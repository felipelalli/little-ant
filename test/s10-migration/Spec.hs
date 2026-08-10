module Main (main) where

import Control.Exception (bracket)
import Control.Monad (forM_)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.ByteString.Base16 qualified as Base16
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Id
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Interaction
import LittleAnt.Migration.V0
import LittleAnt.Model
import LittleAnt.Profile qualified as Profile
import LittleAnt.Result
import LittleAnt.Store
import System.Directory
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "v0 migration"
    [ testCase "inspect and dry-run are read-only" inspectAndDryRun
    , testCase "migration starts even when optional integrations are invalid" invalidIntegrationsDoNotBlockMigration
    , testCase "all 25 observed types build and cut over with exact custody" buildAndCutover
    , testCase "unknown event versions block before mutation" unknownVersionBlocks
    , testCase "a nonempty v1 target is never merged" nonemptyTargetBlocks
    , testCase "cutover resumes after the atomic exchange boundary" interruptedCutoverResumes
    , testCase "a migrated Brick completes the alpha daily loop after restart" migratedDailyLoop
    ]

inspectAndDryRun :: Assertion
inspectAndDryRun = withFixture $ \fixture -> do
  before <- ByteString.readFile (fixtureSource fixture)
  inspected <- migrate fixture False MigrationInspect
  migrationLegacyEventCount inspected @?= 25
  migrationLegacyBrickCount inspected @?= 4
  migrationLegacyRawCount inspected @?= 1
  length (migrationSupportedTypes inspected) @?= 25
  migrationCandidatePath inspected @?= Nothing
  afterInspect <- ByteString.readFile (fixtureSource fixture)
  afterInspect @?= before
  dryBuild <- migrate fixture True MigrationBuild
  migrationDryRun dryBuild @?= True
  candidate <- requireJust "dry-run candidate path" (migrationCandidatePath dryBuild)
  candidateExists <- doesPathExist candidate
  candidateExists @?= False
  live <- loadHealthy (fixtureStore fixture)
  loadedCursor live @?= Genesis
  afterDryRun <- ByteString.readFile (fixtureSource fixture)
  afterDryRun @?= before

invalidIntegrationsDoNotBlockMigration :: Assertion
invalidIntegrationsDoNotBlockMigration = withSystemTempDirectory "lant-migration-bootstrap" $ \root ->
  withEnvironment (xdgAssignments root) $ do
    _ <- productionMigrationEnv Nothing >>= requireRight "create migration profile"
    roots <- Profile.resolveXdgRoots
    paths <- either (assertFailure . show) pure (Profile.profilePaths roots "default")
    ByteString.writeFile (Profile.integrationsFile paths) "not: [valid: typed: yaml"
    let source = root </> "events.jsonl"
    ByteString.writeFile source sanitizedObservedFixture

    environment <- productionMigrationEnv Nothing >>= requireRight "restart migration environment"
    inspected <- runAppCommand environment False (const (pure ())) (MigrateCommand (Just source) MigrationInspect)
    _ <- requireRight "inspect through migration environment" inspected

    productionAppEnv Nothing >>= \case
      Left problem -> appErrorCode problem @?= CorruptData
      Right _ -> assertFailure "the regular environment unexpectedly accepted invalid integrations"

buildAndCutover :: Assertion
buildAndCutover = withFixture $ \fixture -> do
  sourceBefore <- ByteString.readFile (fixtureSource fixture)
  built <- migrate fixture False MigrationBuild
  candidatePath <- requireJust "candidate path" (migrationCandidatePath built)
  candidateCursor <- requireJust "candidate cursor" (migrationCandidateCursor built)
  loadedCursor <$> loadHealthy (fixtureStore fixture) >>= (@?= Genesis)
  candidate <- loadHealthy (StoreConfig candidatePath 5000000 25000)
  loadedCursor candidate @?= candidateCursor
  let state = loadedState candidate
  Map.size (stateBricks state) @?= 4
  Map.size (stateDomains state) @?= 2
  Map.size (stateExternalEntities state) @?= 1
  Map.size (stateDependencies state) @?= 1
  Map.size (statePairJudgments state) @?= 1
  Map.size (stateSourceBindings state) @?= 2
  Map.size (stateWaits state) @?= 1
  length [brick | brick <- Map.elems (stateBricks state), brickStatus brick == BrickDone] @?= 1
  length [brick | brick <- Map.elems (stateBricks state), brickStatus brick == BrickSuperseded] @?= 1
  length [brick | brick <- Map.elems (stateBricks state), brickStatus brick == BrickArchived] @?= 1
  let archivedSource = candidatePath </> "legacy" </> "v0" </> "events.jsonl"
  ByteString.readFile archivedSource >>= (@?= sourceBefore)
  manifestBytes <- ByteString.readFile (candidatePath </> "legacy" </> "v0" </> "manifest.json")
  case eitherDecodeStrict' manifestBytes of
    Left problem -> assertFailure ("could not decode migration manifest: " <> problem)
    Right (Object manifest) -> case KeyMap.lookup "raw_identity_map" manifest of
      Just (Object rawIdentities) -> case KeyMap.lookup "raw-note" rawIdentities of
        Just (String migratedId) -> assertBool "migrated Raw identity is empty" (not (Text.null migratedId))
        _ -> assertFailure "legacy Raw is missing from the identity map"
      _ -> assertFailure "migration manifest has no Raw identity map"
    Right _ -> assertFailure "migration manifest is not an object"
  cutover <- migrate fixture False MigrationCutover
  migrationCutoverComplete cutover @?= True
  live <- loadHealthy (fixtureStore fixture)
  loadedCursor live @?= candidateCursor
  backup <- requireJust "backup path" (migrationBackupPath cutover)
  backupDataset <- loadHealthy (StoreConfig backup 5000000 25000)
  loadedCursor backupDataset @?= Genesis
  ByteString.readFile (fixtureSource fixture) >>= (@?= sourceBefore)
  cutoverAgain <- migrate fixture False MigrationCutover
  migrationCutoverComplete cutoverAgain @?= True
  loadedCursor <$> loadHealthy (fixtureStore fixture) >>= (@?= candidateCursor)

unknownVersionBlocks :: Assertion
unknownVersionBlocks = withSystemTempDirectory "lant-migration-unknown" $ \root -> do
  let store = StoreConfig (root </> "dataset") 5000000 25000
      source = root </> "events.jsonl"
      at = readUtc "2026-08-01 12:00:00 UTC"
      payload = object ["brick" .= ("b1" :: Text), "title" .= ("One" :: Text)]
      invalid = eventValue at "brick_captured" 99 payload
  initializeDataset store
  ByteString.writeFile source (LazyByteString.toStrict (encode invalid <> "\n"))
  result <- runV0Migration store migrationActor (pure at) False (Just source) MigrationInspect
  assertCode CorruptData result
  loadedCursor <$> loadHealthy store >>= (@?= Genesis)

nonemptyTargetBlocks :: Assertion
nonemptyTargetBlocks = withFixture $ \fixture -> do
  _ <- migrate fixture False MigrationBuild
  _ <- migrate fixture False MigrationCutover
  result <- runV0Migration (fixtureStore fixture) migrationActor (pure fixtureNow) False (Just (fixtureSource fixture)) MigrationInspect
  assertCode PreconditionFailed result

interruptedCutoverResumes :: Assertion
interruptedCutoverResumes = withFixture $ \fixture -> do
  built <- migrate fixture False MigrationBuild
  candidate <- requireJust "candidate path" (migrationCandidatePath built)
  expectedCursor <- requireJust "candidate cursor" (migrationCandidateCursor built)
  candidateDataset <- loadHealthy (StoreConfig candidate 5000000 25000)
  let target = storeRoot (fixtureStore fixture)
      exchanged = target <> ".test-exchanged"
  renameDirectory target exchanged
  renameDirectory candidate target
  renameDirectory exchanged candidate
  let digest = migrationSourceDigest built
      parent = takeDirectory target
      base = takeFileName target
      suffix = take 16 (Text.unpack digest)
      pending = parent </> ("." <> base <> ".v0-alpha-" <> suffix <> ".pending.json")
      backup = parent </> (base <> ".pre-v1-alpha-" <> suffix)
      journal =
        object
          [ "schema" .= ("little-ant/v0-migration-cutover@1" :: Text)
          , "source_sha256" .= digest
          , "candidate_cursor" .= expectedCursor
          , "candidate_event_count" .= loadedEventCount candidateDataset
          , "candidate_root" .= candidate
          , "backup_root" .= backup
          ]
  ByteString.writeFile pending (LazyByteString.toStrict (encode journal <> "\n"))
  resumed <- migrate fixture False MigrationCutover
  migrationCutoverComplete resumed @?= True
  loadedCursor <$> loadHealthy (fixtureStore fixture) >>= (@?= expectedCursor)
  backupDataset <- loadHealthy (StoreConfig backup 5000000 25000)
  loadedCursor backupDataset @?= Genesis
  pendingExists <- doesFileExist pending
  pendingExists @?= False

migratedDailyLoop :: Assertion
migratedDailyLoop = withSystemTempDirectory "lant-migration-daily" $ \root -> do
  let store = StoreConfig (root </> "dataset") 5000000 25000
      source = root </> "events.jsonl"
  initializeDataset store
  ByteString.writeFile source dailyLoopFixture
  _ <- migrate (Fixture store source) False MigrationBuild
  _ <- migrate (Fixture store source) False MigrationCutover
  environment <- dailyLoopEnvironment store 1000

  before <- loadHealthy store
  let migrated = Map.elems (stateBricks (loadedState before))
  length migrated @?= 3

  scope <- run environment (OrderCommand Nothing) >>= interactionOf
  ordered <- answer environment scope "order.all" >>= finishOrdering environment
  proposal <- answer environment ordered "next"
  selectedId <- case envelopeOpportunity proposal of
    FocusProposalOpportunity identity _ -> pure identity
    other -> assertFailure ("expected a migrated focus proposal, got " <> show other) >> fail "unreachable"
  assertBool "next selected a non-migrated Brick" (selectedId `elem` fmap brickId migrated)

  let selected = stateBricks (loadedState before) Map.! selectedId
      selectedReference = "#" <> unHandle (brickHandle selected)
  searched <- run environment (SearchCommand (brickTitle selected))
  case searched of
    SearchResult{resultSearchHits} -> assertBool "search lost the migrated Brick" (brickTitle selected `elem` fmap searchHitTitle resultSearchHits)
    other -> assertFailure ("expected search results, got " <> show other)

  focused <- answer environment proposal "focus.accept"
  envelopeOpportunity focused @?= CurrentFocusOpportunity selectedId
  symptoms <- answer environment focused "focus.skip"
  tired <- answer environment symptoms "work.symptom.tired"
  skipped <- answer environment tired "work.reaction.skip"
  case envelopeOpportunity skipped of
    WorkSkipAcknowledgedOpportunity identity TiredSymptom SkipAnywayReaction -> identity @?= selectedId
    other -> assertFailure ("expected a typed skip receipt, got " <> show other)

  nature <- run environment (BreakCommand selectedReference) >>= interactionOf
  draft <- answer environment nature "work.break.nature.project"
  firstPart <- submitBreak environment draft "Inspect the route"
  secondPart <- submitBreak environment firstPart "Carry the first load"
  preview <- submitBreak environment secondPart ""
  broken <- answer environment preview "work.break.accept"
  childIds <- case envelopeOpportunity broken of
    WorkBreakResultOpportunity identity children -> do
      identity @?= selectedId
      length children @?= 2
      pure children
    other -> assertFailure ("expected decomposition result, got " <> show other) >> fail "unreachable"

  afterBreak <- loadHealthy store
  forM_ childIds $ \childId -> do
    let child = stateBricks (loadedState afterBreak) Map.! childId
    _ <- run environment (DoneCommand (Just ("#" <> unHandle (brickHandle child))))
    pure ()
  _ <- run environment (DoneCommand (Just selectedReference))

  restarted <- dailyLoopEnvironment store 5000
  recovered <- loadHealthy (appStore restarted)
  brickStatus (stateBricks (loadedState recovered) Map.! selectedId) @?= BrickDone
  fmap (brickStatus . (stateBricks (loadedState recovered) Map.!)) childIds @?= [BrickDone, BrickDone]
  replayedSearch <- run restarted (SearchCommand (brickTitle selected))
  case replayedSearch of
    SearchResult{resultSearchHits} -> assertBool "restart lost the completed migrated Brick" (brickTitle selected `elem` fmap searchHitTitle resultSearchHits)
    other -> assertFailure ("expected search results after restart, got " <> show other)
  doctor <- run restarted DoctorCommand
  case doctor of
    DoctorResult{resultDatasetHealthy} -> resultDatasetHealthy @?= True
    other -> assertFailure ("expected doctor result, got " <> show other)

dailyLoopFixture :: ByteString.ByteString
dailyLoopFixture =
  LazyByteString.toStrict . mconcat $
    [ encode (eventValue at "brick_captured" 1 payload) <> "\n"
    | (at, payload) <- zip times payloads
    ]
 where
  start = readUtc "2026-08-02 09:00:00 UTC"
  times = [addUTCTime (fromIntegral second) start | second <- [0 :: Int .. 2]]
  payloads =
    [ object ["brick" .= ("daily-one" :: Text), "title" .= ("Prepare the alpha notes" :: Text)]
    , object ["brick" .= ("daily-two" :: Text), "title" .= ("Review the migration report" :: Text)]
    , object ["brick" .= ("daily-three" :: Text), "title" .= ("Exercise the daily loop" :: Text)]
    ]

dailyLoopEnvironment :: StoreConfig -> Int -> IO AppEnv
dailyLoopEnvironment store seed = do
  identities <- traverse dailyLoopUuid [seed .. seed + 500]
  available <- newIORef identities
  pure
    AppEnv
      { appStore = store
      , appActor = migrationActor
      , appNow = pure fixtureNow
      , appZonedNow = pure (utcToZonedTime utc fixtureNow)
      , appAllocateUUID = atomicModifyIORef' available $ \case
          identity : rest -> (rest, identity)
          [] -> error "daily-loop UUID fixture exhausted"
      , appExportPort = emptyExportPort
      , appImportPort = emptyImportPort
      , appImportPortProblem = Nothing
      , appPackRegistryProblem = Nothing
      , appOfficialPackRemote = Nothing
      , appProviderConnectionRuntime = Nothing
      }

dailyLoopUuid :: Int -> IO UUIDv7
dailyLoopUuid seed =
  either (assertFailure . show) pure $
    uuidV7FromEntropy
      (0x0198f8a34c21 + fromIntegral seed)
      (ByteString.replicate 10 (fromIntegral (seed `mod` 251 + 1)))

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command =
  runAppCommand environment False (const (pure ())) command >>= \case
    Left problem -> assertFailure (show problem) >> fail "unreachable"
    Right result -> pure result

answer :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answer environment envelope action =
  run environment (RespondCommand (response envelope action)) >>= interactionOf

submitBreak :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
submitBreak environment envelope submitted =
  run environment (SubmitInteractionTextCommand (response envelope "work.break.submit") submitted) >>= interactionOf

finishOrdering :: AppEnv -> InteractionEnvelope -> IO InteractionEnvelope
finishOrdering environment envelope = case envelopeOpportunity envelope of
  ImportanceReviewOpportunity{} -> answer environment envelope "importance.more" >>= finishOrdering environment
  OrderResultOpportunity{} -> pure envelope
  other -> assertFailure ("expected importance review or order result, got " <> show other) >> fail "unreachable"

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other) >> fail "unreachable"

data Fixture = Fixture
  { fixtureStore :: StoreConfig
  , fixtureSource :: FilePath
  }

fixtureNow :: UTCTime
fixtureNow = readUtc "2026-08-10 12:00:00 UTC"

migrationActor :: Actor
migrationActor = Actor "human" "migration-test"

withFixture :: (Fixture -> IO value) -> IO value
withFixture action = withSystemTempDirectory "lant-migration" $ \root -> do
  let store = StoreConfig (root </> "dataset") 5000000 25000
      source = root </> "events.jsonl"
  initializeDataset store
  ByteString.writeFile source sanitizedObservedFixture
  action (Fixture store source)

migrate :: Fixture -> Bool -> MigrationStage -> IO MigrationReport
migrate fixture dryRun stage =
  runV0Migration (fixtureStore fixture) migrationActor (pure fixtureNow) dryRun (Just (fixtureSource fixture)) stage >>= \case
    Left problem -> assertFailure (show problem)
    Right report -> pure report

loadHealthy :: StoreConfig -> IO LoadedDataset
loadHealthy store =
  loadDataset store (const (pure ())) >>= \case
    Left problem -> assertFailure (show problem)
    Right dataset -> pure dataset

requireJust :: String -> Maybe value -> IO value
requireJust label = maybe (assertFailure (label <> " is missing")) pure

requireRight :: String -> Either AppError value -> IO value
requireRight label = either (\problem -> assertFailure (label <> ": " <> show problem)) pure

xdgAssignments :: FilePath -> [(String, String)]
xdgAssignments root =
  [ ("XDG_CONFIG_HOME", root </> "config")
  , ("XDG_DATA_HOME", root </> "data")
  , ("XDG_STATE_HOME", root </> "state")
  , ("XDG_RUNTIME_DIR", root </> "runtime")
  , ("LANT_PROFILE", "default")
  ]

withEnvironment :: [(String, String)] -> IO value -> IO value
withEnvironment assignments action = bracket save restore (const (setAll >> action))
 where
  save = traverse (\(name, _) -> (name,) <$> lookupEnv name) assignments
  restore = mapM_ restoreOne
  restoreOne (name, Just value) = setEnv name value
  restoreOne (name, Nothing) = unsetEnv name
  setAll = mapM_ (uncurry setEnv) assignments

assertCode :: ErrorCode -> Either AppError value -> Assertion
assertCode expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure "expected migration failure"

sanitizedObservedFixture :: ByteString.ByteString
sanitizedObservedFixture =
  LazyByteString.toStrict . mconcat $
    [ encode event <> "\n"
    | event <- zipWith3 wireValue times typesAndVersions payloads
    ]
 where
  times = [addUTCTime (fromIntegral second) start | second <- [0 :: Int .. 24]]
  start = readUtc "2026-08-01 09:00:00 UTC"
  wireValue at (eventType, version) payload = eventValue' at eventType version payload
  typesAndVersions =
    [ ("party_registered", 1)
    , ("fed", 1)
    , ("seeds_extracted", 1)
    , ("brick_captured", 1)
    , ("seed_promoted", 1)
    , ("brick_ready", 1)
    , ("brick_enriched", 2)
    , ("brick_described", 1)
    , ("requester_attributed", 1)
    , ("flow_opened", 1)
    , ("focus_served", 2)
    , ("brick_started", 1)
    , ("brick_stopped", 1)
    , ("wip_flagged", 1)
    , ("skip_taken", 1)
    , ("wait_recorded", 1)
    , ("dependency_added", 1)
    , ("comparison_recorded", 1)
    , ("source_attached", 1)
    , ("source_checked", 1)
    , ("order_sanity_proposed", 1)
    , ("brick_regressed", 1)
    , ("brick_completed", 1)
    , ("brick_superseded", 1)
    , ("brick_killed", 1)
    ]
  payloads =
    [ object ["party" .= ("party-alex" :: Text), "name" .= ("Alex Example" :: Text), "party_type" .= ("person" :: Text)]
    , object ["raw" .= ("raw-note" :: Text), "content" .= ("A source note" :: Text)]
    , object ["raw" .= ("raw-note" :: Text), "seeds" .= [object ["brick" .= ("brick-seed" :: Text), "title" .= ("Review source note" :: Text)]]]
    , object ["brick" .= ("brick-main" :: Text), "title" .= ("Prepare release" :: Text)]
    , object ["brick" .= ("brick-seed" :: Text)]
    , object ["brick" .= ("brick-main" :: Text)]
    , object ["brick" .= ("brick-main" :: Text), "kind" .= ("spec" :: Text), "context" .= ("Work/Product" :: Text), "weight" .= (0.4 :: Double), "mode" .= ("digital" :: Text), "atomicity" .= ("divisible" :: Text), "estimate_hours" .= (2.0 :: Double), "estimate_by" .= ("human" :: Text)]
    , object ["brick" .= ("brick-main" :: Text), "description" .= ("Define the release boundary." :: Text)]
    , object ["brick" .= ("brick-main" :: Text), "party" .= ("party-alex" :: Text)]
    , object ["flow" .= ("flow-one" :: Text), "context" .= ("Work/Product" :: Text), "strictness" .= ("prefer" :: Text)]
    , object ["flow" .= ("flow-one" :: Text), "brick" .= ("brick-main" :: Text)]
    , object ["brick" .= ("brick-main" :: Text)]
    , object ["brick" .= ("brick-main" :: Text)]
    , object ["brick" .= ("brick-main" :: Text)]
    , object ["skip" .= ("skip-one" :: Text), "brick" .= ("brick-main" :: Text), "reason" .= ("vague" :: Text), "raw_text" .= ("Needs a boundary" :: Text)]
    , object ["wait" .= ("wait-one" :: Text), "brick" .= ("brick-main" :: Text), "party" .= ("party-alex" :: Text), "condition" .= Null]
    , object ["blocked" .= ("brick-main" :: Text), "blocker" .= ("brick-seed" :: Text)]
    , object ["comparison" .= ("comparison-one" :: Text), "before" .= ("brick-seed" :: Text), "after" .= ("brick-main" :: Text), "author" .= ("human" :: Text)]
    , object ["link" .= ("source-one" :: Text), "brick" .= ("brick-main" :: Text), "type" .= ("web" :: Text), "url" .= ("https://example.invalid/release" :: Text)]
    , object ["link" .= ("source-one" :: Text), "fingerprint" .= ("sha256:example" :: Text)]
    , object ["brick" .= ("brick-review" :: Text), "title" .= ("Review importance order" :: Text), "readied_count" .= (1 :: Int)]
    , object ["brick" .= ("brick-main" :: Text)]
    , object ["brick" .= ("brick-seed" :: Text)]
    , object ["brick" .= ("brick-main" :: Text), "replacement" .= ("brick-replacement" :: Text), "title" .= ("Prepare revised release" :: Text), "reason" .= ("Scope changed" :: Text)]
    , object ["brick" .= ("brick-review" :: Text)]
    ]

eventValue :: UTCTime -> Text -> Int -> Value -> Value
eventValue = eventValue'

eventValue' :: UTCTime -> Text -> Int -> Value -> Value
eventValue' at eventType version payload =
  object
    [ "v" .= version
    , "id" .= intrinsicId at eventType payload
    , "at" .= at
    , "type" .= eventType
    , "data" .= payload
    ]

intrinsicId :: UTCTime -> Text -> Value -> Text
intrinsicId at eventType payload =
  TextEncoding.decodeUtf8 . Base16.encode . SHA256.hash . LazyByteString.toStrict . encode $
    object ["at" .= at, "type" .= eventType, "data" .= payload]

readUtc :: String -> UTCTime
readUtc value = parseTimeOrError True defaultTimeLocale "%Y-%m-%d %H:%M:%S %Z" value

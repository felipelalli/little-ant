module Main (main) where

import Control.Monad (foldM, replicateM)
import Data.Aeson (Value (..), eitherDecodeStrict', encode)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Projection
import LittleAnt.Result
import LittleAnt.Store
import LittleAnt.Surface (renderPlain)
import System.Directory
import System.FileLock
import System.FilePath (takeFileName, (</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "S01 walking skeleton"
    [ testCase "UUIDv7 uses the RFC 9562 version and variant layout" testUuidLayout
    , testCase "human handles normalize Unicode and retain retired suffixes" testHandles
    , testCase "new handle bases stop at six characters before collision suffixes" testBoundedHandles
    , testCase "legacy handles survive replay alongside newly shortened handles" testLegacyHandles
    , testCase "pristine next renders the canonical useful first screen" testPristine
    , testCase "optional envelope fields are omitted rather than null" testSparseEnvelope
    , testCase "Feed persists one Raw and restart restores the same pending envelope" testFeedRestart
    , testCase "current and upcasted accepted corpora fold to equal state" testCorpusReplay
    , testCase "accepted fixture filename is its exact SHA-256" testFixtureHash
    , testCase "empty Feed and dry-run append nothing" testNoMutationPaths
    , testCase "a bounded writer lock returns a retry-safe conflict" testWriterContention
    , testCase "a torn dot-prefixed segment is not canonical history" testTornTemporary
    , testCase "unknown event versions stop writable replay" testUnknownVersion
    , testCase "malformed accepted JSON stops replay" testMalformedAccepted
    , testCase "responses revalidate unrelated cursors and reject changed questions" testStaleResponse
    , testCase "Feed undo is rejected after a dependent Raw revision" testDependentUndo
    , testCase "a corrupt presentation checkpoint is rejected without touching history" testCheckpointIntegrity
    , testCase "snapshot plus hot tail equals full replay and snapshots remain disposable" testSnapshotReplay
    , testCase "interrupted cold rotation coalesces only identical segment copies" testInterruptedRotation
    , testCase "cached readers retry a snapshot replaced during hot-tail replay" testConcurrentRotation
    , testCase "accepted writes automatically rotate after 128 command groups" testAutomaticRotation
    ]

testUuidLayout :: Assertion
testUuidLayout = do
  generated <- assertRight (uuidV7FromEntropy 0x0198f8a34c21 (ByteString.pack [0xB6, 0xE0, 0x5D, 0x82, 0xFA, 0x73, 0x1C, 0x4E, 0x60, 0x00]))
  Text.index (renderUUIDv7 generated) 14 @?= '7'
  assertBool "variant must be RFC 4122/9562" (Text.index (renderUUIDv7 generated) 19 `elem` ("89ab" :: String))
  parseUUIDv7 (renderUUIDv7 generated) @?= Right generated
  assertBool "a version-4 UUID is rejected" (isLeft (parseUUIDv7 "0198f8a3-4c21-4b6e-9d05-82fa731c4e60"))

testHandles :: Assertion
testHandles = do
  handleBase BrickHandle "Rock Splitter" @?= "rs"
  handleBase RawHandle "ação útil" @?= "au"
  handleBase RawHandle "日本語" @?= "raw"
  let first = allocateHandle RawHandle Set.empty "milk"
      second = allocateHandle RawHandle (Set.singleton first) "milk"
  first @?= Handle "milk"
  second @?= Handle "milk2"

testBoundedHandles :: Assertion
testBoundedHandles = mapM_ check [BrickHandle, RawHandle, EntityHandle]
 where
  check kind = do
    handleBase kind "Abcdefghijklmnop" @?= "abcdef"
    handleBase kind "Alpha Bravo Charlie Delta Écho Foxtrot Golf Hotel" @?= "abcdef"
    handleBase kind "Short" @?= "short"
    let seed = "Abcdefghijklmnop"
        first = allocateHandle kind Set.empty seed
        second = allocateHandle kind (Set.singleton first) seed
        reserved = Set.fromList [first, second, Handle "abcdef4", Handle "abcdefghijkl"]
        throughNine = Set.fromList (first : [Handle ("abcdef" <> Text.pack (show suffix)) | suffix <- [2 .. 9 :: Int]])
    first @?= Handle "abcdef"
    second @?= Handle "abcdef2"
    allocateHandle kind reserved seed @?= Handle "abcdef3"
    allocateHandle kind throughNine seed @?= Handle "abcdef10"

testLegacyHandles :: Assertion
testLegacyHandles = withSystemTempDirectory "lant-legacy-handles" $ \root -> do
  environment <- deterministicEnv root 800
  facts <- testFacts environment 3
  let material = "Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliet Kilo Lima"
      legacyHandle = Handle "abcdefghijkl2"
  decision <- assertRight (decideFeed emptyState (appActor environment) "test" material facts)
  legacyDraft <- case feedDecisionEvents decision of
    [draft@EventDraft{draftPayload = RawFedV1 payload}] -> pure draft{draftPayload = RawFedV1 payload{fedHandle = legacyHandle}}
    _ -> assertFailure "Feed must produce one Raw allocation" >> fail "unreachable"
  legacy <- appendCommand (appStore environment) Genesis [legacyDraft] >>= assertRightIO
  let legacyId = rawId (feedDecisionRaw decision)
      assertLegacy state = fmap rawId (resolveRawHandle state legacyHandle) @?= Just legacyId
  assertLegacy (loadedState legacy)
  shown <- runAppCommand environment False (const (pure ())) (ShowRawCommand "+abcdefghijkl2" SummaryView) >>= assertRightIO
  case shown of
    ShowRawResult{resultRaw} -> projectedRawId resultRaw @?= legacyId
    _ -> assertFailure "legacy handle must still resolve through the application"
  mapM_
    ( \expected -> do
        result <- runAppCommand environment False (const (pure ())) (FeedCommand "test" material) >>= assertRightIO
        case result of
          FeedResult{resultRaw} -> renderHandle RawHandle (projectedRawHandle resultRaw) @?= expected
          _ -> assertFailure "Feed must allocate a new Raw"
    )
    ["+abcdef", "+abcdef2"]
  restarted <- deterministicEnv root 900
  replayed <- loadDataset (appStore restarted) (const (pure ())) >>= assertRightIO
  assertLegacy (loadedState replayed)
  rawCount (loadedState replayed) @?= 3

testPristine :: Assertion
testPristine = withSystemTempDirectory "lant-pristine" $ \root -> do
  environment <- deterministicEnv root 1
  result <- runAppCommand environment True (const (pure ())) NextCommand >>= assertRightIO
  case result of
    NextResult{resultInteraction} -> do
      let rendered = renderPlain (renderEnvelope resultInteraction)
      assertBool "screen starts usefully" ("No Bricks yet.\n\nFeed Little Ant" `Text.isPrefixOf` rendered)
      assertBool "first Feed is visible" ("[f]eed" `Text.isInfixOf` rendered)
      assertBool "footer remains six lines" (". 0 bricks, 0 raws, 0 reviews\n  mode: dumb, focus: idle" `Text.isSuffixOf` rendered)
    _ -> assertFailure "next did not return an interaction"

testSparseEnvelope :: Assertion
testSparseEnvelope = withSystemTempDirectory "lant-sparse" $ \root -> do
  environment <- deterministicEnv root 10
  result <- runAppCommand environment False (const (pure ())) NextCommand >>= assertRightIO
  let bytes = LazyByteString.toStrict (encode result)
  assertBool "optional uncertainty route must be absent" (not ("uncertainty_route" `ByteString.isInfixOf` bytes))
  assertBool "false dry_run is omitted" (not ("dry_run" `ByteString.isInfixOf` bytes))

testFeedRestart :: Assertion
testFeedRestart = withSystemTempDirectory "lant-feed" $ \root -> do
  environment <- deterministicEnv root 20
  first <- runAppCommand environment False (const (pure ())) NextCommand >>= assertRightIO
  fed <- runAppCommand environment False (const (pure ())) (FeedCommand "test" "milk") >>= assertRightIO
  (rawIdentity, pendingIdentity, acceptedCursor) <- case (first, fed) of
    (NextResult{}, FeedResult{resultRaw, resultInteraction, resultDatasetCursor}) ->
      pure
        (projectedRawId resultRaw, envelopeInteractionId resultInteraction, resultDatasetCursor)
    _ -> assertFailure "unexpected result shape" >> fail "unreachable"
  restarted <- deterministicEnv root 100
  next <- runAppCommand restarted False (const (pure ())) NextCommand >>= assertRightIO
  case next of
    NextResult{resultInteraction, resultDatasetCursor} -> do
      envelopeInteractionId resultInteraction @?= pendingIdentity
      resultDatasetCursor @?= acceptedCursor
    _ -> assertFailure "restart did not return next"
  shown <- runAppCommand restarted False (const (pure ())) (ShowRawCommand "+milk" SummaryView) >>= assertRightIO
  case shown of
    ShowRawResult{resultRaw} -> projectedRawId resultRaw @?= rawIdentity
    _ -> assertFailure "show did not return Raw"
  replayed <- loadDataset (appStore restarted) (const (pure ())) >>= assertRightIO
  loadedEventCount replayed @?= 1
  rawCount (loadedState replayed) @?= 1

testCorpusReplay :: Assertion
testCorpusReplay = do
  current <- loadDataset (fixtureConfig "s01-current") (const (pure ())) >>= assertRightIO
  legacy <- loadDataset (fixtureConfig "s01-legacy") (const (pure ())) >>= assertRightIO
  loadedState current @?= loadedState legacy
  loadedEventCount current @?= 1
  loadedEventCount legacy @?= 1

testFixtureHash :: Assertion
testFixtureHash = do
  names <- listDirectory "test/fixtures/s01-current/events"
  case names of
    [name] -> do
      bytes <- ByteString.readFile ("test/fixtures/s01-current/events" </> name)
      assertBool "filename embeds exact hash" (sha256Hex bytes `Text.isInfixOf` Text.pack name)
    _ -> assertFailure "S01 current corpus must contain exactly one segment"

testNoMutationPaths :: Assertion
testNoMutationPaths = withSystemTempDirectory "lant-no-mutation" $ \root -> do
  environment <- deterministicEnv root 200
  emptyResult <- runAppCommand environment False (const (pure ())) (FeedCommand "test" "   ")
  assertErrorCode InvalidInput emptyResult
  dryResult <- runAppCommand environment True (const (pure ())) (FeedCommand "test" "milk")
  _ <- assertRightIO dryResult
  exists <- doesPathExist root
  assertBool "temporary parent exists" exists
  datasetExists <- doesPathExist (storeRoot (appStore environment))
  assertBool "dry-run must not initialize a dataset" (not datasetExists)

testWriterContention :: Assertion
testWriterContention = withSystemTempDirectory "lant-lock" $ \root -> do
  environment0 <- deterministicEnv root 300
  let environment =
        environment0
          { appStore =
              (appStore environment0)
                { storeLockTimeoutMicros = 20000
                , storeLockPollMicros = 1000
                }
          }
  initializeDataset (appStore environment)
  withFileLock (storeRoot (appStore environment) </> ".writer.lock") Exclusive $ \_ -> do
    result <- runAppCommand environment False (const (pure ())) (FeedCommand "test" "milk")
    assertErrorCode Conflict result
    case result of
      Left problem -> appErrorRetrySafety problem @?= RetrySafe
      Right _ -> assertFailure "contention unexpectedly committed"
  replayed <- loadDataset (appStore environment) (const (pure ())) >>= assertRightIO
  loadedEventCount replayed @?= 0

testTornTemporary :: Assertion
testTornTemporary = withSystemTempDirectory "lant-torn" $ \root -> do
  environment <- deterministicEnv root 400
  _ <- runAppCommand environment False (const (pure ())) (FeedCommand "test" "milk") >>= assertRightIO
  ByteString.writeFile (storeRoot (appStore environment) </> "events" </> ".torn.tmp") "{broken"
  replayed <- loadDataset (appStore environment) (const (pure ())) >>= assertRightIO
  loadedEventCount replayed @?= 1

testUnknownVersion :: Assertion
testUnknownVersion = withSystemTempDirectory "lant-unknown" $ \root -> do
  let config = StoreConfig root 100000 1000
  initializeDataset config
  original <- onlyFixtureBytes
  let changed = replaceBytes "\"event_version\":1" "\"event_version\":99" original
      name = segmentFileName 1 (sha256Hex changed)
  ByteString.writeFile (root </> "events" </> name) changed
  result <- loadDataset config (const (pure ()))
  assertErrorCode UnknownEventVersion result

testMalformedAccepted :: Assertion
testMalformedAccepted = withSystemTempDirectory "lant-malformed" $ \root -> do
  let config = StoreConfig root 100000 1000; bytes = "{broken}\n"
  initializeDataset config
  ByteString.writeFile (root </> "events" </> segmentFileName 1 (sha256Hex bytes)) bytes
  loadDataset config (const (pure ())) >>= assertErrorCode CorruptData

appendTestFeed :: StoreConfig -> LoadedDataset -> Int -> UTCTime -> IO LoadedDataset
appendTestFeed store current seed now = do
  identities <- traverse testUuid [seed * 3 + 3000 .. seed * 3 + 3002]
  let facts = RuntimeFacts now (fmap (UUIDAllocation . renderUUIDv7) identities) mempty (FilesystemFacts True True (Just (renderCursor (loadedCursor current)))) (TerminalCapabilities False False False 80 24 False) []
  decision <- assertRight (decideFeed (loadedState current) (Actor "human" "test") "test" ("raw " <> Text.pack (show seed) <> " — \"escaped\"\ncontext") facts)
  assertRight =<< appendCommand store (loadedCursor current) (feedDecisionEvents decision)

testSnapshotReplay :: Assertion
testSnapshotReplay = withSystemTempDirectory "lant-fold-cache" $ \root -> do
  let store = StoreConfig root 100000 1000
      initial = LoadedDataset emptyState Genesis 0
      snapshot = root </> "projections" </> "fold-snapshot.json"
  first <- appendTestFeed store initial 1 (UTCTime (fromGregorian 2026 2 1) 0)
  second <- appendTestFeed store first 2 (UTCTime (fromGregorian 2026 5 1) 0)
  paths <- assertRight =<< canonicalSegmentFiles store
  before <- traverse ByteString.readFile paths
  compacted <- assertRight =<< compactDataset store
  compacted @?= second
  listDirectory (root </> "events") >>= (@?= [])
  quarters <- listDirectory (root </> "archive")
  Set.fromList quarters @?= Set.fromList ["2026-Q1", "2026-Q2"]
  cold <- assertRight =<< canonicalSegmentFiles store
  (firstCold, firstBytes) <- case (cold, before) of
    (one : _, bytes : _) -> pure (one, bytes)
    _ -> assertFailure "no cold segments" >> fail "unreachable"
  traverse ByteString.readFile cold >>= (@?= before)
  progress <- newIORef []
  cached <- assertRight =<< loadDataset store (\count -> modifyIORef' progress (<> [count]))
  cached @?= second
  readIORef progress >>= (@?= [])
  snapshotBytes <- ByteString.readFile snapshot
  oldSnapshot <- case eitherDecodeStrict' snapshotBytes of
    Right (Object fields)
      | Just (Object payload) <- KeyMap.lookup "payload" fields ->
          let oldPayload = Object (KeyMap.insert "state_format" (String "little-ant/fold-state-binary@1") payload)
              oldDigest = String (sha256Hex (LazyByteString.toStrict (encode oldPayload)))
           in pure (Object (KeyMap.insert "sha256" oldDigest (KeyMap.insert "payload" oldPayload fields)))
    other -> assertFailure ("invalid generated snapshot: " <> show other) >> fail "unreachable"
  LazyByteString.writeFile snapshot (encode oldSnapshot)
  ByteString.writeFile firstCold "{damaged}\n"
  loadDataset store (const (pure ())) >>= assertErrorCode CorruptData
  ByteString.writeFile firstCold firstBytes
  incompatible <- assertRight =<< loadDataset store (\count -> modifyIORef' progress (<> [count]))
  incompatible @?= second
  ByteString.writeFile snapshot snapshotBytes
  -- Prove that cached boot does not decode cold content; doctor still catches
  -- canonical corruption hidden behind a healthy cache.
  ByteString.writeFile firstCold "{damaged}\n"
  loadDataset store (const (pure ())) >>= assertRight >>= (@?= second)
  loadDatasetFull store (const (pure ())) >>= assertErrorCode CorruptData
  ByteString.writeFile firstCold firstBytes
  third <- appendTestFeed store cached 3 fixedUtcTime
  writeIORef progress []
  tailReplay <- assertRight =<< loadDataset store (\count -> modifyIORef' progress (<> [count]))
  tailReplay @?= third
  readIORef progress >>= (@?= [1])
  loadDatasetFull store (const (pure ())) >>= assertRight >>= (@?= third)
  history <- assertRight =<< readCanonicalEvents store
  fromIntegral (length history) @?= loadedEventCount third
  removeFile snapshot
  loadDataset store (const (pure ())) >>= assertRight >>= (@?= third)
  _ <- assertRight =<< compactDataset store
  ByteString.writeFile snapshot "{torn cache}"
  loadDataset store (const (pure ())) >>= assertRight >>= (@?= third)

testInterruptedRotation :: Assertion
testInterruptedRotation = withSystemTempDirectory "lant-rotation" $ \root -> do
  let store = StoreConfig root 100000 1000
  accepted <- appendTestFeed store (LoadedDataset emptyState Genesis 0) 1 fixedUtcTime
  _ <- assertRight =<< compactDataset store
  [cold] <- assertRight =<< canonicalSegmentFiles store
  let hot = root </> "events" </> takeFileName cold
  copyFile cold hot
  ByteString.writeFile (root </> "archive" </> "2026-Q3" </> ".torn.tmp") "{incomplete"
  loadDataset store (const (pure ())) >>= assertRight >>= (@?= accepted)
  loadDatasetFull store (const (pure ())) >>= assertRight >>= (@?= accepted)
  _ <- assertRight =<< compactDataset store
  doesFileExist hot >>= assertBool "hot duplicate should be removed" . not
  copyFile cold hot
  ByteString.appendFile hot "different"
  loadDatasetFull store (const (pure ())) >>= assertErrorCode CorruptData

testConcurrentRotation :: Assertion
testConcurrentRotation = withSystemTempDirectory "lant-reader-rotation" $ \root -> do
  let store = StoreConfig root 100000 1000
  first <- appendTestFeed store (LoadedDataset emptyState Genesis 0) 1 fixedUtcTime
  _ <- assertRight =<< compactDataset store
  second <- appendTestFeed store first 2 fixedUtcTime
  third <- appendTestFeed store second 3 fixedUtcTime
  latest <- newIORef third
  rotated <- newIORef False
  loaded <-
    assertRight
      =<< loadDataset
        store
        ( \_ -> do
            alreadyRotated <- atomicModifyIORef' rotated (True,)
            if alreadyRotated
              then pure ()
              else do
                fourth <- appendTestFeed store third 4 fixedUtcTime
                _ <- assertRight =<< compactDataset store
                writeIORef latest fourth
        )
  readIORef latest >>= (@?= loaded)
  loadDatasetFull store (const (pure ())) >>= assertRight >>= (@?= loaded)

testAutomaticRotation :: Assertion
testAutomaticRotation = withSystemTempDirectory "lant-auto-fold" $ \root -> do
  let store = StoreConfig root 100000 1000
  accepted <- foldM (\current seed -> appendTestFeed store current seed fixedUtcTime) (LoadedDataset emptyState Genesis 0) [1 .. 128]
  listDirectory (root </> "events") >>= (@?= [])
  doesFileExist (root </> "projections" </> "fold-snapshot.json") >>= assertBool "snapshot was not written"
  loadDataset store (const (pure ())) >>= assertRight >>= (@?= accepted)
  loadDatasetFull store (const (pure ())) >>= assertRight >>= (@?= accepted)
  tailState <- appendTestFeed store accepted 129 fixedUtcTime
  loadDataset store (const (pure ())) >>= assertRight >>= (@?= tailState)

testStaleResponse :: Assertion
testStaleResponse = do
  identity <- testUuid 500
  let now = fixedZonedTime
      original = makePristineEnvelope identity Genesis "same" now
      unchanged = makePristineEnvelope identity (DatasetCursor 1 (Text.replicate 64 "a")) "same" now
      changed = makePristineEnvelope identity (DatasetCursor 1 (Text.replicate 64 "b")) "different" now
      response = InteractionResponse identity 1 "feed.open" (envelopeIntegrityToken original) Genesis
  case validateResponse original unchanged response of
    Right ResponseAccepted{} -> pure ()
    other -> assertFailure ("safe revalidation failed: " <> show other)
  case validateResponse original changed response of
    Right (ResponseStale replacement) -> envelopePreconditionHash replacement @?= "different"
    other -> assertFailure ("stale response was not replaced: " <> show other)

testDependentUndo :: Assertion
testDependentUndo = do
  environment <- deterministicEnv "/tmp/not-used-by-pure-test" 600
  facts <- testFacts environment 3
  decision <- assertRight (decideFeed emptyState (appActor environment) "test" "milk" facts)
  let (_, _, persisted) = encodeSegment 1 "genesis" (feedDecisionEvents decision)
  state <- foldEvents emptyState persisted
  let identity = rawId (feedDecisionRaw decision)
      touched = state{stateRaws = Map.adjust (\raw -> raw{rawRevision = 2}) identity (stateRaws state)}
  undoFacts <- testFacts environment 2
  assertErrorCode PreconditionFailed (decideUndoFeed touched (appActor environment) undoFacts)

testCheckpointIntegrity :: Assertion
testCheckpointIntegrity = withSystemTempDirectory "lant-checkpoint" $ \root -> do
  environment <- deterministicEnv root 700
  _ <- runAppCommand environment False (const (pure ())) NextCommand >>= assertRightIO
  let path = storeRoot (appStore environment) </> "checkpoints" </> "pending-envelope.json"
  bytes <- ByteString.readFile path
  ByteString.writeFile path (replaceBytes "\"integrity_token\":\"" "\"integrity_token\":\"broken" bytes)
  result <- runAppCommand environment False (const (pure ())) NextCommand
  assertErrorCode PreconditionFailed result
  replayed <- loadDataset (appStore environment) (const (pure ())) >>= assertRightIO
  loadedEventCount replayed @?= 0

deterministicEnv :: FilePath -> Int -> IO AppEnv
deterministicEnv root seed = do
  identities <- traverse testUuid [seed .. seed + 30]
  reference <- newIORef identities
  pure
    AppEnv
      { appStore = StoreConfig (root </> "dataset") 100000 1000
      , appActor = Actor "human" "test"
      , appNow = pure fixedUtcTime
      , appZonedNow = pure fixedZonedTime
      , appAllocateUUID = atomicModifyIORef' reference $ \case
          identity : rest -> (rest, identity)
          [] -> error "deterministic UUID fixture exhausted"
      , appExportPort = emptyExportPort
      , appImportPort = emptyImportPort
      , appImportPortProblem = Nothing
      , appPackRegistryProblem = Nothing
      , appOfficialPackRemote = Nothing
      , appProviderConnectionRuntime = Nothing
      }

testUuid :: Int -> IO UUIDv7
testUuid seed =
  assertRight $
    uuidV7FromEntropy
      (0x0198f8a34c21 + fromIntegral seed)
      (ByteString.replicate 10 (fromIntegral (seed `mod` 251 + 1)))
testFacts :: AppEnv -> Int -> IO RuntimeFacts
testFacts environment count = do
  identities <- replicateM count (appAllocateUUID environment)
  pure
    RuntimeFacts
      { runtimeNow = fixedUtcTime
      , runtimeUUIDs = fmap (UUIDAllocation . renderUUIDv7) identities
      , runtimeRandomBlocks = mempty
      , runtimeFilesystem = FilesystemFacts False True (Just "genesis")
      , runtimeTerminal = TerminalCapabilities False False False 80 24 False
      , runtimeExternalFacts = []
      }

fixedUtcTime :: UTCTime
fixedUtcTime = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))
fixedZonedTime :: ZonedTime
fixedZonedTime = utcToZonedTime (minutesToTimeZone (-180)) fixedUtcTime
fixtureConfig :: FilePath -> StoreConfig
fixtureConfig name = StoreConfig ("test/fixtures" </> name) 100000 1000
onlyFixtureBytes :: IO ByteString
onlyFixtureBytes = do
  names <- listDirectory "test/fixtures/s01-current/events"
  case names of
    [name] -> ByteString.readFile ("test/fixtures/s01-current/events" </> name)
    _ -> assertFailure "expected one current fixture" >> pure ""
replaceBytes :: ByteString -> ByteString -> ByteString -> ByteString
replaceBytes needle replacement haystack = case ByteString.breakSubstring needle haystack of
  (before, after)
    | ByteString.null after -> haystack
    | otherwise -> before <> replacement <> ByteString.drop (ByteString.length needle) after
foldEvents :: State -> [PersistedEvent] -> IO State
foldEvents state events = case foldl (\result event -> result >>= (`applyEvent` event)) (Right state) events of
  Left problem -> assertFailure (show problem) >> pure state
  Right value -> pure value
assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure
assertRightIO :: (Show left) => Either left right -> IO right
assertRightIO = assertRight
assertErrorCode :: (Eq result, Show result) => ErrorCode -> Either AppError result -> Assertion
assertErrorCode expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right result -> assertFailure ("expected error, got: " <> show result)
isLeft :: Either left right -> Bool
isLeft = \case Left _ -> True; Right _ -> False

module Main (main) where

import Data.Aeson (Value, eitherDecodeStrict')
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Export
import LittleAnt.Id
import LittleAnt.Import
import LittleAnt.Judgment (factoryJudgmentProfileHash)
import LittleAnt.Model
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Standard
import LittleAnt.Pack.Trust
import LittleAnt.Source
import LittleAnt.Store
import LittleAnt.TaskJugglerActuals
import System.Directory (doesDirectoryExist, listDirectory)
import System.Exit (ExitCode (..))
import System.FilePath (makeRelative, splitDirectories, (</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 offline standard Pack"
      [ testCase "the committed source tree reconstructs the exact signed archive" canonicalArchive
      , testCase "the exact compiled identity grants six exporters and two SourceAdapters" builtInRegistry
      , testCase "tree, Org, and self-contained HTML match reviewed fixtures" reviewedFixtures
      , testCase "aligned table and RFC 4180 CSV preserve structural data" structuredTextFormats
      , testCase "the core planning cut produces valid TaskJuggler syntax" taskJugglerPlanningCut
      , testCase "the plain-text SourceAdapter summarizes one whole file for Raw preservation" plainTextSourceAdapter
      , testCase "the TaskJuggler actuals SourceAdapter verifies manifest custody independently" taskJugglerActualsSourceAdapter
      ]

canonicalArchive :: Assertion
canonicalArchive = do
  manifestBytes <- ByteString.readFile (standardRoot </> "pack.json")
  signatureBytes <- ByteString.readFile (standardRoot </> "signature.json")
  payload <- readPayload
  rebuilt <- assertRight (buildCanonicalPackArchive manifestBytes signatureBytes payload)
  committed <- ByteString.readFile (standardRoot </> "standard.lantpack")
  rebuilt @?= committed
  structural <- assertRight (validatePackArchive committed)
  authenticated <- assertRight (authenticatePack structural)
  authenticatedPackIdentity authenticated @?= standardPackIdentity

builtInRegistry :: Assertion
builtInRegistry = do
  scope <- assertRight (mkProfileScope "default")
  registry <- loadStandardPackRegistry fixtureTime scope >>= assertRight
  registryProfileScope registry @?= scope
  let registered = registryComponents registry
  Set.fromList (componentId . componentCommon . registeredComponent <$> registered) @?= standardPackComponentIds
  assertBool
    "the standard Pack exposed an unexpected executable component kind"
    (all ((`elem` [ReadOnlyExporterComponent, SourceAdapterComponent]) . componentKind . componentCommon . registeredComponent) registered)
  client <- fixtureClient
  exportPortCatalog (packRegistryExportPort client registry)
    @?= [ ExportDescriptor "csv" "Csv" "csv" "little-ant/structure@1"
        , ExportDescriptor "html" "Html" "html" "little-ant/structure@1"
        , ExportDescriptor "org" "Org" "org" "little-ant/structure@1"
        , ExportDescriptor "table" "Table" "table" "little-ant/structure@1"
        , ExportDescriptor "taskjuggler" "TaskJuggler" "taskjuggler" "little-ant/taskjuggler@1"
        , ExportDescriptor "tree" "Tree" "tree" "little-ant/structure@1"
        ]

plainTextSourceAdapter :: Assertion
plainTextSourceAdapter = do
  client <- fixtureClient
  scope <- assertRight (mkProfileScope "default")
  registry <- loadStandardPackRegistry fixtureTime scope >>= assertRight
  registered <- assertRight (lookupPackComponent "plain_text" registry)
  let bytes = "First line\nSecond line\n"
      input = SourceInput "ideas.txt" "text/plain; charset=utf-8" bytes
  preflight <- invokePackSourcePreflight client registered SourceMigrate input >>= assertRight
  sourcePreflightContractMajor preflight @?= 1
  assertBool "standard preflight omitted its input authority" ("input_bytes" `Text.isInfixOf` sourcePreflightPermissions preflight)
  sourcePreflightInputDigest preflight @?= sha256Hex bytes
  observedSourceLabel (sourcePreflightObservation preflight) @?= "Plain text file"
  observedCleanupSupported (sourcePreflightObservation preflight) @?= False
  case observedObjects (sourcePreflightObservation preflight) of
    [sourceObject] -> do
      sourceObjectTitle sourceObject @?= "ideas.txt"
      sourceObjectShape sourceObject @?= SourceNoteShape
      sourceObjectMaterial sourceObject @?= summarizeSourceMaterial (SourceTextMaterial "First line\nSecond line\n")
    other -> assertFailure ("unexpected plain-text objects: " <> show other)

taskJugglerActualsSourceAdapter :: Assertion
taskJugglerActualsSourceAdapter = do
  client <- fixtureClient
  scope <- assertRight (mkProfileScope "default")
  registry <- loadStandardPackRegistry fixtureTime scope >>= assertRight
  exported <- runExportHost (packRegistryExportPort client registry) False fixtureTime genesisCursor planningState "taskjuggler" ExportWholeDataset Nothing >>= assertRight
  let original = TextEncoding.decodeUtf8 (exportArtifactBytes (exportHostArtifact exported))
      taskHeader = "task t_0198f000000070008000000000000011 \"Prepare the planning cut\" {\n"
      actualText =
        Text.replace "  now ${projectstart}" "  now 2026-08-09-09:00" $
          Text.replace taskHeader (taskHeader <> "  actual:effortdone 2h\n  actual:effortleft 4h\n") original
      actualBytes = TextEncoding.encodeUtf8 actualText
      input = SourceInput "little-ant.tjp" "text/x-taskjuggler; charset=utf-8" actualBytes
  parsed <- assertRight (parseTaskJugglerActuals actualBytes)
  length (actualsRecords parsed) @?= 1
  registered <- assertRight (lookupPackComponent "taskjuggler_actuals" registry)
  preflight <- invokePackSourcePreflight client registered SourceSnapshot input >>= assertRight
  observedIdentity (sourcePreflightObservation preflight)
    @?= Map.fromList
      [ ("actual_record_count", "1")
      , ("actuals_as_of", "2026-08-09-09:00Z")
      , ("planning_manifest_sha256", actualsManifestDigest parsed)
      ]
  observedSupportedModes (sourcePreflightObservation preflight) @?= [SourceSnapshot]
  observedCleanupSupported (sourcePreflightObservation preflight) @?= False
  case observedObjects (sourcePreflightObservation preflight) of
    [sourceObject] -> do
      sourceObjectLocator sourceObject @?= "manifest-sha256:" <> actualsManifestDigest parsed
      sourceObjectMaterial sourceObject @?= summarizeSourceMaterial (SourceTextMaterial actualText)
    other -> assertFailure ("unexpected TaskJuggler actuals objects: " <> show other)
  withSystemTempDirectory "little-ant-taskjuggler-actuals" $ \directory -> do
    let path = directory </> "actuals.tjp"
    ByteString.writeFile path actualBytes
    imported <- importPortPreflight (packRegistryImportPort client registry) (Text.pack path) SourceSnapshot >>= assertRight
    sourcePreflightAdapterId (importReadPreflight imported) @?= "taskjuggler_actuals"
    observedIdentity (sourcePreflightObservation (importReadPreflight imported)) @?= observedIdentity (sourcePreflightObservation preflight)
    (exitCode, stdoutText, stderrText) <- readProcessWithExitCode "tj3" ["--check-syntax", "--no-reports", path] ""
    case exitCode of
      ExitSuccess -> pure ()
      ExitFailure code -> assertFailure ("tj3 rejected the actuals fixture (" <> show code <> "):\n" <> stdoutText <> stderrText)

reviewedFixtures :: Assertion
reviewedFixtures = do
  (client, registry, projection) <- fixtureRuntime
  mapM_ (assertGolden client registry projection) [("tree", "expected-tree.txt"), ("org", "expected.org"), ("html", "expected.html")]
  html <- artifactBytes client registry projection "html"
  assertBool "HTML fetched an external resource" (not ("http://" `ByteString.isInfixOf` html || "https://" `ByteString.isInfixOf` html))
  assertBool "HTML included executable script" (not ("<script" `ByteString.isInfixOf` html))

structuredTextFormats :: Assertion
structuredTextFormats = do
  (client, registry, projection) <- fixtureRuntime
  tableBytes <- artifactBytes client registry projection "table"
  let tableLines = Text.lines (TextEncoding.decodeUtf8 tableBytes)
  tableLines
    @?= [ "brick  title                        nature       phase      state  domains              "
        , "-----  ---------------------------  -----------  ---------  -----  ---------------------"
        , "#pa    Plan \"alpha\" next            project      spec       wip    Orbit                "
        , "#ss    Ship, safely & verify <all>  atomic_task  execution  idle   Orbit › Rock Splitter"
        ]

  csv <- artifactBytes client registry projection "csv"
  assertBool "CSV header did not use CRLF" ((header <> "\r\n") `ByteString.isPrefixOf` csv)
  assertBool "CSV did not quote a comma" ("#ss,\"Ship, safely & verify <all>\"" `ByteString.isInfixOf` csv)
  assertBool "CSV did not escape quotes and the embedded newline" ("\"Plan \"\"alpha\"\"\nnext\"" `ByteString.isInfixOf` csv)
  assertBool "CSV rendered an integral sibling position as a decimal" (not (",1.0," `ByteString.isInfixOf` csv))
  assertBool "CSV did not end its final record with CRLF" ("\r\n" `ByteString.isSuffixOf` csv)
 where
  header :: ByteString
  header = "id,handle,title,nature,parent_id,domains,sibling_position,status,work_state,phase,effort,impact_class,impact_maturity"

taskJugglerPlanningCut :: Assertion
taskJugglerPlanningCut = do
  client <- fixtureClient
  scope <- assertRight (mkProfileScope "default")
  registry <- loadStandardPackRegistry fixtureTime scope >>= assertRight
  result <- runExportHost (packRegistryExportPort client registry) False fixtureTime genesisCursor planningState "taskjuggler" ExportWholeDataset Nothing >>= assertRight
  let artifact = exportHostArtifact result
      bytes = exportArtifactBytes artifact
  expectedFragments <- ByteString8.lines <$> ByteString.readFile (fixtureRoot </> "expected-taskjuggler-fragments.txt")
  mapM_ (\fragment -> assertBool ("TaskJuggler fixture fragment was omitted: " <> show fragment) (fragment `ByteString.isInfixOf` bytes)) expectedFragments
  exportArtifactMediaType artifact @?= "text/x-taskjuggler; charset=utf-8"
  Map.lookup "projection" (exportArtifactMetadata artifact) @?= Just "little-ant/taskjuggler@1"
  assertBool "the visible effort gap did not reach host warnings" (any ("missing-effort:" `Text.isPrefixOf`) (exportArtifactWarnings artifact))
  withSystemTempDirectory "little-ant-taskjuggler" $ \directory -> do
    let path = directory </> "little-ant.tjp"
    ByteString.writeFile path bytes
    (exitCode, stdoutText, stderrText) <- readProcessWithExitCode "tj3" ["--check-syntax", "--no-reports", path] ""
    case exitCode of
      ExitSuccess -> pure ()
      ExitFailure code -> assertFailure ("tj3 rejected the standard exporter (" <> show code <> "):\n" <> stdoutText <> stderrText)

planningState :: State
planningState =
  emptyState
    { stateBricks = Map.fromList [(brickId first, first), (brickId second, second), (brickId scheduled, scheduled)]
    , stateEffortClaims =
        Map.fromList
          [ (brickId first, EffortClaim (brickId first) EasyEffort fixtureTime DirectHuman factoryJudgmentProfileHash)
          , (brickId scheduled, EffortClaim (brickId scheduled) NormalEffort fixtureTime DirectHuman factoryJudgmentProfileHash)
          ]
    , stateEffortActualEvidence =
        Map.singleton
          (planningUuid "0198f000-0000-7000-8000-0000000000a1")
          ( EffortActualEvidence
              (planningUuid "0198f000-0000-7000-8000-0000000000a1")
              (brickId first)
              (planningUuid "0198f000-0000-7000-8000-0000000000a2")
              (planningUuid "0198f000-0000-7000-8000-0000000000a3")
              (Text.replicate 64 "a")
              "t_0198f000000070008000000000000011"
              fixtureTime
              (Just 2_000_000)
              (Just 2_500_000)
              fixtureTime
          )
    , stateDependencies = Map.singleton (dependencyId dependency) dependency
    , stateTemporalConstraints =
        Map.singleton
          (brickId first)
          ( TemporalConstraints
              (Just (at 1 9))
              (Just (at 5 9))
              (Just (at 10 18))
              1
          )
    , stateScheduledIntervals = Map.singleton (brickId scheduled) (ScheduledInterval (brickId scheduled) (at 2 15) (at 2 16) 1)
    }
 where
  first = planningBrick "0198f000-0000-7000-8000-000000000011" "first" "Prepare the planning cut" 0 Wip
  second = planningBrick "0198f000-0000-7000-8000-000000000012" "second" "Review the visible effort gap" 1 Idle
  scheduled = (planningBrick "0198f000-0000-7000-8000-000000000013" "meeting" "Planning review" 2 Idle){brickNature = ScheduledCommitment}
  dependency = Dependency (planningUuid "0198f000-0000-7000-8000-000000000090") (brickId second) (brickId first) DependencyActive "fixture" fixtureTime
  at daysFromNow hour = ZonedInstant (UTCTime (addDays daysFromNow (utctDay fixtureTime)) (secondsToDiffTime (hour * 3600))) "UTC"

planningBrick :: Text -> Text -> Text -> Int -> WorkState -> Brick
planningBrick identity handle title position workState =
  Brick
    (planningUuid identity)
    (Handle handle)
    title
    AtomicTask
    "factory@1"
    "fixture"
    Nothing
    Nothing
    Set.empty
    position
    (DeterministicPosition "fixture")
    BrickActive
    workState
    fixtureTime
    (Actor "human" "test")
    (planningUuid "0198f000-0000-7000-8000-000000000099")

planningUuid :: Text -> UUIDv7
planningUuid value = either (error . Text.unpack) id (parseUUIDv7 value)

assertGolden :: PackRunnerClient -> PackRegistry -> Value -> (Text, FilePath) -> Assertion
assertGolden client registry projection (componentId, goldenName) = do
  actual <- artifactBytes client registry projection componentId
  expected <- ByteString.readFile (fixtureRoot </> goldenName)
  actual @?= expected

artifactBytes :: PackRunnerClient -> PackRegistry -> Value -> Text -> IO ByteString
artifactBytes client registry projection componentId = do
  registered <- assertRight (lookupPackComponent componentId registry)
  artifact <- invokePackExporter client registered projection >>= assertRight
  runnerArtifactMetadata artifact @?= Map.fromList [("format", expectedFormat componentId), ("projection", "little-ant/structure@1")]
  pure (runnerArtifactBytes artifact)

expectedFormat :: Text -> Text
expectedFormat = \case
  "csv" -> "rfc4180-csv"
  "html" -> "self-contained-html"
  value -> value

fixtureRuntime :: IO (PackRunnerClient, PackRegistry, Value)
fixtureRuntime = do
  client <- fixtureClient
  scope <- assertRight (mkProfileScope "default")
  registry <- loadStandardPackRegistry fixtureTime scope >>= assertRight
  projectionBytes <- ByteString.readFile (fixtureRoot </> "structure.json")
  projection <- either (assertFailure . ("invalid projection fixture: " <>)) pure (eitherDecodeStrict' projectionBytes)
  pure (client, registry, projection)

fixtureClient :: IO PackRunnerClient
fixtureClient = defaultPackRunnerClient

readPayload :: IO (Map Text ByteString)
readPayload = do
  files <- listFiles (standardRoot </> "payload")
  Map.fromList <$> traverse readOne files
 where
  readOne path = do
    bytes <- ByteString.readFile path
    pure (portablePath (makeRelative (standardRoot </> "payload") path), bytes)

listFiles :: FilePath -> IO [FilePath]
listFiles directory = do
  entries <- sort <$> listDirectory directory
  fmap concat . traverse inspect $ entries
 where
  inspect entry = do
    let path = directory </> entry
    directoryEntry <- doesDirectoryExist path
    if directoryEntry then listFiles path else pure [path]

portablePath :: FilePath -> Text
portablePath = Text.intercalate "/" . fmap Text.pack . splitDirectories

assertRight :: (Show problem) => Either problem value -> IO value
assertRight = either (assertFailure . show) pure

standardRoot :: FilePath
standardRoot = "packs/standard"

fixtureRoot :: FilePath
fixtureRoot = "test/fixtures/standard-pack"

fixtureTime :: UTCTime
fixtureTime = UTCTime (fromGregorian 2026 8 9) 0

module Main (main) where

import Data.Aeson (encode)
import Data.Bits ((.&.))
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text.Encoding qualified as Text
import Data.Time
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Export
import LittleAnt.Id
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Model
import LittleAnt.Result
import LittleAnt.Store
import System.Directory
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Files (fileMode, getFileStatus)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 safe export host"
      [ testCase "structural projection is versioned, sparse, scoped, and deterministically ordered" structuralProjection
      , testCase "new-file export publishes exact bytes and reports digest without events" newFileExport
      , testCase "stdout export returns bytes without creating a destination" stdoutExport
      , testCase "dry-run invokes the read-only exporter but writes no file" dryRunExport
      , testCase "existing, symlinked, nonregular, and missing-parent destinations fail before invocation" unsafeDestinations
      , testCase "exporter failure and invalid metadata leave no target" exporterFailures
      , testCase "unknown, duplicate, and incompatible exporters fail before invocation" invalidExporterRegistry
      ]

structuralProjection :: Assertion
structuralProjection = do
  let root = fixtureUuid 1
      child = fixtureUuid 2
      outside = fixtureUuid 3
      domain = fixtureUuid 4
      state =
        emptyState
          { stateBricks =
              Map.fromList
                [ (outside, fixtureBrick outside "outside" "Outside" Nothing Set.empty 9)
                , (child, fixtureBrick child "child" "Child" (Just root) (Set.singleton domain) 1)
                , (root, fixtureBrick root "root" "Root" Nothing (Set.singleton domain) 2)
                ]
          , stateDomains = Map.singleton domain (Domain domain "Engineering" Nothing True)
          }
      projection = buildStructuralProjection Genesis state (ExportBrickSubtree root)
      bytes = LazyByteString.toStrict (encode projection)
  exportProjectionSchema projection @?= "little-ant/structure@1"
  assertBool "scope retains stable identity" (Text.encodeUtf8 (renderUUIDv7 root) `ByteString.isInfixOf` bytes)
  assertBool "subtree includes its child" ("Child" `ByteString.isInfixOf` bytes)
  assertBool "subtree excludes unrelated Work" (not ("Outside" `ByteString.isInfixOf` bytes))
  assertBool "sparse projection omits absent parent" (not ("\"parent_id\":null" `ByteString.isInfixOf` bytes))
  assertBool "parent precedes child" (indexOf "Root" bytes < indexOf "Child" bytes)

newFileExport :: Assertion
newFileExport = withSystemTempDirectory "lant-export-file" $ \root -> do
  invoked <- newIORef ([] :: [ExportProjection])
  environment <- harness root (fixturePort invoked validArtifact)
  let output = root </> "result.txt"
  result <- run environment False (ExportCommand fixtureExporterId Nothing (Just output))
  case result of
    ExportResult{resultDatasetCursor, resultExportDestination, resultExportByteCount, resultExportDigest, resultExportBytes} -> do
      resultDatasetCursor @?= Genesis
      resultExportDestination @?= Just output
      resultExportByteCount @?= ByteString.length fixtureBytes
      resultExportDigest @?= sha256Hex fixtureBytes
      resultExportBytes @?= Nothing
    other -> assertFailure ("unexpected export result: " <> show other)
  ByteString.readFile output >>= (@?= fixtureBytes)
  mode <- fileMode <$> getFileStatus output
  mode .&. 0o777 @?= 0o600
  projections <- readIORef invoked
  length projections @?= 1
  projection <- case projections of
    [value] -> pure value
    _ -> assertFailure "expected exactly one captured projection" >> fail "unreachable"
  assertBool "the exporter input contains no host output path" (not (ByteString.pack (fmap (fromIntegral . fromEnum) output) `ByteString.isInfixOf` LazyByteString.toStrict (encode projection)))
  replayed <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  loadedEventCount replayed @?= 0

stdoutExport :: Assertion
stdoutExport = withSystemTempDirectory "lant-export-stdout" $ \root -> do
  invoked <- newIORef []
  environment <- harness root (fixturePort invoked validArtifact)
  result <- run environment False (ExportCommand fixtureExporterId Nothing Nothing)
  case result of
    ExportResult{resultExportDestination = Nothing, resultExportBytes = Just bytes} -> bytes @?= fixtureBytes
    other -> assertFailure ("stdout export did not retain bytes: " <> show other)
  listDirectory root >>= (@?= [])

dryRunExport :: Assertion
dryRunExport = withSystemTempDirectory "lant-export-dry" $ \root -> do
  invoked <- newIORef []
  environment <- harness root (fixturePort invoked validArtifact)
  let output = root </> "dry.txt"
  result <- run environment True (ExportCommand fixtureExporterId Nothing (Just output))
  case result of
    ExportResult{resultExportDestination = Just _, resultExportBytes = Nothing, resultDryRun = True} -> pure ()
    other -> assertFailure ("unexpected dry-run result: " <> show other)
  doesPathExist output >>= assertBool "dry-run created an output file" . not
  readIORef invoked >>= (\calls -> length calls @?= 1)

unsafeDestinations :: Assertion
unsafeDestinations = withSystemTempDirectory "lant-export-invalid" $ \root -> do
  invoked <- newIORef []
  environment <- harness root (fixturePort invoked validArtifact)
  let existing = root </> "existing.txt"
      symlink = root </> "symlink.txt"
      directory = root </> "directory"
      missing = root </> "missing" </> "output.txt"
  ByteString.writeFile existing "preserve"
  createFileLink existing symlink
  createDirectory directory
  mapM_ (assertRejected environment) [existing, symlink, directory, missing]
  readIORef invoked >>= (\calls -> length calls @?= 0)
  ByteString.readFile existing >>= (@?= "preserve")

exporterFailures :: Assertion
exporterFailures = withSystemTempDirectory "lant-export-failure" $ \root -> do
  failedInvocations <- newIORef []
  failedEnvironment <- harness root (fixturePortResult failedInvocations (Left (appError ExternalFailure "fixture exporter failed")))
  let failedTarget = root </> "failed.txt"
  failed <- runAppCommand failedEnvironment False (const (pure ())) (ExportCommand fixtureExporterId Nothing (Just failedTarget))
  assertError ExternalFailure failed
  doesPathExist failedTarget >>= assertBool "failed exporter left a target" . not

  invalidInvocations <- newIORef []
  invalidEnvironment <- harness root (fixturePort invalidInvocations validArtifact{exportArtifactSuggestedFilename = "../escape.txt"})
  let invalidTarget = root </> "invalid.txt"
  invalid <- runAppCommand invalidEnvironment False (const (pure ())) (ExportCommand fixtureExporterId Nothing (Just invalidTarget))
  assertError ExternalFailure invalid
  doesPathExist invalidTarget >>= assertBool "invalid artifact left a target" . not
  leftovers <- filter (".lant-export-" `isPrefixOf`) <$> listDirectory root
  leftovers @?= []

invalidExporterRegistry :: Assertion
invalidExporterRegistry = withSystemTempDirectory "lant-export-registry" $ \root -> do
  invoked <- newIORef []
  missingEnvironment <- harness root (fixturePort invoked validArtifact)
  runAppCommand missingEnvironment False (const (pure ())) (ExportCommand "missing" Nothing Nothing) >>= assertError NotFound

  let duplicate = ExportPort [fixtureDescriptor, fixtureDescriptor] prepareStructural (invokeFixture invoked (Right validArtifact))
  duplicateEnvironment <- harness root duplicate
  runAppCommand duplicateEnvironment False (const (pure ())) (ExportCommand fixtureExporterId Nothing Nothing) >>= assertError Conflict

  let incompatibleDescriptor = fixtureDescriptor{exportDescriptorProjection = "little-ant/unknown@9"}
      incompatible = ExportPort [incompatibleDescriptor] prepareStructural (invokeFixture invoked (Right validArtifact))
  incompatibleEnvironment <- harness root incompatible
  runAppCommand incompatibleEnvironment False (const (pure ())) (ExportCommand fixtureExporterId Nothing Nothing) >>= assertError Unsupported
  readIORef invoked >>= (\calls -> length calls @?= 0)

assertRejected :: AppEnv -> FilePath -> Assertion
assertRejected environment output = do
  result <- runAppCommand environment False (const (pure ())) (ExportCommand fixtureExporterId Nothing (Just output))
  assertError PreconditionFailed result

fixturePort :: IORef [ExportProjection] -> ExportArtifact -> ExportPort
fixturePort invoked artifact = fixturePortResult invoked (Right artifact)

fixturePortResult :: IORef [ExportProjection] -> Either AppError ExportArtifact -> ExportPort
fixturePortResult invoked result = ExportPort [fixtureDescriptor] prepareStructural (invokeFixture invoked result)

prepareStructural :: ExportDescriptor -> UTCTime -> DatasetCursor -> State -> ExportScope -> Either AppError ExportProjection
prepareStructural descriptor _ cursor state scope
  | exportDescriptorProjection descriptor == "little-ant/structure@1" = Right (buildStructuralProjection cursor state scope)
  | otherwise = Left (appError Unsupported "unsupported fixture projection")

invokeFixture :: IORef [ExportProjection] -> Either AppError ExportArtifact -> ExportDescriptor -> ExportProjection -> IO (Either AppError ExportArtifact)
invokeFixture invoked result _ projection = modifyIORef' invoked (<> [projection]) >> pure result

fixtureDescriptor :: ExportDescriptor
fixtureDescriptor = ExportDescriptor fixtureExporterId "Fixture text" "plain text" "little-ant/structure@1"

fixtureExporterId :: Text
fixtureExporterId = "fixture.text"

validArtifact :: ExportArtifact
validArtifact = ExportArtifact fixtureBytes "text/plain; charset=utf-8" "little-ant.txt" ["fixture warning"] (Map.singleton "fixture" "true")

fixtureBytes :: ByteString.ByteString
fixtureBytes = "exported safely\n"

harness :: FilePath -> ExportPort -> IO AppEnv
harness root port = do
  counter <- newIORef (100 :: Int)
  let allocate = atomicModifyIORef' counter $ \seed -> (seed + 1, fixtureUuid seed)
  pure $
    AppEnv
      (StoreConfig (root </> "dataset") 2_000_000 20_000)
      (Actor "human" "test")
      (pure fixedTime)
      (pure (utcToZonedTime utc fixedTime))
      allocate
      port
      emptyImportPort
      Nothing

run :: AppEnv -> Bool -> AppCommand -> IO CommandResult
run environment dryRun command = assertRight =<< runAppCommand environment dryRun (const (pure ())) command

assertError :: ErrorCode -> Either AppError CommandResult -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right result -> assertFailure ("expected " <> show expected <> ", got " <> show result)

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

fixtureBrick :: UUIDv7 -> Text -> Text -> Maybe UUIDv7 -> Set.Set UUIDv7 -> Int -> Brick
fixtureBrick identity handle title parent domains position =
  Brick
    identity
    (Handle handle)
    title
    AtomicTask
    "1"
    "fixture"
    Nothing
    parent
    domains
    position
    HumanComparison
    BrickActive
    Idle
    fixedTime
    (Actor "human" "test")
    (fixtureUuid (position + 20))

fixtureUuid :: Int -> UUIDv7
fixtureUuid number = either (error . show) id $ uuidV7FromEntropy (0x019f12340000 + fromIntegral number) (ByteString.replicate 10 (fromIntegral (number `mod` 251 + 1)))

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 8) (secondsToDiffTime (12 * 3600))

indexOf :: ByteString.ByteString -> ByteString.ByteString -> Int
indexOf needle haystack = ByteString.length (fst (ByteString.breakSubstring needle haystack))

isPrefixOf :: String -> String -> Bool
isPrefixOf prefix value = take (length prefix) value == prefix

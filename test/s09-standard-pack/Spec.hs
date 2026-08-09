module Main (main) where

import Data.Aeson (Value, eitherDecodeStrict')
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Export
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Standard
import LittleAnt.Pack.Trust
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (makeRelative, splitDirectories, (</>))
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 offline standard Pack"
      [ testCase "the committed source tree reconstructs the exact signed archive" canonicalArchive
      , testCase "the exact compiled identity grants only the five built-in exporters" builtInRegistry
      , testCase "tree, Org, and self-contained HTML match reviewed fixtures" reviewedFixtures
      , testCase "aligned table and RFC 4180 CSV preserve structural data" structuredTextFormats
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
    "the standard structural components must all be read-only exporters"
    (all ((== ReadOnlyExporterComponent) . componentKind . componentCommon . registeredComponent) registered)
  client <- fixtureClient
  exportPortCatalog (packRegistryExportPort client registry)
    @?= [ ExportDescriptor "csv" "Csv" "csv" "little-ant/structure@1"
        , ExportDescriptor "html" "Html" "html" "little-ant/structure@1"
        , ExportDescriptor "org" "Org" "org" "little-ant/structure@1"
        , ExportDescriptor "table" "Table" "table" "little-ant/structure@1"
        , ExportDescriptor "tree" "Tree" "tree" "little-ant/structure@1"
        ]

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

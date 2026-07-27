-- | Executable contract generated from the Little Ant 1.0 Allium garden.
--
-- The application bridge is deliberately external: this suite fixes behavior
-- before the v1 implementation fixes an internal Haskell module layout.
module Main (main) where

import Control.Monad (forM, unless)
import Data.Aeson
  (FromJSON (parseJSON), Result (..), Value (..), eitherDecodeStrict', encode,
   fromJSON, object, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Foldable (toList)
import Data.List (isSuffixOf, sort)
import Data.Maybe (catMaybes)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import System.Directory (doesFileExist, findExecutable, listDirectory)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit
  (Assertion, assertBool, assertFailure, testCase, (@?=))

data Artifact = Artifact
  { artifactName :: String
  , artifactPlan :: Value
  , artifactModel :: Value
  , artifactObligationIds :: [Text]
  }

data Scenario = Scenario
  { scenarioId :: Text
  , scenarioTitle :: Text
  , scenarioProtocolVersion :: Int
  , scenarioKind :: Text
  , scenarioValue :: Value
  , scenarioStepIds :: [Text]
  , scenarioAssertionIds :: [Text]
  , scenarioAssertionAnchors :: [Text]
  }

data AssertionResult = AssertionResult
  { resultId :: Text
  , resultPassed :: Bool
  , resultDetail :: Maybe Text
  }

instance FromJSON AssertionResult where
  parseJSON = withObject "AssertionResult" $ \value ->
    AssertionResult
      <$> value .: "id"
      <*> value .: "passed"
      <*> value .:? "detail"

data DriverResponse = DriverResponse
  { responseProtocolVersion :: Int
  , responseOk :: Bool
  , responseResults :: [AssertionResult]
  , responseDiagnostics :: [Text]
  }

instance FromJSON DriverResponse where
  parseJSON = withObject "DriverResponse" $ \value ->
    DriverResponse
      <$> value .: "protocol_version"
      <*> value .: "ok"
      <*> value .:? "results" .!= []
      <*> value .:? "diagnostics" .!= []

generatedDirectory :: FilePath
generatedDirectory = "test-v1" </> "generated"

scenarioDirectory :: FilePath
scenarioDirectory = "test-v1" </> "scenarios"

expectedModules :: Set.Set String
expectedModules = Set.fromList
  [ "root"
  , "domain"
  , "material"
  , "judgment"
  , "execution"
  , "selection"
  , "interaction"
  , "integration"
  , "migration-v0-v1"
  ]

expectedObligationCount :: Int
expectedObligationCount = 1446

expectedScenarioCount :: Int
expectedScenarioCount = 16

expectedScenarioAssertionCount :: Int
expectedScenarioAssertionCount = 120

main :: IO ()
main = do
  artifacts <- loadArtifacts
  scenarios <- loadScenarios
  driver <- lookupEnv "LANT_V1_TEST_DRIVER"
  defaultMain $ testGroup "little-ant 1.0"
    [ artifactIntegrityTests artifacts scenarios
    , testGroup "Allium obligations"
        (map (artifactContractTest driver) artifacts)
    , testGroup "end-to-end scenarios and mini-simulations"
        (map (scenarioContractTest driver) scenarios)
    ]

loadArtifacts :: IO [Artifact]
loadArtifacts = do
  files <- sort <$> listDirectory generatedDirectory
  let planSuffix = ".plan.json"
      planFiles = filter (planSuffix `isSuffixOf`) files
  forM planFiles $ \planFile -> do
    let name = take (length planFile - length planSuffix) planFile
    plan <- readJsonFile (generatedDirectory </> planFile)
    model <- readJsonFile
      (generatedDirectory </> (name <> ".model.json"))
    obligationIds <- extractObjectArrayIds "obligations" plan
    pure Artifact
      { artifactName = name
      , artifactPlan = plan
      , artifactModel = model
      , artifactObligationIds = obligationIds
      }

loadScenarios :: IO [Scenario]
loadScenarios = do
  files <- sort <$> listDirectory scenarioDirectory
  let jsonFiles = filter (".json" `isSuffixOf`) files
  forM jsonFiles $ \file -> do
    value <- readJsonFile (scenarioDirectory </> file)
    identifier <- extractTextField "id" value
    title <- extractTextField "title" value
    protocolVersion <- extractIntField "protocol_version" value
    kind <- extractTextField "kind" value
    stepIds <- extractObjectArrayIds "steps" value
    assertionIds <- extractObjectArrayIds "assertions" value
    assertionAfter <- extractObjectArrayOptionalTextFields
      "assertions" "after" value
    assertionAt <- extractObjectArrayOptionalTextFields
      "assertions" "at" value
    let assertionAnchors =
          assertionAfter
            <> [ anchor
               | at <- assertionAt
               , Just anchor <- [Text.stripPrefix "after:" at]
               ]
    pure Scenario
      { scenarioId = identifier
      , scenarioTitle = title
      , scenarioProtocolVersion = protocolVersion
      , scenarioKind = kind
      , scenarioValue = value
      , scenarioStepIds = stepIds
      , scenarioAssertionIds = assertionIds
      , scenarioAssertionAnchors = assertionAnchors
      }

readJsonFile :: FilePath -> IO Value
readJsonFile path = do
  bytes <- BS.readFile path
  case eitherDecodeStrict' bytes of
    Left problem -> fail (path <> ": " <> problem)
    Right value -> pure value

extractTextField :: Text -> Value -> IO Text
extractTextField field = \case
  Object value ->
    case KeyMap.lookup (Key.fromText field) value of
      Just (String textValue) -> pure textValue
      _ -> fail ("missing text field: " <> Text.unpack field)
  _ -> fail "expected a JSON object"

extractIntField :: Text -> Value -> IO Int
extractIntField field = \case
  Object value ->
    case KeyMap.lookup (Key.fromText field) value of
      Just fieldValue ->
        case fromJSON fieldValue of
          Success intValue -> pure intValue
          Error _ -> fail ("non-integer field: " <> Text.unpack field)
      _ -> fail ("missing integer field: " <> Text.unpack field)
  _ -> fail "expected a JSON object"

extractObjectArrayIds :: Text -> Value -> IO [Text]
extractObjectArrayIds field = \case
  Object value ->
    case KeyMap.lookup (Key.fromText field) value of
      Just (Array items) -> mapM itemId (toList items)
      _ -> fail ("missing array field: " <> Text.unpack field)
  _ -> fail "expected a JSON object"
  where
    itemId = \case
      Object item ->
        case KeyMap.lookup "id" item of
          Just (String identifier) -> pure identifier
          _ -> fail ("array item has no text id in " <> Text.unpack field)
      _ -> fail ("non-object array item in " <> Text.unpack field)

extractObjectArrayOptionalTextFields ::
  Text ->
  Text ->
  Value ->
  IO [Text]
extractObjectArrayOptionalTextFields arrayField itemField = \case
  Object value ->
    case KeyMap.lookup (Key.fromText arrayField) value of
      Just (Array items) ->
        catMaybes <$> mapM optionalTextField (toList items)
      _ -> fail ("missing array field: " <> Text.unpack arrayField)
  _ -> fail "expected a JSON object"
  where
    optionalTextField = \case
      Object item ->
        case KeyMap.lookup (Key.fromText itemField) item of
          Nothing -> pure Nothing
          Just Null -> pure Nothing
          Just (String textValue) -> pure (Just textValue)
          _ ->
            fail
              ("non-text field " <> Text.unpack itemField
                <> " in " <> Text.unpack arrayField)
      _ -> fail ("non-object array item in " <> Text.unpack arrayField)

artifactIntegrityTests :: [Artifact] -> [Scenario] -> TestTree
artifactIntegrityTests artifacts scenarios =
  testGroup "generated artifact integrity"
    [ testCase "all expected modules have generated plans and models" $
        Set.fromList (map artifactName artifacts) @?= expectedModules
    , testCase "all 1.0 obligations are materialized" $
        sum (map (length . artifactObligationIds) artifacts)
          @?= expectedObligationCount
    , testCase "obligation IDs are unique within each module" $
        mapM_ assertArtifactIdsUnique artifacts
    , testCase "scenario IDs are unique" $
        assertUnique "scenario IDs" (map scenarioId scenarios)
    , testCase "all expected scenario assertions are materialized" $ do
        length scenarios @?= expectedScenarioCount
        sum (map (length . scenarioAssertionIds) scenarios)
          @?= expectedScenarioAssertionCount
    , testCase "every scenario is structurally closed" $
        mapM_ assertScenarioAssertions scenarios
    ]

assertArtifactIdsUnique :: Artifact -> Assertion
assertArtifactIdsUnique artifact =
  assertUnique
    ("obligations in " <> artifactName artifact)
    (artifactObligationIds artifact)

assertScenarioAssertions :: Scenario -> Assertion
assertScenarioAssertions scenario = do
  scenarioProtocolVersion scenario @?= 1
  assertBool
    ("invalid scenario kind: " <> Text.unpack (scenarioKind scenario))
    (scenarioKind scenario `Set.member`
      Set.fromList ["end_to_end", "simulation"])
  assertUnique
    ("steps in " <> Text.unpack (scenarioId scenario))
    (scenarioStepIds scenario)
  assertBool
    ("scenario has no assertions: " <> Text.unpack (scenarioId scenario))
    (not (null (scenarioAssertionIds scenario)))
  assertUnique
    ("assertions in " <> Text.unpack (scenarioId scenario))
    (scenarioAssertionIds scenario)
  let knownSteps = Set.fromList (scenarioStepIds scenario)
      anchors = Set.fromList (scenarioAssertionAnchors scenario)
  unless (anchors `Set.isSubsetOf` knownSteps) $
    assertFailure
      ("unknown assertion anchors in " <> Text.unpack (scenarioId scenario)
        <> ": " <> renderSet (anchors Set.\\ knownSteps))

assertUnique :: Ord a => String -> [a] -> Assertion
assertUnique label values =
  assertBool
    (label <> " contain duplicates")
    (length values == Set.size (Set.fromList values))

artifactContractTest :: Maybe FilePath -> Artifact -> TestTree
artifactContractTest driver artifact =
  testCase (artifactName artifact) $ do
    let request = object
          [ "protocol_version" .= (1 :: Int)
          , "request_kind" .= ("allium_plan" :: Text)
          , "module" .= artifactName artifact
          , "plan" .= artifactPlan artifact
          , "model" .= artifactModel artifact
          ]
    runDriverAndValidate
      driver
      ("Allium module " <> artifactName artifact)
      (artifactObligationIds artifact)
      request

scenarioContractTest :: Maybe FilePath -> Scenario -> TestTree
scenarioContractTest driver scenario =
  testCase
    (Text.unpack (scenarioId scenario <> " — " <> scenarioTitle scenario)) $ do
      let request = object
            [ "protocol_version" .= (1 :: Int)
            , "request_kind" .= ("scenario" :: Text)
            , "scenario" .= scenarioValue scenario
            ]
      runDriverAndValidate
        driver
        ("scenario " <> Text.unpack (scenarioId scenario))
        (scenarioAssertionIds scenario)
        request

runDriverAndValidate ::
  Maybe FilePath ->
  String ->
  [Text] ->
  Value ->
  Assertion
runDriverAndValidate configuredDriver label expectedIds request = do
  executable <- resolveDriver configuredDriver
  (exitCode, stdoutText, stderrText) <-
    readProcessWithExitCode
      executable
      []
      (Text.unpack (TextEncoding.decodeUtf8 (LBS.toStrict (encode request))))
  case exitCode of
    ExitFailure code ->
      assertFailure
        (label <> ": driver exited " <> show code <> "\n" <> stderrText)
    ExitSuccess -> pure ()
  response <- case
      eitherDecodeStrict'
        (TextEncoding.encodeUtf8 (Text.pack stdoutText)) of
    Left problem ->
      failAssertion
        (label <> ": invalid driver JSON: " <> problem
          <> "\nstdout: " <> stdoutText
          <> "\nstderr: " <> stderrText)
    Right value -> pure value
  validateResponse label expectedIds response

resolveDriver :: Maybe FilePath -> IO FilePath
resolveDriver = \case
  Nothing ->
    failAssertion
      "LANT_V1_TEST_DRIVER is not set; the v1 implementation bridge is absent"
  Just configured -> do
    direct <- doesFileExist configured
    if direct
      then pure configured
      else findExecutable configured >>= \case
        Just executable -> pure executable
        Nothing ->
          failAssertion
            ("LANT_V1_TEST_DRIVER is not executable or on PATH: "
              <> configured)

validateResponse :: String -> [Text] -> DriverResponse -> Assertion
validateResponse label expectedIds response = do
  responseProtocolVersion response @?= 1
  let results = responseResults response
      actualIds = map resultId results
      expected = Set.fromList expectedIds
      actual = Set.fromList actualIds
      failures =
        [ resultId result <> maybe "" (": " <>) (resultDetail result)
        | result <- results
        , not (resultPassed result)
        ]
  assertUnique (label <> " result IDs") actualIds
  unless (actual == expected) $
    assertFailure
      (label <> ": result ID mismatch"
        <> "\nmissing: " <> renderSet (expected Set.\\ actual)
        <> "\nunexpected: " <> renderSet (actual Set.\\ expected))
  unless (null failures) $
    assertFailure
      (label <> ": failed assertions\n"
        <> Text.unpack (Text.unlines failures))
  unless (responseOk response) $
    assertFailure
      (label <> ": driver reported ok=false\n"
        <> Text.unpack (Text.unlines (responseDiagnostics response)))

renderSet :: Set.Set Text -> String
renderSet values =
  Text.unpack (Text.intercalate ", " (Set.toAscList values))

failAssertion :: String -> IO a
failAssertion message = do
  _ <- assertFailure message
  fail message

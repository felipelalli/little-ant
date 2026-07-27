{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE RankNTypes #-}

-- | Reusable protocol and scenario runner for the Little Ant 1.0 contract.
--
-- The runner deliberately knows how to execute a contract, but not how to
-- satisfy one.  Domain modules register probes and operations by construct
-- name.  Missing registrations are reported as failures while requested
-- result identifiers are preserved.
module LittleAnt.V1.Contract
  ( AmbientInputs (..)
  , AssertionOperator
  , ContractRegistry (..)
  , DriverResponse (..)
  , Fixture
  , Observation
  , ObservationInput (..)
  , OperationInput (..)
  , OperationResult (..)
  , PathSelector
  , PlanProbe
  , PlanProbeInput (..)
  , ProbeKey (..)
  , ReferenceInput (..)
  , ReferenceResolver
  , ReferenceSnapshot (..)
  , ResultItem (..)
  , ScenarioOperation
  , decodeAndRunContractRequest
  , emptyContractRegistry
  , evaluateAssertionOperator
  , runContractRequest
  , selectJsonPath
  , standardAssertionOperators
  ) where

import Control.Monad (foldM, unless, when)
import Data.Aeson
  (Object, Result (..), ToJSON (toJSON), Value (..), eitherDecode, encode,
   fromJSON, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as LBS
import Data.Foldable (toList)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Text.Read (readMaybe)

-- | Ambient values pinned by a scenario.  Operations receive these values
-- explicitly, so implementations do not need to consult wall clock or random
-- process state while a contract is running.
data AmbientInputs = AmbientInputs
  { ambientClock :: Maybe Value
  , ambientRandomEvidence :: Maybe Value
  , ambientParameterOverrides :: Maybe Value
  }
  deriving stock (Eq, Show)

-- | Input shared by a scenario operation and a fixture.
data OperationInput = OperationInput
  { operationStepId :: Text
  , operationName :: Text
  , operationArguments :: Value
  , operationAmbient :: AmbientInputs
  }
  deriving stock (Eq, Show)

-- | A scenario operation returns its public result and the next isolated
-- domain state.
data OperationResult state = OperationResult
  { operationResultValue :: Value
  , operationResultState :: state
  }
  deriving stock (Eq, Show)

-- | A named scenario operation.
type ScenarioOperation state =
  OperationInput -> state -> Either Text (OperationResult state)

-- | A named fixture.  Fixtures have the same shape as operations so a fixture
-- can augment an already-created isolated scenario state.
type Fixture state =
  OperationInput -> state -> Either Text (OperationResult state)

-- | Parsed input to a read-only named observation.
data ObservationInput = ObservationInput
  { observationName :: Text
  , observationArguments :: [Value]
  , observationAmbient :: AmbientInputs
  }
  deriving stock (Eq, Show)

-- | A read-only scenario observation.
type Observation state = ObservationInput -> state -> Either Text Value

-- | A model-backed conformance probe is selected by semantic Allium metadata,
-- never by an obligation ID.
data ProbeKey = ProbeKey
  { probeModule :: Text
  , probeCategory :: Text
  , probeSourceConstruct :: Text
  }
  deriving stock (Eq, Ord, Show)

-- | Data made available to an Allium conformance probe.
data PlanProbeInput = PlanProbeInput
  { planProbeModule :: Text
  , planProbeCategory :: Text
  , planProbeSourceConstruct :: Text
  , planProbeObligation :: Value
  , planProbeModel :: Value
  }
  deriving stock (Eq, Show)

-- | A successful probe returns 'Right ()'; a failed probe explains why.
type PlanProbe = PlanProbeInput -> Either Text ()

-- | A custom path selector.  Ordinary object/array paths are handled by
-- 'selectJsonPath'; this registry is for implementation-specific projections.
type PathSelector = Value -> Either Text Value

-- | Assertion operators receive the selected actual value, an optional
-- expected value, and the complete assertion object for operator-specific
-- metadata such as tolerance and nested paths.
type AssertionOperator = Value -> Maybe Value -> Object -> Either Text ()

-- | State and symbolic bindings visible at a scenario checkpoint.
data ReferenceSnapshot state = ReferenceSnapshot
  { referenceSnapshotState :: state
  , referenceSnapshotBindings :: Map Text Value
  }
  deriving stock (Eq, Show)

-- | Context passed to an implementation-defined @value_from@ resolver.
--
-- Resolvers are selected by the namespace before the first colon in the
-- source text.  They can inspect immutable checkpoints and already-resolved
-- bindings, but cannot mutate scenario state.
data ReferenceInput state = ReferenceInput
  { referenceInputSource :: Text
  , referenceInputAssertion :: Object
  , referenceInputCurrent :: ReferenceSnapshot state
  , referenceInputCheckpoints :: Map Text (ReferenceSnapshot state)
  , referenceInputAmbient :: AmbientInputs
  }
  deriving stock (Eq, Show)

-- | Resolve one implementation-defined @value_from@ source.
type ReferenceResolver state = ReferenceInput state -> Either Text Value

-- | All extension points used by the generic bridge.
data ContractRegistry state = ContractRegistry
  { registryInitialState :: AmbientInputs -> state
  , registryPlanProbes :: Map ProbeKey PlanProbe
  , registryOperations :: Map Text (ScenarioOperation state)
  , registryObservations :: Map Text (Observation state)
  , registryFixtures :: Map Text (Fixture state)
  , registryReferences :: Map Text (ReferenceResolver state)
  , registryPaths :: Map Text PathSelector
  , registryAssertionOperators :: Map Text AssertionOperator
  }

-- | One protocol result.  The ID always comes from the request.
data ResultItem = ResultItem
  { resultItemId :: Text
  , resultItemPassed :: Bool
  , resultItemDetail :: Maybe Text
  }
  deriving stock (Eq, Show)

instance ToJSON ResultItem where
  toJSON result = object
    [ "id" .= resultItemId result
    , "passed" .= resultItemPassed result
    , "detail" .= resultItemDetail result
    ]

-- | Version-one driver response.
data DriverResponse = DriverResponse
  { driverResponseProtocolVersion :: Int
  , driverResponseOk :: Bool
  , driverResponseResults :: [ResultItem]
  , driverResponseDiagnostics :: [Text]
  }
  deriving stock (Eq, Show)

instance ToJSON DriverResponse where
  toJSON response = object
    [ "protocol_version" .= driverResponseProtocolVersion response
    , "ok" .= driverResponseOk response
    , "results" .= driverResponseResults response
    , "diagnostics" .= driverResponseDiagnostics response
    ]

-- | A registry with no implementation behavior and with all standard
-- comparison operators installed.  It is an honest-red starting point.
emptyContractRegistry :: state -> ContractRegistry state
emptyContractRegistry initialState = ContractRegistry
  { registryInitialState = const initialState
  , registryPlanProbes = Map.empty
  , registryOperations = Map.empty
  , registryObservations = Map.empty
  , registryFixtures = Map.empty
  , registryReferences = Map.empty
  , registryPaths = Map.empty
  , registryAssertionOperators = standardAssertionOperators
  }

-- | Decode exactly one JSON value and run it.  Aeson accepts trailing JSON
-- whitespace but rejects a second value, which enforces the one-request rule.
decodeAndRunContractRequest ::
  ContractRegistry state -> LBS.ByteString -> DriverResponse
decodeAndRunContractRequest registry bytes =
  case eitherDecode bytes of
    Left problem -> protocolFailure ("invalid JSON request: " <> Text.pack problem)
    Right request -> runContractRequest registry request

-- | Run one decoded protocol request.
runContractRequest :: ContractRegistry state -> Value -> DriverResponse
runContractRequest registry request =
  case request of
    Object requestObject ->
      case requiredInt "protocol_version" requestObject of
        Left problem -> protocolFailure problem
        Right version
          | version /= 1 ->
              protocolFailure
                ("unsupported protocol_version: " <> Text.pack (show version))
          | otherwise ->
              case requiredText "request_kind" requestObject of
                Left problem -> protocolFailure problem
                Right "allium_plan" -> runPlanRequest registry requestObject
                Right "scenario" -> runScenarioRequest registry requestObject
                Right requestKind ->
                  protocolFailure ("unknown request_kind: " <> requestKind)
    _ -> protocolFailure "request must be a JSON object"

protocolFailure :: Text -> DriverResponse
protocolFailure problem = DriverResponse
  { driverResponseProtocolVersion = 1
  , driverResponseOk = False
  , driverResponseResults = []
  , driverResponseDiagnostics = [problem]
  }

runPlanRequest :: ContractRegistry state -> Object -> DriverResponse
runPlanRequest registry request =
  case (requiredText "module" request, requiredValue "plan" request,
        requiredValue "model" request) of
    (Right moduleName, Right planValue, Right modelValue) ->
      case identifiedObjects "obligations" planValue of
        Left problem -> protocolFailure problem
        Right (obligations, duplicateIds) ->
          let results = map (runPlanProbe registry moduleName modelValue) obligations
              duplicateDiagnostics =
                [ "duplicate obligation IDs were collapsed: "
                    <> Text.intercalate ", " duplicateIds
                | not (null duplicateIds)
                ]
              passed = all resultItemPassed results
          in DriverResponse
              { driverResponseProtocolVersion = 1
              , driverResponseOk = passed && null duplicateIds
              , driverResponseResults = results
              , driverResponseDiagnostics = duplicateDiagnostics
              }
    (Left problem, _, _) -> protocolFailure problem
    (_, Left problem, _) -> protocolFailure problem
    (_, _, Left problem) -> protocolFailure problem

runPlanProbe ::
  ContractRegistry state -> Text -> Value -> (Text, Object) -> ResultItem
runPlanProbe registry moduleName modelValue (identifier, obligation) =
  case (requiredText "category" obligation,
        requiredText "source_construct" obligation) of
    (Right category, Right construct) ->
      let key = ProbeKey moduleName category construct
          input = PlanProbeInput
            { planProbeModule = moduleName
            , planProbeCategory = category
            , planProbeSourceConstruct = construct
            , planProbeObligation = Object obligation
            , planProbeModel = modelValue
            }
      in case Map.lookup key (registryPlanProbes registry) of
          Nothing -> failedItem identifier
            ("unregistered Allium construct: " <> renderProbeKey key)
          Just probe ->
            case probe input of
              Left problem -> failedItem identifier problem
              Right () -> passedItem identifier
    (Left problem, _) -> failedItem identifier problem
    (_, Left problem) -> failedItem identifier problem

renderProbeKey :: ProbeKey -> Text
renderProbeKey key = Text.intercalate "/"
  [probeModule key, probeCategory key, probeSourceConstruct key]

-- Internal scenario state.  Haskell values are immutable, so retaining a
-- state value is a real checkpoint rather than a lossy serialization.
data Checkpoint state = Checkpoint
  { checkpointState :: state
  , checkpointBindings :: Map Text Value
  }

data ScenarioRuntime state = ScenarioRuntime
  { runtimeState :: state
  , runtimeBindings :: Map Text Value
  , runtimeCheckpoints :: Map Text (Checkpoint state)
  , runtimeAmbient :: AmbientInputs
  }

runScenarioRequest :: ContractRegistry state -> Object -> DriverResponse
runScenarioRequest registry request =
  case requiredValue "scenario" request of
    Left problem -> protocolFailure problem
    Right (Object scenario) ->
      case (requiredArray "steps" scenario, requiredArray "assertions" scenario) of
        (Right steps, Right assertions) ->
          let ambient = ambientFromScenario scenario
              initial = ScenarioRuntime
                { runtimeState = registryInitialState registry ambient
                , runtimeBindings = Map.empty
                , runtimeCheckpoints = Map.empty
                , runtimeAmbient = ambient
                }
              (afterSteps, stepProblems) = runScenarioSteps registry initial steps
              (identifiedAssertions, malformedProblems, duplicateIds) =
                identifyScenarioAssertions assertions
              results =
                [ if null stepProblems
                    then runScenarioAssertion registry afterSteps identifier assertion
                    else failedItem identifier
                      ("scenario setup failed: " <> Text.intercalate "; " stepProblems)
                | (identifier, assertion) <- identifiedAssertions
                ]
              diagnostics = malformedProblems <>
                [ "duplicate assertion IDs were collapsed: "
                    <> Text.intercalate ", " duplicateIds
                | not (null duplicateIds)
                ]
              passed = all resultItemPassed results
          in DriverResponse
              { driverResponseProtocolVersion = 1
              , driverResponseOk = passed && null diagnostics
              , driverResponseResults = results
              , driverResponseDiagnostics = diagnostics
              }
        (Left problem, _) -> protocolFailure problem
        (_, Left problem) -> protocolFailure problem
    Right _ -> protocolFailure "scenario must be a JSON object"

ambientFromScenario :: Object -> AmbientInputs
ambientFromScenario scenario = AmbientInputs
  { ambientClock = optionalNonNull "clock" scenario
  , ambientRandomEvidence = optionalNonNull "random_evidence" scenario
  , ambientParameterOverrides = optionalNonNull "parameter_overrides" scenario
  }

runScenarioSteps ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  [Value] ->
  (ScenarioRuntime state, [Text])
runScenarioSteps registry initial = foldl' runOne (initial, [])
  where
    runOne (runtime, problems) stepValue =
      case stepValue of
        Object step ->
          case (requiredText "id" step, requiredText "operation" step) of
            (Right stepId, Right operationNameValue) ->
              let beforeKey = "before:" <> stepId
                  withBefore = runtime
                    { runtimeCheckpoints = Map.insert beforeKey
                        (runtimeCheckpoint runtime)
                        (runtimeCheckpoints runtime)
                    }
              in case executeNamedOperation
                    registry withBefore stepId operationNameValue
                    (fromMaybe (Object KeyMap.empty)
                      (optionalNonNull "arguments" step)) of
                  Left problem ->
                    let withAfter = withBefore
                          { runtimeCheckpoints = Map.insert ("after:" <> stepId)
                              (runtimeCheckpoint withBefore)
                              (runtimeCheckpoints withBefore)
                          }
                    in (withAfter, problems <>
                          ["step " <> stepId <> ": " <> problem])
                  Right (resultValue, nextState) ->
                    case applyStepBindings step resultValue withBefore
                          { runtimeState = nextState } of
                      Left problem ->
                        let nextRuntime = withBefore {runtimeState = nextState}
                            withAfter = nextRuntime
                              { runtimeCheckpoints = Map.insert
                                  ("after:" <> stepId)
                                  (runtimeCheckpoint nextRuntime)
                                  (runtimeCheckpoints nextRuntime)
                              }
                        in (withAfter, problems <>
                              ["step " <> stepId <> ": " <> problem])
                      Right boundRuntime ->
                        let withAfter = boundRuntime
                              { runtimeCheckpoints = Map.insert
                                  ("after:" <> stepId)
                                  (runtimeCheckpoint boundRuntime)
                                  (runtimeCheckpoints boundRuntime)
                              }
                        in (withAfter, problems)
            (Left problem, _) -> (runtime, problems <> [problem])
            (_, Left problem) -> (runtime, problems <> [problem])
        _ -> (runtime, problems <> ["scenario step must be an object"])

runtimeCheckpoint :: ScenarioRuntime state -> Checkpoint state
runtimeCheckpoint runtime = Checkpoint
  { checkpointState = runtimeState runtime
  , checkpointBindings = runtimeBindings runtime
  }

executeNamedOperation ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Text ->
  Text ->
  Value ->
  Either Text (Value, state)
executeNamedOperation registry runtime stepId name unresolvedArguments = do
  arguments <- resolveValue registry runtime (runtimeCheckpoint runtime)
    unresolvedArguments
  let input = OperationInput
        { operationStepId = stepId
        , operationName = name
        , operationArguments = arguments
        , operationAmbient = runtimeAmbient runtime
        }
  operation <-
    if name == "CreateFixture"
      then do
        fixtureName <- case arguments of
          Object argumentObject -> requiredText "fixture" argumentObject
          _ -> Left "CreateFixture arguments must be an object"
        maybe
          (Left ("unregistered fixture: " <> fixtureName))
          Right
          (Map.lookup fixtureName (registryFixtures registry))
      else maybe
        (Left ("unregistered operation: " <> name))
        Right
        (Map.lookup name (registryOperations registry))
  result <- operation input (runtimeState runtime)
  pure (operationResultValue result, operationResultState result)

applyStepBindings ::
  Object -> Value -> ScenarioRuntime state -> Either Text (ScenarioRuntime state)
applyStepBindings step resultValue runtime = do
  withComplete <- case optionalNonNull "bind" step of
    Nothing -> Right runtime
    Just (String binding) -> insertBinding binding resultValue runtime
    Just _ -> Left "bind must be a symbolic name"
  case optionalNonNull "bind_result" step of
    Nothing -> Right withComplete
    Just (Object requestedBindings) ->
      foldM (bindResultField resultValue) withComplete
        (KeyMap.toList requestedBindings)
    Just _ -> Left "bind_result must be an object"

bindResultField ::
  Value -> ScenarioRuntime state -> (Key.Key, Value) ->
  Either Text (ScenarioRuntime state)
bindResultField resultValue runtime (fieldKey, bindingSpec) = do
  fieldValue <- case resultValue of
    Object resultObject ->
      maybe
        (Left ("bind_result field is absent: " <> Key.toText fieldKey))
        Right
        (KeyMap.lookup fieldKey resultObject)
    _ -> Left "bind_result requires an object operation result"
  case bindingSpec of
    String binding -> insertBinding binding fieldValue runtime
    Array names -> case fieldValue of
      Array values
        | length names == length values ->
            foldM bindPair runtime (zip (toList names) (toList values))
        | otherwise -> Left
            ("bind_result array length differs for field: "
              <> Key.toText fieldKey)
      _ -> Left ("bind_result field is not an array: " <> Key.toText fieldKey)
    _ -> Left ("invalid bind_result target for field: " <> Key.toText fieldKey)
  where
    bindPair current (String binding, value) = insertBinding binding value current
    bindPair _ _ = Left "bind_result array targets must be symbolic names"

insertBinding ::
  Text -> Value -> ScenarioRuntime state -> Either Text (ScenarioRuntime state)
insertBinding binding value runtime
  | Text.null binding = Left "binding name cannot be empty"
  | Text.isPrefixOf "$" binding = Left "binding name must not include '$'"
  | Map.member binding (runtimeBindings runtime) =
      Left ("duplicate binding: $" <> binding)
  | otherwise = Right runtime
      { runtimeBindings = Map.insert binding value (runtimeBindings runtime) }

identifyScenarioAssertions ::
  [Value] -> ([(Text, Object)], [Text], [Text])
identifyScenarioAssertions values =
  let (identified, malformed) = foldl' collect ([], []) values
      (unique, duplicates) = uniqueIdentified identified
  in (unique, reverse malformed, duplicates)
  where
    collect (items, problems) = \case
      Object assertion -> case requiredText "id" assertion of
        Left problem -> (items, problem : problems)
        Right identifier -> (items <> [(identifier, assertion)], problems)
      _ -> (items, "scenario assertion must be an object" : problems)

runScenarioAssertion ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Text ->
  Object ->
  ResultItem
runScenarioAssertion registry runtime identifier assertion =
  case evaluateScenarioAssertion registry runtime assertion of
    Left problem -> failedItem identifier problem
    Right () -> passedItem identifier

evaluateScenarioAssertion ::
  ContractRegistry state -> ScenarioRuntime state -> Object -> Either Text ()
evaluateScenarioAssertion registry runtime assertion = do
  checkpoint <- assertionCheckpoint registry runtime assertion
  actual <- evaluateAssertionSubject registry runtime checkpoint assertion
  selected <- case optionalNonNull "path" assertion of
    Nothing -> Right actual
    Just (String path) -> selectRegisteredPath registry path actual
    Just _ -> Left "assertion path must be text"
  operatorNameValue <- requiredText "operator" assertion
  operator <- maybe
    (Left ("unregistered assertion operator: " <> operatorNameValue))
    Right
    (Map.lookup operatorNameValue (registryAssertionOperators registry))
  expected <- assertionExpected registry runtime checkpoint assertion
  operator selected expected assertion

assertionCheckpoint ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Object ->
  Either Text (Checkpoint state)
assertionCheckpoint registry runtime assertion =
  case optionalNonNull "fixture" assertion of
    Just (String fixtureName) -> do
      fixture <- maybe
        (Left ("unregistered fixture: " <> fixtureName))
        Right
        (Map.lookup fixtureName (registryFixtures registry))
      let initialState = registryInitialState registry (runtimeAmbient runtime)
          input = OperationInput
            { operationStepId = "assertion-fixture"
            , operationName = "CreateFixture"
            , operationArguments = object ["fixture" .= fixtureName]
            , operationAmbient = runtimeAmbient runtime
            }
      result <- fixture input initialState
      pure Checkpoint
        { checkpointState = operationResultState result
        , checkpointBindings = Map.empty
        }
    Just _ -> Left "assertion fixture must be text"
    Nothing ->
      case assertionAnchor assertion of
        Nothing -> Right (runtimeCheckpoint runtime)
        Just key -> maybe
          (Left ("unknown checkpoint: " <> key))
          Right
          (Map.lookup key (runtimeCheckpoints runtime))

assertionAnchor :: Object -> Maybe Text
assertionAnchor assertion =
  case optionalNonNull "after" assertion of
    Just (String stepId) -> Just ("after:" <> stepId)
    Just _ -> Just "<invalid-after>"
    Nothing -> case optionalNonNull "at" assertion of
      Just (String atValue) -> Just atValue
      Just _ -> Just "<invalid-at>"
      Nothing -> Nothing

evaluateAssertionSubject ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Object ->
  Either Text Value
evaluateAssertionSubject registry runtime checkpoint assertion = do
  (operationValue, stateAfterOperation) <-
    case optionalNonNull "operation" assertion of
      Nothing -> Right (Nothing, checkpointState checkpoint)
      Just (String operationNameValue) -> do
        let atCheckpoint = runtime
              { runtimeState = checkpointState checkpoint
              , runtimeBindings = checkpointBindings checkpoint
              }
        (resultValue, nextState) <- executeNamedOperation
          registry atCheckpoint (assertionIdentifier assertion)
          operationNameValue
          (fromMaybe (Object KeyMap.empty)
            (optionalNonNull "arguments" assertion))
        Right (Just resultValue, nextState)
      Just _ -> Left "assertion operation must be text"
  case optionalNonNull "query" assertion of
    Just (String queryText) ->
      executeObservation registry runtime checkpoint
        {checkpointState = stateAfterOperation} queryText
    Just _ -> Left "assertion query must be text"
    Nothing -> maybe
      (Left "assertion must declare an operation or query")
      Right
      operationValue

assertionIdentifier :: Object -> Text
assertionIdentifier assertion =
  either (const "assertion-operation") id (requiredText "id" assertion)

executeObservation ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Text ->
  Either Text Value
executeObservation registry runtime checkpoint queryText = do
  (name, rawArguments, trailingPath) <- parseQuery queryText
  arguments <- mapM (resolveQueryArgument registry runtime checkpoint) rawArguments
  observation <- maybe
    (Left ("unregistered observation: " <> name))
    Right
    (Map.lookup name (registryObservations registry))
  observed <- observation ObservationInput
    { observationName = name
    , observationArguments = arguments
    , observationAmbient = runtimeAmbient runtime
    } (checkpointState checkpoint)
  maybe (Right observed) (\path -> selectRegisteredPath registry path observed)
    trailingPath

parseQuery :: Text -> Either Text (Text, [Text], Maybe Text)
parseQuery queryText =
  let stripped = Text.strip queryText
      (name, remainder) = Text.breakOn "(" stripped
  in if Text.null remainder
      then if Text.null name
        then Left "empty observation"
        else Right (name, [], Nothing)
      else do
        when (Text.null name) (Left "observation name is empty")
        let afterOpen = Text.drop 1 remainder
            (argumentsText, afterClose) = Text.breakOn ")" afterOpen
        when (Text.null afterClose) (Left ("malformed observation: " <> queryText))
        let suffix = Text.drop 1 afterClose
        trailingPath <- if Text.null suffix
          then Right Nothing
          else case Text.stripPrefix "." suffix of
            Nothing -> Left ("malformed observation suffix: " <> suffix)
            Just path | Text.null path -> Left "empty observation suffix path"
                      | otherwise -> Right (Just path)
        let arguments =
              if Text.null (Text.strip argumentsText)
                then []
                else map Text.strip (Text.splitOn "," argumentsText)
        Right (Text.strip name, arguments, trailingPath)

resolveQueryArgument ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Text ->
  Either Text Value
resolveQueryArgument registry runtime checkpoint argument
  | Text.isPrefixOf "$" argument =
      resolveReference registry runtime checkpoint argument
  | otherwise =
      case eitherDecode (LBS.fromStrict (TextEncoding.encodeUtf8 argument)) of
        Right value -> Right value
        Left _ -> Right (String argument)

resolveValue ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Value ->
  Either Text Value
resolveValue registry runtime checkpoint = \case
  String value | Text.isPrefixOf "$" value ->
    resolveReference registry runtime checkpoint value
  Array values -> toJSON <$> mapM
    (resolveValue registry runtime checkpoint) (toList values)
  Object values -> Object . KeyMap.fromList <$> mapM resolveEntry
    (KeyMap.toList values)
  value -> Right value
  where
    resolveEntry (key, value) = do
      resolved <- resolveValue registry runtime checkpoint value
      pure (key, resolved)

resolveReference ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Text ->
  Either Text Value
resolveReference registry runtime checkpoint reference = do
  let withoutDollar = Text.drop 1 reference
      (bindingName, suffix) = Text.breakOn "." withoutDollar
  base <- case Map.lookup bindingName (checkpointBindings checkpoint) of
    Just value -> Right value
    Nothing -> resolveDynamicReference registry runtime checkpoint bindingName
  if Text.null suffix
    then Right base
    else selectRegisteredPath registry (Text.drop 1 suffix) base

resolveDynamicReference ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Text ->
  Either Text Value
resolveDynamicReference registry runtime checkpoint name
  | name == "current_domain_revision" =
      executeObservation registry runtime checkpoint "DomainRevision"
  | Just stepId <- Text.stripPrefix "current_domain_revision_at:" name = do
      atStep <- maybe
        (Left ("unknown checkpoint: after:" <> stepId))
        Right
        (Map.lookup ("after:" <> stepId) (runtimeCheckpoints runtime))
      executeObservation registry runtime atStep "DomainRevision"
  | otherwise = Left ("unregistered reference: $" <> name)

assertionExpected ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Object ->
  Either Text (Maybe Value)
assertionExpected registry runtime checkpoint assertion =
  case (optionalNonNull "value" assertion, optionalNonNull "value_from" assertion) of
    (Just _, Just _) -> Left "assertion declares both value and value_from"
    (Just value, Nothing) ->
      Just <$> resolveExpectedValue registry runtime checkpoint assertion value
    (Nothing, Just (String source)) ->
      Just <$> resolveValueFrom registry runtime checkpoint assertion source
    (Nothing, Just _) -> Left "value_from must be text"
    (Nothing, Nothing) -> Right Nothing

resolveExpectedValue ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Object ->
  Value ->
  Either Text Value
resolveExpectedValue registry runtime checkpoint assertion value =
  case requiredText "operator" assertion of
    Right "equals_expression" -> evaluateSimpleExpression
      registry runtime checkpoint value
    operatorResult -> do
      resolved <- resolveValue registry runtime checkpoint value
      case operatorResult of
        Right "equals_reference" -> case resolved of
          String expression | Text.isInfixOf "(" expression ->
            executeObservation registry runtime checkpoint expression
          _ -> Right resolved
        _ -> Right resolved

resolveValueFrom ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Object ->
  Text ->
  Either Text Value
resolveValueFrom registry runtime checkpoint assertion source
  | Text.isPrefixOf "$" source =
      resolveReference registry runtime checkpoint source
  | Just _ <- Text.stripPrefix "before:" source = snapshotAt source
  | Just _ <- Text.stripPrefix "after:" source = snapshotAt source
  | Text.isInfixOf "(" source = executeObservation registry runtime checkpoint source
  | otherwise = resolveRegisteredReference
  where
    snapshotAt key = do
      snapshot <- maybe
        (Left ("unknown checkpoint: " <> key))
        Right
        (Map.lookup key (runtimeCheckpoints runtime))
      value <- evaluateSnapshotSubject registry runtime snapshot assertion
      case optionalNonNull "path" assertion of
        Nothing -> Right value
        Just (String path) -> selectRegisteredPath registry path value
        Just _ -> Left "assertion path must be text"

    resolveRegisteredReference = do
      let (namespace, _) = Text.breakOn ":" source
      resolver <- maybe
        (Left ("unregistered value_from reference: " <> source))
        Right
        (Map.lookup namespace (registryReferences registry))
      resolver ReferenceInput
        { referenceInputSource = source
        , referenceInputAssertion = assertion
        , referenceInputCurrent = referenceSnapshot checkpoint
        , referenceInputCheckpoints =
            Map.map referenceSnapshot (runtimeCheckpoints runtime)
        , referenceInputAmbient = runtimeAmbient runtime
        }

-- Snapshot expectations observe the checkpoint directly.  In particular,
-- they do not repeat an assertion's operation: an operation such as replay
-- transforms only the actual side before the shared query is evaluated.
evaluateSnapshotSubject ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Object ->
  Either Text Value
evaluateSnapshotSubject registry runtime checkpoint assertion =
  case optionalNonNull "query" assertion of
    Just (String queryText) ->
      executeObservation registry runtime checkpoint queryText
    Just _ -> Left "assertion query must be text"
    Nothing -> Left "snapshot comparison requires an assertion query"

referenceSnapshot :: Checkpoint state -> ReferenceSnapshot state
referenceSnapshot checkpoint = ReferenceSnapshot
  { referenceSnapshotState = checkpointState checkpoint
  , referenceSnapshotBindings = checkpointBindings checkpoint
  }

evaluateSimpleExpression ::
  ContractRegistry state ->
  ScenarioRuntime state ->
  Checkpoint state ->
  Value ->
  Either Text Value
evaluateSimpleExpression registry runtime checkpoint = \case
  String expression -> case Text.words expression of
    [reference, "+", amountText] -> do
      base <- resolveReference registry runtime checkpoint reference
      amount <- decodeNumber amountText
      case (base, amount) of
        (Number left, Number right) -> Right (Number (left + right))
        _ -> Left "equals_expression addition requires numbers"
    [reference, "-", amountText] -> do
      base <- resolveReference registry runtime checkpoint reference
      amount <- decodeNumber amountText
      case (base, amount) of
        (Number left, Number right) -> Right (Number (left - right))
        _ -> Left "equals_expression subtraction requires numbers"
    _ -> Left ("unsupported equals_expression: " <> expression)
  _ -> Left "equals_expression value must be text"
  where
    decodeNumber textValue =
      case eitherDecode (LBS.fromStrict (TextEncoding.encodeUtf8 textValue)) of
        Right value@(Number _) -> Right value
        _ -> Left ("invalid numeric expression operand: " <> textValue)

selectRegisteredPath ::
  ContractRegistry state -> Text -> Value -> Either Text Value
selectRegisteredPath registry path value =
  case Map.lookup path (registryPaths registry) of
    Just selector -> selector value
    Nothing -> selectJsonPath path value

-- | Select a dotted JSON object/array path.  Arrays support numeric indices as
-- well as @first@ and @last@.  A nonexistent segment is an error, not null.
selectJsonPath :: Text -> Value -> Either Text Value
selectJsonPath path value
  | Text.null path = Left "path cannot be empty"
  | otherwise = foldM selectSegment value (Text.splitOn "." path)
  where
    selectSegment (Object objectValue) segment = maybe
      (Left ("unknown path segment: " <> segment))
      Right
      (KeyMap.lookup (Key.fromText segment) objectValue)
    selectSegment (Array arrayValue) "first" =
      case toList arrayValue of
        [] -> Left "cannot select first from an empty array"
        firstValue : _ -> Right firstValue
    selectSegment (Array arrayValue) "last" =
      case reverse (toList arrayValue) of
        [] -> Left "cannot select last from an empty array"
        lastValue : _ -> Right lastValue
    selectSegment (Array arrayValue) segment =
      case readMaybe (Text.unpack segment) of
        Just index
          | index >= (0 :: Int) ->
              case drop index (toList arrayValue) of
                selected : _ -> Right selected
                [] -> Left ("unknown array path segment: " <> segment)
        _ -> Left ("unknown array path segment: " <> segment)
    selectSegment _ segment = Left
      ("cannot select path segment from scalar: " <> segment)

-- | All comparison operators declared by the checked-in v1 scenarios.
standardAssertionOperators :: Map Text AssertionOperator
standardAssertionOperators = Map.fromList
  [ ("all_equal", allEqualOperator)
  , ("all_match", allMatchOperator)
  , ("all_omit", allOmitOperator)
  , ("all_unique_by", uniqueByOperator)
  , ("all_within_absolute_tolerance", toleranceOperator)
  , ("between_inclusive", betweenOperator)
  , ("contains", binaryExpected "contains" valueContains)
  , ("contains_all", binaryExpected "contains_all" containsAll)
  , ("contains_once", binaryExpected "contains_once" containsOnce)
  , ("contains_references", binaryExpected "contains_references" containsAll)
  , ("count_equals", countEqualsOperator)
  , ("equals", binaryExpected "equals" (==))
  , ("equals_expression", binaryExpected "equals_expression" (==))
  , ("equals_reference", binaryExpected "equals_reference" (==))
  , ("equals_set", equalsSetOperator)
  , ("equals_snapshot", binaryExpected "equals_snapshot" (==))
  , ("greater_than", orderingOperator "greater_than" (>))
  , ("is_null", nullOperator)
  , ("less_than", orderingOperator "less_than" (<))
  , ("not_contains", binaryExpected "not_contains"
      (\actual expected -> not (valueContains actual expected)))
  , ("not_empty", notEmptyOperator)
  , ("not_equals", binaryExpected "not_equals" (/=))
  , ("omits", omitsOperator)
  , ("omits_paths", omitsOperator)
  , ("rejected_with", rejectedWithOperator)
  , ("results_in", binaryExpected "results_in" valueContains)
  , ("schema_presence_matches_projection", schemaPresenceOperator)
  , ("unique_by", uniqueByOperator)
  ]

-- | Invoke an operator registry directly.  This is useful for adapter tests
-- and keeps comparison behavior independent from obligation/assertion IDs.
evaluateAssertionOperator ::
  Map Text AssertionOperator ->
  Text ->
  Value ->
  Maybe Value ->
  Object ->
  Either Text ()
evaluateAssertionOperator operators name actual expected assertion = do
  operator <- maybe
    (Left ("unregistered assertion operator: " <> name))
    Right
    (Map.lookup name operators)
  operator actual expected assertion

binaryExpected ::
  Text -> (Value -> Value -> Bool) -> AssertionOperator
binaryExpected name predicate actual expected _ = do
  expectedValue <- requireExpected name expected
  unless (predicate actual expectedValue)
    (Left (name <> " comparison failed"))

requireExpected :: Text -> Maybe Value -> Either Text Value
requireExpected name = maybe
  (Left (name <> " requires value or value_from"))
  Right

valueContains :: Value -> Value -> Bool
valueContains actual expected = case (actual, expected) of
  (Object actualObject, Object expectedObject) ->
    all (objectEntryContained actualObject) (KeyMap.toList expectedObject)
  (Object actualObject, _) ->
    any (`valueContains` expected) (KeyMap.elems actualObject)
  (Array actualValues, _) -> any (`valueContains` expected) (toList actualValues)
  (String actualText, String expectedText) -> expectedText `Text.isInfixOf` actualText
  _ -> actual == expected
  where
    objectEntryContained actualObject (key, expectedValue) =
      maybe False (`valueContains` expectedValue) (KeyMap.lookup key actualObject)

containsAll :: Value -> Value -> Bool
containsAll actual expected = case expected of
  Array expectedValues -> all (valueContains actual) (toList expectedValues)
  _ -> valueContains actual expected

containsOnce :: Value -> Value -> Bool
containsOnce (Array actualValues) expected =
  length (filter (== expected) (toList actualValues)) == 1
containsOnce _ _ = False

countEqualsOperator :: AssertionOperator
countEqualsOperator actual expected _ = do
  expectedValue <- requireExpected "count_equals" expected
  expectedCount <- case expectedValue of
    Number count -> Right count
    _ -> Left "count_equals expected value must be a number"
  actualCount <- case actual of
    Array values -> Right (fromIntegral (length values))
    Object values -> Right (fromIntegral (KeyMap.size values))
    String value -> Right (fromIntegral (Text.length value))
    _ -> Left "count_equals actual value is not countable"
  unless (actualCount == expectedCount) (Left "count_equals comparison failed")

betweenOperator :: AssertionOperator
betweenOperator actual expected _ = do
  bounds <- requireExpected "between_inclusive" expected
  case bounds of
    Array values -> case toList values of
      [lower, upper] -> do
        lowerOk <- compareValues (>=) actual lower
        upperOk <- compareValues (<=) actual upper
        unless (lowerOk && upperOk) (Left "between_inclusive comparison failed")
      _ -> Left "between_inclusive requires exactly two bounds"
    _ -> Left "between_inclusive bounds must be an array"

orderingOperator ::
  Text -> (forall comparable. Ord comparable => comparable -> comparable -> Bool) ->
  AssertionOperator
orderingOperator name predicate actual expected _ = do
  expectedValue <- requireExpected name expected
  matches <- compareValues predicate actual expectedValue
  unless matches (Left (name <> " comparison failed"))

compareValues ::
  (forall comparable. Ord comparable => comparable -> comparable -> Bool) ->
  Value -> Value -> Either Text Bool
compareValues predicate (Number left) (Number right) = Right (predicate left right)
compareValues predicate (String left) (String right) = Right (predicate left right)
compareValues _ _ _ = Left "ordering comparison requires two numbers or two strings"

nullOperator :: AssertionOperator
nullOperator actual _ _ = unless (actual == Null) (Left "is_null comparison failed")

notEmptyOperator :: AssertionOperator
notEmptyOperator actual _ _ = unless (isNonEmpty actual) (Left "not_empty comparison failed")

isNonEmpty :: Value -> Bool
isNonEmpty = \case
  Array values -> not (null values)
  Object values -> not (KeyMap.null values)
  String value -> not (Text.null value)
  Null -> False
  _ -> True

equalsSetOperator :: AssertionOperator
equalsSetOperator actual expected _ = do
  expectedValue <- requireExpected "equals_set" expected
  case (actual, expectedValue) of
    (Array actualValues, Array expectedValues) ->
      unless
        (canonicalSet (toList actualValues) == canonicalSet (toList expectedValues))
        (Left "equals_set comparison failed")
    _ -> Left "equals_set requires two arrays"
  where
    canonicalSet = Set.fromList . map encode

allEqualOperator :: AssertionOperator
allEqualOperator actual expected _ = do
  expectedValue <- requireExpected "all_equal" expected
  case actual of
    Array values -> unless (all (== expectedValue) (toList values))
      (Left "all_equal comparison failed")
    _ -> Left "all_equal actual value must be an array"

allMatchOperator :: AssertionOperator
allMatchOperator actual expected _ = do
  expectedValue <- requireExpected "all_match" expected
  case actual of
    Array values -> mapM_ (`matchesPattern` expectedValue) (toList values)
    _ -> Left "all_match actual value must be an array"

matchesPattern :: Value -> Value -> Either Text ()
matchesPattern actual expected = case (actual, expected) of
  (Object actualObject, Object expectedObject) ->
    mapM_ (matchField actualObject) (KeyMap.toList expectedObject)
  _ -> unless (actual == expected) (Left "all_match comparison failed")
  where
    matchField actualObject (key, condition) = do
      fieldValue <- maybe
        (Left ("all_match field is absent: " <> Key.toText key))
        Right
        (KeyMap.lookup key actualObject)
      case condition of
        Object predicateObject -> case KeyMap.toList predicateObject of
          [(predicateKey, predicateExpected)] ->
            evaluateAssertionOperator standardAssertionOperators
              (Key.toText predicateKey) fieldValue (Just predicateExpected)
              KeyMap.empty
          _ -> unless (valueContains fieldValue condition)
            (Left "all_match object predicate failed")
        String "not_empty" -> notEmptyOperator fieldValue Nothing KeyMap.empty
        _ -> unless (valueContains fieldValue condition)
          (Left "all_match field comparison failed")

allOmitOperator :: AssertionOperator
allOmitOperator actual expected assertion = case actual of
  Array values -> mapM_ (\value -> omitsOperator value expected assertion)
    (toList values)
  _ -> Left "all_omit actual value must be an array"

omitsOperator :: AssertionOperator
omitsOperator actual expected _ = do
  expectedValue <- requireExpected "omits" expected
  paths <- case expectedValue of
    String path -> Right [path]
    Array values -> mapM asText (toList values)
    _ -> Left "omits paths must be text or an array of text"
  mapM_ (assertOmitted actual) paths
  where
    asText (String path) = Right path
    asText _ = Left "omits path must be text"
    assertOmitted value path =
      case selectJsonPath path value of
        Left _ -> Right ()
        Right _ -> Left ("path is present but must be omitted: " <> path)

uniqueByOperator :: AssertionOperator
uniqueByOperator actual expected _ = do
  expectedValue <- requireExpected "unique_by" expected
  path <- case expectedValue of
    String value -> Right value
    _ -> Left "unique_by path must be text"
  case actual of
    Array values -> do
      selected <- mapM (selectJsonPath path) (toList values)
      unless (length selected == Set.size (Set.fromList (map encode selected)))
        (Left "unique_by comparison failed")
    _ -> Left "unique_by actual value must be an array"

toleranceOperator :: AssertionOperator
toleranceOperator actual _ assertion = do
  expectedPath <- requiredText "expected_path" assertion
  actualPath <- requiredText "actual_path" assertion
  tolerance <- case KeyMap.lookup "tolerance" assertion of
    Just (Number value) -> Right value
    _ -> Left "all_within_absolute_tolerance requires numeric tolerance"
  case actual of
    Array values -> mapM_ (within tolerance expectedPath actualPath) (toList values)
    _ -> Left "all_within_absolute_tolerance actual value must be an array"
  where
    within tolerance expectedPath actualPath value = do
      expectedValue <- selectJsonPath expectedPath value
      actualValue <- selectJsonPath actualPath value
      case (expectedValue, actualValue) of
        (Number expectedNumber, Number actualNumber) ->
          unless (abs (expectedNumber - actualNumber) <= tolerance)
            (Left "all_within_absolute_tolerance comparison failed")
        _ -> Left "tolerance paths must select numbers"

rejectedWithOperator :: AssertionOperator
rejectedWithOperator actual expected _ = do
  expectedValue <- requireExpected "rejected_with" expected
  let errorCode = case actual of
        Object value -> KeyMap.lookup "error_code" value
        _ -> Just actual
  unless (errorCode == Just expectedValue) (Left "rejected_with comparison failed")

-- The scenario applies this operator to a structured OperationalResponse and
-- compares the result of schema validation with a Boolean expectation.  It is
-- intentionally not plain JSON equality: false, zero, and empty required
-- fields remain valid values when their typed projection declares them.
schemaPresenceOperator :: AssertionOperator
schemaPresenceOperator actual expected _ = do
  expectedValue <- requireExpected "schema_presence_matches_projection" expected
  expectedMatch <- case expectedValue of
    Bool value -> Right value
    _ -> Left "schema_presence_matches_projection expected value must be Boolean"
  let actualMatch = operationalResponseMatchesSchema actual
  unless (actualMatch == expectedMatch)
    (Left "schema_presence_matches_projection comparison failed")

operationalResponseMatchesSchema :: Value -> Bool
operationalResponseMatchesSchema = \case
  Object response ->
    Set.fromList (KeyMap.keys response) `Set.isSubsetOf` operationalResponseFields
      && requiredField "ok" isBoolean response
      && requiredField "human" isText response
      && requiredField "changed" isTextArray response
      && requiredField "warnings" isTextArray response
      && requiredField "domain_revision" isInteger response
      && optionalField "result_kind" isText response
      && optionalField "entity" compactEntityMatchesSchema response
      && optionalField "error_code" isText response
      && optionalField "hint" isText response
      && optionalField "dry_run" isBoolean response
  _ -> False
  where
    operationalResponseFields = Set.fromList
      [ "ok", "human", "result_kind", "entity", "changed", "warnings"
      , "error_code", "hint", "dry_run", "domain_revision"
      ]

compactEntityMatchesSchema :: Value -> Bool
compactEntityMatchesSchema = \case
  Object entity ->
    Set.fromList (KeyMap.keys entity) `Set.isSubsetOf` compactEntityFields
      && requiredField "id" isText entity
      && requiredField "revision" isInteger entity
      && optionalField "title" isText entity
      && optionalField "state" isText entity
  _ -> False
  where
    compactEntityFields = Set.fromList ["id", "title", "revision", "state"]

requiredField :: Key.Key -> (Value -> Bool) -> Object -> Bool
requiredField field predicate value =
  maybe False predicate (KeyMap.lookup field value)

optionalField :: Key.Key -> (Value -> Bool) -> Object -> Bool
optionalField field predicate value =
  maybe True predicate (KeyMap.lookup field value)

isBoolean :: Value -> Bool
isBoolean (Bool _) = True
isBoolean _ = False

isText :: Value -> Bool
isText (String _) = True
isText _ = False

isTextArray :: Value -> Bool
isTextArray (Array values) = all isText (toList values)
isTextArray _ = False

isInteger :: Value -> Bool
isInteger value = case fromJSON value :: Result Integer of
  Success _ -> True
  Error _ -> False

passedItem :: Text -> ResultItem
passedItem identifier = ResultItem
  { resultItemId = identifier
  , resultItemPassed = True
  , resultItemDetail = Nothing
  }

failedItem :: Text -> Text -> ResultItem
failedItem identifier detail = ResultItem
  { resultItemId = identifier
  , resultItemPassed = False
  , resultItemDetail = Just detail
  }

identifiedObjects ::
  Text -> Value -> Either Text ([(Text, Object)], [Text])
identifiedObjects field = \case
  Object objectValue -> do
    values <- requiredArray field objectValue
    objects <- mapM asIdentified values
    pure (uniqueIdentified objects)
  _ -> Left (field <> " container must be an object")
  where
    asIdentified = \case
      Object item -> do
        identifier <- requiredText "id" item
        pure (identifier, item)
      _ -> Left (field <> " item must be an object")

uniqueIdentified :: [(Text, value)] -> ([(Text, value)], [Text])
uniqueIdentified values =
  let (uniqueReversed, _, duplicatesReversed) = foldl' collect
        ([], Set.empty, []) values
  in (reverse uniqueReversed, reverse duplicatesReversed)
  where
    collect (uniqueValues, seen, duplicates) item@(identifier, _)
      | Set.member identifier seen =
          (uniqueValues, seen, identifier : duplicates)
      | otherwise = (item : uniqueValues, Set.insert identifier seen, duplicates)

requiredValue :: Text -> Object -> Either Text Value
requiredValue field objectValue = maybe
  (Left ("missing field: " <> field))
  Right
  (KeyMap.lookup (Key.fromText field) objectValue)

requiredText :: Text -> Object -> Either Text Text
requiredText field objectValue = case KeyMap.lookup (Key.fromText field) objectValue of
  Just (String value) -> Right value
  Just _ -> Left ("field must be text: " <> field)
  Nothing -> Left ("missing field: " <> field)

requiredInt :: Text -> Object -> Either Text Int
requiredInt field objectValue = case KeyMap.lookup (Key.fromText field) objectValue of
  Just value -> case fromJSON value of
    Success intValue -> Right intValue
    Error _ -> Left ("field must be an integer: " <> field)
  Nothing -> Left ("missing field: " <> field)

requiredArray :: Text -> Object -> Either Text [Value]
requiredArray field objectValue = case KeyMap.lookup (Key.fromText field) objectValue of
  Just (Array values) -> Right (toList values)
  Just _ -> Left ("field must be an array: " <> field)
  Nothing -> Left ("missing field: " <> field)

optionalNonNull :: Text -> Object -> Maybe Value
optionalNonNull field objectValue = case KeyMap.lookup (Key.fromText field) objectValue of
  Just Null -> Nothing
  value -> value

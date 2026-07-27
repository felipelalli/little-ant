module Main (main) where

import Data.Aeson (Object, Value (..), encode, object, toJSON, (.=))
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy.Char8 as LBS8
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import LittleAnt.V1.Contract
  (AmbientInputs (..), ContractRegistry (..), DriverResponse (..),
   ObservationInput (..), OperationInput (..), OperationResult (..),
   PlanProbeInput (..), ProbeKey (..), ReferenceInput (..),
   ReferenceSnapshot (..), ResultItem (..),
   decodeAndRunContractRequest, emptyContractRegistry,
   evaluateAssertionOperator, runContractRequest, standardAssertionOperators)
import LittleAnt.V1.Implementation (contractRegistry)
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..),
   EventBatch (..), KernelError (..), OpaqueId (..), ProposedEvent (..),
   ReplayResult (..), appendSemanticAction, emptyKernelState,
   kernelEventBatches, kernelRevision, kernelValue, replayAll)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit
  (Assertion, assertBool, assertFailure, testCase, (@?=))

main :: IO ()
main = defaultMain $ testGroup "v1 contract runner"
  [ kernelTests
  , implementationBridgeTests
  , planTests
  , scenarioTests
  , operatorTests
  , rejectionTests
  , protocolTests
  ]

kernelTests :: TestTree
kernelTests = testGroup "v1 action kernel"
  [ testCase "commits one atomic batch and advances revision once" $ do
      accepted <- requireKernelSuccess (appendSemanticAction atomicKernelRequest
        emptyKernelState)
      let state = appendResultState accepted
      kernelRevision state @?= DomainRevision 1
      length (kernelEventBatches state) @?= 1
      length (eventBatchEvents (appendResultBatch accepted)) @?= 2
      kernelValue "first" state @?= Just (String "one")
      kernelValue "second" state @?= Just (toJSON (2 :: Int))
  , testCase "rejects stale and partially invalid actions without state" $ do
      accepted <- requireKernelSuccess (appendSemanticAction atomicKernelRequest
        emptyKernelState)
      let before = appendResultState accepted
          stale = atomicKernelRequest
            { appendSemanticActionId = "test:stale"
            , appendExpectedRevision = DomainRevision 0
            }
      case appendSemanticAction stale before of
        Left (RevisionConflict (DomainRevision 0) (DomainRevision 1)) -> pure ()
        result -> assertFailure ("unexpected stale append result: " <> show result)
      encode before @?= encode (appendResultState accepted)
      let invalid = atomicKernelRequest
            { appendSemanticActionId = "test:invalid-batch"
            , appendProposedEvents =
                [ ProposeValueStored "would-have-been-partial" (Bool True)
                , ProposeValueRemoved "missing"
                ]
            }
      case appendSemanticAction invalid emptyKernelState of
        Left (ValueDoesNotExist "missing") -> pure ()
        result -> assertFailure ("unexpected invalid append result: " <> show result)
      kernelRevision emptyKernelState @?= DomainRevision 0
      kernelValue "would-have-been-partial" emptyKernelState @?= Nothing
  , testCase "allocates opaque creation-derived identities" $ do
      accepted <- requireKernelSuccess (appendSemanticAction
        atomicKernelRequest
          { appendSemanticActionId = "test:opaque-identities"
          , appendProposedEvents =
              [ ProposeEntityCreated "brick"
                  (objectMap ["title" .= ("Repeated title" :: Text)])
              , ProposeEntityCreated "brick"
                  (objectMap ["title" .= ("Repeated title" :: Text)])
              ]
          }
        emptyKernelState)
      case appendResultAllocatedIds accepted of
        [first@(OpaqueId firstText), second@(OpaqueId secondText)] -> do
          assertBool "identities collide" (first /= second)
          assertBool "first identity contains title"
            (not ("Repeated title" `Text.isInfixOf` firstText))
          assertBool "second identity contains title"
            (not ("Repeated title" `Text.isInfixOf` secondText))
        identifiers -> assertFailure ("unexpected identities: " <> show identifiers)
  , testCase "replay is byte-equivalent and adapter-free" $ do
      first <- requireKernelSuccess (appendSemanticAction atomicKernelRequest
        emptyKernelState)
      second <- requireKernelSuccess (appendSemanticAction
        AppendRequest
          { appendExpectedRevision = DomainRevision 1
          , appendSemanticActionId = "test:second-action"
          , appendActorOrOrigin = "human:test"
          , appendOccurredAt = Just "2026-07-27T00:00:01Z"
          , appendProposedEvents = [ProposeValueRemoved "first"]
          }
        (appendResultState first))
      replayed <- case replayAll (kernelEventBatches (appendResultState second)) of
        Left problem -> assertFailure ("replay failed: " <> show problem)
        Right result -> pure result
      encode (replayResultState replayed) @?= encode (appendResultState second)
      replayResultExternalTrace replayed @?= []
  ]

implementationBridgeTests :: TestTree
implementationBridgeTests = testGroup "real implementation registry"
  [ testCase "populates every contract extension point" $ do
      assertBool "plan probes are empty" (not (Map.null
        (registryPlanProbes contractRegistry)))
      assertBool "operations are empty" (not (Map.null
        (registryOperations contractRegistry)))
      assertBool "observations are empty" (not (Map.null
        (registryObservations contractRegistry)))
      assertBool "fixtures are empty" (not (Map.null
        (registryFixtures contractRegistry)))
      assertBool "paths are empty" (not (Map.null
        (registryPaths contractRegistry)))
      assertBool "assertion operators are empty" (not (Map.null
        (registryAssertionOperators contractRegistry)))
      assertBool "reference resolvers are empty" (not (Map.null
        (registryReferences contractRegistry)))
  , testCase "kernel plan probes execute real append and replay" $ do
      assertResponsePassed (runContractRequest contractRegistry kernelInteractionPlan)
        [ "contract-signature.CanonicalEventStore.append"
        , "contract-signature.CanonicalEventStore.replay"
        ]
      assertResponsePassed (runContractRequest contractRegistry kernelRootPlan)
        ["invariant.GloballyOpaqueEntityIds"]
  , testCase "dispatches confidence_before and forecast references" $
      assertResponsePassed (runContractRequest contractRegistry
        implementationReferenceScenario)
        ["confidence-reference", "forecast-reference"]
  , testCase "validates schema presence through a structured response query" $
      assertResponsePassed (runContractRequest contractRegistry
        implementationSchemaScenario)
        ["structured-schema-presence"]
  ]

planTests :: TestTree
planTests = testGroup "Allium registry"
  [ testCase "selects probes by semantic metadata and preserves IDs" $ do
      let response = runContractRequest testRegistry planRequest
      map resultItemId (driverResponseResults response) @?= ["known", "unknown"]
      map resultItemPassed (driverResponseResults response) @?= [True, False]
      case driverResponseResults response of
        [_, unknown] -> assertDetailContains "unregistered Allium construct" unknown
        results -> assertFailure ("unexpected results: " <> show results)
      driverResponseOk response @?= False
  , testCase "collapses duplicate requested IDs without inventing one" $ do
      let response = runContractRequest testRegistry duplicatePlanRequest
      map resultItemId (driverResponseResults response) @?= ["known"]
      assertBool "duplicate diagnostic is absent"
        (not (null (driverResponseDiagnostics response)))
      driverResponseOk response @?= False
  ]

scenarioTests :: TestTree
scenarioTests = testGroup "scenario execution"
  [ testCase "resolves bind and bind_result symbols" $
      assertResponsePassed (runContractRequest testRegistry bindingScenario)
        ["complete-binding", "scalar-binding", "array-binding", "expression"]
  , testCase "retains before and after checkpoints" $
      assertResponsePassed (runContractRequest testRegistry checkpointScenario)
        ["after-first", "before-second", "at-anchor", "at-final"]
  , testCase "creates assertion-local fixtures from fresh state" $
      assertResponsePassed (runContractRequest testRegistry localFixtureScenario)
        ["fixture-state"]
  , testCase "passes pinned ambient inputs to operations" $
      assertResponsePassed (runContractRequest testRegistry ambientScenario)
        ["pinned-context"]
  , testCase "resolves registered value_from references with bindings and checkpoints" $
      assertResponsePassed (runContractRequest testRegistry referenceScenario)
        ["confidence-snapshot", "forecast-reference"]
  , testCase "does not rerun assertion operations for snapshot expectations" $
      assertSingleFailure "equals_snapshot comparison failed"
        operationSnapshotScenario
  , testCase "starts every request from isolated state" $ do
      let first = runContractRequest testRegistry isolatedScenario
          second = runContractRequest testRegistry isolatedScenario
      let expected = ["one-in-first-request", "dynamic-revision-reference"]
      assertResponsePassed first expected
      assertResponsePassed second expected
  ]

operatorTests :: TestTree
operatorTests = testGroup "declared assertion operators"
  [ testCase "registry contains every checked-in operator" $
      Set.fromList (Map.keys standardAssertionOperators) @?=
        Set.fromList declaredOperators
  , testCase "all operators implement their literal comparisons" $ do
      assertOperator "all_equal" (toJSON ([1, 1] :: [Int])) (Just (toJSON (1 :: Int))) emptyObject
      assertOperator "all_match"
        (toJSON [object ["n" .= (2 :: Int)], object ["n" .= (3 :: Int)]])
        (Just (object ["n" .= object ["greater_than" .= (1 :: Int)]]))
        emptyObject
      assertOperator "all_omit" (toJSON [object ["id" .= (1 :: Int)]])
        (Just (String "secret")) emptyObject
      assertOperator "all_unique_by"
        (toJSON [object ["id" .= (1 :: Int)], object ["id" .= (2 :: Int)]])
        (Just (String "id")) emptyObject
      assertOperator "all_within_absolute_tolerance"
        (toJSON [object ["expected" .= (0.4 :: Double), "actual" .= (0.41 :: Double)]])
        Nothing
        (objectValue
          [ "expected_path" .= ("expected" :: Text)
          , "actual_path" .= ("actual" :: Text)
          , "tolerance" .= (0.02 :: Double)
          ])
      assertOperator "between_inclusive" (toJSON (2 :: Int))
        (Just (toJSON ([1, 3] :: [Int]))) emptyObject
      assertOperator "contains" (object ["status" .= ("active" :: Text), "n" .= (1 :: Int)])
        (Just (object ["status" .= ("active" :: Text)])) emptyObject
      assertOperator "contains_all" (toJSON (["a", "b", "c"] :: [Text]))
        (Just (toJSON (["a", "c"] :: [Text]))) emptyObject
      assertOperator "contains_once" (toJSON (["a", "b"] :: [Text]))
        (Just (String "a")) emptyObject
      assertOperator "contains_references"
        (object ["first" .= ("brick:a" :: Text), "nested" .= ["brick:b" :: Text]])
        (Just (toJSON (["brick:a", "brick:b"] :: [Text]))) emptyObject
      assertOperator "count_equals" (toJSON ([1, 2] :: [Int]))
        (Just (toJSON (2 :: Int))) emptyObject
      assertOperator "equals" (String "x") (Just (String "x")) emptyObject
      assertOperator "equals_expression" (toJSON (2 :: Int))
        (Just (toJSON (2 :: Int))) emptyObject
      assertOperator "equals_reference" (String "id") (Just (String "id")) emptyObject
      assertOperator "equals_set" (toJSON ([2, 1, 1] :: [Int]))
        (Just (toJSON ([1, 2] :: [Int]))) emptyObject
      assertOperator "equals_snapshot" (String "same") (Just (String "same")) emptyObject
      assertOperator "greater_than" (toJSON (3 :: Int)) (Just (toJSON (2 :: Int))) emptyObject
      assertOperator "is_null" Null Nothing emptyObject
      assertOperator "less_than" (String "2026-01") (Just (String "2026-02")) emptyObject
      assertOperator "not_contains" (toJSON (["a"] :: [Text])) (Just (String "b")) emptyObject
      assertOperator "not_empty" (toJSON ([1] :: [Int])) Nothing emptyObject
      assertOperator "not_equals" (String "a") (Just (String "b")) emptyObject
      assertOperator "omits" (object ["safe" .= True])
        (Just (toJSON (["secret", "nested.token"] :: [Text]))) emptyObject
      assertOperator "omits_paths" (object ["safe" .= True])
        (Just (String "secret")) emptyObject
      assertOperator "rejected_with" (object ["error_code" .= ("precondition_failed" :: Text)])
        (Just (String "precondition_failed")) emptyObject
      assertOperator "results_in" (object ["status" .= ("failed" :: Text), "changed" .= False])
        (Just (object ["status" .= ("failed" :: Text)])) emptyObject
      let sparseResponse = object
            [ "ok" .= False
            , "human" .= ("precondition failed" :: Text)
            , "changed" .= ([] :: [Text])
            , "warnings" .= ([] :: [Text])
            , "domain_revision" .= (0 :: Int)
            , "entity" .= object
                [ "id" .= ("brick:zero" :: Text)
                , "revision" .= (0 :: Int)
                , "state" .= ("active" :: Text)
                ]
            ]
      assertOperator "schema_presence_matches_projection" sparseResponse
        (Just (Bool True)) emptyObject
      assertOperator "schema_presence_matches_projection"
        (object ["human" .= ("missing required fields" :: Text)])
        (Just (Bool False)) emptyObject
      assertOperator "unique_by"
        (toJSON [object ["id" .= (1 :: Int)], object ["id" .= (2 :: Int)]])
        (Just (String "id")) emptyObject
  ]

rejectionTests :: TestTree
rejectionTests = testGroup "fail-closed behavior"
  [ testCase "unknown operation fails requested assertion with a diagnostic" $ do
      let response = runContractRequest testRegistry unknownOperationScenario
      map resultItemId (driverResponseResults response) @?= ["still-returned"]
      map resultItemPassed (driverResponseResults response) @?= [False]
      case driverResponseResults response of
        [result] -> assertDetailContains "unregistered operation" result
        results -> assertFailure ("unexpected results: " <> show results)
  , testCase "unknown fixture fails only its assertion" $
      assertSingleFailure "unregistered fixture"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-fixture" :: Text)
          , "fixture" .= ("absent" :: Text)
          , "query" .= ("State" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown reference is rejected" $
      assertSingleFailure "unregistered reference"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-reference" :: Text)
          , "query" .= ("Argument($absent)" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown observation is rejected" $
      assertSingleFailure "unregistered observation"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-observation" :: Text)
          , "query" .= ("NotRegistered" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown path is rejected" $
      assertSingleFailure "unknown path segment"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-path" :: Text)
          , "query" .= ("View" :: Text)
          , "path" .= ("absent" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown value_from reference is rejected" $
      assertSingleFailure "unregistered value_from reference"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-value-from" :: Text)
          , "query" .= ("State" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value_from" .= ("mystery:source" :: Text)
          ]))
  , testCase "unknown operator is rejected" $
      assertSingleFailure "unregistered assertion operator"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-operator" :: Text)
          , "query" .= ("State" :: Text)
          , "operator" .= ("approximately_magic" :: Text)
          , "value" .= (0 :: Int)
          ]))
  ]

protocolTests :: TestTree
protocolTests = testGroup "wire protocol"
  [ testCase "rejects unsupported protocol versions" $ do
      let response = runContractRequest testRegistry
            (object ["protocol_version" .= (2 :: Int), "request_kind" .= ("scenario" :: Text)])
      driverResponseProtocolVersion response @?= 1
      driverResponseOk response @?= False
  , testCase "rejects a second JSON request on stdin" $ do
      let response = decodeAndRunContractRequest testRegistry
            (LBS8.pack "{\"protocol_version\":1} {\"protocol_version\":1}")
      driverResponseOk response @?= False
      assertBool "missing invalid JSON diagnostic"
        (any (Text.isInfixOf "invalid JSON request")
          (driverResponseDiagnostics response))
  , testCase "scenario result IDs are unique even when requested twice" $ do
      let duplicateAssertion = object
            [ "id" .= ("same" :: Text)
            , "query" .= ("State" :: Text)
            , "operator" .= ("equals" :: Text)
            , "value" .= (0 :: Int)
            ]
          response = runContractRequest testRegistry
            (scenarioRequest [] [duplicateAssertion, duplicateAssertion])
      map resultItemId (driverResponseResults response) @?= ["same"]
      driverResponseOk response @?= False
  ]

testRegistry :: ContractRegistry Int
testRegistry = (emptyContractRegistry (0 :: Int))
  { registryInitialState = const 0
  , registryPlanProbes = Map.singleton
      (ProbeKey "domain" "invariant" "KnownConstruct") knownProbe
  , registryOperations = Map.fromList
      [ ("Increment", incrementOperation)
      , ("Echo", echoOperation)
      , ("CaptureAmbient", ambientOperation)
      , ("ReplayFromEvents", replayFromEventsOperation)
      ]
  , registryObservations = Map.fromList
      [ ("State", stateObservation)
      , ("Argument", argumentObservation)
      , ("View", viewObservation)
      , ("DomainRevision", stateObservation)
      ]
  , registryFixtures = Map.fromList
      [ ("binding_fixture", bindingFixture)
      , ("state_five", stateFiveFixture)
      ]
  , registryReferences = Map.fromList
      [ ("confidence_before", confidenceBeforeReference)
      , ("forecast", forecastReference)
      ]
  }

knownProbe :: PlanProbeInput -> Either Text ()
knownProbe input
  | planProbeCategory input == "invariant" = Right ()
  | otherwise = Left "wrong category"

incrementOperation :: OperationInput -> Int -> Either Text (OperationResult Int)
incrementOperation _ state = Right OperationResult
  { operationResultValue = toJSON (state + 1)
  , operationResultState = state + 1
  }

echoOperation :: OperationInput -> Int -> Either Text (OperationResult Int)
echoOperation input state = Right OperationResult
  { operationResultValue = operationArguments input
  , operationResultState = state
  }

ambientOperation :: OperationInput -> Int -> Either Text (OperationResult Int)
ambientOperation input state = Right OperationResult
  { operationResultValue = ambientValue (operationAmbient input)
  , operationResultState = state
  }

replayFromEventsOperation ::
  OperationInput -> Int -> Either Text (OperationResult Int)
replayFromEventsOperation _ state = Right OperationResult
  { operationResultValue = Null
  , operationResultState = state + 10
  }

confidenceBeforeReference :: ReferenceInput Int -> Either Text Value
confidenceBeforeReference input = do
  stepId <- maybe
    (Left "invalid confidence_before reference")
    Right
    (Text.stripPrefix "confidence_before:" (referenceInputSource input))
  snapshot <- maybe
    (Left ("unknown checkpoint in confidence reference: " <> stepId))
    Right
    (Map.lookup ("before:" <> stepId) (referenceInputCheckpoints input))
  Right (toJSON (referenceSnapshotState snapshot))

forecastReference :: ReferenceInput Int -> Either Text Value
forecastReference input =
  case ( referenceInputSource input
       , Map.lookup "taxes"
           (referenceSnapshotBindings (referenceInputCurrent input))
       , Map.lookup "before:skip-once" (referenceInputCheckpoints input)
       ) of
    ("forecast:before-skip:$taxes.probability", Just (String "brick:taxes"),
        Just _) -> Right (toJSON (0.25 :: Double))
    _ -> Left "invalid forecast reference context"

bindingFixture :: OperationInput -> Int -> Either Text (OperationResult Int)
bindingFixture _ state = Right OperationResult
  { operationResultValue = object
      [ "token" .= ("fixture-token" :: Text)
      , "numbers" .= ([1, 2] :: [Int])
      ]
  , operationResultState = state
  }

stateFiveFixture :: OperationInput -> Int -> Either Text (OperationResult Int)
stateFiveFixture _ _ = Right OperationResult
  { operationResultValue = Null
  , operationResultState = 5
  }

stateObservation :: ObservationInput -> Int -> Either Text Value
stateObservation _ = Right . toJSON

argumentObservation :: ObservationInput -> Int -> Either Text Value
argumentObservation input _ = case observationArguments input of
  [value] -> Right value
  _ -> Left "Argument expects exactly one value"

viewObservation :: ObservationInput -> Int -> Either Text Value
viewObservation _ state = Right (object
  [ "state" .= state
  , "items" .= ([object ["id" .= (1 :: Int)]] :: [Value])
  ])

ambientValue :: AmbientInputs -> Value
ambientValue ambient = object
  [ "clock" .= ambientClock ambient
  , "random_evidence" .= ambientRandomEvidence ambient
  , "parameter_overrides" .= ambientParameterOverrides ambient
  ]

atomicKernelRequest :: AppendRequest
atomicKernelRequest = AppendRequest
  { appendExpectedRevision = DomainRevision 0
  , appendSemanticActionId = "test:atomic-action"
  , appendActorOrOrigin = "human:test"
  , appendOccurredAt = Just "2026-07-27T00:00:00Z"
  , appendProposedEvents =
      [ ProposeValueStored "first" (String "one")
      , ProposeValueStored "second" (toJSON (2 :: Int))
      ]
  }

kernelInteractionPlan :: Value
kernelInteractionPlan = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("interaction" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "contract-signature.CanonicalEventStore.append"
              "contract_signature" "CanonicalEventStore.append"
          , obligation "contract-signature.CanonicalEventStore.replay"
              "contract_signature" "CanonicalEventStore.replay"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

kernelRootPlan :: Value
kernelRootPlan = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("root" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "invariant.GloballyOpaqueEntityIds"
              "invariant" "GloballyOpaqueEntityIds"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

implementationReferenceScenario :: Value
implementationReferenceScenario = scenarioRequest
  [ object
      [ "id" .= ("fixture" :: Text)
      , "operation" .= ("CreateFixture" :: Text)
      , "arguments" .= object
          ["fixture" .= ("kernel_reference_state" :: Text)]
      , "bind_result" .= object ["taxes" .= ("taxes" :: Text)]
      ]
  , object
      [ "id" .= ("lower-confidence" :: Text)
      , "operation" .= ("KernelSetValue" :: Text)
      , "arguments" .= object
          [ "key" .= ("confidence" :: Text)
          , "value" .= (0.4 :: Double)
          ]
      ]
  , object
      [ "id" .= ("skip-once" :: Text)
      , "operation" .= ("KernelSetValue" :: Text)
      , "arguments" .= object
          [ "key" .= ("skip-recorded" :: Text)
          , "value" .= True
          ]
      ]
  ]
  [ object
      [ "id" .= ("confidence-reference" :: Text)
      , "after" .= ("lower-confidence" :: Text)
      , "query" .= ("KernelValue(confidence)" :: Text)
      , "operator" .= ("less_than" :: Text)
      , "value_from" .= ("confidence_before:lower-confidence" :: Text)
      ]
  , object
      [ "id" .= ("forecast-reference" :: Text)
      , "after" .= ("skip-once" :: Text)
      , "query" .= ("KernelValue(actual_probability)" :: Text)
      , "operator" .= ("greater_than" :: Text)
      , "value_from" .= ("forecast:before-skip:$taxes.probability" :: Text)
      ]
  ]

implementationSchemaScenario :: Value
implementationSchemaScenario = scenarioRequest []
  [ object
      [ "id" .= ("structured-schema-presence" :: Text)
      , "query" .= ("LatestOperationalResponse" :: Text)
      , "operator" .= ("schema_presence_matches_projection" :: Text)
      , "value" .= True
      ]
  ]

planRequest :: Value
planRequest = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("domain" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "known" "invariant" "KnownConstruct"
          , obligation "unknown" "invariant" "MissingConstruct"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

duplicatePlanRequest :: Value
duplicatePlanRequest = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("domain" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "known" "invariant" "KnownConstruct"
          , obligation "known" "invariant" "KnownConstruct"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

obligation :: Text -> Text -> Text -> Value
obligation identifier category construct = object
  [ "id" .= identifier
  , "category" .= category
  , "source_construct" .= construct
  ]

bindingScenario :: Value
bindingScenario = scenarioRequest
  [ object
      [ "id" .= ("fixture" :: Text)
      , "operation" .= ("CreateFixture" :: Text)
      , "arguments" .= object ["fixture" .= ("binding_fixture" :: Text)]
      , "bind" .= ("whole" :: Text)
      , "bind_result" .= object
          [ "token" .= ("token" :: Text)
          , "numbers" .= (["one", "two"] :: [Text])
          ]
      ]
  , object
      [ "id" .= ("echo" :: Text)
      , "operation" .= ("Echo" :: Text)
      , "arguments" .= String "$token"
      , "bind" .= ("echoed" :: Text)
      ]
  ]
  [ assertion "complete-binding" "Argument($whole)" "contains"
      (object ["token" .= ("fixture-token" :: Text)])
  , assertion "scalar-binding" "Argument($echoed)" "equals_reference"
      (String "$token")
  , assertion "array-binding" "Argument($two)" "equals" (toJSON (2 :: Int))
  , assertion "expression" "Argument($two)" "equals_expression"
      (String "$one + 1")
  ]

checkpointScenario :: Value
checkpointScenario = scenarioRequest
  [ step "first" "Increment"
  , step "second" "Increment"
  ]
  [ object
      [ "id" .= ("after-first" :: Text)
      , "after" .= ("first" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals" :: Text)
      , "value" .= (1 :: Int)
      ]
  , object
      [ "id" .= ("before-second" :: Text)
      , "after" .= ("first" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals_snapshot" :: Text)
      , "value_from" .= ("before:second" :: Text)
      ]
  , object
      [ "id" .= ("at-anchor" :: Text)
      , "at" .= ("after:first" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals" :: Text)
      , "value" .= (1 :: Int)
      ]
  , assertion "at-final" "State" "equals" (toJSON (2 :: Int))
  ]

referenceScenario :: Value
referenceScenario = scenarioRequest
  [ step "bootstrap" "Increment"
  , object
      [ "id" .= ("capture-tax-brick" :: Text)
      , "operation" .= ("Echo" :: Text)
      , "arguments" .= ("brick:taxes" :: Text)
      , "bind" .= ("taxes" :: Text)
      ]
  , step "skip-once" "Increment"
  ]
  [ object
      [ "id" .= ("confidence-snapshot" :: Text)
      , "after" .= ("skip-once" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("greater_than" :: Text)
      , "value_from" .= ("confidence_before:skip-once" :: Text)
      ]
  , object
      [ "id" .= ("forecast-reference" :: Text)
      , "after" .= ("skip-once" :: Text)
      , "query" .= ("Argument(0.5)" :: Text)
      , "operator" .= ("greater_than" :: Text)
      , "value_from" .=
          ("forecast:before-skip:$taxes.probability" :: Text)
      ]
  ]

operationSnapshotScenario :: Value
operationSnapshotScenario = scenarioRequest
  [step "first" "Increment"]
  [ object
      [ "id" .= ("operation-snapshot" :: Text)
      , "after" .= ("first" :: Text)
      , "operation" .= ("ReplayFromEvents" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals_snapshot" :: Text)
      , "value_from" .= ("after:first" :: Text)
      ]
  ]

localFixtureScenario :: Value
localFixtureScenario = scenarioWithAssertion (object
  [ "id" .= ("fixture-state" :: Text)
  , "fixture" .= ("state_five" :: Text)
  , "query" .= ("State" :: Text)
  , "operator" .= ("equals" :: Text)
  , "value" .= (5 :: Int)
  ])

ambientScenario :: Value
ambientScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("ambient" :: Text)
      , "clock" .= ("2026-07-27T12:00:00Z" :: Text)
      , "random_evidence" .= object ["seed" .= ("fixed" :: Text)]
      , "parameter_overrides" .= object ["limit" .= (2 :: Int)]
      , "steps" .=
          [ object
              [ "id" .= ("capture" :: Text)
              , "operation" .= ("CaptureAmbient" :: Text)
              , "bind" .= ("ambient" :: Text)
              ]
          ]
      , "assertions" .=
          [ assertion "pinned-context" "Argument($ambient)" "equals"
              (object
                [ "clock" .= ("2026-07-27T12:00:00Z" :: Text)
                , "random_evidence" .= object ["seed" .= ("fixed" :: Text)]
                , "parameter_overrides" .= object ["limit" .= (2 :: Int)]
                ])
          ]
      ]
  ]

isolatedScenario :: Value
isolatedScenario = scenarioRequest
  [ step "increment" "Increment"
  , object
      [ "id" .= ("capture-revision" :: Text)
      , "operation" .= ("Echo" :: Text)
      , "arguments" .= String "$current_domain_revision"
      , "bind" .= ("captured_revision" :: Text)
      ]
  ]
  [ assertion "one-in-first-request" "State" "equals" (toJSON (1 :: Int))
  , assertion "dynamic-revision-reference" "Argument($captured_revision)"
      "equals" (toJSON (1 :: Int))
  ]

unknownOperationScenario :: Value
unknownOperationScenario = scenarioRequest
  [step "unknown" "NotRegistered"]
  [assertion "still-returned" "State" "equals" (toJSON (0 :: Int))]

scenarioWithAssertion :: Value -> Value
scenarioWithAssertion assertionValue = scenarioRequest [] [assertionValue]

scenarioRequest :: [Value] -> [Value] -> Value
scenarioRequest steps assertions = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("runner-test" :: Text)
      , "steps" .= steps
      , "assertions" .= assertions
      ]
  ]

step :: Text -> Text -> Value
step identifier operation = object
  [ "id" .= identifier
  , "operation" .= operation
  ]

assertion :: Text -> Text -> Text -> Value -> Value
assertion identifier query operator expected = object
  [ "id" .= identifier
  , "query" .= query
  , "operator" .= operator
  , "value" .= expected
  ]

declaredOperators :: [Text]
declaredOperators =
  [ "all_equal", "all_match", "all_omit", "all_unique_by"
  , "all_within_absolute_tolerance", "between_inclusive", "contains"
  , "contains_all", "contains_once", "contains_references", "count_equals"
  , "equals", "equals_expression", "equals_reference", "equals_set"
  , "equals_snapshot", "greater_than", "is_null", "less_than"
  , "not_contains", "not_empty", "not_equals", "omits", "omits_paths"
  , "rejected_with", "results_in", "schema_presence_matches_projection"
  , "unique_by"
  ]

assertOperator :: Text -> Value -> Maybe Value -> Object -> Assertion
assertOperator name actual expected metadata =
  case evaluateAssertionOperator standardAssertionOperators
      name actual expected metadata of
    Left problem -> assertFailure
      (Text.unpack (name <> " unexpectedly failed: " <> problem))
    Right () -> pure ()

assertResponsePassed :: DriverResponse -> [Text] -> Assertion
assertResponsePassed response expectedIds = do
  map resultItemId (driverResponseResults response) @?= expectedIds
  map resultItemPassed (driverResponseResults response) @?=
    replicate (length expectedIds) True
  driverResponseOk response @?= True

assertSingleFailure :: Text -> Value -> Assertion
assertSingleFailure detail request = do
  let response = runContractRequest testRegistry request
  case driverResponseResults response of
    [result] -> do
      resultItemPassed result @?= False
      assertDetailContains detail result
    results -> assertFailure ("unexpected results: " <> show results)

assertDetailContains :: Text -> ResultItem -> Assertion
assertDetailContains expected result = case resultItemDetail result of
  Nothing -> assertFailure "result has no failure detail"
  Just detail -> assertBool
    ("detail does not contain " <> Text.unpack expected <> ": " <> Text.unpack detail)
    (expected `Text.isInfixOf` detail)

requireKernelSuccess ::
  Either KernelError AppendResult -> IO AppendResult
requireKernelSuccess result = case result of
  Left problem -> assertFailure ("kernel action failed: " <> show problem)
  Right accepted -> pure accepted

objectMap :: [AesonTypes.Pair] -> Object
objectMap = objectValue

emptyObject :: Object
emptyObject = KeyMap.empty

objectValue :: [AesonTypes.Pair] -> Object
objectValue pairs = case object pairs of
  Object value -> value
  _ -> KeyMap.empty

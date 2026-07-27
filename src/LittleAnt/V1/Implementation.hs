-- | Real Little Ant 1.0 implementation bridge used by the executable contract.
--
-- This first slice exposes the event-sourced kernel.  Later domain slices add
-- typed operations to the same semantic registry; unimplemented constructs
-- and operations continue to fail closed.
module LittleAnt.V1.Implementation
  ( V1State
  , contractRegistry
  ) where

import Control.Applicative ((<|>))
import Control.Monad (when)
import Data.Aeson
  (FromJSON, Object, Result (..), Value (..), fromJSON, object, toJSON, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Foldable (toList)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.V1.Contract
  (AmbientInputs (..), ContractRegistry (..), ObservationInput (..),
   OperationInput (..), OperationResult (..), ReferenceInput (..),
   ReferenceSnapshot (..), emptyContractRegistry, selectJsonPath,
   standardAssertionOperators)
import LittleAnt.V1.Domain
  (Authority (Human), Brick (brickId), BrickStatus (Active), DomainError,
   ListEntryDraft (..), Party (partyId), PartyType (Person),
   createBrick, createListEntry, createParty, domainCatalog, domainProjection,
   emptyDomainState, finiteChecklistV1, findBehaviors, findTemplates,
   focusBrick, mkCanonicalText, ordinaryBrickDraft, standardV1)
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..),
   EventBatch (..), KernelError, KernelState, OpaqueId (..), ProposedEvent (..),
   ReplayResult (..), appendSemanticAction, canonicalStateHash,
   emptyKernelState, kernelEntity, kernelEventBatches, kernelRevision,
   kernelValue, replayAll)
import LittleAnt.V1.Material
  (MaterialError, MaterialState (..), Raw (rawId), RawId,
   RawLink (rawLinkId), RawOrigin (rawOriginId),
   RawReviewDisposition (rawReviewDispositionId), RawShelf (rawShelfId),
   RawShelfId, RawShelfMembership (rawShelfMembershipId),
   RawSnapshot (rawSnapshotContentHash, rawSnapshotId, rawSnapshotRaw),
   RawSnapshotId,
   SnapshotCaptureResult (..), SourceObservation (sourceObservationId),
   addRawToShelf, archiveRaw, captureExternalRaw, captureInlineRaw,
   captureRawSnapshot, createRawShelf, emptyMaterialState,
   latestSourceObservation, linkDerivedRaw, linkRawToBrick, linkRawToEntry,
   openSourceReconciliationKinds, rawLinkProjection, rawProjection,
   reconcileRawLink, recordSourceObservation, registerMaterialBrick,
   relocateRawOrigin, removeRawFromShelf, reopenRaw, reportSnapshotCorrupt,
   reportSnapshotMissing, retireRawOrigin, reviewRaw, sourceObservationProjection,
   unarchiveRaw, verifySnapshotBytes)
import LittleAnt.V1.PlanCatalog (v1PlanProbes)
import qualified LittleAnt.V1.Priority as Priority

-- | Isolated v1 state.  Every protocol request obtains a new value through
-- 'registryInitialState'.
type V1State = KernelState

-- | Populated semantic registry shipped by @lant-v1-test-driver@.
contractRegistry :: ContractRegistry V1State
contractRegistry = (emptyContractRegistry emptyKernelState)
  { registryInitialState = const emptyKernelState
  , registryPlanProbes = v1PlanProbes
  , registryOperations = Map.fromList
      [ ("CanonicalEventStore.append", appendOperation)
      , ("CanonicalEventStore.replay", replayOperation)
      , ("ReplayFromEvents", replayOperation)
      , ("KernelAllocateEntity", allocateEntityOperation)
      , ("KernelRejectAction", rejectActionOperation)
      , ("KernelRemoveValue", removeValueOperation)
      , ("KernelSetValue", setValueOperation)
      , ("CreateRootBrick", createRootPriorityOperation)
      , ("CreateChildBrick", createChildPriorityOperation)
      , ("AnswerPriorityComparison", answerPriorityComparisonOperation)
      , ("SkipPriorityComparison", skipPriorityComparisonOperation)
      , ("ReopenPriorityInsertion", reopenPriorityInsertionOperation)
      , ("OpenProvocativeValidation", openProvocativeValidationOperation)
      , ("RecordPriorityJudgment", recordPriorityJudgmentOperation)
      , ("CommitPriorityRecalibration", commitPriorityRecalibrationOperation)
      , ("CaptureInlineRaw", captureInlineRawOperation)
      , ("CaptureExternalRaw", captureExternalRawOperation)
      , ("CaptureRawSnapshot", captureRawSnapshotOperation)
      , ("ReportSnapshotMissing", reportSnapshotMissingOperation)
      , ("ReportSnapshotCorrupt", reportSnapshotCorruptOperation)
      , ("VerifySnapshotBytes", verifySnapshotBytesOperation)
      , ("RecordSourceObservation", recordSourceObservationOperation)
      , ("RelocateRawOrigin", relocateRawOriginOperation)
      , ("RetireRawOrigin", retireRawOriginOperation)
      , ("ReviewRaw", reviewRawOperation)
      , ("ReopenRaw", reopenRawOperation)
      , ("ArchiveRaw", archiveRawOperation)
      , ("UnarchiveRaw", unarchiveRawOperation)
      , ("LinkRawToBrick", linkRawToBrickOperation)
      , ("LinkRawToEntry", linkRawToEntryOperation)
      , ("LinkDerivedRaw", linkDerivedRawOperation)
      , ("ReconcileRawLink", reconcileRawLinkOperation)
      , ("CreateRawShelf", createRawShelfOperation)
      , ("AddRawToShelf", addRawToShelfOperation)
      , ("RemoveRawFromShelf", removeRawFromShelfOperation)
      ]
  , registryObservations = Map.fromList
      [ ("AdapterTrace", adapterTraceObservation)
      , ("BuiltInDefinitionCatalog", builtInCatalogObservation)
      , ("CanonicalState", canonicalStateObservation)
      , ("CanonicalStateHash", canonicalStateHashObservation)
      , ("DomainState", domainStateObservation)
      , ("DomainRevision", domainRevisionObservation)
      , ("EventBatches", eventBatchesObservation)
      , ("KernelEntity", entityObservation)
      , ("KernelSummary", kernelSummaryObservation)
      , ("KernelValue", valueObservation)
      , ("LatestOperationalResponse", operationalResponseObservation)
      , ("ReplaySideEffectTrace", adapterTraceObservation)
      , ("MaterialState", materialStateObservation)
      , ("RawSnapshots", rawSnapshotsObservation)
      , ("PriorityInsertion", priorityInsertionObservation)
      , ("PriorityJudgmentsFor", priorityJudgmentsForObservation)
      , ("PriorityEvidenceFor", priorityEvidenceForObservation)
      , ("RootPriority", rootPriorityObservation)
      , ("PriorityViewItem", priorityViewItemObservation)
      , ("JudgmentProbe", judgmentProbeObservation)
      , ("PriorityEvidence", priorityEvidenceObservation)
      , ("PriorityRecalibration", priorityRecalibrationObservation)
      , ("OpenProposalsFor", openProposalsObservation)
      , ("BrickSummary", materialBrickSummaryObservation)
      , ("RawSummary", rawSummaryObservation)
      , ("LatestSourceObservation", latestSourceObservationQuery)
      , ("RawLink", rawLinkObservation)
      , ("ExternalIoTrace", externalIoTraceObservation)
      ]
  , registryFixtures = Map.fromList
      [ ("active_root_brick", activeRootBrickFixture)
      , ("definition_catalog", definitionCatalogFixture)
      , ("domain_entities", domainEntitiesFixture)
      , ("kernel_populated", populatedFixture)
      , ("kernel_reference_state", referenceFixture)
      , ("material_entities", materialEntitiesFixture)
      , ("strict_root_priority", strictRootPriorityFixture)
      ]
  , registryReferences = Map.fromList
      [ ("confidence_before", confidenceBeforeReference)
      , ("forecast", forecastReference)
      ]
  , registryPaths = Map.fromList
      [ ("kernel_event_batches", selectJsonPath "event_batches")
      , ("kernel_revision", selectJsonPath "domain_revision")
      ]
  , registryAssertionOperators = standardAssertionOperators
  }

appendOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
appendOperation input state = do
  arguments <- requireArgumentsObject input
  expected <- DomainRevision <$> requiredInteger "expected_revision" arguments
  actionId <- requiredText "semantic_action_id" arguments
  proposedValues <- requiredArray "events" arguments
  proposed <- mapM parseProposedEvent proposedValues
  let actor = fromMaybe "contract:canonical-event-store"
        (optionalText "actor_or_origin" arguments)
      occurredAt = optionalText "occurred_at" arguments
        <|> ambientText (ambientClock (operationAmbient input))
  accepted <- mapKernelError (appendSemanticAction AppendRequest
    { appendExpectedRevision = expected
    , appendSemanticActionId = actionId
    , appendActorOrOrigin = actor
    , appendOccurredAt = occurredAt
    , appendProposedEvents = proposed
    } state)
  pure (acceptedOperationResult accepted)

setValueOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
setValueOperation input state = do
  arguments <- requireArgumentsObject input
  key <- requiredText "key" arguments
  value <- requiredValue "value" arguments
  runSimpleAction input state
    [ProposeValueStored key value]

removeValueOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
removeValueOperation input state = do
  arguments <- requireArgumentsObject input
  key <- requiredText "key" arguments
  runSimpleAction input state [ProposeValueRemoved key]

allocateEntityOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
allocateEntityOperation input state = do
  arguments <- requireArgumentsObject input
  kind <- requiredText "kind" arguments
  fields <- fromMaybe KeyMap.empty <$> optionalObject "fields" arguments
  runSimpleAction input state [ProposeEntityCreated kind fields]

-- | Exercise a failed semantic action while returning a protocol value that
-- can be asserted.  The rejected append has no next state, so this operation
-- necessarily returns the original state unchanged.
rejectActionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
rejectActionOperation input state =
  case appendSemanticAction AppendRequest
      { appendExpectedRevision = kernelRevision state
      , appendSemanticActionId = actionIdFor input
      , appendActorOrOrigin = "contract:kernel-rejection-probe"
      , appendOccurredAt = ambientText (ambientClock (operationAmbient input))
      , appendProposedEvents = []
      } state of
    Left problem -> Right OperationResult
      { operationResultValue = object
          [ "accepted" .= False
          , "error" .= Text.pack (show problem)
          , "domain_revision" .= kernelRevision state
          ]
      , operationResultState = state
      }
    Right _ -> Left "empty semantic action unexpectedly succeeded"

replayOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
replayOperation _ state = do
  replayed <- mapKernelError (replayAll (kernelEventBatches state))
  let rebuilt = replayResultState replayed
  pure OperationResult
    { operationResultValue = object
        [ "domain_revision" .= kernelRevision rebuilt
        , "state_hash" .= canonicalStateHash rebuilt
        , "external_trace" .= replayResultExternalTrace replayed
        ]
    , operationResultState = rebuilt
    }

runSimpleAction ::
  OperationInput -> V1State -> [ProposedEvent] ->
  Either Text (OperationResult V1State)
runSimpleAction input state proposed = do
  arguments <- requireArgumentsObject input
  let expected = DomainRevision (fromMaybe
        (unDomainRevision (kernelRevision state))
        (optionalInteger "expected_revision" arguments))
      actor = fromMaybe "contract:kernel-operation"
        (optionalText "actor_or_origin" arguments)
      occurredAt = optionalText "occurred_at" arguments
        <|> ambientText (ambientClock (operationAmbient input))
  accepted <- mapKernelError (appendSemanticAction AppendRequest
    { appendExpectedRevision = expected
    , appendSemanticActionId = fromMaybe (actionIdFor input)
        (optionalText "semantic_action_id" arguments)
    , appendActorOrOrigin = actor
    , appendOccurredAt = occurredAt
    , appendProposedEvents = proposed
    } state)
  pure (acceptedOperationResult accepted)

acceptedOperationResult :: AppendResult -> OperationResult V1State
acceptedOperationResult accepted = OperationResult
  { operationResultValue = object
      [ "accepted" .= True
      , "domain_revision" .= kernelRevision (appendResultState accepted)
      , "allocated_ids" .= map unOpaqueId (appendResultAllocatedIds accepted)
      , "event_count" .= length
          (eventBatchEvents (appendResultBatch accepted))
      ]
  , operationResultState = appendResultState accepted
  }

parseProposedEvent :: Value -> Either Text ProposedEvent
parseProposedEvent value = do
  event <- asObject "event" value
  eventType <- requiredText "type" event
  case eventType of
    "put" -> ProposeValueStored
      <$> requiredText "key" event
      <*> requiredValue "value" event
    "remove" -> ProposeValueRemoved <$> requiredText "key" event
    "create_entity" -> ProposeEntityCreated
      <$> requiredText "kind" event
      <*> (fromMaybe KeyMap.empty <$> optionalObject "fields" event)
    _ -> Left ("unknown kernel event type: " <> eventType)

------------------------------------------------------------
-- Strict human priority operations and observations
------------------------------------------------------------

priorityStateFromKernel :: V1State -> Either Text Priority.PriorityState
priorityStateFromKernel state = case kernelValue "v1.priority" state of
  Nothing -> Right Priority.emptyPriorityState
  Just value -> case fromJSON value of
    Success priority -> Right priority
    Error problem -> Left ("stored priority state is malformed: " <> Text.pack problem)

priorityStateForOperation ::
  OperationInput -> V1State -> Either Text Priority.PriorityState
priorityStateForOperation input state = do
  priority <- priorityStateFromKernel state
  case kernelValue "v1.priority" state of
    Just _ -> Right priority
    Nothing -> do
      let (nearbyDistance, skipLimit) = priorityOverrides
            (ambientParameterOverrides (operationAmbient input))
      mapPriorityError (Priority.configurePriorityState
        nearbyDistance skipLimit priority)

priorityOverrides :: Maybe Value -> (Int, Int)
priorityOverrides value = case value of
  Just (Object fields) ->
    ( integerOverride "priority_nearby_distance" 3 fields
    , integerOverride "priority_skip_limit" 2 fields
    )
  _ -> (3, 2)
  where
    integerOverride field fallback fields =
      case KeyMap.lookup (Key.fromText field) fields of
        Just encoded -> case fromJSON encoded of
          Success number -> number
          Error _ -> fallback
        Nothing -> fallback

persistPriority ::
  OperationInput -> Priority.PriorityState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistPriority input priority resultValue state = do
  accepted <- appendForFixture input "priority"
    [ProposeValueStored "v1.priority" (toJSON priority)] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

createRootPriorityOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
createRootPriorityOperation input state = do
  arguments <- requireArgumentsObject input
  title <- requiredText "title" arguments
  _ <- requiredAs "title_authority" arguments :: Either Text Authority
  behavior <- requiredText "behavior" arguments
  when (Text.null (Text.strip behavior)) (Left "behavior must not be empty")
  now <- operationTime input
  priority <- priorityStateForOperation input state
  let randomEvidence = fromMaybe (actionIdFor input)
        (ambientText (ambientRandomEvidence (operationAmbient input)))
  (brick, insertion, next) <- mapPriorityError
    (Priority.createPriorityRoot title randomEvidence now priority)
  persistPriority input next (object
    [ "brick" .= Priority.priorityBrickId brick
    , "insertion" .= Priority.priorityInsertionId insertion
    ]) state

createChildPriorityOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
createChildPriorityOperation input state = do
  arguments <- requireArgumentsObject input
  parent <- requiredAs "parent" arguments
  title <- requiredText "title" arguments
  _ <- requiredAs "title_authority" arguments :: Either Text Authority
  behavior <- requiredText "behavior" arguments
  when (Text.null (Text.strip behavior)) (Left "behavior must not be empty")
  now <- operationTime input
  priority <- priorityStateForOperation input state
  let randomEvidence = fromMaybe (actionIdFor input)
        (ambientText (ambientRandomEvidence (operationAmbient input)))
  (brick, insertion, next) <- mapPriorityError
    (Priority.createPriorityChild parent title randomEvidence now priority)
  persistPriority input next (object
    [ "brick" .= Priority.priorityBrickId brick
    , "insertion" .= Priority.priorityInsertionId insertion
    ]) state

answerPriorityComparisonOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
answerPriorityComparisonOperation input state = do
  arguments <- requireArgumentsObject input
  insertion <- requiredAs "insertion" arguments
  answerText <- requiredText "answer" arguments
  answer <- case answerText of
    "yes" -> Right True
    "no" -> Right False
    _ -> Left "priority answer must be yes or no"
  authority <- requiredAs "authority" arguments
  reason <- optionalAs "reason" arguments
  now <- operationTime input
  priority <- priorityStateForOperation input state
  (updated, judgment, next) <- mapPriorityError
    (Priority.answerPriorityInsertion insertion answer authority reason now priority)
  persistPriority input next (object
    [ "insertion" .= Priority.priorityInsertionId updated
    , "judgment" .= Priority.priorityJudgmentId judgment
    ]) state

skipPriorityComparisonOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
skipPriorityComparisonOperation input state = do
  arguments <- requireArgumentsObject input
  insertion <- requiredAs "insertion" arguments
  kind <- requiredAs "kind" arguments
  now <- operationTime input
  priority <- priorityStateForOperation input state
  (updated, skipped, next) <- mapPriorityError
    (Priority.skipPriorityComparison insertion kind now priority)
  persistPriority input next (object
    [ "insertion" .= Priority.priorityInsertionId updated
    , "skip" .= Priority.priorityComparisonSkipId skipped
    ]) state

reopenPriorityInsertionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reopenPriorityInsertionOperation input state = do
  arguments <- requireArgumentsObject input
  insertion <- requiredAs "insertion" arguments
  priority <- priorityStateForOperation input state
  (updated, next) <- mapPriorityError
    (Priority.reopenPriorityInsertion insertion priority)
  persistPriority input next (object
    ["insertion" .= Priority.priorityInsertionId updated]) state

openProvocativeValidationOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
openProvocativeValidationOperation input state = do
  arguments <- requireArgumentsObject input
  axis <- requiredAs "axis" arguments
  when (axis /= Priority.PriorityAxis)
    (Left "this implementation slice opens priority probes only")
  scope <- requiredAs "scope" arguments
  left <- requiredAs "left" arguments
  right <- requiredAs "right" arguments
  purpose <- requiredAs "purpose" arguments
  let reason = fromMaybe "provocative validation of retained priority evidence"
        (optionalText "reason" arguments)
  now <- operationTime input
  priority <- priorityStateForOperation input state
  (probe, next) <- mapPriorityError
    (Priority.openPriorityProbe scope left right purpose reason now priority)
  persistPriority input next (toJSON (Priority.judgmentProbeId probe)) state

recordPriorityJudgmentOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
recordPriorityJudgmentOperation input state = do
  arguments <- requireArgumentsObject input
  scope <- requiredAs "scope" arguments
  moreImportant <- requiredAs "more_important" arguments
  lessImportant <- requiredAs "less_important" arguments
  authority <- requiredAs "authority" arguments
  reason <- optionalAs "reason" arguments
  now <- operationTime input
  priority <- priorityStateForOperation input state
  (judgment, recalibration, next) <- mapPriorityError
    (Priority.recordPriorityJudgment scope moreImportant lessImportant
      authority reason now priority)
  persistPriority input next (object
    [ "judgment" .= Priority.priorityJudgmentId judgment
    , "recalibration" .= fmap Priority.priorityRecalibrationId recalibration
    ]) state

commitPriorityRecalibrationOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
commitPriorityRecalibrationOperation input state = do
  arguments <- requireArgumentsObject input
  recalibration <- requiredAs "recalibration" arguments
  now <- operationTime input
  priority <- priorityStateForOperation input state
  (resolved, next) <- mapPriorityError
    (Priority.commitPriorityRecalibration recalibration now priority)
  persistPriority input next (object
    ["recalibration" .= Priority.priorityRecalibrationId resolved]) state

strictRootPriorityFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
strictRootPriorityFixture input state = do
  arguments <- requireArgumentsObject input
  titles <- requiredTextValues "titles" arguments
  pairs <- requiredTextPairs "direct_human_judgments" arguments
  now <- operationTime input
  priority <- priorityStateForOperation input state
  let randomEvidence = fromMaybe (actionIdFor input)
        (ambientText (ambientRandomEvidence (operationAmbient input)))
  (byTitle, next) <- mapPriorityError
    (Priority.createStrictRootFixture titles pairs randomEvidence now priority)
  let resultFields =
        (Key.fromText "scope", toJSON Priority.priorityRootScopeId)
        : [ (Key.fromText title, toJSON identifier)
          | (title, identifier) <- Map.toList byTitle
          ]
  persistPriority input next (Object (KeyMap.fromList resultFields)) state

priorityInsertionObservation :: ObservationInput -> V1State -> Either Text Value
priorityInsertionObservation input state = do
  identifier <- exactlyOneAsArgument "PriorityInsertion" input
  priority <- priorityStateFromKernel state
  mapPriorityError (Priority.priorityInsertionProjection priority identifier)

priorityJudgmentsForObservation :: ObservationInput -> V1State -> Either Text Value
priorityJudgmentsForObservation input state = do
  brick <- exactlyOneAsArgument "PriorityJudgmentsFor" input
  priority <- priorityStateFromKernel state
  let items =
        [ judgment
        | judgment <- Map.elems (Priority.priorityStateJudgments priority)
        , brick `elem`
            [ Priority.priorityJudgmentMoreImportant judgment
            , Priority.priorityJudgmentLessImportant judgment
            ]
        ]
  pure (object ["items" .= items])

priorityEvidenceForObservation :: ObservationInput -> V1State -> Either Text Value
priorityEvidenceForObservation input state = do
  brick <- exactlyOneAsArgument "PriorityEvidenceFor" input
  priority <- priorityStateFromKernel state
  _ <- maybe (Left "unknown priority Brick") Right
    (Map.lookup brick (Priority.priorityStateBricks priority))
  pure (object
    [ "contains_equality" .= False
    , "history" .=
        [ judgment
        | judgment <- Map.elems (Priority.priorityStateJudgments priority)
        , brick `elem`
            [ Priority.priorityJudgmentMoreImportant judgment
            , Priority.priorityJudgmentLessImportant judgment
            ]
        ]
    ])

rootPriorityObservation :: ObservationInput -> V1State -> Either Text Value
rootPriorityObservation input state = do
  requireNoArguments "RootPriority" input
  priority <- priorityStateFromKernel state
  mapPriorityError
    (Priority.priorityScopeProjection priority Priority.priorityRootScopeId)

priorityViewItemObservation :: ObservationInput -> V1State -> Either Text Value
priorityViewItemObservation input state = do
  brick <- exactlyOneAsArgument "PriorityViewItem" input
  priority <- priorityStateFromKernel state
  toJSON <$> mapPriorityError (Priority.priorityViewItem priority brick)

judgmentProbeObservation :: ObservationInput -> V1State -> Either Text Value
judgmentProbeObservation input state = do
  identifier <- exactlyOneAsArgument "JudgmentProbe" input
  priority <- priorityStateFromKernel state
  mapPriorityError (Priority.probeProjection priority identifier)

priorityEvidenceObservation :: ObservationInput -> V1State -> Either Text Value
priorityEvidenceObservation input state = do
  (scope, left, right) <- exactlyThreeAsArguments "PriorityEvidence" input
  priority <- priorityStateFromKernel state
  toJSON <$> mapPriorityError (Priority.priorityEvidence priority scope left right)

priorityRecalibrationObservation :: ObservationInput -> V1State -> Either Text Value
priorityRecalibrationObservation input state = do
  identifier <- exactlyOneAsArgument "PriorityRecalibration" input
  priority <- priorityStateFromKernel state
  mapPriorityError (Priority.priorityRecalibrationProjection priority identifier)

requiredTextValues :: Text -> Object -> Either Text [Text]
requiredTextValues field values = requiredArray field values >>= mapM (\case
  String value -> Right value
  _ -> Left ("field must contain only text: " <> field))

requiredTextPairs :: Text -> Object -> Either Text [(Text, Text)]
requiredTextPairs field values = requiredArray field values >>= mapM (\case
  Array pair -> case toList pair of
    [String first, String second] -> Right (first, second)
    _ -> Left ("field must contain text pairs: " <> field)
  _ -> Left ("field must contain arrays: " <> field))

requireNoArguments :: Text -> ObservationInput -> Either Text ()
requireNoArguments name input = case observationArguments input of
  [] -> Right ()
  _ -> Left (name <> " expects no arguments")

exactlyThreeAsArguments ::
  (FromJSON first, FromJSON second, FromJSON third) =>
  Text -> ObservationInput -> Either Text (first, second, third)
exactlyThreeAsArguments name input = case observationArguments input of
  [firstValue, secondValue, thirdValue] -> (,,)
    <$> decodeArgument name firstValue
    <*> decodeArgument name secondValue
    <*> decodeArgument name thirdValue
  _ -> Left (name <> " expects exactly three arguments")

decodeArgument :: FromJSON value => Text -> Value -> Either Text value
decodeArgument name value = case fromJSON value of
  Success decoded -> Right decoded
  Error problem -> Left (name <> " received an invalid argument: "
    <> Text.pack problem)

mapPriorityError :: Either Priority.PriorityError value -> Either Text value
mapPriorityError = either (Left . Text.pack . show) Right

------------------------------------------------------------
-- Material operations and observations
------------------------------------------------------------

materialStateFromKernel :: V1State -> Either Text MaterialState
materialStateFromKernel state = case kernelValue "v1.material" state of
  Nothing -> Right emptyMaterialState
  Just value -> case fromJSON value of
    Success material -> Right material
    Error problem -> Left ("stored material state is malformed: " <> Text.pack problem)

persistMaterial ::
  OperationInput -> MaterialState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistMaterial input material resultValue state = do
  accepted <- appendForFixture input "material"
    [ProposeValueStored "v1.material" (toJSON material)] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

captureInlineRawOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
captureInlineRawOperation input state = do
  arguments <- requireArgumentsObject input
  original <- requiredText "original_text" arguments
  canonical <- optionalAs "canonical_english" arguments
  authority <- optionalAs "authority" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (raw, next) <- mapMaterialError
    (captureInlineRaw original canonical authority now material)
  persistMaterial input next (object ["raw" .= rawId raw]) state

captureExternalRawOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
captureExternalRawOperation input state = do
  arguments <- requireArgumentsObject input
  title <- optionalAs "title" arguments
  adapter <- requiredText "adapter" arguments
  locator <- requiredText "locator" arguments
  externalId <- optionalAs "external_id" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  ((raw, origin), next) <- mapMaterialError
    (captureExternalRaw title adapter locator externalId now material)
  persistMaterial input next (object
    [ "raw" .= rawId raw
    , "origin" .= rawOriginId origin
    ]) state

captureRawSnapshotOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
captureRawSnapshotOperation input state = do
  arguments <- requireArgumentsObject input
  raw <- requiredAs "raw" arguments
  contentHash <- requiredText "content_hash" arguments
  size <- requiredInteger "size" arguments
  mediaType <- requiredText "media_type" arguments
  originRevision <- optionalAs "origin_revision" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (captureResult, next) <- mapMaterialError
    (captureRawSnapshot raw contentHash size mediaType originRevision now material)
  let (snapshot, reused) = case captureResult of
        SnapshotCreated created -> (created, False)
        SnapshotReused existing -> (existing, True)
  persistMaterial input next (object
    [ "snapshot" .= rawSnapshotId snapshot
    , "reused" .= reused
    ]) state

reportSnapshotMissingOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reportSnapshotMissingOperation = snapshotTransitionOperation reportSnapshotMissing

reportSnapshotCorruptOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reportSnapshotCorruptOperation = snapshotTransitionOperation reportSnapshotCorrupt

snapshotTransitionOperation ::
  (RawSnapshotId -> MaterialState ->
    Either MaterialError (RawSnapshot, MaterialState)) ->
  OperationInput -> V1State -> Either Text (OperationResult V1State)
snapshotTransitionOperation transition input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "snapshot" arguments
  material <- materialStateFromKernel state
  (snapshot, next) <- mapMaterialError (transition identifier material)
  persistMaterial input next (object ["snapshot" .= rawSnapshotId snapshot]) state

verifySnapshotBytesOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
verifySnapshotBytesOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "snapshot" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (snapshot, next) <- mapMaterialError
    (verifySnapshotBytes identifier now material)
  persistMaterial input next (object ["snapshot" .= rawSnapshotId snapshot]) state

recordSourceObservationOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
recordSourceObservationOperation input state = do
  arguments <- requireArgumentsObject input
  origin <- requiredAs "origin" arguments
  authority <- requiredAs "authority" arguments
  externalObservationId <- optionalAs "external_observation_id" arguments
  revision <- optionalAs "revision" arguments
  presence <- requiredAs "presence" arguments
  workState <- requiredAs "work_state" arguments
  failureDetail <- optionalAs "failure_detail" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (observation, next) <- mapMaterialError (recordSourceObservation origin
    authority externalObservationId revision presence workState failureDetail now material)
  persistMaterial input next (object
    ["observation" .= sourceObservationId observation]) state

relocateRawOriginOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
relocateRawOriginOperation input state = do
  arguments <- requireArgumentsObject input
  origin <- requiredAs "origin" arguments
  locator <- requiredText "new_locator" arguments
  material <- materialStateFromKernel state
  (updated, next) <- mapMaterialError (relocateRawOrigin origin locator material)
  persistMaterial input next (object ["origin" .= rawOriginId updated]) state

retireRawOriginOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
retireRawOriginOperation input state = do
  arguments <- requireArgumentsObject input
  origin <- requiredAs "origin" arguments
  material <- materialStateFromKernel state
  (updated, next) <- mapMaterialError (retireRawOrigin origin material)
  persistMaterial input next (object ["origin" .= rawOriginId updated]) state

reviewRawOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reviewRawOperation input state = do
  arguments <- requireArgumentsObject input
  raw <- requiredAs "raw" arguments
  kind <- requiredAs "kind" arguments
  brick <- optionalAs "brick" arguments
  authority <- requiredAs "authority" arguments
  note <- optionalAs "note" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  ((updated, disposition), next) <- mapMaterialError
    (reviewRaw raw kind brick authority note now material)
  persistMaterial input next (object
    [ "raw" .= rawId updated
    , "disposition" .= rawReviewDispositionId disposition
    ]) state

reopenRawOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reopenRawOperation = rawAxisOperation reopenRaw

archiveRawOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
archiveRawOperation = rawAxisOperation archiveRaw

unarchiveRawOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
unarchiveRawOperation = rawAxisOperation unarchiveRaw

rawAxisOperation ::
  (RawId -> MaterialState -> Either MaterialError (Raw, MaterialState)) ->
  OperationInput -> V1State -> Either Text (OperationResult V1State)
rawAxisOperation transition input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "raw" arguments
  material <- materialStateFromKernel state
  (raw, next) <- mapMaterialError (transition identifier material)
  persistMaterial input next (object ["raw" .= rawId raw]) state

linkRawToBrickOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
linkRawToBrickOperation input state = do
  arguments <- requireArgumentsObject input
  raw <- requiredAs "raw" arguments
  brick <- requiredAs "brick" arguments
  role <- requiredAs "role" arguments
  baseline <- optionalAs "baseline" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (link, next) <- mapMaterialError
    (linkRawToBrick raw brick role baseline now material)
  persistMaterial input next (object ["link" .= rawLinkId link]) state

linkRawToEntryOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
linkRawToEntryOperation input state = do
  arguments <- requireArgumentsObject input
  raw <- requiredAs "raw" arguments
  entry <- requiredAs "entry" arguments
  role <- requiredAs "role" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (link, next) <- mapMaterialError (linkRawToEntry raw entry role now material)
  persistMaterial input next (object ["link" .= rawLinkId link]) state

linkDerivedRawOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
linkDerivedRawOperation input state = do
  arguments <- requireArgumentsObject input
  raw <- requiredAs "raw" arguments
  source <- requiredAs "source" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (link, next) <- mapMaterialError (linkDerivedRaw raw source now material)
  persistMaterial input next (object ["link" .= rawLinkId link]) state

reconcileRawLinkOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reconcileRawLinkOperation input state = do
  arguments <- requireArgumentsObject input
  link <- requiredAs "link" arguments
  snapshot <- requiredAs "snapshot" arguments
  material <- materialStateFromKernel state
  (updated, next) <- mapMaterialError (reconcileRawLink link snapshot material)
  persistMaterial input next (object ["link" .= rawLinkId updated]) state

createRawShelfOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
createRawShelfOperation input state = do
  arguments <- requireArgumentsObject input
  name <- requiredText "name" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (shelf, next) <- mapMaterialError (createRawShelf name now material)
  persistMaterial input next (object ["shelf" .= rawShelfId shelf]) state

addRawToShelfOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
addRawToShelfOperation input state = do
  arguments <- requireArgumentsObject input
  raw <- requiredAs "raw" arguments
  shelf <- requiredAs "shelf" arguments
  now <- operationTime input
  material <- materialStateFromKernel state
  (membership, next) <- mapMaterialError (addRawToShelf raw shelf now material)
  persistMaterial input next (object
    ["membership" .= rawShelfMembershipId membership]) state

removeRawFromShelfOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
removeRawFromShelfOperation input state = do
  arguments <- requireArgumentsObject input
  raw <- requiredAs "raw" arguments
  shelf <- requiredAs "shelf" arguments
  material <- materialStateFromKernel state
  next <- mapMaterialError (removeRawFromShelf raw shelf material)
  persistMaterial input next (object
    [ "raw" .= (raw :: RawId)
    , "shelf" .= (shelf :: RawShelfId)
    , "removed" .= True
    ]) state

activeRootBrickFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
activeRootBrickFixture input state = do
  arguments <- requireArgumentsObject input
  titleText <- requiredText "title" arguments
  title <- mapDomainError (mkCanonicalText titleText Nothing Human)
  (brick, _) <- mapDomainError
    (createBrick (ordinaryBrickDraft title standardV1 domainFixtureTime)
      emptyDomainState)
  material <- materialStateFromKernel state
  let next = registerMaterialBrick (brickId brick) Active material
  persistMaterial input next (object ["brick" .= brickId brick]) state

materialEntitiesFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
materialEntitiesFixture input state = do
  material <- materialStateFromKernel state
  ((raw, origin), first) <- mapMaterialError (captureExternalRaw
    (Just "Fixture source") "fixture" "fixture:source" Nothing
    domainFixtureTime material)
  persistMaterial input first (object
    [ "raw" .= rawId raw
    , "origin" .= rawOriginId origin
    ]) state

materialStateObservation :: ObservationInput -> V1State -> Either Text Value
materialStateObservation _ state = toJSON <$> materialStateFromKernel state

rawSnapshotsObservation :: ObservationInput -> V1State -> Either Text Value
rawSnapshotsObservation input state = do
  identifier <- exactlyOneAsArgument "RawSnapshots" input
  material <- materialStateFromKernel state
  _ <- mapMaterialError (rawProjection material identifier)
  let snapshots =
        [ snapshot
        | snapshot <- Map.elems (materialSnapshots material)
        , rawSnapshotRaw snapshot == identifier
        ]
  pure (object
    [ "content_hashes" .= map rawSnapshotContentHash snapshots
    , "snapshots" .= snapshots
    ])

openProposalsObservation :: ObservationInput -> V1State -> Either Text Value
openProposalsObservation input state = do
  brick <- exactlyOneAsArgument "OpenProposalsFor" input
  material <- materialStateFromKernel state
  priority <- priorityStateFromKernel state
  pure (object ["kinds" .= (openSourceReconciliationKinds material brick
    <> Priority.priorityProposalKinds priority brick)])

materialBrickSummaryObservation :: ObservationInput -> V1State -> Either Text Value
materialBrickSummaryObservation input state = do
  brick <- exactlyOneAsArgument "BrickSummary" input
  material <- materialStateFromKernel state
  status <- maybe (Left "unknown material Brick owner") Right
    (Map.lookup brick (materialBrickStatuses material))
  pure (object ["id" .= brick, "status" .= status])

rawSummaryObservation :: ObservationInput -> V1State -> Either Text Value
rawSummaryObservation input state = do
  identifier <- exactlyOneAsArgument "RawSummary" input
  material <- materialStateFromKernel state
  mapMaterialError (rawProjection material identifier)

latestSourceObservationQuery :: ObservationInput -> V1State -> Either Text Value
latestSourceObservationQuery input state = do
  identifier <- exactlyOneAsArgument "LatestSourceObservation" input
  material <- materialStateFromKernel state
  observation <- mapMaterialError (latestSourceObservation material identifier)
  maybe (Left "source origin has no observations")
    (Right . sourceObservationProjection) observation

rawLinkObservation :: ObservationInput -> V1State -> Either Text Value
rawLinkObservation input state = do
  identifier <- exactlyOneAsArgument "RawLink" input
  material <- materialStateFromKernel state
  mapMaterialError (rawLinkProjection material identifier)

externalIoTraceObservation :: ObservationInput -> V1State -> Either Text Value
externalIoTraceObservation _ _ = Right (object
  [ "implicit_reads" .= ([] :: [Text])
  , "explicit_reads" .= ([] :: [Text])
  ])

populatedFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
populatedFixture input state = runSimpleAction input state
  [ ProposeValueStored "fixture" (String "kernel_populated")
  , ProposeEntityCreated "kernel_fixture" KeyMap.empty
  ]

definitionCatalogFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
definitionCatalogFixture input state = do
  projection <- definitionCatalogProjection
  accepted <- appendForFixture input "definition-catalog"
    [ProposeValueStored "v1.definition_catalog" projection] state
  pure OperationResult
    { operationResultValue = projection
    , operationResultState = appendResultState accepted
    }

domainEntitiesFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
domainEntitiesFixture input state = do
  projection <- domainFixtureProjection
  accepted <- appendForFixture input "domain-entities"
    [ProposeValueStored "v1.domain" projection] state
  pure OperationResult
    { operationResultValue = projection
    , operationResultState = appendResultState accepted
    }

referenceFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
referenceFixture input state = do
  first <- appendForFixture input "reference-base"
    [ ProposeValueStored "confidence" (toJSON (0.8 :: Double))
    , ProposeValueStored "actual_probability" (toJSON (0.5 :: Double))
    , ProposeEntityCreated "brick" (KeyMap.singleton "title"
        (String "Reference target"))
    ] state
  target <- case appendResultAllocatedIds first of
    [identifier] -> Right identifier
    identifiers -> Left ("reference fixture allocated unexpected IDs: "
      <> Text.pack (show identifiers))
  second <- appendForFixture input "reference-forecast"
    [ProposeValueStored ("forecast:" <> unOpaqueId target)
      (object ["probability" .= (0.25 :: Double)])]
    (appendResultState first)
  pure OperationResult
    { operationResultValue = object ["taxes" .= unOpaqueId target]
    , operationResultState = appendResultState second
    }

appendForFixture ::
  OperationInput -> Text -> [ProposedEvent] -> V1State ->
  Either Text AppendResult
appendForFixture input suffix events state = mapKernelError
  (appendSemanticAction AppendRequest
    { appendExpectedRevision = kernelRevision state
    , appendSemanticActionId = actionIdFor input <> ":" <> suffix
    , appendActorOrOrigin = "contract:kernel-fixture"
    , appendOccurredAt = ambientText (ambientClock (operationAmbient input))
    , appendProposedEvents = events
    } state)

domainRevisionObservation :: ObservationInput -> V1State -> Either Text Value
domainRevisionObservation _ = Right . toJSON . kernelRevision

domainStateObservation :: ObservationInput -> V1State -> Either Text Value
domainStateObservation _ state = maybe
  (Left "domain entity fixture has not been created")
  Right
  (kernelValue "v1.domain" state)

builtInCatalogObservation :: ObservationInput -> V1State -> Either Text Value
builtInCatalogObservation _ _ = definitionCatalogProjection

definitionCatalogProjection :: Either Text Value
definitionCatalogProjection = do
  behaviors <- mapDomainError
    (findBehaviors "" Nothing 50 (domainCatalog emptyDomainState))
  templates <- mapDomainError
    (findTemplates "" Nothing Nothing 50 (domainCatalog emptyDomainState))
  pure (object
    [ "behaviors" .= behaviors
    , "templates" .= templates
    , "behavior_count" .= length behaviors
    , "template_count" .= length templates
    ])

domainFixtureProjection :: Either Text Value
domainFixtureProjection = do
  (party, first) <- mapDomainError
    (createParty "Contract user" Person domainFixtureTime emptyDomainState)
  title <- mapDomainError
    (mkCanonicalText "Prepare release" (Just "Preparar lançamento") Human)
  (brick, second) <- mapDomainError
    (createBrick (ordinaryBrickDraft title finiteChecklistV1 domainFixtureTime)
      first)
  entryLabel <- mapDomainError
    (mkCanonicalText "Verify package" (Just "Verificar pacote") Human)
  (_, third) <- mapDomainError
    (createListEntry (ListEntryDraft (brickId brick) entryLabel Nothing Nothing
      domainFixtureTime) second)
  (_, fourth) <- mapDomainError
    (focusBrick (Just (brickId brick)) domainFixtureTime third)
  projection <- mapDomainError (domainProjection fourth)
  pure (object
    [ "user_id" .= partyId party
    , "brick_id" .= brickId brick
    , "state" .= projection
    ])

domainFixtureTime :: UTCTime
domainFixtureTime = UTCTime (fromGregorian 2026 7 27) 0

canonicalStateObservation :: ObservationInput -> V1State -> Either Text Value
canonicalStateObservation _ = Right . toJSON

canonicalStateHashObservation ::
  ObservationInput -> V1State -> Either Text Value
canonicalStateHashObservation input state = case observationArguments input of
  [] -> Right (String (canonicalStateHash state))
  [String "current"] -> Right (String (canonicalStateHash state))
  _ -> Left "CanonicalStateHash expects no argument or current"

eventBatchesObservation :: ObservationInput -> V1State -> Either Text Value
eventBatchesObservation _ = Right . toJSON . kernelEventBatches

adapterTraceObservation :: ObservationInput -> V1State -> Either Text Value
adapterTraceObservation _ state = do
  replayed <- mapKernelError (replayAll (kernelEventBatches state))
  pure (toJSON (replayResultExternalTrace replayed))

valueObservation :: ObservationInput -> V1State -> Either Text Value
valueObservation input state = do
  key <- exactlyOneTextArgument "KernelValue" input
  maybe (Left ("unknown kernel value: " <> key)) Right (kernelValue key state)

entityObservation :: ObservationInput -> V1State -> Either Text Value
entityObservation input state = do
  identifier <- OpaqueId <$> exactlyOneTextArgument "KernelEntity" input
  maybe (Left "unknown kernel entity") Right (kernelEntity identifier state)

kernelSummaryObservation :: ObservationInput -> V1State -> Either Text Value
kernelSummaryObservation _ state = Right (object
  [ "domain_revision" .= kernelRevision state
  , "event_batch_count" .= length (kernelEventBatches state)
  , "state_hash" .= canonicalStateHash state
  ])

-- False and zero are required answers here; optional result fields are omitted
-- by schema rather than recursively deleted by value.
operationalResponseObservation ::
  ObservationInput -> V1State -> Either Text Value
operationalResponseObservation _ state = Right (object
  [ "ok" .= False
  , "human" .= ("no kernel command selected" :: Text)
  , "changed" .= ([] :: [Text])
  , "warnings" .= ([] :: [Text])
  , "domain_revision" .= kernelRevision state
  ])

confidenceBeforeReference :: ReferenceInput V1State -> Either Text Value
confidenceBeforeReference input = do
  stepId <- maybe
    (Left "confidence_before reference must name a step")
    Right
    (Text.stripPrefix "confidence_before:" (referenceInputSource input))
  checkpoint <- maybe
    (Left ("unknown confidence checkpoint: before:" <> stepId))
    Right
    (Map.lookup ("before:" <> stepId) (referenceInputCheckpoints input))
  query <- requiredText "query" (referenceInputAssertion input)
  if "PriorityEvidence(" `Text.isPrefixOf` query
    then priorityConfidenceAt checkpoint query
    else maybe
      (Left "confidence is unavailable at the requested checkpoint")
      Right
      (kernelValue "confidence" (referenceSnapshotState checkpoint))

priorityConfidenceAt :: ReferenceSnapshot V1State -> Text -> Either Text Value
priorityConfidenceAt snapshot query = do
  argumentsText <- maybe
    (Left "priority confidence query is malformed") Right
    (Text.stripPrefix "PriorityEvidence(" query >>= Text.stripSuffix ")")
  let argumentNames = map Text.strip (Text.splitOn "," argumentsText)
  (scope, left, right) <- case argumentNames of
    [scopeName, leftName, rightName] -> (,,)
      <$> boundReference scopeName
      <*> boundReference leftName
      <*> boundReference rightName
    _ -> Left "priority confidence query must name scope, left, and right"
  priority <- priorityStateFromKernel (referenceSnapshotState snapshot)
  evidence <- mapPriorityError (Priority.priorityEvidence priority scope left right)
  pure (toJSON (Priority.priorityEvidenceConfidence evidence))
  where
    boundReference name = do
      binding <- maybe
        (Left "priority confidence query arguments must be bindings") Right
        (Text.stripPrefix "$" name)
      value <- maybe
        (Left ("unknown priority confidence binding: $" <> binding)) Right
        (Map.lookup binding (referenceSnapshotBindings snapshot))
      decodeArgument "priority confidence" value

forecastReference :: ReferenceInput V1State -> Either Text Value
forecastReference input = do
  remainder <- maybe
    (Left "forecast reference has an invalid namespace")
    Right
    (Text.stripPrefix "forecast:" (referenceInputSource input))
  (checkpointLabel, bindingExpression) <- case Text.breakOn ":" remainder of
    (label, expression)
      | not (Text.null label) && not (Text.null expression) ->
          Right (label, Text.drop 1 expression)
    _ -> Left "forecast reference must name a checkpoint and binding"
  snapshot <- findForecastCheckpoint checkpointLabel
    (referenceInputCheckpoints input)
  (bindingName, path) <- parseBindingPath bindingExpression
  bound <- maybe
    (Left ("unknown forecast binding: $" <> bindingName))
    Right
    (Map.lookup bindingName
      (referenceSnapshotBindings (referenceInputCurrent input))
      <|> Map.lookup bindingName (referenceSnapshotBindings snapshot))
  forecast <- case bound of
    String identifier -> maybe
      (Left ("forecast is unavailable for: " <> identifier))
      Right
      (kernelValue ("forecast:" <> identifier) (referenceSnapshotState snapshot))
    value -> Right value
  if Text.null path then Right forecast else selectJsonPath path forecast

findForecastCheckpoint ::
  Text -> Map Text (ReferenceSnapshot V1State) ->
  Either Text (ReferenceSnapshot V1State)
findForecastCheckpoint label checkpoints =
  case direct <|> normalized of
    Just checkpoint -> Right checkpoint
    Nothing -> case fuzzyMatches of
      [checkpoint] -> Right checkpoint
      [] -> Left ("unknown forecast checkpoint: " <> label)
      _ -> Left ("ambiguous forecast checkpoint: " <> label)
  where
    direct = Map.lookup label checkpoints
    normalized = Map.lookup (normalizeCheckpointLabel label) checkpoints
    token = Text.toLower (fromMaybe label
      (Text.stripPrefix "before-" label <|> Text.stripPrefix "after-" label))
    expectedPrefix
      | Text.isPrefixOf "after-" label = "after:"
      | otherwise = "before:"
    fuzzyMatches =
      [ checkpoint
      | (key, checkpoint) <- Map.toList checkpoints
      , expectedPrefix `Text.isPrefixOf` key
      , token `Text.isInfixOf` Text.toLower key
      ]

normalizeCheckpointLabel :: Text -> Text
normalizeCheckpointLabel label
  | Just suffix <- Text.stripPrefix "before-" label = "before:" <> suffix
  | Just suffix <- Text.stripPrefix "after-" label = "after:" <> suffix
  | otherwise = label

parseBindingPath :: Text -> Either Text (Text, Text)
parseBindingPath expression = do
  withoutDollar <- maybe
    (Left "forecast binding must start with '$'")
    Right
    (Text.stripPrefix "$" expression)
  let (binding, suffix) = Text.breakOn "." withoutDollar
  when (Text.null binding) (Left "forecast binding name is empty")
  pure (binding, Text.dropWhile (== '.') suffix)

exactlyOneTextArgument :: Text -> ObservationInput -> Either Text Text
exactlyOneTextArgument name input = case observationArguments input of
  [String value] -> Right value
  _ -> Left (name <> " expects exactly one text argument")

actionIdFor :: OperationInput -> Text
actionIdFor input = "contract:" <> operationName input <> ":" <> operationStepId input

ambientText :: Maybe Value -> Maybe Text
ambientText (Just (String value)) = Just value
ambientText _ = Nothing

mapKernelError :: Either KernelError value -> Either Text value
mapKernelError = either (Left . Text.pack . show) Right

mapDomainError :: Either DomainError value -> Either Text value
mapDomainError = either (Left . Text.pack . show) Right

requireArgumentsObject :: OperationInput -> Either Text Object
requireArgumentsObject input = asObject "operation arguments" (operationArguments input)

asObject :: Text -> Value -> Either Text Object
asObject name value = case value of
  Object result -> Right result
  _ -> Left (name <> " must be an object")

requiredValue :: Text -> Object -> Either Text Value
requiredValue field values = maybe
  (Left ("missing field: " <> field))
  Right
  (KeyMap.lookup (Key.fromText field) values)

requiredText :: Text -> Object -> Either Text Text
requiredText field values = case KeyMap.lookup (Key.fromText field) values of
  Just (String value) -> Right value
  Just _ -> Left ("field must be text: " <> field)
  Nothing -> Left ("missing field: " <> field)

requiredInteger :: Text -> Object -> Either Text Integer
requiredInteger field values = case KeyMap.lookup (Key.fromText field) values of
  Just value -> case fromJSON value of
    Success integer -> Right integer
    Error _ -> Left ("field must be an integer: " <> field)
  Nothing -> Left ("missing field: " <> field)

requiredArray :: Text -> Object -> Either Text [Value]
requiredArray field values = case KeyMap.lookup (Key.fromText field) values of
  Just (Array items) -> Right (toList items)
  Just _ -> Left ("field must be an array: " <> field)
  Nothing -> Left ("missing field: " <> field)

optionalText :: Text -> Object -> Maybe Text
optionalText field values = case KeyMap.lookup (Key.fromText field) values of
  Just (String value) -> Just value
  _ -> Nothing

optionalInteger :: Text -> Object -> Maybe Integer
optionalInteger field values = KeyMap.lookup (Key.fromText field) values >>= \value ->
  case fromJSON value of
    Success integer -> Just integer
    Error _ -> Nothing

optionalObject :: Text -> Object -> Either Text (Maybe Object)
optionalObject field values = case KeyMap.lookup (Key.fromText field) values of
  Nothing -> Right Nothing
  Just Null -> Right Nothing
  Just (Object value) -> Right (Just value)
  Just _ -> Left ("field must be an object: " <> field)

requiredAs :: FromJSON value => Text -> Object -> Either Text value
requiredAs field values = do
  value <- requiredValue field values
  case fromJSON value of
    Success decoded -> Right decoded
    Error problem -> Left ("invalid field " <> field <> ": " <> Text.pack problem)

optionalAs :: FromJSON value => Text -> Object -> Either Text (Maybe value)
optionalAs field values = case KeyMap.lookup (Key.fromText field) values of
  Nothing -> Right Nothing
  Just Null -> Right Nothing
  Just value -> case fromJSON value of
    Success decoded -> Right (Just decoded)
    Error problem -> Left ("invalid field " <> field <> ": " <> Text.pack problem)

exactlyOneAsArgument :: FromJSON value =>
  Text -> ObservationInput -> Either Text value
exactlyOneAsArgument name input = case observationArguments input of
  [value] -> case fromJSON value of
    Success decoded -> Right decoded
    Error problem -> Left (name <> " received an invalid identifier: "
      <> Text.pack problem)
  _ -> Left (name <> " expects exactly one argument")

operationTime :: OperationInput -> Either Text UTCTime
operationTime input = case ambientClock (operationAmbient input) of
  Nothing -> Right domainFixtureTime
  Just value -> case fromJSON value of
    Success timestamp -> Right timestamp
    Error problem -> Left ("scenario clock is not a timestamp: " <> Text.pack problem)

mapMaterialError :: Either MaterialError value -> Either Text value
mapMaterialError = either (Left . Text.pack . show) Right

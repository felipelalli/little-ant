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
import Control.Monad (foldM, when)
import Data.Aeson
  (FromJSON, Object, Result (..), Value (..), fromJSON, object, toJSON, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import Data.Foldable (toList)
import Data.List (find, sortOn)
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
import qualified LittleAnt.V1.Coordination as Coordination
import LittleAnt.V1.Domain
  (Applicability (Applicable), Authority (Human), Brick (brickId), BrickId (..),
   BrickStatus (Active), DomainError,
   ListEntryDraft (..), Party (partyId), PartyType (Person),
   behaviorEffort, behaviorId, behaviorVersions, createBrick, createListEntry,
   createParty, domainCatalog, domainProjection, emptyDomainState,
   finiteChecklistV1, findBehaviors, findTemplates, initialDefinitionCatalog,
   focusBrick, mkCanonicalText, ordinaryBrickDraft, standardV1,
   templateBehavior, templateId, templateVersion, templateVersions)
import qualified LittleAnt.V1.Domain as Domain
import qualified LittleAnt.V1.Execution as Execution
import qualified LittleAnt.V1.Judgment as Judgment
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
import qualified LittleAnt.V1.Standing as Standing

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
      , ("ClassifyImpact", classifyImpactOperation)
      , ("CompareImpact", compareImpactOperation)
      , ("ReviseImpactMaturity", reviseImpactMaturityOperation)
      , ("ClassifyEffort", classifyEffortOperation)
      , ("CompareEffort", compareEffortOperation)
      , ("DeferJudgmentProbe", deferJudgmentProbeOperation)
      , ("ReopenJudgmentProbe", reopenJudgmentProbeOperation)
      , ("ConfirmDecompositionCoverage", confirmDecompositionCoverageOperation)
      , ("ConfirmScopeRevision", confirmScopeRevisionOperation)
      , ("RecordProgressEvidence", recordProgressEvidenceOperation)
      , ("SetJudgmentBrickStatus", setJudgmentBrickStatusOperation)
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
      , ("SetBrickDeadline", setCoordinationDeadlineOperation)
      , ("MoveSubtreeUnderParent", moveCoordinationSubtreeOperation)
      , ("AdvanceTime", advanceCoordinationTimeOperation)
      , ("StartStandingExecution", startStandingExecutionOperation)
      , ("FinishStandingExecution", finishStandingExecutionOperation)
      , ("FinishRepeatableAndSchedule", finishRepeatableAndScheduleOperation)
      , ("FinishRepeatableAndRetire", finishRepeatableAndRetireOperation)
      , ("AbandonExecution", abandonStandingExecutionOperation)
      , ("ConfigureRecurrence", configureRecurrenceOperation)
      , ("PauseRecurrence", pauseRecurrenceOperation)
      , ("ResumeRecurrence", resumeRecurrenceOperation)
      , ("RetireRecurrence", retireRecurrenceOperation)
      , ("ReviseRecurrence", reviseRecurrenceOperation)
      , ("AdvanceSchedules", advanceSchedulesOperation)
      , ("CompletePracticeOpportunity", completePracticeOpportunityOperation)
      , ("AbandonPracticeOpportunity", abandonPracticeOpportunityOperation)
      , ("ConfigureOpportunityTrigger", configureOpportunityTriggerOperation)
      , ("RetireOpportunityTrigger", retireOpportunityTriggerOperation)
      , ("CompleteBrick", completeStandingBrickOperation)
      , ("AddDependency", addStandingDependencyOperation)
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
      , ("JudgmentState", judgmentStateObservation)
      , ("ImpactAssessment", impactAssessmentObservation)
      , ("ImpactComparison", impactComparisonObservation)
      , ("ImpactEvidence", impactEvidenceObservation)
      , ("EffortAssessment", effortAssessmentObservation)
      , ("EffortComparisonEvidence", effortComparisonObservation)
      , ("EffortEvidence", effortEvidenceObservation)
      , ("RemainingEffort", remainingEffortObservation)
      , ("JudgmentProjection", judgmentProjectionObservation)
      , ("OpenProposalsFor", openProposalsObservation)
      , ("BrickSummary", materialBrickSummaryObservation)
      , ("RawSummary", rawSummaryObservation)
      , ("LatestSourceObservation", latestSourceObservationQuery)
      , ("RawLink", rawLinkObservation)
      , ("ExternalIoTrace", externalIoTraceObservation)
      , ("DateNotice", dateNoticeObservation)
      , ("ActiveDateNotices", activeDateNoticesObservation)
      , ("PlaceEvaluation", placeEvaluationObservation)
      , ("LatestExecution", latestExecutionObservation)
      , ("ExecutionHistory", executionHistoryObservation)
      , ("BricksByCanonicalTitle", bricksByCanonicalTitleObservation)
      , ("PracticeOpportunity", practiceOpportunityObservation)
      , ("PracticeOpportunities", practiceOpportunitiesObservation)
      , ("PracticeHistory", practiceHistoryObservation)
      , ("ObligationOccurrences", obligationOccurrencesObservation)
      , ("ObligationHistory", obligationHistoryObservation)
      , ("PriorityPath", priorityPathObservation)
      ]
  , registryFixtures = Map.fromList
      [ ("active_root_brick", activeRootBrickFixture)
      , ("definition_catalog", definitionCatalogFixture)
      , ("domain_entities", domainEntitiesFixture)
      , ("kernel_populated", populatedFixture)
      , ("kernel_reference_state", referenceFixture)
      , ("judgment_entities", judgmentEntitiesFixture)
      , ("material_entities", materialEntitiesFixture)
      , ("strict_root_priority", strictRootPriorityFixture)
      , ("two_projects_with_child", twoProjectsWithChildFixture)
      , ("template_brick", templateBrickFixture)
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
-- Standing execution, deterministic recurrence, and practices
------------------------------------------------------------

standingStateFromKernel :: V1State -> Either Text Standing.StandingState
standingStateFromKernel state = case kernelValue "v1.standing" state of
  Just value -> case fromJSON value of
    Success standing -> do
      mapStandingError (Standing.validateStandingState standing)
      Right standing
    Error problem -> Left ("stored standing state is malformed: "
      <> Text.pack problem)
  Nothing -> do
    coordination <- coordinationStateFromKernel state
    let standing = Standing.emptyStandingState
          {Standing.standingStateCoordination = coordination}
    mapStandingError (Standing.validateStandingState standing)
    Right standing

persistStanding ::
  OperationInput -> Text -> Standing.StandingState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistStanding input suffix standing resultValue state = do
  accepted <- appendForFixture input suffix
    [ ProposeValueStored "v1.standing" (toJSON standing)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination standing))
    ] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

startStandingExecutionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
startStandingExecutionOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (execution, next) <- mapStandingError
    (Standing.startStandingExecution brick now standing)
  persistStanding input "standing-start" next (object
    ["execution" .= Standing.executionOccurrenceId execution]) state

finishStandingExecutionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
finishStandingExecutionOperation input state = do
  arguments <- requireArgumentsObject input
  execution <- requiredAs "execution" arguments
  outcome <- requiredAs "outcome" arguments
  note <- optionalAs "note" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.finishStandingExecution execution outcome note now standing)
  persistStanding input "standing-finish" next (toJSON updated) state

finishRepeatableAndScheduleOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
finishRepeatableAndScheduleOperation input state = do
  arguments <- requireArgumentsObject input
  execution <- requiredAs "execution" arguments
  note <- optionalAs "note" arguments
  baseDelay <- requiredText "base_delay" arguments
  jitterRange <- requiredText "jitter_range" arguments
  randomEvidence <- requiredText "random_evidence" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, evidence, next) <- mapStandingError
    (Standing.finishRepeatableAndSchedule execution note baseDelay jitterRange
      randomEvidence now standing)
  persistStanding input "repeat-schedule" next (object
    [ "execution" .= Standing.executionOccurrenceId updated
    , "not_before" .= Standing.repeatScheduleNotBefore evidence
    ]) state

finishRepeatableAndRetireOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
finishRepeatableAndRetireOperation input state = do
  arguments <- requireArgumentsObject input
  execution <- requiredAs "execution" arguments
  note <- optionalAs "note" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.finishRepeatableAndRetire execution note now standing)
  persistStanding input "repeat-retire" next (toJSON updated) state

abandonStandingExecutionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
abandonStandingExecutionOperation input state = do
  arguments <- requireArgumentsObject input
  execution <- requiredAs "execution" arguments
  note <- optionalAs "note" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.abandonExecution execution note now standing)
  persistStanding input "standing-abandon" next (toJSON updated) state

configureRecurrenceOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
configureRecurrenceOperation input state = do
  arguments <- requireArgumentsObject input
  target <- requiredAs "target" arguments
  kind <- requiredAs "kind" arguments
  schedule <- requiredText "schedule" arguments
  timezone <- requiredText "timezone" arguments
  firstRelease <- requiredAs "first_release" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (recurrence, next) <- mapStandingError (Standing.configureRecurrence target kind
    schedule timezone firstRelease now standing)
  persistStanding input "recurrence-configure" next (object
    ["recurrence" .= Standing.recurrenceRuleId recurrence]) state

pauseRecurrenceOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
pauseRecurrenceOperation input state = do
  arguments <- requireArgumentsObject input
  recurrence <- requiredAs "recurrence" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.pauseRecurrence recurrence now standing)
  persistStanding input "recurrence-pause" next (toJSON updated) state

resumeRecurrenceOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
resumeRecurrenceOperation input state = do
  arguments <- requireArgumentsObject input
  recurrence <- requiredAs "recurrence" arguments
  nextRelease <- requiredAs "next_release" arguments
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.resumeRecurrence recurrence nextRelease standing)
  persistStanding input "recurrence-resume" next (toJSON updated) state

retireRecurrenceOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
retireRecurrenceOperation input state = do
  arguments <- requireArgumentsObject input
  recurrence <- requiredAs "recurrence" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.retireRecurrence recurrence now standing)
  persistStanding input "recurrence-retire" next (toJSON updated) state

reviseRecurrenceOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reviseRecurrenceOperation input state = do
  arguments <- requireArgumentsObject input
  recurrence <- requiredAs "recurrence" arguments
  schedule <- requiredText "schedule" arguments
  timezone <- requiredText "timezone" arguments
  nextRelease <- requiredAs "next_release" arguments
  reason <- requiredText "reason" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (revision, next) <- mapStandingError (Standing.reviseRecurrence recurrence
    schedule timezone nextRelease reason authority now standing)
  persistStanding input "recurrence-revise" next (object
    ["revision" .= Standing.recurrenceRevisionId revision]) state

advanceSchedulesOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
advanceSchedulesOperation input state = do
  arguments <- requireArgumentsObject input
  at <- requiredAs "at" arguments
  standing <- standingStateFromKernel state
  (obligations, practices, next) <- mapStandingError
    (Standing.advanceSchedules at standing)
  persistStanding input "schedules-advance" next (object
    [ "occurrence" .= fmap Standing.obligationOccurrenceBrick (lastMay obligations)
    , "occurrences" .= map Standing.obligationOccurrenceBrick obligations
    , "opportunities" .= map Standing.practiceOpportunityId practices
    ]) state

completePracticeOpportunityOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
completePracticeOpportunityOperation input state = do
  arguments <- requireArgumentsObject input
  opportunity <- requiredAs "opportunity" arguments
  note <- optionalAs "note" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, execution, next) <- mapStandingError
    (Standing.completePracticeOpportunity opportunity note now standing)
  persistStanding input "practice-complete" next (object
    [ "opportunity" .= Standing.practiceOpportunityId updated
    , "execution" .= Standing.executionOccurrenceId execution
    ]) state

abandonPracticeOpportunityOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
abandonPracticeOpportunityOperation input state = do
  arguments <- requireArgumentsObject input
  opportunity <- requiredAs "opportunity" arguments
  reason <- optionalAs "reason" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.abandonPracticeOpportunity opportunity reason now standing)
  persistStanding input "practice-abandon" next (toJSON updated) state

configureOpportunityTriggerOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
configureOpportunityTriggerOperation input state = do
  arguments <- requireArgumentsObject input
  source <- requiredAs "source" arguments
  target <- requiredAs "target" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (trigger, next) <- mapStandingError
    (Standing.configureOpportunityTrigger source target now standing)
  persistStanding input "trigger-configure" next (object
    ["trigger" .= Standing.opportunityTriggerId trigger]) state

retireOpportunityTriggerOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
retireOpportunityTriggerOperation input state = do
  arguments <- requireArgumentsObject input
  trigger <- requiredAs "trigger" arguments
  standing <- standingStateFromKernel state
  (updated, next) <- mapStandingError
    (Standing.retireOpportunityTrigger trigger standing)
  persistStanding input "trigger-retire" next (toJSON updated) state

completeStandingBrickOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
completeStandingBrickOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  note <- optionalAs "note" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  next <- mapStandingError (Standing.completeStandingBrick brick note
    (actionIdFor input) now standing)
  persistStanding input "brick-complete" next (object ["brick" .= brick]) state

addStandingDependencyOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
addStandingDependencyOperation input state = do
  arguments <- requireArgumentsObject input
  blocked <- requiredAs "blocked" arguments
  blocker <- requiredAs "blocker" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  next <- mapStandingError
    (Standing.addStandingDependency blocked blocker now standing)
  persistStanding input "dependency-add" next (object
    ["blocked" .= blocked, "blocker" .= blocker]) state

latestExecutionObservation :: ObservationInput -> V1State -> Either Text Value
latestExecutionObservation input state = do
  brick <- exactlyOneAsArgument "LatestExecution" input
  standing <- standingStateFromKernel state
  case lastMay (sortOn Standing.executionOccurrenceId
      [execution | execution <- Map.elems (Standing.standingStateExecutions standing),
        Standing.executionOccurrenceBrick execution == brick]) of
    Nothing -> Right Null
    Just execution -> Right (toJSON execution)

executionHistoryObservation :: ObservationInput -> V1State -> Either Text Value
executionHistoryObservation input state = do
  brick <- exactlyOneAsArgument "ExecutionHistory" input
  standing <- standingStateFromKernel state
  let items = sortOn Standing.executionOccurrenceId
        [execution | execution <- Map.elems (Standing.standingStateExecutions standing),
          Standing.executionOccurrenceBrick execution == brick]
  pure (object ["items" .= items])

bricksByCanonicalTitleObservation ::
  ObservationInput -> V1State -> Either Text Value
bricksByCanonicalTitleObservation input state = do
  title <- exactlyOneAsArgument "BricksByCanonicalTitle" input
  standing <- standingStateFromKernel state
  let domain = Execution.executionStateDomain
        (Coordination.coordinationStateExecution
          (Standing.standingStateCoordination standing))
      identifiers = [brickId brick | brick <- Map.elems (Domain.domainBricks domain),
        Domain.brickTitle brick == title]
  items <- mapM (mapDomainError . standingBrickProjection domain) identifiers
  pure (object ["items" .= items])

practiceOpportunityObservation ::
  ObservationInput -> V1State -> Either Text Value
practiceOpportunityObservation input state = do
  identifier <- exactlyOneAsArgument "PracticeOpportunity" input
  standing <- standingStateFromKernel state
  maybe (Left "unknown PracticeOpportunity") (Right . toJSON)
    (Map.lookup identifier (Standing.standingStatePracticeOpportunities standing))

practiceOpportunitiesObservation ::
  ObservationInput -> V1State -> Either Text Value
practiceOpportunitiesObservation input state = do
  (recurrence, period) <- case observationArguments input of
    [recurrenceValue, periodValue] -> (,)
      <$> decodeArgument "PracticeOpportunities" recurrenceValue
      <*> (Just <$> decodeArgument "PracticeOpportunities" periodValue)
    [recurrenceValue] -> (,)
      <$> decodeArgument "PracticeOpportunities" recurrenceValue
      <*> pure Nothing
    _ -> Left "PracticeOpportunities expects a recurrence and optional period"
  standing <- standingStateFromKernel state
  pure (object ["items" .= Standing.practiceOpportunitiesFor recurrence period standing])

practiceHistoryObservation :: ObservationInput -> V1State -> Either Text Value
practiceHistoryObservation input state = do
  recurrence <- exactlyOneAsArgument "PracticeHistory" input
  standing <- standingStateFromKernel state
  toJSON <$> mapStandingError (Standing.practiceHistory recurrence Nothing 1000 standing)

obligationOccurrencesObservation ::
  ObservationInput -> V1State -> Either Text Value
obligationOccurrencesObservation input state = do
  (recurrence, period) <- case observationArguments input of
    [recurrenceValue, periodValue] -> (,)
      <$> decodeArgument "ObligationOccurrences" recurrenceValue
      <*> (Just <$> decodeArgument "ObligationOccurrences" periodValue)
    [recurrenceValue] -> (,)
      <$> decodeArgument "ObligationOccurrences" recurrenceValue
      <*> pure Nothing
    _ -> Left "ObligationOccurrences expects a recurrence and optional period"
  standing <- standingStateFromKernel state
  let occurrences = Standing.obligationOccurrencesFor recurrence period standing
      domain = Execution.executionStateDomain
        (Coordination.coordinationStateExecution
          (Standing.standingStateCoordination standing))
  items <- mapM (\occurrence -> do
      projection <- mapDomainError (standingBrickProjection domain
        (Standing.obligationOccurrenceBrick occurrence))
      pure (projection `mergeValueFields`
        [ "period_key" .= Standing.obligationOccurrencePeriodKey occurrence
        ])) occurrences
  pure (object ["items" .= items])

obligationHistoryObservation :: ObservationInput -> V1State -> Either Text Value
obligationHistoryObservation input state = do
  recurrence <- exactlyOneAsArgument "ObligationHistory" input
  standing <- standingStateFromKernel state
  let occurrences = Standing.obligationOccurrencesFor recurrence Nothing standing
  pure (object
    [ "period_keys" .= map Standing.obligationOccurrencePeriodKey occurrences
    , "items" .= occurrences
    ])

priorityPathObservation :: ObservationInput -> V1State -> Either Text Value
priorityPathObservation input state = do
  brick <- exactlyOneAsArgument "PriorityPath" input
  standing <- standingStateFromKernel state
  let priority = Execution.executionStatePriority
        (Coordination.coordinationStateExecution
          (Standing.standingStateCoordination standing))
  item <- mapPriorityError (Priority.priorityViewItem priority brick)
  pure (object
    [ "scope" .= Priority.priorityViewItemScope item
    , "sibling_index" .= Priority.priorityViewItemSiblingIndex item
    , "tree_path" .= Priority.priorityViewItemTreePath item
    ])

standingBrickProjection :: Domain.DomainState -> BrickId -> Either DomainError Value
standingBrickProjection domain identifier = do
  projection <- Domain.brickProjection domain identifier
  pure $ case projection of
    Object fields -> case KeyMap.lookup "parent" fields of
      Just parent@(String _) -> Object (KeyMap.insert "parent"
        (object ["id" .= parent]) fields)
      _ -> projection
    _ -> projection

mergeValueFields :: Value -> [AesonTypes.Pair] -> Value
mergeValueFields value pairs = case (value, object pairs) of
  (Object original, Object extra) -> Object (KeyMap.union extra original)
  _ -> value

mapStandingError :: Either Standing.StandingError value -> Either Text value
mapStandingError = either (Left . Text.pack . show) Right

------------------------------------------------------------
-- Coordination, inherited dates, and explicit places
------------------------------------------------------------

coordinationStateFromKernel :: V1State -> Either Text Coordination.CoordinationState
coordinationStateFromKernel state = case kernelValue "v1.coordination" state of
  Nothing -> Right Coordination.emptyCoordinationState
  Just value -> case fromJSON value of
    Success coordination -> do
      mapCoordinationError (Coordination.validateCoordinationState coordination)
      Right coordination
    Error problem -> Left ("stored coordination state is malformed: "
      <> Text.pack problem)

persistCoordination ::
  OperationInput -> Text -> Coordination.CoordinationState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistCoordination input suffix coordination resultValue state = do
  accepted <- appendForFixture input suffix
    [ProposeValueStored "v1.coordination" (toJSON coordination)] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

setCoordinationDeadlineOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
setCoordinationDeadlineOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  value <- requiredAs "value" arguments
  coordination <- coordinationStateFromKernel state
  next <- mapCoordinationError
    (Coordination.setCoordinationDeadline brick value coordination)
  persistCoordination input "deadline" next (object ["brick" .= brick]) state

moveCoordinationSubtreeOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
moveCoordinationSubtreeOperation input state = do
  arguments <- requireArgumentsObject input
  root <- requiredAs "root" arguments
  newParent <- requiredAs "new_parent" arguments
  now <- operationTime input
  coordination <- coordinationStateFromKernel state
  let evidence = fromMaybe (actionIdFor input)
        (ambientText (ambientRandomEvidence (operationAmbient input)))
  (insertion, next) <- mapCoordinationError
    (Coordination.moveCoordinationSubtree root (Just newParent) evidence now coordination)
  persistCoordination input "subtree-move" next (object
    ["priority_insertion" .= Priority.priorityInsertionId insertion]) state

advanceCoordinationTimeOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
advanceCoordinationTimeOperation input state = do
  arguments <- requireArgumentsObject input
  at <- requiredAs "at" arguments
  coordination <- coordinationStateFromKernel state
  (created, next) <- mapCoordinationError
    (Coordination.advanceCoordinationTime at coordination)
  let fixtureChild = kernelValue "v1.fixture.inherited_date_child" state
      childDeadlineNotice = fixtureChild >>= \childValue -> case fromJSON childValue of
        Error _ -> Nothing
        Success child -> Coordination.dateNoticeId <$> find (\notice ->
          Coordination.dateNoticeBrick notice == child
          && Coordination.dateNoticeKind notice == Coordination.DeadlineApproaching)
          created
      common = ["date_notices" .= map Coordination.dateNoticeId created]
      resultFields = case childDeadlineNotice of
        Nothing -> common
        Just notice -> ("deadline_notice_for_copy" .= notice) : common
  persistCoordination input "advance-time" next (object resultFields) state

twoProjectsWithChildFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
twoProjectsWithChildFixture input state = do
  arguments <- requireArgumentsObject input
  firstTitle <- requiredText "first_parent" arguments
  secondTitle <- requiredText "second_parent" arguments
  childTitle <- requiredText "child" arguments
  now <- operationTime input
  firstCanonical <- mapDomainError (mkCanonicalText firstTitle Nothing Human)
  secondCanonical <- mapDomainError (mkCanonicalText secondTitle Nothing Human)
  childCanonical <- mapDomainError (mkCanonicalText childTitle Nothing Human)
  siblingCanonical <- mapDomainError (mkCanonicalText "Existing launch sibling" Nothing Human)
  targetCanonical <- mapDomainError (mkCanonicalText "Existing maintenance child" Nothing Human)
  (firstParent, _, first) <- mapCoordinationError
    (Coordination.createCoordinationBrick
      (Domain.ordinaryBrickDraft firstCanonical Domain.projectV1 now)
      "fixture:first-parent" now Coordination.emptyCoordinationState)
  (secondParent, _, second) <- mapCoordinationError
    (Coordination.createCoordinationBrick
      (Domain.ordinaryBrickDraft secondCanonical Domain.projectV1 now)
      "fixture:second-parent" now first)
  (child, _, third) <- mapCoordinationError
    (Coordination.createCoordinationBrick
      ((Domain.ordinaryBrickDraft childCanonical Domain.standardV1 now)
        {Domain.brickDraftParent = Just (brickId firstParent)})
      "fixture:child" now second)
  (oldSibling, _, fourth) <- mapCoordinationError
    (Coordination.createCoordinationBrick
      ((Domain.ordinaryBrickDraft siblingCanonical Domain.standardV1 now)
        {Domain.brickDraftParent = Just (brickId firstParent)})
      "fixture:old-sibling" now third)
  (_, _, fifth) <- mapCoordinationError
    (Coordination.createCoordinationBrick
      ((Domain.ordinaryBrickDraft targetCanonical Domain.standardV1 now)
        {Domain.brickDraftParent = Just (brickId secondParent)})
      "fixture:target-sibling" now fourth)
  firstScope <- exactlyOnePriorityScope (Just (brickId firstParent))
    (Execution.executionStatePriority (Coordination.coordinationStateExecution fifth))
  secondScope <- exactlyOnePriorityScope (Just (brickId secondParent))
    (Execution.executionStatePriority (Coordination.coordinationStateExecution fifth))
  (_, _, withEvidence) <- mapPriorityError (Priority.recordPriorityJudgment
    (Priority.priorityScopeId firstScope) (brickId child) (brickId oldSibling)
    Human (Just "fixture old-scope evidence") now
    (Execution.executionStatePriority (Coordination.coordinationStateExecution fifth)))
  let execution = (Coordination.coordinationStateExecution fifth)
        {Execution.executionStatePriority = withEvidence}
      coordination = fifth {Coordination.coordinationStateExecution = execution}
  mapCoordinationError (Coordination.validateCoordinationState coordination)
  accepted <- appendForFixture input "inherited-dates"
    [ ProposeValueStored "v1.coordination" (toJSON coordination)
    , ProposeValueStored "v1.fixture.inherited_date_child" (toJSON (brickId child))
    ] state
  pure OperationResult
    { operationResultValue = object
        [ "first_parent" .= brickId firstParent
        , "second_parent" .= brickId secondParent
        , "child" .= brickId child
        , "first_scope" .= Priority.priorityScopeId firstScope
        , "second_scope" .= Priority.priorityScopeId secondScope
        ]
    , operationResultState = appendResultState accepted
    }

exactlyOnePriorityScope ::
  Maybe BrickId -> Priority.PriorityState -> Either Text Priority.PriorityScope
exactlyOnePriorityScope parent priority = case filter
    ((== parent) . Priority.priorityScopeParent)
    (Map.elems (Priority.priorityStateScopes priority)) of
  [scope] -> Right scope
  _ -> Left "expected exactly one priority scope for parent"

dateNoticeObservation :: ObservationInput -> V1State -> Either Text Value
dateNoticeObservation input state = do
  identifier <- exactlyOneAsArgument "DateNotice" input
  coordination <- coordinationStateFromKernel state
  maybe (Left "unknown DateNotice") (Right . toJSON)
    (Map.lookup identifier (Coordination.coordinationStateDateNotices coordination))

activeDateNoticesObservation :: ObservationInput -> V1State -> Either Text Value
activeDateNoticesObservation input state = do
  (brick, kind) <- case observationArguments input of
    [brickValue, kindValue] -> (,)
      <$> decodeArgument "ActiveDateNotices" brickValue
      <*> decodeArgument "ActiveDateNotices" kindValue
    _ -> Left "ActiveDateNotices expects a Brick and NoticeKind"
  coordination <- coordinationStateFromKernel state
  pure (object ["items" .= Coordination.activeDateNotices brick kind coordination])

placeEvaluationObservation :: ObservationInput -> V1State -> Either Text Value
placeEvaluationObservation input state = do
  brick <- exactlyOneAsArgument "PlaceEvaluation" input
  now <- case ambientClock (observationAmbient input) of
    Nothing -> Right domainFixtureTime
    Just value -> case fromJSON value of
      Success timestamp -> Right timestamp
      Error problem -> Left ("observation clock is malformed: " <> Text.pack problem)
  coordination <- coordinationStateFromKernel state
  toJSON <$> mapCoordinationError
    (Coordination.evaluatePlaceConditions now brick coordination)

mapCoordinationError ::
  Either Coordination.CoordinationError value -> Either Text value
mapCoordinationError = either (Left . Text.pack . show) Right

------------------------------------------------------------
-- Strict human priority operations and observations
------------------------------------------------------------

priorityStateFromKernel :: V1State -> Either Text Priority.PriorityState
priorityStateFromKernel state = case kernelValue "v1.priority" state of
  Nothing -> case kernelValue "v1.coordination" state of
    Nothing -> Right Priority.emptyPriorityState
    Just _ -> Execution.executionStatePriority . Coordination.coordinationStateExecution
      <$> coordinationStateFromKernel state
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

persistPriorityAndJudgment ::
  OperationInput -> Priority.PriorityState -> Judgment.JudgmentState -> Value ->
  V1State -> Either Text (OperationResult V1State)
persistPriorityAndJudgment input priority judgment resultValue state = do
  accepted <- appendForFixture input "priority-and-judgment"
    [ ProposeValueStored "v1.priority" (toJSON priority)
    , ProposeValueStored "v1.judgment" (toJSON judgment)
    ] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

behaviorSupportsEffort :: Text -> Either Text Bool
behaviorSupportsEffort identifier = do
  behavior <- maybe (Left ("unknown Brick behavior: " <> identifier)) Right
    (find ((== identifier) . behaviorId) (behaviorVersions initialDefinitionCatalog))
  pure (behaviorEffort behavior == Applicable)

createRootPriorityOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
createRootPriorityOperation input state = do
  arguments <- requireArgumentsObject input
  title <- requiredText "title" arguments
  _ <- requiredAs "title_authority" arguments :: Either Text Authority
  behavior <- requiredText "behavior" arguments
  effortApplicable <- behaviorSupportsEffort behavior
  now <- operationTime input
  priority <- priorityStateForOperation input state
  judgment <- judgmentStateFromKernel state
  let randomEvidence = fromMaybe (actionIdFor input)
        (ambientText (ambientRandomEvidence (operationAmbient input)))
  (brick, insertion, next) <- mapPriorityError
    (Priority.createPriorityRoot title randomEvidence now priority)
  nextJudgment <- mapJudgmentError (Judgment.registerJudgmentBrick
    (Priority.priorityBrickId brick) Nothing Active effortApplicable judgment)
  persistPriorityAndJudgment input next nextJudgment (object
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
  effortApplicable <- behaviorSupportsEffort behavior
  now <- operationTime input
  priority <- priorityStateForOperation input state
  judgment <- judgmentStateFromKernel state
  let randomEvidence = fromMaybe (actionIdFor input)
        (ambientText (ambientRandomEvidence (operationAmbient input)))
  (brick, insertion, next) <- mapPriorityError
    (Priority.createPriorityChild parent title randomEvidence now priority)
  nextJudgment <- mapJudgmentError (Judgment.registerJudgmentBrick
    (Priority.priorityBrickId brick) (Just parent) Active effortApplicable judgment)
  persistPriorityAndJudgment input next nextJudgment (object
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
  left <- requiredAs "left" arguments
  right <- requiredAs "right" arguments
  purpose <- requiredAs "purpose" arguments
  now <- operationTime input
  case axis of
    Priority.PriorityAxis -> do
      scope <- requiredAs "scope" arguments
      let reason = fromMaybe "provocative validation of retained priority evidence"
            (optionalText "reason" arguments)
      priority <- priorityStateForOperation input state
      (probe, next) <- mapPriorityError
        (Priority.openPriorityProbe scope left right purpose reason now priority)
      persistPriority input next (toJSON (Priority.judgmentProbeId probe)) state
    Priority.ImpactAxis -> do
      let reason = fromMaybe "provocative validation of retained impact evidence"
            (optionalText "reason" arguments)
      judgment <- judgmentStateFromKernel state
      (probe, next) <- mapJudgmentError
        (Judgment.openImpactProbe left right purpose reason now judgment)
      persistJudgment input next (toJSON (Priority.judgmentProbeId probe)) state
    Priority.EffortAxis -> do
      let reason = fromMaybe "provocative validation of retained effort evidence"
            (optionalText "reason" arguments)
      judgment <- judgmentStateFromKernel state
      (probe, next) <- mapJudgmentError
        (Judgment.openEffortProbe left right purpose reason now judgment)
      persistJudgment input next (toJSON (Priority.judgmentProbeId probe)) state

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
  judgment <- judgmentStateFromKernel state
  nextJudgment <- foldM (\current brick -> mapJudgmentError
      (Judgment.registerJudgmentBrick (Priority.priorityBrickId brick)
        (Priority.priorityBrickParent brick) (Priority.priorityBrickStatus brick)
        True current)) judgment (Map.elems (Priority.priorityStateBricks next))
  let resultFields =
        (Key.fromText "scope", toJSON Priority.priorityRootScopeId)
        : [ (Key.fromText title, toJSON identifier)
          | (title, identifier) <- Map.toList byTitle
          ]
  persistPriorityAndJudgment input next nextJudgment
    (Object (KeyMap.fromList resultFields)) state

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
  priority <- priorityStateFromKernel state
  case observationArguments input of
    [brickValue] -> do
      brick <- decodeArgument "PriorityEvidenceFor" brickValue
      _ <- maybe (Left "unknown priority Brick") Right
        (Map.lookup brick (Priority.priorityStateBricks priority))
      pure (object
        [ "contains_equality" .= False
        , "history" .= judgmentsFor brick priority
        ])
    [brickValue, scopeValue] -> do
      brick <- decodeArgument "PriorityEvidenceFor" brickValue
      scope <- decodeArgument "PriorityEvidenceFor" scopeValue
      _ <- maybe (Left "unknown priority Brick") Right
        (Map.lookup brick (Priority.priorityStateBricks priority))
      let evidence = [judgment | judgment <- judgmentsFor brick priority,
            Priority.priorityJudgmentScope judgment == scope]
      pure (object
        [ "applicable" .= map Priority.priorityJudgmentApplicable evidence
        , "history" .= evidence
        ])
    _ -> Left "PriorityEvidenceFor expects a Brick and optional scope"
  where
    judgmentsFor brick priority =
      [ judgment
      | judgment <- Map.elems (Priority.priorityStateJudgments priority)
      , brick `elem`
          [ Priority.priorityJudgmentMoreImportant judgment
          , Priority.priorityJudgmentLessImportant judgment
          ]
      ]

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
  judgment <- judgmentStateFromKernel state
  if Map.member identifier (Priority.priorityStateProbes priority)
    then mapPriorityError (Priority.probeProjection priority identifier)
    else mapJudgmentError (Judgment.judgmentProbeProjection judgment identifier)

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
-- Impact, effort, and judgment evidence
------------------------------------------------------------

judgmentStateFromKernel :: V1State -> Either Text Judgment.JudgmentState
judgmentStateFromKernel state = case kernelValue "v1.judgment" state of
  Nothing -> Right Judgment.emptyJudgmentState
  Just value -> case fromJSON value of
    Success judgment -> Right judgment
    Error problem -> Left ("stored judgment state is malformed: " <> Text.pack problem)

persistJudgment ::
  OperationInput -> Judgment.JudgmentState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistJudgment input judgment resultValue state = do
  accepted <- appendForFixture input "judgment"
    [ProposeValueStored "v1.judgment" (toJSON judgment)] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

classifyImpactOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
classifyImpactOperation input state = do
  arguments <- requireArgumentsObject input
  root <- requiredAs "root" arguments
  impact <- requiredAs "impact" arguments
  maturity <- requiredAs "maturity" arguments
  authority <- requiredAs "authority" arguments
  reason <- optionalAs "reason" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  (assessment, probe, next) <- mapJudgmentError
    (Judgment.classifyImpact root impact maturity authority reason now judgment)
  persistJudgment input next (object
    [ "assessment" .= Judgment.impactAssessmentId assessment
    , "probe" .= fmap Priority.judgmentProbeId probe
    ]) state

compareImpactOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
compareImpactOperation input state = do
  arguments <- requireArgumentsObject input
  left <- requiredAs "left" arguments
  right <- requiredAs "right" arguments
  result <- requiredAs "result" arguments
  authority <- requiredAs "authority" arguments
  reason <- optionalAs "reason" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  (comparison, probe, next) <- mapJudgmentError
    (Judgment.compareImpact left right result authority reason now judgment)
  persistJudgment input next (object
    [ "comparison" .= Judgment.impactComparisonId comparison
    , "probe" .= fmap Priority.judgmentProbeId probe
    ]) state

reviseImpactMaturityOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reviseImpactMaturityOperation input state = do
  arguments <- requireArgumentsObject input
  root <- requiredAs "root" arguments
  maturity <- requiredAs "maturity" arguments
  authority <- requiredAs "authority" arguments
  reason <- requiredText "reason" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  (assessment, probe, next) <- mapJudgmentError
    (Judgment.reviseImpactMaturity root maturity authority reason now judgment)
  persistJudgment input next (object
    [ "assessment" .= Judgment.impactAssessmentId assessment
    , "probe" .= fmap Priority.judgmentProbeId probe
    ]) state

classifyEffortOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
classifyEffortOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  authority <- requiredAs "authority" arguments
  provisional <- requiredAs "provisional" arguments
  reason <- optionalAs "reason" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  band <- requiredEffortBand "band" arguments judgment
  (assessment, probe, next) <- mapJudgmentError
    (Judgment.classifyEffort brick band authority provisional reason now judgment)
  persistJudgment input next (object
    [ "assessment" .= Judgment.effortAssessmentId assessment
    , "probe" .= fmap Priority.judgmentProbeId probe
    ]) state

compareEffortOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
compareEffortOperation input state = do
  arguments <- requireArgumentsObject input
  subject <- requiredAs "subject" arguments
  exemplar <- requiredAs "exemplar" arguments
  result <- requiredAs "result" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  (comparison, probe, next) <- mapJudgmentError
    (Judgment.compareEffort subject exemplar result authority now judgment)
  persistJudgment input next (object
    [ "comparison" .= Judgment.effortComparisonEvidenceId comparison
    , "probe" .= fmap Priority.judgmentProbeId probe
    ]) state

deferJudgmentProbeOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
deferJudgmentProbeOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "probe" arguments
  judgment <- judgmentStateFromKernel state
  if Map.member identifier (Judgment.judgmentStateProbes judgment)
    then do
      (probe, next) <- mapJudgmentError
        (Judgment.deferAssessmentProbe identifier judgment)
      persistJudgment input next (toJSON (Priority.judgmentProbeId probe)) state
    else do
      priority <- priorityStateForOperation input state
      (probe, next) <- mapPriorityError (Priority.deferJudgmentProbe identifier priority)
      persistPriority input next (toJSON (Priority.judgmentProbeId probe)) state

reopenJudgmentProbeOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
reopenJudgmentProbeOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "probe" arguments
  judgment <- judgmentStateFromKernel state
  if Map.member identifier (Judgment.judgmentStateProbes judgment)
    then do
      (probe, next) <- mapJudgmentError
        (Judgment.reopenAssessmentProbe identifier judgment)
      persistJudgment input next (toJSON (Priority.judgmentProbeId probe)) state
    else do
      priority <- priorityStateForOperation input state
      (probe, next) <- mapPriorityError (Priority.reopenJudgmentProbe identifier priority)
      persistPriority input next (toJSON (Priority.judgmentProbeId probe)) state

confirmDecompositionCoverageOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
confirmDecompositionCoverageOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  judgment <- judgmentStateFromKernel state
  (updated, next) <- mapJudgmentError
    (Judgment.confirmDecompositionCoverage brick judgment)
  persistJudgment input next (object
    [ "brick" .= Judgment.judgmentBrickId updated
    , "decomposition_coverage" .= Judgment.judgmentBrickDecompositionCoverage updated
    ]) state

confirmScopeRevisionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
confirmScopeRevisionOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  reason <- requiredText "reason" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  (revision, nextJudgment) <- mapJudgmentError
    (Judgment.confirmScopeRevision brick reason authority now judgment)
  priority <- priorityStateFromKernel state
  nextPriority <- if Map.member brick (Priority.priorityStateBricks priority)
    then Just <$> mapPriorityError
      (Priority.invalidatePriorityJudgmentsFor brick priority)
    else pure Nothing
  let events = [ProposeValueStored "v1.judgment" (toJSON nextJudgment)]
        <> maybe [] (\value -> [ProposeValueStored "v1.priority" (toJSON value)])
          nextPriority
  accepted <- appendForFixture input "scope-revision" events state
  pure OperationResult
    { operationResultValue = object
        [ "scope_revision" .= Judgment.scopeRevisionId revision
        , "brick" .= brick
        ]
    , operationResultState = appendResultState accepted
    }

recordProgressEvidenceOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
recordProgressEvidenceOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  kind <- requiredAs "kind" arguments
  amount <- requiredAs "amount" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  (evidence, next) <- mapJudgmentError
    (Judgment.recordProgressEvidence brick kind amount now judgment)
  persistJudgment input next (object
    ["progress_evidence" .= Judgment.progressEvidenceId evidence]) state

setJudgmentBrickStatusOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
setJudgmentBrickStatusOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  status <- requiredAs "status" arguments
  now <- operationTime input
  judgment <- judgmentStateFromKernel state
  (updated, nextJudgment) <- mapJudgmentError
    (Judgment.setJudgmentBrickStatus brick status now judgment)
  priority <- priorityStateFromKernel state
  nextPriority <- if Map.member brick (Priority.priorityStateBricks priority)
    then Just . snd <$> mapPriorityError
      (Priority.setPriorityBrickStatus brick status now priority)
    else pure Nothing
  let events = [ProposeValueStored "v1.judgment" (toJSON nextJudgment)]
        <> maybe [] (\value -> [ProposeValueStored "v1.priority" (toJSON value)])
          nextPriority
  accepted <- appendForFixture input "terminal-judgment-brick" events state
  pure OperationResult
    { operationResultValue = object
        ["brick" .= Judgment.judgmentBrickId updated, "status" .= status]
    , operationResultState = appendResultState accepted
    }

requiredEffortBand ::
  Text -> Object -> Judgment.JudgmentState -> Either Text Judgment.EffortBand
requiredEffortBand field values judgment = do
  value <- requiredValue field values
  case fromJSON value of
    Success band -> Right band
    Error _ -> case value of
      String identifier -> mapJudgmentError
        (Judgment.effortBandById Judgment.initialEffortProfile identifier judgment)
      _ -> Left ("invalid effort band field: " <> field)

judgmentEntitiesFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
judgmentEntitiesFixture input state = do
  judgment <- judgmentStateFromKernel state
  let rootA = BrickId "judgment:fixture:00000001"
      rootB = BrickId "judgment:fixture:00000002"
      child = BrickId "judgment:fixture:00000003"
      disabled = BrickId "judgment:fixture:00000004"
  first <- mapJudgmentError
    (Judgment.registerJudgmentBrick rootA Nothing Active True judgment)
  second <- mapJudgmentError
    (Judgment.registerJudgmentBrick rootB Nothing Active True first)
  third <- mapJudgmentError
    (Judgment.registerJudgmentBrick child (Just rootA) Active True second)
  next <- mapJudgmentError
    (Judgment.registerJudgmentBrick disabled Nothing Active False third)
  easy <- mapJudgmentError
    (Judgment.effortBandById Judgment.initialEffortProfile "EASY" next)
  hard <- mapJudgmentError
    (Judgment.effortBandById Judgment.initialEffortProfile "HARD" next)
  persistJudgment input next (object
    [ "root_a" .= rootA
    , "root_b" .= rootB
    , "child" .= child
    , "effort_disabled" .= disabled
    , "easy" .= easy
    , "hard" .= hard
    , "effort_profile" .= Judgment.initialEffortProfile
    ]) state

judgmentStateObservation :: ObservationInput -> V1State -> Either Text Value
judgmentStateObservation input state = do
  requireNoArguments "JudgmentState" input
  toJSON <$> judgmentStateFromKernel state

impactAssessmentObservation :: ObservationInput -> V1State -> Either Text Value
impactAssessmentObservation input state = do
  identifier <- exactlyOneAsArgument "ImpactAssessment" input
  judgment <- judgmentStateFromKernel state
  mapJudgmentError (Judgment.impactAssessmentProjection judgment identifier)

impactComparisonObservation :: ObservationInput -> V1State -> Either Text Value
impactComparisonObservation input state = do
  identifier <- exactlyOneAsArgument "ImpactComparison" input
  judgment <- judgmentStateFromKernel state
  mapJudgmentError (Judgment.impactComparisonProjection judgment identifier)

impactEvidenceObservation :: ObservationInput -> V1State -> Either Text Value
impactEvidenceObservation input state = do
  root <- exactlyOneAsArgument "ImpactEvidence" input
  judgment <- judgmentStateFromKernel state
  toJSON <$> mapJudgmentError (Judgment.impactEvidence judgment root)

effortAssessmentObservation :: ObservationInput -> V1State -> Either Text Value
effortAssessmentObservation input state = do
  identifier <- exactlyOneAsArgument "EffortAssessment" input
  judgment <- judgmentStateFromKernel state
  mapJudgmentError (Judgment.effortAssessmentProjection judgment identifier)

effortComparisonObservation :: ObservationInput -> V1State -> Either Text Value
effortComparisonObservation input state = do
  identifier <- exactlyOneAsArgument "EffortComparisonEvidence" input
  judgment <- judgmentStateFromKernel state
  mapJudgmentError (Judgment.effortComparisonProjection judgment identifier)

effortEvidenceObservation :: ObservationInput -> V1State -> Either Text Value
effortEvidenceObservation input state = do
  brick <- exactlyOneAsArgument "EffortEvidence" input
  judgment <- judgmentStateFromKernel state
  toJSON <$> mapJudgmentError (Judgment.effortEvidence judgment brick)

remainingEffortObservation :: ObservationInput -> V1State -> Either Text Value
remainingEffortObservation input state = do
  judgment <- judgmentStateFromKernel state
  (brick, profile) <- case observationArguments input of
    [brickValue] -> (, Judgment.initialEffortProfile)
      <$> decodeArgument "RemainingEffort" brickValue
    [brickValue, profileValue] -> (,)
      <$> decodeArgument "RemainingEffort" brickValue
      <*> decodeArgument "RemainingEffort" profileValue
    _ -> Left "RemainingEffort expects a Brick and optional effort profile"
  toJSON <$> mapJudgmentError
    (Judgment.remainingEffortProjection judgment brick profile)

judgmentProjectionObservation :: ObservationInput -> V1State -> Either Text Value
judgmentProjectionObservation input state = do
  brick <- exactlyOneAsArgument "JudgmentProjection" input
  judgment <- judgmentStateFromKernel state
  mapJudgmentError (Judgment.judgmentProjection judgment brick)

mapJudgmentError :: Either Judgment.JudgmentError value -> Either Text value
mapJudgmentError = either (Left . Text.pack . show) Right

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
  createRegisteredStandingFixture input state titleText standardV1

-- | Expand one immutable template version into the coordinated canonical
-- state.  The template reference is data (id@version), not executable code.
templateBrickFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
templateBrickFixture input state = do
  arguments <- requireArgumentsObject input
  templateReference <- requiredText "template" arguments
  titleText <- requiredText "title" arguments
  template <- maybe (Left ("unknown template version: " <> templateReference)) Right
    (find (\candidate -> templateId candidate <> "@"
      <> Text.pack (show (templateVersion candidate)) == templateReference)
      (templateVersions initialDefinitionCatalog))
  createRegisteredStandingFixture input state titleText (templateBehavior template)

createRegisteredStandingFixture ::
  OperationInput -> V1State -> Text -> Domain.BrickBehavior ->
  Either Text (OperationResult V1State)
createRegisteredStandingFixture input state titleText behavior = do
  now <- operationTime input
  title <- mapDomainError (mkCanonicalText titleText Nothing Human)
  standing <- standingStateFromKernel state
  (brick, _, nextStanding) <- mapStandingError (Standing.createStandingBrick
    (ordinaryBrickDraft title behavior now) ("fixture:" <> titleText) now standing)
  material <- materialStateFromKernel state
  let nextMaterial = registerMaterialBrick (brickId brick) Active material
  accepted <- appendForFixture input "standing-brick"
    [ ProposeValueStored "v1.standing" (toJSON nextStanding)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination nextStanding))
    , ProposeValueStored "v1.material" (toJSON nextMaterial)
    ] state
  pure OperationResult
    { operationResultValue = object ["brick" .= brickId brick]
    , operationResultState = appendResultState accepted
    }

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
  judgment <- judgmentStateFromKernel state
  pure (object ["kinds" .= (openSourceReconciliationKinds material brick
    <> Priority.priorityProposalKinds priority brick
    <> Judgment.judgmentProposalKinds judgment brick)])

materialBrickSummaryObservation :: ObservationInput -> V1State -> Either Text Value
materialBrickSummaryObservation input state = do
  brick <- exactlyOneAsArgument "BrickSummary" input
  case kernelValue "v1.coordination" state of
    Just _ -> do
      coordination <- coordinationStateFromKernel state
      mapDomainError (standingBrickProjection
        (Execution.executionStateDomain
          (Coordination.coordinationStateExecution coordination)) brick)
    Nothing -> do
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

lastMay :: [value] -> Maybe value
lastMay [] = Nothing
lastMay [value] = Just value
lastMay (_ : rest) = lastMay rest

operationTime :: OperationInput -> Either Text UTCTime
operationTime input = case ambientClock (operationAmbient input) of
  Nothing -> Right domainFixtureTime
  Just value -> case fromJSON value of
    Success timestamp -> Right timestamp
    Error problem -> Left ("scenario clock is not a timestamp: " <> Text.pack problem)

mapMaterialError :: Either MaterialError value -> Either Text value
mapMaterialError = either (Left . Text.pack . show) Right

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
import Data.Maybe (fromMaybe, isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import qualified LittleAnt.V1.Capture as Capture
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
import qualified LittleAnt.V1.Interaction as Interaction
import qualified LittleAnt.V1.Judgment as Judgment
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..),
   EventBatch (..), KernelError, KernelState, OpaqueId (..), ProposedEvent (..),
   ReplayResult (..), appendSemanticAction, canonicalStateHash,
   emptyKernelState, kernelArtifact, kernelEntity, kernelEventBatches,
   kernelRevision, kernelValue, putKernelArtifact, replayAll)
import LittleAnt.V1.Material
  (MaterialError, MaterialState (..), Raw (..), RawId,
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
import qualified LittleAnt.V1.Material as Material
import LittleAnt.V1.PlanCatalog (v1PlanProbes)
import qualified LittleAnt.V1.Priority as Priority
import qualified LittleAnt.V1.Selection as Selection
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
      , ("CreateParty", createPartyOperation)
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
      , ("AdvanceSelection", advanceSelectionOperation)
      , ("BuildForecast", buildForecastOperation)
      , ("RequestNext", requestNextOperation)
      , ("SkipServedBrick", skipServedBrickOperation)
      , ("ResolveProposal", resolveSelectionProposalOperation)
      , ("DismissProposal", dismissSelectionProposalOperation)
      , ("SimulateReplaySafeDraws", simulateReplaySafeDrawsOperation)
      , ("RepeatSimulation", repeatSimulationOperation)
      , ("BeginCapture", beginCaptureOperation)
      , ("SelectDuplicateSuspicion", selectDuplicateSuspicionOperation)
      , ("ConfirmDuplicateDecision", confirmDuplicateDecisionOperation)
      , ("ConfirmSeparateCapture", confirmSeparateCaptureOperation)
      , ("CancelCapture", cancelCaptureOperation)
      , ("OpenInteraction", openInteractionOperation)
      , ("RequestInteractionHelp", requestInteractionHelpOperation)
      , ("SubmitInteractionAction", submitInteractionActionOperation)
      , ("RebaseInteraction", rebaseInteractionOperation)
      , ("CompleteInteraction", completeInteractionOperation)
      , ("AbandonInteraction", abandonInteractionOperation)
      , ("SaveSurfaceCheckpoint", saveSurfaceCheckpointOperation)
      , ("ValidatePoweredUpAdapter", validatePoweredUpAdapterOperation)
      , ("UseDumbMode", useDumbModeOperation)
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
      , ("Forecast", forecastObservation)
      , ("ForecastItem", forecastItemObservation)
      , ("ForecastReasons", forecastReasonsObservation)
      , ("SelectionCooldown", selectionCooldownObservation)
      , ("SimulationMetrics", simulationMetricsObservation)
      , ("CanonicalEntities", canonicalEntitiesObservation)
      , ("PriorityScope", selectionPriorityScopeObservation)
      , ("CaptureIntent", captureIntentObservation)
      , ("DuplicateSuspicions", duplicateSuspicionsObservation)
      , ("DuplicateDecision", duplicateDecisionObservation)
      , ("PriorityMemberships", priorityMembershipsObservation)
      , ("ListEntrySummary", listEntrySummaryObservation)
      , ("OpenEntries", openEntriesObservation)
      , ("OperationalProjection", captureOperationalProjectionObservation)
      , ("RawLinksToEntry", rawLinksToEntryObservation)
      , ("RawLinksToBrick", rawLinksToBrickObservation)
      , ("Interaction", interactionObservation)
      , ("InteractionEnvelope", interactionEnvelopeObservation)
      , ("SurfaceCheckpoint", surfaceCheckpointObservation)
      , ("ReplRuntime", replRuntimeObservation)
      , ("ProcessInvocationTrace", processInvocationTraceObservation)
      , ("StatusSummary", statusSummaryObservation)
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
      , ("eligible_priority_run", eligiblePriorityRunFixture)
      , ("two_eligible_root_bricks", twoEligibleRootBricksFixture)
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
-- Revision-scoped interactions and powered-up harness state
------------------------------------------------------------

interactionArtifactKey :: Text
interactionArtifactKey = "v1.interaction"

interactionStateFromKernel :: V1State -> Either Text Interaction.InteractionState
interactionStateFromKernel state = case kernelArtifact interactionArtifactKey state of
  Nothing -> Right Interaction.emptyInteractionState
  Just value -> case fromJSON value of
    Success interaction -> do
      mapInteractionError (Interaction.validateInteractionState interaction)
      Right interaction
    Error problem -> Left ("stored interaction state is malformed: "
      <> Text.pack problem)

persistInteractionArtifact ::
  Interaction.InteractionState -> V1State -> Either Text V1State
persistInteractionArtifact interaction state = mapKernelError
  (putKernelArtifact interactionArtifactKey (toJSON interaction) state)

openInteractionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
openInteractionOperation input state = do
  arguments <- requireArgumentsObject input
  kind <- requiredText "kind" arguments
  subjectBrick <- optionalAs "subject_brick" arguments
  subjectRaw <- optionalAs "subject_raw" arguments
  randomEvidence <- optionalAs "random_evidence" arguments
  now <- operationTime input
  interaction <- interactionStateFromKernel state
  (session, nextInteraction) <- mapInteractionError (Interaction.openInteraction
    kind subjectBrick subjectRaw randomEvidence now
    (unDomainRevision (kernelRevision state)) interaction)
  next <- persistInteractionArtifact nextInteraction state
  pure OperationResult
    { operationResultValue = object
        [ "interaction" .= Interaction.interactionSessionId session
        , "domain_revision" .= Interaction.interactionSessionDomainRevision session
        , "interaction_revision" .=
            Interaction.interactionSessionInteractionRevision session
        , "prompt_key" .= Interaction.interactionSessionPromptKey session
        ]
    , operationResultState = next
    }

requestInteractionHelpOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
requestInteractionHelpOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "interaction" arguments
  interaction <- interactionStateFromKernel state
  envelope <- mapInteractionError
    (Interaction.requestInteractionHelp identifier interaction)
  pure OperationResult
    { operationResultValue = toJSON envelope
    , operationResultState = state
    }

submitInteractionActionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
submitInteractionActionOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "interaction" arguments
  displayedDomain <- requiredInteger "displayed_domain_revision" arguments
  displayedInteraction <- requiredInteger
    "displayed_interaction_revision" arguments
  actionId <- requiredText "action_id" arguments
  now <- operationTime input
  interaction <- interactionStateFromKernel state
  let currentDomain = unDomainRevision (kernelRevision state)
  decision <- mapInteractionError (Interaction.classifyInteractionSubmission
    identifier displayedDomain displayedInteraction currentDomain actionId now
    interaction)
  case decision of
    Interaction.StaleSubmission response staleInteraction -> do
      next <- persistInteractionArtifact staleInteraction state
      pure OperationResult
        { operationResultValue = toJSON response
        , operationResultState = next
        }
    Interaction.CurrentSubmission action -> do
      accepted <- appendForFixture input "interaction-answer"
        [ProposeValueStored (Text.intercalate ":"
            [ "v1.interaction.answer"
            , Interaction.unInteractionId identifier
            , Text.pack (show displayedInteraction)
            ])
          (object
            [ "interaction" .= identifier
            , "action_id" .= Interaction.interactionActionId action
            , "prompt_revision" .= displayedInteraction
            ])]
        state
      (_, response, nextInteraction) <- mapInteractionError
        (Interaction.acceptCurrentInteractionAction identifier displayedDomain
          displayedInteraction currentDomain actionId now interaction)
      next <- persistInteractionArtifact nextInteraction
        (appendResultState accepted)
      pure OperationResult
        { operationResultValue = toJSON response
        , operationResultState = next
        }

rebaseInteractionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
rebaseInteractionOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "interaction" arguments
  now <- operationTime input
  interaction <- interactionStateFromKernel state
  (session, nextInteraction) <- mapInteractionError
    (Interaction.rebaseInteraction identifier
      (unDomainRevision (kernelRevision state)) now interaction)
  next <- persistInteractionArtifact nextInteraction state
  pure OperationResult
    { operationResultValue = toJSON session
    , operationResultState = next
    }

completeInteractionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
completeInteractionOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "interaction" arguments
  now <- operationTime input
  interaction <- interactionStateFromKernel state
  (session, nextInteraction) <- mapInteractionError
    (Interaction.completeInteraction identifier now interaction)
  next <- persistInteractionArtifact nextInteraction state
  pure OperationResult
    { operationResultValue = toJSON session
    , operationResultState = next
    }

abandonInteractionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
abandonInteractionOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "interaction" arguments
  now <- operationTime input
  interaction <- interactionStateFromKernel state
  (session, nextInteraction) <- mapInteractionError
    (Interaction.abandonInteraction identifier now interaction)
  next <- persistInteractionArtifact nextInteraction state
  pure OperationResult
    { operationResultValue = toJSON session
    , operationResultState = next
    }

saveSurfaceCheckpointOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
saveSurfaceCheckpointOperation input state = do
  arguments <- requireArgumentsObject input
  draft <- Interaction.SurfaceCheckpointDraft
    <$> requiredText "surface_id" arguments
    <*> optionalAs "interaction_id" arguments
    <*> requiredInteger "displayed_domain_revision" arguments
    <*> optionalAs "displayed_interaction_revision" arguments
    <*> requiredText "screen" arguments
    <*> optionalAs "selected_item" arguments
    <*> optionalAs "text_buffer" arguments
    <*> optionalAs "cursor_offset" arguments
    <*> requiredAs "transcript" arguments
    <*> optionalAs "last_response" arguments
    <*> optionalAs "last_status" arguments
    <*> optionalAs "last_projection" arguments
    <*> optionalAs "history_query" arguments
    <*> optionalAs "last_history_page" arguments
    <*> optionalAs "last_history_brief" arguments
  now <- operationTime input
  interaction <- interactionStateFromKernel state
  (checkpoint, nextInteraction) <- if Map.member
      (Interaction.checkpointDraftSurfaceId draft)
      (Interaction.interactionStateCheckpoints interaction)
    then mapInteractionError
      (Interaction.saveExistingSurfaceCheckpoint draft now interaction)
    else mapInteractionError
      (Interaction.saveFirstSurfaceCheckpoint draft now interaction)
  next <- persistInteractionArtifact nextInteraction state
  pure OperationResult
    { operationResultValue = toJSON checkpoint
    , operationResultState = next
    }

validatePoweredUpAdapterOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
validatePoweredUpAdapterOperation input state = do
  arguments <- requireArgumentsObject input
  path <- requiredText "path" arguments
  transport <- requiredText "transport" arguments
  responseText <- requiredText "probe_response" arguments
  interaction <- interactionStateFromKernel state
  let (_, response, validated) = Interaction.validatePoweredUpAdapter
        path transport responseText interaction
      currentRevision = unDomainRevision (kernelRevision state)
      adjustedResponse = response
        {Interaction.operationalResponseDomainRevision = currentRevision}
      nextInteraction = validated
        {Interaction.interactionStateLatestResponse = Just adjustedResponse}
  next <- persistInteractionArtifact nextInteraction state
  pure OperationResult
    { operationResultValue = toJSON adjustedResponse
    , operationResultState = next
    }

useDumbModeOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
useDumbModeOperation _ state = do
  interaction <- interactionStateFromKernel state
  nextInteraction <- mapInteractionError (Interaction.useDumbMode interaction)
  next <- persistInteractionArtifact nextInteraction state
  pure OperationResult
    { operationResultValue = toJSON (Interaction.interactionStateReplRuntime
        nextInteraction)
    , operationResultState = next
    }

interactionObservation :: ObservationInput -> V1State -> Either Text Value
interactionObservation input state = do
  identifier <- exactlyOneAsArgument "Interaction" input
  interaction <- interactionStateFromKernel state
  maybe (Left "unknown InteractionSession") (Right . toJSON)
    (Map.lookup identifier (Interaction.interactionStateSessions interaction))

interactionEnvelopeObservation ::
  ObservationInput -> V1State -> Either Text Value
interactionEnvelopeObservation input state = do
  identifier <- exactlyOneAsArgument "InteractionEnvelope" input
  interaction <- interactionStateFromKernel state
  toJSON <$> mapInteractionError
    (Interaction.currentInteraction identifier interaction)

surfaceCheckpointObservation ::
  ObservationInput -> V1State -> Either Text Value
surfaceCheckpointObservation input state = do
  surface <- exactlyOneTextArgument "SurfaceCheckpoint" input
  interaction <- interactionStateFromKernel state
  maybe (Left "unknown SurfaceCheckpoint") (Right . toJSON)
    (Map.lookup surface (Interaction.interactionStateCheckpoints interaction))

replRuntimeObservation :: ObservationInput -> V1State -> Either Text Value
replRuntimeObservation _ state = toJSON . Interaction.interactionStateReplRuntime
  <$> interactionStateFromKernel state

processInvocationTraceObservation ::
  ObservationInput -> V1State -> Either Text Value
processInvocationTraceObservation input state = do
  path <- exactlyOneTextArgument "ProcessInvocationTrace" input
  interaction <- interactionStateFromKernel state
  maybe (Left "unknown powered-up process invocation") (Right . toJSON)
    (Map.lookup path (Interaction.interactionStateProcessTraces interaction))

statusSummaryObservation :: ObservationInput -> V1State -> Either Text Value
statusSummaryObservation _ state = do
  interaction <- interactionStateFromKernel state
  pure (toJSON (Interaction.statusSummary Nothing 0 0 0 interaction))

------------------------------------------------------------
-- Routed capture and deterministic duplicate suspicion
------------------------------------------------------------

captureStateFromKernel :: V1State -> Either Text Capture.CaptureState
captureStateFromKernel state = case kernelValue "v1.capture" state of
  Nothing -> Right Capture.emptyCaptureState
  Just value -> case fromJSON value of
    Success captureState -> Right captureState
    Error problem -> Left ("stored capture state is malformed: "
      <> Text.pack problem)

captureContextFromKernel :: V1State -> Either Text Capture.CaptureContext
captureContextFromKernel state = Capture.CaptureContext
  <$> standingStateFromKernel state
  <*> materialStateFromKernel state

persistCaptureState ::
  OperationInput -> Text -> Capture.CaptureState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistCaptureState input suffix captureState resultValue state = do
  accepted <- appendForFixture input suffix
    [ProposeValueStored "v1.capture" (toJSON captureState)] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

persistCaptureContext ::
  OperationInput -> Text -> Capture.CaptureState -> Capture.CaptureContext ->
  Value -> V1State -> Either Text (OperationResult V1State)
persistCaptureContext input suffix captureState context resultValue state = do
  let standing = Capture.captureContextStanding context
      material = Capture.captureContextMaterial context
  accepted <- appendForFixture input suffix
    [ ProposeValueStored "v1.capture" (toJSON captureState)
    , ProposeValueStored "v1.standing" (toJSON standing)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination standing))
    , ProposeValueStored "v1.material" (toJSON material)
    ] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

createPartyOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
createPartyOperation input state = do
  arguments <- requireArgumentsObject input
  label <- requiredText "label" arguments
  partyType <- requiredAs "party_type" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (party, next) <- mapStandingError
    (Standing.createStandingParty label partyType now standing)
  accepted <- appendForFixture input "party"
    [ ProposeValueStored "v1.standing" (toJSON next)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination next))
    ] state
  pure OperationResult
    { operationResultValue = toJSON (Domain.partyId party)
    , operationResultState = appendResultState accepted
    }

beginCaptureOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
beginCaptureOperation input state = do
  arguments <- requireArgumentsObject input
  original <- requiredText "original_text" arguments
  canonical <- optionalAs "canonical_english" arguments
  authority <- optionalAs "normalization_authority" arguments
  route <- optionalAs "proposed_route" arguments
  parent <- optionalAs "proposed_parent" arguments
  owner <- optionalAs "proposed_owner" arguments
  behavior <- optionalDefinition "proposed_behavior" arguments resolveBehaviorReference
  template <- optionalDefinition "proposed_template" arguments resolveTemplateReference
  now <- operationTime input
  context <- captureContextFromKernel state
  captureState <- captureStateFromKernel state
  let draft = Capture.CaptureDraft original canonical authority route parent owner
        behavior template
  (intent, _suspicions, next) <- mapCaptureError
    (Capture.beginCapture draft now context captureState)
  persistCaptureState input "capture-begin" next
    (toJSON (Capture.captureIntentId intent)) state

selectDuplicateSuspicionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
selectDuplicateSuspicionOperation input state = do
  arguments <- requireArgumentsObject input
  captureId <- requiredAs "capture" arguments
  brick <- optionalAs "target_brick" arguments
  entry <- optionalAs "target_entry" arguments
  raw <- optionalAs "target_raw" arguments
  captureState <- captureStateFromKernel state
  suspicion <- mapCaptureError (Capture.selectDuplicateSuspicion
    captureId brick entry raw captureState)
  pure OperationResult
    { operationResultValue = toJSON (Capture.duplicateSuspicionId suspicion)
    , operationResultState = state
    }

confirmDuplicateDecisionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
confirmDuplicateDecisionOperation input state = do
  arguments <- requireArgumentsObject input
  captureId <- requiredAs "capture" arguments
  suspicion <- requiredAs "suspicion" arguments
  decision <- requiredAs "decision" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  context <- captureContextFromKernel state
  captureState <- captureStateFromKernel state
  (result, nextContext, nextState) <- mapCaptureError
    (Capture.confirmDuplicateDecision captureId suspicion decision authority now
      context captureState)
  persistCaptureContext input "capture-duplicate" nextState nextContext
    (captureDecisionProtocolValue result) state

confirmSeparateCaptureOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
confirmSeparateCaptureOperation input state = do
  arguments <- requireArgumentsObject input
  captureId <- requiredAs "capture" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  context <- captureContextFromKernel state
  captureState <- captureStateFromKernel state
  (result, nextContext, nextState) <- mapCaptureError
    (Capture.confirmSeparateCapture captureId authority now context captureState)
  persistCaptureContext input "capture-separate" nextState nextContext
    (captureDecisionProtocolValue result) state

cancelCaptureOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
cancelCaptureOperation input state = do
  arguments <- requireArgumentsObject input
  captureId <- requiredAs "capture" arguments
  context <- captureContextFromKernel state
  captureState <- captureStateFromKernel state
  (cancelled, next) <- mapCaptureError
    (Capture.cancelCapture captureId context captureState)
  persistCaptureState input "capture-cancel" next (toJSON cancelled) state

captureDecisionProtocolValue :: Capture.CaptureDecisionResult -> Value
captureDecisionProtocolValue result = object
  [ "capture" .= Capture.captureDecisionResultCapture result
  , "decision" .= Capture.captureDecisionResultDecision result
  , "created_raw" .= Capture.captureDecisionResultRaw result
  , "created_brick" .= Capture.captureDecisionResultBrick result
  , "created_entry" .= Capture.captureDecisionResultEntry result
  , "priority_insertion" .= Capture.captureDecisionResultInsertion result
  , "enriched_target" .= Capture.captureDecisionResultEnrichedTarget result
  ]

optionalDefinition ::
  Text -> Object -> (Text -> Either Text value) -> Either Text (Maybe value)
optionalDefinition field values resolve = case KeyMap.lookup (Key.fromText field) values of
  Nothing -> Right Nothing
  Just Null -> Right Nothing
  Just (String reference) -> Just <$> resolve reference
  Just _ -> Left ("field must be a definition reference: " <> field)

resolveBehaviorReference :: Text -> Either Text Domain.BrickBehavior
resolveBehaviorReference reference = maybe
  (Left ("unknown behavior version: " <> reference)) Right
  (find (matchesDefinition reference Domain.behaviorId Domain.behaviorVersion)
    (Domain.behaviorVersions Domain.initialDefinitionCatalog))

resolveTemplateReference :: Text -> Either Text Domain.BrickTemplate
resolveTemplateReference reference = maybe
  (Left ("unknown template version: " <> reference)) Right
  (find (matchesDefinition reference Domain.templateId Domain.templateVersion)
    (Domain.templateVersions Domain.initialDefinitionCatalog))

matchesDefinition ::
  Text -> (definition -> Text) -> (definition -> Integer) -> definition -> Bool
matchesDefinition reference identifier version definition =
  reference == identifier definition
  || reference == identifier definition <> "@" <> Text.pack (show (version definition))

mapCaptureError :: Either Capture.CaptureError value -> Either Text value
mapCaptureError = either (Left . Text.pack . show) Right

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
-- Rebuildable proposals, forecast, next, and served-skip pressure
------------------------------------------------------------

selectionStateFromKernel :: V1State -> Either Text Selection.SelectionState
selectionStateFromKernel state = case kernelValue "v1.selection" state of
  Nothing -> Right Selection.emptySelectionState
  Just value -> case fromJSON value of
    Success selection -> Right selection
    Error problem -> Left ("stored selection state is malformed: "
      <> Text.pack problem)

selectionStateForAmbient :: AmbientInputs -> V1State -> Either Text Selection.SelectionState
selectionStateForAmbient ambient state = do
  selection <- selectionStateFromKernel state
  let threshold = case ambientParameterOverrides ambient of
        Just (Object fields) -> case KeyMap.lookup "practice_review_threshold" fields of
          Just encoded -> case fromJSON encoded of
            Success value | value > (0 :: Integer) -> value
            _ -> Selection.selectionStatePracticeReviewThreshold selection
          Nothing -> Selection.selectionStatePracticeReviewThreshold selection
        _ -> Selection.selectionStatePracticeReviewThreshold selection
  pure selection {Selection.selectionStatePracticeReviewThreshold = threshold}

selectionContextFromKernel :: V1State -> Either Text Selection.SelectionContext
selectionContextFromKernel state = Selection.SelectionContext
  <$> standingStateFromKernel state
  <*> materialStateFromKernel state

persistSelection ::
  OperationInput -> Text -> Selection.SelectionState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistSelection input suffix selection resultValue state = do
  accepted <- appendForFixture input suffix
    [ProposeValueStored "v1.selection" (toJSON selection)] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

persistSelectionAndStanding ::
  OperationInput -> Text -> Selection.SelectionState -> Standing.StandingState ->
  Value -> V1State -> Either Text (OperationResult V1State)
persistSelectionAndStanding input suffix selection standing resultValue state = do
  accepted <- appendForFixture input suffix
    [ ProposeValueStored "v1.selection" (toJSON selection)
    , ProposeValueStored "v1.standing" (toJSON standing)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination standing))
    ] state
  pure OperationResult
    { operationResultValue = resultValue
    , operationResultState = appendResultState accepted
    }

buildForecastOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
buildForecastOperation input state = do
  arguments <- requireArgumentsObject input
  at <- requiredAs "at" arguments
  domainRevision <- requiredInteger "domain_revision" arguments
  context <- selectionContextFromKernel state
  selection <- selectionStateForAmbient (operationAmbient input) state
  forecast <- mapSelectionError
    (Selection.buildForecast at domainRevision context selection)
  -- Forecast construction is deliberately read-only: no kernel append, random
  -- cursor, cache, or selection entity is written here.
  pure OperationResult
    { operationResultValue = forecastProtocolValue forecast
    , operationResultState = state
    }

requestNextOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
requestNextOperation input state = do
  arguments <- requireArgumentsObject input
  at <- requiredAs "at" arguments
  domainRevision <- requiredInteger "domain_revision" arguments
  randomEvidence <- requiredText "random_evidence" arguments
  context <- selectionContextFromKernel state
  selection <- selectionStateForAmbient (operationAmbient input) state
  (draw, next) <- mapSelectionError
    (Selection.requestNext at domainRevision randomEvidence context selection)
  persistSelection input "next" next (toJSON draw) state

advanceSelectionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
advanceSelectionOperation input state = do
  arguments <- requireArgumentsObject input
  at <- requiredAs "at" arguments
  context <- selectionContextFromKernel state
  selection <- selectionStateForAmbient (operationAmbient input) state
  (created, openedValidation, nextContext, next) <- mapSelectionError
    (Selection.advanceSelectionWithValidation at context selection)
  persistSelectionAndStanding input "advance-selection" next
    (Selection.selectionContextStanding nextContext) (object
      [ "proposals" .= map Selection.proposalId created
      , "validation_probe" .= fmap Priority.judgmentProbeId openedValidation
      ]) state

skipServedBrickOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
skipServedBrickOperation input state = do
  arguments <- requireArgumentsObject input
  brick <- requiredAs "brick" arguments
  reason <- requiredAs "reason" arguments
  rawText <- optionalAs "raw_text" arguments
  at <- case KeyMap.lookup "at" arguments of
    Nothing -> operationTime input
    Just value -> decodeArgument "SkipServedBrick.at" value
  context <- selectionContextFromKernel state
  selection <- selectionStateForAmbient (operationAmbient input) state
  (served, cooldown, next) <- mapSelectionError
    (Selection.recordServedSkip brick reason rawText at context selection)
  persistSelection input "served-skip" next (object
    [ "served_skip" .= Selection.servedSkipId served
    , "cooldown" .= Selection.selectionCooldownId cooldown
    ]) state

resolveSelectionProposalOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
resolveSelectionProposalOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "proposal" arguments
  selection <- selectionStateForAmbient (operationAmbient input) state
  (updated, next) <- mapSelectionError
    (Selection.resolveProposal identifier selection)
  persistSelection input "proposal-resolve" next (toJSON updated) state

dismissSelectionProposalOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
dismissSelectionProposalOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "proposal" arguments
  selection <- selectionStateForAmbient (operationAmbient input) state
  original <- maybe (Left "unknown Proposal") Right
    (Map.lookup identifier (Selection.selectionStateProposals selection))
  (updated, next) <- mapSelectionError
    (Selection.dismissProposal identifier selection)
  case Selection.proposalJudgmentProbe original of
    Nothing -> persistSelection input "proposal-dismiss" next (toJSON updated) state
    Just probe -> do
      standing <- standingStateFromKernel state
      deferred <- deferSelectionProbe probe standing
      persistSelectionAndStanding input "proposal-dismiss-probe" next deferred
        (toJSON updated) state

-- Dismissing a guided judgment opportunity defers its canonical probe rather
-- than inventing a separate resolution path.
deferSelectionProbe ::
  Priority.JudgmentProbeId -> Standing.StandingState ->
  Either Text Standing.StandingState
deferSelectionProbe identifier standing = do
  let coordination = Standing.standingStateCoordination standing
      execution = Coordination.coordinationStateExecution coordination
      priority = Execution.executionStatePriority execution
      judgment = Execution.executionStateJudgment execution
  execution' <- if Map.member identifier (Priority.priorityStateProbes priority)
    then do
      (_, next) <- mapPriorityError (Priority.deferJudgmentProbe identifier priority)
      Right execution {Execution.executionStatePriority = next}
    else if Map.member identifier (Judgment.judgmentStateProbes judgment)
      then do
        (_, next) <- mapJudgmentError
          (Judgment.deferAssessmentProbe identifier judgment)
        Right execution {Execution.executionStateJudgment = next}
      else Left "Proposal references an unknown JudgmentProbe"
  let coordination' = coordination
        {Coordination.coordinationStateExecution = execution'}
      standing' = standing {Standing.standingStateCoordination = coordination'}
  mapStandingError (Standing.validateStandingState standing')
  pure standing'

simulateReplaySafeDrawsOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
simulateReplaySafeDrawsOperation input state = do
  arguments <- requireArgumentsObject input
  forecastValue <- requiredValue "forecast" arguments
  suppliedForecast <- decodeArgument
    "SimulateReplaySafeDraws.forecast" forecastValue
  samples <- requiredInteger "samples" arguments
  seed <- requiredText "seed" arguments
  context <- selectionContextFromKernel state
  selection <- selectionStateForAmbient (operationAmbient input) state
  rebuiltForecast <- mapSelectionError (Selection.buildForecast
    (Selection.forecastViewGeneratedAt suppliedForecast)
    (Selection.forecastViewDomainRevision suppliedForecast) context selection)
  when (suppliedForecast /= rebuiltForecast)
    (Left "simulation forecast does not match its canonical pinned inputs")
  metrics <- mapSelectionError
    (Selection.simulateReplaySafeDraws seed samples rebuiltForecast)
  accepted <- appendForFixture input "forecast-simulation"
    [ProposeValueStored "v1.forecast-simulation" (object
      [ "domain_revision" .= Selection.forecastViewDomainRevision rebuiltForecast
      , "generated_at" .= Selection.forecastViewGeneratedAt rebuiltForecast
      , "samples" .= samples
      , "seed" .= seed
      ])] state
  pure OperationResult
    { operationResultValue = toJSON metrics
    , operationResultState = appendResultState accepted
    }

repeatSimulationOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
repeatSimulationOperation input state = do
  descriptor <- maybe (Left "no replay-safe simulation has been recorded") Right
    (kernelValue "v1.forecast-simulation" state)
  fields <- asObject "forecast simulation descriptor" descriptor
  domainRevision <- requiredInteger "domain_revision" fields
  generatedAt <- requiredAs "generated_at" fields
  samples <- requiredInteger "samples" fields
  seed <- requiredText "seed" fields
  context <- selectionContextFromKernel state
  selection <- selectionStateForAmbient (operationAmbient input) state
  forecast <- mapSelectionError
    (Selection.buildForecast generatedAt domainRevision context selection)
  metrics <- mapSelectionError
    (Selection.simulateReplaySafeDraws seed samples forecast)
  pure OperationResult
    { operationResultValue = toJSON metrics
    , operationResultState = state
    }

forecastObservation :: ObservationInput -> V1State -> Either Text Value
forecastObservation input _ = do
  forecast <- exactlyOneAsArgument "Forecast" input
  pure (forecastProtocolValue (forecast :: Selection.ForecastView))

forecastItemObservation :: ObservationInput -> V1State -> Either Text Value
forecastItemObservation input _ = case observationArguments input of
  [forecastValue, brickValue] -> do
    forecast <- decodeArgument "ForecastItem" forecastValue
    brick <- decodeArgument "ForecastItem" brickValue
    maybe (Left "Brick is absent from forecast") (Right . toJSON)
      (Selection.forecastItemForBrick brick forecast)
  _ -> Left "ForecastItem expects a forecast and Brick"

forecastReasonsObservation :: ObservationInput -> V1State -> Either Text Value
forecastReasonsObservation input state = do
  brick <- exactlyOneAsArgument "ForecastReasons" input
  at <- observationTime input
  context <- selectionContextFromKernel state
  selection <- selectionStateForAmbient (observationAmbient input) state
  forecast <- mapSelectionError (Selection.buildForecast at
    (unDomainRevision (kernelRevision state)) context selection)
  item <- maybe (Left "Brick is not currently forecast-eligible") Right
    (Selection.forecastItemForBrick brick forecast)
  pure (object ["items" .= Selection.forecastItemReasons item])

selectionCooldownObservation :: ObservationInput -> V1State -> Either Text Value
selectionCooldownObservation input state = do
  brick <- exactlyOneAsArgument "SelectionCooldown" input
  selection <- selectionStateFromKernel state
  maybe (Left "Brick has no SelectionCooldown") (Right . toJSON)
    (Map.lookup brick (Selection.selectionStateCooldowns selection))

simulationMetricsObservation :: ObservationInput -> V1State -> Either Text Value
simulationMetricsObservation input _ = do
  metrics <- exactlyOneAsArgument "SimulationMetrics" input
  pure (toJSON (metrics :: Selection.SimulationMetrics))

canonicalEntitiesObservation :: ObservationInput -> V1State -> Either Text Value
canonicalEntitiesObservation _ state = Right (object
  ["stored_forecast_orders" .= canonicalForecastOrderPaths state])

-- Forecasts are projections.  Search the current canonical values and
-- entities structurally so this observation reports accidental persistence
-- instead of asserting the desired answer.  Event envelopes are history, not
-- current canonical entities, and are deliberately outside this projection.
canonicalForecastOrderPaths :: V1State -> [Text]
canonicalForecastOrderPaths state = case toJSON state of
  Object root -> concat
    [ maybe [] (forecastOrderPaths ("$." <> name))
        (KeyMap.lookup (Key.fromText name) root)
    | name <- ["values", "entities"]
    ]
  _ -> []

forecastOrderPaths :: Text -> Value -> [Text]
forecastOrderPaths path value = case value of
  Object fields
    | isForecastViewObject fields -> [path]
    | otherwise -> concat
        [ forecastOrderPaths (path <> "." <> Key.toText key) child
        | (key, child) <- KeyMap.toList fields
        ]
  Array values -> concat
    [ forecastOrderPaths
        (path <> "[" <> Text.pack (show index) <> "]") child
    | (index, child) <- zip [(0 :: Int) ..] (toList values)
    ]
  _ -> []

isForecastViewObject :: Object -> Bool
isForecastViewObject fields =
  KeyMap.member "domain_revision" fields
  && KeyMap.member "generated_at" fields
  && case KeyMap.lookup "items" fields of
      Just (Array _) -> True
      _ -> False

selectionPriorityScopeObservation :: ObservationInput -> V1State -> Either Text Value
selectionPriorityScopeObservation input state = do
  identifier <- exactlyOneAsArgument "PriorityScope" input
  context <- selectionContextFromKernel state
  maybe (Left "unknown PriorityScope") (Right . toJSON)
    (Map.lookup identifier (Priority.priorityStateScopes
      (Execution.executionStatePriority
        (Coordination.coordinationStateExecution
          (Standing.standingStateCoordination
            (Selection.selectionContextStanding context))))))

captureIntentObservation :: ObservationInput -> V1State -> Either Text Value
captureIntentObservation input state = do
  identifier <- exactlyOneAsArgument "CaptureIntent" input
  captureState <- captureStateFromKernel state
  maybe (Left "unknown CaptureIntent") (Right . toJSON)
    (Map.lookup identifier (Capture.captureStateIntents captureState))

duplicateSuspicionsObservation :: ObservationInput -> V1State -> Either Text Value
duplicateSuspicionsObservation input state = do
  captureId <- exactlyOneAsArgument "DuplicateSuspicions" input
  captureState <- captureStateFromKernel state
  let items = sortOn Capture.duplicateSuspicionId
        [ suspicion
        | suspicion <- Map.elems (Capture.captureStateSuspicions captureState)
        , Capture.duplicateSuspicionCapture suspicion == captureId
        ]
  pure (object ["items" .= items])

duplicateDecisionObservation :: ObservationInput -> V1State -> Either Text Value
duplicateDecisionObservation input state = do
  identifier <- exactlyOneAsArgument "DuplicateDecision" input
  captureState <- captureStateFromKernel state
  maybe (Left "unknown DuplicateDecision") (Right . toJSON)
    (Map.lookup identifier (Capture.captureStateDecisions captureState))

priorityMembershipsObservation :: ObservationInput -> V1State -> Either Text Value
priorityMembershipsObservation input state = do
  brick <- exactlyOneAsArgument "PriorityMemberships" input
  standing <- standingStateFromKernel state
  let priority = Execution.executionStatePriority
        (Coordination.coordinationStateExecution
          (Standing.standingStateCoordination standing))
      memberships =
        [ Priority.priorityScopeId scope
        | scope <- Map.elems (Priority.priorityStateScopes priority)
        , brick `elem` Priority.priorityScopeMembers scope
        ]
  pure (object ["count" .= length memberships, "scopes" .= memberships])

listEntrySummaryObservation :: ObservationInput -> V1State -> Either Text Value
listEntrySummaryObservation input state = do
  identifier <- exactlyOneAsArgument "ListEntrySummary" input
  domain <- captureDomainFromKernel state
  entry <- maybe (Left "unknown ListEntry") Right
    (Map.lookup identifier (Domain.domainListEntries domain))
  pure (mergeValueFields (Domain.listEntryProjection entry)
    ["owner" .= object ["id" .= Domain.listEntryOwner entry]])

openEntriesObservation :: ObservationInput -> V1State -> Either Text Value
openEntriesObservation input state = do
  owner <- exactlyOneAsArgument "OpenEntries" input
  domain <- captureDomainFromKernel state
  let items = map Domain.listEntryProjection (sortOn Domain.listEntryId
        [ entry
        | entry <- Map.elems (Domain.domainListEntries domain)
        , Domain.listEntryOwner entry == owner
        , Domain.listEntryStatus entry == Domain.EntryOpen
        ])
  pure (object ["items" .= items])

captureOperationalProjectionObservation ::
  ObservationInput -> V1State -> Either Text Value
captureOperationalProjectionObservation input state = do
  owner <- exactlyOneAsArgument "OperationalProjection" input
  domain <- captureDomainFromKernel state
  brick <- maybe (Left "unknown operational Brick") Right
    (Map.lookup owner (Domain.domainBricks domain))
  let openLabels =
        [ Domain.listEntryLabel entry
        | entry <- sortOn Domain.listEntryId
            (Map.elems (Domain.domainListEntries domain))
        , Domain.listEntryOwner entry == owner
        , Domain.listEntryStatus entry == Domain.EntryOpen
        ]
      rendered = if Domain.behaviorRendersAllOpenEntries
          (Domain.brickBehavior brick)
        then openLabels else []
  pure (object
    [ "id" .= owner
    , "title" .= Domain.brickTitle brick
    , "open_entries" .= rendered
    ])

rawLinksToEntryObservation :: ObservationInput -> V1State -> Either Text Value
rawLinksToEntryObservation input state = do
  entry <- exactlyOneAsArgument "RawLinksToEntry" input
  material <- materialStateFromKernel state
  let links = sortOn Material.rawLinkId
        [ link | link <- Map.elems (materialLinks material)
        , Material.rawLinkOwnerEntry link == Just entry
        ]
  items <- mapM (captureRawLinkProjection material) links
  pure (object ["items" .= items])

rawLinksToBrickObservation :: ObservationInput -> V1State -> Either Text Value
rawLinksToBrickObservation input state = do
  brick <- exactlyOneAsArgument "RawLinksToBrick" input
  material <- materialStateFromKernel state
  let links = sortOn Material.rawLinkId
        [ link | link <- Map.elems (materialLinks material)
        , Material.rawLinkOwnerBrick link == Just brick
        ]
  pure (object
    [ "roles" .= map Material.rawLinkRole links
    , "items" .= map Material.rawLinkId links
    ])

captureRawLinkProjection :: MaterialState -> Material.RawLink -> Either Text Value
captureRawLinkProjection material link = do
  raw <- maybe (Left "RawLink references an unknown Raw") Right
    (Map.lookup (Material.rawLinkRaw link) (materialRaws material))
  pure (object
    [ "id" .= Material.rawLinkId link
    , "raw" .= Material.rawLinkRaw link
    , "role" .= Material.rawLinkRole link
    , "original_text" .= rawOriginalText raw
    ])

captureDomainFromKernel :: V1State -> Either Text Domain.DomainState
captureDomainFromKernel state =
  Execution.executionStateDomain
    . Coordination.coordinationStateExecution
    . Standing.standingStateCoordination
    <$> standingStateFromKernel state

forecastProtocolValue :: Selection.ForecastView -> Value
forecastProtocolValue forecast = mergeValueFields (toJSON forecast)
  [ "items" .= map forecastItemProtocolValue (Selection.forecastViewItems forecast)
  , "ordinary_eligible_items" .= map forecastItemProtocolValue
      (filter (isJust . Selection.forecastItemBrick)
        (Selection.forecastViewItems forecast))
  ]

forecastItemProtocolValue :: Selection.ForecastItem -> Value
forecastItemProtocolValue item = mergeValueFields (toJSON item)
  ["nonzero_weight_has_nonempty_reasons" .=
    (Selection.forecastItemWeight item == 0
      || not (null (Selection.forecastItemReasons item)))]

observationTime :: ObservationInput -> Either Text UTCTime
observationTime input = case ambientClock (observationAmbient input) of
  Nothing -> Right domainFixtureTime
  Just value -> decodeArgument "observation clock" value

mapSelectionError :: Either Selection.SelectionError value -> Either Text value
mapSelectionError = either (Left . Text.pack . show) Right

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

eligiblePriorityRunFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
eligiblePriorityRunFixture input state = do
  arguments <- requireArgumentsObject input
  titleValues <- requiredArray "titles" arguments
  titles <- mapM (decodeArgument "eligible_priority_run title") titleValues
  phaseValues <- requiredArray "phases" arguments
  phases <- mapM (decodeArgument "eligible_priority_run phase") phaseValues
  pressureValues <- requiredArray "skip_pressure" arguments
  pressures <- mapM (decodeArgument "eligible_priority_run skip pressure")
    pressureValues
  unlessEqualLength "fixture phases" titles phases
  unlessEqualLength "fixture skip pressure" titles pressures
  selectionBrickFixture input state titles phases pressures

twoEligibleRootBricksFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
twoEligibleRootBricksFixture input state = do
  arguments <- requireArgumentsObject input
  titleValues <- requiredArray "titles" arguments
  titles <- mapM (decodeArgument "two_eligible_root_bricks title") titleValues
  selectionBrickFixture input state titles (replicate (length titles) Nothing)
    (replicate (length titles) 0)

selectionBrickFixture ::
  OperationInput -> V1State -> [Text] -> [Maybe Domain.BrickPhase] -> [Integer] ->
  Either Text (OperationResult V1State)
selectionBrickFixture input state titles phases pressures = do
  when (null titles) (Left "selection fixture requires at least one title")
  now <- operationTime input
  standing <- standingStateFromKernel state
  (createdReversed, nextStanding) <- foldM (createOne now) ([], standing)
    (zip titles phases)
  let created = reverse createdReversed
      coordination = Standing.standingStateCoordination nextStanding
      priority = Execution.executionStatePriority
        (Coordination.coordinationStateExecution coordination)
  scope <- maybe (Left "selection fixture root priority scope is absent") Right
    (Map.lookup Priority.priorityRootScopeId (Priority.priorityStateScopes priority))
  material <- materialStateFromKernel state
  let nextMaterial = foldr (\brick -> registerMaterialBrick
        (brickId brick) Active) material created
  selection <- selectionStateForAmbient (operationAmbient input) state
  let seeded = foldl (seedPressure now) selection (zip created pressures)
      context = Selection.SelectionContext nextStanding nextMaterial
  mapSelectionError (Selection.validateSelectionState context seeded)
  accepted <- appendForFixture input "selection-bricks"
    [ ProposeValueStored "v1.standing" (toJSON nextStanding)
    , ProposeValueStored "v1.coordination" (toJSON coordination)
    , ProposeValueStored "v1.material" (toJSON nextMaterial)
    , ProposeValueStored "v1.selection" (toJSON seeded)
    ] state
  let fields = ("scope", toJSON (Priority.priorityScopeId scope)) :
        [(Key.fromText title, toJSON (brickId brick)) |
          (title, brick) <- zip titles created]
  pure OperationResult
    { operationResultValue = Object (KeyMap.fromList fields)
    , operationResultState = appendResultState accepted
    }
  where
    createOne now (created, standing) (titleText, phase) = do
      title <- mapDomainError (mkCanonicalText titleText Nothing Human)
      let draft = (ordinaryBrickDraft title standardV1 now)
            { Domain.brickDraftPhase = phase
            , Domain.brickDraftPhaseAuthority = Human <$ phase
            }
      (brick, _, next) <- mapStandingError
        (Standing.createStandingBrick draft ("fixture:" <> titleText) now standing)
      pure (brick : created, next)
    seedPressure now selection (brick, count)
      | count <= 0 = selection
      | otherwise =
          let identifier = brickId brick
              cooldown = Selection.SelectionCooldown
                (Selection.SelectionCooldownId
                  ("la1:fixture-cooldown:" <> unBrickId identifier))
                identifier (addUTCTime (-1) now) count Selection.SkipOther
          in selection {Selection.selectionStateCooldowns = Map.insert identifier
              cooldown (Selection.selectionStateCooldowns selection)}

unlessEqualLength :: Text -> [left] -> [right] -> Either Text ()
unlessEqualLength label left right = when (length left /= length right)
  (Left (label <> " count differs from titles"))

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
operationalResponseObservation _ state = do
  interaction <- interactionStateFromKernel state
  case Interaction.interactionStateLatestResponse interaction of
    Just response -> Right (toJSON response)
    Nothing -> Right (object
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
    String identifier -> case kernelValue ("forecast:" <> identifier)
        (referenceSnapshotState snapshot) of
      Just captured -> Right captured
      Nothing -> do
        brick <- decodeArgument "forecast checkpoint Brick" (String identifier)
        context <- selectionContextFromKernel (referenceSnapshotState snapshot)
        selection <- selectionStateForAmbient (referenceInputAmbient input)
          (referenceSnapshotState snapshot)
        at <- case ambientClock (referenceInputAmbient input) of
          Nothing -> Right domainFixtureTime
          Just value -> decodeArgument "forecast checkpoint clock" value
        rebuilt <- mapSelectionError (Selection.buildForecast at
          (unDomainRevision (kernelRevision (referenceSnapshotState snapshot)))
          context selection)
        maybe (Left ("forecast is unavailable for: " <> identifier))
          (Right . toJSON)
          (Selection.forecastItemForBrick brick rebuilt)
    value -> Right value
  if Text.null path then Right forecast else selectJsonPath path forecast

findForecastCheckpoint ::
  Text -> Map Text (ReferenceSnapshot V1State) ->
  Either Text (ReferenceSnapshot V1State)
findForecastCheckpoint label checkpoints =
  case direct <|> normalized of
    Just checkpoint -> Right checkpoint
    Nothing -> case sortOn
        (kernelRevision . referenceSnapshotState) fuzzyMatches of
      [] -> Left ("unknown forecast checkpoint: " <> label)
      first : rest
        | "after-" `Text.isPrefixOf` label -> Right (lastOr first rest)
        | otherwise -> Right first
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
    lastOr fallback values = foldl (\_ value -> value) fallback values

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

mapInteractionError ::
  Either Interaction.InteractionError value -> Either Text value
mapInteractionError = either (Left . Text.pack . show) Right

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

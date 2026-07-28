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
import Control.Monad (foldM, unless, when)
import Data.Aeson
  (FromJSON, Object, Result (..), Value (..), fromJSON, object, toJSON, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import Data.Foldable (toList)
import Data.List (find, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
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
import qualified LittleAnt.V1.Integration as Integration
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
import LittleAnt.V1.PlanCatalog (v1PlanProbes, v1RuntimePlanProbes)
import qualified LittleAnt.V1.Planning as Planning
import qualified LittleAnt.V1.Priority as Priority
import qualified LittleAnt.V1.ReadModel as ReadModel
import qualified LittleAnt.V1.Selection as Selection
import qualified LittleAnt.V1.SourceImport as SourceImport
import qualified LittleAnt.V1.Standing as Standing

-- | Isolated v1 state.  Every protocol request obtains a new value through
-- 'registryInitialState'.
type V1State = KernelState

-- | Populated semantic registry shipped by @lant-v1-test-driver@.
contractRegistry :: ContractRegistry V1State
contractRegistry = (emptyContractRegistry emptyKernelState)
  { registryInitialState = const emptyKernelState
  , registryPlanProbes = v1PlanProbes
  , registryRuntimePlanProbes = v1RuntimePlanProbes
  , registryOperations = Map.fromList
      [ ("CanonicalEventStore.append", appendOperation)
      , ("CanonicalEventStore.replay", replayOperation)
      , ("ReplayFromEvents", replayOperation)
      , ("KernelAllocateEntity", allocateEntityOperation)
      , ("KernelRejectAction", rejectActionOperation)
      , ("KernelRemoveValue", removeValueOperation)
      , ("KernelSetValue", setValueOperation)
      , ("CreateParty", createPartyOperation)
      , ("RenameBrick", renameBrickOperation)
      , ("DescribeBrick", describeBrickOperation)
      , ("AnnotatePartyInBrickText", annotatePartyOperation)
      , ("AnnotateBrickInBrickText", annotateBrickOperation)
      , ("MarkAnnotationStale", markAnnotationStaleOperation)
      , ("HistoryQueryProtocol.query", historyQueryOperation)
      , ("HistoryQueryProtocol.brief", historyBriefOperation)
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
      , ("InstallPack", installPackOperation)
      , ("DisablePack", disablePackOperation)
      , ("EnablePack", enablePackOperation)
      , ("RevokePack", revokePackOperation)
      , ("RecordPackInvocation", recordPackInvocationOperation)
      , ("StoreCredential", storeCredentialOperation)
      , ("BindCredential", bindCredentialOperation)
      , ("LockCredentialBinding", lockCredentialBindingOperation)
      , ("UnlockCredentialBinding", unlockCredentialBindingOperation)
      , ("RevokeCredentialBinding", revokeCredentialBindingOperation)
      , ("CredentialBroker.authorize", credentialBrokerAuthorizeOperation)
      , ("HostHttp.request", hostHttpRequestOperation)
      , ("InspectPackRuntimeInput", inspectPackRuntimeInputOperation)
      , ("CreateImportProfile", createImportProfileOperation)
      , ("RetireImportProfile", retireImportProfileOperation)
      , ("PlanImport", planImportOperation)
      , ("StartImport", startImportOperation)
      , ("AcceptImportCandidate", acceptImportCandidateOperation)
      , ("ObserveExternalCompletion", observeExternalCompletionOperation)
      , ("FinishImportCapture", finishImportCaptureOperation)
      , ("VerifyImport", verifyImportOperation)
      , ("FailImport", failImportOperation)
      , ("CompleteSynchronization", completeSynchronizationOperation)
      , ("PlanEraseAfterImport", planEraseAfterImportOperation)
      , ("ApproveSourceEffect", approveSourceEffectOperation)
      , ("DeclineSourceEffect", declineSourceEffectOperation)
      , ("RetrySourceEffect", retrySourceEffectOperation)
      , ("RecordSourceEffectApplied", recordSourceEffectAppliedOperation)
      , ("RecordSourceEffectFailed", recordSourceEffectFailedOperation)
      , ("CutOverImport", cutOverImportOperation)
      , ("ProposeEmptyContainerDeletion", proposeEmptyContainerDeletionOperation)
      , ("ImportTaskJugglerActual", importTaskJugglerActualOperation)
      , ("OpenLocalWebUi", openLocalWebUiOperation)
      , ("CloseLocalWebUi", closeLocalWebUiOperation)
      ]
  , registryRuntimeOperations = Map.fromList
      [ ("PackRunner.execute", packRunnerExecuteOperation)
      , ("ProbePackSandbox", probePackSandboxOperation)
      , ("ExportTaskJuggler", exportTaskJugglerOperation)
      , ("RenderWebUi", renderWebUiOperation)
      , ("SubmitWebUiInput", submitWebUiInputOperation)
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
      , ("ReplaySideEffectTrace", replaySideEffectTraceObservation)
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
      , ("Proposal", proposalObservation)
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
      , ("HistoryPage", historyPageObservation)
      , ("HistoryBrief", historyBriefObservation)
      , ("TextAnnotation", textAnnotationObservation)
      , ("PackExecutionResult", packExecutionResultObservation)
      , ("HostHttpTrace", hostHttpTraceObservation)
      , ("ProviderBackoff", providerBackoffObservation)
      , ("PackInvocationInput", packInvocationInputObservation)
      , ("PackInvocationTrace", packInvocationTraceObservation)
      , ("ImportProfile", importProfileObservation)
      , ("ExternalRecord", externalRecordObservation)
      , ("ImportRun", importRunObservation)
      , ("SourceEffect", sourceEffectObservation)
      , ("SourceEffects", sourceEffectsObservation)
      , ("PlanningManifest", planningManifestObservation)
      , ("ExportedTaskJuggler", exportedTaskJugglerObservation)
      , ("ImportedActual", importedActualObservation)
      , ("WebUiSession", webUiSessionObservation)
      , ("WebUiTransitions", webUiTransitionsObservation)
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
      , ("created_and_described_brick", createdAndDescribedBrickFixture)
      , ("credential_binding", credentialBindingFixture)
      , ("verified_migration_from_existing_records", verifiedMigrationFixture)
      , ("estimated_project", estimatedProjectFixture)
      , ("live_status_summary", liveStatusSummaryFixture)
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
    , operationResultState = state
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
-- Sparse commands, semantic history, and typed annotations
------------------------------------------------------------

annotationStateFromKernel :: V1State -> Either Text ReadModel.AnnotationState
annotationStateFromKernel state = case kernelValue "v1.annotations" state of
  Nothing -> Right ReadModel.emptyAnnotationState
  Just value -> case fromJSON value of
    Success annotations -> do
      mapAnnotationError (ReadModel.validateAnnotationState annotations)
      Right annotations
    Error problem -> Left ("stored annotation state is malformed: "
      <> Text.pack problem)

currentDomainState :: V1State -> Either Text Domain.DomainState
currentDomainState state = Execution.executionStateDomain
  . Coordination.coordinationStateExecution
  . Standing.standingStateCoordination <$> standingStateFromKernel state

persistLatestOperationalResponse ::
  Interaction.OperationalResponse -> V1State -> Either Text V1State
persistLatestOperationalResponse response state = do
  interaction <- interactionStateFromKernel state
  persistInteractionArtifact interaction
    {Interaction.interactionStateLatestResponse = Just response} state

compactBrickReference :: Domain.Brick -> Interaction.CompactEntityReference
compactBrickReference brick = Interaction.CompactEntityReference
  { Interaction.compactEntityReferenceId = Domain.unBrickId (Domain.brickId brick)
  , Interaction.compactEntityReferenceTitle = Just (Domain.brickTitle brick)
  , Interaction.compactEntityReferenceRevision =
      Domain.unEntityRevision (Domain.brickRevision brick)
  , Interaction.compactEntityReferenceState = Just (case Domain.brickStatus brick of
      Domain.Active -> "active"
      Domain.Done -> "done"
      Domain.Dropped -> "dropped"
      Domain.Superseded -> "superseded")
  }

successfulResponse ::
  Text -> Text -> Maybe Interaction.CompactEntityReference -> [Text] ->
  [Text] -> Maybe Bool -> V1State -> Interaction.OperationalResponse
successfulResponse human resultKind entity changed warnings dryRun state =
  Interaction.OperationalResponse
    { Interaction.operationalResponseOk = True
    , Interaction.operationalResponseHuman = human
    , Interaction.operationalResponseResultKind = Just resultKind
    , Interaction.operationalResponseEntity = entity
    , Interaction.operationalResponseChanged = changed
    , Interaction.operationalResponseWarnings = warnings
    , Interaction.operationalResponseErrorCode = Nothing
    , Interaction.operationalResponseHint = Nothing
    , Interaction.operationalResponseDryRun = dryRun
    , Interaction.operationalResponseDomainRevision =
        unDomainRevision (kernelRevision state)
    }

historyMetadata ::
  Text -> Text -> ReadModel.HistoryRelevance -> Text ->
  [Interaction.CompactEntityReference] -> [Text] -> [Text] ->
  ReadModel.SemanticActionMetadata
historyMetadata actionId family relevance summary affected related scopes =
  ReadModel.SemanticActionMetadata
    { ReadModel.semanticActionMetadataActionId = actionId
    , ReadModel.semanticActionMetadataFamily = family
    , ReadModel.semanticActionMetadataRelevance = relevance
    , ReadModel.semanticActionMetadataOutcome = "accepted"
    , ReadModel.semanticActionMetadataSummary = summary
    , ReadModel.semanticActionMetadataAffected = affected
    , ReadModel.semanticActionMetadataRelatedEntityIds = related
    , ReadModel.semanticActionMetadataScopeIds = scopes
    }

createdAndDescribedBrickFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
createdAndDescribedBrickFixture input state = do
  arguments <- requireArgumentsObject input
  titleText <- requiredText "title" arguments
  description <- requiredText "description" arguments
  now <- operationTime input
  title <- mapDomainError (mkCanonicalText titleText Nothing Human)
  standing <- standingStateFromKernel state
  let draft = (ordinaryBrickDraft title standardV1 now)
        {Domain.brickDraftDescription = Just description}
  (brick, _, nextStanding) <- mapStandingError (Standing.createStandingBrick
    draft (actionIdFor input <> ":priority-evidence") now standing)
  material <- materialStateFromKernel state
  let nextMaterial = registerMaterialBrick (brickId brick) Active material
      actionId = actionIdFor input <> ":created-described"
      reference = compactBrickReference brick
      metadata = historyMetadata actionId "lifecycle" ReadModel.Important
        ("Created " <> Domain.brickTitle brick <> ".") [reference] [] []
  accepted <- appendForFixture input "created-described"
    [ ProposeValueStored "v1.standing" (toJSON nextStanding)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination nextStanding))
    , ProposeValueStored "v1.material" (toJSON nextMaterial)
    , ReadModel.historyMetadataEvent metadata
    ] state
  pure OperationResult
    { operationResultValue = object
        [ "brick" .= Domain.brickId brick
        , "semantic_action" .= eventBatchSemanticActionId
            (appendResultBatch accepted)
        ]
    , operationResultState = appendResultState accepted
    }

renameBrickOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
renameBrickOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "brick" arguments
  title <- requiredText "title" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (brick, nextStanding) <- mapStandingError (Standing.renameStandingBrick
    identifier title authority now standing)
  let actionId = actionIdFor input <> ":rename"
      reference = compactBrickReference brick
      metadata = historyMetadata actionId "content" ReadModel.Relevant
        ("Renamed Brick to " <> Domain.brickTitle brick <> ".")
        [reference] [] []
  accepted <- appendForFixture input "rename"
    [ ProposeValueStored "v1.standing" (toJSON nextStanding)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination nextStanding))
    , ReadModel.historyMetadataEvent metadata
    ] state
  let canonical = appendResultState accepted
      response = successfulResponse "Brick renamed." "brick_changed"
        (Just reference) ["title"] [] Nothing canonical
  next <- persistLatestOperationalResponse response canonical
  pure OperationResult
    { operationResultValue = object
        [ "semantic_action" .= eventBatchSemanticActionId
            (appendResultBatch accepted)
        , "response" .= Interaction.operationalResponseProjection response
        ]
    , operationResultState = next
    }

describeBrickOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
describeBrickOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "brick" arguments
  description <- requiredText "description" arguments
  now <- operationTime input
  standing <- standingStateFromKernel state
  (brick, nextStanding) <- mapStandingError (Standing.describeStandingBrick
    identifier description now standing)
  annotations <- annotationStateFromKernel state
  let nextAnnotations = ReadModel.staleAnnotationsAfterTextEdit identifier
        "description" (Domain.brickDescriptionRevision brick) annotations
      actionId = actionIdFor input <> ":describe"
      reference = compactBrickReference brick
      metadata = historyMetadata actionId "content" ReadModel.Relevant
        ("Updated the description of " <> Domain.brickTitle brick <> ".")
        [reference] [] []
  accepted <- appendForFixture input "describe"
    [ ProposeValueStored "v1.standing" (toJSON nextStanding)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination nextStanding))
    , ProposeValueStored "v1.annotations" (toJSON nextAnnotations)
    , ReadModel.historyMetadataEvent metadata
    ] state
  let canonical = appendResultState accepted
      response = successfulResponse "Brick description updated."
        "brick_changed" (Just reference) ["description"] [] Nothing canonical
  next <- persistLatestOperationalResponse response canonical
  pure OperationResult
    { operationResultValue = object
        [ "semantic_action" .= eventBatchSemanticActionId
            (appendResultBatch accepted)
        , "response" .= Interaction.operationalResponseProjection response
        ]
    , operationResultState = next
    }

annotatePartyOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
annotatePartyOperation input state = do
  arguments <- requireArgumentsObject input
  owner <- requiredAs "owner" arguments
  field <- requiredText "field" arguments
  textRevision <- requiredInteger "text_revision" arguments
  start <- requiredInteger "start_offset" arguments
  end <- requiredInteger "end_offset" arguments
  token <- requiredText "displayed_token" arguments
  party <- requiredAs "party" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  domain <- currentDomainState state
  annotations <- annotationStateFromKernel state
  (annotation, nextAnnotations) <- mapAnnotationError
    (ReadModel.annotatePartyInBrickText domain owner field textRevision start end
      token party authority now annotations)
  persistAnnotation input "party-annotation" annotation nextAnnotations state

annotateBrickOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
annotateBrickOperation input state = do
  arguments <- requireArgumentsObject input
  owner <- requiredAs "owner" arguments
  field <- requiredText "field" arguments
  textRevision <- requiredInteger "text_revision" arguments
  start <- requiredInteger "start_offset" arguments
  end <- requiredInteger "end_offset" arguments
  token <- requiredText "displayed_token" arguments
  target <- requiredAs "target" arguments
  authority <- requiredAs "authority" arguments
  now <- operationTime input
  domain <- currentDomainState state
  annotations <- annotationStateFromKernel state
  (annotation, nextAnnotations) <- mapAnnotationError
    (ReadModel.annotateBrickInBrickText domain owner field textRevision start end
      token target authority now annotations)
  persistAnnotation input "brick-annotation" annotation nextAnnotations state

markAnnotationStaleOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
markAnnotationStaleOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredAs "annotation" arguments
  annotations <- annotationStateFromKernel state
  (annotation, nextAnnotations) <- mapAnnotationError
    (ReadModel.markAnnotationStale identifier annotations)
  persistAnnotation input "annotation-stale" annotation nextAnnotations state

persistAnnotation ::
  OperationInput -> Text -> ReadModel.TextAnnotation ->
  ReadModel.AnnotationState -> V1State ->
  Either Text (OperationResult V1State)
persistAnnotation input suffix annotation annotations state = do
  let actionId = actionIdFor input <> ":" <> suffix
      metadata = historyMetadata actionId "content" ReadModel.Relevant
        "Updated a typed text annotation." []
        [ReadModel.unAnnotationId (ReadModel.textAnnotationId annotation)] []
  accepted <- appendForFixture input suffix
    [ ProposeValueStored "v1.annotations" (toJSON annotations)
    , ReadModel.historyMetadataEvent metadata
    ] state
  let canonical = appendResultState accepted
      response = successfulResponse "Annotation updated." "annotation_changed"
        Nothing [ReadModel.unAnnotationId (ReadModel.textAnnotationId annotation)]
        [] Nothing canonical
  next <- persistLatestOperationalResponse response canonical
  pure OperationResult
    { operationResultValue = object
        [ "annotation" .= annotation
        , "semantic_action" .= eventBatchSemanticActionId
            (appendResultBatch accepted)
        , "response" .= Interaction.operationalResponseProjection response
        ]
    , operationResultState = next
    }

historyQueryOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
historyQueryOperation input state = do
  arguments <- requireArgumentsObject input
  query <- requiredAs "filter" arguments
  page <- mapHistoryError (ReadModel.historyQuery query state)
  pure OperationResult
    {operationResultValue = toJSON page, operationResultState = state}

historyBriefOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
historyBriefOperation input state = do
  arguments <- requireArgumentsObject input
  query <- requiredAs "filter" arguments
  brief <- mapHistoryError (ReadModel.historyBrief query state)
  pure OperationResult
    {operationResultValue = toJSON brief, operationResultState = state}

historyPageObservation :: ObservationInput -> V1State -> Either Text Value
historyPageObservation input _ = case observationArguments input of
  [value] -> Right value
  _ -> Left "HistoryPage expects exactly one argument"

historyBriefObservation :: ObservationInput -> V1State -> Either Text Value
historyBriefObservation input _ = case observationArguments input of
  [value] -> Right value
  _ -> Left "HistoryBrief expects exactly one argument"

textAnnotationObservation :: ObservationInput -> V1State -> Either Text Value
textAnnotationObservation input state = do
  identifier <- exactlyOneAsArgument "TextAnnotation" input
  annotations <- annotationStateFromKernel state
  maybe (Left "unknown TextAnnotation") (Right . toJSON)
    (Map.lookup identifier (ReadModel.annotationStateAnnotations annotations))

mapAnnotationError :: Either ReadModel.AnnotationError value -> Either Text value
mapAnnotationError = either (Left . Text.pack . show) Right

mapHistoryError :: Either ReadModel.HistoryError value -> Either Text value
mapHistoryError = either (Left . Text.pack . show) Right

------------------------------------------------------------
-- Typed Packs, local credentials, and the capability host
------------------------------------------------------------

integrationStateFromKernel :: V1State -> Either Text Integration.PackState
integrationStateFromKernel state = case kernelValue "v1.integration" state of
  Nothing -> Right Integration.emptyPackState
  Just value -> case fromJSON value of
    Success integration -> do
      mapIntegrationError (Integration.validatePackState integration)
      Right integration
    Error problem -> Left ("stored integration state is malformed: "
      <> Text.pack problem)

packDeploymentFromKernel :: V1State -> Either Text Integration.PackDeployment
packDeploymentFromKernel state = case kernelArtifact "v1.pack-deployment" state of
  Nothing -> Right Integration.defaultPackDeployment
  Just value -> case fromJSON value of
    Success deployment -> do
      mapIntegrationError
        (Integration.validateVaultState (Integration.packDeploymentVault deployment))
      Right deployment
    Error problem -> Left ("stored Pack deployment is malformed: "
      <> Text.pack problem)

persistPackDeployment ::
  Integration.PackDeployment -> V1State -> Either Text V1State
persistPackDeployment deployment state = mapKernelError
  (putKernelArtifact "v1.pack-deployment" (toJSON deployment) state)

persistIntegrationState ::
  OperationInput -> Text -> Integration.PackState -> V1State ->
  Either Text (AppendResult)
persistIntegrationState input suffix integration = appendForFixture input suffix
  [ProposeValueStored "v1.integration" (toJSON integration)]

installPackOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
installPackOperation input state = do
  arguments <- requireArgumentsObject input
  manifest <- requiredAs "manifest" arguments
  now <- operationTime input
  let evidence = Integration.PackInstallEvidence
        { Integration.packInstallEvidenceVerifiedContentHash = fromMaybe
            (Integration.packInstallManifestContentHash manifest)
            (optionalText "verified_content_hash" arguments)
        , Integration.packInstallEvidenceCompatibleProtocol = fromMaybe 1
            (optionalInteger "compatible_protocol" arguments)
        , Integration.packInstallEvidenceTrustedPublisher = fromMaybe True
            (optionalBoolean "trusted_publisher" arguments)
        }
  componentSources <- fromMaybe Map.empty <$>
    optionalAs "component_sources" arguments
  integrationBefore <- integrationStateFromKernel state
  case Integration.installPack now evidence manifest integrationBefore of
    Left problem -> Right (preconditionRejected problem state)
    Right (pack, components, integration) -> do
      let componentIds = map Integration.packComponentId components
      unless (all (`elem` componentIds) (Map.keys componentSources))
        (Left "component_sources names a component outside the verified manifest")
      accepted <- persistIntegrationState input "install-pack" integration state
      deployment <- packDeploymentFromKernel (appendResultState accepted)
      withSources <- persistPackDeployment (deployment
        { Integration.packDeploymentComponentSources = Map.union
            componentSources
            (Integration.packDeploymentComponentSources deployment)
        }) (appendResultState accepted)
      component <- case components of
        first : _ -> Right first
        [] -> Left "verified Pack installation produced no component"
      pure OperationResult
        { operationResultValue = object
            [ "pack" .= Integration.littleAntPackId pack
            , "component" .= Integration.packComponentId component
            , "components" .= componentIds
            ]
        , operationResultState = withSources
        }

disablePackOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
disablePackOperation = packLifecycleOperation "disable-pack" Integration.disablePack

enablePackOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
enablePackOperation = packLifecycleOperation "enable-pack" Integration.enablePack

revokePackOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
revokePackOperation = packLifecycleOperation "revoke-pack" Integration.revokePack

packLifecycleOperation ::
  Text -> (Text -> Integration.PackState ->
    Either Integration.IntegrationError Integration.PackState) ->
  OperationInput -> V1State -> Either Text (OperationResult V1State)
packLifecycleOperation suffix transition input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredText "pack" arguments
  integration <- integrationStateFromKernel state
  case transition identifier integration of
    Left problem -> Right (preconditionRejected problem state)
    Right next -> do
      accepted <- persistIntegrationState input suffix next state
      pack <- mapIntegrationError (Integration.findPack identifier next)
      pure OperationResult
        { operationResultValue = object
            [ "pack" .= Integration.littleAntPackId pack
            , "status" .= Integration.littleAntPackStatus pack
            ]
        , operationResultState = appendResultState accepted
        }

recordPackInvocationOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
recordPackInvocationOperation input state = do
  arguments <- requireArgumentsObject input
  component <- requiredText "component" arguments
  operation <- requiredText "operation" arguments
  inputRevision <- requiredText "input_revision" arguments
  requestHash <- requiredText "request_hash" arguments
  grants <- requiredAs "capability_grants" arguments
  result <- requiredAs "result" arguments
  now <- operationTime input
  integration <- integrationStateFromKernel state
  case Integration.recordPackInvocation now component operation inputRevision
      requestHash grants result integration of
    Left problem -> Right (preconditionRejected problem state)
    Right (invocation, next) -> do
      accepted <- persistIntegrationState input "pack-invocation" next state
      pure OperationResult
        { operationResultValue = toJSON invocation
        , operationResultState = appendResultState accepted
        }

storeCredentialOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
storeCredentialOperation input state = do
  arguments <- requireArgumentsObject input
  label <- requiredText "label" arguments
  payload <- requiredText "encrypted_payload" arguments
  now <- operationTime input
  deployment <- packDeploymentFromKernel state
  case Integration.storeCredential now label payload
      (Integration.packDeploymentVault deployment) of
    Left problem -> Right (preconditionRejected problem state)
    Right (entry, vault) -> do
      next <- persistPackDeployment (deployment
        {Integration.packDeploymentVault = vault}) state
      pure OperationResult
        { operationResultValue = object
            ["vault_entry" .= Integration.vaultEntryId entry]
        , operationResultState = next
        }

bindCredentialOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
bindCredentialOperation input state = do
  arguments <- requireArgumentsObject input
  slot <- requiredText "slot" arguments
  account <- requiredText "account" arguments
  vaultEntry <- requiredText "vault_entry_id" arguments
  now <- operationTime input
  deployment <- packDeploymentFromKernel state
  case Integration.bindCredential now slot account vaultEntry
      (Integration.packDeploymentVault deployment) of
    Left problem -> Right (preconditionRejected problem state)
    Right (binding, vault) -> do
      next <- persistPackDeployment (deployment
        {Integration.packDeploymentVault = vault}) state
      pure OperationResult
        { operationResultValue = object
            ["binding" .= Integration.credentialBindingId binding]
        , operationResultState = next
        }

lockCredentialBindingOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
lockCredentialBindingOperation = credentialTransitionOperation
  Integration.lockCredentialBinding

unlockCredentialBindingOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
unlockCredentialBindingOperation = credentialTransitionOperation
  Integration.unlockCredentialBinding

revokeCredentialBindingOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
revokeCredentialBindingOperation = credentialTransitionOperation
  Integration.revokeCredentialBinding

credentialTransitionOperation ::
  (Text -> Integration.VaultState -> Either Integration.IntegrationError
    (Integration.CredentialBinding, Integration.VaultState)) ->
  OperationInput -> V1State -> Either Text (OperationResult V1State)
credentialTransitionOperation transition input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredText "binding" arguments
  deployment <- packDeploymentFromKernel state
  case transition identifier (Integration.packDeploymentVault deployment) of
    Left problem -> Right (preconditionRejected problem state)
    Right (binding, vault) -> do
      next <- persistPackDeployment (deployment
        {Integration.packDeploymentVault = vault}) state
      pure OperationResult
        { operationResultValue = Integration.credentialBindingProjection binding
        , operationResultState = next
        }

credentialBrokerAuthorizeOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
credentialBrokerAuthorizeOperation input state = do
  arguments <- requireArgumentsObject input
  component <- requiredText "component_id" arguments
  slot <- requiredText "slot" arguments
  account <- requiredText "account" arguments
  deployment <- packDeploymentFromKernel state
  let result = case Integration.authorizeCredential component slot account
        (Integration.packDeploymentVault deployment) of
        Right binding -> object
          [ "authorized" .= True
          , "binding" .= Integration.credentialBindingId binding
          ]
        Left problem -> object
          [ "authorized" .= False
          , "error_code" .= credentialErrorCode problem
          ]
  pure OperationResult
    {operationResultValue = result, operationResultState = state}

hostHttpRequestOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
hostHttpRequestOperation input state = do
  arguments <- requireArgumentsObject input
  componentId <- requiredText "component_id" arguments
  request <- requiredAs "request" arguments
  grants <- requiredAs "capability_grants" arguments
  integration <- integrationStateFromKernel state
  component <- mapIntegrationError (Integration.findComponent componentId integration)
  case Integration.validateHostHttpRequest component grants request of
    Left problem -> Right (preconditionRejected problem state)
    Right () -> pure OperationResult
      { operationResultValue = object
          [ "accepted" .= True
          , "redacted" .= True
          ]
      , operationResultState = state
      }

packRunnerExecuteOperation ::
  OperationInput -> V1State -> IO (Either Text (OperationResult V1State))
packRunnerExecuteOperation input state = case do
    arguments <- requireArgumentsObject input
    request <- requiredAs "request" arguments
    now <- operationTime input
    integration <- integrationStateFromKernel state
    deployment <- packDeploymentFromKernel state
    account <- packRequestAccount request
    pure (arguments, request, now, integration, deployment, account) of
  Left problem -> pure (Left problem)
  Right (arguments, request, now, integration, deployment, account) -> do
    let componentId = Integration.packExecutionRequestComponentId request
        source = TextEncoding.encodeUtf8 (Map.findWithDefault
          "error('pack_source_unavailable')" componentId
          (Integration.packDeploymentComponentSources deployment))
        provider _
          | fromMaybe False (optionalBoolean "provider_failure" arguments) =
              pure (Integration.ProviderFailed "provider failure")
          | otherwise = pure (Integration.ProviderSucceeded
              (object ["items" .= ([] :: [Value])]))
    attempted <- Integration.executePackRuntime False now account provider source
      request integration deployment
    pure $ case attempted of
      Left problem -> Right OperationResult
        { operationResultValue = toJSON (Integration.PackExecutionResult
            1 False Nothing (Just (packExecutionErrorCode problem)) [])
        , operationResultState = state
        }
      Right (result, nextIntegration, nextDeployment) -> do
        withCanonical <- if nextIntegration == integration
          then Right state
          else appendResultState <$> persistIntegrationState input
            "pack-execution" nextIntegration state
        withDeployment <- persistPackDeployment nextDeployment withCanonical
        pure OperationResult
          { operationResultValue = toJSON result
          , operationResultState = withDeployment
          }

inspectPackRuntimeInputOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
inspectPackRuntimeInputOperation _ state = pure OperationResult
  {operationResultValue = Null, operationResultState = state}

probePackSandboxOperation ::
  OperationInput -> V1State -> IO (Either Text (OperationResult V1State))
probePackSandboxOperation input state = case do
    arguments <- requireArgumentsObject input
    componentId <- requiredText "component" arguments
    integration <- integrationStateFromKernel state
    component <- mapIntegrationError
      (Integration.findComponent componentId integration)
    pure component of
  Left problem -> pure (Left problem)
  Right component -> do
    probed <- Integration.probePackSandbox
      (Integration.packComponentCapabilities component)
    pure $ case probed of
      Left problem -> Left problem
      Right report -> Right OperationResult
        { operationResultValue = Integration.sandboxReportProjection report
        , operationResultState = state
        }

credentialBindingFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
credentialBindingFixture input state = do
  arguments <- requireArgumentsObject input
  component <- requiredText "component" arguments
  slotName <- requiredText "slot" arguments
  account <- requiredText "account" arguments
  integration <- integrationStateFromKernel state
  installedComponent <- mapIntegrationError
    (Integration.findComponent component integration)
  effectiveSlot <- case mapMaybe (Text.stripPrefix "credential:")
      (Integration.packComponentCapabilities installedComponent) of
    [] -> Left "credential fixture component declares no credential slot"
    [onlySlot] -> Right onlySlot
    declaredSlots
      | slotName `elem` declaredSlots -> Right slotName
      | otherwise -> Left "credential fixture slot is not declared by component"
  now <- operationTime input
  deployment <- packDeploymentFromKernel state
  (entry, vault1) <- mapIntegrationError (Integration.storeCredential now
    "scenario credential" "ciphertext:scenario-secret"
    (Integration.packDeploymentVault deployment))
  (slot, vault2) <- mapIntegrationError (Integration.declareCredentialSlot
    component effectiveSlot "api_key" True vault1)
  (binding, vault3) <- mapIntegrationError (Integration.bindCredential now
    (Integration.credentialSlotId slot) account
    (Integration.vaultEntryId entry) vault2)
  next <- persistPackDeployment (deployment
    {Integration.packDeploymentVault = vault3}) state
  pure OperationResult
    { operationResultValue = object
        [ "binding" .= Integration.credentialBindingId binding
        , "slot" .= Integration.credentialSlotId slot
        ]
    , operationResultState = next
    }

packExecutionResultObservation :: ObservationInput -> V1State -> Either Text Value
packExecutionResultObservation input _ = case observationArguments input of
  [value] -> Right value
  _ -> Left "PackExecutionResult expects exactly one argument"

hostHttpTraceObservation :: ObservationInput -> V1State -> Either Text Value
hostHttpTraceObservation _ state = do
  deployment <- packDeploymentFromKernel state
  pure (object ["requests" .= Integration.packDeploymentHttpTrace deployment])

providerBackoffObservation :: ObservationInput -> V1State -> Either Text Value
providerBackoffObservation input state = case observationArguments input of
  [String component, String account] -> do
    integration <- integrationStateFromKernel state
    pure (toJSON (Integration.providerBackoff component account integration))
  _ -> Left "ProviderBackoff expects component and account text arguments"

packInvocationInputObservation :: ObservationInput -> V1State -> Either Text Value
packInvocationInputObservation input state = do
  component <- exactlyOneTextArgument "PackInvocationInput" input
  deployment <- packDeploymentFromKernel state
  pure (fromMaybe (Object KeyMap.empty) (Map.lookup component
    (Integration.packDeploymentRuntimeInputs deployment)))

packInvocationTraceObservation :: ObservationInput -> V1State -> Either Text Value
packInvocationTraceObservation _ state = do
  integration <- integrationStateFromKernel state
  deployment <- packDeploymentFromKernel state
  pure (object
    [ "items" .= Integration.packStateInvocations integration
    , "during_replay" .= Integration.packDeploymentDuringReplay deployment
    ])

preconditionRejected ::
  Show problem => problem -> V1State -> OperationResult V1State
preconditionRejected problem state = OperationResult
  { operationResultValue = object
      [ "accepted" .= False
      , "error_code" .= ("precondition_failed" :: Text)
      , "detail" .= Text.pack (show problem)
      ]
  , operationResultState = state
  }

packRequestAccount :: Integration.PackExecutionRequest -> Either Text Text
packRequestAccount request = case Integration.packExecutionRequestInput request of
  Object fields -> requiredText "account" fields
  _ -> Left "Pack execution input must be an object with account"

credentialErrorCode :: Integration.IntegrationError -> Text
credentialErrorCode = \case
  Integration.VaultUnavailable -> "credential_locked"
  Integration.CredentialAccessLocked -> "credential_locked"
  Integration.CredentialAccessRevoked -> "credential_revoked"
  Integration.CredentialAccessUnauthorized -> "credential_unauthorized"
  _ -> "credential_failure"

packExecutionErrorCode :: Integration.IntegrationError -> Text
packExecutionErrorCode = \case
  Integration.ReplayExecutionForbidden -> "replay_forbidden"
  Integration.UndeclaredCapability _ -> "capability_denied"
  Integration.RawOperatingSystemCapability _ -> "raw_os_denied"
  problem -> credentialErrorCode problem

mapIntegrationError ::
  Either Integration.IntegrationError value -> Either Text value
mapIntegrationError = either (Left . Text.pack . show) Right

------------------------------------------------------------
-- Source imports, synchronization, and reviewed cleanup
------------------------------------------------------------

sourceImportStateFromKernel :: V1State -> Either Text SourceImport.SourceImportState
sourceImportStateFromKernel state = case kernelValue "v1.source-imports" state of
  Nothing -> Right SourceImport.emptySourceImportState
  Just value -> case fromJSON value of
    Success imports -> Right imports
    Error problem -> Left ("stored source-import state is malformed: "
      <> Text.pack problem)

persistSourceImportSlices ::
  OperationInput -> Text -> SourceImport.SourceImportState ->
  Standing.StandingState -> MaterialState -> Value -> V1State ->
  Either Text (OperationResult V1State)
persistSourceImportSlices input suffix imports standing material result state = do
  mapSourceImportError
    (SourceImport.validateSourceImportState standing material imports)
  accepted <- appendForFixture input suffix
    [ ProposeValueStored "v1.source-imports" (toJSON imports)
    , ProposeValueStored "v1.standing" (toJSON standing)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination standing))
    , ProposeValueStored "v1.material" (toJSON material)
    ] state
  pure OperationResult
    {operationResultValue = result, operationResultState = appendResultState accepted}

persistSourceImportSelectionSlices ::
  OperationInput -> Text -> SourceImport.SourceImportState ->
  Selection.SelectionState -> Standing.StandingState -> MaterialState -> Value ->
  V1State -> Either Text (OperationResult V1State)
persistSourceImportSelectionSlices input suffix imports selection standing material
    result state = do
  mapSourceImportError
    (SourceImport.validateSourceImportState standing material imports)
  mapSelectionError (Selection.validateSelectionState
    (Selection.SelectionContext standing material) selection)
  accepted <- appendForFixture input suffix
    [ ProposeValueStored "v1.source-imports" (toJSON imports)
    , ProposeValueStored "v1.selection" (toJSON selection)
    , ProposeValueStored "v1.standing" (toJSON standing)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination standing))
    , ProposeValueStored "v1.material" (toJSON material)
    ] state
  pure OperationResult
    {operationResultValue = result, operationResultState = appendResultState accepted}

withSourceImportSlices ::
  V1State -> Either Text
    (Standing.StandingState, MaterialState, SourceImport.SourceImportState)
withSourceImportSlices state = (,,)
  <$> standingStateFromKernel state
  <*> materialStateFromKernel state
  <*> sourceImportStateFromKernel state

createImportProfileOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
createImportProfileOperation input state = do
  arguments <- requireArgumentsObject input
  name <- requiredText "name" arguments
  adapterReference <- requiredText "adapter" arguments
  sourceScope <- requiredText "source_scope" arguments
  candidateKind <- requiredText "candidate_kind" arguments
  route <- requiredAs "route" arguments
  parent <- optionalAs "destination_parent" arguments
  owner <- optionalAs "destination_owner" arguments
  shelf <- optionalAs "destination_shelf" arguments
  automatic <- requiredAs "automatic_adoption" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  integration <- integrationStateFromKernel state
  adapter <- resolveSourceAdapter adapterReference integration
  case SourceImport.createImportProfile now name adapter sourceScope candidateKind
      route parent owner shelf automatic standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (profile, next) -> persistSourceImportSlices input "import-profile"
      next standing material
      (object ["profile" .= SourceImport.importProfileId profile]) state

resolveSourceAdapter :: Text -> Integration.PackState -> Either Text Integration.PackComponent
resolveSourceAdapter reference integration
  | reference `elem` ["standard/microsoft-todo", "standard/microsoft-todo@1"] =
      Right SourceImport.microsoftTodoAdapterV1
  | otherwise = mapIntegrationError (Integration.findComponent
      (fromMaybe reference (Text.stripSuffix "@1" reference)) integration)

retireImportProfileOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
retireImportProfileOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredText "profile" arguments
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.retireImportProfile identifier standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (profile, nextMaterial, next) -> persistSourceImportSlices input
      "import-profile-retired" next standing nextMaterial
      (SourceImport.importProfileProjection profile) state

planImportOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
planImportOperation input state = do
  arguments <- requireArgumentsObject input
  profile <- requiredText "profile" arguments
  mode <- requiredAs "mode" arguments
  erase <- requiredAs "erase_after_import" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.planImport now profile mode erase standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (run, next) -> persistSourceImportSlices input "import-planned" next
      standing material (object ["run" .= SourceImport.importRunId run]) state

startImportOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
startImportOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.startImport runId standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (run, next) -> persistSourceImportSlices input "import-started" next
      standing material (SourceImport.importRunProjection run) state

acceptImportCandidateOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
acceptImportCandidateOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  candidate <- requiredAs "candidate" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.acceptImportCandidate now runId candidate standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (record, brick, entry, nextStanding, nextMaterial, next) ->
      persistSourceImportSlices input "import-candidate" next nextStanding nextMaterial
        (object
          [ "record" .= SourceImport.externalRecordId record
          , "raw" .= SourceImport.externalRecordRaw record
          , "brick" .= fmap Domain.brickId brick
          , "entry" .= fmap Domain.listEntryId entry
          ]) state

observeExternalCompletionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
observeExternalCompletionOperation input state = do
  arguments <- requireArgumentsObject input
  record <- requiredText "record" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  selection <- selectionStateFromKernel state
  case SourceImport.observeExternalCompletion now record standing material selection
      imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (proposal, nextSelection, next) ->
      persistSourceImportSelectionSlices input "external-completion-review" next
        nextSelection standing material
        (object
          [ "record" .= record
          , "proposal" .= Selection.proposalId proposal
          ]) state

finishImportCaptureOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
finishImportCaptureOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  cursor <- optionalAs "source_cursor" arguments
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.finishImportCapture runId cursor standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (run, next) -> persistSourceImportSlices input "import-captured" next
      standing material (SourceImport.importRunProjection run) state

verifyImportOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
verifyImportOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  verifiedCount <- requiredInteger "verified_count" arguments
  failureCount <- requiredInteger "failure_count" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.verifyImport now runId verifiedCount failureCount
      standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (run, next) -> persistSourceImportSlices input "import-verified" next
      standing material (SourceImport.importRunProjection run) state

failImportOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
failImportOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.failImportRun now runId standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (run, next) -> persistSourceImportSlices input "import-failed" next
      standing material (SourceImport.importRunProjection run) state

completeSynchronizationOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
completeSynchronizationOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  receipt <- requiredText "receipt_hash" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.completeSynchronization now runId receipt standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (run, next) -> persistSourceImportSlices input "synchronization-completed"
      next standing material (SourceImport.importRunProjection run) state

verifiedMigrationFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
verifiedMigrationFixture input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  reviewed <- requiredAs "reviewed_dispositions" arguments
  reconstructible <- requiredAs "locally_reconstructible" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  if not reviewed || not reconstructible
    then Right (preconditionRejected
      ("verified migration fixture requires reviewed reconstructible records" :: Text)
      state)
    else case SourceImport.prepareVerifiedMigration now runId standing material imports of
      Left problem -> Right (preconditionRejected problem state)
      Right (run, next) -> persistSourceImportSlices input "migration-prepared"
        next standing material (object ["run" .= SourceImport.importRunId run]) state

planEraseAfterImportOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
planEraseAfterImportOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.planEraseAfterImport now runId standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (effects, next) -> case effects of
      [] -> Right (preconditionRejected ("migration contains no item" :: Text) state)
      effect : _ -> persistSourceImportSlices input "cleanup-planned" next standing
        material (object
          [ "item_effect" .= SourceImport.sourceEffectId effect
          , "effects" .= map SourceImport.sourceEffectId effects
          ]) state

approveSourceEffectOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
approveSourceEffectOperation = sourceEffectSimpleOperation "effect-approved" $ \now ->
  SourceImport.approveSourceEffect now

declineSourceEffectOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
declineSourceEffectOperation = sourceEffectSimpleOperation "effect-declined" $ \_ ->
  SourceImport.declineSourceEffect

retrySourceEffectOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
retrySourceEffectOperation = sourceEffectSimpleOperation "effect-retried" $ \_ ->
  SourceImport.retrySourceEffect

sourceEffectSimpleOperation ::
  Text -> (UTCTime -> Text -> Standing.StandingState -> MaterialState ->
    SourceImport.SourceImportState -> Either SourceImport.ImportError
      (SourceImport.SourceEffect, SourceImport.SourceImportState)) ->
  OperationInput -> V1State -> Either Text (OperationResult V1State)
sourceEffectSimpleOperation suffix transition input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredText "effect" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case transition now identifier standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (effect, next) -> persistSourceImportSlices input suffix next standing
      material (SourceImport.sourceEffectProjection effect) state

recordSourceEffectAppliedOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
recordSourceEffectAppliedOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredText "effect" arguments
  receipt <- requiredText "receipt" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.applySourceEffect now identifier receipt standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (effect, next) -> persistSourceImportSlices input "effect-applied" next
      standing material (SourceImport.sourceEffectProjection effect) state

recordSourceEffectFailedOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
recordSourceEffectFailedOperation input state = do
  arguments <- requireArgumentsObject input
  identifier <- requiredText "effect" arguments
  failure <- requiredText "failure" arguments
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.failSourceEffect identifier failure standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (effect, next) -> persistSourceImportSlices input "effect-failed" next
      standing material (SourceImport.sourceEffectProjection effect) state

cutOverImportOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
cutOverImportOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  receipt <- requiredText "receipt_hash" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.cutOverImport now runId receipt standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (run, nextMaterial, next) -> persistSourceImportSlices input
      "import-cut-over" next standing nextMaterial
      (SourceImport.importRunProjection run) state

proposeEmptyContainerDeletionOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
proposeEmptyContainerDeletionOperation input state = do
  arguments <- requireArgumentsObject input
  runId <- requiredText "run" arguments
  preview <- requiredText "preview" arguments
  now <- operationTime input
  (standing, material, imports) <- withSourceImportSlices state
  case SourceImport.proposeEmptyContainerDeletion now runId preview standing material imports of
    Left problem -> Right (preconditionRejected problem state)
    Right (effect, next) -> persistSourceImportSlices input "container-effect"
      next standing material (object ["effect" .= SourceImport.sourceEffectId effect]) state

importProfileObservation :: ObservationInput -> V1State -> Either Text Value
importProfileObservation input state = do
  identifier <- exactlyOneTextArgument "ImportProfile" input
  imports <- sourceImportStateFromKernel state
  maybe (Left "unknown ImportProfile")
    (Right . SourceImport.importProfileProjection)
    (Map.lookup identifier (SourceImport.sourceImportProfiles imports))

externalRecordObservation :: ObservationInput -> V1State -> Either Text Value
externalRecordObservation input state = do
  identifier <- exactlyOneTextArgument "ExternalRecord" input
  imports <- sourceImportStateFromKernel state
  maybe (Left "unknown ExternalRecord")
    (Right . SourceImport.sourceRecordProjection)
    (Map.lookup identifier (SourceImport.sourceImportRecords imports))

importRunObservation :: ObservationInput -> V1State -> Either Text Value
importRunObservation input state = do
  identifier <- exactlyOneTextArgument "ImportRun" input
  imports <- sourceImportStateFromKernel state
  maybe (Left "unknown ImportRun") (Right . SourceImport.importRunProjection)
    (Map.lookup identifier (SourceImport.sourceImportRuns imports))

sourceEffectObservation :: ObservationInput -> V1State -> Either Text Value
sourceEffectObservation input state = do
  identifier <- exactlyOneTextArgument "SourceEffect" input
  imports <- sourceImportStateFromKernel state
  maybe (Left "unknown SourceEffect") (Right . SourceImport.sourceEffectProjection)
    (Map.lookup identifier (SourceImport.sourceImportEffects imports))

sourceEffectsObservation :: ObservationInput -> V1State -> Either Text Value
sourceEffectsObservation input state = do
  runId <- exactlyOneTextArgument "SourceEffects" input
  imports <- sourceImportStateFromKernel state
  pure (SourceImport.sourceEffectsForRunProjection runId imports)

proposalObservation :: ObservationInput -> V1State -> Either Text Value
proposalObservation input state = do
  identifier <- exactlyOneAsArgument "Proposal" input
  selection <- selectionStateFromKernel state
  maybe (Left "unknown Proposal") (Right . toJSON)
    (Map.lookup identifier (Selection.selectionStateProposals selection))

mapSourceImportError ::
  Either SourceImport.ImportError value -> Either Text value
mapSourceImportError = either (Left . Text.pack . show) Right

------------------------------------------------------------
-- Read-only planning exports and loopback UI adapter
------------------------------------------------------------

planningArtifactKey :: Text
planningArtifactKey = "v1.planning"

planningStateFromKernel :: V1State -> Either Text Planning.PlanningState
planningStateFromKernel state = case kernelArtifact planningArtifactKey state of
  Nothing -> Right Planning.emptyPlanningState
  Just value -> case fromJSON value of
    Success planning -> do
      mapPlanningError (Planning.validatePlanningState planning)
      Right planning
    Error problem -> Left ("stored planning state is malformed: "
      <> Text.pack problem)

persistPlanningArtifact ::
  Planning.PlanningState -> V1State -> Either Text V1State
persistPlanningArtifact planning state = mapKernelError
  (putKernelArtifact planningArtifactKey (toJSON planning) state)

exportTaskJugglerOperation ::
  OperationInput -> V1State -> IO (Either Text (OperationResult V1State))
exportTaskJugglerOperation input state = case do
    arguments <- requireArgumentsObject input
    datasetRevision <- requiredInteger "dataset_revision" arguments
    selected <- requiredAs "selected_bricks" arguments
    payload <- requiredAs "payload" arguments
    judgment <- judgmentStateFromKernel state
    profile <- requiredPlanningEffortProfile "effort_profile" arguments judgment
    standing <- standingStateFromKernel state
    planning <- planningStateFromKernel state
    now <- operationTime input
    let domain = Execution.executionStateDomain
          (Coordination.coordinationStateExecution
            (Standing.standingStateCoordination standing))
    pure (datasetRevision, selected, payload, profile, domain, judgment,
      planning, now) of
  Left problem -> pure (Left problem)
  Right (datasetRevision, selected, payload, profile, domain, judgment,
      planning, now) -> case Planning.createTaskJugglerManifest now
        datasetRevision (unDomainRevision (kernelRevision state)) selected profile
        payload Planning.taskJugglerExporterV1 domain judgment planning of
    Left problem -> pure (Right (preconditionRejected problem state))
    Right (manifest, planningExport, prepared) -> do
      outputResult <- Planning.runTaskJugglerExporter
        (Planning.planningExportProjection planningExport)
        (Planning.exportPayloadSuggestedFilename payload)
      pure $ case outputResult of
        Left problem -> Left (Text.pack (show problem))
        Right output -> do
          (_, completed) <- mapPlanningError (Planning.attachTaskJugglerOutput
            (Planning.planningManifestId manifest) output prepared)
          next <- persistPlanningArtifact completed state
          pure OperationResult
            { operationResultValue = object
                [ "manifest" .= Planning.planningManifestId manifest
                , "dataset_revision" .= Planning.planningManifestDatasetRevision manifest
                ]
            , operationResultState = next
            }

importTaskJugglerActualOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
importTaskJugglerActualOperation input state = do
  arguments <- requireArgumentsObject input
  manifest <- requiredText "manifest" arguments
  brick <- requiredAs "brick" arguments
  observedHours <- requiredAs "observed_hours" arguments
  now <- operationTime input
  planning <- planningStateFromKernel state
  case Planning.importTaskJugglerActual now manifest brick observedHours planning of
    Left problem -> Right (preconditionRejected problem state)
    Right (actual, nextPlanning) -> do
      accepted <- appendForFixture input "taskjuggler-actual"
        [ProposeValueStored
          ("v1.imported-actual:" <> Planning.importedActualId actual)
          (toJSON actual)] state
      next <- persistPlanningArtifact nextPlanning (appendResultState accepted)
      pure OperationResult
        { operationResultValue = object
            [ "actual" .= Planning.importedActualId actual ]
        , operationResultState = next
        }

openLocalWebUiOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
openLocalWebUiOperation input state = do
  arguments <- requireArgumentsObject input
  port <- requiredInteger "port" arguments
  now <- operationTime input
  planning <- planningStateFromKernel state
  case Planning.openLocalWebUi now port Planning.metroWebUiV1 planning of
    Left problem -> Right (preconditionRejected problem state)
    Right (session, nextPlanning) -> do
      next <- persistPlanningArtifact nextPlanning state
      pure OperationResult
        { operationResultValue = object
            [ "session" .= Planning.webUiSessionId session
            , "bind_host" .= Planning.webUiSessionBindHost session
            ]
        , operationResultState = next
        }

closeLocalWebUiOperation ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
closeLocalWebUiOperation input state = do
  arguments <- requireArgumentsObject input
  sessionId <- requiredText "session" arguments
  now <- operationTime input
  planning <- planningStateFromKernel state
  case Planning.closeLocalWebUi now sessionId planning of
    Left problem -> Right (preconditionRejected problem state)
    Right (session, nextPlanning) -> do
      next <- persistPlanningArtifact nextPlanning state
      pure OperationResult
        { operationResultValue = toJSON session
        , operationResultState = next
        }

renderWebUiOperation ::
  OperationInput -> V1State -> IO (Either Text (OperationResult V1State))
renderWebUiOperation input state = case do
    arguments <- requireArgumentsObject input
    sessionId <- requiredText "session" arguments
    interactionId <- requiredAs "interaction" arguments
    planning <- planningStateFromKernel state
    interaction <- interactionStateFromKernel state
    envelope <- mapInteractionError
      (Interaction.currentInteraction interactionId interaction)
    _ <- mapPlanningError
      (Planning.renderUiEnvelope sessionId envelope planning)
    pure envelope of
  Left problem -> pure (Left problem)
  Right envelope -> do
    rendered <- Planning.runMetroWebUiRender envelope
    pure $ do
      value <- mapPlanningError rendered
      pure OperationResult
        { operationResultValue = toJSON value
        , operationResultState = state
        }

submitWebUiInputOperation ::
  OperationInput -> V1State -> IO (Either Text (OperationResult V1State))
submitWebUiInputOperation input state = case do
    arguments <- requireArgumentsObject input
    sessionId <- requiredText "session" arguments
    interactionId <- requiredAs "interaction_id" arguments
    interactionRevision <- requiredInteger "interaction_revision" arguments
    domainRevision <- requiredInteger "domain_revision" arguments
    actionId <- requiredText "action_id" arguments
    now <- operationTime input
    planning <- planningStateFromKernel state
    interaction <- interactionStateFromKernel state
    envelope <- mapInteractionError
      (Interaction.currentInteraction interactionId interaction)
    _ <- mapPlanningError
      (Planning.renderUiEnvelope sessionId envelope planning)
    let channelInput = object
          [ "interaction_id" .= interactionId
          , "interaction_revision" .= interactionRevision
          , "domain_revision" .= domainRevision
          , "action_id" .= actionId
          ]
    pure (sessionId, interactionId, interactionRevision, domainRevision,
      actionId, now, planning, interaction, envelope, channelInput) of
  Left problem -> pure (Left problem)
  Right (sessionId, interactionId, interactionRevision, domainRevision,
      actionId, now, planning, interaction, envelope, channelInput) -> do
    decodedResult <- Planning.runMetroWebUiDecode envelope channelInput
    pure $ do
      decoded <- mapPlanningError decodedResult
      forwarded <- mapPlanningError
        (Planning.forwardWebUiInput now sessionId decoded planning)
      let currentDomain = unDomainRevision (kernelRevision state)
      decision <- mapInteractionError (Interaction.classifyInteractionSubmission
        interactionId domainRevision interactionRevision currentDomain actionId now
        interaction)
      case decision of
        Interaction.StaleSubmission response staleInteraction -> do
          withInteraction <- persistInteractionArtifact staleInteraction state
          next <- persistPlanningArtifact forwarded withInteraction
          pure OperationResult
            { operationResultValue = toJSON response
            , operationResultState = next
            }
        Interaction.CurrentSubmission action -> do
          accepted <- appendForFixture input "web-ui-interaction-answer"
            [ProposeValueStored (Text.intercalate ":"
                [ "v1.interaction.answer"
                , Interaction.unInteractionId interactionId
                , Text.pack (show interactionRevision)
                ])
              (object
                [ "interaction" .= interactionId
                , "action_id" .= Interaction.interactionActionId action
                , "prompt_revision" .= interactionRevision
                , "surface" .= ("standard/web-metro" :: Text)
                ])]
            state
          (_, response, nextInteraction) <- mapInteractionError
            (Interaction.acceptCurrentInteractionAction interactionId domainRevision
              interactionRevision currentDomain actionId now interaction)
          withInteraction <- persistInteractionArtifact nextInteraction
            (appendResultState accepted)
          next <- persistPlanningArtifact forwarded withInteraction
          pure OperationResult
            { operationResultValue = toJSON response
            , operationResultState = next
            }

planningManifestObservation :: ObservationInput -> V1State -> Either Text Value
planningManifestObservation input state = do
  identifier <- exactlyOneTextArgument "PlanningManifest" input
  planning <- planningStateFromKernel state
  maybe (Left "unknown PlanningManifest") (Right . toJSON)
    (Map.lookup identifier (Planning.planningStateManifests planning))

exportedTaskJugglerObservation ::
  ObservationInput -> V1State -> Either Text Value
exportedTaskJugglerObservation input state = do
  identifier <- exactlyOneTextArgument "ExportedTaskJuggler" input
  planning <- planningStateFromKernel state
  planningExport <- maybe (Left "unknown TaskJuggler export") Right
    (Map.lookup identifier (Planning.planningStateExports planning))
  maybe (Left "TaskJuggler output was not recorded") (Right . toJSON)
    (Planning.planningExportOutput planningExport)

importedActualObservation :: ObservationInput -> V1State -> Either Text Value
importedActualObservation input state = do
  identifier <- exactlyOneTextArgument "ImportedActual" input
  planning <- planningStateFromKernel state
  maybe (Left "unknown ImportedActual") (Right . toJSON)
    (Map.lookup identifier (Planning.planningStateActuals planning))

webUiSessionObservation :: ObservationInput -> V1State -> Either Text Value
webUiSessionObservation input state = do
  identifier <- exactlyOneTextArgument "WebUiSession" input
  planning <- planningStateFromKernel state
  maybe (Left "unknown WebUiSession") (Right . toJSON)
    (Map.lookup identifier (Planning.planningStateWebSessions planning))

webUiTransitionsObservation :: ObservationInput -> V1State -> Either Text Value
webUiTransitionsObservation _ state =
  toJSON . Planning.planningStateWebTransitions <$> planningStateFromKernel state

requiredPlanningEffortProfile ::
  Text -> Object -> Judgment.JudgmentState -> Either Text Judgment.EffortProfile
requiredPlanningEffortProfile field arguments judgment = do
  value <- requiredValue field arguments
  case value of
    String reference
      | reference `elem` ["core/effort", "core/effort@1"] ->
          Right Judgment.initialEffortProfile
      | otherwise -> Left ("unknown effort profile: " <> reference)
    _ -> do
      profile <- decodeArgument field value
      _ <- mapJudgmentError (Judgment.effortBandById profile "NORMAL" judgment)
      pure profile

estimatedProjectFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
estimatedProjectFixture input state = do
  arguments <- requireArgumentsObject input
  projectText <- requiredText "project" arguments
  childValues <- requiredArray "children" arguments
  unless (length childValues == 2)
    (Left "estimated_project requires exactly two children")
  requestedProfile <- requiredText "effort_profile" arguments
  unless (requestedProfile `elem` ["core/effort", "core/effort@1"])
    (Left "estimated_project requires core/effort@1")
  children <- mapM parseEstimatedChild childValues
  now <- operationTime input
  projectTitle <- mapDomainError (mkCanonicalText projectText Nothing Human)
  standing <- standingStateFromKernel state
  (project, _, withProject) <- mapStandingError
    (Standing.createStandingBrick
      (ordinaryBrickDraft projectTitle Domain.projectV1 now)
      "fixture:estimated-project" now standing)
  (createdReversed, finalStanding) <- foldM
    (createEstimatedChild now (brickId project)) ([], withProject) children
  let created = reverse createdReversed
  judgment <- judgmentStateFromKernel state
  withJudgmentProject <- mapJudgmentError (Judgment.registerJudgmentBrick
    (brickId project) Nothing Active True judgment)
  finalJudgment <- foldM (registerEstimatedEffort now (brickId project))
    withJudgmentProject (zip created children)
  accepted <- appendForFixture input "estimated-project"
    [ ProposeValueStored "v1.standing" (toJSON finalStanding)
    , ProposeValueStored "v1.coordination"
        (toJSON (Standing.standingStateCoordination finalStanding))
    , ProposeValueStored "v1.judgment" (toJSON finalJudgment)
    ] state
  case created of
    [eventStore, repl] -> pure OperationResult
      { operationResultValue = object
          [ "project" .= brickId project
          , "event_store" .= brickId eventStore
          , "repl" .= brickId repl
          , "effort_profile" .= Judgment.effortProfileId Judgment.initialEffortProfile
          ]
      , operationResultState = appendResultState accepted
      }
    _ -> Left "estimated_project child creation was incomplete"
  where
    parseEstimatedChild value = do
      fields <- asObject "estimated project child" value
      (,) <$> requiredText "title" fields <*> requiredText "effort_band" fields
    createEstimatedChild now parent (created, standing) (titleText, band) = do
      title <- mapDomainError (mkCanonicalText titleText Nothing Human)
      (brick, _, next) <- mapStandingError (Standing.createStandingBrick
        ((ordinaryBrickDraft title standardV1 now)
          {Domain.brickDraftParent = Just parent})
        ("fixture:estimated:" <> band <> ":" <> titleText) now standing)
      pure (brick : created, next)
    registerEstimatedEffort now parent judgmentState (brick, (_, bandId)) = do
      registered <- mapJudgmentError (Judgment.registerJudgmentBrick
        (brickId brick) (Just parent) Active True judgmentState)
      band <- mapJudgmentError (Judgment.effortBandById
        Judgment.initialEffortProfile bandId registered)
      (_, _, next) <- mapJudgmentError (Judgment.classifyEffort
        (brickId brick) band Human False (Just "estimated project fixture")
        now registered)
      pure next

liveStatusSummaryFixture ::
  OperationInput -> V1State -> Either Text (OperationResult V1State)
liveStatusSummaryFixture input state = do
  now <- operationTime input
  title <- mapDomainError
    (mkCanonicalText "Focused status work" Nothing Human)
  standing <- standingStateFromKernel state
  (brick, _, created) <- mapStandingError (Standing.createStandingBrick
    (ordinaryBrickDraft title standardV1 now) "fixture:live-status" now standing)
  let coordination0 = Standing.standingStateCoordination created
  focusedExecution <- mapExecutionError (Execution.focusExecutionBrick
    (brickId brick) now (Coordination.coordinationStateExecution coordination0))
  let coordination1 = coordination0
        {Coordination.coordinationStateExecution = focusedExecution}
  coordination2 <- mapCoordinationError (Coordination.setCoordinationDeadline
    (brickId brick) (addUTCTime 3600 now) coordination1)
  (notices, coordination3) <- mapCoordinationError
    (Coordination.advanceCoordinationTime now coordination2)
  unless (not (null notices))
    (Left "live status fixture did not create a pending date notice")
  let finalStanding = created
        {Standing.standingStateCoordination = coordination3}
  mapStandingError (Standing.validateStandingState finalStanding)
  material <- materialStateFromKernel state
  (_, nextMaterial) <- mapMaterialError
    (captureInlineRaw "Review this source" Nothing Nothing now material)
  selection <- selectionStateFromKernel state
  (proposals, nextSelection) <- mapSelectionError (Selection.advanceSelection now
    (Selection.SelectionContext finalStanding nextMaterial) selection)
  unless (not (null proposals))
    (Left "live status fixture did not create an open proposal")
  accepted <- appendForFixture input "live-status-summary"
    [ ProposeValueStored "v1.standing" (toJSON finalStanding)
    , ProposeValueStored "v1.coordination" (toJSON coordination3)
    , ProposeValueStored "v1.material" (toJSON nextMaterial)
    , ProposeValueStored "v1.selection" (toJSON nextSelection)
    ] state
  pure OperationResult
    { operationResultValue = object ["brick" .= brickId brick]
    , operationResultState = appendResultState accepted
    }

mapExecutionError ::
  Either Execution.ExecutionError value -> Either Text value
mapExecutionError = either (Left . Text.pack . show) Right

mapPlanningError ::
  Either Planning.PlanningError value -> Either Text value
mapPlanningError = either (Left . Text.pack . show) Right

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
  coordination <- coordinationStateFromKernel state
  selection <- selectionStateFromKernel state
  let execution = Coordination.coordinationStateExecution coordination
      domain = Execution.executionStateDomain execution
      focused = Domain.focusRegisterCurrent (Domain.domainFocusRegister domain)
        >>= (`Map.lookup` Domain.domainBricks domain)
      focusReference = fmap (\brick -> Interaction.CompactEntityReference
        { Interaction.compactEntityReferenceId = unBrickId (brickId brick)
        , Interaction.compactEntityReferenceTitle = Just (Domain.brickTitle brick)
        , Interaction.compactEntityReferenceRevision =
            Domain.unEntityRevision (Domain.brickRevision brick)
        , Interaction.compactEntityReferenceState = case toJSON
            (Domain.brickStatus brick) of
              String value -> Just value
              _ -> Nothing
        }) focused
      humanWip = fromIntegral (Execution.activeHumanWipCount execution)
      openProposals = fromIntegral (length
        [ ()
        | proposal <- Map.elems (Selection.selectionStateProposals selection)
        , Selection.proposalStatus proposal == Selection.ProposalOpen
        ])
      pendingNotices = fromIntegral (length
        [ ()
        | notice <- Map.elems (Coordination.coordinationStateDateNotices coordination)
        , Coordination.dateNoticeStatus notice `elem`
            [Coordination.NoticePending, Coordination.NoticeSnoozed]
        ])
  pure (toJSON (Interaction.statusSummary focusReference humanWip
    openProposals pendingNotices interaction))

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
  [Object replayed] -> case KeyMap.lookup "state_hash" replayed of
    Just value@(String _) -> Right value
    _ -> Left "replay result does not contain a state hash"
  _ -> Left "CanonicalStateHash expects current or a replay result"

eventBatchesObservation :: ObservationInput -> V1State -> Either Text Value
eventBatchesObservation _ = Right . toJSON . kernelEventBatches

adapterTraceObservation :: ObservationInput -> V1State -> Either Text Value
adapterTraceObservation _ state = do
  replayed <- mapKernelError (replayAll (kernelEventBatches state))
  pure (toJSON (replayResultExternalTrace replayed))

replaySideEffectTraceObservation ::
  ObservationInput -> V1State -> Either Text Value
replaySideEffectTraceObservation _ state = do
  replayed <- mapKernelError (replayAll (kernelEventBatches state))
  when (not (null (replayResultExternalTrace replayed)))
    (Left "canonical replay produced an external side effect")
  pure (object
    [ "clock_reads" .= (0 :: Integer)
    , "random_reads" .= (0 :: Integer)
    , "network_calls" .= (0 :: Integer)
    , "pack_invocations" .= (0 :: Integer)
    ])

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
    Just response -> Right (Interaction.operationalResponseProjection response)
    Nothing -> Right (object
      [ "ok" .= False
      , "human" .= ("no kernel command selected" :: Text)
      , "changed" .= ([] :: [Text])
      , "warnings" .= ([] :: [Text])
      , "error_code" .= ("no_operational_response" :: Text)
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

optionalBoolean :: Text -> Object -> Maybe Bool
optionalBoolean field values = KeyMap.lookup (Key.fromText field) values >>= \value ->
  case fromJSON value of
    Success boolean -> Just boolean
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

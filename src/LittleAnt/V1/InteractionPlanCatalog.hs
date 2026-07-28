{-# LANGUAGE DerivingStrategies #-}

-- | Allium conformance probes for revision-scoped interactions.  Every probe
-- executes the real transition or parser named by its semantic construct.
module LittleAnt.V1.InteractionPlanCatalog
  ( interactionPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson
  (FromJSON, Object, Result (..), ToJSON, Value (..), fromJSON, object,
   toJSON, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.V1.Contract (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Interaction
import LittleAnt.V1.Kernel
  (DomainRevision (..), emptyKernelState, kernelRevision)

interactionPlanProbes :: Map ProbeKey PlanProbe
interactionPlanProbes = Map.fromList
  ( valueRegistrations
  <> contractRegistrations
  <> enumRegistrations
  <> entityRegistrations
  <> transitionRegistrations
  <> ruleRegistrations
  <> invariantRegistrations
  )

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations = concat
  [ valueType "InteractionAction" sampleAction
      ["id", "label", "shortcut", "canonical_command", "destructive",
       "confirmation_required"]
  , valueType "InteractionProgress" sampleProgress
      ["facts", "estimated_remaining_min", "estimated_remaining_max"]
  , valueType "InteractionEnvelope" sampleEnvelope
      ["protocol_version", "interaction_id", "domain_revision",
       "interaction_revision", "kind", "prompt", "subject", "actions", "help",
       "progress"]
  , valueType "OperationalResponse" sampleResponse
      ["ok", "human", "result_kind", "entity", "changed", "warnings",
       "error_code", "hint", "dry_run", "domain_revision"]
  , valueType "StatusSummary" sampleStatus
      ["human", "mode", "powered_by", "current_focus", "human_wip_count",
       "open_proposal_count", "pending_notice_count"]
  ]
  where
    valueType construct value fields =
      [ registration "value_equality" construct $ do
          require (toJSON value /= Null)
            (construct <> " encoded to an untyped null")
          roundTrip construct value
      , registration "entity_fields" construct $ do
          encoded <- asObject construct (toJSON value)
          requireFields construct fields encoded
          roundTrip construct value
      ]

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "InteractionProtocol.current"
      interactionCurrentProbe
  , registration "contract_signature" "InteractionProtocol.submit"
      currentActionProbe
  , registration "contract_signature" "StatusProvider.status"
      poweredUpRulesProbe
  , registration "contract_signature" "PoweredUpModel.request_via_stdin"
      poweredUpContractProbe
  ]

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ enumRegistration "InteractionStatus"
      [InteractionOpen, InteractionStale, InteractionCompleted,
       InteractionAbandoned]
  , enumRegistration "ProjectionKind"
      [ProjectionSummary, ProjectionOperational, ProjectionRelationships,
       ProjectionHistory, ProjectionComplete]
  , enumRegistration "HarnessMode" [Dumb, PoweredUp]
  ]

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ registration "entity_fields" "DomainClock" domainClockProbe
  , registration "entity_fields" "InteractionSession" interactionEntityProbe
  , registration "entity_optional" "InteractionSession.subject_brick"
      interactionEntityProbe
  , registration "entity_optional" "InteractionSession.subject_raw"
      interactionEntityProbe
  , registration "entity_optional" "InteractionSession.random_evidence"
      interactionEntityProbe
  , registration "entity_fields" "SurfaceCheckpoint" checkpointEntityProbe
  ]
  <> [registration "entity_optional" field checkpointEntityProbe
      | field <-
          [ "SurfaceCheckpoint.interaction_id"
          , "SurfaceCheckpoint.displayed_interaction_revision"
          , "SurfaceCheckpoint.selected_item"
          , "SurfaceCheckpoint.text_buffer"
          , "SurfaceCheckpoint.cursor_offset"
          , "SurfaceCheckpoint.last_response"
          , "SurfaceCheckpoint.last_status"
          , "SurfaceCheckpoint.last_projection"
          , "SurfaceCheckpoint.history_query"
          , "SurfaceCheckpoint.last_history_page"
          , "SurfaceCheckpoint.last_history_brief"
          ]]
  <> [ registration "entity_fields" "ReplRuntime" replEntityProbe
     , registration "entity_optional" "ReplRuntime.powered_by" replEntityProbe
     , registration "entity_optional" "ReplRuntime.adapter_protocol"
         replEntityProbe
     ]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [ registration category "InteractionSession.status" interactionTransitionsProbe
  | category <- ["transition_edge", "transition_rejected", "transition_terminal"]
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ categories "InteractionOpened" interactionOpenedProbe
      ["rule_success", "rule_entity_creation"]
  , categories "CurrentInteractionActionAccepted" currentActionProbe
      ["rule_success", "rule_failure"]
  , categories "StaleInteractionActionRejected" staleActionProbe
      ["rule_success", "rule_failure"]
  , categories "StaleInteractionRebased" rebaseProbe
      ["rule_success", "rule_failure"]
  , categories "InteractionHelpRequested" interactionHelpProbe
      ["rule_success", "rule_failure"]
  , categories "InteractionCompleted" completeProbe
      ["rule_success", "rule_failure"]
  , categories "InteractionAbandoned" abandonProbe
      ["rule_success", "rule_failure"]
  , categories "SurfaceCheckpointSavedFirstTime" checkpointRulesProbe
      ["rule_success", "rule_failure", "rule_entity_creation"]
  , categories "ExistingSurfaceCheckpointUpdated" checkpointRulesProbe
      ["rule_success", "rule_failure"]
  , categories "PoweredUpAdapterValidated" poweredUpRulesProbe
      ["rule_success", "rule_failure"]
  , categories "PoweredUpAdapterRejected" poweredUpRulesProbe
      ["rule_success", "rule_failure"]
  , categories "PoweredUpModeDisabled" poweredUpRulesProbe
      ["rule_success", "rule_failure"]
  ]
  where
    categories construct probe = map
      (\category -> registration category construct probe)

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" "OneCheckpointPerSurface" checkpointRulesProbe
  , registration "invariant" "HonestProgress" honestProgressProbe
  ]

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct probe =
  ( ProbeKey "interaction" category construct
  , \input -> do
      checkMetadata category construct input
      probe
  )

enumRegistration :: ToJSON value => Text -> [value] -> (ProbeKey, PlanProbe)
enumRegistration construct values = registration "enum_comparable" construct $ do
  let encoded = map toJSON values
  require (Set.size (Set.fromList encoded) == length encoded)
    (construct <> " enum values are not uniquely comparable")
  require (all canonicalEnum encoded)
    (construct <> " enum values are not canonical English text")
  where
    canonicalEnum (String value) = value == Text.toLower value
    canonicalEnum _ = False

------------------------------------------------------------
-- Real behavior probes
------------------------------------------------------------

domainClockProbe :: Either Text ()
domainClockProbe = do
  let authoritativeRevision = kernelRevision emptyKernelState
      encoded = object ["revision" .= authoritativeRevision]
  fields <- asObject "DomainClock" encoded
  requireFields "DomainClock" ["revision"] fields
  require (authoritativeRevision == DomainRevision 0)
    "authoritative kernel DomainClock did not begin at revision zero"
  require
    (KeyMap.lookup "revision" fields == Just (toJSON authoritativeRevision))
    "DomainClock projection did not contain the authoritative kernel revision"

interactionOpenedProbe :: Either Text ()
interactionOpenedProbe = do
  (session, state) <- mapInteractionError (openInteraction
    "priority_comparison" (Just "brick-1") (Just "raw-1")
    (Just "seed-1") sampleTime 7 emptyInteractionState)
  require (interactionSessionStatus session == InteractionOpen)
    "new interaction did not start open"
  require (interactionSessionDomainRevision session == 7
      && interactionSessionInteractionRevision session == 1)
    "new interaction captured the wrong revisions"
  require (interactionSessionConfirmedActions session == 0)
    "new interaction fabricated a confirmed action"
  require (Map.lookup (interactionSessionId session)
      (interactionStateSessions state) == Just session)
    "new InteractionSession was not retained"
  case openInteraction " " Nothing Nothing Nothing sampleTime 0
      emptyInteractionState of
    Left EmptyInteractionKind -> Right ()
    result -> Left ("empty interaction kind was accepted: " <> Text.pack (show result))

interactionCurrentProbe :: Either Text ()
interactionCurrentProbe = do
  (session, state) <- sampleOpen
  envelope <- mapInteractionError
    (currentInteraction (interactionSessionId session) state)
  require (interactionEnvelopeInteractionId envelope == interactionSessionId session
      && interactionEnvelopeDomainRevision envelope == 0
      && interactionEnvelopeInteractionRevision envelope == 1)
    "current interaction envelope was not scoped to its session revisions"
  require (map interactionActionId (interactionEnvelopeActions envelope)
      == ["yes", "no", "skip"])
    "current interaction inferred actions outside its canonical kind"

currentActionProbe :: Either Text ()
currentActionProbe = do
  (session, state) <- sampleOpen
  let identifier = interactionSessionId session
  (action, response, accepted) <- mapInteractionError
    (acceptCurrentInteractionAction identifier 0 1 0 "yes" sampleTime state)
  acceptedSession <- lookupInteraction identifier accepted
  require (interactionActionId action == "yes")
    "accepted a label or shortcut instead of canonical action identity"
  require (operationalResponseOk response
      && operationalResponseDomainRevision response == 1)
    "current action did not return its committed domain revision"
  require (interactionSessionDomainRevision acceptedSession == 1
      && interactionSessionInteractionRevision acceptedSession == 2
      && interactionSessionConfirmedActions acceptedSession == 1)
    "accepted action did not advance domain and interaction revisions once"
  require (interactionSessionPromptKey acceptedSession
      /= interactionSessionPromptKey session)
    "accepted action reused a previous prompt key"
  -- Every requires clause is reached independently: open status, displayed
  -- versus clock, displayed versus session, interaction revision, and action ID.
  (_, completedState) <- mapInteractionError
    (completeInteraction identifier sampleTime state)
  expectNotOpen (classifyInteractionSubmission identifier 0 1 0 "yes"
    sampleTime completedState)
  expectStale (classifyInteractionSubmission identifier 0 1 1 "yes"
    sampleTime state)
  expectStale (classifyInteractionSubmission identifier 1 1 1 "yes"
    sampleTime state)
  expectStale (classifyInteractionSubmission identifier 0 2 0 "yes"
    sampleTime state)
  expectStale (classifyInteractionSubmission identifier 0 1 0 "unknown"
    sampleTime state)

staleActionProbe :: Either Text ()
staleActionProbe = do
  (session, state) <- sampleOpen
  let identifier = interactionSessionId session
      staleCases =
        [ classifyInteractionSubmission identifier 0 1 1 "yes" sampleTime state
        , classifyInteractionSubmission identifier 1 1 1 "yes" sampleTime state
        , classifyInteractionSubmission identifier 0 2 0 "yes" sampleTime state
        , classifyInteractionSubmission identifier 0 1 0 "renamed-label"
            sampleTime state
        ]
  mapM_ expectStaleWithoutConfirmation staleCases
  decision <- mapInteractionError
    (classifyInteractionSubmission identifier 0 1 0 "yes" sampleTime state)
  case decision of
    CurrentSubmission _ -> Right ()
    _ -> Left "current valid action incorrectly witnessed stale rejection"
  (_, completed) <- mapInteractionError
    (completeInteraction identifier sampleTime state)
  expectNotOpen (classifyInteractionSubmission identifier 0 1 0 "yes"
    sampleTime completed)

rebaseProbe :: Either Text ()
rebaseProbe = do
  (session, state) <- sampleOpen
  stale <- staleStateFor session state
  (rebased, next) <- mapInteractionError
    (rebaseInteraction (interactionSessionId session) 4 sampleTime stale)
  require (interactionSessionStatus rebased == InteractionOpen
      && interactionSessionDomainRevision rebased == 4
      && interactionSessionInteractionRevision rebased == 2)
    "stale interaction was not independently rebased"
  require (interactionSessionConfirmedActions rebased == 0)
    "rebase invented a confirmed domain action"
  case rebaseInteraction (interactionSessionId session) 4 sampleTime next of
    Left (InteractionIsNotStale _ InteractionOpen) -> Right ()
    result -> Left ("open interaction rebased without staleness: "
      <> Text.pack (show result))

interactionHelpProbe :: Either Text ()
interactionHelpProbe = do
  (session, state) <- sampleOpen
  before <- mapInteractionError (currentInteraction (interactionSessionId session) state)
  after <- mapInteractionError
    (requestInteractionHelp (interactionSessionId session) state)
  require (after == before) "help changed the pending prompt or its revisions"
  require (interactionEnvelopeDomainRevision after
      == interactionSessionDomainRevision session
      && interactionEnvelopeInteractionRevision after
        == interactionSessionInteractionRevision session)
    "help advanced a domain or interaction revision"
  (_, completed) <- mapInteractionError
    (completeInteraction (interactionSessionId session) sampleTime state)
  case requestInteractionHelp (interactionSessionId session) completed of
    Left (InteractionIsNotOpen _ InteractionCompleted) -> Right ()
    result -> Left ("terminal interaction returned help: " <> Text.pack (show result))

completeProbe :: Either Text ()
completeProbe = do
  (session, state) <- sampleOpen
  (completed, next) <- mapInteractionError
    (completeInteraction (interactionSessionId session) sampleTime state)
  require (interactionSessionStatus completed == InteractionCompleted)
    "open interaction did not complete"
  case completeInteraction (interactionSessionId session) sampleTime next of
    Left (InteractionIsNotOpen _ InteractionCompleted) -> Right ()
    result -> Left ("completed interaction transitioned again: "
      <> Text.pack (show result))

abandonProbe :: Either Text ()
abandonProbe = do
  (openSession, openState) <- sampleOpen
  (abandonedOpen, terminalOpen) <- mapInteractionError
    (abandonInteraction (interactionSessionId openSession) sampleTime openState)
  require (interactionSessionStatus abandonedOpen == InteractionAbandoned)
    "open interaction was not abandoned"
  (staleSession, staleBase) <- sampleOpen
  stale <- staleStateFor staleSession staleBase
  (abandonedStale, _) <- mapInteractionError
    (abandonInteraction (interactionSessionId staleSession) sampleTime stale)
  require (interactionSessionStatus abandonedStale == InteractionAbandoned)
    "stale interaction was not abandoned"
  case abandonInteraction (interactionSessionId openSession) sampleTime terminalOpen of
    Left (InteractionIsTerminal _) -> Right ()
    result -> Left ("terminal interaction was abandoned twice: "
      <> Text.pack (show result))

interactionTransitionsProbe :: Either Text ()
interactionTransitionsProbe = do
  -- open -> stale -> open, open -> completed, open -> abandoned, and
  -- stale -> abandoned are all exercised by their public witnessing rules.
  rebaseProbe
  completeProbe
  abandonProbe
  (session, state) <- sampleOpen
  (_, terminal) <- mapInteractionError
    (completeInteraction (interactionSessionId session) sampleTime state)
  case rebaseInteraction (interactionSessionId session) 0 sampleTime terminal of
    Left (InteractionIsNotStale _ InteractionCompleted) -> Right ()
    result -> Left ("terminal state had an outbound edge: " <> Text.pack (show result))

checkpointRulesProbe :: Either Text ()
checkpointRulesProbe = do
  let initialDraft = sampleCheckpointDraft
        { checkpointDraftSelectedItem = Nothing
        , checkpointDraftTextBuffer = Nothing
        , checkpointDraftCursorOffset = Nothing
        , checkpointDraftLastResponse = Nothing
        , checkpointDraftLastStatus = Nothing
        , checkpointDraftLastProjection = Nothing
        , checkpointDraftHistoryQuery = Nothing
        , checkpointDraftLastHistoryPage = Nothing
        , checkpointDraftLastHistoryBrief = Nothing
        }
  (first, firstState) <- mapInteractionError
    (saveFirstSurfaceCheckpoint initialDraft sampleTime emptyInteractionState)
  require (Map.size (interactionStateCheckpoints firstState) == 1)
    "first checkpoint did not establish one surface record"
  require (surfaceCheckpointSelectedItem first == Nothing
      && surfaceCheckpointTextBuffer first == Nothing)
    "first checkpoint did not retain optional presentation absence"
  case saveFirstSurfaceCheckpoint initialDraft sampleTime firstState of
    Left (CheckpointAlreadyExists "terminal") -> Right ()
    result -> Left ("second first checkpoint was accepted: " <> Text.pack (show result))
  let updatedDraft = sampleCheckpointDraft
      later = addUTCTime 1 sampleTime
  (updated, updatedState) <- mapInteractionError
    (saveExistingSurfaceCheckpoint updatedDraft later firstState)
  require (surfaceCheckpointId updated == surfaceCheckpointId first)
    "checkpoint update replaced surface identity"
  require (Map.size (interactionStateCheckpoints updatedState) == 1)
    "checkpoint update created a second surface record"
  require (surfaceCheckpointSelectedItem updated == Just "row-3"
      && surfaceCheckpointTextBuffer updated == Just "unsubmitted text"
      && surfaceCheckpointCursorOffset updated == Just 7
      && surfaceCheckpointLastResponse updated == Just sampleResponse
      && surfaceCheckpointLastStatus updated == Just sampleStatus
      && surfaceCheckpointLastProjection updated == Just ProjectionHistory
      && surfaceCheckpointHistoryQuery updated == Just sampleHistoryQuery
      && surfaceCheckpointLastHistoryPage updated == Just sampleHistoryPage
      && surfaceCheckpointLastHistoryBrief updated == Just sampleHistoryBrief)
    "checkpoint did not restore selection, edit, response, status, projection, or history"
  case saveExistingSurfaceCheckpoint updatedDraft later emptyInteractionState of
    Left (CheckpointDoesNotExist "terminal") -> Right ()
    result -> Left ("missing checkpoint updated: " <> Text.pack (show result))

poweredUpContractProbe :: Either Text ()
poweredUpContractProbe = do
  let request = "bounded model probe"
      invocation = poweredUpInvocation "/opt/lant/model" request
  require (null (poweredUpInvocationArguments invocation))
    "powered-up request used process arguments"
  require (poweredUpInvocationStdin invocation == request)
    "powered-up request was not carried intact through stdin"
  either (Left . Text.pack . show) Right (parsePoweredUpProbe
    "prefix {\"protocol_version\":1,\"status\":\"OK\"} suffix")
  expectPoweredFailure PoweredUpOutputMissing (parsePoweredUpProbe "no object")
  expectPoweredFailure PoweredUpOutputAmbiguous (parsePoweredUpProbe
    "{\"protocol_version\":1,\"status\":\"OK\"}{\"protocol_version\":1,\"status\":\"OK\"}")
  expectAnyPoweredFailure (parsePoweredUpProbe "{not json}")
  expectPoweredFailure PoweredUpOutputUnsupported (parsePoweredUpProbe
    "{\"protocol_version\":2,\"status\":\"OK\"}")
  expectPoweredFailure PoweredUpOutputUnsupported (parsePoweredUpProbe
    "{\"protocol_version\":1,\"status\":\"NO\"}")

poweredUpRulesProbe :: Either Text ()
poweredUpRulesProbe = do
  let ambiguous = "Here {\"status\":\"OK\"} then {\"status\":\"NO\"}"
      (rejected, rejectedResponse, rejectedState) = validatePoweredUpAdapter
        "/tmp/broken" "stdin" ambiguous emptyInteractionState
  require (case rejected of PoweredUpRejected _ -> True; _ -> False)
    "ambiguous powered-up output did not fail startup"
  require (not (operationalResponseOk rejectedResponse)
      && replRuntimeMode (interactionStateReplRuntime rejectedState) == Dumb)
    "invalid adapter silently entered powered-up mode"
  let valid = "{\"protocol_version\":1,\"status\":\"OK\"}"
      (accepted, acceptedResponse, powered) = validatePoweredUpAdapter
        "/opt/lant/model" "stdin" valid emptyInteractionState
      runtime = interactionStateReplRuntime powered
      summary = statusSummary Nothing 0 0 0 powered
  require (accepted == PoweredUpAccepted && operationalResponseOk acceptedResponse)
    "valid powered-up adapter was rejected"
  require (runtime == ReplRuntime PoweredUp (Just "/opt/lant/model") (Just 1))
    "validated runtime omitted its exact adapter identity"
  require (statusSummaryMode summary == "powered_up"
      && statusSummaryPoweredBy summary == Just "/opt/lant/model")
    "canonical status did not expose validated powered-up mode"
  trace <- maybe (Left "powered-up process trace was not recorded") Right
    (Map.lookup "/opt/lant/model" (interactionStateProcessTraces powered))
  require (processInvocationTraceArgumentCount trace == 0
      && not (processInvocationTraceArgumentsContainPrompt trace)
      && processInvocationTraceStdinContainsProbe trace
      && not (processInvocationTraceSecretValuesRecorded trace))
    "powered-up process trace exposed prompt arguments or secret values"
  dumb <- mapInteractionError (useDumbMode powered)
  require (interactionStateReplRuntime dumb == ReplRuntime Dumb Nothing Nothing)
    "dumb mode retained powered-up authority"
  case useDumbMode dumb of
    Left PoweredUpModeIsNotEnabled -> Right ()
    result -> Left ("dumb mode was disabled twice: " <> Text.pack (show result))
  let (transportRejected, _, transportState) = validatePoweredUpAdapter
        "/opt/lant/model" "argv" valid emptyInteractionState
  require (transportRejected == PoweredUpRejected PoweredUpTransportMustBeStdin
      && replRuntimeMode (interactionStateReplRuntime transportState) == Dumb)
    "non-stdin transport passed powered-up validation"

honestProgressProbe :: Either Text ()
honestProgressProbe = do
  (session, state) <- sampleOpen
  let before = honestInteractionProgress session
  require (interactionProgressFacts before == ["0 confirmed actions"])
    "progress credited unconfirmed work"
  _ <- mapInteractionError (requestInteractionHelp (interactionSessionId session) state)
  let afterHelp = honestInteractionProgress session
  require (afterHelp == before) "help changed progress"
  (_, _, accepted) <- mapInteractionError (acceptCurrentInteractionAction
    (interactionSessionId session) 0 1 0 "yes" sampleTime state)
  acceptedSession <- lookupInteraction (interactionSessionId session) accepted
  let afterAccepted = honestInteractionProgress acceptedSession
  require (interactionProgressFacts afterAccepted == ["1 confirmed action"])
    "progress did not report the one confirmed canonical action"
  decision <- mapInteractionError (classifyInteractionSubmission
    (interactionSessionId session) 0 1 1 "yes" sampleTime state)
  case decision of
    StaleSubmission _ stale -> do
      staleSession <- lookupInteraction (interactionSessionId session) stale
      require (interactionProgressFacts (honestInteractionProgress staleSession)
          == ["0 confirmed actions"])
        "stale action increased honest progress"
    _ -> Left "stale progress probe unexpectedly accepted an action"
  require (interactionProgressEstimatedRemainingMin afterAccepted
      <= interactionProgressEstimatedRemainingMax afterAccepted)
    "adaptive estimated progress range is incoherent"

interactionEntityProbe :: Either Text ()
interactionEntityProbe = do
  (present, _) <- mapInteractionError (openInteraction "priority_comparison"
    (Just "brick-1") (Just "raw-1") (Just "seed") sampleTime 3
    emptyInteractionState)
  presentFields <- asObject "InteractionSession" (toJSON present)
  requireFields "InteractionSession"
    [ "id", "kind", "subject_brick", "subject_raw", "status",
      "domain_revision", "interaction_revision", "prompt_key",
      "random_evidence", "confirmed_actions", "opened_at", "updated_at"]
    presentFields
  (absent, _) <- mapInteractionError (openInteraction "priority_comparison"
    Nothing Nothing Nothing sampleTime 0 emptyInteractionState)
  absentFields <- asObject "InteractionSession optional" (toJSON absent)
  mapM_ (requireNull absentFields)
    ["subject_brick", "subject_raw", "random_evidence"]
  require (all (/= Just Null)
      [ KeyMap.lookup "subject_brick" presentFields
      , KeyMap.lookup "subject_raw" presentFields
      , KeyMap.lookup "random_evidence" presentFields
      ]) "InteractionSession optionals rejected non-null values"
  roundTrip "InteractionSession" present

checkpointEntityProbe :: Either Text ()
checkpointEntityProbe = do
  (present, _) <- mapInteractionError
    (saveFirstSurfaceCheckpoint sampleCheckpointDraft sampleTime
      emptyInteractionState)
  presentFields <- asObject "SurfaceCheckpoint" (toJSON present)
  requireFields "SurfaceCheckpoint"
    [ "id", "surface_id", "interaction_id", "displayed_domain_revision",
      "displayed_interaction_revision", "screen", "selected_item", "text_buffer",
      "cursor_offset", "transcript", "last_response", "last_status",
      "last_projection", "history_query", "last_history_page",
      "last_history_brief", "updated_at"] presentFields
  let absentDraft = sampleCheckpointDraft
        { checkpointDraftInteractionId = Nothing
        , checkpointDraftDisplayedInteractionRevision = Nothing
        , checkpointDraftSelectedItem = Nothing
        , checkpointDraftTextBuffer = Nothing
        , checkpointDraftCursorOffset = Nothing
        , checkpointDraftLastResponse = Nothing
        , checkpointDraftLastStatus = Nothing
        , checkpointDraftLastProjection = Nothing
        , checkpointDraftHistoryQuery = Nothing
        , checkpointDraftLastHistoryPage = Nothing
        , checkpointDraftLastHistoryBrief = Nothing
        }
  (absent, _) <- mapInteractionError
    (saveFirstSurfaceCheckpoint absentDraft sampleTime emptyInteractionState)
  absentFields <- asObject "SurfaceCheckpoint optional" (toJSON absent)
  mapM_ (requireNull absentFields)
    [ "interaction_id", "displayed_interaction_revision", "selected_item",
      "text_buffer", "cursor_offset", "last_response", "last_status",
      "last_projection", "history_query", "last_history_page",
      "last_history_brief"]
  roundTrip "SurfaceCheckpoint" present

replEntityProbe :: Either Text ()
replEntityProbe = do
  let dumb = ReplRuntime Dumb Nothing Nothing
      powered = ReplRuntime PoweredUp (Just "/opt/lant/model") (Just 1)
  dumbFields <- asObject "dumb ReplRuntime" (toJSON dumb)
  poweredFields <- asObject "powered ReplRuntime" (toJSON powered)
  requireFields "ReplRuntime" ["mode", "powered_by", "adapter_protocol"] dumbFields
  mapM_ (requireNull dumbFields) ["powered_by", "adapter_protocol"]
  require (KeyMap.lookup "powered_by" poweredFields
      == Just (String "/opt/lant/model")
      && KeyMap.lookup "adapter_protocol" poweredFields == Just (toJSON (1 :: Integer)))
    "ReplRuntime optionals rejected validated non-null values"
  roundTrip "ReplRuntime" powered

------------------------------------------------------------
-- Probe fixtures and helpers
------------------------------------------------------------

sampleOpen :: Either Text (InteractionSession, InteractionState)
sampleOpen = mapInteractionError (openInteraction "priority_comparison" Nothing
  Nothing (Just "seed") sampleTime 0 emptyInteractionState)

staleStateFor ::
  InteractionSession -> InteractionState -> Either Text InteractionState
staleStateFor session state = do
  decision <- mapInteractionError (classifyInteractionSubmission
    (interactionSessionId session) 0 2 0 "yes" sampleTime state)
  case decision of
    StaleSubmission _ stale -> Right stale
    _ -> Left "failed to construct stale interaction fixture"

lookupInteraction :: InteractionId -> InteractionState -> Either Text InteractionSession
lookupInteraction identifier state = maybe (Left "interaction disappeared") Right
  (Map.lookup identifier (interactionStateSessions state))

expectStale :: Either InteractionError SubmissionDecision -> Either Text ()
expectStale result = do
  decision <- mapInteractionError result
  case decision of
    StaleSubmission response _ -> require
      (operationalResponseErrorCode response == Just "stale_interaction")
      "stale action returned the wrong structured rejection"
    CurrentSubmission _ -> Left "stale action was accepted"

expectStaleWithoutConfirmation ::
  Either InteractionError SubmissionDecision -> Either Text ()
expectStaleWithoutConfirmation result = do
  decision <- mapInteractionError result
  case decision of
    StaleSubmission response state -> do
      require (operationalResponseErrorCode response == Just "stale_interaction")
        "stale action returned the wrong error code"
      let sessions = Map.elems (interactionStateSessions state)
      require (all ((== 0) . interactionSessionConfirmedActions) sessions)
        "stale action mutated confirmed domain progress"
    CurrentSubmission _ -> Left "stale action was accepted"

expectNotOpen :: Either InteractionError SubmissionDecision -> Either Text ()
expectNotOpen result = case result of
  Left (InteractionIsNotOpen _ _) -> Right ()
  _ -> Left ("non-open interaction reached submission: " <> Text.pack (show result))

expectPoweredFailure ::
  PoweredUpError -> Either PoweredUpError () -> Either Text ()
expectPoweredFailure expected result = case result of
  Left actual | actual == expected -> Right ()
  _ -> Left ("unexpected powered-up parse result: " <> Text.pack (show result))

expectAnyPoweredFailure :: Either PoweredUpError () -> Either Text ()
expectAnyPoweredFailure result = case result of
  Left _ -> Right ()
  Right () -> Left "invalid powered-up output was accepted"

sampleAction :: InteractionAction
sampleAction = InteractionAction "yes" "Yes" "y"
  "la interaction submit interaction-0 yes" False False

sampleProgress :: InteractionProgress
sampleProgress = InteractionProgress ["1 confirmed action"] (Just 0) (Just 2)

sampleEnvelope :: InteractionEnvelope
sampleEnvelope = InteractionEnvelope 1 (InteractionId "interaction-0") 1 2
  "priority_comparison" "Choose" Nothing [sampleAction] (Just "Help")
  (Just sampleProgress)

sampleResponse :: OperationalResponse
sampleResponse = OperationalResponse True "Accepted" (Just "interaction_action")
  Nothing ["domain"] [] Nothing Nothing Nothing 1

sampleStatus :: StatusSummary
sampleStatus = StatusSummary "mode: powered up · by: /opt/lant/model"
  "powered_up" (Just "/opt/lant/model") Nothing 0 0 0

sampleHistoryQuery :: Value
sampleHistoryQuery = object
  ["page_size" .= (20 :: Integer), "brick_ids" .= (["brick-1"] :: [Text])]

sampleHistoryPage :: Value
sampleHistoryPage = object
  ["snapshot_domain_revision" .= (3 :: Integer), "items" .= ([] :: [Value])]

sampleHistoryBrief :: Value
sampleHistoryBrief = object
  ["snapshot_domain_revision" .= (3 :: Integer), "facts" .= (["one"] :: [Text])]

sampleCheckpointDraft :: SurfaceCheckpointDraft
sampleCheckpointDraft = SurfaceCheckpointDraft
  { checkpointDraftSurfaceId = "terminal"
  , checkpointDraftInteractionId = Just (InteractionId "interaction-0")
  , checkpointDraftDisplayedDomainRevision = 3
  , checkpointDraftDisplayedInteractionRevision = Just 2
  , checkpointDraftScreen = "history"
  , checkpointDraftSelectedItem = Just "row-3"
  , checkpointDraftTextBuffer = Just "unsubmitted text"
  , checkpointDraftCursorOffset = Just 7
  , checkpointDraftTranscript = ["prompt", "answer"]
  , checkpointDraftLastResponse = Just sampleResponse
  , checkpointDraftLastStatus = Just sampleStatus
  , checkpointDraftLastProjection = Just ProjectionHistory
  , checkpointDraftHistoryQuery = Just sampleHistoryQuery
  , checkpointDraftLastHistoryPage = Just sampleHistoryPage
  , checkpointDraftLastHistoryBrief = Just sampleHistoryBrief
  }

sampleTime :: UTCTime
sampleTime = UTCTime (fromGregorian 2026 7 27) 0

checkMetadata :: Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata expectedCategory expectedConstruct input = do
  require (planProbeModule input == "interaction")
    "interaction probe received another module"
  require (planProbeCategory input == expectedCategory)
    "interaction probe received another category"
  require (planProbeSourceConstruct input == expectedConstruct)
    "interaction probe received another semantic construct"

requireFields :: Text -> [Text] -> Object -> Either Text ()
requireFields construct fields objectValue = require
  (all (\field -> KeyMap.member (Key.fromText field) objectValue) fields)
  (construct <> " projection omits declared fields")

requireNull :: Object -> Text -> Either Text ()
requireNull fields field = require
  (KeyMap.lookup (Key.fromText field) fields == Just Null)
  (field <> " did not accept null")

roundTrip :: (Eq value, ToJSON value, FromJSON value) =>
  Text -> value -> Either Text ()
roundTrip construct value = case fromJSON (toJSON value) of
  Success decoded -> require (decoded == value)
    (construct <> " lost typed fields during JSON round-trip")
  Error problem -> Left (construct <> " failed typed decode: " <> Text.pack problem)

asObject :: Text -> Value -> Either Text Object
asObject construct value = case value of
  Object fields -> Right fields
  _ -> Left (construct <> " did not encode as an object")

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

mapInteractionError :: Either InteractionError value -> Either Text value
mapInteractionError = either (Left . Text.pack . show) Right

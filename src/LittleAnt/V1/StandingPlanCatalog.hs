{-# LANGUAGE DerivingStrategies #-}

-- | Semantic Allium probes for execution occurrences and recurrence.
-- Registrations are selected only by module/category/construct metadata; each
-- probe drives the real typed state transitions and invariant validator.
module LittleAnt.V1.StandingPlanCatalog
  ( standingPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson (encode, toJSON)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Coordination (coordinationStateExecution)
import LittleAnt.V1.Domain
  (Authority (Human), Brick (..), BrickBehavior, BrickDraft (..), BrickId (..),
   BrickStatus (..),
   DomainError, DomainState (..), WorkState (..), collectionV1, mkCanonicalText,
   ordinaryBrickDraft, practiceV1, recurringObligationV1,
   repeatableV1, standardV1, standingChecklistV1)
import LittleAnt.V1.Execution (ExecutionState (..))
import qualified LittleAnt.V1.Priority as Priority
import LittleAnt.V1.Standing

standingPlanProbes :: Map ProbeKey PlanProbe
standingPlanProbes = Map.fromList
  ( enumRegistrations
  <> transitionRegistrations
  <> entityRegistrations
  <> optionalRegistrations
  <> valueRegistrations
  <> ruleRegistrations
  <> invariantRegistrations
  )

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ registration "enum_comparable" construct standingShapeProbe
  | construct <-
      [ "ExecutionStatus", "ExecutionOutcome", "RecurrenceKind", "ScheduleStatus"
      , "PracticeOpportunityStatus", "OpportunityTriggerStatus"
      ]
  ]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [ registration category construct standingShapeProbe
  | (construct, categories) <-
      [ ("ExecutionOccurrence.status",
          ["transition_edge", "transition_rejected", "transition_terminal"])
      , ("RecurrenceRule.status",
          ["transition_edge", "transition_rejected", "transition_terminal"])
      , ("PracticeOpportunity.status",
          ["transition_edge", "transition_rejected", "transition_terminal"])
      , ("OpportunityTrigger.status",
          ["transition_edge", "transition_rejected", "transition_terminal"])
      ]
  , category <- categories
  ]

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ registration "entity_fields" construct standingShapeProbe
  | construct <-
      [ "ExecutionOccurrence", "RecurrenceRule", "ObligationOccurrence"
      , "RecurrenceRevision", "PracticeOpportunity", "OpportunityTrigger"
      , "TriggeredOpportunity", "PracticeHistoryView"
      ]
  ]

optionalRegistrations :: [(ProbeKey, PlanProbe)]
optionalRegistrations =
  [ registration "entity_optional" construct standingShapeProbe
  | construct <-
      [ "ExecutionOccurrence.started_at", "ExecutionOccurrence.finished_at"
      , "ExecutionOccurrence.outcome", "ExecutionOccurrence.completion_note"
      , "PracticeOpportunity.resolved_at", "PracticeOpportunity.reason"
      , "TriggeredOpportunity.consumed_at"
      ]
  ]

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations =
  [ registration "derived" "RecurrenceRule.practice_history" recurrenceProbe
  , registration "value_equality" "PracticeHistoryView" recurrenceProbe
  , registration "contract_signature" "PracticeProjection.history" recurrenceProbe
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ rules executionRules standingLifecycleProbe
  , rules recurrenceRules recurrenceProbe
  , rules triggerRules triggerProbe
  , rules ["TerminalBrickRetiresFutureStandingMechanics"] terminalMechanicsProbe
  ]
  where
    rules constructs probe =
      [registration category construct probe
      | construct <- constructs, category <- ruleCategories construct]
    ruleCategories construct
      | construct `elem`
          [ "StandingExecutionStarted", "RecurrenceConfigured"
          , "RecurrenceScheduleRevised", "PracticeOpportunityCompleted"
          , "OpportunityTriggerConfigured", "SourceExecutionReleasesOpportunity"
          , "DirectCompletionReleasesOpportunity"
          ] = ["rule_success", "rule_failure", "rule_entity_creation"]
      | construct `elem`
          [ "DueObligationsReleased", "ApplicablePracticeOpportunitiesReleased"
          , "InapplicablePracticeWindowsRecorded", "ExpiredPracticeOpportunityRecorded"
          , "TerminalBrickRetiresFutureStandingMechanics"
          ] = ["rule_success"]
      | otherwise = ["rule_success", "rule_failure"]
    executionRules =
      [ "StandingExecutionStarted", "StandingExecutionFinished"
      , "RepeatableExecutionScheduledAgain", "RepeatableExecutionRetired"
      , "RunningExecutionAbandoned"
      ]
    recurrenceRules =
      [ "RecurrenceConfigured", "RecurrencePaused", "RecurrenceResumed"
      , "RecurrenceRetired", "RecurrenceScheduleRevised", "DueObligationsReleased"
      , "ApplicablePracticeOpportunitiesReleased"
      , "InapplicablePracticeWindowsRecorded", "PracticeOpportunityCompleted"
      , "PracticeOpportunityAbandoned", "ExpiredPracticeOpportunityRecorded"
      ]
    triggerRules =
      [ "OpportunityTriggerConfigured", "SourceExecutionReleasesOpportunity"
      , "DirectCompletionReleasesOpportunity"
      , "TargetExecutionConsumesOneTriggeredOpportunity"
      , "OpportunityTriggerRetired"
      ]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" construct probe
  | (construct, probe) <-
      [ ("AtMostOneRunningExecutionPerBrick", standingLifecycleProbe)
      , ("RunningExecutionHasObservedStart", standingLifecycleProbe)
      , ("ObligationPeriodIsUnique", recurrenceProbe)
      , ("OneLiveRecurrencePerTargetAndKind", recurrenceProbe)
      , ("PracticePeriodIsUnique", recurrenceProbe)
      , ("TriggeredOpportunityIsIdempotentPerSourceEvent", triggerProbe)
      , ("PracticeOpportunityHasValidWindow", recurrenceProbe)
      , ("RepeatableHasAtMostOnePendingDate", standingLifecycleProbe)
      ]
  ]

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "execution" category construct, semanticProbe category construct probe)

semanticProbe :: Text -> Text -> Either Text () -> PlanProbe
semanticProbe category construct probe input = do
  require (planProbeModule input == "execution")
    "standing probe received the wrong module"
  require (planProbeCategory input == category)
    "standing probe received the wrong category"
  require (planProbeSourceConstruct input == construct)
    "standing probe received the wrong semantic construct"
  probe

standingShapeProbe :: Either Text ()
standingShapeProbe = do
  standingLifecycleProbe
  recurrenceProbe
  triggerProbe
  let running = ExecutionOccurrence (ExecutionOccurrenceId "shape:execution")
        (brickIdPlaceholder "shape:brick") ExecutionRunning
        (Just probeTime) Nothing Nothing Nothing
      finished = running
        { executionOccurrenceStatus = ExecutionFinished
        , executionOccurrenceFinishedAt = Just probeTime
        , executionOccurrenceOutcome = Just OutcomeDone
        , executionOccurrenceCompletionNote = Just "observed"
        }
  require (encode running /= encode finished)
    "execution transition has no structural representation"
  require (toJSON (ExecutionRunning :: ExecutionStatus) /= toJSON ExecutionFinished)
    "execution status enum encodings collide"
  require (toJSON (ObligationRecurrence :: RecurrenceKind)
      /= toJSON PracticeRecurrence)
    "recurrence kind enum encodings collide"
  require (toJSON (OpportunityOpen :: PracticeOpportunityStatus)
      /= toJSON OpportunityNotApplicable)
    "practice status enum encodings collide"
  require (toJSON (TriggerActive :: OpportunityTriggerStatus)
      /= toJSON TriggerRetired)
    "trigger status enum encodings collide"

standingLifecycleProbe :: Either Text ()
standingLifecycleProbe = do
  (standingBrick, first) <- createBrickFixture "Standing run" standingChecklistV1
    emptyStandingState
  (running, second) <- standing (startStandingExecution (brickId standingBrick)
    probeTime first)
  require (executionOccurrenceStartedAt running == Just probeTime)
    "running execution omitted its observed start"
  expectFailure (startStandingExecution (brickId standingBrick) probeTime second)
    "second running execution was accepted for one Brick"
  (finished, third) <- standing (finishStandingExecution
    (executionOccurrenceId running) OutcomePartial (Just "some items remain")
    (addUTCTime 1 probeTime) second)
  require (executionOccurrenceStatus finished == ExecutionFinished
      && executionOccurrenceOutcome finished == Just OutcomePartial)
    "standing finish did not retain its honest outcome"
  standingAfter <- lookupBrickState (brickId standingBrick) third
  require (brickStatus standingAfter == Active && brickWorkState standingAfter == Idle)
    "finishing a standing run retired it or left it WIP"
  expectFailure (finishStandingExecution (executionOccurrenceId running) OutcomeDone
    Nothing (addUTCTime 2 probeTime) third)
    "terminal execution occurrence transitioned twice"
  (abandonedRun, fourth) <- standing (startStandingExecution
    (brickId standingBrick) (addUTCTime 2 probeTime) third)
  (abandoned, _) <- standing (abandonExecution (executionOccurrenceId abandonedRun)
    (Just "interrupted") (addUTCTime 3 probeTime) fourth)
  require (executionOccurrenceStatus abandoned == ExecutionAbandoned
      && executionOccurrenceOutcome abandoned == Just OutcomeAbandoned)
    "abandonment was not distinct from a finish"
  (repeatable, repeatFirst) <- createBrickFixture "Repeat me" repeatableV1
    emptyStandingState
  (repeatRun, repeatSecond) <- standing (startStandingExecution
    (brickId repeatable) probeTime repeatFirst)
  (_, evidence, repeatThird) <- standing (finishRepeatableAndSchedule
    (executionOccurrenceId repeatRun) (Just "done") "P6M" "P3M"
    "fixed-seed" probeTime repeatSecond)
  repeatedDate <- lookupBrickState (brickId repeatable) repeatThird
  selectedAgain <- standing (deterministicRepeatDate probeTime "P6M" "P3M"
    "fixed-seed")
  require (brickNotBefore repeatedDate == Just (repeatScheduleNotBefore evidence)
      && selectedAgain == (repeatScheduleSelectedMonths evidence,
        repeatScheduleNotBefore evidence))
    "repeat schedule did not replay from pinned evidence"
  require (repeatScheduleSelectedMonths evidence >= 3
      && repeatScheduleSelectedMonths evidence <= 9)
    "repeat jitter escaped the inclusive range"
  (retiringRun, repeatFourth) <- standing (startStandingExecution
    (brickId repeatable) (repeatScheduleNotBefore evidence) repeatThird)
  (_, retired) <- standing (finishRepeatableAndRetire
    (executionOccurrenceId retiringRun) Nothing
    (addUTCTime 1 (repeatScheduleNotBefore evidence)) repeatFourth)
  retiredBrick <- lookupBrickState (brickId repeatable) retired
  require (brickStatus retiredBrick == Done)
    "repeatable terminal choice did not retire the owner"
  standing (validateStandingState retired)

recurrenceProbe :: Either Text ()
recurrenceProbe = do
  (owner, first) <- createBrickFixture "Pay electricity bill"
    recurringObligationV1 emptyStandingState
  (monthly, second) <- standing (configureRecurrence (brickId owner)
    ObligationRecurrence "monthly on day 1" "UTC" probeTime probeTime first)
  expectFailure (configureRecurrence (brickId owner) ObligationRecurrence
    "monthly on day 1" "UTC" probeTime probeTime second)
    "duplicate live recurrence was accepted"
  (august, _, third) <- standing (advanceSchedules probeTime second)
  require (length august == 1) "due obligation was not released"
  (_, _, repeated) <- standing (advanceSchedules probeTime third)
  require (length (obligationOccurrencesFor (recurrenceRuleId monthly) Nothing repeated)
      == 1) "same obligation period was released twice"
  let firstOccurrence = headSafe august
  occurrence <- maybe (Left "released obligation is absent") Right firstOccurrence
  occurrenceBrick <- lookupBrickState (obligationOccurrenceBrick occurrence) repeated
  require (brickParent occurrenceBrick == Just (brickId owner))
    "obligation occurrence is not a distinct child of its owner"
  view <- priority (Priority.priorityViewItem
    (executionStatePriority (coordinationStateExecution
      (standingStateCoordination repeated))) (brickId occurrenceBrick))
  require (Priority.priorityViewItemProvisional view)
    "released obligation was not provisionally positioned"
  completed <- standing (completeStandingBrick (brickId occurrenceBrick)
    (Just "paid") "probe:paid" probeTime repeated)
  ownerAfter <- lookupBrickState (brickId owner) completed
  require (brickStatus ownerAfter == Active)
    "completing an obligation retired its standing owner"
  (practiceBrick, practiceFirst) <- createBrickFixture "Swim twice per week"
    practiceV1 completed
  (practiceRule, practiceSecond) <- standing (configureRecurrence
    (brickId practiceBrick) PracticeRecurrence "2 times per ISO week" "UTC"
    probeTime probeTime practiceFirst)
  (_, opportunities, practiceThird) <- standing
    (advanceSchedules probeTime practiceSecond)
  case opportunities of
    firstOpportunity : secondOpportunity : [] -> do
      (done, directExecution, practiceFourth) <- standing
        (completePracticeOpportunity (practiceOpportunityId firstOpportunity)
          (Just "swam") probeTime practiceThird)
      require (practiceOpportunityStatus done == OpportunityDone
          && executionOccurrenceStartedAt directExecution == Nothing)
        "direct practice completion invented an observed start"
      (_, practiceFifth) <- standing
        (abandonPracticeOpportunity (practiceOpportunityId secondOpportunity)
          (Just "cold") probeTime practiceFourth)
      history <- standing (practiceHistory (recurrenceRuleId practiceRule)
        Nothing 20 practiceFifth)
      require (practiceHistoryMarks history == ["x", "-"]
          && practiceHistoryNotDoneCount history == 1)
        "practice history did not derive honest marks"
      (_, paused) <- standing (pauseRecurrence (recurrenceRuleId practiceRule)
        probeTime practiceFifth)
      (_, resumed) <- standing (resumeRecurrence (recurrenceRuleId practiceRule)
        (addUTCTime week probeTime) paused)
      (revision, revised) <- standing (reviseRecurrence
        (recurrenceRuleId practiceRule) "2 times per ISO week" "UTC"
        (addUTCTime week probeTime) "new pool" Human probeTime resumed)
      require (recurrenceRevisionRule revision == recurrenceRuleId practiceRule
          && Map.size (standingStatePracticeOpportunities revised) == 2)
        "recurrence revision changed identity or rewrote history"
      (_, retired) <- standing (retireRecurrence (recurrenceRuleId practiceRule)
        probeTime revised)
      expectFailure (resumeRecurrence (recurrenceRuleId practiceRule)
        probeTime retired) "retired recurrence resumed"
      standing (validateStandingState retired)
    _ -> Left "weekly quota did not release exactly two opportunities"

triggerProbe :: Either Text ()
triggerProbe = do
  (source, first) <- createBrickFixture "Have lunch" standingChecklistV1
    emptyStandingState
  (target, second) <- createBrickFixture "Brush teeth" practiceV1 first
  (trigger, third) <- standing (configureOpportunityTrigger (brickId source)
    (brickId target) probeTime second)
  expectFailure (configureOpportunityTrigger (brickId source) (brickId target)
    probeTime third) "duplicate active trigger was accepted"
  (sourceRun, fourth) <- standing (startStandingExecution (brickId source)
    probeTime third)
  (_, fifth) <- standing (finishStandingExecution (executionOccurrenceId sourceRun)
    OutcomeDone Nothing (addUTCTime 1 probeTime) fourth)
  require (Map.size (standingStateTriggeredOpportunities fifth) == 1)
    "source execution did not release exactly one opportunity"
  let sourceEventId = "execution-finished:"
        <> unExecutionOccurrenceId (executionOccurrenceId sourceRun)
  retried <- standing (releaseTriggeredOpportunities (brickId source)
    sourceEventId (addUTCTime 1 probeTime) fifth)
  require (Map.size (standingStateTriggeredOpportunities retried) == 1)
    "retry released a duplicate opportunity for one source event"
  (secondSourceRun, sixth) <- standing (startStandingExecution (brickId source)
    (addUTCTime 2 probeTime) retried)
  (_, seventh) <- standing (finishStandingExecution
    (executionOccurrenceId secondSourceRun) OutcomeDone Nothing
    (addUTCTime 3 probeTime) sixth)
  require (Map.size (standingStateTriggeredOpportunities seventh) == 2)
    "distinct source events did not retain distinct opportunities"
  (targetRun, eighth) <- standing (startStandingExecution (brickId target)
    (addUTCTime 4 probeTime) seventh)
  (_, ninth) <- standing (finishStandingExecution (executionOccurrenceId targetRun)
    OutcomeDone Nothing (addUTCTime 5 probeTime) eighth)
  let consumed = length [opportunity | opportunity <- Map.elems
        (standingStateTriggeredOpportunities ninth),
        triggeredOpportunityConsumedAt opportunity /= Nothing]
  require (consumed == 1)
    "one target execution did not consume exactly one trigger"
  retired <- standing (retireStandingTarget (brickId target)
    (addUTCTime 6 probeTime) ninth)
  require (fmap opportunityTriggerStatus (Map.lookup (opportunityTriggerId trigger)
      (standingStateOpportunityTriggers retired)) == Just TriggerRetired)
    "terminal target left its trigger active"
  standing (validateStandingState retired)

-- The terminal rule applies to every Domain lifecycle path, not just explicit
-- standing retirement.  Probe each declared status and the coordinated
-- subtree/child-transfer wrappers so a passing result cannot hide live future
-- mechanics behind a dropped or superseded Brick.
data TerminalProbeTransition
  = ProbeDone
  | ProbeDropped
  | ProbeSuperseded

terminalMechanicsProbe :: Either Text ()
terminalMechanicsProbe = do
  mapM_ probeTerminalTransition
    [ProbeDone, ProbeDropped, ProbeSuperseded]
  mapM_ probeTerminalSubtree [Done, Dropped]
  probeSupersessionWithChildren

probeTerminalTransition :: TerminalProbeTransition -> Either Text ()
probeTerminalTransition transition = do
  (target, first) <- createBrickFixture "Terminal practice" practiceV1
    emptyStandingState
  (replacement, second) <- createBrickFixture "Replacement practice" practiceV1 first
  (source, third) <- createBrickFixture "Trigger source" standingChecklistV1 second
  (rule, fourth) <- standing (configureRecurrence (brickId target)
    PracticeRecurrence "2 times per ISO week" "UTC" probeTime probeTime third)
  (_, opportunities, fifth) <- standing (advanceSchedules probeTime fourth)
  (incoming, sixth) <- standing (configureOpportunityTrigger (brickId source)
    (brickId target) probeTime fifth)
  (outgoing, seventh) <- standing (configureOpportunityTrigger (brickId target)
    (brickId replacement) probeTime sixth)
  terminal <- case transition of
    ProbeDone -> standing (retireStandingTarget (brickId target) probeTime seventh)
    ProbeDropped -> standing (dropStandingBrick (brickId target) probeTime seventh)
    ProbeSuperseded -> standing (supersedeStandingBrick (brickId target)
      (brickId replacement) (Just "method changed") probeTime seventh)
  let expected = case transition of
        ProbeDone -> Done
        ProbeDropped -> Dropped
        ProbeSuperseded -> Superseded
  assertRetiredMechanics expected target rule opportunities [incoming, outgoing]
    probeTime terminal

probeTerminalSubtree :: BrickStatus -> Either Text ()
probeTerminalSubtree status = do
  (root, first) <- createBrickFixture "Standing collection" collectionV1
    emptyStandingState
  (target, second) <- createChildFixture "Nested practice" practiceV1
    (brickId root) first
  (rule, third) <- standing (configureRecurrence (brickId target)
    PracticeRecurrence "2 times per ISO week" "UTC" probeTime probeTime second)
  (_, opportunities, fourth) <- standing (advanceSchedules probeTime third)
  (trigger, fifth) <- standing (configureOpportunityTrigger (brickId root)
    (brickId target) probeTime fourth)
  terminal <- standing (closeStandingSubtree (brickId root) status probeTime fifth)
  rootAfter <- lookupBrickState (brickId root) terminal
  require (brickStatus rootAfter == status)
    "terminal subtree did not close its root"
  assertRetiredMechanics status target rule opportunities [trigger] probeTime terminal

probeSupersessionWithChildren :: Either Text ()
probeSupersessionWithChildren = do
  (source, first) <- createBrickFixture "Old recurring owner"
    recurringObligationV1 emptyStandingState
  (replacement, second) <- createBrickFixture "New recurring owner"
    recurringObligationV1 first
  (child, third) <- createChildFixture "Transferred occurrence" standardV1
    (brickId source) second
  (practiceTarget, fourth) <- createBrickFixture "Practice target" practiceV1 third
  (rule, fifth) <- standing (configureRecurrence (brickId source)
    ObligationRecurrence "monthly on day 1" "UTC"
    (addUTCTime week probeTime) probeTime fourth)
  (trigger, sixth) <- standing (configureOpportunityTrigger (brickId source)
    (brickId practiceTarget) probeTime fifth)
  (_, terminal) <- standing (supersedeStandingBrickWithChildren (brickId source)
    (brickId replacement) [brickId child] (Just "replace series")
    "transfer-child" probeTime sixth)
  sourceAfter <- lookupBrickState (brickId source) terminal
  childAfter <- lookupBrickState (brickId child) terminal
  require (brickStatus sourceAfter == Superseded
      && brickParent childAfter == Just (brickId replacement)
      && brickStatus childAfter == Active)
    "supersession with children changed the wrong identities"
  assertRetiredMechanics Superseded source rule [] [trigger] probeTime terminal

assertRetiredMechanics ::
  BrickStatus -> Brick -> RecurrenceRule -> [PracticeOpportunity] ->
  [OpportunityTrigger] -> UTCTime -> StandingState -> Either Text ()
assertRetiredMechanics expected target rule opportunities triggers now state = do
  targetAfter <- lookupBrickState (brickId target) state
  require (brickStatus targetAfter == expected)
    "terminal transition produced the wrong Brick status"
  retainedRule <- maybe (Left "terminal recurrence disappeared") Right
    (Map.lookup (recurrenceRuleId rule) (standingStateRecurrences state))
  require (recurrenceRuleStatus retainedRule == ScheduleRetired)
    "terminal Brick retained a live recurrence"
  mapM_ (assertClosedPractice state) opportunities
  mapM_ (assertRetiredTrigger state) triggers
  standing (validateStandingState state)
  where
    assertClosedPractice current original = do
      retained <- maybe (Left "terminal practice opportunity disappeared") Right
        (Map.lookup (practiceOpportunityId original)
          (standingStatePracticeOpportunities current))
      require (practiceOpportunityStatus retained == OpportunityNotApplicable
          && practiceOpportunityResolvedAt retained == Just now
          && practiceOpportunityReason retained == Just "target_terminal")
        "terminal Brick retained or dishonestly resolved a practice opportunity"
    assertRetiredTrigger current original = do
      retained <- maybe (Left "terminal opportunity trigger disappeared") Right
        (Map.lookup (opportunityTriggerId original)
          (standingStateOpportunityTriggers current))
      require (opportunityTriggerStatus retained == TriggerRetired)
        "terminal Brick retained an inbound or outbound trigger"

createBrickFixture ::
  Text -> BrickBehavior -> StandingState ->
  Either Text (Brick, StandingState)
createBrickFixture title behavior state = do
  canonical <- domain (mkCanonicalText title Nothing Human)
  (brick, _, next) <- standing (createStandingBrick
    (ordinaryBrickDraft canonical behavior probeTime) ("probe:" <> title)
    probeTime state)
  pure (brick, next)

createChildFixture ::
  Text -> BrickBehavior -> BrickId -> StandingState ->
  Either Text (Brick, StandingState)
createChildFixture title behavior parent state = do
  canonical <- domain (mkCanonicalText title Nothing Human)
  (brick, _, next) <- standing (createStandingBrick
    ((ordinaryBrickDraft canonical behavior probeTime)
      {brickDraftParent = Just parent}) ("probe:" <> title) probeTime state)
  pure (brick, next)

lookupBrickState :: BrickId -> StandingState -> Either Text Brick
lookupBrickState identifier state = maybe (Left "probe Brick is absent") Right
  (Map.lookup identifier (domainBricks (executionStateDomain
    (coordinationStateExecution (standingStateCoordination state)))))

brickIdPlaceholder :: Text -> BrickId
brickIdPlaceholder = BrickId

headSafe :: [value] -> Maybe value
headSafe [] = Nothing
headSafe (value : _) = Just value

week :: RealFrac value => value
week = 7 * 24 * 60 * 60

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 8 1) 0

expectFailure :: Either problem value -> Text -> Either Text ()
expectFailure result problem = case result of
  Left _ -> Right ()
  Right _ -> Left problem

standing :: Either StandingError value -> Either Text value
standing = either (Left . Text.pack . show) Right

domain :: Either DomainError value -> Either Text value
domain = either (Left . Text.pack . show) Right

priority :: Either Priority.PriorityError value -> Either Text value
priority = either (Left . Text.pack . show) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

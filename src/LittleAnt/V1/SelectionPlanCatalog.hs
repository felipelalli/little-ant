{-# LANGUAGE DerivingStrategies #-}

-- | Semantic Allium probes for rebuildable proposals and probabilistic
-- selection.  Every registration drives typed domain state; obligation IDs
-- are deliberately unavailable here.
module LittleAnt.V1.SelectionPlanCatalog
  ( selectionPlanProbes
  ) where

import Control.Monad (foldM, unless)
import Data.Aeson (encode, toJSON)
import qualified Data.ByteString.Lazy.Char8 as LBS8
import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Coordination (CoordinationState (..))
import LittleAnt.V1.Domain
  (Authority (Human), Brick (..), BrickBehavior, BrickId,
   BrickStatus (..), DomainError, DomainState (..), FocusRegister (..),
   WorkState (..),
   mkCanonicalText, ordinaryBrickDraft, practiceV1, setBrickWorkState,
   standardV1)
import LittleAnt.V1.Execution
  (ExecutionError, ExecutionState (..), focusExecutionBrick)
import qualified LittleAnt.V1.Judgment as Judgment
import LittleAnt.V1.Material
  (MaterialError, MaterialState (materialLinks), Raw (..), RawLink (rawLinkId),
   RawLinkRole (Source), RawSnapshot (rawSnapshotId),
   ReviewDispositionKind (Retained), SnapshotCaptureResult (..), archiveRaw,
   captureInlineRaw, captureRawSnapshot, emptyMaterialState, linkRawToBrick,
   registerMaterialBrick, reviewRaw)
import qualified LittleAnt.V1.Priority as Priority
import LittleAnt.V1.Selection
import LittleAnt.V1.Standing
  (PracticeOpportunity (..), RecurrenceKind (PracticeRecurrence), StandingError,
   StandingState (..), abandonPracticeOpportunity, advanceSchedules,
   configureRecurrence, createStandingBrick, emptyStandingState,
   validateStandingState)

selectionPlanProbes :: Map ProbeKey PlanProbe
selectionPlanProbes = Map.fromList
  (selectionShapeRegistrations
  <> proposalRegistrations
  <> skipRegistrations
  <> forecastRegistrations
  <> invariantRegistrations
  <> surfaceRegistrations)

------------------------------------------------------------
-- Registrations
------------------------------------------------------------

selectionShapeRegistrations :: [(ProbeKey, PlanProbe)]
selectionShapeRegistrations =
  [ selectionRegistration category construct selectionShapeProbe
  | (category, constructs) <-
      [ ("value_equality", ["ForecastItem", "ForecastView"])
      , ("entity_fields",
          ["ForecastItem", "ForecastView", "Proposal", "SelectionCooldown",
           "NextDraw"])
      , ("enum_comparable", ["ProposalKind", "ProposalStatus"])
      , ("transition_edge", ["Proposal.status"])
      , ("transition_rejected", ["Proposal.status"])
      , ("transition_terminal", ["Proposal.status"])
      , ("entity_optional",
          [ "Proposal.brick", "Proposal.raw", "Proposal.insertion"
          , "Proposal.judgment_probe", "Proposal.delegation"
          , "NextDraw.selected_brick", "NextDraw.selected_proposal"
          ])
      , ("derived", ["NextDraw.source_forecast"])
      , ("config_default",
          ["config.served_skip_cooldown", "config.stale_focus_after"])
      ]
  , construct <- constructs
  ]

proposalRegistrations :: [(ProbeKey, PlanProbe)]
proposalRegistrations = concat
  [ allRuleCategories "DeferredPlacementCreatesPriorityProbe"
  , allRuleCategories "DeferredPriorityMayProposeInvestigationWork"
  , allRuleCategories "ContradictionCreatesPriorityProbe"
  , allRuleCategories "JudgmentProbeCreatesAxisProposal"
  , allRuleCategories "DueProvocativeValidationOpened"
  , allRuleCategories "ReopenedJudgmentProbeCreatesAxisProposal"
  , successOnly "DeferredJudgmentProbeResolvesAxisProposal"
  , allRuleCategories "DeferredJudgmentMayProposeInvestigationWork"
  , successOnly "ResolvedJudgmentProbeResolvesAxisProposal"
  , allRuleCategories "ParentReviewProposed"
  , allRuleCategories "WipReviewProposed"
  , allRuleCategories "ScopeReviewProposed"
  , allRuleCategories "DependencyReviewProposed"
  , allRuleCategories "NewRawCreatesReviewProposal"
  , successOnly "ReviewedRawResolvesReviewProposal"
  , successOnly "ArchivedRawResolvesMaterialProposals"
  , allRuleCategories "SourceRefreshCreatesReconciliationProposal"
  , successAndFailure "ProposalResolved"
  , successAndFailure "ProposalDismissed"
  , allRuleCategories "RepeatedPracticeFrictionCreatesReview"
  , allRuleCategories "RepeatedUnfulfilledPracticeCreatesReview"
  , allRuleCategories "StaleFocusProposed"
  ]
  where
    successOnly construct =
      [selectionRegistration "rule_success" construct proposalDerivationProbe]
    successAndFailure construct =
      [selectionRegistration category construct proposalDerivationProbe
      | category <- ["rule_success", "rule_failure"]]
    allRuleCategories construct =
      [selectionRegistration category construct proposalDerivationProbe
      | category <- ["rule_success", "rule_failure", "rule_entity_creation"]]

skipRegistrations :: [(ProbeKey, PlanProbe)]
skipRegistrations =
  [ executionRegistration category construct servedSkipProbe
  | (category, construct) <-
      [ ("enum_comparable", "SkipReason")
      , ("entity_fields", "ServedSkip")
      , ("entity_optional", "ServedSkip.raw_text")
      , ("rule_success", "ServedBrickSkipped")
      , ("rule_failure", "ServedBrickSkipped")
      , ("rule_entity_creation", "ServedBrickSkipped")
      ]
  ] <>
  [ selectionRegistration category construct servedSkipProbe
  | (construct, categories) <-
      [ ("FirstServedSkipStartsCooldown",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("RepeatedServedSkipRefreshesCooldown",
          ["rule_success", "rule_failure"])
      ]
  , category <- categories
  ]

forecastRegistrations :: [(ProbeKey, PlanProbe)]
forecastRegistrations =
  [selectionRegistration "contract_signature" "ForecastEngine.build" forecastProbe]
  <> [ selectionRegistration category "ValidCurrentFocusReturnedByNext" forecastProbe
     | category <- ["rule_success", "rule_failure", "rule_entity_creation"]
     ] <>
  [ selectionRegistration category "OrdinaryNextDrawnFromForecast" forecastProbe
  | category <- ["rule_success", "rule_failure", "rule_entity_creation"]
  ]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ selectionRegistration "invariant" construct forecastProbe
  | construct <-
      ["NextDrawSelectsExactlyOneKind", "ProposalIsNotBrick",
       "OptionalAxesDoNotControlEligibility"]
  ]

surfaceRegistrations :: [(ProbeKey, PlanProbe)]
surfaceRegistrations =
  [selectionRegistration category "SelectionDesk" fullSelectionProbe
  | category <- ["surface_actor", "surface_exposure", "surface_provides"]]

selectionRegistration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
selectionRegistration category construct probe =
  (ProbeKey "selection" category construct,
    semanticProbe "selection" category construct probe)

executionRegistration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
executionRegistration category construct probe =
  (ProbeKey "execution" category construct,
    semanticProbe "execution" category construct probe)

semanticProbe :: Text -> Text -> Text -> Either Text () -> PlanProbe
semanticProbe expectedModule category construct probe input = do
  require (planProbeModule input == expectedModule)
    "selection probe received the wrong module"
  require (planProbeCategory input == category)
    "selection probe received the wrong category"
  require (planProbeSourceConstruct input == construct)
    "selection probe received the wrong semantic construct"
  probe

------------------------------------------------------------
-- Forecast, next, and cooldown probes
------------------------------------------------------------

fullSelectionProbe :: Either Text ()
fullSelectionProbe = do
  selectionShapeProbe
  forecastProbe
  servedSkipProbe
  proposalDerivationProbe

selectionShapeProbe :: Either Text ()
selectionShapeProbe = do
  (bricks, _, context) <- contextFixture
    [("Shape A", standardV1), ("Shape B", standardV1)]
  (first, second) <- exactlyTwo "shape Bricks" bricks
  baseline <- selection (buildForecast probeTime 7 context emptySelectionState)
  item <- maybe (Left "shape forecast omitted its first Brick") Right
    (forecastItemForBrick (brickId first) baseline)
  require (encode item == encode item && encode baseline == encode baseline)
    "forecast values lack structural equality"
  require (forecastItemBrick item == Just (brickId first)
      && forecastItemProposal item == Nothing
      && forecastItemWeight item > 0
      && forecastItemProbability item > 0
      && not (null (forecastItemReasons item)))
    "ForecastItem omits a declared field or relationship"
  (_, _, skipped) <- selection (recordServedSkip (brickId second) SkipVague
    Nothing probeTime context emptySelectionState)
  cooldown <- maybe (Left "shape cooldown is absent") Right
    (Map.lookup (brickId second) (selectionStateCooldowns skipped))
  require (selectionCooldownRecentSkipCount cooldown == 1
      && selectionCooldownLastReason cooldown == SkipVague)
    "SelectionCooldown does not retain its declared fields"
  require (toJSON (minBound :: ProposalKind) /= toJSON (maxBound :: ProposalKind)
      && toJSON ProposalOpen /= toJSON ProposalDismissed)
    "selection enum encodings collide"
  -- Exercise both declared edges and every terminal/rejected transition.
  focused <- setFocus (brickId first) probeTime context
  (_, withProposal) <- selection (advanceSelection
    (addUTCTime (staleFocusAfter + 1) probeTime) focused emptySelectionState)
  proposal <- exactlyOneProposal StaleFocus withProposal
  (resolved, resolvedState) <- selection
    (resolveProposal (proposalId proposal) withProposal)
  require (proposalStatus resolved == ProposalResolved)
    "open-to-resolved Proposal edge failed"
  expectFailure (resolveProposal (proposalId proposal) resolvedState)
    "resolved Proposal had an outbound edge"
  (_, secondProposalState) <- selection (advanceSelection
    (addUTCTime (staleFocusAfter + 1) probeTime) focused emptySelectionState)
  secondProposal <- exactlyOneProposal StaleFocus secondProposalState
  (dismissed, dismissedState) <- selection
    (dismissProposal (proposalId secondProposal) secondProposalState)
  require (proposalStatus dismissed == ProposalDismissed)
    "open-to-dismissed Proposal edge failed"
  expectFailure (dismissProposal (proposalId secondProposal) dismissedState)
    "dismissed Proposal had an outbound edge"
  require (servedSkipCooldown == 2 * 60 * 60
      && staleFocusAfter == 24 * 60 * 60)
    "selection defaults differ from the declared config"

forecastProbe :: Either Text ()
forecastProbe = do
  (bricks, _, context) <- contextFixture
    [("Critical", standardV1), ("Guide", standardV1), ("Background", standardV1)]
  (critical, guide, background) <- exactlyThree "forecast Bricks" bricks
  let beforeContext = context
      beforeSelection = encode emptySelectionState
      beforePriority = encode (selectionPriority context)
  forecast <- selection (buildForecast probeTime 11 context emptySelectionState)
  require (context == beforeContext
      && encode emptySelectionState == beforeSelection
      && encode (selectionPriority context) == beforePriority)
    "building a forecast mutated canonical state or priority"
  require (length (forecastViewItems forecast) == 3
      && all (\item -> forecastItemProbability item > 0
        && forecastItemWeight item > 0
        && not (null (forecastItemReasons item))) (forecastViewItems forecast)
      && abs (sum (map forecastItemProbability (forecastViewItems forecast)) - 1)
        < 1e-9)
    "eligible forecast mass is not positive, normalized, and explained"
  firstMetrics <- selection
    (simulateReplaySafeDraws "selection-probe-seed" 10000 forecast)
  secondMetrics <- selection
    (simulateReplaySafeDraws "selection-probe-seed" 10000 forecast)
  require (firstMetrics == secondMetrics
      && all (\metric -> abs
        (simulationCandidateObservedFrequency metric
          - simulationCandidateForecastProbability metric) <= 0.02)
        (simulationMetricsPerCandidate firstMetrics))
    "forecast simulation is not replayable or calibrated"
  focusedContext <- setFocus (brickId guide) probeTime context
  (focusedDraw, focusedState) <- selection (requestNext probeTime 11
    "focus-evidence" focusedContext emptySelectionState)
  require (nextDrawSelectedBrick focusedDraw == Just (brickId guide)
      && nextDrawSelectedProposal focusedDraw == Nothing
      && nextDrawReasons focusedDraw == ["current focus remains valid"])
    "valid current focus did not take precedence"
  selection (validateSelectionState focusedContext focusedState)
  (ordinaryDraw, firstDrawState) <- selection (requestNext probeTime 11
    "ordinary-evidence" context emptySelectionState)
  (replayedDraw, _) <- selection (requestNext probeTime 11
    "ordinary-evidence" context emptySelectionState)
  require (nextDrawSelectedBrick ordinaryDraw == nextDrawSelectedBrick replayedDraw
      && nextDrawSelectedProposal ordinaryDraw == nextDrawSelectedProposal replayedDraw
      && exactlyOneKind ordinaryDraw
      && nextDrawReasons ordinaryDraw /= ["current focus remains valid"])
    "ordinary next did not draw exactly one replay-safe forecast item"
  let invalidFocused = setBrickStatusInContext (brickId guide) Done focusedContext
  (fallbackDraw, _) <- selection (requestNext probeTime 11
    "invalid-focus-evidence" invalidFocused emptySelectionState)
  require (nextDrawSelectedBrick fallbackDraw /= Just (brickId guide)
      && nextDrawReasons fallbackDraw /= ["current focus remains valid"])
    "non-executable focus was returned by next instead of ordinary forecast"
  let emptyContext = SelectionContext emptyStandingState emptyMaterialState
  expectFailure (requestNext probeTime 0 "no-candidate" emptyContext
    emptySelectionState) "ordinary next accepted an empty forecast"
  require (not ("source_forecast" `isInfixOf`
    LBS8.unpack (encode firstDrawState)))
    "ordinary next persisted its derived source forecast"
  selection (validateSelectionState context firstDrawState)
  -- Optional axes are absent for all three Bricks; that absence did not remove
  -- any candidate.  Human priority remains a separate unchanged structure.
  require (all (`elem` map forecastItemBrick (forecastViewItems forecast))
      [Just (brickId critical), Just (brickId guide), Just (brickId background)])
    "missing optional impact/effort/phase controlled eligibility"
  (_, _, withImpact) <- judgmentResult (Judgment.classifyImpact
    (brickId critical) Judgment.CriticalImpact Judgment.Supported Human
    (Just "customer evidence") probeTime (selectionJudgment context))
  easyBand <- judgmentResult (Judgment.effortBandById
    Judgment.initialEffortProfile "VERY_EASY" withImpact)
  (_, _, withOptionalAxes) <- judgmentResult (Judgment.classifyEffort
    (brickId guide) easyBand Human False (Just "small change") probeTime withImpact)
  optionalContext <- setJudgment withOptionalAxes context
  informed <- selection (buildForecast probeTime 11 optionalContext
    emptySelectionState)
  criticalBefore <- requireForecastItem (brickId critical) forecast
  criticalAfter <- requireForecastItem (brickId critical) informed
  guideBefore <- requireForecastItem (brickId guide) forecast
  guideAfter <- requireForecastItem (brickId guide) informed
  require (forecastItemWeight criticalAfter /= forecastItemWeight criticalBefore
      && forecastItemWeight guideAfter /= forecastItemWeight guideBefore
      && Set.fromList (map forecastItemBrick (forecastViewItems informed))
        == Set.fromList (map forecastItemBrick (forecastViewItems forecast))
      && encode (selectionPriority optionalContext) == beforePriority)
    "optional impact/effort failed to influence weights neutrally or rewrote eligibility/priority"

servedSkipProbe :: Either Text ()
servedSkipProbe = do
  (bricks, _, context) <- contextFixture
    [("Taxes", standardV1), ("Tidy", standardV1)]
  (taxes, _tidy) <- exactlyTwo "served-skip Bricks" bricks
  let identifier = brickId taxes
      priorityBefore = encode (selectionPriority context)
  baseline <- selection (buildForecast probeTime 1 context emptySelectionState)
  baselineItem <- requireForecastItem identifier baseline
  (firstSkip, firstCooldown, first) <- selection (recordServedSkip identifier
    SkipVague (Just "find statements") probeTime context emptySelectionState)
  require (servedSkipBrick firstSkip == identifier
      && servedSkipRawText firstSkip == Just "find statements"
      && selectionCooldownRecentSkipCount firstCooldown == 1
      && selectionCooldownUntil firstCooldown
        == addUTCTime servedSkipCooldown probeTime)
    "first served skip did not retain evidence and start cooldown"
  during <- selection (buildForecast (addUTCTime 1800 probeTime) 1 context first)
  duringItem <- requireForecastItem identifier during
  require (forecastItemProbability duringItem
      < forecastItemProbability baselineItem)
    "active cooldown did not reduce immediate probability"
  after <- selection (buildForecast
    (addUTCTime (servedSkipCooldown + 1) probeTime) 1 context first)
  afterItem <- requireForecastItem identifier after
  require (forecastItemProbability afterItem > 0
      && "retained served-skip pressure" `elem` forecastItemReasons afterItem)
    "expired cooldown did not restore positive retained pressure"
  (_, repeatedCooldown, repeated) <- selection (recordServedSkip identifier
    SkipVague Nothing (addUTCTime (servedSkipCooldown + 1) probeTime) context first)
  require (selectionCooldownRecentSkipCount repeatedCooldown == 2
      && selectionCooldownUntil repeatedCooldown
        == addUTCTime (2 * servedSkipCooldown + 1) probeTime
      && encode (selectionPriority context) == priorityBefore
      && brickStatus taxes == Active)
    "repeated served skip did not refresh cooldown without lifecycle/priority change"
  selection (validateSelectionState context repeated)
  expectFailure (recordServedSkip identifier SkipOther Nothing probeTime context
    emptySelectionState) "other skip reason without raw text was accepted"
  let terminalContext = setBrickStatusInContext identifier Done context
  expectFailure (recordServedSkip identifier SkipVague Nothing probeTime
    terminalContext emptySelectionState) "terminal Brick was skipped"

------------------------------------------------------------
-- Proposal-source probe
------------------------------------------------------------

proposalDerivationProbe :: Either Text ()
proposalDerivationProbe = do
  deferredPlacementProbe
  deferredInvestigationProbe
  contradictionProposalProbe
  judgmentProposalProbe
  dueValidationProbe
  reviewFlagProposalProbe
  materialProposalProbe
  sourceRefreshProposalProbe
  proposalLifecycleFailureProbe
  practiceProposalProbe
  unfulfilledPracticeProposalProbe
  staleProposalProbe

deferredPlacementProbe :: Either Text ()
deferredPlacementProbe = do
  (bricks, insertions, context) <- contextFixture
    [("First", standardV1), ("Deferred", standardV1)]
  (_first, deferredBrick) <- exactlyTwo "deferred Bricks" bricks
  (_firstInsertion, insertion) <- exactlyTwo "deferred insertions" insertions
  let priority = selectionPriority context
  (_, deferredPriority) <- priorityResult (Priority.deferPriorityInsertion
    (Priority.priorityInsertionId insertion) probeTime priority)
  deferredContext <- setPriority deferredPriority context
  (created, first) <- selection
    (advanceSelection probeTime deferredContext emptySelectionState)
  require (any (\proposal -> proposalKind proposal == PriorityProbe
      && proposalBrick proposal == Just (brickId deferredBrick)
      && proposalInsertion proposal == Just (Priority.priorityInsertionId insertion))
      created
      && null (openKind InvestigationPlan first))
    "deferred low-value placement did not derive only its priority_probe"
  (createdAgain, second) <- selection
    (advanceSelection probeTime deferredContext first)
  require (null createdAgain && length (openKind PriorityProbe second) == 1)
    "deferred placement created a duplicate open proposal"

deferredInvestigationProbe :: Either Text ()
deferredInvestigationProbe = do
  (_bricks, insertions, context) <- contextFixture
    [("First", standardV1), ("Uncertain", standardV1)]
  (_firstInsertion, insertion) <- exactlyTwo "investigation insertions" insertions
  let priority = selectionPriority context
  (_, _, onceSkipped) <- priorityResult (Priority.skipPriorityComparison
    (Priority.priorityInsertionId insertion) Priority.Unresolved probeTime priority)
  (_, _, deferred) <- priorityResult (Priority.skipPriorityComparison
    (Priority.priorityInsertionId insertion) Priority.Unresolved
    (addUTCTime 1 probeTime) onceSkipped)
  deferredContext <- setPriority deferred context
  (created, first) <- selection
    (advanceSelection probeTime deferredContext emptySelectionState)
  require (length [proposal | proposal <- created,
      proposalKind proposal == InvestigationPlan,
      proposalInsertion proposal == Just (Priority.priorityInsertionId insertion)] == 1)
    "high-value deferred priority information did not create investigation work"
  (createdAgain, second) <- selection
    (advanceSelection probeTime deferredContext first)
  require (null createdAgain && length (openKind InvestigationPlan second) == 1)
    "existing priority investigation proposal did not suppress a duplicate"

contradictionProposalProbe :: Either Text ()
contradictionProposalProbe = do
  (bricks, _, context) <- contextFixture
    [("A", standardV1), ("B", standardV1),
     ("C", standardV1), ("D", standardV1)]
  (a, b, c, _d) <- exactlyFour "contradiction Bricks" bricks
  let priority = selectionPriority context
      scope = Priority.priorityRootScopeId
  (_, _, withAB) <- priorityResult (Priority.recordPriorityJudgment scope
    (brickId a) (brickId b) Human (Just "A before B") probeTime priority)
  (_, _, withBC) <- priorityResult (Priority.recordPriorityJudgment scope
    (brickId b) (brickId c) Human (Just "B before C") probeTime withAB)
  (_, recalibration, contradicted) <- priorityResult
    (Priority.recordPriorityJudgment scope (brickId c) (brickId a) Human
      (Just "new contrary evidence") probeTime withBC)
  _ <- maybe (Left "contradiction did not create recalibration") Right recalibration
  contradictedContext <- setPriority contradicted context
  (created, first) <- selection
    (advanceSelection probeTime contradictedContext emptySelectionState)
  require (length [proposal | proposal <- created,
      proposalKind proposal == PriorityProbe,
      proposalBrick proposal == Just (brickId a)] == 1)
    "priority contradiction did not create one local priority probe proposal"
  (again, second) <- selection
    (advanceSelection probeTime contradictedContext first)
  require (null again && length (openKind PriorityProbe second) == 1)
    "existing contradiction proposal did not suppress duplicate creation"

judgmentProposalProbe :: Either Text ()
judgmentProposalProbe = do
  (bricks, _, context) <- contextFixture
    [("Impact A", standardV1), ("Impact B", standardV1)]
  (left, right) <- exactlyTwo "judgment Bricks" bricks
  let judgment = selectionJudgment context
  (probe, openJudgment) <- judgmentResult (Judgment.openImpactProbe
    (brickId left) (brickId right) Priority.Discovery "compare impact"
    probeTime judgment)
  openContext <- setJudgment openJudgment context
  (_, withProposal) <- selection
    (advanceSelection probeTime openContext emptySelectionState)
  proposal <- exactlyOneProposal ImpactProbe withProposal
  require (proposalJudgmentProbe proposal == Just (Priority.judgmentProbeId probe))
    "open impact probe did not derive its axis proposal"
  (duplicateCreated, duplicateState) <- selection
    (advanceSelection probeTime openContext withProposal)
  require (null duplicateCreated && length (openKind ImpactProbe duplicateState) == 1)
    "existing JudgmentProbe proposal did not suppress a duplicate"
  expectFailure (resolveProposal (proposalId proposal) withProposal)
    "live judgment proposal resolved outside its JudgmentProbe"
  (_, deferredJudgment) <- judgmentResult
    (Judgment.deferAssessmentProbe (Priority.judgmentProbeId probe) openJudgment)
  deferredContext <- setJudgment deferredJudgment context
  (deferredCreated, resolved) <- selection
    (advanceSelection probeTime deferredContext withProposal)
  retained <- maybe (Left "axis proposal disappeared instead of resolving") Right
    (Map.lookup (proposalId proposal) (selectionStateProposals resolved))
  require (proposalStatus retained == ProposalResolved
      && length [candidate | candidate <- deferredCreated,
        proposalKind candidate == InvestigationPlan,
        proposalJudgmentProbe candidate == Just (Priority.judgmentProbeId probe)] == 1)
    "deferred high-value JudgmentProbe did not resolve its axis proposal and create investigation work"
  (_, reopenedJudgment) <- judgmentResult
    (Judgment.reopenAssessmentProbe (Priority.judgmentProbeId probe)
      deferredJudgment)
  reopenedContext <- setJudgment reopenedJudgment context
  (reopened, reopenedState) <- selection
    (advanceSelection probeTime reopenedContext resolved)
  require (length [candidate | candidate <- reopened,
      proposalKind candidate == ImpactProbe] == 1
      && length (openKind ImpactProbe reopenedState) == 1)
    "reopened JudgmentProbe did not create a fresh axis proposal"
  (reopenedAgain, reopenedDeduplicated) <- selection
    (advanceSelection probeTime reopenedContext reopenedState)
  require (null reopenedAgain
      && length (openKind ImpactProbe reopenedDeduplicated) == 1)
    "reopened JudgmentProbe duplicated its open axis proposal"
  (_, _, answeredJudgment) <- judgmentResult (Judgment.compareImpact
    (brickId left) (brickId right) Judgment.RelativelyMore Human
    (Just "resolved comparison") probeTime reopenedJudgment)
  answeredContext <- setJudgment answeredJudgment context
  (_, afterResolution) <- selection
    (advanceSelection probeTime answeredContext reopenedState)
  require (null (openKind ImpactProbe afterResolution))
    "resolved JudgmentProbe left its axis proposal open"

  -- Validation-purpose deferral is deliberately low-information and does not
  -- invent investigation work.
  (lowProbe, lowOpen) <- judgmentResult (Judgment.openImpactProbe
    (brickId left) (brickId right) Priority.Validation "bounded check"
    probeTime judgment)
  (_, lowDeferred) <- judgmentResult
    (Judgment.deferAssessmentProbe (Priority.judgmentProbeId lowProbe) lowOpen)
  lowContext <- setJudgment lowDeferred context
  (lowCreated, _) <- selection
    (advanceSelection probeTime lowContext emptySelectionState)
  require (null [candidate | candidate <- lowCreated,
      proposalKind candidate == InvestigationPlan,
      proposalJudgmentProbe candidate == Just (Priority.judgmentProbeId lowProbe)])
    "low-value deferred JudgmentProbe created investigation work"

dueValidationProbe :: Either Text ()
dueValidationProbe = do
  (bricks, _, context) <- contextFixture
    [("Validation A", standardV1), ("Validation B", standardV1)]
  (left, right) <- exactlyTwo "validation Bricks" bricks
  let priority = selectionPriority context
  (_, _, withEvidence) <- priorityResult (Priority.recordPriorityJudgment
    Priority.priorityRootScopeId (brickId left) (brickId right) Human
    (Just "retained direct evidence") probeTime priority)
  evidenceContext <- setPriority withEvidence context
  (created, opened, withValidation, selected) <- selection
    (advanceSelectionWithValidation probeTime evidenceContext emptySelectionState)
  probe <- maybe (Left "due provocative validation did not open") Right opened
  require (Priority.judgmentProbeAxis probe == Priority.PriorityAxis
      && Priority.judgmentProbePurpose probe == Priority.Validation
      && Priority.judgmentProbeLeft probe == brickId left
      && Priority.judgmentProbeRight probe == brickId right
      && length [proposal | proposal <- created,
          proposalKind proposal == PriorityProbe,
          proposalJudgmentProbe proposal == Just (Priority.judgmentProbeId probe)] == 1)
    "due validation was not comparable, bounded, or proposal-backed"
  (createdAgain, openedAgain, _, deduplicated) <- selection
    (advanceSelectionWithValidation probeTime withValidation selected)
  require (openedAgain == Nothing && null createdAgain
      && length (openKind PriorityProbe deduplicated) == 1)
    "an existing open validation/proposal did not suppress duplicate creation"
  (_, absent, _, noCandidateState) <- selection
    (advanceSelectionWithValidation probeTime context emptySelectionState)
  require (absent == Nothing && Map.null (selectionStateProposals noCandidateState))
    "AdvanceSelection without a due candidate invented validation"

reviewFlagProposalProbe :: Either Text ()
reviewFlagProposalProbe = do
  (bricks, _, base) <- contextFixture
    [("Parent", standardV1), ("Scope", standardV1),
     ("Dependency", standardV1), ("Wip extra", standardV1)]
  (parent, scopeBrick, dependencyBrick, _) <- exactlyFour
    "review Bricks" bricks
  let standing = selectionContextStanding base
      coordination = standingStateCoordination standing
      execution = coordinationStateExecution coordination
      flaggedExecution = execution
        {executionStateParentReviews = Set.singleton (brickId parent)}
      flaggedCoordination = coordination
        { coordinationStateExecution = flaggedExecution
        , coordinationStateChecklistReviews = Set.singleton (brickId scopeBrick)
        , coordinationStateDependencyReviews = Set.singleton (brickId dependencyBrick)
        }
      flaggedStanding = standing {standingStateCoordination = flaggedCoordination}
      flagged = base {selectionContextStanding = flaggedStanding}
  (_, selected) <- selection (advanceSelection probeTime flagged emptySelectionState)
  require (not (null (openKind ReviewParent selected))
      && not (null (openKind ScopeReview selected))
      && not (null (openKind BrickReview selected)))
    "parent, scope, or dependency review pressure was not derived"
  (duplicateReviews, selectedAgain) <- selection
    (advanceSelection probeTime flagged selected)
  require (null duplicateReviews
      && length (openKind ReviewParent selectedAgain) == 1
      && length (openKind ScopeReview selectedAgain) == 1
      && length (openKind BrickReview selectedAgain) == 1)
    "existing parent/scope/dependency reviews did not suppress duplicates"
  wipContext <- setAllWip base
  (_, withWip) <- selection
    (advanceSelection probeTime wipContext emptySelectionState)
  require (length (openKind ReviewWip withWip) == 4)
    "soft-limit WIP pressure did not derive review_wip proposals"
  (duplicateWip, withWipAgain) <- selection
    (advanceSelection probeTime wipContext withWip)
  require (null duplicateWip && length (openKind ReviewWip withWipAgain) == 4)
    "existing WIP reviews did not suppress duplicates"

materialProposalProbe :: Either Text ()
materialProposalProbe = do
  (_, _, base) <- contextFixture [("Owner", standardV1)]
  (raw, pending) <- materialResult (captureInlineRaw "source note" Nothing Nothing
    probeTime emptyMaterialState)
  let pendingContext = base {selectionContextMaterial = pending}
  (_, withReview) <- selection
    (advanceSelection probeTime pendingContext emptySelectionState)
  review <- exactlyOneProposal ReviewRaw withReview
  require (proposalRaw review == Just (rawId raw))
    "new pending active Raw did not derive review_raw"
  (duplicateRawReviews, withReviewAgain) <- selection
    (advanceSelection probeTime pendingContext withReview)
  require (null duplicateRawReviews
      && length (openKind ReviewRaw withReviewAgain) == 1)
    "existing Raw review proposal did not suppress a duplicate"
  ((_, _), reviewed) <- materialResult (reviewRaw (rawId raw) Retained Nothing
    Human Nothing probeTime pending)
  let reviewedContext = base {selectionContextMaterial = reviewed}
  (_, resolved) <- selection
    (advanceSelection probeTime reviewedContext withReview)
  retained <- maybe (Left "Raw review proposal disappeared") Right
    (Map.lookup (proposalId review) (selectionStateProposals resolved))
  require (proposalStatus retained == ProposalResolved)
    "reviewed Raw did not resolve its review proposal"
  (archivedRaw, archivedState) <- materialResult (captureInlineRaw
    "archive note" Nothing Nothing probeTime emptyMaterialState)
  (_, archived) <- materialResult (archiveRaw (rawId archivedRaw) archivedState)
  let archivedContext = base {selectionContextMaterial = archived}
  (_, noArchivedProposal) <- selection
    (advanceSelection probeTime archivedContext emptySelectionState)
  require (null (openKind ReviewRaw noArchivedProposal))
    "archived Raw retained material proposal pressure"

sourceRefreshProposalProbe :: Either Text ()
sourceRefreshProposalProbe = do
  (bricks, _, base) <- contextFixture [("Source owner", standardV1)]
  owner <- exactlyOne "source owner" bricks
  (raw, first) <- materialResult (captureInlineRaw "source body" Nothing Nothing
    probeTime (selectionContextMaterial base))
  (firstCapture, second) <- materialResult (captureRawSnapshot (rawId raw)
    "sha256:first" 1 "text/plain" Nothing probeTime first)
  firstSnapshot <- createdSnapshot firstCapture
  (link, third) <- materialResult (linkRawToBrick (rawId raw) (brickId owner)
    Source (Just (rawSnapshotId firstSnapshot)) probeTime second)
  let reconciledContext = base {selectionContextMaterial = third}
  (_, beforeRefresh) <- selection
    (advanceSelection probeTime reconciledContext emptySelectionState)
  require (null (openKind SourceReconciliation beforeRefresh))
    "reconciled source link created premature refresh pressure"
  (_, fourth) <- materialResult (captureRawSnapshot (rawId raw)
    "sha256:second" 2 "text/plain" Nothing (addUTCTime 1 probeTime) third)
  let refreshedContext = base {selectionContextMaterial = fourth}
  (created, firstProposalState) <- selection
    (advanceSelection probeTime refreshedContext emptySelectionState)
  require (length [proposal | proposal <- created,
      proposalKind proposal == SourceReconciliation,
      proposalBrick proposal == Just (brickId owner),
      proposalRaw proposal == Just (rawId raw)] == 1)
    "new source snapshot did not create reconciliation proposal"
  (again, secondProposalState) <- selection
    (advanceSelection probeTime refreshedContext firstProposalState)
  require (null again
      && length (openKind SourceReconciliation secondProposalState) == 1
      && rawLinkId link `elem` Map.keys (materialLinks fourth))
    "existing source reconciliation proposal did not suppress a duplicate"
  where
    createdSnapshot result = case result of
      SnapshotCreated snapshot -> Right snapshot
      SnapshotReused _ -> Left "source refresh fixture unexpectedly reused snapshot"

proposalLifecycleFailureProbe :: Either Text ()
proposalLifecycleFailureProbe = do
  (bricks, _, context) <- contextFixture [("Lifecycle", standardV1)]
  brick <- exactlyOne "proposal lifecycle Brick" bricks
  focused <- setFocus (brickId brick) probeTime context
  (_, withProposal) <- selection (advanceSelection
    (addUTCTime (staleFocusAfter + 1) probeTime) focused emptySelectionState)
  proposal <- exactlyOneProposal StaleFocus withProposal
  (_, resolved) <- selection (resolveProposal (proposalId proposal) withProposal)
  expectFailure (resolveProposal (proposalId proposal) resolved)
    "terminal resolved Proposal accepted another resolution"
  expectFailure (dismissProposal (proposalId proposal) resolved)
    "terminal resolved Proposal accepted dismissal"
  (_, freshState) <- selection (advanceSelection
    (addUTCTime (staleFocusAfter + 1) probeTime) focused emptySelectionState)
  fresh <- exactlyOneProposal StaleFocus freshState
  (_, dismissed) <- selection (dismissProposal (proposalId fresh) freshState)
  expectFailure (dismissProposal (proposalId fresh) dismissed)
    "terminal dismissed Proposal accepted another dismissal"

practiceProposalProbe :: Either Text ()
practiceProposalProbe = do
  (bricks, _, context) <- contextFixture [("Practice", practiceV1)]
  practice <- exactlyOne "practice Brick" bricks
  let identifier = brickId practice
  (_, _, first) <- selection (recordServedSkip identifier SkipHard Nothing
    probeTime context emptySelectionState)
  (_, _, second) <- selection (recordServedSkip identifier SkipHard Nothing
    (addUTCTime 1 probeTime) context first)
  (_, _, third) <- selection (recordServedSkip identifier SkipHard Nothing
    (addUTCTime 2 probeTime) context second)
  (_, selected) <- selection
    (advanceSelection (addUTCTime 2 probeTime) context third)
  proposal <- exactlyOneProposal PracticeReview selected
  require (proposalBrick proposal == Just identifier)
    "repeated practice friction did not derive practice_review"
  (again, selectedAgain) <- selection
    (advanceSelection (addUTCTime 2 probeTime) context selected)
  require (null again && length (openKind PracticeReview selectedAgain) == 1)
    "existing practice-friction review did not suppress a duplicate"

  (ordinaryBricks, _, ordinaryContext) <- contextFixture
    [("Ordinary", standardV1)]
  ordinary <- exactlyOne "ordinary Brick" ordinaryBricks
  (_, _, ordinaryFirst) <- selection (recordServedSkip (brickId ordinary)
    SkipHard Nothing probeTime ordinaryContext emptySelectionState)
  (_, _, ordinarySecond) <- selection (recordServedSkip (brickId ordinary)
    SkipHard Nothing (addUTCTime 1 probeTime) ordinaryContext ordinaryFirst)
  (_, _, ordinaryThird) <- selection (recordServedSkip (brickId ordinary)
    SkipHard Nothing (addUTCTime 2 probeTime) ordinaryContext ordinarySecond)
  (_, noOrdinaryReview) <- selection
    (advanceSelection (addUTCTime 2 probeTime) ordinaryContext ordinaryThird)
  require (null (openKind PracticeReview noOrdinaryReview))
    "repeated friction on non-practice work created practice review"

  (_, _, oneSkip) <- selection (recordServedSkip identifier SkipHard Nothing
    probeTime context emptySelectionState)
  (_, _, twoSkips) <- selection (recordServedSkip identifier SkipHard Nothing
    (addUTCTime 1 probeTime) context oneSkip)
  (_, belowThreshold) <- selection
    (advanceSelection (addUTCTime 1 probeTime) context twoSkips)
  require (null (openKind PracticeReview belowThreshold))
    "practice review opened below its configured due threshold"

unfulfilledPracticeProposalProbe :: Either Text ()
unfulfilledPracticeProposalProbe = do
  (bricks, _, context) <- contextFixture [("Weekly practice", practiceV1)]
  practice <- exactlyOne "unfulfilled practice Brick" bricks
  (_, configured) <- standingResult (configureRecurrence (brickId practice)
    PracticeRecurrence "3 times per ISO week" "UTC" probeTime probeTime
    (selectionContextStanding context))
  (_, opportunities, released) <- standingResult
    (advanceSchedules probeTime configured)
  require (length opportunities == 3)
    "practice fixture did not release three due opportunities"
  missed <- foldM (\current opportunity -> snd <$> standingResult
      (abandonPracticeOpportunity (practiceOpportunityId opportunity)
        (Just "not done") probeTime current)) released opportunities
  let missedContext = context {selectionContextStanding = missed}
  (created, first) <- selection
    (advanceSelection probeTime missedContext emptySelectionState)
  require (length [proposal | proposal <- created,
      proposalKind proposal == PracticeReview,
      proposalBrick proposal == Just (brickId practice)] == 1)
    "repeated unfulfilled practice did not create review"
  (again, second) <- selection (advanceSelection probeTime missedContext first)
  require (null again && length (openKind PracticeReview second) == 1)
    "existing unfulfilled-practice review did not suppress duplicate creation"

  (belowBricks, _, belowContext) <- contextFixture
    [("Below threshold practice", practiceV1)]
  belowPractice <- exactlyOne "below-threshold practice" belowBricks
  (_, belowConfigured) <- standingResult (configureRecurrence (brickId belowPractice)
    PracticeRecurrence "2 times per ISO week" "UTC" probeTime probeTime
    (selectionContextStanding belowContext))
  (_, belowOpportunities, belowReleased) <- standingResult
    (advanceSchedules probeTime belowConfigured)
  belowMissed <- foldM (\current opportunity -> snd <$> standingResult
      (abandonPracticeOpportunity (practiceOpportunityId opportunity)
        Nothing probeTime current)) belowReleased belowOpportunities
  let belowMissedContext = belowContext {selectionContextStanding = belowMissed}
  (_, notDue) <- selection
    (advanceSelection probeTime belowMissedContext emptySelectionState)
  require (null (openKind PracticeReview notDue))
    "unfulfilled-practice review opened below its due threshold"

staleProposalProbe :: Either Text ()
staleProposalProbe = do
  (bricks, _, context) <- contextFixture [("Focused", standardV1)]
  focused <- exactlyOne "focused Brick" bricks
  focusedContext <- setFocus (brickId focused) probeTime context
  let staleAt = addUTCTime (staleFocusAfter + 1) probeTime
  (created, first) <- selection
    (advanceSelection staleAt focusedContext emptySelectionState)
  require (length [proposal | proposal <- created,
      proposalKind proposal == StaleFocus] == 1)
    "stale focus did not derive exactly one stale_focus proposal"
  (createdAgain, second) <- selection
    (advanceSelection staleAt focusedContext first)
  require (null createdAgain && length (openKind StaleFocus second) == 1)
    "stale focus proposal was duplicated"
  (_, noFocus) <- selection
    (advanceSelection staleAt context emptySelectionState)
  require (null (openKind StaleFocus noFocus))
    "missing current focus created stale-focus proposal"
  (_, notYetStale) <- selection
    (advanceSelection (addUTCTime (staleFocusAfter - 1) probeTime)
      focusedContext emptySelectionState)
  require (null (openKind StaleFocus notYetStale))
    "fresh focus created stale-focus proposal"
  let standing = selectionContextStanding focusedContext
      coordination = standingStateCoordination standing
      execution = coordinationStateExecution coordination
      domainState = executionStateDomain execution
      malformedFocus = (domainFocusRegister domainState)
        {focusRegisterChangedAt = Nothing}
      malformedDomain = domainState {domainFocusRegister = malformedFocus}
      malformedExecution = execution {executionStateDomain = malformedDomain}
      malformedContext = focusedContext {selectionContextStanding = standing
        {standingStateCoordination = coordination
          {coordinationStateExecution = malformedExecution}}}
  (_, missingTimestamp) <- selection
    (advanceSelection staleAt malformedContext emptySelectionState)
  require (null (openKind StaleFocus missingTimestamp))
    "focus without changed_at created stale-focus proposal"

------------------------------------------------------------
-- Fixtures and helpers
------------------------------------------------------------

contextFixture :: [(Text, BrickBehavior)] ->
  Either Text ([Brick], [Priority.PriorityInsertion], SelectionContext)
contextFixture values = do
  (bricksReversed, insertionsReversed, standing) <- foldM create
    ([], [], emptyStandingState) values
  let bricks = reverse bricksReversed
      material = foldr (\brick -> registerMaterialBrick
        (brickId brick) Active) emptyMaterialState bricks
  pure (bricks, reverse insertionsReversed,
    SelectionContext standing material)
  where
    create (bricks, insertions, state) (titleText, behavior) = do
      title <- domain (mkCanonicalText titleText Nothing Human)
      (brick, insertion, next) <- standingResult (createStandingBrick
        (ordinaryBrickDraft title behavior probeTime) ("probe:" <> titleText)
        probeTime state)
      pure (brick : bricks, insertion : insertions, next)

setFocus :: BrickId -> UTCTime -> SelectionContext -> Either Text SelectionContext
setFocus identifier at context = do
  let standing = selectionContextStanding context
      coordination = standingStateCoordination standing
  execution <- executionResult (focusExecutionBrick identifier at
    (coordinationStateExecution coordination))
  replaceExecution execution context

setPriority :: Priority.PriorityState -> SelectionContext -> Either Text SelectionContext
setPriority priority context =
  let execution = selectionExecution context
  in replaceExecution execution {executionStatePriority = priority} context

setJudgment :: Judgment.JudgmentState -> SelectionContext -> Either Text SelectionContext
setJudgment judgment context =
  let execution = selectionExecution context
  in replaceExecution execution {executionStateJudgment = judgment} context

setAllWip :: SelectionContext -> Either Text SelectionContext
setAllWip context = do
  let execution = selectionExecution context
  domainState <- foldM markWip (executionStateDomain execution)
    (Map.keys (domainBricks (executionStateDomain execution)))
  replaceExecution execution {executionStateDomain = domainState} context
  where
    markWip current identifier = snd <$> domain
      (setBrickWorkState identifier Wip current)

setBrickStatusInContext :: BrickId -> BrickStatus -> SelectionContext -> SelectionContext
setBrickStatusInContext identifier status context =
  let standing = selectionContextStanding context
      coordination = standingStateCoordination standing
      execution = coordinationStateExecution coordination
      domainState = executionStateDomain execution
      bricks = domainBricks domainState
      domain' = domainState {domainBricks = Map.adjust
        (\brick -> brick {brickStatus = status, brickWorkState = Idle}) identifier bricks}
      execution' = execution {executionStateDomain = domain'}
      coordination' = coordination {coordinationStateExecution = execution'}
  in context {selectionContextStanding = standing
      {standingStateCoordination = coordination'}}

replaceExecution :: ExecutionState -> SelectionContext -> Either Text SelectionContext
replaceExecution execution context = do
  let standing = selectionContextStanding context
      coordination = standingStateCoordination standing
      standing' = standing {standingStateCoordination = coordination
        {coordinationStateExecution = execution}}
  standingResult (validateStandingState standing')
  pure context {selectionContextStanding = standing'}

selectionExecution :: SelectionContext -> ExecutionState
selectionExecution = coordinationStateExecution . standingStateCoordination
  . selectionContextStanding

selectionPriority :: SelectionContext -> Priority.PriorityState
selectionPriority = executionStatePriority . selectionExecution

selectionJudgment :: SelectionContext -> Judgment.JudgmentState
selectionJudgment = executionStateJudgment . selectionExecution

openKind :: ProposalKind -> SelectionState -> [Proposal]
openKind kind state = [proposal | proposal <- Map.elems
  (selectionStateProposals state), proposalKind proposal == kind,
  proposalStatus proposal == ProposalOpen]

exactlyOneProposal :: ProposalKind -> SelectionState -> Either Text Proposal
exactlyOneProposal kind state = case openKind kind state of
  [proposal] -> Right proposal
  proposals -> Left ("expected one " <> Text.pack (show kind)
    <> " proposal, found " <> Text.pack (show (length proposals)))

exactlyOne :: Text -> [value] -> Either Text value
exactlyOne _ [value] = Right value
exactlyOne label values = Left (label <> " expected one value, found "
  <> Text.pack (show (length values)))

exactlyTwo :: Text -> [value] -> Either Text (value, value)
exactlyTwo _ [first, second] = Right (first, second)
exactlyTwo label values = Left (label <> " expected two values, found "
  <> Text.pack (show (length values)))

exactlyThree :: Text -> [value] -> Either Text (value, value, value)
exactlyThree _ [first, second, third] = Right (first, second, third)
exactlyThree label values = Left (label <> " expected three values, found "
  <> Text.pack (show (length values)))

exactlyFour :: Text -> [value] -> Either Text (value, value, value, value)
exactlyFour _ [first, second, third, fourth] = Right (first, second, third, fourth)
exactlyFour label values = Left (label <> " expected four values, found "
  <> Text.pack (show (length values)))

requireForecastItem :: BrickId -> ForecastView -> Either Text ForecastItem
requireForecastItem identifier forecast = maybe
  (Left "forecast omitted expected Brick") Right
  (forecastItemForBrick identifier forecast)

exactlyOneKind :: NextDraw -> Bool
exactlyOneKind draw =
  (nextDrawSelectedBrick draw /= Nothing)
    /= (nextDrawSelectedProposal draw /= Nothing)

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 0

expectFailure :: Either problem value -> Text -> Either Text ()
expectFailure result problem = case result of
  Left _ -> Right ()
  Right _ -> Left problem

selection :: Either SelectionError value -> Either Text value
selection = either (Left . Text.pack . show) Right

standingResult :: Either StandingError value -> Either Text value
standingResult = either (Left . Text.pack . show) Right

executionResult :: Either ExecutionError value -> Either Text value
executionResult = either (Left . Text.pack . show) Right

priorityResult :: Either Priority.PriorityError value -> Either Text value
priorityResult = either (Left . Text.pack . show) Right

judgmentResult :: Either Judgment.JudgmentError value -> Either Text value
judgmentResult = either (Left . Text.pack . show) Right

materialResult :: Either MaterialError value -> Either Text value
materialResult = either (Left . Text.pack . show) Right

domain :: Either DomainError value -> Either Text value
domain = either (Left . Text.pack . show) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

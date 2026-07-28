{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Identity-preserving executions, deterministic recurrence, and practices.
--
-- Clock and random evidence are explicit inputs.  The state is canonical and
-- serializable, so replay restores chosen repeat dates, period identities, and
-- motivational projections without consulting adapters or wall-clock state.
module LittleAnt.V1.Standing
  ( ExecutionOccurrence (..)
  , ExecutionOccurrenceId (..)
  , ExecutionOutcome (..)
  , ExecutionStatus (..)
  , ObligationOccurrence (..)
  , ObligationOccurrenceId (..)
  , OpportunityTrigger (..)
  , OpportunityTriggerId (..)
  , OpportunityTriggerStatus (..)
  , PracticeHistoryView (..)
  , PracticeOpportunity (..)
  , PracticeOpportunityId (..)
  , PracticeOpportunityStatus (..)
  , RecurrenceKind (..)
  , RecurrenceRevision (..)
  , RecurrenceRevisionId (..)
  , RecurrenceRule (..)
  , RecurrenceRuleId (..)
  , RepeatScheduleEvidence (..)
  , ScheduleStatus (..)
  , StandingError (..)
  , StandingState (..)
  , TriggeredOpportunity (..)
  , TriggeredOpportunityId (..)
  , abandonExecution
  , abandonPracticeOpportunity
  , addStandingDependency
  , advanceSchedules
  , completePracticeOpportunity
  , completeStandingBrick
  , configureOpportunityTrigger
  , closeStandingSubtree
  , configureRecurrence
  , createStandingBrick
  , deterministicRepeatDate
  , dropStandingBrick
  , emptyStandingState
  , finishRepeatableAndRetire
  , finishRepeatableAndSchedule
  , finishStandingExecution
  , obligationOccurrencesFor
  , pauseRecurrence
  , practiceHistory
  , practiceOpportunitiesFor
  , releaseTriggeredOpportunities
  , retireOpportunityTrigger
  , retireRecurrence
  , retireStandingTarget
  , reviseRecurrence
  , resumeRecurrence
  , startStandingExecution
  , supersedeStandingBrick
  , supersedeStandingBrickWithChildren
  , validateStandingState
  ) where

import Control.Monad (foldM, unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey, Value (..),
   defaultOptions, genericParseJSON, genericToJSON, withText)
import qualified Data.Aeson.Types as AesonTypes
import Data.Char (ord, toLower)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time
  (UTCTime (..), addUTCTime, utctDay)
import Data.Time.Calendar (addGregorianMonthsClip, toGregorian)
import Data.Time.Calendar.WeekDate (toWeekDate)
import GHC.Generics (Generic)
import LittleAnt.V1.Coordination
  (CoordinationError, CoordinationState (..), Dependency (..),
   DependencyStatus (..), addCoordinationDependency, closeCoordinationSubtree,
   completeCoordinationBrick, createCoordinationBrick, dropCoordinationBrick,
   emptyCoordinationState, retireCoordinationStandingBrick,
   supersedeCoordinationBrick, supersedeCoordinationBrickWithChildren,
   validateCoordinationState)
import LittleAnt.V1.Domain
  (Authority, Brick (..), BrickDraft (..), BrickId (..), BrickStatus (..),
   DomainError, DomainState (..), FocusRegister (..), Lifetime (..),
   RepetitionKind (..), WorkState (..), behaviorLifetime, behaviorRepetition,
   mkCanonicalText, ordinaryBrickDraft, returnBrickToIdle, setBrickNotBefore,
   standardV1, subtreeBricks, unfocusCurrentBrick)
import LittleAnt.V1.Execution
  (ExecutionError, ExecutionState (..), focusExecutionBrick,
   validateExecutionState)
import qualified LittleAnt.V1.Priority as Priority
import Text.Read (readMaybe)

------------------------------------------------------------
-- Closed vocabulary and identity
------------------------------------------------------------

data ExecutionStatus = ExecutionRunning | ExecutionFinished | ExecutionAbandoned
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ExecutionOutcome = OutcomeDone | OutcomePartial | OutcomeAbandoned
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data RecurrenceKind = ObligationRecurrence | PracticeRecurrence
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ScheduleStatus = ScheduleActive | SchedulePaused | ScheduleRetired
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data PracticeOpportunityStatus
  = OpportunityOpen
  | OpportunityDone
  | OpportunityNotDone
  | OpportunityNotApplicable
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data OpportunityTriggerStatus = TriggerActive | TriggerRetired
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON ExecutionStatus where toJSON = enumJSON executionStatusText
instance FromJSON ExecutionStatus where
  parseJSON = parseEnum "ExecutionStatus" executionStatusText
instance ToJSON ExecutionOutcome where toJSON = enumJSON executionOutcomeText
instance FromJSON ExecutionOutcome where
  parseJSON = parseEnum "ExecutionOutcome" executionOutcomeText
instance ToJSON RecurrenceKind where toJSON = enumJSON recurrenceKindText
instance FromJSON RecurrenceKind where
  parseJSON = parseEnum "RecurrenceKind" recurrenceKindText
instance ToJSON ScheduleStatus where toJSON = enumJSON scheduleStatusText
instance FromJSON ScheduleStatus where
  parseJSON = parseEnum "ScheduleStatus" scheduleStatusText
instance ToJSON PracticeOpportunityStatus where
  toJSON = enumJSON practiceOpportunityStatusText
instance FromJSON PracticeOpportunityStatus where
  parseJSON = parseEnum "PracticeOpportunityStatus" practiceOpportunityStatusText
instance ToJSON OpportunityTriggerStatus where
  toJSON = enumJSON opportunityTriggerStatusText
instance FromJSON OpportunityTriggerStatus where
  parseJSON = parseEnum "OpportunityTriggerStatus" opportunityTriggerStatusText

enumJSON :: (value -> Text) -> value -> Value
enumJSON render = String . render

parseEnum :: (Bounded value, Enum value) =>
  String -> (value -> Text) -> Value -> AesonTypes.Parser value
parseEnum name render = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate [(render value, value) | value <- [minBound .. maxBound]])

executionStatusText :: ExecutionStatus -> Text
executionStatusText status = case status of
  ExecutionRunning -> "running"
  ExecutionFinished -> "finished"
  ExecutionAbandoned -> "abandoned"

executionOutcomeText :: ExecutionOutcome -> Text
executionOutcomeText outcome = case outcome of
  OutcomeDone -> "done"
  OutcomePartial -> "partial"
  OutcomeAbandoned -> "abandoned"

recurrenceKindText :: RecurrenceKind -> Text
recurrenceKindText kind = case kind of
  ObligationRecurrence -> "obligation"
  PracticeRecurrence -> "practice"

scheduleStatusText :: ScheduleStatus -> Text
scheduleStatusText status = case status of
  ScheduleActive -> "active"
  SchedulePaused -> "paused"
  ScheduleRetired -> "retired"

practiceOpportunityStatusText :: PracticeOpportunityStatus -> Text
practiceOpportunityStatusText status = case status of
  OpportunityOpen -> "open"
  OpportunityDone -> "done"
  OpportunityNotDone -> "not_done"
  OpportunityNotApplicable -> "not_applicable"

opportunityTriggerStatusText :: OpportunityTriggerStatus -> Text
opportunityTriggerStatusText status = case status of
  TriggerActive -> "active"
  TriggerRetired -> "retired"

newtype ExecutionOccurrenceId = ExecutionOccurrenceId {unExecutionOccurrenceId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RecurrenceRuleId = RecurrenceRuleId {unRecurrenceRuleId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype ObligationOccurrenceId = ObligationOccurrenceId {unObligationOccurrenceId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RecurrenceRevisionId = RecurrenceRevisionId {unRecurrenceRevisionId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype PracticeOpportunityId = PracticeOpportunityId {unPracticeOpportunityId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype OpportunityTriggerId = OpportunityTriggerId {unOpportunityTriggerId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype TriggeredOpportunityId = TriggeredOpportunityId {unTriggeredOpportunityId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

------------------------------------------------------------
-- Canonical entities and state
------------------------------------------------------------

data ExecutionOccurrence = ExecutionOccurrence
  { executionOccurrenceId :: ExecutionOccurrenceId
  , executionOccurrenceBrick :: BrickId
  , executionOccurrenceStatus :: ExecutionStatus
  , executionOccurrenceStartedAt :: Maybe UTCTime
  , executionOccurrenceFinishedAt :: Maybe UTCTime
  , executionOccurrenceOutcome :: Maybe ExecutionOutcome
  , executionOccurrenceCompletionNote :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data RecurrenceRule = RecurrenceRule
  { recurrenceRuleId :: RecurrenceRuleId
  , recurrenceRuleTarget :: BrickId
  , recurrenceRuleKind :: RecurrenceKind
  , recurrenceRuleSchedule :: Text
  , recurrenceRuleTimezone :: Text
  , recurrenceRuleStatus :: ScheduleStatus
  , recurrenceRuleNextReleaseAt :: UTCTime
  , recurrenceRuleCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data ObligationOccurrence = ObligationOccurrence
  { obligationOccurrenceId :: ObligationOccurrenceId
  , obligationOccurrenceRule :: RecurrenceRuleId
  , obligationOccurrencePeriodKey :: Text
  , obligationOccurrenceBrick :: BrickId
  , obligationOccurrenceReleasedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data RecurrenceRevision = RecurrenceRevision
  { recurrenceRevisionId :: RecurrenceRevisionId
  , recurrenceRevisionRule :: RecurrenceRuleId
  , recurrenceRevisionPriorSchedule :: Text
  , recurrenceRevisionNewSchedule :: Text
  , recurrenceRevisionPriorTimezone :: Text
  , recurrenceRevisionNewTimezone :: Text
  , recurrenceRevisionNextReleaseAt :: UTCTime
  , recurrenceRevisionReason :: Text
  , recurrenceRevisionAuthority :: Authority
  , recurrenceRevisionRevisedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data PracticeOpportunity = PracticeOpportunity
  { practiceOpportunityId :: PracticeOpportunityId
  , practiceOpportunityRule :: RecurrenceRuleId
  , practiceOpportunityPeriodKey :: Text
  , practiceOpportunityStatus :: PracticeOpportunityStatus
  , practiceOpportunityWindowStart :: UTCTime
  , practiceOpportunityWindowEnd :: UTCTime
  , practiceOpportunityResolvedAt :: Maybe UTCTime
  , practiceOpportunityReason :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data OpportunityTrigger = OpportunityTrigger
  { opportunityTriggerId :: OpportunityTriggerId
  , opportunityTriggerSource :: BrickId
  , opportunityTriggerTarget :: BrickId
  , opportunityTriggerStatus :: OpportunityTriggerStatus
  , opportunityTriggerCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data TriggeredOpportunity = TriggeredOpportunity
  { triggeredOpportunityId :: TriggeredOpportunityId
  , triggeredOpportunityTrigger :: OpportunityTriggerId
  , triggeredOpportunitySourceEventId :: Text
  , triggeredOpportunityTarget :: BrickId
  , triggeredOpportunityReleasedAt :: UTCTime
  , triggeredOpportunityConsumedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

data RepeatScheduleEvidence = RepeatScheduleEvidence
  { repeatScheduleExecution :: ExecutionOccurrenceId
  , repeatScheduleBrick :: BrickId
  , repeatScheduleBaseDelay :: Text
  , repeatScheduleJitterRange :: Text
  , repeatScheduleRandomEvidence :: Text
  , repeatScheduleSelectedMonths :: Integer
  , repeatScheduleNotBefore :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data PracticeHistoryView = PracticeHistoryView
  { practiceHistoryTarget :: BrickId
  , practiceHistoryMarks :: [Text]
  , practiceHistoryCurrentStreak :: Integer
  , practiceHistoryBestStreak :: Integer
  , practiceHistoryApplicableCount :: Integer
  , practiceHistoryDoneCount :: Integer
  , practiceHistoryNotDoneCount :: Integer
  }
  deriving stock (Eq, Show, Generic)

data StandingState = StandingState
  { standingStateRevision :: Integer
  , standingStateNextOrdinal :: Integer
  , standingStateCoordination :: CoordinationState
  , standingStateExecutions :: Map ExecutionOccurrenceId ExecutionOccurrence
  , standingStateRecurrences :: Map RecurrenceRuleId RecurrenceRule
  , standingStateObligations :: Map ObligationOccurrenceId ObligationOccurrence
  , standingStateRecurrenceRevisions :: Map RecurrenceRevisionId RecurrenceRevision
  , standingStatePracticeOpportunities :: Map PracticeOpportunityId PracticeOpportunity
  , standingStateOpportunityTriggers :: Map OpportunityTriggerId OpportunityTrigger
  , standingStateTriggeredOpportunities :: Map TriggeredOpportunityId TriggeredOpportunity
  , standingStateRepeatSchedules :: [RepeatScheduleEvidence]
  , standingStateHistory :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON ExecutionOccurrence where toJSON = genericToJSON (recordOptions "executionOccurrence")
instance FromJSON ExecutionOccurrence where parseJSON = genericParseJSON (recordOptions "executionOccurrence")
instance ToJSON RecurrenceRule where toJSON = genericToJSON (recordOptions "recurrenceRule")
instance FromJSON RecurrenceRule where parseJSON = genericParseJSON (recordOptions "recurrenceRule")
instance ToJSON ObligationOccurrence where toJSON = genericToJSON (recordOptions "obligationOccurrence")
instance FromJSON ObligationOccurrence where parseJSON = genericParseJSON (recordOptions "obligationOccurrence")
instance ToJSON RecurrenceRevision where toJSON = genericToJSON (recordOptions "recurrenceRevision")
instance FromJSON RecurrenceRevision where parseJSON = genericParseJSON (recordOptions "recurrenceRevision")
instance ToJSON PracticeOpportunity where toJSON = genericToJSON (recordOptions "practiceOpportunity")
instance FromJSON PracticeOpportunity where parseJSON = genericParseJSON (recordOptions "practiceOpportunity")
instance ToJSON OpportunityTrigger where toJSON = genericToJSON (recordOptions "opportunityTrigger")
instance FromJSON OpportunityTrigger where parseJSON = genericParseJSON (recordOptions "opportunityTrigger")
instance ToJSON TriggeredOpportunity where toJSON = genericToJSON (recordOptions "triggeredOpportunity")
instance FromJSON TriggeredOpportunity where parseJSON = genericParseJSON (recordOptions "triggeredOpportunity")
instance ToJSON RepeatScheduleEvidence where toJSON = genericToJSON (recordOptions "repeatSchedule")
instance FromJSON RepeatScheduleEvidence where parseJSON = genericParseJSON (recordOptions "repeatSchedule")
instance ToJSON PracticeHistoryView where toJSON = genericToJSON (recordOptions "practiceHistory")
instance FromJSON PracticeHistoryView where parseJSON = genericParseJSON (recordOptions "practiceHistory")
instance ToJSON StandingState where toJSON = genericToJSON (recordOptions "standingState")
instance FromJSON StandingState where parseJSON = genericParseJSON (recordOptions "standingState")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLower first : rest)

data StandingError
  = StandingCoordinationError CoordinationError
  | StandingDomainError DomainError
  | StandingExecutionError ExecutionError
  | StandingPriorityError Priority.PriorityError
  | StandingUnknownEntity Text
  | StandingInvalidTransition Text
  | StandingInvalidSchedule Text
  | StandingInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

emptyStandingState :: StandingState
emptyStandingState = StandingState
  { standingStateRevision = 0
  , standingStateNextOrdinal = 1
  , standingStateCoordination = emptyCoordinationState
  , standingStateExecutions = Map.empty
  , standingStateRecurrences = Map.empty
  , standingStateObligations = Map.empty
  , standingStateRecurrenceRevisions = Map.empty
  , standingStatePracticeOpportunities = Map.empty
  , standingStateOpportunityTriggers = Map.empty
  , standingStateTriggeredOpportunities = Map.empty
  , standingStateRepeatSchedules = []
  , standingStateHistory = []
  }

------------------------------------------------------------
-- Coordinated Brick helpers
------------------------------------------------------------

createStandingBrick ::
  BrickDraft -> Text -> UTCTime -> StandingState ->
  Either StandingError (Brick, Priority.PriorityInsertion, StandingState)
createStandingBrick draft evidence now state = do
  (brick, insertion, coordination) <- mapCoordination
    (createCoordinationBrick draft evidence now (standingStateCoordination state))
  next <- commit "brick_created" state {standingStateCoordination = coordination}
  pure (brick, insertion, next)

addStandingDependency ::
  BrickId -> BrickId -> UTCTime -> StandingState ->
  Either StandingError StandingState
addStandingDependency blocked blocker now state = do
  (_, coordination) <- mapCoordination (addCoordinationDependency blocked blocker now
    (standingStateCoordination state))
  commit "dependency_added" state {standingStateCoordination = coordination}

completeStandingBrick ::
  BrickId -> Maybe Text -> Text -> UTCTime -> StandingState ->
  Either StandingError StandingState
completeStandingBrick identifier _note sourceEventId now state = do
  coordination <- mapCoordination (completeCoordinationBrick identifier now
    (standingStateCoordination state))
  released <- releaseTriggeredOpportunities identifier sourceEventId now state
    {standingStateCoordination = coordination}
  commit "brick_completed" (retireFutureMechanics identifier now released)

retireStandingTarget ::
  BrickId -> UTCTime -> StandingState -> Either StandingError StandingState
retireStandingTarget identifier now state = do
  coordination <- mapCoordination (retireCoordinationStandingBrick identifier now
    (standingStateCoordination state))
  commit "standing_target_retired" (retireFutureMechanics identifier now state
    {standingStateCoordination = coordination})

dropStandingBrick ::
  BrickId -> UTCTime -> StandingState -> Either StandingError StandingState
dropStandingBrick identifier now state = do
  coordination <- mapCoordination (dropCoordinationBrick identifier now
    (standingStateCoordination state))
  commit "brick_dropped" (retireFutureMechanics identifier now state
    {standingStateCoordination = coordination})

supersedeStandingBrick ::
  BrickId -> BrickId -> Maybe Text -> UTCTime -> StandingState ->
  Either StandingError StandingState
supersedeStandingBrick identifier replacement reason now state = do
  coordination <- mapCoordination (supersedeCoordinationBrick identifier replacement
    reason now (standingStateCoordination state))
  commit "brick_superseded" (retireFutureMechanics identifier now state
    {standingStateCoordination = coordination})

supersedeStandingBrickWithChildren ::
  BrickId -> BrickId -> [BrickId] -> Maybe Text -> Text -> UTCTime ->
  StandingState -> Either StandingError
    ([Priority.PriorityInsertion], StandingState)
supersedeStandingBrickWithChildren identifier replacement selected reason evidence
    now state = do
  (insertions, coordination) <- mapCoordination
    (supersedeCoordinationBrickWithChildren identifier replacement selected reason
      evidence now (standingStateCoordination state))
  committed <- commit "brick_superseded_with_children"
    (retireFutureMechanics identifier now state
      {standingStateCoordination = coordination})
  pure (insertions, committed)

closeStandingSubtree ::
  BrickId -> BrickStatus -> UTCTime -> StandingState ->
  Either StandingError StandingState
closeStandingSubtree root status now state = do
  members <- mapDomain (subtreeBricks
    (executionStateDomain (coordinationExecution state)) root)
  let terminalIds = map brickId (filter ((== Active) . brickStatus) members)
  coordination <- mapCoordination (closeCoordinationSubtree root status now
    (standingStateCoordination state))
  released <- if status == Done
    then foldM (releaseCompletion now) state
      {standingStateCoordination = coordination} terminalIds
    else Right state {standingStateCoordination = coordination}
  commit (if status == Done then "subtree_completed" else "subtree_dropped")
    (retireFutureMechanicsFor terminalIds now released)
  where
    releaseCompletion at current identifier = releaseTriggeredOpportunities identifier
      ("subtree-completed:" <> Text.pack (show (standingStateRevision state + 1))
        <> ":" <> unBrickId identifier) at current

------------------------------------------------------------
-- Execution occurrences and completion-triggered repeat
------------------------------------------------------------

startStandingExecution ::
  BrickId -> UTCTime -> StandingState ->
  Either StandingError (ExecutionOccurrence, StandingState)
startStandingExecution identifier now state = do
  brick <- requireBrick identifier state
  unless (brickStatus brick == Active)
    (Left (StandingInvalidTransition "only active work can start an execution"))
  unless (behaviorLifetime (brickBehavior brick) == Standing)
    (Left (StandingInvalidTransition "only standing work has execution occurrences"))
  when (any (\execution -> executionOccurrenceBrick execution == identifier
      && executionOccurrenceStatus execution == ExecutionRunning)
      (Map.elems (standingStateExecutions state)))
    (Left (StandingInvalidTransition "Brick already has a running execution"))
  executionState <- mapExecution
    (focusExecutionBrick identifier now (coordinationExecution state))
  let (executionId, allocated) = allocateId "execution" ExecutionOccurrenceId state
      occurrence = ExecutionOccurrence executionId identifier ExecutionRunning
        (Just now) Nothing Nothing Nothing
      changed = setCoordinationExecution executionState allocated
        {standingStateExecutions = Map.insert executionId occurrence
          (standingStateExecutions allocated)}
  committed <- commit "standing_execution_started" changed
  pure (occurrence, committed)

finishStandingExecution ::
  ExecutionOccurrenceId -> ExecutionOutcome -> Maybe Text -> UTCTime ->
  StandingState -> Either StandingError (ExecutionOccurrence, StandingState)
finishStandingExecution identifier outcome note now state = do
  occurrence <- requireExecution identifier state
  requireRunning occurrence
  brick <- requireBrick (executionOccurrenceBrick occurrence) state
  when (behaviorRepetition (brickBehavior brick) == CompletionTriggered)
    (Left (StandingInvalidTransition
      "completion-triggered execution requires a repeat or retire outcome"))
  settled <- settleExecutionBrick (brickId brick) Nothing now state
  let updated = occurrence
        { executionOccurrenceStatus = ExecutionFinished
        , executionOccurrenceFinishedAt = Just now
        , executionOccurrenceOutcome = Just outcome
        , executionOccurrenceCompletionNote = note
        }
      withExecution = settled {standingStateExecutions = Map.insert identifier updated
        (standingStateExecutions settled)}
      eventId = executionEventId updated
  released <- releaseTriggeredOpportunities (brickId brick) eventId now withExecution
  let consumed = consumeTriggeredOpportunity (brickId brick) now released
  committed <- commit "standing_execution_finished" consumed
  pure (updated, committed)

abandonExecution ::
  ExecutionOccurrenceId -> Maybe Text -> UTCTime -> StandingState ->
  Either StandingError (ExecutionOccurrence, StandingState)
abandonExecution identifier note now state = do
  occurrence <- requireExecution identifier state
  requireRunning occurrence
  settled <- settleExecutionBrick (executionOccurrenceBrick occurrence) Nothing now state
  let updated = occurrence
        { executionOccurrenceStatus = ExecutionAbandoned
        , executionOccurrenceFinishedAt = Just now
        , executionOccurrenceOutcome = Just OutcomeAbandoned
        , executionOccurrenceCompletionNote = note
        }
      changed = settled {standingStateExecutions = Map.insert identifier updated
        (standingStateExecutions settled)}
  committed <- commit "standing_execution_abandoned" changed
  pure (updated, committed)

finishRepeatableAndSchedule ::
  ExecutionOccurrenceId -> Maybe Text -> Text -> Text -> Text -> UTCTime ->
  StandingState ->
  Either StandingError (ExecutionOccurrence, RepeatScheduleEvidence, StandingState)
finishRepeatableAndSchedule identifier note baseDelay jitterRange randomEvidence now state = do
  occurrence <- requireExecution identifier state
  requireRunning occurrence
  brick <- requireBrick (executionOccurrenceBrick occurrence) state
  unless (behaviorRepetition (brickBehavior brick) == CompletionTriggered)
    (Left (StandingInvalidTransition "Brick is not completion-triggered"))
  (selectedMonths, notBefore) <- deterministicRepeatDate now baseDelay jitterRange
    randomEvidence
  settled <- settleExecutionBrick (brickId brick) (Just notBefore) now state
  let updated = occurrence
        { executionOccurrenceStatus = ExecutionFinished
        , executionOccurrenceFinishedAt = Just now
        , executionOccurrenceOutcome = Just OutcomeDone
        , executionOccurrenceCompletionNote = note
        }
      evidence = RepeatScheduleEvidence identifier (brickId brick) baseDelay jitterRange
        randomEvidence selectedMonths notBefore
      changed = settled
        { standingStateExecutions = Map.insert identifier updated
            (standingStateExecutions settled)
        , standingStateRepeatSchedules = standingStateRepeatSchedules settled <> [evidence]
        }
  released <- releaseTriggeredOpportunities (brickId brick)
    (executionEventId updated) now changed
  let consumed = consumeTriggeredOpportunity (brickId brick) now released
  committed <- commit "repeatable_execution_scheduled" consumed
  pure (updated, evidence, committed)

finishRepeatableAndRetire ::
  ExecutionOccurrenceId -> Maybe Text -> UTCTime -> StandingState ->
  Either StandingError (ExecutionOccurrence, StandingState)
finishRepeatableAndRetire identifier note now state = do
  occurrence <- requireExecution identifier state
  requireRunning occurrence
  brick <- requireBrick (executionOccurrenceBrick occurrence) state
  unless (behaviorRepetition (brickBehavior brick) == CompletionTriggered)
    (Left (StandingInvalidTransition "Brick is not completion-triggered"))
  coordination <- mapCoordination
    (retireCoordinationStandingBrick (brickId brick) now
      (standingStateCoordination state))
  let updated = occurrence
        { executionOccurrenceStatus = ExecutionFinished
        , executionOccurrenceFinishedAt = Just now
        , executionOccurrenceOutcome = Just OutcomeDone
        , executionOccurrenceCompletionNote = note
        }
      changed = state
        { standingStateCoordination = coordination
        , standingStateExecutions = Map.insert identifier updated
          (standingStateExecutions state)}
  released <- releaseTriggeredOpportunities (brickId brick)
    (executionEventId updated) now changed
  let terminal = retireFutureMechanics (brickId brick) now
        (consumeTriggeredOpportunity (brickId brick) now released)
  committed <- commit "repeatable_execution_retired" terminal
  pure (updated, committed)

-- | Parse month durations and choose one replay-safe month count in the
-- inclusive @base +/- jitter@ range.
deterministicRepeatDate ::
  UTCTime -> Text -> Text -> Text -> Either StandingError (Integer, UTCTime)
deterministicRepeatDate now baseDelay jitterRange evidence = do
  base <- parseMonthDuration baseDelay
  jitter <- parseMonthDuration jitterRange
  let width = 2 * jitter + 1
      evidenceNumber = Text.foldl' (\total character ->
        (total * 131 + fromIntegral (ord character)) `mod` 2147483647) 0 evidence
      offset = if width <= 0 then 0 else evidenceNumber `mod` width - jitter
      selected = max 0 (base + offset)
      selectedDate = addCalendarMonths selected now
  pure (selected, selectedDate)

parseMonthDuration :: Text -> Either StandingError Integer
parseMonthDuration value = case Text.stripPrefix "P" value >>= Text.stripSuffix "M" of
  Just encoded -> case readMaybe (Text.unpack encoded) of
    Just months | months >= 0 -> Right months
    _ -> invalid
  Nothing -> invalid
  where
    invalid = Left (StandingInvalidSchedule
      ("duration must be a nonnegative calendar-month duration: " <> value))

addCalendarMonths :: Integer -> UTCTime -> UTCTime
addCalendarMonths months (UTCTime day time) =
  UTCTime (addGregorianMonthsClip months day) time

------------------------------------------------------------
-- Recurrence, obligations, and practices
------------------------------------------------------------

configureRecurrence ::
  BrickId -> RecurrenceKind -> Text -> Text -> UTCTime -> UTCTime ->
  StandingState -> Either StandingError (RecurrenceRule, StandingState)
configureRecurrence target kind schedule timezone firstRelease now state = do
  brick <- requireBrick target state
  unless (brickStatus brick == Active)
    (Left (StandingInvalidTransition "recurrence target must be active"))
  let expected = case kind of
        ObligationRecurrence -> RecurringObligation
        PracticeRecurrence -> Practice
  unless (behaviorRepetition (brickBehavior brick) == expected)
    (Left (StandingInvalidTransition "recurrence kind disagrees with target behavior"))
  validateSchedule kind schedule
  when (any (\rule -> recurrenceRuleTarget rule == target
      && recurrenceRuleKind rule == kind
      && recurrenceRuleStatus rule `elem` [ScheduleActive, SchedulePaused])
      (Map.elems (standingStateRecurrences state)))
    (Left (StandingInvalidTransition "target already has a live recurrence of this kind"))
  let (identifier, allocated) = allocateId "recurrence" RecurrenceRuleId state
      rule = RecurrenceRule identifier target kind schedule timezone ScheduleActive
        firstRelease now
      changed = allocated {standingStateRecurrences = Map.insert identifier rule
        (standingStateRecurrences allocated)}
  committed <- commit "recurrence_configured" changed
  pure (rule, committed)

pauseRecurrence ::
  RecurrenceRuleId -> UTCTime -> StandingState ->
  Either StandingError (RecurrenceRule, StandingState)
pauseRecurrence identifier now state = do
  rule <- requireRecurrence identifier state
  unless (recurrenceRuleStatus rule == ScheduleActive)
    (Left (StandingInvalidTransition "only an active recurrence can pause"))
  let updated = rule {recurrenceRuleStatus = SchedulePaused}
      changed = resolveOpenPractice identifier OpportunityNotApplicable now
        "recurrence_paused" state
          {standingStateRecurrences = Map.insert identifier updated
            (standingStateRecurrences state)}
  committed <- commit "recurrence_paused" changed
  pure (updated, committed)

resumeRecurrence ::
  RecurrenceRuleId -> UTCTime -> StandingState ->
  Either StandingError (RecurrenceRule, StandingState)
resumeRecurrence identifier nextRelease state = do
  rule <- requireRecurrence identifier state
  unless (recurrenceRuleStatus rule == SchedulePaused)
    (Left (StandingInvalidTransition "only a paused recurrence can resume"))
  let updated = rule
        {recurrenceRuleStatus = ScheduleActive,
         recurrenceRuleNextReleaseAt = nextRelease}
      changed = state {standingStateRecurrences = Map.insert identifier updated
        (standingStateRecurrences state)}
  committed <- commit "recurrence_resumed" changed
  pure (updated, committed)

retireRecurrence ::
  RecurrenceRuleId -> UTCTime -> StandingState ->
  Either StandingError (RecurrenceRule, StandingState)
retireRecurrence identifier now state = do
  rule <- requireRecurrence identifier state
  unless (recurrenceRuleStatus rule `elem` [ScheduleActive, SchedulePaused])
    (Left (StandingInvalidTransition "recurrence is already retired"))
  let updated = rule {recurrenceRuleStatus = ScheduleRetired}
      changed = resolveOpenPractice identifier OpportunityNotApplicable now
        "recurrence_retired" state
          {standingStateRecurrences = Map.insert identifier updated
            (standingStateRecurrences state)}
  committed <- commit "recurrence_retired" changed
  pure (updated, committed)

reviseRecurrence ::
  RecurrenceRuleId -> Text -> Text -> UTCTime -> Text -> Authority -> UTCTime ->
  StandingState -> Either StandingError (RecurrenceRevision, StandingState)
reviseRecurrence identifier schedule timezone nextRelease reason authority now state = do
  rule <- requireRecurrence identifier state
  unless (recurrenceRuleStatus rule `elem` [ScheduleActive, SchedulePaused])
    (Left (StandingInvalidTransition "retired recurrence cannot be revised"))
  validateSchedule (recurrenceRuleKind rule) schedule
  let (revisionId, allocated) = allocateId "recurrence-revision"
        RecurrenceRevisionId state
      revision = RecurrenceRevision revisionId identifier
        (recurrenceRuleSchedule rule) schedule (recurrenceRuleTimezone rule) timezone
        nextRelease reason authority now
      updated = rule
        { recurrenceRuleSchedule = schedule
        , recurrenceRuleTimezone = timezone
        , recurrenceRuleNextReleaseAt = nextRelease
        }
      changed = allocated
        { standingStateRecurrences = Map.insert identifier updated
            (standingStateRecurrences allocated)
        , standingStateRecurrenceRevisions = Map.insert revisionId revision
            (standingStateRecurrenceRevisions allocated)
        }
  committed <- commit "recurrence_revised" changed
  pure (revision, committed)

advanceSchedules ::
  UTCTime -> StandingState ->
  Either StandingError ([ObligationOccurrence], [PracticeOpportunity], StandingState)
advanceSchedules at state = do
  let expired = expirePracticeOpportunities at state
      beforeObligations = Map.keysSet (standingStateObligations expired)
      beforePractices = Map.keysSet (standingStatePracticeOpportunities expired)
  released <- foldM (advanceOneRecurrence at) expired
    (sortOn recurrenceRuleId (Map.elems (standingStateRecurrences expired)))
  committed <- commit "schedules_advanced" released
  let obligations = sortOn obligationOccurrenceId
        [occurrence | (identifier, occurrence) <- Map.toList
          (standingStateObligations committed),
          Set.notMember identifier beforeObligations]
      practices = sortOn practiceOpportunityId
        [opportunity | (identifier, opportunity) <- Map.toList
          (standingStatePracticeOpportunities committed),
          Set.notMember identifier beforePractices]
  pure (obligations, practices, committed)

advanceOneRecurrence ::
  UTCTime -> StandingState -> RecurrenceRule -> Either StandingError StandingState
advanceOneRecurrence at state original = do
  rule <- requireRecurrence (recurrenceRuleId original) state
  if recurrenceRuleStatus rule == ScheduleRetired
      || recurrenceRuleNextReleaseAt rule > at
    then Right state
    else do
      (periods, nextRelease) <- duePeriods rule at
      released <- case recurrenceRuleKind rule of
        ObligationRecurrence
          | recurrenceRuleStatus rule == ScheduleActive ->
              foldM (releaseObligation rule at) state periods
          | otherwise -> Right state
        PracticeRecurrence -> foldM
          (releasePractice rule at (practiceIsApplicable rule state)) state periods
      let current = Map.findWithDefault rule (recurrenceRuleId rule)
            (standingStateRecurrences released)
          advanced = current {recurrenceRuleNextReleaseAt = nextRelease}
      pure released {standingStateRecurrences = Map.insert (recurrenceRuleId rule)
        advanced (standingStateRecurrences released)}

releaseObligation ::
  RecurrenceRule -> UTCTime -> StandingState -> SchedulePeriod ->
  Either StandingError StandingState
releaseObligation rule releasedAt state period
  | any (\occurrence -> obligationOccurrenceRule occurrence == recurrenceRuleId rule
      && obligationOccurrencePeriodKey occurrence == schedulePeriodKey period)
      (Map.elems (standingStateObligations state)) = Right state
  | otherwise = do
      owner <- requireBrick (recurrenceRuleTarget rule) state
      title <- mapDomain (mkCanonicalText
        (brickTitle owner <> " · " <> schedulePeriodDisplay period) Nothing
        (brickTitleAuthority owner))
      let draft = (ordinaryBrickDraft title standardV1 releasedAt)
            { brickDraftParent = Just (recurrenceRuleTarget rule)
            , brickDraftNotBefore = Just (schedulePeriodStart period)
            }
      (brick, insertion, coordination) <- mapCoordination
        (createCoordinationBrick draft (schedulePeriodKey period) releasedAt
          (standingStateCoordination state))
      let execution = coordinationStateExecution coordination
      (_, deferredPriority) <- mapPriority (Priority.deferPriorityInsertion
        (Priority.priorityInsertionId insertion) releasedAt
        (executionStatePriority execution))
      let deferredExecution = execution {executionStatePriority = deferredPriority}
          deferredCoordination = coordination
            {coordinationStateExecution = deferredExecution}
      mapCoordination (validateCoordinationState deferredCoordination)
      let (occurrenceId, allocated) = allocateId "obligation-occurrence"
            ObligationOccurrenceId state
          occurrence = ObligationOccurrence occurrenceId (recurrenceRuleId rule)
            (schedulePeriodKey period) (brickId brick) releasedAt
      pure allocated
        { standingStateCoordination = deferredCoordination
        , standingStateObligations = Map.insert occurrenceId occurrence
            (standingStateObligations allocated)
        }

releasePractice ::
  RecurrenceRule -> UTCTime -> Bool -> StandingState -> SchedulePeriod ->
  Either StandingError StandingState
releasePractice rule releasedAt applicable state period = foldM releaseSlot state
  [1 .. schedulePeriodQuota period]
  where
    releaseSlot current slot =
      let periodKey = schedulePeriodKey period <> ":" <> Text.pack (show slot)
      in if any (\opportunity -> practiceOpportunityRule opportunity
            == recurrenceRuleId rule
            && practiceOpportunityPeriodKey opportunity == periodKey)
            (Map.elems (standingStatePracticeOpportunities current))
          then Right current
          else let
            (identifier, allocated) = allocateId "practice-opportunity"
              PracticeOpportunityId current
            status = if applicable then OpportunityOpen
              else OpportunityNotApplicable
            opportunity = PracticeOpportunity identifier (recurrenceRuleId rule)
              periodKey status (schedulePeriodStart period) (schedulePeriodEnd period)
              (if applicable then Nothing else Just releasedAt)
              (if applicable then Nothing else Just (inapplicableReason rule current))
            in Right allocated {standingStatePracticeOpportunities = Map.insert
                identifier opportunity (standingStatePracticeOpportunities allocated)}

completePracticeOpportunity ::
  PracticeOpportunityId -> Maybe Text -> UTCTime -> StandingState ->
  Either StandingError (PracticeOpportunity, ExecutionOccurrence, StandingState)
completePracticeOpportunity identifier note now state = do
  opportunity <- requirePractice identifier state
  unless (practiceOpportunityStatus opportunity == OpportunityOpen)
    (Left (StandingInvalidTransition "only an open practice opportunity can complete"))
  rule <- requireRecurrence (practiceOpportunityRule opportunity) state
  let updated = opportunity
        { practiceOpportunityStatus = OpportunityDone
        , practiceOpportunityResolvedAt = Just now
        }
      (executionId, allocated) = allocateId "execution" ExecutionOccurrenceId state
      execution = ExecutionOccurrence executionId (recurrenceRuleTarget rule)
        ExecutionFinished Nothing (Just now) (Just OutcomeDone) note
      changed = allocated
        { standingStatePracticeOpportunities = Map.insert identifier updated
            (standingStatePracticeOpportunities allocated)
        , standingStateExecutions = Map.insert executionId execution
            (standingStateExecutions allocated)
        }
  released <- releaseTriggeredOpportunities (recurrenceRuleTarget rule)
    (executionEventId execution) now changed
  let consumed = consumeTriggeredOpportunity (recurrenceRuleTarget rule) now released
  committed <- commit "practice_opportunity_completed" consumed
  pure (updated, execution, committed)

abandonPracticeOpportunity ::
  PracticeOpportunityId -> Maybe Text -> UTCTime -> StandingState ->
  Either StandingError (PracticeOpportunity, StandingState)
abandonPracticeOpportunity identifier reason now state = do
  opportunity <- requirePractice identifier state
  unless (practiceOpportunityStatus opportunity == OpportunityOpen)
    (Left (StandingInvalidTransition "only an open practice opportunity can be abandoned"))
  let updated = opportunity
        { practiceOpportunityStatus = OpportunityNotDone
        , practiceOpportunityResolvedAt = Just now
        , practiceOpportunityReason = reason
        }
      changed = state {standingStatePracticeOpportunities = Map.insert identifier updated
        (standingStatePracticeOpportunities state)}
  committed <- commit "practice_opportunity_abandoned" changed
  pure (updated, committed)

practiceHistory :: RecurrenceRuleId -> Maybe UTCTime -> Int -> StandingState ->
  Either StandingError PracticeHistoryView
practiceHistory identifier through limit state = do
  rule <- requireRecurrence identifier state
  unless (recurrenceRuleKind rule == PracticeRecurrence)
    (Left (StandingInvalidTransition "obligation recurrence has no practice history"))
  when (limit < 0) (Left (StandingInvalidSchedule "history limit cannot be negative"))
  let ordered = sortOn (\opportunity ->
        (practiceOpportunityWindowStart opportunity, practiceOpportunityPeriodKey opportunity))
        [opportunity | opportunity <- Map.elems (standingStatePracticeOpportunities state),
          practiceOpportunityRule opportunity == identifier,
          maybe True (practiceOpportunityWindowStart opportunity <=) through]
      selected = if limit == 0 then [] else drop (max 0 (length ordered - limit)) ordered
      statuses = map practiceOpportunityStatus selected
      marks = map practiceMark statuses
      doneCount = countStatus OpportunityDone statuses
      notDoneCount = countStatus OpportunityNotDone statuses
      applicableCount = doneCount + notDoneCount
      streaks = practiceStreaks statuses
  pure PracticeHistoryView
    { practiceHistoryTarget = recurrenceRuleTarget rule
    , practiceHistoryMarks = marks
    , practiceHistoryCurrentStreak = fromIntegral (currentPracticeStreak statuses)
    , practiceHistoryBestStreak = fromIntegral (maximum (0 : streaks))
    , practiceHistoryApplicableCount = fromIntegral applicableCount
    , practiceHistoryDoneCount = fromIntegral doneCount
    , practiceHistoryNotDoneCount = fromIntegral notDoneCount
    }

practiceOpportunitiesFor ::
  RecurrenceRuleId -> Maybe Text -> StandingState -> [PracticeOpportunity]
practiceOpportunitiesFor identifier period state = sortOn practiceOpportunityPeriodKey
  [opportunity | opportunity <- Map.elems (standingStatePracticeOpportunities state),
    practiceOpportunityRule opportunity == identifier,
    maybe True (`Text.isPrefixOf` practiceOpportunityPeriodKey opportunity) period]

obligationOccurrencesFor ::
  RecurrenceRuleId -> Maybe Text -> StandingState -> [ObligationOccurrence]
obligationOccurrencesFor identifier period state = sortOn obligationOccurrencePeriodKey
  [occurrence | occurrence <- Map.elems (standingStateObligations state),
    obligationOccurrenceRule occurrence == identifier,
    maybe True (== obligationOccurrencePeriodKey occurrence) period]

------------------------------------------------------------
-- Event-triggered opportunities
------------------------------------------------------------

configureOpportunityTrigger ::
  BrickId -> BrickId -> UTCTime -> StandingState ->
  Either StandingError (OpportunityTrigger, StandingState)
configureOpportunityTrigger source target now state = do
  when (source == target)
    (Left (StandingInvalidTransition "opportunity trigger source and target differ"))
  sourceBrick <- requireBrick source state
  targetBrick <- requireBrick target state
  unless (brickStatus sourceBrick == Active && brickStatus targetBrick == Active)
    (Left (StandingInvalidTransition "opportunity trigger endpoints must be active"))
  unless (behaviorRepetition (brickBehavior targetBrick) == Practice)
    (Left (StandingInvalidTransition "opportunity target must support practice"))
  when (any (\trigger -> opportunityTriggerSource trigger == source
      && opportunityTriggerTarget trigger == target
      && opportunityTriggerStatus trigger == TriggerActive)
      (Map.elems (standingStateOpportunityTriggers state)))
    (Left (StandingInvalidTransition "active opportunity trigger already exists"))
  let (identifier, allocated) = allocateId "opportunity-trigger"
        OpportunityTriggerId state
      trigger = OpportunityTrigger identifier source target TriggerActive now
      changed = allocated {standingStateOpportunityTriggers = Map.insert identifier trigger
        (standingStateOpportunityTriggers allocated)}
  committed <- commit "opportunity_trigger_configured" changed
  pure (trigger, committed)

retireOpportunityTrigger ::
  OpportunityTriggerId -> StandingState ->
  Either StandingError (OpportunityTrigger, StandingState)
retireOpportunityTrigger identifier state = do
  trigger <- requireTrigger identifier state
  unless (opportunityTriggerStatus trigger == TriggerActive)
    (Left (StandingInvalidTransition "opportunity trigger is already retired"))
  let updated = trigger {opportunityTriggerStatus = TriggerRetired}
      changed = state {standingStateOpportunityTriggers = Map.insert identifier updated
        (standingStateOpportunityTriggers state)}
  committed <- commit "opportunity_trigger_retired" changed
  pure (updated, committed)

-- | Deterministically release each matching active trigger at most once for
-- one canonical source event. Re-running this fold for retry/replay is a no-op.
releaseTriggeredOpportunities ::
  BrickId -> Text -> UTCTime -> StandingState -> Either StandingError StandingState
releaseTriggeredOpportunities source sourceEventId now state = foldM release state
  [trigger | trigger <- sortOn opportunityTriggerId
    (Map.elems (standingStateOpportunityTriggers state)),
    opportunityTriggerSource trigger == source,
    opportunityTriggerStatus trigger == TriggerActive]
  where
    release current trigger
      | any (\opportunity -> triggeredOpportunityTrigger opportunity
          == opportunityTriggerId trigger
          && triggeredOpportunitySourceEventId opportunity == sourceEventId)
          (Map.elems (standingStateTriggeredOpportunities current)) = Right current
      | otherwise =
          let (identifier, allocated) = allocateId "triggered-opportunity"
                TriggeredOpportunityId current
              opportunity = TriggeredOpportunity identifier
                (opportunityTriggerId trigger) sourceEventId
                (opportunityTriggerTarget trigger) now Nothing
          in Right allocated {standingStateTriggeredOpportunities = Map.insert
              identifier opportunity (standingStateTriggeredOpportunities allocated)}

consumeTriggeredOpportunity :: BrickId -> UTCTime -> StandingState -> StandingState
consumeTriggeredOpportunity target now state = case sortOn
    (\opportunity -> (triggeredOpportunityReleasedAt opportunity,
      triggeredOpportunityId opportunity))
    [opportunity | opportunity <- Map.elems (standingStateTriggeredOpportunities state),
      triggeredOpportunityTarget opportunity == target,
      triggeredOpportunityConsumedAt opportunity == Nothing] of
  [] -> state
  opportunity : _ ->
    let updated = opportunity {triggeredOpportunityConsumedAt = Just now}
    in state {standingStateTriggeredOpportunities = Map.insert
        (triggeredOpportunityId opportunity) updated
        (standingStateTriggeredOpportunities state)}

------------------------------------------------------------
-- Schedule policy and projections
------------------------------------------------------------

data SchedulePeriod = SchedulePeriod
  { schedulePeriodKey :: Text
  , schedulePeriodDisplay :: Text
  , schedulePeriodStart :: UTCTime
  , schedulePeriodEnd :: UTCTime
  , schedulePeriodQuota :: Int
  }

validateSchedule :: RecurrenceKind -> Text -> Either StandingError ()
validateSchedule kind schedule = case (kind, schedule) of
  (ObligationRecurrence, "monthly on day 1") -> Right ()
  (PracticeRecurrence, value)
    | Just quota <- practiceQuota value, quota > 0 -> Right ()
  _ -> Left (StandingInvalidSchedule ("unsupported deterministic schedule: " <> schedule))

practiceQuota :: Text -> Maybe Int
practiceQuota value = do
  encoded <- Text.stripSuffix " times per ISO week" value
  readMaybe (Text.unpack encoded)

duePeriods :: RecurrenceRule -> UTCTime ->
  Either StandingError ([SchedulePeriod], UTCTime)
duePeriods rule through = case recurrenceRuleKind rule of
  ObligationRecurrence -> monthly (recurrenceRuleNextReleaseAt rule) []
  PracticeRecurrence -> case practiceQuota (recurrenceRuleSchedule rule) of
    Nothing -> Left (StandingInvalidSchedule (recurrenceRuleSchedule rule))
    Just quota -> weekly quota (recurrenceRuleNextReleaseAt rule) []
  where
    monthly cursor periods
      | cursor > through = Right (reverse periods, cursor)
      | otherwise = monthly (addCalendarMonths 1 cursor)
          (monthlyPeriod cursor : periods)
    weekly quota cursor periods
      | cursor > through = Right (reverse periods, cursor)
      | otherwise = weekly quota (addUTCTime weekSeconds cursor)
          (weeklyPeriod quota cursor : periods)

monthlyPeriod :: UTCTime -> SchedulePeriod
monthlyPeriod start =
  let (year, month, _) = toGregorian (utctDay start)
      key = Text.pack (show year) <> "-" <> pad2 month
  in SchedulePeriod key key start (addCalendarMonths 1 start) 1

weeklyPeriod :: Int -> UTCTime -> SchedulePeriod
weeklyPeriod quota start =
  let (year, week, _) = toWeekDate (utctDay start)
      key = Text.pack (show year) <> "-W" <> pad2 week
  in SchedulePeriod key key start (addUTCTime weekSeconds start) quota

pad2 :: Show value => value -> Text
pad2 value = let encoded = Text.pack (show value)
  in if Text.length encoded < 2 then "0" <> encoded else encoded

weekSeconds :: RealFrac value => value
weekSeconds = 7 * 24 * 60 * 60

practiceIsApplicable :: RecurrenceRule -> StandingState -> Bool
practiceIsApplicable rule state = recurrenceRuleStatus rule == ScheduleActive
  && not (brickIsBlocked (recurrenceRuleTarget rule) state)

brickIsBlocked :: BrickId -> StandingState -> Bool
brickIsBlocked identifier state = any (\dependency ->
    dependencyBlocked dependency == identifier
    && dependencyStatus dependency == DependencyActive)
  (Map.elems (coordinationStateDependencies (standingStateCoordination state)))

inapplicableReason :: RecurrenceRule -> StandingState -> Text
inapplicableReason rule state
  | recurrenceRuleStatus rule == SchedulePaused = "recurrence_paused"
  | brickIsBlocked (recurrenceRuleTarget rule) state = "target_blocked"
  | otherwise = "not_applicable"

expirePracticeOpportunities :: UTCTime -> StandingState -> StandingState
expirePracticeOpportunities at state = state
  {standingStatePracticeOpportunities = Map.map expire
    (standingStatePracticeOpportunities state)}
  where
    expire opportunity
      | practiceOpportunityStatus opportunity == OpportunityOpen
      , practiceOpportunityWindowEnd opportunity <= at =
          case Map.lookup (practiceOpportunityRule opportunity)
              (standingStateRecurrences state) of
            Just rule
              | practiceIsApplicable rule state -> opportunity
                  { practiceOpportunityStatus = OpportunityNotDone
                  , practiceOpportunityResolvedAt = Just at
                  , practiceOpportunityReason = Just "window_expired"
                  }
            _ -> opportunity
              { practiceOpportunityStatus = OpportunityNotApplicable
              , practiceOpportunityResolvedAt = Just at
              , practiceOpportunityReason = Just "not_applicable_at_expiry"
              }
      | otherwise = opportunity

resolveOpenPractice ::
  RecurrenceRuleId -> PracticeOpportunityStatus -> UTCTime -> Text ->
  StandingState -> StandingState
resolveOpenPractice identifier status now reason state = state
  {standingStatePracticeOpportunities = Map.map resolve
    (standingStatePracticeOpportunities state)}
  where
    resolve opportunity
      | practiceOpportunityRule opportunity == identifier
      , practiceOpportunityStatus opportunity == OpportunityOpen = opportunity
          { practiceOpportunityStatus = status
          , practiceOpportunityResolvedAt = Just now
          , practiceOpportunityReason = Just reason
          }
      | otherwise = opportunity

practiceMark :: PracticeOpportunityStatus -> Text
practiceMark status = case status of
  OpportunityDone -> "x"
  OpportunityNotDone -> "-"
  OpportunityNotApplicable -> "n/a"
  OpportunityOpen -> "open"

countStatus :: Eq value => value -> [value] -> Int
countStatus expected = length . filter (== expected)

practiceStreaks :: [PracticeOpportunityStatus] -> [Int]
practiceStreaks = reverse . snd . foldl step (0, [])
  where
    step (current, streaks) status = case status of
      OpportunityDone -> let next = current + 1 in (next, next : streaks)
      OpportunityNotDone -> (0, 0 : streaks)
      OpportunityNotApplicable -> (current, current : streaks)
      OpportunityOpen -> (current, current : streaks)

currentPracticeStreak :: [PracticeOpportunityStatus] -> Int
currentPracticeStreak = foldl step 0
  where
    step current status = case status of
      OpportunityDone -> current + 1
      OpportunityNotDone -> 0
      OpportunityNotApplicable -> current
      OpportunityOpen -> current

------------------------------------------------------------
-- State embedding, validation, and lookup
------------------------------------------------------------

settleExecutionBrick ::
  BrickId -> Maybe UTCTime -> UTCTime -> StandingState ->
  Either StandingError StandingState
settleExecutionBrick identifier nextNotBefore now state = do
  let execution = coordinationExecution state
      domain = executionStateDomain execution
  brick <- maybe (Left (StandingUnknownEntity "Execution Brick")) Right
    (Map.lookup identifier (domainBricks domain))
  unless (brickStatus brick == Active && brickWorkState brick == Wip)
    (Left (StandingInvalidTransition "running execution Brick is not active WIP"))
  unfocused <- if focusRegisterCurrent (domainFocusRegister domain) == Just identifier
    then snd <$> mapDomain (unfocusCurrentBrick now domain)
    else Right domain
  (_, idle) <- mapDomain (returnBrickToIdle identifier unfocused)
  dated <- case nextNotBefore of
    Nothing -> Right idle
    Just value -> snd <$> mapDomain (setBrickNotBefore identifier value idle)
  let nextExecution = execution {executionStateDomain = dated}
  mapExecution (validateExecutionState nextExecution)
  let next = setCoordinationExecution nextExecution state
  mapCoordination (validateCoordinationState (standingStateCoordination next))
  pure next

coordinationExecution :: StandingState -> ExecutionState
coordinationExecution = coordinationStateExecution . standingStateCoordination

setCoordinationExecution :: ExecutionState -> StandingState -> StandingState
setCoordinationExecution execution state = state
  {standingStateCoordination = (standingStateCoordination state)
    {coordinationStateExecution = execution}}

requireBrick :: BrickId -> StandingState -> Either StandingError Brick
requireBrick identifier state = maybe
  (Left (StandingUnknownEntity "Brick")) Right
  (Map.lookup identifier (domainBricks
    (executionStateDomain (coordinationExecution state))))

requireExecution ::
  ExecutionOccurrenceId -> StandingState -> Either StandingError ExecutionOccurrence
requireExecution identifier state = lookupEntity "ExecutionOccurrence" identifier
  (standingStateExecutions state)

requireRecurrence ::
  RecurrenceRuleId -> StandingState -> Either StandingError RecurrenceRule
requireRecurrence identifier state = lookupEntity "RecurrenceRule" identifier
  (standingStateRecurrences state)

requirePractice ::
  PracticeOpportunityId -> StandingState -> Either StandingError PracticeOpportunity
requirePractice identifier state = lookupEntity "PracticeOpportunity" identifier
  (standingStatePracticeOpportunities state)

requireTrigger ::
  OpportunityTriggerId -> StandingState -> Either StandingError OpportunityTrigger
requireTrigger identifier state = lookupEntity "OpportunityTrigger" identifier
  (standingStateOpportunityTriggers state)

lookupEntity :: (Ord identifier, Show identifier) =>
  Text -> identifier -> Map identifier value -> Either StandingError value
lookupEntity name identifier values = maybe
  (Left (StandingUnknownEntity (name <> ": " <> Text.pack (show identifier))))
  Right (Map.lookup identifier values)

requireRunning :: ExecutionOccurrence -> Either StandingError ()
requireRunning occurrence = unless
  (executionOccurrenceStatus occurrence == ExecutionRunning)
  (Left (StandingInvalidTransition "execution occurrence is not running"))

executionEventId :: ExecutionOccurrence -> Text
executionEventId occurrence = "execution-finished:"
  <> unExecutionOccurrenceId (executionOccurrenceId occurrence)

retireFutureMechanicsFor ::
  [BrickId] -> UTCTime -> StandingState -> StandingState
retireFutureMechanicsFor identifiers now state = foldl'
  (\current identifier -> retireFutureMechanics identifier now current)
  state identifiers

retireFutureMechanics :: BrickId -> UTCTime -> StandingState -> StandingState
retireFutureMechanics identifier now state = state
  { standingStateRecurrences = Map.map retireRule (standingStateRecurrences state)
  , standingStatePracticeOpportunities = Map.map closePractice
      (standingStatePracticeOpportunities state)
  , standingStateOpportunityTriggers = Map.map retireTrigger
      (standingStateOpportunityTriggers state)
  }
  where
    retireRule rule
      | recurrenceRuleTarget rule == identifier
      , recurrenceRuleStatus rule `elem` [ScheduleActive, SchedulePaused] =
          rule {recurrenceRuleStatus = ScheduleRetired}
      | otherwise = rule
    closePractice opportunity = case Map.lookup (practiceOpportunityRule opportunity)
        (standingStateRecurrences state) of
      Just rule
        | recurrenceRuleTarget rule == identifier
        , practiceOpportunityStatus opportunity == OpportunityOpen -> opportunity
            { practiceOpportunityStatus = OpportunityNotApplicable
            , practiceOpportunityResolvedAt = Just now
            , practiceOpportunityReason = Just "target_terminal"
            }
      _ -> opportunity
    retireTrigger trigger
      | opportunityTriggerStatus trigger == TriggerActive
      , identifier `elem`
          [opportunityTriggerSource trigger, opportunityTriggerTarget trigger] =
          trigger {opportunityTriggerStatus = TriggerRetired}
      | otherwise = trigger

allocateId ::
  Text -> (Text -> identifier) -> StandingState -> (identifier, StandingState)
allocateId kind wrap state =
  let ordinal = standingStateNextOrdinal state
      identifier = wrap ("la1:" <> kind <> ":" <> Text.pack (show ordinal))
  in (identifier, state {standingStateNextOrdinal = ordinal + 1})

commit :: Text -> StandingState -> Either StandingError StandingState
commit action state = do
  let next = state
        { standingStateRevision = standingStateRevision state + 1
        , standingStateHistory = standingStateHistory state <> [action]
        }
  validateStandingState next
  pure next

validateStandingState :: StandingState -> Either StandingError ()
validateStandingState state = do
  mapCoordination (validateCoordinationState (standingStateCoordination state))
  unless (null violations) (Left (StandingInvariantViolation violations))
  where
    bricks = domainBricks (executionStateDomain (coordinationExecution state))
    executions = Map.elems (standingStateExecutions state)
    recurrences = Map.elems (standingStateRecurrences state)
    obligations = Map.elems (standingStateObligations state)
    practices = Map.elems (standingStatePracticeOpportunities state)
    triggers = Map.elems (standingStateOpportunityTriggers state)
    triggered = Map.elems (standingStateTriggeredOpportunities state)
    runningKeys = [(executionOccurrenceBrick execution) | execution <- executions,
      executionOccurrenceStatus execution == ExecutionRunning]
    liveRecurrenceKeys = [(recurrenceRuleTarget rule, recurrenceRuleKind rule)
      | rule <- recurrences,
        recurrenceRuleStatus rule `elem` [ScheduleActive, SchedulePaused]]
    obligationKeys = [(obligationOccurrenceRule occurrence,
      obligationOccurrencePeriodKey occurrence) | occurrence <- obligations]
    practiceKeys = [(practiceOpportunityRule opportunity,
      practiceOpportunityPeriodKey opportunity) | opportunity <- practices]
    triggeredKeys = [(triggeredOpportunityTrigger opportunity,
      triggeredOpportunitySourceEventId opportunity) | opportunity <- triggered]
    violations = concat
      [ ["standing revision, history, or allocator is inconsistent" |
          standingStateRevision state < 0 || standingStateNextOrdinal state < 1
          || standingStateRevision state /= fromIntegral (length
            (standingStateHistory state))]
      , ["ExecutionOccurrence map key differs from identity" | any (uncurry (/=))
          [(identifier, executionOccurrenceId execution) |
            (identifier, execution) <- Map.toList (standingStateExecutions state)]]
      , ["ExecutionOccurrence references an unknown Brick" | any
          ((`Map.notMember` bricks) . executionOccurrenceBrick) executions]
      , ["Brick has more than one running execution" | hasDuplicates runningKeys]
      , ["running execution does not have exactly one observed start" | any
          (\execution -> executionOccurrenceStatus execution == ExecutionRunning
            && (executionOccurrenceStartedAt execution == Nothing
              || executionOccurrenceFinishedAt execution /= Nothing
              || executionOccurrenceOutcome execution /= Nothing)) executions]
      , ["terminal execution lacks honest finish/outcome evidence" | any
          (\execution -> executionOccurrenceStatus execution /= ExecutionRunning
            && (executionOccurrenceFinishedAt execution == Nothing
              || executionOccurrenceOutcome execution == Nothing)) executions]
      , ["RecurrenceRule references an unknown Brick" | any
          ((`Map.notMember` bricks) . recurrenceRuleTarget) recurrences]
      , ["terminal Brick retains a live recurrence" | any
          (\rule -> recurrenceRuleStatus rule `elem` [ScheduleActive, SchedulePaused]
            && isTerminalBrick (recurrenceRuleTarget rule)) recurrences]
      , ["live recurrence target/kind is duplicated" |
          hasDuplicates liveRecurrenceKeys]
      , ["ObligationOccurrence period is duplicated" |
          hasDuplicates obligationKeys]
      , ["ObligationOccurrence has a broken relationship" | any
          (\occurrence -> case
              ( Map.lookup (obligationOccurrenceRule occurrence)
                  (standingStateRecurrences state)
              , Map.lookup (obligationOccurrenceBrick occurrence) bricks
              ) of
                (Just rule, Just brick) -> recurrenceRuleKind rule
                    /= ObligationRecurrence
                  || brickParent brick /= Just (recurrenceRuleTarget rule)
                _ -> True) obligations]
      , ["PracticeOpportunity period is duplicated" | hasDuplicates practiceKeys]
      , ["PracticeOpportunity has an invalid window or rule" | any
          (\opportunity -> practiceOpportunityWindowStart opportunity
              >= practiceOpportunityWindowEnd opportunity
            || maybe True ((/= PracticeRecurrence) . recurrenceRuleKind)
              (Map.lookup (practiceOpportunityRule opportunity)
                (standingStateRecurrences state))) practices]
      , ["PracticeOpportunity resolution fields disagree with status" | any
          (\opportunity -> (practiceOpportunityStatus opportunity == OpportunityOpen)
            /= (practiceOpportunityResolvedAt opportunity == Nothing)) practices]
      , ["terminal Brick retains an open practice opportunity" | any
          (\opportunity -> practiceOpportunityStatus opportunity == OpportunityOpen
            && maybe False (isTerminalBrick . recurrenceRuleTarget)
              (Map.lookup (practiceOpportunityRule opportunity)
                (standingStateRecurrences state))) practices]
      , ["OpportunityTrigger has a broken relationship" | any
          (\trigger -> opportunityTriggerSource trigger == opportunityTriggerTarget trigger
            || Map.notMember (opportunityTriggerSource trigger) bricks
            || Map.notMember (opportunityTriggerTarget trigger) bricks) triggers]
      , ["terminal Brick retains an active opportunity trigger" | any
          (\trigger -> opportunityTriggerStatus trigger == TriggerActive
            && (isTerminalBrick (opportunityTriggerSource trigger)
              || isTerminalBrick (opportunityTriggerTarget trigger))) triggers]
      , ["TriggeredOpportunity source event is duplicated" |
          hasDuplicates triggeredKeys]
      , ["TriggeredOpportunity has a broken relationship" | any
          (\opportunity -> case Map.lookup (triggeredOpportunityTrigger opportunity)
              (standingStateOpportunityTriggers state) of
              Just trigger -> triggeredOpportunityTarget opportunity
                /= opportunityTriggerTarget trigger
              Nothing -> True) triggered]
      ]
    isTerminalBrick identifier = maybe False ((/= Active) . brickStatus)
      (Map.lookup identifier bricks)

hasDuplicates :: Ord value => [value] -> Bool
hasDuplicates values = Set.size (Set.fromList values) /= length values

mapCoordination :: Either CoordinationError value -> Either StandingError value
mapCoordination = either (Left . StandingCoordinationError) Right

mapDomain :: Either DomainError value -> Either StandingError value
mapDomain = either (Left . StandingDomainError) Right

mapExecution :: Either ExecutionError value -> Either StandingError value
mapExecution = either (Left . StandingExecutionError) Right

mapPriority :: Either Priority.PriorityError value -> Either StandingError value
mapPriority = either (Left . StandingPriorityError) Right

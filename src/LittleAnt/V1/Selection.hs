{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Read-only probabilistic selection, rebuildable maintenance proposals, and
-- retained served-skip pressure.
--
-- A forecast is a pure projection over canonical domain evidence.  It neither
-- stores an order nor consumes randomness.  Random evidence enters only when
-- one 'NextDraw' (or an explicitly requested deterministic simulation) is
-- produced.
module LittleAnt.V1.Selection
  ( ForecastItem (..)
  , ForecastView (..)
  , NextDraw (..)
  , NextDrawId (..)
  , Proposal (..)
  , ProposalId (..)
  , ProposalKind (..)
  , ProposalStatus (..)
  , SelectionContext (..)
  , SelectionCooldown (..)
  , SelectionCooldownId (..)
  , SelectionError (..)
  , SelectionState (..)
  , ServedSkip (..)
  , ServedSkipId (..)
  , SkipReason (..)
  , StoredNextDraw (..)
  , SimulationCandidateMetric (..)
  , SimulationMetrics (..)
  , advanceSelection
  , advanceSelectionWithValidation
  , buildForecast
  , defaultPracticeReviewThreshold
  , dismissProposal
  , emptySelectionState
  , forecastItemForBrick
  , openProposalsFor
  , recordServedSkip
  , replaySafeWeightedDraw
  , requestNext
  , resolveProposal
  , servedSkipCooldown
  , simulateReplaySafeDraws
  , staleFocusAfter
  , validateSelectionState
  ) where

import Control.Monad (foldM, unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey, Value (..),
   defaultOptions, genericParseJSON, genericToJSON, withText)
import qualified Data.Aeson.Types as AesonTypes
import Data.Char (ord, toLower)
import Data.List (find, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (catMaybes, fromMaybe, isJust, mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (NominalDiffTime, UTCTime, addUTCTime, diffUTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Coordination
  (CoordinationState (..), DelegationId, Dependency (..), DependencyStatus (..),
   PlaceEvaluation (..), Wait (..), WaitStatus (..), evaluatePlaceConditions)
import LittleAnt.V1.Domain
  (Brick (..), BrickId (..), BrickPhase (..), BrickStatus (..), DomainError,
   DomainState (..), FocusRegister (..), ListEntry (..), ListEntryStatus (..),
   RepetitionKind (..), WorkState (..), behaviorEmptyIsDormant,
   behaviorRepetition, effectiveBestBefore, effectiveDeadline,
   effectiveNotBefore)
import LittleAnt.V1.Execution (ExecutionState (..), softWipLimit)
import qualified LittleAnt.V1.Judgment as Judgment
import LittleAnt.V1.Material
  (MaterialState (..), Raw (..), RawId (..), RawLink (..), RawLinkId (..),
   RawLinkRole (..),
   RawReviewState (..), RawSnapshot (..), RawStorageState (..))
import qualified LittleAnt.V1.Priority as Priority
import LittleAnt.V1.Standing
  (PracticeOpportunity (..), PracticeOpportunityStatus (..), RecurrenceKind (..),
   RecurrenceRule (..), StandingState (..), TriggeredOpportunity (..),
   validateStandingState)

------------------------------------------------------------
-- Vocabulary, values, and canonical state
------------------------------------------------------------

data ProposalKind
  = PriorityProbe
  | ImpactProbe
  | EffortProbe
  | BrickReview
  | ReviewParent
  | ReviewWip
  | PhaseReview
  | PracticeReview
  | ReviewRaw
  | RefreshRaw
  | StaleFocus
  | StaleComparison
  | ScopeReview
  | SourceReconciliation
  | DelegationFollowup
  | EffectApproval
  | DuplicateReview
  | PlaceBatch
  | InvestigationPlan
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ProposalStatus = ProposalOpen | ProposalResolved | ProposalDismissed
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data SkipReason
  = SkipHard
  | SkipVague
  | SkipNotPriority
  | SkipWaiting
  | SkipTired
  | SkipMeh
  | SkipKill
  | SkipAlternatives
  | SkipOther
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON ProposalKind where toJSON = String . proposalKindText
instance FromJSON ProposalKind where
  parseJSON = parseEnum "ProposalKind" proposalKindText
instance ToJSON ProposalStatus where toJSON = String . proposalStatusText
instance FromJSON ProposalStatus where
  parseJSON = parseEnum "ProposalStatus" proposalStatusText
instance ToJSON SkipReason where toJSON = String . skipReasonText
instance FromJSON SkipReason where parseJSON = parseEnum "SkipReason" skipReasonText

parseEnum :: (Bounded value, Enum value) =>
  String -> (value -> Text) -> Value -> AesonTypes.Parser value
parseEnum name render = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate [(render value, value) | value <- [minBound .. maxBound]])

proposalKindText :: ProposalKind -> Text
proposalKindText kind = case kind of
  PriorityProbe -> "priority_probe"
  ImpactProbe -> "impact_probe"
  EffortProbe -> "effort_probe"
  BrickReview -> "brick_review"
  ReviewParent -> "review_parent"
  ReviewWip -> "review_wip"
  PhaseReview -> "phase_review"
  PracticeReview -> "practice_review"
  ReviewRaw -> "review_raw"
  RefreshRaw -> "refresh_raw"
  StaleFocus -> "stale_focus"
  StaleComparison -> "stale_comparison"
  ScopeReview -> "scope_review"
  SourceReconciliation -> "source_reconciliation"
  DelegationFollowup -> "delegation_followup"
  EffectApproval -> "effect_approval"
  DuplicateReview -> "duplicate_review"
  PlaceBatch -> "place_batch"
  InvestigationPlan -> "investigation_plan"

proposalStatusText :: ProposalStatus -> Text
proposalStatusText status = case status of
  ProposalOpen -> "open"
  ProposalResolved -> "resolved"
  ProposalDismissed -> "dismissed"

skipReasonText :: SkipReason -> Text
skipReasonText reason = case reason of
  SkipHard -> "hard"
  SkipVague -> "vague"
  SkipNotPriority -> "not_priority"
  SkipWaiting -> "waiting"
  SkipTired -> "tired"
  SkipMeh -> "meh"
  SkipKill -> "kill"
  SkipAlternatives -> "alternatives"
  SkipOther -> "other"

newtype ProposalId = ProposalId {unProposalId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype SelectionCooldownId = SelectionCooldownId {unSelectionCooldownId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype NextDrawId = NextDrawId {unNextDrawId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype ServedSkipId = ServedSkipId {unServedSkipId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

data Proposal = Proposal
  { proposalId :: ProposalId
  , proposalKind :: ProposalKind
  , proposalBrick :: Maybe BrickId
  , proposalRaw :: Maybe RawId
  , proposalInsertion :: Maybe Priority.PriorityInsertionId
  , proposalJudgmentProbe :: Maybe Priority.JudgmentProbeId
  , proposalDelegation :: Maybe DelegationId
  , proposalReason :: Text
  , proposalStatus :: ProposalStatus
  , proposalCreatedAt :: UTCTime
  , proposalAvailableAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data SelectionCooldown = SelectionCooldown
  { selectionCooldownId :: SelectionCooldownId
  , selectionCooldownBrick :: BrickId
  , selectionCooldownUntil :: UTCTime
  , selectionCooldownRecentSkipCount :: Integer
  , selectionCooldownLastReason :: SkipReason
  }
  deriving stock (Eq, Show, Generic)

data ServedSkip = ServedSkip
  { servedSkipId :: ServedSkipId
  , servedSkipBrick :: BrickId
  , servedSkipReason :: SkipReason
  , servedSkipRawText :: Maybe Text
  , servedSkipRecordedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data ForecastItem = ForecastItem
  { forecastItemBrick :: Maybe BrickId
  , forecastItemProposal :: Maybe ProposalId
  , forecastItemWeight :: Double
  , forecastItemProbability :: Double
  , forecastItemReasons :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data ForecastView = ForecastView
  { forecastViewDomainRevision :: Integer
  , forecastViewGeneratedAt :: UTCTime
  , forecastViewItems :: [ForecastItem]
  }
  deriving stock (Eq, Show, Generic)

-- | Protocol projection of a draw.  The source forecast is derived from the
-- pinned revision and time; it is returned to callers but is never canonical
-- state.
data NextDraw = NextDraw
  { nextDrawId :: NextDrawId
  , nextDrawSelectedBrick :: Maybe BrickId
  , nextDrawSelectedProposal :: Maybe ProposalId
  , nextDrawDomainRevision :: Integer
  , nextDrawRandomEvidence :: Text
  , nextDrawDrawnAt :: UTCTime
  , nextDrawReasons :: [Text]
  , nextDrawSourceForecast :: ForecastView
  }
  deriving stock (Eq, Show, Generic)

-- | Canonical historical facts for a draw.  These are sufficient to rebuild
-- 'NextDraw.source_forecast' at the pinned domain revision and time without
-- persisting its ordered list of candidates.
data StoredNextDraw = StoredNextDraw
  { storedNextDrawId :: NextDrawId
  , storedNextDrawSelectedBrick :: Maybe BrickId
  , storedNextDrawSelectedProposal :: Maybe ProposalId
  , storedNextDrawDomainRevision :: Integer
  , storedNextDrawRandomEvidence :: Text
  , storedNextDrawDrawnAt :: UTCTime
  , storedNextDrawReasons :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data SimulationCandidateMetric = SimulationCandidateMetric
  { simulationCandidateId :: Text
  , simulationCandidateForecastProbability :: Double
  , simulationCandidateObservedFrequency :: Double
  , simulationCandidateCount :: Integer
  }
  deriving stock (Eq, Show, Generic)

data SimulationMetrics = SimulationMetrics
  { simulationMetricsSeed :: Text
  , simulationMetricsSamples :: Integer
  , simulationMetricsPerCandidate :: [SimulationCandidateMetric]
  }
  deriving stock (Eq, Show, Generic)

data SelectionContext = SelectionContext
  { selectionContextStanding :: StandingState
  , selectionContextMaterial :: MaterialState
  }
  deriving stock (Eq, Show, Generic)

data SelectionState = SelectionState
  { selectionStateRevision :: Integer
  , selectionStateNextOrdinal :: Integer
  , selectionStateProposals :: Map ProposalId Proposal
  , selectionStateProposalSources :: Map Text ProposalId
  , selectionStateCooldowns :: Map BrickId SelectionCooldown
  , selectionStateServedSkips :: Map ServedSkipId ServedSkip
  , selectionStateDraws :: Map NextDrawId StoredNextDraw
  , selectionStatePracticeReviewThreshold :: Integer
  , selectionStateHistory :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON Proposal where toJSON = genericToJSON (recordOptions "proposal")
instance FromJSON Proposal where parseJSON = genericParseJSON (recordOptions "proposal")
instance ToJSON SelectionCooldown where
  toJSON = genericToJSON (recordOptions "selectionCooldown")
instance FromJSON SelectionCooldown where
  parseJSON = genericParseJSON (recordOptions "selectionCooldown")
instance ToJSON ServedSkip where toJSON = genericToJSON (recordOptions "servedSkip")
instance FromJSON ServedSkip where parseJSON = genericParseJSON (recordOptions "servedSkip")
instance ToJSON ForecastItem where toJSON = genericToJSON (recordOptions "forecastItem")
instance FromJSON ForecastItem where parseJSON = genericParseJSON (recordOptions "forecastItem")
instance ToJSON ForecastView where toJSON = genericToJSON (recordOptions "forecastView")
instance FromJSON ForecastView where parseJSON = genericParseJSON (recordOptions "forecastView")
instance ToJSON NextDraw where toJSON = genericToJSON (recordOptions "nextDraw")
instance FromJSON NextDraw where parseJSON = genericParseJSON (recordOptions "nextDraw")
instance ToJSON StoredNextDraw where
  toJSON = genericToJSON (recordOptions "storedNextDraw")
instance FromJSON StoredNextDraw where
  parseJSON = genericParseJSON (recordOptions "storedNextDraw")
instance ToJSON SimulationCandidateMetric where
  toJSON = genericToJSON (recordOptions "simulationCandidate")
instance FromJSON SimulationCandidateMetric where
  parseJSON = genericParseJSON (recordOptions "simulationCandidate")
instance ToJSON SimulationMetrics where
  toJSON = genericToJSON (recordOptions "simulationMetrics")
instance FromJSON SimulationMetrics where
  parseJSON = genericParseJSON (recordOptions "simulationMetrics")
instance ToJSON SelectionState where
  toJSON = genericToJSON (recordOptions "selectionState")
instance FromJSON SelectionState where
  parseJSON = genericParseJSON (recordOptions "selectionState")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLower first : rest)

data SelectionError
  = SelectionDomainError DomainError
  | SelectionPriorityError Priority.PriorityError
  | SelectionUnknownEntity Text
  | SelectionInvalidTransition Text
  | SelectionNoCandidate
  | SelectionInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

servedSkipCooldown :: NominalDiffTime
servedSkipCooldown = 2 * 60 * 60

staleFocusAfter :: NominalDiffTime
staleFocusAfter = 24 * 60 * 60

defaultPracticeReviewThreshold :: Integer
defaultPracticeReviewThreshold = 3

emptySelectionState :: SelectionState
emptySelectionState = SelectionState
  { selectionStateRevision = 0
  , selectionStateNextOrdinal = 1
  , selectionStateProposals = Map.empty
  , selectionStateProposalSources = Map.empty
  , selectionStateCooldowns = Map.empty
  , selectionStateServedSkips = Map.empty
  , selectionStateDraws = Map.empty
  , selectionStatePracticeReviewThreshold = defaultPracticeReviewThreshold
  , selectionStateHistory = []
  }

------------------------------------------------------------
-- Proposal derivation and lifecycle
------------------------------------------------------------

data ProposalCandidate = ProposalCandidate
  { candidateSource :: Text
  , candidateKind :: ProposalKind
  , candidateBrick :: Maybe BrickId
  , candidateRaw :: Maybe RawId
  , candidateInsertion :: Maybe Priority.PriorityInsertionId
  , candidateJudgmentProbe :: Maybe Priority.JudgmentProbeId
  , candidateDelegation :: Maybe DelegationId
  , candidateReason :: Text
  , candidateAvailableAt :: UTCTime
  }

-- | Rebuild current proposal pressure from unresolved canonical state and
-- materialize any newly discovered proposal exactly once.  Previously
-- materialized source proposals are resolved when their source ceases to be
-- unresolved; dismissed proposals remain terminal.
advanceSelection ::
  UTCTime -> SelectionContext -> SelectionState ->
  Either SelectionError ([Proposal], SelectionState)
advanceSelection at context state = do
  let candidates = deriveProposalCandidates at context state
      bySource = Map.fromList [(candidateSource candidate, candidate)
        | candidate <- candidates]
      resolved = Map.mapWithKey (resolveMissing bySource state)
        (selectionStateProposals state)
      withResolved = state {selectionStateProposals = resolved}
  (created, materialized) <- foldM materialize ([], withResolved)
    (sortOn candidateSource candidates)
  committed <- commit "selection_advanced" materialized
  pure (reverse created, committed)
  where
    resolveMissing current original _identifier proposal
      | proposalStatus proposal /= ProposalOpen = proposal
      | sourceForProposal original (proposalId proposal) `Map.member` current = proposal
      | otherwise = proposal {proposalStatus = ProposalResolved}
    materialize (created, current) candidate =
      case Map.lookup (candidateSource candidate)
          (selectionStateProposalSources current) >>= (`Map.lookup`
            selectionStateProposals current) of
        Just existing | proposalStatus existing == ProposalOpen ->
          Right (created, current)
        _ ->
          let (identifier, allocated) = allocateId "proposal" ProposalId current
              proposal = Proposal
                { proposalId = identifier
                , proposalKind = candidateKind candidate
                , proposalBrick = candidateBrick candidate
                , proposalRaw = candidateRaw candidate
                , proposalInsertion = candidateInsertion candidate
                , proposalJudgmentProbe = candidateJudgmentProbe candidate
                , proposalDelegation = candidateDelegation candidate
                , proposalReason = candidateReason candidate
                , proposalStatus = ProposalOpen
                , proposalCreatedAt = at
                , proposalAvailableAt = candidateAvailableAt candidate
                }
              next = allocated
                { selectionStateProposals = Map.insert identifier proposal
                    (selectionStateProposals allocated)
                , selectionStateProposalSources = Map.insert
                    (candidateSource candidate) identifier
                    (selectionStateProposalSources allocated)
                }
          in Right (proposal : created, next)

-- | Advance proposal pressure and, when retained comparable evidence is due,
-- open one deterministic validation probe in the canonical judgment state.
-- An already-open probe for the same directed relation suppresses creation.
advanceSelectionWithValidation ::
  UTCTime -> SelectionContext -> SelectionState ->
  Either SelectionError
    ([Proposal], Maybe Priority.JudgmentProbe, SelectionContext, SelectionState)
advanceSelectionWithValidation at context state = do
  (opened, contextWithValidation) <- openDueValidation at context
  (created, next) <- advanceSelection at contextWithValidation state
  pure (created, opened, contextWithValidation, next)

openDueValidation ::
  UTCTime -> SelectionContext ->
  Either SelectionError (Maybe Priority.JudgmentProbe, SelectionContext)
openDueValidation at context = case dueCandidates of
  [] -> Right (Nothing, context)
  (scope, left, right) : _ -> do
    let reason = "provocative validation of retained priority evidence"
    (probe, priority') <- mapPriority (Priority.openPriorityProbe scope left right
      Priority.Validation reason at priority)
    nextContext <- replaceSelectionPriority priority' context
    pure (Just probe, nextContext)
  where
    priority = selectionPriority context
    scopes = Priority.priorityStateScopes priority
    active = Priority.priorityStateBricks priority
    openProbes = Map.elems (Priority.priorityStateProbes priority)
    dueCandidates = sortOn (\(scope, left, right) -> (scope, left, right))
      [ (scopeId, left, right)
      | judgment <- Map.elems (Priority.priorityStateJudgments priority)
      , Priority.priorityJudgmentApplicable judgment
      , let scopeId = Priority.priorityJudgmentScope judgment
            left = Priority.priorityJudgmentMoreImportant judgment
            right = Priority.priorityJudgmentLessImportant judgment
      , Just scope <- [Map.lookup scopeId scopes]
      , left `elem` Priority.priorityScopeMembers scope
      , right `elem` Priority.priorityScopeMembers scope
      , maybe False ((== Active) . Priority.priorityBrickStatus)
          (Map.lookup left active)
      , maybe False ((== Active) . Priority.priorityBrickStatus)
          (Map.lookup right active)
      , not (any (sameOpenRelation left right) openProbes)
      ]
    sameOpenRelation left right probe =
      Priority.judgmentProbeAxis probe == Priority.PriorityAxis
      && Priority.judgmentProbeLeft probe == left
      && Priority.judgmentProbeRight probe == right
      && Priority.judgmentProbeStatus probe == Priority.ProbeOpen

replaceSelectionPriority ::
  Priority.PriorityState -> SelectionContext ->
  Either SelectionError SelectionContext
replaceSelectionPriority priority context = do
  let standing = selectionContextStanding context
      coordination = standingStateCoordination standing
      execution = coordinationStateExecution coordination
      standing' = standing {standingStateCoordination = coordination
        {coordinationStateExecution = execution
          {executionStatePriority = priority}}}
  either (Left . SelectionInvalidTransition . Text.pack . show) Right
    (validateStandingState standing')
  pure context {selectionContextStanding = standing'}

mapPriority :: Either Priority.PriorityError value -> Either SelectionError value
mapPriority = either (Left . SelectionPriorityError) Right

sourceForProposal :: SelectionState -> ProposalId -> Text
sourceForProposal state identifier = fromMaybe ""
  (fst <$> find ((== identifier) . snd)
    (Map.toList (selectionStateProposalSources state)))

resolveProposal :: ProposalId -> SelectionState ->
  Either SelectionError (Proposal, SelectionState)
resolveProposal identifier state = do
  proposal <- requireProposal identifier state
  unless (proposalStatus proposal == ProposalOpen)
    (Left (SelectionInvalidTransition "only an open Proposal can resolve"))
  when (proposalKind proposal `elem` [PriorityProbe, ImpactProbe, EffortProbe]
      && isJust (proposalJudgmentProbe proposal))
    (Left (SelectionInvalidTransition
      "a live judgment proposal resolves through its JudgmentProbe"))
  let updated = proposal {proposalStatus = ProposalResolved}
  committed <- commit "proposal_resolved" state
    {selectionStateProposals = Map.insert identifier updated
      (selectionStateProposals state)}
  pure (updated, committed)

dismissProposal :: ProposalId -> SelectionState ->
  Either SelectionError (Proposal, SelectionState)
dismissProposal identifier state = do
  proposal <- requireProposal identifier state
  unless (proposalStatus proposal == ProposalOpen)
    (Left (SelectionInvalidTransition "only an open Proposal can be dismissed"))
  let updated = proposal {proposalStatus = ProposalDismissed}
  committed <- commit "proposal_dismissed" state
    {selectionStateProposals = Map.insert identifier updated
      (selectionStateProposals state)}
  pure (updated, committed)

openProposalsFor ::
  UTCTime -> BrickId -> SelectionContext -> SelectionState -> [Proposal]
openProposalsFor at brick context state = sortOn proposalId
  [ proposal
  | proposal <- projectedOpenProposals at context state
  , proposalBrick proposal == Just brick
  ]

projectedOpenProposals ::
  UTCTime -> SelectionContext -> SelectionState -> [Proposal]
projectedOpenProposals at context state =
  let candidates = deriveProposalCandidates at context state
      candidateSources = Set.fromList (map candidateSource candidates)
      persisted = [proposal | proposal <- Map.elems (selectionStateProposals state),
        proposalStatus proposal == ProposalOpen,
        proposalAvailableAt proposal <= at,
        Set.member (sourceForProposal state (proposalId proposal)) candidateSources]
      knownOpenSources = Set.fromList
        [source | (source, identifier) <- Map.toList
            (selectionStateProposalSources state),
          maybe False ((== ProposalOpen) . proposalStatus)
            (Map.lookup identifier (selectionStateProposals state))]
      projected = snd (foldl project
        (selectionStateNextOrdinal state, [])
        (sortOn candidateSource candidates))
      project (ordinal, values) candidate
        | Set.member (candidateSource candidate) knownOpenSources = (ordinal, values)
        | otherwise =
            let identifier = ProposalId
                  ("la1:projected-proposal:" <> Text.pack (show ordinal))
                proposal = Proposal identifier (candidateKind candidate)
                  (candidateBrick candidate) (candidateRaw candidate)
                  (candidateInsertion candidate) (candidateJudgmentProbe candidate)
                  (candidateDelegation candidate) (candidateReason candidate)
                  ProposalOpen at (candidateAvailableAt candidate)
            in (ordinal + 1, proposal : values)
  in sortOn proposalId (persisted <> projected)

deriveProposalCandidates ::
  UTCTime -> SelectionContext -> SelectionState -> [ProposalCandidate]
deriveProposalCandidates at context state = deduplicateCandidates
  (priorityCandidates <> judgmentCandidates <> executionCandidates
    <> materialCandidates <> practiceCandidates <> staleFocusCandidates)
  where
    standing = selectionContextStanding context
    coordination = standingStateCoordination standing
    execution = coordinationStateExecution coordination
    domain = executionStateDomain execution
    priority = executionStatePriority execution
    judgment = executionStateJudgment execution
    material = selectionContextMaterial context

    priorityCandidates = concatMap insertionCandidates
      (Map.elems (Priority.priorityStateInsertions priority))
      <> mapMaybe recalibrationCandidate
        (Map.elems (Priority.priorityStateRecalibrations priority))
      <> mapMaybe priorityProbeCandidate
        (Map.elems (Priority.priorityStateProbes priority))
      <> mapMaybe deferredProbeInvestigation
        (Map.elems (Priority.priorityStateProbes priority))
    insertionCandidates insertion
      | Priority.priorityInsertionStatus insertion /= Priority.InsertionDeferred = []
      | otherwise =
          [ candidate ("priority-insertion:"
                <> Priority.unPriorityInsertionId
                  (Priority.priorityInsertionId insertion))
              PriorityProbe (Just (Priority.priorityInsertionBrick insertion))
              Nothing (Just (Priority.priorityInsertionId insertion)) Nothing
              "priority placement is provisional"
          ] <>
          [ candidate ("priority-investigation:"
                <> Priority.unPriorityInsertionId
                  (Priority.priorityInsertionId insertion))
              InvestigationPlan (Just (Priority.priorityInsertionBrick insertion))
              Nothing (Just (Priority.priorityInsertionId insertion)) Nothing
              "resolving this importance uncertainty could change a relevant decision"
          | Priority.priorityInsertionConsecutiveSkips insertion > 0
              || Priority.priorityInsertionComparisonsRecorded insertion > 1
          ]
    recalibrationCandidate recalibration
      | Priority.priorityRecalibrationStatus recalibration
          /= Priority.RecalibrationOpen = Nothing
      | otherwise = case Priority.priorityRecalibrationSegment recalibration of
          [] -> Nothing
          brick : _ -> Just (candidate ("priority-recalibration:"
              <> Priority.unPriorityRecalibrationId
                (Priority.priorityRecalibrationId recalibration))
            PriorityProbe (Just brick) Nothing Nothing Nothing
            "a local priority segment contradicts current evidence")
    priorityProbeCandidate probe
      | Priority.judgmentProbeStatus probe /= Priority.ProbeOpen = Nothing
      | otherwise = Just (probeCandidate "priority-probe" probe)

    judgmentCandidates = mapMaybe assessmentProbeCandidate
      (Map.elems (Judgment.judgmentStateProbes judgment))
      <> mapMaybe deferredProbeInvestigation
        (Map.elems (Judgment.judgmentStateProbes judgment))
    assessmentProbeCandidate probe
      | Priority.judgmentProbeStatus probe /= Priority.ProbeOpen = Nothing
      | otherwise = Just (probeCandidate "judgment-probe" probe)
    deferredProbeInvestigation probe
      | Priority.judgmentProbeStatus probe /= Priority.ProbeDeferred = Nothing
      | not (highValueProbe probe) = Nothing
      | otherwise = Just (candidate ("judgment-investigation:"
          <> Priority.unJudgmentProbeId (Priority.judgmentProbeId probe))
          InvestigationPlan (Just (Priority.judgmentProbeLeft probe)) Nothing
          Nothing (Just (Priority.judgmentProbeId probe))
          "purposeful evidence could resolve a decision-relevant uncertainty")
    highValueProbe probe = Priority.judgmentProbePurpose probe
      `elem` [Priority.Discovery, Priority.Recalibration]
    probeCandidate prefix probe =
      let identifier = Priority.unJudgmentProbeId (Priority.judgmentProbeId probe)
      in (candidate (prefix <> ":" <> identifier)
          (kindForAxis (Priority.judgmentProbeAxis probe))
          (Just (Priority.judgmentProbeLeft probe)) Nothing Nothing
          (Just (Priority.judgmentProbeId probe))
          (Priority.judgmentProbeReason probe))

    executionCandidates =
      [candidate ("parent-review:" <> brickText brick) ReviewParent (Just brick)
          Nothing Nothing Nothing "the final active child closed"
      | brick <- Set.toList (executionStateParentReviews execution)] <>
      [candidate ("scope-review:" <> brickText brick) ScopeReview (Just brick)
          Nothing Nothing Nothing "scope evidence requires review"
      | brick <- Set.toList (coordinationStateChecklistReviews coordination)] <>
      [candidate ("dependency-review:" <> brickText brick) BrickReview (Just brick)
          Nothing Nothing Nothing
          "a blocker ended without satisfying the dependency"
      | brick <- Set.toList (coordinationStateDependencyReviews coordination)] <>
      [candidate ("wip-review:" <> brickText (brickId brick)) ReviewWip
          (Just (brickId brick)) Nothing Nothing Nothing
          "the soft human WIP limit was exceeded"
      | activeHumanWipCount execution > softWipLimit
      , brick <- Map.elems (domainBricks domain)
      , brickStatus brick == Active, brickWorkState brick == Wip]

    materialCandidates =
      [candidate ("raw-review:" <> rawIdText (rawId raw)) ReviewRaw Nothing
          (Just (rawId raw)) Nothing Nothing "new material has not been reviewed"
      | raw <- Map.elems (materialRaws material)
      , rawReviewState raw == RawPending
      , rawStorageState raw == RawActive] <>
      mapMaybe reconciliationCandidate (Map.elems (materialLinks material))
    reconciliationCandidate link
      | rawLinkRole link /= Source = Nothing
      | otherwise = do
          brick <- rawLinkOwnerBrick link
          latest <- latestSnapshotFor (rawLinkRaw link) material
          if rawLinkReconciledSnapshot link == Just (rawSnapshotId latest)
            then Nothing
            else Just (candidate ("source-reconciliation:"
                <> rawLinkText (rawLinkId link)) SourceReconciliation
              (Just brick) (Just (rawLinkRaw link)) Nothing Nothing
              "a linked source has a newer attributable snapshot")

    practiceCandidates =
      [candidate ("practice-review:" <> brickText target) PracticeReview
          (Just target) Nothing Nothing Nothing
          "repeated unfulfilled opportunities merit an enabling-work or cadence review"
      | brick <- Map.elems (domainBricks domain)
      , behaviorRepetition (brickBehavior brick) == Practice
      , let target = brickId brick
            ruleIds = Set.fromList
              [recurrenceRuleId rule | (rule, owner) <- practiceRules standing,
                owner == target]
            misses = fromIntegral (length
              [opportunity
              | opportunity <- Map.elems (standingStatePracticeOpportunities standing)
              , Set.member (practiceOpportunityRule opportunity) ruleIds
              , practiceOpportunityStatus opportunity == OpportunityNotDone])
            skips = fromIntegral (length
              [served
              | served <- Map.elems (selectionStateServedSkips state)
              , servedSkipBrick served == target])
      , misses + skips >= selectionStatePracticeReviewThreshold state]

    staleFocusCandidates = case
        (focusRegisterCurrent (domainFocusRegister domain),
         focusRegisterChangedAt (domainFocusRegister domain)) of
      (Just brick, Just changed)
        | addUTCTime staleFocusAfter changed <= at ->
            [candidate ("stale-focus:" <> brickText brick) StaleFocus
              (Just brick) Nothing Nothing Nothing
              "current focus has not been reaffirmed"]
      _ -> []

    candidate source kind brick raw insertion probe reason = ProposalCandidate
      source kind brick raw insertion probe Nothing reason at

kindForAxis :: Priority.JudgmentAxis -> ProposalKind
kindForAxis axis = case axis of
  Priority.PriorityAxis -> PriorityProbe
  Priority.ImpactAxis -> ImpactProbe
  Priority.EffortAxis -> EffortProbe

activeHumanWipCount :: ExecutionState -> Int
activeHumanWipCount execution = length
  [brick | brick <- Map.elems (domainBricks (executionStateDomain execution)),
    brickStatus brick == Active, brickWorkState brick == Wip,
    Set.notMember (brickId brick) (executionStateDelegated execution)]

practiceRules :: StandingState -> [(RecurrenceRule, BrickId)]
practiceRules standing =
  [(rule, recurrenceRuleTarget rule)
  | rule <- Map.elems (standingStateRecurrences standing)
  , recurrenceRuleKind rule == PracticeRecurrence]

latestSnapshotFor :: RawId -> MaterialState -> Maybe RawSnapshot
latestSnapshotFor raw material = case sortOn rawSnapshotCreationOrdinal
    [snapshot | snapshot <- Map.elems (materialSnapshots material),
      rawSnapshotRaw snapshot == raw] of
  [] -> Nothing
  values -> Just (last values)

deduplicateCandidates :: [ProposalCandidate] -> [ProposalCandidate]
deduplicateCandidates = Map.elems . Map.fromList . map (\value ->
  (candidateSource value, value))

------------------------------------------------------------
-- Forecast projection and replay-safe draws
------------------------------------------------------------

-- | Construct a forecast without changing either selection or domain state.
buildForecast ::
  UTCTime -> Integer -> SelectionContext -> SelectionState ->
  Either SelectionError ForecastView
buildForecast at domainRevision context state = do
  when (domainRevision < 0)
    (Left (SelectionInvalidTransition "forecast domain revision cannot be negative"))
  ordinary <- mapM (brickForecastDraft at context state) eligible
  let proposals =
        [ ForecastDraft Nothing (Just (proposalId proposal)) 1
            ["unresolved " <> proposalKindText (proposalKind proposal)]
        | proposal <- projectedOpenProposals at context state
        , proposalAvailableAt proposal <= at
        ]
      drafts = ordinary <> proposals
      total = sum (map draftWeight drafts)
  when (not (null drafts) && total <= 0)
    (Left (SelectionInvariantViolation ["eligible forecast has no positive mass"]))
  let items = [ForecastItem (draftBrick draft) (draftProposal draft)
        (draftWeight draft) (if total == 0 then 0 else draftWeight draft / total)
        (draftReasons draft) | draft <- drafts]
      forecast = ForecastView domainRevision at items
  validateForecast context forecast
  pure forecast
  where
    domain = selectionDomain context
    eligible = sortOn brickId
      [brick | brick <- Map.elems (domainBricks domain),
        executableCandidate at context brick]

data ForecastDraft = ForecastDraft
  { draftBrick :: Maybe BrickId
  , draftProposal :: Maybe ProposalId
  , draftWeight :: Double
  , draftReasons :: [Text]
  }

brickForecastDraft ::
  UTCTime -> SelectionContext -> SelectionState -> Brick ->
  Either SelectionError ForecastDraft
brickForecastDraft at context state brick = do
  let domain = selectionDomain context
      priority = selectionPriority context
      judgment = selectionJudgment context
      identifier = brickId brick
      base = [(1.0, "eligible active work")]
      priorityContribution = case Priority.priorityViewItem priority identifier of
        Left _ -> []
        Right item ->
          let pathCost = fromIntegral (sum (Priority.priorityViewItemTreePath item))
          in [(2 / (1 + pathCost), "human priority path")]
      focusContribution =
        [(2.0, "currently in human WIP") | brickWorkState brick == Wip]
      phaseContribution = case brickPhase brick of
        Nothing -> []
        Just phase -> [(phaseWeight phase, "applicable phase: " <> phaseText phase)]
      impactContribution = case rootOf domain identifier >>= \root ->
          Judgment.currentImpactAssessment judgment root of
        Nothing -> []
        Just assessment -> [(impactWeight (Judgment.impactAssessmentImpact assessment),
          "optional impact evidence")]
      effortContribution = case Judgment.currentEffortAssessment judgment identifier of
        Nothing -> []
        Just assessment ->
          let ordinal = Judgment.effortBandOrdinal
                (Judgment.effortAssessmentBand assessment)
          in [(1 / (1 + fromIntegral ordinal), "optional effort evidence")]
      dateContributions = datePressure at domain identifier
      ageDays = max 0 (realToFrac (diffUTCTime at (brickCreatedAt brick)) / 86400)
      agingContribution = [(min 2 (ageDays * 0.01), "aging pressure") | ageDays > 0]
      unlockContributions = blockerPressure context brick
      opportunityContributions = standingPressure context identifier
      contributions = base <> priorityContribution <> focusContribution
        <> phaseContribution <> impactContribution <> effortContribution
        <> dateContributions <> agingContribution <> unlockContributions
        <> opportunityContributions
      uncoolWeight = sum (map fst contributions)
      uncoolReasons = map snd (filter ((> 0) . fst) contributions)
      (weight, reasons) = case Map.lookup identifier
          (selectionStateCooldowns state) of
        Just cooldown
          | selectionCooldownUntil cooldown > at ->
              (max 0.000001 (uncoolWeight * 0.2),
                uncoolReasons <> ["served-skip cooldown"])
          | otherwise ->
              (uncoolWeight + 0.4 * fromIntegral
                  (selectionCooldownRecentSkipCount cooldown),
                uncoolReasons <> ["retained served-skip pressure"])
        Nothing -> (uncoolWeight, uncoolReasons)
  unless (weight > 0 && not (null reasons))
    (Left (SelectionInvariantViolation
      ["eligible Brick lacks positive explained forecast weight"]))
  pure (ForecastDraft (Just identifier) Nothing weight reasons)

executableCandidate :: UTCTime -> SelectionContext -> Brick -> Bool
executableCandidate at context brick =
  brickStatus brick == Active
  && dateAllows
  && not hasOpenWait
  && not hasActiveDependency
  && placeAllows
  && not dormant
  where
    identifier = brickId brick
    domain = selectionDomain context
    coordination = standingStateCoordination (selectionContextStanding context)
    dateAllows = case effectiveNotBefore domain identifier of
      Right (Just value) -> value <= at
      Right Nothing -> True
      Left _ -> False
    hasOpenWait = any (\wait -> waitBrick wait == identifier
        && waitStatus wait == WaitOpen)
      (Map.elems (coordinationStateWaits coordination))
    hasActiveDependency = any (\dependency ->
        dependencyBlocked dependency == identifier
        && dependencyStatus dependency == DependencyActive)
      (Map.elems (coordinationStateDependencies coordination))
    placeAllows = case evaluatePlaceConditions at identifier coordination of
      Right evaluation -> placeEvaluationEligible evaluation
      Left _ -> False
    dormant = behaviorEmptyIsDormant (brickBehavior brick)
      && null [child | child <- Map.elems (domainBricks domain),
        brickParent child == Just identifier, brickStatus child == Active]
      && null [entry | entry <- Map.elems (domainListEntries domain),
        listEntryOwner entry == identifier, listEntryStatus entry == EntryOpen]
      && null (standingPressure context identifier)

forecastItemForBrick :: BrickId -> ForecastView -> Maybe ForecastItem
forecastItemForBrick identifier forecast = find
  ((== Just identifier) . forecastItemBrick) (forecastViewItems forecast)

requestNext ::
  UTCTime -> Integer -> Text -> SelectionContext -> SelectionState ->
  Either SelectionError (NextDraw, SelectionState)
requestNext at domainRevision randomEvidence context state = do
  forecast <- buildForecast at domainRevision context state
  let domain = selectionDomain context
      focus = focusRegisterCurrent (domainFocusRegister domain)
      focusedItem = focus >>= \identifier -> do
        brick <- Map.lookup identifier (domainBricks domain)
        if executableCandidate at context brick
          then forecastItemForBrick identifier forecast else Nothing
  selected <- case focusedItem of
    Just item -> Right item
      {forecastItemReasons = ["current focus remains valid"]}
    Nothing -> replaySafeWeightedDraw randomEvidence forecast
  let (identifier, allocated) = allocateId "next-draw" NextDrawId state
      selectedBrick = forecastItemBrick selected
      selectedProposal = forecastItemProposal selected
      reasons = forecastItemReasons selected
      draw = NextDraw identifier selectedBrick selectedProposal domainRevision
        randomEvidence at reasons forecast
      stored = StoredNextDraw identifier selectedBrick selectedProposal
        domainRevision randomEvidence at reasons
      changed = allocated {selectionStateDraws = Map.insert identifier stored
        (selectionStateDraws allocated)}
  committed <- commit "next_drawn" changed
  pure (draw, committed)

replaySafeWeightedDraw :: Text -> ForecastView -> Either SelectionError ForecastItem
replaySafeWeightedDraw evidence forecast = do
  let items = forecastViewItems forecast
  when (null items) (Left SelectionNoCandidate)
  let target = stableUnitInterval evidence
  maybe (Left SelectionNoCandidate) Right (pick target 0 items)
  where
    pick _ _ [] = Nothing
    pick _target _cumulative [item] =
      if forecastItemProbability item > 0 then Just item else Nothing
    pick target cumulative (item : rest)
      | target < cumulative + forecastItemProbability item = Just item
      | otherwise = pick target (cumulative + forecastItemProbability item) rest

simulateReplaySafeDraws ::
  Text -> Integer -> ForecastView -> Either SelectionError SimulationMetrics
simulateReplaySafeDraws seed samples forecast = do
  when (samples <= 0)
    (Left (SelectionInvalidTransition "simulation samples must be positive"))
  when (null (forecastViewItems forecast)) (Left SelectionNoCandidate)
  let stream = take (fromIntegral samples)
        (drop 1 (iterate lcg (stableSeed seed)))
      selected = map (drawAtUnit forecast . unitFromInteger) stream
  drawn <- sequence selected
  let counts = Map.fromListWith (+) [(forecastItemKey item, 1 :: Integer)
        | item <- drawn]
      metrics = [SimulationCandidateMetric (forecastItemKey item)
          (forecastItemProbability item)
          (fromIntegral (Map.findWithDefault 0 (forecastItemKey item) counts)
            / fromIntegral samples)
          (Map.findWithDefault 0 (forecastItemKey item) counts)
        | item <- forecastViewItems forecast]
  pure (SimulationMetrics seed samples metrics)

recordServedSkip ::
  BrickId -> SkipReason -> Maybe Text -> UTCTime -> SelectionContext ->
  SelectionState -> Either SelectionError (ServedSkip, SelectionCooldown, SelectionState)
recordServedSkip brick reason rawText at context state = do
  domainBrick <- maybe (Left (SelectionUnknownEntity "served Brick")) Right
    (Map.lookup brick (domainBricks (selectionDomain context)))
  unless (brickStatus domainBrick == Active)
    (Left (SelectionInvalidTransition "only an active Brick can be skipped"))
  when (reason == SkipOther && rawText == Nothing)
    (Left (SelectionInvalidTransition "other skip reason requires raw text"))
  let (skipId, allocatedSkip) = allocateId "served-skip" ServedSkipId state
      served = ServedSkip skipId brick reason rawText at
      (cooldownId, allocatedCooldown, previousCount) =
        case Map.lookup brick (selectionStateCooldowns allocatedSkip) of
          Just existing ->
            (selectionCooldownId existing, allocatedSkip,
              selectionCooldownRecentSkipCount existing)
          Nothing ->
            let (identifier, allocated) = allocateId "selection-cooldown"
                  SelectionCooldownId allocatedSkip
            in (identifier, allocated, 0)
      cooldown = SelectionCooldown cooldownId brick
        (addUTCTime servedSkipCooldown at) (previousCount + 1) reason
      changed = allocatedCooldown
        { selectionStateServedSkips = Map.insert skipId served
            (selectionStateServedSkips allocatedCooldown)
        , selectionStateCooldowns = Map.insert brick cooldown
            (selectionStateCooldowns allocatedCooldown)
        }
  committed <- commit "served_brick_skipped" changed
  pure (served, cooldown, committed)

------------------------------------------------------------
-- Pressure and deterministic helpers
------------------------------------------------------------

selectionExecution :: SelectionContext -> ExecutionState
selectionExecution = coordinationStateExecution . standingStateCoordination
  . selectionContextStanding

selectionDomain :: SelectionContext -> DomainState
selectionDomain = executionStateDomain . selectionExecution

selectionPriority :: SelectionContext -> Priority.PriorityState
selectionPriority = executionStatePriority . selectionExecution

selectionJudgment :: SelectionContext -> Judgment.JudgmentState
selectionJudgment = executionStateJudgment . selectionExecution

rootOf :: DomainState -> BrickId -> Maybe BrickId
rootOf domain identifier = do
  brick <- Map.lookup identifier (domainBricks domain)
  case brickParent brick of
    Nothing -> Just identifier
    Just parent -> rootOf domain parent

phaseWeight :: BrickPhase -> Double
phaseWeight phase = case phase of
  Idea -> 0.1
  Spec -> 0.2
  Exec -> 0.4
  Validation -> 0.3

phaseText :: BrickPhase -> Text
phaseText phase = case phase of
  Idea -> "idea"
  Spec -> "spec"
  Exec -> "exec"
  Validation -> "validation"

impactWeight :: Judgment.ImpactClass -> Double
impactWeight impact = case impact of
  Judgment.VeryLowImpact -> 0.1
  Judgment.LowImpact -> 0.2
  Judgment.MediumImpact -> 0.4
  Judgment.HighImpact -> 0.8
  Judgment.VeryHighImpact -> 1.2
  Judgment.CriticalImpact -> 1.8

datePressure :: UTCTime -> DomainState -> BrickId -> [(Double, Text)]
datePressure at domain identifier = catMaybes
  [ case effectiveBestBefore domain identifier of
      Right (Just value) | value <= at -> Just (1, "best-before pressure")
      _ -> Nothing
  , case effectiveDeadline domain identifier of
      Right (Just value) | value <= at -> Just (2, "overdue deadline pressure")
      Right (Just value) | diffUTCTime value at <= 7 * 86400 ->
          Just (0.75, "approaching deadline pressure")
      _ -> Nothing
  ]

blockerPressure :: SelectionContext -> Brick -> [(Double, Text)]
blockerPressure context brick = map pressure blocked
  where
    standing = selectionContextStanding context
    coordination = standingStateCoordination standing
    domain = selectionDomain context
    blocked = [dependencyBlocked dependency
      | dependency <- Map.elems (coordinationStateDependencies coordination)
      , dependencyStatus dependency == DependencyActive
      , dependencyBlocker dependency == brickId brick]
    pressure identifier = case Map.lookup identifier (domainBricks domain) of
      Just target | behaviorRepetition (brickBehavior target) == Practice ->
        (2.5, "unlocks important practice")
      _ -> (1.5, "unlocks blocked work")

standingPressure :: SelectionContext -> BrickId -> [(Double, Text)]
standingPressure context identifier =
  [(1.0, "open practice opportunity") | hasOpenPractice]
  <> [(1.0, "triggered opportunity") | hasTriggeredOpportunity]
  where
    standing = selectionContextStanding context
    practiceRuleIds = Set.fromList
      [recurrenceRuleId rule | rule <- Map.elems (standingStateRecurrences standing),
        recurrenceRuleTarget rule == identifier,
        recurrenceRuleKind rule == PracticeRecurrence]
    hasOpenPractice = any (\opportunity ->
        Set.member (practiceOpportunityRule opportunity) practiceRuleIds
        && practiceOpportunityStatus opportunity == OpportunityOpen)
      (Map.elems (standingStatePracticeOpportunities standing))
    hasTriggeredOpportunity = any (\opportunity ->
        triggeredOpportunityTarget opportunity == identifier
        && triggeredOpportunityConsumedAt opportunity == Nothing)
      (Map.elems (standingStateTriggeredOpportunities standing))

forecastItemKey :: ForecastItem -> Text
forecastItemKey item = case (forecastItemBrick item, forecastItemProposal item) of
  (Just brick, Nothing) -> "brick:" <> brickText brick
  (Nothing, Just proposal) -> "proposal:" <> unProposalId proposal
  _ -> "invalid"

stableSeed :: Text -> Integer
stableSeed = Text.foldl' (\total character ->
  (total * 16777619 + fromIntegral (ord character)) `mod` randomModulus) 2166136261

stableUnitInterval :: Text -> Double
stableUnitInterval = unitFromInteger . lcg . stableSeed

lcg :: Integer -> Integer
lcg value = (1103515245 * value + 12345) `mod` randomModulus

randomModulus :: Integer
randomModulus = 2147483648

unitFromInteger :: Integer -> Double
unitFromInteger value = fromIntegral value / fromIntegral randomModulus

drawAtUnit :: ForecastView -> Double -> Either SelectionError ForecastItem
drawAtUnit forecast target = maybe (Left SelectionNoCandidate) Right
  (pick 0 (forecastViewItems forecast))
  where
    pick _ [] = Nothing
    pick _ [item] = Just item
    pick cumulative (item : rest)
      | target < cumulative + forecastItemProbability item = Just item
      | otherwise = pick (cumulative + forecastItemProbability item) rest

------------------------------------------------------------
-- Validation and identity
------------------------------------------------------------

validateForecast :: SelectionContext -> ForecastView -> Either SelectionError ()
validateForecast context forecast = do
  let items = forecastViewItems forecast
      probability = sum (map forecastItemProbability items)
      ordinaryEligible = Set.fromList
        [brickId brick | brick <- Map.elems (domainBricks (selectionDomain context)),
          executableCandidate (forecastViewGeneratedAt forecast) context brick]
      forecastBricks = Set.fromList (mapMaybe forecastItemBrick items)
      invalidKinds = [item | item <- items,
        isJust (forecastItemBrick item) == isJust (forecastItemProposal item)]
      unexplained = [item | item <- items,
        forecastItemWeight item <= 0 || forecastItemProbability item <= 0
        || null (forecastItemReasons item)]
      violations =
        ["ForecastItem does not select exactly one kind" | not (null invalidKinds)] <>
        ["eligible Brick is missing from forecast" |
          not (ordinaryEligible `Set.isSubsetOf` forecastBricks)] <>
        ["eligible forecast weight is not positive and explained" |
          not (null unexplained)] <>
        ["forecast probabilities do not sum to one" |
          not (null items) && abs (probability - 1) > 1e-9]
  unless (null violations) (Left (SelectionInvariantViolation violations))

validateSelectionState :: SelectionContext -> SelectionState -> Either SelectionError ()
validateSelectionState context state = do
  let proposals = selectionStateProposals state
      cooldowns = selectionStateCooldowns state
      skips = selectionStateServedSkips state
      draws = selectionStateDraws state
      domain = domainBricks (selectionDomain context)
      invalidDraw draw =
        isJust (storedNextDrawSelectedBrick draw)
          == isJust (storedNextDrawSelectedProposal draw)
      violations = concat
        [ ["selection revision/history/allocator is inconsistent" |
            selectionStateRevision state < 0
            || selectionStateNextOrdinal state < 1
            || selectionStatePracticeReviewThreshold state <= 0
            || selectionStateRevision state
              /= fromIntegral (length (selectionStateHistory state))]
        , ["Proposal map key differs from identity" | any (uncurry (/=))
            [(identifier, proposalId proposal) |
              (identifier, proposal) <- Map.toList proposals]]
        , ["Proposal has neither or multiple primary source relationships" |
            any (\proposal -> length (catMaybes
              [() <$ proposalBrick proposal, () <$ proposalRaw proposal,
               () <$ proposalInsertion proposal, () <$ proposalJudgmentProbe proposal,
               () <$ proposalDelegation proposal]) > 2)
              (Map.elems proposals)]
        , ["SelectionCooldown map key or count is invalid" | any
            (\(brick, cooldown) -> selectionCooldownBrick cooldown /= brick
              || selectionCooldownRecentSkipCount cooldown <= 0)
            (Map.toList cooldowns)]
        , ["SelectionCooldown references an unknown Brick" | any
            ((`Map.notMember` domain) . selectionCooldownBrick)
            (Map.elems cooldowns)]
        , ["ServedSkip map key differs from identity" | any (uncurry (/=))
            [(identifier, servedSkipId served) |
              (identifier, served) <- Map.toList skips]]
        , ["ServedSkip references an unknown Brick" | any
            ((`Map.notMember` domain) . servedSkipBrick) (Map.elems skips)]
        , ["NextDraw map key differs from identity or selects invalid kinds" |
            any (\(identifier, draw) -> storedNextDrawId draw /= identifier
              || invalidDraw draw) (Map.toList draws)]
        ]
  unless (null violations) (Left (SelectionInvariantViolation violations))

commit :: Text -> SelectionState -> Either SelectionError SelectionState
commit action state =
  let next = state
        { selectionStateRevision = selectionStateRevision state + 1
        , selectionStateHistory = selectionStateHistory state <> [action]
        }
  in if selectionStateRevision next
      == fromIntegral (length (selectionStateHistory next))
    then Right next
    else Left (SelectionInvariantViolation
      ["selection revision and history diverged"])

allocateId ::
  Text -> (Text -> identifier) -> SelectionState -> (identifier, SelectionState)
allocateId kind wrap state =
  let ordinal = selectionStateNextOrdinal state
      identifier = wrap ("la1:" <> kind <> ":" <> Text.pack (show ordinal))
  in (identifier, state {selectionStateNextOrdinal = ordinal + 1})

requireProposal :: ProposalId -> SelectionState -> Either SelectionError Proposal
requireProposal identifier state = maybe
  (Left (SelectionUnknownEntity "Proposal")) Right
  (Map.lookup identifier (selectionStateProposals state))

brickText :: BrickId -> Text
brickText = unBrickId

rawIdText :: RawId -> Text
rawIdText = unRawId

rawLinkText :: RawLinkId -> Text
rawLinkText = unRawLinkId

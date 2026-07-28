{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Explicit coordination, checklist, date-notice, and place state.
--
-- This slice deliberately consumes an explicit clock and explicit location
-- observations.  It has no sensor or notification capability: derived place
-- eligibility and date pressure can change without changing human priority or
-- silently executing work.
module LittleAnt.V1.Coordination
  ( CoordinationError (..)
  , CoordinationState (..)
  , DateNotice (..)
  , DateNoticeId (..)
  , Delegation (..)
  , DelegationId (..)
  , DelegationStatus (..)
  , Dependency (..)
  , DependencyId (..)
  , DependencyStatus (..)
  , LocationObservation (..)
  , LocationObservationId (..)
  , LocationObservationKind (..)
  , NoticeKind (..)
  , NoticeStatus (..)
  , Place (..)
  , PlaceCondition (..)
  , PlaceConditionId (..)
  , PlaceEvaluation (..)
  , PlaceId (..)
  , PlaceStrength (..)
  , Wait (..)
  , WaitId (..)
  , WaitStatus (..)
  , acknowledgeDateNotice
  , activeDateNotices
  , addCoordinationDependency
  , addCoordinationListEntry
  , addCoordinationWait
  , addPlaceCondition
  , advanceCoordinationTime
  , abandonDelegation
  , approveDelegationNotice
  , bestBeforeNoticeLead
  , cancelCoordinationDependency
  , cancelCoordinationWait
  , clearCoordinationBestBefore
  , clearCoordinationDeadline
  , clearCoordinationNotBefore
  , completeCoordinationBrick
  , completeFiniteChecklist
  , completeDelegation
  , createCoordinationBrick
  , createCoordinationParty
  , createPlace
  , deadlineNoticeLead
  , draftDelegation
  , dropCoordinationBrick
  , emptyCoordinationState
  , evaluatePlaceConditions
  , locationObservationTtl
  , markDelegationInProgress
  , moveCoordinationSubtree
  , recordLocationObservation
  , refuseDelegation
  , removeCoordinationListEntry
  , resolveCoordinationListEntry
  , resolveCoordinationWait
  , setCoordinationBestBefore
  , setCoordinationDeadline
  , setCoordinationNotBefore
  , snoozeDateNotice
  , validateCoordinationState
  ) where

import Control.Monad (foldM, unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey, Value (..),
   defaultOptions, genericParseJSON, genericToJSON, withText)
import qualified Data.Aeson.Types as AesonTypes
import Data.Char (toLower)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (isJust, mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (NominalDiffTime, UTCTime, addUTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain
  (Authority, Brick (..), BrickDraft, BrickId, BrickStatus (..), DomainError,
   DomainState (..), Lifetime (..), ListEntry (..), ListEntryDraft, ListEntryId,
   ListEntryStatus (..), Party (..), PartyId, PartyType,
   behaviorLifetime, behaviorOwnsEntries, clearBrickBestBefore,
   clearBrickDeadline, clearBrickNotBefore, createListEntry, createParty,
   effectiveBestBefore, effectiveDateRevision, effectiveDeadline,
   removeListEntry, resolveListEntry, setBrickBestBefore, setBrickDeadline,
   setBrickNotBefore, subtreeBricks)
import LittleAnt.V1.Execution
  (ExecutionError, ExecutionState (..), completeExecutionBrick,
   createExecutionBrick, dropExecutionBrick, emptyExecutionState,
   moveExecutionSubtree, validateExecutionState)
import qualified LittleAnt.V1.Priority as Priority

------------------------------------------------------------
-- Closed vocabulary and identity
------------------------------------------------------------

data WaitStatus = WaitOpen | WaitResolved | WaitCancelled
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data DependencyStatus = DependencyActive | DependencySatisfied | DependencyCancelled
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data DelegationStatus
  = AwaitingApproval
  | Notified
  | DelegationInProgress
  | DelegationCompleted
  | DelegationRefused
  | DelegationAbandoned
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data NoticeKind
  = BestBeforeApproaching
  | BestBeforePassed
  | DeadlineApproaching
  | DeadlineOverdue
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data NoticeStatus = NoticePending | NoticeAcknowledged | NoticeSnoozed | NoticeResolved
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data PlaceStrength = PlaceHard | PlaceSoft
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data LocationObservationKind = LocationEntered | LocationLeft | LocationPresent
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON WaitStatus where toJSON = enumJSON waitStatusText
instance FromJSON WaitStatus where parseJSON = parseEnum "WaitStatus" waitStatusText
instance ToJSON DependencyStatus where toJSON = enumJSON dependencyStatusText
instance FromJSON DependencyStatus where parseJSON = parseEnum "DependencyStatus" dependencyStatusText
instance ToJSON DelegationStatus where toJSON = enumJSON delegationStatusText
instance FromJSON DelegationStatus where parseJSON = parseEnum "DelegationStatus" delegationStatusText
instance ToJSON NoticeKind where toJSON = enumJSON noticeKindText
instance FromJSON NoticeKind where parseJSON = parseEnum "NoticeKind" noticeKindText
instance ToJSON NoticeStatus where toJSON = enumJSON noticeStatusText
instance FromJSON NoticeStatus where parseJSON = parseEnum "NoticeStatus" noticeStatusText
instance ToJSON PlaceStrength where toJSON = enumJSON placeStrengthText
instance FromJSON PlaceStrength where parseJSON = parseEnum "PlaceStrength" placeStrengthText
instance ToJSON LocationObservationKind where toJSON = enumJSON locationKindText
instance FromJSON LocationObservationKind where
  parseJSON = parseEnum "LocationObservationKind" locationKindText

enumJSON :: (value -> Text) -> value -> Value
enumJSON render = String . render

parseEnum :: (Bounded value, Enum value) => String -> (value -> Text) -> Value -> AesonTypes.Parser value
parseEnum name render = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate [(render value, value) | value <- [minBound .. maxBound]])

waitStatusText :: WaitStatus -> Text
waitStatusText status = case status of
  WaitOpen -> "open"
  WaitResolved -> "resolved"
  WaitCancelled -> "cancelled"

dependencyStatusText :: DependencyStatus -> Text
dependencyStatusText status = case status of
  DependencyActive -> "active"
  DependencySatisfied -> "satisfied"
  DependencyCancelled -> "cancelled"

delegationStatusText :: DelegationStatus -> Text
delegationStatusText status = case status of
  AwaitingApproval -> "awaiting_approval"
  Notified -> "notified"
  DelegationInProgress -> "in_progress"
  DelegationCompleted -> "completed"
  DelegationRefused -> "refused"
  DelegationAbandoned -> "abandoned"

noticeKindText :: NoticeKind -> Text
noticeKindText kind = case kind of
  BestBeforeApproaching -> "best_before_approaching"
  BestBeforePassed -> "best_before_passed"
  DeadlineApproaching -> "deadline_approaching"
  DeadlineOverdue -> "deadline_overdue"

noticeStatusText :: NoticeStatus -> Text
noticeStatusText status = case status of
  NoticePending -> "pending"
  NoticeAcknowledged -> "acknowledged"
  NoticeSnoozed -> "snoozed"
  NoticeResolved -> "resolved"

placeStrengthText :: PlaceStrength -> Text
placeStrengthText strength = case strength of
  PlaceHard -> "hard"
  PlaceSoft -> "soft"

locationKindText :: LocationObservationKind -> Text
locationKindText kind = case kind of
  LocationEntered -> "entered"
  LocationLeft -> "left"
  LocationPresent -> "present"

newtype WaitId = WaitId {unWaitId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype DependencyId = DependencyId {unDependencyId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype DelegationId = DelegationId {unDelegationId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype DateNoticeId = DateNoticeId {unDateNoticeId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype PlaceId = PlaceId {unPlaceId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype PlaceConditionId = PlaceConditionId {unPlaceConditionId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype LocationObservationId = LocationObservationId {unLocationObservationId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

------------------------------------------------------------
-- Entities and state
------------------------------------------------------------

data Wait = Wait
  { waitId :: WaitId
  , waitBrick :: BrickId
  , waitOnParty :: Maybe PartyId
  , waitCondition :: Text
  , waitStatus :: WaitStatus
  , waitCreatedAt :: UTCTime
  , waitResolvedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

data Dependency = Dependency
  { dependencyId :: DependencyId
  , dependencyBlocked :: BrickId
  , dependencyBlocker :: BrickId
  , dependencyStatus :: DependencyStatus
  , dependencyCreatedAt :: UTCTime
  , dependencyResolvedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

data Delegation = Delegation
  { delegationId :: DelegationId
  , delegationBrick :: BrickId
  , delegationDelegate :: PartyId
  , delegationStatus :: DelegationStatus
  , delegationInstructions :: Text
  , delegationCreatedAt :: UTCTime
  , delegationLastContactAt :: Maybe UTCTime
  , delegationNextFollowupAt :: Maybe UTCTime
  , delegationResultNote :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data DateNotice = DateNotice
  { dateNoticeId :: DateNoticeId
  , dateNoticeBrick :: BrickId
  , dateNoticeKind :: NoticeKind
  , dateNoticeDateValue :: UTCTime
  , dateNoticeDateRevision :: Text
  , dateNoticeStatus :: NoticeStatus
  , dateNoticeCreatedAt :: UTCTime
  , dateNoticeSnoozedUntil :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

data Place = Place
  { placeId :: PlaceId
  , placeLabel :: Text
  , placeCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data PlaceCondition = PlaceCondition
  { placeConditionId :: PlaceConditionId
  , placeConditionBrick :: BrickId
  , placeConditionPlace :: PlaceId
  , placeConditionStrength :: PlaceStrength
  , placeConditionCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data LocationObservation = LocationObservation
  { locationObservationId :: LocationObservationId
  , locationObservationPlace :: PlaceId
  , locationObservationKind :: LocationObservationKind
  , locationObservationObservedAt :: UTCTime
  , locationObservationExpiresAt :: UTCTime
  , locationObservationAuthority :: Authority
  , locationObservationSource :: Text
  , locationObservationExternalObservationId :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data PlaceEvaluation = PlaceEvaluation
  { placeEvaluationEligible :: Bool
  , placeEvaluationHardRequired :: Bool
  , placeEvaluationMatchingHard :: [PlaceId]
  , placeEvaluationMatchingSoft :: [PlaceId]
  , placeEvaluationProposalKinds :: [Text]
  , placeEvaluationExternalTrace :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data CoordinationState = CoordinationState
  { coordinationStateRevision :: Integer
  , coordinationStateNextOrdinal :: Integer
  , coordinationStateExecution :: ExecutionState
  , coordinationStateWaits :: Map WaitId Wait
  , coordinationStateDependencies :: Map DependencyId Dependency
  , coordinationStateDelegations :: Map DelegationId Delegation
  , coordinationStateDateNotices :: Map DateNoticeId DateNotice
  , coordinationStatePlaces :: Map PlaceId Place
  , coordinationStatePlaceConditions :: Map PlaceConditionId PlaceCondition
  , coordinationStateLocationObservations :: Map LocationObservationId LocationObservation
  , coordinationStateChecklistReviews :: Set BrickId
  , coordinationStateDependencyReviews :: Set BrickId
  , coordinationStateHistory :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON Wait where toJSON = genericToJSON (recordOptions "wait")
instance FromJSON Wait where parseJSON = genericParseJSON (recordOptions "wait")
instance ToJSON Dependency where toJSON = genericToJSON (recordOptions "dependency")
instance FromJSON Dependency where parseJSON = genericParseJSON (recordOptions "dependency")
instance ToJSON Delegation where toJSON = genericToJSON (recordOptions "delegation")
instance FromJSON Delegation where parseJSON = genericParseJSON (recordOptions "delegation")
instance ToJSON DateNotice where toJSON = genericToJSON (recordOptions "dateNotice")
instance FromJSON DateNotice where parseJSON = genericParseJSON (recordOptions "dateNotice")
instance ToJSON Place where toJSON = genericToJSON (recordOptions "place")
instance FromJSON Place where parseJSON = genericParseJSON (recordOptions "place")
instance ToJSON PlaceCondition where toJSON = genericToJSON (recordOptions "placeCondition")
instance FromJSON PlaceCondition where parseJSON = genericParseJSON (recordOptions "placeCondition")
instance ToJSON LocationObservation where toJSON = genericToJSON (recordOptions "locationObservation")
instance FromJSON LocationObservation where parseJSON = genericParseJSON (recordOptions "locationObservation")
instance ToJSON PlaceEvaluation where toJSON = genericToJSON (recordOptions "placeEvaluation")
instance FromJSON PlaceEvaluation where parseJSON = genericParseJSON (recordOptions "placeEvaluation")
instance ToJSON CoordinationState where toJSON = genericToJSON (recordOptions "coordinationState")
instance FromJSON CoordinationState where parseJSON = genericParseJSON (recordOptions "coordinationState")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLower first : rest)

data CoordinationError
  = CoordinationDomainError DomainError
  | CoordinationExecutionError ExecutionError
  | CoordinationUnknownEntity Text
  | CoordinationInvalidTransition Text
  | CoordinationInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

emptyCoordinationState :: CoordinationState
emptyCoordinationState = CoordinationState
  { coordinationStateRevision = 0
  , coordinationStateNextOrdinal = 1
  , coordinationStateExecution = emptyExecutionState
  , coordinationStateWaits = Map.empty
  , coordinationStateDependencies = Map.empty
  , coordinationStateDelegations = Map.empty
  , coordinationStateDateNotices = Map.empty
  , coordinationStatePlaces = Map.empty
  , coordinationStatePlaceConditions = Map.empty
  , coordinationStateLocationObservations = Map.empty
  , coordinationStateChecklistReviews = Set.empty
  , coordinationStateDependencyReviews = Set.empty
  , coordinationStateHistory = []
  }

bestBeforeNoticeLead :: NominalDiffTime
bestBeforeNoticeLead = 7 * 24 * 60 * 60

deadlineNoticeLead :: NominalDiffTime
deadlineNoticeLead = 7 * 24 * 60 * 60

locationObservationTtl :: NominalDiffTime
locationObservationTtl = 4 * 60 * 60

------------------------------------------------------------
-- Composition helpers
------------------------------------------------------------

createCoordinationParty ::
  Text -> PartyType -> UTCTime -> CoordinationState ->
  Either CoordinationError (Party, CoordinationState)
createCoordinationParty label kind now state = do
  (party, domain) <- mapDomain (createParty label kind now (coordinationDomain state))
  next <- withDomain domain state >>= commit "party_created"
  pure (party, next)

createCoordinationBrick ::
  BrickDraft -> Text -> UTCTime -> CoordinationState ->
  Either CoordinationError (Brick, Priority.PriorityInsertion, CoordinationState)
createCoordinationBrick draft evidence now state = do
  (brick, insertion, execution) <- mapExecution
    (createExecutionBrick draft evidence now (coordinationStateExecution state))
  next <- commit "brick_created" state {coordinationStateExecution = execution}
  pure (brick, insertion, next)

completeCoordinationBrick ::
  BrickId -> UTCTime -> CoordinationState -> Either CoordinationError CoordinationState
completeCoordinationBrick identifier now state = do
  execution <- mapExecution
    (completeExecutionBrick identifier now (coordinationStateExecution state))
  commit "brick_completed" (settleTerminal identifier Done now state
    {coordinationStateExecution = execution})

dropCoordinationBrick ::
  BrickId -> UTCTime -> CoordinationState -> Either CoordinationError CoordinationState
dropCoordinationBrick identifier now state = do
  execution <- mapExecution
    (dropExecutionBrick identifier now (coordinationStateExecution state))
  commit "brick_dropped" (settleTerminal identifier Dropped now state
    {coordinationStateExecution = execution})

moveCoordinationSubtree ::
  BrickId -> Maybe BrickId -> Text -> UTCTime -> CoordinationState ->
  Either CoordinationError (Priority.PriorityInsertion, CoordinationState)
moveCoordinationSubtree identifier newParent evidence now state = do
  affected <- mapDomain (subtreeBricks (coordinationDomain state) identifier)
  (insertion, execution) <- mapExecution
    (moveExecutionSubtree identifier newParent evidence now
      (coordinationStateExecution state))
  let next = resolveNoticesFor (Set.fromList (map brickId affected)) state
        {coordinationStateExecution = execution}
  committed <- commit "subtree_moved" next
  pure (insertion, committed)

------------------------------------------------------------
-- Waits, dependencies, and delegations
------------------------------------------------------------

addCoordinationWait ::
  BrickId -> Maybe PartyId -> Text -> UTCTime -> CoordinationState ->
  Either CoordinationError (Wait, CoordinationState)
addCoordinationWait brick party condition now state = do
  _ <- requireActiveBrick brick state
  mapM_ (`requireParty` state) party
  let (identifier, allocated) = allocateId "wait" WaitId state
      wait = Wait identifier brick party condition WaitOpen now Nothing
      next = allocated
        {coordinationStateWaits = Map.insert identifier wait
          (coordinationStateWaits allocated)}
  committed <- commit "wait_added" next
  pure (wait, committed)

resolveCoordinationWait ::
  WaitId -> UTCTime -> CoordinationState -> Either CoordinationError (Wait, CoordinationState)
resolveCoordinationWait = transitionWait WaitResolved "wait_resolved"

cancelCoordinationWait ::
  WaitId -> UTCTime -> CoordinationState -> Either CoordinationError (Wait, CoordinationState)
cancelCoordinationWait = transitionWait WaitCancelled "wait_cancelled"

transitionWait ::
  WaitStatus -> Text -> WaitId -> UTCTime -> CoordinationState ->
  Either CoordinationError (Wait, CoordinationState)
transitionWait status action identifier now state = do
  wait <- lookupEntity "Wait" identifier (coordinationStateWaits state)
  unless (waitStatus wait == WaitOpen)
    (Left (CoordinationInvalidTransition "only an open Wait can transition"))
  let updated = wait {waitStatus = status, waitResolvedAt = Just now}
      next = state {coordinationStateWaits = Map.insert identifier updated
        (coordinationStateWaits state)}
  committed <- commit action next
  pure (updated, committed)

addCoordinationDependency ::
  BrickId -> BrickId -> UTCTime -> CoordinationState ->
  Either CoordinationError (Dependency, CoordinationState)
addCoordinationDependency blocked blocker now state = do
  when (blocked == blocker)
    (Left (CoordinationInvalidTransition "a Brick cannot depend on itself"))
  _ <- requireActiveBrick blocked state
  _ <- requireActiveBrick blocker state
  when (any (sameActiveDependency blocked blocker)
      (Map.elems (coordinationStateDependencies state)))
    (Left (CoordinationInvalidTransition "active dependency already exists"))
  when (dependencyReachable state blocker blocked)
    (Left (CoordinationInvalidTransition "dependency would create a cycle"))
  let (identifier, allocated) = allocateId "dependency" DependencyId state
      dependency = Dependency identifier blocked blocker DependencyActive now Nothing
      next = allocated
        {coordinationStateDependencies = Map.insert identifier dependency
          (coordinationStateDependencies allocated)}
  committed <- commit "dependency_added" next
  pure (dependency, committed)

cancelCoordinationDependency ::
  DependencyId -> UTCTime -> CoordinationState ->
  Either CoordinationError (Dependency, CoordinationState)
cancelCoordinationDependency identifier now state = do
  dependency <- lookupEntity "Dependency" identifier
    (coordinationStateDependencies state)
  unless (dependencyStatus dependency == DependencyActive)
    (Left (CoordinationInvalidTransition "only an active Dependency can cancel"))
  let updated = dependency
        {dependencyStatus = DependencyCancelled, dependencyResolvedAt = Just now}
      next = state {coordinationStateDependencies = Map.insert identifier updated
        (coordinationStateDependencies state)}
  committed <- commit "dependency_cancelled" next
  pure (updated, committed)

draftDelegation ::
  BrickId -> PartyId -> Text -> Maybe UTCTime -> UTCTime -> CoordinationState ->
  Either CoordinationError (Delegation, CoordinationState)
draftDelegation brick delegate instructions followup now state = do
  _ <- requireActiveBrick brick state
  _ <- requireParty delegate state
  let (identifier, allocated) = allocateId "delegation" DelegationId state
      delegation = Delegation identifier brick delegate AwaitingApproval instructions
        now Nothing followup Nothing
      next = allocated
        {coordinationStateDelegations = Map.insert identifier delegation
          (coordinationStateDelegations allocated)}
  committed <- commit "delegation_drafted" next
  pure (delegation, committed)

approveDelegationNotice ::
  DelegationId -> UTCTime -> CoordinationState ->
  Either CoordinationError (Delegation, CoordinationState)
approveDelegationNotice identifier now = transitionDelegation identifier [AwaitingApproval]
  Notified (\delegation -> delegation {delegationLastContactAt = Just now})
  "delegation_notified"

markDelegationInProgress ::
  DelegationId -> CoordinationState -> Either CoordinationError (Delegation, CoordinationState)
markDelegationInProgress identifier = transitionDelegation identifier [Notified]
  DelegationInProgress id "delegation_started"

completeDelegation ::
  DelegationId -> Maybe Text -> CoordinationState ->
  Either CoordinationError (Delegation, CoordinationState)
completeDelegation identifier note = transitionDelegation identifier
  [Notified, DelegationInProgress] DelegationCompleted
  (\delegation -> delegation {delegationResultNote = note}) "delegation_completed"

refuseDelegation ::
  DelegationId -> Maybe Text -> CoordinationState ->
  Either CoordinationError (Delegation, CoordinationState)
refuseDelegation identifier note = transitionDelegation identifier
  [Notified, DelegationInProgress] DelegationRefused
  (\delegation -> delegation {delegationResultNote = note}) "delegation_refused"

abandonDelegation ::
  DelegationId -> Maybe Text -> CoordinationState ->
  Either CoordinationError (Delegation, CoordinationState)
abandonDelegation identifier note = transitionDelegation identifier
  [AwaitingApproval, Notified, DelegationInProgress] DelegationAbandoned
  (\delegation -> delegation {delegationResultNote = note}) "delegation_abandoned"

transitionDelegation ::
  DelegationId -> [DelegationStatus] -> DelegationStatus ->
  (Delegation -> Delegation) -> Text -> CoordinationState ->
  Either CoordinationError (Delegation, CoordinationState)
transitionDelegation identifier allowed status amend action state = do
  delegation <- lookupEntity "Delegation" identifier
    (coordinationStateDelegations state)
  unless (delegationStatus delegation `elem` allowed)
    (Left (CoordinationInvalidTransition "Delegation transition is not declared"))
  let updated = amend delegation {delegationStatus = status}
      next = state {coordinationStateDelegations = Map.insert identifier updated
        (coordinationStateDelegations state)}
  committed <- commit action next
  pure (updated, committed)

------------------------------------------------------------
-- Structured entries
------------------------------------------------------------

addCoordinationListEntry ::
  ListEntryDraft -> CoordinationState ->
  Either CoordinationError (ListEntry, CoordinationState)
addCoordinationListEntry draft state = do
  (entry, domain) <- mapDomain (createListEntry draft (coordinationDomain state))
  next <- withDomain domain state >>= commit "list_entry_added"
  pure (entry, next)

resolveCoordinationListEntry ::
  ListEntryId -> UTCTime -> CoordinationState ->
  Either CoordinationError (ListEntry, CoordinationState)
resolveCoordinationListEntry identifier now state = do
  (entry, domain) <- mapDomain
    (resolveListEntry identifier now (coordinationDomain state))
  next <- withDomain domain state
  committed <- commit "list_entry_resolved" (suggestChecklistReview entry next)
  pure (entry, committed)

removeCoordinationListEntry ::
  ListEntryId -> Maybe Text -> UTCTime -> CoordinationState ->
  Either CoordinationError (ListEntry, CoordinationState)
removeCoordinationListEntry identifier reason now state = do
  (entry, domain) <- mapDomain
    (removeListEntry identifier reason now (coordinationDomain state))
  next <- withDomain domain state
  committed <- commit "list_entry_removed" (suggestChecklistReview entry next)
  pure (entry, committed)

-- | Completion remains explicit.  Empty entries only suggest review; this
-- operation accepts that outcome only when no active child remains.
completeFiniteChecklist ::
  BrickId -> UTCTime -> CoordinationState -> Either CoordinationError CoordinationState
completeFiniteChecklist owner now state = do
  brick <- requireActiveBrick owner state
  unless (behaviorOwnsEntries (brickBehavior brick)
      && behaviorLifetime (brickBehavior brick) == Finite)
    (Left (CoordinationInvalidTransition "Brick is not a finite checklist"))
  let domain = coordinationDomain state
      openEntries = [entry | entry <- Map.elems (domainListEntries domain),
        listEntryOwner entry == owner, listEntryStatus entry == EntryOpen]
      activeChildren = [child | child <- Map.elems (domainBricks domain),
        brickParent child == Just owner, brickStatus child == Active]
  unless (null openEntries)
    (Left (CoordinationInvalidTransition "finite checklist still has open entries"))
  unless (null activeChildren)
    (Left (CoordinationInvalidTransition "finite checklist still has active children"))
  completeCoordinationBrick owner now state

suggestChecklistReview :: ListEntry -> CoordinationState -> CoordinationState
suggestChecklistReview entry state = case Map.lookup (listEntryOwner entry)
    (domainBricks (coordinationDomain state)) of
  Just owner
    | brickStatus owner == Active
    , behaviorOwnsEntries (brickBehavior owner)
    , behaviorLifetime (brickBehavior owner) == Finite
    , null [candidate | candidate <- Map.elems
        (domainListEntries (coordinationDomain state)),
        listEntryOwner candidate == brickId owner,
        listEntryStatus candidate == EntryOpen] -> state
          {coordinationStateChecklistReviews = Set.insert (brickId owner)
            (coordinationStateChecklistReviews state)}
  _ -> state

------------------------------------------------------------
-- Effective-date notices
------------------------------------------------------------

setCoordinationNotBefore ::
  BrickId -> UTCTime -> CoordinationState -> Either CoordinationError CoordinationState
setCoordinationNotBefore identifier value = applyDateChange identifier
  (sndMapDomain . setBrickNotBefore identifier value) "not_before_set"

clearCoordinationNotBefore ::
  BrickId -> CoordinationState -> Either CoordinationError CoordinationState
clearCoordinationNotBefore identifier = applyDateChange identifier
  (sndMapDomain . clearBrickNotBefore identifier) "not_before_cleared"

setCoordinationBestBefore ::
  BrickId -> UTCTime -> CoordinationState -> Either CoordinationError CoordinationState
setCoordinationBestBefore identifier value = applyDateChange identifier
  (sndMapDomain . setBrickBestBefore identifier value) "best_before_set"

clearCoordinationBestBefore ::
  BrickId -> CoordinationState -> Either CoordinationError CoordinationState
clearCoordinationBestBefore identifier = applyDateChange identifier
  (sndMapDomain . clearBrickBestBefore identifier) "best_before_cleared"

setCoordinationDeadline ::
  BrickId -> UTCTime -> CoordinationState -> Either CoordinationError CoordinationState
setCoordinationDeadline identifier value = applyDateChange identifier
  (sndMapDomain . setBrickDeadline identifier value) "deadline_set"

clearCoordinationDeadline ::
  BrickId -> CoordinationState -> Either CoordinationError CoordinationState
clearCoordinationDeadline identifier = applyDateChange identifier
  (sndMapDomain . clearBrickDeadline identifier) "deadline_cleared"

sndMapDomain :: Either DomainError (Brick, DomainState) -> Either CoordinationError DomainState
sndMapDomain = fmap snd . mapDomain

applyDateChange ::
  BrickId -> (DomainState -> Either CoordinationError DomainState) -> Text ->
  CoordinationState -> Either CoordinationError CoordinationState
applyDateChange identifier transition action state = do
  affected <- mapDomain (subtreeBricks (coordinationDomain state) identifier)
  domain <- transition (coordinationDomain state)
  withChangedDomain <- withDomain domain state
  commit action (resolveNoticesFor (Set.fromList (map brickId affected))
    withChangedDomain)

advanceCoordinationTime ::
  UTCTime -> CoordinationState -> Either CoordinationError ([DateNotice], CoordinationState)
advanceCoordinationTime now state = do
  let woken = state {coordinationStateDateNotices = Map.map wake
        (coordinationStateDateNotices state)}
      wake notice
        | dateNoticeStatus notice == NoticeSnoozed
        , maybe False (<= now) (dateNoticeSnoozedUntil notice) = notice
            {dateNoticeStatus = NoticePending, dateNoticeSnoozedUntil = Nothing}
        | otherwise = notice
      beforeIds = Map.keysSet (coordinationStateDateNotices woken)
      activeBricks = sortOn brickId
        [brick | brick <- Map.elems (domainBricks (coordinationDomain woken)),
          brickStatus brick == Active]
  emitted <- foldM (emitNoticesForBrick now) woken activeBricks
  committed <- commit "time_advanced" emitted
  let created = [notice | (identifier, notice) <- Map.toList
        (coordinationStateDateNotices committed), Set.notMember identifier beforeIds]
  pure (created, committed)

emitNoticesForBrick ::
  UTCTime -> CoordinationState -> Brick -> Either CoordinationError CoordinationState
emitNoticesForBrick now state brick = do
  let domain = coordinationDomain state
      identifier = brickId brick
  fingerprint <- mapDomain (effectiveDateRevision domain identifier)
  bestBefore <- mapDomain (effectiveBestBefore domain identifier)
  deadline <- mapDomain (effectiveDeadline domain identifier)
  foldM (emit fingerprint identifier) state
    (mapMaybe id
      [ bestBefore >>= threshold BestBeforeApproaching
          (\date -> date > now && date <= addUTCTime bestBeforeNoticeLead now)
      , bestBefore >>= threshold BestBeforePassed (<= now)
      , deadline >>= threshold DeadlineApproaching
          (\date -> date > now && date <= addUTCTime deadlineNoticeLead now)
      , deadline >>= threshold DeadlineOverdue (<= now)
      ])
  where
    threshold kind predicate date = if predicate date then Just (kind, date) else Nothing
    emit fingerprint identifier current (kind, date)
      | any (sameNoticeOccurrence identifier kind fingerprint)
          (Map.elems (coordinationStateDateNotices current)) = Right current
      | otherwise =
          let (noticeId, allocated) = allocateId "date-notice" DateNoticeId current
              notice = DateNotice noticeId identifier kind date fingerprint
                NoticePending now Nothing
          in Right allocated {coordinationStateDateNotices = Map.insert noticeId notice
              (coordinationStateDateNotices allocated)}

acknowledgeDateNotice ::
  DateNoticeId -> CoordinationState -> Either CoordinationError (DateNotice, CoordinationState)
acknowledgeDateNotice identifier state = do
  notice <- lookupEntity "DateNotice" identifier (coordinationStateDateNotices state)
  unless (dateNoticeStatus notice `elem` [NoticePending, NoticeSnoozed])
    (Left (CoordinationInvalidTransition "DateNotice cannot be acknowledged"))
  updateNotice "date_notice_acknowledged" notice
    {dateNoticeStatus = NoticeAcknowledged, dateNoticeSnoozedUntil = Nothing} state

snoozeDateNotice ::
  DateNoticeId -> UTCTime -> CoordinationState ->
  Either CoordinationError (DateNotice, CoordinationState)
snoozeDateNotice identifier snoozedUntil state = do
  notice <- lookupEntity "DateNotice" identifier (coordinationStateDateNotices state)
  unless (dateNoticeStatus notice == NoticePending)
    (Left (CoordinationInvalidTransition "only a pending DateNotice can snooze"))
  updateNotice "date_notice_snoozed" notice
    {dateNoticeStatus = NoticeSnoozed,
     dateNoticeSnoozedUntil = Just snoozedUntil} state

updateNotice ::
  Text -> DateNotice -> CoordinationState -> Either CoordinationError (DateNotice, CoordinationState)
updateNotice action notice state = do
  committed <- commit action state {coordinationStateDateNotices = Map.insert
    (dateNoticeId notice) notice (coordinationStateDateNotices state)}
  pure (notice, committed)

activeDateNotices :: BrickId -> NoticeKind -> CoordinationState -> [DateNotice]
activeDateNotices brick kind state = sortOn dateNoticeCreatedAt
  [notice | notice <- Map.elems (coordinationStateDateNotices state),
    dateNoticeBrick notice == brick, dateNoticeKind notice == kind,
    dateNoticeStatus notice /= NoticeResolved]

------------------------------------------------------------
-- Places and explicit observations
------------------------------------------------------------

createPlace ::
  Text -> UTCTime -> CoordinationState -> Either CoordinationError (Place, CoordinationState)
createPlace label now state = do
  let (identifier, allocated) = allocateId "place" PlaceId state
      place = Place identifier label now
      next = allocated {coordinationStatePlaces = Map.insert identifier place
        (coordinationStatePlaces allocated)}
  committed <- commit "place_created" next
  pure (place, committed)

addPlaceCondition ::
  BrickId -> PlaceId -> PlaceStrength -> UTCTime -> CoordinationState ->
  Either CoordinationError (PlaceCondition, CoordinationState)
addPlaceCondition brick place strength now state = do
  _ <- requireActiveBrick brick state
  _ <- lookupEntity "Place" place (coordinationStatePlaces state)
  when (any (\condition -> placeConditionBrick condition == brick
      && placeConditionPlace condition == place
      && placeConditionStrength condition == strength)
      (Map.elems (coordinationStatePlaceConditions state)))
    (Left (CoordinationInvalidTransition "duplicate PlaceCondition"))
  let (identifier, allocated) = allocateId "place-condition" PlaceConditionId state
      condition = PlaceCondition identifier brick place strength now
      next = allocated {coordinationStatePlaceConditions = Map.insert identifier condition
        (coordinationStatePlaceConditions allocated)}
  committed <- commit "place_condition_added" next
  pure (condition, committed)

recordLocationObservation ::
  PlaceId -> LocationObservationKind -> UTCTime -> Maybe UTCTime -> Authority ->
  Text -> Maybe Text -> CoordinationState ->
  Either CoordinationError (LocationObservation, CoordinationState)
recordLocationObservation place kind observedAt expiresAt authority source externalId state = do
  _ <- lookupEntity "Place" place (coordinationStatePlaces state)
  when (isJust externalId && any (sameExternalObservation source externalId)
      (Map.elems (coordinationStateLocationObservations state)))
    (Left (CoordinationInvalidTransition "external location observation is duplicate"))
  let (identifier, allocated) = allocateId "location-observation"
        LocationObservationId state
      observation = LocationObservation identifier place kind observedAt
        (maybe (addUTCTime locationObservationTtl observedAt) id expiresAt)
        authority source externalId
      next = allocated {coordinationStateLocationObservations = Map.insert
        identifier observation (coordinationStateLocationObservations allocated)}
  committed <- commit "location_observation_recorded" next
  pure (observation, committed)

-- | Derive eligibility from persisted evidence only.  The empty external trace
-- makes the no-hidden-location-I/O boundary inspectable by callers.
evaluatePlaceConditions ::
  UTCTime -> BrickId -> CoordinationState -> Either CoordinationError PlaceEvaluation
evaluatePlaceConditions now brick state = do
  _ <- lookupEntity "Brick" brick (domainBricks (coordinationDomain state))
  let conditions = [condition | condition <- Map.elems
        (coordinationStatePlaceConditions state), placeConditionBrick condition == brick]
      hardPlaces = Set.fromList [placeConditionPlace condition | condition <- conditions,
        placeConditionStrength condition == PlaceHard]
      softPlaces = Set.fromList [placeConditionPlace condition | condition <- conditions,
        placeConditionStrength condition == PlaceSoft]
      current = currentPresentPlaces now state
      matchingHard = Set.toAscList (Set.intersection hardPlaces current)
      matchingSoft = Set.toAscList (Set.intersection softPlaces current)
      hardRequired = not (Set.null hardPlaces)
      eligible = not hardRequired || not (null matchingHard)
      proposals = ["place_batch" | not (null matchingHard) || not (null matchingSoft)]
  pure PlaceEvaluation
    { placeEvaluationEligible = eligible
    , placeEvaluationHardRequired = hardRequired
    , placeEvaluationMatchingHard = matchingHard
    , placeEvaluationMatchingSoft = matchingSoft
    , placeEvaluationProposalKinds = proposals
    , placeEvaluationExternalTrace = []
    }

currentPresentPlaces :: UTCTime -> CoordinationState -> Set PlaceId
currentPresentPlaces now state = Set.fromList
  [place | place <- Map.keys (coordinationStatePlaces state), isCurrent place]
  where
    isCurrent place = case sortOn locationObservationObservedAt
        [observation | observation <- Map.elems
          (coordinationStateLocationObservations state),
          locationObservationPlace observation == place,
          locationObservationObservedAt observation <= now] of
      [] -> False
      observations -> let latest = last observations in
        locationObservationExpiresAt latest > now
        && locationObservationKind latest `elem` [LocationEntered, LocationPresent]

------------------------------------------------------------
-- Validation and helpers
------------------------------------------------------------

validateCoordinationState :: CoordinationState -> Either CoordinationError ()
validateCoordinationState state = do
  mapExecution (validateExecutionState (coordinationStateExecution state))
  unless (null violations) (Left (CoordinationInvariantViolation violations))
  where
    domain = coordinationDomain state
    bricks = domainBricks domain
    parties = domainParties domain
    waits = Map.elems (coordinationStateWaits state)
    dependencies = Map.elems (coordinationStateDependencies state)
    delegations = Map.elems (coordinationStateDelegations state)
    notices = Map.elems (coordinationStateDateNotices state)
    places = coordinationStatePlaces state
    conditions = Map.elems (coordinationStatePlaceConditions state)
    observations = Map.elems (coordinationStateLocationObservations state)
    noticeKeys = [(dateNoticeBrick notice, dateNoticeKind notice,
      dateNoticeDateRevision notice) | notice <- notices]
    externalKeys = [(locationObservationSource observation, externalId)
      | observation <- observations,
        externalId <- maybe [] pure (locationObservationExternalObservationId observation)]
    conditionKeys = [(placeConditionBrick condition, placeConditionPlace condition,
      placeConditionStrength condition) | condition <- conditions]
    activeDependencies = [dependency | dependency <- dependencies,
      dependencyStatus dependency == DependencyActive]
    violations = concat
      [ ["coordination revision or allocator is invalid" |
          coordinationStateRevision state < 0 || coordinationStateNextOrdinal state < 1]
      , ["Wait map key differs from identity" | any (uncurry (/=))
          [(identifier, waitId wait) | (identifier, wait) <- Map.toList
            (coordinationStateWaits state)]]
      , ["Wait references an unknown entity" | any (\wait ->
          Map.notMember (waitBrick wait) bricks
          || maybe False (`Map.notMember` parties) (waitOnParty wait)) waits]
      , ["Wait terminal fields are inconsistent" | any invalidWaitPresence waits]
      , ["Dependency references an unknown or identical Brick" | any (\dependency ->
          dependencyBlocked dependency == dependencyBlocker dependency
          || Map.notMember (dependencyBlocked dependency) bricks
          || Map.notMember (dependencyBlocker dependency) bricks) dependencies]
      , ["active dependency graph has a duplicate" | hasDuplicates
          [(dependencyBlocked dependency, dependencyBlocker dependency)
          | dependency <- activeDependencies]]
      , ["active dependency graph has a cycle" | any (\dependency ->
          dependencyReachableWithout (dependencyId dependency) state
            (dependencyBlocker dependency) (dependencyBlocked dependency))
          activeDependencies]
      , ["Dependency terminal fields are inconsistent" |
          any invalidDependencyPresence dependencies]
      , ["Delegation references an unknown entity" | any (\delegation ->
          Map.notMember (delegationBrick delegation) bricks
          || Map.notMember (delegationDelegate delegation) parties) delegations]
      , ["DateNotice references an unknown Brick" |
          any ((`Map.notMember` bricks) . dateNoticeBrick) notices]
      , ["DateNotice occurrence is duplicated" | hasDuplicates noticeKeys]
      , ["DateNotice snooze fields are inconsistent" |
          any invalidNoticePresence notices]
      , ["PlaceCondition references an unknown entity" | any (\condition ->
          Map.notMember (placeConditionBrick condition) bricks
          || Map.notMember (placeConditionPlace condition) places) conditions]
      , ["PlaceCondition is duplicated" | hasDuplicates conditionKeys]
      , ["LocationObservation references an unknown Place" | any
          ((`Map.notMember` places) . locationObservationPlace) observations]
      , ["external LocationObservation identity is duplicated" |
          hasDuplicates externalKeys]
      ]

invalidWaitPresence :: Wait -> Bool
invalidWaitPresence wait = (waitStatus wait == WaitOpen) == isJust (waitResolvedAt wait)

invalidDependencyPresence :: Dependency -> Bool
invalidDependencyPresence dependency =
  (dependencyStatus dependency == DependencyActive) == isJust (dependencyResolvedAt dependency)

invalidNoticePresence :: DateNotice -> Bool
invalidNoticePresence notice =
  (dateNoticeStatus notice == NoticeSnoozed) /= isJust (dateNoticeSnoozedUntil notice)

commit :: Text -> CoordinationState -> Either CoordinationError CoordinationState
commit action state = do
  let next = state
        { coordinationStateRevision = coordinationStateRevision state + 1
        , coordinationStateHistory = coordinationStateHistory state <> [action]
        }
  validateCoordinationState next
  pure next

coordinationDomain :: CoordinationState -> DomainState
coordinationDomain = executionStateDomain . coordinationStateExecution

withDomain :: DomainState -> CoordinationState -> Either CoordinationError CoordinationState
withDomain domain state = do
  let execution = (coordinationStateExecution state) {executionStateDomain = domain}
  mapExecution (validateExecutionState execution)
  pure state {coordinationStateExecution = execution}

requireActiveBrick :: BrickId -> CoordinationState -> Either CoordinationError Brick
requireActiveBrick identifier state = do
  brick <- lookupEntity "Brick" identifier (domainBricks (coordinationDomain state))
  unless (brickStatus brick == Active)
    (Left (CoordinationInvalidTransition "Brick is terminal"))
  pure brick

requireParty :: PartyId -> CoordinationState -> Either CoordinationError Party
requireParty identifier state = lookupEntity "Party" identifier
  (domainParties (coordinationDomain state))

lookupEntity :: (Ord identifier, Show identifier) =>
  Text -> identifier -> Map identifier value -> Either CoordinationError value
lookupEntity name identifier values = maybe
  (Left (CoordinationUnknownEntity (name <> ": " <> Text.pack (show identifier))))
  Right (Map.lookup identifier values)

allocateId ::
  Text -> (Text -> identifier) -> CoordinationState -> (identifier, CoordinationState)
allocateId kind wrap state =
  let ordinal = coordinationStateNextOrdinal state
      identifier = wrap ("la1:" <> kind <> ":" <> Text.pack (show ordinal))
  in (identifier, state {coordinationStateNextOrdinal = ordinal + 1})

sameActiveDependency :: BrickId -> BrickId -> Dependency -> Bool
sameActiveDependency blocked blocker dependency =
  dependencyStatus dependency == DependencyActive
  && dependencyBlocked dependency == blocked
  && dependencyBlocker dependency == blocker

dependencyReachable :: CoordinationState -> BrickId -> BrickId -> Bool
dependencyReachable = dependencyReachableWithout (DependencyId "")

dependencyReachableWithout ::
  DependencyId -> CoordinationState -> BrickId -> BrickId -> Bool
dependencyReachableWithout excluded state start target = go Set.empty start
  where
    edges = [(dependencyBlocked dependency, dependencyBlocker dependency)
      | dependency <- Map.elems (coordinationStateDependencies state),
        dependencyStatus dependency == DependencyActive,
        dependencyId dependency /= excluded]
    go visited current
      | current == target = True
      | Set.member current visited = False
      | otherwise = any (go (Set.insert current visited))
          [next | (blocked, next) <- edges, blocked == current]

sameNoticeOccurrence :: BrickId -> NoticeKind -> Text -> DateNotice -> Bool
sameNoticeOccurrence brick kind revision notice =
  dateNoticeBrick notice == brick && dateNoticeKind notice == kind
  && dateNoticeDateRevision notice == revision

sameExternalObservation :: Text -> Maybe Text -> LocationObservation -> Bool
sameExternalObservation source externalId observation =
  locationObservationSource observation == source
  && locationObservationExternalObservationId observation == externalId

settleTerminal ::
  BrickId -> BrickStatus -> UTCTime -> CoordinationState -> CoordinationState
settleTerminal identifier status now state = state
  { coordinationStateDependencies = Map.map settleDependency
      (coordinationStateDependencies state)
  , coordinationStateDateNotices = Map.map settleNotice
      (coordinationStateDateNotices state)
  , coordinationStateDependencyReviews = if status == Done then
      coordinationStateDependencyReviews state else Set.union blockedReviews
        (coordinationStateDependencyReviews state)
  }
  where
    blockedReviews = Set.fromList
      [dependencyBlocked dependency
      | dependency <- Map.elems (coordinationStateDependencies state),
        dependencyBlocker dependency == identifier,
        dependencyStatus dependency == DependencyActive]
    settleDependency dependency
      | dependencyBlocker dependency == identifier
      , dependencyStatus dependency == DependencyActive = dependency
          { dependencyStatus = if status == Done
              then DependencySatisfied else DependencyCancelled
          , dependencyResolvedAt = Just now
          }
      | otherwise = dependency
    settleNotice notice
      | dateNoticeBrick notice == identifier
      , dateNoticeStatus notice /= NoticeResolved = notice
          {dateNoticeStatus = NoticeResolved, dateNoticeSnoozedUntil = Nothing}
      | otherwise = notice

resolveNoticesFor :: Set BrickId -> CoordinationState -> CoordinationState
resolveNoticesFor affected state = state
  {coordinationStateDateNotices = Map.map resolve
    (coordinationStateDateNotices state)}
  where
    resolve notice
      | Set.member (dateNoticeBrick notice) affected
      , dateNoticeStatus notice /= NoticeResolved = notice
          {dateNoticeStatus = NoticeResolved, dateNoticeSnoozedUntil = Nothing}
      | otherwise = notice

hasDuplicates :: Ord value => [value] -> Bool
hasDuplicates values = Set.size (Set.fromList values) /= length values

mapDomain :: Either DomainError value -> Either CoordinationError value
mapDomain = either (Left . CoordinationDomainError) Right

mapExecution :: Either ExecutionError value -> Either CoordinationError value
mapExecution = either (Left . CoordinationExecutionError) Right

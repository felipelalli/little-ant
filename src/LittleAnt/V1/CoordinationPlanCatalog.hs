{-# LANGUAGE DerivingStrategies #-}

-- | Executable semantic probes for explicit coordination, date notices, and
-- place observations in the execution module.
module LittleAnt.V1.CoordinationPlanCatalog
  ( coordinationPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson (ToJSON (toJSON), Value (..), encode)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.V1.Contract (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Coordination
import LittleAnt.V1.Domain hiding (createBrick)
import qualified LittleAnt.V1.Execution as Execution

coordinationPlanProbes :: Map ProbeKey PlanProbe
coordinationPlanProbes = Map.fromList
  (enumRegistrations <> entityRegistrations <> optionalRegistrations
    <> transitionRegistrations <> ruleRegistrations <> configRegistrations
    <> invariantRegistrations <> temporalRegistrations)

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ registration "enum_comparable" construct (enumProbe values)
  | (construct, values) <-
      [ ("WaitStatus", map toJSON ([minBound .. maxBound] :: [WaitStatus]))
      , ("DependencyStatus", map toJSON ([minBound .. maxBound] :: [DependencyStatus]))
      , ("DelegationStatus", map toJSON ([minBound .. maxBound] :: [DelegationStatus]))
      , ("NoticeKind", map toJSON ([minBound .. maxBound] :: [NoticeKind]))
      , ("NoticeStatus", map toJSON ([minBound .. maxBound] :: [NoticeStatus]))
      , ("PlaceStrength", map toJSON ([minBound .. maxBound] :: [PlaceStrength]))
      , ("LocationObservationKind",
          map toJSON ([minBound .. maxBound] :: [LocationObservationKind]))
      ]
  ]

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [registration "entity_fields" construct (entityProbe construct)
  | construct <- ["Wait", "Dependency", "Delegation", "DateNotice", "Place",
      "PlaceCondition", "LocationObservation"]]

optionalRegistrations :: [(ProbeKey, PlanProbe)]
optionalRegistrations =
  [registration "entity_optional" construct (optionalProbe construct)
  | construct <-
      [ "Wait.on_party", "Wait.resolved_at", "Dependency.resolved_at"
      , "Delegation.last_contact_at", "Delegation.next_followup_at"
      , "Delegation.result_note", "DateNotice.snoozed_until"
      , "LocationObservation.external_observation_id"
      ]]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [registration category construct transitionProbe
  | category <- ["transition_edge", "transition_rejected", "transition_terminal"]
  , construct <- ["Wait.status", "Dependency.status", "Delegation.status",
      "DateNotice.status"]]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ rules ["rule_success", "rule_failure", "rule_entity_creation"]
      ["WaitAdded"] waitProbe
  , rules ["rule_success", "rule_failure"]
      ["WaitResolved", "WaitCancelled"] waitProbe
  , rules ["rule_success", "rule_failure", "rule_entity_creation"]
      ["DependencyAdded"] dependencyProbe
  , rules ["rule_success"]
      ["DependencySatisfiedByCompletion", "DependencyCancelledByNonCompletion"]
      dependencyProbe
  , rules ["rule_success", "rule_failure"]
      ["DependencyRemovedExplicitly"] dependencyProbe
  , rules ["rule_success", "rule_failure", "rule_entity_creation"]
      ["DelegationDrafted"] delegationProbe
  , rules ["rule_success", "rule_failure"]
      [ "DelegationApprovedAndNotified", "DelegationStarted"
      , "DelegationCompleted", "DelegationRefused", "DelegationAbandoned"
      ] delegationProbe
  , rules ["rule_success", "rule_failure", "rule_entity_creation"]
      ["ListEntryAdded"] entryProbe
  , rules ["rule_success", "rule_failure"]
      ["ListEntryResolved", "ListEntryRemoved", "FiniteChecklistBecameEmpty"]
      entryProbe
  , rules ["rule_success"]
      ["DateConfigurationChangeResolvesSupersededNotices",
       "TerminalBrickResolvesDateNotices"] dateProbe
  , rules ["rule_success", "rule_failure", "rule_entity_creation"]
      [ "BestBeforeApproachingNoticeCreated", "BestBeforePassedNoticeCreated"
      , "DeadlineApproachingNoticeCreated", "DeadlineOverdueNoticeCreated"
      ] dateProbe
  , rules ["rule_success", "rule_failure"]
      ["DateNoticeAcknowledged", "DateNoticeSnoozed", "DateNoticeSnoozeEnded"]
      dateProbe
  , rules ["rule_success", "rule_entity_creation"] ["PlaceCreated"] placeProbe
  , rules ["rule_success", "rule_failure", "rule_entity_creation"]
      ["PlaceConditionAdded", "LocationObservationRecorded"] placeProbe
  ]
  where
    rules categories constructs probe =
      [registration category construct probe
      | category <- categories, construct <- constructs]

configRegistrations :: [(ProbeKey, PlanProbe)]
configRegistrations =
  [ registration "config_default" "config.best_before_notice_lead"
      (require (bestBeforeNoticeLead == 7 * 24 * 60 * 60)
        "best-before lead is not seven days")
  , registration "config_default" "config.deadline_notice_lead"
      (require (deadlineNoticeLead == 7 * 24 * 60 * 60)
        "deadline lead is not seven days")
  , registration "config_default" "config.location_observation_ttl"
      (require (locationObservationTtl == 4 * 60 * 60)
        "location observation TTL is not four hours")
  ]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [registration "invariant" "NoSelfDependency" dependencyProbe
  , registration "invariant" "DateNoticeOccurrenceIsUniquePerRevision" dateProbe
  ]

temporalRegistrations :: [(ProbeKey, PlanProbe)]
temporalRegistrations =
  [registration "temporal" "DateNoticeSnoozeEnded" dateProbe]

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "execution" category construct, semanticProbe category construct probe)

semanticProbe :: Text -> Text -> Either Text () -> PlanProbe
semanticProbe category construct probe input = do
  require (planProbeModule input == "execution")
    "coordination probe received the wrong module"
  require (planProbeCategory input == category)
    "coordination probe received the wrong category"
  require (planProbeSourceConstruct input == construct)
    "coordination probe received the wrong source construct"
  probe

enumProbe :: [Value] -> Either Text ()
enumProbe values = do
  require (not (null values)) "closed enum has no values"
  require (Set.size (Set.fromList (map encode values)) == length values)
    "closed enum values do not encode uniquely"
  require (all canonical values) "closed enum is not canonical text"
  where
    canonical (String value) = not (Text.null value) && Text.toLower value == value
    canonical _ = False

entityProbe :: Text -> Either Text ()
entityProbe construct = do
  sample <- sampleCoordination
  value <- case construct of
    "Wait" -> Right (toJSON (sampleWait sample))
    "Dependency" -> Right (toJSON (sampleDependency sample))
    "Delegation" -> Right (toJSON (sampleDelegation sample))
    "DateNotice" -> Right (toJSON (sampleNotice sample))
    "Place" -> Right (toJSON (samplePlace sample))
    "PlaceCondition" -> Right (toJSON (samplePlaceCondition sample))
    "LocationObservation" -> Right (toJSON (sampleObservation sample))
    _ -> Left ("unknown coordination entity probe: " <> construct)
  fields <- maybe (Left "entity fixture is not an object") Right (asObject value)
  let expected = case construct of
        "Wait" -> ["id", "brick", "on_party", "condition", "status",
          "created_at", "resolved_at"]
        "Dependency" -> ["id", "blocked", "blocker", "status", "created_at",
          "resolved_at"]
        "Delegation" -> ["id", "brick", "delegate", "status", "instructions",
          "created_at", "last_contact_at", "next_followup_at", "result_note"]
        "DateNotice" -> ["id", "brick", "kind", "date_value", "date_revision",
          "status", "created_at", "snoozed_until"]
        "Place" -> ["id", "label", "created_at"]
        "PlaceCondition" -> ["id", "brick", "place", "strength", "created_at"]
        "LocationObservation" -> ["id", "place", "kind", "observed_at",
          "expires_at", "authority", "source", "external_observation_id"]
        _ -> []
  require (all (\field -> KeyMap.member (Key.fromText field) fields) expected)
    (construct <> " projection omits declared fields")

optionalProbe :: Text -> Either Text ()
optionalProbe construct = do
  sample <- sampleCoordination
  let (value, field) = case construct of
        "Wait.on_party" -> (toJSON (sampleWait sample), "on_party")
        "Wait.resolved_at" -> (toJSON (sampleWait sample), "resolved_at")
        "Dependency.resolved_at" ->
          (toJSON (sampleDependency sample), "resolved_at")
        "Delegation.last_contact_at" ->
          (toJSON (sampleDelegation sample), "last_contact_at")
        "Delegation.next_followup_at" ->
          (toJSON (sampleDelegation sample), "next_followup_at")
        "Delegation.result_note" ->
          (toJSON (sampleDelegation sample), "result_note")
        "DateNotice.snoozed_until" ->
          (toJSON (sampleNotice sample), "snoozed_until")
        "LocationObservation.external_observation_id" ->
          (toJSON (sampleObservation sample), "external_observation_id")
        _ -> (Null, "")
  fields <- maybe (Left "optional fixture is not an object") Right (asObject value)
  require (KeyMap.lookup (Key.fromText field) fields == Just Null)
    (construct <> " does not encode absence as null")

transitionProbe :: Either Text ()
transitionProbe = do
  sample <- sampleCoordination
  (_, waitResolvedState) <- coordination
    (resolveCoordinationWait (waitId (sampleWait sample)) probeTime
      (sampleState sample))
  expectCoordinationFailure
    (resolveCoordinationWait (waitId (sampleWait sample)) probeTime waitResolvedState)
    "terminal Wait transitioned twice"
  dependencyProbe
  delegationProbe
  dateProbe

waitProbe :: Either Text ()
waitProbe = do
  (party, brick, state) <- basicFixture
  (wait, first) <- coordination
    (addCoordinationWait (brickId brick) Nothing "reply received" probeTime state)
  require (waitStatus wait == WaitOpen && waitOnParty wait == Nothing)
    "Wait creation lost its declared fields"
  (resolved, second) <- coordination
    (resolveCoordinationWait (waitId wait) probeTime first)
  require (waitId resolved == waitId wait && waitResolvedAt resolved == Just probeTime)
    "Wait resolution changed identity or lost its timestamp"
  expectCoordinationFailure (cancelCoordinationWait (waitId wait) probeTime second)
    "resolved Wait was cancelled"
  (other, third) <- coordination (addCoordinationWait (brickId brick)
    (Just (partyId party)) "approval" probeTime second)
  (cancelled, _) <- coordination
    (cancelCoordinationWait (waitId other) probeTime third)
  require (waitStatus cancelled == WaitCancelled)
    "open Wait did not cancel"
  terminal <- coordination
    (dropCoordinationBrick (brickId brick) probeTime state)
  expectCoordinationFailure
    (addCoordinationWait (brickId brick) Nothing "too late" probeTime terminal)
    "terminal Brick accepted a Wait"

dependencyProbe :: Either Text ()
dependencyProbe = do
  (_, a, initial) <- basicFixture
  (b, second) <- createBrick "Blocker" standardV1 Nothing initial
  (c, third) <- createBrick "Third" standardV1 Nothing second
  (dependency, fourth) <- coordination
    (addCoordinationDependency (brickId a) (brickId b) probeTime third)
  require (dependencyStatus dependency == DependencyActive)
    "Dependency was not active at creation"
  expectCoordinationFailure
    (addCoordinationDependency (brickId a) (brickId a) probeTime fourth)
    "self-dependency was accepted"
  expectCoordinationFailure
    (addCoordinationDependency (brickId a) (brickId b) probeTime fourth)
    "duplicate active dependency was accepted"
  (_, fifth) <- coordination
    (addCoordinationDependency (brickId b) (brickId c) probeTime fourth)
  expectCoordinationFailure
    (addCoordinationDependency (brickId c) (brickId a) probeTime fifth)
    "dependency cycle was accepted"
  satisfied <- coordination
    (completeCoordinationBrick (brickId b) probeTime fifth)
  let stored = Map.lookup (dependencyId dependency)
        (coordinationStateDependencies satisfied)
  require (fmap dependencyStatus stored == Just DependencySatisfied
      && fmap dependencyResolvedAt stored == Just (Just probeTime))
    "blocker completion did not satisfy Dependency"
  (_, x, cancelInitial) <- basicFixture
  (y, cancelSecond) <- createBrick "Noncompletion blocker" standardV1 Nothing
    cancelInitial
  (cancelledDependency, cancelThird) <- coordination
    (addCoordinationDependency (brickId x) (brickId y) probeTime cancelSecond)
  cancelled <- coordination
    (dropCoordinationBrick (brickId y) probeTime cancelThird)
  require (fmap dependencyStatus (Map.lookup (dependencyId cancelledDependency)
      (coordinationStateDependencies cancelled)) == Just DependencyCancelled
      && Set.member (brickId x) (coordinationStateDependencyReviews cancelled))
    "blocker non-completion did not cancel and review Dependency"
  (_, p, explicitInitial) <- basicFixture
  (q, explicitSecond) <- createBrick "Explicit blocker" standardV1 Nothing
    explicitInitial
  (explicit, explicitThird) <- coordination
    (addCoordinationDependency (brickId p) (brickId q) probeTime explicitSecond)
  (_, explicitlyCancelled) <- coordination
    (cancelCoordinationDependency (dependencyId explicit) probeTime explicitThird)
  expectCoordinationFailure
    (cancelCoordinationDependency (dependencyId explicit) probeTime explicitlyCancelled)
    "terminal Dependency cancelled twice"

delegationProbe :: Either Text ()
delegationProbe = do
  (party, brick, initial) <- basicFixture
  let executionBefore = coordinationStateExecution initial
  (draft, first) <- coordination (draftDelegation (brickId brick) (partyId party)
    "Please handle this" Nothing probeTime initial)
  require (delegationStatus draft == AwaitingApproval
      && coordinationStateExecution first == executionBefore)
    "delegation draft changed human work or focus state"
  (notified, second) <- coordination
    (approveDelegationNotice (delegationId draft) probeTime first)
  require (delegationLastContactAt notified == Just probeTime)
    "approved notice did not retain contact time"
  (_, third) <- coordination (markDelegationInProgress (delegationId draft) second)
  (completed, fourth) <- coordination
    (completeDelegation (delegationId draft) (Just "done") third)
  require (delegationStatus completed == DelegationCompleted
      && delegationResultNote completed == Just "done")
    "in-progress Delegation did not complete"
  expectCoordinationFailure
    (abandonDelegation (delegationId draft) Nothing fourth)
    "terminal Delegation transitioned again"
  (refusedDraft, fifth) <- coordination (draftDelegation (brickId brick)
    (partyId party) "Try" Nothing probeTime fourth)
  (_, sixth) <- coordination
    (approveDelegationNotice (delegationId refusedDraft) probeTime fifth)
  (refused, seventh) <- coordination
    (refuseDelegation (delegationId refusedDraft) Nothing sixth)
  require (delegationStatus refused == DelegationRefused)
    "notified Delegation did not refuse"
  (abandonedDraft, eighth) <- coordination (draftDelegation (brickId brick)
    (partyId party) "Maybe" Nothing probeTime seventh)
  (abandoned, _) <- coordination
    (abandonDelegation (delegationId abandonedDraft) Nothing eighth)
  require (delegationStatus abandoned == DelegationAbandoned)
    "awaiting Delegation did not abandon"
  terminal <- coordination (dropCoordinationBrick (brickId brick) probeTime initial)
  expectCoordinationFailure (draftDelegation (brickId brick) (partyId party)
    "too late" Nothing probeTime terminal)
    "terminal Brick accepted delegation"

entryProbe :: Either Text ()
entryProbe = do
  (_, _, initial) <- basicFixture
  (owner, second) <- createBrick "Packing list" finiteChecklistV1 Nothing initial
  (child, third) <- createBrick "Active child" standardV1
    (Just (brickId owner)) second
  label <- domain (mkCanonicalText "Passport" (Just "Passaporte") Human)
  (entry, fourth) <- coordination (addCoordinationListEntry
    (ListEntryDraft (brickId owner) label (Just 1) (Just "valid") probeTime) third)
  (resolved, fifth) <- coordination
    (resolveCoordinationListEntry (listEntryId entry) probeTime fourth)
  require (listEntryId resolved == listEntryId entry
      && listEntryStatus resolved == EntryResolved
      && Map.member (listEntryId entry)
        (domainListEntries (Execution.executionStateDomain
          (coordinationStateExecution fifth))))
    "ListEntry resolution changed identity or erased history"
  require (Set.member (brickId owner) (coordinationStateChecklistReviews fifth))
    "empty finite checklist did not suggest outcome review"
  expectCoordinationFailure
    (resolveCoordinationListEntry (listEntryId entry) probeTime fifth)
    "resolved ListEntry resolved twice"
  expectCoordinationFailure (completeFiniteChecklist (brickId owner) probeTime fifth)
    "finite checklist with an active child completed"
  childClosed <- coordination
    (completeCoordinationBrick (brickId child) probeTime fifth)
  ownerClosed <- coordination
    (completeFiniteChecklist (brickId owner) probeTime childClosed)
  require (fmap brickStatus (Map.lookup (brickId owner)
      (domainBricks (Execution.executionStateDomain
        (coordinationStateExecution ownerClosed)))) == Just Done)
    "explicit empty finite-checklist completion failed"
  (removeOwner, sixth) <- createBrick "Removal list" finiteChecklistV1 Nothing initial
  removeLabel <- domain (mkCanonicalText "Old item" Nothing Human)
  (removeEntry, seventh) <- coordination (addCoordinationListEntry
    (ListEntryDraft (brickId removeOwner) removeLabel Nothing Nothing probeTime) sixth)
  (removed, eighth) <- coordination (removeCoordinationListEntry
    (listEntryId removeEntry) (Just "not needed") probeTime seventh)
  require (listEntryStatus removed == EntryRemoved
      && listEntryRemovalReason removed == Just "not needed"
      && Set.member (brickId removeOwner) (coordinationStateChecklistReviews eighth))
    "ListEntry removal lost history or review pressure"
  ordinaryLabel <- domain (mkCanonicalText "Unsupported" Nothing Human)
  (_, ordinary, ordinaryState) <- basicFixture
  expectCoordinationFailure (addCoordinationListEntry
    (ListEntryDraft (brickId ordinary) ordinaryLabel Nothing Nothing probeTime)
    ordinaryState) "entry-owning behavior was not enforced"

dateProbe :: Either Text ()
dateProbe = do
  (_, _, initial) <- basicFixture
  (parent, second) <- createBrick "Dated parent" projectV1 Nothing initial
  (child, third) <- createBrick "Dated child" standardV1
    (Just (brickId parent)) second
  first <- coordination (setCoordinationBestBefore (brickId parent)
    (addUTCTime (2 * 24 * 60 * 60) probeTime) third)
  secondWithDate <- coordination (setCoordinationDeadline (brickId parent)
    (addUTCTime (3 * 24 * 60 * 60) probeTime) first)
  (created, advanced) <- coordination
    (advanceCoordinationTime probeTime secondWithDate)
  let childCreated = [notice | notice <- created,
        dateNoticeBrick notice == brickId child]
      occurrenceCount = Map.size (coordinationStateDateNotices advanced)
  require (Set.fromList (map dateNoticeKind childCreated) ==
      Set.fromList [BestBeforeApproaching, DeadlineApproaching])
    "approaching date notices were not emitted"
  (_, repeated) <- coordination (advanceCoordinationTime probeTime advanced)
  require (Map.size (coordinationStateDateNotices repeated) == occurrenceCount)
    "repeated tick duplicated date notices"
  deadlineNotice <- exactlyOne [notice | notice <- childCreated,
    dateNoticeKind notice == DeadlineApproaching]
  (_, snoozed) <- coordination (snoozeDateNotice (dateNoticeId deadlineNotice)
    (addUTCTime 60 probeTime) repeated)
  (_, beforeWake) <- coordination
    (advanceCoordinationTime (addUTCTime 59 probeTime) snoozed)
  require (fmap dateNoticeStatus (Map.lookup (dateNoticeId deadlineNotice)
      (coordinationStateDateNotices beforeWake)) == Just NoticeSnoozed)
    "DateNotice woke before its snooze deadline"
  (_, atWake) <- coordination
    (advanceCoordinationTime (addUTCTime 60 probeTime) beforeWake)
  require (fmap dateNoticeStatus (Map.lookup (dateNoticeId deadlineNotice)
      (coordinationStateDateNotices atWake)) == Just NoticePending)
    "DateNotice did not wake at its snooze deadline"
  (_, acknowledged) <- coordination
    (acknowledgeDateNotice (dateNoticeId deadlineNotice) atWake)
  expectCoordinationFailure
    (snoozeDateNotice (dateNoticeId deadlineNotice) (addUTCTime 120 probeTime)
      acknowledged) "acknowledged DateNotice snoozed"
  changed <- coordination (setCoordinationDeadline (brickId parent)
    (addUTCTime (4 * 24 * 60 * 60) probeTime) acknowledged)
  require (all ((== NoticeResolved) . dateNoticeStatus)
      (Map.elems (coordinationStateDateNotices changed)))
    "ancestor date change did not resolve descendant notice history"
  (newItems, withNew) <- coordination (advanceCoordinationTime probeTime changed)
  require (any ((== DeadlineApproaching) . dateNoticeKind) newItems)
    "new effective date revision did not emit a new notice"
  terminal <- coordination
    (completeCoordinationBrick (brickId child) probeTime withNew)
  require (all ((== NoticeResolved) . dateNoticeStatus)
      [notice | notice <- Map.elems (coordinationStateDateNotices terminal),
        dateNoticeBrick notice == brickId child])
    "terminal Brick retained an active DateNotice"
  (_, _, overdueInitial) <- basicFixture
  (overdue, overdueSecond) <- createBrick "Overdue" standardV1 Nothing overdueInitial
  overdueThird <- coordination (setCoordinationBestBefore (brickId overdue)
    (addUTCTime (-1) probeTime) overdueSecond)
  overdueFourth <- coordination (setCoordinationDeadline (brickId overdue)
    (addUTCTime (-1) probeTime) overdueThird)
  (pastItems, _) <- coordination (advanceCoordinationTime probeTime overdueFourth)
  require (Set.fromList (map dateNoticeKind pastItems) ==
      Set.fromList [BestBeforePassed, DeadlineOverdue])
    "passed/overdue thresholds emitted the wrong notices"

placeProbe :: Either Text ()
placeProbe = do
  (_, hardBrick, initial) <- basicFixture
  (softBrick, second) <- createBrick "Soft place work" standardV1 Nothing initial
  (home, third) <- coordination (createPlace "Home" probeTime second)
  (office, fourth) <- coordination (createPlace "Office" probeTime third)
  (hardCondition, fifth) <- coordination
    (addPlaceCondition (brickId hardBrick) (placeId home) PlaceHard probeTime fourth)
  (softCondition, sixth) <- coordination
    (addPlaceCondition (brickId softBrick) (placeId office) PlaceSoft probeTime fifth)
  require (placeConditionStrength hardCondition == PlaceHard
      && placeConditionStrength softCondition == PlaceSoft)
    "PlaceCondition strength was not preserved"
  hardBefore <- coordination
    (evaluatePlaceConditions probeTime (brickId hardBrick) sixth)
  softBefore <- coordination
    (evaluatePlaceConditions probeTime (brickId softBrick) sixth)
  require (not (placeEvaluationEligible hardBefore)
      && placeEvaluationEligible softBefore)
    "hard and soft PlaceCondition eligibility was conflated"
  let executionBefore = coordinationStateExecution sixth
  (observation, seventh) <- coordination (recordLocationObservation (placeId home)
    LocationEntered probeTime Nothing Human "manual" (Just "manual:1") sixth)
  require (locationObservationExpiresAt observation ==
      addUTCTime locationObservationTtl probeTime
      && coordinationStateExecution seventh == executionBefore)
    "location observation TTL was wrong or silently executed work"
  current <- coordination
    (evaluatePlaceConditions (addUTCTime 1 probeTime) (brickId hardBrick) seventh)
  require (placeEvaluationEligible current
      && placeEvaluationMatchingHard current == [placeId home]
      && placeEvaluationProposalKinds current == ["place_batch"]
      && null (placeEvaluationExternalTrace current))
    "explicit current observation did not drive adapter-free place evaluation"
  expectCoordinationFailure (recordLocationObservation (placeId home)
    LocationPresent probeTime Nothing Adapter "manual" (Just "manual:1") seventh)
    "external location observation identity was not idempotent"
  stale <- coordination (evaluatePlaceConditions
    (addUTCTime locationObservationTtl probeTime) (brickId hardBrick) seventh)
  require (not (placeEvaluationEligible stale))
    "stale location evidence continued affecting eligibility"
  (_, eighth) <- coordination (recordLocationObservation (placeId home)
    LocationLeft (addUTCTime 2 probeTime) Nothing Human "manual" Nothing seventh)
  left <- coordination
    (evaluatePlaceConditions (addUTCTime 3 probeTime) (brickId hardBrick) eighth)
  require (not (placeEvaluationEligible left))
    "explicit left observation did not replace presence"
  expectCoordinationFailure (addPlaceCondition (brickId hardBrick) (placeId home)
    PlaceHard probeTime eighth) "duplicate PlaceCondition was accepted"

------------------------------------------------------------
-- Probe fixtures
------------------------------------------------------------

data Sample = Sample
  { sampleWait :: Wait
  , sampleDependency :: Dependency
  , sampleDelegation :: Delegation
  , sampleNotice :: DateNotice
  , samplePlace :: Place
  , samplePlaceCondition :: PlaceCondition
  , sampleObservation :: LocationObservation
  , sampleState :: CoordinationState
  }
  deriving stock (Eq, Show)

sampleCoordination :: Either Text Sample
sampleCoordination = do
  (party, brick, initial) <- basicFixture
  (blocker, second) <- createBrick "Sample blocker" standardV1 Nothing initial
  (wait, third) <- coordination
    (addCoordinationWait (brickId brick) Nothing "sample" probeTime second)
  (dependency, fourth) <- coordination
    (addCoordinationDependency (brickId brick) (brickId blocker) probeTime third)
  (delegation, fifth) <- coordination (draftDelegation (brickId brick)
    (partyId party) "sample" Nothing probeTime fourth)
  sixth <- coordination (setCoordinationDeadline (brickId brick)
    (addUTCTime (24 * 60 * 60) probeTime) fifth)
  (notices, seventh) <- coordination (advanceCoordinationTime probeTime sixth)
  notice <- exactlyOne notices
  (place, eighth) <- coordination (createPlace "Sample" probeTime seventh)
  (condition, ninth) <- coordination
    (addPlaceCondition (brickId brick) (placeId place) PlaceHard probeTime eighth)
  (observation, final) <- coordination (recordLocationObservation (placeId place)
    LocationPresent probeTime Nothing Human "manual" Nothing ninth)
  pure Sample
    { sampleWait = wait
    , sampleDependency = dependency
    , sampleDelegation = delegation
    , sampleNotice = notice
    , samplePlace = place
    , samplePlaceCondition = condition
    , sampleObservation = observation
    , sampleState = final
    }

basicFixture :: Either Text (Party, Brick, CoordinationState)
basicFixture = do
  (party, first) <- coordination
    (createCoordinationParty "Contract user" Person probeTime emptyCoordinationState)
  (brick, second) <- createBrick "Ordinary work" standardV1 Nothing first
  pure (party, brick, second)

createBrick ::
  Text -> BrickBehavior -> Maybe BrickId -> CoordinationState ->
  Either Text (Brick, CoordinationState)
createBrick title behavior parent state = do
  canonical <- domain (mkCanonicalText title Nothing Human)
  (brick, _, next) <- coordination (createCoordinationBrick
    ((ordinaryBrickDraft canonical behavior probeTime) {brickDraftParent = parent})
    ("probe:" <> title) probeTime state)
  pure (brick, next)

asObject :: Value -> Maybe (KeyMap.KeyMap Value)
asObject (Object fields) = Just fields
asObject _ = Nothing

exactlyOne :: [value] -> Either Text value
exactlyOne values = case values of
  [value] -> Right value
  _ -> Left "expected exactly one probe value"

expectCoordinationFailure :: Either CoordinationError value -> Text -> Either Text ()
expectCoordinationFailure result problem = case result of
  Left _ -> Right ()
  Right _ -> Left problem

coordination :: Either CoordinationError value -> Either Text value
coordination = either (Left . Text.pack . show) Right

domain :: Either DomainError value -> Either Text value
domain = either (Left . Text.pack . show) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 0

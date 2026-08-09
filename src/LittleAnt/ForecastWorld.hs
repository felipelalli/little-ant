module LittleAnt.ForecastWorld (
  DependencyEndpoint (..),
  ForecastSelection (..),
  ForecastSubjectKind (..),
  NonBrickEndpoint (..),
  SelectableOpportunity (..),
  SelectableOpportunityKind (..),
  SubjectTicket (..),
  buildForecastWorld,
  opportunityKindName,
  selectForecast,
)
where

import Data.ByteString (ByteString)
import Data.List (maximumBy, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, fromMaybe, mapMaybe)
import Data.Ord (comparing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime, diffUTCTime)
import LittleAnt.Forecast
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Judgment
import LittleAnt.Model

data SelectableOpportunityKind
  = FiniteWorkOpportunity
  | RepeatableRunOpportunity
  | HabitWindowOpportunity
  | LivingChecklistRunOpportunity
  | FiniteChecklistRunOpportunity
  | RawTriageOpportunity
  | NatureReviewOpportunity
  | PhaseReviewOpportunity
  | EffortComparisonOpportunity
  | ImpactComparisonOpportunity
  | ImpactMaturityReviewOpportunity
  | ImportanceRunReviewOpportunity
  | ImportanceValidationOpportunity
  | ImportanceRecalibrationOpportunity
  | WipReviewOpportunity
  | ScopeClosureReviewOpportunity
  | ArchiveRelevanceReviewOpportunity
  | RepeatableReturnReviewOpportunity
  | WaitReviewOpportunity
  | WaitResolutionReviewOpportunity
  | HabitIntrospectionReviewOpportunity
  | DelegationReviewOpportunity
  | DelegationCompletionReviewOpportunity
  | DelegationRefusalReviewOpportunity
  | ExternalEffectApprovalOpportunity
  | ExternalEffectRecoveryOpportunity
  | SourceChangeReconciliationOpportunity
  | SourceFailureReviewOpportunity
  | RawDuplicateReviewOpportunity
  | BrickDuplicateReviewOpportunity
  | ListEntryDuplicateReviewOpportunity
  | DomainMembershipReviewOpportunity
  | SkipTaxonomyReviewOpportunity
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data SelectableOpportunity = SelectableOpportunity
  { selectableIdentity :: Text
  , selectableKind :: SelectableOpportunityKind
  , selectableSignals :: [ForecastSignal]
  }
  deriving stock (Eq, Show)

data ForecastSubjectKind = BrickSubject | RawSubject
  deriving stock (Eq, Ord, Show)

data NonBrickEndpoint
  = ExternalWaitEndpoint Text
  | TemporalGateEndpoint Text
  | RequiredPlaceEndpoint Text
  | MissingPermissionEndpoint Text
  | CorruptDependencyEndpoint Text
  deriving stock (Eq, Ord, Show)

data DependencyEndpoint
  = DependencyBrick UUIDv7
  | DependencyNonBrick NonBrickEndpoint
  deriving stock (Eq, Ord, Show)

data SubjectTicket = SubjectTicket
  { ticketIdentity :: UUIDv7
  , ticketKind :: ForecastSubjectKind
  , ticketParent :: Maybe UUIDv7
  , ticketSiblingPosition :: Maybe (Int, Int)
  , ticketImportanceConfidence :: Fixed
  , ticketNegativeSignals :: [ForecastSignal]
  , ticketDomainPaths :: [[UUIDv7]]
  , ticketChildren :: [UUIDv7]
  , ticketDependencies :: [DependencyEndpoint]
  , ticketOpportunities :: [SelectableOpportunity]
  }
  deriving stock (Eq, Show)

data ForecastSelection
  = SelectedOpportunity
      { selectedOriginalSubject :: UUIDv7
      , selectedEndpointSubject :: UUIDv7
      , selectedOpportunity :: SelectableOpportunity
      , selectedDependencyPath :: [UUIDv7]
      , selectedEffectiveDomain :: Maybe [UUIDv7]
      , selectedDraws :: [DrawRecord Text]
      , selectedEndingCursors :: Map RandomPurpose Integer
      }
  | SelectedRecovery
      { selectedOriginalSubject :: UUIDv7
      , selectedRecoveryEndpoint :: NonBrickEndpoint
      , selectedDependencyPath :: [UUIDv7]
      , selectedDraws :: [DrawRecord Text]
      , selectedEndingCursors :: Map RandomPurpose Integer
      }
  | EmptyForecast Text
  deriving stock (Eq, Show)

buildForecastWorld :: State -> UTCTime -> [SubjectTicket]
buildForecastWorld state now =
  fmap brickTicket active <> fmap archivedReviewTicket reviewableArchived <> fmap rawTicket eligibleRaws
 where
  active = sortOn brickId (filter (\brick -> not (coolingDown brick) && temporalGateOpen state now brick) (activeBricks state))
  eligibleRaws = sortOn rawId (inboxRaws state)
  reviewableArchived =
    sortOn (brickId . fst) $
      mapMaybe
        ( \brick ->
            let claims =
                  [ claim
                  | claim <- Map.elems (stateLazyReviews state)
                  , lazyReviewSubject claim == brickId brick
                  , lazyReviewKind claim == "archive_relevance_review"
                  ]
             in if brickStatus brick == BrickArchived && not (null claims)
                  then Just (brick, claims)
                  else Nothing
        )
        (Map.elems (stateBricks state))
  activeByParent =
    Map.fromListWith
      (<>)
      [(brickParent brick, [brick]) | brick <- active]
  allByParent =
    Map.fromListWith
      (<>)
      [(brickParent brick, [brick]) | brick <- Map.elems (stateBricks state)]
  brickTicket brick =
    let siblings = sortOn brickSiblingPosition (Map.findWithDefault [] (brickParent brick) activeByParent)
        position = fromMaybe 0 (lookupIndex (brickId brick) (fmap brickId siblings))
        children = sortOn brickSiblingPosition (Map.findWithDefault [] (Just (brickId brick)) activeByParent)
        allChildren = Map.findWithDefault [] (Just (brickId brick)) allByParent
     in SubjectTicket
          { ticketIdentity = brickId brick
          , ticketKind = BrickSubject
          , ticketParent = brickParent brick
          , ticketSiblingPosition = Just (position, length siblings)
          , ticketImportanceConfidence = localConfidence state now brick siblings
          , ticketNegativeSignals = deferralSignals brick
          , ticketDomainPaths = fmap (domainPath state) (Set.toAscList (brickDomains brick))
          , ticketChildren = fmap brickId children
          , ticketDependencies =
              [ DependencyBrick (dependencyBlockerBrick dependency)
              | dependency <- Map.elems (stateDependencies state)
              , dependencyStatus dependency == DependencyActive
              , dependencyBlockedBrick dependency == brickId brick
              ]
          , ticketOpportunities = brickOpportunities state now brick children allChildren
          }
  rawTicket raw =
    SubjectTicket
      { ticketIdentity = rawId raw
      , ticketKind = RawSubject
      , ticketParent = Nothing
      , ticketSiblingPosition = Nothing
      , ticketImportanceConfidence = Fixed 0
      , ticketNegativeSignals = []
      , ticketDomainPaths = []
      , ticketChildren = []
      , ticketDependencies = []
      , ticketOpportunities =
          [ SelectableOpportunity
              (renderUUIDv7 (rawId raw) <> ":raw-triage")
              RawTriageOpportunity
              [ForecastSignal AvailabilitySignal (Fixed 150_000) "new Inbox Raw triage"]
          ]
      }
  archivedReviewTicket (brick, claims) =
    SubjectTicket
      { ticketIdentity = brickId brick
      , ticketKind = BrickSubject
      , ticketParent = Nothing
      , ticketSiblingPosition = Nothing
      , ticketImportanceConfidence = Fixed 0
      , ticketNegativeSignals = []
      , ticketDomainPaths = fmap (domainPath state) (Set.toAscList (brickDomains brick))
      , ticketChildren = []
      , ticketDependencies = []
      , ticketOpportunities =
          [ SelectableOpportunity
              (renderUUIDv7 (brickId brick) <> ":archive-relevance:" <> renderUUIDv7 (lazyReviewId claim))
              ArchiveRelevanceReviewOpportunity
              [ ForecastSignal
                  ReviewConsequenceSignal
                  (Fixed 100_000)
                  "archived Work relevance review"
              ]
          | claim <- claims
          ]
      }
  coolingDown brick =
    any
      (\deferral -> workDeferralBrick deferral == brickId brick && maybe False (> now) (workDeferralCooldownUntil deferral))
      (Map.elems (stateWorkDeferrals state))
  deferralSignals brick =
    case length [() | deferral <- Map.elems (stateWorkDeferrals state), workDeferralBrick deferral == brickId brick] of
      0 -> []
      count ->
        [ ForecastSignal
            AvoidanceSignal
            (Fixed (min 800_000 (fromIntegral count * 100_000)))
            "recent served-work deferrals"
        ]

selectForecast ::
  ByteString ->
  Map RandomPurpose Integer ->
  Maybe [UUIDv7] ->
  Maybe UUIDv7 ->
  [SubjectTicket] ->
  Either Text ForecastSelection
selectForecast seed cursors activeDomain hardScope tickets
  | null admittedRoots =
      Right (EmptyForecast (if hardScope == Nothing then "No opportunity is currently eligible." else "No actionable endpoint exists in this Domain scope."))
  | otherwise = do
      (root, rootDraw, cursorsAfterRoot) <- drawTickets ForecastSubjectDraw admittedRoots cursors
      descend (ticketIdentity root) (ticketIdentity root) [] [eraseDraw rootDraw] cursorsAfterRoot
 where
  table = Map.fromList [(ticketIdentity ticket, ticket) | ticket <- tickets]
  roots = filter ((== Nothing) . ticketParent) tickets
  admittedRoots =
    filter
      (\ticket -> reachable table Set.empty (ticketIdentity ticket) && maybe True (containsDomain table (ticketIdentity ticket)) hardScope)
      roots

  descend original current path draws currentCursors = do
    ticket <- maybe (Left "The selected subject disappeared from the forecast world.") Right (Map.lookup current table)
    case ticketDependencies ticket of
      dependencies@(_ : _) -> do
        let brickTargets = mapMaybe dependencyTicket dependencies
            nonBrickTargets = [endpoint | DependencyNonBrick endpoint <- dependencies]
        if null brickTargets
          then case nonBrickTargets of
            endpoint : _ ->
              Right
                SelectedRecovery
                  { selectedOriginalSubject = original
                  , selectedRecoveryEndpoint = endpoint
                  , selectedDependencyPath = path <> [current]
                  , selectedDraws = draws
                  , selectedEndingCursors = currentCursors
                  }
            [] -> Left "Every Dependency endpoint is corrupt."
          else do
            (nextTicket, dependencyDraw, nextCursors) <- drawTickets ForecastDependencyDraw brickTargets currentCursors
            descend original (ticketIdentity nextTicket) (path <> [current]) (draws <> [eraseDraw dependencyDraw]) nextCursors
      [] ->
        case filter (reachable table Set.empty) (ticketChildren ticket) of
          children@(_ : _) -> do
            childTickets <- traverse lookupTicket children
            (child, childDraw, nextCursors) <- drawTickets ForecastChildDraw childTickets currentCursors
            descend original (ticketIdentity child) path (draws <> [eraseDraw childDraw]) nextCursors
          [] ->
            case ticketOpportunities ticket of
              [] -> Left "An admitted semantic leaf has no selectable opportunity."
              opportunities -> do
                (opportunity, opportunityDraw, nextCursors) <- drawOpportunities opportunities currentCursors
                (effectiveDomain, domainDraws, finalCursors) <- chooseEffectiveDomain ticket nextCursors
                Right
                  SelectedOpportunity
                    { selectedOriginalSubject = original
                    , selectedEndpointSubject = current
                    , selectedOpportunity = opportunity
                    , selectedDependencyPath = path <> [current]
                    , selectedEffectiveDomain = effectiveDomain
                    , selectedDraws = draws <> [eraseDraw opportunityDraw] <> domainDraws
                    , selectedEndingCursors = finalCursors
                    }

  lookupTicket identity = maybe (Left "A structural child is missing from the forecast world.") Right (Map.lookup identity table)
  dependencyTicket = \case
    DependencyBrick identity -> Map.lookup identity table
    DependencyNonBrick{} -> Nothing

  drawTickets purpose candidates currentCursors = do
    let weighted = fmap (forecastWeight factoryForecastProfile . ticketCandidate table activeDomain) candidates
    record <- sampleRecorded factoryForecastProfile seed (cursorFor purpose currentCursors) purpose weighted
    chosen <- maybe (Left "The chosen ticket is missing.") Right (Map.lookup (drawChosenSubject record) table)
    pure (chosen, record, advance purpose record currentCursors)

  drawOpportunities opportunities currentCursors = do
    let candidates =
          [ ForecastCandidate
              (selectableIdentity opportunity)
              (selectableIdentity opportunity)
              ForecastFactors
                { factorSiblingPosition = Nothing
                , factorImportanceConfidence = Fixed 0
                , factorPositiveSignals = selectableSignals opportunity
                , factorDomainAffinity = Fixed 0
                , factorFamilyAffinity = Fixed 0
                , factorNegativeSignals = []
                }
          | opportunity <- opportunities
          ]
        weighted = fmap (forecastWeight factoryForecastProfile) candidates
    record <- sampleRecorded factoryForecastProfile seed (cursorFor ForecastOpportunityDraw currentCursors) ForecastOpportunityDraw weighted
    opportunity <-
      maybe
        (Left "The chosen local opportunity is missing.")
        Right
        (findOpportunity (drawChosenIdentity record) opportunities)
    pure (opportunity, record, advance ForecastOpportunityDraw record currentCursors)

  chooseEffectiveDomain ticket currentCursors =
    case strongestPaths of
      [] -> Right (Nothing, [], currentCursors)
      [path] -> Right (Just path, [], currentCursors)
      paths -> do
        let candidates =
              [ forecastWeight
                  factoryForecastProfile
                  ( ForecastCandidate
                      (pathIdentity path)
                      path
                      ForecastFactors
                        { factorSiblingPosition = Nothing
                        , factorImportanceConfidence = Fixed 0
                        , factorPositiveSignals = []
                        , factorDomainAffinity = Fixed 0
                        , factorFamilyAffinity = Fixed 0
                        , factorNegativeSignals = []
                        }
                  )
              | path <- paths
              ]
        record <- sampleRecorded factoryForecastProfile seed (cursorFor ForecastDomainPathDraw currentCursors) ForecastDomainPathDraw candidates
        pure
          ( Just (drawChosenSubject record)
          , [eraseDraw record]
          , advance ForecastDomainPathDraw record currentCursors
          )
   where
    paths = ticketDomainPaths ticket
    best = maximum (Fixed 0 : fmap (domainAffinity activeDomain . pure) paths)
    strongestPaths = [path | path <- paths, domainAffinity activeDomain [path] == best]
    pathIdentity = Text.intercalate " › " . fmap renderUUIDv7

  cursorFor purpose = Map.findWithDefault 0 purpose
  advance purpose record = Map.insert purpose (drawEndingCursor record)

eraseDraw :: DrawRecord subject -> DrawRecord Text
eraseDraw record =
  record
    { drawCandidates =
        [ candidate
            { drawCandidateSubject = drawCandidateIdentity candidate
            }
        | candidate <- drawCandidates record
        ]
    , drawChosenSubject = drawChosenIdentity record
    }

ticketCandidate :: Map UUIDv7 SubjectTicket -> Maybe [UUIDv7] -> SubjectTicket -> ForecastCandidate UUIDv7
ticketCandidate table activeDomain ticket =
  ForecastCandidate
    (renderUUIDv7 (ticketIdentity ticket))
    (ticketIdentity ticket)
    ForecastFactors
      { factorSiblingPosition = ticketSiblingPosition ticket
      , factorImportanceConfidence = ticketImportanceConfidence ticket
      , factorPositiveSignals = strongestOpportunitySignals table (ticketIdentity ticket)
      , factorDomainAffinity = domainAffinity activeDomain (ticketDomainPaths ticket)
      , factorFamilyAffinity = Fixed 0
      , factorNegativeSignals = ticketNegativeSignals ticket
      }

strongestOpportunitySignals :: Map UUIDv7 SubjectTicket -> UUIDv7 -> [ForecastSignal]
strongestOpportunitySignals table root =
  case candidates of
    [] -> []
    _ -> snd (maximumBy (comparing (\(pressure, signals) -> (pressure, fmap signalExplanation signals))) candidates)
 where
  candidates =
    [ (pressure, selectableSignals opportunity)
    | identity <- descendants table Set.empty root
    , Just ticket <- [Map.lookup identity table]
    , opportunity <- ticketOpportunities ticket
    , let (pressure, _, _) = positivePressure factoryForecastProfile (selectableSignals opportunity)
    ]

reachable :: Map UUIDv7 SubjectTicket -> Set.Set UUIDv7 -> UUIDv7 -> Bool
reachable table seen identity
  | identity `Set.member` seen = False
  | otherwise =
      case Map.lookup identity table of
        Nothing -> False
        Just ticket ->
          not (null (ticketOpportunities ticket))
            || any (reachable table (Set.insert identity seen)) (ticketChildren ticket)
            || any dependencyReachable (ticketDependencies ticket)
 where
  dependencyReachable = \case
    DependencyBrick target -> reachable table (Set.insert identity seen) target
    DependencyNonBrick{} -> True

descendants :: Map UUIDv7 SubjectTicket -> Set.Set UUIDv7 -> UUIDv7 -> [UUIDv7]
descendants table seen identity
  | identity `Set.member` seen = []
  | otherwise =
      identity
        : case Map.lookup identity table of
          Nothing -> []
          Just ticket -> concatMap (descendants table (Set.insert identity seen)) (ticketChildren ticket)

containsDomain :: Map UUIDv7 SubjectTicket -> UUIDv7 -> UUIDv7 -> Bool
containsDomain table root domain =
  any
    (\identity -> maybe False (any (domain `elem`) . ticketDomainPaths) (Map.lookup identity table))
    (descendants table Set.empty root)

domainAffinity :: Maybe [UUIDv7] -> [[UUIDv7]] -> Fixed
domainAffinity Nothing _ = Fixed 0
domainAffinity _ [] = Fixed 0
domainAffinity (Just active) paths =
  maximum (Fixed 0 : fmap affinity paths)
 where
  affinity candidate =
    let shared = length (takeWhile id (zipWith (==) active candidate))
        denominator = max (length active) (length candidate)
     in if denominator == 0 then Fixed 0 else Fixed (fromIntegral shared * 1_000_000 `div` fromIntegral denominator)

domainPath :: State -> UUIDv7 -> [UUIDv7]
domainPath state identity =
  case Map.lookup identity (stateDomains state) of
    Nothing -> []
    Just domain -> maybe [] (domainPath state) (domainParent domain) <> [identity]

localConfidence :: State -> UTCTime -> Brick -> [Brick] -> Fixed
localConfidence state now brick siblings =
  case catMaybes [previousConfidence, nextConfidence] of
    [] -> fallback
    values -> minimum values
 where
  ordered = fmap brickId siblings
  index = fromMaybe 0 (lookupIndex (brickId brick) ordered)
  previousConfidence = if index <= 0 then Nothing else relationConfidence (ordered !! (index - 1)) (brickId brick)
  nextConfidence = if index + 1 >= length ordered then Nothing else relationConfidence (brickId brick) (ordered !! (index + 1))
  relationConfidence first second =
    directedPathConfidence <$> bestDirectedPath state now ImportanceAxis first second
  fallback = case brickImportanceConfidence brick of
    HumanComparison -> Fixed 1_000_000
    DeterministicPosition{} -> Fixed 150_000
    Provisional{} -> Fixed 150_000

delegationReviewKind :: Delegation -> SelectableOpportunityKind
delegationReviewKind delegation = case delegationLastObservation delegation of
  Just "reported_complete" -> DelegationCompletionReviewOpportunity
  Just "refused" -> DelegationRefusalReviewOpportunity
  _ -> DelegationReviewOpportunity

brickOpportunities :: State -> UTCTime -> Brick -> [Brick] -> [Brick] -> [SelectableOpportunity]
brickOpportunities state now brick children allChildren =
  execution <> waitReviews <> delegationReviews <> effectReviews <> reviews
 where
  execution
    | hasActiveWait state brick = []
    | isActivelyDelegated state brick = []
    | brickNature brick == ScheduledCommitment = []
    | brickNature brick == RecurringObligation = []
    | brickNature brick == Habit && null (openHabitWindows state now brick) = []
    | pendingRepeatableReturn state brick = []
    | not (null children) && descends (brickNature brick) = []
    | null children && not (null allChildren) && finite (brickNature brick) =
        [op ScopeClosureReviewOpportunity 200_000 "finite scope may now be complete"]
    | otherwise = [op (executionKind (brickNature brick)) 250_000 "ordinary executable Work availability"]
  reviews =
    [ op (reviewKind claim) 50_000 (lazyReviewReason claim)
    | claim <- Map.elems (stateLazyReviews state)
    , lazyReviewSubject claim == brickId brick
    ]
  waitReviews =
    [ op WaitReviewOpportunity 350_000 "Wait review is due"
    | gate <- Map.elems (stateWaits state)
    , waitAffectedBrick gate == brickId brick
    , waitStatus gate == WaitActive
    , zonedInstantUtc (waitReviewNotBefore gate) <= now
    , maybe True (<= now) (waitReviewCooldownUntil gate)
    ]
  delegationReviews =
    [ op (delegationReviewKind delegation) 350_000 "Delegation follow-up review is due"
    | delegation <- Map.elems (stateDelegations state)
    , delegationBrick delegation == brickId brick
    , delegationStatus delegation == DelegationActive
    , delegationLastObservation delegation `elem` [Just "reported_complete", Just "refused"]
        || maybe False ((<= now) . zonedInstantUtc) (delegationReviewNotBefore delegation)
    ]
  effectReviews =
    [ op kind 400_000 explanation
    | effect <- Map.elems (stateExternalEffects state)
    , Just delegationId <- [externalEffectDelegation effect]
    , Just delegation <- [Map.lookup delegationId (stateDelegations state)]
    , delegationBrick delegation == brickId brick
    , (kind, explanation) <- case externalEffectStatus effect of
        EffectProposed
          | maybe True ((<= now) . zonedInstantUtc) (externalEffectReviewNotBefore effect) ->
              [(ExternalEffectApprovalOpportunity, "External effect awaits exact approval")]
          | otherwise -> []
        EffectFailedRetryable -> [(ExternalEffectRecoveryOpportunity, "External effect failed and can be retried")]
        EffectFailedTerminal -> [(ExternalEffectRecoveryOpportunity, "External effect failed terminally")]
        EffectOutcomeUnknown -> [(ExternalEffectRecoveryOpportunity, "External effect outcome is unknown")]
        _ -> []
    ]
  op kind strength explanation =
    SelectableOpportunity
      (renderUUIDv7 (brickId brick) <> ":" <> kindName kind)
      kind
      (phaseSignal <> impactSignal <> temporalSignals state now brick <> [ForecastSignal AvailabilitySignal (Fixed strength) explanation])
  phaseSignal = case Map.lookup (brickId brick) (statePhaseClaims state) of
    Nothing -> []
    Just claim -> [ForecastSignal PhaseSignal (phaseStrength (phaseClaimValue claim)) "current phase"]
  impactSignal = case Map.lookup (brickId brick) (stateImpactClaims state) of
    Nothing -> []
    Just claim -> [ForecastSignal ImpactSignal (impactStrength (impactClaimClass claim)) "current Impact class"]

hasActiveWait :: State -> Brick -> Bool
hasActiveWait state brick =
  any
    (\gate -> waitAffectedBrick gate == brickId brick && waitStatus gate == WaitActive)
    (Map.elems (stateWaits state))

isActivelyDelegated :: State -> Brick -> Bool
isActivelyDelegated state brick = any covers (Map.elems (stateDelegations state))
 where
  covers delegation
    | delegationStatus delegation /= DelegationActive = False
    | delegationScope delegation == BrickOnlyDelegation = delegationBrick delegation == brickId brick
    | otherwise = delegationBrick delegation `elem` (brickId brick : fmap brickId (ancestors state brick))

openHabitWindows :: State -> UTCTime -> Brick -> [HabitWindow]
openHabitWindows state now brick =
  [ window
  | window <- Map.elems (stateHabitWindows state)
  , habitWindowOwner window == brickId brick
  , not (habitWindowSettled window)
  , zonedInstantUtc (habitWindowOpensAt window) <= now
  , now < zonedInstantUtc (habitWindowClosesAt window)
  ]

temporalGateOpen :: State -> UTCTime -> Brick -> Bool
temporalGateOpen state now brick =
  ordinaryGate && returnGate
 where
  ordinaryGate = maybe True ((<= now) . zonedInstantUtc) (effectiveTemporal state brick temporalNotBefore latestInstant)
  returnGate = case (brickNature brick, Map.lookup (brickId brick) (stateReturnSchedules state)) of
    (Repeatable, Just ReturnSchedule{returnSchedulePolicy = ManualOnlyReturn}) -> False
    (Repeatable, Just ReturnSchedule{returnScheduleNotBefore = Just instant}) -> zonedInstantUtc instant <= now
    _ -> True

pendingRepeatableReturn :: State -> Brick -> Bool
pendingRepeatableReturn state brick =
  any
    (\claim -> lazyReviewSubject claim == brickId brick && lazyReviewKind claim == "repeatable_return_policy")
    (Map.elems (stateLazyReviews state))

temporalSignals :: State -> UTCTime -> Brick -> [ForecastSignal]
temporalSignals state now brick =
  catMaybes
    [ dateSignal "best-before" (effectiveTemporal state brick temporalBestBefore earliestInstant)
    , dateSignal "deadline" (effectiveTemporal state brick temporalDeadline earliestInstant)
    ]
 where
  leadSeconds = 7 * 24 * 60 * 60 :: Integer
  dateSignal label = fmap $ \instant ->
    let remaining = floor (diffUTCTime (zonedInstantUtc instant) now) :: Integer
        strength
          | remaining <= 0 = 1_000_000
          | remaining >= leadSeconds = 0
          | otherwise = (leadSeconds - remaining) * 1_000_000 `div` leadSeconds
     in ForecastSignal DateSignal (Fixed strength) (label <> " window")

effectiveTemporal :: State -> Brick -> (TemporalConstraints -> Maybe ZonedInstant) -> (ZonedInstant -> ZonedInstant -> ZonedInstant) -> Maybe ZonedInstant
effectiveTemporal state brick field combine = foldl choose Nothing lineage
 where
  lineage = brick : ancestors state brick
  choose current item = case Map.lookup (brickId item) (stateTemporalConstraints state) >>= field of
    Nothing -> current
    Just candidate -> Just (maybe candidate (`combine` candidate) current)

ancestors :: State -> Brick -> [Brick]
ancestors state brick = case brickParent brick >>= (`Map.lookup` stateBricks state) of
  Nothing -> []
  Just parent -> parent : ancestors state parent

latestInstant :: ZonedInstant -> ZonedInstant -> ZonedInstant
latestInstant first second = if zonedInstantUtc first >= zonedInstantUtc second then first else second

earliestInstant :: ZonedInstant -> ZonedInstant -> ZonedInstant
earliestInstant first second = if zonedInstantUtc first <= zonedInstantUtc second then first else second

executionKind :: BrickNature -> SelectableOpportunityKind
executionKind = \case
  Repeatable -> RepeatableRunOpportunity
  Habit -> HabitWindowOpportunity
  LivingChecklist -> LivingChecklistRunOpportunity
  FiniteChecklist -> FiniteChecklistRunOpportunity
  _ -> FiniteWorkOpportunity

descends :: BrickNature -> Bool
descends = \case
  AtomicTask -> True
  Project -> True
  Collection -> True
  RecurringObligation -> True
  _ -> False

finite :: BrickNature -> Bool
finite = \case
  AtomicTask -> True
  Project -> True
  FiniteChecklist -> True
  RecurringObligation -> True
  ScheduledCommitment -> True
  _ -> False

reviewKind :: LazyReviewClaim -> SelectableOpportunityKind
reviewKind claim = case lazyReviewKind claim of
  "nature" -> NatureReviewOpportunity
  "phase" -> PhaseReviewOpportunity
  "importance" -> ImportanceRunReviewOpportunity
  "importance_run_review" -> ImportanceRunReviewOpportunity
  "archive_relevance_review" -> ArchiveRelevanceReviewOpportunity
  "repeatable_return_policy" -> RepeatableReturnReviewOpportunity
  "domain" -> DomainMembershipReviewOpportunity
  _ -> NatureReviewOpportunity

phaseStrength :: WorkPhase -> Fixed
phaseStrength = \case
  IdeaPhase -> Fixed 0
  SpecPhase -> Fixed 50_000
  ExecutionPhase -> Fixed 150_000
  ValidationPhase -> Fixed 100_000

impactStrength :: ImpactClass -> Fixed
impactStrength value = Fixed (fromIntegral (fromEnum value) * 20_000)

kindName :: SelectableOpportunityKind -> Text
kindName = Text.toLower . Text.pack . show

opportunityKindName :: SelectableOpportunityKind -> Text
opportunityKindName = \case
  FiniteWorkOpportunity -> "finite_work"
  RepeatableRunOpportunity -> "repeatable_run"
  HabitWindowOpportunity -> "habit_window"
  LivingChecklistRunOpportunity -> "living_checklist_run"
  FiniteChecklistRunOpportunity -> "finite_checklist_run"
  RawTriageOpportunity -> "raw_triage"
  NatureReviewOpportunity -> "nature_review"
  PhaseReviewOpportunity -> "phase_review"
  EffortComparisonOpportunity -> "effort_comparison"
  ImpactComparisonOpportunity -> "impact_comparison"
  ImpactMaturityReviewOpportunity -> "impact_maturity_review"
  ImportanceRunReviewOpportunity -> "importance_run_review"
  ImportanceValidationOpportunity -> "importance_validation"
  ImportanceRecalibrationOpportunity -> "importance_recalibration"
  WipReviewOpportunity -> "wip_review"
  ScopeClosureReviewOpportunity -> "scope_closure_review"
  ArchiveRelevanceReviewOpportunity -> "archive_relevance_review"
  RepeatableReturnReviewOpportunity -> "repeatable_return_policy"
  WaitReviewOpportunity -> "wait_review"
  WaitResolutionReviewOpportunity -> "wait_resolution_review"
  HabitIntrospectionReviewOpportunity -> "habit_introspection_review"
  DelegationReviewOpportunity -> "delegation_review"
  DelegationCompletionReviewOpportunity -> "delegation_completion_review"
  DelegationRefusalReviewOpportunity -> "delegation_refusal_review"
  ExternalEffectApprovalOpportunity -> "external_effect_approval"
  ExternalEffectRecoveryOpportunity -> "external_effect_recovery"
  SourceChangeReconciliationOpportunity -> "source_change_reconciliation"
  SourceFailureReviewOpportunity -> "source_failure_review"
  RawDuplicateReviewOpportunity -> "raw_duplicate_review"
  BrickDuplicateReviewOpportunity -> "brick_duplicate_review"
  ListEntryDuplicateReviewOpportunity -> "list_entry_duplicate_review"
  DomainMembershipReviewOpportunity -> "domain_membership_review"
  SkipTaxonomyReviewOpportunity -> "skip_taxonomy_review"

lookupIndex :: (Eq value) => value -> [value] -> Maybe Int
lookupIndex needle = go 0
 where
  go _ [] = Nothing
  go index (value : rest)
    | needle == value = Just index
    | otherwise = go (index + 1) rest

findOpportunity :: Text -> [SelectableOpportunity] -> Maybe SelectableOpportunity
findOpportunity identity = go
 where
  go [] = Nothing
  go (opportunity : rest)
    | selectableIdentity opportunity == identity = Just opportunity
    | otherwise = go rest

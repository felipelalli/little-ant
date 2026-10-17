module LittleAnt.ForecastWorld (
  DependencyEndpoint (..),
  ForecastSelection (..),
  ForecastSubjectKind (..),
  NonBrickEndpoint (..),
  SelectableOpportunity (..),
  SelectableOpportunityKind (..),
  SubjectTicket (..),
  buildForecastWorld,
  escalatedOccurrences,
  domainAffinity,
  forecastSubjectChances,
  forecastOpportunityChances,
  forecastTicketWeight,
  opportunityKindName,
  selectForecast,
)
where

import Data.Bifunctor qualified
import Data.ByteString (ByteString)
import Data.List (maximumBy, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, fromMaybe, mapMaybe)
import Data.Maybe qualified
import Data.Ord (comparing)
import Data.Ratio ((%))
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime, addUTCTime, diffUTCTime)
import LittleAnt.Forecast
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Judgment
import LittleAnt.JudgmentReview
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

data ForecastSubjectKind = BrickSubject | RawSubject | ExternalEffectSubject
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
  , ticketDeadlineApproach :: Fixed
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
buildForecastWorld state now = filter (reachable table Set.empty . ticketIdentity) tickets
 where
  tickets = fmap brickTicket active <> fmap archivedReviewTicket reviewableArchived <> fmap rawTicket eligibleRaws <> fmap sourceEffectTicket reviewableSourceEffects
  table = Map.fromList [(ticketIdentity ticket, ticket) | ticket <- tickets]
  active = sortOn brickId (activeBricks state)
  eligibleRaws = sortOn rawId (inboxRaws state)
  reviewableSourceEffects =
    sortOn
      externalEffectId
      [ effect
      | effect <- Map.elems (stateExternalEffects state)
      , sourceCleanupNeedsReview effect
      ]
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
  importanceReviews = importanceRunReviews state now
  activeByParent =
    Map.fromListWith
      (<>)
      [(brickParent brick, [brick]) | brick <- active]
  allByParent =
    Map.fromListWith
      (<>)
      [(brickParent brick, [brick]) | brick <- Map.elems (stateBricks state)]
  brickTicket brick =
    let siblings = sortOn brickSiblingPosition (filter (carriesImportance state) (Map.findWithDefault [] (brickParent brick) activeByParent))
        position = fromMaybe 0 (lookupIndex (brickId brick) (fmap brickId siblings))
        children = sortOn brickSiblingPosition (Map.findWithDefault [] (Just (brickId brick)) activeByParent)
        allChildren = Map.findWithDefault [] (Just (brickId brick)) allByParent
        opportunities = brickOpportunities state now brick children allChildren
     in SubjectTicket
          { ticketIdentity = brickId brick
          , ticketKind = BrickSubject
          , ticketParent = brickParent brick
          , -- IMP-057: obligation series and occurrences hold no position.
            ticketSiblingPosition = if carriesImportance state brick then Just (position, length siblings) else Nothing
          , ticketImportanceConfidence = if carriesImportance state brick then localConfidence state now brick siblings else Fixed 0
          , ticketNegativeSignals = deferralSignals brick
          , ticketDomainPaths = fmap (domainPath state) (Set.toAscList (brickDomains brick))
          , ticketChildren = fmap brickId children
          , ticketDependencies =
              [ DependencyBrick (dependencyBlockerBrick dependency)
              | dependency <- Map.elems (stateDependencies state)
              , dependencyIsBlocking state dependency
              , dependencyBlockedBrick dependency == brickId brick
              ]
          , ticketOpportunities = opportunities <> Map.findWithDefault [] (brickId brick) importanceReviews <> demandReviews brick
          , ticketDeadlineApproach =
              if any (isExecutionKind . selectableKind) opportunities
                then
                  deadlineApproach
                    deadlineLeadSeconds
                    now
                    (zonedInstantUtc <$> effectiveTemporal state brick temporalBestBefore earliestInstant)
                    (zonedInstantUtc <$> effectiveTemporal state brick temporalDeadline earliestInstant)
                else Fixed 0
          }
  demandReviews brick =
    [ SelectableOpportunity
        (reviewKindText (judgmentReviewKind review) <> ":" <> renderUUIDv7 (brickId brick))
        (case judgmentReviewKind review of EffortDiscovery -> EffortComparisonOpportunity; ImpactDiscovery -> ImpactComparisonOpportunity; ImpactEvidenceReview -> ImpactMaturityReviewOpportunity)
        ( [ ForecastSignal AvailabilitySignal (Fixed 50_000) ("Review requested: " <> judgmentReviewReason review)
          , ForecastSignal AgeSignal (Fixed (min 500_000 (max 0 (floor (diffUTCTime now (judgmentReviewCreatedAt review) * 500_000 / (30 * 86400)))))) "age of this unresolved judgment request"
          ]
            <> [ForecastSignal UncertaintySignal (Fixed 500_000) "previous judgment needs review after a material change" | judgmentReviewClassDue review]
            <> [ForecastSignal AvoidanceSignal (Fixed (500_000 - 500_000 `div` (2 ^ min 20 (judgmentReviewDeferrals review)))) "judgment review deferred" | judgmentReviewDeferrals review > 0]
        )
    | review <- pendingJudgmentReviews state
    , judgmentReviewSubject review == brickId brick
    , reviewEligible state now review
    ]
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
      , ticketDeadlineApproach = Fixed 0
      }
  sourceEffectTicket effect =
    SubjectTicket
      { ticketIdentity = externalEffectId effect
      , ticketKind = ExternalEffectSubject
      , ticketParent = Nothing
      , ticketSiblingPosition = Nothing
      , ticketImportanceConfidence = Fixed 0
      , ticketNegativeSignals = []
      , ticketDomainPaths = []
      , ticketChildren = []
      , ticketDependencies = []
      , ticketOpportunities =
          [ SelectableOpportunity
              (renderUUIDv7 (externalEffectId effect) <> ":" <> kindName kind)
              kind
              [ForecastSignal ReviewConsequenceSignal strength explanation]
          ]
      , ticketDeadlineApproach = Fixed 0
      }
   where
    (kind, strength, explanation) = case externalEffectStatus effect of
      EffectProposed -> (ExternalEffectApprovalOpportunity, Fixed 400_000, "Source cleanup awaits exact approval")
      EffectApproved -> (ExternalEffectRecoveryOpportunity, Fixed 700_000, "Approved source cleanup is pending dispatch")
      EffectDispatching -> (ExternalEffectRecoveryOpportunity, Fixed 900_000, "Source cleanup dispatch was interrupted")
      EffectFailedRetryable -> (ExternalEffectRecoveryOpportunity, Fixed 650_000, "Source cleanup can be retried safely")
      EffectFailedTerminal -> (ExternalEffectRecoveryOpportunity, Fixed 250_000, "Source cleanup failed terminally")
      EffectOutcomeUnknown -> (ExternalEffectRecoveryOpportunity, Fixed 850_000, "Source cleanup outcome needs verification")
      _ -> (ExternalEffectRecoveryOpportunity, Fixed 0, "Source cleanup is not actionable")
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
      , ticketDeadlineApproach = Fixed 0
      }
  sourceCleanupNeedsReview effect = case externalEffectRequest effect of
    SourceCleanupItemRequest _ target ->
      profileActive target
        && reviewableStatus effect
    SourceCleanupContainerRequest{} -> reviewableStatus effect
    _ -> False
  reviewableStatus effect = case externalEffectStatus effect of
    EffectProposed -> maybe True ((<= now) . zonedInstantUtc) (externalEffectReviewNotBefore effect)
    status -> status `elem` [EffectApproved, EffectDispatching, EffectFailedRetryable, EffectFailedTerminal, EffectOutcomeUnknown]
  profileActive target =
    case Map.lookup (cleanupItemImportInvocation target) (stateImportInvocations state) >>= (\invocation -> Map.lookup (importInvocationProfileId invocation) (stateImportProfiles state)) of
      Just profile -> importProfileLifecycle profile == ImportProfileActive
      Nothing -> False
  deferralSignals brick =
    case length [() | deferral <- Map.elems (stateWorkDeferrals state), workDeferralBrick deferral == brickId brick] of
      0 -> []
      count ->
        [ ForecastSignal
            AvoidanceSignal
            (Fixed (min 800_000 (fromIntegral count * 100_000)))
            "recent served-work deferrals"
        ]

{- | FOC-071: escalated occurrences that the draw could serve now, earliest
deadline first, then earliest nominal anchor, then identity. A skip pause is
an ordinary cooldown, so a paused occurrence is not listed.
-}
escalatedOccurrences :: State -> UTCTime -> [(Brick, RecurringOccurrence)]
escalatedOccurrences state now =
  sortOn
    ( \(brick, occurrence) ->
        ( Data.Maybe.isNothing (deadlineOf brick)
        , deadlineOf brick
        , zonedInstantUtc (recurringOccurrenceNominalAnchor occurrence)
        , brickId brick
        )
    )
    [ (brick, occurrence)
    | occurrence <- Map.elems (stateRecurringOccurrences state)
    , Just brick <- [Map.lookup (recurringOccurrenceBrick occurrence) (stateBricks state)]
    , Just escalation <- [obligationEscalatesAt state brick]
    , escalation <= now
    , Just ticket <- [Map.lookup (brickId brick) tickets]
    , null (ticketDependencies ticket)
    , any ((== FiniteWorkOpportunity) . selectableKind) (ticketOpportunities ticket)
    ]
 where
  tickets = Map.fromList [(ticketIdentity ticket, ticket) | ticket <- buildForecastWorld state now]
  deadlineOf brick = zonedInstantUtc <$> (Map.lookup (brickId brick) (stateTemporalConstraints state) >>= temporalDeadline)

selectForecast ::
  ByteString ->
  Map RandomPurpose Integer ->
  Maybe [UUIDv7] ->
  Maybe UUIDv7 ->
  [SubjectTicket] ->
  Either Text ForecastSelection
selectForecast seed cursors activeDomain hardScope tickets
  | null admittedRoots =
      Right (EmptyForecast (if Data.Maybe.isNothing hardScope then "No opportunity is currently eligible." else "No actionable endpoint exists in this Domain scope."))
  | otherwise = do
      (root, rootDraw, cursorsAfterRoot) <- drawTickets ForecastSubjectDraw admittedRoots cursors
      descend Set.empty (ticketIdentity root) (ticketIdentity root) [] [eraseDraw rootDraw] cursorsAfterRoot
 where
  table = Map.fromList [(ticketIdentity ticket, ticket) | ticket <- tickets]
  roots = filter ((== Nothing) . ticketParent) tickets
  admittedRoots =
    filter
      (\ticket -> reachable table Set.empty (ticketIdentity ticket) && maybe True (containsDomain table (ticketIdentity ticket)) hardScope)
      roots

  descend seen original current path draws currentCursors = do
    ticket <- lookupTicket current
    let routes = localRoutes table seen ticket
    case routes of
      [] -> Left "An admitted semantic subject has no selectable route."
      [(_, Nothing, _)] -> continue (Set.insert current seen) ticket original path draws currentCursors
      _ -> do
        (opportunity, opportunityDraw, nextCursors) <- drawRoutes routes currentCursors
        let nextDraws = draws <> [eraseDraw opportunityDraw]
        case opportunity of
          Nothing -> continue (Set.insert current seen) ticket original path nextDraws nextCursors
          Just selected -> do
            (effectiveDomain, domainDraws, finalCursors) <- chooseEffectiveDomain ticket nextCursors
            Right
              SelectedOpportunity
                { selectedOriginalSubject = original
                , selectedEndpointSubject = current
                , selectedOpportunity = selected
                , selectedDependencyPath = path <> [current]
                , selectedEffectiveDomain = effectiveDomain
                , selectedDraws = nextDraws <> domainDraws
                , selectedEndingCursors = finalCursors
                }

  continue seen ticket original path draws currentCursors =
    case ticketDependencies ticket of
      dependencies@(_ : _) -> do
        let brickTargets = filter (reachable table seen . ticketIdentity) (mapMaybe dependencyTicket dependencies)
            nonBrickTargets = [endpoint | DependencyNonBrick endpoint <- dependencies]
        if null brickTargets
          then case nonBrickTargets of
            endpoint : _ ->
              Right
                SelectedRecovery
                  { selectedOriginalSubject = original
                  , selectedRecoveryEndpoint = endpoint
                  , selectedDependencyPath = path <> [ticketIdentity ticket]
                  , selectedDraws = draws
                  , selectedEndingCursors = currentCursors
                  }
            [] -> Left "Every Dependency endpoint is corrupt."
          else do
            (nextTicket, dependencyDraw, nextCursors) <- drawTickets ForecastDependencyDraw brickTargets currentCursors
            descend seen original (ticketIdentity nextTicket) (path <> [ticketIdentity ticket]) (draws <> [eraseDraw dependencyDraw]) nextCursors
      [] -> do
        childTickets <- traverse lookupTicket (filter (reachable table seen) (ticketChildren ticket))
        (child, childDraw, nextCursors) <- drawTickets ForecastChildDraw childTickets currentCursors
        descend seen original (ticketIdentity child) path (draws <> [eraseDraw childDraw]) nextCursors

  lookupTicket identity = maybe (Left "A structural child is missing from the forecast world.") Right (Map.lookup identity table)
  dependencyTicket = \case
    DependencyBrick identity -> Map.lookup identity table
    DependencyNonBrick{} -> Nothing

  drawTickets purpose candidates currentCursors = do
    let weighted = fmap (forecastWeight factoryForecastProfile . ticketCandidate table activeDomain) candidates
    record <- sampleRecorded factoryForecastProfile seed (cursorFor purpose currentCursors) purpose weighted
    chosen <- maybe (Left "The chosen ticket is missing.") Right (Map.lookup (drawChosenSubject record) table)
    pure (chosen, record, advance purpose record currentCursors)

  drawRoutes routes currentCursors = do
    let weighted = [routeWeight identity opportunity signals | (identity, opportunity, signals) <- routes]
    record <- sampleRecorded factoryForecastProfile seed (cursorFor ForecastOpportunityDraw currentCursors) ForecastOpportunityDraw weighted
    pure (drawChosenSubject record, record, advance ForecastOpportunityDraw record currentCursors)

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
                        , factorDeadlineApproach = Fixed 0
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

  cursorFor = Map.findWithDefault 0
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
      , factorDeadlineApproach = maximum (Fixed 0 : [ticketDeadlineApproach descendant | identity <- descendants table Set.empty (ticketIdentity ticket), Just descendant <- [Map.lookup identity table]])
      }

-- The same conditional ticket weights as selectForecast, integrated without
-- sampling. A blocker may receive probability through several original roots.
forecastSubjectChances :: Maybe [UUIDv7] -> Maybe UUIDv7 -> [SubjectTicket] -> [(SubjectTicket, Rational)]
forecastSubjectChances activeDomain hardScope tickets =
  Map.elems
    ( Map.fromListWith
        combine
        [(ticketIdentity ticket, (ticket, chance)) | (ticket, _, chance) <- forecastOpportunityChances activeDomain hardScope tickets]
    )
 where
  combine (ticket, first) (_, second) = (ticket, first + second)

-- Integrate the same route, child and dependency intervals as the draw.
-- Nothing denotes a typed non-Brick recovery, never an execution variant.
forecastOpportunityChances :: Maybe [UUIDv7] -> Maybe UUIDv7 -> [SubjectTicket] -> [(SubjectTicket, Maybe SelectableOpportunity, Rational)]
forecastOpportunityChances activeDomain hardScope tickets =
  Map.elems (Map.fromListWith combine (concat [descend Set.empty ticket chance | (ticket, chance) <- shares roots]))
 where
  table = Map.fromList [(ticketIdentity ticket, ticket) | ticket <- tickets]
  roots = [ticket | ticket <- tickets, Data.Maybe.isNothing (ticketParent ticket), reachable table Set.empty (ticketIdentity ticket), maybe True (containsDomain table (ticketIdentity ticket)) hardScope]
  combine (ticket, opportunity, first) (_, _, second) = (ticket, opportunity, first + second)
  shares candidates = normalized [(ticket, weightedInteger (forecastWeight factoryForecastProfile (ticketCandidate table activeDomain ticket))) | ticket <- candidates]
  descend seen ticket chance
    | ticketIdentity ticket `Set.member` seen = []
    | otherwise = concatMap route (normalized [(opportunity, weightedInteger (routeWeight identity opportunity signals)) | (identity, opportunity, signals) <- localRoutes table seen ticket])
   where
    nextSeen = Set.insert (ticketIdentity ticket) seen
    route (Just opportunity, share) = [((ticketIdentity ticket, selectableIdentity opportunity), (ticket, Just opportunity, chance * share))]
    route (Nothing, share)
      | not (null (ticketDependencies ticket)) = case dependencyTargets of
          [] -> [((ticketIdentity ticket, "recovery"), (ticket, Nothing, chance * share)) | any isNonBrick (ticketDependencies ticket)]
          _ -> branch dependencyTargets share
      | otherwise = branch childTargets share
    dependencyTargets = [target | DependencyBrick identity <- ticketDependencies ticket, reachable table nextSeen identity, Just target <- [Map.lookup identity table]]
    childTargets = [child | identity <- ticketChildren ticket, reachable table nextSeen identity, Just child <- [Map.lookup identity table]]
    branch candidates share = concat [descend nextSeen child (chance * share * childShare) | (child, childShare) <- shares candidates]
    isNonBrick DependencyNonBrick{} = True
    isNonBrick _ = False

normalized :: [(a, Integer)] -> [(a, Rational)]
normalized candidates = [(value, weight % total) | (value, weight) <- candidates, weight > 0, total > 0]
 where
  total = sum (snd <$> candidates)

routeWeight :: Text -> Maybe SelectableOpportunity -> [ForecastSignal] -> WeightedCandidate (Maybe SelectableOpportunity)
routeWeight identity opportunity signals =
  forecastWeight
    factoryForecastProfile
    (ForecastCandidate identity opportunity (ForecastFactors Nothing (Fixed 0) signals (Fixed 0) (Fixed 0) [] (Fixed 0)))

-- A review need not execute its owner. Continuation preserves dependency/child
-- routing, using the strongest reachable alternative rather than a child sum.
isLocalReview :: SelectableOpportunityKind -> Bool
isLocalReview kind = kind `elem` [ImportanceRunReviewOpportunity, EffortComparisonOpportunity, ImpactComparisonOpportunity, ImpactMaturityReviewOpportunity]

localRoutes :: Map UUIDv7 SubjectTicket -> Set.Set UUIDv7 -> SubjectTicket -> [(Text, Maybe SelectableOpportunity, [ForecastSignal])]
localRoutes table seen ticket
  | null (ticketDependencies ticket) && null (ticketChildren ticket) = local (ticketOpportunities ticket)
  | otherwise = local reviews <> continuation
 where
  reviews = filter (isLocalReview . selectableKind) (ticketOpportunities ticket)
  local = fmap (\opportunity -> (selectableIdentity opportunity, Just opportunity, selectableSignals opportunity))
  targets =
    if null (ticketDependencies ticket)
      then ticketChildren ticket
      else [identity | DependencyBrick identity <- ticketDependencies ticket]
  viable = filter (reachable table (Set.insert (ticketIdentity ticket) seen)) targets
  nonBrick = any (\case DependencyNonBrick{} -> True; _ -> False) (ticketDependencies ticket)
  continuation =
    [ (renderUUIDv7 (ticketIdentity ticket) <> ":continue", Nothing, bestSignals)
    | not (null viable) || nonBrick
    ]
  alternatives = [(pressure, signals) | target <- viable, let signals = strongestOpportunitySignals table target, let (pressure, _, _) = positivePressure factoryForecastProfile signals]
  bestSignals = case alternatives of
    [] -> []
    values -> snd (maximumBy (comparing (Data.Bifunctor.second (fmap signalExplanation))) values)

forecastTicketWeight :: Maybe [UUIDv7] -> [SubjectTicket] -> SubjectTicket -> WeightedCandidate UUIDv7
forecastTicketWeight activeDomain tickets = forecastWeight factoryForecastProfile . ticketCandidate (Map.fromList [(ticketIdentity ticket, ticket) | ticket <- tickets]) activeDomain

strongestOpportunitySignals :: Map UUIDv7 SubjectTicket -> UUIDv7 -> [ForecastSignal]
strongestOpportunitySignals table root =
  case candidates of
    [] -> []
    _ -> snd (maximumBy (comparing (Data.Bifunctor.second (fmap signalExplanation))) candidates)
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
          any (isLocalReview . selectableKind) (ticketOpportunities ticket)
            || ( if null (ticketDependencies ticket)
                   then not (null (ticketOpportunities ticket)) || any (reachable table (Set.insert identity seen)) (ticketChildren ticket)
                   else any dependencyReachable (ticketDependencies ticket)
               )
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
    | workCoolingDown state now brick || not (temporalGateOpen state now brick) = []
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
    , lazyReviewKind claim `notElem` ["importance", "importance_run_review"]
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
      (phaseSignal <> impactSignal <> temporalSignals state now brick <> missedSignals state brick <> quotaSignals state now brick <> [ForecastSignal AvailabilitySignal (Fixed strength) explanation])
  phaseSignal = case Map.lookup (brickId brick) (statePhaseClaims state) of
    Nothing -> []
    Just claim -> [ForecastSignal PhaseSignal (phaseStrength (phaseClaimValue claim)) "current phase"]
  impactSignal = case Map.lookup (brickId brick) (stateImpactClaims state) of
    Nothing -> []
    Just claim -> [ForecastSignal ImpactSignal (impactStrength (impactClaimClass claim)) "current Impact class"]

workCoolingDown :: State -> UTCTime -> Brick -> Bool
workCoolingDown state now brick =
  or
    [ now < untilTime
    | deferral <- Map.elems (stateWorkDeferrals state)
    , workDeferralBrick deferral == brickId brick
    , Just untilTime <- [workDeferralCooldownUntil deferral]
    ]

-- One owner per unresolved sibling run, including imported provisional order.
-- Equivalent persisted claims are coalesced rather than becoming extra tickets.
importanceRunReviews :: State -> UTCTime -> Map UUIDv7 [SelectableOpportunity]
importanceRunReviews state now =
  Map.fromListWith
    (<>)
    [ (first, [SelectableOpportunity identity ImportanceRunReviewOpportunity signals])
    | parent <- Set.toAscList (Set.fromList (brickParent <$> activeBricks state))
    , maybe True ((<= now) . importanceReviewCooldownUntil) (Map.lookup parent (stateImportanceReviewDeferrals state))
    , Just (first, second) <- [adaptiveImportancePair state now parent]
    , let siblings = importanceSiblings state parent
          relevantClaims = [claim | claim <- Map.elems (stateLazyReviews state), lazyReviewKind claim `elem` ["importance", "importance_run_review"], lazyReviewSubject claim `elem` fmap brickId siblings]
          pairCreatedAt = maximum [brickCreatedAt brick | identity' <- [first, second], Just brick <- [Map.lookup identity' (stateBricks state)]]
          origin = max pairCreatedAt (if null relevantClaims then pairCreatedAt else minimum (fmap lazyReviewCreatedAt relevantClaims))
          confidence = minimum [localConfidence state now brick siblings | identity' <- [first, second], Just brick <- [Map.lookup identity' (stateBricks state)]]
          uncertainty = min 750_000 (max 0 (1_000_000 - unFixed confidence))
          age = min 500_000 (max 0 (floor (diffUTCTime now origin * 500_000 / (30 * 86400))))
          count = maybe 0 importanceReviewDeferralCount (Map.lookup parent (stateImportanceReviewDeferrals state))
          avoidance = 500_000 - (500_000 `div` (2 ^ min 20 count))
          identity = "importance-run:" <> maybe "root" renderUUIDv7 parent
          signals =
            [ ForecastSignal AvailabilitySignal (Fixed 50_000) "unresolved sibling order review"
            , ForecastSignal UncertaintySignal (Fixed uncertainty) "low confidence in this sibling order"
            , ForecastSignal AgeSignal (Fixed age) "age of unresolved sibling order"
            ]
              <> [ForecastSignal AvoidanceSignal (Fixed avoidance) "ordering review deferred after uncertainty" | count > 0]
    ]

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

-- | @forecast.date.deadline_lead_days@, seven days in the factory profile.
deadlineLeadSeconds :: Integer
deadlineLeadSeconds = 7 * 24 * 60 * 60

-- | @forecast.date.best_before_max_ramp_days@, thirty days in the factory profile.
bestBeforeMaxRampSeconds :: Integer
bestBeforeMaxRampSeconds = 30 * 24 * 60 * 60

{- | Date pressure. Deadline pressure ramps over its fixed lead window; a
@best_before@ ramps from the later of the opportunity's eligibility origin
and the maximum ramp, reaching 1.00 at @best_before@ itself.
-}
temporalSignals :: State -> UTCTime -> Brick -> [ForecastSignal]
temporalSignals state now brick =
  catMaybes
    [ bestBeforeSignal . zonedInstantUtc <$> effectiveTemporal state brick temporalBestBefore earliestInstant
    , deadlineSignal . zonedInstantUtc <$> effectiveTemporal state brick temporalDeadline earliestInstant
    ]
 where
  bestBeforeSignal preferred =
    let rampStart = max (eligibilityOrigin state brick) (addUTCTime (fromInteger (negate bestBeforeMaxRampSeconds)) preferred)
     in ForecastSignal DateSignal (rampFraction now (min rampStart preferred) preferred) "best-before window"
  deadlineSignal deadline =
    ForecastSignal DateSignal (rampFraction now (addUTCTime (fromInteger (negate deadlineLeadSeconds)) deadline) deadline) "deadline window"

{- | When this Work first became eligible: its creation or release, or its
opening when that comes later.
-}
eligibilityOrigin :: State -> Brick -> UTCTime
eligibilityOrigin state brick =
  maybe created (max created . zonedInstantUtc) (effectiveTemporal state brick temporalNotBefore latestInstant)
 where
  created = brickCreatedAt brick

-- | @forecast.miss.*@: recent misses of a lapsing series press its next occurrence.
missedSignals :: State -> Brick -> [ForecastSignal]
missedSignals state brick = case Map.lookup (brickId brick) (stateRecurringOccurrences state) of
  Just occurrence
    | Just schedule <- Map.lookup (recurringOccurrenceOwner occurrence) (stateRecurrenceSchedules state)
    , recurrenceDeadlinePolicy schedule == DeadlineLapses
    , misses > 0 ->
        [ForecastSignal MissedSignal (Fixed (min 500_000 (250_000 * fromIntegral misses))) "recent missed periods of this series"]
   where
    misses = length (filter ((== PeriodMissed) . snd) (take missHistoryPeriods (obligationPeriodHistory state (recurringOccurrenceOwner occurrence))))
  _ -> []

-- | @obligation.miss_history_periods@, four in the factory profile.
missHistoryPeriods :: Int
missHistoryPeriods = 4

{- | Quota-window pressure: the elapsed fraction of an open quota window
times its unmet fraction. Fixed slots use date, age, and deferral evidence.
-}
quotaSignals :: State -> UTCTime -> Brick -> [ForecastSignal]
quotaSignals state now brick = case Map.lookup (brickId brick) (stateHabitSchedules state) of
  Just QuotaWindowHabit{} ->
    [ ForecastSignal ScheduleSignal (fixedProduct elapsed unmet) "quota window elapsing with unmet completions"
    | window <- openHabitWindows state now brick
    , let elapsed = rampFraction now (zonedInstantUtc (habitWindowOpensAt window)) (zonedInstantUtc (habitWindowClosesAt window))
          recorded = length [() | outcome <- Map.elems (stateHabitOutcomes state), habitOutcomeWindow outcome == habitWindowId window]
          target = habitWindowTarget window
          unmet = if target <= 0 then Fixed 0 else Fixed (fromIntegral (max 0 (target - recorded)) * 1_000_000 `div` fromIntegral target)
    , unFixed unmet > 0
    ]
  _ -> []
 where
  fixedProduct (Fixed left) (Fixed right) = Fixed ((left * right + 500_000) `div` 1_000_000)

isExecutionKind :: SelectableOpportunityKind -> Bool
isExecutionKind kind =
  kind `elem` [FiniteWorkOpportunity, RepeatableRunOpportunity, HabitWindowOpportunity, LivingChecklistRunOpportunity, FiniteChecklistRunOpportunity]

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

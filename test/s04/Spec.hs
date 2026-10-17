module Main (main) where

import Data.Bifunctor qualified
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Ratio ((%))
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Forecast
import LittleAnt.ForecastWorld
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Model
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S04 forecast"
      [ testCase "provisional runs add one review and uncertainty raises its chance" provisionalReviews
      , testCase "local reviews share a ticket with container and dependency continuation" reviewRouting
      , testCase "review cooldown preserves Work and expires without erasing uncertainty" reviewCooldown
      , testCase "factory importance vector matches the normative profile" referenceImportanceVector
      , testCase "Forte+ preserves a 60 percent head and a softer tail" fortePlusDistribution
      , testCase "importance confidence and unranked subjects retain their neutral behavior" importanceConfidence
      , testCase "forecast inspection uses Forte+ at roots and hierarchical descent" fortePlusInspection
      , testCase "bounded signals match the mixed normative vector" mixedReferenceVector
      , testCase "sample 600000 selects B" referenceSample
      , testCase "every admitted candidate retains positive weight" positiveTail
      , testCase "correlated signals collapse to their maximum" correlationCollapse
      , testCase "purpose streams are isolated" purposeIsolation
      , testCase "inspection can reuse one immutable draw record" immutableRecord
      , testCase "hierarchy descends instead of serving a decomposed parent" hierarchyDescent
      , testCase "a drawn blocker preserves the original subject" blockerRedirection
      , testCase "dependency redirection follows an N-step chain" blockerChain
      , testCase "forecast chances integrate hierarchy and shared blockers without sampling" inspectChances
      , testCase "unavailable blockers cannot crash an admitted forecast branch" unavailableBlockers
      , testCase "legacy dependencies on completed work are already satisfied" completedLegacyBlocker
      , testCase "legacy dependencies on retired work cannot exclude executable Work" retiredLegacyBlocker
      , testCase "equal Domain paths consume only the Domain-path stream" domainPathTie
      , testCase "hard Domain scope never falls through globally" hardScope
      , testCase "ancestor not_before gates descendants without rewriting importance" inheritedNotBefore
      , testCase "ancestor best_before adds date pressure without rewriting importance" inheritedBestBefore
      , testCase "best_before pressure ramps from eligibility, at most thirty days" bestBeforeRamp
      , testCase "deadline approach raises importance without ever lowering it" deadlineApproachVector
      , testCase "recurring obligations hold no importance position and inherit deadline approach" obligationsAreNeutral
      , testCase "recent misses of a lapsing series press its next occurrence" recentMissPressure
      , testCase "quota windows press by elapsed and unmet fractions" quotaWindowPressure
      ]

provisionalReviews :: Assertion
provisionalReviews = do
  let bricks = [fixtureBrick (uuid index) ("task-" <> Text.pack (show index)) AtomicTask Nothing (index - 1) | index <- [1 .. 6]]
      state = fixtureState bricks
      world = buildForecastWorld state fixedTime
      reviews = [op | owner <- world, op <- ticketOpportunities owner, selectableKind op == ImportanceRunReviewOpportunity]
      reviewChance tickets = sum [chance | (_, Just op, chance) <- forecastOpportunityChances Nothing Nothing tickets, selectableKind op == ImportanceRunReviewOpportunity]
      removeUncertainty ticket' = ticket'{ticketOpportunities = [op{selectableSignals = filter ((/= UncertaintySignal) . signalKey) (selectableSignals op)} | op <- ticketOpportunities ticket']}
  length world @?= 6
  length reviews @?= 1
  Set.size (Set.fromList (ticketIdentity <$> world)) @?= 6
  assertBool "uncertainty did not raise the review's marginal chance" (reviewChance world > reviewChance (removeUncertainty <$> world))
  let claims = [LazyReviewClaim (uuid index) (brickId (head bricks)) "importance_run_review" "provisional" fixedTime | index <- [80, 81]]
      duplicated = state{stateLazyReviews = Map.fromList [(lazyReviewId claim, claim) | claim <- claims]}
  buildForecastWorld duplicated fixedTime @?= world
  let old = (head bricks){brickCreatedAt = addUTCTime (-(60 * 86400)) fixedTime}
      freshRun = buildForecastWorld (fixtureState [old, bricks !! 1]) fixedTime
  [signalStrength signal | owner <- freshRun, op <- ticketOpportunities owner, selectableKind op == ImportanceRunReviewOpportunity, signal <- selectableSignals op, signalKey signal == AgeSignal] @?= [Fixed 0]
  let first = head bricks
      second = bricks !! 1
      comparison = PairJudgment (uuid 90) ImportanceAxis (brickId first) (brickId second) MoreThan fixedTime DirectHuman fixedOne "judgment@1" "order" "test" JudgmentCurrent
      coherent = (fixtureState [first, second]){statePairJudgments = Map.singleton (judgmentId comparison) comparison}
  assertBool "a coherent sibling group was asked again" (all (all ((/= ImportanceRunReviewOpportunity) . selectableKind) . ticketOpportunities) (buildForecastWorld coherent fixedTime))

reviewRouting :: Assertion
reviewRouting = do
  let review = SelectableOpportunity "review" ImportanceRunReviewOpportunity [ForecastSignal UncertaintySignal (Fixed 750_000) "uncertain order"]
      parent = ticket (uuid 1) Nothing [uuid 2] [] [review]
      child = ticket (uuid 2) (Just (uuid 1)) [] [] [work (uuid 2)]
      blocked = parent{ticketChildren = [], ticketDependencies = [DependencyBrick (uuid 2)]}
      check owner = do
        let world = [owner, child]
            chances = forecastOpportunityChances Nothing Nothing world
        sum [chance | (_, _, chance) <- chances] @?= 1
        sum [chance | (one, _, chance) <- chances, ticketIdentity one == uuid 1] @?= 5 % 8
        sum [chance | (one, _, chance) <- chances, ticketIdentity one == uuid 2] @?= 3 % 8
        mapM_
          ( \n -> case selectForecast (ByteString.replicate 32 n) mempty Nothing Nothing world of
              Right SelectedOpportunity{selectedEndpointSubject, selectedOpportunity} ->
                assertBool "the draw selected an unprojected opportunity" (any (\(one, op, chance) -> ticketIdentity one == selectedEndpointSubject && op == Just selectedOpportunity && chance > 0) chances)
              other -> assertFailure (show other)
          )
          [0 .. 40]
  mapM_
    ( \kind -> do
        let localReview = review{selectableKind = kind}
        check parent{ticketOpportunities = [localReview]}
        check blocked{ticketOpportunities = [localReview]}
    )
    [ImportanceRunReviewOpportunity, EffortComparisonOpportunity, ImpactComparisonOpportunity, ImpactMaturityReviewOpportunity]
  let cyclic = child{ticketDependencies = [DependencyBrick (uuid 1)]}
  sum [chance | (_, _, chance) <- forecastOpportunityChances Nothing Nothing [blocked, cyclic]] @?= 1
  case selectForecast seed mempty Nothing Nothing [blocked, cyclic] of
    Right SelectedOpportunity{selectedOpportunity} -> selectableKind selectedOpportunity @?= ImportanceRunReviewOpportunity
    other -> assertFailure (show other)

reviewCooldown :: Assertion
reviewCooldown = do
  let first = fixtureBrick (uuid 1) "one" AtomicTask Nothing 0
      second = fixtureBrick (uuid 2) "two" AtomicTask Nothing 1
      state = (fixtureState [first, second]){stateImportanceReviewDeferrals = Map.singleton Nothing (ImportanceReviewDeferral (addUTCTime 86400 fixedTime) 1)}
      kinds now = selectableKind <$> concatMap ticketOpportunities (buildForecastWorld state now)
  assertBool "review was still admitted during its cooldown" (ImportanceRunReviewOpportunity `notElem` kinds fixedTime)
  length (filter (== FiniteWorkOpportunity) (kinds fixedTime)) @?= 2
  length (filter (== ImportanceRunReviewOpportunity) (kinds (addUTCTime 86400 fixedTime))) @?= 1

referenceImportanceVector :: Assertion
referenceImportanceVector =
  fmap weightedInteger candidates @?= [1_000_000, 390_980, 275_687]
 where
  candidates = fmap (forecastWeight factoryForecastProfile) [candidate "A" 0 3, candidate "B" 1 3, candidate "C" 2 3]

mixedReferenceVector :: Assertion
mixedReferenceVector =
  fmap weightedInteger [a, b, c] @?= [250_000, 684_215, 827_061]
 where
  a = forecastWeight factoryForecastProfile (withNegative (candidate "A" 0 3) (Fixed 1_000_000))
  b = forecastWeight factoryForecastProfile (withDomain (candidate "B" 1 3) (Fixed 1_000_000))
  c = forecastWeight factoryForecastProfile (withPositive (candidate "C" 2 3) (Fixed 1_000_000))

fortePlusDistribution :: Assertion
fortePlusDistribution = do
  let weights count =
        [ unFixed (importanceFactor factoryForecastProfile (Just (position, count)) fixedOne)
        | position <- [0 .. count - 1]
        ]
      check count = case weights count of
        [] -> assertFailure "the sibling group is empty"
        values@(top : _) -> do
          let topChance = top % sum values
          assertBool "the top should remain near 60 percent as the group size changes" (abs (topChance - 3 % 5) < 1 % 5_000)
          assertBool "tail weights must remain positive" (all (> 0) values)
          assertBool "importance must not reverse the sibling order" (and (zipWith (>=) values (drop 1 values)))
  mapM_ check [2, 3, 5, 10, 20, 53, 100, 1_000]
  take 5 (weights 53) @?= [1_000_000, 196_257, 137_457, 96_297, 67_485]
  sum (weights 53) @?= 1_666_684
  let values = weights 53
      tailRatio = values !! 2 % (values !! 1)
      topFive = sum (take 5 values) % sum values
  assertBool "the tail should fall by about 30 percent per position" (tailRatio > 7 % 10 && tailRatio < 71 % 100)
  assertBool "the first five should receive about 89.85 percent" (abs (topFive - 8_985 % 10_000) < 1 % 10_000)

importanceConfidence :: Assertion
importanceConfidence = do
  let factor = importanceFactor factoryForecastProfile
      placements = [Just (position, 53) | position <- [0 .. 52]]
  map (\placement -> factor placement (Fixed 0)) placements @?= replicate 53 (Fixed 350_000)
  factor (Just (0, 53)) (Fixed 150_000) @?= Fixed 447_500
  factor Nothing fixedOne @?= Fixed 350_000
  factor (Just (0, 1)) (Fixed 0) @?= fixedOne
  factor (Just (-1, 53)) fixedOne @?= factor (Just (0, 53)) fixedOne
  factor (Just (100, 53)) fixedOne @?= factor (Just (52, 53)) fixedOne
  factor (Just (52, 53)) (Fixed (-1)) @?= Fixed 350_000
  factor (Just (52, 53)) (Fixed 2_000_000) @?= factor (Just (52, 53)) fixedOne
  let values = [unFixed (factor placement (Fixed 150_000)) | placement <- placements]
      topChance = unFixed (factor (Just (0, 53)) (Fixed 150_000)) % sum values
  assertBool "provisional confidence must still dilute the stronger curve" (topChance > 2 % 100 && topChance < 3 % 100)

fortePlusInspection :: Assertion
fortePlusInspection = do
  let positioned identity position count parent =
        (ticket identity parent [] [] [work identity]){ticketSiblingPosition = Just (position, count)}
      siblings = [positioned (uuid (position + 1)) position 53 Nothing | position <- [0 .. 52]]
      chances = fmap (Data.Bifunctor.first ticketIdentity) (forecastSubjectChances Nothing Nothing siblings)
  sum (snd <$> chances) @?= 1
  case lookup (uuid 1) chances of
    Just chance -> assertBool "inspection must reflect the factory 60 percent head after bounded-signal rounding" (abs (chance - 3 % 5) < 1 % 50_000)
    Nothing -> assertFailure "forecast inspection omitted the first sibling"
  let parent = ticket (uuid 70) Nothing [uuid 71, uuid 72] [] []
      first = positioned (uuid 71) 0 2 (Just (uuid 70))
      second = positioned (uuid 72) 1 2 (Just (uuid 70))
      childChances = fmap (Data.Bifunctor.first ticketIdentity) (forecastSubjectChances Nothing Nothing [parent, first, second])
  case lookup (uuid 71) childChances of
    Just chance -> assertBool "hierarchical descent must use the same Forte+ curve" (abs (chance - 3 % 5) < 1 % 100_000)
    Nothing -> assertFailure "forecast descent omitted the first child"

referenceSample :: Assertion
referenceSample =
  case sampleWithInteger factoryForecastProfile ForecastSubjectDraw 600_000 weighted of
    Left problem -> assertFailure (show problem)
    Right record -> drawChosenIdentity record @?= "B"
 where
  weighted =
    [ forecastWeight factoryForecastProfile (withNegative (candidate "A" 0 3) (Fixed 1_000_000))
    , forecastWeight factoryForecastProfile (withDomain (candidate "B" 1 3) (Fixed 1_000_000))
    , forecastWeight factoryForecastProfile (withPositive (candidate "C" 2 3) (Fixed 1_000_000))
    ]

positiveTail :: Assertion
positiveTail =
  assertBool "bottom candidate is still drawable" (weightedInteger bottom > 0)
 where
  bottom =
    forecastWeight
      factoryForecastProfile
      (withNegative (candidate "odd" 999 1000) (Fixed 1_000_000))

correlationCollapse :: Assertion
correlationCollapse =
  pressure @?= Fixed 800_000
 where
  (pressure, _, _) =
    positivePressure
      factoryForecastProfile
      [ ForecastSignal AgeSignal (Fixed 300_000) "old"
      , ForecastSignal AgeSignal (Fixed 800_000) "older"
      ]

purposeIsolation :: Assertion
purposeIsolation =
  case (subject, child) of
    (Right left, Right right) -> do
      assertBool "subject stream consumed at least one subject block" (drawEndingCursor left >= 1)
      assertBool "child stream consumed at least one child block" (drawEndingCursor right >= 1)
      assertBool "purpose-separated hashes normally choose or sample differently" (drawSampledInteger left /= drawSampledInteger right || drawChosenIdentity left /= drawChosenIdentity right)
    (Left problem, _) -> assertFailure (show problem)
    (_, Left problem) -> assertFailure (show problem)
 where
  seed = ByteString.pack [0 .. 31]
  weighted = fmap (forecastWeight factoryForecastProfile) [candidate "A" 0 2, candidate "B" 1 2]
  subject = sampleRecorded factoryForecastProfile seed 0 ForecastSubjectDraw weighted
  child = sampleRecorded factoryForecastProfile seed 0 ForecastChildDraw weighted

immutableRecord :: Assertion
immutableRecord =
  case sampleRecorded factoryForecastProfile (ByteString.replicate 32 7) 9 ForecastSubjectDraw weighted of
    Left problem -> assertFailure (show problem)
    Right record -> do
      drawStartingCursor record @?= 9
      drawEndingCursor record @?= 10
      drawCandidates record @?= drawCandidates record
 where
  weighted = fmap (forecastWeight factoryForecastProfile) [candidate "A" 0 2, candidate "B" 1 2]

candidate :: Text -> Int -> Int -> ForecastCandidate Text
candidate identity position count =
  ForecastCandidate
    identity
    identity
    ForecastFactors
      { factorSiblingPosition = Just (position, count)
      , factorImportanceConfidence = Fixed 1_000_000
      , factorPositiveSignals = []
      , factorDomainAffinity = Fixed 0
      , factorFamilyAffinity = Fixed 0
      , factorNegativeSignals = []
      , factorDeadlineApproach = Fixed 0
      }

withPositive :: ForecastCandidate subject -> Fixed -> ForecastCandidate subject
withPositive item strength =
  item
    { forecastFactors =
        (forecastFactors item)
          { factorPositiveSignals = [ForecastSignal AvailabilitySignal strength "pressure"]
          }
    }

withNegative :: ForecastCandidate subject -> Fixed -> ForecastCandidate subject
withNegative item strength =
  item
    { forecastFactors =
        (forecastFactors item)
          { factorNegativeSignals = [ForecastSignal AvoidanceSignal strength "fatigue"]
          }
    }

withDomain :: ForecastCandidate subject -> Fixed -> ForecastCandidate subject
withDomain item affinity =
  item{forecastFactors = (forecastFactors item){factorDomainAffinity = affinity}}

inspectChances :: Assertion
inspectChances = do
  let parent = ticket (uuid 1) Nothing [uuid 2, uuid 3] [] []
      first = ticket (uuid 2) (Just (uuid 1)) [] [] [work (uuid 2)]
      second = ticket (uuid 3) (Just (uuid 1)) [] [] [work (uuid 3)]
  fmap (Data.Bifunctor.first ticketIdentity) (forecastSubjectChances Nothing Nothing [parent, first, second]) @?= [(uuid 2, 1 % 2), (uuid 3, 1 % 2)]
  let blocked = ticket (uuid 4) Nothing [] [DependencyBrick (uuid 2)] [work (uuid 4)]
      blocker = first{ticketParent = Nothing}
  fmap (Data.Bifunctor.first ticketIdentity) (forecastSubjectChances Nothing Nothing [blocked, blocker]) @?= [(uuid 2, 1)]
  forecastSubjectChances Nothing (Just (uuid 99)) [parent, first, second] @?= []

hierarchyDescent :: Assertion
hierarchyDescent =
  case selectForecast seed mempty Nothing Nothing [parent, child] of
    Right SelectedOpportunity{selectedOriginalSubject = original, selectedEndpointSubject = endpoint} -> do
      original @?= uuid 1
      endpoint @?= uuid 2
    other -> assertFailure (show other)
 where
  parent = ticket (uuid 1) Nothing [uuid 2] [] []
  child = ticket (uuid 2) (Just (uuid 1)) [] [] [work (uuid 2)]

unavailableBlockers :: Assertion
unavailableBlockers = do
  let unavailable = ticket (uuid 1) Nothing [] [DependencyBrick (uuid 99)] [work (uuid 1)]
      ready = ticket (uuid 2) Nothing [] [] [work (uuid 2)]
      branching = ticket (uuid 3) Nothing [] [DependencyBrick (uuid 1), DependencyBrick (uuid 2)] [work (uuid 3)]
  selectForecast seed mempty Nothing Nothing [unavailable] @?= Right (EmptyForecast "No opportunity is currently eligible.")
  mapM_ (\world -> case selectForecast seed mempty Nothing Nothing world of Right SelectedOpportunity{selectedEndpointSubject} -> selectedEndpointSubject @?= uuid 2; other -> assertFailure (show other)) [[unavailable, ready], [branching, unavailable{ticketParent = Just (uuid 98)}, ready{ticketParent = Just (uuid 97)}]]
  fmap (Data.Bifunctor.first ticketIdentity) (forecastSubjectChances Nothing Nothing [unavailable, ready]) @?= [(uuid 2, 1)]

completedLegacyBlocker :: Assertion
completedLegacyBlocker = do
  let blocked = fixtureBrick (uuid 84) "blocked" AtomicTask Nothing 0
      done = (fixtureBrick (uuid 85) "done" AtomicTask Nothing 1){brickStatus = BrickDone}
      dependency = Dependency (uuid 86) (brickId blocked) (brickId done) DependencyActive "migration:v0" fixedTime
      state = (fixtureState [blocked, done]){stateDependencies = Map.singleton (dependencyId dependency) dependency}
      world = buildForecastWorld state fixedTime
  case selectForecast seed mempty Nothing Nothing world of
    Right SelectedOpportunity{selectedEndpointSubject} -> selectedEndpointSubject @?= brickId blocked
    other -> assertFailure (show other)
  fmap (Data.Bifunctor.first ticketIdentity) (forecastSubjectChances Nothing Nothing world) @?= [(brickId blocked, 1)]

retiredLegacyBlocker :: Assertion
retiredLegacyBlocker = mapM_ check [BrickArchived, BrickSuperseded, BrickMerged, BrickMissed, BrickCancelled]
 where
  check status = do
    let blocked = fixtureBrick (uuid 87) "blocked" AtomicTask Nothing 0
        retired = (fixtureBrick (uuid 88) "retired" AtomicTask Nothing 1){brickStatus = status}
        dependency = Dependency (uuid 89) (brickId blocked) (brickId retired) DependencyActive "legacy" fixedTime
        state = (fixtureState [blocked, retired]){stateDependencies = Map.singleton (dependencyId dependency) dependency}
        world = buildForecastWorld state fixedTime
    case selectForecast seed mempty Nothing Nothing world of
      Right SelectedOpportunity{selectedEndpointSubject} -> selectedEndpointSubject @?= brickId blocked
      other -> assertFailure (show other)
    fmap (Data.Bifunctor.first ticketIdentity) (forecastSubjectChances Nothing Nothing world) @?= [(brickId blocked, 1)]

blockerRedirection :: Assertion
blockerRedirection =
  case selectForecast seed mempty Nothing Nothing [blocked, blocker] of
    Right SelectedOpportunity{selectedOriginalSubject = original, selectedEndpointSubject = endpoint, selectedDependencyPath = path} -> do
      original @?= uuid 1
      endpoint @?= uuid 2
      path @?= [uuid 1, uuid 2]
    other -> assertFailure (show other)
 where
  blocked = ticket (uuid 1) Nothing [] [DependencyBrick (uuid 2)] [work (uuid 1)]
  blocker = ticket (uuid 2) (Just (uuid 99)) [] [] [work (uuid 2)]

blockerChain :: Assertion
blockerChain =
  case selectForecast seed mempty Nothing Nothing [first, second, endpoint] of
    Right SelectedOpportunity{selectedOriginalSubject = original, selectedEndpointSubject = selected, selectedDependencyPath = path} -> do
      original @?= uuid 1
      selected @?= uuid 3
      path @?= [uuid 1, uuid 2, uuid 3]
    other -> assertFailure (show other)
 where
  first = ticket (uuid 1) Nothing [] [DependencyBrick (uuid 2)] [work (uuid 1)]
  second = ticket (uuid 2) (Just (uuid 90)) [] [DependencyBrick (uuid 3)] [work (uuid 2)]
  endpoint = ticket (uuid 3) (Just (uuid 91)) [] [] [work (uuid 3)]

domainPathTie :: Assertion
domainPathTie =
  case selectForecast seed mempty Nothing Nothing [multi] of
    Right SelectedOpportunity{selectedEffectiveDomain = Just selected, selectedDraws = draws} -> do
      assertBool "selected path is not a direct membership" (selected `elem` paths)
      fmap drawPurpose draws @?= [ForecastSubjectDraw, ForecastOpportunityDraw, ForecastDomainPathDraw]
      drawStartingCursor (last draws) @?= 0
      assertBool "Domain tie did not consume its own stream" (drawEndingCursor (last draws) > 0)
    other -> assertFailure (show other)
 where
  paths = [[uuid 10, uuid 11], [uuid 20, uuid 21]]
  multi = (ticket (uuid 1) Nothing [] [] [work (uuid 1)]){ticketDomainPaths = paths}

hardScope :: Assertion
hardScope =
  case selectForecast seed mempty Nothing (Just (uuid 10)) [inside, outside] of
    Right SelectedOpportunity{selectedOriginalSubject = original} -> original @?= uuid 1
    other -> assertFailure (show other)
 where
  inside = (ticket (uuid 1) Nothing [] [] [work (uuid 1)]){ticketDomainPaths = [[uuid 10]]}
  outside = (ticket (uuid 2) Nothing [] [] [work (uuid 2)]){ticketDomainPaths = [[uuid 20]]}

inheritedNotBefore :: Assertion
inheritedNotBefore = do
  let parent = fixtureBrick (uuid 80) "parent" Project Nothing 0
      child = fixtureBrick (uuid 81) "child" AtomicTask (Just (brickId parent)) 0
      tomorrow = addUTCTime (24 * 60 * 60) fixedTime
      constraints = TemporalConstraints (Just (ZonedInstant tomorrow "America/Montevideo")) Nothing Nothing 1
      state = (fixtureState [parent, child]){stateTemporalConstraints = Map.singleton (brickId parent) constraints}
  buildForecastWorld state fixedTime @?= []
  brickSiblingPosition child @?= 0

inheritedBestBefore :: Assertion
inheritedBestBefore = do
  let parent = fixtureBrick (uuid 82) "parent" Project Nothing 0
      halfDays = fromIntegral (7 * 24 * 60 * 60 `div` 2 :: Int)
      -- The ramp starts when the child became eligible, half its length ago.
      child = (fixtureBrick (uuid 83) "child" AtomicTask (Just (brickId parent)) 0){brickCreatedAt = addUTCTime (negate halfDays) fixedTime}
      halfway = addUTCTime halfDays fixedTime
      constraints = TemporalConstraints Nothing (Just (ZonedInstant halfway "America/Montevideo")) Nothing 1
      state = (fixtureState [parent, child]){stateTemporalConstraints = Map.singleton (brickId parent) constraints}
      childTicket = head [item | item <- buildForecastWorld state fixedTime, ticketIdentity item == brickId child]
      dateStrengths = [signalStrength signal | opportunity <- ticketOpportunities childTicket, signal <- selectableSignals opportunity, signalKey signal == DateSignal]
  dateStrengths @?= [Fixed 500_000]
  brickSiblingPosition child @?= 0

dateStrengthsAt :: UTCTime -> UTCTime -> UTCTime -> [Fixed]
dateStrengthsAt created preferred now =
  let brick = (fixtureBrick (uuid 84) "ramp" AtomicTask Nothing 0){brickCreatedAt = created}
      constraints = TemporalConstraints Nothing (Just (ZonedInstant preferred "America/Montevideo")) Nothing 1
      state = (fixtureState [brick]){stateTemporalConstraints = Map.singleton (brickId brick) constraints}
   in [signalStrength signal | owner <- buildForecastWorld state now, opportunity <- ticketOpportunities owner, signal <- selectableSignals opportunity, signalKey signal == DateSignal]

bestBeforeRamp :: Assertion
bestBeforeRamp = do
  let days count = fromIntegral (count * 24 * 60 * 60 :: Int)
      preferred = addUTCTime (days 15) fixedTime
  -- Eligible 40 days ago: the ramp is capped to the 30 days before best_before.
  dateStrengthsAt (addUTCTime (days (-40)) fixedTime) preferred fixedTime @?= [Fixed 500_000]
  dateStrengthsAt (addUTCTime (days (-40)) fixedTime) preferred preferred @?= [fixedOne]
  dateStrengthsAt (addUTCTime (days (-40)) fixedTime) preferred (addUTCTime (days 1) preferred) @?= [fixedOne]
  -- Eligible today: no pressure yet, a quarter after a quarter of the ramp.
  dateStrengthsAt fixedTime preferred fixedTime @?= [Fixed 0]
  dateStrengthsAt fixedTime (addUTCTime (days 20) fixedTime) (addUTCTime (days 5) fixedTime) @?= [Fixed 250_000]
  -- A best_before already behind the origin is complete once eligible.
  dateStrengthsAt fixedTime (addUTCTime (days (-1)) fixedTime) fixedTime @?= [fixedOne]

deadlineApproachVector :: Assertion
deadlineApproachVector = do
  let days count = fromIntegral (count * 24 * 60 * 60 :: Int)
      lead = 7 * 24 * 60 * 60
      at count = addUTCTime (days count) fixedTime
  deadlineApproach lead fixedTime Nothing Nothing @?= Fixed 0
  deadlineApproach lead fixedTime Nothing (Just (at 7)) @?= Fixed 0
  deadlineApproach lead fixedTime Nothing (Just (addUTCTime (days 7 / 2) fixedTime)) @?= Fixed 500_000
  deadlineApproach lead fixedTime Nothing (Just (at (-1))) @?= fixedOne
  -- best_before alone starts nothing; before the deadline it starts the approach.
  deadlineApproach lead fixedTime (Just (at (-1))) Nothing @?= Fixed 0
  deadlineApproach lead fixedTime (Just (at (-2))) (Just (at 2)) @?= Fixed 500_000
  deadlineApproach lead fixedTime (Just (at 3)) (Just (at 2)) @?= Fixed 714_286
  effectiveImportance (Fixed 350_000) (Fixed 500_000) @?= Fixed 675_000
  effectiveImportance (Fixed 350_000) (Fixed 0) @?= Fixed 350_000
  effectiveImportance fixedOne (Fixed 300_000) @?= fixedOne
  effectiveImportance (Fixed 67_485) fixedOne @?= fixedOne

-- One series between two ordinary siblings, with one open occurrence.
obligationWorld :: Maybe UTCTime -> State
obligationWorld deadline =
  let first = fixtureBrick (uuid 85) "first" AtomicTask Nothing 0
      series = fixtureBrick (uuid 86) "series" RecurringObligation Nothing 1
      second = fixtureBrick (uuid 87) "second" AtomicTask Nothing 2
      occurrence = fixtureBrick (uuid 88) "occurrence" AtomicTask (Just (brickId series)) 0
      released = RecurringOccurrence (brickId occurrence) (brickId series) (brickId occurrence) (ZonedInstant fixedTime "America/Montevideo") "Aug 2026" 1
      constraints = TemporalConstraints Nothing Nothing ((`ZonedInstant` "America/Montevideo") <$> deadline) 1
   in (fixtureState [first, series, second, occurrence])
        { stateRecurringOccurrences = Map.singleton (brickId occurrence) released
        , stateTemporalConstraints = Map.singleton (brickId occurrence) constraints
        }

obligationsAreNeutral :: Assertion
obligationsAreNeutral = do
  let quiet = obligationWorld Nothing
      world = buildForecastWorld quiet fixedTime
      positionOf identity = head [ticketSiblingPosition item | item <- world, ticketIdentity item == identity]
  positionOf (uuid 85) @?= Just (0, 2)
  positionOf (uuid 86) @?= Nothing
  positionOf (uuid 87) @?= Just (1, 2)
  positionOf (uuid 88) @?= Nothing
  let seriesImportance state = weightedImportance (head [forecastTicketWeight Nothing tickets item | let tickets = buildForecastWorld state fixedTime, item <- tickets, ticketIdentity item == uuid 86])
  seriesImportance quiet @?= importanceNeutral factoryForecastProfile
  -- An overdue occurrence raises its series to the top factor.
  seriesImportance (obligationWorld (Just (addUTCTime (-60) fixedTime))) @?= fixedOne

recentMissPressure :: Assertion
recentMissPressure = do
  let series = fixtureBrick (uuid 90) "series" RecurringObligation Nothing 0
      occurrenceBrick index status = (fixtureBrick (uuid index) ("occ-" <> Text.pack (show index)) AtomicTask (Just (brickId series)) 0){brickStatus = status}
      bricks = [occurrenceBrick 91 BrickMissed, occurrenceBrick 92 BrickDone, occurrenceBrick 93 BrickMissed, occurrenceBrick 94 BrickActive]
      anchor index = ZonedInstant (addUTCTime (fromIntegral (index * 86400)) fixedTime) "America/Montevideo"
      occurrences = Map.fromList [(brickId brick, RecurringOccurrence (brickId brick) (brickId series) (brickId brick) (anchor (index :: Int)) "day" 1) | (index, brick) <- zip [1 ..] bricks]
      schedule policy = RecurrenceSchedule (brickId series) (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 1) Set.empty Nothing Nothing [TimeOfDay 18 0 0]) "America/Montevideo" AtomicTask Nothing 0 Nothing (Just 0) policy Nothing 1
      stateWith policy =
        (fixtureState (series : bricks))
          { stateRecurringOccurrences = occurrences
          , stateRecurrenceSchedules = Map.singleton (brickId series) (schedule policy)
          }
      missed state = [signalStrength signal | item <- buildForecastWorld state fixedTime, ticketIdentity item == uuid 94, opportunity <- ticketOpportunities item, signal <- selectableSignals opportunity, signalKey signal == MissedSignal]
  missed (stateWith DeadlineLapses) @?= [Fixed 500_000]
  missed (stateWith DeadlineStaysOpen) @?= []
  let excused = (stateWith DeadlineLapses){stateObligationPeriods = Map.singleton (uuid 93) (ObligationPeriod (Just fixedTime) (Just fixedTime) Nothing Nothing)}
  missed excused @?= [Fixed 250_000]

quotaWindowPressure :: Assertion
quotaWindowPressure = do
  let habit = fixtureBrick (uuid 95) "habit" Habit Nothing 0
      opens = addUTCTime (-(2 * 86400)) fixedTime
      window = HabitWindow (uuid 96) (brickId habit) (ZonedInstant opens "America/Montevideo") (ZonedInstant (addUTCTime (4 * 86400) opens) "America/Montevideo") 2 1 False
      schedule = QuotaWindowHabit (brickId habit) 2 4 ReturnDays (fromGregorian 2026 8 1) "America/Montevideo" Nothing 1
      done = HabitOutcome (uuid 97) (uuid 96) (brickId habit) StandingDone fixedTime
      base =
        (fixtureState [habit])
          { stateHabitSchedules = Map.singleton (brickId habit) schedule
          , stateHabitWindows = Map.singleton (uuid 96) window
          }
      quota state = [signalStrength signal | item <- buildForecastWorld state fixedTime, opportunity <- ticketOpportunities item, signal <- selectableSignals opportunity, signalKey signal == ScheduleSignal]
  quota base @?= [Fixed 500_000]
  quota base{stateHabitOutcomes = Map.singleton (uuid 97) done} @?= [Fixed 250_000]

fixtureState :: [Brick] -> State
fixtureState bricks =
  emptyState
    { stateBricks = Map.fromList [(brickId brick, brick) | brick <- bricks]
    , stateBrickHandles = Map.fromList [(brickHandle brick, brickId brick) | brick <- bricks]
    , stateRetiredBrickHandles = Set.fromList (fmap brickHandle bricks)
    }

fixtureBrick :: UUIDv7 -> Text -> BrickNature -> Maybe UUIDv7 -> Int -> Brick
fixtureBrick identity handle nature parent position =
  Brick identity (Handle handle) handle nature "factory@1" "test" Nothing parent Set.empty position (DeterministicPosition "fixture") BrickActive Idle fixedTime (Actor "human" "test") (uuid 99)

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))

seed :: ByteString.ByteString
seed = ByteString.pack [0 .. 31]

ticket :: UUIDv7 -> Maybe UUIDv7 -> [UUIDv7] -> [DependencyEndpoint] -> [SelectableOpportunity] -> SubjectTicket
ticket identity parent children dependencies opportunities =
  SubjectTicket
    { ticketIdentity = identity
    , ticketKind = BrickSubject
    , ticketParent = parent
    , ticketSiblingPosition = Just (0, 1)
    , ticketImportanceConfidence = Fixed 1_000_000
    , ticketNegativeSignals = []
    , ticketDomainPaths = []
    , ticketChildren = children
    , ticketDependencies = dependencies
    , ticketOpportunities = opportunities
    , ticketDeadlineApproach = Fixed 0
    }

work :: UUIDv7 -> SelectableOpportunity
work identity =
  SelectableOpportunity
    (renderUUIDv7 identity <> ":work")
    FiniteWorkOpportunity
    [ForecastSignal AvailabilitySignal (Fixed 250_000) "work"]

uuid :: Int -> UUIDv7
uuid suffix =
  either (error . show) id . parseUUIDv7 $
    "018f0000-0000-7000-8000-0000000000" <> Text.justifyRight 2 '0' (Text.pack (show suffix))

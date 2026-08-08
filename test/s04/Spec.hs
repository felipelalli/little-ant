module Main (main) where

import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
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
      [ testCase "factory importance vector matches the normative profile" referenceImportanceVector
      , testCase "bounded signals match the mixed normative vector" mixedReferenceVector
      , testCase "sample 600000 selects B" referenceSample
      , testCase "every admitted candidate retains positive weight" positiveTail
      , testCase "correlated signals collapse to their maximum" correlationCollapse
      , testCase "purpose streams are isolated" purposeIsolation
      , testCase "inspection can reuse one immutable draw record" immutableRecord
      , testCase "hierarchy descends instead of serving a decomposed parent" hierarchyDescent
      , testCase "a drawn blocker preserves the original subject" blockerRedirection
      , testCase "dependency redirection follows an N-step chain" blockerChain
      , testCase "equal Domain paths consume only the Domain-path stream" domainPathTie
      , testCase "hard Domain scope never falls through globally" hardScope
      , testCase "ancestor not_before gates descendants without rewriting importance" inheritedNotBefore
      , testCase "ancestor best_before adds date pressure without rewriting importance" inheritedBestBefore
      ]

referenceImportanceVector :: Assertion
referenceImportanceVector =
  fmap weightedInteger candidates @?= [1_000_000, 287_500, 50_000]
 where
  candidates = fmap (forecastWeight factoryForecastProfile) [candidate "A" 0 3, candidate "B" 1 3, candidate "C" 2 3]

mixedReferenceVector :: Assertion
mixedReferenceVector =
  fmap weightedInteger [a, b, c] @?= [250_000, 503_125, 150_000]
 where
  a = forecastWeight factoryForecastProfile (withNegative (candidate "A" 0 3) (Fixed 1_000_000))
  b = forecastWeight factoryForecastProfile (withDomain (candidate "B" 1 3) (Fixed 1_000_000))
  c = forecastWeight factoryForecastProfile (withPositive (candidate "C" 2 3) (Fixed 1_000_000))

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
      child = fixtureBrick (uuid 83) "child" AtomicTask (Just (brickId parent)) 0
      halfway = addUTCTime (fromIntegral (7 * 24 * 60 * 60 `div` 2 :: Int)) fixedTime
      constraints = TemporalConstraints Nothing (Just (ZonedInstant halfway "America/Montevideo")) Nothing 1
      state = (fixtureState [parent, child]){stateTemporalConstraints = Map.singleton (brickId parent) constraints}
      childTicket = head [item | item <- buildForecastWorld state fixedTime, ticketIdentity item == brickId child]
      dateStrengths = [signalStrength signal | opportunity <- ticketOpportunities childTicket, signal <- selectableSignals opportunity, signalKey signal == DateSignal]
  dateStrengths @?= [Fixed 500_000]
  brickSiblingPosition child @?= 0

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

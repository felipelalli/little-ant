module Main (main) where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Error (AppError)
import LittleAnt.Event
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Judgment
import LittleAnt.JudgmentDecision
import LittleAnt.Model
import LittleAnt.Store (genesisCursor)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "S03 importance and judgment"
    [ testCase "factory confidence decays linearly through exact public boundaries" $ do
        let judgment = evidence 4 ImportanceAxis 1 2 MoreThan DirectHuman JudgmentCurrent epoch
        effectiveConfidence epoch judgment @?= Fixed 1000000
        effectiveConfidence (daysAfter 146 epoch) judgment @?= Fixed 600000
        confidenceLabel (effectiveConfidence (daysAfter 146 epoch) judgment) @?= ReviewedJudgment
        effectiveConfidence (daysAfter 292 epoch) judgment @?= Fixed 200000
        confidenceLabel (effectiveConfidence (daysAfter 292 epoch) judgment) @?= ProvisionalJudgment
        confidenceLabel (effectiveConfidence (daysAfter 365 epoch) judgment) @?= HistoricalOnlyJudgment
    , testCase "Effort uses its shorter axis horizon without changing provenance" $ do
        let judgment = evidence 4 EffortAxis 1 2 MoreThan DirectHuman JudgmentCurrent epoch
        effectiveConfidence (daysAfter 72 epoch) judgment @?= Fixed 600000
        effectiveConfidence (daysAfter 180 epoch) judgment @?= Fixed 0
    , testCase "transitive confidence uses the weakest edge and one path penalty" $ do
        let state = stateWithEvidence [evidence 4 ImportanceAxis 1 2 MoreThan DirectHuman JudgmentCurrent epoch, evidence 5 ImportanceAxis 2 3 MoreThan DirectHuman JudgmentCurrent epoch]
        fmap directedPathConfidence (bestDirectedPath state epoch ImportanceAxis (uuid 1) (uuid 3)) @?= Just (Fixed 900000)
        relationBetween state epoch ImportanceAxis (uuid 1) (uuid 3) @?= FirstMore
    , testCase "relevant direct human evidence outranks an opposite model proposal" $ do
        let state = stateWithEvidence [evidence 4 ImportanceAxis 1 2 MoreThan DirectHuman JudgmentCurrent epoch, evidence 5 ImportanceAxis 2 1 MoreThan (ModelOnly "cheap-model") JudgmentCurrent epoch]
        relationBetween state epoch ImportanceAxis (uuid 1) (uuid 2) @?= FirstMore
        reorderedSiblingIds state epoch Nothing @?= [uuid 1, uuid 2, uuid 3]
    , testCase "fresh direct cycle is gated while changed resolution retires its path" $ do
        let first = evidence 4 ImportanceAxis 1 2 MoreThan DirectHuman JudgmentCurrent epoch
            second = evidence 5 ImportanceAxis 2 3 MoreThan DirectHuman JudgmentCurrent epoch
            state = stateWithEvidence [first, second]
        case detectContradiction state epoch ImportanceAxis (uuid 3) (uuid 1) of
          FreshContradiction path -> fmap judgmentId (directedPathJudgments path) @?= [uuid 4, uuid 5]
          other -> assertFailure ("expected a fresh contradiction, got " <> show other)
        mutation <- assertRight (decidePairJudgment state actor ImportanceAxis (uuid 3) (uuid 1) MoreThan DirectHuman JudgmentCurrent [] "order" "direct" runtime)
        assertLeft (applyMutation state mutation)
        changed <- assertRight (decidePairJudgment state actor ImportanceAxis (uuid 3) (uuid 1) MoreThan DirectHuman JudgmentCurrent [uuid 4, uuid 5] "contradiction" "changed" runtime)
        resolved <- assertRight (applyMutation state changed)
        judgmentStatus (statePairJudgments resolved Map.! uuid 4) @?= JudgmentRetired (uuid 9) "changed"
        judgmentStatus (statePairJudgments resolved Map.! uuid 5) @?= JudgmentRetired (uuid 9) "changed"
    , testCase "either-order evidence is pair-local and never transitive" $ do
        let state = stateWithEvidence [evidence 4 ImportanceAxis 1 2 EitherOrder HumanEitherOrder JudgmentCurrent epoch, evidence 5 ImportanceAxis 2 3 EitherOrder HumanEitherOrder JudgmentCurrent epoch]
        relationBetween state epoch ImportanceAxis (uuid 1) (uuid 2) @?= PairInterchangeable
        relationBetween state epoch ImportanceAxis (uuid 1) (uuid 3) @?= RelationUnknown
    , testCase "adaptive maintenance reuses known adjacent evidence and asks one unresolved pair" $ do
        let state = stateWithEvidence [evidence 4 ImportanceAxis 1 2 MoreThan DirectHuman JudgmentCurrent epoch]
        adaptiveImportancePair state epoch Nothing @?= Just (uuid 2, uuid 3)
    , testCase "provocative validation selects a never-directly-asked transitive relation" $ do
        let state = stateWithEvidence [evidence 4 ImportanceAxis 1 2 MoreThan DirectHuman JudgmentCurrent epoch, evidence 5 ImportanceAxis 2 3 MoreThan DirectHuman JudgmentCurrent epoch]
        provocativeImportancePair state epoch Nothing @?= Just (uuid 1, uuid 3)
    , testCase "nearby alternatives remain bounded to one through three positions" $ do
        nearbyComparators fiveBrickState Nothing (uuid 5) (uuid 3) @?= [uuid 2, uuid 4, uuid 1]
    , testCase "phase, Impact, and Effort are independent replayed claims" $ do
        phaseMutation <- assertRight (decidePhase baseState actor (uuid 1) (Just SpecPhase) DirectHuman runtime)
        phaseState <- assertRight (applyMutation baseState phaseMutation)
        phaseClaimValue (statePhaseClaims phaseState Map.! uuid 1) @?= SpecPhase
        impactMutation <- assertRight (decideImpactClass phaseState actor (uuid 1) (Just HighImpact) SpeculativeImpact [] DirectHuman runtime)
        impactState <- assertRight (applyMutation phaseState impactMutation)
        impactClaimClass (stateImpactClaims impactState Map.! uuid 1) @?= HighImpact
        effortMutation <- assertRight (decideEffortClass impactState actor (uuid 1) (Just EasyEffort) DirectHuman runtime)
        effortState <- assertRight (applyMutation impactState effortMutation)
        effortClaimClass (stateEffortClaims effortState Map.! uuid 1) @?= EasyEffort
        stateImportanceEdges effortState @?= Set.empty
        persisted <- case judgmentMutationEvents effortMutation of
          event : _ -> pure (persist 1 event)
          [] -> assertFailure "effort mutation has no event"
        decodeEvent (encodeEvent persisted) @?= Right persisted
    , testCase "Impact rejects child ownership and unsupported maturity without evidence" $ do
        let childState = baseState{stateBricks = Map.insert (uuid 6) (brick 6 (Just (uuid 1)) 0) (stateBricks baseState)}
        assertLeft (decideImpactClass childState actor (uuid 6) (Just HighImpact) SpeculativeImpact [] DirectHuman runtime)
        mutation <- assertRight (decideImpactClass baseState actor (uuid 1) (Just HighImpact) SupportedImpact [] DirectHuman runtime)
        assertLeft (applyMutation baseState mutation)
    ]

baseState :: State
baseState =
  emptyState
    { stateBricks = Map.fromList [(brickId value, value) | value <- fmap (\index -> brick index Nothing (index - 1)) [1 .. 3]]
    , stateBrickHandles = Map.fromList [(brickHandle value, brickId value) | value <- fmap (\index -> brick index Nothing (index - 1)) [1 .. 3]]
    }

fiveBrickState :: State
fiveBrickState =
  emptyState
    { stateBricks = Map.fromList [(brickId value, value) | value <- fmap (\index -> brick index Nothing (index - 1)) [1 .. 5]]
    }

stateWithEvidence :: [PairJudgment] -> State
stateWithEvidence values = baseState{statePairJudgments = Map.fromList [(judgmentId value, value) | value <- values]}

brick :: Int -> Maybe UUIDv7 -> Int -> Brick
brick index parent position =
  Brick
    (uuid index)
    (Handle ("b" <> Text.pack (show index)))
    ("Brick " <> Text.pack (show index))
    AtomicTask
    "factory@1"
    "factory"
    Nothing
    parent
    Set.empty
    position
    (DeterministicPosition "fixture")
    BrickActive
    Idle
    epoch
    actor
    (uuid 7)

evidence :: Int -> JudgmentAxis -> Int -> Int -> JudgmentRelation -> JudgmentProvenance -> JudgmentStatus -> UTCTime -> PairJudgment
evidence identity axis first second relation provenance status recordedAt =
  PairJudgment
    (uuid identity)
    axis
    (uuid first)
    (uuid second)
    relation
    recordedAt
    provenance
    (initialConfidence provenance)
    factoryJudgmentProfileHash
    "fixture"
    "fixture"
    status

applyMutation :: State -> JudgmentMutation -> Either AppError State
applyMutation state mutation = foldl' step (Right state) (zip [1 ..] (judgmentMutationEvents mutation))
 where
  step current (sequenceNumber, draft) = current >>= \currentState -> applyEvent currentState (persist sequenceNumber draft)

persist :: Int -> EventDraft -> PersistedEvent
persist sequenceNumber draft =
  PersistedEvent
    (draftEventId draft)
    (draftCommandId draft)
    1
    sequenceNumber
    (draftActor draft)
    (draftRecordedAt draft)
    "genesis"
    (draftPreconditionHash draft)
    (draftReplayUUIDs draft)
    (draftPayload draft)

runtime :: RuntimeFacts
runtime =
  RuntimeFacts
    epoch
    [UUIDAllocation (renderUUIDv7 (uuid 8)), UUIDAllocation (renderUUIDv7 (uuid 9))]
    Map.empty
    (FilesystemFacts True True (Just (Text.pack (show genesisCursor))))
    (TerminalCapabilities False False False 80 24 False)
    []

actor :: Actor
actor = Actor "human" "test"

epoch :: UTCTime
epoch = UTCTime (fromGregorian 2026 1 1) 0

daysAfter :: NominalDiffTime -> UTCTime -> UTCTime
daysAfter count = addUTCTime (count * 86400)

uuid :: Int -> UUIDv7
uuid index = case parseUUIDv7 ("018f0000-0000-7000-8000-00000000000" <> Text.pack (show index)) of
  Left problem -> error (Text.unpack problem)
  Right value -> value

assertRight :: (Show problem) => Either problem value -> IO value
assertRight = either (assertFailure . show) pure

assertLeft :: (Show value) => Either problem value -> Assertion
assertLeft = \case
  Left _ -> pure ()
  Right value -> assertFailure ("expected Left, got " <> show value)

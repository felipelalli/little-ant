module LittleAnt.Judgment (
  ContradictionAssessment (..),
  DirectedPath (..),
  RelationView (..),
  adaptiveImportancePair,
  axisHorizonSeconds,
  bestDirectedPath,
  confidenceLabel,
  detectContradiction,
  effectiveConfidence,
  effortPlanningHours,
  factoryJudgmentProfileHash,
  initialConfidence,
  nearbyComparators,
  provocativeImportancePair,
  provenanceTier,
  relationBetween,
  reorderedSiblingIds,
)
where

import Data.Function (on)
import Data.List (find, minimumBy, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust, mapMaybe)
import Data.Ord (Down (..), comparing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Time
import LittleAnt.Id
import LittleAnt.Model

data RelationView
  = FirstMore
  | SecondMore
  | PairInterchangeable
  | PairSimilar
  | RelationUnknown
  deriving stock (Eq, Ord, Show)

data DirectedPath = DirectedPath
  { directedPathJudgments :: [PairJudgment]
  , directedPathConfidence :: Fixed
  }
  deriving stock (Eq, Show)

data ContradictionAssessment
  = NoContradiction [UUIDv7]
  | FreshContradiction DirectedPath
  deriving stock (Eq, Show)

scale :: Integer
scale = 1000000

factoryJudgmentProfileHash :: Text
factoryJudgmentProfileHash = "little-ant/judgment-profile@1"

initialConfidence :: JudgmentProvenance -> Fixed
initialConfidence = \case
  DirectHuman -> Fixed scale
  HumanEitherOrder -> Fixed scale
  AssistedAccepted{} -> Fixed 800000
  DeterministicProvisional -> Fixed 150000
  ModelOnly{} -> Fixed 300000

provenanceTier :: JudgmentProvenance -> Int
provenanceTier = \case
  DirectHuman -> 3
  HumanEitherOrder -> 3
  AssistedAccepted{} -> 2
  DeterministicProvisional -> 1
  ModelOnly{} -> 1

axisHorizonSeconds :: JudgmentAxis -> JudgmentProvenance -> Integer
axisHorizonSeconds axis provenance = days (min provenanceDays axisDays)
 where
  provenanceDays = case provenance of
    DirectHuman -> 365
    HumanEitherOrder -> 365
    AssistedAccepted{} -> 270
    DeterministicProvisional -> 30
    ModelOnly{} -> 30
  axisDays = case axis of
    ImportanceAxis -> 365
    ImpactAxis -> 365
    EffortAxis -> 180
  days value = value * 86400

effectiveConfidence :: UTCTime -> PairJudgment -> Fixed
effectiveConfidence now judgment
  | not (isCurrent judgment) = Fixed 0
  | age >= horizon = Fixed 0
  | otherwise = Fixed (roundHalfUp (unFixed (judgmentInitialConfidence judgment) * (horizon - age)) horizon)
 where
  horizon = axisHorizonSeconds (judgmentAxis judgment) (judgmentProvenance judgment)
  age = max 0 (floor (diffUTCTime now (judgmentRecordedAt judgment)))

confidenceLabel :: Fixed -> JudgmentLabel
confidenceLabel (Fixed value)
  | value == 0 = HistoricalOnlyJudgment
  | value >= 600000 = ReviewedJudgment
  | value >= 200000 = ProvisionalJudgment
  | otherwise = ReviewDueJudgment

relationBetween :: State -> UTCTime -> JudgmentAxis -> UUIDv7 -> UUIDv7 -> RelationView
relationBetween state now axis first second
  | directRelation EitherOrder = PairInterchangeable
  | directRelation AboutSame = PairSimilar
  | Just firstScore <- pathScore <$> firstPath
  , Just secondScore <- pathScore <$> secondPath =
      case compare firstScore secondScore of
        GT -> FirstMore
        LT -> SecondMore
        EQ -> RelationUnknown
  | isJust firstPath = FirstMore
  | isJust secondPath = SecondMore
  | otherwise = RelationUnknown
 where
  directRelation relation = any matches (currentRelevant state now axis)
   where
    matches judgment =
      judgmentRelation judgment == relation
        && unorderedPair judgment == orderedPair first second
  firstPath = bestDirectedPath state now axis first second
  secondPath = bestDirectedPath state now axis second first
  pathScore path =
    ( minimum (fmap (provenanceTier . judgmentProvenance) (directedPathJudgments path))
    , directedPathConfidence path
    )

bestDirectedPath :: State -> UTCTime -> JudgmentAxis -> UUIDv7 -> UUIDv7 -> Maybe DirectedPath
bestDirectedPath state now axis from to
  | from == to = Nothing
  | otherwise = bestPath (dfs Set.empty from)
 where
  edges = currentRelevantDirected state now axis
  adjacency = Map.fromListWith (<>) [(judgmentFirst edge, [edge]) | edge <- edges]
  dfs visited current
    | current == to = [[]]
    | current `Set.member` visited = []
    | otherwise =
        [ edge : rest
        | edge <- sortOn judgmentId (Map.findWithDefault [] current adjacency)
        , rest <- dfs (Set.insert current visited) (judgmentSecond edge)
        ]
  bestPath paths = case filter (not . null) paths of
    [] -> Nothing
    candidates -> Just (minimumBy comparePath (fmap toPath candidates))
  toPath edgesInPath = DirectedPath edgesInPath (pathConfidence now edgesInPath)
  comparePath left right =
    comparing (Down . unFixed . directedPathConfidence) left right
      <> comparing (length . directedPathJudgments) left right
      <> comparing (fmap judgmentId . directedPathJudgments) left right

detectContradiction :: State -> UTCTime -> JudgmentAxis -> UUIDv7 -> UUIDv7 -> ContradictionAssessment
detectContradiction state now axis proposedFirst proposedSecond = case bestDirectedPath state now axis proposedSecond proposedFirst of
  Nothing -> NoContradiction []
  Just path
    | all ((>= Fixed 600000) . effectiveConfidence now) (directedPathJudgments path) -> FreshContradiction path
    | otherwise -> NoContradiction (fmap judgmentId (directedPathJudgments path))

adaptiveImportancePair :: State -> UTCTime -> Maybe UUIDv7 -> Maybe (UUIDv7, UUIDv7)
adaptiveImportancePair state now parent
  | length ordered <= shortRunThreshold = insertionPair [] ordered
  | otherwise = mergeRoundPair (knownRuns ordered)
 where
  shortRunThreshold = 12
  ordered = fmap brickId (sortOn (\brick -> (brickSiblingPosition brick, brickId brick)) (siblingBricks state parent))

  insertionPair _ [] = Nothing
  insertionPair [] (first : rest) = insertionPair [first] rest
  insertionPair prefix (subject : rest) =
    case insertInto prefix subject 0 (length prefix) of
      Left pair -> Just pair
      Right positioned -> insertionPair positioned rest

  insertInto prefix subject low high
    | low >= high = Right (take low prefix <> [subject] <> drop low prefix)
    | otherwise =
        let midpoint = low + ((high - low) `div` 2)
            comparator = prefix !! midpoint
         in case relationBetween state now ImportanceAxis subject comparator of
              FirstMore -> insertInto prefix subject low midpoint
              SecondMore -> insertInto prefix subject (midpoint + 1) high
              PairInterchangeable -> Right (take (midpoint + 1) prefix <> [subject] <> drop (midpoint + 1) prefix)
              PairSimilar -> Left (orderedPairByPosition comparator subject)
              RelationUnknown -> Left (orderedPairByPosition comparator subject)

  knownRuns = foldl extend []
   where
    extend [] identity = [[identity]]
    extend runs identity =
      case unsnoc runs of
        Nothing -> [[identity]]
        Just (before, currentRun) ->
          case currentRun of
            [] -> before <> [[identity]]
            _ ->
              let previous = last currentRun
               in if coherentBefore previous identity
                    then before <> [currentRun <> [identity]]
                    else runs <> [[identity]]

  mergeRoundPair = \case
    [] -> Nothing
    [_] -> Nothing
    runs -> mergePairs runs

  mergePairs (left : right : rest) =
    case mergePair left right of
      Left unresolved -> Just unresolved
      Right merged -> mergeRoundPair (merged : rest)
  mergePairs _ = Nothing

  mergePair [] right = Right right
  mergePair left [] = Right left
  mergePair left@(leftHead : leftTail) right@(rightHead : rightTail) =
    case relationBetween state now ImportanceAxis leftHead rightHead of
      FirstMore -> (leftHead :) <$> mergePair leftTail right
      SecondMore -> (rightHead :) <$> mergePair left rightTail
      PairInterchangeable -> (leftHead :) <$> mergePair leftTail right
      PairSimilar -> Left (orderedPairByPosition leftHead rightHead)
      RelationUnknown -> Left (orderedPairByPosition leftHead rightHead)

  coherentBefore first second =
    relationBetween state now ImportanceAxis first second `elem` [FirstMore, PairInterchangeable]

  position = Map.fromList (zip ordered [0 :: Int ..])
  orderedPairByPosition first second =
    if Map.findWithDefault maxBound first position <= Map.findWithDefault maxBound second position
      then (first, second)
      else (second, first)

  unsnoc = \case
    [] -> Nothing
    values -> Just (init values, last values)

provocativeImportancePair :: State -> UTCTime -> Maybe UUIDv7 -> Maybe (UUIDv7, UUIDv7)
provocativeImportancePair state now parent = case candidates of
  [] -> Nothing
  candidate : _ -> Just (candidateFirst candidate, candidateSecond candidate)
 where
  ordered = fmap brickId (sortOn (\brick -> (brickSiblingPosition brick, brickId brick)) (siblingBricks state parent))
  pairs = [(first, second) | (leftIndex, first) <- zip [0 :: Int ..] ordered, second <- drop (leftIndex + 2) ordered]
  candidates = sortOn candidateOrder (mapMaybe candidate pairs)
  candidate (first, second)
    | directlyAsked state ImportanceAxis first second = Nothing
    | otherwise = ValidationCandidate first second <$> bestDirectedPath state now ImportanceAxis first second
  candidateOrder value =
    ( unFixed (directedPathConfidence (candidatePath value))
    , oldestEdgeAt (candidatePath value)
    , length (directedPathJudgments (candidatePath value))
    , candidateFirst value
    , candidateSecond value
    )

data ValidationCandidate = ValidationCandidate
  { candidateFirst :: UUIDv7
  , candidateSecond :: UUIDv7
  , candidatePath :: DirectedPath
  }

nearbyComparators :: State -> Maybe UUIDv7 -> UUIDv7 -> UUIDv7 -> [UUIDv7]
nearbyComparators state parent subject current =
  [ identity
  | distance <- [1 .. 3]
  , index <- [currentIndex - distance, currentIndex + distance]
  , index >= 0
  , index < length ordered
  , let identity = ordered !! index
  , identity /= subject
  , identity /= current
  ]
 where
  ordered = fmap brickId (sortOn (\brick -> (brickSiblingPosition brick, brickId brick)) (siblingBricks state parent))
  currentIndex = maybe 0 fst (find ((== current) . snd) (zip [0 ..] ordered))

reorderedSiblingIds :: State -> UTCTime -> Maybe UUIDv7 -> [UUIDv7]
reorderedSiblingIds state now parent = go initialIncoming []
 where
  ordered = fmap brickId (sortOn (\brick -> (brickSiblingPosition brick, brickId brick)) (siblingBricks state parent))
  orderIndex = Map.fromList (zip ordered [0 :: Int ..])
  relevantIds = Set.fromList ordered
  candidates =
    [ judgment
    | judgment <- currentRelevantDirected state now ImportanceAxis
    , judgmentFirst judgment `Set.member` relevantIds
    , judgmentSecond judgment `Set.member` relevantIds
    ]
  accepted = foldl addUnlessCyclic [] (sortOn edgeOrder candidates)
  edges = fmap (\judgment -> (judgmentFirst judgment, judgmentSecond judgment)) accepted
  edgeOrder judgment = (Down (provenanceTier (judgmentProvenance judgment)), Down (effectiveConfidence now judgment), judgmentId judgment)
  addUnlessCyclic current candidate =
    if reachable current (judgmentSecond candidate) (judgmentFirst candidate)
      then current
      else current <> [candidate]
  reachable current from to = go Set.empty from
   where
    go visited node
      | node == to = True
      | node `Set.member` visited = False
      | otherwise = any (go (Set.insert node visited) . judgmentSecond) [edge | edge <- current, judgmentFirst edge == node]
  initialIncoming = Map.fromList [(identity, length [() | (_, below) <- edges, below == identity]) | identity <- ordered]
  go incoming result
    | length result == length ordered = result
    | null available = ordered
    | otherwise =
        let chosen = minimumBy (compare `on` (orderIndex Map.!)) available
            outgoing = [below | (above, below) <- edges, above == chosen]
            next = foldl (flip (Map.adjust (subtract 1))) (Map.delete chosen incoming) outgoing
         in go next (result <> [chosen])
   where
    available = [identity | (identity, count) <- Map.toList incoming, count == 0]

effortPlanningHours :: EffortClass -> Integer
effortPlanningHours = \case
  VeryEasyEffort -> 3
  EasyEffort -> 6
  NormalEffort -> 12
  ModerateEffort -> 24
  HardEffort -> 48
  VeryHardEffort -> 96
  MiniProjectEffort -> 192
  ProjectEffort -> 384

currentRelevant :: State -> UTCTime -> JudgmentAxis -> [PairJudgment]
currentRelevant state now axis =
  [ judgment
  | judgment <- Map.elems (statePairJudgments state)
  , judgmentAxis judgment == axis
  , isCurrent judgment
  , effectiveConfidence now judgment >= Fixed 200000
  ]

currentRelevantDirected :: State -> UTCTime -> JudgmentAxis -> [PairJudgment]
currentRelevantDirected state now axis = filter ((== MoreThan) . judgmentRelation) (currentRelevant state now axis)

isCurrent :: PairJudgment -> Bool
isCurrent judgment = judgmentStatus judgment == JudgmentCurrent

directlyAsked :: State -> JudgmentAxis -> UUIDv7 -> UUIDv7 -> Bool
directlyAsked state axis first second = any matches (Map.elems (statePairJudgments state))
 where
  matches judgment = judgmentAxis judgment == axis && unorderedPair judgment == orderedPair first second

unorderedPair :: PairJudgment -> (UUIDv7, UUIDv7)
unorderedPair judgment = orderedPair (judgmentFirst judgment) (judgmentSecond judgment)

orderedPair :: UUIDv7 -> UUIDv7 -> (UUIDv7, UUIDv7)
orderedPair first second = if first <= second then (first, second) else (second, first)

pathConfidence :: UTCTime -> [PairJudgment] -> Fixed
pathConfidence _ [] = Fixed 0
pathConfidence now edges = foldl penalize weakest (drop 1 edges)
 where
  weakest = minimum (fmap (effectiveConfidence now) edges)
  penalize (Fixed value) _ = Fixed (roundHalfUp (value * 900000) scale)

oldestEdgeAt :: DirectedPath -> UTCTime
oldestEdgeAt = minimum . fmap judgmentRecordedAt . directedPathJudgments

roundHalfUp :: Integer -> Integer -> Integer
roundHalfUp numerator denominator = (numerator + denominator `div` 2) `div` denominator

-- | The total order over bricks.
--
-- Two edge sources constrain the order: the dependency DAG (hard — a blocker
-- comes before what it blocks) and pairwise comparisons (the human/AI
-- judgment, org-sort-tasks lineage). A deterministic Kahn topological sort
-- produces the order; incomparable ties fall back to creation order (oldest
-- first), and those ties are exactly what 'orderQuestions' proposes asking
-- the human about.
module LittleAnt.Order
  ( totalOrder
  , orderQuestions
  , placeBrick
  , SortOutcome (..)
  , mergeSortStep
  , hasPath
  , orderEdges
  ) where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import LittleAnt.Ids (Id)
import LittleAnt.State
import LittleAnt.Types

-- | Ordering edges restricted to the given node set: (first, later).
-- Dependencies contribute blocker->blocked; comparisons before->after.
orderEdges :: State -> Set Id -> Set (Id, Id)
orderEdges st nodes = Set.union depEdges compEdges
  where
    inSet i = Set.member i nodes
    depEdges = Set.fromList
      [ (blocker, blocked)
      | (blocked, blocker) <- Set.toList (stDeps st)
      , inSet blocker, inSet blocked ]
    compEdges = Set.fromList
      [ (before, after)
      | (before, after) <- Map.keys (stComparisons st)
      , inSet before, inSet after ]

-- | Deterministic total order over the given bricks.
--
-- Kahn's algorithm; among ready nodes the oldest (creation sequence) wins.
-- If a cycle survives (possible via transitive comparison chains), it is
-- broken deterministically by emitting the oldest node in the cycle.
totalOrder :: State -> [Brick] -> [Brick]
totalOrder st bricks = go initialIndeg (Set.fromList nodeIds)
  where
    byId = Map.fromList [ (bId b, b) | b <- bricks ]
    nodeIds = Map.keys byId
    edges = orderEdges st (Map.keysSet byId)
    initialIndeg :: Map Id Int
    initialIndeg =
      foldr (\(_, to) m -> Map.adjust (+ 1) to m)
        (Map.fromList [ (i, 0) | i <- nodeIds ])
        (Set.toList edges)

    tieBreak :: Id -> (Int, Id)
    tieBreak i = (maybe maxBound bCreatedSeq (Map.lookup i byId), i)

    go :: Map Id Int -> Set Id -> [Brick]
    go indeg remaining
      | Set.null remaining = []
      | otherwise =
          let ready =
                [ i | i <- Set.toList remaining
                    , Map.findWithDefault 0 i indeg == 0 ]
              pick = case ready of
                [] -> minimumBy tieBreak (Set.toList remaining) -- cycle: break it
                is -> minimumBy tieBreak is
              outgoing =
                [ to | (from, to) <- Set.toList edges
                     , from == pick, Set.member to remaining ]
              indeg' = foldr (Map.adjust (subtract 1)) indeg outgoing
              remaining' = Set.delete pick remaining
           in case Map.lookup pick byId of
                Just b -> b : go indeg' remaining'
                Nothing -> go indeg' remaining'

    minimumBy :: Ord k => (a -> k) -> [a] -> a
    minimumBy f (x : xs) = foldl (\acc y -> if f y < f acc then y else acc) x xs
    minimumBy _ [] = error "minimumBy: empty list (unreachable)"

-- | Is there a directed path from a to b through the order edges?
hasPath :: Set (Id, Id) -> Id -> Id -> Bool
hasPath edges from to = go (Set.singleton from) [from]
  where
    succs i = [ y | (x, y) <- Set.toList edges, x == i ]
    go _ [] = False
    go seen (x : rest)
      | x == to = True
      | otherwise =
          let new = [ y | y <- succs x, not (Set.member y seen) ]
           in go (foldr Set.insert seen new) (new ++ rest)

-- | Binary-insertion placement — the direct heir of
-- org-insert-sorted-todo-heading: to place one brick into an already-ordered
-- list, ask ~log n midpoint questions. Returns either the settled position
-- (0-based, within the others' order) or the single next brick to compare
-- against.
placeBrick :: State -> [Brick] -> Brick -> Either Int Brick
placeBrick st others target =
  let ordered = totalOrder st [ o | o <- others, bId o /= bId target ]
      nodes = Set.fromList (bId target : map bId ordered)
      edges = orderEdges st nodes
      go lo hi
        | lo >= hi = Left lo
        | otherwise =
            let mid = (lo + hi) `div` 2
                m = ordered !! mid
             in if hasPath edges (bId target) (bId m)
                  then go lo mid          -- target already before mid
                  else if hasPath edges (bId m) (bId target)
                    then go (mid + 1) hi  -- target already after mid
                    else Right m          -- unknown: this is the question
   in go 0 (length ordered)

-- | One step of an interactive bulk sort — the faithful port of
-- org-sort-tasks' adapted merge sort, made resumable:
--
-- * insertion sort (walking backward from the end) for runs of up to 8
--   elements — below that, insertion asks fewer questions than merging;
-- * merge with the short-circuit: if the two halves are already ordered
--   relative to each other (@last left <= first right@), they concatenate
--   after a single question — on a mostly-sorted list the whole sort
--   collapses to near-zero questions (the \"tolerance\" effect);
-- * every already-known pair (dependencies, recorded comparisons, and their
--   transitive closure) is answered from the graph, never asked.
--
-- The CLI is stateless across invocations, so the algorithm simply replays:
-- each recorded answer extends the graph, the replay takes the same
-- deterministic path and stops at the next unknown pair.
data SortOutcome
  = SortedOrder [Brick]
    -- ^ The sort completed: the frontier's order is fully justified.
  | AskPair Brick Brick
    -- ^ The next question: should the first be done before the second?
  deriving (Eq, Show)

mergeSortStep :: State -> [Brick] -> SortOutcome
mergeSortStep st bricks =
  case sortE (totalOrder st bricks) of
    Right sorted -> SortedOrder sorted
    Left (a, b) -> AskPair a b
  where
    edges = orderEdges st (Set.fromList (map bId bricks))

    -- Right True: a before b. Right False: b before a. Left: unknown — ask.
    cmp :: Brick -> Brick -> Either (Brick, Brick) Bool
    cmp a b
      | hasPath edges (bId a) (bId b) = Right True
      | hasPath edges (bId b) (bId a) = Right False
      | otherwise = Left (a, b)

    smallRun :: Int
    smallRun = 8

    sortE :: [Brick] -> Either (Brick, Brick) [Brick]
    sortE xs
      | length xs <= smallRun = foldM insertBack [] xs
      | otherwise = do
          let (l, r) = splitAt (length xs `div` 2) xs
          ls <- sortE l
          rs <- sortE r
          mergeE ls rs

    -- org-sort-tasks' insert-sort: walk backward from the end of the
    -- already-sorted accumulator (cheapest on mostly-sorted input).
    insertBack :: [Brick] -> Brick -> Either (Brick, Brick) [Brick]
    insertBack acc x = go (reverse acc) []
      where
        go [] suffix = Right (x : suffix)
        go (y : rest) suffix = do
          xBefore <- cmp x y
          if xBefore
            then go rest (y : suffix)
            else Right (reverse (y : rest) ++ (x : suffix))

    -- org-sort-tasks' merge: first probe whether the halves are already
    -- ordered relative to each other; if so, concatenate.
    mergeE :: [Brick] -> [Brick] -> Either (Brick, Brick) [Brick]
    mergeE [] ys = Right ys
    mergeE xs [] = Right xs
    mergeE xs ys@(y0 : _) =
      case reverse xs of
        [] -> Right ys
        (lastX : _) -> do
          headRightFirst <- cmp y0 lastX
          if not headRightFirst
            then Right (xs ++ ys)
            else interleave xs ys
      where
        interleave [] ys' = Right ys'
        interleave xs' [] = Right xs'
        interleave (x : xs') (y : ys') = do
          xFirst <- cmp x y
          if xFirst
            then (x :) <$> interleave xs' (y : ys')
            else (y :) <$> interleave (x : xs') ys'

-- | Pairs of adjacent bricks in the current order whose relative position is
-- a mere tie-break (no path connects them): the most informative questions
-- to ask the human, top of the order first.
orderQuestions :: State -> [Brick] -> Int -> [(Brick, Brick)]
orderQuestions st bricks limit =
  let ordered = totalOrder st bricks
      edges = orderEdges st (Set.fromList (map bId bricks))
      adjacent = zip ordered (drop 1 ordered)
      unordered =
        [ (a, b)
        | (a, b) <- adjacent
        , not (hasPath edges (bId a) (bId b))
        , not (hasPath edges (bId b) (bId a)) ]
   in take limit unordered

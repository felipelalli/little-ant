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
  , hasPath
  , orderEdges
  ) where

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

-- | Human-readable projections. Projections are cheap and regenerable —
-- the truth is always the event log.
module LittleAnt.Render
  ( renderMarkdown
  , renderOrg
  , renderTaskJuggler
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, utctDay)
import LittleAnt.Ids (Id, shortId)
import LittleAnt.Order (totalOrder)
import LittleAnt.Scheduler (frontier)
import LittleAnt.State
import LittleAnt.Types

renderMarkdown :: State -> Text
renderMarkdown st = T.unlines $
  [ "# Backlog", "" ]
  ++ section "Focus frontier (in order)" (frontierLines "1. ")
  ++ section "In progress" (wipLines "- ")
  ++ section "Waiting / blocked" (waitingLines "- ")
  ++ section "Committed (not yet ready)" (committedLines "- ")
  ++ section "Seeds (idea bucket)" (seedLines "- ")
  where
    section title ls =
      if null ls then [] else ("## " <> title) : "" : ls ++ [""]
    line prefix b =
      prefix <> "`" <> shortId (bId b) <> "` " <> bTitle b
        <> maybe "" (\c -> " _(" <> c <> ")_") (bContext b)
    frontierLines p = [ line p b | b <- frontier st ]
    wipLines p =
      [ line p b | b <- Map.elems (stBricks st), bStage b == Wip ]
    waitingLines p =
      [ line p b <> " — " <> reason b
      | b <- Map.elems (stBricks st)
      , bStage b == Ready
      , isWaiting st b || isBlocked st b ]
    reason b
      | isWaiting st b && isBlocked st b = "waiting + blocked"
      | isWaiting st b = "waiting"
      | otherwise = "blocked"
    committedLines p =
      [ line p b | b <- Map.elems (stBricks st), bStage b == Committed ]
    seedLines p =
      [ line p b | b <- Map.elems (stBricks st), bStage b == Seed ]

-- | A TaskJuggler 3 project: the open actionable leaves as tasks, the
-- dependency DAG as `depends`, the total order as `priority`, estimates as
-- `effort` — gaps filled with a default and explicitly marked as guesses.
-- Feed to tj3 for scenario simulation (v1 grows this).
renderTaskJuggler :: State -> UTCTime -> Double -> Text
renderTaskJuggler st now defaultEffort = T.unlines $
  [ "project ant \"Little Ant\" \"0.1\" " <> day <> " +6m {"
  , "    timezone \"UTC\""
  , "    now ${projectstart}"
  , "    scenario plan \"Plan\" {}"
  , "}"
  , ""
  , "resource me \"Me\" {"
  , "    limits { dailymax 6h }"
  , "}"
  , ""
  ] ++ concatMap taskBlock (zip [1 ..] leaves) ++
  [ ""
  , "taskreport schedule \"schedule\" {"
  , "    formats csv"
  , "    columns id, name, start, end, effort"
  , "    scenarios plan"
  , "}"
  ]
  where
    day = T.pack (show (utctDay now))
    leaves = totalOrder st
      [ b | b <- Map.elems (stBricks st)
          , bStage b `elem` [Committed, Ready, Wip]
          , isLeaf st b ]
    leafIds = Set.fromList (map bId leaves)
    total = length leaves
    tjId :: Id -> Text
    tjId i = "t_" <> shortId i
    esc = T.filter (/= '"')
    taskBlock :: (Int, Brick) -> [Text]
    taskBlock (pos, b) =
      let deps =
            [ tjId blocker
            | blocker <- brickBlockers st b
            , Set.member blocker leafIds ]
          (effort, marker) = case bEstimateHours b of
            Just h ->
              ( h
              , case bEstimateBy b of
                  Just AI -> "  # estimate by ai (guess)"
                  _ -> "" )
            Nothing -> (defaultEffort, "  # estimate missing — default")
          -- top of the order = highest priority (TJ scale 1..1000)
          prio = max 1 (1000 - ((pos - 1) * 900 `div` max 1 total))
       in [ "task " <> tjId (bId b) <> " \"" <> esc (bTitle b) <> "\" {"
          , "    effort " <> T.pack (show effort) <> "h" <> marker
          , "    priority " <> T.pack (show prio)
          , "    allocate me"
          ] ++
          [ "    depends " <> T.intercalate ", " (map ("!" <>) deps)
          | not (null deps) ] ++
          [ "}", "" ]

renderOrg :: State -> Text
renderOrg st = T.unlines $
  [ "#+TITLE: Little Ant backlog", "" ]
  ++ concatMap entry (frontier st)
  ++ concatMap todoEntry
       [ b | b <- Map.elems (stBricks st), bStage b == Committed ]
  where
    entry b =
      [ "* NEXT " <> bTitle b
      , "  :PROPERTIES:"
      , "  :BRICK: " <> shortId (bId b)
      , "  :END:" ]
    todoEntry b =
      [ "* TODO " <> bTitle b
      , "  :PROPERTIES:"
      , "  :BRICK: " <> shortId (bId b)
      , "  :END:" ]

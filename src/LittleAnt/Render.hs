-- | Human-readable projections. Projections are cheap and regenerable —
-- the truth is always the event log.
module LittleAnt.Render
  ( renderMarkdown
  , renderOrg
  , renderTaskJuggler
  , renderTree
  , renderTable
  , renderCsv
  ) where

import Data.List (sortOn)
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

-- | The open forest as a real org outline: composition (break's
-- parent/child) nests as heading levels; the dependency DAG is annotated
-- per entry (:BLOCKED_BY:) — nesting it too would duplicate bricks with
-- several blockers.
renderOrg :: State -> Text
renderOrg st = T.unlines $
  [ "#+TITLE: Little Ant backlog"
  , "#+SEQ_TODO: IDEA TODO NEXT WIP | DONE"
  , "" ]
  ++ concatMap (entry 1) (openForest st)
  where
    entry depth (BrickTree b children) =
      [ T.replicate depth "*" <> " " <> keyword b <> " " <> bTitle b
      , indent <> ":PROPERTIES:"
      , indent <> ":BRICK: " <> shortId (bId b) ]
      ++ [ indent <> ":CONTEXT: " <> c | Just c <- [bContext b] ]
      ++ [ indent <> ":BLOCKED_BY: " <> refs (openBlockers st b)
         | not (null (openBlockers st b)) ]
      ++ [ indent <> ":END:" ]
      ++ concatMap (entry (depth + 1)) children
      where indent = T.replicate (depth + 1) " "
    keyword b
      | bStage b == Wip = "WIP"
      | isServable st b = "NEXT"
      | bStage b == Seed = "IDEA"
      | otherwise = "TODO"

refs :: [Brick] -> Text
refs = T.unwords . map (\b -> "#" <> shortId (bId b))

-- | The open forest for the terminal. Colon indentation — `::` per level
-- (spaces don't survive chat surfaces). Two edge kinds: composition
-- children nest bare; dependency edges nest as one-line → pointers under
-- each blocker (one line per edge, no recursive descent — the real node
-- stays at its composition slot).
renderTree :: State -> Text
renderTree st = T.unlines (concatMap (go 0) (openForest st))
  where
    go depth (BrickTree b children) =
      (indent depth <> brickOneLiner b)
        : concatMap (go (depth + 1)) children
        ++ [ indent (depth + 1) <> "→ " <> brickOneLiner d
           | d <- openDependents b ]
    indent depth =
      if depth == 0 then "" else T.replicate depth "::" <> " "
    openDependents b = sortOn bCreatedSeq
      [ d
      | did <- brickDependents st b
      , Just d <- [Map.lookup did (stBricks st)]
      , isOpen d ]

-- | Aligned columns for the terminal — plain words, light separators, no
-- box-drawing. Emojis stay out: their double display width breaks
-- alignment.
renderTable :: State -> [Brick] -> Text
renderTable st bricks = T.unlines (map line (headerCells : sepCells : rows))
  where
    headerCells = ["id", "stage", "title", "context", "blocked_by"]
    rows = map cells bricks
    cells b =
      [ shortId (bId b)
      , stageText (bStage b)
      , ellipsize 60 (bTitle b)
      , maybe "" id (bContext b)
      , refs (openBlockers st b)
      ]
    widths = foldr1 (zipWith max) (map (map T.length) (headerCells : rows))
    sepCells = map (\w -> T.replicate w "-") widths
    line cs = T.stripEnd (T.concat (zipWith pad widths cs))
    pad w t = t <> T.replicate (w - T.length t + 2) " "
    ellipsize n t = if T.length t <= n then t else T.take (n - 1) t <> "…"

-- | RFC-4180-ish CSV, same columns as the table (title untruncated).
renderCsv :: State -> [Brick] -> Text
renderCsv st bricks = T.unlines (map row (headerCells : map cells bricks))
  where
    headerCells = ["id", "stage", "title", "context", "blocked_by"]
    cells b =
      [ shortId (bId b)
      , stageText (bStage b)
      , bTitle b
      , maybe "" id (bContext b)
      , refs (openBlockers st b)
      ]
    row = T.intercalate "," . map quote
    quote t
      | T.any (`elem` (",\"\n" :: String)) t =
          "\"" <> T.replace "\"" "\"\"" t <> "\""
      | otherwise = t

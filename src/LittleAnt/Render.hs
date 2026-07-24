-- | Human-readable projections. Projections are cheap and regenerable —
-- the truth is always the event log.
module LittleAnt.Render
  ( renderMarkdown
  , renderOrg
  , renderTaskJuggler
  , renderTree
  , renderTable
  , renderCsv
  , renderHtml
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
           | d <- openDependents st b ]
    indent depth =
      if depth == 0 then "" else T.replicate depth "::" <> " "

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

-- | A self-contained HTML backlog document — no external requests, fully
-- deterministic for a given state and day, so every operator produces the
-- same artifact. Two flavours share this builder: interactive (descriptions
-- fold behind <details>, anchor navigation) and static (everything
-- expanded, print-first — the PDF path is printing this file).
renderHtml :: State -> UTCTime -> Bool -> Text
renderHtml st now interactive = T.concat
  [ "<!doctype html>\n<html lang=\"en\">\n<head>\n"
  , "<meta charset=\"utf-8\">\n"
  , "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n"
  , "<title>Little Ant \183 backlog</title>\n"
  , "<style>", htmlCss, "</style>\n</head>\n<body>\n<main>\n"
  , "<header><h1>\128028 Little Ant</h1><p class=\"gen\">backlog \183 "
  , T.pack (show (utctDay now)), "</p>\n"
  , "<nav><a href=\"#frontier\">frontier</a> \183 "
  , "<a href=\"#forest\">open forest</a></nav></header>\n"
  , statsHtml
  , frontierHtml
  , forestHtml
  , "<footer><p class=\"gen\">"
  , countLine
  , " \183 the truth is the event log</p></footer>\n"
  , "</main>\n</body>\n</html>\n"
  ]
  where
    esc = T.replace "\"" "&quot;" . T.replace ">" "&gt;"
        . T.replace "<" "&lt;" . T.replace "&" "&amp;"
    anchor b = "b-" <> shortId (bId b)
    idBadge b =
      "<code class=\"id\" id=\"" <> anchor b <> "\">#"
        <> shortId (bId b) <> "</code>"
    idLink b =
      "<a class=\"id\" href=\"#" <> anchor b <> "\">#"
        <> shortId (bId b) <> "</a>"
    stageCount s = length [ b | b <- Map.elems (stBricks st), bStage b == s ]
    statsHtml = T.concat $
      [ "<section class=\"stats\">" ]
      ++ [ stat (T.pack (show (length (frontier st)))) "\127919 frontier" ]
      ++ [ stat (T.pack (show (stageCount s))) (stageEmoji s <> " " <> stageText s)
         | s <- [Seed, Committed, Ready, Wip] ]
      ++ [ "</section>\n" ]
    stat n label =
      "<div class=\"stat\"><b>" <> n <> "</b><span>" <> label <> "</span></div>"
    countLine = T.intercalate " \183 "
      [ T.pack (show (stageCount s)) <> " " <> stageText s
      | s <- [Done, Dropped, Superseded] ]
    frontierHtml = T.concat $
      [ "<section id=\"frontier\"><h2>Focus frontier</h2>" ]
      ++ (case frontier st of
            [] -> [ "<p class=\"gen\">empty \8212 promote/ready a brick, "
                  , "resolve waits, or triage seeds</p>" ]
            fs -> [ "<ol>" ]
               ++ [ "<li>" <> stageEmoji (bStage b) <> " " <> idLink b
                      <> " <span class=\"t\">" <> esc (bTitle b)
                      <> "</span>" <> chips b <> "</li>"
                  | b <- fs ]
               ++ [ "</ol>" ])
      ++ [ "</section>\n" ]
    forestHtml = T.concat $
      [ "<section id=\"forest\"><h2>Open forest</h2>"
      , "<ul class=\"forest\">" ]
      ++ map nodeHtml (openForest st)
      ++ [ "</ul></section>\n" ]
    nodeHtml (BrickTree b children) = T.concat $
      [ "<li>", stageEmoji (bStage b), " ", idBadge b
      , " <span class=\"t\">", esc (bTitle b), "</span>", chips b
      , descHtml b ]
      ++ (let deps = [ "<li class=\"dep\">\8594 " <> stageEmoji (bStage d)
                         <> " " <> idLink d <> " <span class=\"t\">"
                         <> esc (bTitle d) <> "</span></li>"
                     | d <- openDependents st b ]
              subs = map nodeHtml children
           in if null subs && null deps
                then []
                else [ "<ul>" ] ++ subs ++ deps ++ [ "</ul>" ])
      ++ [ "</li>" ]
    chips b = T.concat $
      [ " <span class=\"chip\">" <> esc c <> "</span>" | Just c <- [bContext b] ]
      ++ [ " <span class=\"chip warn\">\9203 waiting" <> "</span>"
         | isWaiting st b ]
      ++ [ " <span class=\"chip warn\">\9940 "
             <> T.intercalate " " (map idLink (openBlockers st b)) <> "</span>"
         | not (null (openBlockers st b)) ]
    descHtml b = case bDescription b of
      Nothing -> ""
      Just d
        | interactive ->
            "<details><summary>description</summary><div class=\"desc\">"
              <> esc d <> "</div></details>"
        | otherwise -> "<div class=\"desc\">" <> esc d <> "</div>"

openDependents :: State -> Brick -> [Brick]
openDependents st b = sortOn bCreatedSeq
  [ d
  | did <- brickDependents st b
  , Just d <- [Map.lookup did (stBricks st)]
  , isOpen d ]

htmlCss :: Text
htmlCss = T.intercalate "\n"
  [ ":root{--bg:#faf9f6;--fg:#211f1c;--muted:#6f6a61;--card:#ffffff;"
  , "--line:#e4dfd6;--accent:#b45309;--warn:#9a3412}"
  , "@media(prefers-color-scheme:dark){:root{--bg:#141318;--fg:#e9e6e1;"
  , "--muted:#9b96a0;--card:#1e1c24;--line:#2e2b35;--accent:#f59e0b;"
  , "--warn:#fb923c}}"
  , "*{box-sizing:border-box}"
  , "body{margin:0;background:var(--bg);color:var(--fg);"
  , "font:15px/1.6 system-ui,-apple-system,'Segoe UI',sans-serif;"
  , "padding:2.2rem 1.2rem}"
  , "main{max-width:54rem;margin:0 auto}"
  , "h1{font-size:1.5rem;margin:0}"
  , "h2{font-size:1rem;letter-spacing:.03em;text-transform:uppercase;"
  , "color:var(--muted);border-bottom:1px solid var(--line);"
  , "padding-bottom:.35rem;margin-top:2.2rem}"
  , ".gen{color:var(--muted);font-size:.85rem;margin:.2rem 0}"
  , "nav{margin-top:.5rem;font-size:.85rem}"
  , "nav a{color:var(--accent);text-decoration:none}"
  , ".stats{display:flex;flex-wrap:wrap;gap:.7rem;margin:1.6rem 0}"
  , ".stat{background:var(--card);border:1px solid var(--line);"
  , "border-radius:.7rem;padding:.55rem 1rem;min-width:5.4rem}"
  , ".stat b{display:block;font-size:1.3rem}"
  , ".stat span{color:var(--muted);font-size:.78rem;white-space:nowrap}"
  , "ol{padding-left:1.4rem}"
  , "ol li{margin:.35rem 0}"
  , "ul.forest{list-style:none;padding-left:0}"
  , "ul.forest ul{list-style:none;padding-left:1.5rem;margin-left:.4rem;"
  , "border-left:2px solid var(--line)}"
  , "ul.forest li{margin:.4rem 0}"
  , "code.id,a.id{font:.8rem ui-monospace,'Cascadia Code',monospace;"
  , "color:var(--muted);background:var(--card);border:1px solid var(--line);"
  , "border-radius:.4rem;padding:.06rem .35rem;text-decoration:none}"
  , "a.id:hover{color:var(--accent);border-color:var(--accent)}"
  , ".chip{font-size:.72rem;border:1px solid var(--line);"
  , "border-radius:99px;padding:.08rem .5rem;color:var(--muted);"
  , "white-space:nowrap}"
  , ".chip.warn{color:var(--warn);border-color:var(--warn)}"
  , "li.dep{color:var(--muted)}"
  , "li.dep .t{font-style:italic}"
  , "details{margin:.25rem 0 .25rem 1.6rem}"
  , "summary{cursor:pointer;color:var(--accent);font-size:.8rem}"
  , ".desc{white-space:pre-wrap;background:var(--card);"
  , "border:1px solid var(--line);border-radius:.6rem;padding:.7rem .9rem;"
  , "font-size:.85rem;color:var(--muted);margin:.35rem 0 .35rem 1.6rem;"
  , "max-width:46rem}"
  , "footer{margin-top:2.5rem;border-top:1px solid var(--line);"
  , "padding-top:.8rem}"
  , "@media print{body{background:#fff;color:#000;padding:0;font-size:12px}"
  , "nav{display:none}.stat,.desc,code.id,a.id{border-color:#ccc;"
  , "background:#fff}a{color:inherit}}"
  ]

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

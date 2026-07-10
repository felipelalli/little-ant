-- | Human-readable projections. Projections are cheap and regenerable —
-- the truth is always the event log.
module LittleAnt.Render
  ( renderMarkdown
  , renderOrg
  ) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import LittleAnt.Ids (shortId)
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

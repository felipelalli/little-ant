-- | The @next@ engine: mechanism, not policy.
--
-- Core mechanisms (deterministic, knob-driven): two queues with a serve
-- ratio (drip-feed for the background), anti-starvation aging (the most
-- neglected background brick surfaces on background turns), and sticky
-- context sessions with strictness levels. Policy — which context today,
-- when to override the ratio — belongs to the operator outside.
module LittleAnt.Scheduler
  ( Choice (..)
  , NoChoice (..)
  , selectNext
  , frontier
  , arrangeByContext
  , contextMatches
  ) where

import Data.List (partition, sortOn)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import LittleAnt.Config
import LittleAnt.State
import LittleAnt.Order (totalOrder)
import LittleAnt.Types

data Choice = Choice
  { chBrick :: Brick
  , chQueue :: Text
    -- ^ "foreground" | "background"
  , chContextMatched :: Bool
  } deriving (Eq, Show)

data NoChoice
  = FrontierEmpty
  | ContextExcludedAll
    -- ^ strictness = require filtered every candidate out
  deriving (Eq, Show)

-- | The servable frontier in total order.
frontier :: State -> [Brick]
frontier st =
  totalOrder st [ b | b <- Map.elems (stBricks st), isServable st b ]

-- | Does a brick's context match the session hint? Namespaced: hint
-- @acme@ matches brick context @acme/api@.
contextMatches :: Maybe Text -> Brick -> Bool
contextMatches Nothing _ = True
contextMatches (Just hint) b = case bContext b of
  Nothing -> False
  Just ctx -> ctx == hint || (hint <> "/") `T.isPrefixOf` ctx

-- | Arrange ordered candidates according to the session's context
-- strictness. Returns the arranged list; for @require@ non-matching
-- candidates are removed entirely.
arrangeByContext :: Flow -> [Brick] -> [Brick]
arrangeByContext ses ordered = case floStrictness ses of
  SIgnore -> ordered
  SPrefer ->
    let (matching, rest) = partition (contextMatches hint) ordered
     in matching ++ rest
  SRequire -> case floContextHint ses of
    Nothing -> ordered
    Just _ -> filter (contextMatches hint) ordered
  where
    hint = floContextHint ses

-- | Pick the next focus. Deterministic given config, state and session.
selectNext :: Config -> State -> Flow -> Either NoChoice Choice
selectNext cfg st ses
  | null front = Left FrontierEmpty
  | null arranged = Left ContextExcludedAll
  | backgroundTurn, (b : _) <- aged = Right (choice b "background")
  | otherwise = case arranged of
      (b : _) -> Right (choice b "foreground")
      [] -> Left ContextExcludedAll
  where
    front = frontier st
    arranged = arrangeByContext ses front
    window = max 1 (cfgForegroundWindow cfg)
    background = drop window arranged
    ratio = cfgBackgroundServeRatio cfg
    serveNo = floServeCount ses + 1
    backgroundTurn = ratio > 0 && serveNo `mod` ratio == 0
    -- anti-starvation: the most neglected background brick first
    aged = sortOn (\b -> (bLastActivityAt b, bCreatedSeq b)) background
    choice b queue = Choice
      { chBrick = b
      , chQueue = queue
      , chContextMatched = contextMatches (floContextHint ses) b
      }

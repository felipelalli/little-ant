-- | Configurable knobs, mirroring the spec's config block. The core exposes
-- the knobs; policy (turning them) belongs to the operator.
module LittleAnt.Config
  ( Config (..)
  , defaultConfig
  , parseConfig
  ) where

import Data.Aeson
import qualified Data.Aeson.KeyMap as KM

data Config = Config
  { cfgBackgroundServeRatio :: Int
    -- ^ Every Nth serve comes from the background queue. 0 disables.
  , cfgForegroundWindow :: Int
    -- ^ Top-K of the total order = the foreground queue.
  , cfgComparisonShelfLifeDays :: Double
    -- ^ Comparisons older than this want revalidation.
  , cfgNudgeIntervalDays :: Double
    -- ^ Delegation follow-up cadence.
  , cfgWipCheckAfterHours :: Double
    -- ^ Dangling-WIP detection threshold.
  } deriving (Eq, Show)

defaultConfig :: Config
defaultConfig = Config
  { cfgBackgroundServeRatio = 5
  , cfgForegroundWindow = 5
  , cfgComparisonShelfLifeDays = 30
  , cfgNudgeIntervalDays = 3
  , cfgWipCheckAfterHours = 24
  }

-- | Parse a partial config: absent fields keep their defaults.
parseConfig :: Value -> Either String Config
parseConfig = \case
  Object o ->
    let get :: FromJSON a => Key -> a -> Either String a
        get k dflt = case KM.lookup k o of
          Nothing -> Right dflt
          Just v -> case fromJSON v of
            Success x -> Right x
            Error e -> Left (show k <> ": " <> e)
     in Config
          <$> get "background_serve_ratio" (cfgBackgroundServeRatio defaultConfig)
          <*> get "foreground_window" (cfgForegroundWindow defaultConfig)
          <*> get "comparison_shelf_life_days" (cfgComparisonShelfLifeDays defaultConfig)
          <*> get "nudge_interval_days" (cfgNudgeIntervalDays defaultConfig)
          <*> get "wip_check_after_hours" (cfgWipCheckAfterHours defaultConfig)
  _ -> Left "config must be a JSON object"

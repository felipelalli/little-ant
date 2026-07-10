-- | Temporal rules. The CLI is not a daemon: time-triggered rules fire
-- lazily, whenever a command runs (see the auto-tick in the CLI driver).
-- Deterministic given the clock reading.
module LittleAnt.Tick
  ( dueBodies
  ) where

import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Time (NominalDiffTime, UTCTime, addUTCTime)
import LittleAnt.Config
import LittleAnt.Event (Body (..))
import LittleAnt.State
import LittleAnt.Types

hours :: Double -> NominalDiffTime
hours h = realToFrac (h * 3600)

days :: Double -> NominalDiffTime
days d = realToFrac (d * 86400)

-- | All temporal events due at @now@. Deterministic order (by entity id).
dueBodies :: Config -> UTCTime -> State -> [Body]
dueBodies cfg now st =
  wipChecks ++ staleComparisons ++ dueNudges ++ taxonomyReview
  where
    -- rule DanglingWipDetected
    wipChecks =
      [ WipFlagged (bId b)
      | b <- sortOn bId (Map.elems (stBricks st))
      , bStage b == Wip
      , bWipFlagged b == Just False
      , Just started <- [bWipStartedAt b]
      , addUTCTime (hours (cfgWipCheckAfterHours cfg)) started <= now
      ]

    -- rule ComparisonGoesStale (restricted to comparisons whose endpoints
    -- are both still open — the rest cannot surface anyway)
    staleComparisons =
      [ ComparisonStale (cId c)
      | c <- sortOn cId (Map.elems (stComparisons st))
      , not (cRevalidationRequested c)
      , addUTCTime (days (cfgComparisonShelfLifeDays cfg)) (cRecordedAt c) <= now
      , openBrick (cBefore c)
      , openBrick (cAfter c)
      ]

    -- rule FollowUpComesDue
    dueNudges =
      [ NudgeDue (dId d)
      | d <- sortOn dId (Map.elems (stDelegations st))
      , dStatus d `elem` [DNotified, DNudged]
      , not (dNudgePending d)
      , Just next <- [dNextNudgeAt d]
      , next <= now
      ]

    -- rule TaxonomyReviewTriggered
    taxonomyReview =
      let tw = stTaxonomy st
       in [ TaxonomyReviewProposed (twUnreviewedOtherCount tw)
          | twUnreviewedOtherCount tw >= twReviewThreshold tw ]

    openBrick i = maybe False isOpen (Map.lookup i (stBricks st))

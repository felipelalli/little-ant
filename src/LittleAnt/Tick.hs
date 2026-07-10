-- | Temporal rules. The CLI is not a daemon: time-triggered rules fire
-- lazily, whenever a command runs (see the auto-tick in the CLI driver).
-- Deterministic given the clock reading.
module LittleAnt.Tick
  ( dueBodies
  ) where

import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (NominalDiffTime, UTCTime, addUTCTime)
import LittleAnt.Config
import LittleAnt.Event (Body (..))
import LittleAnt.Ids (mkTitleId)
import LittleAnt.State
import LittleAnt.Types

hours :: Double -> NominalDiffTime
hours h = realToFrac (h * 3600)

days :: Double -> NominalDiffTime
days d = realToFrac (d * 86400)

-- | All temporal events due at @now@. Deterministic order (by entity id).
dueBodies :: Config -> UTCTime -> State -> [Body]
dueBodies cfg now st =
  wipChecks ++ staleComparisons ++ dueNudges ++ taxonomyReview ++ orderSanity
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

    -- rules OrderSanityRoundProposed (burst) + ...DueByTime (drift):
    -- a sanity-round meta-brick is spawned when enough new bricks entered
    -- the order as mere tie-breaks (tolerance), OR when the cadence
    -- interval elapsed with something to order — priorities rot with time.
    -- While a round brick is open, no new one is proposed. The round is
    -- served like any work; the operator drives `la order --sort`.
    orderSanity =
      let ow = stOrderWatch st
          burstDue = owReadiedSinceRound ow >= owRoundThreshold ow
          driftDue = case owClockAt ow of
            Just anchor ->
              addUTCTime (days (cfgOrderSanityIntervalDays cfg)) anchor <= now
                && orderableCount >= 2
            Nothing -> False
          roundOpen = case owRoundBrick ow of
            Just b -> maybe False isOpen (Map.lookup b (stBricks st))
            Nothing -> False
          orderableCount =
            length [ b | b <- Map.elems (stBricks st), isServable st b ]
          title = "Order sanity round ("
                    <> tshow (stEventCount st) <> ")"
          bid = mkTitleId title
       in [ OrderSanityProposed bid title (owReadiedSinceRound ow)
          | burstDue || driftDue
          , not roundOpen
          , not (Map.member bid (stBricks st)) ]

    tshow = T.pack . show

    openBrick i = maybe False isOpen (Map.lookup i (stBricks st))

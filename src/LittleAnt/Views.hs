-- | JSON views: the CLI's stable output vocabulary for the LLM operator.
module LittleAnt.Views
  ( brickSummary
  , brickView
  , treeView
  , partyView
  , skipView
  , waitView
  , comparisonView
  , delegationView
  , effectView
  , linkView
  , flowView
  , rawView
  , statusView
  ) where

import Data.Aeson
import Data.Aeson.Key (fromText)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (..))
import LittleAnt.Ids (Id (..), shortId)
import LittleAnt.Scheduler (frontier)
import LittleAnt.State
import LittleAnt.Types

idFields :: Id -> [(Key, Value)]
idFields i = [ ("id", toJSON (shortId i)), ("full_id", toJSON (unId i)) ]

obj :: [(Key, Value)] -> Value
obj = object . map (uncurry (.=))

brickSummary :: Brick -> Value
brickSummary b = obj $ idFields (bId b) ++
  [ ("title", toJSON (bTitle b))
  , ("stage", toJSON (stageText (bStage b)))
  , ("kind", toJSON (kindText <$> bKind b))
  , ("context", toJSON (bContext b))
  ]

-- | The open forest, nested: each node is the full brick view plus its
-- open children (composition axis; the dependency DAG is already in each
-- brick's blockers field).
treeView :: State -> BrickTree -> Value
treeView st (BrickTree b children) = obj
  [ ("brick", brickView st b)
  , ("children", toJSON (map (treeView st) children))
  ]

brickView :: State -> Brick -> Value
brickView st b = obj $ idFields (bId b) ++
  [ ("title", toJSON (bTitle b))
  , ("description", toJSON (bDescription b))
  , ("stage", toJSON (stageText (bStage b)))
  , ("atomicity", toJSON (atomicityText (bAtomicity b)))
  , ("kind", toJSON (kindText <$> bKind b))
  , ("context", toJSON (bContext b))
  , ("weight", toJSON (bWeight b))
  , ("mode", toJSON (modeText <$> bMode b))
  , ("parent", toJSON (shortId <$> bParent b))
  , ("about", toJSON (shortId <$> bAbout b))
  , ("requester", toJSON (shortId <$> bRequester b))
  , ("estimate_hours", toJSON (bEstimateHours b))
  , ("estimate_by", toJSON (authorText <$> bEstimateBy b))
  , ("wip_started_at", toJSON (bWipStartedAt b))
  , ("wip_flagged", toJSON (bWipFlagged b))
  , ("superseded_by", toJSON (shortId <$> bSupersededBy b))
  , ("supersede_reason", toJSON (bSupersedeReason b))
  , ("created_at", toJSON (bCreatedAt b))
  , ("last_activity_at", toJSON (bLastActivityAt b))
  , ("skip_count", toJSON (bSkipCount b))
  , ("serve_count", toJSON (bServeCount b))
  , ("is_leaf", toJSON (isLeaf st b))
  , ("is_waiting", toJSON (isWaiting st b))
  , ("is_blocked", toJSON (isBlocked st b))
  , ("is_servable", toJSON (isServable st b))
  , ("open_children",
      toJSON (map (shortId . bId) (openChildren st b)))
  , ("blockers", toJSON (map shortId (brickBlockers st b)))
  ]

partyView :: Party -> Value
partyView p = obj $ idFields (pId p) ++
  [ ("name", toJSON (pName p))
  , ("party_type", toJSON (partyTypeText (pType p)))
  ]

skipView :: State -> Skip -> Value
skipView st s = obj $ idFields (skId s) ++
  [ ("brick", toJSON (shortId (skBrick s)))
  , ("brick_title", toJSON (bTitle <$> Map.lookup (skBrick s) (stBricks st)))
  , ("reason", toJSON (skipReasonText (skReason s)))
  , ("raw_text", toJSON (skRawText s))
  , ("recorded_at", toJSON (skRecordedAt s))
  ]

waitView :: State -> Wait -> Value
waitView st w = obj $ idFields (wId w) ++
  [ ("brick", toJSON (shortId (wBrick w)))
  , ("brick_title", toJSON (bTitle <$> Map.lookup (wBrick w) (stBricks st)))
  , ("on_party", toJSON (shortId <$> wOnParty w))
  , ("condition", toJSON (wConditionNote w))
  , ("resolved", toJSON (wResolved w))
  ]

comparisonView :: State -> Comparison -> Value
comparisonView st c = obj $ idFields (cId c) ++
  [ ("before", toJSON (shortId (cBefore c)))
  , ("before_title", toJSON (bTitle <$> Map.lookup (cBefore c) (stBricks st)))
  , ("after", toJSON (shortId (cAfter c)))
  , ("after_title", toJSON (bTitle <$> Map.lookup (cAfter c) (stBricks st)))
  , ("author", toJSON (authorText (cAuthor c)))
  , ("recorded_at", toJSON (cRecordedAt c))
  , ("revalidation_requested", toJSON (cRevalidationRequested c))
  ]

delegationView :: State -> Delegation -> Value
delegationView st d = obj $ idFields (dId d) ++
  [ ("brick", toJSON (shortId (dBrick d)))
  , ("brick_title", toJSON (bTitle <$> Map.lookup (dBrick d) (stBricks st)))
  , ("delegate", toJSON (shortId (dDelegate d)))
  , ("delegate_name", toJSON (pName <$> Map.lookup (dDelegate d) (stParties st)))
  , ("status", toJSON (delegationStatusText (dStatus d)))
  , ("nudge_count", toJSON (dNudgeCount d))
  , ("next_nudge_at", toJSON (dNextNudgeAt d))
  , ("nudge_pending", toJSON (dNudgePending d))
  ]

effectView :: State -> Effect -> Value
effectView st e = obj $ idFields (efId e) ++
  [ ("brick", toJSON (shortId (efBrick e)))
  , ("brick_title", toJSON (bTitle <$> Map.lookup (efBrick e) (stBricks st)))
  , ("kind", toJSON (effectKindText (efKind e)))
  , ("detail", toJSON (efDetail e))
  , ("status", toJSON (effectStatusText (efStatus e)))
  ]

linkView :: State -> SourceLink -> Value
linkView st l = obj $ idFields (slId l) ++
  [ ("brick", toJSON (shortId (slBrick l)))
  , ("brick_title", toJSON (bTitle <$> Map.lookup (slBrick l) (stBricks st)))
  , ("type", toJSON (slType l))
  , ("url", toJSON (slUrl l))
  , ("last_fingerprint", toJSON (slLastFingerprint l))
  , ("diverged", toJSON (slDiverged l))
  ]

flowView :: Flow -> Value
flowView s = obj $ idFields (floId s) ++
  [ ("context", toJSON (floContextHint s))
  , ("strictness", toJSON (strictnessText (floStrictness s)))
  , ("serve_count", toJSON (floServeCount s))
  , ("status", toJSON (flowStatusText (floStatus s)))
  , ("opened_at", toJSON (floOpenedAt s))
  ]

rawView :: RawInput -> Value
rawView r = obj $ idFields (rawId r) ++
  [ ("content", toJSON (rawContent r))
  , ("received_at", toJSON (rawReceivedAt r))
  , ("status", toJSON (rawStatusText (rawStatus r)))
  ]

-- | The opening status line's data source (exact human rendering is
-- the operator's concern — an open question in the spec).
statusView :: State -> Value
statusView st = obj
  [ ("bricks_by_stage", obj
      [ (fromText (stageText stage), toJSON (countStage stage))
      | stage <- [Seed, Committed, Ready, Wip, Done, Dropped, Superseded] ])
  , ("frontier", toJSON (map brickSummary (frontier st)))
  , ("inbox_seeds", toJSON (countStage Seed))
  , ("raw_pending", toJSON
      (length [ r | r <- Map.elems (stRawInputs st)
                  , rawStatus r == RawPending ]))
  , ("wip", toJSON
      [ brickSummary b | b <- Map.elems (stBricks st), bStage b == Wip ])
  , ("dangling_wip", toJSON
      [ brickSummary b | b <- Map.elems (stBricks st)
                       , bStage b == Wip, bWipFlagged b == Just True ])
  , ("nudges_pending", toJSON
      [ delegationView st d | d <- Map.elems (stDelegations st)
                            , dNudgePending d ])
  , ("delegations_to_notify", toJSON
      [ delegationView st d | d <- Map.elems (stDelegations st)
                            , dStatus d == DToNotify ])
  , ("effects_proposed", toJSON
      [ effectView st e | e <- Map.elems (stEffects st)
                        , efStatus e == EProposed ])
  , ("stale_comparisons", toJSON
      [ comparisonView st c
      | c <- Map.elems (stComparisons st)
      , cRevalidationRequested c
      , openId (cBefore c), openId (cAfter c) ])
  , ("diverged_sources", toJSON
      [ linkView st l | l <- Map.elems (stSourceLinks st), slDiverged l ])
  , ("open_flows", toJSON
      (map flowView
        (sortOn (Down . floOpenedAt) (openFlows st))))
  , ("unreviewed_other_skips",
      toJSON (twUnreviewedOtherCount (stTaxonomy st)))
  ]
  where
    countStage s =
      length [ b | b <- Map.elems (stBricks st), bStage b == s ]
    openId i = maybe False isOpen (Map.lookup i (stBricks st))

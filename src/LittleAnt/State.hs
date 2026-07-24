-- | State is a pure, deterministic fold over the event log.
--
-- The fold is total and tolerant: events referencing unknown entities are
-- no-ops (validation lives in "LittleAnt.Command"; a log produced through
-- commands is always coherent). Replaying the same log always yields the
-- same state.
module LittleAnt.State
  ( State (..)
  , emptyState
  , applyEvent
  , replay
    -- * Derived (the spec's derived values)
  , isOpen
  , openChildren
  , isLeaf
  , BrickTree (..)
  , openForest
  , openBlockers
  , brickWaits
  , isWaiting
  , brickBlockers
  , brickDependents
  , isBlocked
  , isServable
  , brickSources
  , brickEffects
  , comparisonById
  , openSessions
  , latestOpenSession
  ) where

import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (..))
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import LittleAnt.Event
import LittleAnt.Ids (Id (..), derivedId)
import LittleAnt.Types

data State = State
  { stBricks :: Map Id Brick
  , stParties :: Map Id Party
  , stRawInputs :: Map Id RawInput
  , stSkips :: Map Id Skip
  , stWaits :: Map Id Wait
  , stDeps :: Set (Id, Id)
    -- ^ (blocked, blocker)
  , stComparisons :: Map (Id, Id) Comparison
    -- ^ keyed by (before, after)
  , stSourceLinks :: Map Id SourceLink
  , stEffects :: Map Id Effect
  , stDelegations :: Map Id Delegation
  , stSessions :: Map Id Session
  , stTaxonomy :: TaxonomyWatch
  , stOrderWatch :: OrderWatch
  , stEventCount :: Int
  } deriving (Eq, Show)

emptyState :: State
emptyState = State
  { stBricks = Map.empty
  , stParties = Map.empty
  , stRawInputs = Map.empty
  , stSkips = Map.empty
  , stWaits = Map.empty
  , stDeps = Set.empty
  , stComparisons = Map.empty
  , stSourceLinks = Map.empty
  , stEffects = Map.empty
  , stDelegations = Map.empty
  , stSessions = Map.empty
  , stTaxonomy = TaxonomyWatch 0 5
  , stOrderWatch = OrderWatch 0 7 Nothing Nothing
  , stEventCount = 0
  }

replay :: [Event] -> State
replay = foldl (flip applyEvent) emptyState

-- --------------------------------------------------------------------------
-- Fold
-- --------------------------------------------------------------------------

applyEvent :: Event -> State -> State
applyEvent Event {..} st0 =
  let st = go st0
   in st { stEventCount = stEventCount st0 + 1 }
  where
    at = evAt
    seqNo = stEventCount st0

    newBrick :: Id -> Text -> Stage -> Brick
    newBrick bid title stage = Brick
      { bId = bid, bTitle = title, bDescription = Nothing, bStage = stage
      , bAtomicity = UnknownAtomicity
      , bKind = Nothing, bContext = Nothing, bEnergy = Nothing
      , bMode = Nothing, bParent = Nothing, bAbout = Nothing
      , bRequester = Nothing
      , bEstimateHours = Nothing, bEstimateBy = Nothing
      , bWipStartedAt = Nothing, bWipFlagged = Nothing
      , bSupersededBy = Nothing, bSupersedeReason = Nothing
      , bCreatedAt = at, bCreatedSeq = seqNo
      , bLastActivityAt = at, bSkipCount = 0, bServeCount = 0
      }

    adjustBrick :: Id -> (Brick -> Brick) -> State -> State
    adjustBrick bid f s = s { stBricks = Map.adjust f bid (stBricks s) }

    touch :: Brick -> Brick
    touch b = b { bLastActivityAt = at }

    clearWip :: Brick -> Brick
    clearWip b = b { bWipStartedAt = Nothing, bWipFlagged = Nothing }

    go :: State -> State
    go st = case evBody of
      PartyRegistered pid name ptype ->
        st { stParties = Map.insert pid (Party pid name ptype) (stParties st) }

      BrickCaptured bid title ->
        st { stBricks = Map.insert bid (newBrick bid title Seed) (stBricks st) }

      Fed rid content ->
        st { stRawInputs =
               Map.insert rid (RawInput rid content at RawPending) (stRawInputs st) }

      SeedsExtracted rid seeds ->
        let st' = st { stRawInputs =
                         Map.adjust (\r -> r { rawStatus = RawExtracted }) rid
                           (stRawInputs st) }
            ins s (bid, title) =
              s { stBricks = Map.insert bid (newBrick bid title Seed) (stBricks s) }
         in foldl ins st' seeds

      SeedPromoted bid ->
        adjustBrick bid (\b -> b { bStage = Committed }) st

      BrickKilled bid ->
        adjustBrick bid (clearWip . (\b -> b { bStage = Dropped })) st

      BrickReady bid ->
        countReadied (adjustBrick bid (\b -> b { bStage = Ready }) st)

      BrickRegressed bid ->
        adjustBrick bid (\b -> b { bStage = Committed }) st

      RequesterAttributed bid pid ->
        adjustBrick bid (\b -> b { bRequester = Just pid }) st

      BrickEnriched bid k c en m a est estBy ->
        adjustBrick bid
          (\b -> b
            { bKind = maybe (bKind b) Just k
            , bContext = maybe (bContext b) Just c
            , bEnergy = maybe (bEnergy b) Just en
            , bMode = maybe (bMode b) Just m
            , bAtomicity = maybe (bAtomicity b) id a
            , bEstimateHours = maybe (bEstimateHours b) Just est
            , bEstimateBy = maybe (bEstimateBy b) Just estBy
            }) st

      BrickDescribed bid d ->
        adjustBrick bid (\b -> b { bDescription = Just d }) st

      BrickBroken parentId parts ->
        let parent = Map.lookup parentId (stBricks st)
            child (bid, title) =
              (newBrick bid title Committed)
                { bParent = Just parentId
                , bKind = parent >>= bKind
                , bContext = parent >>= bContext
                }
            ins s p = s { stBricks = Map.insert (fst p) (child p) (stBricks s) }
         in foldl ins st parts

      BricksUnified bid intoId reason ->
        let st' = st { stComparisons = repointComparisons bid intoId (stComparisons st) }
         in adjustBrick bid
              (\b -> b { bStage = Superseded
                       , bSupersededBy = Just intoId
                       , bSupersedeReason = reason })
              st'

      BrickSuperseded bid replId title reason ->
        case Map.lookup bid (stBricks st) of
          Nothing -> st
          Just old ->
            let repl = (newBrick replId title Committed)
                  { bParent = bParent old
                  , bKind = bKind old
                  , bContext = bContext old
                  , bRequester = bRequester old
                  }
                -- copy source links to the replacement
                oldLinks = [ l | l <- Map.elems (stSourceLinks st), slBrick l == bid ]
                copyLink l =
                  let lid = derivedId "source_link" [unId replId, slUrl l]
                   in SourceLink lid replId (slType l) (slUrl l)
                        (slLastFingerprint l) (slDiverged l)
                newLinks = Map.fromList [ (slId l', l') | l' <- map copyLink oldLinks ]
                -- dependencies: blockers copied, dependents re-pointed
                deps' = Set.fromList
                  [ ( if blocked == bid then replId else blocked
                    , if blocker == bid then replId else blocker )
                  | (blocked, blocker) <- Set.toList (stDeps st) ]
                comps' = repointComparisons bid replId (stComparisons st)
             in st { stBricks =
                       Map.insert replId repl $
                         Map.adjust
                           (clearWip . (\b -> b
                             { bStage = Superseded
                             , bSupersededBy = Just replId
                             , bSupersedeReason = reason }))
                           bid (stBricks st)
                   , stSourceLinks = Map.union newLinks (stSourceLinks st)
                   , stDeps = deps'
                   , stComparisons = comps'
                   }

      SessionOpened sid ctx strict ->
        st { stSessions =
               Map.insert sid (Session sid ctx strict 0 SessOpen at)
                 (stSessions st) }

      SessionClosed sid ->
        st { stSessions =
               Map.adjust (\s -> s { sesStatus = SessClosed }) sid
                 (stSessions st) }

      FocusServed sid bid ->
        let st' = st { stSessions =
                         Map.adjust (\s -> s { sesServeCount = sesServeCount s + 1 })
                           sid (stSessions st) }
         in adjustBrick bid
              (touch . (\b -> b { bServeCount = bServeCount b + 1 })) st'

      BrickStarted bid ->
        adjustBrick bid
          (touch . (\b -> b { bStage = Wip
                            , bWipStartedAt = Just at
                            , bWipFlagged = Just False })) st

      BrickStopped bid ->
        countReadied
          (adjustBrick bid (touch . clearWip . (\b -> b { bStage = Ready })) st)

      BrickCompleted bid ->
        adjustBrick bid (touch . clearWip . (\b -> b { bStage = Done })) st

      WipFlagged bid ->
        adjustBrick bid (\b -> b { bWipFlagged = Just True }) st

      SkipTaken skid bid reason rawText ->
        let st' = st { stSkips =
                         Map.insert skid (Skip skid bid reason rawText at)
                           (stSkips st) }
            st'' = adjustBrick bid
                     (touch . (\b -> b { bSkipCount = bSkipCount b + 1 })) st'
         in if reason == OtherReason
              then st'' { stTaxonomy =
                            (stTaxonomy st'')
                              { twUnreviewedOtherCount =
                                  twUnreviewedOtherCount (stTaxonomy st'') + 1 } }
              else st''

      ClarificationDeferred bid cid title ->
        st { stBricks =
               Map.insert cid
                 ((newBrick cid title Committed)
                    { bKind = Just KMeta, bAbout = Just bid })
                 (stBricks st) }

      WaitRecorded wid bid party cond ->
        st { stWaits =
               Map.insert wid (Wait wid bid party cond False) (stWaits st) }

      WaitResolved wid ->
        st { stWaits =
               Map.adjust (\w -> w { wResolved = True }) wid (stWaits st) }

      DependencyAdded blocked blocker ->
        st { stDeps = Set.insert (blocked, blocker) (stDeps st) }

      ComparisonRecorded cid before after author ->
        st { stComparisons =
               Map.insert (before, after)
                 (Comparison cid before after author at False) $
                 Map.delete (after, before) (stComparisons st) }

      ComparisonStale cid ->
        st { stComparisons =
               Map.map
                 (\c -> if cId c == cid
                          then c { cRevalidationRequested = True }
                          else c)
                 (stComparisons st) }

      DelegationCreated did bid pid ->
        st { stDelegations =
               Map.insert did (Delegation did bid pid DToNotify 0 Nothing False)
                 (stDelegations st) }

      DelegationNoticeApproved did next ->
        st { stDelegations =
               Map.adjust
                 (\d -> d { dStatus = DNotified, dNextNudgeAt = Just next })
                 did (stDelegations st) }

      DelegationCancelled did ->
        st { stDelegations =
               Map.adjust
                 (\d -> d { dStatus = DAbandoned
                          , dNudgePending = False
                          , dNextNudgeAt = Nothing })
                 did (stDelegations st) }

      NudgeDue did ->
        st { stDelegations =
               Map.adjust (\d -> d { dNudgePending = True }) did
                 (stDelegations st) }

      NudgeApproved did next ->
        st { stDelegations =
               Map.adjust
                 (\d -> d { dStatus = DNudged
                          , dNudgeCount = dNudgeCount d + 1
                          , dNextNudgeAt = Just next
                          , dNudgePending = False })
                 did (stDelegations st) }

      NudgeDeclined did next ->
        st { stDelegations =
               Map.adjust
                 (\d -> d { dNudgePending = False, dNextNudgeAt = Just next })
                 did (stDelegations st) }

      DelegationCompleted did -> closeDelegation did DCompleted st
      DelegationRefused did -> closeDelegation did DRefused st
      DelegationAbandoned did -> closeDelegation did DAbandoned st

      EffectAdded eid bid kind detail ->
        st { stEffects =
               Map.insert eid (Effect eid bid kind detail EArmed) (stEffects st) }

      EffectProposed eid ->
        st { stEffects =
               Map.adjust (\e -> e { efStatus = EProposed }) eid (stEffects st) }

      EffectApplied eid spawned ->
        let st' = st { stEffects =
                         Map.adjust (\e -> e { efStatus = EApplied }) eid
                           (stEffects st) }
         in case spawned of
              Nothing -> st'
              Just (bid, title) ->
                let about = efBrick <$> Map.lookup eid (stEffects st)
                 in st' { stBricks =
                            Map.insert bid
                              ((newBrick bid title Committed) { bAbout = about })
                              (stBricks st') }

      EffectDeclined eid ->
        st { stEffects =
               Map.adjust (\e -> e { efStatus = EDeclined }) eid (stEffects st) }

      SourceAttached lid bid stype url ->
        st { stSourceLinks =
               Map.insert lid (SourceLink lid bid stype url Nothing False)
                 (stSourceLinks st) }

      SourceChecked lid fp ->
        st { stSourceLinks =
               Map.adjust (\l -> l { slLastFingerprint = Just fp }) lid
                 (stSourceLinks st) }

      SourceDiverged lid rid title ->
        let about = slBrick <$> Map.lookup lid (stSourceLinks st)
            st' = st { stSourceLinks =
                         Map.adjust (\l -> l { slDiverged = True }) lid
                           (stSourceLinks st) }
         in st' { stBricks =
                    Map.insert rid
                      ((newBrick rid title Committed)
                         { bKind = Just KMeta, bAbout = about })
                      (stBricks st') }

      DivergenceResolved lid fp ->
        st { stSourceLinks =
               Map.adjust
                 (\l -> l { slDiverged = False, slLastFingerprint = Just fp })
                 lid (stSourceLinks st) }

      TaxonomyReviewProposed _ ->
        st { stTaxonomy = (stTaxonomy st) { twUnreviewedOtherCount = 0 } }

      OrderSanityProposed bid title _ ->
        let st' = st { stOrderWatch =
                         (stOrderWatch st)
                           { owReadiedSinceRound = 0
                           , owClockAt = Just at
                           , owRoundBrick = Just bid
                           } }
         in st' { stBricks =
                    Map.insert bid
                      ((newBrick bid title Committed) { bKind = Just KMeta })
                      (stBricks st') }

    countReadied s =
      let ow = stOrderWatch s
       in s { stOrderWatch = ow
                { owReadiedSinceRound = owReadiedSinceRound ow + 1
                , owClockAt = case owClockAt ow of
                    Nothing -> Just at
                    anchored -> anchored
                } }

    closeDelegation did status s =
      s { stDelegations =
            Map.adjust
              (\d -> d { dStatus = status
                       , dNudgePending = False
                       , dNextNudgeAt = Nothing })
              did (stDelegations s) }

-- | Re-point comparison edges from one brick to another, eliminating pairs
-- that would become self-comparisons. On a key conflict the target's own
-- existing comparison wins (deterministic).
repointComparisons
  :: Id -> Id -> Map (Id, Id) Comparison -> Map (Id, Id) Comparison
repointComparisons from to comps =
  let involves (before, after) = before == from || after == from
      (involving, others) =
        Map.partitionWithKey (\k _ -> involves k) comps
      repointed =
        [ ((before', after'), c { cBefore = before', cAfter = after' })
        | ((before, after), c) <- Map.toList involving
        , let before' = if before == from then to else before
        , let after' = if after == from then to else after
        , before' /= after' -- would become a self-comparison: eliminate
        ]
      insertIfAbsent acc (k, v)
        | Map.member k acc = acc -- the target's own comparison wins
        | otherwise = Map.insert k v acc
   in foldl insertIfAbsent others repointed

-- --------------------------------------------------------------------------
-- Derived values (mirroring the spec)
-- --------------------------------------------------------------------------

isOpen :: Brick -> Bool
isOpen b = bStage b `elem` [Seed, Committed, Ready, Wip]

openChildren :: State -> Brick -> [Brick]
openChildren st b =
  [ c | c <- Map.elems (stBricks st)
      , bParent c == Just (bId b)
      , isOpen c ]

isLeaf :: State -> Brick -> Bool
isLeaf st = null . openChildren st

-- | The open bricks as a forest along the composition axis (parent/child
-- from break). A child whose parent is closed roots itself. Siblings and
-- roots keep creation order.
data BrickTree = BrickTree Brick [BrickTree]
  deriving (Eq, Show)

openForest :: State -> [BrickTree]
openForest st = map grow roots
  where
    open = sortOn bCreatedSeq [ b | b <- Map.elems (stBricks st), isOpen b ]
    openIds = Set.fromList (map bId open)
    rootish b = case bParent b of
      Nothing -> True
      Just p -> not (Set.member p openIds)
    roots = filter rootish open
    grow b = BrickTree b [ grow c | c <- open, bParent c == Just (bId b) ]

-- | Blockers (dependency DAG) that are still open, in creation order.
openBlockers :: State -> Brick -> [Brick]
openBlockers st b = sortOn bCreatedSeq
  [ blocker
  | bid <- brickBlockers st b
  , Just blocker <- [Map.lookup bid (stBricks st)]
  , isOpen blocker ]

brickWaits :: State -> Brick -> [Wait]
brickWaits st b = [ w | w <- Map.elems (stWaits st), wBrick w == bId b ]

isWaiting :: State -> Brick -> Bool
isWaiting st b = any (not . wResolved) (brickWaits st b)

-- | Dependencies where this brick is blocked: (blocked, blocker) pairs.
brickBlockers :: State -> Brick -> [Id]
brickBlockers st b =
  [ blocker | (blocked, blocker) <- Set.toList (stDeps st), blocked == bId b ]

-- | Dependencies where this brick blocks others.
brickDependents :: State -> Brick -> [Id]
brickDependents st b =
  [ blocked | (blocked, blocker) <- Set.toList (stDeps st), blocker == bId b ]

isBlocked :: State -> Brick -> Bool
isBlocked st b =
  any
    (\blocker -> maybe False isOpen (Map.lookup blocker (stBricks st)))
    (brickBlockers st b)

-- | The servable frontier: ready, an actionable leaf, not waiting on the
-- world, not blocked by open work.
isServable :: State -> Brick -> Bool
isServable st b =
  bStage b == Ready
    && isLeaf st b
    && not (isWaiting st b)
    && not (isBlocked st b)

brickSources :: State -> Brick -> [SourceLink]
brickSources st b =
  [ l | l <- Map.elems (stSourceLinks st), slBrick l == bId b ]

brickEffects :: State -> Brick -> [Effect]
brickEffects st b =
  [ e | e <- Map.elems (stEffects st), efBrick e == bId b ]

comparisonById :: State -> Id -> Maybe Comparison
comparisonById st cid =
  case [ c | c <- Map.elems (stComparisons st), cId c == cid ] of
    (c : _) -> Just c
    [] -> Nothing

openSessions :: State -> [Session]
openSessions st =
  [ s | s <- Map.elems (stSessions st), sesStatus s == SessOpen ]

-- | The most recently opened session that is still open.
latestOpenSession :: State -> Maybe Session
latestOpenSession st =
  case sortOn (Down . sesOpenedAt) (openSessions st) of
    (s : _) -> Just s
    [] -> Nothing

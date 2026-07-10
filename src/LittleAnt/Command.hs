-- | Commands: validation + event production. One function per spec rule
-- with an external stimulus. Commands never mutate anything — they inspect
-- state and return the events that would extend the log ('Left' when a
-- precondition fails, mirroring the spec's @requires@ clauses).
module LittleAnt.Command
  ( CmdError (..)
  , notFound
  , cmdPartyAdd
  , cmdCapture
  , cmdRawCapture
  , cmdExtract
  , cmdPromote
  , cmdKill
  , cmdReady
  , cmdRequester
  , cmdEnrich
  , cmdBreak
  , cmdUnify
  , cmdSupersede
  , cmdSessionOpen
  , cmdSessionClose
  , cmdNext
  , cmdStart
  , cmdStop
  , cmdDone
  , cmdSkip
  , cmdClarify
  , cmdWait
  , cmdWaitResolve
  , cmdDepAdd
  , cmdCompare
  , cmdDelegate
  , cmdDelegationNotice
  , cmdDelegationCancel
  , cmdNudgeApprove
  , cmdNudgeDecline
  , cmdDelegationOutcome
  , cmdEffectAdd
  , cmdEffectApprove
  , cmdEffectDecline
  , cmdSourceAttach
  , cmdSourceCheck
  , cmdSourceResolve
    -- * Resolvers (shared with read-only CLI commands)
  , resolveBrick
  , resolveParty
  , resolveDelegation
  , resolveEffect
  , resolveWait
  , resolveLink
  , resolveSession
  , resolveRaw
  ) where

import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (NominalDiffTime, UTCTime, addUTCTime)
import LittleAnt.Config
import LittleAnt.Event (Body (..))
import LittleAnt.Ids
import LittleAnt.Order (hasPath)
import LittleAnt.Scheduler (Choice (..), NoChoice (..), selectNext)
import LittleAnt.State
import LittleAnt.Types

data CmdError = CmdError
  { ceCode :: Text
  , ceMessage :: Text
  , ceHint :: Maybe Text
  } deriving (Eq, Show)

precondition :: Text -> Maybe Text -> CmdError
precondition = CmdError "precondition_failed"

notFound :: Text -> Text -> CmdError
notFound what ref = CmdError "ref_not_found"
  (what <> " not found: " <> ref)
  (Just ("use `la ls` (or the matching list command) to find the right " <> what))

need :: Bool -> Text -> Maybe Text -> Either CmdError ()
need True _ _ = Right ()
need False msg hint = Left (precondition msg hint)

tshow :: Show a => a -> Text
tshow = T.pack . show

nextSeq :: State -> Text
nextSeq = tshow . stEventCount

daysToDiff :: Double -> NominalDiffTime
daysToDiff d = realToFrac (d * 86400)

-- --------------------------------------------------------------------------
-- Reference resolution
-- --------------------------------------------------------------------------

resolveIn :: Text -> Map.Map Id a -> Text -> Either CmdError a
resolveIn what m ref =
  case resolvePrefix ref (Map.keys m) of
    Right i -> case Map.lookup i m of
      Just a -> Right a
      Nothing -> Left (notFound what ref)
    Left (RefNotFound _) -> Left (notFound what ref)
    Left (RefAmbiguous _ ids) -> Left $ CmdError "ref_ambiguous"
      ("ambiguous " <> what <> " reference: " <> ref)
      (Just ("candidates: " <> T.intercalate ", " (map shortId ids)))

resolveBrick :: State -> Text -> Either CmdError Brick
resolveBrick st = resolveIn "brick" (stBricks st)

-- | Parties resolve by id prefix, or by unique case-insensitive name.
resolveParty :: State -> Text -> Either CmdError Party
resolveParty st ref =
  case resolveIn "party" (stParties st) ref of
    Right p -> Right p
    Left e ->
      let named =
            [ p | p <- Map.elems (stParties st)
                , T.toLower (pName p) == T.toLower (T.strip ref) ]
       in case named of
            [p] -> Right p
            _ -> Left e

resolveDelegation :: State -> Text -> Either CmdError Delegation
resolveDelegation st = resolveIn "delegation" (stDelegations st)

resolveEffect :: State -> Text -> Either CmdError Effect
resolveEffect st = resolveIn "effect" (stEffects st)

resolveWait :: State -> Text -> Either CmdError Wait
resolveWait st = resolveIn "wait" (stWaits st)

resolveLink :: State -> Text -> Either CmdError SourceLink
resolveLink st = resolveIn "source link" (stSourceLinks st)

resolveSession :: State -> Text -> Either CmdError Session
resolveSession st = resolveIn "session" (stSessions st)

resolveRaw :: State -> Text -> Either CmdError RawInput
resolveRaw st = resolveIn "raw input" (stRawInputs st)

-- --------------------------------------------------------------------------
-- Title identity
-- --------------------------------------------------------------------------

-- | A title collision is a feature: it forces a more specific title.
freshTitle :: State -> [Id] -> Text -> Either CmdError (Id, Text)
freshTitle st alsoTaken title = do
  let t = T.strip title
  need (not (T.null t)) "title must not be empty" Nothing
  let i = mkTitleId t
  if Map.member i (stBricks st) || i `elem` alsoTaken
    then Left $ CmdError "title_collision"
      ("a brick with this exact title already exists: " <> t)
      (Just "choose a more specific title — e.g. add a scope or a date")
    else Right (i, t)

freshTitles :: State -> [Text] -> Either CmdError [(Id, Text)]
freshTitles st = go []
  where
    go _ [] = Right []
    go taken (t : ts) = do
      (i, t') <- freshTitle st taken t
      rest <- go (i : taken) ts
      pure ((i, t') : rest)

-- --------------------------------------------------------------------------
-- Capture and triage
-- --------------------------------------------------------------------------

cmdPartyAdd :: State -> Text -> PartyType -> Either CmdError [Body]
cmdPartyAdd st name ptype = do
  let n = T.strip name
  need (not (T.null n)) "party name must not be empty" Nothing
  let i = mkTitleId n
  need (not (Map.member i (stParties st)))
    ("a party with this exact name already exists: " <> n)
    (Just "choose a more specific name")
  pure [PartyRegistered i n ptype]

-- rule SeedCaptured
cmdCapture :: State -> Text -> Either CmdError [Body]
cmdCapture st title = do
  (i, t) <- freshTitle st [] title
  pure [BrickCaptured i t]

-- rule RawInputCaptured
cmdRawCapture :: State -> Text -> Either CmdError [Body]
cmdRawCapture st content = do
  need (not (T.null (T.strip content))) "raw content must not be empty" Nothing
  let rid = derivedId "raw" [nextSeq st]
  pure [RawCaptured rid content]

-- rule SeedsExtracted (extraction may yield zero seeds)
cmdExtract :: State -> Text -> [Text] -> Either CmdError [Body]
cmdExtract st rawRef titles = do
  raw <- resolveRaw st rawRef
  need (rawStatus raw == RawPending)
    "raw input already extracted" Nothing
  seeds <- freshTitles st titles
  pure [SeedsExtracted (rawId raw) seeds]

-- rule SeedPromoted
cmdPromote :: State -> Text -> Either CmdError [Body]
cmdPromote st ref = do
  b <- resolveBrick st ref
  need (bStage b == Seed)
    ("brick is not a seed (stage: " <> stageText (bStage b) <> ")") Nothing
  pure [SeedPromoted (bId b)]

-- rule BrickKilled
cmdKill :: State -> Text -> Either CmdError [Body]
cmdKill st ref = do
  b <- resolveBrick st ref
  need (isOpen b)
    ("brick is already in a final stage: " <> stageText (bStage b)) Nothing
  pure [BrickKilled (bId b)]

-- rule BrickMarkedReady (definition-of-ready per kind is an open question;
-- the operator prepares bricks via drip meta-work)
cmdReady :: State -> Text -> Either CmdError [Body]
cmdReady st ref = do
  b <- resolveBrick st ref
  need (bStage b == Committed)
    ("brick is not committed (stage: " <> stageText (bStage b) <> ")") Nothing
  pure [BrickReady (bId b)]

-- rule RequesterAttributed
cmdRequester :: State -> Text -> Text -> Either CmdError [Body]
cmdRequester st ref partyRef = do
  b <- resolveBrick st ref
  p <- resolveParty st partyRef
  pure [RequesterAttributed (bId b) (pId p)]

-- rule BrickEnriched (lazy classification: metadata in drips, never forms)
cmdEnrich
  :: State -> Text -> Maybe Kind -> Maybe Text -> Maybe Double
  -> Maybe Mode -> Maybe Atomicity -> Maybe Double -> Maybe Author
  -> Either CmdError [Body]
cmdEnrich st ref k c en m a est estBy = do
  b <- resolveBrick st ref
  need (isOpen b)
    ("brick is in a final stage: " <> stageText (bStage b)) Nothing
  need (any' [ k /= Nothing, c /= Nothing, en /= Nothing
             , m /= Nothing, a /= Nothing, est /= Nothing ])
    "nothing to enrich"
    (Just "pass at least one of --kind --context --energy --mode --atomicity --estimate")
  need (maybe True (\e -> e >= 0 && e <= 1) en)
    "energy must be within 0..1" Nothing
  need (maybe True (> 0) est)
    "estimate must be positive (hours)" Nothing
  let estBy' = if est /= Nothing && estBy == Nothing then Just Human else estBy
  pure [BrickEnriched (bId b) k c en m a est estBy']
  where any' = or

-- --------------------------------------------------------------------------
-- Composition
-- --------------------------------------------------------------------------

-- rule BrickBroken (lazy decomposition)
cmdBreak :: State -> Text -> [Text] -> Either CmdError [Body]
cmdBreak st ref titles = do
  b <- resolveBrick st ref
  need (bAtomicity b /= Atomic)
    "brick is atomic: it cannot be broken"
    (Just "offer a learning brick or delegation instead")
  need (bStage b `elem` [Committed, Ready, Wip])
    ("brick cannot be broken at stage " <> stageText (bStage b)) Nothing
  need (not (null titles)) "provide at least one part title" Nothing
  parts <- freshTitles st titles
  pure [BrickBroken (bId b) parts]

-- rule BricksUnified
cmdUnify :: State -> Text -> Text -> Maybe Text -> Either CmdError [Body]
cmdUnify st ref intoRef reason = do
  b <- resolveBrick st ref
  into <- resolveBrick st intoRef
  need (bId b /= bId into) "cannot unify a brick with itself" Nothing
  need (bStage b `elem` [Committed, Ready])
    ("brick cannot be unified at stage " <> stageText (bStage b)) Nothing
  need (isOpen into)
    ("target brick is in a final stage: " <> stageText (bStage into)) Nothing
  pure [BricksUnified (bId b) (bId into) reason]

-- rule BrickSuperseded (keep the goal, replace the method)
cmdSupersede :: State -> Text -> Text -> Maybe Text -> Either CmdError [Body]
cmdSupersede st ref title reason = do
  b <- resolveBrick st ref
  need (bStage b `elem` [Committed, Ready, Wip])
    ("brick cannot be superseded at stage " <> stageText (bStage b)) Nothing
  (i, t) <- freshTitle st [] title
  pure [BrickSuperseded (bId b) i t reason]

-- --------------------------------------------------------------------------
-- Focus loop
-- --------------------------------------------------------------------------

-- rule SessionOpened
cmdSessionOpen :: State -> Maybe Text -> Strictness -> Either CmdError [Body]
cmdSessionOpen st ctx strict = do
  let sid = derivedId "session" [nextSeq st]
  pure [SessionOpened sid ctx strict]

-- rule SessionClosed
cmdSessionClose :: State -> Maybe Text -> Either CmdError [Body]
cmdSessionClose st mref = do
  ses <- currentSession st mref
  need (sesStatus ses == SessOpen) "session is already closed" Nothing
  pure [SessionClosed (sesId ses)]

currentSession :: State -> Maybe Text -> Either CmdError Session
currentSession st = \case
  Just ref -> resolveSession st ref
  Nothing -> case latestOpenSession st of
    Just s -> Right s
    Nothing -> Left $ CmdError "no_open_session"
      "no open focus session"
      (Just "run: la session open [--context C] [--strictness prefer]")

-- rule FocusServed
cmdNext
  :: Config -> State -> Maybe Text
  -> Either CmdError ([Body], Either NoChoice Choice)
cmdNext cfg st mref = do
  ses <- currentSession st mref
  case selectNext cfg st ses of
    Right choice ->
      pure ([FocusServed (sesId ses) (bId (chBrick choice))], Right choice)
    Left nc -> pure ([], Left nc)

-- rule BrickStarted
cmdStart :: State -> Text -> Either CmdError [Body]
cmdStart st ref = do
  b <- resolveBrick st ref
  need (bStage b == Ready)
    ("brick is not ready (stage: " <> stageText (bStage b) <> ")") Nothing
  pure [BrickStarted (bId b)]

-- rule BrickStopped
cmdStop :: State -> Text -> Either CmdError [Body]
cmdStop st ref = do
  b <- resolveBrick st ref
  need (bStage b == Wip)
    ("brick is not in progress (stage: " <> stageText (bStage b) <> ")") Nothing
  pure [BrickStopped (bId b)]

-- rules BrickCompleted + CompletionEffectsFired: completing a brick fires
-- its armed effects — spawn effects apply immediately (internal), the rest
-- stop at proposed until a human decides (NoSilentExternalActions).
cmdDone :: State -> Text -> Either CmdError [Body]
cmdDone st ref = do
  b <- resolveBrick st ref
  need (bStage b `elem` [Ready, Wip])
    ("brick cannot be completed at stage " <> stageText (bStage b)) Nothing
  let armed = sortOn efId
        [ e | e <- brickEffects st b, efStatus e == EArmed ]
      spawns = [ e | e <- armed, efKind e == Spawn ]
      others = [ e | e <- armed, efKind e /= Spawn ]
  spawned <- freshTitles st (map efDetail spawns)
  let spawnEvents =
        [ EffectApplied (efId e) (Just s) | (e, s) <- zip spawns spawned ]
      proposeEvents = [ EffectProposed (efId e) | e <- others ]
  pure (BrickCompleted (bId b) : spawnEvents ++ proposeEvents)

-- --------------------------------------------------------------------------
-- Skip flow (the heart of the system)
-- --------------------------------------------------------------------------

-- rule SkipTaken + the per-reason reaction rules. The returned reaction tag
-- tells the operator which flow to drive next; the raw utterance is always
-- preserved in the event.
cmdSkip
  :: State -> Text -> SkipReason -> Maybe Text
  -> Either CmdError ([Body], Text)
cmdSkip st ref reason rawText = do
  b <- resolveBrick st ref
  need (bStage b == Ready)
    ("only a served (ready) brick can be skipped; stage: "
      <> stageText (bStage b)) Nothing
  need (reason /= OtherReason || rawText /= Nothing)
    "a skip with reason `other` must carry the raw text"
    (Just "pass --text with what the human actually said")
  let skid = derivedId "skip" [nextSeq st]
      skipEv = SkipTaken skid (bId b) reason rawText
  pure $ case reason of
    Hard ->
      ( [skipEv]
      , if bAtomicity b == Atomic
          then "learn_or_delegate_offered"
          else "decomposition_offered" )
    Vague -> ([skipEv, BrickRegressed (bId b)], "clarification_offered")
    NotPriority -> ([skipEv], "priority_challenge_issued")
    WaitingReason -> ([skipEv], "wait_details_requested")
    Tired -> ([skipEv], "recovery_options_offered")
    Meh -> ([skipEv], "tiny_step_proposed")
    KillReason -> ([skipEv, BrickKilled (bId b)], "killed")
    Alternatives -> ([skipEv], "alternatives_requested")
    OtherReason -> ([skipEv], "recorded_as_other")

-- rule ClarificationDeferred (vague gets specified, not broken)
cmdClarify :: State -> Text -> Text -> Either CmdError [Body]
cmdClarify st ref title = do
  b <- resolveBrick st ref
  need (bStage b == Committed)
    ("brick is not awaiting clarification (stage: "
      <> stageText (bStage b) <> ")") Nothing
  (i, t) <- freshTitle st [] title
  pure [ClarificationDeferred (bId b) i t]

-- rule WaitRecorded (people and world conditions; waiting on another brick
-- is a dependency, not a wait)
cmdWait :: State -> Text -> Maybe Text -> Maybe Text -> Either CmdError [Body]
cmdWait st ref mparty mcond = do
  b <- resolveBrick st ref
  need (mparty /= Nothing || mcond /= Nothing)
    "a wait needs a party or a condition"
    (Just "waiting on another brick? use `la dep add` instead")
  pid <- traverse (fmap pId . resolveParty st) mparty
  let wid = derivedId "wait" [nextSeq st]
  pure [WaitRecorded wid (bId b) pid mcond]

-- rule WaitResolved
cmdWaitResolve :: State -> Text -> Either CmdError [Body]
cmdWaitResolve st ref = do
  w <- resolveWait st ref
  need (not (wResolved w)) "wait is already resolved" Nothing
  pure [WaitResolved (wId w)]

-- --------------------------------------------------------------------------
-- Dependencies and prioritisation
-- --------------------------------------------------------------------------

depEdges :: State -> Set.Set (Id, Id)
depEdges st = Set.fromList
  [ (blocker, blocked) | (blocked, blocker) <- Set.toList (stDeps st) ]

-- rule DependencyAdded (the graph must stay acyclic — cycle detection is
-- exactly the algorithmic work the spec delegates to the implementation)
cmdDepAdd :: State -> Text -> Text -> Either CmdError [Body]
cmdDepAdd st blockedRef blockerRef = do
  blocked <- resolveBrick st blockedRef
  blocker <- resolveBrick st blockerRef
  need (bId blocked /= bId blocker)
    "a brick cannot depend on itself" Nothing
  need (not (Set.member (bId blocked, bId blocker) (stDeps st)))
    "this dependency already exists" Nothing
  need (not (hasPath (depEdges st) (bId blocked) (bId blocker)))
    "this dependency would create a cycle"
    (Just "the blocker already (transitively) depends on the blocked brick")
  pure [DependencyAdded (bId blocked) (bId blocker)]

-- rule ComparisonRecorded. Human precedence: an AI-authored comparison never
-- displaces a human-authored one — in either direction.
cmdCompare :: State -> Text -> Text -> Author -> Either CmdError [Body]
cmdCompare st earlierRef laterRef author = do
  earlier <- resolveBrick st earlierRef
  later <- resolveBrick st laterRef
  need (bId earlier /= bId later)
    "cannot compare a brick with itself" Nothing
  -- a question that would violate a dependency is never asked
  need (not (hasPath (depEdges st) (bId later) (bId earlier)))
    "this comparison contradicts the dependency order"
    (Just "the later brick transitively blocks the earlier one")
  let same = Map.lookup (bId earlier, bId later) (stComparisons st)
      reverse' = Map.lookup (bId later, bId earlier) (stComparisons st)
      humanOwned c = cAuthor c == Human
  need (author == Human || not (any humanOwned same))
    "human precedence: a human already recorded this comparison" Nothing
  need (author == Human || not (any humanOwned reverse'))
    "human precedence: a human recorded the opposite comparison" Nothing
  let cid = derivedId "comparison" [unId (bId earlier), unId (bId later)]
  pure [ComparisonRecorded cid (bId earlier) (bId later) author]

-- --------------------------------------------------------------------------
-- Delegation
-- --------------------------------------------------------------------------

-- rules BrickDelegated + DelegationNoticeDrafted
cmdDelegate :: State -> Text -> Text -> Either CmdError [Body]
cmdDelegate st ref partyRef = do
  b <- resolveBrick st ref
  p <- resolveParty st partyRef
  let did = derivedId "delegation" [nextSeq st]
  pure [DelegationCreated did (bId b) (pId p)]

-- rule DelegationNoticeApproved
cmdDelegationNotice :: Config -> State -> UTCTime -> Text -> Either CmdError [Body]
cmdDelegationNotice cfg st now ref = do
  d <- resolveDelegation st ref
  need (dStatus d == DToNotify)
    ("delegation is not awaiting notice (status: "
      <> delegationStatusText (dStatus d) <> ")") Nothing
  let next = addUTCTime (daysToDiff (cfgNudgeIntervalDays cfg)) now
  pure [DelegationNoticeApproved (dId d) next]

-- rule DelegationCancelled
cmdDelegationCancel :: State -> Text -> Either CmdError [Body]
cmdDelegationCancel st ref = do
  d <- resolveDelegation st ref
  need (dStatus d == DToNotify)
    "only a delegation awaiting notice can be cancelled" Nothing
  pure [DelegationCancelled (dId d)]

-- rule NudgeApproved
cmdNudgeApprove :: Config -> State -> UTCTime -> Text -> Either CmdError [Body]
cmdNudgeApprove cfg st now ref = do
  d <- resolveDelegation st ref
  need (dNudgePending d) "no nudge is pending for this delegation" Nothing
  need (dStatus d `elem` [DNotified, DNudged])
    ("delegation status: " <> delegationStatusText (dStatus d)) Nothing
  let next = addUTCTime (daysToDiff (cfgNudgeIntervalDays cfg)) now
  pure [NudgeApproved (dId d) next]

-- rule NudgeDeclined
cmdNudgeDecline :: Config -> State -> UTCTime -> Text -> Either CmdError [Body]
cmdNudgeDecline cfg st now ref = do
  d <- resolveDelegation st ref
  need (dNudgePending d) "no nudge is pending for this delegation" Nothing
  let next = addUTCTime (daysToDiff (cfgNudgeIntervalDays cfg)) now
  pure [NudgeDeclined (dId d) next]

-- rules DelegationCompleted / DelegationRefused / DelegationAbandoned
cmdDelegationOutcome :: State -> Text -> Text -> Either CmdError [Body]
cmdDelegationOutcome st ref outcome = do
  d <- resolveDelegation st ref
  need (dStatus d `elem` [DNotified, DNudged])
    ("delegation cannot be closed from status "
      <> delegationStatusText (dStatus d)) Nothing
  ev <- case outcome of
    "completed" -> Right (DelegationCompleted (dId d))
    "refused" -> Right (DelegationRefused (dId d))
    "abandoned" -> Right (DelegationAbandoned (dId d))
    other -> Left $ precondition
      ("unknown delegation outcome: " <> other)
      (Just "one of: completed, refused, abandoned")
  pure [ev]

-- --------------------------------------------------------------------------
-- Completion effects
-- --------------------------------------------------------------------------

-- rule CompletionEffectAdded
cmdEffectAdd :: State -> Text -> EffectKind -> Text -> Either CmdError [Body]
cmdEffectAdd st ref kind detail = do
  b <- resolveBrick st ref
  need (isOpen b)
    ("brick is in a final stage: " <> stageText (bStage b)) Nothing
  need (not (T.null (T.strip detail))) "effect detail must not be empty" Nothing
  let eid = derivedId "effect" [nextSeq st]
  pure [EffectAdded eid (bId b) kind detail]

-- rule ExternalActionApproved (execution goes through the operator's
-- WriteBackExecutor; the core only records the human decision)
cmdEffectApprove :: State -> Text -> Either CmdError [Body]
cmdEffectApprove st ref = do
  e <- resolveEffect st ref
  need (efStatus e == EProposed)
    ("effect is not awaiting approval (status: "
      <> effectStatusText (efStatus e) <> ")") Nothing
  pure [EffectApplied (efId e) Nothing]

-- rule ExternalActionDeclined
cmdEffectDecline :: State -> Text -> Either CmdError [Body]
cmdEffectDecline st ref = do
  e <- resolveEffect st ref
  need (efStatus e == EProposed)
    ("effect is not awaiting approval (status: "
      <> effectStatusText (efStatus e) <> ")") Nothing
  pure [EffectDeclined (efId e)]

-- --------------------------------------------------------------------------
-- External sources
-- --------------------------------------------------------------------------

-- rule SourceAttached
cmdSourceAttach :: State -> Text -> Text -> Either CmdError [Body]
cmdSourceAttach st ref uri = do
  b <- resolveBrick st ref
  need (not (T.null (T.strip uri))) "source ref must not be empty" Nothing
  let lid = derivedId "source_link" [unId (bId b), uri]
  need (not (Map.member lid (stSourceLinks st)))
    "this source is already attached to this brick" Nothing
  pure [SourceAttached lid (bId b) uri]

-- rule SourceChecked: divergence never auto-resolves — it becomes a
-- reconcile meta-brick served like any other work.
cmdSourceCheck :: State -> Text -> Text -> Either CmdError [Body]
cmdSourceCheck st ref fingerprint = do
  l <- resolveLink st ref
  need (not (slDiverged l))
    "source is diverged; reconcile first"
    (Just "after reconciling, run: la source resolve")
  let drifted = case slLastFingerprint l of
        Just old -> old /= fingerprint
        Nothing -> False
  if not drifted
    then pure [SourceChecked (slId l) fingerprint]
    else do
      let brickTitle = maybe (unId (slBrick l)) bTitle
            (Map.lookup (slBrick l) (stBricks st))
          base = "Reconcile: " <> brickTitle <> " vs " <> slRef l
          candidate =
            if Map.member (mkTitleId base) (stBricks st)
              then base <> " (" <> shortId (slId l) <> ")"
              else base
      (rid, title) <- freshTitle st [] candidate
      pure [SourceDiverged (slId l) rid title]

-- rule DivergenceResolved
cmdSourceResolve :: State -> Text -> Text -> Either CmdError [Body]
cmdSourceResolve st ref fingerprint = do
  l <- resolveLink st ref
  need (slDiverged l) "source is not diverged" Nothing
  pure [DivergenceResolved (slId l) fingerprint]

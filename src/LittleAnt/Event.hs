-- | The event log schema: the single source of truth.
--
-- Events are persisted as JSONL, append-only. This module owns the (stable)
-- wire format: manual To/FromJSON so the schema never drifts silently with
-- refactors. Unknown event types are tolerated on read (forward
-- compatibility) — the loader skips them with a warning.
module LittleAnt.Event
  ( Event (..)
  , Body (..)
  , eventToJSON
  , eventFromJSON
  , computeEventId
  , bodyType
  ) where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import LittleAnt.Ids (Id (..))
import LittleAnt.Types

data Event = Event
  { evId :: Text
    -- ^ Intrinsic id: sha256 of (at, type, data). Position-independent so a
    -- future multi-device sync can treat the log as a set of events.
  , evAt :: UTCTime
  , evBody :: Body
  } deriving (Eq, Show)

-- | Event payloads. Positional fields; the comment names them.
data Body
  = PartyRegistered Id Text PartyType
    -- ^ party, name, party_type
  | BrickCaptured Id Text
    -- ^ brick, title  (a new seed)
  | RawCaptured Id Text
    -- ^ raw, content
  | SeedsExtracted Id [(Id, Text)]
    -- ^ raw, seeds (brick, title) — may be empty
  | SeedPromoted Id
    -- ^ brick
  | BrickKilled Id
    -- ^ brick
  | BrickReady Id
    -- ^ brick
  | BrickRegressed Id
    -- ^ brick (ready -> committed; e.g. skip(vague))
  | RequesterAttributed Id Id
    -- ^ brick, party
  | BrickEnriched Id (Maybe Kind) (Maybe Text) (Maybe Double) (Maybe Mode) (Maybe Atomicity)
    -- ^ brick, kind, context, energy, mode, atomicity (absent = unchanged)
  | BrickBroken Id [(Id, Text)]
    -- ^ parent, parts (brick, title)
  | BricksUnified Id Id (Maybe Text)
    -- ^ brick, into, reason
  | BrickSuperseded Id Id Text (Maybe Text)
    -- ^ brick, replacement, replacement title, reason
  | SessionOpened Id (Maybe Text) Strictness
    -- ^ session, context hint, strictness
  | SessionClosed Id
    -- ^ session
  | FocusServed Id Id
    -- ^ session, brick
  | BrickStarted Id
    -- ^ brick
  | BrickStopped Id
    -- ^ brick
  | BrickCompleted Id
    -- ^ brick
  | WipFlagged Id
    -- ^ brick (dangling wip detected)
  | SkipTaken Id Id SkipReason (Maybe Text)
    -- ^ skip, brick, reason, raw text
  | ClarificationDeferred Id Id Text
    -- ^ brick, clarify meta-brick, clarify title
  | WaitRecorded Id Id (Maybe Id) (Maybe Text)
    -- ^ wait, brick, on party, condition note
  | WaitResolved Id
    -- ^ wait
  | DependencyAdded Id Id
    -- ^ blocked, blocker
  | ComparisonRecorded Id Id Id Author
    -- ^ comparison, before, after, author
  | ComparisonStale Id
    -- ^ comparison
  | DelegationCreated Id Id Id
    -- ^ delegation, brick, delegate party
  | DelegationNoticeApproved Id UTCTime
    -- ^ delegation, next nudge at
  | DelegationCancelled Id
    -- ^ delegation
  | NudgeDue Id
    -- ^ delegation
  | NudgeApproved Id UTCTime
    -- ^ delegation, next nudge at
  | NudgeDeclined Id UTCTime
    -- ^ delegation, next nudge at
  | DelegationCompleted Id
    -- ^ delegation
  | DelegationRefused Id
    -- ^ delegation
  | DelegationAbandoned Id
    -- ^ delegation
  | EffectAdded Id Id EffectKind Text
    -- ^ effect, brick, kind, detail
  | EffectProposed Id
    -- ^ effect
  | EffectApplied Id (Maybe (Id, Text))
    -- ^ effect, spawned (brick, title) when kind = spawn
  | EffectDeclined Id
    -- ^ effect
  | SourceAttached Id Id Text
    -- ^ link, brick, source ref
  | SourceChecked Id Text
    -- ^ link, fingerprint (fresh)
  | SourceDiverged Id Id Text
    -- ^ link, reconcile meta-brick, reconcile title
  | DivergenceResolved Id Text
    -- ^ link, fingerprint
  | TaxonomyReviewProposed Int
    -- ^ unreviewed `other` count at proposal time
  deriving (Eq, Show)

-- --------------------------------------------------------------------------
-- Serialisation
-- --------------------------------------------------------------------------

bodyType :: Body -> Text
bodyType = \case
  PartyRegistered {} -> "party_registered"
  BrickCaptured {} -> "brick_captured"
  RawCaptured {} -> "raw_captured"
  SeedsExtracted {} -> "seeds_extracted"
  SeedPromoted {} -> "seed_promoted"
  BrickKilled {} -> "brick_killed"
  BrickReady {} -> "brick_ready"
  BrickRegressed {} -> "brick_regressed"
  RequesterAttributed {} -> "requester_attributed"
  BrickEnriched {} -> "brick_enriched"
  BrickBroken {} -> "brick_broken"
  BricksUnified {} -> "bricks_unified"
  BrickSuperseded {} -> "brick_superseded"
  SessionOpened {} -> "session_opened"
  SessionClosed {} -> "session_closed"
  FocusServed {} -> "focus_served"
  BrickStarted {} -> "brick_started"
  BrickStopped {} -> "brick_stopped"
  BrickCompleted {} -> "brick_completed"
  WipFlagged {} -> "wip_flagged"
  SkipTaken {} -> "skip_taken"
  ClarificationDeferred {} -> "clarification_deferred"
  WaitRecorded {} -> "wait_recorded"
  WaitResolved {} -> "wait_resolved"
  DependencyAdded {} -> "dependency_added"
  ComparisonRecorded {} -> "comparison_recorded"
  ComparisonStale {} -> "comparison_stale"
  DelegationCreated {} -> "delegation_created"
  DelegationNoticeApproved {} -> "delegation_notice_approved"
  DelegationCancelled {} -> "delegation_cancelled"
  NudgeDue {} -> "nudge_due"
  NudgeApproved {} -> "nudge_approved"
  NudgeDeclined {} -> "nudge_declined"
  DelegationCompleted {} -> "delegation_completed"
  DelegationRefused {} -> "delegation_refused"
  DelegationAbandoned {} -> "delegation_abandoned"
  EffectAdded {} -> "effect_added"
  EffectProposed {} -> "effect_proposed"
  EffectApplied {} -> "effect_applied"
  EffectDeclined {} -> "effect_declined"
  SourceAttached {} -> "source_attached"
  SourceChecked {} -> "source_checked"
  SourceDiverged {} -> "source_diverged"
  DivergenceResolved {} -> "divergence_resolved"
  TaxonomyReviewProposed {} -> "taxonomy_review_proposed"

pair :: (Id, Text) -> Value
pair (i, t) = object [ "brick" .= i, "title" .= t ]

parsePair :: Value -> Parser (Id, Text)
parsePair = withObject "brick/title pair" $ \o ->
  (,) <$> o .: "brick" <*> o .: "title"

bodyData :: Body -> Value
bodyData = \case
  PartyRegistered p n t ->
    object [ "party" .= p, "name" .= n, "party_type" .= partyTypeText t ]
  BrickCaptured b t -> object [ "brick" .= b, "title" .= t ]
  RawCaptured r c -> object [ "raw" .= r, "content" .= c ]
  SeedsExtracted r seeds ->
    object [ "raw" .= r, "seeds" .= map pair seeds ]
  SeedPromoted b -> object [ "brick" .= b ]
  BrickKilled b -> object [ "brick" .= b ]
  BrickReady b -> object [ "brick" .= b ]
  BrickRegressed b -> object [ "brick" .= b ]
  RequesterAttributed b p -> object [ "brick" .= b, "party" .= p ]
  BrickEnriched b k c en m a ->
    object [ "brick" .= b
           , "kind" .= fmap kindText k
           , "context" .= c
           , "energy" .= en
           , "mode" .= fmap modeText m
           , "atomicity" .= fmap atomicityText a ]
  BrickBroken parent parts ->
    object [ "parent" .= parent, "parts" .= map pair parts ]
  BricksUnified b into reason ->
    object [ "brick" .= b, "into" .= into, "reason" .= reason ]
  BrickSuperseded b repl title reason ->
    object [ "brick" .= b, "replacement" .= repl
           , "title" .= title, "reason" .= reason ]
  SessionOpened s ctx strict ->
    object [ "session" .= s, "context" .= ctx
           , "strictness" .= strictnessText strict ]
  SessionClosed s -> object [ "session" .= s ]
  FocusServed s b -> object [ "session" .= s, "brick" .= b ]
  BrickStarted b -> object [ "brick" .= b ]
  BrickStopped b -> object [ "brick" .= b ]
  BrickCompleted b -> object [ "brick" .= b ]
  WipFlagged b -> object [ "brick" .= b ]
  SkipTaken sk b r raw ->
    object [ "skip" .= sk, "brick" .= b
           , "reason" .= skipReasonText r, "raw_text" .= raw ]
  ClarificationDeferred b c t ->
    object [ "brick" .= b, "clarify" .= c, "title" .= t ]
  WaitRecorded w b p c ->
    object [ "wait" .= w, "brick" .= b, "party" .= p, "condition" .= c ]
  WaitResolved w -> object [ "wait" .= w ]
  DependencyAdded blocked blocker ->
    object [ "blocked" .= blocked, "blocker" .= blocker ]
  ComparisonRecorded c before after author ->
    object [ "comparison" .= c, "before" .= before, "after" .= after
           , "author" .= authorText author ]
  ComparisonStale c -> object [ "comparison" .= c ]
  DelegationCreated d b p ->
    object [ "delegation" .= d, "brick" .= b, "party" .= p ]
  DelegationNoticeApproved d next ->
    object [ "delegation" .= d, "next_nudge_at" .= next ]
  DelegationCancelled d -> object [ "delegation" .= d ]
  NudgeDue d -> object [ "delegation" .= d ]
  NudgeApproved d next ->
    object [ "delegation" .= d, "next_nudge_at" .= next ]
  NudgeDeclined d next ->
    object [ "delegation" .= d, "next_nudge_at" .= next ]
  DelegationCompleted d -> object [ "delegation" .= d ]
  DelegationRefused d -> object [ "delegation" .= d ]
  DelegationAbandoned d -> object [ "delegation" .= d ]
  EffectAdded e b k detail ->
    object [ "effect" .= e, "brick" .= b
           , "kind" .= effectKindText k, "detail" .= detail ]
  EffectProposed e -> object [ "effect" .= e ]
  EffectApplied e spawned ->
    object [ "effect" .= e, "spawned" .= fmap pair spawned ]
  EffectDeclined e -> object [ "effect" .= e ]
  SourceAttached l b r ->
    object [ "link" .= l, "brick" .= b, "ref" .= r ]
  SourceChecked l fp -> object [ "link" .= l, "fingerprint" .= fp ]
  SourceDiverged l rec t ->
    object [ "link" .= l, "reconcile" .= rec, "title" .= t ]
  DivergenceResolved l fp -> object [ "link" .= l, "fingerprint" .= fp ]
  TaxonomyReviewProposed n -> object [ "count" .= n ]

enumField :: Text -> (Text -> Maybe e) -> Object -> Key -> Parser e
enumField label parse o k = do
  t <- o .: k
  case parse t of
    Just e -> pure e
    Nothing -> fail (T.unpack ("invalid " <> label <> ": " <> t))

optEnumField :: Text -> (Text -> Maybe e) -> Object -> Key -> Parser (Maybe e)
optEnumField label parse o k = do
  mt <- o .:? k
  case mt of
    Nothing -> pure Nothing
    Just t -> case parse t of
      Just e -> pure (Just e)
      Nothing -> fail (T.unpack ("invalid " <> label <> ": " <> t))

parseBody :: Text -> Object -> Parser Body
parseBody ty o = case ty of
  "party_registered" ->
    PartyRegistered <$> o .: "party" <*> o .: "name"
      <*> enumField "party_type" parsePartyType o "party_type"
  "brick_captured" -> BrickCaptured <$> o .: "brick" <*> o .: "title"
  "raw_captured" -> RawCaptured <$> o .: "raw" <*> o .: "content"
  "seeds_extracted" -> do
    r <- o .: "raw"
    seeds <- o .: "seeds" >>= mapM parsePair
    pure (SeedsExtracted r seeds)
  "seed_promoted" -> SeedPromoted <$> o .: "brick"
  "brick_killed" -> BrickKilled <$> o .: "brick"
  "brick_ready" -> BrickReady <$> o .: "brick"
  "brick_regressed" -> BrickRegressed <$> o .: "brick"
  "requester_attributed" ->
    RequesterAttributed <$> o .: "brick" <*> o .: "party"
  "brick_enriched" ->
    BrickEnriched
      <$> o .: "brick"
      <*> optEnumField "kind" parseKind o "kind"
      <*> o .:? "context"
      <*> o .:? "energy"
      <*> optEnumField "mode" parseMode o "mode"
      <*> optEnumField "atomicity" parseAtomicity o "atomicity"
  "brick_broken" -> do
    p <- o .: "parent"
    parts <- o .: "parts" >>= mapM parsePair
    pure (BrickBroken p parts)
  "bricks_unified" ->
    BricksUnified <$> o .: "brick" <*> o .: "into" <*> o .:? "reason"
  "brick_superseded" ->
    BrickSuperseded <$> o .: "brick" <*> o .: "replacement"
      <*> o .: "title" <*> o .:? "reason"
  "session_opened" ->
    SessionOpened <$> o .: "session" <*> o .:? "context"
      <*> enumField "strictness" parseStrictness o "strictness"
  "session_closed" -> SessionClosed <$> o .: "session"
  "focus_served" -> FocusServed <$> o .: "session" <*> o .: "brick"
  "brick_started" -> BrickStarted <$> o .: "brick"
  "brick_stopped" -> BrickStopped <$> o .: "brick"
  "brick_completed" -> BrickCompleted <$> o .: "brick"
  "wip_flagged" -> WipFlagged <$> o .: "brick"
  "skip_taken" ->
    SkipTaken <$> o .: "skip" <*> o .: "brick"
      <*> enumField "reason" parseSkipReason o "reason"
      <*> o .:? "raw_text"
  "clarification_deferred" ->
    ClarificationDeferred <$> o .: "brick" <*> o .: "clarify" <*> o .: "title"
  "wait_recorded" ->
    WaitRecorded <$> o .: "wait" <*> o .: "brick"
      <*> o .:? "party" <*> o .:? "condition"
  "wait_resolved" -> WaitResolved <$> o .: "wait"
  "dependency_added" ->
    DependencyAdded <$> o .: "blocked" <*> o .: "blocker"
  "comparison_recorded" ->
    ComparisonRecorded <$> o .: "comparison" <*> o .: "before"
      <*> o .: "after" <*> enumField "author" parseAuthor o "author"
  "comparison_stale" -> ComparisonStale <$> o .: "comparison"
  "delegation_created" ->
    DelegationCreated <$> o .: "delegation" <*> o .: "brick" <*> o .: "party"
  "delegation_notice_approved" ->
    DelegationNoticeApproved <$> o .: "delegation" <*> o .: "next_nudge_at"
  "delegation_cancelled" -> DelegationCancelled <$> o .: "delegation"
  "nudge_due" -> NudgeDue <$> o .: "delegation"
  "nudge_approved" ->
    NudgeApproved <$> o .: "delegation" <*> o .: "next_nudge_at"
  "nudge_declined" ->
    NudgeDeclined <$> o .: "delegation" <*> o .: "next_nudge_at"
  "delegation_completed" -> DelegationCompleted <$> o .: "delegation"
  "delegation_refused" -> DelegationRefused <$> o .: "delegation"
  "delegation_abandoned" -> DelegationAbandoned <$> o .: "delegation"
  "effect_added" ->
    EffectAdded <$> o .: "effect" <*> o .: "brick"
      <*> enumField "kind" parseEffectKind o "kind"
      <*> o .: "detail"
  "effect_proposed" -> EffectProposed <$> o .: "effect"
  "effect_applied" -> do
    e <- o .: "effect"
    spawned <- o .:? "spawned" >>= traverse parsePair
    pure (EffectApplied e spawned)
  "effect_declined" -> EffectDeclined <$> o .: "effect"
  "source_attached" ->
    SourceAttached <$> o .: "link" <*> o .: "brick" <*> o .: "ref"
  "source_checked" -> SourceChecked <$> o .: "link" <*> o .: "fingerprint"
  "source_diverged" ->
    SourceDiverged <$> o .: "link" <*> o .: "reconcile" <*> o .: "title"
  "divergence_resolved" ->
    DivergenceResolved <$> o .: "link" <*> o .: "fingerprint"
  "taxonomy_review_proposed" -> TaxonomyReviewProposed <$> o .: "count"
  other -> fail (T.unpack ("unknown event type: " <> other))

eventToJSON :: Event -> Value
eventToJSON Event {..} = object
  [ "v" .= (1 :: Int)
  , "id" .= evId
  , "at" .= evAt
  , "type" .= bodyType evBody
  , "data" .= bodyData evBody
  ]

eventFromJSON :: Value -> Parser Event
eventFromJSON = withObject "event" $ \o -> do
  eid <- o .: "id"
  at <- o .: "at"
  ty <- o .: "type"
  d <- o .: "data"
  body <- withObject "data" (parseBody ty) d
  pure (Event eid at body)

-- | Intrinsic event id: hash of the canonical serialised content (without
-- the id field itself). Position-independent, so future sync can treat the
-- log as a set.
computeEventId :: UTCTime -> Body -> Text
computeEventId at body =
  T.pack . showDigest . sha256 . encode $ object
    [ "at" .= at, "type" .= bodyType body, "data" .= bodyData body ]

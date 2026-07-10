-- | Core domain types, mirroring spec/little-ant.allium.
--
-- Every enum has an explicit, stable text mapping (used both in the event
-- log and in CLI arguments). Data is always English; UI language is the
-- operator's concern.
module LittleAnt.Types
  ( -- * Enums
    Stage (..)
  , Kind (..)
  , Mode (..)
  , Atomicity (..)
  , Author (..)
  , SkipReason (..)
  , Strictness (..)
  , EffectKind (..)
  , EffectStatus (..)
  , DelegationStatus (..)
  , PartyType (..)
  , SessionStatus (..)
  , RawStatus (..)
    -- * Enum text mappings
  , stageText, parseStage
  , kindText, parseKind
  , modeText, parseMode
  , atomicityText, parseAtomicity
  , authorText, parseAuthor
  , skipReasonText, parseSkipReason
  , strictnessText, parseStrictness
  , effectKindText, parseEffectKind
  , effectStatusText
  , delegationStatusText
  , partyTypeText, parsePartyType
  , sessionStatusText
  , rawStatusText
    -- * Entities
  , Brick (..)
  , Party (..)
  , RawInput (..)
  , Skip (..)
  , Wait (..)
  , Comparison (..)
  , SourceLink (..)
  , Effect (..)
  , Delegation (..)
  , Session (..)
  , TaxonomyWatch (..)
  , OrderWatch (..)
  ) where

import Data.Text (Text)
import Data.Time (UTCTime)
import LittleAnt.Ids (Id)

-- --------------------------------------------------------------------------
-- Enums
-- --------------------------------------------------------------------------

data Stage = Seed | Committed | Ready | Wip | Done | Dropped | Superseded
  deriving (Eq, Ord, Show, Enum, Bounded)

data Kind = KSpec | KExec | KDelegation | KDecision | KMeta
  deriving (Eq, Ord, Show, Enum, Bounded)

data Mode = Digital | Physical
  deriving (Eq, Ord, Show, Enum, Bounded)

data Atomicity = Atomic | Divisible | UnknownAtomicity
  deriving (Eq, Ord, Show, Enum, Bounded)

data Author = Human | AI
  deriving (Eq, Ord, Show, Enum, Bounded)

data SkipReason
  = Hard | Vague | NotPriority | WaitingReason | Tired | Meh | KillReason
  | Alternatives | OtherReason
  deriving (Eq, Ord, Show, Enum, Bounded)

data Strictness = SIgnore | SPrefer | SRequire
  deriving (Eq, Ord, Show, Enum, Bounded)

data EffectKind = WriteBack | Notify | Spawn
  deriving (Eq, Ord, Show, Enum, Bounded)

data EffectStatus = EArmed | EProposed | EApplied | EDeclined
  deriving (Eq, Ord, Show, Enum, Bounded)

data DelegationStatus
  = DToNotify | DNotified | DNudged | DCompleted | DRefused | DAbandoned
  deriving (Eq, Ord, Show, Enum, Bounded)

data PartyType = Person | AiAgent | Company | Area
  deriving (Eq, Ord, Show, Enum, Bounded)

data SessionStatus = SessOpen | SessClosed
  deriving (Eq, Ord, Show, Enum, Bounded)

data RawStatus = RawPending | RawExtracted
  deriving (Eq, Ord, Show, Enum, Bounded)

-- --------------------------------------------------------------------------
-- Enum text tables
-- --------------------------------------------------------------------------

byText :: [(e, Text)] -> Text -> Maybe e
byText table t = lookup t [ (txt, e) | (e, txt) <- table ]

stageTable :: [(Stage, Text)]
stageTable =
  [ (Seed, "seed"), (Committed, "committed"), (Ready, "ready"), (Wip, "wip")
  , (Done, "done"), (Dropped, "dropped"), (Superseded, "superseded") ]

stageText :: Stage -> Text
stageText s = maybe "" id (Prelude.lookup s stageTable)

parseStage :: Text -> Maybe Stage
parseStage = byText stageTable

kindTable :: [(Kind, Text)]
kindTable =
  [ (KSpec, "spec"), (KExec, "exec"), (KDelegation, "delegation")
  , (KDecision, "decision"), (KMeta, "meta") ]

kindText :: Kind -> Text
kindText k = maybe "" id (Prelude.lookup k kindTable)

parseKind :: Text -> Maybe Kind
parseKind = byText kindTable

modeTable :: [(Mode, Text)]
modeTable = [ (Digital, "digital"), (Physical, "physical") ]

modeText :: Mode -> Text
modeText m = maybe "" id (Prelude.lookup m modeTable)

parseMode :: Text -> Maybe Mode
parseMode = byText modeTable

atomicityTable :: [(Atomicity, Text)]
atomicityTable =
  [ (Atomic, "atomic"), (Divisible, "divisible")
  , (UnknownAtomicity, "unknown") ]

atomicityText :: Atomicity -> Text
atomicityText a = maybe "" id (Prelude.lookup a atomicityTable)

parseAtomicity :: Text -> Maybe Atomicity
parseAtomicity = byText atomicityTable

authorTable :: [(Author, Text)]
authorTable = [ (Human, "human"), (AI, "ai") ]

authorText :: Author -> Text
authorText a = maybe "" id (Prelude.lookup a authorTable)

parseAuthor :: Text -> Maybe Author
parseAuthor = byText authorTable

skipReasonTable :: [(SkipReason, Text)]
skipReasonTable =
  [ (Hard, "hard"), (Vague, "vague"), (NotPriority, "not_priority")
  , (WaitingReason, "waiting"), (Tired, "tired"), (Meh, "meh")
  , (KillReason, "kill"), (Alternatives, "alternatives")
  , (OtherReason, "other") ]

skipReasonText :: SkipReason -> Text
skipReasonText r = maybe "" id (Prelude.lookup r skipReasonTable)

parseSkipReason :: Text -> Maybe SkipReason
parseSkipReason = byText skipReasonTable

strictnessTable :: [(Strictness, Text)]
strictnessTable =
  [ (SIgnore, "ignore"), (SPrefer, "prefer"), (SRequire, "require") ]

strictnessText :: Strictness -> Text
strictnessText s = maybe "" id (Prelude.lookup s strictnessTable)

parseStrictness :: Text -> Maybe Strictness
parseStrictness = byText strictnessTable

effectKindTable :: [(EffectKind, Text)]
effectKindTable =
  [ (WriteBack, "write_back"), (Notify, "notify"), (Spawn, "spawn") ]

effectKindText :: EffectKind -> Text
effectKindText k = maybe "" id (Prelude.lookup k effectKindTable)

parseEffectKind :: Text -> Maybe EffectKind
parseEffectKind = byText effectKindTable

effectStatusText :: EffectStatus -> Text
effectStatusText = \case
  EArmed -> "armed"
  EProposed -> "proposed"
  EApplied -> "applied"
  EDeclined -> "declined"

delegationStatusText :: DelegationStatus -> Text
delegationStatusText = \case
  DToNotify -> "to_notify"
  DNotified -> "notified"
  DNudged -> "nudged"
  DCompleted -> "completed"
  DRefused -> "refused"
  DAbandoned -> "abandoned"

partyTypeTable :: [(PartyType, Text)]
partyTypeTable =
  [ (Person, "person"), (AiAgent, "ai_agent"), (Company, "company")
  , (Area, "area") ]

partyTypeText :: PartyType -> Text
partyTypeText p = maybe "" id (Prelude.lookup p partyTypeTable)

parsePartyType :: Text -> Maybe PartyType
parsePartyType = byText partyTypeTable

sessionStatusText :: SessionStatus -> Text
sessionStatusText = \case
  SessOpen -> "open"
  SessClosed -> "closed"

rawStatusText :: RawStatus -> Text
rawStatusText = \case
  RawPending -> "pending"
  RawExtracted -> "extracted"

-- --------------------------------------------------------------------------
-- Entities
-- --------------------------------------------------------------------------

data Brick = Brick
  { bId :: Id
  , bTitle :: Text
  , bStage :: Stage
  , bAtomicity :: Atomicity
  , bKind :: Maybe Kind
  , bContext :: Maybe Text
  , bEnergy :: Maybe Double
  , bMode :: Maybe Mode
  , bParent :: Maybe Id
  , bAbout :: Maybe Id
  , bRequester :: Maybe Id
  , bEstimateHours :: Maybe Double
  , bEstimateBy :: Maybe Author
  , bWipStartedAt :: Maybe UTCTime
  , bWipFlagged :: Maybe Bool
  , bSupersededBy :: Maybe Id
  , bSupersedeReason :: Maybe Text
  , bCreatedAt :: UTCTime
  , bCreatedSeq :: Int
    -- ^ Event sequence number at creation: a stable, deterministic
    -- tie-breaker for ordering.
  , bLastActivityAt :: UTCTime
    -- ^ Last time this brick was served, skipped, started or stopped.
    -- Drives anti-starvation aging.
  , bSkipCount :: Int
  , bServeCount :: Int
  } deriving (Eq, Show)

data Party = Party
  { pId :: Id
  , pName :: Text
  , pType :: PartyType
  } deriving (Eq, Show)

data RawInput = RawInput
  { rawId :: Id
  , rawContent :: Text
  , rawReceivedAt :: UTCTime
  , rawStatus :: RawStatus
  } deriving (Eq, Show)

data Skip = Skip
  { skId :: Id
  , skBrick :: Id
  , skReason :: SkipReason
  , skRawText :: Maybe Text
  , skRecordedAt :: UTCTime
  } deriving (Eq, Show)

data Wait = Wait
  { wId :: Id
  , wBrick :: Id
  , wOnParty :: Maybe Id
  , wConditionNote :: Maybe Text
  , wResolved :: Bool
  } deriving (Eq, Show)

data Comparison = Comparison
  { cId :: Id
  , cBefore :: Id
  , cAfter :: Id
  , cAuthor :: Author
  , cRecordedAt :: UTCTime
  , cRevalidationRequested :: Bool
  } deriving (Eq, Show)

data SourceLink = SourceLink
  { slId :: Id
  , slBrick :: Id
  , slRef :: Text
  , slLastFingerprint :: Maybe Text
  , slDiverged :: Bool
  } deriving (Eq, Show)

data Effect = Effect
  { efId :: Id
  , efBrick :: Id
  , efKind :: EffectKind
  , efDetail :: Text
  , efStatus :: EffectStatus
  } deriving (Eq, Show)

data Delegation = Delegation
  { dId :: Id
  , dBrick :: Id
  , dDelegate :: Id
  , dStatus :: DelegationStatus
  , dNudgeCount :: Int
  , dNextNudgeAt :: Maybe UTCTime
  , dNudgePending :: Bool
  } deriving (Eq, Show)

data Session = Session
  { sesId :: Id
  , sesContextHint :: Maybe Text
  , sesStrictness :: Strictness
  , sesServeCount :: Int
  , sesStatus :: SessionStatus
  , sesOpenedAt :: UTCTime
  } deriving (Eq, Show)

data TaxonomyWatch = TaxonomyWatch
  { twUnreviewedOtherCount :: Int
  , twReviewThreshold :: Int
  } deriving (Eq, Show)

data OrderWatch = OrderWatch
  { owReadiedSinceRound :: Int
    -- ^ Bricks that became ready since the last sanity round: each one
    -- lands in the order as a mere tie-break until placed/sorted.
  , owRoundThreshold :: Int
    -- ^ The tolerance: below this count, no burst-triggered round.
  , owClockAt :: Maybe UTCTime
    -- ^ Time anchor for the drift-triggered round: last round (or first
    -- readied brick). Priorities rot with time even when nothing new
    -- arrives — same reason comparisons have a shelf life.
  , owRoundBrick :: Maybe Id
    -- ^ The last spawned sanity-round meta-brick; while it is open, no new
    -- round is proposed.
  } deriving (Eq, Show)

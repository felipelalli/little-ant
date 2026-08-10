{-# LANGUAGE ForeignFunctionInterface #-}

module LittleAnt.Migration.V0 (
  MigrationReport (..),
  MigrationStage (..),
  runV0Migration,
)
where

import Control.Applicative ((<|>))
import Control.Exception (IOException, bracket, catch)
import Control.Monad (foldM, replicateM, unless, when, (>=>))
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base16 qualified as Base16
import Data.ByteString.Char8 qualified as ByteStringChar8
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Foldable (toList, traverse_)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (UTCTime, addUTCTime)
import Foreign.C.Error (Errno, eINVAL, eNOSYS, eOPNOTSUPP, errnoToIOError, getErrno)
import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CInt (..), CUInt (..))
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.JudgmentDecision
import LittleAnt.Model
import LittleAnt.Store
import System.Directory
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO (IOMode (WriteMode), hFlush, openBinaryFile)
import System.Posix.Files (getSymbolicLinkStatus, isDirectory, setFileMode)
import System.Posix.Files qualified as Posix
import System.Posix.IO (FdOption (CloseOnExec), OpenMode (ReadOnly), closeFd, defaultFileFlags, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)

data MigrationStage = MigrationInspect | MigrationBuild | MigrationCutover
  deriving stock (Eq, Ord, Show)

data MigrationReport = MigrationReport
  { migrationStage :: MigrationStage
  , migrationSourcePath :: FilePath
  , migrationSourceDigest :: Text
  , migrationLegacyEventCount :: Int
  , migrationLegacyBrickCount :: Int
  , migrationLegacyRawCount :: Int
  , migrationSupportedTypes :: [Text]
  , migrationCandidatePath :: Maybe FilePath
  , migrationBackupPath :: Maybe FilePath
  , migrationCandidateCursor :: Maybe DatasetCursor
  , migrationCutoverComplete :: Bool
  , migrationDryRun :: Bool
  }
  deriving stock (Eq, Show)

data LegacyEvent = LegacyEvent
  { legacyEventId :: Text
  , legacyEventAt :: UTCTime
  , legacyEventType :: Text
  , legacyEventVersion :: Int
  , legacyEventData :: Object
  }
  deriving stock (Eq, Show)

data LegacyStage = LegacyActive | LegacyWip | LegacyDone | LegacyArchived | LegacySuperseded
  deriving stock (Eq, Ord, Show)

data LegacyBrick = LegacyBrick
  { legacyBrickId :: Text
  , legacyBrickTitle :: Text
  , legacyBrickDescription :: Maybe Text
  , legacyBrickStage :: LegacyStage
  , legacyBrickAtomicity :: Maybe Text
  , legacyBrickKind :: Maybe Text
  , legacyBrickContext :: Maybe Text
  , legacyBrickWeight :: Maybe Double
  , legacyBrickEstimateHours :: Maybe Double
  , legacyBrickRequester :: Maybe Text
  , legacyBrickCreatedAt :: UTCTime
  , legacyBrickCreatedOrder :: Int
  }
  deriving stock (Eq, Show)

data LegacyRaw = LegacyRaw
  { legacyRawId :: Text
  , legacyRawContent :: Text
  , legacyRawAt :: UTCTime
  , legacyRawExtracted :: Bool
  }
  deriving stock (Eq, Show)

data LegacyParty = LegacyParty
  { legacyPartyId :: Text
  , legacyPartyName :: Text
  , legacyPartyType :: Text
  , legacyPartyAt :: UTCTime
  }
  deriving stock (Eq, Show)

data LegacyWait = LegacyWait
  { legacyWaitId :: Text
  , legacyWaitBrick :: Text
  , legacyWaitParty :: Maybe Text
  , legacyWaitCondition :: Maybe Text
  , legacyWaitAt :: UTCTime
  }
  deriving stock (Eq, Show)

data LegacySource = LegacySource
  { legacySourceId :: Text
  , legacySourceBrick :: Text
  , legacySourceKind :: Text
  , legacySourceLocator :: Text
  , legacySourceFingerprint :: Maybe Text
  , legacySourceAt :: UTCTime
  }
  deriving stock (Eq, Show)

data LegacyComparison = LegacyComparison
  { legacyComparisonId :: Text
  , legacyComparisonBefore :: Text
  , legacyComparisonAfter :: Text
  , legacyComparisonAuthor :: Text
  , legacyComparisonAt :: UTCTime
  }
  deriving stock (Eq, Show)

data LegacySkip = LegacySkip
  { legacySkipId :: Text
  , legacySkipBrick :: Text
  , legacySkipReason :: Text
  , legacySkipRawText :: Maybe Text
  , legacySkipAt :: UTCTime
  }
  deriving stock (Eq, Show)

data LegacyProjection = LegacyProjection
  { legacyEvents :: [LegacyEvent]
  , legacyBricks :: Map Text LegacyBrick
  , legacyRaws :: Map Text LegacyRaw
  , legacyParties :: Map Text LegacyParty
  , legacyWaits :: Map Text LegacyWait
  , legacySources :: Map Text LegacySource
  , legacyDependencies :: Set (Text, Text)
  , legacyComparisons :: Map (Text, Text) LegacyComparison
  , legacySkips :: [LegacySkip]
  , legacyFlows :: Set Text
  , legacySeenEventIds :: Set Text
  }
  deriving stock (Eq, Show)

emptyLegacyProjection :: LegacyProjection
emptyLegacyProjection =
  LegacyProjection [] Map.empty Map.empty Map.empty Map.empty Map.empty Set.empty Map.empty [] Set.empty Set.empty

supportedVersions :: Map Text Int
supportedVersions =
  Map.fromList
    [ ("brick_captured", 1)
    , ("brick_completed", 1)
    , ("brick_described", 1)
    , ("brick_enriched", 2)
    , ("brick_killed", 1)
    , ("brick_ready", 1)
    , ("brick_regressed", 1)
    , ("brick_started", 1)
    , ("brick_stopped", 1)
    , ("brick_superseded", 1)
    , ("comparison_recorded", 1)
    , ("dependency_added", 1)
    , ("fed", 1)
    , ("flow_opened", 1)
    , ("focus_served", 2)
    , ("order_sanity_proposed", 1)
    , ("party_registered", 1)
    , ("requester_attributed", 1)
    , ("seed_promoted", 1)
    , ("seeds_extracted", 1)
    , ("skip_taken", 1)
    , ("source_attached", 1)
    , ("source_checked", 1)
    , ("wait_recorded", 1)
    , ("wip_flagged", 1)
    ]

parseLegacyLog :: ByteString -> Either AppError LegacyProjection
parseLegacyLog bytes = do
  let rows = ByteStringChar8.lines bytes
  when (null rows) $ Left (migrationError InvalidInput "The v0 event log is empty.")
  events <- traverse parseRow (zip [1 :: Int ..] rows)
  projection <- foldM applyLegacyEvent emptyLegacyProjection events
  validateLegacyProjection projection
 where
  parseRow (lineNumber, row)
    | ByteString.null row = Left (lineProblem lineNumber "Blank JSONL records are not accepted.")
    | otherwise = case eitherDecodeStrict' row of
        Left detail -> Left (lineProblem lineNumber ("Invalid JSON: " <> Text.pack detail))
        Right value -> case parseEither parseLegacyEvent value of
          Left detail -> Left (lineProblem lineNumber (Text.pack detail))
          Right event -> validateLegacyEvent lineNumber event

parseLegacyEvent :: Value -> Parser LegacyEvent
parseLegacyEvent = withObject "Little Ant v0 event" $ \value -> do
  version <- value .: "v"
  identity <- value .: "id"
  at <- value .: "at"
  eventType <- value .: "type"
  payload <- value .: "data"
  pure (LegacyEvent identity at eventType version payload)

validateLegacyEvent :: Int -> LegacyEvent -> Either AppError LegacyEvent
validateLegacyEvent lineNumber event = do
  expectedVersion <-
    maybe
      (Left (lineProblem lineNumber ("Unsupported v0 event type: " <> legacyEventType event)))
      Right
      (Map.lookup (legacyEventType event) supportedVersions)
  unless (legacyEventVersion event == expectedVersion) $
    Left
      ( lineProblem
          lineNumber
          ( "Unsupported version for "
              <> legacyEventType event
              <> ": expected "
              <> tshow expectedVersion
              <> ", found "
              <> tshow (legacyEventVersion event)
          )
      )
  validatePayloadShape event
  unless (legacyEventId event `elem` acceptableLegacyIntrinsicIds event) $
    Left (lineProblem lineNumber "The intrinsic v0 event ID does not match its canonical payload.")
  pure event

legacyIntrinsicId :: LegacyEvent -> Text
legacyIntrinsicId event = legacyIntrinsicIdFor event (legacyEventType event) (canonicalLegacyData event)

legacyIntrinsicIdFor :: LegacyEvent -> Text -> Value -> Text
legacyIntrinsicIdFor event eventType payload =
  TextEncoding.decodeUtf8 . Base16.encode . SHA256.hash . LazyByteString.toStrict . encode $
    object
      [ "at" .= legacyEventAt event
      , "type" .= eventType
      , "data" .= payload
      ]

acceptableLegacyIntrinsicIds :: LegacyEvent -> [Text]
acceptableLegacyIntrinsicIds event = legacyIntrinsicId event : historical
 where
  value key = fromMaybe Null (KeyMap.lookup (Key.fromText key) (legacyEventData event))
  historical = case legacyEventType event of
    "brick_enriched" ->
      [ legacyIntrinsicIdFor
          event
          "brick_enriched"
          ( object
              [ "brick" .= value "brick"
              , "kind" .= value "kind"
              , "context" .= value "context"
              , "energy" .= value "weight"
              , "mode" .= value "mode"
              , "atomicity" .= value "atomicity"
              , "estimate_hours" .= value "estimate_hours"
              , "estimate_by" .= value "estimate_by"
              ]
          )
      ]
    "fed" -> [legacyIntrinsicIdFor event "raw_captured" (canonicalLegacyData event)]
    "flow_opened" ->
      [ legacyIntrinsicIdFor
          event
          "session_opened"
          (object ["session" .= value "flow", "context" .= value "context", "strictness" .= value "strictness"])
      ]
    "focus_served" ->
      [ legacyIntrinsicIdFor
          event
          "focus_served"
          (object ["session" .= value "flow", "brick" .= value "brick"])
      ]
    _ -> []

canonicalLegacyData :: LegacyEvent -> Value
canonicalLegacyData event = case legacyEventType event of
  "party_registered" -> fields ["party", "name", "party_type"]
  "brick_captured" -> fields ["brick", "title"]
  "fed" -> fields ["raw", "content"]
  "seeds_extracted" ->
    object
      [ "raw" .= value "raw"
      , "seeds" .= canonicalSeeds (value "seeds")
      ]
  "seed_promoted" -> fields ["brick"]
  "brick_killed" -> fields ["brick"]
  "brick_ready" -> fields ["brick"]
  "brick_regressed" -> fields ["brick"]
  "requester_attributed" -> fields ["brick", "party"]
  "brick_enriched" -> fields ["brick", "kind", "context", "weight", "mode", "atomicity", "estimate_hours", "estimate_by"]
  "brick_described" -> fields ["brick", "description"]
  "brick_superseded" -> fields ["brick", "replacement", "title", "reason"]
  "flow_opened" -> fields ["flow", "context", "strictness"]
  "focus_served" -> fields ["flow", "brick"]
  "brick_started" -> fields ["brick"]
  "brick_stopped" -> fields ["brick"]
  "brick_completed" -> fields ["brick"]
  "wip_flagged" -> fields ["brick"]
  "skip_taken" -> fields ["skip", "brick", "reason", "raw_text"]
  "wait_recorded" -> fields ["wait", "brick", "party", "condition"]
  "dependency_added" -> fields ["blocked", "blocker"]
  "comparison_recorded" -> fields ["comparison", "before", "after", "author"]
  "source_attached" -> fields ["link", "brick", "type", "url"]
  "source_checked" -> fields ["link", "fingerprint"]
  "order_sanity_proposed" -> fields ["brick", "title", "readied_count"]
  _ -> Object (legacyEventData event)
 where
  value key = fromMaybe Null (KeyMap.lookup (Key.fromText key) (legacyEventData event))
  fields keys = object [(Key.fromText key, value key) | key <- keys]
  canonicalSeeds = \case
    Array seeds ->
      toJSON
        [ object
            [ "brick" .= fromMaybe Null (KeyMap.lookup "brick" seed)
            , "title" .= fromMaybe Null (KeyMap.lookup "title" seed)
            ]
        | Object seed <- toList seeds
        ]
    other -> other

validatePayloadShape :: LegacyEvent -> Either AppError ()
validatePayloadShape event =
  parserResult $ case legacyEventType event of
    "party_registered" -> reqText "party" >> reqText "name" >> reqEnum "party_type" ["person", "ai_agent", "company", "area"]
    "brick_captured" -> brickAndTitle
    "fed" -> reqText "raw" >> reqText "content"
    "seeds_extracted" -> reqText "raw" >> reqSeeds
    "seed_promoted" -> reqText "brick"
    "brick_killed" -> reqText "brick"
    "brick_ready" -> reqText "brick"
    "brick_regressed" -> reqText "brick"
    "requester_attributed" -> reqText "brick" >> reqText "party"
    "brick_enriched" -> do
      reqText "brick"
      optEnum "kind" ["spec", "exec", "delegation", "decision", "meta"]
      optText "context"
      optNumber "weight"
      optEnum "mode" ["digital", "physical"]
      optEnum "atomicity" ["atomic", "divisible", "unknown"]
      optNumber "estimate_hours"
      optEnum "estimate_by" ["human", "ai"]
    "brick_described" -> reqText "brick" >> reqText "description"
    "brick_superseded" -> reqText "brick" >> reqText "replacement" >> reqText "title" >> optText "reason"
    "flow_opened" -> reqText "flow" >> optText "context" >> reqEnum "strictness" ["ignore", "prefer", "require"]
    "focus_served" -> reqText "flow" >> reqText "brick"
    "brick_started" -> reqText "brick"
    "brick_stopped" -> reqText "brick"
    "brick_completed" -> reqText "brick"
    "wip_flagged" -> reqText "brick"
    "skip_taken" -> reqText "skip" >> reqText "brick" >> reqEnum "reason" legacySkipReasons >> optText "raw_text"
    "wait_recorded" -> reqText "wait" >> reqText "brick" >> optText "party" >> optText "condition"
    "dependency_added" -> reqText "blocked" >> reqText "blocker"
    "comparison_recorded" -> reqText "comparison" >> reqText "before" >> reqText "after" >> reqEnum "author" ["human", "ai"]
    "source_attached" -> reqText "link" >> reqText "brick" >> reqText "type" >> reqText "url"
    "source_checked" -> reqText "link" >> reqText "fingerprint"
    "order_sanity_proposed" -> reqText "brick" >> reqText "title" >> reqInt "readied_count"
    _ -> fail "event type escaped the supported-version boundary"
 where
  payload = legacyEventData event
  parserResult parser = case parseEither (const parser) (Object payload) of
    Left detail -> Left (migrationError CorruptData ("Invalid " <> legacyEventType event <> " payload: " <> Text.pack detail))
    Right () -> Right ()
  reqText :: Text -> Parser ()
  reqText key = nonempty key =<< field key
  optText :: Text -> Parser ()
  optText key = optionalField key >>= traverse_ (nonempty key)
  reqInt :: Text -> Parser ()
  reqInt key = (() <$ (field key :: Parser Int))
  optNumber :: Text -> Parser ()
  optNumber key = (() <$ (optionalField key :: Parser (Maybe Double)))
  reqEnum :: Text -> [Text] -> Parser ()
  reqEnum key choices = field key >>= enumValue key choices
  optEnum :: Text -> [Text] -> Parser ()
  optEnum key choices = optionalField key >>= traverse_ (enumValue key choices)
  field :: (FromJSON value) => Text -> Parser value
  field key = maybe (fail ("missing field: " <> Text.unpack key)) parseJSON (KeyMap.lookup (fromStringKey key) payload)
  optionalField :: (FromJSON value) => Text -> Parser (Maybe value)
  optionalField key = case KeyMap.lookup (fromStringKey key) payload of
    Nothing -> pure Nothing
    Just Null -> pure Nothing
    Just value -> Just <$> parseJSON value
  nonempty :: Text -> Text -> Parser ()
  nonempty key value = unless (not (Text.null (Text.strip value))) (fail (Text.unpack key <> " cannot be empty"))
  enumValue :: Text -> [Text] -> Text -> Parser ()
  enumValue key choices value = unless (value `elem` choices) (fail (Text.unpack key <> " has an unsupported value"))
  brickAndTitle :: Parser ()
  brickAndTitle = reqText "brick" >> reqText "title"
  reqSeeds :: Parser ()
  reqSeeds = do
    seeds <- field "seeds" :: Parser [Value]
    traverse_
      ( withObject "seed" $ \seed -> do
          brick <- seed .: "brick"
          title <- seed .: "title"
          nonempty "brick" brick
          nonempty "title" title
      )
      seeds

legacySkipReasons :: [Text]
legacySkipReasons = ["hard", "vague", "not_priority", "waiting", "tired", "meh", "kill", "alternatives", "other"]

fromStringKey :: Text -> Key
fromStringKey = Key.fromText

applyLegacyEvent :: LegacyProjection -> LegacyEvent -> Either AppError LegacyProjection
applyLegacyEvent projection event = do
  when (legacyEventId event `Set.member` legacySeenEventIds projection) $
    Left (migrationError CorruptData "The v0 log repeats an intrinsic event ID.")
  next <- applyType projection event
  pure
    next
      { legacyEvents = legacyEvents projection <> [event]
      , legacySeenEventIds = Set.insert (legacyEventId event) (legacySeenEventIds projection)
      }

applyType :: LegacyProjection -> LegacyEvent -> Either AppError LegacyProjection
applyType projection event = case legacyEventType event of
  "party_registered" -> do
    identity <- textField event "party"
    name <- textField event "name"
    kind <- textField event "party_type"
    unique "party" identity (legacyParties projection)
    pure projection{legacyParties = Map.insert identity (LegacyParty identity name kind (legacyEventAt event)) (legacyParties projection)}
  "brick_captured" -> createBrickFromFields projection event "brick" "title"
  "fed" -> do
    identity <- textField event "raw"
    content <- textField event "content"
    unique "raw" identity (legacyRaws projection)
    pure projection{legacyRaws = Map.insert identity (LegacyRaw identity content (legacyEventAt event) False) (legacyRaws projection)}
  "seeds_extracted" -> do
    rawIdentity <- textField event "raw"
    raw <- requireMap "raw" rawIdentity (legacyRaws projection)
    seeds <- seedsField event
    withRaw <- pure projection{legacyRaws = Map.insert rawIdentity raw{legacyRawExtracted = True} (legacyRaws projection)}
    foldM (\current (identity, title) -> createLegacyBrick current event identity title) withRaw seeds
  "seed_promoted" -> touchStage projection event LegacyActive
  "brick_ready" -> touchStage projection event LegacyActive
  "brick_regressed" -> touchStage projection event LegacyActive
  "brick_started" -> touchStage projection event LegacyWip
  "brick_stopped" -> touchStage projection event LegacyActive
  "brick_completed" -> touchStage projection event LegacyDone
  "brick_killed" -> touchStage projection event LegacyArchived
  "wip_flagged" -> requireBrickOnly projection event
  "brick_described" -> do
    description <- textField event "description"
    updateBrick projection event $ \brick -> brick{legacyBrickDescription = Just description}
  "brick_enriched" -> updateBrick projection event enrich
  "requester_attributed" -> do
    requester <- textField event "party"
    _ <- requireMap "party" requester (legacyParties projection)
    updateBrick projection event $ \brick -> brick{legacyBrickRequester = Just requester}
  "brick_superseded" -> supersedeBrick projection event
  "flow_opened" -> do
    flow <- textField event "flow"
    when (flow `Set.member` legacyFlows projection) $ Left (migrationError CorruptData "A v0 flow ID is repeated.")
    pure projection{legacyFlows = Set.insert flow (legacyFlows projection)}
  "focus_served" -> do
    flow <- textField event "flow"
    brick <- textField event "brick"
    unless (flow `Set.member` legacyFlows projection) $ Left (migrationError CorruptData "A focus event references a missing v0 flow.")
    _ <- requireMap "brick" brick (legacyBricks projection)
    pure projection
  "skip_taken" -> do
    identity <- textField event "skip"
    brick <- textField event "brick"
    _ <- requireMap "brick" brick (legacyBricks projection)
    reason <- textField event "reason"
    rawText <- optionalTextField event "raw_text"
    pure projection{legacySkips = legacySkips projection <> [LegacySkip identity brick reason rawText (legacyEventAt event)]}
  "wait_recorded" -> do
    identity <- textField event "wait"
    brick <- textField event "brick"
    _ <- requireMap "brick" brick (legacyBricks projection)
    party <- optionalTextField event "party"
    traverse_ (\value -> requireMap "party" value (legacyParties projection)) party
    condition <- optionalTextField event "condition"
    unique "wait" identity (legacyWaits projection)
    let wait = LegacyWait identity brick party condition (legacyEventAt event)
    pure projection{legacyWaits = Map.insert identity wait (legacyWaits projection)}
  "dependency_added" -> do
    blocked <- textField event "blocked"
    blocker <- textField event "blocker"
    _ <- requireMap "brick" blocked (legacyBricks projection)
    _ <- requireMap "brick" blocker (legacyBricks projection)
    when (blocked == blocker) $ Left (migrationError CorruptData "A v0 Brick cannot depend on itself.")
    pure projection{legacyDependencies = Set.insert (blocked, blocker) (legacyDependencies projection)}
  "comparison_recorded" -> do
    identity <- textField event "comparison"
    before <- textField event "before"
    after <- textField event "after"
    author <- textField event "author"
    _ <- requireMap "brick" before (legacyBricks projection)
    _ <- requireMap "brick" after (legacyBricks projection)
    when (before == after) $ Left (migrationError CorruptData "A v0 importance comparison cannot compare one Brick with itself.")
    let comparison = LegacyComparison identity before after author (legacyEventAt event)
        withoutReverse = Map.delete (after, before) (legacyComparisons projection)
    pure projection{legacyComparisons = Map.insert (before, after) comparison withoutReverse}
  "source_attached" -> do
    identity <- textField event "link"
    brick <- textField event "brick"
    _ <- requireMap "brick" brick (legacyBricks projection)
    kind <- textField event "type"
    locator <- textField event "url"
    unique "source link" identity (legacySources projection)
    let source = LegacySource identity brick kind locator Nothing (legacyEventAt event)
    pure projection{legacySources = Map.insert identity source (legacySources projection)}
  "source_checked" -> do
    identity <- textField event "link"
    fingerprint <- textField event "fingerprint"
    source <- requireMap "source link" identity (legacySources projection)
    pure projection{legacySources = Map.insert identity source{legacySourceFingerprint = Just fingerprint} (legacySources projection)}
  "order_sanity_proposed" -> createBrickFromFields projection event "brick" "title"
  unsupported -> Left (migrationError Unsupported ("The validated event type has no v1 projection: " <> unsupported))
 where
  enrich brick =
    brick
      { legacyBrickKind = optional "kind" <|> legacyBrickKind brick
      , legacyBrickContext = optional "context" <|> legacyBrickContext brick
      , legacyBrickWeight = optionalNumber "weight" <|> legacyBrickWeight brick
      , legacyBrickAtomicity = optional "atomicity" <|> legacyBrickAtomicity brick
      , legacyBrickEstimateHours = optionalNumber "estimate_hours" <|> legacyBrickEstimateHours brick
      }
  optional key = either (const Nothing) id (optionalTextField event key)
  optionalNumber key = either (const Nothing) id (optionalDoubleField event key)

createBrickFromFields :: LegacyProjection -> LegacyEvent -> Text -> Text -> Either AppError LegacyProjection
createBrickFromFields projection event identityKey titleKey = do
  identity <- textField event identityKey
  title <- textField event titleKey
  createLegacyBrick projection event identity title

createLegacyBrick :: LegacyProjection -> LegacyEvent -> Text -> Text -> Either AppError LegacyProjection
createLegacyBrick projection event identity title = do
  unique "brick" identity (legacyBricks projection)
  let brick =
        LegacyBrick
          identity
          title
          Nothing
          LegacyActive
          Nothing
          Nothing
          Nothing
          Nothing
          Nothing
          Nothing
          (legacyEventAt event)
          (length (legacyBricks projection))
  pure projection{legacyBricks = Map.insert identity brick (legacyBricks projection)}

touchStage :: LegacyProjection -> LegacyEvent -> LegacyStage -> Either AppError LegacyProjection
touchStage projection event stage = updateBrick projection event (\brick -> brick{legacyBrickStage = stage})

requireBrickOnly :: LegacyProjection -> LegacyEvent -> Either AppError LegacyProjection
requireBrickOnly projection event = do
  identity <- textField event "brick"
  _ <- requireMap "brick" identity (legacyBricks projection)
  pure projection

updateBrick :: LegacyProjection -> LegacyEvent -> (LegacyBrick -> LegacyBrick) -> Either AppError LegacyProjection
updateBrick projection event transform = do
  identity <- textField event "brick"
  brick <- requireMap "brick" identity (legacyBricks projection)
  pure projection{legacyBricks = Map.insert identity (transform brick) (legacyBricks projection)}

supersedeBrick :: LegacyProjection -> LegacyEvent -> Either AppError LegacyProjection
supersedeBrick projection event = do
  oldIdentity <- textField event "brick"
  replacementIdentity <- textField event "replacement"
  title <- textField event "title"
  old <- requireMap "brick" oldIdentity (legacyBricks projection)
  unique "replacement brick" replacementIdentity (legacyBricks projection)
  let replacement =
        old
          { legacyBrickId = replacementIdentity
          , legacyBrickTitle = title
          , legacyBrickDescription = Nothing
          , legacyBrickStage = LegacyActive
          , legacyBrickAtomicity = Nothing
          , legacyBrickWeight = Nothing
          , legacyBrickEstimateHours = Nothing
          , legacyBrickCreatedAt = legacyEventAt event
          , legacyBrickCreatedOrder = length (legacyBricks projection)
          }
      changedOld = old{legacyBrickStage = LegacySuperseded}
      repoint identity = if identity == oldIdentity then replacementIdentity else identity
      dependencies =
        Set.fromList
          [ (repoint blocked, repoint blocker)
          | (blocked, blocker) <- Set.toList (legacyDependencies projection)
          , repoint blocked /= repoint blocker
          ]
      comparisons = repointLegacyComparisons oldIdentity replacementIdentity (legacyComparisons projection)
      copiedSources =
        Map.fromList
          [ let copiedId = legacySourceId source <> ":superseded:" <> replacementIdentity
             in (copiedId, source{legacySourceId = copiedId, legacySourceBrick = replacementIdentity})
          | source <- Map.elems (legacySources projection)
          , legacySourceBrick source == oldIdentity
          ]
  pure
    projection
      { legacyBricks =
          Map.insert replacementIdentity replacement $
            Map.insert oldIdentity changedOld (legacyBricks projection)
      , legacyDependencies = dependencies
      , legacyComparisons = comparisons
      , legacySources = Map.union copiedSources (legacySources projection)
      }

repointLegacyComparisons :: Text -> Text -> Map (Text, Text) LegacyComparison -> Map (Text, Text) LegacyComparison
repointLegacyComparisons oldIdentity replacementIdentity comparisons =
  foldl' insertIfAbsent unaffected repointed
 where
  involves (before, after) = before == oldIdentity || after == oldIdentity
  (affected, unaffected) = Map.partitionWithKey (\pair _ -> involves pair) comparisons
  repoint identity = if identity == oldIdentity then replacementIdentity else identity
  repointed =
    [ ( (before, after)
      , comparison{legacyComparisonBefore = before, legacyComparisonAfter = after}
      )
    | comparison <- Map.elems affected
    , let before = repoint (legacyComparisonBefore comparison)
    , let after = repoint (legacyComparisonAfter comparison)
    , before /= after
    ]
  insertIfAbsent current (key, comparison)
    | Map.member key current = current
    | otherwise = Map.insert key comparison current

validateLegacyProjection :: LegacyProjection -> Either AppError LegacyProjection
validateLegacyProjection projection = do
  let brickIds = Map.keysSet (legacyBricks projection)
      missingBrickRefs =
        [ subject
        | subject <-
            concat
              [ concatMap (\(blocked, blocker) -> [blocked, blocker]) (Set.toList (legacyDependencies projection))
              , concatMap (\comparison -> [legacyComparisonBefore comparison, legacyComparisonAfter comparison]) (Map.elems (legacyComparisons projection))
              , legacyWaitBrick <$> Map.elems (legacyWaits projection)
              , legacySourceBrick <$> Map.elems (legacySources projection)
              , legacySkipBrick <$> legacySkips projection
              ]
        , subject `Set.notMember` brickIds
        ]
  unless (null missingBrickRefs) $
    Left (migrationError CorruptData "The v0 projection contains references to missing Bricks.")
  unless (acyclicDependencies (legacyDependencies projection)) $
    Left (migrationError Conflict "The v0 Dependency graph contains a cycle and cannot be projected safely.")
  pure projection

acyclicDependencies :: Set (Text, Text) -> Bool
acyclicDependencies edges = all (not . reachesSelf) nodes
 where
  nodes = Set.toList (Set.fromList (concatMap (\(a, b) -> [a, b]) (Set.toList edges)))
  reachesSelf origin = go Set.empty origin origin
  go visited origin current
    | current `Set.member` visited = False
    | otherwise =
        any
          (\next -> next == origin || go (Set.insert current visited) origin next)
          [blocker | (blocked, blocker) <- Set.toList edges, blocked == current]

textField :: LegacyEvent -> Text -> Either AppError Text
textField event key = case KeyMap.lookup (fromStringKey key) (legacyEventData event) of
  Just (String value) | not (Text.null (Text.strip value)) -> Right value
  _ -> Left (migrationError CorruptData (legacyEventType event <> " has an invalid " <> key <> " field."))

optionalTextField :: LegacyEvent -> Text -> Either AppError (Maybe Text)
optionalTextField event key = case KeyMap.lookup (fromStringKey key) (legacyEventData event) of
  Nothing -> Right Nothing
  Just Null -> Right Nothing
  Just (String value) | not (Text.null (Text.strip value)) -> Right (Just value)
  _ -> Left (migrationError CorruptData (legacyEventType event <> " has an invalid optional " <> key <> " field."))

optionalDoubleField :: LegacyEvent -> Text -> Either AppError (Maybe Double)
optionalDoubleField event key = case KeyMap.lookup (fromStringKey key) (legacyEventData event) of
  Nothing -> Right Nothing
  Just Null -> Right Nothing
  Just value -> case fromJSON value of
    Success number -> Right (Just number)
    Error _ -> Left (migrationError CorruptData (legacyEventType event <> " has an invalid optional " <> key <> " field."))

seedsField :: LegacyEvent -> Either AppError [(Text, Text)]
seedsField event = case KeyMap.lookup "seeds" (legacyEventData event) of
  Just value -> case parseEither (parseJSON >=> traverse parseSeed) value of
    Left detail -> Left (migrationError CorruptData ("Invalid seeds_extracted payload: " <> Text.pack detail))
    Right seeds -> Right seeds
  Nothing -> Left (migrationError CorruptData "A seeds_extracted event has no seeds field.")
 where
  parseSeed = withObject "seed" (\seed -> (,) <$> seed .: "brick" <*> seed .: "title")

unique :: (Ord key) => Text -> key -> Map key value -> Either AppError ()
unique label identity values = when (Map.member identity values) (Left (migrationError CorruptData ("A v0 " <> label <> " ID is repeated.")))

requireMap :: (Ord key) => Text -> key -> Map key value -> Either AppError value
requireMap label identity values = maybe (Left (migrationError CorruptData ("A v0 event references a missing " <> label <> "."))) Right (Map.lookup identity values)

lineProblem :: Int -> Text -> AppError
lineProblem lineNumber detail =
  (migrationError CorruptData "The v0 event log failed strict preflight.")
    { appErrorDetails = ["line " <> tshow lineNumber <> ": " <> detail]
    }

migrationError :: ErrorCode -> Text -> AppError
migrationError code message =
  (appError code message)
    { appErrorRecovery = [RecoveryAction "inspect-source" "Keep the v0 source untouched, correct or upgrade the migrator, then inspect again." (Just "lant migrate")]
    }

tshow :: (Show value) => value -> Text
tshow = Text.pack . show

data MigrationPaths = MigrationPaths
  { migrationTargetRoot :: FilePath
  , migrationCandidateRoot :: FilePath
  , migrationBackupRoot :: FilePath
  , migrationBuildReceiptPath :: FilePath
  , migrationPendingPath :: FilePath
  , migrationCompletePath :: FilePath
  }
  deriving stock (Eq, Show)

data BuildReceipt = BuildReceipt
  { buildReceiptPolicyVersion :: Text
  , buildReceiptSourceDigest :: Text
  , buildReceiptSourceBytes :: Int
  , buildReceiptLegacyEvents :: Int
  , buildReceiptCandidateCursor :: DatasetCursor
  , buildReceiptCandidateEvents :: Integer
  }
  deriving stock (Eq, Show)

instance ToJSON BuildReceipt where
  toJSON receipt =
    object
      [ "schema" .= ("little-ant/v0-migration-build@1" :: Text)
      , "policy_version" .= buildReceiptPolicyVersion receipt
      , "source_sha256" .= buildReceiptSourceDigest receipt
      , "source_bytes" .= buildReceiptSourceBytes receipt
      , "legacy_event_count" .= buildReceiptLegacyEvents receipt
      , "candidate_cursor" .= buildReceiptCandidateCursor receipt
      , "candidate_event_count" .= buildReceiptCandidateEvents receipt
      ]

instance FromJSON BuildReceipt where
  parseJSON = withObject "v0 migration build receipt" $ \value -> do
    schema <- value .: "schema"
    unless (schema == ("little-ant/v0-migration-build@1" :: Text)) (fail "unsupported build receipt schema")
    BuildReceipt
      <$> value .: "policy_version"
      <*> value .: "source_sha256"
      <*> value .: "source_bytes"
      <*> value .: "legacy_event_count"
      <*> value .: "candidate_cursor"
      <*> value .: "candidate_event_count"

data PendingCutover = PendingCutover
  { pendingSourceDigest :: Text
  , pendingCandidateCursor :: DatasetCursor
  , pendingCandidateEvents :: Integer
  , pendingCandidateRoot :: FilePath
  , pendingBackupRoot :: FilePath
  }
  deriving stock (Eq, Show)

instance ToJSON PendingCutover where
  toJSON pending =
    object
      [ "schema" .= ("little-ant/v0-migration-cutover@1" :: Text)
      , "source_sha256" .= pendingSourceDigest pending
      , "candidate_cursor" .= pendingCandidateCursor pending
      , "candidate_event_count" .= pendingCandidateEvents pending
      , "candidate_root" .= pendingCandidateRoot pending
      , "backup_root" .= pendingBackupRoot pending
      ]

instance FromJSON PendingCutover where
  parseJSON = withObject "v0 migration cutover journal" $ \value -> do
    schema <- value .: "schema"
    unless (schema == ("little-ant/v0-migration-cutover@1" :: Text)) (fail "unsupported cutover journal schema")
    PendingCutover
      <$> value .: "source_sha256"
      <*> value .: "candidate_cursor"
      <*> value .: "candidate_event_count"
      <*> value .: "candidate_root"
      <*> value .: "backup_root"

data BuildState = BuildState
  { builtDataset :: LoadedDataset
  , builtBrickIds :: Map Text UUIDv7
  , builtBrickRawIds :: Map Text UUIDv7
  , builtLegacyRawIds :: Map Text UUIDv7
  , builtPartyIds :: Map Text UUIDv7
  , builtDomainIds :: Map Text UUIDv7
  }
  deriving stock (Eq, Show)

runV0Migration :: StoreConfig -> Actor -> IO UTCTime -> Bool -> Maybe FilePath -> MigrationStage -> IO (Either AppError MigrationReport)
runV0Migration targetStore actor clock dryRun sourceOverride stage = handleMigrationIO $ do
  sourcePath <- maybe defaultV0SourcePath pure sourceOverride
  sourceExists <- doesFileExist sourcePath
  unless sourceExists (ioError (userError ("v0 source does not exist: " <> sourcePath)))
  sourceBytes <- ByteString.readFile sourcePath
  case parseLegacyLog sourceBytes of
    Left problem -> pure (Left problem)
    Right projection -> do
      let sourceDigest = sha256Hex sourceBytes
          paths = migrationPaths targetStore sourceDigest
      current <- loadDataset targetStore (const (pure ()))
      case current of
        Left problem -> pure (Left problem)
        Right live ->
          case stage of
            MigrationInspect ->
              pure $ do
                requireEmptyTarget paths live
                Right (reportFor stage sourcePath sourceDigest sourceBytes projection paths Nothing False dryRun)
            MigrationBuild -> do
              case requireEmptyTarget paths live of
                Left problem -> pure (Left problem)
                Right ()
                  | dryRun -> pure (Right (reportFor stage sourcePath sourceDigest sourceBytes projection paths Nothing False True))
                  | otherwise -> do
                      now <- clock
                      buildOrReuseCandidate targetStore actor now sourcePath sourceBytes sourceDigest projection paths >>= \case
                        Left problem -> pure (Left problem)
                        Right candidate ->
                          pure (Right (reportFor stage sourcePath sourceDigest sourceBytes projection paths (Just (loadedCursor candidate)) False False))
            MigrationCutover
              | dryRun -> inspectCutover sourcePath sourceBytes sourceDigest projection paths live True
              | otherwise -> performCutover targetStore sourcePath sourceBytes sourceDigest projection paths live

defaultV0SourcePath :: IO FilePath
defaultV0SourcePath = do
  root <- getXdgDirectory XdgData "little-ant"
  pure (root </> "events.jsonl")

migrationPaths :: StoreConfig -> Text -> MigrationPaths
migrationPaths targetStore digest =
  let target = storeRoot targetStore
      parent = takeDirectory target
      base = takeFileName target
      suffix = Text.unpack (Text.take 16 digest)
      stem = "." <> base <> ".v0-alpha-" <> suffix
   in MigrationPaths
        target
        (parent </> (base <> ".v0-alpha-" <> suffix <> ".candidate"))
        (parent </> (base <> ".pre-v1-alpha-" <> suffix))
        (parent </> (stem <> ".build.json"))
        (parent </> (stem <> ".pending.json"))
        (parent </> (stem <> ".complete.json"))

reportFor :: MigrationStage -> FilePath -> Text -> ByteString -> LegacyProjection -> MigrationPaths -> Maybe DatasetCursor -> Bool -> Bool -> MigrationReport
reportFor stage sourcePath sourceDigest _sourceBytes projection paths candidateCursor complete dryRun =
  MigrationReport
    stage
    sourcePath
    sourceDigest
    (length (legacyEvents projection))
    (Map.size (legacyBricks projection))
    (Map.size (legacyRaws projection))
    (Map.keys supportedVersions)
    (if stage == MigrationInspect then Nothing else Just (migrationCandidateRoot paths))
    (if stage == MigrationCutover then Just (migrationBackupRoot paths) else Nothing)
    candidateCursor
    complete
    dryRun

requireEmptyTarget :: MigrationPaths -> LoadedDataset -> Either AppError ()
requireEmptyTarget paths dataset =
  unless (loadedCursor dataset == Genesis && loadedEventCount dataset == 0) $
    Left
      ( (migrationError PreconditionFailed "The selected v1 profile is not empty; alpha migration never merges histories.")
          { appErrorDetails = ["target: " <> Text.pack (migrationTargetRoot paths), "cursor: " <> renderCursor (loadedCursor dataset)]
          , appErrorRecovery = [RecoveryAction "select-empty-profile" "Select or create an empty v1 profile, then inspect again." (Just "lant profile create migrated-v0")]
          }
      )

buildOrReuseCandidate :: StoreConfig -> Actor -> UTCTime -> FilePath -> ByteString -> Text -> LegacyProjection -> MigrationPaths -> IO (Either AppError LoadedDataset)
buildOrReuseCandidate targetStore actor now sourcePath sourceBytes sourceDigest projection paths = do
  existingReceipt <- readJsonIfExists (migrationBuildReceiptPath paths)
  candidateExists <- doesPathExist (migrationCandidateRoot paths)
  case (candidateExists, existingReceipt) of
    (True, Right (Just receipt))
      | receiptMatches sourceBytes sourceDigest projection receipt -> validateCandidate paths receipt
    (True, _) -> do
      quarantine <- quarantinePath (migrationCandidateRoot paths)
      renamePath (migrationCandidateRoot paths) quarantine
      buildFresh
    (False, Right (Just _)) ->
      pure . Left $
        (migrationError CorruptData "A migration build receipt exists but its candidate directory is missing.")
          { appErrorDetails = ["receipt: " <> Text.pack (migrationBuildReceiptPath paths)]
          }
    (False, Left problem) -> pure (Left problem)
    (False, Right Nothing) -> buildFresh
 where
  buildFresh = do
    createDirectoryIfMissing True (takeDirectory (migrationCandidateRoot paths))
    let candidateStore = targetStore{storeRoot = migrationCandidateRoot paths}
    initializeDataset candidateStore
    buildCandidate candidateStore actor now projection >>= \case
      Left problem -> pure (Left problem)
      Right built -> do
        let legacyDirectory = migrationCandidateRoot paths </> "legacy" </> "v0"
            archivePath = legacyDirectory </> "events.jsonl"
            manifestPath = legacyDirectory </> "manifest.json"
        createDirectoryIfMissing True legacyDirectory
        writeBytesDurably legacyDirectory archivePath sourceBytes
        writeJsonDurably
          legacyDirectory
          manifestPath
          (legacyManifest sourcePath sourceDigest projection built)
        let dataset = builtDataset built
            receipt =
              BuildReceipt
                migrationPolicyVersion
                sourceDigest
                (ByteString.length sourceBytes)
                (length (legacyEvents projection))
                (loadedCursor dataset)
                (loadedEventCount dataset)
        writeJsonDurably (migrationCandidateRoot paths) (migrationCandidateRoot paths </> "migration-receipt.json") receipt
        writeJsonDurably (takeDirectory (migrationBuildReceiptPath paths)) (migrationBuildReceiptPath paths) receipt
        validateCandidate paths receipt

receiptMatches :: ByteString -> Text -> LegacyProjection -> BuildReceipt -> Bool
receiptMatches sourceBytes sourceDigest projection receipt =
  buildReceiptPolicyVersion receipt == migrationPolicyVersion
    && buildReceiptSourceDigest receipt == sourceDigest
    && buildReceiptSourceBytes receipt == ByteString.length sourceBytes
    && buildReceiptLegacyEvents receipt == length (legacyEvents projection)

validateCandidate :: MigrationPaths -> BuildReceipt -> IO (Either AppError LoadedDataset)
validateCandidate paths receipt = do
  let store = StoreConfig (migrationCandidateRoot paths) 5000000 25000
  loadDataset store (const (pure ())) >>= \case
    Left problem -> pure (Left problem)
    Right dataset
      | loadedCursor dataset /= buildReceiptCandidateCursor receipt || loadedEventCount dataset /= buildReceiptCandidateEvents receipt ->
          pure . Left $
            (migrationError CorruptData "The isolated migration candidate does not match its durable build receipt.")
              { appErrorDetails = ["candidate: " <> Text.pack (migrationCandidateRoot paths)]
              }
      | otherwise -> do
          let archivePath = migrationCandidateRoot paths </> "legacy" </> "v0" </> "events.jsonl"
          archiveExists <- doesFileExist archivePath
          if not archiveExists
            then pure (Left (migrationError CorruptData "The migration candidate is missing its exact v0 source archive."))
            else do
              archive <- ByteString.readFile archivePath
              if sha256Hex archive == buildReceiptSourceDigest receipt && ByteString.length archive == buildReceiptSourceBytes receipt
                then pure (Right dataset)
                else pure (Left (migrationError CorruptData "The migration candidate's v0 source archive does not match its build receipt."))

buildCandidate :: StoreConfig -> Actor -> UTCTime -> LegacyProjection -> IO (Either AppError BuildState)
buildCandidate store actor now projection = do
  loadDataset store (const (pure ())) >>= \case
    Left problem -> pure (Left problem)
    Right genesis -> do
      let initial = BuildState genesis Map.empty Map.empty Map.empty Map.empty Map.empty
      buildParties initial >>= bindEither buildDomains >>= bindEither buildLegacyRaws >>= bindEither buildBricks >>= bindEither buildDescriptions >>= bindEither buildSources >>= bindEither buildDependencies >>= bindEither buildComparisons >>= bindEither buildSkips >>= bindEither buildWaits >>= bindEither buildPhases >>= bindEither buildLifecycle
 where
  buildParties current =
    foldBuild current (sortOn legacyPartyAt (Map.elems (legacyParties projection))) $ \state party -> do
      facts <- migrationFacts (legacyPartyAt party) 3 (builtDataset state)
      pure $ do
        decision <- decideRegisterExternalEntity (loadedState (builtDataset state)) actor (legacyEntityKind (legacyPartyType party)) (legacyPartyName party) facts
        entityId <- eventRegisteredEntityId (mutationDecisionEvents decision)
        Right (mutationDecisionEvents decision, state{builtPartyIds = Map.insert (legacyPartyId party) entityId (builtPartyIds state)})

  buildDomains current =
    foldBuild current domainPaths $ \state path -> do
      facts <- migrationFacts now 3 (builtDataset state)
      pure $ do
        allocated <- factsUUIDs facts
        (commandId, domainId, eventId) <- exactlyThreeIds allocated
        let parentPath = parentDomainPath path
            parentId = parentPath >>= (`Map.lookup` builtDomainIds state)
            name = last (Text.splitOn " › " path)
            domain = Domain domainId name parentId True
            draft = directDraft actor (loadedState (builtDataset state)) facts commandId eventId (DomainRegisteredV1 (DomainRegistered domain))
        Right ([draft], state{builtDomainIds = Map.insert path domainId (builtDomainIds state)})
   where
    domainPaths =
      sortOn (\path -> (length (Text.splitOn " › " path), path)) . Set.toList . Set.fromList $
        concatMap contextPrefixes [context | brick <- Map.elems (legacyBricks projection), Just context <- [legacyBrickContext brick]]

  buildLegacyRaws current =
    foldBuild current (sortOn legacyRawAt (Map.elems (legacyRaws projection))) $ \state raw -> do
      feedFacts <- migrationFacts (legacyRawAt raw) 3 (builtDataset state)
      case decideFeed (loadedState (builtDataset state)) actor "migration:v0-raw" (legacyRawContent raw) feedFacts of
        Left problem -> pure (Left problem)
        Right feed ->
          appendBuilt store state (feedDecisionEvents feed) >>= \case
            Left problem -> pure (Left problem)
            Right accepted -> do
              let mappedRaw =
                    accepted
                      { builtLegacyRawIds =
                          Map.insert
                            (legacyRawId raw)
                            (rawId (feedDecisionRaw feed))
                            (builtLegacyRawIds accepted)
                      }
              keepFacts <- migrationFacts (legacyRawAt raw) 2 (builtDataset mappedRaw)
              pure $ do
                decision <- decideKeepRawStandalone (loadedState (builtDataset mappedRaw)) actor (rawId (feedDecisionRaw feed)) keepFacts
                Right (mutationDecisionEvents decision, mappedRaw)

  buildBricks current =
    foldBuild current orderedBricks $ \state brick -> do
      feedFacts <- migrationFacts (legacyBrickCreatedAt brick) 3 (builtDataset state)
      case decideFeed (loadedState (builtDataset state)) actor "migration:v0-brick-title" (legacyBrickTitle brick) feedFacts of
        Left problem -> pure (Left problem)
        Right feed ->
          appendBuilt store state (feedDecisionEvents feed) >>= \case
            Left problem -> pure (Left problem)
            Right fedState -> do
              materializeFacts <- migrationFacts (legacyBrickCreatedAt brick) 6 (builtDataset fedState)
              let currentState = loadedState (builtDataset fedState)
                  siblings = siblingBricks currentState Nothing
                  confidence = if null siblings then DeterministicPosition "migrated v0 order" else Provisional "migrated v0 order"
                  domains = maybe Set.empty (maybe Set.empty Set.singleton . (`Map.lookup` builtDomainIds fedState) . normalizeContext) (legacyBrickContext brick)
                  draft = WorkDraft (rawId (feedDecisionRaw feed)) (legacyBrickTitle brick) (legacyNature brick) Nothing Nothing domains (length siblings) confidence []
              pure $ do
                decision <- decideMaterializeWork currentState actor draft materializeFacts
                created <- maybe (Left (migrationError CorruptData "Materializing a migrated v0 Brick returned no Brick.")) Right (mutationDecisionBrick decision)
                let updated =
                      fedState
                        { builtBrickIds = Map.insert (legacyBrickId brick) (brickId created) (builtBrickIds fedState)
                        , builtBrickRawIds = Map.insert (legacyBrickId brick) (rawId (feedDecisionRaw feed)) (builtBrickRawIds fedState)
                        }
                Right (mutationDecisionEvents decision, updated)
   where
    orderedBricks = sortOn legacyBrickCreatedOrder (Map.elems (legacyBricks projection))

  buildDescriptions current =
    foldBuild current described $ \state brick -> do
      case legacyBrickDescription brick of
        Nothing -> pure (Left (migrationError CorruptData "A v0 Brick escaped description filtering."))
        Just description -> case Map.lookup (legacyBrickId brick) (builtBrickIds state) of
          Nothing -> pure (Left (migrationError CorruptData "A described v0 Brick was not mapped."))
          Just brickId -> case descriptionUpdateUUIDCount (loadedState (builtDataset state)) brickId of
            Left problem -> pure (Left problem)
            Right count -> do
              facts <- migrationFacts now count (builtDataset state)
              pure $ do
                decision <- decideUpdateBrickDescription (loadedState (builtDataset state)) actor brickId description facts
                Right (mutationDecisionEvents decision, state)
   where
    described = [brick | brick <- sortOn legacyBrickCreatedOrder (Map.elems (legacyBricks projection)), isJust (legacyBrickDescription brick)]

  buildSources current =
    foldBuild current (sortOn legacySourceAt (Map.elems (legacySources projection))) $ \state source -> do
      facts <- migrationFacts (legacySourceAt source) 3 (builtDataset state)
      pure $ do
        rawIdValue <- mapped "source Brick Raw" (legacySourceBrick source) (builtBrickRawIds state)
        decision <-
          decideAttachSourceBinding
            (loadedState (builtDataset state))
            actor
            rawIdValue
            (legacySourceKind source)
            Nothing
            (Just (legacySourceId source))
            Nothing
            (legacySourceLocator source)
            SourceMigrate
            SourceManualCheck
            facts
        Right (mutationDecisionEvents decision, state)

  buildDependencies current =
    foldBuild current (Set.toAscList (legacyDependencies projection)) $ \state (blocked, blocker) -> do
      facts <- migrationFacts now 3 (builtDataset state)
      pure $ do
        blockedId <- mapped "blocked Brick" blocked (builtBrickIds state)
        blockerId <- mapped "blocker Brick" blocker (builtBrickIds state)
        decision <- decideAddDependency (loadedState (builtDataset state)) actor blockedId blockerId "migration:v0" facts
        Right (mutationDecisionEvents decision, state)

  buildComparisons current =
    foldBuild current (sortOn legacyComparisonAt (Map.elems (legacyComparisons projection))) $ \state comparison -> do
      facts <- migrationFacts (legacyComparisonAt comparison) 2 (builtDataset state)
      pure $ do
        before <- mapped "importance Brick" (legacyComparisonBefore comparison) (builtBrickIds state)
        after <- mapped "importance Brick" (legacyComparisonAfter comparison) (builtBrickIds state)
        decision <-
          decidePairJudgment
            (loadedState (builtDataset state))
            actor
            ImportanceAxis
            before
            after
            MoreThan
            (if legacyComparisonAuthor comparison == "human" then DirectHuman else ModelOnly "v0")
            JudgmentCurrent
            []
            "migration:v0"
            "preserved direct v0 importance judgment"
            facts
        Right (judgmentMutationEvents decision, state)

  buildSkips current =
    foldBuild current (sortOn legacySkipAt (legacySkips projection)) $ \state skip -> do
      facts <- migrationFacts (legacySkipAt skip) 2 (builtDataset state)
      pure $ do
        brickId <- mapped "skipped Brick" (legacySkipBrick skip) (builtBrickIds state)
        decision <- decideWorkReaction (loadedState (builtDataset state)) actor brickId Nothing (legacySkipSymptom skip) SkipAnywayReaction facts
        Right (mutationDecisionEvents decision, state)

  buildWaits current =
    foldBuild current (sortOn legacyWaitAt (Map.elems (legacyWaits projection))) $ \state legacyWait -> do
      facts <- migrationFacts now 4 (builtDataset state)
      pure $ do
        brickId <- mapped "waiting Brick" (legacyWaitBrick legacyWait) (builtBrickIds state)
        kind <- case legacyWaitParty legacyWait of
          Just party -> HumanResponseWait <$> mapped "wait person or company" party (builtPartyIds state)
          Nothing -> Right (ExternalConditionWait (fromMaybe "legacy v0 condition" (legacyWaitCondition legacyWait)))
        decision <- decideActivateWait (loadedState (builtDataset state)) actor brickId kind (ZonedInstant (addUTCTime (7 * 24 * 60 * 60) now) "Etc/UTC") facts
        Right (mutationDecisionEvents decision, state)

  buildPhases current =
    foldBuild current phased $ \state brick -> do
      facts <- migrationFacts now 2 (builtDataset state)
      pure $ do
        brickId <- mapped "phase Brick" (legacyBrickId brick) (builtBrickIds state)
        phase <- case legacyBrickKind brick of
          Just "spec" -> Right SpecPhase
          Just "exec" -> Right ExecutionPhase
          _ -> Left (migrationError CorruptData "An unsupported v0 Kind escaped phase filtering.")
        decision <- decidePhase (loadedState (builtDataset state)) actor brickId (Just phase) DeterministicProvisional facts
        Right (judgmentMutationEvents decision, state)
   where
    phased = [brick | brick <- Map.elems (legacyBricks projection), legacyBrickKind brick `elem` [Just "spec", Just "exec"]]

  buildLifecycle current =
    foldBuild current lifecycle $ \state brick -> do
      facts <- migrationFacts now 2 (builtDataset state)
      pure $ do
        brickId <- mapped "lifecycle Brick" (legacyBrickId brick) (builtBrickIds state)
        allocated <- factsUUIDs facts
        (commandId, eventId) <- exactlyTwoIds allocated
        payload <- lifecyclePayload brickId brick
        let event = directDraft actor (loadedState (builtDataset state)) facts commandId eventId payload
        Right ([event], state)
   where
    lifecycle = [brick | brick <- sortOn legacyBrickCreatedOrder (Map.elems (legacyBricks projection)), legacyBrickStage brick /= LegacyActive]

  foldBuild initial values make = go initial values
   where
    go state [] = pure (Right state)
    go state (value : rest) =
      make state value >>= \case
        Left problem -> pure (Left problem)
        Right (events, projectedState) ->
          appendBuilt store projectedState events >>= \case
            Left problem -> pure (Left problem)
            Right accepted -> go accepted rest

bindEither :: (value -> IO (Either AppError next)) -> Either AppError value -> IO (Either AppError next)
bindEither _ (Left problem) = pure (Left problem)
bindEither action (Right value) = action value

appendBuilt :: StoreConfig -> BuildState -> [EventDraft] -> IO (Either AppError BuildState)
appendBuilt store state events =
  appendCommand store (loadedCursor (builtDataset state)) events >>= \case
    Left problem -> pure (Left problem)
    Right accepted -> pure (Right state{builtDataset = accepted})

migrationFacts :: UTCTime -> Int -> LoadedDataset -> IO RuntimeFacts
migrationFacts now count dataset = do
  identities <- replicateM count generateUUIDv7
  pure
    RuntimeFacts
      { runtimeNow = now
      , runtimeUUIDs = UUIDAllocation . renderUUIDv7 <$> identities
      , runtimeRandomBlocks = Map.empty
      , runtimeFilesystem = FilesystemFacts True True (Just (renderCursor (loadedCursor dataset)))
      , runtimeTerminal = TerminalCapabilities False False False 80 24 False
      , runtimeExternalFacts = []
      }

factsUUIDs :: RuntimeFacts -> Either AppError [UUIDv7]
factsUUIDs facts = traverse (either (const (Left (migrationError CorruptData "The migration runtime allocated an invalid UUIDv7."))) Right . parseUUIDv7 . unUUIDAllocation) (runtimeUUIDs facts)

exactlyTwoIds :: [UUIDv7] -> Either AppError (UUIDv7, UUIDv7)
exactlyTwoIds [first, second] = Right (first, second)
exactlyTwoIds _ = Left (migrationError PreconditionFailed "The migration UUID allocation count changed unexpectedly.")

exactlyThreeIds :: [UUIDv7] -> Either AppError (UUIDv7, UUIDv7, UUIDv7)
exactlyThreeIds [first, second, third] = Right (first, second, third)
exactlyThreeIds _ = Left (migrationError PreconditionFailed "The migration UUID allocation count changed unexpectedly.")

directDraft :: Actor -> State -> RuntimeFacts -> UUIDv7 -> UUIDv7 -> EventPayload -> EventDraft
directDraft actor state facts commandId eventId payload =
  EventDraft eventId commandId actor (runtimeNow facts) (statePreconditionHash state) (either (const []) id (factsUUIDs facts)) payload

eventRegisteredEntityId :: [EventDraft] -> Either AppError UUIDv7
eventRegisteredEntityId events = case [externalEntityId entity | EventDraft{draftPayload = ExternalEntityRegisteredV1 (ExternalEntityRegistered entity)} <- events] of
  [identity] -> Right identity
  _ -> Left (migrationError CorruptData "Registering a migrated v0 person or company returned no canonical identity.")

legacyEntityKind :: Text -> ExternalEntityKind
legacyEntityKind = \case
  "person" -> PersonEntity
  "ai_agent" -> AIAgentEntity
  "company" -> OrganizationEntity
  "area" -> TeamEntity
  _ -> ServiceEntity

legacyNature :: LegacyBrick -> BrickNature
legacyNature brick = if legacyBrickAtomicity brick == Just "divisible" then Project else AtomicTask

legacySkipSymptom :: LegacySkip -> SkipSymptom
legacySkipSymptom skip = case legacySkipReason skip of
  "hard" -> HardSymptom
  "vague" -> VagueSymptom
  "not_priority" -> LessImportantSymptom
  "waiting" -> WaitingSymptom
  "tired" -> TiredSymptom
  "meh" -> BoredSymptom
  "kill" -> OutOfDateSymptom
  "alternatives" -> OtherSymptom "alternatives"
  _ -> OtherSymptom (fromMaybe "legacy v0 other" (legacySkipRawText skip))

lifecyclePayload :: UUIDv7 -> LegacyBrick -> Either AppError EventPayload
lifecyclePayload identity brick = case legacyBrickStage brick of
  LegacyWip -> Right (BrickFocusedV1 (BrickFocused identity))
  LegacyDone -> Right (BrickCompletedV1 (BrickCompleted identity))
  LegacyArchived -> Right (BrickStatusChangedV1 (BrickStatusChanged identity BrickActive BrickArchived "migrated v0 killed state"))
  LegacySuperseded -> Right (BrickStatusChangedV1 (BrickStatusChanged identity BrickActive BrickSuperseded "migrated v0 superseded state"))
  LegacyActive -> Left (migrationError CorruptData "An active v0 Brick entered the lifecycle projection.")

mapped :: Text -> Text -> Map Text UUIDv7 -> Either AppError UUIDv7
mapped label legacyIdentity identities =
  maybe (Left (migrationError CorruptData ("No canonical identity exists for the migrated " <> label <> "."))) Right (Map.lookup legacyIdentity identities)

normalizeContext :: Text -> Text
normalizeContext = Text.intercalate " › " . contextParts

contextParts :: Text -> [Text]
contextParts = filter (not . Text.null) . fmap Text.strip . Text.split (\character -> character == '/' || character == '›')

contextPrefixes :: Text -> [Text]
contextPrefixes context =
  [Text.intercalate " › " (take count parts) | count <- [1 .. length parts]]
 where
  parts = contextParts context

parentDomainPath :: Text -> Maybe Text
parentDomainPath path = case Text.splitOn " › " path of
  [_] -> Nothing
  parts -> Just (Text.intercalate " › " (init parts))

legacyManifest :: FilePath -> Text -> LegacyProjection -> BuildState -> Value
legacyManifest sourcePath sourceDigest projection built =
  object
    [ "schema" .= ("little-ant/v0-migration-manifest@1" :: Text)
    , "policy_version" .= migrationPolicyVersion
    , "source_path" .= sourcePath
    , "source_sha256" .= sourceDigest
    , "legacy_event_count" .= length (legacyEvents projection)
    , "supported_event_types" .= Map.keys supportedVersions
    , "brick_identity_map" .= Map.map renderUUIDv7 (builtBrickIds built)
    , "raw_identity_map" .= Map.map renderUUIDv7 (builtLegacyRawIds built)
    , "party_identity_map" .= Map.map renderUUIDv7 (builtPartyIds built)
    , "domain_identity_map" .= Map.map renderUUIDv7 (builtDomainIds built)
    , "preserved_historical_fields"
        .= ( [ "v0 stage transitions"
             , "requester attribution"
             , "source fingerprints"
             , "weight"
             , "estimate_hours"
             , "flow history"
             , "serve counts"
             , "original event timestamps and intrinsic IDs"
             ] ::
               [Text]
           )
    , "note" .= ("The exact source JSONL beside this manifest is authoritative for v0-only historical fields." :: Text)
    ]

migrationPolicyVersion :: Text
migrationPolicyVersion = "v1-alpha-observed-25@1"

inspectCutover :: FilePath -> ByteString -> Text -> LegacyProjection -> MigrationPaths -> LoadedDataset -> Bool -> IO (Either AppError MigrationReport)
inspectCutover sourcePath sourceBytes sourceDigest projection paths live dryRun = do
  readJsonIfExists (migrationBuildReceiptPath paths) >>= \case
    Left problem -> pure (Left problem)
    Right Nothing ->
      pure . Left $
        (migrationError PreconditionFailed "No isolated v0 migration candidate has been built.")
          { appErrorRecovery = [RecoveryAction "build" "Build and replay the isolated candidate before cutover." (Just "lant migrate --build")]
          }
    Right (Just receipt)
      | not (receiptMatches sourceBytes sourceDigest projection receipt) -> pure (Left (migrationError Conflict "The v0 source changed after the candidate was built; inspect and build again."))
      | otherwise -> do
          completeExists <- doesFileExist (migrationCompletePath paths)
          pendingExists <- doesFileExist (migrationPendingPath paths)
          if completeExists
            then
              if loadedCursor live == buildReceiptCandidateCursor receipt && loadedEventCount live == buildReceiptCandidateEvents receipt
                then pure (Right (reportFor MigrationCutover sourcePath sourceDigest sourceBytes projection paths (Just (buildReceiptCandidateCursor receipt)) True dryRun))
                else pure (Left (migrationError CorruptData "The completed migration receipt does not match the live v1 dataset."))
            else
              if pendingExists || loadedCursor live == Genesis
                then
                  validateCandidate paths receipt >>= \case
                    Left _problem | pendingExists -> inspectInterruptedCutover sourcePath sourceBytes sourceDigest projection paths live receipt dryRun
                    Left problem -> pure (Left problem)
                    Right _ -> pure (Right (reportFor MigrationCutover sourcePath sourceDigest sourceBytes projection paths (Just (buildReceiptCandidateCursor receipt)) False dryRun))
                else pure (Left (migrationError PreconditionFailed "The selected v1 profile is not empty and no matching cutover journal exists."))

performCutover :: StoreConfig -> FilePath -> ByteString -> Text -> LegacyProjection -> MigrationPaths -> LoadedDataset -> IO (Either AppError MigrationReport)
performCutover targetStore sourcePath sourceBytes sourceDigest projection paths live = do
  inspectCutover sourcePath sourceBytes sourceDigest projection paths live False >>= \case
    Left problem -> pure (Left problem)
    Right inspected
      | migrationCutoverComplete inspected -> pure (Right inspected)
      | otherwise -> do
          receiptResult <- readJsonIfExists (migrationBuildReceiptPath paths)
          case receiptResult of
            Left problem -> pure (Left problem)
            Right Nothing -> pure (Left (migrationError PreconditionFailed "The migration build receipt disappeared before cutover."))
            Right (Just receipt) -> do
              pendingExists <- doesFileExist (migrationPendingPath paths)
              if pendingExists
                then finishInterruptedCutover targetStore sourcePath sourceBytes sourceDigest projection paths receipt
                else do
                  let pending = PendingCutover sourceDigest (buildReceiptCandidateCursor receipt) (buildReceiptCandidateEvents receipt) (migrationCandidateRoot paths) (migrationBackupRoot paths)
                  backupExists <- doesPathExist (migrationBackupRoot paths)
                  when backupExists (ioError (userError ("migration backup path already exists: " <> migrationBackupRoot paths)))
                  validateCutoverRoots paths
                  writeJsonDurably (takeDirectory (migrationPendingPath paths)) (migrationPendingPath paths) pending
                  renameExchange (migrationTargetRoot paths) (migrationCandidateRoot paths) >>= \case
                    Left problem -> pure (Left problem)
                    Right () -> do
                      syncDirectory (takeDirectory (migrationTargetRoot paths))
                      finishInterruptedCutover targetStore sourcePath sourceBytes sourceDigest projection paths receipt

inspectInterruptedCutover :: FilePath -> ByteString -> Text -> LegacyProjection -> MigrationPaths -> LoadedDataset -> BuildReceipt -> Bool -> IO (Either AppError MigrationReport)
inspectInterruptedCutover sourcePath sourceBytes sourceDigest projection paths live receipt dryRun
  | loadedCursor live == buildReceiptCandidateCursor receipt && loadedEventCount live == buildReceiptCandidateEvents receipt =
      pure (Right (reportFor MigrationCutover sourcePath sourceDigest sourceBytes projection paths (Just (loadedCursor live)) False dryRun))
  | otherwise = pure (Left (migrationError CorruptData "The interrupted cutover state does not match either the empty target or the validated candidate."))

finishInterruptedCutover :: StoreConfig -> FilePath -> ByteString -> Text -> LegacyProjection -> MigrationPaths -> BuildReceipt -> IO (Either AppError MigrationReport)
finishInterruptedCutover targetStore sourcePath sourceBytes sourceDigest projection paths receipt = do
  liveResult <- loadDataset targetStore (const (pure ()))
  case liveResult of
    Left problem -> pure (Left problem)
    Right live
      | loadedCursor live /= buildReceiptCandidateCursor receipt || loadedEventCount live /= buildReceiptCandidateEvents receipt ->
          pure (Left (migrationError CorruptData "The live profile does not match the candidate promised by the pending cutover journal."))
      | otherwise -> do
          candidateExists <- doesPathExist (migrationCandidateRoot paths)
          backupExists <- doesPathExist (migrationBackupRoot paths)
          case (candidateExists, backupExists) of
            (True, False) -> renameNoReplace (migrationCandidateRoot paths) (migrationBackupRoot paths) >>= finish live
            (False, True) -> finish live (Right ())
            _ -> pure (Left (migrationError CorruptData "The pending cutover has an ambiguous candidate/backup layout."))
 where
  finish live = \case
    Left problem -> pure (Left problem)
    Right () -> do
      syncDirectory (takeDirectory (migrationTargetRoot paths))
      writeJsonDurably
        (takeDirectory (migrationCompletePath paths))
        (migrationCompletePath paths)
        ( object
            [ "schema" .= ("little-ant/v0-migration-complete@1" :: Text)
            , "source_sha256" .= sourceDigest
            , "live_cursor" .= loadedCursor live
            , "backup_root" .= migrationBackupRoot paths
            ]
        )
      removeFileIfExists (migrationPendingPath paths)
      pure (Right (reportFor MigrationCutover sourcePath sourceDigest sourceBytes projection paths (Just (loadedCursor live)) True False))

validateCutoverRoots :: MigrationPaths -> IO ()
validateCutoverRoots paths = do
  traverse_ requireRealDirectory [migrationTargetRoot paths, migrationCandidateRoot paths]
  unless (takeDirectory (migrationTargetRoot paths) == takeDirectory (migrationCandidateRoot paths)) $
    ioError (userError "migration target and candidate are not sibling directories")
 where
  requireRealDirectory path = do
    status <- getSymbolicLinkStatus path
    when (Posix.isSymbolicLink status || not (isDirectory status)) (ioError (userError ("migration root is not a real directory: " <> path)))

readJsonIfExists :: (FromJSON value) => FilePath -> IO (Either AppError (Maybe value))
readJsonIfExists path = do
  exists <- doesFileExist path
  if not exists
    then pure (Right Nothing)
    else do
      bytes <- ByteString.readFile path
      pure $ case eitherDecodeStrict' bytes of
        Left detail -> Left (migrationError CorruptData ("Invalid migration receipt: " <> Text.pack detail))
        Right value -> Right (Just value)

quarantinePath :: FilePath -> IO FilePath
quarantinePath path = do
  identity <- generateUUIDv7
  pure (path <> ".incomplete-" <> Text.unpack (Text.take 8 (Text.filter (/= '-') (renderUUIDv7 identity))))

writeBytesDurably :: FilePath -> FilePath -> ByteString -> IO ()
writeBytesDurably parent path bytes = do
  let temporary = path <> ".tmp"
  handle <- openBinaryFile temporary WriteMode
  ByteString.hPut handle bytes
  hFlush handle
  descriptor <- handleToFd handle
  setFdOption descriptor CloseOnExec True
  fileSynchronise descriptor
  closeFd descriptor
  setFileMode temporary 0o600
  renameFile temporary path
  syncDirectory parent

writeJsonDurably :: (ToJSON value) => FilePath -> FilePath -> value -> IO ()
writeJsonDurably parent path value = writeBytesDurably parent path (LazyByteString.toStrict (encode value <> "\n"))

syncDirectory :: FilePath -> IO ()
syncDirectory path = bracket (openFd path ReadOnly defaultFileFlags) closeFd fileSynchronise

removeFileIfExists :: FilePath -> IO ()
removeFileIfExists path = do
  exists <- doesFileExist path
  when exists (removeFile path)

renameExchange :: FilePath -> FilePath -> IO (Either AppError ())
renameExchange = renameWithFlag renameExchangeFlag "exchange"

renameNoReplace :: FilePath -> FilePath -> IO (Either AppError ())
renameNoReplace = renameWithFlag renameNoReplaceFlag "no-replace rename"

renameWithFlag :: CUInt -> Text -> FilePath -> FilePath -> IO (Either AppError ())
renameWithFlag flag operation source destination =
  withCString source $ \sourceName ->
    withCString destination $ \destinationName -> do
      result <- c_renameat2 atCurrentWorkingDirectory sourceName atCurrentWorkingDirectory destinationName flag
      if result == 0
        then pure (Right ())
        else do
          errno <- getErrno
          if errno `elem` unsupportedRenameErrors
            then
              pure . Left $
                (migrationError Unsupported "This filesystem cannot perform the required atomic v0 migration cutover.")
                  { appErrorDetails = [operation <> " is unsupported by the current filesystem or kernel"]
                  }
            else ioError (errnoToIOError (Text.unpack operation) errno Nothing (Just source))

unsupportedRenameErrors :: [Errno]
unsupportedRenameErrors = [eNOSYS, eINVAL, eOPNOTSUPP]

atCurrentWorkingDirectory :: CInt
atCurrentWorkingDirectory = -100

renameNoReplaceFlag :: CUInt
renameNoReplaceFlag = 1

renameExchangeFlag :: CUInt
renameExchangeFlag = 2

foreign import ccall unsafe "renameat2"
  c_renameat2 :: CInt -> CString -> CInt -> CString -> CUInt -> IO CInt

handleMigrationIO :: IO (Either AppError value) -> IO (Either AppError value)
handleMigrationIO action = action `catch` handle
 where
  handle :: IOException -> IO (Either AppError value)
  handle exception =
    pure . Left $
      (migrationError ExternalFailure "The v0 migration could not complete its filesystem operation.")
        { appErrorDetails = [Text.pack (show exception)]
        }

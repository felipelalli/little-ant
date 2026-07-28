{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

-- | Auditable semantic migration from the immutable v0 event log to one clean
-- v1 authority.  The old reader is confined to this module: v0 events are
-- folded once, projected to v1 creation/evidence records, and never enter the
-- normal v1 replay path.
module LittleAnt.V1.Migration
  ( ActiveDataset (..)
  , ArchiveInspection (..)
  , CutoverReceipt (..)
  , CutoverStatus (..)
  , MigratedEntityKind (..)
  , MigrationError (..)
  , MigrationEvidence (..)
  , MigrationState (..)
  , ProjectedBrick (..)
  , ProjectionMode (..)
  , StagedV1Dataset (..)
  , WriterProjection (..)
  , V0Archive (..)
  , V0V1IdentityMap (..)
  , V1Cutover (..)
  , activeDatasetPointer
  , archiveBytes
  , commitV1Cutover
  , cutoverTargetLocation
  , emptyMigrationState
  , failCutover
  , findArchive
  , findCutover
  , findIdentityMap
  , findProjectedBrick
  , hashCleanLog
  , hashV0ArchiveBytes
  , inspectV0Archive
  , planV0V1Cutover
  , planV0V1CutoverFromBytes
  , projectV0Events
  , replayProjectedBricks
  , stageWriterProjection
  , readV0ArchiveEvents
  , recordMigratedIdentity
  , recordMigrationEvidence
  , rejectV1Projection
  , stagedIdentityPlans
  , validateMigrationState
  , verifyCutoverReceipt
  , verifyV0Archive
  , verifyV1Projection
  ) where

import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), Options, Result (..), ToJSON (toJSON), Value (..),
   camelTo2, defaultOptions, eitherDecodeStrict, encode, fieldLabelModifier,
   fromJSON, genericParseJSON, genericToJSON, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Types (parseEither)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (isJust)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.Event (Event (..), bodyType)
import LittleAnt.Ids (Id (..))
import qualified LittleAnt.State as V0
import qualified LittleAnt.V1.Domain as Domain
import LittleAnt.Upcast (eventFromJSONVersioned)
import qualified LittleAnt.Types as V0

-- | Explicit cutover lifecycle.  Committed and failed are terminal.
data CutoverStatus
  = CutoverPlanned
  | ArchiveVerified
  | StateProjected
  | ProjectionVerified
  | CutoverCommitted
  | CutoverFailed
  deriving stock (Eq, Ord, Show, Generic)

instance ToJSON CutoverStatus where
  toJSON = toJSON . cutoverStatusText

instance FromJSON CutoverStatus where
  parseJSON value = do
    text <- parseJSON value
    maybe (fail "invalid CutoverStatus") pure (parseCutoverStatus text)

data MigratedEntityKind
  = MigratedBrick
  | MigratedRaw
  | MigratedParty
  | MigratedListEntry
  deriving stock (Eq, Ord, Show, Generic)

instance ToJSON MigratedEntityKind where
  toJSON = toJSON . migratedEntityKindText

instance FromJSON MigratedEntityKind where
  parseJSON value = do
    text <- parseJSON value
    maybe (fail "invalid MigratedEntityKind") pure (parseMigratedEntityKind text)

-- | Whether the staged records were produced by the built-in v0 fold or by a
-- bounded writer adapter.  Both modes retain concrete records and are checked
-- identically before activation.
data ProjectionMode = MaterializedProjection | AdapterWriterProjection
  deriving stock (Eq, Ord, Show, Generic)

instance ToJSON ProjectionMode where
  toJSON MaterializedProjection = toJSON ("materialized" :: Text)
  toJSON AdapterWriterProjection = toJSON ("adapter_writer" :: Text)

instance FromJSON ProjectionMode where
  parseJSON value = do
    text <- parseJSON value
    case (text :: Text) of
      "materialized" -> pure MaterializedProjection
      "adapter_writer" -> pure AdapterWriterProjection
      _ -> fail "invalid ProjectionMode"

-- | Immutable metadata returned by the bounded v0 archive reader.
data ArchiveInspection = ArchiveInspection
  { archiveInspectionSourcePath :: Text
  , archiveInspectionByteSize :: Integer
  , archiveInspectionEventCount :: Integer
  , archiveInspectionSha256 :: Text
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON ArchiveInspection where
  toJSON = genericToJSON (jsonOptions "archiveInspection")

instance FromJSON ArchiveInspection where
  parseJSON = genericParseJSON (jsonOptions "archiveInspection")

data V0Archive = V0Archive
  { v0ArchiveId :: Text
  , v0ArchiveSourcePath :: Text
  , v0ArchiveByteSize :: Integer
  , v0ArchiveEventCount :: Integer
  , v0ArchiveSha256 :: Text
  , v0ArchiveArchivedAt :: UTCTime
  , v0ArchiveImmutable :: Bool
  , v0ArchiveVerified :: Bool
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON V0Archive where
  toJSON = genericToJSON (jsonOptions "v0Archive")

instance FromJSON V0Archive where
  parseJSON = genericParseJSON (jsonOptions "v0Archive")

data V0V1IdentityMap = V0V1IdentityMap
  { v0V1IdentityMapId :: Text
  , v0V1IdentityMapArchive :: Text
  , v0V1IdentityMapOldId :: Text
  , v0V1IdentityMapNewId :: Text
  , v0V1IdentityMapKind :: MigratedEntityKind
  , v0V1IdentityMapRecordedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON V0V1IdentityMap where
  toJSON = genericToJSON (jsonOptions "v0V1IdentityMap")

instance FromJSON V0V1IdentityMap where
  parseJSON = genericParseJSON (jsonOptions "v0V1IdentityMap")

data MigrationEvidence = MigrationEvidence
  { migrationEvidenceId :: Text
  , migrationEvidenceArchive :: Text
  , migrationEvidenceOldEventId :: Maybe Text
  , migrationEvidenceSubjectOldId :: Maybe Text
  , migrationEvidenceSemanticKind :: Text
  , migrationEvidenceSummary :: Text
  , migrationEvidenceRecordedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON MigrationEvidence where
  toJSON = genericToJSON (jsonOptions "migrationEvidence")

instance FromJSON MigrationEvidence where
  parseJSON = genericParseJSON (jsonOptions "migrationEvidence")

data V1Cutover = V1Cutover
  { v1CutoverId :: Text
  , v1CutoverArchive :: Text
  , v1CutoverStatus :: CutoverStatus
  , v1CutoverPlannedAt :: UTCTime
  , v1CutoverFinishedAt :: Maybe UTCTime
  , v1CutoverProjectedEntityCount :: Integer
  , v1CutoverMappedIdentityCount :: Integer
  , v1CutoverRetainedEvidenceCount :: Integer
  , v1CutoverV1LogHash :: Maybe Text
  , v1CutoverReceiptHash :: Maybe Text
  , v1CutoverFailure :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON V1Cutover where
  toJSON = genericToJSON (jsonOptions "v1Cutover")

instance FromJSON V1Cutover where
  parseJSON = genericParseJSON (jsonOptions "v1Cutover")

-- | A compact staged Brick view used to validate removed v0 stage semantics.
data ProjectedBrick = ProjectedBrick
  { projectedBrickOldId :: Text
  , projectedBrickNewId :: Text
  , projectedBrickTitle :: Text
  , projectedBrickStatus :: Text
  , projectedBrickWorkState :: Text
  , projectedBrickBehavior :: Text
  , projectedBrickParentOldId :: Maybe Text
  , projectedBrickPriorityMembershipCount :: Integer
  , projectedBrickPriorityPosition :: Maybe Integer
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON ProjectedBrick where
  toJSON = genericToJSON (jsonOptions "projectedBrick")

instance FromJSON ProjectedBrick where
  parseJSON = genericParseJSON (jsonOptions "projectedBrick")

-- | Concrete output supplied by a bounded cutover writer.  The writer's log
-- hash is an opaque storage identifier (the Allium contract types it as a
-- String); the core independently hashes the exact staged JSON to detect any
-- mutation before activation.
data WriterProjection = WriterProjection
  { writerProjectionArchiveHash :: Text
  , writerProjectionBricks :: Map Text ProjectedBrick
  , writerProjectionIdentityPlans :: Map Text (Text, MigratedEntityKind)
  , writerProjectionCleanLog :: [Value]
  , writerProjectionLogHash :: Text
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON WriterProjection where
  toJSON = genericToJSON (jsonOptions "writerProjection")

instance FromJSON WriterProjection where
  parseJSON = genericParseJSON (jsonOptions "writerProjection")

-- | Writer-owned staged dataset.  The event bodies are clean v1 creation and
-- migration-evidence records; old event kinds are never stored here.
data StagedV1Dataset = StagedV1Dataset
  { stagedV1DatasetCutover :: Text
  , stagedV1DatasetTargetLocation :: Text
  , stagedV1DatasetArchiveHash :: Text
  , stagedV1DatasetMode :: ProjectionMode
  , stagedV1DatasetProjectedBricks :: Map Text ProjectedBrick
  , stagedV1DatasetIdentityPlans :: Map Text (Text, MigratedEntityKind)
  , stagedV1DatasetCleanLog :: [Value]
  , stagedV1DatasetComputedLogHash :: Maybe Text
  , stagedV1DatasetContentHash :: Text
  , stagedV1DatasetInvariantsSatisfied :: Bool
  , stagedV1DatasetIdentityCoverageComplete :: Bool
  , stagedV1DatasetEvidenceCoverageComplete :: Bool
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON StagedV1Dataset where
  toJSON = genericToJSON (jsonOptions "stagedV1Dataset")

instance FromJSON StagedV1Dataset where
  parseJSON = genericParseJSON (jsonOptions "stagedV1Dataset")

data ActiveDataset = ActiveDataset
  { activeDatasetFormat :: Text
  , activeDatasetLocation :: Text
  , activeDatasetLogHash :: Text
  , activeDatasetCutover :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON ActiveDataset where
  toJSON = genericToJSON (jsonOptions "activeDataset")

instance FromJSON ActiveDataset where
  parseJSON = genericParseJSON (jsonOptions "activeDataset")

data CutoverReceipt = CutoverReceipt
  { cutoverReceiptHash :: Text
  , cutoverReceiptCutover :: Text
  , cutoverReceiptArchiveHash :: Text
  , cutoverReceiptV1LogHash :: Text
  , cutoverReceiptTargetLocation :: Text
  , cutoverReceiptCommittedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON CutoverReceipt where
  toJSON = genericToJSON (jsonOptions "cutoverReceipt")

instance FromJSON CutoverReceipt where
  parseJSON = genericParseJSON (jsonOptions "cutoverReceipt")

-- | Canonical migration state.  Archive payloads are retained byte-for-byte as
-- UTF-8 JSONL text and are never rewritten by any exported transition.
data MigrationState = MigrationState
  { migrationStateNextIdentity :: Integer
  , migrationStateArchives :: Map Text V0Archive
  , migrationStateArchivePayloads :: Map Text Text
  , migrationStateCutovers :: Map Text V1Cutover
  , migrationStateTargetLocations :: Map Text Text
  , migrationStateIdentityMaps :: Map (Text, Text) V0V1IdentityMap
  , migrationStateEvidence :: Map Text MigrationEvidence
  , migrationStateStagedDatasets :: Map Text StagedV1Dataset
  , migrationStateReceipts :: Map Text CutoverReceipt
  , migrationStateActiveDataset :: ActiveDataset
  , migrationStateActiveV1Log :: [Value]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON MigrationState where
  toJSON = genericToJSON (jsonOptions "migrationState")

instance FromJSON MigrationState where
  parseJSON = genericParseJSON (jsonOptions "migrationState")

data MigrationError
  = InvalidArchiveSource Text
  | InvalidArchiveSize Integer
  | InvalidArchiveEventCount Integer
  | InvalidArchiveHash Text
  | InvalidTargetLocation
  | UnknownArchive Text
  | UnknownCutover Text
  | InvalidCutoverTransition CutoverStatus CutoverStatus
  | ArchiveVerificationMismatch
  | ProjectionCountInvalid
  | ProjectionUnavailable
  | DuplicateOldIdentity Text
  | DuplicateNewIdentity Text
  | InvalidMigratedIdentity Text
  | InvalidMigrationEvidence Text
  | ProjectionCountMismatch
  | ProjectionHashMismatch
  | ProjectionInvariantFailure
  | InvalidReceipt
  | MigrationInvariantViolation [Text]
  deriving stock (Eq, Show)

emptyMigrationState :: MigrationState
emptyMigrationState = MigrationState
  { migrationStateNextIdentity = 0
  , migrationStateArchives = Map.empty
  , migrationStateArchivePayloads = Map.empty
  , migrationStateCutovers = Map.empty
  , migrationStateTargetLocations = Map.empty
  , migrationStateIdentityMaps = Map.empty
  , migrationStateEvidence = Map.empty
  , migrationStateStagedDatasets = Map.empty
  , migrationStateReceipts = Map.empty
  , migrationStateActiveDataset = ActiveDataset
      { activeDatasetFormat = "v0"
      , activeDatasetLocation = "active/v0/events.jsonl"
      , activeDatasetLogHash = "sha256:active-v0"
      , activeDatasetCutover = Nothing
      }
  , migrationStateActiveV1Log = []
  }

-- | Strict v0 reader inspection.  Unlike the legacy operational loader this
-- rejects malformed/unknown lines: migration cannot silently lose evidence.
inspectV0Archive :: Text -> LBS.ByteString -> Either MigrationError ArchiveInspection
inspectV0Archive sourcePath bytes = do
  when (Text.null (Text.strip sourcePath))
    (Left (InvalidArchiveSource sourcePath))
  events <- readV0ArchiveEvents bytes
  let byteSize = fromIntegral (LBS.length bytes)
      eventCount = fromIntegral (length events)
  when (byteSize <= 0) (Left (InvalidArchiveSize byteSize))
  when (eventCount <= 0) (Left (InvalidArchiveEventCount eventCount))
  pure ArchiveInspection
    { archiveInspectionSourcePath = sourcePath
    , archiveInspectionByteSize = byteSize
    , archiveInspectionEventCount = eventCount
    , archiveInspectionSha256 = hashV0ArchiveBytes bytes
    }

hashV0ArchiveBytes :: LBS.ByteString -> Text
hashV0ArchiveBytes bytes = "sha256:" <> Text.pack (showDigest (sha256 bytes))

readV0ArchiveEvents :: LBS.ByteString -> Either MigrationError [Event]
readV0ArchiveEvents bytes = traverse parseLine nonempty
  where
    nonempty = filter (not . BS.null) (BS8.lines (LBS.toStrict bytes))
    parseLine line = case eitherDecodeStrict line of
      Left problem -> Left (InvalidArchiveSource (Text.pack problem))
      Right value -> case parseEither eventFromJSONVersioned value of
        Left problem -> Left (InvalidArchiveSource (Text.pack problem))
        Right event -> Right event

planV0V1Cutover ::
  UTCTime -> Text -> Text -> Integer -> Integer -> Text -> MigrationState ->
  Either MigrationError (V0Archive, V1Cutover, MigrationState)
planV0V1Cutover now sourcePath targetLocation byteSize eventCount archiveHash =
  planWithPayload now sourcePath targetLocation byteSize eventCount archiveHash Nothing

planV0V1CutoverFromBytes ::
  UTCTime -> Text -> Text -> LBS.ByteString -> MigrationState ->
  Either MigrationError (V0Archive, V1Cutover, MigrationState)
planV0V1CutoverFromBytes now sourcePath targetLocation bytes state = do
  inspection <- inspectV0Archive sourcePath bytes
  planWithPayload now sourcePath targetLocation
    (archiveInspectionByteSize inspection)
    (archiveInspectionEventCount inspection)
    (archiveInspectionSha256 inspection)
    (Just (TextEncoding.decodeUtf8 (LBS.toStrict bytes))) state

planWithPayload ::
  UTCTime -> Text -> Text -> Integer -> Integer -> Text -> Maybe Text ->
  MigrationState -> Either MigrationError (V0Archive, V1Cutover, MigrationState)
planWithPayload now sourcePath targetLocation byteSize eventCount archiveHash payload
    state = do
  when (Text.null (Text.strip sourcePath))
    (Left (InvalidArchiveSource sourcePath))
  when (Text.null (Text.strip targetLocation)) (Left InvalidTargetLocation)
  when (byteSize <= 0) (Left (InvalidArchiveSize byteSize))
  when (eventCount <= 0) (Left (InvalidArchiveEventCount eventCount))
  when (Text.null (Text.strip archiveHash)) (Left (InvalidArchiveHash archiveHash))
  let archiveId = opaqueMigrationId "archive" (migrationStateNextIdentity state)
      cutoverId = opaqueMigrationId "cutover" (migrationStateNextIdentity state + 1)
      archive = V0Archive archiveId sourcePath byteSize eventCount archiveHash now True False
      cutover = V1Cutover cutoverId archiveId CutoverPlanned now Nothing 0 0 0
        Nothing Nothing Nothing
      withPayload = maybe (migrationStateArchivePayloads state)
        (\bytes -> Map.insert archiveId bytes (migrationStateArchivePayloads state))
        payload
      next = state
        { migrationStateNextIdentity = migrationStateNextIdentity state + 2
        , migrationStateArchives = Map.insert archiveId archive
            (migrationStateArchives state)
        , migrationStateArchivePayloads = withPayload
        , migrationStateCutovers = Map.insert cutoverId cutover
            (migrationStateCutovers state)
        , migrationStateTargetLocations = Map.insert cutoverId targetLocation
            (migrationStateTargetLocations state)
        }
  validated <- validateAndReturn next
  pure (archive, cutover, validated)

verifyV0Archive ::
  UTCTime -> Text -> Text -> Integer -> MigrationState ->
  Either MigrationError (V0Archive, V1Cutover, MigrationState)
verifyV0Archive now cutoverId observedHash observedEventCount state = do
  cutover <- findCutover cutoverId state
  archive <- findArchive (v1CutoverArchive cutover) state
  requireStatus CutoverPlanned cutover
  let payloadMatches = case Map.lookup (v0ArchiveId archive)
        (migrationStateArchivePayloads state) of
        Nothing -> False
        Just payload ->
          hashV0ArchiveBytes (LBS.fromStrict (TextEncoding.encodeUtf8 payload))
            == v0ArchiveSha256 archive
      matches = observedHash == v0ArchiveSha256 archive
        && observedEventCount == v0ArchiveEventCount archive
        && payloadMatches
  if matches
    then do
      let verifiedArchive = archive {v0ArchiveVerified = True}
          verifiedCutover = cutover {v1CutoverStatus = ArchiveVerified}
          next = state
            { migrationStateArchives = Map.insert (v0ArchiveId archive)
                verifiedArchive (migrationStateArchives state)
            , migrationStateCutovers = Map.insert cutoverId verifiedCutover
                (migrationStateCutovers state)
            }
      validated <- validateAndReturn next
      pure (verifiedArchive, verifiedCutover, validated)
    else do
      let failed = cutover
            { v1CutoverStatus = CutoverFailed
            , v1CutoverFinishedAt = Just now
            , v1CutoverFailure = Just "v0_archive_verification_failed"
            }
          next = state {migrationStateCutovers = Map.insert cutoverId failed
            (migrationStateCutovers state)}
      validated <- validateAndReturn next
      pure (archive, failed, validated)

-- | Stage concrete output from a bounded writer adapter.  Aggregate counts are
-- checked against the retained records; they are never accepted as a
-- substitute for those records.
stageWriterProjection ::
  Text -> Integer -> Integer -> WriterProjection -> MigrationState ->
  Either MigrationError (V1Cutover, MigrationState)
stageWriterProjection = stageProjection AdapterWriterProjection

-- | Fold the exact retained v0 log once and stage clean v1 creation/evidence
-- records.  A separately supplied, same-length event list is rejected: the
-- immutable archive payload is the migration input authority.
projectV0Events ::
  Text -> [Event] -> MigrationState ->
  Either MigrationError (V1Cutover, MigrationState)
projectV0Events cutoverId events state = do
  cutover <- findCutover cutoverId state
  archive <- findArchive (v1CutoverArchive cutover) state
  requireStatus ArchiveVerified cutover
  unless (v0ArchiveVerified archive) (Left ArchiveVerificationMismatch)
  payload <- maybe (Left ProjectionUnavailable) Right
    (archiveBytes (v0ArchiveId archive) state)
  archivedEvents <- readV0ArchiveEvents payload
  unless (hashV0ArchiveBytes payload == v0ArchiveSha256 archive
      && archivedEvents == events
      && fromIntegral (length archivedEvents) == v0ArchiveEventCount archive)
    (Left ArchiveVerificationMismatch)
  when (null archivedEvents) (Left ProjectionUnavailable)
  let legacy = V0.replay archivedEvents
      entities = legacyEntities legacy
      ordinals = [migrationStateNextIdentity state ..]
      allocated = zipWith allocateProjected entities ordinals
      plans = Map.fromList
        [(oldId, (newId, kind)) | ((oldId, kind), newId) <- allocated]
      nextOrdinal = migrationStateNextIdentity state
        + fromIntegral (length allocated)
      bricks = projectLegacyBricks legacy plans
      creationRecords = map (creationRecord legacy bricks) allocated
      evidenceRecords = map eventEvidenceRecord archivedEvents
      cleanLog = creationRecords <> evidenceRecords
      computedHash = hashCleanLog cleanLog
      writer = WriterProjection (v0ArchiveSha256 archive) bricks plans cleanLog
        computedHash
      projectedCount = fromIntegral (length allocated)
      evidenceCount = fromIntegral (length evidenceRecords)
  (projected, next) <- stageProjection MaterializedProjection cutoverId
    projectedCount evidenceCount writer state
  validated <- validateAndReturn
    (next {migrationStateNextIdentity = nextOrdinal})
  pure (projected, validated)

stageProjection ::
  ProjectionMode -> Text -> Integer -> Integer -> WriterProjection ->
  MigrationState -> Either MigrationError (V1Cutover, MigrationState)
stageProjection mode cutoverId projectedCount evidenceCount writer state = do
  cutover <- findCutover cutoverId state
  archive <- findArchive (v1CutoverArchive cutover) state
  requireStatus ArchiveVerified cutover
  unless (v0ArchiveVerified archive) (Left ArchiveVerificationMismatch)
  when (projectedCount < 0 || evidenceCount < 0) (Left ProjectionCountInvalid)
  target <- cutoverTargetLocation cutoverId state
  let bricks = writerProjectionBricks writer
      plans = writerProjectionIdentityPlans writer
      cleanLog = writerProjectionCleanLog writer
      logHash = writerProjectionLogHash writer
      contentHash = hashCleanLog cleanLog
      invariantsSatisfied = writerProjectionArchiveHash writer
        == v0ArchiveSha256 archive
        && writerProjectionIsValid projectedCount evidenceCount writer
        && writerProjectionMatchesArchive archive state writer
      stagedWithoutCoverage = StagedV1Dataset cutoverId target
        (v0ArchiveSha256 archive) mode bricks plans cleanLog (Just logHash)
        contentHash invariantsSatisfied False
        (evidenceRecordCount cleanLog == evidenceCount)
      identityComplete = identityPlansCovered (v0ArchiveId archive)
        (migrationStateIdentityMaps state) stagedWithoutCoverage
      staged = stagedWithoutCoverage
        {stagedV1DatasetIdentityCoverageComplete = identityComplete}
  unless invariantsSatisfied (Left ProjectionInvariantFailure)
  when (Text.null (Text.strip logHash)) (Left ProjectionHashMismatch)
  let projected = cutover
        { v1CutoverStatus = StateProjected
        , v1CutoverProjectedEntityCount = projectedCount
        , v1CutoverRetainedEvidenceCount = evidenceCount
        }
      next = state
        { migrationStateCutovers = Map.insert cutoverId projected
            (migrationStateCutovers state)
        , migrationStateStagedDatasets = Map.insert cutoverId staged
            (migrationStateStagedDatasets state)
        }
  validated <- validateAndReturn next
  pure (projected, validated)

recordMigratedIdentity ::
  UTCTime -> Text -> Text -> Text -> MigratedEntityKind -> MigrationState ->
  Either MigrationError (V0V1IdentityMap, V1Cutover, MigrationState)
recordMigratedIdentity now cutoverId oldId newId kind state = do
  cutover <- findCutover cutoverId state
  requireStatus StateProjected cutover
  requireNonemptyIdentity oldId
  requireNonemptyIdentity newId
  unless (isOpaqueMigrationId newId)
    (Left (InvalidMigratedIdentity newId))
  when (oldId == newId || looksTitleDerived newId)
    (Left (InvalidMigratedIdentity newId))
  let archiveId = v1CutoverArchive cutover
      key = (archiveId, oldId)
  when (Map.member key (migrationStateIdentityMaps state))
    (Left (DuplicateOldIdentity oldId))
  when (any ((== newId) . v0V1IdentityMapNewId)
      (Map.elems (migrationStateIdentityMaps state)))
    (Left (DuplicateNewIdentity newId))
  staged <- maybe (Left ProjectionUnavailable) Right
    (Map.lookup cutoverId (migrationStateStagedDatasets state))
  (expectedNewId, expectedKind) <- maybe
    (Left (InvalidMigratedIdentity "old identity is absent from staged projection"))
    Right (Map.lookup oldId (stagedV1DatasetIdentityPlans staged))
  unless (newId == expectedNewId && kind == expectedKind)
    (Left (InvalidMigratedIdentity
      "identity or kind differs from staged projection"))
  let mapId = opaqueMigrationId "identity-map" (migrationStateNextIdentity state)
      mapping = V0V1IdentityMap mapId archiveId oldId newId kind now
      changedCutover = cutover {v1CutoverMappedIdentityCount =
        v1CutoverMappedIdentityCount cutover + 1}
      identityMaps = Map.insert key mapping (migrationStateIdentityMaps state)
      updateStaged current = current
        { stagedV1DatasetIdentityCoverageComplete =
            identityPlansCovered archiveId identityMaps current
        }
      next = state
        { migrationStateNextIdentity = migrationStateNextIdentity state + 1
        , migrationStateIdentityMaps = identityMaps
        , migrationStateCutovers = Map.insert cutoverId changedCutover
            (migrationStateCutovers state)
        , migrationStateStagedDatasets = Map.adjust updateStaged cutoverId
            (migrationStateStagedDatasets state)
        }
  validated <- validateAndReturn next
  pure (mapping, changedCutover, validated)

recordMigrationEvidence ::
  UTCTime -> Text -> Maybe Text -> Maybe Text -> Text -> Text -> MigrationState ->
  Either MigrationError (MigrationEvidence, MigrationState)
recordMigrationEvidence now cutoverId oldEventId subjectOldId semanticKind summary
    state = do
  cutover <- findCutover cutoverId state
  requireStatus StateProjected cutover
  when (Text.null (Text.strip semanticKind) || Text.null (Text.strip summary))
    (Left (InvalidMigrationEvidence "semantic kind and summary are required"))
  staged <- maybe (Left ProjectionUnavailable) Right
    (Map.lookup cutoverId (migrationStateStagedDatasets state))
  case oldEventId of
    Just identifier -> unless (cleanLogContains "old_event_id" identifier
        (stagedV1DatasetCleanLog staged))
      (Left (InvalidMigrationEvidence
        "old event is absent from staged projection evidence"))
    Nothing -> pure ()
  case subjectOldId of
    Just identifier -> unless (Map.member identifier
        (stagedV1DatasetIdentityPlans staged))
      (Left (InvalidMigrationEvidence
        "old subject is absent from staged projection identities"))
    Nothing -> pure ()
  let evidenceId = opaqueMigrationId "migration-evidence"
        (migrationStateNextIdentity state)
      evidence = MigrationEvidence evidenceId (v1CutoverArchive cutover)
        oldEventId subjectOldId semanticKind summary now
      next = state
        { migrationStateNextIdentity = migrationStateNextIdentity state + 1
        , migrationStateEvidence = Map.insert evidenceId evidence
            (migrationStateEvidence state)
        }
  validated <- validateAndReturn next
  pure (evidence, validated)

verifyV1Projection ::
  Text -> Integer -> Integer -> Text -> MigrationState ->
  Either MigrationError (V1Cutover, MigrationState)
verifyV1Projection cutoverId mappedCount projectedCount observedLogHash state = do
  cutover <- findCutover cutoverId state
  archive <- findArchive (v1CutoverArchive cutover) state
  requireStatus StateProjected cutover
  staged <- maybe (Left ProjectionUnavailable) Right
    (Map.lookup cutoverId (migrationStateStagedDatasets state))
  unless (v0ArchiveVerified archive
      && stagedV1DatasetArchiveHash staged == v0ArchiveSha256 archive)
    (Left ArchiveVerificationMismatch)
  unless (mappedCount == v1CutoverMappedIdentityCount cutover
      && projectedCount == v1CutoverProjectedEntityCount cutover)
    (Left ProjectionCountMismatch)
  when (Text.null (Text.strip observedLogHash)) (Left ProjectionHashMismatch)
  expectedLogHash <- maybe (Left ProjectionHashMismatch) Right
    (stagedV1DatasetComputedLogHash staged)
  unless (expectedLogHash == observedLogHash
      && stagedV1DatasetContentHash staged
        == hashCleanLog (stagedV1DatasetCleanLog staged))
    (Left ProjectionHashMismatch)
  let archiveId = v0ArchiveId archive
      identityComplete = identityPlansCovered archiveId
        (migrationStateIdentityMaps state) staged
      evidenceComplete = evidenceRecordCount (stagedV1DatasetCleanLog staged)
        == v1CutoverRetainedEvidenceCount cutover
      writer = WriterProjection (stagedV1DatasetArchiveHash staged)
        (stagedV1DatasetProjectedBricks staged)
        (stagedV1DatasetIdentityPlans staged)
        (stagedV1DatasetCleanLog staged) expectedLogHash
      invariantsSatisfied = writerProjectionIsValid
        (v1CutoverProjectedEntityCount cutover)
        (v1CutoverRetainedEvidenceCount cutover) writer
        && writerProjectionMatchesArchive archive state writer
  unless (archivePayloadMatches archive state
      && invariantsSatisfied
      && identityComplete
      && evidenceComplete
      && stagedV1DatasetInvariantsSatisfied staged == invariantsSatisfied
      && stagedV1DatasetIdentityCoverageComplete staged == identityComplete
      && stagedV1DatasetEvidenceCoverageComplete staged == evidenceComplete)
    (Left ProjectionInvariantFailure)
  let verified = cutover
        { v1CutoverStatus = ProjectionVerified
        , v1CutoverV1LogHash = Just observedLogHash
        }
      next = state {migrationStateCutovers = Map.insert cutoverId verified
        (migrationStateCutovers state)}
  validated <- validateAndReturn next
  pure (verified, validated)

rejectV1Projection ::
  UTCTime -> Text -> Text -> MigrationState ->
  Either MigrationError (V1Cutover, MigrationState)
rejectV1Projection now cutoverId failure state = do
  cutover <- findCutover cutoverId state
  requireStatus StateProjected cutover
  failCutover now cutoverId failure state

-- | Explicit writer failure for staging/activation boundaries.  It never
-- changes the active dataset pointer and never removes archive bytes.
failCutover ::
  UTCTime -> Text -> Text -> MigrationState ->
  Either MigrationError (V1Cutover, MigrationState)
failCutover now cutoverId failure state = do
  cutover <- findCutover cutoverId state
  unless (v1CutoverStatus cutover `elem`
      [CutoverPlanned, ArchiveVerified, StateProjected, ProjectionVerified])
    (Left (InvalidCutoverTransition (v1CutoverStatus cutover) CutoverFailed))
  when (Text.null (Text.strip failure))
    (Left (InvalidMigrationEvidence "failure reason is required"))
  let failed = cutover
        { v1CutoverStatus = CutoverFailed
        , v1CutoverFinishedAt = Just now
        , v1CutoverFailure = Just failure
        }
      next = state {migrationStateCutovers = Map.insert cutoverId failed
        (migrationStateCutovers state)}
  validated <- validateAndReturn next
  pure (failed, validated)

-- | The only authority switch.  All checks occur before one immutable state
-- value is returned, so callers cannot observe a partially active v1 log.
commitV1Cutover ::
  UTCTime -> Text -> Text -> MigrationState ->
  Either MigrationError (V1Cutover, CutoverReceipt, MigrationState)
commitV1Cutover now cutoverId receiptHash state = do
  cutover <- findCutover cutoverId state
  archive <- findArchive (v1CutoverArchive cutover) state
  requireStatus ProjectionVerified cutover
  unless (v0ArchiveVerified archive) (Left ArchiveVerificationMismatch)
  logHash <- maybe (Left ProjectionHashMismatch) Right (v1CutoverV1LogHash cutover)
  when (Text.null (Text.strip receiptHash)) (Left InvalidReceipt)
  target <- cutoverTargetLocation cutoverId state
  staged <- maybe (Left ProjectionUnavailable) Right
    (Map.lookup cutoverId (migrationStateStagedDatasets state))
  unless (stagedReadyForActivation archive cutover state staged
      && stagedV1DatasetComputedLogHash staged == Just logHash)
    (Left ProjectionInvariantFailure)
  let committed = cutover
        { v1CutoverStatus = CutoverCommitted
        , v1CutoverFinishedAt = Just now
        , v1CutoverReceiptHash = Just receiptHash
        }
      receipt = CutoverReceipt receiptHash cutoverId (v0ArchiveSha256 archive)
        logHash target now
      active = ActiveDataset "v1" target logHash (Just cutoverId)
      next = state
        { migrationStateCutovers = Map.insert cutoverId committed
            (migrationStateCutovers state)
        , migrationStateReceipts = Map.insert cutoverId receipt
            (migrationStateReceipts state)
        , migrationStateActiveDataset = active
        , migrationStateActiveV1Log = stagedV1DatasetCleanLog staged
        }
  validated <- validateAndReturn next
  pure (committed, receipt, validated)

verifyCutoverReceipt :: Text -> MigrationState -> Either MigrationError CutoverReceipt
verifyCutoverReceipt cutoverId state = do
  cutover <- findCutover cutoverId state
  archive <- findArchive (v1CutoverArchive cutover) state
  receipt <- maybe (Left InvalidReceipt) Right
    (Map.lookup cutoverId (migrationStateReceipts state))
  target <- cutoverTargetLocation cutoverId state
  unless (v1CutoverStatus cutover == CutoverCommitted
      && v1CutoverReceiptHash cutover == Just (cutoverReceiptHash receipt)
      && v1CutoverV1LogHash cutover == Just (cutoverReceiptV1LogHash receipt)
      && cutoverReceiptArchiveHash receipt == v0ArchiveSha256 archive
      && cutoverReceiptTargetLocation receipt == target
      && migrationStateActiveDataset state
          == ActiveDataset "v1" target (cutoverReceiptV1LogHash receipt)
            (Just cutoverId)
      && hashCleanLog (migrationStateActiveV1Log state)
          == cutoverReceiptV1LogHash receipt)
    (Left InvalidReceipt)
  pure receipt

findArchive :: Text -> MigrationState -> Either MigrationError V0Archive
findArchive identifier state = maybe (Left (UnknownArchive identifier)) Right
  (Map.lookup identifier (migrationStateArchives state))

findCutover :: Text -> MigrationState -> Either MigrationError V1Cutover
findCutover identifier state = maybe (Left (UnknownCutover identifier)) Right
  (Map.lookup identifier (migrationStateCutovers state))

findIdentityMap ::
  Text -> Text -> MigrationState -> Either MigrationError V0V1IdentityMap
findIdentityMap archiveId oldId state = maybe
  (Left (DuplicateOldIdentity oldId)) Right
  (Map.lookup (archiveId, oldId) (migrationStateIdentityMaps state))

-- | Look up only a Brick that the staged writer actually retained.  Unknown
-- old IDs fail closed; observations never synthesize projection state.
findProjectedBrick :: Text -> MigrationState -> Either MigrationError ProjectedBrick
findProjectedBrick oldId state = case
    [brick | staged <- Map.elems (migrationStateStagedDatasets state)
           , brick <- maybeToList (Map.lookup oldId
               (stagedV1DatasetProjectedBricks staged))] of
  brick : _ -> Right brick
  [] -> Left ProjectionUnavailable

stagedIdentityPlans ::
  Text -> MigrationState -> Either MigrationError (Map Text (Text, MigratedEntityKind))
stagedIdentityPlans cutoverId state = maybe (Left ProjectionUnavailable)
  (Right . stagedV1DatasetIdentityPlans)
  (Map.lookup cutoverId (migrationStateStagedDatasets state))

archiveBytes :: Text -> MigrationState -> Maybe LBS.ByteString
archiveBytes archiveId state = LBS.fromStrict . TextEncoding.encodeUtf8 <$>
  Map.lookup archiveId (migrationStateArchivePayloads state)

cutoverTargetLocation :: Text -> MigrationState -> Either MigrationError Text
cutoverTargetLocation cutoverId state = maybe (Left InvalidTargetLocation) Right
  (Map.lookup cutoverId (migrationStateTargetLocations state))

activeDatasetPointer :: MigrationState -> Text
activeDatasetPointer = activeDatasetLocation . migrationStateActiveDataset

validateMigrationState :: MigrationState -> Either MigrationError ()
validateMigrationState state = unless (null failures)
  (Left (MigrationInvariantViolation failures))
  where
    archives = Map.elems (migrationStateArchives state)
    cutovers = Map.elems (migrationStateCutovers state)
    mappings = Map.elems (migrationStateIdentityMaps state)
    archiveIds = Map.keysSet (migrationStateArchives state)
    targetIds = Map.keysSet (migrationStateTargetLocations state)
    mapKeys = [(v0V1IdentityMapArchive item, v0V1IdentityMapOldId item)
      | item <- mappings]
    mappedNewIds = map v0V1IdentityMapNewId mappings
    committed = filter ((== CutoverCommitted) . v1CutoverStatus) cutovers
    failures = concat
      [ ["archive is mutable" | any (not . v0ArchiveImmutable) archives]
      , ["retained archive bytes differ from archive identity" |
          any (\archive -> Map.member (v0ArchiveId archive)
              (migrationStateArchivePayloads state)
            && not (archivePayloadMatches archive state)) archives]
      , ["verified archive has no matching retained bytes" |
          any (\archive -> v0ArchiveVerified archive
            && not (archivePayloadMatches archive state)) archives]
      , ["cutover references an unknown archive" |
          any ((`Set.notMember` archiveIds) . v1CutoverArchive) cutovers]
      , ["cutover has no target location" |
          any ((`Set.notMember` targetIds) . v1CutoverId) cutovers]
      , ["duplicate archive/old identity map" |
          Set.size (Set.fromList mapKeys) /= length mapKeys]
      , ["new migrated identity was reused" |
          Set.size (Set.fromList mappedNewIds) /= length mappedNewIds]
      , ["migrated identity is not opaque" |
          any (not . isOpaqueMigrationId . v0V1IdentityMapNewId) mappings]
      , ["title-derived old identity was reused" |
          any (\item -> v0V1IdentityMapOldId item == v0V1IdentityMapNewId item
            || looksTitleDerived (v0V1IdentityMapNewId item)) mappings]
      , ["migrated identity differs from staged projection" |
          any (not . mappingMatchesProjection state) mappings]
      , ["mapped identity count does not match retained maps" |
          any (\cutover -> v1CutoverMappedIdentityCount cutover /=
            fromIntegral (length [() | item <- mappings
              , v0V1IdentityMapArchive item == v1CutoverArchive cutover])) cutovers]
      , ["committed cutover is not verifiable" |
          any (\cutover -> not (isJust (v1CutoverFinishedAt cutover)
            && isJust (v1CutoverV1LogHash cutover)
            && isJust (v1CutoverReceiptHash cutover)
            && maybe False v0ArchiveVerified
              (Map.lookup (v1CutoverArchive cutover)
                (migrationStateArchives state)))) committed]
      , ["committed cutover has no receipt" |
          any ((`Map.notMember` migrationStateReceipts state) . v1CutoverId)
            committed]
      , ["committed cutover staged data no longer verifies" |
          any (not . committedStageReady state) committed]
      , ["active v1 pointer does not name the committed cutover" |
          activeDatasetFormat (migrationStateActiveDataset state) == "v1"
          && maybe True (\identifier -> maybe True
              ((/= CutoverCommitted) . v1CutoverStatus)
              (Map.lookup identifier (migrationStateCutovers state)))
            (activeDatasetCutover (migrationStateActiveDataset state))]
      , ["active v1 log differs from its verified authority" |
          activeDatasetFormat (migrationStateActiveDataset state) == "v1"
          && (hashCleanLog (migrationStateActiveV1Log state)
                /= activeDatasetLogHash (migrationStateActiveDataset state)
            || maybe True (\identifier -> maybe True
                ((/= migrationStateActiveV1Log state)
                  . stagedV1DatasetCleanLog)
                (Map.lookup identifier (migrationStateStagedDatasets state)))
              (activeDatasetCutover (migrationStateActiveDataset state)))]
      , ["v0 authority unexpectedly contains an active v1 log" |
          activeDatasetFormat (migrationStateActiveDataset state) == "v0"
            && not (null (migrationStateActiveV1Log state))]
      , ["terminal cutover has no finish time" |
          any (\cutover -> v1CutoverStatus cutover `elem`
              [CutoverCommitted, CutoverFailed]
            && not (isJust (v1CutoverFinishedAt cutover))) cutovers]
      ]

validateAndReturn :: MigrationState -> Either MigrationError MigrationState
validateAndReturn state = state <$ validateMigrationState state

requireStatus :: CutoverStatus -> V1Cutover -> Either MigrationError ()
requireStatus expected cutover = unless (v1CutoverStatus cutover == expected)
  (Left (InvalidCutoverTransition (v1CutoverStatus cutover) expected))

requireNonemptyIdentity :: Text -> Either MigrationError ()
requireNonemptyIdentity value = when (Text.null (Text.strip value))
  (Left (InvalidMigratedIdentity value))

looksTitleDerived :: Text -> Bool
looksTitleDerived value = "title" `Text.isInfixOf` Text.toLower value
  && not ("opaque:" `Text.isPrefixOf` value)
  && not ("la1:" `Text.isPrefixOf` value)

legacyEntities :: V0.State -> [(Text, MigratedEntityKind)]
legacyEntities state =
  [(unId identifier, MigratedBrick) | identifier <- Map.keys (V0.stBricks state)]
  <> [(unId identifier, MigratedRaw) | identifier <- Map.keys (V0.stRawInputs state)]
  <> [(unId identifier, MigratedParty) | identifier <- Map.keys (V0.stParties state)]

allocateProjected ::
  (Text, MigratedEntityKind) -> Integer -> ((Text, MigratedEntityKind), Text)
allocateProjected old ordinal = (old, opaqueMigrationId "entity" ordinal)

projectLegacyBricks ::
  V0.State -> Map Text (Text, MigratedEntityKind) -> Map Text ProjectedBrick
projectLegacyBricks state plans = Map.fromList
  [ (oldId, ProjectedBrick oldId newId (V0.bTitle brick) status workState
      canonicalBehaviorId (unId <$> V0.bParent brick) membership position)
  | scoped <- Map.elems grouped
  , let ordered = sortOn V0.bCreatedSeq scoped
        activePositions = Map.fromList
          [(V0.bId activeBrick, positionIndex)
          | (positionIndex, activeBrick) <- zip [0 ..]
              (filter ((== "active") . projectedStatus . V0.bStage) ordered)]
  , brick <- ordered
  , let oldId = unId (V0.bId brick)
        newId = maybe "opaque:missing" fst (Map.lookup oldId plans)
        status = projectedStatus (V0.bStage brick)
        workState = if V0.bStage brick == V0.Wip then "wip" else "idle"
        position = Map.lookup (V0.bId brick) activePositions
        membership = if isJust position then 1 else 0
  ]
  where
    grouped = Map.fromListWith (<>)
      [ (V0.bParent brick, [brick]) | brick <- Map.elems (V0.stBricks state)]

projectedStatus :: V0.Stage -> Text
projectedStatus stage = case stage of
  V0.Seed -> "active"
  V0.Committed -> "active"
  V0.Ready -> "active"
  V0.Wip -> "active"
  V0.Done -> "done"
  V0.Dropped -> "dropped"
  V0.Superseded -> "superseded"

creationRecord ::
  V0.State -> Map Text ProjectedBrick ->
  ((Text, MigratedEntityKind), Text) -> Value
creationRecord state bricks ((oldId, kind), newId) = case kind of
  MigratedBrick -> case Map.lookup oldId bricks of
    Just brick -> object
      [ "record_type" .= ("v1_entity_created" :: Text)
      , "old_id" .= oldId
      , "new_id" .= newId
      , "kind" .= migratedEntityKindText kind
      , "summary" .= summary
      , "title" .= projectedBrickTitle brick
      , "status" .= projectedBrickStatus brick
      , "work_state" .= projectedBrickWorkState brick
      , "behavior" .= projectedBrickBehavior brick
      , "parent_old_id" .= projectedBrickParentOldId brick
      , "priority_membership_count" .=
          projectedBrickPriorityMembershipCount brick
      , "priority_position" .= projectedBrickPriorityPosition brick
      ]
    Nothing -> baseRecord
  _ -> baseRecord
  where
    baseRecord = object
      [ "record_type" .= ("v1_entity_created" :: Text)
      , "old_id" .= oldId
      , "new_id" .= newId
      , "kind" .= migratedEntityKindText kind
      , "summary" .= summary
      ]
    summary = case kind of
      MigratedBrick -> maybe "migrated Brick"
        (\brick -> "migrated Brick: " <> V0.bTitle brick)
        (Map.lookup (Id oldId) (V0.stBricks state))
      MigratedRaw -> "migrated Raw"
      MigratedParty -> "migrated Party"
      MigratedListEntry -> "migrated ListEntry"

eventEvidenceRecord :: Event -> Value
eventEvidenceRecord event = toJSON (Map.fromList
  [ ("record_type" :: Text, "migration_evidence")
  , ("old_event_id", evId event)
  , ("semantic_kind", bodyType (evBody event))
  , ("summary", "retained v0 semantic evidence")
  ])

validStrictPlacement :: Map Text ProjectedBrick -> Bool
validStrictPlacement bricks = all validBrick (Map.elems bricks)
    && all validScope grouped
  where
    active = filter ((== "active") . projectedBrickStatus) (Map.elems bricks)
    grouped = Map.elems (Map.fromListWith (<>)
      [(projectedBrickParentOldId brick, [brick]) | brick <- active])
    validBrick brick = validCataloguedBrick brick && validParent brick
      && case projectedBrickStatus brick of
        "active" -> projectedBrickPriorityMembershipCount brick == 1
          && isJust (projectedBrickPriorityPosition brick)
          && projectedBrickWorkState brick `elem` ["idle", "wip"]
        terminal | terminal `elem` ["done", "dropped", "superseded"] ->
          projectedBrickPriorityMembershipCount brick == 0
            && projectedBrickPriorityPosition brick == Nothing
            && projectedBrickWorkState brick == "idle"
        _ -> False
    validParent brick = case projectedBrickParentOldId brick of
      Nothing -> True
      Just parentId -> parentId /= projectedBrickOldId brick
        && case Map.lookup parentId bricks of
          Nothing -> False
          Just parent -> projectedBrickStatus brick /= "active"
            || projectedBrickStatus parent == "active"
    validScope scope =
      let positions = sortOn id
            [position | Just position <- map projectedBrickPriorityPosition scope]
          expected = [0 .. fromIntegral (length scope) - 1]
      in all ((== 1) . projectedBrickPriorityMembershipCount) scope
        && positions == expected

validCataloguedBrick :: ProjectedBrick -> Bool
validCataloguedBrick brick =
  Domain.catalogContainsBehavior Domain.initialDefinitionCatalog Domain.standardV1
    && projectedBrickBehavior brick == canonicalBehaviorId

canonicalBehaviorId :: Text
canonicalBehaviorId = Domain.behaviorId Domain.standardV1

hashCleanLog :: [Value] -> Text
hashCleanLog = hashV0ArchiveBytes . encode

-- | Rebuild the exact migrated Brick projection using only clean v1 creation
-- records.  This is the same replay used by verification and activation; the
-- migration-side materialized map is never a second authority.
replayProjectedBricks ::
  [Value] -> Either MigrationError (Map Text ProjectedBrick)
replayProjectedBricks cleanLog = do
  parsed <- maybe (Left ProjectionInvariantFailure) Right
    (traverse projectedBrickFromRecord brickRecords)
  let keys = map fst parsed
      bricks = Map.fromList parsed
  unless (Set.size (Set.fromList keys) == length keys
      && validStrictPlacement bricks)
    (Left ProjectionInvariantFailure)
  pure bricks
  where
    brickRecords = [value | value <- cleanLog
      , recordTextField "record_type" value == Just "v1_entity_created"
      , recordTextField "kind" value == Just "brick"]

projectedBrickFromRecord :: Value -> Maybe (Text, ProjectedBrick)
projectedBrickFromRecord value = do
  oldId <- recordTextField "old_id" value
  newId <- recordTextField "new_id" value
  title <- recordTextField "title" value
  status <- recordTextField "status" value
  workState <- recordTextField "work_state" value
  behavior <- recordTextField "behavior" value
  parent <- recordOptionalTextField "parent_old_id" value
  membership <- recordIntegerField "priority_membership_count" value
  position <- recordOptionalIntegerField "priority_position" value
  pure (oldId, ProjectedBrick oldId newId title status workState behavior
    parent membership position)

writerProjectionMatchesArchive ::
  V0Archive -> MigrationState -> WriterProjection -> Bool
writerProjectionMatchesArchive archive state writer = case
    archiveBytes (v0ArchiveId archive) state >>= eitherToMaybe . readV0ArchiveEvents of
  Nothing -> False
  Just events ->
    let legacy = V0.replay events
        plans = writerProjectionIdentityPlans writer
        plannedKinds = Map.map snd plans
        expectedKinds = Map.fromList (legacyEntities legacy)
        expectedBricks = projectLegacyBricks legacy plans
        retainedEventIds = Set.fromList
          [identifier | value <- writerProjectionCleanLog writer
          , recordTextField "record_type" value == Just "migration_evidence"
          , Just identifier <- [recordTextField "old_event_id" value]]
    in plannedKinds == expectedKinds
      && writerProjectionBricks writer == expectedBricks
      && retainedEventIds == Set.fromList (map evId events)

writerProjectionIsValid :: Integer -> Integer -> WriterProjection -> Bool
writerProjectionIsValid projectedCount evidenceCount writer =
  projectedRecordCount cleanLog == projectedCount
    && evidenceRecordCount cleanLog == evidenceCount
    && fromIntegral (Map.size plans) == projectedCount
    && length createdOldIds == Map.size plans
    && Set.fromList createdOldIds == Map.keysSet plans
    && all cleanRecordTypeAllowed cleanLog
    && replayProjectedBricks cleanLog == Right bricks
    && all planIsConcrete (Map.toList plans)
    && all brickHasPlan (Map.toList bricks)
    && uniqueCreatedIdentities cleanLog
    && uniqueEvidenceRecords cleanLog
    && writerProjectionLogHash writer == hashCleanLog cleanLog
  where
    bricks = writerProjectionBricks writer
    plans = writerProjectionIdentityPlans writer
    cleanLog = writerProjectionCleanLog writer
    planIsConcrete (oldId, (newId, kind)) =
      not (Text.null (Text.strip oldId))
        && isOpaqueMigrationId newId
        && oldId /= newId
        && cleanLogContainsIdentity oldId newId kind cleanLog
        && case kind of
          MigratedBrick -> case Map.lookup oldId bricks of
            Just brick -> projectedBrickOldId brick == oldId
              && projectedBrickNewId brick == newId
            Nothing -> False
          _ -> True
    brickHasPlan (oldId, brick) =
      Map.lookup oldId plans == Just (projectedBrickNewId brick, MigratedBrick)
    createdOldIds = [oldId | value <- cleanLog
      , recordTextField "record_type" value == Just "v1_entity_created"
      , Just oldId <- [recordTextField "old_id" value]]
    cleanRecordTypeAllowed value = case recordTextField "record_type" value of
      Just "v1_entity_created" -> True
      Just "migration_evidence" -> True
      _ -> False

projectedRecordCount :: [Value] -> Integer
projectedRecordCount = fromIntegral . length . filter
  ((== Just "v1_entity_created") . recordTextField "record_type")

evidenceRecordCount :: [Value] -> Integer
evidenceRecordCount = fromIntegral . length . filter
  ((== Just "migration_evidence") . recordTextField "record_type")

cleanLogContainsIdentity ::
  Text -> Text -> MigratedEntityKind -> [Value] -> Bool
cleanLogContainsIdentity oldId newId kind = any matches
  where
    matches value = recordTextField "record_type" value
        == Just "v1_entity_created"
      && recordTextField "old_id" value == Just oldId
      && recordTextField "new_id" value == Just newId
      && recordTextField "kind" value == Just (migratedEntityKindText kind)

uniqueCreatedIdentities :: [Value] -> Bool
uniqueCreatedIdentities cleanLog =
  let identifiers = [identifier | value <- cleanLog
        , recordTextField "record_type" value == Just "v1_entity_created"
        , Just identifier <- [recordTextField "new_id" value]]
  in fromIntegral (length identifiers) == projectedRecordCount cleanLog
    && Set.size (Set.fromList identifiers) == length identifiers
    && all isOpaqueMigrationId identifiers

uniqueEvidenceRecords :: [Value] -> Bool
uniqueEvidenceRecords cleanLog =
  let evidence = [value | value <- cleanLog
        , recordTextField "record_type" value == Just "migration_evidence"]
      oldEventIds = [identifier | value <- evidence
        , Just identifier <- [recordTextField "old_event_id" value]]
  in fromIntegral (length evidence) == evidenceRecordCount cleanLog
    && length oldEventIds == length evidence
    && Set.size (Set.fromList oldEventIds) == length oldEventIds
    && all (\value -> maybe False (not . Text.null . Text.strip)
          (recordTextField "semantic_kind" value)
        && maybe False (not . Text.null . Text.strip)
          (recordTextField "summary" value)) evidence

recordTextField :: Text -> Value -> Maybe Text
recordTextField field (Object fields) = case
    KeyMap.lookup (Key.fromText field) fields of
  Just (String value) -> Just value
  _ -> Nothing
recordTextField _ _ = Nothing

recordIntegerField :: Text -> Value -> Maybe Integer
recordIntegerField field (Object fields) =
  KeyMap.lookup (Key.fromText field) fields >>= \value -> case fromJSON value of
    Success integer -> Just integer
    Error _ -> Nothing
recordIntegerField _ _ = Nothing

recordOptionalTextField :: Text -> Value -> Maybe (Maybe Text)
recordOptionalTextField field (Object fields) = case
    KeyMap.lookup (Key.fromText field) fields of
  Just Null -> Just Nothing
  Just (String value) -> Just (Just value)
  _ -> Nothing
recordOptionalTextField _ _ = Nothing

recordOptionalIntegerField :: Text -> Value -> Maybe (Maybe Integer)
recordOptionalIntegerField field (Object fields) = case
    KeyMap.lookup (Key.fromText field) fields of
  Just Null -> Just Nothing
  Just value -> case fromJSON value of
    Success integer -> Just (Just integer)
    Error _ -> Nothing
  Nothing -> Nothing
recordOptionalIntegerField _ _ = Nothing

cleanLogContains :: Text -> Text -> [Value] -> Bool
cleanLogContains field expected = any ((== Just expected) . recordTextField field)

identityPlansCovered ::
  Text -> Map (Text, Text) V0V1IdentityMap -> StagedV1Dataset -> Bool
identityPlansCovered archiveId mappings staged =
  all covered (Map.toList (stagedV1DatasetIdentityPlans staged))
    && length archiveMappings
      == Map.size (stagedV1DatasetIdentityPlans staged)
  where
    archiveMappings = [mapping | mapping <- Map.elems mappings
      , v0V1IdentityMapArchive mapping == archiveId]
    covered (oldId, (newId, kind)) = case Map.lookup (archiveId, oldId) mappings of
      Just mapping -> v0V1IdentityMapNewId mapping == newId
        && v0V1IdentityMapKind mapping == kind
      Nothing -> False

archivePayloadMatches :: V0Archive -> MigrationState -> Bool
archivePayloadMatches archive state = case archiveBytes (v0ArchiveId archive) state of
  Nothing -> False
  Just payload -> hashV0ArchiveBytes payload == v0ArchiveSha256 archive
    && fromIntegral (LBS.length payload) == v0ArchiveByteSize archive
    && case readV0ArchiveEvents payload of
      Right events -> fromIntegral (length events) == v0ArchiveEventCount archive
      Left _ -> False

stagedReadyForActivation ::
  V0Archive -> V1Cutover -> MigrationState -> StagedV1Dataset -> Bool
stagedReadyForActivation archive cutover state staged =
  stagedV1DatasetArchiveHash staged == v0ArchiveSha256 archive
    && archivePayloadMatches archive state
    && stagedV1DatasetContentHash staged
      == hashCleanLog (stagedV1DatasetCleanLog staged)
    && maybe False (not . Text.null . Text.strip)
      (stagedV1DatasetComputedLogHash staged)
    && invariantsSatisfied
    && identityComplete
    && evidenceComplete
    && stagedV1DatasetInvariantsSatisfied staged == invariantsSatisfied
    && stagedV1DatasetIdentityCoverageComplete staged == identityComplete
    && stagedV1DatasetEvidenceCoverageComplete staged == evidenceComplete
  where
    writer = WriterProjection (stagedV1DatasetArchiveHash staged)
      (stagedV1DatasetProjectedBricks staged)
      (stagedV1DatasetIdentityPlans staged)
      (stagedV1DatasetCleanLog staged)
      (maybe "" id (stagedV1DatasetComputedLogHash staged))
    invariantsSatisfied = writerProjectionIsValid
      (v1CutoverProjectedEntityCount cutover)
      (v1CutoverRetainedEvidenceCount cutover) writer
      && writerProjectionMatchesArchive archive state writer
    identityComplete = identityPlansCovered (v0ArchiveId archive)
      (migrationStateIdentityMaps state) staged
    evidenceComplete = evidenceRecordCount (stagedV1DatasetCleanLog staged)
      == v1CutoverRetainedEvidenceCount cutover

mappingMatchesProjection :: MigrationState -> V0V1IdentityMap -> Bool
mappingMatchesProjection state mapping = any matches
  [staged | (cutoverId, staged) <- Map.toList
      (migrationStateStagedDatasets state)
    , Just cutover <- [Map.lookup cutoverId (migrationStateCutovers state)]
    , v1CutoverArchive cutover == v0V1IdentityMapArchive mapping]
  where
    matches staged = Map.lookup (v0V1IdentityMapOldId mapping)
      (stagedV1DatasetIdentityPlans staged)
      == Just (v0V1IdentityMapNewId mapping, v0V1IdentityMapKind mapping)

committedStageReady :: MigrationState -> V1Cutover -> Bool
committedStageReady state cutover = case
    (Map.lookup (v1CutoverArchive cutover) (migrationStateArchives state),
     Map.lookup (v1CutoverId cutover) (migrationStateStagedDatasets state)) of
  (Just archive, Just staged) -> stagedReadyForActivation archive cutover state staged
    && stagedV1DatasetComputedLogHash staged == v1CutoverV1LogHash cutover
  _ -> False

isOpaqueMigrationId :: Text -> Bool
isOpaqueMigrationId value = any validPrefix ["opaque:", "la1:"]
  where
    validPrefix prefix = case Text.stripPrefix prefix value of
      Just suffix -> not (Text.null (Text.strip suffix))
        && Text.strip value == value
      Nothing -> False

opaqueMigrationId :: Text -> Integer -> Text
opaqueMigrationId kind ordinal =
  "la1:migration:" <> kind <> ":" <> Text.justifyRight 12 '0' (Text.pack (show ordinal))

cutoverStatusText :: CutoverStatus -> Text
cutoverStatusText status = case status of
  CutoverPlanned -> "planned"
  ArchiveVerified -> "archive_verified"
  StateProjected -> "state_projected"
  ProjectionVerified -> "projection_verified"
  CutoverCommitted -> "committed"
  CutoverFailed -> "failed"

parseCutoverStatus :: Text -> Maybe CutoverStatus
parseCutoverStatus text = lookup text
  [ ("planned", CutoverPlanned)
  , ("archive_verified", ArchiveVerified)
  , ("state_projected", StateProjected)
  , ("projection_verified", ProjectionVerified)
  , ("committed", CutoverCommitted)
  , ("failed", CutoverFailed)
  ]

migratedEntityKindText :: MigratedEntityKind -> Text
migratedEntityKindText kind = case kind of
  MigratedBrick -> "brick"
  MigratedRaw -> "raw"
  MigratedParty -> "party"
  MigratedListEntry -> "list_entry"

parseMigratedEntityKind :: Text -> Maybe MigratedEntityKind
parseMigratedEntityKind text = lookup text
  [ ("brick", MigratedBrick)
  , ("raw", MigratedRaw)
  , ("party", MigratedParty)
  , ("list_entry", MigratedListEntry)
  ]

jsonOptions :: String -> Options
jsonOptions prefix = defaultOptions
  {fieldLabelModifier = camelTo2 '_' . drop (length prefix)}

maybeToList :: Maybe value -> [value]
maybeToList Nothing = []
maybeToList (Just value) = [value]

eitherToMaybe :: Either problem value -> Maybe value
eitherToMaybe (Left _) = Nothing
eitherToMaybe (Right value) = Just value

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Durable v1 source material, immutable snapshots, provenance, and shelves.
--
-- The module is pure. External reads are represented by an explicit
-- 'SourceReader' capability, and bytes enter through 'CanonicalBlobStore'.
-- Rendering and reconciliation therefore have no path to filesystem or
-- network I/O.
module LittleAnt.V1.Material
  ( BlobEntry (..)
  , CanonicalBlobStore
  , ExternalPresence (..)
  , ExternalWorkState (..)
  , MaterialError (..)
  , MaterialState (..)
  , Raw (..)
  , RawId (..)
  , RawLink (..)
  , RawLinkId (..)
  , RawLinkRole (..)
  , RawOrigin (..)
  , RawOriginId (..)
  , RawReviewDisposition (..)
  , RawReviewDispositionId (..)
  , RawReviewState (..)
  , RawShelf (..)
  , RawShelfId (..)
  , RawShelfMembership (..)
  , RawShelfMembershipId (..)
  , RawSnapshot (..)
  , RawSnapshotId (..)
  , RawStorageState (..)
  , ReviewDispositionKind (..)
  , SnapshotAvailability (..)
  , SnapshotCaptureResult (..)
  , SourceObservation (..)
  , SourceObservationId (..)
  , SourceReadKind (..)
  , SourceReadResult (..)
  , SourceReader (..)
  , addRawToShelf
  , archiveRaw
  , canonicalBlobPut
  , canonicalBlobRead
  , canonicalBlobVerify
  , canonicalContentHash
  , captureExternalRaw
  , captureInlineRaw
  , captureRawSnapshot
  , createRawShelf
  , emptyCanonicalBlobStore
  , emptyMaterialState
  , latestSourceObservation
  , linkDerivedRaw
  , linkRawToBrick
  , linkRawToEntry
  , materialProjection
  , openSourceReconciliationKinds
  , rawLatestSnapshot
  , rawLinkProjection
  , rawOriginProjection
  , rawProjection
  , rawReviewDispositionProjection
  , rawShelfMembershipProjection
  , rawShelfProjection
  , rawSnapshotProjection
  , reconcileRawLink
  , recordSourceObservation
  , registerMaterialBrick
  , registerMaterialListEntry
  , relocateRawOrigin
  , removeRawFromShelf
  , reopenRaw
  , reportSnapshotCorrupt
  , reportSnapshotMissing
  , retireRawOrigin
  , reviewRaw
  , sourceReaderFetch
  , sourceObservationProjection
  , sourceReaderObserve
  , unarchiveRaw
  , validateMaterialState
  , validateSourceReadResult
  , verifySnapshotBytes
  ) where

import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey, Value (..),
   genericParseJSON, genericToJSON, object, withText, (.=))
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy as LBS
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.List (maximumBy)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (catMaybes, isJust)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain
  (Authority, BrickId, BrickStatus, ListEntryId, canonicalEnglishText)

------------------------------------------------------------
-- Closed vocabulary
------------------------------------------------------------

data RawReviewState = RawPending | RawReviewedState
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data RawStorageState = RawActive | RawArchivedState
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data SnapshotAvailability = SnapshotAvailable | SnapshotMissing | SnapshotCorrupt
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data RawLinkRole = Attachment | Source | Evidence | DerivedFrom
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ExternalPresence = PresenceUnknown | Present | Removed | Unavailable
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ExternalWorkState = WorkUnknown | WorkOpen | WorkCompleted
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ReviewDispositionKind = Retained | Linked | ProducedWork | NoWork
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON RawReviewState where toJSON = String . rawReviewStateText
instance FromJSON RawReviewState where parseJSON = parseEnum "RawReviewState" rawReviewStateValues
instance ToJSON RawStorageState where toJSON = String . rawStorageStateText
instance FromJSON RawStorageState where parseJSON = parseEnum "RawStorageState" rawStorageStateValues
instance ToJSON SnapshotAvailability where toJSON = String . snapshotAvailabilityText
instance FromJSON SnapshotAvailability where parseJSON = parseEnum "SnapshotAvailability" snapshotAvailabilityValues
instance ToJSON RawLinkRole where toJSON = String . rawLinkRoleText
instance FromJSON RawLinkRole where parseJSON = parseEnum "RawLinkRole" rawLinkRoleValues
instance ToJSON ExternalPresence where toJSON = String . externalPresenceText
instance FromJSON ExternalPresence where parseJSON = parseEnum "ExternalPresence" externalPresenceValues
instance ToJSON ExternalWorkState where toJSON = String . externalWorkStateText
instance FromJSON ExternalWorkState where parseJSON = parseEnum "ExternalWorkState" externalWorkStateValues
instance ToJSON ReviewDispositionKind where toJSON = String . reviewDispositionText
instance FromJSON ReviewDispositionKind where parseJSON = parseEnum "ReviewDispositionKind" reviewDispositionValues

parseEnum :: String -> [(Text, value)] -> Value -> AesonTypes.Parser value
parseEnum name values = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate values)

rawReviewStateText :: RawReviewState -> Text
rawReviewStateText value = case value of
  RawPending -> "pending"
  RawReviewedState -> "reviewed"

rawStorageStateText :: RawStorageState -> Text
rawStorageStateText value = case value of
  RawActive -> "active"
  RawArchivedState -> "archived"

snapshotAvailabilityText :: SnapshotAvailability -> Text
snapshotAvailabilityText value = case value of
  SnapshotAvailable -> "available"
  SnapshotMissing -> "missing"
  SnapshotCorrupt -> "corrupt"

rawLinkRoleText :: RawLinkRole -> Text
rawLinkRoleText value = case value of
  Attachment -> "attachment"
  Source -> "source"
  Evidence -> "evidence"
  DerivedFrom -> "derived_from"

externalPresenceText :: ExternalPresence -> Text
externalPresenceText value = case value of
  PresenceUnknown -> "unknown"
  Present -> "present"
  Removed -> "removed"
  Unavailable -> "unavailable"

externalWorkStateText :: ExternalWorkState -> Text
externalWorkStateText value = case value of
  WorkUnknown -> "unknown"
  WorkOpen -> "open"
  WorkCompleted -> "completed"

reviewDispositionText :: ReviewDispositionKind -> Text
reviewDispositionText value = case value of
  Retained -> "retained"
  Linked -> "linked"
  ProducedWork -> "produced_work"
  NoWork -> "no_work"

rawReviewStateValues :: [(Text, RawReviewState)]
rawReviewStateValues = [(rawReviewStateText value, value) | value <- [minBound .. maxBound]]
rawStorageStateValues :: [(Text, RawStorageState)]
rawStorageStateValues = [(rawStorageStateText value, value) | value <- [minBound .. maxBound]]
snapshotAvailabilityValues :: [(Text, SnapshotAvailability)]
snapshotAvailabilityValues = [(snapshotAvailabilityText value, value) | value <- [minBound .. maxBound]]
rawLinkRoleValues :: [(Text, RawLinkRole)]
rawLinkRoleValues = [(rawLinkRoleText value, value) | value <- [minBound .. maxBound]]
externalPresenceValues :: [(Text, ExternalPresence)]
externalPresenceValues = [(externalPresenceText value, value) | value <- [minBound .. maxBound]]
externalWorkStateValues :: [(Text, ExternalWorkState)]
externalWorkStateValues = [(externalWorkStateText value, value) | value <- [minBound .. maxBound]]
reviewDispositionValues :: [(Text, ReviewDispositionKind)]
reviewDispositionValues = [(reviewDispositionText value, value) | value <- [minBound .. maxBound]]

------------------------------------------------------------
-- Identity and entities
------------------------------------------------------------

newtype RawId = RawId { unRawId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RawOriginId = RawOriginId { unRawOriginId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RawSnapshotId = RawSnapshotId { unRawSnapshotId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RawLinkId = RawLinkId { unRawLinkId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RawShelfId = RawShelfId { unRawShelfId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RawShelfMembershipId = RawShelfMembershipId { unRawShelfMembershipId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype SourceObservationId = SourceObservationId { unSourceObservationId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype RawReviewDispositionId = RawReviewDispositionId { unRawReviewDispositionId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

data Raw = Raw
  { rawId :: RawId
  , rawTitle :: Maybe Text
  , rawOriginalText :: Maybe Text
  , rawCanonicalEnglish :: Maybe Text
  , rawNormalizationAuthority :: Maybe Authority
  , rawReviewState :: RawReviewState
  , rawStorageState :: RawStorageState
  , rawCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data RawOrigin = RawOrigin
  { rawOriginId :: RawOriginId
  , rawOriginRaw :: RawId
  , rawOriginAdapter :: Text
  , rawOriginLocator :: Text
  , rawOriginExternalId :: Maybe Text
  , rawOriginLastCheckedAt :: Maybe UTCTime
  , rawOriginLastObservedRevision :: Maybe Text
  , rawOriginHistoricalOnly :: Bool
  , rawOriginCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data RawSnapshot = RawSnapshot
  { rawSnapshotId :: RawSnapshotId
  , rawSnapshotRaw :: RawId
  , rawSnapshotContentHash :: Text
  , rawSnapshotSize :: Integer
  , rawSnapshotMediaType :: Text
  , rawSnapshotCapturedAt :: UTCTime
  , rawSnapshotOriginRevision :: Maybe Text
  , rawSnapshotAvailability :: SnapshotAvailability
  , rawSnapshotVerifiedAt :: Maybe UTCTime
  , rawSnapshotCreationOrdinal :: Integer
  }
  deriving stock (Eq, Show, Generic)

data RawLink = RawLink
  { rawLinkId :: RawLinkId
  , rawLinkRaw :: RawId
  , rawLinkRole :: RawLinkRole
  , rawLinkOwnerBrick :: Maybe BrickId
  , rawLinkOwnerEntry :: Maybe ListEntryId
  , rawLinkOwnerRaw :: Maybe RawId
  , rawLinkReconciledSnapshot :: Maybe RawSnapshotId
  , rawLinkCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data RawShelf = RawShelf
  { rawShelfId :: RawShelfId
  , rawShelfName :: Text
  , rawShelfCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data RawShelfMembership = RawShelfMembership
  { rawShelfMembershipId :: RawShelfMembershipId
  , rawShelfMembershipRaw :: RawId
  , rawShelfMembershipShelf :: RawShelfId
  , rawShelfMembershipAddedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data SourceObservation = SourceObservation
  { sourceObservationId :: SourceObservationId
  , sourceObservationOrigin :: RawOriginId
  , sourceObservationObservedAt :: UTCTime
  , sourceObservationAuthority :: Authority
  , sourceObservationExternalObservationId :: Maybe Text
  , sourceObservationRevision :: Maybe Text
  , sourceObservationPresence :: ExternalPresence
  , sourceObservationWorkState :: ExternalWorkState
  , sourceObservationFailureDetail :: Maybe Text
  , sourceObservationCreationOrdinal :: Integer
  }
  deriving stock (Eq, Show, Generic)

data RawReviewDisposition = RawReviewDisposition
  { rawReviewDispositionId :: RawReviewDispositionId
  , rawReviewDispositionRaw :: RawId
  , rawReviewDispositionKind :: ReviewDispositionKind
  , rawReviewDispositionBrick :: Maybe BrickId
  , rawReviewDispositionRecordedAt :: UTCTime
  , rawReviewDispositionAuthority :: Authority
  , rawReviewDispositionNote :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON Raw where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON Raw where parseJSON = genericParseJSON AesonTypes.defaultOptions
instance ToJSON RawOrigin where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON RawOrigin where parseJSON = genericParseJSON AesonTypes.defaultOptions
instance ToJSON RawSnapshot where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON RawSnapshot where parseJSON = genericParseJSON AesonTypes.defaultOptions
instance ToJSON RawLink where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON RawLink where parseJSON = genericParseJSON AesonTypes.defaultOptions
instance ToJSON RawShelf where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON RawShelf where parseJSON = genericParseJSON AesonTypes.defaultOptions
instance ToJSON RawShelfMembership where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON RawShelfMembership where parseJSON = genericParseJSON AesonTypes.defaultOptions
instance ToJSON SourceObservation where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON SourceObservation where parseJSON = genericParseJSON AesonTypes.defaultOptions
instance ToJSON RawReviewDisposition where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON RawReviewDisposition where parseJSON = genericParseJSON AesonTypes.defaultOptions

-- | Material state also records the work IDs that may own links. It does not
-- own or mutate those work entities; their status is a read-only reference
-- integrity projection supplied by the domain boundary.
data MaterialState = MaterialState
  { materialNextIdentityOrdinal :: Integer
  , materialRaws :: Map RawId Raw
  , materialOrigins :: Map RawOriginId RawOrigin
  , materialSnapshots :: Map RawSnapshotId RawSnapshot
  , materialLinks :: Map RawLinkId RawLink
  , materialShelves :: Map RawShelfId RawShelf
  , materialMemberships :: Map RawShelfMembershipId RawShelfMembership
  , materialObservations :: Map SourceObservationId SourceObservation
  , materialReviewDispositions :: Map RawReviewDispositionId RawReviewDisposition
  , materialBrickStatuses :: Map BrickId BrickStatus
  , materialListEntries :: Set ListEntryId
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON MaterialState where toJSON = genericToJSON AesonTypes.defaultOptions
instance FromJSON MaterialState where parseJSON = genericParseJSON AesonTypes.defaultOptions

emptyMaterialState :: MaterialState
emptyMaterialState = MaterialState
  { materialNextIdentityOrdinal = 0
  , materialRaws = Map.empty
  , materialOrigins = Map.empty
  , materialSnapshots = Map.empty
  , materialLinks = Map.empty
  , materialShelves = Map.empty
  , materialMemberships = Map.empty
  , materialObservations = Map.empty
  , materialReviewDispositions = Map.empty
  , materialBrickStatuses = Map.empty
  , materialListEntries = Set.empty
  }

------------------------------------------------------------
-- Explicit source-reader and blob boundaries
------------------------------------------------------------

data SourceReadKind = ObserveSource | FetchSource
  deriving stock (Eq, Ord, Show, Generic)

data SourceReadResult = SourceReadResult
  { sourceReadAdapter :: Text
  , sourceReadLocator :: Text
  , sourceReadObservedAt :: UTCTime
  , sourceReadAuthority :: Authority
  , sourceReadExternalRevision :: Maybe Text
  , sourceReadPayload :: Value
  }
  deriving stock (Eq, Show, Generic)

-- | Adapter capability. Calling it is always explicit; no material query has
-- access to this value.
newtype SourceReader = SourceReader
  { runSourceReader :: SourceReadKind -> Text -> Text -> Either MaterialError SourceReadResult
  }

sourceReaderObserve :: SourceReader -> Text -> Text -> Either MaterialError SourceReadResult
sourceReaderObserve reader = runSourceReader reader ObserveSource

sourceReaderFetch :: SourceReader -> Text -> Text -> Either MaterialError SourceReadResult
sourceReaderFetch reader = runSourceReader reader FetchSource

validateSourceReadResult ::
  Text -> Text -> SourceReadResult -> Either MaterialError SourceReadResult
validateSourceReadResult adapter locator result = do
  unless (sourceReadAdapter result == adapter && sourceReadLocator result == locator)
    (Left (InvalidSourceAttribution "adapter or locator differs from the request"))
  validateNonEmpty "source adapter" (sourceReadAdapter result)
  validateNonEmpty "source locator" (sourceReadLocator result)
  pure result

data BlobEntry = BlobEntry
  { blobEntryContentHash :: Text
  , blobEntrySize :: Integer
  , blobEntryMediaType :: Text
  , blobEntryBytes :: LBS.ByteString
  }
  deriving stock (Eq, Show)

newtype CanonicalBlobStore = CanonicalBlobStore
  { canonicalBlobs :: Map Text BlobEntry
  }
  deriving stock (Eq, Show)

emptyCanonicalBlobStore :: CanonicalBlobStore
emptyCanonicalBlobStore = CanonicalBlobStore Map.empty

canonicalContentHash :: LBS.ByteString -> Text
canonicalContentHash bytes = "sha256:" <> Text.pack (showDigest (sha256 bytes))

canonicalBlobPut ::
  Text -> Integer -> Text -> LBS.ByteString -> CanonicalBlobStore ->
  Either MaterialError CanonicalBlobStore
canonicalBlobPut contentHash size mediaType bytes store = do
  validateNonEmpty "media type" mediaType
  unless (size >= 0) (Left (InvalidSnapshotSize size))
  let actualHash = canonicalContentHash bytes
      actualSize = fromIntegral (LBS.length bytes)
  unless (contentHash == actualHash)
    (Left (BlobHashMismatch contentHash actualHash))
  unless (size == actualSize) (Left (BlobSizeMismatch size actualSize))
  case Map.lookup contentHash (canonicalBlobs store) of
    Nothing -> Right (CanonicalBlobStore (Map.insert contentHash
      (BlobEntry contentHash size mediaType bytes) (canonicalBlobs store)))
    Just existing
      | blobEntryBytes existing == bytes && blobEntrySize existing == size -> Right store
      | otherwise -> Left (BlobHashCollision contentHash)

canonicalBlobRead :: Text -> CanonicalBlobStore -> Either MaterialError LBS.ByteString
canonicalBlobRead contentHash store = maybe
  (Left (BlobNotFound contentHash))
  (Right . blobEntryBytes)
  (Map.lookup contentHash (canonicalBlobs store))

canonicalBlobVerify :: Text -> CanonicalBlobStore -> Bool
canonicalBlobVerify contentHash store = case Map.lookup contentHash (canonicalBlobs store) of
  Nothing -> False
  Just entry ->
    canonicalContentHash (blobEntryBytes entry) == contentHash
    && fromIntegral (LBS.length (blobEntryBytes entry)) == blobEntrySize entry

------------------------------------------------------------
-- Failures and creation
------------------------------------------------------------

data MaterialError
  = UnknownRaw RawId
  | UnknownRawOrigin RawOriginId
  | UnknownRawSnapshot RawSnapshotId
  | UnknownRawLink RawLinkId
  | UnknownRawShelf RawShelfId
  | UnknownBrickOwner BrickId
  | UnknownListEntryOwner ListEntryId
  | InvalidMaterialText Text
  | InvalidNormalizationAttribution
  | InvalidSnapshotSize Integer
  | DuplicateRawSnapshot RawId Text
  | SnapshotMetadataMismatch RawSnapshotId
  | InvalidMaterialTransition Text
  | InvalidRawLinkRole RawLinkRole
  | InvalidRawLinkOwner Text
  | DuplicateRawLink
  | DuplicateShelfMembership RawId RawShelfId
  | MissingShelfMembership RawId RawShelfId
  | BlobHashMismatch Text Text
  | BlobSizeMismatch Integer Integer
  | BlobHashCollision Text
  | BlobNotFound Text
  | InvalidSourceAttribution Text
  | MaterialInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

data SnapshotCaptureResult
  = SnapshotCreated RawSnapshot
  | SnapshotReused RawSnapshot
  deriving stock (Eq, Show, Generic)

captureInlineRaw ::
  Text -> Maybe Text -> Maybe Authority -> UTCTime -> MaterialState ->
  Either MaterialError (Raw, MaterialState)
captureInlineRaw original canonical authority createdAt state = do
  validateNonEmpty "original Raw text" original
  validateNormalization canonical authority
  let (identifier, nextOrdinal) = allocateRaw state
      raw = Raw identifier Nothing (Just original) canonical authority
        RawPending RawActive createdAt
      next = state
        { materialNextIdentityOrdinal = nextOrdinal
        , materialRaws = Map.insert identifier raw (materialRaws state)
        }
  validateAndReturn raw next

captureExternalRaw ::
  Maybe Text -> Text -> Text -> Maybe Text -> UTCTime -> MaterialState ->
  Either MaterialError ((Raw, RawOrigin), MaterialState)
captureExternalRaw title adapter locator externalId createdAt state = do
  mapM_ (validateNonEmpty "Raw title") title
  validateNonEmpty "origin adapter" adapter
  validateNonEmpty "origin locator" locator
  let (rawIdentifier, afterRaw) = allocateRaw state
      raw = Raw rawIdentifier title Nothing Nothing Nothing RawPending RawActive createdAt
      stateAfterRaw = state {materialNextIdentityOrdinal = afterRaw}
      (originIdentifier, afterOrigin) = allocateRawOrigin stateAfterRaw
      origin = RawOrigin originIdentifier rawIdentifier adapter locator externalId
        Nothing Nothing False createdAt
      next = state
        { materialNextIdentityOrdinal = afterOrigin
        , materialRaws = Map.insert rawIdentifier raw (materialRaws state)
        , materialOrigins = Map.insert originIdentifier origin (materialOrigins state)
        }
  validateMaterialState next
  pure ((raw, origin), next)

captureRawSnapshot ::
  RawId -> Text -> Integer -> Text -> Maybe Text -> UTCTime -> MaterialState ->
  Either MaterialError (SnapshotCaptureResult, MaterialState)
captureRawSnapshot rawIdentifier contentHash size mediaType originRevision capturedAt state = do
  _ <- lookupRaw rawIdentifier state
  validateNonEmpty "content hash" contentHash
  validateNonEmpty "media type" mediaType
  unless (size >= 0) (Left (InvalidSnapshotSize size))
  case existingSnapshot rawIdentifier contentHash state of
    Just existing
      | rawSnapshotSize existing == size
          && rawSnapshotMediaType existing == mediaType ->
          pure (SnapshotReused existing, state)
      | otherwise -> Left (SnapshotMetadataMismatch (rawSnapshotId existing))
    Nothing -> do
      let ordinal = materialNextIdentityOrdinal state
          (identifier, nextOrdinal) = allocateRawSnapshot state
          snapshot = RawSnapshot identifier rawIdentifier contentHash size mediaType
            capturedAt originRevision SnapshotAvailable (Just capturedAt) ordinal
          next = state
            { materialNextIdentityOrdinal = nextOrdinal
            , materialSnapshots = Map.insert identifier snapshot
                (materialSnapshots state)
            }
      validateAndReturn (SnapshotCreated snapshot) next

existingSnapshot :: RawId -> Text -> MaterialState -> Maybe RawSnapshot
existingSnapshot rawIdentifier contentHash =
  findFirst (\snapshot -> rawSnapshotRaw snapshot == rawIdentifier
    && rawSnapshotContentHash snapshot == contentHash)
  . Map.elems . materialSnapshots

------------------------------------------------------------
-- Snapshot and origin transitions
------------------------------------------------------------

reportSnapshotMissing ::
  RawSnapshotId -> MaterialState -> Either MaterialError (RawSnapshot, MaterialState)
reportSnapshotMissing identifier = updateSnapshotAvailability identifier
  [SnapshotAvailable, SnapshotCorrupt] SnapshotMissing Nothing

reportSnapshotCorrupt ::
  RawSnapshotId -> MaterialState -> Either MaterialError (RawSnapshot, MaterialState)
reportSnapshotCorrupt identifier = updateSnapshotAvailability identifier
  [SnapshotAvailable, SnapshotMissing] SnapshotCorrupt Nothing

verifySnapshotBytes ::
  RawSnapshotId -> UTCTime -> MaterialState ->
  Either MaterialError (RawSnapshot, MaterialState)
verifySnapshotBytes identifier verifiedAt = updateSnapshotAvailability identifier
  [SnapshotMissing, SnapshotCorrupt] SnapshotAvailable (Just verifiedAt)

updateSnapshotAvailability ::
  RawSnapshotId -> [SnapshotAvailability] -> SnapshotAvailability ->
  Maybe UTCTime -> MaterialState ->
  Either MaterialError (RawSnapshot, MaterialState)
updateSnapshotAvailability identifier allowed target verifiedAt state = do
  snapshot <- lookupSnapshot identifier state
  unless (rawSnapshotAvailability snapshot `elem` allowed)
    (Left (InvalidMaterialTransition "snapshot availability edge is not declared"))
  let updated = snapshot
        { rawSnapshotAvailability = target
        , rawSnapshotVerifiedAt = verifiedAt
        }
      next = state {materialSnapshots = Map.insert identifier updated
        (materialSnapshots state)}
  validateAndReturn updated next

recordSourceObservation ::
  RawOriginId -> Authority -> Maybe Text -> Maybe Text -> ExternalPresence ->
  ExternalWorkState -> Maybe Text -> UTCTime -> MaterialState ->
  Either MaterialError (SourceObservation, MaterialState)
recordSourceObservation originIdentifier authority externalObservationId revision
    presence workState failureDetail observedAt state = do
  origin <- lookupOrigin originIdentifier state
  let ordinal = materialNextIdentityOrdinal state
      (identifier, nextOrdinal) = allocateSourceObservation state
      observation = SourceObservation identifier originIdentifier observedAt authority
        externalObservationId revision presence workState failureDetail ordinal
      updatedOrigin = origin
        { rawOriginLastCheckedAt = Just observedAt
        , rawOriginLastObservedRevision = revision <|> rawOriginLastObservedRevision origin
        }
      next = state
        { materialNextIdentityOrdinal = nextOrdinal
        , materialOrigins = Map.insert originIdentifier updatedOrigin
            (materialOrigins state)
        , materialObservations = Map.insert identifier observation
            (materialObservations state)
        }
  validateAndReturn observation next

relocateRawOrigin ::
  RawOriginId -> Text -> MaterialState -> Either MaterialError (RawOrigin, MaterialState)
relocateRawOrigin identifier locator state = do
  validateNonEmpty "origin locator" locator
  origin <- lookupOrigin identifier state
  when (rawOriginLocator origin == locator)
    (Left (InvalidMaterialTransition "origin locator is unchanged"))
  let updated = origin {rawOriginLocator = locator}
      next = state {materialOrigins = Map.insert identifier updated
        (materialOrigins state)}
  validateAndReturn updated next

retireRawOrigin ::
  RawOriginId -> MaterialState -> Either MaterialError (RawOrigin, MaterialState)
retireRawOrigin identifier state = do
  origin <- lookupOrigin identifier state
  when (rawOriginHistoricalOnly origin)
    (Left (InvalidMaterialTransition "origin is already historical"))
  let updated = origin {rawOriginHistoricalOnly = True}
      next = state {materialOrigins = Map.insert identifier updated
        (materialOrigins state)}
  validateAndReturn updated next

------------------------------------------------------------
-- Review/storage axes and links
------------------------------------------------------------

reviewRaw ::
  RawId -> ReviewDispositionKind -> Maybe BrickId -> Authority -> Maybe Text ->
  UTCTime -> MaterialState ->
  Either MaterialError ((Raw, RawReviewDisposition), MaterialState)
reviewRaw rawIdentifier kind brick authority note recordedAt state = do
  raw <- lookupRaw rawIdentifier state
  unless (rawReviewState raw == RawPending)
    (Left (InvalidMaterialTransition "only pending Raw can be reviewed"))
  mapM_ (`requireBrickOwner` state) brick
  let updatedRaw = raw {rawReviewState = RawReviewedState}
      stateAfterRaw = state {materialRaws = Map.insert rawIdentifier updatedRaw
        (materialRaws state)}
      (identifier, nextOrdinal) = allocateReviewDisposition stateAfterRaw
      disposition = RawReviewDisposition identifier rawIdentifier kind brick
        recordedAt authority note
      next = stateAfterRaw
        { materialNextIdentityOrdinal = nextOrdinal
        , materialReviewDispositions = Map.insert identifier disposition
            (materialReviewDispositions stateAfterRaw)
        }
  validateMaterialState next
  pure ((updatedRaw, disposition), next)

reopenRaw :: RawId -> MaterialState -> Either MaterialError (Raw, MaterialState)
reopenRaw identifier = transitionRawReview identifier RawReviewedState RawPending

archiveRaw :: RawId -> MaterialState -> Either MaterialError (Raw, MaterialState)
archiveRaw identifier = transitionRawStorage identifier RawActive RawArchivedState

unarchiveRaw :: RawId -> MaterialState -> Either MaterialError (Raw, MaterialState)
unarchiveRaw identifier = transitionRawStorage identifier RawArchivedState RawActive

transitionRawReview ::
  RawId -> RawReviewState -> RawReviewState -> MaterialState ->
  Either MaterialError (Raw, MaterialState)
transitionRawReview identifier expected target state = do
  raw <- lookupRaw identifier state
  unless (rawReviewState raw == expected)
    (Left (InvalidMaterialTransition "Raw review-state edge is not declared"))
  let updated = raw {rawReviewState = target}
      next = state {materialRaws = Map.insert identifier updated (materialRaws state)}
  validateAndReturn updated next

transitionRawStorage ::
  RawId -> RawStorageState -> RawStorageState -> MaterialState ->
  Either MaterialError (Raw, MaterialState)
transitionRawStorage identifier expected target state = do
  raw <- lookupRaw identifier state
  unless (rawStorageState raw == expected)
    (Left (InvalidMaterialTransition "Raw storage-state edge is not declared"))
  let updated = raw {rawStorageState = target}
      next = state {materialRaws = Map.insert identifier updated (materialRaws state)}
  validateAndReturn updated next

registerMaterialBrick :: BrickId -> BrickStatus -> MaterialState -> MaterialState
registerMaterialBrick identifier status state = state
  {materialBrickStatuses = Map.insert identifier status (materialBrickStatuses state)}

registerMaterialListEntry :: ListEntryId -> MaterialState -> MaterialState
registerMaterialListEntry identifier state = state
  {materialListEntries = Set.insert identifier (materialListEntries state)}

linkRawToBrick ::
  RawId -> BrickId -> RawLinkRole -> Maybe RawSnapshotId -> UTCTime ->
  MaterialState -> Either MaterialError (RawLink, MaterialState)
linkRawToBrick rawIdentifier brick role baseline createdAt state = do
  _ <- lookupRaw rawIdentifier state
  _ <- requireBrickOwner brick state
  requireWorkLinkRole role
  mapM_ (requireSnapshotForRaw rawIdentifier state) baseline
  when (any (sameBrickLink rawIdentifier brick role) (Map.elems (materialLinks state)))
    (Left DuplicateRawLink)
  createRawLink rawIdentifier role (Just brick) Nothing Nothing baseline createdAt state

linkRawToEntry ::
  RawId -> ListEntryId -> RawLinkRole -> UTCTime -> MaterialState ->
  Either MaterialError (RawLink, MaterialState)
linkRawToEntry rawIdentifier entry role createdAt state = do
  _ <- lookupRaw rawIdentifier state
  unless (Set.member entry (materialListEntries state))
    (Left (UnknownListEntryOwner entry))
  requireWorkLinkRole role
  when (any (sameEntryLink rawIdentifier entry role) (Map.elems (materialLinks state)))
    (Left DuplicateRawLink)
  createRawLink rawIdentifier role Nothing (Just entry) Nothing Nothing createdAt state

-- | The link is attached to the source Raw and owned by the derived Raw, as
-- declared by @LinkDerivedRaw(raw, source)@.
linkDerivedRaw ::
  RawId -> RawId -> UTCTime -> MaterialState ->
  Either MaterialError (RawLink, MaterialState)
linkDerivedRaw derived source createdAt state = do
  _ <- lookupRaw derived state
  _ <- lookupRaw source state
  when (derived == source)
    (Left (InvalidRawLinkOwner "Raw cannot derive from itself"))
  when (any (sameDerivedLink source derived) (Map.elems (materialLinks state)))
    (Left DuplicateRawLink)
  createRawLink source DerivedFrom Nothing Nothing (Just derived) Nothing createdAt state

createRawLink ::
  RawId -> RawLinkRole -> Maybe BrickId -> Maybe ListEntryId -> Maybe RawId ->
  Maybe RawSnapshotId -> UTCTime -> MaterialState ->
  Either MaterialError (RawLink, MaterialState)
createRawLink rawIdentifier role brick entry ownerRaw baseline createdAt state = do
  let (identifier, nextOrdinal) = allocateRawLink state
      link = RawLink identifier rawIdentifier role brick entry ownerRaw baseline createdAt
      next = state
        { materialNextIdentityOrdinal = nextOrdinal
        , materialLinks = Map.insert identifier link (materialLinks state)
        }
  validateAndReturn link next

reconcileRawLink ::
  RawLinkId -> RawSnapshotId -> MaterialState ->
  Either MaterialError (RawLink, MaterialState)
reconcileRawLink linkIdentifier snapshotIdentifier state = do
  link <- lookupLink linkIdentifier state
  unless (rawLinkRole link `elem` [Source, Evidence])
    (Left (InvalidRawLinkRole (rawLinkRole link)))
  _ <- requireSnapshotForRaw (rawLinkRaw link) state snapshotIdentifier
  let updated = link {rawLinkReconciledSnapshot = Just snapshotIdentifier}
      next = state {materialLinks = Map.insert linkIdentifier updated
        (materialLinks state)}
  validateAndReturn updated next

------------------------------------------------------------
-- Flat shelves
------------------------------------------------------------

createRawShelf ::
  Text -> UTCTime -> MaterialState -> Either MaterialError (RawShelf, MaterialState)
createRawShelf name createdAt state = do
  validateNonEmpty "Raw shelf name" name
  let (identifier, nextOrdinal) = allocateRawShelf state
      shelf = RawShelf identifier name createdAt
      next = state
        { materialNextIdentityOrdinal = nextOrdinal
        , materialShelves = Map.insert identifier shelf (materialShelves state)
        }
  validateAndReturn shelf next

addRawToShelf ::
  RawId -> RawShelfId -> UTCTime -> MaterialState ->
  Either MaterialError (RawShelfMembership, MaterialState)
addRawToShelf rawIdentifier shelfIdentifier addedAt state = do
  _ <- lookupRaw rawIdentifier state
  _ <- lookupShelf shelfIdentifier state
  when (isJust (findMembership rawIdentifier shelfIdentifier state))
    (Left (DuplicateShelfMembership rawIdentifier shelfIdentifier))
  let (identifier, nextOrdinal) = allocateShelfMembership state
      membership = RawShelfMembership identifier rawIdentifier shelfIdentifier addedAt
      next = state
        { materialNextIdentityOrdinal = nextOrdinal
        , materialMemberships = Map.insert identifier membership
            (materialMemberships state)
        }
  validateAndReturn membership next

removeRawFromShelf ::
  RawId -> RawShelfId -> MaterialState -> Either MaterialError MaterialState
removeRawFromShelf rawIdentifier shelfIdentifier state = do
  membership <- maybe
    (Left (MissingShelfMembership rawIdentifier shelfIdentifier))
    Right
    (findMembership rawIdentifier shelfIdentifier state)
  let next = state {materialMemberships = Map.delete
        (rawShelfMembershipId membership) (materialMemberships state)}
  validateMaterialState next
  pure next

findMembership :: RawId -> RawShelfId -> MaterialState -> Maybe RawShelfMembership
findMembership rawIdentifier shelfIdentifier = findFirst
  (\membership -> rawShelfMembershipRaw membership == rawIdentifier
    && rawShelfMembershipShelf membership == shelfIdentifier)
  . Map.elems . materialMemberships

------------------------------------------------------------
-- Derived values and declared projections
------------------------------------------------------------

rawLatestSnapshot :: MaterialState -> RawId -> Either MaterialError (Maybe RawSnapshot)
rawLatestSnapshot state identifier = do
  _ <- lookupRaw identifier state
  pure (maximumByMaybe compareSnapshotCreation
    [snapshot | snapshot <- Map.elems (materialSnapshots state),
      rawSnapshotRaw snapshot == identifier])

latestSourceObservation ::
  MaterialState -> RawOriginId -> Either MaterialError (Maybe SourceObservation)
latestSourceObservation state identifier = do
  _ <- lookupOrigin identifier state
  pure (maximumByMaybe compareObservationCreation
    [observation | observation <- Map.elems (materialObservations state),
      sourceObservationOrigin observation == identifier])

openSourceReconciliationKinds :: MaterialState -> BrickId -> [Text]
openSourceReconciliationKinds state brick =
  ["source_reconciliation" | any linkNeedsReconciliation relevant]
  where
    relevant =
      [link | link <- Map.elems (materialLinks state),
        rawLinkOwnerBrick link == Just brick,
        rawLinkRole link `elem` [Source, Evidence]]
    linkNeedsReconciliation link = case rawLatestSnapshot state (rawLinkRaw link) of
      Left _ -> False
      Right Nothing -> False
      Right (Just latest) -> rawLinkReconciledSnapshot link /= Just (rawSnapshotId latest)

rawProjection :: MaterialState -> RawId -> Either MaterialError Value
rawProjection state identifier = do
  raw <- lookupRaw identifier state
  latest <- rawLatestSnapshot state identifier
  let origins = filter ((== identifier) . rawOriginRaw)
        (Map.elems (materialOrigins state))
      snapshots = filter ((== identifier) . rawSnapshotRaw)
        (Map.elems (materialSnapshots state))
      links = filter ((== identifier) . rawLinkRaw)
        (Map.elems (materialLinks state))
      memberships = filter ((== identifier) . rawShelfMembershipRaw)
        (Map.elems (materialMemberships state))
  pure (object
    [ "id" .= rawId raw
    , "title" .= rawTitle raw
    , "original_text" .= rawOriginalText raw
    , "canonical_english" .= rawCanonicalEnglish raw
    , "normalization_authority" .= rawNormalizationAuthority raw
    , "review_state" .= rawReviewState raw
    , "storage_state" .= rawStorageState raw
    , "created_at" .= rawCreatedAt raw
    , "origin" .= listToMaybe origins
    , "snapshots" .= map rawSnapshotProjection snapshots
    , "links" .= map rawLinkProjectionValue links
    , "memberships" .= map rawShelfMembershipProjection memberships
    , "latest_snapshot" .= fmap rawSnapshotProjection latest
    ])

rawLinkProjection :: MaterialState -> RawLinkId -> Either MaterialError Value
rawLinkProjection state identifier = rawLinkProjectionValue <$> lookupLink identifier state

rawLinkProjectionValue :: RawLink -> Value
rawLinkProjectionValue link = object
  [ "id" .= rawLinkId link
  , "raw" .= rawLinkRaw link
  , "role" .= rawLinkRole link
  , "owner_brick" .= rawLinkOwnerBrick link
  , "owner_entry" .= rawLinkOwnerEntry link
  , "owner_raw" .= rawLinkOwnerRaw link
  , "reconciled_snapshot" .= fmap (\identifier -> object ["id" .= identifier])
      (rawLinkReconciledSnapshot link)
  , "created_at" .= rawLinkCreatedAt link
  ]

rawSnapshotProjection :: RawSnapshot -> Value
rawSnapshotProjection snapshot = object
  [ "id" .= rawSnapshotId snapshot
  , "raw" .= rawSnapshotRaw snapshot
  , "content_hash" .= rawSnapshotContentHash snapshot
  , "size" .= rawSnapshotSize snapshot
  , "media_type" .= rawSnapshotMediaType snapshot
  , "captured_at" .= rawSnapshotCapturedAt snapshot
  , "origin_revision" .= rawSnapshotOriginRevision snapshot
  , "availability" .= rawSnapshotAvailability snapshot
  , "verified_at" .= rawSnapshotVerifiedAt snapshot
  ]

rawOriginProjection :: MaterialState -> RawOrigin -> Value
rawOriginProjection state origin = object
  [ "id" .= rawOriginId origin
  , "raw" .= rawOriginRaw origin
  , "adapter" .= rawOriginAdapter origin
  , "locator" .= rawOriginLocator origin
  , "external_id" .= rawOriginExternalId origin
  , "last_checked_at" .= rawOriginLastCheckedAt origin
  , "last_observed_revision" .= rawOriginLastObservedRevision origin
  , "historical_only" .= rawOriginHistoricalOnly origin
  , "created_at" .= rawOriginCreatedAt origin
  , "observations" .= map sourceObservationProjection
      [observation | observation <- Map.elems (materialObservations state),
        sourceObservationOrigin observation == rawOriginId origin]
  ]

rawShelfProjection :: MaterialState -> RawShelf -> Value
rawShelfProjection state shelf = object
  [ "id" .= rawShelfId shelf
  , "name" .= rawShelfName shelf
  , "created_at" .= rawShelfCreatedAt shelf
  , "memberships" .= map rawShelfMembershipProjection
      [membership | membership <- Map.elems (materialMemberships state),
        rawShelfMembershipShelf membership == rawShelfId shelf]
  ]

rawShelfMembershipProjection :: RawShelfMembership -> Value
rawShelfMembershipProjection membership = object
  [ "id" .= rawShelfMembershipId membership
  , "raw" .= rawShelfMembershipRaw membership
  , "shelf" .= rawShelfMembershipShelf membership
  , "added_at" .= rawShelfMembershipAddedAt membership
  ]

sourceObservationProjection :: SourceObservation -> Value
sourceObservationProjection observation = object
  [ "id" .= sourceObservationId observation
  , "origin" .= sourceObservationOrigin observation
  , "observed_at" .= sourceObservationObservedAt observation
  , "authority" .= sourceObservationAuthority observation
  , "external_observation_id" .= sourceObservationExternalObservationId observation
  , "revision" .= sourceObservationRevision observation
  , "presence" .= sourceObservationPresence observation
  , "work_state" .= sourceObservationWorkState observation
  , "failure_detail" .= sourceObservationFailureDetail observation
  ]

rawReviewDispositionProjection :: RawReviewDisposition -> Value
rawReviewDispositionProjection disposition = object
  [ "id" .= rawReviewDispositionId disposition
  , "raw" .= rawReviewDispositionRaw disposition
  , "kind" .= rawReviewDispositionKind disposition
  , "brick" .= rawReviewDispositionBrick disposition
  , "recorded_at" .= rawReviewDispositionRecordedAt disposition
  , "authority" .= rawReviewDispositionAuthority disposition
  , "note" .= rawReviewDispositionNote disposition
  ]

materialProjection :: MaterialState -> Either MaterialError Value
materialProjection state = do
  validateMaterialState state
  raws <- mapM (rawProjection state . rawId) (Map.elems (materialRaws state))
  pure (object
    [ "raws" .= raws
    , "origins" .= map (rawOriginProjection state) (Map.elems (materialOrigins state))
    , "snapshots" .= map rawSnapshotProjection (Map.elems (materialSnapshots state))
    , "links" .= map rawLinkProjectionValue (Map.elems (materialLinks state))
    , "shelves" .= map (rawShelfProjection state) (Map.elems (materialShelves state))
    , "memberships" .= map rawShelfMembershipProjection
        (Map.elems (materialMemberships state))
    , "observations" .= map sourceObservationProjection
        (Map.elems (materialObservations state))
    , "review_dispositions" .= map rawReviewDispositionProjection
        (Map.elems (materialReviewDispositions state))
    ])

------------------------------------------------------------
-- Invariants
------------------------------------------------------------

validateMaterialState :: MaterialState -> Either MaterialError ()
validateMaterialState state = case violations of
  [] -> Right ()
  _ -> Left (MaterialInvariantViolation violations)
  where
    raws = Map.elems (materialRaws state)
    origins = Map.elems (materialOrigins state)
    snapshots = Map.elems (materialSnapshots state)
    links = Map.elems (materialLinks state)
    memberships = Map.elems (materialMemberships state)
    observations = Map.elems (materialObservations state)
    dispositions = Map.elems (materialReviewDispositions state)
    originCounts = Map.fromListWith (+) [(rawOriginRaw origin, 1 :: Int) | origin <- origins]
    membershipPairs = [(rawShelfMembershipRaw membership,
      rawShelfMembershipShelf membership) | membership <- memberships]
    linkKeys = map linkUniquenessKey links
    violations = concat
      [ ["material identity ordinal is negative" | materialNextIdentityOrdinal state < 0]
      , ["Raw normalization is not attributed" | any invalidNormalization raws]
      , ["Raw has more than one origin" | any (> 1) (Map.elems originCounts)]
      , ["origin references unknown Raw" | any
          ((`Map.notMember` materialRaws state) . rawOriginRaw) origins]
      , ["snapshot references unknown Raw" | any
          ((`Map.notMember` materialRaws state) . rawSnapshotRaw) snapshots]
      , ["snapshot metadata is invalid" | any invalidSnapshot snapshots]
      , ["RawLink does not have exactly one owner" | any invalidOwnerCount links]
      , ["derived RawLink does not own Raw" | any invalidDerivedOwner links]
      , ["work RawLink owns Raw" | any invalidWorkOwner links]
      , ["RawLink references unknown Raw" | any invalidLinkReference links]
      , ["reconciled snapshot belongs to another Raw" | any invalidBaseline links]
      , ["duplicate RawLink" | distinctCount linkKeys /= length linkKeys]
      , ["membership references unknown Raw or shelf" | any invalidMembership memberships]
      , ["duplicate shelf membership" |
          distinctCount membershipPairs /= length membershipPairs]
      , ["observation references unknown origin" | any
          ((`Map.notMember` materialOrigins state) . sourceObservationOrigin)
          observations]
      , ["review disposition references unknown Raw or Brick" |
          any invalidDisposition dispositions]
      ]
    invalidNormalization raw =
      isJust (rawCanonicalEnglish raw) /= isJust (rawNormalizationAuthority raw)
      || maybe False (not . canonicalEnglishText) (rawCanonicalEnglish raw)
    invalidSnapshot snapshot = rawSnapshotSize snapshot < 0
      || Text.null (Text.strip (rawSnapshotContentHash snapshot))
      || Text.null (Text.strip (rawSnapshotMediaType snapshot))
      || ((rawSnapshotAvailability snapshot == SnapshotAvailable)
          /= isJust (rawSnapshotVerifiedAt snapshot))
    invalidOwnerCount link = length (catMaybes
      [() <$ rawLinkOwnerBrick link, () <$ rawLinkOwnerEntry link,
       () <$ rawLinkOwnerRaw link]) /= 1
    invalidDerivedOwner link = rawLinkRole link == DerivedFrom
      && (not (isJust (rawLinkOwnerRaw link))
        || isJust (rawLinkOwnerBrick link) || isJust (rawLinkOwnerEntry link))
    invalidWorkOwner link = rawLinkRole link /= DerivedFrom
      && (isJust (rawLinkOwnerRaw link)
        || not (isJust (rawLinkOwnerBrick link) || isJust (rawLinkOwnerEntry link)))
    invalidLinkReference link =
      Map.notMember (rawLinkRaw link) (materialRaws state)
      || maybe False (`Map.notMember` materialBrickStatuses state)
          (rawLinkOwnerBrick link)
      || maybe False (`Set.notMember` materialListEntries state)
          (rawLinkOwnerEntry link)
      || maybe False (`Map.notMember` materialRaws state) (rawLinkOwnerRaw link)
    invalidBaseline link = case rawLinkReconciledSnapshot link of
      Nothing -> False
      Just identifier -> case Map.lookup identifier (materialSnapshots state) of
        Nothing -> True
        Just snapshot -> rawSnapshotRaw snapshot /= rawLinkRaw link
    invalidMembership membership =
      Map.notMember (rawShelfMembershipRaw membership) (materialRaws state)
      || Map.notMember (rawShelfMembershipShelf membership) (materialShelves state)
    invalidDisposition disposition =
      Map.notMember (rawReviewDispositionRaw disposition) (materialRaws state)
      || maybe False (`Map.notMember` materialBrickStatuses state)
          (rawReviewDispositionBrick disposition)

linkUniquenessKey :: RawLink -> (RawId, RawLinkRole, Maybe BrickId, Maybe ListEntryId, Maybe RawId)
linkUniquenessKey link =
  (rawLinkRaw link, rawLinkRole link, rawLinkOwnerBrick link,
   rawLinkOwnerEntry link, rawLinkOwnerRaw link)

------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------

lookupRaw :: RawId -> MaterialState -> Either MaterialError Raw
lookupRaw identifier state = maybe (Left (UnknownRaw identifier)) Right
  (Map.lookup identifier (materialRaws state))

lookupOrigin :: RawOriginId -> MaterialState -> Either MaterialError RawOrigin
lookupOrigin identifier state = maybe (Left (UnknownRawOrigin identifier)) Right
  (Map.lookup identifier (materialOrigins state))

lookupSnapshot :: RawSnapshotId -> MaterialState -> Either MaterialError RawSnapshot
lookupSnapshot identifier state = maybe (Left (UnknownRawSnapshot identifier)) Right
  (Map.lookup identifier (materialSnapshots state))

lookupLink :: RawLinkId -> MaterialState -> Either MaterialError RawLink
lookupLink identifier state = maybe (Left (UnknownRawLink identifier)) Right
  (Map.lookup identifier (materialLinks state))

lookupShelf :: RawShelfId -> MaterialState -> Either MaterialError RawShelf
lookupShelf identifier state = maybe (Left (UnknownRawShelf identifier)) Right
  (Map.lookup identifier (materialShelves state))

requireBrickOwner :: BrickId -> MaterialState -> Either MaterialError BrickStatus
requireBrickOwner identifier state = maybe (Left (UnknownBrickOwner identifier)) Right
  (Map.lookup identifier (materialBrickStatuses state))

requireSnapshotForRaw ::
  RawId -> MaterialState -> RawSnapshotId -> Either MaterialError RawSnapshot
requireSnapshotForRaw rawIdentifier state identifier = do
  snapshot <- lookupSnapshot identifier state
  unless (rawSnapshotRaw snapshot == rawIdentifier)
    (Left (InvalidRawLinkOwner "snapshot belongs to another Raw"))
  pure snapshot

requireWorkLinkRole :: RawLinkRole -> Either MaterialError ()
requireWorkLinkRole role = unless (role `elem` [Attachment, Source, Evidence])
  (Left (InvalidRawLinkRole role))

sameBrickLink :: RawId -> BrickId -> RawLinkRole -> RawLink -> Bool
sameBrickLink rawIdentifier brick role link = rawLinkRaw link == rawIdentifier
  && rawLinkOwnerBrick link == Just brick && rawLinkRole link == role

sameEntryLink :: RawId -> ListEntryId -> RawLinkRole -> RawLink -> Bool
sameEntryLink rawIdentifier entry role link = rawLinkRaw link == rawIdentifier
  && rawLinkOwnerEntry link == Just entry && rawLinkRole link == role

sameDerivedLink :: RawId -> RawId -> RawLink -> Bool
sameDerivedLink source derived link = rawLinkRaw link == source
  && rawLinkOwnerRaw link == Just derived && rawLinkRole link == DerivedFrom

validateNormalization :: Maybe Text -> Maybe Authority -> Either MaterialError ()
validateNormalization canonical authority = do
  unless (isJust canonical == isJust authority) (Left InvalidNormalizationAttribution)
  mapM_ (\text -> unless (canonicalEnglishText text)
    (Left (InvalidMaterialText text))) canonical

validateNonEmpty :: Text -> Text -> Either MaterialError ()
validateNonEmpty field value = when (Text.null (Text.strip value))
  (Left (InvalidMaterialText field))

validateAndReturn ::
  value -> MaterialState -> Either MaterialError (value, MaterialState)
validateAndReturn value state = do
  validateMaterialState state
  pure (value, state)

allocateRaw :: MaterialState -> (RawId, Integer)
allocateRaw = allocateTyped RawId
allocateRawOrigin :: MaterialState -> (RawOriginId, Integer)
allocateRawOrigin = allocateTyped RawOriginId
allocateRawSnapshot :: MaterialState -> (RawSnapshotId, Integer)
allocateRawSnapshot = allocateTyped RawSnapshotId
allocateRawLink :: MaterialState -> (RawLinkId, Integer)
allocateRawLink = allocateTyped RawLinkId
allocateRawShelf :: MaterialState -> (RawShelfId, Integer)
allocateRawShelf = allocateTyped RawShelfId
allocateShelfMembership :: MaterialState -> (RawShelfMembershipId, Integer)
allocateShelfMembership = allocateTyped RawShelfMembershipId
allocateSourceObservation :: MaterialState -> (SourceObservationId, Integer)
allocateSourceObservation = allocateTyped SourceObservationId
allocateReviewDisposition :: MaterialState -> (RawReviewDispositionId, Integer)
allocateReviewDisposition = allocateTyped RawReviewDispositionId

allocateTyped :: (Text -> identifier) -> MaterialState -> (identifier, Integer)
allocateTyped constructor state =
  (constructor (opaqueMaterialId ordinal), ordinal + 1)
  where ordinal = materialNextIdentityOrdinal state

opaqueMaterialId :: Integer -> Text
opaqueMaterialId ordinal = "mat1_" <> Text.pack (showDigest
  (sha256 (LBS.fromStrict (TextEncoding.encodeUtf8
    ("little-ant-v1:material:" <> Text.pack (show ordinal))))))

findFirst :: (value -> Bool) -> [value] -> Maybe value
findFirst _ [] = Nothing
findFirst predicate (value : rest)
  | predicate value = Just value
  | otherwise = findFirst predicate rest

maximumByMaybe :: (value -> value -> Ordering) -> [value] -> Maybe value
maximumByMaybe _ [] = Nothing
maximumByMaybe comparison values = Just (maximumBy comparison values)

compareSnapshotCreation :: RawSnapshot -> RawSnapshot -> Ordering
compareSnapshotCreation left right = compare
  (rawSnapshotCapturedAt left, rawSnapshotCreationOrdinal left)
  (rawSnapshotCapturedAt right, rawSnapshotCreationOrdinal right)

compareObservationCreation :: SourceObservation -> SourceObservation -> Ordering
compareObservationCreation left right = compare
  (sourceObservationObservedAt left, sourceObservationCreationOrdinal left)
  (sourceObservationObservedAt right, sourceObservationCreationOrdinal right)

listToMaybe :: [value] -> Maybe value
listToMaybe [] = Nothing
listToMaybe (value : _) = Just value

distinctCount :: Ord value => [value] -> Int
distinctCount = Set.size . Set.fromList

infixr 3 <|>
(<|>) :: Maybe value -> Maybe value -> Maybe value
(<|>) (Just value) _ = Just value
(<|>) Nothing other = other

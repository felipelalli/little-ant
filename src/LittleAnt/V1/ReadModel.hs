{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Sparse operational responses, semantic history, and typed text
-- annotations derived from canonical v1 state.
--
-- History pages summarize event batches rather than individual event bodies.
-- Annotation state is canonical data: callers persist it through the kernel's
-- ordinary append path, while these transitions remain pure and replay-safe.
module LittleAnt.V1.ReadModel
  ( AnnotationError (..)
  , AnnotationId (..)
  , AnnotationState (..)
  , AnnotationStatus (..)
  , AnnotationTargetKind (..)
  , HistoryBrief (..)
  , HistoryError (..)
  , HistoryPage (..)
  , HistoryQuery (..)
  , HistoryRelevance (..)
  , SemanticActionMetadata (..)
  , SemanticActionSummary (..)
  , TextAnnotation (..)
  , annotateBrickInBrickText
  , annotatePartyInBrickText
  , commandFailure
  , commandProject
  , emptyAnnotationState
  , historyBrief
  , historyMetadataEvent
  , historyQuery
  , markAnnotationStale
  , runOperationalMutation
  , staleAnnotationsAfterTextEdit
  , validateAnnotationState
  ) where

import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, Result (..), ToJSON (toJSON),
   ToJSONKey, Value (..), defaultOptions, encode, fromJSON, genericParseJSON,
   genericToJSON, object, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy as LBS
import Data.Digest.Pure.SHA (sha256, showDigest)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time (UTCTime (..), fromGregorian)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain
  (Authority, Brick (..), BrickId, DomainState (..), PartyId)
import LittleAnt.V1.Interaction
  (CompactEntityReference, OperationalResponse (..), ProjectionKind (..))
import LittleAnt.V1.Kernel
  (AppendRequest, AppendResult (..), DomainEvent (..), DomainRevision (..),
   EventBatch (..), EventEnvelope (..), KernelError, KernelState, OpaqueId (..),
   ProposedEvent (..), appendSemanticAction, kernelEventBatches,
   kernelRevision, kernelValue)
import Text.Read (readMaybe)

------------------------------------------------------------
-- Sparse command protocol
------------------------------------------------------------

-- | Execute one already-validated canonical mutation.  The semantic action is
-- appended before its response is constructed, so the response always names
-- the one committed domain revision and cannot describe a partial mutation.
runOperationalMutation ::
  AppendRequest -> Text -> Text -> Maybe CompactEntityReference -> [Text] ->
  [Text] -> Maybe Bool -> KernelState ->
  Either KernelError (OperationalResponse, AppendResult)
runOperationalMutation request human resultKind entity changed warnings dryRun state = do
  accepted <- appendSemanticAction request state
  let DomainRevision revision = kernelRevision (appendResultState accepted)
  pure
    ( OperationalResponse
        { operationalResponseOk = True
        , operationalResponseHuman = human
        , operationalResponseResultKind = Just resultKind
        , operationalResponseEntity = entity
        , operationalResponseChanged = changed
        , operationalResponseWarnings = warnings
        , operationalResponseErrorCode = Nothing
        , operationalResponseHint = Nothing
        , operationalResponseDryRun = dryRun
        , operationalResponseDomainRevision = revision
        }
    , accepted
    )

-- | Build a structured failed-command result.  Failure preserves the current
-- domain revision and has no next-state channel through which work can leak.
commandFailure ::
  Text -> Text -> Maybe Text -> [Text] -> KernelState -> OperationalResponse
commandFailure code human hint warnings state = OperationalResponse
  { operationalResponseOk = False
  , operationalResponseHuman = human
  , operationalResponseResultKind = Nothing
  , operationalResponseEntity = Nothing
  , operationalResponseChanged = []
  , operationalResponseWarnings = warnings
  , operationalResponseErrorCode = Just code
  , operationalResponseHint = hint
  , operationalResponseDryRun = Nothing
  , operationalResponseDomainRevision = revision
  }
  where
    DomainRevision revision = kernelRevision state

-- | Purpose-bounded projections over one canonical state.  Ordinary
-- projections never include event bodies; the complete projection is the
-- explicit diagnostic escape hatch.
commandProject ::
  ProjectionKind -> Maybe Text -> KernelState -> Either Text Value
commandProject kind reference state = case (kind, reference) of
  (ProjectionSummary, _) -> Right (object
    ["domain_revision" .= kernelRevision state])
  (ProjectionOperational, Nothing) -> Right (object
    ["domain_revision" .= kernelRevision state, "available" .= True])
  (ProjectionOperational, Just key) -> maybe
    (Left ("unknown projection reference: " <> key))
    (\value -> Right (object
      [ "domain_revision" .= kernelRevision state
      , "reference" .= key
      , "value" .= value
      ]))
    (kernelValue key state)
  (ProjectionRelationships, _) -> Right (object
    [ "domain_revision" .= kernelRevision state
    , "relationships" .= ([] :: [Value])
    ])
  (ProjectionHistory, _) -> either (Left . Text.pack . show) (Right . toJSON)
    (historyQuery defaultHistoryQuery state)
  (ProjectionComplete, _) -> Right (toJSON state)

------------------------------------------------------------
-- Semantic history
------------------------------------------------------------

data HistoryRelevance
  = Routine
  | Relevant
  | Important
  | Critical
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data HistoryQuery = HistoryQuery
  { historyQueryFrom :: Maybe UTCTime
  , historyQueryThrough :: Maybe UTCTime
  , historyQueryBrickIds :: [Text]
  , historyQueryRelatedEntityIds :: [Text]
  , historyQueryScopeIds :: [Text]
  , historyQueryActorIds :: [Text]
  , historyQueryOrigins :: [Text]
  , historyQueryActionFamilies :: [Text]
  , historyQueryMinimumRelevance :: Maybe HistoryRelevance
  , historyQueryCursor :: Maybe Text
  , historyQueryPageSize :: Integer
  }
  deriving stock (Eq, Show, Generic)

data SemanticActionSummary = SemanticActionSummary
  { semanticActionSummaryActionId :: Text
  , semanticActionSummaryDomainRevision :: Integer
  , semanticActionSummaryOccurredAt :: UTCTime
  , semanticActionSummaryActorOrOrigin :: Text
  , semanticActionSummaryFamily :: Text
  , semanticActionSummaryRelevance :: HistoryRelevance
  , semanticActionSummaryOutcome :: Text
  , semanticActionSummarySummary :: Text
  , semanticActionSummaryAffected :: [CompactEntityReference]
  , semanticActionSummaryEventReferences :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data HistoryPage = HistoryPage
  { historyPageSnapshotDomainRevision :: Integer
  , historyPageItems :: [SemanticActionSummary]
  , historyPageNextCursor :: Maybe Text
  , historyPageExactTotal :: Maybe Integer
  }
  deriving stock (Eq, Show, Generic)

data HistoryBrief = HistoryBrief
  { historyBriefSnapshotDomainRevision :: Integer
  , historyBriefFrom :: Maybe UTCTime
  , historyBriefThrough :: Maybe UTCTime
  , historyBriefFacts :: [Text]
  , historyBriefSourceActionIds :: [Text]
  }
  deriving stock (Eq, Show, Generic)

-- | Metadata emitted in the same event batch as a semantic action.  It is
-- canonical but is not copied into ordinary history responses.
data SemanticActionMetadata = SemanticActionMetadata
  { semanticActionMetadataActionId :: Text
  , semanticActionMetadataFamily :: Text
  , semanticActionMetadataRelevance :: HistoryRelevance
  , semanticActionMetadataOutcome :: Text
  , semanticActionMetadataSummary :: Text
  , semanticActionMetadataAffected :: [CompactEntityReference]
  , semanticActionMetadataRelatedEntityIds :: [Text]
  , semanticActionMetadataScopeIds :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data HistoryError
  = InvalidHistoryPageSize Integer
  | InvalidHistoryCursor
  | StaleHistoryCursor Integer Integer
  | HistoryCursorQueryMismatch
  | MalformedHistoryMetadata Text
  deriving stock (Eq, Show)

instance ToJSON HistoryRelevance where toJSON = String . historyRelevanceText
instance FromJSON HistoryRelevance where
  parseJSON = AesonTypes.withText "HistoryRelevance" $ \candidate ->
    maybe (fail "unknown HistoryRelevance") pure
      (lookup candidate historyRelevanceValues)
instance ToJSON HistoryQuery where toJSON = genericToJSON (recordOptions "historyQuery")
instance FromJSON HistoryQuery where
  parseJSON = withObject "HistoryQuery" $ \fields -> HistoryQuery
    <$> fields .:? "from"
    <*> fields .:? "through"
    <*> fields .:? "brick_ids" .!= []
    <*> fields .:? "related_entity_ids" .!= []
    <*> fields .:? "scope_ids" .!= []
    <*> fields .:? "actor_ids" .!= []
    <*> fields .:? "origins" .!= []
    <*> fields .:? "action_families" .!= []
    <*> fields .:? "minimum_relevance"
    <*> fields .:? "cursor"
    <*> fields .: "page_size"
instance ToJSON SemanticActionSummary where
  toJSON = genericToJSON (recordOptions "semanticActionSummary")
instance FromJSON SemanticActionSummary where
  parseJSON = genericParseJSON (recordOptions "semanticActionSummary")
instance ToJSON HistoryPage where toJSON = genericToJSON (recordOptions "historyPage")
instance FromJSON HistoryPage where parseJSON = genericParseJSON (recordOptions "historyPage")
instance ToJSON HistoryBrief where toJSON = genericToJSON (recordOptions "historyBrief")
instance FromJSON HistoryBrief where parseJSON = genericParseJSON (recordOptions "historyBrief")
instance ToJSON SemanticActionMetadata where
  toJSON = genericToJSON (recordOptions "semanticActionMetadata")
instance FromJSON SemanticActionMetadata where
  parseJSON = genericParseJSON (recordOptions "semanticActionMetadata")

historyMetadataEvent :: SemanticActionMetadata -> ProposedEvent
historyMetadataEvent metadata = ProposeValueStored
  (historyMetadataKey (semanticActionMetadataActionId metadata))
  (toJSON metadata)

historyQuery :: HistoryQuery -> KernelState -> Either HistoryError HistoryPage
historyQuery query state = do
  when (historyQueryPageSize query < 1 || historyQueryPageSize query > 100)
    (Left (InvalidHistoryPageSize (historyQueryPageSize query)))
  indexed <- mapM summarizeBatch (kernelBatches state)
  let matching = map indexedSummary (filter (matchesHistoryQuery query) indexed)
      DomainRevision snapshot = kernelRevision state
      fingerprint = historyQueryFingerprint query
  offset <- case historyQueryCursor query of
    Nothing -> Right 0
    Just cursor -> parseCursor snapshot fingerprint cursor
  when (offset > length matching) (Left InvalidHistoryCursor)
  let pageSize = fromIntegral (historyQueryPageSize query)
      items = take pageSize (drop offset matching)
      nextOffset = offset + length items
      nextCursor
        | nextOffset < length matching = Just
            (renderCursor snapshot fingerprint nextOffset)
        | otherwise = Nothing
  pure HistoryPage
    { historyPageSnapshotDomainRevision = snapshot
    , historyPageItems = items
    , historyPageNextCursor = nextCursor
    , historyPageExactTotal = Just (fromIntegral (length matching))
    }

historyBrief :: HistoryQuery -> KernelState -> Either HistoryError HistoryBrief
historyBrief query state = do
  indexed <- mapM summarizeBatch (kernelBatches state)
  let matching = map indexedSummary (filter (matchesHistoryQuery query) indexed)
      DomainRevision snapshot = kernelRevision state
  pure HistoryBrief
    { historyBriefSnapshotDomainRevision = snapshot
    , historyBriefFrom = historyQueryFrom query
    , historyBriefThrough = historyQueryThrough query
    , historyBriefFacts = map semanticActionSummarySummary matching
    , historyBriefSourceActionIds = map semanticActionSummaryActionId matching
    }

-- History is tied directly to canonical event batches and exact envelopes;
-- it is never reconstructed from an operational cache or search projection.
kernelBatches :: KernelState -> [EventBatch]
kernelBatches = kernelEventBatches

data IndexedAction = IndexedAction
  { indexedSummary :: SemanticActionSummary
  , indexedRelatedEntityIds :: [Text]
  , indexedScopeIds :: [Text]
  }

summarizeBatch :: EventBatch -> Either HistoryError IndexedAction
summarizeBatch batch = do
  let events = eventBatchEvents batch
      actionId = eventBatchSemanticActionId batch
      metadataValues =
        [ value
        | envelope <- events
        , ValueStored key value <- [eventBody envelope]
        , key == historyMetadataKey actionId
        ]
  metadata <- case metadataValues of
    [value] -> case fromJSON value of
      Success decoded
        | semanticActionMetadataActionId decoded == actionId -> Right decoded
        | otherwise -> Left (MalformedHistoryMetadata actionId)
      Error _ -> Left (MalformedHistoryMetadata actionId)
    [] -> Right (fallbackMetadata actionId)
    _ -> Left (MalformedHistoryMetadata actionId)
  let firstEnvelope = case events of
        first : _ -> Just first
        [] -> Nothing
      DomainRevision revision = eventBatchDomainRevision batch
      occurredAt = fromMaybe historyEpoch
        (firstEnvelope >>= eventOccurredAt >>= parseTimestamp)
      actor = maybe "unknown" eventActorOrOrigin firstEnvelope
  pure IndexedAction
    { indexedSummary = SemanticActionSummary
        { semanticActionSummaryActionId = actionId
        , semanticActionSummaryDomainRevision = revision
        , semanticActionSummaryOccurredAt = occurredAt
        , semanticActionSummaryActorOrOrigin = actor
        , semanticActionSummaryFamily = semanticActionMetadataFamily metadata
        , semanticActionSummaryRelevance = semanticActionMetadataRelevance metadata
        , semanticActionSummaryOutcome = semanticActionMetadataOutcome metadata
        , semanticActionSummarySummary = semanticActionMetadataSummary metadata
        , semanticActionSummaryAffected = semanticActionMetadataAffected metadata
        , semanticActionSummaryEventReferences =
            [unOpaqueId (eventIdentifier envelope) | envelope <- events]
        }
    , indexedRelatedEntityIds = semanticActionMetadataRelatedEntityIds metadata
    , indexedScopeIds = semanticActionMetadataScopeIds metadata
    }

fallbackMetadata :: Text -> SemanticActionMetadata
fallbackMetadata actionId = SemanticActionMetadata
  { semanticActionMetadataActionId = actionId
  , semanticActionMetadataFamily = "system"
  , semanticActionMetadataRelevance = Routine
  , semanticActionMetadataOutcome = "accepted"
  , semanticActionMetadataSummary = "Accepted " <> actionId
  , semanticActionMetadataAffected = []
  , semanticActionMetadataRelatedEntityIds = []
  , semanticActionMetadataScopeIds = []
  }

matchesHistoryQuery :: HistoryQuery -> IndexedAction -> Bool
matchesHistoryQuery query indexed =
  maybe True (<= semanticActionSummaryOccurredAt summary) (historyQueryFrom query)
  && maybe True (>= semanticActionSummaryOccurredAt summary) (historyQueryThrough query)
  && listFilter (historyQueryBrickIds query) affectedIds
  && listFilter (historyQueryRelatedEntityIds query)
      (indexedRelatedEntityIds indexed)
  && listFilter (historyQueryScopeIds query) (indexedScopeIds indexed)
  && listFilter (historyQueryActorIds query) [actor]
  && listFilter (historyQueryOrigins query) [actor]
  && listFilter (historyQueryActionFamilies query)
      [semanticActionSummaryFamily summary]
  && maybe True (<= semanticActionSummaryRelevance summary)
      (historyQueryMinimumRelevance query)
  where
    summary = indexedSummary indexed
    actor = semanticActionSummaryActorOrOrigin summary
    affectedIds = map compactId (semanticActionSummaryAffected summary)
    compactId reference = case toJSON reference of
      Object fields -> case KeyMap.lookup "id" fields of
        Just (String identifier) -> identifier
        _ -> ""
      _ -> ""

listFilter :: [Text] -> [Text] -> Bool
listFilter requested actual = null requested || any (`elem` actual) requested

historyQueryFingerprint :: HistoryQuery -> Text
historyQueryFingerprint query = digestValue (toJSON query
  {historyQueryCursor = Nothing})

renderCursor :: Integer -> Text -> Int -> Text
renderCursor revision fingerprint offset = Text.intercalate "."
  [Text.pack (show revision), fingerprint, Text.pack (show offset)]

parseCursor :: Integer -> Text -> Text -> Either HistoryError Int
parseCursor current expected cursor = case Text.splitOn "." cursor of
  [revisionText, fingerprint, offsetText] -> case
      (readMaybe (Text.unpack revisionText), readMaybe (Text.unpack offsetText)) of
    (Just revision, Just offset)
      | revision /= current -> Left (StaleHistoryCursor revision current)
      | fingerprint /= expected -> Left HistoryCursorQueryMismatch
      | offset < 0 -> Left InvalidHistoryCursor
      | otherwise -> Right offset
    _ -> Left InvalidHistoryCursor
  _ -> Left InvalidHistoryCursor

historyMetadataKey :: Text -> Text
historyMetadataKey actionId = "v1.history." <> digestText actionId

historyRelevanceText :: HistoryRelevance -> Text
historyRelevanceText relevance = case relevance of
  Routine -> "routine"
  Relevant -> "relevant"
  Important -> "important"
  Critical -> "critical"

historyRelevanceValues :: [(Text, HistoryRelevance)]
historyRelevanceValues =
  [(historyRelevanceText value, value) | value <- [minBound .. maxBound]]

defaultHistoryQuery :: HistoryQuery
defaultHistoryQuery = HistoryQuery Nothing Nothing [] [] [] [] [] [] Nothing Nothing 20

historyEpoch :: UTCTime
historyEpoch = UTCTime (fromGregorian 1970 1 1) 0

parseTimestamp :: Text -> Maybe UTCTime
parseTimestamp value = case fromJSON (String value) of
  Success timestamp -> Just timestamp
  Error _ -> Nothing

------------------------------------------------------------
-- Typed text annotations
------------------------------------------------------------

newtype AnnotationId = AnnotationId {unAnnotationId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

data AnnotationTargetKind = AnnotationParty | AnnotationBrick
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data AnnotationStatus = AnnotationActive | AnnotationStale
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data TextAnnotation = TextAnnotation
  { textAnnotationId :: AnnotationId
  , textAnnotationOwnerBrick :: BrickId
  , textAnnotationField :: Text
  , textAnnotationTextRevision :: Integer
  , textAnnotationStartOffset :: Integer
  , textAnnotationEndOffset :: Integer
  , textAnnotationDisplayedToken :: Text
  , textAnnotationTargetKind :: AnnotationTargetKind
  , textAnnotationTargetParty :: Maybe PartyId
  , textAnnotationTargetBrick :: Maybe BrickId
  , textAnnotationAuthority :: Authority
  , textAnnotationStatus :: AnnotationStatus
  , textAnnotationCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data AnnotationState = AnnotationState
  { annotationStateNextOrdinal :: Integer
  , annotationStateAnnotations :: Map AnnotationId TextAnnotation
  }
  deriving stock (Eq, Show, Generic)

data AnnotationError
  = UnknownAnnotationOwner BrickId
  | UnknownAnnotationParty PartyId
  | UnknownAnnotationBrick BrickId
  | UnsupportedAnnotationField Text
  | AnnotationTextRevisionMismatch Integer Integer
  | InvalidAnnotationStart Integer
  | InvalidAnnotationRange Integer Integer
  | AnnotationSpanOutsideText Integer Integer
  | AnnotationTokenMismatch Text Text
  | UnknownAnnotation AnnotationId
  | AnnotationAlreadyStale AnnotationId
  | AnnotationInvariantViolation Text
  deriving stock (Eq, Show)

instance ToJSON AnnotationTargetKind where
  toJSON kind = String (case kind of AnnotationParty -> "party"; AnnotationBrick -> "brick")
instance FromJSON AnnotationTargetKind where
  parseJSON = AesonTypes.withText "AnnotationTargetKind" $ \case
    "party" -> pure AnnotationParty
    "brick" -> pure AnnotationBrick
    _ -> fail "unknown AnnotationTargetKind"
instance ToJSON AnnotationStatus where
  toJSON status = String (case status of AnnotationActive -> "active"; AnnotationStale -> "stale")
instance FromJSON AnnotationStatus where
  parseJSON = AesonTypes.withText "AnnotationStatus" $ \case
    "active" -> pure AnnotationActive
    "stale" -> pure AnnotationStale
    _ -> fail "unknown AnnotationStatus"
instance ToJSON TextAnnotation where
  toJSON = genericToJSON (recordOptions "textAnnotation")
instance FromJSON TextAnnotation where
  parseJSON = genericParseJSON (recordOptions "textAnnotation")
instance ToJSON AnnotationState where
  toJSON state = object
    [ "next_ordinal" .= annotationStateNextOrdinal state
    , "annotations" .= Map.elems (annotationStateAnnotations state)
    ]
instance FromJSON AnnotationState where
  parseJSON = AesonTypes.withObject "AnnotationState" $ \fields -> do
    ordinal <- fields AesonTypes..: "next_ordinal"
    annotations <- fields AesonTypes..: "annotations"
    pure AnnotationState
      { annotationStateNextOrdinal = ordinal
      , annotationStateAnnotations = Map.fromList
          [(textAnnotationId annotation, annotation) | annotation <- annotations]
      }

emptyAnnotationState :: AnnotationState
emptyAnnotationState = AnnotationState 0 Map.empty

annotatePartyInBrickText ::
  DomainState -> BrickId -> Text -> Integer -> Integer -> Integer -> Text ->
  PartyId -> Authority -> UTCTime -> AnnotationState ->
  Either AnnotationError (TextAnnotation, AnnotationState)
annotatePartyInBrickText domain owner field textRevision start end token target
    authority now state = do
  _ <- maybe (Left (UnknownAnnotationParty target)) Right
    (Map.lookup target (domainParties domain))
  createAnnotation domain owner field textRevision start end token
    AnnotationParty (Just target) Nothing authority now state

annotateBrickInBrickText ::
  DomainState -> BrickId -> Text -> Integer -> Integer -> Integer -> Text ->
  BrickId -> Authority -> UTCTime -> AnnotationState ->
  Either AnnotationError (TextAnnotation, AnnotationState)
annotateBrickInBrickText domain owner field textRevision start end token target
    authority now state = do
  _ <- maybe (Left (UnknownAnnotationBrick target)) Right
    (Map.lookup target (domainBricks domain))
  createAnnotation domain owner field textRevision start end token
    AnnotationBrick Nothing (Just target) authority now state

createAnnotation ::
  DomainState -> BrickId -> Text -> Integer -> Integer -> Integer -> Text ->
  AnnotationTargetKind -> Maybe PartyId -> Maybe BrickId -> Authority -> UTCTime ->
  AnnotationState -> Either AnnotationError (TextAnnotation, AnnotationState)
createAnnotation domain ownerId field textRevision start end token kind party brick
    authority now state = do
  owner <- maybe (Left (UnknownAnnotationOwner ownerId)) Right
    (Map.lookup ownerId (domainBricks domain))
  unless (field == "description") (Left (UnsupportedAnnotationField field))
  let currentRevision = brickDescriptionRevision owner
  unless (textRevision == currentRevision)
    (Left (AnnotationTextRevisionMismatch textRevision currentRevision))
  when (start < 0) (Left (InvalidAnnotationStart start))
  unless (start < end) (Left (InvalidAnnotationRange start end))
  text <- maybe (Left (UnsupportedAnnotationField field)) Right
    (brickDescription owner)
  when (end > fromIntegral (Text.length text))
    (Left (AnnotationSpanOutsideText start end))
  let selected = Text.take (fromIntegral (end - start))
        (Text.drop (fromIntegral start) text)
  unless (selected == token) (Left (AnnotationTokenMismatch token selected))
  let ordinal = annotationStateNextOrdinal state
      identifier = AnnotationId ("annotation-" <> Text.pack (show ordinal))
      annotation = TextAnnotation identifier ownerId field textRevision start end
        token kind party brick authority AnnotationActive now
      next = state
        { annotationStateNextOrdinal = ordinal + 1
        , annotationStateAnnotations = Map.insert identifier annotation
            (annotationStateAnnotations state)
        }
  validateAnnotationState next
  pure (annotation, next)

markAnnotationStale ::
  AnnotationId -> AnnotationState ->
  Either AnnotationError (TextAnnotation, AnnotationState)
markAnnotationStale identifier state = do
  annotation <- maybe (Left (UnknownAnnotation identifier)) Right
    (Map.lookup identifier (annotationStateAnnotations state))
  when (textAnnotationStatus annotation /= AnnotationActive)
    (Left (AnnotationAlreadyStale identifier))
  let stale = annotation {textAnnotationStatus = AnnotationStale}
      next = state {annotationStateAnnotations = Map.insert identifier stale
        (annotationStateAnnotations state)}
  validateAnnotationState next
  pure (stale, next)

-- | Editing annotation-capable text never guesses a moved span.  Every active
-- annotation anchored to the prior revision is retained and explicitly stale.
staleAnnotationsAfterTextEdit ::
  BrickId -> Text -> Integer -> AnnotationState -> AnnotationState
staleAnnotationsAfterTextEdit owner field newRevision state = state
  {annotationStateAnnotations = Map.map staleOld
      (annotationStateAnnotations state)}
  where
    staleOld annotation
      | textAnnotationOwnerBrick annotation == owner
      , textAnnotationField annotation == field
      , textAnnotationTextRevision annotation /= newRevision
      , textAnnotationStatus annotation == AnnotationActive =
          annotation {textAnnotationStatus = AnnotationStale}
      | otherwise = annotation

validateAnnotationState :: AnnotationState -> Either AnnotationError ()
validateAnnotationState state = do
  when (annotationStateNextOrdinal state < 0)
    (Left (AnnotationInvariantViolation "negative annotation allocator"))
  mapM_ validateOne (Map.toList (annotationStateAnnotations state))
  where
    validateOne (identifier, annotation) = do
      unless (identifier == textAnnotationId annotation)
        (Left (AnnotationInvariantViolation "annotation map key differs from ID"))
      let partyPresent = maybe False (const True)
            (textAnnotationTargetParty annotation)
          brickPresent = maybe False (const True)
            (textAnnotationTargetBrick annotation)
      unless (partyPresent /= brickPresent)
        (Left (AnnotationInvariantViolation
          "annotation does not have exactly one target"))
      unless (case textAnnotationTargetKind annotation of
          AnnotationParty -> partyPresent && not brickPresent
          AnnotationBrick -> brickPresent && not partyPresent)
        (Left (AnnotationInvariantViolation
          "annotation kind does not match target"))

------------------------------------------------------------
-- Shared encoding helpers
------------------------------------------------------------

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLowerAscii first : rest)
    toLowerAscii character
      | character >= 'A' && character <= 'Z' =
          toEnum (fromEnum character + fromEnum 'a' - fromEnum 'A')
      | otherwise = character

digestValue :: Value -> Text
digestValue = Text.pack . showDigest . sha256 . encode

digestText :: Text -> Text
digestText = Text.pack . showDigest . sha256 . LBS.fromStrict
  . TextEncoding.encodeUtf8

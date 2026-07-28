{-# LANGUAGE DerivingStrategies #-}

-- | Deterministic, event-sourced authority for Little Ant 1.0 state.
--
-- Semantic actions are compiled to one immutable event batch and applied only
-- after every proposed event has validated.  Replay consumes those batches
-- directly; there is deliberately no callback through which an adapter could
-- run while canonical state is being rebuilt.
module LittleAnt.V1.Kernel
  ( AppendRequest (..)
  , AppendResult (..)
  , DomainEvent (..)
  , DomainRevision (..)
  , EventBatch (..)
  , EventEnvelope (..)
  , KernelError (..)
  , KernelState
  , OpaqueId (..)
  , ProposedEvent (..)
  , ReplayResult (..)
  , appendSemanticAction
  , canonicalStateHash
  , emptyKernelState
  , kernelArtifact
  , kernelEntity
  , kernelEventBatches
  , kernelNextIdentityOrdinal
  , kernelRevision
  , kernelValue
  , putKernelArtifact
  , replayAll
  , replayThrough
  ) where

import Control.Monad (foldM, unless, when)
import Data.Aeson (Object, ToJSON (toJSON), Value (..), encode, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as LBS
import Data.Digest.Pure.SHA (sha256, showDigest)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding

-- | The one optimistic concurrency token shared by all domain mutations.
newtype DomainRevision = DomainRevision { unDomainRevision :: Integer }
  deriving stock (Eq, Ord, Show)

instance ToJSON DomainRevision where
  toJSON = toJSON . unDomainRevision

-- | An identity whose representation is creation-derived, never title-derived.
newtype OpaqueId = OpaqueId { unOpaqueId :: Text }
  deriving stock (Eq, Ord, Show)

instance ToJSON OpaqueId where
  toJSON = toJSON . unOpaqueId

-- | Inputs accepted by the generic kernel.  Domain modules translate their
-- typed operations into these bounded canonical changes.
data ProposedEvent
  = ProposeValueStored Text Value
  | ProposeValueRemoved Text
  | ProposeEntityCreated Text Object
  deriving stock (Eq, Show)

-- | Canonical event bodies.  Allocation ordinals are retained so replay can
-- verify identity generation and reconstruct the next allocator position.
data DomainEvent
  = ValueStored Text Value
  | ValueRemoved Text
  | EntityCreated Integer OpaqueId Text Object
  deriving stock (Eq, Show)

instance ToJSON DomainEvent where
  toJSON event = case event of
    ValueStored key value -> object
      [ "type" .= ("value_stored" :: Text)
      , "key" .= key
      , "value" .= value
      ]
    ValueRemoved key -> object
      [ "type" .= ("value_removed" :: Text)
      , "key" .= key
      ]
    EntityCreated ordinal identifier kind fields -> object
      [ "type" .= ("entity_created" :: Text)
      , "identity_ordinal" .= ordinal
      , "id" .= identifier
      , "kind" .= kind
      , "fields" .= Object fields
      ]

-- | Versioned envelope around one canonical event.
data EventEnvelope = EventEnvelope
  { eventSchemaVersion :: Int
  , eventIdentifier :: OpaqueId
  , eventSemanticActionId :: Text
  , eventDomainRevision :: DomainRevision
  , eventIndexInAction :: Int
  , eventActorOrOrigin :: Text
  , eventOccurredAt :: Maybe Text
  , eventBody :: DomainEvent
  }
  deriving stock (Eq, Show)

instance ToJSON EventEnvelope where
  toJSON event = object
    [ "schema_version" .= eventSchemaVersion event
    , "event_id" .= eventIdentifier event
    , "semantic_action_id" .= eventSemanticActionId event
    , "domain_revision" .= eventDomainRevision event
    , "event_index" .= eventIndexInAction event
    , "actor_or_origin" .= eventActorOrOrigin event
    , "occurred_at" .= eventOccurredAt event
    , "body" .= eventBody event
    ]

-- | Every accepted semantic action contributes exactly one batch.
data EventBatch = EventBatch
  { eventBatchSemanticActionId :: Text
  , eventBatchDomainRevision :: DomainRevision
  , eventBatchEvents :: [EventEnvelope]
  }
  deriving stock (Eq, Show)

instance ToJSON EventBatch where
  toJSON batch = object
    [ "semantic_action_id" .= eventBatchSemanticActionId batch
    , "domain_revision" .= eventBatchDomainRevision batch
    , "events" .= eventBatchEvents batch
    ]

-- | One optimistic semantic append request.  Time and origin are explicit
-- inputs, so the kernel never consults an ambient clock or process identity.
data AppendRequest = AppendRequest
  { appendExpectedRevision :: DomainRevision
  , appendSemanticActionId :: Text
  , appendActorOrOrigin :: Text
  , appendOccurredAt :: Maybe Text
  , appendProposedEvents :: [ProposedEvent]
  }
  deriving stock (Eq, Show)

-- | Result of an accepted action.  Allocated IDs are returned in proposal
-- order so a typed domain operation can build its compact postcondition.
data AppendResult = AppendResult
  { appendResultState :: KernelState
  , appendResultBatch :: EventBatch
  , appendResultAllocatedIds :: [OpaqueId]
  }
  deriving stock (Eq, Show)

-- | Failures are values.  Since 'appendSemanticAction' is pure and returns no
-- next state on failure, callers cannot accidentally commit a partial action.
data KernelError
  = RevisionConflict DomainRevision DomainRevision
  | EmptySemanticAction
  | EmptySemanticActionId
  | EmptyActorOrOrigin
  | EmptyValueKey
  | EmptyArtifactKey
  | ValueDoesNotExist Text
  | EmptyEntityKind
  | ReservedEntityField Text
  | DuplicateSemanticAction Text
  | CorruptEventLog Text
  deriving stock (Eq, Show)

-- | Authoritative replayed state plus the immutable batches that produced it.
data KernelState = KernelState
  { stateDomainRevision :: DomainRevision
  , stateNextIdentityOrdinal :: Integer
  , stateValues :: Map Text Value
  , stateArtifacts :: Map Text Value
  , stateEntities :: Map OpaqueId Value
  , stateBatches :: [EventBatch]
  , stateSemanticActionIds :: Set Text
  }
  deriving stock (Eq, Show)

instance ToJSON KernelState where
  toJSON state = object
    [ "domain_revision" .= stateDomainRevision state
    , "next_identity_ordinal" .= stateNextIdentityOrdinal state
    , "values" .= stateValues state
    , "entities" .= Map.fromList
        [ (unOpaqueId identifier, value)
        | (identifier, value) <- Map.toAscList (stateEntities state)
        ]
    , "event_batches" .= stateBatches state
    ]

-- | Replay reports its external trace explicitly.  Its only possible value is
-- empty because replay has no adapter argument and performs no IO.
data ReplayResult = ReplayResult
  { replayResultState :: KernelState
  , replayResultExternalTrace :: [Text]
  }
  deriving stock (Eq, Show)

emptyKernelState :: KernelState
emptyKernelState = KernelState
  { stateDomainRevision = DomainRevision 0
  , stateNextIdentityOrdinal = 0
  , stateValues = Map.empty
  , stateArtifacts = Map.empty
  , stateEntities = Map.empty
  , stateBatches = []
  , stateSemanticActionIds = Set.empty
  }

kernelRevision :: KernelState -> DomainRevision
kernelRevision = stateDomainRevision

kernelNextIdentityOrdinal :: KernelState -> Integer
kernelNextIdentityOrdinal = stateNextIdentityOrdinal

kernelValue :: Text -> KernelState -> Maybe Value
kernelValue key = Map.lookup key . stateValues

-- | Read a bounded non-domain artifact such as a presentation checkpoint.
-- Artifacts are deliberately excluded from canonical JSON, hashes, and event
-- replay, but immutable 'KernelState' snapshots still retain them.
kernelArtifact :: Text -> KernelState -> Maybe Value
kernelArtifact key = Map.lookup key . stateArtifacts

-- | Update presentation or harness state without advancing the authoritative
-- domain clock.  Callers must never use this path for canonical domain data.
putKernelArtifact ::
  Text -> Value -> KernelState -> Either KernelError KernelState
putKernelArtifact key value state
  | Text.null (Text.strip key) = Left EmptyArtifactKey
  | otherwise = Right state
      {stateArtifacts = Map.insert key value (stateArtifacts state)}

kernelEntity :: OpaqueId -> KernelState -> Maybe Value
kernelEntity identifier = Map.lookup identifier . stateEntities

kernelEventBatches :: KernelState -> [EventBatch]
kernelEventBatches = stateBatches

-- | Validate and append one complete semantic action.
appendSemanticAction ::
  AppendRequest -> KernelState -> Either KernelError AppendResult
appendSemanticAction request state = do
  validateAppendRequest request state
  (compiledReversed, allocatedReversed, projected) <- foldM compileOne
    ([], [], state)
    (appendProposedEvents request)
  let revision = successor (stateDomainRevision state)
      bodies = reverse compiledReversed
      envelopes = zipWith (envelopeFor request revision) [0 ..] bodies
      batch = EventBatch
        { eventBatchSemanticActionId = appendSemanticActionId request
        , eventBatchDomainRevision = revision
        , eventBatchEvents = envelopes
        }
      committed = projected
        { stateDomainRevision = revision
        , stateBatches = stateBatches state <> [batch]
        , stateSemanticActionIds = Set.insert
            (appendSemanticActionId request)
            (stateSemanticActionIds state)
        }
  pure AppendResult
    { appendResultState = committed
    , appendResultBatch = batch
    , appendResultAllocatedIds = reverse allocatedReversed
    }
  where
    compileOne (events, allocated, projected) proposal = do
      body <- compileProposedEvent proposal projected
      next <- applyDomainEvent body projected
      let newlyAllocated = case body of
            EntityCreated _ identifier _ _ -> identifier : allocated
            _ -> allocated
      pure (body : events, newlyAllocated, next)

validateAppendRequest :: AppendRequest -> KernelState -> Either KernelError ()
validateAppendRequest request state = do
  unless (appendExpectedRevision request == stateDomainRevision state)
    (Left (RevisionConflict
      (appendExpectedRevision request)
      (stateDomainRevision state)))
  when (Text.null (Text.strip (appendSemanticActionId request)))
    (Left EmptySemanticActionId)
  when (Text.null (Text.strip (appendActorOrOrigin request)))
    (Left EmptyActorOrOrigin)
  when (null (appendProposedEvents request)) (Left EmptySemanticAction)
  when (Set.member (appendSemanticActionId request) (stateSemanticActionIds state))
    (Left (DuplicateSemanticAction (appendSemanticActionId request)))

compileProposedEvent :: ProposedEvent -> KernelState -> Either KernelError DomainEvent
compileProposedEvent proposal state = case proposal of
  ProposeValueStored key value
    | Text.null (Text.strip key) -> Left EmptyValueKey
    | otherwise -> Right (ValueStored key value)
  ProposeValueRemoved key
    | Text.null (Text.strip key) -> Left EmptyValueKey
    | Map.notMember key (stateValues state) -> Left (ValueDoesNotExist key)
    | otherwise -> Right (ValueRemoved key)
  ProposeEntityCreated kind fields -> do
    when (Text.null (Text.strip kind)) (Left EmptyEntityKind)
    mapM_ rejectReservedField ["id", "kind"]
    let ordinal = stateNextIdentityOrdinal state
        identifier = opaqueIdentity "entity" ordinal
    pure (EntityCreated ordinal identifier kind fields)
    where
      rejectReservedField field = when
        (KeyMap.member (Key.fromText field) fields)
        (Left (ReservedEntityField field))

envelopeFor ::
  AppendRequest -> DomainRevision -> Int -> DomainEvent -> EventEnvelope
envelopeFor request revision index body = EventEnvelope
  { eventSchemaVersion = 1
  , eventIdentifier = opaqueEventIdentity
      (appendSemanticActionId request) revision index
  , eventSemanticActionId = appendSemanticActionId request
  , eventDomainRevision = revision
  , eventIndexInAction = index
  , eventActorOrOrigin = appendActorOrOrigin request
  , eventOccurredAt = appendOccurredAt request
  , eventBody = body
  }

applyDomainEvent :: DomainEvent -> KernelState -> Either KernelError KernelState
applyDomainEvent event state = case event of
  ValueStored key value
    | Text.null (Text.strip key) -> Left (CorruptEventLog "empty value key")
    | otherwise -> Right state
        { stateValues = Map.insert key value (stateValues state) }
  ValueRemoved key
    | Map.member key (stateValues state) -> Right state
        { stateValues = Map.delete key (stateValues state) }
    | otherwise -> Left (CorruptEventLog
        ("removed value does not exist: " <> key))
  EntityCreated ordinal identifier kind fields -> do
    when (ordinal /= stateNextIdentityOrdinal state)
      (Left (CorruptEventLog "non-contiguous identity allocation"))
    when (identifier /= opaqueIdentity "entity" ordinal)
      (Left (CorruptEventLog "entity identity does not match allocation"))
    when (Text.null (Text.strip kind))
      (Left (CorruptEventLog "empty entity kind"))
    when (Map.member identifier (stateEntities state))
      (Left (CorruptEventLog "duplicate opaque entity identity"))
    let entity = Object
          (KeyMap.insert "kind" (String kind)
            (KeyMap.insert "id" (String (unOpaqueId identifier)) fields))
    pure state
      { stateNextIdentityOrdinal = ordinal + 1
      , stateEntities = Map.insert identifier entity (stateEntities state)
      }

-- | Replay all batches.  No adapter, clock, random generator, vault, or Pack
-- runner can be supplied to this function.
replayAll :: [EventBatch] -> Either KernelError ReplayResult
replayAll batches = replayThrough target batches
  where
    target = case reverse batches of
      [] -> DomainRevision 0
      batch : _ -> eventBatchDomainRevision batch

-- | Replay the exact prefix ending at the requested revision.
replayThrough ::
  DomainRevision -> [EventBatch] -> Either KernelError ReplayResult
replayThrough target batches = do
  when (target < DomainRevision 0)
    (Left (CorruptEventLog "negative replay revision"))
  state <- foldM applyBatch emptyKernelState
    (takeWhile ((<= target) . eventBatchDomainRevision) batches)
  unless (stateDomainRevision state == target)
    (Left (CorruptEventLog "requested replay revision is unavailable"))
  pure ReplayResult
    { replayResultState = state
    , replayResultExternalTrace = []
    }

applyBatch :: KernelState -> EventBatch -> Either KernelError KernelState
applyBatch state batch = do
  let expectedRevision = successor (stateDomainRevision state)
      actionId = eventBatchSemanticActionId batch
      events = eventBatchEvents batch
  unless (eventBatchDomainRevision batch == expectedRevision)
    (Left (CorruptEventLog "non-contiguous event batch revision"))
  when (Text.null (Text.strip actionId))
    (Left (CorruptEventLog "empty semantic action ID"))
  when (Set.member actionId (stateSemanticActionIds state))
    (Left (CorruptEventLog "duplicate semantic action ID"))
  when (null events) (Left (CorruptEventLog "empty event batch"))
  mapM_ (validateEnvelope batch) (zip [0 ..] events)
  projected <- foldM
    (\current envelope -> applyDomainEvent (eventBody envelope) current)
    state
    events
  pure projected
    { stateDomainRevision = eventBatchDomainRevision batch
    , stateBatches = stateBatches state <> [batch]
    , stateSemanticActionIds = Set.insert actionId
        (stateSemanticActionIds state)
    }

validateEnvelope :: EventBatch -> (Int, EventEnvelope) -> Either KernelError ()
validateEnvelope batch (index, envelope) = do
  unless (eventSchemaVersion envelope == 1)
    (Left (CorruptEventLog "unsupported event schema version"))
  unless (eventSemanticActionId envelope == eventBatchSemanticActionId batch)
    (Left (CorruptEventLog "event action ID differs from its batch"))
  unless (eventDomainRevision envelope == eventBatchDomainRevision batch)
    (Left (CorruptEventLog "event revision differs from its batch"))
  unless (eventIndexInAction envelope == index)
    (Left (CorruptEventLog "non-contiguous event index"))
  unless (eventIdentifier envelope == opaqueEventIdentity
      (eventSemanticActionId envelope)
      (eventDomainRevision envelope)
      index)
    (Left (CorruptEventLog "event identity does not match its envelope"))

successor :: DomainRevision -> DomainRevision
successor (DomainRevision revision) = DomainRevision (revision + 1)

opaqueIdentity :: Text -> Integer -> OpaqueId
opaqueIdentity namespace ordinal = OpaqueId
  ("la1_" <> digestText (namespace <> ":" <> Text.pack (show ordinal)))

opaqueEventIdentity :: Text -> DomainRevision -> Int -> OpaqueId
opaqueEventIdentity actionId (DomainRevision revision) index = OpaqueId
  ("evt1_" <> digestText (Text.intercalate ":"
    [actionId, Text.pack (show revision), Text.pack (show index)]))

digestText :: Text -> Text
digestText = Text.pack . showDigest . sha256 . LBS.fromStrict
  . TextEncoding.encodeUtf8

-- | Stable hash of the complete replayed state and canonical event history.
canonicalStateHash :: KernelState -> Text
canonicalStateHash = Text.pack . showDigest . sha256 . encode

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

-- | Canonical v1 command and terminal-adapter boundary.
--
-- Both executable names use this module.  Domain writes are appended as
-- 'EventBatch'es, interaction/checkpoint state is stored separately, and all
-- renderers consume the same typed responses used by noninteractive clients.
module LittleAnt.V1.CLI
  ( CanonicalActor (..)
  , CanonicalInteractionSurface (..)
  , CliState (..)
  , SurfaceAccessError (..)
  , abandonCliInteraction
  , captureBrick
  , checkpointInteraction
  , completeBrick
  , completeCliInteraction
  , currentCliInteraction
  , emptyCliState
  , historyBriefFor
  , historyPageFor
  , interactionSurface
  , loadCliState
  , openCliInteraction
  , powerUpCli
  , projectCliState
  , rebaseCliInteraction
  , requestCliInteractionHelp
  , resumeCliInteraction
  , saveCliState
  , statusFor
  , submitCliInteraction
  , useDumbCli
  ) where

import Control.Exception (IOException, try)
import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON, Result (..), ToJSON (toJSON), Value (..), eitherDecodeStrict',
   encode, fromJSON, object, (.=))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain (PartyType (..))
import LittleAnt.V1.Interaction
  (CompactEntityReference (..), HarnessMode (..), InteractionAction (..),
   InteractionEnvelope (..), InteractionError (..), InteractionId (..),
   InteractionSession (..),
   InteractionState (..), InteractionStatus (..), OperationalResponse (..),
   PoweredUpError (..), ProjectionKind, ReplRuntime (..), StatusSummary,
   SubmissionDecision (..), SurfaceCheckpoint (..), SurfaceCheckpointDraft (..),
   abandonInteraction, acceptCurrentInteractionAction,
   classifyInteractionSubmission, completeInteraction, currentInteraction,
   emptyInteractionState, openInteraction, requestInteractionHelp,
   requestPoweredUpModelViaStdin, rebaseInteraction, saveExistingSurfaceCheckpoint,
   saveFirstSurfaceCheckpoint, statusSummary, useDumbMode,
   validateInteractionState, validatePoweredUpAdapter)
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..), EventBatch,
   KernelState, OpaqueId (..), ProposedEvent (..), appendSemanticAction,
   emptyKernelState, kernelEntity, kernelEventBatches, kernelRevision,
   kernelValue, replayAll, replayResultState)
import LittleAnt.V1.ReadModel
  (HistoryBrief, HistoryError, HistoryPage, HistoryQuery,
   SemanticActionMetadata (..), HistoryRelevance (..), commandFailure,
   commandProject, historyBrief, historyMetadataEvent, historyQuery)
import System.Directory
  (createDirectoryIfMissing, doesFileExist, renameFile, removeFile)
import System.FilePath ((</>))

-- | The only actor accepted by the canonical surface is a person.  Other
-- Party variants remain valid domain entities but cannot acquire human action
-- authority merely by reaching an adapter.
data CanonicalActor = CanonicalActor
  { canonicalActorId :: Text
  , canonicalActorPartyType :: PartyType
  }
  deriving stock (Eq, Show, Generic)

data SurfaceAccessError
  = EmptyCanonicalActor
  | ActorIsNotUser PartyType
  deriving stock (Eq, Show)

-- | Adapter-facing projection of the surface declaration.  The declared
-- operation set is stable; @available_operations@ is the context-valid
-- command palette for a particular interaction/runtime state.
data CanonicalInteractionSurface = CanonicalInteractionSurface
  { canonicalSurfaceUserId :: Text
  , canonicalSurfaceDomainRevision :: Integer
  , canonicalSurfaceMode :: HarnessMode
  , canonicalSurfacePoweredBy :: Maybe Text
  , canonicalSurfaceProvidedOperations :: [Text]
  , canonicalSurfaceAvailableOperations :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON CanonicalInteractionSurface where
  toJSON surface = object
    [ "user" .= object ["id" .= canonicalSurfaceUserId surface]
    , "clock" .= object
        ["revision" .= canonicalSurfaceDomainRevision surface]
    , "repl" .= object
        [ "mode" .= modeText (canonicalSurfaceMode surface)
        , "powered_by" .= canonicalSurfacePoweredBy surface
        ]
    , "provides" .= canonicalSurfaceProvidedOperations surface
    , "available_operations" .= canonicalSurfaceAvailableOperations surface
    ]

-- | Runtime state shared by dumb/powered REPLs and direct CLI commands.
data CliState = CliState
  { cliKernelState :: KernelState
  , cliInteractionState :: InteractionState
  }
  deriving stock (Eq, Show)

emptyCliState :: CliState
emptyCliState = CliState emptyKernelState emptyInteractionState

-- | Build the exact actor/exposure/provides view consumed by all adapters.
interactionSurface ::
  CanonicalActor -> Maybe InteractionId -> CliState ->
  Either SurfaceAccessError CanonicalInteractionSurface
interactionSurface actor selected state = do
  when (Text.null (Text.strip (canonicalActorId actor)))
    (Left EmptyCanonicalActor)
  unless (canonicalActorPartyType actor == Person)
    (Left (ActorIsNotUser (canonicalActorPartyType actor)))
  let runtime = interactionStateReplRuntime (cliInteractionState state)
      session = selected >>= (\identifier -> Map.lookup identifier
        (interactionStateSessions (cliInteractionState state)))
  pure CanonicalInteractionSurface
    { canonicalSurfaceUserId = canonicalActorId actor
    , canonicalSurfaceDomainRevision = currentRevision state
    , canonicalSurfaceMode = replRuntimeMode runtime
    , canonicalSurfacePoweredBy = replRuntimePoweredBy runtime
    , canonicalSurfaceProvidedOperations = providedOperations
    , canonicalSurfaceAvailableOperations = availableOperations runtime session
    }

providedOperations :: [Text]
providedOperations =
  [ "OpenInteraction"
  , "SubmitInteractionAction"
  , "RebaseInteraction"
  , "RequestInteractionHelp"
  , "CompleteInteraction"
  , "AbandonInteraction"
  , "SaveSurfaceCheckpoint"
  , "ValidatePoweredUpAdapter"
  , "UseDumbMode"
  , "AnnotatePartyInBrickText"
  , "AnnotateBrickInBrickText"
  , "MarkAnnotationStale"
  ]

availableOperations :: ReplRuntime -> Maybe InteractionSession -> [Text]
availableOperations runtime session =
  [ "OpenInteraction"
  , "SaveSurfaceCheckpoint"
  , "ValidatePoweredUpAdapter"
  , "AnnotatePartyInBrickText"
  , "AnnotateBrickInBrickText"
  , "MarkAnnotationStale"
  ]
  <> case replRuntimeMode runtime of
      Dumb -> []
      PoweredUp -> ["UseDumbMode"]
  <> case interactionSessionStatus <$> session of
      Just InteractionOpen ->
        [ "SubmitInteractionAction"
        , "RequestInteractionHelp"
        , "CompleteInteraction"
        , "AbandonInteraction"
        ]
      Just InteractionStale -> ["RebaseInteraction", "AbandonInteraction"]
      _ -> []

------------------------------------------------------------
-- Event-sourced persistence
------------------------------------------------------------

v1EventsPath :: FilePath -> FilePath
v1EventsPath directory = directory </> "events-v1.jsonl"

v1InteractionPath :: FilePath -> FilePath
v1InteractionPath directory = directory </> "interaction-v1.json"

loadCliState :: FilePath -> IO (Either Text CliState)
loadCliState directory = do
  eventsResult <- loadEventBatches (v1EventsPath directory)
  interactionResult <- loadJsonOr
    (v1InteractionPath directory) emptyInteractionState
  pure $ do
    batches <- eventsResult
    replayed <- firstShow "event replay failed" (replayAll batches)
    interaction <- interactionResult
    firstShow "interaction state is invalid"
      (validateInteractionState interaction)
    pure CliState
      { cliKernelState = replayResultState replayed
      , cliInteractionState = interaction
      }

loadEventBatches :: FilePath -> IO (Either Text [EventBatch])
loadEventBatches path = do
  exists <- doesFileExist path
  if not exists
    then pure (Right [])
    else do
      outcome <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
      pure $ case outcome of
        Left problem -> Left ("cannot read " <> Text.pack path <> ": "
          <> Text.pack (show problem))
        Right bytes -> traverse decodeLine
          (zip [1 :: Int ..] (filter (not . BS.null) (BS8.lines bytes)))
  where
    decodeLine (lineNumber, bytes) = case eitherDecodeStrict' bytes of
      Left problem -> Left (Text.pack path <> " line "
        <> Text.pack (show lineNumber) <> ": " <> Text.pack problem)
      Right batch -> Right batch

loadJsonOr :: FromJSON value => FilePath -> value -> IO (Either Text value)
loadJsonOr path fallback = do
  exists <- doesFileExist path
  if not exists
    then pure (Right fallback)
    else do
      outcome <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
      pure $ case outcome of
        Left problem -> Left ("cannot read " <> Text.pack path <> ": "
          <> Text.pack (show problem))
        Right bytes -> case eitherDecodeStrict' bytes of
          Left problem -> Left (Text.pack path <> ": " <> Text.pack problem)
          Right value -> Right value

-- | Persist only the newly accepted append-only batches, then atomically
-- replace the bounded non-domain interaction/checkpoint file.
saveCliState :: FilePath -> CliState -> CliState -> IO (Either Text ())
saveCliState directory before after = do
  createDirectoryIfMissing True directory
  let previous = kernelEventBatches (cliKernelState before)
      current = kernelEventBatches (cliKernelState after)
  if previous /= take (length previous) current
    then pure (Left "refusing to rewrite or fork the canonical event log")
    else do
      appendResult <- appendBatches (v1EventsPath directory)
        (drop (length previous) current)
      case appendResult of
        Left problem -> pure (Left problem)
        Right () -> atomicWriteJson (v1InteractionPath directory)
          (cliInteractionState after)

appendBatches :: FilePath -> [EventBatch] -> IO (Either Text ())
appendBatches _ [] = pure (Right ())
appendBatches path batches = do
  let payload = LBS.concat [encode batch <> "\n" | batch <- batches]
  result <- try (LBS.appendFile path payload) :: IO (Either IOException ())
  pure (either (Left . storageFailure path) Right result)

atomicWriteJson :: ToJSON value => FilePath -> value -> IO (Either Text ())
atomicWriteJson path value = do
  let temporary = path <> ".tmp"
  written <- try (LBS.writeFile temporary (encode value)) ::
    IO (Either IOException ())
  case written of
    Left problem -> pure (Left (storageFailure temporary problem))
    Right () -> do
      renamed <- try (renameFile temporary path) :: IO (Either IOException ())
      case renamed of
        Right () -> pure (Right ())
        Left problem -> do
          _ <- try (removeFile temporary) :: IO (Either IOException ())
          pure (Left (storageFailure path problem))

storageFailure :: FilePath -> IOException -> Text
storageFailure path problem = "cannot persist " <> Text.pack path <> ": "
  <> Text.pack (show problem)

------------------------------------------------------------
-- CommandProtocol and StatusProvider
------------------------------------------------------------

captureBrick ::
  Text -> UTCTime -> CliState -> (OperationalResponse, CliState)
captureBrick rawTitle now state
  | Text.null title =
      (commandFailure "invalid_argument" "A canonical title is required."
        (Just "Pass a non-empty English title.") [] (cliKernelState state), state)
  | otherwise = case appendSemanticAction request (cliKernelState state) of
      Left problem ->
        (kernelFailure problem state, state)
      Right accepted -> case appendResultAllocatedIds accepted of
        [identifier] ->
          let revision = revisionOf (appendResultState accepted)
              reference = CompactEntityReference
                (unOpaqueId identifier) (Just title) revision (Just "active")
              response = OperationalResponse
                { operationalResponseOk = True
                , operationalResponseHuman = "Captured " <> title <> "."
                , operationalResponseResultKind = Just "brick_created"
                , operationalResponseEntity = Just reference
                , operationalResponseChanged = ["brick"]
                , operationalResponseWarnings = []
                , operationalResponseErrorCode = Nothing
                , operationalResponseHint = Nothing
                , operationalResponseDryRun = Nothing
                , operationalResponseDomainRevision = revision
                }
          in (response, state {cliKernelState = appendResultState accepted})
        _ -> (commandFailure "internal_error"
              "The canonical create action returned no identity." Nothing []
              (cliKernelState state), state)
  where
    title = Text.strip rawTitle
    nextRevision = currentRevision state + 1
    actionId = "cli:capture:" <> Text.pack (show nextRevision)
    request = AppendRequest
      { appendExpectedRevision = kernelRevision (cliKernelState state)
      , appendSemanticActionId = actionId
      , appendActorOrOrigin = "human:local-user"
      , appendOccurredAt = Just (timestampText now)
      , appendProposedEvents =
          [ ProposeEntityCreated "brick" (case object
              [ "title" .= title
              , "status" .= ("active" :: Text)
              , "revision" .= nextRevision
              ] of Object fields -> fields; _ -> mempty)
          , historyMetadataEvent SemanticActionMetadata
              { semanticActionMetadataActionId = actionId
              , semanticActionMetadataFamily = "capture"
              , semanticActionMetadataRelevance = Relevant
              , semanticActionMetadataOutcome = "accepted"
              , semanticActionMetadataSummary = "Captured " <> title <> "."
              , semanticActionMetadataAffected = []
              , semanticActionMetadataRelatedEntityIds = []
              , semanticActionMetadataScopeIds = []
              }
          ]
      }

completeBrick ::
  Text -> Integer -> UTCTime -> CliState -> (OperationalResponse, CliState)
completeBrick identifier expectedRevision now state
  | expectedRevision /= currentRevision state =
      (commandFailure "revision_conflict"
        "The command precondition is stale."
        (Just "Reload the entity and retry with the current domain revision.") []
        (cliKernelState state), state)
  | kernelEntity opaque (cliKernelState state) == Nothing =
      (commandFailure "unknown_entity" "No Brick has that opaque ID."
        Nothing [] (cliKernelState state), state)
  | currentStatus == Just (String "done") =
      (commandFailure "failed_precondition" "The Brick is already done."
        Nothing [] (cliKernelState state), state)
  | otherwise = case appendSemanticAction request (cliKernelState state) of
      Left problem -> (kernelFailure problem state, state)
      Right accepted ->
        let revision = revisionOf (appendResultState accepted)
            reference = CompactEntityReference identifier title revision
              (Just "done")
            response = OperationalResponse
              { operationalResponseOk = True
              , operationalResponseHuman = "Completed " <> displayTitle <> "."
              , operationalResponseResultKind = Just "brick_changed"
              , operationalResponseEntity = Just reference
              , operationalResponseChanged = ["status"]
              , operationalResponseWarnings = []
              , operationalResponseErrorCode = Nothing
              , operationalResponseHint = Nothing
              , operationalResponseDryRun = Nothing
              , operationalResponseDomainRevision = revision
              }
        in (response, state {cliKernelState = appendResultState accepted})
  where
    opaque = OpaqueId identifier
    statusKey = "v1.brick-status." <> identifier
    currentStatus = kernelValue statusKey (cliKernelState state)
    title = entityTitle =<< kernelEntity opaque (cliKernelState state)
    displayTitle = maybe identifier id title
    nextRevision = currentRevision state + 1
    actionId = "cli:complete:" <> Text.pack (show nextRevision)
    request = AppendRequest
      { appendExpectedRevision = DomainRevision expectedRevision
      , appendSemanticActionId = actionId
      , appendActorOrOrigin = "human:local-user"
      , appendOccurredAt = Just (timestampText now)
      , appendProposedEvents =
          [ ProposeValueStored statusKey (String "done")
          , historyMetadataEvent SemanticActionMetadata
              { semanticActionMetadataActionId = actionId
              , semanticActionMetadataFamily = "lifecycle"
              , semanticActionMetadataRelevance = Relevant
              , semanticActionMetadataOutcome = "accepted"
              , semanticActionMetadataSummary = "Completed " <> displayTitle <> "."
              , semanticActionMetadataAffected =
                  [CompactEntityReference identifier title nextRevision (Just "done")]
              , semanticActionMetadataRelatedEntityIds = []
              , semanticActionMetadataScopeIds = []
              }
          ]
      }

projectCliState :: ProjectionKind -> Maybe Text -> CliState -> Either Text Value
projectCliState kind reference = commandProject kind reference . cliKernelState

statusFor :: CliState -> StatusSummary
statusFor state = statusSummary Nothing 0 0 0 (cliInteractionState state)

historyPageFor :: HistoryQuery -> CliState -> Either HistoryError HistoryPage
historyPageFor query = historyQuery query . cliKernelState

historyBriefFor :: HistoryQuery -> CliState -> Either HistoryError HistoryBrief
historyBriefFor query = historyBrief query . cliKernelState

------------------------------------------------------------
-- InteractionProtocol
------------------------------------------------------------

openCliInteraction ::
  Text -> UTCTime -> CliState ->
  Either InteractionError (InteractionEnvelope, CliState)
openCliInteraction kind now state = do
  (session, interaction) <- openInteraction kind Nothing Nothing Nothing now
    (currentRevision state) (cliInteractionState state)
  envelope <- currentInteraction (interactionSessionId session) interaction
  pure (envelope, state {cliInteractionState = interaction})

currentCliInteraction ::
  InteractionId -> CliState -> Either InteractionError InteractionEnvelope
currentCliInteraction identifier = currentInteraction identifier . cliInteractionState

requestCliInteractionHelp ::
  InteractionId -> CliState -> Either InteractionError InteractionEnvelope
requestCliInteractionHelp identifier =
  requestInteractionHelp identifier . cliInteractionState

submitCliInteraction ::
  InteractionId -> Integer -> Integer -> Text -> UTCTime -> CliState ->
  Either InteractionError (OperationalResponse, CliState)
submitCliInteraction identifier displayedDomain displayedInteraction actionId now
    state = do
  decision <- classifyInteractionSubmission identifier displayedDomain
    displayedInteraction (currentRevision state) actionId now
    (cliInteractionState state)
  case decision of
    StaleSubmission response interaction -> pure
      (response, state {cliInteractionState = interaction})
    CurrentSubmission action -> do
      let semanticId = "cli:interaction:"
            <> interactionIdText identifier <> ":"
            <> Text.pack (show displayedInteraction)
          request = AppendRequest
            { appendExpectedRevision = kernelRevision (cliKernelState state)
            , appendSemanticActionId = semanticId
            , appendActorOrOrigin = "human:local-user"
            , appendOccurredAt = Just (timestampText now)
            , appendProposedEvents =
                [ ProposeValueStored
                    ("v1.interaction.answer." <> interactionIdText identifier
                      <> "." <> Text.pack (show displayedInteraction))
                    (object ["action_id" .= actionId])
                , historyMetadataEvent SemanticActionMetadata
                    { semanticActionMetadataActionId = semanticId
                    , semanticActionMetadataFamily = "interaction"
                    , semanticActionMetadataRelevance = Relevant
                    , semanticActionMetadataOutcome = "accepted"
                    , semanticActionMetadataSummary =
                        "Accepted " <> interactionActionLabel action <> "."
                    , semanticActionMetadataAffected = []
                    , semanticActionMetadataRelatedEntityIds = []
                    , semanticActionMetadataScopeIds = []
                    }
                ]
            }
      case appendSemanticAction request (cliKernelState state) of
        Left _ -> pure
          (commandFailure "append_failed" "The interaction action was not committed."
            (Just "Reload the interaction and try again.") []
            (cliKernelState state), state)
        Right accepted -> do
          (_, response, interaction) <- acceptCurrentInteractionAction identifier
            displayedDomain displayedInteraction (currentRevision state)
            actionId now (cliInteractionState state)
          pure (response, CliState (appendResultState accepted) interaction)

rebaseCliInteraction ::
  InteractionId -> UTCTime -> CliState ->
  Either InteractionError (InteractionEnvelope, CliState)
rebaseCliInteraction identifier now state = do
  (_, interaction) <- rebaseInteraction identifier (currentRevision state) now
    (cliInteractionState state)
  envelope <- currentInteraction identifier interaction
  pure (envelope, state {cliInteractionState = interaction})

completeCliInteraction ::
  InteractionId -> UTCTime -> CliState ->
  Either InteractionError (InteractionSession, CliState)
completeCliInteraction identifier now state = do
  (session, interaction) <- completeInteraction identifier now
    (cliInteractionState state)
  pure (session, state {cliInteractionState = interaction})

abandonCliInteraction ::
  InteractionId -> UTCTime -> CliState ->
  Either InteractionError (InteractionSession, CliState)
abandonCliInteraction identifier now state = do
  (session, interaction) <- abandonInteraction identifier now
    (cliInteractionState state)
  pure (session, state {cliInteractionState = interaction})

checkpointInteraction ::
  Text -> Text -> [Text] -> InteractionEnvelope -> UTCTime -> CliState ->
  Either InteractionError CliState
checkpointInteraction surface screen transcript envelope now state = do
  let draft = SurfaceCheckpointDraft
        { checkpointDraftSurfaceId = surface
        , checkpointDraftInteractionId = Just
            (interactionEnvelopeInteractionId envelope)
        , checkpointDraftDisplayedDomainRevision =
            interactionEnvelopeDomainRevision envelope
        , checkpointDraftDisplayedInteractionRevision = Just
            (interactionEnvelopeInteractionRevision envelope)
        , checkpointDraftScreen = screen
        , checkpointDraftSelectedItem = Nothing
        , checkpointDraftTextBuffer = Nothing
        , checkpointDraftCursorOffset = Nothing
        , checkpointDraftTranscript = transcript
        , checkpointDraftLastResponse = interactionStateLatestResponse
            (cliInteractionState state)
        , checkpointDraftLastStatus = Just (statusFor state)
        , checkpointDraftLastProjection = Nothing
        , checkpointDraftHistoryQuery = Nothing
        , checkpointDraftLastHistoryPage = Nothing
        , checkpointDraftLastHistoryBrief = Nothing
        }
      interaction = cliInteractionState state
  (_, next) <- if Map.member surface (interactionStateCheckpoints interaction)
    then saveExistingSurfaceCheckpoint draft now interaction
    else saveFirstSurfaceCheckpoint draft now interaction
  pure state {cliInteractionState = next}

resumeCliInteraction ::
  Text -> CliState -> Either InteractionError InteractionEnvelope
resumeCliInteraction surface state = do
  checkpoint <- maybe
    (Left (CheckpointDoesNotExist surface)) Right
    (Map.lookup surface
      (interactionStateCheckpoints (cliInteractionState state)))
  identifier <- maybe
    (Left (CheckpointDoesNotExist surface)) Right
    (surfaceCheckpointInteractionId checkpoint)
  currentInteraction identifier (cliInteractionState state)

powerUpCli ::
  FilePath -> CliState -> IO (Either PoweredUpError (OperationalResponse, CliState))
powerUpCli executable state = do
  response <- requestPoweredUpModelViaStdin executable
    "{\"protocol_version\":1,\"kind\":\"probe\"}"
  pure $ do
    (output, _) <- response
    let (_, operational, interaction) = validatePoweredUpAdapter
          (Text.pack executable) "stdin" output (cliInteractionState state)
        adjusted = operational
          {operationalResponseDomainRevision = currentRevision state}
        nextInteraction = interaction
          {interactionStateLatestResponse = Just adjusted}
    if operationalResponseOk adjusted
      then Right (adjusted, state {cliInteractionState = nextInteraction})
      else Left PoweredUpOutputUnsupported

useDumbCli :: CliState -> Either InteractionError CliState
useDumbCli state = do
  interaction <- useDumbMode (cliInteractionState state)
  pure state {cliInteractionState = interaction}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

currentRevision :: CliState -> Integer
currentRevision = revisionOf . cliKernelState

revisionOf :: KernelState -> Integer
revisionOf state = case kernelRevision state of DomainRevision revision -> revision

kernelFailure :: Show error => error -> CliState -> OperationalResponse
kernelFailure problem state = commandFailure "append_failed"
  "The canonical event append failed."
  (Just (Text.pack (show problem))) [] (cliKernelState state)

entityTitle :: Value -> Maybe Text
entityTitle value = case fromJSON value :: Result (Map.Map Text Value) of
  Success fields -> case Map.lookup "title" fields of
    Just (String title) -> Just title
    _ -> Nothing
  Error _ -> Nothing

interactionIdText :: InteractionId -> Text
interactionIdText = unInteractionId

timestampText :: UTCTime -> Text
timestampText timestamp = case toJSON timestamp of
  String encoded -> encoded
  _ -> Text.pack (show timestamp)

modeText :: HarnessMode -> Text
modeText mode = case mode of Dumb -> "dumb"; PoweredUp -> "powered_up"

firstShow :: Show error => Text -> Either error value -> Either Text value
firstShow prefix = either
  (Left . ((prefix <> ": ") <>) . Text.pack . show) Right

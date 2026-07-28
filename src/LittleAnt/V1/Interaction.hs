{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Revision-scoped guided interactions and bounded powered-up harness state.
--
-- Confirmed answers are committed by the caller through the canonical event
-- store.  Sessions, surface checkpoints, and process traces are non-domain
-- artifacts: changing them never advances the domain clock and they cannot be
-- replayed as canonical state.
module LittleAnt.V1.Interaction
  ( CompactEntityReference (..)
  , HarnessMode (..)
  , InteractionAction (..)
  , InteractionError (..)
  , InteractionEnvelope (..)
  , InteractionId (..)
  , InteractionProgress (..)
  , InteractionSession (..)
  , InteractionState (..)
  , InteractionStatus (..)
  , OperationalResponse (..)
  , PoweredUpError (..)
  , PoweredUpInvocation (..)
  , PoweredUpValidation (..)
  , ProcessInvocationTrace (..)
  , ProjectionKind (..)
  , ReplRuntime (..)
  , StatusSummary (..)
  , SubmissionDecision (..)
  , SurfaceCheckpoint (..)
  , SurfaceCheckpointDraft (..)
  , abandonInteraction
  , acceptCurrentInteractionAction
  , classifyInteractionSubmission
  , completeInteraction
  , currentInteraction
  , emptyInteractionState
  , honestInteractionProgress
  , openInteraction
  , operationalResponseMatchesProjection
  , operationalResponseProjection
  , parsePoweredUpProbe
  , poweredUpInvocation
  , probePoweredUpAdapter
  , rebaseInteraction
  , requestInteractionHelp
  , requestPoweredUpModelViaStdin
  , saveExistingSurfaceCheckpoint
  , saveFirstSurfaceCheckpoint
  , statusSummary
  , useDumbMode
  , validateInteractionState
  , validatePoweredUpAdapter
  ) where

import Control.Exception (SomeException, try)
import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, Result (..), ToJSON (toJSON),
   ToJSONKey, Value (..), camelTo2, defaultOptions, eitherDecode,
   genericParseJSON, genericToJSON)
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Char as Char
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (isJust)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import System.Exit (ExitCode (..))
import System.Process (proc, readCreateProcessWithExitCode)
import System.Timeout (timeout)

------------------------------------------------------------
-- Protocol vocabulary
------------------------------------------------------------

newtype InteractionId = InteractionId {unInteractionId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

data InteractionStatus
  = InteractionOpen
  | InteractionStale
  | InteractionCompleted
  | InteractionAbandoned
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ProjectionKind
  = ProjectionSummary
  | ProjectionOperational
  | ProjectionRelationships
  | ProjectionHistory
  | ProjectionComplete
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data HarnessMode = Dumb | PoweredUp
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON InteractionStatus where
  toJSON = String . interactionStatusText
instance FromJSON InteractionStatus where
  parseJSON = parseTextEnum "InteractionStatus" interactionStatusText
instance ToJSON ProjectionKind where
  toJSON = String . projectionKindText
instance FromJSON ProjectionKind where
  parseJSON = parseTextEnum "ProjectionKind" projectionKindText
instance ToJSON HarnessMode where
  toJSON = String . harnessModeText
instance FromJSON HarnessMode where
  parseJSON = parseTextEnum "HarnessMode" harnessModeText

interactionStatusText :: InteractionStatus -> Text
interactionStatusText status = case status of
  InteractionOpen -> "open"
  InteractionStale -> "stale"
  InteractionCompleted -> "completed"
  InteractionAbandoned -> "abandoned"

projectionKindText :: ProjectionKind -> Text
projectionKindText kind = case kind of
  ProjectionSummary -> "summary"
  ProjectionOperational -> "operational"
  ProjectionRelationships -> "relationships"
  ProjectionHistory -> "history"
  ProjectionComplete -> "complete"

harnessModeText :: HarnessMode -> Text
harnessModeText mode = case mode of
  Dumb -> "dumb"
  PoweredUp -> "powered_up"

parseTextEnum :: (Bounded value, Enum value) =>
  String -> (value -> Text) -> Value -> AesonTypes.Parser value
parseTextEnum name render = Aeson.withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate [(render value, value) | value <- [minBound .. maxBound]])

data CompactEntityReference = CompactEntityReference
  { compactEntityReferenceId :: Text
  , compactEntityReferenceTitle :: Maybe Text
  , compactEntityReferenceRevision :: Integer
  , compactEntityReferenceState :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data InteractionAction = InteractionAction
  { interactionActionId :: Text
  , interactionActionLabel :: Text
  , interactionActionShortcut :: Text
  , interactionActionCanonicalCommand :: Text
  , interactionActionDestructive :: Bool
  , interactionActionConfirmationRequired :: Bool
  }
  deriving stock (Eq, Show, Generic)

data InteractionProgress = InteractionProgress
  { interactionProgressFacts :: [Text]
  , interactionProgressEstimatedRemainingMin :: Maybe Integer
  , interactionProgressEstimatedRemainingMax :: Maybe Integer
  }
  deriving stock (Eq, Show, Generic)

data InteractionEnvelope = InteractionEnvelope
  { interactionEnvelopeProtocolVersion :: Integer
  , interactionEnvelopeInteractionId :: InteractionId
  , interactionEnvelopeDomainRevision :: Integer
  , interactionEnvelopeInteractionRevision :: Integer
  , interactionEnvelopeKind :: Text
  , interactionEnvelopePrompt :: Text
  , interactionEnvelopeSubject :: Maybe CompactEntityReference
  , interactionEnvelopeActions :: [InteractionAction]
  , interactionEnvelopeHelp :: Maybe Text
  , interactionEnvelopeProgress :: Maybe InteractionProgress
  }
  deriving stock (Eq, Show, Generic)

data OperationalResponse = OperationalResponse
  { operationalResponseOk :: Bool
  , operationalResponseHuman :: Text
  , operationalResponseResultKind :: Maybe Text
  , operationalResponseEntity :: Maybe CompactEntityReference
  , operationalResponseChanged :: [Text]
  , operationalResponseWarnings :: [Text]
  , operationalResponseErrorCode :: Maybe Text
  , operationalResponseHint :: Maybe Text
  , operationalResponseDryRun :: Maybe Bool
  , operationalResponseDomainRevision :: Integer
  }
  deriving stock (Eq, Show, Generic)

data StatusSummary = StatusSummary
  { statusSummaryHuman :: Text
  , statusSummaryMode :: Text
  , statusSummaryPoweredBy :: Maybe Text
  , statusSummaryCurrentFocus :: Maybe CompactEntityReference
  , statusSummaryHumanWipCount :: Integer
  , statusSummaryOpenProposalCount :: Integer
  , statusSummaryPendingNoticeCount :: Integer
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON CompactEntityReference where
  toJSON = genericToJSON (recordOptions "compactEntityReference")
instance FromJSON CompactEntityReference where
  parseJSON = genericParseJSON (recordOptions "compactEntityReference")
instance ToJSON InteractionAction where
  toJSON = genericToJSON (recordOptions "interactionAction")
instance FromJSON InteractionAction where
  parseJSON = genericParseJSON (recordOptions "interactionAction")
instance ToJSON InteractionProgress where
  toJSON = genericToJSON (recordOptions "interactionProgress")
instance FromJSON InteractionProgress where
  parseJSON = genericParseJSON (recordOptions "interactionProgress")
instance ToJSON InteractionEnvelope where
  toJSON = genericToJSON (recordOptions "interactionEnvelope")
instance FromJSON InteractionEnvelope where
  parseJSON = genericParseJSON (recordOptions "interactionEnvelope")
instance ToJSON OperationalResponse where
  toJSON = genericToJSON (recordOptions "operationalResponse")
instance FromJSON OperationalResponse where
  parseJSON = genericParseJSON (recordOptions "operationalResponse")
instance ToJSON StatusSummary where
  toJSON = genericToJSON (recordOptions "statusSummary")
instance FromJSON StatusSummary where
  parseJSON = genericParseJSON (recordOptions "statusSummary")

-- | Serialize the sparse operational projection declared by the command
-- schema. Required false, zero, and empty values remain present; only absent
-- optional fields are omitted.
operationalResponseProjection :: OperationalResponse -> Value
operationalResponseProjection response = Object (KeyMap.fromList
  ( [ ("ok", toJSON (operationalResponseOk response))
    , ("human", toJSON (operationalResponseHuman response))
    , ("changed", toJSON (operationalResponseChanged response))
    , ("warnings", toJSON (operationalResponseWarnings response))
    , ("domain_revision", toJSON (operationalResponseDomainRevision response))
    ]
  <> optional "result_kind" toJSON (operationalResponseResultKind response)
  <> optional "entity" compactProjection (operationalResponseEntity response)
  <> optional "error_code" toJSON (operationalResponseErrorCode response)
  <> optional "hint" toJSON (operationalResponseHint response)
  <> optional "dry_run" toJSON (operationalResponseDryRun response)
  ))
  where
    optional _ _ Nothing = []
    optional field encodeValue (Just value) = [(field, encodeValue value)]
    compactProjection entity = Object (KeyMap.fromList
      ( [ ("id", toJSON (compactEntityReferenceId entity))
        , ("revision", toJSON (compactEntityReferenceRevision entity))
        ]
      <> optional "title" toJSON (compactEntityReferenceTitle entity)
      <> optional "state" toJSON (compactEntityReferenceState entity)
      ))

-- | Validate the exact sparse schema used by 'operationalResponseProjection'.
-- Success must identify its typed result and cannot carry an error code;
-- failure must carry an error code. Unknown, null, missing, and mistyped fields
-- fail validation instead of being silently interpreted as omission defaults.
operationalResponseMatchesProjection :: Value -> Bool
operationalResponseMatchesProjection = \case
  Object response ->
    Set.fromList (KeyMap.keys response) `Set.isSubsetOf` allowedFields
      && requiredField "ok" isBoolean response
      && requiredField "human" isText response
      && requiredField "changed" isTextArray response
      && requiredField "warnings" isTextArray response
      && requiredField "domain_revision" isNonnegativeInteger response
      && optionalField "result_kind" isText response
      && optionalField "entity" compactMatches response
      && optionalField "error_code" isText response
      && optionalField "hint" isText response
      && optionalField "dry_run" isBoolean response
      && outcomeFieldsMatch response
  _ -> False
  where
    allowedFields = Set.fromList
      [ "ok", "human", "result_kind", "entity", "changed", "warnings"
      , "error_code", "hint", "dry_run", "domain_revision"
      ]
    outcomeFieldsMatch response = case KeyMap.lookup "ok" response of
      Just (Bool True) -> KeyMap.member "result_kind" response
        && not (KeyMap.member "error_code" response)
      Just (Bool False) -> KeyMap.member "error_code" response
      _ -> False
    compactMatches = \case
      Object entity ->
        Set.fromList (KeyMap.keys entity) `Set.isSubsetOf` compactFields
          && requiredField "id" isText entity
          && requiredField "revision" isNonnegativeInteger entity
          && optionalField "title" isText entity
          && optionalField "state" isText entity
      _ -> False
    compactFields = Set.fromList ["id", "title", "revision", "state"]
    requiredField field predicate fields =
      maybe False predicate (KeyMap.lookup field fields)
    optionalField field predicate fields =
      maybe True predicate (KeyMap.lookup field fields)
    isBoolean (Bool _) = True
    isBoolean _ = False
    isText (String _) = True
    isText _ = False
    isTextArray value = case Aeson.fromJSON value :: Result [Text] of
      Success _ -> True
      Error _ -> False
    isNonnegativeInteger value = case Aeson.fromJSON value :: Result Integer of
      Success number -> number >= 0
      Error _ -> False

------------------------------------------------------------
-- Interaction and checkpoint state
------------------------------------------------------------

data InteractionSession = InteractionSession
  { interactionSessionId :: InteractionId
  , interactionSessionKind :: Text
  , interactionSessionSubjectBrick :: Maybe Text
  , interactionSessionSubjectRaw :: Maybe Text
  , interactionSessionStatus :: InteractionStatus
  , interactionSessionDomainRevision :: Integer
  , interactionSessionInteractionRevision :: Integer
  , interactionSessionPromptKey :: Text
  , interactionSessionRandomEvidence :: Maybe Text
  , interactionSessionConfirmedActions :: Integer
  , interactionSessionOpenedAt :: UTCTime
  , interactionSessionUpdatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data SurfaceCheckpoint = SurfaceCheckpoint
  { surfaceCheckpointId :: Text
  , surfaceCheckpointSurfaceId :: Text
  , surfaceCheckpointInteractionId :: Maybe InteractionId
  , surfaceCheckpointDisplayedDomainRevision :: Integer
  , surfaceCheckpointDisplayedInteractionRevision :: Maybe Integer
  , surfaceCheckpointScreen :: Text
  , surfaceCheckpointSelectedItem :: Maybe Text
  , surfaceCheckpointTextBuffer :: Maybe Text
  , surfaceCheckpointCursorOffset :: Maybe Integer
  , surfaceCheckpointTranscript :: [Text]
  , surfaceCheckpointLastResponse :: Maybe OperationalResponse
  , surfaceCheckpointLastStatus :: Maybe StatusSummary
  , surfaceCheckpointLastProjection :: Maybe ProjectionKind
  , surfaceCheckpointHistoryQuery :: Maybe Value
  , surfaceCheckpointLastHistoryPage :: Maybe Value
  , surfaceCheckpointLastHistoryBrief :: Maybe Value
  , surfaceCheckpointUpdatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data SurfaceCheckpointDraft = SurfaceCheckpointDraft
  { checkpointDraftSurfaceId :: Text
  , checkpointDraftInteractionId :: Maybe InteractionId
  , checkpointDraftDisplayedDomainRevision :: Integer
  , checkpointDraftDisplayedInteractionRevision :: Maybe Integer
  , checkpointDraftScreen :: Text
  , checkpointDraftSelectedItem :: Maybe Text
  , checkpointDraftTextBuffer :: Maybe Text
  , checkpointDraftCursorOffset :: Maybe Integer
  , checkpointDraftTranscript :: [Text]
  , checkpointDraftLastResponse :: Maybe OperationalResponse
  , checkpointDraftLastStatus :: Maybe StatusSummary
  , checkpointDraftLastProjection :: Maybe ProjectionKind
  , checkpointDraftHistoryQuery :: Maybe Value
  , checkpointDraftLastHistoryPage :: Maybe Value
  , checkpointDraftLastHistoryBrief :: Maybe Value
  }
  deriving stock (Eq, Show, Generic)

data ReplRuntime = ReplRuntime
  { replRuntimeMode :: HarnessMode
  , replRuntimePoweredBy :: Maybe Text
  , replRuntimeAdapterProtocol :: Maybe Integer
  }
  deriving stock (Eq, Show, Generic)

data ProcessInvocationTrace = ProcessInvocationTrace
  { processInvocationTraceExecutable :: Text
  , processInvocationTraceArgumentCount :: Integer
  , processInvocationTraceArgumentsContainPrompt :: Bool
  , processInvocationTraceStdinContainsProbe :: Bool
  , processInvocationTraceSecretValuesRecorded :: Bool
  }
  deriving stock (Eq, Show, Generic)

data InteractionState = InteractionState
  { interactionStateNextOrdinal :: Integer
  , interactionStateSessions :: Map InteractionId InteractionSession
  , interactionStateCheckpoints :: Map Text SurfaceCheckpoint
  , interactionStateReplRuntime :: ReplRuntime
  , interactionStateProcessTraces :: Map Text ProcessInvocationTrace
  , interactionStateLatestResponse :: Maybe OperationalResponse
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON InteractionSession where
  toJSON = genericToJSON (recordOptions "interactionSession")
instance FromJSON InteractionSession where
  parseJSON = genericParseJSON (recordOptions "interactionSession")
instance ToJSON SurfaceCheckpoint where
  toJSON = genericToJSON (recordOptions "surfaceCheckpoint")
instance FromJSON SurfaceCheckpoint where
  parseJSON = genericParseJSON (recordOptions "surfaceCheckpoint")
instance ToJSON ReplRuntime where
  toJSON = genericToJSON (recordOptions "replRuntime")
instance FromJSON ReplRuntime where
  parseJSON = genericParseJSON (recordOptions "replRuntime")
instance ToJSON ProcessInvocationTrace where
  toJSON = genericToJSON (recordOptions "processInvocationTrace")
instance FromJSON ProcessInvocationTrace where
  parseJSON = genericParseJSON (recordOptions "processInvocationTrace")
instance ToJSON InteractionState where
  toJSON = genericToJSON (recordOptions "interactionState")
instance FromJSON InteractionState where
  parseJSON = genericParseJSON (recordOptions "interactionState")

emptyInteractionState :: InteractionState
emptyInteractionState = InteractionState
  { interactionStateNextOrdinal = 0
  , interactionStateSessions = Map.empty
  , interactionStateCheckpoints = Map.empty
  , interactionStateReplRuntime = ReplRuntime Dumb Nothing Nothing
  , interactionStateProcessTraces = Map.empty
  , interactionStateLatestResponse = Nothing
  }

data InteractionError
  = UnknownInteraction InteractionId
  | InteractionIsNotOpen InteractionId InteractionStatus
  | InteractionIsNotStale InteractionId InteractionStatus
  | InteractionIsTerminal InteractionId
  | InvalidDomainRevision Integer Integer
  | InvalidInteractionTransition InteractionStatus InteractionStatus
  | EmptyInteractionKind
  | EmptySurfaceId
  | CheckpointAlreadyExists Text
  | CheckpointDoesNotExist Text
  | InvalidCheckpointCursor Integer
  | InvalidInteractionState Text
  | PoweredUpModeIsNotEnabled
  deriving stock (Eq, Show)

data SubmissionDecision
  = CurrentSubmission InteractionAction
  | StaleSubmission OperationalResponse InteractionState
  deriving stock (Eq, Show)

openInteraction ::
  Text -> Maybe Text -> Maybe Text -> Maybe Text -> UTCTime -> Integer ->
  InteractionState -> Either InteractionError (InteractionSession, InteractionState)
openInteraction kind subjectBrick subjectRaw randomEvidence now domainRevision state = do
  when (Text.null (Text.strip kind)) (Left EmptyInteractionKind)
  let ordinal = interactionStateNextOrdinal state
      identifier = InteractionId ("interaction-" <> Text.pack (show ordinal))
      session = InteractionSession
        { interactionSessionId = identifier
        , interactionSessionKind = kind
        , interactionSessionSubjectBrick = subjectBrick
        , interactionSessionSubjectRaw = subjectRaw
        , interactionSessionStatus = InteractionOpen
        , interactionSessionDomainRevision = domainRevision
        , interactionSessionInteractionRevision = 1
        , interactionSessionPromptKey = promptKey kind subjectBrick subjectRaw
            domainRevision 1
        , interactionSessionRandomEvidence = randomEvidence
        , interactionSessionConfirmedActions = 0
        , interactionSessionOpenedAt = now
        , interactionSessionUpdatedAt = now
        }
      next = state
        { interactionStateNextOrdinal = ordinal + 1
        , interactionStateSessions = Map.insert identifier session
            (interactionStateSessions state)
        }
  validateInteractionState next
  pure (session, next)

currentInteraction ::
  InteractionId -> InteractionState -> Either InteractionError InteractionEnvelope
currentInteraction identifier state = do
  session <- lookupSession identifier state
  when (interactionSessionStatus session /= InteractionOpen)
    (Left (InteractionIsNotOpen identifier (interactionSessionStatus session)))
  pure (envelopeFor session)

requestInteractionHelp ::
  InteractionId -> InteractionState -> Either InteractionError InteractionEnvelope
requestInteractionHelp = currentInteraction

-- | Classify a submitted canonical action ID.  Kept separate from acceptance
-- so callers can append its ordinary domain event before advancing the session.
classifyInteractionSubmission ::
  InteractionId -> Integer -> Integer -> Integer -> Text -> UTCTime ->
  InteractionState -> Either InteractionError SubmissionDecision
classifyInteractionSubmission identifier displayedDomain displayedInteraction
    currentDomain actionId now state = do
  session <- lookupSession identifier state
  when (interactionSessionStatus session /= InteractionOpen)
    (Left (InteractionIsNotOpen identifier (interactionSessionStatus session)))
  let action = Map.lookup actionId (Map.fromList
        [(interactionActionId item, item) | item <- actionsFor session])
      current = displayedDomain == currentDomain
        && displayedDomain == interactionSessionDomainRevision session
        && displayedInteraction == interactionSessionInteractionRevision session
  case action of
    Just selected | current -> Right (CurrentSubmission selected)
    _ -> do
      let stale = session
            { interactionSessionStatus = InteractionStale
            , interactionSessionUpdatedAt = now
            }
          response = staleResponse currentDomain
          next = state
            { interactionStateSessions = Map.insert identifier stale
                (interactionStateSessions state)
            , interactionStateLatestResponse = Just response
            }
      validateInteractionState next
      pure (StaleSubmission response next)

acceptCurrentInteractionAction ::
  InteractionId -> Integer -> Integer -> Integer -> Text -> UTCTime ->
  InteractionState ->
  Either InteractionError (InteractionAction, OperationalResponse, InteractionState)
acceptCurrentInteractionAction identifier displayedDomain displayedInteraction
    currentDomain actionId now state = do
  decision <- classifyInteractionSubmission identifier displayedDomain
    displayedInteraction currentDomain actionId now state
  action <- case decision of
    CurrentSubmission selected -> Right selected
    StaleSubmission _ _ -> Left
      (InvalidDomainRevision displayedDomain currentDomain)
  let nextDomain = currentDomain + 1
  session <- lookupSession identifier state
  let nextRevision = interactionSessionInteractionRevision session + 1
      accepted = session
        { interactionSessionDomainRevision = nextDomain
        , interactionSessionInteractionRevision = nextRevision
        , interactionSessionPromptKey = promptKey
            (interactionSessionKind session)
            (interactionSessionSubjectBrick session)
            (interactionSessionSubjectRaw session)
            nextDomain nextRevision
        , interactionSessionConfirmedActions =
            interactionSessionConfirmedActions session + 1
        , interactionSessionUpdatedAt = now
        }
      response = OperationalResponse
        { operationalResponseOk = True
        , operationalResponseHuman = interactionActionLabel action <> " accepted"
        , operationalResponseResultKind = Just "interaction_action"
        , operationalResponseEntity = Nothing
        , operationalResponseChanged = ["interaction", "domain"]
        , operationalResponseWarnings = []
        , operationalResponseErrorCode = Nothing
        , operationalResponseHint = Nothing
        , operationalResponseDryRun = Nothing
        , operationalResponseDomainRevision = nextDomain
        }
      next = state
        { interactionStateSessions = Map.insert identifier accepted
            (interactionStateSessions state)
        , interactionStateLatestResponse = Just response
        }
  validateInteractionState next
  pure (action, response, next)

rebaseInteraction ::
  InteractionId -> Integer -> UTCTime -> InteractionState ->
  Either InteractionError (InteractionSession, InteractionState)
rebaseInteraction identifier currentDomain now state = do
  session <- lookupSession identifier state
  when (interactionSessionStatus session /= InteractionStale)
    (Left (InteractionIsNotStale identifier (interactionSessionStatus session)))
  let nextRevision = interactionSessionInteractionRevision session + 1
      rebased = session
        { interactionSessionStatus = InteractionOpen
        , interactionSessionDomainRevision = currentDomain
        , interactionSessionInteractionRevision = nextRevision
        , interactionSessionPromptKey = promptKey
            (interactionSessionKind session)
            (interactionSessionSubjectBrick session)
            (interactionSessionSubjectRaw session)
            currentDomain nextRevision
        , interactionSessionUpdatedAt = now
        }
      next = state
        {interactionStateSessions = Map.insert identifier rebased
          (interactionStateSessions state)}
  validateInteractionState next
  pure (rebased, next)

completeInteraction ::
  InteractionId -> UTCTime -> InteractionState ->
  Either InteractionError (InteractionSession, InteractionState)
completeInteraction identifier now = transitionOpen identifier now InteractionCompleted

abandonInteraction ::
  InteractionId -> UTCTime -> InteractionState ->
  Either InteractionError (InteractionSession, InteractionState)
abandonInteraction identifier now state = do
  session <- lookupSession identifier state
  unless (interactionSessionStatus session `elem`
      [InteractionOpen, InteractionStale])
    (Left (InteractionIsTerminal identifier))
  transitionSession identifier now InteractionAbandoned state

transitionOpen ::
  InteractionId -> UTCTime -> InteractionStatus -> InteractionState ->
  Either InteractionError (InteractionSession, InteractionState)
transitionOpen identifier now target state = do
  session <- lookupSession identifier state
  when (interactionSessionStatus session /= InteractionOpen)
    (Left (InteractionIsNotOpen identifier (interactionSessionStatus session)))
  transitionSession identifier now target state

transitionSession ::
  InteractionId -> UTCTime -> InteractionStatus -> InteractionState ->
  Either InteractionError (InteractionSession, InteractionState)
transitionSession identifier now target state = do
  session <- lookupSession identifier state
  let source = interactionSessionStatus session
      allowed = (source, target) `elem`
        [ (InteractionOpen, InteractionStale)
        , (InteractionOpen, InteractionCompleted)
        , (InteractionOpen, InteractionAbandoned)
        , (InteractionStale, InteractionOpen)
        , (InteractionStale, InteractionAbandoned)
        ]
  unless allowed (Left (InvalidInteractionTransition source target))
  let updated = session
        { interactionSessionStatus = target
        , interactionSessionUpdatedAt = now
        }
      next = state
        {interactionStateSessions = Map.insert identifier updated
          (interactionStateSessions state)}
  validateInteractionState next
  pure (updated, next)

saveFirstSurfaceCheckpoint ::
  SurfaceCheckpointDraft -> UTCTime -> InteractionState ->
  Either InteractionError (SurfaceCheckpoint, InteractionState)
saveFirstSurfaceCheckpoint draft now state = do
  validateCheckpointDraft draft
  let surface = checkpointDraftSurfaceId draft
  when (Map.member surface (interactionStateCheckpoints state))
    (Left (CheckpointAlreadyExists surface))
  let checkpoint = checkpointFromDraft ("checkpoint-" <> surface) now draft
      next = state
        {interactionStateCheckpoints = Map.insert surface checkpoint
          (interactionStateCheckpoints state)}
  validateInteractionState next
  pure (checkpoint, next)

saveExistingSurfaceCheckpoint ::
  SurfaceCheckpointDraft -> UTCTime -> InteractionState ->
  Either InteractionError (SurfaceCheckpoint, InteractionState)
saveExistingSurfaceCheckpoint draft now state = do
  validateCheckpointDraft draft
  let surface = checkpointDraftSurfaceId draft
  existing <- maybe (Left (CheckpointDoesNotExist surface)) Right
    (Map.lookup surface (interactionStateCheckpoints state))
  let checkpoint = checkpointFromDraft (surfaceCheckpointId existing) now draft
      next = state
        {interactionStateCheckpoints = Map.insert surface checkpoint
          (interactionStateCheckpoints state)}
  validateInteractionState next
  pure (checkpoint, next)

honestInteractionProgress :: InteractionSession -> InteractionProgress
honestInteractionProgress session = InteractionProgress
  { interactionProgressFacts =
      [Text.pack (show confirmed) <> " confirmed " <> noun]
  , interactionProgressEstimatedRemainingMin = estimateMin
  , interactionProgressEstimatedRemainingMax = estimateMax
  }
  where
    confirmed = interactionSessionConfirmedActions session
    noun | confirmed == 1 = "action"
         | otherwise = "actions"
    (estimateMin, estimateMax)
      | interactionSessionKind session == "priority_comparison" =
          (Just 0, Just (max 0 (3 - confirmed)))
      | otherwise = (Nothing, Nothing)

envelopeFor :: InteractionSession -> InteractionEnvelope
envelopeFor session = InteractionEnvelope
  { interactionEnvelopeProtocolVersion = 1
  , interactionEnvelopeInteractionId = interactionSessionId session
  , interactionEnvelopeDomainRevision = interactionSessionDomainRevision session
  , interactionEnvelopeInteractionRevision =
      interactionSessionInteractionRevision session
  , interactionEnvelopeKind = interactionSessionKind session
  , interactionEnvelopePrompt = promptFor session
  , interactionEnvelopeSubject = Nothing
  , interactionEnvelopeActions = actionsFor session
  , interactionEnvelopeHelp = Just (helpFor session)
  , interactionEnvelopeProgress = Just (honestInteractionProgress session)
  }

actionsFor :: InteractionSession -> [InteractionAction]
actionsFor session
  | interactionSessionKind session == "priority_comparison" =
      [action "yes" "Yes" "y", action "no" "No" "n", action "skip" "Skip" "s"]
  | otherwise = [action "continue" "Continue" "c"]
  where
    action identifier label shortcut = InteractionAction
      { interactionActionId = identifier
      , interactionActionLabel = label
      , interactionActionShortcut = shortcut
      , interactionActionCanonicalCommand = Text.unwords
          ["la", "interaction", "submit", unInteractionId
            (interactionSessionId session), identifier]
      , interactionActionDestructive = False
      , interactionActionConfirmationRequired = False
      }

promptFor :: InteractionSession -> Text
promptFor session
  | interactionSessionKind session == "priority_comparison" =
      "Is the first item more important?"
  | otherwise = "Continue this interaction?"

helpFor :: InteractionSession -> Text
helpFor session = "Choose one canonical action for "
  <> interactionSessionPromptKey session <> "."

promptKey :: Text -> Maybe Text -> Maybe Text -> Integer -> Integer -> Text
promptKey kind subjectBrick subjectRaw domainRevision interactionRevision =
  Text.intercalate ":"
    [ kind
    , maybe "no-brick" id subjectBrick
    , maybe "no-raw" id subjectRaw
    , "domain-" <> Text.pack (show domainRevision)
    , "interaction-" <> Text.pack (show interactionRevision)
    ]

staleResponse :: Integer -> OperationalResponse
staleResponse revision = OperationalResponse
  { operationalResponseOk = False
  , operationalResponseHuman = "This interaction changed; rebase before answering."
  , operationalResponseResultKind = Just "interaction_rejection"
  , operationalResponseEntity = Nothing
  , operationalResponseChanged = []
  , operationalResponseWarnings = []
  , operationalResponseErrorCode = Just "stale_interaction"
  , operationalResponseHint = Just "Rebase and use an action from the new prompt."
  , operationalResponseDryRun = Nothing
  , operationalResponseDomainRevision = revision
  }

checkpointFromDraft ::
  Text -> UTCTime -> SurfaceCheckpointDraft -> SurfaceCheckpoint
checkpointFromDraft identifier now draft = SurfaceCheckpoint
  { surfaceCheckpointId = identifier
  , surfaceCheckpointSurfaceId = checkpointDraftSurfaceId draft
  , surfaceCheckpointInteractionId = checkpointDraftInteractionId draft
  , surfaceCheckpointDisplayedDomainRevision =
      checkpointDraftDisplayedDomainRevision draft
  , surfaceCheckpointDisplayedInteractionRevision =
      checkpointDraftDisplayedInteractionRevision draft
  , surfaceCheckpointScreen = checkpointDraftScreen draft
  , surfaceCheckpointSelectedItem = checkpointDraftSelectedItem draft
  , surfaceCheckpointTextBuffer = checkpointDraftTextBuffer draft
  , surfaceCheckpointCursorOffset = checkpointDraftCursorOffset draft
  , surfaceCheckpointTranscript = checkpointDraftTranscript draft
  , surfaceCheckpointLastResponse = checkpointDraftLastResponse draft
  , surfaceCheckpointLastStatus = checkpointDraftLastStatus draft
  , surfaceCheckpointLastProjection = checkpointDraftLastProjection draft
  , surfaceCheckpointHistoryQuery = checkpointDraftHistoryQuery draft
  , surfaceCheckpointLastHistoryPage = checkpointDraftLastHistoryPage draft
  , surfaceCheckpointLastHistoryBrief = checkpointDraftLastHistoryBrief draft
  , surfaceCheckpointUpdatedAt = now
  }

validateCheckpointDraft :: SurfaceCheckpointDraft -> Either InteractionError ()
validateCheckpointDraft draft = do
  when (Text.null (Text.strip (checkpointDraftSurfaceId draft)))
    (Left EmptySurfaceId)
  case checkpointDraftCursorOffset draft of
    Just offset | offset < 0 -> Left (InvalidCheckpointCursor offset)
    _ -> Right ()

lookupSession ::
  InteractionId -> InteractionState -> Either InteractionError InteractionSession
lookupSession identifier state = maybe (Left (UnknownInteraction identifier)) Right
  (Map.lookup identifier (interactionStateSessions state))

------------------------------------------------------------
-- Powered-up adapter boundary
------------------------------------------------------------

data PoweredUpInvocation = PoweredUpInvocation
  { poweredUpInvocationExecutable :: Text
  , poweredUpInvocationArguments :: [Text]
  , poweredUpInvocationStdin :: Text
  }
  deriving stock (Eq, Show, Generic)

data PoweredUpValidation = PoweredUpAccepted | PoweredUpRejected PoweredUpError
  deriving stock (Eq, Show)

data PoweredUpError
  = EmptyPoweredUpPath
  | PoweredUpTransportMustBeStdin
  | PoweredUpOutputTooLarge
  | PoweredUpOutputMissing
  | PoweredUpOutputAmbiguous
  | PoweredUpOutputMalformed Text
  | PoweredUpOutputUnsupported
  | PoweredUpExecutionFailed Text
  | PoweredUpTimedOut
  deriving stock (Eq, Show)

poweredUpProbeRequest :: Text
poweredUpProbeRequest = "{\"protocol_version\":1,\"kind\":\"probe\"}"

poweredUpInvocation :: Text -> Text -> PoweredUpInvocation
poweredUpInvocation path request = PoweredUpInvocation
  { poweredUpInvocationExecutable = path
  , poweredUpInvocationArguments = []
  , poweredUpInvocationStdin = request
  }

requestPoweredUpModelViaStdin ::
  FilePath -> Text -> IO (Either PoweredUpError (Text, ProcessInvocationTrace))
requestPoweredUpModelViaStdin executable request = do
  let invocation = poweredUpInvocation (Text.pack executable) request
      trace = traceFor invocation
  outcome <- timeout (5 * 1000000) (try
    (readCreateProcessWithExitCode
      (proc executable (map Text.unpack (poweredUpInvocationArguments invocation)))
      (Text.unpack (poweredUpInvocationStdin invocation))) ::
      IO (Either SomeException (ExitCode, String, String)))
  pure $ case outcome of
    Nothing -> Left PoweredUpTimedOut
    Just (Left problem) -> Left (PoweredUpExecutionFailed (Text.pack (show problem)))
    Just (Right (ExitSuccess, stdoutText, _)) ->
      Right (Text.pack stdoutText, trace)
    Just (Right (ExitFailure code, _, stderrText)) -> Left
      (PoweredUpExecutionFailed ("exit " <> Text.pack (show code) <> ": "
        <> boundedDiagnostic (Text.pack stderrText)))

probePoweredUpAdapter ::
  FilePath -> IO (Either PoweredUpError ProcessInvocationTrace)
probePoweredUpAdapter executable = do
  result <- requestPoweredUpModelViaStdin executable poweredUpProbeRequest
  pure $ do
    (response, trace) <- result
    parsePoweredUpProbe response
    pure trace

validatePoweredUpAdapter ::
  Text -> Text -> Text -> InteractionState ->
  (PoweredUpValidation, OperationalResponse, InteractionState)
validatePoweredUpAdapter path transport response state =
  case validation of
    Right () ->
      let runtime = ReplRuntime PoweredUp (Just path) (Just 1)
          operational = OperationalResponse
            { operationalResponseOk = True
            , operationalResponseHuman = "Powered-up adapter validated."
            , operationalResponseResultKind = Just "powered_up_adapter"
            , operationalResponseEntity = Nothing
            , operationalResponseChanged = ["repl.mode", "repl.powered_by"]
            , operationalResponseWarnings = []
            , operationalResponseErrorCode = Nothing
            , operationalResponseHint = Nothing
            , operationalResponseDryRun = Nothing
            , operationalResponseDomainRevision = 0
            }
          next = withTrace state
            { interactionStateReplRuntime = runtime
            , interactionStateLatestResponse = Just operational
            }
      in (PoweredUpAccepted, operational, next)
    Left problem ->
      let operational = OperationalResponse
            { operationalResponseOk = False
            , operationalResponseHuman = "Powered-up startup failed."
            , operationalResponseResultKind = Just "powered_up_adapter"
            , operationalResponseEntity = Nothing
            , operationalResponseChanged = []
            , operationalResponseWarnings = []
            , operationalResponseErrorCode = Just "invalid_powered_up_adapter"
            , operationalResponseHint = Just "Return one protocol-v1 OK object."
            , operationalResponseDryRun = Nothing
            , operationalResponseDomainRevision = 0
            }
          next = withTrace state {interactionStateLatestResponse = Just operational}
      in (PoweredUpRejected problem, operational, next)
  where
    validation = do
      when (Text.null (Text.strip path)) (Left EmptyPoweredUpPath)
      unless (transport == "stdin") (Left PoweredUpTransportMustBeStdin)
      parsePoweredUpProbe response
    invocation = poweredUpInvocation path poweredUpProbeRequest
    withTrace current = current
      {interactionStateProcessTraces = Map.insert path (traceFor invocation)
        (interactionStateProcessTraces current)}

useDumbMode :: InteractionState -> Either InteractionError InteractionState
useDumbMode state = case replRuntimeMode (interactionStateReplRuntime state) of
  Dumb -> Left PoweredUpModeIsNotEnabled
  PoweredUp -> Right state
    {interactionStateReplRuntime = ReplRuntime Dumb Nothing Nothing}

parsePoweredUpProbe :: Text -> Either PoweredUpError ()
parsePoweredUpProbe output = do
  when (Text.length output > 16384) (Left PoweredUpOutputTooLarge)
  encoded <- case extractJsonObjects output of
    [] -> Left PoweredUpOutputMissing
    [candidate] -> Right candidate
    _ -> Left PoweredUpOutputAmbiguous
  value <- either (Left . PoweredUpOutputMalformed . Text.pack) Right
    (eitherDecode (LBS.fromStrict (TextEncoding.encodeUtf8 encoded)))
  fields <- case value of
    Object objectValue -> Right objectValue
    _ -> Left PoweredUpOutputUnsupported
  protocol <- case KeyMap.lookup (Key.fromText "protocol_version") fields of
    Just encodedProtocol -> case (Aeson.fromJSON encodedProtocol :: Result Integer) of
      Success version -> Right version
      Error _ -> Left PoweredUpOutputUnsupported
    Nothing -> Left PoweredUpOutputUnsupported
  status <- case KeyMap.lookup (Key.fromText "status") fields of
    Just (String valueStatus) -> Right valueStatus
    _ -> Left PoweredUpOutputUnsupported
  unless (protocol == 1 && status == "OK") (Left PoweredUpOutputUnsupported)

extractJsonObjects :: Text -> [Text]
extractJsonObjects = map Text.pack . reverse . finish . foldl step initial . Text.unpack
  where
    initial = (0 :: Int, False, False, Nothing :: Maybe String, [] :: [String])
    step (depth, quoted, escaped, current, found) character =
      case current of
        Nothing
          | character == '{' -> (1, False, False, Just "{", found)
          | otherwise -> (0, False, False, Nothing, found)
        Just reversed ->
          let nextReversed = character : reversed
          in if quoted
              then if escaped
                then (depth, True, False, Just nextReversed, found)
                else case character of
                  '\\' -> (depth, True, True, Just nextReversed, found)
                  '"' -> (depth, False, False, Just nextReversed, found)
                  _ -> (depth, True, False, Just nextReversed, found)
              else case character of
                '"' -> (depth, True, False, Just nextReversed, found)
                '{' -> (depth + 1, False, False, Just nextReversed, found)
                '}' | depth == 1 -> (0, False, False, Nothing,
                        reverse nextReversed : found)
                    | otherwise -> (depth - 1, False, False,
                        Just nextReversed, found)
                _ -> (depth, False, False, Just nextReversed, found)
    finish (_, _, _, _, found) = found

traceFor :: PoweredUpInvocation -> ProcessInvocationTrace
traceFor invocation = ProcessInvocationTrace
  { processInvocationTraceExecutable = poweredUpInvocationExecutable invocation
  , processInvocationTraceArgumentCount = fromIntegral
      (length (poweredUpInvocationArguments invocation))
  , processInvocationTraceArgumentsContainPrompt = False
  , processInvocationTraceStdinContainsProbe =
      not (Text.null (poweredUpInvocationStdin invocation))
  , processInvocationTraceSecretValuesRecorded = False
  }

statusSummary ::
  Maybe CompactEntityReference -> Integer -> Integer -> Integer ->
  InteractionState -> StatusSummary
statusSummary focus humanWip proposals notices state = StatusSummary
  { statusSummaryHuman = case replRuntimeMode runtime of
      Dumb -> "mode: dumb"
      PoweredUp -> "mode: powered up · by: "
        <> maybe "unknown" id (replRuntimePoweredBy runtime)
  , statusSummaryMode = harnessModeText (replRuntimeMode runtime)
  , statusSummaryPoweredBy = replRuntimePoweredBy runtime
  , statusSummaryCurrentFocus = focus
  , statusSummaryHumanWipCount = humanWip
  , statusSummaryOpenProposalCount = proposals
  , statusSummaryPendingNoticeCount = notices
  }
  where
    runtime = interactionStateReplRuntime state

boundedDiagnostic :: Text -> Text
boundedDiagnostic = Text.take 512

------------------------------------------------------------
-- Validation and JSON naming
------------------------------------------------------------

validateInteractionState :: InteractionState -> Either InteractionError ()
validateInteractionState state = do
  when (interactionStateNextOrdinal state < 0)
    (invalid "negative interaction identity ordinal")
  mapM_ validateSession (Map.toList (interactionStateSessions state))
  mapM_ validateCheckpoint (Map.toList (interactionStateCheckpoints state))
  validateRuntime (interactionStateReplRuntime state)
  mapM_ validateTrace (Map.elems (interactionStateProcessTraces state))
  where
    invalid = Left . InvalidInteractionState
    validateSession (identifier, session) = do
      unless (identifier == interactionSessionId session)
        (invalid "interaction map key differs from entity identity")
      when (interactionSessionInteractionRevision session < 1)
        (invalid "interaction revision is not positive")
      when (interactionSessionDomainRevision session < 0)
        (invalid "interaction domain revision is negative")
      when (interactionSessionConfirmedActions session < 0)
        (invalid "confirmed action count is negative")
      unless (interactionSessionPromptKey session == promptKey
          (interactionSessionKind session)
          (interactionSessionSubjectBrick session)
          (interactionSessionSubjectRaw session)
          (interactionSessionDomainRevision session)
          (interactionSessionInteractionRevision session))
        (invalid "prompt key is not tied to the session revisions")
    validateCheckpoint (surface, checkpoint) = do
      unless (surface == surfaceCheckpointSurfaceId checkpoint)
        (invalid "checkpoint map key differs from surface identity")
      case surfaceCheckpointCursorOffset checkpoint of
        Just offset | offset < 0 -> invalid "checkpoint cursor is negative"
        _ -> Right ()
    validateRuntime runtime = case replRuntimeMode runtime of
      Dumb -> unless (replRuntimePoweredBy runtime == Nothing
          && replRuntimeAdapterProtocol runtime == Nothing)
        (invalid "dumb runtime retained powered-up identity")
      PoweredUp -> unless (isJust (replRuntimePoweredBy runtime)
          && replRuntimeAdapterProtocol runtime == Just 1)
        (invalid "powered-up runtime is not validated for protocol 1")
    validateTrace trace = do
      when (processInvocationTraceArgumentsContainPrompt trace)
        (invalid "powered-up prompt appeared in process arguments")
      when (processInvocationTraceSecretValuesRecorded trace)
        (invalid "process trace retained secret values")

recordOptions :: String -> Aeson.Options
recordOptions prefix = defaultOptions
  { Aeson.fieldLabelModifier = camelTo2 '_' . lowerFirst . drop (length prefix)
  }
  where
    lowerFirst [] = []
    lowerFirst (first : rest) = Char.toLower first : rest

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

-- | Read-only planning artifacts and thin local UI adapter sessions.
--
-- Planning manifests, exporter output, imported actuals, and web sessions are
-- artifacts around the canonical domain.  The core prepares and validates a
-- pinned projection; executable Pack code can only serialize that projection.
-- UI adapter output is likewise validated against a canonical interaction
-- envelope before the caller may submit the decoded action to the interaction
-- protocol.
module LittleAnt.V1.Planning
  ( ExportPayload (..)
  , ExtensionDeskSurface (..)
  , ImportedActual (..)
  , PlanningError (..)
  , PlanningExport (..)
  , PlanningItem (..)
  , PlanningManifest (..)
  , PlanningProjection (..)
  , PlanningState (..)
  , TaskJugglerExportMetadata (..)
  , TaskJugglerExporterOutput (..)
  , UiForward (..)
  , UiRenderedEnvelope (..)
  , WebSessionStatus (..)
  , WebUiSession (..)
  , WebUiTransition (..)
  , WebUiTransitionKind (..)
  , attachTaskJugglerOutput
  , closeLocalWebUi
  , createTaskJugglerManifest
  , decodeUiInput
  , emptyPlanningState
  , enrichmentProposal
  , extensionDeskSurface
  , forwardWebUiInput
  , importTaskJugglerActual
  , metroWebUiSource
  , metroWebUiV1
  , openLocalWebUi
  , renderUiEnvelope
  , runMetroWebUiDecode
  , runMetroWebUiRender
  , runTaskJugglerExporter
  , taskJugglerExporterSource
  , taskJugglerExporterV1
  , validatePlanningState
  ) where

import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), Options (..), Result (..), ToJSON (toJSON), Value (..),
   camelTo2, defaultOptions, fromJSON, genericParseJSON, genericToJSON, object,
   withText, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Char8 as BS8
import Data.List (find, nub)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (isJust)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain
  (Brick (..), BrickId, DomainState (..))
import LittleAnt.V1.Integration
  (ComponentStatus (..), PackComponent (..), PackComponentKind (..),
   PackExecutionResult (..), defaultSandboxLimits, runLuaComponent)
import LittleAnt.V1.Interaction
  (InteractionAction (..), InteractionEnvelope (..), InteractionId)
import LittleAnt.V1.Judgment
  (EffortAssessment (..), EffortBand (..), EffortProfile (..), JudgmentState,
   currentEffortAssessment)

------------------------------------------------------------
-- Typed planning and adapter artifacts
------------------------------------------------------------

data ExportPayload = ExportPayload
  { exportPayloadMediaType :: Text
  , exportPayloadSuggestedFilename :: Text
  , exportPayloadContentHash :: Text
  , exportPayloadSize :: Integer
  }
  deriving stock (Eq, Show, Generic)

data PlanningManifest = PlanningManifest
  { planningManifestId :: Text
  , planningManifestExporter :: PackComponent
  , planningManifestDatasetRevision :: Integer
  , planningManifestSelectedBricks :: [BrickId]
  , planningManifestEffortProfile :: EffortProfile
  , planningManifestGeneratedAt :: UTCTime
  , planningManifestPayload :: ExportPayload
  , planningManifestContentHash :: Text
  }
  deriving stock (Eq, Show, Generic)

data PlanningItem = PlanningItem
  { planningItemBrick :: BrickId
  , planningItemTitle :: Text
  , planningItemAncestors :: [BrickId]
  , planningItemEffortBand :: Text
  , planningItemMacro :: Text
  , planningItemOptimisticHours :: Double
  , planningItemRealisticHours :: Double
  , planningItemPessimisticHours :: Double
  , planningItemWarnings :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data PlanningProjection = PlanningProjection
  { planningProjectionVersion :: Integer
  , planningProjectionDatasetRevision :: Integer
  , planningProjectionEffortProfile :: EffortProfile
  , planningProjectionItems :: [PlanningItem]
  }
  deriving stock (Eq, Show, Generic)

data TaskJugglerExportMetadata = TaskJugglerExportMetadata
  { taskJugglerExportMetadataExporterId :: Text
  , taskJugglerExportMetadataProjectionVersion :: Integer
  , taskJugglerExportMetadataMacros :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data TaskJugglerExporterOutput = TaskJugglerExporterOutput
  { taskJugglerExporterOutputBytes :: Text
  , taskJugglerExporterOutputMediaType :: Text
  , taskJugglerExporterOutputSuggestedFilename :: Text
  , taskJugglerExporterOutputWarnings :: [Text]
  , taskJugglerExporterOutputExportMetadata :: TaskJugglerExportMetadata
  }
  deriving stock (Eq, Show, Generic)

data PlanningExport = PlanningExport
  { planningExportManifest :: Text
  , planningExportProjection :: PlanningProjection
  , planningExportOutput :: Maybe TaskJugglerExporterOutput
  }
  deriving stock (Eq, Show, Generic)

data ImportedActual = ImportedActual
  { importedActualId :: Text
  , importedActualManifest :: Text
  , importedActualBrick :: BrickId
  , importedActualObservedHours :: Double
  , importedActualImportedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data WebSessionStatus = WebSessionOpen | WebSessionClosed
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data WebUiSession = WebUiSession
  { webUiSessionId :: Text
  , webUiSessionComponent :: PackComponent
  , webUiSessionBindHost :: Text
  , webUiSessionPort :: Integer
  , webUiSessionStatus :: WebSessionStatus
  , webUiSessionOpenedAt :: UTCTime
  , webUiSessionClosedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

data UiForward = UiForward
  { uiForwardInteractionId :: InteractionId
  , uiForwardInteractionRevision :: Integer
  , uiForwardDomainRevision :: Integer
  , uiForwardActionId :: Text
  }
  deriving stock (Eq, Show, Generic)

data UiRenderedEnvelope = UiRenderedEnvelope
  { uiRenderedEnvelopeChannel :: Text
  , uiRenderedEnvelopeReadOnly :: Bool
  , uiRenderedEnvelopeEnvelope :: InteractionEnvelope
  }
  deriving stock (Eq, Show, Generic)

data WebUiTransitionKind
  = WebUiOpened
  | WebUiClosed
  | WebUiForwarded
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data WebUiTransition = WebUiTransition
  { webUiTransitionId :: Text
  , webUiTransitionSession :: Text
  , webUiTransitionKind :: WebUiTransitionKind
  , webUiTransitionForward :: Maybe UiForward
  , webUiTransitionAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data PlanningState = PlanningState
  { planningStateNextIdentity :: Integer
  , planningStateManifests :: Map Text PlanningManifest
  , planningStateExports :: Map Text PlanningExport
  , planningStateActuals :: Map Text ImportedActual
  , planningStateWebSessions :: Map Text WebUiSession
  , planningStateWebTransitions :: [WebUiTransition]
  }
  deriving stock (Eq, Show, Generic)

data ExtensionDeskSurface = ExtensionDeskSurface
  { extensionDeskSurfaceActorPartyType :: Text
  , extensionDeskSurfaceExposedItems :: [Text]
  , extensionDeskSurfaceProvidedOperations :: [Text]
  , extensionDeskSurfaceDemandedContracts :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data PlanningError
  = EmptyPlanningCut
  | UnknownPlanningBrick BrickId
  | OverlappingPlanningCut BrickId BrickId
  | PlanningEffortUnavailable BrickId
  | PlanningEffortProfileMismatch BrickId
  | StalePlanningRevision Integer Integer
  | TaskJugglerExporterUnavailable
  | InvalidExportPayload Text
  | UnknownPlanningManifest Text
  | TaskJugglerOutputAlreadyRecorded Text
  | InvalidTaskJugglerOutput Text
  | ActualBrickNotSelected BrickId
  | InvalidObservedHours Double
  | DuplicateImportedActual Text BrickId
  | WebUiComponentUnavailable
  | UnknownWebUiSession Text
  | WebUiSessionNotOpen Text
  | UiEnvelopeMismatch Text
  | UiActionNotAvailable Text
  | InvalidUiAdapterOutput Text
  | InvalidEnricherComponent
  | InvalidPlanningState Text
  deriving stock (Eq, Show)

------------------------------------------------------------
-- JSON protocol
------------------------------------------------------------

instance ToJSON ExportPayload where toJSON = genericToJSON (recordOptions "exportPayload")
instance FromJSON ExportPayload where parseJSON = genericParseJSON (recordOptions "exportPayload")
instance ToJSON PlanningManifest where toJSON = genericToJSON (recordOptions "planningManifest")
instance FromJSON PlanningManifest where parseJSON = genericParseJSON (recordOptions "planningManifest")
instance ToJSON PlanningItem where toJSON = genericToJSON (recordOptions "planningItem")
instance FromJSON PlanningItem where parseJSON = genericParseJSON (recordOptions "planningItem")
instance ToJSON PlanningProjection where toJSON = genericToJSON (recordOptions "planningProjection")
instance FromJSON PlanningProjection where parseJSON = genericParseJSON (recordOptions "planningProjection")
instance ToJSON TaskJugglerExportMetadata where
  toJSON = genericToJSON (recordOptions "taskJugglerExportMetadata")
instance FromJSON TaskJugglerExportMetadata where
  parseJSON = genericParseJSON (recordOptions "taskJugglerExportMetadata")
instance ToJSON TaskJugglerExporterOutput where
  toJSON = genericToJSON (recordOptions "taskJugglerExporterOutput")
instance FromJSON TaskJugglerExporterOutput where
  parseJSON = genericParseJSON (recordOptions "taskJugglerExporterOutput")
instance ToJSON PlanningExport where toJSON = genericToJSON (recordOptions "planningExport")
instance FromJSON PlanningExport where parseJSON = genericParseJSON (recordOptions "planningExport")
instance ToJSON ImportedActual where toJSON = genericToJSON (recordOptions "importedActual")
instance FromJSON ImportedActual where parseJSON = genericParseJSON (recordOptions "importedActual")
instance ToJSON WebSessionStatus where
  toJSON = String . \case
    WebSessionOpen -> "open"
    WebSessionClosed -> "closed"
instance FromJSON WebSessionStatus where
  parseJSON = withText "WebSessionStatus" $ \case
    "open" -> pure WebSessionOpen
    "closed" -> pure WebSessionClosed
    _ -> fail "unknown WebSessionStatus"
instance ToJSON WebUiSession where toJSON = genericToJSON (recordOptions "webUiSession")
instance FromJSON WebUiSession where parseJSON = genericParseJSON (recordOptions "webUiSession")
instance ToJSON UiForward where toJSON = genericToJSON (recordOptions "uiForward")
instance FromJSON UiForward where parseJSON = genericParseJSON (recordOptions "uiForward")
instance ToJSON UiRenderedEnvelope where toJSON = genericToJSON (recordOptions "uiRenderedEnvelope")
instance FromJSON UiRenderedEnvelope where parseJSON = genericParseJSON (recordOptions "uiRenderedEnvelope")
instance ToJSON WebUiTransitionKind where
  toJSON = String . \case
    WebUiOpened -> "opened"
    WebUiClosed -> "closed"
    WebUiForwarded -> "forwarded"
instance FromJSON WebUiTransitionKind where
  parseJSON = withText "WebUiTransitionKind" $ \case
    "opened" -> pure WebUiOpened
    "closed" -> pure WebUiClosed
    "forwarded" -> pure WebUiForwarded
    _ -> fail "unknown WebUiTransitionKind"
instance ToJSON WebUiTransition where toJSON = genericToJSON (recordOptions "webUiTransition")
instance FromJSON WebUiTransition where parseJSON = genericParseJSON (recordOptions "webUiTransition")
instance ToJSON PlanningState where toJSON = genericToJSON (recordOptions "planningState")
instance FromJSON PlanningState where parseJSON = genericParseJSON (recordOptions "planningState")
instance ToJSON ExtensionDeskSurface where
  toJSON = genericToJSON (recordOptions "extensionDeskSurface")
instance FromJSON ExtensionDeskSurface where
  parseJSON = genericParseJSON (recordOptions "extensionDeskSurface")

recordOptions :: String -> Options
recordOptions prefix = defaultOptions
  {fieldLabelModifier = camelTo2 '_' . drop (length prefix)}

------------------------------------------------------------
-- Standard Pack components and ExtensionDesk
------------------------------------------------------------

taskJugglerExporterV1 :: PackComponent
taskJugglerExporterV1 = PackComponent
  { packComponentId = "standard/taskjuggler"
  , packComponentVersion = 1
  , packComponentPackId = "little-ant/standard"
  , packComponentPackVersion = 1
  , packComponentKind = ReadOnlyExporterComponent
  , packComponentExecutable = True
  , packComponentStatus = ComponentEnabled
  , packComponentCapabilities = []
  }

metroWebUiV1 :: PackComponent
metroWebUiV1 = PackComponent
  { packComponentId = "standard/web-metro"
  , packComponentVersion = 1
  , packComponentPackId = "little-ant/standard"
  , packComponentPackVersion = 1
  , packComponentKind = UiAdapterComponent
  , packComponentExecutable = True
  , packComponentStatus = ComponentEnabled
  , packComponentCapabilities = []
  }

extensionDeskSurface :: ExtensionDeskSurface
extensionDeskSurface = ExtensionDeskSurface
  { extensionDeskSurfaceActorPartyType = "person"
  , extensionDeskSurfaceExposedItems =
      [ "user.id"
      , "little-ant/standard"
      , "standard/microsoft-todo"
      , "standard/notesnook"
      , "standard/taskjuggler"
      , "standard/web-metro"
      ]
  , extensionDeskSurfaceProvidedOperations =
      [ "InstallPack", "RecordPackInvocation", "DisablePack", "EnablePack"
      , "RevokePack", "StoreCredential", "BindCredential"
      , "LockCredentialBinding", "UnlockCredentialBinding"
      , "RevokeCredentialBinding", "CreateImportProfile", "RetireImportProfile"
      , "PlanImport", "StartImport", "AcceptImportCandidate"
      , "ObserveExternalCompletion", "FinishImportCapture", "VerifyImport"
      , "CompleteSynchronization", "PlanEraseAfterImport"
      , "ApproveSourceEffect", "DeclineSourceEffect", "RetrySourceEffect"
      , "RecordSourceEffectApplied", "RecordSourceEffectFailed", "CutOverImport"
      , "ProposeEmptyContainerDeletion", "ExportTaskJuggler"
      , "ImportTaskJugglerActual", "OpenLocalWebUi", "CloseLocalWebUi"
      , "SubmitWebUiInput"
      ]
  , extensionDeskSurfaceDemandedContracts =
      [ "PackRunner", "HostHttp", "CredentialBroker", "SourceAdapterContract"
      , "EnricherContract", "ReadOnlyExporterContract", "UIAdapterContract"
      ]
  }

-- | A bounded attributed proposal.  No state value is accepted or returned,
-- so an Enricher cannot smuggle canonical mutation through this contract.
enrichmentProposal :: PackComponent -> Value -> Either PlanningError Value
enrichmentProposal component projection = do
  unless (packComponentKind component == EnricherComponent
      && packComponentExecutable component
      && packComponentStatus component == ComponentEnabled)
    (Left InvalidEnricherComponent)
  pure (object
    [ "component" .= packComponentId component
    , "component_version" .= packComponentVersion component
    , "projection" .= projection
    , "authority" .= ("proposal_only" :: Text)
    ])

------------------------------------------------------------
-- Planning cut, manifest, export, and actual evidence
------------------------------------------------------------

emptyPlanningState :: PlanningState
emptyPlanningState = PlanningState 1 Map.empty Map.empty Map.empty Map.empty []

createTaskJugglerManifest ::
  UTCTime -> Integer -> Integer -> [BrickId] -> EffortProfile -> ExportPayload ->
  PackComponent -> DomainState -> JudgmentState -> PlanningState ->
  Either PlanningError (PlanningManifest, PlanningExport, PlanningState)
createTaskJugglerManifest now datasetRevision currentRevision selected profile
    payload exporter domain judgment state = do
  when (null selected) (Left EmptyPlanningCut)
  validateExporter exporter
  validatePayload payload
  unless (datasetRevision == currentRevision)
    (Left (StalePlanningRevision datasetRevision currentRevision))
  mapM_ (requireBrick domain) selected
  case firstOverlap domain selected of
    Just pair -> Left (uncurry OverlappingPlanningCut pair)
    Nothing -> pure ()
  items <- mapM (planningItem domain judgment profile) selected
  let ordinal = planningStateNextIdentity state
      identifier = identity "planning-manifest" ordinal
      manifest = PlanningManifest
        { planningManifestId = identifier
        , planningManifestExporter = exporter
        , planningManifestDatasetRevision = datasetRevision
        , planningManifestSelectedBricks = selected
        , planningManifestEffortProfile = profile
        , planningManifestGeneratedAt = now
        , planningManifestPayload = payload
        , planningManifestContentHash = exportPayloadContentHash payload
        }
      projection = PlanningProjection
        { planningProjectionVersion = 1
        , planningProjectionDatasetRevision = datasetRevision
        , planningProjectionEffortProfile = profile
        , planningProjectionItems = items
        }
      planningExport = PlanningExport identifier projection Nothing
      next = state
        { planningStateNextIdentity = ordinal + 1
        , planningStateManifests = Map.insert identifier manifest
            (planningStateManifests state)
        , planningStateExports = Map.insert identifier planningExport
            (planningStateExports state)
        }
  validatePlanningState next
  pure (manifest, planningExport, next)

attachTaskJugglerOutput ::
  Text -> TaskJugglerExporterOutput -> PlanningState ->
  Either PlanningError (PlanningExport, PlanningState)
attachTaskJugglerOutput manifestId output state = do
  manifest <- maybe (Left (UnknownPlanningManifest manifestId)) Right
    (Map.lookup manifestId (planningStateManifests state))
  planningExport <- maybe (Left (UnknownPlanningManifest manifestId)) Right
    (Map.lookup manifestId (planningStateExports state))
  when (isJust (planningExportOutput planningExport))
    (Left (TaskJugglerOutputAlreadyRecorded manifestId))
  validateTaskJugglerOutput manifest (planningExportProjection planningExport) output
  let updated = planningExport {planningExportOutput = Just output}
      next = state {planningStateExports = Map.insert manifestId updated
        (planningStateExports state)}
  validatePlanningState next
  pure (updated, next)

importTaskJugglerActual ::
  UTCTime -> Text -> BrickId -> Double -> PlanningState ->
  Either PlanningError (ImportedActual, PlanningState)
importTaskJugglerActual now manifestId brick hours state = do
  manifest <- maybe (Left (UnknownPlanningManifest manifestId)) Right
    (Map.lookup manifestId (planningStateManifests state))
  unless (brick `elem` planningManifestSelectedBricks manifest)
    (Left (ActualBrickNotSelected brick))
  when (hours < 0 || isNaN hours || isInfinite hours)
    (Left (InvalidObservedHours hours))
  when (any (\actual -> importedActualManifest actual == manifestId
      && importedActualBrick actual == brick) (Map.elems (planningStateActuals state)))
    (Left (DuplicateImportedActual manifestId brick))
  let ordinal = planningStateNextIdentity state
      identifier = identity "imported-actual" ordinal
      actual = ImportedActual identifier manifestId brick hours now
      next = state
        { planningStateNextIdentity = ordinal + 1
        , planningStateActuals = Map.insert identifier actual
            (planningStateActuals state)
        }
  validatePlanningState next
  pure (actual, next)

planningItem ::
  DomainState -> JudgmentState -> EffortProfile -> BrickId ->
  Either PlanningError PlanningItem
planningItem domain judgment profile identifier = do
  brick <- requireBrick domain identifier
  assessment <- maybe (Left (PlanningEffortUnavailable identifier)) Right
    (currentEffortAssessment judgment identifier)
  let band = effortAssessmentBand assessment
  unless (effortBandProfile band == profile)
    (Left (PlanningEffortProfileMismatch identifier))
  pure PlanningItem
    { planningItemBrick = identifier
    , planningItemTitle = brickTitle brick
    , planningItemAncestors = ancestorIds domain identifier
    , planningItemEffortBand = effortBandId band
    , planningItemMacro = effortBandMacro band
    , planningItemOptimisticHours = effortBandOptimisticHours band
    , planningItemRealisticHours = effortBandRealisticHours band
    , planningItemPessimisticHours = effortBandPessimisticHours band
    , planningItemWarnings =
        ["effort assessment is provisional" | effortAssessmentProvisional assessment]
    }

requireBrick :: DomainState -> BrickId -> Either PlanningError Brick
requireBrick domain identifier = maybe (Left (UnknownPlanningBrick identifier)) Right
  (Map.lookup identifier (domainBricks domain))

ancestorIds :: DomainState -> BrickId -> [BrickId]
ancestorIds domain identifier = go Set.empty (brickParent =<< Map.lookup identifier bricks)
  where
    bricks = domainBricks domain
    go seen = \case
      Nothing -> []
      Just current
        | Set.member current seen -> []
        | otherwise -> current : go (Set.insert current seen)
            (brickParent =<< Map.lookup current bricks)

firstOverlap :: DomainState -> [BrickId] -> Maybe (BrickId, BrickId)
firstOverlap domain selected = find overlaps
  [(left, right) | (index, left) <- zip [0 :: Int ..] selected,
    right <- drop (index + 1) selected]
  where
    overlaps (left, right) = left == right
      || left `elem` ancestorIds domain right
      || right `elem` ancestorIds domain left

validateExporter :: PackComponent -> Either PlanningError ()
validateExporter exporter = unless
  ( packComponentId exporter == "standard/taskjuggler"
  && packComponentVersion exporter == 1
  && packComponentKind exporter == ReadOnlyExporterComponent
  && packComponentExecutable exporter
  && packComponentStatus exporter == ComponentEnabled
  && null (packComponentCapabilities exporter)
  ) (Left TaskJugglerExporterUnavailable)

validatePayload :: ExportPayload -> Either PlanningError ()
validatePayload payload = do
  when (Text.null (Text.strip (exportPayloadMediaType payload)))
    (Left (InvalidExportPayload "media_type is empty"))
  unless (exportPayloadMediaType payload == "text/x-taskjuggler")
    (Left (InvalidExportPayload "TaskJuggler media_type is required"))
  when (Text.null (Text.strip (exportPayloadSuggestedFilename payload))
      || not (".tjp" `Text.isSuffixOf` exportPayloadSuggestedFilename payload))
    (Left (InvalidExportPayload "suggested_filename must end in .tjp"))
  when (Text.null (Text.strip (exportPayloadContentHash payload)))
    (Left (InvalidExportPayload "content_hash is empty"))
  when (exportPayloadSize payload <= 0)
    (Left (InvalidExportPayload "size must be positive"))

validateTaskJugglerOutput ::
  PlanningManifest -> PlanningProjection -> TaskJugglerExporterOutput ->
  Either PlanningError ()
validateTaskJugglerOutput manifest projection output = do
  unless (taskJugglerExporterOutputMediaType output
      == exportPayloadMediaType (planningManifestPayload manifest))
    (Left (InvalidTaskJugglerOutput "media type differs from the manifest"))
  unless (taskJugglerExporterOutputSuggestedFilename output
      == exportPayloadSuggestedFilename (planningManifestPayload manifest))
    (Left (InvalidTaskJugglerOutput "filename differs from the manifest"))
  when (Text.null (taskJugglerExporterOutputBytes output))
    (Left (InvalidTaskJugglerOutput "export bytes are empty"))
  let metadata = taskJugglerExporterOutputExportMetadata output
      expectedMacros = map planningItemMacro (planningProjectionItems projection)
  unless (taskJugglerExportMetadataExporterId metadata == "standard/taskjuggler"
      && taskJugglerExportMetadataProjectionVersion metadata
        == planningProjectionVersion projection
      && taskJugglerExportMetadataMacros metadata == expectedMacros
      && all (`Text.isInfixOf` taskJugglerExporterOutputBytes output) expectedMacros)
    (Left (InvalidTaskJugglerOutput "profile macros or projection pin differ"))

------------------------------------------------------------
-- Executable reference exporter
------------------------------------------------------------

taskJugglerExporterSource :: BS8.ByteString
taskJugglerExporterSource = BS8.pack $ Text.unpack $ Text.unlines
  [ "local lines = {'project little_ant \\\"Little Ant\\\" 2026-01-01 +1y'}"
  , "local macros = {}"
  , "local warnings = {'planning projection and effort profile are pinned by the manifest'}"
  , "for _, item in ipairs(input.projection.items) do"
  , "  local task_id = string.gsub(item.brick, '[^%w_]', '_')"
  , "  table.insert(lines, 'task ' .. task_id .. ' \\\"' .. item.title .. '\\\" { effort ' .. item.macro .. ' }')"
  , "  table.insert(macros, item.macro)"
  , "  for _, warning in ipairs(item.warnings) do table.insert(warnings, warning) end"
  , "end"
  , "return {"
  , "  bytes=table.concat(lines, '\\n'),"
  , "  media_type='text/x-taskjuggler',"
  , "  suggested_filename=input.suggested_filename,"
  , "  warnings=warnings,"
  , "  export_metadata={exporter_id='standard/taskjuggler', projection_version=input.projection.version, macros=macros}"
  , "}"
  ]

runTaskJugglerExporter ::
  PlanningProjection -> Text -> IO (Either PlanningError TaskJugglerExporterOutput)
runTaskJugglerExporter projection filename = do
  result <- runLuaComponent defaultSandboxLimits []
    (object ["projection" .= projection, "suggested_filename" .= filename])
    taskJugglerExporterSource
  pure $ do
    unless (packExecutionResultOk result)
      (Left (InvalidTaskJugglerOutput
        (maybe "runner failed" id (packExecutionResultErrorCode result))))
    value <- maybe (Left (InvalidTaskJugglerOutput "runner returned no output")) Right
      (packExecutionResultOutput result)
    output <- case fromJSON value of
      Success decoded -> Right decoded
      Error problem -> Left (InvalidTaskJugglerOutput (Text.pack problem))
    unless (taskJugglerExporterOutputMediaType output == "text/x-taskjuggler")
      (Left (InvalidTaskJugglerOutput "runner returned the wrong media type"))
    pure output

------------------------------------------------------------
-- Loopback UI adapter
------------------------------------------------------------

openLocalWebUi ::
  UTCTime -> Integer -> PackComponent -> PlanningState ->
  Either PlanningError (WebUiSession, PlanningState)
openLocalWebUi now port component state = do
  validateWebUiComponent component
  let ordinal = planningStateNextIdentity state
      identifier = identity "web-ui-session" ordinal
      session = WebUiSession identifier component "127.0.0.1" port
        WebSessionOpen now Nothing
      transition = WebUiTransition (identity "web-ui-transition" ordinal)
        identifier WebUiOpened Nothing now
      next = state
        { planningStateNextIdentity = ordinal + 1
        , planningStateWebSessions = Map.insert identifier session
            (planningStateWebSessions state)
        , planningStateWebTransitions = planningStateWebTransitions state
            <> [transition]
        }
  validatePlanningState next
  pure (session, next)

closeLocalWebUi ::
  UTCTime -> Text -> PlanningState ->
  Either PlanningError (WebUiSession, PlanningState)
closeLocalWebUi now identifier state = do
  session <- requireOpenSession identifier state
  let ordinal = planningStateNextIdentity state
      closed = session {webUiSessionStatus = WebSessionClosed,
        webUiSessionClosedAt = Just now}
      transition = WebUiTransition (identity "web-ui-transition" ordinal)
        identifier WebUiClosed Nothing now
      next = state
        { planningStateNextIdentity = ordinal + 1
        , planningStateWebSessions = Map.insert identifier closed
            (planningStateWebSessions state)
        , planningStateWebTransitions = planningStateWebTransitions state
            <> [transition]
        }
  validatePlanningState next
  pure (closed, next)

renderUiEnvelope ::
  Text -> InteractionEnvelope -> PlanningState ->
  Either PlanningError UiRenderedEnvelope
renderUiEnvelope sessionId envelope state = do
  _ <- requireOpenSession sessionId state
  pure (UiRenderedEnvelope "web" True envelope)

decodeUiInput :: InteractionEnvelope -> Value -> Either PlanningError UiForward
decodeUiInput envelope value = do
  fields <- case value of
    Object objectValue -> Right objectValue
    _ -> Left (InvalidUiAdapterOutput "decoded UI input must be an object")
  let expectedFields = Set.fromList (map Key.fromText
        ["interaction_id", "interaction_revision", "domain_revision", "action_id"])
  unless (Set.fromList (KeyMap.keys fields) == expectedFields)
    (Left (InvalidUiAdapterOutput "decoded UI input fields are not exact"))
  decoded <- case fromJSON value of
    Success forward -> Right forward
    Error problem -> Left (InvalidUiAdapterOutput (Text.pack problem))
  unless (uiForwardInteractionId decoded == interactionEnvelopeInteractionId envelope)
    (Left (UiEnvelopeMismatch "interaction identity"))
  unless (uiForwardInteractionRevision decoded
      == interactionEnvelopeInteractionRevision envelope)
    (Left (UiEnvelopeMismatch "interaction revision"))
  unless (uiForwardDomainRevision decoded == interactionEnvelopeDomainRevision envelope)
    (Left (UiEnvelopeMismatch "domain revision"))
  unless (any ((== uiForwardActionId decoded) . interactionActionId)
      (interactionEnvelopeActions envelope))
    (Left (UiActionNotAvailable (uiForwardActionId decoded)))
  pure decoded

forwardWebUiInput ::
  UTCTime -> Text -> UiForward -> PlanningState ->
  Either PlanningError PlanningState
forwardWebUiInput now sessionId forward state = do
  _ <- requireOpenSession sessionId state
  let ordinal = planningStateNextIdentity state
      transition = WebUiTransition (identity "web-ui-transition" ordinal)
        sessionId WebUiForwarded (Just forward) now
      next = state
        { planningStateNextIdentity = ordinal + 1
        , planningStateWebTransitions = planningStateWebTransitions state
            <> [transition]
        }
  validatePlanningState next
  pure next

validateWebUiComponent :: PackComponent -> Either PlanningError ()
validateWebUiComponent component = unless
  ( packComponentId component == "standard/web-metro"
  && packComponentVersion component == 1
  && packComponentKind component == UiAdapterComponent
  && packComponentExecutable component
  && packComponentStatus component == ComponentEnabled
  && null (packComponentCapabilities component)
  ) (Left WebUiComponentUnavailable)

requireOpenSession :: Text -> PlanningState -> Either PlanningError WebUiSession
requireOpenSession identifier state = do
  session <- maybe (Left (UnknownWebUiSession identifier)) Right
    (Map.lookup identifier (planningStateWebSessions state))
  unless (webUiSessionStatus session == WebSessionOpen)
    (Left (WebUiSessionNotOpen identifier))
  validateWebUiComponent (webUiSessionComponent session)
  pure session

metroWebUiSource :: BS8.ByteString
metroWebUiSource = BS8.pack $ Text.unpack $ Text.unlines
  [ "if input.operation == 'render' then"
  , "  return {channel='web', read_only=true, envelope=input.envelope}"
  , "elseif input.operation == 'decode' then"
  , "  return input.channel_input"
  , "else"
  , "  error('unsupported ui operation')"
  , "end"
  ]

runMetroWebUiRender ::
  InteractionEnvelope -> IO (Either PlanningError UiRenderedEnvelope)
runMetroWebUiRender envelope = do
  result <- runLuaComponent defaultSandboxLimits []
    (object ["operation" .= ("render" :: Text), "envelope" .= envelope])
    metroWebUiSource
  pure $ do
    output <- packOutput "render" result
    rendered <- case fromJSON output of
      Success decoded -> Right decoded
      Error problem -> Left (InvalidUiAdapterOutput (Text.pack problem))
    unless (uiRenderedEnvelopeChannel rendered == "web"
        && uiRenderedEnvelopeReadOnly rendered
        && uiRenderedEnvelopeEnvelope rendered == envelope)
      (Left (InvalidUiAdapterOutput "render changed the canonical envelope"))
    pure rendered

runMetroWebUiDecode ::
  InteractionEnvelope -> Value -> IO (Either PlanningError UiForward)
runMetroWebUiDecode envelope channelInput = do
  result <- runLuaComponent defaultSandboxLimits []
    (object
      [ "operation" .= ("decode" :: Text)
      , "channel_input" .= channelInput
      ]) metroWebUiSource
  pure $ packOutput "decode" result >>= decodeUiInput envelope

packOutput ::
  Text -> PackExecutionResult -> Either PlanningError Value
packOutput operation result = do
  unless (packExecutionResultOk result)
    (Left (InvalidUiAdapterOutput (operation <> " failed: "
      <> maybe "runner failure" id (packExecutionResultErrorCode result))))
  maybe (Left (InvalidUiAdapterOutput (operation <> " returned no output"))) Right
    (packExecutionResultOutput result)

------------------------------------------------------------
-- Artifact validation
------------------------------------------------------------

validatePlanningState :: PlanningState -> Either PlanningError ()
validatePlanningState state = do
  mapM_ validateManifestEntry (Map.toList (planningStateManifests state))
  mapM_ validateExportEntry (Map.toList (planningStateExports state))
  unless (Map.keysSet (planningStateManifests state)
      == Map.keysSet (planningStateExports state))
    (Left (InvalidPlanningState "manifest/export key sets differ"))
  mapM_ validateActualEntry (Map.toList (planningStateActuals state))
  let actualPairs = [(importedActualManifest actual, importedActualBrick actual)
        | actual <- Map.elems (planningStateActuals state)]
  unless (length actualPairs == length (nub actualPairs))
    (Left (InvalidPlanningState "duplicate actual for manifest and Brick"))
  mapM_ validateSessionEntry (Map.toList (planningStateWebSessions state))
  mapM_ validateTransition (planningStateWebTransitions state)
  where
    validateManifestEntry (key, manifest) = do
      unless (key == planningManifestId manifest)
        (Left (InvalidPlanningState "manifest map key differs from identity"))
      validateExporter (planningManifestExporter manifest)
      validatePayload (planningManifestPayload manifest)
      unless (planningManifestContentHash manifest
          == exportPayloadContentHash (planningManifestPayload manifest))
        (Left (InvalidPlanningState "manifest content hash is not pinned"))
    validateExportEntry (key, planningExport) = do
      unless (key == planningExportManifest planningExport)
        (Left (InvalidPlanningState "export map key differs from manifest"))
      manifest <- maybe (Left (InvalidPlanningState "export has no manifest")) Right
        (Map.lookup key (planningStateManifests state))
      let projection = planningExportProjection planningExport
          selected = planningManifestSelectedBricks manifest
          items = planningProjectionItems projection
      unless (planningProjectionDatasetRevision projection
          == planningManifestDatasetRevision manifest
          && planningProjectionEffortProfile projection
            == planningManifestEffortProfile manifest
          && map planningItemBrick items == selected)
        (Left (InvalidPlanningState "projection differs from manifest pins"))
      let overlap = any (\item -> any (`elem` planningItemAncestors item) selected)
            items
      when overlap (Left (InvalidPlanningState "stored planning cut overlaps"))
      case planningExportOutput planningExport of
        Nothing -> pure ()
        Just output -> validateTaskJugglerOutput manifest projection output
    validateActualEntry (key, actual) = do
      unless (key == importedActualId actual)
        (Left (InvalidPlanningState "actual map key differs from identity"))
      manifest <- maybe (Left (InvalidPlanningState "actual has no manifest")) Right
        (Map.lookup (importedActualManifest actual) (planningStateManifests state))
      unless (importedActualBrick actual `elem` planningManifestSelectedBricks manifest)
        (Left (InvalidPlanningState "actual Brick is outside manifest"))
      let hours = importedActualObservedHours actual
      when (hours < 0 || isNaN hours || isInfinite hours)
        (Left (InvalidPlanningState "actual hours are invalid"))
    validateSessionEntry (key, session) = do
      unless (key == webUiSessionId session)
        (Left (InvalidPlanningState "web session map key differs from identity"))
      validateWebUiComponent (webUiSessionComponent session)
      unless (webUiSessionBindHost session == "127.0.0.1")
        (Left (InvalidPlanningState "web UI is not bound to loopback"))
      unless ((webUiSessionStatus session == WebSessionClosed)
          == isJust (webUiSessionClosedAt session))
        (Left (InvalidPlanningState "web close status and timestamp differ"))
    validateTransition transition = do
      unless (Map.member (webUiTransitionSession transition)
          (planningStateWebSessions state))
        (Left (InvalidPlanningState "web transition has no session"))
      unless ((webUiTransitionKind transition == WebUiForwarded)
          == isJust (webUiTransitionForward transition))
        (Left (InvalidPlanningState "web forward evidence shape is invalid"))

identity :: Text -> Integer -> Text
identity prefix ordinal = "la1_" <> prefix <> "_" <> Text.pack (show ordinal)

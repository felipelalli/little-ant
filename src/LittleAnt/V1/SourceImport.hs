{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

-- | Canonical source-import, synchronization, and reviewed cleanup workflows.
--
-- Adapters contribute only normalized 'ImportCandidate' evidence.  This pure
-- module owns stable external identity, routing, run checkpoints, and approved
-- source effects; provider IO remains outside the deterministic core.
module LittleAnt.V1.SourceImport
  ( ExternalRecord (..)
  , ImportCandidate (..)
  , ImportError (..)
  , ImportProfile (..)
  , ImportProfileStatus (..)
  , ImportRoute (..)
  , ImportRun (..)
  , ImportRunMode (..)
  , ImportRunStatus (..)
  , SourceEffect (..)
  , SourceEffectKind (..)
  , SourceEffectStatus (..)
  , SourceImportState (..)
  , acceptImportCandidate
  , applySourceEffect
  , approveSourceEffect
  , authorizeApprovedSourceEffect
  , completeSynchronization
  , createImportProfile
  , cutOverImport
  , declineSourceEffect
  , emptySourceImportState
  , failImportRun
  , failSourceEffect
  , finishImportCapture
  , importProfileProjection
  , importRunProjection
  , microsoftTodoAdapterV1
  , observeExternalCompletion
  , planEraseAfterImport
  , planImport
  , prepareVerifiedMigration
  , proposeEmptyContainerDeletion
  , reconcileAdapterCandidates
  , retireImportProfile
  , retrySourceEffect
  , sourceEffectProjection
  , sourceEffectsForRunProjection
  , sourceRecordProjection
  , startImport
  , validateImportCandidate
  , validateSourceImportState
  , verifyImport
  ) where

import Control.Monad (filterM, unless, when)
import Data.Aeson
  (FromJSON (parseJSON), Options (..), ToJSON (toJSON), Value (..), camelTo2,
   defaultOptions, genericParseJSON, genericToJSON, object, withText, (.=))
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy as LBS
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.List (find, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (catMaybes, fromMaybe, isJust)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import qualified LittleAnt.V1.Coordination as Coordination
import qualified LittleAnt.V1.Domain as Domain
import qualified LittleAnt.V1.Execution as Execution
import LittleAnt.V1.Integration
  (ComponentStatus (..), PackComponent (..), PackComponentKind (..))
import qualified LittleAnt.V1.Material as Material
import qualified LittleAnt.V1.Priority as Priority
import qualified LittleAnt.V1.Selection as Selection
import qualified LittleAnt.V1.Standing as Standing

------------------------------------------------------------
-- Closed vocabulary and normalized adapter evidence
------------------------------------------------------------

data ImportProfileStatus = ImportProfileActive | ImportProfileRetired
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ImportRoute = PreserveRaw | AdoptBrick | AdoptListEntry
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ImportRunMode = Synchronize | Migrate
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ImportRunStatus
  = ImportPlanned
  | ImportRunning
  | ImportCaptured
  | ImportVerifiedStatus
  | ImportCompleted
  | ImportCutOver
  | ImportFailed
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data SourceEffectKind = EraseObject | EraseContainer | WriteBack
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data SourceEffectStatus
  = EffectProposed
  | EffectApproved
  | EffectApplied
  | EffectDeclined
  | EffectFailed
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ImportCandidate = ImportCandidate
  { importCandidateProvider :: Text
  , importCandidateAccount :: Text
  , importCandidateExternalId :: Text
  , importCandidateContainerId :: Maybe Text
  , importCandidateKind :: Text
  , importCandidateOriginalTitle :: Maybe Text
  , importCandidateCanonicalEnglish :: Maybe Text
  , importCandidateNormalizationAuthority :: Maybe Domain.Authority
  , importCandidateBody :: Maybe Text
  , importCandidateContentHash :: Text
  , importCandidateRevision :: Maybe Text
  , importCandidatePresence :: Material.ExternalPresence
  , importCandidateWorkState :: Material.ExternalWorkState
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON ImportProfileStatus where toJSON = enumJSON importProfileStatusText
instance FromJSON ImportProfileStatus where
  parseJSON = parseEnum "ImportProfileStatus" importProfileStatusText
instance ToJSON ImportRoute where toJSON = enumJSON importRouteText
instance FromJSON ImportRoute where parseJSON = parseEnum "ImportRoute" importRouteText
instance ToJSON ImportRunMode where toJSON = enumJSON importRunModeText
instance FromJSON ImportRunMode where
  parseJSON = parseEnum "ImportRunMode" importRunModeText
instance ToJSON ImportRunStatus where toJSON = enumJSON importRunStatusText
instance FromJSON ImportRunStatus where
  parseJSON = parseEnum "ImportRunStatus" importRunStatusText
instance ToJSON SourceEffectKind where toJSON = enumJSON sourceEffectKindText
instance FromJSON SourceEffectKind where
  parseJSON = parseEnum "SourceEffectKind" sourceEffectKindText
instance ToJSON SourceEffectStatus where toJSON = enumJSON sourceEffectStatusText
instance FromJSON SourceEffectStatus where
  parseJSON = parseEnum "SourceEffectStatus" sourceEffectStatusText
instance ToJSON ImportCandidate where
  toJSON = genericToJSON (recordOptions "importCandidate")
instance FromJSON ImportCandidate where
  parseJSON = genericParseJSON (recordOptions "importCandidate")

enumJSON :: (value -> Text) -> value -> Value
enumJSON render = String . render

parseEnum :: (Bounded value, Enum value) =>
  String -> (value -> Text) -> Value -> AesonTypes.Parser value
parseEnum name render = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate [(render value, value) | value <- [minBound .. maxBound]])

importProfileStatusText :: ImportProfileStatus -> Text
importProfileStatusText = \case
  ImportProfileActive -> "active"
  ImportProfileRetired -> "retired"

importRouteText :: ImportRoute -> Text
importRouteText = \case
  PreserveRaw -> "preserve_raw"
  AdoptBrick -> "adopt_brick"
  AdoptListEntry -> "adopt_list_entry"

importRunModeText :: ImportRunMode -> Text
importRunModeText = \case
  Synchronize -> "synchronize"
  Migrate -> "migrate"

importRunStatusText :: ImportRunStatus -> Text
importRunStatusText = \case
  ImportPlanned -> "planned"
  ImportRunning -> "running"
  ImportCaptured -> "captured"
  ImportVerifiedStatus -> "verified"
  ImportCompleted -> "completed"
  ImportCutOver -> "cut_over"
  ImportFailed -> "failed"

sourceEffectKindText :: SourceEffectKind -> Text
sourceEffectKindText = \case
  EraseObject -> "erase_object"
  EraseContainer -> "erase_container"
  WriteBack -> "write_back"

sourceEffectStatusText :: SourceEffectStatus -> Text
sourceEffectStatusText = \case
  EffectProposed -> "proposed"
  EffectApproved -> "approved"
  EffectApplied -> "applied"
  EffectDeclined -> "declined"
  EffectFailed -> "failed"

------------------------------------------------------------
-- Canonical entities
------------------------------------------------------------

data ImportProfile = ImportProfile
  { importProfileId :: Text
  , importProfileVersion :: Integer
  , importProfileName :: Text
  , importProfileAdapter :: PackComponent
  , importProfileSourceScope :: Text
  , importProfileCandidateKind :: Text
  , importProfileRoute :: ImportRoute
  , importProfileDestinationParent :: Maybe Domain.BrickId
  , importProfileDestinationOwner :: Maybe Domain.BrickId
  , importProfileDestinationShelf :: Maybe Material.RawShelfId
  , importProfileAutomaticAdoption :: Bool
  , importProfileStatus :: ImportProfileStatus
  , importProfileCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data ExternalRecord = ExternalRecord
  { externalRecordId :: Text
  , externalRecordProfile :: Text
  , externalRecordProvider :: Text
  , externalRecordAccount :: Text
  , externalRecordExternalId :: Text
  , externalRecordContainerId :: Maybe Text
  , externalRecordRaw :: Material.RawId
  , externalRecordBrick :: Maybe Domain.BrickId
  , externalRecordEntry :: Maybe Domain.ListEntryId
  , externalRecordPresence :: Material.ExternalPresence
  , externalRecordWorkState :: Material.ExternalWorkState
  , externalRecordLastRevision :: Maybe Text
  , externalRecordLastObservedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data ImportRun = ImportRun
  { importRunId :: Text
  , importRunProfile :: Text
  , importRunMode :: ImportRunMode
  , importRunStatus :: ImportRunStatus
  , importRunEraseAfterImport :: Bool
  , importRunStartedAt :: UTCTime
  , importRunFinishedAt :: Maybe UTCTime
  , importRunSourceCursor :: Maybe Text
  , importRunCapturedCount :: Integer
  , importRunVerifiedCount :: Integer
  , importRunFailureCount :: Integer
  , importRunReceiptHash :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data SourceEffect = SourceEffect
  { sourceEffectId :: Text
  , sourceEffectRun :: Maybe Text
  , sourceEffectRecord :: Maybe Text
  , sourceEffectKind :: SourceEffectKind
  , sourceEffectPreview :: Text
  , sourceEffectStatus :: SourceEffectStatus
  , sourceEffectProposedAt :: UTCTime
  , sourceEffectApprovedAt :: Maybe UTCTime
  , sourceEffectAppliedAt :: Maybe UTCTime
  , sourceEffectReceipt :: Maybe Text
  , sourceEffectFailure :: Maybe Text
  , sourceEffectTargetRevision :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data SourceImportState = SourceImportState
  { sourceImportNextIdentity :: Integer
  , sourceImportProfiles :: Map Text ImportProfile
  , sourceImportRecords :: Map Text ExternalRecord
  , sourceImportRuns :: Map Text ImportRun
  , sourceImportEffects :: Map Text SourceEffect
  , sourceImportCompletionReviews :: Set Domain.BrickId
  , sourceImportUnresolvedConflicts :: Set Text
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON ImportProfile where
  toJSON = genericToJSON (recordOptions "importProfile")
instance FromJSON ImportProfile where
  parseJSON = genericParseJSON (recordOptions "importProfile")
instance ToJSON ExternalRecord where
  toJSON = genericToJSON (recordOptions "externalRecord")
instance FromJSON ExternalRecord where
  parseJSON = genericParseJSON (recordOptions "externalRecord")
instance ToJSON ImportRun where toJSON = genericToJSON (recordOptions "importRun")
instance FromJSON ImportRun where parseJSON = genericParseJSON (recordOptions "importRun")
instance ToJSON SourceEffect where
  toJSON = genericToJSON (recordOptions "sourceEffect")
instance FromJSON SourceEffect where
  parseJSON = genericParseJSON (recordOptions "sourceEffect")
instance ToJSON SourceImportState where
  toJSON = genericToJSON (recordOptions "sourceImport")
instance FromJSON SourceImportState where
  parseJSON = genericParseJSON (recordOptions "sourceImport")

recordOptions :: String -> Options
recordOptions prefix = defaultOptions
  {fieldLabelModifier = camelTo2 '_' . drop (length prefix)}

emptySourceImportState :: SourceImportState
emptySourceImportState = SourceImportState 1 Map.empty Map.empty Map.empty
  Map.empty Set.empty Set.empty

-- | Offline standard component used by the shipped profile and scenario.
microsoftTodoAdapterV1 :: PackComponent
microsoftTodoAdapterV1 = PackComponent
  { packComponentId = "standard/microsoft-todo"
  , packComponentVersion = 1
  , packComponentPackId = "little-ant/standard"
  , packComponentPackVersion = 1
  , packComponentKind = SourceAdapterComponent
  , packComponentExecutable = True
  , packComponentStatus = ComponentEnabled
  , packComponentCapabilities =
      [ "http:microsoft-graph"
      , "credential:microsoft-todo"
      , "effect:erase-object"
      , "effect:erase-container"
      ]
  }

------------------------------------------------------------
-- Errors and profile lifecycle
------------------------------------------------------------

data ImportError
  = InvalidImportText Text
  | InvalidImportAdapter Text
  | InvalidImportDestination Text
  | InvalidImportCandidate Text
  | UnknownImportProfile Text
  | UnknownExternalRecord Text
  | UnknownImportRun Text
  | UnknownSourceEffect Text
  | InvalidImportProfileTransition ImportProfileStatus
  | InvalidImportRunTransition ImportRunStatus
  | InvalidSourceEffectTransition SourceEffectStatus
  | DuplicateExternalIdentity Text
  | MigrationCleanupNotAllowed
  | ImportVerificationIncomplete
  | ImportDispositionIncomplete Text
  | ImportCleanupUnresolved
  | SourceEffectTargetChanged
  | SourceEffectCapabilityMissing Text
  | SourceImportMaterialError Material.MaterialError
  | SourceImportStandingError Standing.StandingError
  | SourceImportPriorityError Priority.PriorityError
  | SourceImportSelectionError Selection.SelectionError
  | SourceImportInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

createImportProfile ::
  UTCTime -> Text -> PackComponent -> Text -> Text -> ImportRoute ->
  Maybe Domain.BrickId -> Maybe Domain.BrickId -> Maybe Material.RawShelfId ->
  Bool -> Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError (ImportProfile, SourceImportState)
createImportProfile now name adapter sourceScope candidateKind route parent owner shelf
    automatic standing material state = do
  requireText "profile name" name
  requireText "source scope" sourceScope
  requireText "candidate kind" candidateKind
  unless (packComponentKind adapter == SourceAdapterComponent)
    (Left (InvalidImportAdapter "profile component is not a source adapter"))
  unless (packComponentStatus adapter == ComponentEnabled)
    (Left (InvalidImportAdapter "profile source adapter is not enabled"))
  validateDestination route parent owner shelf standing material
  let identifier = importIdentity "profile" (sourceImportNextIdentity state)
      profile = ImportProfile identifier 1 name adapter sourceScope candidateKind route
        parent owner shelf automatic ImportProfileActive now
      next = state
        { sourceImportNextIdentity = sourceImportNextIdentity state + 1
        , sourceImportProfiles = Map.insert identifier profile
            (sourceImportProfiles state)
        }
  validateAndReturn standing material profile next

validateDestination ::
  ImportRoute -> Maybe Domain.BrickId -> Maybe Domain.BrickId ->
  Maybe Material.RawShelfId -> Standing.StandingState -> Material.MaterialState ->
  Either ImportError ()
validateDestination route parent owner shelf standing material = case route of
  PreserveRaw -> do
    unless (parent == Nothing && owner == Nothing)
      (Left (InvalidImportDestination
        "preserve_raw accepts only its optional semantic Raw shelf"))
    mapM_ requireShelf shelf
  AdoptBrick -> do
    unless (owner == Nothing && shelf == Nothing)
      (Left (InvalidImportDestination
        "adopt_brick accepts a parent or the canonical root, not owner/shelf"))
    mapM_ (requireActiveBrick False) parent
  AdoptListEntry -> do
    unless (parent == Nothing && shelf == Nothing)
      (Left (InvalidImportDestination
        "adopt_list_entry accepts exactly one ListEntry-owning destination"))
    destination <- maybe
      (Left (InvalidImportDestination "adopt_list_entry requires destination_owner"))
      Right owner
    requireActiveBrick True destination
  where
    domain = standingDomain standing
    requireShelf identifier = unless
      (Map.member identifier (Material.materialShelves material))
      (Left (InvalidImportDestination "destination Raw shelf does not exist"))
    requireActiveBrick ownsEntries identifier = do
      brick <- maybe
        (Left (InvalidImportDestination "destination Brick does not exist")) Right
        (Map.lookup identifier (Domain.domainBricks domain))
      unless (Domain.brickStatus brick == Domain.Active)
        (Left (InvalidImportDestination "destination Brick is terminal"))
      when (ownsEntries && not (Domain.behaviorOwnsEntries
          (Domain.brickBehavior brick)))
        (Left (InvalidImportDestination
          "destination owner behavior does not own ListEntries"))

retireImportProfile ::
  Text -> Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError (ImportProfile, Material.MaterialState, SourceImportState)
retireImportProfile identifier standing material state = do
  profile <- requireProfile identifier state
  unless (importProfileStatus profile == ImportProfileActive)
    (Left (InvalidImportProfileTransition (importProfileStatus profile)))
  let retired = profile {importProfileStatus = ImportProfileRetired}
      rawIds = Set.fromList
        [ externalRecordRaw record
        | record <- Map.elems (sourceImportRecords state)
        , externalRecordProfile record == identifier
        ]
      retire origin = if Material.rawOriginRaw origin `Set.member` rawIds
        then origin {Material.rawOriginHistoricalOnly = True} else origin
      nextMaterial = material
        {Material.materialOrigins = Map.map retire (Material.materialOrigins material)}
      next = state {sourceImportProfiles = Map.insert identifier retired
        (sourceImportProfiles state)}
  validateSourceImportState standing nextMaterial next
  pure (retired, nextMaterial, next)

------------------------------------------------------------
-- Runs, capture, and synchronization
------------------------------------------------------------

planImport ::
  UTCTime -> Text -> ImportRunMode -> Bool -> Standing.StandingState ->
  Material.MaterialState -> SourceImportState ->
  Either ImportError (ImportRun, SourceImportState)
planImport now profileId mode erase standing material state = do
  profile <- requireProfile profileId state
  unless (importProfileStatus profile == ImportProfileActive)
    (Left (InvalidImportProfileTransition (importProfileStatus profile)))
  when (erase && mode /= Migrate) (Left MigrationCleanupNotAllowed)
  let identifier = importIdentity "run" (sourceImportNextIdentity state)
      run = ImportRun identifier profileId mode ImportPlanned erase now Nothing
        Nothing 0 0 0 Nothing
      next = state
        { sourceImportNextIdentity = sourceImportNextIdentity state + 1
        , sourceImportRuns = Map.insert identifier run (sourceImportRuns state)
        }
  validateAndReturn standing material run next

startImport ::
  Text -> Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError (ImportRun, SourceImportState)
startImport identifier = transitionRun identifier ImportPlanned ImportRunning

finishImportCapture ::
  Text -> Maybe Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (ImportRun, SourceImportState)
finishImportCapture identifier cursor standing material state = do
  run <- requireRun identifier state
  unless (importRunStatus run == ImportRunning)
    (Left (InvalidImportRunTransition (importRunStatus run)))
  let captured = run
        {importRunStatus = ImportCaptured, importRunSourceCursor = cursor}
      next = replaceRun captured state
  validateAndReturn standing material captured next

verifyImport ::
  UTCTime -> Text -> Integer -> Integer -> Standing.StandingState ->
  Material.MaterialState -> SourceImportState ->
  Either ImportError (ImportRun, SourceImportState)
verifyImport now identifier verifiedCount failureCount standing material state = do
  run <- requireRun identifier state
  unless (importRunStatus run == ImportCaptured)
    (Left (InvalidImportRunTransition (importRunStatus run)))
  if verifiedCount /= importRunCapturedCount run || failureCount > 0
    then do
      let failed = run
            { importRunStatus = ImportFailed
            , importRunFinishedAt = Just now
            , importRunVerifiedCount = verifiedCount
            , importRunFailureCount = failureCount
            }
          next = replaceRun failed state
      validateAndReturn standing material failed next
    else do
      when (importRunMode run == Migrate
          && not (migrationScopeReviewed run material state))
        (Left ImportVerificationIncomplete)
      let verified = run
            { importRunStatus = ImportVerifiedStatus
            , importRunVerifiedCount = verifiedCount
            , importRunFailureCount = 0
            }
          next = replaceRun verified state
      validateAndReturn standing material verified next

failImportRun ::
  UTCTime -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (ImportRun, SourceImportState)
failImportRun now identifier standing material state = do
  run <- requireRun identifier state
  unless (importRunStatus run `elem`
      [ImportPlanned, ImportRunning, ImportVerifiedStatus])
    (Left (InvalidImportRunTransition (importRunStatus run)))
  let failed = run
        { importRunStatus = ImportFailed
        , importRunFinishedAt = Just now
        , importRunFailureCount = importRunFailureCount run + 1
        }
      next = replaceRun failed state
  validateAndReturn standing material failed next

completeSynchronization ::
  UTCTime -> Text -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (ImportRun, SourceImportState)
completeSynchronization now identifier receipt standing material state = do
  run <- requireRun identifier state
  requireText "synchronization receipt" receipt
  unless (importRunMode run == Synchronize
      && importRunStatus run == ImportVerifiedStatus)
    (Left (InvalidImportRunTransition (importRunStatus run)))
  let completed = run
        { importRunStatus = ImportCompleted
        , importRunFinishedAt = Just now
        , importRunReceiptHash = Just receipt
        }
      next = replaceRun completed state
  profile <- requireProfile (importRunProfile run) next
  unless (importProfileStatus profile == ImportProfileActive)
    (Left (InvalidImportProfileTransition (importProfileStatus profile)))
  validateAndReturn standing material completed next

transitionRun ::
  Text -> ImportRunStatus -> ImportRunStatus -> Standing.StandingState ->
  Material.MaterialState -> SourceImportState ->
  Either ImportError (ImportRun, SourceImportState)
transitionRun identifier expected target standing material state = do
  run <- requireRun identifier state
  unless (importRunStatus run == expected)
    (Left (InvalidImportRunTransition (importRunStatus run)))
  let changed = run {importRunStatus = target}
      next = replaceRun changed state
  validateAndReturn standing material changed next

-- | Execute one real planned -> running -> captured -> verified migration over
-- already captured profile records.  The contract fixture uses this operation
-- rather than manufacturing a verified state.
prepareVerifiedMigration ::
  UTCTime -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (ImportRun, SourceImportState)
prepareVerifiedMigration now identifier standing material state = do
  (running, first) <- startImport identifier standing material state
  let count = fromIntegral (length (recordsForProfile
        (importRunProfile running) first))
      withCount = replaceRun (running {importRunCapturedCount = count}) first
  (_, capturedState) <- finishImportCapture identifier Nothing standing material withCount
  verifyImport now identifier count 0 standing material capturedState

validateImportCandidate :: ImportCandidate -> Either ImportError ImportCandidate
validateImportCandidate candidate = do
  mapM_ (uncurry requireText)
    [ ("candidate provider", importCandidateProvider candidate)
    , ("candidate account", importCandidateAccount candidate)
    , ("candidate external identity", importCandidateExternalId candidate)
    , ("candidate kind", importCandidateKind candidate)
    , ("candidate content hash", importCandidateContentHash candidate)
    ]
  unless (isJust (importCandidateCanonicalEnglish candidate)
      == isJust (importCandidateNormalizationAuthority candidate))
    (Left (InvalidImportCandidate
      "canonical_english and normalization_authority must appear together"))
  mapM_ (\title -> unless (Domain.canonicalEnglishText title)
      (Left (InvalidImportCandidate "canonical English is invalid")))
    (importCandidateCanonicalEnglish candidate)
  pure candidate

-- | Validate a complete adapter page before the caller captures any item.
-- Omission from the page produces no synthetic removed record.
reconcileAdapterCandidates ::
  [ImportCandidate] -> Either ImportError [ImportCandidate]
reconcileAdapterCandidates candidates = do
  checked <- mapM validateImportCandidate candidates
  let identities = map candidateExternalKey checked
  unless (length identities == Set.size (Set.fromList identities))
    (Left (InvalidImportCandidate "adapter page repeats an external identity"))
  pure checked

acceptImportCandidate ::
  UTCTime -> Text -> ImportCandidate -> Standing.StandingState ->
  Material.MaterialState -> SourceImportState ->
  Either ImportError
    (ExternalRecord, Maybe Domain.Brick, Maybe Domain.ListEntry,
     Standing.StandingState, Material.MaterialState, SourceImportState)
acceptImportCandidate now runId unvalidated standing material state = do
  candidate <- validateImportCandidate unvalidated
  run <- requireRun runId state
  unless (importRunStatus run == ImportRunning)
    (Left (InvalidImportRunTransition (importRunStatus run)))
  profile <- requireProfile (importRunProfile run) state
  case findRecord profile candidate state of
    Just existing -> reconcileExisting now run existing candidate standing material state
    Nothing -> captureNew now run profile candidate standing material state

captureNew ::
  UTCTime -> ImportRun -> ImportProfile -> ImportCandidate -> Standing.StandingState ->
  Material.MaterialState -> SourceImportState ->
  Either ImportError
    (ExternalRecord, Maybe Domain.Brick, Maybe Domain.ListEntry,
     Standing.StandingState, Material.MaterialState, SourceImportState)
captureNew now run profile candidate standing material state = do
  let title = importCandidateCanonicalEnglish candidate
        <|> importCandidateOriginalTitle candidate
      locator = importLocator candidate
  ((raw0, origin), capturedMaterial) <- mapMaterial
    (Material.captureExternalRaw title (packComponentId (importProfileAdapter profile))
      locator (Just (importCandidateExternalId candidate)) now material)
  let raw = raw0
        { Material.rawTitle = title
        , Material.rawOriginalText = candidateVerbatim candidate
        , Material.rawCanonicalEnglish = importCandidateCanonicalEnglish candidate
        , Material.rawNormalizationAuthority =
            importCandidateNormalizationAuthority candidate
        }
      materialWithText = capturedMaterial
        {Material.materialRaws = Map.insert (Material.rawId raw) raw
          (Material.materialRaws capturedMaterial)}
  (snapshotResult, withSnapshot) <- mapMaterial (Material.captureRawSnapshot
    (Material.rawId raw) (importCandidateContentHash candidate)
    (candidateSize candidate) "application/json" (importCandidateRevision candidate)
    now materialWithText)
  snapshot <- case snapshotResult of
    Material.SnapshotCreated value -> Right value
    Material.SnapshotReused _ -> Left (InvalidImportCandidate
      "new external identity unexpectedly reused an existing snapshot")
  (_, observedMaterial) <- mapMaterial (Material.recordSourceObservation
    (Material.rawOriginId origin) Domain.Adapter (Just (importCandidateExternalId candidate))
    (importCandidateRevision candidate) (importCandidatePresence candidate)
    (importCandidateWorkState candidate) Nothing now withSnapshot)
  (brick, entry, routedStanding, routedMaterial) <- routeNewCandidate now profile
    candidate raw snapshot standing observedMaterial
  withShelf <- case importProfileDestinationShelf profile of
    Nothing -> Right routedMaterial
    Just shelf -> snd <$> mapMaterial (Material.addRawToShelf
      (Material.rawId raw) shelf now routedMaterial)
  let recordId = stableExternalRecordId profile candidate
      record = ExternalRecord
        { externalRecordId = recordId
        , externalRecordProfile = importProfileId profile
        , externalRecordProvider = importCandidateProvider candidate
        , externalRecordAccount = importCandidateAccount candidate
        , externalRecordExternalId = importCandidateExternalId candidate
        , externalRecordContainerId = importCandidateContainerId candidate
        , externalRecordRaw = Material.rawId raw
        , externalRecordBrick = Domain.brickId <$> brick
        , externalRecordEntry = Domain.listEntryId <$> entry
        , externalRecordPresence = importCandidatePresence candidate
        , externalRecordWorkState = importCandidateWorkState candidate
        , externalRecordLastRevision = importCandidateRevision candidate
        , externalRecordLastObservedAt = now
        }
      changedRun = run {importRunCapturedCount = importRunCapturedCount run + 1}
      next = state
        { sourceImportRecords = Map.insert recordId record (sourceImportRecords state)
        , sourceImportRuns = Map.insert (importRunId run) changedRun
            (sourceImportRuns state)
        }
  validateSourceImportState routedStanding withShelf next
  pure (record, brick, entry, routedStanding, withShelf, next)

routeNewCandidate ::
  UTCTime -> ImportProfile -> ImportCandidate -> Material.Raw ->
  Material.RawSnapshot -> Standing.StandingState -> Material.MaterialState ->
  Either ImportError
    (Maybe Domain.Brick, Maybe Domain.ListEntry,
     Standing.StandingState, Material.MaterialState)
routeNewCandidate now profile candidate raw snapshot standing material
  | not (shouldAutomaticallyAdopt profile candidate) =
      Right (Nothing, Nothing, standing, material)
  | importProfileRoute profile == AdoptBrick = do
      canonical <- requireCanonical candidate
      title <- mapDomain (Domain.mkCanonicalText canonical
        (importCandidateOriginalTitle candidate)
        (fromMaybe Domain.Adapter (importCandidateNormalizationAuthority candidate)))
      let draft = (Domain.ordinaryBrickDraft title Domain.standardV1 now)
            { Domain.brickDraftDescription = importCandidateBody candidate
            , Domain.brickDraftParent = importProfileDestinationParent profile
            }
      (brick, insertion, createdStanding) <- mapStanding
        (Standing.createStandingBrick draft (importCandidateExternalId candidate)
          now standing)
      positionedStanding <- deferImportedInsertion insertion now createdStanding
      let registered = Material.registerMaterialBrick
            (Domain.brickId brick) Domain.Active material
      (link, linked) <- mapMaterial (Material.linkRawToBrick
        (Material.rawId raw) (Domain.brickId brick) Material.Source
        (Just (Material.rawSnapshotId snapshot)) now registered)
      (_, reviewed) <- mapMaterial (Material.reviewRaw (Material.rawId raw)
        Material.ProducedWork (Just (Domain.brickId brick))
        (fromMaybe Domain.Adapter (importCandidateNormalizationAuthority candidate))
        Nothing now linked)
      unless (Material.rawLinkReconciledSnapshot link
          == Just (Material.rawSnapshotId snapshot))
        (Left (SourceImportInvariantViolation
          ["imported Brick source link omitted its snapshot baseline"]))
      pure (Just brick, Nothing, positionedStanding, reviewed)
  | importProfileRoute profile == AdoptListEntry = do
      owner <- maybe
        (Left (InvalidImportDestination "ListEntry profile lost its owner")) Right
        (importProfileDestinationOwner profile)
      canonical <- requireCanonical candidate
      label <- mapDomain (Domain.mkCanonicalText canonical
        (importCandidateOriginalTitle candidate)
        (fromMaybe Domain.Adapter (importCandidateNormalizationAuthority candidate)))
      let draft = Domain.ListEntryDraft owner label Nothing
            (importCandidateBody candidate) now
      (entry, nextStanding) <- mapStanding
        (Standing.addStandingListEntry draft standing)
      let registered = Material.registerMaterialListEntry (Domain.listEntryId entry)
            (Material.registerMaterialBrick owner Domain.Active material)
      (link, linked) <- mapMaterial (Material.linkRawToEntry
        (Material.rawId raw) (Domain.listEntryId entry) Material.Source now registered)
      (_, reconciled) <- mapMaterial (Material.reconcileRawLink
        (Material.rawLinkId link) (Material.rawSnapshotId snapshot) linked)
      (_, reviewed) <- mapMaterial (Material.reviewRaw (Material.rawId raw)
        Material.ProducedWork (Just owner)
        (fromMaybe Domain.Adapter (importCandidateNormalizationAuthority candidate))
        Nothing now reconciled)
      pure (Nothing, Just entry, nextStanding, reviewed)
  | otherwise = Right (Nothing, Nothing, standing, material)

shouldAutomaticallyAdopt :: ImportProfile -> ImportCandidate -> Bool
shouldAutomaticallyAdopt profile candidate =
  importProfileAutomaticAdoption profile
  && isJust (importCandidateCanonicalEnglish candidate)
  && isJust (importCandidateNormalizationAuthority candidate)
  && case importProfileRoute profile of
    AdoptBrick -> importCandidateKind candidate == "structured_task"
    AdoptListEntry -> importCandidateKind candidate `elem`
      ["structured_task", "list_item"]
    PreserveRaw -> False

reconcileExisting ::
  UTCTime -> ImportRun -> ExternalRecord -> ImportCandidate ->
  Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError
    (ExternalRecord, Maybe Domain.Brick, Maybe Domain.ListEntry,
     Standing.StandingState, Material.MaterialState, SourceImportState)
reconcileExisting now run record candidate standing material state = do
  origin <- maybe
    (Left (SourceImportInvariantViolation ["ExternalRecord Raw has no origin"])) Right
    (find ((== externalRecordRaw record) . Material.rawOriginRaw)
      (Map.elems (Material.materialOrigins material)))
  latest <- mapMaterial (Material.rawLatestSnapshot material
    (externalRecordRaw record))
  materialWithSnapshot <- case latest of
    Just snapshot | Material.rawSnapshotContentHash snapshot
        == importCandidateContentHash candidate -> Right material
    _ -> snd <$> mapMaterial (Material.captureRawSnapshot
      (externalRecordRaw record) (importCandidateContentHash candidate)
      (candidateSize candidate) "application/json" (importCandidateRevision candidate)
      now material)
  (_, observed) <- mapMaterial (Material.recordSourceObservation
    (Material.rawOriginId origin) Domain.Adapter
    (Just (importCandidateExternalId candidate)) (importCandidateRevision candidate)
    (importCandidatePresence candidate) (importCandidateWorkState candidate)
    Nothing now materialWithSnapshot)
  let changed = record
        { externalRecordContainerId = importCandidateContainerId candidate
        , externalRecordPresence = importCandidatePresence candidate
        , externalRecordWorkState = importCandidateWorkState candidate
        , externalRecordLastRevision = importCandidateRevision candidate
        , externalRecordLastObservedAt = now
        }
      changedRun = run {importRunCapturedCount = importRunCapturedCount run + 1}
      next = state
        { sourceImportRecords = Map.insert (externalRecordId record) changed
            (sourceImportRecords state)
        , sourceImportRuns = Map.insert (importRunId run) changedRun
            (sourceImportRuns state)
        }
  validateSourceImportState standing observed next
  let domain = standingDomain standing
      brick = externalRecordBrick changed >>= (`Map.lookup` Domain.domainBricks domain)
      entry = externalRecordEntry changed >>= (`Map.lookup` Domain.domainListEntries domain)
  pure (changed, brick, entry, standing, observed, next)

observeExternalCompletion ::
  UTCTime -> Text -> Standing.StandingState -> Material.MaterialState ->
  Selection.SelectionState -> SourceImportState ->
  Either ImportError
    (Selection.Proposal, Selection.SelectionState, SourceImportState)
observeExternalCompletion now identifier standing material selection state = do
  record <- requireRecord identifier state
  brickId <- maybe
    (Left (InvalidImportCandidate "external record has no Brick adoption")) Right
    (externalRecordBrick record)
  unless (externalRecordWorkState record == Material.WorkCompleted)
    (Left (InvalidImportCandidate "external record is not completed"))
  brick <- maybe (Left (InvalidImportDestination "adopted Brick is missing")) Right
    (Map.lookup brickId (Domain.domainBricks (standingDomain standing)))
  unless (Domain.brickStatus brick == Domain.Active)
    (Left (InvalidImportDestination "adopted Brick is terminal"))
  when (any (isOpenReviewFor brickId)
      (Map.elems (Selection.selectionStateProposals selection)))
    (Left (InvalidImportCandidate "completion review proposal already exists"))
  (proposal, nextSelection) <- mapSelection
    (Selection.createBrickReviewProposal now
      ("external-completion:" <> identifier) brickId
      "the attributed external source reports completion" selection)
  let next = state {sourceImportCompletionReviews = Set.insert brickId
        (sourceImportCompletionReviews state)}
      context = Selection.SelectionContext standing material
  mapSelection (Selection.validateSelectionState context nextSelection)
  validateSourceImportState standing material next
  pure (proposal, nextSelection, next)
  where
    isOpenReviewFor brickId proposal =
      Selection.proposalKind proposal == Selection.BrickReview
      && Selection.proposalBrick proposal == Just brickId
      && Selection.proposalStatus proposal == Selection.ProposalOpen

------------------------------------------------------------
-- Reviewed source effects and cutover
------------------------------------------------------------

planEraseAfterImport ::
  UTCTime -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError ([SourceEffect], SourceImportState)
planEraseAfterImport now runId standing material state = do
  run <- requireRun runId state
  unless (importRunMode run == Migrate && importRunEraseAfterImport run
      && importRunStatus run == ImportVerifiedStatus)
    (Left MigrationCleanupNotAllowed)
  profile <- requireProfile (importRunProfile run) state
  unless ("effect:erase-object" `elem`
      packComponentCapabilities (importProfileAdapter profile))
    (Left (SourceEffectCapabilityMissing "effect:erase-object"))
  let records = recordsForProfile (importProfileId profile) state
  eligible <- filterM cleanupEligible records
  let unplanned = filter
        (not . effectAlreadyPlanned runId . externalRecordId) eligible
      (effects, nextOrdinal) = allocateEffects run unplanned
        (sourceImportNextIdentity state)
      next = state
        { sourceImportNextIdentity = nextOrdinal
        , sourceImportEffects = foldr
            (\effect -> Map.insert (sourceEffectId effect) effect)
            (sourceImportEffects state) effects
        }
  validateSourceImportState standing material next
  pure (effects, next)
  where
    effectAlreadyPlanned selectedRun recordId = any (\effect ->
      sourceEffectRun effect == Just selectedRun
      && sourceEffectRecord effect == Just recordId
      && sourceEffectKind effect == EraseObject)
      (Map.elems (sourceImportEffects state))
    cleanupEligible record = case requireCleanupEligible material state record of
      Right () -> Right True
      Left (ImportDispositionIncomplete _) -> Right False
      Left problem -> Left problem
    allocateEffects run records firstOrdinal = foldl allocate ([], firstOrdinal) records
      where
        allocate (built, ordinal) record =
          let identifier = importIdentity "source-effect" ordinal
              preview = "Erase external object " <> externalRecordProvider record
                <> "/" <> externalRecordAccount record <> "/"
                <> externalRecordExternalId record <> " at revision "
                <> fromMaybe "unknown" (externalRecordLastRevision record)
              effect = SourceEffect identifier (Just (importRunId run))
                (Just (externalRecordId record)) EraseObject preview EffectProposed
                now Nothing Nothing Nothing Nothing
                (externalRecordLastRevision record)
          in (built <> [effect], ordinal + 1)

requireCleanupEligible ::
  Material.MaterialState -> SourceImportState -> ExternalRecord ->
  Either ImportError ()
requireCleanupEligible material state record = do
  raw <- maybe (Left (ImportDispositionIncomplete (externalRecordId record))) Right
    (Map.lookup (externalRecordRaw record) (Material.materialRaws material))
  unless (Material.rawReviewState raw == Material.RawReviewedState)
    (Left (ImportDispositionIncomplete (externalRecordId record)))
  latest <- mapMaterial (Material.rawLatestSnapshot material
    (externalRecordRaw record))
  unless (maybe False ((== Material.SnapshotAvailable)
      . Material.rawSnapshotAvailability) latest)
    (Left (ImportDispositionIncomplete (externalRecordId record)))
  when (Set.member (externalRecordId record)
      (sourceImportUnresolvedConflicts state))
    (Left (ImportDispositionIncomplete (externalRecordId record)))

approveSourceEffect ::
  UTCTime -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (SourceEffect, SourceImportState)
approveSourceEffect now = transitionEffectWith EffectProposed EffectApproved $ \effect ->
  effect {sourceEffectApprovedAt = Just now}

-- | The adapter boundary accepts only the exact already-previewed item effect.
authorizeApprovedSourceEffect ::
  Text -> SourceImportState -> Either ImportError SourceEffect
authorizeApprovedSourceEffect identifier state = do
  effect <- requireEffect identifier state
  unless (sourceEffectStatus effect == EffectApproved)
    (Left (InvalidSourceEffectTransition (sourceEffectStatus effect)))
  case sourceEffectKind effect of
    EraseObject -> unless (isJust (sourceEffectRecord effect))
      (Left (InvalidImportCandidate "erase-object effect is not item scoped"))
    _ -> pure ()
  pure effect

declineSourceEffect ::
  Text -> Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError (SourceEffect, SourceImportState)
declineSourceEffect identifier standing material state = do
  effect <- requireEffect identifier state
  unless (sourceEffectStatus effect `elem` [EffectProposed, EffectFailed])
    (Left (InvalidSourceEffectTransition (sourceEffectStatus effect)))
  let declined = effect {sourceEffectStatus = EffectDeclined}
      next = replaceEffect declined state
  validateAndReturn standing material declined next

failSourceEffect ::
  Text -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (SourceEffect, SourceImportState)
failSourceEffect identifier failure standing material state = do
  requireText "source effect failure" failure
  transitionEffectWith EffectApproved EffectFailed
    (\effect -> effect {sourceEffectFailure = Just failure})
    identifier standing material state

retrySourceEffect ::
  Text -> Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError (SourceEffect, SourceImportState)
retrySourceEffect identifier standing material state = do
  effect <- requireEffect identifier state
  unless (sourceEffectStatus effect == EffectFailed)
    (Left (InvalidSourceEffectTransition (sourceEffectStatus effect)))
  record <- case sourceEffectRecord effect of
    Nothing -> Right Nothing
    Just recordId -> Just <$> requireRecord recordId state
  unless (maybe True ((== sourceEffectTargetRevision effect)
      . externalRecordLastRevision) record)
    (Left SourceEffectTargetChanged)
  let retried = effect
        {sourceEffectStatus = EffectApproved, sourceEffectFailure = Nothing}
      next = replaceEffect retried state
  validateAndReturn standing material retried next

applySourceEffect ::
  UTCTime -> Text -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (SourceEffect, SourceImportState)
applySourceEffect now identifier receipt standing material state = do
  requireText "source effect receipt" receipt
  _ <- authorizeApprovedSourceEffect identifier state
  effect <- requireEffect identifier state
  let applied = effect
        { sourceEffectStatus = EffectApplied
        , sourceEffectAppliedAt = Just now
        , sourceEffectReceipt = Just receipt
        , sourceEffectFailure = Nothing
        }
      records = case sourceEffectRecord effect of
        Just recordId | sourceEffectKind effect == EraseObject ->
          Map.adjust (\record -> record
            {externalRecordPresence = Material.Removed}) recordId
            (sourceImportRecords state)
        _ -> sourceImportRecords state
      next = (replaceEffect applied state) {sourceImportRecords = records}
  validateAndReturn standing material applied next

transitionEffectWith ::
  SourceEffectStatus -> SourceEffectStatus -> (SourceEffect -> SourceEffect) ->
  Text -> Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError (SourceEffect, SourceImportState)
transitionEffectWith expected target alter identifier standing material state = do
  effect <- requireEffect identifier state
  unless (sourceEffectStatus effect == expected)
    (Left (InvalidSourceEffectTransition (sourceEffectStatus effect)))
  let changed = alter effect {sourceEffectStatus = target}
      next = replaceEffect changed state
  validateAndReturn standing material changed next

cutOverImport ::
  UTCTime -> Text -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState ->
  Either ImportError (ImportRun, Material.MaterialState, SourceImportState)
cutOverImport now identifier receipt standing material state = do
  run <- requireRun identifier state
  requireText "migration receipt" receipt
  unless (importRunMode run == Migrate
      && importRunStatus run == ImportVerifiedStatus)
    (Left (InvalidImportRunTransition (importRunStatus run)))
  unless (migrationScopeReviewed run material state)
    (Left ImportVerificationIncomplete)
  when (importRunEraseAfterImport run && not (cleanupResolved run state))
    (Left ImportCleanupUnresolved)
  let cutover = run
        { importRunStatus = ImportCutOver
        , importRunFinishedAt = Just now
        , importRunReceiptHash = Just receipt
        }
      withRun = replaceRun cutover state
  (retired, nextMaterial, retiredState) <- retireImportProfile
    (importRunProfile run) standing material withRun
  unless (importProfileStatus retired == ImportProfileRetired)
    (Left (SourceImportInvariantViolation ["cutover did not retire its profile"]))
  pure (cutover, nextMaterial, retiredState)

proposeEmptyContainerDeletion ::
  UTCTime -> Text -> Text -> Standing.StandingState -> Material.MaterialState ->
  SourceImportState -> Either ImportError (SourceEffect, SourceImportState)
proposeEmptyContainerDeletion now runId preview standing material state = do
  run <- requireRun runId state
  requireText "container deletion preview" preview
  unless (importRunStatus run `elem` [ImportVerifiedStatus, ImportCutOver])
    (Left (InvalidImportRunTransition (importRunStatus run)))
  profile <- requireProfile (importRunProfile run) state
  unless ("effect:erase-container" `elem`
      packComponentCapabilities (importProfileAdapter profile))
    (Left (SourceEffectCapabilityMissing "effect:erase-container"))
  let itemEffects = effectsForRunAndKind runId EraseObject state
  unless (not (null itemEffects)
      && all ((== EffectApplied) . sourceEffectStatus) itemEffects)
    (Left ImportCleanupUnresolved)
  let identifier = importIdentity "source-effect"
        (sourceImportNextIdentity state)
      effect = SourceEffect identifier (Just runId) Nothing EraseContainer
        preview EffectProposed now Nothing Nothing Nothing Nothing Nothing
      next = state
        { sourceImportNextIdentity = sourceImportNextIdentity state + 1
        , sourceImportEffects = Map.insert identifier effect
            (sourceImportEffects state)
        }
  validateAndReturn standing material effect next

------------------------------------------------------------
-- Sparse entity projections
------------------------------------------------------------

importProfileProjection :: ImportProfile -> Value
importProfileProjection profile = object
  [ "id" .= importProfileId profile
  , "version" .= importProfileVersion profile
  , "name" .= importProfileName profile
  , "adapter" .= importProfileAdapter profile
  , "source_scope" .= importProfileSourceScope profile
  , "candidate_kind" .= importProfileCandidateKind profile
  , "route" .= importProfileRoute profile
  , "destination_parent" .= importProfileDestinationParent profile
  , "destination_owner" .= importProfileDestinationOwner profile
  , "destination_shelf" .= importProfileDestinationShelf profile
  , "automatic_adoption" .= importProfileAutomaticAdoption profile
  , "status" .= importProfileStatus profile
  , "created_at" .= importProfileCreatedAt profile
  ]

sourceRecordProjection :: ExternalRecord -> Value
sourceRecordProjection record = object
  [ "id" .= externalRecordId record
  , "profile" .= externalRecordProfile record
  , "provider" .= externalRecordProvider record
  , "account" .= externalRecordAccount record
  , "external_id" .= externalRecordExternalId record
  , "container_id" .= externalRecordContainerId record
  , "raw" .= externalRecordRaw record
  , "brick" .= externalRecordBrick record
  , "entry" .= externalRecordEntry record
  , "presence" .= externalRecordPresence record
  , "work_state" .= externalRecordWorkState record
  , "last_revision" .= externalRecordLastRevision record
  , "last_observed_at" .= externalRecordLastObservedAt record
  ]

importRunProjection :: ImportRun -> Value
importRunProjection run = object
  [ "id" .= importRunId run
  , "profile" .= importRunProfile run
  , "mode" .= importRunMode run
  , "status" .= importRunStatus run
  , "erase_after_import" .= importRunEraseAfterImport run
  , "started_at" .= importRunStartedAt run
  , "finished_at" .= importRunFinishedAt run
  , "source_cursor" .= importRunSourceCursor run
  , "captured_count" .= importRunCapturedCount run
  , "verified_count" .= importRunVerifiedCount run
  , "failure_count" .= importRunFailureCount run
  , "receipt_hash" .= importRunReceiptHash run
  ]

sourceEffectProjection :: SourceEffect -> Value
sourceEffectProjection effect = object
  [ "id" .= sourceEffectId effect
  , "run" .= sourceEffectRun effect
  , "record" .= sourceEffectRecord effect
  , "kind" .= sourceEffectKind effect
  , "preview" .= sourceEffectPreview effect
  , "status" .= sourceEffectStatus effect
  , "proposed_at" .= sourceEffectProposedAt effect
  , "approved_at" .= sourceEffectApprovedAt effect
  , "applied_at" .= sourceEffectAppliedAt effect
  , "receipt" .= sourceEffectReceipt effect
  , "failure" .= sourceEffectFailure effect
  ]

sourceEffectsForRunProjection :: Text -> SourceImportState -> Value
sourceEffectsForRunProjection run state = object
  [ "items" .= map sourceEffectProjection effects
  , "kinds" .= map sourceEffectKind effects
  ]
  where
    effects = sortOn sourceEffectId
      [effect | effect <- Map.elems (sourceImportEffects state),
        sourceEffectRun effect == Just run]

------------------------------------------------------------
-- Invariants and helpers
------------------------------------------------------------

validateSourceImportState ::
  Standing.StandingState -> Material.MaterialState -> SourceImportState ->
  Either ImportError ()
validateSourceImportState standing material state = do
  mapMaterial (Material.validateMaterialState material)
  mapStanding (Standing.validateStandingState standing)
  case violations of
    [] -> Right ()
    _ -> Left (SourceImportInvariantViolation violations)
  where
    profiles = Map.elems (sourceImportProfiles state)
    records = Map.elems (sourceImportRecords state)
    runs = Map.elems (sourceImportRuns state)
    effects = Map.elems (sourceImportEffects state)
    domain = standingDomain standing
    externalKeys = map recordExternalKey records
    violations = concat
      [ ["source-import identity ordinal is not positive" |
          sourceImportNextIdentity state < 1]
      , ["profile map key differs from identity" | any (\(key, value) ->
          key /= importProfileId value) (Map.toList (sourceImportProfiles state))]
      , ["profile adapter is not an enabled source adapter" | any (\profile ->
          packComponentKind (importProfileAdapter profile) /= SourceAdapterComponent
          || packComponentStatus (importProfileAdapter profile) /= ComponentEnabled)
          profiles]
      , ["external identity is duplicated within a profile" |
          length externalKeys /= Set.size (Set.fromList externalKeys)]
      , ["ExternalRecord has both Brick and ListEntry adoption" | any (\record ->
          isJust (externalRecordBrick record) && isJust (externalRecordEntry record))
          records]
      , ["ExternalRecord references unknown profile or Raw" | any (\record ->
          Map.notMember (externalRecordProfile record) (sourceImportProfiles state)
          || Map.notMember (externalRecordRaw record) (Material.materialRaws material))
          records]
      , ["ExternalRecord adoption references unknown work" | any (\record ->
          maybe False (`Map.notMember` Domain.domainBricks domain)
            (externalRecordBrick record)
          || maybe False (`Map.notMember` Domain.domainListEntries domain)
            (externalRecordEntry record)) records]
      , ["ExternalRecord lacks preserved Raw origin or snapshot" | any (\record ->
          not (any ((== externalRecordRaw record) . Material.rawOriginRaw)
            (Map.elems (Material.materialOrigins material)))
          || not (any ((== externalRecordRaw record) . Material.rawSnapshotRaw)
            (Map.elems (Material.materialSnapshots material)))) records]
      , ["ImportRun references unknown profile" | any (\run ->
          Map.notMember (importRunProfile run) (sourceImportProfiles state)) runs]
      , ["synchronize run requested destructive cleanup" | any (\run ->
          importRunMode run == Synchronize && importRunEraseAfterImport run) runs]
      , ["terminal run omitted finish evidence" | any (\run ->
          importRunStatus run `elem` [ImportCompleted, ImportCutOver, ImportFailed]
          && not (isJust (importRunFinishedAt run))) runs]
      , ["SourceEffect references unknown run or record" | any (\effect ->
          maybe False (`Map.notMember` sourceImportRuns state) (sourceEffectRun effect)
          || maybe False (`Map.notMember` sourceImportRecords state)
            (sourceEffectRecord effect)) effects]
      , ["erase-object effect is not item scoped" | any (\effect ->
          sourceEffectKind effect == EraseObject
          && not (isJust (sourceEffectRecord effect))) effects]
      , ["container effect incorrectly owns an item" | any (\effect ->
          sourceEffectKind effect == EraseContainer
          && isJust (sourceEffectRecord effect)) effects]
      , ["effect status lacks its required evidence" | any invalidEffectEvidence effects]
      ]
    invalidEffectEvidence effect = case sourceEffectStatus effect of
      EffectProposed -> isJust (sourceEffectApprovedAt effect)
      EffectApproved -> not (isJust (sourceEffectApprovedAt effect))
      EffectApplied -> not (isJust (sourceEffectApprovedAt effect)
        && isJust (sourceEffectAppliedAt effect) && isJust (sourceEffectReceipt effect))
      EffectDeclined -> False
      EffectFailed -> not (isJust (sourceEffectApprovedAt effect)
        && isJust (sourceEffectFailure effect))

validateAndReturn ::
  Standing.StandingState -> Material.MaterialState -> value -> SourceImportState ->
  Either ImportError (value, SourceImportState)
validateAndReturn standing material value state = do
  validateSourceImportState standing material state
  pure (value, state)

standingDomain :: Standing.StandingState -> Domain.DomainState
standingDomain = Execution.executionStateDomain
  . Coordination.coordinationStateExecution . Standing.standingStateCoordination

deferImportedInsertion ::
  Priority.PriorityInsertion -> UTCTime -> Standing.StandingState ->
  Either ImportError Standing.StandingState
deferImportedInsertion insertion now standing = do
  let coordination = Standing.standingStateCoordination standing
      execution = Coordination.coordinationStateExecution coordination
  (_, priority) <- mapPriority (Priority.deferPriorityInsertion
    (Priority.priorityInsertionId insertion) now (Execution.executionStatePriority execution))
  let next = standing
        { Standing.standingStateCoordination = coordination
            { Coordination.coordinationStateExecution = execution
                {Execution.executionStatePriority = priority}
            }
        }
  mapStanding (Standing.validateStandingState next)
  pure next

migrationScopeReviewed ::
  ImportRun -> Material.MaterialState -> SourceImportState -> Bool
migrationScopeReviewed run material state = all reviewed
  (recordsForProfile (importRunProfile run) state)
  where
    reviewed record = maybe False
      ((== Material.RawReviewedState) . Material.rawReviewState)
      (Map.lookup (externalRecordRaw record) (Material.materialRaws material))

cleanupResolved :: ImportRun -> SourceImportState -> Bool
cleanupResolved run state = all resolved records
  where
    records = recordsForProfile (importRunProfile run) state
    effects = effectsForRunAndKind (importRunId run) EraseObject state
    resolved record = case filter
        ((== Just (externalRecordId record)) . sourceEffectRecord) effects of
      [effect] -> sourceEffectStatus effect `elem` [EffectApplied, EffectDeclined]
      _ -> False

effectsForRunAndKind :: Text -> SourceEffectKind -> SourceImportState -> [SourceEffect]
effectsForRunAndKind run kind state =
  [ effect
  | effect <- Map.elems (sourceImportEffects state)
  , sourceEffectRun effect == Just run
  , sourceEffectKind effect == kind
  ]

recordsForProfile :: Text -> SourceImportState -> [ExternalRecord]
recordsForProfile profile state = sortOn externalRecordId
  [record | record <- Map.elems (sourceImportRecords state),
    externalRecordProfile record == profile]

requireProfile :: Text -> SourceImportState -> Either ImportError ImportProfile
requireProfile identifier state = maybe (Left (UnknownImportProfile identifier)) Right
  (Map.lookup identifier (sourceImportProfiles state))

requireRecord :: Text -> SourceImportState -> Either ImportError ExternalRecord
requireRecord identifier state = maybe (Left (UnknownExternalRecord identifier)) Right
  (Map.lookup identifier (sourceImportRecords state))

requireRun :: Text -> SourceImportState -> Either ImportError ImportRun
requireRun identifier state = maybe (Left (UnknownImportRun identifier)) Right
  (Map.lookup identifier (sourceImportRuns state))

requireEffect :: Text -> SourceImportState -> Either ImportError SourceEffect
requireEffect identifier state = maybe (Left (UnknownSourceEffect identifier)) Right
  (Map.lookup identifier (sourceImportEffects state))

replaceRun :: ImportRun -> SourceImportState -> SourceImportState
replaceRun run state = state {sourceImportRuns = Map.insert (importRunId run) run
  (sourceImportRuns state)}

replaceEffect :: SourceEffect -> SourceImportState -> SourceImportState
replaceEffect effect state = state {sourceImportEffects = Map.insert
  (sourceEffectId effect) effect (sourceImportEffects state)}

findRecord :: ImportProfile -> ImportCandidate -> SourceImportState -> Maybe ExternalRecord
findRecord profile candidate = find ((== expected) . recordExternalKey)
  . Map.elems . sourceImportRecords
  where
    expected = (importProfileId profile, importCandidateProvider candidate,
      importCandidateAccount candidate, importCandidateExternalId candidate)

recordExternalKey :: ExternalRecord -> (Text, Text, Text, Text)
recordExternalKey record = (externalRecordProfile record,
  externalRecordProvider record, externalRecordAccount record,
  externalRecordExternalId record)

candidateExternalKey :: ImportCandidate -> (Text, Text, Text)
candidateExternalKey candidate = (importCandidateProvider candidate,
  importCandidateAccount candidate, importCandidateExternalId candidate)

stableExternalRecordId :: ImportProfile -> ImportCandidate -> Text
stableExternalRecordId profile candidate = "external_" <> digestText (Text.intercalate "\NUL"
  [ importProfileId profile
  , importCandidateProvider candidate
  , importCandidateAccount candidate
  , importCandidateExternalId candidate
  ])

importIdentity :: Text -> Integer -> Text
importIdentity kind ordinal = "la1_" <> kind <> "_" <> digestText
  (kind <> ":" <> Text.pack (show ordinal))

digestText :: Text -> Text
digestText = Text.pack . showDigest . sha256 . LBS.fromStrict . TextEncoding.encodeUtf8

importLocator :: ImportCandidate -> Text
importLocator candidate = Text.intercalate "/"
  (filter (not . Text.null)
    [importCandidateProvider candidate, importCandidateAccount candidate,
     fromMaybe "" (importCandidateContainerId candidate),
     importCandidateExternalId candidate])

candidateVerbatim :: ImportCandidate -> Maybe Text
candidateVerbatim candidate = case catMaybes
    [importCandidateOriginalTitle candidate, importCandidateBody candidate] of
  [] -> Nothing
  parts -> Just (Text.intercalate "\n\n" parts)

candidateSize :: ImportCandidate -> Integer
candidateSize = fromIntegral . Text.length . fromMaybe "" . candidateVerbatim

requireCanonical :: ImportCandidate -> Either ImportError Text
requireCanonical candidate = maybe
  (Left (InvalidImportCandidate "automatic adoption requires canonical English"))
  Right (importCandidateCanonicalEnglish candidate)

requireText :: Text -> Text -> Either ImportError ()
requireText label value = when (Text.null (Text.strip value))
  (Left (InvalidImportText label))

mapMaterial :: Either Material.MaterialError value -> Either ImportError value
mapMaterial = either (Left . SourceImportMaterialError) Right

mapStanding :: Either Standing.StandingError value -> Either ImportError value
mapStanding = either (Left . SourceImportStandingError) Right

mapPriority :: Either Priority.PriorityError value -> Either ImportError value
mapPriority = either (Left . SourceImportPriorityError) Right

mapSelection :: Either Selection.SelectionError value -> Either ImportError value
mapSelection = either (Left . SourceImportSelectionError) Right

mapDomain :: Either Domain.DomainError value -> Either ImportError value
mapDomain = either
  (Left . InvalidImportCandidate . Text.pack . show) Right

infixr 3 <|>
(<|>) :: Maybe value -> Maybe value -> Maybe value
(<|>) (Just value) _ = Just value
(<|>) Nothing other = other

module LittleAnt.Application (
  AppCommand (..),
  AppEnv (..),
  ProviderConnectionRuntime (..),
  ViewDepth (..),
  natureBranch,
  productionAppEnv,
  resolveProfileName,
  runAppCommand,
)
where

import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Exception (IOException, SomeException, catch, displayException, try)
import Control.Monad (foldM, replicateM, unless, void, when)
import Data.Aeson
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAsciiLower)
import Data.Either (isRight)
import Data.List (find, minimumBy, sort, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust, isNothing, mapMaybe)
import Data.Ord (Down (..), comparing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time
import Data.Time.Zones (TZ, loadTZFromDB, utcToLocalTimeTZ)
import LittleAnt.Catalog
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Event (EventDraft (..), EventPayload (..), ForecastSelected (..), PersistedEvent (..), RepeatableReturnSet (..), applyEvent, decodeEvent, eventTypeName)
import LittleAnt.Export
import LittleAnt.Forecast
import LittleAnt.ForecastWorld qualified as World
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Import
import LittleAnt.Interaction
import LittleAnt.Judgment
import LittleAnt.JudgmentDecision
import LittleAnt.JudgmentUI
import LittleAnt.Model
import LittleAnt.Notice
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Admin
import LittleAnt.Pack.Catalog
import LittleAnt.Pack.Format
import LittleAnt.Pack.Installed
import LittleAnt.Pack.Official
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner (defaultPackRunnerClient)
import LittleAnt.Pack.Standard (loadStandardPackAuthorization, standardPackIdentity)
import LittleAnt.Pack.Store (PackStoreConfig (..), inspectStoredPack, storeAuthorizedPack)
import LittleAnt.Pack.Transport
import LittleAnt.Pack.Trust
import LittleAnt.Profile qualified as Profile
import LittleAnt.Projection
import LittleAnt.Provider
import LittleAnt.Provider.Connection
import LittleAnt.Repair
import LittleAnt.Result
import LittleAnt.Source
import LittleAnt.Store
import LittleAnt.Temporal
import LittleAnt.Time
import LittleAnt.Vault.Agent
import System.Directory
import System.Entropy qualified as Entropy
import System.Environment (lookupEnv)
import System.FilePath (takeExtension, (</>))
import System.IO (stderr)
import System.IO.Error (isDoesNotExistError)

data ViewDepth = SummaryView | OperationalView | RelationshipsView | HistoryView | CompleteView | GuidedView
  deriving stock (Eq, Ord, Show)

data AppCommand
  = NextCommand
  | FocusCommand Text
  | FocusBlockerCommand Text
  | DoneCommand (Maybe Text)
  | ReturnToIdleCommand (Maybe Text)
  | FinishCommand Text
  | ListCommand (Maybe Text)
  | SearchCommand Text
  | HelpCommand (Maybe Text)
  | FeedCommand Text Text
  | ShowRawCommand Text ViewDepth
  | TranslateCommand (Maybe Text)
  | RespondCommand InteractionResponse
  | SubmitInteractionTextCommand InteractionResponse Text
  | NavigateBackCommand InteractionResponse
  | NavigateForwardCommand InteractionResponse
  | UndoCommand
  | RedoCommand
  | GrammarCommand
  | OrderCommand (Maybe Text)
  | ImpactCommand Text
  | EffortCommand Text
  | PhaseCommand Text
  | PauseCommand
  | BreakCommand Text
  | ArchiveCommand Text
  | RestoreCommand Text
  | DomainFocusCommand Text
  | TieBreakCommand
  | NoticesCommand
  | HistoryCommand (Maybe Int)
  | TickCommand
  | SetRecurrenceScheduleCommand RecurrenceSchedule
  | SetHabitScheduleCommand HabitSchedule
  | SetScheduledIntervalCommand Text ZonedInstant ZonedInstant
  | SetOperationalDayConfigCommand OperationalDayConfig
  | ProfileListCommand
  | ProfileShowCommand (Maybe Text)
  | ProfileCreateCommand Text
  | ProfileUseCommand Text
  | ConfigShowCommand
  | ConfigPathsCommand
  | ConfigValidateCommand
  | ConfigConnectCommand Text Text Text Text
  | UpdateCommand Text (Maybe Text)
  | MergeCommand Text Text
  | SupersedeCommand Text Text
  | ImportCommand Text SourceMode Bool
  | MigrateCommand Text Text Text
  | ExportCommand Text (Maybe Text) (Maybe FilePath)
  | WebCommand
  | PacksListCommand
  | PacksShowCommand Text
  | PacksInstallCommand Text
  | PacksUpdatesCommand
  | PacksUpdateCommand Text
  | PacksRemoveCommand Text
  | PacksRefreshCommand
  | PacksTrustCommand Text
  | PacksUntrustCommand Text
  | PacksGcCommand
  | DoctorCommand
  | RepairCommand
  | EditorCommand
  deriving stock (Eq, Show)

data AppEnv = AppEnv
  { appStore :: StoreConfig
  , appActor :: Actor
  , appNow :: IO UTCTime
  , appZonedNow :: IO ZonedTime
  , appAllocateUUID :: IO UUIDv7
  , appExportPort :: ExportPort
  , appImportPort :: ImportPort
  , appImportPortProblem :: Maybe AppError
  , appPackRegistryProblem :: Maybe AppError
  , appOfficialPackRemote :: Maybe OfficialPackRemote
  , appProviderConnectionRuntime :: Maybe ProviderConnectionRuntime
  }

data ProviderConnectionRuntime = ProviderConnectionRuntime
  { providerConnectionDefinitions :: [ProviderSourceDefinition]
  , providerConnectionInstalledDefinitions :: [ProviderSourceDefinition]
  , providerConnectionOAuthTransport :: OAuthFormTransport
  , providerConnectionPresentPrompt :: DeviceAuthorizationPrompt -> IO ()
  , providerConnectionWaitSeconds :: Int -> IO ()
  }

data PresentationCheckpoint = PresentationCheckpoint
  { checkpointCurrent :: InteractionEnvelope
  , checkpointBack :: [InteractionEnvelope]
  , checkpointForward :: [InteractionEnvelope]
  }
  deriving stock (Eq, Show)

productionAppEnv :: Maybe Text -> IO (Either AppError AppEnv)
productionAppEnv explicitProfile = do
  roots <- Profile.resolveXdgRoots
  resolveProfileName explicitProfile >>= \case
    Left problem -> pure (Left problem)
    Right profile -> do
      case Profile.profilePaths roots profile of
        Left problem -> pure (Left problem)
        Right paths -> do
          exists <- doesDirectoryExist (Profile.profileDirectory paths)
          prepared <-
            if exists
              then pure (Right ())
              else
                if profile == "default"
                  then do
                    nonce <- generateUUIDv7
                    fmap (const ()) <$> Profile.createProfile roots profile nonce
                  else
                    pure . Left $
                      (appError NotFound "The selected named profile does not exist.")
                        { appErrorSubject = Just profile
                        , appErrorRecovery = [RecoveryAction "create-profile" "Create it explicitly before selection." (Just ("lant profile create " <> profile))]
                        }

          case prepared of
            Left problem -> pure (Left problem)
            Right () ->
              Profile.loadProfile roots profile >>= \case
                Left problem -> pure (Left problem)
                Right (loadedPaths, config, _, _, integrations) -> case mkProfileScope profile of
                  Left problem -> pure (Left problem)
                  Right scope -> do
                    now <- getCurrentTime
                    case compiledOfficialCatalogRoot of
                      Left problem -> pure (Left problem)
                      Right root -> do
                        registry <- loadProfilePackRegistry now scope loadedPaths integrations (OfficialCatalogCompiledRoot root)
                        runner <- defaultPackRunnerClient
                        remote <- newOfficialPackRemote
                        providerHttp <- newTlsPackHttpTransport
                        oauthTransport <- newTlsOAuthFormTransport
                        let providerSources =
                              registry >>= \available ->
                                configuredProviderImportSources
                                  standardProviderSourceDefinitions
                                  integrations
                                  available
                                  (vaultAgentAccessTokenResolver (Profile.vaultSocket loadedPaths) getCurrentTime)
                                  providerHttp
                            registryProblem = either Just (const Nothing) registry
                            importProblem = either Just (const Nothing) (registry >> providerSources)
                            installedProviderDefinitions =
                              case registry of
                                Left _ -> []
                                Right available -> filter (\definition -> isRight (lookupPackComponent (providerDefinitionAdapterId definition) available)) standardProviderSourceDefinitions
                        pure . Right $
                          AppEnv
                            { appStore = StoreConfig (Profile.configuredDataset config) 2000000 20000
                            , appActor = Actor "human" profile
                            , appNow = getCurrentTime
                            , appZonedNow = getZonedTime
                            , appAllocateUUID = generateUUIDv7
                            , appExportPort = either (const emptyExportPort) (packRegistryExportPort runner) registry
                            , appImportPort =
                                case (registry, providerSources) of
                                  (Right available, Right providers) -> packRegistryImportPortWithProviders runner available providers
                                  (Right available, Left _) -> packRegistryImportPort runner available
                                  (Left _, _) -> emptyImportPort
                            , appImportPortProblem = importProblem
                            , appPackRegistryProblem = registryProblem
                            , appOfficialPackRemote = Just remote
                            , appProviderConnectionRuntime =
                                Just
                                  ProviderConnectionRuntime
                                    { providerConnectionDefinitions = standardProviderSourceDefinitions
                                    , providerConnectionInstalledDefinitions = installedProviderDefinitions
                                    , providerConnectionOAuthTransport = oauthTransport
                                    , providerConnectionPresentPrompt = presentDeviceAuthorizationPrompt
                                    , providerConnectionWaitSeconds = \seconds -> threadDelay (seconds * 1_000_000)
                                    }
                            }

presentDeviceAuthorizationPrompt :: DeviceAuthorizationPrompt -> IO ()
presentDeviceAuthorizationPrompt prompt =
  TextIO.hPutStrLn stderr $
    Text.unlines
      [ "Authorize this provider account:"
      , ""
      , "Open: " <> devicePromptVerificationUri prompt
      , "Code: " <> devicePromptUserCode prompt
      , "Expires: " <> Text.pack (formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (devicePromptExpiresAt prompt))
      , ""
      , "Little Ant is waiting for the provider."
      ]

resolveProfileName :: Maybe Text -> IO (Either AppError Text)
resolveProfileName explicit = do
  roots <- Profile.resolveXdgRoots
  fromEnvironment <- fmap Text.pack <$> lookupEnv "LANT_PROFILE"
  Profile.readSelectedProfile roots >>= \case
    Left problem -> pure (Left problem)
    Right selectedFile ->
      let selected = fromMaybe "default" (explicit <|> fromEnvironment <|> selectedFile)
       in pure $
            if Profile.validProfileName selected
              then Right selected
              else Left (appError InvalidInput "A profile name must match [a-z0-9][a-z0-9-]{0,31}."){appErrorSubject = Just selected}

runAppCommand :: AppEnv -> Bool -> (Integer -> IO ()) -> AppCommand -> IO (Either AppError CommandResult)
runAppCommand environment dryRun progress DoctorCommand = runDoctor environment dryRun progress
runAppCommand environment dryRun progress RepairCommand = runRepair environment dryRun progress
runAppCommand environment dryRun progress command =
  loadDataset (appStore environment) progress >>= \case
    Left problem -> case command of
      RespondCommand response -> runCorruptDatasetResponse environment dryRun response problem
      _ -> pure (Left problem)
    Right loaded ->
      advanceDueTemporal environment dryRun loaded >>= \case
        Left problem -> pure (Left problem)
        Right (dataset, tickPlan) -> do
          result <- runLoadedCommand environment dryRun dataset tickPlan command
          applyNoticeFrameToResult environment dryRun dataset result

runLoadedCommand :: AppEnv -> Bool -> LoadedDataset -> TemporalTickPlan -> AppCommand -> IO (Either AppError CommandResult)
runLoadedCommand environment dryRun dataset tickPlan = \case
  NextCommand -> runNext environment dryRun dataset
  FocusCommand reference -> runFocus environment dryRun dataset reference
  DoneCommand reference -> runDone environment dryRun dataset reference
  ReturnToIdleCommand reference -> runReturnToIdle environment dryRun dataset reference
  FinishCommand reference -> runFinish environment dryRun dataset reference
  ListCommand list -> runList environment dryRun dataset list
  SearchCommand query -> runSearch environment dryRun dataset query
  HelpCommand topic -> runHelp environment dryRun dataset topic
  FocusBlockerCommand reference -> runFocusBlocker environment dryRun dataset reference
  FeedCommand origin material -> runFeed environment dryRun dataset origin material
  ShowRawCommand reference GuidedView -> runOpenRaw environment dryRun dataset reference
  ShowRawCommand reference view -> pure (runShow dryRun dataset reference view)
  TranslateCommand reference -> runTranslate environment dryRun dataset reference
  RespondCommand response -> runResponse environment dryRun dataset response Nothing
  SubmitInteractionTextCommand response submitted -> runResponse environment dryRun dataset response (Just submitted)
  NavigateBackCommand response -> runNavigation environment dryRun dataset response True
  NavigateForwardCommand response -> runNavigation environment dryRun dataset response False
  UndoCommand -> runUndo environment dryRun dataset
  RedoCommand -> runRedo environment dryRun dataset
  GrammarCommand -> pure . Right $ GrammarResult (loadedCursor dataset) ["focus", "comparison", "confirmation", "choice", "input"] dryRun
  OrderCommand reference -> runOrder environment dryRun dataset reference
  ImpactCommand reference -> runImpact environment dryRun dataset reference
  EffortCommand reference -> runEffort environment dryRun dataset reference
  PhaseCommand reference -> runPhase environment dryRun dataset reference
  PauseCommand -> runPause environment dryRun dataset
  BreakCommand reference -> runBreak environment dryRun dataset reference
  ArchiveCommand reference -> runArchive environment dryRun dataset reference
  RestoreCommand reference -> runRestore environment dryRun dataset reference
  DomainFocusCommand reference -> runDomainFocus environment dryRun dataset reference
  TieBreakCommand -> runTieBreak environment dryRun dataset
  NoticesCommand -> runNotices environment dryRun dataset
  HistoryCommand limit -> runHistory environment dryRun dataset limit
  TickCommand ->
    pure . Right $
      TickResult
        (loadedCursor dataset)
        (length (temporalTickReleases tickPlan))
        (length (temporalTickNewHabitWindows tickPlan))
        ( sum (habitWindowFactExpiredUnits <$> temporalTickNewHabitWindows tickPlan)
            + sum (habitExpiryUnits <$> temporalTickHabitExpiries tickPlan)
        )
        dryRun
  SetRecurrenceScheduleCommand schedule ->
    runDirectMutation environment dryRun dataset 2 (decideSetRecurrenceSchedule (loadedState dataset) (appActor environment) schedule)
  SetHabitScheduleCommand schedule ->
    runDirectMutation environment dryRun dataset 2 (decideSetHabitSchedule (loadedState dataset) (appActor environment) schedule)
  SetScheduledIntervalCommand reference startsAt endsAt ->
    case resolveBrickReference (loadedState dataset) reference of
      Left problem -> pure (Left problem)
      Right brick ->
        runDirectMutation
          environment
          dryRun
          dataset
          2
          (decideSetScheduledInterval (loadedState dataset) (appActor environment) (brickId brick) startsAt endsAt)
  SetOperationalDayConfigCommand config ->
    runDirectMutation environment dryRun dataset 2 (decideSetOperationalDayConfig (loadedState dataset) (appActor environment) config)
  ProfileListCommand -> runProfileList environment dryRun dataset
  ProfileShowCommand requested -> runProfileShow environment dryRun dataset requested
  ProfileCreateCommand name -> runProfileCreate environment dryRun dataset name
  ProfileUseCommand name -> runProfileUse environment dryRun dataset name
  ConfigShowCommand -> runConfigShow environment dryRun dataset
  ConfigPathsCommand -> runConfigPaths environment dryRun dataset
  ConfigValidateCommand -> runConfigValidate environment dryRun dataset
  ConfigConnectCommand source account label clientId -> runConfigConnect environment dryRun dataset source account label clientId
  UpdateCommand reference section -> pure (unsupportedCommand "update")
  MergeCommand survivor absorbed -> pure (unsupportedCommand ("merge " <> survivor <> " " <> absorbed))
  SupersedeCommand oldBrick newBrick -> pure (unsupportedCommand ("supersede " <> oldBrick <> " " <> newBrick))
  ImportCommand source mode eraseAfterImport ->
    runImport environment dryRun dataset source mode eraseAfterImport
  MigrateCommand sourcePath targetPath mode ->
    pure $ unsupportedCommand ("migrate " <> sourcePath <> " " <> targetPath <> " mode=" <> mode)
  ExportCommand exporter scope outputPath -> runExport environment dryRun dataset exporter scope outputPath
  WebCommand -> pure (unsupportedCommand "web")
  PacksListCommand -> runPacksList environment dryRun dataset
  PacksShowCommand pack -> runPacksShow environment dryRun dataset pack
  PacksInstallCommand archive -> runPacksInstall environment dryRun dataset archive
  PacksUpdatesCommand -> pure (unsupportedCommand "packs updates")
  PacksUpdateCommand pack -> pure (unsupportedCommand ("packs update " <> pack))
  PacksRemoveCommand pack -> pure (unsupportedCommand ("packs remove " <> pack))
  PacksRefreshCommand -> runPacksRefresh environment dryRun dataset
  PacksTrustCommand keyFile -> runPacksTrust environment dryRun dataset keyFile
  PacksUntrustCommand pack -> pure (unsupportedCommand ("packs untrust " <> pack))
  PacksGcCommand -> pure (unsupportedCommand "packs gc")
  DoctorCommand -> runDoctor environment dryRun (const (pure ()))
  RepairCommand -> runRepair environment dryRun (const (pure ()))
  EditorCommand -> pure (unsupportedCommand "editor")

unsupportedCommand :: Text -> Either AppError CommandResult
unsupportedCommand detail =
  Left $
    (appError Unsupported (detail <> " is not implemented in this checkpoint."))
      { appErrorRecovery =
          [RecoveryAction "implementation-roadmap" "Implement this command path in a later milestone." (Just "lant help commands")]
      , appErrorDetails = ["checkpoint: v1 command-surface alignment"]
      }

data PackProfileSnapshot = PackProfileSnapshot
  { packProfilePaths :: Profile.ProfilePaths
  , packProfileScope :: ProfileScope
  , packProfileIntegrations :: Profile.IntegrationsConfig
  , packProfileTrustPolicy :: PackTrustPolicy
  , packProfileRevision :: Text
  , packProfileObservedAt :: UTCTime
  }

runPacksInstall :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runPacksInstall environment dryRun dataset requested = do
  let normalized = Text.strip requested
  pathExists <- doesPathExist (Text.unpack normalized)
  if pathExists || looksLikePackPath normalized
    then runLocalPackInstall environment dryRun dataset normalized
    else runOfficialPackInstall environment dryRun dataset normalized

runLocalPackInstall :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runLocalPackInstall environment dryRun dataset requested =
  readPackArchiveCandidate (Text.unpack requested) >>= \case
    Left problem -> pure (Left problem)
    Right candidate ->
      loadPackProfileSnapshot environment >>= \case
        Left problem -> pure (Left problem)
        Right profile -> makePackInstallPreview environment dryRun dataset profile candidate

runOfficialPackInstall :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runOfficialPackInstall environment dryRun dataset requested =
  case appOfficialPackRemote environment of
    Nothing -> pure . Left $ officialRemoteUnavailable "install"
    Just remote ->
      loadPackProfileSnapshot environment >>= \case
        Left problem -> pure (Left problem)
        Right profile -> case selectOfficialRelease requested (packProfileTrustPolicy profile) of
          Left problem -> pure (Left problem)
          Right grant ->
            fetchOfficialPackArchive remote (officialGrantArchiveDigest grant) >>= \case
              Left problem -> pure (Left problem)
              Right bytes -> do
                let dryRunSource = "official:" <> Text.unpack (officialGrantName grant) <> "@" <> Text.unpack (officialGrantVersion grant)
                cached <-
                  if dryRun
                    then pure (Right dryRunSource)
                    else cacheOfficialPackArchive (Profile.profileStateDirectory (packProfilePaths profile)) (officialGrantArchiveDigest grant) bytes
                case cached of
                  Left problem -> pure (Left problem)
                  Right sourcePath -> case packArchiveCandidateFromBytes sourcePath bytes of
                    Left problem -> pure (Left problem)
                    Right candidate
                      | authenticatedPackIdentity (packCandidateAuthenticated candidate) /= officialGrantIdentity grant ->
                          pure . Left $
                            (appError CorruptData "The downloaded official Pack does not match the signed catalog release.")
                              { appErrorSubject = Just (officialGrantName grant)
                              , appErrorDetails = [officialGrantArchiveDigest grant, artifactArchiveDigest (authenticatedPackIdentity (packCandidateAuthenticated candidate))]
                              }
                      | otherwise -> makePackInstallPreview environment dryRun dataset profile candidate

makePackInstallPreview :: AppEnv -> Bool -> LoadedDataset -> PackProfileSnapshot -> PackArchiveCandidate -> IO (Either AppError CommandResult)
makePackInstallPreview environment dryRun dataset profile candidate =
  case preparePackInstallDraft profile candidate of
    Left problem -> pure (Left problem)
    Right draft -> do
      identity <- appAllocateUUID environment
      now <- appZonedNow environment
      let state = loadedState dataset
          envelope = makePackInstallEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now state draft (packCandidateAuthenticated candidate)
      saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
      pure (Right (NextResult (loadedCursor dataset) envelope dryRun))

runPacksRefresh :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runPacksRefresh environment dryRun dataset = case (compiledOfficialCatalogRoot, appOfficialPackRemote environment) of
  (Left problem, _) -> pure (Left problem)
  (_, Nothing) -> pure . Left $ officialRemoteUnavailable "refresh"
  (Right compiledRoot, Just remote) ->
    fetchOfficialCatalog remote >>= \case
      Left problem -> pure (Left problem)
      Right payload ->
        loadPackProfileSnapshot environment >>= \case
          Left problem -> pure (Left problem)
          Right profile -> do
            let config = CatalogStateConfig (Profile.officialCatalogStateFile (packProfilePaths profile))
            readAcceptedCatalogState config compiledRoot >>= \case
              Left problem -> pure (Left problem)
              Right accepted -> do
                now <- appNow environment
                let candidate =
                      acceptOfficialPackCatalog
                        now
                        (emptyAcceptedCatalogState (acceptedCatalogActiveRoot accepted))
                        (officialCatalogDocumentBytes payload)
                        (officialCatalogSignatureBytes payload)
                case candidate >>= maybe (Left (appError CorruptData "The verified catalog produced no current document.")) Right . acceptedCatalogCurrent of
                  Left problem -> pure (Left problem)
                  Right catalog -> refreshFromCandidate payload config compiledRoot accepted catalog now
 where
  refreshFromCandidate payload config compiledRoot accepted catalog now = case acceptedCatalogCurrent accepted of
    Just current
      | officialCatalogSequence catalog < officialCatalogSequence current -> pure . Left $ catalogSequenceProblem "The downloaded official catalog is older than the accepted catalog." current catalog
      | officialCatalogSequence catalog == officialCatalogSequence current && catalog /= current -> pure . Left $ catalogSequenceProblem "The downloaded official catalog equivocates at an accepted sequence." current catalog
      | catalog == current -> pure (Right (catalogRefreshResult dataset dryRun compiledRoot catalog False))
    _
      | dryRun -> pure (Right (catalogRefreshResult dataset True compiledRoot catalog True))
      | otherwise -> do
          refreshed <-
            refreshOfficialPackCatalog
              config
              compiledRoot
              now
              (officialCatalogDocumentBytes payload)
              (officialCatalogSignatureBytes payload)
          pure (fmap (const (catalogRefreshResult dataset False compiledRoot catalog True)) refreshed)

looksLikePackPath :: Text -> Bool
looksLikePackPath requested =
  Text.isSuffixOf ".lantpack" requested
    || Text.any (`elem` ['/', '\\']) requested
    || Text.isPrefixOf "." requested

selectOfficialRelease :: Text -> PackTrustPolicy -> Either AppError OfficialReleaseGrant
selectOfficialRelease requested policy =
  let (name, version) = splitOfficialReference requested
      candidates =
        [ grant
        | grant <- Set.toAscList (trustOfficialReleaseGrants policy)
        , officialGrantName grant == name
        , maybe True (== officialGrantVersion grant) version
        ]
   in case candidates of
        [] ->
          Left
            ( (appError NotFound "The accepted official catalog has no matching Pack release.")
                { appErrorSubject = Just requested
                , appErrorRecovery = [RecoveryAction "refresh-catalog" "Refresh the signed official catalog, then use an exact Pack name or name@version." (Just "lant packs refresh")]
                }
            )
        [grant] -> Right grant
        _ ->
          Left
            ( (appError AmbiguousReference "More than one official Pack release matches this name.")
                { appErrorSubject = Just requested
                , appErrorDetails = [officialGrantName grant <> "@" <> officialGrantVersion grant | grant <- candidates]
                , appErrorRecovery = [RecoveryAction "select-version" "Choose one exact name@version from the signed catalog." Nothing]
                }
            )

splitOfficialReference :: Text -> (Text, Maybe Text)
splitOfficialReference requested = case Text.breakOnEnd "@" requested of
  (prefix, suffix)
    | not (Text.null prefix) && not (Text.null suffix) -> (Text.dropEnd 1 prefix, Just suffix)
  _ -> (requested, Nothing)

officialGrantIdentity :: OfficialReleaseGrant -> PackArtifactIdentity
officialGrantIdentity grant =
  PackArtifactIdentity
    { artifactPublisher = officialGrantPublisher grant
    , artifactName = officialGrantName grant
    , artifactVersion = officialGrantVersion grant
    , artifactManifestDigest = officialGrantManifestDigest grant
    , artifactArchiveDigest = officialGrantArchiveDigest grant
    }

catalogRefreshResult :: LoadedDataset -> Bool -> CatalogRoot -> OfficialPackCatalog -> Bool -> CommandResult
catalogRefreshResult dataset dryRun root catalog changed =
  ConfigurationResult
    (loadedCursor dataset)
    "packs_refresh"
    Nothing
    []
    ( Map.fromList
        [ ("catalog_sequence", Text.pack (show (officialCatalogSequence catalog)))
        , ("expires_at", Text.pack (formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (officialCatalogExpiresAt catalog)))
        , ("root_fingerprint", catalogRootFingerprint root)
        , ("status", if changed then if dryRun then "would update" else "updated" else "already current")
        ]
    )
    dryRun

catalogSequenceProblem :: Text -> OfficialPackCatalog -> OfficialPackCatalog -> AppError
catalogSequenceProblem message current candidate =
  (appError Conflict message)
    { appErrorSubject = Just "official Pack catalog"
    , appErrorDetails =
        [ "accepted sequence: " <> Text.pack (show (officialCatalogSequence current))
        , "downloaded sequence: " <> Text.pack (show (officialCatalogSequence candidate))
        ]
    , appErrorRecovery = [RecoveryAction "retain-current" "Keep the accepted signed history and investigate the publication source; do not replace it manually." Nothing]
    }

officialRemoteUnavailable :: Text -> AppError
officialRemoteUnavailable action =
  (appError Unsupported ("Official Pack " <> action <> " is unavailable in this host."))
    { appErrorRecovery = [RecoveryAction "use-production-host" "Use a Little Ant host configured with the official HTTPS Pack transport." Nothing]
    }

runPacksTrust :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runPacksTrust environment dryRun dataset requested =
  readPackPublisherKeyDocument (Text.unpack (Text.strip requested)) >>= \case
    Left problem -> pure (Left problem)
    Right (canonicalPath, sourceDigest, document) ->
      loadPackProfileSnapshot environment >>= \case
        Left problem -> pure (Left problem)
        Right profile -> do
          identity <- appAllocateUUID environment
          now <- appZonedNow environment
          let state = loadedState dataset
              publisher = publisherKeyTrust document
          if publisher `Set.member` Profile.trustedPublishers (packProfileIntegrations profile)
            then do
              let envelope = makePackTrustResultEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now state publisher
              saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
              pure (Right (NextResult (loadedCursor dataset) envelope dryRun))
            else do
              let draft =
                    PackTrustDraft
                      { packTrustSource = StandalonePublisherKey
                      , packTrustSourcePath = canonicalPath
                      , packTrustSourceSha256 = sourceDigest
                      , packTrustPublisher = publisher
                      , packTrustProfileRevision = packProfileRevision profile
                      , packTrustReturnToInstall = Nothing
                      }
                  envelope = makePackTrustEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now state draft
              saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
              pure (Right (NextResult (loadedCursor dataset) envelope dryRun))

loadPackProfileSnapshot :: AppEnv -> IO (Either AppError PackProfileSnapshot)
loadPackProfileSnapshot environment = do
  roots <- Profile.resolveXdgRoots
  let profileName = actorProfile (appActor environment)
  case Profile.profilePaths roots profileName of
    Left problem -> pure (Left problem)
    Right expectedPaths ->
      Profile.integrationsConfigRevision expectedPaths >>= \case
        Left problem -> pure (Left problem)
        Right beforeRevision ->
          Profile.loadProfile roots profileName >>= \case
            Left problem -> pure (Left problem)
            Right (paths, _, _, _, integrations) ->
              Profile.integrationsConfigRevision paths >>= \case
                Left problem -> pure (Left problem)
                Right afterRevision
                  | beforeRevision /= afterRevision -> pure (Left packProfileChanged)
                  | otherwise -> case mkProfileScope profileName of
                      Left problem -> pure (Left problem)
                      Right scope -> do
                        now <- appNow environment
                        case compiledOfficialCatalogRoot of
                          Left problem -> pure (Left problem)
                          Right root ->
                            loadProfileTrustPolicy now paths integrations (OfficialCatalogCompiledRoot root) >>= \case
                              Left problem -> pure (Left problem)
                              Right policy ->
                                pure . Right $
                                  PackProfileSnapshot
                                    { packProfilePaths = paths
                                    , packProfileScope = scope
                                    , packProfileIntegrations = integrations
                                    , packProfileTrustPolicy = policy
                                    , packProfileRevision = afterRevision
                                    , packProfileObservedAt = now
                                    }

preparePackInstallDraft :: PackProfileSnapshot -> PackArchiveCandidate -> Either AppError PackInstallDraft
preparePackInstallDraft profile candidate = do
  let authenticated = packCandidateAuthenticated candidate
      identity = authenticatedPackIdentity authenticated
      manifest = structurallyValidManifest (authenticatedStructuralPack authenticated)
      enabled = Set.fromList (componentId . componentCommon <$> packComponents manifest)
      existing = Map.lookup (artifactName identity) (Profile.installedComponents (packProfileIntegrations profile))
  when (artifactName identity == artifactName standardPackIdentity) $
    Left (packAlreadyPresent identity "The bundled standard Pack is already available and cannot be installed as a profile Pack.")
  case existing of
    Nothing -> pure ()
    Just pin
      | pinArtifact pin == identity -> Left (packAlreadyPresent identity "This exact Pack release is already installed in the selected profile.")
      | otherwise ->
          Left
            ( (appError Conflict "A different release of this Pack is already installed.")
                { appErrorSubject = Just (artifactName identity)
                , appErrorDetails = ["Installed: " <> artifactVersion (pinArtifact pin), "Candidate: " <> artifactVersion identity]
                , appErrorRecovery = [RecoveryAction "update-pack" "Review the signed update difference instead of overwriting the current pin." (Just ("lant packs update " <> artifactName identity))]
                }
            )
  validatePackInstallCandidate (packProfileTrustPolicy profile) enabled authenticated
  assessment <- assessPackTrust (packProfileObservedAt profile) (packProfileTrustPolicy profile) authenticated
  case assessedTrustClass assessment of
    RevokedPack ->
      Left
        ( (appError PermissionRequired "The Pack signer or archive is revoked and cannot be installed.")
            { appErrorSubject = Just (artifactName identity)
            , appErrorDetails = [authenticatedSignerFingerprint authenticated, artifactArchiveDigest identity]
            }
        )
    _ -> pure ()
  case assessedTrustClass assessment of
    UntrustedPack -> pure ()
    RevokedPack -> pure ()
    _ -> void (authorizePackInstall (packProfileObservedAt profile) (packProfileScope profile) (packProfileTrustPolicy profile) enabled authenticated)
  pure
    PackInstallDraft
      { packInstallSourcePath = packCandidateCanonicalPath candidate
      , packInstallSourceSha256 = packCandidateSourceSha256 candidate
      , packInstallArtifact = identity
      , packInstallSignerFingerprint = authenticatedSignerFingerprint authenticated
      , packInstallTrustClass = packTrustClassText (assessedTrustClass assessment)
      , packInstallEnabledComponents = Set.toAscList enabled
      , packInstallProfileRevision = packProfileRevision profile
      }

packAlreadyPresent :: PackArtifactIdentity -> Text -> AppError
packAlreadyPresent identity message =
  (appError Conflict message)
    { appErrorSubject = Just (artifactName identity)
    , appErrorRecovery = [RecoveryAction "show-pack" "Inspect the installed Pack instead." (Just ("lant packs show " <> artifactName identity))]
    }

packProfileChanged :: AppError
packProfileChanged =
  (appError Conflict "The selected profile integrations changed while they were being read.")
    { appErrorRetrySafety = RetryAfterRefresh
    , appErrorRecovery = [RecoveryAction "retry" "Retry to build a preview from one stable profile revision." Nothing]
    }

runPacksList :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runPacksList environment dryRun dataset =
  loadProfilePackProjections environment >>= \case
    Left problem -> pure (Left problem)
    Right packs ->
      pure . Right $
        PacksResult
          (loadedCursor dataset)
          "list"
          packs
          (appPackRegistryProblem environment)
          dryRun

runPacksShow :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runPacksShow environment dryRun dataset requested =
  loadProfilePackProjections environment >>= \case
    Left problem -> pure (Left problem)
    Right packs -> case filter ((== Text.strip requested) . projectedPackName) packs of
      [] ->
        pure . Left $
          (appError NotFound "The requested Pack is not installed in this profile.")
            { appErrorSubject = Just (Text.strip requested)
            , appErrorRecovery = [RecoveryAction "list-packs" "Inspect exact installed Pack names." (Just "lant packs list")]
            }
      [pack] -> pure . Right $ PacksResult (loadedCursor dataset) "show" [pack] (appPackRegistryProblem environment) dryRun
      _ ->
        pure . Left $
          (appError Conflict "Installed Pack names are not unique.")
            { appErrorSubject = Just (Text.strip requested)
            , appErrorRecovery = [RecoveryAction "diagnose" "Inspect the profile configuration before using Pack components." (Just "lant doctor")]
            }

loadProfilePackProjections :: AppEnv -> IO (Either AppError [PackProjection])
loadProfilePackProjections environment = do
  roots <- Profile.resolveXdgRoots
  let profile = actorProfile (appActor environment)
  Profile.loadProfile roots profile >>= \case
    Left problem -> pure (Left problem)
    Right (paths, _, _, _, integrations) -> case mkProfileScope profile of
      Left problem -> pure (Left problem)
      Right scope -> do
        now <- appNow environment
        loadStandardPackAuthorization now scope >>= \case
          Left problem -> pure (Left problem)
          Right standard -> do
            installed <- traverse (inspectConfiguredPack paths (appPackRegistryProblem environment)) (Map.elems (Profile.installedComponents integrations))
            pure (Right (packProjection (appPackRegistryProblem environment) standard : installed))

inspectConfiguredPack :: Profile.ProfilePaths -> Maybe AppError -> PackPin -> IO PackProjection
inspectConfiguredPack paths registryProblem pin = do
  let identity = pinArtifact pin
      fallback problem =
        PackProjection
          { projectedPackName = artifactName identity
          , projectedPackDisplayName = artifactName identity
          , projectedPackPublisher = artifactPublisher identity
          , projectedPackVersion = artifactVersion identity
          , projectedPackTrustClass = pinTrustText (pinTrustOrigin pin)
          , projectedPackStatus = "unavailable"
          , projectedPackArchiveDigest = artifactArchiveDigest identity
          , projectedPackSignerFingerprint = pinSignerFingerprint pin
          , projectedPackComponents =
              [ PackComponentProjection component "unknown" True [] [] [] []
              | component <- Set.toAscList (pinEnabledComponents pin)
              ]
          , projectedPackProblem = Just problem
          }
  inspectStoredPack (PackStoreConfig (Profile.packStoreDirectory paths)) (artifactArchiveDigest identity) >>= \case
    Left problem -> pure (fallback problem)
    Right authenticated
      | authenticatedPackIdentity authenticated /= identity || authenticatedSignerFingerprint authenticated /= pinSignerFingerprint pin ->
          pure (fallback (appError CorruptData "The configured Pack pin does not match the stored signed archive."))
      | otherwise -> pure (authenticatedPackProjection registryProblem pin authenticated)

packProjection :: Maybe AppError -> ExecutionAuthorizedPack -> PackProjection
packProjection registryProblem authorized =
  let authenticated = executionAuthorizedPack authorized
      pin = executionAuthorizedPin authorized
   in authenticatedPackProjection registryProblem pin authenticated

authenticatedPackProjection :: Maybe AppError -> PackPin -> AuthenticatedPack -> PackProjection
authenticatedPackProjection registryProblem pin authenticated =
  let manifest = structurallyValidManifest (authenticatedStructuralPack authenticated)
      enabled = pinEnabledComponents pin
   in PackProjection
        { projectedPackName = packName manifest
        , projectedPackDisplayName = packDisplayName manifest
        , projectedPackPublisher = packPublisher manifest
        , projectedPackVersion = packVersion manifest
        , projectedPackTrustClass = pinTrustText (pinTrustOrigin pin)
        , projectedPackStatus = maybe "enabled" (const "unavailable") registryProblem
        , projectedPackArchiveDigest = artifactArchiveDigest (authenticatedPackIdentity authenticated)
        , projectedPackSignerFingerprint = authenticatedSignerFingerprint authenticated
        , projectedPackComponents = componentProjection enabled <$> packComponents manifest
        , projectedPackProblem = Nothing
        }

componentProjection :: Set.Set Text -> PackComponent -> PackComponentProjection
componentProjection enabled component =
  let common = componentCommon component
      permissions = case component of
        DeclarativeComponent _ _ -> Nothing
        ExecutableComponent _ _ declared -> Just declared
   in PackComponentProjection
        { projectedPackComponentId = componentId common
        , projectedPackComponentKind = componentKindText (componentKind common)
        , projectedPackComponentEnabled = componentId common `Set.member` enabled
        , projectedPackComponentHttpHosts =
            maybe [] (Set.toAscList . Set.fromList . fmap httpPermissionHost . permissionHttp) permissions
        , projectedPackComponentCredentialSchemes =
            maybe [] (Set.toAscList . Set.fromList . fmap (credentialSchemeText . credentialSlotScheme) . permissionCredentialSlots) permissions
        , projectedPackComponentEffectPurposes =
            maybe [] (fmap effectPermissionText . permissionEffectPurposes) permissions
        , projectedPackComponentHostCapabilities =
            maybe [] (fmap hostCapabilityText . permissionHostCapabilities) permissions
        }

pinTrustText :: PinTrustOrigin -> Text
pinTrustText = \case
  PinBuiltIn -> "built in"
  PinVerifiedOfficial _ -> "verified official"
  PinTrustedPublisher -> "trusted publisher"

runDoctor :: AppEnv -> Bool -> (Integer -> IO ()) -> IO (Either AppError CommandResult)
runDoctor environment dryRun progress =
  diagnoseDataset (appStore environment) progress >>= \case
    Left problem ->
      pure . Right $
        DoctorResult
          Genesis
          False
          0
          [DiagnosticCheck "canonical_history" False (appErrorMessage problem) (Just problem)]
          dryRun
    Right diagnosis ->
      let dataset = diagnosedDataset diagnosis
          issue = diagnosisProblem diagnosis
          healthy = isNothing issue
          summary =
            maybe
              "Every canonical segment replayed successfully."
              appErrorMessage
              issue
       in pure . Right $
            DoctorResult
              (loadedCursor dataset)
              healthy
              (loadedEventCount dataset)
              [DiagnosticCheck "canonical_history" healthy summary issue]
              dryRun

runRepair :: AppEnv -> Bool -> (Integer -> IO ()) -> IO (Either AppError CommandResult)
runRepair environment dryRun progress = do
  recovered <- if dryRun then pure (Right Nothing) else recoverRepairCutover (appStore environment)
  case recovered of
    Left problem -> pure (Left problem)
    Right (Just result) -> repairCompletionResult environment dryRun Nothing result
    Right Nothing ->
      planDatasetRepair (appStore environment) >>= \case
        Left problem -> pure (Left problem)
        Right plan -> do
          diagnosis <- diagnoseDataset (appStore environment) progress
          case diagnosis of
            Left problem -> pure (Left problem)
            Right report -> do
              let dataset = diagnosedDataset report
                  state = loadedState dataset
              identity <- appAllocateUUID environment
              now <- appZonedNow environment
              candidateExists <- doesDirectoryExist (repairPlanCandidateRoot plan)
              if candidateExists
                then
                  buildRepairCandidate (appStore environment) plan >>= \case
                    Left problem -> pure (Left problem)
                    Right candidate ->
                      planRepairCutover (appStore environment) plan candidate >>= \case
                        Left problem -> pure (Left problem)
                        Right cutover -> do
                          let preview = repairPreviewEnvelope identity now state plan
                              envelope = repairCandidateEnvelope preview now state plan candidate cutover
                              checkpoint = PresentationCheckpoint envelope [] []
                          saveUnlessDry environment dryRun checkpoint
                          pure (Right (RepairResult (loadedCursor dataset) "candidate" envelope dryRun))
                else do
                  let envelope = repairPreviewEnvelope identity now state plan
                      checkpoint = PresentationCheckpoint envelope [] []
                  saveUnlessDry environment dryRun checkpoint
                  pure (Right (RepairResult (loadedCursor dataset) "preview" envelope dryRun))

runCorruptDatasetResponse :: AppEnv -> Bool -> InteractionResponse -> AppError -> IO (Either AppError CommandResult)
runCorruptDatasetResponse environment dryRun response originalProblem =
  loadPendingCheckpoint environment >>= \case
    Left problem -> pure (Left problem)
    Right Nothing -> pure (Left originalProblem)
    Right (Just checkpoint) -> do
      let current = checkpointCurrent checkpoint
      if not (isRepairOpportunity (envelopeOpportunity current))
        then pure (Left originalProblem)
        else case validateResponse current current response of
          Left problem -> pure (Left problem)
          Right ResponseStale{} -> pure (Left (appError Conflict "The repair question changed before this answer was applied."))
          Right ResponseAccepted{} -> runRepairResponse environment dryRun checkpoint response

runRepairResponse :: AppEnv -> Bool -> PresentationCheckpoint -> InteractionResponse -> IO (Either AppError CommandResult)
runRepairResponse environment dryRun checkpoint response =
  case envelopeOpportunity current of
    opportunity@RepairPreviewOpportunity{} -> respondToRepairPreview opportunity
    opportunity@RepairCandidateOpportunity{} -> respondToRepairCandidate opportunity
    _ -> pure (Left (appError PreconditionFailed "The pending interaction is not a repair checkpoint."))
 where
  current = checkpointCurrent checkpoint
  action = responseActionId response
  respondToRepairPreview (RepairPreviewOpportunity planHash source original replacement candidatePath validEvents)
    | action == "repair.assistance" = explain "A candidate is a complete separate dataset. Little Ant copies canonical material, applies only the displayed filename correction, then replays every event before offering cutover."
    | action == "repair.build" =
        planDatasetRepair (appStore environment) >>= \case
          Left problem -> pure (Left problem)
          Right plan
            | not (repairPreviewMatches plan planHash source original replacement candidatePath validEvents) -> pure (Left staleRepairQuestion)
            | dryRun -> explain "Dry run validated this repair plan. No candidate was created and cutover is unavailable until a real build succeeds."
            | otherwise ->
                buildRepairCandidate (appStore environment) plan >>= \case
                  Left problem -> pure (Left problem)
                  Right candidate ->
                    planRepairCutover (appStore environment) plan candidate >>= \case
                      Left problem -> pure (Left problem)
                      Right cutover -> do
                        diagnosis <- diagnoseDataset (appStore environment) (const (pure ()))
                        case diagnosis of
                          Left problem -> pure (Left problem)
                          Right report -> do
                            now <- appZonedNow environment
                            let state = loadedState (diagnosedDataset report)
                                envelope = repairCandidateEnvelope current now state plan candidate cutover
                                nextCheckpoint = PresentationCheckpoint envelope (current : checkpointBack checkpoint) []
                            savePendingCheckpoint environment nextCheckpoint
                            pure (Right (RespondResult (envelopeDatasetCursor envelope) envelope Nothing False))
    | otherwise = pure (Left unavailableRepairAction)
  respondToRepairPreview _ = pure (Left unavailableRepairAction)

  respondToRepairCandidate (RepairCandidateOpportunity repairHash cutoverHash source candidatePath backupPath candidateCursor candidateEvents)
    | action == "repair.assistance" = explain "Cutover first records this exact consent outside both datasets. It atomically exchanges their names, keeps the old live dataset as a read-only backup, and resumes only forward after interruption."
    | action == "repair.cutover" =
        planDatasetRepair (appStore environment) >>= \case
          Left problem -> pure (Left problem)
          Right plan
            | repairPlanHash plan /= repairHash || repairPlanSourceRoot plan /= source -> pure (Left staleRepairQuestion)
            | otherwise ->
                buildRepairCandidate (appStore environment) plan >>= \case
                  Left problem -> pure (Left problem)
                  Right candidate
                    | repairCandidateRoot candidate /= candidatePath
                        || repairCandidateCursor candidate /= candidateCursor
                        || repairCandidateEventCount candidate /= candidateEvents ->
                        pure (Left staleRepairQuestion)
                    | dryRun -> explain "Dry run revalidated the candidate and exact cutover inputs. No intent, exchange, or backup was written."
                    | otherwise ->
                        planRepairCutover (appStore environment) plan candidate >>= \case
                          Left problem -> pure (Left problem)
                          Right cutover
                            | cutoverPlanHash cutover /= cutoverHash || cutoverBackupRoot cutover /= backupPath -> pure (Left staleRepairQuestion)
                            | otherwise ->
                                executeRepairCutover (appStore environment) cutover >>= \case
                                  Left problem -> pure (Left problem)
                                  Right result -> repairCompletionResult environment False (Just current) result
    | otherwise = pure (Left unavailableRepairAction)
  respondToRepairCandidate _ = pure (Left unavailableRepairAction)

  explain message = do
    let envelope = appendBody current message
        nextCheckpoint = checkpoint{checkpointCurrent = envelope, checkpointBack = current : checkpointBack checkpoint, checkpointForward = []}
    saveUnlessDry environment dryRun nextCheckpoint
    pure (Right (RespondResult (envelopeDatasetCursor envelope) envelope Nothing dryRun))

repairCompletionResult :: AppEnv -> Bool -> Maybe InteractionEnvelope -> RepairCutoverResult -> IO (Either AppError CommandResult)
repairCompletionResult environment dryRun previous result =
  loadDataset (appStore environment) (const (pure ())) >>= \case
    Left problem -> pure (Left problem)
    Right dataset -> do
      identity <- appAllocateUUID environment
      now <- appZonedNow environment
      let state = loadedState dataset
          base = fromMaybe (makeSafeEmptyEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now) previous
          envelope =
            makeRepairCompleteEnvelope
              base
              (loadedCursor dataset)
              (statePreconditionHash state)
              now
              state
              (cutoverResultPlanHash result)
              (cutoverResultBackupRoot result)
              (cutoverResultRecovered result)
          checkpoint = PresentationCheckpoint envelope [] []
      saveUnlessDry environment dryRun checkpoint
      pure (Right (RepairResult (loadedCursor dataset) "complete" envelope dryRun))

repairPreviewEnvelope :: UUIDv7 -> ZonedTime -> State -> RepairPlan -> InteractionEnvelope
repairPreviewEnvelope identity now state plan =
  makeRepairPreviewEnvelope
    identity
    (repairPlanSourceCursor plan)
    (repairPlanHash plan)
    now
    state
    (repairPlanSourceRoot plan)
    (repairPlanOriginalSegment plan)
    (repairPlanReplacementSegment plan)
    (repairPlanCandidateRoot plan)
    (repairPlanValidEventCount plan)

repairCandidateEnvelope :: InteractionEnvelope -> ZonedTime -> State -> RepairPlan -> RepairCandidate -> RepairCutoverPlan -> InteractionEnvelope
repairCandidateEnvelope previous now state plan candidate cutover =
  makeRepairCandidateEnvelope
    previous
    now
    state
    (repairPlanHash plan)
    (cutoverPlanHash cutover)
    (repairPlanSourceRoot plan)
    (repairCandidateRoot candidate)
    (cutoverBackupRoot cutover)
    (repairCandidateCursor candidate)
    (repairCandidateEventCount candidate)

repairPreviewMatches :: RepairPlan -> Text -> FilePath -> FilePath -> FilePath -> FilePath -> Integer -> Bool
repairPreviewMatches plan planHash source original replacement candidate validEvents =
  and
    [ repairPlanHash plan == planHash
    , repairPlanSourceRoot plan == source
    , repairPlanOriginalSegment plan == original
    , repairPlanReplacementSegment plan == replacement
    , repairPlanCandidateRoot plan == candidate
    , repairPlanValidEventCount plan == validEvents
    ]

isRepairOpportunity :: Opportunity -> Bool
isRepairOpportunity = \case RepairPreviewOpportunity{} -> True; RepairCandidateOpportunity{} -> True; RepairCompleteOpportunity{} -> True; _ -> False

staleRepairQuestion :: AppError
staleRepairQuestion =
  (appError Conflict "The repair inputs changed after this question was rendered.")
    { appErrorRetrySafety = RetryAfterRefresh
    , appErrorRecovery = [RecoveryAction "repair" "Generate and review a fresh repair plan." (Just "lant repair")]
    }

unavailableRepairAction :: AppError
unavailableRepairAction =
  (appError InvalidInput "That action is not available at this repair checkpoint.")
    { appErrorRecovery = [RecoveryAction "continue" "Choose one action shown by the current repair envelope." Nothing]
    }

runProfileList :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runProfileList environment dryRun dataset = do
  roots <- Profile.resolveXdgRoots
  Profile.listProfiles roots >>= \case
    Left problem -> pure (Left problem)
    Right profiles ->
      pure . Right $
        ConfigurationResult
          (loadedCursor dataset)
          "profile_list"
          (Just (actorProfile (appActor environment)))
          profiles
          Map.empty
          dryRun

runProfileShow :: AppEnv -> Bool -> LoadedDataset -> Maybe Text -> IO (Either AppError CommandResult)
runProfileShow environment dryRun dataset requested = do
  roots <- Profile.resolveXdgRoots
  let name = fromMaybe (actorProfile (appActor environment)) requested
  Profile.loadProfile roots name >>= \case
    Left problem -> pure (Left problem)
    Right (paths, config, _, _, _) ->
      pure . Right $
        ConfigurationResult
          (loadedCursor dataset)
          "profile_show"
          (Just name)
          []
          (profileFacts paths config)
          dryRun

runProfileCreate :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runProfileCreate environment dryRun dataset name = do
  roots <- Profile.resolveXdgRoots
  case Profile.profilePaths roots name of
    Left problem -> pure (Left problem)
    Right paths ->
      if dryRun
        then pure (Right (configurationResult dataset "profile_create_preview" (Just name) (pathFacts paths) True))
        else do
          nonce <- appAllocateUUID environment
          Profile.createProfile roots name nonce >>= \case
            Left problem -> pure (Left problem)
            Right created -> pure (Right (configurationResult dataset "profile_create" (Just name) (pathFacts created) False))

runProfileUse :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runProfileUse _ dryRun dataset name = do
  roots <- Profile.resolveXdgRoots
  case Profile.profilePaths roots name of
    Left problem -> pure (Left problem)
    Right paths -> do
      exists <- doesDirectoryExist (Profile.profileDirectory paths)
      if not exists
        then
          pure . Left $
            (appError NotFound "The requested profile does not exist.")
              { appErrorSubject = Just name
              , appErrorRecovery = [RecoveryAction "create-profile" "Create it before selecting it." (Just ("lant profile create " <> name))]
              }
        else
          if dryRun
            then pure (Right (configurationResult dataset "profile_use_preview" (Just name) Map.empty True))
            else
              Profile.writeSelectedProfile roots name >>= \case
                Left problem -> pure (Left problem)
                Right () -> pure (Right (configurationResult dataset "profile_use" (Just name) Map.empty False))

runConfigShow :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runConfigShow environment dryRun dataset = do
  roots <- Profile.resolveXdgRoots
  let name = actorProfile (appActor environment)
  Profile.loadProfile roots name >>= \case
    Left problem -> pure (Left problem)
    Right (paths, config, preferences, calibration, integrations) ->
      pure . Right $
        configurationResult
          dataset
          "config_show"
          (Just name)
          ( profileFacts paths config
              <> Map.fromList
                [ ("presentation_language", Profile.preferredPresentationLanguage preferences)
                , ("color_mode", Profile.preferredColorMode preferences)
                , ("emoji_mode", Profile.preferredEmojiMode preferences)
                , ("calibration_parameters", Text.pack (show (Map.size (Profile.calibrationParameters calibration))))
                , ("installed_components", Text.pack (show (Map.size (Profile.installedComponents integrations))))
                , ("provider_accounts", Text.pack (show (Map.size (Profile.providerAccounts integrations))))
                , ("credential_bindings", Text.pack (show (Map.size (Profile.credentialBindings integrations))))
                ]
          )
          dryRun

runConfigPaths :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runConfigPaths environment dryRun dataset = do
  roots <- Profile.resolveXdgRoots
  pure $ do
    paths <- Profile.profilePaths roots (actorProfile (appActor environment))
    Right (configurationResult dataset "config_paths" (Just (actorProfile (appActor environment))) (pathFacts paths) dryRun)

runConfigValidate :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runConfigValidate environment dryRun dataset = do
  roots <- Profile.resolveXdgRoots
  let name = actorProfile (appActor environment)
  Profile.loadProfile roots name >>= \case
    Left problem -> pure (Left problem)
    Right (paths, config, _, _, _) ->
      pure (Right (configurationResult dataset "config_validate" (Just name) (profileFacts paths config) dryRun))

data ConnectionProfileSnapshot = ConnectionProfileSnapshot
  { connectionProfilePaths :: Profile.ProfilePaths
  , connectionProfileIntegrations :: Profile.IntegrationsConfig
  , connectionProfileRevision :: Text
  , connectionProfileRegistry :: PackRegistry
  }

runConfigConnect :: AppEnv -> Bool -> LoadedDataset -> Text -> Text -> Text -> Text -> IO (Either AppError CommandResult)
runConfigConnect environment dryRun dataset source account label clientId =
  case appProviderConnectionRuntime environment of
    Nothing -> pure . Left $ providerConnectionUnavailable "This host cannot run provider connection flows."
    Just runtime ->
      loadConnectionProfileSnapshot environment >>= \case
        Left problem -> pure (Left problem)
        Right profile -> do
          vaultEntry <- appAllocateUUID environment
          case prepareProviderConnectionDraft
            (providerConnectionDefinitions runtime)
            (connectionProfileRegistry profile)
            (connectionProfileIntegrations profile)
            (connectionProfileRevision profile)
            source
            account
            label
            clientId
            vaultEntry of
            Left problem -> pure (Left problem)
            Right draft -> do
              identity <- appAllocateUUID environment
              now <- appZonedNow environment
              let state = loadedState dataset
                  envelope = makeProviderConnectionEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now state draft
              saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
              pure (Right (NextResult (loadedCursor dataset) envelope dryRun))

loadConnectionProfileSnapshot :: AppEnv -> IO (Either AppError ConnectionProfileSnapshot)
loadConnectionProfileSnapshot environment = do
  roots <- Profile.resolveXdgRoots
  let profileName = actorProfile (appActor environment)
  case Profile.profilePaths roots profileName of
    Left problem -> pure (Left problem)
    Right expectedPaths ->
      Profile.integrationsConfigRevision expectedPaths >>= \case
        Left problem -> pure (Left problem)
        Right beforeRevision ->
          Profile.loadProfile roots profileName >>= \case
            Left problem -> pure (Left problem)
            Right (paths, _, _, _, integrations) ->
              Profile.integrationsConfigRevision paths >>= \case
                Left problem -> pure (Left problem)
                Right afterRevision
                  | beforeRevision /= afterRevision -> pure (Left packProfileChanged)
                  | otherwise -> case mkProfileScope profileName of
                      Left problem -> pure (Left problem)
                      Right scope -> do
                        now <- appNow environment
                        case compiledOfficialCatalogRoot of
                          Left problem -> pure (Left problem)
                          Right root ->
                            loadProfilePackRegistry now scope paths integrations (OfficialCatalogCompiledRoot root) >>= \case
                              Left problem -> pure (Left problem)
                              Right registry ->
                                pure . Right $
                                  ConnectionProfileSnapshot
                                    { connectionProfilePaths = paths
                                    , connectionProfileIntegrations = integrations
                                    , connectionProfileRevision = afterRevision
                                    , connectionProfileRegistry = registry
                                    }

providerConnectionUnavailable :: Text -> AppError
providerConnectionUnavailable message =
  (appError Unsupported message)
    { appErrorRecovery =
        [ RecoveryAction "production-host" "Use the ordinary Little Ant CLI or REPL host." Nothing
        , RecoveryAction "packs" "Install and inspect the signed provider Pack first." (Just "lant packs list")
        ]
    }

ensureConnectionVaultUnlocked :: Profile.ProfilePaths -> IO (Either AppError ())
ensureConnectionVaultUnlocked paths =
  sendVaultAgentRequest (Profile.vaultSocket paths) agentStatusRequest >>= \case
    Right reply | agentReplyUnlocked reply == Just True -> pure (Right ())
    Right _ -> pure (Left locked)
    Left problem ->
      pure . Left $
        locked
          { appErrorDetails = appErrorMessage problem : appErrorDetails problem
          }
 where
  locked =
    (appError PermissionRequired "Credentials are unavailable or locked.")
      { appErrorRecovery =
          [ RecoveryAction "unlock" "Create or unlock this profile's encrypted vault, then accept the unchanged connection preview again." (Just "lant vault unlock")
          , RecoveryAction "create" "Create the encrypted vault first if this profile has none." (Just "lant vault create")
          ]
      }

runTransientDeviceAuthorization :: AppEnv -> ProviderConnectionRuntime -> OAuthDeviceClient -> IO (Either AppError OAuthTokenSet)
runTransientDeviceAuthorization environment runtime client = do
  startedAt <- appNow environment
  beginDeviceAuthorization (providerConnectionOAuthTransport runtime) startedAt client >>= \case
    Left problem -> pure (Left problem)
    Right session -> do
      providerConnectionPresentPrompt runtime (deviceAuthorizationPrompt session)
      poll session (devicePromptPollingIntervalSeconds (deviceAuthorizationPrompt session))
 where
  poll session delay = do
    providerConnectionWaitSeconds runtime delay
    now <- appNow environment
    pollDeviceAuthorization (providerConnectionOAuthTransport runtime) now client session >>= \case
      Left problem -> pure (Left problem)
      Right (DeviceAuthorizationPending nextDelay nextSession) -> poll nextSession nextDelay
      Right (DeviceAuthorizationSucceeded tokenSet) -> pure (Right tokenSet)
      Right DeviceAuthorizationDeclined ->
        pure . Left $
          (appError PermissionRequired "The provider authorization was declined.")
            { appErrorRecovery = [RecoveryAction "try-again" "Accept the unchanged connection preview when you are ready to authorize it." Nothing]
            }
      Right DeviceAuthorizationExpired ->
        pure . Left $
          (appError PreconditionFailed "The provider authorization code expired.")
            { appErrorRecovery = [RecoveryAction "try-again" "Accept the unchanged connection preview to request a new code." Nothing]
            }

configurationResult :: LoadedDataset -> Text -> Maybe Text -> Map.Map Text Text -> Bool -> CommandResult
configurationResult dataset action selected facts =
  ConfigurationResult (loadedCursor dataset) action selected [] facts

profileFacts :: Profile.ProfilePaths -> Profile.ProfileConfig -> Map.Map Text Text
profileFacts paths config =
  pathFacts paths
    <> Map.fromList
      [ ("dataset", Text.pack (Profile.configuredDataset config))
      , ("vault_name", Profile.configuredVaultName config)
      ]

pathFacts :: Profile.ProfilePaths -> Map.Map Text Text
pathFacts paths =
  Map.fromList
    [ ("selection", Text.pack (Profile.selectionPath paths))
    , ("profile", Text.pack (Profile.profileFile paths))
    , ("preferences", Text.pack (Profile.preferencesFile paths))
    , ("calibration", Text.pack (Profile.calibrationFile paths))
    , ("integrations", Text.pack (Profile.integrationsFile paths))
    , ("vault", Text.pack (Profile.vaultFile paths))
    , ("pack_store", Text.pack (Profile.packStoreDirectory paths))
    , ("official_pack_catalog", Text.pack (Profile.officialCatalogStateFile paths))
    , ("state", Text.pack (Profile.profileStateDirectory paths))
    , ("dataset", Text.pack (Profile.datasetDirectory paths))
    , ("vault_socket", Text.pack (Profile.vaultSocket paths))
    ]

runNotices :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runNotices environment dryRun dataset = do
  identity <- appAllocateUUID environment
  now <- appZonedNow environment
  let state = loadedState dataset
      envelope = makeNoticeListEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now state (noticeCandidates state (zonedTimeToUTC now))
      checkpoint = PresentationCheckpoint envelope [] []
  saveUnlessDry environment dryRun checkpoint
  pure (Right (NextResult (loadedCursor dataset) envelope dryRun))

runHistory :: AppEnv -> Bool -> LoadedDataset -> Maybe Int -> IO (Either AppError CommandResult)
runHistory environment dryRun dataset maybeLimit = do
  let store = appStore environment
  loadedEvents <- readHistoryEvents store
  case loadedEvents of
    Left problem -> pure (Left problem)
    Right events ->
      pure . Right $
        HistoryResult
          (loadedCursor dataset)
          (selectHistoryLimit maybeLimit (toHistoryEntries events))
          dryRun

readHistoryEvents :: StoreConfig -> IO (Either AppError [PersistedEvent])
readHistoryEvents store = do
  let root = storeRoot store </> "events"
  exists <- doesDirectoryExist root
  if not exists
    then pure (Right [])
    else do
      names <- sort <$> listDirectory root
      let segmentFiles = [root </> name | name <- names, takeExtension name == ".jsonl"]
      results <- traverse readSegmentEvents segmentFiles
      pure (concat <$> sequence results)

readSegmentEvents :: FilePath -> IO (Either AppError [PersistedEvent])
readSegmentEvents path = do
  bytes <- ByteString.readFile path
  let linesInSegment = filter (not . ByteString.null) (ByteString.split 10 bytes)
  pure (traverse decodeEvent linesInSegment)

selectHistoryLimit :: Maybe Int -> [HistoryEntry] -> [HistoryEntry]
selectHistoryLimit Nothing history = reverse history
selectHistoryLimit (Just limit) history
  | limit <= 0 = []
  | otherwise = reverse (take limit (reverse history))

chunkByCommand :: [PersistedEvent] -> [[PersistedEvent]]
chunkByCommand [] = []
chunkByCommand (first : rest) =
  let (same, remaining) = span ((== persistedCommandId first) . persistedCommandId) rest
   in (first : same) : chunkByCommand remaining

toHistoryEntries :: [PersistedEvent] -> [HistoryEntry]
toHistoryEntries = fmap toHistoryEntry . chunkByCommand
 where
  toHistoryEntry grouped =
    let headEvent = head grouped
     in HistoryEntry
          { historyCommandId = persistedCommandId headEvent
          , historyRecordedAt = persistedRecordedAt headEvent
          , historyActor = persistedActor headEvent
          , historyEventCount = length grouped
          , historyEventTypes = fmap (eventTypeName . persistedPayload) grouped
          }

applyNoticeFrameToResult :: AppEnv -> Bool -> LoadedDataset -> Either AppError CommandResult -> IO (Either AppError CommandResult)
applyNoticeFrameToResult _ _ _ result@(Left _) = pure result
applyNoticeFrameToResult environment dryRun fallback (Right result) = do
  framedState <-
    if dryRun
      then pure (loadedState fallback)
      else loadDataset (appStore environment) (const (pure ())) >>= pure . either (const (loadedState fallback)) loadedState
  now <- appZonedNow environment
  let framed = mapResultInteraction (decorateNoticeFrame framedState now) result
  case resultInteractionMaybe framed of
    Nothing -> pure ()
    Just interaction ->
      if dryRun
        then pure ()
        else
          loadPendingCheckpoint environment >>= \case
            Right (Just checkpoint)
              | envelopeInteractionId (checkpointCurrent checkpoint) == envelopeInteractionId interaction ->
                  savePendingCheckpoint environment checkpoint{checkpointCurrent = interaction}
            _ -> pure ()
  pure (Right framed)

mapResultInteraction :: (InteractionEnvelope -> InteractionEnvelope) -> CommandResult -> CommandResult
mapResultInteraction transform = \case
  result@NextResult{resultInteraction} -> result{resultInteraction = transform resultInteraction}
  result@RespondResult{resultInteraction} -> result{resultInteraction = transform resultInteraction}
  result@FeedResult{resultInteraction} -> result{resultInteraction = transform resultInteraction}
  result@UndoResult{resultInteraction} -> result{resultInteraction = transform resultInteraction}
  result -> result

resultInteractionMaybe :: CommandResult -> Maybe InteractionEnvelope
resultInteractionMaybe = \case
  NextResult{resultInteraction} -> Just resultInteraction
  RespondResult{resultInteraction} -> Just resultInteraction
  FeedResult{resultInteraction} -> Just resultInteraction
  UndoResult{resultInteraction} -> Just resultInteraction
  _ -> Nothing

decorateNoticeFrame :: State -> ZonedTime -> InteractionEnvelope -> InteractionEnvelope
decorateNoticeFrame state now envelope
  | envelopeGrammar envelope `notElem` [FocusGrammar, ChoiceGrammar] = clearNotice
  | null candidates = clearNotice
  | otherwise =
      let selected = candidates !! (envelopeNoticeTurn envelope `mod` length candidates)
          brick = candidateNoticeBrick selected
          identity = candidateNoticeIdentity selected
          summary = renderHandle BrickHandle (brickHandle brick) <> " \"" <> brickTitle brick <> "\" · " <> Text.toLower (noticeKindLabel (noticeKind identity))
       in resealEnvelope envelope{envelopeFooter = (envelopeFooter envelope){footerNotice = Just summary, footerNoticeCount = length candidates}}
 where
  candidates = activeNoticeCandidates state (zonedTimeToUTC now)
  clearNotice = resealEnvelope envelope{envelopeFooter = (envelopeFooter envelope){footerNotice = Nothing, footerNoticeCount = 0}}

runDirectMutation :: AppEnv -> Bool -> LoadedDataset -> Int -> (RuntimeFacts -> Either AppError MutationDecision) -> IO (Either AppError CommandResult)
runDirectMutation environment dryRun dataset count decide = do
  facts <- runtimeFacts environment count (loadedCursor dataset)
  case decide facts of
    Left problem -> pure (Left problem)
    Right mutation ->
      persistOrSimulate environment dryRun dataset (mutationDecisionEvents mutation) >>= \case
        Left problem -> pure (Left problem)
        Right accepted ->
          freshCheckpoint environment accepted >>= \case
            Left problem -> pure (Left problem)
            Right checkpoint -> do
              saveUnlessDry environment dryRun checkpoint
              pure . Right $
                RespondResult
                  (loadedCursor accepted)
                  (checkpointCurrent checkpoint)
                  (Just (mutationDecisionCommandId mutation))
                  dryRun

advanceDueTemporal :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError (LoadedDataset, TemporalTickPlan))
advanceDueTemporal environment dryRun dataset = do
  now <- appNow environment
  buildTemporalTickPlan (loadedState dataset) now >>= \case
    Left problem -> pure (Left problem)
    Right plan
      | temporalTickUUIDCount plan == 0 -> pure (Right (dataset, plan))
      | otherwise -> do
          facts <- runtimeFacts environment (temporalTickUUIDCount plan) (loadedCursor dataset)
          case decideTemporalTick (loadedState dataset) (Actor "system" (actorProfile (appActor environment))) plan facts of
            Left problem -> pure (Left problem)
            Right Nothing -> pure (Right (dataset, plan))
            Right (Just mutation) ->
              persistOrSimulate environment dryRun dataset (mutationDecisionEvents mutation) >>= \case
                Left problem -> pure (Left problem)
                Right accepted -> pure (Right (accepted, plan))

runNext :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runNext environment dryRun dataset = do
  now <- appZonedNow environment
  if dryRun
    then createRecordedForecastCheckpoint environment True dataset >>= pure . fmap result
    else
      if not (null (activeScheduledCommitments (loadedState dataset) (zonedTimeToUTC now)))
        then
          createRecordedForecastCheckpoint environment False dataset >>= \case
            Left problem -> pure (Left problem)
            Right (accepted, checkpoint) -> do
              savePendingCheckpoint environment checkpoint
              pure (Right (NextResult (loadedCursor accepted) (checkpointCurrent checkpoint) False))
        else
          loadPendingCheckpoint environment >>= \case
            Left problem -> pure (Left problem)
            Right (Just checkpoint)
              | checkpointIsFresh dataset checkpoint ->
                  pure (Right (NextResult (loadedCursor dataset) (checkpointCurrent checkpoint) False))
            Right _ ->
              createRecordedForecastCheckpoint environment False dataset >>= \case
                Left problem -> pure (Left problem)
                Right (accepted, checkpoint) -> do
                  savePendingCheckpoint environment checkpoint
                  pure (Right (NextResult (loadedCursor accepted) (checkpointCurrent checkpoint) False))
 where
  result (accepted, checkpoint) = NextResult (loadedCursor accepted) (checkpointCurrent checkpoint) True

createRecordedForecastCheckpoint :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError (LoadedDataset, PresentationCheckpoint))
createRecordedForecastCheckpoint environment dryRun dataset = do
  interactionId <- appAllocateUUID environment
  now <- appZonedNow environment
  let state = loadedState dataset
      cursor = loadedCursor dataset
      precondition = statePreconditionHash state
  case activeScheduledCommitments state (zonedTimeToUTC now) of
    [(brick, interval)] ->
      pure . Right $ (dataset, PresentationCheckpoint (makeScheduledCommitmentEnvelope interactionId cursor precondition now state brick interval) [] [])
    commitments@(_ : _ : _) ->
      pure . Right $ (dataset, PresentationCheckpoint (makeScheduledOverlapEnvelope interactionId cursor precondition now state commitments) [] [])
    []
      | Just brick <- stateCurrentFocus state >>= (\identity -> Map.lookup identity (stateBricks state))
      , brickStatus brick == BrickActive ->
          pure . Right $ (dataset, PresentationCheckpoint (activeFocusEnvelope interactionId cursor precondition now state brick) [] [])
    _
      | Just (brick, review) <- pendingRepeatableReturn state ->
          pure . Right $ (dataset, PresentationCheckpoint (makeRepeatableReturnEnvelope interactionId cursor precondition now state brick review) [] [])
    _
      | stateEventCount state == 0 ->
          pure . Right $ (dataset, PresentationCheckpoint (makePristineEnvelope interactionId cursor precondition now) [] [])
    _ -> do
      seed <- maybe (Entropy.getEntropy 32) pure (stateRandomSeed state)
      let tickets = fmap supportedTicket (World.buildForecastWorld state (zonedTimeToUTC now))
          purposeCursors =
            Map.fromList
              [ (purpose, Map.findWithDefault 0 (randomPurposeName purpose) (stateRandomCursors state))
              | purpose <- randomPurposeRegistry
              ]

          hardScope = domainScopeTarget <$> stateDomainScope state
          activePath =
            if isJust hardScope
              then Nothing
              else stateActiveDomain state >>= domainIdentityPath state
      case World.selectForecast seed purposeCursors activePath hardScope tickets of
        Left problem ->
          pure . Left $
            (appError CorruptData "The focus forecast could not produce a replay-safe result.")
              { appErrorDetails = [problem]
              , appErrorRecovery = [RecoveryAction "inspect" "Inspect forecast gates and dataset integrity." (Just "lant list forecast")]
              }
        Right World.EmptyForecast{} ->
          case stateDomainScope state of
            Just DomainScope{domainScopeMode = OneSuggestion} -> do
              facts <- runtimeFacts environment 2 cursor
              case decideDomainFocus state (appActor environment) Nothing Nothing facts of
                Left problem -> pure (Left problem)
                Right mutation ->
                  persistOrSimulate environment dryRun dataset (mutationDecisionEvents mutation) >>= \case
                    Left problem -> pure (Left problem)
                    Right accepted ->
                      let acceptedState = loadedState accepted
                          envelope = makeSafeEmptyEnvelope interactionId (loadedCursor accepted) (statePreconditionHash acceptedState) now
                       in pure . Right $ (accepted, PresentationCheckpoint envelope [] [])
            _ ->
              pure . Right $ (dataset, PresentationCheckpoint (makeSafeEmptyEnvelope interactionId cursor precondition now) [] [])
        Right selection -> persistForecastSelection environment dryRun dataset interactionId now seed selection
 where
  supportedTicket ticket =
    ticket
      { World.ticketOpportunities =
          filter
            (isSupported . World.selectableKind)
            (World.ticketOpportunities ticket)
      }
  isSupported kind =
    kind
      `elem` [ World.FiniteWorkOpportunity
             , World.RepeatableRunOpportunity
             , World.HabitWindowOpportunity
             , World.LivingChecklistRunOpportunity
             , World.FiniteChecklistRunOpportunity
             , World.RawTriageOpportunity
             , World.ArchiveRelevanceReviewOpportunity
             , World.WaitReviewOpportunity
             , World.DelegationReviewOpportunity
             , World.DelegationCompletionReviewOpportunity
             , World.DelegationRefusalReviewOpportunity
             , World.ExternalEffectApprovalOpportunity
             ]

persistForecastSelection ::
  AppEnv ->
  Bool ->
  LoadedDataset ->
  UUIDv7 ->
  ZonedTime ->
  ByteString ->
  World.ForecastSelection ->
  IO (Either AppError (LoadedDataset, PresentationCheckpoint))
persistForecastSelection environment dryRun dataset selectionId now seed selection = do
  eventId <- appAllocateUUID environment
  commandId <- appAllocateUUID environment
  let state = loadedState dataset
      evidence = forecastEvidence selectionId seed selection
      event =
        EventDraft
          eventId
          commandId
          (appActor environment)
          (zonedTimeToUTC now)
          (statePreconditionHash state)
          [selectionId, eventId, commandId]
          (ForecastSelectedV1 (ForecastSelected evidence))
  persisted <- persistOrSimulate environment dryRun dataset [event]
  case persisted of
    Left problem -> pure (Left problem)
    Right accepted ->
      let acceptedState = loadedState accepted
          acceptedCursor = loadedCursor accepted
          acceptedPrecondition = statePreconditionHash acceptedState
          makeCheckpoint envelope = Right (accepted, PresentationCheckpoint envelope [] [])
       in pure $ case selection of
            World.SelectedOpportunity{World.selectedEndpointSubject = endpoint, World.selectedOpportunity = opportunity} ->
              case World.selectableKind opportunity of
                World.RawTriageOpportunity ->
                  maybe
                    (Left (appError CorruptData "The selected Raw is missing after forecast replay."))
                    (makeCheckpoint . makeRawTriageEnvelope selectionId acceptedCursor acceptedPrecondition now acceptedState)
                    (Map.lookup endpoint (stateRaws acceptedState))
                World.ArchiveRelevanceReviewOpportunity ->
                  case [ review
                       | review <- Map.elems (stateLazyReviews acceptedState)
                       , lazyReviewSubject review == endpoint
                       , lazyReviewKind review == "archive_relevance_review"
                       ] of
                    review : _ ->
                      maybe
                        (Left (appError CorruptData "The archived review subject is missing after forecast replay."))
                        (\brick -> makeCheckpoint (makeArchiveReviewEnvelope selectionId acceptedCursor acceptedPrecondition now acceptedState brick review))
                        (Map.lookup endpoint (stateBricks acceptedState))
                    [] -> Left (appError CorruptData "The selected archive relevance review is missing after forecast replay.")
                World.WaitReviewOpportunity ->
                  case dueWait acceptedState endpoint (zonedTimeToUTC now) of
                    Just gate ->
                      maybe
                        (Left (appError CorruptData "The selected Wait subject is missing after forecast replay."))
                        (\brick -> makeCheckpoint (makeWaitReviewEnvelope selectionId acceptedCursor acceptedPrecondition now acceptedState brick gate))
                        (Map.lookup endpoint (stateBricks acceptedState))
                    Nothing -> Left (appError CorruptData "The selected Wait review is missing after forecast replay.")
                kind
                  | kind
                      `elem` [ World.DelegationReviewOpportunity
                             , World.DelegationCompletionReviewOpportunity
                             , World.DelegationRefusalReviewOpportunity
                             ] ->
                      case dueDelegation acceptedState endpoint (zonedTimeToUTC now) of
                        Just delegation ->
                          maybe
                            (Left (appError CorruptData "The selected Delegation subject is missing after forecast replay."))
                            (\brick -> makeCheckpoint (makeDelegationReviewEnvelope selectionId acceptedCursor acceptedPrecondition now acceptedState brick delegation))
                            (Map.lookup endpoint (stateBricks acceptedState))
                        Nothing -> Left (appError CorruptData "The selected Delegation review is missing after forecast replay.")
                World.ExternalEffectApprovalOpportunity ->
                  case pendingEffect acceptedState endpoint of
                    Just effect ->
                      maybe
                        (Left (appError CorruptData "The selected external-effect subject is missing after forecast replay."))
                        (\brick -> makeCheckpoint (makeExternalEffectApprovalEnvelope selectionId acceptedCursor acceptedPrecondition now acceptedState brick effect))
                        (Map.lookup endpoint (stateBricks acceptedState))
                    Nothing -> Left (appError CorruptData "The selected external-effect approval is missing after forecast replay.")
                World.ExternalEffectRecoveryOpportunity ->
                  case recoverableEffect acceptedState endpoint of
                    Just effect ->
                      maybe
                        (Left (appError CorruptData "The selected external-effect subject is missing after forecast replay."))
                        (\brick -> makeCheckpoint (makeExternalEffectRecoveryEnvelope selectionId acceptedCursor acceptedPrecondition now acceptedState brick effect))
                        (Map.lookup endpoint (stateBricks acceptedState))
                    Nothing -> Left (appError CorruptData "The selected external-effect recovery is missing after forecast replay.")
                _ ->
                  maybe
                    (Left (appError CorruptData "The selected Brick is missing after forecast replay."))
                    (\brick -> makeCheckpoint (makeRecordedFocusProposalEnvelope selectionId acceptedCursor acceptedPrecondition now acceptedState brick evidence))
                    (Map.lookup endpoint (stateBricks acceptedState))
            World.SelectedRecovery{} ->
              makeCheckpoint
                ( appendBody
                    (makeSafeEmptyEnvelope selectionId acceptedCursor acceptedPrecondition now)
                    "The selected subject currently ends at a typed non-Brick gate; inspect the blocker path before choosing another focus."
                )
            World.EmptyForecast{} -> makeCheckpoint (makeSafeEmptyEnvelope selectionId acceptedCursor acceptedPrecondition now)
 where
  dueWait state brickIdentity instant =
    safeFirst . sortOn waitId $
      [ gate
      | gate <- Map.elems (stateWaits state)
      , waitAffectedBrick gate == brickIdentity
      , waitStatus gate == WaitActive
      , zonedInstantUtc (waitReviewNotBefore gate) <= instant
      , maybe True (<= instant) (waitReviewCooldownUntil gate)
      ]
  dueDelegation state brickIdentity instant =
    safeFirst . sortOn delegationId $
      [ delegation
      | delegation <- Map.elems (stateDelegations state)
      , delegationBrick delegation == brickIdentity
      , delegationStatus delegation == DelegationActive
      , maybe False ((<= instant) . zonedInstantUtc) (delegationReviewNotBefore delegation)
      ]
  pendingEffect state brickIdentity =
    safeFirst . sortOn externalEffectId $
      [ effect
      | effect <- Map.elems (stateExternalEffects state)
      , externalEffectStatus effect == EffectPendingApproval
      , maybe True ((<= zonedTimeToUTC now) . zonedInstantUtc) (externalEffectReviewNotBefore effect)
      , Just delegation <- [Map.lookup (externalEffectDelegation effect) (stateDelegations state)]
      , delegationBrick delegation == brickIdentity
      ]
  recoverableEffect state brickIdentity =
    safeFirst . sortOn externalEffectId $
      [ effect
      | effect <- Map.elems (stateExternalEffects state)
      , externalEffectStatus effect `elem` [EffectFailed, EffectOutcomeUnknown]
      , Just delegation <- [Map.lookup (externalEffectDelegation effect) (stateDelegations state)]
      , delegationBrick delegation == brickIdentity
      ]

forecastEvidence :: UUIDv7 -> ByteString -> World.ForecastSelection -> ForecastSelectionEvidence
forecastEvidence selectionId seed selection =
  case selection of
    World.SelectedOpportunity original endpoint opportunity path domain draws _ ->
      common original (Just endpoint) (World.opportunityKindName (World.selectableKind opportunity)) path domain draws
    World.SelectedRecovery original endpoint path draws _ ->
      common original Nothing ("recovery:" <> Text.pack (show endpoint)) path Nothing draws
    World.EmptyForecast reason ->
      ForecastSelectionEvidence selectionId (profileHash factoryForecastProfile) seed [] selectionId Nothing ("empty:" <> reason) [] Nothing Nothing [] []
 where
  common original endpoint kind path domain draws =
    let admitted = case draws of
          first : _ ->
            mapMaybe
              (\candidate -> (,drawCandidateWeight candidate) <$> either (const Nothing) Just (parseUUIDv7 (drawCandidateIdentity candidate)))
              (drawCandidates first)
          [] -> []
        selectedRootSignal = Nothing
     in ForecastSelectionEvidence
          selectionId
          (profileHash factoryForecastProfile)
          seed
          admitted
          original
          endpoint
          kind
          path
          domain
          selectedRootSignal
          []
          (fmap drawEvidence draws)
  drawEvidence draw =
    ForecastDrawEvidence
      (randomPurposeName (drawPurpose draw))
      [(drawCandidateIdentity candidate, drawCandidateWeight candidate) | candidate <- drawCandidates draw]
      (drawTotal draw)
      (drawStartingCursor draw)
      (drawEndingCursor draw)
      (drawSampledInteger draw)
      (drawChosenIdentity draw)

runOrder :: AppEnv -> Bool -> LoadedDataset -> Maybe Text -> IO (Either AppError CommandResult)
runOpenRaw :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runOpenRaw environment dryRun dataset reference =
  case resolveAnyRawReference (loadedState dataset) reference of
    Left problem -> pure (Left problem)
    Right raw -> do
      identity <- appAllocateUUID environment
      now <- appZonedNow environment
      let state = loadedState dataset
          envelope = makeRawDetailEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now state raw
      saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
      pure (Right (NextResult (loadedCursor dataset) envelope dryRun))

runTranslate :: AppEnv -> Bool -> LoadedDataset -> Maybe Text -> IO (Either AppError CommandResult)
runTranslate environment dryRun dataset reference = do
  identity <- appAllocateUUID environment
  now <- appZonedNow environment
  let state = loadedState dataset
      cursor = loadedCursor dataset
      precondition = statePreconditionHash state
      defaultScope = TranslationScope True True False
      (titleCount, rawCountValue, unsupportedCount) = translationScopeCounts state defaultScope
      scopeEnvelope = makeTranslationScopeEnvelope identity cursor precondition now state defaultScope titleCount rawCountValue unsupportedCount
  result <- case reference of
    Nothing -> pure (Right scopeEnvelope)
    Just target -> case resolveTranslationTarget state target of
      Left problem -> pure (Left problem)
      Right candidate ->
        let queue = TranslationQueue defaultScope [candidate] 0 0 1
         in pure (Right (makeTranslationEditorEnvelope scopeEnvelope now state queue Nothing Nothing))
  case result of
    Left problem -> pure (Left problem)
    Right envelope -> do
      saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
      pure (Right (NextResult cursor envelope dryRun))
runOrder environment dryRun dataset reference = do
  identity <- appAllocateUUID environment
  now <- appZonedNow environment
  let state = loadedState dataset
      cursor = loadedCursor dataset
      precondition = statePreconditionHash state
      scopeEnvelope = makeOrderScopeEnvelope identity cursor precondition now state
  result <- case reference of
    Nothing -> pure (Right scopeEnvelope)
    Just selected -> case resolveOrderScope state selected of
      Left problem -> pure (Left problem)
      Right scope -> pure (Right (startOrderEnvelope now state scopeEnvelope (orderSessionFor state (zonedTimeToUTC now) ContinuousOrder scope)))
  case result of
    Left problem -> pure (Left problem)
    Right envelope -> do
      saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
      pure (Right (NextResult cursor envelope dryRun))

runFocus :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runFocus environment dryRun dataset reference =
  startBrickInteraction environment dryRun dataset reference $ \identity cursor precondition now state brick ->
    case stateCurrentFocus state of
      Just current | current == brickId brick -> activeFocusEnvelope identity cursor precondition now state brick
      _ -> makeFocusProposalEnvelope identity cursor precondition now state brick

runFocusBlocker :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runFocusBlocker environment dryRun dataset reference =
  case resolveBrickReference (loadedState dataset) reference of
    Left problem -> pure (Left problem)
    Right brick ->
      case latestVisibleBlocker (loadedState dataset) of
        Just identity
          | identity == brickId brick ->
              startBrickInteraction environment dryRun dataset reference makeFocusProposalEnvelope
        _ ->
          pure . Left $
            (appError PreconditionFailed "The named Brick is not the executable endpoint of a visible blocker chain.")
              { appErrorRecovery =
                  [ RecoveryAction "next" "Restore the recorded blocker chain before focusing its endpoint." (Just "lant next")
                  , RecoveryAction "focus" "Use ordinary focus when choosing unrelated Work directly." (Just ("lant focus " <> reference))
                  ]
              }
 where
  latestVisibleBlocker state =
    case reverse (Map.elems (stateForecastSelections state)) of
      evidence : _ ->
        case forecastSelectionDependencyPath evidence of
          _ : _ : _ -> forecastSelectionEndpointSubject evidence
          _ -> Nothing
      [] -> Nothing

runTieBreak :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runTieBreak environment dryRun dataset =
  loadPendingCheckpoint environment >>= \case
    Left problem -> pure (Left problem)
    Right Nothing -> pure (Left (appError PreconditionFailed "/tie-break requires one pending importance comparison."))
    Right (Just checkpoint) -> case envelopeOpportunity (checkpointCurrent checkpoint) of
      ImportanceReviewOpportunity{} ->
        let envelope = checkpointCurrent checkpoint
            response =
              InteractionResponse
                (envelopeInteractionId envelope)
                (envelopeRevision envelope)
                "importance.tie-break"
                (envelopeIntegrityToken envelope)
                (envelopeDatasetCursor envelope)
         in if envelopeDatasetCursor envelope /= loadedCursor dataset
              then pure (Left (appError PreconditionFailed "The pending importance comparison is stale; run next and try again."))
              else dispatchResponse environment dryRun dataset checkpoint response Nothing
      _ -> pure (Left (appError PreconditionFailed "/tie-break is available only while an importance comparison is pending."))

runImpact :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runImpact environment dryRun dataset reference =
  startBrickInteraction environment dryRun dataset reference $ \identity cursor precondition now state brick ->
    let root = compositionRoot state brick
     in makeImpactClassEnvelope identity cursor precondition now state root

runEffort :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runEffort environment dryRun dataset reference =
  startBrickInteraction environment dryRun dataset reference makeEffortClassEnvelope

runPhase :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runPhase environment dryRun dataset reference =
  startBrickInteraction environment dryRun dataset reference makePhaseEnvelope

runPause :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runPause environment dryRun dataset =
  case stateCurrentFocus (loadedState dataset) of
    Nothing ->
      pure . Left $
        (appError PreconditionFailed "There is no current focus to pause.")
          { appErrorRecovery = [RecoveryAction "next" "Ask for the next useful opportunity." (Just "lant next")]
          }
    Just brickId -> do
      facts <- runtimeFacts environment 2 (loadedCursor dataset)
      case decidePauseFocus (loadedState dataset) (appActor environment) brickId facts of
        Left problem -> pure (Left problem)
        Right mutation ->
          persistOrSimulate environment dryRun dataset (mutationDecisionEvents mutation) >>= \case
            Left problem -> pure (Left problem)
            Right accepted ->
              freshCheckpoint environment accepted >>= \case
                Left problem -> pure (Left problem)
                Right checkpoint -> do
                  saveUnlessDry environment dryRun checkpoint
                  pure . Right $
                    RespondResult
                      (loadedCursor accepted)
                      (checkpointCurrent checkpoint)
                      (Just (mutationDecisionCommandId mutation))
                      dryRun

runDone :: AppEnv -> Bool -> LoadedDataset -> Maybe Text -> IO (Either AppError CommandResult)
runDone environment dryRun dataset maybeReference =
  let state = loadedState dataset
      actor = appActor environment
   in case maybeReference of
        Nothing ->
          case stateCurrentFocus state of
            Nothing ->
              pure . Left $
                (appError PreconditionFailed "There is no current focus to complete.")
                  { appErrorRecovery = [RecoveryAction "next" "Get the next focus first." (Just "lant next")]
                  }
            Just identity -> runDoneByIdentity state actor environment dryRun dataset identity
        Just reference ->
          case resolveAnyBrickReference state reference of
            Left problem -> pure (Left problem)
            Right brick -> runDoneByIdentity state actor environment dryRun dataset (brickId brick)
 where
  runDoneByIdentity state actor env dryRun' currentDataset identity =
    runDirectMutation env dryRun' currentDataset (completionUUIDCount state identity) (decideCompleteBrick state actor identity)

runReturnToIdle :: AppEnv -> Bool -> LoadedDataset -> Maybe Text -> IO (Either AppError CommandResult)
runReturnToIdle environment dryRun dataset maybeReference =
  let state = loadedState dataset
      actor = appActor environment
   in case maybeReference of
        Nothing ->
          case stateCurrentFocus state of
            Nothing ->
              pure . Left $
                (appError PreconditionFailed "There is no current focus to return to idle.")
                  { appErrorRecovery = [RecoveryAction "next" "Get the next focus first." (Just "lant next")]
                  }
            Just identity -> runPauseLike state actor environment dryRun dataset identity
        Just reference ->
          case resolveAnyBrickReference state reference of
            Left problem -> pure (Left problem)
            Right brick ->
              if stateCurrentFocus state /= Just (brickId brick)
                then pure (Left (appError PreconditionFailed "Only the current focus can be returned to idle with /return-to-idle."))
                else runPauseLike state actor environment dryRun dataset (brickId brick)
 where
  runPauseLike state actor env dryRun' dataset' identity =
    runDirectMutation env dryRun' dataset' 2 (decidePauseFocus state actor identity)

runImport :: AppEnv -> Bool -> LoadedDataset -> Text -> SourceMode -> Bool -> IO (Either AppError CommandResult)
runImport environment dryRun dataset source mode eraseAfterImport =
  case appPackRegistryProblem environment <|> appImportPortProblem environment of
    Just problem -> pure (Left problem)
    Nothing ->
      importPortPreflight (appImportPort environment) source mode >>= \case
        Left problem -> pure (Left problem)
        Right imported ->
          case validateImportCleanupRequest mode eraseAfterImport preflight of
            Left problem -> pure (Left problem)
            Right () -> do
              identity <- appAllocateUUID environment
              now <- appZonedNow environment
              let state = loadedState dataset
                  cursor = loadedCursor dataset
                  envelope =
                    makeImportPreflightEnvelope
                      identity
                      cursor
                      (statePreconditionHash state)
                      now
                      state
                      (actorProfile (appActor environment))
                      (importReadSourceReference imported)
                      eraseAfterImport
                      preflight
              saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
              pure (Right (NextResult cursor envelope dryRun))
         where
          preflight = importReadPreflight imported

validateImportCleanupRequest :: SourceMode -> Bool -> SourcePreflight -> Either AppError ()
validateImportCleanupRequest mode eraseAfterImport preflight
  | not eraseAfterImport = Right ()
  | mode /= SourceMigrate =
      Left $
        (appError Unsupported "--erase-after-import is valid only with --migrate.")
          { appErrorRecovery = [RecoveryAction "migrate" "Use --migrate or omit source cleanup." Nothing]
          }
  | not (observedCleanupSupported (sourcePreflightObservation preflight)) =
      Left $
        (appError Unsupported "The selected SourceAdapter does not support source cleanup.")
          { appErrorSubject = Just (sourcePreflightAdapterId preflight)
          , appErrorRecovery = [RecoveryAction "ordinary-migration" "Run a verified migration without --erase-after-import." Nothing]
          }
  | otherwise = Right ()

runExport :: AppEnv -> Bool -> LoadedDataset -> Text -> Maybe Text -> Maybe FilePath -> IO (Either AppError CommandResult)
runExport environment dryRun dataset exporter requestedScope outputPath =
  case appPackRegistryProblem environment of
    Just problem -> pure (Left problem)
    Nothing ->
      case resolveExportScope (loadedState dataset) requestedScope of
        Left problem -> pure (Left problem)
        Right scope -> do
          now <- appNow environment
          runExportHost
            (appExportPort environment)
            dryRun
            now
            (loadedCursor dataset)
            (loadedState dataset)
            exporter
            scope
            outputPath
            >>= \case
              Left problem -> pure (Left problem)
              Right result -> do
                let artifact = exportHostArtifact result
                    stdoutBytes =
                      if isNothing (exportHostDestination result) && not dryRun
                        then Just (exportArtifactBytes artifact)
                        else Nothing
                pure . Right $
                  ExportResult
                    (loadedCursor dataset)
                    (exportHostDescriptor result)
                    (exportHostScopeLabel result)
                    (exportArtifactMediaType artifact)
                    (exportArtifactSuggestedFilename artifact)
                    (exportHostDestination result)
                    (ByteString.length (exportArtifactBytes artifact))
                    (exportHostDigest result)
                    (exportArtifactWarnings artifact)
                    (exportArtifactMetadata artifact)
                    stdoutBytes
                    dryRun

resolveExportScope :: State -> Maybe Text -> Either AppError ExportScope
resolveExportScope _ Nothing = Right ExportWholeDataset
resolveExportScope state (Just supplied)
  | Text.null reference = Left (appError InvalidInput "Export scope cannot be empty.")
  | "#" `Text.isPrefixOf` reference = ExportBrickSubtree . brickId <$> resolveAnyBrickReference state reference
  | otherwise =
      case (resolveAnyBrickReference state reference, resolveDomainReference state reference) of
        (Right brick, Left _) -> Right (ExportBrickSubtree (brickId brick))
        (Left _, Right domain) -> Right (ExportDomain (domainId domain))
        (Right brick, Right domain) ->
          Left
            ( (appError AmbiguousReference "The export scope matches both a Brick and a Domain.")
                { appErrorSubject = Just reference
                , appErrorDetails = [renderHandle BrickHandle (brickHandle brick), domainPathText state (domainId domain)]
                , appErrorRecovery = [RecoveryAction "scope" "Use a #Brick handle or a complete Domain path." Nothing]
                }
            )
        (Left brickProblem, Left _) -> Left brickProblem
 where
  reference = Text.strip supplied

runList :: AppEnv -> Bool -> LoadedDataset -> Maybe Text -> IO (Either AppError CommandResult)
runList environment dryRun dataset maybeList =
  let listName = fmap (Text.toLower . Text.strip) maybeList
   in case listName of
        Nothing ->
          pure . Left $
            (appError InvalidInput "Choose a list: importance | forecast")
              { appErrorRecovery =
                  [ RecoveryAction "list" "Show the ordered work list." (Just "lant list importance")
                  , RecoveryAction "forecast" "Show the current forecast list." (Just "lant list forecast")
                  ]
              }
        Just "importance" ->
          pure . Right . ListResult (loadedCursor dataset) "importance" (importanceListRows (loadedState dataset)) $ dryRun
        Just "forecast" -> do
          now <- appZonedNow environment
          let rows = forecastListRows (loadedState dataset) (zonedTimeToUTC now)
          pure . Right . ListResult (loadedCursor dataset) "forecast" rows $ dryRun
        Just unsupported ->
          pure . Left $
            (appError InvalidInput "Unknown list name.")
              { appErrorSubject = Just unsupported
              , appErrorRecovery =
                  [ RecoveryAction "list" "Show the ordered work list." (Just "lant list importance")
                  , RecoveryAction "forecast" "Show the current forecast list." (Just "lant list forecast")
                  ]
              }

importanceListRows :: State -> [ListRow]
importanceListRows state = importanceSubtree state 0 Nothing
 where
  importanceSubtree currentState depth parent =
    concatMap
      ( \current ->
          mkImportanceRow currentState depth current
            : importanceSubtree currentState (depth + 1) (Just (brickId current))
      )
      (orderedSiblings currentState parent)
  mkImportanceRow currentState depth brick =
    ListRow
      (renderHandle BrickHandle (brickHandle brick))
      (Text.replicate (2 * depth) " " <> brickTitle brick)
      ("position " <> showText (brickSiblingPosition brick) <> statusSuffix)
   where
    domains = [domainPathText currentState identity | identity <- Set.toAscList (brickDomains brick)]
    statusSuffix
      | null domains = ""
      | otherwise = " · " <> Text.intercalate ", " domains

forecastListRows :: State -> UTCTime -> [ListRow]
forecastListRows state now =
  [ mkForecastRow state ticket
  | ticket <- World.buildForecastWorld state now
  ]
 where
  mkForecastRow currentState ticket =
    ListRow
      (ticketHandle currentState ticket)
      (ticketTitle currentState ticket)
      (ticketDetails currentState ticket)
  ticketHandle currentState ticket =
    case World.ticketKind ticket of
      World.BrickSubject ->
        maybe
          (showText (World.ticketIdentity ticket))
          (renderHandle BrickHandle . brickHandle)
          (Map.lookup (World.ticketIdentity ticket) (stateBricks currentState))
      World.RawSubject ->
        maybe
          (showText (World.ticketIdentity ticket))
          (renderHandle RawHandle . rawHandle)
          (Map.lookup (World.ticketIdentity ticket) (stateRaws currentState))
  ticketTitle currentState ticket =
    case World.ticketKind ticket of
      World.BrickSubject -> fromMaybe (showText (World.ticketIdentity ticket)) (brickTitle <$> Map.lookup (World.ticketIdentity ticket) (stateBricks currentState))
      World.RawSubject -> fromMaybe "Raw item" (rawOriginal <$> Map.lookup (World.ticketIdentity ticket) (stateRaws currentState))
  ticketDetails currentState ticket =
    Text.intercalate " · " $ case World.ticketKind ticket of
      World.BrickSubject ->
        ("kind: brick")
          : maybe
            []
            (\brick -> ["parent: " <> renderHandle BrickHandle (brickHandle brick)])
            (World.ticketParent ticket >>= \parent -> Map.lookup parent (stateBricks currentState))
            <> ["opportunities: " <> showText (length (World.ticketOpportunities ticket))]
      World.RawSubject ->
        ["kind: raw", "opportunities: " <> showText (length (World.ticketOpportunities ticket))]

runSearch :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runSearch _environment dryRun dataset rawQuery =
  let state = loadedState dataset
      normalized = Text.toCaseFold (Text.unwords (Text.words rawQuery))
      hits = searchEntries state normalized
   in if Text.null normalized
        then pure . Left $ appError InvalidInput "Search query cannot be empty."
        else pure . Right . SearchResult (loadedCursor dataset) rawQuery hits $ dryRun

runHelp :: AppEnv -> Bool -> LoadedDataset -> Maybe Text -> IO (Either AppError CommandResult)
runHelp _environment _dryRun dataset maybeTopic =
  let topic = fmap (Text.toLower . Text.strip) maybeTopic
   in pure . Right $
        ListResult
          (loadedCursor dataset)
          "help"
          (helpEntries topic)
          False

searchEntries :: State -> Text -> [SearchHit]
searchEntries state query
  | Text.null query = []
  | otherwise =
      sortOn searchHitHandle $
        [ mkBrickHit state brick
        | brick <- activeBricks state
        , queryIn query (brickTitle brick)
            || queryIn query (unHandle (brickHandle brick))
        ]
          <> [ mkRawHit raw
             | raw <- Map.elems (stateRaws state)
             , queryIn query (rawOriginal raw)
                 || queryIn query (unHandle (rawHandle raw))
             ]
          <> [ mkDomainHit state domain
             | domain <- Map.elems (stateDomains state)
             , domainActive domain
             , queryIn query (domainName domain)
                 || queryIn query (Text.unwords (Text.splitOn "›" (domainPathText state (domainId domain))))
             ]
          <> [ mkEntityHit entity
             | entity <- Map.elems (stateExternalEntities state)
             , externalEntityActive entity
             , queryIn query (Text.toLower (externalEntityName entity))
             ]
          <> [ mkListEntryHit entry
             | entry <- Map.elems (stateListEntries state)
             , listEntryState entry == EntryOpen
             , queryIn query (listEntryLabel entry)
             ]

queryIn :: Text -> Text -> Bool
queryIn query target =
  Text.toCaseFold (Text.unwords (Text.words query))
    `Text.isInfixOf` Text.toCaseFold (Text.unwords (Text.words target))

mkBrickHit :: State -> Brick -> SearchHit
mkBrickHit state brick =
  SearchHit
    "brick"
    (renderHandle BrickHandle (brickHandle brick))
    (brickTitle brick)
    ("status: " <> showText (brickStatus brick) <> maybe "" (" · " <>) domainsText)
 where
  domainsText =
    case Set.toAscList (brickDomains brick) of
      [] -> Nothing
      values -> Just ("domains: " <> Text.intercalate ", " (fmap (domainPathText state) values))

mkRawHit :: Raw -> SearchHit
mkRawHit raw =
  SearchHit
    "raw"
    (renderHandle RawHandle (rawHandle raw))
    (Text.take 80 (Text.unwords (Text.words (rawOriginal raw))))
    ("status: " <> showText (rawStatus raw))

mkDomainHit :: State -> Domain -> SearchHit
mkDomainHit state domain =
  SearchHit
    "domain"
    (domainPathText state (domainId domain))
    (domainName domain)
    (if domainActive domain then "active" else "archived")

mkEntityHit :: ExternalEntity -> SearchHit
mkEntityHit entity =
  SearchHit
    "entity"
    (renderHandle EntityHandle (externalEntityHandle entity))
    (externalEntityName entity)
    (entityKindLabel (externalEntityKind entity))

mkListEntryHit :: ListEntry -> SearchHit
mkListEntryHit entry =
  SearchHit
    "list_entry"
    ("entry:" <> renderUUIDv7 (listEntryId entry))
    (listEntryLabel entry)
    ("quantity: " <> quantityText (listEntryQuantity entry) <> " · state: " <> listEntryStateLabel (listEntryState entry))

quantityText :: Quantity -> Text
quantityText quantity =
  Text.pack (show (quantityCoefficient quantity))
    <> (if quantityScale quantity == 0 then "" else "e-" <> Text.pack (show (quantityScale quantity)))
    <> (if Text.null (quantityUnit quantity) then "" else " " <> quantityUnit quantity)

listEntryStateLabel :: ListEntryState -> Text
listEntryStateLabel =
  \case
    EntryOpen -> "open"
    EntryResolved -> "resolved"
    EntryCancelled -> "cancelled"

helpEntries :: Maybe Text -> [ListRow]
helpEntries Nothing =
  [ helpEntry "help" "Show help" "Use: lant help <topic>"
  , helpEntry "list" "List structured data" "usage: lant list <importance|forecast>"
  , helpEntry "search" "Search text references" "usage: lant search <query>"
  , helpEntry "next" "Get the next useful action" "default REPL route: lant"
  , helpEntry "focus" "Answer pending focus confirmation" "usage: lant focus <BRICK>"
  , helpEntry "done" "Complete a Brick" "usage: lant done [BRICK]"
  , helpEntry "return-to-idle" "Return current focus to idle" "usage: lant return-to-idle [BRICK]"
  , helpEntry "pause" "Pause current focus" "usage: lant pause"
  , helpEntry "translate" "Review english-normalization opportunities" "usage: lant translate [TARGET]"
  , helpEntry "update" "Patch one Brick metadata or section" "usage: lant update <BRICK> [SECTION]"
  , helpEntry "merge" "Merge two Bricks" "usage: lant merge <SURVIVOR> <ABSORBED>"
  , helpEntry "supersede" "Supersede a Brick with another" "usage: lant supersede <OLD> <NEW>"
  , helpEntry "import" "Import external source data" "usage: lant import <SOURCE> (--snapshot|--synchronize|--migrate) [--erase-after-import]"
  , helpEntry "migrate" "Migrate state between formats" "usage: lant migrate <SOURCE> <TARGET> [--mode inspect|build|cutover]"
  , helpEntry "export" "Export a named versioned projection" "usage: lant export <EXPORTER> [--scope REFERENCE] [--output NEW_FILE]"
  , helpEntry "packs" "Manage packs and extensions" "usage: lant packs <list|show|install|updates|update|remove|refresh|trust|untrust|gc>"
  , helpEntry "doctor" "Run dataset consistency checks" "usage: lant doctor"
  , helpEntry "repair" "Attempt deterministic dataset repair steps" "usage: lant repair"
  , helpEntry "editor" "Open EDITOR workflow for raw material" "usage: lant editor"
  , helpEntry "web" "Start or inspect web view" "usage: lant web"
  ]
helpEntries (Just "list") =
  [ helpEntry "lant list importance" "Current ordered work list" "active Brick tree grouped by insertion position"
  , helpEntry "lant list forecast" "Current forecast list" "upcoming selectable opportunities used by /next"
  ]
helpEntries (Just "search") =
  [ helpEntry "lant search <term>" "Search active bricks, raws, domains, entities, and entries" "Try short terms first"
  ]
helpEntries (Just "commands") =
  [ helpEntry "/done" "Mark one Brick done" "default target: current focus"
  , helpEntry "/focus" "Run an importance comparison on demand" "target a Brick explicitly"
  ]
helpEntries (Just "done") =
  [ helpEntry "done" "Complete one Brick" "usage: lant done [BRICK]"
  , helpEntry "return-to-idle" "Move current focus to idle" "usage: lant return-to-idle [BRICK]"
  ]
helpEntries _ =
  [helpEntry "help" "Unknown help topic" "Try: lant help"]

helpEntry :: Text -> Text -> Text -> ListRow
helpEntry handle title details = ListRow handle title details

showText :: (Show a) => a -> Text
showText = Text.pack . show

entityKindLabel :: ExternalEntityKind -> Text
entityKindLabel = \case
  PersonEntity -> "person"
  TeamEntity -> "team"
  OrganizationEntity -> "organization"
  AIAgentEntity -> "ai_agent"
  ServiceEntity -> "service"
runFinish :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runFinish environment dryRun dataset reference =
  case resolveAnyBrickReference (loadedState dataset) reference of
    Left problem -> pure (Left problem)
    Right brick -> do
      let state = loadedState dataset
          actor = appActor environment
      case Map.lookup (brickId brick) (stateChecklistRuns state) of
        Nothing -> pure (Left (appError PreconditionFailed "That checklist has no active run. Start one first."))
        Just _ -> runDirectMutation environment dryRun dataset (finishChecklistRunUUIDCount state (brickId brick)) (decideFinishChecklistRun state actor (brickId brick))

runBreak :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runBreak environment dryRun dataset reference =
  startBrickInteraction environment dryRun dataset reference $ \identity cursor precondition now state brick ->
    let base = makeFocusProposalEnvelope identity cursor precondition now state brick
     in if supportsChildParts (brickNature brick)
          then makeWorkBreakDraftEnvelope base now state brick Nothing Nothing Nothing []
          else makeWorkBreakNatureEnvelope base now state brick Nothing Nothing

runArchive :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runArchive environment dryRun dataset reference =
  startBrickInteraction environment dryRun dataset reference $ \identity cursor precondition now state brick ->
    makeArchivePreviewEnvelope identity cursor precondition now state brick Nothing Nothing

runRestore :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runRestore environment dryRun dataset reference =
  case resolveAnyBrickReference (loadedState dataset) reference of
    Left problem -> pure (Left problem)
    Right brick
      | brickStatus brick /= BrickArchived ->
          pure (Left (appError PreconditionFailed "Only archived Work can be restored."))
      | otherwise -> do
          identity <- appAllocateUUID environment
          now <- appZonedNow environment
          let state = loadedState dataset
              envelope = makeRestorePreviewEnvelope identity (loadedCursor dataset) (statePreconditionHash state) now state brick
          saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
          pure (Right (NextResult (loadedCursor dataset) envelope dryRun))

runDomainFocus :: AppEnv -> Bool -> LoadedDataset -> Text -> IO (Either AppError CommandResult)
runDomainFocus environment dryRun dataset reference =
  case resolveDomainReference (loadedState dataset) reference of
    Left problem -> pure (Left problem)
    Right domain -> do
      identity <- appAllocateUUID environment
      now <- appZonedNow environment
      let cursor = loadedCursor dataset
          state = loadedState dataset
          envelope = makeDomainFocusEnvelope identity cursor (statePreconditionHash state) now state domain
      saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
      pure (Right (NextResult cursor envelope dryRun))

startBrickInteraction :: AppEnv -> Bool -> LoadedDataset -> Text -> (UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope) -> IO (Either AppError CommandResult)
startBrickInteraction environment dryRun dataset reference builder =
  case resolveBrickReference (loadedState dataset) reference of
    Left problem -> pure (Left problem)
    Right brick -> do
      identity <- appAllocateUUID environment
      now <- appZonedNow environment
      let cursor = loadedCursor dataset
          envelope = builder identity cursor (statePreconditionHash (loadedState dataset)) now (loadedState dataset) brick
      saveUnlessDry environment dryRun (PresentationCheckpoint envelope [] [])
      pure (Right (NextResult cursor envelope dryRun))

runFeed :: AppEnv -> Bool -> LoadedDataset -> Text -> Text -> IO (Either AppError CommandResult)
runFeed environment dryRun dataset origin material = do
  priorCheckpoint <- loadPendingCheckpoint environment
  facts <- runtimeFacts environment 3 (loadedCursor dataset)
  case (priorCheckpoint, decideFeed (loadedState dataset) (appActor environment) origin material facts) of
    (Left problem, _) -> pure (Left problem)
    (_, Left problem) -> pure (Left problem)
    (Right prior, Right decision) -> do
      acceptedResult <- persistOrSimulate environment dryRun dataset (feedDecisionEvents decision)
      case acceptedResult of
        Left problem -> pure (Left problem)
        Right accepted -> do
          checkpointResult <- feedCheckpoint environment dataset accepted (feedDecisionRaw decision) prior
          case checkpointResult of
            Left problem -> pure (Left problem)
            Right checkpoint -> do
              saveUnlessDry environment dryRun checkpoint
              let token = undoToken (feedDecisionCommandId decision) (loadedCursor accepted)
              pure . Right $
                FeedResult
                  (feedDecisionCommandId decision)
                  (loadedCursor accepted)
                  (rawProjection False (feedDecisionRaw decision))
                  CreateUndo
                  token
                  (checkpointCurrent checkpoint)
                  dryRun

feedCheckpoint :: AppEnv -> LoadedDataset -> LoadedDataset -> Raw -> Maybe PresentationCheckpoint -> IO (Either AppError PresentationCheckpoint)
feedCheckpoint environment before accepted raw = \case
  Just checkpoint
    | checkpointIsFresh before checkpoint
    , resumableAfterFeed (checkpointCurrent checkpoint) ->
        pure . Right $ PresentationCheckpoint (withFeedFact accepted raw (checkpointCurrent checkpoint)) [] []
  _ -> freshCheckpoint environment accepted

resumableAfterFeed :: InteractionEnvelope -> Bool
resumableAfterFeed envelope = case envelopeOpportunity envelope of
  FocusProposalOpportunity{} -> True
  CurrentFocusOpportunity{} -> True
  ChecklistRunOpportunity{} -> True
  _ -> False

withFeedFact :: LoadedDataset -> Raw -> InteractionEnvelope -> InteractionEnvelope
withFeedFact accepted raw envelope =
  resealEnvelope $
    envelope
      { envelopeRevision = envelopeRevision envelope + 1
      , envelopeDatasetCursor = loadedCursor accepted
      , envelopePreconditionHash = statePreconditionHash (loadedState accepted)
      , envelopeContent =
          (envelopeContent envelope)
            { contentBody = contentBody (envelopeContent envelope) <> ["", "Fed: " <> renderHandle RawHandle (rawHandle raw) <> " \"" <> Text.take 80 (Text.unwords (Text.words (rawOriginal raw))) <> "\""]
            }
      }

runResponse :: AppEnv -> Bool -> LoadedDataset -> InteractionResponse -> Maybe Text -> IO (Either AppError CommandResult)
runResponse environment dryRun dataset response submitted = do
  loadedCheckpoint <- loadPendingCheckpoint environment
  replacementResult <- freshCheckpoint environment dataset
  case (loadedCheckpoint, replacementResult) of
    (Left problem, _) -> pure (Left problem)
    (_, Left problem) -> pure (Left problem)
    (Right Nothing, Right replacement) -> pure (Left (missingInteraction replacement))
    (Right (Just checkpoint), Right replacement)
      | responseAnsweredCursor response /= envelopeDatasetCursor (checkpointCurrent checkpoint) ->
          pure . Right $ RespondResult (loadedCursor dataset) (checkpointCurrent checkpoint) Nothing dryRun
      | otherwise ->
          if scheduledInterrupts (checkpointCurrent checkpoint) (checkpointCurrent replacement)
            then do
              saveUnlessDry environment dryRun replacement
              pure . Right $ RespondResult (loadedCursor dataset) (checkpointCurrent replacement) Nothing dryRun
            else case validateResponse (checkpointCurrent checkpoint) (checkpointCurrent replacement) response of
              Left problem -> pure (Left problem)
              Right (ResponseStale fresh) -> do
                let freshCheckpointValue = PresentationCheckpoint fresh [] []
                saveUnlessDry environment dryRun freshCheckpointValue
                pure . Right $ RespondResult (loadedCursor dataset) fresh Nothing dryRun
              Right ResponseAccepted{} -> dispatchResponse environment dryRun dataset checkpoint response submitted

dispatchResponse :: AppEnv -> Bool -> LoadedDataset -> PresentationCheckpoint -> InteractionResponse -> Maybe Text -> IO (Either AppError CommandResult)
dispatchResponse environment dryRun dataset checkpoint response submitted = do
  now <- appZonedNow environment
  dispatchResponseAt now environment dryRun dataset checkpoint response submitted

dispatchResponseAt :: ZonedTime -> AppEnv -> Bool -> LoadedDataset -> PresentationCheckpoint -> InteractionResponse -> Maybe Text -> IO (Either AppError CommandResult)
dispatchResponseAt now environment dryRun dataset checkpoint response submitted =
  case (envelopeOpportunity current, responseActionId response, submitted) of
    (_, "next", _) -> replaceWithRecordedForecast
    (ImportPreflightOpportunity source expected eraseAfterImport, "import.accept", _) -> acceptImport source expected eraseAfterImport
    (ImportPreflightOpportunity{}, "import.back", _) -> replaceWithRecordedForecast
    (ImportPreflightOpportunity{}, "import.unknown", _) ->
      local (appendBody current "Import preserves each selected object as Raw material before any Work adoption. Acceptance reruns this read-only preview; source cleanup, when supported, always needs a later separate approval.")
    (ImportResultOpportunity imported reused _, "import.triage", _) ->
      case imported <> reused of
        rawId : _ -> withRaw rawId $ \raw -> local (advanceEnvelope current (makeRawTriageEnvelope (envelopeInteractionId current) cursor precondition now state raw))
        [] -> pure (Left (appError PreconditionFailed "This import result contains no Raw material to triage."))
    (ImportResultOpportunity _ _ True, "import.cleanup", _) ->
      local (appendBody current "Verified source cleanup requires the separate effect approval flow; no source item has changed.")
    (ProviderConnectionOpportunity draft, "provider.connect.accept", _) -> acceptProviderConnection draft
    (ProviderConnectionOpportunity{}, "provider.connect.back", _) -> replaceWithFresh
    (ProviderConnectionOpportunity{}, "provider.connect.unknown", _) ->
      local (appendBody current "The signed Pack fixes the provider endpoints and requested scopes. The public client ID and account label are non-secret profile configuration; device codes stay only in this running host, and tokens go only to the encrypted vault. Connecting imports nothing.")
    (PackInstallOpportunity draft, "pack.install.trust", _) -> beginPackTrust draft
    (PackInstallOpportunity draft, "pack.install.accept", _) -> acceptPackInstall draft
    (PackInstallOpportunity{}, "pack.install.back", _) -> replaceWithFresh
    (PackInstallOpportunity{}, "pack.install.unknown", _) ->
      local (appendBody current "Publisher trust authorizes one exact signing key for this profile. Installation is a separate decision that pins only the displayed signed archive and components. Neither decision grants undeclared authority.")
    (PackTrustOpportunity draft, "pack.trust.accept", _) -> acceptPackTrust draft
    (PackTrustOpportunity draft, "pack.trust.back", _) -> backFromPackTrust draft
    (PackTrustOpportunity{}, "pack.trust.unknown", _) ->
      local (appendBody current "Trust binds the displayed publisher ID to this exact public-key fingerprint in the selected profile. It does not install, update, execute, or grant permissions to any Pack by itself.")
    (RawDetailOpportunity rawId, "raw.detail.origin", _) -> withRaw rawId $ \raw -> local (makeRawOriginListEnvelope current now state raw)
    (RawDetailOpportunity rawId, "raw.detail.translate", _) -> withRaw rawId $ \raw ->
      case resolveTranslationTarget state (rawCitationText raw) of
        Left problem -> pure (Left problem)
        Right candidate -> local (makeTranslationEditorEnvelope current now state (TranslationQueue (TranslationScope False True False) [candidate] 0 0 1) Nothing Nothing)
    (RawDetailOpportunity{}, action, _)
      | action `elem` ["raw.detail.revise", "raw.detail.link", "raw.detail.shelve", "raw.detail.classify", "raw.detail.archive"] ->
          local (appendBody current "This Raw maintenance action is not available in this checkpoint yet. Use [o]rigin or [t]ranslate for actionable review paths.")
    (RawOriginListOpportunity rawId, "raw.origin.back", _) -> withRaw rawId $ \raw -> local (makeRawDetailEnvelope (envelopeInteractionId current) cursor precondition now state raw)
    (RawOriginListOpportunity{}, "raw.origin.add", _) -> local (appendBody current "Choose a source adapter or enter a manual URL through the SourceBinding builder; no origin has been attached yet.")
    (RawOriginListOpportunity{}, "raw.origin.unknown", _) -> local (appendBody current "An origin records where this Raw came from and how it may be checked. It never decides whether attached Work is done.")
    (RawOriginListOpportunity rawId, action, _)
      | Just bindingText <- Text.stripPrefix "raw.origin.select." action ->
          case parseUUIDv7 bindingText of
            Left _ -> pure (Left (appError InvalidInput "The selected SourceBinding identity is invalid."))
            Right bindingId -> withSourceBinding bindingId $ \binding ->
              if sourceBindingRaw binding == rawId
                then local (makeSourceBindingEnvelope current now state binding)
                else pure (Left (appError PreconditionFailed "The selected origin no longer belongs to this Raw."))
    (SourceBindingOpportunity bindingId, "source.binding.move", _) -> withSourceBinding bindingId $ \binding -> local (makeSourceRelocateEnvelope current now state binding (sourceBindingLocator binding))
    (SourceBindingOpportunity bindingId, "source.binding.pause", _) -> withSourceBinding bindingId $ \binding -> local (makeSourceLifecyclePreviewEnvelope current now state binding SourceBindingPaused)
    (SourceBindingOpportunity bindingId, "source.binding.resume", _) -> withSourceBinding bindingId $ \binding -> local (makeSourceLifecyclePreviewEnvelope current now state binding SourceBindingActive)
    (SourceBindingOpportunity bindingId, "source.binding.detach", _) -> withSourceBinding bindingId $ \binding -> local (makeSourceLifecyclePreviewEnvelope current now state binding SourceBindingDetached)
    (SourceBindingOpportunity bindingId, "source.binding.back", _) -> withSourceBinding bindingId $ \binding -> withRaw (sourceBindingRaw binding) $ \raw -> local (makeRawOriginListEnvelope current now state raw)
    (SourceBindingOpportunity{}, "source.binding.check", _) -> local (appendBody current "A check is provider IO owned by the selected SourceAdapter. It must first record one immutable observation; local content cannot change here.")
    (SourceBindingOpportunity{}, "source.binding.unknown", _) -> local (appendBody current "Snapshot preserves once; synchronize keeps observing; migrate may propose verified cleanup later. Pausing and detaching preserve all local material.")
    (SourceChangeOpportunity observationId, "source.change.same", _) -> sourcePreview observationId ReconcileSameRaw
    (SourceChangeOpportunity observationId, "source.change.derived", _) -> sourcePreview observationId ReconcileDerivedRaw
    (SourceChangeOpportunity observationId, "source.change.unrelated", _) -> sourcePreview observationId ReconcileUnrelated
    (SourceChangeOpportunity observationId, "source.change.view", _) -> withSourceObservation observationId $ \observation -> local (appendBody current (sourceDifferenceFor state observation))
    (SourceChangeOpportunity{}, "source.change.unknown", _) -> local (appendBody current "Use the same Raw for corrected or newer representation of one material; derive when the observed artifact is independently useful; unrelated records that this source change should not alter local content.")
    (SourceReconciliationPreviewOpportunity observationId choice, "source.reconcile.accept", _) ->
      case choice of
        ReconcileSameRaw -> mutate 4 (decideAcceptSourceObservationAsRevision state actor observationId) (makeSourceMutationResult "Accepted the observed content as a new revision of the same Raw.")
        ReconcileDerivedRaw -> mutate 7 (decideDeriveSourceObservation state actor observationId) (makeSourceMutationResult "Preserved the observed content as new derived Raw material.")
        ReconcileUnrelated -> mutate 3 (decideIgnoreSourceObservation state actor observationId) (makeSourceMutationResult "Recorded the observed content as unrelated; local Raw content is unchanged.")
    (SourceReconciliationPreviewOpportunity observationId _, action, _)
      | action `elem` ["source.reconcile.edit", "source.reconcile.reject"] -> withSourceObservation observationId $ \observation -> local (makeSourceReconciliationEnvelope current now state observation)
    (SourceReconciliationPreviewOpportunity{}, "source.reconcile.unknown", _) -> local (appendBody current "Yes records the visible branch and advances this origin's accepted observation. Only same-Raw changes current content; derive creates another identity; unrelated creates no content.")
    (SourceFailureOpportunity observationId, "source.failure.pause", _) -> withObservationBinding observationId $ \_ binding -> local (makeSourceLifecyclePreviewEnvelope current now state binding SourceBindingPaused)
    (SourceFailureOpportunity observationId, "source.failure.move", _) -> withObservationBinding observationId $ \_ binding -> local (makeSourceRelocateEnvelope current now state binding (sourceBindingLocator binding))
    (SourceFailureOpportunity observationId, "source.failure.detach", _) -> withObservationBinding observationId $ \_ binding -> local (makeSourceLifecyclePreviewEnvelope current now state binding SourceBindingDetached)
    (SourceFailureOpportunity observationId, "source.failure.later", _) -> withObservationBinding observationId $ \_ binding -> withRaw (sourceBindingRaw binding) $ \raw -> local (makeRawDetailEnvelope (envelopeInteractionId current) cursor precondition now state raw)
    (SourceFailureOpportunity{}, "source.failure.retry", _) -> local (appendBody current "Retry is a provider-owned action. Wait for a new adapter-originated observation to refresh this failure, or move/preview lifecycle actions to change check strategy.")
    (SourceFailureOpportunity{}, "source.failure.unknown", _) -> local (appendBody current "Missing, unreachable, unauthorized, and malformed observations prove nothing about completion, archive, or deletion. Local truth stays unchanged.")
    (SourceRelocateOpportunity bindingId _, "source.relocate.submit", Just locator)
      | not (Text.null (Text.strip locator)) -> withSourceBinding bindingId $ \binding -> local (makeSourceRelocatePreviewEnvelope current now state binding (Text.strip locator))
    (SourceRelocateOpportunity{}, "source.relocate.submit", _) -> pure (Left (appError InvalidInput "An external-origin locator cannot be empty."))
    (SourceRelocatePreviewOpportunity bindingId locator, "source.relocate.accept", _) -> withSourceBinding bindingId $ \binding ->
      mutate 2 (decideChangeSourceBinding state actor bindingId locator (sourceBindingCheckPolicy binding) (sourceBindingLifecycle binding) (sourceBindingAcceptedObservation binding)) (makeSourceMutationResult "Moved the external origin while preserving SourceBinding identity.")
    (SourceRelocatePreviewOpportunity bindingId locator, "source.relocate.edit", _) -> withSourceBinding bindingId $ \binding -> local (makeSourceRelocateEnvelope current now state binding locator)
    (SourceRelocatePreviewOpportunity bindingId _, "source.relocate.reject", _) -> withSourceBinding bindingId $ \binding -> local (makeSourceBindingEnvelope current now state binding)
    (SourceRelocatePreviewOpportunity{}, "source.relocate.unknown", _) -> local (appendBody current "Provider identity verifies a move when available. Otherwise yes is an explicit human claim that the new locator is the same origin.")
    (SourceLifecyclePreviewOpportunity bindingId lifecycle, "source.lifecycle.accept", _) -> withSourceBinding bindingId $ \binding ->
      mutate 2 (decideChangeSourceBinding state actor bindingId (sourceBindingLocator binding) (sourceBindingCheckPolicy binding) lifecycle (sourceBindingAcceptedObservation binding)) (makeSourceMutationResult (sourceLifecycleResult lifecycle))
    (SourceLifecyclePreviewOpportunity bindingId _, "source.lifecycle.reject", _) -> withSourceBinding bindingId $ \binding -> local (makeSourceBindingEnvelope current now state binding)
    (SourceLifecyclePreviewOpportunity{}, "source.lifecycle.unknown", _) -> local (appendBody current "A binding lifecycle controls future checks only. Raw revisions, observations, links, and attached Work remain unchanged.")
    (SourceResultOpportunity rawId _, "source.result.back", _) -> withRaw rawId $ \raw -> local (makeRawDetailEnvelope (envelopeInteractionId current) cursor precondition now state raw)
    (TranslationScopeOpportunity scope, "translate.scope.all", _) -> showTranslationScope (TranslationScope True True (translationScopeArchived scope))
    (TranslationScopeOpportunity scope, "translate.scope.titles", _) -> showTranslationScope (TranslationScope True False (translationScopeArchived scope))
    (TranslationScopeOpportunity scope, "translate.scope.raws", _) -> showTranslationScope (TranslationScope False True (translationScopeArchived scope))
    (TranslationScopeOpportunity scope, "translate.scope.archived", _) -> showTranslationScope scope{translationScopeArchived = not (translationScopeArchived scope)}
    (TranslationScopeOpportunity scope, "translate.scope.continue", _) ->
      let candidates = translationCandidates state scope
          queue = TranslationQueue scope candidates 0 0 (length candidates)
       in local (translationEnvelopeAfter current now state queue)
    (TranslationScopeOpportunity{}, "translate.scope.unknown", _) ->
      local (appendBody current "Titles are renamed in place after preview. Raw text keeps its original revision and receives one attributed English normalization. Unsupported non-text material is never guessed.")
    (TranslationEditOpportunity queue _ _, "translate.edit.submit", Just proposed)
      | not (Text.null (Text.strip proposed)) ->
          local (makeTranslationPreviewEnvelope current now state queue (Text.strip proposed) HumanNormalization Nothing Nothing)
    (TranslationEditOpportunity{}, "translate.edit.submit", _) ->
      pure (Left (appError InvalidInput "An English normalization cannot be empty."))
    (TranslationEditOpportunity queue _ _, "translate.edit.skip", _) ->
      local (translationEnvelopeAfter current now state (advanceTranslationQueue False queue))
    (TranslationEditOpportunity{}, "translate.edit.unknown", _) ->
      local (appendBody current "Write the canonical English wording while preserving meaning. This review changes neither identity nor importance, and skip leaves the candidate unresolved.")
    (TranslationPreviewOpportunity queue proposed source producer confidence, "translate.preview.accept", _) ->
      case translationQueueRemaining queue of
        TranslationBrickTitle brickIdentity : _ ->
          mutate 2 (decideAcceptBrickTitleNormalization state actor brickIdentity proposed source producer confidence) (makeTranslationAccepted queue)
        TranslationRawRevision _ revisionIdentity : _ ->
          mutate 2 (decideAcceptEnglishNormalization state actor revisionIdentity proposed source producer confidence) (makeTranslationAccepted queue)
        [] -> pure (Left (appError CorruptData "The translation preview has no current candidate."))
    (TranslationPreviewOpportunity queue proposed _ _ _, "translate.preview.edit", _) ->
      local (makeTranslationEditorEnvelope current now state queue (Just proposed) (Just "your current draft"))
    (TranslationPreviewOpportunity queue _ _ _ _, "translate.preview.reject", _) ->
      local (makeTranslationEditorEnvelope current now state queue Nothing Nothing)
    (TranslationPreviewOpportunity{}, "translate.preview.unknown", _) ->
      local (appendBody current "Yes accepts exactly the visible wording. A Brick keeps its handle; a Raw keeps its original revision. No changes only this draft and returns to the dumb editor.")
    (WorkSkipReactionOpportunity brickId selection BlockedOrWaitingSymptom, "work.reaction.response", _) ->
      withBrick brickId $ \brick -> local (makeEntitySelectEnvelope current now state brick selection WaitTargetPurpose)
    (WorkSkipReactionOpportunity brickId selection BlockedOrWaitingSymptom, "work.reaction.prerequisite", _) ->
      withBrick brickId $ \brick -> local (makeDependencySelectEnvelope current now state brick selection)
    (WorkSkipReactionOpportunity brickId selection BlockedOrWaitingSymptom, "work.reaction.condition", _) ->
      withBrick brickId $ \brick -> local (makeWaitConditionInputEnvelope current now state brick selection "")
    (WorkSkipReactionOpportunity brickId selection symptom, "work.reaction.support", _)
      | symptom `elem` [HardSymptom, FearSymptom] ->
          withBrick brickId $ \brick -> local (makeEntitySelectEnvelope current now state brick selection DelegationTargetPurpose)
    (EntitySelectOpportunity brickId selection purpose, "entity.new", _) ->
      withBrick brickId $ \brick -> local (makeEntityKindEnvelope current now state brick selection purpose)
    (EntitySelectOpportunity brickId selection purpose, action, _)
      | Just entityText <- Text.stripPrefix "entity.select." action ->
          case parseUUIDv7 entityText of
            Left _ -> pure (Left (appError InvalidInput "The selected person or company identity is invalid."))
            Right entityId -> withActiveEntity entityId $ \entity ->
              withBrick brickId $ \brick -> continueWithEntity brick selection purpose entity
    (EntityKindOpportunity brickId selection purpose, action, _)
      | Just kind <- entityKindForAction action ->
          withBrick brickId $ \brick -> local (makeEntityNameEnvelope current now state brick selection purpose kind "")
    (EntityKindOpportunity{}, "entity.kind.unknown", _) ->
      local (appendBody current "Choose the real-world identity that receives the request or responsibility. The kind is descriptive and grants no capability.")
    (EntityNameOpportunity brickId selection purpose kind _, "entity.name.submit", Just suppliedName)
      | not (Text.null (Text.strip suppliedName)) ->
          mutate 3 (decideRegisterExternalEntity state actor kind (Text.strip suppliedName)) (makeEntityCreated brickId selection purpose)
    (EntityNameOpportunity{}, "entity.name.submit", _) ->
      pure (Left (appError InvalidInput "A person or company name cannot be empty."))
    (WaitRequestStatusOpportunity brickId selection entityId, "wait.request.yes", _) ->
      withBrick brickId $ \brick -> withActiveEntity entityId $ \_ ->
        local (makeWaitActivationDelayEnvelope current now state brick selection (HumanResponseWait entityId))
    (WaitRequestStatusOpportunity{}, "wait.request.no", _) ->
      case envelopeOpportunity current of
        WaitRequestStatusOpportunity brickId selection entityId ->
          withBrick brickId $ \brick -> withActiveEntity entityId $ \entity ->
            local (makeWaitRequestInputEnvelope current now state brick selection entity ("Ask " <> externalEntityName entity <> " about: " <> brickTitle brick))
        _ -> pure (Left unavailable)
    (WaitRequestStatusOpportunity{}, "wait.request.unknown", _) ->
      local (appendBody current "No means your own request is still Work. Yes means the request was already made and the remaining gate is the other person's response.")
    (WaitRequestInputOpportunity brickId selection entityId _, "wait.request.input.submit", Just title)
      | not (Text.null (Text.strip title)) -> feedRequestTitle brickId selection entityId (Text.strip title)
    (WaitRequestInputOpportunity{}, "wait.request.input.submit", _) ->
      pure (Left (appError InvalidInput "An enabling request title cannot be empty."))
    (WaitRequestDelayOpportunity brickId selection entityId rawId, action, _)
      | Just seconds <- waitRequestDelaySeconds action ->
          withBrick brickId $ \brick -> withActiveEntity entityId $ \entity ->
            case Map.lookup rawId (stateRaws state) of
              Just raw | Map.notMember rawId (stateRawDispositions state) -> local (makeWaitRequestPreviewEnvelope current now state brick selection entity raw seconds)
              _ -> pure (Left (appError PreconditionFailed "The preserved request Raw is no longer awaiting this preview."))
    (WaitRequestDelayOpportunity{}, "wait.request.delay.unknown", _) ->
      local (appendBody current "Choose when the response Wait may first return after the enabling request is completed. This does not predict when anyone will answer.")
    (WaitRequestPreviewOpportunity brickId selection entityId rawId seconds, "wait.request.preview.accept", _) ->
      mutate 11 (decideCreateRequestHandoff state actor brickId entityId rawId selection seconds) (makeRequestHandoffRecorded brickId)
    (WaitRequestPreviewOpportunity{}, "wait.request.preview.reject", _) -> replaceWithFresh
    (WaitRequestPreviewOpportunity{}, "wait.request.preview.unknown", _) ->
      local (appendBody current "The new Work is an actionable prerequisite. Its completion resolves that Dependency and activates the declared response Wait in the same command group, so the original Work never becomes transiently eligible.")
    (WaitConditionInputOpportunity brickId selection _, "wait.condition.submit", Just suppliedCondition)
      | not (Text.null (Text.strip suppliedCondition)) ->
          withBrick brickId $ \brick -> local (makeWaitActivationDelayEnvelope current now state brick selection (ExternalConditionWait (Text.strip suppliedCondition)))
    (WaitConditionInputOpportunity{}, "wait.condition.submit", _) ->
      pure (Left (appError InvalidInput "A Wait condition cannot be empty."))
    (DependencySelectOpportunity blockedId selection, action, _)
      | Just blockerText <- Text.stripPrefix "dependency.select." action ->
          case parseUUIDv7 blockerText of
            Left _ -> pure (Left (appError InvalidInput "The selected prerequisite identity is invalid."))
            Right blockerId ->
              withBrick blockedId $ \blocked ->
                case Map.lookup blockerId (stateBricks state) of
                  Just blocker | brickStatus blocker == BrickActive -> local (makeDependencyPreviewEnvelope current now state blocked selection blocker)
                  _ -> pure (Left (appError NotFound "The selected prerequisite Work is no longer active."))
    (DependencySelectOpportunity{}, "dependency.feed", _) ->
      local (appendBody current "Use /feed to preserve the prerequisite, materialize it as Work, then return here. No Dependency or skip evidence was recorded.")
    (DependencySelectOpportunity{}, "dependency.unknown", _) ->
      local (appendBody current "Choose prerequisite Work only when completing it can unblock this Brick. Use a response or condition Wait for truth outside your direct control.")
    (DependencyPreviewOpportunity blockedId _ blockerId, "dependency.accept", _) ->
      mutate 3 (decideAddDependency state actor blockedId blockerId "guided_prerequisite") (makeDependencyRecorded blockedId blockerId)
    (DependencyPreviewOpportunity{}, "dependency.reject", _) -> replaceWithFresh
    (DependencyPreviewOpportunity{}, "dependency.unknown", _) ->
      local (appendBody current "The first Brick becomes unavailable until the second completes. The core rejects self-edges, duplicates, and cycles before recording anything.")
    (WaitActivationDelayOpportunity brickId _ kind, action, _)
      | Just seconds <- waitActivationSeconds action ->
          withBrick brickId $ \_ ->
            mutate 4 (decideActivateWait state actor brickId kind (reviewInstant seconds)) (makeWaitActivated brickId)
    (WaitActivationDelayOpportunity{}, "wait.activate.choose", _) ->
      local (appendBody current "Structured custom date/time selection is available through the shared date-time component; the finite presets remain unchanged.")
    (WaitActivationDelayOpportunity{}, "wait.activate.unknown", _) ->
      local (appendBody current "This instant only says when a review may re-enter the weighted lottery. It is not a deadline, appointment, or promised response time.")
    (DelegationScopeOpportunity draft, "delegation.scope.brick", _) -> continueDelegationScope draft BrickOnlyDelegation
    (DelegationScopeOpportunity draft, "delegation.scope.whole", _) -> continueDelegationScope draft WholeScopeDelegation
    (DelegationScopeOpportunity{}, "delegation.scope.unknown", _) ->
      local (appendBody current "Brick only delegates this durable outcome. Whole scope also covers its current and future parts. Importance order does not change.")
    (DelegationPolicyOpportunity draft, action, _)
      | Just policy <- followUpPolicyForAction action ->
          withBrick (delegationDraftBrick draft) $ \brick -> local (makeDelegationDelayEnvelope current now state brick draft{delegationDraftPolicy = Just policy})
    (DelegationPolicyOpportunity{}, "delegation.policy.unknown", _) ->
      local (appendBody current "The policy controls only outbound follow-up proposals. Internal status reviews continue under every choice, and every message still needs explicit approval.")
    (DelegationDelayOpportunity draft, action, _)
      | Just seconds <- delegationDelaySecondsForAction action ->
          withBrick (delegationDraftBrick draft) $ \brick ->
            case delegationDraftScope draft of
              Nothing -> pure (Left (appError CorruptData "The Delegation draft lost its scope."))
              Just scope ->
                let completed = draft{delegationDraftReviewDelaySeconds = Just seconds, delegationDraftMessage = initialDelegationMessage state brick (delegationDraftTarget draft) scope}
                 in local (makeDelegationPreviewEnvelope current now state brick completed)
    (DelegationDelayOpportunity{}, "delegation.delay.custom", _) ->
      local (appendBody current "Custom review delay accepts one positive integer in hours, days, or weeks; this checkpoint keeps the factory presets until that structured editor is opened.")
    (DelegationDelayOpportunity{}, "delegation.delay.unknown", _) ->
      local (appendBody current "The delay starts from an observed handoff or status update, never from this uncommitted draft.")
    (DelegationPreviewOpportunity draft, "delegation.preview.edit", _) ->
      withBrick (delegationDraftBrick draft) $ \brick -> local (makeDelegationMessageEnvelope current now state brick draft)
    (DelegationMessageOpportunity draft, "delegation.message.submit", Just message)
      | not (Text.null (Text.strip message)) ->
          withBrick (delegationDraftBrick draft) $ \brick -> local (makeDelegationPreviewEnvelope current now state brick draft{delegationDraftMessage = Text.strip message})
    (DelegationMessageOpportunity{}, "delegation.message.submit", _) ->
      pure (Left (appError InvalidInput "A Delegation message cannot be empty."))
    (DelegationPreviewOpportunity draft, "delegation.preview.accept", _) ->
      case (delegationDraftScope draft, delegationDraftPolicy draft, delegationDraftReviewDelaySeconds draft) of
        (Just scope, Just policy, Just delay) ->
          mutate 3 (decideProposeDelegation state actor (delegationDraftBrick draft) (delegationDraftTarget draft) scope policy delay (delegationDraftMessage draft)) (makeDelegationProposed (delegationDraftBrick draft))
        _ -> pure (Left (appError CorruptData "The Delegation preview is incomplete."))
    (DelegationPreviewOpportunity{}, "delegation.preview.reject", _) -> replaceWithFresh
    (DelegationPreviewOpportunity{}, "delegation.preview.unknown", _) ->
      local (appendBody current "Yes creates only a proposed Delegation. Human execution remains eligible until a successful adapter delivery or your explicit handed-it-off observation.")
    (DelegationHandoffOpportunity delegationId, "delegation.handoff.observed", _) ->
      withProposedDelegation delegationId $ \delegation _ ->
        mutate 2 (decideObserveDelegationHandoff state actor delegationId (Just (delegationReviewInstant delegationId))) (makeDelegationUpdated delegationId "Observed handoff recorded; delegated coverage is now excluded from human execution.")
    (DelegationHandoffOpportunity delegationId, "delegation.handoff.cancel", _) ->
      withProposedDelegation delegationId $ \_ _ ->
        mutate 2 (decideCancelProposedDelegation state actor delegationId) (makeDelegationUpdated delegationId "Proposed Delegation cancelled; no handoff was claimed.")
    (DelegationHandoffOpportunity{}, "delegation.handoff.edit", _) ->
      local (appendBody current "Editing an already proposed message is a forward revision and records no handoff. Use Back to return to its accepted preview before delivery.")
    (WaitReviewScreenOpportunity waitIdentity, "wait.response", _) ->
      withWait waitIdentity $ \gate brick ->
        let observation = case waitKind gate of
              HumanResponseWait{} -> WaitResponseReceivedObservation
              ExternalConditionWait{} -> WaitResponseReceivedObservation
         in mutate 3 (decideReviewWait state actor waitIdentity observation WaitResolved Nothing Nothing) (makeWaitUpdated waitIdentity "The Wait was resolved. Human execution may return only if no other gate remains.")
    (WaitReviewScreenOpportunity waitIdentity, "wait.longer", _) ->
      withWait waitIdentity $ \gate brick -> local (makeWaitDelayEnvelope current now state brick gate)
    (WaitReviewScreenOpportunity waitIdentity, "wait.skip", _) ->
      withWait waitIdentity $ \_ _ ->
        mutate 3 (decideReviewWait state actor waitIdentity WaitReviewSkippedObservation WaitActive Nothing Nothing) (makeWaitUpdated waitIdentity "This review was deferred for 24 hours; the Wait itself did not change.")
    (WaitReviewScreenOpportunity{}, "wait.follow-up", _) ->
      local (appendBody current "Follow-up must become explicit enabling Work. Use /feed to preserve the intended action; Little Ant will not claim that a message was sent.")
    (WaitReviewScreenOpportunity{}, "wait.change-blocker", _) ->
      local (appendBody current "Changing the blocker requires a separate typed obstacle preview. The current Wait remains active until that preview is accepted.")
    (WaitReviewScreenOpportunity{}, "wait.unknown", _) ->
      local (appendBody current "Response received resolves only the Wait. Wait longer changes its review threshold. Follow up creates honest Work. Skip changes only the review cooldown.")
    (WaitDelayOpportunity waitIdentity, action, _)
      | Just seconds <- waitDelaySeconds action ->
          withWait waitIdentity $ \_ _ ->
            let reviewAt = reviewInstant seconds
             in mutate 3 (decideReviewWait state actor waitIdentity WaitLongerObservation WaitActive (Just reviewAt) Nothing) (makeWaitUpdated waitIdentity ("Review after " <> Text.pack (show (zonedInstantUtc reviewAt)) <> "."))
    (WaitDelayOpportunity{}, "wait.delay.choose", _) ->
      local (appendBody current "Custom Wait review time uses the structured date/time editor; no free-form instant is recorded from this screen.")
    (WaitDelayOpportunity{}, "wait.delay.unknown", _) ->
      local (appendBody current "Each choice is a minimum review threshold, not an appointment, deadline, or promise that the response will exist then.")
    (DelegationReviewScreenOpportunity delegationIdentity, "delegation.progress", _) ->
      withDelegation delegationIdentity $ \_ _ ->
        mutate 2 (decideReviewDelegation state actor delegationIdentity DelegationActive (Just (delegationReviewInstant delegationIdentity)) (Just "progress") False) (makeDelegationUpdated delegationIdentity "Progress recorded; internal review remains separate from any message.")
    (DelegationReviewScreenOpportunity delegationIdentity, "delegation.complete-report", _) ->
      withDelegation delegationIdentity $ \_ _ ->
        mutate 2 (decideReviewDelegation state actor delegationIdentity DelegationActive (Just (delegationReviewInstant delegationIdentity)) (Just "reported_complete") False) (makeDelegationUpdated delegationIdentity "Reported completion recorded; responsibility remains delegated until Work closure is reconciled.")
    (DelegationReviewScreenOpportunity delegationIdentity, "delegation.refused", _) ->
      withDelegation delegationIdentity $ \_ _ ->
        mutate 2 (decideReviewDelegation state actor delegationIdentity DelegationActive (Just (delegationReviewInstant delegationIdentity)) (Just "refused") False) (makeDelegationUpdated delegationIdentity "Refusal recorded; responsibility remains delegated until reconciliation.")
    (DelegationReviewScreenOpportunity delegationIdentity, "delegation.no-response", _) ->
      withDelegation delegationIdentity $ \delegation _ ->
        if delegationFollowUpAllowed delegation
          then mutate 4 (decideReviewDelegationWithFollowUp state actor delegationIdentity (delegationFollowUpMessage state delegation)) (makeNewEffectApproval delegationIdentity)
          else mutate 2 (decideReviewDelegation state actor delegationIdentity DelegationActive (Just (delegationReviewInstant delegationIdentity)) (Just "no_response") False) (makeDelegationUpdated delegationIdentity "No response recorded. The declared policy permits no new message; another internal review was scheduled.")
    (DelegationReviewScreenOpportunity delegationIdentity, "delegation.take-back", _) ->
      withDelegation delegationIdentity $ \delegation brick -> local (makeDelegationTakeBackPreviewEnvelope current now state brick delegation)
    (DelegationTakeBackPreviewOpportunity delegationIdentity, "delegation.take-back.accept", _) ->
      withDelegation delegationIdentity $ \_ _ ->
        mutate 2 (decideReviewDelegation state actor delegationIdentity DelegationTakenBack Nothing (Just "taken_back") False) (makeDelegationUpdated delegationIdentity "Responsibility taken back; human execution is eligible again.")
    (DelegationTakeBackPreviewOpportunity{}, "delegation.take-back.reject", _) -> replaceWithFresh
    (DelegationTakeBackPreviewOpportunity{}, "delegation.take-back.unknown", _) ->
      local (appendBody current "Taking back ends delegated execution responsibility. It does not complete, archive, or otherwise change the Work.")
    (DelegationReviewScreenOpportunity delegationIdentity, "delegation.skip", _) ->
      withDelegation delegationIdentity $ \_ _ ->
        mutate 2 (decideReviewDelegation state actor delegationIdentity DelegationActive (Just (reviewInstant 86400)) Nothing False) (makeDelegationUpdated delegationIdentity "This internal review was deferred for 24 hours; responsibility did not change.")
    (DelegationReviewScreenOpportunity{}, "delegation.unknown", _) ->
      local (appendBody current "Choose only an observed outcome. A report is not completion, refusal is not take-back, and no response never proves that a follow-up was sent.")
    (ExternalEffectApprovalScreenOpportunity effectIdentity, "effect.approve", _) ->
      withEffect effectIdentity $ \_ _ ->
        mutate 2 (decideApproveExternalEffect state actor effectIdentity) (makeEffectUpdated effectIdentity "The exact revision was approved. It has not been dispatched yet.")
    (ExternalEffectApprovalScreenOpportunity effectIdentity, "effect.edit", _) ->
      withEffect effectIdentity $ \effect brick -> local (makeExternalEffectEditEnvelope current now state brick effect (externalEffectMessage effect))
    (ExternalEffectEditOpportunity effectIdentity _, "effect.edit.submit", Just message)
      | not (Text.null (Text.strip message)) ->
          withEffect effectIdentity $ \_ _ -> mutate 2 (decideReviseExternalEffect state actor effectIdentity (Text.strip message)) (makeEffectApproval effectIdentity)
    (ExternalEffectEditOpportunity{}, "effect.edit.submit", _) ->
      pure (Left (appError InvalidInput "An external-effect message cannot be empty."))
    (ExternalEffectApprovalScreenOpportunity effectIdentity, "effect.reject", _) ->
      withEffect effectIdentity $ \_ _ -> mutate 2 (decideRejectExternalEffect state actor effectIdentity) (makeEffectUpdated effectIdentity "This exact effect was rejected. The Delegation and underlying need remain unchanged.")
    (ExternalEffectApprovalScreenOpportunity effectIdentity, "effect.later", _) ->
      withEffect effectIdentity $ \effect brick -> local (makeExternalEffectDelayEnvelope current now state brick effect)
    (ExternalEffectApprovalScreenOpportunity effectIdentity, "effect.skip", _) ->
      withEffect effectIdentity $ \_ _ -> mutate 2 (decideDeferExternalEffect state actor effectIdentity (reviewInstant 86400)) (makeEffectUpdated effectIdentity "Approval review deferred for 24 hours; nothing was approved or sent.")
    (ExternalEffectDelayOpportunity effectIdentity, action, _)
      | Just seconds <- effectDelaySeconds action ->
          withEffect effectIdentity $ \_ _ -> mutate 2 (decideDeferExternalEffect state actor effectIdentity (reviewInstant seconds)) (makeEffectUpdated effectIdentity "External-effect approval review deferred; nothing was approved or sent.")
    (ExternalEffectDelayOpportunity{}, "effect.delay.unknown", _) ->
      local (appendBody current "This changes only when approval may return to the lottery. Recipient, message, Delegation, and delivery truth remain unchanged.")
    (ExternalEffectApprovalScreenOpportunity{}, "effect.unknown", _) ->
      local (appendBody current "Approval is consent for this exact recipient, purpose, adapter, message, and revision. Nothing may be sent before the approved revision is durably recorded.")
    (ExternalEffectRecoveryScreenOpportunity effectIdentity, "effect.recovery.retry", _) ->
      withEffect effectIdentity $ \_ _ -> mutate 2 (decideRetryExternalEffect state actor effectIdentity False) (makeEffectApproval effectIdentity)
    (ExternalEffectRecoveryScreenOpportunity effectIdentity, "effect.recovery.retry-risk", _) ->
      withEffect effectIdentity $ \effect brick -> local (makeExternalEffectDuplicateRiskEnvelope current now state brick effect)
    (ExternalEffectRecoveryScreenOpportunity{}, "effect.recovery.verify", _) ->
      local (appendBody current "Provider verification is read-only and adapter-specific. Until an observation arrives, this effect remains outcome unknown and no retry is authorized.")
    (ExternalEffectRecoveryScreenOpportunity effectIdentity, "effect.recovery.stop", _) ->
      withEffect effectIdentity $ \_ _ -> mutate 2 (decideRejectExternalEffect state actor effectIdentity) (makeEffectUpdated effectIdentity "Recovery stopped. Provider history remains inspectable and no success was inferred.")
    (ExternalEffectRecoveryScreenOpportunity{}, "effect.recovery.unknown", _) ->
      local (appendBody current "A reported failure is safe to revise and approve again. An unknown outcome may already have happened outside Little Ant, so retry needs separate duplicate-risk consent.")
    (ExternalEffectDuplicateRiskOpportunity effectIdentity, "effect.risk.accept", _) ->
      withEffect effectIdentity $ \_ _ -> mutate 2 (decideRetryExternalEffect state actor effectIdentity True) (makeEffectApproval effectIdentity)
    (ExternalEffectDuplicateRiskOpportunity effectIdentity, "effect.risk.reject", _) ->
      withEffect effectIdentity $ \effect brick -> local (makeExternalEffectRecoveryEnvelope (envelopeInteractionId current) cursor precondition now state brick effect)
    (ExternalEffectDuplicateRiskOpportunity{}, "effect.risk.unknown", _) ->
      local (appendBody current "The durable dispatch intent proves only that an attempt began. Without a trustworthy receipt or read-only provider lookup, local history cannot prove whether the outside action happened.")
    (NoticeListOpportunity notices, action, _)
      | Just indexText <- Text.stripPrefix "notice.select." action ->
          case reads (Text.unpack indexText) of
            [(index, "")] | index >= 0 && index < length notices ->
              withNotice (notices !! index) $ \candidate -> local (makeTemporalNoticeEnvelope current now state candidate)
            _ -> pure (Left (appError InvalidInput "The selected notice is outside this bounded list."))
    (TemporalNoticeOpportunity notice, "notice.open-work", _) ->
      withNotice notice $ \candidate ->
        local (advanceEnvelope current (makeFocusProposalEnvelope (envelopeInteractionId current) cursor precondition now state (candidateNoticeBrick candidate)))
    (TemporalNoticeOpportunity notice, "notice.acknowledge", _) ->
      withNotice notice $ \candidate ->
        mutate 2 (\facts -> decideNoticeDisposition state actor notice (NoticeAcknowledged (runtimeNow facts)) facts) (makeNoticeUpdated candidate "Acknowledged.")
    (TemporalNoticeOpportunity notice, "notice.snooze", _) ->
      withNotice notice $ \candidate -> local (makeNoticeSnoozeEnvelope current now state candidate)
    (TemporalNoticeOpportunity{}, "notice.unknown", _) ->
      local (appendBody current "Open Work changes no state. Acknowledge hides only this exact fact revision. Snooze changes only when this notice may return; importance and Work dates stay untouched.")
    (NoticeSnoozeOpportunity notice, "notice.snooze.hour", _) -> snoozeNotice notice SnoozeOneHour
    (NoticeSnoozeOpportunity notice, "notice.snooze.tomorrow", _) -> snoozeNotice notice SnoozeTomorrow
    (NoticeSnoozeOpportunity notice, "notice.snooze.week", _) -> snoozeNotice notice SnoozeOneWeek
    (NoticeSnoozeOpportunity{}, "notice.snooze.unknown", _) ->
      local (appendBody current "Each choice records one exact notice-only not-before instant. It does not defer the Work or edit best-before or deadline.")
    (RawTriageOpportunity rawId _ _, "raw.materialize-work", _) -> withRaw rawId $ \raw -> local (makeNatureChoiceEnvelope current now state raw (WorkContext rawId Nothing Set.empty))
    (RawTriageOpportunity rawId _ _, "raw.choose-destination", _) -> withRaw rawId $ \raw -> local (makeRawDestinationEnvelope current now state raw 0)
    (RawTriageOpportunity rawId _ _, "raw.defer-triage", _) -> mutate 2 (decideDeferRawTriage state actor rawId) makeFreshResult
    (RawTriageOpportunity rawId _ _, "raw.triage-assistance", _) -> withRaw rawId $ \raw -> local (withExplanation current "Seeing this Raw alone under Work should communicate one useful action: do it, consider it, or read it. Choose yes or no; another uncertainty may leave triage pending." raw state now)
    (RawDuplicateOpportunity candidate root, "raw.duplicate.accept", _) -> mutate 4 (decideRawDuplicateYes state actor candidate root) makeFreshResult
    (RawDuplicateOpportunity candidate root, "raw.duplicate.reject", _) -> mutate 2 (decideRawDuplicateNo state actor candidate root) makeFreshResult
    (RawDuplicateOpportunity candidate _, "raw.duplicate.defer", _) -> mutate 2 (decideDeferRawTriage state actor candidate) makeFreshResult
    (RawDuplicateOpportunity candidate _, "raw.duplicate.inspect", _) -> withRaw candidate $ \raw -> local (withExplanation current "Both complete Raw receipts remain inspectable. Say yes only when this is another receipt of the same material; similarity alone is not identity." raw state now)
    (RawDestinationOpportunity rawId _, "raw.keep-standalone", _) -> mutate 2 (decideKeepRawStandalone state actor rawId) makeStandaloneResult
    (RawDestinationOpportunity rawId _, "raw.destination-assistance", _) -> withRaw rawId $ \raw -> local (withExplanation current "Choose where the material belongs. A checklist keeps entries together; a project or collection may own independently focusable Work; standalone Raw stays useful without another object." raw state now)
    (RawDestinationOpportunity rawId _, "raw.create-group", _) -> withRaw rawId $ \raw -> local (makeRawGroupDiscoveryEnvelope current now state raw)
    (RawDestinationOpportunity rawId _, action, _)
      | Just shelfId <- Text.stripPrefix "raw.destination.shelf." action -> chooseShelfDestination rawId shelfId
    (RawDestinationOpportunity rawId _, action, _)
      | Just targetId <- Text.stripPrefix "raw.destination.brick." action -> chooseDestination rawId targetId
    (RawUnderBrickOpportunity rawId targetId, "raw.child-work", _) -> withRaw rawId $ \raw -> local (makeNatureChoiceEnvelope current now state raw (WorkContext rawId (Just targetId) Set.empty))
    (RawUnderBrickOpportunity rawId targetId, "raw.attach", _) -> withRawAndBrick rawId targetId $ \raw target -> local (makeRawAttachmentEnvelope current now state raw target)
    (RawUnderBrickOpportunity _ _, "raw.under-brick-assistance", _) -> local (appendBody current "Independent Work can be served, ordered, and completed on its own. Supporting material stays Raw beside this Brick.")
    (RawAttachmentOpportunity rawId targetId, "raw.attach.description", _) -> attach rawId targetId DescriptionRole
    (RawAttachmentOpportunity rawId targetId, "raw.attach.attachment", _) -> attach rawId targetId AttachmentRole
    (RawAttachmentOpportunity rawId targetId, "raw.attach.evidence", _) -> attach rawId targetId EvidenceRole
    (RawAttachmentOpportunity _ _, "raw.attachment-assistance", _) -> local (appendBody current "Description is the Brick's single primary text; attachment keeps useful material nearby; evidence explicitly supports a judgment or claim.")
    (RawGroupDiscoveryOpportunity rawId, "raw-group.shelf", _) -> withRaw rawId $ \raw -> local (makeRawShelfNameEnvelope current now state raw "")
    (RawGroupDiscoveryOpportunity _, "raw-group.list", _) -> local (appendBody current "A list is one working unit. Its finite-versus-living lifecycle builder is owned by the complete checklist slice; no object has been created.")
    (RawGroupDiscoveryOpportunity _, "raw-group.work", _) -> local (appendBody current "A Work group uses ordinary Brick Nature and structure discovery; no object has been created.")
    (RawGroupDiscoveryOpportunity _, "raw-group.assistance", _) -> local (appendBody current "A list shows entries together; a shelf organizes preserved Raw; a Work group lets children appear independently in next.")
    (RawShelfNameOpportunity rawId _, "raw-shelf.name.submit", Just name) -> withRaw rawId $ \raw ->
      if Text.null (Text.strip name)
        then pure (Left (appError InvalidInput "A RawShelf name cannot be empty."))
        else local (makeRawShelfCreatePreviewEnvelope current now state raw (Text.strip name))
    (RawShelfCreatePreviewOpportunity rawId name, "raw-shelf.create", _) -> mutate 5 (decideCreateRawShelf state actor rawId name) makeRawShelfResult
    (RawShelfCreatePreviewOpportunity rawId name, "raw-shelf.edit", _) -> withRaw rawId $ \raw -> local (makeRawShelfNameEnvelope current now state raw name)
    (RawShelfCreatePreviewOpportunity rawId _, "raw-shelf.cancel", _) -> withRaw rawId $ \raw -> local (makeRawDestinationEnvelope current now state raw 0)
    (RawShelfCreatePreviewOpportunity _ _, "raw-shelf.assistance", _) -> local (appendBody current "A RawShelf is flat, may share members with other shelves, and never turns Raw material into Work.")
    (RawShelfMembershipPreviewOpportunity rawId shelfId, "raw-shelf.add", _) -> mutate 3 (decidePlaceRawOnShelf state actor rawId shelfId) makeRawShelfResult
    (RawShelfMembershipPreviewOpportunity rawId _, "raw-shelf.cancel", _) -> withRaw rawId $ \raw -> local (makeRawDestinationEnvelope current now state raw 0)
    (RawShelfMembershipPreviewOpportunity _ _, "raw-shelf.assistance", _) -> local (appendBody current "Membership adds this preserved Raw to the shelf's direct display order and settles only its Inbox triage.")
    (NatureChoiceOpportunity context, "nature.discover", _) -> withContextRaw context $ \raw -> local (makeNatureDiscoveryEnvelope current now state raw context initialDiscovery)
    (NatureChoiceOpportunity context, action, _)
      | Just identifier <- Text.stripPrefix "nature.choose." action -> chooseNature context identifier
    (NatureDiscoveryOpportunity context discovery, action, _) -> answerNature context discovery action
    (NatureConfirmationOpportunity context nature _ _, "nature.confirm", _) -> withContextRaw context $ \raw -> local (makeTemplateChoiceEnvelope current now state raw context nature)
    (NatureConfirmationOpportunity context _ _ _, "nature.reject", _) -> withContextRaw context $ \raw -> local (makeNatureChoiceEnvelope current now state raw context)
    (NatureConfirmationOpportunity context _ _ _, "nature.restart", _) -> withContextRaw context $ \raw -> local (makeNatureDiscoveryEnvelope current now state raw context initialDiscovery)
    (TemplateChoiceOpportunity context nature, "template.none", _) -> openTitle context nature Nothing
    (TemplateChoiceOpportunity context _, "template.assistance", _) -> withContextRaw context $ \raw -> local (withExplanation current "A Template is an optional factory setup compatible with the selected Nature. Choosing none keeps only the Nature behavior." raw state now)
    (TemplateChoiceOpportunity context nature, action, _)
      | Just identifier <- Text.stripPrefix "template.choose." action -> chooseTemplate context nature identifier
    (ListEntryPreviewOpportunity rawId ownerId label quantity, "list-entry.create", _) -> mutate 6 (decideMaterializeListEntry state actor rawId ownerId label quantity) makeListEntryResult
    (ListEntryPreviewOpportunity rawId _ _ _, "list-entry.cancel", _) -> withRaw rawId $ \raw -> local (makeRawDestinationEnvelope current now state raw 0)
    (ListEntryPreviewOpportunity{}, "list-entry.assistance", _) -> local (appendBody current "A ListEntry belongs only to this checklist. Its label is not a global object, and the source Raw remains preserved.")
    (ListEntryReuseOpportunity rawId _ entryId _, "list-entry.keep", _) -> mutate 4 (decideReuseListEntry state actor rawId entryId) makeListEntryResult
    (ListEntryReuseOpportunity rawId _ entryId quantity, "list-entry.add-quantity", _) -> mutate 5 (decideAddListEntryQuantity state actor rawId entryId quantity) makeListEntryResult
    (ListEntryReuseOpportunity{}, "list-entry.change", _) -> local (appendBody current "Explicit quantity editing is preserved in this draft; the numeric editor is added with the remaining checklist builder.")
    (ListEntryReuseOpportunity{}, "list-entry.separate", _) -> local (appendBody current "A separate item must first receive a distinguishable label; identical owner-scoped duplicates are never created silently.")
    (ListEntryReuseOpportunity{}, "list-entry.assistance", _) -> local (appendBody current "Keep preserves the current quantity. Add is offered only for matching normalized units. Separate requires a distinguishable label.")
    (WorkTitleOpportunity context nature template _, "work.title.submit", Just title) -> acceptTitle context nature template title
    (DomainSelectionOpportunity draft candidates, action, _) -> withRaw (workDraftRawId draft) $ \raw ->
      case action of
        "domain.continue" -> beginExistingWorkCheck raw draft
        "domain.clear" -> local (makeDomainSelectionEnvelope current now state raw draft{workDraftDomains = Set.empty} candidates)
        "domain.assistance" -> local (appendBody current "Domain membership is direct and optional. A parent may suggest these paths, but it never assigns them silently.")
        _ | Just identityText <- Text.stripPrefix "domain.toggle." action ->
          case parseUUIDv7 identityText of
            Right identity
              | identity `elem` candidates ->
                  let selected = workDraftDomains draft
                      updated = if identity `Set.member` selected then Set.delete identity selected else Set.insert identity selected
                   in local (makeDomainSelectionEnvelope current now state raw draft{workDraftDomains = updated} candidates)
            _ -> pure (Left (appError InvalidInput "The selected Domain is not one of this draft's candidates."))
        _ -> pure (Left unavailable)
    (ExistingWorkSuspicionOpportunity draft existingId, "work-reuse.use", _) -> mutate 4 (decideReuseExistingWork state actor (workDraftRawId draft) existingId) (makeExistingWorkResult existingId)
    (ExistingWorkSuspicionOpportunity draft _, "work-reuse.separate", _) -> withRaw (workDraftRawId draft) $ \raw -> beginImportance raw draft
    (ExistingWorkSuspicionOpportunity draft existingId, "work-reuse.differences", _) ->
      case Map.lookup existingId (stateBricks state) of
        Nothing -> pure (Left (appError NotFound "The suspected existing Work no longer exists."))
        Just existing -> local (appendBody current ("Existing: Nature " <> Text.pack (show (brickNature existing)) <> ", parent " <> maybe "<root>" renderUUIDv7 (brickParent existing) <> ". Proposed: Nature " <> Text.pack (show (workDraftNature draft)) <> ", parent " <> maybe "<root>" renderUUIDv7 (workDraftParent draft) <> "."))
    (ExistingWorkSuspicionOpportunity _ _, "work-reuse.assistance", _) -> local (appendBody current "Use existing only if completing that Brick would also satisfy this fed intention. Similar wording alone is not enough.")
    (ImportanceInsertionOpportunity draft low high skipped comparator, action, _) -> answerImportance draft low high skipped comparator action
    (WorkPreviewOpportunity draft, "work.create", _) -> mutate (6 + length (workDraftComparisons draft)) (decideMaterializeWork state actor draft) makeWorkCreated
    (WorkPreviewOpportunity draft, "work.edit", _) -> withRaw (workDraftRawId draft) $ \raw -> local (makeWorkTitleEnvelope current now state raw (WorkContext (workDraftRawId draft) (workDraftParent draft) (workDraftDomains draft)) (workDraftNature draft) (workDraftTemplate draft) (workDraftTitle draft))
    (WorkPreviewOpportunity draft, "work.cancel", _) -> withRaw (workDraftRawId draft) $ \raw -> local (advanceEnvelope current (makeRawTriageEnvelope (envelopeInteractionId current) cursor precondition now state raw))
    (WorkPreviewOpportunity draft, "work.preview-assistance", _) -> withRaw (workDraftRawId draft) $ \raw -> local (withExplanation current "Yes is the only mutation. It creates the Brick, source link, Raw disposition, sibling position, and accepted comparison evidence as one command group." raw state now)
    (OrderScopeOpportunity, "order.all", _) -> startScope AllSiblingGroups
    (OrderScopeOpportunity, "order.current", _) -> case currentParentFor state of
      Nothing -> pure (Left (appError PreconditionFailed "There is no current sibling group to order."))
      Just parent -> startScope (OneSiblingGroup (Just parent))
    (OrderScopeOpportunity, "order.pick", _) -> local (appendBody current "Use /order followed by a # Brick handle, exact title, or complete Domain path. The REPL autocomplete will resolve the UUID-backed target.")
    (OrderScopeOpportunity, "order.scope-assistance", _) -> local (appendBody current "Every scope orchestrates independent sibling groups. Bricks with different parents are never compared.")
    (ImportanceReviewOpportunity session first second _ _ _, "importance.more", _) -> answerPair session first second [] "direct"
    (ImportanceReviewOpportunity session first second _ _ _, "importance.less", _) -> answerPair session second first [] "direct"
    (ImportanceReviewOpportunity session first second skips skipped provocative, "importance.skip", _) -> skipPair session first second skips skipped provocative
    (ImportanceReviewOpportunity session first second _ skipped provocative, "importance.tie-break", _) ->
      tieBreakPair session first second skipped provocative
    (ImportanceReviewOpportunity session first second _ _ _, "importance.assistance", _) -> local (makeImportanceDiscoveryEnvelope current now state session first second UnderstandFirstResult False)
    (ImportanceContradictionOpportunity session first second path, "contradiction.changed", _) -> answerPair session first second path "changed"
    (ImportanceContradictionOpportunity session first second _, "contradiction.mistake", _) -> answerPair session second first [] "mistake"
    (ImportanceContradictionOpportunity session first second path, "contradiction.aid", _) ->
      local (makeImportanceAidEnvelope current now state session (contradictionTriad state first second path))
    (ImportanceContradictionAidOpportunity session triad, action, _)
      | Just winnerText <- Text.stripPrefix "contradiction.winner." action -> chooseTriadWinner session triad winnerText
    (ImportanceContradictionAidOpportunity session triad, "contradiction.unresolved", _) ->
      local (makeOrderResultEnvelope current now state session False (length triad))
    (ImportanceDiscoveryOpportunity session first second node alternate, action, _) ->
      answerImportanceDiscovery session first second node alternate action
    (ImportanceDirectionConfirmationOpportunity session first second, "importance.direction.accept", _) -> answerPair session first second [] "guided_discovery"
    (ImportanceDirectionConfirmationOpportunity session first second, action, _)
      | action == "importance.direction.reject" || action == "importance.direction.reject.unknown" ->
          local (makeImportanceDiscoveryEnvelope current now state session first second ChooseFirstForever (Text.isSuffixOf ".unknown" action))
    (ImportanceEitherConfirmationOpportunity session first second, "importance.either.accept", _) ->
      mutateJudgment 2 (decidePairJudgment state actor ImportanceAxis first second EitherOrder HumanEitherOrder JudgmentCurrent [] "order" "either_order") (afterImportance session first "Ordering judgment recorded.")
    (ImportanceEitherConfirmationOpportunity session first second, action, _)
      | action == "importance.either.reject" || action == "importance.either.reject.unknown" ->
          local (makeImportanceDiscoveryEnvelope current now state session first second AcceptEitherOrder (Text.isSuffixOf ".unknown" action))
    (ImportanceProvisionalConfirmationOpportunity session first _, "importance.provisional.accept", _) ->
      mutateJudgment 2 (decideImportanceProvisional state actor first "uncertain_after_help") (afterProvisional session first)
    (ImportanceProvisionalConfirmationOpportunity session first second, action, _)
      | action == "importance.provisional.reject" || action == "importance.provisional.reject.unknown" ->
          local (makeImportanceDiscoveryEnvelope current now state session first second TryNearbySibling (Text.isSuffixOf ".unknown" action))
    (OrderResultOpportunity session _ _, "order.resume", _) -> local (startOrderEnvelope now state current session)
    (ImpactClassOpportunity brickId, action, _)
      | Just impact <- impactClassForAction action -> withBrick brickId $ \brick -> local (makeImpactBasisEnvelope current now state brick impact)
    (ImpactClassOpportunity subjectId, "impact.unknown", _) -> withBrick subjectId $ \_ ->
      case impactComparators state subjectId [] of
        comparator : _ -> local (makeImpactComparisonEnvelope current now state subjectId (brickId comparator) 0 [] False)
        [] -> local (appendBody current "No comparable reviewed root is available. Impact stays unclassified; MEDIUM is never inferred.")
    (ImpactBasisOpportunity brickId impact, "impact.speculative", _) ->
      mutateJudgment 2 (decideImpactClass state actor brickId (Just impact) SpeculativeImpact [] DirectHuman) (judgmentReceipt ImpactAxis brickId (impactClassName impact <> " · speculative"))
    (ImpactBasisOpportunity brickId _, "impact.back", _) -> withBrick brickId $ \brick -> local (makeImpactClassEnvelopeFrom current now state brick)
    (ImpactBasisOpportunity brickId impact, "impact.evidence", _) -> withBrick brickId $ \brick ->
      let candidates = impactEvidenceCandidates state brickId
       in if null candidates
            then local (appendBody current "No attached evidence or completed validation Work is available. Feed or attach supporting material first; the impact class is still unrecorded.")
            else local (makeImpactEvidenceEnvelope current now state brick impact candidates)
    (ImpactBasisOpportunity _ _, "impact.basis-unknown", _) -> local (appendBody current "Speculative means no selected support. Supported, validated, and observed require inspectable evidence and a separate maturity review.")
    (ImpactEvidenceOpportunity brickId impact _, "impact.evidence.back", _) -> withBrick brickId $ \brick -> local (makeImpactBasisEnvelope current now state brick impact)
    (ImpactEvidenceOpportunity{}, "impact.evidence.unknown", _) ->
      local (appendBody current "Evidence must be inspectable and relevant to this claimed result. A description alone is not support.")
    (ImpactEvidenceOpportunity brickId impact candidates, action, _)
      | Just evidenceText <- Text.stripPrefix "impact.evidence.select." action ->
          case parseUUIDv7 evidenceText of
            Right evidence | evidence `elem` candidates ->
              withBrick brickId $ \brick -> local (makeImpactMaturityEnvelope current now state brick impact evidence ObservedResultQuestion False)
            _ -> pure (Left (appError InvalidInput "The selected impact evidence is not available in this review."))
    (ImpactMaturityOpportunity brickId impact evidence question _, "impact.maturity.yes", _) ->
      withBrick brickId $ \brick -> local (makeImpactMaturityPreviewEnvelope current now state brick impact evidence (maturityForYes question))
    (ImpactMaturityOpportunity brickId impact evidence question _, action, _)
      | action == "impact.maturity.no" || action == "impact.maturity.unknown" ->
          withBrick brickId $ \brick ->
            case nextMaturityQuestion question of
              Just nextQuestion -> local (makeImpactMaturityEnvelope current now state brick impact evidence nextQuestion (action == "impact.maturity.unknown"))
              Nothing -> local (makeImpactMaturityPreviewEnvelope current now state brick impact evidence SpeculativeImpact)
    (ImpactMaturityPreviewOpportunity brickId impact evidence maturity, "impact.preview.accept", _) ->
      mutateJudgment 2 (decideImpactClass state actor brickId (Just impact) maturity [evidence] DirectHuman) (judgmentReceipt ImpactAxis brickId (impactClassName impact <> " · " <> impactMaturityName maturity))
    (ImpactMaturityPreviewOpportunity brickId impact _ _, "impact.preview.edit", _) -> withBrick brickId $ \brick ->
      local (makeImpactEvidenceEnvelope current now state brick impact (impactEvidenceCandidates state brickId))
    (ImpactMaturityPreviewOpportunity brickId _ _ _, "impact.preview.reject", _) -> withBrick brickId $ \brick -> local (makeImpactClassEnvelopeFrom current now state brick)
    (ImpactMaturityPreviewOpportunity{}, "impact.preview.unknown", _) ->
      local (appendBody current "Acceptance records one attributed class, its evidence maturity, and the exact selected evidence. No field changes before yes.")
    (ImpactComparisonOpportunity first second _ _ _, "impact.more", _) ->
      answerImpactComparison first second first second MoreThan
    (ImpactComparisonOpportunity first second _ _ _, "impact.less", _) ->
      answerImpactComparison first second second first MoreThan
    (ImpactComparisonOpportunity first second _ _ _, "impact.same", _) ->
      answerImpactComparison first second first second AboutSame
    (ImpactComparisonOpportunity first second skips skipped provocative, "impact.skip", _) ->
      case impactComparators state first (second : skipped) of
        comparator : _ | skips == 0 -> local (makeImpactComparisonEnvelope current now state first (brickId comparator) 1 (second : skipped) provocative)
        _ -> withBrick first $ \brick -> local (makeImpactClassEnvelopeFrom current now state brick)
    (ImpactComparisonOpportunity{}, "impact.comparison-unknown", _) ->
      local (appendBody current "Compare expected difference using both likely result and uncertainty of success. About the same is pair-local impact evidence, not equal importance.")
    (EffortClassOpportunity brickId, action, _)
      | Just effort <- effortClassForAction action ->
          mutateJudgment 2 (decideEffortClass state actor brickId (Just effort) DirectHuman) (judgmentReceipt EffortAxis brickId (effortClassName effort <> " (~" <> Text.pack (show (effortPlanningHours effort)) <> " work hours) · reviewed"))
    (EffortClassOpportunity brickId, "effort.unknown", _) -> withBrick brickId $ \brick ->
      case nextEffortExemplar state brickId [minBound .. maxBound] [] of
        Just exemplar -> local (makeEffortExemplarEnvelope current now state brick exemplar 0 [minBound .. maxBound] [])
        Nothing -> local (appendBody current "No suitable reviewed exemplar is available. Total effort stays unclassified; NORMAL is never assumed.")
    (EffortExemplarOpportunity brickId exemplarId index remaining tried, action, _)
      | action == "effort.more" || action == "effort.less" || action == "effort.same" ->
          withTwoBricks brickId exemplarId $ \brick _ ->
            case Map.lookup exemplarId (stateEffortClaims state) of
              Nothing -> pure (Left (appError PreconditionFailed "The reviewed effort exemplar is no longer classified."))
              Just claim ->
                let narrowed = narrowEffortClasses action (effortClaimClass claim) remaining
                    relation = if action == "effort.same" then AboutSame else MoreThan
                    (above, below) = if action == "effort.less" then (exemplarId, brickId) else (brickId, exemplarId)
                 in answerEffortComparison brick exemplarId index remaining tried narrowed above below relation
    (EffortExemplarOpportunity brickId exemplarId index remaining tried, "effort.skip", _) ->
      withBrick brickId $ \brick ->
        case nextEffortExemplar state brickId remaining (tried <> [exemplarId]) of
          Just exemplar | index < 3 -> local (makeEffortExemplarEnvelope current now state brick exemplar index remaining (tried <> [exemplarId]))
          _ -> local (if index == 0 then makeEffortClassEnvelopeFrom current now state brick else makeEffortNarrowedEnvelope current now state brick remaining)
    (EffortExemplarOpportunity{}, "effort.comparison-unknown", _) ->
      local (appendBody current "Compare the complete current finite scopes. Fear, boredom, elapsed time, and remaining effort are different questions.")
    (EffortNarrowedOpportunity brickId _, action, _)
      | Just effort <- effortClassForAction action ->
          mutateJudgment 2 (decideEffortClass state actor brickId (Just effort) DirectHuman) (judgmentReceipt EffortAxis brickId (effortClassName effort <> " · reviewed"))
    (EffortNarrowedOpportunity brickId _, "effort.narrowed-unknown", _) -> withBrick brickId $ \brick ->
      local (appendBody (makeEffortClassEnvelopeFrom current now state brick) "The comparisons remain relative evidence; no class was selected.")
    (EffortProposalOpportunity brickId effort, "effort.proposal.accept", _) ->
      mutateJudgment 2 (decideEffortClass state actor brickId (Just effort) DirectHuman) (judgmentReceipt EffortAxis brickId (effortClassName effort <> " · reviewed"))
    (EffortProposalOpportunity brickId _, "effort.proposal.reject", _) -> withBrick brickId $ \brick -> local (makeEffortClassEnvelopeFrom current now state brick)
    (EffortProposalOpportunity _ _, "effort.proposal-unknown", _) ->
      local (appendBody current "The proposed class is the only class left by the accepted comparisons. It is recorded only if you confirm it.")
    (ImpactContradictionOpportunity subject _ above below relation path, "judgment.changed", _) ->
      mutateJudgment
        2
        (decidePairJudgment state actor ImpactAxis above below relation DirectHuman JudgmentCurrent path "impact_comparison" "changed")
        (judgmentReceipt ImpactAxis subject "Impact comparison recorded.")
    (ImpactContradictionOpportunity subject comparator _ _ _ _, "judgment.revise", _) ->
      local (makeImpactComparisonEnvelope current now state subject comparator 0 [] False)
    (ImpactContradictionOpportunity subject comparator _ _ _ path, "judgment.aid", _) ->
      local (makeJudgmentContradictionAidEnvelope current now state ImpactAxis subject (axisContradictionTriad state subject comparator path) path)
    (EffortContradictionOpportunity brickId exemplarId index remaining tried above below relation path, "judgment.changed", _) ->
      withTwoBricks brickId exemplarId $ \brick _ ->
        case Map.lookup exemplarId (stateEffortClaims state) of
          Nothing -> pure (Left (appError PreconditionFailed "The reviewed effort exemplar is no longer classified."))
          Just claim ->
            let action = effortDirectionAction relation above brickId
                narrowed = narrowEffortClasses action (effortClaimClass claim) remaining
             in mutateJudgment
                  2
                  (decidePairJudgment state actor EffortAxis above below relation DirectHuman JudgmentCurrent path "effort_exemplar" "changed")
                  (afterEffortComparison brick narrowed (index + 1) (tried <> [exemplarId]))
    (EffortContradictionOpportunity brickId exemplarId index remaining tried _ _ _ _, "judgment.revise", _) ->
      withTwoBricks brickId exemplarId $ \brick exemplar ->
        local (makeEffortExemplarEnvelope current now state brick exemplar index remaining tried)
    (EffortContradictionOpportunity brickId exemplarId _ _ _ _ _ _ path, "judgment.aid", _) ->
      local (makeJudgmentContradictionAidEnvelope current now state EffortAxis brickId (axisContradictionTriad state brickId exemplarId path) path)
    (JudgmentContradictionAidOpportunity axis subject triad retired, action, _)
      | Just winnerText <- Text.stripPrefix "judgment.aid.winner." action ->
          resolveAxisAid axis subject triad retired winnerText False
    (JudgmentContradictionAidOpportunity axis subject triad retired, "judgment.aid.same", _) ->
      resolveAxisAid axis subject triad retired (maybe "" renderUUIDv7 (safeFirst triad)) True
    (JudgmentContradictionAidOpportunity axis subject triad _, "judgment.aid.unresolved", _) ->
      local (makeJudgmentResultEnvelope current now state axis subject ("Still uncertain · " <> Text.pack (show (length triad)) <> " placements need review."))
    (PhaseOpportunity brickId, action, _)
      | Just phase <- phaseForAction action ->
          mutateJudgment 2 (decidePhase state actor brickId (Just phase) DirectHuman) (judgmentReceipt ImportanceAxis brickId (phaseName phase <> " phase recorded."))
    (PhaseOpportunity brickId, "phase.clear", _) ->
      mutateJudgment 2 (decidePhase state actor brickId Nothing DirectHuman) (judgmentReceipt ImportanceAxis brickId "Phase cleared.")
    (PhaseOpportunity brickId, "phase.leave", _) -> withBrick brickId $ \_ -> local (makeJudgmentResultEnvelope current now state ImportanceAxis brickId "Phase left unspecified.")
    (PhaseOpportunity _, "phase.unknown", _) -> local (appendBody current "Phase is optional and descriptive. It never changes importance order or forecast eligibility by itself.")
    (FocusProposalOpportunity brickId selection, "focus.accept", _) ->
      withBrick brickId $ \brick ->
        if brickNature brick `elem` [LivingChecklist, FiniteChecklist]
          then mutate 4 (decideStartChecklistRun state actor brickId selection) makeChecklistStarted
          else case selection of
            Just selectionId -> mutate 2 (decideRecordedFocus state actor brickId selectionId) makeFocused
            Nothing -> mutate 2 (decideFocusBrick state actor brickId) makeFocused
    (FocusProposalOpportunity brickId selection, "focus.skip", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipSymptomEnvelope current now state brick selection)
    (FocusProposalOpportunity _ _, "focus.assistance", _) -> local (appendBody current "Choose yes when this is an honest useful focus now. Skip opens the recovery route without saying the Work is unimportant.")
    (CurrentFocusOpportunity brickId, "focus.done", _) -> mutate (completionUUIDCount state brickId) (decideCompleteBrick state actor brickId) makeCompleted
    (CurrentFocusOpportunity brickId, "focus.blocked", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipReactionEnvelope current now state brick Nothing BlockedOrWaitingSymptom)
    (CurrentFocusOpportunity brickId, "focus.skip", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipSymptomEnvelope current now state brick Nothing)
    (ScheduledOverlapOpportunity ownerIds, action, _)
      | Just selectedText <- Text.stripPrefix "commitment.overlap.select." action ->
          case parseUUIDv7 selectedText of
            Right selected
              | selected `elem` ownerIds -> withScheduled selected $ \brick interval -> local (makeScheduledCommitmentEnvelope (envelopeInteractionId current) cursor precondition now state brick interval)
            _ -> pure (Left (appError InvalidInput "The selected scheduled commitment is not active in this overlap."))
    (ScheduledOverlapOpportunity{}, "commitment.overlap.unknown", _) ->
      local (appendBody current "Overlapping commitments have equal hard precedence. Choose one to report truthfully; Little Ant never invents an outcome or a default winner.")
    (ScheduledCommitmentOpportunity ownerId, "commitment.attend", _) ->
      withScheduled ownerId $ \_ interval ->
        if zonedTimeToUTC now < zonedInstantUtc (scheduledEndsAt interval)
          then mutate 2 (decideFocusBrick state actor ownerId) (makeScheduled ownerId)
          else pure (Left (appError PreconditionFailed "This commitment interval has ended; record attended, missed, or cancelled truthfully."))
    (ScheduledCommitmentOpportunity ownerId, "commitment.attended", _) ->
      withScheduled ownerId $ \_ _ -> mutate 2 (decideScheduledOutcome state actor ownerId StandingAttended) (makeScheduledOutcome ownerId StandingAttended)
    (ScheduledCommitmentOpportunity ownerId, "commitment.missed", _) ->
      withScheduled ownerId $ \_ _ -> mutate 2 (decideScheduledOutcome state actor ownerId StandingMissed) (makeScheduledOutcome ownerId StandingMissed)
    (ScheduledCommitmentOpportunity ownerId, "commitment.cancelled", _) ->
      withScheduled ownerId $ \_ _ -> mutate 2 (decideScheduledOutcome state actor ownerId StandingCancelled) (makeScheduledOutcome ownerId StandingCancelled)
    (ScheduledCommitmentOpportunity{}, "commitment.unknown", _) ->
      local (appendBody current "The exact interval gives this commitment hard precedence, but elapsed time never proves attendance, a miss, or cancellation. Record only what actually happened.")
    (ChecklistRunOpportunity ownerId _, action, _)
      | Just entryText <- Text.stripPrefix "checklist.select." action ->
          case parseUUIDv7 entryText of
            Left _ -> pure (Left (appError InvalidInput "The selected checklist row has an invalid identity."))
            Right entryId -> withBrick ownerId $ \owner -> local (makeChecklistRunEnvelope (envelopeInteractionId current) cursor precondition now state owner (Just entryId))
    (ChecklistRunOpportunity ownerId (Just entryId), "checklist.entry.done", _) ->
      mutate 2 (decideChangeListEntryState state actor entryId EntryResolved) (makeChecklist ownerId (Just entryId))
    (ChecklistRunOpportunity ownerId (Just entryId), "checklist.entry.cancel", _) ->
      mutate 2 (decideChangeListEntryState state actor entryId EntryCancelled) (makeChecklist ownerId (Just entryId))
    (ChecklistRunOpportunity ownerId (Just entryId), "checklist.entry.reopen", _) ->
      mutate 2 (decideChangeListEntryState state actor entryId EntryOpen) (makeChecklist ownerId (Just entryId))
    (ChecklistRunOpportunity ownerId _, "checklist.finish", _) ->
      mutate (finishChecklistRunUUIDCount state ownerId) (decideFinishChecklistRun state actor ownerId) (makeChecklistFinished ownerId)
    (ChecklistRunOpportunity ownerId _, "checklist.skip", _) ->
      withBrick ownerId $ \owner -> local (makeWorkSkipSymptomEnvelope current now state owner Nothing)
    (RepeatableReturnOpportunity ownerId reviewId, "return.keep", _) ->
      withRepeatableReview ownerId reviewId $ \owner review ->
        case returnSchedulePolicy <$> Map.lookup ownerId (stateReturnSchedules state) of
          Nothing -> pure (Left (appError PreconditionFailed "This repeatable Brick has no existing return policy to keep."))
          Just policy -> prepareReturnPreview owner review policy Nothing
    (RepeatableReturnOpportunity ownerId reviewId, action, _)
      | action == "return.set" || action == "return.change" ->
          withRepeatableReview ownerId reviewId $ \owner review ->
            let draft = case Map.lookup ownerId (stateReturnSchedules state) of
                  Just ReturnSchedule{returnSchedulePolicy = AfterCompletionReturn center _ _ _} -> Text.pack (show center)
                  _ -> "6"
             in local (makeRepeatableReturnCenterEnvelope current now state owner review draft)
    (RepeatableReturnOpportunity ownerId reviewId, "return.manual", _) ->
      withRepeatableReview ownerId reviewId $ \_ _ ->
        case prepareRepeatableReturn state ownerId ManualOnlyReturn impossibleResolver emptyReturnFacts of
          Left problem -> pure (Left problem)
          Right proposal -> mutate 3 (decideSetRepeatableReturn state actor reviewId proposal) makeReturnRecorded
    (RepeatableReturnOpportunity ownerId reviewId, "return.archive", _) ->
      withRepeatableReview ownerId reviewId $ \owner _ -> local (makeArchivePreviewEnvelope (envelopeInteractionId current) cursor precondition now state owner Nothing Nothing)
    (RepeatableReturnOpportunity{}, "return.unknown", _) ->
      local (appendBody current "A return keeps the same standing Brick behind one deterministic future not-before. Manual only removes it from ordinary draws; archive is an explicit lifecycle change.")
    (RepeatableReturnCenterOpportunity ownerId reviewId _, "return.center.submit", Just input) ->
      withRepeatableReview ownerId reviewId $ \owner review ->
        case parseWholeNumber True input of
          Left problem -> pure (Left problem)
          Right center -> local (makeRepeatableReturnUnitEnvelope current now state owner review center)
    (RepeatableReturnUnitOpportunity ownerId reviewId center, action, _)
      | Just unit <- returnUnitForAction action ->
          withRepeatableReview ownerId reviewId $ \owner review ->
            let variation = case Map.lookup ownerId (stateReturnSchedules state) of
                  Just ReturnSchedule{returnSchedulePolicy = AfterCompletionReturn _ existingUnit existingVariation _}
                    | existingUnit == unit -> Text.pack (show existingVariation)
                  _ -> "0"
             in local (makeRepeatableReturnVariationEnvelope current now state owner review center unit variation)
    (RepeatableReturnVariationOpportunity ownerId reviewId center unit _, "return.variation.submit", Just input) ->
      withRepeatableReview ownerId reviewId $ \owner review ->
        case parseWholeNumber False input of
          Left problem -> pure (Left problem)
          Right variation
            | variation > center -> pure (Left (appError InvalidInput "Variation cannot exceed the return center."))
            | otherwise ->
                let zone = case Map.lookup ownerId (stateReturnSchedules state) of
                      Just ReturnSchedule{returnSchedulePolicy = AfterCompletionReturn _ _ _ existingZone} -> existingZone
                      _ -> "America/Montevideo"
                 in local (makeRepeatableReturnZoneEnvelope current now state owner review center unit variation zone)
    (RepeatableReturnZoneOpportunity ownerId reviewId center unit variation _, "return.zone.submit", Just input) ->
      withRepeatableReview ownerId reviewId $ \owner review ->
        let zone = Text.strip input
         in if Text.null zone
              then pure (Left (appError InvalidInput "A return needs one named IANA zone."))
              else prepareReturnPreview owner review (AfterCompletionReturn center unit variation zone) Nothing
    (RepeatableReturnPreviewOpportunity ownerId reviewId policy chosen notBefore resolution seed, "return.accept", _) ->
      withRepeatableReview ownerId reviewId $ \_ _ ->
        prepareReturnProposal ownerId policy (Just seed) >>= \case
          Left problem -> pure (Left problem)
          Right proposal
            | repeatableReturnChosenOffset proposal /= Just chosen
                || repeatableReturnNotBefore proposal /= Just notBefore
                || repeatableReturnResolution proposal /= Just resolution ->
                pure (Left (appError CorruptData "The sealed return preview no longer reproduces its deterministic result."))
            | otherwise -> mutate 3 (decideSetRepeatableReturn state actor reviewId proposal) makeReturnRecorded
    (RepeatableReturnPreviewOpportunity ownerId reviewId _ _ _ _ _, "return.edit", _) ->
      withRepeatableReview ownerId reviewId $ \owner review -> local (makeRepeatableReturnCenterEnvelope current now state owner review "6")
    (RepeatableReturnPreviewOpportunity ownerId reviewId _ _ _ _ _, "return.reject", _) ->
      withRepeatableReview ownerId reviewId $ \owner review -> local (makeRepeatableReturnEnvelope (envelopeInteractionId current) cursor precondition now state owner review)
    (RepeatableReturnPreviewOpportunity{}, "return.unknown", _) ->
      local (appendBody current "The offset was sampled once from the displayed inclusive range. The absolute instant and DST resolution are recorded only after yes; importance never changes.")
    (WorkSkipSymptomOpportunity brickId selection, "work.symptom.done", _) ->
      mutate (completionUUIDCount state brickId) (decideCompleteBrick state actor brickId) makeCompleted
    (WorkSkipSymptomOpportunity brickId selection, "work.symptom.unknown", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipDiscoveryEnvelope current now state brick selection OutsidePrerequisiteNode False)
    (WorkSkipSymptomOpportunity brickId selection, "work.symptom.other", _) ->
      withBrick brickId $ \brick -> local (makeWorkOtherExplanationEnvelope current now state brick selection "")
    (WorkSkipSymptomOpportunity brickId selection, action, _)
      | Just symptom <- symptomForAction action ->
          withBrick brickId $ \brick -> local (makeWorkSkipReactionEnvelope current now state brick selection symptom)
    (WorkSkipDiscoveryOpportunity brickId selection node alternate, action, _)
      | action == "work.discovery.yes" || action == "work.discovery.no" ->
          withBrick brickId $ \brick ->
            let yes = action == "work.discovery.yes"
             in case skipDiscoveryStep node yes of
                  Left symptom -> local (makeWorkSkipConfirmationEnvelope current now state brick selection symptom)
                  Right nextNode -> local (makeWorkSkipDiscoveryEnvelope current now state brick selection nextNode False)
    (WorkSkipDiscoveryOpportunity brickId selection node False, "work.discovery.unknown", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipDiscoveryEnvelope current now state brick selection node True)
    (WorkSkipDiscoveryOpportunity{}, "work.discovery.unknown", _) ->
      local (appendBody current "This distinction remains unanswered. Choose yes or no, or navigate back without recording anything.")
    (WorkSkipConfirmationOpportunity brickId selection symptom, "work.discovery.confirm", _) ->
      withBrick brickId $ \brick ->
        if isOtherSymptom symptom
          then local (makeWorkOtherExplanationEnvelope current now state brick selection "")
          else local (makeWorkSkipReactionEnvelope current now state brick selection symptom)
    (WorkSkipConfirmationOpportunity brickId selection _, "work.discovery.reject", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipSymptomEnvelope current now state brick selection)
    (WorkSkipConfirmationOpportunity brickId selection _, "work.discovery.restart", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipDiscoveryEnvelope current now state brick selection OutsidePrerequisiteNode False)
    (WorkOtherExplanationOpportunity brickId selection _, "work.other.submit", Just explanation)
      | not (Text.null (Text.strip explanation)) ->
          withBrick brickId $ \brick -> local (makeWorkOtherPreviewEnvelope current now state brick selection (Text.strip explanation))
    (WorkOtherExplanationOpportunity{}, "work.other.submit", _) ->
      pure (Left (appError InvalidInput "An other-symptom explanation cannot be empty."))
    (WorkOtherPreviewOpportunity brickId selection explanation, "work.other.accept", _) ->
      mutateWorkReaction brickId selection (OtherSymptom explanation) SkipAnywayReaction
    (WorkOtherPreviewOpportunity brickId selection explanation, "work.other.edit", _) ->
      withBrick brickId $ \brick -> local (makeWorkOtherExplanationEnvelope current now state brick selection explanation)
    (WorkOtherPreviewOpportunity brickId selection _, "work.other.reject", _) ->
      withBrick brickId $ \brick -> local (makeWorkSkipSymptomEnvelope current now state brick selection)
    (WorkOtherPreviewOpportunity{}, "work.other.unknown", _) ->
      local (appendBody current "The exact explanation becomes event evidence only. It does not create Raw material or silently invent another symptom.")
    (WorkSkipReactionOpportunity brickId selection symptom, "work.reaction.skip", _) ->
      mutateWorkReaction brickId selection symptom SkipAnywayReaction
    (WorkSkipReactionOpportunity brickId selection TiredSymptom, "work.reaction.pause", _) ->
      mutateWorkReaction brickId selection TiredSymptom PauseForNowReaction
    (WorkSkipReactionOpportunity brickId selection BoredSymptom, "work.reaction.interesting", _) ->
      withBrick brickId $ \brick -> local (makeWorkInterestingEnvelope current now state brick selection)
    (WorkInterestingOpportunity brickId selection, "work.interesting.sprint", _) ->
      withBrick brickId $ \brick -> local (makeWorkSprintDurationEnvelope current now state brick selection)
    (WorkSkipReactionOpportunity brickId selection OutOfDateSymptom, "work.reaction.archive", _) ->
      withBrick brickId $ \brick ->
        local
          ( advanceEnvelope current $
              makeArchivePreviewEnvelope
                (envelopeInteractionId current)
                cursor
                precondition
                now
                state
                brick
                selection
                (Just OutOfDateSymptom)
          )
    (WorkInterestingOpportunity brickId selection, "work.interesting.break", _) ->
      withBrick brickId $ \brick -> openBreak brick selection (Just BoredSymptom)
    (WorkSkipReactionOpportunity brickId selection symptom, "work.reaction.break", _) ->
      withBrick brickId $ \brick -> openBreak brick selection (Just symptom)
    (WorkBreakNatureOpportunity brickId selection symptom, "work.break.nature.project", _) ->
      withBrick brickId $ \brick -> local (makeWorkBreakDraftEnvelope current now state brick selection symptom (Just Project) [])
    (WorkBreakNatureOpportunity brickId selection symptom, "work.break.nature.collection", _) ->
      withBrick brickId $ \brick -> local (makeWorkBreakDraftEnvelope current now state brick selection symptom (Just Collection) [])
    (WorkBreakNatureOpportunity{}, "work.break.nature.unknown", _) ->
      local (appendBody current "A Project has one finite outcome and returns for scope review after its active children finish. A Collection stays open for independently useful parts.")
    (WorkBreakDraftOpportunity brickId selection symptom target titles, "work.break.submit", Just submittedText) ->
      withBrick brickId $ \brick ->
        let title = Text.strip submittedText
            minimumParts = if supportsChildParts (brickNature brick) then 1 else 2
         in if Text.null title
              then
                if length titles >= minimumParts
                  then local (makeWorkBreakPreviewEnvelope current now state brick selection symptom target titles)
                  else pure (Left (appError InvalidInput ("Enter at least " <> Text.pack (show minimumParts) <> " part titles before review.")))
              else local (makeWorkBreakDraftEnvelope current now state brick selection symptom target (titles <> [title]))
    (WorkBreakDraftOpportunity{}, "work.break.submit", _) ->
      pure (Left (appError InvalidInput "The part draft submission is missing."))
    (WorkBreakPreviewOpportunity brickId selection symptom target titles, "work.break.accept", _) ->
      let count = 1 + maybe 0 (const 1) symptom + maybe 0 (const 1) target + 3 * length titles
       in mutate count (decideBreakBrick state actor (BreakDraft brickId target titles selection symptom)) (makeBreakResult brickId)
    (WorkBreakPreviewOpportunity brickId selection symptom target titles, "work.break.edit", _) ->
      withBrick brickId $ \brick -> local (makeWorkBreakDraftEnvelope current now state brick selection symptom target titles)
    (WorkBreakPreviewOpportunity{}, "work.break.cancel", _) -> replaceWithFresh
    (WorkBreakPreviewOpportunity{}, "work.break.unknown", _) ->
      local (appendBody current "The parent keeps its UUID and # handle. New child Bricks are created atomically; entered order only seeds local importance, and each default Nature remains reviewable later.")
    (ArchivePreviewOpportunity brickId selection symptom, "archive.accept", _) ->
      mutate
        (archiveUUIDCount (fmap (\value -> (selection, value)) symptom))
        (decideArchiveBrick state actor brickId (fmap (\value -> (selection, value)) symptom))
        (makeArchived brickId)
    (ArchivePreviewOpportunity{}, "archive.reject", _) -> replaceWithFresh
    (ArchivePreviewOpportunity{}, "archive.unknown", _) ->
      local (appendBody current "Archive stops active pursuit without claiming completion. Restore is a later forward action; semantic undo of the archive remains separate.")
    (RestorePreviewOpportunity brickId, "restore.accept", _) ->
      mutate (restoreUUIDCount state brickId) (decideRestoreBrick state actor brickId) (makeRestored brickId)
    (RestorePreviewOpportunity{}, "restore.reject", _) -> replaceWithFresh
    (RestorePreviewOpportunity{}, "restore.unknown", _) ->
      local (appendBody current "Restoration keeps the same identity and history, returns the Brick as idle Work, and queues only its local importance placement for review.")
    (ArchiveReviewOpportunity brickId reviewId, "archive-review.keep", _) ->
      mutate 2 (decideKeepArchived state actor reviewId) (makeArchiveReviewResult brickId "Kept archived.")
    (ArchiveReviewOpportunity brickId _, "archive-review.restore", _) ->
      case Map.lookup brickId (stateBricks state) of
        Just brick -> local (advanceEnvelope current (makeRestorePreviewEnvelope (envelopeInteractionId current) cursor precondition now state brick))
        Nothing -> pure (Left (appError CorruptData "The archive review subject is missing."))
    (ArchiveReviewOpportunity{}, "archive-review.skip", _) ->
      local (appendBody current "The Brick remains archived and this bounded relevance review remains pending.")
    (ArchiveReviewOpportunity{}, "archive-review.unknown", _) ->
      local (appendBody current "Keep archived when the Work still should not compete for focus. Restore only when it is again actionable; update or supersede when its meaning changed.")
    (ArchiveReviewOpportunity{}, "archive-review.update", _) ->
      local (appendBody current "Semantic update is not implemented in this slice yet; the archive review remains pending.")
    (ArchiveReviewOpportunity{}, "archive-review.supersede", _) ->
      local (appendBody current "Supersession is not implemented in this slice yet; the archive review remains pending.")
    (DomainFocusOpportunity domainId, action, _)
      | Just mode <- domainFocusModeForAction action ->
          mutate 2 (decideDomainFocus state actor (Just domainId) (Just mode)) (makeDomainFocusResult domainId mode)
    (DomainFocusOpportunity{}, "domain-focus.unknown", _) ->
      local (appendBody current "One suggestion constrains only the next draw. Stay within keeps a visible hard scope. Prefer changes soft continuity while unrelated Work keeps a positive chance.")
    (WorkInterestingOpportunity{}, "work.interesting.unknown", _) ->
      local (appendBody current "A sprint changes only timebox; break changes visible structure; a better way creates explicit enabling Work.")
    (WorkSprintDurationOpportunity brickId selection, action, _)
      | Just minutes <- sprintMinutesForAction action ->
          mutate 3 (decideStartSprint state actor brickId selection minutes) makeFocused
    (WorkSprintDurationOpportunity{}, "work.sprint.custom", _) ->
      local (appendBody current "Custom durations use an integer from 1 to 120 minutes; the typed editor follows the same preview-before-start rule.")
    (WorkSprintDurationOpportunity{}, "work.sprint.unknown", _) ->
      local (appendBody current "A sprint is a bounded attempt, not an estimate, deadline, progress claim, or promise of completion.")
    (WorkSkipReactionOpportunity{}, "work.reaction.unknown", _) ->
      local (appendBody current "Choose the smallest concrete recovery that would help. Navigating back records no symptom.")
    (WorkSkipReactionOpportunity{}, _, _) ->
      local (appendBody current "This recovery continues through its own explicit preview. No symptom or structural change has been recorded yet.")
    (_, "palette.open", _) -> pure (Right (RespondResult cursor current Nothing dryRun))
    _ -> pure (Left unavailable)
 where
  current = checkpointCurrent checkpoint
  state = loadedState dataset
  cursor = loadedCursor dataset
  precondition = statePreconditionHash state
  actor = appActor environment

  acceptProviderConnection draft = case appProviderConnectionRuntime environment of
    Nothing -> pure (Left (providerConnectionUnavailable "This host cannot finish the provider connection."))
    Just runtime ->
      loadConnectionProfileSnapshot environment >>= \case
        Left problem -> pure (Left problem)
        Right profile ->
          case refreshProviderConnectionDraft runtime profile draft of
            Left problem -> pure (Left problem)
            Right refreshed
              | refreshed /= draft ->
                  local
                    ( appendBody
                        (advanceEnvelope current (makeProviderConnectionEnvelope (envelopeInteractionId current) cursor precondition now state refreshed))
                        "The profile or signed provider authority changed after the prior preview. Review this refreshed connection before authorizing."
                    )
              | dryRun ->
                  local (appendBody current "Dry run revalidated the profile, Pack, account, binding, client ID, and signed scopes. No OAuth request ran and no configuration or vault entry changed.")
              | otherwise ->
                  ensureConnectionVaultUnlocked (connectionProfilePaths profile) >>= \case
                    Left problem -> pure (Left problem)
                    Right () -> case connectionOAuthClient (connectionProfileRegistry profile) draft of
                      Left problem -> pure (Left problem)
                      Right client ->
                        runTransientDeviceAuthorization environment runtime client >>= \case
                          Left problem -> pure (Left problem)
                          Right tokenSet ->
                            persistOAuthTokenSet
                              (Profile.vaultSocket (connectionProfilePaths profile))
                              client
                              (providerConnectionBinding draft)
                              (providerConnectionDisplayName draft <> " · " <> Profile.providerAccountLabel (providerConnectionAccount draft))
                              tokenSet
                              >>= \case
                                Left problem -> pure (Left problem)
                                Right () -> case applyProviderConnectionDraft (connectionProfileIntegrations profile) draft of
                                  Left problem -> pure (Left problem)
                                  Right changed ->
                                    Profile.writeIntegrationsConfigIfRevision
                                      (connectionProfilePaths profile)
                                      (providerConnectionProfileRevision draft)
                                      changed
                                      >>= \case
                                        Left problem -> pure (Left problem)
                                        Right True -> finishProviderConnection draft
                                        Right False ->
                                          pure . Left $
                                            (appError Conflict "The profile changed after provider authorization; the new vault entry remains safe but is not yet referenced.")
                                              { appErrorRetrySafety = RetryAfterRefresh
                                              , appErrorRecovery = [RecoveryAction "review-again" "Run the same connection command again to build a fresh preview; no source data changed." Nothing]
                                              }

  refreshProviderConnectionDraft runtime profile draft =
    prepareProviderConnectionDraft
      (providerConnectionDefinitions runtime)
      (connectionProfileRegistry profile)
      (connectionProfileIntegrations profile)
      (connectionProfileRevision profile)
      (providerConnectionSource draft)
      (providerConnectionAccountName draft)
      (Profile.providerAccountLabel (providerConnectionAccount draft))
      (providerConnectionClientId draft)
      (Profile.credentialBindingVaultEntry (providerConnectionBinding draft))

  finishProviderConnection draft = do
    let result =
          makeProviderConnectionResultEnvelope
            (envelopeInteractionId current)
            cursor
            precondition
            now
            state
            (providerConnectionSource draft)
            (providerConnectionAccountName draft)
            (Profile.providerAccountLabel (providerConnectionAccount draft))
    local (advanceEnvelope current result)

  acceptImport source expected eraseAfterImport =
    importPortMaterialize (appImportPort environment) source (sourcePreflightMode expected) >>= \case
      Left problem -> pure (Left problem)
      Right materialization ->
        let reread = importMaterializationRead materialization
         in case validateImportCleanupRequest (sourcePreflightMode expected) eraseAfterImport (importReadPreflight reread) of
              Left problem -> pure (Left problem)
              Right ()
                | importReadSourceReference reread /= source || importReadPreflight reread /= expected -> do
                    let refreshed =
                          makeImportPreflightEnvelope
                            (envelopeInteractionId current)
                            cursor
                            precondition
                            now
                            state
                            (actorProfile actor)
                            (importReadSourceReference reread)
                            eraseAfterImport
                            (importReadPreflight reread)
                        staleEnvelope = appendBody (advanceEnvelope current refreshed) "The source or its signed adapter changed after the prior preview. Review this refreshed preflight before importing."
                    local staleEnvelope
                | otherwise ->
                    case importAcceptanceUUIDCount state source expected of
                      Left problem -> pure (Left problem)
                      Right count -> do
                        facts <- runtimeFacts environment count cursor
                        case decideAcceptImport state actor source (importReadInput reread) expected (importMaterializationObjects materialization) facts of
                          Left problem -> pure (Left problem)
                          Right decision -> do
                            acceptedResult <-
                              if null (importAcceptanceEvents decision)
                                then pure (Right dataset)
                                else persistOrSimulate environment dryRun dataset (importAcceptanceEvents decision)
                            case acceptedResult of
                              Left problem -> pure (Left problem)
                              Right accepted -> do
                                identity <- appAllocateUUID environment
                                currentNow <- appZonedNow environment
                                let acceptedState = loadedState accepted
                                    cleanupReady =
                                      eraseAfterImport
                                        && sourcePreflightMode expected == SourceMigrate
                                        && observedCleanupSupported (sourcePreflightObservation expected)
                                    resultEnvelope =
                                      makeImportResultEnvelope
                                        identity
                                        (loadedCursor accepted)
                                        (statePreconditionHash acceptedState)
                                        currentNow
                                        acceptedState
                                        (importAcceptanceImportedRaws decision)
                                        (importAcceptanceReusedRaws decision)
                                        cleanupReady
                                        dryRun
                                    nextCheckpoint = PresentationCheckpoint resultEnvelope [] []
                                saveUnlessDry environment dryRun nextCheckpoint
                                pure . Right $
                                  RespondResult
                                    (loadedCursor accepted)
                                    resultEnvelope
                                    (importAcceptanceCommandId decision)
                                    dryRun

  beginPackTrust draft =
    reacquirePackInstall draft >>= \case
      Left problem -> invalidatePackCheckpoint problem
      Right candidate ->
        loadPackProfileSnapshot environment >>= \case
          Left problem -> pure (Left problem)
          Right profile
            | packProfileRevision profile /= packInstallProfileRevision draft ->
                refreshPackInstall candidate profile "The profile changed after the prior preview. Review this refreshed installation candidate before continuing."
            | otherwise -> do
                let authenticated = packCandidateAuthenticated candidate
                    identity = authenticatedPackIdentity authenticated
                    publisher =
                      TrustedCommunityPublisher
                        (artifactPublisher identity)
                        (authenticatedSignerPublicKey authenticated)
                        (authenticatedSignerFingerprint authenticated)
                case validateTrustedCommunityPublisher publisher of
                  Left problem -> pure (Left problem)
                  Right ()
                    | publisher `Set.member` Profile.trustedPublishers (packProfileIntegrations profile) ->
                        refreshPackInstall candidate profile "This exact publisher key is already trusted. Installation remains unapproved."
                    | otherwise -> do
                        let trustDraft =
                              PackTrustDraft
                                { packTrustSource = PackArchiveSigner
                                , packTrustSourcePath = packCandidateCanonicalPath candidate
                                , packTrustSourceSha256 = packCandidateSourceSha256 candidate
                                , packTrustPublisher = publisher
                                , packTrustProfileRevision = packProfileRevision profile
                                , packTrustReturnToInstall = Just draft
                                }
                            candidateEnvelope = makePackTrustEnvelope (envelopeInteractionId current) cursor precondition now state trustDraft
                        local (advanceEnvelope current candidateEnvelope)

  acceptPackTrust draft =
    reacquirePackTrust draft >>= \case
      Left problem -> invalidatePackCheckpoint problem
      Right publisher ->
        loadPackProfileSnapshot environment >>= \case
          Left problem -> pure (Left problem)
          Right profile
            | packProfileRevision profile /= packTrustProfileRevision draft ->
                refreshPackTrust draft publisher profile "The profile changed after the prior trust preview. Review this key again before trusting it."
            | otherwise -> do
                let integrations = packProfileIntegrations profile
                    alreadyTrusted = publisher `Set.member` Profile.trustedPublishers integrations
                    changed = integrations{Profile.trustedPublishers = Set.insert publisher (Profile.trustedPublishers integrations)}
                if dryRun
                  then local (appendBody current "Dry run revalidated this exact publisher key and profile revision. No trust was stored and installation remains unavailable.")
                  else
                    if alreadyTrusted
                      then finishPackTrust draft publisher
                      else
                        Profile.writeIntegrationsConfigIfRevision (packProfilePaths profile) (packTrustProfileRevision draft) changed >>= \case
                          Left problem -> pure (Left problem)
                          Right True -> finishPackTrust draft publisher
                          Right False ->
                            loadPackProfileSnapshot environment >>= \case
                              Left problem -> pure (Left problem)
                              Right refreshed -> refreshPackTrust draft publisher refreshed "The profile changed before trust could be stored. Nothing was overwritten; review the refreshed decision."

  acceptPackInstall draft =
    reacquirePackInstall draft >>= \case
      Left problem -> invalidatePackCheckpoint problem
      Right candidate ->
        loadPackProfileSnapshot environment >>= \case
          Left problem -> pure (Left problem)
          Right profile
            | packProfileRevision profile /= packInstallProfileRevision draft ->
                refreshPackInstall candidate profile "The profile changed after the prior preview. Review this refreshed installation candidate before installing."
            | otherwise ->
                case preparePackInstallDraft profile candidate of
                  Left problem -> pure (Left problem)
                  Right refreshedDraft
                    | refreshedDraft /= draft ->
                        refreshPackInstall candidate profile "The candidate's current trust or component plan differs from the prior preview. Review it again before installing."
                    | otherwise -> do
                        let authenticated = packCandidateAuthenticated candidate
                            enabled = Set.fromList (packInstallEnabledComponents draft)
                        case authorizePackInstall (packProfileObservedAt profile) (packProfileScope profile) (packProfileTrustPolicy profile) enabled authenticated of
                          Left problem -> pure (Left problem)
                          Right authorized
                            | dryRun ->
                                local (appendBody current "Dry run revalidated the exact archive, signer trust, component authority, and profile revision. No archive was stored and no pin changed.")
                            | otherwise ->
                                storeAuthorizedPack (PackStoreConfig (Profile.packStoreDirectory (packProfilePaths profile))) authorized >>= \case
                                  Left problem -> pure (Left problem)
                                  Right _ -> do
                                    let pin = installAuthorizedPin authorized
                                        integrations = packProfileIntegrations profile
                                        changed = integrations{Profile.installedComponents = Map.insert (artifactName (pinArtifact pin)) pin (Profile.installedComponents integrations)}
                                    Profile.writeIntegrationsConfigIfRevision (packProfilePaths profile) (packInstallProfileRevision draft) changed >>= \case
                                      Left problem -> pure (Left problem)
                                      Right True -> finishPackInstall (pinArtifact pin)
                                      Right False ->
                                        loadPackProfileSnapshot environment >>= \case
                                          Left problem -> pure (Left problem)
                                          Right refreshed -> refreshPackInstall candidate refreshed "The profile changed before the pin could be stored. Nothing was overwritten; the unreferenced archive is safe to collect. Review the refreshed plan."

  backFromPackTrust draft = case packTrustReturnToInstall draft of
    Nothing -> replaceWithFresh
    Just installDraft ->
      reacquirePackInstall installDraft >>= \case
        Left problem -> invalidatePackCheckpoint problem
        Right candidate ->
          loadPackProfileSnapshot environment >>= \case
            Left problem -> pure (Left problem)
            Right profile -> refreshPackInstall candidate profile "The publisher remains untrusted and installation remains unapproved."

  reacquirePackInstall draft =
    readPackArchiveCandidate (packInstallSourcePath draft) >>= \case
      Left problem ->
        pure . Left $
          (packInputChanged "The Pack archive changed or became unreadable after the preview." (packInstallSourcePath draft))
            { appErrorDetails = appErrorMessage problem : appErrorDetails problem
            }
      Right candidate ->
        let authenticated = packCandidateAuthenticated candidate
            matches =
              packCandidateCanonicalPath candidate == packInstallSourcePath draft
                && packCandidateSourceSha256 candidate == packInstallSourceSha256 draft
                && authenticatedPackIdentity authenticated == packInstallArtifact draft
                && authenticatedSignerFingerprint authenticated == packInstallSignerFingerprint draft
         in pure $
              if matches
                then Right candidate
                else Left (packInputChanged "The Pack archive changed after the preview." (packInstallSourcePath draft))

  reacquirePackTrust draft = case packTrustSource draft of
    StandalonePublisherKey ->
      readPackPublisherKeyDocument (packTrustSourcePath draft) >>= \case
        Left problem ->
          pure . Left $
            (packInputChanged "The Pack publisher-key file changed or became unreadable after the preview." (packTrustSourcePath draft))
              { appErrorDetails = appErrorMessage problem : appErrorDetails problem
              }
        Right (path, digest, document) ->
          pure $
            if path == packTrustSourcePath draft
              && digest == packTrustSourceSha256 draft
              && publisherKeyTrust document == packTrustPublisher draft
              then Right (publisherKeyTrust document)
              else Left (packInputChanged "The Pack publisher-key file changed after the preview." (packTrustSourcePath draft))
    PackArchiveSigner -> case packTrustReturnToInstall draft of
      Nothing -> pure (Left (appError CorruptData "A Pack-archive trust preview lost its installation custody."))
      Just installDraft ->
        reacquirePackInstall installDraft >>= \case
          Left problem -> pure (Left problem)
          Right candidate ->
            let authenticated = packCandidateAuthenticated candidate
                identity = authenticatedPackIdentity authenticated
                publisher = TrustedCommunityPublisher (artifactPublisher identity) (authenticatedSignerPublicKey authenticated) (authenticatedSignerFingerprint authenticated)
             in pure $
                  if packCandidateCanonicalPath candidate == packTrustSourcePath draft
                    && packCandidateSourceSha256 candidate == packTrustSourceSha256 draft
                    && publisher == packTrustPublisher draft
                    then Right publisher
                    else Left (packInputChanged "The Pack signer changed after the trust preview." (packTrustSourcePath draft))

  refreshPackInstall candidate profile message =
    case preparePackInstallDraft profile candidate of
      Left problem -> invalidatePackCheckpoint problem
      Right refreshedDraft -> do
        let candidateEnvelope = makePackInstallEnvelope (envelopeInteractionId current) cursor precondition now state refreshedDraft (packCandidateAuthenticated candidate)
        local (appendBody (advanceEnvelope current candidateEnvelope) message)

  refreshPackTrust draft publisher profile message
    | publisher `Set.member` Profile.trustedPublishers (packProfileIntegrations profile) = finishPackTrust draft publisher
    | otherwise = do
        let refreshedDraft = draft{packTrustProfileRevision = packProfileRevision profile}
            candidateEnvelope = makePackTrustEnvelope (envelopeInteractionId current) cursor precondition now state refreshedDraft
        local (appendBody (advanceEnvelope current candidateEnvelope) message)

  finishPackTrust draft publisher = case packTrustReturnToInstall draft of
    Nothing -> do
      let result = makePackTrustResultEnvelope (envelopeInteractionId current) cursor precondition now state publisher
      local (advanceEnvelope current result)
    Just installDraft ->
      reacquirePackInstall installDraft >>= \case
        Left problem -> invalidatePackCheckpoint problem
        Right candidate ->
          loadPackProfileSnapshot environment >>= \case
            Left problem -> pure (Left problem)
            Right profile ->
              case preparePackInstallDraft profile candidate of
                Left problem -> pure (Left problem)
                Right refreshedDraft -> do
                  let preview = makePackInstallEnvelope (envelopeInteractionId current) cursor precondition now state refreshedDraft (packCandidateAuthenticated candidate)
                  local (appendBody (advanceEnvelope current preview) "Publisher trusted. Installation is still unapproved.")

  finishPackInstall artifact = do
    let result = makePackInstallResultEnvelope (envelopeInteractionId current) cursor precondition now state artifact
    local (advanceEnvelope current result)

  invalidatePackCheckpoint problem = do
    unless dryRun (discardPendingCheckpoint environment)
    pure (Left problem)

  replaceWithFresh = do
    fresh <- freshCheckpoint environment dataset
    case fresh of
      Left problem -> pure (Left problem)
      Right nextCheckpoint -> saveAndReturn nextCheckpoint Nothing

  replaceWithRecordedForecast =
    createRecordedForecastCheckpoint environment dryRun dataset >>= \case
      Left problem -> pure (Left problem)
      Right (accepted, nextCheckpoint) -> do
        saveUnlessDry environment dryRun nextCheckpoint
        pure . Right $ RespondResult (loadedCursor accepted) (checkpointCurrent nextCheckpoint) Nothing dryRun

  withBrick identity continue = case Map.lookup identity (stateBricks state) of
    Nothing -> pure (Left (appError NotFound "The Brick used by this interaction no longer exists."))
    Just brick | brickStatus brick == BrickActive -> continue brick
    Just _ -> pure (Left (appError PreconditionFailed "The Brick used by this interaction is no longer active."))

  withWait identity continue = case Map.lookup identity (stateWaits state) of
    Nothing -> pure (Left (appError NotFound "The Wait used by this interaction no longer exists."))
    Just gate
      | waitStatus gate /= WaitActive -> pure (Left (appError PreconditionFailed "The Wait used by this interaction is no longer active."))
      | otherwise -> withBrick (waitAffectedBrick gate) (continue gate)

  withDelegation identity continue = case Map.lookup identity (stateDelegations state) of
    Nothing -> pure (Left (appError NotFound "The Delegation used by this interaction no longer exists."))
    Just delegation
      | delegationStatus delegation /= DelegationActive -> pure (Left (appError PreconditionFailed "The Delegation used by this interaction is no longer active."))
      | otherwise -> withBrick (delegationBrick delegation) (continue delegation)

  withProposedDelegation identity continue = case Map.lookup identity (stateDelegations state) of
    Nothing -> pure (Left (appError NotFound "The proposed Delegation used by this interaction no longer exists."))
    Just delegation
      | delegationStatus delegation /= DelegationProposed -> pure (Left (appError PreconditionFailed "The Delegation is no longer awaiting handoff."))
      | otherwise -> withBrick (delegationBrick delegation) (continue delegation)

  withActiveEntity identity continue = case Map.lookup identity (stateExternalEntities state) of
    Just entity | externalEntityActive entity -> continue entity
    _ -> pure (Left (appError NotFound "The selected person or company is no longer active."))

  continueWithEntity brick selection purpose entity =
    case purpose of
      WaitTargetPurpose -> local (makeWaitRequestStatusEnvelope current now state brick selection entity)
      DelegationTargetPurpose ->
        case delegationStartEnvelope current now state brick selection entity of
          Left explanation -> local (appendBody current explanation)
          Right envelope -> local envelope

  delegationStartEnvelope base currentNow currentState brick selection entity =
    case brickNature brick of
      Habit -> Left "A habit remains your embodied practice. Create separate enabling Work when another person can help."
      ScheduledCommitment -> Left "Attendance cannot be delegated in V1. Delegate an ordinary preparation child instead."
      Project -> Right (makeDelegationScopeEnvelope base currentNow currentState brick initialDraft)
      AtomicTask -> fixed BrickOnlyDelegation
      Collection -> fixed BrickOnlyDelegation
      Repeatable -> fixed BrickOnlyDelegation
      LivingChecklist -> fixed WholeScopeDelegation
      FiniteChecklist -> fixed WholeScopeDelegation
      RecurringObligation -> fixed WholeScopeDelegation
   where
    initialDraft = DelegationDraft (brickId brick) selection (externalEntityId entity) Nothing Nothing Nothing ""
    fixed scope = Right (makeDelegationPolicyEnvelope base currentNow currentState brick initialDraft{delegationDraftScope = Just scope})

  continueDelegationScope draft scope =
    withBrick (delegationDraftBrick draft) $ \brick ->
      local (makeDelegationPolicyEnvelope current now state brick draft{delegationDraftScope = Just scope})

  initialDelegationMessage currentState brick target scope =
    let recipient = maybe "there" externalEntityName (Map.lookup target (stateExternalEntities currentState))
        rendered = renderHandle BrickHandle (brickHandle brick) <> " \"" <> brickTitle brick <> "\""
     in case scope of
          BrickOnlyDelegation -> "Hi " <> recipient <> ", could you take care of " <> rendered <> "?"
          WholeScopeDelegation -> "Hi " <> recipient <> ", could you take responsibility for " <> rendered <> ", including its current and future work?"

  delegationFollowUpAllowed delegation = case delegationFollowUpPolicy delegation of
    FollowUpNone -> False
    FollowUpOnce -> delegationFollowUpHandoffs delegation == 0
    FollowUpEvery -> delegationFollowUpHandoffs delegation < 2 + delegationExtraFollowUps delegation

  delegationFollowUpMessage currentState delegation =
    let recipient = maybe "there" externalEntityName (Map.lookup (delegationTarget delegation) (stateExternalEntities currentState))
        rendered = maybe "the delegated Work" (\brick -> renderHandle BrickHandle (brickHandle brick) <> " \"" <> brickTitle brick <> "\"") (Map.lookup (delegationBrick delegation) (stateBricks currentState))
     in "Hi " <> recipient <> ", could you share an update on " <> rendered <> "?"

  withEffect identity continue = case Map.lookup identity (stateExternalEffects state) of
    Nothing -> pure (Left (appError NotFound "The external effect used by this interaction no longer exists."))
    Just effect -> case Map.lookup (externalEffectDelegation effect) (stateDelegations state) of
      Nothing -> pure (Left (appError CorruptData "The external effect has no owning Delegation."))
      Just delegation -> withBrick (delegationBrick delegation) (continue effect)

  reviewInstant seconds = ZonedInstant (addUTCTime seconds (zonedTimeToUTC now)) (operationalZone (stateOperationalDayConfig state))

  waitDelaySeconds = \case
    "wait.delay.tomorrow" -> Just 86400
    "wait.delay.three-days" -> Just (3 * 86400)
    "wait.delay.week" -> Just (7 * 86400)
    _ -> Nothing

  waitActivationSeconds = \case
    "wait.activate.tomorrow" -> Just 86400
    "wait.activate.three-days" -> Just (3 * 86400)
    "wait.activate.week" -> Just (7 * 86400)
    _ -> Nothing

  waitRequestDelaySeconds = \case
    "wait.request.delay.tomorrow" -> Just 86400
    "wait.request.delay.three-days" -> Just (3 * 86400)
    "wait.request.delay.week" -> Just (7 * 86400)
    _ -> Nothing

  effectDelaySeconds = \case
    "effect.delay.tomorrow" -> Just 86400
    "effect.delay.three-days" -> Just (3 * 86400)
    "effect.delay.week" -> Just (7 * 86400)
    _ -> Nothing

  entityKindForAction = \case
    "entity.kind.person" -> Just PersonEntity
    "entity.kind.team" -> Just TeamEntity
    "entity.kind.organization" -> Just OrganizationEntity
    "entity.kind.agent" -> Just AIAgentEntity
    "entity.kind.service" -> Just ServiceEntity
    _ -> Nothing

  followUpPolicyForAction = \case
    "delegation.policy.once" -> Just FollowUpOnce
    "delegation.policy.every" -> Just FollowUpEvery
    "delegation.policy.none" -> Just FollowUpNone
    _ -> Nothing

  delegationDelaySecondsForAction = \case
    "delegation.delay.day" -> Just (24 * 3600)
    "delegation.delay.three-days" -> Just (72 * 3600)
    "delegation.delay.week" -> Just (168 * 3600)
    _ -> Nothing

  delegationReviewInstant identity =
    reviewInstant . fromIntegral $
      maybe (72 * 3600) delegationReviewDelaySeconds (Map.lookup identity (stateDelegations state))

  withNotice identity continue =
    case find ((== identity) . candidateNoticeIdentity) (noticeCandidates state (zonedTimeToUTC now)) of
      Nothing -> pure (Left (appError NotFound "This exact temporal notice is no longer available."))
      Just candidate -> continue candidate

  snoozeNotice notice choice = withNotice notice $ \candidate -> do
    chosen <- noticeSnoozeInstant environment (stateOperationalDayConfig state) choice
    case chosen of
      Left problem -> pure (Left problem)
      Right notBefore ->
        mutate 2 (decideNoticeDisposition state actor notice (NoticeSnoozed notBefore)) (makeNoticeUpdated candidate ("Snoozed until " <> Text.pack (show (zonedInstantUtc notBefore)) <> "."))

  withRepeatableReview ownerId reviewId continue =
    withBrick ownerId $ \owner ->
      case Map.lookup reviewId (stateLazyReviews state) of
        Just review
          | brickNature owner == Repeatable
          , lazyReviewSubject review == ownerId
          , lazyReviewKind review == "repeatable_return_policy" ->
              continue owner review
        _ -> pure (Left (appError PreconditionFailed "The repeatable completion checkpoint is missing or stale."))

  withScheduled ownerId continue =
    withBrick ownerId $ \owner ->
      case Map.lookup ownerId (stateScheduledIntervals state) of
        Just interval
          | brickNature owner == ScheduledCommitment
          , zonedInstantUtc (scheduledStartsAt interval) <= zonedTimeToUTC now ->
              continue owner interval
        _ -> pure (Left (appError PreconditionFailed "The scheduled commitment is no longer active at this checkpoint."))

  prepareReturnPreview owner review policy suppliedSeed =
    prepareReturnProposal (brickId owner) policy suppliedSeed >>= \case
      Left problem -> pure (Left problem)
      Right proposal ->
        case (repeatableReturnChosenOffset proposal, repeatableReturnNotBefore proposal, repeatableReturnResolution proposal, repeatableReturnSeed proposal) of
          (Just chosen, Just notBefore, Just resolution, Just seed) ->
            local (makeRepeatableReturnPreviewEnvelope current now state owner review policy chosen notBefore resolution seed)
          _ -> pure (Left (appError CorruptData "A scheduled return preview is incomplete."))

  prepareReturnProposal ownerId policy suppliedSeed = do
    baseFacts <- runtimeFacts environment 0 cursor
    seed <- case suppliedSeed <|> stateRandomSeed state of
      Just existing -> pure existing
      Nothing -> Entropy.getEntropy 32
    let facts = baseFacts{runtimeRandomBlocks = Map.singleton RepeatableReturnJitter [seed]}
    case policy of
      ManualOnlyReturn -> pure (prepareRepeatableReturn state ownerId policy impossibleResolver facts)
      AfterCompletionReturn _ _ _ zoneName -> do
        loaded <- try (loadTZFromDB (Text.unpack zoneName)) :: IO (Either SomeException TZ)
        pure $ case loaded of
          Left problem ->
            Left
              (appError InvalidInput "That IANA time zone could not be loaded.")
                { appErrorDetails = [Text.pack (displayException problem)]
                , appErrorRecovery = [RecoveryAction "edit" "Choose a canonical IANA zone such as America/Montevideo." Nothing]
                }
          Right zone -> prepareRepeatableReturn state ownerId policy (returnResolver zoneName zone) facts

  returnResolver zoneName zone completedAt unit amount =
    let (instant, resolution) = resolveReturnInstant zone completedAt unit amount
     in Right (ZonedInstant instant zoneName, localResolutionText resolution)

  impossibleResolver _ _ _ = Left (appError CorruptData "A manual-only return unexpectedly requested calendar resolution.")

  emptyReturnFacts =
    RuntimeFacts
      nowUtc
      []
      mempty
      (FilesystemFacts True True (Just (renderCursor cursor)))
      (TerminalCapabilities False False False 80 24 False)
      []
   where
    nowUtc = zonedTimeToUTC now

  localResolutionText = \case
    UniqueLocalTime -> "unique"
    GapShiftedForward -> "gap_shifted_forward"
    FoldEarlier -> "fold_earlier"

  returnUnitForAction = \case
    "return.unit.days" -> Just ReturnDays
    "return.unit.weeks" -> Just ReturnWeeks
    "return.unit.months" -> Just ReturnMonths
    "return.unit.years" -> Just ReturnYears
    _ -> Nothing

  parseWholeNumber positive input =
    case reads (Text.unpack (Text.strip input)) of
      [(value, "")]
        | value >= 0
        , not positive || value > 0 ->
            Right value
      _ ->
        Left
          (appError InvalidInput (if positive then "Enter a positive whole number." else "Enter a nonnegative whole number."))

  openBreak brick selection symptom =
    if supportsChildParts (brickNature brick)
      then local (makeWorkBreakDraftEnvelope current now state brick selection symptom Nothing [])
      else local (makeWorkBreakNatureEnvelope current now state brick selection symptom)

  startScope scope =
    local (startOrderEnvelope now state current (orderSessionFor state (zonedTimeToUTC now) ContinuousOrder scope))

  answerPair session above below explicitlyRetired reason =
    case detectContradiction state (zonedTimeToUTC now) ImportanceAxis above below of
      FreshContradiction path
        | null explicitlyRetired ->
            local (makeImportanceContradictionEnvelope current now state session above below (fmap judgmentId (directedPathJudgments path)))
      NoContradiction weakPath -> record (explicitlyRetired <> weakPath)
      _ -> record explicitlyRetired
   where
    record retired =
      mutateJudgment
        2
        (decidePairJudgment state actor ImportanceAxis above below MoreThan DirectHuman JudgmentCurrent (Set.toAscList (Set.fromList retired)) "order" reason)
        (afterImportance session above "Importance recorded.")

  afterImportance session subject message base currentNow accepted _ =
    let updated = session{orderSessionComparisons = orderSessionComparisons session + 1}
        acceptedState = loadedState accepted
     in case orderSessionCadence session of
          ContinuousOrder -> startOrderEnvelope currentNow acceptedState base updated
          LotteryOrder -> makeJudgmentResultEnvelope base currentNow acceptedState ImportanceAxis subject message

  skipPair session first second skips skipped provocative =
    case candidates of
      alternative : _ | skips == 0 -> local (makeImportanceReviewEnvelope current now state session first alternative 1 (skipped <> [second]) provocative)
      _ ->
        mutateJudgment 2 (decideImportanceProvisional state actor first "nearby importance comparisons skipped") (afterProvisional session first)
   where
    parent = brickParent =<< Map.lookup first (stateBricks state)
    candidates = filter (`notElem` skipped) (nearbyComparators state parent first second)

  tieBreakPair session first second skipped provocative =
    mutateJudgment
      2
      (decideImportanceProvisional state actor first "deterministic_tie_break")
      (afterTieBreak session first second skipped provocative)

  afterTieBreak session first second skipped provocative base currentNow accepted mutation =
    let acceptedState = loadedState accepted
        parent = brickParent =<< Map.lookup first (stateBricks acceptedState)
        candidates = filter (\candidate -> candidate `notElem` (second : skipped)) (nearbyComparators acceptedState parent first second)
     in case candidates of
          alternative : _ -> makeImportanceReviewEnvelope base currentNow acceptedState session first alternative 1 (second : skipped) provocative
          [] -> afterProvisional session first base currentNow accepted mutation

  afterProvisional session _brickId base currentNow accepted _ =
    let paused = session{orderSessionGroupIndex = orderSessionGroupIndex session + 1}
        acceptedState = loadedState accepted
     in case orderSessionCadence session of
          ContinuousOrder -> startOrderEnvelope currentNow acceptedState base paused
          LotteryOrder -> makeOrderResultEnvelope base currentNow acceptedState paused False 1

  answerImpactComparison subject comparator above below relation =
    case if relation == MoreThan then detectContradiction state (zonedTimeToUTC now) ImpactAxis above below else NoContradiction [] of
      FreshContradiction path ->
        local (makeImpactContradictionEnvelope current now state subject comparator above below relation (fmap judgmentId (directedPathJudgments path)))
      NoContradiction weakPath ->
        mutateJudgment
          2
          (decidePairJudgment state actor ImpactAxis above below relation DirectHuman JudgmentCurrent weakPath "impact_comparison" "direct")
          (judgmentReceipt ImpactAxis subject "Impact comparison recorded.")

  answerEffortComparison brick exemplarId index remaining tried narrowed above below relation =
    case if relation == MoreThan then detectContradiction state (zonedTimeToUTC now) EffortAxis above below else NoContradiction [] of
      FreshContradiction path ->
        local (makeEffortContradictionEnvelope current now state (brickId brick) exemplarId index remaining tried above below relation (fmap judgmentId (directedPathJudgments path)))
      NoContradiction weakPath ->
        mutateJudgment
          2
          (decidePairJudgment state actor EffortAxis above below relation DirectHuman JudgmentCurrent weakPath "effort_exemplar" "direct")
          (afterEffortComparison brick narrowed (index + 1) (tried <> [exemplarId]))

  resolveAxisAid axis subject triad retired winnerText aboutSame =
    case parseUUIDv7 winnerText of
      Left _ -> pure (Left (appError InvalidInput "The selected contradiction answer is invalid."))
      Right winner
        | winner `notElem` triad -> pure (Left (appError InvalidInput "The selected Brick is not in this contradiction aid."))
        | otherwise ->
            let others = filter (/= winner) triad
                relations
                  | aboutSame = fmap (sameRelation winner) others
                  | axis == EffortAxis = fmap (lessEffortRelation winner) others
                  | otherwise = fmap (moreRelation winner) others
             in mutateJudgment
                  (length relations + 1)
                  (decideAxisTriadRelations state actor axis relations retired)
                  (judgmentReceipt axis subject (axisResultName axis <> " recalibrated."))

  afterEffortComparison brick remaining index tried base currentNow accepted _ =
    let acceptedState = loadedState accepted
        acceptedBrick = fromMaybe brick (Map.lookup (brickId brick) (stateBricks acceptedState))
     in case remaining of
          [effort] -> makeEffortProposalEnvelope base currentNow acceptedState acceptedBrick effort
          _
            | index >= 3 -> makeEffortNarrowedEnvelope base currentNow acceptedState acceptedBrick remaining
            | otherwise -> case nextEffortExemplar acceptedState (brickId brick) remaining tried of
                Just exemplar -> makeEffortExemplarEnvelope base currentNow acceptedState acceptedBrick exemplar index remaining tried
                Nothing -> makeEffortNarrowedEnvelope base currentNow acceptedState acceptedBrick remaining

  withTwoBricks firstId secondId continue =
    withBrick firstId $ \firstBrick -> case Map.lookup secondId (stateBricks state) of
      Just secondBrick | brickStatus secondBrick == BrickActive -> continue firstBrick secondBrick
      _ -> pure (Left (appError PreconditionFailed "The comparison exemplar is no longer active."))

  effortDirectionAction relation above subject
    | relation == AboutSame = "effort.same"
    | above == subject = "effort.more"
    | otherwise = "effort.less"

  sameRelation winner other = (winner, other, AboutSame)
  lessEffortRelation winner other = (other, winner, MoreThan)
  moreRelation winner other = (winner, other, MoreThan)

  chooseTriadWinner session triad winnerText = case parseUUIDv7 winnerText of
    Left _ -> pure (Left (appError InvalidInput "The selected contradiction winner is invalid."))
    Right winner
      | winner `notElem` triad -> pure (Left (appError InvalidInput "The selected winner is not in this contradiction aid."))
      | otherwise ->
          let losers = filter (/= winner) triad
              retired = incompatibleJudgments state (zonedTimeToUTC now) winner losers
           in mutateJudgment 3 (decideTriadWinner state actor winner losers retired) (afterImportance session winner "Importance recalibrated.")

  answerImportanceDiscovery session first second node alternate action =
    case action of
      "importance.discovery.yes" -> yesBranch
      "importance.discovery.no" -> noBranch False
      "importance.discovery.unknown" -> unknownBranch
      _ -> pure (Left unavailable)
   where
    screen nextNode nextAlternate = local (makeImportanceDiscoveryEnvelope current now state session first second nextNode nextAlternate)
    yesBranch = case node of
      UnderstandFirstResult -> screen UnderstandSecondResult False
      InspectFirstContext -> screen UnderstandFirstResult False
      UnderstandSecondResult -> screen ChooseFirstForever False
      InspectSecondContext -> screen UnderstandSecondResult False
      ChooseFirstForever -> local (makeImportanceDirectionEnvelope current now state session first second)
      ChooseSecondForever -> local (makeImportanceDirectionEnvelope current now state session second first)
      AcceptEitherOrder -> local (makeImportanceEitherEnvelope current now state session first second)
      SeekNewEvidence -> local (appendBody current "Feed the evidence or investigation Work that would help decide this relationship. The comparison remains pending and neither Brick becomes blocked.")
      TryNearbySibling -> nearbyOrProvisional
    noBranch fromUnknown = case node of
      UnderstandFirstResult -> screen InspectFirstContext fromUnknown
      InspectFirstContext -> local (appendBody current "More evidence about the first Brick is needed. Use contextual /feed; the pending comparison alone creates no Work automatically.")
      UnderstandSecondResult -> screen InspectSecondContext fromUnknown
      InspectSecondContext -> local (appendBody current "More evidence about the second Brick is needed. Use contextual /feed; the pending comparison alone creates no Work automatically.")
      ChooseFirstForever -> screen ChooseSecondForever fromUnknown
      ChooseSecondForever -> screen AcceptEitherOrder fromUnknown
      AcceptEitherOrder -> screen SeekNewEvidence fromUnknown
      SeekNewEvidence -> screen TryNearbySibling fromUnknown
      TryNearbySibling -> local (makeImportanceProvisionalEnvelope current now state session first second)
    unknownBranch = case node of
      UnderstandFirstResult -> noBranch True
      UnderstandSecondResult -> noBranch True
      ChooseFirstForever -> noBranch True
      ChooseSecondForever -> noBranch True
      InspectFirstContext -> screen InspectFirstContext (not alternate)
      InspectSecondContext -> screen InspectSecondContext (not alternate)
      AcceptEitherOrder -> screen AcceptEitherOrder (not alternate)
      SeekNewEvidence -> screen SeekNewEvidence (not alternate)
      TryNearbySibling -> screen TryNearbySibling (not alternate)
    nearbyOrProvisional =
      let parent = brickParent =<< Map.lookup first (stateBricks state)
       in case nearbyComparators state parent first second of
            alternative : _ -> local (makeImportanceReviewEnvelope current now state session first alternative 0 [second] False)
            [] -> local (makeImportanceProvisionalEnvelope current now state session first second)

  mutateJudgment count decision resultBuilder = do
    facts <- runtimeFacts environment count cursor
    case decision facts of
      Left problem -> pure (Left problem)
      Right mutation -> do
        acceptedResult <- persistOrSimulate environment dryRun dataset (judgmentMutationEvents mutation)
        case acceptedResult of
          Left problem -> pure (Left problem)
          Right accepted -> do
            identity <- appAllocateUUID environment
            currentNow <- appZonedNow environment
            let base =
                  resealEnvelope
                    current
                      { envelopeInteractionId = identity
                      , envelopeRevision = 0
                      , envelopeDatasetCursor = loadedCursor accepted
                      , envelopePreconditionHash = statePreconditionHash (loadedState accepted)
                      }
                envelope = resultBuilder base currentNow accepted mutation
                nextCheckpoint = PresentationCheckpoint envelope [] []
            saveUnlessDry environment dryRun nextCheckpoint
            pure . Right $ RespondResult (loadedCursor accepted) envelope (Just (judgmentMutationCommandId mutation)) dryRun

  judgmentReceipt axis brickId message base currentNow accepted _ =
    makeJudgmentResultEnvelope base currentNow (loadedState accepted) axis brickId message

  local envelope = saveAndReturn (PresentationCheckpoint envelope (current : checkpointBack checkpoint) []) Nothing

  saveAndReturn nextCheckpoint commandId = do
    saveUnlessDry environment dryRun nextCheckpoint
    pure . Right $ RespondResult cursor (checkpointCurrent nextCheckpoint) commandId dryRun

  withRaw identity continue = case Map.lookup identity (stateRaws state) of
    Nothing -> pure (Left (appError NotFound "The Raw used by this interaction no longer exists."))
    Just raw -> continue raw

  withSourceBinding identity continue = case Map.lookup identity (stateSourceBindings state) of
    Nothing -> pure (Left (appError NotFound "The SourceBinding used by this interaction no longer exists."))
    Just binding -> continue binding

  withSourceObservation identity continue = case Map.lookup identity (stateSourceObservations state) of
    Nothing -> pure (Left (appError NotFound "The SourceObservation used by this interaction no longer exists."))
    Just observation -> continue observation

  withObservationBinding observationId continue =
    withSourceObservation observationId $ \observation -> withSourceBinding (sourceObservationBinding observation) (continue observation)

  sourcePreview observationId choice = withSourceObservation observationId $ \observation -> local (makeSourceReconciliationPreviewEnvelope current now state observation choice)

  makeSourceMutationResult message identity currentNow accepted mutation = do
    raw <- maybe (Left (appError CorruptData "The source reconciliation result has no Raw.")) Right (mutationDecisionRaw mutation)
    acceptedRaw <- maybe (Left (appError CorruptData "The source reconciliation Raw is missing after acceptance.")) Right (Map.lookup (rawId raw) (stateRaws (loadedState accepted)))
    pure (makeSourceResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) acceptedRaw message)

  withRawAndBrick rawIdentity brickIdentity continue =
    withRaw rawIdentity $ \raw -> case Map.lookup brickIdentity (stateBricks state) of
      Nothing -> pure (Left (appError NotFound "The selected Brick no longer exists."))
      Just brick -> continue raw brick

  attach rawIdentity targetIdentity role =
    mutate 4 (decideAttachRaw state actor rawIdentity targetIdentity role) (makeAttachedResult targetIdentity role)

  makeAttachedResult targetIdentity role identity currentNow accepted mutation = do
    raw <- maybe (Left (appError CorruptData "The attached source Raw is missing.")) Right (mutationDecisionRaw mutation)
    target <- maybe (Left (appError CorruptData "The attachment target is missing.")) Right (Map.lookup targetIdentity (stateBricks (loadedState accepted)))
    pure (makeRawAttachmentResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) raw target role)
  withContextRaw context = withRaw (workContextRawId context)
  chooseNature context identifier = case find ((== identifier) . natureDefinitionId) factoryNatures of
    Nothing -> pure (Left (appError InvalidInput "The selected Nature is not in the factory catalog."))
    Just definition -> withContextRaw context $ \raw -> local (makeTemplateChoiceEnvelope current now state raw context (natureValue definition))

  chooseTemplate context nature identifier = case findTemplate identifier of
    Just definition | templateNature definition == nature -> openTitle context nature (Just (TemplateSelection identifier (templateDefinitionVersion definition) "factory"))
    _ -> pure (Left (appError InvalidInput "The selected Template is unknown or incompatible with the Nature."))

  openTitle context nature template = withContextRaw context $ \raw -> local (makeWorkTitleEnvelope current now state raw context nature template (titleDraftFromRaw raw))

  acceptTitle context nature template title
    | Text.null (Text.strip title) = pure (Left (appError InvalidInput "A Brick title cannot be empty."))
    | otherwise = withContextRaw context $ \raw ->
        let parent = workContextParent context
            candidates = maybe [] (maybe [] (Set.toAscList . brickDomains) . (`Map.lookup` stateBricks state)) parent
            initialDomains = if null candidates then workContextDomains context else Set.fromList candidates
            initialDraft = WorkDraft (workContextRawId context) (Text.strip title) nature template parent initialDomains 0 (Provisional "importance insertion pending") []
         in if null candidates
              then beginExistingWorkCheck raw initialDraft
              else local (makeDomainSelectionEnvelope current now state raw initialDraft candidates)

  beginExistingWorkCheck raw draft =
    case find matching (activeBricks state) of
      Nothing -> beginImportance raw draft
      Just existing -> local (makeExistingWorkSuspicionEnvelope current now state raw draft existing)
   where
    matching brick =
      brickParent brick == workDraftParent draft
        && Text.toCaseFold (Text.unwords (Text.words (brickTitle brick))) == Text.toCaseFold (Text.unwords (Text.words (workDraftTitle draft)))

  makeExistingWorkResult existingId identity currentNow accepted mutation = do
    raw <- maybe (Left (appError CorruptData "The reused Work source Raw is missing.")) Right (mutationDecisionRaw mutation)
    existing <- maybe (Left (appError CorruptData "The reused Work is missing.")) Right (Map.lookup existingId (stateBricks (loadedState accepted)))
    pure (makeExistingWorkReuseResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) raw existing)
  beginImportance raw draft =
    case orderedSiblings state (workDraftParent draft) of
      [] -> local (makeWorkPreviewEnvelope current now state raw draft{workDraftImportanceConfidence = DeterministicPosition "sole_sibling"})
      siblings ->
        let index = length siblings `div` 2
            comparator = brickId (siblings !! index)
         in local (makeImportanceInsertionEnvelope current now state raw draft 0 (length siblings) [] comparator)

  answerImportance draft low high skipped comparator action = withRaw (workDraftRawId draft) $ \raw ->
    case findIndexById comparator siblings of
      Nothing -> pure (Left (appError PreconditionFailed "The comparison sibling is no longer available."))
      Just index -> case action of
        "importance.more" -> continueImportance raw draft{workDraftComparisons = workDraftComparisons draft <> [DraftAbove comparator]} low index skipped
        "importance.less" -> continueImportance raw draft{workDraftComparisons = workDraftComparisons draft <> [DraftBelow comparator]} (index + 1) high skipped
        "importance.skip" -> skipImportance raw draft low high (skipped <> [comparator]) index
        "importance.assistance" -> local (appendBody current "Compare enduring importance: if only one could ever be completed, which loss would matter more? Uncertainty is not equality; skip tries a nearby sibling.")
        _ -> pure (Left unavailable)
   where
    siblings = orderedSiblings state (workDraftParent draft)

  continueImportance raw draft nextLow nextHigh skipped
    | nextLow >= nextHigh =
        local (makeWorkPreviewEnvelope current now state raw draft{workDraftSiblingPosition = nextLow, workDraftImportanceConfidence = HumanComparison})
    | otherwise =
        let index = nextLow + ((nextHigh - nextLow) `div` 2)
         in local (makeImportanceInsertionEnvelope current now state raw draft nextLow nextHigh skipped (brickId (orderedSiblings state (workDraftParent draft) !! index)))

  skipImportance raw draft low high skipped currentIndex =
    case nearbyComparator (orderedSiblings state (workDraftParent draft)) low high skipped currentIndex of
      Just nextComparator | length skipped < 2 -> local (makeImportanceInsertionEnvelope current now state raw draft low high skipped nextComparator)
      _ -> local (makeWorkPreviewEnvelope current now state raw draft{workDraftSiblingPosition = currentIndex, workDraftImportanceConfidence = Provisional "nearby importance comparisons skipped"})

  chooseShelfDestination rawIdentity shelfText = case parseUUIDv7 shelfText of
    Left _ -> pure (Left (appError InvalidInput "The selected RawShelf identity is invalid."))
    Right shelfIdentity -> case Map.lookup shelfIdentity (stateRawShelves state) of
      Nothing -> pure (Left (appError NotFound "The selected RawShelf no longer exists."))
      Just shelf
        | not (rawShelfActive shelf) -> pure (Left (appError PreconditionFailed "The selected RawShelf is archived."))
        | otherwise -> withRaw rawIdentity $ \raw -> local (makeRawShelfMembershipPreviewEnvelope current now state raw shelf)

  makeRawShelfResult identity currentNow accepted mutation = do
    raw <- maybe (Left (appError CorruptData "The RawShelf source Raw is missing.")) Right (mutationDecisionRaw mutation)
    case Map.lookup (rawId raw) (stateRawDispositions (loadedState accepted)) of
      Just (RawPlacedOnShelf shelfId) -> do
        shelf <- maybe (Left (appError CorruptData "The accepted RawShelf is missing.")) Right (Map.lookup shelfId (stateRawShelves (loadedState accepted)))
        pure (makeRawShelfResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) raw shelf)
      _ -> Left (appError CorruptData "The accepted Raw has no RawShelf disposition.")
  chooseDestination rawId targetText = case parseUUIDv7 targetText of
    Left _ -> pure (Left (appError InvalidInput "The selected destination identity is invalid."))
    Right targetId -> case Map.lookup targetId (stateBricks state) of
      Nothing -> pure (Left (appError NotFound "The selected destination Brick no longer exists."))
      Just target -> withRaw rawId $ \raw ->
        case brickNature target of
          LivingChecklist -> chooseChecklistDestination raw target
          FiniteChecklist -> chooseChecklistDestination raw target
          _ -> local (makeRawUnderBrickEnvelope current now state raw target)

  chooseChecklistDestination raw owner =
    let (label, quantity) = listEntryDraftFromRaw raw
        matches =
          [ entry
          | entry <- Map.elems (stateListEntries state)
          , listEntryOwner entry == brickId owner
          , listEntryState entry == EntryOpen
          , normalizedLabel (listEntryLabel entry) == normalizedLabel label
          ]
     in case sortOn listEntryInsertionOrdinal matches of
          entry : _ -> local (makeListEntryReuseEnvelope current now state raw owner entry quantity)
          [] -> local (makeListEntryPreviewEnvelope current now state raw owner label quantity)

  answerNature context discovery action = withContextRaw context $ \raw -> case action of
    "nature.answer.unknown"
      | discoveryAlternateProbe discovery -> local (advanceEnvelope current (makeRawTriageEnvelope (envelopeInteractionId current) cursor precondition now state raw))
      | otherwise -> local (makeNatureDiscoveryEnvelope current now state raw context discovery{discoveryAlternateProbe = True})
    "nature.answer.yes" -> applyNatureBranch raw context discovery True
    "nature.answer.no" -> applyNatureBranch raw context discovery False
    _ -> pure (Left unavailable)

  applyNatureBranch raw context discovery answer =
    case natureBranch discovery answer of
      Left (nature, reason) -> local (makeNatureConfirmationEnvelope current now state raw context nature reason (discoveryQuestion discovery))
      Right nextQuestion -> local (makeNatureDiscoveryEnvelope current now state raw context (NatureDiscovery nextQuestion False (discoveryHistory discovery <> [discoveryQuestion discovery])))

  showTranslationScope scope =
    let (titles, raws, unsupported) = translationScopeCounts state scope
        candidate = makeTranslationScopeEnvelope (envelopeInteractionId current) cursor precondition now state scope titles raws unsupported
     in local (advanceEnvelope current candidate)

  makeTranslationAccepted queue identity currentNow accepted _ =
    let acceptedState = loadedState accepted
        base = acceptedBase identity currentNow accepted
     in Right (translationEnvelopeAfter base currentNow acceptedState (advanceTranslationQueue True queue))

  mutate count decision resultBuilder = do
    facts <- runtimeFacts environment count cursor
    case decision facts of
      Left problem -> pure (Left problem)
      Right mutation -> do
        acceptedResult <- persistOrSimulate environment dryRun dataset (mutationDecisionEvents mutation)
        case acceptedResult of
          Left problem -> pure (Left problem)
          Right accepted -> do
            identity <- appAllocateUUID environment
            currentNow <- appZonedNow environment
            case resultBuilder identity currentNow accepted mutation of
              Left problem -> pure (Left problem)
              Right envelope -> do
                let nextCheckpoint = PresentationCheckpoint envelope [] []
                saveUnlessDry environment dryRun nextCheckpoint
                pure . Right $ RespondResult (loadedCursor accepted) envelope (Just (mutationDecisionCommandId mutation)) dryRun

  feedRequestTitle brickId selection entityId title = do
    facts <- runtimeFacts environment 3 cursor
    case decideFeed state actor "guided_request" title facts of
      Left problem -> pure (Left problem)
      Right decision ->
        persistOrSimulate environment dryRun dataset (feedDecisionEvents decision) >>= \case
          Left problem -> pure (Left problem)
          Right accepted -> do
            identity <- appAllocateUUID environment
            currentNow <- appZonedNow environment
            let acceptedState = loadedState accepted
                base = acceptedBase identity currentNow accepted
            case (Map.lookup brickId (stateBricks acceptedState), Map.lookup entityId (stateExternalEntities acceptedState)) of
              (Just brick, Just entity) | brickStatus brick == BrickActive && externalEntityActive entity -> do
                let envelope = makeWaitRequestDelayEnvelope base currentNow acceptedState brick selection entity (feedDecisionRaw decision)
                    nextCheckpoint = PresentationCheckpoint envelope [] []
                saveUnlessDry environment dryRun nextCheckpoint
                pure . Right $ RespondResult (loadedCursor accepted) envelope (Just (feedDecisionCommandId decision)) dryRun
              _ -> pure (Left (appError PreconditionFailed "The request subject or response target changed while preserving the Raw."))

  makeFreshResult identity currentNow accepted _ =
    pure (chooseFreshEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted))

  makeEntityCreated brickId selection purpose identity currentNow accepted _ = do
    let acceptedState = loadedState accepted
        created =
          [ entity
          | (entityId, entity) <- Map.toAscList (stateExternalEntities acceptedState)
          , Map.notMember entityId (stateExternalEntities state)
          ]
    entity <- case created of
      [value] -> Right value
      _ -> Left (appError CorruptData "The accepted person-or-company command did not create exactly one identity.")
    brick <- maybe (Left (appError CorruptData "The responsibility subject disappeared after person creation.")) Right (Map.lookup brickId (stateBricks acceptedState))
    let base = acceptedBase identity currentNow accepted
    case purpose of
      WaitTargetPurpose -> pure (makeWaitRequestStatusEnvelope base currentNow acceptedState brick selection entity)
      DelegationTargetPurpose ->
        case delegationStartEnvelope base currentNow acceptedState brick selection entity of
          Left explanation -> Left (appError PreconditionFailed explanation)
          Right envelope -> Right envelope

  makeWaitActivated brickId identity currentNow accepted _ = do
    let acceptedState = loadedState accepted
        candidates =
          [ gate
          | gate <- Map.elems (stateWaits acceptedState)
          , waitAffectedBrick gate == brickId
          , waitStatus gate == WaitActive
          ]
    gate <- case sortOn waitId candidates of
      [value] -> Right value
      _ -> Left (appError CorruptData "Wait activation did not yield exactly one active gate for the Work.")
    brick <- maybe (Left (appError CorruptData "The Wait subject disappeared after activation.")) Right (Map.lookup brickId (stateBricks acceptedState))
    pure (makeWaitActivationResultEnvelope identity (loadedCursor accepted) (statePreconditionHash acceptedState) currentNow acceptedState brick gate)

  makeDependencyRecorded blockedId blockerId identity currentNow accepted _ = do
    let acceptedState = loadedState accepted
    blocked <- maybe (Left (appError CorruptData "The blocked Work disappeared after Dependency replay.")) Right (Map.lookup blockedId (stateBricks acceptedState))
    blocker <- maybe (Left (appError CorruptData "The prerequisite Work disappeared after Dependency replay.")) Right (Map.lookup blockerId (stateBricks acceptedState))
    pure (makeDependencyResultEnvelope identity (loadedCursor accepted) (statePreconditionHash acceptedState) currentNow acceptedState blocked blocker)

  makeRequestHandoffRecorded affectedId identity currentNow accepted mutation = do
    let acceptedState = loadedState accepted
    affected <- maybe (Left (appError CorruptData "The affected Work disappeared after request-handoff replay.")) Right (Map.lookup affectedId (stateBricks acceptedState))
    enabling <- maybe (Left (appError CorruptData "The request handoff did not create its enabling Work.")) Right (mutationDecisionBrick mutation)
    successor <-
      case [candidate | candidate <- Map.elems (stateWaitSuccessors acceptedState), waitSuccessorEnablingBrick candidate == brickId enabling, waitSuccessorAffectedBrick candidate == affectedId] of
        [candidate] -> Right candidate
        _ -> Left (appError CorruptData "The request handoff did not declare exactly one successor Wait.")
    pure (makeWaitRequestHandoffResultEnvelope identity (loadedCursor accepted) (statePreconditionHash acceptedState) currentNow acceptedState affected enabling successor)

  makeDelegationProposed brickId identity currentNow accepted _ = do
    let acceptedState = loadedState accepted
        candidates =
          [ delegation
          | delegation <- Map.elems (stateDelegations acceptedState)
          , delegationBrick delegation == brickId
          , delegationStatus delegation == DelegationProposed
          ]
    delegation <- case sortOn delegationId candidates of
      [value] -> Right value
      _ -> Left (appError CorruptData "Delegation acceptance did not yield exactly one proposed responsibility record.")
    brick <- maybe (Left (appError CorruptData "The delegated Work disappeared after replay.")) Right (Map.lookup brickId (stateBricks acceptedState))
    pure (makeDelegationHandoffEnvelope identity (loadedCursor accepted) (statePreconditionHash acceptedState) currentNow acceptedState brick delegation)

  makeEffectApproval effectIdentity identity currentNow accepted _ = do
    let acceptedState = loadedState accepted
    effect <- maybe (Left (appError CorruptData "The revised external effect disappeared after replay.")) Right (Map.lookup effectIdentity (stateExternalEffects acceptedState))
    delegation <- maybe (Left (appError CorruptData "The revised external effect lost its Delegation.")) Right (Map.lookup (externalEffectDelegation effect) (stateDelegations acceptedState))
    brick <- maybe (Left (appError CorruptData "The revised external effect lost its Work.")) Right (Map.lookup (delegationBrick delegation) (stateBricks acceptedState))
    pure (makeExternalEffectApprovalEnvelope identity (loadedCursor accepted) (statePreconditionHash acceptedState) currentNow acceptedState brick effect)

  makeNewEffectApproval delegationIdentity identity currentNow accepted _ = do
    let acceptedState = loadedState accepted
        effects =
          [ effect
          | effect <- Map.elems (stateExternalEffects acceptedState)
          , externalEffectDelegation effect == delegationIdentity
          , externalEffectPurpose effect == DelegationFollowUpEffect
          , externalEffectStatus effect == EffectPendingApproval
          , Map.notMember (externalEffectId effect) (stateExternalEffects state)
          ]
    effect <- case effects of
      [value] -> Right value
      _ -> Left (appError CorruptData "The no-response review did not create exactly one pending follow-up effect.")
    delegation <- maybe (Left (appError CorruptData "The follow-up effect lost its Delegation.")) Right (Map.lookup delegationIdentity (stateDelegations acceptedState))
    brick <- maybe (Left (appError CorruptData "The follow-up effect lost its Work.")) Right (Map.lookup (delegationBrick delegation) (stateBricks acceptedState))
    pure (makeExternalEffectApprovalEnvelope identity (loadedCursor accepted) (statePreconditionHash acceptedState) currentNow acceptedState brick effect)

  acceptedBase identity _currentNow accepted =
    current
      { envelopeInteractionId = identity
      , envelopeRevision = 0
      , envelopeDatasetCursor = loadedCursor accepted
      , envelopePreconditionHash = statePreconditionHash (loadedState accepted)
      }

  makeWaitUpdated waitIdentity message identity currentNow accepted _ = do
    gate <- maybe (Left (appError CorruptData "The reviewed Wait disappeared after replay.")) Right (Map.lookup waitIdentity (stateWaits (loadedState accepted)))
    brick <- maybe (Left (appError CorruptData "The Wait subject disappeared after replay.")) Right (Map.lookup (waitAffectedBrick gate) (stateBricks (loadedState accepted)))
    pure (makeWaitResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick gate message)

  makeDelegationUpdated delegationIdentity message identity currentNow accepted _ = do
    delegation <- maybe (Left (appError CorruptData "The reviewed Delegation disappeared after replay.")) Right (Map.lookup delegationIdentity (stateDelegations (loadedState accepted)))
    brick <- maybe (Left (appError CorruptData "The Delegation subject disappeared after replay.")) Right (Map.lookup (delegationBrick delegation) (stateBricks (loadedState accepted)))
    pure (makeDelegationResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick delegation message)

  makeEffectUpdated effectIdentity message identity currentNow accepted _ = do
    effect <- maybe (Left (appError CorruptData "The external effect disappeared after replay.")) Right (Map.lookup effectIdentity (stateExternalEffects (loadedState accepted)))
    delegation <- maybe (Left (appError CorruptData "The external effect lost its owning Delegation.")) Right (Map.lookup (externalEffectDelegation effect) (stateDelegations (loadedState accepted)))
    brick <- maybe (Left (appError CorruptData "The external-effect Work disappeared after replay.")) Right (Map.lookup (delegationBrick delegation) (stateBricks (loadedState accepted)))
    pure (makeExternalEffectResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick effect message)

  makeStandaloneResult identity currentNow accepted mutation = do
    raw <- maybe (Left (appError CorruptData "The standalone Raw result is missing.")) Right (mutationDecisionRaw mutation)
    pure (makeStandaloneResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) raw)

  makeListEntryResult identity currentNow accepted mutation = do
    raw <- maybe (Left (appError CorruptData "The ListEntry source Raw is missing.")) Right (mutationDecisionRaw mutation)
    case Map.lookup (rawId raw) (stateRawDispositions (loadedState accepted)) of
      Just (RawMaterializedAsListEntry ownerId entryId) -> do
        owner <- maybe (Left (appError CorruptData "The ListEntry owner is missing.")) Right (Map.lookup ownerId (stateBricks (loadedState accepted)))
        entry <- maybe (Left (appError CorruptData "The accepted ListEntry is missing.")) Right (Map.lookup entryId (stateListEntries (loadedState accepted)))
        pure (makeListEntryResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) raw owner entry)
      _ -> Left (appError CorruptData "The accepted Raw has no ListEntry disposition.")

  makeWorkCreated identity currentNow accepted mutation = do
    raw <- maybe (Left (appError CorruptData "The Work source Raw is missing.")) Right (mutationDecisionRaw mutation)
    brick <- maybe (Left (appError CorruptData "The created Brick is missing.")) Right (mutationDecisionBrick mutation)
    pure (makeWorkCreatedResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) raw brick)

  makeFocused identity currentNow accepted mutation = do
    brick <- maybe (Left (appError CorruptData "The focused Brick is missing.")) Right (mutationDecisionBrick mutation)
    currentBrick <- maybe (Left (appError CorruptData "The focused Brick disappeared after replay.")) Right (Map.lookup (brickId brick) (stateBricks (loadedState accepted)))
    pure (makeCurrentFocusEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) currentBrick)

  makeChecklist ownerId selected identity currentNow accepted _ = do
    owner <- maybe (Left (appError CorruptData "The checklist owner disappeared after replay.")) Right (Map.lookup ownerId (stateBricks (loadedState accepted)))
    pure (makeChecklistRunEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) owner selected)

  makeChecklistStarted identity currentNow accepted mutation = do
    owner <- maybe (Left (appError CorruptData "The focused checklist is missing.")) Right (mutationDecisionBrick mutation)
    currentOwner <- maybe (Left (appError CorruptData "The focused checklist disappeared after replay.")) Right (Map.lookup (brickId owner) (stateBricks (loadedState accepted)))
    pure (makeChecklistRunEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) currentOwner Nothing)

  makeChecklistFinished ownerId identity currentNow accepted _ = do
    owner <- maybe (Left (appError CorruptData "The finished checklist owner disappeared after replay.")) Right (Map.lookup ownerId (stateBricks (loadedState accepted)))
    pure (makeChecklistRunResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) owner)

  makeCompleted identity currentNow accepted mutation = do
    brick <- maybe (Left (appError CorruptData "The completed Brick is missing.")) Right (mutationDecisionBrick mutation)
    case brickNature brick of
      Repeatable ->
        case [ review
             | review <- Map.elems (stateLazyReviews (loadedState accepted))
             , lazyReviewSubject review == brickId brick
             , lazyReviewKind review == "repeatable_return_policy"
             ] of
          review : _ -> pure (makeRepeatableReturnEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick review)
          [] -> Left (appError CorruptData "A completed repeatable run did not create its return-policy checkpoint.")
      _ -> pure (makeCompletionResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick)

  makeReturnRecorded identity currentNow accepted mutation = do
    brick <- maybe (Left (appError CorruptData "The repeatable Brick is missing from the accepted return policy.")) Right (mutationDecisionBrick mutation)
    pure (makeRepeatableReturnResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick)

  makeScheduled ownerId identity currentNow accepted _ = do
    owner <- maybe (Left (appError CorruptData "The scheduled commitment disappeared after focus.")) Right (Map.lookup ownerId (stateBricks (loadedState accepted)))
    interval <- maybe (Left (appError CorruptData "The focused scheduled commitment lost its exact interval.")) Right (Map.lookup ownerId (stateScheduledIntervals (loadedState accepted)))
    pure (makeScheduledCommitmentEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) owner interval)

  makeScheduledOutcome ownerId outcome identity currentNow accepted _ = do
    owner <- maybe (Left (appError CorruptData "The resolved scheduled commitment disappeared after replay.")) Right (Map.lookup ownerId (stateBricks (loadedState accepted)))
    pure (makeScheduledOutcomeResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) owner outcome)

  makeNoticeUpdated candidate message identity currentNow accepted _ =
    pure (makeNoticeResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) candidate message)

  makeBreakResult parentId identity currentNow accepted mutation = do
    parent <- maybe (Left (appError CorruptData "The decomposed parent is missing after replay.")) Right (Map.lookup parentId (stateBricks (loadedState accepted)))
    let commandId = mutationDecisionCommandId mutation
        children =
          sortOn
            brickSiblingPosition
            [ brick
            | brick <- Map.elems (stateBricks (loadedState accepted))
            , brickParent brick == Just parentId
            , brickCreatedByCommand brick == commandId
            ]
    if null children
      then Left (appError CorruptData "The decomposition committed without replayable child Bricks.")
      else pure (makeWorkBreakResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) parent children)

  makeArchived brickId identity currentNow accepted _ = do
    brick <- maybe (Left (appError CorruptData "The archived Brick disappeared after replay.")) Right (Map.lookup brickId (stateBricks (loadedState accepted)))
    pure (makeArchiveResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick)

  makeRestored brickId identity currentNow accepted _ = do
    brick <- maybe (Left (appError CorruptData "The restored Brick disappeared after replay.")) Right (Map.lookup brickId (stateBricks (loadedState accepted)))
    pure (makeRestoreResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick)

  makeArchiveReviewResult brickId message identity currentNow accepted _ = do
    brick <- maybe (Left (appError CorruptData "The archived Brick disappeared after review.")) Right (Map.lookup brickId (stateBricks (loadedState accepted)))
    pure (makeArchiveReviewResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick message)

  makeDomainFocusResult domainId mode identity currentNow accepted _ = do
    domain <- maybe (Left (appError CorruptData "The focused Domain disappeared after replay.")) Right (Map.lookup domainId (stateDomains (loadedState accepted)))
    pure (makeDomainFocusResultEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) domain mode)

  mutateWorkReaction brickId selection symptom reaction =
    mutate 2 (decideWorkReaction state actor brickId selection symptom reaction) (makeSkipped symptom reaction)

  makeSkipped symptom reaction identity currentNow accepted mutation = do
    brick <- maybe (Left (appError CorruptData "The served Brick is missing from the accepted reaction.")) Right (mutationDecisionBrick mutation)
    pure (makeSkipAcknowledgedEnvelope identity (loadedCursor accepted) (statePreconditionHash (loadedState accepted)) currentNow (loadedState accepted) brick symptom reaction)

  unavailable =
    (appError InvalidInput "That response is not valid for the current opportunity.")
      { appErrorRecovery = [RecoveryAction "continue" "Choose one of the actions shown on the current screen." Nothing]
      }

runNavigation :: AppEnv -> Bool -> LoadedDataset -> InteractionResponse -> Bool -> IO (Either AppError CommandResult)
runNavigation environment dryRun dataset response backward =
  loadPendingCheckpoint environment >>= \case
    Left problem -> pure (Left problem)
    Right Nothing -> pure (Left (appError PreconditionFailed "There is no pending interaction to navigate."))
    Right (Just checkpoint) ->
      if not (navigationMatches (checkpointCurrent checkpoint) response)
        then pure (Left (appError PreconditionFailed "The navigation request is stale or invalid."))
        else case if backward then moveBack checkpoint else moveForward checkpoint of
          Nothing -> pure . Right $ RespondResult (loadedCursor dataset) (checkpointCurrent checkpoint) Nothing dryRun
          Just moved -> do
            saveUnlessDry environment dryRun moved
            pure . Right $ RespondResult (loadedCursor dataset) (checkpointCurrent moved) Nothing dryRun

navigationMatches :: InteractionEnvelope -> InteractionResponse -> Bool
navigationMatches envelope response =
  responseInteractionId response == envelopeInteractionId envelope
    && responseRevision response == envelopeRevision envelope
    && responseIntegrityToken response == envelopeIntegrityToken envelope
    && responseAnsweredCursor response == envelopeDatasetCursor envelope

moveBack :: PresentationCheckpoint -> Maybe PresentationCheckpoint
moveBack checkpoint = case checkpointBack checkpoint of
  [] -> Nothing
  previous : rest -> Just (PresentationCheckpoint previous rest (checkpointCurrent checkpoint : checkpointForward checkpoint))

moveForward :: PresentationCheckpoint -> Maybe PresentationCheckpoint
moveForward checkpoint = case checkpointForward checkpoint of
  [] -> Nothing
  next : rest -> Just (PresentationCheckpoint next (checkpointCurrent checkpoint : checkpointBack checkpoint) rest)

initialDiscovery :: NatureDiscovery
initialDiscovery = NatureDiscovery FixedTimeQuestion False []

natureBranch :: NatureDiscovery -> Bool -> Either (BrickNature, Text) NatureQuestion
natureBranch discovery answer =
  if discoveryAlternateProbe discovery then alternate else direct
 where
  question = discoveryQuestion discovery
  direct = case (question, answer) of
    (FixedTimeQuestion, True) -> leaf ScheduledCommitment "it must happen in an externally fixed time window"
    (FixedTimeQuestion, False) -> Right FiniteIntentionQuestion
    (FiniteIntentionQuestion, True) -> Right MultipartQuestion
    (FiniteIntentionQuestion, False) -> Right ChangingMembersQuestion
    (MultipartQuestion, True) -> Right IndependentPartsQuestion
    (MultipartQuestion, False) -> leaf AtomicTask "one done action completes the finite intention"
    (IndependentPartsQuestion, True) -> leaf Project "parts need independent focus or lifecycle facts"
    (IndependentPartsQuestion, False) -> leaf FiniteChecklist "all finite entries are handled as one scope"
    (ChangingMembersQuestion, True) -> Right IndependentMemberQuestion
    (ChangingMembersQuestion, False) -> Right OpenOccurrenceQuestion
    (IndependentMemberQuestion, True) -> leaf Collection "members may be suggested independently"
    (IndependentMemberQuestion, False) -> leaf LivingChecklist "the changing open set is worked as one scope"
    (OpenOccurrenceQuestion, True) -> leaf RecurringObligation "each required occurrence remains open until closed"
    (OpenOccurrenceQuestion, False) -> Right StreakQuestion
    (StreakQuestion, True) -> leaf Habit "missed windows and streaks belong to its history"
    (StreakQuestion, False) -> leaf Repeatable "each execution finishes without accumulating an overdue occurrence"
  alternate = case (question, answer) of
    (FixedTimeQuestion, True) -> Right FiniteIntentionQuestion
    (FixedTimeQuestion, False) -> leaf ScheduledCommitment "doing it earlier would not satisfy the fixed-time intention"
    (FiniteIntentionQuestion, True) -> Right ChangingMembersQuestion
    (FiniteIntentionQuestion, False) -> Right MultipartQuestion
    (MultipartQuestion, True) -> Right IndependentPartsQuestion
    (MultipartQuestion, False) -> leaf AtomicTask "one done action would not lose separately tracked progress"
    (IndependentPartsQuestion, True) -> leaf Project "a part may need its own next, importance, blocker, date, Domain, or history"
    (IndependentPartsQuestion, False) -> leaf FiniteChecklist "parts do not need independent focus or lifecycle facts"
    (ChangingMembersQuestion, True) -> Right IndependentMemberQuestion
    (ChangingMembersQuestion, False) -> Right OpenOccurrenceQuestion
    (IndependentMemberQuestion, True) -> leaf LivingChecklist "the whole open set must appear together at focus time"
    (IndependentMemberQuestion, False) -> leaf Collection "a member may be served independently"
    (OpenOccurrenceQuestion, True) -> leaf RecurringObligation "an unfinished period remains open or overdue"
    (OpenOccurrenceQuestion, False) -> Right StreakQuestion
    (StreakQuestion, True) -> leaf Habit "an unfulfilled window affects history or a streak"
    (StreakQuestion, False) -> leaf Repeatable "an unfulfilled window does not accumulate or affect a streak"
  leaf nature reason = Left (nature, reason)

nearbyComparator :: [Brick] -> Int -> Int -> [UUIDv7] -> Int -> Maybe UUIDv7
nearbyComparator siblings low high skipped current =
  brickId <$> find eligible candidates
 where
  indices = [current + 1, current - 1, current + 2, current - 2, current + 3, current - 3]
  candidates = mapMaybe (safeIndex siblings) indices
  eligible brick =
    let position = brickSiblingPosition brick
     in position >= low && position < high && brickId brick `notElem` skipped

orderedSiblings :: State -> Maybe UUIDv7 -> [Brick]
orderedSiblings state parent = sortOn (\brick -> (brickSiblingPosition brick, brickId brick)) (siblingBricks state parent)

findIndexById :: UUIDv7 -> [Brick] -> Maybe Int
findIndexById identity = go 0
 where
  go _ [] = Nothing
  go index (brick : rest)
    | brickId brick == identity = Just index
    | otherwise = go (index + 1) rest

safeIndex :: [value] -> Int -> Maybe value
safeIndex values index
  | index < 0 = Nothing
  | otherwise = case drop index values of value : _ -> Just value; [] -> Nothing

titleDraftFromRaw :: Raw -> Text
titleDraftFromRaw raw = case filter (not . Text.null) (fmap Text.strip (Text.lines (rawOriginal raw))) of
  first : _ -> upperFirst first
  [] -> ""
 where
  upperFirst value = case Text.uncons value of
    Nothing -> value
    Just (character, rest)
      | isAsciiLower character -> Text.cons (toEnum (fromEnum character - 32)) rest
      | otherwise -> value

listEntryDraftFromRaw :: Raw -> (Text, Quantity)
listEntryDraftFromRaw raw = case Text.words (rawOriginal raw) of
  first : rest
    | [(amount, "")] <- reads (Text.unpack first)
    , amount > (0 :: Integer)
    , not (null rest) ->
        (Text.unwords rest, Quantity amount 0 "item")
  _ -> (Text.unwords (Text.words (rawOriginal raw)), Quantity 1 0 "item")

normalizedLabel :: Text -> Text
normalizedLabel = Text.toCaseFold . Text.unwords . Text.words

appendBody :: InteractionEnvelope -> Text -> InteractionEnvelope
appendBody envelope explanation =
  resealEnvelope envelope{envelopeRevision = envelopeRevision envelope + 1, envelopeContent = (envelopeContent envelope){contentBody = contentBody (envelopeContent envelope) <> ["", explanation]}}

withExplanation :: InteractionEnvelope -> Text -> Raw -> State -> ZonedTime -> InteractionEnvelope
withExplanation envelope explanation _ _ _ = appendBody envelope explanation

runUndo :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runUndo environment dryRun dataset = do
  facts <- runtimeFacts environment 2 (loadedCursor dataset)
  case decideUndoFeed (loadedState dataset) (appActor environment) facts of
    Left problem -> pure (Left problem)
    Right decision -> finishCompensation environment dryRun dataset decision True

runRedo :: AppEnv -> Bool -> LoadedDataset -> IO (Either AppError CommandResult)
runRedo environment dryRun dataset = do
  facts <- runtimeFacts environment 2 (loadedCursor dataset)
  case decideRedoFeed (loadedState dataset) (appActor environment) facts of
    Left problem -> pure (Left problem)
    Right decision -> finishCompensation environment dryRun dataset decision False

finishCompensation :: AppEnv -> Bool -> LoadedDataset -> UndoDecision -> Bool -> IO (Either AppError CommandResult)
finishCompensation environment dryRun dataset decision isUndo = do
  acceptedResult <- persistOrSimulate environment dryRun dataset (undoDecisionEvents decision)
  case acceptedResult of
    Left problem -> pure (Left problem)
    Right accepted -> do
      checkpointResult <- freshCheckpoint environment accepted
      case checkpointResult of
        Left problem -> pure (Left problem)
        Right checkpoint -> do
          saveUnlessDry environment dryRun checkpoint
          let redoToken = if isUndo then Just (undoToken (undoDecisionCommandId decision) (loadedCursor accepted)) else Nothing
          pure . Right $
            UndoResult
              (undoDecisionCommandId decision)
              (undoDecisionTargetCommandId decision)
              (loadedCursor accepted)
              (rawProjection False (undoDecisionRaw decision))
              redoToken
              (not isUndo)
              (checkpointCurrent checkpoint)
              dryRun

runShow :: Bool -> LoadedDataset -> Text -> ViewDepth -> Either AppError CommandResult
runShow dryRun dataset reference view = do
  handle <- parseRawReference reference
  raw <- maybe (Left notFoundError) Right (resolveRawHandle (loadedState dataset) handle)
  pure (ShowRawResult (loadedCursor dataset) (rawProjection (view == CompleteView) raw) dryRun)
 where
  notFoundError =
    (appError NotFound "No active Raw matches that exact handle.")
      { appErrorSubject = Just reference
      , appErrorRecovery = [RecoveryAction "search" "Search all raw material." (Just ("lant search " <> reference))]
      }

rawCitationText :: Raw -> Text
rawCitationText raw = renderHandle RawHandle (rawHandle raw) <> " \"" <> Text.take 80 (Text.unwords (Text.words (rawOriginal raw))) <> "\""

sourceDifferenceFor :: State -> SourceObservation -> Text
sourceDifferenceFor state observation =
  case (Map.lookup (sourceObservationBinding observation) (stateSourceBindings state) >>= (\binding -> Map.lookup (sourceBindingRaw binding) (stateRaws state)), sourceObservationSnapshot observation) of
    (Just raw, Just observed) -> "Current local representation: " <> contentPreview (currentContent raw) <> "\nObserved source representation: " <> contentPreview observed
    _ -> "No complete source snapshot is available for a safe difference view."
 where
  currentContent raw =
    case Map.lookup (rawId raw) (stateCurrentRawRevisions state) >>= (`Map.lookup` stateRawContentRevisions state) of
      Just revision -> rawContentRevisionContent revision
      Nothing -> RawTextContent "<missing current revision>"
  contentPreview =
    Text.take 400 . \case
      RawTextContent text -> text
      RawUriContent locator label -> fromMaybe locator label
      RawBlobContent digest mediaType lengthBytes filename -> fromMaybe "blob" filename <> " · " <> mediaType <> " · " <> Text.pack (show lengthBytes) <> " bytes · " <> Text.take 12 digest
      RawStructuredContent schema json -> schema <> " · " <> json

sourceLifecycleResult :: SourceBindingLifecycle -> Text
sourceLifecycleResult = \case
  SourceBindingActive -> "Resumed external-origin checks; no missed observation was invented."
  SourceBindingPaused -> "Paused external-origin checks; all local material remains preserved."
  SourceBindingDetached -> "Detached the external origin; all local material and observation history remain preserved."

freshCheckpoint :: AppEnv -> LoadedDataset -> IO (Either AppError PresentationCheckpoint)
freshCheckpoint environment dataset = do
  identity <- appAllocateUUID environment
  now <- appZonedNow environment
  let state = loadedState dataset
      cursor = loadedCursor dataset
      precondition = statePreconditionHash state
      envelope = chooseFreshEnvelope identity cursor precondition now state
  pure (Right (PresentationCheckpoint envelope [] []))

chooseFreshEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> InteractionEnvelope
chooseFreshEnvelope identity cursor precondition now state =
  case activeScheduledCommitments state (zonedTimeToUTC now) of
    [(brick, interval)] -> makeScheduledCommitmentEnvelope identity cursor precondition now state brick interval
    commitments@(_ : _ : _) -> makeScheduledOverlapEnvelope identity cursor precondition now state commitments
    [] | Just brick <- stateCurrentFocus state >>= (`Map.lookup` stateBricks state), brickStatus brick == BrickActive -> activeFocusEnvelope identity cursor precondition now state brick
    [] | Just (brick, review) <- pendingRepeatableReturn state -> makeRepeatableReturnEnvelope identity cursor precondition now state brick review
    _ -> case duplicateOpportunity state of
      Just (candidate, root) -> makeRawDuplicateEnvelope identity cursor precondition now state candidate root
      Nothing -> case orderedInbox state of
        raw : _ -> makeRawTriageEnvelope identity cursor precondition now state raw
        [] -> case orderedFocusable state of
          brick : _ -> makeFocusProposalEnvelope identity cursor precondition now state brick
          [] | stateEventCount state == 0 -> makePristineEnvelope identity cursor precondition now
          [] -> makeSafeEmptyEnvelope identity cursor precondition now

activeScheduledCommitments :: State -> UTCTime -> [(Brick, ScheduledInterval)]
activeScheduledCommitments state now =
  sortOn
    (\(brick, interval) -> (zonedInstantUtc (scheduledStartsAt interval), brickId brick))
    [ (brick, interval)
    | interval <- Map.elems (stateScheduledIntervals state)
    , zonedInstantUtc (scheduledStartsAt interval) <= now
    , Just brick <- [Map.lookup (scheduledIntervalOwner interval) (stateBricks state)]
    , brickNature brick == ScheduledCommitment
    , brickStatus brick == BrickActive
    , not (any (\gate -> waitAffectedBrick gate == brickId brick && waitStatus gate == WaitActive) (Map.elems (stateWaits state)))
    ]

scheduledInterrupts :: InteractionEnvelope -> InteractionEnvelope -> Bool
scheduledInterrupts original replacement =
  isScheduled (envelopeOpportunity replacement)
    && not (isScheduled (envelopeOpportunity original))
 where
  isScheduled = \case
    ScheduledCommitmentOpportunity{} -> True
    ScheduledOverlapOpportunity{} -> True
    _ -> False

activeFocusEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
activeFocusEnvelope identity cursor precondition now state brick =
  case Map.lookup (brickId brick) (stateChecklistRuns state) of
    Just _ -> makeChecklistRunEnvelope identity cursor precondition now state brick Nothing
    Nothing -> makeCurrentFocusEnvelope identity cursor precondition now state brick

pendingRepeatableReturn :: State -> Maybe (Brick, LazyReviewClaim)
pendingRepeatableReturn state =
  case [ (brick, review)
       | review <- sortOn lazyReviewCreatedAt (Map.elems (stateLazyReviews state))
       , lazyReviewKind review == "repeatable_return_policy"
       , Just brick <- [Map.lookup (lazyReviewSubject review) (stateBricks state)]
       , brickStatus brick == BrickActive
       , brickNature brick == Repeatable
       ] of
    first : _ -> Just first
    [] -> Nothing

resolveBrickReference :: State -> Text -> Either AppError Brick
translationCandidates :: State -> TranslationScope -> [TranslationCandidate]
translationCandidates state scope = titleCandidates <> rawCandidates
 where
  titleCandidates =
    [ TranslationBrickTitle (brickId brick)
    | brick <- sortOn brickId (Map.elems (stateBricks state))
    , translationScopeTitles scope
    , translationLifecycleIncludes (translationScopeArchived scope) (brickStatus brick)
    , not (titleNormalizationCurrent state brick)
    ]
  rawCandidates =
    [ TranslationRawRevision (rawId raw) revisionId
    | raw <- sortOn rawId (Map.elems (stateRaws state))
    , translationScopeRaws scope
    , rawTranslationLifecycleIncludes (translationScopeArchived scope) (rawStatus raw)
    , Just revisionId <- [Map.lookup (rawId raw) (stateCurrentRawRevisions state)]
    , Just revision <- [Map.lookup revisionId (stateRawContentRevisions state)]
    , RawTextContent{} <- [rawContentRevisionContent revision]
    , Map.notMember revisionId (stateCurrentEnglishNormalizations state)
    ]

translationScopeCounts :: State -> TranslationScope -> (Int, Int, Int)
translationScopeCounts state scope = (length titles, length raws, unsupported)
 where
  allCandidates = translationCandidates state scope
  titles = [() | TranslationBrickTitle{} <- allCandidates]
  raws = [() | TranslationRawRevision{} <- allCandidates]
  unsupported =
    length
      [ ()
      | raw <- Map.elems (stateRaws state)
      , translationScopeRaws scope
      , rawTranslationLifecycleIncludes (translationScopeArchived scope) (rawStatus raw)
      , Just revisionId <- [Map.lookup (rawId raw) (stateCurrentRawRevisions state)]
      , Just revision <- [Map.lookup revisionId (stateRawContentRevisions state)]
      , case rawContentRevisionContent revision of RawTextContent{} -> False; _ -> True
      ]

translationLifecycleIncludes :: Bool -> BrickStatus -> Bool
translationLifecycleIncludes includeArchived status = status == BrickActive || (includeArchived && status == BrickArchived)

rawTranslationLifecycleIncludes :: Bool -> RawStatus -> Bool
rawTranslationLifecycleIncludes includeArchived status = status == RawAwaitingReview || (includeArchived && status == RawArchived)

titleNormalizationCurrent :: State -> Brick -> Bool
titleNormalizationCurrent state brick =
  case Map.lookup (brickId brick) (stateCurrentBrickTitleNormalizations state) >>= (`Map.lookup` stateBrickTitleNormalizations state) of
    Just normalization -> brickTitleNormalizationCurrent normalization == brickTitle brick
    Nothing -> False

advanceTranslationQueue :: Bool -> TranslationQueue -> TranslationQueue
advanceTranslationQueue accepted queue =
  queue
    { translationQueueRemaining = drop 1 (translationQueueRemaining queue)
    , translationQueueAccepted = translationQueueAccepted queue + if accepted then 1 else 0
    , translationQueueSkipped = translationQueueSkipped queue + if accepted then 0 else 1
    }

translationEnvelopeAfter :: InteractionEnvelope -> ZonedTime -> State -> TranslationQueue -> InteractionEnvelope
translationEnvelopeAfter previous now state queue = case translationQueueRemaining queue of
  [] -> makeTranslationCompleteEnvelope previous now state queue
  _ -> makeTranslationEditorEnvelope previous now state queue Nothing Nothing

resolveTranslationTarget :: State -> Text -> Either AppError TranslationCandidate
resolveTranslationTarget state reference
  | "+" `Text.isPrefixOf` Text.strip reference = rawCandidate =<< resolveAnyRawReference state reference
  | "#" `Text.isPrefixOf` Text.strip reference = TranslationBrickTitle . brickId <$> resolveAnyBrickReference state reference
  | otherwise =
      case (resolveAnyBrickReference state reference, resolveAnyRawReference state reference) of
        (Right brick, Left _) -> Right (TranslationBrickTitle (brickId brick))
        (Left _, Right raw) -> rawCandidate raw
        (Right _, Right _) -> Left (appError AmbiguousReference "That untyped translation target matches both a Brick and Raw; choose its # or + handle.")
        (Left brickProblem, Left _) -> Left brickProblem
 where
  rawCandidate raw = do
    revisionId <- maybe (Left (appError CorruptData "The Raw has no current content revision.")) Right (Map.lookup (rawId raw) (stateCurrentRawRevisions state))
    revision <- maybe (Left (appError CorruptData "The Raw current revision is missing.")) Right (Map.lookup revisionId (stateRawContentRevisions state))
    case rawContentRevisionContent revision of
      RawTextContent{} -> Right (TranslationRawRevision (rawId raw) revisionId)
      _ -> Left (appError Unsupported "This non-text Raw requires an explicit textual extraction before translation.")

resolveAnyRawReference :: State -> Text -> Either AppError Raw
resolveAnyRawReference state reference =
  case exactMatches of
    [raw] -> Right raw
    [] -> Left (appError NotFound "No Raw matches that reference.")
    _ -> Left (appError AmbiguousReference "More than one Raw has that original content; choose one exact + handle.")
 where
  normalized = Text.toCaseFold . Text.unwords . Text.words
  cleaned = Text.dropAround (\character -> character == '"' || character == '\'') (Text.strip reference)
  handleText = Text.dropWhile (== '+') (Text.takeWhile (/= ' ') cleaned)
  exactMatches =
    sortOn
      rawId
      [ raw
      | raw <- Map.elems (stateRaws state)
      , unHandle (rawHandle raw) == handleText || normalized (rawOriginal raw) == normalized cleaned
      ]

resolveBrickReference state reference =
  case exactMatches of
    [brick] -> Right brick
    [] ->
      Left
        (appError NotFound "No active Brick matches that reference.")
          { appErrorSubject = Just reference
          , appErrorRecovery = [RecoveryAction "search" "Use # autocomplete or an exact Brick title." Nothing]
          }
    _ ->
      Left
        (appError AmbiguousReference "More than one active Brick has that title.")
          { appErrorSubject = Just reference
          , appErrorDetails = fmap (renderHandle BrickHandle . brickHandle) exactMatches
          , appErrorRecovery = [RecoveryAction "choose-reference" "Choose one exact # handle." Nothing]
          }
 where
  normalized = Text.toCaseFold . Text.unwords . Text.words
  cleaned = Text.dropAround (\character -> character == '"' || character == '\'') (Text.strip reference)
  handleText = Text.dropWhile (== '#') (Text.takeWhile (/= ' ') cleaned)
  exactMatches =
    sortOn
      brickId
      [ brick
      | brick <- activeBricks state
      , unHandle (brickHandle brick) == handleText || normalized (brickTitle brick) == normalized cleaned
      ]

resolveAnyBrickReference :: State -> Text -> Either AppError Brick
resolveAnyBrickReference state reference =
  case exactMatches of
    [brick] -> Right brick
    [] ->
      Left
        (appError NotFound "No Brick matches that reference.")
          { appErrorSubject = Just reference
          , appErrorRecovery = [RecoveryAction "search" "Use # autocomplete or an exact Brick title." Nothing]
          }
    _ ->
      Left
        (appError AmbiguousReference "More than one Brick has that title.")
          { appErrorSubject = Just reference
          , appErrorDetails = fmap (renderHandle BrickHandle . brickHandle) exactMatches
          }
 where
  normalized = Text.toCaseFold . Text.unwords . Text.words
  cleaned = Text.dropAround (\character -> character == '"' || character == '\'') (Text.strip reference)
  handleText = Text.dropWhile (== '#') (Text.takeWhile (/= ' ') cleaned)
  exactMatches =
    sortOn
      brickId
      [ brick
      | brick <- Map.elems (stateBricks state)
      , unHandle (brickHandle brick) == handleText || normalized (brickTitle brick) == normalized cleaned
      ]

resolveDomainReference :: State -> Text -> Either AppError Domain
resolveDomainReference state reference =
  case matches of
    [domain] -> Right domain
    [] ->
      Left
        (appError NotFound "No active Domain matches that name or complete path.")
          { appErrorSubject = Just reference
          , appErrorRecovery = [RecoveryAction "choose-domain" "Use Domain autocomplete or an exact complete path." Nothing]
          }
    domains ->
      Left
        (appError AmbiguousReference "More than one active Domain has that name.")
          { appErrorSubject = Just reference
          , appErrorDetails = fmap (domainPathText state . domainId) domains
          , appErrorRecovery = [RecoveryAction "choose-domain" "Choose one complete Domain path." Nothing]
          }
 where
  normalized = normalizeDomainText reference
  matches =
    [ domain
    | domain <- Map.elems (stateDomains state)
    , domainActive domain
    , normalized == normalizeDomainText (domainName domain)
        || normalized == normalizeDomainText (domainPathText state (domainId domain))
    ]
  normalizeDomainText = Text.toCaseFold . Text.unwords . Text.words . Text.replace ">" "›"

resolveOrderScope :: State -> Text -> Either AppError OrderScope
resolveOrderScope state reference =
  case resolveBrickReference state reference of
    Right brick -> Right (OneSiblingGroup (if hasChildren brick then Just (brickId brick) else brickParent brick))
    Left brickProblem -> case domainMatches of
      [domain] -> Right (DomainSiblingGroups (domainId domain))
      [] -> Left brickProblem
      _ ->
        Left
          (appError AmbiguousReference "More than one Domain matches that reference.")
            { appErrorSubject = Just reference
            , appErrorRecovery = [RecoveryAction "choose-domain" "Choose one complete Domain path." Nothing]
            }
 where
  hasChildren brick = any ((== Just (brickId brick)) . brickParent) (activeBricks state)
  cleaned = Text.dropAround (\character -> character == '"' || character == '\'') (Text.strip reference)
  normalized = Text.toCaseFold . Text.unwords . Text.words
  domainMatches =
    sortOn
      domainId
      [ domain
      | domain <- Map.elems (stateDomains state)
      , domainActive domain
      , normalized (domainName domain) == normalized cleaned || normalized (domainPathText state (domainId domain)) == normalized cleaned
      ]

orderSessionFor :: State -> UTCTime -> OrderCadence -> OrderScope -> OrderSession
orderSessionFor state now cadence scope = OrderSession scope (scopeGroups state now scope) 0 0 cadence

scopeGroups :: State -> UTCTime -> OrderScope -> [Maybe UUIDv7]
scopeGroups state now scope = filter needsReview candidates
 where
  allGroups = Set.toAscList (Set.fromList (fmap brickParent (activeBricks state)))
  candidates = case scope of
    AllSiblingGroups -> allGroups
    OneSiblingGroup parent -> [parent]
    DomainSiblingGroups domain ->
      [ parent
      | parent <- allGroups
      , any (Set.member domain . brickDomains) (siblingBricks state parent)
      ]
  needsReview parent = length (siblingBricks state parent) >= 2 && isJust (adaptiveImportancePair state now parent)

startOrderEnvelope :: ZonedTime -> State -> InteractionEnvelope -> OrderSession -> InteractionEnvelope
startOrderEnvelope now state previous session =
  case nextOrderPair state (zonedTimeToUTC now) session of
    Just (activeSession, first, second) -> makeImportanceReviewEnvelope previous now state activeSession first second 0 [] False
    Nothing -> makeOrderResultEnvelope previous now state session True 0

nextOrderPair :: State -> UTCTime -> OrderSession -> Maybe (OrderSession, UUIDv7, UUIDv7)
nextOrderPair state now session = seek (max 0 (orderSessionGroupIndex session))
 where
  groups = orderSessionGroups session
  seek index = case drop index groups of
    [] -> Nothing
    parent : _ -> case adaptiveImportancePair state now parent of
      Just (first, second) -> Just (session{orderSessionGroupIndex = index}, first, second)
      Nothing -> seek (index + 1)

compositionRoot :: State -> Brick -> Brick
compositionRoot state brick = case brickParent brick >>= (`Map.lookup` stateBricks state) of
  Nothing -> brick
  Just parent -> compositionRoot state parent

symptomForAction :: Text -> Maybe SkipSymptom
symptomForAction = \case
  "work.symptom.vague" -> Just VagueSymptom
  "work.symptom.hard" -> Just HardSymptom
  "work.symptom.big" -> Just BigSymptom
  "work.symptom.blocked" -> Just BlockedOrWaitingSymptom
  "work.symptom.tired" -> Just TiredSymptom
  "work.symptom.bored" -> Just BoredSymptom
  "work.symptom.fear" -> Just FearSymptom
  "work.symptom.less-important" -> Just LessImportantSymptom
  "work.symptom.out-of-date" -> Just OutOfDateSymptom
  _ -> Nothing

domainFocusModeForAction :: Text -> Maybe DomainFocusMode
domainFocusModeForAction = \case
  "domain-focus.one" -> Just OneSuggestion
  "domain-focus.stay" -> Just StayWithin
  "domain-focus.prefer" -> Just PreferDomain
  _ -> Nothing

skipDiscoveryStep :: SkipDiscoveryNode -> Bool -> Either SkipSymptom SkipDiscoveryNode
skipDiscoveryStep node yes
  | yes = Left (discoveredSymptom node)
  | otherwise =
      case node of
        OutsidePrerequisiteNode -> Right UnclearWorkNode
        UnclearWorkNode -> Right TrackedPartsNode
        TrackedPartsNode -> Right DifficultWorkNode
        DifficultWorkNode -> Right StaleWorkNode
        StaleWorkNode -> Right RelativeImportanceNode
        RelativeImportanceNode -> Right EnergyNode
        EnergyNode -> Right InterestNode
        InterestNode -> Right RiskNode
        RiskNode -> Left (OtherSymptom "")
 where
  discoveredSymptom = \case
    OutsidePrerequisiteNode -> BlockedOrWaitingSymptom
    UnclearWorkNode -> VagueSymptom
    TrackedPartsNode -> BigSymptom
    DifficultWorkNode -> HardSymptom
    StaleWorkNode -> OutOfDateSymptom
    RelativeImportanceNode -> LessImportantSymptom
    EnergyNode -> TiredSymptom
    InterestNode -> BoredSymptom
    RiskNode -> FearSymptom

isOtherSymptom :: SkipSymptom -> Bool
isOtherSymptom OtherSymptom{} = True
isOtherSymptom _ = False

sprintMinutesForAction :: Text -> Maybe Int
sprintMinutesForAction = \case
  "work.sprint.5" -> Just 5
  "work.sprint.15" -> Just 15
  "work.sprint.25" -> Just 25
  _ -> Nothing

domainPathText :: State -> UUIDv7 -> Text
domainPathText state identity = case Map.lookup identity (stateDomains state) of
  Nothing -> "<missing Domain>"
  Just domain -> maybe "" (\parent -> domainPathText state parent <> " › ") (domainParent domain) <> domainName domain

domainIdentityPath :: State -> UUIDv7 -> Maybe [UUIDv7]
domainIdentityPath state identity =
  case Map.lookup identity (stateDomains state) of
    Nothing -> Nothing
    Just domain ->
      Just (maybe [] (fromMaybe [] . domainIdentityPath state) (domainParent domain) <> [identity])

currentParentFor :: State -> Maybe UUIDv7
currentParentFor state = do
  focused <- stateCurrentFocus state >>= (`Map.lookup` stateBricks state)
  if length (siblingBricks state (Just (brickId focused))) >= 2
    then Just (brickId focused)
    else brickParent focused

axisContradictionTriad :: State -> UUIDv7 -> UUIDv7 -> [UUIDv7] -> [UUIDv7]
axisContradictionTriad state first second path =
  take 3 (foldl add [] ([first, second] <> pathNodes))
 where
  pathNodes =
    concat
      [ [judgmentFirst judgment, judgmentSecond judgment]
      | identity <- path
      , Just judgment <- [Map.lookup identity (statePairJudgments state)]
      ]
  add seen identity = if identity `elem` seen then seen else seen <> [identity]

safeFirst :: [value] -> Maybe value
safeFirst = \case
  [] -> Nothing
  first : _ -> Just first

axisResultName :: JudgmentAxis -> Text
axisResultName = \case
  ImportanceAxis -> "Importance"
  ImpactAxis -> "Impact"
  EffortAxis -> "Effort"

contradictionTriad :: State -> UUIDv7 -> UUIDv7 -> [UUIDv7] -> [UUIDv7]
contradictionTriad state first second path = take 3 (deduplicate ([first, second] <> pathNodes <> nearby))
 where
  pathNodes =
    [ judgmentSecond judgment
    | identity <- path
    , Just judgment <- [Map.lookup identity (statePairJudgments state)]
    ]
  parent = brickParent =<< Map.lookup first (stateBricks state)
  nearby = fmap brickId (sortOn brickSiblingPosition (siblingBricks state parent))
  deduplicate = foldl (\seen identity -> if identity `elem` seen then seen else seen <> [identity]) []

incompatibleJudgments :: State -> UTCTime -> UUIDv7 -> [UUIDv7] -> [UUIDv7]
incompatibleJudgments state now winner losers =
  Set.toAscList . Set.fromList $
    [ judgmentId judgment
    | loser <- losers
    , Just path <- [bestDirectedPath state now ImportanceAxis loser winner]
    , judgment <- directedPathJudgments path
    ]

impactEvidenceCandidates :: State -> UUIDv7 -> [UUIDv7]
impactEvidenceCandidates state rootId =
  Set.toAscList . Set.fromList $
    linkedRaws <> completedValidation
 where
  linkedRaws =
    [ rawLinkRaw link
    | link <- Map.elems (stateRawLinks state)
    , rawLinkTarget link == RawLinkBrick rootId
    , rawLinkRole link == EvidenceRole || rawLinkRole link == AttachmentRole
    ]
  completedValidation =
    [ brickId brick
    | brick <- Map.elems (stateBricks state)
    , brickStatus brick == BrickDone
    , isDescendantOf state rootId brick
    , maybe False ((== ValidationPhase) . phaseClaimValue) (Map.lookup (brickId brick) (statePhaseClaims state))
    ]

isDescendantOf :: State -> UUIDv7 -> Brick -> Bool
isDescendantOf state ancestor brick =
  case brickParent brick of
    Nothing -> False
    Just parent
      | parent == ancestor -> True
      | otherwise -> maybe False (isDescendantOf state ancestor) (Map.lookup parent (stateBricks state))

impactComparators :: State -> UUIDv7 -> [UUIDv7] -> [Brick]
impactComparators state subject excluded =
  sortOn
    (\brick -> (impactDistance brick, brickId brick))
    [ brick
    | brick <- activeBricks state
    , isNothing (brickParent brick)
    , brickId brick /= subject
    , brickId brick `notElem` excluded
    , Map.member (brickId brick) (stateImpactClaims state)
    ]
 where
  subjectClass = impactClaimClass <$> Map.lookup subject (stateImpactClaims state)
  impactDistance brick = case (subjectClass, impactClaimClass <$> Map.lookup (brickId brick) (stateImpactClaims state)) of
    (Just left, Just right) -> abs (fromEnum left - fromEnum right)
    _ -> 0

nextEffortExemplar :: State -> UUIDv7 -> [EffortClass] -> [UUIDv7] -> Maybe Brick
nextEffortExemplar state subject remaining tried =
  case sortOn exemplarOrder candidates of
    exemplar : _ -> Just exemplar
    [] -> Nothing
 where
  candidates =
    [ brick
    | brick <- activeBricks state
    , brickId brick /= subject
    , brickId brick `notElem` tried
    , Just claim <- [Map.lookup (brickId brick) (stateEffortClaims state)]
    , effortClaimClass claim `elem` remaining
    ]
  midpoint = case remaining of
    [] -> 0
    first : rest -> (fromEnum first + fromEnum (foldl (const id) first rest)) `div` 2
  exemplarOrder brick =
    let value = maybe midpoint (fromEnum . effortClaimClass) (Map.lookup (brickId brick) (stateEffortClaims state))
     in (abs (value - midpoint), brickId brick)

narrowEffortClasses :: Text -> EffortClass -> [EffortClass] -> [EffortClass]
narrowEffortClasses action exemplar remaining =
  let narrowed = case action of
        "effort.more" -> filter (> exemplar) remaining
        "effort.less" -> filter (< exemplar) remaining
        "effort.same" -> filter (== exemplar) remaining
        _ -> remaining
   in if null narrowed then remaining else narrowed

maturityForYes :: ImpactMaturityQuestion -> ImpactMaturity
maturityForYes = \case
  ObservedResultQuestion -> ObservedImpact
  RepresentativeTestQuestion -> ValidatedImpact
  RelevantSupportQuestion -> SupportedImpact

nextMaturityQuestion :: ImpactMaturityQuestion -> Maybe ImpactMaturityQuestion
nextMaturityQuestion = \case
  ObservedResultQuestion -> Just RepresentativeTestQuestion
  RepresentativeTestQuestion -> Just RelevantSupportQuestion
  RelevantSupportQuestion -> Nothing

impactMaturityName :: ImpactMaturity -> Text
impactMaturityName = \case
  SpeculativeImpact -> "speculative"
  SupportedImpact -> "supported"
  ValidatedImpact -> "validated"
  ObservedImpact -> "observed"

makeImpactClassEnvelopeFrom :: InteractionEnvelope -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeImpactClassEnvelopeFrom previous now state brick =
  advanceEnvelope previous $
    makeImpactClassEnvelope
      (envelopeInteractionId previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      now
      state
      brick

makeEffortClassEnvelopeFrom :: InteractionEnvelope -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeEffortClassEnvelopeFrom previous now state brick =
  advanceEnvelope previous $
    makeEffortClassEnvelope
      (envelopeInteractionId previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      now
      state
      brick

impactClassForAction :: Text -> Maybe ImpactClass
impactClassForAction = (`lookup` table)
 where
  table =
    [ ("impact.class.very-low", VeryLowImpact)
    , ("impact.class.low", LowImpact)
    , ("impact.class.medium", MediumImpact)
    , ("impact.class.high", HighImpact)
    , ("impact.class.very-high", VeryHighImpact)
    , ("impact.class.critical", CriticalImpact)
    ]

effortClassForAction :: Text -> Maybe EffortClass
effortClassForAction = (`lookup` table)
 where
  table =
    [ ("effort.class.very-easy", VeryEasyEffort)
    , ("effort.class.easy", EasyEffort)
    , ("effort.class.normal", NormalEffort)
    , ("effort.class.moderate", ModerateEffort)
    , ("effort.class.hard", HardEffort)
    , ("effort.class.very-hard", VeryHardEffort)
    , ("effort.class.mini-project", MiniProjectEffort)
    , ("effort.class.project", ProjectEffort)
    ]

phaseForAction :: Text -> Maybe WorkPhase
phaseForAction = (`lookup` table)
 where
  table =
    [ ("phase.idea", IdeaPhase)
    , ("phase.spec", SpecPhase)
    , ("phase.execution", ExecutionPhase)
    , ("phase.validation", ValidationPhase)
    ]

impactClassName :: ImpactClass -> Text
impactClassName = \case
  VeryLowImpact -> "VERY LOW"
  LowImpact -> "LOW"
  MediumImpact -> "MEDIUM"
  HighImpact -> "HIGH"
  VeryHighImpact -> "VERY HIGH"
  CriticalImpact -> "CRITICAL"

effortClassName :: EffortClass -> Text
effortClassName = \case
  VeryEasyEffort -> "VERY EASY"
  EasyEffort -> "EASY"
  NormalEffort -> "NORMAL"
  ModerateEffort -> "MODERATE"
  HardEffort -> "HARD"
  VeryHardEffort -> "VERY HARD"
  MiniProjectEffort -> "MINI PROJECT"
  ProjectEffort -> "PROJECT"

phaseName :: WorkPhase -> Text
phaseName = \case
  IdeaPhase -> "Idea"
  SpecPhase -> "Spec"
  ExecutionPhase -> "Execution"
  ValidationPhase -> "Validation"

duplicateOpportunity :: State -> Maybe (Raw, Raw)
duplicateOpportunity state = findCandidate newestFirst
 where
  active = filter ((== RawAwaitingReview) . rawStatus) (Map.elems (stateRaws state))
  newestFirst = sortOn (Down . (\raw -> (rawCreatedAt raw, rawId raw))) active
  findCandidate [] = Nothing
  findCandidate (candidate : rest) = case find (validRoot candidate) rest of
    Just root -> Just (candidate, root)
    Nothing -> findCandidate rest
  validRoot candidate root =
    normalizedRaw candidate == normalizedRaw root
      && Map.notMember (rawId candidate) (stateRawDispositions state)
      && not (isListEntryRoot root)
      && not ((rawId candidate, rawRevision candidate, rawId root, rawRevision root) `Set.member` stateRejectedRawDuplicates state)
  isListEntryRoot root = case Map.lookup (rawId root) (stateRawDispositions state) of
    Just RawMaterializedAsListEntry{} -> True
    _ -> False
  normalizedRaw = Text.toCaseFold . Text.unwords . Text.words . rawOriginal

orderedInbox :: State -> [Raw]
orderedInbox state = case inboxRaws state of
  [] -> []
  raws -> [minimumBy (comparing (\raw -> (rawCreatedAt raw, rawId raw))) raws]

orderedFocusable :: State -> [Brick]
orderedFocusable state =
  sortOn
    (\brick -> (brickSiblingPosition brick, brickCreatedAt brick, brickId brick))
    [ brick
    | brick <- activeBricks state
    , not (any (\child -> brickParent child == Just (brickId brick) && brickStatus child == BrickActive) (Map.elems (stateBricks state)))
    ]

restoreOrCreateCheckpoint :: AppEnv -> LoadedDataset -> IO (Either AppError PresentationCheckpoint)
restoreOrCreateCheckpoint environment dataset =
  loadPendingCheckpoint environment >>= \case
    Left problem -> pure (Left problem)
    Right (Just checkpoint)
      | checkpointIsFresh dataset checkpoint -> pure (Right checkpoint)
    Right _ -> do
      fresh <- freshCheckpoint environment dataset
      case fresh of
        Right checkpoint -> savePendingCheckpoint environment checkpoint >> pure (Right checkpoint)
        Left problem -> pure (Left problem)

checkpointIsFresh :: LoadedDataset -> PresentationCheckpoint -> Bool
checkpointIsFresh dataset checkpoint =
  let envelope = checkpointCurrent checkpoint
   in envelopeDatasetCursor envelope == loadedCursor dataset
        && envelopePreconditionHash envelope == statePreconditionHash (loadedState dataset)
        && all envelopeIntegrityIsValid (envelope : checkpointBack checkpoint <> checkpointForward checkpoint)

runtimeFacts :: AppEnv -> Int -> DatasetCursor -> IO RuntimeFacts
runtimeFacts environment count cursor = do
  now <- appNow environment
  uuids <- replicateM count (appAllocateUUID environment)
  pure
    RuntimeFacts
      { runtimeNow = now
      , runtimeUUIDs = fmap (UUIDAllocation . renderUUIDv7) uuids
      , runtimeRandomBlocks = mempty
      , runtimeFilesystem = FilesystemFacts True True (Just (renderCursor cursor))
      , runtimeTerminal = TerminalCapabilities False False False 80 24 False
      , runtimeExternalFacts = []
      }

persistOrSimulate :: AppEnv -> Bool -> LoadedDataset -> [EventDraft] -> IO (Either AppError LoadedDataset)
persistOrSimulate environment dryRun dataset drafts =
  if dryRun then pure (simulateEvents dataset drafts) else appendCommand (appStore environment) (loadedCursor dataset) drafts

data NoticeSnoozeChoice = SnoozeOneHour | SnoozeTomorrow | SnoozeOneWeek

noticeSnoozeInstant :: AppEnv -> OperationalDayConfig -> NoticeSnoozeChoice -> IO (Either AppError ZonedInstant)
noticeSnoozeInstant environment config choice = do
  now <- appNow environment
  let zoneName = operationalZone config
  case choice of
    SnoozeOneHour -> pure (Right (ZonedInstant (addUTCTime 3600 now) zoneName))
    _ -> do
      loaded <- try (loadTZFromDB (Text.unpack zoneName))
      pure $ case loaded of
        Left problem ->
          Left
            (appError CorruptData "The operational IANA timezone could not be loaded for notice snooze.")
              { appErrorSubject = Just zoneName
              , appErrorDetails = [Text.pack (displayException (problem :: SomeException))]
              }
        Right zone ->
          let days = case choice of SnoozeTomorrow -> 1; SnoozeOneWeek -> 7; SnoozeOneHour -> 0
              targetLocal = addLocalTime (fromIntegral days * nominalDay) (utcToLocalTimeTZ zone now)
              (target, _) = resolveLocalInstant zone targetLocal
           in Right (ZonedInstant target zoneName)

simulateEvents :: LoadedDataset -> [EventDraft] -> Either AppError LoadedDataset
simulateEvents dataset drafts = do
  let sequenceNumber = case loadedCursor dataset of Genesis -> 1; DatasetCursor value _ -> value + 1
      (_, _, events) = encodeSegment sequenceNumber (cursorHash (loadedCursor dataset)) drafts
  state <- foldM applyEvent (loadedState dataset) events
  pure dataset{loadedState = state}

parseRawReference :: Text -> Either AppError Handle
parseRawReference reference = case Text.uncons (Text.takeWhile (/= ' ') (Text.strip reference)) of
  Just ('+', handle) | not (Text.null handle) -> Right (Handle handle)
  _ ->
    Left
      (appError InvalidInput "A Raw reference must begin with + and use an exact current handle.")
        { appErrorSubject = Just reference
        , appErrorRecovery = [RecoveryAction "search" "Use typed Raw search to choose a reference." Nothing]
        }

undoToken :: UUIDv7 -> DatasetCursor -> Text
undoToken commandId cursor = sha256Hex . Text.encodeUtf8 $ renderUUIDv7 commandId <> ":" <> renderCursor cursor

missingInteraction :: PresentationCheckpoint -> AppError
missingInteraction replacement =
  (appError PreconditionFailed "There is no pending interaction to answer.")
    { appErrorCursor = Just (renderCursor (envelopeDatasetCursor (checkpointCurrent replacement)))
    , appErrorRecovery = [RecoveryAction "next" "Obtain a fresh interaction." (Just "lant next")]
    }

checkpointPath :: AppEnv -> FilePath
checkpointPath environment = storeRoot (appStore environment) </> "checkpoints" </> "pending-envelope.json"

discardPendingCheckpoint :: AppEnv -> IO ()
discardPendingCheckpoint environment =
  removeFile (checkpointPath environment)
    `catch` \problem -> unless (isDoesNotExistError problem) (ioError (problem :: IOException))

packInputChanged :: Text -> FilePath -> AppError
packInputChanged message path =
  (appError Conflict message)
    { appErrorSubject = Just (Text.pack path)
    , appErrorRetrySafety = RetryAfterRefresh
    , appErrorRecovery = [RecoveryAction "restart-preview" "Start a new Pack preview from the current file bytes." Nothing]
    }

saveUnlessDry :: AppEnv -> Bool -> PresentationCheckpoint -> IO ()
saveUnlessDry environment dryRun checkpoint = if dryRun then pure () else savePendingCheckpoint environment checkpoint

savePendingCheckpoint :: AppEnv -> PresentationCheckpoint -> IO ()
savePendingCheckpoint environment checkpoint = do
  initializeDataset (appStore environment)
  let path = checkpointPath environment
      temporary = path <> ".tmp"
  LazyByteString.writeFile temporary (encode checkpoint)
  renameFile temporary path

loadPendingCheckpoint :: AppEnv -> IO (Either AppError (Maybe PresentationCheckpoint))
loadPendingCheckpoint environment = do
  exists <- doesFileExist (checkpointPath environment)
  if not exists
    then pure (Right Nothing)
    else do
      decoded <- eitherDecodeFileStrict' (checkpointPath environment) `catch` (\exception -> pure (Left (show (exception :: IOException))))
      pure $ case decoded of
        Left problem -> Left (checkpointError (Text.pack problem))
        Right checkpoint
          | all envelopeIntegrityIsValid (checkpointCurrent checkpoint : checkpointBack checkpoint <> checkpointForward checkpoint) -> Right (Just checkpoint)
          | otherwise -> Left (checkpointError "one or more envelope integrity tokens are invalid")

checkpointError :: Text -> AppError
checkpointError detail =
  (appError PreconditionFailed "The pending presentation checkpoint is invalid.")
    { appErrorDetails = [detail]
    , appErrorRecovery = [RecoveryAction "discard-checkpoint" "Remove only the damaged presentation checkpoint and retry." Nothing]
    }

instance ToJSON PresentationCheckpoint where
  toJSON checkpoint =
    object
      [ "schema" .= ("little-ant/presentation-checkpoint@1" :: Text)
      , "current" .= checkpointCurrent checkpoint
      , "back_stack" .= checkpointBack checkpoint
      , "forward_stack" .= checkpointForward checkpoint
      ]

instance FromJSON PresentationCheckpoint where
  parseJSON = withObject "PresentationCheckpoint" $ \value -> do
    schema <- value .: "schema"
    if schema /= ("little-ant/presentation-checkpoint@1" :: Text)
      then fail "unsupported presentation checkpoint schema"
      else PresentationCheckpoint <$> value .: "current" <*> value .: "back_stack" <*> value .: "forward_stack"

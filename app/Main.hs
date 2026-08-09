module Main (main) where

import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Exception (IOException, bracket_, try)
import Control.Monad (when)
import Data.Aeson (encode, object, (.=))
import Data.ByteString qualified as StrictByteString
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Foldable (traverse_)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Id (parseUUIDv7, renderUUIDv7)
import LittleAnt.Model (actorProfile)
import LittleAnt.Profile qualified as Profile
import LittleAnt.Projection
import LittleAnt.REPL
import LittleAnt.Vault
import LittleAnt.Vault.Age (makePassphraseBytes)
import LittleAnt.Vault.Agent
import Options.Applicative
import System.Directory (doesDirectoryExist, doesPathExist)
import System.Environment (getExecutablePath)
import System.Exit (exitFailure)
import System.FilePath (takeDirectory)
import System.IO (Handle, hIsTerminalDevice, hSetEcho, stderr, stdin)
import System.Process

data Options = Options
  { optionProfile :: Maybe Text
  , optionDryRun :: Bool
  , optionJson :: Bool
  , optionSchemaMajor :: Int
  , optionView :: ViewDepth
  , optionCommand :: CliCommand
  }

data CliCommand
  = ReplCli
  | NextCli
  | DoneCli (Maybe Text)
  | ReturnToIdleCli (Maybe Text)
  | FinishCli Text
  | ListCli (Maybe Text)
  | SearchCli [Text]
  | HelpCli (Maybe Text)
  | FocusCli [Text]
  | FocusBlockerCli [Text]
  | FeedCli [Text]
  | ShowCli [Text]
  | TranslateCli [Text]
  | OrderCli [Text]
  | ImpactCli [Text]
  | EffortCli [Text]
  | PhaseCli [Text]
  | PauseCli
  | BreakCli [Text]
  | ArchiveCli [Text]
  | RestoreCli [Text]
  | DomainFocusCli [Text]
  | TieBreakCli
  | UndoCli
  | RedoCli
  | GrammarCli
  | TickCli
  | NoticesCli
  | HistoryCli (Maybe Int)
  | ProfileListCli
  | ProfileShowCli (Maybe Text)
  | ProfileCreateCli Text
  | ProfileUseCli Text
  | ConfigShowCli
  | ConfigPathsCli
  | ConfigValidateCli
  | VaultAgentCli Int
  | VaultStatusCli
  | VaultCreateCli (Maybe FilePath) Bool
  | VaultUnlockCli
  | VaultLockCli
  | VaultInventoryCli
  | VaultAddCli Text Text
  | VaultRemoveCli Text Bool
  | VaultBackupCli FilePath
  | VaultRotateCli
  | VaultDiagnoseCli
  | UpdateCli Text (Maybe Text)
  | MergeCli Text Text
  | SupersedeCli Text Text
  | ImportCli Text Text Bool
  | MigrateCli Text Text Text
  | ExportCli Text (Maybe Text) (Maybe FilePath)
  | WebCli
  | PacksListCli
  | PacksShowCli Text
  | PacksInstallCli Text
  | PacksUpdatesCli
  | PacksUpdateCli Text
  | PacksRemoveCli Text
  | PacksRefreshCli
  | PacksTrustCli Text
  | PacksUntrustCli Text
  | PacksGcCli
  | DoctorCli
  | RepairCli
  | EditorCli

main :: IO ()
main = do
  options <- execParser parserInfo
  if optionSchemaMajor options /= 1
    then
      emitError (optionJson options) $
        (appError Unsupported "The requested result schema major is unsupported.")
          { appErrorDetails = ["Supported schema majors: 1"]
          }
    else
      productionAppEnv (optionProfile options) >>= \case
        Left problem -> emitError (optionJson options) problem
        Right environment -> run environment options

run :: AppEnv -> Options -> IO ()
run environment options = case optionCommand options of
  ReplCli
    | optionJson options || optionDryRun options -> execute environment options NextCommand
    | otherwise -> runRepl environment
  NextCli -> execute environment options NextCommand
  DoneCli (Just target) -> requiredBrickCommand environment options "done" (DoneCommand . Just) [target]
  DoneCli Nothing -> execute environment options (DoneCommand Nothing)
  ReturnToIdleCli (Just target) -> requiredBrickCommand environment options "return-to-idle" (ReturnToIdleCommand . Just) [target]
  ReturnToIdleCli Nothing -> execute environment options (ReturnToIdleCommand Nothing)
  FinishCli target -> execute environment options (FinishCommand target)
  ListCli maybeList -> execute environment options (ListCommand maybeList)
  SearchCli query -> execute environment options (SearchCommand (Text.unwords query))
  HelpCli maybeTopic -> execute environment options (HelpCommand maybeTopic)
  FocusCli referenceWords -> requiredBrickCommand environment options "focus" FocusCommand referenceWords
  FocusBlockerCli referenceWords -> requiredBrickCommand environment options "focus-blocker" FocusBlockerCommand referenceWords
  FeedCli wordsInCommand -> do
    material <- if null wordsInCommand then readFeedMaterial else pure (Text.unwords wordsInCommand)
    execute environment options (FeedCommand "cli" material)
  ShowCli referenceWords
    | null referenceWords ->
        emitError (optionJson options) $
          (appError InvalidInput "Usage: lant show <reference>")
            { appErrorRecovery = [RecoveryAction "search" "Search for the Raw before showing it." Nothing]
            }
    | otherwise ->
        execute
          environment
          options
          (ShowRawCommand (Text.unwords referenceWords) (optionView options))
  TranslateCli targetWords -> execute environment options (TranslateCommand (nonEmptyWords targetWords))
  OrderCli referenceWords -> execute environment options (OrderCommand (nonEmptyWords referenceWords))
  ImpactCli referenceWords -> requiredBrickCommand environment options "impact" ImpactCommand referenceWords
  EffortCli referenceWords -> requiredBrickCommand environment options "effort" EffortCommand referenceWords
  PhaseCli referenceWords -> requiredBrickCommand environment options "phase" PhaseCommand referenceWords
  PauseCli -> execute environment options PauseCommand
  BreakCli referenceWords -> requiredBrickCommand environment options "break" BreakCommand referenceWords
  ArchiveCli referenceWords -> requiredBrickCommand environment options "archive" ArchiveCommand referenceWords
  RestoreCli referenceWords -> requiredBrickCommand environment options "restore" RestoreCommand referenceWords
  DomainFocusCli domainWords ->
    case nonEmptyWords domainWords of
      Nothing ->
        emitError (optionJson options) $
          (appError InvalidInput "Usage: lant domain focus <Domain>")
            { appErrorRecovery = [RecoveryAction "choose-domain" "Use an exact Domain name or complete path." Nothing]
            }
      Just reference -> execute environment options (DomainFocusCommand reference)
  TieBreakCli -> execute environment options TieBreakCommand
  UndoCli -> execute environment options UndoCommand
  RedoCli -> execute environment options RedoCommand
  GrammarCli -> execute environment options GrammarCommand
  TickCli -> execute environment options TickCommand
  NoticesCli -> execute environment options NoticesCommand
  HistoryCli limit -> execute environment options (HistoryCommand limit)
  ProfileListCli -> execute environment options ProfileListCommand
  ProfileShowCli name -> execute environment options (ProfileShowCommand name)
  ProfileCreateCli name -> execute environment options (ProfileCreateCommand name)
  ProfileUseCli name -> execute environment options (ProfileUseCommand name)
  ConfigShowCli -> execute environment options ConfigShowCommand
  ConfigPathsCli -> execute environment options ConfigPathsCommand
  ConfigValidateCli -> execute environment options ConfigValidateCommand
  VaultAgentCli idleSeconds -> runVaultAgentCli environment options idleSeconds
  VaultStatusCli -> runVaultStatus environment options
  VaultCreateCli backup declined -> runVaultCreate environment options backup declined
  VaultUnlockCli -> runVaultUnlock environment options
  VaultLockCli -> runVaultLock environment options
  VaultInventoryCli -> runVaultInventory environment options
  VaultAddCli scheme label -> runVaultAdd environment options scheme label
  VaultRemoveCli identity confirmed -> runVaultRemove environment options identity confirmed
  VaultBackupCli destination -> runVaultBackup environment options destination
  VaultRotateCli -> runVaultRotate environment options
  VaultDiagnoseCli -> runVaultDiagnose environment options
  UpdateCli reference section -> execute environment options (UpdateCommand reference section)
  MergeCli survivor absorbed -> execute environment options (MergeCommand survivor absorbed)
  SupersedeCli oldBrick newBrick -> execute environment options (SupersedeCommand oldBrick newBrick)
  ImportCli source mode eraseAfterImport ->
    execute environment options (ImportCommand source mode eraseAfterImport)
  MigrateCli sourcePath targetPath mode ->
    execute environment options (MigrateCommand sourcePath targetPath mode)
  ExportCli exporter scope outputPath ->
    execute environment options (ExportCommand exporter scope outputPath)
  WebCli -> execute environment options WebCommand
  PacksListCli -> execute environment options PacksListCommand
  PacksShowCli pack -> execute environment options (PacksShowCommand pack)
  PacksInstallCli pack -> execute environment options (PacksInstallCommand pack)
  PacksUpdatesCli -> execute environment options PacksUpdatesCommand
  PacksUpdateCli pack -> execute environment options (PacksUpdateCommand pack)
  PacksRemoveCli pack -> execute environment options (PacksRemoveCommand pack)
  PacksRefreshCli -> execute environment options PacksRefreshCommand
  PacksTrustCli pack -> execute environment options (PacksTrustCommand pack)
  PacksUntrustCli pack -> execute environment options (PacksUntrustCommand pack)
  PacksGcCli -> execute environment options PacksGcCommand
  DoctorCli -> execute environment options DoctorCommand
  RepairCli
    | optionJson options || optionDryRun options -> execute environment options RepairCommand
    | otherwise -> runReplWithCommand environment RepairCommand
  EditorCli -> execute environment options EditorCommand

runVaultAgentCli :: AppEnv -> Options -> Int -> IO ()
runVaultAgentCli environment options idleSeconds =
  withVaultPaths environment options $ \paths ->
    runVaultAgent (Profile.vaultSocket paths) (Profile.vaultFile paths) idleSeconds >>= \case
      Left problem -> emitError (optionJson options) problem
      Right () -> pure ()

runVaultStatus :: AppEnv -> Options -> IO ()
runVaultStatus environment options =
  withVaultPaths environment options $ \paths -> do
    exists <- doesPathExist (Profile.vaultSocket paths)
    unlocked <-
      if not exists
        then pure False
        else
          sendVaultAgentRequest (Profile.vaultSocket paths) agentStatusRequest >>= \case
            Left _ -> pure False
            Right reply -> pure (fromMaybe False (agentReplyUnlocked reply))
    emitVaultFacts options "vault_status" (Map.singleton "status" (if unlocked then "unlocked" else "locked"))

runVaultCreate :: AppEnv -> Options -> Maybe FilePath -> Bool -> IO ()
runVaultCreate environment options backup explicitlyDeclined =
  withVaultPaths environment options $ \paths -> do
    let target = Profile.vaultFile paths
    exists <- doesPathExist target
    if exists
      then emitError (optionJson options) (appError Conflict "This profile already has an encrypted vault.")
      else case (backup, explicitlyDeclined) of
        (Nothing, False) ->
          emitError (optionJson options) $
            (appError InvalidInput "Choose --backup FILE or explicitly pass --without-backup.")
              { appErrorRecovery = [RecoveryAction "choose-recovery" "Create an encrypted backup unless you intentionally decline it." Nothing]
              }
        (Just _, True) -> emitError (optionJson options) (appError InvalidInput "Choose either --backup or --without-backup, not both.")
        _ -> do
          traverse_ (validateNewBackupPath options) backup
          if optionDryRun options
            then emitVaultFacts options "vault_create_preview" (Map.fromList ([("vault", Text.pack target)] <> maybe [] (pure . ("backup",) . Text.pack) backup))
            else do
              first <- readSecretBytes options "Create vault passphrase: "
              second <- readSecretBytes options "Confirm vault passphrase: "
              bracket_
                (pure ())
                (wipeAgentSecret first >> wipeAgentSecret second)
                ( if first /= second
                    then emitError (optionJson options) (appError InvalidInput "The passphrase confirmation did not match.")
                    else case makePassphraseBytes first of
                      Left problem -> emitError (optionJson options) problem
                      Right passphrase -> do
                        identity <- appAllocateUUID environment
                        writeVault target passphrase (emptyVault identity) >>= \case
                          Left problem -> emitError (optionJson options) problem
                          Right () ->
                            case backup of
                              Nothing -> emitVaultFacts options "vault_create" (Map.singleton "vault" (Text.pack target))
                              Just destination ->
                                backupVault target destination >>= \case
                                  Left problem -> emitError (optionJson options) problem
                                  Right () ->
                                    emitVaultFacts options "vault_create" (Map.fromList [("vault", Text.pack target), ("backup", Text.pack destination)])
                )

runVaultUnlock :: AppEnv -> Options -> IO ()
runVaultUnlock environment options =
  withVaultPaths environment options $ \paths -> do
    exists <- doesPathExist (Profile.vaultFile paths)
    if not exists
      then emitError (optionJson options) (appError NotFound "This profile has no encrypted vault.")
      else
        if optionDryRun options
          then emitVaultFacts options "vault_unlock_preview" Map.empty
          else do
            ensureVaultAgent environment options paths
            passphrase <- readSecretBytes options "Unlock credentials: "
            sendVaultAgentRequest (Profile.vaultSocket paths) (agentUnlockRequest passphrase) >>= \case
              Left problem -> emitError (optionJson options) problem
              Right reply
                | agentReplySucceeded reply -> emitVaultFacts options "vault_unlock" (Map.singleton "status" "unlocked")
                | otherwise -> emitError (optionJson options) (appError ExternalFailure "The vault agent returned an unexpected unlock reply.")

runVaultLock :: AppEnv -> Options -> IO ()
runVaultLock environment options =
  withVaultPaths environment options $ \paths -> do
    exists <- doesPathExist (Profile.vaultSocket paths)
    if optionDryRun options
      then emitVaultFacts options "vault_lock_preview" Map.empty
      else
        if not exists
          then emitVaultFacts options "vault_lock" (Map.singleton "status" "locked")
          else
            sendVaultAgentRequest (Profile.vaultSocket paths) agentLockRequest >>= \case
              Left problem -> emitError (optionJson options) problem
              Right reply
                | agentReplySucceeded reply -> emitVaultFacts options "vault_lock" (Map.singleton "status" "locked")
                | otherwise -> emitError (optionJson options) (appError ExternalFailure "The vault agent returned an unexpected lock reply.")

runVaultInventory :: AppEnv -> Options -> IO ()
runVaultInventory environment options =
  withVaultPaths environment options $ \paths ->
    sendVaultAgentRequest (Profile.vaultSocket paths) agentInventoryRequest >>= \case
      Left problem -> emitError (optionJson options) problem
      Right reply -> case agentReplyInventory reply of
        Nothing -> emitError (optionJson options) (appError ExternalFailure "The vault agent returned an unexpected inventory reply.")
        Just inventory ->
          if optionJson options
            then
              LazyByteString.putStrLn . encode $
                object
                  [ "schema" .= ("little-ant/vault-result@1" :: Text)
                  , "action" .= ("vault_inventory" :: Text)
                  , "entries" .= inventory
                  ]
            else do
              Text.putStrLn "Credentials:"
              mapM_
                ( \entry ->
                    Text.putStrLn $
                      "- "
                        <> renderUUIDv7 (inventoryIdentity entry)
                        <> " · "
                        <> inventoryLabel entry
                        <> " · "
                        <> credentialSchemeName (inventoryScheme entry)
                        <> maybe "" (" · ••••" <>) (inventoryRedactedSuffix entry)
                )
                inventory

runVaultAdd :: AppEnv -> Options -> Text -> Text -> IO ()
runVaultAdd environment options schemeName label =
  case parseCredentialSchemeName schemeName of
    Left problem -> emitError (optionJson options) problem
    Right scheme ->
      withVaultPaths environment options $ \paths -> do
        if optionDryRun options
          then emitVaultFacts options "vault_add_preview" (Map.fromList [("scheme", schemeName), ("label", label)])
          else do
            ensureVaultAgent environment options paths
            identity <- appAllocateUUID environment
            secret <- readSecretBytes options "Credential: "
            sendVaultAgentRequest (Profile.vaultSocket paths) (agentPutRequest identity scheme label Map.empty secret) >>= \case
              Left problem -> emitError (optionJson options) problem
              Right reply
                | agentReplySucceeded reply ->
                    emitVaultFacts options "vault_add" (Map.fromList [("entry_id", renderUUIDv7 identity), ("scheme", schemeName), ("label", label)])
                | otherwise -> emitError (optionJson options) (appError ExternalFailure "The vault agent returned an unexpected mutation reply.")

runVaultRemove :: AppEnv -> Options -> Text -> Bool -> IO ()
runVaultRemove environment options suppliedIdentity confirmed =
  case parseUUIDv7 suppliedIdentity of
    Left _ -> emitError (optionJson options) (appError InvalidInput "Vault entry removal requires one exact UUID.")
    Right identity
      | not confirmed ->
          emitError (optionJson options) $
            (appError PermissionRequired "Vault entry removal requires --yes.")
              { appErrorRecovery = [RecoveryAction "confirm" "Review the redacted inventory, then confirm the exact UUID." Nothing]
              }
      | otherwise ->
          withVaultPaths environment options $ \paths ->
            if optionDryRun options
              then emitVaultFacts options "vault_remove_preview" (Map.singleton "entry_id" (renderUUIDv7 identity))
              else
                sendVaultAgentRequest (Profile.vaultSocket paths) (agentRemoveRequest identity) >>= \case
                  Left problem -> emitError (optionJson options) problem
                  Right reply
                    | agentReplySucceeded reply -> emitVaultFacts options "vault_remove" (Map.singleton "entry_id" (renderUUIDv7 identity))
                    | otherwise -> emitError (optionJson options) (appError ExternalFailure "The vault agent returned an unexpected mutation reply.")

runVaultBackup :: AppEnv -> Options -> FilePath -> IO ()
runVaultBackup environment options destination =
  withVaultPaths environment options $ \paths -> do
    validateNewBackupPath options destination
    if optionDryRun options
      then emitVaultFacts options "vault_backup_preview" (Map.singleton "backup" (Text.pack destination))
      else
        backupVault (Profile.vaultFile paths) destination >>= \case
          Left problem -> emitError (optionJson options) problem
          Right () -> emitVaultFacts options "vault_backup" (Map.singleton "backup" (Text.pack destination))

runVaultRotate :: AppEnv -> Options -> IO ()
runVaultRotate environment options =
  withVaultPaths environment options $ \paths -> do
    if optionDryRun options
      then emitVaultFacts options "vault_rotate_preview" Map.empty
      else do
        ensureVaultAgent environment options paths
        first <- readSecretBytes options "New vault passphrase: "
        second <- readSecretBytes options "Confirm new vault passphrase: "
        if first /= second
          then wipeAgentSecret first >> wipeAgentSecret second >> emitError (optionJson options) (appError InvalidInput "The passphrase confirmation did not match.")
          else
            sendVaultAgentRequest (Profile.vaultSocket paths) (agentRotateRequest first) >>= \case
              Left problem -> wipeAgentSecret second >> emitError (optionJson options) problem
              Right reply -> do
                wipeAgentSecret second
                if agentReplySucceeded reply
                  then emitVaultFacts options "vault_rotate" Map.empty
                  else emitError (optionJson options) (appError ExternalFailure "The vault agent returned an unexpected rotation reply.")

runVaultDiagnose :: AppEnv -> Options -> IO ()
runVaultDiagnose environment options =
  withVaultPaths environment options $ \paths ->
    diagnoseVault (Profile.vaultFile paths) >>= \case
      Left problem -> emitError (optionJson options) problem
      Right facts -> do
        agentExists <- doesPathExist (Profile.vaultSocket paths)
        emitVaultFacts options "vault_diagnose" (Map.fromList (fmap splitFact facts <> [("agent_socket", if agentExists then "present" else "absent")]))
 where
  splitFact fact =
    let (key, value) = Text.breakOn ":" fact
     in (key, Text.strip (Text.drop 1 value))

withVaultPaths :: AppEnv -> Options -> (Profile.ProfilePaths -> IO ()) -> IO ()
withVaultPaths environment options action = do
  roots <- Profile.resolveXdgRoots
  case Profile.profilePaths roots (actorProfile (appActor environment)) of
    Left problem -> emitError (optionJson options) problem
    Right paths -> action paths

ensureVaultAgent :: AppEnv -> Options -> Profile.ProfilePaths -> IO ()
ensureVaultAgent environment options paths = do
  let socketPath = Profile.vaultSocket paths
  exists <- doesPathExist socketPath
  if exists
    then
      sendVaultAgentRequest socketPath agentStatusRequest >>= \case
        Left problem -> emitError (optionJson options) problem
        Right _ -> pure ()
    else do
      executable <- getExecutablePath
      let profile = actorProfile (appActor environment)
          process =
            (proc executable ["--profile", Text.unpack profile, "--vault-agent-internal=900"])
              { std_in = NoStream
              , std_out = NoStream
              , std_err = NoStream
              , close_fds = True
              , new_session = True
              }
      started <- try (createProcess process) :: IO (Either IOException (Maybe Handle, Maybe Handle, Maybe Handle, ProcessHandle))
      case started of
        Left problem ->
          emitError (optionJson options) $
            (appError ExternalFailure "Could not start the private vault agent.")
              { appErrorDetails = [Text.pack (show problem)]
              }
        Right _ -> waitForAgent options socketPath 200

waitForAgent :: Options -> FilePath -> Int -> IO ()
waitForAgent options socketPath attempts
  | attempts <= 0 = emitError (optionJson options) (appError ExternalFailure "The private vault agent did not become ready.")
  | otherwise = do
      exists <- doesPathExist socketPath
      if not exists
        then threadDelay 10_000 >> waitForAgent options socketPath (attempts - 1)
        else
          sendVaultAgentRequest socketPath agentStatusRequest >>= \case
            Right _ -> pure ()
            Left _ -> threadDelay 10_000 >> waitForAgent options socketPath (attempts - 1)

validateNewBackupPath :: Options -> FilePath -> IO ()
validateNewBackupPath options destination = do
  parentExists <- doesDirectoryExist (takeDirectory destination)
  destinationExists <- doesPathExist destination
  if not parentExists
    then emitError (optionJson options) (appError NotFound "The backup parent directory does not exist.")
    else when destinationExists (emitError (optionJson options) (appError Conflict "The backup destination already exists."))

readSecretBytes :: Options -> Text -> IO StrictByteString.ByteString
readSecretBytes options prompt = do
  interactive <- hIsTerminalDevice stdin
  if not interactive
    then emitError (optionJson options) (appError PermissionRequired "Secret input requires an interactive terminal with echo disabled.")
    else do
      Text.hPutStr stderr prompt
      value <- bracket_ (hSetEcho stdin False) (hSetEcho stdin True) (StrictByteString.hGetLine stdin)
      Text.hPutStrLn stderr ""
      pure value

emitVaultFacts :: Options -> Text -> Map Text Text -> IO ()
emitVaultFacts options action facts
  | optionJson options =
      LazyByteString.putStrLn . encode $
        object $
          [ "schema" .= ("little-ant/vault-result@1" :: Text)
          , "action" .= action
          ]
            <> [("facts" .= facts) | not (Map.null facts)]
  | otherwise = do
      Text.putStrLn (vaultActionHeading action)
      mapM_ (\(key, value) -> Text.putStrLn (key <> ": " <> value)) (Map.toAscList facts)

vaultActionHeading :: Text -> Text
vaultActionHeading = \case
  "vault_status" -> "Vault status"
  "vault_create" -> "Encrypted vault created."
  "vault_create_preview" -> "Vault creation preview."
  "vault_unlock" -> "Credentials unlocked."
  "vault_unlock_preview" -> "Vault unlock preview."
  "vault_lock" -> "Credentials locked."
  "vault_lock_preview" -> "Vault lock preview."
  "vault_add" -> "Credential added."
  "vault_add_preview" -> "Credential addition preview."
  "vault_remove" -> "Credential removed."
  "vault_remove_preview" -> "Credential removal preview."
  "vault_backup" -> "Encrypted backup created."
  "vault_backup_preview" -> "Vault backup preview."
  "vault_rotate" -> "Vault passphrase rotated."
  "vault_rotate_preview" -> "Vault rotation preview."
  "vault_diagnose" -> "Vault diagnostics"
  other -> other

requiredBrickCommand :: AppEnv -> Options -> Text -> (Text -> AppCommand) -> [Text] -> IO ()
requiredBrickCommand environment options name constructor referenceWords =
  case nonEmptyWords referenceWords of
    Nothing ->
      emitError (optionJson options) $
        (appError InvalidInput ("Usage: lant " <> name <> " <Brick reference>"))
          { appErrorRecovery = [RecoveryAction "search" "Use # autocomplete or an exact Brick title." Nothing]
          }
    Just reference -> execute environment options (constructor reference)

nonEmptyWords :: [Text] -> Maybe Text
nonEmptyWords wordsInCommand =
  case Text.strip (Text.unwords wordsInCommand) of
    "" -> Nothing
    value -> Just value

execute :: AppEnv -> Options -> AppCommand -> IO ()
execute environment options command =
  runAppCommand environment (optionDryRun options) (const (pure ())) command >>= \case
    Left problem -> emitError (optionJson options) problem
    Right ExportResult{resultExportBytes = Just bytes, resultExportDestination = Nothing}
      | not (optionDryRun options) -> StrictByteString.putStr bytes
    Right result
      | optionJson options -> LazyByteString.putStrLn (encode result)
      | otherwise -> Text.putStrLn (renderCommandResult result)

readFeedMaterial :: IO Text
readFeedMaterial = do
  interactive <- hIsTerminalDevice stdin
  if interactive
    then do
      Text.putStrLn "Feed Little Ant"
      Text.putStrLn "Tip: prefer English for consistent titles and search."
      Text.putStr "› "
      Text.getLine
    else Text.getContents

emitError :: Bool -> AppError -> IO a
emitError asJson problem = do
  if asJson
    then LazyByteString.hPutStrLn stderr (encode problem)
    else Text.hPutStrLn stderr (renderError problem)
  exitFailure

parserInfo :: ParserInfo Options
parserInfo =
  info
    (helper <*> versionOption <*> optionsParser)
    ( fullDesc
        <> header "lant — Little Ant 1.0"
        <> progDesc "Turn raw material into one trustworthy opportunity to move forward."
    )

vaultParser :: Parser CliCommand
vaultParser =
  hsubparser
    ( command "status" (info (pure VaultStatusCli) (progDesc "Show whether this profile's credentials are locked"))
        <> command
          "create"
          ( info
              ( VaultCreateCli
                  <$> optional (strOption (long "backup" <> metavar "FILE" <> help "Exclusively create an encrypted ciphertext backup"))
                  <*> switch (long "without-backup" <> help "Explicitly decline the initial encrypted backup")
              )
              (progDesc "Create this profile's encrypted vault using no-echo input")
          )
        <> command "unlock" (info (pure VaultUnlockCli) (progDesc "Unlock credentials in the private profile agent"))
        <> command "lock" (info (pure VaultLockCli) (progDesc "Clear unlocked credentials from the profile agent"))
        <> command "inventory" (info (pure VaultInventoryCli) (progDesc "List only redacted credential metadata"))
        <> command
          "add"
          ( info
              ( VaultAddCli
                  <$> (Text.pack <$> strOption (long "scheme" <> metavar "SCHEME"))
                  <*> (Text.pack <$> strOption (long "label" <> metavar "LABEL"))
              )
              (progDesc "Add one credential using no-echo input")
          )
        <> command
          "remove"
          ( info
              ( VaultRemoveCli
                  <$> (Text.pack <$> strArgument (metavar "ENTRY_UUID"))
                  <*> switch (long "yes" <> help "Confirm permanent removal from the encrypted vault")
              )
              (progDesc "Remove one exact credential entry")
          )
        <> command
          "backup"
          ( info
              (VaultBackupCli <$> strArgument (metavar "DESTINATION"))
              (progDesc "Verify and exclusively copy the current encrypted ciphertext")
          )
        <> command "rotate" (info (pure VaultRotateCli) (progDesc "Replace the vault passphrase and verify the result"))
        <> command "diagnose" (info (pure VaultDiagnoseCli) (progDesc "Inspect redacted path, permissions, and age-format facts"))
    )

optionsParser :: Parser Options
optionsParser =
  Options
    <$> optional
      ( Text.pack
          <$> strOption
            (long "profile" <> metavar "NAME" <> help "Use one named, non-merging profile")
      )
    <*> switch (long "dry-run" <> help "Validate and calculate without recording anything")
    <*> switch (long "json" <> help "Return the sparse structured result")
    <*> option
      auto
      ( long "schema"
          <> metavar "MAJOR"
          <> value 1
          <> showDefault
          <> help "Request one supported structured-result schema major"
      )
    <*> option
      viewReader
      ( long "view"
          <> metavar "DEPTH"
          <> value SummaryView
          <> help "summary | operational | relationships | history | complete"
      )
    <*> (fromMaybe ReplCli <$> optional commandParser)

commandParser :: Parser CliCommand
commandParser =
  hsubparser
    ( command "next" (info (pure NextCli) (progDesc "Obtain or restore one useful opportunity"))
        <> command
          "done"
          ( info
              (DoneCli . fmap Text.pack <$> optional (strArgument (metavar "BRICK")))
              (progDesc "Mark one Brick as completed")
          )
        <> command
          "return-to-idle"
          ( info
              (ReturnToIdleCli . fmap Text.pack <$> optional (strArgument (metavar "BRICK")))
              (progDesc "Return focus to idle (current Brick by default)")
          )
        <> command
          "finish"
          ( info
              (FinishCli . Text.pack <$> strArgument (metavar "CHECKLIST"))
              (progDesc "Finish an active checklist run for the selected checklist")
          )
        <> command
          "list"
          ( info
              (ListCli . fmap Text.pack <$> optional (strArgument (metavar "LIST")))
              (progDesc "List structured data (importance | forecast)")
          )
        <> command
          "search"
          ( info
              (SearchCli . fmap Text.pack <$> some (strArgument (metavar "QUERY")))
              (progDesc "Search Bricks and Raw material by text or handle")
          )
        <> command
          "help"
          ( info
              (HelpCli . fmap Text.pack <$> optional (strArgument (metavar "TOPIC")))
              (progDesc "Show concise command help")
          )
        <> command
          "feed"
          ( info
              (FeedCli . fmap Text.pack <$> many (strArgument (metavar "TEXT")))
              (progDesc "Preserve one submission as Inbox Raw material")
          )
        <> command
          "show"
          ( info
              (ShowCli . fmap Text.pack <$> many (strArgument (metavar "REFERENCE")))
              (progDesc "Inspect one exact typed reference")
          )
        <> command
          "translate"
          ( info
              (TranslateCli . fmap Text.pack <$> many (strArgument (metavar "BRICK_OR_RAW")))
              (progDesc "Run the interruptible English-normalization review queue")
          )
        <> command
          "focus"
          ( info
              (FocusCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Ask ordinary Focus consent for one Brick")
          )
        <> command
          "focus-blocker"
          ( info
              (FocusBlockerCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Focus the executable endpoint of the visible blocker chain")
          )
        <> command
          "order"
          ( info
              (OrderCli . fmap Text.pack <$> many (strArgument (metavar "BRICK_OR_DOMAIN")))
              (progDesc "Review human importance within sibling groups")
          )
        <> command
          "impact"
          ( info
              (ImpactCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Classify the expected impact of one composition root")
          )
        <> command
          "effort"
          ( info
              (EffortCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Classify total effort for one Brick scope")
          )
        <> command
          "phase"
          ( info
              (PhaseCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Review the optional descriptive phase of one Brick")
          )
        <> command
          "update"
          ( info
              (UpdateCli . Text.pack <$> strArgument (metavar "REFERENCE") <*> optional (Text.pack <$> strArgument (metavar "SECTION")))
              (progDesc "Patch metadata or status of one Brick")
          )
        <> command
          "merge"
          ( info
              (MergeCli <$> (Text.pack <$> strArgument (metavar "SURVIVOR")) <*> (Text.pack <$> strArgument (metavar "ABSORBED")))
              (progDesc "Merge two Bricks keeping the survivor identity")
          )
        <> command
          "supersede"
          ( info
              (SupersedeCli <$> (Text.pack <$> strArgument (metavar "OLD")) <*> (Text.pack <$> strArgument (metavar "NEW")))
              (progDesc "Mark one Brick as superseded by another")
          )
        <> command
          "import"
          ( info
              ( ImportCli
                  . Text.pack
                  <$> strArgument (metavar "SOURCE")
                  <*> option
                    (strOptionMode ["snapshot", "synchronize", "migrate"])
                    ( long "mode"
                        <> metavar "snapshot|synchronize|migrate"
                        <> value "synchronize"
                        <> showDefault
                        <> help "Import execution mode"
                    )
                  <*> switch (long "erase-after-import" <> help "Delete imported entries from source as a migration aid")
              )
              (progDesc "Import external data into your Lant dataset")
          )
        <> command
          "migrate"
          ( info
              ( MigrateCli
                  <$> (Text.pack <$> strArgument (metavar "SOURCE"))
                  <*> (Text.pack <$> strArgument (metavar "TARGET"))
                  <*> option
                    (strOptionMode ["inspect", "build", "cutover"])
                    ( long "mode"
                        <> metavar "inspect|build|cutover"
                        <> value "inspect"
                        <> showDefault
                        <> help "Migration strategy"
                    )
              )
              (progDesc "Migrate state between formats or adapters")
          )
        <> command
          "export"
          ( info
              ( ExportCli
                  . Text.pack
                  <$> strArgument (metavar "EXPORTER")
                  <*> optional
                    ( Text.pack
                        <$> strOption
                          ( long "scope"
                              <> metavar "REFERENCE"
                              <> help "Narrow the projection to one Brick or Domain"
                          )
                    )
                  <*> optional
                    ( strOption
                        ( long "output"
                            <> metavar "FILE"
                            <> help "Exclusively create one new output file"
                        )
                    )
              )
              (progDesc "Run one installed read-only exporter")
          )
        <> command "web" (info (pure WebCli) (progDesc "Start or inspect the web service mode"))
        <> command
          "packs"
          ( info
              (packParser <|> pure PacksListCli)
              (progDesc "Manage packs (extensions, adapters, templates)")
          )
        <> command "doctor" (info (pure DoctorCli) (progDesc "Run a dataset consistency diagnostic"))
        <> command "repair" (info (pure RepairCli) (progDesc "Apply safe deterministic repair recipes"))
        <> command "editor" (info (pure EditorCli) (progDesc "Open a $EDITOR-assisted raw editing workflow"))
        <> command "pause" (info (pure PauseCli) (progDesc "Clear current focus while retaining WIP"))
        <> command
          "break"
          ( info
              (BreakCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Break one Brick into independently tracked child Bricks")
          )
        <> command
          "archive"
          ( info
              (ArchiveCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Stop pursuing Work without claiming completion")
          )
        <> command
          "restore"
          ( info
              (RestoreCli . fmap Text.pack <$> many (strArgument (metavar "BRICK")))
              (progDesc "Restore archived Work as the same Brick")
          )
        <> command
          "domain"
          ( info
              ( hsubparser
                  ( command
                      "focus"
                      ( info
                          (DomainFocusCli . fmap Text.pack <$> many (strArgument (metavar "DOMAIN")))
                          (progDesc "Choose one suggestion, stay within, or prefer a Domain")
                      )
                  )
              )
              (progDesc "Manage the Domain forest")
          )
        <> command "tie-break" (info (pure TieBreakCli) (progDesc "Choose a deterministic provisional direction for the pending importance comparison"))
        <> command "undo" (info (pure UndoCli) (progDesc "Compensate the latest reversible command"))
        <> command "redo" (info (pure RedoCli) (progDesc "Reapply the currently redoable command"))
        <> command "grammar" (info (pure GrammarCli) (progDesc "Inspect the closed screen-grammar registry"))
        <> command "tick" (info (pure TickCli) (progDesc "Advance due recurrence and habit state explicitly"))
        <> command "notices" (info (pure NoticesCli) (progDesc "Inspect current, snoozed, and acknowledged temporal notices"))
        <> command
          "history"
          (info (HistoryCli <$> optional (argument auto (metavar "LIMIT" <> help "Show only the last N command records"))) (progDesc "List recent command history"))
        <> command
          "profile"
          (info profileParser (progDesc "List, inspect, create, or select one non-merging profile"))
        <> command
          "config"
          (info configParser (progDesc "Inspect or validate typed configuration"))
        <> command "vault" (info vaultParser (progDesc "Manage profile-scoped encrypted credentials"))
    )
    <|> (VaultAgentCli <$> option auto (long "vault-agent-internal" <> hidden <> internal))

strOptionMode :: [String] -> ReadM Text
strOptionMode options =
  eitherReader $ \value ->
    if value `elem` options
      then Right (Text.pack value)
      else Left $ "unsupported value " <> value <> ". Supported: " <> Text.unpack (Text.intercalate ", " (map Text.pack options))

packParser :: Parser CliCommand
packParser =
  hsubparser
    ( command "list" (info (pure PacksListCli) (progDesc "List known packs"))
        <> command "show" (info (PacksShowCli . Text.pack <$> strArgument (metavar "PACK")) (progDesc "Show pack metadata"))
        <> command "install" (info (PacksInstallCli . Text.pack <$> strArgument (metavar "PACK")) (progDesc "Install a pack"))
        <> command "updates" (info (pure PacksUpdatesCli) (progDesc "List available pack updates"))
        <> command "update" (info (PacksUpdateCli . Text.pack <$> strArgument (metavar "PACK")) (progDesc "Update one pack"))
        <> command "remove" (info (PacksRemoveCli . Text.pack <$> strArgument (metavar "PACK")) (progDesc "Remove an installed pack"))
        <> command "refresh" (info (pure PacksRefreshCli) (progDesc "Refresh local pack index"))
        <> command "trust" (info (PacksTrustCli . Text.pack <$> strArgument (metavar "PACK")) (progDesc "Trust a pack"))
        <> command "untrust" (info (PacksUntrustCli . Text.pack <$> strArgument (metavar "PACK")) (progDesc "Untrust a pack"))
        <> command "gc" (info (pure PacksGcCli) (progDesc "Collect and prune unused pack state"))
    )

profileParser :: Parser CliCommand
profileParser =
  hsubparser
    ( command "list" (info (pure ProfileListCli) (progDesc "List named profiles"))
        <> command
          "show"
          ( info
              (ProfileShowCli . fmap Text.pack <$> optional (strArgument (metavar "NAME")))
              (progDesc "Show one profile and its resolved paths")
          )
        <> command
          "create"
          ( info
              (ProfileCreateCli . Text.pack <$> strArgument (metavar "NAME"))
              (progDesc "Create one empty named profile without selecting it")
          )
        <> command
          "use"
          ( info
              (ProfileUseCli . Text.pack <$> strArgument (metavar "NAME"))
              (progDesc "Select one existing profile for future starts")
          )
    )

configParser :: Parser CliCommand
configParser =
  hsubparser
    ( command "show" (info (pure ConfigShowCli) (progDesc "Show sparse redacted typed configuration"))
        <> command "paths" (info (pure ConfigPathsCli) (progDesc "Show all resolved configuration paths"))
        <> command "validate" (info (pure ConfigValidateCli) (progDesc "Validate all typed configuration files"))
    )

viewReader :: ReadM ViewDepth
viewReader = eitherReader $ \case
  "summary" -> Right SummaryView
  "operational" -> Right OperationalView
  "relationships" -> Right RelationshipsView
  "history" -> Right HistoryView
  "complete" -> Right CompleteView
  value -> Left ("unknown projection depth: " <> value)

versionOption :: Parser (a -> a)
versionOption = infoOption "lant 1.0.0.0" (long "version" <> help "Show version")

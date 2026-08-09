module LittleAnt.Profile (
  XdgRoots (..),
  ProfilePaths (..),
  ProfileConfig (..),
  PreferencesConfig (..),
  CalibrationConfig (..),
  IntegrationsConfig (..),
  resolveXdgRoots,
  profilePaths,
  validProfileName,
  createProfile,
  listProfiles,
  loadProfile,
  writeIntegrationsConfig,
  readSelectedProfile,
  writeSelectedProfile,
)
where

import Control.Exception (IOException, bracketOnError, catch)
import Control.Monad (unless, when)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.ByteString qualified as ByteString
import Data.Char (isAsciiLower, isDigit)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Yaml qualified as Yaml
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Pack.Trust (PackArtifactIdentity (artifactName), PackPin (..), TrustedCommunityPublisher (..), validatePackPin, validateTrustedCommunityPublisher)
import LittleAnt.Store (StoreConfig (..), initializeDataset)
import System.Directory hiding (isSymbolicLink)
import System.Environment (lookupEnv)
import System.FilePath
import System.IO
import System.Posix.Files
import System.Posix.IO (FdOption (CloseOnExec), OpenMode (ReadOnly), closeFd, defaultFileFlags, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)

data XdgRoots = XdgRoots
  { xdgConfigRoot :: FilePath
  , xdgDataRoot :: FilePath
  , xdgStateRoot :: FilePath
  , xdgRuntimeRoot :: FilePath
  }
  deriving stock (Eq, Show)

data ProfilePaths = ProfilePaths
  { selectionPath :: FilePath
  , profileDirectory :: FilePath
  , profileFile :: FilePath
  , preferencesFile :: FilePath
  , calibrationFile :: FilePath
  , integrationsFile :: FilePath
  , vaultFile :: FilePath
  , packStoreDirectory :: FilePath
  , profileStateDirectory :: FilePath
  , datasetDirectory :: FilePath
  , vaultSocket :: FilePath
  }
  deriving stock (Eq, Show)

data ProfileConfig = ProfileConfig
  { configuredDataset :: FilePath
  , configuredPreferences :: FilePath
  , configuredCalibration :: FilePath
  , configuredIntegrations :: FilePath
  , configuredVaultName :: Text
  }
  deriving stock (Eq, Show)

data PreferencesConfig = PreferencesConfig
  { preferredPresentationLanguage :: Text
  , preferredColorMode :: Text
  , preferredEmojiMode :: Text
  , preferredEditorArgv :: [Text]
  , preferredPoweredUpArgv :: Maybe [Text]
  }
  deriving stock (Eq, Show)

newtype CalibrationConfig = CalibrationConfig
  { calibrationParameters :: Map Text Value
  }
  deriving stock (Eq, Show)

data IntegrationsConfig = IntegrationsConfig
  { installedComponents :: Map Text PackPin
  , providerAccounts :: Map Text Text
  , credentialBindings :: Map Text Text
  , deliveryBindings :: Map Text Text
  , trustedPublishers :: Set.Set TrustedCommunityPublisher
  }
  deriving stock (Eq, Show)

resolveXdgRoots :: IO XdgRoots
resolveXdgRoots = do
  home <- getHomeDirectory
  config <- xdg "XDG_CONFIG_HOME" (home </> ".config")
  dataRoot <- xdg "XDG_DATA_HOME" (home </> ".local" </> "share")
  state <- xdg "XDG_STATE_HOME" (home </> ".local" </> "state")
  runtime <- xdg "XDG_RUNTIME_DIR" (state </> "lant" </> "runtime")
  pure (XdgRoots config dataRoot state runtime)
 where
  xdg variable fallback =
    lookupEnv variable >>= \case
      Just path | not (null path) && isAbsolute path -> pure (normalise path)
      _ -> pure fallback

validProfileName :: Text -> Bool
validProfileName name = case Text.uncons name of
  Nothing -> False
  Just (first, rest) ->
    Text.length name <= 32
      && isLowerDigit first
      && Text.all (\character -> isLowerDigit character || character == '-') rest
 where
  isLowerDigit character = isAsciiLower character || isDigit character

profilePaths :: XdgRoots -> Text -> Either AppError ProfilePaths
profilePaths roots name
  | not (validProfileName name) =
      Left
        (appError InvalidInput "A profile name must match [a-z0-9][a-z0-9-]{0,31}.")
          { appErrorSubject = Just name
          }
  | otherwise =
      let component = Text.unpack name
          configDirectory = xdgConfigRoot roots </> "lant" </> "profiles" </> component
          stateDirectory = xdgStateRoot roots </> "lant" </> "profiles" </> component
       in Right
            ProfilePaths
              { selectionPath = xdgConfigRoot roots </> "lant" </> "selection.yaml"
              , profileDirectory = configDirectory
              , profileFile = configDirectory </> "profile.yaml"
              , preferencesFile = configDirectory </> "preferences.yaml"
              , calibrationFile = configDirectory </> "calibration.yaml"
              , integrationsFile = configDirectory </> "integrations.yaml"
              , vaultFile = xdgDataRoot roots </> "lant" </> "vaults" </> component <.> "age"
              , packStoreDirectory = xdgDataRoot roots </> "lant" </> "packs" </> "sha256"
              , profileStateDirectory = stateDirectory
              , datasetDirectory = stateDirectory </> "dataset"
              , vaultSocket = xdgRuntimeRoot roots </> "lant" </> component </> "vault.sock"
              }

createProfile :: XdgRoots -> Text -> UUIDv7 -> IO (Either AppError ProfilePaths)
createProfile roots name nonce =
  case profilePaths roots name of
    Left problem -> pure (Left problem)
    Right paths -> handleProfileIO $ do
      ensureSafeParents roots paths
      exists <- doesPathExist (profileDirectory paths)
      when exists (ioError (userError "profile already exists"))
      stateExists <- doesPathExist (profileStateDirectory paths)
      when stateExists (ioError (userError "profile state already exists"))
      createDirectory (profileStateDirectory paths)
      setFileMode (profileStateDirectory paths) 0o700
      initializeDataset (StoreConfig (datasetDirectory paths) 2_000_000 20_000)
      let staging = takeDirectory (profileDirectory paths) </> ("." <> Text.unpack name <> ".tmp-" <> Text.unpack (Text.take 12 (renderUUIDv7 nonce)))
      bracketOnError
        (createStaging staging)
        (\temporary -> removePathForcibly temporary >> removePathForcibly (profileStateDirectory paths))
        ( \temporary -> do
            writeTypedYaml (temporary </> "profile.yaml") (profileValue paths name)
            writeTypedYaml (temporary </> "preferences.yaml") factoryPreferences
            writeTypedYaml (temporary </> "calibration.yaml") factoryCalibration
            writeTypedYaml (temporary </> "integrations.yaml") factoryIntegrations
            renameDirectory temporary (profileDirectory paths)
            syncDirectory (takeDirectory (profileDirectory paths))
            pure (Right paths)
        )
 where
  createStaging path = do
    exists <- doesPathExist path
    when exists (ioError (userError "profile staging path already exists"))
    createDirectory path
    setFileMode path 0o700
    pure path

listProfiles :: XdgRoots -> IO (Either AppError [Text])
listProfiles roots = handleProfileIO $ do
  let parent = xdgConfigRoot roots </> "lant" </> "profiles"
  exists <- doesDirectoryExist parent
  if not exists
    then pure (Right [])
    else do
      names <- listDirectory parent
      accepted <- traverse (inspect parent) names
      pure (Right (Set.toAscList (Set.fromList [name | Just name <- accepted])))
 where
  inspect parent component = do
    let name = Text.pack component
        path = parent </> component
    if not (validProfileName name)
      then pure Nothing
      else do
        status <- getSymbolicLinkStatus path
        pure (if isDirectory status && not (isSymbolicLink status) then Just name else Nothing)

loadProfile :: XdgRoots -> Text -> IO (Either AppError (ProfilePaths, ProfileConfig, PreferencesConfig, CalibrationConfig, IntegrationsConfig))
loadProfile roots name =
  case profilePaths roots name of
    Left problem -> pure (Left problem)
    Right paths -> handleProfileIO $ do
      profile <- Yaml.decodeFileEither (profileFile paths)
      preferences <- Yaml.decodeFileEither (preferencesFile paths)
      calibration <- Yaml.decodeFileEither (calibrationFile paths)
      integrations <- Yaml.decodeFileEither (integrationsFile paths)
      pure $ do
        decodedProfile <- yamlResult "profile.yaml" profile
        decodedPreferences <- yamlResult "preferences.yaml" preferences
        decodedCalibration <- yamlResult "calibration.yaml" calibration
        decodedIntegrations <- yamlResult "integrations.yaml" integrations
        validateProfileReferences paths decodedProfile
        Right (paths, decodedProfile, decodedPreferences, decodedCalibration, decodedIntegrations)

readSelectedProfile :: XdgRoots -> IO (Either AppError (Maybe Text))
readSelectedProfile roots = handleProfileIO $ do
  let path = xdgConfigRoot roots </> "lant" </> "selection.yaml"
  exists <- doesFileExist path
  if not exists
    then pure (Right Nothing)
    else do
      decoded <- Yaml.decodeFileEither path
      pure $ do
        Selection selected <- yamlResult "selection.yaml" decoded
        unless (validProfileName selected) (Left (appError CorruptData "The selected profile name is invalid."))
        Right (Just selected)

writeSelectedProfile :: XdgRoots -> Text -> IO (Either AppError ())
writeSelectedProfile roots name =
  case profilePaths roots name of
    Left problem -> pure (Left problem)
    Right paths -> handleProfileIO $ do
      exists <- doesDirectoryExist (profileDirectory paths)
      unless exists (ioError (userError "selected profile does not exist"))
      ensurePrivateDirectory (takeDirectory (selectionPath paths))
      atomicWrite (selectionPath paths) (Yaml.encode (Selection name))
      pure (Right ())

factoryPreferences :: PreferencesConfig
factoryPreferences = PreferencesConfig "en" "auto" "auto" [] Nothing

factoryCalibration :: CalibrationConfig
factoryCalibration = CalibrationConfig Map.empty

factoryIntegrations :: IntegrationsConfig
factoryIntegrations = IntegrationsConfig Map.empty Map.empty Map.empty Map.empty Set.empty

writeIntegrationsConfig :: ProfilePaths -> IntegrationsConfig -> IO (Either AppError ())
writeIntegrationsConfig paths integrations = case validateIntegrationsConfig integrations of
  Left problem -> pure (Left problem)
  Right () ->
    handleProfileIO $ do
      atomicWrite (integrationsFile paths) (Yaml.encode integrations)
      pure (Right ())

profileValue :: ProfilePaths -> Text -> ProfileConfig
profileValue paths name =
  ProfileConfig
    (datasetDirectory paths)
    (preferencesFile paths)
    (calibrationFile paths)
    (integrationsFile paths)
    name

newtype Selection = Selection Text

instance ToJSON Selection where
  toJSON (Selection name) = object ["schema" .= ("little-ant/profile-selection@1" :: Text), "selected_profile" .= name]

instance FromJSON Selection where
  parseJSON = withObject "ProfileSelection" $ \fields -> do
    rejectUnknown fields ["schema", "selected_profile"]
    requireSchema fields "little-ant/profile-selection@1"
    Selection <$> fields .: "selected_profile"

instance ToJSON ProfileConfig where
  toJSON config =
    object
      [ "schema" .= ("little-ant/profile@1" :: Text)
      , "dataset" .= configuredDataset config
      , "preferences" .= configuredPreferences config
      , "calibration" .= configuredCalibration config
      , "integrations" .= configuredIntegrations config
      , "vault" .= configuredVaultName config
      ]

instance FromJSON ProfileConfig where
  parseJSON = withObject "ProfileConfig" $ \fields -> do
    rejectUnknown fields ["schema", "dataset", "preferences", "calibration", "integrations", "vault"]
    requireSchema fields "little-ant/profile@1"
    ProfileConfig <$> fields .: "dataset" <*> fields .: "preferences" <*> fields .: "calibration" <*> fields .: "integrations" <*> fields .: "vault"

instance ToJSON PreferencesConfig where
  toJSON preferences =
    object $
      [ "schema" .= ("little-ant/preferences@1" :: Text)
      , "presentation_language" .= preferredPresentationLanguage preferences
      , "color_mode" .= preferredColorMode preferences
      , "emoji_mode" .= preferredEmojiMode preferences
      , "editor_argv" .= preferredEditorArgv preferences
      ]
        <> maybe [] (pure . ("powered_up_argv" .=)) (preferredPoweredUpArgv preferences)

instance FromJSON PreferencesConfig where
  parseJSON = withObject "PreferencesConfig" $ \fields -> do
    rejectUnknown fields ["schema", "presentation_language", "color_mode", "emoji_mode", "editor_argv", "powered_up_argv"]
    requireSchema fields "little-ant/preferences@1"
    PreferencesConfig <$> fields .: "presentation_language" <*> fields .: "color_mode" <*> fields .: "emoji_mode" <*> fields .: "editor_argv" <*> fields .:? "powered_up_argv"

instance ToJSON CalibrationConfig where
  toJSON calibration = object ["schema" .= ("little-ant/calibration@1" :: Text), "parameters" .= calibrationParameters calibration]

instance FromJSON CalibrationConfig where
  parseJSON = withObject "CalibrationConfig" $ \fields -> do
    rejectUnknown fields ["schema", "parameters"]
    requireSchema fields "little-ant/calibration@1"
    CalibrationConfig <$> fields .: "parameters"

instance ToJSON IntegrationsConfig where
  toJSON integrations =
    object
      [ "schema" .= ("little-ant/integrations@1" :: Text)
      , "installed_components" .= installedComponents integrations
      , "provider_accounts" .= providerAccounts integrations
      , "credential_bindings" .= credentialBindings integrations
      , "delivery_bindings" .= deliveryBindings integrations
      , "trusted_publishers" .= trustedPublishers integrations
      ]

instance FromJSON IntegrationsConfig where
  parseJSON = withObject "IntegrationsConfig" $ \fields -> do
    rejectUnknown fields ["schema", "installed_components", "provider_accounts", "credential_bindings", "delivery_bindings", "trusted_publishers"]
    requireSchema fields "little-ant/integrations@1"
    integrations <-
      IntegrationsConfig
        <$> fields .: "installed_components"
        <*> fields .: "provider_accounts"
        <*> fields .: "credential_bindings"
        <*> fields .: "delivery_bindings"
        <*> (Set.fromList <$> fields .: "trusted_publishers")
    either (fail . Text.unpack . appErrorMessage) (const (pure integrations)) (validateIntegrationsConfig integrations)

validateIntegrationsConfig :: IntegrationsConfig -> Either AppError ()
validateIntegrationsConfig integrations = do
  mapM_ validatePackPin (installedComponents integrations)
  mapM_ validateTrustedCommunityPublisher (trustedPublishers integrations)
  unless
    (all (\(name, pin) -> name == artifactName (pinArtifact pin)) (Map.toList (installedComponents integrations)))
    (Left (appError CorruptData "An installed Pack map key must equal its signed Pack name."))

requireSchema :: Object -> Text -> Parser ()
requireSchema fields expected = do
  actual <- fields .: "schema"
  unless (actual == expected) (fail ("unsupported schema: " <> Text.unpack actual))

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (\key -> Set.notMember key accepted) (fmap Key.toText (KeyMap.keys fields))
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

validateProfileReferences :: ProfilePaths -> ProfileConfig -> Either AppError ()
validateProfileReferences paths profile =
  unless
    ( configuredDataset profile == datasetDirectory paths
        && configuredPreferences profile == preferencesFile paths
        && configuredCalibration profile == calibrationFile paths
        && configuredIntegrations profile == integrationsFile paths
        && configuredVaultName profile == Text.pack (takeBaseName (vaultFile paths))
    )
    (Left (appError CorruptData "Profile references do not match its resolved non-merging paths."))

yamlResult :: Text -> Either Yaml.ParseException value -> Either AppError value
yamlResult filename =
  either
    ( \problem ->
        Left
          (appError CorruptData ("The typed configuration file " <> filename <> " is invalid."))
            { appErrorDetails = [Text.pack (Yaml.prettyPrintParseException problem)]
            }
    )
    Right

writeTypedYaml :: (ToJSON value) => FilePath -> value -> IO ()
writeTypedYaml path value = do
  ByteString.writeFile path (Yaml.encode value)
  setFileMode path 0o600

atomicWrite :: FilePath -> ByteString.ByteString -> IO ()
atomicWrite path bytes = do
  let directory = takeDirectory path
  bracketOnError
    (openBinaryTempFile directory ".lant-config.tmp")
    (\(temporary, handle) -> catch (hClose handle) ignoreIOException >> removeIfPresent temporary)
    ( \(temporary, handle) -> do
        setFileMode temporary 0o600
        ByteString.hPut handle bytes
        hFlush handle
        descriptor <- handleToFd handle
        setFdOption descriptor CloseOnExec True
        fileSynchronise descriptor
        closeFd descriptor
        renameFile temporary path
        setFileMode path 0o600
        syncDirectory directory
    )

ensureSafeParents :: XdgRoots -> ProfilePaths -> IO ()
ensureSafeParents roots paths = do
  let parents =
        [ xdgConfigRoot roots </> "lant"
        , takeDirectory (profileDirectory paths)
        , xdgDataRoot roots </> "lant"
        , takeDirectory (vaultFile paths)
        , xdgStateRoot roots </> "lant"
        , takeDirectory (profileStateDirectory paths)
        , xdgRuntimeRoot roots </> "lant"
        ]
  mapM_ ensurePrivateDirectory parents

ensurePrivateDirectory :: FilePath -> IO ()
ensurePrivateDirectory path = do
  exists <- doesPathExist path
  if exists
    then do
      status <- getSymbolicLinkStatus path
      when (isSymbolicLink status || not (isDirectory status)) (ioError (userError "configuration parent is not a regular directory"))
    else createDirectoryIfMissing True path
  setFileMode path 0o700

syncDirectory :: FilePath -> IO ()
syncDirectory path = do
  descriptor <- openFd path ReadOnly defaultFileFlags
  fileSynchronise descriptor
  closeFd descriptor

removeIfPresent :: FilePath -> IO ()
removeIfPresent path = do
  exists <- doesFileExist path
  when exists (removeFile path)

handleProfileIO :: IO (Either AppError value) -> IO (Either AppError value)
handleProfileIO action = catch action $ \problem ->
  pure . Left $
    (appError ExternalFailure "Little Ant could not access the named profile safely.")
      { appErrorDetails = [Text.pack (show (problem :: IOException))]
      , appErrorRetrySafety = DoNotRetry
      , appErrorRecovery = [RecoveryAction "paths" "Inspect resolved profile paths and permissions." (Just "lant config paths")]
      }

ignoreIOException :: IOException -> IO ()
ignoreIOException _ = pure ()

module LittleAnt.Profile (
  XdgRoots (..),
  ProfilePaths (..),
  ProfileConfig (..),
  PreferencesConfig (..),
  CalibrationConfig (..),
  ProviderAccount (..),
  CredentialBinding (..),
  IntegrationsConfig (..),
  resolveXdgRoots,
  profilePaths,
  validProfileName,
  validIntegrationName,
  validateIntegrationsConfig,
  createProfile,
  listProfiles,
  loadProfile,
  integrationsConfigRevision,
  writeIntegrationsConfig,
  writeIntegrationsConfigIfRevision,
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
import LittleAnt.Store (StoreConfig (..), initializeDataset, sha256Hex)
import LittleAnt.Vault (CredentialScheme (..), credentialSchemeName, parseCredentialSchemeName)
import System.Directory hiding (isSymbolicLink)
import System.Environment (lookupEnv)
import System.FileLock (SharedExclusive (Exclusive), withFileLock)
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
  , officialCatalogStateFile :: FilePath
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

data ProviderAccount = ProviderAccount
  { providerAccountComponent :: Text
  , providerAccountProvider :: Text
  , providerAccountExternalId :: Text
  , providerAccountLabel :: Text
  , providerAccountConfiguration :: Value
  }
  deriving stock (Eq, Show)

data CredentialBinding = CredentialBinding
  { credentialBindingComponent :: Text
  , credentialBindingSlot :: Text
  , credentialBindingAccount :: Text
  , credentialBindingScheme :: CredentialScheme
  , credentialBindingVaultEntry :: UUIDv7
  , credentialBindingAuthorizationFingerprint :: Maybe Text
  , credentialBindingPurposes :: Set.Set Text
  }
  deriving stock (Eq, Show)

data IntegrationsConfig = IntegrationsConfig
  { installedComponents :: Map Text PackPin
  , providerAccounts :: Map Text ProviderAccount
  , credentialBindings :: Map Text CredentialBinding
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
              , officialCatalogStateFile = stateDirectory </> "official-pack-catalog.json"
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

integrationsConfigRevision :: ProfilePaths -> IO (Either AppError Text)
integrationsConfigRevision paths =
  handleProfileIO $ do
    bytes <- ByteString.readFile (integrationsFile paths)
    pure (Right (sha256Hex bytes))

writeIntegrationsConfigIfRevision :: ProfilePaths -> Text -> IntegrationsConfig -> IO (Either AppError Bool)
writeIntegrationsConfigIfRevision paths expectedRevision integrations = case validateIntegrationsConfig integrations of
  Left problem -> pure (Left problem)
  Right () ->
    handleProfileIO $ do
      let lockPath = integrationsFile paths <> ".lock"
      withFileLock lockPath Exclusive $ \_ -> do
        setFileMode lockPath 0o600
        current <- ByteString.readFile (integrationsFile paths)
        if sha256Hex current /= expectedRevision
          then pure (Right False)
          else atomicWrite (integrationsFile paths) (Yaml.encode integrations) >> pure (Right True)

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

instance ToJSON ProviderAccount where
  toJSON account =
    object
      [ "component" .= providerAccountComponent account
      , "provider" .= providerAccountProvider account
      , "external_id" .= providerAccountExternalId account
      , "label" .= providerAccountLabel account
      , "configuration" .= providerAccountConfiguration account
      ]

instance FromJSON ProviderAccount where
  parseJSON = withObject "ProviderAccount" $ \fields -> do
    rejectUnknown fields ["component", "provider", "external_id", "label", "configuration"]
    ProviderAccount
      <$> fields .: "component"
      <*> fields .: "provider"
      <*> fields .: "external_id"
      <*> fields .: "label"
      <*> fields .: "configuration"

instance ToJSON CredentialBinding where
  toJSON binding =
    object $
      [ "component" .= credentialBindingComponent binding
      , "slot" .= credentialBindingSlot binding
      , "account" .= credentialBindingAccount binding
      , "scheme" .= credentialSchemeName (credentialBindingScheme binding)
      , "vault_entry" .= renderUUIDv7 (credentialBindingVaultEntry binding)
      , "purposes" .= Set.toAscList (credentialBindingPurposes binding)
      ]
        <> maybe [] (pure . ("authorization_fingerprint" .=)) (credentialBindingAuthorizationFingerprint binding)

instance FromJSON CredentialBinding where
  parseJSON = withObject "CredentialBinding" $ \fields -> do
    rejectUnknown fields ["component", "slot", "account", "scheme", "vault_entry", "authorization_fingerprint", "purposes"]
    scheme <- fields .: "scheme" >>= either (fail . Text.unpack . appErrorMessage) pure . parseCredentialSchemeName
    vaultEntry <- fields .: "vault_entry" >>= either (fail . Text.unpack) pure . parseUUIDv7
    CredentialBinding
      <$> fields .: "component"
      <*> fields .: "slot"
      <*> fields .: "account"
      <*> pure scheme
      <*> pure vaultEntry
      <*> fields .:? "authorization_fingerprint"
      <*> (Set.fromList <$> fields .: "purposes")

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
  mapM_ (uncurry validateProviderAccount) (Map.toList (providerAccounts integrations))
  let enabledComponents = Set.unions (pinEnabledComponents <$> Map.elems (installedComponents integrations))
  mapM_
    ( \(name, account) ->
        unless
          (providerAccountComponent account `Set.member` enabledComponents)
          (invalid "A provider account must reference an enabled installed component." name)
    )
    (Map.toList (providerAccounts integrations))
  mapM_ (uncurry (validateCredentialBinding (providerAccounts integrations))) (Map.toList (credentialBindings integrations))
  let bindingCoordinates =
        [ (credentialBindingComponent binding, credentialBindingSlot binding, credentialBindingAccount binding)
        | binding <- Map.elems (credentialBindings integrations)
        ]
  unless
    (length bindingCoordinates == Set.size (Set.fromList bindingCoordinates))
    (Left (appError Conflict "Only one CredentialBinding may own one component, slot, and provider account."))

validateProviderAccount :: Text -> ProviderAccount -> Either AppError ()
validateProviderAccount name account = do
  unless (validIntegrationName name) (invalid "A provider-account name must be a lowercase local identifier." name)
  mapM_
    (\(label, value) -> unless (nonempty value) (invalid ("A provider account needs a nonempty " <> label <> ".") name))
    [ ("component", providerAccountComponent account)
    , ("provider", providerAccountProvider account)
    , ("external identity", providerAccountExternalId account)
    , ("label", providerAccountLabel account)
    ]
  case providerAccountConfiguration account of
    Object configuration -> rejectSensitiveConfiguration name configuration
    _ -> invalid "Provider-account configuration must be one JSON object." name
 where
  nonempty = not . Text.null . Text.strip

validateCredentialBinding :: Map Text ProviderAccount -> Text -> CredentialBinding -> Either AppError ()
validateCredentialBinding accounts name binding = do
  unless (validIntegrationName name) (invalid "A credential-binding name must be a lowercase local identifier." name)
  unless (nonempty (credentialBindingComponent binding)) (invalid "A CredentialBinding needs a component." name)
  unless (validIntegrationName (credentialBindingSlot binding)) (invalid "A CredentialBinding slot must be a lowercase local identifier." name)
  unless (not (Set.null purposes) && all nonempty (Set.toList purposes)) (invalid "A CredentialBinding needs nonempty supported purposes." name)
  case (credentialBindingScheme binding, credentialBindingAuthorizationFingerprint binding) of
    (OAuthAuthorizationCodePKCE, Just fingerprint) -> validateFingerprint fingerprint
    (OAuthDeviceAuthorization, Just fingerprint) -> validateFingerprint fingerprint
    (OAuthAuthorizationCodePKCE, Nothing) -> invalid "An OAuth CredentialBinding needs the exact signed authorization fingerprint." name
    (OAuthDeviceAuthorization, Nothing) -> invalid "An OAuth CredentialBinding needs the exact signed authorization fingerprint." name
    (_, Nothing) -> Right ()
    (_, Just _) -> invalid "A non-OAuth CredentialBinding cannot carry an authorization fingerprint." name
  account <-
    maybe
      (invalid "A CredentialBinding references an unknown provider account." (credentialBindingAccount binding))
      Right
      (Map.lookup (credentialBindingAccount binding) accounts)
  unless
    (providerAccountComponent account == credentialBindingComponent binding)
    (invalid "A CredentialBinding component must match its provider account component." name)
 where
  purposes = credentialBindingPurposes binding
  nonempty = not . Text.null . Text.strip
  validateFingerprint fingerprint =
    unless
      (Text.length fingerprint == 64 && Text.all (\character -> isDigit character || character >= 'a' && character <= 'f') fingerprint)
      (invalid "A CredentialBinding authorization fingerprint must be lowercase SHA-256." name)

rejectSensitiveConfiguration :: Text -> Object -> Either AppError ()
rejectSensitiveConfiguration accountName configuration =
  mapM_ inspect (KeyMap.toList configuration)
 where
  inspect (key, value)
    | sensitive (Key.toText key) = invalid "Provider-account configuration cannot contain secret-bearing keys." accountName
    | otherwise = case value of
        Object nested -> rejectSensitiveConfiguration accountName nested
        Array values -> mapM_ inspectValue values
        _ -> Right ()
  inspectValue = \case
    Object nested -> rejectSensitiveConfiguration accountName nested
    Array values -> mapM_ inspectValue values
    _ -> Right ()
  sensitive key =
    any (`Text.isInfixOf` Text.toLower key) ["secret", "token", "password", "authorization", "api_key", "private_key"]

validIntegrationName :: Text -> Bool
validIntegrationName name = case Text.uncons name of
  Nothing -> False
  Just (first, rest) ->
    Text.length name <= 64
      && isLowerDigit first
      && Text.all (\character -> isLowerDigit character || character `elem` ['-', '_']) rest
 where
  isLowerDigit character = isAsciiLower character || isDigit character

invalid :: Text -> Text -> Either AppError value
invalid message subject = Left (appError InvalidInput message){appErrorSubject = Just subject}

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

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

-- | Typed Little Ant Pack, sandbox, host-capability, and credential boundary.
--
-- Pack definitions and invocation evidence are canonical.  The credential
-- vault and the last validated runtime inputs are local deployment state and
-- are deliberately represented separately, so they cannot be serialized as
-- Pack content or replayed as domain events.
module LittleAnt.V1.Integration
  ( ComponentStatus (..)
  , CredentialBinding (..)
  , CredentialBindingStatus (..)
  , CredentialSlot (..)
  , HostHttpRecord (..)
  , HostHttpRequest (..)
  , IntegrationError (..)
  , LittleAntPack (..)
  , PackComponent (..)
  , PackComponentKind (..)
  , PackComponentManifest (..)
  , PackDeployment (..)
  , PackExecutionRequest (..)
  , PackExecutionResult (..)
  , PackInstallEvidence (..)
  , PackInstallManifest (..)
  , PackInstallation (..)
  , PackInvocation (..)
  , PackState (..)
  , PackStatus (..)
  , ProviderOutcome (..)
  , SandboxLimits (..)
  , SandboxReport (..)
  , VaultEntry (..)
  , VaultState (..)
  , authorizeCredential
  , bindCredential
  , credentialBindingProjection
  , declareCredentialSlot
  , defaultPackDeployment
  , defaultSandboxLimits
  , disablePack
  , emptyPackState
  , emptyVaultState
  , enablePack
  , executePackBoundary
  , findComponent
  , findPack
  , installPack
  , lockCredentialBinding
  , packContentProjection
  , packStateProjection
  , probePackSandbox
  , providerBackoff
  , recordPackInvocation
  , revokeCredentialBinding
  , revokePack
  , runLuaComponent
  , sandboxReportProjection
  , storeCredential
  , unlockCredentialBinding
  , validateHostHttpRequest
  , validatePackState
  , validateVaultState
  ) where

import Control.Exception (SomeException, try)
import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), Options (..), Result (..), ToJSON (toJSON), Value (..),
   camelTo2, defaultOptions, encode, fromJSON, genericParseJSON, genericToJSON,
   object, withObject, withText, (.:), (.=))
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.List (find, nub, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe, isJust, mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import GHC.Generics (Generic)
import qualified HsLua as Lua
import qualified HsLua.Aeson as LuaAeson
import System.Timeout (timeout)

------------------------------------------------------------
-- Public protocol and canonical Pack types
------------------------------------------------------------

data PackComponentKind
  = BrickBehaviorComponent
  | BrickTemplateComponent
  | ImportProfilePresetComponent
  | SourceAdapterComponent
  | EnricherComponent
  | ReadOnlyExporterComponent
  | UiAdapterComponent
  deriving stock (Eq, Ord, Show, Generic)

data PackStatus = PackInstalled | PackDisabled | PackRevoked
  deriving stock (Eq, Ord, Show, Generic)

data ComponentStatus = ComponentEnabled | ComponentDisabled | ComponentRevoked
  deriving stock (Eq, Ord, Show, Generic)

data CredentialBindingStatus
  = CredentialActive
  | CredentialLocked
  | CredentialRevoked
  deriving stock (Eq, Ord, Show, Generic)

data PackExecutionRequest = PackExecutionRequest
  { packExecutionRequestProtocolVersion :: Integer
  , packExecutionRequestComponentId :: Text
  , packExecutionRequestOperation :: Text
  , packExecutionRequestInput :: Value
  , packExecutionRequestCapabilityGrants :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data PackExecutionResult = PackExecutionResult
  { packExecutionResultProtocolVersion :: Integer
  , packExecutionResultOk :: Bool
  , packExecutionResultOutput :: Maybe Value
  , packExecutionResultErrorCode :: Maybe Text
  , packExecutionResultDiagnostics :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data PackComponentManifest = PackComponentManifest
  { packComponentManifestId :: Text
  , packComponentManifestVersion :: Integer
  , packComponentManifestKind :: PackComponentKind
  , packComponentManifestExecutable :: Bool
  , packComponentManifestCapabilities :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data PackInstallManifest = PackInstallManifest
  { packInstallManifestId :: Text
  , packInstallManifestVersion :: Integer
  , packInstallManifestPublisher :: Text
  , packInstallManifestContentHash :: Text
  , packInstallManifestComponents :: [PackComponentManifest]
  }
  deriving stock (Eq, Show, Generic)

data PackInstallEvidence = PackInstallEvidence
  { packInstallEvidenceVerifiedContentHash :: Text
  , packInstallEvidenceCompatibleProtocol :: Integer
  , packInstallEvidenceTrustedPublisher :: Bool
  }
  deriving stock (Eq, Show, Generic)

data LittleAntPack = LittleAntPack
  { littleAntPackId :: Text
  , littleAntPackVersion :: Integer
  , littleAntPackPublisher :: Text
  , littleAntPackContentHash :: Text
  , littleAntPackStatus :: PackStatus
  }
  deriving stock (Eq, Show, Generic)

data PackComponent = PackComponent
  { packComponentId :: Text
  , packComponentVersion :: Integer
  , packComponentPackId :: Text
  , packComponentPackVersion :: Integer
  , packComponentKind :: PackComponentKind
  , packComponentExecutable :: Bool
  , packComponentStatus :: ComponentStatus
  , packComponentCapabilities :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data PackInvocation = PackInvocation
  { packInvocationId :: Text
  , packInvocationComponent :: Text
  , packInvocationPackContentHash :: Text
  , packInvocationComponentVersion :: Integer
  , packInvocationOperation :: Text
  , packInvocationInputRevision :: Text
  , packInvocationRequestHash :: Text
  , packInvocationCapabilityGrants :: [Text]
  , packInvocationResult :: PackExecutionResult
  , packInvocationInvokedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data PackInstallation = PackInstallation
  { packInstallationId :: Text
  , packInstallationPack :: Text
  , packInstallationManifest :: PackInstallManifest
  , packInstallationInstalledAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data CredentialSlot = CredentialSlot
  { credentialSlotId :: Text
  , credentialSlotComponent :: Text
  , credentialSlotName :: Text
  , credentialSlotAuthenticationKind :: Text
  , credentialSlotRequired :: Bool
  }
  deriving stock (Eq, Show, Generic)

data VaultEntry = VaultEntry
  { vaultEntryId :: Text
  , vaultEntryLabel :: Text
  , vaultEntryEncryptedPayload :: Text
  , vaultEntryCreatedAt :: UTCTime
  , vaultEntryRotatedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

data CredentialBinding = CredentialBinding
  { credentialBindingId :: Text
  , credentialBindingSlot :: Text
  , credentialBindingAccount :: Text
  , credentialBindingVaultEntryId :: Text
  , credentialBindingStatus :: CredentialBindingStatus
  , credentialBindingCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data HostHttpRequest = HostHttpRequest
  { hostHttpRequestMethod :: Text
  , hostHttpRequestUrl :: Text
  , hostHttpRequestBodySize :: Integer
  , hostHttpRequestRedirectUrl :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data HostHttpRecord = HostHttpRecord
  { hostHttpRecordComponentId :: Text
  , hostHttpRecordAccount :: Text
  , hostHttpRecordMethod :: Text
  , hostHttpRecordUrl :: Text
  , hostHttpRecordCredentialInjected :: Bool
  }
  deriving stock (Eq, Show, Generic)

data PackState = PackState
  { packStatePacks :: Map Text LittleAntPack
  , packStateComponents :: Map Text PackComponent
  , packStateInstallations :: [PackInstallation]
  , packStateInvocations :: [PackInvocation]
  , packStateProviderBackoff :: Map Text Integer
  , packStateNextIdentity :: Integer
  }
  deriving stock (Eq, Show, Generic)

data VaultState = VaultState
  { vaultStateEntries :: Map Text VaultEntry
  , vaultStateSlots :: Map Text CredentialSlot
  , vaultStateBindings :: Map Text CredentialBinding
  , vaultStateUnlocked :: Bool
  , vaultStateNextIdentity :: Integer
  }
  deriving stock (Eq, Show, Generic)

-- | Local runtime/deployment state.  It is suitable for the kernel artifact
-- store, not for @v1.integration@ or a Pack archive.
data PackDeployment = PackDeployment
  { packDeploymentVault :: VaultState
  , packDeploymentRuntimeInputs :: Map Text Value
  , packDeploymentHttpTrace :: [HostHttpRecord]
  , packDeploymentExecutionCount :: Integer
  , packDeploymentDuringReplay :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data ProviderOutcome
  = ProviderSucceeded Value
  | ProviderFailed Text
  deriving stock (Eq, Show)

data SandboxLimits = SandboxLimits
  { sandboxLimitWallMicros :: Int
  , sandboxLimitInstructions :: Integer
  , sandboxLimitMemoryBytes :: Integer
  , sandboxLimitSourceBytes :: Int
  , sandboxLimitOutputBytes :: Int
  , sandboxLimitNestingDepth :: Int
  }
  deriving stock (Eq, Show)

data SandboxReport = SandboxReport
  { sandboxReportOs :: Bool
  , sandboxReportProcess :: Bool
  , sandboxReportFilesystem :: Bool
  , sandboxReportSocket :: Bool
  , sandboxReportDynamicLibrary :: Bool
  }
  deriving stock (Eq, Show, Generic)

data IntegrationError
  = InvalidPackManifest Text
  | PackArchiveNotVerified
  | PackManifestIncompatible
  | PackPublisherUntrusted
  | PackVersionAlreadyInstalled Text Integer
  | ComponentVersionAlreadyInstalled Text Integer
  | UnknownPack Text
  | UnknownComponent Text
  | InvalidPackStatus PackStatus
  | InvalidComponentStatus ComponentStatus
  | UndeclaredCapability Text
  | RawOperatingSystemCapability Text
  | InvalidPackResult Text
  | InvalidHostHttpRequest Text
  | RuntimeInputContainsSecret Text
  | UnknownCredentialSlot Text
  | UnknownVaultEntry Text
  | UnknownCredentialBinding Text
  | DuplicateLiveCredentialBinding Text Text
  | InvalidCredentialBindingStatus CredentialBindingStatus
  | VaultUnavailable
  | CredentialAccessLocked
  | CredentialAccessRevoked
  | CredentialAccessUnauthorized
  | ReplayExecutionForbidden
  deriving stock (Eq, Show)

------------------------------------------------------------
-- JSON instances
------------------------------------------------------------

instance ToJSON PackComponentKind where
  toJSON = String . packComponentKindText

instance FromJSON PackComponentKind where
  parseJSON = withText "PackComponentKind" $ \value ->
    maybe (fail "unknown PackComponentKind") pure
      (lookup value [(packComponentKindText kind, kind) | kind <- allComponentKinds])

instance ToJSON PackStatus where
  toJSON = String . \case
    PackInstalled -> "installed"
    PackDisabled -> "disabled"
    PackRevoked -> "revoked"

instance FromJSON PackStatus where
  parseJSON = enumParser "PackStatus"
    [("installed", PackInstalled), ("disabled", PackDisabled), ("revoked", PackRevoked)]

instance ToJSON ComponentStatus where
  toJSON = String . \case
    ComponentEnabled -> "enabled"
    ComponentDisabled -> "disabled"
    ComponentRevoked -> "revoked"

instance FromJSON ComponentStatus where
  parseJSON = enumParser "ComponentStatus"
    [ ("enabled", ComponentEnabled), ("disabled", ComponentDisabled)
    , ("revoked", ComponentRevoked)
    ]

instance ToJSON CredentialBindingStatus where
  toJSON = String . \case
    CredentialActive -> "active"
    CredentialLocked -> "locked"
    CredentialRevoked -> "revoked"

instance FromJSON CredentialBindingStatus where
  parseJSON = enumParser "CredentialBindingStatus"
    [ ("active", CredentialActive), ("locked", CredentialLocked)
    , ("revoked", CredentialRevoked)
    ]

instance ToJSON PackExecutionRequest where
  toJSON = genericToJSON (jsonOptions "packExecutionRequest")
instance FromJSON PackExecutionRequest where
  parseJSON = genericParseJSON (jsonOptions "packExecutionRequest")

instance ToJSON PackExecutionResult where
  toJSON = genericToJSON (jsonOptions "packExecutionResult")
instance FromJSON PackExecutionResult where
  parseJSON = genericParseJSON (jsonOptions "packExecutionResult")

instance ToJSON PackComponentManifest where
  toJSON = genericToJSON (jsonOptions "packComponentManifest")
  
instance FromJSON PackComponentManifest where
  parseJSON = withObject "PackComponentManifest" $ \fields -> do
    rejectUndeclaredFields "PackComponentManifest"
      ["id", "version", "kind", "executable", "capabilities"] fields
    PackComponentManifest
      <$> fields .: "id"
      <*> fields .: "version"
      <*> fields .: "kind"
      <*> fields .: "executable"
      <*> fields .: "capabilities"

instance ToJSON PackInstallManifest where
  toJSON = genericToJSON (jsonOptions "packInstallManifest")

instance FromJSON PackInstallManifest where
  parseJSON = withObject "PackInstallManifest" $ \fields -> do
    rejectUndeclaredFields "PackInstallManifest"
      ["id", "version", "publisher", "content_hash", "components"] fields
    PackInstallManifest
      <$> fields .: "id"
      <*> fields .: "version"
      <*> fields .: "publisher"
      <*> fields .: "content_hash"
      <*> fields .: "components"

instance ToJSON PackInstallEvidence where
  toJSON = genericToJSON (jsonOptions "packInstallEvidence")
instance FromJSON PackInstallEvidence where
  parseJSON = genericParseJSON (jsonOptions "packInstallEvidence")

instance ToJSON LittleAntPack where
  toJSON = genericToJSON (jsonOptions "littleAntPack")
instance FromJSON LittleAntPack where
  parseJSON = genericParseJSON (jsonOptions "littleAntPack")

instance ToJSON PackComponent where
  toJSON component = object
    [ "id" .= packComponentId component
    , "version" .= packComponentVersion component
    , "pack" .= object
        [ "id" .= packComponentPackId component
        , "version" .= packComponentPackVersion component
        ]
    , "kind" .= packComponentKind component
    , "executable" .= packComponentExecutable component
    , "status" .= packComponentStatus component
    , "capabilities" .= packComponentCapabilities component
    ]
instance FromJSON PackComponent where
  parseJSON = withObject "PackComponent" $ \fields -> do
    pack <- fields .: "pack"
    withObject "PackComponent.pack" (\packFields -> PackComponent
      <$> fields .: "id"
      <*> fields .: "version"
      <*> packFields .: "id"
      <*> packFields .: "version"
      <*> fields .: "kind"
      <*> fields .: "executable"
      <*> fields .: "status"
      <*> fields .: "capabilities") pack

instance ToJSON PackInvocation where
  toJSON = genericToJSON (jsonOptions "packInvocation")
instance FromJSON PackInvocation where
  parseJSON = genericParseJSON (jsonOptions "packInvocation")

instance ToJSON PackInstallation where
  toJSON = genericToJSON (jsonOptions "packInstallation")
instance FromJSON PackInstallation where
  parseJSON = genericParseJSON (jsonOptions "packInstallation")

instance ToJSON CredentialSlot where
  toJSON = genericToJSON (jsonOptions "credentialSlot")
instance FromJSON CredentialSlot where
  parseJSON = genericParseJSON (jsonOptions "credentialSlot")

instance ToJSON VaultEntry where
  toJSON = genericToJSON (jsonOptions "vaultEntry")
instance FromJSON VaultEntry where
  parseJSON = genericParseJSON (jsonOptions "vaultEntry")

instance ToJSON CredentialBinding where
  toJSON = genericToJSON (jsonOptions "credentialBinding")
instance FromJSON CredentialBinding where
  parseJSON = genericParseJSON (jsonOptions "credentialBinding")

instance ToJSON HostHttpRequest where
  toJSON = genericToJSON (jsonOptions "hostHttpRequest")
instance FromJSON HostHttpRequest where
  parseJSON = genericParseJSON (jsonOptions "hostHttpRequest")

instance ToJSON HostHttpRecord where
  toJSON = genericToJSON (jsonOptions "hostHttpRecord")
instance FromJSON HostHttpRecord where
  parseJSON = genericParseJSON (jsonOptions "hostHttpRecord")

instance ToJSON PackState where
  toJSON = genericToJSON (jsonOptions "packState")
instance FromJSON PackState where
  parseJSON = genericParseJSON (jsonOptions "packState")

instance ToJSON VaultState where
  toJSON = genericToJSON (jsonOptions "vaultState")
instance FromJSON VaultState where
  parseJSON = genericParseJSON (jsonOptions "vaultState")

instance ToJSON PackDeployment where
  toJSON = genericToJSON (jsonOptions "packDeployment")
instance FromJSON PackDeployment where
  parseJSON = genericParseJSON (jsonOptions "packDeployment")

instance ToJSON SandboxReport where
  toJSON = genericToJSON (jsonOptions "sandboxReport")
instance FromJSON SandboxReport where
  parseJSON = genericParseJSON (jsonOptions "sandboxReport")

jsonOptions :: String -> Options
jsonOptions prefix = defaultOptions
  { fieldLabelModifier = camelTo2 '_' . drop (length prefix)
  , omitNothingFields = False
  }

enumParser :: String -> [(Text, value)] -> Value -> AesonTypes.Parser value
enumParser label values = withText label $ \value ->
  maybe (fail ("unknown " <> label)) pure (lookup value values)

rejectUndeclaredFields :: String -> [Text] -> KeyMap.KeyMap Value -> AesonTypes.Parser ()
rejectUndeclaredFields label allowed fields =
  unless (Set.fromList (map Key.toText (KeyMap.keys fields))
      `Set.isSubsetOf` Set.fromList allowed)
    (fail (label <> " contains undeclared fields"))

------------------------------------------------------------
-- Canonical Pack lifecycle
------------------------------------------------------------

emptyPackState :: PackState
emptyPackState = PackState Map.empty Map.empty [] [] Map.empty 1

emptyVaultState :: VaultState
emptyVaultState = VaultState Map.empty Map.empty Map.empty True 1

defaultPackDeployment :: PackDeployment
defaultPackDeployment = PackDeployment emptyVaultState Map.empty [] 0 []

defaultSandboxLimits :: SandboxLimits
defaultSandboxLimits = SandboxLimits
  { sandboxLimitWallMicros = 500000
  , sandboxLimitInstructions = 100000
  , sandboxLimitMemoryBytes = 8 * 1024 * 1024
  , sandboxLimitSourceBytes = 65536
  , sandboxLimitOutputBytes = 1048576
  , sandboxLimitNestingDepth = 32
  }

installPack ::
  UTCTime -> PackInstallEvidence -> PackInstallManifest -> PackState ->
  Either IntegrationError (LittleAntPack, [PackComponent], PackState)
installPack now evidence manifest state = do
  validateInstallEvidence evidence manifest
  validateManifest manifest
  let key = packKey (packInstallManifestId manifest)
        (packInstallManifestVersion manifest)
  when (Map.member key (packStatePacks state))
    (Left (PackVersionAlreadyInstalled
      (packInstallManifestId manifest) (packInstallManifestVersion manifest)))
  mapM_ (rejectExistingComponent state) (packInstallManifestComponents manifest)
  let pack = LittleAntPack
        { littleAntPackId = packInstallManifestId manifest
        , littleAntPackVersion = packInstallManifestVersion manifest
        , littleAntPackPublisher = packInstallManifestPublisher manifest
        , littleAntPackContentHash = packInstallManifestContentHash manifest
        , littleAntPackStatus = PackInstalled
        }
      components = map (componentFromManifest pack)
        (packInstallManifestComponents manifest)
      installation = PackInstallation
        { packInstallationId = identity "pack-installation" state
        , packInstallationPack = key
        , packInstallationManifest = manifest
        , packInstallationInstalledAt = now
        }
      next = state
        { packStatePacks = Map.insert key pack (packStatePacks state)
        , packStateComponents = foldr
            (\component -> Map.insert (packComponentId component) component)
            (packStateComponents state)
            components
        , packStateInstallations = packStateInstallations state <> [installation]
        , packStateNextIdentity = packStateNextIdentity state + 1
        }
  validatePackState next
  pure (pack, components, next)

validateInstallEvidence ::
  PackInstallEvidence -> PackInstallManifest -> Either IntegrationError ()
validateInstallEvidence evidence manifest = do
  unless (packInstallEvidenceVerifiedContentHash evidence
      == packInstallManifestContentHash manifest)
    (Left PackArchiveNotVerified)
  unless (packInstallEvidenceCompatibleProtocol evidence == 1)
    (Left PackManifestIncompatible)
  unless (packInstallEvidenceTrustedPublisher evidence)
    (Left PackPublisherUntrusted)

validateManifest :: PackInstallManifest -> Either IntegrationError ()
validateManifest manifest = do
  requireNonempty "Pack id" (packInstallManifestId manifest)
  requirePositive "Pack version" (packInstallManifestVersion manifest)
  requireNonempty "Pack publisher" (packInstallManifestPublisher manifest)
  unless ("sha256:" `Text.isPrefixOf` packInstallManifestContentHash manifest)
    (Left (InvalidPackManifest "content_hash must be a sha256 identity"))
  when (null (packInstallManifestComponents manifest))
    (Left (InvalidPackManifest "a Pack must declare at least one component"))
  let componentIds = map packComponentManifestId
        (packInstallManifestComponents manifest)
  unless (length componentIds == length (nub componentIds))
    (Left (InvalidPackManifest "component identities must be unique"))
  mapM_ validateComponentManifest (packInstallManifestComponents manifest)

validateComponentManifest :: PackComponentManifest -> Either IntegrationError ()
validateComponentManifest component = do
  requireNonempty "component id" (packComponentManifestId component)
  requirePositive "component version" (packComponentManifestVersion component)
  let executable = packComponentManifestExecutable component
      kind = packComponentManifestKind component
  unless (executable == isExecutableKind kind)
    (Left (InvalidPackManifest
      "component executable flag does not match its closed typed kind"))
  let capabilities = packComponentManifestCapabilities component
  unless (length capabilities == length (nub capabilities))
    (Left (InvalidPackManifest "component capabilities must be unique"))
  when (not executable && not (null capabilities))
    (Left (InvalidPackManifest
      "declarative components cannot declare runtime capabilities"))
  mapM_ validateCapability capabilities

validateCapability :: Text -> Either IntegrationError ()
validateCapability capability
  | any (`Text.isInfixOf` lowered)
      ["raw-os", "filesystem", "process", "socket", "dynamic-library",
       "environment", "loadlib", "subprocess"] =
      Left (RawOperatingSystemCapability capability)
  | Just host <- Text.stripPrefix "http:" capability =
      if validCapabilitySuffix host && not (Text.any (`elem` ("/:" :: String)) host)
        then Right ()
        else Left (InvalidPackManifest "HTTP capability must name one exact host")
  | Just slot <- Text.stripPrefix "credential:" capability =
      if validCapabilitySuffix slot then Right ()
        else Left (InvalidPackManifest "credential capability has an empty slot")
  | Just effect <- Text.stripPrefix "effect:" capability =
      if validCapabilitySuffix effect then Right ()
        else Left (InvalidPackManifest "effect capability has an empty kind")
  | otherwise = Left (InvalidPackManifest
      ("unknown typed capability: " <> capability))
  where
    lowered = Text.toLower capability

validCapabilitySuffix :: Text -> Bool
validCapabilitySuffix value =
  not (Text.null (Text.strip value)) && Text.strip value == value

isExecutableKind :: PackComponentKind -> Bool
isExecutableKind = \case
  SourceAdapterComponent -> True
  EnricherComponent -> True
  ReadOnlyExporterComponent -> True
  UiAdapterComponent -> True
  BrickBehaviorComponent -> False
  BrickTemplateComponent -> False
  ImportProfilePresetComponent -> False

allComponentKinds :: [PackComponentKind]
allComponentKinds =
  [ BrickBehaviorComponent, BrickTemplateComponent, ImportProfilePresetComponent
  , SourceAdapterComponent, EnricherComponent, ReadOnlyExporterComponent
  , UiAdapterComponent
  ]

packComponentKindText :: PackComponentKind -> Text
packComponentKindText = \case
  BrickBehaviorComponent -> "brick_behavior"
  BrickTemplateComponent -> "brick_template"
  ImportProfilePresetComponent -> "import_profile_preset"
  SourceAdapterComponent -> "source_adapter"
  EnricherComponent -> "enricher"
  ReadOnlyExporterComponent -> "read_only_exporter"
  UiAdapterComponent -> "ui_adapter"

componentFromManifest :: LittleAntPack -> PackComponentManifest -> PackComponent
componentFromManifest pack manifest = PackComponent
  { packComponentId = packComponentManifestId manifest
  , packComponentVersion = packComponentManifestVersion manifest
  , packComponentPackId = littleAntPackId pack
  , packComponentPackVersion = littleAntPackVersion pack
  , packComponentKind = packComponentManifestKind manifest
  , packComponentExecutable = packComponentManifestExecutable manifest
  , packComponentStatus = ComponentEnabled
  , packComponentCapabilities = packComponentManifestCapabilities manifest
  }

rejectExistingComponent :: PackState -> PackComponentManifest -> Either IntegrationError ()
rejectExistingComponent state component = case
    Map.lookup (packComponentManifestId component) (packStateComponents state) of
  Nothing -> Right ()
  Just existing -> Left (ComponentVersionAlreadyInstalled
    (packComponentId existing) (packComponentVersion existing))

disablePack :: Text -> PackState -> Either IntegrationError PackState
disablePack identifier state = transitionPack identifier PackInstalled PackDisabled
  ComponentEnabled ComponentDisabled state

enablePack :: Text -> PackState -> Either IntegrationError PackState
enablePack identifier state = transitionPack identifier PackDisabled PackInstalled
  ComponentDisabled ComponentEnabled state

revokePack :: Text -> PackState -> Either IntegrationError PackState
revokePack identifier state = do
  pack <- findPack identifier state
  unless (littleAntPackStatus pack `elem` [PackInstalled, PackDisabled])
    (Left (InvalidPackStatus (littleAntPackStatus pack)))
  let key = packKey (littleAntPackId pack) (littleAntPackVersion pack)
      next = state
        { packStatePacks = Map.insert key
            (pack {littleAntPackStatus = PackRevoked}) (packStatePacks state)
        , packStateComponents = Map.map (\component ->
            if componentBelongsTo pack component
              then component {packComponentStatus = ComponentRevoked}
              else component) (packStateComponents state)
        }
  validatePackState next
  pure next

transitionPack ::
  Text -> PackStatus -> PackStatus -> ComponentStatus -> ComponentStatus ->
  PackState -> Either IntegrationError PackState
transitionPack identifier expected target expectedComponent targetComponent state = do
  pack <- findPack identifier state
  unless (littleAntPackStatus pack == expected)
    (Left (InvalidPackStatus (littleAntPackStatus pack)))
  let key = packKey (littleAntPackId pack) (littleAntPackVersion pack)
      next = state
        { packStatePacks = Map.insert key
            (pack {littleAntPackStatus = target}) (packStatePacks state)
        , packStateComponents = Map.map (\component ->
            if componentBelongsTo pack component
                && packComponentStatus component == expectedComponent
              then component {packComponentStatus = targetComponent}
              else component) (packStateComponents state)
        }
  validatePackState next
  pure next

findPack :: Text -> PackState -> Either IntegrationError LittleAntPack
findPack identifier state = case reverse (sortOn littleAntPackVersion
    [pack | pack <- Map.elems (packStatePacks state), littleAntPackId pack == identifier]) of
  pack : _ -> Right pack
  [] -> Left (UnknownPack identifier)

findComponent :: Text -> PackState -> Either IntegrationError PackComponent
findComponent identifier state = maybe (Left (UnknownComponent identifier)) Right
  (Map.lookup identifier (packStateComponents state))

recordPackInvocation ::
  UTCTime -> Text -> Text -> Text -> Text -> [Text] -> PackExecutionResult ->
  PackState -> Either IntegrationError (PackInvocation, PackState)
recordPackInvocation now componentId operation inputRevision requestHash grants result state = do
  component <- findComponent componentId state
  unless (packComponentStatus component == ComponentEnabled)
    (Left (InvalidComponentStatus (packComponentStatus component)))
  mapM_ (\grant -> unless (grant `elem` packComponentCapabilities component)
    (Left (UndeclaredCapability grant))) grants
  validateExecutionResult result
  pack <- findPack (packComponentPackId component) state
  let invocation = PackInvocation
        { packInvocationId = identity "pack-invocation" state
        , packInvocationComponent = componentId
        , packInvocationPackContentHash = littleAntPackContentHash pack
        , packInvocationComponentVersion = packComponentVersion component
        , packInvocationOperation = operation
        , packInvocationInputRevision = inputRevision
        , packInvocationRequestHash = requestHash
        , packInvocationCapabilityGrants = grants
        , packInvocationResult = result
        , packInvocationInvokedAt = now
        }
      next = state
        { packStateInvocations = packStateInvocations state <> [invocation]
        , packStateNextIdentity = packStateNextIdentity state + 1
        }
  validatePackState next
  pure (invocation, next)

validateExecutionResult :: PackExecutionResult -> Either IntegrationError ()
validateExecutionResult result = do
  unless (packExecutionResultProtocolVersion result == 1)
    (Left (InvalidPackResult "unsupported protocol version"))
  if packExecutionResultOk result
    then when (isJust (packExecutionResultErrorCode result))
      (Left (InvalidPackResult "successful result contains error_code"))
    else when (packExecutionResultErrorCode result == Nothing)
      (Left (InvalidPackResult "failed result omits error_code"))
  when (containsForbiddenSecret (toJSON result))
    (Left (InvalidPackResult "result or diagnostics contain credential material"))

validatePackState :: PackState -> Either IntegrationError ()
validatePackState state = do
  mapM_ (\component -> do
      pack <- findExactPack (packComponentPackId component)
        (packComponentPackVersion component) state
      unless (packComponentExecutable component == isExecutableKind
          (packComponentKind component))
        (Left (InvalidPackManifest "stored component violates typed execution kind"))
      when (not (packComponentExecutable component)
          && not (null (packComponentCapabilities component)))
        (Left (InvalidPackManifest "stored declarative component has capabilities"))
      case littleAntPackStatus pack of
        PackRevoked -> unless (packComponentStatus component == ComponentRevoked)
          (Left (InvalidComponentStatus (packComponentStatus component)))
        PackDisabled -> unless (packComponentStatus component
            `elem` [ComponentDisabled, ComponentRevoked])
          (Left (InvalidComponentStatus (packComponentStatus component)))
        PackInstalled -> pure ())
    (Map.elems (packStateComponents state))
  mapM_ (validateExecutionResult . packInvocationResult)
    (packStateInvocations state)
  unless (all invocationReferencesPinnedComponent (packStateInvocations state))
    (Left (InvalidPackResult "invocation references uninstalled component version"))
  where
    invocationReferencesPinnedComponent invocation = case
        Map.lookup (packInvocationComponent invocation) (packStateComponents state) of
      Nothing -> False
      Just component -> packComponentVersion component
        == packInvocationComponentVersion invocation

findExactPack :: Text -> Integer -> PackState -> Either IntegrationError LittleAntPack
findExactPack identifier version state = maybe (Left (UnknownPack identifier)) Right
  (Map.lookup (packKey identifier version) (packStatePacks state))

------------------------------------------------------------
-- Local vault and bindings
------------------------------------------------------------

storeCredential ::
  UTCTime -> Text -> Text -> VaultState ->
  Either IntegrationError (VaultEntry, VaultState)
storeCredential now label encryptedPayload vault = do
  requireNonempty "credential label" label
  requireNonempty "encrypted credential payload" encryptedPayload
  let identifier = vaultIdentity "vault-entry" vault
      entry = VaultEntry identifier label encryptedPayload now Nothing
      next = vault
        { vaultStateEntries = Map.insert identifier entry (vaultStateEntries vault)
        , vaultStateNextIdentity = vaultStateNextIdentity vault + 1
        }
  validateVaultState next
  pure (entry, next)

declareCredentialSlot ::
  Text -> Text -> Text -> Bool -> VaultState ->
  Either IntegrationError (CredentialSlot, VaultState)
declareCredentialSlot component name authenticationKind required vault = do
  requireNonempty "credential component" component
  requireNonempty "credential slot" name
  unless (authenticationKind `elem`
      ["oauth2_pkce", "oauth2_device", "bearer", "api_key", "none"])
    (Left (InvalidPackManifest "unsupported credential authentication kind"))
  let existing = find (\slot -> credentialSlotComponent slot == component
        && credentialSlotName slot == name) (Map.elems (vaultStateSlots vault))
  case existing of
    Just slot -> Right (slot, vault)
    Nothing -> do
      let identifier = vaultIdentity "credential-slot" vault
          slot = CredentialSlot identifier component name authenticationKind required
          next = vault
            { vaultStateSlots = Map.insert identifier slot (vaultStateSlots vault)
            , vaultStateNextIdentity = vaultStateNextIdentity vault + 1
            }
      validateVaultState next
      pure (slot, next)

bindCredential ::
  UTCTime -> Text -> Text -> Text -> VaultState ->
  Either IntegrationError (CredentialBinding, VaultState)
bindCredential now slotId account vaultEntryId vault = do
  _ <- maybe (Left (UnknownCredentialSlot slotId)) Right
    (Map.lookup slotId (vaultStateSlots vault))
  _ <- maybe (Left (UnknownVaultEntry vaultEntryId)) Right
    (Map.lookup vaultEntryId (vaultStateEntries vault))
  requireNonempty "credential account" account
  when (any (isLiveBindingFor slotId account) (Map.elems (vaultStateBindings vault)))
    (Left (DuplicateLiveCredentialBinding slotId account))
  let identifier = vaultIdentity "credential-binding" vault
      binding = CredentialBinding identifier slotId account vaultEntryId
        CredentialActive now
      next = vault
        { vaultStateBindings = Map.insert identifier binding
            (vaultStateBindings vault)
        , vaultStateNextIdentity = vaultStateNextIdentity vault + 1
        }
  validateVaultState next
  pure (binding, next)

lockCredentialBinding ::
  Text -> VaultState -> Either IntegrationError (CredentialBinding, VaultState)
lockCredentialBinding = transitionBinding CredentialActive CredentialLocked

unlockCredentialBinding ::
  Text -> VaultState -> Either IntegrationError (CredentialBinding, VaultState)
unlockCredentialBinding = transitionBinding CredentialLocked CredentialActive

revokeCredentialBinding ::
  Text -> VaultState -> Either IntegrationError (CredentialBinding, VaultState)
revokeCredentialBinding identifier vault = do
  binding <- lookupBinding identifier vault
  unless (credentialBindingStatus binding `elem`
      [CredentialActive, CredentialLocked])
    (Left (InvalidCredentialBindingStatus (credentialBindingStatus binding)))
  let revoked = binding {credentialBindingStatus = CredentialRevoked}
      next = vault {vaultStateBindings = Map.insert identifier revoked
        (vaultStateBindings vault)}
  validateVaultState next
  pure (revoked, next)

transitionBinding ::
  CredentialBindingStatus -> CredentialBindingStatus -> Text -> VaultState ->
  Either IntegrationError (CredentialBinding, VaultState)
transitionBinding expected target identifier vault = do
  binding <- lookupBinding identifier vault
  unless (credentialBindingStatus binding == expected)
    (Left (InvalidCredentialBindingStatus (credentialBindingStatus binding)))
  let changed = binding {credentialBindingStatus = target}
      next = vault {vaultStateBindings = Map.insert identifier changed
        (vaultStateBindings vault)}
  validateVaultState next
  pure (changed, next)

authorizeCredential ::
  Text -> Text -> VaultState -> Either IntegrationError CredentialBinding
authorizeCredential component account vault = do
  unless (vaultStateUnlocked vault) (Left VaultUnavailable)
  let slots = Set.fromList
        [ credentialSlotId slot
        | slot <- Map.elems (vaultStateSlots vault)
        , credentialSlotComponent slot == component
        ]
      candidates = sortOn credentialBindingCreatedAt
        [ binding
        | binding <- Map.elems (vaultStateBindings vault)
        , credentialBindingSlot binding `Set.member` slots
        , credentialBindingAccount binding == account
        ]
  case reverse candidates of
    [] -> Left CredentialAccessUnauthorized
    binding : _ -> case credentialBindingStatus binding of
      CredentialActive -> Right binding
      CredentialLocked -> Left CredentialAccessLocked
      CredentialRevoked -> Left CredentialAccessRevoked

validateVaultState :: VaultState -> Either IntegrationError ()
validateVaultState vault = do
  mapM_ (\binding -> do
      unless (Map.member (credentialBindingSlot binding) (vaultStateSlots vault))
        (Left (UnknownCredentialSlot (credentialBindingSlot binding)))
      unless (Map.member (credentialBindingVaultEntryId binding)
          (vaultStateEntries vault))
        (Left (UnknownVaultEntry (credentialBindingVaultEntryId binding))))
    (Map.elems (vaultStateBindings vault))
  let livePairs =
        [ (credentialBindingSlot binding, credentialBindingAccount binding)
        | binding <- Map.elems (vaultStateBindings vault)
        , credentialBindingStatus binding `elem`
            [CredentialActive, CredentialLocked]
        ]
  unless (length livePairs == Set.size (Set.fromList livePairs))
    (case livePairs of
      pair : _ -> Left (uncurry DuplicateLiveCredentialBinding pair)
      [] -> Left (InvalidPackManifest "invalid empty binding invariant witness"))

lookupBinding :: Text -> VaultState -> Either IntegrationError CredentialBinding
lookupBinding identifier vault = maybe
  (Left (UnknownCredentialBinding identifier)) Right
  (Map.lookup identifier (vaultStateBindings vault))

isLiveBindingFor :: Text -> Text -> CredentialBinding -> Bool
isLiveBindingFor slot account binding =
  credentialBindingSlot binding == slot
    && credentialBindingAccount binding == account
    && credentialBindingStatus binding `elem` [CredentialActive, CredentialLocked]

------------------------------------------------------------
-- Pack execution, host HTTP, and deterministic invocation evidence
------------------------------------------------------------

validateHostHttpRequest ::
  PackComponent -> [Text] -> HostHttpRequest -> Either IntegrationError ()
validateHostHttpRequest component grants request = do
  unless (hostHttpRequestMethod request `elem`
      ["GET", "POST", "PUT", "PATCH", "DELETE"])
    (Left (InvalidHostHttpRequest "HTTP method is not in the typed allowlist"))
  when (hostHttpRequestBodySize request < 0
      || hostHttpRequestBodySize request > 1048576)
    (Left (InvalidHostHttpRequest "HTTP body exceeds the one-megabyte limit"))
  let grantedHosts = mapMaybe (Text.stripPrefix "http:") grants
      declaredHosts = mapMaybe (Text.stripPrefix "http:")
        (packComponentCapabilities component)
      targetHost = httpsHost (hostHttpRequestUrl request)
      redirectHost = hostHttpRequestRedirectUrl request >>= httpsHost
  host <- maybe (Left (InvalidHostHttpRequest
      "HTTP URL must use https and include an exact host")) Right targetHost
  unless (host `elem` grantedHosts && host `elem` declaredHosts)
    (Left (UndeclaredCapability ("http:" <> host)))
  case hostHttpRequestRedirectUrl request of
    Nothing -> pure ()
    Just _ -> unless (redirectHost == Just host)
      (Left (InvalidHostHttpRequest
        "redirect target differs from the exact allowed host"))

httpsHost :: Text -> Maybe Text
httpsHost url = do
  remainder <- Text.stripPrefix "https://" url
  let host = Text.takeWhile (\character -> character /= '/' && character /= '?'
        && character /= '#') remainder
  if validCapabilitySuffix host && not (Text.any (== ':') host)
    then Just host
    else Nothing

executePackBoundary ::
  Bool -> UTCTime -> Text -> ProviderOutcome -> PackExecutionRequest ->
  PackState -> PackDeployment ->
  Either IntegrationError (PackExecutionResult, PackState, PackDeployment)
executePackBoundary duringReplay now account outcome request state deployment = do
  when duringReplay (Left ReplayExecutionForbidden)
  unless (packExecutionRequestProtocolVersion request == 1)
    (Left (InvalidPackResult "unsupported request protocol version"))
  component <- findComponent (packExecutionRequestComponentId request) state
  unless (packComponentStatus component == ComponentEnabled)
    (Left (InvalidComponentStatus (packComponentStatus component)))
  unless (packComponentExecutable component)
    (Left (InvalidPackManifest "declarative component cannot execute"))
  let grants = packExecutionRequestCapabilityGrants request
  unless (length grants == length (nub grants))
    (Left (InvalidPackManifest "capability grants must be unique"))
  mapM_ (\grant -> unless (grant `elem` packComponentCapabilities component)
    (Left (UndeclaredCapability grant))) grants
  when (containsForbiddenSecret (packExecutionRequestInput request))
    (Left (RuntimeInputContainsSecret "Pack request input"))
  let componentId = packComponentId component
      sanitized = toJSON request
      validatedDeployment = deployment
        { packDeploymentRuntimeInputs = Map.insert componentId sanitized
            (packDeploymentRuntimeInputs deployment)
        }
      credentialRequested = any ("credential:" `Text.isPrefixOf`) grants
      authorization = if credentialRequested
        then authorizeCredential componentId account (packDeploymentVault deployment)
        else Right noCredentialBinding
  case authorization of
    Left problem | problem `elem`
        [VaultUnavailable, CredentialAccessLocked] ->
      pure (failedExecution "credential_locked", state, validatedDeployment)
    Left CredentialAccessRevoked ->
      pure (failedExecution "credential_revoked", state, validatedDeployment)
    Left CredentialAccessUnauthorized ->
      pure (failedExecution "credential_unauthorized", state, validatedDeployment)
    Left problem -> Left problem
    Right _ -> executeAuthorized component validatedDeployment grants
  where
    executeAuthorized component validatedDeployment grants = do
      let httpCapabilities = mapMaybe (Text.stripPrefix "http:") grants
          hasHttpRequest = not (null httpCapabilities)
          host = case httpCapabilities of
            firstHost : _ -> firstHost
            [] -> ""
          hostRequest = HostHttpRequest "GET" ("https://" <> host <> "/") 0 Nothing
          traceRecord = HostHttpRecord
            { hostHttpRecordComponentId = packComponentId component
            , hostHttpRecordAccount = account
            , hostHttpRecordMethod = "GET"
            , hostHttpRecordUrl = "https://" <> host <> "/"
            , hostHttpRecordCredentialInjected =
                any ("credential:" `Text.isPrefixOf`) grants
            }
          withTrace = if hasHttpRequest
            then validatedDeployment
              { packDeploymentHttpTrace = packDeploymentHttpTrace validatedDeployment
                  <> [traceRecord]
              }
            else validatedDeployment
          (result, withBackoff) = case outcome of
            ProviderSucceeded output ->
              (successfulExecution output, state)
            ProviderFailed _ | hasHttpRequest ->
              (failedExecution "provider_failure", advanceProviderBackoff
                (packComponentId component) account state)
            ProviderFailed _ ->
              (failedExecution "pack_runtime_failure", state)
          requestHash = digestValue (toJSON request)
      when hasHttpRequest (validateHostHttpRequest component grants hostRequest)
      (_, withInvocation) <- recordPackInvocation now
        (packComponentId component)
        (packExecutionRequestOperation request)
        "1"
        requestHash
        grants
        result
        withBackoff
      pure (result, withInvocation, withTrace
        {packDeploymentExecutionCount = packDeploymentExecutionCount withTrace + 1})

noCredentialBinding :: CredentialBinding
noCredentialBinding = CredentialBinding "none" "none" "none" "none"
  CredentialActive (UTCTime (fromGregorian 1970 1 1) 0)

successfulExecution :: Value -> PackExecutionResult
successfulExecution output = PackExecutionResult 1 True (Just output) Nothing []

failedExecution :: Text -> PackExecutionResult
failedExecution code = PackExecutionResult 1 False Nothing (Just code) []

advanceProviderBackoff :: Text -> Text -> PackState -> PackState
advanceProviderBackoff component account state = state
  { packStateProviderBackoff = Map.insertWith (+)
      (backoffKey component account) 1 (packStateProviderBackoff state)
  }

providerBackoff :: Text -> Text -> PackState -> Integer
providerBackoff component account state = Map.findWithDefault 0
  (backoffKey component account) (packStateProviderBackoff state)

------------------------------------------------------------
-- HsLua 2.3.1 fresh-VM sandbox
------------------------------------------------------------

-- | Execute one Lua 5.4 chunk in a fresh HsLua state.  Only the typed @lant@
-- table implied by the granted capabilities is installed.  The base library
-- is reduced before Pack code runs; filesystem loaders, printing, package,
-- IO, OS, debug, sockets, and dynamic libraries are absent.  An internal Lua
-- hook enforces the instruction budget while an outer timeout enforces the
-- wall-clock budget.  Source, result size, and result depth are checked at the
-- process boundary.
runLuaComponent ::
  SandboxLimits -> [Text] -> Value -> BS.ByteString -> IO PackExecutionResult
runLuaComponent limits grants input source
  | not (validLimits limits) = pure (failedExecution "invalid_runtime_limits")
  | BS.length source > sandboxLimitSourceBytes limits =
      pure (failedExecution "source_limit")
  | containsForbiddenSecret input =
      pure (failedExecution "credential_input_rejected")
  | otherwise = do
      attempted <- timeout (sandboxLimitWallMicros limits)
        (try (Lua.run @Lua.Exception (luaProgram limits grants input source)) ::
          IO (Either SomeException Value))
      pure $ case attempted of
        Nothing -> failedExecution "timeout"
        Just (Left problem)
          | "instruction_limit" `Text.isInfixOf` Text.pack (show problem) ->
              failedExecution "instruction_limit"
          | "memory_limit" `Text.isInfixOf` Text.pack (show problem) ->
              failedExecution "memory_limit"
          | otherwise -> failedExecution "lua_error"
        Just (Right output)
          | LBS.length (encode output) > fromIntegral
              (sandboxLimitOutputBytes limits) -> failedExecution "output_limit"
          | valueDepth output > sandboxLimitNestingDepth limits ->
              failedExecution "nesting_limit"
          | otherwise -> successfulExecution output

luaProgram ::
  SandboxLimits -> [Text] -> Value -> BS.ByteString -> Lua.Lua Value
luaProgram limits grants input source = do
  Lua.openbase
  Lua.opendebug
  Lua.setglobal "debug"
  Lua.settop 0
  mapM_ removeGlobal ["dofile", "loadfile", "print", "warn"]
  installTypedHost grants
  LuaAeson.pushValue input
  Lua.setglobal "input"
  let hookPeriod = 100 :: Integer
      hookCalls = max 1 (sandboxLimitInstructions limits `div` hookPeriod)
      prefix = BS8.pack
        ("do local __lant_count=0; local __lant_error=error; "
          <> "debug.sethook(function() __lant_count=__lant_count+1; "
          <> "if __lant_count>" <> show hookCalls
          <> " then __lant_error('instruction_limit') end end, '', "
          <> show hookPeriod <> "); end; debug=nil; ")
  _ <- Lua.loadstring (prefix <> source)
  Lua.call 0 1
  memoryKilobytes <- Lua.gc Lua.GCCount
  memoryRemainder <- Lua.gc Lua.GCCountb
  let memoryBytes = fromIntegral memoryKilobytes * 1024
        + fromIntegral memoryRemainder
  when (memoryBytes > sandboxLimitMemoryBytes limits)
    (Lua.failLua "memory_limit")
  Lua.forcePeek (LuaAeson.peekValue Lua.top)

removeGlobal :: Lua.Name -> Lua.Lua ()
removeGlobal name = Lua.pushnil *> Lua.setglobal name

installTypedHost :: [Text] -> Lua.Lua ()
installTypedHost grants =
  when (any ("http:" `Text.isPrefixOf`) grants) $ do
    Lua.newtable
    Lua.newtable
    Lua.pushHaskellFunction typedHttpStub
    Lua.setfield (-2) "request"
    Lua.setfield (-2) "http"
    Lua.setglobal "lant"

typedHttpStub :: Lua.LuaE Lua.Exception Lua.NumResults
typedHttpStub = do
  Lua.newtable
  Lua.pushboolean False
  Lua.setfield (-2) "ok"
  Lua.pushstring "host_call_must_be_brokered"
  Lua.setfield (-2) "error_code"
  pure (Lua.NumResults 1)

probePackSandbox :: [Text] -> IO (Either Text SandboxReport)
probePackSandbox grants = do
  result <- runLuaComponent defaultSandboxLimits grants Null
    (BS8.pack ("return {"
      <> "os = os ~= nil, "
      <> "process = process ~= nil or (os ~= nil and os.execute ~= nil), "
      <> "filesystem = filesystem ~= nil or io ~= nil or dofile ~= nil or loadfile ~= nil, "
      <> "socket = socket ~= nil, "
      <> "dynamic_library = dynamic_library ~= nil or "
      <> "(package ~= nil and package.loadlib ~= nil)}"))
  case packExecutionResultOutput result of
    Just value | packExecutionResultOk result -> case fromJSONValue value of
      Right report -> pure (Right report)
      Left problem -> pure (Left problem)
    _ -> pure (Left (fromMaybe "sandbox probe failed"
      (packExecutionResultErrorCode result)))

fromJSONValue :: FromJSON value => Value -> Either Text value
fromJSONValue value = case fromJSON value of
  Success decoded -> Right decoded
  Error problem -> Left (Text.pack problem)

validLimits :: SandboxLimits -> Bool
validLimits limits = and
  [ sandboxLimitWallMicros limits > 0
  , sandboxLimitInstructions limits > 0
  , sandboxLimitMemoryBytes limits > 0
  , sandboxLimitSourceBytes limits > 0
  , sandboxLimitOutputBytes limits > 0
  , sandboxLimitNestingDepth limits > 0
  ]

valueDepth :: Value -> Int
valueDepth = \case
  Object fields -> 1 + maximumOrZero (map valueDepth (KeyMap.elems fields))
  Array values -> 1 + maximumOrZero (map valueDepth (foldr (:) [] values))
  _ -> 1

maximumOrZero :: [Int] -> Int
maximumOrZero [] = 0
maximumOrZero values = maximum values

------------------------------------------------------------
-- Sparse/redacted projections and helpers
------------------------------------------------------------

packStateProjection :: PackState -> Value
packStateProjection state = object
  [ "packs" .= Map.elems (packStatePacks state)
  , "components" .= Map.elems (packStateComponents state)
  , "installations" .= packStateInstallations state
  , "invocations" .= packStateInvocations state
  , "provider_backoff" .= packStateProviderBackoff state
  ]

-- | Pack content deliberately excludes VaultEntry, CredentialBinding, local
-- account names, runtime inputs, and provider traces.
packContentProjection :: PackInstallManifest -> Value
packContentProjection = toJSON

credentialBindingProjection :: CredentialBinding -> Value
credentialBindingProjection binding = object
  [ "id" .= credentialBindingId binding
  , "slot" .= credentialBindingSlot binding
  , "account" .= credentialBindingAccount binding
  , "vault_entry_id" .= credentialBindingVaultEntryId binding
  , "status" .= credentialBindingStatus binding
  , "created_at" .= credentialBindingCreatedAt binding
  ]

sandboxReportProjection :: SandboxReport -> Value
sandboxReportProjection = toJSON

containsForbiddenSecret :: Value -> Bool
containsForbiddenSecret = \case
  Object fields -> any forbiddenKey (map (Text.toLower . Key.toText)
      (KeyMap.keys fields)) || any containsForbiddenSecret (KeyMap.elems fields)
  Array values -> any containsForbiddenSecret values
  _ -> False
  where
    forbiddenKey key = key `elem`
      [ "secret", "token", "access_token", "refresh_token", "vault_payload"
      , "encrypted_payload", "credential_payload"
      ]

requireNonempty :: Text -> Text -> Either IntegrationError ()
requireNonempty label value = when (Text.null (Text.strip value))
  (Left (InvalidPackManifest (label <> " cannot be empty")))

requirePositive :: Text -> Integer -> Either IntegrationError ()
requirePositive label value = when (value <= 0)
  (Left (InvalidPackManifest (label <> " must be positive")))

packKey :: Text -> Integer -> Text
packKey identifier version = identifier <> "@" <> Text.pack (show version)

componentBelongsTo :: LittleAntPack -> PackComponent -> Bool
componentBelongsTo pack component =
  packComponentPackId component == littleAntPackId pack
    && packComponentPackVersion component == littleAntPackVersion pack

identity :: Text -> PackState -> Text
identity kind state = "la1_" <> kind <> "_" <>
  Text.pack (show (packStateNextIdentity state))

vaultIdentity :: Text -> VaultState -> Text
vaultIdentity kind vault = "local_" <> kind <> "_" <>
  Text.pack (show (vaultStateNextIdentity vault))

backoffKey :: Text -> Text -> Text
backoffKey component account = component <> "\NUL" <> account

digestValue :: Value -> Text
digestValue = Text.pack . showDigest . sha256 . encode

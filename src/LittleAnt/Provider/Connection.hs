module LittleAnt.Provider.Connection (
  ProviderConnectionDraft (..),
  ProviderOAuthClient (..),
  prepareProviderConnectionDraft,
  applyProviderConnectionDraft,
  connectionOAuthClient,
)
where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.OAuth.AuthorizationCode
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import LittleAnt.Provider
import LittleAnt.Vault qualified as Vault

data ProviderConnectionDraft = ProviderConnectionDraft
  { providerConnectionSource :: Text
  , providerConnectionDisplayName :: Text
  , providerConnectionAccountName :: Text
  , providerConnectionAccount :: ProviderAccount
  , providerConnectionBindingName :: Text
  , providerConnectionBinding :: CredentialBinding
  , providerConnectionClientId :: Text
  , providerConnectionArtifact :: PackArtifactIdentity
  , providerConnectionScopes :: Set Text
  , providerConnectionProfileRevision :: Text
  }
  deriving stock (Eq, Show)

data ProviderOAuthClient
  = ProviderOAuthPkceClient OAuthPkceClient
  | ProviderOAuthDeviceClient OAuthDeviceClient

data OAuthDescriptor
  = PkceDescriptor OAuthAuthorizationCodePkcePermission
  | DeviceDescriptor OAuthDeviceAuthorizationPermission

prepareProviderConnectionDraft :: [ProviderSourceDefinition] -> PackRegistry -> IntegrationsConfig -> Text -> Text -> Text -> Text -> Text -> UUIDv7 -> Either AppError ProviderConnectionDraft
prepareProviderConnectionDraft definitions registry integrations revision requestedSource requestedAccount requestedLabel clientId allocatedVaultEntry = do
  let source = Text.strip requestedSource
      accountName = Text.strip requestedAccount
      label = Text.strip requestedLabel
  definition <-
    maybe
      (Left (connectionProblem NotFound "The requested provider source is not in the standard connection catalog." [source]))
      Right
      (find ((== source) . providerDefinitionAdapterId) definitions)
  unless (validIntegrationName accountName) $
    Left (connectionProblem InvalidInput "The provider account key must be a lowercase local identifier." [accountName])
  unless (not (Text.null label) && Text.length label <= 160 && Text.all visibleLabelCharacter label) $
    Left (connectionProblem InvalidInput "The provider account label must contain 1 to 160 printable characters." [label])
  registered <- lookupPackComponent source registry
  unless (componentKind (componentCommon (registeredComponent registered)) == SourceAdapterComponent) $
    Left (connectionProblem PreconditionFailed "The selected Pack component is not a SourceAdapter." [source])
  authorization <- soleOAuthAuthorization registered
  let slot = descriptorSlot authorization
      scheme = descriptorScheme authorization
  existingAccount <- compatibleExistingAccount definition accountName integrations
  let account =
        ProviderAccount
          { providerAccountComponent = source
          , providerAccountProvider = providerDefinitionNamespace definition
          , providerAccountExternalId = maybe accountName providerAccountExternalId existingAccount
          , providerAccountLabel = label
          , providerAccountConfiguration = insertClientId (descriptorClientIdKey authorization) clientId (providerAccountConfiguration <$> existingAccount)
          }
  client <- resolveProviderOAuthClient registered account authorization
  (bindingName, vaultEntry) <- existingBinding source accountName slot scheme allocatedVaultEntry integrations
  let binding =
        CredentialBinding
          { credentialBindingComponent = source
          , credentialBindingSlot = slot
          , credentialBindingAccount = accountName
          , credentialBindingScheme = scheme
          , credentialBindingVaultEntry = vaultEntry
          , credentialBindingAuthorizationFingerprint = Just (providerOAuthFingerprint client)
          , credentialBindingPurposes = Set.singleton "source_read"
          }
      draft =
        ProviderConnectionDraft
          { providerConnectionSource = source
          , providerConnectionDisplayName = providerDefinitionDisplayName definition
          , providerConnectionAccountName = accountName
          , providerConnectionAccount = account
          , providerConnectionBindingName = bindingName
          , providerConnectionBinding = binding
          , providerConnectionClientId = clientId
          , providerConnectionArtifact = registeredPackIdentity registered
          , providerConnectionScopes = providerOAuthScopes client
          , providerConnectionProfileRevision = revision
          }
  _ <- applyProviderConnectionDraft integrations draft
  pure draft

applyProviderConnectionDraft :: IntegrationsConfig -> ProviderConnectionDraft -> Either AppError IntegrationsConfig
applyProviderConnectionDraft integrations draft = do
  let changed =
        integrations
          { providerAccounts = Map.insert (providerConnectionAccountName draft) (providerConnectionAccount draft) (providerAccounts integrations)
          , credentialBindings = Map.insert (providerConnectionBindingName draft) (providerConnectionBinding draft) (credentialBindings integrations)
          }
  validateIntegrationsConfig changed
  pure changed

connectionOAuthClient :: PackRegistry -> ProviderConnectionDraft -> Either AppError ProviderOAuthClient
connectionOAuthClient registry draft = do
  registered <- lookupPackComponent (providerConnectionSource draft) registry
  unless (registeredPackIdentity registered == providerConnectionArtifact draft) $
    Left (connectionProblem PermissionRequired "The installed provider Pack changed after the connection preview." [providerConnectionSource draft])
  descriptor <- soleOAuthAuthorization registered
  client <- resolveProviderOAuthClient registered (providerConnectionAccount draft) descriptor
  unless
    ( providerOAuthFingerprint client == maybe "" id (credentialBindingAuthorizationFingerprint (providerConnectionBinding draft))
        && providerOAuthScopes client == providerConnectionScopes draft
        && descriptorSlot descriptor == credentialBindingSlot (providerConnectionBinding draft)
        && descriptorScheme descriptor == credentialBindingScheme (providerConnectionBinding draft)
    )
    (Left (connectionProblem PermissionRequired "The signed provider authorization changed after the connection preview." [providerConnectionSource draft]))
  pure client

soleOAuthAuthorization :: RegisteredPackComponent -> Either AppError OAuthDescriptor
soleOAuthAuthorization registered = case registeredComponent registered of
  ExecutableComponent _ _ permissions -> case candidates permissions of
    [authorization] -> Right authorization
    [] -> Left (connectionProblem PreconditionFailed "The selected provider declares no supported OAuth authorization." [])
    _ -> Left (connectionProblem Conflict "The selected provider declares more than one OAuth authorization; choose an explicit connection profile." [])
  _ -> Left (connectionProblem PreconditionFailed "A declarative component cannot connect a provider account." [])
 where
  candidates permissions =
    (PkceDescriptor <$> permissionOAuthAuthorizationCodePkce permissions)
      <> (DeviceDescriptor <$> permissionOAuthDeviceAuthorizations permissions)

descriptorSlot :: OAuthDescriptor -> Text
descriptorSlot = \case
  PkceDescriptor permission -> oauthPkceCredentialSlot permission
  DeviceDescriptor permission -> oauthDeviceCredentialSlot permission

descriptorScheme :: OAuthDescriptor -> Vault.CredentialScheme
descriptorScheme = \case
  PkceDescriptor _ -> Vault.OAuthAuthorizationCodePKCE
  DeviceDescriptor _ -> Vault.OAuthDeviceAuthorization

descriptorClientIdKey :: OAuthDescriptor -> Text
descriptorClientIdKey = \case
  PkceDescriptor permission -> oauthPkceClientIdConfigurationKey permission
  DeviceDescriptor permission -> oauthDeviceClientIdConfigurationKey permission

resolveProviderOAuthClient :: RegisteredPackComponent -> ProviderAccount -> OAuthDescriptor -> Either AppError ProviderOAuthClient
resolveProviderOAuthClient registered account = \case
  PkceDescriptor permission -> ProviderOAuthPkceClient <$> resolveOAuthPkceClient registered account (oauthPkceCredentialSlot permission)
  DeviceDescriptor permission -> ProviderOAuthDeviceClient <$> resolveOAuthDeviceClient registered account (oauthDeviceCredentialSlot permission)

providerOAuthFingerprint :: ProviderOAuthClient -> Text
providerOAuthFingerprint = \case
  ProviderOAuthPkceClient client -> oauthPkceAuthorizationFingerprint client
  ProviderOAuthDeviceClient client -> oauthDeviceAuthorizationFingerprint client

providerOAuthScopes :: ProviderOAuthClient -> Set Text
providerOAuthScopes = \case
  ProviderOAuthPkceClient client -> oauthPkceRequestedScopes client
  ProviderOAuthDeviceClient client -> oauthDeviceRequestedScopes client

compatibleExistingAccount :: ProviderSourceDefinition -> Text -> IntegrationsConfig -> Either AppError (Maybe ProviderAccount)
compatibleExistingAccount definition accountName integrations = case Map.lookup accountName (providerAccounts integrations) of
  Nothing -> Right Nothing
  Just account
    | providerAccountComponent account /= providerDefinitionAdapterId definition ->
        Left (connectionProblem Conflict "This provider account key already belongs to another component." [accountName, providerAccountComponent account])
    | providerAccountProvider account /= providerDefinitionNamespace definition ->
        Left (connectionProblem Conflict "This provider account key already belongs to another provider namespace." [accountName, providerAccountProvider account])
    | otherwise -> Right (Just account)

existingBinding :: Text -> Text -> Text -> Vault.CredentialScheme -> UUIDv7 -> IntegrationsConfig -> Either AppError (Text, UUIDv7)
existingBinding source accountName slot scheme allocated integrations =
  case [ (name, binding)
       | (name, binding) <- Map.toList (credentialBindings integrations)
       , credentialBindingComponent binding == source
       , credentialBindingAccount binding == accountName
       ] of
    [] -> do
      let name = source <> "-" <> accountName
      unless (validIntegrationName name) $
        Left (connectionProblem InvalidInput "The derived credential-binding name is too long; use a shorter account key." [name])
      case Map.lookup name (credentialBindings integrations) of
        Nothing -> Right (name, allocated)
        Just _ -> Left (connectionProblem Conflict "The derived credential-binding name is already in use." [name])
    [(name, binding)] -> do
      unless (credentialBindingSlot binding == slot && credentialBindingScheme binding == scheme) $
        Left (connectionProblem Conflict "The existing provider binding uses a different credential slot or scheme." [name])
      Right (name, credentialBindingVaultEntry binding)
    matches -> Left (connectionProblem Conflict "The provider account has more than one credential binding." (fst <$> matches))

insertClientId :: Text -> Text -> Maybe Value -> Value
insertClientId slot clientId existing =
  let fields = case existing of
        Just (Object objectValue) -> objectValue
        _ -> KeyMap.empty
   in Object (KeyMap.insert (Key.fromText slot) (String clientId) fields)

connectionProblem :: ErrorCode -> Text -> [Text] -> AppError
connectionProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRecovery =
        [ RecoveryAction "packs" "Install and inspect the provider's signed SourceAdapter." (Just "lant packs list")
        , RecoveryAction "config" "Inspect the selected profile's redacted integration configuration." (Just "lant config show")
        ]
    }

visibleLabelCharacter :: Char -> Bool
visibleLabelCharacter character = character >= ' ' && character /= '\DEL'

instance ToJSON ProviderConnectionDraft where
  toJSON draft =
    object
      [ "source" .= providerConnectionSource draft
      , "display_name" .= providerConnectionDisplayName draft
      , "account_name" .= providerConnectionAccountName draft
      , "account" .= providerConnectionAccount draft
      , "binding_name" .= providerConnectionBindingName draft
      , "binding" .= providerConnectionBinding draft
      , "client_id" .= providerConnectionClientId draft
      , "artifact" .= providerConnectionArtifact draft
      , "scopes" .= Set.toAscList (providerConnectionScopes draft)
      , "profile_revision" .= providerConnectionProfileRevision draft
      ]

instance FromJSON ProviderConnectionDraft where
  parseJSON = withObject "ProviderConnectionDraft" $ \fields -> do
    rejectUnknown fields ["source", "display_name", "account_name", "account", "binding_name", "binding", "client_id", "artifact", "scopes", "profile_revision"]
    ProviderConnectionDraft
      <$> fields .: "source"
      <*> fields .: "display_name"
      <*> fields .: "account_name"
      <*> fields .: "account"
      <*> fields .: "binding_name"
      <*> fields .: "binding"
      <*> fields .: "client_id"
      <*> fields .: "artifact"
      <*> (Set.fromList <$> fields .: "scopes")
      <*> fields .: "profile_revision"

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

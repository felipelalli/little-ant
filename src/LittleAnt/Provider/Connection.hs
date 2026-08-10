module LittleAnt.Provider.Connection (
  ProviderConnectionDraft (..),
  ProviderOAuthClient (..),
  prepareProviderConnectionDraft,
  applyProviderConnectionDraft,
  connectionOAuthClient,
  connectionUsesStaticCredential,
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
  , providerConnectionClientId :: Maybe Text
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

data ConnectionDescriptor
  = OAuthConnection OAuthDescriptor
  | StaticConnection CredentialSlot Vault.CredentialScheme

prepareProviderConnectionDraft :: [ProviderSourceDefinition] -> PackRegistry -> IntegrationsConfig -> Text -> Text -> Text -> Text -> Maybe Text -> UUIDv7 -> Either AppError ProviderConnectionDraft
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
  authorization <- soleConnectionAuthorization registered
  let slot = connectionDescriptorSlot authorization
      scheme = connectionDescriptorScheme authorization
  existingAccount <- compatibleExistingAccount definition accountName integrations
  (configuration, scopes, fingerprint, publicClientId) <- case authorization of
    OAuthConnection oauth -> do
      supplied <- case Text.strip <$> clientId of
        Just value | not (Text.null value) -> Right value
        _ -> Left (connectionProblem InvalidInput "The public OAuth client ID is required by this signed connector." [source])
      let configured = insertClientId (descriptorClientIdKey oauth) supplied (providerAccountConfiguration <$> existingAccount)
      accountForClient <-
        pure
          ProviderAccount
            { providerAccountComponent = source
            , providerAccountProvider = providerDefinitionNamespace definition
            , providerAccountExternalId = maybe accountName providerAccountExternalId existingAccount
            , providerAccountLabel = label
            , providerAccountConfiguration = configured
            }
      client <- resolveProviderOAuthClient registered accountForClient oauth
      pure (configured, providerOAuthScopes client, Just (providerOAuthFingerprint client), Just supplied)
    StaticConnection _ _ -> do
      unless (maybe True (Text.null . Text.strip) clientId) $
        Left (connectionProblem InvalidInput "This signed connector uses a static credential and accepts no OAuth client ID." [source])
      pure (maybe (Object KeyMap.empty) providerAccountConfiguration existingAccount, Set.empty, Nothing, Nothing)
  let account =
        ProviderAccount
          { providerAccountComponent = source
          , providerAccountProvider = providerDefinitionNamespace definition
          , providerAccountExternalId = maybe accountName providerAccountExternalId existingAccount
          , providerAccountLabel = label
          , providerAccountConfiguration = configuration
          }
  (bindingName, vaultEntry) <- existingBinding source accountName slot scheme allocatedVaultEntry integrations
  let binding =
        CredentialBinding
          { credentialBindingComponent = source
          , credentialBindingSlot = slot
          , credentialBindingAccount = accountName
          , credentialBindingScheme = scheme
          , credentialBindingVaultEntry = vaultEntry
          , credentialBindingAuthorizationFingerprint = fingerprint
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
          , providerConnectionClientId = publicClientId
          , providerConnectionArtifact = registeredPackIdentity registered
          , providerConnectionScopes = scopes
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

connectionUsesStaticCredential :: ProviderConnectionDraft -> Bool
connectionUsesStaticCredential draft =
  credentialBindingScheme (providerConnectionBinding draft) `elem` [Vault.BearerCredential, Vault.ApiKeyCredential]

soleConnectionAuthorization :: RegisteredPackComponent -> Either AppError ConnectionDescriptor
soleConnectionAuthorization registered = case registeredComponent registered of
  ExecutableComponent _ _ permissions ->
    case oauthCandidates permissions of
      [authorization] -> Right (OAuthConnection authorization)
      [] -> case staticCandidates permissions of
        [(slot, scheme)] -> Right (StaticConnection slot scheme)
        [] -> Left (connectionProblem PreconditionFailed "The selected provider declares no supported credential connection." [])
        _ -> Left (connectionProblem Conflict "The selected provider declares more than one static credential slot; choose an explicit connection profile." [])
      _ -> Left (connectionProblem Conflict "The selected provider declares more than one OAuth authorization; choose an explicit connection profile." [])
  _ -> Left (connectionProblem PreconditionFailed "A declarative component cannot connect a provider account." [])
 where
  oauthCandidates permissions =
    (PkceDescriptor <$> permissionOAuthAuthorizationCodePkce permissions)
      <> (DeviceDescriptor <$> permissionOAuthDeviceAuthorizations permissions)
  oauthSlots permissions = Set.fromList (descriptorSlot <$> oauthCandidates permissions)
  staticCandidates permissions =
    [ (slot, scheme)
    | slot <- permissionCredentialSlots permissions
    , credentialSlotId slot `Set.notMember` oauthSlots permissions
    , scheme <- case credentialSlotScheme slot of
        BearerToken -> [Vault.BearerCredential]
        ApiKey -> [Vault.ApiKeyCredential]
        _ -> []
    ]

soleOAuthAuthorization :: RegisteredPackComponent -> Either AppError OAuthDescriptor
soleOAuthAuthorization registered =
  soleConnectionAuthorization registered >>= \case
    OAuthConnection authorization -> Right authorization
    StaticConnection _ _ -> Left (connectionProblem PreconditionFailed "The selected provider uses a static credential rather than OAuth." [])

connectionDescriptorSlot :: ConnectionDescriptor -> Text
connectionDescriptorSlot = \case
  OAuthConnection authorization -> descriptorSlot authorization
  StaticConnection slot _ -> credentialSlotId slot

connectionDescriptorScheme :: ConnectionDescriptor -> Vault.CredentialScheme
connectionDescriptorScheme = \case
  OAuthConnection authorization -> descriptorScheme authorization
  StaticConnection _ scheme -> scheme

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
    object $
      [ "source" .= providerConnectionSource draft
      , "display_name" .= providerConnectionDisplayName draft
      , "account_name" .= providerConnectionAccountName draft
      , "account" .= providerConnectionAccount draft
      , "binding_name" .= providerConnectionBindingName draft
      , "binding" .= providerConnectionBinding draft
      , "artifact" .= providerConnectionArtifact draft
      , "profile_revision" .= providerConnectionProfileRevision draft
      ]
        <> maybe [] (pure . ("client_id" .=)) (providerConnectionClientId draft)
        <> [("scopes" .= Set.toAscList (providerConnectionScopes draft)) | not (Set.null (providerConnectionScopes draft))]

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
      <*> fields .:? "client_id"
      <*> fields .: "artifact"
      <*> (Set.fromList <$> fields .:? "scopes" .!= [])
      <*> fields .: "profile_revision"

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

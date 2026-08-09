module LittleAnt.Provider (
  ProviderSourceDefinition (..),
  standardProviderSourceDefinitions,
  providerAccessTokenResolver,
  configuredProviderImportSources,
)
where

import Control.Exception (finally)
import Control.Monad (forM, unless)
import Data.Aeson (Value (Object, String), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Import
import LittleAnt.Model (SourceMode (..))
import LittleAnt.OAuth.AuthorizationCode
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Transport
import LittleAnt.Profile
import LittleAnt.Vault qualified as Vault
import LittleAnt.Vault.Agent

data ProviderSourceDefinition = ProviderSourceDefinition
  { providerDefinitionAdapterId :: Text
  , providerDefinitionNamespace :: Text
  , providerDefinitionDisplayName :: Text
  , providerDefinitionModes :: [SourceMode]
  , providerDefinitionRequiresContainerSelection :: Bool
  }
  deriving stock (Eq, Show)

standardProviderSourceDefinitions :: [ProviderSourceDefinition]
standardProviderSourceDefinitions =
  [ ProviderSourceDefinition
      { providerDefinitionAdapterId = "microsoft_todo"
      , providerDefinitionNamespace = "microsoft_todo"
      , providerDefinitionDisplayName = "Microsoft To Do"
      , providerDefinitionModes = [SourceSnapshot, SourceSynchronize, SourceMigrate]
      , providerDefinitionRequiresContainerSelection = False
      }
  , ProviderSourceDefinition
      { providerDefinitionAdapterId = "google_tasks"
      , providerDefinitionNamespace = "google_tasks"
      , providerDefinitionDisplayName = "Google Tasks"
      , providerDefinitionModes = [SourceSnapshot, SourceSynchronize, SourceMigrate]
      , providerDefinitionRequiresContainerSelection = False
      }
  , ProviderSourceDefinition
      { providerDefinitionAdapterId = "google_calendar"
      , providerDefinitionNamespace = "google_calendar"
      , providerDefinitionDisplayName = "Google Calendar"
      , providerDefinitionModes = [SourceSnapshot, SourceSynchronize]
      , providerDefinitionRequiresContainerSelection = True
      }
  ]

providerAccessTokenResolver :: [ProviderSourceDefinition] -> PackRegistry -> IntegrationsConfig -> FilePath -> IO UTCTime -> OAuthFormTransport -> AccessTokenResolver
providerAccessTokenResolver definitions registry integrations socketPath currentTime transport = AccessTokenResolver $ \binding -> do
  resolved <- sendVaultAgentRequest socketPath (agentResolveRequest (credentialBindingVaultEntry binding) "source_read")
  case resolved of
    Left problem -> pure (Left problem)
    Right reply -> case agentReplySecret reply of
      Nothing -> pure . Left $ providerProblem ExternalFailure "The vault agent returned no credential material for this provider binding." []
      Just secret -> finally (resolveOrRefresh binding secret) (wipeAgentSecret secret)
 where
  resolveOrRefresh binding secret = do
    now <- currentTime
    case accessTokenFromVaultSecret now binding secret of
      Right token -> pure (Right token)
      Left problem
        | appErrorRetrySafety problem == RetryAfterRefresh -> refreshExpired now binding secret
        | otherwise -> pure (Left problem)

  refreshExpired now binding secret = case refreshPlan binding secret of
    Left problem -> pure (Left problem)
    Right (definition, account, previous, client) -> do
      refreshed <- case client of
        ProviderRefreshPkce pkce -> refreshOAuthPkceTokenSet transport now pkce previous
        ProviderRefreshDevice device -> refreshOAuthTokenSet transport now device previous
      case refreshed of
        Left problem -> pure (Left problem)
        Right tokenSet -> do
          let label = providerDefinitionDisplayName definition <> " · " <> providerAccountLabel account
          persisted <- case client of
            ProviderRefreshPkce pkce -> persistOAuthPkceTokenSet socketPath pkce binding label tokenSet
            ProviderRefreshDevice device -> persistOAuthTokenSet socketPath device binding label tokenSet
          pure $ persisted >> accessTokenFromBytes (TextEncoding.encodeUtf8 (oauthAccessToken tokenSet))

  refreshPlan binding secret = do
    previous <-
      either
        (const (Left (providerProblem CorruptData "The stored provider credential is not a supported OAuth token set." [])))
        Right
        (eitherDecodeStrict' secret)
    account <- case Map.lookup (credentialBindingAccount binding) (providerAccounts integrations) of
      Nothing -> Left (providerProblem CorruptData "The OAuth binding names a missing provider account." [credentialBindingAccount binding])
      Just value -> Right value
    unless (providerAccountComponent account == credentialBindingComponent binding) $
      Left (providerProblem CorruptData "The OAuth binding and provider account name different components." [credentialBindingComponent binding, providerAccountComponent account])
    definition <- case filter ((== credentialBindingComponent binding) . providerDefinitionAdapterId) definitions of
      [value] -> Right value
      [] -> Left (providerProblem Unsupported "The OAuth binding has no refresh-capable provider definition." [credentialBindingComponent binding])
      _ -> Left (providerProblem CorruptData "The provider definition catalog is ambiguous during OAuth refresh." [credentialBindingComponent binding])
    unless (providerAccountProvider account == providerDefinitionNamespace definition) $
      Left (providerProblem CorruptData "The provider account has the wrong namespace during OAuth refresh." [providerAccountProvider account])
    registered <- lookupPackComponent (credentialBindingComponent binding) registry
    client <- case credentialBindingScheme binding of
      Vault.OAuthAuthorizationCodePKCE -> ProviderRefreshPkce <$> resolveOAuthPkceClient registered account (credentialBindingSlot binding)
      Vault.OAuthDeviceAuthorization -> ProviderRefreshDevice <$> resolveOAuthDeviceClient registered account (credentialBindingSlot binding)
      _ -> Left (providerProblem PreconditionFailed "Only an OAuth binding can enter provider token refresh." [Vault.credentialSchemeName (credentialBindingScheme binding)])
    pure (definition, account, previous, client)

data ProviderRefreshClient
  = ProviderRefreshPkce OAuthPkceClient
  | ProviderRefreshDevice OAuthDeviceClient

configuredProviderImportSources :: [ProviderSourceDefinition] -> IntegrationsConfig -> PackRegistry -> AccessTokenResolver -> PackHttpTransport -> Either AppError [ProviderImportSource]
configuredProviderImportSources definitions integrations registry resolver transport =
  fmap concat . forM definitions $ \definition -> do
    let matchingAccounts =
          sortOn
            fst
            [ (name, account)
            | (name, account) <- Map.toList (providerAccounts integrations)
            , providerAccountComponent account == providerDefinitionAdapterId definition
            ]
        qualify = length matchingAccounts > 1
    if null matchingAccounts
      then pure []
      else do
        registered <- lookupPackComponent (providerDefinitionAdapterId definition) registry
        forM matchingAccounts $ \(accountName, account) -> do
          unless (providerAccountProvider account == providerDefinitionNamespace definition) $
            Left (providerProblem CorruptData "A configured provider account has the wrong provider namespace." [accountName, providerAccountProvider account])
          (bindingReference, binding) <- exactBinding integrations definition accountName
          hostOnlyKeys <- case credentialBindingScheme binding of
            Vault.OAuthAuthorizationCodePKCE -> do
              oauthClient <- resolveOAuthPkceClient registered account (credentialBindingSlot binding)
              validateOAuthPkceCredentialBinding oauthClient binding
              pure (Set.singleton (oauthPkceClientConfigurationKey oauthClient))
            Vault.OAuthDeviceAuthorization -> do
              oauthClient <- resolveOAuthDeviceClient registered account (credentialBindingSlot binding)
              validateOAuthCredentialBinding oauthClient binding
              pure (Set.singleton (oauthDeviceClientConfigurationKey oauthClient))
            _ -> Right Set.empty
          broker <- credentialBoundPackHttpBroker registered binding resolver transport
          configuration <- sourceConfiguration hostOnlyKeys accountName account
          let reference =
                if qualify
                  then providerDefinitionAdapterId definition <> "@" <> accountName
                  else providerDefinitionAdapterId definition
              canonicalReference = providerDefinitionAdapterId definition <> "@" <> accountName
          pure
            ProviderImportSource
              { providerImportReference = reference
              , providerImportCanonicalReference = canonicalReference
              , providerImportAdapterId = providerDefinitionAdapterId definition
              , providerImportDisplayName = providerDefinitionDisplayName definition
              , providerImportInputLabel = providerDefinitionDisplayName definition <> " · " <> providerAccountLabel account
              , providerImportModes = providerDefinitionModes definition
              , providerImportRequiresContainerSelection = providerDefinitionRequiresContainerSelection definition
              , providerImportConfiguration = configuration
              , providerImportCredentialBindingReference = bindingReference
              , providerImportBroker = broker
              }

exactBinding :: IntegrationsConfig -> ProviderSourceDefinition -> Text -> Either AppError (Text, CredentialBinding)
exactBinding integrations definition accountName =
  case [ (bindingName, binding)
       | (bindingName, binding) <- Map.toList (credentialBindings integrations)
       , credentialBindingComponent binding == providerDefinitionAdapterId definition
       , credentialBindingAccount binding == accountName
       ] of
    [binding] -> Right binding
    [] ->
      Left
        (providerProblem PermissionRequired "The provider account has no CredentialBinding." [accountName])
          { appErrorRecovery = [RecoveryAction "configure-binding" "Bind this provider account to one opaque vault entry." (Just "lant config show")]
          }
    _ -> Left (providerProblem Conflict "The provider account resolves to more than one CredentialBinding." [accountName])

sourceConfiguration :: Set.Set Text -> Text -> ProviderAccount -> Either AppError Value
sourceConfiguration hostOnlyKeys accountName account = case providerAccountConfiguration account of
  Object configured -> do
    let reserved = ["provider", "account_id", "account_label"]
        collisions = filter (`KeyMap.member` configured) (Key.fromText <$> reserved)
    unless (null collisions) $
      Left (providerProblem CorruptData "Provider-account configuration attempts to replace host-owned identity fields." [accountName, Text.intercalate ", " (Key.toText <$> collisions)])
    let adapterConfiguration = foldr (KeyMap.delete . Key.fromText) configured (Set.toList hostOnlyKeys)
    pure . Object
      $ KeyMap.insert "provider" (textValue (providerAccountProvider account))
        . KeyMap.insert "account_id" (textValue (providerAccountExternalId account))
        . KeyMap.insert "account_label" (textValue (providerAccountLabel account))
      $ adapterConfiguration
  _ -> Left (providerProblem CorruptData "Provider-account configuration is not an object." [accountName])
 where
  textValue = String

providerProblem :: ErrorCode -> Text -> [Text] -> AppError
providerProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRetrySafety = DoNotRetry
    }

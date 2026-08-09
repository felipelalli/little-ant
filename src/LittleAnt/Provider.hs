module LittleAnt.Provider (
  ProviderSourceDefinition (..),
  configuredProviderImportSources,
)
where

import Control.Monad (forM, unless)
import Data.Aeson (Value (Object, String))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Import
import LittleAnt.Model (SourceMode)
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Transport
import LittleAnt.Profile
import LittleAnt.Vault qualified as Vault

data ProviderSourceDefinition = ProviderSourceDefinition
  { providerDefinitionAdapterId :: Text
  , providerDefinitionNamespace :: Text
  , providerDefinitionDisplayName :: Text
  , providerDefinitionModes :: [SourceMode]
  }
  deriving stock (Eq, Show)

configuredProviderImportSources :: [ProviderSourceDefinition] -> IntegrationsConfig -> PackRegistry -> AccessTokenResolver -> PackHttpTransport -> Either AppError [ProviderImportSource]
configuredProviderImportSources definitions integrations registry resolver transport =
  fmap concat . forM definitions $ \definition -> do
    registered <- lookupPackComponent (providerDefinitionAdapterId definition) registry
    let matchingAccounts =
          sortOn
            fst
            [ (name, account)
            | (name, account) <- Map.toList (providerAccounts integrations)
            , providerAccountComponent account == providerDefinitionAdapterId definition
            ]
        qualify = length matchingAccounts > 1
    forM matchingAccounts $ \(accountName, account) -> do
      unless (providerAccountProvider account == providerDefinitionNamespace definition) $
        Left (providerProblem CorruptData "A configured provider account has the wrong provider namespace." [accountName, providerAccountProvider account])
      binding <- exactBinding integrations definition accountName
      hostOnlyKeys <- case credentialBindingScheme binding of
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
      pure
        ProviderImportSource
          { providerImportReference = reference
          , providerImportAdapterId = providerDefinitionAdapterId definition
          , providerImportDisplayName = providerDefinitionDisplayName definition
          , providerImportInputLabel = providerDefinitionDisplayName definition <> " · " <> providerAccountLabel account
          , providerImportModes = providerDefinitionModes definition
          , providerImportConfiguration = configuration
          , providerImportBroker = broker
          }

exactBinding :: IntegrationsConfig -> ProviderSourceDefinition -> Text -> Either AppError CredentialBinding
exactBinding integrations definition accountName =
  case [ binding
       | binding <- Map.elems (credentialBindings integrations)
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

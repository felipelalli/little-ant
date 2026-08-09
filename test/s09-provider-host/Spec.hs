module Main (main) where

import Data.Aeson (Value, encode, object, toJSON, (.=))
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime, addUTCTime)
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Import
import LittleAnt.Model (SourceMode (..))
import LittleAnt.Pack.Format
import LittleAnt.Pack.Http
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Transport
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import LittleAnt.Provider
import LittleAnt.Source
import LittleAnt.Vault qualified as Vault
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 provider host"
      [ testCase "integrations YAML round-trips typed accounts and bindings without secret-shaped configuration" typedIntegrationState
      , testCase "OAuth token sets are closed, expiring vault payloads rather than configuration secrets" oauthTokenCustody
      , testCase "configured provider import injects credentials only after Pack route authorization" credentialBoundary
      , testCase "locked credentials stop before provider transport and retain a typed non-provider failure" lockedCredential
      , testCase "multiple accounts receive explicit unambiguous import references" multipleAccountReferences
      , testCase "binding scheme and component must match the signed SourceAdapter" bindingAuthority
      , testCase "a direct broker call rechecks the signed route before resolving credentials" brokerDefenseInDepth
      ]

oauthTokenCustody :: Assertion
oauthTokenCustody = do
  let binding = fixtureBinding "personal" fixtureVaultEntry
      tokenSet =
        OAuthTokenSet
          { oauthAccessToken = "SECRET-ACCESS-TOKEN"
          , oauthRefreshToken = Just "SECRET-REFRESH-TOKEN"
          , oauthExpiresAt = addUTCTime 3600 fixtureTime
          , oauthScopes = Set.fromList ["Tasks.Read", "offline_access"]
          }
  encoded <- assertRight (encodeOAuthTokenSet tokenSet)
  access <- assertRight (accessTokenFromVaultSecret fixtureTime binding encoded)
  accessTokenBytes access @?= secretToken
  let expired = tokenSet{oauthExpiresAt = fixtureTime}
  expiredBytes <- assertRight (encodeOAuthTokenSet expired)
  case accessTokenFromVaultSecret fixtureTime binding expiredBytes of
    Left problem -> do
      appErrorCode problem @?= PermissionRequired
      appErrorRetrySafety problem @?= RetryAfterRefresh
    Right _ -> assertFailure "an expired OAuth token set was accepted"

typedIntegrationState :: Assertion
typedIntegrationState = withSystemTempDirectory "lant-provider-profile" $ \root -> do
  let roots = XdgRoots (root </> "config") (root </> "data") (root </> "state") (root </> "runtime")
  paths <- createProfile roots "default" fixtureProfileId >>= assertRight
  let integrations = fixtureIntegrations [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)]
  writeIntegrationsConfig paths integrations >>= assertRight
  (_, _, _, _, loaded) <- loadProfile roots "default" >>= assertRight
  loaded @?= integrations
  let serialized = LazyByteString.toStrict (encode (toJSON loaded))
  assertBool "typed integrations emitted a secret" (not ("SECRET-ACCESS-TOKEN" `ByteString.isInfixOf` serialized))

  let unsafeAccount = (fixtureAccount "account-personal" "Personal"){providerAccountConfiguration = object ["access_token" .= ("forbidden" :: Text)]}
  writeIntegrationsConfig paths (fixtureIntegrations [("personal", unsafeAccount, fixtureBinding "personal" fixtureVaultEntry)]) >>= assertError InvalidInput
  (_, _, _, _, unchanged) <- loadProfile roots "default" >>= assertRight
  unchanged @?= integrations

credentialBoundary :: Assertion
credentialBoundary = do
  (runner, registry) <- connectorRuntime
  resolverCalls <- newIORef (0 :: Int)
  transportCalls <- newIORef []
  token <- assertRight (accessTokenFromBytes secretToken)
  let resolver = AccessTokenResolver $ \binding -> do
        credentialBindingVaultEntry binding @?= fixtureVaultEntry
        modifyIORef' resolverCalls (+ 1)
        pure (Right token)
      transport = graphTransport transportCalls
      integrations = fixtureIntegrations [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)]
  providers <- assertRight (configuredProviderImportSources [microsoftTodoDefinition] integrations registry resolver transport)
  (providerImportReference <$> providers) @?= ["microsoft_todo"]
  let importPort = packRegistryImportPortWithProviders runner registry providers
  imported <- importPortPreflight importPort "microsoft_todo" SourceSnapshot >>= assertRight
  sourcePreflightAdapterId (importReadPreflight imported) @?= "microsoft_todo"
  sourceInputMediaType (importReadInput imported) @?= "application/vnd.little-ant.http-transcript+json"
  assertBool "the access token escaped into source custody" (not (secretToken `ByteString.isInfixOf` sourceInputBytes (importReadInput imported)))
  readIORef resolverCalls >>= (@?= 2)
  requests <- readIORef transportCalls
  length requests @?= 2
  assertBool "Lua supplied an Authorization header" (all (Map.notMember "authorization" . brokerHttpHeaders) requests)

  materialized <- importPortMaterialize importPort "microsoft_todo" SourceSnapshot >>= assertRight
  Map.keys (importMaterializationObjects materialized) @?= ["task:list-1:task-1"]
  assertBool
    "the access token escaped into materialization custody"
    (not (secretToken `ByteString.isInfixOf` sourceInputBytes (importReadInput (importMaterializationRead materialized))))

lockedCredential :: Assertion
lockedCredential = do
  (runner, registry) <- connectorRuntime
  transportCalls <- newIORef []
  let locked =
        AccessTokenResolver $ \_ ->
          pure . Left $
            (appError PermissionRequired "Credentials are locked.")
              { appErrorRecovery = [RecoveryAction "unlock" "Unlock this profile's vault and return to the same import intention." (Just "lant vault unlock")]
              }
      integrations = fixtureIntegrations [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)]
  providers <- assertRight (configuredProviderImportSources [microsoftTodoDefinition] integrations registry locked (graphTransport transportCalls))
  result <- importPortPreflight (packRegistryImportPortWithProviders runner registry providers) "microsoft_todo" SourceSnapshot
  assertError PermissionRequired result
  readIORef transportCalls >>= (@?= [])

multipleAccountReferences :: Assertion
multipleAccountReferences = do
  (_, registry) <- connectorRuntime
  token <- assertRight (accessTokenFromBytes secretToken)
  let resolver = AccessTokenResolver (const (pure (Right token)))
      transport = PackHttpTransport (const (pure (Left (appError ExternalFailure "unused"))))
      workEntry = fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0e1"
      integrations =
        fixtureIntegrations
          [ ("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)
          , ("work", fixtureAccount "account-work" "Work", fixtureBinding "work" workEntry)
          ]
  providers <- assertRight (configuredProviderImportSources [microsoftTodoDefinition] integrations registry resolver transport)
  (providerImportReference <$> providers) @?= ["microsoft_todo@personal", "microsoft_todo@work"]
  let encodedConfigurations = LazyByteString.toStrict . encode . providerImportConfiguration <$> providers
  assertBool "personal account identity was omitted" (any ("account-personal" `ByteString.isInfixOf`) encodedConfigurations)
  assertBool "work account identity was omitted" (any ("account-work" `ByteString.isInfixOf`) encodedConfigurations)

bindingAuthority :: Assertion
bindingAuthority = do
  (_, registry) <- connectorRuntime
  token <- assertRight (accessTokenFromBytes secretToken)
  let resolver = AccessTokenResolver (const (pure (Right token)))
      transport = PackHttpTransport (const (pure (Left (appError ExternalFailure "unused"))))
      wrongScheme = (fixtureBinding "personal" fixtureVaultEntry){credentialBindingScheme = Vault.BearerCredential}
      integrations = fixtureIntegrations [("personal", fixtureAccount "account-personal" "Personal", wrongScheme)]
  assertError PreconditionFailed (configuredProviderImportSources [microsoftTodoDefinition] integrations registry resolver transport)

brokerDefenseInDepth :: Assertion
brokerDefenseInDepth = do
  (_, registry) <- connectorRuntime
  registered <- assertRight (lookupPackComponent "microsoft_todo" registry)
  resolverCalls <- newIORef (0 :: Int)
  token <- assertRight (accessTokenFromBytes secretToken)
  let resolver = AccessTokenResolver $ \_ -> modifyIORef' resolverCalls (+ 1) >> pure (Right token)
      transport = PackHttpTransport (const (pure (Left (appError ExternalFailure "must not run"))))
  broker <- assertRight (credentialBoundPackHttpBroker registered (fixtureBinding "personal" fixtureVaultEntry) resolver transport)
  permission <- case registeredComponent registered of
    ExecutableComponent _ _ permissions -> case permissionHttp permissions of
      [one] -> pure one
      other -> assertFailure ("unexpected HTTP permissions: " <> show other)
    component -> assertFailure ("unexpected connector component: " <> show component)
  result <-
    runPackHttpBroker
      broker
      permission
      (BrokerHttpRequest "GET" "https://example.com/v1.0/me/todo/lists" (Map.singleton "accept" "application/json") Nothing)
  assertError PermissionRequired result
  readIORef resolverCalls >>= (@?= 0)

graphTransport :: IORef [BrokerHttpRequest] -> PackHttpTransport
graphTransport calls = PackHttpTransport $ \credentialed -> do
  accessTokenBytes (credentialedAccessToken credentialed) @?= secretToken
  let request = credentialedRequest credentialed
  modifyIORef' calls (<> [request])
  pure . Right $ case brokerHttpUrl request of
    "https://graph.microsoft.com/v1.0/me/todo/lists" ->
      jsonResponse (object ["value" .= [object ["id" .= ("list-1" :: Text), "displayName" .= ("Tasks" :: Text)]]])
    "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks" ->
      jsonResponse
        ( object
            [ "value"
                .= [ object
                       [ "id" .= ("task-1" :: Text)
                       , "title" .= ("Keep the token private" :: Text)
                       , "status" .= ("notStarted" :: Text)
                       , "hasAttachments" .= False
                       ]
                   ]
            ]
        )
    _ -> BrokerHttpResponse 404 Map.empty (object ["error" .= ("not found" :: Text)])

jsonResponse :: Value -> BrokerHttpResponse
jsonResponse = BrokerHttpResponse 200 (Map.singleton "content-type" "application/json")

fixtureIntegrations :: [(Text, ProviderAccount, CredentialBinding)] -> IntegrationsConfig
fixtureIntegrations entries =
  IntegrationsConfig
    { installedComponents = Map.singleton "org.littleant.official-connectors" connectorPin
    , providerAccounts = Map.fromList [(name, account) | (name, account, _) <- entries]
    , credentialBindings = Map.fromList [(name <> "-credential", binding) | (name, _, binding) <- entries]
    , deliveryBindings = Map.empty
    , trustedPublishers = Set.empty
    }

fixtureAccount :: Text -> Text -> ProviderAccount
fixtureAccount externalId label =
  ProviderAccount
    { providerAccountComponent = "microsoft_todo"
    , providerAccountProvider = "microsoft_todo"
    , providerAccountExternalId = externalId
    , providerAccountLabel = label
    , providerAccountConfiguration =
        object
          [ "include_completed" .= False
          , "allow_incomplete_attachments" .= False
          , "list_ids" .= ([] :: [Text])
          ]
    }

fixtureBinding :: Text -> UUIDv7 -> CredentialBinding
fixtureBinding account vaultEntry =
  CredentialBinding
    { credentialBindingComponent = "microsoft_todo"
    , credentialBindingSlot = "microsoft"
    , credentialBindingAccount = account
    , credentialBindingScheme = Vault.OAuthDeviceAuthorization
    , credentialBindingVaultEntry = vaultEntry
    , credentialBindingPurposes = Set.singleton "source_read"
    }

microsoftTodoDefinition :: ProviderSourceDefinition
microsoftTodoDefinition =
  ProviderSourceDefinition
    { providerDefinitionAdapterId = "microsoft_todo"
    , providerDefinitionNamespace = "microsoft_todo"
    , providerDefinitionDisplayName = "Microsoft To Do"
    , providerDefinitionModes = [SourceSnapshot, SourceSynchronize, SourceMigrate]
    }

connectorRuntime :: IO (PackRunnerClient, PackRegistry)
connectorRuntime = do
  runner <- defaultPackRunnerClient
  archive <- ByteString.readFile (connectorRoot </> "official-connectors.lantpack")
  structural <- assertRight (validatePackArchive archive)
  authenticated <- assertRight (authenticatePack structural)
  scope <- assertRight (mkProfileScope "default")
  let identity = authenticatedPackIdentity authenticated
      grant =
        OfficialReleaseGrant
          { officialGrantPublisher = artifactPublisher identity
          , officialGrantNamePrefix = "org.littleant."
          , officialGrantPublicKey = authenticatedSignerPublicKey authenticated
          , officialGrantKeyFingerprint = authenticatedSignerFingerprint authenticated
          , officialGrantName = artifactName identity
          , officialGrantVersion = artifactVersion identity
          , officialGrantManifestDigest = artifactManifestDigest identity
          , officialGrantArchiveDigest = artifactArchiveDigest identity
          }
      policy =
        PackTrustPolicy
          { trustSupportedLittleAntMajor = 1
          , trustBuiltInArtifacts = Set.empty
          , trustOfficialCatalogSequence = Just 1
          , trustOfficialCatalogExpiresAt = Just (read "2027-01-01 00:00:00 UTC")
          , trustOfficialReleaseGrants = Set.singleton grant
          , trustCommunityPublishers = Set.empty
          , trustRevokedKeyFingerprints = Set.empty
          , trustRevokedArchiveDigests = Set.empty
          }
  install <- assertRight (authorizePackInstall fixtureTime scope policy (Set.singleton "microsoft_todo") authenticated)
  execution <- assertRight (authorizePinnedPackExecution fixtureTime scope policy (installAuthorizedPin install) authenticated)
  registry <- assertRight (buildPackRegistry scope [execution])
  pure (runner, registry)

assertError :: ErrorCode -> Either AppError value -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure ("expected " <> show expected)

assertRight :: (Show problem) => Either problem value -> IO value
assertRight = either (assertFailure . show) pure

fixtureUuid :: Text -> UUIDv7
fixtureUuid = either (error . Text.unpack) id . parseUUIDv7

connectorRoot :: FilePath
connectorRoot = "packs" </> "official-connectors"

secretToken :: ByteString.ByteString
secretToken = "SECRET-ACCESS-TOKEN"

fixtureProfileId, fixtureVaultEntry :: UUIDv7
fixtureProfileId = fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0d1"
fixtureVaultEntry = fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0d2"

fixtureTime :: UTCTime
fixtureTime = read "2026-08-09 12:00:00 UTC"

connectorPin :: PackPin
connectorPin =
  PackPin
    { pinArtifact =
        PackArtifactIdentity
          { artifactPublisher = "org.littleant.project"
          , artifactName = "org.littleant.official-connectors"
          , artifactVersion = "1.0.0"
          , artifactManifestDigest = "ee2c595318a7c0060206c7aa94c77e7f2f0ad10f8a2fc7ea9c02872c4845a065"
          , artifactArchiveDigest = "c6f8b9f46d261710fc8ff16d3ef82071d551b810bd00f0f859ec8764b91913ac"
          }
    , pinSignerFingerprint = "da37479b4b9929fc47ee514f90c6e7e558aef294d1c88873686d7278394090a1"
    , pinTrustOrigin = PinVerifiedOfficial 1
    , pinEnabledComponents = Set.singleton "microsoft_todo"
    }

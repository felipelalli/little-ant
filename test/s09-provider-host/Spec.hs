module Main (main) where

import Data.Aeson (Value, encode, object, toJSON, (.=))
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef (IORef, atomicModifyIORef', modifyIORef', newIORef, readIORef)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime, addUTCTime, utc, utcToZonedTime)
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Id
import LittleAnt.Import
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Format
import LittleAnt.Pack.Http
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Transport
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import LittleAnt.Provider
import LittleAnt.Result
import LittleAnt.Source
import LittleAnt.Store
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
      , testCase "verified provider materialization is accepted as canonical Raw truth" remoteAcceptance
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
          , oauthScopes = Set.fromList ["Tasks.ReadWrite", "offline_access"]
          , oauthAuthorizationFingerprint = fixtureAuthorizationFingerprint
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
      entries = [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)]
  integrations <- assertRight (authorizedIntegrations registry entries)
  providers <- assertRight (configuredProviderImportSources [microsoftTodoDefinition] integrations registry resolver transport)
  (providerImportReference <$> providers) @?= ["microsoft_todo"]
  (providerImportCanonicalReference <$> providers) @?= ["microsoft_todo@personal"]
  assertBool
    "host-only OAuth client ID escaped into Lua configuration"
    (all (not . ("client_id" `ByteString.isInfixOf`) . LazyByteString.toStrict . encode . providerImportConfiguration) providers)
  let importPort = packRegistryImportPortWithProviders runner registry providers
  imported <- importPortPreflight importPort "microsoft_todo" SourceSnapshot >>= assertRight
  importReadSourceReference imported @?= "microsoft_todo@personal"
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

remoteAcceptance :: Assertion
remoteAcceptance = withSystemTempDirectory "lant-provider-acceptance" $ \root -> do
  (runner, registry) <- connectorRuntime
  token <- assertRight (accessTokenFromBytes secretToken)
  transportCalls <- newIORef []
  dispatchObserved <- newIORef False
  let store = StoreConfig (root </> "dataset") 2_000_000 20_000
      observeDurableDispatch = do
        current <- loadDataset store silentProgress >>= assertRight
        let dispatching = filter ((== EffectDispatching) . externalEffectStatus) (Map.elems (stateExternalEffects (loadedState current)))
        length dispatching @?= 1
        modifyIORef' dispatchObserved (const True)
  integrations <-
    assertRight (authorizedIntegrations registry [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)])
  providers <-
    assertRight
      ( configuredProviderImportSources
          [microsoftTodoDefinition]
          integrations
          registry
          (AccessTokenResolver (const (pure (Right token))))
          (graphTransportWithProbe transportCalls observeDurableDispatch)
      )
  counter <- newIORef (9000 :: Int)
  let importPort = packRegistryImportPortWithProviders runner registry providers
      environment =
        AppEnv
          store
          (Actor "human" "test")
          (pure fixtureTime)
          (pure (utcToZonedTime utc fixtureTime))
          (allocateFixtureUUID counter)
          emptyExportPort
          importPort
          Nothing
          Nothing
          Nothing
          Nothing
  previewResult <- runAppCommand environment False silentProgress (ImportCommand "microsoft_todo" SourceMigrate True) >>= assertRight
  preview <- interactionOf previewResult
  case envelopeOpportunity preview of
    ImportPreflightOpportunity "microsoft_todo@personal" preflight True -> do
      sourcePreflightAdapterId preflight @?= "microsoft_todo"
      observedCleanupSupported (sourcePreflightObservation preflight) @?= True
    other -> assertFailure ("unexpected provider import preview: " <> show other)
  acceptedResult <- runAppCommand environment False silentProgress (RespondCommand (response preview "import.accept")) >>= assertRight
  accepted <- interactionOf acceptedResult
  importedRaw <- case envelopeOpportunity accepted of
    ImportResultOpportunity _ [identity] [] True -> pure identity
    other -> assertFailure ("unexpected provider import result: " <> show other) >> fail "unreachable"
  dataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let state = loadedState dataset
      profile = only "ImportProfile" (Map.elems (stateImportProfiles state))
      invocation = only "ImportInvocation" (Map.elems (stateImportInvocations state))
      binding = only "SourceBinding" (Map.elems (stateSourceBindings state))
      revisionId = stateCurrentRawRevisions state Map.! importedRaw
      revision = stateRawContentRevisions state Map.! revisionId
  importProfileInputReference profile @?= "microsoft_todo@personal"
  importProfileMode profile @?= SourceMigrate
  importInvocationComponentId invocation @?= "microsoft_todo"
  importObjectExternalIdentity (only "ImportObjectMapping" (importInvocationMappings invocation)) @?= "task:list-1:task-1"
  sourceBindingExternalIdentity binding @?= Just "task:list-1:task-1"
  sourceBindingLocator binding @?= "microsoft-todo://account-personal/lists/list-1/tasks/task-1"
  case rawContentRevisionContent revision of
    RawStructuredContent "microsoft-graph/todo-task@1" body -> do
      assertBool "the accepted Raw omitted provider identity" ("account-personal" `Text.isInfixOf` body)
      assertBool "the accepted Raw omitted the complete task body" ("Keep the token private" `Text.isInfixOf` body)
    other -> assertFailure ("provider material was not preserved as structured Raw truth: " <> show other)
  let acceptedEventCount = loadedEventCount dataset
  repeatedPreview <- runAppCommand environment False silentProgress (ImportCommand "microsoft_todo" SourceMigrate True) >>= assertRight >>= interactionOf
  repeatedResult <- runAppCommand environment False silentProgress (RespondCommand (response repeatedPreview "import.accept")) >>= assertRight
  repeated <- interactionOf repeatedResult
  case envelopeOpportunity repeated of
    ImportResultOpportunity _ [] [identity] True -> identity @?= importedRaw
    other -> assertFailure ("provider retry was not idempotent: " <> show other)
  resultMutationCommandId repeatedResult @?= Nothing
  repeatedDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  loadedEventCount repeatedDataset @?= acceptedEventCount

  cleanupPreview <- runAppCommand environment False silentProgress (RespondCommand (response repeated "import.cleanup")) >>= assertRight >>= interactionOf
  cleanupEffect <- case envelopeOpportunity cleanupPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected cleanup approval: " <> show other) >> fail "unreachable"
  proposedDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState proposedDataset) Map.! cleanupEffect) @?= EffectProposed
  deleteCallsBeforeApproval <- filter ((== "DELETE") . brokerHttpMethod) <$> readIORef transportCalls
  deleteCallsBeforeApproval @?= []

  cleanupResult <- runAppCommand environment False silentProgress (RespondCommand (response cleanupPreview "effect.approve")) >>= assertRight >>= interactionOf
  case envelopeOpportunity cleanupResult of
    SourceCleanupResultOpportunity [identity] -> identity @?= cleanupEffect
    other -> assertFailure ("unexpected cleanup result: " <> show other)
  finalDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let finalState = loadedState finalDataset
      finalEffect = stateExternalEffects finalState Map.! cleanupEffect
      finalProfile = only "retired ImportProfile" (Map.elems (stateImportProfiles finalState))
  externalEffectStatus finalEffect @?= EffectSucceeded
  Map.size (stateExternalEffectApprovalGrants finalState) @?= 1
  Map.size (stateExternalEffectReceipts finalState) @?= 1
  importProfileLifecycle finalProfile @?= ImportProfileRetired
  assertBool "verified local Raw disappeared after source cleanup" (Map.member importedRaw (stateRaws finalState))
  readIORef dispatchObserved >>= (@?= True)
  deleteCalls <- filter ((== "DELETE") . brokerHttpMethod) <$> readIORef transportCalls
  case deleteCalls of
    [request] -> brokerHttpUrl request @?= "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1"
    other -> assertFailure ("unexpected cleanup DELETE calls: " <> show other)

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
      entries = [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)]
  integrations <- assertRight (authorizedIntegrations registry entries)
  providers <- assertRight (configuredProviderImportSources [microsoftTodoDefinition] integrations registry locked (graphTransport transportCalls))
  result <- importPortPreflight (packRegistryImportPortWithProviders runner registry providers) "microsoft_todo" SourceSnapshot
  assertError PermissionRequired result
  readIORef transportCalls >>= (@?= [])

multipleAccountReferences :: Assertion
multipleAccountReferences = do
  (runner, registry) <- connectorRuntime
  token <- assertRight (accessTokenFromBytes secretToken)
  let resolver = AccessTokenResolver (const (pure (Right token)))
      transport = PackHttpTransport (const (pure (Left (appError ExternalFailure "unused"))))
      workEntry = fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0e1"
      entries =
        [ ("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)
        , ("work", fixtureAccount "account-work" "Work", fixtureBinding "work" workEntry)
        ]
  integrations <- assertRight (authorizedIntegrations registry entries)
  providers <- assertRight (configuredProviderImportSources [microsoftTodoDefinition] integrations registry resolver transport)
  (providerImportReference <$> providers) @?= ["microsoft_todo@personal", "microsoft_todo@work"]
  (providerImportCanonicalReference <$> providers) @?= ["microsoft_todo@personal", "microsoft_todo@work"]
  let catalog = importPortCatalog (packRegistryImportPortWithProviders runner registry providers)
      providerCatalog = filter (null . importSourceExtensions) catalog
  (importSourceId <$> providerCatalog) @?= ["microsoft_todo@personal", "microsoft_todo@work"]
  (importSourceDisplayName <$> providerCatalog) @?= ["Microsoft To Do · Personal", "Microsoft To Do · Work"]
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
graphTransport calls = graphTransportWithProbe calls (pure ())

graphTransportWithProbe :: IORef [BrokerHttpRequest] -> IO () -> PackHttpTransport
graphTransportWithProbe calls onDelete = PackHttpTransport $ \credentialed -> do
  accessTokenBytes (credentialedAccessToken credentialed) @?= secretToken
  let request = credentialedRequest credentialed
  modifyIORef' calls (<> [request])
  case (brokerHttpMethod request, brokerHttpUrl request) of
    ("DELETE", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1") -> onDelete >> pure (Right (BrokerHttpResponse 204 Map.empty (object [])))
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists") ->
      pure . Right $ jsonResponse (object ["value" .= [object ["id" .= ("list-1" :: Text), "displayName" .= ("Tasks" :: Text)]]])
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks") ->
      pure . Right $
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
    _ -> pure . Right $ BrokerHttpResponse 404 Map.empty (object ["error" .= ("not found" :: Text)])

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
          , "client_id" .= ("11111111-1111-1111-1111-111111111111" :: Text)
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
    , credentialBindingAuthorizationFingerprint = Just fixtureAuthorizationFingerprint
    , credentialBindingPurposes = Set.singleton "source_read"
    }

fixtureAuthorizationFingerprint :: Text
fixtureAuthorizationFingerprint = Text.replicate 64 "0"

authorizedIntegrations :: PackRegistry -> [(Text, ProviderAccount, CredentialBinding)] -> Either AppError IntegrationsConfig
authorizedIntegrations registry entries = do
  registered <- lookupPackComponent "microsoft_todo" registry
  authorized <- traverse (authorize registered) entries
  pure (fixtureIntegrations authorized)
 where
  authorize registered (name, account, binding) = do
    client <- resolveOAuthDeviceClient registered account (credentialBindingSlot binding)
    pure (name, account, binding{credentialBindingAuthorizationFingerprint = Just (oauthDeviceAuthorizationFingerprint client)})

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
          , trustOfficialPinAuthorizations = Set.singleton (officialPinAuthorizationFromGrant 1 grant)
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

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other) >> fail "unreachable"

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

allocateFixtureUUID :: IORef Int -> IO UUIDv7
allocateFixtureUUID counter =
  atomicModifyIORef' counter $ \seed -> (seed + 1, generated seed)
 where
  generated seed =
    either (error . show) id $
      uuidV7FromEntropy
        (0x019f98760000 + fromIntegral seed)
        (ByteString.replicate 10 (fromIntegral (seed `mod` 251 + 1)))

only :: String -> [value] -> value
only label = \case
  [value] -> value
  values -> error ("expected one " <> label <> ", got " <> show (length values))

silentProgress :: Integer -> IO ()
silentProgress _ = pure ()

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
          , artifactManifestDigest = "27bf699a7df346613b31132675aca5f6e510e2bb9e16436ac679cbb11702a4d7"
          , artifactArchiveDigest = "3e708db5a1861dfda1f008588257faa7339cc8e11b885d29855457a7330fd192"
          }
    , pinSignerFingerprint = "b4be8b7bd0a60ee3d19c70e26ba5b40fd982cd857241b278f7e26cd91d933c51"
    , pinTrustOrigin = PinVerifiedOfficial 2
    , pinEnabledComponents = Set.singleton "microsoft_todo"
    }

module Main (main) where

import Control.Monad (replicateM)
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
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Foundation
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
      , testCase "partial cleanup retries only the unchanged failed item" partialCleanupRecovery
      , testCase "an unknown cleanup outcome is verified read-only before completion" unknownCleanupVerification
      , testCase "a restarted dispatch is surfaced and verified without another delete" interruptedCleanupRecovery
      , testCase "cleanup authority drift fails before provider deletion" cleanupAuthorityDrift
      , testCase "rejecting the exact cleanup set retires the migration without deletion" cleanupRejection
      , testCase "unknowable provider truth requires risk consent and a new exact approval" unknownCleanupRiskConsent
      , testCase "an empty source container needs its own check and approval" emptyContainerCleanup
      , testCase "a nonempty source container never becomes a cleanup effect" nonemptyContainerRefusal
      , testCase "a container that gains an item fails before deletion" containerRaceRefusal
      , testCase "an unknown container deletion is reconciled without another delete" unknownContainerCleanup
      , testCase "locked credentials stop before provider transport and retain a typed non-provider failure" lockedCredential
      , testCase "remote container selection is explicit and closed by provider policy" containerSelectionBoundary
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
  imported <- importPortPreflight importPort "microsoft_todo" SourceSnapshot Set.empty >>= assertRight
  importReadSourceReference imported @?= "microsoft_todo@personal"
  sourcePreflightAdapterId (importReadPreflight imported) @?= "microsoft_todo"
  sourceInputMediaType (importReadInput imported) @?= "application/vnd.little-ant.http-transcript+json"
  assertBool "the access token escaped into source custody" (not (secretToken `ByteString.isInfixOf` sourceInputBytes (importReadInput imported)))
  readIORef resolverCalls >>= (@?= 2)
  requests <- readIORef transportCalls
  length requests @?= 2
  assertBool "Lua supplied an Authorization header" (all (Map.notMember "authorization" . brokerHttpHeaders) requests)

  materialized <- importPortMaterialize importPort "microsoft_todo" SourceSnapshot Set.empty >>= assertRight
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
  previewResult <- runAppCommand environment False silentProgress (ImportCommand "microsoft_todo" SourceMigrate [] True) >>= assertRight
  preview <- interactionOf previewResult
  case envelopeOpportunity preview of
    ImportPreflightOpportunity "microsoft_todo@personal" selectedContainers preflight True -> do
      selectedContainers @?= Set.empty
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
  repeatedPreview <- runAppCommand environment False silentProgress (ImportCommand "microsoft_todo" SourceMigrate [] True) >>= assertRight >>= interactionOf
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

partialCleanupRecovery :: Assertion
partialCleanupRecovery = withSystemTempDirectory "lant-provider-partial-cleanup" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  secondAttempts <- newIORef (0 :: Int)
  environment <- providerEnvironment root 11000 runner registry (partialCleanupTransport calls secondAttempts)
  cleanupPreview <- prepareCleanup environment
  cleanupEffects <- case envelopeOpportunity cleanupPreview of
    ExternalEffectApprovalScreenOpportunity identities -> do
      length identities @?= 2
      pure identities
    other -> assertFailure ("unexpected partial-cleanup approval: " <> show other) >> fail "unreachable"

  partialResult <- runAppCommand environment False silentProgress (RespondCommand (response cleanupPreview "effect.approve")) >>= assertRight >>= interactionOf
  envelopeOpportunity partialResult @?= SourceCleanupResultOpportunity cleanupEffects
  assertBool "the partial result omitted safe retry" (any ((== "effect.cleanup.retry") . actionId) (envelopeActions partialResult))
  partialDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let partialState = loadedState partialDataset
      partialStatuses = externalEffectStatus <$> Map.elems (stateExternalEffects partialState)
      profile = only "active partial-cleanup profile" (Map.elems (stateImportProfiles partialState))
  length (filter (== EffectSucceeded) partialStatuses) @?= 1
  length (filter (== EffectFailedRetryable) partialStatuses) @?= 1
  importProfileLifecycle profile @?= ImportProfileActive

  completedResult <- runAppCommand environment False silentProgress (RespondCommand (response partialResult "effect.cleanup.retry")) >>= assertRight >>= interactionOf
  envelopeOpportunity completedResult @?= SourceCleanupResultOpportunity cleanupEffects
  completedDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let completedState = loadedState completedDataset
  assertBool "a cleanup effect did not complete after its safe retry" (all ((== EffectSucceeded) . externalEffectStatus) (Map.elems (stateExternalEffects completedState)))
  importProfileLifecycle (only "retired partial-cleanup profile" (Map.elems (stateImportProfiles completedState))) @?= ImportProfileRetired
  requests <- readIORef calls
  let deletesFor taskId =
        length
          [ ()
          | request <- requests
          , brokerHttpMethod request == "DELETE"
          , ("/tasks/" <> taskId) `Text.isSuffixOf` brokerHttpUrl request
          ]
  deletesFor "task-1" @?= 1
  deletesFor "task-2" @?= 2

unknownCleanupVerification :: Assertion
unknownCleanupVerification = withSystemTempDirectory "lant-provider-unknown-cleanup" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  environment <- providerEnvironment root 12000 runner registry (unknownCleanupTransport calls)
  cleanupPreview <- prepareCleanup environment
  [cleanupEffect] <- case envelopeOpportunity cleanupPreview of
    ExternalEffectApprovalScreenOpportunity identities -> pure identities
    other -> assertFailure ("unexpected unknown-cleanup approval: " <> show other) >> fail "unreachable"
  unknownResult <- runAppCommand environment False silentProgress (RespondCommand (response cleanupPreview "effect.approve")) >>= assertRight >>= interactionOf
  envelopeOpportunity unknownResult @?= SourceCleanupResultOpportunity [cleanupEffect]
  unknownDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState unknownDataset) Map.! cleanupEffect) @?= EffectOutcomeUnknown
  assertBool "the unknown result omitted read-only verification" (any ((== "effect.cleanup.verify") . actionId) (envelopeActions unknownResult))

  verifiedResult <- runAppCommand environment False silentProgress (RespondCommand (response unknownResult "effect.cleanup.verify")) >>= assertRight >>= interactionOf
  envelopeOpportunity verifiedResult @?= SourceCleanupResultOpportunity [cleanupEffect]
  verifiedDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let verifiedState = loadedState verifiedDataset
  externalEffectStatus (stateExternalEffects verifiedState Map.! cleanupEffect) @?= EffectSucceeded
  importProfileLifecycle (only "retired verified profile" (Map.elems (stateImportProfiles verifiedState))) @?= ImportProfileRetired
  Map.size (stateExternalEffectReceipts verifiedState) @?= 2
  requests <- readIORef calls
  length (filter ((== "DELETE") . brokerHttpMethod) requests) @?= 1
  length
    [ ()
    | request <- requests
    , brokerHttpMethod request == "GET"
    , "/tasks/task-1" `Text.isSuffixOf` brokerHttpUrl request
    ]
    @?= 1

interruptedCleanupRecovery :: Assertion
interruptedCleanupRecovery = withSystemTempDirectory "lant-provider-interrupted-cleanup" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  environment <- providerEnvironment root 13000 runner registry (unknownCleanupTransport calls)
  cleanupPreview <- prepareCleanup environment
  cleanupEffect <- case envelopeOpportunity cleanupPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected interrupted-cleanup approval: " <> show other) >> fail "unreachable"
  proposed <- loadDataset (appStore environment) silentProgress >>= assertRight
  approvalFacts <- factsFor environment (loadedCursor proposed) 3
  approval <- assertRight (decideApproveExternalEffects (loadedState proposed) (appActor environment) [cleanupEffect] approvalFacts)
  approved <- appendCommand (appStore environment) (loadedCursor proposed) (mutationDecisionEvents approval) >>= assertRight
  dispatchFacts <- factsFor environment (loadedCursor approved) 2
  dispatch <- assertRight (decideStartExternalEffectDispatch (loadedState approved) (appActor environment) cleanupEffect dispatchFacts)
  dispatching <- appendCommand (appStore environment) (loadedCursor approved) (mutationDecisionEvents dispatch) >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState dispatching) Map.! cleanupEffect) @?= EffectDispatching

  recovery <- nextAfterRawTriage environment
  envelopeOpportunity recovery @?= SourceCleanupResultOpportunity [cleanupEffect]
  assertBool "the interrupted result omitted its explicit check" (any ((== "effect.cleanup.check") . actionId) (envelopeActions recovery))
  resolved <- runAppCommand environment False silentProgress (RespondCommand (response recovery "effect.cleanup.check")) >>= assertRight >>= interactionOf
  envelopeOpportunity resolved @?= SourceCleanupResultOpportunity [cleanupEffect]
  finalDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let finalState = loadedState finalDataset
  externalEffectStatus (stateExternalEffects finalState Map.! cleanupEffect) @?= EffectSucceeded
  Map.size (stateExternalEffectReceipts finalState) @?= 2
  requests <- readIORef calls
  filter ((== "DELETE") . brokerHttpMethod) requests @?= []
  length
    [ ()
    | request <- requests
    , brokerHttpMethod request == "GET"
    , "/tasks/task-1" `Text.isSuffixOf` brokerHttpUrl request
    ]
    @?= 1

cleanupAuthorityDrift :: Assertion
cleanupAuthorityDrift = withSystemTempDirectory "lant-provider-cleanup-drift" $ \root -> do
  (runner, registry) <- connectorRuntime
  originalCalls <- newIORef []
  original <- providerEnvironment root 14000 runner registry (graphTransport originalCalls)
  cleanupPreview <- prepareCleanup original
  cleanupEffect <- case envelopeOpportunity cleanupPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected authority-drift approval: " <> show other) >> fail "unreachable"

  token <- assertRight (accessTokenFromBytes secretToken)
  integrations <-
    assertRight (authorizedIntegrations registry [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)])
  let currentBinding = credentialBindings integrations Map.! "personal-credential"
      renamedIntegrations = integrations{credentialBindings = Map.singleton "replacement-credential" currentBinding}
  reboundProviders <-
    assertRight
      ( configuredProviderImportSources
          [microsoftTodoDefinition]
          renamedIntegrations
          registry
          (AccessTokenResolver (const (pure (Right token))))
          (graphTransport originalCalls)
      )
  let rebound = original{appImportPort = packRegistryImportPortWithProviders runner registry reboundProviders}
  deleteCountBefore <- length . filter ((== "DELETE") . brokerHttpMethod) <$> readIORef originalCalls
  result <- runAppCommand rebound False silentProgress (RespondCommand (response cleanupPreview "effect.approve")) >>= assertRight >>= interactionOf
  envelopeOpportunity result @?= SourceCleanupResultOpportunity [cleanupEffect]
  finalDataset <- loadDataset (appStore rebound) silentProgress >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState finalDataset) Map.! cleanupEffect) @?= EffectFailedTerminal
  deleteCountAfter <- length . filter ((== "DELETE") . brokerHttpMethod) <$> readIORef originalCalls
  deleteCountAfter @?= deleteCountBefore

cleanupRejection :: Assertion
cleanupRejection = withSystemTempDirectory "lant-provider-cleanup-rejection" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  environment <- providerEnvironment root 15000 runner registry (graphTransport calls)
  cleanupPreview <- prepareCleanup environment
  result <- runAppCommand environment False silentProgress (RespondCommand (response cleanupPreview "effect.reject")) >>= assertRight >>= interactionOf
  case envelopeOpportunity result of
    SourceCleanupResultOpportunity [_] -> pure ()
    other -> assertFailure ("unexpected cleanup rejection result: " <> show other)
  dataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let currentState = loadedState dataset
  assertBool "a rejected cleanup effect remained nonterminal" (all ((== EffectRejected) . externalEffectStatus) (Map.elems (stateExternalEffects currentState)))
  importProfileLifecycle (only "retired rejected migration" (Map.elems (stateImportProfiles currentState))) @?= ImportProfileRetired
  requests <- readIORef calls
  filter ((== "DELETE") . brokerHttpMethod) requests @?= []

unknownCleanupRiskConsent :: Assertion
unknownCleanupRiskConsent = withSystemTempDirectory "lant-provider-cleanup-risk" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  deleteAttempts <- newIORef (0 :: Int)
  environment <- providerEnvironment root 16000 runner registry (unknownThenRetryTransport calls deleteAttempts)
  cleanupPreview <- prepareCleanup environment
  cleanupEffect <- case envelopeOpportunity cleanupPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected cleanup-risk approval: " <> show other) >> fail "unreachable"
  unknown <- runAppCommand environment False silentProgress (RespondCommand (response cleanupPreview "effect.approve")) >>= assertRight >>= interactionOf
  checked <- runAppCommand environment False silentProgress (RespondCommand (response unknown "effect.cleanup.verify")) >>= assertRight >>= interactionOf
  checkedDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState checkedDataset) Map.! cleanupEffect) @?= EffectOutcomeUnknown

  risk <- runAppCommand environment False silentProgress (RespondCommand (response checked "effect.cleanup.retry-risk")) >>= assertRight >>= interactionOf
  envelopeOpportunity risk @?= SourceCleanupRiskOpportunity [cleanupEffect]
  revisedApproval <- runAppCommand environment False silentProgress (RespondCommand (response risk "effect.cleanup.risk.accept")) >>= assertRight >>= interactionOf
  envelopeOpportunity revisedApproval @?= ExternalEffectApprovalScreenOpportunity [cleanupEffect]
  revisedDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let revisedEffect = stateExternalEffects (loadedState revisedDataset) Map.! cleanupEffect
  externalEffectRevision revisedEffect @?= 2
  externalEffectStatus revisedEffect @?= EffectProposed
  externalEffectApprovalGrant revisedEffect @?= Nothing

  completed <- runAppCommand environment False silentProgress (RespondCommand (response revisedApproval "effect.approve")) >>= assertRight >>= interactionOf
  envelopeOpportunity completed @?= SourceCleanupResultOpportunity [cleanupEffect]
  finalDataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let finalState = loadedState finalDataset
  externalEffectStatus (stateExternalEffects finalState Map.! cleanupEffect) @?= EffectSucceeded
  Map.size (stateExternalEffectApprovalGrants finalState) @?= 2
  requests <- readIORef calls
  length (filter ((== "DELETE") . brokerHttpMethod) requests) @?= 2

emptyContainerCleanup :: Assertion
emptyContainerCleanup = withSystemTempDirectory "lant-provider-empty-container" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  itemDeleted <- newIORef False
  listDeleted <- newIORef False
  postDeleteReads <- newIORef (0 :: Int)
  environment <- providerEnvironment root 17000 runner registry (containerCleanupTransport ContainerStaysEmpty calls itemDeleted listDeleted postDeleteReads)
  (itemEffect, itemResult) <- completeItemCleanup environment
  assertBool "completed item cleanup did not offer an empty-container check" (any ((== "effect.cleanup.check-containers") . actionId) (envelopeActions itemResult))

  containerPreview <- runAppCommand environment False silentProgress (RespondCommand (response itemResult "effect.cleanup.check-containers")) >>= assertRight >>= interactionOf
  containerEffect <- case envelopeOpportunity containerPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected container cleanup approval: " <> show other) >> fail "unreachable"
  beforeApproval <- readIORef calls
  assertBool "the source list was deleted before its separate approval" (not (any isContainerDelete beforeApproval))

  result <- runAppCommand environment False silentProgress (RespondCommand (response containerPreview "effect.approve")) >>= assertRight >>= interactionOf
  envelopeOpportunity result @?= SourceCleanupResultOpportunity [containerEffect]
  dataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  let currentState = loadedState dataset
  externalEffectStatus (stateExternalEffects currentState Map.! itemEffect) @?= EffectSucceeded
  externalEffectStatus (stateExternalEffects currentState Map.! containerEffect) @?= EffectSucceeded
  Map.size (stateExternalEffectApprovalGrants currentState) @?= 2
  Map.size (stateExternalEffectReceipts currentState) @?= 2
  Map.size (stateRaws currentState) @?= 1
  requests <- readIORef calls
  length (filter isContainerDelete requests) @?= 1
  reads <- readIORef postDeleteReads
  reads @?= 2

nonemptyContainerRefusal :: Assertion
nonemptyContainerRefusal = withSystemTempDirectory "lant-provider-nonempty-container" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  itemDeleted <- newIORef False
  listDeleted <- newIORef False
  postDeleteReads <- newIORef (0 :: Int)
  environment <- providerEnvironment root 18000 runner registry (containerCleanupTransport ContainerHasNewItem calls itemDeleted listDeleted postDeleteReads)
  (_, itemResult) <- completeItemCleanup environment
  checked <- runAppCommand environment False silentProgress (RespondCommand (response itemResult "effect.cleanup.check-containers")) >>= assertRight >>= interactionOf
  envelopeOpportunity checked @?= envelopeOpportunity itemResult
  assertBool "the nonempty result omitted its truthful explanation" (any (Text.isInfixOf "still contains 1 item(s)") (contentBody (envelopeContent checked)))
  dataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  Map.size (stateExternalEffects (loadedState dataset)) @?= 1
  requests <- readIORef calls
  filter isContainerDelete requests @?= []

containerRaceRefusal :: Assertion
containerRaceRefusal = withSystemTempDirectory "lant-provider-container-race" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  itemDeleted <- newIORef False
  listDeleted <- newIORef False
  postDeleteReads <- newIORef (0 :: Int)
  environment <- providerEnvironment root 19000 runner registry (containerCleanupTransport ContainerChangesAfterInspection calls itemDeleted listDeleted postDeleteReads)
  (_, itemResult) <- completeItemCleanup environment
  containerPreview <- runAppCommand environment False silentProgress (RespondCommand (response itemResult "effect.cleanup.check-containers")) >>= assertRight >>= interactionOf
  containerEffect <- case envelopeOpportunity containerPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected raced-container approval: " <> show other) >> fail "unreachable"
  result <- runAppCommand environment False silentProgress (RespondCommand (response containerPreview "effect.approve")) >>= assertRight >>= interactionOf
  envelopeOpportunity result @?= SourceCleanupResultOpportunity [containerEffect]
  assertBool "a terminal container race omitted fresh reinspection" (any ((== "effect.cleanup.reinspect-container") . actionId) (envelopeActions result))
  dataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState dataset) Map.! containerEffect) @?= EffectFailedTerminal
  requests <- readIORef calls
  filter isContainerDelete requests @?= []

unknownContainerCleanup :: Assertion
unknownContainerCleanup = withSystemTempDirectory "lant-provider-unknown-container" $ \root -> do
  (runner, registry) <- connectorRuntime
  calls <- newIORef []
  itemDeleted <- newIORef False
  listDeleted <- newIORef False
  postDeleteReads <- newIORef (0 :: Int)
  environment <- providerEnvironment root 20000 runner registry (containerCleanupTransport ContainerDeleteResponseLost calls itemDeleted listDeleted postDeleteReads)
  (_, itemResult) <- completeItemCleanup environment
  containerPreview <- runAppCommand environment False silentProgress (RespondCommand (response itemResult "effect.cleanup.check-containers")) >>= assertRight >>= interactionOf
  containerEffect <- case envelopeOpportunity containerPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected unknown-container approval: " <> show other) >> fail "unreachable"
  unknown <- runAppCommand environment False silentProgress (RespondCommand (response containerPreview "effect.approve")) >>= assertRight >>= interactionOf
  datasetUnknown <- loadDataset (appStore environment) silentProgress >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState datasetUnknown) Map.! containerEffect) @?= EffectOutcomeUnknown
  verified <- runAppCommand environment False silentProgress (RespondCommand (response unknown "effect.cleanup.verify")) >>= assertRight >>= interactionOf
  envelopeOpportunity verified @?= SourceCleanupResultOpportunity [containerEffect]
  dataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  externalEffectStatus (stateExternalEffects (loadedState dataset) Map.! containerEffect) @?= EffectSucceeded
  requests <- readIORef calls
  length (filter isContainerDelete requests) @?= 1

completeItemCleanup :: AppEnv -> IO (UUIDv7, InteractionEnvelope)
completeItemCleanup environment = do
  cleanupPreview <- prepareCleanup environment
  itemEffect <- case envelopeOpportunity cleanupPreview of
    ExternalEffectApprovalScreenOpportunity [identity] -> pure identity
    other -> assertFailure ("unexpected item cleanup approval: " <> show other) >> fail "unreachable"
  result <- runAppCommand environment False silentProgress (RespondCommand (response cleanupPreview "effect.approve")) >>= assertRight >>= interactionOf
  envelopeOpportunity result @?= SourceCleanupResultOpportunity [itemEffect]
  pure (itemEffect, result)

isContainerDelete :: BrokerHttpRequest -> Bool
isContainerDelete request =
  brokerHttpMethod request == "DELETE"
    && brokerHttpUrl request == "https://graph.microsoft.com/v1.0/me/todo/lists/list-1"

nextAfterRawTriage :: AppEnv -> IO InteractionEnvelope
nextAfterRawTriage environment = do
  dataset <- loadDataset (appStore environment) silentProgress >>= assertRight
  seek (Map.size (stateRaws (loadedState dataset)) + 1)
 where
  seek remaining
    | remaining <= 0 = assertFailure "source cleanup recovery did not surface after every Raw triage was settled" >> fail "unreachable"
    | otherwise = do
        next <- runAppCommand environment False silentProgress NextCommand >>= assertRight >>= interactionOf
        inspect remaining next
  inspect remaining next =
    case envelopeOpportunity next of
      RawTriageOpportunity{} -> do
        destination <- runAppCommand environment False silentProgress (RespondCommand (response next "raw.choose-destination")) >>= assertRight >>= interactionOf
        case envelopeOpportunity destination of
          RawDestinationOpportunity{} -> pure ()
          other -> assertFailure ("unexpected Raw destination screen: " <> show other)
        settled <- runAppCommand environment False silentProgress (RespondCommand (response destination "raw.keep-standalone")) >>= assertRight >>= interactionOf
        inspect (remaining - 1) settled
      StandaloneResultOpportunity{} -> do
        advanced <- runAppCommand environment False silentProgress (RespondCommand (response next "next")) >>= assertRight >>= interactionOf
        inspect remaining advanced
      _ -> pure next

factsFor :: AppEnv -> DatasetCursor -> Int -> IO RuntimeFacts
factsFor environment cursor count = do
  identities <- replicateM count (appAllocateUUID environment)
  pure
    RuntimeFacts
      { runtimeNow = fixtureTime
      , runtimeUUIDs = UUIDAllocation . renderUUIDv7 <$> identities
      , runtimeRandomBlocks = Map.empty
      , runtimeFilesystem = FilesystemFacts True True (Just (renderCursor cursor))
      , runtimeTerminal = TerminalCapabilities False False False 80 24 False
      , runtimeExternalFacts = []
      }

providerEnvironment :: FilePath -> Int -> PackRunnerClient -> PackRegistry -> PackHttpTransport -> IO AppEnv
providerEnvironment root seed runner registry transport = do
  token <- assertRight (accessTokenFromBytes secretToken)
  integrations <-
    assertRight (authorizedIntegrations registry [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)])
  providers <-
    assertRight
      ( configuredProviderImportSources
          [microsoftTodoDefinition]
          integrations
          registry
          (AccessTokenResolver (const (pure (Right token))))
          transport
      )
  counter <- newIORef seed
  pure
    AppEnv
      { appStore = StoreConfig (root </> "dataset") 2_000_000 20_000
      , appActor = Actor "human" "test"
      , appNow = pure fixtureTime
      , appZonedNow = pure (utcToZonedTime utc fixtureTime)
      , appAllocateUUID = allocateFixtureUUID counter
      , appExportPort = emptyExportPort
      , appImportPort = packRegistryImportPortWithProviders runner registry providers
      , appImportPortProblem = Nothing
      , appPackRegistryProblem = Nothing
      , appOfficialPackRemote = Nothing
      , appProviderConnectionRuntime = Nothing
      }

prepareCleanup :: AppEnv -> IO InteractionEnvelope
prepareCleanup environment = do
  preview <- runAppCommand environment False silentProgress (ImportCommand "microsoft_todo" SourceMigrate [] True) >>= assertRight >>= interactionOf
  imported <- runAppCommand environment False silentProgress (RespondCommand (response preview "import.accept")) >>= assertRight >>= interactionOf
  runAppCommand environment False silentProgress (RespondCommand (response imported "import.cleanup")) >>= assertRight >>= interactionOf

partialCleanupTransport :: IORef [BrokerHttpRequest] -> IORef Int -> PackHttpTransport
partialCleanupTransport calls secondAttempts = PackHttpTransport $ \credentialed -> do
  accessTokenBytes (credentialedAccessToken credentialed) @?= secretToken
  let request = credentialedRequest credentialed
  modifyIORef' calls (<> [request])
  case (brokerHttpMethod request, brokerHttpUrl request) of
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists") -> pure (Right oneListResponse)
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks") -> pure (Right twoTaskResponse)
    ("DELETE", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1") -> pure (Right (BrokerHttpResponse 204 Map.empty (object [])))
    ("DELETE", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-2") -> do
      attempt <- atomicModifyIORef' secondAttempts (\count -> (count + 1, count))
      pure . Right $ if attempt == 0 then BrokerHttpResponse 503 Map.empty (object []) else BrokerHttpResponse 204 Map.empty (object [])
    _ -> pure (Right (BrokerHttpResponse 404 Map.empty (object [])))

unknownCleanupTransport :: IORef [BrokerHttpRequest] -> PackHttpTransport
unknownCleanupTransport calls = PackHttpTransport $ \credentialed -> do
  accessTokenBytes (credentialedAccessToken credentialed) @?= secretToken
  let request = credentialedRequest credentialed
  modifyIORef' calls (<> [request])
  case (brokerHttpMethod request, brokerHttpUrl request) of
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists") -> pure (Right oneListResponse)
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks") -> pure (Right oneTaskResponse)
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1") -> pure (Right (BrokerHttpResponse 404 Map.empty (object [])))
    ("DELETE", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1") -> pure (Left (appError ExternalFailure "The provider response was lost."))
    _ -> pure (Right (BrokerHttpResponse 404 Map.empty (object [])))

unknownThenRetryTransport :: IORef [BrokerHttpRequest] -> IORef Int -> PackHttpTransport
unknownThenRetryTransport calls deleteAttempts = PackHttpTransport $ \credentialed -> do
  accessTokenBytes (credentialedAccessToken credentialed) @?= secretToken
  let request = credentialedRequest credentialed
  modifyIORef' calls (<> [request])
  case (brokerHttpMethod request, brokerHttpUrl request) of
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists") -> pure (Right oneListResponse)
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks") -> pure (Right oneTaskResponse)
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1") -> pure (Right (BrokerHttpResponse 503 Map.empty (object [])))
    ("DELETE", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1") -> do
      attempt <- atomicModifyIORef' deleteAttempts (\count -> (count + 1, count))
      if attempt == 0
        then pure (Left (appError ExternalFailure "The provider response was lost."))
        else pure (Right (BrokerHttpResponse 204 Map.empty (object [])))
    _ -> pure (Right (BrokerHttpResponse 404 Map.empty (object [])))

data ContainerCleanupBehavior
  = ContainerStaysEmpty
  | ContainerHasNewItem
  | ContainerChangesAfterInspection
  | ContainerDeleteResponseLost
  deriving stock (Eq, Show)

containerCleanupTransport :: ContainerCleanupBehavior -> IORef [BrokerHttpRequest] -> IORef Bool -> IORef Bool -> IORef Int -> PackHttpTransport
containerCleanupTransport behavior calls itemDeleted listDeleted postDeleteReads = PackHttpTransport $ \credentialed -> do
  accessTokenBytes (credentialedAccessToken credentialed) @?= secretToken
  let request = credentialedRequest credentialed
  modifyIORef' calls (<> [request])
  case (brokerHttpMethod request, brokerHttpUrl request) of
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists") -> pure (Right oneListResponse)
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1") -> do
      absent <- readIORef listDeleted
      pure . Right $ if absent then BrokerHttpResponse 404 Map.empty (object []) else listDetailResponse
    ("GET", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks") -> do
      cleaned <- readIORef itemDeleted
      if not cleaned
        then pure (Right oneTaskResponse)
        else do
          prior <- atomicModifyIORef' postDeleteReads (\count -> (count + 1, count))
          pure . Right $ case behavior of
            ContainerStaysEmpty -> taskCollection []
            ContainerDeleteResponseLost -> taskCollection []
            ContainerHasNewItem -> taskCollection ["new-task"]
            ContainerChangesAfterInspection -> if prior == 0 then taskCollection [] else taskCollection ["new-task"]
    ("DELETE", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1") -> do
      modifyIORef' itemDeleted (const True)
      pure (Right (BrokerHttpResponse 204 Map.empty (object [])))
    ("DELETE", "https://graph.microsoft.com/v1.0/me/todo/lists/list-1") -> do
      modifyIORef' listDeleted (const True)
      if behavior == ContainerDeleteResponseLost
        then pure (Left (appError ExternalFailure "The provider response was lost."))
        else pure (Right (BrokerHttpResponse 204 Map.empty (object [])))
    _ -> pure (Right (BrokerHttpResponse 404 Map.empty (object [])))

listDetailResponse :: BrokerHttpResponse
listDetailResponse =
  jsonResponse
    ( object
        [ "@odata.etag" .= ("W/\"list-version-1\"" :: Text)
        , "id" .= ("list-1" :: Text)
        , "displayName" .= ("Tasks" :: Text)
        , "isOwner" .= True
        , "isShared" .= False
        , "wellknownListName" .= ("none" :: Text)
        ]
    )

oneListResponse :: BrokerHttpResponse
oneListResponse = jsonResponse (object ["value" .= [object ["id" .= ("list-1" :: Text), "displayName" .= ("Tasks" :: Text)]]])

oneTaskResponse :: BrokerHttpResponse
oneTaskResponse = taskCollection ["task-1"]

twoTaskResponse :: BrokerHttpResponse
twoTaskResponse = taskCollection ["task-1", "task-2"]

taskCollection :: [Text] -> BrokerHttpResponse
taskCollection identities =
  jsonResponse
    ( object
        [ "value"
            .= [ object
                   [ "id" .= identity
                   , "title" .= ("Imported " <> identity)
                   , "status" .= ("notStarted" :: Text)
                   , "hasAttachments" .= False
                   ]
               | identity <- identities
               ]
        ]
    )

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
  result <- importPortPreflight (packRegistryImportPortWithProviders runner registry providers) "microsoft_todo" SourceSnapshot Set.empty
  assertError PermissionRequired result
  readIORef transportCalls >>= (@?= [])

containerSelectionBoundary :: Assertion
containerSelectionBoundary = do
  (runner, registry) <- connectorRuntime
  token <- assertRight (accessTokenFromBytes secretToken)
  transportCalls <- newIORef []
  let resolver = AccessTokenResolver (const (pure (Right token)))
      entries = [("personal", fixtureAccount "account-personal" "Personal", fixtureBinding "personal" fixtureVaultEntry)]
  integrations <- assertRight (authorizedIntegrations registry entries)
  providers <- assertRight (configuredProviderImportSources [microsoftTodoDefinition] integrations registry resolver (graphTransport transportCalls))
  provider <- case providers of
    [one] -> pure one
    other -> assertFailure ("unexpected provider count: " <> show (length other)) >> fail "unreachable"
  let ordinaryPort = packRegistryImportPortWithProviders runner registry [provider]
      scopedPort = packRegistryImportPortWithProviders runner registry [provider{providerImportRequiresContainerSelection = True}]
  importPortPreflight ordinaryPort "microsoft_todo" SourceSnapshot (Set.singleton "list:inbox") >>= assertError InvalidInput
  scopedResult <- importPortPreflight scopedPort "microsoft_todo" SourceSnapshot Set.empty
  assertError PreconditionFailed scopedResult
  case scopedResult of
    Left problem -> map recoveryActionId (appErrorRecovery problem) @?= ["select-containers"]
    Right _ -> assertFailure "scoped import unexpectedly accepted an empty selection"
  importSourceRequiresContainerSelection (last (importPortCatalog scopedPort)) @?= True
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
  integrations <- assertRight (authorizedIntegrations registry [("personal", fixtureAccount "account-personal" "Personal", wrongScheme)])
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
fixtureIntegrations = fixtureIntegrationsWithPin connectorPin

fixtureIntegrationsWithPin :: PackPin -> [(Text, ProviderAccount, CredentialBinding)] -> IntegrationsConfig
fixtureIntegrationsWithPin pin entries =
  IntegrationsConfig
    { installedComponents = Map.singleton "org.littleant.official-connectors" pin
    , providerAccounts = Map.fromList [(name, account) | (name, account, _) <- entries]
    , credentialBindings = Map.fromList [(name <> "-credential", binding) | (name, _, binding) <- entries]
    , deliveryBindings = Map.empty
    , trustedPublishers = Set.empty
    }

fixtureAccount :: Text -> Text -> ProviderAccount
fixtureAccount externalId label =
  ProviderAccount
    { providerAccountPackPin = connectorPin
    , providerAccountComponent = "microsoft_todo"
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
  let exactPin =
        connectorPin
          { pinArtifact = registeredPackIdentity registered
          , pinSignerFingerprint = registeredSignerFingerprint registered
          }
  pure (fixtureIntegrationsWithPin exactPin authorized)
 where
  authorize registered (name, account, binding) = do
    let exactPin =
          (providerAccountPackPin account)
            { pinArtifact = registeredPackIdentity registered
            , pinSignerFingerprint = registeredSignerFingerprint registered
            }
        exactAccount = account{providerAccountPackPin = exactPin}
    client <- resolveOAuthDeviceClient registered exactAccount (credentialBindingSlot binding)
    pure (name, exactAccount, binding{credentialBindingAuthorizationFingerprint = Just (oauthDeviceAuthorizationFingerprint client)})

microsoftTodoDefinition :: ProviderSourceDefinition
microsoftTodoDefinition =
  ProviderSourceDefinition
    { providerDefinitionAdapterId = "microsoft_todo"
    , providerDefinitionNamespace = "microsoft_todo"
    , providerDefinitionDisplayName = "Microsoft To Do"
    , providerDefinitionModes = [SourceSnapshot, SourceSynchronize, SourceMigrate]
    , providerDefinitionRequiresContainerSelection = False
    , providerDefinitionRequiresClientId = True
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
          , artifactManifestDigest = "23ec374a45ccf8ac839db91ec1b590b86ef042c832275b8e9025aeda95747cd6"
          , artifactArchiveDigest = "8722c8879e6534523d1b8fcb15aecd8f667f750096e28c9c28339b80ddd5b24d"
          }
    , pinSignerFingerprint = "77d0e2f201ee265179a942d0af762b9485afb7ec59ae3f47a26c5926264d1c8d"
    , pinTrustOrigin = PinVerifiedOfficial 5
    , pinEnabledComponents = Set.singleton "microsoft_todo"
    }

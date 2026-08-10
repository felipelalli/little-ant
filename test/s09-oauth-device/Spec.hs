module Main (main) where

import Control.Concurrent
import Control.Exception (bracket)
import Data.Aeson (object, (.=))
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.OAuth.AuthorizationCode
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Transport
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import LittleAnt.Provider
import LittleAnt.Vault qualified as Vault
import LittleAnt.Vault.Age (makePassphrase)
import LittleAnt.Vault.Agent
import Network.HTTP.Types.URI (parseQueryText)
import Network.Socket
import Network.Socket.ByteString qualified as SocketBytes
import System.Directory (doesPathExist)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit
import Text.Read (readMaybe)

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 OAuth authorization"
      [ testCase "signed authorization and account client id produce one drift-sensitive binding" signedAuthorizationBinding
      , testCase "device authorization exposes only the human prompt and polls pending to success" deviceAuthorizationLifecycle
      , testCase "slow_down lengthens polling while decline and expiry stop cleanly" pollingOutcomes
      , testCase "token scope escalation and malformed endpoint responses fail closed" responseConfinement
      , testCase "refresh replaces rotated refresh tokens and preserves an omitted replacement" refreshRotation
      , testCase "OAuth grants insert and refresh through one atomic same-scheme vault mutation" oauthVaultPersistence
      , testCase "authorization code PKCE keeps state and verifier transient through loopback exchange" pkceAuthorizationLifecycle
      , testCase "authorization code PKCE rejects state mismatch and missing refresh custody" pkceResponseConfinement
      , testCase "the production PKCE receiver accepts one exact IPv4 loopback callback" pkceLoopbackRoundTrip
      , testCase "an expired provider grant refreshes once and persists before broker use" providerAutomaticRefresh
      ]

pkceLoopbackRoundTrip :: Assertion
pkceLoopbackRoundTrip = do
  client <- fixturePkceClient
  receiver <- newLoopbackReceiver
  presented <- newIORef Nothing
  let runtime =
        OAuthAuthorizationCodeRuntime
          { oauthPkceEntropy = deterministicEntropy
          , oauthPkceLoopbackReceiver = receiver
          , oauthPkcePresentAuthorizationUrl = \url -> do
              writeIORef presented (Just url)
              query <- assertRight (authorizationQuery url)
              redirectUri <- maybe (assertFailure "authorization URL omitted redirect URI" >> pure "") pure (Map.lookup "redirect_uri" query)
              state <- maybe (assertFailure "authorization URL omitted state" >> pure "") pure (Map.lookup "state" query)
              _ <- forkIO (sendLoopbackCallback redirectUri state)
              pure ()
          , oauthPkceCurrentTime = pure fixtureTime
          }
  (transport, _) <- scriptedTransport [pkceTokenResponse (Just "LOOPBACK-REFRESH")]
  result <- runAuthorizationCodePkce runtime transport client >>= assertRight
  oauthRefreshToken result @?= Just "LOOPBACK-REFRESH"
  readIORef presented >>= maybe (assertFailure "production receiver presented no URL") (const (pure ()))

sendLoopbackCallback :: Text -> Text -> IO ()
sendLoopbackCallback redirectUri state = withSocketsDo $ do
  port <- case loopbackPort redirectUri of
    Nothing -> assertFailure "fixture could not parse loopback port" >> pure 0
    Just value -> pure value
  bracket (socket AF_INET Stream defaultProtocol) close $ \connection -> do
    connect connection (SockAddrInet (fromIntegral port) (tupleToHostAddress (127, 0, 0, 1)))
    let host = "127.0.0.1:" <> show port
        request =
          "GET /oauth/callback?code=LOOPBACK-CODE&state="
            <> Text.unpack state
            <> " HTTP/1.1\r\nHost: "
            <> host
            <> "\r\nConnection: close\r\n\r\n"
    SocketBytes.sendAll connection (ByteString8.pack request)
    response <- SocketBytes.recv connection 4096
    assertBool "loopback receiver did not return its private completion page" ("Authorization received" `ByteString.isInfixOf` response)

loopbackPort :: Text -> Maybe Int
loopbackPort uri = do
  remainder <- Text.stripPrefix "http://127.0.0.1:" uri
  let (portText, path) = Text.breakOn "/" remainder
  if path == "/oauth/callback" then readMaybe (Text.unpack portText) else Nothing

pkceAuthorizationLifecycle :: Assertion
pkceAuthorizationLifecycle = do
  client <- fixturePkceClient
  presented <- newIORef Nothing
  let redirectUri = "http://127.0.0.1:43123/oauth/callback"
      receiver = OAuthLoopbackReceiver $ \begin -> do
        begin redirectUri >>= assertRight
        url <- readIORef presented >>= maybe (assertFailure "authorization URL was not presented" >> pure "") pure
        query <- assertRight (authorizationQuery url)
        state <- maybe (assertFailure "authorization URL omitted state" >> pure "") pure (Map.lookup "state" query)
        pure (Right (redirectUri, Map.fromList [("code", "AUTHORIZATION-CODE"), ("state", state)]))
      runtime =
        OAuthAuthorizationCodeRuntime
          { oauthPkceEntropy = deterministicEntropy
          , oauthPkceLoopbackReceiver = receiver
          , oauthPkcePresentAuthorizationUrl = writeIORef presented . Just
          , oauthPkceCurrentTime = pure fixtureTime
          }
  (transport, requests) <- scriptedTransport [pkceTokenResponse (Just "GOOGLE-REFRESH")]
  tokenSet <- runAuthorizationCodePkce runtime transport client >>= assertRight
  oauthScopes tokenSet @?= Set.singleton googleTasksScope
  oauthRefreshToken tokenSet @?= Just "GOOGLE-REFRESH"
  oauthAuthorizationFingerprint tokenSet @?= oauthPkceAuthorizationFingerprint client

  (refreshTransport, _) <- scriptedTransport [pkceRefreshResponseWithoutScope]
  refreshed <- refreshOAuthPkceTokenSet refreshTransport (addUTCTime 3600 fixtureTime) client tokenSet >>= assertRight
  oauthScopes refreshed @?= oauthScopes tokenSet
  oauthRefreshToken refreshed @?= oauthRefreshToken tokenSet

  url <- readIORef presented >>= maybe (assertFailure "authorization URL was not retained by the fixture" >> pure "") pure
  assertBool "wrong authorization endpoint" (googleAuthorizationEndpoint `Text.isPrefixOf` url)
  query <- assertRight (authorizationQuery url)
  Map.lookup "response_type" query @?= Just "code"
  Map.lookup "code_challenge_method" query @?= Just "S256"
  Map.lookup "redirect_uri" query @?= Just redirectUri
  Map.lookup "prompt" query @?= Just "consent"
  Map.lookup "scope" query @?= Just googleTasksScope
  maybe (assertFailure "authorization URL omitted PKCE challenge") (\challenge -> Text.length challenge @?= 43) (Map.lookup "code_challenge" query)

  observed <- readIORef requests
  case observed of
    [exchange] -> do
      oauthFormEndpoint exchange @?= googleTokenEndpoint
      Map.lookup "grant_type" (oauthFormFields exchange) @?= Just "authorization_code"
      Map.lookup "code" (oauthFormFields exchange) @?= Just "AUTHORIZATION-CODE"
      Map.lookup "redirect_uri" (oauthFormFields exchange) @?= Just redirectUri
      maybe (assertFailure "token exchange omitted code_verifier") (\verifier -> Text.length verifier @?= 86) (Map.lookup "code_verifier" (oauthFormFields exchange))
      assertBool "public client unexpectedly sent a secret" (Map.notMember "client_secret" (oauthFormFields exchange))
    other -> assertFailure ("unexpected PKCE request count: " <> show (length other))

pkceResponseConfinement :: Assertion
pkceResponseConfinement = do
  client <- fixturePkceClient
  calls <- newIORef (0 :: Int)
  let mismatched =
        OAuthAuthorizationCodeRuntime
          { oauthPkceEntropy = deterministicEntropy
          , oauthPkceLoopbackReceiver = OAuthLoopbackReceiver $ \begin -> do
              begin "http://127.0.0.1:43123/oauth/callback" >>= assertRight
              pure (Right ("http://127.0.0.1:43123/oauth/callback", Map.fromList [("code", "CODE"), ("state", "wrong")]))
          , oauthPkcePresentAuthorizationUrl = const (pure ())
          , oauthPkceCurrentTime = pure fixtureTime
          }
      unusedTransport = OAuthFormTransport $ \_ -> modifyIORef' calls (+ 1) >> pure (Left (appError ExternalFailure "must not run"))
  runAuthorizationCodePkce mismatched unusedTransport client >>= assertError PermissionRequired
  readIORef calls >>= (@?= 0)

  presented <- newIORef Nothing
  let noRefresh = successfulPkceRuntime presented
  (transport, _) <- scriptedTransport [pkceTokenResponse Nothing]
  runAuthorizationCodePkce noRefresh transport client >>= assertError ExternalFailure

successfulPkceRuntime :: IORef (Maybe Text) -> OAuthAuthorizationCodeRuntime
successfulPkceRuntime presented =
  OAuthAuthorizationCodeRuntime
    { oauthPkceEntropy = deterministicEntropy
    , oauthPkceLoopbackReceiver = OAuthLoopbackReceiver $ \begin -> do
        let redirectUri = "http://127.0.0.1:43123/oauth/callback"
        begin redirectUri >>= assertRight
        url <- readIORef presented >>= maybe (assertFailure "authorization URL was not presented" >> pure "") pure
        query <- assertRight (authorizationQuery url)
        state <- maybe (assertFailure "authorization URL omitted state" >> pure "") pure (Map.lookup "state" query)
        pure (Right (redirectUri, Map.fromList [("code", "CODE"), ("state", state)]))
    , oauthPkcePresentAuthorizationUrl = writeIORef presented . Just
    , oauthPkceCurrentTime = pure fixtureTime
    }

authorizationQuery :: Text -> Either AppError (Map.Map Text Text)
authorizationQuery url = do
  let (_, marked) = Text.breakOn "?" url
  if Text.null marked
    then Left (appError InvalidInput "authorization URL has no query")
    else foldl insertOne (Right Map.empty) (parseQueryText (TextEncoding.encodeUtf8 (Text.drop 1 marked)))
 where
  insertOne prior (key, value) = do
    fields <- prior
    decoded <- maybe (Left (appError InvalidInput "authorization query has a valueless field")) Right value
    if Map.member key fields
      then Left (appError InvalidInput "authorization query has a duplicate field")
      else Right (Map.insert key decoded fields)

deterministicEntropy :: Int -> IO ByteString.ByteString
deterministicEntropy count = pure (ByteString.pack (take count (cycle [0 .. 255])))

signedAuthorizationBinding :: Assertion
signedAuthorizationBinding = do
  client <- assertRight (resolveOAuthDeviceClient fixtureRegistered fixtureAccount "microsoft")
  let fingerprint = oauthDeviceAuthorizationFingerprint client
      valid = fixtureBinding (Just fingerprint)
  Text.length fingerprint @?= 64
  validateOAuthCredentialBinding client valid @?= Right ()
  assertError PermissionRequired (validateOAuthCredentialBinding client (fixtureBinding (Just (Text.replicate 64 "0"))))
  let changedAccount = fixtureAccount{providerAccountConfiguration = object ["client_id" .= ("22222222-2222-2222-2222-222222222222" :: Text)]}
  changed <- assertRight (resolveOAuthDeviceClient fixtureRegistered changedAccount "microsoft")
  assertBool "client-id drift retained the old authorization identity" (oauthDeviceAuthorizationFingerprint changed /= fingerprint)

deviceAuthorizationLifecycle :: Assertion
deviceAuthorizationLifecycle = do
  client <- fixtureClient
  (transport, requests) <- scriptedTransport [deviceResponse, pendingResponse, tokenResponse "REFRESH-1"]
  session <- beginDeviceAuthorization transport fixtureTime client >>= assertRight
  let prompt = deviceAuthorizationPrompt session
  devicePromptUserCode prompt @?= "ABCD-EFGH"
  devicePromptVerificationUri prompt @?= "https://microsoft.com/devicelogin"
  devicePromptExpiresAt prompt @?= addUTCTime 900 fixtureTime
  devicePromptPollingIntervalSeconds prompt @?= 5

  first <- pollDeviceAuthorization transport (addUTCTime 5 fixtureTime) client session >>= assertRight
  continued <- case first of
    DeviceAuthorizationPending delay next -> do
      delay @?= 5
      pure next
    _ -> assertFailure "expected authorization_pending" >> pure session
  second <- pollDeviceAuthorization transport (addUTCTime 10 fixtureTime) client continued >>= assertRight
  tokenSet <- case second of
    DeviceAuthorizationSucceeded value -> pure value
    _ -> assertFailure "expected successful device authorization" >> fail "unreachable"
  oauthRefreshToken tokenSet @?= Just "REFRESH-1"
  oauthScopes tokenSet @?= Set.singleton "Tasks.Read"
  oauthAuthorizationFingerprint tokenSet @?= oauthDeviceAuthorizationFingerprint client

  observed <- readIORef requests
  case observed of
    [started, polled, _] -> do
      oauthFormEndpoint started @?= deviceEndpoint
      Map.lookup "scope" (oauthFormFields started) @?= Just "Tasks.Read offline_access"
      Map.lookup "device_code" (oauthFormFields polled) @?= Just "PRIVATE-DEVICE-CODE"
    other -> assertFailure ("unexpected OAuth request count: " <> show (length other))

pollingOutcomes :: Assertion
pollingOutcomes = do
  client <- fixtureClient
  (transport, _) <- scriptedTransport [deviceResponse, slowDownResponse, declinedResponse]
  session <- beginDeviceAuthorization transport fixtureTime client >>= assertRight
  slowed <- pollDeviceAuthorization transport (addUTCTime 5 fixtureTime) client session >>= assertRight
  continued <- case slowed of
    DeviceAuthorizationPending delay next -> do
      delay @?= 10
      devicePromptPollingIntervalSeconds (deviceAuthorizationPrompt next) @?= 10
      pure next
    _ -> assertFailure "expected slow_down" >> pure session
  declined <- pollDeviceAuthorization transport (addUTCTime 15 fixtureTime) client continued >>= assertRight
  case declined of
    DeviceAuthorizationDeclined -> pure ()
    _ -> assertFailure "expected authorization_declined"
  expired <- pollDeviceAuthorization transport (addUTCTime 901 fixtureTime) client session >>= assertRight
  case expired of
    DeviceAuthorizationExpired -> pure ()
    _ -> assertFailure "a locally expired device session was polled"

responseConfinement :: Assertion
responseConfinement = do
  client <- fixtureClient
  (escalated, _) <- scriptedTransport [deviceResponse, tokenResponseWithScopes "Tasks.Read Tasks.ReadWrite"]
  session <- beginDeviceAuthorization escalated fixtureTime client >>= assertRight
  pollDeviceAuthorization escalated (addUTCTime 5 fixtureTime) client session >>= assertError ExternalFailure

  (malformed, _) <- scriptedTransport [OAuthFormResponse 200 (object ["device_code" .= ("x" :: Text)])]
  beginDeviceAuthorization malformed fixtureTime client >>= assertError ExternalFailure

refreshRotation :: Assertion
refreshRotation = do
  client <- fixtureClient
  let previous = fixtureTokenSet client "REFRESH-OLD"
  (rotating, requests) <- scriptedTransport [tokenResponse "REFRESH-NEW"]
  rotated <- refreshOAuthTokenSet rotating fixtureTime client previous >>= assertRight
  oauthRefreshToken rotated @?= Just "REFRESH-NEW"
  observed <- readIORef requests
  case observed of
    [request] -> Map.lookup "refresh_token" (oauthFormFields request) @?= Just "REFRESH-OLD"
    other -> assertFailure ("unexpected refresh request count: " <> show (length other))

  (preserving, _) <- scriptedTransport [tokenResponseWithoutRefresh]
  preserved <- refreshOAuthTokenSet preserving fixtureTime client previous >>= assertRight
  oauthRefreshToken preserved @?= Just "REFRESH-OLD"

oauthVaultPersistence :: Assertion
oauthVaultPersistence = withSystemTempDirectory "lant-oauth-vault" $ \root -> do
  passphrase <- assertRight (makePassphrase "oauth fixture passphrase")
  let vaultPath = root </> "vaults" </> "default.age"
      socketPath = root </> "runtime" </> "default" </> "vault.sock"
      bindingId = fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0d2"
  Vault.writeVault vaultPath passphrase (Vault.emptyVault (fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0d1")) >>= assertRight
  finished <- newEmptyMVar
  _ <- forkIO (runVaultAgent socketPath vaultPath 60 >>= putMVar finished)
  waitForPath socketPath 100
  sendVaultAgentRequest socketPath (agentUnlockRequest "oauth fixture passphrase") >>= assertRight >>= assertSucceeded

  client <- fixtureClient
  let binding = fixtureBinding (Just (oauthDeviceAuthorizationFingerprint client))
      first = fixtureTokenSet client "REFRESH-OLD"
  persistOAuthTokenSet socketPath client binding "Microsoft To Do · Personal" first >>= assertRight
  firstSecret <- resolveSecret socketPath bindingId
  firstAccess <- assertRight (accessTokenFromVaultSecret fixtureTime binding firstSecret)
  accessTokenBytes firstAccess @?= "ACCESS-OLD"
  wipeAgentSecret firstSecret

  (transport, _) <- scriptedTransport [tokenResponse "REFRESH-NEW"]
  refreshed <- refreshOAuthTokenSet transport fixtureTime client first >>= assertRight
  persistOAuthTokenSet socketPath client binding "Microsoft To Do · Personal" refreshed >>= assertRight
  refreshedSecret <- resolveSecret socketPath bindingId
  refreshedAccess <- assertRight (accessTokenFromVaultSecret fixtureTime binding refreshedSecret)
  accessTokenBytes refreshedAccess @?= "ACCESS-NEW"
  wipeAgentSecret refreshedSecret

  sendVaultAgentRequest socketPath agentShutdownRequest >>= assertRight >>= assertSucceeded
  takeMVar finished >>= assertRight
  stored <- Vault.readVault vaultPath passphrase >>= assertRight
  Vault.vaultRevision stored @?= 3
 where
  assertSucceeded reply = assertBool "vault agent did not acknowledge the OAuth mutation" (agentReplySucceeded reply)
  resolveSecret socketPath identity = do
    reply <- sendVaultAgentRequest socketPath (agentResolveRequest identity "source_read") >>= assertRight
    maybe (assertFailure "vault agent omitted OAuth secret" >> pure ByteString.empty) pure (agentReplySecret reply)

providerAutomaticRefresh :: Assertion
providerAutomaticRefresh = withSystemTempDirectory "lant-provider-refresh" $ \root -> do
  passphrase <- assertRight (makePassphrase "provider refresh fixture passphrase")
  let vaultPath = root </> "vaults" </> "default.age"
      socketPath = root </> "runtime" </> "default" </> "vault.sock"
      bindingId = fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0e2"
  Vault.writeVault vaultPath passphrase (Vault.emptyVault (fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0e1")) >>= assertRight
  finished <- newEmptyMVar
  _ <- forkIO (runVaultAgent socketPath vaultPath 60 >>= putMVar finished)
  waitForPath socketPath 100
  sendVaultAgentRequest socketPath (agentUnlockRequest "provider refresh fixture passphrase") >>= assertRight >>= assertSucceeded

  registry <- googleConnectorRegistry
  registered <- assertRight (lookupPackComponent "google_tasks" registry)
  let exactPin =
        fixturePkcePackPin
          { pinArtifact = registeredPackIdentity registered
          , pinSignerFingerprint = registeredSignerFingerprint registered
          , pinTrustOrigin = PinVerifiedOfficial 1
          }
      exactAccount = fixturePkceAccount{providerAccountPackPin = exactPin}
  client <- assertRight (resolveOAuthPkceClient registered exactAccount "google")
  let binding =
        CredentialBinding
          { credentialBindingComponent = "google_tasks"
          , credentialBindingSlot = "google"
          , credentialBindingAccount = "personal"
          , credentialBindingScheme = Vault.OAuthAuthorizationCodePKCE
          , credentialBindingVaultEntry = bindingId
          , credentialBindingAuthorizationFingerprint = Just (oauthPkceAuthorizationFingerprint client)
          , credentialBindingPurposes = Set.singleton "source_read"
          }
      expired =
        OAuthTokenSet
          { oauthAccessToken = "EXPIRED-GOOGLE-ACCESS"
          , oauthRefreshToken = Just "GOOGLE-REFRESH"
          , oauthExpiresAt = fixtureTime
          , oauthScopes = Set.singleton googleTasksScope
          , oauthAuthorizationFingerprint = oauthPkceAuthorizationFingerprint client
          }
      integrations =
        IntegrationsConfig
          { installedComponents = Map.empty
          , providerAccounts = Map.singleton "personal" exactAccount
          , credentialBindings = Map.singleton "google_tasks-personal" binding
          , deliveryBindings = Map.empty
          , trustedPublishers = Set.empty
          }
  persistOAuthPkceTokenSet socketPath client binding "Google Tasks · Personal" expired >>= assertRight
  (transport, requests) <- scriptedTransport [pkceRefreshResponseWithoutScope]
  let resolver = providerAccessTokenResolver standardProviderSourceDefinitions registry integrations socketPath (pure fixtureTime) transport
  first <- resolveAccessToken resolver binding >>= assertRight
  accessTokenBytes first @?= "GOOGLE-REFRESHED-ACCESS"
  second <- resolveAccessToken resolver binding >>= assertRight
  accessTokenBytes second @?= "GOOGLE-REFRESHED-ACCESS"
  readIORef requests >>= \observed -> length observed @?= 1

  sendVaultAgentRequest socketPath agentShutdownRequest >>= assertRight >>= assertSucceeded
  takeMVar finished >>= assertRight
 where
  assertSucceeded reply = assertBool "vault agent did not acknowledge provider refresh" (agentReplySucceeded reply)

googleConnectorRegistry :: IO PackRegistry
googleConnectorRegistry = do
  archive <- ByteString.readFile ("packs" </> "official-connectors" </> "official-connectors.lantpack")
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
  install <- assertRight (authorizePackInstall fixtureTime scope policy (Set.singleton "google_tasks") authenticated)
  execution <- assertRight (authorizePinnedPackExecution fixtureTime scope policy (installAuthorizedPin install) authenticated)
  assertRight (buildPackRegistry scope [execution])

waitForPath :: FilePath -> Int -> Assertion
waitForPath path attempts
  | attempts <= 0 = assertFailure ("timed out waiting for " <> path)
  | otherwise = do
      exists <- doesPathExist path
      if exists then pure () else threadDelay 10_000 >> waitForPath path (attempts - 1)

scriptedTransport :: [OAuthFormResponse] -> IO (OAuthFormTransport, IORef [OAuthFormRequest])
scriptedTransport responses = do
  remaining <- newIORef responses
  requests <- newIORef []
  let run request = do
        modifyIORef' requests (<> [request])
        atomicModifyIORef' remaining $ \case
          [] -> ([], Left (appError ExternalFailure "fixture transport exhausted"))
          response : rest -> (rest, Right response)
  pure (OAuthFormTransport run, requests)

fixtureClient :: IO OAuthDeviceClient
fixtureClient = assertRight (resolveOAuthDeviceClient fixtureRegistered fixtureAccount "microsoft")

fixturePkceClient :: IO OAuthPkceClient
fixturePkceClient = assertRight (resolveOAuthPkceClient fixturePkceRegistered fixturePkceAccount "google")

fixtureTokenSet :: OAuthDeviceClient -> Text -> OAuthTokenSet
fixtureTokenSet client refresh =
  OAuthTokenSet
    { oauthAccessToken = "ACCESS-OLD"
    , oauthRefreshToken = Just refresh
    , oauthExpiresAt = addUTCTime 3600 fixtureTime
    , oauthScopes = Set.singleton "Tasks.Read"
    , oauthAuthorizationFingerprint = oauthDeviceAuthorizationFingerprint client
    }

fixtureAccount :: ProviderAccount
fixtureAccount =
  ProviderAccount
    { providerAccountPackPin = fixturePackPin
    , providerAccountComponent = "microsoft_todo"
    , providerAccountProvider = "microsoft_todo"
    , providerAccountExternalId = "account-personal"
    , providerAccountLabel = "Personal"
    , providerAccountConfiguration = object ["client_id" .= ("11111111-1111-1111-1111-111111111111" :: Text)]
    }

fixturePkceAccount :: ProviderAccount
fixturePkceAccount =
  ProviderAccount
    { providerAccountPackPin = fixturePkcePackPin
    , providerAccountComponent = "google_tasks"
    , providerAccountProvider = "google_tasks"
    , providerAccountExternalId = "google-personal"
    , providerAccountLabel = "Personal"
    , providerAccountConfiguration = object ["client_id" .= ("example.apps.googleusercontent.com" :: Text)]
    }

fixturePackPin :: PackPin
fixturePackPin =
  PackPin
    { pinArtifact = registeredPackIdentity fixtureRegistered
    , pinSignerFingerprint = registeredSignerFingerprint fixtureRegistered
    , pinTrustOrigin = PinTrustedPublisher
    , pinEnabledComponents = Set.singleton "microsoft_todo"
    }

fixturePkcePackPin :: PackPin
fixturePkcePackPin =
  PackPin
    { pinArtifact = registeredPackIdentity fixturePkceRegistered
    , pinSignerFingerprint = registeredSignerFingerprint fixturePkceRegistered
    , pinTrustOrigin = PinTrustedPublisher
    , pinEnabledComponents = Set.singleton "google_tasks"
    }

fixtureBinding :: Maybe Text -> CredentialBinding
fixtureBinding fingerprint =
  CredentialBinding
    { credentialBindingComponent = "microsoft_todo"
    , credentialBindingSlot = "microsoft"
    , credentialBindingAccount = "personal"
    , credentialBindingScheme = Vault.OAuthDeviceAuthorization
    , credentialBindingVaultEntry = fixtureUuid "019fe080-4344-763f-b110-53cb7aefd0d2"
    , credentialBindingAuthorizationFingerprint = fingerprint
    , credentialBindingPurposes = Set.singleton "source_read"
    }

fixtureRegistered :: RegisteredPackComponent
fixtureRegistered =
  RegisteredPackComponent
    { registeredPackIdentity =
        PackArtifactIdentity
          "org.littleant.project"
          "org.littleant.official-connectors"
          "1.0.0"
          (Text.replicate 64 "1")
          (Text.replicate 64 "2")
    , registeredSignerFingerprint = Text.replicate 64 "3"
    , registeredComponent =
        ExecutableComponent
          ComponentCommon
            { componentId = "microsoft_todo"
            , componentKind = SourceAdapterComponent
            , componentContractMajor = 1
            , componentRoot = "sources/microsoft_todo"
            , componentConfigurationSchema = "config.schema.json"
            }
          "main.lua"
          fixturePermissions
    , registeredComponentPayload = Map.empty
    }

fixturePkceRegistered :: RegisteredPackComponent
fixturePkceRegistered =
  RegisteredPackComponent
    { registeredPackIdentity =
        PackArtifactIdentity
          "org.littleant.project"
          "org.littleant.official-connectors"
          "1.0.0"
          (Text.replicate 64 "4")
          (Text.replicate 64 "5")
    , registeredSignerFingerprint = Text.replicate 64 "6"
    , registeredComponent =
        ExecutableComponent
          ComponentCommon
            { componentId = "google_tasks"
            , componentKind = SourceAdapterComponent
            , componentContractMajor = 1
            , componentRoot = "sources/google_tasks"
            , componentConfigurationSchema = "config.schema.json"
            }
          "main.lua"
          ComponentPermissions
            { permissionCredentialSlots = [CredentialSlot "google" OAuthAuthorizationCodePkce]
            , permissionOAuthAuthorizationCodePkce =
                [ OAuthAuthorizationCodePkcePermission
                    { oauthPkceCredentialSlot = "google"
                    , oauthPkceAuthorizationEndpoint = googleAuthorizationEndpoint
                    , oauthPkceTokenEndpoint = googleTokenEndpoint
                    , oauthPkceClientIdConfigurationKey = "client_id"
                    , oauthPkceScopes = Set.singleton googleTasksScope
                    , oauthPkceAuthorizationParameters = Map.singleton "prompt" "consent"
                    }
                ]
            , permissionOAuthDeviceAuthorizations = []
            , permissionHttp = [HttpPermission ["GET"] "tasks.googleapis.com" "/tasks/v1" (Just "google")]
            , permissionEffectPurposes = []
            , permissionProjections = []
            , permissionHostCapabilities = []
            }
    , registeredComponentPayload = Map.empty
    }

fixturePermissions :: ComponentPermissions
fixturePermissions =
  ComponentPermissions
    { permissionCredentialSlots = [CredentialSlot "microsoft" OAuthDeviceAuthorization]
    , permissionOAuthAuthorizationCodePkce = []
    , permissionOAuthDeviceAuthorizations = [fixtureAuthorization]
    , permissionHttp = [HttpPermission ["GET"] "graph.microsoft.com" "/v1.0/me/todo" (Just "microsoft")]
    , permissionEffectPurposes = []
    , permissionProjections = []
    , permissionHostCapabilities = []
    }

fixtureAuthorization :: OAuthDeviceAuthorizationPermission
fixtureAuthorization =
  OAuthDeviceAuthorizationPermission
    { oauthDeviceCredentialSlot = "microsoft"
    , oauthDeviceAuthorizationEndpoint = deviceEndpoint
    , oauthDeviceTokenEndpoint = tokenEndpoint
    , oauthDeviceClientIdConfigurationKey = "client_id"
    , oauthDeviceScopes = Set.fromList ["Tasks.Read", "offline_access"]
    }

deviceResponse, pendingResponse, slowDownResponse, declinedResponse, tokenResponseWithoutRefresh :: OAuthFormResponse
deviceResponse =
  OAuthFormResponse
    200
    ( object
        [ "device_code" .= ("PRIVATE-DEVICE-CODE" :: Text)
        , "user_code" .= ("ABCD-EFGH" :: Text)
        , "verification_uri" .= ("https://microsoft.com/devicelogin" :: Text)
        , "expires_in" .= (900 :: Int)
        , "interval" .= (5 :: Int)
        ]
    )
pendingResponse = OAuthFormResponse 400 (object ["error" .= ("authorization_pending" :: Text)])
slowDownResponse = OAuthFormResponse 400 (object ["error" .= ("slow_down" :: Text)])
declinedResponse = OAuthFormResponse 400 (object ["error" .= ("authorization_declined" :: Text)])
tokenResponseWithoutRefresh =
  OAuthFormResponse
    200
    ( object
        [ "token_type" .= ("Bearer" :: Text)
        , "scope" .= ("Tasks.Read" :: Text)
        , "expires_in" .= (3600 :: Int)
        , "access_token" .= ("ACCESS-NEW" :: Text)
        ]
    )

tokenResponse :: Text -> OAuthFormResponse
tokenResponse refresh = tokenResponseWithScopesAndRefresh "Tasks.Read" (Just refresh)

tokenResponseWithScopes :: Text -> OAuthFormResponse
tokenResponseWithScopes scopes = tokenResponseWithScopesAndRefresh scopes (Just "REFRESH")

tokenResponseWithScopesAndRefresh :: Text -> Maybe Text -> OAuthFormResponse
tokenResponseWithScopesAndRefresh scopes refresh =
  OAuthFormResponse
    200
    ( object $
        [ "token_type" .= ("Bearer" :: Text)
        , "scope" .= scopes
        , "expires_in" .= (3600 :: Int)
        , "access_token" .= ("ACCESS-NEW" :: Text)
        ]
          <> maybe [] (pure . ("refresh_token" .=)) refresh
    )

pkceTokenResponse :: Maybe Text -> OAuthFormResponse
pkceTokenResponse refresh =
  OAuthFormResponse
    200
    ( object $
        [ "token_type" .= ("Bearer" :: Text)
        , "scope" .= googleTasksScope
        , "expires_in" .= (3600 :: Int)
        , "access_token" .= ("GOOGLE-ACCESS" :: Text)
        ]
          <> maybe [] (pure . ("refresh_token" .=)) refresh
    )

pkceRefreshResponseWithoutScope :: OAuthFormResponse
pkceRefreshResponseWithoutScope =
  OAuthFormResponse
    200
    ( object
        [ "token_type" .= ("Bearer" :: Text)
        , "expires_in" .= (3600 :: Int)
        , "access_token" .= ("GOOGLE-REFRESHED-ACCESS" :: Text)
        ]
    )

deviceEndpoint, tokenEndpoint :: Text
deviceEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/devicecode"
tokenEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/token"

googleAuthorizationEndpoint, googleTokenEndpoint, googleTasksScope :: Text
googleAuthorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
googleTokenEndpoint = "https://oauth2.googleapis.com/token"
googleTasksScope = "https://www.googleapis.com/auth/tasks"

fixtureTime :: UTCTime
fixtureTime = read "2026-08-09 12:00:00 UTC"

fixtureUuid :: Text -> UUIDv7
fixtureUuid value = either (error . Text.unpack) id (parseUUIDv7 value)

assertRight :: (HasCallStack, Show err) => Either err value -> IO value
assertRight = either (assertFailure . show) pure

assertError :: (HasCallStack) => ErrorCode -> Either AppError value -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure "expected an AppError"

module Main (main) where

import Control.Concurrent
import Data.Aeson (object, (.=))
import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Transport
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import LittleAnt.Vault qualified as Vault
import LittleAnt.Vault.Age (makePassphrase)
import LittleAnt.Vault.Agent
import System.Directory (doesPathExist)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 OAuth device authorization"
      [ testCase "signed authorization and account client id produce one drift-sensitive binding" signedAuthorizationBinding
      , testCase "device authorization exposes only the human prompt and polls pending to success" deviceAuthorizationLifecycle
      , testCase "slow_down lengthens polling while decline and expiry stop cleanly" pollingOutcomes
      , testCase "token scope escalation and malformed endpoint responses fail closed" responseConfinement
      , testCase "refresh replaces rotated refresh tokens and preserves an omitted replacement" refreshRotation
      , testCase "OAuth grants insert and refresh through one atomic same-scheme vault mutation" oauthVaultPersistence
      ]

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
    { providerAccountComponent = "microsoft_todo"
    , providerAccountProvider = "microsoft_todo"
    , providerAccountExternalId = "account-personal"
    , providerAccountLabel = "Personal"
    , providerAccountConfiguration = object ["client_id" .= ("11111111-1111-1111-1111-111111111111" :: Text)]
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

fixturePermissions :: ComponentPermissions
fixturePermissions =
  ComponentPermissions
    { permissionCredentialSlots = [CredentialSlot "microsoft" OAuthDeviceAuthorization]
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

deviceEndpoint, tokenEndpoint :: Text
deviceEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/devicecode"
tokenEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/token"

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

module LittleAnt.OAuth.Device (
  OAuthDeviceClient,
  resolveOAuthDeviceClient,
  validateOAuthCredentialBinding,
  oauthDeviceAuthorizationFingerprint,
  oauthDeviceClientConfigurationKey,
  oauthDeviceRequestedScopes,
  DeviceAuthorizationPrompt (..),
  DeviceAuthorizationSession,
  deviceAuthorizationPrompt,
  DeviceAuthorizationPoll (..),
  OAuthFormRequest (..),
  OAuthFormResponse (..),
  OAuthFormTransport (..),
  beginDeviceAuthorization,
  pollDeviceAuthorization,
  refreshOAuthTokenSet,
  persistOAuthTokenSet,
  newTlsOAuthFormTransport,
) where

import Control.Applicative ((<|>))
import Control.Exception (finally, try)
import Control.Monad (unless, when)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Error
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Transport (OAuthTokenSet (..), encodeOAuthTokenSet)
import LittleAnt.Profile
import LittleAnt.Store (sha256Hex)
import LittleAnt.Vault qualified as Vault
import LittleAnt.Vault.Agent
import Network.HTTP.Client qualified as Http
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Header qualified as Header
import Network.HTTP.Types.Status (statusCode)
import Network.HTTP.Types.URI (renderSimpleQuery)
import Network.URI (URI (..), URIAuth (..), parseURI)

data OAuthDeviceClient = OAuthDeviceClient
  { deviceClientId :: Text
  , deviceClientPermission :: OAuthDeviceAuthorizationPermission
  , deviceClientAuthorizationFingerprint :: Text
  }

data DeviceAuthorizationPrompt = DeviceAuthorizationPrompt
  { devicePromptUserCode :: Text
  , devicePromptVerificationUri :: Text
  , devicePromptExpiresAt :: UTCTime
  , devicePromptPollingIntervalSeconds :: Int
  }
  deriving stock (Eq, Show)

data DeviceAuthorizationSession = DeviceAuthorizationSession
  { deviceSessionCode :: Text
  , deviceSessionPrompt :: DeviceAuthorizationPrompt
  }

deviceAuthorizationPrompt :: DeviceAuthorizationSession -> DeviceAuthorizationPrompt
deviceAuthorizationPrompt = deviceSessionPrompt

data DeviceAuthorizationPoll
  = DeviceAuthorizationPending Int DeviceAuthorizationSession
  | DeviceAuthorizationSucceeded OAuthTokenSet
  | DeviceAuthorizationDeclined
  | DeviceAuthorizationExpired

data OAuthFormRequest = OAuthFormRequest
  { oauthFormEndpoint :: Text
  , oauthFormFields :: Map Text Text
  }

data OAuthFormResponse = OAuthFormResponse
  { oauthFormStatus :: Int
  , oauthFormJson :: Value
  }

newtype OAuthFormTransport = OAuthFormTransport
  { runOAuthFormTransport :: OAuthFormRequest -> IO (Either AppError OAuthFormResponse)
  }

resolveOAuthDeviceClient :: RegisteredPackComponent -> ProviderAccount -> Text -> Either AppError OAuthDeviceClient
resolveOAuthDeviceClient registered account slotId = do
  permissions <- executablePermissions registered
  permission <-
    case filter ((== slotId) . oauthDeviceCredentialSlot) (permissionOAuthDeviceAuthorizations permissions) of
      [value] -> Right value
      [] -> Left (oauthProblem PreconditionFailed "The signed component has no OAuth device authorization for this credential slot." [slotId])
      _ -> Left (oauthProblem CorruptData "The signed component has ambiguous OAuth device authorizations." [slotId])
  clientId <- configurationText (oauthDeviceClientIdConfigurationKey permission) (providerAccountConfiguration account)
  validateClientId clientId
  fingerprint <- authorizationFingerprint registered permission clientId
  pure (OAuthDeviceClient clientId permission fingerprint)

validateOAuthCredentialBinding :: OAuthDeviceClient -> CredentialBinding -> Either AppError ()
validateOAuthCredentialBinding client binding = do
  unless (credentialBindingScheme binding == Vault.OAuthDeviceAuthorization) $
    invalid "The CredentialBinding scheme does not match OAuth device authorization."
  unless (credentialBindingSlot binding == oauthDeviceCredentialSlot (deviceClientPermission client)) $
    invalid "The CredentialBinding slot does not match the signed OAuth authorization."
  unless (credentialBindingAuthorizationFingerprint binding == Just (deviceClientAuthorizationFingerprint client)) $
    Left
      ( (oauthProblem PermissionRequired "The provider authorization changed and requires fresh human consent." [credentialBindingSlot binding])
          { appErrorRecovery = [RecoveryAction "reconnect" "Review the exact client and scopes, then reconnect this account." Nothing]
          }
      )
 where
  invalid message = Left (oauthProblem PreconditionFailed message [credentialBindingSlot binding])

oauthDeviceAuthorizationFingerprint :: OAuthDeviceClient -> Text
oauthDeviceAuthorizationFingerprint = deviceClientAuthorizationFingerprint

oauthDeviceClientConfigurationKey :: OAuthDeviceClient -> Text
oauthDeviceClientConfigurationKey = oauthDeviceClientIdConfigurationKey . deviceClientPermission

oauthDeviceRequestedScopes :: OAuthDeviceClient -> Set Text
oauthDeviceRequestedScopes = oauthDeviceScopes . deviceClientPermission

beginDeviceAuthorization :: OAuthFormTransport -> UTCTime -> OAuthDeviceClient -> IO (Either AppError DeviceAuthorizationSession)
beginDeviceAuthorization transport now client = do
  let permission = deviceClientPermission client
      request =
        OAuthFormRequest
          (oauthDeviceAuthorizationEndpoint permission)
          ( Map.fromList
              [ ("client_id", deviceClientId client)
              , ("scope", renderScopes (oauthDeviceScopes permission))
              ]
          )
  runOAuthFormTransport transport request >>= pure . (>>= parseDeviceAuthorization now)

pollDeviceAuthorization :: OAuthFormTransport -> UTCTime -> OAuthDeviceClient -> DeviceAuthorizationSession -> IO (Either AppError DeviceAuthorizationPoll)
pollDeviceAuthorization transport now client session
  | now >= devicePromptExpiresAt (deviceSessionPrompt session) = pure (Right DeviceAuthorizationExpired)
  | otherwise = do
      let permission = deviceClientPermission client
          request =
            OAuthFormRequest
              (oauthDeviceTokenEndpoint permission)
              ( Map.fromList
                  [ ("client_id", deviceClientId client)
                  , ("device_code", deviceSessionCode session)
                  , ("grant_type", "urn:ietf:params:oauth:grant-type:device_code")
                  ]
              )
      runOAuthFormTransport transport request >>= pure . (>>= parsePollResponse now client session)

refreshOAuthTokenSet :: OAuthFormTransport -> UTCTime -> OAuthDeviceClient -> OAuthTokenSet -> IO (Either AppError OAuthTokenSet)
refreshOAuthTokenSet transport now client previous
  | oauthAuthorizationFingerprint previous /= deviceClientAuthorizationFingerprint client =
      pure . Left $ oauthProblem PermissionRequired "The stored OAuth grant belongs to a different signed authorization." []
  | otherwise = case oauthRefreshToken previous of
      Nothing -> pure . Left $ oauthProblem PermissionRequired "The stored OAuth grant has no refresh token; reconnect this account." []
      Just refreshToken -> do
        let permission = deviceClientPermission client
            request =
              OAuthFormRequest
                (oauthDeviceTokenEndpoint permission)
                ( Map.fromList
                    [ ("client_id", deviceClientId client)
                    , ("grant_type", "refresh_token")
                    , ("refresh_token", refreshToken)
                    , ("scope", renderScopes (oauthDeviceScopes permission))
                    ]
                )
        runOAuthFormTransport transport request >>= pure . (>>= parseRefreshResponse now client refreshToken)

persistOAuthTokenSet :: FilePath -> OAuthDeviceClient -> CredentialBinding -> Text -> OAuthTokenSet -> IO (Either AppError ())
persistOAuthTokenSet socketPath client binding label tokenSet = case validateTokenForClient client binding tokenSet of
  Left problem -> pure (Left problem)
  Right () -> case encodeOAuthTokenSet tokenSet of
    Left problem -> pure (Left problem)
    Right encoded ->
      finally
        ( sendVaultAgentRequest
            socketPath
            ( agentPutRequest
                (credentialBindingVaultEntry binding)
                (credentialBindingScheme binding)
                label
                ( Map.fromList
                    [ ("account", credentialBindingAccount binding)
                    , ("authorization_fingerprint", oauthAuthorizationFingerprint tokenSet)
                    , ("component", credentialBindingComponent binding)
                    ]
                )
                encoded
            )
            >>= pure . (>>= acknowledged)
        )
        (wipeAgentSecret encoded)
 where
  acknowledged reply
    | agentReplySucceeded reply = Right ()
    | otherwise = Left (oauthProblem ExternalFailure "The vault agent returned an unexpected OAuth mutation reply." [])

validateTokenForClient :: OAuthDeviceClient -> CredentialBinding -> OAuthTokenSet -> Either AppError ()
validateTokenForClient client binding tokenSet = do
  validateOAuthCredentialBinding client binding
  unless (oauthAuthorizationFingerprint tokenSet == deviceClientAuthorizationFingerprint client) $
    Left (oauthProblem PermissionRequired "The OAuth token set does not belong to this signed authorization." [])
  let requested = Set.delete "offline_access" (oauthDeviceScopes (deviceClientPermission client))
  unless (not (Set.null (oauthScopes tokenSet)) && oauthScopes tokenSet `Set.isSubsetOf` requested) $
    Left (oauthProblem PermissionRequired "The OAuth token set contains scopes outside the signed authorization." [])

newTlsOAuthFormTransport :: IO OAuthFormTransport
newTlsOAuthFormTransport = do
  manager <- Http.newManager tlsManagerSettings
  pure . OAuthFormTransport $ executeOAuthForm manager

executeOAuthForm :: Http.Manager -> OAuthFormRequest -> IO (Either AppError OAuthFormResponse)
executeOAuthForm manager request = case prepareOAuthRequest request of
  Left problem -> pure (Left problem)
  Right prepared -> do
    attempted <- try (Http.withResponse prepared manager readOAuthResponse)
    pure $ case attempted of
      Left (_ :: Http.HttpException) -> Left (oauthProblem ExternalFailure "The OAuth HTTPS request failed before a sanitized response was available." [])
      Right response -> response

prepareOAuthRequest :: OAuthFormRequest -> Either AppError Http.Request
prepareOAuthRequest request = do
  parsed <- case Http.parseRequest (Text.unpack (oauthFormEndpoint request)) of
    Nothing -> Left (oauthProblem InvalidInput "The signed OAuth endpoint could not be parsed by the trusted transport." [])
    Just value -> Right value
  let body = renderSimpleQuery False [(TextEncoding.encodeUtf8 key, TextEncoding.encodeUtf8 value) | (key, value) <- Map.toAscList (oauthFormFields request)]
  unless (ByteString.length body <= maximumOAuthRequestBytes) $
    Left (oauthProblem PreconditionFailed "The OAuth form request exceeds its bounded size." [])
  pure
    parsed
      { Http.method = "POST"
      , Http.requestHeaders = [(Header.hAccept, "application/json"), (Header.hContentType, "application/x-www-form-urlencoded")]
      , Http.requestBody = Http.RequestBodyBS body
      , Http.redirectCount = 0
      , Http.responseTimeout = Http.responseTimeoutMicro oauthTimeoutMicros
      , Http.cookieJar = Nothing
      , Http.proxy = Nothing
      , Http.decompress = const False
      }

readOAuthResponse :: Http.Response Http.BodyReader -> IO (Either AppError OAuthFormResponse)
readOAuthResponse response = readBoundedOAuthBody (Http.responseBody response) >>= pure . (>>= decodeBody)
 where
  decodeBody bytes = do
    value <- either (const (Left (oauthProblem ExternalFailure "The OAuth endpoint returned a non-JSON response." []))) Right (eitherDecodeStrict' bytes)
    pure (OAuthFormResponse (statusCode (Http.responseStatus response)) value)

readBoundedOAuthBody :: Http.BodyReader -> IO (Either AppError ByteString)
readBoundedOAuthBody reader = go 0 []
 where
  go total chunks = do
    chunk <- Http.brRead reader
    if ByteString.null chunk
      then pure (Right (ByteString.concat (reverse chunks)))
      else do
        let next = total + ByteString.length chunk
        if next > maximumOAuthResponseBytes
          then pure (Left (oauthProblem PreconditionFailed "The OAuth response exceeds its bounded size." []))
          else go next (chunk : chunks)

parseDeviceAuthorization :: UTCTime -> OAuthFormResponse -> Either AppError DeviceAuthorizationSession
parseDeviceAuthorization now response
  | oauthFormStatus response /= 200 = Left (oauthEndpointError "device authorization" response)
  | otherwise = parseJson "device authorization" parser (oauthFormJson response)
 where
  parser = withObject "DeviceAuthorizationResponse" $ \fields -> do
    deviceCode <- boundedText "device_code" maximumDeviceCodeCharacters fields
    userCode <- boundedText "user_code" maximumUserCodeCharacters fields
    verificationUri <- boundedText "verification_uri" maximumUriCharacters fields
    either (fail . Text.unpack) pure (validateVerificationUri verificationUri)
    expiresIn <- boundedSeconds "expires_in" maximumDeviceLifetimeSeconds fields
    interval <- boundedSeconds "interval" maximumPollIntervalSeconds fields
    pure $
      DeviceAuthorizationSession
        deviceCode
        (DeviceAuthorizationPrompt userCode verificationUri (addUTCTime (fromIntegral expiresIn) now) interval)

parsePollResponse :: UTCTime -> OAuthDeviceClient -> DeviceAuthorizationSession -> OAuthFormResponse -> Either AppError DeviceAuthorizationPoll
parsePollResponse now client session response
  | oauthFormStatus response >= 200 && oauthFormStatus response < 300 =
      DeviceAuthorizationSucceeded <$> parseTokenResponse now client Nothing response
  | otherwise = do
      code <- oauthErrorCode response
      case code of
        "authorization_pending" -> Right (DeviceAuthorizationPending interval session)
        "slow_down" ->
          let slowed = min maximumPollIntervalSeconds (interval + 5)
              updated = session{deviceSessionPrompt = (deviceSessionPrompt session){devicePromptPollingIntervalSeconds = slowed}}
           in Right (DeviceAuthorizationPending slowed updated)
        "authorization_declined" -> Right DeviceAuthorizationDeclined
        "expired_token" -> Right DeviceAuthorizationExpired
        "bad_verification_code" -> Left (oauthProblem ExternalFailure "The OAuth server rejected the device authorization session." [code])
        _ -> Left (oauthProblem ExternalFailure "The OAuth token endpoint rejected device authorization." [code])
 where
  interval = devicePromptPollingIntervalSeconds (deviceSessionPrompt session)

parseRefreshResponse :: UTCTime -> OAuthDeviceClient -> Text -> OAuthFormResponse -> Either AppError OAuthTokenSet
parseRefreshResponse now client priorRefresh response
  | oauthFormStatus response >= 200 && oauthFormStatus response < 300 = parseTokenResponse now client (Just priorRefresh) response
  | otherwise = do
      code <- oauthErrorCode response
      Left
        ( (oauthProblem PermissionRequired "The OAuth refresh grant is no longer usable; reconnect this account." [code])
            { appErrorRetrySafety = DoNotRetry
            , appErrorRecovery = [RecoveryAction "reconnect" "Start a new reviewed device authorization without changing canonical data." Nothing]
            }
        )

parseTokenResponse :: UTCTime -> OAuthDeviceClient -> Maybe Text -> OAuthFormResponse -> Either AppError OAuthTokenSet
parseTokenResponse now client priorRefresh response = parseJson "token" parser (oauthFormJson response)
 where
  requested = oauthDeviceScopes (deviceClientPermission client)
  parser = withObject "OAuthTokenResponse" $ \fields -> do
    tokenType <- fields .: "token_type"
    unless (tokenType == ("Bearer" :: Text)) (fail "unsupported token type")
    accessToken <- boundedText "access_token" maximumAccessTokenCharacters fields
    expiresIn <- boundedSeconds "expires_in" maximumAccessTokenLifetimeSeconds fields
    grantedText <- boundedText "scope" maximumScopeResponseCharacters fields
    let granted = Set.fromList (Text.words grantedText)
        accessRequested = Set.delete "offline_access" requested
    when (Set.null granted || not (granted `Set.isSubsetOf` accessRequested)) (fail "the granted scopes are not a nonempty subset of the signed request")
    refresh <- fields .:? "refresh_token"
    let effectiveRefresh = refresh <|> priorRefresh
    when ("offline_access" `Set.member` requested && maybe True Text.null effectiveRefresh) (fail "offline_access did not yield a refresh token")
    let tokenSet =
          OAuthTokenSet
            { oauthAccessToken = accessToken
            , oauthRefreshToken = effectiveRefresh
            , oauthExpiresAt = addUTCTime (fromIntegral expiresIn) now
            , oauthScopes = granted
            , oauthAuthorizationFingerprint = deviceClientAuthorizationFingerprint client
            }
    either (fail . Text.unpack . appErrorMessage) (const (pure tokenSet)) (encodeOAuthTokenSet tokenSet)

oauthErrorCode :: OAuthFormResponse -> Either AppError Text
oauthErrorCode response = parseJson "error" (withObject "OAuthError" (boundedText "error" 128)) (oauthFormJson response)

oauthEndpointError :: Text -> OAuthFormResponse -> AppError
oauthEndpointError stage response =
  case oauthErrorCode response of
    Left _ -> oauthProblem ExternalFailure ("The OAuth " <> stage <> " endpoint rejected the request.") [Text.pack (show (oauthFormStatus response))]
    Right code -> oauthProblem ExternalFailure ("The OAuth " <> stage <> " endpoint rejected the request.") [code]

parseJson :: Text -> (Value -> Parser value) -> Value -> Either AppError value
parseJson label parser value =
  either
    (const (Left (oauthProblem ExternalFailure ("The OAuth " <> label <> " response has an invalid shape.") [])))
    Right
    (parseEither parser value)

boundedText :: Text -> Int -> Object -> Parser Text
boundedText key limit fields = do
  value <- fields .: Key.fromText key
  when (Text.null value || Text.length value > limit) (fail (Text.unpack key <> " is outside its bound"))
  pure value

boundedSeconds :: Text -> Int -> Object -> Parser Int
boundedSeconds key limit fields = do
  value <- fields .: Key.fromText key
  when (value <= 0 || value > limit) (fail (Text.unpack key <> " is outside its bound"))
  pure value

configurationText :: Text -> Value -> Either AppError Text
configurationText key = \case
  Object fields -> case KeyMap.lookup (Key.fromText key) fields of
    Just (String value) -> Right value
    _ -> Left (oauthProblem InvalidInput "The provider account lacks the signed OAuth client-id configuration value." [key])
  _ -> Left (oauthProblem InvalidInput "Provider-account configuration must be an object." [])

validateClientId :: Text -> Either AppError ()
validateClientId clientId =
  unless
    ( not (Text.null clientId)
        && Text.length clientId <= 256
        && Text.all (\character -> character >= '\x21' && character <= '\x7e') clientId
    )
    (Left (oauthProblem InvalidInput "The OAuth client ID must be bounded visible ASCII." []))

validateVerificationUri :: Text -> Either Text ()
validateVerificationUri supplied = do
  uri <- maybe (Left "verification_uri is not an absolute URI") Right (parseURI (Text.unpack supplied))
  unless (uriScheme uri == "https:") (Left "verification_uri must use HTTPS")
  authority <- maybe (Left "verification_uri has no authority") Right (uriAuthority uri)
  unless (null (uriUserInfo authority) && null (uriPort authority) && not (null (uriRegName authority))) $
    Left "verification_uri has an unsafe authority"
  unless (null (uriQuery uri) && null (uriFragment uri)) (Left "verification_uri cannot contain a query or fragment")

authorizationFingerprint :: RegisteredPackComponent -> OAuthDeviceAuthorizationPermission -> Text -> Either AppError Text
authorizationFingerprint registered permission clientId =
  sha256Hex
    <$> canonicalJsonBytes
      ( object
          [ "schema" .= ("little-ant/oauth-authorization-binding@1" :: Text)
          , "artifact" .= registeredPackIdentity registered
          , "component" .= componentId (componentCommon (registeredComponent registered))
          , "credential_slot" .= oauthDeviceCredentialSlot permission
          , "device_authorization_endpoint" .= oauthDeviceAuthorizationEndpoint permission
          , "token_endpoint" .= oauthDeviceTokenEndpoint permission
          , "client_id" .= clientId
          , "scopes" .= Set.toAscList (oauthDeviceScopes permission)
          ]
      )

executablePermissions :: RegisteredPackComponent -> Either AppError ComponentPermissions
executablePermissions registered = case registeredComponent registered of
  ExecutableComponent _ _ permissions -> Right permissions
  _ -> Left (oauthProblem PreconditionFailed "A declarative Pack component cannot declare OAuth authorization." [])

renderScopes :: Set Text -> Text
renderScopes = Text.unwords . Set.toAscList

oauthProblem :: ErrorCode -> Text -> [Text] -> AppError
oauthProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRetrySafety = DoNotRetry
    , appErrorRecovery = [RecoveryAction "provider-connection" "Inspect the signed provider authorization and reconnect if needed." Nothing]
    }

maximumOAuthRequestBytes, maximumOAuthResponseBytes, oauthTimeoutMicros :: Int
maximumOAuthRequestBytes = 64 * 1024
maximumOAuthResponseBytes = 1024 * 1024
oauthTimeoutMicros = 30 * 1000 * 1000

maximumDeviceCodeCharacters, maximumUserCodeCharacters, maximumUriCharacters, maximumScopeResponseCharacters, maximumAccessTokenCharacters :: Int
maximumDeviceCodeCharacters = 16 * 1024
maximumUserCodeCharacters = 256
maximumUriCharacters = 4 * 1024
maximumScopeResponseCharacters = 16 * 1024
maximumAccessTokenCharacters = 16 * 1024

maximumDeviceLifetimeSeconds, maximumPollIntervalSeconds, maximumAccessTokenLifetimeSeconds :: Int
maximumDeviceLifetimeSeconds = 24 * 60 * 60
maximumPollIntervalSeconds = 5 * 60
maximumAccessTokenLifetimeSeconds = 24 * 60 * 60

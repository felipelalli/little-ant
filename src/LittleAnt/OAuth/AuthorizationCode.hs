module LittleAnt.OAuth.AuthorizationCode (
  OAuthPkceClient,
  resolveOAuthPkceClient,
  validateOAuthPkceCredentialBinding,
  oauthPkceAuthorizationFingerprint,
  oauthPkceClientConfigurationKey,
  oauthPkceRequestedScopes,
  OAuthLoopbackReceiver (..),
  OAuthAuthorizationCodeRuntime (..),
  newLoopbackReceiver,
  runAuthorizationCodePkce,
  refreshOAuthPkceTokenSet,
  persistOAuthPkceTokenSet,
) where

import Control.Applicative ((<|>))
import Control.Exception (bracket, bracketOnError, finally)
import Control.Monad (unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.ByteString.Char8 qualified as ByteString8
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (UTCTime, addUTCTime)
import LittleAnt.Error
import LittleAnt.OAuth.Device (OAuthFormRequest (..), OAuthFormResponse (..), OAuthFormTransport (..))
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Transport (OAuthTokenSet (..), encodeOAuthTokenSet)
import LittleAnt.Profile
import LittleAnt.Store (sha256Hex)
import LittleAnt.Vault qualified as Vault
import LittleAnt.Vault.Agent
import Network.HTTP.Types.URI (parseQueryText, renderSimpleQuery)
import Network.Socket
import Network.Socket.ByteString qualified as SocketBytes
import System.Timeout (timeout)

data OAuthPkceClient = OAuthPkceClient
  { pkceClientId :: Text
  , pkceClientPermission :: OAuthAuthorizationCodePkcePermission
  , pkceClientAuthorizationFingerprint :: Text
  }

newtype OAuthLoopbackReceiver = OAuthLoopbackReceiver
  { withOAuthLoopbackReceiver :: (Text -> IO (Either AppError ())) -> IO (Either AppError (Text, Map Text Text))
  }

data OAuthAuthorizationCodeRuntime = OAuthAuthorizationCodeRuntime
  { oauthPkceEntropy :: Int -> IO ByteString
  , oauthPkceLoopbackReceiver :: OAuthLoopbackReceiver
  , oauthPkcePresentAuthorizationUrl :: Text -> IO ()
  , oauthPkceCurrentTime :: IO UTCTime
  }

resolveOAuthPkceClient :: RegisteredPackComponent -> ProviderAccount -> Text -> Either AppError OAuthPkceClient
resolveOAuthPkceClient registered account slotId = do
  permissions <- executablePermissions registered
  permission <- case filter ((== slotId) . oauthPkceCredentialSlot) (permissionOAuthAuthorizationCodePkce permissions) of
    [value] -> Right value
    [] -> Left (oauthProblem PreconditionFailed "The signed component has no OAuth authorization-code PKCE permission for this credential slot." [slotId])
    _ -> Left (oauthProblem CorruptData "The signed component has ambiguous OAuth authorization-code PKCE permissions." [slotId])
  clientId <- configurationText (oauthPkceClientIdConfigurationKey permission) (providerAccountConfiguration account)
  validateClientId clientId
  fingerprint <- authorizationFingerprint registered permission clientId
  pure (OAuthPkceClient clientId permission fingerprint)

validateOAuthPkceCredentialBinding :: OAuthPkceClient -> CredentialBinding -> Either AppError ()
validateOAuthPkceCredentialBinding client binding = do
  unless (credentialBindingScheme binding == Vault.OAuthAuthorizationCodePKCE) $
    invalid "The CredentialBinding scheme does not match OAuth authorization-code PKCE."
  unless (credentialBindingSlot binding == oauthPkceCredentialSlot (pkceClientPermission client)) $
    invalid "The CredentialBinding slot does not match the signed OAuth authorization."
  unless (credentialBindingAuthorizationFingerprint binding == Just (pkceClientAuthorizationFingerprint client)) $
    Left
      ( (oauthProblem PermissionRequired "The provider authorization changed and requires fresh human consent." [credentialBindingSlot binding])
          { appErrorRecovery = [RecoveryAction "reconnect" "Review the exact client and scopes, then reconnect this account." Nothing]
          }
      )
 where
  invalid message = Left (oauthProblem PreconditionFailed message [credentialBindingSlot binding])

oauthPkceAuthorizationFingerprint :: OAuthPkceClient -> Text
oauthPkceAuthorizationFingerprint = pkceClientAuthorizationFingerprint

oauthPkceClientConfigurationKey :: OAuthPkceClient -> Text
oauthPkceClientConfigurationKey = oauthPkceClientIdConfigurationKey . pkceClientPermission

oauthPkceRequestedScopes :: OAuthPkceClient -> Set Text
oauthPkceRequestedScopes = oauthPkceScopes . pkceClientPermission

runAuthorizationCodePkce :: OAuthAuthorizationCodeRuntime -> OAuthFormTransport -> OAuthPkceClient -> IO (Either AppError OAuthTokenSet)
runAuthorizationCodePkce runtime transport client = do
  verifierEntropy <- oauthPkceEntropy runtime 64
  stateEntropy <- oauthPkceEntropy runtime 32
  case buildSecrets verifierEntropy stateEntropy of
    Left problem -> pure (Left problem)
    Right (verifier, challenge, state) ->
      ( withOAuthLoopbackReceiver (oauthPkceLoopbackReceiver runtime) $ \redirectUri -> do
          let url = authorizationUrl client redirectUri challenge state
          oauthPkcePresentAuthorizationUrl runtime url
          pure (Right ())
      )
        >>= \case
          Left problem -> pure (Left problem)
          Right (redirectUri, callback) -> case authorizationCode state callback of
            Left problem -> pure (Left problem)
            Right code -> do
              now <- oauthPkceCurrentTime runtime
              exchangeCode transport now client verifier code redirectUri

refreshOAuthPkceTokenSet :: OAuthFormTransport -> UTCTime -> OAuthPkceClient -> OAuthTokenSet -> IO (Either AppError OAuthTokenSet)
refreshOAuthPkceTokenSet transport now client previous
  | oauthAuthorizationFingerprint previous /= pkceClientAuthorizationFingerprint client =
      pure . Left $ oauthProblem PermissionRequired "The stored OAuth grant belongs to a different signed authorization." []
  | otherwise = case oauthRefreshToken previous of
      Nothing -> pure . Left $ oauthProblem PermissionRequired "The stored OAuth grant has no refresh token; reconnect this account." []
      Just refreshToken -> do
        let request =
              OAuthFormRequest
                (oauthPkceTokenEndpoint (pkceClientPermission client))
                ( Map.fromList
                    [ ("client_id", pkceClientId client)
                    , ("grant_type", "refresh_token")
                    , ("refresh_token", refreshToken)
                    ]
                )
        runOAuthFormTransport transport request >>= pure . (>>= parseTokenResponse now client (Just previous) False)

persistOAuthPkceTokenSet :: FilePath -> OAuthPkceClient -> CredentialBinding -> Text -> OAuthTokenSet -> IO (Either AppError ())
persistOAuthPkceTokenSet socketPath client binding label tokenSet = case validateTokenForClient client binding tokenSet of
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

newLoopbackReceiver :: IO OAuthLoopbackReceiver
newLoopbackReceiver = pure (OAuthLoopbackReceiver receiveLoopback)

receiveLoopback :: (Text -> IO (Either AppError ())) -> IO (Either AppError (Text, Map Text Text))
receiveLoopback begin = bracket open close $ \listener -> do
  address <- getSocketName listener
  case address of
    SockAddrInet port host
      | host == tupleToHostAddress (127, 0, 0, 1) -> do
          let portText = Text.pack (show (fromIntegral port :: Int))
              redirectUri = "http://127.0.0.1:" <> portText <> callbackPath
              expectedHost = "127.0.0.1:" <> portText
          begin redirectUri >>= \case
            Left problem -> pure (Left problem)
            Right () -> do
              received <- timeout loopbackTimeoutMicros $
                bracket (accept listener) (close . fst) $ \(connected, peer) -> do
                  callback <- receiveRequest connected peer expectedHost
                  SocketBytes.sendAll connected (browserResponse (either (const False) (const True) callback))
                  pure callback
              case received of
                Nothing -> pure . Left $ oauthProblem PreconditionFailed "The OAuth loopback authorization timed out." []
                Just callback -> pure ((redirectUri,) <$> callback)
    _ -> pure . Left $ oauthProblem ExternalFailure "The OAuth loopback listener did not bind an IPv4 loopback address." []
 where
  open = bracketOnError (socket AF_INET Stream defaultProtocol) close $ \listener -> do
    setSocketOption listener ReuseAddr 1
    bind listener (SockAddrInet 0 (tupleToHostAddress (127, 0, 0, 1)))
    listen listener 1
    pure listener

receiveRequest :: Socket -> SockAddr -> Text -> IO (Either AppError (Map Text Text))
receiveRequest connection peer expectedHost
  | not (isLoopbackPeer peer) = pure . Left $ oauthProblem PermissionRequired "The OAuth callback did not originate from loopback." []
  | otherwise = readHeaders connection >>= pure . (>>= parseCallback expectedHost)

readHeaders :: Socket -> IO (Either AppError ByteString)
readHeaders connection = go ByteString.empty
 where
  go accumulated
    | ByteString.length accumulated > maximumCallbackBytes = pure . Left $ oauthProblem PreconditionFailed "The OAuth callback request exceeds its bounded size." []
    | "\r\n\r\n" `ByteString.isInfixOf` accumulated = pure (Right accumulated)
    | otherwise = do
        chunk <- SocketBytes.recv connection 4096
        if ByteString.null chunk
          then pure . Left $ oauthProblem ExternalFailure "The OAuth callback closed before sending complete headers." []
          else go (accumulated <> chunk)

parseCallback :: Text -> ByteString -> Either AppError (Map Text Text)
parseCallback expectedHost bytes = do
  decoded <- either (const (Left malformed)) Right (TextEncoding.decodeUtf8' bytes)
  let lines' = Text.splitOn "\r\n" decoded
  requestLine <- case lines' of
    value : _ -> Right value
    [] -> Left malformed
  target <- case Text.words requestLine of
    ["GET", value, "HTTP/1.1"] -> Right value
    _ -> Left malformed
  let (path, queryWithMarker) = Text.breakOn "?" target
  unless (path == callbackPath && not (Text.null queryWithMarker)) (Left malformed)
  host <- singleHeader "host" (drop 1 lines')
  unless (host == expectedHost) (Left (oauthProblem PermissionRequired "The OAuth callback Host header does not match the bound loopback listener." []))
  uniqueQuery (TextEncoding.encodeUtf8 (Text.drop 1 queryWithMarker))
 where
  malformed = oauthProblem InvalidInput "The OAuth callback request is malformed." []

singleHeader :: Text -> [Text] -> Either AppError Text
singleHeader requested lines' = case values of
  [value] | not (Text.null value) -> Right value
  _ -> Left (oauthProblem InvalidInput "The OAuth callback contains a missing or ambiguous required header." [requested])
 where
  values =
    [ Text.strip (Text.drop 1 rest)
    | line <- lines'
    , let (name, rest) = Text.breakOn ":" line
    , Text.toLower name == requested
    , not (Text.null rest)
    ]

uniqueQuery :: ByteString -> Either AppError (Map Text Text)
uniqueQuery encoded = foldl insertOne (Right Map.empty) (parseQueryText encoded)
 where
  insertOne prior (key, maybeValue) = do
    values <- prior
    value <- maybe (Left malformed) Right maybeValue
    when (Text.null key || Map.member key values) (Left malformed)
    pure (Map.insert key value values)
  malformed = oauthProblem InvalidInput "The OAuth callback query is malformed or ambiguous." []

authorizationCode :: Text -> Map Text Text -> Either AppError Text
authorizationCode expectedState callback = do
  state <- maybe (Left malformed) Right (Map.lookup "state" callback)
  unless (state == expectedState) (Left (oauthProblem PermissionRequired "The OAuth callback state did not match the active authorization." []))
  case (Map.lookup "code" callback, Map.lookup "error" callback) of
    (Just code, Nothing) | not (Text.null code) && Text.length code <= maximumAuthorizationCodeCharacters -> Right code
    (Nothing, Just "access_denied") -> Left (oauthProblem PermissionRequired "The provider authorization was declined." [])
    (Nothing, Just failure) -> Left (oauthProblem ExternalFailure "The provider authorization endpoint returned an error." [Text.take 128 failure])
    _ -> Left malformed
 where
  malformed = oauthProblem InvalidInput "The OAuth callback contains neither one authorization code nor one provider error." []

exchangeCode :: OAuthFormTransport -> UTCTime -> OAuthPkceClient -> Text -> Text -> Text -> IO (Either AppError OAuthTokenSet)
exchangeCode transport now client verifier code redirectUri = do
  let request =
        OAuthFormRequest
          (oauthPkceTokenEndpoint (pkceClientPermission client))
          ( Map.fromList
              [ ("client_id", pkceClientId client)
              , ("code", code)
              , ("code_verifier", verifier)
              , ("grant_type", "authorization_code")
              , ("redirect_uri", redirectUri)
              ]
          )
  runOAuthFormTransport transport request >>= pure . (>>= parseTokenResponse now client Nothing True)

parseTokenResponse :: UTCTime -> OAuthPkceClient -> Maybe OAuthTokenSet -> Bool -> OAuthFormResponse -> Either AppError OAuthTokenSet
parseTokenResponse now client previous requireNewRefresh response
  | oauthFormStatus response < 200 || oauthFormStatus response >= 300 = Left (oauthEndpointError response)
  | otherwise = parseJson parser (oauthFormJson response)
 where
  requested = oauthPkceScopes (pkceClientPermission client)
  parser = withObject "OAuthTokenResponse" $ \fields -> do
    tokenType <- fields .: "token_type"
    unless (tokenType == ("Bearer" :: Text)) (fail "unsupported token type")
    accessToken <- boundedText "access_token" maximumAccessTokenCharacters fields
    expiresIn <- boundedSeconds "expires_in" maximumAccessTokenLifetimeSeconds fields
    grantedText <- fields .:? "scope"
    granted <- case grantedText of
      Nothing -> maybe (fail "authorization code exchange omitted granted scopes") (pure . oauthScopes) previous
      Just value -> do
        bounded <- boundedTextValue "scope" maximumScopeResponseCharacters value
        pure (Set.fromList (Text.words bounded))
    when (Set.null granted || not (granted `Set.isSubsetOf` requested)) (fail "the granted scopes are not a nonempty subset of the signed request")
    refresh <- fields .:? "refresh_token"
    let effectiveRefresh = refresh <|> (oauthRefreshToken =<< previous)
    when (requireNewRefresh && maybe True Text.null refresh) (fail "authorization code exchange did not yield a refresh token")
    let tokenSet =
          OAuthTokenSet
            { oauthAccessToken = accessToken
            , oauthRefreshToken = effectiveRefresh
            , oauthExpiresAt = addUTCTime (fromIntegral expiresIn) now
            , oauthScopes = granted
            , oauthAuthorizationFingerprint = pkceClientAuthorizationFingerprint client
            }
    either (fail . Text.unpack . appErrorMessage) (const (pure tokenSet)) (encodeOAuthTokenSet tokenSet)

boundedTextValue :: Text -> Int -> Text -> Parser Text
boundedTextValue label maximumLength value
  | Text.null value || Text.length value > maximumLength = fail (Text.unpack label <> " is empty or exceeds its bound")
  | otherwise = pure value

validateTokenForClient :: OAuthPkceClient -> CredentialBinding -> OAuthTokenSet -> Either AppError ()
validateTokenForClient client binding tokenSet = do
  validateOAuthPkceCredentialBinding client binding
  unless (oauthAuthorizationFingerprint tokenSet == pkceClientAuthorizationFingerprint client) $
    Left (oauthProblem PermissionRequired "The OAuth token set does not belong to this signed authorization." [])
  unless (not (Set.null (oauthScopes tokenSet)) && oauthScopes tokenSet `Set.isSubsetOf` oauthPkceScopes (pkceClientPermission client)) $
    Left (oauthProblem PermissionRequired "The OAuth token set contains scopes outside the signed authorization." [])
  unless (maybe False (not . Text.null) (oauthRefreshToken tokenSet)) $
    Left (oauthProblem PermissionRequired "The OAuth token set has no refresh token; reconnect this account." [])

authorizationUrl :: OAuthPkceClient -> Text -> Text -> Text -> Text
authorizationUrl client redirectUri challenge state =
  oauthPkceAuthorizationEndpoint permission
    <> TextEncoding.decodeUtf8
      ( renderSimpleQuery
          True
          [ (TextEncoding.encodeUtf8 key, TextEncoding.encodeUtf8 value)
          | (key, value) <- Map.toAscList fields
          ]
      )
 where
  permission = pkceClientPermission client
  fields =
    Map.fromList
      [ ("client_id", pkceClientId client)
      , ("code_challenge", challenge)
      , ("code_challenge_method", "S256")
      , ("redirect_uri", redirectUri)
      , ("response_type", "code")
      , ("scope", Text.unwords (Set.toAscList (oauthPkceScopes permission)))
      , ("state", state)
      ]
      <> oauthPkceAuthorizationParameters permission

buildSecrets :: ByteString -> ByteString -> Either AppError (Text, Text, Text)
buildSecrets verifierEntropy stateEntropy = do
  unless (ByteString.length verifierEntropy == 64 && ByteString.length stateEntropy == 32) $
    Left (oauthProblem ExternalFailure "The host returned the wrong amount of OAuth PKCE entropy." [])
  let verifierBytes = Base64Url.encodeUnpadded verifierEntropy
      verifier = TextEncoding.decodeUtf8 verifierBytes
      challenge = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded (SHA256.hash verifierBytes))
      state = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded stateEntropy)
  pure (verifier, challenge, state)

authorizationFingerprint :: RegisteredPackComponent -> OAuthAuthorizationCodePkcePermission -> Text -> Either AppError Text
authorizationFingerprint registered permission clientId =
  sha256Hex
    <$> canonicalJsonBytes
      ( object
          [ "schema" .= ("little-ant/oauth-authorization-binding@1" :: Text)
          , "scheme" .= ("oauth2_authorization_code_pkce" :: Text)
          , "artifact" .= registeredPackIdentity registered
          , "component" .= componentId (componentCommon (registeredComponent registered))
          , "credential_slot" .= oauthPkceCredentialSlot permission
          , "authorization_endpoint" .= oauthPkceAuthorizationEndpoint permission
          , "token_endpoint" .= oauthPkceTokenEndpoint permission
          , "client_id" .= clientId
          , "scopes" .= Set.toAscList (oauthPkceScopes permission)
          , "authorization_parameters" .= oauthPkceAuthorizationParameters permission
          ]
      )

configurationText :: Text -> Value -> Either AppError Text
configurationText key = \case
  Object fields -> case KeyMap.lookup (Key.fromText key) fields of
    Just (String value) -> Right value
    _ -> Left (oauthProblem InvalidInput "The provider account lacks the signed OAuth client-id configuration value." [key])
  _ -> Left (oauthProblem InvalidInput "Provider-account configuration must be an object." [])

validateClientId :: Text -> Either AppError ()
validateClientId clientId =
  unless
    (not (Text.null clientId) && Text.length clientId <= 256 && Text.all (\character -> character >= '\x21' && character <= '\x7e') clientId)
    (Left (oauthProblem InvalidInput "The OAuth client ID must be bounded visible ASCII." []))

executablePermissions :: RegisteredPackComponent -> Either AppError ComponentPermissions
executablePermissions registered = case registeredComponent registered of
  ExecutableComponent _ _ permissions -> Right permissions
  _ -> Left (oauthProblem PreconditionFailed "A declarative Pack component cannot declare OAuth authorization." [])

parseJson :: (Value -> Parser value) -> Value -> Either AppError value
parseJson parser value =
  either (const (Left (oauthProblem ExternalFailure "The OAuth token response has an invalid shape." []))) Right (parseEither parser value)

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

oauthEndpointError :: OAuthFormResponse -> AppError
oauthEndpointError response =
  let code = case parseEither (withObject "OAuthError" (boundedText "error" 128)) (oauthFormJson response) of
        Left _ -> Text.pack (show (oauthFormStatus response))
        Right value -> value
   in oauthProblem ExternalFailure "The OAuth token endpoint rejected the authorization." [code]

isLoopbackPeer :: SockAddr -> Bool
isLoopbackPeer = \case
  SockAddrInet _ host -> host == tupleToHostAddress (127, 0, 0, 1)
  _ -> False

browserResponse :: Bool -> ByteString
browserResponse succeeded =
  let title = if succeeded then "Authorization received" else "Authorization failed"
      body = if succeeded then "Return to Little Ant to continue." else "Return to Little Ant and review the error."
      html = "<!doctype html><meta charset=utf-8><meta http-equiv=Content-Security-Policy content=\"default-src 'none'; style-src 'unsafe-inline'\"><title>" <> title <> "</title><style>body{font:16px system-ui;margin:3rem;max-width:42rem}</style><h1>" <> title <> "</h1><p>" <> body <> "</p>"
   in ByteString8.pack
        ( "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: "
            <> show (length html)
            <> "\r\n\r\n"
            <> html
        )

oauthProblem :: ErrorCode -> Text -> [Text] -> AppError
oauthProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRetrySafety = DoNotRetry
    , appErrorRecovery = [RecoveryAction "provider-connection" "Inspect the signed provider authorization and reconnect if needed." Nothing]
    }

callbackPath :: Text
callbackPath = "/oauth/callback"

maximumCallbackBytes, maximumAuthorizationCodeCharacters, maximumAccessTokenCharacters, maximumScopeResponseCharacters, maximumAccessTokenLifetimeSeconds, loopbackTimeoutMicros :: Int
maximumCallbackBytes = 32 * 1024
maximumAuthorizationCodeCharacters = 4096
maximumAccessTokenCharacters = 16 * 1024
maximumScopeResponseCharacters = 16 * 1024
maximumAccessTokenLifetimeSeconds = 31 * 24 * 3600
loopbackTimeoutMicros = 5 * 60 * 1_000_000

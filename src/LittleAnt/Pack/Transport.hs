module LittleAnt.Pack.Transport (
  AccessToken,
  accessTokenFromBytes,
  accessTokenBytes,
  AccessTokenResolver (..),
  OAuthTokenSet (..),
  encodeOAuthTokenSet,
  accessTokenFromVaultSecret,
  vaultAgentAccessTokenResolver,
  CredentialedHttpRequest (..),
  PackHttpTransport (..),
  credentialBoundPackHttpBroker,
  newTlsPackHttpTransport,
)
where

import Control.Exception (finally, try)
import Control.Monad (unless, when)
import Data.Aeson (FromJSON (..), ToJSON (..), Value (Null), eitherDecodeStrict', object, withObject, (.:), (.:?), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.CaseInsensitive qualified as CI
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (NominalDiffTime, UTCTime, addUTCTime)
import LittleAnt.Error
import LittleAnt.Pack.Format qualified as Pack
import LittleAnt.Pack.Http
import LittleAnt.Pack.Registry
import LittleAnt.Profile
import LittleAnt.Vault qualified as Vault
import LittleAnt.Vault.Agent
import Network.HTTP.Client qualified as Http
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Header qualified as Header
import Network.HTTP.Types.Status (statusCode)

newtype AccessToken = AccessToken ByteString

accessTokenFromBytes :: ByteString -> Either AppError AccessToken
accessTokenFromBytes supplied
  | ByteString.null supplied = Left (transportProblem InvalidInput "The resolved provider access token is empty.")
  | ByteString.length supplied > maximumAccessTokenBytes = Left (transportProblem PreconditionFailed "The resolved provider access token exceeds its bounded size.")
  | ByteString.any unsafe supplied = Left (transportProblem InvalidInput "The resolved provider access token contains an unsafe byte.")
  | otherwise = Right (AccessToken supplied)
 where
  unsafe byte = byte < 0x21 || byte > 0x7e

accessTokenBytes :: AccessToken -> ByteString
accessTokenBytes (AccessToken bytes) = bytes

newtype AccessTokenResolver = AccessTokenResolver
  { resolveAccessToken :: CredentialBinding -> IO (Either AppError AccessToken)
  }

data OAuthTokenSet = OAuthTokenSet
  { oauthAccessToken :: Text
  , oauthRefreshToken :: Maybe Text
  , oauthExpiresAt :: UTCTime
  , oauthScopes :: Set.Set Text
  }
  deriving stock (Eq)

encodeOAuthTokenSet :: OAuthTokenSet -> Either AppError ByteString
encodeOAuthTokenSet tokenSet = validateOAuthTokenSet tokenSet >> Pack.canonicalJsonBytes (toJSON tokenSet)

accessTokenFromVaultSecret :: UTCTime -> CredentialBinding -> ByteString -> Either AppError AccessToken
accessTokenFromVaultSecret now binding secret = case credentialBindingScheme binding of
  Vault.BearerCredential -> accessTokenFromBytes secret
  Vault.OAuthAuthorizationCodePKCE -> oauthToken
  Vault.OAuthDeviceAuthorization -> oauthToken
  Vault.ApiKeyCredential -> Left (bindingProblem "An API-key CredentialBinding cannot satisfy a bearer-token HTTP slot." [])
 where
  oauthToken = do
    tokenSet <-
      either
        (const (Left (bindingProblem "The OAuth credential payload is not a supported token set." [])))
        Right
        (eitherDecodeStrict' secret)
    validateOAuthTokenSet tokenSet
    whenExpired tokenSet
    accessTokenFromBytes (TextEncoding.encodeUtf8 (oauthAccessToken tokenSet))
  whenExpired tokenSet =
    unless
      (now < addUTCTime (-oauthExpirySkewSeconds) (oauthExpiresAt tokenSet))
      ( Left
          ( (appError PermissionRequired "The provider credential needs OAuth refresh before it can be used.")
              { appErrorRetrySafety = RetryAfterRefresh
              , appErrorRecovery = [RecoveryAction "refresh" "Refresh or reconnect this provider account, then return to the same import intention." Nothing]
              }
          )
      )

vaultAgentAccessTokenResolver :: FilePath -> IO UTCTime -> AccessTokenResolver
vaultAgentAccessTokenResolver socketPath currentTime = AccessTokenResolver $ \binding -> do
  resolved <- sendVaultAgentRequest socketPath (agentResolveRequest (credentialBindingVaultEntry binding) "source_read")
  case resolved of
    Left problem -> pure (Left problem)
    Right reply -> case agentReplySecret reply of
      Nothing -> pure . Left $ bindingProblem "The vault agent returned no credential material for this binding." []
      Just secret ->
        finally
          (do now <- currentTime; pure (accessTokenFromVaultSecret now binding secret))
          (wipeAgentSecret secret)

data CredentialedHttpRequest = CredentialedHttpRequest
  { credentialedRequest :: BrokerHttpRequest
  , credentialedAccessToken :: AccessToken
  }

newtype PackHttpTransport = PackHttpTransport
  { runPackHttpTransport :: CredentialedHttpRequest -> IO (Either AppError BrokerHttpResponse)
  }

credentialBoundPackHttpBroker :: RegisteredPackComponent -> CredentialBinding -> AccessTokenResolver -> PackHttpTransport -> Either AppError PackHttpBroker
credentialBoundPackHttpBroker registered binding resolver transport = do
  permissions <- componentPermissions registered
  let component = Pack.componentId (Pack.componentCommon (registeredComponent registered))
  unless (credentialBindingComponent binding == component) $
    Left (bindingProblem "The CredentialBinding component does not match the selected SourceAdapter." [component, credentialBindingComponent binding])
  unless ("source_read" `Set.member` credentialBindingPurposes binding) $
    Left (bindingProblem "The CredentialBinding does not grant the source_read purpose." [component])
  slot <-
    case filter ((== credentialBindingSlot binding) . Pack.credentialSlotId) (Pack.permissionCredentialSlots permissions) of
      [value] -> Right value
      [] -> Left (bindingProblem "The CredentialBinding slot is absent from the signed component." [credentialBindingSlot binding])
      _ -> Left (bindingProblem "The signed component contains an ambiguous credential slot." [credentialBindingSlot binding])
  unless (schemeMatches (credentialBindingScheme binding) (Pack.credentialSlotScheme slot)) $
    Left (bindingProblem "The CredentialBinding scheme does not match the signed component slot." [Vault.credentialSchemeName (credentialBindingScheme binding)])
  pure . PackHttpBroker $ \permission request ->
    case authorizeBrokerHttpRequest permissions request of
      Left problem -> pure (Left problem)
      Right authorized
        | authorized /= permission -> pure . Left $ bindingProblem "The supplied HTTP permission is not the route authorized for this request." []
        | Pack.httpPermissionCredentialSlot permission /= Just (credentialBindingSlot binding) ->
            pure . Left $ bindingProblem "The authorized HTTP route references a different credential slot." [credentialBindingSlot binding]
        | otherwise ->
            resolveAccessToken resolver binding >>= \case
              Left problem -> pure (Left problem)
              Right token -> runPackHttpTransport transport (CredentialedHttpRequest request token)

newTlsPackHttpTransport :: IO PackHttpTransport
newTlsPackHttpTransport = do
  manager <- Http.newManager tlsManagerSettings
  pure (PackHttpTransport (executeTls manager))

executeTls :: Http.Manager -> CredentialedHttpRequest -> IO (Either AppError BrokerHttpResponse)
executeTls manager credentialed =
  case prepareRequest credentialed of
    Left problem -> pure (Left problem)
    Right request -> do
      attempted <- try (Http.withResponse request manager readResponse)
      pure $ case attempted of
        Left (_ :: Http.HttpException) -> Left networkProblem
        Right response -> response

prepareRequest :: CredentialedHttpRequest -> Either AppError Http.Request
prepareRequest credentialed = do
  let brokerRequest = credentialedRequest credentialed
  _ <- validateBrokerHttpRequest brokerRequest
  parsed <-
    case Http.parseRequest (Text.unpack (brokerHttpUrl brokerRequest)) of
      Nothing -> Left (transportProblem InvalidInput "The trusted HTTPS transport could not parse the authorized URL.")
      Just request -> Right request
  body <- traverse Pack.canonicalJsonBytes (brokerHttpJson brokerRequest)
  let suppliedHeaders =
        [ (CI.mk (TextEncoding.encodeUtf8 name), TextEncoding.encodeUtf8 value)
        | (name, value) <- Map.toAscList (brokerHttpHeaders brokerRequest)
        ]
      requestHeaders =
        (Header.hAuthorization, "Bearer " <> accessTokenBytes (credentialedAccessToken credentialed))
          : maybe suppliedHeaders (const ((Header.hContentType, "application/json") : suppliedHeaders)) body
  pure
    parsed
      { Http.method = TextEncoding.encodeUtf8 (brokerHttpMethod brokerRequest)
      , Http.requestHeaders = requestHeaders
      , Http.requestBody = maybe (Http.RequestBodyBS ByteString.empty) (Http.RequestBodyLBS . LazyByteString.fromStrict) body
      , Http.redirectCount = 0
      , Http.responseTimeout = Http.responseTimeoutMicro transportTimeoutMicros
      , Http.cookieJar = Nothing
      , Http.proxy = Nothing
      , Http.decompress = const False
      }

readResponse :: Http.Response Http.BodyReader -> IO (Either AppError BrokerHttpResponse)
readResponse response =
  readBoundedBody (Http.responseBody response) >>= \case
    Left problem -> pure (Left problem)
    Right bytes ->
      pure $ do
        value <-
          if ByteString.null bytes
            then Right Null
            else either (const (Left (transportProblem ExternalFailure "The provider returned a non-JSON response body."))) Right (eitherDecodeStrict' bytes)
        let sanitized =
              BrokerHttpResponse
                { brokerHttpStatus = statusCode (Http.responseStatus response)
                , brokerHttpResponseHeaders = responseHeaders (Http.responseHeaders response)
                , brokerHttpResponseJson = value
                }
        validateBrokerHttpResponse sanitized
        Right sanitized

readBoundedBody :: Http.BodyReader -> IO (Either AppError ByteString)
readBoundedBody reader = go 0 []
 where
  go total chunks = do
    chunk <- Http.brRead reader
    if ByteString.null chunk
      then pure (Right (ByteString.concat (reverse chunks)))
      else do
        let next = total + ByteString.length chunk
        if next > maximumResponseBytes
          then pure (Left (transportProblem PreconditionFailed "The provider response exceeds the trusted transport body limit."))
          else go next (chunk : chunks)

responseHeaders :: [(CI.CI ByteString, ByteString)] -> Map Text Text
responseHeaders = Map.fromList . mapMaybe sanitize
 where
  sanitize (name, value)
    | normalized `Set.member` allowedResponseHeaders =
        case TextEncoding.decodeUtf8' value of
          Left _ -> Nothing
          Right decoded -> Just (normalized, decoded)
    | otherwise = Nothing
   where
    normalized = TextEncoding.decodeUtf8 (CI.foldedCase name)

componentPermissions :: RegisteredPackComponent -> Either AppError Pack.ComponentPermissions
componentPermissions registered = case registeredComponent registered of
  Pack.ExecutableComponent _ _ permissions -> Right permissions
  _ -> Left (bindingProblem "A declarative Pack component cannot use provider credentials." [])

schemeMatches :: Vault.CredentialScheme -> Pack.CredentialScheme -> Bool
schemeMatches vaultScheme packScheme = case (vaultScheme, packScheme) of
  (Vault.OAuthAuthorizationCodePKCE, Pack.OAuthAuthorizationCodePkce) -> True
  (Vault.OAuthDeviceAuthorization, Pack.OAuthDeviceAuthorization) -> True
  (Vault.BearerCredential, Pack.BearerToken) -> True
  (Vault.ApiKeyCredential, Pack.ApiKey) -> True
  _ -> False

instance ToJSON OAuthTokenSet where
  toJSON tokenSet =
    object $
      [ "schema" .= ("little-ant/oauth-token-set@1" :: Text)
      , "token_type" .= ("Bearer" :: Text)
      , "access_token" .= oauthAccessToken tokenSet
      , "expires_at" .= oauthExpiresAt tokenSet
      , "scopes" .= Set.toAscList (oauthScopes tokenSet)
      ]
        <> maybe [] (pure . ("refresh_token" .=)) (oauthRefreshToken tokenSet)

instance FromJSON OAuthTokenSet where
  parseJSON = withObject "OAuthTokenSet" $ \fields -> do
    rejectUnknown fields ["schema", "token_type", "access_token", "refresh_token", "expires_at", "scopes"]
    schema <- fields .: "schema"
    unless (schema == ("little-ant/oauth-token-set@1" :: Text)) (fail "unsupported OAuth token-set schema")
    tokenType <- fields .: "token_type"
    unless (tokenType == ("Bearer" :: Text)) (fail "unsupported OAuth token type")
    OAuthTokenSet
      <$> fields .: "access_token"
      <*> fields .:? "refresh_token"
      <*> fields .: "expires_at"
      <*> (Set.fromList <$> fields .: "scopes")

validateOAuthTokenSet :: OAuthTokenSet -> Either AppError ()
validateOAuthTokenSet tokenSet = do
  _ <- accessTokenFromBytes (TextEncoding.encodeUtf8 (oauthAccessToken tokenSet))
  when (any (Text.null . Text.strip) (Set.toList (oauthScopes tokenSet))) $
    Left (bindingProblem "The OAuth credential contains an empty scope." [])
  case oauthRefreshToken tokenSet of
    Just refresh | Text.null refresh -> Left (bindingProblem "The OAuth credential contains an empty refresh token." [])
    _ -> Right ()

rejectUnknown :: KeyMap.KeyMap value -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

bindingProblem :: Text -> [Text] -> AppError
bindingProblem message details =
  (transportProblem PreconditionFailed message)
    { appErrorDetails = details
    , appErrorRecovery = [RecoveryAction "configure-binding" "Inspect the provider account and its local CredentialBinding." (Just "lant config show")]
    }

transportProblem :: ErrorCode -> Text -> AppError
transportProblem code message =
  (appError code message)
    { appErrorRetrySafety = DoNotRetry
    , appErrorRecovery = [RecoveryAction "retry-provider" "Check the provider connection and retry without changing canonical data." Nothing]
    }

networkProblem :: AppError
networkProblem =
  (appError ExternalFailure "The trusted HTTPS request failed before a sanitized provider response was available.")
    { appErrorRetrySafety = RetrySafe
    , appErrorRecovery = [RecoveryAction "retry-provider" "Check the provider connection and retry the read-only preflight." Nothing]
    }

allowedResponseHeaders :: Set.Set Text
allowedResponseHeaders = Set.fromList ["content-type", "etag", "preference-applied", "retry-after"]

maximumAccessTokenBytes, maximumResponseBytes, transportTimeoutMicros :: Int
maximumAccessTokenBytes = 16 * 1024
maximumResponseBytes = 16 * 1024 * 1024
transportTimeoutMicros = 30 * 1000 * 1000

oauthExpirySkewSeconds :: NominalDiffTime
oauthExpirySkewSeconds = 60

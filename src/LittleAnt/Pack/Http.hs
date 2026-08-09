module LittleAnt.Pack.Http (
  BrokerHttpRequest (..),
  BrokerHttpResponse (..),
  BrokerHttpExchange (..),
  PackHttpBroker (..),
  authorizeBrokerHttpRequest,
  validateBrokerHttpRequest,
  validateBrokerHttpResponse,
  validateBrokerHttpTranscript,
) where

import Control.Monad (unless, when)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.ByteString qualified as ByteString
import Data.Char (digitToInt, isAscii, isAsciiLower, isDigit, isHexDigit, ord)
import Data.Either (fromRight)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import LittleAnt.Error
import LittleAnt.Pack.Format
import Network.URI (URI (..), URIAuth (..), parseURI)

data BrokerHttpRequest = BrokerHttpRequest
  { brokerHttpMethod :: Text
  , brokerHttpUrl :: Text
  , brokerHttpHeaders :: Map Text Text
  , brokerHttpJson :: Maybe Value
  }
  deriving stock (Eq, Show)

data BrokerHttpResponse = BrokerHttpResponse
  { brokerHttpStatus :: Int
  , brokerHttpResponseHeaders :: Map Text Text
  , brokerHttpResponseJson :: Value
  }
  deriving stock (Eq, Show)

data BrokerHttpExchange = BrokerHttpExchange
  { brokerExchangeRequest :: BrokerHttpRequest
  , brokerExchangeResponse :: BrokerHttpResponse
  }
  deriving stock (Eq, Show)

newtype PackHttpBroker = PackHttpBroker
  { runPackHttpBroker :: HttpPermission -> BrokerHttpRequest -> IO (Either AppError BrokerHttpResponse)
  }

authorizeBrokerHttpRequest :: ComponentPermissions -> BrokerHttpRequest -> Either AppError HttpPermission
authorizeBrokerHttpRequest permissions request = do
  (_, host, path) <- validateBrokerHttpRequest request
  case filter (matches host path) (permissionHttp permissions) of
    [permission] -> Right permission
    [] -> Left (httpProblem PermissionRequired "The Pack requested an HTTP route outside its signed component permissions." [brokerHttpMethod request, brokerHttpUrl request])
    _ -> Left (httpProblem CorruptData "The signed component has ambiguous overlapping HTTP permissions for one request." [brokerHttpMethod request, brokerHttpUrl request])
 where
  matches host path permission =
    brokerHttpMethod request `elem` httpPermissionMethods permission
      && host == httpPermissionHost permission
      && pathWithin (httpPermissionPathPrefix permission) path

validateBrokerHttpRequest :: BrokerHttpRequest -> Either AppError (URI, Text, Text)
validateBrokerHttpRequest request = do
  unless (brokerHttpMethod request `elem` ["GET", "POST", "PUT", "PATCH", "DELETE"]) $
    invalid "The brokered HTTP method is outside the closed method catalog."
  unless (Text.length (brokerHttpUrl request) <= maximumUrlCharacters) $
    invalid "The brokered HTTP URL exceeds its bounded size."
  uri <- maybe (invalid "The brokered HTTP URL is not an absolute URI.") Right (parseURI (Text.unpack (brokerHttpUrl request)))
  unless (uriScheme uri == "https:") $ invalid "Brokered HTTP requires HTTPS."
  authority <- maybe (invalid "The brokered HTTP URL has no authority.") Right (uriAuthority uri)
  unless (null (uriUserInfo authority) && null (uriPort authority)) $
    invalid "The brokered HTTP URL cannot contain user information or an explicit port."
  let host = Text.pack (uriRegName authority)
  unless (validHost host) $ invalid "The brokered HTTP URL host is not canonical lowercase ASCII DNS."
  unless (null (uriFragment uri)) $ invalid "The brokered HTTP URL cannot contain a fragment."
  unless (length (uriQuery uri) <= maximumQueryCharacters) $ invalid "The brokered HTTP query exceeds its bounded size."
  path <- strictDecodePath (Text.pack (uriPath uri))
  validateDecodedPath path
  validateHeaders requestHeaderNames (brokerHttpHeaders request)
  case brokerHttpJson request of
    Nothing -> pure ()
    Just body -> do
      when (brokerHttpMethod request `elem` ["GET", "DELETE"]) $
        invalid "GET and DELETE broker requests cannot contain a JSON body."
      validateJsonSize maximumRequestJsonBytes "The brokered HTTP request JSON exceeds its bounded size." body
  pure (uri, host, path)
 where
  invalid message = Left (httpProblem InvalidInput message [brokerHttpMethod request, brokerHttpUrl request])

validateBrokerHttpResponse :: BrokerHttpResponse -> Either AppError ()
validateBrokerHttpResponse response = do
  unless (brokerHttpStatus response >= 100 && brokerHttpStatus response <= 599) $
    invalid "The brokered HTTP response status is invalid."
  validateHeaders responseHeaderNames (brokerHttpResponseHeaders response)
  validateJsonSize maximumResponseJsonBytes "The brokered HTTP response JSON exceeds its bounded size." (brokerHttpResponseJson response)
 where
  invalid message = Left (httpProblem ExternalFailure message [Text.pack (show (brokerHttpStatus response))])

validateBrokerHttpTranscript :: [BrokerHttpExchange] -> Either AppError ()
validateBrokerHttpTranscript exchanges = do
  unless (length exchanges <= maximumTranscriptExchanges) $
    invalid "The brokered HTTP transcript contains too many exchanges."
  mapM_ validateExchange exchanges
  encoded <- canonicalJsonBytes (toJSON exchanges)
  unless (ByteString.length encoded <= maximumTranscriptBytes) $
    invalid "The brokered HTTP transcript exceeds its cumulative byte limit."
  let requests = brokerExchangeRequest <$> exchanges
  unless (length requests == Set.size (Set.fromList (requestIdentity <$> requests))) $
    invalid "The Pack repeated an identical brokered HTTP request in one invocation."
 where
  validateExchange exchange = validateBrokerHttpRequest (brokerExchangeRequest exchange) >> validateBrokerHttpResponse (brokerExchangeResponse exchange)
  requestIdentity = fromRight ByteString.empty . canonicalJsonBytes . toJSON
  invalid message = Left (httpProblem PreconditionFailed message [])

instance ToJSON BrokerHttpRequest where
  toJSON request =
    object $
      [ "method" .= brokerHttpMethod request
      , "url" .= brokerHttpUrl request
      , "headers" .= brokerHttpHeaders request
      ]
        <> maybe [] (pure . ("json" .=)) (brokerHttpJson request)

instance FromJSON BrokerHttpRequest where
  parseJSON = withObject "BrokerHttpRequest" $ \fields -> do
    rejectUnknown fields ["method", "url", "headers", "json"]
    request <- BrokerHttpRequest <$> fields .: "method" <*> fields .: "url" <*> fields .: "headers" <*> fields .:? "json"
    either (fail . Text.unpack . appErrorMessage) (const (pure request)) (validateBrokerHttpRequest request)

instance ToJSON BrokerHttpResponse where
  toJSON response =
    object
      [ "status" .= brokerHttpStatus response
      , "headers" .= brokerHttpResponseHeaders response
      , "json" .= brokerHttpResponseJson response
      ]

instance FromJSON BrokerHttpResponse where
  parseJSON = withObject "BrokerHttpResponse" $ \fields -> do
    rejectUnknown fields ["status", "headers", "json"]
    response <- BrokerHttpResponse <$> fields .: "status" <*> fields .: "headers" <*> fields .: "json"
    either (fail . Text.unpack . appErrorMessage) (const (pure response)) (validateBrokerHttpResponse response)

instance ToJSON BrokerHttpExchange where
  toJSON exchange = object ["request" .= brokerExchangeRequest exchange, "response" .= brokerExchangeResponse exchange]

instance FromJSON BrokerHttpExchange where
  parseJSON = withObject "BrokerHttpExchange" $ \fields -> do
    rejectUnknown fields ["request", "response"]
    BrokerHttpExchange <$> fields .: "request" <*> fields .: "response"

pathWithin :: Text -> Text -> Bool
pathWithin prefix path = path == prefix || (prefix <> "/") `Text.isPrefixOf` path || prefix == "/"

strictDecodePath :: Text -> Either AppError Text
strictDecodePath raw = do
  bytes <- go (Text.unpack raw)
  either (const (invalid "The brokered HTTP path is not canonical UTF-8.")) Right (TextEncoding.decodeUtf8' (ByteString.pack (fromIntegral <$> bytes)))
 where
  go [] = Right []
  go ('%' : high : low : rest)
    | isHexDigit high && isHexDigit low = ((digitToInt high * 16 + digitToInt low) :) <$> go rest
  go ('%' : _) = invalid "The brokered HTTP path contains an invalid percent escape."
  go (character : rest)
    | isAscii character = (ord character :) <$> go rest
    | otherwise = invalid "Non-ASCII URL path characters must be percent encoded."
  invalid message = Left (httpProblem InvalidInput message [raw])

validateDecodedPath :: Text -> Either AppError ()
validateDecodedPath path = do
  unless ("/" `Text.isPrefixOf` path) $ invalid "The brokered HTTP path must be absolute."
  unless (Text.length path <= maximumPathCharacters) $ invalid "The brokered HTTP path exceeds its bounded size."
  when (Text.any (\character -> character == '\0' || character == '\\') path) $
    invalid "The brokered HTTP path contains an unsafe character."
  unless (path == "/" || all validSegment (Text.splitOn "/" (Text.drop 1 path))) $
    invalid "The brokered HTTP path contains an empty, dot, or dot-dot segment."
 where
  validSegment segment = not (Text.null segment) && segment /= "." && segment /= ".."
  invalid message = Left (httpProblem InvalidInput message [path])

validateHeaders :: Set.Set Text -> Map Text Text -> Either AppError ()
validateHeaders allowed headers = do
  unless (Map.size headers <= maximumHeaderCount) $ invalid "The brokered HTTP header count exceeds its bounded limit."
  mapM_ validateHeader (Map.toList headers)
 where
  validateHeader (name, value) = do
    unless (name `Set.member` allowed) $ invalid "The brokered HTTP request contains a header outside the closed allowlist."
    unless (Text.length value <= maximumHeaderValueCharacters && Text.all printable value) $
      invalid "A brokered HTTP header value is invalid or too large."
  printable character = isAscii character && ord character >= 0x20 && ord character <= 0x7e
  invalid message = Left (httpProblem PermissionRequired message (Map.keys headers))

validateJsonSize :: Int -> Text -> Value -> Either AppError ()
validateJsonSize limit message value = do
  encoded <- canonicalJsonBytes value
  unless (ByteString.length encoded <= limit) (Left (httpProblem PreconditionFailed message []))

validHost :: Text -> Bool
validHost host =
  not (Text.null host)
    && host == Text.toLower host
    && Text.all (\character -> isAsciiLower character || isDigit character || character == '.' || character == '-') host
    && all validLabel (Text.splitOn "." host)
 where
  validLabel label =
    not (Text.null label)
      && Text.head label /= '-'
      && Text.last label /= '-'

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

httpProblem :: ErrorCode -> Text -> [Text] -> AppError
httpProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRecovery = [RecoveryAction "inspect-pack-http" "Inspect the signed component HTTP permissions and retry through the trusted host." Nothing]
    }

requestHeaderNames :: Set.Set Text
requestHeaderNames = Set.fromList ["accept", "if-match", "if-none-match", "prefer"]

responseHeaderNames :: Set.Set Text
responseHeaderNames = Set.fromList ["content-type", "etag", "preference-applied", "retry-after"]

maximumUrlCharacters, maximumPathCharacters, maximumQueryCharacters, maximumHeaderValueCharacters :: Int
maximumUrlCharacters = 16 * 1024
maximumPathCharacters = 8 * 1024
maximumQueryCharacters = 8 * 1024
maximumHeaderValueCharacters = 2 * 1024

maximumHeaderCount, maximumTranscriptExchanges :: Int
maximumHeaderCount = 16
maximumTranscriptExchanges = 64

maximumRequestJsonBytes, maximumResponseJsonBytes, maximumTranscriptBytes :: Int
maximumRequestJsonBytes = 1024 * 1024
maximumResponseJsonBytes = 16 * 1024 * 1024
maximumTranscriptBytes = 16 * 1024 * 1024

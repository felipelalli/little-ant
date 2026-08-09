module LittleAnt.Pack.Runner (
  PackRunnerClient (..),
  PackRunnerLimits (..),
  factoryPackRunnerLimits,
  defaultPackRunnerClient,
  RunnerExportArtifact (..),
  invokePackExporter,
  invokePackSourcePreflight,
  invokePackSourceMaterialize,
  runPackRunnerMain,
)
where

import Codec.Archive.Zip qualified as Zip
import Control.Concurrent (forkFinally, newEmptyMVar, putMVar, takeMVar, threadDelay)
import Control.Exception (Exception, IOException, SomeException, catch, displayException, try)
import Control.Monad (filterM, forM, unless, void, when)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base16 qualified as Base16
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAscii, isAsciiLower, isAsciiUpper, isDigit)
import Data.Digest.CRC32 (crc32)
import Data.Foldable (traverse_)
import Data.List (find, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.Encoding.Error qualified as TextError
import Data.Text.IO qualified as TextIO
import GHC.Clock (getMonotonicTimeNSec)
import HsLua qualified as Lua
import LittleAnt.Error
import LittleAnt.Model (SourceMode (..))
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Trust
import LittleAnt.Source
import LittleAnt.Store (sha256Hex)
import System.Directory (doesFileExist, executable, findExecutable, getPermissions)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))
import System.IO (Handle, hClose, hFlush, hSetBinaryMode, stderr, stdin, stdout)
import System.Posix.Resource
import System.Process
import Text.Read (readMaybe)

data PackRunnerLimits = PackRunnerLimits
  { runnerWallTimeoutMicros :: Int
  , runnerMaximumRequestBytes :: Int
  , runnerMaximumResponseBytes :: Int
  , runnerMaximumArtifactBytes :: Int
  }
  deriving stock (Eq, Show)

data PackRunnerClient = PackRunnerClient
  { packRunnerExecutable :: FilePath
  , packRunnerLimits :: PackRunnerLimits
  }
  deriving stock (Eq, Show)

data RunnerExportArtifact = RunnerExportArtifact
  { runnerArtifactBytes :: ByteString
  , runnerArtifactMediaType :: Text
  , runnerArtifactSuggestedFilename :: FilePath
  , runnerArtifactWarnings :: [Text]
  , runnerArtifactMetadata :: Map Text Text
  }
  deriving stock (Eq, Show)

data RunnerRequest = RunnerRequest
  { requestArtifact :: PackArtifactIdentity
  , requestSignerFingerprint :: Text
  , requestComponentId :: Text
  , requestContractMajor :: Int
  , requestEntryPoint :: Text
  , requestPayload :: Map Text ByteString
  , requestProjection :: Value
  , requestOperation :: RunnerOperation
  , requestInputBytes :: Maybe ByteString
  , requestMaximumArtifactBytes :: Int
  }
  deriving stock (Eq, Show)

data RunnerOperation = RunnerExport | RunnerSourcePreflight | RunnerSourceMaterialize
  deriving stock (Eq, Show)

data RunnerFailure = RunnerFailure
  { runnerFailureKind :: Text
  , runnerFailureMessage :: Text
  }
  deriving stock (Eq, Show)

data RunnerResponse
  = RunnerSucceeded RunnerExportArtifact
  | RunnerFailed RunnerFailure
  deriving stock (Eq, Show)

factoryPackRunnerLimits :: PackRunnerLimits
factoryPackRunnerLimits =
  PackRunnerLimits
    { runnerWallTimeoutMicros = 5_000_000
    , runnerMaximumRequestBytes = 96 * 1024 * 1024
    , runnerMaximumResponseBytes = 24 * 1024 * 1024
    , runnerMaximumArtifactBytes = 16 * 1024 * 1024
    }

defaultPackRunnerClient :: IO PackRunnerClient
defaultPackRunnerClient = do
  host <- getExecutablePath
  let binaryDirectory = takeDirectory host
      installRoot = takeDirectory binaryDirectory
      installed = installRoot </> "libexec" </> "little-ant" </> "lant-pack-runner"
      development = binaryDirectory </> "lant-pack-runner"
      classicBuilds = fmap (\root -> root </> "lant-pack-runner" </> "lant-pack-runner") (take 12 (ancestors binaryDirectory))
  local <- filterM doesFileExist (installed : development : classicBuilds)
  fromPath <- findExecutable "lant-pack-runner"
  pure (PackRunnerClient (firstAvailable installed local fromPath) factoryPackRunnerLimits)
 where
  firstAvailable fallback candidates fromPath = case candidates <> maybe [] pure fromPath of
    candidate : _ -> candidate
    [] -> fallback
  ancestors path =
    let parent = takeDirectory path
     in path : if parent == path then [] else ancestors parent

instance ToJSON RunnerRequest where
  toJSON request =
    object $
      [ "schema" .= ("little-ant/pack-runner-request@1" :: Text)
      , "artifact" .= requestArtifact request
      , "signer_fingerprint" .= requestSignerFingerprint request
      , "component_id" .= requestComponentId request
      , "contract_major" .= requestContractMajor request
      , "entry_point" .= requestEntryPoint request
      , "payload" .= fmap encodeBytes (requestPayload request)
      , "projection" .= requestProjection request
      , "operation" .= runnerOperationName (requestOperation request)
      , "maximum_artifact_bytes" .= requestMaximumArtifactBytes request
      ]
        <> maybe [] (pure . ("input_bytes" .=) . encodeBytes) (requestInputBytes request)

instance FromJSON RunnerRequest where
  parseJSON = withObject "RunnerRequest" $ \fields -> do
    rejectUnknown fields ["schema", "artifact", "signer_fingerprint", "component_id", "contract_major", "entry_point", "payload", "projection", "operation", "input_bytes", "maximum_artifact_bytes"]
    requireSchema fields "little-ant/pack-runner-request@1"
    encodedPayload <- fields .: "payload"
    payload <- traverse (either fail pure . decodeBytes) encodedPayload
    RunnerRequest
      <$> fields .: "artifact"
      <*> fields .: "signer_fingerprint"
      <*> fields .: "component_id"
      <*> fields .: "contract_major"
      <*> fields .: "entry_point"
      <*> pure payload
      <*> fields .: "projection"
      <*> (fields .: "operation" >>= parseRunnerOperation)
      <*> (fields .:? "input_bytes" >>= traverse (either fail pure . decodeBytes))
      <*> fields .: "maximum_artifact_bytes"

runnerOperationName :: RunnerOperation -> Text
runnerOperationName = \case
  RunnerExport -> "export"
  RunnerSourcePreflight -> "source_preflight"
  RunnerSourceMaterialize -> "source_materialize"

parseRunnerOperation :: Text -> Parser RunnerOperation
parseRunnerOperation = \case
  "export" -> pure RunnerExport
  "source_preflight" -> pure RunnerSourcePreflight
  "source_materialize" -> pure RunnerSourceMaterialize
  value -> fail ("unknown runner operation: " <> Text.unpack value)

instance ToJSON RunnerExportArtifact where
  toJSON artifact =
    object
      [ "bytes" .= encodeBytes (runnerArtifactBytes artifact)
      , "media_type" .= runnerArtifactMediaType artifact
      , "suggested_filename" .= runnerArtifactSuggestedFilename artifact
      , "warnings" .= runnerArtifactWarnings artifact
      , "metadata" .= runnerArtifactMetadata artifact
      ]

instance FromJSON RunnerExportArtifact where
  parseJSON = withObject "RunnerExportArtifact" $ \fields -> do
    rejectUnknown fields ["bytes", "media_type", "suggested_filename", "warnings", "metadata"]
    encoded <- fields .: "bytes"
    bytes <- either fail pure (decodeBytes encoded)
    RunnerExportArtifact bytes
      <$> fields .: "media_type"
      <*> fields .: "suggested_filename"
      <*> fields .: "warnings"
      <*> fields .: "metadata"

instance ToJSON RunnerFailure where
  toJSON failure = object ["kind" .= runnerFailureKind failure, "message" .= runnerFailureMessage failure]

instance FromJSON RunnerFailure where
  parseJSON = withObject "RunnerFailure" $ \fields -> do
    rejectUnknown fields ["kind", "message"]
    RunnerFailure <$> fields .: "kind" <*> fields .: "message"

instance ToJSON RunnerResponse where
  toJSON = \case
    RunnerSucceeded artifact ->
      object
        [ "schema" .= ("little-ant/pack-runner-response@1" :: Text)
        , "ok" .= True
        , "artifact" .= artifact
        ]
    RunnerFailed failure ->
      object
        [ "schema" .= ("little-ant/pack-runner-response@1" :: Text)
        , "ok" .= False
        , "error" .= failure
        ]

instance FromJSON RunnerResponse where
  parseJSON = withObject "RunnerResponse" $ \fields -> do
    requireSchema fields "little-ant/pack-runner-response@1"
    succeeded <- fields .: "ok"
    if succeeded
      then rejectUnknown fields ["schema", "ok", "artifact"] >> RunnerSucceeded <$> fields .: "artifact"
      else rejectUnknown fields ["schema", "ok", "error"] >> RunnerFailed <$> fields .: "error"

invokePackExporter :: PackRunnerClient -> RegisteredPackComponent -> Value -> IO (Either AppError RunnerExportArtifact)
invokePackExporter client registered projection =
  case prepareRequest client registered RunnerExport Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> case canonicalJsonBytes (toJSON request) of
      Left problem -> pure (Left problem)
      Right requestBytes -> invokeRunnerProcess client requestBytes

invokePackSourcePreflight :: PackRunnerClient -> RegisteredPackComponent -> SourceMode -> SourceInput -> IO (Either AppError SourcePreflight)
invokePackSourcePreflight client registered mode input =
  case prepareRequest client registered RunnerSourcePreflight (Just (sourceInputBytes input)) projection of
    Left problem -> pure (Left problem)
    Right request -> case (canonicalJsonBytes (toJSON request), sourceInvocationAuthority registered) of
      (Left problem, _) -> pure (Left problem)
      (_, Left problem) -> pure (Left problem)
      (Right requestBytes, Right (contractMajor, permissions)) ->
        invokeRunnerProcess client requestBytes >>= \case
          Left problem -> pure (Left problem)
          Right artifact -> pure $ do
            observation <- decodeSourceObservation (runnerArtifactBytes artifact)
            makeSourcePreflight
              (componentId (componentCommon (registeredComponent registered)))
              (registeredPackIdentity registered)
              (registeredSignerFingerprint registered)
              contractMajor
              permissions
              mode
              input
              observation
 where
  projection =
    object
      [ "schema" .= ("little-ant/source-preflight-request@1" :: Text)
      , "mode" .= sourceModeName mode
      , "input"
          .= object
            [ "label" .= sourceInputLabel input
            , "media_type" .= sourceInputMediaType input
            , "digest" .= sha256Hex (sourceInputBytes input)
            , "byte_count" .= ByteString.length (sourceInputBytes input)
            ]
      ]

invokePackSourceMaterialize :: PackRunnerClient -> RegisteredPackComponent -> SourceMode -> SourceInput -> IO (Either AppError (SourcePreflight, SourceAdapterMaterialization))
invokePackSourceMaterialize client registered mode input =
  case prepareRequest client registered RunnerSourceMaterialize (Just (sourceInputBytes input)) projection of
    Left problem -> pure (Left problem)
    Right request -> case (canonicalJsonBytes (toJSON request), sourceInvocationAuthority registered) of
      (Left problem, _) -> pure (Left problem)
      (_, Left problem) -> pure (Left problem)
      (Right requestBytes, Right (contractMajor, permissions)) ->
        invokeRunnerProcess client requestBytes >>= \case
          Left problem -> pure (Left problem)
          Right artifact -> pure $ do
            materialization <- decodeSourceMaterialization (runnerArtifactBytes artifact)
            preflight <-
              makeSourcePreflight
                (componentId (componentCommon (registeredComponent registered)))
                (registeredPackIdentity registered)
                (registeredSignerFingerprint registered)
                contractMajor
                permissions
                mode
                input
                (materializedObservation materialization)
            pure (preflight, materialization)
 where
  projection =
    object
      [ "schema" .= ("little-ant/source-preflight-request@1" :: Text)
      , "mode" .= sourceModeName mode
      , "input"
          .= object
            [ "label" .= sourceInputLabel input
            , "media_type" .= sourceInputMediaType input
            , "digest" .= sha256Hex (sourceInputBytes input)
            , "byte_count" .= ByteString.length (sourceInputBytes input)
            ]
      ]

sourceInvocationAuthority :: RegisteredPackComponent -> Either AppError (Int, Text)
sourceInvocationAuthority registered =
  case registeredComponent registered of
    ExecutableComponent common _ permissions -> do
      encoded <- canonicalJsonBytes (toJSON permissions)
      pure (componentContractMajor common, TextEncoding.decodeUtf8 encoded)
    _ -> Left (runnerProblem Unsupported "A declarative Pack component has no executable invocation authority." [])

prepareRequest :: PackRunnerClient -> RegisteredPackComponent -> RunnerOperation -> Maybe ByteString -> Value -> Either AppError RunnerRequest
prepareRequest client registered operation input projection = do
  validateClientLimits (packRunnerLimits client)
  case registeredComponent registered of
    ExecutableComponent common entry permissions
      | componentKind common /= expectedKind -> Left (runnerProblem Unsupported wrongKindMessage [])
      | componentContractMajor common /= 1 -> Left (runnerProblem Unsupported "The selected component uses an unsupported host contract major." [Text.pack (show (componentContractMajor common))])
      | operation == RunnerExport && null (permissionProjections permissions) -> Left (runnerProblem CorruptData "The selected exporter declares no input projection." [])
      | operation `elem` [RunnerSourcePreflight, RunnerSourceMaterialize] && InputBytesCapability `notElem` permissionHostCapabilities permissions -> Left (runnerProblem PermissionRequired "The selected SourceAdapter did not declare the input_bytes host capability." [])
      | operation `elem` [RunnerSourcePreflight, RunnerSourceMaterialize] && isNothing input -> Left (runnerProblem PreconditionFailed "A file SourceAdapter invocation requires host-custodied input bytes." [])
      | otherwise -> do
          let payload = registeredComponentPayload registered
          entryBytes <- maybe (Left (runnerProblem CorruptData "The component entry point is absent from its authorized payload." [entry])) Right (Map.lookup entry payload)
          validateLuaSource entry entryBytes
          mapM_ (uncurry validatePayloadSource) (Map.toAscList payload)
          let limits = packRunnerLimits client
          pure
            RunnerRequest
              { requestArtifact = registeredPackIdentity registered
              , requestSignerFingerprint = registeredSignerFingerprint registered
              , requestComponentId = componentId common
              , requestContractMajor = componentContractMajor common
              , requestEntryPoint = entry
              , requestPayload = payload
              , requestProjection = projection
              , requestOperation = operation
              , requestInputBytes = input
              , requestMaximumArtifactBytes = runnerMaximumArtifactBytes limits
              }
    _ -> Left (runnerProblem Unsupported "Declarative Pack components cannot execute in the Lua runner." [])
 where
  expectedKind = case operation of
    RunnerExport -> ReadOnlyExporterComponent
    RunnerSourcePreflight -> SourceAdapterComponent
    RunnerSourceMaterialize -> SourceAdapterComponent
  wrongKindMessage = case operation of
    RunnerExport -> "The selected Pack component is not a read-only exporter."
    RunnerSourcePreflight -> "The selected Pack component is not a SourceAdapter."
    RunnerSourceMaterialize -> "The selected Pack component is not a SourceAdapter."

validatePayloadSource :: Text -> ByteString -> Either AppError ()
validatePayloadSource path bytes
  | ".lua" `Text.isSuffixOf` path = validateLuaSource path bytes
  | otherwise = Right ()

validateLuaSource :: Text -> ByteString -> Either AppError ()
validateLuaSource path bytes = do
  when (ByteString.isPrefixOf "\x1bLua" bytes) (Left (runnerProblem CorruptData "Precompiled Lua bytecode is not accepted." [path]))
  when (ByteString.elem 0 bytes) (Left (runnerProblem CorruptData "Lua source contains a NUL byte." [path]))
  case TextEncoding.decodeUtf8' bytes of
    Left _ -> Left (runnerProblem CorruptData "Lua source must be valid UTF-8 text." [path])
    Right _ -> pure ()

validateClientLimits :: PackRunnerLimits -> Either AppError ()
validateClientLimits limits = do
  unless (runnerWallTimeoutMicros limits > 0 && runnerWallTimeoutMicros limits <= runnerWallTimeoutMicros factoryPackRunnerLimits) invalid
  unless (runnerMaximumRequestBytes limits > 0 && runnerMaximumRequestBytes limits <= runnerMaximumRequestBytes factoryPackRunnerLimits) invalid
  unless (runnerMaximumResponseBytes limits > 0 && runnerMaximumResponseBytes limits <= runnerMaximumResponseBytes factoryPackRunnerLimits) invalid
  unless (runnerMaximumArtifactBytes limits > 0 && runnerMaximumArtifactBytes limits <= runnerMaximumArtifactBytes factoryPackRunnerLimits) invalid
 where
  invalid = Left (runnerProblem InvalidInput "Pack runner limits must be positive and cannot exceed the factory safety ceiling." [])

invokeRunnerProcess :: PackRunnerClient -> ByteString -> IO (Either AppError RunnerExportArtifact)
invokeRunnerProcess client requestBytes
  | ByteString.length requestBytes > runnerMaximumRequestBytes limits = pure (Left (runnerProblem PreconditionFailed "The Pack runner request exceeds its bounded size." []))
  | otherwise = do
      executableReady <- validateRunnerExecutable (packRunnerExecutable client)
      case executableReady of
        Left problem -> pure (Left problem)
        Right () -> runBoundedProcess
 where
  limits = packRunnerLimits client
  runBoundedProcess =
    handleRunnerIo $ withCreateProcess processSpec $ \maybeInput maybeOutput maybeError processHandle ->
      case (maybeInput, maybeOutput, maybeError) of
        (Just input, Just output, Just errorOutput) -> do
          mapM_ (`hSetBinaryMode` True) [input, output, errorOutput]
          outputResult <- newEmptyMVar
          errorResult <- newEmptyMVar
          void $ forkFinally (readBounded output (runnerMaximumResponseBytes limits)) (putMVar outputResult)
          void $ forkFinally (readBounded errorOutput maximumRunnerErrorBytes) (putMVar errorResult)
          writeResult <- try (ByteString.hPut input requestBytes >> hFlush input >> hClose input)
          case writeResult of
            Left problem -> terminateProcess processHandle >> waitForProcess processHandle >> pure (Left (runnerIoProblem (problem :: IOException)))
            Right () -> do
              completed <- waitForProcessBounded (runnerWallTimeoutMicros limits) processHandle
              case completed of
                Nothing -> do
                  terminateProcess processHandle
                  _ <- waitForProcess processHandle
                  pure (Left runnerTimeoutProblem)
                Just exitCode -> do
                  stdoutResult <- takeMVar outputResult
                  stderrResult <- takeMVar errorResult
                  pure (decodeProcessOutcome (runnerMaximumArtifactBytes limits) (exitCode, stdoutResult, stderrResult))
        _ -> pure (Left (runnerProblem ExternalFailure "The private Pack runner pipes could not be created." []))
  processSpec =
    (proc (packRunnerExecutable client) ["+RTS", "-M512m", "-K32m", "-RTS"])
      { cwd = Just "/"
      , env = Just [("LANG", "C.UTF-8"), ("LC_ALL", "C.UTF-8")]
      , std_in = CreatePipe
      , std_out = CreatePipe
      , std_err = CreatePipe
      , close_fds = True
      , create_group = True
      }

validateRunnerExecutable :: FilePath -> IO (Either AppError ())
validateRunnerExecutable path = do
  exists <- doesFileExist path
  if not exists
    then pure (Left (runnerProblem NotFound "The private Pack runner executable is unavailable." [Text.pack path]))
    else do
      permissions <- getPermissions path
      pure $ unless (executable permissions) (Left (runnerProblem PermissionRequired "The private Pack runner is not executable." [Text.pack path]))

decodeProcessOutcome :: Int -> (ExitCode, Either SomeException (Either () ByteString), Either SomeException (Either () ByteString)) -> Either AppError RunnerExportArtifact
decodeProcessOutcome maximumArtifactBytes (exitCode, stdoutResult, stderrResult) = do
  output <- flattenRead "stdout" stdoutResult
  errors <- flattenRead "stderr" stderrResult
  unless
    (exitCode == ExitSuccess)
    (Left (runnerProblem ExternalFailure "The private Pack runner exited unsuccessfully." (processDetails exitCode errors)))
  response <- decodeCanonicalResponse output
  case response of
    RunnerSucceeded artifact -> validateRunnerArtifact maximumArtifactBytes artifact >> Right artifact
    RunnerFailed failure -> Left (runnerProblem ExternalFailure "The Pack component failed in the isolated runner." [runnerFailureKind failure, runnerFailureMessage failure])

flattenRead :: Text -> Either SomeException (Either () ByteString) -> Either AppError ByteString
flattenRead label = \case
  Left problem -> Left (runnerProblem ExternalFailure ("The Pack runner " <> label <> " pipe failed.") [Text.pack (displayException problem)])
  Right (Left ()) -> Left (runnerProblem ExternalFailure ("The Pack runner " <> label <> " exceeded its bounded size.") [])
  Right (Right bytes) -> Right bytes

processDetails :: ExitCode -> ByteString -> [Text]
processDetails exitCode errors =
  ["exit: " <> Text.pack (show exitCode)]
    <> ["stderr: " <> boundedText errors | not (ByteString.null errors)]

decodeCanonicalResponse :: ByteString -> Either AppError RunnerResponse
decodeCanonicalResponse bytes = do
  value <- either (\problem -> Left (runnerProblem CorruptData "The Pack runner returned invalid JSON." [Text.pack problem])) Right (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (runnerProblem CorruptData "The Pack runner response is not canonical JSON." []))
  either (\problem -> Left (runnerProblem CorruptData "The Pack runner response violates its closed schema." [Text.pack problem])) Right (parseEither parseJSON value)

decodeSourceObservation :: ByteString -> Either AppError SourceAdapterObservation
decodeSourceObservation bytes = do
  value <- either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter returned invalid JSON." [Text.pack problem])) Right (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (runnerProblem CorruptData "The SourceAdapter observation is not canonical JSON." []))
  either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter observation violates its closed schema." [Text.pack problem])) Right (parseEither parseJSON value)

decodeSourceMaterialization :: ByteString -> Either AppError SourceAdapterMaterialization
decodeSourceMaterialization bytes = do
  value <- either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter materialization returned invalid JSON." [Text.pack problem])) Right (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (runnerProblem CorruptData "The SourceAdapter materialization is not canonical JSON." []))
  either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter materialization violates its closed schema." [Text.pack problem])) Right (parseEither parseJSON value)

runPackRunnerMain :: IO ()
runPackRunnerMain = do
  mapM_ (`hSetBinaryMode` True) [stdin, stdout, stderr]
  applyChildResourceLimits
  input <- readBounded stdin (runnerMaximumRequestBytes factoryPackRunnerLimits)
  response <- case input of
    Left () -> pure (RunnerFailed (RunnerFailure "request_too_large" "The runner request exceeds its bounded size."))
    Right bytes -> executeEncodedRequest bytes
  let encoded = canonicalJsonBytes (toJSON response)
  case encoded of
    Left problem -> emitEmergencyFailure (appErrorMessage problem)
    Right bytes -> ByteString.hPut stdout bytes >> hFlush stdout

executeEncodedRequest :: ByteString -> IO RunnerResponse
executeEncodedRequest bytes = case decodeCanonicalRequest bytes of
  Left problem -> pure (RunnerFailed (failureFromError "invalid_request" problem))
  Right request -> do
    result <- try (executeLuaRequest request)
    pure $ case result of
      Left problem -> RunnerFailed (RunnerFailure "lua_failure" (boundedException (problem :: SomeException)))
      Right (Left problem) -> RunnerFailed (failureFromError "invalid_result" problem)
      Right (Right artifact) -> RunnerSucceeded artifact

decodeCanonicalRequest :: ByteString -> Either AppError RunnerRequest
decodeCanonicalRequest bytes = do
  value <- either (\problem -> Left (runnerProblem CorruptData "The runner request is not valid JSON." [Text.pack problem])) Right (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (runnerProblem CorruptData "The runner request is not canonical JSON." []))
  request <- either (\problem -> Left (runnerProblem CorruptData "The runner request violates its closed schema." [Text.pack problem])) Right (parseEither parseJSON value)
  validateRunnerRequest request
  pure request

validateRunnerRequest :: RunnerRequest -> Either AppError ()
validateRunnerRequest request = do
  validateDigest "The request signer fingerprint" (requestSignerFingerprint request)
  unless (requestContractMajor request == 1) (Left (runnerProblem Unsupported "The runner supports only component contract major 1." []))
  unless (validComponentId (requestComponentId request)) (Left (runnerProblem CorruptData "The runner component ID is invalid." []))
  unless (safeRelativePath (requestEntryPoint request) && ".lua" `Text.isSuffixOf` requestEntryPoint request) (Left (runnerProblem CorruptData "The runner entry point is unsafe or is not Lua source." []))
  unless (requestMaximumArtifactBytes request > 0 && requestMaximumArtifactBytes request <= runnerMaximumArtifactBytes factoryPackRunnerLimits) (Left (runnerProblem CorruptData "The runner artifact limit exceeds its factory ceiling." []))
  entry <- maybe (Left (runnerProblem CorruptData "The runner entry point is missing from the payload." [])) Right (Map.lookup (requestEntryPoint request) (requestPayload request))
  validateLuaSource (requestEntryPoint request) entry
  mapM_ validatePayloadPathAndSource (Map.toAscList (requestPayload request))
  case (requestOperation request, requestInputBytes request) of
    (RunnerExport, Nothing) -> pure ()
    (RunnerExport, Just _) -> Left (runnerProblem CorruptData "An exporter request cannot contain source input bytes." [])
    (RunnerSourcePreflight, Just _) -> pure ()
    (RunnerSourcePreflight, Nothing) -> Left (runnerProblem CorruptData "A SourceAdapter preflight request is missing its input bytes." [])
    (RunnerSourceMaterialize, Just _) -> pure ()
    (RunnerSourceMaterialize, Nothing) -> Left (runnerProblem CorruptData "A SourceAdapter materialization request is missing its input bytes." [])
 where
  validatePayloadPathAndSource (path, payload) = do
    unless (safeRelativePath path) (Left (runnerProblem CorruptData "The runner payload contains an unsafe path." [path]))
    validatePayloadSource path payload

executeLuaRequest :: RunnerRequest -> IO (Either AppError RunnerExportArtifact)
executeLuaRequest request = do
  result <- Lua.runEither $ do
    openSafeLibraries
    installPayloadApi (requestEntryPoint request) (requestPayload request) (requestInputBytes request)
    let source = requestPayload request Map.! requestEntryPoint request
    loadChunk source ("@" <> requestEntryPoint request)
    Lua.callTrace 0 1
    valueType <- Lua.ltype Lua.top
    unless (valueType == Lua.TypeFunction) (Lua.failLua "the component entry chunk must return one function")
    Lua.pushValue (requestProjection request)
    Lua.callTrace 1 1
    artifact <- case requestOperation request of
      RunnerExport -> Lua.forcePeek (peekRunnerArtifact Lua.top)
      RunnerSourcePreflight -> do
        materialization <- Lua.forcePeek (peekSourceMaterialization Lua.top)
        let observation = materializedObservation materialization
        case canonicalJsonBytes (toJSON observation) of
          Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
          Right bytes ->
            pure
              RunnerExportArtifact
                { runnerArtifactBytes = bytes
                , runnerArtifactMediaType = "application/vnd.little-ant.source-observation+json"
                , runnerArtifactSuggestedFilename = "source-preflight.json"
                , runnerArtifactWarnings = observedWarnings observation
                , runnerArtifactMetadata = Map.singleton "schema" "little-ant/source-adapter-observation@1"
                }
      RunnerSourceMaterialize -> do
        materialization <- Lua.forcePeek (peekSourceMaterialization Lua.top)
        case canonicalJsonBytes (toJSON materialization) of
          Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
          Right bytes ->
            pure
              RunnerExportArtifact
                { runnerArtifactBytes = bytes
                , runnerArtifactMediaType = "application/vnd.little-ant.source-materialization+json"
                , runnerArtifactSuggestedFilename = "source-materialization.json"
                , runnerArtifactWarnings = observedWarnings (materializedObservation materialization)
                , runnerArtifactMetadata = Map.singleton "schema" "little-ant/source-adapter-materialization@1"
                }
    Lua.pop 1
    pure artifact
  pure $ case result of
    Left problem -> Left (runnerProblem ExternalFailure "Lua execution failed." [boundedException problem])
    Right artifact -> validateRunnerArtifact (requestMaximumArtifactBytes request) artifact >> Right artifact

openSafeLibraries :: Lua.Lua ()
openSafeLibraries = do
  Lua.openbase
  Lua.settop 0
  Lua.openmath
  Lua.setglobal "math"
  Lua.openstring
  Lua.setglobal "string"
  Lua.opentable
  Lua.setglobal "table"
  mapM_ removeGlobal ["collectgarbage", "dofile", "load", "loadfile", "print", "require", "warn"]
  removeField "math" "random"
  removeField "math" "randomseed"
  removeField "string" "dump"
 where
  removeGlobal name = Lua.pushnil >> Lua.setglobal name
  removeField table field = do
    valueType <- Lua.getglobal table
    when (valueType == Lua.TypeTable) (Lua.pushnil >> Lua.setfield (Lua.nth 2) field)
    Lua.pop 1

installPayloadApi :: Text -> Map Text ByteString -> Maybe ByteString -> Lua.Lua ()
installPayloadApi entry payload inputBytes = do
  Lua.newtable
  mapM_ pushModule (Map.toAscList payload)
  Lua.setglobal "__lant_preload"
  Lua.pushMap Lua.pushText Lua.pushByteString payload
  Lua.setglobal "__lant_assets"
  maybe Lua.pushnil Lua.pushByteString inputBytes
  Lua.setglobal "__lant_input_bytes"
  Lua.pushHaskellFunction $ do
    bytes <- Lua.forcePeek (Lua.peekByteString (Lua.nthBottom 1))
    Lua.pushText (sha256Hex bytes)
    pure 1
  Lua.setglobal "__lant_sha256"
  Lua.pushHaskellFunction $ do
    encoded <- Lua.forcePeek (Lua.peekText (Lua.nthBottom 1))
    case decodeBytes encoded of
      Left problem -> Lua.failLua problem
      Right decoded -> Lua.pushByteString decoded >> pure 1
  Lua.setglobal "__lant_base64url_decode"
  Lua.pushHaskellFunction $ do
    case inputBytes of
      Nothing -> Lua.failLua "input ZIP entries are unavailable for this invocation"
      Just bytes ->
        case extractInputZipEntries bytes of
          Left problem -> Lua.failLua (Text.unpack problem)
          Right entries -> do
            Lua.pushValue
              ( toJSON
                  [ object ["path" .= path, "bytes" .= encodeBytes content]
                  | (path, content) <- entries
                  ]
              )
            pure 1
  Lua.setglobal "__lant_input_zip_entries"
  loadChunk trustedBootstrap "@little-ant/bootstrap"
  Lua.callTrace 0 0
 where
  pushModule (path, source) = case moduleName path of
    Just name | path /= entry -> do
      Lua.pushText name
      loadChunk source ("@" <> path)
      Lua.rawset (Lua.nth 3)
    _ -> pure ()

loadChunk :: ByteString -> Text -> Lua.Lua ()
loadChunk source name = do
  status <- Lua.loadbuffer source (Lua.Name (TextEncoding.encodeUtf8 name))
  unless (status == Lua.OK) Lua.throwErrorAsException

peekRunnerArtifact :: Lua.Peeker Lua.Exception RunnerExportArtifact
peekRunnerArtifact index = do
  keys <- fmap fst <$> Lua.peekKeyValuePairs Lua.peekText (const (pure ())) index
  let expected = Set.fromList ["bytes", "media_type", "suggested_filename", "warnings", "metadata"]
  unless (Set.fromList keys == expected && length keys == Set.size expected) (Lua.failPeek "export artifact fields do not match the closed contract")
  RunnerExportArtifact
    <$> Lua.peekFieldRaw Lua.peekByteString "bytes" index
    <*> Lua.peekFieldRaw Lua.peekText "media_type" index
    <*> (Text.unpack <$> Lua.peekFieldRaw Lua.peekText "suggested_filename" index)
    <*> Lua.peekFieldRaw (Lua.peekList Lua.peekText) "warnings" index
    <*> Lua.peekFieldRaw (Lua.peekMap Lua.peekText Lua.peekText) "metadata" index

peekSourceMaterialization :: Lua.Peeker Lua.Exception SourceAdapterMaterialization
peekSourceMaterialization index = do
  exactLuaKeys "SourceAdapter observation" ["source_label", "account_label", "identity", "supported_modes", "cleanup_supported", "containers", "objects", "unsupported_fields", "warnings"] index
  account <- emptyMeansNothing <$> Lua.peekFieldRaw Lua.peekText "account_label" index
  sourceObjects <- Lua.peekFieldRaw (Lua.peekList peekSourceObjectWithMaterial) "objects" index
  observation <-
    SourceAdapterObservation
      <$> Lua.peekFieldRaw Lua.peekText "source_label" index
      <*> pure account
      <*> Lua.peekFieldRaw (Lua.peekMap Lua.peekText Lua.peekText) "identity" index
      <*> Lua.peekFieldRaw (Lua.peekList peekSourceMode) "supported_modes" index
      <*> Lua.peekFieldRaw Lua.peekBool "cleanup_supported" index
      <*> Lua.peekFieldRaw (Lua.peekList peekSourceContainer) "containers" index
      <*> pure (fst <$> sourceObjects)
      <*> Lua.peekFieldRaw (Lua.peekList Lua.peekText) "unsupported_fields" index
      <*> Lua.peekFieldRaw (Lua.peekList Lua.peekText) "warnings" index
  case validateSourceAdapterObservation observation of
    Left problem -> Lua.failPeek (TextEncoding.encodeUtf8 (appErrorMessage problem))
    Right () -> do
      let materialization = SourceAdapterMaterialization observation (Map.fromList [(sourceObjectExternalId sourceObject, material) | (sourceObject, material) <- sourceObjects])
      case validateSourceAdapterMaterialization materialization of
        Left problem -> Lua.failPeek (TextEncoding.encodeUtf8 (appErrorMessage problem))
        Right () -> pure materialization

peekSourceMode :: Lua.Peeker Lua.Exception SourceMode
peekSourceMode index =
  Lua.peekText index >>= \case
    "snapshot" -> pure SourceSnapshot
    "synchronize" -> pure SourceSynchronize
    "migrate" -> pure SourceMigrate
    value -> Lua.failPeek (TextEncoding.encodeUtf8 ("unknown source mode: " <> value))

peekSourceContainer :: Lua.Peeker Lua.Exception SourceContainer
peekSourceContainer index = do
  exactLuaKeys "source container" ["external_id", "label"] index
  SourceContainer
    <$> Lua.peekFieldRaw Lua.peekText "external_id" index
    <*> Lua.peekFieldRaw Lua.peekText "label" index

peekSourceObjectWithMaterial :: Lua.Peeker Lua.Exception (SourceObject, SourceMaterial)
peekSourceObjectWithMaterial index = do
  exactLuaKeys "source object" ["external_id", "locator", "container_id", "title", "shape", "completed", "attachment_count", "content", "duplicate_keys"] index
  externalIdentity <- Lua.peekFieldRaw Lua.peekText "external_id" index
  locator <- Lua.peekFieldRaw Lua.peekText "locator" index
  container <- emptyMeansNothing <$> Lua.peekFieldRaw Lua.peekText "container_id" index
  title <- Lua.peekFieldRaw Lua.peekText "title" index
  shape <- Lua.peekFieldRaw peekSourceShape "shape" index
  completed <- Lua.peekFieldRaw Lua.peekBool "completed" index
  attachmentCount <- Lua.peekFieldRaw Lua.peekIntegral "attachment_count" index
  sourceMaterial <- Lua.peekFieldRaw peekSourceMaterial "content" index
  case validateSourceMaterial sourceMaterial of
    Left problem -> Lua.failPeek (TextEncoding.encodeUtf8 (appErrorMessage problem))
    Right () -> pure ()
  let material = summarizeSourceMaterial sourceMaterial
  duplicateKeys <- Lua.peekFieldRaw (Lua.peekList Lua.peekText) "duplicate_keys" index
  pure (SourceObject externalIdentity locator container title shape completed attachmentCount material duplicateKeys, sourceMaterial)

peekSourceShape :: Lua.Peeker Lua.Exception SourceObjectShape
peekSourceShape index =
  Lua.peekText index >>= \case
    "task" -> pure SourceTaskShape
    "note" -> pure SourceNoteShape
    "other" -> pure SourceOtherShape
    value -> Lua.failPeek (TextEncoding.encodeUtf8 ("unknown source object shape: " <> value))

peekSourceMaterial :: Lua.Peeker Lua.Exception SourceMaterial
peekSourceMaterial index = do
  kind <- Lua.peekFieldRaw Lua.peekText "kind" index
  case kind of
    "text" -> do
      exactLuaKeys "text source material" ["kind", "text"] index
      SourceTextMaterial <$> Lua.peekFieldRaw Lua.peekText "text" index
    "uri" -> do
      exactLuaKeys "URI source material" ["kind", "uri", "label"] index
      SourceUriMaterial
        <$> Lua.peekFieldRaw Lua.peekText "uri" index
        <*> (emptyMeansNothing <$> Lua.peekFieldRaw Lua.peekText "label" index)
    "blob" -> do
      exactLuaKeys "blob source material" ["kind", "bytes", "media_type", "filename"] index
      SourceBlobMaterial
        <$> Lua.peekFieldRaw Lua.peekByteString "bytes" index
        <*> Lua.peekFieldRaw Lua.peekText "media_type" index
        <*> (emptyMeansNothing <$> Lua.peekFieldRaw Lua.peekText "filename" index)
    "structured" -> do
      exactLuaKeys "structured source material" ["kind", "schema", "json"] index
      SourceStructuredMaterial
        <$> Lua.peekFieldRaw Lua.peekText "schema" index
        <*> Lua.peekFieldRaw Lua.peekText "json" index
    value -> Lua.failPeek (TextEncoding.encodeUtf8 ("unknown source material kind: " <> value))

exactLuaKeys :: Text -> [Text] -> Lua.StackIndex -> Lua.Peek Lua.Exception ()
exactLuaKeys label expected index = do
  keys <- fmap fst <$> Lua.peekKeyValuePairs Lua.peekText (const (pure ())) index
  let expectedSet = Set.fromList expected
  unless (Set.fromList keys == expectedSet && length keys == Set.size expectedSet) $
    Lua.failPeek (TextEncoding.encodeUtf8 (label <> " fields do not match the closed contract"))

emptyMeansNothing :: Text -> Maybe Text
emptyMeansNothing value = if Text.null value then Nothing else Just value

validateRunnerArtifact :: Int -> RunnerExportArtifact -> Either AppError ()
validateRunnerArtifact maximumBytes artifact = do
  when (ByteString.length (runnerArtifactBytes artifact) > maximumBytes) (Left (runnerProblem PreconditionFailed "The runner artifact exceeds its declared byte limit." []))
  when (Text.length (runnerArtifactMediaType artifact) > 256) invalid
  when (length (runnerArtifactSuggestedFilename artifact) > 255) invalid
  when (length (runnerArtifactWarnings artifact) > 128 || any ((> 2048) . Text.length) (runnerArtifactWarnings artifact)) invalid
  when (Map.size (runnerArtifactMetadata artifact) > 128 || any ((> 2048) . Text.length) (Map.keys (runnerArtifactMetadata artifact) <> Map.elems (runnerArtifactMetadata artifact))) invalid
 where
  invalid = Left (runnerProblem CorruptData "The runner artifact metadata exceeds the bounded contract." [])

trustedBootstrap :: ByteString
trustedBootstrap =
  TextEncoding.encodeUtf8 . Text.unlines $
    [ "local preload = __lant_preload"
    , "local assets = __lant_assets"
    , "local input_bytes = __lant_input_bytes"
    , "local sha256 = __lant_sha256"
    , "local base64url_decode = __lant_base64url_decode"
    , "local input_zip_entries = __lant_input_zip_entries"
    , "__lant_preload = nil"
    , "__lant_assets = nil"
    , "__lant_input_bytes = nil"
    , "__lant_sha256 = nil"
    , "__lant_base64url_decode = nil"
    , "__lant_input_zip_entries = nil"
    , "local loaded = {}"
    , "function require(name)"
    , "  if type(name) ~= 'string' then"
    , "    error('invalid module name', 2)"
    , "  end"
    , "  if loaded[name] ~= nil then return loaded[name] end"
    , "  local loader = preload[name]"
    , "  if loader == nil then error('module not present in signed component payload: ' .. name, 2) end"
    , "  loaded[name] = true"
    , "  local result = loader(name)"
    , "  if result ~= nil then loaded[name] = result end"
    , "  return loaded[name]"
    , "end"
    , "lant = {"
    , "  contract_major = 1,"
    , "  asset = function(path)"
    , "    if type(path) ~= 'string' then error('asset path must be a string', 2) end"
    , "    local value = assets[path]"
    , "    if value == nil then error('asset not present in signed component payload: ' .. path, 2) end"
    , "    return value"
    , "  end,"
    , "  input_bytes = function()"
    , "    if input_bytes == nil then error('input bytes are unavailable for this invocation', 2) end"
    , "    return input_bytes"
    , "  end,"
    , "  sha256 = function(bytes)"
    , "    if type(bytes) ~= 'string' then error('sha256 input must be bytes', 2) end"
    , "    return sha256(bytes)"
    , "  end,"
    , "  base64url_decode = function(encoded)"
    , "    if type(encoded) ~= 'string' then error('base64url input must be a string', 2) end"
    , "    return base64url_decode(encoded)"
    , "  end,"
    , "  input_zip_entries = function()"
    , "    local entries = input_zip_entries()"
    , "    for index = 1, #entries do"
    , "      entries[index].bytes = base64url_decode(entries[index].bytes)"
    , "    end"
    , "    return entries"
    , "  end"
    , "}"
    ]

extractInputZipEntries :: ByteString -> Either Text [(Text, ByteString)]
extractInputZipEntries bytes = do
  archive <- either (Left . ("invalid ZIP input: " <>) . Text.pack) Right (Zip.toArchiveOrFail (LazyByteString.fromStrict bytes))
  let fileEntries = filter (not . isDirectoryEntry) (Zip.zEntries archive)
  when (null fileEntries) (Left "the ZIP input contains no files")
  unless (length fileEntries <= maximumInputZipEntries) (Left "the ZIP input contains too many files")
  traverse_ validateMetadata fileEntries
  let advertisedTotal = sum (fromIntegral . Zip.eUncompressedSize <$> fileEntries)
  unless (advertisedTotal <= maximumExpandedZipBytes) (Left "the ZIP input expands beyond the bounded materialization limit")
  materialized <- forM fileEntries $ \entry -> do
    let path = Text.pack (Zip.eRelativePath entry)
        content = LazyByteString.toStrict (Zip.fromEntry entry)
    unless (ByteString.length content == fromIntegral (Zip.eUncompressedSize entry)) (Left "a ZIP entry does not match its advertised uncompressed size")
    unless (crc32 content == Zip.eCRC32 entry) (Left "a ZIP entry failed its CRC32 integrity check")
    pure (path, content)
  let paths = fst <$> materialized
  unless (length paths == Set.size (Set.fromList paths)) (Left "the ZIP input contains duplicate file paths")
  pure (sortOn (TextEncoding.encodeUtf8 . fst) materialized)
 where
  validateMetadata entry = do
    let path = Text.pack (Zip.eRelativePath entry)
    unless (safeZipEntryPath path) (Left "the ZIP input contains an unsafe file path")
    unless (Zip.eEncryptionMethod entry == Zip.NoEncryption) (Left "encrypted ZIP entries are unsupported")
    when (Zip.isEntrySymbolicLink entry) (Left "symbolic links inside ZIP input are unsupported")
    unless (fromIntegral (Zip.eUncompressedSize entry) <= maximumInputZipEntryBytes) (Left "a ZIP entry exceeds the bounded materialization limit")
  isDirectoryEntry = Text.isSuffixOf "/" . Text.pack . Zip.eRelativePath

safeZipEntryPath :: Text -> Bool
safeZipEntryPath path =
  let segments = Text.splitOn "/" path
   in not (Text.null path)
        && not ("/" `Text.isPrefixOf` path)
        && not (Text.any (\character -> character == '\\' || character == '\0') path)
        && ByteString.length (TextEncoding.encodeUtf8 path) <= 1024
        && all (\segment -> not (Text.null segment) && segment /= "." && segment /= "..") segments

maximumInputZipEntries :: Int
maximumInputZipEntries = 4096

maximumInputZipEntryBytes :: Int
maximumInputZipEntryBytes = 8 * 1024 * 1024

maximumExpandedZipBytes :: Int
maximumExpandedZipBytes = 16 * 1024 * 1024

moduleName :: Text -> Maybe Text
moduleName path = do
  withoutSuffix <- Text.stripSuffix ".lua" path
  let segments = Text.splitOn "/" withoutSuffix
  unlessMaybe (not (null segments) && all validModuleSegment segments)
  pure (Text.intercalate "." segments)
 where
  validModuleSegment segment = case Text.uncons segment of
    Nothing -> False
    Just (first, rest) -> (isAsciiLetter first || first == '_') && Text.all (\character -> isAsciiLetter character || isDigit character || character == '_') rest
  isAsciiLetter character = isAscii character && (isAsciiLower character || isAsciiUpper character)

unlessMaybe :: Bool -> Maybe ()
unlessMaybe condition = if condition then Just () else Nothing

safeRelativePath :: Text -> Bool
safeRelativePath path =
  let segments = Text.splitOn "/" path
   in not (Text.null path)
        && not ("/" `Text.isPrefixOf` path)
        && not (Text.any (\character -> character == '\\' || character == '\0') path)
        && all (\segment -> not (Text.null segment) && segment /= "." && segment /= "..") segments

validComponentId :: Text -> Bool
validComponentId value = case Text.uncons value of
  Nothing -> False
  Just (first, rest) ->
    Text.length value <= 64
      && isAsciiLower first
      && Text.all (\character -> isAsciiLower character || isDigit character || character `elem` ("._-" :: String)) rest

validateDigest :: Text -> Text -> Either AppError ()
validateDigest label digest =
  unless
    (Text.length digest == 64 && Text.all (\character -> isDigit character || character >= 'a' && character <= 'f') digest)
    (Left (runnerProblem CorruptData (label <> " must be a lowercase SHA-256 digest.") [digest]))

readBounded :: Handle -> Int -> IO (Either () ByteString)
readBounded handle maximumBytes = go 0 []
 where
  go total chunks = do
    chunk <- ByteString.hGetSome handle 32768
    if ByteString.null chunk
      then pure (Right (ByteString.concat (reverse chunks)))
      else
        let next = total + ByteString.length chunk
         in if next > maximumBytes then pure (Left ()) else go next (chunk : chunks)

waitForProcessBounded :: Int -> ProcessHandle -> IO (Maybe ExitCode)
waitForProcessBounded maximumMicros processHandle = do
  started <- getMonotonicTimeNSec
  poll started
 where
  poll started =
    getProcessExitCode processHandle >>= \case
      Just exitCode -> pure (Just exitCode)
      Nothing -> do
        now <- getMonotonicTimeNSec
        let elapsedMicros = (now - started) `div` 1000
        if elapsedMicros >= fromIntegral maximumMicros
          then pure Nothing
          else threadDelay (min 10_000 (maximumMicros - fromIntegral elapsedMicros)) >> poll started

applyChildResourceLimits :: IO ()
applyChildResourceLimits = do
  capSoft ResourceCPUTime (ResourceLimit 3)
  baselineAddressSpace <- currentAddressSpaceBytes
  capSoft ResourceTotalMemory (ResourceLimit (baselineAddressSpace + maximumAdditionalAddressSpaceBytes))
  capSoft ResourceFileSize (ResourceLimit 0)
  capSoft ResourceCoreFileSize (ResourceLimit 0)
  capSoft ResourceOpenFiles (ResourceLimit 32)
  capSoft ResourceStackSize (ResourceLimit (32 * 1024 * 1024))
 where
  capSoft resource requested = do
    current <- getResourceLimit resource
    let limited = minimumLimit requested (hardLimit current)
    setResourceLimit resource current{softLimit = limited}
  minimumLimit requested inherited = case (requested, inherited) of
    (ResourceLimit requestedValue, ResourceLimit inheritedValue) -> ResourceLimit (min requestedValue inheritedValue)
    (ResourceLimit _, ResourceLimitInfinity) -> requested
    (ResourceLimit _, ResourceLimitUnknown) -> requested
    _ -> inherited

-- GHC's reserved virtual address space varies with the linker and profiling
-- mode. RLIMIT_AS therefore caps additional address space above the fresh
-- helper's measured runtime baseline rather than an absolute virtual address.
currentAddressSpaceBytes :: IO Integer
currentAddressSpaceBytes = catch inspect (const (pure 0) :: IOException -> IO Integer)
 where
  inspect = do
    status <- TextIO.readFile "/proc/self/status"
    pure $ case find (Text.isPrefixOf "VmSize:") (Text.lines status) of
      Just line -> case Text.words line of
        ["VmSize:", kibibytes, "kB"] -> maybe 0 (* 1024) (readMaybe (Text.unpack kibibytes))
        _ -> 0
      Nothing -> 0

maximumAdditionalAddressSpaceBytes :: Integer
maximumAdditionalAddressSpaceBytes = 1024 * 1024 * 1024

encodeBytes :: ByteString -> Text
encodeBytes = TextEncoding.decodeUtf8 . Base64Url.encodeUnpadded

decodeBytes :: Text -> Either String ByteString
decodeBytes encoded = do
  let bytes = TextEncoding.encodeUtf8 encoded
  decoded <- Base64Url.decodeUnpadded bytes
  unless (Base64Url.encodeUnpadded decoded == bytes) (Left "noncanonical base64url")
  pure decoded

requireSchema :: Object -> Text -> Parser ()
requireSchema fields expected = do
  actual <- fields .: "schema"
  unless (actual == expected) (fail ("unsupported schema: " <> Text.unpack actual))

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

failureFromError :: Text -> AppError -> RunnerFailure
failureFromError kind problem = RunnerFailure kind (boundedText (TextEncoding.encodeUtf8 (appErrorMessage problem <> details)))
 where
  details = case appErrorDetails problem of
    [] -> ""
    values -> ": " <> Text.intercalate "; " values

boundedException :: (Exception exception) => exception -> Text
boundedException = boundedText . TextEncoding.encodeUtf8 . Text.pack . displayException

boundedText :: ByteString -> Text
boundedText = Text.take 4096 . TextEncoding.decodeUtf8With TextError.lenientDecode

emitEmergencyFailure :: Text -> IO ()
emitEmergencyFailure message =
  ByteString.hPut stdout ("{\"error\":{\"kind\":\"internal\",\"message\":\"" <> escaped <> "\"},\"ok\":false,\"schema\":\"little-ant/pack-runner-response@1\"}") >> hFlush stdout
 where
  escaped = Base16.encode (ByteString.take 512 (TextEncoding.encodeUtf8 message))

handleRunnerIo :: IO (Either AppError value) -> IO (Either AppError value)
handleRunnerIo action = catch action (pure . Left . runnerIoProblem)

runnerIoProblem :: IOException -> AppError
runnerIoProblem problem = runnerProblem ExternalFailure "Little Ant could not communicate with the private Pack runner." [Text.pack (displayException problem)]

runnerTimeoutProblem :: AppError
runnerTimeoutProblem =
  (runnerProblem ExternalFailure "The Pack component exceeded its wall-time limit and was terminated." [])
    { appErrorRetrySafety = RetrySafe
    }

runnerProblem :: ErrorCode -> Text -> [Text] -> AppError
runnerProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRecovery = [RecoveryAction "packs" "Inspect or replace the Pack component." (Just "lant packs list")]
    }

maximumRunnerErrorBytes :: Int
maximumRunnerErrorBytes = 64 * 1024

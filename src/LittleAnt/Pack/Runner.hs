module LittleAnt.Pack.Runner (
  PackRunnerClient (..),
  PackRunnerLimits (..),
  factoryPackRunnerLimits,
  defaultPackRunnerClient,
  RunnerExportArtifact (..),
  invokePackExporter,
  invokePackSourcePreflight,
  invokePackSourceMaterialize,
  invokePackSourcePreflightHttp,
  invokePackSourceMaterializeHttp,
  invokePackSourceCleanupItemHttp,
  invokePackSourceCleanupItemVerifyHttp,
  invokePackSourceCleanupContainerInspectHttp,
  invokePackSourceCleanupContainerHttp,
  invokePackSourceCleanupContainerVerifyHttp,
  runPackRunnerMain,
)
where

import Codec.Archive.Zip qualified as Zip
import Control.Concurrent (forkFinally, newEmptyMVar, putMVar, takeMVar, threadDelay)
import Control.Exception (Exception, IOException, SomeException, catch, displayException, try)
import Control.Monad (filterM, forM, unless, void, when)
import Control.Monad.IO.Class (liftIO)
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
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.List (find, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust, isNothing)
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
import LittleAnt.Pack.Http
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
  , requestHttpEnabled :: Bool
  , requestHttpTranscript :: [BrokerHttpExchange]
  , requestMaximumArtifactBytes :: Int
  }
  deriving stock (Eq, Show)

data RunnerOperation
  = RunnerExport
  | RunnerSourcePreflight
  | RunnerSourceMaterialize
  | RunnerSourceCleanupItem
  | RunnerSourceCleanupItemVerify
  | RunnerSourceCleanupContainerInspect
  | RunnerSourceCleanupContainer
  | RunnerSourceCleanupContainerVerify
  deriving stock (Eq, Show)

data RunnerFailure = RunnerFailure
  { runnerFailureKind :: Text
  , runnerFailureMessage :: Text
  }
  deriving stock (Eq, Show)

data RunnerResponse
  = RunnerSucceeded RunnerExportArtifact
  | RunnerNeedsHttp BrokerHttpRequest
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
      [ "schema" .= ("little-ant/pack-runner-request@2" :: Text)
      , "artifact" .= requestArtifact request
      , "signer_fingerprint" .= requestSignerFingerprint request
      , "component_id" .= requestComponentId request
      , "contract_major" .= requestContractMajor request
      , "entry_point" .= requestEntryPoint request
      , "payload" .= fmap encodeBytes (requestPayload request)
      , "projection" .= requestProjection request
      , "operation" .= runnerOperationName (requestOperation request)
      , "http_enabled" .= requestHttpEnabled request
      , "http_transcript" .= requestHttpTranscript request
      , "maximum_artifact_bytes" .= requestMaximumArtifactBytes request
      ]
        <> maybe [] (pure . ("input_bytes" .=) . encodeBytes) (requestInputBytes request)

instance FromJSON RunnerRequest where
  parseJSON = withObject "RunnerRequest" $ \fields -> do
    rejectUnknown fields ["schema", "artifact", "signer_fingerprint", "component_id", "contract_major", "entry_point", "payload", "projection", "operation", "input_bytes", "http_enabled", "http_transcript", "maximum_artifact_bytes"]
    requireSchema fields "little-ant/pack-runner-request@2"
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
      <*> fields .: "http_enabled"
      <*> fields .: "http_transcript"
      <*> fields .: "maximum_artifact_bytes"

runnerOperationName :: RunnerOperation -> Text
runnerOperationName = \case
  RunnerExport -> "export"
  RunnerSourcePreflight -> "source_preflight"
  RunnerSourceMaterialize -> "source_materialize"
  RunnerSourceCleanupItem -> "source_cleanup_item"
  RunnerSourceCleanupItemVerify -> "source_cleanup_item_verify"
  RunnerSourceCleanupContainerInspect -> "source_cleanup_container_inspect"
  RunnerSourceCleanupContainer -> "source_cleanup_container"
  RunnerSourceCleanupContainerVerify -> "source_cleanup_container_verify"

parseRunnerOperation :: Text -> Parser RunnerOperation
parseRunnerOperation = \case
  "export" -> pure RunnerExport
  "source_preflight" -> pure RunnerSourcePreflight
  "source_materialize" -> pure RunnerSourceMaterialize
  "source_cleanup_item" -> pure RunnerSourceCleanupItem
  "source_cleanup_item_verify" -> pure RunnerSourceCleanupItemVerify
  "source_cleanup_container_inspect" -> pure RunnerSourceCleanupContainerInspect
  "source_cleanup_container" -> pure RunnerSourceCleanupContainer
  "source_cleanup_container_verify" -> pure RunnerSourceCleanupContainerVerify
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
        [ "schema" .= ("little-ant/pack-runner-response@2" :: Text)
        , "kind" .= ("succeeded" :: Text)
        , "artifact" .= artifact
        ]
    RunnerNeedsHttp request ->
      object
        [ "schema" .= ("little-ant/pack-runner-response@2" :: Text)
        , "kind" .= ("http_request" :: Text)
        , "request" .= request
        ]
    RunnerFailed failure ->
      object
        [ "schema" .= ("little-ant/pack-runner-response@2" :: Text)
        , "kind" .= ("failed" :: Text)
        , "error" .= failure
        ]

instance FromJSON RunnerResponse where
  parseJSON = withObject "RunnerResponse" $ \fields -> do
    requireSchema fields "little-ant/pack-runner-response@2"
    fields .: "kind" >>= \case
      ("succeeded" :: Text) -> rejectUnknown fields ["schema", "kind", "artifact"] >> RunnerSucceeded <$> fields .: "artifact"
      "http_request" -> rejectUnknown fields ["schema", "kind", "request"] >> RunnerNeedsHttp <$> fields .: "request"
      "failed" -> rejectUnknown fields ["schema", "kind", "error"] >> RunnerFailed <$> fields .: "error"
      value -> fail ("unknown Pack runner response kind: " <> Text.unpack value)

invokePackExporter :: PackRunnerClient -> RegisteredPackComponent -> Value -> IO (Either AppError RunnerExportArtifact)
invokePackExporter client registered projection =
  case prepareRequest client registered RunnerExport Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> invokeRunnerProcess client request

invokePackSourcePreflight :: PackRunnerClient -> RegisteredPackComponent -> SourceMode -> SourceInput -> IO (Either AppError SourcePreflight)
invokePackSourcePreflight client registered mode input =
  case prepareRequest client registered RunnerSourcePreflight (Just (sourceInputBytes input)) projection of
    Left problem -> pure (Left problem)
    Right request -> case sourceInvocationAuthority registered of
      Left problem -> pure (Left problem)
      Right (contractMajor, permissions) ->
        invokeRunnerProcess client request >>= \case
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
    Right request -> case sourceInvocationAuthority registered of
      Left problem -> pure (Left problem)
      Right (contractMajor, permissions) ->
        invokeRunnerProcess client request >>= \case
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

invokePackSourcePreflightHttp :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> SourceMode -> Text -> Value -> IO (Either AppError (SourceInput, SourcePreflight))
invokePackSourcePreflightHttp client broker registered mode inputLabel source =
  case prepareRequest client registered RunnerSourcePreflight Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> case sourceInvocationDetails registered of
      Left problem -> pure (Left problem)
      Right (contractMajor, encodedPermissions, permissions) ->
        invokeRunnerProcessHttp client permissions broker request >>= \case
          Left problem -> pure (Left problem)
          Right (artifact, transcript) -> pure $ do
            input <- transcriptSourceInput inputLabel transcript
            observation <- decodeSourceObservation (runnerArtifactBytes artifact)
            preflight <-
              makeSourcePreflight
                (componentId (componentCommon (registeredComponent registered)))
                (registeredPackIdentity registered)
                (registeredSignerFingerprint registered)
                contractMajor
                encodedPermissions
                mode
                input
                observation
            pure (input, preflight)
 where
  projection = object ["schema" .= ("little-ant/source-provider-request@1" :: Text), "mode" .= sourceModeName mode, "source" .= source]

invokePackSourceMaterializeHttp :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> SourceMode -> Text -> Value -> IO (Either AppError (SourceInput, SourcePreflight, SourceAdapterMaterialization))
invokePackSourceMaterializeHttp client broker registered mode inputLabel source =
  case prepareRequest client registered RunnerSourceMaterialize Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> case sourceInvocationDetails registered of
      Left problem -> pure (Left problem)
      Right (contractMajor, encodedPermissions, permissions) ->
        invokeRunnerProcessHttp client permissions broker request >>= \case
          Left problem -> pure (Left problem)
          Right (artifact, transcript) -> pure $ do
            input <- transcriptSourceInput inputLabel transcript
            materialization <- decodeSourceMaterialization (runnerArtifactBytes artifact)
            preflight <-
              makeSourcePreflight
                (componentId (componentCommon (registeredComponent registered)))
                (registeredPackIdentity registered)
                (registeredSignerFingerprint registered)
                contractMajor
                encodedPermissions
                mode
                input
                (materializedObservation materialization)
            pure (input, preflight, materialization)
 where
  projection = object ["schema" .= ("little-ant/source-provider-request@1" :: Text), "mode" .= sourceModeName mode, "source" .= source]

invokePackSourceCleanupItemHttp :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> Value -> Text -> Text -> Maybe Text -> IO (Either AppError SourceCleanupReceipt)
invokePackSourceCleanupItemHttp client broker registered source externalIdentity locator containerIdentity =
  case prepareRequest client registered RunnerSourceCleanupItem Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> case sourceInvocationDetails registered of
      Left problem -> pure (Left problem)
      Right (_, _, permissions)
        | SourceCleanupItemPermission `notElem` permissionEffectPurposes permissions ->
            pure . Left $ runnerProblem PermissionRequired "The SourceAdapter did not declare source_cleanup_item authority." []
        | otherwise ->
            invokeRunnerProcessHttp client permissions broker request >>= \case
              Left problem -> pure (Left problem)
              Right (artifact, _) -> pure $ decodeSourceCleanupReceipt (runnerArtifactBytes artifact)
 where
  projection =
    object
      [ "schema" .= ("little-ant/source-cleanup-item-request@1" :: Text)
      , "source" .= source
      , "target"
          .= object
            ( [ "external_identity" .= externalIdentity
              , "locator" .= locator
              ]
                <> maybe [] (pure . ("container_identity" .=)) containerIdentity
            )
      ]

invokePackSourceCleanupItemVerifyHttp :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> Value -> Text -> Text -> Maybe Text -> IO (Either AppError SourceCleanupReceipt)
invokePackSourceCleanupItemVerifyHttp client broker registered source externalIdentity locator containerIdentity =
  case prepareRequest client registered RunnerSourceCleanupItemVerify Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> case sourceInvocationDetails registered of
      Left problem -> pure (Left problem)
      Right (_, _, permissions)
        | SourceCleanupItemPermission `notElem` permissionEffectPurposes permissions ->
            pure . Left $ runnerProblem PermissionRequired "The SourceAdapter did not declare source_cleanup_item authority." []
        | otherwise ->
            invokeRunnerProcessHttp client permissions broker request >>= \case
              Left problem -> pure (Left problem)
              Right (artifact, _) -> pure $ decodeSourceCleanupReceipt (runnerArtifactBytes artifact)
 where
  projection =
    object
      [ "schema" .= ("little-ant/source-cleanup-item-verify-request@1" :: Text)
      , "source" .= source
      , "target"
          .= object
            ( [ "external_identity" .= externalIdentity
              , "locator" .= locator
              ]
                <> maybe [] (pure . ("container_identity" .=)) containerIdentity
            )
      ]

invokePackSourceCleanupContainerInspectHttp :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> Value -> Text -> IO (Either AppError SourceContainerInspection)
invokePackSourceCleanupContainerInspectHttp client broker registered source externalIdentity =
  case prepareRequest client registered RunnerSourceCleanupContainerInspect Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> case sourceInvocationDetails registered of
      Left problem -> pure (Left problem)
      Right (_, _, permissions)
        | SourceCleanupContainerPermission `notElem` permissionEffectPurposes permissions ->
            pure . Left $ runnerProblem PermissionRequired "The SourceAdapter did not declare source_cleanup_container authority." []
        | otherwise ->
            invokeRunnerProcessHttp client permissions broker request >>= \case
              Left problem -> pure (Left problem)
              Right (artifact, _) -> pure $ decodeSourceContainerInspection (runnerArtifactBytes artifact)
 where
  projection =
    object
      [ "schema" .= ("little-ant/source-cleanup-container-inspect-request@1" :: Text)
      , "source" .= source
      , "target" .= object ["external_identity" .= externalIdentity]
      ]

invokePackSourceCleanupContainerHttp :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> Value -> Text -> IO (Either AppError SourceCleanupReceipt)
invokePackSourceCleanupContainerHttp client broker registered source externalIdentity =
  invokePackSourceCleanupContainerOperation client broker registered RunnerSourceCleanupContainer "little-ant/source-cleanup-container-request@1" source externalIdentity

invokePackSourceCleanupContainerVerifyHttp :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> Value -> Text -> IO (Either AppError SourceCleanupReceipt)
invokePackSourceCleanupContainerVerifyHttp client broker registered source externalIdentity =
  invokePackSourceCleanupContainerOperation client broker registered RunnerSourceCleanupContainerVerify "little-ant/source-cleanup-container-verify-request@1" source externalIdentity

invokePackSourceCleanupContainerOperation :: PackRunnerClient -> PackHttpBroker -> RegisteredPackComponent -> RunnerOperation -> Text -> Value -> Text -> IO (Either AppError SourceCleanupReceipt)
invokePackSourceCleanupContainerOperation client broker registered operation schema source externalIdentity =
  case prepareRequest client registered operation Nothing projection of
    Left problem -> pure (Left problem)
    Right request -> case sourceInvocationDetails registered of
      Left problem -> pure (Left problem)
      Right (_, _, permissions)
        | SourceCleanupContainerPermission `notElem` permissionEffectPurposes permissions ->
            pure . Left $ runnerProblem PermissionRequired "The SourceAdapter did not declare source_cleanup_container authority." []
        | otherwise ->
            invokeRunnerProcessHttp client permissions broker request >>= \case
              Left problem -> pure (Left problem)
              Right (artifact, _) -> pure $ decodeSourceCleanupReceipt (runnerArtifactBytes artifact)
 where
  projection =
    object
      [ "schema" .= schema
      , "source" .= source
      , "target" .= object ["external_identity" .= externalIdentity]
      ]

transcriptSourceInput :: Text -> [BrokerHttpExchange] -> Either AppError SourceInput
transcriptSourceInput label transcript = do
  validateBrokerHttpTranscript transcript
  bytes <- canonicalJsonBytes (toJSON transcript)
  pure (SourceInput (Text.strip label) "application/vnd.little-ant.http-transcript+json" bytes)

sourceInvocationAuthority :: RegisteredPackComponent -> Either AppError (Int, Text)
sourceInvocationAuthority registered =
  (\(contractMajor, encoded, _) -> (contractMajor, encoded)) <$> sourceInvocationDetails registered

sourceInvocationDetails :: RegisteredPackComponent -> Either AppError (Int, Text, ComponentPermissions)
sourceInvocationDetails registered =
  case registeredComponent registered of
    ExecutableComponent common _ permissions -> do
      encoded <- canonicalJsonBytes (toJSON permissions)
      pure (componentContractMajor common, TextEncoding.decodeUtf8 encoded, permissions)
    _ -> Left (runnerProblem Unsupported "A declarative Pack component has no executable invocation authority." [])

prepareRequest :: PackRunnerClient -> RegisteredPackComponent -> RunnerOperation -> Maybe ByteString -> Value -> Either AppError RunnerRequest
prepareRequest client registered operation input projection = do
  validateClientLimits (packRunnerLimits client)
  case registeredComponent registered of
    ExecutableComponent common entry permissions
      | componentKind common /= expectedKind -> Left (runnerProblem Unsupported wrongKindMessage [])
      | componentContractMajor common /= 1 -> Left (runnerProblem Unsupported "The selected component uses an unsupported host contract major." [Text.pack (show (componentContractMajor common))])
      | operation == RunnerExport && null (permissionProjections permissions) -> Left (runnerProblem CorruptData "The selected exporter declares no input projection." [])
      | operation `elem` [RunnerSourcePreflight, RunnerSourceMaterialize] && isJust input && InputBytesCapability `notElem` permissionHostCapabilities permissions -> Left (runnerProblem PermissionRequired "The selected SourceAdapter did not declare the input_bytes host capability." [])
      | operation `elem` [RunnerSourcePreflight, RunnerSourceMaterialize] && isNothing input && null (permissionHttp permissions) -> Left (runnerProblem PreconditionFailed "A SourceAdapter invocation requires host-custodied input bytes or signed HTTP permissions." [])
      | operation `elem` cleanupOperations && (isJust input || null (permissionHttp permissions)) -> Left (runnerProblem PreconditionFailed "A source cleanup invocation requires signed brokered HTTP and no input bytes." [])
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
              , requestHttpEnabled = not (null (permissionHttp permissions))
              , requestHttpTranscript = []
              , requestMaximumArtifactBytes = runnerMaximumArtifactBytes limits
              }
    _ -> Left (runnerProblem Unsupported "Declarative Pack components cannot execute in the Lua runner." [])
 where
  expectedKind = case operation of
    RunnerExport -> ReadOnlyExporterComponent
    RunnerSourcePreflight -> SourceAdapterComponent
    RunnerSourceMaterialize -> SourceAdapterComponent
    RunnerSourceCleanupItem -> SourceAdapterComponent
    RunnerSourceCleanupItemVerify -> SourceAdapterComponent
    RunnerSourceCleanupContainerInspect -> SourceAdapterComponent
    RunnerSourceCleanupContainer -> SourceAdapterComponent
    RunnerSourceCleanupContainerVerify -> SourceAdapterComponent
  wrongKindMessage = case operation of
    RunnerExport -> "The selected Pack component is not a read-only exporter."
    RunnerSourcePreflight -> "The selected Pack component is not a SourceAdapter."
    RunnerSourceMaterialize -> "The selected Pack component is not a SourceAdapter."
    RunnerSourceCleanupItem -> "The selected Pack component is not a SourceAdapter."
    RunnerSourceCleanupItemVerify -> "The selected Pack component is not a SourceAdapter."
    RunnerSourceCleanupContainerInspect -> "The selected Pack component is not a SourceAdapter."
    RunnerSourceCleanupContainer -> "The selected Pack component is not a SourceAdapter."
    RunnerSourceCleanupContainerVerify -> "The selected Pack component is not a SourceAdapter."
  cleanupOperations =
    [ RunnerSourceCleanupItem
    , RunnerSourceCleanupItemVerify
    , RunnerSourceCleanupContainerInspect
    , RunnerSourceCleanupContainer
    , RunnerSourceCleanupContainerVerify
    ]

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

data RunnerProcessOutcome
  = RunnerProcessCompleted RunnerExportArtifact
  | RunnerProcessNeedsHttp BrokerHttpRequest

data HttpReplayState = HttpReplayState
  { replayRemaining :: [BrokerHttpExchange]
  , replayPending :: Maybe BrokerHttpRequest
  }

invokeRunnerProcess :: PackRunnerClient -> RunnerRequest -> IO (Either AppError RunnerExportArtifact)
invokeRunnerProcess client request =
  invokeRunnerProcessOnce client request >>= \case
    Left problem -> pure (Left problem)
    Right (RunnerProcessCompleted artifact) -> pure (Right artifact)
    Right (RunnerProcessNeedsHttp _) -> pure (Left (runnerProblem PermissionRequired "The Pack requested HTTP but this invocation has no trusted host broker." []))

invokeRunnerProcessHttp :: PackRunnerClient -> ComponentPermissions -> PackHttpBroker -> RunnerRequest -> IO (Either AppError (RunnerExportArtifact, [BrokerHttpExchange]))
invokeRunnerProcessHttp client permissions broker = go []
 where
  go transcript request =
    invokeRunnerProcessOnce client request{requestHttpTranscript = transcript} >>= \case
      Left problem -> pure (Left problem)
      Right (RunnerProcessCompleted artifact) -> pure (Right (artifact, transcript))
      Right (RunnerProcessNeedsHttp pending) ->
        case ensureFreshRequest transcript pending >> authorizeBrokerHttpRequest permissions pending of
          Left problem -> pure (Left problem)
          Right authorized -> do
            brokered <- try (runPackHttpBroker broker authorized pending)
            case brokered of
              Left (_ :: SomeException) -> pure (Left (runnerProblem ExternalFailure "The trusted HTTP broker failed before returning a sanitized response." []))
              Right (Left problem) -> pure (Left problem)
              Right (Right response) ->
                case validateBrokerHttpResponse response >> validateBrokerHttpTranscript (transcript <> [BrokerHttpExchange pending response]) of
                  Left problem -> pure (Left problem)
                  Right () -> go (transcript <> [BrokerHttpExchange pending response]) request
  ensureFreshRequest transcript pending =
    when
      (pending `elem` (brokerExchangeRequest <$> transcript))
      (Left (runnerProblem PreconditionFailed "The Pack repeated an identical brokered HTTP request in one invocation." [brokerHttpMethod pending, brokerHttpUrl pending]))

invokeRunnerProcessOnce :: PackRunnerClient -> RunnerRequest -> IO (Either AppError RunnerProcessOutcome)
invokeRunnerProcessOnce client request =
  case canonicalJsonBytes (toJSON request) of
    Left problem -> pure (Left problem)
    Right requestBytes
      | ByteString.length requestBytes > runnerMaximumRequestBytes limits -> pure (Left (runnerProblem PreconditionFailed "The Pack runner request exceeds its bounded size." []))
      | otherwise -> do
          executableReady <- validateRunnerExecutable (packRunnerExecutable client)
          case executableReady of
            Left problem -> pure (Left problem)
            Right () -> runBoundedProcess requestBytes
 where
  limits = packRunnerLimits client
  runBoundedProcess requestBytes =
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

decodeProcessOutcome :: Int -> (ExitCode, Either SomeException (Either () ByteString), Either SomeException (Either () ByteString)) -> Either AppError RunnerProcessOutcome
decodeProcessOutcome maximumArtifactBytes (exitCode, stdoutResult, stderrResult) = do
  output <- flattenRead "stdout" stdoutResult
  errors <- flattenRead "stderr" stderrResult
  unless
    (exitCode == ExitSuccess)
    (Left (runnerProblem ExternalFailure "The private Pack runner exited unsuccessfully." (processDetails exitCode errors)))
  response <- decodeCanonicalResponse output
  case response of
    RunnerSucceeded artifact -> validateRunnerArtifact maximumArtifactBytes artifact >> Right (RunnerProcessCompleted artifact)
    RunnerNeedsHttp request -> validateBrokerHttpRequest request >> Right (RunnerProcessNeedsHttp request)
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

decodeSourceCleanupReceipt :: ByteString -> Either AppError SourceCleanupReceipt
decodeSourceCleanupReceipt bytes = do
  value <- either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter cleanup returned invalid JSON." [Text.pack problem])) Right (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (runnerProblem CorruptData "The SourceAdapter cleanup receipt is not canonical JSON." []))
  receipt <- either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter cleanup receipt violates its closed schema." [Text.pack problem])) Right (parseEither parseSourceCleanupReceipt value)
  validateSourceCleanupReceipt receipt
  pure receipt

decodeSourceContainerInspection :: ByteString -> Either AppError SourceContainerInspection
decodeSourceContainerInspection bytes = do
  value <- either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter container inspection returned invalid JSON." [Text.pack problem])) Right (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (runnerProblem CorruptData "The SourceAdapter container inspection is not canonical JSON." []))
  unverified <- either (\problem -> Left (runnerProblem CorruptData "The SourceAdapter container inspection violates its closed schema." [Text.pack problem])) Right (parseEither parseSourceContainerInspection value)
  let inspection = unverified{inspectedContainerDigest = sha256Hex bytes}
  validateSourceContainerInspection inspection
  pure inspection

parseSourceContainerInspection :: Value -> Parser SourceContainerInspection
parseSourceContainerInspection = withObject "SourceContainerInspection" $ \fields -> do
  rejectUnknown fields ["schema", "external_identity", "label", "outcome", "item_count", "provider_version", "redacted_detail"]
  requireSchema fields "little-ant/source-container-inspection@1"
  outcome <- fields .: "outcome" >>= parseSourceContainerInspectionOutcome
  count <- fields .: "item_count"
  providerVersion <- emptyMeansNothing <$> fields .: "provider_version"
  SourceContainerInspection
    <$> fields .: "external_identity"
    <*> fields .: "label"
    <*> pure outcome
    <*> pure (if count < (0 :: Int) then Nothing else Just count)
    <*> pure providerVersion
    <*> fields .: "redacted_detail"
    <*> pure (Text.replicate 64 "0")

parseSourceContainerInspectionOutcome :: Text -> Parser SourceContainerInspectionOutcome
parseSourceContainerInspectionOutcome = \case
  "empty" -> pure SourceContainerEmpty
  "nonempty" -> pure SourceContainerNonempty
  "absent" -> pure SourceContainerAbsent
  "protected" -> pure SourceContainerProtected
  value -> fail ("unknown source-container inspection outcome: " <> Text.unpack value)

sourceContainerInspectionValue :: SourceContainerInspection -> Value
sourceContainerInspectionValue inspection =
  object
    [ "schema" .= ("little-ant/source-container-inspection@1" :: Text)
    , "external_identity" .= inspectedContainerExternalIdentity inspection
    , "label" .= inspectedContainerLabel inspection
    , "outcome" .= sourceContainerInspectionOutcomeText (inspectedContainerOutcome inspection)
    , "item_count" .= maybe (-1 :: Int) id (inspectedContainerItemCount inspection)
    , "provider_version" .= maybe "" id (inspectedContainerProviderVersion inspection)
    , "redacted_detail" .= inspectedContainerRedactedDetail inspection
    ]

sourceContainerInspectionOutcomeText :: SourceContainerInspectionOutcome -> Text
sourceContainerInspectionOutcomeText = \case
  SourceContainerEmpty -> "empty"
  SourceContainerNonempty -> "nonempty"
  SourceContainerAbsent -> "absent"
  SourceContainerProtected -> "protected"

parseSourceCleanupReceipt :: Value -> Parser SourceCleanupReceipt
parseSourceCleanupReceipt = withObject "SourceCleanupReceipt" $ \fields -> do
  rejectUnknown fields ["schema", "outcome", "provider_reference", "redacted_detail"]
  requireSchema fields "little-ant/source-cleanup-receipt@1"
  outcome <- fields .: "outcome" >>= parseSourceCleanupOutcome
  providerReference <- emptyMeansNothing <$> fields .: "provider_reference"
  redactedDetail <- emptyMeansNothing <$> fields .: "redacted_detail"
  pure (SourceCleanupReceipt outcome providerReference redactedDetail)

parseSourceCleanupOutcome :: Text -> Parser SourceCleanupOutcome
parseSourceCleanupOutcome = \case
  "succeeded" -> pure SourceCleanupSucceeded
  "failed_retryable" -> pure SourceCleanupFailedRetryable
  "failed_terminal" -> pure SourceCleanupFailedTerminal
  "outcome_unknown" -> pure SourceCleanupOutcomeUnknown
  value -> fail ("unknown source cleanup outcome: " <> Text.unpack value)

sourceCleanupReceiptValue :: SourceCleanupReceipt -> Value
sourceCleanupReceiptValue receipt =
  object
    [ "schema" .= ("little-ant/source-cleanup-receipt@1" :: Text)
    , "outcome" .= sourceCleanupOutcomeText (sourceCleanupOutcome receipt)
    , "provider_reference" .= maybe "" id (sourceCleanupProviderReference receipt)
    , "redacted_detail" .= maybe "" id (sourceCleanupRedactedDetail receipt)
    ]

sourceCleanupOutcomeText :: SourceCleanupOutcome -> Text
sourceCleanupOutcomeText = \case
  SourceCleanupSucceeded -> "succeeded"
  SourceCleanupFailedRetryable -> "failed_retryable"
  SourceCleanupFailedTerminal -> "failed_terminal"
  SourceCleanupOutcomeUnknown -> "outcome_unknown"

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
      Right (Right (RunnerProcessCompleted artifact)) -> RunnerSucceeded artifact
      Right (Right (RunnerProcessNeedsHttp pending)) -> RunnerNeedsHttp pending

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
  validateBrokerHttpTranscript (requestHttpTranscript request)
  unless (requestHttpEnabled request || null (requestHttpTranscript request)) (Left (runnerProblem CorruptData "A runner request disabled HTTP but supplied a broker transcript." []))
  case (requestOperation request, requestInputBytes request) of
    (RunnerExport, Nothing) -> do
      when (requestHttpEnabled request) (Left (runnerProblem CorruptData "An exporter request cannot enable brokered HTTP." []))
      unless (null (requestHttpTranscript request)) (Left (runnerProblem CorruptData "An exporter request cannot contain a brokered HTTP transcript." []))
    (RunnerExport, Just _) -> Left (runnerProblem CorruptData "An exporter request cannot contain source input bytes." [])
    (RunnerSourcePreflight, Just _) -> pure ()
    (RunnerSourcePreflight, Nothing) -> unless (requestHttpEnabled request) (Left (runnerProblem CorruptData "A SourceAdapter preflight request has neither input bytes nor brokered HTTP." []))
    (RunnerSourceMaterialize, Just _) -> pure ()
    (RunnerSourceMaterialize, Nothing) -> unless (requestHttpEnabled request) (Left (runnerProblem CorruptData "A SourceAdapter materialization request has neither input bytes nor brokered HTTP." []))
    (RunnerSourceCleanupItem, Nothing) -> unless (requestHttpEnabled request) (Left (runnerProblem CorruptData "A source cleanup request has no brokered HTTP authority." []))
    (RunnerSourceCleanupItem, Just _) -> Left (runnerProblem CorruptData "A source cleanup request cannot contain source input bytes." [])
    (RunnerSourceCleanupItemVerify, Nothing) -> unless (requestHttpEnabled request) (Left (runnerProblem CorruptData "A source cleanup verification has no brokered HTTP authority." []))
    (RunnerSourceCleanupItemVerify, Just _) -> Left (runnerProblem CorruptData "A source cleanup verification cannot contain source input bytes." [])
    (RunnerSourceCleanupContainerInspect, Nothing) -> unless (requestHttpEnabled request) (Left (runnerProblem CorruptData "A source-container inspection has no brokered HTTP authority." []))
    (RunnerSourceCleanupContainerInspect, Just _) -> Left (runnerProblem CorruptData "A source-container inspection cannot contain source input bytes." [])
    (RunnerSourceCleanupContainer, Nothing) -> unless (requestHttpEnabled request) (Left (runnerProblem CorruptData "A source-container cleanup has no brokered HTTP authority." []))
    (RunnerSourceCleanupContainer, Just _) -> Left (runnerProblem CorruptData "A source-container cleanup cannot contain source input bytes." [])
    (RunnerSourceCleanupContainerVerify, Nothing) -> unless (requestHttpEnabled request) (Left (runnerProblem CorruptData "A source-container verification has no brokered HTTP authority." []))
    (RunnerSourceCleanupContainerVerify, Just _) -> Left (runnerProblem CorruptData "A source-container verification cannot contain source input bytes." [])
 where
  validatePayloadPathAndSource (path, payload) = do
    unless (safeRelativePath path) (Left (runnerProblem CorruptData "The runner payload contains an unsafe path." [path]))
    validatePayloadSource path payload

executeLuaRequest :: RunnerRequest -> IO (Either AppError RunnerProcessOutcome)
executeLuaRequest request = do
  replay <- newIORef (HttpReplayState (requestHttpTranscript request) Nothing)
  result <- Lua.runEither $ do
    openSafeLibraries
    installPayloadApi (requestEntryPoint request) (requestPayload request) (requestInputBytes request) (requestHttpEnabled request) replay
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
      RunnerSourceCleanupItem -> do
        receipt <- Lua.forcePeek (peekSourceCleanupReceipt Lua.top)
        case canonicalJsonBytes (sourceCleanupReceiptValue receipt) of
          Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
          Right bytes ->
            pure
              RunnerExportArtifact
                { runnerArtifactBytes = bytes
                , runnerArtifactMediaType = "application/vnd.little-ant.source-cleanup-receipt+json"
                , runnerArtifactSuggestedFilename = "source-cleanup-receipt.json"
                , runnerArtifactWarnings = []
                , runnerArtifactMetadata = Map.singleton "schema" "little-ant/source-cleanup-receipt@1"
                }
      RunnerSourceCleanupItemVerify -> do
        receipt <- Lua.forcePeek (peekSourceCleanupReceipt Lua.top)
        case canonicalJsonBytes (sourceCleanupReceiptValue receipt) of
          Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
          Right bytes ->
            pure
              RunnerExportArtifact
                { runnerArtifactBytes = bytes
                , runnerArtifactMediaType = "application/vnd.little-ant.source-cleanup-receipt+json"
                , runnerArtifactSuggestedFilename = "source-cleanup-verification.json"
                , runnerArtifactWarnings = []
                , runnerArtifactMetadata = Map.singleton "schema" "little-ant/source-cleanup-receipt@1"
                }
      RunnerSourceCleanupContainerInspect -> do
        inspection <- Lua.forcePeek (peekSourceContainerInspection Lua.top)
        case canonicalJsonBytes (sourceContainerInspectionValue inspection) of
          Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
          Right bytes ->
            pure
              RunnerExportArtifact
                { runnerArtifactBytes = bytes
                , runnerArtifactMediaType = "application/vnd.little-ant.source-container-inspection+json"
                , runnerArtifactSuggestedFilename = "source-container-inspection.json"
                , runnerArtifactWarnings = []
                , runnerArtifactMetadata = Map.singleton "schema" "little-ant/source-container-inspection@1"
                }
      RunnerSourceCleanupContainer -> do
        receipt <- Lua.forcePeek (peekSourceCleanupReceipt Lua.top)
        case canonicalJsonBytes (sourceCleanupReceiptValue receipt) of
          Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
          Right bytes ->
            pure
              RunnerExportArtifact
                { runnerArtifactBytes = bytes
                , runnerArtifactMediaType = "application/vnd.little-ant.source-cleanup-receipt+json"
                , runnerArtifactSuggestedFilename = "source-container-cleanup-receipt.json"
                , runnerArtifactWarnings = []
                , runnerArtifactMetadata = Map.singleton "schema" "little-ant/source-cleanup-receipt@1"
                }
      RunnerSourceCleanupContainerVerify -> do
        receipt <- Lua.forcePeek (peekSourceCleanupReceipt Lua.top)
        case canonicalJsonBytes (sourceCleanupReceiptValue receipt) of
          Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
          Right bytes ->
            pure
              RunnerExportArtifact
                { runnerArtifactBytes = bytes
                , runnerArtifactMediaType = "application/vnd.little-ant.source-cleanup-receipt+json"
                , runnerArtifactSuggestedFilename = "source-container-cleanup-verification.json"
                , runnerArtifactWarnings = []
                , runnerArtifactMetadata = Map.singleton "schema" "little-ant/source-cleanup-receipt@1"
                }
    Lua.pop 1
    pure artifact
  replayed <- readIORef replay
  pure $ case replayPending replayed of
    Just pending -> Right (RunnerProcessNeedsHttp pending)
    Nothing
      | not (null (replayRemaining replayed)) -> Left (runnerProblem CorruptData "The Pack completed without consuming its exact brokered HTTP transcript." [])
      | otherwise -> case result of
          Left problem -> Left (runnerProblem ExternalFailure "Lua execution failed." [boundedException problem])
          Right artifact -> validateRunnerArtifact (requestMaximumArtifactBytes request) artifact >> Right (RunnerProcessCompleted artifact)

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

installPayloadApi :: Text -> Map Text ByteString -> Maybe ByteString -> Bool -> IORef HttpReplayState -> Lua.Lua ()
installPayloadApi entry payload inputBytes httpEnabled replay = do
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
    value <- Lua.forcePeek (Lua.peekValue (Lua.nthBottom 1))
    case canonicalJsonBytes value of
      Left problem -> Lua.failLua (Text.unpack (appErrorMessage problem))
      Right encoded -> Lua.pushText (TextEncoding.decodeUtf8 encoded) >> pure 1
  Lua.setglobal "__lant_json_encode"
  Lua.pushHaskellFunction $ do
    segment <- Lua.forcePeek (Lua.peekText (Lua.nthBottom 1))
    Lua.pushText (encodeUrlPathSegment segment)
    pure 1
  Lua.setglobal "__lant_url_encode_path_segment"
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
  Lua.pushBool httpEnabled
  Lua.setglobal "__lant_http_enabled"
  Lua.pushHaskellFunction $ do
    requestValue <- Lua.forcePeek (Lua.peekValue (Lua.nthBottom 1))
    request <- case parseEither parseJSON requestValue of
      Left problem -> Lua.failLua ("invalid brokered HTTP request: " <> problem)
      Right value -> pure value
    step <- liftIO $ atomicModifyIORef' replay (consumeHttpExchange request)
    case step of
      Left problem -> Lua.failLua (Text.unpack problem)
      Right Nothing -> Lua.failLua "__little_ant_http_request_pending__"
      Right (Just response) -> Lua.pushValue (toJSON response) >> pure 1
  Lua.setglobal "__lant_http_request"
  loadChunk trustedBootstrap "@little-ant/bootstrap"
  Lua.callTrace 0 0
 where
  pushModule (path, source) = case moduleName path of
    Just name | path /= entry -> do
      Lua.pushText name
      loadChunk source ("@" <> path)
      Lua.rawset (Lua.nth 3)
    _ -> pure ()

consumeHttpExchange :: BrokerHttpRequest -> HttpReplayState -> (HttpReplayState, Either Text (Maybe BrokerHttpResponse))
consumeHttpExchange request state = case replayPending state of
  Just _ -> (state, Left "a Pack cannot issue another HTTP request while one is pending")
  Nothing -> case replayRemaining state of
    [] -> (state{replayPending = Just request}, Right Nothing)
    exchange : remaining
      | brokerExchangeRequest exchange == request -> (state{replayRemaining = remaining}, Right (Just (brokerExchangeResponse exchange)))
      | otherwise -> (state, Left "the Pack's HTTP request diverged from the exact broker transcript")

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

peekSourceContainerInspection :: Lua.Peeker Lua.Exception SourceContainerInspection
peekSourceContainerInspection index = do
  exactLuaKeys "source container inspection" ["external_identity", "label", "outcome", "item_count", "provider_version", "redacted_detail"] index
  outcome <-
    Lua.peekFieldRaw Lua.peekText "outcome" index >>= \case
      "empty" -> pure SourceContainerEmpty
      "nonempty" -> pure SourceContainerNonempty
      "absent" -> pure SourceContainerAbsent
      "protected" -> pure SourceContainerProtected
      value -> Lua.failPeek (TextEncoding.encodeUtf8 ("unknown source-container inspection outcome: " <> value))
  count <- Lua.peekFieldRaw Lua.peekIntegral "item_count" index
  inspection <-
    SourceContainerInspection
      <$> Lua.peekFieldRaw Lua.peekText "external_identity" index
      <*> Lua.peekFieldRaw Lua.peekText "label" index
      <*> pure outcome
      <*> pure (if count < (0 :: Int) then Nothing else Just count)
      <*> (emptyMeansNothing <$> Lua.peekFieldRaw Lua.peekText "provider_version" index)
      <*> Lua.peekFieldRaw Lua.peekText "redacted_detail" index
      <*> pure (Text.replicate 64 "0")
  case validateSourceContainerInspection inspection of
    Left problem -> Lua.failPeek (TextEncoding.encodeUtf8 (appErrorMessage problem))
    Right () -> pure inspection

peekSourceCleanupReceipt :: Lua.Peeker Lua.Exception SourceCleanupReceipt
peekSourceCleanupReceipt index = do
  exactLuaKeys "source cleanup receipt" ["outcome", "provider_reference", "redacted_detail"] index
  outcome <-
    Lua.peekFieldRaw Lua.peekText "outcome" index >>= \case
      "succeeded" -> pure SourceCleanupSucceeded
      "failed_retryable" -> pure SourceCleanupFailedRetryable
      "failed_terminal" -> pure SourceCleanupFailedTerminal
      "outcome_unknown" -> pure SourceCleanupOutcomeUnknown
      value -> Lua.failPeek (TextEncoding.encodeUtf8 ("unknown source cleanup outcome: " <> value))
  receipt <-
    SourceCleanupReceipt
      outcome
      . emptyMeansNothing
      <$> Lua.peekFieldRaw Lua.peekText "provider_reference" index
      <*> (emptyMeansNothing <$> Lua.peekFieldRaw Lua.peekText "redacted_detail" index)
  case validateSourceCleanupReceipt receipt of
    Left problem -> Lua.failPeek (TextEncoding.encodeUtf8 (appErrorMessage problem))
    Right () -> pure receipt

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
    , "local json_encode = __lant_json_encode"
    , "local url_encode_path_segment = __lant_url_encode_path_segment"
    , "local input_zip_entries = __lant_input_zip_entries"
    , "local http_enabled = __lant_http_enabled"
    , "local http_request = __lant_http_request"
    , "__lant_preload = nil"
    , "__lant_assets = nil"
    , "__lant_input_bytes = nil"
    , "__lant_sha256 = nil"
    , "__lant_base64url_decode = nil"
    , "__lant_json_encode = nil"
    , "__lant_url_encode_path_segment = nil"
    , "__lant_input_zip_entries = nil"
    , "__lant_http_enabled = nil"
    , "__lant_http_request = nil"
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
    , "  end,"
    , "  json = {"
    , "    encode = function(value) return json_encode(value) end"
    , "  },"
    , "  url = {"
    , "    encode_path_segment = function(value)"
    , "      if type(value) ~= 'string' then error('URL path segment must be a string', 2) end"
    , "      return url_encode_path_segment(value)"
    , "    end"
    , "  }"
    , "}"
    , "if http_enabled then"
    , "  lant.http = {"
    , "    request = function(request)"
    , "      if type(request) ~= 'table' then error('http request must be a table', 2) end"
    , "      return http_request(request)"
    , "    end"
    , "  }"
    , "end"
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

encodeUrlPathSegment :: Text -> Text
encodeUrlPathSegment =
  TextEncoding.decodeUtf8
    . ByteString.concatMap encodeByte
    . TextEncoding.encodeUtf8
 where
  encodeByte byte
    | unreserved byte = ByteString.singleton byte
    | otherwise = ByteString.pack [37, hexadecimal (byte `div` 16), hexadecimal (byte `mod` 16)]
  unreserved byte =
    (byte >= 65 && byte <= 90)
      || (byte >= 97 && byte <= 122)
      || (byte >= 48 && byte <= 57)
      || byte `elem` [45, 46, 95, 126]
  hexadecimal nibble = ByteString.index "0123456789ABCDEF" (fromIntegral nibble)

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

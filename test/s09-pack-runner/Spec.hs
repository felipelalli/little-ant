module Main (main) where

import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Aeson (object, toJSON, (.=))
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (UTCTime)
import GHC.Clock (getMonotonicTimeNSec)
import LittleAnt.Error
import LittleAnt.Export
import LittleAnt.Model (SourceMode (..), emptyState)
import LittleAnt.Pack.Format
import LittleAnt.Pack.Http
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Trust
import LittleAnt.Source
import LittleAnt.Store (genesisCursor, sha256Hex)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 isolated HsLua Pack runner"
      [ testCase "an execution-authorized exporter runs through the private process" authorizedExporterProcess
      , testCase "each invocation receives a fresh Lua VM" freshVmPerInvocation
      , testCase "unsafe libraries and dynamic loaders are absent" unsafeLibrariesAbsent
      , testCase "require and asset access remain inside the signed component payload" payloadConfinement
      , testCase "binary Lua strings survive the bounded protocol exactly" binaryArtifact
      , testCase "wall timeout terminates a non-returning exporter" wallTimeout
      , testCase "closed result shape and artifact limit fail without an artifact" invalidResults
      , testCase "a file SourceAdapter sees only host-custodied bytes and returns a closed preflight" authorizedSourceAdapter
      , testCase "a remote SourceAdapter replays a bounded host-brokered HTTP transcript in fresh VMs" brokeredHttpSourceAdapter
      , testCase "an undeclared HTTP route fails before the trusted broker runs" undeclaredHttpRoute
      , testCase "an identical HTTP request cycle fails before a second provider call" repeatedHttpRequest
      ]

brokeredHttpSourceAdapter :: Assertion
brokeredHttpSourceAdapter = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureSourceRegistryWith fixtureHttpSourceComponent brokeredSourceAdapter
  registered <- assertRight (lookupPackComponent fixtureHttpSourceId registry)
  calls <- newIORef []
  let bodyText = Text.replicate 300 "x" <> "::PRIVATE_PROVIDER_TAIL::"
      broker = fixtureHttpBroker bodyText calls
      source = object ["account_label" .= ("Personal account" :: Text)]
      expectedMaterial = SourceTextMaterial ("Buy milk\n" <> bodyText)
  (input, preflight) <- invokePackSourcePreflightHttp client broker registered SourceMigrate "Microsoft To Do · Personal account" source >>= assertRight
  sourceInputMediaType input @?= "application/vnd.little-ant.http-transcript+json"
  sourcePreflightInputDigest preflight @?= sha256Hex (sourceInputBytes input)
  sourcePreflightInputByteCount preflight @?= ByteString.length (sourceInputBytes input)
  observedSupportedModes (sourcePreflightObservation preflight) @?= [SourceSnapshot, SourceSynchronize, SourceMigrate]
  observedCleanupSupported (sourcePreflightObservation preflight) @?= True
  case observedObjects (sourcePreflightObservation preflight) of
    [sourceObject] -> do
      sourceObjectExternalId sourceObject @?= "task:list-1:task-1"
      sourceObjectContainerId sourceObject @?= Just "list:list-1"
      sourceObjectShape sourceObject @?= SourceTaskShape
      sourceObjectMaterial sourceObject @?= summarizeSourceMaterial expectedMaterial
    other -> assertFailure ("unexpected brokered source objects: " <> show other)
  encodedPreflight <- assertRight (canonicalJsonBytes (toJSON preflight))
  assertBool "provider body escaped the sparse preflight" (not ("::PRIVATE_PROVIDER_TAIL::" `ByteString.isInfixOf` encodedPreflight))
  (materializedInput, materializedPreflight, materialization) <-
    invokePackSourceMaterializeHttp client broker registered SourceMigrate "Microsoft To Do · Personal account" source >>= assertRight
  materializedInput @?= input
  materializedPreflight @?= preflight
  materializedObjects materialization @?= Map.singleton "task:list-1:task-1" expectedMaterial
  observedCalls <- readIORef calls
  length observedCalls @?= 4
  (brokerHttpUrl <$> observedCalls)
    @?= [listsUrl, tasksUrl, listsUrl, tasksUrl]

undeclaredHttpRoute :: Assertion
undeclaredHttpRoute = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureSourceRegistryWith fixtureHttpSourceComponent undeclaredHostSource
  registered <- assertRight (lookupPackComponent fixtureHttpSourceId registry)
  calls <- newIORef (0 :: Int)
  let broker = PackHttpBroker $ \_ _ -> modifyIORef' calls (+ 1) >> pure (Right emptyHttpResponse)
  invokePackSourcePreflightHttp client broker registered SourceSnapshot "Fixture account" (object []) >>= assertError PermissionRequired
  readIORef calls >>= (@?= 0)

repeatedHttpRequest :: Assertion
repeatedHttpRequest = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureSourceRegistryWith fixtureHttpSourceComponent repeatedHttpSource
  registered <- assertRight (lookupPackComponent fixtureHttpSourceId registry)
  calls <- newIORef (0 :: Int)
  let broker = PackHttpBroker $ \_ _ -> modifyIORef' calls (+ 1) >> pure (Right emptyHttpResponse)
  invokePackSourcePreflightHttp client broker registered SourceSnapshot "Fixture account" (object []) >>= assertError PreconditionFailed
  readIORef calls >>= (@?= 1)

authorizedSourceAdapter :: Assertion
authorizedSourceAdapter = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureSourceRegistry validSourceAdapter
  registered <- assertRight (lookupPackComponent fixtureSourceId registry)
  let bytes = "Remember the milk " <> ByteString.replicate 200 120 <> "::PRIVATE_TAIL::"
      textMaterial = SourceTextMaterial (TextEncoding.decodeUtf8 bytes)
      input = SourceInput "notes.txt" "text/plain; charset=utf-8" bytes
  preflight <- invokePackSourcePreflight client registered SourceSnapshot input >>= assertRight
  sourcePreflightAdapterId preflight @?= fixtureSourceId
  sourcePreflightContractMajor preflight @?= 1
  assertBool "preflight omitted exact invocation permissions" ("input_bytes" `Text.isInfixOf` sourcePreflightPermissions preflight)
  sourcePreflightInputDigest preflight @?= sha256Hex bytes
  sourcePreflightInputByteCount preflight @?= ByteString.length bytes
  observedSupportedModes (sourcePreflightObservation preflight) @?= [SourceSnapshot, SourceMigrate]
  observedCleanupSupported (sourcePreflightObservation preflight) @?= False
  case observedObjects (sourcePreflightObservation preflight) of
    [sourceObject] -> do
      sourceObjectExternalId sourceObject @?= sha256Hex bytes
      sourceObjectTitle sourceObject @?= "notes.txt"
      sourceObjectShape sourceObject @?= SourceNoteShape
      sourceObjectMaterial sourceObject @?= summarizeSourceMaterial textMaterial
    other -> assertFailure ("unexpected source objects: " <> show other)
  encodedPreflight <- assertRight (canonicalJsonBytes (toJSON preflight))
  assertBool "preflight echoed source bytes beyond the bounded preview" (not ("::PRIVATE_TAIL::" `ByteString.isInfixOf` encodedPreflight))
  (materializedPreflight, materialization) <- invokePackSourceMaterialize client registered SourceSnapshot input >>= assertRight
  materializedPreflight @?= preflight
  materializedObjects materialization @?= Map.singleton (sha256Hex bytes) textMaterial
  invokePackSourcePreflight client registered SourceSynchronize input >>= assertError Unsupported

authorizedExporterProcess :: Assertion
authorizedExporterProcess = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureRegistry validSource fixtureSupportPayload
  let port = packRegistryExportPort client registry
  exportPortCatalog port @?= [ExportDescriptor fixtureComponentId "Fixture Export" fixtureComponentId "little-ant/structure@1"]
  result <- runExportHost port False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing >>= assertRight
  exportArtifactBytes (exportHostArtifact result) @?= "little-ant/structure@1\nsigned asset\n"
  exportArtifactMediaType (exportHostArtifact result) @?= "text/plain; charset=utf-8"
  exportArtifactWarnings (exportHostArtifact result) @?= ["fixture warning"]
  exportArtifactMetadata (exportHostArtifact result) @?= Map.singleton "sandbox" "yes"

freshVmPerInvocation :: Assertion
freshVmPerInvocation = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureRegistry freshVmSource Map.empty
  let port = packRegistryExportPort client registry
  first <- runExportHost port False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing >>= assertRight
  second <- runExportHost port False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing >>= assertRight
  exportArtifactBytes (exportHostArtifact first) @?= "1"
  exportArtifactBytes (exportHostArtifact second) @?= "1"

unsafeLibrariesAbsent :: Assertion
unsafeLibrariesAbsent = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureRegistry sandboxProbeSource Map.empty
  result <- runExportHost (packRegistryExportPort client registry) False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing >>= assertRight
  exportArtifactBytes (exportHostArtifact result) @?= "sandboxed"

payloadConfinement :: Assertion
payloadConfinement = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureRegistry missingModuleSource Map.empty
  failed <- runExportHost (packRegistryExportPort client registry) False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing
  assertError ExternalFailure failed

binaryArtifact :: Assertion
binaryArtifact = do
  client <- fixtureClient factoryPackRunnerLimits
  registry <- fixtureRegistry binarySource Map.empty
  result <- runExportHost (packRegistryExportPort client registry) False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing >>= assertRight
  exportArtifactBytes (exportHostArtifact result) @?= ByteString.pack [0, 1, 127, 128, 255]

wallTimeout :: Assertion
wallTimeout = do
  let shortLimits = factoryPackRunnerLimits{runnerWallTimeoutMicros = 300_000}
  client <- fixtureClient shortLimits
  registry <- fixtureRegistry infiniteSource Map.empty
  started <- getMonotonicTimeNSec
  failed <- runExportHost (packRegistryExportPort client registry) False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing
  finished <- getMonotonicTimeNSec
  assertError ExternalFailure failed
  assertBool "timeout did not terminate the private process promptly" (finished - started < 3_000_000_000)

invalidResults :: Assertion
invalidResults = do
  client <- fixtureClient factoryPackRunnerLimits{runnerMaximumArtifactBytes = 8}
  unknownFieldRegistry <- fixtureRegistry unknownFieldSource Map.empty
  runExportHost (packRegistryExportPort client unknownFieldRegistry) False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing >>= assertError ExternalFailure
  oversizedRegistry <- fixtureRegistry oversizedSource Map.empty
  runExportHost (packRegistryExportPort client oversizedRegistry) False fixtureTime genesisCursor emptyState fixtureComponentId ExportWholeDataset Nothing >>= assertError ExternalFailure

fixtureClient :: PackRunnerLimits -> IO PackRunnerClient
fixtureClient limits = do
  client <- defaultPackRunnerClient
  pure client{packRunnerLimits = limits}

fixtureRegistry :: ByteString -> Map Text ByteString -> IO PackRegistry
fixtureRegistry = fixtureRegistryFor fixtureComponent "exporters/fixture"

fixtureSourceRegistry :: ByteString -> IO PackRegistry
fixtureSourceRegistry entrySource = fixtureRegistryFor fixtureSourceComponent "sources/fixture" entrySource Map.empty

fixtureSourceRegistryWith :: PackComponent -> ByteString -> IO PackRegistry
fixtureSourceRegistryWith component entrySource = fixtureRegistryFor component "sources/http-fixture" entrySource Map.empty

fixtureRegistryFor :: PackComponent -> Text -> ByteString -> Map Text ByteString -> IO PackRegistry
fixtureRegistryFor component root entrySource support = do
  let payload =
        Map.unions
          [ Map.fromList
              [ ("config.schema.json", "{\"additionalProperties\":false,\"type\":\"object\"}")
              , ("main.lua", entrySource)
              ]
          , support
          ]
      rootedPayload = Map.mapKeys ((root <> "/") <>) payload
      manifest = fixtureManifest component rootedPayload
  manifestBytes <- assertRight (encodePackManifest manifest)
  signatureBytes <- assertRight (encodePackSignature (signedDocument manifestBytes))
  archive <- assertRight (buildCanonicalPackArchive manifestBytes signatureBytes rootedPayload)
  structural <- assertRight (validatePackArchive archive)
  authenticated <- assertRight (authenticatePack structural)
  scope <- assertRight (mkProfileScope "default")
  let policy =
        PackTrustPolicy
          { trustSupportedLittleAntMajor = 1
          , trustBuiltInArtifacts = Set.empty
          , trustOfficialCatalogSequence = Nothing
          , trustOfficialCatalogExpiresAt = Nothing
          , trustOfficialReleaseGrants = Set.empty
          , trustOfficialPinAuthorizations = Set.empty
          , trustCommunityPublishers = Set.singleton (communityTrust authenticated)
          , trustRevokedKeyFingerprints = Set.empty
          , trustRevokedArchiveDigests = Set.empty
          }
  let selectedId = componentId (componentCommon component)
  install <- assertRight (authorizePackInstall fixtureTime scope policy (Set.singleton selectedId) authenticated)
  execution <- assertRight (authorizePinnedPackExecution fixtureTime scope policy (installAuthorizedPin install) authenticated)
  assertRight (buildPackRegistry scope [execution])

fixtureManifest :: PackComponent -> Map Text ByteString -> PackManifest
fixtureManifest component payload =
  PackManifest
    { packName = "org.example.runner-fixture"
    , packVersion = "1.0.0"
    , packDisplayName = "Runner Fixture"
    , packPublisher = "org.example.publisher"
    , packLittleAntMajor = 1
    , packComponents = [component]
    , packFiles = payloadRecord <$> Map.toAscList payload
    , packLinks = Nothing
    }

fixtureComponent :: PackComponent
fixtureComponent =
  ExecutableComponent
    ComponentCommon
      { componentId = fixtureComponentId
      , componentKind = ReadOnlyExporterComponent
      , componentContractMajor = 1
      , componentRoot = "exporters/fixture"
      , componentConfigurationSchema = "config.schema.json"
      }
    "main.lua"
    ComponentPermissions
      { permissionCredentialSlots = []
      , permissionOAuthDeviceAuthorizations = []
      , permissionHttp = []
      , permissionEffectPurposes = []
      , permissionProjections = ["little-ant/structure@1"]
      , permissionHostCapabilities = []
      }

fixtureSourceComponent :: PackComponent
fixtureSourceComponent =
  ExecutableComponent
    ComponentCommon
      { componentId = fixtureSourceId
      , componentKind = SourceAdapterComponent
      , componentContractMajor = 1
      , componentRoot = "sources/fixture"
      , componentConfigurationSchema = "config.schema.json"
      }
    "main.lua"
    ComponentPermissions
      { permissionCredentialSlots = []
      , permissionOAuthDeviceAuthorizations = []
      , permissionHttp = []
      , permissionEffectPurposes = []
      , permissionProjections = []
      , permissionHostCapabilities = [InputBytesCapability]
      }

fixtureHttpSourceComponent :: PackComponent
fixtureHttpSourceComponent =
  ExecutableComponent
    ComponentCommon
      { componentId = fixtureHttpSourceId
      , componentKind = SourceAdapterComponent
      , componentContractMajor = 1
      , componentRoot = "sources/http-fixture"
      , componentConfigurationSchema = "config.schema.json"
      }
    "main.lua"
    ComponentPermissions
      { permissionCredentialSlots = [CredentialSlot "microsoft" OAuthDeviceAuthorization]
      , permissionOAuthDeviceAuthorizations =
          [ OAuthDeviceAuthorizationPermission
              "microsoft"
              "https://login.microsoftonline.com/common/oauth2/v2.0/devicecode"
              "https://login.microsoftonline.com/common/oauth2/v2.0/token"
              "client_id"
              (Set.fromList ["Tasks.Read", "offline_access"])
          ]
      , permissionHttp = [HttpPermission ["GET"] "graph.microsoft.com" "/v1.0/me/todo" (Just "microsoft")]
      , permissionEffectPurposes = [SourceCleanupItemPermission, SourceCleanupContainerPermission]
      , permissionProjections = []
      , permissionHostCapabilities = []
      }

payloadRecord :: (Text, ByteString) -> PayloadFile
payloadRecord (path, bytes) =
  PayloadFile path (fromIntegral (ByteString.length bytes)) (if ".lua" `Text.isSuffixOf` path then "text/x-lua; charset=utf-8" else "application/octet-stream") (sha256Hex bytes)

signedDocument :: ByteString -> PackSignatureDocument
signedDocument manifestBytes =
  PackSignatureDocument
    { packSignaturePublicKey = encodeBytes fixturePublicKeyBytes
    , packSignatureKeyFingerprint = sha256Hex fixturePublicKeyBytes
    , packSignatureValue = encodeBytes (convert (Ed25519.sign fixtureSecretKey fixturePublicKey manifestBytes))
    }

communityTrust :: AuthenticatedPack -> TrustedCommunityPublisher
communityTrust authenticated =
  TrustedCommunityPublisher
    { communityPublisher = artifactPublisher (authenticatedPackIdentity authenticated)
    , communityPublicKey = authenticatedSignerPublicKey authenticated
    , communityKeyFingerprint = authenticatedSignerFingerprint authenticated
    }

encodeBytes :: ByteString -> Text
encodeBytes = TextEncoding.decodeUtf8 . Base64Url.encodeUnpadded

fixtureSecretKey :: Ed25519.SecretKey
fixtureSecretKey = case Ed25519.secretKey (ByteString.pack [0 .. 31]) of
  CryptoPassed value -> value
  CryptoFailed problem -> error (show problem)

fixturePublicKey :: Ed25519.PublicKey
fixturePublicKey = Ed25519.toPublic fixtureSecretKey

fixturePublicKeyBytes :: ByteString
fixturePublicKeyBytes = convert fixturePublicKey

fixtureComponentId :: Text
fixtureComponentId = "fixture_export"

fixtureSourceId :: Text
fixtureSourceId = "fixture_source"

fixtureHttpSourceId :: Text
fixtureHttpSourceId = "fixture_http_source"

fixtureTime :: UTCTime
fixtureTime = read "2026-08-08 12:00:00 UTC"

fixtureSupportPayload :: Map Text ByteString
fixtureSupportPayload =
  Map.fromList
    [
      ( "helper.lua"
      , "return { render = function(projection) return projection.schema .. '\\n' end }\n"
      )
    , ("template.txt", "signed asset\n")
    ]

validSource :: ByteString
validSource =
  "local helper = require('helper')\n"
    <> "return function(projection)\n"
    <> "  return { bytes = helper.render(projection) .. lant.asset('template.txt'), media_type = 'text/plain; charset=utf-8', suggested_filename = 'fixture.txt', warnings = {'fixture warning'}, metadata = {sandbox = 'yes'} }\n"
    <> "end\n"

freshVmSource :: ByteString
freshVmSource =
  "invocations = (invocations or 0) + 1\n"
    <> "return function(_) return {bytes=tostring(invocations), media_type='text/plain', suggested_filename='fresh.txt', warnings={}, metadata={}} end\n"

sandboxProbeSource :: ByteString
sandboxProbeSource =
  "return function(_)\n"
    <> "  if io ~= nil or os ~= nil or debug ~= nil or package ~= nil or load ~= nil or loadfile ~= nil or dofile ~= nil or print ~= nil or warn ~= nil or collectgarbage ~= nil then error('unsafe global exposed') end\n"
    <> "  if math.random ~= nil or math.randomseed ~= nil or string.dump ~= nil then error('nondeterministic or bytecode function exposed') end\n"
    <> "  return {bytes='sandboxed', media_type='text/plain', suggested_filename='safe.txt', warnings={}, metadata={}}\n"
    <> "end\n"

missingModuleSource :: ByteString
missingModuleSource = "return function(_) require('not_present') end\n"

binarySource :: ByteString
binarySource = "return function(_) return {bytes=string.char(0,1,127,128,255), media_type='application/octet-stream', suggested_filename='bytes.bin', warnings={}, metadata={}} end\n"

infiniteSource :: ByteString
infiniteSource = "return function(_) while true do end end\n"

unknownFieldSource :: ByteString
unknownFieldSource = "return function(_) return {bytes='ok', media_type='text/plain', suggested_filename='x.txt', warnings={}, metadata={}, surprise=true} end\n"

oversizedSource :: ByteString
oversizedSource = "return function(_) return {bytes='123456789', media_type='text/plain', suggested_filename='x.txt', warnings={}, metadata={}} end\n"

validSourceAdapter :: ByteString
validSourceAdapter =
  "return function(request)\n"
    <> "  local bytes = lant.input_bytes()\n"
    <> "  return {source_label='Fixture source', account_label='', identity={content_sha256=lant.sha256(bytes)}, supported_modes={'snapshot','migrate'}, cleanup_supported=false, containers={}, objects={{external_id=request.input.digest, locator='sha256:' .. request.input.digest, container_id='', title=request.input.label, shape='note', completed=false, attachment_count=0, content={kind='text', text=bytes}, duplicate_keys={request.input.digest}}}, unsupported_fields={}, warnings={}}\n"
    <> "end\n"

brokeredSourceAdapter :: ByteString
brokeredSourceAdapter =
  "return function(request)\n"
    <> "  if request.schema ~= 'little-ant/source-provider-request@1' then error('unexpected provider request') end\n"
    <> "  local lists = lant.http.request({method='GET', url='"
    <> TextEncoding.encodeUtf8 listsUrl
    <> "', headers={accept='application/json'}})\n"
    <> "  if lists.status ~= 200 then error('list request failed') end\n"
    <> "  local list = lists.json.value[1]\n"
    <> "  local tasks = lant.http.request({method='GET', url=lists.json.tasks_url, headers={accept='application/json'}})\n"
    <> "  if tasks.status ~= 200 then error('task request failed') end\n"
    <> "  local task = tasks.json.value[1]\n"
    <> "  local content = task.title .. '\\n' .. task.body.content\n"
    <> "  return {source_label='Microsoft To Do', account_label=request.source.account_label, identity={list_count='1', item_count='1'}, supported_modes={'snapshot','synchronize','migrate'}, cleanup_supported=true, containers={{external_id='list:' .. list.id, label=list.displayName}}, objects={{external_id='task:' .. list.id .. ':' .. task.id, locator='ms-todo:' .. list.id .. '/' .. task.id, container_id='list:' .. list.id, title=task.title, shape='task', completed=false, attachment_count=0, content={kind='text', text=content}, duplicate_keys={lant.sha256(content)}}}, unsupported_fields={}, warnings={}}\n"
    <> "end\n"

undeclaredHostSource :: ByteString
undeclaredHostSource =
  "return function(_) lant.http.request({method='GET', url='https://example.com/v1.0/me/todo/lists', headers={}}) end\n"

repeatedHttpSource :: ByteString
repeatedHttpSource =
  "return function(_) local request={method='GET', url='" <> TextEncoding.encodeUtf8 listsUrl <> "', headers={}}; lant.http.request(request); lant.http.request(request) end\n"

fixtureHttpBroker :: Text -> IORef [BrokerHttpRequest] -> PackHttpBroker
fixtureHttpBroker bodyText calls = PackHttpBroker $ \permission request -> do
  httpPermissionCredentialSlot permission @?= Just "microsoft"
  modifyIORef' calls (<> [request])
  pure . Right $ case brokerHttpUrl request of
    url
      | url == listsUrl ->
          BrokerHttpResponse
            200
            (Map.singleton "content-type" "application/json")
            (object ["value" .= [object ["id" .= ("list-1" :: Text), "displayName" .= ("Groceries" :: Text)]], "tasks_url" .= tasksUrl])
    _ ->
      BrokerHttpResponse
        200
        (Map.singleton "content-type" "application/json")
        (object ["value" .= [object ["id" .= ("task-1" :: Text), "title" .= ("Buy milk" :: Text), "body" .= object ["content" .= bodyText]]]])

emptyHttpResponse :: BrokerHttpResponse
emptyHttpResponse = BrokerHttpResponse 200 (Map.singleton "content-type" "application/json") (object [])

listsUrl, tasksUrl :: Text
listsUrl = "https://graph.microsoft.com/v1.0/me/todo/lists"
tasksUrl = "https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks"

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertError :: ErrorCode -> Either AppError value -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure ("expected " <> show expected <> " failure")

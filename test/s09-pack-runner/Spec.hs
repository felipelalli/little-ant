module Main (main) where

import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
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
import LittleAnt.Model (emptyState)
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Trust
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
      ]

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
fixtureRegistry entrySource support = do
  let payload =
        Map.unions
          [ Map.fromList
              [ ("config.schema.json", "{\"additionalProperties\":false,\"type\":\"object\"}")
              , ("main.lua", entrySource)
              ]
          , support
          ]
      rootedPayload = Map.mapKeys ("exporters/fixture/" <>) payload
      manifest = fixtureManifest rootedPayload
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
          , trustCommunityPublishers = Set.singleton (communityTrust authenticated)
          , trustRevokedKeyFingerprints = Set.empty
          , trustRevokedArchiveDigests = Set.empty
          }
  install <- assertRight (authorizePackInstall fixtureTime scope policy (Set.singleton fixtureComponentId) authenticated)
  execution <- assertRight (authorizePinnedPackExecution fixtureTime scope policy (installAuthorizedPin install) authenticated)
  assertRight (buildPackRegistry scope [execution])

fixtureManifest :: Map Text ByteString -> PackManifest
fixtureManifest payload =
  PackManifest
    { packName = "org.example.runner-fixture"
    , packVersion = "1.0.0"
    , packDisplayName = "Runner Fixture"
    , packPublisher = "org.example.publisher"
    , packLittleAntMajor = 1
    , packComponents = [fixtureComponent]
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
      , permissionHttp = []
      , permissionEffectPurposes = []
      , permissionProjections = ["little-ant/structure@1"]
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

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertError :: ErrorCode -> Either AppError value -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure ("expected " <> show expected <> " failure")

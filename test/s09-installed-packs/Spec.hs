module Main (main) where

import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Pack.Catalog
import LittleAnt.Pack.Format
import LittleAnt.Pack.Installed
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Store
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 installed Pack loading"
      [ testCase "production combines the standard Pack with exact trusted-publisher pins" communityPinLoads
      , testCase "a configured pin with a missing archive fails the whole registry" missingArchiveFails
      , testCase "official pins and catalog state fail explicitly without a compiled root" officialTrustUnavailable
      , testCase "accepted catalog history authorizes an exact official pin offline" officialHistoryLoads
      , testCase "a later known revocation disables the previously accepted pin" knownRevocationWins
      , testCase "an exact retained Pack version coexists without replacing the active default" retainedVersionCoexists
      ]

communityPinLoads :: Assertion
communityPinLoads = withProfile "lant-installed-community" $ \paths scope -> do
  authenticated <- connectorPack
  let publisher = trustedCommunityPublisher authenticated
      policy = emptyPolicy{trustCommunityPublishers = Set.singleton publisher}
  install <- assertRight (authorizePackInstall fixtureNow scope policy connectorComponents authenticated)
  _ <- storeAuthorizedPack (PackStoreConfig (packStoreDirectory paths)) install >>= assertRight
  let integrations = integrationsFor (installAuthorizedPin install) (Set.singleton publisher)
  registry <- loadProfilePackRegistry fixtureNow scope paths integrations OfficialCatalogUnavailable >>= assertRight
  _ <- assertRight (lookupPackComponent "tree" registry)
  connector <- assertRight (lookupPackComponent "microsoft_todo" registry)
  registeredPackIdentity connector @?= authenticatedPackIdentity authenticated

retainedVersionCoexists :: Assertion
retainedVersionCoexists = do
  authenticated <- connectorPack
  scope <- assertRight (mkProfileScope "default")
  let publisher = trustedCommunityPublisher authenticated
      policy = emptyPolicy{trustCommunityPublishers = Set.singleton publisher}
  installed <- assertRight (authorizePackInstall fixtureNow scope policy connectorComponents authenticated)
  active <- assertRight (authorizePinnedPackExecution fixtureNow scope policy (installAuthorizedPin installed) authenticated)
  let activeIdentity = authenticatedPackIdentity authenticated
      retainedIdentity =
        activeIdentity
          { artifactVersion = "0.9.0"
          , artifactManifestDigest = Text.replicate 64 "a"
          , artifactArchiveDigest = Text.replicate 64 "b"
          }
      retainedPack = authenticated{authenticatedPackIdentity = retainedIdentity}
      retainedPin = (executionAuthorizedPin active){pinArtifact = retainedIdentity}
      retained = active{executionAuthorizedPack = retainedPack, executionAuthorizedPin = retainedPin}
  registry <- assertRight (buildPackRegistryWithRetained scope [active] [retained])
  selected <- assertRight (lookupPackComponent "microsoft_todo" registry)
  registeredPackIdentity selected @?= activeIdentity
  older <- assertRight (lookupPackComponentForArtifact retainedIdentity "microsoft_todo" registry)
  registeredPackIdentity older @?= retainedIdentity
  length (registryComponents registry) @?= 1

missingArchiveFails :: Assertion
missingArchiveFails = withProfile "lant-installed-missing" $ \paths scope -> do
  authenticated <- connectorPack
  let publisher = trustedCommunityPublisher authenticated
      policy = emptyPolicy{trustCommunityPublishers = Set.singleton publisher}
  install <- assertRight (authorizePackInstall fixtureNow scope policy connectorComponents authenticated)
  loadProfilePackRegistry
    fixtureNow
    scope
    paths
    (integrationsFor (installAuthorizedPin install) (Set.singleton publisher))
    OfficialCatalogUnavailable
    >>= assertError ExternalFailure

officialTrustUnavailable :: Assertion
officialTrustUnavailable = withProfile "lant-installed-unavailable" $ \paths scope -> do
  authenticated <- connectorPack
  let pin =
        PackPin
          { pinArtifact = authenticatedPackIdentity authenticated
          , pinSignerFingerprint = authenticatedSignerFingerprint authenticated
          , pinTrustOrigin = PinVerifiedOfficial 1
          , pinEnabledComponents = connectorComponents
          }
  loadProfilePackRegistry fixtureNow scope paths (integrationsFor pin Set.empty) OfficialCatalogUnavailable
    >>= assertError PermissionRequired

  ByteString.writeFile (officialCatalogStateFile paths) "untrusted-state-must-not-be-ignored"
  loadProfilePackRegistry fixtureNow scope paths emptyIntegrations OfficialCatalogUnavailable
    >>= assertError PermissionRequired

officialHistoryLoads :: Assertion
officialHistoryLoads = withProfile "lant-installed-official" $ \paths scope -> do
  authenticated <- connectorPack
  root <- assertRight fixtureCatalogRoot
  accepted <- persistCatalog paths root authenticated 1 []
  let policy = catalogTrustPolicy fixtureNow 1 Set.empty Set.empty accepted
  install <- assertRight (authorizePackInstall fixtureNow scope policy connectorComponents authenticated)
  _ <- storeAuthorizedPack (PackStoreConfig (packStoreDirectory paths)) install >>= assertRight
  let integrations = integrationsFor (installAuthorizedPin install) Set.empty
  registry <- loadProfilePackRegistry fixtureNow scope paths integrations (OfficialCatalogCompiledRoot root) >>= assertRight
  connector <- assertRight (lookupPackComponent "microsoft_todo" registry)
  registeredPackIdentity connector @?= authenticatedPackIdentity authenticated

knownRevocationWins :: Assertion
knownRevocationWins = withProfile "lant-installed-revoked" $ \paths scope -> do
  authenticated <- connectorPack
  root <- assertRight fixtureCatalogRoot
  accepted <- persistCatalog paths root authenticated 1 []
  let policy = catalogTrustPolicy fixtureNow 1 Set.empty Set.empty accepted
  install <- assertRight (authorizePackInstall fixtureNow scope policy connectorComponents authenticated)
  _ <- storeAuthorizedPack (PackStoreConfig (packStoreDirectory paths)) install >>= assertRight
  let revocation =
        CatalogRevocation
          RevokeArchive
          (artifactArchiveDigest (authenticatedPackIdentity authenticated))
          "withdrawn fixture"
          fixtureNow
  _ <- persistCatalog paths root authenticated 2 [revocation]
  loadProfilePackRegistry
    fixtureNow
    scope
    paths
    (integrationsFor (installAuthorizedPin install) Set.empty)
    (OfficialCatalogCompiledRoot root)
    >>= assertError PermissionRequired

withProfile :: String -> (ProfilePaths -> ProfileScope -> Assertion) -> Assertion
withProfile label action = withSystemTempDirectory label $ \root -> do
  let roots = XdgRoots (root </> "config") (root </> "data") (root </> "state") (root </> "runtime")
  paths <- createProfile roots "default" fixtureProfileUuid >>= assertRight
  scope <- assertRight (mkProfileScope "default")
  action paths scope

connectorPack :: IO AuthenticatedPack
connectorPack = do
  bytes <- ByteString.readFile "packs/official-connectors/official-connectors.lantpack"
  structural <- assertRight (validatePackArchive bytes)
  assertRight (authenticatePack structural)

connectorComponents :: Set.Set Text
connectorComponents = Set.singleton "microsoft_todo"

trustedCommunityPublisher :: AuthenticatedPack -> TrustedCommunityPublisher
trustedCommunityPublisher authenticated =
  TrustedCommunityPublisher
    { communityPublisher = artifactPublisher (authenticatedPackIdentity authenticated)
    , communityPublicKey = authenticatedSignerPublicKey authenticated
    , communityKeyFingerprint = authenticatedSignerFingerprint authenticated
    }

integrationsFor :: PackPin -> Set.Set TrustedCommunityPublisher -> IntegrationsConfig
integrationsFor pin publishers =
  emptyIntegrations
    { installedComponents = Map.singleton (artifactName (pinArtifact pin)) pin
    , trustedPublishers = publishers
    }

emptyIntegrations :: IntegrationsConfig
emptyIntegrations = IntegrationsConfig Map.empty Map.empty Map.empty Map.empty Set.empty

emptyPolicy :: PackTrustPolicy
emptyPolicy =
  PackTrustPolicy
    { trustSupportedLittleAntMajor = 1
    , trustBuiltInArtifacts = Set.empty
    , trustOfficialCatalogSequence = Nothing
    , trustOfficialCatalogExpiresAt = Nothing
    , trustOfficialReleaseGrants = Set.empty
    , trustOfficialPinAuthorizations = Set.empty
    , trustCommunityPublishers = Set.empty
    , trustRevokedKeyFingerprints = Set.empty
    , trustRevokedArchiveDigests = Set.empty
    }

persistCatalog :: ProfilePaths -> CatalogRoot -> AuthenticatedPack -> Integer -> [CatalogRevocation] -> IO AcceptedCatalogState
persistCatalog paths root authenticated sequenceNumber revocations = do
  let catalog = connectorCatalog authenticated sequenceNumber revocations
  catalogBytes <- assertRight (encodeOfficialPackCatalog catalog)
  signatureBytes <- assertRight (encodeCatalogSignature (catalogSignature root catalogBytes))
  refreshOfficialPackCatalog
    (CatalogStateConfig (officialCatalogStateFile paths))
    root
    fixtureNow
    catalogBytes
    signatureBytes
    >>= assertRight

connectorCatalog :: AuthenticatedPack -> Integer -> [CatalogRevocation] -> OfficialPackCatalog
connectorCatalog authenticated sequenceNumber revocations =
  let identity = authenticatedPackIdentity authenticated
   in OfficialPackCatalog
        { officialCatalogSequence = sequenceNumber
        , officialCatalogExpiresAt = addUTCTime 86400 fixtureNow
        , officialCatalogDelegations =
            [ CatalogPublisherDelegation
                { catalogPublisherId = artifactPublisher identity
                , catalogPublisherPublicKey = authenticatedSignerPublicKey authenticated
                , catalogPublisherKeyFingerprint = authenticatedSignerFingerprint authenticated
                , catalogPublisherNamePrefixes = ["org.littleant."]
                }
            ]
        , officialCatalogReleases =
            [ CatalogRelease
                { catalogReleasePublisher = artifactPublisher identity
                , catalogReleaseName = artifactName identity
                , catalogReleaseVersion = artifactVersion identity
                , catalogReleaseManifestDigest = artifactManifestDigest identity
                , catalogReleaseArchiveDigest = artifactArchiveDigest identity
                }
            ]
        , officialCatalogRevocations = revocations
        }

catalogSignature :: CatalogRoot -> ByteString -> CatalogSignatureDocument
catalogSignature root bytes =
  CatalogSignatureDocument
    { catalogSignatureRootFingerprint = catalogRootFingerprint root
    , catalogSignatureValue = encodeBase64 (convert (Ed25519.sign fixtureCatalogSecretKey (Ed25519.toPublic fixtureCatalogSecretKey) bytes))
    }

fixtureCatalogRoot :: Either AppError CatalogRoot
fixtureCatalogRoot = catalogRootFromPublicKey 0 (encodeBase64 (convert (Ed25519.toPublic fixtureCatalogSecretKey)))

fixtureCatalogSecretKey :: Ed25519.SecretKey
fixtureCatalogSecretKey = case Ed25519.secretKey (ByteString.pack [32 .. 63]) of
  CryptoPassed key -> key
  CryptoFailed problem -> error (show problem)

encodeBase64 :: ByteString -> Text
encodeBase64 = TextEncoding.decodeUtf8 . Base64Url.encodeUnpadded

fixtureNow :: UTCTime
fixtureNow = UTCTime (fromGregorian 2026 8 9) (secondsToDiffTime (8 * 60 * 60))

fixtureProfileUuid :: UUIDv7
fixtureProfileUuid = either (error . Text.unpack) id (parseUUIDv7 "019fe876-9380-7b23-b377-1071a653e52d")

assertRight :: (Show problem) => Either problem value -> IO value
assertRight = either (assertFailure . show) pure

assertError :: ErrorCode -> Either AppError value -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure ("expected " <> show expected <> " failure")

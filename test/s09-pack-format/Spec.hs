module Main (main) where

import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bits (xor, (.&.))
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
import Data.Time
import Data.Word (Word8)
import LittleAnt.Error (AppError)
import LittleAnt.Id (UUIDv7, parseUUIDv7)
import LittleAnt.Pack.Catalog
import LittleAnt.Pack.Format
import LittleAnt.Pack.Http
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Store
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import LittleAnt.Store (sha256Hex)
import System.Directory hiding (emptyPermissions)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Files
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 canonical Pack format"
      [ testCase "the canonical writer is reproducible and round-trips structural identity" canonicalRoundTrip
      , testCase "noncanonical ZIP bytes and trailing data fail closed" zipMutations
      , testCase "pack.json and signature.json require exact JCS and closed keys" controlDocuments
      , testCase "permissions are component-local and kind constrained" permissionIsolation
      , testCase "brokered HTTP authority rejects ambiguous and escaped routes" httpAuthorityConfinement
      , testCase "component roots and file ownership are unambiguous" componentOwnership
      , testCase "payload length, digest, and entry set are verified before authority" payloadIntegrity
      , testCase "unsafe and Unicode-colliding paths are rejected by the writer" pathSafety
      , testCase "JCS object ordering follows UTF-16 code units" jcsOrdering
      , testCase "Ed25519 authenticates the exact manifest and canonical key identity" signatureAuthentication
      , testCase "revocation dominates every positive trust source" revocationDominates
      , testCase "expired official metadata blocks install but preserves an accepted pin" expiredOfficialCatalog
      , testCase "untrusting a community publisher disables its existing pin" communityUntrust
      , testCase "pins cannot authorize another artifact or undeclared component" pinConfinement
      , testCase "trust policy rejects release equivocation" trustPolicyEquivocation
      , testCase "content-addressed store is private, idempotent, and reverified on load" packStoreLifecycle
      , testCase "stored Pack tampering and path substitution fail closed" packStoreTampering
      , testCase "registry accepts only authorized enabled components without collisions" packRegistryConfinement
      , testCase "integrations YAML round-trips exact typed pins and publisher keys" typedIntegrationsRoundTrip
      , testCase "official catalogs grant exact releases and reject stale or invalid candidates" officialCatalogAcceptance
      , testCase "catalog revocations remain effective when later catalogs omit them" officialCatalogRevocationMemory
      , testCase "dual-signed root rotation survives binaries anchored at either root" officialCatalogRootRotation
      , testCase "accepted catalog history is private, atomic, and reverified from disk" officialCatalogPersistence
      ]

canonicalRoundTrip :: Assertion
canonicalRoundTrip = do
  first <- fixtureArchive fixtureManifest fixturePayload
  second <- fixtureArchive fixtureManifest fixturePayload
  first @?= second
  validated <- assertRight (validatePackArchive first)
  packName (structurallyValidManifest validated) @?= "org.littleant.standard"
  packVersion (structurallyValidManifest validated) @?= "1.0.0"
  structurallyValidPayload validated @?= fixturePayload
  structurallyValidManifestDigest validated @?= sha256Hex (structurallyValidManifestBytes validated)
  structurallyValidArchiveDigest validated @?= sha256Hex first

zipMutations :: Assertion
zipMutations = do
  archive <- fixtureArchive fixtureManifest fixturePayload
  assertLeft "local timestamp" (validatePackArchive (replaceByte 10 1 archive))
  assertLeft "UTF-8 flag" (validatePackArchive (replaceByte 7 0 archive))
  assertLeft "compression method" (validatePackArchive (replaceByte 8 8 archive))
  assertLeft "payload byte" (validatePackArchive (replaceNeedleByte "return" archive))
  assertLeft "trailing data" (validatePackArchive (archive <> "x"))

controlDocuments :: Assertion
controlDocuments = do
  manifestBytes <- assertRight (encodePackManifest fixtureManifest)
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  assertLeft "manifest whitespace" (buildCanonicalPackArchive (" " <> manifestBytes) signatureBytes fixturePayload)
  assertLeft "signature whitespace" (buildCanonicalPackArchive manifestBytes (signatureBytes <> "\n") fixturePayload)

  manifestObject <- assertObject (toJSON fixtureManifest)
  let extraManifest = Object (KeyMap.insert "permissions" (object []) manifestObject)
  extraManifestBytes <- assertRight (canonicalJsonBytes extraManifest)
  archiveWithPackPermission <- assertRight (buildCanonicalPackArchive extraManifestBytes signatureBytes fixturePayload)
  assertLeft "Pack-wide permissions" (validatePackArchive archiveWithPackPermission)

  signatureObject <- assertObject (toJSON fixtureSignature)
  let extraSignature = Object (KeyMap.insert "label" "not authority" signatureObject)
  extraSignatureBytes <- assertRight (canonicalJsonBytes extraSignature)
  archiveWithSignatureLabel <- assertRight (buildCanonicalPackArchive manifestBytes extraSignatureBytes fixturePayload)
  assertLeft "signature display label" (validatePackArchive archiveWithSignatureLabel)

permissionIsolation :: Assertion
permissionIsolation = do
  let escalated =
        emptyPermissions
          { permissionCredentialSlots = [CredentialSlot "account" BearerToken]
          , permissionHttp = [HttpPermission ["GET"] "example.com" "/v1" (Just "account")]
          }
      exporter = ExecutableComponent fixtureCommon "main.lua" escalated
  assertLeft "exporter authority escalation" (encodePackManifest fixtureManifest{packComponents = [exporter]})

  let sourceCommon = fixtureCommon{componentKind = SourceAdapterComponent}
      invalidSource = ExecutableComponent sourceCommon "main.lua" emptyPermissions{permissionHostCapabilities = [LoopbackHttpCapability]}
  assertLeft "SourceAdapter UI authority" (encodePackManifest fixtureManifest{packComponents = [invalidSource]})

  let deviceSlot = CredentialSlot "account" OAuthDeviceAuthorization
      authorization =
        OAuthDeviceAuthorizationPermission
          "account"
          "https://login.microsoftonline.com/common/oauth2/v2.0/devicecode"
          "https://login.microsoftonline.com/common/oauth2/v2.0/token"
          "client_id"
          (Set.fromList ["Tasks.Read", "offline_access"])
      missingAuthorization = ExecutableComponent sourceCommon "main.lua" emptyPermissions{permissionCredentialSlots = [deviceSlot]}
      unsignedScope = ExecutableComponent sourceCommon "main.lua" emptyPermissions{permissionCredentialSlots = [deviceSlot], permissionOAuthDeviceAuthorizations = [authorization{oauthDeviceScopes = Set.singleton "Tasks.Read"}]}
      insecureEndpoint = ExecutableComponent sourceCommon "main.lua" emptyPermissions{permissionCredentialSlots = [deviceSlot], permissionOAuthDeviceAuthorizations = [authorization{oauthDeviceTokenEndpoint = "http://login.microsoftonline.com/token"}]}
  assertLeft "OAuth slot without signed authorization" (encodePackManifest fixtureManifest{packComponents = [missingAuthorization]})
  assertLeft "OAuth authorization without refresh custody" (encodePackManifest fixtureManifest{packComponents = [unsignedScope]})
  assertLeft "OAuth authorization over insecure endpoint" (encodePackManifest fixtureManifest{packComponents = [insecureEndpoint]})

  let uiCommon = fixtureCommon{componentKind = UIAdapterComponent}
      invalidUi = ExecutableComponent uiCommon "main.lua" emptyPermissions{permissionEffectPurposes = [CalendarCreatePermission]}
  assertLeft "UIAdapter effect authority" (encodePackManifest fixtureManifest{packComponents = [invalidUi]})

  let overlapping =
        emptyPermissions
          { permissionCredentialSlots = [CredentialSlot "account" BearerToken]
          , permissionHttp =
              [ HttpPermission ["GET"] "graph.microsoft.com" "/v1.0/me/todo" (Just "account")
              , HttpPermission ["GET"] "graph.microsoft.com" "/v1.0/me/todo/lists" (Just "account")
              ]
          }
      ambiguousSource = ExecutableComponent sourceCommon "main.lua" overlapping
  assertLeft "overlapping HTTP permissions" (encodePackManifest fixtureManifest{packComponents = [ambiguousSource]})

httpAuthorityConfinement :: Assertion
httpAuthorityConfinement = do
  let permission = HttpPermission ["GET"] "graph.microsoft.com" "/v1.0/me/todo" (Just "account")
      permissions = emptyPermissions{permissionCredentialSlots = [CredentialSlot "account" BearerToken], permissionHttp = [permission]}
      valid = BrokerHttpRequest "GET" "https://graph.microsoft.com/v1.0/me/todo/lists?%24top=100" (Map.singleton "accept" "application/json") Nothing
  authorizeBrokerHttpRequest permissions valid @?= Right permission
  assertLeft "explicit port" (authorizeBrokerHttpRequest permissions valid{brokerHttpUrl = "https://graph.microsoft.com:443/v1.0/me/todo/lists"})
  assertLeft "encoded path traversal" (authorizeBrokerHttpRequest permissions valid{brokerHttpUrl = "https://graph.microsoft.com/v1.0/me/todo/%2e%2e/users"})
  assertLeft "authorization header from Lua" (authorizeBrokerHttpRequest permissions valid{brokerHttpHeaders = Map.singleton "authorization" "Bearer forbidden"})
  assertLeft "nearby host" (authorizeBrokerHttpRequest permissions valid{brokerHttpUrl = "https://graph.microsoft.com.example/v1.0/me/todo/lists"})

componentOwnership :: Assertion
componentOwnership = do
  let secondCommon =
        fixtureCommon
          { componentId = "nested"
          , componentRoot = "exporters/tree/nested"
          }
      second = ExecutableComponent secondCommon "main.lua" emptyPermissions{permissionProjections = ["little-ant/structure@1"]}
  assertLeft "overlapping roots" (encodePackManifest fixtureManifest{packComponents = [fixtureComponent, second]})

  let orphan = PayloadFile "orphan.txt" 1 "text/plain" (sha256Hex "x")
  assertLeft "orphan payload" (encodePackManifest fixtureManifest{packFiles = packFiles fixtureManifest <> [orphan]})

  let missingReference = fixtureCommon{componentConfigurationSchema = "missing.json"}
  assertLeft "missing component file" (encodePackManifest fixtureManifest{packComponents = [ExecutableComponent missingReference "main.lua" emptyPermissions{permissionProjections = ["little-ant/structure@1"]}]})

payloadIntegrity :: Assertion
payloadIntegrity = do
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  let wrongLength = case packFiles fixtureManifest of
        first : rest -> first{payloadFileLength = payloadFileLength first + 1} : rest
        [] -> error "fixture has files"
      wrongDigest = case packFiles fixtureManifest of
        first : rest -> first{payloadFileSha256 = TextEncoding.decodeUtf8 (ByteString.replicate 64 48)} : rest
        [] -> error "fixture has files"
  lengthManifest <- assertRight (canonicalJsonBytes (toJSON fixtureManifest{packFiles = wrongLength}))
  digestManifest <- assertRight (canonicalJsonBytes (toJSON fixtureManifest{packFiles = wrongDigest}))
  lengthArchive <- assertRight (buildCanonicalPackArchive lengthManifest signatureBytes fixturePayload)
  digestArchive <- assertRight (buildCanonicalPackArchive digestManifest signatureBytes fixturePayload)
  assertLeft "declared length" (validatePackArchive lengthArchive)
  assertLeft "declared digest" (validatePackArchive digestArchive)

pathSafety :: Assertion
pathSafety = do
  manifestBytes <- assertRight (encodePackManifest fixtureManifest)
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  assertLeft "parent traversal" (buildCanonicalPackArchive manifestBytes signatureBytes (Map.singleton "../escape.lua" "x"))
  assertLeft "backslash" (buildCanonicalPackArchive manifestBytes signatureBytes (Map.singleton "bad\\path.lua" "x"))
  assertLeft
    "Unicode normalization collision"
    ( buildCanonicalPackArchive
        manifestBytes
        signatureBytes
        (Map.fromList [("caf\x00e9.lua", "x"), ("cafe\x0301.lua", "y")])
    )

jcsOrdering :: Assertion
jcsOrdering = do
  let supplementary = "\x10000"
      privateUse = "\xe000"
  bytes <- assertRight (canonicalJsonBytes (object [Key.fromText privateUse .= (2 :: Int), Key.fromText supplementary .= (1 :: Int)]))
  indexOf (TextEncoding.encodeUtf8 supplementary) bytes @?= 2
  assertBool "UTF-16 order placed the supplementary key first" (indexOf (TextEncoding.encodeUtf8 supplementary) bytes < indexOf (TextEncoding.encodeUtf8 privateUse) bytes)
  assertLeft "fractional control number" (canonicalJsonBytes (Number 1.5))

signatureAuthentication :: Assertion
signatureAuthentication = do
  (_, authenticated) <- signedFixture fixtureManifest
  authenticatedSignerFingerprint authenticated @?= sha256Hex fixturePublicKeyBytes
  authenticatedSignerPublicKey authenticated @?= TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded fixturePublicKeyBytes)

  manifestBytes <- assertRight (encodePackManifest fixtureManifest)
  let wrongFingerprint =
        (signedDocument manifestBytes)
          { packSignatureKeyFingerprint = Text.replicate 64 "0"
          }
  wrongFingerprintBytes <- assertRight (encodePackSignature wrongFingerprint)
  wrongFingerprintArchive <- assertRight (buildCanonicalPackArchive manifestBytes wrongFingerprintBytes fixturePayload)
  wrongFingerprintPack <- assertRight (validatePackArchive wrongFingerprintArchive)
  assertLeft "fingerprint mismatch" (authenticatePack wrongFingerprintPack)

  let signatureBytes = signatureBytesFor manifestBytes
      changedSignature = ByteString.init signatureBytes <> ByteString.singleton (ByteString.last signatureBytes `xor` 1)
      invalidSignature = (signedDocument manifestBytes){packSignatureValue = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded changedSignature)}
  invalidSignatureBytes <- assertRight (encodePackSignature invalidSignature)
  invalidSignatureArchive <- assertRight (buildCanonicalPackArchive manifestBytes invalidSignatureBytes fixturePayload)
  invalidSignaturePack <- assertRight (validatePackArchive invalidSignatureArchive)
  assertLeft "invalid Ed25519 signature" (authenticatePack invalidSignaturePack)

  let shortKey = (signedDocument manifestBytes){packSignaturePublicKey = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded (ByteString.take 31 fixturePublicKeyBytes))}
  shortKeyBytes <- assertRight (encodePackSignature shortKey)
  shortKeyArchive <- assertRight (buildCanonicalPackArchive manifestBytes shortKeyBytes fixturePayload)
  shortKeyPack <- assertRight (validatePackArchive shortKeyArchive)
  assertLeft "short public key" (authenticatePack shortKeyPack)

revocationDominates :: Assertion
revocationDominates = do
  (_, authenticated) <- signedFixture fixtureManifest
  scope <- assertRight (mkProfileScope "default")
  let identity = authenticatedPackIdentity authenticated
      builtInPolicy = emptyTrustPolicy{trustBuiltInArtifacts = Set.singleton identity}
  builtIn <- assertRight (assessPackTrust fixtureNow builtInPolicy authenticated)
  assessedTrustClass builtIn @?= BuiltInTrust
  _ <- assertRight (authorizePackInstall fixtureNow scope builtInPolicy (Set.singleton "tree") authenticated)

  let revokedByKey = builtInPolicy{trustRevokedKeyFingerprints = Set.singleton (authenticatedSignerFingerprint authenticated)}
      revokedByArchive = builtInPolicy{trustRevokedArchiveDigests = Set.singleton (artifactArchiveDigest identity)}
  assessedTrustClass <$> assessPackTrust fixtureNow revokedByKey authenticated @?= Right RevokedPack
  assessedTrustClass <$> assessPackTrust fixtureNow revokedByArchive authenticated @?= Right RevokedPack
  assertLeft "revoked built-in install" (authorizePackInstall fixtureNow scope revokedByKey (Set.singleton "tree") authenticated)

expiredOfficialCatalog :: Assertion
expiredOfficialCatalog = do
  (_, authenticated) <- signedFixture fixtureManifest
  scope <- assertRight (mkProfileScope "work")
  let currentPolicy =
        emptyTrustPolicy
          { trustOfficialCatalogSequence = Just 7
          , trustOfficialCatalogExpiresAt = Just (addUTCTime 3600 fixtureNow)
          , trustOfficialReleaseGrants = Set.singleton (officialGrant authenticated)
          }
      expiredPolicy = currentPolicy{trustOfficialCatalogExpiresAt = Just (addUTCTime (-1) fixtureNow)}
  currentAssessment <- assertRight (assessPackTrust fixtureNow currentPolicy authenticated)
  assessedTrustClass currentAssessment @?= VerifiedOfficialTrust
  assessedOfficialCatalogFreshness currentAssessment @?= OfficialCatalogCurrent
  install <- assertRight (authorizePackInstall fixtureNow scope currentPolicy (Set.singleton "tree") authenticated)

  expiredAssessment <- assertRight (assessPackTrust fixtureNow expiredPolicy authenticated)
  assessedTrustClass expiredAssessment @?= VerifiedOfficialTrust
  assessedOfficialCatalogFreshness expiredAssessment @?= OfficialCatalogExpired
  assertLeft "expired catalog install" (authorizePackInstall fixtureNow scope expiredPolicy (Set.singleton "tree") authenticated)
  _ <- assertRight (authorizePinnedPackExecution fixtureNow scope expiredPolicy (installAuthorizedPin install) authenticated)
  let revokedPolicy = expiredPolicy{trustRevokedArchiveDigests = Set.singleton (artifactArchiveDigest (authenticatedPackIdentity authenticated))}
  assertLeft "revoked accepted pin" (authorizePinnedPackExecution fixtureNow scope revokedPolicy (installAuthorizedPin install) authenticated)

communityUntrust :: Assertion
communityUntrust = do
  (_, authenticated) <- signedFixture fixtureManifest
  scope <- assertRight (mkProfileScope "personal")
  let trustedPolicy = emptyTrustPolicy{trustCommunityPublishers = Set.singleton (communityTrust authenticated)}
  assessment <- assertRight (assessPackTrust fixtureNow trustedPolicy authenticated)
  assessedTrustClass assessment @?= TrustedPublisherTrust
  install <- assertRight (authorizePackInstall fixtureNow scope trustedPolicy (Set.singleton "tree") authenticated)
  _ <- assertRight (authorizePinnedPackExecution fixtureNow scope trustedPolicy (installAuthorizedPin install) authenticated)
  assertLeft "untrusted publisher execution" (authorizePinnedPackExecution fixtureNow scope emptyTrustPolicy (installAuthorizedPin install) authenticated)

pinConfinement :: Assertion
pinConfinement = do
  (_, authenticated) <- signedFixture fixtureManifest
  (_, otherArtifact) <- signedFixture fixtureManifest{packVersion = "1.0.1"}
  scope <- assertRight (mkProfileScope "default")
  let policy = emptyTrustPolicy{trustCommunityPublishers = Set.singleton (communityTrust authenticated)}
  install <- assertRight (authorizePackInstall fixtureNow scope policy (Set.singleton "tree") authenticated)
  assertLeft "different artifact" (authorizePinnedPackExecution fixtureNow scope policy (installAuthorizedPin install) otherArtifact)
  assertLeft "missing component" (authorizePackInstall fixtureNow scope policy (Set.singleton "missing") authenticated)

trustPolicyEquivocation :: Assertion
trustPolicyEquivocation = do
  (_, authenticated) <- signedFixture fixtureManifest
  let grant = officialGrant authenticated
      otherDigest = grant{officialGrantArchiveDigest = Text.replicate 64 "0"}
      officialPolicy =
        emptyTrustPolicy
          { trustOfficialCatalogSequence = Just 8
          , trustOfficialCatalogExpiresAt = Just (addUTCTime 3600 fixtureNow)
          , trustOfficialReleaseGrants = Set.fromList [grant, otherDigest]
          }
      identity = authenticatedPackIdentity authenticated
      builtInPolicy =
        emptyTrustPolicy
          { trustBuiltInArtifacts =
              Set.fromList
                [ identity
                , identity{artifactArchiveDigest = Text.replicate 64 "0"}
                ]
          }
  assertLeft "official equivocation" (assessPackTrust fixtureNow officialPolicy authenticated)
  assertLeft "built-in equivocation" (assessPackTrust fixtureNow builtInPolicy authenticated)

packStoreLifecycle :: Assertion
packStoreLifecycle = withSystemTempDirectory "lant-pack-store" $ \root -> do
  (_, authenticated) <- signedFixture fixtureManifest
  scope <- assertRight (mkProfileScope "default")
  let policy = emptyTrustPolicy{trustCommunityPublishers = Set.singleton (communityTrust authenticated)}
      config = PackStoreConfig (root </> "packs" </> "sha256")
  install <- assertRight (authorizePackInstall fixtureNow scope policy (Set.singleton "tree") authenticated)
  first <- storeAuthorizedPack config install >>= assertRight
  second <- storeAuthorizedPack config install >>= assertRight
  first @?= second
  storedPackArchiveDigest first @?= artifactArchiveDigest (authenticatedPackIdentity authenticated)
  status <- getFileStatus (storedPackPath first)
  fileMode status .&. 0o077 @?= 0
  execution <- loadPinnedPack config fixtureNow scope policy (installAuthorizedPin install) >>= assertRight
  registry <- assertRight (buildPackRegistry scope [execution])
  component <- assertRight (lookupPackComponent "tree" registry)
  Map.keys (registeredComponentPayload component) @?= ["config.schema.json", "main.lua"]

packStoreTampering :: Assertion
packStoreTampering = withSystemTempDirectory "lant-pack-tamper" $ \root -> do
  (archive, authenticated) <- signedFixture fixtureManifest
  scope <- assertRight (mkProfileScope "default")
  let policy = emptyTrustPolicy{trustCommunityPublishers = Set.singleton (communityTrust authenticated)}
      config = PackStoreConfig (root </> "packs" </> "sha256")
  install <- assertRight (authorizePackInstall fixtureNow scope policy (Set.singleton "tree") authenticated)
  stored <- storeAuthorizedPack config install >>= assertRight
  ByteString.writeFile (storedPackPath stored) (archive <> "x")
  setFileMode (storedPackPath stored) 0o600
  tampered <- loadPinnedPack config fixtureNow scope policy (installAuthorizedPin install)
  assertLeft "tampered store" tampered

  removeFile (storedPackPath stored)
  let target = root </> "elsewhere.lantpack"
  ByteString.writeFile target archive
  setFileMode target 0o600
  createSymbolicLink target (storedPackPath stored)
  substituted <- loadPinnedPack config fixtureNow scope policy (installAuthorizedPin install)
  assertLeft "symlink substitution" substituted

  let collisionConfig = PackStoreConfig (root </> "collision" </> "sha256")
      collisionPath = packArchivePath collisionConfig (artifactArchiveDigest (authenticatedPackIdentity authenticated))
  createDirectoryIfMissing True (packStoreRoot collisionConfig)
  setFileMode (packStoreRoot collisionConfig) 0o700
  ByteString.writeFile collisionPath "not the authorized archive"
  setFileMode collisionPath 0o600
  collision <- storeAuthorizedPack collisionConfig install
  assertLeft "preexisting digest collision" collision
  ByteString.readFile collisionPath >>= (@?= "not the authorized archive")

packRegistryConfinement :: Assertion
packRegistryConfinement = do
  (_, firstPack) <- signedFixture fixtureManifest
  (_, secondPack) <- signedFixture fixtureManifest{packName = "org.example.other", packDisplayName = "Other Pack"}
  scope <- assertRight (mkProfileScope "default")
  let policy = emptyTrustPolicy{trustCommunityPublishers = Set.singleton (communityTrust firstPack)}
  firstInstall <- assertRight (authorizePackInstall fixtureNow scope policy (Set.singleton "tree") firstPack)
  secondInstall <- assertRight (authorizePackInstall fixtureNow scope policy (Set.singleton "tree") secondPack)
  firstExecution <- assertRight (authorizePinnedPackExecution fixtureNow scope policy (installAuthorizedPin firstInstall) firstPack)
  secondExecution <- assertRight (authorizePinnedPackExecution fixtureNow scope policy (installAuthorizedPin secondInstall) secondPack)
  assertLeft "component collision" (buildPackRegistry scope [firstExecution, secondExecution])
  otherScope <- assertRight (mkProfileScope "work")
  assertLeft "profile authority" (buildPackRegistry otherScope [firstExecution])

typedIntegrationsRoundTrip :: Assertion
typedIntegrationsRoundTrip = withSystemTempDirectory "lant-pack-profile" $ \root -> do
  (_, authenticated) <- signedFixture fixtureManifest
  scope <- assertRight (mkProfileScope "default")
  let policy = emptyTrustPolicy{trustCommunityPublishers = Set.singleton (communityTrust authenticated)}
  install <- assertRight (authorizePackInstall fixtureNow scope policy (Set.singleton "tree") authenticated)
  let roots = XdgRoots (root </> "config") (root </> "data") (root </> "state") (root </> "runtime")
  paths <- createProfile roots "default" fixtureProfileUuid >>= assertRight
  let integrations =
        IntegrationsConfig
          { installedComponents = Map.singleton (artifactName (authenticatedPackIdentity authenticated)) (installAuthorizedPin install)
          , providerAccounts = Map.empty
          , credentialBindings = Map.empty
          , deliveryBindings = Map.empty
          , trustedPublishers = Set.singleton (communityTrust authenticated)
          }
  writeIntegrationsConfig paths integrations >>= assertRight
  (_, _, _, _, loaded) <- loadProfile roots "default" >>= assertRight
  loaded @?= integrations
  packStoreDirectory paths @?= root </> "data" </> "lant" </> "packs" </> "sha256"
  officialCatalogStateFile paths @?= root </> "state" </> "lant" </> "profiles" </> "default" </> "official-pack-catalog.json"
  let invalid = integrations{installedComponents = Map.singleton "org.example.wrong" (installAuthorizedPin install)}
  writeIntegrationsConfig paths invalid >>= assertLeft "invalid pin key"
  (_, _, _, _, unchanged) <- loadProfile roots "default" >>= assertRight
  unchanged @?= integrations

officialCatalogAcceptance :: Assertion
officialCatalogAcceptance = do
  (_, authenticated) <- signedFixture fixtureManifest
  root <- assertRight fixtureCatalogRoot
  let catalog = fixtureCatalog authenticated 4 (addUTCTime 3600 fixtureNow) []
  (catalogBytes, signatureBytes) <- signedCatalog fixtureCatalogSecretKey root catalog
  accepted <- assertRight (acceptOfficialPackCatalog fixtureNow (emptyAcceptedCatalogState root) catalogBytes signatureBytes)
  officialCatalogSequence <$> acceptedCatalogCurrent accepted @?= Just 4
  acceptedCatalogHistoryLength accepted @?= 1
  let policy = catalogTrustPolicy fixtureNow 1 Set.empty Set.empty accepted
  assessed <- assertRight (assessPackTrust fixtureNow policy authenticated)
  assessedTrustClass assessed @?= VerifiedOfficialTrust
  scope <- assertRight (mkProfileScope "default")
  _ <- assertRight (authorizePackInstall fixtureNow scope policy (Set.singleton "tree") authenticated)

  assertLeft "same sequence" (acceptOfficialPackCatalog fixtureNow accepted catalogBytes signatureBytes)
  assertLeft "noncanonical catalog" (acceptOfficialPackCatalog fixtureNow (emptyAcceptedCatalogState root) (" " <> catalogBytes) signatureBytes)
  let badSignature = ByteString.init signatureBytes <> ByteString.singleton (ByteString.last signatureBytes `xor` 1)
  assertLeft "invalid detached signature" (acceptOfficialPackCatalog fixtureNow (emptyAcceptedCatalogState root) catalogBytes badSignature)
  let expired = fixtureCatalog authenticated 5 (addUTCTime (-1) fixtureNow) []
  (expiredBytes, expiredSignature) <- signedCatalog fixtureCatalogSecretKey root expired
  assertLeft "expired candidate" (acceptOfficialPackCatalog fixtureNow accepted expiredBytes expiredSignature)

officialCatalogRevocationMemory :: Assertion
officialCatalogRevocationMemory = do
  (_, authenticated) <- signedFixture fixtureManifest
  root <- assertRight fixtureCatalogRoot
  let identity = authenticatedPackIdentity authenticated
      revocation = CatalogRevocation RevokeArchive (artifactArchiveDigest identity) "release withdrawn" fixtureNow
      first = fixtureCatalog authenticated 1 (addUTCTime 3600 fixtureNow) [revocation]
      second = fixtureCatalog authenticated 2 (addUTCTime 7200 fixtureNow) []
  (firstBytes, firstSignature) <- signedCatalog fixtureCatalogSecretKey root first
  (secondBytes, secondSignature) <- signedCatalog fixtureCatalogSecretKey root second
  acceptedFirst <- assertRight (acceptOfficialPackCatalog fixtureNow (emptyAcceptedCatalogState root) firstBytes firstSignature)
  acceptedSecond <- assertRight (acceptOfficialPackCatalog fixtureNow acceptedFirst secondBytes secondSignature)
  let policy = catalogTrustPolicy fixtureNow 1 Set.empty Set.empty acceptedSecond
  trustRevokedArchiveDigests policy @?= Set.singleton (artifactArchiveDigest identity)
  assessedTrustClass <$> assessPackTrust fixtureNow policy authenticated @?= Right RevokedPack

  let futureRevocation = CatalogRevocation RevokePublisherKey (authenticatedSignerFingerprint authenticated) "scheduled key retirement" (addUTCTime 600 fixtureNow)
      third = fixtureCatalog authenticated 3 (addUTCTime 7200 fixtureNow) [futureRevocation]
  (thirdBytes, thirdSignature) <- signedCatalog fixtureCatalogSecretKey root third
  acceptedThird <- assertRight (acceptOfficialPackCatalog fixtureNow acceptedSecond thirdBytes thirdSignature)
  trustRevokedKeyFingerprints (catalogTrustPolicy fixtureNow 1 Set.empty Set.empty acceptedThird) @?= Set.empty
  trustRevokedKeyFingerprints (catalogTrustPolicy (addUTCTime 600 fixtureNow) 1 Set.empty Set.empty acceptedThird)
    @?= Set.singleton (authenticatedSignerFingerprint authenticated)

officialCatalogRootRotation :: Assertion
officialCatalogRootRotation = do
  (_, authenticated) <- signedFixture fixtureManifest
  oldRoot <- assertRight fixtureCatalogRoot
  newRoot <- assertRight fixtureNextCatalogRoot
  (transitionBytes, proofBytes) <- signedRootTransition oldRoot fixtureCatalogSecretKey newRoot fixtureNextCatalogSecretKey
  rotated <- assertRight (acceptCatalogRootTransition (emptyAcceptedCatalogState oldRoot) transitionBytes proofBytes)
  acceptedCatalogActiveRoot rotated @?= newRoot

  let catalog = fixtureCatalog authenticated 1 (addUTCTime 3600 fixtureNow) []
  (oldCatalogBytes, oldCatalogSignature) <- signedCatalog fixtureCatalogSecretKey oldRoot catalog
  assertLeft "retired root catalog" (acceptOfficialPackCatalog fixtureNow rotated oldCatalogBytes oldCatalogSignature)
  (newCatalogBytes, newCatalogSignature) <- signedCatalog fixtureNextCatalogSecretKey newRoot catalog
  accepted <- assertRight (acceptOfficialPackCatalog fixtureNow rotated newCatalogBytes newCatalogSignature)
  officialCatalogSequence <$> acceptedCatalogCurrent accepted @?= Just 1

  let invalidProof = ByteString.init proofBytes <> ByteString.singleton (ByteString.last proofBytes `xor` 1)
  assertLeft "invalid root proof" (acceptCatalogRootTransition (emptyAcceptedCatalogState oldRoot) transitionBytes invalidProof)

officialCatalogPersistence :: Assertion
officialCatalogPersistence = withSystemTempDirectory "lant-pack-catalog" $ \directory -> do
  (_, authenticated) <- signedFixture fixtureManifest
  oldRoot <- assertRight fixtureCatalogRoot
  newRoot <- assertRight fixtureNextCatalogRoot
  let config = CatalogStateConfig (directory </> "profile" </> "official-pack-catalog.json")
      first = fixtureCatalog authenticated 7 (addUTCTime 3600 fixtureNow) []
      second = fixtureCatalog authenticated 8 (addUTCTime 7200 fixtureNow) []
  (firstBytes, firstSignature) <- signedCatalog fixtureCatalogSecretKey oldRoot first
  refreshed <- refreshOfficialPackCatalog config oldRoot fixtureNow firstBytes firstSignature >>= assertRight
  acceptedCatalogHistoryLength refreshed @?= 1
  status <- getFileStatus (catalogStatePath config)
  fileMode status .&. 0o077 @?= 0

  (transitionBytes, proofBytes) <- signedRootTransition oldRoot fixtureCatalogSecretKey newRoot fixtureNextCatalogSecretKey
  _ <- rotateOfficialCatalogRoot config oldRoot transitionBytes proofBytes >>= assertRight
  (secondBytes, secondSignature) <- signedCatalog fixtureNextCatalogSecretKey newRoot second
  final <- refreshOfficialPackCatalog config oldRoot fixtureNow secondBytes secondSignature >>= assertRight
  acceptedCatalogHistoryLength final @?= 3

  loadedFromOld <- readAcceptedCatalogState config oldRoot >>= assertRight
  loadedFromNew <- readAcceptedCatalogState config newRoot >>= assertRight
  acceptedCatalogCurrent loadedFromOld @?= acceptedCatalogCurrent final
  acceptedCatalogCurrent loadedFromNew @?= acceptedCatalogCurrent final
  acceptedCatalogActiveRoot loadedFromNew @?= newRoot

  original <- ByteString.readFile (catalogStatePath config)
  ByteString.writeFile (catalogStatePath config) (original <> "\n")
  setFileMode (catalogStatePath config) 0o600
  readAcceptedCatalogState config newRoot >>= assertLeft "noncanonical persisted state"

fixtureCatalog :: AuthenticatedPack -> Integer -> UTCTime -> [CatalogRevocation] -> OfficialPackCatalog
fixtureCatalog authenticated sequenceNumber expiry revocations =
  let identity = authenticatedPackIdentity authenticated
      delegation =
        CatalogPublisherDelegation
          { catalogPublisherId = artifactPublisher identity
          , catalogPublisherPublicKey = authenticatedSignerPublicKey authenticated
          , catalogPublisherKeyFingerprint = authenticatedSignerFingerprint authenticated
          , catalogPublisherNamePrefixes = ["org.littleant."]
          }
      release =
        CatalogRelease
          { catalogReleasePublisher = artifactPublisher identity
          , catalogReleaseName = artifactName identity
          , catalogReleaseVersion = artifactVersion identity
          , catalogReleaseManifestDigest = artifactManifestDigest identity
          , catalogReleaseArchiveDigest = artifactArchiveDigest identity
          }
   in OfficialPackCatalog sequenceNumber expiry [delegation] [release] revocations

signedCatalog :: Ed25519.SecretKey -> CatalogRoot -> OfficialPackCatalog -> IO (ByteString, ByteString)
signedCatalog secret root catalog = do
  catalogBytes <- assertRight (encodeOfficialPackCatalog catalog)
  signatureBytes <-
    assertRight . encodeCatalogSignature $
      CatalogSignatureDocument
        (catalogRootFingerprint root)
        (encodedSignature secret catalogBytes)
  pure (catalogBytes, signatureBytes)

signedRootTransition :: CatalogRoot -> Ed25519.SecretKey -> CatalogRoot -> Ed25519.SecretKey -> IO (ByteString, ByteString)
signedRootTransition previous previousSecret next nextSecret = do
  let transition =
        CatalogRootTransition
          { rootTransitionGeneration = catalogRootGeneration next
          , rootTransitionPreviousPublicKey = catalogRootPublicKey previous
          , rootTransitionPreviousFingerprint = catalogRootFingerprint previous
          , rootTransitionNextPublicKey = catalogRootPublicKey next
          , rootTransitionNextFingerprint = catalogRootFingerprint next
          }
  transitionBytes <- assertRight (encodeCatalogRootTransition transition)
  proofBytes <-
    assertRight . encodeCatalogRootProof $
      CatalogRootProof
        (encodedSignature previousSecret transitionBytes)
        (encodedSignature nextSecret transitionBytes)
  pure (transitionBytes, proofBytes)

encodedSignature :: Ed25519.SecretKey -> ByteString -> Text
encodedSignature secret bytes =
  let public = Ed25519.toPublic secret
   in TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded (convert (Ed25519.sign secret public bytes)))

fixtureCatalogRoot :: Either AppError CatalogRoot
fixtureCatalogRoot = catalogRootFromPublicKey 0 (encodedPublicKey fixtureCatalogSecretKey)

fixtureNextCatalogRoot :: Either AppError CatalogRoot
fixtureNextCatalogRoot = catalogRootFromPublicKey 1 (encodedPublicKey fixtureNextCatalogSecretKey)

encodedPublicKey :: Ed25519.SecretKey -> Text
encodedPublicKey = TextEncoding.decodeUtf8 . Base64Url.encodeUnpadded . convert . Ed25519.toPublic

fixtureCatalogSecretKey :: Ed25519.SecretKey
fixtureCatalogSecretKey = cryptoPassed (Ed25519.secretKey (ByteString.pack [32 .. 63]))

fixtureNextCatalogSecretKey :: Ed25519.SecretKey
fixtureNextCatalogSecretKey = cryptoPassed (Ed25519.secretKey (ByteString.pack [64 .. 95]))

signedFixture :: PackManifest -> IO (ByteString, AuthenticatedPack)
signedFixture manifest = do
  manifestBytes <- assertRight (encodePackManifest manifest)
  signatureDocumentBytes <- assertRight (encodePackSignature (signedDocument manifestBytes))
  archive <- assertRight (buildCanonicalPackArchive manifestBytes signatureDocumentBytes fixturePayload)
  structural <- assertRight (validatePackArchive archive)
  authenticated <- assertRight (authenticatePack structural)
  pure (archive, authenticated)

signedDocument :: ByteString -> PackSignatureDocument
signedDocument manifestBytes =
  PackSignatureDocument
    { packSignaturePublicKey = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded fixturePublicKeyBytes)
    , packSignatureKeyFingerprint = sha256Hex fixturePublicKeyBytes
    , packSignatureValue = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded (signatureBytesFor manifestBytes))
    }

signatureBytesFor :: ByteString -> ByteString
signatureBytesFor manifestBytes = convert (Ed25519.sign fixtureSecretKey fixturePublicKey manifestBytes)

fixtureSecretKey :: Ed25519.SecretKey
fixtureSecretKey = cryptoPassed (Ed25519.secretKey (ByteString.pack [0 .. 31]))

fixturePublicKey :: Ed25519.PublicKey
fixturePublicKey = Ed25519.toPublic fixtureSecretKey

fixturePublicKeyBytes :: ByteString
fixturePublicKeyBytes = convert fixturePublicKey

emptyTrustPolicy :: PackTrustPolicy
emptyTrustPolicy =
  PackTrustPolicy
    { trustSupportedLittleAntMajor = 1
    , trustBuiltInArtifacts = Set.empty
    , trustOfficialCatalogSequence = Nothing
    , trustOfficialCatalogExpiresAt = Nothing
    , trustOfficialReleaseGrants = Set.empty
    , trustCommunityPublishers = Set.empty
    , trustRevokedKeyFingerprints = Set.empty
    , trustRevokedArchiveDigests = Set.empty
    }

communityTrust :: AuthenticatedPack -> TrustedCommunityPublisher
communityTrust authenticated =
  TrustedCommunityPublisher
    { communityPublisher = artifactPublisher (authenticatedPackIdentity authenticated)
    , communityPublicKey = authenticatedSignerPublicKey authenticated
    , communityKeyFingerprint = authenticatedSignerFingerprint authenticated
    }

officialGrant :: AuthenticatedPack -> OfficialReleaseGrant
officialGrant authenticated =
  let identity = authenticatedPackIdentity authenticated
   in OfficialReleaseGrant
        { officialGrantPublisher = artifactPublisher identity
        , officialGrantNamePrefix = "org.littleant."
        , officialGrantPublicKey = authenticatedSignerPublicKey authenticated
        , officialGrantKeyFingerprint = authenticatedSignerFingerprint authenticated
        , officialGrantName = artifactName identity
        , officialGrantVersion = artifactVersion identity
        , officialGrantManifestDigest = artifactManifestDigest identity
        , officialGrantArchiveDigest = artifactArchiveDigest identity
        }

fixtureNow :: UTCTime
fixtureNow = UTCTime (fromGregorian 2026 8 8) (secondsToDiffTime (12 * 60 * 60))

fixtureProfileUuid :: UUIDv7
fixtureProfileUuid = either (error . Text.unpack) id (parseUUIDv7 "019fe436-5e25-7ee2-9eaf-eff23cfb54fc")

cryptoPassed :: CryptoFailable value -> value
cryptoPassed = \case
  CryptoPassed value -> value
  CryptoFailed problem -> error (show problem)

fixtureArchive :: PackManifest -> Map Text ByteString -> IO ByteString
fixtureArchive manifest payload = do
  manifestBytes <- assertRight (encodePackManifest manifest)
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  assertRight (buildCanonicalPackArchive manifestBytes signatureBytes payload)

fixtureManifest :: PackManifest
fixtureManifest =
  PackManifest
    { packName = "org.littleant.standard"
    , packVersion = "1.0.0"
    , packDisplayName = "Little Ant Standard Pack"
    , packPublisher = "org.littleant.project"
    , packLittleAntMajor = 1
    , packComponents = [fixtureComponent]
    , packFiles = fmap payloadRecord (Map.toAscList fixturePayload)
    , packLinks = Just (PackLinks (Just "https://example.com/little-ant") Nothing Nothing)
    }

fixtureComponent :: PackComponent
fixtureComponent = ExecutableComponent fixtureCommon "main.lua" emptyPermissions{permissionProjections = ["little-ant/structure@1"]}

fixtureCommon :: ComponentCommon
fixtureCommon =
  ComponentCommon
    { componentId = "tree"
    , componentKind = ReadOnlyExporterComponent
    , componentContractMajor = 1
    , componentRoot = "exporters/tree"
    , componentConfigurationSchema = "config.schema.json"
    }

emptyPermissions :: ComponentPermissions
emptyPermissions = ComponentPermissions [] [] [] [] [] []

fixturePayload :: Map Text ByteString
fixturePayload =
  Map.fromList
    [ ("exporters/tree/config.schema.json", "{\"additionalProperties\":false,\"type\":\"object\"}")
    , ("exporters/tree/main.lua", "return {}\n")
    ]

payloadRecord :: (Text, ByteString) -> PayloadFile
payloadRecord (path, bytes) = PayloadFile path (fromIntegral (ByteString.length bytes)) (mediaType path) (sha256Hex bytes)
 where
  mediaType value
    | ".lua" `Text.isSuffixOf` value = "text/x-lua; charset=utf-8"
    | otherwise = "application/schema+json"

fixtureSignature :: PackSignatureDocument
fixtureSignature =
  PackSignatureDocument
    { packSignaturePublicKey = TextEncoding.decodeUtf8 (ByteString.replicate 43 65)
    , packSignatureKeyFingerprint = TextEncoding.decodeUtf8 (ByteString.replicate 64 48)
    , packSignatureValue = TextEncoding.decodeUtf8 (ByteString.replicate 86 65)
    }

replaceByte :: Int -> Word8 -> ByteString -> ByteString
replaceByte offset byte bytes = ByteString.take offset bytes <> ByteString.singleton byte <> ByteString.drop (offset + 1) bytes

replaceNeedleByte :: ByteString -> ByteString -> ByteString
replaceNeedleByte needle bytes =
  let (before, suffix) = ByteString.breakSubstring needle bytes
   in if ByteString.null suffix
        then error "fixture needle not found"
        else before <> ByteString.singleton (ByteString.head suffix + 1) <> ByteString.tail suffix

indexOf :: ByteString -> ByteString -> Int
indexOf needle haystack = ByteString.length (fst (ByteString.breakSubstring needle haystack))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertObject :: Value -> IO Object
assertObject = \case
  Object fields -> pure fields
  other -> assertFailure ("expected object, got " <> show other)

assertLeft :: (Show right) => String -> Either left right -> Assertion
assertLeft label = \case
  Left _ -> pure ()
  Right value -> assertFailure (label <> " unexpectedly succeeded: " <> show value)

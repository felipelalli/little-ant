module LittleAnt.Pack.Trust (
  PackArtifactIdentity (..),
  AuthenticatedPack,
  authenticatedStructuralPack,
  authenticatedPackIdentity,
  authenticatedSignerFingerprint,
  authenticatedSignerPublicKey,
  authenticatePack,
  PackTrustClass (..),
  packTrustClassText,
  OfficialCatalogFreshness (..),
  OfficialReleaseGrant (..),
  TrustedCommunityPublisher (..),
  PackTrustPolicy (..),
  PackTrustAssessment (..),
  assessPackTrust,
  ProfileScope,
  profileScopeName,
  mkProfileScope,
  PinTrustOrigin (..),
  PackPin (..),
  InstallAuthorizedPack,
  installAuthorizedPack,
  installAuthorizedScope,
  installAuthorizedAssessment,
  installAuthorizedPin,
  authorizePackInstall,
  ExecutionAuthorizedPack,
  executionAuthorizedPack,
  executionAuthorizedScope,
  executionAuthorizedPin,
  authorizePinnedPackExecution,
)
where

import Control.Monad (unless, when)
import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Char (isAsciiLower, isDigit)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Pack.Format
import LittleAnt.Store (sha256Hex)

data PackArtifactIdentity = PackArtifactIdentity
  { artifactPublisher :: Text
  , artifactName :: Text
  , artifactVersion :: Text
  , artifactManifestDigest :: Text
  , artifactArchiveDigest :: Text
  }
  deriving stock (Eq, Ord, Show)

data AuthenticatedPack = AuthenticatedPack
  { authenticatedStructuralPack :: StructurallyValidPack
  , authenticatedPackIdentity :: PackArtifactIdentity
  , authenticatedSignerFingerprint :: Text
  , authenticatedSignerPublicKey :: Text
  }
  deriving stock (Eq, Show)

data PackTrustClass
  = BuiltInTrust
  | VerifiedOfficialTrust
  | TrustedPublisherTrust
  | UntrustedPack
  | RevokedPack
  deriving stock (Eq, Ord, Show)

packTrustClassText :: PackTrustClass -> Text
packTrustClassText = \case
  BuiltInTrust -> "built in"
  VerifiedOfficialTrust -> "verified official"
  TrustedPublisherTrust -> "trusted publisher"
  UntrustedPack -> "untrusted"
  RevokedPack -> "revoked"

data OfficialCatalogFreshness
  = NoOfficialCatalog
  | OfficialCatalogCurrent
  | OfficialCatalogExpired
  deriving stock (Eq, Ord, Show)

data OfficialReleaseGrant = OfficialReleaseGrant
  { officialGrantPublisher :: Text
  , officialGrantNamePrefix :: Text
  , officialGrantPublicKey :: Text
  , officialGrantKeyFingerprint :: Text
  , officialGrantName :: Text
  , officialGrantVersion :: Text
  , officialGrantManifestDigest :: Text
  , officialGrantArchiveDigest :: Text
  }
  deriving stock (Eq, Ord, Show)

data TrustedCommunityPublisher = TrustedCommunityPublisher
  { communityPublisher :: Text
  , communityPublicKey :: Text
  , communityKeyFingerprint :: Text
  }
  deriving stock (Eq, Ord, Show)

data PackTrustPolicy = PackTrustPolicy
  { trustSupportedLittleAntMajor :: Int
  , trustBuiltInArtifacts :: Set PackArtifactIdentity
  , trustOfficialCatalogSequence :: Maybe Integer
  , trustOfficialCatalogExpiresAt :: Maybe UTCTime
  , trustOfficialReleaseGrants :: Set OfficialReleaseGrant
  , trustCommunityPublishers :: Set TrustedCommunityPublisher
  , trustRevokedKeyFingerprints :: Set Text
  , trustRevokedArchiveDigests :: Set Text
  }
  deriving stock (Eq, Show)

data PackTrustAssessment = PackTrustAssessment
  { assessedTrustClass :: PackTrustClass
  , assessedArtifact :: PackArtifactIdentity
  , assessedSignerFingerprint :: Text
  , assessedOfficialCatalogFreshness :: OfficialCatalogFreshness
  , assessedOfficialCatalogSequence :: Maybe Integer
  }
  deriving stock (Eq, Show)

newtype ProfileScope = ProfileScope
  { profileScopeName :: Text
  }
  deriving stock (Eq, Ord, Show)

data PinTrustOrigin
  = PinBuiltIn
  | PinVerifiedOfficial Integer
  | PinTrustedPublisher
  deriving stock (Eq, Ord, Show)

data PackPin = PackPin
  { pinArtifact :: PackArtifactIdentity
  , pinSignerFingerprint :: Text
  , pinTrustOrigin :: PinTrustOrigin
  , pinEnabledComponents :: Set Text
  }
  deriving stock (Eq, Show)

data InstallAuthorizedPack = InstallAuthorizedPack
  { installAuthorizedPack :: AuthenticatedPack
  , installAuthorizedScope :: ProfileScope
  , installAuthorizedAssessment :: PackTrustAssessment
  , installAuthorizedPin :: PackPin
  }
  deriving stock (Eq, Show)

data ExecutionAuthorizedPack = ExecutionAuthorizedPack
  { executionAuthorizedPack :: AuthenticatedPack
  , executionAuthorizedScope :: ProfileScope
  , executionAuthorizedPin :: PackPin
  }
  deriving stock (Eq, Show)

authenticatePack :: StructurallyValidPack -> Either AppError AuthenticatedPack
authenticatePack structural = do
  let document = structurallyValidSignature structural
  publicKeyBytes <- decodeBase64UrlExact "publisher public key" 32 (packSignaturePublicKey document)
  signatureBytes <- decodeBase64UrlExact "Pack signature" 64 (packSignatureValue document)
  let observedFingerprint = sha256Hex publicKeyBytes
  unless
    (observedFingerprint == packSignatureKeyFingerprint document)
    (Left (trustDataProblem "The publisher key fingerprint does not match the decoded public key." []))
  publicKey <- cryptoValue "The publisher public key is not a valid Ed25519 key." (Ed25519.publicKey publicKeyBytes)
  signature <- cryptoValue "The Pack signature is not a valid Ed25519 signature." (Ed25519.signature signatureBytes)
  unless
    (Ed25519.verify publicKey (structurallyValidManifestBytes structural) signature)
    (Left (trustDataProblem "The Pack signature does not authenticate the exact pack.json bytes." []))
  let manifest = structurallyValidManifest structural
      identity =
        PackArtifactIdentity
          { artifactPublisher = packPublisher manifest
          , artifactName = packName manifest
          , artifactVersion = packVersion manifest
          , artifactManifestDigest = structurallyValidManifestDigest structural
          , artifactArchiveDigest = structurallyValidArchiveDigest structural
          }
  pure
    AuthenticatedPack
      { authenticatedStructuralPack = structural
      , authenticatedPackIdentity = identity
      , authenticatedSignerFingerprint = observedFingerprint
      , authenticatedSignerPublicKey = packSignaturePublicKey document
      }

assessPackTrust :: UTCTime -> PackTrustPolicy -> AuthenticatedPack -> Either AppError PackTrustAssessment
assessPackTrust now policy authenticated = do
  validateTrustPolicy policy
  let identity = authenticatedPackIdentity authenticated
      fingerprint = authenticatedSignerFingerprint authenticated
      freshness = officialCatalogFreshness now policy
      trustClass
        | fingerprint `Set.member` trustRevokedKeyFingerprints policy = RevokedPack
        | artifactArchiveDigest identity `Set.member` trustRevokedArchiveDigests policy = RevokedPack
        | identity `Set.member` trustBuiltInArtifacts policy = BuiltInTrust
        | any (matchesOfficialGrant authenticated) (trustOfficialReleaseGrants policy) = VerifiedOfficialTrust
        | any (matchesCommunityPublisher authenticated) (trustCommunityPublishers policy) = TrustedPublisherTrust
        | otherwise = UntrustedPack
  pure
    PackTrustAssessment
      { assessedTrustClass = trustClass
      , assessedArtifact = identity
      , assessedSignerFingerprint = fingerprint
      , assessedOfficialCatalogFreshness = freshness
      , assessedOfficialCatalogSequence = trustOfficialCatalogSequence policy
      }

mkProfileScope :: Text -> Either AppError ProfileScope
mkProfileScope name
  | validProfileName name = Right (ProfileScope name)
  | otherwise = Left (appError InvalidInput "A profile scope must match [a-z0-9][a-z0-9-]{0,31}.")

authorizePackInstall :: UTCTime -> ProfileScope -> PackTrustPolicy -> Set Text -> AuthenticatedPack -> Either AppError InstallAuthorizedPack
authorizePackInstall now scope policy enabledComponents authenticated = do
  validateCompatibility policy authenticated
  validateEnabledComponents enabledComponents authenticated
  assessment <- assessPackTrust now policy authenticated
  origin <- case assessedTrustClass assessment of
    BuiltInTrust -> Right PinBuiltIn
    VerifiedOfficialTrust -> do
      when
        (assessedOfficialCatalogFreshness assessment /= OfficialCatalogCurrent)
        (Left (catalogExpiredProblem assessment))
      sequenceNumber <-
        maybe
          (Left (trustDataProblem "Verified official trust is missing its accepted catalog sequence." []))
          Right
          (assessedOfficialCatalogSequence assessment)
      Right (PinVerifiedOfficial sequenceNumber)
    TrustedPublisherTrust -> Right PinTrustedPublisher
    UntrustedPack -> Left (trustPermissionProblem "The Pack publisher is not trusted in this profile." [authenticatedSignerFingerprint authenticated])
    RevokedPack -> Left (trustPermissionProblem "The Pack signer or archive is revoked and cannot be installed." [artifactArchiveDigest (authenticatedPackIdentity authenticated)])
  let pin =
        PackPin
          { pinArtifact = authenticatedPackIdentity authenticated
          , pinSignerFingerprint = authenticatedSignerFingerprint authenticated
          , pinTrustOrigin = origin
          , pinEnabledComponents = enabledComponents
          }
  pure
    InstallAuthorizedPack
      { installAuthorizedPack = authenticated
      , installAuthorizedScope = scope
      , installAuthorizedAssessment = assessment
      , installAuthorizedPin = pin
      }

authorizePinnedPackExecution :: UTCTime -> ProfileScope -> PackTrustPolicy -> PackPin -> AuthenticatedPack -> Either AppError ExecutionAuthorizedPack
authorizePinnedPackExecution now scope policy pin authenticated = do
  validateCompatibility policy authenticated
  validatePinIdentity pin authenticated
  validateEnabledComponents (pinEnabledComponents pin) authenticated
  assessment <- assessPackTrust now policy authenticated
  when
    (assessedTrustClass assessment == RevokedPack)
    (Left (trustPermissionProblem "The pinned Pack signer or archive is revoked and cannot execute." [artifactArchiveDigest (pinArtifact pin)]))
  case pinTrustOrigin pin of
    PinBuiltIn ->
      unless
        (assessedTrustClass assessment == BuiltInTrust)
        (Left (trustPermissionProblem "This pin no longer matches a built-in Pack artifact." []))
    PinVerifiedOfficial sequenceNumber -> do
      when (sequenceNumber < 0) (Left (trustDataProblem "The pinned official catalog sequence is invalid." []))
      unless
        (pinSignerFingerprint pin == authenticatedSignerFingerprint authenticated)
        (Left (trustDataProblem "The pinned official signer does not match the archive signer." []))
    PinTrustedPublisher ->
      unless
        (assessedTrustClass assessment == TrustedPublisherTrust)
        (Left (trustPermissionProblem "The pinned community publisher is no longer trusted in this profile." []))
  pure
    ExecutionAuthorizedPack
      { executionAuthorizedPack = authenticated
      , executionAuthorizedScope = scope
      , executionAuthorizedPin = pin
      }

validateCompatibility :: PackTrustPolicy -> AuthenticatedPack -> Either AppError ()
validateCompatibility policy authenticated = do
  let declaredMajor = packLittleAntMajor (structurallyValidManifest (authenticatedStructuralPack authenticated))
  unless
    (declaredMajor == trustSupportedLittleAntMajor policy)
    (Left (appError Unsupported "The Pack targets a different Little Ant contract major."))

validatePinIdentity :: PackPin -> AuthenticatedPack -> Either AppError ()
validatePinIdentity pin authenticated = do
  unless
    (pinArtifact pin == authenticatedPackIdentity authenticated)
    (Left (trustDataProblem "The pinned Pack identity does not match the stored archive." []))
  unless
    (pinSignerFingerprint pin == authenticatedSignerFingerprint authenticated)
    (Left (trustDataProblem "The pinned signer fingerprint does not match the stored archive." []))

validateEnabledComponents :: Set Text -> AuthenticatedPack -> Either AppError ()
validateEnabledComponents enabled authenticated = do
  when (Set.null enabled) (Left (appError PreconditionFailed "At least one Pack component must be enabled."))
  let available =
        Set.fromList
          [ componentId common
          | component <- packComponents (structurallyValidManifest (authenticatedStructuralPack authenticated))
          , let common = componentCommon component
          ]
      missing = Set.toAscList (enabled `Set.difference` available)
  unless
    (null missing)
    (Left (trustDataProblem "The pin enables components that the Pack does not contain." missing))

validateTrustPolicy :: PackTrustPolicy -> Either AppError ()
validateTrustPolicy policy = do
  unless (trustSupportedLittleAntMajor policy > 0) (Left (invalid "The supported Little Ant major must be positive." []))
  case (trustOfficialCatalogSequence policy, trustOfficialCatalogExpiresAt policy) of
    (Nothing, Nothing) -> unless (Set.null (trustOfficialReleaseGrants policy)) (Left (invalid "Official release grants require accepted catalog metadata." []))
    (Just sequenceNumber, Just _) -> when (sequenceNumber < 0) (Left (invalid "The official catalog sequence cannot be negative." []))
    _ -> Left (invalid "Official catalog sequence and expiry must be present together." [])
  mapM_ validateArtifactIdentity builtInArtifacts
  mapM_ validateCommunityPublisher (trustCommunityPublishers policy)
  mapM_ validateOfficialGrant officialGrants
  unless
    (uniqueOn artifactReleaseKey builtInArtifacts)
    (Left (invalid "Built-in trust contains an equivocated Pack release." []))
  unless
    (uniqueOn officialReleaseKey officialGrants)
    (Left (invalid "The official catalog contains an equivocated Pack release." []))
  mapM_ (validateDigest "A revoked key fingerprint") (trustRevokedKeyFingerprints policy)
  mapM_ (validateDigest "A revoked archive digest") (trustRevokedArchiveDigests policy)
 where
  builtInArtifacts = Set.toList (trustBuiltInArtifacts policy)
  officialGrants = Set.toList (trustOfficialReleaseGrants policy)
  invalid = trustDataProblem

validateArtifactIdentity :: PackArtifactIdentity -> Either AppError ()
validateArtifactIdentity identity = do
  unless (validReverseDns (artifactPublisher identity)) (Left (trustDataProblem "A trusted Pack publisher ID is invalid." []))
  unless (validReverseDns (artifactName identity)) (Left (trustDataProblem "A trusted Pack name is invalid." []))
  when (Text.null (artifactVersion identity)) (Left (trustDataProblem "A trusted Pack version is empty." []))
  validateDigest "A trusted Pack manifest digest" (artifactManifestDigest identity)
  validateDigest "A trusted Pack archive digest" (artifactArchiveDigest identity)

validateCommunityPublisher :: TrustedCommunityPublisher -> Either AppError ()
validateCommunityPublisher publisher = do
  validatePublisherBinding
    (communityPublisher publisher)
    (communityPublicKey publisher)
    (communityKeyFingerprint publisher)
  unless (validReverseDns (communityPublisher publisher)) (Left (trustDataProblem "A trusted community publisher ID is invalid." []))

validateOfficialGrant :: OfficialReleaseGrant -> Either AppError ()
validateOfficialGrant grant = do
  validatePublisherBinding
    (officialGrantPublisher grant)
    (officialGrantPublicKey grant)
    (officialGrantKeyFingerprint grant)
  unless (validReverseDns (officialGrantPublisher grant)) (Left (invalid "An official publisher ID is invalid." []))
  unless (validReverseDnsPrefix (officialGrantNamePrefix grant)) (Left (invalid "An official Pack name prefix is invalid." []))
  unless (officialGrantNamePrefix grant `Text.isPrefixOf` officialGrantName grant) (Left (invalid "An official release is outside its delegated Pack name prefix." []))
  validateDigest "An official manifest digest" (officialGrantManifestDigest grant)
  validateDigest "An official archive digest" (officialGrantArchiveDigest grant)
 where
  invalid = trustDataProblem

validatePublisherBinding :: Text -> Text -> Text -> Either AppError ()
validatePublisherBinding publisher publicKeyText fingerprint = do
  keyBytes <- decodeBase64UrlExact "trusted publisher public key" 32 publicKeyText
  validateDigest "A trusted publisher key fingerprint" fingerprint
  unless
    (sha256Hex keyBytes == fingerprint)
    (Left (trustDataProblem "A trusted publisher fingerprint does not match its public key." [publisher]))

matchesOfficialGrant :: AuthenticatedPack -> OfficialReleaseGrant -> Bool
matchesOfficialGrant authenticated grant =
  let identity = authenticatedPackIdentity authenticated
   in officialGrantPublisher grant == artifactPublisher identity
        && officialGrantNamePrefix grant `Text.isPrefixOf` artifactName identity
        && officialGrantPublicKey grant == authenticatedSignerPublicKey authenticated
        && officialGrantKeyFingerprint grant == authenticatedSignerFingerprint authenticated
        && officialGrantName grant == artifactName identity
        && officialGrantVersion grant == artifactVersion identity
        && officialGrantManifestDigest grant == artifactManifestDigest identity
        && officialGrantArchiveDigest grant == artifactArchiveDigest identity

matchesCommunityPublisher :: AuthenticatedPack -> TrustedCommunityPublisher -> Bool
matchesCommunityPublisher authenticated publisher =
  communityPublisher publisher == artifactPublisher (authenticatedPackIdentity authenticated)
    && communityPublicKey publisher == authenticatedSignerPublicKey authenticated
    && communityKeyFingerprint publisher == authenticatedSignerFingerprint authenticated

officialCatalogFreshness :: UTCTime -> PackTrustPolicy -> OfficialCatalogFreshness
officialCatalogFreshness now policy = case trustOfficialCatalogExpiresAt policy of
  Nothing -> NoOfficialCatalog
  Just expiry
    | now < expiry -> OfficialCatalogCurrent
    | otherwise -> OfficialCatalogExpired

decodeBase64UrlExact :: Text -> Int -> Text -> Either AppError ByteString
decodeBase64UrlExact label expectedLength encoded = do
  let encodedBytes = Text.encodeUtf8 encoded
  decoded <-
    either
      (\problem -> Left (trustDataProblem ("The " <> label <> " is not canonical unpadded base64url.") [Text.pack problem]))
      Right
      (Base64Url.decodeUnpadded encodedBytes)
  unless
    (Base64Url.encodeUnpadded decoded == encodedBytes)
    (Left (trustDataProblem ("The " <> label <> " is not canonical unpadded base64url.") []))
  unless
    (ByteString.length decoded == expectedLength)
    (Left (trustDataProblem ("The " <> label <> " has the wrong decoded length.") ["expected " <> Text.pack (show expectedLength) <> " bytes"]))
  pure decoded

cryptoValue :: Text -> CryptoFailable value -> Either AppError value
cryptoValue message = \case
  CryptoPassed value -> Right value
  CryptoFailed problem -> Left (trustDataProblem message [Text.pack (show problem)])

validateDigest :: Text -> Text -> Either AppError ()
validateDigest label digest =
  unless
    (Text.length digest == 64 && Text.all (\character -> isDigit character || character >= 'a' && character <= 'f') digest)
    (Left (trustDataProblem (label <> " must be a lowercase SHA-256 digest.") [digest]))

validProfileName :: Text -> Bool
validProfileName name = case Text.uncons name of
  Nothing -> False
  Just (first, rest) ->
    Text.length name <= 32
      && isLowerDigit first
      && Text.all (\character -> isLowerDigit character || character == '-') rest
 where
  isLowerDigit character = isAsciiLower character || isDigit character

validReverseDns :: Text -> Bool
validReverseDns value =
  let labels = Text.splitOn "." value
   in length labels >= 2 && all validDnsLabel labels

validReverseDnsPrefix :: Text -> Bool
validReverseDnsPrefix prefix =
  not (Text.null prefix)
    && Text.last prefix == '.'
    && validReverseDns (Text.dropEnd 1 prefix)

validDnsLabel :: Text -> Bool
validDnsLabel label =
  not (Text.null label)
    && Text.length label <= 63
    && isAlphaNumeric (Text.head label)
    && isAlphaNumeric (Text.last label)
    && Text.all (\character -> isAlphaNumeric character || character == '-') label
 where
  isAlphaNumeric character = isAsciiLower character || isDigit character

artifactReleaseKey :: PackArtifactIdentity -> (Text, Text, Text)
artifactReleaseKey identity = (artifactPublisher identity, artifactName identity, artifactVersion identity)

officialReleaseKey :: OfficialReleaseGrant -> (Text, Text, Text)
officialReleaseKey grant = (officialGrantPublisher grant, officialGrantName grant, officialGrantVersion grant)

uniqueOn :: (Ord key) => (value -> key) -> [value] -> Bool
uniqueOn project values = length values == Set.size (Set.fromList (project <$> values))

trustDataProblem :: Text -> [Text] -> AppError
trustDataProblem message details =
  (appError CorruptData message)
    { appErrorDetails = details
    }

trustPermissionProblem :: Text -> [Text] -> AppError
trustPermissionProblem message details =
  (appError PermissionRequired message)
    { appErrorDetails = details
    }

catalogExpiredProblem :: PackTrustAssessment -> AppError
catalogExpiredProblem assessment =
  (appError PreconditionFailed "The accepted official catalog is expired; refresh it before installing or updating this Pack.")
    { appErrorDetails =
        maybe [] (pure . ("accepted catalog sequence " <>) . Text.pack . show) (assessedOfficialCatalogSequence assessment)
    , appErrorRecovery = [RecoveryAction "packs.refresh" "Refresh the official Pack catalog" (Just "lant packs refresh")]
    }

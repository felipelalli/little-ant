module LittleAnt.Pack.Catalog (
  CatalogPublisherDelegation (..),
  CatalogRelease (..),
  CatalogRevocationTarget (..),
  CatalogRevocation (..),
  OfficialPackCatalog (..),
  CatalogSignatureDocument (..),
  CatalogRoot,
  catalogRootGeneration,
  catalogRootPublicKey,
  catalogRootFingerprint,
  catalogRootFromPublicKey,
  CatalogRootTransition (..),
  CatalogRootProof (..),
  AcceptedCatalogState,
  acceptedCatalogActiveRoot,
  acceptedCatalogCurrent,
  acceptedCatalogHistoryLength,
  emptyAcceptedCatalogState,
  encodeOfficialPackCatalog,
  encodeCatalogSignature,
  encodeCatalogRootTransition,
  encodeCatalogRootProof,
  acceptOfficialPackCatalog,
  acceptCatalogRootTransition,
  catalogTrustPolicy,
  CatalogStateConfig (..),
  readAcceptedCatalogState,
  refreshOfficialPackCatalog,
  rotateOfficialCatalogRoot,
)
where

import Control.Exception (IOException, bracketOnError, catch)
import Control.Monad (foldM, foldM_, unless, when)
import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.Bits ((.&.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Char (isAsciiLower, isDigit)
import Data.Foldable (traverse_)
import Data.List (maximumBy)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Pack.Format (canonicalJsonBytes)
import LittleAnt.Pack.Trust
import LittleAnt.SemVer (validSemVer)
import LittleAnt.Store (sha256Hex)
import System.Directory hiding (isSymbolicLink)
import System.FileLock (SharedExclusive (Exclusive), withFileLock)
import System.FilePath (takeDirectory, (</>))
import System.IO (hClose, hFlush, openBinaryTempFile)
import System.IO.Error (isDoesNotExistError)
import System.Posix.Files
import System.Posix.IO (FdOption (CloseOnExec), OpenMode (ReadOnly), closeFd, defaultFileFlags, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)

data CatalogPublisherDelegation = CatalogPublisherDelegation
  { catalogPublisherId :: Text
  , catalogPublisherPublicKey :: Text
  , catalogPublisherKeyFingerprint :: Text
  , catalogPublisherNamePrefixes :: [Text]
  }
  deriving stock (Eq, Show)

data CatalogRelease = CatalogRelease
  { catalogReleasePublisher :: Text
  , catalogReleaseName :: Text
  , catalogReleaseVersion :: Text
  , catalogReleaseManifestDigest :: Text
  , catalogReleaseArchiveDigest :: Text
  }
  deriving stock (Eq, Ord, Show)

data CatalogRevocationTarget
  = RevokePublisherKey
  | RevokeArchive
  deriving stock (Eq, Ord, Show)

data CatalogRevocation = CatalogRevocation
  { catalogRevocationTarget :: CatalogRevocationTarget
  , catalogRevocationSha256 :: Text
  , catalogRevocationReason :: Text
  , catalogRevocationEffectiveAt :: UTCTime
  }
  deriving stock (Eq, Ord, Show)

data OfficialPackCatalog = OfficialPackCatalog
  { officialCatalogSequence :: Integer
  , officialCatalogExpiresAt :: UTCTime
  , officialCatalogDelegations :: [CatalogPublisherDelegation]
  , officialCatalogReleases :: [CatalogRelease]
  , officialCatalogRevocations :: [CatalogRevocation]
  }
  deriving stock (Eq, Show)

data CatalogSignatureDocument = CatalogSignatureDocument
  { catalogSignatureRootFingerprint :: Text
  , catalogSignatureValue :: Text
  }
  deriving stock (Eq, Show)

data CatalogRoot = CatalogRoot
  { catalogRootGeneration :: Integer
  , catalogRootPublicKey :: Text
  , catalogRootFingerprint :: Text
  }
  deriving stock (Eq, Show)

data CatalogRootTransition = CatalogRootTransition
  { rootTransitionGeneration :: Integer
  , rootTransitionPreviousPublicKey :: Text
  , rootTransitionPreviousFingerprint :: Text
  , rootTransitionNextPublicKey :: Text
  , rootTransitionNextFingerprint :: Text
  }
  deriving stock (Eq, Show)

data CatalogRootProof = CatalogRootProof
  { rootProofPreviousSignature :: Text
  , rootProofNextSignature :: Text
  }
  deriving stock (Eq, Show)

data CatalogHistoryEntry
  = AcceptedCatalogEntry ByteString ByteString OfficialPackCatalog
  | AcceptedRootTransitionEntry ByteString ByteString CatalogRootTransition
  deriving stock (Eq, Show)

data AcceptedCatalogState = AcceptedCatalogState
  { acceptedCatalogActiveRoot :: CatalogRoot
  , acceptedCatalogHistory :: [CatalogHistoryEntry]
  , acceptedCatalogCatalogs :: [OfficialPackCatalog]
  }
  deriving stock (Eq, Show)

newtype CatalogStateConfig = CatalogStateConfig
  { catalogStatePath :: FilePath
  }
  deriving stock (Eq, Show)

newtype PersistedCatalogState = PersistedCatalogState [PersistedHistoryEntry]
  deriving stock (Eq, Show)

data PersistedHistoryEntry = PersistedHistoryEntry
  { persistedHistoryKind :: Text
  , persistedHistoryDocument :: Text
  , persistedHistoryProof :: Text
  }
  deriving stock (Eq, Show)

instance ToJSON CatalogPublisherDelegation where
  toJSON delegation =
    object
      [ "publisher" .= catalogPublisherId delegation
      , "public_key" .= catalogPublisherPublicKey delegation
      , "key_fingerprint" .= catalogPublisherKeyFingerprint delegation
      , "name_prefixes" .= catalogPublisherNamePrefixes delegation
      ]

instance FromJSON CatalogPublisherDelegation where
  parseJSON = withObject "CatalogPublisherDelegation" $ \fields -> do
    rejectUnknown fields ["publisher", "public_key", "key_fingerprint", "name_prefixes"]
    CatalogPublisherDelegation
      <$> fields .: "publisher"
      <*> fields .: "public_key"
      <*> fields .: "key_fingerprint"
      <*> fields .: "name_prefixes"

instance ToJSON CatalogRelease where
  toJSON release =
    object
      [ "publisher" .= catalogReleasePublisher release
      , "name" .= catalogReleaseName release
      , "version" .= catalogReleaseVersion release
      , "manifest_sha256" .= catalogReleaseManifestDigest release
      , "archive_sha256" .= catalogReleaseArchiveDigest release
      ]

instance FromJSON CatalogRelease where
  parseJSON = withObject "CatalogRelease" $ \fields -> do
    rejectUnknown fields ["publisher", "name", "version", "manifest_sha256", "archive_sha256"]
    CatalogRelease
      <$> fields .: "publisher"
      <*> fields .: "name"
      <*> fields .: "version"
      <*> fields .: "manifest_sha256"
      <*> fields .: "archive_sha256"

instance ToJSON CatalogRevocation where
  toJSON revocation =
    object
      [ "target" .= revocationTargetText (catalogRevocationTarget revocation)
      , "sha256" .= catalogRevocationSha256 revocation
      , "reason" .= catalogRevocationReason revocation
      , "effective_at" .= catalogRevocationEffectiveAt revocation
      ]

instance FromJSON CatalogRevocation where
  parseJSON = withObject "CatalogRevocation" $ \fields -> do
    rejectUnknown fields ["target", "sha256", "reason", "effective_at"]
    CatalogRevocation
      <$> (fields .: "target" >>= parseRevocationTarget)
      <*> fields .: "sha256"
      <*> fields .: "reason"
      <*> fields .: "effective_at"

instance ToJSON OfficialPackCatalog where
  toJSON catalog =
    object
      [ "schema" .= ("little-ant/pack-catalog@1" :: Text)
      , "sequence" .= officialCatalogSequence catalog
      , "expires_at" .= officialCatalogExpiresAt catalog
      , "delegations" .= officialCatalogDelegations catalog
      , "releases" .= officialCatalogReleases catalog
      , "revocations" .= officialCatalogRevocations catalog
      ]

instance FromJSON OfficialPackCatalog where
  parseJSON = withObject "OfficialPackCatalog" $ \fields -> do
    rejectUnknown fields ["schema", "sequence", "expires_at", "delegations", "releases", "revocations"]
    requireSchema fields "little-ant/pack-catalog@1"
    OfficialPackCatalog
      <$> fields .: "sequence"
      <*> fields .: "expires_at"
      <*> fields .: "delegations"
      <*> fields .: "releases"
      <*> fields .: "revocations"

instance ToJSON CatalogSignatureDocument where
  toJSON signature =
    object
      [ "schema" .= ("little-ant/catalog-signature@1" :: Text)
      , "algorithm" .= ("Ed25519" :: Text)
      , "root_fingerprint" .= catalogSignatureRootFingerprint signature
      , "signature" .= catalogSignatureValue signature
      ]

instance FromJSON CatalogSignatureDocument where
  parseJSON = withObject "CatalogSignatureDocument" $ \fields -> do
    rejectUnknown fields ["schema", "algorithm", "root_fingerprint", "signature"]
    requireSchema fields "little-ant/catalog-signature@1"
    requireAlgorithm fields
    CatalogSignatureDocument <$> fields .: "root_fingerprint" <*> fields .: "signature"

instance ToJSON CatalogRootTransition where
  toJSON transition =
    object
      [ "schema" .= ("little-ant/catalog-root@1" :: Text)
      , "generation" .= rootTransitionGeneration transition
      , "previous_root_public_key" .= rootTransitionPreviousPublicKey transition
      , "previous_root_fingerprint" .= rootTransitionPreviousFingerprint transition
      , "next_root_public_key" .= rootTransitionNextPublicKey transition
      , "next_root_fingerprint" .= rootTransitionNextFingerprint transition
      ]

instance FromJSON CatalogRootTransition where
  parseJSON = withObject "CatalogRootTransition" $ \fields -> do
    rejectUnknown fields ["schema", "generation", "previous_root_public_key", "previous_root_fingerprint", "next_root_public_key", "next_root_fingerprint"]
    requireSchema fields "little-ant/catalog-root@1"
    CatalogRootTransition
      <$> fields .: "generation"
      <*> fields .: "previous_root_public_key"
      <*> fields .: "previous_root_fingerprint"
      <*> fields .: "next_root_public_key"
      <*> fields .: "next_root_fingerprint"

instance ToJSON CatalogRootProof where
  toJSON proof =
    object
      [ "schema" .= ("little-ant/catalog-root-proof@1" :: Text)
      , "algorithm" .= ("Ed25519" :: Text)
      , "previous_signature" .= rootProofPreviousSignature proof
      , "next_signature" .= rootProofNextSignature proof
      ]

instance FromJSON CatalogRootProof where
  parseJSON = withObject "CatalogRootProof" $ \fields -> do
    rejectUnknown fields ["schema", "algorithm", "previous_signature", "next_signature"]
    requireSchema fields "little-ant/catalog-root-proof@1"
    requireAlgorithm fields
    CatalogRootProof <$> fields .: "previous_signature" <*> fields .: "next_signature"

instance ToJSON PersistedCatalogState where
  toJSON (PersistedCatalogState history) =
    object
      [ "schema" .= ("little-ant/pack-catalog-state@1" :: Text)
      , "history" .= history
      ]

instance FromJSON PersistedCatalogState where
  parseJSON = withObject "PersistedCatalogState" $ \fields -> do
    rejectUnknown fields ["schema", "history"]
    requireSchema fields "little-ant/pack-catalog-state@1"
    PersistedCatalogState <$> fields .: "history"

instance ToJSON PersistedHistoryEntry where
  toJSON entry =
    object
      [ "kind" .= persistedHistoryKind entry
      , "document" .= persistedHistoryDocument entry
      , "proof" .= persistedHistoryProof entry
      ]

instance FromJSON PersistedHistoryEntry where
  parseJSON = withObject "PersistedHistoryEntry" $ \fields -> do
    rejectUnknown fields ["kind", "document", "proof"]
    PersistedHistoryEntry <$> fields .: "kind" <*> fields .: "document" <*> fields .: "proof"

acceptedCatalogCurrent :: AcceptedCatalogState -> Maybe OfficialPackCatalog
acceptedCatalogCurrent state = case reverse (acceptedCatalogCatalogs state) of
  current : _ -> Just current
  [] -> Nothing

acceptedCatalogHistoryLength :: AcceptedCatalogState -> Int
acceptedCatalogHistoryLength = length . acceptedCatalogHistory

catalogRootFromPublicKey :: Integer -> Text -> Either AppError CatalogRoot
catalogRootFromPublicKey generation publicKey = do
  when (generation < 0) (Left (catalogProblem "A catalog root generation cannot be negative." []))
  keyBytes <- decodeBase64UrlExact "catalog root public key" 32 publicKey
  pure (CatalogRoot generation publicKey (sha256Hex keyBytes))

emptyAcceptedCatalogState :: CatalogRoot -> AcceptedCatalogState
emptyAcceptedCatalogState root = AcceptedCatalogState root [] []

encodeOfficialPackCatalog :: OfficialPackCatalog -> Either AppError ByteString
encodeOfficialPackCatalog catalog = validateOfficialCatalog catalog >> canonicalJsonBytes (toJSON catalog)

encodeCatalogSignature :: CatalogSignatureDocument -> Either AppError ByteString
encodeCatalogSignature signature = validateCatalogSignatureShape signature >> canonicalJsonBytes (toJSON signature)

encodeCatalogRootTransition :: CatalogRootTransition -> Either AppError ByteString
encodeCatalogRootTransition transition = validateRootTransition transition >> canonicalJsonBytes (toJSON transition)

encodeCatalogRootProof :: CatalogRootProof -> Either AppError ByteString
encodeCatalogRootProof proof = validateRootProofShape proof >> canonicalJsonBytes (toJSON proof)

acceptOfficialPackCatalog :: UTCTime -> AcceptedCatalogState -> ByteString -> ByteString -> Either AppError AcceptedCatalogState
acceptOfficialPackCatalog now state catalogBytes signatureBytes = do
  catalog <- verifyOfficialCatalog (acceptedCatalogActiveRoot state) catalogBytes signatureBytes
  when (now >= officialCatalogExpiresAt catalog) (Left (expiredCatalogProblem catalog))
  appendVerifiedCatalog state catalogBytes signatureBytes catalog

acceptCatalogRootTransition :: AcceptedCatalogState -> ByteString -> ByteString -> Either AppError AcceptedCatalogState
acceptCatalogRootTransition state transitionBytes proofBytes = do
  transition <- verifyRootTransition (acceptedCatalogActiveRoot state) transitionBytes proofBytes
  let nextRoot =
        CatalogRoot
          (rootTransitionGeneration transition)
          (rootTransitionNextPublicKey transition)
          (rootTransitionNextFingerprint transition)
  pure
    state
      { acceptedCatalogActiveRoot = nextRoot
      , acceptedCatalogHistory = acceptedCatalogHistory state <> [AcceptedRootTransitionEntry transitionBytes proofBytes transition]
      }

catalogTrustPolicy :: UTCTime -> Int -> Set PackArtifactIdentity -> Set TrustedCommunityPublisher -> AcceptedCatalogState -> PackTrustPolicy
catalogTrustPolicy now supportedMajor builtIns community state =
  PackTrustPolicy
    { trustSupportedLittleAntMajor = supportedMajor
    , trustBuiltInArtifacts = builtIns
    , trustOfficialCatalogSequence = officialCatalogSequence <$> current
    , trustOfficialCatalogExpiresAt = officialCatalogExpiresAt <$> current
    , trustOfficialReleaseGrants = maybe Set.empty releaseGrants current
    , trustOfficialPinAuthorizations = Set.fromList (concatMap pinAuthorizations (acceptedCatalogCatalogs state))
    , trustCommunityPublishers = community
    , trustRevokedKeyFingerprints = revoked RevokePublisherKey
    , trustRevokedArchiveDigests = revoked RevokeArchive
    }
 where
  current = acceptedCatalogCurrent state
  effectiveRevocations =
    [ revocation
    | catalog <- acceptedCatalogCatalogs state
    , revocation <- officialCatalogRevocations catalog
    , catalogRevocationEffectiveAt revocation <= now
    ]
  revoked target = Set.fromList [catalogRevocationSha256 value | value <- effectiveRevocations, catalogRevocationTarget value == target]

  releaseGrants catalog = Set.fromList (mapMaybe (grantFor catalog) (officialCatalogReleases catalog))
  grantFor catalog release = do
    delegation <- uniqueDelegationFor catalog release
    prefix <- longestMatchingPrefix delegation release
    pure
      OfficialReleaseGrant
        { officialGrantPublisher = catalogReleasePublisher release
        , officialGrantNamePrefix = prefix
        , officialGrantPublicKey = catalogPublisherPublicKey delegation
        , officialGrantKeyFingerprint = catalogPublisherKeyFingerprint delegation
        , officialGrantName = catalogReleaseName release
        , officialGrantVersion = catalogReleaseVersion release
        , officialGrantManifestDigest = catalogReleaseManifestDigest release
        , officialGrantArchiveDigest = catalogReleaseArchiveDigest release
        }

  pinAuthorizations catalog = mapMaybe (pinAuthorizationFor catalog) (officialCatalogReleases catalog)
  pinAuthorizationFor catalog release = do
    grant <- grantFor catalog release
    pure (officialPinAuthorizationFromGrant (officialCatalogSequence catalog) grant)

readAcceptedCatalogState :: CatalogStateConfig -> CatalogRoot -> IO (Either AppError AcceptedCatalogState)
readAcceptedCatalogState config compiledRoot = handleCatalogIo $ do
  observed <- readStateBytes config
  pure $ case observed of
    Nothing -> Right (emptyAcceptedCatalogState compiledRoot)
    Just bytes -> decodeAcceptedState compiledRoot bytes

refreshOfficialPackCatalog :: CatalogStateConfig -> CatalogRoot -> UTCTime -> ByteString -> ByteString -> IO (Either AppError AcceptedCatalogState)
refreshOfficialPackCatalog config compiledRoot now catalogBytes signatureBytes =
  mutateCatalogState config compiledRoot (\state -> acceptOfficialPackCatalog now state catalogBytes signatureBytes)

rotateOfficialCatalogRoot :: CatalogStateConfig -> CatalogRoot -> ByteString -> ByteString -> IO (Either AppError AcceptedCatalogState)
rotateOfficialCatalogRoot config compiledRoot transitionBytes proofBytes =
  mutateCatalogState config compiledRoot (\state -> acceptCatalogRootTransition state transitionBytes proofBytes)

appendVerifiedCatalog :: AcceptedCatalogState -> ByteString -> ByteString -> OfficialPackCatalog -> Either AppError AcceptedCatalogState
appendVerifiedCatalog state catalogBytes signatureBytes catalog = do
  case acceptedCatalogCurrent state of
    Nothing -> pure ()
    Just previous ->
      unless
        (officialCatalogSequence catalog > officialCatalogSequence previous)
        (Left (catalogRollbackProblem previous catalog))
  pure
    state
      { acceptedCatalogHistory = acceptedCatalogHistory state <> [AcceptedCatalogEntry catalogBytes signatureBytes catalog]
      , acceptedCatalogCatalogs = acceptedCatalogCatalogs state <> [catalog]
      }

verifyOfficialCatalog :: CatalogRoot -> ByteString -> ByteString -> Either AppError OfficialPackCatalog
verifyOfficialCatalog root catalogBytes signatureBytes = do
  catalog <- decodeCanonicalDocument "official Pack catalog" maxCatalogDocumentBytes catalogBytes
  signature <- decodeCanonicalDocument "official Pack catalog signature" maxProofDocumentBytes signatureBytes
  validateOfficialCatalog catalog
  validateCatalogSignatureShape signature
  unless
    (catalogSignatureRootFingerprint signature == catalogRootFingerprint root)
    (Left (catalogProblem "The catalog signature does not name the active root." [catalogSignatureRootFingerprint signature]))
  verifyEd25519
    "The official catalog signature does not authenticate the exact catalog bytes."
    (catalogRootPublicKey root)
    catalogBytes
    (catalogSignatureValue signature)
  pure catalog

verifyRootTransition :: CatalogRoot -> ByteString -> ByteString -> Either AppError CatalogRootTransition
verifyRootTransition current transitionBytes proofBytes = do
  transition <- decodeCanonicalDocument "catalog root transition" maxProofDocumentBytes transitionBytes
  proof <- decodeCanonicalDocument "catalog root proof" maxProofDocumentBytes proofBytes
  validateRootTransition transition
  validateRootProofShape proof
  unless
    ( rootTransitionGeneration transition == catalogRootGeneration current + 1
        && rootTransitionPreviousPublicKey transition == catalogRootPublicKey current
        && rootTransitionPreviousFingerprint transition == catalogRootFingerprint current
    )
    (Left (catalogProblem "The root transition does not continue the active root generation." []))
  verifyTransitionProof transitionBytes transition proof
  pure transition

verifyTransitionProof :: ByteString -> CatalogRootTransition -> CatalogRootProof -> Either AppError ()
verifyTransitionProof transitionBytes transition proof = do
  verifyEd25519
    "The previous root did not authenticate the exact root transition bytes."
    (rootTransitionPreviousPublicKey transition)
    transitionBytes
    (rootProofPreviousSignature proof)
  verifyEd25519
    "The replacement root did not authenticate the exact root transition bytes."
    (rootTransitionNextPublicKey transition)
    transitionBytes
    (rootProofNextSignature proof)

validateOfficialCatalog :: OfficialPackCatalog -> Either AppError ()
validateOfficialCatalog catalog = do
  when (officialCatalogSequence catalog < 0) (Left (catalogProblem "An official catalog sequence cannot be negative." []))
  traverse_ validateDelegation delegations
  unless (uniqueOn catalogPublisherId delegations) (Left (catalogProblem "An official catalog contains duplicate publisher delegations." []))
  traverse_ validateRelease releases
  unless (uniqueOn releaseKey releases) (Left (catalogProblem "An official catalog equivocates one Pack release." []))
  traverse_ validateRevocation revocations
  unless (uniqueOn revocationKey revocations) (Left (catalogProblem "An official catalog repeats one revocation target." []))
  traverse_ requireAuthorizedRelease releases
 where
  delegations = officialCatalogDelegations catalog
  releases = officialCatalogReleases catalog
  revocations = officialCatalogRevocations catalog
  requireAuthorizedRelease release = case Map.lookup (catalogReleasePublisher release) delegationMap of
    Nothing -> Left (catalogProblem "An official release has no publisher delegation." [catalogReleasePublisher release])
    Just delegation ->
      unless
        (any (`Text.isPrefixOf` catalogReleaseName release) (catalogPublisherNamePrefixes delegation))
        (Left (catalogProblem "An official release is outside its delegated Pack name prefixes." [catalogReleaseName release]))
  delegationMap = Map.fromList [(catalogPublisherId delegation, delegation) | delegation <- delegations]

validateDelegation :: CatalogPublisherDelegation -> Either AppError ()
validateDelegation delegation = do
  unless (validReverseDns (catalogPublisherId delegation)) (Left (catalogProblem "A catalog publisher ID is invalid." []))
  keyBytes <- decodeBase64UrlExact "catalog publisher public key" 32 (catalogPublisherPublicKey delegation)
  validateDigest "A catalog publisher key fingerprint" (catalogPublisherKeyFingerprint delegation)
  unless (sha256Hex keyBytes == catalogPublisherKeyFingerprint delegation) (Left (catalogProblem "A catalog publisher fingerprint does not match its public key." [catalogPublisherId delegation]))
  when (null prefixes) (Left (catalogProblem "A catalog publisher must delegate at least one Pack name prefix." [catalogPublisherId delegation]))
  traverse_ (\prefix -> unless (validReverseDnsPrefix prefix) (Left (catalogProblem "A delegated Pack name prefix is invalid." [prefix]))) prefixes
  unless (uniqueList prefixes) (Left (catalogProblem "A publisher delegation repeats a Pack name prefix." [catalogPublisherId delegation]))
 where
  prefixes = catalogPublisherNamePrefixes delegation

validateRelease :: CatalogRelease -> Either AppError ()
validateRelease release = do
  unless (validReverseDns (catalogReleasePublisher release)) (Left (catalogProblem "An official release publisher ID is invalid." []))
  unless (validReverseDns (catalogReleaseName release)) (Left (catalogProblem "An official release Pack name is invalid." []))
  unless (validSemVer (catalogReleaseVersion release)) (Left (catalogProblem "An official release version is not complete SemVer 2.0.0." []))
  validateDigest "An official release manifest digest" (catalogReleaseManifestDigest release)
  validateDigest "An official release archive digest" (catalogReleaseArchiveDigest release)

validateRevocation :: CatalogRevocation -> Either AppError ()
validateRevocation revocation = do
  validateDigest "A catalog revocation SHA-256" (catalogRevocationSha256 revocation)
  when (Text.null (Text.strip (catalogRevocationReason revocation))) (Left (catalogProblem "A catalog revocation reason cannot be empty." []))

validateCatalogSignatureShape :: CatalogSignatureDocument -> Either AppError ()
validateCatalogSignatureShape signature = do
  validateDigest "A catalog signature root fingerprint" (catalogSignatureRootFingerprint signature)
  _ <- decodeBase64UrlExact "catalog signature" 64 (catalogSignatureValue signature)
  pure ()

validateRootTransition :: CatalogRootTransition -> Either AppError ()
validateRootTransition transition = do
  when (rootTransitionGeneration transition <= 0) (Left (catalogProblem "A root transition generation must be positive." []))
  previous <- catalogRootFromPublicKey (rootTransitionGeneration transition - 1) (rootTransitionPreviousPublicKey transition)
  next <- catalogRootFromPublicKey (rootTransitionGeneration transition) (rootTransitionNextPublicKey transition)
  unless (catalogRootFingerprint previous == rootTransitionPreviousFingerprint transition) (Left (catalogProblem "The previous root fingerprint does not match its public key." []))
  unless (catalogRootFingerprint next == rootTransitionNextFingerprint transition) (Left (catalogProblem "The replacement root fingerprint does not match its public key." []))
  when (catalogRootPublicKey previous == catalogRootPublicKey next) (Left (catalogProblem "A root transition must replace the key." []))

validateRootProofShape :: CatalogRootProof -> Either AppError ()
validateRootProofShape proof = do
  _ <- decodeBase64UrlExact "previous root transition signature" 64 (rootProofPreviousSignature proof)
  _ <- decodeBase64UrlExact "next root transition signature" 64 (rootProofNextSignature proof)
  pure ()

uniqueDelegationFor :: OfficialPackCatalog -> CatalogRelease -> Maybe CatalogPublisherDelegation
uniqueDelegationFor catalog release =
  case filter ((== catalogReleasePublisher release) . catalogPublisherId) (officialCatalogDelegations catalog) of
    [delegation] -> Just delegation
    _ -> Nothing

longestMatchingPrefix :: CatalogPublisherDelegation -> CatalogRelease -> Maybe Text
longestMatchingPrefix delegation release =
  case filter (`Text.isPrefixOf` catalogReleaseName release) (catalogPublisherNamePrefixes delegation) of
    [] -> Nothing
    prefixes -> Just (maximumBy (comparing Text.length) prefixes)

releaseKey :: CatalogRelease -> (Text, Text, Text)
releaseKey release = (catalogReleasePublisher release, catalogReleaseName release, catalogReleaseVersion release)

revocationKey :: CatalogRevocation -> (CatalogRevocationTarget, Text)
revocationKey revocation = (catalogRevocationTarget revocation, catalogRevocationSha256 revocation)

revocationTargetText :: CatalogRevocationTarget -> Text
revocationTargetText = \case
  RevokePublisherKey -> "publisher_key"
  RevokeArchive -> "archive"

parseRevocationTarget :: Text -> Parser CatalogRevocationTarget
parseRevocationTarget = \case
  "publisher_key" -> pure RevokePublisherKey
  "archive" -> pure RevokeArchive
  _ -> fail "unknown catalog revocation target"

decodeAcceptedState :: CatalogRoot -> ByteString -> Either AppError AcceptedCatalogState
decodeAcceptedState compiledRoot bytes = do
  PersistedCatalogState persisted <- decodeCanonicalDocument "accepted catalog state" maxCatalogStateBytes bytes
  decoded <- traverse decodeHistoryEntry persisted
  initialRoot <- deriveInitialRoot compiledRoot decoded
  foldM replayHistoryEntry (emptyAcceptedCatalogState initialRoot) decoded

decodeHistoryEntry :: PersistedHistoryEntry -> Either AppError CatalogHistoryEntry
decodeHistoryEntry persisted = do
  document <- decodeStateBytes "history document" (persistedHistoryDocument persisted)
  proof <- decodeStateBytes "history proof" (persistedHistoryProof persisted)
  case persistedHistoryKind persisted of
    "catalog" -> do
      catalog <- decodeCanonicalDocument "persisted official catalog" maxCatalogDocumentBytes document
      pure (AcceptedCatalogEntry document proof catalog)
    "root_transition" -> do
      transition <- decodeCanonicalDocument "persisted root transition" maxProofDocumentBytes document
      pure (AcceptedRootTransitionEntry document proof transition)
    _ -> Left (catalogProblem "Accepted catalog state contains an unknown history kind." [persistedHistoryKind persisted])

deriveInitialRoot :: CatalogRoot -> [CatalogHistoryEntry] -> Either AppError CatalogRoot
deriveInitialRoot compiled entries = case [transition | AcceptedRootTransitionEntry _ _ transition <- entries] of
  [] -> Right compiled
  first : rest -> do
    validateRootTransition first
    let initial =
          CatalogRoot
            (rootTransitionGeneration first - 1)
            (rootTransitionPreviousPublicKey first)
            (rootTransitionPreviousFingerprint first)
    foldM_ linkedNext first rest
    let roots = initial : fmap transitionNextRoot (first : rest)
    unless (compiled `elem` roots) (Left (catalogProblem "The persisted root chain is not anchored by this binary's compiled root." [catalogRootFingerprint compiled]))
    pure initial
 where
  linkedNext previous next = do
    validateRootTransition next
    unless
      ( rootTransitionGeneration next == rootTransitionGeneration previous + 1
          && rootTransitionPreviousPublicKey next == rootTransitionNextPublicKey previous
          && rootTransitionPreviousFingerprint next == rootTransitionNextFingerprint previous
      )
      (Left (catalogProblem "The persisted catalog root transitions do not form one contiguous chain." []))
    pure next

transitionNextRoot :: CatalogRootTransition -> CatalogRoot
transitionNextRoot transition = CatalogRoot (rootTransitionGeneration transition) (rootTransitionNextPublicKey transition) (rootTransitionNextFingerprint transition)

replayHistoryEntry :: AcceptedCatalogState -> CatalogHistoryEntry -> Either AppError AcceptedCatalogState
replayHistoryEntry state = \case
  AcceptedCatalogEntry document proof _ -> do
    catalog <- verifyOfficialCatalog (acceptedCatalogActiveRoot state) document proof
    appendVerifiedCatalog state document proof catalog
  AcceptedRootTransitionEntry document proof _ -> acceptCatalogRootTransition state document proof

encodeAcceptedState :: AcceptedCatalogState -> Either AppError ByteString
encodeAcceptedState state = canonicalJsonBytes . toJSON . PersistedCatalogState $ fmap persist (acceptedCatalogHistory state)
 where
  persist = \case
    AcceptedCatalogEntry document proof _ -> encoded "catalog" document proof
    AcceptedRootTransitionEntry document proof _ -> encoded "root_transition" document proof
  encoded kind document proof =
    PersistedHistoryEntry
      kind
      (Text.decodeUtf8 (Base64Url.encodeUnpadded document))
      (Text.decodeUtf8 (Base64Url.encodeUnpadded proof))

mutateCatalogState :: CatalogStateConfig -> CatalogRoot -> (AcceptedCatalogState -> Either AppError AcceptedCatalogState) -> IO (Either AppError AcceptedCatalogState)
mutateCatalogState config compiledRoot mutation = handleCatalogIo $ do
  ensureCatalogDirectory config
  withFileLock (catalogLockPath config) Exclusive $ \_ -> do
    setFileMode (catalogLockPath config) 0o600
    observed <- readStateBytes config
    case maybe (Right (emptyAcceptedCatalogState compiledRoot)) (decodeAcceptedState compiledRoot) observed >>= mutation of
      Left problem -> pure (Left problem)
      Right next -> case encodeAcceptedState next of
        Left problem -> pure (Left problem)
        Right bytes -> writeStateBytes config bytes >> pure (Right next)

readStateBytes :: CatalogStateConfig -> IO (Maybe ByteString)
readStateBytes config = do
  let path = catalogStatePath config
  statusResult <- catch (Just <$> getSymbolicLinkStatus path) missing
  case statusResult of
    Nothing -> pure Nothing
    Just status -> do
      unless (isRegularFile status && not (isSymbolicLink status)) (ioError (userError "catalog state is not a regular file"))
      unless (fileMode status .&. 0o077 == 0) (ioError (userError "catalog state permissions are not private"))
      when (fromIntegral (fileSize status) > maxCatalogStateBytes) (ioError (userError "catalog state exceeds its bounded read limit"))
      Just <$> ByteString.readFile path
 where
  missing problem
    | isDoesNotExistError problem = pure Nothing
    | otherwise = ioError problem

writeStateBytes :: CatalogStateConfig -> ByteString -> IO ()
writeStateBytes config bytes = do
  let path = catalogStatePath config
      directory = takeDirectory path
  bracketOnError
    (openBinaryTempFile directory ".lant-pack-catalog.tmp")
    (\(temporary, handle) -> catch (hClose handle) ignoreIo >> removeIfPresent temporary)
    ( \(temporary, handle) -> do
        setFileMode temporary 0o600
        ByteString.hPut handle bytes
        hFlush handle
        descriptor <- handleToFd handle
        setFdOption descriptor CloseOnExec True
        fileSynchronise descriptor
        closeFd descriptor
        renameFile temporary path
        setFileMode path 0o600
        syncDirectory directory
    )

ensureCatalogDirectory :: CatalogStateConfig -> IO ()
ensureCatalogDirectory config = do
  let directory = takeDirectory (catalogStatePath config)
  createDirectoryIfMissing True directory
  status <- getSymbolicLinkStatus directory
  unless (isDirectory status && not (isSymbolicLink status)) (ioError (userError "catalog state parent is not a real directory"))
  setFileMode directory 0o700

catalogLockPath :: CatalogStateConfig -> FilePath
catalogLockPath config = takeDirectory (catalogStatePath config) </> ".official-pack-catalog.lock"

decodeCanonicalDocument :: (FromJSON value) => Text -> Int -> ByteString -> Either AppError value
decodeCanonicalDocument label maximumBytes bytes = do
  when (ByteString.length bytes > maximumBytes) (Left (catalogProblem ("The " <> label <> " exceeds its bounded size.") []))
  value <- either (\problem -> Left (catalogProblem ("The " <> label <> " is not valid JSON.") [Text.pack problem])) Right (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (catalogProblem ("The " <> label <> " is not RFC 8785 canonical JSON.") []))
  either (\problem -> Left (catalogProblem ("The " <> label <> " does not match its closed schema.") [Text.pack problem])) Right (parseEither parseJSON value)

decodeStateBytes :: Text -> Text -> Either AppError ByteString
decodeStateBytes label encoded = do
  let encodedBytes = Text.encodeUtf8 encoded
  decoded <- either (\problem -> Left (catalogProblem ("The persisted " <> label <> " is not canonical base64url.") [Text.pack problem])) Right (Base64Url.decodeUnpadded encodedBytes)
  unless (Base64Url.encodeUnpadded decoded == encodedBytes) (Left (catalogProblem ("The persisted " <> label <> " is not canonical base64url.") []))
  pure decoded

verifyEd25519 :: Text -> Text -> ByteString -> Text -> Either AppError ()
verifyEd25519 message publicKeyText payload signatureText = do
  publicKeyBytes <- decodeBase64UrlExact "Ed25519 public key" 32 publicKeyText
  signatureBytes <- decodeBase64UrlExact "Ed25519 signature" 64 signatureText
  publicKey <- cryptoValue "The catalog public key is not a valid Ed25519 key." (Ed25519.publicKey publicKeyBytes)
  signature <- cryptoValue "The catalog signature is not a valid Ed25519 signature." (Ed25519.signature signatureBytes)
  unless (Ed25519.verify publicKey payload signature) (Left (catalogProblem message []))

decodeBase64UrlExact :: Text -> Int -> Text -> Either AppError ByteString
decodeBase64UrlExact label expectedLength encoded = do
  let encodedBytes = Text.encodeUtf8 encoded
  decoded <- either (\problem -> Left (catalogProblem ("The " <> label <> " is not canonical unpadded base64url.") [Text.pack problem])) Right (Base64Url.decodeUnpadded encodedBytes)
  unless (Base64Url.encodeUnpadded decoded == encodedBytes) (Left (catalogProblem ("The " <> label <> " is not canonical unpadded base64url.") []))
  unless (ByteString.length decoded == expectedLength) (Left (catalogProblem ("The " <> label <> " has the wrong decoded length.") ["expected " <> Text.pack (show expectedLength) <> " bytes"]))
  pure decoded

cryptoValue :: Text -> CryptoFailable value -> Either AppError value
cryptoValue message = \case
  CryptoPassed value -> Right value
  CryptoFailed problem -> Left (catalogProblem message [Text.pack (show problem)])

validateDigest :: Text -> Text -> Either AppError ()
validateDigest label digest =
  unless
    (Text.length digest == 64 && Text.all (\character -> isDigit character || character >= 'a' && character <= 'f') digest)
    (Left (catalogProblem (label <> " must be a lowercase SHA-256 digest.") [digest]))

validReverseDns :: Text -> Bool
validReverseDns value =
  let labels = Text.splitOn "." value
   in length labels >= 2 && all validDnsLabel labels

validReverseDnsPrefix :: Text -> Bool
validReverseDnsPrefix prefix = not (Text.null prefix) && Text.last prefix == '.' && validReverseDns (Text.dropEnd 1 prefix)

validDnsLabel :: Text -> Bool
validDnsLabel label =
  not (Text.null label)
    && Text.length label <= 63
    && lowerDigit (Text.head label)
    && lowerDigit (Text.last label)
    && Text.all (\character -> lowerDigit character || character == '-') label
 where
  lowerDigit character = isAsciiLower character || isDigit character

uniqueOn :: (Ord key) => (value -> key) -> [value] -> Bool
uniqueOn project values = uniqueList (project <$> values)

uniqueList :: (Ord value) => [value] -> Bool
uniqueList values = length values == Set.size (Set.fromList values)

requireSchema :: Object -> Text -> Parser ()
requireSchema fields expected = do
  actual <- fields .: "schema"
  unless (actual == expected) (fail ("unsupported schema: " <> Text.unpack actual))

requireAlgorithm :: Object -> Parser ()
requireAlgorithm fields = do
  algorithm <- fields .: "algorithm"
  unless (algorithm == ("Ed25519" :: Text)) (fail "unsupported signature algorithm")

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

catalogProblem :: Text -> [Text] -> AppError
catalogProblem message details =
  (appError CorruptData message)
    { appErrorDetails = details
    }

catalogRollbackProblem :: OfficialPackCatalog -> OfficialPackCatalog -> AppError
catalogRollbackProblem current candidate =
  (appError Conflict "The official Pack catalog sequence must strictly increase.")
    { appErrorDetails =
        [ "accepted sequence " <> Text.pack (show (officialCatalogSequence current))
        , "candidate sequence " <> Text.pack (show (officialCatalogSequence candidate))
        ]
    , appErrorRecovery = [RecoveryAction "newer-catalog" "Refresh from a source that publishes a newer catalog." (Just "lant packs refresh")]
    }

expiredCatalogProblem :: OfficialPackCatalog -> AppError
expiredCatalogProblem catalog =
  (appError PreconditionFailed "The candidate official Pack catalog is already expired.")
    { appErrorDetails = ["candidate sequence " <> Text.pack (show (officialCatalogSequence catalog))]
    , appErrorRecovery = [RecoveryAction "newer-catalog" "Refresh from a source that publishes an unexpired catalog." (Just "lant packs refresh")]
    }

handleCatalogIo :: IO (Either AppError value) -> IO (Either AppError value)
handleCatalogIo action = catch action $ \problem ->
  pure . Left $
    (appError ExternalFailure "Little Ant could not access the official Pack catalog state safely.")
      { appErrorDetails = [Text.pack (show (problem :: IOException))]
      , appErrorRetrySafety = RetrySafe
      }

syncDirectory :: FilePath -> IO ()
syncDirectory path = do
  descriptor <- openFd path ReadOnly defaultFileFlags
  fileSynchronise descriptor
  closeFd descriptor

removeIfPresent :: FilePath -> IO ()
removeIfPresent path = catch (removeFile path) (\problem -> unless (isDoesNotExistError problem) (ioError problem))

ignoreIo :: IOException -> IO ()
ignoreIo _ = pure ()

maxCatalogDocumentBytes :: Int
maxCatalogDocumentBytes = 8 * 1024 * 1024

maxProofDocumentBytes :: Int
maxProofDocumentBytes = 64 * 1024

maxCatalogStateBytes :: Int
maxCatalogStateBytes = 64 * 1024 * 1024

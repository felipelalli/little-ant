{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless, when)
import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Aeson (FromJSON (..), ToJSON (..), eitherDecodeStrict', object, withObject, (.:), (.=))
import Data.Bits ((.&.))
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (UTCTime, defaultTimeLocale, getCurrentTime, parseTimeM)
import LittleAnt.Error (AppError)
import LittleAnt.Pack.Catalog
import LittleAnt.Pack.Format (canonicalJsonBytes, validatePackArchive)
import LittleAnt.Pack.Trust
import LittleAnt.Store (sha256Hex)
import System.Directory (canonicalizePath, createDirectoryIfMissing, doesFileExist, getCurrentDirectory)
import System.Environment (getArgs)
import System.FilePath (isAbsolute, makeRelative, normalise, splitDirectories, (</>))
import System.IO (hPutStrLn, stderr)
import System.Posix.Files (fileMode, fileSize, getSymbolicLinkStatus, isRegularFile, isSymbolicLink)
import Text.Read (readMaybe)

data PublicRootDocument = PublicRootDocument
  { publicRootGeneration :: Integer
  , publicRootPublicKey :: Text
  , publicRootFingerprint :: Text
  }

instance ToJSON PublicRootDocument where
  toJSON root =
    object
      [ "schema" .= ("little-ant/compiled-catalog-root@1" :: Text)
      , "generation" .= publicRootGeneration root
      , "public_key" .= publicRootPublicKey root
      , "key_fingerprint" .= publicRootFingerprint root
      ]

instance FromJSON PublicRootDocument where
  parseJSON = withObject "PublicRootDocument" $ \fields ->
    PublicRootDocument
      <$> fields .: "generation"
      <*> fields .: "public_key"
      <*> fields .: "key_fingerprint"

catalogDirectory :: FilePath
catalogDirectory = "packs" </> "official"

connectorArchive :: FilePath
connectorArchive = "packs" </> "official-connectors" </> "official-connectors.lantpack"

main :: IO ()
main =
  getArgs >>= \case
    ["sign", secretPath, sequenceText, expiresAt] -> signCatalog secretPath sequenceText expiresAt
    ["verify"] -> verifyCatalog
    _ -> die "usage: cabal exec runghc -- -isrc tools/official-catalog.hs sign SECRET-FILE SEQUENCE EXPIRES-AT|verify"

signCatalog :: FilePath -> String -> String -> IO ()
signCatalog secretPath sequenceText expiresAtText = do
  ensureSecretOutsideCheckout secretPath
  secretBytes <- readPrivateSeed secretPath
  secret <- cryptoOrDie (Ed25519.secretKey secretBytes)
  sequenceNumber <- maybe (die "SEQUENCE must be a positive integer") pure (readMaybe sequenceText)
  when (sequenceNumber < 1) (die "SEQUENCE must be a positive integer")
  expiresAt <-
    maybe
      (die "EXPIRES-AT must be UTC RFC 3339 such as 2028-08-09T00:00:00Z")
      pure
      (parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" expiresAtText :: Maybe UTCTime)
  now <- getCurrentTime
  when (expiresAt <= now) (die "EXPIRES-AT must be in the future at publication time")
  previous <- readPreviousCatalog
  case previous of
    Nothing -> unless (sequenceNumber == 1) (die "the first official catalog must use sequence 1")
    Just catalog -> do
      verifyCatalog
      unless (sequenceNumber > officialCatalogSequence catalog) (die "a replacement catalog must strictly increase the published sequence")
  authenticated <- readConnector
  let public = Ed25519.toPublic secret
      publicBytes = convert public
      publicKey = encodeBase64 publicBytes
      fingerprint = sha256Hex publicBytes
      identity = authenticatedPackIdentity authenticated
      rootDocument = PublicRootDocument 0 publicKey fingerprint
      rememberedRevocations = maybe [] officialCatalogRevocations previous
      catalog =
        OfficialPackCatalog
          { officialCatalogSequence = sequenceNumber
          , officialCatalogExpiresAt = expiresAt
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
          , officialCatalogRevocations = rememberedRevocations
          }
  catalogBytes <- rightOrDie (encodeOfficialPackCatalog catalog)
  signatureBytes <-
    rightOrDie . encodeCatalogSignature $
      CatalogSignatureDocument
        { catalogSignatureRootFingerprint = fingerprint
        , catalogSignatureValue = encodeBase64 (convert (Ed25519.sign secret public catalogBytes))
        }
  rootBytes <- rightOrDie (canonicalJsonBytes (toJSON rootDocument))
  archiveBytes <- ByteString.readFile connectorArchive
  validateExistingRoot rootDocument
  createDirectoryIfMissing True (catalogDirectory </> "releases")
  ByteString.writeFile (catalogDirectory </> "catalog-root.json") rootBytes
  ByteString.writeFile (catalogDirectory </> "catalog.json") catalogBytes
  ByteString.writeFile (catalogDirectory </> "catalog-signature.json") signatureBytes
  ByteString.writeFile (catalogDirectory </> "releases" </> Text.unpack (artifactArchiveDigest identity) <> ".lantpack") archiveBytes
  putStrLn ("catalog root public key: " <> Text.unpack publicKey)
  putStrLn ("catalog root fingerprint: " <> Text.unpack fingerprint)
  putStrLn ("catalog sequence: " <> show sequenceNumber)
  putStrLn ("release archive: " <> Text.unpack (artifactArchiveDigest identity))

verifyCatalog :: IO ()
verifyCatalog = do
  rootBytes <- ByteString.readFile (catalogDirectory </> "catalog-root.json")
  rootDocument <- either die pure (eitherDecodeStrict' rootBytes)
  root <- rightOrDie (catalogRootFromPublicKey (publicRootGeneration rootDocument) (publicRootPublicKey rootDocument))
  unless (catalogRootFingerprint root == publicRootFingerprint rootDocument) (die "catalog-root.json fingerprint mismatch")
  catalogBytes <- ByteString.readFile (catalogDirectory </> "catalog.json")
  signatureBytes <- ByteString.readFile (catalogDirectory </> "catalog-signature.json")
  accepted <-
    rightOrDie
      ( acceptOfficialPackCatalog
          (read "1970-01-01 00:00:00 UTC")
          (emptyAcceptedCatalogState root)
          catalogBytes
          signatureBytes
      )
  catalog <- maybe (die "verified catalog has no current document") pure (acceptedCatalogCurrent accepted)
  case officialCatalogReleases catalog of
    [release] -> do
      let path = catalogDirectory </> "releases" </> Text.unpack (catalogReleaseArchiveDigest release) <> ".lantpack"
      bytes <- ByteString.readFile path
      structural <- rightOrDie (validatePackArchive bytes)
      authenticated <- rightOrDie (authenticatePack structural)
      let identity = authenticatedPackIdentity authenticated
      unless
        ( artifactPublisher identity == catalogReleasePublisher release
            && artifactName identity == catalogReleaseName release
            && artifactVersion identity == catalogReleaseVersion release
            && artifactManifestDigest identity == catalogReleaseManifestDigest release
            && artifactArchiveDigest identity == catalogReleaseArchiveDigest release
        )
        (die "catalog release does not match its signed archive")
      putStrLn ("verified official catalog sequence " <> show (officialCatalogSequence catalog) <> " and " <> path)
    _ -> die "the V1 official catalog must contain exactly one release"

ensureSecretOutsideCheckout :: FilePath -> IO ()
ensureSecretOutsideCheckout requested = do
  checkout <- canonicalizePath =<< getCurrentDirectory
  secret <- canonicalizePath requested
  let relative = normalise (makeRelative checkout secret)
      inside =
        not (isAbsolute relative) && case splitDirectories relative of
          ".." : _ -> False
          _ -> True
  when inside (die "the catalog signing secret must live outside the repository checkout")

readPrivateSeed :: FilePath -> IO ByteString
readPrivateSeed path = do
  status <- getSymbolicLinkStatus path
  unless (isRegularFile status && not (isSymbolicLink status)) (die "catalog signing secret must be a regular non-symlink file")
  unless (fileMode status .&. 0o077 == 0) (die "catalog signing secret permissions must exclude group and other access")
  unless (fileSize status == 32) (die "catalog signing secret must contain exactly 32 raw bytes")
  ByteString.readFile path

readConnector :: IO AuthenticatedPack
readConnector = do
  bytes <- ByteString.readFile connectorArchive
  rightOrDie (validatePackArchive bytes >>= authenticatePack)

readPreviousCatalog :: IO (Maybe OfficialPackCatalog)
readPreviousCatalog = do
  let path = catalogDirectory </> "catalog.json"
  doesFileExist path >>= \case
    False -> pure Nothing
    True -> do
      bytes <- ByteString.readFile path
      catalog <- either (die . ((path <> ": ") <>)) pure (eitherDecodeStrict' bytes)
      canonical <- rightOrDie (encodeOfficialPackCatalog catalog)
      unless (bytes == canonical) (die "the previous official catalog is not canonical JCS")
      pure (Just catalog)

validateExistingRoot :: PublicRootDocument -> IO ()
validateExistingRoot expected = do
  let path = catalogDirectory </> "catalog-root.json"
  doesFileExist path >>= \case
    False -> pure ()
    True -> do
      bytes <- ByteString.readFile path
      observed <- either (die . ((path <> ": ") <>)) pure (eitherDecodeStrict' bytes)
      unless
        ( publicRootGeneration observed == publicRootGeneration expected
            && publicRootPublicKey observed == publicRootPublicKey expected
            && publicRootFingerprint observed == publicRootFingerprint expected
        )
        (die "the signing secret does not match the already published catalog root")

encodeBase64 :: ByteString -> Text
encodeBase64 = TextEncoding.decodeUtf8 . Base64Url.encodeUnpadded

rightOrDie :: Either AppError value -> IO value
rightOrDie = either (die . show) pure

cryptoOrDie :: CryptoFailable value -> IO value
cryptoOrDie = \case
  CryptoPassed value -> pure value
  CryptoFailed problem -> die (show problem)

die :: String -> IO value
die message = hPutStrLn stderr message >> fail message

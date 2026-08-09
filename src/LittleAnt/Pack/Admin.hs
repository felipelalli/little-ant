module LittleAnt.Pack.Admin (
  PackInstallDraft (..),
  PackTrustSource (..),
  PackTrustDraft (..),
  PackArchiveCandidate (..),
  PackPublisherKeyDocument (..),
  readPackArchiveCandidate,
  readPackPublisherKeyDocument,
  encodePackPublisherKeyDocument,
)
where

import Control.Exception (IOException, displayException, finally, try)
import Control.Monad (unless, void)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Pack.Format
import LittleAnt.Pack.Trust
import LittleAnt.Store (sha256Hex)
import System.Directory (makeAbsolute)
import System.FilePath (normalise)
import System.IO (hClose)
import System.Posix.Files (deviceID, fileID, fileSize, getFdStatus, getSymbolicLinkStatus, isRegularFile, isSymbolicLink)
import System.Posix.IO (OpenMode (ReadOnly), cloexec, closeFd, defaultFileFlags, fdToHandle, nofollow, openFd)
import System.Posix.Types (Fd, FileOffset)

data PackInstallDraft = PackInstallDraft
  { packInstallSourcePath :: FilePath
  , packInstallSourceSha256 :: Text
  , packInstallArtifact :: PackArtifactIdentity
  , packInstallSignerFingerprint :: Text
  , packInstallTrustClass :: Text
  , packInstallEnabledComponents :: [Text]
  , packInstallProfileRevision :: Text
  }
  deriving stock (Eq, Show)

data PackTrustSource
  = StandalonePublisherKey
  | PackArchiveSigner
  deriving stock (Eq, Show)

data PackTrustDraft = PackTrustDraft
  { packTrustSource :: PackTrustSource
  , packTrustSourcePath :: FilePath
  , packTrustSourceSha256 :: Text
  , packTrustPublisher :: TrustedCommunityPublisher
  , packTrustProfileRevision :: Text
  , packTrustReturnToInstall :: Maybe PackInstallDraft
  }
  deriving stock (Eq, Show)

data PackArchiveCandidate = PackArchiveCandidate
  { packCandidateCanonicalPath :: FilePath
  , packCandidateSourceSha256 :: Text
  , packCandidateAuthenticated :: AuthenticatedPack
  }
  deriving stock (Eq, Show)

newtype PackPublisherKeyDocument = PackPublisherKeyDocument
  { publisherKeyTrust :: TrustedCommunityPublisher
  }
  deriving stock (Eq, Show)

readPackArchiveCandidate :: FilePath -> IO (Either AppError PackArchiveCandidate)
readPackArchiveCandidate requested = do
  loaded <- readBoundedRegularFile "Pack archive" maximumPackInputBytes requested
  pure $ do
    (canonicalPath, bytes) <- loaded
    structural <- validatePackArchive bytes
    authenticated <- authenticatePack structural
    pure
      PackArchiveCandidate
        { packCandidateCanonicalPath = canonicalPath
        , packCandidateSourceSha256 = sha256Hex bytes
        , packCandidateAuthenticated = authenticated
        }

readPackPublisherKeyDocument :: FilePath -> IO (Either AppError (FilePath, Text, PackPublisherKeyDocument))
readPackPublisherKeyDocument requested = do
  loaded <- readBoundedRegularFile "Pack publisher key" maximumPublisherKeyBytes requested
  pure $ do
    (canonicalPath, bytes) <- loaded
    value <-
      either
        (\problem -> Left (keyProblem CorruptData "The Pack publisher key is not valid UTF-8 JSON." [Text.pack problem]))
        Right
        (eitherDecodeStrict' bytes)
    canonical <- canonicalJsonBytes value
    unless
      (canonical == bytes)
      (Left (keyProblem CorruptData "The Pack publisher key is not RFC 8785 canonical JSON." []))
    document <-
      either
        (\problem -> Left (keyProblem CorruptData "The Pack publisher key does not match little-ant/pack-publisher-key@1." [Text.pack problem]))
        Right
        (parseEither parseJSON value)
    pure (canonicalPath, sha256Hex bytes, document)

encodePackPublisherKeyDocument :: PackPublisherKeyDocument -> Either AppError ByteString
encodePackPublisherKeyDocument = canonicalJsonBytes . toJSON

instance ToJSON PackInstallDraft where
  toJSON draft =
    object
      [ "source_path" .= packInstallSourcePath draft
      , "source_sha256" .= packInstallSourceSha256 draft
      , "artifact" .= packInstallArtifact draft
      , "signer_fingerprint" .= packInstallSignerFingerprint draft
      , "trust_class" .= packInstallTrustClass draft
      , "enabled_components" .= packInstallEnabledComponents draft
      , "profile_revision" .= packInstallProfileRevision draft
      ]

instance FromJSON PackInstallDraft where
  parseJSON = withObject "PackInstallDraft" $ \fields -> do
    rejectUnknown fields ["source_path", "source_sha256", "artifact", "signer_fingerprint", "trust_class", "enabled_components", "profile_revision"]
    PackInstallDraft
      <$> fields .: "source_path"
      <*> fields .: "source_sha256"
      <*> fields .: "artifact"
      <*> fields .: "signer_fingerprint"
      <*> fields .: "trust_class"
      <*> fields .: "enabled_components"
      <*> fields .: "profile_revision"

instance ToJSON PackTrustSource where
  toJSON =
    String . \case
      StandalonePublisherKey -> "publisher_key"
      PackArchiveSigner -> "pack_archive"

instance FromJSON PackTrustSource where
  parseJSON = withText "PackTrustSource" $ \case
    "publisher_key" -> pure StandalonePublisherKey
    "pack_archive" -> pure PackArchiveSigner
    other -> fail ("unknown Pack trust source: " <> Text.unpack other)

instance ToJSON PackTrustDraft where
  toJSON draft =
    object $
      [ "source" .= packTrustSource draft
      , "source_path" .= packTrustSourcePath draft
      , "source_sha256" .= packTrustSourceSha256 draft
      , "publisher" .= packTrustPublisher draft
      , "profile_revision" .= packTrustProfileRevision draft
      ]
        <> maybe [] (pure . ("return_to_install" .=)) (packTrustReturnToInstall draft)

instance FromJSON PackTrustDraft where
  parseJSON = withObject "PackTrustDraft" $ \fields -> do
    rejectUnknown fields ["source", "source_path", "source_sha256", "publisher", "profile_revision", "return_to_install"]
    PackTrustDraft
      <$> fields .: "source"
      <*> fields .: "source_path"
      <*> fields .: "source_sha256"
      <*> fields .: "publisher"
      <*> fields .: "profile_revision"
      <*> fields .:? "return_to_install"

instance ToJSON PackPublisherKeyDocument where
  toJSON document =
    let publisher = publisherKeyTrust document
     in object
          [ "schema" .= ("little-ant/pack-publisher-key@1" :: Text)
          , "publisher" .= communityPublisher publisher
          , "public_key" .= communityPublicKey publisher
          , "key_fingerprint" .= communityKeyFingerprint publisher
          ]

instance FromJSON PackPublisherKeyDocument where
  parseJSON = withObject "PackPublisherKeyDocument" $ \fields -> do
    rejectUnknown fields ["schema", "publisher", "public_key", "key_fingerprint"]
    schema <- fields .: "schema"
    unless (schema == ("little-ant/pack-publisher-key@1" :: Text)) (fail "unsupported Pack publisher-key schema")
    publisher <-
      TrustedCommunityPublisher
        <$> fields .: "publisher"
        <*> fields .: "public_key"
        <*> fields .: "key_fingerprint"
    either (fail . Text.unpack . appErrorMessage) (const (pure (PackPublisherKeyDocument publisher))) (validateTrustedCommunityPublisher publisher)

readBoundedRegularFile :: Text -> FileOffset -> FilePath -> IO (Either AppError (FilePath, ByteString))
readBoundedRegularFile label maximumBytes requested = do
  absolute <- makeAbsolute requested
  let path = normalise absolute
  inspected <- try (getSymbolicLinkStatus path)
  case inspected of
    Left problem -> pure (Left (readProblem label path problem))
    Right initial
      | isSymbolicLink initial -> pure (Left (inputProblem PreconditionFailed label path "The selected path cannot be a symbolic link."))
      | not (isRegularFile initial) -> pure (Left (inputProblem PreconditionFailed label path "The selected path must be one regular file."))
      | fileSize initial > maximumBytes -> pure (Left (tooLargeProblem label path maximumBytes))
      | otherwise ->
          try (openFd path ReadOnly defaultFileFlags{nofollow = True, cloexec = True}) >>= \case
            Left problem -> pure (Left (readProblem label path problem))
            Right descriptor ->
              try (getFdStatus descriptor) >>= \case
                Left problem -> closeQuietly descriptor >> pure (Left (readProblem label path problem))
                Right opened
                  | not (isRegularFile opened) -> closeQuietly descriptor >> pure (Left (inputProblem PreconditionFailed label path "The selected path did not remain a regular file while it was opened."))
                  | deviceID opened /= deviceID initial || fileID opened /= fileID initial -> closeQuietly descriptor >> pure (Left (inputProblem Conflict label path "The selected file changed while it was being opened."))
                  | fileSize opened > maximumBytes -> closeQuietly descriptor >> pure (Left (tooLargeProblem label path maximumBytes))
                  | otherwise ->
                      try (fdToHandle descriptor) >>= \case
                        Left problem -> closeQuietly descriptor >> pure (Left (readProblem label path problem))
                        Right handle -> do
                          readResult <- try (ByteString.hGetContents handle `finally` hClose handle)
                          pure $ case readResult of
                            Left problem -> Left (readProblem label path problem)
                            Right bytes
                              | fromIntegral (ByteString.length bytes) > maximumBytes -> Left (tooLargeProblem label path maximumBytes)
                              | otherwise -> Right (path, bytes)

maximumPackInputBytes :: FileOffset
maximumPackInputBytes = 72 * 1024 * 1024

maximumPublisherKeyBytes :: FileOffset
maximumPublisherKeyBytes = 64 * 1024

closeQuietly :: Fd -> IO ()
closeQuietly descriptor = void (try (closeFd descriptor) :: IO (Either IOException ()))

readProblem :: Text -> FilePath -> IOException -> AppError
readProblem label path problem =
  (inputProblem NotFound label path ("The selected file could not be read: " <> Text.pack (displayException problem)))
    { appErrorRetrySafety = RetrySafe
    }

tooLargeProblem :: Text -> FilePath -> FileOffset -> AppError
tooLargeProblem label path maximumBytes =
  (inputProblem PreconditionFailed label path "The selected file exceeds the bounded input limit.")
    { appErrorDetails = ["Maximum bytes: " <> Text.pack (show maximumBytes)]
    }

inputProblem :: ErrorCode -> Text -> FilePath -> Text -> AppError
inputProblem code label path message =
  (appError code message)
    { appErrorSubject = Just label
    , appErrorDetails = [Text.pack path]
    , appErrorRecovery = [RecoveryAction "choose-file" "Choose one readable regular file and retry." Nothing]
    }

keyProblem :: ErrorCode -> Text -> [Text] -> AppError
keyProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRecovery = [RecoveryAction "publisher-key" "Use a canonical little-ant/pack-publisher-key@1 JSON document." Nothing]
    }

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let unknown = filter (`notElem` allowed) (Text.pack . Key.toString <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown fields: " <> Text.unpack (Text.intercalate ", " unknown)))

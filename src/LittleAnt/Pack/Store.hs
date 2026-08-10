module LittleAnt.Pack.Store (
  PackStoreConfig (..),
  StoredPackArtifact (..),
  PackStoreEntry (..),
  packArchivePath,
  listPackStoreEntries,
  removePackStoreEntries,
  withPackStoreLock,
  inspectStoredPack,
  storeAuthorizedPack,
  loadPinnedPack,
)
where

import Control.Exception (IOException, bracketOnError, catch)
import Control.Monad (unless, when)
import Data.Bits ((.&.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Pack.Format
import LittleAnt.Pack.Trust
import LittleAnt.Store (sha256Hex)
import System.Directory hiding (isSymbolicLink)
import System.FileLock (SharedExclusive (Exclusive), withFileLock)
import System.FilePath ((</>))
import System.IO (hClose, hFlush, openBinaryTempFile)
import System.IO.Error (isAlreadyExistsError, isDoesNotExistError)
import System.Posix.Files
import System.Posix.IO (FdOption (CloseOnExec), OpenMode (ReadOnly), closeFd, defaultFileFlags, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)

newtype PackStoreConfig = PackStoreConfig
  { packStoreRoot :: FilePath
  }
  deriving stock (Eq, Show)

data StoredPackArtifact = StoredPackArtifact
  { storedPackPath :: FilePath
  , storedPackArchiveDigest :: Text
  , storedPackManifestDigest :: Text
  , storedPackByteCount :: Integer
  }
  deriving stock (Eq, Show)

data PackStoreEntry = PackStoreEntry
  { packStoreEntryPath :: FilePath
  , packStoreEntryArtifact :: PackArtifactIdentity
  , packStoreEntrySignerFingerprint :: Text
  , packStoreEntryByteCount :: Integer
  }
  deriving stock (Eq, Show)

packArchivePath :: PackStoreConfig -> Text -> FilePath
packArchivePath config digest = packStoreRoot config </> Text.unpack digest <> ".lantpack"

storeAuthorizedPack :: PackStoreConfig -> InstallAuthorizedPack -> IO (Either AppError StoredPackArtifact)
storeAuthorizedPack config authorized = handlePackStoreIo $ do
  let authenticated = installAuthorizedPack authorized
      structural = authenticatedStructuralPack authenticated
      bytes = structurallyValidArchiveBytes structural
      identity = authenticatedPackIdentity authenticated
      digest = artifactArchiveDigest identity
      finalPath = packArchivePath config digest
  unless
    (sha256Hex bytes == digest)
    (ioError (userError "authorized Pack bytes no longer match their archive digest"))
  ensurePackStore config
  bracketOnError
    (openBinaryTempFile (packStoreRoot config) ".lant-pack.tmp")
    (\(temporary, handle) -> catch (hClose handle) ignoreIo >> removeIfPresent temporary)
    ( \(temporary, handle) -> do
        setFileMode temporary 0o600
        ByteString.hPut handle bytes
        hFlush handle
        descriptor <- handleToFd handle
        setFdOption descriptor CloseOnExec True
        fileSynchronise descriptor
        closeFd descriptor
        publish temporary finalPath bytes
        syncDirectory (packStoreRoot config)
    )
  stored <- verifyStoredFile finalPath digest
  unless
    (stored == bytes)
    (ioError (userError "content-addressed Pack collision"))
  pure
    ( Right
        StoredPackArtifact
          { storedPackPath = finalPath
          , storedPackArchiveDigest = digest
          , storedPackManifestDigest = artifactManifestDigest identity
          , storedPackByteCount = fromIntegral (ByteString.length bytes)
          }
    )
 where
  publish temporary finalPath expected =
    catch
      (createLink temporary finalPath >> removeFile temporary)
      (\problem -> if isAlreadyExistsError problem then verifyExisting expected finalPath >> removeFile temporary else ioError problem)
  verifyExisting expected finalPath = do
    observed <- verifyStoredFile finalPath (sha256Hex expected)
    unless (observed == expected) (ioError (userError "content-addressed Pack collision"))

loadPinnedPack :: PackStoreConfig -> UTCTime -> ProfileScope -> PackTrustPolicy -> PackPin -> IO (Either AppError ExecutionAuthorizedPack)
loadPinnedPack config now scope policy pin = handlePackStoreIo $ do
  case validatePackPin pin of
    Left problem -> pure (Left problem)
    Right () -> do
      let digest = artifactArchiveDigest (pinArtifact pin)
          path = packArchivePath config digest
      tryPackStore $ do
        bytes <- verifyStoredFile path digest
        pure $ do
          structural <- validatePackArchive bytes
          authenticated <- authenticatePack structural
          authorizePinnedPackExecution now scope policy pin authenticated

inspectStoredPack :: PackStoreConfig -> Text -> IO (Either AppError AuthenticatedPack)
inspectStoredPack config digest = handlePackStoreIo $ do
  let path = packArchivePath config digest
  tryPackStore $ do
    bytes <- verifyStoredFile path digest
    pure (validatePackArchive bytes >>= authenticatePack)

listPackStoreEntries :: PackStoreConfig -> IO (Either AppError [PackStoreEntry])
listPackStoreEntries config = handlePackStoreIo $ do
  exists <- doesDirectoryExist (packStoreRoot config)
  if not exists
    then pure (Right [])
    else do
      status <- getSymbolicLinkStatus (packStoreRoot config)
      unless (isDirectory status && not (isSymbolicLink status)) (ioError (userError "Pack store root is not a real directory"))
      names <- sort <$> listDirectory (packStoreRoot config)
      entries <- traverse inspectName (filter ((== ".lantpack") . suffix) names)
      pure (sequence entries)
 where
  suffix name = reverse (take 9 (reverse name))
  inspectName name =
    let digest = Text.pack (take (length name - 9) name)
        path = packStoreRoot config </> name
     in if not (validDigest digest)
          then pure . Left $ unsafeStoreEntry path "A Pack archive filename is not one lowercase SHA-256 digest."
          else
            inspectStoredPack config digest >>= \case
              Left problem -> pure (Left problem{appErrorSubject = Just (Text.pack path)})
              Right authenticated -> do
                fileStatus <- getSymbolicLinkStatus path
                let identity = authenticatedPackIdentity authenticated
                pure $
                  if artifactArchiveDigest identity /= digest
                    then Left (unsafeStoreEntry path "A stored Pack identity does not match its content-addressed filename.")
                    else
                      Right
                        PackStoreEntry
                          { packStoreEntryPath = path
                          , packStoreEntryArtifact = identity
                          , packStoreEntrySignerFingerprint = authenticatedSignerFingerprint authenticated
                          , packStoreEntryByteCount = fromIntegral (fileSize fileStatus)
                          }

removePackStoreEntries :: PackStoreConfig -> [PackStoreEntry] -> IO (Either AppError ())
removePackStoreEntries config expected = handlePackStoreIo $ do
  observed <- listPackStoreEntries config
  case observed of
    Left problem -> pure (Left problem)
    Right entries ->
      let byPath = Map.fromList [(packStoreEntryPath entry, entry) | entry <- entries]
       in case mapM_ (verifyExpected byPath) expected of
            Left problem -> pure (Left problem)
            Right () -> do
              mapM_ (removeFile . packStoreEntryPath) expected
              unless (null expected) (syncDirectory (packStoreRoot config))
              pure (Right ())
 where
  verifyExpected observed candidate =
    case Map.lookup (packStoreEntryPath candidate) observed of
      Just current | current == candidate -> Right ()
      _ ->
        Left
          ( (appError Conflict "A Pack archive changed after the garbage-collection preview.")
              { appErrorSubject = Just (Text.pack (packStoreEntryPath candidate))
              , appErrorRetrySafety = RetryAfterRefresh
              , appErrorRecovery = [RecoveryAction "refresh" "Review a freshly computed garbage-collection plan." (Just "lant packs gc")]
              }
          )

withPackStoreLock :: PackStoreConfig -> IO (Either AppError value) -> IO (Either AppError value)
withPackStoreLock config action = handlePackStoreIo $ do
  ensurePackStore config
  let lockPath = packStoreRoot config </> ".store.lock"
  withFileLock lockPath Exclusive $ \_ -> do
    setFileMode lockPath 0o600
    action

ensurePackStore :: PackStoreConfig -> IO ()
ensurePackStore config = do
  createDirectoryIfMissing True (packStoreRoot config)
  status <- getSymbolicLinkStatus (packStoreRoot config)
  unless
    (isDirectory status && not (isSymbolicLink status))
    (ioError (userError "Pack store root is not a real directory"))
  setFileMode (packStoreRoot config) 0o700

verifyStoredFile :: FilePath -> Text -> IO ByteString
verifyStoredFile path expectedDigest = do
  status <-
    catch
      (getSymbolicLinkStatus path)
      (\problem -> if isDoesNotExistError problem then ioError (userError "Pack archive is not present in the content-addressed store") else ioError problem)
  unless
    (isRegularFile status && not (isSymbolicLink status))
    (ioError (userError "Pack archive is not a regular file"))
  unless
    (fileMode status .&. 0o077 == 0)
    (ioError (userError "Pack archive permissions are not private"))
  when
    (fromIntegral (fileSize status) > maxStoredArchiveBytes)
    (ioError (userError "Pack archive exceeds the bounded store read limit"))
  bytes <- ByteString.readFile path
  unless
    (sha256Hex bytes == expectedDigest)
    (ioError (userError "Pack archive content does not match its content-addressed filename"))
  pure bytes

maxStoredArchiveBytes :: Integer
maxStoredArchiveBytes = 72 * 1024 * 1024

validDigest :: Text -> Bool
validDigest digest =
  Text.length digest == 64
    && Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f') digest

unsafeStoreEntry :: FilePath -> Text -> AppError
unsafeStoreEntry path message =
  (appError CorruptData message)
    { appErrorSubject = Just (Text.pack path)
    , appErrorRecovery = [RecoveryAction "diagnose" "Inspect the Pack store without deleting unknown bytes." (Just "lant doctor")]
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

tryPackStore :: IO (Either AppError value) -> IO (Either AppError value)
tryPackStore action = action `catch` recover
 where
  recover :: IOException -> IO (Either AppError value)
  recover problem = pure (Left (packStoreProblem problem))

handlePackStoreIo :: IO (Either AppError value) -> IO (Either AppError value)
handlePackStoreIo = tryPackStore

packStoreProblem :: IOException -> AppError
packStoreProblem problem =
  (appError ExternalFailure "Little Ant could not access the Pack store safely.")
    { appErrorDetails = [Text.pack (show problem)]
    , appErrorRetrySafety = RetrySafe
    }

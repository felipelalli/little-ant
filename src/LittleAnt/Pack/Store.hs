module LittleAnt.Pack.Store (
  PackStoreConfig (..),
  StoredPackArtifact (..),
  packArchivePath,
  storeAuthorizedPack,
  loadPinnedPack,
)
where

import Control.Exception (IOException, bracketOnError, catch)
import Control.Monad (unless, when)
import Data.Bits ((.&.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Pack.Format
import LittleAnt.Pack.Trust
import LittleAnt.Store (sha256Hex)
import System.Directory hiding (isSymbolicLink)
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

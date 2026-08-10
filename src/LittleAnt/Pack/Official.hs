module LittleAnt.Pack.Official (
  OfficialCatalogPayload (..),
  OfficialPackRemote (..),
  compiledOfficialCatalogRoot,
  newOfficialPackRemote,
  cacheOfficialPackArchive,
)
where

import Control.Exception (IOException, bracketOnError, catch, try)
import Control.Monad (unless, when)
import Data.Bits ((.&.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (isDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Pack.Catalog
import LittleAnt.Store (sha256Hex)
import Network.HTTP.Client qualified as Http
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Header qualified as Header
import Network.HTTP.Types.Status (statusCode)
import System.Directory hiding (isSymbolicLink)
import System.FilePath ((</>))
import System.IO (hClose, hFlush, openBinaryTempFile)
import System.IO.Error (isAlreadyExistsError, isDoesNotExistError)
import System.Posix.Files
import System.Posix.IO (FdOption (CloseOnExec), OpenMode (ReadOnly), closeFd, defaultFileFlags, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)

data OfficialCatalogPayload = OfficialCatalogPayload
  { officialCatalogDocumentBytes :: ByteString
  , officialCatalogSignatureBytes :: ByteString
  }

data OfficialPackRemote = OfficialPackRemote
  { fetchOfficialCatalog :: IO (Either AppError OfficialCatalogPayload)
  , fetchOfficialPackArchive :: Text -> IO (Either AppError ByteString)
  }

compiledOfficialCatalogRoot :: Either AppError CatalogRoot
compiledOfficialCatalogRoot =
  catalogRootFromPublicKey
    0
    "VDmoMgvtG1tSN0bEhIz9VQ3lfXGGYQZQIe7jPV-oAk0"

newOfficialPackRemote :: IO OfficialPackRemote
newOfficialPackRemote = do
  manager <- Http.newManager tlsManagerSettings
  pure
    OfficialPackRemote
      { fetchOfficialCatalog = do
          catalog <- fetchBounded manager "official Pack catalog" maximumCatalogBytes (officialBaseUrl <> "catalog.json")
          signature <- fetchBounded manager "official Pack catalog signature" maximumSignatureBytes (officialBaseUrl <> "catalog-signature.json")
          pure (OfficialCatalogPayload <$> catalog <*> signature)
      , fetchOfficialPackArchive = \digest ->
          if validSha256 digest
            then fetchBounded manager "official Pack archive" maximumArchiveBytes (officialBaseUrl <> "releases/" <> Text.unpack digest <> ".lantpack")
            else pure . Left $ officialProblem InvalidInput "An official Pack archive digest must be lowercase SHA-256." [digest]
      }

cacheOfficialPackArchive :: FilePath -> Text -> ByteString -> IO (Either AppError FilePath)
cacheOfficialPackArchive profileStateDirectory expectedDigest bytes
  | not (validSha256 expectedDigest) = pure . Left $ officialProblem InvalidInput "An official Pack archive digest must be lowercase SHA-256." [expectedDigest]
  | sha256Hex bytes /= expectedDigest = pure . Left $ officialProblem CorruptData "The downloaded official Pack does not match its catalog digest." [expectedDigest, sha256Hex bytes]
  | otherwise = handleCacheIo $ do
      let directory = profileStateDirectory </> "pack-downloads"
          finalPath = directory </> Text.unpack expectedDigest <> ".lantpack"
      ensurePrivateDirectory directory
      bracketOnError
        (openBinaryTempFile directory ".lant-download.tmp")
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
            syncDirectory directory
        )
      observed <- verifyCachedArchive finalPath expectedDigest
      unless (observed == bytes) (ioError (userError "content-addressed official Pack cache collision"))
      pure (Right finalPath)
 where
  publish temporary finalPath expected =
    catch
      (createLink temporary finalPath >> removeFile temporary)
      (\problem -> if isAlreadyExistsError problem then verifyExisting expected finalPath >> removeFile temporary else ioError problem)
  verifyExisting expected finalPath = do
    observed <- verifyCachedArchive finalPath (sha256Hex expected)
    unless (observed == expected) (ioError (userError "content-addressed official Pack cache collision"))

officialBaseUrl :: String
officialBaseUrl = "https://raw.githubusercontent.com/felipelalli/little-ant/main/packs/official/"

fetchBounded :: Http.Manager -> Text -> Int -> String -> IO (Either AppError ByteString)
fetchBounded manager label limit url = do
  attempted <- try $ do
    parsed <- Http.parseRequest url
    let request =
          parsed
            { Http.redirectCount = 0
            , Http.responseTimeout = Http.responseTimeoutMicro (15 * 1000000)
            , Http.requestHeaders = [(Header.hUserAgent, "Little-Ant/1.0 official-pack-client")]
            }
    Http.withResponse request manager (readResponse label limit)
  pure $ case attempted of
    Left (_ :: Http.HttpException) -> Left (officialProblem ExternalFailure ("Little Ant could not fetch the " <> label <> ".") ["HTTPS transport failed without exposing provider details."])
    Right result -> result

readResponse :: Text -> Int -> Http.Response Http.BodyReader -> IO (Either AppError ByteString)
readResponse label limit response
  | statusCode (Http.responseStatus response) /= 200 =
      pure . Left $ officialProblem ExternalFailure ("The " <> label <> " endpoint returned an unexpected status.") [Text.pack (show (statusCode (Http.responseStatus response)))]
  | otherwise = readBody 0 []
 where
  readBody count chunks = do
    chunk <- Http.brRead (Http.responseBody response)
    if ByteString.null chunk
      then pure (Right (ByteString.concat (reverse chunks)))
      else do
        let next = count + ByteString.length chunk
        if next > limit
          then pure . Left $ officialProblem PreconditionFailed ("The " <> label <> " exceeds its bounded download size.") [Text.pack (show limit)]
          else readBody next (chunk : chunks)

ensurePrivateDirectory :: FilePath -> IO ()
ensurePrivateDirectory directory = do
  createDirectoryIfMissing True directory
  status <- getSymbolicLinkStatus directory
  unless (isDirectory status && not (isSymbolicLink status)) (ioError (userError "official Pack cache is not a real directory"))
  setFileMode directory 0o700

verifyCachedArchive :: FilePath -> Text -> IO ByteString
verifyCachedArchive path expectedDigest = do
  status <-
    catch
      (getSymbolicLinkStatus path)
      (\problem -> if isDoesNotExistError problem then ioError (userError "official Pack cache entry disappeared") else ioError problem)
  unless (isRegularFile status && not (isSymbolicLink status)) (ioError (userError "official Pack cache entry is not a regular file"))
  unless (fileMode status .&. 0o077 == 0) (ioError (userError "official Pack cache entry permissions are not private"))
  when (fromIntegral (fileSize status) > maximumArchiveBytes) (ioError (userError "official Pack cache entry exceeds its bounded size"))
  bytes <- ByteString.readFile path
  unless (sha256Hex bytes == expectedDigest) (ioError (userError "official Pack cache entry digest mismatch"))
  pure bytes

validSha256 :: Text -> Bool
validSha256 digest = Text.length digest == 64 && Text.all (\character -> isDigit character || character >= 'a' && character <= 'f') digest

handleCacheIo :: IO (Either AppError value) -> IO (Either AppError value)
handleCacheIo action =
  action `catch` \(problem :: IOException) ->
    pure . Left $ officialProblem ExternalFailure "Little Ant could not cache the verified official Pack safely." [Text.pack (show problem)]

syncDirectory :: FilePath -> IO ()
syncDirectory path = do
  descriptor <- openFd path ReadOnly defaultFileFlags
  fileSynchronise descriptor
  closeFd descriptor

removeIfPresent :: FilePath -> IO ()
removeIfPresent path = catch (removeFile path) (\problem -> unless (isDoesNotExistError problem) (ioError problem))

ignoreIo :: IOException -> IO ()
ignoreIo _ = pure ()

officialProblem :: ErrorCode -> Text -> [Text] -> AppError
officialProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRetrySafety = if code == ExternalFailure then RetrySafe else DoNotRetry
    }

maximumCatalogBytes :: Int
maximumCatalogBytes = 1024 * 1024

maximumSignatureBytes :: Int
maximumSignatureBytes = 16 * 1024

maximumArchiveBytes :: Int
maximumArchiveBytes = 72 * 1024 * 1024

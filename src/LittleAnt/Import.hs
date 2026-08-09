module LittleAnt.Import (
  ImportSourceDescriptor (..),
  ImportRead (..),
  ImportPort (..),
  emptyImportPort,
  packRegistryImportPort,
)
where

import Control.Exception (IOException, displayException, finally, try)
import Control.Monad (void)
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (defaultTimeLocale, formatTime)
import LittleAnt.Error
import LittleAnt.Model (SourceMode (..))
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Source
import LittleAnt.TaskJugglerActuals
import System.FilePath (normalise, takeExtension, takeFileName)
import System.IO (hClose)
import System.Posix.Files (fileSize, getFdStatus, getSymbolicLinkStatus, isRegularFile, isSymbolicLink)
import System.Posix.IO (OpenMode (ReadOnly), cloexec, closeFd, defaultFileFlags, fdToHandle, nofollow, openFd)
import System.Posix.Types (FileOffset)

data ImportSourceDescriptor = ImportSourceDescriptor
  { importSourceId :: Text
  , importSourceDisplayName :: Text
  , importSourceExtensions :: [Text]
  , importSourceModes :: [SourceMode]
  }
  deriving stock (Eq, Show)

data ImportRead = ImportRead
  { importReadSourceReference :: Text
  , importReadInput :: SourceInput
  , importReadPreflight :: SourcePreflight
  }
  deriving stock (Eq, Show)

data ImportPort = ImportPort
  { importPortCatalog :: [ImportSourceDescriptor]
  , importPortPreflight :: Text -> SourceMode -> IO (Either AppError ImportRead)
  }

emptyImportPort :: ImportPort
emptyImportPort =
  ImportPort
    []
    (\source _ -> pure . Left $ unavailable source)
 where
  unavailable source =
    (appError Unsupported "No SourceAdapter is available in this host environment.")
      { appErrorSubject = Just source
      , appErrorRecovery = [RecoveryAction "packs" "Inspect the enabled SourceAdapters." (Just "lant packs list")]
      }

packRegistryImportPort :: PackRunnerClient -> PackRegistry -> ImportPort
packRegistryImportPort runner registry =
  ImportPort
    descriptors
    preflight
 where
  preflight source mode = do
    case descriptorFor source of
      Left problem -> pure (Left problem)
      Right descriptor -> do
        selected <- readFileInput descriptor source
        case selected of
          Left problem -> pure (Left problem)
          Right input ->
            case lookupPackComponent (importSourceId descriptor) registry of
              Left problem -> pure (Left problem)
              Right component ->
                invokePackSourcePreflight runner component mode input >>= \case
                  Left problem -> pure (Left problem)
                  Right preview -> pure $ do
                    verifyCoreCustody descriptor input preview
                    Right (ImportRead (normalizedReference source) input preview)
  descriptorFor source =
    let extension = Text.toLower (Text.pack (takeExtension (Text.unpack (Text.strip source))))
        matches = filter (elem extension . importSourceExtensions) descriptors
     in case matches of
          [descriptor] -> Right descriptor
          _ ->
            Left $
              (sourceProblem Unsupported "No enabled file SourceAdapter unambiguously accepts this source path.")
                { appErrorSubject = Just (Text.strip source)
                , appErrorDetails = ["Recognized extensions: " <> Text.intercalate ", " (concatMap importSourceExtensions descriptors)]
                , appErrorRecovery = [RecoveryAction "choose-source" "Choose a source whose format identifies one enabled SourceAdapter." Nothing]
                }
  descriptors =
    [ ImportSourceDescriptor "plain_text" "Plain text file" [".txt", ".text"] [SourceSnapshot, SourceMigrate]
    , ImportSourceDescriptor "taskjuggler_actuals" "TaskJuggler actuals" [".tjp"] [SourceSnapshot]
    ]

readFileInput :: ImportSourceDescriptor -> Text -> IO (Either AppError SourceInput)
readFileInput descriptor source
  | Text.null stripped = pure . Left $ sourceProblem InvalidInput "A file import needs a nonempty source path."
  | extension `notElem` importSourceExtensions descriptor = pure . Left $ sourceProblem Unsupported "The selected SourceAdapter does not accept this file extension."
  | otherwise = do
      inspected <- try (getSymbolicLinkStatus path)
      case inspected of
        Left problem -> pure (Left (readProblem source problem))
        Right status
          | isSymbolicLink status -> pure . Left $ sourceProblem PreconditionFailed "A file import source cannot be a symbolic link."
          | not (isRegularFile status) -> pure . Left $ sourceProblem PreconditionFailed "A file import source must be one regular file."
          | fileSize status > maximumInputBytes ->
              pure . Left $
                (sourceProblem PreconditionFailed "The selected file exceeds the bounded import-input limit.")
                  { appErrorDetails = ["Maximum bytes: " <> Text.pack (show maximumInputBytes)]
                  }
          | otherwise -> do
              loaded <- readOpenedRegularFile source path
              pure $ SourceInput (Text.pack (takeFileName path)) (mediaTypeFor descriptor) <$> loaded
 where
  stripped = Text.strip source
  path = Text.unpack stripped
  extension = Text.toLower (Text.pack (takeExtension path))

mediaTypeFor :: ImportSourceDescriptor -> Text
mediaTypeFor descriptor = case importSourceId descriptor of
  "taskjuggler_actuals" -> "text/x-taskjuggler; charset=utf-8"
  _ -> "text/plain; charset=utf-8"

verifyCoreCustody :: ImportSourceDescriptor -> SourceInput -> SourcePreflight -> Either AppError ()
verifyCoreCustody descriptor input preflight
  | importSourceId descriptor /= "taskjuggler_actuals" = Right ()
  | otherwise = do
      actuals <- parseTaskJugglerActuals (sourceInputBytes input)
      let identity = observedIdentity (sourcePreflightObservation preflight)
          expected =
            Map.fromList
              [ ("planning_manifest_sha256", actualsManifestDigest actuals)
              , ("actuals_as_of", Text.pack (formatTime defaultTimeLocale "%Y-%m-%d-%H:%MZ" (actualsAsOf actuals)))
              , ("actual_record_count", Text.pack (show (length (actualsRecords actuals))))
              ]
      if expected == identity
        then Right ()
        else
          Left
            ( (sourceProblem CorruptData "The TaskJuggler SourceAdapter observation disagrees with the core custody parser.")
                { appErrorDetails = ["Expected: " <> Text.pack (show expected), "Observed: " <> Text.pack (show identity)]
                }
            )

normalizedReference :: Text -> Text
normalizedReference = Text.pack . normalise . Text.unpack . Text.strip

maximumInputBytes :: FileOffset
maximumInputBytes = 64 * 1024 * 1024

readOpenedRegularFile :: Text -> FilePath -> IO (Either AppError ByteString.ByteString)
readOpenedRegularFile source path =
  try (openFd path ReadOnly defaultFileFlags{nofollow = True, cloexec = True}) >>= \case
    Left problem -> pure (Left (readProblem source problem))
    Right descriptor ->
      try (getFdStatus descriptor) >>= \case
        Left problem -> closeQuietly descriptor >> pure (Left (readProblem source problem))
        Right status
          | not (isRegularFile status) -> closeQuietly descriptor >> pure (Left (sourceProblem PreconditionFailed "A file import source must remain one regular file while it is opened."))
          | fileSize status > maximumInputBytes -> closeQuietly descriptor >> pure (Left tooLarge)
          | otherwise ->
              try (fdToHandle descriptor) >>= \case
                Left problem -> closeQuietly descriptor >> pure (Left (readProblem source problem))
                Right handle -> do
                  loaded <- try (ByteString.hGetContents handle `finally` hClose handle)
                  pure $ case loaded of
                    Left problem -> Left (readProblem source problem)
                    Right bytes
                      | fromIntegral (ByteString.length bytes) > maximumInputBytes -> Left tooLarge
                      | otherwise -> Right bytes
 where
  tooLarge =
    (sourceProblem PreconditionFailed "The selected file exceeds the bounded import-input limit.")
      { appErrorDetails = ["Maximum bytes: " <> Text.pack (show maximumInputBytes)]
      }
  closeQuietly descriptor = void (try (closeFd descriptor) :: IO (Either IOException ()))

readProblem :: Text -> IOException -> AppError
readProblem source problem =
  (sourceProblem NotFound "The selected import source could not be read.")
    { appErrorSubject = Just (Text.strip source)
    , appErrorDetails = [Text.pack (displayException problem)]
    }

sourceProblem :: ErrorCode -> Text -> AppError
sourceProblem code message =
  (appError code message)
    { appErrorRecovery = [RecoveryAction "choose-source" "Choose one readable regular source file and try again." Nothing]
    }

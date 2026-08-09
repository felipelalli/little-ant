module LittleAnt.Import (
  ImportSourceDescriptor (..),
  ImportRead (..),
  ImportPort (..),
  emptyImportPort,
  packRegistryImportPort,
)
where

import Control.Exception (IOException, displayException, try)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Model (SourceMode (..))
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Source
import System.FilePath (normalise, takeExtension, takeFileName)
import System.Posix.Files (fileSize, getSymbolicLinkStatus, isRegularFile, isSymbolicLink)
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
    [ImportSourceDescriptor "plain_text" "Plain text file" [".txt", ".text"] [SourceSnapshot, SourceMigrate]]
    preflight
 where
  preflight source mode = do
    selected <- readPlainTextInput source
    case selected of
      Left problem -> pure (Left problem)
      Right input ->
        case lookupPackComponent "plain_text" registry of
          Left problem -> pure (Left problem)
          Right component ->
            invokePackSourcePreflight runner component mode input >>= \case
              Left problem -> pure (Left problem)
              Right preview -> pure (Right (ImportRead (normalizedReference source) input preview))

readPlainTextInput :: Text -> IO (Either AppError SourceInput)
readPlainTextInput source
  | Text.null stripped = pure . Left $ sourceProblem InvalidInput "A file import needs a nonempty source path."
  | extension `notElem` [".txt", ".text"] =
      pure . Left $
        (sourceProblem Unsupported "No enabled file SourceAdapter unambiguously accepts this source path.")
          { appErrorSubject = Just stripped
          , appErrorDetails = ["The current standard boundary recognizes .txt and .text as plain text."]
          , appErrorRecovery = [RecoveryAction "choose-source" "Choose a source whose format identifies one enabled SourceAdapter." Nothing]
          }
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
              loaded <- try (ByteString.readFile path)
              pure $ case loaded of
                Left problem -> Left (readProblem source problem)
                Right bytes -> Right (SourceInput (Text.pack (takeFileName path)) "text/plain; charset=utf-8" bytes)
 where
  stripped = Text.strip source
  path = Text.unpack stripped
  extension = Text.toLower (Text.pack (takeExtension path))

normalizedReference :: Text -> Text
normalizedReference = Text.pack . normalise . Text.unpack . Text.strip

maximumInputBytes :: FileOffset
maximumInputBytes = 64 * 1024 * 1024

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

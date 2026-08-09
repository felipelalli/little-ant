module LittleAnt.Store (
  DatasetDiagnosis (..),
  DatasetCursor (..),
  LoadedDataset (..),
  StoreConfig (..),
  appendCommand,
  cursorHash,
  diagnoseDataset,
  encodeSegment,
  genesisCursor,
  initializeDataset,
  loadDataset,
  renderCursor,
  segmentFileName,
  sha256Hex,
)
where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, bracketOnError, catch, finally)
import Control.Monad (foldM, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (FromJSON (..), ToJSON (..), withText)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base16 qualified as Base16
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import GHC.Clock (getMonotonicTimeNSec)
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Id (renderUUIDv7)
import LittleAnt.Model
import System.Directory
import System.FileLock
import System.FilePath (takeExtension, (</>))
import System.IO (IOMode (WriteMode), hFlush, openBinaryFile)
import System.Posix.Files (setFileMode)
import System.Posix.IO (FdOption (CloseOnExec), OpenMode (ReadOnly), closeFd, defaultFileFlags, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)
import Text.Read (readMaybe)

data DatasetCursor = Genesis | DatasetCursor Integer Text
  deriving stock (Eq, Ord, Show)

data LoadedDataset = LoadedDataset
  { loadedState :: State
  , loadedCursor :: DatasetCursor
  , loadedEventCount :: Integer
  }
  deriving stock (Eq, Show)

data DatasetDiagnosis = DatasetDiagnosis
  { diagnosedDataset :: LoadedDataset
  , diagnosisProblem :: Maybe AppError
  }
  deriving stock (Eq, Show)
instance ToJSON DatasetCursor where
  toJSON = toJSON . renderCursor

instance FromJSON DatasetCursor where
  parseJSON = withText "DatasetCursor" $ \text -> case text of
    "genesis" -> pure Genesis
    _ -> case Text.splitOn ":" text of
      [sequenceText, digest]
        | [(sequenceNumber, "")] <- reads (Text.unpack sequenceText)
        , sequenceNumber > (0 :: Integer)
        , Text.length digest == 64 ->
            pure (DatasetCursor sequenceNumber digest)
      _ -> fail "invalid dataset cursor"

data StoreConfig = StoreConfig
  { storeRoot :: FilePath
  , storeLockTimeoutMicros :: Int
  , storeLockPollMicros :: Int
  }
  deriving stock (Eq, Show)

genesisCursor :: DatasetCursor
genesisCursor = Genesis

renderCursor :: DatasetCursor -> Text
renderCursor = \case
  Genesis -> "genesis"
  DatasetCursor sequenceNumber digest ->
    Text.justifyRight 20 '0' (Text.pack (show sequenceNumber)) <> ":" <> digest

cursorHash :: DatasetCursor -> Text
cursorHash = \case Genesis -> "genesis"; DatasetCursor _ digest -> digest

sha256Hex :: ByteString -> Text
sha256Hex = Text.decodeUtf8 . Base16.encode . SHA256.hash

eventsDirectory :: StoreConfig -> FilePath
eventsDirectory config = storeRoot config </> "events"

initializeDataset :: StoreConfig -> IO ()
initializeDataset config = do
  let directories =
        [ storeRoot config
        , eventsDirectory config
        , storeRoot config </> "blobs"
        , storeRoot config </> "checkpoints"
        , storeRoot config </> "projections"
        ]
  mapM_ (createDirectoryIfMissing True) directories
  mapM_ (`setFileMode` 0o700) directories

loadDataset :: StoreConfig -> (Integer -> IO ()) -> IO (Either AppError LoadedDataset)
loadDataset config progress =
  diagnoseDataset config progress >>= \case
    Left problem -> pure (Left problem)
    Right diagnosis ->
      pure $ case diagnosisProblem diagnosis of
        Nothing -> Right (diagnosedDataset diagnosis)
        Just problem -> Left problem

diagnoseDataset :: StoreConfig -> (Integer -> IO ()) -> IO (Either AppError DatasetDiagnosis)
diagnoseDataset config progress = handleIo $ do
  exists <- doesDirectoryExist (eventsDirectory config)
  if not exists
    then pure (Right (healthyDiagnosis (LoadedDataset emptyState Genesis 0)))
    else do
      names <- sort <$> listDirectory (eventsDirectory config)
      let accepted = filter (not . Text.isPrefixOf "." . Text.pack) names
          alien = filter ((/= ".jsonl") . takeExtension) accepted
      if not (null alien)
        then
          pure . Right $
            failedDiagnosis
              (LoadedDataset emptyState Genesis 0)
              ( (appError CorruptData "The events directory contains an unrecognized canonical file.")
                  { appErrorDetails = fmap Text.pack alien
                  }
              )
        else replayFiles accepted
 where
  replayFiles = go 1 Genesis emptyState 0
  go _ cursor state count [] = pure (Right (healthyDiagnosis (LoadedDataset state cursor count)))
  go expected cursor state count (name : rest) = do
    bytes <- ByteString.readFile (eventsDirectory config </> name)
    case validateSegment expected cursor name bytes state of
      Left problem ->
        pure . Right $
          failedDiagnosis
            (LoadedDataset state cursor count)
            problem
              { appErrorDetails =
                  appErrorDetails problem
                    <> ["valid_event_count: " <> Text.pack (show count)]
              }
      Right (nextState, nextCursor, events) -> do
        let counts = [count + 1 .. count + fromIntegral (length events)]
        mapM_ progress counts
        go (expected + 1) nextCursor nextState (count + fromIntegral (length events)) rest

healthyDiagnosis :: LoadedDataset -> DatasetDiagnosis
healthyDiagnosis dataset = DatasetDiagnosis dataset Nothing

failedDiagnosis :: LoadedDataset -> AppError -> DatasetDiagnosis
failedDiagnosis dataset problem = DatasetDiagnosis dataset (Just problem)

appendCommand :: StoreConfig -> DatasetCursor -> [EventDraft] -> IO (Either AppError LoadedDataset)
appendCommand _ _ [] = pure (Left (appError InvalidInput "A command group must contain at least one event."))
appendCommand config expected drafts@(firstDraft : _)
  | any ((/= firstCommand) . draftCommandId) drafts =
      pure (Left (appError InvalidInput "Every event in a command group must share one command ID."))
  | otherwise = do
      initializeDataset config
      acquired <- acquireWriterLock config
      case acquired of
        Left problem -> pure (Left problem)
        Right lock -> appendWhileLocked `finally` unlockFile lock
 where
  firstCommand = draftCommandId firstDraft
  appendWhileLocked = do
    loaded <- loadDataset config (const (pure ()))
    case loaded of
      Left problem -> pure (Left problem)
      Right current
        | loadedCursor current /= expected ->
            pure . Left $
              (appError Conflict "The dataset changed before this command could be committed.")
                { appErrorCursor = Just (renderCursor (loadedCursor current))
                , appErrorRetrySafety = RetryAfterRefresh
                , appErrorRecovery = [RecoveryAction "refresh" "Reload and retry against current state." Nothing]
                }
        | otherwise -> writeNext current
  writeNext current = do
    let sequenceNumber = case loadedCursor current of
          Genesis -> 1
          DatasetCursor value _ -> value + 1
        (digest, bytes, persisted) = encodeSegment sequenceNumber (cursorHash (loadedCursor current)) drafts
        finalName = segmentFileName sequenceNumber digest
        finalPath = eventsDirectory config </> finalName
        temporaryPath = eventsDirectory config </> ("." <> Text.unpack (renderUUIDv7 firstCommand) <> ".tmp")
    case foldM applyEvent (loadedState current) persisted of
      Left problem -> pure (Left problem)
      Right nextState -> do
        finalExists <- doesPathExist finalPath
        if finalExists
          then pure (Left (appError Conflict "The next canonical segment already exists."))
          else handleIo $ do
            bracketOnError
              (writeDurably temporaryPath bytes)
              (const (removeIfPresent temporaryPath))
              ( const $ do
                  renameFile temporaryPath finalPath
                  syncDirectory (eventsDirectory config)
              )
            let nextCursor = DatasetCursor sequenceNumber digest
            pure . Right $
              LoadedDataset
                nextState
                nextCursor
                (loadedEventCount current + fromIntegral (length persisted))

encodeSegment :: Integer -> Text -> [EventDraft] -> (Text, ByteString, [PersistedEvent])
encodeSegment sequenceNumber previousHash drafts = (sha256Hex bytes, bytes, persisted)
 where
  persisted = zipWith materialize [1 ..] drafts
  materialize eventSequence draft =
    PersistedEvent
      { persistedEventId = draftEventId draft
      , persistedCommandId = draftCommandId draft
      , persistedSegmentSequence = sequenceNumber
      , persistedEventSequence = eventSequence
      , persistedActor = draftActor draft
      , persistedRecordedAt = draftRecordedAt draft
      , persistedPreviousSegmentHash = previousHash
      , persistedPreconditionHash = draftPreconditionHash draft
      , persistedReplayUUIDs = draftReplayUUIDs draft
      , persistedPayload = draftPayload draft
      }
  bytes = ByteString.concat [encodeEvent event <> "\n" | event <- persisted]

segmentFileName :: Integer -> Text -> FilePath
segmentFileName sequenceNumber digest =
  Text.unpack (Text.justifyRight 20 '0' (Text.pack (show sequenceNumber)) <> "-" <> digest <> ".jsonl")

validateSegment ::
  Integer ->
  DatasetCursor ->
  FilePath ->
  ByteString ->
  State ->
  Either AppError (State, DatasetCursor, [PersistedEvent])
validateSegment expected previous name bytes state = do
  (nameSequence, nameHash) <- parseSegmentFileName name
  unless (nameSequence == expected) $ corrupt "The canonical segment sequence is not contiguous."
  unless (sha256Hex bytes == nameHash) $ corrupt "The canonical segment content hash does not match its filename."
  unless (not (ByteString.null bytes) && ByteString.last bytes == 10) $
    corrupt "A canonical JSONL segment must be nonempty and newline-terminated."
  let physicalLines = init (ByteString.split 10 bytes)
      byteOffsets = init (scanl (\offset line -> offset + ByteString.length line + 1) 0 physicalLines)
      indexedLines = zip3 [1 :: Int ..] byteOffsets physicalLines
  when (any ByteString.null physicalLines) $ corrupt "A canonical JSONL segment contains a blank line."
  events <- traverse decodeAt indexedLines
  when (null events) $ corrupt "A command-group segment contains no events."
  let eventSequences = fmap persistedEventSequence events
      commandIds = fmap persistedCommandId events
  unless (eventSequences == [1 .. length events]) $ corrupt "Event sequence within the command group is invalid."
  unless (all ((== nameSequence) . persistedSegmentSequence) events) $
    corrupt "An event declares the wrong segment sequence."
  unless (all ((== cursorHash previous) . persistedPreviousSegmentHash) events) $
    corrupt "The previous-segment hash chain is broken."
  case commandIds of
    firstCommand : otherCommands ->
      unless (all (== firstCommand) otherCommands) $
        corrupt "A segment contains more than one command ID."
    [] -> corrupt "A command-group segment contains no events."
  nextState <- foldM applyAt state (zip indexedLines events)
  pure (nextState, DatasetCursor nameSequence nameHash, events)
 where
  corrupt message =
    Left
      (appError CorruptData message)
        { appErrorSubject = Just (Text.pack name)
        , appErrorCursor = Just (renderCursor previous)
        }
  decodeAt (lineNumber, byteOffset, line) =
    contextualize lineNumber byteOffset (decodeEvent line)
  applyAt current ((lineNumber, byteOffset, _), event) =
    contextualize lineNumber byteOffset (applyEvent current event)
  contextualize lineNumber byteOffset = \case
    Right value -> Right value
    Left problem ->
      Left
        problem
          { appErrorSubject = Just (Text.pack name)
          , appErrorCursor = Just (renderCursor previous)
          , appErrorDetails =
              appErrorDetails problem
                <> [ "physical_line: " <> Text.pack (show lineNumber)
                   , "byte_offset: " <> Text.pack (show byteOffset)
                   ]
          }

parseSegmentFileName :: FilePath -> Either AppError (Integer, Text)
parseSegmentFileName name = case Text.splitOn "-" (Text.pack (take (length name - 6) name)) of
  [sequenceText, digest]
    | Text.length sequenceText == 20
    , Text.length digest == 64
    , Text.all (`elem` ("0123456789abcdef" :: String)) digest
    , Just sequenceNumber <- readMaybe (Text.unpack sequenceText) ->
        Right (sequenceNumber, digest)
  _ ->
    Left
      (appError CorruptData "A canonical segment filename is invalid.")
        { appErrorSubject = Just (Text.pack name)
        }

acquireWriterLock :: StoreConfig -> IO (Either AppError FileLock)
acquireWriterLock config = do
  started <- getMonotonicTimeNSec
  let timeoutNanos = fromIntegral (storeLockTimeoutMicros config) * 1000
      loop = do
        candidate <- tryLockFile (storeRoot config </> ".writer.lock") Exclusive
        case candidate of
          Just lock -> pure (Right lock)
          Nothing -> do
            now <- getMonotonicTimeNSec
            if now - started >= timeoutNanos
              then
                pure . Left $
                  (appError Conflict "Another Little Ant writer is still using this dataset.")
                    { appErrorRetrySafety = RetrySafe
                    , appErrorRecovery = [RecoveryAction "retry" "Retry after the other command finishes." Nothing]
                    }
              else threadDelay (max 1000 (storeLockPollMicros config)) >> loop
  loop

writeDurably :: FilePath -> ByteString -> IO ()
writeDurably path bytes = do
  handle <- openBinaryFile path WriteMode
  ByteString.hPut handle bytes
  hFlush handle
  descriptor <- handleToFd handle
  setFdOption descriptor CloseOnExec True
  fileSynchronise descriptor
  closeFd descriptor
  setFileMode path 0o600

syncDirectory :: FilePath -> IO ()
syncDirectory path = do
  descriptor <- openFd path ReadOnly defaultFileFlags
  fileSynchronise descriptor
  closeFd descriptor

removeIfPresent :: FilePath -> IO ()
removeIfPresent path = do
  exists <- doesFileExist path
  when exists (removeFile path)

handleIo :: IO (Either AppError value) -> IO (Either AppError value)
handleIo action = action `catch` recover
 where
  recover :: IOException -> IO (Either AppError value)
  recover exception =
    pure . Left $
      (appError ExternalFailure "Little Ant could not access the dataset safely.")
        { appErrorDetails = [Text.pack (show exception)]
        , appErrorRetrySafety = RetrySafe
        }

module LittleAnt.Store (
  DatasetDiagnosis (..),
  DatasetCursor (..),
  LoadedDataset (..),
  StoreConfig (..),
  appendCommand,
  canonicalSegmentFiles,
  compactDataset,
  cursorHash,
  diagnoseDataset,
  encodeSegment,
  genesisCursor,
  initializeDataset,
  loadDataset,
  loadDatasetFull,
  readCanonicalEvents,
  renderCursor,
  segmentFileName,
  sha256Hex,
)
where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, bracketOnError, catch, finally)
import Control.Monad (filterM, foldM, unless, void, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (FromJSON (..), ToJSON (..), Value, eitherDecodeStrict', encode, object, withObject, withText, (.:), (.=))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base16 qualified as Base16
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Functor ((<&>))
import Data.IORef
import Data.List (groupBy, sort, sortOn)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (toGregorian, utctDay)
import GHC.Clock (getMonotonicTimeNSec)
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Id (renderUUIDv7)
import LittleAnt.Model
import LittleAnt.Store.Codec
import System.Directory
import System.FileLock
import System.FilePath (makeRelative, takeDirectory, takeExtension, takeFileName, (</>))
import System.IO (IOMode (WriteMode), hFlush, openBinaryFile)
import System.IO.Error (isDoesNotExistError)
import System.Posix.Files (setFileMode)
import System.Posix.Files qualified as Posix
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

-- A snapshot is a private, disposable fold cache. The payload uses the typed
-- versioned binary State codec, not the canonical event format. Incompatible model
-- changes, bad checksums, or missing caches fall back to full canonical replay.
newtype FoldSnapshot = FoldSnapshot LoadedDataset

snapshotPayload :: LoadedDataset -> Value
snapshotPayload dataset =
  object
    [ "schema" .= ("little-ant/fold-snapshot@1" :: Text)
    , "state_format" .= ("little-ant/fold-state-binary@6" :: Text)
    , "cursor" .= loadedCursor dataset
    , "event_count" .= loadedEventCount dataset
    , "state" .= Text.decodeUtf8 (Base16.encode (encodeFoldState (loadedState dataset)))
    ]

instance ToJSON FoldSnapshot where
  toJSON (FoldSnapshot dataset) =
    object ["payload" .= snapshotPayload dataset, "sha256" .= sha256Hex (LazyByteString.toStrict (encode (snapshotPayload dataset)))]

instance FromJSON FoldSnapshot where
  parseJSON = withObject "FoldSnapshot" $ \value -> do
    payload <- value .: "payload"
    digest <- value .: "sha256"
    unless (sha256Hex (LazyByteString.toStrict (encode payload)) == digest) (fail "snapshot checksum mismatch")
    withObject
      "fold payload"
      ( \fields -> do
          schema <- fields .: "schema"
          format <- fields .: "state_format"
          unless (schema == ("little-ant/fold-snapshot@1" :: Text) && format == ("little-ant/fold-state-binary@6" :: Text)) (fail "unsupported fold snapshot")
          cursor <- fields .: "cursor"
          count <- fields .: "event_count"
          text <- fields .: "state"
          binary <- either fail pure (Base16.decode (Text.encodeUtf8 text))
          state <- either (fail . Text.unpack) pure (decodeFoldState binary)
          unless (count == stateEventCount state && count >= cursorSequence cursor) (fail "inconsistent fold count")
          unless (cursor /= Genesis || state == emptyState) (fail "inconsistent genesis snapshot")
          pure (FoldSnapshot (LoadedDataset state cursor count))
      )
      payload

snapshotPath :: StoreConfig -> FilePath
snapshotPath config = storeRoot config </> "projections" </> "fold-snapshot.json"

cursorSequence :: DatasetCursor -> Integer
cursorSequence = \case Genesis -> 0; DatasetCursor sequenceNumber _ -> sequenceNumber

readSnapshot :: StoreConfig -> IO (Maybe LoadedDataset)
readSnapshot config =
  ( do
      bytes <- ByteString.readFile (snapshotPath config)
      case eitherDecodeStrict' bytes of
        Left _ -> pure Nothing
        Right (FoldSnapshot dataset) -> case loadedCursor dataset of
          Genesis -> pure (Just dataset)
          DatasetCursor sequenceNumber digest -> do
            let name = segmentFileName sequenceNumber digest
            hot <- doesFileExist (eventsDirectory config </> name)
            if hot
              then pure (Just dataset)
              else do
                quarters <- archiveDirectories config
                present <- case quarters of
                  Left _ -> pure False
                  Right directories -> or <$> traverse (doesFileExist . (</> name)) directories
                pure (if present then Just dataset else Nothing)
  )
    `catch` (\(_ :: IOException) -> pure Nothing)

snapshotGeneration :: StoreConfig -> IO (Maybe (Integer, Integer, Rational, Integer))
snapshotGeneration config =
  ( do
      status <- Posix.getSymbolicLinkStatus (snapshotPath config)
      pure (Just (fromIntegral (Posix.deviceID status), fromIntegral (Posix.fileID status), toRational (Posix.modificationTimeHiRes status), fromIntegral (Posix.fileSize status)))
  )
    `catch` (\exception -> if isDoesNotExistError exception then pure Nothing else ioError exception)

loadDataset :: StoreConfig -> (Integer -> IO ()) -> IO (Either AppError LoadedDataset)
loadDataset config progress = handleIo $ do
  generation <- snapshotGeneration config
  result <- loadAtSnapshot
  currentGeneration <- snapshotGeneration config
  -- A new cache is published before covered hot paths move. Restart if a
  -- concurrent rotation could have removed part of this cache's hot suffix.
  if generation == currentGeneration then pure result else loadDataset config progress
 where
  loadAtSnapshot = do
    snapshot <- readSnapshot config
    case snapshot of
      Nothing -> loadDatasetFull config progress
      Just base -> do
        listed <- hotSegmentFiles config
        case listed of
          Left problem -> pure (Left problem)
          Right files ->
            case traverse (\path -> (path,) <$> parseSegmentFileName (takeFileName path)) files of
              Left problem -> pure (Left problem)
              Right indexed -> do
                -- Covered files can remain hot after an interrupted rotation.
                -- Inspect their names, but never read cold bytes on a cached boot.
                let cutoff = cursorSequence (loadedCursor base)
                    wrongBoundary = [digest | (_, (sequenceNumber, digest)) <- indexed, sequenceNumber == cutoff, digest /= cursorHash (loadedCursor base)]
                    suffix = [path | (path, (sequenceNumber, _)) <- indexed, sequenceNumber > cutoff]
                if not (null wrongBoundary)
                  then loadDatasetFull config progress
                  else replaySegmentFiles config base progress suffix <&> (>>= diagnosisResult)

loadDatasetFull :: StoreConfig -> (Integer -> IO ()) -> IO (Either AppError LoadedDataset)
loadDatasetFull config progress = diagnoseDataset config progress <&> (>>= diagnosisResult)

readCanonicalEvents :: StoreConfig -> IO (Either AppError [PersistedEvent])
readCanonicalEvents config = handleIo $ do
  chunks <- newIORef []
  canonicalSegmentFiles config >>= \case
    Left problem -> pure (Left problem)
    Right files -> do
      diagnosis <- replaySegments config (LoadedDataset emptyState Genesis 0) (const (pure ())) (\events -> modifyIORef' chunks (events :)) files
      case diagnosis >>= diagnosisResult of
        Left problem -> pure (Left problem)
        Right _ -> Right . concat . reverse <$> readIORef chunks

diagnosisResult :: DatasetDiagnosis -> Either AppError LoadedDataset
diagnosisResult diagnosis = maybe (Right (diagnosedDataset diagnosis)) Left (diagnosisProblem diagnosis)

-- Doctor and repair deliberately bypass the cache and validate all hot/cold
-- bytes, including old event versions and the complete segment hash chain.
diagnoseDataset :: StoreConfig -> (Integer -> IO ()) -> IO (Either AppError DatasetDiagnosis)
diagnoseDataset config progress = handleIo $ do
  files <- canonicalSegmentFiles config
  case files of
    Left problem -> pure (Right (failedDiagnosis (LoadedDataset emptyState Genesis 0) problem))
    Right accepted -> replaySegmentFiles config (LoadedDataset emptyState Genesis 0) progress accepted

replaySegmentFiles :: StoreConfig -> LoadedDataset -> (Integer -> IO ()) -> [FilePath] -> IO (Either AppError DatasetDiagnosis)
replaySegmentFiles config base progress = replaySegments config base progress (const (pure ()))

replaySegments :: StoreConfig -> LoadedDataset -> (Integer -> IO ()) -> ([PersistedEvent] -> IO ()) -> [FilePath] -> IO (Either AppError DatasetDiagnosis)
replaySegments config base progress accepted = go (cursorSequence (loadedCursor base) + 1) base 0
 where
  go _ dataset _ [] = pure (Right (healthyDiagnosis dataset))
  go expected dataset processed (path : rest) = do
    bytes <- readCanonicalSegment config path
    case validateSegment expected (loadedCursor dataset) (takeFileName path) bytes (loadedState dataset) of
      Left problem ->
        pure . Right $
          failedDiagnosis
            dataset
            problem
              { appErrorSubject = Just (segmentSubject config path)
              , appErrorDetails = appErrorDetails problem <> ["valid_event_count: " <> Text.pack (show (loadedEventCount dataset))]
              }
      Right (nextState, nextCursor, events) -> do
        accepted events
        let acceptedCount = fromIntegral (length events)
        mapM_ progress [processed + 1 .. processed + acceptedCount]
        go (expected + 1) (LoadedDataset nextState nextCursor (loadedEventCount dataset + acceptedCount)) (processed + acceptedCount) rest

segmentSubject :: StoreConfig -> FilePath -> Text
segmentSubject config path =
  Text.pack $
    if takeDirectory path == eventsDirectory config then takeFileName path else makeRelative (storeRoot config) path

hotSegmentFiles :: StoreConfig -> IO (Either AppError [FilePath])
hotSegmentFiles config = segmentFilesIn (eventsDirectory config)

segmentFilesIn :: FilePath -> IO (Either AppError [FilePath])
segmentFilesIn directory = do
  exists <- doesDirectoryExist directory
  if not exists
    then pure (Right [])
    else do
      names <- sort . filter (not . Text.isPrefixOf "." . Text.pack) <$> listDirectory directory
      let alien = filter ((/= ".jsonl") . takeExtension) names
      if not (null alien)
        then pure . Left $ (appError CorruptData "The events directory contains an unrecognized canonical file."){appErrorDetails = fmap Text.pack alien}
        else do
          let paths = fmap (directory </>) names
          regular <- traverse regularSegmentPath paths
          pure $ if and regular then Right paths else Left (appError CorruptData "A canonical segment is not a regular file.")

regularSegmentPath :: FilePath -> IO Bool
regularSegmentPath path = (Posix.isRegularFile <$> Posix.getSymbolicLinkStatus path) `catch` recover
 where
  -- A listed hot file may have moved after listing. The reader resolves its
  -- unchanged name in the archive; a genuinely missing file still fails there.
  recover exception
    | isDoesNotExistError exception = pure True
    | otherwise = ioError exception

archiveDirectories :: StoreConfig -> IO (Either AppError [FilePath])
archiveDirectories config = do
  let root = storeRoot config </> "archive"
  exists <- doesDirectoryExist root
  if not exists
    then pure (Right [])
    else do
      names <- sort . filter (not . Text.isPrefixOf "." . Text.pack) <$> listDirectory root
      let valid name = case Text.splitOn "-Q" (Text.pack name) of
            [year, quarter] -> let digits = fromMaybe year (Text.stripPrefix "-" year) in Text.length digits >= 4 && Text.all (`elem` ("0123456789" :: String)) digits && quarter `elem` ["1", "2", "3", "4"]
            _ -> False
      if all valid names
        then do
          let directories = fmap (root </>) names
          regular <- traverse (\path -> ((&&) . not <$> pathIsSymbolicLink path) <*> doesDirectoryExist path) directories
          pure $ if and regular then Right directories else Left (appError CorruptData "A cold quarter is not a regular directory.")
        else pure (Left (appError CorruptData "The cold archive contains an unrecognized quarter."))

-- Returns one canonical path per unchanged command segment. A durable
-- copy-before-unlink rotation can leave two physical copies after a crash;
-- only byte-identical copies may be coalesced.
canonicalSegmentFiles :: StoreConfig -> IO (Either AppError [FilePath])
canonicalSegmentFiles config = handleIo $ do
  hot <- hotSegmentFiles config
  quarters <- archiveDirectories config
  case (hot, quarters) of
    (Right hotFiles, Right directories) -> do
      cold <- traverse segmentFilesIn directories
      case sequence cold of
        Left problem -> pure (Left problem)
        Right coldFiles -> deduplicate (groupBy (\a b -> takeFileName a == takeFileName b) (sortOn takeFileName (hotFiles <> concat coldFiles)))
    (Left problem, _) -> pure (Left problem)
    (_, Left problem) -> pure (Left problem)
 where
  deduplicate [] = pure (Right [])
  deduplicate ([] : rest) = deduplicate rest
  deduplicate ((first : copies) : rest) = do
    identical <-
      if null copies
        then pure True
        else do
          bytes <- readCanonicalSegment config first
          otherBytes <- traverse (readCanonicalSegment config) copies
          pure (all (== bytes) otherBytes)
    if identical
      then fmap (fmap (first :)) (deduplicate rest)
      else pure (Left (appError CorruptData "Hot and cold copies of one canonical segment differ."))

readCanonicalSegment :: StoreConfig -> FilePath -> IO ByteString
readCanonicalSegment config path = ByteString.readFile path `catch` recover
 where
  recover exception
    | isDoesNotExistError exception && takeDirectory path == eventsDirectory config = do
        quarters <- archiveDirectories config
        candidates <- case quarters of Left _ -> pure []; Right directories -> filterM (doesFileExist . (</> takeFileName path)) directories
        case candidates of directory : _ -> ByteString.readFile (directory </> takeFileName path); [] -> ioError exception
    | otherwise = ioError exception

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
            let accepted = LoadedDataset nextState nextCursor (loadedEventCount current + fromIntegral (length persisted))
            snapshot <- readSnapshot config
            when (sequenceNumber - maybe 0 (cursorSequence . loadedCursor) snapshot >= 128) $
              void (handleIo (compactWhileLocked config))
            pure (Right accepted)

-- Compaction changes physical placement only. It never discards canonical
-- events, material, closed cycles, handles, or active/resurrectable identities.
compactDataset :: StoreConfig -> IO (Either AppError LoadedDataset)
compactDataset config = handleIo $ do
  initializeDataset config
  acquired <- acquireWriterLock config
  case acquired of
    Left problem -> pure (Left problem)
    Right lock -> compactWhileLocked config `finally` unlockFile lock

compactWhileLocked :: StoreConfig -> IO (Either AppError LoadedDataset)
compactWhileLocked config =
  loadDatasetFull config (const (pure ())) >>= \case
    Left problem -> pure (Left problem)
    Right dataset -> do
      let path = snapshotPath config
          temporary = path <> ".tmp"
      writeDurably temporary (LazyByteString.toStrict (encode (FoldSnapshot dataset)) <> "\n")
      renameFile temporary path
      syncDirectory (takeDirectory path)
      -- The snapshot is durable before the first hot segment can move.
      hotSegmentFiles config >>= \case
        Left problem -> pure (Left problem)
        Right files -> do
          moved <- foldM (archiveCovered dataset) (Right ()) files
          pure (dataset <$ moved)
 where
  archiveCovered _ (Left problem) _ = pure (Left problem)
  archiveCovered dataset (Right ()) path = case parseSegmentFileName (takeFileName path) of
    Left problem -> pure (Left problem)
    Right (sequenceNumber, _) | sequenceNumber > cursorSequence (loadedCursor dataset) -> pure (Right ())
    Right _ -> do
      bytes <- readCanonicalSegment config path
      case ByteString.split 10 bytes of
        first : _ -> case decodeEvent first of
          Left problem -> pure (Left problem)
          Right event -> do
            let (year, month, _) = toGregorian (utctDay (persistedRecordedAt event))
                yearText = (if year < 0 then "-" else "") <> Text.justifyRight 4 '0' (Text.pack (show (abs year)))
                quarter = Text.unpack yearText <> "-Q" <> show ((month - 1) `div` 3 + 1)
                archiveRoot = storeRoot config </> "archive"
                directory = archiveRoot </> quarter
                destination = directory </> takeFileName path
            createDirectoryIfMissing True directory
            setFileMode archiveRoot 0o700
            setFileMode directory 0o700
            syncDirectory (storeRoot config)
            syncDirectory archiveRoot
            exists <- doesFileExist destination
            if exists
              then do
                cold <- ByteString.readFile destination
                if cold /= bytes
                  then pure (Left (appError CorruptData "An existing cold segment differs from its hot copy."))
                  else finishMove directory path
              else do
                let temporary = directory </> ("." <> takeFileName path <> ".tmp")
                writeDurably temporary bytes
                renameFile temporary destination
                finishMove directory path
        [] -> pure (Left (appError CorruptData "An empty segment cannot be archived."))
  finishMove directory path = do
    syncDirectory directory
    removeFile path
    syncDirectory (eventsDirectory config)
    pure (Right ())

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

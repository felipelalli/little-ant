module LittleAnt.Repair (
  RepairCandidate (..),
  RepairPlan (..),
  buildRepairCandidate,
  planDatasetRepair,
)
where

import Control.Exception (IOException, catch)
import Control.Monad (unless)
import Data.Aeson
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import LittleAnt.Error
import LittleAnt.Store
import System.Directory
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.Posix.Files (setFileMode)

data RepairPlan = RepairPlan
  { repairPlanHash :: Text
  , repairPlanSourceRoot :: FilePath
  , repairPlanSourceCursor :: DatasetCursor
  , repairPlanValidEventCount :: Integer
  , repairPlanProblem :: AppError
  , repairPlanOriginalSegment :: FilePath
  , repairPlanReplacementSegment :: FilePath
  , repairPlanSegmentDigest :: Text
  , repairPlanCandidateRoot :: FilePath
  }
  deriving stock (Eq, Show)

data RepairCandidate = RepairCandidate
  { repairCandidatePlanHash :: Text
  , repairCandidateRoot :: FilePath
  , repairCandidateCursor :: DatasetCursor
  , repairCandidateEventCount :: Integer
  , repairCandidateReceipt :: FilePath
  , repairCandidateReused :: Bool
  }
  deriving stock (Eq, Show)

data RepairReceipt = RepairReceipt
  { receiptPlanHash :: Text
  , receiptSourceRoot :: FilePath
  , receiptSourceCursor :: DatasetCursor
  , receiptOriginalSegment :: FilePath
  , receiptReplacementSegment :: FilePath
  , receiptSegmentDigest :: Text
  , receiptCandidateCursor :: DatasetCursor
  , receiptCandidateEventCount :: Integer
  }
  deriving stock (Eq, Show)

instance ToJSON RepairReceipt where
  toJSON receipt =
    object
      [ "schema" .= ("little-ant/repair-receipt@1" :: Text)
      , "plan_hash" .= receiptPlanHash receipt
      , "source_root" .= receiptSourceRoot receipt
      , "source_cursor" .= receiptSourceCursor receipt
      , "original_segment" .= receiptOriginalSegment receipt
      , "replacement_segment" .= receiptReplacementSegment receipt
      , "segment_digest" .= receiptSegmentDigest receipt
      , "candidate_cursor" .= receiptCandidateCursor receipt
      , "candidate_event_count" .= receiptCandidateEventCount receipt
      ]

instance FromJSON RepairReceipt where
  parseJSON = withObject "repair receipt" $ \value -> do
    schema <- value .: "schema"
    unless (schema == ("little-ant/repair-receipt@1" :: Text)) $ fail "unsupported repair receipt schema"
    RepairReceipt
      <$> value .: "plan_hash"
      <*> value .: "source_root"
      <*> value .: "source_cursor"
      <*> value .: "original_segment"
      <*> value .: "replacement_segment"
      <*> value .: "segment_digest"
      <*> value .: "candidate_cursor"
      <*> value .: "candidate_event_count"

planDatasetRepair :: StoreConfig -> IO (Either AppError RepairPlan)
planDatasetRepair store =
  diagnoseDataset store (const (pure ())) >>= \case
    Left problem -> pure (Left problem)
    Right diagnosis ->
      case diagnosisProblem diagnosis of
        Nothing ->
          pure . Left $
            (appError PreconditionFailed "The dataset is healthy; no repair is needed.")
              { appErrorRecovery = [RecoveryAction "doctor" "Inspect the healthy diagnostic report." (Just "lant doctor")]
              }
        Just problem
          | appErrorMessage problem == segmentHashMismatch -> planFileNameRepair store diagnosis problem
          | otherwise ->
              pure . Left $
                (appError PreconditionFailed "No lossless automatic repair is available for this failure.")
                  { appErrorSubject = appErrorSubject problem
                  , appErrorCursor = appErrorCursor problem
                  , appErrorDetails = ["diagnostic: " <> appErrorMessage problem] <> appErrorDetails problem
                  , appErrorRecovery = [RecoveryAction "doctor" "Inspect the exact failure and provide a verified recovery source." (Just "lant doctor")]
                  }

planFileNameRepair :: StoreConfig -> DatasetDiagnosis -> AppError -> IO (Either AppError RepairPlan)
planFileNameRepair store diagnosis problem =
  case appErrorSubject problem of
    Nothing -> pure (Left (appError CorruptData "The filename repair diagnostic omitted its segment."))
    Just subject
      | takeFileName (Text.unpack subject) /= Text.unpack subject ->
          pure (Left (appError CorruptData "The filename repair diagnostic contains an unsafe path."))
      | otherwise -> handleRepairIo $ do
          let dataset = diagnosedDataset diagnosis
              originalName = Text.unpack subject
              originalPath = storeRoot store </> "events" </> originalName
              sequenceNumber = nextSegmentSequence (loadedCursor dataset)
          bytes <- ByteString.readFile originalPath
          let digest = sha256Hex bytes
              replacementName = segmentFileName sequenceNumber digest
              material =
                Text.intercalate
                  "\n"
                  [ "filename_hash_mismatch@1"
                  , Text.pack (storeRoot store)
                  , renderCursor (loadedCursor dataset)
                  , Text.pack (show (loadedEventCount dataset))
                  , subject
                  , Text.pack replacementName
                  , digest
                  ]
              planHash = sha256Hex (Text.encodeUtf8 material)
              candidateRoot =
                takeDirectory (storeRoot store)
                  </> (takeFileName (storeRoot store) <> ".repair-" <> Text.unpack (Text.take 16 planHash))
          if originalName == replacementName
            then pure (Left (appError CorruptData "The filename repair would make no change."))
            else
              pure . Right $
                RepairPlan
                  planHash
                  (storeRoot store)
                  (loadedCursor dataset)
                  (loadedEventCount dataset)
                  problem
                  originalName
                  replacementName
                  digest
                  candidateRoot

buildRepairCandidate :: StoreConfig -> RepairPlan -> IO (Either AppError RepairCandidate)
buildRepairCandidate store plan = handleRepairIo $ do
  current <- planDatasetRepair store
  case current of
    Left problem -> pure (Left problem)
    Right fresh
      | repairPlanHash fresh /= repairPlanHash plan -> pure (Left stalePlan)
      | otherwise -> do
          exists <- doesPathExist (repairPlanCandidateRoot plan)
          if exists
            then reuseCandidate store plan
            else buildFreshCandidate store plan
 where
  stalePlan =
    (appError Conflict "The authoritative dataset changed after this repair was previewed.")
      { appErrorCursor = Just (renderCursor (repairPlanSourceCursor plan))
      , appErrorRetrySafety = RetryAfterRefresh
      , appErrorRecovery = [RecoveryAction "repair" "Generate and review a fresh repair plan." (Just "lant repair")]
      }

buildFreshCandidate :: StoreConfig -> RepairPlan -> IO (Either AppError RepairCandidate)
buildFreshCandidate source plan = do
  let candidateStore = source{storeRoot = repairPlanCandidateRoot plan}
      candidateEvents = storeRoot candidateStore </> "events"
      originalPath = candidateEvents </> repairPlanOriginalSegment plan
      replacementPath = candidateEvents </> repairPlanReplacementSegment plan
  createDirectory (storeRoot candidateStore)
  initializeDataset candidateStore
  copiedEvents <- copyCanonicalEvents (storeRoot source </> "events") candidateEvents
  case copiedEvents of
    Left problem -> pure (Left problem)
    Right () -> do
      copiedBlobs <- copyTreeIfPresent (storeRoot source </> "blobs") (storeRoot candidateStore </> "blobs")
      case copiedBlobs of
        Left problem -> pure (Left problem)
        Right () -> do
          renameFile originalPath replacementPath
          diagnoseDataset candidateStore (const (pure ())) >>= \case
            Left problem -> pure (Left problem)
            Right diagnosis ->
              case diagnosisProblem diagnosis of
                Just problem ->
                  pure . Left $
                    (appError PreconditionFailed "The repair candidate did not pass full replay.")
                      { appErrorSubject = Just (Text.pack (storeRoot candidateStore))
                      , appErrorCursor = Just (renderCursor (loadedCursor (diagnosedDataset diagnosis)))
                      , appErrorDetails = [appErrorMessage problem] <> appErrorDetails problem
                      , appErrorRecovery = [RecoveryAction "inspect-candidate" "Keep the candidate for inspection; the live dataset is unchanged." Nothing]
                      }
                Nothing -> do
                  let dataset = diagnosedDataset diagnosis
                      receipt = receiptFor plan dataset
                      receiptPath = storeRoot candidateStore </> "repair-receipt.json"
                  LazyByteString.writeFile receiptPath (encode receipt <> "\n")
                  setFileMode receiptPath 0o600
                  pure (Right (candidateFromReceipt candidateStore receiptPath False receipt))

reuseCandidate :: StoreConfig -> RepairPlan -> IO (Either AppError RepairCandidate)
reuseCandidate source plan = do
  let candidateStore = source{storeRoot = repairPlanCandidateRoot plan}
      receiptPath = storeRoot candidateStore </> "repair-receipt.json"
  receiptExists <- doesFileExist receiptPath
  if not receiptExists
    then pure (Left candidateConflict)
    else do
      decoded <- eitherDecode <$> LazyByteString.readFile receiptPath
      case decoded of
        Left problem -> pure (Left candidateConflict{appErrorDetails = [Text.pack problem]})
        Right receipt
          | not (receiptMatchesPlan plan receipt) -> pure (Left candidateConflict)
          | otherwise ->
              diagnoseDataset candidateStore (const (pure ())) >>= \case
                Right diagnosis
                  | Nothing <- diagnosisProblem diagnosis
                  , let dataset = diagnosedDataset diagnosis
                  , loadedCursor dataset == receiptCandidateCursor receipt
                  , loadedEventCount dataset == receiptCandidateEventCount receipt ->
                      pure (Right (candidateFromReceipt candidateStore receiptPath True receipt))
                _ -> pure (Left candidateConflict)
 where
  candidateConflict =
    (appError Conflict "The repair candidate path already exists but is not the verified candidate for this plan.")
      { appErrorSubject = Just (Text.pack (repairPlanCandidateRoot plan))
      , appErrorRecovery = [RecoveryAction "inspect-candidate" "Inspect or move the existing candidate before retrying." Nothing]
      }

copyCanonicalEvents :: FilePath -> FilePath -> IO (Either AppError ())
copyCanonicalEvents source destination = do
  names <- sort <$> listDirectory source
  copyFiles source destination (filter (not . isPrefixOf ".") names)

copyTreeIfPresent :: FilePath -> FilePath -> IO (Either AppError ())
copyTreeIfPresent source destination = do
  exists <- doesDirectoryExist source
  if not exists
    then pure (Right ())
    else do
      names <- sort <$> listDirectory source
      copyEntries names
 where
  copyEntries [] = pure (Right ())
  copyEntries (name : rest) = do
    let sourcePath = source </> name
        destinationPath = destination </> name
    symbolic <- pathIsSymbolicLink sourcePath
    if symbolic
      then pure (Left (unsafeSourcePath sourcePath))
      else do
        directory <- doesDirectoryExist sourcePath
        if directory
          then do
            createDirectory destinationPath
            nested <- copyTreeIfPresent sourcePath destinationPath
            case nested of Left problem -> pure (Left problem); Right () -> copyEntries rest
          else do
            regular <- doesFileExist sourcePath
            if regular
              then copyFile sourcePath destinationPath >> copyEntries rest
              else pure (Left (unsafeSourcePath sourcePath))

copyFiles :: FilePath -> FilePath -> [FilePath] -> IO (Either AppError ())
copyFiles _ _ [] = pure (Right ())
copyFiles source destination (name : rest) = do
  let sourcePath = source </> name
      destinationPath = destination </> name
  symbolic <- pathIsSymbolicLink sourcePath
  regular <- doesFileExist sourcePath
  if symbolic || not regular
    then pure (Left (unsafeSourcePath sourcePath))
    else copyFile sourcePath destinationPath >> copyFiles source destination rest

unsafeSourcePath :: FilePath -> AppError
unsafeSourcePath path =
  (appError CorruptData "A repair source path is not a regular file or directory.")
    { appErrorSubject = Just (Text.pack path)
    }

receiptFor :: RepairPlan -> LoadedDataset -> RepairReceipt
receiptFor plan dataset =
  RepairReceipt
    (repairPlanHash plan)
    (repairPlanSourceRoot plan)
    (repairPlanSourceCursor plan)
    (repairPlanOriginalSegment plan)
    (repairPlanReplacementSegment plan)
    (repairPlanSegmentDigest plan)
    (loadedCursor dataset)
    (loadedEventCount dataset)

candidateFromReceipt :: StoreConfig -> FilePath -> Bool -> RepairReceipt -> RepairCandidate
candidateFromReceipt store receiptPath reused receipt =
  RepairCandidate
    (receiptPlanHash receipt)
    (storeRoot store)
    (receiptCandidateCursor receipt)
    (receiptCandidateEventCount receipt)
    receiptPath
    reused

receiptMatchesPlan :: RepairPlan -> RepairReceipt -> Bool
receiptMatchesPlan plan receipt =
  and
    [ receiptPlanHash receipt == repairPlanHash plan
    , receiptSourceRoot receipt == repairPlanSourceRoot plan
    , receiptSourceCursor receipt == repairPlanSourceCursor plan
    , receiptOriginalSegment receipt == repairPlanOriginalSegment plan
    , receiptReplacementSegment receipt == repairPlanReplacementSegment plan
    , receiptSegmentDigest receipt == repairPlanSegmentDigest plan
    ]

nextSegmentSequence :: DatasetCursor -> Integer
nextSegmentSequence = \case Genesis -> 1; DatasetCursor sequenceNumber _ -> sequenceNumber + 1

segmentHashMismatch :: Text
segmentHashMismatch = "The canonical segment content hash does not match its filename."

handleRepairIo :: IO (Either AppError value) -> IO (Either AppError value)
handleRepairIo action = action `catch` recover
 where
  recover :: IOException -> IO (Either AppError value)
  recover exception =
    pure . Left $
      (appError ExternalFailure "Little Ant could not create or inspect the repair candidate safely.")
        { appErrorDetails = [Text.pack (show exception)]
        , appErrorRetrySafety = RetrySafe
        }

{-# LANGUAGE ForeignFunctionInterface #-}

module LittleAnt.Repair (
  RepairCandidate (..),
  RepairCutoverPlan (..),
  RepairCutoverResult (..),
  RepairPlan (..),
  buildRepairCandidate,
  executeRepairCutover,
  planDatasetRepair,
  planRepairCutover,
  prepareRepairCutoverIntent,
  recoverRepairCutover,
)
where

import Control.Exception (IOException, bracket, catch, try)
import Control.Monad (unless, when)
import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Foreign.C.Error (Errno, eINVAL, eNOSYS, eOPNOTSUPP, errnoToIOError, getErrno)
import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CInt (..), CUInt (..))
import LittleAnt.Error
import LittleAnt.Store
import System.Directory hiding (isSymbolicLink)
import System.FileLock (SharedExclusive (Exclusive), withFileLock)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO (IOMode (WriteMode), hFlush, openBinaryFile)
import System.IO.Error (isDoesNotExistError)
import System.Posix.Files (FileStatus, deviceID, fileID, getFileStatus, getSymbolicLinkStatus, isDirectory, isSymbolicLink, setFileMode)
import System.Posix.IO (FdOption (CloseOnExec), OpenMode (ReadOnly), closeFd, defaultFileFlags, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)

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

data DirectoryIdentity = DirectoryIdentity
  { directoryDevice :: Integer
  , directoryInode :: Integer
  }
  deriving stock (Eq, Show)

data RepairCutoverPlan = RepairCutoverPlan
  { cutoverPlanHash :: Text
  , cutoverRepairPlanHash :: Text
  , cutoverSourceRoot :: FilePath
  , cutoverCandidateRoot :: FilePath
  , cutoverBackupRoot :: FilePath
  , cutoverJournalPath :: FilePath
  , cutoverReceiptPath :: FilePath
  , cutoverSourceIdentity :: DirectoryIdentity
  , cutoverCandidateIdentity :: DirectoryIdentity
  , cutoverCandidateCursor :: DatasetCursor
  , cutoverCandidateEventCount :: Integer
  }
  deriving stock (Eq, Show)

data RepairCutoverResult = RepairCutoverResult
  { cutoverResultPlanHash :: Text
  , cutoverResultCursor :: DatasetCursor
  , cutoverResultEventCount :: Integer
  , cutoverResultBackupRoot :: FilePath
  , cutoverResultReceiptPath :: FilePath
  , cutoverResultRecovered :: Bool
  }
  deriving stock (Eq, Show)

data CutoverJournal = CutoverJournal
  { journalPlan :: RepairCutoverPlan
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

instance ToJSON DirectoryIdentity where
  toJSON identity = object ["device" .= directoryDevice identity, "inode" .= directoryInode identity]

instance FromJSON DirectoryIdentity where
  parseJSON = withObject "directory identity" $ \value -> DirectoryIdentity <$> value .: "device" <*> value .: "inode"

instance ToJSON RepairCutoverPlan where
  toJSON = cutoverPlanValue

instance FromJSON RepairCutoverPlan where
  parseJSON = parseCutoverPlan

instance ToJSON CutoverJournal where
  toJSON journal = object ["schema" .= ("little-ant/repair-cutover-intent@1" :: Text), "plan" .= journalPlan journal]

instance FromJSON CutoverJournal where
  parseJSON = withObject "repair cutover intent" $ \value -> do
    schema <- value .: "schema"
    unless (schema == ("little-ant/repair-cutover-intent@1" :: Text)) $ fail "unsupported repair cutover intent schema"
    CutoverJournal <$> value .: "plan"

cutoverPlanValue :: RepairCutoverPlan -> Value
cutoverPlanValue plan =
  object
    [ "plan_hash" .= cutoverPlanHash plan
    , "repair_plan_hash" .= cutoverRepairPlanHash plan
    , "source_root" .= cutoverSourceRoot plan
    , "candidate_root" .= cutoverCandidateRoot plan
    , "backup_root" .= cutoverBackupRoot plan
    , "journal_path" .= cutoverJournalPath plan
    , "receipt_path" .= cutoverReceiptPath plan
    , "source_identity" .= cutoverSourceIdentity plan
    , "candidate_identity" .= cutoverCandidateIdentity plan
    , "candidate_cursor" .= cutoverCandidateCursor plan
    , "candidate_event_count" .= cutoverCandidateEventCount plan
    ]

parseCutoverPlan :: Value -> Parser RepairCutoverPlan
parseCutoverPlan = withObject "repair cutover plan" $ \value ->
  RepairCutoverPlan
    <$> value .: "plan_hash"
    <*> value .: "repair_plan_hash"
    <*> value .: "source_root"
    <*> value .: "candidate_root"
    <*> value .: "backup_root"
    <*> value .: "journal_path"
    <*> value .: "receipt_path"
    <*> value .: "source_identity"
    <*> value .: "candidate_identity"
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

planRepairCutover :: StoreConfig -> RepairPlan -> RepairCandidate -> IO (Either AppError RepairCutoverPlan)
planRepairCutover store repairPlan candidate = handleRepairIo $ do
  refreshed <- planDatasetRepair store
  case refreshed of
    Left problem -> pure (Left problem)
    Right current
      | repairPlanHash current /= repairPlanHash repairPlan -> pure (Left staleCutoverPlan)
      | repairCandidatePlanHash candidate /= repairPlanHash repairPlan -> pure (Left mismatchedCandidate)
      | repairCandidateRoot candidate /= repairPlanCandidateRoot repairPlan -> pure (Left mismatchedCandidate)
      | otherwise -> do
          verified <- buildRepairCandidate store repairPlan
          case verified of
            Left problem -> pure (Left problem)
            Right currentCandidate
              | repairCandidateCursor currentCandidate /= repairCandidateCursor candidate -> pure (Left mismatchedCandidate)
              | repairCandidateEventCount currentCandidate /= repairCandidateEventCount candidate -> pure (Left mismatchedCandidate)
              | otherwise -> do
                  let sourceRoot = storeRoot store
                      candidateRoot = repairCandidateRoot candidate
                      parent = takeDirectory sourceRoot
                      suffix = Text.unpack (Text.take 16 (repairPlanHash repairPlan))
                      backupRoot = parent </> (takeFileName sourceRoot <> ".backup-" <> suffix)
                      journalPath = parent </> (takeFileName sourceRoot <> ".repair-cutover-" <> suffix <> ".pending.json")
                      receiptPath = parent </> (takeFileName sourceRoot <> ".repair-cutover-" <> suffix <> ".receipt.json")
                  if takeDirectory candidateRoot /= parent || sourceRoot == candidateRoot
                    then pure (Left unsafeCutoverPaths)
                    else do
                      backupExists <- doesPathExist backupRoot
                      if backupExists
                        then pure (Left backupConflict{appErrorSubject = Just (Text.pack backupRoot)})
                        else do
                          identities <- validateCutoverDirectories parent sourceRoot candidateRoot
                          case identities of
                            Left problem -> pure (Left problem)
                            Right (sourceIdentity, candidateIdentity) -> do
                              let planWithoutHash =
                                    RepairCutoverPlan
                                      ""
                                      (repairPlanHash repairPlan)
                                      sourceRoot
                                      candidateRoot
                                      backupRoot
                                      journalPath
                                      receiptPath
                                      sourceIdentity
                                      candidateIdentity
                                      (repairCandidateCursor candidate)
                                      (repairCandidateEventCount candidate)
                              pure . Right $ planWithoutHash{cutoverPlanHash = cutoverPlanDigest planWithoutHash}
 where
  staleCutoverPlan =
    (appError Conflict "The authoritative dataset changed before cutover planning.")
      { appErrorRetrySafety = RetryAfterRefresh
      , appErrorRecovery = [RecoveryAction "repair" "Generate and review a fresh repair plan." (Just "lant repair")]
      }
  mismatchedCandidate =
    (appError Conflict "The candidate does not match the reviewed repair plan.")
      { appErrorRetrySafety = RetryAfterRefresh
      , appErrorRecovery = [RecoveryAction "repair" "Build and validate the candidate again." (Just "lant repair")]
      }
  unsafeCutoverPaths =
    (appError PreconditionFailed "Repair cutover requires distinct sibling dataset directories.")
      { appErrorRecovery = [RecoveryAction "inspect-paths" "Keep live, candidate, and backup paths under one real parent directory." Nothing]
      }
  backupConflict =
    (appError Conflict "The retained backup path already exists.")
      { appErrorRecovery = [RecoveryAction "inspect-backup" "Inspect the existing backup; Little Ant will not overwrite it." Nothing]
      }

executeRepairCutover :: StoreConfig -> RepairCutoverPlan -> IO (Either AppError RepairCutoverResult)
executeRepairCutover store plan = handleRepairIo $
  withFileLock (cutoverLockPath store) Exclusive $ \_ -> do
    valid <- validateSuppliedCutoverPlan store plan
    case valid of
      Left problem -> pure (Left problem)
      Right () -> do
        journalExists <- doesFileExist (cutoverJournalPath plan)
        if journalExists
          then readCutoverJournal (cutoverJournalPath plan) >>= continueExisting
          else do
            prepared <- prepareCutoverIntentUnlocked store plan
            case prepared of
              Left problem -> pure (Left problem)
              Right () -> advanceCutover store False plan
 where
  continueExisting = \case
    Left problem -> pure (Left problem)
    Right journal
      | journalPlan journal /= plan -> pure (Left journalConflict)
      | otherwise -> advanceCutover store True plan
  journalConflict =
    (appError Conflict "The durable cutover intent does not match this consent.")
      { appErrorSubject = Just (Text.pack (cutoverJournalPath plan))
      , appErrorRecovery = [RecoveryAction "doctor" "Inspect the pending cutover before taking further action." (Just "lant doctor")]
      }

recoverRepairCutover :: StoreConfig -> IO (Either AppError (Maybe RepairCutoverResult))
recoverRepairCutover store = handleRepairIo $
  withFileLock (cutoverLockPath store) Exclusive $ \_ -> do
    pending <- pendingCutoverJournals store
    case pending of
      [] -> pure (Right Nothing)
      [path] -> do
        readCutoverJournal path >>= \case
          Left problem -> pure (Left problem)
          Right journal -> do
            valid <- validateSuppliedCutoverPlan store (journalPlan journal)
            case valid of
              Left problem -> pure (Left problem)
              Right () -> fmap Just <$> advanceCutover store True (journalPlan journal)
      paths ->
        pure . Left $
          (appError Conflict "More than one repair cutover is pending for this dataset.")
            { appErrorDetails = fmap Text.pack paths
            , appErrorRecovery = [RecoveryAction "doctor" "Inspect every pending cutover intent before continuing." (Just "lant doctor")]
            }

prepareRepairCutoverIntent :: StoreConfig -> RepairCutoverPlan -> IO (Either AppError ())
prepareRepairCutoverIntent store plan = handleRepairIo $
  withFileLock (cutoverLockPath store) Exclusive $ \_ -> do
    valid <- validateSuppliedCutoverPlan store plan
    case valid of
      Left problem -> pure (Left problem)
      Right () -> do
        exists <- doesFileExist (cutoverJournalPath plan)
        if exists
          then
            readCutoverJournal (cutoverJournalPath plan) >>= \case
              Right journal | journalPlan journal == plan -> pure (Right ())
              Right _ -> pure (Left (appError Conflict "Another cutover intent already occupies this repair path."))
              Left problem -> pure (Left problem)
          else prepareCutoverIntentUnlocked store plan

prepareCutoverIntentUnlocked :: StoreConfig -> RepairCutoverPlan -> IO (Either AppError ())
prepareCutoverIntentUnlocked store plan = do
  prepared <- validateBeforeExchange store plan
  case prepared of
    Left problem -> pure (Left problem)
    Right () -> do
      syncTree (cutoverCandidateRoot plan)
      writeJsonDurably (takeDirectory (cutoverSourceRoot plan)) (cutoverJournalPath plan) (CutoverJournal plan)
      pure (Right ())

advanceCutover :: StoreConfig -> Bool -> RepairCutoverPlan -> IO (Either AppError RepairCutoverResult)
advanceCutover store recovered plan = do
  observed <- observeCutover plan
  case observed of
    CutoverBeforeExchange -> do
      renameExchange (cutoverSourceRoot plan) (cutoverCandidateRoot plan) >>= \case
        Left problem -> pure (Left problem)
        Right () -> do
          syncDirectory (takeDirectory (cutoverSourceRoot plan))
          advanceCutover store recovered plan
    CutoverAfterExchange -> do
      renameNoReplace (cutoverCandidateRoot plan) (cutoverBackupRoot plan) >>= \case
        Left problem -> pure (Left problem)
        Right () -> do
          syncDirectory (takeDirectory (cutoverSourceRoot plan))
          advanceCutover store recovered plan
    CutoverNamesComplete -> finalizeCutover store recovered plan
    CutoverAmbiguous details ->
      pure . Left $
        (appError Conflict "The repair cutover paths no longer match a safely recoverable phase.")
          { appErrorDetails = details
          , appErrorRecovery = [RecoveryAction "doctor" "Inspect directory identities and the durable cutover intent; do not retry blindly." (Just "lant doctor")]
          }

data ObservedCutover
  = CutoverBeforeExchange
  | CutoverAfterExchange
  | CutoverNamesComplete
  | CutoverAmbiguous [Text]

observeCutover :: RepairCutoverPlan -> IO ObservedCutover
observeCutover plan = do
  live <- directoryIdentityMaybe (cutoverSourceRoot plan)
  candidate <- directoryIdentityMaybe (cutoverCandidateRoot plan)
  backup <- directoryIdentityMaybe (cutoverBackupRoot plan)
  pure $
    if live == Just (cutoverSourceIdentity plan) && candidate == Just (cutoverCandidateIdentity plan) && backup == Nothing
      then CutoverBeforeExchange
      else
        if live == Just (cutoverCandidateIdentity plan) && candidate == Just (cutoverSourceIdentity plan) && backup == Nothing
          then CutoverAfterExchange
          else
            if live == Just (cutoverCandidateIdentity plan) && candidate == Nothing && backup == Just (cutoverSourceIdentity plan)
              then CutoverNamesComplete
              else
                CutoverAmbiguous
                  [ "live: " <> maybe "missing" renderDirectoryIdentity live
                  , "candidate: " <> maybe "missing" renderDirectoryIdentity candidate
                  , "backup: " <> maybe "missing" renderDirectoryIdentity backup
                  ]

finalizeCutover :: StoreConfig -> Bool -> RepairCutoverPlan -> IO (Either AppError RepairCutoverResult)
finalizeCutover store recovered plan = do
  let liveStore = store{storeRoot = cutoverSourceRoot plan}
  loadDataset liveStore (const (pure ())) >>= \case
    Left problem -> pure (Left problem)
    Right dataset
      | loadedCursor dataset /= cutoverCandidateCursor plan || loadedEventCount dataset /= cutoverCandidateEventCount plan ->
          pure . Left $
            (appError CorruptData "The live dataset does not reproduce the validated candidate after cutover.")
              { appErrorCursor = Just (renderCursor (loadedCursor dataset))
              , appErrorRecovery = [RecoveryAction "doctor" "Keep both live and backup datasets and inspect the mismatch." (Just "lant doctor")]
              }
      | otherwise -> do
          makeTreeReadOnly (cutoverBackupRoot plan)
          let result =
                RepairCutoverResult
                  (cutoverPlanHash plan)
                  (loadedCursor dataset)
                  (loadedEventCount dataset)
                  (cutoverBackupRoot plan)
                  (cutoverReceiptPath plan)
                  recovered
          writeJsonDurably
            (takeDirectory (cutoverSourceRoot plan))
            (cutoverReceiptPath plan)
            ( object
                [ "schema" .= ("little-ant/repair-cutover-receipt@1" :: Text)
                , "plan" .= plan
                , "result_cursor" .= cutoverResultCursor result
                , "result_event_count" .= cutoverResultEventCount result
                , "backup_read_only" .= True
                ]
            )
          removeFile (cutoverJournalPath plan)
          syncDirectory (takeDirectory (cutoverSourceRoot plan))
          pure (Right result)

validateBeforeExchange :: StoreConfig -> RepairCutoverPlan -> IO (Either AppError ())
validateBeforeExchange store plan = do
  refreshed <- planDatasetRepair store
  case refreshed of
    Left problem -> pure (Left problem)
    Right repairPlan
      | repairPlanHash repairPlan /= cutoverRepairPlanHash plan -> pure (Left staleSource)
      | otherwise -> do
          candidate <- loadDataset store{storeRoot = cutoverCandidateRoot plan} (const (pure ()))
          case candidate of
            Left problem -> pure (Left problem)
            Right dataset
              | loadedCursor dataset /= cutoverCandidateCursor plan || loadedEventCount dataset /= cutoverCandidateEventCount plan -> pure (Left staleCandidate)
              | otherwise -> do
                  observed <- observeCutover plan
                  pure $ case observed of CutoverBeforeExchange -> Right (); _ -> Left identityConflict
 where
  staleSource =
    (appError Conflict "The authoritative dataset changed after cutover consent was prepared.")
      { appErrorRetrySafety = RetryAfterRefresh
      , appErrorRecovery = [RecoveryAction "repair" "Generate and review a fresh repair plan." (Just "lant repair")]
      }
  staleCandidate =
    (appError Conflict "The repair candidate changed after validation.")
      { appErrorRetrySafety = RetryAfterRefresh
      , appErrorRecovery = [RecoveryAction "repair" "Rebuild and validate the candidate." (Just "lant repair")]
      }
  identityConflict =
    (appError Conflict "The live or candidate directory identity changed before cutover.")
      { appErrorRecovery = [RecoveryAction "doctor" "Inspect the cutover paths; no rename was attempted." (Just "lant doctor")]
      }

validateSuppliedCutoverPlan :: StoreConfig -> RepairCutoverPlan -> IO (Either AppError ())
validateSuppliedCutoverPlan store plan = do
  let source = storeRoot store
      parent = takeDirectory source
      suffix = Text.unpack (Text.take 16 (cutoverRepairPlanHash plan))
      expectedCandidate = parent </> (takeFileName source <> ".repair-" <> suffix)
      expectedBackup = parent </> (takeFileName source <> ".backup-" <> suffix)
      expectedJournal = parent </> (takeFileName source <> ".repair-cutover-" <> suffix <> ".pending.json")
      expectedReceipt = parent </> (takeFileName source <> ".repair-cutover-" <> suffix <> ".receipt.json")
  pure $
    if cutoverSourceRoot plan == source
      && cutoverCandidateRoot plan == expectedCandidate
      && cutoverBackupRoot plan == expectedBackup
      && cutoverJournalPath plan == expectedJournal
      && cutoverReceiptPath plan == expectedReceipt
      && cutoverPlanHash plan == cutoverPlanDigest plan
      then Right ()
      else
        Left
          ( (appError CorruptData "A repair cutover intent contains paths outside its dataset boundary.")
              { appErrorSubject = Just (Text.pack (cutoverJournalPath plan))
              }
          )

validateCutoverDirectories :: FilePath -> FilePath -> FilePath -> IO (Either AppError (DirectoryIdentity, DirectoryIdentity))
validateCutoverDirectories parent source candidate = do
  parentStatus <- getFileStatus parent
  sourceStatus <- getSymbolicLinkStatus source
  candidateStatus <- getSymbolicLinkStatus candidate
  pure $
    if any isSymbolicLink [sourceStatus, candidateStatus] || not (all isDirectory [sourceStatus, candidateStatus])
      then Left (appError PreconditionFailed "Repair cutover paths must be real directories, not links.")
      else
        if deviceID sourceStatus /= deviceID parentStatus || deviceID candidateStatus /= deviceID parentStatus
          then Left (appError Unsupported "Atomic repair cutover requires same-filesystem, non-mountpoint siblings.")
          else Right (directoryIdentity sourceStatus, directoryIdentity candidateStatus)

pendingCutoverJournals :: StoreConfig -> IO [FilePath]
pendingCutoverJournals store = do
  let source = storeRoot store
      parent = takeDirectory source
      prefix = takeFileName source <> ".repair-cutover-"
  names <- sort <$> listDirectory parent
  pure [parent </> name | name <- names, prefix `isPrefixOf` name, ".pending.json" `isSuffixOf` name]

readCutoverJournal :: FilePath -> IO (Either AppError CutoverJournal)
readCutoverJournal path = do
  decoded <- eitherDecodeFileStrict' path
  pure $ case decoded of
    Left problem ->
      Left
        ( (appError CorruptData "The durable repair cutover intent is unreadable.")
            { appErrorSubject = Just (Text.pack path)
            , appErrorDetails = [Text.pack problem]
            }
        )
    Right journal -> Right journal

cutoverPlanDigest :: RepairCutoverPlan -> Text
cutoverPlanDigest plan =
  sha256Hex . Text.encodeUtf8 $
    Text.intercalate
      "\n"
      [ "repair_cutover@1"
      , cutoverRepairPlanHash plan
      , Text.pack (cutoverSourceRoot plan)
      , Text.pack (cutoverCandidateRoot plan)
      , Text.pack (cutoverBackupRoot plan)
      , renderDirectoryIdentity (cutoverSourceIdentity plan)
      , renderDirectoryIdentity (cutoverCandidateIdentity plan)
      , renderCursor (cutoverCandidateCursor plan)
      , Text.pack (show (cutoverCandidateEventCount plan))
      ]

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

directoryIdentity :: FileStatus -> DirectoryIdentity
directoryIdentity status = DirectoryIdentity (fromIntegral (deviceID status)) (fromIntegral (fileID status))

directoryIdentityMaybe :: FilePath -> IO (Maybe DirectoryIdentity)
directoryIdentityMaybe path = do
  observed <- try (getSymbolicLinkStatus path) :: IO (Either IOException FileStatus)
  case observed of
    Left problem
      | isDoesNotExistError problem -> pure Nothing
      | otherwise -> ioError problem
    Right status
      | isSymbolicLink status || not (isDirectory status) -> pure Nothing
      | otherwise -> pure (Just (directoryIdentity status))

renderDirectoryIdentity :: DirectoryIdentity -> Text
renderDirectoryIdentity identity = Text.pack (show (directoryDevice identity)) <> ":" <> Text.pack (show (directoryInode identity))

syncTree :: FilePath -> IO ()
syncTree path = do
  status <- getSymbolicLinkStatus path
  when (isSymbolicLink status) (ioError (userError ("refusing to fsync symbolic link: " <> path)))
  if isDirectory status
    then do
      names <- sort <$> listDirectory path
      mapM_ (syncTree . (path </>)) names
      syncDirectory path
    else syncFile path

syncFile :: FilePath -> IO ()
syncFile path = bracket (openFd path ReadOnly defaultFileFlags) closeFd fileSynchronise

syncDirectory :: FilePath -> IO ()
syncDirectory path = bracket (openFd path ReadOnly defaultFileFlags) closeFd fileSynchronise

makeTreeReadOnly :: FilePath -> IO ()
makeTreeReadOnly path = do
  status <- getSymbolicLinkStatus path
  when (isSymbolicLink status) (ioError (userError ("refusing to change symbolic link permissions: " <> path)))
  if isDirectory status
    then do
      names <- sort <$> listDirectory path
      mapM_ (makeTreeReadOnly . (path </>)) names
      setFileMode path 0o500
    else setFileMode path 0o400

writeJsonDurably :: (ToJSON value) => FilePath -> FilePath -> value -> IO ()
writeJsonDurably parent path value = do
  let temporary = path <> ".tmp"
      bytes = LazyByteString.toStrict (encode value <> "\n")
  handle <- openBinaryFile temporary WriteMode
  ByteString.hPut handle bytes
  hFlush handle
  descriptor <- handleToFd handle
  setFdOption descriptor CloseOnExec True
  fileSynchronise descriptor
  closeFd descriptor
  setFileMode temporary 0o600
  renameFile temporary path
  syncDirectory parent

cutoverLockPath :: StoreConfig -> FilePath
cutoverLockPath store = storeRoot store <> ".repair-cutover.lock"

renameExchange :: FilePath -> FilePath -> IO (Either AppError ())
renameExchange = renameWithFlag renameExchangeFlag "exchange"

renameNoReplace :: FilePath -> FilePath -> IO (Either AppError ())
renameNoReplace = renameWithFlag renameNoReplaceFlag "no-replace rename"

renameWithFlag :: CUInt -> Text -> FilePath -> FilePath -> IO (Either AppError ())
renameWithFlag flag operation source destination =
  withCString source $ \sourceName ->
    withCString destination $ \destinationName -> do
      result <- c_renameat2 atCurrentWorkingDirectory sourceName atCurrentWorkingDirectory destinationName flag
      if result == 0
        then pure (Right ())
        else do
          errno <- getErrno
          if errno `elem` unsupportedRenameErrors
            then
              pure . Left $
                (appError Unsupported "This filesystem cannot perform the required atomic repair cutover.")
                  { appErrorDetails = [operation <> " is unsupported by the current filesystem or kernel"]
                  , appErrorRecovery = [RecoveryAction "move-dataset" "Move the dataset to a local filesystem that supports atomic exchange." Nothing]
                  }
            else ioError (errnoToIOError (Text.unpack operation) errno Nothing (Just source))

unsupportedRenameErrors :: [Errno]
unsupportedRenameErrors = [eNOSYS, eINVAL, eOPNOTSUPP]

atCurrentWorkingDirectory :: CInt
atCurrentWorkingDirectory = -100

renameNoReplaceFlag :: CUInt
renameNoReplaceFlag = 1

renameExchangeFlag :: CUInt
renameExchangeFlag = 2

foreign import ccall unsafe "renameat2"
  c_renameat2 :: CInt -> CString -> CInt -> CString -> CUInt -> IO CInt

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

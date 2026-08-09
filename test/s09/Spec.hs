module Main (main) where

import Control.Exception (finally)
import Control.Monad (foldM)
import Data.Aeson (eitherDecode, encode)
import Data.Bits ((.&.))
import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Repair
import LittleAnt.Result
import LittleAnt.Store
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory, renameDirectory, renameFile)
import System.FilePath (takeDirectory, (</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Files (FileStatus, fileMode, getFileStatus, isDirectory, setFileMode)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 Raw revisions and sources"
      [ testCase "Feed creates one immutable initial text revision" initialRevision
      , testCase "English normalization stays on the same Raw revision and retains history" normalizationHistory
      , testCase "an obsolete Raw revision cannot become the current English normalization" obsoleteRevisionRejected
      , testCase "changed and missing source observations never rewrite Raw implicitly" sourceReconciliation
      , testCase "a pending source change blocks another check until explicit reconciliation" pendingChangeBlocksCheck
      , testCase "source reconciliation may preserve changed material as a derived Raw" derivedSourceReconciliation
      , testCase "unrelated source content advances only the accepted source baseline" unrelatedSourceReconciliation
      , testCase "source events round-trip through canonical JSONL" sourceEventRoundTrip
      , testCase "Brick title normalization preserves handle and prior title in event history" brickTitleNormalization
      , testCase "dumb translate previews and accepts one same-Raw normalization" publicRawTranslation
      , testCase "translation skip records nothing and leaves the candidate unresolved" translationSkip
      , testCase "translation queue opportunities round-trip in persisted checkpoints" translationOpportunityRoundTrip
      , testCase "doctor validates a pristine dataset without clock or randomness" pristineDoctor
      , testCase "doctor reports the exact corrupt boundary while ordinary replay stays closed" corruptDoctor
      , testCase "repair builds and reuses a fully replayed candidate without touching authority" losslessRepairCandidate
      , testCase "repair refuses malformed history without creating a candidate" unsupportedRepair
      , testCase "repair rejects a stale plan before creating its candidate" staleRepairPlan
      , testCase "repair cutover atomically promotes the candidate and retains a read-only backup" atomicRepairCutover
      , testCase "repair resumes forward from a durable pre-exchange intent" recoverPreparedCutover
      , testCase "repair resumes forward after the namespace exchange" recoverExchangedCutover
      , testCase "repair dry-run previews without writing repair artifacts" repairDryRun
      , testCase "public repair requires separate build and cutover consent" publicRepairFlow
      ]

initialRevision :: Assertion
initialRevision = do
  (state, raw) <- fedState "comprar leite"
  Map.size (stateRawContentRevisions state) @?= 1
  let revisionId = stateCurrentRawRevisions state Map.! rawId raw
      revision = stateRawContentRevisions state Map.! revisionId
  rawContentRevisionContent revision @?= RawTextContent "comprar leite"
  rawContentRevisionOrdinal revision @?= 1

normalizationHistory :: Assertion
normalizationHistory = do
  (state1, raw) <- fedState "comprar leite"
  let revisionId = stateCurrentRawRevisions state1 Map.! rawId raw
  first <- assertRight (decideAcceptEnglishNormalization state1 actor revisionId "buy milk" HumanNormalization Nothing (Just (Fixed 1000000)) (facts 10 2))
  state2 <- applyMutation state1 first
  second <- assertRight (decideAcceptEnglishNormalization state2 actor revisionId "purchase milk" HumanNormalization Nothing Nothing (facts 20 2))
  state3 <- applyMutation state2 second
  Map.size (stateEnglishNormalizations state3) @?= 2
  let currentId = stateCurrentEnglishNormalizations state3 Map.! revisionId
  englishNormalizationText (stateEnglishNormalizations state3 Map.! currentId) @?= "purchase milk"
  rawId raw @?= rawContentRevisionRaw (stateRawContentRevisions state3 Map.! revisionId)

obsoleteRevisionRejected :: Assertion
obsoleteRevisionRejected = do
  (state1, raw) <- fedState "comprar leite"
  let oldRevisionId = stateCurrentRawRevisions state1 Map.! rawId raw
  appended <- assertRight (decideAppendRawRevision state1 actor (rawId raw) (RawTextContent "comprar leite integral") "human edit" (facts 10 2))
  state2 <- applyMutation state1 appended
  case decideAcceptEnglishNormalization state2 actor oldRevisionId "buy milk" HumanNormalization Nothing Nothing (facts 20 2) of
    Left problem -> appErrorCode problem @?= PreconditionFailed
    Right decision -> assertFailure ("obsolete revision unexpectedly accepted: " <> show decision)

sourceReconciliation :: Assertion
sourceReconciliation = do
  (state1, raw) <- fedState "old source text"
  bindingDecision <- assertRight (decideAttachSourceBinding state1 actor (rawId raw) "notesnook" Nothing (Just "note-42") Nothing "notesnook://note-42" SourceSynchronize SourceManualCheck (facts 30 3))
  state2 <- applyMutation state1 bindingDecision
  let binding = head (Map.elems (stateSourceBindings state2))
      changedText = "new source text"
      digest = rawContentDigest (RawTextContent changedText)
  observed <- assertRight (decideRecordSourceObservation state2 actor (sourceBindingId binding) "notesnook://note-42" SourceChanged (Just "v2") Nothing (Just digest) (Just (RawTextContent changedText)) (facts 40 2))
  state3 <- applyMutation state2 observed
  rawRevision (stateRaws state3 Map.! rawId raw) @?= 1
  sourceBindingAcceptedObservation (stateSourceBindings state3 Map.! sourceBindingId binding) @?= Nothing
  let observation = head (Map.elems (stateSourceObservations state3))
  accepted <- assertRight (decideAcceptSourceObservationAsRevision state3 actor (sourceObservationId observation) (facts 50 4))
  state4 <- applyMutation state3 accepted
  rawRevision (stateRaws state4 Map.! rawId raw) @?= 2
  sourceBindingAcceptedObservation (stateSourceBindings state4 Map.! sourceBindingId binding) @?= Just (sourceObservationId observation)
  missing <- assertRight (decideRecordSourceObservation state4 actor (sourceBindingId binding) "notesnook://note-42" SourceMissing Nothing Nothing Nothing Nothing (facts 60 2))
  state5 <- applyMutation state4 missing
  rawRevision (stateRaws state5 Map.! rawId raw) @?= 2
  rawStatus (stateRaws state5 Map.! rawId raw) @?= RawAwaitingReview

pendingChangeBlocksCheck :: Assertion
pendingChangeBlocksCheck = do
  (state, _, binding, _) <- changedSourceState "new source text"
  case decideRecordSourceObservation state actor (sourceBindingId binding) (sourceBindingLocator binding) SourceChanged (Just "v3") Nothing (Just (rawContentDigest (RawTextContent "another change"))) (Just (RawTextContent "another change")) (facts 260 2) of
    Left problem -> appErrorCode problem @?= PreconditionFailed
    Right decision -> assertFailure ("a second source check unexpectedly started: " <> show decision)

derivedSourceReconciliation :: Assertion
derivedSourceReconciliation = do
  let changedText = "an independently meaningful article revision"
  (state1, sourceRaw, binding, observation) <- changedSourceState changedText
  decision <- assertRight (decideDeriveSourceObservation state1 actor (sourceObservationId observation) (facts 300 7))
  state2 <- applyMutation state1 decision
  let derived = only "derived Raw" [raw | raw <- Map.elems (stateRaws state2), rawId raw /= rawId sourceRaw]
      revisionId = stateCurrentRawRevisions state2 Map.! rawId derived
      revision = stateRawContentRevisions state2 Map.! revisionId
      reconciliation = only "source reconciliation" (Map.elems (stateSourceReconciliations state2))
      currentBinding = stateSourceBindings state2 Map.! sourceBindingId binding
  rawContentRevisionContent revision @?= RawTextContent changedText
  sourceBindingRaw currentBinding @?= rawId sourceRaw
  sourceBindingAcceptedObservation currentBinding @?= Just (sourceObservationId observation)
  sourceReconciliationDisposition reconciliation @?= SourceAcceptedAsDerivedRaw (rawId derived)
  assertBool
    "derived_from relation targets the Raw that retained the SourceBinding"
    (any (\link -> rawLinkRaw link == rawId derived && rawLinkTarget link == RawLinkRaw (rawId sourceRaw) && rawLinkRole link == DerivedFromRole) (Map.elems (stateRawLinks state2)))

unrelatedSourceReconciliation :: Assertion
unrelatedSourceReconciliation = do
  (state1, sourceRaw, binding, observation) <- changedSourceState "an unrelated response"
  decision <- assertRight (decideIgnoreSourceObservation state1 actor (sourceObservationId observation) (facts 400 3))
  state2 <- applyMutation state1 decision
  Map.size (stateRaws state2) @?= Map.size (stateRaws state1)
  rawRevision (stateRaws state2 Map.! rawId sourceRaw) @?= rawRevision sourceRaw
  sourceBindingAcceptedObservation (stateSourceBindings state2 Map.! sourceBindingId binding) @?= Just (sourceObservationId observation)
  sourceReconciliationDisposition (only "source reconciliation" (Map.elems (stateSourceReconciliations state2))) @?= SourceIgnoredAsUnrelated

changedSourceState :: Text -> IO (State, Raw, SourceBinding, SourceObservation)
changedSourceState changedText = do
  (state1, raw) <- fedState "old source text"
  bindingDecision <- assertRight (decideAttachSourceBinding state1 actor (rawId raw) "notesnook" Nothing (Just "note-42") Nothing "notesnook://note-42" SourceSynchronize SourceManualCheck (facts 220 3))
  state2 <- applyMutation state1 bindingDecision
  let binding = only "SourceBinding" (Map.elems (stateSourceBindings state2))
      content = RawTextContent changedText
  observed <- assertRight (decideRecordSourceObservation state2 actor (sourceBindingId binding) (sourceBindingLocator binding) SourceChanged (Just "v2") Nothing (Just (rawContentDigest content)) (Just content) (facts 230 2))
  state3 <- applyMutation state2 observed
  pure (state3, raw, binding, only "SourceObservation" (Map.elems (stateSourceObservations state3)))

sourceEventRoundTrip :: Assertion
sourceEventRoundTrip = do
  (state1, raw) <- fedState "source"
  decision <- assertRight (decideAttachSourceBinding state1 actor (rawId raw) "microsoft_todo" Nothing (Just "task-1") Nothing "mstodo://task-1" SourceMigrate (SourceIntervalCheck 3600) (facts 70 3))
  let event = persist 99 (head (mutationDecisionEvents decision))
  decodeEvent (encodeEvent event) @?= Right event

brickTitleNormalization :: Assertion
brickTitleNormalization = do
  (state1, raw) <- fedState "corrigir site"
  materialized <- assertRight (decideMaterializeWork state1 actor (WorkDraft (rawId raw) "Corrigir site" AtomicTask Nothing Nothing Set.empty 0 (DeterministicPosition "sole_sibling") []) (facts 80 6))
  state2 <- applyMutation state1 materialized
  let brick = case Map.elems (stateBricks state2) of [value] -> value; _ -> error "expected one Brick"
  normalized <- assertRight (decideAcceptBrickTitleNormalization state2 actor (brickId brick) "Fix website" HumanNormalization Nothing Nothing (facts 90 2))
  state3 <- applyMutation state2 normalized
  let changed = stateBricks state3 Map.! brickId brick
  brickHandle changed @?= brickHandle brick
  brickTitle changed @?= "Fix website"
  let record = case Map.elems (stateBrickTitleNormalizations state3) of [value] -> value; _ -> error "expected one title normalization"
  brickTitleNormalizationPrevious record @?= "Corrigir site"
  brickTitleNormalizationCurrent record @?= "Fix website"

publicRawTranslation :: Assertion
publicRawTranslation = withHarness $ \environment -> do
  fed <- run environment (FeedCommand "test" "comprar leite")
  raw <- case fed of FeedResult{resultRaw} -> pure resultRaw; other -> assertFailure (show other) >> fail "unreachable"
  editor <- run environment (TranslateCommand (Just (renderHandle RawHandle (projectedRawHandle raw)))) >>= interactionOf
  case envelopeOpportunity editor of
    TranslationEditOpportunity queue Nothing Nothing -> translationQueueTotal queue @?= 1
    other -> assertFailure ("expected translation editor, got " <> show other)
  preview <- submit environment editor "translate.edit.submit" "buy milk"
  accepted <- answer environment preview "translate.preview.accept"
  envelopeOpportunity accepted @?= TranslationCompleteOpportunity 1 0 1
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
      revisionId = stateCurrentRawRevisions state Map.! projectedRawId raw
      normalizationId = stateCurrentEnglishNormalizations state Map.! revisionId
  englishNormalizationText (stateEnglishNormalizations state Map.! normalizationId) @?= "buy milk"

translationSkip :: Assertion
translationSkip = withHarness $ \environment -> do
  fed <- run environment (FeedCommand "test" "comprar pão")
  raw <- case fed of FeedResult{resultRaw} -> pure resultRaw; other -> assertFailure (show other) >> fail "unreachable"
  editor <- run environment (TranslateCommand (Just (renderHandle RawHandle (projectedRawHandle raw)))) >>= interactionOf
  skipped <- answer environment editor "translate.edit.skip"
  envelopeOpportunity skipped @?= TranslationCompleteOpportunity 0 1 1
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  stateEventCount (loadedState loaded) @?= 1
  stateEnglishNormalizations (loadedState loaded) @?= Map.empty

translationOpportunityRoundTrip :: Assertion
translationOpportunityRoundTrip = do
  let candidate = TranslationRawRevision (fixtureUuid 150) (fixtureUuid 151)
      opportunity = TranslationPreviewOpportunity (TranslationQueue (TranslationScope True True False) [candidate] 2 1 7) "translated" PoweredUpNormalization (Just "/bin/claude-fast.sh") (Just (Fixed 700000))
  eitherDecode (encode opportunity) @?= Right opportunity

pristineDoctor :: Assertion
pristineDoctor = withHarness $ \environment -> do
  let isolated =
        environment
          { appNow = fail "doctor must not read the semantic clock"
          , appZonedNow = fail "doctor must not read the presentation clock"
          , appAllocateUUID = fail "doctor must not allocate identity"
          }
  result <- run isolated DoctorCommand
  case result of
    DoctorResult Genesis True 0 [check] False -> do
      diagnosticCheckName check @?= "canonical_history"
      diagnosticCheckPassed check @?= True
      diagnosticCheckProblem check @?= Nothing
    other -> assertFailure ("unexpected pristine diagnosis: " <> show other)

corruptDoctor :: Assertion
corruptDoctor = withHarness $ \environment -> do
  _ <- run environment (FeedCommand "test" "preserved before corruption")
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let corruptBytes = "{not-json}\n"
      corruptName = segmentFileName 2 (sha256Hex corruptBytes)
      corruptPath = storeRoot (appStore environment) </> "events" </> corruptName
  ByteString.writeFile corruptPath corruptBytes
  result <- run environment DoctorCommand
  case result of
    DoctorResult cursor False validated [check] False -> do
      cursor @?= loadedCursor loaded
      validated @?= loadedEventCount loaded
      diagnosticCheckPassed check @?= False
      case diagnosticCheckProblem check of
        Nothing -> assertFailure "corrupt diagnosis omitted its typed problem"
        Just problem -> do
          appErrorCode problem @?= CorruptData
          appErrorSubject problem @?= Just (Text.pack corruptName)
          assertBool "physical line is reported" ("physical_line: 1" `elem` appErrorDetails problem)
          assertBool "byte offset is reported" ("byte_offset: 0" `elem` appErrorDetails problem)
    other -> assertFailure ("unexpected corrupt diagnosis: " <> show other)
  ordinary <- runAppCommand environment False (const (pure ())) NextCommand
  case ordinary of
    Left problem -> appErrorCode problem @?= CorruptData
    Right accepted -> assertFailure ("ordinary replay crossed corruption: " <> show accepted)

losslessRepairCandidate :: Assertion
losslessRepairCandidate = withRepairHarness $ \outer environment -> do
  _ <- run environment (FeedCommand "test" "preserve this event")
  let store = appStore environment
      events = storeRoot store </> "events"
  originalName <- only "canonical segment" <$> listDirectory events
  originalBytes <- ByteString.readFile (events </> originalName)
  let wrongName = segmentFileName 1 (Text.replicate 64 "0")
  renameFile (events </> originalName) (events </> wrongName)
  before <- eventFiles store

  plan <- assertRight =<< planDatasetRepair store
  repairPlanOriginalSegment plan @?= wrongName
  repairPlanReplacementSegment plan @?= originalName
  repairPlanSegmentDigest plan @?= sha256Hex originalBytes
  takeDirectory (repairPlanCandidateRoot plan) @?= outer

  candidate <- assertRight =<< buildRepairCandidate store plan
  repairCandidateReused candidate @?= False
  assertBool "candidate is separate from authority" (repairCandidateRoot candidate /= storeRoot store)
  receiptExists <- doesFileExist (repairCandidateReceipt candidate)
  assertBool "verified candidate has a durable receipt" receiptExists
  replayed <- assertRight =<< loadDataset store{storeRoot = repairCandidateRoot candidate} (const (pure ()))
  loadedCursor replayed @?= repairCandidateCursor candidate
  loadedEventCount replayed @?= repairCandidateEventCount candidate
  loadedEventCount replayed @?= 1
  authorityAfterBuild <- eventFiles store
  authorityAfterBuild @?= before

  reused <- assertRight =<< buildRepairCandidate store plan
  repairCandidateReused reused @?= True
  repairCandidateRoot reused @?= repairCandidateRoot candidate

unsupportedRepair :: Assertion
unsupportedRepair = withRepairHarness $ \outer environment -> do
  _ <- run environment (FeedCommand "test" "valid prefix")
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let corruptBytes = "{not-json}\n"
      corruptName = segmentFileName 2 (sha256Hex corruptBytes)
      corruptPath = storeRoot (appStore environment) </> "events" </> corruptName
  ByteString.writeFile corruptPath corruptBytes
  problem <- assertLeft =<< planDatasetRepair (appStore environment)
  appErrorCode problem @?= PreconditionFailed
  appErrorCursor problem @?= Just (renderCursor (loadedCursor loaded))
  siblings <- listDirectory outer
  siblings @?= ["live"]

staleRepairPlan :: Assertion
staleRepairPlan = withRepairHarness $ \_ environment -> do
  _ <- run environment (FeedCommand "test" "stable before preview")
  let store = appStore environment
      events = storeRoot store </> "events"
  originalName <- only "canonical segment" <$> listDirectory events
  let wrongName = segmentFileName 1 (Text.replicate 64 "0")
      wrongPath = events </> wrongName
  renameFile (events </> originalName) wrongPath
  plan <- assertRight =<< planDatasetRepair store
  ByteString.appendFile wrongPath " "
  before <- eventFiles store
  problem <- assertLeft =<< buildRepairCandidate store plan
  appErrorCode problem @?= Conflict
  candidateExists <- doesDirectoryExist (repairPlanCandidateRoot plan)
  assertBool "stale preview did not create its candidate" (not candidateExists)
  authorityAfterRejection <- eventFiles store
  authorityAfterRejection @?= before

atomicRepairCutover :: Assertion
atomicRepairCutover = withRepairHarness $ \_ environment -> do
  (repairPlan, candidate, corruptAuthority) <- preparedRepair environment
  cutover <- assertRight =<< planRepairCutover (appStore environment) repairPlan candidate
  let backup = cutoverBackupRoot cutover
  ( do
      result <- assertRight =<< executeRepairCutover (appStore environment) cutover
      cutoverResultRecovered result @?= False
      cutoverResultBackupRoot result @?= backup
      receiptExists <- doesFileExist (cutoverResultReceiptPath result)
      assertBool "completed cutover has a durable receipt" receiptExists
      journalExists <- doesFileExist (cutoverJournalPath cutover)
      assertBool "completed cutover removes its pending intent" (not journalExists)
      candidateExists <- doesDirectoryExist (cutoverCandidateRoot cutover)
      assertBool "the candidate name is consumed by cutover" (not candidateExists)
      live <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
      loadedCursor live @?= cutoverCandidateCursor cutover
      loadedEventCount live @?= cutoverCandidateEventCount cutover
      retained <- eventFiles (appStore environment){storeRoot = backup}
      retained @?= corruptAuthority
      assertTreeReadOnly backup
    )
    `finally` makeTreeWritableIfPresent backup

recoverPreparedCutover :: Assertion
recoverPreparedCutover = withRepairHarness $ \_ environment -> do
  (repairPlan, candidate, corruptAuthority) <- preparedRepair environment
  cutover <- assertRight =<< planRepairCutover (appStore environment) repairPlan candidate
  let backup = cutoverBackupRoot cutover
  ( do
      assertRight =<< prepareRepairCutoverIntent (appStore environment) cutover
      before <- eventFiles (appStore environment)
      before @?= corruptAuthority
      journalExists <- doesFileExist (cutoverJournalPath cutover)
      assertBool "consent is durable before namespace exchange" journalExists
      recovered <- assertRight =<< recoverRepairCutover (appStore environment)
      result <- maybe (assertFailure "pending cutover was not recovered") pure recovered
      cutoverResultRecovered result @?= True
      live <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
      loadedCursor live @?= cutoverCandidateCursor cutover
      retained <- eventFiles (appStore environment){storeRoot = backup}
      retained @?= corruptAuthority
      pending <- recoverRepairCutover (appStore environment)
      pending @?= Right Nothing
    )
    `finally` makeTreeWritableIfPresent backup

recoverExchangedCutover :: Assertion
recoverExchangedCutover = withRepairHarness $ \outer environment -> do
  (repairPlan, candidate, corruptAuthority) <- preparedRepair environment
  cutover <- assertRight =<< planRepairCutover (appStore environment) repairPlan candidate
  let source = cutoverSourceRoot cutover
      candidateRoot = cutoverCandidateRoot cutover
      backup = cutoverBackupRoot cutover
      transition = outer </> "interrupted-exchange"
  ( do
      assertRight =<< prepareRepairCutoverIntent (appStore environment) cutover
      renameDirectory source transition
      renameDirectory candidateRoot source
      renameDirectory transition candidateRoot

      recovered <- assertRight =<< recoverRepairCutover (appStore environment)
      result <- maybe (assertFailure "post-exchange cutover was not recovered") pure recovered
      cutoverResultRecovered result @?= True
      live <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
      loadedCursor live @?= cutoverCandidateCursor cutover
      retained <- eventFiles (appStore environment){storeRoot = backup}
      retained @?= corruptAuthority
      oldCandidateNameExists <- doesDirectoryExist candidateRoot
      assertBool "recovery consumed the old candidate name" (not oldCandidateNameExists)
    )
    `finally` makeTreeWritableIfPresent backup

repairDryRun :: Assertion
repairDryRun = withRepairHarness $ \outer environment -> do
  corruptAuthority <- corruptOneSegment environment "dry-run repair evidence"
  siblingsBefore <- listDirectory outer
  result <- assertRight =<< runAppCommand environment True (const (pure ())) RepairCommand
  envelope <- interactionOf result
  case envelopeOpportunity envelope of
    RepairPreviewOpportunity _ _ _ _ candidate _ -> do
      candidateExists <- doesDirectoryExist candidate
      assertBool "dry-run does not build a repair candidate" (not candidateExists)
    other -> assertFailure ("expected dry-run repair preview, got " <> show other)
  siblingsAfter <- listDirectory outer
  siblingsAfter @?= siblingsBefore
  authorityAfter <- eventFiles (appStore environment)
  authorityAfter @?= corruptAuthority

publicRepairFlow :: Assertion
publicRepairFlow = withRepairHarness $ \_ environment -> do
  corruptAuthority <- corruptOneSegment environment "public repair evidence"
  previewResult <- run environment RepairCommand
  preview <- interactionOf previewResult
  planHash <- case envelopeOpportunity preview of
    RepairPreviewOpportunity hash source _ _ candidate validEvents -> do
      source @?= storeRoot (appStore environment)
      validEvents @?= 0
      exists <- doesDirectoryExist candidate
      assertBool "preview does not build the candidate" (not exists)
      pure hash
    other -> assertFailure ("expected repair preview, got " <> show other) >> fail "unreachable"
  assertBool "repair preview has no default action" (not (any actionDefault (envelopeActions preview)))

  candidateEnvelope <- answer environment preview "repair.build"
  (cutoverHash, backup) <- case envelopeOpportunity candidateEnvelope of
    RepairCandidateOpportunity repairHash candidateCutoverHash source candidatePath backupPath _ eventCount -> do
      repairHash @?= planHash
      source @?= storeRoot (appStore environment)
      eventCount @?= 1
      exists <- doesDirectoryExist candidatePath
      assertBool "explicit build creates the separate candidate" exists
      liveAfterBuild <- eventFiles (appStore environment)
      liveAfterBuild @?= corruptAuthority
      pure (candidateCutoverHash, backupPath)
    other -> assertFailure ("expected validated repair candidate, got " <> show other) >> fail "unreachable"
  assertBool "cutover consent has no default action" (not (any actionDefault (envelopeActions candidateEnvelope)))

  ( do
      completed <- run environment (RespondCommand (response candidateEnvelope "repair.cutover"))
      completion <- interactionOf completed
      case envelopeOpportunity completion of
        RepairCompleteOpportunity completedHash retainedBackup recovered -> do
          completedHash @?= cutoverHash
          retainedBackup @?= backup
          recovered @?= False
        other -> assertFailure ("expected repair completion, got " <> show other)
      live <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
      loadedEventCount live @?= 1
      next <- run environment NextCommand
      case next of
        NextResult{} -> pure ()
        other -> assertFailure ("ordinary commands did not resume after repair: " <> show other)
    )
    `finally` makeTreeWritableIfPresent backup

preparedRepair :: AppEnv -> IO (RepairPlan, RepairCandidate, [(FilePath, ByteString.ByteString)])
preparedRepair environment = do
  corruptAuthority <- corruptOneSegment environment "preserve through atomic cutover"
  let store = appStore environment
  repairPlan <- assertRight =<< planDatasetRepair store
  candidate <- assertRight =<< buildRepairCandidate store repairPlan
  pure (repairPlan, candidate, corruptAuthority)

corruptOneSegment :: AppEnv -> Text -> IO [(FilePath, ByteString.ByteString)]
corruptOneSegment environment material = do
  _ <- run environment (FeedCommand "test" material)
  let store = appStore environment
      events = storeRoot store </> "events"
  originalName <- only "canonical segment" <$> listDirectory events
  let wrongName = segmentFileName 1 (Text.replicate 64 "0")
  renameFile (events </> originalName) (events </> wrongName)
  eventFiles store

assertTreeReadOnly :: FilePath -> Assertion
assertTreeReadOnly path = do
  status <- getFileStatus path
  assertBool ("write bits remain on " <> path) (fileMode status .&. 0o222 == 0)
  whenDirectory status $ do
    names <- listDirectory path
    mapM_ (assertTreeReadOnly . (path </>)) names

makeTreeWritableIfPresent :: FilePath -> IO ()
makeTreeWritableIfPresent path = do
  exists <- doesDirectoryExist path
  if not exists
    then pure ()
    else do
      setFileMode path 0o700
      names <- listDirectory path
      mapM_ restore (fmap (path </>) names)
 where
  restore child = do
    status <- getFileStatus child
    if isDirectory status
      then makeTreeWritableIfPresent child
      else setFileMode child 0o600

whenDirectory :: FileStatus -> IO () -> IO ()
whenDirectory status action = if isDirectory status then action else pure ()

eventFiles :: StoreConfig -> IO [(FilePath, ByteString.ByteString)]
eventFiles store = do
  let events = storeRoot store </> "events"
  names <- listDirectory events
  traverse (\name -> (name,) <$> ByteString.readFile (events </> name)) names

fedState :: Text -> IO (State, Raw)
fedState text = do
  decision <- assertRight (decideFeed emptyState actor "test" text (facts 1 3))
  state <- applyEvents emptyState (feedDecisionEvents decision)
  pure (state, feedDecisionRaw decision)

applyMutation :: State -> MutationDecision -> IO State
applyMutation state decision = applyEvents state (mutationDecisionEvents decision)

applyEvents :: State -> [EventDraft] -> IO State
applyEvents state events = assertRight (foldM applyEvent state (zipWith persist [stateEventCount state + 1 ..] events))

persist :: Integer -> EventDraft -> PersistedEvent
persist sequenceNumber draft =
  PersistedEvent (draftEventId draft) (draftCommandId draft) sequenceNumber 0 (draftActor draft) (draftRecordedAt draft) (if sequenceNumber == 1 then "GENESIS" else "fixture") (draftPreconditionHash draft) (draftReplayUUIDs draft) (draftPayload draft)

facts :: Int -> Int -> RuntimeFacts
facts base count =
  RuntimeFacts now [UUIDAllocation (renderUUIDv7 (fixtureUuid number)) | number <- [base .. base + count - 1]] Map.empty (FilesystemFacts True True Nothing) (TerminalCapabilities False False False 80 24 False) []

actor :: Actor
actor = Actor "human" "test"

now :: UTCTime
now = UTCTime (fromGregorian 2026 8 8) (secondsToDiffTime (12 * 3600))

fixtureUuid :: Int -> UUIDv7
fixtureUuid number = either (error . show) id $ uuidV7FromEntropy (0x019f12340000 + fromIntegral number) (ByteString.replicate 10 (fromIntegral (number `mod` 251 + 1)))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertLeft :: (Show right) => Either left right -> IO left
assertLeft = either pure (assertFailure . show)

only :: String -> [value] -> value
only label = \case
  [value] -> value
  values -> error ("expected one " <> label <> ", got " <> show (length values))

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s09" $ \root -> do
  environment <- harnessEnvironment root
  action environment

withRepairHarness :: (FilePath -> AppEnv -> IO a) -> IO a
withRepairHarness action = withSystemTempDirectory "little-ant-s09-repair" $ \outer -> do
  environment <- harnessEnvironment (outer </> "live")
  action outer environment

harnessEnvironment :: FilePath -> IO AppEnv
harnessEnvironment root = do
  counter <- newIORef (1000 :: Int)
  let allocate = atomicModifyIORef' counter $ \seed -> (seed + 1, fixtureUuid seed)
  pure (AppEnv (StoreConfig root 2000000 20000) actor (pure now) (pure (utcToZonedTime utc now)) allocate emptyExportPort emptyImportPort Nothing)

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command = assertRight =<< runAppCommand environment False (const (pure ())) command

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  FeedResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  RepairResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no guided interaction: " <> show other) >> fail "unreachable"

answer :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answer environment envelope action = run environment (RespondCommand (response envelope action)) >>= interactionOf

submit :: AppEnv -> InteractionEnvelope -> Text -> Text -> IO InteractionEnvelope
submit environment envelope action value = run environment (SubmitInteractionTextCommand (response envelope action) value) >>= interactionOf

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action = InteractionResponse (envelopeInteractionId envelope) (envelopeRevision envelope) action (envelopeIntegrityToken envelope) (envelopeDatasetCursor envelope)

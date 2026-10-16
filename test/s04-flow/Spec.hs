module Main (main) where

import Control.Monad (foldM, when)
import Data.Aeson (encode, object, (.=))
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision (completionUUIDCount, decideAddDependency, decideCompleteBrick, mutationDecisionEvents, statePreconditionHash)
import LittleAnt.Error (AppError (..), ErrorCode (PreconditionFailed))
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Forecast (factoryForecastProfile, profileHash)
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Projection (renderEnvelopeAtWidth)
import LittleAnt.Result
import LittleAnt.Store
import LittleAnt.Surface (plainLine, screenLines, textDisplayWidth)
import System.FilePath ((</>))
import System.IO.Temp
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S04 vertical forecast"
      [ testCase "why and forecast preserve the checkpoint, history and recorded facts" whyIsReadOnly
      , testCase "lottery ordering serves one comparison and persists its skip cooldown" lotteryOrdering
      , testCase "next records one immutable draw and restart restores it" recordedNext
      , testCase "legacy forecast evidence replays its original profile and weights" legacyForecastReplay
      , testCase "completion releases every Dependency for which the Brick is the blocker" dependencyRelease
      , testCase "retirement removes both dependency directions, discloses release, and preserves historical replay" dependencyRetirement
      , testCase "saved archive consent refreshes before acceptance without a forecast draw" savedArchiveConsent
      , testCase "category grouping retains archived relevance-review forecast candidates" archivedCategoryForecast
      ]

whyIsReadOnly :: Assertion
whyIsReadOnly = withHarness $ \environment -> do
  seedOneBrick environment
  _ <- run environment NextCommand
  before <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let checkpoint = storeRoot (appStore environment) </> "checkpoints" </> "pending-envelope.json"
  saved <- ByteString.readFile checkpoint
  first <- run environment (WhyCommand CompleteView)
  case first of
    WhyResult{resultWhyEvidence = Just evidence, resultWhySummary = summary} -> do
      assertBool "new selections omitted their snapshot" (isJust (forecastSelectionExplanation evidence))
      assertBool "why did not explain its recorded chance" (any (Text.isInfixOf "100.00%") summary)
    other -> assertFailure (show other)
  _ <- run environment (ListCommand (Just "forecast"))
  again <- run environment (WhyCommand CompleteView)
  again @?= first
  ByteString.readFile checkpoint >>= (@?= saved)
  after <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  loadedCursor after @?= loadedCursor before
  stateRandomCursors (loadedState after) @?= stateRandomCursors (loadedState before)
  let event =
        EventDraft
          (fixtureUuid 80)
          (fixtureUuid 81)
          (appActor environment)
          fixedTime
          (statePreconditionHash (loadedState after))
          []
          (BrickTitleNormalizationAcceptedV1 (BrickTitleNormalizationAccepted brickIdValue "Write the migration specification" "Renamed later" HumanNormalization Nothing Nothing))
  _ <- assertRight =<< appendCommand (appStore environment) (loadedCursor after) [event]
  changed <- run environment (WhyCommand CompleteView)
  resultWhySummary changed @?= resultWhySummary first
  resultWhyDetails changed @?= resultWhyDetails first
  -- No pending lottery may be invented for a directly opened proposal.
  _ <- run environment (FocusCommand "#wtms")
  manual <- run environment (WhyCommand SummaryView)
  resultWhyEvidence manual @?= Nothing
  assertBool "manual opening was described as a draw" (any (Text.isInfixOf "opened directly") (resultWhySummary manual))

lotteryOrdering :: Assertion
lotteryOrdering = withHarness $ \environment -> do
  seedOrderingRun environment
  first <- run environment NextCommand >>= interactionOf
  case envelopeOpportunity first of
    ImportanceReviewOpportunity session _ _ _ _ _ -> orderSessionCadence session @?= LotteryOrder
    other -> assertFailure ("unresolved ordering was not dispatched: " <> show other)
  forecast <- run environment (ListCommand (Just "forecast"))
  case forecast of
    ListResult{resultListEntries = [ForecastListRow _ _ _ chance [opportunity]]} -> do
      chance @?= (1, 1)
      projectedOpportunityKind opportunity @?= "importance_run_review"
      projectedOpportunityChance opportunity @?= (1, 1)
    other -> assertFailure (show other)
  why <- run environment (WhyCommand SummaryView)
  assertBool "ordering selection lost its provenance" (isJust (resultWhyEvidence why))
  accepted <- respond environment first "importance.more"
  assertBool "lottery answer unexpectedly started a continuous sorter" (case envelopeOpportunity accepted of ImportanceReviewOpportunity{} -> False; _ -> True)
  afterAnswer <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  Map.size (statePairJudgments (loadedState afterAnswer)) @?= 1
  _ <- run environment (OrderCommand (Just "#wtms"))
  continuous <- run environment NextCommand >>= interactionOf
  case envelopeOpportunity continuous of
    ImportanceReviewOpportunity session _ _ _ _ _ -> orderSessionCadence session @?= ContinuousOrder
    other -> assertFailure (show other)
  -- A new isolated run exercises first skip, nearby alternative and second skip.
  withHarness $ \skipping -> do
    seedOrderingRun skipping
    offered <- run skipping NextCommand >>= interactionOf
    nearby <- respond skipping offered "importance.skip"
    case envelopeOpportunity nearby of
      ImportanceReviewOpportunity _ _ _ skips _ _ -> skips @?= 1
      other -> assertFailure (show other)
    _ <- respond skipping nearby "importance.skip"
    deferred <- assertRight =<< loadDataset (appStore skipping) (const (pure ()))
    fmap importanceReviewCooldownUntil (Map.lookup Nothing (stateImportanceReviewDeferrals (loadedState deferred))) @?= Just (addUTCTime 86400 fixedTime)
    stateWorkDeferrals (loadedState deferred) @?= Map.empty
    during <- run skipping (ListCommand (Just "forecast"))
    resultListEntries during @?= []
    let later = addUTCTime 86400 fixedTime
        resumed = skipping{appNow = pure later, appZonedNow = pure (utcToZonedTime utc later)}
    afterCooldown <- run resumed (ListCommand (Just "forecast"))
    assertBool "cooldown expiry discarded the unresolved review" (not (null (resultListEntries afterCooldown)))
 where
  respond environment envelope action =
    run environment (RespondCommand (InteractionResponse (envelopeInteractionId envelope) (envelopeRevision envelope) action (envelopeIntegrityToken envelope) (envelopeDatasetCursor envelope))) >>= \case
      RespondResult{resultInteraction} -> pure resultInteraction
      other -> assertFailure (show other) >> fail "unreachable"

seedOrderingRun :: AppEnv -> IO ()
seedOrderingRun environment = do
  seedOneBrick environment
  dataset <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let payload identity handle position = BrickCreatedV1 (BrickCreated identity (Handle handle) handle AtomicTask "nature-v1" "human" Nothing Nothing Set.empty position (DeterministicPosition "imported") rawIdValue)
      tomorrow identity = TemporalConstraintsChangedV1 (TemporalConstraintsChanged identity (Just (ZonedInstant (addUTCTime (7 * 86400) fixedTime) "UTC")) Nothing Nothing 1)
      payloads = [payload (fixtureUuid 3) "two" 1, payload (fixtureUuid 4) "three" 2] <> fmap tomorrow [brickIdValue, fixtureUuid 3, fixtureUuid 4]
      draft index = EventDraft (fixtureUuid index) (fixtureUuid 90) (appActor environment) fixedTime (statePreconditionHash (loadedState dataset)) []
  _ <- assertRight =<< appendCommand (appStore environment) (loadedCursor dataset) (zipWith draft [100 ..] payloads)
  pure ()

recordedNext :: Assertion
recordedNext =
  withHarness $ \environment -> do
    seedOneBrick environment
    first <- run environment NextCommand
    firstEnvelope <- interactionOf first
    selectionId <- case envelopeOpportunity firstEnvelope of
      FocusProposalOpportunity identity (Just selected) -> do
        identity @?= brickIdValue
        pure selected
      other -> assertFailure ("expected recorded Focus proposal, got " <> show other)
    afterFirst <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
    Map.size (stateForecastSelections (loadedState afterFirst)) @?= 1
    assertBool "selection evidence is missing" (Map.member selectionId (stateForecastSelections (loadedState afterFirst)))
    forecastSelectionProfileHash (stateForecastSelections (loadedState afterFirst) Map.! selectionId) @?= profileHash factoryForecastProfile
    stateEventCount (loadedState afterFirst) @?= 5
    second <- run environment NextCommand
    secondEnvelope <- interactionOf second
    secondEnvelope @?= firstEnvelope
    resultCursor second @?= resultCursor first
    afterSecond <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
    stateEventCount (loadedState afterSecond) @?= 5

legacyForecastReplay :: Assertion
legacyForecastReplay = do
  let actor = Actor "human" "test"
      identities = fmap fixtureUuid [30 .. 32]
      selected = identities !! 1
      selectionId = fixtureUuid 33
      weights = zip identities [1_000_000, 287_500, 50_000]
      draw = ForecastDrawEvidence "forecast_subject_draw" [(renderUUIDv7 identity, weight) | (identity, weight) <- weights] 1_337_500 0 1 1_100_000 (renderUUIDv7 selected)
      evidence = ForecastSelectionEvidence selectionId "little-ant-forecast-v1-factory" (ByteString.replicate 32 7) weights selected (Just selected) "finite_work" [] Nothing Nothing [] [draw] Nothing
      brick identity = Brick identity (Handle (renderUUIDv7 identity)) "legacy sibling" AtomicTask "factory@1" "test" Nothing Nothing Set.empty 0 (DeterministicPosition "fixture") BrickActive Idle fixedTime actor (fixtureUuid 99)
      initial = emptyState{stateBricks = Map.fromList [(identity, brick identity) | identity <- identities]}
      event =
        PersistedEvent
          { persistedEventId = fixtureUuid 34
          , persistedCommandId = fixtureUuid 35
          , persistedSegmentSequence = 1
          , persistedEventSequence = 1
          , persistedActor = actor
          , persistedRecordedAt = fixedTime
          , persistedPreviousSegmentHash = "genesis"
          , persistedPreconditionHash = statePreconditionHash initial
          , persistedReplayUUIDs = [selectionId]
          , persistedPayload = ForecastSelectedV1 (ForecastSelected evidence)
          }
  decoded <- assertRight (decodeEvent (encodeEvent event))
  decoded @?= event
  replayed <- assertRight (applyEvent initial decoded)
  Map.lookup selectionId (stateForecastSelections replayed) @?= Just evidence
  Map.lookup "forecast_subject_draw" (stateRandomCursors replayed) @?= Just 1
  assertBool "new calculations must identify a different profile" (forecastSelectionProfileHash evidence /= profileHash factoryForecastProfile)

dependencyRelease :: Assertion
dependencyRelease = do
  let blocked = brickIdValue
      blocker = fixtureUuid 3
      state0 =
        emptyState
          { stateBricks = Map.fromList [(blocked, fixtureBrick blocked "blocked"), (blocker, fixtureBrick blocker "blocker")]
          , stateBrickHandles = Map.fromList [(Handle "blocked", blocked), (Handle "blocker", blocker)]
          , stateRetiredBrickHandles = Set.fromList [Handle "blocked", Handle "blocker"]
          }
  added <- assertRight (decideAddDependency state0 actor blocked blocker "human" (facts [100 .. 102]))
  state1 <- assertRight (foldDrafts state0 (mutationDecisionEvents added))
  completionUUIDCount state1 blocker @?= 3
  completed <- assertRight (decideCompleteBrick state1 actor blocker (facts [110 .. 112]))
  state2 <- assertRight (foldDrafts state1 (mutationDecisionEvents completed))
  brickStatus (stateBricks state2 Map.! blocker) @?= BrickDone
  fmap dependencyStatus (Map.elems (stateDependencies state2)) @?= [DependencyResolved]
 where
  actor = Actor "human" "test"
  facts numbers =
    RuntimeFacts
      fixedTime
      (fmap (UUIDAllocation . renderUUIDv7 . fixtureUuid) numbers)
      Map.empty
      (FilesystemFacts True True Nothing)
      (TerminalCapabilities False False False 80 24 False)
      []

  fixtureBrick identity handle =
    Brick identity (Handle handle) handle AtomicTask "factory@1" "test" Nothing Nothing Set.empty 0 (DeterministicPosition "fixture") BrickActive Idle fixedTime actor (fixtureUuid 99)

  foldDrafts state drafts =
    foldM apply state (zip [1 ..] drafts)

  apply state (sequenceNumber, draft) =
    applyEvent
      state
      PersistedEvent
        { persistedEventId = draftEventId draft
        , persistedCommandId = draftCommandId draft
        , persistedSegmentSequence = 1
        , persistedEventSequence = sequenceNumber
        , persistedActor = draftActor draft
        , persistedRecordedAt = draftRecordedAt draft
        , persistedPreviousSegmentHash = "genesis"
        , persistedPreconditionHash = draftPreconditionHash draft
        , persistedReplayUUIDs = draftReplayUUIDs draft
        , persistedPayload = draftPayload draft
        }

dependencyRetirement :: Assertion
dependencyRetirement = mapM_ check [BrickArchived, BrickSuperseded, BrickMerged]
 where
  actor = Actor "human" "test"
  target = fixtureUuid 21
  blocked = fixtureUuid 20
  prerequisite = fixtureUuid 22
  unrelated = fixtureUuid 23
  brick identity handle = Brick identity (Handle handle) handle AtomicTask "factory@1" "test" Nothing Nothing Set.empty 0 (DeterministicPosition "fixture") BrickActive Idle fixedTime actor (fixtureUuid 99)
  targetBrick = brick target "retiring"
  dependencies =
    [ Dependency (fixtureUuid 30) blocked target DependencyActive "human" fixedTime
    , Dependency (fixtureUuid 31) target prerequisite DependencyActive "human" fixedTime
    , Dependency (fixtureUuid 32) unrelated prerequisite DependencyActive "human" fixedTime
    ]
  initial = emptyState{stateBricks = Map.fromList [(brickId one, one) | one <- [brick blocked "blocked", targetBrick, brick prerequisite "prerequisite", brick unrelated "unrelated"]], stateDependencies = Map.fromList [(dependencyId one, one) | one <- dependencies]}
  statuses state = fmap dependencyStatus (Map.elems (stateDependencies state))
  apply number payload state =
    applyEvent state PersistedEvent{persistedEventId = fixtureUuid number, persistedCommandId = fixtureUuid (number + 100), persistedSegmentSequence = 1, persistedEventSequence = fromIntegral number, persistedActor = actor, persistedRecordedAt = fixedTime, persistedPreviousSegmentHash = "genesis", persistedPreconditionHash = statePreconditionHash state, persistedReplayUUIDs = [], persistedPayload = payload}
  check status = do
    let preview = makeArchivePreviewEnvelope (fixtureUuid 40) Genesis (statePreconditionHash initial) (utcToZonedTime utc fixedTime) initial targetBrick Nothing Nothing
    assertBool "archive hid release of dependent Work" ("Stop blocking: #blocked \"blocked\"" `elem` contentBody (envelopeContent preview))
    assertBool "archive hid removal of its prerequisite" ("Remove prerequisite: #prerequisite \"prerequisite\"" `elem` contentBody (envelopeContent preview))
    mapM_ (\width -> assertBool "archive disclosure exceeded terminal cells" (all ((<= width) . textDisplayWidth . plainLine) (screenLines (renderEnvelopeAtWidth width preview)))) [28, 80]
    retired <- assertRight (apply 40 (BrickStatusChangedV1 (BrickStatusChanged target BrickActive status "retire")) initial)
    statuses retired @?= [DependencyRemoved, DependencyRemoved, DependencyActive]
    stateDependencies retired Map.! fixtureUuid 30 @?= (head dependencies){dependencyStatus = DependencyRemoved}
    when (status == BrickArchived) $ do
      restored <- assertRight (apply 41 (BrickStatusChangedV1 (BrickStatusChanged target BrickArchived BrickActive "restore")) retired)
      statuses restored @?= statuses retired
      let restorePreview = makeRestorePreviewEnvelope (fixtureUuid 42) Genesis (statePreconditionHash retired) (utcToZonedTime utc fixedTime) retired (stateBricks retired Map.! target)
      assertBool "restore promised to silently revive dependencies" (any (Text.isInfixOf "will not reactivate") (contentBody (envelopeContent restorePreview)))
    -- This exact event ordering exists in older logs: archive an owner, then
    -- complete its prerequisite and record the explicit resolution.
    completed <- assertRight (apply 43 (BrickCompletedV1 (BrickCompleted prerequisite)) retired)
    historical <- assertRight (apply 44 (DependencyResolvedV1 (DependencyResolution (fixtureUuid 31))) completed)
    statuses historical @?= [DependencyRemoved, DependencyResolved, DependencyActive]

savedArchiveConsent :: Assertion
savedArchiveConsent = withHarness $ \environment -> do
  seedOneBrick environment
  preview <- run environment (ArchiveCommand "#wtms") >>= interactionOf
  before <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let oldAction action
        | actionId action == "archive.accept" = action{actionConsequence = "Archive reversibly and create one relevance review."}
        | otherwise = action
      old = resealEnvelope preview{envelopeActions = fmap oldAction (envelopeActions preview)}
  LazyByteString.writeFile (storeRoot (appStore environment) </> "checkpoints" </> "pending-envelope.json") $
    encode (object ["schema" .= ("little-ant/presentation-checkpoint@1" :: Text.Text), "current" .= old, "back_stack" .= ([] :: [InteractionEnvelope]), "forward_stack" .= ([] :: [InteractionEnvelope])])
  resumed <- run environment NextCommand >>= interactionOf
  envelopeOpportunity resumed @?= envelopeOpportunity preview
  envelopeActions resumed @?= envelopeActions preview
  assertBool "old archive token still authorized the changed consent" (envelopeIntegrityToken resumed /= envelopeIntegrityToken old)
  again <- run environment NextCommand >>= interactionOf
  again @?= resumed
  let oldResponse = InteractionResponse{responseInteractionId = envelopeInteractionId old, responseRevision = envelopeRevision old, responseActionId = "archive.accept", responseIntegrityToken = envelopeIntegrityToken old, responseAnsweredCursor = envelopeDatasetCursor old}
  runAppCommand environment False (const (pure ())) (RespondCommand oldResponse) >>= \case
    Left problem -> appErrorCode problem @?= PreconditionFailed
    Right result -> assertFailure ("old consent was applied: " <> show result)
  after <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  after @?= before

archivedCategoryForecast :: Assertion
archivedCategoryForecast = withHarness $ \environment -> do
  seedOneBrick environment
  preview <- run environment (ArchiveCommand "#wtms") >>= interactionOf
  let response = InteractionResponse (envelopeInteractionId preview) (envelopeRevision preview) "archive.accept" (envelopeIntegrityToken preview) (envelopeDatasetCursor preview)
  _ <- run environment (RespondCommand response)
  before <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  importance <- run environment (ListCommand (Just "importance"))
  case importance of ListResult{resultListEntries} -> resultListEntries @?= []; other -> assertFailure (show other)
  forecast <- run environment (ListCommand (Just "forecast"))
  case forecast of
    ListResult{resultListEntries = [row], resultListCategories = [ListCategory "Without a category" [ListItem grouped False []]]} -> do
      listEntryHandle row @?= "#wtms"
      listEntryHandle grouped @?= listEntryHandle row
      assertBool "grouping lost the archived review or changed its chance" (listEntryDetails row `Text.isPrefixOf` listEntryDetails grouped)
      assertBool "expected the archived relevance-review opportunity" ("archive relevance review" `Text.isInfixOf` listEntryDetails row)
    other -> assertFailure ("archived forecast disappeared from categories: " <> show other)
  after <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  after @?= before

seedOneBrick :: AppEnv -> IO ()
seedOneBrick environment = do
  let actor = Actor "human" "test"
      command = fixtureUuid 10
      eventIds = fmap fixtureUuid [11 .. 14]
      precondition = statePreconditionHash emptyState
      replay = rawIdValue : brickIdValue : command : eventIds
      draft eventId =
        EventDraft eventId command actor fixedTime precondition replay
      events =
        [ draft (head eventIds) (RawFedV1 (RawFed rawIdValue (Handle "wtms") "Write the migration specification" "test" Nothing))
        , draft
            (eventIds !! 1)
            ( BrickCreatedV1
                ( BrickCreated
                    brickIdValue
                    (Handle "wtms")
                    "Write the migration specification"
                    AtomicTask
                    "nature-v1"
                    "human"
                    Nothing
                    Nothing
                    Set.empty
                    0
                    (DeterministicPosition "singleton")
                    rawIdValue
                )
            )
        , draft (eventIds !! 2) (RawLinkAddedV1 (RawLinkAdded (fixtureUuid 20) rawIdValue (RawLinkBrick brickIdValue) MaterializationSourceRole))
        , draft (eventIds !! 3) (RawDispositionAcceptedV1 (RawDispositionAccepted rawIdValue (RawMaterializedAsWork brickIdValue)))
        ]
  accepted <- appendCommand (appStore environment) Genesis events
  case accepted of
    Left problem -> assertFailure (show problem)
    Right _ -> pure ()

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s04" $ \root -> do
  counter <- newIORef (4000 :: Int)
  let allocate = atomicModifyIORef' counter $ \number -> (number + 1, fixtureUuid number)
      environment =
        AppEnv
          (StoreConfig root 2_000_000 20_000)
          (Actor "human" "test")
          (pure fixedTime)
          (pure (utcToZonedTime utc fixedTime))
          allocate
          emptyExportPort
          emptyImportPort
          Nothing
          Nothing
          Nothing
          Nothing
  action environment

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command =
  assertRight =<< runAppCommand environment False (const (pure ())) command

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other)

rawIdValue :: UUIDv7
rawIdValue = fixtureUuid 1

brickIdValue :: UUIDv7
brickIdValue = fixtureUuid 2

fixtureUuid :: Int -> UUIDv7
fixtureUuid number =
  either (error . show) id $
    uuidV7FromEntropy
      (0x0198f8a34c21 + fromIntegral number)
      (ByteString.replicate 10 (fromIntegral (rem number 251 + 1)))

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

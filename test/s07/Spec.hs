module Main (main) where

import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import Data.Time.Zones
import LittleAnt.Application
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Result
import LittleAnt.Store
import LittleAnt.Time
import System.IO.Temp
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S07 time and standing work"
      [ testCase "month-end return clamps without drift" monthEndClamp
      , testCase "DST gap shifts by the gap while preserving minutes" dstGap
      , testCase "DST fold chooses the earlier occurrence" dstFold
      , testCase "repeatable completion restores checkpoint and records jittered return" repeatableReturnFlow
      , testCase "manual-only repeatable remains active and leaves ordinary draws" manualOnlyReturn
      , testCase "habit completion records one outcome without terminalizing owner" habitCompletion
      , testCase "recurring obligation releases one stable occurrence and tick is idempotent" recurringRelease
      , testCase "notices remain secondary and acknowledge or snooze only their exact identity" noticeLifecycle
      , testCase "scheduled commitment has hard precedence and truthful outcome" scheduledCommitmentFlow
      , testCase "scheduled commitment preserves interrupted Work as WIP" scheduledPreemptsFocus
      , testCase "overlapping commitments have no default and resolve independently" scheduledOverlap
      ]

monthEndClamp :: Assertion
monthEndClamp = do
  let local = LocalTime (fromGregorian 2026 1 31) (TimeOfDay 9 15 0)
  addReturnOffset ReturnMonths 1 local @?= LocalTime (fromGregorian 2026 2 28) (TimeOfDay 9 15 0)
  addReturnOffset ReturnMonths 2 local @?= LocalTime (fromGregorian 2026 3 31) (TimeOfDay 9 15 0)

dstGap :: Assertion
dstGap = do
  zone <- loadTZFromDB "America/New_York"
  let completed = UTCTime (fromGregorian 2026 3 7) (secondsToDiffTime (7 * 3600 + 30 * 60))
      (result, resolution) = resolveReturnInstant zone completed ReturnDays 1
  resolution @?= GapShiftedForward
  utcToLocalTimeTZ zone result @?= LocalTime (fromGregorian 2026 3 8) (TimeOfDay 3 30 0)

dstFold :: Assertion
dstFold = do
  zone <- loadTZFromDB "America/New_York"
  let completed = UTCTime (fromGregorian 2026 10 31) (secondsToDiffTime (5 * 3600 + 30 * 60))
      (result, resolution) = resolveReturnInstant zone completed ReturnDays 1
  resolution @?= FoldEarlier
  result @?= UTCTime (fromGregorian 2026 11 1) (secondsToDiffTime (5 * 3600 + 30 * 60))

repeatableReturnFlow :: Assertion
repeatableReturnFlow = withHarness $ \environment -> do
  seedBrick environment Repeatable
  proposal <- run environment NextCommand >>= interactionOf
  focused <- answer environment proposal "focus.accept"
  completed <- answer environment focused "focus.done"
  case envelopeOpportunity completed of
    RepeatableReturnOpportunity identity _ -> identity @?= brickIdValue
    other -> assertFailure ("expected repeatable return checkpoint, got " <> show other)
  restored <- run environment NextCommand >>= interactionOf
  envelopeOpportunity restored @?= envelopeOpportunity completed
  center <- answer environment restored "return.set"
  unit <- submit environment center "return.center.submit" "6"
  variation <- answer environment unit "return.unit.months"
  zone <- submit environment variation "return.variation.submit" "3"
  preview <- submit environment zone "return.zone.submit" "America/Montevideo"
  case envelopeOpportunity preview of
    RepeatableReturnPreviewOpportunity identity _ (AfterCompletionReturn 6 ReturnMonths 3 "America/Montevideo") chosen notBefore _ _ -> do
      identity @?= brickIdValue
      assertBool "chosen offset is outside 3..9" (chosen >= 3 && chosen <= 9)
      assertBool "return is not in the future" (zonedInstantUtc notBefore > fixedTime)
    other -> assertFailure ("expected deterministic return preview, got " <> show other)
  receipt <- answer environment preview "return.accept"
  envelopeOpportunity receipt @?= RepeatableReturnResultOpportunity brickIdValue
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  brickStatus (stateBricks state Map.! brickIdValue) @?= BrickActive
  brickWorkState (stateBricks state Map.! brickIdValue) @?= Idle
  length (stateStandingOutcomes state) @?= 1
  Map.size (stateLazyReviews state) @?= 0
  case Map.lookup brickIdValue (stateReturnSchedules state) of
    Just ReturnSchedule{returnSchedulePolicy = AfterCompletionReturn 6 ReturnMonths 3 "America/Montevideo", returnScheduleChosenOffset = Just chosen} ->
      assertBool "persisted offset is outside 3..9" (chosen >= 3 && chosen <= 9)
    other -> assertFailure ("unexpected return schedule: " <> show other)
  nextScreen <- answer environment receipt "next"
  envelopeOpportunity nextScreen @?= SafeEmptyOpportunity

manualOnlyReturn :: Assertion
manualOnlyReturn = withHarness $ \environment -> do
  seedBrick environment Repeatable
  proposal <- run environment NextCommand >>= interactionOf
  focused <- answer environment proposal "focus.accept"
  checkpoint <- answer environment focused "focus.done"
  receipt <- answer environment checkpoint "return.manual"
  envelopeOpportunity receipt @?= RepeatableReturnResultOpportunity brickIdValue
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  returnSchedulePolicy (stateReturnSchedules (loadedState loaded) Map.! brickIdValue) @?= ManualOnlyReturn
  nextScreen <- answer environment receipt "next"
  envelopeOpportunity nextScreen @?= SafeEmptyOpportunity

habitCompletion :: Assertion
habitCompletion = withHarness $ \environment -> do
  seedBrick environment Habit
  let schedule =
        FixedSlotHabit
          brickIdValue
          (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 3) Set.empty Nothing Nothing [TimeOfDay 8 0 0])
          "America/Montevideo"
          7200
          Nothing
          0
  _ <- run environment (SetHabitScheduleCommand schedule)
  proposal <- run environment NextCommand >>= interactionOf
  focused <- answer environment proposal "focus.accept"
  _ <- answer environment focused "focus.done"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  brickStatus (stateBricks state Map.! brickIdValue) @?= BrickActive
  fmap habitOutcomeKind (Map.elems (stateHabitOutcomes state)) @?= [StandingDone]
  fmap habitWindowSettled (Map.elems (stateHabitWindows state)) @?= [True]

recurringRelease :: Assertion
recurringRelease = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  let schedule =
        RecurrenceSchedule
          brickIdValue
          (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 3) Set.empty Nothing Nothing [TimeOfDay 8 0 0])
          "America/Montevideo"
          AtomicTask
          Nothing
          0
          Nothing
          Nothing
          0
  _ <- run environment (SetRecurrenceScheduleCommand schedule)
  first <- run environment TickCommand
  case first of
    TickResult{resultReleasedOccurrences = 1} -> pure ()
    other -> assertFailure ("expected one released occurrence, got " <> show other)
  afterFirst <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let occurrences = Map.elems (stateRecurringOccurrences (loadedState afterFirst))
  length occurrences @?= 1
  let occurrence = head occurrences
      occurrenceBrick = stateBricks (loadedState afterFirst) Map.! recurringOccurrenceBrick occurrence
  brickParent occurrenceBrick @?= Just brickIdValue
  brickNature occurrenceBrick @?= AtomicTask
  second <- run environment TickCommand
  case second of
    TickResult{resultReleasedOccurrences = 0} -> pure ()
    other -> assertFailure ("expected idempotent empty tick, got " <> show other)
  afterSecond <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  Map.size (stateRecurringOccurrences (loadedState afterSecond)) @?= 1

noticeLifecycle :: Assertion
noticeLifecycle = withHarness $ \environment -> do
  seedBrick environment AtomicTask
  let bestBefore = ZonedInstant (addUTCTime 7200 fixedTime) "America/Montevideo"
      deadline = ZonedInstant (addUTCTime 10800 fixedTime) "America/Montevideo"
  setTemporal environment brickIdValue (Just bestBefore) (Just deadline) 200
  proposal <- run environment NextCommand >>= interactionOf
  footerNoticeCount (envelopeFooter proposal) @?= 2
  assertBool "notice replaced the focus proposal" $ case envelopeOpportunity proposal of
    FocusProposalOpportunity{} -> True
    _ -> False
  listed <- run environment NoticesCommand >>= interactionOf
  notices <- case envelopeOpportunity listed of
    NoticeListOpportunity values -> pure values
    other -> assertFailure ("expected notice list, got " <> show other)
  length notices @?= 2
  opened <- answer environment listed "notice.select.0"
  envelopeOpportunity opened @?= TemporalNoticeOpportunity (head notices)
  acknowledged <- answer environment opened "notice.acknowledge"
  case envelopeOpportunity acknowledged of
    NoticeResultOpportunity identity _ -> identity @?= head notices
    other -> assertFailure ("expected notice receipt, got " <> show other)
  listedAgain <- run environment NoticesCommand >>= interactionOf
  noticesAgain <- case envelopeOpportunity listedAgain of
    NoticeListOpportunity values -> pure values
    other -> assertFailure ("expected complete notice list, got " <> show other)
  length noticesAgain @?= 2
  second <- answer environment listedAgain "notice.select.1"
  snoozeChoice <- answer environment second "notice.snooze"
  _ <- answer environment snoozeChoice "notice.snooze.tomorrow"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  Map.size (stateNoticeDispositions state) @?= 2
  Map.lookup brickIdValue (stateTemporalConstraints state) @?= Just (TemporalConstraints Nothing (Just bestBefore) (Just deadline) 1)
  Map.size (statePairJudgments state) @?= 0

scheduledCommitmentFlow :: Assertion
scheduledCommitmentFlow = withHarness $ \environment -> do
  seedBrick environment ScheduledCommitment
  setInterval environment brickIdValue (addUTCTime (-3600) fixedTime) (addUTCTime 3600 fixedTime) 40
  opportunity <- run environment NextCommand >>= interactionOf
  envelopeOpportunity opportunity @?= ScheduledCommitmentOpportunity brickIdValue
  assertBool "generic done leaked into the commitment screen" ("focus.done" `notElem` fmap actionId (envelopeActions opportunity))
  attending <- answer environment opportunity "commitment.attend"
  envelopeOpportunity attending @?= ScheduledCommitmentOpportunity brickIdValue
  receipt <- answer environment attending "commitment.attended"
  envelopeOpportunity receipt @?= ScheduledOutcomeResultOpportunity brickIdValue StandingAttended
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  brickStatus (stateBricks state Map.! brickIdValue) @?= BrickDone
  fmap standingOutcomeKind (Map.elems (stateStandingOutcomes state)) @?= [StandingAttended]

scheduledPreemptsFocus :: Assertion
scheduledPreemptsFocus = withHarness $ \environment -> do
  let ordinaryId = fixtureUuid 70
  seedBrickAs environment ordinaryId (Handle "ordinary") "Write migration notes" AtomicTask 71
  proposal <- run environment NextCommand >>= interactionOf
  focused <- answer environment proposal "focus.accept"
  envelopeOpportunity focused @?= CurrentFocusOpportunity ordinaryId
  seedBrickAs environment brickIdValue (Handle "flight") "Take flight AD123" ScheduledCommitment 80
  setInterval environment brickIdValue (addUTCTime (-3600) fixedTime) (addUTCTime 3600 fixedTime) 90
  commitment <- run environment NextCommand >>= interactionOf
  envelopeOpportunity commitment @?= ScheduledCommitmentOpportunity brickIdValue
  assertBool "the interrupted focus was not named" (any (Text.isInfixOf "Current focus remains WIP") (contentBody (envelopeContent commitment)))
  _ <- answer environment commitment "commitment.attend"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  brickWorkState (stateBricks state Map.! ordinaryId) @?= Wip
  stateCurrentFocus state @?= Just brickIdValue

scheduledOverlap :: Assertion
scheduledOverlap = withHarness $ \environment -> do
  let secondId = fixtureUuid 110
  seedBrickAs environment brickIdValue (Handle "first") "First meeting" ScheduledCommitment 111
  seedBrickAs environment secondId (Handle "second") "Second meeting" ScheduledCommitment 121
  setInterval environment brickIdValue (addUTCTime (-1800) fixedTime) (addUTCTime 1800 fixedTime) 131
  setInterval environment secondId (addUTCTime (-900) fixedTime) (addUTCTime 2700 fixedTime) 141
  overlap <- run environment NextCommand >>= interactionOf
  case envelopeOpportunity overlap of
    ScheduledOverlapOpportunity identities -> Set.fromList identities @?= Set.fromList [brickIdValue, secondId]
    other -> assertFailure ("expected scheduled overlap, got " <> show other)
  assertBool "overlap acquired an unsafe default" (all (not . actionDefault) (envelopeActions overlap))
  selected <- answer environment overlap ("commitment.overlap.select." <> renderUUIDv7 brickIdValue)
  _ <- answer environment selected "commitment.missed"
  remaining <- run environment NextCommand >>= interactionOf
  envelopeOpportunity remaining @?= ScheduledCommitmentOpportunity secondId

seedBrick :: AppEnv -> BrickNature -> IO ()
seedBrick environment nature = seedBrickAs environment brickIdValue (Handle "standing") "Standing work" nature 10

seedBrickAs :: AppEnv -> UUIDv7 -> Handle -> Text -> BrickNature -> Int -> IO ()
seedBrickAs environment identity handle title nature base = do
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let actor = Actor "human" "test"
      command = fixtureUuid base
      rawIdentity = fixtureUuid (base + 1)
      eventIds = fmap fixtureUuid [base + 2 .. base + 5]
      linkIdentity = fixtureUuid (base + 6)
      replay = command : rawIdentity : identity : linkIdentity : eventIds
      draft eventId payload = EventDraft eventId command actor fixedTime (statePreconditionHash (loadedState loaded)) replay payload
      events =
        [ draft (eventIds !! 0) (RawFedV1 (RawFed rawIdentity handle title "test" Nothing))
        , draft (eventIds !! 1) (BrickCreatedV1 (BrickCreated identity handle title nature "factory@1" "human" Nothing Nothing Set.empty 0 (DeterministicPosition "singleton") rawIdentity))
        , draft (eventIds !! 2) (RawLinkAddedV1 (RawLinkAdded linkIdentity rawIdentity (RawLinkBrick identity) MaterializationSourceRole))
        , draft (eventIds !! 3) (RawDispositionAcceptedV1 (RawDispositionAccepted rawIdentity (RawMaterializedAsWork identity)))
        ]
  accepted <- appendCommand (appStore environment) (loadedCursor loaded) events
  either (assertFailure . show) (const (pure ())) accepted

setTemporal :: AppEnv -> UUIDv7 -> Maybe ZonedInstant -> Maybe ZonedInstant -> Int -> IO ()
setTemporal environment owner bestBefore deadline base = do
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let actor = Actor "human" "test"
      commandId = fixtureUuid base
      eventId = fixtureUuid (base + 1)
      replay = [commandId, eventId]
      payload = TemporalConstraintsChanged owner Nothing bestBefore deadline 1
      event = EventDraft eventId commandId actor fixedTime (statePreconditionHash (loadedState loaded)) replay (TemporalConstraintsChangedV1 payload)
  accepted <- appendCommand (appStore environment) (loadedCursor loaded) [event]
  either (assertFailure . show) (const (pure ())) accepted

setInterval :: AppEnv -> UUIDv7 -> UTCTime -> UTCTime -> Int -> IO ()
setInterval environment owner starts ends base = do
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let actor = Actor "human" "test"
      commandId = fixtureUuid base
      eventId = fixtureUuid (base + 1)
      replay = [commandId, eventId]
      interval = ScheduledIntervalSet owner (ZonedInstant starts "America/Montevideo") (ZonedInstant ends "America/Montevideo") 1
      event = EventDraft eventId commandId actor fixedTime (statePreconditionHash (loadedState loaded)) replay (ScheduledIntervalSetV1 interval)
  accepted <- appendCommand (appStore environment) (loadedCursor loaded) [event]
  either (assertFailure . show) (const (pure ())) accepted

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s07" $ \root -> do
  counter <- newIORef (7000 :: Int)
  let allocate = atomicModifyIORef' counter $ \number -> (number + 1, fixtureUuid number)
      environment =
        AppEnv
          (StoreConfig root 2_000_000 20_000)
          (Actor "human" "test")
          (pure fixedTime)
          (pure (utcToZonedTime (hoursToTimeZone (-3)) fixedTime))
          allocate
          emptyExportPort
  action environment

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command = assertRight =<< runAppCommand environment False (const (pure ())) command

answer :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answer environment envelope action =
  run environment (RespondCommand (response envelope action)) >>= interactionOf

submit :: AppEnv -> InteractionEnvelope -> Text -> Text -> IO InteractionEnvelope
submit environment envelope action text =
  run environment (SubmitInteractionTextCommand (response envelope action) text) >>= interactionOf

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other)

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

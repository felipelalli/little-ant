module Main (main) where

import Data.ByteString qualified as ByteString
import Data.IORef
import Data.List qualified
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
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.RecurrenceInput (RecurrenceField (..))
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
      , testCase "recurrence editor records a weekly obligation with due offsets" recurrenceEditorWeekly
      , testCase "recurrence editor rejects prose, RRULE, and unknown zones" recurrenceEditorRejectsProse
      , testCase "recurrence editor records a lapsing policy with its consequence" recurrenceEditorLapses
      , testCase "lapsing occurrences close as missed and can be done late or excused" lapsingOccurrences
      , testCase "a stays-open series keeps unfinished occurrences as debt" staysOpenKeepsDebt
      , testCase "escalated occurrences come first by deadline and a skip pauses one" escalatedFirst
      , testCase "the agenda lists dated facts by day with projections and a calendar" agendaOutlook
      , testCase "the agenda lists habit slots with their own kind and calendar mark" agendaHabits
      , testCase "the agenda lists a quota habit at its close with its progress" agendaQuotaHabit
      , testCase "the agenda's past shows misses, late completions, and excuses on their own days" agendaPastOccurrences
      , testCase "the agenda's past shows closed habit slots as done or missed" agendaPastHabits
      , testCase "the agenda's past shows every completion as done or done late" agendaPastCompletions
      , testCase "done at an earlier time dates the completion in one command, never in the future" doneAtEarlierTime
      , testCase "completed Work takes an earlier completion time through a preview" completionDateFlow
      , testCase "recurrence is offered only for a recurring-obligation series" recurrenceEntryPoints
      , testCase "raw detail classifies one exact Inbox Raw" rawDetailClassify
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

agendaHabits :: Assertion
agendaHabits = withHarness $ \environment -> do
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
  listed <- run environment (ListCommand (Just "agenda") (Just 3) Nothing)
  case listed of
    ListResult{resultListEntries, resultListHeader} -> do
      [(listEntryDay row, listEntryKind row) | row@AgendaListRow{} <- resultListEntries]
        @?= [("Mon, Aug 3", "habit"), ("Tue, Aug 4", "habit"), ("Wed, Aug 5", "habit")]
      [listEntryDetails row | row@AgendaListRow{} <- take 2 resultListEntries]
        @?= ["Mon, Aug 3 \183 08:00 \183 habit \183 until 10:00 \183 projected", "Tue, Aug 4 \183 08:00 \183 habit \183 until 10:00 \183 projected"]
      assertBool ("habit days lack their mark: " <> show resultListHeader) (any (Text.isInfixOf " 4\9702  5\9702") resultListHeader)
      last resultListHeader @?= agendaLegend
    other -> assertFailure ("expected the agenda, got " <> show other)

agendaQuotaHabit :: Assertion
agendaQuotaHabit = withHarness $ \environment -> do
  seedBrick environment Habit
  _ <- run environment (SetHabitScheduleCommand (QuotaWindowHabit brickIdValue 3 1 ReturnWeeks (fromGregorian 2026 8 3) "America/Montevideo" Nothing 0))
  listed <- run environment (ListCommand (Just "agenda") (Just 15) Nothing)
  case listed of
    ListResult{resultListEntries} ->
      [(listEntryDay row, listEntryKind row, listEntryDetails row) | row@AgendaListRow{} <- resultListEntries]
        @?= [ ("Mon, Aug 10", "habit due", "Mon, Aug 10 \183 04:00 \183 habit due \183 0/3 done \183 projected")
            , ("Mon, Aug 17", "habit due", "Mon, Aug 17 \183 04:00 \183 habit due \183 0/3 done \183 projected")
            ]
    other -> assertFailure ("expected the agenda, got " <> show other)

agendaPastOccurrences :: Assertion
agendaPastOccurrences = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  -- Daily at 18:00 in Montevideo with a lapsing deadline: at the fixed clock
  -- (Mon Aug 3, 09:00 local) Aug 1 and Aug 2 are missed.
  let schedule =
        RecurrenceSchedule
          brickIdValue
          (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 1) Set.empty Nothing Nothing [TimeOfDay 18 0 0])
          "America/Montevideo"
          AtomicTask
          Nothing
          (-86400)
          Nothing
          (Just 0)
          DeadlineLapses
          Nothing
          0
  _ <- run environment (SetRecurrenceScheduleCommand schedule)
  _ <- run environment TickCommand
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
      handleOf occurrence = "#" <> unHandle (brickHandle (stateBricks state Map.! recurringOccurrenceBrick occurrence))
  (newest, middle, oldest) <- case seriesOccurrences state brickIdValue of
    [first, second, third] -> pure (first, second, third)
    other -> assertFailure ("expected three occurrences, got " <> show other)
  missed <- run environment (ShowRawCommand (handleOf middle) GuidedView) >>= interactionOf
  _ <- answer environment missed "occurrence.done_late"
  oldestScreen <- run environment (ShowRawCommand (handleOf oldest) GuidedView) >>= interactionOf
  reason <- answer environment oldestScreen "occurrence.excuse"
  _ <- submit environment reason "occurrence.excuse.submit" "vacation"
  -- Excusing today's open occurrence leaves Aug 3 without a deadline.
  newestScreen <- run environment (ShowRawCommand (handleOf newest) GuidedView) >>= interactionOf
  newestReason <- answer environment newestScreen "occurrence.excuse"
  _ <- submit environment newestReason "occurrence.excuse.submit" ""
  -- Without past days the agenda starts now.
  current <- run environment (ListCommand (Just "agenda") (Just 2) Nothing)
  case current of
    ListResult{resultListEntries} -> assertBool "the default agenda shows the past" (all ((/= "missed") . listEntryKind) [row | row@AgendaListRow{} <- resultListEntries])
    other -> assertFailure ("expected the agenda, got " <> show other)
  listed <- run environment (ListCommand (Just "agenda") (Just 2) (Just 5))
  case listed of
    ListResult{resultListEntries, resultListHeader} -> do
      [(listEntryDay row, listEntryHandle row, listEntryKind row) | row@AgendaListRow{} <- take 4 resultListEntries]
        @?= [ ("Sat, Aug 1", handleOf oldest, "missed")
            , ("Sun, Aug 2", handleOf middle, "missed")
            , ("Mon, Aug 3", handleOf middle, "done late")
            , ("Mon, Aug 3", handleOf oldest, "excused")
            ]
      [listEntryDetails row | row@AgendaListRow{} <- take 1 (drop 3 resultListEntries)] @?= ["Mon, Aug 3 \183 09:00 \183 excused \183 vacation"]
      take 1 resultListHeader @?= ["Today: Mon, Aug 3, 2026"]
      -- The window reaches back into July, so its grid comes first.
      take 1 (drop 2 resultListHeader) @?= ["           July 2026"]
      assertBool ("missed days lack their mark: " <> show resultListHeader) (any (Text.isInfixOf " 1\215  2\215") resultListHeader)
      assertBool ("the late completion lacks its mark: " <> show resultListHeader) (any (Text.isInfixOf " 3.  4!") resultListHeader)
      last resultListHeader @?= agendaLegend
    other -> assertFailure ("expected the agenda, got " <> show other)

agendaPastHabits :: Assertion
agendaPastHabits = withHarness $ \environment -> do
  seedBrick environment Habit
  let schedule =
        FixedSlotHabit
          brickIdValue
          (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 1) Set.empty Nothing Nothing [TimeOfDay 8 0 0])
          "America/Montevideo"
          3600
          Nothing
          0
  _ <- run environment (SetHabitScheduleCommand schedule)
  _ <- run environment TickCommand
  listed <- run environment (ListCommand (Just "agenda") (Just 1) (Just 3))
  case listed of
    ListResult{resultListEntries} ->
      [(listEntryDay row, listEntryKind row) | row@AgendaListRow{} <- resultListEntries]
        @?= [("Sat, Aug 1", "habit missed"), ("Sun, Aug 2", "habit missed"), ("Mon, Aug 3", "habit missed")]
    other -> assertFailure ("expected the agenda, got " <> show other)

agendaPastCompletions :: Assertion
agendaPastCompletions = withHarness $ \environment -> do
  seedBrickAs environment (fixtureUuid 40) (Handle "late") "Late work" AtomicTask 50
  seedBrickAs environment (fixtureUuid 60) (Handle "early") "Early work" AtomicTask 70
  seedBrickAs environment (fixtureUuid 80) (Handle "undated") "Undated work" AtomicTask 90
  setTemporal environment (fixtureUuid 40) Nothing (Just (ZonedInstant (UTCTime (fromGregorian 2026 8 1) 0) "America/Montevideo")) 100
  setTemporal environment (fixtureUuid 60) Nothing (Just (ZonedInstant (UTCTime (fromGregorian 2026 8 10) 0) "America/Montevideo")) 110
  mapM_ (run environment . DoneCommand . Just) ["#late", "#early", "#undated"]
  listed <- run environment (ListCommand (Just "agenda") (Just 1) (Just 1))
  case listed of
    ListResult{resultListEntries} ->
      -- Every completion is a dated fact; the order is time, then handle.
      [(listEntryHandle row, listEntryKind row) | row@AgendaListRow{} <- resultListEntries] @?= [("#early", "done"), ("#late", "done late"), ("#undated", "done")]
    other -> assertFailure ("expected the agenda, got " <> show other)

doneAtEarlierTime :: Assertion
doneAtEarlierTime = withHarness $ \environment -> do
  -- The fixed clock is Mon Aug 3, 09:00 at UTC-3; the deadline was Aug 1.
  seedBrickAs environment (fixtureUuid 40) (Handle "late") "Late work" AtomicTask 50
  setTemporal environment (fixtureUuid 40) Nothing (Just (ZonedInstant (UTCTime (fromGregorian 2026 8 1) 0) "America/Montevideo")) 100
  future <- runAppCommand environment False (const (pure ())) (DoneAtCommand "#late" "2026-08-04 10:00")
  either (\problem -> appErrorCode problem @?= InvalidInput) (\other -> assertFailure ("a future completion was accepted: " <> show other)) future
  malformed <- runAppCommand environment False (const (pure ())) (DoneAtCommand "#late" "last friday")
  either (\problem -> appErrorCode problem @?= InvalidInput) (\other -> assertFailure ("prose was accepted: " <> show other)) malformed
  _ <- run environment (DoneAtCommand "#late" "2026-07-31 15:00")
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  brickStatus (stateBricks state Map.! fixtureUuid 40) @?= BrickDone
  Map.lookup (fixtureUuid 40) (stateBrickCompletedAt state) @?= Just (UTCTime (fromGregorian 2026 7 31) (secondsToDiffTime (18 * 3600)))
  -- Before the deadline, so the agenda says done, on its own day.
  listed <- run environment (ListCommand (Just "agenda") (Just 1) (Just 5))
  case listed of
    ListResult{resultListEntries} -> [(listEntryDay row, listEntryKind row) | row@AgendaListRow{} <- resultListEntries] @?= [("Fri, Jul 31", "done")]
    other -> assertFailure ("expected the agenda, got " <> show other)
  -- A date alone keeps the current clock time and also dates done Work.
  _ <- run environment (DoneAtCommand "#late" "2026-08-02")
  again <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  Map.lookup (fixtureUuid 40) (stateBrickCompletedAt (loadedState again)) @?= Just (UTCTime (fromGregorian 2026 8 2) (secondsToDiffTime (12 * 3600)))

completionDateFlow :: Assertion
completionDateFlow = withHarness $ \environment -> do
  seedBrickAs environment (fixtureUuid 40) (Handle "met") "Meet the team" AtomicTask 50
  completed <- run environment (DoneCommand (Just "#met")) >>= interactionOf
  fmap actionId (envelopeActions completed) @?= ["next", "completion.earlier", "palette.open"]
  asked <- answer environment completed "completion.earlier"
  envelopeOpportunity asked @?= CompletionDateOpportunity (fixtureUuid 40) (LocalTime (fromGregorian 2026 8 3) (TimeOfDay 9 0 0))
  fmap actionLabel (take 3 (envelopeActions asked)) @?= ["yesterday \183 Sun, Aug 2, 2026 \183 09:00", "2 days ago \183 Sat, Aug 1, 2026 \183 09:00", "3 days ago \183 Fri, Jul 31, 2026 \183 09:00"]
  rejected <- runAppCommand environment False (const (pure ())) (SubmitInteractionTextCommand (response asked "completion.date.submit") "2026-08-03 10:00")
  either (\problem -> appErrorCode problem @?= InvalidInput) (\other -> assertFailure ("a future time was previewed: " <> show other)) rejected
  preview <- submit environment asked "completion.date.submit" "2026-07-30 15:30"
  envelopeOpportunity preview @?= CompletionDatePreviewOpportunity (fixtureUuid 40) (UTCTime (fromGregorian 2026 7 30) (secondsToDiffTime (18 * 3600 + 1800)))
  take 1 (contentBody (envelopeContent preview)) @?= ["Thu, Jul 30, 2026 \183 15:30"]
  -- Nothing is recorded before yes.
  before <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  Map.lookup (fixtureUuid 40) (stateBrickCompletedAt (loadedState before)) @?= Just (UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600)))
  dated <- answer environment preview "completion.date.accept"
  envelopeOpportunity dated @?= CompletionDatedResultOpportunity (fixtureUuid 40)
  contentBody (envelopeContent dated) @?= ["#met \"Meet the team\"", "Thu, Jul 30, 2026 \183 15:30"]
  -- Undo restores the recorded time.
  _ <- run environment UndoCommand
  undone <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  Map.lookup (fixtureUuid 40) (stateBrickCompletedAt (loadedState undone)) @?= Just (UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600)))
  _ <- run environment RedoCommand
  -- The update hub offers it for completed Work only.
  hub <- run environment (UpdateCommand "#met" Nothing) >>= interactionOf
  assertBool "the update hub lacks when done" ("update.done_at" `elem` fmap actionId (envelopeActions hub))
  seedBrickAs environment (fixtureUuid 60) (Handle "open") "Open work" AtomicTask 70
  openHub <- run environment (UpdateCommand "#open" Nothing) >>= interactionOf
  assertBool "active Work offers when done" ("update.done_at" `notElem` fmap actionId (envelopeActions openHub))

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
          DeadlineStaysOpen
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

recurrenceEditorWeekly :: Assertion
recurrenceEditorWeekly = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  family <- run environment (UpdateCommand "#standing" (Just "repetition")) >>= interactionOf
  case envelopeOpportunity family of
    RecurrenceFieldOpportunity identity RecurrenceFamilyField _ _ -> identity @?= brickIdValue
    other -> assertFailure ("expected the recurrence family field, got " <> show other)
  occurrence <- answer environment family "recurrence.family.weekly"
  every <- answer environment occurrence "recurrence.occurrence.atomic"
  weekdays <- submit environment every "recurrence.field.submit" "1"
  times <- submit environment weekdays "recurrence.field.submit" "fri"
  zone <- submit environment times "recurrence.field.submit" "18:00"
  opens <- submit environment zone "recurrence.field.submit" "America/Sao_Paulo"
  bestBefore <- submit environment opens "recurrence.field.submit" "5 days before"
  deadline <- submit environment bestBefore "recurrence.field.submit" "2 days before"
  policy <- submit environment deadline "recurrence.field.submit" "at the anchor"
  case envelopeOpportunity policy of
    RecurrenceFieldOpportunity _ RecurrencePolicyField _ _ -> pure ()
    other -> assertFailure ("expected the At deadline field, got " <> show other)
  preview <- answer environment policy "recurrence.policy.stays_open"
  case envelopeOpportunity preview of
    RecurrencePreviewOpportunity identity _ -> identity @?= brickIdValue
    other -> assertFailure ("expected the recurrence preview, got " <> show other)
  let body = contentBody (envelopeContent preview)
  assertBool ("preview lacks the first anchor: " <> show body) $
    ["Fri, Aug 7 2026, 18:00", "  opens Aug 2, 18:00 · best before Aug 5, 18:00 · deadline Aug 7, 18:00"] `Data.List.isInfixOf` body
  assertBool ("preview lacks the third anchor: " <> show body) ("Fri, Aug 21 2026, 18:00" `elem` body)
  receipt <- answer environment preview "recurrence.accept"
  envelopeOpportunity receipt @?= RecurrenceResultOpportunity brickIdValue
  assertBool ("receipt does not list the released occurrence: " <> show (contentBody (envelopeContent receipt))) $
    any ("Fri, Aug 7 2026" `Text.isSuffixOf`) (contentBody (envelopeContent receipt))
  -- The release happened with the receipt, so answering it is not stale.
  afterReceipt <- answer environment receipt "next"
  case envelopeOpportunity afterReceipt of
    FocusProposalOpportunity{} -> pure ()
    other -> assertFailure ("expected the released occurrence to be drawn, got " <> show other)
  assertBool ("occurrence context lacks its label and deadline: " <> show (contentBody (envelopeContent afterReceipt))) $
    "Occurrence: Fri, Aug 7 2026 · deadline Fri, Aug 7, 18:00" `elem` contentBody (envelopeContent afterReceipt)
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  case Map.lookup brickIdValue (stateRecurrenceSchedules state) of
    Just schedule -> do
      calendarFamily (recurrenceRule schedule) @?= WeeklyRecurrence
      calendarWeekdays (recurrenceRule schedule) @?= Set.singleton Friday
      calendarIntendedDay (recurrenceRule schedule) @?= Nothing
      calendarTimes (recurrenceRule schedule) @?= [TimeOfDay 18 0 0]
      calendarStartsOn (recurrenceRule schedule) @?= fromGregorian 2026 8 3
      recurrenceZone schedule @?= "America/Sao_Paulo"
      recurrenceNotBeforeOffsetSeconds schedule @?= -(5 * 86400)
      recurrenceBestBeforeOffsetSeconds schedule @?= Just (-(2 * 86400))
      recurrenceDeadlineOffsetSeconds schedule @?= Just 0
    Nothing -> assertFailure "the accepted recurrence was not recorded"
  ticked <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let tickedState = loadedState ticked
  case Map.elems (stateRecurringOccurrences tickedState) of
    [released] -> do
      zonedInstantUtc (recurringOccurrenceNominalAnchor released) @?= UTCTime (fromGregorian 2026 8 7) (secondsToDiffTime (21 * 3600))
      fmap zonedInstantUtc (temporalDeadline =<< Map.lookup (recurringOccurrenceBrick released) (stateTemporalConstraints tickedState))
        @?= Just (UTCTime (fromGregorian 2026 8 7) (secondsToDiffTime (21 * 3600)))
    other -> assertFailure ("expected exactly the open Aug 7 occurrence, got " <> show other)

recurrenceEditorLapses :: Assertion
recurrenceEditorLapses = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  family <- run environment (UpdateCommand "#standing" (Just "repetition")) >>= interactionOf
  occurrence <- answer environment family "recurrence.family.weekly"
  every <- answer environment occurrence "recurrence.occurrence.atomic"
  weekdays <- submit environment every "recurrence.field.submit" "1"
  times <- submit environment weekdays "recurrence.field.submit" "fri"
  zone <- submit environment times "recurrence.field.submit" "18:00"
  opens <- submit environment zone "recurrence.field.submit" "America/Sao_Paulo"
  bestBefore <- submit environment opens "recurrence.field.submit" "114 hours before"
  deadline <- submit environment bestBefore "recurrence.field.submit" "2 days before"
  policy <- submit environment deadline "recurrence.field.submit" "at the anchor"
  consequence <- answer environment policy "recurrence.policy.lapses"
  case envelopeOpportunity consequence of
    RecurrenceFieldOpportunity _ RecurrenceConsequenceField _ _ -> pure ()
    other -> assertFailure ("expected the Consequence field, got " <> show other)
  tooLong <- runAppCommand environment False (const (pure ())) (SubmitInteractionTextCommand (response consequence "recurrence.field.submit") (Text.replicate 201 "x"))
  either (\problem -> appErrorCode problem @?= InvalidInput) (\other -> assertFailure ("expected a long consequence to be rejected, got " <> show other)) tooLong
  preview <- submit environment consequence "recurrence.field.submit" "Attendance is reported to HR"
  let body = contentBody (envelopeContent preview)
  assertBool ("preview lacks the policy: " <> show body) ("At deadline › counts as missed" `elem` body)
  assertBool ("preview lacks the consequence: " <> show body) ("Consequence › Attendance is reported to HR" `elem` body)
  assertBool ("preview lacks the policy sentence: " <> show body) ("A period not done by its deadline counts as missed." `elem` body)
  _ <- answer environment preview "recurrence.accept"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  case Map.lookup brickIdValue (stateRecurrenceSchedules (loadedState loaded)) of
    Just schedule -> do
      recurrenceDeadlinePolicy schedule @?= DeadlineLapses
      recurrenceConsequence schedule @?= Just "Attendance is reported to HR"
    Nothing -> assertFailure "the lapsing recurrence was not recorded"

lapsingOccurrences :: Assertion
lapsingOccurrences = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  -- Daily at 18:00 in Montevideo (21:00 UTC), opening a day early: at the
  -- fixed 12:00 UTC clock Aug 1 and Aug 2 are past their deadline and Aug 3
  -- is open.
  let schedule =
        RecurrenceSchedule
          brickIdValue
          (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 1) Set.empty Nothing Nothing [TimeOfDay 18 0 0])
          "America/Montevideo"
          AtomicTask
          Nothing
          (-86400)
          Nothing
          (Just 0)
          DeadlineLapses
          (Just "Attendance is reported to HR")
          0
  _ <- run environment (SetRecurrenceScheduleCommand schedule)
  ticked <- run environment TickCommand
  case ticked of
    TickResult{resultReleasedOccurrences = 3, resultLapsedOccurrences = 2} -> pure ()
    other -> assertFailure ("expected three releases and two misses, got " <> show other)
  afterTick <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState afterTick
  (newest, middle, oldest) <- case seriesOccurrences state brickIdValue of
    [first, second, third] -> pure (first, second, third)
    other -> assertFailure ("expected three occurrences, got " <> show other)
  let deadlineOf day = UTCTime (fromGregorian 2026 8 day) (secondsToDiffTime (21 * 3600))
  fmap (obligationPeriodState state . recurringOccurrenceId) [newest, middle, oldest] @?= [PeriodOpen, PeriodMissed, PeriodMissed]
  fmap obligationPeriodMissedAt (Map.lookup (recurringOccurrenceId oldest) (stateObligationPeriods state)) @?= Just (Just (deadlineOf 1))
  brickStatus (stateBricks state Map.! recurringOccurrenceBrick middle) @?= BrickMissed
  again <- run environment TickCommand
  case again of
    TickResult{resultReleasedOccurrences = 0, resultLapsedOccurrences = 0} -> pure ()
    other -> assertFailure ("expected an idempotent tick, got " <> show other)
  let handleOf occurrence = "#" <> unHandle (brickHandle (stateBricks state Map.! recurringOccurrenceBrick occurrence))
  missed <- run environment (ShowRawCommand (handleOf middle) GuidedView) >>= interactionOf
  envelopeOpportunity missed @?= ObligationOccurrenceOpportunity (recurringOccurrenceId middle)
  contentHeading (envelopeContent missed) @?= "Missed:"
  assertBool ("missed screen lacks the consequence: " <> show (contentBody (envelopeContent missed))) $
    "Consequence: Attendance is reported to HR" `elem` contentBody (envelopeContent missed)
  fmap actionId (envelopeActions missed) @?= ["occurrence.done_late", "occurrence.excuse", "occurrence.unknown", "palette.open"]
  late <- answer environment missed "occurrence.done_late"
  envelopeOpportunity late @?= ObligationOutcomeResultOpportunity (recurringOccurrenceId middle)
  contentHeading (envelopeContent late) @?= "Done late:"
  oldestScreen <- run environment (ShowRawCommand (handleOf oldest) GuidedView) >>= interactionOf
  reason <- answer environment oldestScreen "occurrence.excuse"
  excused <- submit environment reason "occurrence.excuse.submit" "vacation"
  contentHeading (envelopeContent excused) @?= "Excused:"
  openScreen <- run environment (ShowRawCommand (handleOf newest) GuidedView) >>= interactionOf
  fmap actionId (envelopeActions openScreen) @?= ["occurrence.excuse", "occurrence.unknown", "palette.open"]
  openReason <- answer environment openScreen "occurrence.excuse"
  _ <- submit environment openReason "occurrence.excuse.submit" ""
  final <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let finalState = loadedState final
  fmap snd (obligationPeriodHistory finalState brickIdValue) @?= [PeriodExcused, PeriodDoneLate, PeriodExcused]
  obligationHistoryLine finalState brickIdValue @?= Just "History: [-][~][-]  ·  0 on time · 1 late · 0 missed · 2 excused"
  let oldestPeriod = stateObligationPeriods finalState Map.! recurringOccurrenceId oldest
  obligationPeriodMissedAt oldestPeriod @?= Just (deadlineOf 1)
  obligationPeriodExcuseReason oldestPeriod @?= Just "vacation"
  obligationPeriodExcuseReason (stateObligationPeriods finalState Map.! recurringOccurrenceId newest) @?= Nothing
  brickStatus (stateBricks finalState Map.! recurringOccurrenceBrick middle) @?= BrickDone
  brickStatus (stateBricks finalState Map.! recurringOccurrenceBrick newest) @?= BrickCancelled
  -- Neither late completion nor an excuse can repeat.
  repeated <- runAppCommand environment False (const (pure ())) (ShowRawCommand (handleOf middle) GuidedView) >>= either (assertFailure . show) interactionOf
  fmap actionId (envelopeActions repeated) @?= ["next", "occurrence.unknown", "palette.open"]

escalatedFirst :: Assertion
escalatedFirst = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  seedBrickAs environment (fixtureUuid 40) (Handle "plain") "Plain work" AtomicTask 50
  -- Daily at 18:00 in Montevideo, opening three days early with best before
  -- two days early: at 12:00 UTC on Aug 3 the Aug 3 and Aug 4 occurrences
  -- have escalated and the Aug 5 one has not.
  let schedule =
        RecurrenceSchedule
          brickIdValue
          (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 3) Set.empty Nothing Nothing [TimeOfDay 18 0 0])
          "America/Montevideo"
          AtomicTask
          Nothing
          (-(3 * 86400))
          (Just (-(2 * 86400)))
          (Just 0)
          DeadlineLapses
          Nothing
          0
  _ <- run environment (SetRecurrenceScheduleCommand schedule)
  _ <- run environment TickCommand
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  (aug5, aug4, aug3) <- case seriesOccurrences state brickIdValue of
    [first, second, third] -> pure (recurringOccurrenceBrick first, recurringOccurrenceBrick second, recurringOccurrenceBrick third)
    other -> assertFailure ("expected three occurrences, got " <> show other)
  first <- run environment NextCommand >>= interactionOf
  envelopeOpportunity first @?= FocusProposalOpportunity aug3 Nothing
  footerTimeLabel (envelopeFooter first) @?= "Due first"
  assertBool ("escalation reason missing: " <> show (footerTimeValue (envelopeFooter first))) $
    "best before passed · deadline " `Text.isPrefixOf` footerTimeValue (envelopeFooter first)
  symptom <- answer environment first "focus.skip"
  tired <- answer environment symptom "work.symptom.tired"
  receipt <- answer environment tired "work.reaction.skip"
  paused <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  [workDeferralCooldownUntil deferral | deferral <- Map.elems (stateWorkDeferrals (loadedState paused)), workDeferralBrick deferral == aug3]
    @?= [Just (addUTCTime (120 * 60) fixedTime)]
  second <- answer environment receipt "next"
  envelopeOpportunity second @?= FocusProposalOpportunity aug4 Nothing
  assertBool "the unescalated occurrence must not be offered first" (envelopeOpportunity second /= FocusProposalOpportunity aug5 Nothing)

agendaOutlook :: Assertion
agendaOutlook = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  seedBrickAs environment (fixtureUuid 40) (Handle "plain") "Plain work" AtomicTask 50
  -- The fixed clock is Mon Aug 3, 09:00 at UTC-3. Plain work was due Aug 1.
  setTemporal environment (fixtureUuid 40) Nothing (Just (ZonedInstant (UTCTime (fromGregorian 2026 8 1) 0) "America/Montevideo")) 60
  let schedule =
        RecurrenceSchedule
          brickIdValue
          (CalendarRule WeeklyRecurrence 1 (fromGregorian 2026 8 3) (Set.singleton Friday) Nothing Nothing [TimeOfDay 18 0 0])
          "America/Montevideo"
          AtomicTask
          Nothing
          (-(2 * 86400))
          (Just (-86400))
          (Just 0)
          DeadlineLapses
          Nothing
          0
  _ <- run environment (SetRecurrenceScheduleCommand schedule)
  listed <- run environment (ListCommand (Just "agenda") Nothing Nothing)
  case listed of
    ListResult{resultListEntries, resultListHeader, resultListCategories} -> do
      let summary = [(listEntryDay row, listEntryHandle row, listEntryKind row) | row@AgendaListRow{} <- resultListEntries]
      take 4 summary
        @?= [ ("Overdue", "#plain", "deadline")
            , ("Wed, Aug 5", "#standing", "opens")
            , ("Thu, Aug 6", "#standing", "best before")
            , ("Fri, Aug 7", "#standing", "deadline")
            ]
      assertBool ("the second Friday is not projected: " <> show summary) (("Fri, Aug 14", "#standing", "deadline") `elem` summary)
      assertBool "a projected row lacks its mark" (all (Text.isInfixOf "projected" . listEntryDetails) (filter ((== "#standing") . listEntryHandle) resultListEntries))
      assertBool ("the lapsing deadline lacks its consequence: " <> show resultListEntries) (any (Text.isInfixOf "deadline · counts as missed" . listEntryDetails) resultListEntries)
      take 5 resultListHeader @?= ["Today: Mon, Aug 3, 2026", "", "          August 2026", "Wk  Mo  Tu  We  Th  Fr  Sa  Su", "31                       1   2"]
      assertBool ("calendar marks are missing: " <> show resultListHeader) (any (Text.isInfixOf " 6•  7!  8") resultListHeader)
      last resultListHeader @?= agendaLegend
      [label | ListCategory label _ <- resultListCategories] @?= ["Without a category"]
      [label | ListCategory _ days <- resultListCategories, ListCategory label _ <- days] @?= ["Overdue", "Wed, Aug 5", "Thu, Aug 6", "Fri, Aug 7", "Wed, Aug 12", "Thu, Aug 13", "Fri, Aug 14", "Wed, Aug 19", "Thu, Aug 20", "Fri, Aug 21", "Wed, Aug 26", "Thu, Aug 27", "Fri, Aug 28", "Wed, Sep 2", "Thu, Sep 3", "Fri, Sep 4"]
      [listEntryDate row | row@AgendaListRow{} <- take 2 resultListEntries] @?= ["2026-07-31", "2026-08-05"]
    other -> assertFailure ("expected the agenda, got " <> show other)
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  Map.size (stateRecurringOccurrences (loadedState loaded)) @?= 0

staysOpenKeepsDebt :: Assertion
staysOpenKeepsDebt = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  let schedule =
        RecurrenceSchedule
          brickIdValue
          (CalendarRule DailyRecurrence 1 (fromGregorian 2026 8 1) Set.empty Nothing Nothing [TimeOfDay 8 0 0])
          "America/Montevideo"
          AtomicTask
          Nothing
          0
          Nothing
          (Just 0)
          DeadlineStaysOpen
          Nothing
          0
  _ <- run environment (SetRecurrenceScheduleCommand schedule)
  ticked <- run environment TickCommand
  case ticked of
    TickResult{resultReleasedOccurrences = 3, resultLapsedOccurrences = 0} -> pure ()
    other -> assertFailure ("expected three open debts, got " <> show other)
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  fmap (obligationPeriodState state . recurringOccurrenceId) (seriesOccurrences state brickIdValue) @?= [PeriodOpen, PeriodOpen, PeriodOpen]
  obligationHistoryLine state brickIdValue @?= Nothing

recurrenceEditorRejectsProse :: Assertion
recurrenceEditorRejectsProse = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  family <- run environment (UpdateCommand "#standing" (Just "repetition")) >>= interactionOf
  occurrence <- answer environment family "recurrence.family.weekly"
  every <- answer environment occurrence "recurrence.occurrence.atomic"
  rejected environment every "every other week"
  weekdays <- submit environment every "recurrence.field.submit" "2"
  rejected environment weekdays "FREQ=WEEKLY;BYDAY=FR"
  times <- submit environment weekdays "recurrence.field.submit" "mon, fri"
  rejected environment times "6pm"
  rejected environment times "18:00, 18:00"
  zone <- submit environment times "recurrence.field.submit" "09:00, 18:00"
  rejected environment zone "Mars/Olympus_Mons"
  opens <- submit environment zone "recurrence.field.submit" "America/Sao_Paulo"
  rejected environment opens "a few days before"
  rejected environment opens "7 days ahead"
 where
  rejected environment envelope text =
    runAppCommand environment False (const (pure ())) (SubmitInteractionTextCommand (response envelope "recurrence.field.submit") text) >>= \case
      Left problem -> appErrorCode problem @?= InvalidInput
      Right other -> assertFailure ("expected " <> show text <> " to be rejected, got " <> show other)

recurrenceEntryPoints :: Assertion
recurrenceEntryPoints = withHarness $ \environment -> do
  seedBrick environment RecurringObligation
  seedBrickAs environment (fixtureUuid 40) (Handle "plain") "Plain work" AtomicTask 50
  series <- run environment (UpdateCommand "#standing" Nothing) >>= interactionOf
  assertBool "series update hub lacks repetition" ("update.repetition" `elem` fmap actionId (envelopeActions series))
  plain <- run environment (UpdateCommand "#plain" Nothing) >>= interactionOf
  assertBool "plain update hub offers repetition" ("update.repetition" `notElem` fmap actionId (envelopeActions plain))
  runAppCommand environment False (const (pure ())) (UpdateCommand "#plain" (Just "repetition")) >>= \case
    Left problem -> appErrorCode problem @?= PreconditionFailed
    Right other -> assertFailure ("expected repetition to be refused for atomic Work, got " <> show other)
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
      brick = stateBricks state Map.! brickIdValue
      plainBrick = stateBricks state Map.! fixtureUuid 40
      rawOf owner = head [raw | raw <- Map.elems (stateRaws state), Map.lookup (rawId raw) (stateRawDispositions state) == Just (RawMaterializedAsWork owner)]
      zoned = utcToZonedTime (hoursToTimeZone (-3)) fixedTime
      created owner = makeWorkCreatedResultEnvelope (fixtureUuid 90) (loadedCursor loaded) (statePreconditionHash state) zoned state (rawOf (brickId owner)) owner
  take 1 (fmap actionId (envelopeActions (created brick))) @?= ["recurrence.set"]
  assertBool "plain Work is offered a recurrence" ("recurrence.set" `notElem` fmap actionId (envelopeActions (created plainBrick)))

rawDetailClassify :: Assertion
rawDetailClassify = withHarness $ \environment -> do
  _ <- run environment (FeedCommand "test" "Older Inbox material")
  _ <- run environment (FeedCommand "test" "Monthly onboarding interview")
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
      target = head [raw | raw <- Map.elems (stateRaws state), rawOriginal raw == "Monthly onboarding interview"]
      reference = "+" <> unHandle (rawHandle target)
  detail <- run environment (ShowRawCommand reference GuidedView) >>= interactionOf
  assertBool "Inbox Raw detail lacks classify" ("raw.detail.classify" `elem` fmap actionId (envelopeActions detail))
  triage <- answer environment detail "raw.detail.classify"
  case envelopeOpportunity triage of
    RawTriageOpportunity identity _ _ _ -> identity @?= rawId target
    other -> assertFailure ("expected triage of the exact Raw, got " <> show other)

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
  assertBool "overlap acquired an unsafe default" ((not . any actionDefault) (envelopeActions overlap))
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
      draft eventId =
        EventDraft
          eventId
          command
          actor
          fixedTime
          (statePreconditionHash (loadedState loaded))
          replay
      events =
        [ draft (head eventIds) (RawFedV1 (RawFed rawIdentity handle title "test" Nothing))
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
          emptyImportPort
          Nothing
          Nothing
          Nothing
          Nothing
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

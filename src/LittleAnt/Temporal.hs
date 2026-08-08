module LittleAnt.Temporal (
  buildTemporalTickPlan,
)
where

import Control.Exception (SomeException, displayException, try)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import Data.Time.Zones (TZ, loadTZFromDB)
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Model
import LittleAnt.Schedule
import LittleAnt.Time

{- | Derive the bounded, replayable work performed by one administrative tick.
The clock and timezone database are runtime facts; every resulting fact is
recorded as an ordinary event by 'decideTemporalTick'.
-}
buildTemporalTickPlan :: State -> UTCTime -> IO (Either AppError TemporalTickPlan)
buildTemporalTickPlan state now = do
  releases <- traverse (recurrenceFacts state now) (Map.elems (stateRecurrenceSchedules state))
  windows <- traverse (habitFacts state now) (Map.elems (stateHabitSchedules state))
  pure $ do
    dueReleases <- concat <$> sequence releases
    dueWindows <- concat <$> sequence windows
    let boundedReleases = take catchUpLimit (sortOn (zonedInstantUtc . releaseFactAnchor) dueReleases)
        boundedWindows = take catchUpLimit (sortOn (zonedInstantUtc . habitWindowFactOpensAt) dueWindows)
    pure
      TemporalTickPlan
        { temporalTickReleases = boundedReleases
        , temporalTickNewHabitWindows = boundedWindows
        , temporalTickHabitExpiries = existingHabitExpiries state now
        }

catchUpLimit :: Int
catchUpLimit = 1000

recurrenceFacts :: State -> UTCTime -> RecurrenceSchedule -> IO (Either AppError [RecurrenceReleaseFact])
recurrenceFacts state now schedule = withZone (recurrenceZone schedule) $ \zone -> do
  let horizon = addUTCTime (negate (fromInteger (recurrenceNotBeforeOffsetSeconds schedule))) now
  anchors <- calendarAnchorsThrough (recurrenceZone schedule) zone (recurrenceRule schedule) horizon
  pure
    [ makeRelease schedule anchor
    | anchor <- anchors
    , not (occurrenceExists state schedule anchor)
    ]

makeRelease :: RecurrenceSchedule -> CalendarAnchor -> RecurrenceReleaseFact
makeRelease schedule anchor =
  RecurrenceReleaseFact
    { releaseFactOwner = recurrenceOwner schedule
    , releaseFactAnchor = anchorInstant anchor
    , releaseFactLabel = Text.pack (show (anchorLocal anchor))
    , releaseFactTemporal = constraints
    , releaseFactInterval = interval
    }
 where
  anchored offset =
    ZonedInstant
      (addUTCTime (fromInteger offset) (zonedInstantUtc (anchorInstant anchor)))
      (recurrenceZone schedule)
  constraints =
    TemporalConstraints
      { temporalNotBefore = Just (anchored (recurrenceNotBeforeOffsetSeconds schedule))
      , temporalBestBefore = anchored <$> recurrenceBestBeforeOffsetSeconds schedule
      , temporalDeadline = anchored <$> recurrenceDeadlineOffsetSeconds schedule
      , temporalRevision = 1
      }
  interval = case recurrenceDurationSeconds schedule of
    Nothing -> Nothing
    Just duration -> Just (anchorInstant anchor, anchored duration)

occurrenceExists :: State -> RecurrenceSchedule -> CalendarAnchor -> Bool
occurrenceExists state schedule anchor =
  any sameOccurrence (Map.elems (stateRecurringOccurrences state))
 where
  sameOccurrence occurrence =
    recurringOccurrenceOwner occurrence == recurrenceOwner schedule
      && zonedInstantUtc (recurringOccurrenceNominalAnchor occurrence) == zonedInstantUtc (anchorInstant anchor)

habitFacts :: State -> UTCTime -> HabitSchedule -> IO (Either AppError [HabitWindowFact])
habitFacts state now schedule = withZone (habitScheduleZone schedule) $ \zone -> do
  candidates <- case schedule of
    FixedSlotHabit{} -> fixedWindows zone schedule now
    QuotaWindowHabit{} -> pure (quotaWindows state zone schedule now)
  pure
    [ HabitWindowFact
        { habitWindowFactOwner = habitScheduleOwner schedule
        , habitWindowFactOpensAt = opensAt
        , habitWindowFactClosesAt = closesAt
        , habitWindowFactTarget = target
        , habitWindowFactScheduleRevision = habitScheduleRevision schedule
        , habitWindowFactExpiredUnits = if zonedInstantUtc closesAt <= now then target else 0
        }
    | (opensAt, closesAt, target) <- candidates
    , not (habitWindowExists state schedule opensAt)
    ]

fixedWindows :: TZ -> HabitSchedule -> UTCTime -> Either AppError [(ZonedInstant, ZonedInstant, Int)]
fixedWindows zone schedule@FixedSlotHabit{} now = do
  anchors <- calendarAnchorsThrough (habitScheduleZone schedule) zone (habitFixedRule schedule) now
  pure
    [ (anchorInstant anchor, addSeconds (habitScheduleZone schedule) (habitSlotDurationSeconds schedule) (anchorInstant anchor), 1)
    | anchor <- anchors
    ]
fixedWindows _ _ _ = pure []

quotaWindows :: State -> TZ -> HabitSchedule -> UTCTime -> [(ZonedInstant, ZonedInstant, Int)]
quotaWindows state zone schedule@QuotaWindowHabit{} now =
  takeWhile
    ((<= now) . zonedInstantUtc . firstOfThree)
    [ let startLocal = addReturnOffset (habitQuotaUnit schedule) (index * habitQuotaSpan schedule) origin
          endLocal = addReturnOffset (habitQuotaUnit schedule) ((index + 1) * habitQuotaSpan schedule) origin
          (startUtc, _) = resolveLocalInstant zone startLocal
          (endUtc, _) = resolveLocalInstant zone endLocal
       in (ZonedInstant startUtc (habitScheduleZone schedule), ZonedInstant endUtc (habitScheduleZone schedule), habitQuotaTarget schedule)
    | index <- [0 .. 100000]
    ]
 where
  boundary = maybe (operationalHabitDayStartsAt (stateOperationalDayConfig state)) id (habitDayBoundary schedule)
  origin = LocalTime (habitQuotaStartsOn schedule) boundary
quotaWindows _ _ _ _ = []

firstOfThree :: (a, b, c) -> a
firstOfThree (first, _, _) = first

addSeconds :: Text -> Integer -> ZonedInstant -> ZonedInstant
addSeconds zone seconds instant =
  ZonedInstant (addUTCTime (fromInteger seconds) (zonedInstantUtc instant)) zone

habitWindowExists :: State -> HabitSchedule -> ZonedInstant -> Bool
habitWindowExists state schedule opensAt =
  any sameWindow (Map.elems (stateHabitWindows state))
 where
  sameWindow window =
    habitWindowOwner window == habitScheduleOwner schedule
      && zonedInstantUtc (habitWindowOpensAt window) == zonedInstantUtc opensAt

existingHabitExpiries :: State -> UTCTime -> [HabitExpiryFact]
existingHabitExpiries state now =
  [ HabitExpiryFact
      { habitExpiryWindow = habitWindowId window
      , habitExpiryOwner = habitWindowOwner window
      , habitExpiryUnits = missing
      , habitExpiryOutcome = StandingUnfulfilled
      }
  | window <- Map.elems (stateHabitWindows state)
  , not (habitWindowSettled window)
  , zonedInstantUtc (habitWindowClosesAt window) <= now
  , let recorded =
          length
            [ ()
            | outcome <- Map.elems (stateHabitOutcomes state)
            , habitOutcomeWindow outcome == habitWindowId window
            ]
        missing = max 0 (habitWindowTarget window - recorded)
  , missing > 0
  ]

withZone :: Text -> (TZ -> Either AppError value) -> IO (Either AppError value)
withZone zoneName use = do
  loaded <- try (loadTZFromDB (Text.unpack zoneName))
  pure $ case loaded of
    Left problem ->
      Left
        (appError CorruptData "A recorded IANA timezone could not be loaded.")
          { appErrorSubject = Just zoneName
          , appErrorDetails = [Text.pack (displayException (problem :: SomeException))]
          , appErrorRecovery = [RecoveryAction "set-timezone" "Choose an installed IANA timezone and retry." Nothing]
          }
    Right zone -> use zone

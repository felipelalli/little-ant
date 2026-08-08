module LittleAnt.Schedule (
  CalendarAnchor (..),
  calendarAnchorsThrough,
  operationalDay,
  validateCalendarRule,
)
where

import Control.Monad (unless, when)
import Data.List (nub, sort)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import Data.Time.Zones
import LittleAnt.Error
import LittleAnt.Model
import LittleAnt.Time

data CalendarAnchor = CalendarAnchor
  { anchorLocal :: LocalTime
  , anchorInstant :: ZonedInstant
  , anchorResolution :: LocalResolution
  }
  deriving stock (Eq, Show)

validateCalendarRule :: CalendarRule -> Either AppError ()
validateCalendarRule rule = do
  unless (calendarEvery rule > 0) $ invalid "A calendar recurrence interval must be positive."
  unless (not (null (calendarTimes rule)) && length (calendarTimes rule) == length (nub (calendarTimes rule))) $
    invalid "A calendar recurrence needs one or more distinct local times."
  case calendarFamily rule of
    DailyRecurrence -> pure ()
    WeeklyRecurrence -> unless (not (Set.null (calendarWeekdays rule))) (invalid "A weekly recurrence needs at least one weekday.")
    MonthlyRecurrence -> validateDay
    YearlyRecurrence -> do
      validateDay
      case calendarIntendedMonth rule of
        Just month | month >= 1 && month <= 12 -> pure ()
        _ -> invalid "A yearly recurrence needs an intended month from 1 through 12."
 where
  invalid = Left . appError InvalidInput
  validateDay = case calendarIntendedDay rule of
    Just day | day >= 1 && day <= 31 -> pure ()
    _ -> invalid "A monthly or yearly recurrence needs an intended day from 1 through 31."

calendarAnchorsThrough :: Text -> TZ -> CalendarRule -> UTCTime -> Either AppError [CalendarAnchor]
calendarAnchorsThrough zoneName zone rule now = do
  validateCalendarRule rule
  let lastDay = localDay (utcToLocalTimeTZ zone now)
      days
        | lastDay < calendarStartsOn rule = []
        | otherwise = [calendarStartsOn rule .. lastDay]
      locals =
        [ LocalTime day clock
        | day <- days
        , matches rule day
        , clock <- sort (calendarTimes rule)
        ]
      anchors = fmap resolve locals
  pure (filter ((<= now) . zonedInstantUtc . anchorInstant) anchors)
 where
  resolve local =
    let (instant, resolution) = resolveLocalInstant zone local
     in CalendarAnchor local (ZonedInstant instant zoneName) resolution

matches :: CalendarRule -> Day -> Bool
matches rule day =
  day >= calendarStartsOn rule && case calendarFamily rule of
    DailyRecurrence -> dayDistance `mod` fromIntegral (calendarEvery rule) == 0
    WeeklyRecurrence ->
      (dayDistance `div` 7) `mod` fromIntegral (calendarEvery rule) == 0
        && dayOfWeek day `Set.member` calendarWeekdays rule
    MonthlyRecurrence ->
      monthDistance `mod` calendarEvery rule == 0
        && gregorianDay == clippedDay year month intendedDay
    YearlyRecurrence ->
      (year - startYear) `mod` fromIntegral (calendarEvery rule) == 0
        && month == intendedMonth
        && gregorianDay == clippedDay year month intendedDay
 where
  dayDistance = diffDays day (calendarStartsOn rule)
  (year, month, gregorianDay) = toGregorian day
  (startYear, startMonth, _) = toGregorian (calendarStartsOn rule)
  monthDistance = fromIntegral ((year - startYear) * 12) + month - startMonth
  intendedDay = maybe 1 id (calendarIntendedDay rule)
  intendedMonth = maybe startMonth id (calendarIntendedMonth rule)

clippedDay :: Integer -> Int -> Int -> Int
clippedDay year month intended = min intended (gregorianMonthLength year month)

operationalDay :: TZ -> TimeOfDay -> UTCTime -> Day
operationalDay zone boundary instant =
  let local = utcToLocalTimeTZ zone instant
   in if localTimeOfDay local < boundary then addDays (-1) (localDay local) else localDay local

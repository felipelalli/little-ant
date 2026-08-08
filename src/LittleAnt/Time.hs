module LittleAnt.Time (
  LocalResolution (..),
  addReturnOffset,
  resolveLocalInstant,
  resolveReturnInstant,
)
where

import Data.Time
import Data.Time.Zones
import LittleAnt.Model

data LocalResolution = UniqueLocalTime | GapShiftedForward | FoldEarlier
  deriving stock (Eq, Ord, Show)

addReturnOffset :: ReturnUnit -> Int -> LocalTime -> LocalTime
addReturnOffset unit amount local =
  local{localDay = advanceDay unit amount (localDay local)}
 where
  advanceDay ReturnDays value = addDays (fromIntegral value)
  advanceDay ReturnWeeks value = addDays (fromIntegral (7 * value))
  advanceDay ReturnMonths value = addGregorianMonthsClip (fromIntegral value)
  advanceDay ReturnYears value = addGregorianYearsClip (fromIntegral value)

resolveReturnInstant :: TZ -> UTCTime -> ReturnUnit -> Int -> (UTCTime, LocalResolution)
resolveReturnInstant zone completedAt unit amount =
  resolveLocalInstant zone targetLocal
 where
  targetLocal = addReturnOffset unit amount (utcToLocalTimeTZ zone completedAt)

resolveLocalInstant :: TZ -> LocalTime -> (UTCTime, LocalResolution)
resolveLocalInstant zone targetLocal =
  case localTimeToUTCFull zone targetLocal of
    LTUUnique result _ -> (result, UniqueLocalTime)
    LTUNone result _ -> (result, GapShiftedForward)
    LTUAmbiguous first _ _ _ -> (first, FoldEarlier)

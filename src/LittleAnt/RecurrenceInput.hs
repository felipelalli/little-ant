{- | Structured, finite input for one recurring-obligation schedule (UX-RO01).

The editor walks a complete 'RecurrenceSchedule' draft one field at a time.
Every field accepts only numbers, finite tokens, or the closed offset grammar
below; no field accepts cron, RRULE, or recurrence prose.
-}
module LittleAnt.RecurrenceInput (
  RecurrenceField (..),
  applyRecurrenceInput,
  defaultRecurrenceSchedule,
  nextRecurrenceField,
  normalizeRecurrenceSchedule,
  parseRecurrenceFieldCode,
  recurrenceFamilyName,
  recurrenceFieldCode,
  recurrenceFieldDraft,
  recurrenceFieldIsChoice,
  recurrenceFieldLabel,
  recurrenceFieldPrompt,
  recurrenceFieldValue,
  recurrenceFields,
  recurrenceOccurrenceName,
  renderRecurrenceOffset,
  setRecurrenceDeadlinePolicy,
  setRecurrenceFamily,
  deadlinePolicyName,
  deadlinePolicySentence,
  setRecurrenceOccurrenceNature,
)
where

import Data.Char (isDigit, isSpace)
import Data.List (nub, sort)
import Data.Maybe (fromMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Error
import LittleAnt.Id (UUIDv7)
import LittleAnt.Model

data RecurrenceField
  = RecurrenceFamilyField
  | RecurrenceOccurrenceField
  | RecurrenceEveryField
  | RecurrenceWeekdaysField
  | RecurrenceMonthField
  | RecurrenceDayField
  | RecurrenceTimesField
  | RecurrenceZoneField
  | RecurrenceDurationField
  | RecurrenceOpensField
  | RecurrenceBestBeforeField
  | RecurrenceDeadlineField
  | RecurrencePolicyField
  | RecurrenceConsequenceField
  deriving stock (Bounded, Enum, Eq, Ord, Show)

-- | A new weekly atomic series anchored on @today@, with no due offsets.
defaultRecurrenceSchedule :: UUIDv7 -> Text -> Day -> RecurrenceSchedule
defaultRecurrenceSchedule owner zone today =
  RecurrenceSchedule
    { recurrenceOwner = owner
    , recurrenceRule =
        CalendarRule
          { calendarFamily = WeeklyRecurrence
          , calendarEvery = 1
          , calendarStartsOn = today
          , calendarWeekdays = Set.singleton (dayOfWeek today)
          , calendarIntendedDay = Nothing
          , calendarIntendedMonth = Nothing
          , calendarTimes = [TimeOfDay 9 0 0]
          }
    , recurrenceZone = zone
    , recurrenceOccurrenceNature = AtomicTask
    , recurrenceDurationSeconds = Nothing
    , recurrenceNotBeforeOffsetSeconds = 0
    , recurrenceBestBeforeOffsetSeconds = Nothing
    , recurrenceDeadlineOffsetSeconds = Nothing
    , recurrenceDeadlinePolicy = DeadlineStaysOpen
    , recurrenceConsequence = Nothing
    , recurrenceRevision = 0
    }

-- | The fields required by WRK-148 for this draft, in editor order.
recurrenceFields :: RecurrenceSchedule -> [RecurrenceField]
recurrenceFields schedule =
  [RecurrenceFamilyField, RecurrenceOccurrenceField, RecurrenceEveryField]
    <> familyFields
    <> [RecurrenceTimesField, RecurrenceZoneField]
    <> [RecurrenceDurationField | recurrenceOccurrenceNature schedule == ScheduledCommitment]
    <> [RecurrenceOpensField, RecurrenceBestBeforeField, RecurrenceDeadlineField]
    <> [RecurrencePolicyField | Just _ <- [recurrenceDeadlineOffsetSeconds schedule]]
    <> [RecurrenceConsequenceField | recurrenceDeadlinePolicy schedule == DeadlineLapses]
 where
  familyFields = case calendarFamily (recurrenceRule schedule) of
    DailyRecurrence -> []
    WeeklyRecurrence -> [RecurrenceWeekdaysField]
    MonthlyRecurrence -> [RecurrenceDayField]
    YearlyRecurrence -> [RecurrenceMonthField, RecurrenceDayField]

nextRecurrenceField :: RecurrenceSchedule -> RecurrenceField -> Maybe RecurrenceField
nextRecurrenceField schedule field = case dropWhile (/= field) (recurrenceFields schedule) of
  _ : next : _ -> Just next
  _ -> Nothing

recurrenceFieldIsChoice :: RecurrenceField -> Bool
recurrenceFieldIsChoice field = field `elem` [RecurrenceFamilyField, RecurrenceOccurrenceField, RecurrencePolicyField]

recurrenceFieldCode :: RecurrenceField -> Text
recurrenceFieldCode = \case
  RecurrenceFamilyField -> "family"
  RecurrenceOccurrenceField -> "occurrence"
  RecurrenceEveryField -> "every"
  RecurrenceWeekdaysField -> "weekdays"
  RecurrenceMonthField -> "month"
  RecurrenceDayField -> "day"
  RecurrenceTimesField -> "times"
  RecurrenceZoneField -> "zone"
  RecurrenceDurationField -> "duration"
  RecurrenceOpensField -> "opens"
  RecurrenceBestBeforeField -> "best_before"
  RecurrenceDeadlineField -> "deadline"
  RecurrencePolicyField -> "at_deadline"
  RecurrenceConsequenceField -> "consequence"

parseRecurrenceFieldCode :: Text -> Maybe RecurrenceField
parseRecurrenceFieldCode code = lookup code [(recurrenceFieldCode field, field) | field <- [minBound .. maxBound]]

recurrenceFieldLabel :: RecurrenceField -> Text
recurrenceFieldLabel = \case
  RecurrenceFamilyField -> "Family"
  RecurrenceOccurrenceField -> "Occurrence"
  RecurrenceEveryField -> "Every"
  RecurrenceWeekdaysField -> "Weekdays"
  RecurrenceMonthField -> "Month"
  RecurrenceDayField -> "Day"
  RecurrenceTimesField -> "Time"
  RecurrenceZoneField -> "Zone"
  RecurrenceDurationField -> "Duration"
  RecurrenceOpensField -> "Opens"
  RecurrenceBestBeforeField -> "Best before"
  RecurrenceDeadlineField -> "Deadline"
  RecurrencePolicyField -> "At deadline"
  RecurrenceConsequenceField -> "Consequence"

recurrenceFieldPrompt :: RecurrenceSchedule -> RecurrenceField -> Text
recurrenceFieldPrompt schedule = \case
  RecurrenceFamilyField -> "How often does this obligation recur?"
  RecurrenceOccurrenceField -> "What does each occurrence become?"
  RecurrenceEveryField -> "Enter a positive whole number of " <> familyUnit (calendarFamily (recurrenceRule schedule)) <> "s."
  RecurrenceWeekdaysField -> "Enter one or more weekdays, such as mon, wed, fri."
  RecurrenceMonthField -> "Enter the intended month, 1 through 12."
  RecurrenceDayField -> "Enter the intended day of the month, 1 through 31. Shorter months use their last day."
  RecurrenceTimesField -> "Enter one or more local times, such as 09:00 or 09:00, 14:00."
  RecurrenceZoneField -> "Enter one named IANA time zone."
  RecurrenceDurationField -> "Enter a positive duration, such as 90 minutes or 2 hours."
  RecurrenceOpensField -> "When does each occurrence open? For example: 7 days before, or at the anchor."
  RecurrenceBestBeforeField -> "Preferred completion relative to the anchor, such as 1 day before, or none."
  RecurrenceDeadlineField -> "Deadline relative to the anchor, such as at the anchor, or none."
  RecurrencePolicyField -> "When a period is not done by its deadline, what does it become?"
  RecurrenceConsequenceField -> "Optional: what happens when a period is missed? At most 200 characters, or none."

deadlinePolicyName :: DeadlinePolicy -> Text
deadlinePolicyName = \case
  DeadlineStaysOpen -> "stays open"
  DeadlineLapses -> "counts as missed"

-- | The review sentence for one deadline policy (UX-RO01).
deadlinePolicySentence :: DeadlinePolicy -> Text
deadlinePolicySentence = \case
  DeadlineStaysOpen -> "A period not done by its deadline stays open until done."
  DeadlineLapses -> "A period not done by its deadline counts as missed."

recurrenceFamilyName :: RecurrenceFamily -> Text
recurrenceFamilyName = \case
  DailyRecurrence -> "daily"
  WeeklyRecurrence -> "weekly"
  MonthlyRecurrence -> "monthly"
  YearlyRecurrence -> "yearly"

recurrenceOccurrenceName :: BrickNature -> Text
recurrenceOccurrenceName = \case
  ScheduledCommitment -> "scheduled commitment"
  _ -> "atomic task"

familyUnit :: RecurrenceFamily -> Text
familyUnit = \case
  DailyRecurrence -> "day"
  WeeklyRecurrence -> "week"
  MonthlyRecurrence -> "month"
  YearlyRecurrence -> "year"

-- | The settled value of one field, as rendered in the editor's field list.
recurrenceFieldValue :: RecurrenceSchedule -> RecurrenceField -> Text
recurrenceFieldValue schedule field = case field of
  RecurrenceFamilyField -> recurrenceFamilyName (calendarFamily rule)
  RecurrenceOccurrenceField -> recurrenceOccurrenceName (recurrenceOccurrenceNature schedule)
  RecurrenceEveryField ->
    let every = calendarEvery rule
     in Text.pack (show every) <> " " <> familyUnit (calendarFamily rule) <> (if every == 1 then "" else "s")
  _ -> recurrenceFieldDraft schedule field
 where
  rule = recurrenceRule schedule

-- | The editable text that prefills one input field.
recurrenceFieldDraft :: RecurrenceSchedule -> RecurrenceField -> Text
recurrenceFieldDraft schedule = \case
  RecurrenceFamilyField -> recurrenceFamilyName (calendarFamily rule)
  RecurrenceOccurrenceField -> recurrenceOccurrenceName (recurrenceOccurrenceNature schedule)
  RecurrenceEveryField -> Text.pack (show (calendarEvery rule))
  RecurrenceWeekdaysField -> Text.intercalate ", " (fmap weekdayName (Set.toAscList (calendarWeekdays rule)))
  RecurrenceMonthField -> maybe "" (Text.pack . show) (calendarIntendedMonth rule)
  RecurrenceDayField -> maybe "" (Text.pack . show) (calendarIntendedDay rule)
  RecurrenceTimesField -> Text.intercalate ", " (fmap renderClock (sort (calendarTimes rule)))
  RecurrenceZoneField -> recurrenceZone schedule
  RecurrenceDurationField -> maybe "" renderDuration (recurrenceDurationSeconds schedule)
  RecurrenceOpensField -> renderRecurrenceOffset (recurrenceNotBeforeOffsetSeconds schedule)
  RecurrenceBestBeforeField -> maybe "none" renderRecurrenceOffset (recurrenceBestBeforeOffsetSeconds schedule)
  RecurrenceDeadlineField -> maybe "none" renderRecurrenceOffset (recurrenceDeadlineOffsetSeconds schedule)
  RecurrencePolicyField -> deadlinePolicyName (recurrenceDeadlinePolicy schedule)
  RecurrenceConsequenceField -> fromMaybe "none" (recurrenceConsequence schedule)
 where
  rule = recurrenceRule schedule

-- | Apply one submitted input field. Choice fields use their own setters.
applyRecurrenceInput :: RecurrenceField -> Text -> RecurrenceSchedule -> Either AppError RecurrenceSchedule
applyRecurrenceInput field raw schedule = case field of
  RecurrenceFamilyField -> invalid "Choose the family from the listed options."
  RecurrenceOccurrenceField -> invalid "Choose the occurrence Nature from the listed options."
  RecurrencePolicyField -> invalid "Choose what a period becomes at its deadline from the listed options."
  RecurrenceConsequenceField
    | Text.null input || Text.toLower input == "none" -> pure schedule{recurrenceConsequence = Nothing}
    | Text.length input > 200 -> invalid "A consequence has at most 200 characters."
    | otherwise -> pure schedule{recurrenceConsequence = Just input}
  RecurrenceEveryField -> do
    every <- wholeNumber "The interval" 1 100000 input
    pure (withRule rule{calendarEvery = every})
  RecurrenceWeekdaysField -> do
    days <- traverse parseWeekday (tokens input)
    if null days
      then invalid "A weekly recurrence needs at least one weekday."
      else pure (withRule rule{calendarWeekdays = Set.fromList days})
  RecurrenceMonthField -> do
    month <- wholeNumber "The intended month" 1 12 input
    pure (withRule rule{calendarIntendedMonth = Just month})
  RecurrenceDayField -> do
    day <- wholeNumber "The intended day" 1 31 input
    pure (withRule rule{calendarIntendedDay = Just day})
  RecurrenceTimesField -> do
    clocks <- traverse parseClock (tokens input)
    case clocks of
      [] -> invalid "Enter at least one local time."
      _
        | length clocks /= length (nub clocks) -> invalid "Each local time may appear only once."
        | otherwise -> pure (withRule rule{calendarTimes = sort clocks})
  RecurrenceZoneField
    | Text.null input || Text.any isSpace input -> invalid "Enter one named IANA time zone, such as America/Sao_Paulo."
    | otherwise -> pure schedule{recurrenceZone = input}
  RecurrenceDurationField -> do
    seconds <- parseDuration input
    pure schedule{recurrenceDurationSeconds = Just seconds}
  RecurrenceOpensField -> do
    offset <- parseRecurrenceOffset input
    pure schedule{recurrenceNotBeforeOffsetSeconds = offset}
  RecurrenceBestBeforeField -> do
    offset <- optionalOffset input
    pure schedule{recurrenceBestBeforeOffsetSeconds = offset}
  RecurrenceDeadlineField -> do
    offset <- optionalOffset input
    pure schedule{recurrenceDeadlineOffsetSeconds = offset}
 where
  input = Text.strip raw
  rule = recurrenceRule schedule
  withRule updated = schedule{recurrenceRule = updated}
  optionalOffset text
    | Text.toLower text == "none" = pure Nothing
    | otherwise = Just <$> parseRecurrenceOffset text

{- | Change the family, filling the family anchor from the series start day
when the draft has none yet.
-}
setRecurrenceFamily :: RecurrenceFamily -> RecurrenceSchedule -> RecurrenceSchedule
setRecurrenceFamily family schedule =
  schedule{recurrenceRule = filled}
 where
  rule = recurrenceRule schedule
  start = calendarStartsOn rule
  (_, startMonth, startDay) = toGregorian start
  filled =
    rule
      { calendarFamily = family
      , calendarWeekdays = if Set.null (calendarWeekdays rule) then Set.singleton (dayOfWeek start) else calendarWeekdays rule
      , calendarIntendedDay = Just (fromMaybe startDay (calendarIntendedDay rule))
      , calendarIntendedMonth = Just (fromMaybe startMonth (calendarIntendedMonth rule))
      }

setRecurrenceDeadlinePolicy :: DeadlinePolicy -> RecurrenceSchedule -> RecurrenceSchedule
setRecurrenceDeadlinePolicy policy schedule = case policy of
  DeadlineLapses -> schedule{recurrenceDeadlinePolicy = DeadlineLapses}
  DeadlineStaysOpen -> schedule{recurrenceDeadlinePolicy = DeadlineStaysOpen, recurrenceConsequence = Nothing}

setRecurrenceOccurrenceNature :: BrickNature -> RecurrenceSchedule -> RecurrenceSchedule
setRecurrenceOccurrenceNature nature schedule = case nature of
  ScheduledCommitment ->
    schedule
      { recurrenceOccurrenceNature = ScheduledCommitment
      , recurrenceDurationSeconds = Just (fromMaybe 3600 (recurrenceDurationSeconds schedule))
      }
  _ -> schedule{recurrenceOccurrenceNature = AtomicTask, recurrenceDurationSeconds = Nothing}

{- | Drop family anchors the selected family does not use before recording,
and the deadline policy when no deadline remains to lapse at.
-}
normalizeRecurrenceSchedule :: RecurrenceSchedule -> RecurrenceSchedule
normalizeRecurrenceSchedule schedule =
  withPolicy schedule{recurrenceRule = normalized}
 where
  withPolicy current = case recurrenceDeadlineOffsetSeconds current of
    Nothing -> setRecurrenceDeadlinePolicy DeadlineStaysOpen current
    Just _ -> current
  rule = recurrenceRule schedule
  family = calendarFamily rule
  normalized =
    rule
      { calendarWeekdays = if family == WeeklyRecurrence then calendarWeekdays rule else Set.empty
      , calendarIntendedDay = if family `elem` [MonthlyRecurrence, YearlyRecurrence] then calendarIntendedDay rule else Nothing
      , calendarIntendedMonth = if family == YearlyRecurrence then calendarIntendedMonth rule else Nothing
      }

{- | The closed offset grammar: @at the anchor@, or a whole number, a unit
(minutes, hours, days, weeks), and @before@ or @after@ the anchor.
-}
parseRecurrenceOffset :: Text -> Either AppError Integer
parseRecurrenceOffset text = case Text.words (Text.toLower text) of
  ["at", "the", "anchor"] -> pure 0
  ["at", "anchor"] -> pure 0
  ["0"] -> pure 0
  [amount, unit, direction] -> do
    magnitude <- (*) <$> positiveAmount amount <*> unitSeconds unit
    case direction of
      "before" -> pure (negate magnitude)
      "after" -> pure magnitude
      _ -> offsetProblem
  _ -> offsetProblem
 where
  offsetProblem = invalid "Write an offset such as 7 days before, 2 hours after, or at the anchor."

parseDuration :: Text -> Either AppError Integer
parseDuration text = case Text.words (Text.toLower text) of
  [amount, unit] -> (*) <$> positiveAmount amount <*> unitSeconds unit
  _ -> invalid "Write a duration such as 90 minutes or 2 hours."

positiveAmount :: Text -> Either AppError Integer
positiveAmount amount
  | not (Text.null amount) && Text.all isDigit amount && Text.length amount <= 6 =
      let value = read (Text.unpack amount)
       in if value > 0 then pure value else invalid "An offset amount must be a positive whole number."
  | otherwise = invalid "An offset amount must be a positive whole number."

unitSeconds :: Text -> Either AppError Integer
unitSeconds unit
  | unit `elem` ["minute", "minutes", "min", "mins"] = pure 60
  | unit `elem` ["hour", "hours", "h"] = pure 3600
  | unit `elem` ["day", "days", "d"] = pure 86400
  | unit `elem` ["week", "weeks", "w"] = pure 604800
  | otherwise = invalid "Use minutes, hours, days, or weeks."

renderRecurrenceOffset :: Integer -> Text
renderRecurrenceOffset 0 = "at the anchor"
renderRecurrenceOffset seconds =
  renderDuration (abs seconds) <> if seconds < 0 then " before" else " after"

renderDuration :: Integer -> Text
renderDuration seconds =
  case [(amount, name) | (size, name) <- units, seconds `mod` size == 0, let amount = seconds `div` size] of
    (amount, name) : _ -> Text.pack (show amount) <> " " <> name <> (if amount == 1 then "" else "s")
    [] -> Text.pack (show seconds) <> " seconds"
 where
  units = [(604800, "week"), (86400, "day"), (3600, "hour"), (60, "minute")]

parseClock :: Text -> Either AppError TimeOfDay
parseClock text = case Text.splitOn ":" text of
  [hours, minutes]
    | digits hours && Text.length hours <= 2 && digits minutes && Text.length minutes == 2 ->
        let h = read (Text.unpack hours)
            m = read (Text.unpack minutes)
         in if h < 24 && m < 60 then pure (TimeOfDay h m 0) else clockProblem
  _ -> clockProblem
 where
  digits value = not (Text.null value) && Text.all isDigit value
  clockProblem = invalid ("Write each local time as HH:MM; " <> text <> " is not one.")

renderClock :: TimeOfDay -> Text
renderClock = Text.pack . formatTime defaultTimeLocale "%H:%M"

parseWeekday :: Text -> Either AppError DayOfWeek
parseWeekday text = case lookup (Text.take 3 text) weekdays of
  Just day | Text.length text >= 3 && text `Text.isPrefixOf` fullName day -> pure day
  _ -> invalid ("Use weekday names such as mon, wed, fri; " <> text <> " is not one.")
 where
  weekdays = [(weekdayName day, day) | day <- [Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday]]
  fullName = Text.toLower . Text.pack . show

weekdayName :: DayOfWeek -> Text
weekdayName = Text.toLower . Text.take 3 . Text.pack . show

tokens :: Text -> [Text]
tokens = filter (not . Text.null) . Text.split (\character -> character == ',' || isSpace character) . Text.toLower

wholeNumber :: Text -> Int -> Int -> Text -> Either AppError Int
wholeNumber name low high text
  | not (Text.null text) && Text.all isDigit text && Text.length text <= 6
  , let value = read (Text.unpack text)
  , value >= low && value <= high =
      pure value
  | otherwise = invalid (name <> " must be a whole number from " <> Text.pack (show low) <> " through " <> Text.pack (show high) <> ".")

invalid :: Text -> Either AppError a
invalid = Left . appError InvalidInput

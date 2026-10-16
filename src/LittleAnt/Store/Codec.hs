{-# LANGUAGE DeriveAnyClass #-}
{-# OPTIONS_GHC -Wno-orphans #-}

-- These instances belong exclusively to the disposable fold-cache format.
-- They neither encode nor decode the canonical domain event protocol.
module LittleAnt.Store.Codec (encodeFoldState, decodeFoldState) where

import Control.Monad (unless)
import Data.Binary (Binary (..), decodeOrFail, encode)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Id
import LittleAnt.Model

encodeFoldState :: State -> ByteString
encodeFoldState = LazyByteString.toStrict . encode

decodeFoldState :: ByteString -> Either Text State
decodeFoldState bytes = case decodeOrFail (LazyByteString.fromStrict bytes) of
  Left (_, _, problem) -> Left (Text.pack problem)
  Right (remaining, _, state)
    | LazyByteString.null remaining -> Right state
    | otherwise -> Left "trailing fold-cache bytes"

instance Binary UUIDv7 where
  put = put . renderUUIDv7
  get = get >>= either (fail . Text.unpack) pure . parseUUIDv7

instance Binary Handle where
  put = put . unHandle
  get = Handle <$> get

instance Binary Day where
  put = put . toModifiedJulianDay
  get = ModifiedJulianDay <$> get

instance Binary UTCTime where
  put (UTCTime day seconds) = put day >> put (diffTimeToPicoseconds seconds)
  get = UTCTime <$> get <*> (picosecondsToDiffTime <$> get)

instance Binary TimeOfDay where
  put (TimeOfDay hour minute seconds) = put hour >> put minute >> put (toRational seconds)
  get = TimeOfDay <$> get <*> get <*> (fromRational <$> get)

instance Binary DayOfWeek where
  put = put . fromEnum
  get = do
    value <- get
    unless (value >= fromEnum Monday && value <= fromEnum Sunday) (fail "invalid cached weekday")
    pure (toEnum value)

deriving anyclass instance Binary Actor
deriving anyclass instance Binary RawStatus
deriving anyclass instance Binary Raw
deriving anyclass instance Binary BrickTitleNormalization
deriving anyclass instance Binary RawContent
deriving anyclass instance Binary RawContentRevision
deriving anyclass instance Binary NormalizationSource
deriving anyclass instance Binary EnglishNormalization
deriving anyclass instance Binary SourceMode
deriving anyclass instance Binary ImportProfileLifecycle
deriving anyclass instance Binary ImportProfile
deriving anyclass instance Binary ImportObjectDisposition
deriving anyclass instance Binary ImportObjectMapping
deriving anyclass instance Binary ImportInvocation
deriving anyclass instance Binary SourceCheckPolicy
deriving anyclass instance Binary SourceBindingLifecycle
deriving anyclass instance Binary SourceBinding
deriving anyclass instance Binary SourceObservationOutcome
deriving anyclass instance Binary SourceObservation
deriving anyclass instance Binary SourceReconciliationDisposition
deriving anyclass instance Binary SourceReconciliation
deriving anyclass instance Binary WaitSuccessor
deriving anyclass instance Binary ExternalEntityKind
deriving anyclass instance Binary ExternalEntity
deriving anyclass instance Binary ContactPointKind
deriving anyclass instance Binary ContactPoint
deriving anyclass instance Binary WaitKind
deriving anyclass instance Binary WaitStatus
deriving anyclass instance Binary WaitGate
deriving anyclass instance Binary WaitObservationKind
deriving anyclass instance Binary WaitObservation
deriving anyclass instance Binary DelegationScope
deriving anyclass instance Binary FollowUpPolicy
deriving anyclass instance Binary DelegationStatus
deriving anyclass instance Binary Delegation
deriving anyclass instance Binary DelegationDeliveryReason
deriving anyclass instance Binary EffectAdapterCustody
deriving anyclass instance Binary SourceCleanupItemTarget
deriving anyclass instance Binary SourceCleanupContainerTarget
deriving anyclass instance Binary ExternalEffectRequest
deriving anyclass instance Binary ExternalEffectPurpose
deriving anyclass instance Binary ExternalEffectStatus
deriving anyclass instance Binary ExternalEffect
deriving anyclass instance Binary ExternalEffectApprovalItem
deriving anyclass instance Binary ExternalEffectApprovalGrant
deriving anyclass instance Binary ExternalEffectReceipt
deriving anyclass instance Binary RecurrenceFamily
deriving anyclass instance Binary CalendarRule
deriving anyclass instance Binary RecurrenceSchedule
deriving anyclass instance Binary RecurringOccurrence
deriving anyclass instance Binary HabitSchedule
deriving anyclass instance Binary HabitWindow
deriving anyclass instance Binary HabitOutcome
deriving anyclass instance Binary NoticeKind
deriving anyclass instance Binary NoticeIdentity
deriving anyclass instance Binary NoticeDisposition
deriving anyclass instance Binary OperationalDayConfig
deriving anyclass instance Binary ScheduledInterval
deriving anyclass instance Binary ReturnUnit
deriving anyclass instance Binary ReturnPolicy
deriving anyclass instance Binary ReturnSchedule
deriving anyclass instance Binary StandingOutcomeKind
deriving anyclass instance Binary StandingOutcome
deriving anyclass instance Binary ZonedInstant
deriving anyclass instance Binary TemporalConstraints
deriving anyclass instance Binary ChecklistRun
deriving anyclass instance Binary DomainFocusMode
deriving anyclass instance Binary DomainScope
deriving anyclass instance Binary DependencyStatus
deriving anyclass instance Binary Dependency
deriving anyclass instance Binary WorkDeferral
deriving anyclass instance Binary ActiveSprint
deriving anyclass instance Binary BrickNature
deriving anyclass instance Binary BrickStatus
deriving anyclass instance Binary WorkState
deriving anyclass instance Binary SkipSymptom
deriving anyclass instance Binary SkipReaction
deriving anyclass instance Binary TemplateSelection
deriving anyclass instance Binary ImportanceConfidence
deriving anyclass instance Binary Fixed
deriving anyclass instance Binary JudgmentAxis
deriving anyclass instance Binary JudgmentProvenance
deriving anyclass instance Binary JudgmentRelation
deriving anyclass instance Binary JudgmentStatus
deriving anyclass instance Binary PairJudgment
deriving anyclass instance Binary JudgmentLabel
deriving anyclass instance Binary WorkPhase
deriving anyclass instance Binary PhaseClaim
deriving anyclass instance Binary ImpactClass
deriving anyclass instance Binary ImpactMaturity
deriving anyclass instance Binary ImpactClaim
deriving anyclass instance Binary EffortClass
deriving anyclass instance Binary EffortClaim
deriving anyclass instance Binary EffortActualEvidence
deriving anyclass instance Binary Brick
deriving anyclass instance Binary Domain
deriving anyclass instance Binary RawShelf
deriving anyclass instance Binary Quantity
deriving anyclass instance Binary ListEntryState
deriving anyclass instance Binary ListEntry
deriving anyclass instance Binary RawDisposition
deriving anyclass instance Binary RawLinkRole
deriving anyclass instance Binary RawLinkTarget
deriving anyclass instance Binary RawLink
deriving anyclass instance Binary ImportanceEdge
deriving anyclass instance Binary LazyReviewClaim
deriving anyclass instance Binary JudgmentReviewKind
deriving anyclass instance Binary JudgmentReview
deriving anyclass instance Binary CommandEffect
deriving anyclass instance Binary MaterializationEffect
deriving anyclass instance Binary ForecastDrawEvidence
deriving anyclass instance Binary ForecastExplanation
deriving anyclass instance Binary ForecastFactorEvidence
deriving anyclass instance Binary ImportanceReviewDeferral
deriving anyclass instance Binary ForecastSelectionEvidence
deriving anyclass instance Binary State

module LittleAnt.Model (
  Actor (..),
  Brick (..),
  BrickNature (..),
  BrickStatus (..),
  CommandEffect (..),
  ChecklistRun (..),
  Domain (..),
  DomainFocusMode (..),
  DomainScope (..),
  Dependency (..),
  DependencyStatus (..),
  EffortClaim (..),
  EffortActualEvidence (..),
  EffortClass (..),
  Fixed (..),
  ForecastDrawEvidence (..),
  ForecastSelectionEvidence (..),
  ForecastExplanation (..),
  ForecastFactorEvidence (..),
  ImportanceReviewDeferral (..),
  ImpactClaim (..),
  ImpactClass (..),
  ImpactMaturity (..),
  JudgmentAxis (..),
  JudgmentLabel (..),
  JudgmentProvenance (..),
  JudgmentRelation (..),
  JudgmentStatus (..),
  PairJudgment (..),
  PhaseClaim (..),
  WorkPhase (..),
  ImportanceConfidence (..),
  ImportanceEdge (..),
  LazyReviewClaim (..),
  JudgmentReviewKind (..),
  JudgmentReview (..),
  ListEntry (..),
  ListEntryState (..),
  MaterializationEffect (..),
  Quantity (..),
  Raw (..),
  RawContent (..),
  RawContentRevision (..),
  NormalizationSource (..),
  EnglishNormalization (..),
  BrickTitleNormalization (..),
  ImportProfileLifecycle (..),
  ImportProfile (..),
  ImportObjectDisposition (..),
  ImportObjectMapping (..),
  ImportInvocation (..),
  SourceMode (..),
  SourceCheckPolicy (..),
  SourceBindingLifecycle (..),
  SourceBinding (..),
  SourceObservationOutcome (..),
  SourceObservation (..),
  SourceReconciliationDisposition (..),
  SourceReconciliation (..),
  RawDisposition (..),
  RawLink (..),
  RawLinkRole (..),
  RawLinkTarget (..),
  RawShelf (..),
  RawStatus (..),
  SkipReaction (..),
  SkipSymptom (..),
  State (..),
  UndoPoint (..),
  TemplateSelection (..),
  ZonedInstant (..),
  TemporalConstraints (..),
  StandingOutcomeKind (..),
  StandingOutcome (..),
  ReturnUnit (..),
  ReturnPolicy (..),
  ReturnSchedule (..),
  ScheduledInterval (..),
  RecurrenceFamily (..),
  CalendarRule (..),
  RecurrenceSchedule (..),
  RecurringOccurrence (..),
  DeadlinePolicy (..),
  ObligationPeriod (..),
  ObligationPeriodState (..),
  obligationPeriodState,
  obligationPeriodHistory,
  obligationEscalatesAt,
  obligationEscalationSkipPause,
  seriesOccurrences,
  isObligationOccurrence,
  carriesImportance,
  importanceSiblings,
  HabitSchedule (..),
  HabitWindow (..),
  HabitOutcome (..),
  NoticeKind (..),
  NoticeIdentity (..),
  NoticeDisposition (..),
  OperationalDayConfig (..),
  ExternalEntityKind (..),
  ExternalEntity (..),
  ContactPointKind (..),
  ContactPoint (..),
  WaitKind (..),
  WaitStatus (..),
  WaitGate (..),
  WaitSuccessor (..),
  WaitObservationKind (..),
  WaitObservation (..),
  DelegationScope (..),
  FollowUpPolicy (..),
  DelegationStatus (..),
  Delegation (..),
  DelegationDeliveryReason (..),
  EffectAdapterCustody (..),
  SourceCleanupItemTarget (..),
  SourceCleanupContainerTarget (..),
  ExternalEffectRequest (..),
  ExternalEffectPurpose (..),
  ExternalEffectStatus (..),
  ExternalEffect (..),
  ExternalEffectApprovalItem (..),
  ExternalEffectApprovalGrant (..),
  ExternalEffectReceipt (..),
  externalEffectPurpose,
  externalEffectDelegation,
  WorkState (..),
  WorkDeferral (..),
  ActiveSprint (..),
  activeBricks,
  dependencyIsBlocking,
  brickCount,
  emptyState,
  inboxRaws,
  rawCount,
  resolveBrickHandle,
  resolveExternalEntityHandle,
  resolveRawHandle,
  siblingBricks,
)
where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.:?), (.=))
import Data.ByteString (ByteString)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Ord (Down (..))
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Time (Day, DayOfWeek, NominalDiffTime, TimeOfDay (..), UTCTime, addUTCTime)
import GHC.Generics (Generic)
import LittleAnt.Id

data Actor = Actor {actorKind :: Text, actorProfile :: Text}
  deriving stock (Eq, Ord, Generic, Show)

data RawStatus = RawAwaitingReview | RawRetracted | RawArchived
  deriving stock (Eq, Ord, Generic, Show)

data Raw = Raw
  { rawId :: UUIDv7
  , rawHandle :: Handle
  , rawOriginal :: Text
  , rawCreatedAt :: UTCTime
  , rawCreatedBy :: Actor
  , rawStatus :: RawStatus
  , rawRevision :: Int
  , rawCreatedByCommand :: UUIDv7
  }
  deriving stock (Eq, Generic, Show)

data BrickTitleNormalization = BrickTitleNormalization
  { brickTitleNormalizationId :: UUIDv7
  , brickTitleNormalizationBrick :: UUIDv7
  , brickTitleNormalizationPrevious :: Text
  , brickTitleNormalizationCurrent :: Text
  , brickTitleNormalizationSource :: NormalizationSource
  , brickTitleNormalizationProducer :: Maybe Text
  , brickTitleNormalizationAcceptedAt :: UTCTime
  , brickTitleNormalizationConfidence :: Maybe Fixed
  }
  deriving stock (Eq, Generic, Show)

data RawContent
  = RawTextContent Text
  | RawUriContent Text (Maybe Text)
  | RawBlobContent Text Text Integer (Maybe Text)
  | RawStructuredContent Text Text
  deriving stock (Eq, Generic, Show)

data RawContentRevision = RawContentRevision
  { rawContentRevisionId :: UUIDv7
  , rawContentRevisionRaw :: UUIDv7
  , rawContentRevisionOrdinal :: Int
  , rawContentRevisionRecordedAt :: UTCTime
  , rawContentRevisionActor :: Actor
  , rawContentRevisionProvenance :: Text
  , rawContentRevisionContent :: RawContent
  , rawContentRevisionDigest :: Text
  }
  deriving stock (Eq, Generic, Show)

data NormalizationSource = HumanNormalization | PoweredUpNormalization | SkillNormalization | ImportNormalization
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data EnglishNormalization = EnglishNormalization
  { englishNormalizationId :: UUIDv7
  , englishNormalizationRevision :: UUIDv7
  , englishNormalizationText :: Text
  , englishNormalizationSource :: NormalizationSource
  , englishNormalizationProducer :: Maybe Text
  , englishNormalizationAcceptedAt :: UTCTime
  , englishNormalizationConfidence :: Maybe Fixed
  }
  deriving stock (Eq, Generic, Show)

data SourceMode = SourceSnapshot | SourceSynchronize | SourceMigrate
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ImportProfileLifecycle = ImportProfileActive | ImportProfileRetired
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ImportProfile = ImportProfile
  { importProfileId :: UUIDv7
  , importProfileAdapterId :: Text
  , importProfileSourceLabel :: Text
  , importProfileAccountLabel :: Maybe Text
  , importProfileInputReference :: Text
  , importProfileSelectedContainers :: Set Text
  , importProfileMode :: SourceMode
  , importProfileCleanupSupported :: Bool
  , importProfileLifecycle :: ImportProfileLifecycle
  , importProfileRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

data ImportObjectDisposition = ImportCreatedRaw | ImportReusedRaw
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ImportObjectMapping = ImportObjectMapping
  { importObjectExternalIdentity :: Text
  , importObjectRawId :: UUIDv7
  , importObjectDisposition :: ImportObjectDisposition
  }
  deriving stock (Eq, Generic, Show)

data ImportInvocation = ImportInvocation
  { importInvocationId :: UUIDv7
  , importInvocationProfileId :: UUIDv7
  , importInvocationComponentId :: Text
  , importInvocationContractMajor :: Int
  , importInvocationPermissions :: Text
  , importInvocationInputLabel :: Text
  , importInvocationInputMediaType :: Text
  , importInvocationInputDigest :: Text
  , importInvocationInputByteCount :: Int
  , importInvocationMode :: SourceMode
  , importInvocationSelectedContainers :: Set Text
  , importInvocationPackPublisher :: Text
  , importInvocationPackName :: Text
  , importInvocationPackVersion :: Text
  , importInvocationPackManifestDigest :: Text
  , importInvocationPackArchiveDigest :: Text
  , importInvocationSignerFingerprint :: Text
  , importInvocationMappings :: [ImportObjectMapping]
  }
  deriving stock (Eq, Generic, Show)

data SourceCheckPolicy = SourceManualCheck | SourceIntervalCheck Integer
  deriving stock (Eq, Ord, Generic, Show)

data SourceBindingLifecycle = SourceBindingActive | SourceBindingPaused | SourceBindingDetached
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data SourceBinding = SourceBinding
  { sourceBindingId :: UUIDv7
  , sourceBindingRaw :: UUIDv7
  , sourceBindingKind :: Text
  , sourceBindingImportProfile :: Maybe UUIDv7
  , sourceBindingExternalIdentity :: Maybe Text
  , sourceBindingContainerIdentity :: Maybe Text
  , sourceBindingLocator :: Text
  , sourceBindingMode :: SourceMode
  , sourceBindingCheckPolicy :: SourceCheckPolicy
  , sourceBindingLifecycle :: SourceBindingLifecycle
  , sourceBindingAcceptedObservation :: Maybe UUIDv7
  , sourceBindingRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

data SourceObservationOutcome
  = SourceUnchanged
  | SourceChanged
  | SourceMissing
  | SourceUnreachable
  | SourceUnauthorized
  | SourceMalformed
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data SourceObservation = SourceObservation
  { sourceObservationId :: UUIDv7
  , sourceObservationBinding :: UUIDv7
  , sourceObservationAt :: UTCTime
  , sourceObservationLocator :: Text
  , sourceObservationOutcome :: SourceObservationOutcome
  , sourceObservationProviderVersion :: Maybe Text
  , sourceObservationFingerprint :: Maybe Text
  , sourceObservationSnapshotDigest :: Maybe Text
  , sourceObservationSnapshot :: Maybe RawContent
  }
  deriving stock (Eq, Generic, Show)

data SourceReconciliationDisposition
  = SourceAcceptedAsRevision UUIDv7
  | SourceAcceptedAsDerivedRaw UUIDv7
  | SourceIgnoredAsUnrelated
  deriving stock (Eq, Ord, Generic, Show)

data SourceReconciliation = SourceReconciliation
  { sourceReconciliationId :: UUIDv7
  , sourceReconciliationObservation :: UUIDv7
  , sourceReconciliationDisposition :: SourceReconciliationDisposition
  , sourceReconciliationAt :: UTCTime
  , sourceReconciliationActor :: Actor
  }
  deriving stock (Eq, Generic, Show)

{- | A declared handoff from human Work to an external Wait. The Wait UUID is
allocated when the handoff is accepted, but the Wait itself does not exist
until the enabling Brick completes. This lets completion activate the Wait
in the same command group that resolves the Dependency.
-}
data WaitSuccessor = WaitSuccessor
  { waitSuccessorWait :: UUIDv7
  , waitSuccessorEnablingBrick :: UUIDv7
  , waitSuccessorAffectedBrick :: UUIDv7
  , waitSuccessorKind :: WaitKind
  , waitSuccessorReviewDelaySeconds :: Integer
  , waitSuccessorDeclaredAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data ExternalEntityKind = PersonEntity | TeamEntity | OrganizationEntity | AIAgentEntity | ServiceEntity
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ExternalEntity = ExternalEntity
  { externalEntityId :: UUIDv7
  , externalEntityHandle :: Handle
  , externalEntityName :: Text
  , externalEntityKind :: ExternalEntityKind
  , externalEntityActive :: Bool
  , externalEntityCreatedAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data ContactPointKind = EmailContact | PhoneContact | URIContact | ProviderRecipientContact
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ContactPoint = ContactPoint
  { contactPointId :: UUIDv7
  , contactPointOwner :: UUIDv7
  , contactPointKind :: ContactPointKind
  , contactPointLabel :: Maybe Text
  , contactPointValue :: Text
  , contactPointProvider :: Maybe Text
  , contactPointActive :: Bool
  , contactPointSource :: Text
  , contactPointVerifiedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Generic, Show)

data WaitKind
  = HumanResponseWait UUIDv7
  | ExternalConditionWait Text
  deriving stock (Eq, Ord, Generic, Show)

data WaitStatus = WaitActive | WaitResolved | WaitCancelled
  deriving stock (Eq, Ord, Generic, Show)

data WaitGate = WaitGate
  { waitId :: UUIDv7
  , waitAffectedBrick :: UUIDv7
  , waitKind :: WaitKind
  , waitReviewNotBefore :: ZonedInstant
  , waitReviewCooldownUntil :: Maybe UTCTime
  , waitStatus :: WaitStatus
  , waitActivatedAt :: UTCTime
  , waitDeferralCount :: Int
  , waitRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

data WaitObservationKind
  = WaitActivatedObservation
  | WaitResponseReceivedObservation
  | WaitLongerObservation
  | WaitFollowUpObservation
  | WaitReviewSkippedObservation
  | WaitReclassifiedObservation
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data WaitObservation = WaitObservation
  { waitObservationId :: UUIDv7
  , waitObservationWait :: UUIDv7
  , waitObservationKind :: WaitObservationKind
  , waitObservationAt :: UTCTime
  , waitObservationActor :: Actor
  , waitObservationNote :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)

data DelegationScope = BrickOnlyDelegation | WholeScopeDelegation
  deriving stock (Eq, Ord, Generic, Show)

data FollowUpPolicy = FollowUpOnce | FollowUpEvery | FollowUpNone
  deriving stock (Eq, Ord, Generic, Show)

data DelegationStatus
  = DelegationProposed
  | DelegationActive
  | DelegationCompleted
  | DelegationRefused
  | DelegationTakenBack
  | DelegationCancelled
  | DelegationReassigned
  deriving stock (Eq, Ord, Generic, Show)

data Delegation = Delegation
  { delegationId :: UUIDv7
  , delegationBrick :: UUIDv7
  , delegationTarget :: UUIDv7
  , delegationScope :: DelegationScope
  , delegationFollowUpPolicy :: FollowUpPolicy
  , delegationReviewDelaySeconds :: Integer
  , delegationReviewNotBefore :: Maybe ZonedInstant
  , delegationStatus :: DelegationStatus
  , delegationMessage :: Text
  , delegationLastObservation :: Maybe Text
  , delegationLastObservedAt :: Maybe UTCTime
  , delegationInitialHandoffAt :: Maybe UTCTime
  , delegationFollowUpHandoffs :: Int
  , delegationExtraFollowUps :: Int
  , delegationRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

data DelegationDeliveryReason = InitialDelegationDelivery | FollowUpDelegationDelivery
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data EffectAdapterCustody = EffectAdapterCustody
  { effectAdapterComponentId :: Text
  , effectAdapterContractMajor :: Int
  , effectAdapterProviderAccount :: Text
  , effectAdapterCredentialBinding :: Text
  , effectAdapterPackPublisher :: Text
  , effectAdapterPackName :: Text
  , effectAdapterPackVersion :: Text
  , effectAdapterPackManifestDigest :: Text
  , effectAdapterPackArchiveDigest :: Text
  , effectAdapterSignerFingerprint :: Text
  }
  deriving stock (Eq, Generic, Show)

data SourceCleanupItemTarget = SourceCleanupItemTarget
  { cleanupItemImportInvocation :: UUIDv7
  , cleanupItemSourceBinding :: UUIDv7
  , cleanupItemRaw :: UUIDv7
  , cleanupItemExternalIdentity :: Text
  , cleanupItemLocator :: Text
  , cleanupItemContainerIdentity :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)

data SourceCleanupContainerTarget = SourceCleanupContainerTarget
  { cleanupContainerImportProfile :: UUIDv7
  , cleanupContainerImportInvocation :: UUIDv7
  , cleanupContainerExternalIdentity :: Text
  , cleanupContainerLabel :: Text
  , cleanupContainerInspectionDigest :: Text
  , cleanupContainerInspectedAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data ExternalEffectRequest
  = DelegationDeliveryRequest
      { effectRequestDelegation :: UUIDv7
      , effectRequestDeliveryReason :: DelegationDeliveryReason
      , effectRequestTarget :: UUIDv7
      , effectRequestContactPoint :: Maybe UUIDv7
      , effectRequestAdapter :: Maybe Text
      , effectRequestMessage :: Text
      }
  | DelegationTakeBackNoticeRequest
      { effectRequestDelegation :: UUIDv7
      , effectRequestTarget :: UUIDv7
      , effectRequestContactPoint :: Maybe UUIDv7
      , effectRequestAdapter :: Maybe Text
      , effectRequestMessage :: Text
      }
  | SourceCleanupItemRequest EffectAdapterCustody SourceCleanupItemTarget
  | SourceCleanupContainerRequest EffectAdapterCustody SourceCleanupContainerTarget
  deriving stock (Eq, Generic, Show)

data ExternalEffectPurpose
  = DelegationDeliveryEffect
  | DelegationTakeBackNoticeEffect
  | SourceCleanupItemEffect
  | SourceCleanupContainerEffect
  | CalendarCreateEffect
  | CalendarUpdateEffect
  | CalendarCancelEffect
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ExternalEffectStatus
  = EffectProposed
  | EffectApproved
  | EffectDispatching
  | EffectSucceeded
  | EffectFailedRetryable
  | EffectFailedTerminal
  | EffectOutcomeUnknown
  | EffectRejected
  | EffectWithdrawn
  deriving stock (Eq, Ord, Generic, Show)

data ExternalEffect = ExternalEffect
  { externalEffectId :: UUIDv7
  , externalEffectRequest :: ExternalEffectRequest
  , externalEffectRevision :: Int
  , externalEffectRecordVersion :: Int
  , externalEffectRedactedPreview :: Text
  , externalEffectPayloadDigest :: Text
  , externalEffectOriginatingCommand :: UUIDv7
  , externalEffectOriginatingCursor :: Text
  , externalEffectIdempotencyKey :: Maybe Text
  , externalEffectStatus :: ExternalEffectStatus
  , externalEffectReviewNotBefore :: Maybe ZonedInstant
  , externalEffectApprovalGrant :: Maybe UUIDv7
  , externalEffectApprovedDigest :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)

data ExternalEffectApprovalItem = ExternalEffectApprovalItem
  { approvedEffectId :: UUIDv7
  , approvedEffectRevision :: Int
  , approvedEffectDigest :: Text
  }
  deriving stock (Eq, Ord, Generic, Show)

data ExternalEffectApprovalGrant = ExternalEffectApprovalGrant
  { externalEffectApprovalGrantId :: UUIDv7
  , externalEffectApprovalItems :: [ExternalEffectApprovalItem]
  , externalEffectApprovalAt :: UTCTime
  , externalEffectApprovalCommand :: UUIDv7
  , externalEffectApprovalCursor :: Text
  }
  deriving stock (Eq, Generic, Show)

data ExternalEffectReceipt = ExternalEffectReceipt
  { externalEffectReceiptId :: UUIDv7
  , externalEffectReceiptEffect :: UUIDv7
  , externalEffectReceiptAt :: UTCTime
  , externalEffectReceiptOutcome :: ExternalEffectStatus
  , externalEffectReceiptProviderReference :: Maybe Text
  , externalEffectReceiptRedactedDetail :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)

externalEffectPurpose :: ExternalEffect -> ExternalEffectPurpose
externalEffectPurpose effect = case externalEffectRequest effect of
  DelegationDeliveryRequest{} -> DelegationDeliveryEffect
  DelegationTakeBackNoticeRequest{} -> DelegationTakeBackNoticeEffect
  SourceCleanupItemRequest{} -> SourceCleanupItemEffect
  SourceCleanupContainerRequest{} -> SourceCleanupContainerEffect

externalEffectDelegation :: ExternalEffect -> Maybe UUIDv7
externalEffectDelegation effect = case externalEffectRequest effect of
  DelegationDeliveryRequest{effectRequestDelegation} -> Just effectRequestDelegation
  DelegationTakeBackNoticeRequest{effectRequestDelegation} -> Just effectRequestDelegation
  SourceCleanupItemRequest{} -> Nothing
  SourceCleanupContainerRequest{} -> Nothing

data RecurrenceFamily = DailyRecurrence | WeeklyRecurrence | MonthlyRecurrence | YearlyRecurrence
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data CalendarRule = CalendarRule
  { calendarFamily :: RecurrenceFamily
  , calendarEvery :: Int
  , calendarStartsOn :: Day
  , calendarWeekdays :: Set DayOfWeek
  , calendarIntendedDay :: Maybe Int
  , calendarIntendedMonth :: Maybe Int
  , calendarTimes :: [TimeOfDay]
  }
  deriving stock (Eq, Ord, Generic, Show)

data RecurrenceSchedule = RecurrenceSchedule
  { recurrenceOwner :: UUIDv7
  , recurrenceRule :: CalendarRule
  , recurrenceZone :: Text
  , recurrenceOccurrenceNature :: BrickNature
  , recurrenceDurationSeconds :: Maybe Integer
  , recurrenceNotBeforeOffsetSeconds :: Integer
  , recurrenceBestBeforeOffsetSeconds :: Maybe Integer
  , recurrenceDeadlineOffsetSeconds :: Maybe Integer
  , recurrenceDeadlinePolicy :: DeadlinePolicy
  , recurrenceConsequence :: Maybe Text
  , recurrenceRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

{- | What an unfinished period becomes at its deadline (WRK-148): debt that
stays open, as for a bill, or a miss, as for a required weekly shift.
-}
data DeadlinePolicy = DeadlineStaysOpen | DeadlineLapses
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

{- | The resolution facts of one occurrence of a recurring obligation beyond
its ordinary Brick lifecycle (WRK-161..163). Every fact keeps its time, so
excusing or completing a miss late never erases the miss itself.
-}
data ObligationPeriod = ObligationPeriod
  { obligationPeriodMissedAt :: Maybe UTCTime
  , obligationPeriodExcusedAt :: Maybe UTCTime
  , obligationPeriodExcuseReason :: Maybe Text
  , obligationPeriodDoneLateAt :: Maybe UTCTime
  }
  deriving stock (Eq, Generic, Show)

-- | How one occurrence counts in the period history of its series (WRK-164).
data ObligationPeriodState
  = PeriodOpen
  | PeriodDoneOnTime
  | PeriodDoneLate
  | PeriodMissed
  | PeriodExcused
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data RecurringOccurrence = RecurringOccurrence
  { recurringOccurrenceId :: UUIDv7
  , recurringOccurrenceOwner :: UUIDv7
  , recurringOccurrenceBrick :: UUIDv7
  , recurringOccurrenceNominalAnchor :: ZonedInstant
  , recurringOccurrenceLabel :: Text
  , recurringOccurrenceScheduleRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

data HabitSchedule
  = FixedSlotHabit
      { habitScheduleOwner :: UUIDv7
      , habitFixedRule :: CalendarRule
      , habitScheduleZone :: Text
      , habitSlotDurationSeconds :: Integer
      , habitDayBoundary :: Maybe TimeOfDay
      , habitScheduleRevision :: Int
      }
  | QuotaWindowHabit
      { habitScheduleOwner :: UUIDv7
      , habitQuotaTarget :: Int
      , habitQuotaSpan :: Int
      , habitQuotaUnit :: ReturnUnit
      , habitQuotaStartsOn :: Day
      , habitScheduleZone :: Text
      , habitDayBoundary :: Maybe TimeOfDay
      , habitScheduleRevision :: Int
      }
  deriving stock (Eq, Generic, Show)

data HabitWindow = HabitWindow
  { habitWindowId :: UUIDv7
  , habitWindowOwner :: UUIDv7
  , habitWindowOpensAt :: ZonedInstant
  , habitWindowClosesAt :: ZonedInstant
  , habitWindowTarget :: Int
  , habitWindowScheduleRevision :: Int
  , habitWindowSettled :: Bool
  }
  deriving stock (Eq, Generic, Show)

data HabitOutcome = HabitOutcome
  { habitOutcomeId :: UUIDv7
  , habitOutcomeWindow :: UUIDv7
  , habitOutcomeOwner :: UUIDv7
  , habitOutcomeKind :: StandingOutcomeKind
  , habitOutcomeAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data NoticeKind = BestBeforeNotice | DeadlineNotice | RecurringReleaseNotice | TemporalTransitionNotice
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data NoticeIdentity = NoticeIdentity
  { noticeSubject :: UUIDv7
  , noticeFactRevision :: Int
  , noticeKind :: NoticeKind
  , noticeThreshold :: UTCTime
  }
  deriving stock (Eq, Ord, Generic, Show)

data NoticeDisposition
  = NoticeAcknowledged UTCTime
  | NoticeSnoozed ZonedInstant
  deriving stock (Eq, Generic, Show)

data OperationalDayConfig = OperationalDayConfig
  { operationalZone :: Text
  , operationalHabitDayStartsAt :: TimeOfDay
  , operationalWorkdayStartsAt :: TimeOfDay
  }
  deriving stock (Eq, Generic, Show)

data ScheduledInterval = ScheduledInterval
  { scheduledIntervalOwner :: UUIDv7
  , scheduledStartsAt :: ZonedInstant
  , scheduledEndsAt :: ZonedInstant
  , scheduledIntervalRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

data ReturnUnit = ReturnDays | ReturnWeeks | ReturnMonths | ReturnYears
  deriving stock (Eq, Ord, Generic, Show)

data ReturnPolicy
  = ManualOnlyReturn
  | AfterCompletionReturn
      { returnCenter :: Int
      , returnUnit :: ReturnUnit
      , returnVariation :: Int
      , returnZone :: Text
      }
  deriving stock (Eq, Ord, Generic, Show)

data ReturnSchedule = ReturnSchedule
  { returnScheduleOwner :: UUIDv7
  , returnSchedulePolicy :: ReturnPolicy
  , returnScheduleChosenOffset :: Maybe Int
  , returnScheduleNotBefore :: Maybe ZonedInstant
  , returnScheduleResolution :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)

data StandingOutcomeKind
  = StandingDone
  | StandingUnfulfilled
  | StandingBlocked
  | StandingPaused
  | StandingInapplicable
  | StandingAttended
  | StandingMissed
  | StandingCancelled
  deriving stock (Eq, Ord, Generic, Show)

data StandingOutcome = StandingOutcome
  { standingOutcomeId :: UUIDv7
  , standingOutcomeOwner :: UUIDv7
  , standingOutcomeKind :: StandingOutcomeKind
  , standingOutcomeAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data ZonedInstant = ZonedInstant
  { zonedInstantUtc :: UTCTime
  , zonedInstantZone :: Text
  }
  deriving stock (Eq, Ord, Generic, Show)

data TemporalConstraints = TemporalConstraints
  { temporalNotBefore :: Maybe ZonedInstant
  , temporalBestBefore :: Maybe ZonedInstant
  , temporalDeadline :: Maybe ZonedInstant
  , temporalRevision :: Int
  }
  deriving stock (Eq, Generic, Show)

data ChecklistRun = ChecklistRun
  { checklistRunId :: UUIDv7
  , checklistRunOwner :: UUIDv7
  , checklistRunStartedAt :: UTCTime
  , checklistRunMutationCount :: Int
  }
  deriving stock (Eq, Generic, Show)

data DomainFocusMode = OneSuggestion | StayWithin | PreferDomain
  deriving stock (Eq, Ord, Generic, Show)

data DomainScope = DomainScope
  { domainScopeTarget :: UUIDv7
  , domainScopeMode :: DomainFocusMode
  }
  deriving stock (Eq, Generic, Show)

data DependencyStatus = DependencyActive | DependencyResolved | DependencyRemoved
  deriving stock (Eq, Ord, Generic, Show)

data Dependency = Dependency
  { dependencyId :: UUIDv7
  , dependencyBlockedBrick :: UUIDv7
  , dependencyBlockerBrick :: UUIDv7
  , dependencyStatus :: DependencyStatus
  , dependencySource :: Text
  , dependencyCreatedAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data WorkDeferral = WorkDeferral
  { workDeferralId :: UUIDv7
  , workDeferralBrick :: UUIDv7
  , workDeferralSelection :: Maybe UUIDv7
  , workDeferralSymptom :: SkipSymptom
  , workDeferralReaction :: SkipReaction
  , workDeferralRecordedAt :: UTCTime
  , workDeferralCooldownUntil :: Maybe UTCTime
  }
  deriving stock (Eq, Generic, Show)

data ActiveSprint = ActiveSprint
  { activeSprintBrick :: UUIDv7
  , activeSprintStartedAt :: UTCTime
  , activeSprintEndsAt :: UTCTime
  , activeSprintMinutes :: Int
  }
  deriving stock (Eq, Generic, Show)

data BrickNature
  = AtomicTask
  | Project
  | Collection
  | Repeatable
  | LivingChecklist
  | FiniteChecklist
  | RecurringObligation
  | Habit
  | ScheduledCommitment
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data BrickStatus
  = BrickActive
  | BrickDone
  | BrickArchived
  | BrickSuperseded
  | BrickMerged
  | BrickMissed
  | BrickCancelled
  deriving stock (Eq, Ord, Generic, Show)

data WorkState = Idle | Wip
  deriving stock (Eq, Ord, Generic, Show)

data SkipSymptom
  = VagueSymptom
  | HardSymptom
  | BigSymptom
  | BlockedOrWaitingSymptom
  | BlockedSymptom
  | WaitingSymptom
  | TiredSymptom
  | BoredSymptom
  | FearSymptom
  | LessImportantSymptom
  | OutOfDateSymptom
  | OtherSymptom Text
  deriving stock (Eq, Ord, Generic, Show)

data SkipReaction
  = SkipAnywayReaction
  | PauseForNowReaction
  | StartSprintReaction Int
  | ArchiveReaction
  | KeepAndUpdateReaction
  | BreakIntoPartsReaction
  | CollectContextReaction
  | LearnFirstReaction
  | FindEasierApproachReaction
  | GetHelpReaction
  | ChangeSubjectReaction
  | EasierWorkReaction UUIDv7
  | OrderLowerReaction
  | LaterReaction
  | CreateRequestReaction
  deriving stock (Eq, Ord, Generic, Show)

data TemplateSelection = TemplateSelection
  { templateIdentifier :: Text
  , templateCatalogVersion :: Text
  , templateSource :: Text
  }
  deriving stock (Eq, Ord, Generic, Show)

data ImportanceConfidence
  = HumanComparison
  | DeterministicPosition Text
  | Provisional Text
  deriving stock (Eq, Ord, Generic, Show)

newtype Fixed = Fixed {unFixed :: Integer}
  deriving stock (Eq, Ord, Generic, Show)

data JudgmentAxis
  = ImportanceAxis
  | ImpactAxis
  | EffortAxis
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data JudgmentProvenance
  = DirectHuman
  | AssistedAccepted Text
  | HumanEitherOrder
  | DeterministicProvisional
  | ModelOnly Text
  deriving stock (Eq, Ord, Generic, Show)

data JudgmentRelation
  = MoreThan
  | EitherOrder
  | AboutSame
  deriving stock (Eq, Ord, Generic, Show)

data JudgmentStatus
  = JudgmentCurrent
  | JudgmentRetired UUIDv7 Text
  | JudgmentRetracted UUIDv7 Text
  | JudgmentUnresolved Text
  deriving stock (Eq, Ord, Generic, Show)

data PairJudgment = PairJudgment
  { judgmentId :: UUIDv7
  , judgmentAxis :: JudgmentAxis
  , judgmentFirst :: UUIDv7
  , judgmentSecond :: UUIDv7
  , judgmentRelation :: JudgmentRelation
  , judgmentRecordedAt :: UTCTime
  , judgmentProvenance :: JudgmentProvenance
  , judgmentInitialConfidence :: Fixed
  , judgmentProfileHash :: Text
  , judgmentContext :: Text
  , judgmentReason :: Text
  , judgmentStatus :: JudgmentStatus
  }
  deriving stock (Eq, Ord, Generic, Show)

data JudgmentLabel
  = ReviewedJudgment
  | ProvisionalJudgment
  | ReviewDueJudgment
  | HistoricalOnlyJudgment
  deriving stock (Eq, Ord, Generic, Show)

data WorkPhase
  = IdeaPhase
  | SpecPhase
  | ExecutionPhase
  | ValidationPhase
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data PhaseClaim = PhaseClaim
  { phaseClaimBrick :: UUIDv7
  , phaseClaimValue :: WorkPhase
  , phaseClaimRecordedAt :: UTCTime
  , phaseClaimProvenance :: JudgmentProvenance
  }
  deriving stock (Eq, Generic, Show)

data ImpactClass
  = VeryLowImpact
  | LowImpact
  | MediumImpact
  | HighImpact
  | VeryHighImpact
  | CriticalImpact
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ImpactMaturity
  = SpeculativeImpact
  | SupportedImpact
  | ValidatedImpact
  | ObservedImpact
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data ImpactClaim = ImpactClaim
  { impactClaimBrick :: UUIDv7
  , impactClaimClass :: ImpactClass
  , impactClaimMaturity :: ImpactMaturity
  , impactClaimEvidence :: [UUIDv7]
  , impactClaimRecordedAt :: UTCTime
  , impactClaimProvenance :: JudgmentProvenance
  , impactClaimProfileHash :: Text
  }
  deriving stock (Eq, Generic, Show)

data EffortClass
  = VeryEasyEffort
  | EasyEffort
  | NormalEffort
  | ModerateEffort
  | HardEffort
  | VeryHardEffort
  | MiniProjectEffort
  | ProjectEffort
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

data EffortClaim = EffortClaim
  { effortClaimBrick :: UUIDv7
  , effortClaimClass :: EffortClass
  , effortClaimRecordedAt :: UTCTime
  , effortClaimProvenance :: JudgmentProvenance
  , effortClaimProfileHash :: Text
  }
  deriving stock (Eq, Generic, Show)

data EffortActualEvidence = EffortActualEvidence
  { effortActualEvidenceId :: UUIDv7
  , effortActualBrick :: UUIDv7
  , effortActualRaw :: UUIDv7
  , effortActualImportInvocation :: UUIDv7
  , effortActualPlanningManifestDigest :: Text
  , effortActualTaskId :: Text
  , effortActualAsOf :: UTCTime
  , effortActualCompletedMicrohours :: Maybe Integer
  , effortActualRemainingMicrohours :: Maybe Integer
  , effortActualRecordedAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data Brick = Brick
  { brickId :: UUIDv7
  , brickHandle :: Handle
  , brickTitle :: Text
  , brickNature :: BrickNature
  , brickNatureVersion :: Text
  , brickNatureSource :: Text
  , brickTemplate :: Maybe TemplateSelection
  , brickParent :: Maybe UUIDv7
  , brickDomains :: Set UUIDv7
  , brickSiblingPosition :: Int
  , brickImportanceConfidence :: ImportanceConfidence
  , brickStatus :: BrickStatus
  , brickWorkState :: WorkState
  , brickCreatedAt :: UTCTime
  , brickCreatedBy :: Actor
  , brickCreatedByCommand :: UUIDv7
  }
  deriving stock (Eq, Generic, Show)

data Domain = Domain
  { domainId :: UUIDv7
  , domainName :: Text
  , domainParent :: Maybe UUIDv7
  , domainActive :: Bool
  }
  deriving stock (Eq, Generic, Show)

data RawShelf = RawShelf
  { rawShelfId :: UUIDv7
  , rawShelfName :: Text
  , rawShelfActive :: Bool
  , rawShelfMembers :: [UUIDv7]
  }
  deriving stock (Eq, Generic, Show)

data Quantity = Quantity
  { quantityCoefficient :: Integer
  , quantityScale :: Int
  , quantityUnit :: Text
  }
  deriving stock (Eq, Ord, Generic, Show)

data ListEntryState = EntryOpen | EntryResolved | EntryCancelled
  deriving stock (Eq, Ord, Generic, Show)

data ListEntry = ListEntry
  { listEntryId :: UUIDv7
  , listEntryOwner :: UUIDv7
  , listEntryLabel :: Text
  , listEntryQuantity :: Quantity
  , listEntryState :: ListEntryState
  , listEntryInsertionOrdinal :: Int
  , listEntryCreatedAt :: UTCTime
  }
  deriving stock (Eq, Generic, Show)

data RawDisposition
  = RawKeptStandalone
  | RawGroupedAsDuplicate UUIDv7
  | RawMaterializedAsWork UUIDv7
  | RawMaterializedAsListEntry UUIDv7 UUIDv7
  | RawPlacedOnShelf UUIDv7
  | RawAttachedTo UUIDv7 RawLinkRole
  deriving stock (Eq, Ord, Generic, Show)

data RawLinkRole
  = DescriptionRole
  | MaterializationSourceRole
  | AttachmentRole
  | EvidenceRole
  | DerivedFromRole
  | DuplicateOfRole
  deriving stock (Eq, Ord, Generic, Show)

data RawLinkTarget
  = RawLinkBrick UUIDv7
  | RawLinkListEntry UUIDv7
  | RawLinkRaw UUIDv7
  deriving stock (Eq, Ord, Generic, Show)

data RawLink = RawLink
  { rawLinkId :: UUIDv7
  , rawLinkRaw :: UUIDv7
  , rawLinkTarget :: RawLinkTarget
  , rawLinkRole :: RawLinkRole
  , rawLinkCreatedAt :: UTCTime
  , rawLinkCreatedBy :: Actor
  }
  deriving stock (Eq, Generic, Show)

data ImportanceEdge = ImportanceEdge
  { importanceAbove :: UUIDv7
  , importanceBelow :: UUIDv7
  , importanceRecordedAt :: UTCTime
  , importanceSource :: Text
  }
  deriving stock (Eq, Ord, Generic, Show)

data LazyReviewClaim = LazyReviewClaim
  { lazyReviewId :: UUIDv7
  , lazyReviewSubject :: UUIDv7
  , lazyReviewKind :: Text
  , lazyReviewReason :: Text
  , lazyReviewCreatedAt :: UTCTime
  }
  deriving stock (Eq, Ord, Generic, Show)

data JudgmentReviewKind = EffortDiscovery | ImpactDiscovery | ImpactEvidenceReview
  deriving stock (Bounded, Enum, Eq, Ord, Generic, Show)

-- A demand is attached to existing Work. Resolved demands retain the revision
-- and class-validity evidence, so viewing or repeating a command cannot revive it.
data JudgmentReview = JudgmentReview
  { judgmentReviewKind :: JudgmentReviewKind
  , judgmentReviewSubject :: UUIDv7
  , judgmentReviewCandidates :: [UUIDv7]
  , judgmentReviewReason :: Text
  , judgmentReviewRevision :: Text
  , judgmentReviewCreatedAt :: UTCTime
  , judgmentReviewCooldown :: Maybe UTCTime
  , judgmentReviewDeferrals :: Int
  , judgmentReviewResolved :: Bool
  , judgmentReviewClassDue :: Bool
  }
  deriving stock (Eq, Generic, Show)

data CommandEffect = CommandEffect
  { effectCommandId :: UUIDv7
  , effectActor :: Actor
  , effectCreatedRaws :: [UUIDv7]
  , effectCompensatedBy :: Maybe UUIDv7
  }
  deriving stock (Eq, Generic, Show)

data MaterializationEffect = MaterializationEffect
  { materializationCommandId :: UUIDv7
  , materializationRawId :: UUIDv7
  , materializationBrickId :: Maybe UUIDv7
  , materializationLinkIds :: [UUIDv7]
  , materializationEntryIds :: [UUIDv7]
  , materializationPreviousDisposition :: Maybe RawDisposition
  , materializationCompensatedBy :: Maybe UUIDv7
  , materializationCreatedShelfIds :: [UUIDv7]
  , materializationShelfMemberships :: [(UUIDv7, UUIDv7)]
  , materializationPreviousQuantities :: Map UUIDv7 Quantity
  }
  deriving stock (Eq, Generic, Show)

data ForecastDrawEvidence = ForecastDrawEvidence
  { forecastDrawPurpose :: Text
  , forecastDrawCandidates :: [(Text, Integer)]
  , forecastDrawTotal :: Integer
  , forecastDrawStartingCursor :: Integer
  , forecastDrawEndingCursor :: Integer
  , forecastDrawSampledInteger :: Integer
  , forecastDrawChosenIdentity :: Text
  }
  deriving stock (Eq, Generic, Show)

data ForecastSelectionEvidence = ForecastSelectionEvidence
  { forecastSelectionId :: UUIDv7
  , forecastSelectionProfileHash :: Text
  , forecastSelectionSeed :: ByteString
  , forecastSelectionAdmitted :: [(UUIDv7, Integer)]
  , forecastSelectionOriginalSubject :: UUIDv7
  , forecastSelectionEndpointSubject :: Maybe UUIDv7
  , forecastSelectionOpportunityKind :: Text
  , forecastSelectionDependencyPath :: [UUIDv7]
  , forecastSelectionDomainPath :: Maybe [UUIDv7]
  , forecastSelectionStrongestSignal :: Maybe Text
  , forecastSelectionAdditionalSignals :: [Text]
  , forecastSelectionDraws :: [ForecastDrawEvidence]
  , forecastSelectionExplanation :: Maybe ForecastExplanation
  }
  deriving stock (Eq, Generic, Show)

-- Captured inputs belong to the selection instant, never to a later projection.
data ForecastFactorEvidence = ForecastFactorEvidence
  { evidenceIdentity :: UUIDv7
  , evidenceSubject :: Text
  , evidencePosition :: Maybe (Int, Int)
  , evidenceConfidence :: Integer
  , evidenceFactors :: [(Text, Integer)]
  , evidenceSignals :: [Text]
  }
  deriving stock (Eq, Generic, Show)

data ForecastExplanation = ForecastExplanation
  { explanationRecordedAt :: UTCTime
  , explanationOriginal :: Text
  , explanationEndpoint :: Maybe Text
  , explanationDomain :: [Text]
  , explanationSubjectChance :: (Integer, Integer)
  , explanationOpportunityChance :: (Integer, Integer)
  , explanationFactors :: [ForecastFactorEvidence]
  }
  deriving stock (Eq, Generic, Show)

instance ToJSON ForecastFactorEvidence where
  toJSON value =
    object $
      [ "subject_id" .= renderUUIDv7 (evidenceIdentity value)
      , "subject" .= evidenceSubject value
      , "confidence_millionths" .= evidenceConfidence value
      , "factors_millionths" .= evidenceFactors value
      , "signals" .= evidenceSignals value
      ]
        <> maybe [] (pure . ("position" .=)) (evidencePosition value)
instance FromJSON ForecastFactorEvidence where
  parseJSON = withObject "forecast factor evidence" $ \value ->
    ForecastFactorEvidence
      <$> (value .: "subject_id" >>= either (fail . show) pure . parseUUIDv7)
      <*> value .: "subject"
      <*> value .:? "position"
      <*> value .: "confidence_millionths"
      <*> value .: "factors_millionths"
      <*> value .: "signals"
instance ToJSON ForecastExplanation where
  toJSON value =
    object $
      [ "recorded_at" .= explanationRecordedAt value
      , "original" .= explanationOriginal value
      , "domain" .= explanationDomain value
      , "subject_chance" .= explanationSubjectChance value
      , "opportunity_chance" .= explanationOpportunityChance value
      , "factors" .= explanationFactors value
      ]
        <> maybe [] (pure . ("endpoint" .=)) (explanationEndpoint value)
instance FromJSON ForecastExplanation where
  parseJSON = withObject "forecast explanation" $ \value ->
    ForecastExplanation
      <$> value .: "recorded_at"
      <*> value .: "original"
      <*> value .:? "endpoint"
      <*> value .: "domain"
      <*> value .: "subject_chance"
      <*> value .: "opportunity_chance"
      <*> value .: "factors"

data ImportanceReviewDeferral = ImportanceReviewDeferral
  { importanceReviewCooldownUntil :: UTCTime
  , importanceReviewDeferralCount :: Int
  }
  deriving stock (Eq, Generic, Show)

data State = State
  { stateRaws :: Map UUIDv7 Raw
  , stateRawHandles :: Map Handle UUIDv7
  , stateRetiredRawHandles :: Set Handle
  , stateRawDispositions :: Map UUIDv7 RawDisposition
  , stateRawTriageDeferrals :: Map UUIDv7 Int
  , stateRejectedRawDuplicates :: Set (UUIDv7, Int, UUIDv7, Int)
  , statePairJudgments :: Map UUIDv7 PairJudgment
  , stateImpactClaims :: Map UUIDv7 ImpactClaim
  , stateEffortClaims :: Map UUIDv7 EffortClaim
  , stateEffortActualEvidence :: Map UUIDv7 EffortActualEvidence
  , statePhaseClaims :: Map UUIDv7 PhaseClaim
  , stateBricks :: Map UUIDv7 Brick
  , stateBrickHandles :: Map Handle UUIDv7
  , stateRetiredBrickHandles :: Set Handle
  , stateDomains :: Map UUIDv7 Domain
  , stateRawShelves :: Map UUIDv7 RawShelf
  , stateListEntries :: Map UUIDv7 ListEntry
  , stateRawLinks :: Map UUIDv7 RawLink
  , stateImportanceEdges :: Set ImportanceEdge
  , stateLazyReviews :: Map UUIDv7 LazyReviewClaim
  , stateJudgmentReviews :: Map (JudgmentReviewKind, UUIDv7) JudgmentReview
  , stateCurrentFocus :: Maybe UUIDv7
  , stateCommandEffects :: Map UUIDv7 CommandEffect
  , stateMaterializationEffects :: Map UUIDv7 MaterializationEffect
  , stateLastRedo :: Maybe UUIDv7
  , stateActiveDomain :: Maybe UUIDv7
  , stateDomainScope :: Maybe DomainScope
  , stateRandomSeed :: Maybe ByteString
  , stateRandomCursors :: Map Text Integer
  , stateForecastSelections :: Map UUIDv7 ForecastSelectionEvidence
  , stateImportanceReviewDeferrals :: Map (Maybe UUIDv7) ImportanceReviewDeferral
  , stateWorkDeferrals :: Map UUIDv7 WorkDeferral
  , stateActiveSprint :: Maybe ActiveSprint
  , stateDependencies :: Map UUIDv7 Dependency
  , stateChecklistRuns :: Map UUIDv7 ChecklistRun
  , stateTemporalConstraints :: Map UUIDv7 TemporalConstraints
  , stateStandingOutcomes :: Map UUIDv7 StandingOutcome
  , stateReturnSchedules :: Map UUIDv7 ReturnSchedule
  , stateScheduledIntervals :: Map UUIDv7 ScheduledInterval
  , stateRecurrenceSchedules :: Map UUIDv7 RecurrenceSchedule
  , stateRecurringOccurrences :: Map UUIDv7 RecurringOccurrence
  , stateObligationPeriods :: Map UUIDv7 ObligationPeriod
  , stateHabitSchedules :: Map UUIDv7 HabitSchedule
  , stateHabitWindows :: Map UUIDv7 HabitWindow
  , stateHabitOutcomes :: Map UUIDv7 HabitOutcome
  , stateNoticeDispositions :: Map NoticeIdentity NoticeDisposition
  , stateExternalEntities :: Map UUIDv7 ExternalEntity
  , stateExternalEntityHandles :: Map Handle UUIDv7
  , stateRetiredExternalEntityHandles :: Set Handle
  , stateContactPoints :: Map UUIDv7 ContactPoint
  , stateWaits :: Map UUIDv7 WaitGate
  , stateWaitSuccessors :: Map UUIDv7 WaitSuccessor
  , stateWaitObservations :: Map UUIDv7 WaitObservation
  , stateDelegations :: Map UUIDv7 Delegation
  , stateExternalEffects :: Map UUIDv7 ExternalEffect
  , stateExternalEffectApprovalGrants :: Map UUIDv7 ExternalEffectApprovalGrant
  , stateExternalEffectReceipts :: Map UUIDv7 ExternalEffectReceipt
  , stateRawContentRevisions :: Map UUIDv7 RawContentRevision
  , stateCurrentRawRevisions :: Map UUIDv7 UUIDv7
  , stateEnglishNormalizations :: Map UUIDv7 EnglishNormalization
  , stateCurrentEnglishNormalizations :: Map UUIDv7 UUIDv7
  , stateBrickTitleNormalizations :: Map UUIDv7 BrickTitleNormalization
  , stateCurrentBrickTitleNormalizations :: Map UUIDv7 UUIDv7
  , stateImportProfiles :: Map UUIDv7 ImportProfile
  , stateImportInvocations :: Map UUIDv7 ImportInvocation
  , stateSourceBindings :: Map UUIDv7 SourceBinding
  , stateSourceObservations :: Map UUIDv7 SourceObservation
  , stateSourceReconciliations :: Map UUIDv7 SourceReconciliation
  , stateOperationalDayConfig :: OperationalDayConfig
  , stateEventCount :: Integer
  , stateUndoPoint :: Maybe UndoPoint
  , stateRedoPoint :: Maybe UndoPoint
  }
  deriving stock (Eq, Generic, Show)

{- | UX-020: the state on the other side of the latest reversible command.
For undo it is the state before that command; for redo, the state it left.
Restoring it is the compensation, so every event family is reversible
without a hand-written inverse.
-}
data UndoPoint = UndoPoint
  { undoPointCommand :: UUIDv7
  , undoPointState :: State
  , undoPointKinds :: [Text]
  , undoPointSummary :: [Text]
  }
  deriving stock (Eq, Generic, Show)

emptyState :: State
emptyState =
  State
    { stateRaws = Map.empty
    , stateRawHandles = Map.empty
    , stateRetiredRawHandles = Set.empty
    , stateRawDispositions = Map.empty
    , stateRawTriageDeferrals = Map.empty
    , stateRejectedRawDuplicates = Set.empty
    , statePairJudgments = Map.empty
    , stateImpactClaims = Map.empty
    , stateEffortClaims = Map.empty
    , stateEffortActualEvidence = Map.empty
    , statePhaseClaims = Map.empty
    , stateBricks = Map.empty
    , stateBrickHandles = Map.empty
    , stateRetiredBrickHandles = Set.empty
    , stateDomains = Map.empty
    , stateRawShelves = Map.empty
    , stateListEntries = Map.empty
    , stateRawLinks = Map.empty
    , stateImportanceEdges = Set.empty
    , stateLazyReviews = Map.empty
    , stateJudgmentReviews = Map.empty
    , stateCurrentFocus = Nothing
    , stateCommandEffects = Map.empty
    , stateMaterializationEffects = Map.empty
    , stateLastRedo = Nothing
    , stateActiveDomain = Nothing
    , stateDomainScope = Nothing
    , stateRandomSeed = Nothing
    , stateRandomCursors = Map.empty
    , stateForecastSelections = Map.empty
    , stateImportanceReviewDeferrals = Map.empty
    , stateWorkDeferrals = Map.empty
    , stateActiveSprint = Nothing
    , stateDependencies = Map.empty
    , stateChecklistRuns = Map.empty
    , stateTemporalConstraints = Map.empty
    , stateStandingOutcomes = Map.empty
    , stateReturnSchedules = Map.empty
    , stateScheduledIntervals = Map.empty
    , stateRecurrenceSchedules = Map.empty
    , stateRecurringOccurrences = Map.empty
    , stateObligationPeriods = Map.empty
    , stateHabitSchedules = Map.empty
    , stateHabitWindows = Map.empty
    , stateHabitOutcomes = Map.empty
    , stateNoticeDispositions = Map.empty
    , stateExternalEntities = Map.empty
    , stateExternalEntityHandles = Map.empty
    , stateRetiredExternalEntityHandles = Set.empty
    , stateContactPoints = Map.empty
    , stateWaits = Map.empty
    , stateWaitSuccessors = Map.empty
    , stateWaitObservations = Map.empty
    , stateDelegations = Map.empty
    , stateExternalEffects = Map.empty
    , stateExternalEffectApprovalGrants = Map.empty
    , stateExternalEffectReceipts = Map.empty
    , stateRawContentRevisions = Map.empty
    , stateCurrentRawRevisions = Map.empty
    , stateEnglishNormalizations = Map.empty
    , stateCurrentEnglishNormalizations = Map.empty
    , stateBrickTitleNormalizations = Map.empty
    , stateCurrentBrickTitleNormalizations = Map.empty
    , stateImportProfiles = Map.empty
    , stateImportInvocations = Map.empty
    , stateSourceBindings = Map.empty
    , stateSourceObservations = Map.empty
    , stateSourceReconciliations = Map.empty
    , stateOperationalDayConfig = OperationalDayConfig "America/Montevideo" (TimeOfDay 4 0 0) (TimeOfDay 6 0 0)
    , stateEventCount = 0
    , stateUndoPoint = Nothing
    , stateRedoPoint = Nothing
    }

inboxRaws :: State -> [Raw]
inboxRaws state =
  [ raw
  | raw <- Map.elems (stateRaws state)
  , rawStatus raw == RawAwaitingReview
  , Map.notMember (rawId raw) (stateRawDispositions state)
  ]

rawCount :: State -> Int
rawCount = length . inboxRaws

-- A retained historical edge cannot gate executable Work through a retired
-- endpoint. Missing endpoints remain visible as corrupt prerequisites.
dependencyIsBlocking :: State -> Dependency -> Bool
dependencyIsBlocking state dependency =
  dependencyStatus dependency == DependencyActive
    && all activeEndpoint [dependencyBlockedBrick dependency, dependencyBlockerBrick dependency]
 where
  activeEndpoint identity = maybe True ((== BrickActive) . brickStatus) (Map.lookup identity (stateBricks state))

activeBricks :: State -> [Brick]
activeBricks = filter ((== BrickActive) . brickStatus) . Map.elems . stateBricks

brickCount :: State -> Int
brickCount = length . activeBricks

siblingBricks :: State -> Maybe UUIDv7 -> [Brick]
siblingBricks state parent =
  filter ((== parent) . brickParent) (activeBricks state)

{- | Siblings that hold a human importance position. Recurring-obligation
series and their occurrences compete for time, not value, and never enter
the sibling importance order (IMP-057). Replay still places them physically
through 'siblingBricks'.
-}
importanceSiblings :: State -> Maybe UUIDv7 -> [Brick]
importanceSiblings state parent = filter (carriesImportance state) (siblingBricks state parent)

carriesImportance :: State -> Brick -> Bool
carriesImportance state brick =
  brickNature brick /= RecurringObligation && not (isObligationOccurrence state (brickId brick))

isObligationOccurrence :: State -> UUIDv7 -> Bool
isObligationOccurrence state identity = Map.member identity (stateRecurringOccurrences state)

{- | FOC-071: an open atomic occurrence escalates at its @best_before@, or
@obligation.default_escalation_lead_hours@ (24) before its deadline when it
has none. An occurrence with neither never escalates.
-}
obligationEscalatesAt :: State -> Brick -> Maybe UTCTime
obligationEscalatesAt state brick
  | not (isObligationOccurrence state (brickId brick)) = Nothing
  | brickNature brick /= AtomicTask || brickStatus brick /= BrickActive = Nothing
  | otherwise = case Map.lookup (brickId brick) (stateTemporalConstraints state) of
      Just TemporalConstraints{temporalBestBefore = Just preferred} -> Just (zonedInstantUtc preferred)
      Just TemporalConstraints{temporalDeadline = Just deadline} -> Just (addUTCTime (-(24 * 60 * 60)) (zonedInstantUtc deadline))
      _ -> Nothing

-- | @obligation.escalation_skip_cooldown_minutes@, 120 in the factory profile.
obligationEscalationSkipPause :: NominalDiffTime
obligationEscalationSkipPause = 120 * 60

-- | Released occurrences of one series, newest nominal anchor first.
seriesOccurrences :: State -> UUIDv7 -> [RecurringOccurrence]
seriesOccurrences state owner =
  sortOn
    (\occurrence -> (Down (zonedInstantUtc (recurringOccurrenceNominalAnchor occurrence)), recurringOccurrenceId occurrence))
    [occurrence | occurrence <- Map.elems (stateRecurringOccurrences state), recurringOccurrenceOwner occurrence == owner]

-- | Resolved periods of one series, newest first (WRK-164).
obligationPeriodHistory :: State -> UUIDv7 -> [(RecurringOccurrence, ObligationPeriodState)]
obligationPeriodHistory state owner =
  [ (occurrence, cell)
  | occurrence <- seriesOccurrences state owner
  , let cell = obligationPeriodState state (recurringOccurrenceId occurrence)
  , cell /= PeriodOpen
  ]

-- | The period-history cell of one released occurrence (WRK-164).
obligationPeriodState :: State -> UUIDv7 -> ObligationPeriodState
obligationPeriodState state identity = case Map.lookup identity (stateObligationPeriods state) of
  Just period
    | Just _ <- obligationPeriodExcusedAt period -> PeriodExcused
    | Just _ <- obligationPeriodDoneLateAt period -> PeriodDoneLate
    | Just _ <- obligationPeriodMissedAt period -> PeriodMissed
  _ -> case brickStatus <$> Map.lookup identity (stateBricks state) of
    Just BrickDone -> PeriodDoneOnTime
    Just BrickMissed -> PeriodMissed
    Just BrickCancelled -> PeriodExcused
    _ -> PeriodOpen

resolveRawHandle :: State -> Handle -> Maybe Raw
resolveRawHandle state handle = do
  identity <- Map.lookup handle (stateRawHandles state)
  raw <- Map.lookup identity (stateRaws state)
  if rawStatus raw == RawRetracted then Nothing else Just raw

resolveBrickHandle :: State -> Handle -> Maybe Brick
resolveBrickHandle state handle = do
  identity <- Map.lookup handle (stateBrickHandles state)
  Map.lookup identity (stateBricks state)

resolveExternalEntityHandle :: State -> Handle -> Maybe ExternalEntity
resolveExternalEntityHandle state handle = do
  identity <- Map.lookup handle (stateExternalEntityHandles state)
  entity <- Map.lookup identity (stateExternalEntities state)
  if externalEntityActive entity then Just entity else Nothing

instance ToJSON Actor where
  toJSON actor = object ["kind" .= actorKind actor, "profile" .= actorProfile actor]

instance FromJSON Actor where
  parseJSON = withObject "Actor" $ \value -> Actor <$> value .: "kind" <*> value .: "profile"

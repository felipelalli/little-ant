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
  EffortClass (..),
  Fixed (..),
  ForecastDrawEvidence (..),
  ForecastSelectionEvidence (..),
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
  ExternalEffectPurpose (..),
  ExternalEffectStatus (..),
  ExternalEffect (..),
  ExternalEffectReceipt (..),
  WorkState (..),
  WorkDeferral (..),
  ActiveSprint (..),
  activeBricks,
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

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Time (Day, DayOfWeek, TimeOfDay (..), UTCTime)
import LittleAnt.Id

data Actor = Actor {actorKind :: Text, actorProfile :: Text}
  deriving stock (Eq, Ord, Show)

data RawStatus = RawAwaitingReview | RawRetracted | RawArchived
  deriving stock (Eq, Ord, Show)

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
  deriving stock (Eq, Show)

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
  deriving stock (Eq, Show)

data RawContent
  = RawTextContent Text
  | RawUriContent Text (Maybe Text)
  | RawBlobContent Text Text Integer (Maybe Text)
  | RawStructuredContent Text Text
  deriving stock (Eq, Show)

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
  deriving stock (Eq, Show)

data NormalizationSource = HumanNormalization | PoweredUpNormalization | SkillNormalization | ImportNormalization
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data EnglishNormalization = EnglishNormalization
  { englishNormalizationId :: UUIDv7
  , englishNormalizationRevision :: UUIDv7
  , englishNormalizationText :: Text
  , englishNormalizationSource :: NormalizationSource
  , englishNormalizationProducer :: Maybe Text
  , englishNormalizationAcceptedAt :: UTCTime
  , englishNormalizationConfidence :: Maybe Fixed
  }
  deriving stock (Eq, Show)

data SourceMode = SourceSnapshot | SourceSynchronize | SourceMigrate
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ImportProfileLifecycle = ImportProfileActive | ImportProfileRetired
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ImportProfile = ImportProfile
  { importProfileId :: UUIDv7
  , importProfileAdapterId :: Text
  , importProfileSourceLabel :: Text
  , importProfileAccountLabel :: Maybe Text
  , importProfileInputReference :: Text
  , importProfileInputDigest :: Text
  , importProfileInputByteCount :: Int
  , importProfileMode :: SourceMode
  , importProfileCleanupSupported :: Bool
  , importProfilePackName :: Text
  , importProfilePackVersion :: Text
  , importProfilePackManifestDigest :: Text
  , importProfilePackArchiveDigest :: Text
  , importProfileSignerFingerprint :: Text
  , importProfileLifecycle :: ImportProfileLifecycle
  , importProfileRevision :: Int
  }
  deriving stock (Eq, Show)

data SourceCheckPolicy = SourceManualCheck | SourceIntervalCheck Integer
  deriving stock (Eq, Ord, Show)

data SourceBindingLifecycle = SourceBindingActive | SourceBindingPaused | SourceBindingDetached
  deriving stock (Bounded, Enum, Eq, Ord, Show)

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
  deriving stock (Eq, Show)

data SourceObservationOutcome
  = SourceUnchanged
  | SourceChanged
  | SourceMissing
  | SourceUnreachable
  | SourceUnauthorized
  | SourceMalformed
  deriving stock (Bounded, Enum, Eq, Ord, Show)

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
  deriving stock (Eq, Show)

data SourceReconciliationDisposition
  = SourceAcceptedAsRevision UUIDv7
  | SourceAcceptedAsDerivedRaw UUIDv7
  | SourceIgnoredAsUnrelated
  deriving stock (Eq, Ord, Show)

data SourceReconciliation = SourceReconciliation
  { sourceReconciliationId :: UUIDv7
  , sourceReconciliationObservation :: UUIDv7
  , sourceReconciliationDisposition :: SourceReconciliationDisposition
  , sourceReconciliationAt :: UTCTime
  , sourceReconciliationActor :: Actor
  }
  deriving stock (Eq, Show)

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
  deriving stock (Eq, Show)

data ExternalEntityKind = PersonEntity | TeamEntity | OrganizationEntity | AIAgentEntity | ServiceEntity
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ExternalEntity = ExternalEntity
  { externalEntityId :: UUIDv7
  , externalEntityHandle :: Handle
  , externalEntityName :: Text
  , externalEntityKind :: ExternalEntityKind
  , externalEntityActive :: Bool
  , externalEntityCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show)

data ContactPointKind = EmailContact | PhoneContact | URIContact | ProviderRecipientContact
  deriving stock (Bounded, Enum, Eq, Ord, Show)

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
  deriving stock (Eq, Show)

data WaitKind
  = HumanResponseWait UUIDv7
  | ExternalConditionWait Text
  deriving stock (Eq, Ord, Show)

data WaitStatus = WaitActive | WaitResolved | WaitCancelled
  deriving stock (Eq, Ord, Show)

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
  deriving stock (Eq, Show)

data WaitObservationKind
  = WaitActivatedObservation
  | WaitResponseReceivedObservation
  | WaitLongerObservation
  | WaitFollowUpObservation
  | WaitReviewSkippedObservation
  | WaitReclassifiedObservation
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data WaitObservation = WaitObservation
  { waitObservationId :: UUIDv7
  , waitObservationWait :: UUIDv7
  , waitObservationKind :: WaitObservationKind
  , waitObservationAt :: UTCTime
  , waitObservationActor :: Actor
  , waitObservationNote :: Maybe Text
  }
  deriving stock (Eq, Show)

data DelegationScope = BrickOnlyDelegation | WholeScopeDelegation
  deriving stock (Eq, Ord, Show)

data FollowUpPolicy = FollowUpOnce | FollowUpEvery | FollowUpNone
  deriving stock (Eq, Ord, Show)

data DelegationStatus
  = DelegationProposed
  | DelegationActive
  | DelegationCompleted
  | DelegationRefused
  | DelegationTakenBack
  | DelegationCancelled
  | DelegationReassigned
  deriving stock (Eq, Ord, Show)

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
  deriving stock (Eq, Show)

data ExternalEffectPurpose = DelegationDeliveryEffect | DelegationFollowUpEffect | DelegationTakeBackEffect
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ExternalEffectStatus
  = EffectPendingApproval
  | EffectApproved
  | EffectDispatching
  | EffectSucceeded
  | EffectFailed
  | EffectOutcomeUnknown
  | EffectRejected
  deriving stock (Eq, Ord, Show)

data ExternalEffect = ExternalEffect
  { externalEffectId :: UUIDv7
  , externalEffectDelegation :: UUIDv7
  , externalEffectPurpose :: ExternalEffectPurpose
  , externalEffectRevision :: Int
  , externalEffectTarget :: UUIDv7
  , externalEffectContactPoint :: Maybe UUIDv7
  , externalEffectAdapter :: Maybe Text
  , externalEffectMessage :: Text
  , externalEffectStatus :: ExternalEffectStatus
  , externalEffectReviewNotBefore :: Maybe ZonedInstant
  , externalEffectApprovedDigest :: Maybe Text
  }
  deriving stock (Eq, Show)

data ExternalEffectReceipt = ExternalEffectReceipt
  { externalEffectReceiptId :: UUIDv7
  , externalEffectReceiptEffect :: UUIDv7
  , externalEffectReceiptAt :: UTCTime
  , externalEffectReceiptOutcome :: ExternalEffectStatus
  , externalEffectReceiptProviderReference :: Maybe Text
  , externalEffectReceiptRedactedDetail :: Maybe Text
  }
  deriving stock (Eq, Show)

data RecurrenceFamily = DailyRecurrence | WeeklyRecurrence | MonthlyRecurrence | YearlyRecurrence
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data CalendarRule = CalendarRule
  { calendarFamily :: RecurrenceFamily
  , calendarEvery :: Int
  , calendarStartsOn :: Day
  , calendarWeekdays :: Set DayOfWeek
  , calendarIntendedDay :: Maybe Int
  , calendarIntendedMonth :: Maybe Int
  , calendarTimes :: [TimeOfDay]
  }
  deriving stock (Eq, Ord, Show)

data RecurrenceSchedule = RecurrenceSchedule
  { recurrenceOwner :: UUIDv7
  , recurrenceRule :: CalendarRule
  , recurrenceZone :: Text
  , recurrenceOccurrenceNature :: BrickNature
  , recurrenceDurationSeconds :: Maybe Integer
  , recurrenceNotBeforeOffsetSeconds :: Integer
  , recurrenceBestBeforeOffsetSeconds :: Maybe Integer
  , recurrenceDeadlineOffsetSeconds :: Maybe Integer
  , recurrenceRevision :: Int
  }
  deriving stock (Eq, Show)

data RecurringOccurrence = RecurringOccurrence
  { recurringOccurrenceId :: UUIDv7
  , recurringOccurrenceOwner :: UUIDv7
  , recurringOccurrenceBrick :: UUIDv7
  , recurringOccurrenceNominalAnchor :: ZonedInstant
  , recurringOccurrenceLabel :: Text
  , recurringOccurrenceScheduleRevision :: Int
  }
  deriving stock (Eq, Show)

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
  deriving stock (Eq, Show)

data HabitWindow = HabitWindow
  { habitWindowId :: UUIDv7
  , habitWindowOwner :: UUIDv7
  , habitWindowOpensAt :: ZonedInstant
  , habitWindowClosesAt :: ZonedInstant
  , habitWindowTarget :: Int
  , habitWindowScheduleRevision :: Int
  , habitWindowSettled :: Bool
  }
  deriving stock (Eq, Show)

data HabitOutcome = HabitOutcome
  { habitOutcomeId :: UUIDv7
  , habitOutcomeWindow :: UUIDv7
  , habitOutcomeOwner :: UUIDv7
  , habitOutcomeKind :: StandingOutcomeKind
  , habitOutcomeAt :: UTCTime
  }
  deriving stock (Eq, Show)

data NoticeKind = BestBeforeNotice | DeadlineNotice | RecurringReleaseNotice | TemporalTransitionNotice
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data NoticeIdentity = NoticeIdentity
  { noticeSubject :: UUIDv7
  , noticeFactRevision :: Int
  , noticeKind :: NoticeKind
  , noticeThreshold :: UTCTime
  }
  deriving stock (Eq, Ord, Show)

data NoticeDisposition
  = NoticeAcknowledged UTCTime
  | NoticeSnoozed ZonedInstant
  deriving stock (Eq, Show)

data OperationalDayConfig = OperationalDayConfig
  { operationalZone :: Text
  , operationalHabitDayStartsAt :: TimeOfDay
  , operationalWorkdayStartsAt :: TimeOfDay
  }
  deriving stock (Eq, Show)

data ScheduledInterval = ScheduledInterval
  { scheduledIntervalOwner :: UUIDv7
  , scheduledStartsAt :: ZonedInstant
  , scheduledEndsAt :: ZonedInstant
  , scheduledIntervalRevision :: Int
  }
  deriving stock (Eq, Show)

data ReturnUnit = ReturnDays | ReturnWeeks | ReturnMonths | ReturnYears
  deriving stock (Eq, Ord, Show)

data ReturnPolicy
  = ManualOnlyReturn
  | AfterCompletionReturn
      { returnCenter :: Int
      , returnUnit :: ReturnUnit
      , returnVariation :: Int
      , returnZone :: Text
      }
  deriving stock (Eq, Ord, Show)

data ReturnSchedule = ReturnSchedule
  { returnScheduleOwner :: UUIDv7
  , returnSchedulePolicy :: ReturnPolicy
  , returnScheduleChosenOffset :: Maybe Int
  , returnScheduleNotBefore :: Maybe ZonedInstant
  , returnScheduleResolution :: Maybe Text
  }
  deriving stock (Eq, Show)

data StandingOutcomeKind
  = StandingDone
  | StandingUnfulfilled
  | StandingBlocked
  | StandingPaused
  | StandingInapplicable
  | StandingAttended
  | StandingMissed
  | StandingCancelled
  deriving stock (Eq, Ord, Show)

data StandingOutcome = StandingOutcome
  { standingOutcomeId :: UUIDv7
  , standingOutcomeOwner :: UUIDv7
  , standingOutcomeKind :: StandingOutcomeKind
  , standingOutcomeAt :: UTCTime
  }
  deriving stock (Eq, Show)

data ZonedInstant = ZonedInstant
  { zonedInstantUtc :: UTCTime
  , zonedInstantZone :: Text
  }
  deriving stock (Eq, Ord, Show)

data TemporalConstraints = TemporalConstraints
  { temporalNotBefore :: Maybe ZonedInstant
  , temporalBestBefore :: Maybe ZonedInstant
  , temporalDeadline :: Maybe ZonedInstant
  , temporalRevision :: Int
  }
  deriving stock (Eq, Show)

data ChecklistRun = ChecklistRun
  { checklistRunId :: UUIDv7
  , checklistRunOwner :: UUIDv7
  , checklistRunStartedAt :: UTCTime
  , checklistRunMutationCount :: Int
  }
  deriving stock (Eq, Show)

data DomainFocusMode = OneSuggestion | StayWithin | PreferDomain
  deriving stock (Eq, Ord, Show)

data DomainScope = DomainScope
  { domainScopeTarget :: UUIDv7
  , domainScopeMode :: DomainFocusMode
  }
  deriving stock (Eq, Show)

data DependencyStatus = DependencyActive | DependencyResolved
  deriving stock (Eq, Ord, Show)

data Dependency = Dependency
  { dependencyId :: UUIDv7
  , dependencyBlockedBrick :: UUIDv7
  , dependencyBlockerBrick :: UUIDv7
  , dependencyStatus :: DependencyStatus
  , dependencySource :: Text
  , dependencyCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show)

data WorkDeferral = WorkDeferral
  { workDeferralId :: UUIDv7
  , workDeferralBrick :: UUIDv7
  , workDeferralSelection :: Maybe UUIDv7
  , workDeferralSymptom :: SkipSymptom
  , workDeferralReaction :: SkipReaction
  , workDeferralRecordedAt :: UTCTime
  , workDeferralCooldownUntil :: Maybe UTCTime
  }
  deriving stock (Eq, Show)

data ActiveSprint = ActiveSprint
  { activeSprintBrick :: UUIDv7
  , activeSprintStartedAt :: UTCTime
  , activeSprintEndsAt :: UTCTime
  , activeSprintMinutes :: Int
  }
  deriving stock (Eq, Show)

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
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data BrickStatus
  = BrickActive
  | BrickDone
  | BrickArchived
  | BrickSuperseded
  | BrickMerged
  | BrickMissed
  | BrickCancelled
  deriving stock (Eq, Ord, Show)

data WorkState = Idle | Wip
  deriving stock (Eq, Ord, Show)

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
  deriving stock (Eq, Ord, Show)

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
  deriving stock (Eq, Ord, Show)

data TemplateSelection = TemplateSelection
  { templateIdentifier :: Text
  , templateCatalogVersion :: Text
  , templateSource :: Text
  }
  deriving stock (Eq, Ord, Show)

data ImportanceConfidence
  = HumanComparison
  | DeterministicPosition Text
  | Provisional Text
  deriving stock (Eq, Ord, Show)

newtype Fixed = Fixed {unFixed :: Integer}
  deriving stock (Eq, Ord, Show)

data JudgmentAxis
  = ImportanceAxis
  | ImpactAxis
  | EffortAxis
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data JudgmentProvenance
  = DirectHuman
  | AssistedAccepted Text
  | HumanEitherOrder
  | DeterministicProvisional
  | ModelOnly Text
  deriving stock (Eq, Ord, Show)

data JudgmentRelation
  = MoreThan
  | EitherOrder
  | AboutSame
  deriving stock (Eq, Ord, Show)

data JudgmentStatus
  = JudgmentCurrent
  | JudgmentRetired UUIDv7 Text
  | JudgmentRetracted UUIDv7 Text
  | JudgmentUnresolved Text
  deriving stock (Eq, Ord, Show)

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
  deriving stock (Eq, Ord, Show)

data JudgmentLabel
  = ReviewedJudgment
  | ProvisionalJudgment
  | ReviewDueJudgment
  | HistoricalOnlyJudgment
  deriving stock (Eq, Ord, Show)

data WorkPhase
  = IdeaPhase
  | SpecPhase
  | ExecutionPhase
  | ValidationPhase
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data PhaseClaim = PhaseClaim
  { phaseClaimBrick :: UUIDv7
  , phaseClaimValue :: WorkPhase
  , phaseClaimRecordedAt :: UTCTime
  , phaseClaimProvenance :: JudgmentProvenance
  }
  deriving stock (Eq, Show)

data ImpactClass
  = VeryLowImpact
  | LowImpact
  | MediumImpact
  | HighImpact
  | VeryHighImpact
  | CriticalImpact
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ImpactMaturity
  = SpeculativeImpact
  | SupportedImpact
  | ValidatedImpact
  | ObservedImpact
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ImpactClaim = ImpactClaim
  { impactClaimBrick :: UUIDv7
  , impactClaimClass :: ImpactClass
  , impactClaimMaturity :: ImpactMaturity
  , impactClaimEvidence :: [UUIDv7]
  , impactClaimRecordedAt :: UTCTime
  , impactClaimProvenance :: JudgmentProvenance
  , impactClaimProfileHash :: Text
  }
  deriving stock (Eq, Show)

data EffortClass
  = VeryEasyEffort
  | EasyEffort
  | NormalEffort
  | ModerateEffort
  | HardEffort
  | VeryHardEffort
  | MiniProjectEffort
  | ProjectEffort
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data EffortClaim = EffortClaim
  { effortClaimBrick :: UUIDv7
  , effortClaimClass :: EffortClass
  , effortClaimRecordedAt :: UTCTime
  , effortClaimProvenance :: JudgmentProvenance
  , effortClaimProfileHash :: Text
  }
  deriving stock (Eq, Show)

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
  deriving stock (Eq, Show)

data Domain = Domain
  { domainId :: UUIDv7
  , domainName :: Text
  , domainParent :: Maybe UUIDv7
  , domainActive :: Bool
  }
  deriving stock (Eq, Show)

data RawShelf = RawShelf
  { rawShelfId :: UUIDv7
  , rawShelfName :: Text
  , rawShelfActive :: Bool
  , rawShelfMembers :: [UUIDv7]
  }
  deriving stock (Eq, Show)

data Quantity = Quantity
  { quantityCoefficient :: Integer
  , quantityScale :: Int
  , quantityUnit :: Text
  }
  deriving stock (Eq, Ord, Show)

data ListEntryState = EntryOpen | EntryResolved | EntryCancelled
  deriving stock (Eq, Ord, Show)

data ListEntry = ListEntry
  { listEntryId :: UUIDv7
  , listEntryOwner :: UUIDv7
  , listEntryLabel :: Text
  , listEntryQuantity :: Quantity
  , listEntryState :: ListEntryState
  , listEntryInsertionOrdinal :: Int
  , listEntryCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show)

data RawDisposition
  = RawKeptStandalone
  | RawGroupedAsDuplicate UUIDv7
  | RawMaterializedAsWork UUIDv7
  | RawMaterializedAsListEntry UUIDv7 UUIDv7
  | RawPlacedOnShelf UUIDv7
  | RawAttachedTo UUIDv7 RawLinkRole
  deriving stock (Eq, Ord, Show)

data RawLinkRole
  = DescriptionRole
  | MaterializationSourceRole
  | AttachmentRole
  | EvidenceRole
  | DerivedFromRole
  | DuplicateOfRole
  deriving stock (Eq, Ord, Show)

data RawLinkTarget
  = RawLinkBrick UUIDv7
  | RawLinkListEntry UUIDv7
  | RawLinkRaw UUIDv7
  deriving stock (Eq, Ord, Show)

data RawLink = RawLink
  { rawLinkId :: UUIDv7
  , rawLinkRaw :: UUIDv7
  , rawLinkTarget :: RawLinkTarget
  , rawLinkRole :: RawLinkRole
  , rawLinkCreatedAt :: UTCTime
  , rawLinkCreatedBy :: Actor
  }
  deriving stock (Eq, Show)

data ImportanceEdge = ImportanceEdge
  { importanceAbove :: UUIDv7
  , importanceBelow :: UUIDv7
  , importanceRecordedAt :: UTCTime
  , importanceSource :: Text
  }
  deriving stock (Eq, Ord, Show)

data LazyReviewClaim = LazyReviewClaim
  { lazyReviewId :: UUIDv7
  , lazyReviewSubject :: UUIDv7
  , lazyReviewKind :: Text
  , lazyReviewReason :: Text
  , lazyReviewCreatedAt :: UTCTime
  }
  deriving stock (Eq, Ord, Show)

data CommandEffect = CommandEffect
  { effectCommandId :: UUIDv7
  , effectActor :: Actor
  , effectCreatedRaws :: [UUIDv7]
  , effectCompensatedBy :: Maybe UUIDv7
  }
  deriving stock (Eq, Show)

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
  deriving stock (Eq, Show)

data ForecastDrawEvidence = ForecastDrawEvidence
  { forecastDrawPurpose :: Text
  , forecastDrawCandidates :: [(Text, Integer)]
  , forecastDrawTotal :: Integer
  , forecastDrawStartingCursor :: Integer
  , forecastDrawEndingCursor :: Integer
  , forecastDrawSampledInteger :: Integer
  , forecastDrawChosenIdentity :: Text
  }
  deriving stock (Eq, Show)

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
  }
  deriving stock (Eq, Show)

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
  , stateCurrentFocus :: Maybe UUIDv7
  , stateCommandEffects :: Map UUIDv7 CommandEffect
  , stateMaterializationEffects :: Map UUIDv7 MaterializationEffect
  , stateLastRedo :: Maybe UUIDv7
  , stateActiveDomain :: Maybe UUIDv7
  , stateDomainScope :: Maybe DomainScope
  , stateRandomSeed :: Maybe ByteString
  , stateRandomCursors :: Map Text Integer
  , stateForecastSelections :: Map UUIDv7 ForecastSelectionEvidence
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
  , stateExternalEffectReceipts :: Map UUIDv7 ExternalEffectReceipt
  , stateRawContentRevisions :: Map UUIDv7 RawContentRevision
  , stateCurrentRawRevisions :: Map UUIDv7 UUIDv7
  , stateEnglishNormalizations :: Map UUIDv7 EnglishNormalization
  , stateCurrentEnglishNormalizations :: Map UUIDv7 UUIDv7
  , stateBrickTitleNormalizations :: Map UUIDv7 BrickTitleNormalization
  , stateCurrentBrickTitleNormalizations :: Map UUIDv7 UUIDv7
  , stateImportProfiles :: Map UUIDv7 ImportProfile
  , stateSourceBindings :: Map UUIDv7 SourceBinding
  , stateSourceObservations :: Map UUIDv7 SourceObservation
  , stateSourceReconciliations :: Map UUIDv7 SourceReconciliation
  , stateOperationalDayConfig :: OperationalDayConfig
  , stateEventCount :: Integer
  }
  deriving stock (Eq, Show)

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
    , stateCurrentFocus = Nothing
    , stateCommandEffects = Map.empty
    , stateMaterializationEffects = Map.empty
    , stateLastRedo = Nothing
    , stateActiveDomain = Nothing
    , stateDomainScope = Nothing
    , stateRandomSeed = Nothing
    , stateRandomCursors = Map.empty
    , stateForecastSelections = Map.empty
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
    , stateExternalEffectReceipts = Map.empty
    , stateRawContentRevisions = Map.empty
    , stateCurrentRawRevisions = Map.empty
    , stateEnglishNormalizations = Map.empty
    , stateCurrentEnglishNormalizations = Map.empty
    , stateBrickTitleNormalizations = Map.empty
    , stateCurrentBrickTitleNormalizations = Map.empty
    , stateImportProfiles = Map.empty
    , stateSourceBindings = Map.empty
    , stateSourceObservations = Map.empty
    , stateSourceReconciliations = Map.empty
    , stateOperationalDayConfig = OperationalDayConfig "America/Montevideo" (TimeOfDay 4 0 0) (TimeOfDay 6 0 0)
    , stateEventCount = 0
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

activeBricks :: State -> [Brick]
activeBricks = filter ((== BrickActive) . brickStatus) . Map.elems . stateBricks

brickCount :: State -> Int
brickCount = length . activeBricks

siblingBricks :: State -> Maybe UUIDv7 -> [Brick]
siblingBricks state parent =
  filter ((== parent) . brickParent) (activeBricks state)

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

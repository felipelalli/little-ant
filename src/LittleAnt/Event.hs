module LittleAnt.Event (
  BrickCompleted (..),
  BrickCreated (..),
  BrickChildCreated (..),
  BrickNatureChanged (..),
  BrickFocused (..),
  BrickStatusChanged (..),
  DependencyAdded (..),
  DependencyResolution (..),
  DomainFocusChanged (..),
  EventDraft (..),
  EventPayload (..),
  ForecastSelected (..),
  ForecastFocusAccepted (..),
  FocusPaused (..),
  ImportanceCompared (..),
  ImportancePlacementMarked (..),
  EffortClassified (..),
  EffortActualObserved (..),
  ImpactClassified (..),
  PairJudgmentRecorded (..),
  PhaseChanged (..),
  ListEntryCreated (..),
  ListEntryQuantityChanged (..),
  ListEntryStateChanged (..),
  ChecklistRunStarted (..),
  ChecklistRunFinished (..),
  LazyReviewRequested (..),
  LazyReviewSettled (..),
  PersistedEvent (..),
  RawDispositionAccepted (..),
  RawDuplicateRejected (..),
  RawFed (..),
  RawContentRevisionAppended (..),
  EnglishNormalizationAccepted (..),
  BrickTitleNormalizationAccepted (..),
  ImportProfileChanged (..),
  ImportInvocationRecorded (..),
  SourceBindingChanged (..),
  SourceObservationRecorded (..),
  SourceObservationReconciled (..),
  RawFeedRestored (..),
  RawFeedRetracted (..),
  RawLinkAdded (..),
  RawShelfCreated (..),
  RawShelfMemberAdded (..),
  RawTriageDeferred (..),
  SprintStarted (..),
  TemporalConstraintsChanged (..),
  StandingOutcomeRecorded (..),
  RepeatableReturnSet (..),
  ScheduledIntervalSet (..),
  RecurrenceScheduleSet (..),
  RecurringOccurrenceReleased (..),
  HabitScheduleSet (..),
  HabitWindowOpened (..),
  HabitWindowOutcomeRecorded (..),
  NoticeDispositionChanged (..),
  OperationalDayConfigChanged (..),
  ExternalEntityRegistered (..),
  ContactPointRegistered (..),
  WaitChanged (..),
  WaitSuccessorDeclared (..),
  DelegationChanged (..),
  ExternalEffectChanged (..),
  ExternalEffectApprovalGranted (..),
  ExternalEffectReceiptRecorded (..),
  WorkReactionRecorded (..),
  rawContentDigest,
  applyEvent,
  decodeEvent,
  encodeEvent,
  eventTypeName,
  eventVersionNumber,
  externalEffectConsentDigest,
  externalEffectRequestDigest,
)
where

import Control.Monad (foldM, unless, void, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson
import Data.Aeson.Encoding (encodingToLazyByteString)
import Data.Aeson.Types (Pair, Parser)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base16 qualified as Base16
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAscii, isDigit)
import Data.Foldable (traverse_)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, isJust, isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (DayOfWeek (..), UTCTime, addUTCTime, defaultTimeLocale, formatTime)
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Judgment (ContradictionAssessment (..), detectContradiction, factoryJudgmentProfileHash, initialConfidence, reorderedSiblingIds)
import LittleAnt.Model
import LittleAnt.Schedule (validateCalendarRule)

data RawFed = RawFed
  { fedRawId :: UUIDv7
  , fedHandle :: Handle
  , fedOriginal :: Text
  , fedOrigin :: Text
  , fedContent :: Maybe RawContent
  }
  deriving stock (Eq, Show)

data BrickTitleNormalizationAccepted = BrickTitleNormalizationAccepted
  { acceptedTitleNormalizationBrick :: UUIDv7
  , acceptedTitleNormalizationPrevious :: Text
  , acceptedTitleNormalizationCurrent :: Text
  , acceptedTitleNormalizationSource :: NormalizationSource
  , acceptedTitleNormalizationProducer :: Maybe Text
  , acceptedTitleNormalizationConfidence :: Maybe Fixed
  }
  deriving stock (Eq, Show)

data RawContentRevisionAppended = RawContentRevisionAppended
  { appendedRawRevisionRaw :: UUIDv7
  , appendedRawRevisionOrdinal :: Int
  , appendedRawRevisionProvenance :: Text
  , appendedRawRevisionContent :: RawContent
  , appendedRawRevisionDigest :: Text
  }
  deriving stock (Eq, Show)

data EnglishNormalizationAccepted = EnglishNormalizationAccepted
  { acceptedNormalizationRevision :: UUIDv7
  , acceptedNormalizationText :: Text
  , acceptedNormalizationSource :: NormalizationSource
  , acceptedNormalizationProducer :: Maybe Text
  , acceptedNormalizationConfidence :: Maybe Fixed
  }
  deriving stock (Eq, Show)

newtype SourceBindingChanged = SourceBindingChanged
  { changedSourceBinding :: SourceBinding
  }
  deriving stock (Eq, Show)

newtype ImportProfileChanged = ImportProfileChanged
  { changedImportProfile :: ImportProfile
  }
  deriving stock (Eq, Show)

newtype ImportInvocationRecorded = ImportInvocationRecorded
  { recordedImportInvocation :: ImportInvocation
  }
  deriving stock (Eq, Show)

data SourceObservationRecorded = SourceObservationRecorded
  { recordedSourceObservationBinding :: UUIDv7
  , recordedSourceObservationLocator :: Text
  , recordedSourceObservationOutcome :: SourceObservationOutcome
  , recordedSourceObservationProviderVersion :: Maybe Text
  , recordedSourceObservationFingerprint :: Maybe Text
  , recordedSourceObservationSnapshotDigest :: Maybe Text
  , recordedSourceObservationSnapshot :: Maybe RawContent
  }
  deriving stock (Eq, Show)

data SourceObservationReconciled = SourceObservationReconciled
  { reconciledSourceObservation :: UUIDv7
  , reconciledSourceDisposition :: SourceReconciliationDisposition
  }
  deriving stock (Eq, Show)

newtype WaitSuccessorDeclared = WaitSuccessorDeclared
  { declaredWaitSuccessor :: WaitSuccessor
  }
  deriving stock (Eq, Show)

newtype ExternalEntityRegistered = ExternalEntityRegistered
  { registeredExternalEntity :: ExternalEntity
  }
  deriving stock (Eq, Show)

newtype ContactPointRegistered = ContactPointRegistered
  { registeredContactPoint :: ContactPoint
  }
  deriving stock (Eq, Show)

data WaitChanged = WaitChanged
  { changedWaitGate :: WaitGate
  , changedWaitObservation :: WaitObservation
  }
  deriving stock (Eq, Show)

newtype DelegationChanged = DelegationChanged
  { changedDelegation :: Delegation
  }
  deriving stock (Eq, Show)

newtype ExternalEffectChanged = ExternalEffectChanged
  { changedExternalEffect :: ExternalEffect
  }
  deriving stock (Eq, Show)

newtype ExternalEffectApprovalGranted = ExternalEffectApprovalGranted
  { grantedExternalEffectApproval :: ExternalEffectApprovalGrant
  }
  deriving stock (Eq, Show)

newtype ExternalEffectReceiptRecorded = ExternalEffectReceiptRecorded
  { recordedExternalEffectReceipt :: ExternalEffectReceipt
  }
  deriving stock (Eq, Show)

newtype RecurrenceScheduleSet = RecurrenceScheduleSet
  { setRecurrenceSchedule :: RecurrenceSchedule
  }
  deriving stock (Eq, Show)

data RecurringOccurrenceReleased = RecurringOccurrenceReleased
  { releasedOccurrence :: RecurringOccurrence
  , releasedOccurrenceHandle :: Handle
  , releasedOccurrenceTitle :: Text
  , releasedOccurrenceNature :: BrickNature
  , releasedOccurrenceDomains :: Set.Set UUIDv7
  , releasedOccurrencePosition :: Int
  , releasedOccurrenceTemporal :: TemporalConstraints
  , releasedOccurrenceInterval :: Maybe ScheduledInterval
  }
  deriving stock (Eq, Show)

newtype HabitScheduleSet = HabitScheduleSet
  { setHabitSchedule :: HabitSchedule
  }
  deriving stock (Eq, Show)

newtype HabitWindowOpened = HabitWindowOpened
  { openedHabitWindow :: HabitWindow
  }
  deriving stock (Eq, Show)

data HabitWindowOutcomeRecorded = HabitWindowOutcomeRecorded
  { recordedHabitWindowOutcomeId :: UUIDv7
  , recordedHabitWindowId :: UUIDv7
  , recordedHabitWindowOwner :: UUIDv7
  , recordedHabitWindowOutcome :: StandingOutcomeKind
  }
  deriving stock (Eq, Show)

data NoticeDispositionChanged = NoticeDispositionChanged
  { changedNoticeIdentity :: NoticeIdentity
  , changedNoticeDisposition :: NoticeDisposition
  }
  deriving stock (Eq, Show)

newtype OperationalDayConfigChanged = OperationalDayConfigChanged
  { changedOperationalDayConfig :: OperationalDayConfig
  }
  deriving stock (Eq, Show)

data ScheduledIntervalSet = ScheduledIntervalSet
  { intervalSetOwner :: UUIDv7
  , intervalSetStartsAt :: ZonedInstant
  , intervalSetEndsAt :: ZonedInstant
  , intervalSetRevision :: Int
  }
  deriving stock (Eq, Show)

data RepeatableReturnSet = RepeatableReturnSet
  { repeatableReturnOwner :: UUIDv7
  , repeatableReturnPolicy :: ReturnPolicy
  , repeatableReturnChosenOffset :: Maybe Int
  , repeatableReturnNotBefore :: Maybe ZonedInstant
  , repeatableReturnResolution :: Maybe Text
  , repeatableReturnSeed :: Maybe ByteString
  , repeatableReturnDraw :: Maybe ForecastDrawEvidence
  }
  deriving stock (Eq, Show)

data StandingOutcomeRecorded = StandingOutcomeRecorded
  { recordedStandingOwner :: UUIDv7
  , recordedStandingOutcome :: StandingOutcomeKind
  }
  deriving stock (Eq, Show)

data TemporalConstraintsChanged = TemporalConstraintsChanged
  { changedTemporalBrick :: UUIDv7
  , changedTemporalNotBefore :: Maybe ZonedInstant
  , changedTemporalBestBefore :: Maybe ZonedInstant
  , changedTemporalDeadline :: Maybe ZonedInstant
  , changedTemporalRevision :: Int
  }
  deriving stock (Eq, Show)

data ListEntryStateChanged = ListEntryStateChanged
  { stateChangedListEntryId :: UUIDv7
  , stateChangedChecklistRunId :: UUIDv7
  , previousListEntryState :: ListEntryState
  , currentListEntryState :: ListEntryState
  }
  deriving stock (Eq, Show)

data ChecklistRunStarted = ChecklistRunStarted
  { startedChecklistRunId :: UUIDv7
  , startedChecklistOwner :: UUIDv7
  }
  deriving stock (Eq, Show)

data ChecklistRunFinished = ChecklistRunFinished
  { finishedChecklistRunId :: UUIDv7
  , finishedChecklistOwner :: UUIDv7
  }
  deriving stock (Eq, Show)

data LazyReviewSettled = LazyReviewSettled
  { settledReviewId :: UUIDv7
  , settledReviewOutcome :: Text
  }
  deriving stock (Eq, Show)

data BrickStatusChanged = BrickStatusChanged
  { statusChangedBrick :: UUIDv7
  , statusChangedFrom :: BrickStatus
  , statusChangedTo :: BrickStatus
  , statusChangedReason :: Text
  }
  deriving stock (Eq, Show)

data DependencyAdded = DependencyAdded
  { addedDependencyId :: UUIDv7
  , addedDependencyBlockedBrick :: UUIDv7
  , addedDependencyBlockerBrick :: UUIDv7
  , addedDependencySource :: Text
  }
  deriving stock (Eq, Show)

newtype DependencyResolution = DependencyResolution {resolvedDependencyId :: UUIDv7}
  deriving stock (Eq, Show)

data DomainFocusChanged = DomainFocusChanged
  { changedDomainFocusTarget :: Maybe UUIDv7
  , changedDomainFocusMode :: Text
  }
  deriving stock (Eq, Show)

data BrickNatureChanged = BrickNatureChanged
  { natureChangedBrick :: UUIDv7
  , natureChangedFrom :: BrickNature
  , natureChangedTo :: BrickNature
  , natureChangedSource :: Text
  }
  deriving stock (Eq, Show)

data BrickChildCreated = BrickChildCreated
  { createdChildId :: UUIDv7
  , createdChildHandle :: Handle
  , createdChildTitle :: Text
  , createdChildNature :: BrickNature
  , createdChildNatureVersion :: Text
  , createdChildNatureSource :: Text
  , createdChildParent :: UUIDv7
  , createdChildSiblingPosition :: Int
  , createdChildImportanceConfidence :: ImportanceConfidence
  }
  deriving stock (Eq, Show)

data LazyReviewRequested = LazyReviewRequested
  { requestedReviewSubject :: UUIDv7
  , requestedReviewKind :: Text
  , requestedReviewReason :: Text
  }
  deriving stock (Eq, Show)

data WorkReactionRecorded = WorkReactionRecorded
  { recordedWorkReactionBrick :: UUIDv7
  , recordedWorkReactionSelection :: Maybe UUIDv7
  , recordedWorkReactionSymptom :: SkipSymptom
  , recordedWorkReaction :: SkipReaction
  , recordedWorkReactionCooldownUntil :: Maybe UTCTime
  }
  deriving stock (Eq, Show)

newtype FocusPaused = FocusPaused {pausedFocusBrick :: UUIDv7}
  deriving stock (Eq, Show)

data SprintStarted = SprintStarted
  { sprintStartedBrick :: UUIDv7
  , sprintStartedMinutes :: Int
  , sprintStartedEndsAt :: UTCTime
  }
  deriving stock (Eq, Show)

data ForecastFocusAccepted = ForecastFocusAccepted
  { acceptedForecastSelection :: UUIDv7
  , acceptedForecastBrick :: UUIDv7
  , acceptedForecastDomain :: Maybe UUIDv7
  }
  deriving stock (Eq, Show)

data RawFeedRetracted = RawFeedRetracted
  { retractedRawId :: UUIDv7
  , retractedFeedCommandId :: UUIDv7
  }
  deriving stock (Eq, Show)

data RawFeedRestored = RawFeedRestored
  { restoredRawId :: UUIDv7
  , restoredFeedCommandId :: UUIDv7
  , restoredRetractionCommandId :: UUIDv7
  }
  deriving stock (Eq, Show)

data BrickCreated = BrickCreated
  { createdBrickId :: UUIDv7
  , createdBrickHandle :: Handle
  , createdBrickTitle :: Text
  , createdBrickNature :: BrickNature
  , createdNatureVersion :: Text
  , createdNatureSource :: Text
  , createdTemplate :: Maybe TemplateSelection
  , createdParent :: Maybe UUIDv7
  , createdDomains :: Set.Set UUIDv7
  , createdSiblingPosition :: Int
  , createdImportanceConfidence :: ImportanceConfidence
  , createdSourceRawId :: UUIDv7
  }
  deriving stock (Eq, Show)

data RawLinkAdded = RawLinkAdded
  { addedRawLinkId :: UUIDv7
  , addedRawId :: UUIDv7
  , addedRawLinkTarget :: RawLinkTarget
  , addedRawLinkRole :: RawLinkRole
  }
  deriving stock (Eq, Show)

data RawDispositionAccepted = RawDispositionAccepted
  { dispositionRawId :: UUIDv7
  , acceptedRawDisposition :: RawDisposition
  }
  deriving stock (Eq, Show)

data RawTriageDeferred = RawTriageDeferred
  { deferredRawId :: UUIDv7
  , deferredCount :: Int
  }
  deriving stock (Eq, Show)

data RawShelfCreated = RawShelfCreated
  { createdRawShelfId :: UUIDv7
  , createdRawShelfName :: Text
  , createdRawShelfSourceRaw :: UUIDv7
  }
  deriving stock (Eq, Show)

data RawShelfMemberAdded = RawShelfMemberAdded
  { memberRawShelfId :: UUIDv7
  , memberRawId :: UUIDv7
  , memberRawOrdinal :: Int
  }
  deriving stock (Eq, Show)

data RawDuplicateRejected = RawDuplicateRejected
  { duplicateCandidateRawId :: UUIDv7
  , duplicateComparedRawId :: UUIDv7
  , duplicateCandidateRevision :: Int
  , duplicateComparedRevision :: Int
  }
  deriving stock (Eq, Ord, Show)

data ImportanceCompared = ImportanceCompared
  { comparedAbove :: UUIDv7
  , comparedBelow :: UUIDv7
  , comparisonSource :: Text
  }
  deriving stock (Eq, Show)

data ImportancePlacementMarked = ImportancePlacementMarked
  { markedImportanceBrick :: UUIDv7
  , markedImportanceConfidence :: ImportanceConfidence
  , markedImportanceReason :: Text
  }
  deriving stock (Eq, Show)

data PairJudgmentRecorded = PairJudgmentRecorded
  { recordedJudgmentId :: UUIDv7
  , recordedJudgmentAxis :: JudgmentAxis
  , recordedJudgmentFirst :: UUIDv7
  , recordedJudgmentSecond :: UUIDv7
  , recordedJudgmentRelation :: JudgmentRelation
  , recordedJudgmentProvenance :: JudgmentProvenance
  , recordedJudgmentInitialConfidence :: Fixed
  , recordedJudgmentProfileHash :: Text
  , recordedJudgmentContext :: Text
  , recordedJudgmentReason :: Text
  , recordedJudgmentStatus :: JudgmentStatus
  , recordedRetiredJudgments :: [UUIDv7]
  }
  deriving stock (Eq, Show)

data PhaseChanged = PhaseChanged
  { changedPhaseBrick :: UUIDv7
  , changedPhaseValue :: Maybe WorkPhase
  , changedPhaseProvenance :: JudgmentProvenance
  }
  deriving stock (Eq, Show)

data ImpactClassified = ImpactClassified
  { classifiedImpactBrick :: UUIDv7
  , classifiedImpactClass :: Maybe ImpactClass
  , classifiedImpactMaturity :: ImpactMaturity
  , classifiedImpactEvidence :: [UUIDv7]
  , classifiedImpactProvenance :: JudgmentProvenance
  , classifiedImpactProfileHash :: Text
  }
  deriving stock (Eq, Show)

data EffortClassified = EffortClassified
  { classifiedEffortBrick :: UUIDv7
  , classifiedEffortClass :: Maybe EffortClass
  , classifiedEffortProvenance :: JudgmentProvenance
  , classifiedEffortProfileHash :: Text
  }
  deriving stock (Eq, Show)

data EffortActualObserved = EffortActualObserved
  { observedEffortActualBrick :: UUIDv7
  , observedEffortActualRaw :: UUIDv7
  , observedEffortActualImportInvocation :: UUIDv7
  , observedEffortActualPlanningManifestDigest :: Text
  , observedEffortActualTaskId :: Text
  , observedEffortActualAsOf :: UTCTime
  , observedEffortActualCompletedMicrohours :: Maybe Integer
  , observedEffortActualRemainingMicrohours :: Maybe Integer
  }
  deriving stock (Eq, Show)

newtype BrickFocused = BrickFocused {focusedBrickId :: UUIDv7}
  deriving stock (Eq, Show)

newtype BrickCompleted = BrickCompleted {completedBrickId :: UUIDv7}
  deriving stock (Eq, Show)

newtype ForecastSelected = ForecastSelected
  { selectedForecastEvidence :: ForecastSelectionEvidence
  }
  deriving stock (Eq, Show)

data ListEntryCreated = ListEntryCreated
  { createdListEntryId :: UUIDv7
  , createdListEntryOwner :: UUIDv7
  , createdListEntryLabel :: Text
  , createdListEntryQuantity :: Quantity
  , createdListEntryOrdinal :: Int
  , createdListEntrySourceRaw :: UUIDv7
  }
  deriving stock (Eq, Show)

data ListEntryQuantityChanged = ListEntryQuantityChanged
  { changedListEntryId :: UUIDv7
  , changedListEntrySourceRaw :: UUIDv7
  , previousListEntryQuantity :: Quantity
  , currentListEntryQuantity :: Quantity
  }
  deriving stock (Eq, Show)

data EventPayload
  = RawFedV1 RawFed
  | RawContentRevisionAppendedV1 RawContentRevisionAppended
  | EnglishNormalizationAcceptedV1 EnglishNormalizationAccepted
  | BrickTitleNormalizationAcceptedV1 BrickTitleNormalizationAccepted
  | ImportProfileChangedV1 ImportProfileChanged
  | ImportInvocationRecordedV1 ImportInvocationRecorded
  | SourceBindingChangedV1 SourceBindingChanged
  | SourceObservationRecordedV1 SourceObservationRecorded
  | SourceObservationReconciledV1 SourceObservationReconciled
  | RawFeedRetractedV1 RawFeedRetracted
  | RawFeedRestoredV1 RawFeedRestored
  | BrickCreatedV1 BrickCreated
  | BrickNatureChangedV1 BrickNatureChanged
  | BrickChildCreatedV1 BrickChildCreated
  | LazyReviewRequestedV1 LazyReviewRequested
  | LazyReviewSettledV1 LazyReviewSettled
  | BrickStatusChangedV1 BrickStatusChanged
  | RawLinkAddedV1 RawLinkAdded
  | RawDispositionAcceptedV1 RawDispositionAccepted
  | RawTriageDeferredV1 RawTriageDeferred
  | RawShelfCreatedV1 RawShelfCreated
  | RawShelfMemberAddedV1 RawShelfMemberAdded
  | RawDuplicateRejectedV1 RawDuplicateRejected
  | ListEntryCreatedV1 ListEntryCreated
  | ListEntryQuantityChangedV1 ListEntryQuantityChanged
  | ListEntryStateChangedV1 ListEntryStateChanged
  | ChecklistRunStartedV1 ChecklistRunStarted
  | ChecklistRunFinishedV1 ChecklistRunFinished
  | TemporalConstraintsChangedV1 TemporalConstraintsChanged
  | StandingOutcomeRecordedV1 StandingOutcomeRecorded
  | RepeatableReturnSetV1 RepeatableReturnSet
  | ScheduledIntervalSetV1 ScheduledIntervalSet
  | RecurrenceScheduleSetV1 RecurrenceScheduleSet
  | RecurringOccurrenceReleasedV1 RecurringOccurrenceReleased
  | HabitScheduleSetV1 HabitScheduleSet
  | HabitWindowOpenedV1 HabitWindowOpened
  | HabitWindowOutcomeRecordedV1 HabitWindowOutcomeRecorded
  | NoticeDispositionChangedV1 NoticeDispositionChanged
  | OperationalDayConfigChangedV1 OperationalDayConfigChanged
  | ImportanceComparedV1 ImportanceCompared
  | ImportancePlacementMarkedV1 ImportancePlacementMarked
  | PairJudgmentRecordedV1 PairJudgmentRecorded
  | PhaseChangedV1 PhaseChanged
  | ImpactClassifiedV1 ImpactClassified
  | EffortClassifiedV1 EffortClassified
  | EffortActualObservedV1 EffortActualObserved
  | BrickFocusedV1 BrickFocused
  | BrickCompletedV1 BrickCompleted
  | ForecastSelectedV1 ForecastSelected
  | ForecastFocusAcceptedV1 ForecastFocusAccepted
  | WorkReactionRecordedV1 WorkReactionRecorded
  | FocusPausedV1 FocusPaused
  | SprintStartedV1 SprintStarted
  | DependencyAddedV1 DependencyAdded
  | DependencyResolvedV1 DependencyResolution
  | DomainFocusChangedV1 DomainFocusChanged
  | ExternalEntityRegisteredV1 ExternalEntityRegistered
  | ContactPointRegisteredV1 ContactPointRegistered
  | WaitChangedV1 WaitChanged
  | WaitSuccessorDeclaredV1 WaitSuccessorDeclared
  | DelegationChangedV1 DelegationChanged
  | ExternalEffectChangedV1 ExternalEffectChanged
  | ExternalEffectApprovalGrantedV1 ExternalEffectApprovalGranted
  | ExternalEffectReceiptRecordedV1 ExternalEffectReceiptRecorded
  deriving stock (Eq, Show)

data EventDraft = EventDraft
  { draftEventId :: UUIDv7
  , draftCommandId :: UUIDv7
  , draftActor :: Actor
  , draftRecordedAt :: UTCTime
  , draftPreconditionHash :: Text
  , draftReplayUUIDs :: [UUIDv7]
  , draftPayload :: EventPayload
  }
  deriving stock (Eq, Show)

data PersistedEvent = PersistedEvent
  { persistedEventId :: UUIDv7
  , persistedCommandId :: UUIDv7
  , persistedSegmentSequence :: Integer
  , persistedEventSequence :: Int
  , persistedActor :: Actor
  , persistedRecordedAt :: UTCTime
  , persistedPreviousSegmentHash :: Text
  , persistedPreconditionHash :: Text
  , persistedReplayUUIDs :: [UUIDv7]
  , persistedPayload :: EventPayload
  }
  deriving stock (Eq, Show)

eventTypeName :: EventPayload -> Text
eventTypeName = \case
  RawFedV1 _ -> "raw_fed"
  RawContentRevisionAppendedV1 _ -> "raw_content_revision_appended"
  EnglishNormalizationAcceptedV1 _ -> "english_normalization_accepted"
  BrickTitleNormalizationAcceptedV1 _ -> "brick_title_normalization_accepted"
  ImportProfileChangedV1 _ -> "import_profile_changed"
  ImportInvocationRecordedV1 _ -> "import_invocation_recorded"
  SourceBindingChangedV1 _ -> "source_binding_changed"
  SourceObservationRecordedV1 _ -> "source_observation_recorded"
  SourceObservationReconciledV1 _ -> "source_observation_reconciled"
  RawFeedRetractedV1 _ -> "raw_feed_retracted"
  RawFeedRestoredV1 _ -> "raw_feed_restored"
  BrickCreatedV1 _ -> "brick_created"
  BrickNatureChangedV1 _ -> "brick_nature_changed"
  BrickChildCreatedV1 _ -> "brick_child_created"
  LazyReviewRequestedV1 _ -> "lazy_review_requested"
  LazyReviewSettledV1 _ -> "lazy_review_settled"
  BrickStatusChangedV1 _ -> "brick_status_changed"
  RawLinkAddedV1 _ -> "raw_link_added"
  RawDispositionAcceptedV1 _ -> "raw_disposition_accepted"
  RawTriageDeferredV1 _ -> "raw_triage_deferred"
  RawShelfCreatedV1 _ -> "raw_shelf_created"
  RawShelfMemberAddedV1 _ -> "raw_shelf_member_added"
  RawDuplicateRejectedV1 _ -> "raw_duplicate_rejected"
  ListEntryCreatedV1 _ -> "list_entry_created"
  ListEntryQuantityChangedV1 _ -> "list_entry_quantity_changed"
  ListEntryStateChangedV1 _ -> "list_entry_state_changed"
  ChecklistRunStartedV1 _ -> "checklist_run_started"
  ChecklistRunFinishedV1 _ -> "checklist_run_finished"
  TemporalConstraintsChangedV1 _ -> "temporal_constraints_changed"
  StandingOutcomeRecordedV1 _ -> "standing_outcome_recorded"
  RepeatableReturnSetV1 _ -> "repeatable_return_set"
  ScheduledIntervalSetV1 _ -> "scheduled_interval_set"
  RecurrenceScheduleSetV1 _ -> "recurrence_schedule_set"
  RecurringOccurrenceReleasedV1 _ -> "recurring_occurrence_released"
  HabitScheduleSetV1 _ -> "habit_schedule_set"
  HabitWindowOpenedV1 _ -> "habit_window_opened"
  HabitWindowOutcomeRecordedV1 _ -> "habit_window_outcome_recorded"
  NoticeDispositionChangedV1 _ -> "notice_disposition_changed"
  OperationalDayConfigChangedV1 _ -> "operational_day_config_changed"
  ImportanceComparedV1 _ -> "importance_compared"
  ImportancePlacementMarkedV1 _ -> "importance_placement_marked"
  PairJudgmentRecordedV1 _ -> "pair_judgment_recorded"
  PhaseChangedV1 _ -> "phase_changed"
  ImpactClassifiedV1 _ -> "impact_classified"
  EffortClassifiedV1 _ -> "effort_classified"
  EffortActualObservedV1 _ -> "effort_actual_observed"
  BrickFocusedV1 _ -> "brick_focused"
  BrickCompletedV1 _ -> "brick_completed"
  ForecastSelectedV1 _ -> "forecast_selected"
  ForecastFocusAcceptedV1 _ -> "forecast_focus_accepted"
  WorkReactionRecordedV1 _ -> "work_reaction_recorded"
  FocusPausedV1 _ -> "focus_paused"
  SprintStartedV1 _ -> "sprint_started"
  DependencyAddedV1 _ -> "dependency_added"
  DependencyResolvedV1 _ -> "dependency_resolved"
  DomainFocusChangedV1 _ -> "domain_focus_changed"
  ExternalEntityRegisteredV1 _ -> "external_entity_registered"
  ContactPointRegisteredV1 _ -> "contact_point_registered"
  WaitChangedV1 _ -> "wait_changed"
  WaitSuccessorDeclaredV1 _ -> "wait_successor_declared"
  DelegationChangedV1 _ -> "delegation_changed"
  ExternalEffectChangedV1 _ -> "external_effect_changed"
  ExternalEffectApprovalGrantedV1 _ -> "external_effect_approval_granted"
  ExternalEffectReceiptRecordedV1 _ -> "external_effect_receipt_recorded"

eventVersionNumber :: EventPayload -> Int
eventVersionNumber _ = 1

encodeEvent :: PersistedEvent -> ByteString
encodeEvent = LazyByteString.toStrict . encodingToLazyByteString . toEncoding

decodeEvent :: ByteString -> Either AppError PersistedEvent
decodeEvent bytes = case eitherDecodeStrict' bytes of
  Left problem
    | "unknown event" `Text.isInfixOf` Text.pack problem ->
        Left
          (appError UnknownEventVersion "The event uses an unsupported version.")
            { appErrorDetails = [Text.pack problem]
            }
    | otherwise ->
        Left
          (appError CorruptData "An accepted JSONL event is malformed.")
            { appErrorDetails = [Text.pack problem]
            }
  Right value -> Right value

applyDomainFocusChanged :: State -> DomainFocusChanged -> Either AppError State
applyDomainFocusChanged state payload =
  case (changedDomainFocusMode payload, changedDomainFocusTarget payload) of
    ("one_suggestion", Just identity) -> setScope identity OneSuggestion
    ("stay_within", Just identity) -> setScope identity StayWithin
    ("prefer", Just identity) -> do
      _ <- requireDomain identity
      pure . bump $ state{stateActiveDomain = Just identity, stateDomainScope = Nothing}
    ("clear", Nothing) -> pure . bump $ state{stateDomainScope = Nothing}
    _ -> corrupt "A Domain focus event has an invalid mode or target."
 where
  setScope identity mode = do
    _ <- requireDomain identity
    pure . bump $ state{stateDomainScope = Just (DomainScope identity mode)}
  requireDomain identity =
    case Map.lookup identity (stateDomains state) of
      Just domain | domainActive domain -> Right domain
      _ -> corrupt "A Domain focus event references a missing or inactive Domain."

applyEvent :: State -> PersistedEvent -> Either AppError State
applyEvent state event = case persistedPayload event of
  RawFedV1 payload -> applyRawFed state event payload
  RawContentRevisionAppendedV1 payload -> applyRawContentRevisionAppended state event payload
  EnglishNormalizationAcceptedV1 payload -> applyEnglishNormalizationAccepted state event payload
  BrickTitleNormalizationAcceptedV1 payload -> applyBrickTitleNormalizationAccepted state event payload
  ImportProfileChangedV1 payload -> applyImportProfileChanged state (changedImportProfile payload)
  ImportInvocationRecordedV1 payload -> applyImportInvocationRecorded state event (recordedImportInvocation payload)
  SourceBindingChangedV1 payload -> applySourceBindingChanged state (changedSourceBinding payload)
  SourceObservationRecordedV1 payload -> applySourceObservationRecorded state event payload
  SourceObservationReconciledV1 payload -> applySourceObservationReconciled state event payload
  RawFeedRetractedV1 payload -> applyFeedRetraction state event payload
  RawFeedRestoredV1 payload -> applyFeedRestoration state event payload
  BrickCreatedV1 payload -> applyBrickCreated state event payload
  BrickNatureChangedV1 payload -> applyBrickNatureChanged state payload
  BrickChildCreatedV1 payload -> applyBrickChildCreated state event payload
  LazyReviewRequestedV1 payload -> applyLazyReviewRequested state event payload
  LazyReviewSettledV1 payload -> applyLazyReviewSettled state payload
  BrickStatusChangedV1 payload -> applyBrickStatusChanged state payload
  RawLinkAddedV1 payload -> applyRawLinkAdded state event payload
  RawDispositionAcceptedV1 payload -> applyRawDisposition state event payload
  RawTriageDeferredV1 payload -> applyRawTriageDeferral state payload
  RawShelfCreatedV1 payload -> applyRawShelfCreated state event payload
  RawShelfMemberAddedV1 payload -> applyRawShelfMemberAdded state event payload
  RawDuplicateRejectedV1 payload -> applyDuplicateRejection state payload
  ListEntryCreatedV1 payload -> applyListEntryCreated state event payload
  ListEntryQuantityChangedV1 payload -> applyListEntryQuantityChanged state event payload
  ListEntryStateChangedV1 payload -> applyListEntryStateChanged state payload
  ChecklistRunStartedV1 payload -> applyChecklistRunStarted state event payload
  ChecklistRunFinishedV1 payload -> applyChecklistRunFinished state payload
  TemporalConstraintsChangedV1 payload -> applyTemporalConstraintsChanged state payload
  StandingOutcomeRecordedV1 payload -> applyStandingOutcomeRecorded state event payload
  RepeatableReturnSetV1 payload -> applyRepeatableReturnSet state payload
  ScheduledIntervalSetV1 payload -> applyScheduledIntervalSet state payload
  RecurrenceScheduleSetV1 payload -> applyRecurrenceScheduleSet state payload
  RecurringOccurrenceReleasedV1 payload -> applyRecurringOccurrenceReleased state event payload
  HabitScheduleSetV1 payload -> applyHabitScheduleSet state payload
  HabitWindowOpenedV1 payload -> applyHabitWindowOpened state payload
  HabitWindowOutcomeRecordedV1 payload -> applyHabitWindowOutcomeRecorded state event payload
  NoticeDispositionChangedV1 payload -> applyNoticeDispositionChanged state payload
  OperationalDayConfigChangedV1 payload -> applyOperationalDayConfigChanged state payload
  ImportanceComparedV1 payload -> applyImportanceCompared state event payload
  ImportancePlacementMarkedV1 payload -> applyImportancePlacementMarked state event payload
  PairJudgmentRecordedV1 payload -> applyPairJudgmentRecorded state event payload
  PhaseChangedV1 payload -> applyPhaseChanged state event payload
  ImpactClassifiedV1 payload -> applyImpactClassified state event payload
  EffortClassifiedV1 payload -> applyEffortClassified state event payload
  EffortActualObservedV1 payload -> applyEffortActualObserved state event payload
  BrickFocusedV1 payload -> applyBrickFocused state payload
  BrickCompletedV1 payload -> applyBrickCompleted state payload
  ForecastSelectedV1 payload -> applyForecastSelected state payload
  ForecastFocusAcceptedV1 payload -> applyForecastFocusAccepted state payload
  WorkReactionRecordedV1 payload -> applyWorkReactionRecorded state event payload
  FocusPausedV1 payload -> applyFocusPaused state payload
  SprintStartedV1 payload -> applySprintStarted state event payload
  DependencyAddedV1 payload -> applyDependencyAdded state event payload
  DependencyResolvedV1 payload -> applyDependencyResolved state payload
  DomainFocusChangedV1 payload -> applyDomainFocusChanged state payload
  ExternalEntityRegisteredV1 payload -> applyExternalEntityRegistered state (registeredExternalEntity payload)
  ContactPointRegisteredV1 payload -> applyContactPointRegistered state (registeredContactPoint payload)
  WaitChangedV1 payload -> applyWaitChanged state payload
  WaitSuccessorDeclaredV1 payload -> applyWaitSuccessorDeclared state (declaredWaitSuccessor payload)
  DelegationChangedV1 payload -> applyDelegationChanged state (changedDelegation payload)
  ExternalEffectChangedV1 payload -> applyExternalEffectChanged state (changedExternalEffect payload)
  ExternalEffectApprovalGrantedV1 payload -> applyExternalEffectApprovalGranted state (grantedExternalEffectApproval payload)
  ExternalEffectReceiptRecordedV1 payload -> applyExternalEffectReceiptRecorded state (recordedExternalEffectReceipt payload)

applyExternalEntityRegistered :: State -> ExternalEntity -> Either AppError State
applyExternalEntityRegistered state entity = do
  when (Map.member (externalEntityId entity) (stateExternalEntities state)) $
    corrupt "An ExternalEntity UUID is repeated in canonical history."
  when (externalEntityHandle entity `Set.member` stateRetiredExternalEntityHandles state) $
    corrupt "An ExternalEntity handle is repeated in canonical history."
  when (Text.null (Text.strip (externalEntityName entity))) $
    corrupt "An ExternalEntity name cannot be empty."
  unless (externalEntityActive entity) $
    corrupt "A new ExternalEntity must be active."
  pure . bump $
    state
      { stateExternalEntities = Map.insert (externalEntityId entity) entity (stateExternalEntities state)
      , stateExternalEntityHandles = Map.insert (externalEntityHandle entity) (externalEntityId entity) (stateExternalEntityHandles state)
      , stateRetiredExternalEntityHandles = Set.insert (externalEntityHandle entity) (stateRetiredExternalEntityHandles state)
      }

applyContactPointRegistered :: State -> ContactPoint -> Either AppError State
applyContactPointRegistered state contact = do
  when (Map.member (contactPointId contact) (stateContactPoints state)) $
    corrupt "A ContactPoint UUID is repeated in canonical history."
  entity <- maybe (corrupt "A ContactPoint owner is missing.") Right (Map.lookup (contactPointOwner contact) (stateExternalEntities state))
  unless (externalEntityActive entity) $ corrupt "A ContactPoint owner must be active."
  when (Text.null (Text.strip (contactPointValue contact))) $ corrupt "A ContactPoint value cannot be empty."
  pure . bump $ state{stateContactPoints = Map.insert (contactPointId contact) contact (stateContactPoints state)}

applyWaitChanged :: State -> WaitChanged -> Either AppError State
applyWaitChanged state payload = do
  let gate = changedWaitGate payload
      observation = changedWaitObservation payload
  brick <- requireBrick state (waitAffectedBrick gate)
  unless (brickStatus brick == BrickActive) $ corrupt "A Wait can gate only active Work."
  case waitKind gate of
    HumanResponseWait entityId ->
      case Map.lookup entityId (stateExternalEntities state) of
        Just entity | externalEntityActive entity -> pure ()
        _ -> corrupt "A human-response Wait references a missing or inactive ExternalEntity."
    ExternalConditionWait condition ->
      when (Text.null (Text.strip condition)) $ corrupt "An external-condition Wait cannot be empty."
  unless (waitObservationWait observation == waitId gate) $ corrupt "A Wait observation references another Wait."
  when (Map.member (waitObservationId observation) (stateWaitObservations state)) $
    corrupt "A Wait observation UUID is repeated in canonical history."
  case Map.lookup (waitId gate) (stateWaits state) of
    Nothing -> do
      unless (waitRevision gate == 1 && waitStatus gate == WaitActive && waitDeferralCount gate == 0) $
        corrupt "A new Wait must start active at revision one."
      unless (waitObservationKind observation == WaitActivatedObservation) $
        corrupt "A new Wait requires an activation observation."
    Just previous -> do
      unless (waitRevision gate == waitRevision previous + 1) $ corrupt "A Wait revision is not contiguous."
      unless (waitAffectedBrick gate == waitAffectedBrick previous && waitKind gate == waitKind previous && waitActivatedAt gate == waitActivatedAt previous) $
        corrupt "A Wait update changed immutable identity facts."
      unless (waitStatus previous == WaitActive) $ corrupt "A terminal Wait cannot change again."
      unless (waitStatus gate `elem` [WaitActive, WaitResolved, WaitCancelled]) $ corrupt "A Wait transition is invalid."
      when (waitStatus gate == WaitActive && waitDeferralCount gate < waitDeferralCount previous) $
        corrupt "A Wait deferral count cannot decrease."
  pure . bump $
    state
      { stateWaits = Map.insert (waitId gate) gate (stateWaits state)
      , stateWaitObservations = Map.insert (waitObservationId observation) observation (stateWaitObservations state)
      }

applyWaitSuccessorDeclared :: State -> WaitSuccessor -> Either AppError State
applyWaitSuccessorDeclared state successor = do
  enabling <- requireBrick state (waitSuccessorEnablingBrick successor)
  affected <- requireBrick state (waitSuccessorAffectedBrick successor)
  unless (brickStatus enabling == BrickActive && brickStatus affected == BrickActive) $
    corrupt "A Wait successor can connect only active Work."
  when (brickId enabling == brickId affected) $
    corrupt "A Wait successor cannot use the affected Brick as its enabling Work."
  unless (waitSuccessorReviewDelaySeconds successor > 0) $
    corrupt "A Wait successor needs a positive review delay."
  when (Map.member (waitSuccessorWait successor) (stateWaits state) || Map.member (waitSuccessorWait successor) (stateWaitSuccessors state)) $
    corrupt "A Wait successor UUID is repeated in canonical history."
  when (any ((== brickId enabling) . waitSuccessorEnablingBrick) (Map.elems (stateWaitSuccessors state))) $
    corrupt "One enabling Brick cannot declare multiple Wait successors."
  unless (any matchingDependency (Map.elems (stateDependencies state))) $
    corrupt "A Wait successor requires the matching active Dependency."
  case waitSuccessorKind successor of
    HumanResponseWait entityId ->
      case Map.lookup entityId (stateExternalEntities state) of
        Just entity | externalEntityActive entity -> pure ()
        _ -> corrupt "A human-response Wait successor references a missing or inactive ExternalEntity."
    ExternalConditionWait condition ->
      when (Text.null (Text.strip condition)) (corrupt "An external-condition Wait successor cannot be empty.")
  pure . bump $ state{stateWaitSuccessors = Map.insert (waitSuccessorWait successor) successor (stateWaitSuccessors state)}
 where
  matchingDependency dependency =
    dependencyStatus dependency == DependencyActive
      && dependencyBlockedBrick dependency == waitSuccessorAffectedBrick successor
      && dependencyBlockerBrick dependency == waitSuccessorEnablingBrick successor

applyDelegationChanged :: State -> Delegation -> Either AppError State
applyDelegationChanged state delegation = do
  brick <- requireBrick state (delegationBrick delegation)
  unless (brickStatus brick == BrickActive) $ corrupt "A Delegation can reference only active Work."
  entity <- maybe (corrupt "A Delegation target is missing.") Right (Map.lookup (delegationTarget delegation) (stateExternalEntities state))
  unless (externalEntityActive entity) $ corrupt "A Delegation target must be active."
  when (Text.null (Text.strip (delegationMessage delegation))) $ corrupt "A Delegation message cannot be empty."
  when (delegationReviewDelaySeconds delegation <= 0) $ corrupt "A Delegation review delay must be positive."
  when (delegationExtraFollowUps delegation < 0) $ corrupt "A Delegation follow-up allowance cannot be negative."
  case Map.lookup (delegationId delegation) (stateDelegations state) of
    Nothing ->
      unless (delegationRevision delegation == 1 && delegationStatus delegation == DelegationProposed && isNothing (delegationInitialHandoffAt delegation)) $
        corrupt "A new Delegation must start proposed at revision one."
    Just previous -> do
      unless (delegationRevision delegation == delegationRevision previous + 1) $ corrupt "A Delegation revision is not contiguous."
      unless (delegationBrick delegation == delegationBrick previous && delegationTarget delegation == delegationTarget previous && delegationScope delegation == delegationScope previous && delegationFollowUpPolicy delegation == delegationFollowUpPolicy previous) $
        corrupt "A Delegation update changed immutable responsibility facts."
      unless (delegationTransitionAllowed (delegationStatus previous) (delegationStatus delegation)) $
        corrupt "A Delegation transition is invalid."
      when (delegationStatus delegation == DelegationActive && isNothing (delegationInitialHandoffAt delegation)) $
        corrupt "An active Delegation requires an observed handoff."
  pure . bump $ state{stateDelegations = Map.insert (delegationId delegation) delegation (stateDelegations state)}

delegationTransitionAllowed :: DelegationStatus -> DelegationStatus -> Bool
delegationTransitionAllowed from to = case from of
  DelegationProposed -> to `elem` [DelegationProposed, DelegationActive, DelegationCancelled]
  DelegationActive -> to `elem` [DelegationActive, DelegationCompleted, DelegationRefused, DelegationTakenBack, DelegationCancelled, DelegationReassigned]
  _ -> False

applyExternalEffectChanged :: State -> ExternalEffect -> Either AppError State
applyExternalEffectChanged state effect = do
  validateExternalEffectRequest state (externalEffectRequest effect)
  when (Text.null (Text.strip (externalEffectRedactedPreview effect))) $ corrupt "An ExternalEffect preview cannot be empty."
  when (Text.null (Text.strip (externalEffectOriginatingCursor effect))) $ corrupt "An ExternalEffect originating cursor cannot be empty."
  unless (externalEffectPayloadDigest effect == externalEffectRequestDigest (externalEffectRequest effect)) $
    corrupt "An ExternalEffect payload digest does not match its typed request."
  case Map.lookup (externalEffectId effect) (stateExternalEffects state) of
    Nothing ->
      unless
        ( externalEffectRevision effect == 1
            && externalEffectRecordVersion effect == 1
            && externalEffectStatus effect == EffectProposed
            && isNothing (externalEffectApprovalGrant effect)
            && isNothing (externalEffectApprovedDigest effect)
        )
        $ corrupt "A new ExternalEffect must start proposed at payload and record version one."
    Just previous -> do
      unless (externalEffectRecordVersion effect == externalEffectRecordVersion previous + 1) $
        corrupt "An ExternalEffect record version is not contiguous."
      validateEffectRevision previous effect
      unless (effectTransitionAllowed previous effect) $
        corrupt "An ExternalEffect transition is invalid."
  validateEffectApprovalCustody effect
  pure . bump $ state{stateExternalEffects = Map.insert (externalEffectId effect) effect (stateExternalEffects state)}

applyExternalEffectApprovalGranted :: State -> ExternalEffectApprovalGrant -> Either AppError State
applyExternalEffectApprovalGranted state grant = do
  when (Map.member (externalEffectApprovalGrantId grant) (stateExternalEffectApprovalGrants state)) $
    corrupt "An ExternalEffect approval-grant UUID is repeated in canonical history."
  when (null items || items /= sortOn approvedEffectId items || not (allUnique (approvedEffectId <$> items))) $
    corrupt "An ExternalEffect approval grant must contain one nonempty sorted set of effects."
  when (Text.null (Text.strip (externalEffectApprovalCursor grant))) $
    corrupt "An ExternalEffect approval grant needs its exact dataset cursor."
  approved <- traverse approve items
  pure . bump $
    state
      { stateExternalEffects = foldr (\effect -> Map.insert (externalEffectId effect) effect) (stateExternalEffects state) approved
      , stateExternalEffectApprovalGrants = Map.insert (externalEffectApprovalGrantId grant) grant (stateExternalEffectApprovalGrants state)
      }
 where
  items = externalEffectApprovalItems grant
  approve item = do
    effect <- maybe (corrupt "An ExternalEffect approval item references a missing effect.") Right (Map.lookup (approvedEffectId item) (stateExternalEffects state))
    unless (externalEffectStatus effect == EffectProposed) $
      corrupt "An ExternalEffect approval item is not proposed."
    unless (approvedEffectRevision item == externalEffectRevision effect && approvedEffectDigest item == externalEffectConsentDigest effect) $
      corrupt "An ExternalEffect approval item does not match the exact payload revision."
    pure
      effect
        { externalEffectRecordVersion = externalEffectRecordVersion effect + 1
        , externalEffectStatus = EffectApproved
        , externalEffectReviewNotBefore = Nothing
        , externalEffectApprovalGrant = Just (externalEffectApprovalGrantId grant)
        , externalEffectApprovedDigest = Just (approvedEffectDigest item)
        }

applyExternalEffectReceiptRecorded :: State -> ExternalEffectReceipt -> Either AppError State
applyExternalEffectReceiptRecorded state receipt = do
  when (Map.member (externalEffectReceiptId receipt) (stateExternalEffectReceipts state)) $
    corrupt "An ExternalEffect receipt UUID is repeated in canonical history."
  effect <- maybe (corrupt "An ExternalEffect receipt references a missing effect.") Right (Map.lookup (externalEffectReceiptEffect receipt) (stateExternalEffects state))
  unless (externalEffectStatus effect `elem` [EffectDispatching, EffectOutcomeUnknown]) $
    corrupt "A provider receipt requires a durably dispatching or outcome-unknown ExternalEffect."
  let allowedOutcomes = case externalEffectStatus effect of
        EffectDispatching -> [EffectSucceeded, EffectFailedRetryable, EffectFailedTerminal, EffectOutcomeUnknown]
        EffectOutcomeUnknown -> [EffectSucceeded, EffectFailedRetryable, EffectOutcomeUnknown]
        _ -> []
  unless (externalEffectReceiptOutcome receipt `elem` allowedOutcomes) $
    corrupt "An ExternalEffect receipt has an invalid provider outcome for its current state."
  let resolved = effect{externalEffectRecordVersion = externalEffectRecordVersion effect + 1, externalEffectStatus = externalEffectReceiptOutcome receipt}
  pure . bump $
    state
      { stateExternalEffects = Map.insert (externalEffectId effect) resolved (stateExternalEffects state)
      , stateExternalEffectReceipts = Map.insert (externalEffectReceiptId receipt) receipt (stateExternalEffectReceipts state)
      }

validateExternalEffectRequest :: State -> ExternalEffectRequest -> Either AppError ()
validateExternalEffectRequest state = \case
  DelegationDeliveryRequest delegationId _ targetId contactId _ message -> validateDelegationRequest delegationId targetId contactId message
  DelegationTakeBackNoticeRequest delegationId targetId contactId _ message -> validateDelegationRequest delegationId targetId contactId message
  SourceCleanupItemRequest custody target -> do
    validateEffectAdapterCustody custody
    invocation <- maybe (corrupt "A source-cleanup effect references a missing ImportInvocation.") Right (Map.lookup (cleanupItemImportInvocation target) (stateImportInvocations state))
    binding <- maybe (corrupt "A source-cleanup effect references a missing SourceBinding.") Right (Map.lookup (cleanupItemSourceBinding target) (stateSourceBindings state))
    unless
      ( importInvocationMode invocation == SourceMigrate
          && importInvocationComponentId invocation == effectAdapterComponentId custody
          && importInvocationContractMajor invocation == effectAdapterContractMajor custody
          && importInvocationPackPublisher invocation == effectAdapterPackPublisher custody
          && importInvocationPackName invocation == effectAdapterPackName custody
          && importInvocationPackVersion invocation == effectAdapterPackVersion custody
          && importInvocationPackManifestDigest invocation == effectAdapterPackManifestDigest custody
          && importInvocationPackArchiveDigest invocation == effectAdapterPackArchiveDigest custody
          && importInvocationSignerFingerprint invocation == effectAdapterSignerFingerprint custody
      )
      $ corrupt "A source-cleanup effect changed signed ImportInvocation custody."
    unless
      ( sourceBindingRaw binding == cleanupItemRaw target
          && sourceBindingExternalIdentity binding == Just (cleanupItemExternalIdentity target)
          && sourceBindingLocator binding == cleanupItemLocator target
          && sourceBindingContainerIdentity binding == cleanupItemContainerIdentity target
          && sourceBindingMode binding == SourceMigrate
      )
      $ corrupt "A source-cleanup effect changed its exact SourceBinding target."
  SourceCleanupContainerRequest custody target -> do
    validateEffectAdapterCustody custody
    profile <- maybe (corrupt "A source-container cleanup effect references a missing ImportProfile.") Right (Map.lookup (cleanupContainerImportProfile target) (stateImportProfiles state))
    invocation <- maybe (corrupt "A source-container cleanup effect references a missing ImportInvocation.") Right (Map.lookup (cleanupContainerImportInvocation target) (stateImportInvocations state))
    unless
      ( importProfileMode profile == SourceMigrate
          && importProfileLifecycle profile == ImportProfileRetired
          && importProfileAdapterId profile == effectAdapterComponentId custody
          && importInvocationProfileId invocation == importProfileId profile
          && importInvocationMode invocation == SourceMigrate
          && importInvocationComponentId invocation == effectAdapterComponentId custody
          && importInvocationContractMajor invocation == effectAdapterContractMajor custody
          && importInvocationPackPublisher invocation == effectAdapterPackPublisher custody
          && importInvocationPackName invocation == effectAdapterPackName custody
          && importInvocationPackVersion invocation == effectAdapterPackVersion custody
          && importInvocationPackManifestDigest invocation == effectAdapterPackManifestDigest custody
          && importInvocationPackArchiveDigest invocation == effectAdapterPackArchiveDigest custody
          && importInvocationSignerFingerprint invocation == effectAdapterSignerFingerprint custody
      )
      $ corrupt "A source-container cleanup effect changed its migration scope."
    let itemEffects =
          [ effect
          | effect <- Map.elems (stateExternalEffects state)
          , SourceCleanupItemRequest _ item <- [externalEffectRequest effect]
          , cleanupItemImportInvocation item == importInvocationId invocation
          , cleanupItemContainerIdentity item == Just (cleanupContainerExternalIdentity target)
          ]
    unless (not (null itemEffects) && all ((== EffectSucceeded) . externalEffectStatus) itemEffects) $
      corrupt "A source-container cleanup effect lacks complete successful item cleanup custody."
    when
      ( Text.null (Text.strip (cleanupContainerExternalIdentity target))
          || Text.null (Text.strip (cleanupContainerLabel target))
          || not (validDigest (cleanupContainerInspectionDigest target))
      )
      $ corrupt "A source-container cleanup target cannot be empty."
 where
  validateDelegationRequest delegationId targetId contactId message = do
    delegation <- maybe (corrupt "An ExternalEffect Delegation is missing.") Right (Map.lookup delegationId (stateDelegations state))
    unless (delegationTarget delegation == targetId) $ corrupt "An ExternalEffect target differs from its Delegation."
    when (Text.null (Text.strip message)) $ corrupt "A Delegation effect message cannot be empty."
    traverse_ (requireContact targetId) contactId
  requireContact targetId identity = do
    contact <- maybe (corrupt "An ExternalEffect ContactPoint is missing.") Right (Map.lookup identity (stateContactPoints state))
    unless (contactPointOwner contact == targetId && contactPointActive contact) $
      corrupt "An ExternalEffect ContactPoint is not an active binding of its target."
  validDigest value = Text.length value == 64 && Text.all (\character -> isDigit character || character `elem` ['a' .. 'f']) value

validateEffectAdapterCustody :: EffectAdapterCustody -> Either AppError ()
validateEffectAdapterCustody custody = do
  when (effectAdapterContractMajor custody < 1) $ corrupt "An effect adapter contract major must be positive."
  when (any (Text.null . Text.strip) requiredText) $ corrupt "An effect adapter custody field cannot be empty."
  traverse_ validateDigestField digests
 where
  requiredText =
    [ effectAdapterComponentId custody
    , effectAdapterProviderAccount custody
    , effectAdapterCredentialBinding custody
    , effectAdapterPackPublisher custody
    , effectAdapterPackName custody
    , effectAdapterPackVersion custody
    ]
  digests =
    [ effectAdapterPackManifestDigest custody
    , effectAdapterPackArchiveDigest custody
    , effectAdapterSignerFingerprint custody
    ]
  validateDigestField value = unless (validSha256 value) $ corrupt "An effect adapter custody digest is invalid."

validateEffectRevision :: ExternalEffect -> ExternalEffect -> Either AppError ()
validateEffectRevision previous current
  | externalEffectRevision current == externalEffectRevision previous =
      unless (immutableRevision current == immutableRevision previous) $
        corrupt "An ExternalEffect state transition changed immutable revision facts."
  | externalEffectRevision current == externalEffectRevision previous + 1 = do
      unless (externalEffectStatus current == EffectProposed) $ corrupt "A new ExternalEffect payload revision must return to proposed."
      unless (externalEffectStatus previous `elem` [EffectProposed, EffectFailedRetryable, EffectFailedTerminal, EffectOutcomeUnknown]) $
        corrupt "This ExternalEffect state cannot create a corrected payload revision."
      unless (isNothing (externalEffectApprovalGrant current) && isNothing (externalEffectApprovedDigest current)) $
        corrupt "A new ExternalEffect payload revision cannot inherit approval."
  | otherwise = corrupt "An ExternalEffect payload revision is not contiguous."
 where
  immutableRevision effect =
    ( externalEffectRequest effect
    , externalEffectRedactedPreview effect
    , externalEffectPayloadDigest effect
    , externalEffectOriginatingCommand effect
    , externalEffectOriginatingCursor effect
    , externalEffectIdempotencyKey effect
    )

effectTransitionAllowed :: ExternalEffect -> ExternalEffect -> Bool
effectTransitionAllowed previous current
  | externalEffectRevision current == externalEffectRevision previous + 1 = externalEffectStatus current == EffectProposed
  | otherwise = case externalEffectStatus previous of
      EffectProposed -> externalEffectStatus current `elem` [EffectProposed, EffectRejected, EffectWithdrawn]
      EffectApproved -> externalEffectStatus current `elem` [EffectDispatching, EffectRejected, EffectWithdrawn]
      EffectFailedRetryable -> externalEffectStatus current `elem` [EffectApproved, EffectWithdrawn]
      EffectFailedTerminal -> externalEffectStatus current == EffectWithdrawn
      EffectOutcomeUnknown -> externalEffectStatus current == EffectWithdrawn
      _ -> False

validateEffectApprovalCustody :: ExternalEffect -> Either AppError ()
validateEffectApprovalCustody effect
  | externalEffectStatus effect `elem` [EffectApproved, EffectDispatching, EffectSucceeded, EffectFailedRetryable, EffectFailedTerminal, EffectOutcomeUnknown] =
      unless
        ( isJust (externalEffectApprovalGrant effect)
            && externalEffectApprovedDigest effect == Just (externalEffectConsentDigest effect)
        )
        $ corrupt "An approved or dispatched ExternalEffect requires its exact approval grant and digest."
  | otherwise =
      unless (isNothing (externalEffectApprovalGrant effect) && isNothing (externalEffectApprovedDigest effect)) $
        corrupt "A proposed, rejected, or withdrawn ExternalEffect cannot retain approval custody."

applyDependencyAdded :: State -> PersistedEvent -> DependencyAdded -> Either AppError State
applyDependencyAdded state event payload = do
  blocked <- requireBrick state (addedDependencyBlockedBrick payload)
  blocker <- requireBrick state (addedDependencyBlockerBrick payload)
  unless (brickStatus blocked == BrickActive && brickStatus blocker == BrickActive) $
    corrupt "A Dependency can connect only active Bricks."
  when (brickId blocked == brickId blocker) $ corrupt "A Brick cannot depend on itself."
  when (Map.member (addedDependencyId payload) (stateDependencies state)) $
    corrupt "A Dependency UUID is repeated in canonical history."
  when (any sameActive (Map.elems (stateDependencies state))) $
    corrupt "The same active Dependency edge is repeated."
  when (reaches state (brickId blocker) (brickId blocked)) $
    corrupt "A Dependency would create a cycle."
  let dependency =
        Dependency
          (addedDependencyId payload)
          (brickId blocked)
          (brickId blocker)
          DependencyActive
          (addedDependencySource payload)
          (persistedRecordedAt event)
  pure . bump $ state{stateDependencies = Map.insert (dependencyId dependency) dependency (stateDependencies state)}
 where
  sameActive dependency =
    dependencyStatus dependency == DependencyActive
      && dependencyBlockedBrick dependency == addedDependencyBlockedBrick payload
      && dependencyBlockerBrick dependency == addedDependencyBlockerBrick payload

applyDependencyResolved :: State -> DependencyResolution -> Either AppError State
applyDependencyResolved state payload = do
  dependency <-
    maybe (corrupt "A resolved Dependency is missing.") Right (Map.lookup (resolvedDependencyId payload) (stateDependencies state))
  unless (dependencyStatus dependency == DependencyActive) $ corrupt "Only an active Dependency can be resolved."
  pure . bump $
    state
      { stateDependencies =
          Map.insert
            (dependencyId dependency)
            dependency{dependencyStatus = DependencyResolved}
            (stateDependencies state)
      }

reaches :: State -> UUIDv7 -> UUIDv7 -> Bool
reaches state start target = go Set.empty start
 where
  go visited current
    | current == target = True
    | current `Set.member` visited = False
    | otherwise =
        any
          (go (Set.insert current visited) . dependencyBlockerBrick)
          [ dependency
          | dependency <- Map.elems (stateDependencies state)
          , dependencyStatus dependency == DependencyActive
          , dependencyBlockedBrick dependency == current
          ]
applyForecastSelected :: State -> ForecastSelected -> Either AppError State
applyForecastSelected state payload = do
  let evidence = selectedForecastEvidence payload
      seed = forecastSelectionSeed evidence
  unless (ByteString.length seed == 32) $ corrupt "A forecast selection seed must contain exactly 32 bytes."
  case stateRandomSeed state of
    Nothing -> pure ()
    Just existing -> unless (existing == seed) $ corrupt "A forecast selection changed the dataset random seed."
  when (Map.member (forecastSelectionId evidence) (stateForecastSelections state)) $
    corrupt "A forecast selection UUID is repeated in canonical history."
  unless (forecastSelectionOriginalSubject evidence `elem` fmap fst (forecastSelectionAdmitted evidence)) $
    corrupt "The selected original subject is absent from the recorded admitted set."
  nextCursors <- foldM advanceCursor (stateRandomCursors state) (forecastSelectionDraws evidence)
  Right . bump $
    state
      { stateRandomSeed = Just seed
      , stateRandomCursors = nextCursors
      , stateForecastSelections = Map.insert (forecastSelectionId evidence) evidence (stateForecastSelections state)
      , stateDomainScope =
          case stateDomainScope state of
            Just DomainScope{domainScopeMode = OneSuggestion} -> Nothing
            existing -> existing
      }
 where
  advanceCursor cursors draw = do
    let purpose = forecastDrawPurpose draw
        expected = Map.findWithDefault 0 purpose cursors
    unless (forecastDrawStartingCursor draw == expected) $
      corrupt "A forecast draw starts at the wrong purpose cursor."
    unless (forecastDrawEndingCursor draw >= expected) $
      corrupt "A forecast draw moves its purpose cursor backwards."
    unless (forecastDrawTotal draw > 0 && forecastDrawSampledInteger draw >= 0 && forecastDrawSampledInteger draw < forecastDrawTotal draw) $
      corrupt "A forecast draw records an invalid sampled interval."
    pure (Map.insert purpose (forecastDrawEndingCursor draw) cursors)

applyForecastFocusAccepted :: State -> ForecastFocusAccepted -> Either AppError State
applyForecastFocusAccepted state payload = do
  evidence <-
    maybe
      (corrupt "A Focus acceptance references a missing forecast selection.")
      Right
      (Map.lookup (acceptedForecastSelection payload) (stateForecastSelections state))
  brick <- requireBrick state (acceptedForecastBrick payload)
  unless (brickStatus brick == BrickActive) $ corrupt "Only active Work can become current focus."
  unless (forecastSelectionEndpointSubject evidence == Just (brickId brick)) $
    corrupt "A Focus acceptance does not match the recorded forecast endpoint."
  let recordedDomain = forecastSelectionDomainPath evidence >>= lastMaybe
  unless (acceptedForecastDomain payload == recordedDomain) $
    corrupt "A Focus acceptance changed the recorded effective Domain."
  let bricks =
        Map.map
          ( \current ->
              if brickId current == brickId brick
                then current{brickWorkState = Wip}
                else current
          )
          (stateBricks state)
  Right . bump $
    state
      { stateBricks = bricks
      , stateCurrentFocus = Just (brickId brick)
      , stateActiveDomain = acceptedForecastDomain payload
      }
 where
  lastMaybe [] = Nothing
  lastMaybe values = Just (last values)

applyScheduledIntervalSet :: State -> ScheduledIntervalSet -> Either AppError State
applyScheduledIntervalSet state payload = do
  owner <- requireBrick state (intervalSetOwner payload)
  unless (brickStatus owner == BrickActive && brickNature owner == ScheduledCommitment) $
    corrupt "An exact commitment interval belongs only to an active scheduled-commitment Brick."
  let previousRevision = maybe 0 scheduledIntervalRevision (Map.lookup (brickId owner) (stateScheduledIntervals state))
  unless (intervalSetRevision payload == previousRevision + 1) $
    corrupt "A scheduled-commitment interval revision is not contiguous."
  traverse_ validateInstant [intervalSetStartsAt payload, intervalSetEndsAt payload]
  unless (zonedInstantUtc (intervalSetEndsAt payload) > zonedInstantUtc (intervalSetStartsAt payload)) $
    corrupt "A scheduled commitment must end after it starts."
  let interval = ScheduledInterval (brickId owner) (intervalSetStartsAt payload) (intervalSetEndsAt payload) (intervalSetRevision payload)
  Right . bump $ state{stateScheduledIntervals = Map.insert (brickId owner) interval (stateScheduledIntervals state), stateLastRedo = Nothing}
 where
  validateInstant instant =
    when (Text.null (Text.strip (zonedInstantZone instant))) (corrupt "A scheduled endpoint needs a named IANA display zone.")

applyRecurrenceScheduleSet :: State -> RecurrenceScheduleSet -> Either AppError State
applyRecurrenceScheduleSet state payload = do
  let schedule = setRecurrenceSchedule payload
  owner <- requireBrick state (recurrenceOwner schedule)
  unless (brickStatus owner == BrickActive && brickNature owner == RecurringObligation) $
    corrupt "A recurrence schedule belongs only to an active recurring-obligation series."
  either (const (corrupt "A recurrence schedule has an invalid calendar rule.")) pure (validateCalendarRule (recurrenceRule schedule))
  unless (recurrenceOccurrenceNature schedule `elem` [AtomicTask, ScheduledCommitment]) $
    corrupt "A recurring occurrence must be an atomic task or scheduled commitment."
  case (recurrenceOccurrenceNature schedule, recurrenceDurationSeconds schedule) of
    (AtomicTask, Nothing) -> pure ()
    (ScheduledCommitment, Just duration) | duration > 0 -> pure ()
    _ -> corrupt "Only a scheduled occurrence has one positive duration."
  when (Text.null (Text.strip (recurrenceZone schedule))) $ corrupt "A recurrence schedule needs one named IANA zone."
  let previousRevision = maybe 0 recurrenceRevision (Map.lookup (brickId owner) (stateRecurrenceSchedules state))
  unless (recurrenceRevision schedule == previousRevision + 1) $
    corrupt "A recurrence schedule revision is not contiguous."
  Right . bump $ state{stateRecurrenceSchedules = Map.insert (brickId owner) schedule (stateRecurrenceSchedules state), stateLastRedo = Nothing}

applyRecurringOccurrenceReleased :: State -> PersistedEvent -> RecurringOccurrenceReleased -> Either AppError State
applyRecurringOccurrenceReleased state event payload = do
  let occurrence = releasedOccurrence payload
      ownerId = recurringOccurrenceOwner occurrence
      brickIdentity = recurringOccurrenceBrick occurrence
  owner <- requireBrick state ownerId
  unless (brickStatus owner == BrickActive && brickNature owner == RecurringObligation) $
    corrupt "A recurring occurrence requires one active recurring-obligation owner."
  schedule <- maybe (corrupt "A recurring occurrence references a missing schedule.") Right (Map.lookup ownerId (stateRecurrenceSchedules state))
  unless (recurringOccurrenceScheduleRevision occurrence == recurrenceRevision schedule) $
    corrupt "A recurring occurrence references the wrong schedule revision."
  unless (releasedOccurrenceNature payload == recurrenceOccurrenceNature schedule) $
    corrupt "A recurring occurrence changed its configured Nature."
  unless (recurringOccurrenceId occurrence == brickIdentity) $
    corrupt "A recurring occurrence and its finite Brick must share one identity."
  when (Map.member brickIdentity (stateRecurringOccurrences state) || Map.member brickIdentity (stateBricks state)) $
    corrupt "A recurring occurrence identity is repeated."
  when (Map.member (releasedOccurrenceHandle payload) (stateBrickHandles state) || releasedOccurrenceHandle payload `Set.member` stateRetiredBrickHandles state) $
    corrupt "A recurring occurrence handle is not unique."
  when (any (sameAnchor occurrence) (Map.elems (stateRecurringOccurrences state))) $
    corrupt "A recurring series released the same nominal anchor twice."
  unless (releasedOccurrenceTitle payload == brickTitle owner && releasedOccurrenceDomains payload == brickDomains owner) $
    corrupt "A recurring occurrence did not retain its series title and direct Domains."
  let interval = releasedOccurrenceInterval payload
  case (releasedOccurrenceNature payload, recurrenceDurationSeconds schedule, interval) of
    (AtomicTask, Nothing, Nothing) -> pure ()
    (ScheduledCommitment, Just _, Just exactInterval)
      | scheduledIntervalOwner exactInterval == brickIdentity
      , scheduledIntervalRevision exactInterval == 1
      , zonedInstantUtc (scheduledEndsAt exactInterval) > zonedInstantUtc (scheduledStartsAt exactInterval) ->
          pure ()
    _ -> corrupt "A released occurrence has invalid exact-interval data."
  unless (temporalRevision (releasedOccurrenceTemporal payload) == 1) $
    corrupt "A released occurrence must begin with temporal revision one."
  let brick =
        Brick
          brickIdentity
          (releasedOccurrenceHandle payload)
          (releasedOccurrenceTitle payload)
          (releasedOccurrenceNature payload)
          "factory@1"
          "system_recurrence"
          Nothing
          (Just ownerId)
          (releasedOccurrenceDomains payload)
          (releasedOccurrencePosition payload)
          (DeterministicPosition "recurring occurrence")
          BrickActive
          Idle
          (persistedRecordedAt event)
          (persistedActor event)
          (persistedCommandId event)
      intervals = maybe (stateScheduledIntervals state) (\value -> Map.insert brickIdentity value (stateScheduledIntervals state)) interval
  Right . bump $
    state
      { stateBricks = Map.insert brickIdentity brick (stateBricks state)
      , stateBrickHandles = Map.insert (brickHandle brick) brickIdentity (stateBrickHandles state)
      , stateRetiredBrickHandles = Set.insert (brickHandle brick) (stateRetiredBrickHandles state)
      , stateRecurringOccurrences = Map.insert brickIdentity occurrence (stateRecurringOccurrences state)
      , stateTemporalConstraints = Map.insert brickIdentity (releasedOccurrenceTemporal payload) (stateTemporalConstraints state)
      , stateScheduledIntervals = intervals
      , stateLastRedo = Nothing
      }
 where
  sameAnchor candidate existing =
    recurringOccurrenceOwner existing == recurringOccurrenceOwner candidate
      && zonedInstantUtc (recurringOccurrenceNominalAnchor existing) == zonedInstantUtc (recurringOccurrenceNominalAnchor candidate)

applyHabitScheduleSet :: State -> HabitScheduleSet -> Either AppError State
applyHabitScheduleSet state payload = do
  let schedule = setHabitSchedule payload
      ownerId = habitScheduleOwner schedule
  owner <- requireBrick state ownerId
  unless (brickStatus owner == BrickActive && brickNature owner == Habit) $
    corrupt "A habit schedule belongs only to an active habit."
  when (Text.null (Text.strip (habitScheduleZone schedule))) $ corrupt "A habit schedule needs one named IANA zone."
  case schedule of
    FixedSlotHabit{habitFixedRule, habitSlotDurationSeconds} -> do
      either (const (corrupt "A fixed-slot habit has an invalid calendar rule.")) pure (validateCalendarRule habitFixedRule)
      unless (habitSlotDurationSeconds > 0) $ corrupt "A fixed-slot habit needs a positive opportunity duration."
    QuotaWindowHabit{habitQuotaTarget, habitQuotaSpan} ->
      unless (habitQuotaTarget > 0 && habitQuotaSpan > 0) $ corrupt "A quota habit needs positive target and span values."
  let previousRevision = maybe 0 habitScheduleRevision (Map.lookup ownerId (stateHabitSchedules state))
  unless (habitScheduleRevision schedule == previousRevision + 1) $
    corrupt "A habit schedule revision is not contiguous."
  Right . bump $ state{stateHabitSchedules = Map.insert ownerId schedule (stateHabitSchedules state), stateLastRedo = Nothing}

applyHabitWindowOpened :: State -> HabitWindowOpened -> Either AppError State
applyHabitWindowOpened state payload = do
  let window = openedHabitWindow payload
      ownerId = habitWindowOwner window
  owner <- requireBrick state ownerId
  unless (brickStatus owner == BrickActive && brickNature owner == Habit) $ corrupt "A habit window requires one active habit owner."
  schedule <- maybe (corrupt "A habit window references a missing schedule.") Right (Map.lookup ownerId (stateHabitSchedules state))
  unless (habitWindowScheduleRevision window == habitScheduleRevision schedule) $ corrupt "A habit window references the wrong schedule revision."
  unless (habitWindowTarget window > 0 && zonedInstantUtc (habitWindowClosesAt window) > zonedInstantUtc (habitWindowOpensAt window)) $
    corrupt "A habit window needs a positive target and an ordered exact interval."
  when (habitWindowSettled window || Map.member (habitWindowId window) (stateHabitWindows state)) $ corrupt "A newly opened habit window is already settled or repeated."
  when (any (sameWindow window) (Map.elems (stateHabitWindows state))) $ corrupt "The same habit window was opened twice."
  Right . bump $ state{stateHabitWindows = Map.insert (habitWindowId window) window (stateHabitWindows state), stateLastRedo = Nothing}
 where
  sameWindow candidate existing =
    habitWindowOwner existing == habitWindowOwner candidate
      && zonedInstantUtc (habitWindowOpensAt existing) == zonedInstantUtc (habitWindowOpensAt candidate)

applyHabitWindowOutcomeRecorded :: State -> PersistedEvent -> HabitWindowOutcomeRecorded -> Either AppError State
applyHabitWindowOutcomeRecorded state event payload = do
  owner <- requireBrick state (recordedHabitWindowOwner payload)
  unless (brickStatus owner == BrickActive && brickNature owner == Habit) $ corrupt "A habit outcome requires one active habit owner."
  window <- maybe (corrupt "A habit outcome references a missing window.") Right (Map.lookup (recordedHabitWindowId payload) (stateHabitWindows state))
  unless (habitWindowOwner window == brickId owner && not (habitWindowSettled window)) $ corrupt "A habit outcome references a settled or different owner's window."
  unless (recordedHabitWindowOutcome payload `elem` [StandingDone, StandingUnfulfilled, StandingBlocked, StandingPaused, StandingInapplicable]) $
    corrupt "A habit window has an invalid outcome."
  unless (recordedHabitWindowOutcomeId payload == persistedEventId event) $ corrupt "A habit outcome identity must equal its event identity."
  when (Map.member (persistedEventId event) (stateHabitOutcomes state)) $ corrupt "A habit outcome UUID is repeated."
  let prior = [outcome | outcome <- Map.elems (stateHabitOutcomes state), habitOutcomeWindow outcome == habitWindowId window]
      settles = recordedHabitWindowOutcome payload `elem` [StandingBlocked, StandingPaused, StandingInapplicable] || length prior + 1 >= habitWindowTarget window
      outcome = HabitOutcome (persistedEventId event) (habitWindowId window) (brickId owner) (recordedHabitWindowOutcome payload) (persistedRecordedAt event)
      standing = StandingOutcome (persistedEventId event) (brickId owner) (recordedHabitWindowOutcome payload) (persistedRecordedAt event)
      windows = Map.adjust (\current -> current{habitWindowSettled = settles}) (habitWindowId window) (stateHabitWindows state)
      bricks = Map.adjust (\brick -> brick{brickWorkState = Idle}) (brickId owner) (stateBricks state)
      focus = if stateCurrentFocus state == Just (brickId owner) then Nothing else stateCurrentFocus state
  Right . bump $
    state
      { stateHabitWindows = windows
      , stateHabitOutcomes = Map.insert (habitOutcomeId outcome) outcome (stateHabitOutcomes state)
      , stateStandingOutcomes = Map.insert (standingOutcomeId standing) standing (stateStandingOutcomes state)
      , stateBricks = bricks
      , stateCurrentFocus = focus
      , stateLastRedo = Nothing
      }

applyNoticeDispositionChanged :: State -> NoticeDispositionChanged -> Either AppError State
applyNoticeDispositionChanged state payload = do
  _ <- requireBrick state (noticeSubject (changedNoticeIdentity payload))
  case changedNoticeDisposition payload of
    NoticeSnoozed instant | Text.null (Text.strip (zonedInstantZone instant)) -> corrupt "A snoozed notice needs a named IANA zone."
    _ -> pure ()
  Right . bump $ state{stateNoticeDispositions = Map.insert (changedNoticeIdentity payload) (changedNoticeDisposition payload) (stateNoticeDispositions state), stateLastRedo = Nothing}

applyOperationalDayConfigChanged :: State -> OperationalDayConfigChanged -> Either AppError State
applyOperationalDayConfigChanged state payload =
  let config = changedOperationalDayConfig payload
   in if Text.null (Text.strip (operationalZone config))
        then corrupt "Operational days need one named IANA zone."
        else Right . bump $ state{stateOperationalDayConfig = config, stateLastRedo = Nothing}

applyWorkReactionRecorded :: State -> PersistedEvent -> WorkReactionRecorded -> Either AppError State
applyWorkReactionRecorded state event payload = do
  brick <- requireBrick state (recordedWorkReactionBrick payload)
  unless (brickStatus brick == BrickActive) $ corrupt "Only active Work can record a served reaction."
  case recordedWorkReactionSelection payload of
    Nothing -> pure ()
    Just selectionId -> do
      evidence <-
        maybe
          (corrupt "A served reaction references a missing forecast selection.")
          Right
          (Map.lookup selectionId (stateForecastSelections state))
      unless (forecastSelectionEndpointSubject evidence == Just (brickId brick)) $
        corrupt "A served reaction does not match its forecast endpoint."
  let deferral =
        WorkDeferral
          (persistedEventId event)
          (brickId brick)
          (recordedWorkReactionSelection payload)
          (recordedWorkReactionSymptom payload)
          (recordedWorkReaction payload)
          (persistedRecordedAt event)
          (recordedWorkReactionCooldownUntil payload)
      focus =
        if reactionClosesFocus (recordedWorkReaction payload) && stateCurrentFocus state == Just (brickId brick)
          then Nothing
          else stateCurrentFocus state
  Right . bump $
    state
      { stateWorkDeferrals = Map.insert (workDeferralId deferral) deferral (stateWorkDeferrals state)
      , stateCurrentFocus = focus
      , stateActiveSprint =
          case stateActiveSprint state of
            Just sprint | activeSprintBrick sprint == brickId brick -> Nothing
            other -> other
      , stateLastRedo = Nothing
      }

applyTemporalConstraintsChanged :: State -> TemporalConstraintsChanged -> Either AppError State
applyTemporalConstraintsChanged state payload = do
  _ <- requireBrick state (changedTemporalBrick payload)
  let previousRevision = maybe 0 temporalRevision (Map.lookup (changedTemporalBrick payload) (stateTemporalConstraints state))
  unless (changedTemporalRevision payload == previousRevision + 1) $
    corrupt "A temporal-constraint revision is not contiguous."
  traverse_ validateZonedInstant (changedTemporalNotBefore payload)
  traverse_ validateZonedInstant (changedTemporalBestBefore payload)
  traverse_ validateZonedInstant (changedTemporalDeadline payload)
  let constraints =
        TemporalConstraints
          (changedTemporalNotBefore payload)
          (changedTemporalBestBefore payload)
          (changedTemporalDeadline payload)
          (changedTemporalRevision payload)
  Right . bump $ state{stateTemporalConstraints = Map.insert (changedTemporalBrick payload) constraints (stateTemporalConstraints state), stateLastRedo = Nothing}
 where
  validateZonedInstant instant =
    when (Text.null (Text.strip (zonedInstantZone instant))) (corrupt "A temporal instant needs a named IANA display zone.")

applyStandingOutcomeRecorded :: State -> PersistedEvent -> StandingOutcomeRecorded -> Either AppError State
applyStandingOutcomeRecorded state event payload = do
  owner <- requireBrick state (recordedStandingOwner payload)
  unless (brickStatus owner == BrickActive) $ corrupt "Only active standing Work can record an outcome."
  unless (validStandingOutcome (brickNature owner) (recordedStandingOutcome payload)) $
    corrupt "This outcome is not valid for the standing Brick Nature."
  when (Map.member (persistedEventId event) (stateStandingOutcomes state)) $
    corrupt "A standing outcome UUID is repeated in canonical history."
  let outcome = StandingOutcome (persistedEventId event) (brickId owner) (recordedStandingOutcome payload) (persistedRecordedAt event)
      resultingStatus = case (brickNature owner, recordedStandingOutcome payload) of
        (ScheduledCommitment, StandingAttended) -> BrickDone
        (ScheduledCommitment, StandingMissed) -> BrickMissed
        (ScheduledCommitment, StandingCancelled) -> BrickCancelled
        _ -> BrickActive
      bricks = Map.adjust (\brick -> brick{brickWorkState = Idle, brickStatus = resultingStatus}) (brickId owner) (stateBricks state)
      focus = if stateCurrentFocus state == Just (brickId owner) then Nothing else stateCurrentFocus state
  Right . bump $
    state
      { stateBricks = bricks
      , stateCurrentFocus = focus
      , stateActiveSprint = case stateActiveSprint state of
          Just sprint | activeSprintBrick sprint == brickId owner -> Nothing
          current -> current
      , stateStandingOutcomes = Map.insert (standingOutcomeId outcome) outcome (stateStandingOutcomes state)
      , stateLastRedo = Nothing
      }
 where
  validStandingOutcome Repeatable StandingDone = True
  validStandingOutcome Habit outcome = outcome `elem` [StandingDone, StandingUnfulfilled, StandingBlocked, StandingPaused, StandingInapplicable]
  validStandingOutcome ScheduledCommitment outcome = outcome `elem` [StandingAttended, StandingMissed, StandingCancelled]
  validStandingOutcome _ _ = False

applyRepeatableReturnSet :: State -> RepeatableReturnSet -> Either AppError State
applyRepeatableReturnSet state payload = do
  owner <- requireBrick state (repeatableReturnOwner payload)
  unless (brickStatus owner == BrickActive && brickNature owner == Repeatable) $
    corrupt "A return policy can be set only on an active repeatable Brick."
  (nextSeed, nextCursors) <- validatePolicy
  let schedule =
        ReturnSchedule
          (brickId owner)
          (repeatableReturnPolicy payload)
          (repeatableReturnChosenOffset payload)
          (repeatableReturnNotBefore payload)
          (repeatableReturnResolution payload)
  Right . bump $
    state
      { stateReturnSchedules = Map.insert (brickId owner) schedule (stateReturnSchedules state)
      , stateRandomSeed = nextSeed
      , stateRandomCursors = nextCursors
      , stateLastRedo = Nothing
      }
 where
  validatePolicy = case repeatableReturnPolicy payload of
    ManualOnlyReturn -> do
      unless
        ( isNothing (repeatableReturnChosenOffset payload)
            && isNothing (repeatableReturnNotBefore payload)
            && isNothing (repeatableReturnResolution payload)
            && isNothing (repeatableReturnSeed payload)
            && isNothing (repeatableReturnDraw payload)
        )
        $ corrupt "A manual-only return policy cannot contain a scheduled return."
      pure (stateRandomSeed state, stateRandomCursors state)
    AfterCompletionReturn center _ variation zone -> do
      unless (center > 0 && variation >= 0 && variation <= center && not (Text.null (Text.strip zone))) $
        corrupt "A completion-relative return policy is invalid."
      chosen <- maybe (corrupt "A completion-relative return is missing its chosen offset.") Right (repeatableReturnChosenOffset payload)
      instant <- maybe (corrupt "A completion-relative return is missing its absolute instant.") Right (repeatableReturnNotBefore payload)
      resolution <- maybe (corrupt "A completion-relative return is missing its local-time resolution.") Right (repeatableReturnResolution payload)
      seed <- maybe (corrupt "A completion-relative return is missing its random seed.") Right (repeatableReturnSeed payload)
      draw <- maybe (corrupt "A completion-relative return is missing its recorded draw.") Right (repeatableReturnDraw payload)
      unless (chosen >= center - variation && chosen <= center + variation) $
        corrupt "A return offset falls outside its accepted range."
      unless (zonedInstantZone instant == zone) $
        corrupt "A return instant changed the policy IANA zone."
      unless (resolution `elem` ["unique", "gap_shifted_forward", "fold_earlier"]) $
        corrupt "A return instant has an unknown local-time resolution."
      unless (ByteString.length seed == 32) $ corrupt "A return draw seed must contain exactly 32 bytes."
      case stateRandomSeed state of
        Just existing -> unless (existing == seed) $ corrupt "A return draw changed the dataset random seed."
        Nothing -> pure ()
      unless (forecastDrawPurpose draw == "repeatable_return_jitter") $
        corrupt "A return draw uses the wrong purpose stream."
      let expectedCursor = Map.findWithDefault 0 "repeatable_return_jitter" (stateRandomCursors state)
      unless (forecastDrawStartingCursor draw == expectedCursor && forecastDrawEndingCursor draw >= expectedCursor) $
        corrupt "A return draw uses an invalid purpose cursor."
      unless (forecastDrawTotal draw > 0 && forecastDrawSampledInteger draw >= 0 && forecastDrawSampledInteger draw < forecastDrawTotal draw) $
        corrupt "A return draw records an invalid sampled interval."
      unless (forecastDrawChosenIdentity draw == Text.pack (show chosen)) $
        corrupt "A return draw does not match its chosen offset."
      pure
        ( Just seed
        , Map.insert "repeatable_return_jitter" (forecastDrawEndingCursor draw) (stateRandomCursors state)
        )

applyChecklistRunStarted :: State -> PersistedEvent -> ChecklistRunStarted -> Either AppError State
applyChecklistRunStarted state event payload = do
  owner <- requireBrick state (startedChecklistOwner payload)
  unless (brickStatus owner == BrickActive && brickNature owner `elem` [LivingChecklist, FiniteChecklist]) $
    corrupt "Only an active checklist can start a checklist run."
  unless (stateCurrentFocus state == Just (brickId owner)) $
    corrupt "A checklist run can start only after its owner accepts Focus."
  when (Map.member (brickId owner) (stateChecklistRuns state)) $
    corrupt "A checklist can have at most one active run."
  when (any ((== startedChecklistRunId payload) . checklistRunId) (Map.elems (stateChecklistRuns state))) $
    corrupt "A checklist run UUID is repeated in canonical history."
  let run = ChecklistRun (startedChecklistRunId payload) (brickId owner) (persistedRecordedAt event) 0
  Right . bump $ state{stateChecklistRuns = Map.insert (brickId owner) run (stateChecklistRuns state)}

applyListEntryStateChanged :: State -> ListEntryStateChanged -> Either AppError State
applyListEntryStateChanged state payload = do
  entry <- maybe (corrupt "A state event references a missing ListEntry.") Right (Map.lookup (stateChangedListEntryId payload) (stateListEntries state))
  run <- maybe (corrupt "A ListEntry can change state only inside its active checklist run.") Right (Map.lookup (listEntryOwner entry) (stateChecklistRuns state))
  unless (checklistRunId run == stateChangedChecklistRunId payload) $
    corrupt "A ListEntry state event references a stale checklist run."
  unless (listEntryState entry == previousListEntryState payload) $
    corrupt "A ListEntry state event cites stale state."
  unless (allowedEntryTransition (previousListEntryState payload) (currentListEntryState payload)) $
    corrupt "A ListEntry state transition is invalid."
  let updatedEntry = entry{listEntryState = currentListEntryState payload}
      updatedRun = run{checklistRunMutationCount = checklistRunMutationCount run + 1}
  Right . bump $
    state
      { stateListEntries = Map.insert (listEntryId entry) updatedEntry (stateListEntries state)
      , stateChecklistRuns = Map.insert (listEntryOwner entry) updatedRun (stateChecklistRuns state)
      , stateLastRedo = Nothing
      }
 where
  allowedEntryTransition EntryOpen EntryResolved = True
  allowedEntryTransition EntryOpen EntryCancelled = True
  allowedEntryTransition EntryResolved EntryOpen = True
  allowedEntryTransition EntryCancelled EntryOpen = True
  allowedEntryTransition _ _ = False

applyChecklistRunFinished :: State -> ChecklistRunFinished -> Either AppError State
applyChecklistRunFinished state payload = do
  owner <- requireBrick state (finishedChecklistOwner payload)
  run <- maybe (corrupt "A finished checklist run is missing.") Right (Map.lookup (brickId owner) (stateChecklistRuns state))
  unless (checklistRunId run == finishedChecklistRunId payload) $
    corrupt "A checklist finish event references a stale run."
  unless (checklistRunMutationCount run > 0) $
    corrupt "A checklist run cannot finish without a recorded entry mutation."
  let bricks = Map.adjust (\brick -> brick{brickWorkState = Idle}) (brickId owner) (stateBricks state)
      focus = if stateCurrentFocus state == Just (brickId owner) then Nothing else stateCurrentFocus state
  Right . bump $
    state
      { stateBricks = bricks
      , stateCurrentFocus = focus
      , stateChecklistRuns = Map.delete (brickId owner) (stateChecklistRuns state)
      , stateLastRedo = Nothing
      }

applyLazyReviewSettled :: State -> LazyReviewSettled -> Either AppError State
applyLazyReviewSettled state payload = do
  unless (Map.member (settledReviewId payload) (stateLazyReviews state)) $
    corrupt "A settled lazy review is missing or already settled."
  when (Text.null (Text.strip (settledReviewOutcome payload))) $
    corrupt "A lazy-review outcome cannot be empty."
  Right . bump $
    state
      { stateLazyReviews = Map.delete (settledReviewId payload) (stateLazyReviews state)
      , stateLastRedo = Nothing
      }

applyBrickStatusChanged :: State -> BrickStatusChanged -> Either AppError State
applyBrickStatusChanged state payload = do
  brick <- requireBrick state (statusChangedBrick payload)
  unless (brickStatus brick == statusChangedFrom payload) $
    corrupt "A lifecycle event cites stale prior Brick status."
  unless (allowed (statusChangedFrom payload) (statusChangedTo payload)) $
    corrupt "A lifecycle event contains an invalid Brick status transition."
  when (Text.null (Text.strip (statusChangedReason payload))) $
    corrupt "A lifecycle transition reason cannot be empty."
  let target = statusChangedTo payload
      changed =
        brick
          { brickStatus = target
          , brickWorkState = if target == BrickActive then Idle else Idle
          , brickImportanceConfidence =
              if statusChangedFrom payload == BrickArchived && target == BrickActive
                then Provisional "restored local placement"
                else brickImportanceConfidence brick
          }
  Right . bump $
    state
      { stateBricks = Map.insert (brickId brick) changed (stateBricks state)
      , stateCurrentFocus =
          if stateCurrentFocus state == Just (brickId brick) && target /= BrickActive
            then Nothing
            else stateCurrentFocus state
      , stateActiveSprint =
          case stateActiveSprint state of
            Just sprint | activeSprintBrick sprint == brickId brick && target /= BrickActive -> Nothing
            existing -> existing
      , stateLastRedo = Nothing
      }
 where
  allowed BrickActive BrickArchived = True
  allowed BrickArchived BrickActive = True
  allowed BrickActive BrickSuperseded = True
  allowed BrickArchived BrickSuperseded = True
  allowed BrickActive BrickMerged = True
  allowed BrickArchived BrickMerged = True
  allowed _ _ = False
reactionClosesFocus :: SkipReaction -> Bool
reactionClosesFocus = \case
  SkipAnywayReaction -> True
  PauseForNowReaction -> True
  StartSprintReaction{} -> True
  ChangeSubjectReaction -> True
  EasierWorkReaction{} -> True
  OrderLowerReaction -> True
  LaterReaction -> True
  ArchiveReaction -> True
  _ -> False

applyFocusPaused :: State -> FocusPaused -> Either AppError State
applyFocusPaused state payload = do
  brick <- requireBrick state (pausedFocusBrick payload)
  unless (stateCurrentFocus state == Just (brickId brick) && brickWorkState brick == Wip) $
    corrupt "Only the current WIP can be paused."
  Right . bump $
    state
      { stateCurrentFocus = Nothing
      , stateActiveSprint =
          case stateActiveSprint state of
            Just sprint | activeSprintBrick sprint == brickId brick -> Nothing
            other -> other
      , stateLastRedo = Nothing
      }

applySprintStarted :: State -> PersistedEvent -> SprintStarted -> Either AppError State
applySprintStarted state event payload = do
  brick <- requireBrick state (sprintStartedBrick payload)
  unless (brickStatus brick == BrickActive) $ corrupt "Only active Work can start a sprint."
  unless (sprintStartedMinutes payload >= 1 && sprintStartedMinutes payload <= 120) $
    corrupt "A sprint duration must be between 1 and 120 minutes."
  let expectedEnd = addUTCTime (fromIntegral (sprintStartedMinutes payload * 60)) (persistedRecordedAt event)
  unless (sprintStartedEndsAt payload == expectedEnd) $ corrupt "A sprint end must match its recorded duration."
  let sprint = ActiveSprint (brickId brick) (persistedRecordedAt event) expectedEnd (sprintStartedMinutes payload)
      bricks = Map.adjust (\current -> current{brickWorkState = Wip}) (brickId brick) (stateBricks state)
  Right . bump $
    state
      { stateBricks = bricks
      , stateCurrentFocus = Just (brickId brick)
      , stateActiveSprint = Just sprint
      , stateLastRedo = Nothing
      }

applyRawFed :: State -> PersistedEvent -> RawFed -> Either AppError State
applyRawFed state event payload
  | Map.member (fedRawId payload) (stateRaws state) = duplicate "Raw UUID"
  | fedHandle payload `Set.member` stateRetiredRawHandles state = duplicate "Raw handle"
  | otherwise = do
      validateRawContent initialContent
      Right . bump $
        state
          { stateRaws = Map.insert (fedRawId payload) raw (stateRaws state)
          , stateRawHandles = Map.insert (fedHandle payload) (fedRawId payload) (stateRawHandles state)
          , stateRetiredRawHandles = Set.insert (fedHandle payload) (stateRetiredRawHandles state)
          , stateCommandEffects = Map.insert (persistedCommandId event) effect (stateCommandEffects state)
          , stateRawContentRevisions = Map.insert (rawContentRevisionId revision) revision (stateRawContentRevisions state)
          , stateCurrentRawRevisions = Map.insert (fedRawId payload) (rawContentRevisionId revision) (stateCurrentRawRevisions state)
          , stateLastRedo = Nothing
          }
 where
  raw =
    Raw
      (fedRawId payload)
      (fedHandle payload)
      (fedOriginal payload)
      (persistedRecordedAt event)
      (persistedActor event)
      RawAwaitingReview
      1
      (persistedCommandId event)
  effect = CommandEffect (persistedCommandId event) (persistedActor event) [fedRawId payload] Nothing
  revision =
    RawContentRevision
      (persistedEventId event)
      (fedRawId payload)
      1
      (persistedRecordedAt event)
      (persistedActor event)
      (fedOrigin payload)
      initialContent
      (rawContentDigest initialContent)
  initialContent = maybe (RawTextContent (fedOriginal payload)) id (fedContent payload)
  duplicate subject = corrupt (subject <> " is repeated in canonical history.")

applyRawContentRevisionAppended :: State -> PersistedEvent -> RawContentRevisionAppended -> Either AppError State
applyRawContentRevisionAppended state event payload = do
  raw <- requireRaw state (appendedRawRevisionRaw payload)
  when (Map.member (persistedEventId event) (stateRawContentRevisions state)) $ corrupt "A Raw content revision UUID is repeated."
  unless (appendedRawRevisionOrdinal payload == rawRevision raw + 1) $ corrupt "A Raw content revision ordinal is not contiguous."
  unless (appendedRawRevisionDigest payload == rawContentDigest (appendedRawRevisionContent payload)) $ corrupt "A Raw content revision digest is invalid."
  validateRawContent (appendedRawRevisionContent payload)
  let revision =
        RawContentRevision
          (persistedEventId event)
          (rawId raw)
          (appendedRawRevisionOrdinal payload)
          (persistedRecordedAt event)
          (persistedActor event)
          (appendedRawRevisionProvenance payload)
          (appendedRawRevisionContent payload)
          (appendedRawRevisionDigest payload)
      changedRaw = raw{rawRevision = appendedRawRevisionOrdinal payload}
  pure . bump $
    state
      { stateRaws = Map.insert (rawId raw) changedRaw (stateRaws state)
      , stateRawContentRevisions = Map.insert (persistedEventId event) revision (stateRawContentRevisions state)
      , stateCurrentRawRevisions = Map.insert (rawId raw) (persistedEventId event) (stateCurrentRawRevisions state)
      }

applyEnglishNormalizationAccepted :: State -> PersistedEvent -> EnglishNormalizationAccepted -> Either AppError State
applyEnglishNormalizationAccepted state event payload = do
  revision <- maybe (corrupt "An English normalization references a missing Raw revision.") Right (Map.lookup (acceptedNormalizationRevision payload) (stateRawContentRevisions state))
  case rawContentRevisionContent revision of
    RawTextContent{} -> pure ()
    _ -> corrupt "Only a text Raw revision can receive an English normalization without a separate extraction."
  when (Text.null (Text.strip (acceptedNormalizationText payload))) $ corrupt "An English normalization cannot be empty."
  traverse_ (\confidence -> unless (confidence >= Fixed 0 && confidence <= Fixed 1000000) (corrupt "Normalization confidence is outside [0,1].")) (acceptedNormalizationConfidence payload)
  let normalization =
        EnglishNormalization
          (persistedEventId event)
          (acceptedNormalizationRevision payload)
          (acceptedNormalizationText payload)
          (acceptedNormalizationSource payload)
          (acceptedNormalizationProducer payload)
          (persistedRecordedAt event)
          (acceptedNormalizationConfidence payload)
  pure . bump $
    state
      { stateEnglishNormalizations = Map.insert (persistedEventId event) normalization (stateEnglishNormalizations state)
      , stateCurrentEnglishNormalizations = Map.insert (acceptedNormalizationRevision payload) (persistedEventId event) (stateCurrentEnglishNormalizations state)
      }

applyBrickTitleNormalizationAccepted :: State -> PersistedEvent -> BrickTitleNormalizationAccepted -> Either AppError State
applyBrickTitleNormalizationAccepted state event payload = do
  brick <- requireBrick state (acceptedTitleNormalizationBrick payload)
  when (Map.member (persistedEventId event) (stateBrickTitleNormalizations state)) $ corrupt "A Brick title normalization UUID is repeated."
  unless (brickTitle brick == acceptedTitleNormalizationPrevious payload) $ corrupt "A Brick title normalization cites a stale previous title."
  when (Text.null (Text.strip (acceptedTitleNormalizationCurrent payload))) $ corrupt "A normalized Brick title cannot be empty."
  traverse_ (\confidence -> unless (confidence >= Fixed 0 && confidence <= Fixed 1000000) (corrupt "Title-normalization confidence is outside [0,1].")) (acceptedTitleNormalizationConfidence payload)
  let normalization =
        BrickTitleNormalization
          (persistedEventId event)
          (brickId brick)
          (acceptedTitleNormalizationPrevious payload)
          (acceptedTitleNormalizationCurrent payload)
          (acceptedTitleNormalizationSource payload)
          (acceptedTitleNormalizationProducer payload)
          (persistedRecordedAt event)
          (acceptedTitleNormalizationConfidence payload)
      changedBrick = brick{brickTitle = acceptedTitleNormalizationCurrent payload}
  pure . bump $
    state
      { stateBricks = Map.insert (brickId brick) changedBrick (stateBricks state)
      , stateBrickTitleNormalizations = Map.insert (persistedEventId event) normalization (stateBrickTitleNormalizations state)
      , stateCurrentBrickTitleNormalizations = Map.insert (brickId brick) (persistedEventId event) (stateCurrentBrickTitleNormalizations state)
      }

applyImportProfileChanged :: State -> ImportProfile -> Either AppError State
applyImportProfileChanged state profile = do
  when (any (Text.null . Text.strip) requiredText) $ corrupt "An ImportProfile contains an empty source-scope field."
  when (any (Text.null . Text.strip) (Set.toList (importProfileSelectedContainers profile))) $
    corrupt "An ImportProfile contains an empty selected-container identity."
  case Map.lookup (importProfileId profile) (stateImportProfiles state) of
    Nothing -> unless (importProfileRevision profile == 1) $ corrupt "A new ImportProfile must start at revision one."
    Just previous -> do
      unless (importProfileRevision profile == importProfileRevision previous + 1) $ corrupt "An ImportProfile revision is not contiguous."
      unless
        ( importProfileAdapterId profile == importProfileAdapterId previous
            && importProfileInputReference profile == importProfileInputReference previous
        )
        $ corrupt "An ImportProfile update changed immutable source scope."
  pure . bump $ state{stateImportProfiles = Map.insert (importProfileId profile) profile (stateImportProfiles state)}
 where
  requiredText =
    [ importProfileAdapterId profile
    , importProfileSourceLabel profile
    , importProfileInputReference profile
    ]

applyImportInvocationRecorded :: State -> PersistedEvent -> ImportInvocation -> Either AppError State
applyImportInvocationRecorded state event invocation = do
  profile <- case Map.lookup (importInvocationProfileId invocation) (stateImportProfiles state) of
    Nothing -> corrupt "An ImportInvocation references a missing ImportProfile."
    Just value -> Right value
  when (Map.member (importInvocationId invocation) (stateImportInvocations state)) $ corrupt "An ImportInvocation identity was recorded twice."
  when (any (Text.null . Text.strip) requiredText) $ corrupt "An ImportInvocation contains an empty custody field."
  when (importInvocationContractMajor invocation < 1) $ corrupt "An ImportInvocation contract major must be positive."
  when (importInvocationInputByteCount invocation < 0) $ corrupt "An ImportInvocation input byte count cannot be negative."
  when (any (Text.null . Text.strip) (Set.toList (importInvocationSelectedContainers invocation))) $
    corrupt "An ImportInvocation contains an empty selected-container identity."
  traverse_ requireDigest digestFields
  when (null mappings) $ corrupt "An ImportInvocation must attribute at least one source object."
  unless (unique (importObjectExternalIdentity <$> mappings)) $ corrupt "An ImportInvocation repeats one external identity."
  unless
    ( importProfileAdapterId profile == importInvocationComponentId invocation
        && importProfileMode profile == importInvocationMode invocation
        && importProfileSelectedContainers profile == importInvocationSelectedContainers invocation
    )
    $ corrupt "An ImportInvocation does not match its ImportProfile scope."
  traverse_ validateMapping mappings
  pure . bump $ state{stateImportInvocations = Map.insert (importInvocationId invocation) invocation (stateImportInvocations state)}
 where
  mappings = importInvocationMappings invocation
  requiredText =
    [ importInvocationComponentId invocation
    , importInvocationPermissions invocation
    , importInvocationInputLabel invocation
    , importInvocationInputMediaType invocation
    , importInvocationPackPublisher invocation
    , importInvocationPackName invocation
    , importInvocationPackVersion invocation
    , importInvocationSignerFingerprint invocation
    ]
  digestFields =
    [ importInvocationInputDigest invocation
    , importInvocationPackManifestDigest invocation
    , importInvocationPackArchiveDigest invocation
    ]
  requireDigest digest =
    unless (Text.length digest == 64 && Text.all lowerHex digest) $
      corrupt "An ImportInvocation contains an invalid SHA-256 digest."
  lowerHex character = (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f')
  unique values = Set.size (Set.fromList values) == length values
  validateMapping mapping = do
    when (Text.null (Text.strip (importObjectExternalIdentity mapping))) $ corrupt "An ImportInvocation mapping has an empty external identity."
    raw <- requireRaw state (importObjectRawId mapping)
    let matchingBindings =
          [ binding
          | binding <- Map.elems (stateSourceBindings state)
          , sourceBindingImportProfile binding == Just (importInvocationProfileId invocation)
          , sourceBindingExternalIdentity binding == Just (importObjectExternalIdentity mapping)
          , sourceBindingRaw binding == importObjectRawId mapping
          ]
    unless (length matchingBindings == 1) $ corrupt "An ImportInvocation mapping has no unique SourceBinding."
    case importObjectDisposition mapping of
      ImportCreatedRaw -> unless (rawCreatedByCommand raw == persistedCommandId event) $ corrupt "An ImportInvocation labels a pre-existing Raw as newly created."
      ImportReusedRaw -> when (rawCreatedByCommand raw == persistedCommandId event) $ corrupt "An ImportInvocation labels a newly created Raw as reused."

applySourceBindingChanged :: State -> SourceBinding -> Either AppError State
applySourceBindingChanged state binding = do
  _ <- requireRaw state (sourceBindingRaw binding)
  traverse_
    (\profileId -> unless (Map.member profileId (stateImportProfiles state)) $ corrupt "A SourceBinding ImportProfile is missing.")
    (sourceBindingImportProfile binding)
  when (Text.null (Text.strip (sourceBindingKind binding)) || Text.null (Text.strip (sourceBindingLocator binding))) $ corrupt "A SourceBinding needs a kind and locator."
  case sourceBindingCheckPolicy binding of
    SourceIntervalCheck seconds | seconds <= 0 -> corrupt "A SourceBinding interval must be positive."
    _ -> pure ()
  traverse_ validateBaseline (sourceBindingAcceptedObservation binding)
  case Map.lookup (sourceBindingId binding) (stateSourceBindings state) of
    Nothing -> unless (sourceBindingRevision binding == 1) $ corrupt "A new SourceBinding must start at revision one."
    Just previous -> do
      unless (sourceBindingRevision binding == sourceBindingRevision previous + 1) $ corrupt "A SourceBinding revision is not contiguous."
      unless
        ( sourceBindingRaw binding == sourceBindingRaw previous
            && sourceBindingKind binding == sourceBindingKind previous
            && sourceBindingImportProfile binding == sourceBindingImportProfile previous
            && sourceBindingExternalIdentity binding == sourceBindingExternalIdentity previous
            && sourceBindingContainerIdentity binding == sourceBindingContainerIdentity previous
        )
        $ corrupt "A SourceBinding update changed immutable identity facts."
  pure . bump $ state{stateSourceBindings = Map.insert (sourceBindingId binding) binding (stateSourceBindings state)}
 where
  validateBaseline observationId = do
    observation <- maybe (corrupt "A SourceBinding baseline observation is missing.") Right (Map.lookup observationId (stateSourceObservations state))
    unless (sourceObservationBinding observation == sourceBindingId binding) $ corrupt "A SourceBinding baseline belongs to another binding."
    when (sourceObservationOutcome observation == SourceChanged && not (sourceObservationIsReconciled state observationId)) $
      corrupt "A changed SourceObservation cannot become baseline before reconciliation."

applySourceObservationRecorded :: State -> PersistedEvent -> SourceObservationRecorded -> Either AppError State
applySourceObservationRecorded state event payload = do
  binding <- maybe (corrupt "A SourceObservation binding is missing.") Right (Map.lookup (recordedSourceObservationBinding payload) (stateSourceBindings state))
  unless (sourceBindingLifecycle binding /= SourceBindingDetached) $ corrupt "A detached SourceBinding cannot be checked."
  when (Text.null (Text.strip (recordedSourceObservationLocator payload))) $ corrupt "A SourceObservation locator cannot be empty."
  when (Map.member (persistedEventId event) (stateSourceObservations state)) $ corrupt "A SourceObservation UUID is repeated."
  traverse_ validateRawContent (recordedSourceObservationSnapshot payload)
  case (recordedSourceObservationOutcome payload, recordedSourceObservationSnapshot payload, recordedSourceObservationSnapshotDigest payload) of
    (SourceChanged, Just snapshot, Just digest) -> unless (rawContentDigest snapshot == digest) $ corrupt "A SourceObservation snapshot digest is invalid."
    (SourceChanged, _, _) -> corrupt "A changed SourceObservation requires canonical snapshot material and its digest."
    (_, Just snapshot, Just digest) -> unless (rawContentDigest snapshot == digest) $ corrupt "A SourceObservation snapshot digest is invalid."
    (_, Just _, Nothing) -> corrupt "Canonical SourceObservation snapshot material requires its digest."
    _ -> pure ()
  let observation =
        SourceObservation
          (persistedEventId event)
          (recordedSourceObservationBinding payload)
          (persistedRecordedAt event)
          (recordedSourceObservationLocator payload)
          (recordedSourceObservationOutcome payload)
          (recordedSourceObservationProviderVersion payload)
          (recordedSourceObservationFingerprint payload)
          (recordedSourceObservationSnapshotDigest payload)
          (recordedSourceObservationSnapshot payload)
  pure . bump $ state{stateSourceObservations = Map.insert (persistedEventId event) observation (stateSourceObservations state)}

applySourceObservationReconciled :: State -> PersistedEvent -> SourceObservationReconciled -> Either AppError State
applySourceObservationReconciled state event payload = do
  observation <- maybe (corrupt "A Source reconciliation references a missing observation.") Right (Map.lookup (reconciledSourceObservation payload) (stateSourceObservations state))
  unless (sourceObservationOutcome observation == SourceChanged) $ corrupt "Only a changed SourceObservation enters content reconciliation."
  when (sourceObservationIsReconciled state (sourceObservationId observation)) $ corrupt "A SourceObservation cannot be reconciled twice."
  binding <- maybe (corrupt "A Source reconciliation references a missing binding.") Right (Map.lookup (sourceObservationBinding observation) (stateSourceBindings state))
  validateDisposition binding (reconciledSourceDisposition payload)
  let reconciliation = SourceReconciliation (persistedEventId event) (sourceObservationId observation) (reconciledSourceDisposition payload) (persistedRecordedAt event) (persistedActor event)
  pure . bump $ state{stateSourceReconciliations = Map.insert (persistedEventId event) reconciliation (stateSourceReconciliations state)}
 where
  validateDisposition binding = \case
    SourceAcceptedAsRevision revisionId -> do
      revision <- maybe (corrupt "A source reconciliation references a missing Raw revision.") Right (Map.lookup revisionId (stateRawContentRevisions state))
      unless (rawContentRevisionRaw revision == sourceBindingRaw binding && Map.lookup (sourceBindingRaw binding) (stateCurrentRawRevisions state) == Just revisionId) $
        corrupt "A source reconciliation must cite the current revision of its bound Raw."
    SourceAcceptedAsDerivedRaw derivedId -> do
      _ <- requireRaw state derivedId
      let linked = any (\link -> rawLinkRaw link == derivedId && rawLinkTarget link == RawLinkRaw (sourceBindingRaw binding) && rawLinkRole link == DerivedFromRole) (Map.elems (stateRawLinks state))
      unless linked $ corrupt "A derived source reconciliation requires its derived_from RawLink."
    SourceIgnoredAsUnrelated -> pure ()

sourceObservationIsReconciled :: State -> UUIDv7 -> Bool
sourceObservationIsReconciled state observationId =
  any ((== observationId) . sourceReconciliationObservation) (Map.elems (stateSourceReconciliations state))

validateRawContent :: RawContent -> Either AppError ()
validateRawContent = \case
  RawTextContent text -> when (Text.null text) (corrupt "A text Raw revision cannot be empty.")
  RawUriContent locator _ -> when (Text.null (Text.strip locator)) (corrupt "A URI Raw revision cannot be empty.")
  RawBlobContent digest mediaType lengthBytes _ -> do
    when (Text.null digest || Text.null mediaType || lengthBytes < 0) (corrupt "A blob Raw revision has invalid metadata.")
  RawStructuredContent schema json -> when (Text.null schema || Text.null json) (corrupt "A structured Raw revision needs schema and canonical JSON.")

rawContentDigest :: RawContent -> Text
rawContentDigest = TextEncoding.decodeUtf8 . Base16.encode . SHA256.hash . TextEncoding.encodeUtf8 . contentCanonicalText

contentCanonicalText :: RawContent -> Text
contentCanonicalText = \case
  RawTextContent text -> "text\n" <> text
  RawUriContent locator label -> "uri\n" <> locator <> "\n" <> maybe "" id label
  RawBlobContent digest mediaType lengthBytes filename -> "blob\n" <> digest <> "\n" <> mediaType <> "\n" <> Text.pack (show lengthBytes) <> "\n" <> maybe "" id filename
  RawStructuredContent schema json -> "structured\n" <> schema <> "\n" <> json

applyFeedRetraction :: State -> PersistedEvent -> RawFeedRetracted -> Either AppError State
applyFeedRetraction state event payload = do
  raw <- requireRaw state (retractedRawId payload)
  effect <- requireFeedEffect state (retractedFeedCommandId payload)
  unless (rawCreatedByCommand raw == retractedFeedCommandId payload) $
    corrupt "The Raw was not created by the target Feed command."
  unless
    ( rawStatus raw == RawAwaitingReview
        && rawRevision raw == 1
        && Map.notMember (rawId raw) (stateRawDispositions state)
        && isNothing (effectCompensatedBy effect)
    )
    $ corrupt "The target Feed command is no longer safely reversible."
  Right . bump $
    state
      { stateRaws = Map.insert (rawId raw) raw{rawStatus = RawRetracted} (stateRaws state)
      , stateRawHandles = Map.delete (rawHandle raw) (stateRawHandles state)
      , stateCommandEffects =
          Map.insert
            (effectCommandId effect)
            effect{effectCompensatedBy = Just (persistedCommandId event)}
            (stateCommandEffects state)
      , stateLastRedo = Just (effectCommandId effect)
      }

applyFeedRestoration :: State -> PersistedEvent -> RawFeedRestored -> Either AppError State
applyFeedRestoration state _ payload = do
  raw <- requireRaw state (restoredRawId payload)
  effect <- requireFeedEffect state (restoredFeedCommandId payload)
  unless
    ( rawStatus raw == RawRetracted
        && effectCompensatedBy effect == Just (restoredRetractionCommandId payload)
        && stateLastRedo state == Just (restoredFeedCommandId payload)
    )
    $ corrupt "The Feed command can no longer be redone."
  Right . bump $
    state
      { stateRaws = Map.insert (rawId raw) raw{rawStatus = RawAwaitingReview} (stateRaws state)
      , stateRawHandles = Map.insert (rawHandle raw) (rawId raw) (stateRawHandles state)
      , stateCommandEffects =
          Map.insert
            (effectCommandId effect)
            effect{effectCompensatedBy = Nothing}
            (stateCommandEffects state)
      , stateLastRedo = Nothing
      }

applyBrickCreated :: State -> PersistedEvent -> BrickCreated -> Either AppError State
applyBrickCreated state event payload = do
  _ <- requireRaw state (createdSourceRawId payload)
  when (Map.member (createdBrickId payload) (stateBricks state)) $ corrupt "Brick UUID is repeated in canonical history."
  when (createdBrickHandle payload `Set.member` stateRetiredBrickHandles state) $ corrupt "Brick handle is repeated in canonical history."
  case createdParent payload of
    Nothing -> pure ()
    Just parentId -> do
      parent <- requireBrick state parentId
      unless (brickStatus parent == BrickActive) $ corrupt "A new Brick cannot use an inactive parent."
  unless (all (`Map.member` stateDomains state) (Set.toList (createdDomains payload))) $
    corrupt "A new Brick references an unknown Domain."
  let siblings = siblingBricks state (createdParent payload)
  unless (createdSiblingPosition payload >= 0 && createdSiblingPosition payload <= length siblings) $
    corrupt "A new Brick has an invalid sibling position."
  let shifted =
        Map.map
          ( \currentBrick ->
              if brickStatus currentBrick == BrickActive
                && brickParent currentBrick == createdParent payload
                && brickSiblingPosition currentBrick >= createdSiblingPosition payload
                then currentBrick{brickSiblingPosition = brickSiblingPosition currentBrick + 1}
                else currentBrick
          )
          (stateBricks state)
      brick =
        Brick
          (createdBrickId payload)
          (createdBrickHandle payload)
          (createdBrickTitle payload)
          (createdBrickNature payload)
          (createdNatureVersion payload)
          (createdNatureSource payload)
          (createdTemplate payload)
          (createdParent payload)
          (createdDomains payload)
          (createdSiblingPosition payload)
          (createdImportanceConfidence payload)
          BrickActive
          Idle
          (persistedRecordedAt event)
          (persistedActor event)
          (persistedCommandId event)
      effect =
        MaterializationEffect
          (persistedCommandId event)
          (createdSourceRawId payload)
          (Just (createdBrickId payload))
          []
          []
          (Map.lookup (createdSourceRawId payload) (stateRawDispositions state))
          Nothing
          []
          []
          Map.empty
  Right . bump $
    state
      { stateBricks = Map.insert (brickId brick) brick shifted
      , stateBrickHandles = Map.insert (brickHandle brick) (brickId brick) (stateBrickHandles state)
      , stateRetiredBrickHandles = Set.insert (brickHandle brick) (stateRetiredBrickHandles state)
      , stateMaterializationEffects = Map.insert (persistedCommandId event) effect (stateMaterializationEffects state)
      , stateLastRedo = Nothing
      }

applyBrickNatureChanged :: State -> BrickNatureChanged -> Either AppError State
applyBrickNatureChanged state payload = do
  brick <- requireBrick state (natureChangedBrick payload)
  unless (brickStatus brick == BrickActive) $ corrupt "Only an active Brick can change Nature."
  unless (brickNature brick == natureChangedFrom payload) $ corrupt "A Nature change cites stale prior Nature."
  when (natureChangedFrom payload == natureChangedTo payload) $ corrupt "A Nature change must change the Nature."
  let changed =
        brick
          { brickNature = natureChangedTo payload
          , brickNatureVersion = "factory@1"
          , brickNatureSource = natureChangedSource payload
          }
  Right . bump $
    state
      { stateBricks = Map.insert (brickId brick) changed (stateBricks state)
      , stateLastRedo = Nothing
      }

applyBrickChildCreated :: State -> PersistedEvent -> BrickChildCreated -> Either AppError State
applyBrickChildCreated state event payload = do
  parent <- requireBrick state (createdChildParent payload)
  unless (brickStatus parent == BrickActive) $ corrupt "A child cannot be added to inactive Work."
  unless (elem (brickNature parent) [Project, Collection, ScheduledCommitment]) $
    corrupt "The parent Nature cannot own independently focusable child Bricks."
  when (Map.member (createdChildId payload) (stateBricks state)) $ corrupt "Child Brick UUID is repeated in canonical history."
  when (Set.member (createdChildHandle payload) (stateRetiredBrickHandles state)) $ corrupt "Child Brick handle is repeated in canonical history."
  when (Text.null (Text.strip (createdChildTitle payload))) $ corrupt "A child Brick title cannot be empty."
  let siblings =
        [ child
        | child <- Map.elems (stateBricks state)
        , brickParent child == Just (brickId parent)
        ]
      expectedPosition =
        case fmap brickSiblingPosition siblings of
          [] -> 0
          positions -> maximum positions + 1
  unless (createdChildSiblingPosition payload == expectedPosition) $
    corrupt "A child Brick append position is not contiguous."
  let child =
        Brick
          (createdChildId payload)
          (createdChildHandle payload)
          (createdChildTitle payload)
          (createdChildNature payload)
          (createdChildNatureVersion payload)
          (createdChildNatureSource payload)
          Nothing
          (Just (brickId parent))
          Set.empty
          expectedPosition
          (createdChildImportanceConfidence payload)
          BrickActive
          Idle
          (persistedRecordedAt event)
          (persistedActor event)
          (persistedCommandId event)
  Right . bump $
    state
      { stateBricks = Map.insert (brickId child) child (stateBricks state)
      , stateBrickHandles = Map.insert (brickHandle child) (brickId child) (stateBrickHandles state)
      , stateRetiredBrickHandles = Set.insert (brickHandle child) (stateRetiredBrickHandles state)
      , stateLastRedo = Nothing
      }

applyLazyReviewRequested :: State -> PersistedEvent -> LazyReviewRequested -> Either AppError State
applyLazyReviewRequested state event payload = do
  _ <- requireBrick state (requestedReviewSubject payload)
  when (Map.member (persistedEventId event) (stateLazyReviews state)) $
    corrupt "Lazy-review UUID is repeated in canonical history."
  when (Text.null (Text.strip (requestedReviewKind payload))) $ corrupt "A lazy review kind cannot be empty."
  let claim =
        LazyReviewClaim
          (persistedEventId event)
          (requestedReviewSubject payload)
          (requestedReviewKind payload)
          (requestedReviewReason payload)
          (persistedRecordedAt event)
  Right . bump $
    state
      { stateLazyReviews = Map.insert (lazyReviewId claim) claim (stateLazyReviews state)
      , stateLastRedo = Nothing
      }

applyRawLinkAdded :: State -> PersistedEvent -> RawLinkAdded -> Either AppError State
applyRawLinkAdded state event payload = do
  _ <- requireRaw state (addedRawId payload)
  when (Map.member (addedRawLinkId payload) (stateRawLinks state)) $ corrupt "RawLink UUID is repeated in canonical history."
  validateTarget state (addedRawLinkTarget payload)
  validateRoleCardinality state payload
  let link =
        RawLink
          (addedRawLinkId payload)
          (addedRawId payload)
          (addedRawLinkTarget payload)
          (addedRawLinkRole payload)
          (persistedRecordedAt event)
          (persistedActor event)
      effects =
        Map.alter
          (Just . updateEffect)
          (persistedCommandId event)
          (stateMaterializationEffects state)
      updateEffect = \case
        Nothing -> MaterializationEffect (persistedCommandId event) (addedRawId payload) Nothing [addedRawLinkId payload] [] (Map.lookup (addedRawId payload) (stateRawDispositions state)) Nothing [] [] Map.empty
        Just effect -> effect{materializationLinkIds = materializationLinkIds effect <> [addedRawLinkId payload]}
  Right . bump $ state{stateRawLinks = Map.insert (rawLinkId link) link (stateRawLinks state), stateMaterializationEffects = effects}

applyRawDisposition :: State -> PersistedEvent -> RawDispositionAccepted -> Either AppError State
applyRawDisposition state event payload = do
  raw <- requireRaw state (dispositionRawId payload)
  unless (rawStatus raw == RawAwaitingReview) $ corrupt "Only active Raw material can receive a triage disposition."
  when (Map.member (rawId raw) (stateRawDispositions state)) $ corrupt "The Raw already has an accepted triage disposition."
  validateDisposition state (rawId raw) (acceptedRawDisposition payload)
  let effects =
        Map.alter
          (Just . updateEffect)
          (persistedCommandId event)
          (stateMaterializationEffects state)
      updateEffect = \case
        Nothing -> MaterializationEffect (persistedCommandId event) (rawId raw) Nothing [] [] Nothing Nothing [] [] Map.empty
        Just effect -> effect
  Right . bump $
    state
      { stateRawDispositions = Map.insert (rawId raw) (acceptedRawDisposition payload) (stateRawDispositions state)
      , stateMaterializationEffects = effects
      , stateLastRedo = Nothing
      }

applyRawShelfCreated :: State -> PersistedEvent -> RawShelfCreated -> Either AppError State
applyRawShelfCreated state event payload = do
  _ <- requireRaw state (createdRawShelfSourceRaw payload)
  let name = Text.strip (createdRawShelfName payload)
      normalized = Text.toCaseFold name
  when (Text.null name) $ corrupt "A RawShelf name cannot be empty."
  when (Map.member (createdRawShelfId payload) (stateRawShelves state)) $ corrupt "A RawShelf UUID is repeated in canonical history."
  when (any (\shelf -> rawShelfActive shelf && Text.toCaseFold (rawShelfName shelf) == normalized) (Map.elems (stateRawShelves state))) $
    corrupt "An active RawShelf with the same canonical name already exists."
  let shelf = RawShelf (createdRawShelfId payload) name True []
      effects =
        Map.alter
          ( Just
              . \case
                Nothing -> MaterializationEffect (persistedCommandId event) (createdRawShelfSourceRaw payload) Nothing [] [] Nothing Nothing [createdRawShelfId payload] [] Map.empty
                Just effect -> effect{materializationCreatedShelfIds = materializationCreatedShelfIds effect <> [createdRawShelfId payload]}
          )
          (persistedCommandId event)
          (stateMaterializationEffects state)
  Right . bump $ state{stateRawShelves = Map.insert (rawShelfId shelf) shelf (stateRawShelves state), stateMaterializationEffects = effects, stateLastRedo = Nothing}

applyRawShelfMemberAdded :: State -> PersistedEvent -> RawShelfMemberAdded -> Either AppError State
applyRawShelfMemberAdded state event payload = do
  raw <- requireRaw state (memberRawId payload)
  unless (rawStatus raw == RawAwaitingReview) $ corrupt "Only active Raw material can be placed on a RawShelf."
  shelf <- maybe (corrupt "A RawShelf membership references a missing shelf.") Right (Map.lookup (memberRawShelfId payload) (stateRawShelves state))
  unless (rawShelfActive shelf) $ corrupt "Raw material cannot be added to an archived RawShelf."
  when (memberRawId payload `elem` rawShelfMembers shelf) $ corrupt "The Raw is already a direct member of this RawShelf."
  unless (memberRawOrdinal payload == length (rawShelfMembers shelf)) $ corrupt "RawShelf membership order is not contiguous."
  let updated = shelf{rawShelfMembers = rawShelfMembers shelf <> [memberRawId payload]}
      membership = (memberRawShelfId payload, memberRawId payload)
      effects =
        Map.alter
          ( Just
              . \case
                Nothing -> MaterializationEffect (persistedCommandId event) (memberRawId payload) Nothing [] [] Nothing Nothing [] [membership] Map.empty
                Just effect -> effect{materializationShelfMemberships = materializationShelfMemberships effect <> [membership]}
          )
          (persistedCommandId event)
          (stateMaterializationEffects state)
  Right . bump $ state{stateRawShelves = Map.insert (rawShelfId shelf) updated (stateRawShelves state), stateMaterializationEffects = effects, stateLastRedo = Nothing}

applyRawTriageDeferral :: State -> RawTriageDeferred -> Either AppError State
applyRawTriageDeferral state payload = do
  raw <- requireRaw state (deferredRawId payload)
  unless (rawStatus raw == RawAwaitingReview && Map.notMember (rawId raw) (stateRawDispositions state)) $
    corrupt "Only unresolved Inbox Raw material can be deferred."
  let expected = Map.findWithDefault 0 (rawId raw) (stateRawTriageDeferrals state) + 1
  unless (deferredCount payload == expected) $ corrupt "A Raw triage deferral count is not contiguous."
  Right . bump $ state{stateRawTriageDeferrals = Map.insert (rawId raw) expected (stateRawTriageDeferrals state)}

applyDuplicateRejection :: State -> RawDuplicateRejected -> Either AppError State
applyDuplicateRejection state payload = do
  firstRaw <- requireRaw state (duplicateCandidateRawId payload)
  secondRaw <- requireRaw state (duplicateComparedRawId payload)
  unless
    ( rawRevision firstRaw == duplicateCandidateRevision payload
        && rawRevision secondRaw == duplicateComparedRevision payload
    )
    $ corrupt "Raw duplicate negative evidence cites stale revisions."
  Right . bump $ state{stateRejectedRawDuplicates = Set.insert (duplicateCandidateRawId payload, duplicateCandidateRevision payload, duplicateComparedRawId payload, duplicateComparedRevision payload) (stateRejectedRawDuplicates state)}

applyImportanceCompared :: State -> PersistedEvent -> ImportanceCompared -> Either AppError State
applyListEntryCreated :: State -> PersistedEvent -> ListEntryCreated -> Either AppError State
applyListEntryCreated state event payload = do
  owner <- requireBrick state (createdListEntryOwner payload)
  _ <- requireRaw state (createdListEntrySourceRaw payload)
  unless (brickStatus owner == BrickActive && brickNature owner `elem` [LivingChecklist, FiniteChecklist]) $
    corrupt "Only an active checklist can own a ListEntry."
  when (Map.member (createdListEntryId payload) (stateListEntries state)) $
    corrupt "ListEntry UUID is repeated in canonical history."
  let owned = filter ((== brickId owner) . listEntryOwner) (Map.elems (stateListEntries state))
  unless (createdListEntryOrdinal payload == length owned) $
    corrupt "A ListEntry insertion ordinal is not contiguous for its owner."
  unless (quantityCoefficient (createdListEntryQuantity payload) > 0 && quantityScale (createdListEntryQuantity payload) >= 0) $
    corrupt "A ListEntry quantity must be positive and normalized."
  let entry =
        ListEntry
          (createdListEntryId payload)
          (brickId owner)
          (createdListEntryLabel payload)
          (createdListEntryQuantity payload)
          EntryOpen
          (createdListEntryOrdinal payload)
          (persistedRecordedAt event)
      effect =
        MaterializationEffect
          (persistedCommandId event)
          (createdListEntrySourceRaw payload)
          Nothing
          []
          [createdListEntryId payload]
          (Map.lookup (createdListEntrySourceRaw payload) (stateRawDispositions state))
          Nothing
          []
          []
          Map.empty
  Right . bump $
    state
      { stateListEntries = Map.insert (listEntryId entry) entry (stateListEntries state)
      , stateMaterializationEffects = Map.insert (persistedCommandId event) effect (stateMaterializationEffects state)
      , stateLastRedo = Nothing
      }

applyListEntryQuantityChanged :: State -> PersistedEvent -> ListEntryQuantityChanged -> Either AppError State
applyListEntryQuantityChanged state event payload = do
  entry <- maybe (corrupt "A quantity event references a missing ListEntry.") Right (Map.lookup (changedListEntryId payload) (stateListEntries state))
  _ <- requireRaw state (changedListEntrySourceRaw payload)
  unless (listEntryState entry == EntryOpen && listEntryQuantity entry == previousListEntryQuantity payload) $
    corrupt "A ListEntry quantity event cites stale state."
  unless (quantityCoefficient (currentListEntryQuantity payload) > 0 && quantityScale (currentListEntryQuantity payload) >= 0) $
    corrupt "A changed ListEntry quantity must be positive and normalized."
  let updated = entry{listEntryQuantity = currentListEntryQuantity payload}
      effect =
        MaterializationEffect
          (persistedCommandId event)
          (changedListEntrySourceRaw payload)
          Nothing
          []
          []
          (Map.lookup (changedListEntrySourceRaw payload) (stateRawDispositions state))
          Nothing
          []
          []
          (Map.singleton (changedListEntryId payload) (previousListEntryQuantity payload))
  Right . bump $
    state
      { stateListEntries = Map.insert (listEntryId entry) updated (stateListEntries state)
      , stateMaterializationEffects = Map.insert (persistedCommandId event) effect (stateMaterializationEffects state)
      , stateLastRedo = Nothing
      }

applyImportanceCompared state event payload = do
  above <- requireBrick state (comparedAbove payload)
  below <- requireBrick state (comparedBelow payload)
  unless (brickParent above == brickParent below) $ corrupt "Importance comparison is valid only between siblings."
  when (brickId above == brickId below) $ corrupt "A Brick cannot be compared with itself."
  let edge = ImportanceEdge (brickId above) (brickId below) (persistedRecordedAt event) (comparisonSource payload)
      evidence =
        PairJudgmentRecorded
          (persistedEventId event)
          ImportanceAxis
          (brickId above)
          (brickId below)
          MoreThan
          DirectHuman
          (initialConfidence DirectHuman)
          factoryJudgmentProfileHash
          "work_materialization"
          (comparisonSource payload)
          JudgmentCurrent
          []
  next <- applyPairJudgmentRecorded state event evidence
  pure next{stateImportanceEdges = Set.insert edge (stateImportanceEdges next)}

applyImportancePlacementMarked :: State -> PersistedEvent -> ImportancePlacementMarked -> Either AppError State
applyImportancePlacementMarked state event payload = do
  brick <- requireActiveBrick state (markedImportanceBrick payload)
  case markedImportanceConfidence payload of
    Provisional _ -> pure ()
    _ -> corrupt "An importance placement marker must be provisional."
  let updated = brick{brickImportanceConfidence = markedImportanceConfidence payload}
      review = LazyReviewClaim (persistedEventId event) (brickId brick) "importance_run_review" (markedImportanceReason payload) (persistedRecordedAt event)
  Right . bump $
    state
      { stateBricks = Map.insert (brickId brick) updated (stateBricks state)
      , stateLazyReviews = Map.insert (lazyReviewId review) review (stateLazyReviews state)
      , stateLastRedo = Nothing
      }

applyPairJudgmentRecorded :: State -> PersistedEvent -> PairJudgmentRecorded -> Either AppError State
applyPairJudgmentRecorded state event payload = do
  first <- requireActiveBrick state (recordedJudgmentFirst payload)
  second <- requireActiveBrick state (recordedJudgmentSecond payload)
  when (brickId first == brickId second) $ corrupt "A pair judgment cannot compare one Brick with itself."
  when (Map.member (recordedJudgmentId payload) (statePairJudgments state)) $ corrupt "A pair judgment UUID is repeated in canonical history."
  validatePairScope first second
  validateRelation
  validateConfidence
  retired <- traverse requireRetired (recordedRetiredJudgments payload)
  let resolutionId = persistedEventId event
      retire current =
        if judgmentId current `elem` fmap judgmentId retired
          then current{judgmentStatus = JudgmentRetired resolutionId (recordedJudgmentReason payload)}
          else current
      evidence =
        PairJudgment
          (recordedJudgmentId payload)
          (recordedJudgmentAxis payload)
          (brickId first)
          (brickId second)
          (recordedJudgmentRelation payload)
          (persistedRecordedAt event)
          (recordedJudgmentProvenance payload)
          (recordedJudgmentInitialConfidence payload)
          (recordedJudgmentProfileHash payload)
          (recordedJudgmentContext payload)
          (recordedJudgmentReason payload)
          (recordedJudgmentStatus payload)
      retiredJudgments = Map.map retire (statePairJudgments state)
      retiredState = state{statePairJudgments = retiredJudgments}
      judgments = Map.insert (judgmentId evidence) evidence retiredJudgments
      withEvidence = state{statePairJudgments = judgments, stateLastRedo = Nothing}
  case detectContradiction retiredState (persistedRecordedAt event) (recordedJudgmentAxis payload) (recordedJudgmentFirst payload) (recordedJudgmentSecond payload) of
    FreshContradiction{}
      | recordedJudgmentStatus payload == JudgmentCurrent
      , recordedJudgmentRelation payload == MoreThan
      , recordedJudgmentProvenance payload == DirectHuman ->
          corrupt "A fresh direct cycle requires explicit contradiction resolution."
    _ -> pure ()
  let reordered =
        if isActiveDirected evidence && judgmentAxis evidence == ImportanceAxis
          then reorderBricks withEvidence (brickParent first) (reorderedSiblingIds withEvidence (persistedRecordedAt event) (brickParent first))
          else withEvidence
  Right (bump reordered)
 where
  validatePairScope first second = case recordedJudgmentAxis payload of
    ImportanceAxis -> unless (brickParent first == brickParent second) $ corrupt "Importance compares only sibling Bricks."
    ImpactAxis -> unless (isNothing (brickParent first) && isNothing (brickParent second)) $ corrupt "Impact compares only composition roots."
    EffortAxis -> pure ()
  validateRelation = case (recordedJudgmentAxis payload, recordedJudgmentRelation payload) of
    (ImportanceAxis, AboutSame) -> corrupt "Importance has no about-the-same relation."
    (ImpactAxis, EitherOrder) -> corrupt "Impact has no either-order relation."
    (EffortAxis, EitherOrder) -> corrupt "Effort has no either-order relation."
    _ -> pure ()
  validateConfidence =
    unless (recordedJudgmentInitialConfidence payload == initialConfidence (recordedJudgmentProvenance payload)) $
      corrupt "A pair judgment does not match its provenance confidence."
  requireRetired identity = case Map.lookup identity (statePairJudgments state) of
    Nothing -> corrupt "A judgment resolution retires unknown evidence."
    Just judgment
      | judgmentAxis judgment /= recordedJudgmentAxis payload -> corrupt "A judgment resolution crosses axes."
      | judgmentStatus judgment /= JudgmentCurrent -> corrupt "Only current judgment evidence can retire."
      | otherwise -> Right judgment

applyPhaseChanged :: State -> PersistedEvent -> PhaseChanged -> Either AppError State
applyPhaseChanged state event payload = do
  brick <- requireActiveBrick state (changedPhaseBrick payload)
  let claims = case changedPhaseValue payload of
        Nothing -> Map.delete (brickId brick) (statePhaseClaims state)
        Just phase -> Map.insert (brickId brick) (PhaseClaim (brickId brick) phase (persistedRecordedAt event) (changedPhaseProvenance payload)) (statePhaseClaims state)
  Right . bump $ state{statePhaseClaims = claims, stateLastRedo = Nothing}

applyImpactClassified :: State -> PersistedEvent -> ImpactClassified -> Either AppError State
applyImpactClassified state event payload = do
  brick <- requireActiveBrick state (classifiedImpactBrick payload)
  unless (isNothing (brickParent brick)) $ corrupt "Only a composition root may own direct Impact."
  traverse_ requireImpactEvidence (classifiedImpactEvidence payload)
  case classifiedImpactClass payload of
    Nothing -> do
      unless (null (classifiedImpactEvidence payload)) $ corrupt "Cleared Impact cannot retain current evidence."
      Right . bump $ state{stateImpactClaims = Map.delete (brickId brick) (stateImpactClaims state), stateLastRedo = Nothing}
    Just impact -> do
      when (classifiedImpactMaturity payload /= SpeculativeImpact && null (classifiedImpactEvidence payload)) $
        corrupt "Supported Impact maturity requires selected evidence."
      let claim = ImpactClaim (brickId brick) impact (classifiedImpactMaturity payload) (classifiedImpactEvidence payload) (persistedRecordedAt event) (classifiedImpactProvenance payload) (classifiedImpactProfileHash payload)
      Right . bump $ state{stateImpactClaims = Map.insert (brickId brick) claim (stateImpactClaims state), stateLastRedo = Nothing}
 where
  requireImpactEvidence identity = case (Map.lookup identity (stateRaws state), Map.lookup identity (stateBricks state)) of
    (Just raw, _) | rawStatus raw /= RawRetracted -> Right ()
    (_, Just brick) | brickStatus brick == BrickDone -> Right ()
    _ -> corrupt "Impact evidence must cite existing Raw material or completed validation Work."

applyEffortClassified :: State -> PersistedEvent -> EffortClassified -> Either AppError State
applyEffortClassified state event payload = do
  brick <- requireActiveBrick state (classifiedEffortBrick payload)
  let claims = case classifiedEffortClass payload of
        Nothing -> Map.delete (brickId brick) (stateEffortClaims state)
        Just effort -> Map.insert (brickId brick) (EffortClaim (brickId brick) effort (persistedRecordedAt event) (classifiedEffortProvenance payload) (classifiedEffortProfileHash payload)) (stateEffortClaims state)
  Right . bump $ state{stateEffortClaims = claims, stateLastRedo = Nothing}

applyEffortActualObserved :: State -> PersistedEvent -> EffortActualObserved -> Either AppError State
applyEffortActualObserved state event payload = do
  _ <- requireBrick state (observedEffortActualBrick payload)
  raw <- requireRaw state (observedEffortActualRaw payload)
  invocation <-
    maybe
      (corrupt "Effort actual evidence references a missing ImportInvocation.")
      Right
      (Map.lookup (observedEffortActualImportInvocation payload) (stateImportInvocations state))
  when (importInvocationComponentId invocation /= "taskjuggler_actuals") $
    corrupt "Effort actual evidence must originate from the TaskJuggler actuals adapter."
  when (Map.member (persistedEventId event) (stateEffortActualEvidence state)) $
    corrupt "An effort actual evidence identity was recorded twice."
  unless (rawCreatedByCommand raw == persistedCommandId event) $
    corrupt "TaskJuggler actual evidence must be recorded atomically after its canonical Raw."
  unless (validDigest (observedEffortActualPlanningManifestDigest payload)) $
    corrupt "Effort actual evidence contains an invalid planning-manifest digest."
  let expectedTaskId = "t_" <> Text.filter (/= '-') (renderUUIDv7 (observedEffortActualBrick payload))
  unless (observedEffortActualTaskId payload == expectedTaskId) $
    corrupt "Effort actual evidence contains a noncanonical TaskJuggler task identity."
  when (isNothing completed && isNothing remaining) $
    corrupt "Effort actual evidence must contain completed or remaining effort."
  traverse_ (\value -> when (value < 0) $ corrupt "Effort actual evidence cannot contain negative microhours.") (catMaybes [completed, remaining])
  case importInvocationMappings invocation of
    [mapping] -> do
      unless (importObjectDisposition mapping == ImportCreatedRaw) $
        corrupt "TaskJuggler actual evidence requires a newly preserved immutable Raw observation."
      unless (importObjectRawId mapping == observedEffortActualRaw payload) $
        corrupt "Effort actual evidence does not reference the Raw owned by its ImportInvocation."
      unless (importObjectExternalIdentity mapping == expectedExternalIdentity) $
        corrupt "Effort actual evidence does not match its immutable source observation identity."
    _ -> corrupt "TaskJuggler actual evidence requires exactly one imported source object."
  let priorForManifest =
        [ evidence
        | evidence <- Map.elems (stateEffortActualEvidence state)
        , effortActualPlanningManifestDigest evidence == observedEffortActualPlanningManifestDigest payload
        , effortActualImportInvocation evidence /= observedEffortActualImportInvocation payload
        ]
      priorForInvocation =
        [ evidence
        | evidence <- Map.elems (stateEffortActualEvidence state)
        , effortActualImportInvocation evidence == observedEffortActualImportInvocation payload
        ]
  when (any ((== observedEffortActualTaskId payload) . effortActualTaskId) priorForInvocation) $
    corrupt "A TaskJuggler actuals invocation contains duplicate evidence for one task."
  unless
    ( all ((== observedEffortActualRaw payload) . effortActualRaw) priorForInvocation
        && all ((== observedEffortActualPlanningManifestDigest payload) . effortActualPlanningManifestDigest) priorForInvocation
        && all ((== observedEffortActualAsOf payload) . effortActualAsOf) priorForInvocation
    )
    $ corrupt "One TaskJuggler actuals invocation contains inconsistent observation custody."
  unless (all ((< observedEffortActualAsOf payload) . effortActualAsOf) priorForManifest) $
    corrupt "TaskJuggler actual observations must advance monotonically for one planning manifest."
  let evidence =
        EffortActualEvidence
          (persistedEventId event)
          (observedEffortActualBrick payload)
          (observedEffortActualRaw payload)
          (observedEffortActualImportInvocation payload)
          (observedEffortActualPlanningManifestDigest payload)
          (observedEffortActualTaskId payload)
          (observedEffortActualAsOf payload)
          completed
          remaining
          (persistedRecordedAt event)
  pure . bump $ state{stateEffortActualEvidence = Map.insert (persistedEventId event) evidence (stateEffortActualEvidence state)}
 where
  completed = observedEffortActualCompletedMicrohours payload
  remaining = observedEffortActualRemainingMicrohours payload
  expectedExternalIdentity =
    "manifest:"
      <> observedEffortActualPlanningManifestDigest payload
      <> "@"
      <> Text.pack (formatTime defaultTimeLocale "%Y-%m-%d-%H:%MZ" (observedEffortActualAsOf payload))
  validDigest digest = Text.length digest == 64 && Text.all lowerHex digest
  lowerHex character = isAscii character && (isDigit character || (character >= 'a' && character <= 'f'))

requireActiveBrick :: State -> UUIDv7 -> Either AppError Brick
requireActiveBrick state identity = do
  brick <- requireBrick state identity
  unless (brickStatus brick == BrickActive) $ corrupt "A current judgment requires active Work."
  pure brick

isActiveDirected :: PairJudgment -> Bool
isActiveDirected judgment = judgmentStatus judgment == JudgmentCurrent && judgmentRelation judgment == MoreThan

reorderBricks :: State -> Maybe UUIDv7 -> [UUIDv7] -> State
reorderBricks state _parent ordered =
  state
    { stateBricks =
        foldl
          (\bricks (position, identity) -> Map.adjust (\brick -> brick{brickSiblingPosition = position}) identity bricks)
          (stateBricks state)
          (zip [0 ..] ordered)
    }
applyBrickFocused :: State -> BrickFocused -> Either AppError State
applyBrickFocused state payload = do
  brick <- requireBrick state (focusedBrickId payload)
  unless (brickStatus brick == BrickActive) $ corrupt "Only active Work can receive focus."
  let bricks = Map.adjust (\current -> current{brickWorkState = Wip}) (brickId brick) (stateBricks state)
  Right . bump $ state{stateBricks = bricks, stateCurrentFocus = Just (brickId brick), stateActiveSprint = Nothing, stateLastRedo = Nothing}

applyBrickCompleted :: State -> BrickCompleted -> Either AppError State
applyBrickCompleted state payload = do
  brick <- requireBrick state (completedBrickId payload)
  unless (brickStatus brick == BrickActive) $ corrupt "Only active Work can be completed."
  let bricks = Map.adjust (\current -> current{brickStatus = BrickDone, brickWorkState = Idle}) (brickId brick) (stateBricks state)
      focus = if stateCurrentFocus state == Just (brickId brick) then Nothing else stateCurrentFocus state
  let sprint = case stateActiveSprint state of
        Just current | activeSprintBrick current == brickId brick -> Nothing
        other -> other
  Right . bump $ state{stateBricks = bricks, stateCurrentFocus = focus, stateActiveSprint = sprint, stateLastRedo = Nothing}

validateTarget :: State -> RawLinkTarget -> Either AppError ()
validateTarget state = \case
  RawLinkBrick identity -> void (requireBrick state identity)
  RawLinkListEntry identity ->
    unless (Map.member identity (stateListEntries state)) (corrupt "A RawLink references a missing ListEntry.")
  RawLinkRaw identity -> void (requireRaw state identity)

validateRoleCardinality :: State -> RawLinkAdded -> Either AppError ()
validateRoleCardinality state payload
  | addedRawLinkRole payload /= DescriptionRole = Right ()
  | otherwise = do
      case addedRawLinkTarget payload of
        RawLinkBrick _ -> pure ()
        _ -> corrupt "A description RawLink must target one Brick."
      let descriptions = filter ((== DescriptionRole) . rawLinkRole) (Map.elems (stateRawLinks state))
      when (any ((== addedRawId payload) . rawLinkRaw) descriptions) $ corrupt "A Raw already describes another Brick."
      when (any ((== addedRawLinkTarget payload) . rawLinkTarget) descriptions) $ corrupt "A Brick already has a description Raw."

validateDisposition :: State -> UUIDv7 -> RawDisposition -> Either AppError ()
validateDisposition state source = \case
  RawKeptStandalone -> Right ()
  RawGroupedAsDuplicate root -> do
    _ <- requireRaw state root
    when (source == root) $ corrupt "A Raw cannot be a duplicate receipt of itself."
    unless (hasLink DuplicateOfRole (RawLinkRaw root)) $ corrupt "A duplicate disposition requires its duplicate_of RawLink."
  RawMaterializedAsWork target -> do
    _ <- requireBrick state target
    unless (hasLink MaterializationSourceRole (RawLinkBrick target)) $ corrupt "A Work disposition requires its materialization-source RawLink."
  RawMaterializedAsListEntry owner entry -> do
    _ <- requireBrick state owner
    unless (Map.member entry (stateListEntries state)) $ corrupt "A ListEntry disposition references a missing entry."
    unless (hasLink MaterializationSourceRole (RawLinkListEntry entry)) $ corrupt "A ListEntry disposition requires its materialization-source RawLink."
  RawPlacedOnShelf shelf -> case Map.lookup shelf (stateRawShelves state) of
    Nothing -> corrupt "A shelf disposition references a missing RawShelf."
    Just rawShelf -> unless (source `elem` rawShelfMembers rawShelf) (corrupt "A shelf disposition requires direct RawShelf membership.")
  RawAttachedTo target role -> do
    _ <- requireBrick state target
    unless (hasLink role (RawLinkBrick target)) $ corrupt "An attachment disposition requires its RawLink."
 where
  hasLink role target =
    any
      (\link -> rawLinkRaw link == source && rawLinkRole link == role && rawLinkTarget link == target)
      (Map.elems (stateRawLinks state))

requireRaw :: State -> UUIDv7 -> Either AppError Raw
requireRaw state identity = maybe (corrupt "An event references a missing Raw.") Right (Map.lookup identity (stateRaws state))

requireBrick :: State -> UUIDv7 -> Either AppError Brick
requireBrick state identity = maybe (corrupt "An event references a missing Brick.") Right (Map.lookup identity (stateBricks state))

requireFeedEffect :: State -> UUIDv7 -> Either AppError CommandEffect
requireFeedEffect state identity = maybe (corrupt "An event references a missing command group.") Right (Map.lookup identity (stateCommandEffects state))

bump :: State -> State
bump state = state{stateEventCount = stateEventCount state + 1}

corrupt :: Text -> Either AppError value
corrupt = Left . appError CorruptData

instance ToJSON PersistedEvent where
  toJSON event = object (eventPairs event)
  toEncoding event = pairs (mconcat (eventSeries event))

eventPairs :: PersistedEvent -> [Pair]
eventPairs event =
  [ "schema" .= ("little-ant/event@1" :: Text)
  , "event_type" .= eventTypeName (persistedPayload event)
  , "event_version" .= eventVersionNumber (persistedPayload event)
  , "event_id" .= renderUUIDv7 (persistedEventId event)
  , "command_id" .= renderUUIDv7 (persistedCommandId event)
  , "segment_sequence" .= persistedSegmentSequence event
  , "event_sequence" .= persistedEventSequence event
  , "actor" .= persistedActor event
  , "recorded_at" .= persistedRecordedAt event
  , "previous_segment_hash" .= persistedPreviousSegmentHash event
  , "precondition_hash" .= persistedPreconditionHash event
  , "replay_facts" .= replayFactsValue event
  , "payload" .= payloadValue (persistedPayload event)
  ]

eventSeries :: PersistedEvent -> [Series]
eventSeries event =
  [ "schema" .= ("little-ant/event@1" :: Text)
  , "event_type" .= eventTypeName (persistedPayload event)
  , "event_version" .= eventVersionNumber (persistedPayload event)
  , "event_id" .= renderUUIDv7 (persistedEventId event)
  , "command_id" .= renderUUIDv7 (persistedCommandId event)
  , "segment_sequence" .= persistedSegmentSequence event
  , "event_sequence" .= persistedEventSequence event
  , "actor" .= persistedActor event
  , "recorded_at" .= persistedRecordedAt event
  , "previous_segment_hash" .= persistedPreviousSegmentHash event
  , "precondition_hash" .= persistedPreconditionHash event
  , "replay_facts" .= replayFactsValue event
  , "payload" .= payloadValue (persistedPayload event)
  ]

replayFactsValue :: PersistedEvent -> Value
replayFactsValue event = object ["allocated_uuids" .= fmap renderUUIDv7 (persistedReplayUUIDs event)]

payloadValue :: EventPayload -> Value
payloadValue = \case
  RawFedV1 payload ->
    object $ ["raw_id" .= uuid (fedRawId payload), "handle" .= unHandle (fedHandle payload), "original" .= fedOriginal payload, "origin" .= fedOrigin payload] <> maybe [] (pure . ("content" .=) . rawContentValue) (fedContent payload)
  RawContentRevisionAppendedV1 payload ->
    object ["raw_id" .= uuid (appendedRawRevisionRaw payload), "ordinal" .= appendedRawRevisionOrdinal payload, "provenance" .= appendedRawRevisionProvenance payload, "content" .= rawContentValue (appendedRawRevisionContent payload), "digest" .= appendedRawRevisionDigest payload]
  EnglishNormalizationAcceptedV1 payload ->
    object $ ["revision_id" .= uuid (acceptedNormalizationRevision payload), "text" .= acceptedNormalizationText payload, "source" .= normalizationSourceText (acceptedNormalizationSource payload)] <> maybe [] (pure . ("producer" .=)) (acceptedNormalizationProducer payload) <> maybe [] (pure . ("confidence" .=) . unFixed) (acceptedNormalizationConfidence payload)
  BrickTitleNormalizationAcceptedV1 payload ->
    object $ ["brick_id" .= uuid (acceptedTitleNormalizationBrick payload), "previous" .= acceptedTitleNormalizationPrevious payload, "current" .= acceptedTitleNormalizationCurrent payload, "source" .= normalizationSourceText (acceptedTitleNormalizationSource payload)] <> maybe [] (pure . ("producer" .=)) (acceptedTitleNormalizationProducer payload) <> maybe [] (pure . ("confidence" .=) . unFixed) (acceptedTitleNormalizationConfidence payload)
  ImportProfileChangedV1 payload -> importProfileValue (changedImportProfile payload)
  ImportInvocationRecordedV1 payload -> importInvocationValue (recordedImportInvocation payload)
  SourceBindingChangedV1 payload -> sourceBindingValue (changedSourceBinding payload)
  SourceObservationRecordedV1 payload ->
    object $ ["binding_id" .= uuid (recordedSourceObservationBinding payload), "locator" .= recordedSourceObservationLocator payload, "outcome" .= sourceObservationOutcomeText (recordedSourceObservationOutcome payload)] <> maybe [] (pure . ("provider_version" .=)) (recordedSourceObservationProviderVersion payload) <> maybe [] (pure . ("fingerprint" .=)) (recordedSourceObservationFingerprint payload) <> maybe [] (pure . ("snapshot_digest" .=)) (recordedSourceObservationSnapshotDigest payload) <> maybe [] (pure . ("snapshot" .=) . rawContentValue) (recordedSourceObservationSnapshot payload)
  SourceObservationReconciledV1 payload ->
    object ["observation_id" .= uuid (reconciledSourceObservation payload), "disposition" .= sourceReconciliationDispositionValue (reconciledSourceDisposition payload)]
  RawFeedRetractedV1 payload ->
    object ["raw_id" .= uuid (retractedRawId payload), "feed_command_id" .= uuid (retractedFeedCommandId payload)]
  RawFeedRestoredV1 payload ->
    object
      [ "raw_id" .= uuid (restoredRawId payload)
      , "feed_command_id" .= uuid (restoredFeedCommandId payload)
      , "retraction_command_id" .= uuid (restoredRetractionCommandId payload)
      ]
  BrickCreatedV1 payload ->
    object $
      [ "brick_id" .= uuid (createdBrickId payload)
      , "handle" .= unHandle (createdBrickHandle payload)
      , "title" .= createdBrickTitle payload
      , "nature" .= natureText (createdBrickNature payload)
      , "nature_version" .= createdNatureVersion payload
      , "nature_source" .= createdNatureSource payload
      , "domains" .= fmap uuid (Set.toAscList (createdDomains payload))
      , "sibling_position" .= createdSiblingPosition payload
      , "importance_confidence" .= confidenceValue (createdImportanceConfidence payload)
      , "source_raw_id" .= uuid (createdSourceRawId payload)
      ]
        <> maybe [] (pure . ("template" .=) . templateValue) (createdTemplate payload)
        <> maybe [] (pure . ("parent_id" .=) . renderUUIDv7) (createdParent payload)
  BrickNatureChangedV1 payload ->
    object
      [ "brick_id" .= uuid (natureChangedBrick payload)
      , "from" .= natureText (natureChangedFrom payload)
      , "to" .= natureText (natureChangedTo payload)
      , "source" .= natureChangedSource payload
      ]
  BrickChildCreatedV1 payload ->
    object
      [ "brick_id" .= uuid (createdChildId payload)
      , "handle" .= unHandle (createdChildHandle payload)
      , "title" .= createdChildTitle payload
      , "nature" .= natureText (createdChildNature payload)
      , "nature_version" .= createdChildNatureVersion payload
      , "nature_source" .= createdChildNatureSource payload
      , "parent_id" .= uuid (createdChildParent payload)
      , "sibling_position" .= createdChildSiblingPosition payload
      , "importance_confidence" .= confidenceValue (createdChildImportanceConfidence payload)
      ]
  LazyReviewRequestedV1 payload ->
    object
      [ "subject_id" .= uuid (requestedReviewSubject payload)
      , "kind" .= requestedReviewKind payload
      , "reason" .= requestedReviewReason payload
      ]
  LazyReviewSettledV1 payload ->
    object
      [ "review_id" .= uuid (settledReviewId payload)
      , "outcome" .= settledReviewOutcome payload
      ]
  BrickStatusChangedV1 payload ->
    object
      [ "brick_id" .= uuid (statusChangedBrick payload)
      , "from" .= brickStatusText (statusChangedFrom payload)
      , "to" .= brickStatusText (statusChangedTo payload)
      , "reason" .= statusChangedReason payload
      ]
  RawLinkAddedV1 payload ->
    object
      [ "raw_link_id" .= uuid (addedRawLinkId payload)
      , "raw_id" .= uuid (addedRawId payload)
      , "target" .= rawLinkTargetValue (addedRawLinkTarget payload)
      , "role" .= roleText (addedRawLinkRole payload)
      ]
  RawDispositionAcceptedV1 payload ->
    object ["raw_id" .= uuid (dispositionRawId payload), "disposition" .= dispositionValue (acceptedRawDisposition payload)]
  RawTriageDeferredV1 payload -> object ["raw_id" .= uuid (deferredRawId payload), "count" .= deferredCount payload]
  RawShelfCreatedV1 payload -> object ["shelf_id" .= uuid (createdRawShelfId payload), "name" .= createdRawShelfName payload, "source_raw_id" .= uuid (createdRawShelfSourceRaw payload)]
  RawShelfMemberAddedV1 payload -> object ["shelf_id" .= uuid (memberRawShelfId payload), "raw_id" .= uuid (memberRawId payload), "ordinal" .= memberRawOrdinal payload]
  RawDuplicateRejectedV1 payload ->
    object
      [ "candidate_raw_id" .= uuid (duplicateCandidateRawId payload)
      , "compared_raw_id" .= uuid (duplicateComparedRawId payload)
      , "candidate_revision" .= duplicateCandidateRevision payload
      , "compared_revision" .= duplicateComparedRevision payload
      ]
  ListEntryCreatedV1 payload ->
    object ["entry_id" .= uuid (createdListEntryId payload), "owner_id" .= uuid (createdListEntryOwner payload), "label" .= createdListEntryLabel payload, "quantity" .= quantityValue (createdListEntryQuantity payload), "ordinal" .= createdListEntryOrdinal payload, "source_raw_id" .= uuid (createdListEntrySourceRaw payload)]
  ListEntryQuantityChangedV1 payload ->
    object ["entry_id" .= uuid (changedListEntryId payload), "source_raw_id" .= uuid (changedListEntrySourceRaw payload), "previous_quantity" .= quantityValue (previousListEntryQuantity payload), "current_quantity" .= quantityValue (currentListEntryQuantity payload)]
  ListEntryStateChangedV1 payload ->
    object
      [ "entry_id" .= uuid (stateChangedListEntryId payload)
      , "run_id" .= uuid (stateChangedChecklistRunId payload)
      , "from" .= listEntryStateText (previousListEntryState payload)
      , "to" .= listEntryStateText (currentListEntryState payload)
      ]
  ChecklistRunStartedV1 payload ->
    object ["run_id" .= uuid (startedChecklistRunId payload), "owner_id" .= uuid (startedChecklistOwner payload)]
  ChecklistRunFinishedV1 payload ->
    object ["run_id" .= uuid (finishedChecklistRunId payload), "owner_id" .= uuid (finishedChecklistOwner payload)]
  TemporalConstraintsChangedV1 payload ->
    object $
      [ "brick_id" .= uuid (changedTemporalBrick payload)
      , "revision" .= changedTemporalRevision payload
      ]
        <> maybe [] (pure . ("not_before" .=) . zonedInstantValue) (changedTemporalNotBefore payload)
        <> maybe [] (pure . ("best_before" .=) . zonedInstantValue) (changedTemporalBestBefore payload)
        <> maybe [] (pure . ("deadline" .=) . zonedInstantValue) (changedTemporalDeadline payload)
  StandingOutcomeRecordedV1 payload ->
    object ["owner_id" .= uuid (recordedStandingOwner payload), "outcome" .= standingOutcomeText (recordedStandingOutcome payload)]
  RepeatableReturnSetV1 payload ->
    object $
      [ "owner_id" .= uuid (repeatableReturnOwner payload)
      , "policy" .= returnPolicyValue (repeatableReturnPolicy payload)
      ]
        <> maybe [] (pure . ("chosen_offset" .=)) (repeatableReturnChosenOffset payload)
        <> maybe [] (pure . ("not_before" .=) . zonedInstantValue) (repeatableReturnNotBefore payload)
        <> maybe [] (pure . ("resolution" .=)) (repeatableReturnResolution payload)
        <> maybe [] (pure . ("seed" .=) . TextEncoding.decodeUtf8 . Base16.encode) (repeatableReturnSeed payload)
        <> maybe [] (pure . ("draw" .=) . forecastDrawValue) (repeatableReturnDraw payload)
  ScheduledIntervalSetV1 payload ->
    object
      [ "owner_id" .= uuid (intervalSetOwner payload)
      , "starts_at" .= zonedInstantValue (intervalSetStartsAt payload)
      , "ends_at" .= zonedInstantValue (intervalSetEndsAt payload)
      , "revision" .= intervalSetRevision payload
      ]
  RecurrenceScheduleSetV1 payload -> recurrenceScheduleValue (setRecurrenceSchedule payload)
  RecurringOccurrenceReleasedV1 payload ->
    object $
      [ "occurrence" .= recurringOccurrenceValue (releasedOccurrence payload)
      , "handle" .= unHandle (releasedOccurrenceHandle payload)
      , "title" .= releasedOccurrenceTitle payload
      , "nature" .= natureText (releasedOccurrenceNature payload)
      , "domains" .= fmap uuid (Set.toAscList (releasedOccurrenceDomains payload))
      , "sibling_position" .= releasedOccurrencePosition payload
      , "temporal" .= temporalConstraintsValue (releasedOccurrenceTemporal payload)
      ]
        <> maybe [] (pure . ("interval" .=) . scheduledIntervalValue) (releasedOccurrenceInterval payload)
  HabitScheduleSetV1 payload -> habitScheduleValue (setHabitSchedule payload)
  HabitWindowOpenedV1 payload -> habitWindowValue (openedHabitWindow payload)
  HabitWindowOutcomeRecordedV1 payload ->
    object
      [ "outcome_id" .= uuid (recordedHabitWindowOutcomeId payload)
      , "window_id" .= uuid (recordedHabitWindowId payload)
      , "owner_id" .= uuid (recordedHabitWindowOwner payload)
      , "outcome" .= standingOutcomeText (recordedHabitWindowOutcome payload)
      ]
  NoticeDispositionChangedV1 payload ->
    object
      [ "notice" .= noticeIdentityValue (changedNoticeIdentity payload)
      , "disposition" .= noticeDispositionValue (changedNoticeDisposition payload)
      ]
  OperationalDayConfigChangedV1 payload -> operationalDayConfigValue (changedOperationalDayConfig payload)
  ImportanceComparedV1 payload ->
    object ["above" .= uuid (comparedAbove payload), "below" .= uuid (comparedBelow payload), "source" .= comparisonSource payload]
  ImportancePlacementMarkedV1 payload ->
    object ["brick_id" .= uuid (markedImportanceBrick payload), "confidence" .= confidenceValue (markedImportanceConfidence payload), "reason" .= markedImportanceReason payload]
  PairJudgmentRecordedV1 payload ->
    object
      [ "judgment_id" .= uuid (recordedJudgmentId payload)
      , "axis" .= axisText (recordedJudgmentAxis payload)
      , "first" .= uuid (recordedJudgmentFirst payload)
      , "second" .= uuid (recordedJudgmentSecond payload)
      , "relation" .= relationText (recordedJudgmentRelation payload)
      , "provenance" .= provenanceValue (recordedJudgmentProvenance payload)
      , "initial_confidence" .= unFixed (recordedJudgmentInitialConfidence payload)
      , "profile_hash" .= recordedJudgmentProfileHash payload
      , "context" .= recordedJudgmentContext payload
      , "reason" .= recordedJudgmentReason payload
      , "status" .= judgmentStatusValue (recordedJudgmentStatus payload)
      , "retired_judgments" .= fmap uuid (recordedRetiredJudgments payload)
      ]
  PhaseChangedV1 payload ->
    object $
      [ "brick_id" .= uuid (changedPhaseBrick payload)
      , "provenance" .= provenanceValue (changedPhaseProvenance payload)
      ]
        <> maybe [] (pure . ("phase" .=) . phaseText) (changedPhaseValue payload)
  ImpactClassifiedV1 payload ->
    object $
      [ "brick_id" .= uuid (classifiedImpactBrick payload)
      , "maturity" .= impactMaturityText (classifiedImpactMaturity payload)
      , "evidence" .= fmap uuid (classifiedImpactEvidence payload)
      , "provenance" .= provenanceValue (classifiedImpactProvenance payload)
      , "profile_hash" .= classifiedImpactProfileHash payload
      ]
        <> maybe [] (pure . ("class" .=) . impactClassText) (classifiedImpactClass payload)
  EffortClassifiedV1 payload ->
    object $
      [ "brick_id" .= uuid (classifiedEffortBrick payload)
      , "provenance" .= provenanceValue (classifiedEffortProvenance payload)
      , "profile_hash" .= classifiedEffortProfileHash payload
      ]
        <> maybe [] (pure . ("class" .=) . effortClassText) (classifiedEffortClass payload)
  EffortActualObservedV1 payload ->
    object $
      [ "brick_id" .= uuid (observedEffortActualBrick payload)
      , "raw_id" .= uuid (observedEffortActualRaw payload)
      , "import_invocation_id" .= uuid (observedEffortActualImportInvocation payload)
      , "planning_manifest_sha256" .= observedEffortActualPlanningManifestDigest payload
      , "task_id" .= observedEffortActualTaskId payload
      , "as_of" .= observedEffortActualAsOf payload
      ]
        <> maybe [] (pure . ("completed_microhours" .=) . Text.pack . show) (observedEffortActualCompletedMicrohours payload)
        <> maybe [] (pure . ("remaining_microhours" .=) . Text.pack . show) (observedEffortActualRemainingMicrohours payload)
  BrickFocusedV1 payload -> object ["brick_id" .= uuid (focusedBrickId payload)]
  BrickCompletedV1 payload -> object ["brick_id" .= uuid (completedBrickId payload)]
  ForecastSelectedV1 payload -> forecastSelectionValue (selectedForecastEvidence payload)
  ForecastFocusAcceptedV1 payload ->
    object $
      [ "selection_id" .= uuid (acceptedForecastSelection payload)
      , "brick_id" .= uuid (acceptedForecastBrick payload)
      ]
        <> maybe [] (pure . ("active_domain_id" .=) . renderUUIDv7) (acceptedForecastDomain payload)
  WorkReactionRecordedV1 payload ->
    object $
      [ "brick_id" .= uuid (recordedWorkReactionBrick payload)
      , "symptom" .= skipSymptomValue (recordedWorkReactionSymptom payload)
      , "reaction" .= skipReactionValue (recordedWorkReaction payload)
      ]
        <> maybe [] (pure . ("selection_id" .=) . renderUUIDv7) (recordedWorkReactionSelection payload)
        <> maybe [] (pure . ("cooldown_until" .=)) (recordedWorkReactionCooldownUntil payload)
  FocusPausedV1 payload -> object ["brick_id" .= uuid (pausedFocusBrick payload)]
  SprintStartedV1 payload ->
    object
      [ "brick_id" .= uuid (sprintStartedBrick payload)
      , "minutes" .= sprintStartedMinutes payload
      , "ends_at" .= sprintStartedEndsAt payload
      ]
  DependencyAddedV1 payload ->
    object
      [ "dependency_id" .= uuid (addedDependencyId payload)
      , "blocked_brick_id" .= uuid (addedDependencyBlockedBrick payload)
      , "blocker_brick_id" .= uuid (addedDependencyBlockerBrick payload)
      , "source" .= addedDependencySource payload
      ]
  DependencyResolvedV1 payload ->
    object ["dependency_id" .= uuid (resolvedDependencyId payload)]
  DomainFocusChangedV1 payload ->
    object $
      ["mode" .= changedDomainFocusMode payload]
        <> maybe [] (pure . ("domain_id" .=) . renderUUIDv7) (changedDomainFocusTarget payload)
  ExternalEntityRegisteredV1 payload -> externalEntityValue (registeredExternalEntity payload)
  ContactPointRegisteredV1 payload -> contactPointValue' (registeredContactPoint payload)
  WaitChangedV1 payload -> object ["wait" .= waitGateValue (changedWaitGate payload), "observation" .= waitObservationValue (changedWaitObservation payload)]
  WaitSuccessorDeclaredV1 payload -> object ["successor" .= waitSuccessorValue (declaredWaitSuccessor payload)]
  DelegationChangedV1 payload -> delegationValue (changedDelegation payload)
  ExternalEffectChangedV1 payload -> externalEffectValue (changedExternalEffect payload)
  ExternalEffectApprovalGrantedV1 payload -> externalEffectApprovalGrantValue (grantedExternalEffectApproval payload)
  ExternalEffectReceiptRecordedV1 payload -> externalEffectReceiptValue (recordedExternalEffectReceipt payload)
 where
  uuid = renderUUIDv7

forecastSelectionValue :: ForecastSelectionEvidence -> Value
forecastSelectionValue evidence =
  object $
    [ "selection_id" .= renderUUIDv7 (forecastSelectionId evidence)
    , "profile_hash" .= forecastSelectionProfileHash evidence
    , "seed" .= TextEncoding.decodeUtf8 (Base16.encode (forecastSelectionSeed evidence))
    , "admitted" .= fmap admittedValue (forecastSelectionAdmitted evidence)
    , "original_subject" .= renderUUIDv7 (forecastSelectionOriginalSubject evidence)
    , "opportunity_kind" .= forecastSelectionOpportunityKind evidence
    , "dependency_path" .= fmap renderUUIDv7 (forecastSelectionDependencyPath evidence)
    , "additional_signals" .= forecastSelectionAdditionalSignals evidence
    , "draws" .= fmap forecastDrawValue (forecastSelectionDraws evidence)
    ]
      <> maybe [] (pure . ("endpoint_subject" .=) . renderUUIDv7) (forecastSelectionEndpointSubject evidence)
      <> maybe [] (pure . ("domain_path" .=) . fmap renderUUIDv7) (forecastSelectionDomainPath evidence)
      <> maybe [] (pure . ("strongest_signal" .=)) (forecastSelectionStrongestSignal evidence)
 where
  admittedValue (identity, weight) = object ["subject_id" .= renderUUIDv7 identity, "weight" .= weight]
  candidateValue (identity, weight) = object ["identity" .= identity, "weight" .= weight]

forecastDrawValue :: ForecastDrawEvidence -> Value
forecastDrawValue draw =
  object
    [ "purpose" .= forecastDrawPurpose draw
    , "candidates" .= fmap candidateValue (forecastDrawCandidates draw)
    , "total" .= forecastDrawTotal draw
    , "starting_cursor" .= forecastDrawStartingCursor draw
    , "ending_cursor" .= forecastDrawEndingCursor draw
    , "sampled_integer" .= forecastDrawSampledInteger draw
    , "chosen_identity" .= forecastDrawChosenIdentity draw
    ]
 where
  candidateValue (identity, weight) = object ["identity" .= identity, "weight" .= weight]

instance FromJSON PersistedEvent where
  parseJSON = withObject "Little Ant event" $ \value -> do
    schema <- value .: "schema"
    when (schema /= ("little-ant/event@1" :: Text)) $
      fail (if "little-ant/event@" `Text.isPrefixOf` schema then "unknown event schema version" else "invalid event schema")
    eventType <- value .: "event_type"
    eventVersion <- value .: "event_version"
    payload <- value .: "payload" >>= parsePayload eventType eventVersion
    PersistedEvent
      <$> (value .: "event_id" >>= parseUuidField)
      <*> (value .: "command_id" >>= parseUuidField)
      <*> value .: "segment_sequence"
      <*> value .: "event_sequence"
      <*> value .: "actor"
      <*> value .: "recorded_at"
      <*> value .: "previous_segment_hash"
      <*> value .: "precondition_hash"
      <*> (value .: "replay_facts" >>= withObject "replay facts" (\facts -> facts .: "allocated_uuids" >>= traverse parseUuidField))
      <*> pure payload

parsePayload :: Text -> Int -> Value -> Parser EventPayload
parsePayload eventType version payload = case (eventType, version) of
  ("raw_fed", 1) -> RawFedV1 <$> parseRawFedV1 payload
  ("raw_fed", 0) -> RawFedV1 <$> parseRawFedV0 payload
  ("raw_content_revision_appended", 1) -> RawContentRevisionAppendedV1 <$> parseRawContentRevisionAppended payload
  ("english_normalization_accepted", 1) -> EnglishNormalizationAcceptedV1 <$> parseEnglishNormalizationAccepted payload
  ("brick_title_normalization_accepted", 1) -> BrickTitleNormalizationAcceptedV1 <$> parseBrickTitleNormalizationAccepted payload
  ("import_profile_changed", 1) -> ImportProfileChangedV1 . ImportProfileChanged <$> parseImportProfile payload
  ("import_invocation_recorded", 1) -> ImportInvocationRecordedV1 . ImportInvocationRecorded <$> parseImportInvocation payload
  ("source_binding_changed", 1) -> SourceBindingChangedV1 . SourceBindingChanged <$> parseSourceBinding payload
  ("source_observation_recorded", 1) -> SourceObservationRecordedV1 <$> parseSourceObservationRecorded payload
  ("source_observation_reconciled", 1) -> SourceObservationReconciledV1 <$> parseSourceObservationReconciled payload
  ("raw_feed_retracted", 1) -> RawFeedRetractedV1 <$> parseRetraction payload
  ("raw_feed_restored", 1) -> RawFeedRestoredV1 <$> parseRestoration payload
  ("brick_created", 1) -> BrickCreatedV1 <$> parseBrickCreated payload
  ("brick_nature_changed", 1) ->
    BrickNatureChangedV1
      <$> withObject
        "brick_nature_changed@1"
        ( \value ->
            BrickNatureChanged
              <$> (value .: "brick_id" >>= parseId)
              <*> (value .: "from" >>= parseNature)
              <*> (value .: "to" >>= parseNature)
              <*> value .: "source"
        )
        payload
  ("lazy_review_settled", 1) ->
    LazyReviewSettledV1
      <$> withObject
        "lazy_review_settled@1"
        (\value -> LazyReviewSettled <$> (value .: "review_id" >>= parseId) <*> value .: "outcome")
        payload
  ("brick_status_changed", 1) ->
    BrickStatusChangedV1
      <$> withObject
        "brick_status_changed@1"
        ( \value ->
            BrickStatusChanged
              <$> (value .: "brick_id" >>= parseId)
              <*> (value .: "from" >>= parseBrickStatus)
              <*> (value .: "to" >>= parseBrickStatus)
              <*> value .: "reason"
        )
        payload
  ("dependency_added", 1) ->
    DependencyAddedV1
      <$> withObject
        "dependency_added@1"
        (\value -> DependencyAdded <$> (value .: "dependency_id" >>= parseId) <*> (value .: "blocked_brick_id" >>= parseId) <*> (value .: "blocker_brick_id" >>= parseId) <*> value .: "source")
        payload
  ("dependency_resolved", 1) ->
    DependencyResolvedV1
      <$> withObject "dependency_resolved@1" (\value -> DependencyResolution <$> (value .: "dependency_id" >>= parseId)) payload
  ("domain_focus_changed", 1) ->
    DomainFocusChangedV1
      <$> withObject
        "domain_focus_changed@1"
        (\value -> DomainFocusChanged <$> (value .:? "domain_id" >>= traverse parseId) <*> value .: "mode")
        payload
  ("brick_child_created", 1) ->
    BrickChildCreatedV1
      <$> withObject
        "brick_child_created@1"
        ( \value ->
            BrickChildCreated
              <$> (value .: "brick_id" >>= parseId)
              <*> (Handle <$> value .: "handle")
              <*> value .: "title"
              <*> (value .: "nature" >>= parseNature)
              <*> value .: "nature_version"
              <*> value .: "nature_source"
              <*> (value .: "parent_id" >>= parseId)
              <*> value .: "sibling_position"
              <*> (value .: "importance_confidence" >>= parseConfidence)
        )
        payload
  ("lazy_review_requested", 1) ->
    LazyReviewRequestedV1
      <$> withObject
        "lazy_review_requested@1"
        ( \value ->
            LazyReviewRequested
              <$> (value .: "subject_id" >>= parseId)
              <*> value .: "kind"
              <*> value .: "reason"
        )
        payload
  ("raw_link_added", 1) -> RawLinkAddedV1 <$> parseRawLinkAdded payload
  ("raw_disposition_accepted", 1) -> RawDispositionAcceptedV1 <$> parseDispositionAccepted payload
  ("raw_triage_deferred", 1) -> RawTriageDeferredV1 <$> parseTriageDeferred payload
  ("raw_shelf_created", 1) -> RawShelfCreatedV1 <$> parseRawShelfCreated payload
  ("raw_shelf_member_added", 1) -> RawShelfMemberAddedV1 <$> parseRawShelfMemberAdded payload
  ("raw_duplicate_rejected", 1) -> RawDuplicateRejectedV1 <$> parseDuplicateRejected payload
  ("list_entry_created", 1) -> ListEntryCreatedV1 <$> parseListEntryCreated payload
  ("list_entry_quantity_changed", 1) -> ListEntryQuantityChangedV1 <$> parseListEntryQuantityChanged payload
  ("list_entry_state_changed", 1) -> ListEntryStateChangedV1 <$> parseListEntryStateChanged payload
  ("checklist_run_started", 1) -> ChecklistRunStartedV1 <$> parseChecklistRunStarted payload
  ("checklist_run_finished", 1) -> ChecklistRunFinishedV1 <$> parseChecklistRunFinished payload
  ("temporal_constraints_changed", 1) -> TemporalConstraintsChangedV1 <$> parseTemporalConstraintsChanged payload
  ("standing_outcome_recorded", 1) -> StandingOutcomeRecordedV1 <$> parseStandingOutcomeRecorded payload
  ("repeatable_return_set", 1) -> RepeatableReturnSetV1 <$> parseRepeatableReturnSet payload
  ("scheduled_interval_set", 1) -> ScheduledIntervalSetV1 <$> parseScheduledIntervalSet payload
  ("recurrence_schedule_set", 1) -> RecurrenceScheduleSetV1 . RecurrenceScheduleSet <$> parseRecurrenceSchedule payload
  ("recurring_occurrence_released", 1) -> RecurringOccurrenceReleasedV1 <$> parseRecurringOccurrenceReleased payload
  ("habit_schedule_set", 1) -> HabitScheduleSetV1 . HabitScheduleSet <$> parseHabitSchedule payload
  ("habit_window_opened", 1) -> HabitWindowOpenedV1 . HabitWindowOpened <$> parseHabitWindow payload
  ("habit_window_outcome_recorded", 1) -> HabitWindowOutcomeRecordedV1 <$> parseHabitWindowOutcomeRecorded payload
  ("notice_disposition_changed", 1) -> NoticeDispositionChangedV1 <$> parseNoticeDispositionChanged payload
  ("operational_day_config_changed", 1) -> OperationalDayConfigChangedV1 . OperationalDayConfigChanged <$> parseOperationalDayConfig payload
  ("importance_compared", 1) -> ImportanceComparedV1 <$> parseImportanceCompared payload
  ("importance_placement_marked", 1) -> ImportancePlacementMarkedV1 <$> parseImportancePlacementMarked payload
  ("pair_judgment_recorded", 1) -> PairJudgmentRecordedV1 <$> parsePairJudgmentRecorded payload
  ("phase_changed", 1) -> PhaseChangedV1 <$> parsePhaseChanged payload
  ("impact_classified", 1) -> ImpactClassifiedV1 <$> parseImpactClassified payload
  ("effort_classified", 1) -> EffortClassifiedV1 <$> parseEffortClassified payload
  ("effort_actual_observed", 1) -> EffortActualObservedV1 <$> parseEffortActualObserved payload
  ("brick_focused", 1) -> BrickFocusedV1 <$> withObject "brick_focused@1" (\value -> BrickFocused <$> (value .: "brick_id" >>= parseId)) payload
  ("brick_completed", 1) -> BrickCompletedV1 <$> withObject "brick_completed@1" (\value -> BrickCompleted <$> (value .: "brick_id" >>= parseId)) payload
  ("forecast_selected", 1) -> ForecastSelectedV1 . ForecastSelected <$> parseForecastSelection payload
  ("forecast_focus_accepted", 1) ->
    ForecastFocusAcceptedV1
      <$> withObject
        "forecast_focus_accepted@1"
        ( \value ->
            ForecastFocusAccepted
              <$> (value .: "selection_id" >>= parseId)
              <*> (value .: "brick_id" >>= parseId)
              <*> (value .:? "active_domain_id" >>= traverse parseId)
        )
        payload
  ("work_reaction_recorded", 1) ->
    WorkReactionRecordedV1
      <$> withObject
        "work_reaction_recorded@1"
        ( \value ->
            WorkReactionRecorded
              <$> (value .: "brick_id" >>= parseId)
              <*> (value .:? "selection_id" >>= traverse parseId)
              <*> (value .: "symptom" >>= parseSkipSymptom)
              <*> (value .: "reaction" >>= parseSkipReaction)
              <*> value .:? "cooldown_until"
        )
        payload
  ("focus_paused", 1) ->
    FocusPausedV1 <$> withObject "focus_paused@1" (\value -> FocusPaused <$> (value .: "brick_id" >>= parseId)) payload
  ("sprint_started", 1) ->
    SprintStartedV1
      <$> withObject
        "sprint_started@1"
        ( \value ->
            SprintStarted
              <$> (value .: "brick_id" >>= parseId)
              <*> value .: "minutes"
              <*> value .: "ends_at"
        )
        payload
  ("external_entity_registered", 1) -> ExternalEntityRegisteredV1 . ExternalEntityRegistered <$> parseExternalEntity payload
  ("contact_point_registered", 1) -> ContactPointRegisteredV1 . ContactPointRegistered <$> parseContactPoint payload
  ("wait_changed", 1) -> WaitChangedV1 <$> withObject "wait_changed@1" (\value -> WaitChanged <$> (value .: "wait" >>= parseWaitGate) <*> (value .: "observation" >>= parseWaitObservation)) payload
  ("wait_successor_declared", 1) -> WaitSuccessorDeclaredV1 <$> withObject "wait_successor_declared@1" (\value -> WaitSuccessorDeclared <$> (value .: "successor" >>= parseWaitSuccessor)) payload
  ("delegation_changed", 1) -> DelegationChangedV1 . DelegationChanged <$> parseDelegation payload
  ("external_effect_changed", 1) -> ExternalEffectChangedV1 . ExternalEffectChanged <$> parseExternalEffect payload
  ("external_effect_approval_granted", 1) -> ExternalEffectApprovalGrantedV1 . ExternalEffectApprovalGranted <$> parseExternalEffectApprovalGrant payload
  ("external_effect_receipt_recorded", 1) -> ExternalEffectReceiptRecordedV1 . ExternalEffectReceiptRecorded <$> parseExternalEffectReceipt payload
  (_, bad) -> fail ("unknown event version: " <> show bad <> " for " <> Text.unpack eventType)
 where
  parseRawFedV1 = withObject "raw_fed@1" $ \value -> RawFed <$> (value .: "raw_id" >>= parseId) <*> (Handle <$> value .: "handle") <*> value .: "original" <*> value .: "origin" <*> (value .:? "content" >>= traverse parseRawContent)
  parseForecastSelection = withObject "forecast_selected@1" $ \value ->
    ForecastSelectionEvidence
      <$> (value .: "selection_id" >>= parseId)
      <*> value .: "profile_hash"
      <*> (value .: "seed" >>= parseSeed)
      <*> (value .: "admitted" >>= traverse parseAdmitted)
      <*> (value .: "original_subject" >>= parseId)
      <*> (value .:? "endpoint_subject" >>= traverse parseId)
      <*> value .: "opportunity_kind"
      <*> (value .: "dependency_path" >>= traverse parseId)
      <*> (value .:? "domain_path" >>= traverse (traverse parseId))
      <*> value .:? "strongest_signal"
      <*> value .: "additional_signals"
      <*> (value .: "draws" >>= traverse parseForecastDraw)
  parseSeed encoded =
    case Base16.decode (TextEncoding.encodeUtf8 encoded) of
      Left _ -> fail "invalid forecast seed"
      Right bytes | ByteString.length bytes == 32 -> pure bytes
      Right _ -> fail "forecast seed must be 32 bytes"
  parseAdmitted = withObject "forecast admitted candidate" $ \value ->
    (,) <$> (value .: "subject_id" >>= parseId) <*> value .: "weight"
  parseForecastDraw = withObject "forecast draw" $ \value ->
    ForecastDrawEvidence
      <$> value .: "purpose"
      <*> (value .: "candidates" >>= traverse parseDrawCandidate)
      <*> value .: "total"
      <*> value .: "starting_cursor"
      <*> value .: "ending_cursor"
      <*> value .: "sampled_integer"
      <*> value .: "chosen_identity"
  parseDrawCandidate = withObject "forecast draw candidate" $ \value ->
    (,) <$> value .: "identity" <*> value .: "weight"
  parseRawFedV0 = withObject "raw_fed@0" $ \value -> RawFed <$> (value .: "id" >>= parseId) <*> (Handle <$> value .: "handle") <*> value .: "content" <*> pure "cli" <*> pure Nothing
  parseRetraction = withObject "raw_feed_retracted@1" $ \value -> RawFeedRetracted <$> (value .: "raw_id" >>= parseId) <*> (value .: "feed_command_id" >>= parseId)
  parseRestoration = withObject "raw_feed_restored@1" $ \value -> RawFeedRestored <$> (value .: "raw_id" >>= parseId) <*> (value .: "feed_command_id" >>= parseId) <*> (value .: "retraction_command_id" >>= parseId)
  parseBrickCreated = withObject "brick_created@1" $ \value ->
    BrickCreated
      <$> (value .: "brick_id" >>= parseId)
      <*> (Handle <$> value .: "handle")
      <*> value .: "title"
      <*> (value .: "nature" >>= parseNature)
      <*> value .: "nature_version"
      <*> value .: "nature_source"
      <*> (value .:? "template" >>= traverse parseTemplate)
      <*> (value .:? "parent_id" >>= traverse parseId)
      <*> (Set.fromList <$> (value .: "domains" >>= traverse parseId))
      <*> value .: "sibling_position"
      <*> (value .: "importance_confidence" >>= parseConfidence)
      <*> (value .: "source_raw_id" >>= parseId)
  parseRawLinkAdded = withObject "raw_link_added@1" $ \value ->
    RawLinkAdded <$> (value .: "raw_link_id" >>= parseId) <*> (value .: "raw_id" >>= parseId) <*> (value .: "target" >>= parseRawLinkTarget) <*> (value .: "role" >>= parseRole)
  parseDispositionAccepted = withObject "raw_disposition_accepted@1" $ \value -> RawDispositionAccepted <$> (value .: "raw_id" >>= parseId) <*> (value .: "disposition" >>= parseDisposition)
  parseTriageDeferred = withObject "raw_triage_deferred@1" $ \value -> RawTriageDeferred <$> (value .: "raw_id" >>= parseId) <*> value .: "count"
  parseRawShelfCreated = withObject "raw_shelf_created@1" $ \value -> RawShelfCreated <$> (value .: "shelf_id" >>= parseId) <*> value .: "name" <*> (value .: "source_raw_id" >>= parseId)
  parseRawShelfMemberAdded = withObject "raw_shelf_member_added@1" $ \value -> RawShelfMemberAdded <$> (value .: "shelf_id" >>= parseId) <*> (value .: "raw_id" >>= parseId) <*> value .: "ordinal"
  parseDuplicateRejected = withObject "raw_duplicate_rejected@1" $ \value -> RawDuplicateRejected <$> (value .: "candidate_raw_id" >>= parseId) <*> (value .: "compared_raw_id" >>= parseId) <*> value .: "candidate_revision" <*> value .: "compared_revision"
  parseListEntryCreated = withObject "list_entry_created@1" $ \value -> ListEntryCreated <$> (value .: "entry_id" >>= parseId) <*> (value .: "owner_id" >>= parseId) <*> value .: "label" <*> (value .: "quantity" >>= parseQuantity) <*> value .: "ordinal" <*> (value .: "source_raw_id" >>= parseId)
  parseListEntryQuantityChanged = withObject "list_entry_quantity_changed@1" $ \value -> ListEntryQuantityChanged <$> (value .: "entry_id" >>= parseId) <*> (value .: "source_raw_id" >>= parseId) <*> (value .: "previous_quantity" >>= parseQuantity) <*> (value .: "current_quantity" >>= parseQuantity)
  parseListEntryStateChanged = withObject "list_entry_state_changed@1" $ \value -> ListEntryStateChanged <$> (value .: "entry_id" >>= parseId) <*> (value .: "run_id" >>= parseId) <*> (value .: "from" >>= parseListEntryState) <*> (value .: "to" >>= parseListEntryState)
  parseChecklistRunStarted = withObject "checklist_run_started@1" $ \value -> ChecklistRunStarted <$> (value .: "run_id" >>= parseId) <*> (value .: "owner_id" >>= parseId)
  parseChecklistRunFinished = withObject "checklist_run_finished@1" $ \value -> ChecklistRunFinished <$> (value .: "run_id" >>= parseId) <*> (value .: "owner_id" >>= parseId)
  parseTemporalConstraintsChanged = withObject "temporal_constraints_changed@1" $ \value -> TemporalConstraintsChanged <$> (value .: "brick_id" >>= parseId) <*> (value .:? "not_before" >>= traverse parseZonedInstant) <*> (value .:? "best_before" >>= traverse parseZonedInstant) <*> (value .:? "deadline" >>= traverse parseZonedInstant) <*> value .: "revision"
  parseStandingOutcomeRecorded = withObject "standing_outcome_recorded@1" $ \value -> StandingOutcomeRecorded <$> (value .: "owner_id" >>= parseId) <*> (value .: "outcome" >>= parseStandingOutcome)
  parseRepeatableReturnSet = withObject "repeatable_return_set@1" $ \value ->
    RepeatableReturnSet
      <$> (value .: "owner_id" >>= parseId)
      <*> (value .: "policy" >>= parseReturnPolicy)
      <*> value .:? "chosen_offset"
      <*> (value .:? "not_before" >>= traverse parseZonedInstant)
      <*> value .:? "resolution"
      <*> (value .:? "seed" >>= traverse parseSeed)
      <*> (value .:? "draw" >>= traverse parseForecastDraw)
  parseScheduledIntervalSet = withObject "scheduled_interval_set@1" $ \value ->
    ScheduledIntervalSet
      <$> (value .: "owner_id" >>= parseId)
      <*> (value .: "starts_at" >>= parseZonedInstant)
      <*> (value .: "ends_at" >>= parseZonedInstant)
      <*> value .: "revision"

  parseRawContent :: Value -> Parser RawContent
  parseRawContent = withObject "RawContent" $ \value -> do
    kind <- value .: "kind" :: Parser Text
    case kind of
      "text" -> RawTextContent <$> value .: "text"
      "uri" -> RawUriContent <$> value .: "locator" <*> value .:? "label"
      "blob" -> RawBlobContent <$> value .: "digest" <*> value .: "media_type" <*> value .: "byte_length" <*> value .:? "filename"
      "structured" -> RawStructuredContent <$> value .: "schema" <*> value .: "canonical_json"
      _ -> fail "unknown Raw content kind"

  parseRawContentRevisionAppended :: Value -> Parser RawContentRevisionAppended
  parseRawContentRevisionAppended = withObject "raw_content_revision_appended@1" $ \value ->
    RawContentRevisionAppended
      <$> (value .: "raw_id" >>= parseId)
      <*> value .: "ordinal"
      <*> value .: "provenance"
      <*> (value .: "content" >>= parseRawContent)
      <*> value .: "digest"

  parseNormalizationSource :: Text -> Parser NormalizationSource
  parseNormalizationSource = \case
    "human" -> pure HumanNormalization
    "powered_up" -> pure PoweredUpNormalization
    "skill" -> pure SkillNormalization
    "import" -> pure ImportNormalization
    _ -> fail "unknown normalization source"

  parseEnglishNormalizationAccepted :: Value -> Parser EnglishNormalizationAccepted
  parseEnglishNormalizationAccepted = withObject "english_normalization_accepted@1" $ \value ->
    EnglishNormalizationAccepted
      <$> (value .: "revision_id" >>= parseId)
      <*> value .: "text"
      <*> (value .: "source" >>= parseNormalizationSource)
      <*> value .:? "producer"
      <*> (fmap Fixed <$> value .:? "confidence")

  parseBrickTitleNormalizationAccepted :: Value -> Parser BrickTitleNormalizationAccepted
  parseBrickTitleNormalizationAccepted = withObject "brick_title_normalization_accepted@1" $ \value ->
    BrickTitleNormalizationAccepted
      <$> (value .: "brick_id" >>= parseId)
      <*> value .: "previous"
      <*> value .: "current"
      <*> (value .: "source" >>= parseNormalizationSource)
      <*> value .:? "producer"
      <*> (fmap Fixed <$> value .:? "confidence")

  parseSourceMode :: Text -> Parser SourceMode
  parseSourceMode = \case "snapshot" -> pure SourceSnapshot; "synchronize" -> pure SourceSynchronize; "migrate" -> pure SourceMigrate; _ -> fail "unknown source mode"

  parseImportProfileLifecycle :: Text -> Parser ImportProfileLifecycle
  parseImportProfileLifecycle = \case "active" -> pure ImportProfileActive; "retired" -> pure ImportProfileRetired; _ -> fail "unknown import profile lifecycle"

  parseImportProfile :: Value -> Parser ImportProfile
  parseImportProfile = withObject "ImportProfile" $ \value ->
    ImportProfile
      <$> (value .: "import_profile_id" >>= parseId)
      <*> value .: "adapter_id"
      <*> value .: "source_label"
      <*> value .:? "account_label"
      <*> value .: "input_reference"
      <*> (Set.fromList <$> value .:? "selected_containers" .!= [])
      <*> (value .: "mode" >>= parseSourceMode)
      <*> value .: "cleanup_supported"
      <*> (value .: "lifecycle" >>= parseImportProfileLifecycle)
      <*> value .: "revision"

  parseImportObjectDisposition :: Text -> Parser ImportObjectDisposition
  parseImportObjectDisposition = \case "created_raw" -> pure ImportCreatedRaw; "reused_raw" -> pure ImportReusedRaw; _ -> fail "unknown import object disposition"

  parseImportObjectMapping :: Value -> Parser ImportObjectMapping
  parseImportObjectMapping = withObject "ImportObjectMapping" $ \value ->
    ImportObjectMapping
      <$> value .: "external_identity"
      <*> (value .: "raw_id" >>= parseId)
      <*> (value .: "disposition" >>= parseImportObjectDisposition)

  parseImportInvocation :: Value -> Parser ImportInvocation
  parseImportInvocation = withObject "ImportInvocation" $ \value ->
    ImportInvocation
      <$> (value .: "import_invocation_id" >>= parseId)
      <*> (value .: "import_profile_id" >>= parseId)
      <*> value .: "component_id"
      <*> value .: "contract_major"
      <*> value .: "permissions"
      <*> value .: "input_label"
      <*> value .: "input_media_type"
      <*> value .: "input_digest"
      <*> value .: "input_byte_count"
      <*> (value .: "mode" >>= parseSourceMode)
      <*> (Set.fromList <$> value .:? "selected_containers" .!= [])
      <*> value .: "pack_publisher"
      <*> value .: "pack_name"
      <*> value .: "pack_version"
      <*> value .: "pack_manifest_digest"
      <*> value .: "pack_archive_digest"
      <*> value .: "signer_fingerprint"
      <*> (value .: "mappings" >>= traverse parseImportObjectMapping)

  parseSourceLifecycle :: Text -> Parser SourceBindingLifecycle
  parseSourceLifecycle = \case "active" -> pure SourceBindingActive; "paused" -> pure SourceBindingPaused; "detached" -> pure SourceBindingDetached; _ -> fail "unknown source lifecycle"

  parseSourceCheckPolicy :: Value -> Parser SourceCheckPolicy
  parseSourceCheckPolicy = withObject "SourceCheckPolicy" $ \value -> do
    kind <- value .: "kind" :: Parser Text
    case kind of "manual" -> pure SourceManualCheck; "interval" -> SourceIntervalCheck <$> value .: "seconds"; _ -> fail "unknown source check policy"

  parseSourceBinding :: Value -> Parser SourceBinding
  parseSourceBinding = withObject "SourceBinding" $ \value ->
    SourceBinding
      <$> (value .: "binding_id" >>= parseId)
      <*> (value .: "raw_id" >>= parseId)
      <*> value .: "source_kind"
      <*> (value .:? "import_profile_id" >>= traverse parseId)
      <*> value .:? "external_identity"
      <*> value .:? "container_identity"
      <*> value .: "locator"
      <*> (value .: "mode" >>= parseSourceMode)
      <*> (value .: "check_policy" >>= parseSourceCheckPolicy)
      <*> (value .: "lifecycle" >>= parseSourceLifecycle)
      <*> (value .:? "accepted_observation_id" >>= traverse parseId)
      <*> value .: "revision"

  parseSourceObservationOutcome :: Text -> Parser SourceObservationOutcome
  parseSourceObservationOutcome = \case
    "unchanged" -> pure SourceUnchanged
    "changed" -> pure SourceChanged
    "missing" -> pure SourceMissing
    "unreachable" -> pure SourceUnreachable
    "unauthorized" -> pure SourceUnauthorized
    "malformed" -> pure SourceMalformed
    _ -> fail "unknown source observation outcome"

  parseSourceObservationRecorded :: Value -> Parser SourceObservationRecorded
  parseSourceObservationRecorded = withObject "source_observation_recorded@1" $ \value ->
    SourceObservationRecorded
      <$> (value .: "binding_id" >>= parseId)
      <*> value .: "locator"
      <*> (value .: "outcome" >>= parseSourceObservationOutcome)
      <*> value .:? "provider_version"
      <*> value .:? "fingerprint"
      <*> value .:? "snapshot_digest"
      <*> (value .:? "snapshot" >>= traverse parseRawContent)

  parseSourceObservationReconciled :: Value -> Parser SourceObservationReconciled
  parseSourceObservationReconciled = withObject "source_observation_reconciled@1" $ \value ->
    SourceObservationReconciled
      <$> (value .: "observation_id" >>= parseId)
      <*> (value .: "disposition" >>= parseSourceReconciliationDisposition)
  parseRecurringOccurrenceReleased = withObject "recurring_occurrence_released@1" $ \value ->
    RecurringOccurrenceReleased
      <$> (value .: "occurrence" >>= parseRecurringOccurrence)
      <*> (Handle <$> value .: "handle")
      <*> value .: "title"
      <*> (value .: "nature" >>= parseNature)
      <*> (Set.fromList <$> (value .: "domains" >>= traverse parseId))
      <*> value .: "sibling_position"
      <*> (value .: "temporal" >>= parseTemporalConstraints)
      <*> (value .:? "interval" >>= traverse parseScheduledInterval)
  parseHabitWindowOutcomeRecorded = withObject "habit_window_outcome_recorded@1" $ \value ->
    HabitWindowOutcomeRecorded
      <$> (value .: "outcome_id" >>= parseId)
      <*> (value .: "window_id" >>= parseId)
      <*> (value .: "owner_id" >>= parseId)
      <*> (value .: "outcome" >>= parseStandingOutcome)
  parseNoticeDispositionChanged = withObject "notice_disposition_changed@1" $ \value ->
    NoticeDispositionChanged <$> (value .: "notice" >>= parseNoticeIdentity) <*> (value .: "disposition" >>= parseNoticeDisposition)
  parseImportanceCompared = withObject "importance_compared@1" $ \value -> ImportanceCompared <$> (value .: "above" >>= parseId) <*> (value .: "below" >>= parseId) <*> value .: "source"
  parseImportancePlacementMarked = withObject "importance_placement_marked@1" (\value -> ImportancePlacementMarked <$> (value .: "brick_id" >>= parseId) <*> (value .: "confidence" >>= parseConfidence) <*> value .: "reason")
  parsePairJudgmentRecorded = withObject "pair_judgment_recorded@1" $ \value ->
    PairJudgmentRecorded
      <$> (value .: "judgment_id" >>= parseId)
      <*> (value .: "axis" >>= parseAxis)
      <*> (value .: "first" >>= parseId)
      <*> (value .: "second" >>= parseId)
      <*> (value .: "relation" >>= parseRelation)
      <*> (value .: "provenance" >>= parseProvenance)
      <*> (Fixed <$> value .: "initial_confidence")
      <*> value .: "profile_hash"
      <*> value .: "context"
      <*> value .: "reason"
      <*> (value .: "status" >>= parseJudgmentStatus)
      <*> (value .: "retired_judgments" >>= traverse parseId)
  parsePhaseChanged = withObject "phase_changed@1" $ \value -> PhaseChanged <$> (value .: "brick_id" >>= parseId) <*> (value .:? "phase" >>= traverse parsePhase) <*> (value .: "provenance" >>= parseProvenance)
  parseImpactClassified = withObject "impact_classified@1" $ \value -> ImpactClassified <$> (value .: "brick_id" >>= parseId) <*> (value .:? "class" >>= traverse parseImpactClass) <*> (value .: "maturity" >>= parseImpactMaturity) <*> (value .: "evidence" >>= traverse parseId) <*> (value .: "provenance" >>= parseProvenance) <*> value .: "profile_hash"
  parseEffortClassified = withObject "effort_classified@1" $ \value -> EffortClassified <$> (value .: "brick_id" >>= parseId) <*> (value .:? "class" >>= traverse parseEffortClass) <*> (value .: "provenance" >>= parseProvenance) <*> value .: "profile_hash"
  parseEffortActualObserved = withObject "effort_actual_observed@1" $ \value ->
    EffortActualObserved
      <$> (value .: "brick_id" >>= parseId)
      <*> (value .: "raw_id" >>= parseId)
      <*> (value .: "import_invocation_id" >>= parseId)
      <*> value .: "planning_manifest_sha256"
      <*> value .: "task_id"
      <*> value .: "as_of"
      <*> (value .:? "completed_microhours" >>= traverse parseMicrohoursText)
      <*> (value .:? "remaining_microhours" >>= traverse parseMicrohoursText)

parseUuidField :: Text -> Parser UUIDv7
parseUuidField = parseId

parseId :: Text -> Parser UUIDv7
parseId text = either (fail . Text.unpack) pure (parseUUIDv7 text)

parseMicrohoursText :: Text -> Parser Integer
parseMicrohoursText text =
  case reads (Text.unpack text) of
    [(value, "")]
      | value >= 0
      , Text.pack (show value) == text ->
          pure value
    _ -> fail "microhours must be a canonical nonnegative decimal integer string"

rawContentValue :: RawContent -> Value
rawContentValue = \case
  RawTextContent text -> object ["kind" .= ("text" :: Text), "text" .= text]
  RawUriContent locator label -> object $ ["kind" .= ("uri" :: Text), "locator" .= locator] <> maybe [] (pure . ("label" .=)) label
  RawBlobContent digest mediaType lengthBytes filename -> object $ ["kind" .= ("blob" :: Text), "digest" .= digest, "media_type" .= mediaType, "byte_length" .= lengthBytes] <> maybe [] (pure . ("filename" .=)) filename
  RawStructuredContent schema json -> object ["kind" .= ("structured" :: Text), "schema" .= schema, "canonical_json" .= json]

normalizationSourceText :: NormalizationSource -> Text
normalizationSourceText = \case
  HumanNormalization -> "human"
  PoweredUpNormalization -> "powered_up"
  SkillNormalization -> "skill"
  ImportNormalization -> "import"

sourceModeText :: SourceMode -> Text
sourceModeText = \case SourceSnapshot -> "snapshot"; SourceSynchronize -> "synchronize"; SourceMigrate -> "migrate"

importProfileLifecycleText :: ImportProfileLifecycle -> Text
importProfileLifecycleText = \case ImportProfileActive -> "active"; ImportProfileRetired -> "retired"

importProfileValue :: ImportProfile -> Value
importProfileValue profile =
  object $
    [ "import_profile_id" .= renderUUIDv7 (importProfileId profile)
    , "adapter_id" .= importProfileAdapterId profile
    , "source_label" .= importProfileSourceLabel profile
    , "input_reference" .= importProfileInputReference profile
    , "mode" .= sourceModeText (importProfileMode profile)
    , "cleanup_supported" .= importProfileCleanupSupported profile
    , "lifecycle" .= importProfileLifecycleText (importProfileLifecycle profile)
    , "revision" .= importProfileRevision profile
    ]
      <> maybe [] (pure . ("account_label" .=)) (importProfileAccountLabel profile)
      <> sparseSet "selected_containers" (importProfileSelectedContainers profile)

importObjectDispositionText :: ImportObjectDisposition -> Text
importObjectDispositionText = \case ImportCreatedRaw -> "created_raw"; ImportReusedRaw -> "reused_raw"

importObjectMappingValue :: ImportObjectMapping -> Value
importObjectMappingValue mapping =
  object
    [ "external_identity" .= importObjectExternalIdentity mapping
    , "raw_id" .= renderUUIDv7 (importObjectRawId mapping)
    , "disposition" .= importObjectDispositionText (importObjectDisposition mapping)
    ]

importInvocationValue :: ImportInvocation -> Value
importInvocationValue invocation =
  object $
    [ "import_invocation_id" .= renderUUIDv7 (importInvocationId invocation)
    , "import_profile_id" .= renderUUIDv7 (importInvocationProfileId invocation)
    , "component_id" .= importInvocationComponentId invocation
    , "contract_major" .= importInvocationContractMajor invocation
    , "permissions" .= importInvocationPermissions invocation
    , "input_label" .= importInvocationInputLabel invocation
    , "input_media_type" .= importInvocationInputMediaType invocation
    , "input_digest" .= importInvocationInputDigest invocation
    , "input_byte_count" .= importInvocationInputByteCount invocation
    , "mode" .= sourceModeText (importInvocationMode invocation)
    , "pack_publisher" .= importInvocationPackPublisher invocation
    , "pack_name" .= importInvocationPackName invocation
    , "pack_version" .= importInvocationPackVersion invocation
    , "pack_manifest_digest" .= importInvocationPackManifestDigest invocation
    , "pack_archive_digest" .= importInvocationPackArchiveDigest invocation
    , "signer_fingerprint" .= importInvocationSignerFingerprint invocation
    , "mappings" .= fmap importObjectMappingValue (importInvocationMappings invocation)
    ]
      <> sparseSet "selected_containers" (importInvocationSelectedContainers invocation)

sparseSet :: (ToJSON value) => Key -> Set.Set value -> [Pair]
sparseSet key values
  | Set.null values = []
  | otherwise = [key .= Set.toAscList values]

sourceLifecycleText :: SourceBindingLifecycle -> Text
sourceLifecycleText = \case SourceBindingActive -> "active"; SourceBindingPaused -> "paused"; SourceBindingDetached -> "detached"

sourceCheckPolicyValue :: SourceCheckPolicy -> Value
sourceCheckPolicyValue = \case
  SourceManualCheck -> object ["kind" .= ("manual" :: Text)]
  SourceIntervalCheck seconds -> object ["kind" .= ("interval" :: Text), "seconds" .= seconds]

sourceBindingValue :: SourceBinding -> Value
sourceBindingValue binding =
  object $
    [ "binding_id" .= renderUUIDv7 (sourceBindingId binding)
    , "raw_id" .= renderUUIDv7 (sourceBindingRaw binding)
    , "source_kind" .= sourceBindingKind binding
    , "locator" .= sourceBindingLocator binding
    , "mode" .= sourceModeText (sourceBindingMode binding)
    , "check_policy" .= sourceCheckPolicyValue (sourceBindingCheckPolicy binding)
    , "lifecycle" .= sourceLifecycleText (sourceBindingLifecycle binding)
    , "revision" .= sourceBindingRevision binding
    ]
      <> maybe [] (pure . ("import_profile_id" .=) . renderUUIDv7) (sourceBindingImportProfile binding)
      <> maybe [] (pure . ("external_identity" .=)) (sourceBindingExternalIdentity binding)
      <> maybe [] (pure . ("container_identity" .=)) (sourceBindingContainerIdentity binding)
      <> maybe [] (pure . ("accepted_observation_id" .=) . renderUUIDv7) (sourceBindingAcceptedObservation binding)

sourceObservationOutcomeText :: SourceObservationOutcome -> Text
sourceObservationOutcomeText = \case
  SourceUnchanged -> "unchanged"
  SourceChanged -> "changed"
  SourceMissing -> "missing"
  SourceUnreachable -> "unreachable"
  SourceUnauthorized -> "unauthorized"
  SourceMalformed -> "malformed"

sourceReconciliationDispositionValue :: SourceReconciliationDisposition -> Value
sourceReconciliationDispositionValue = \case
  SourceAcceptedAsRevision revisionId -> object ["kind" .= ("same_raw_revision" :: Text), "revision_id" .= renderUUIDv7 revisionId]
  SourceAcceptedAsDerivedRaw rawId -> object ["kind" .= ("derived_raw" :: Text), "raw_id" .= renderUUIDv7 rawId]
  SourceIgnoredAsUnrelated -> object ["kind" .= ("unrelated" :: Text)]

parseSourceReconciliationDisposition :: Value -> Parser SourceReconciliationDisposition
parseSourceReconciliationDisposition = withObject "SourceReconciliationDisposition" $ \value -> do
  kind <- value .: "kind" :: Parser Text
  case kind of
    "same_raw_revision" -> SourceAcceptedAsRevision <$> (value .: "revision_id" >>= parseId)
    "derived_raw" -> SourceAcceptedAsDerivedRaw <$> (value .: "raw_id" >>= parseId)
    "unrelated" -> pure SourceIgnoredAsUnrelated
    _ -> fail "unknown SourceReconciliation disposition"

natureText :: BrickNature -> Text
natureText = \case
  AtomicTask -> "atomic_task"
  Project -> "project"
  Collection -> "collection"
  Repeatable -> "repeatable"
  LivingChecklist -> "living_checklist"
  FiniteChecklist -> "finite_checklist"
  RecurringObligation -> "recurring_obligation"
  Habit -> "habit"
  ScheduledCommitment -> "scheduled_commitment"

parseNature :: Text -> Parser BrickNature
parseNature = \case
  "atomic_task" -> pure AtomicTask
  "project" -> pure Project
  "collection" -> pure Collection
  "repeatable" -> pure Repeatable
  "living_checklist" -> pure LivingChecklist
  "finite_checklist" -> pure FiniteChecklist
  "recurring_obligation" -> pure RecurringObligation
  "habit" -> pure Habit
  "scheduled_commitment" -> pure ScheduledCommitment
  value -> fail ("unknown Brick Nature: " <> Text.unpack value)

brickStatusText :: BrickStatus -> Text
brickStatusText = \case
  BrickActive -> "active"
  BrickDone -> "done"
  BrickArchived -> "archived"
  BrickSuperseded -> "superseded"
  BrickMerged -> "merged"
  BrickMissed -> "missed"
  BrickCancelled -> "cancelled"

parseBrickStatus :: Text -> Parser BrickStatus
parseBrickStatus = \case
  "active" -> pure BrickActive
  "done" -> pure BrickDone
  "archived" -> pure BrickArchived
  "superseded" -> pure BrickSuperseded
  "merged" -> pure BrickMerged
  "missed" -> pure BrickMissed
  "cancelled" -> pure BrickCancelled
  value -> fail ("unknown Brick status: " <> Text.unpack value)

listEntryStateText :: ListEntryState -> Text
listEntryStateText = \case
  EntryOpen -> "open"
  EntryResolved -> "resolved"
  EntryCancelled -> "cancelled"

parseListEntryState :: Text -> Parser ListEntryState
parseListEntryState = \case
  "open" -> pure EntryOpen
  "resolved" -> pure EntryResolved
  "cancelled" -> pure EntryCancelled
  value -> fail ("unknown ListEntry state: " <> Text.unpack value)

zonedInstantValue :: ZonedInstant -> Value
zonedInstantValue instant = object ["utc" .= zonedInstantUtc instant, "zone" .= zonedInstantZone instant]

parseZonedInstant :: Value -> Parser ZonedInstant
parseZonedInstant = withObject "ZonedInstant" $ \value -> ZonedInstant <$> value .: "utc" <*> value .: "zone"

calendarRuleValue :: CalendarRule -> Value
calendarRuleValue rule =
  object $
    [ "family" .= recurrenceFamilyText (calendarFamily rule)
    , "every" .= calendarEvery rule
    , "starts_on" .= calendarStartsOn rule
    , "weekdays" .= fmap dayOfWeekText (Set.toAscList (calendarWeekdays rule))
    , "times" .= calendarTimes rule
    ]
      <> maybe [] (pure . ("intended_day" .=)) (calendarIntendedDay rule)
      <> maybe [] (pure . ("intended_month" .=)) (calendarIntendedMonth rule)

parseCalendarRule :: Value -> Parser CalendarRule
parseCalendarRule = withObject "CalendarRule" $ \value ->
  CalendarRule
    <$> (value .: "family" >>= parseRecurrenceFamily)
    <*> value .: "every"
    <*> value .: "starts_on"
    <*> (Set.fromList <$> (value .: "weekdays" >>= traverse parseDayOfWeek))
    <*> value .:? "intended_day"
    <*> value .:? "intended_month"
    <*> value .: "times"

recurrenceScheduleValue :: RecurrenceSchedule -> Value
recurrenceScheduleValue schedule =
  object $
    [ "owner_id" .= renderUUIDv7 (recurrenceOwner schedule)
    , "rule" .= calendarRuleValue (recurrenceRule schedule)
    , "zone" .= recurrenceZone schedule
    , "occurrence_nature" .= natureText (recurrenceOccurrenceNature schedule)
    , "not_before_offset_seconds" .= recurrenceNotBeforeOffsetSeconds schedule
    , "revision" .= recurrenceRevision schedule
    ]
      <> maybe [] (pure . ("duration_seconds" .=)) (recurrenceDurationSeconds schedule)
      <> maybe [] (pure . ("best_before_offset_seconds" .=)) (recurrenceBestBeforeOffsetSeconds schedule)
      <> maybe [] (pure . ("deadline_offset_seconds" .=)) (recurrenceDeadlineOffsetSeconds schedule)

parseRecurrenceSchedule :: Value -> Parser RecurrenceSchedule
parseRecurrenceSchedule = withObject "RecurrenceSchedule" $ \value ->
  RecurrenceSchedule
    <$> (value .: "owner_id" >>= parseId)
    <*> (value .: "rule" >>= parseCalendarRule)
    <*> value .: "zone"
    <*> (value .: "occurrence_nature" >>= parseNature)
    <*> value .:? "duration_seconds"
    <*> value .: "not_before_offset_seconds"
    <*> value .:? "best_before_offset_seconds"
    <*> value .:? "deadline_offset_seconds"
    <*> value .: "revision"

recurringOccurrenceValue :: RecurringOccurrence -> Value
recurringOccurrenceValue occurrence =
  object
    [ "occurrence_id" .= renderUUIDv7 (recurringOccurrenceId occurrence)
    , "owner_id" .= renderUUIDv7 (recurringOccurrenceOwner occurrence)
    , "brick_id" .= renderUUIDv7 (recurringOccurrenceBrick occurrence)
    , "nominal_anchor" .= zonedInstantValue (recurringOccurrenceNominalAnchor occurrence)
    , "label" .= recurringOccurrenceLabel occurrence
    , "schedule_revision" .= recurringOccurrenceScheduleRevision occurrence
    ]

parseRecurringOccurrence :: Value -> Parser RecurringOccurrence
parseRecurringOccurrence = withObject "RecurringOccurrence" $ \value ->
  RecurringOccurrence
    <$> (value .: "occurrence_id" >>= parseId)
    <*> (value .: "owner_id" >>= parseId)
    <*> (value .: "brick_id" >>= parseId)
    <*> (value .: "nominal_anchor" >>= parseZonedInstant)
    <*> value .: "label"
    <*> value .: "schedule_revision"

habitScheduleValue :: HabitSchedule -> Value
habitScheduleValue = \case
  FixedSlotHabit owner rule zone duration boundary revision ->
    object $
      [ "kind" .= ("fixed_slots" :: Text)
      , "owner_id" .= renderUUIDv7 owner
      , "rule" .= calendarRuleValue rule
      , "zone" .= zone
      , "duration_seconds" .= duration
      , "revision" .= revision
      ]
        <> maybe [] (pure . ("habit_day_boundary" .=)) boundary
  QuotaWindowHabit owner target span unit starts zone boundary revision ->
    object $
      [ "kind" .= ("quota_window" :: Text)
      , "owner_id" .= renderUUIDv7 owner
      , "target" .= target
      , "span" .= span
      , "unit" .= returnUnitText unit
      , "starts_on" .= starts
      , "zone" .= zone
      , "revision" .= revision
      ]
        <> maybe [] (pure . ("habit_day_boundary" .=)) boundary

parseHabitSchedule :: Value -> Parser HabitSchedule
parseHabitSchedule = withObject "HabitSchedule" $ \value -> do
  kind <- value .: "kind"
  case (kind :: Text) of
    "fixed_slots" ->
      FixedSlotHabit
        <$> (value .: "owner_id" >>= parseId)
        <*> (value .: "rule" >>= parseCalendarRule)
        <*> value .: "zone"
        <*> value .: "duration_seconds"
        <*> value .:? "habit_day_boundary"
        <*> value .: "revision"
    "quota_window" ->
      QuotaWindowHabit
        <$> (value .: "owner_id" >>= parseId)
        <*> value .: "target"
        <*> value .: "span"
        <*> (value .: "unit" >>= parseReturnUnit)
        <*> value .: "starts_on"
        <*> value .: "zone"
        <*> value .:? "habit_day_boundary"
        <*> value .: "revision"
    _ -> fail ("unknown habit schedule: " <> Text.unpack kind)

habitWindowValue :: HabitWindow -> Value
habitWindowValue window =
  object
    [ "window_id" .= renderUUIDv7 (habitWindowId window)
    , "owner_id" .= renderUUIDv7 (habitWindowOwner window)
    , "opens_at" .= zonedInstantValue (habitWindowOpensAt window)
    , "closes_at" .= zonedInstantValue (habitWindowClosesAt window)
    , "target" .= habitWindowTarget window
    , "schedule_revision" .= habitWindowScheduleRevision window
    , "settled" .= habitWindowSettled window
    ]

parseHabitWindow :: Value -> Parser HabitWindow
parseHabitWindow = withObject "HabitWindow" $ \value ->
  HabitWindow
    <$> (value .: "window_id" >>= parseId)
    <*> (value .: "owner_id" >>= parseId)
    <*> (value .: "opens_at" >>= parseZonedInstant)
    <*> (value .: "closes_at" >>= parseZonedInstant)
    <*> value .: "target"
    <*> value .: "schedule_revision"
    <*> value .: "settled"

temporalConstraintsValue :: TemporalConstraints -> Value
temporalConstraintsValue constraints =
  object $
    ["revision" .= temporalRevision constraints]
      <> maybe [] (pure . ("not_before" .=) . zonedInstantValue) (temporalNotBefore constraints)
      <> maybe [] (pure . ("best_before" .=) . zonedInstantValue) (temporalBestBefore constraints)
      <> maybe [] (pure . ("deadline" .=) . zonedInstantValue) (temporalDeadline constraints)

parseTemporalConstraints :: Value -> Parser TemporalConstraints
parseTemporalConstraints = withObject "TemporalConstraints" $ \value ->
  TemporalConstraints
    <$> (value .:? "not_before" >>= traverse parseZonedInstant)
    <*> (value .:? "best_before" >>= traverse parseZonedInstant)
    <*> (value .:? "deadline" >>= traverse parseZonedInstant)
    <*> value .: "revision"

scheduledIntervalValue :: ScheduledInterval -> Value
scheduledIntervalValue interval =
  object
    [ "owner_id" .= renderUUIDv7 (scheduledIntervalOwner interval)
    , "starts_at" .= zonedInstantValue (scheduledStartsAt interval)
    , "ends_at" .= zonedInstantValue (scheduledEndsAt interval)
    , "revision" .= scheduledIntervalRevision interval
    ]

parseScheduledInterval :: Value -> Parser ScheduledInterval
parseScheduledInterval = withObject "ScheduledInterval" $ \value ->
  ScheduledInterval
    <$> (value .: "owner_id" >>= parseId)
    <*> (value .: "starts_at" >>= parseZonedInstant)
    <*> (value .: "ends_at" >>= parseZonedInstant)
    <*> value .: "revision"

noticeIdentityValue :: NoticeIdentity -> Value
noticeIdentityValue notice =
  object
    [ "subject_id" .= renderUUIDv7 (noticeSubject notice)
    , "fact_revision" .= noticeFactRevision notice
    , "kind" .= noticeKindText (noticeKind notice)
    , "threshold" .= noticeThreshold notice
    ]

parseNoticeIdentity :: Value -> Parser NoticeIdentity
parseNoticeIdentity = withObject "NoticeIdentity" $ \value ->
  NoticeIdentity
    <$> (value .: "subject_id" >>= parseId)
    <*> value .: "fact_revision"
    <*> (value .: "kind" >>= parseNoticeKind)
    <*> value .: "threshold"

noticeDispositionValue :: NoticeDisposition -> Value
noticeDispositionValue = \case
  NoticeAcknowledged at -> object ["kind" .= ("acknowledged" :: Text), "at" .= at]
  NoticeSnoozed until -> object ["kind" .= ("snoozed" :: Text), "not_before" .= zonedInstantValue until]

parseNoticeDisposition :: Value -> Parser NoticeDisposition
parseNoticeDisposition = withObject "NoticeDisposition" $ \value -> do
  kind <- value .: "kind"
  case (kind :: Text) of
    "acknowledged" -> NoticeAcknowledged <$> value .: "at"
    "snoozed" -> NoticeSnoozed <$> (value .: "not_before" >>= parseZonedInstant)
    _ -> fail ("unknown notice disposition: " <> Text.unpack kind)

operationalDayConfigValue :: OperationalDayConfig -> Value
operationalDayConfigValue config =
  object
    [ "zone" .= operationalZone config
    , "habit_day_starts_at" .= operationalHabitDayStartsAt config
    , "workday_starts_at" .= operationalWorkdayStartsAt config
    ]

parseOperationalDayConfig :: Value -> Parser OperationalDayConfig
parseOperationalDayConfig = withObject "OperationalDayConfig" $ \value ->
  OperationalDayConfig <$> value .: "zone" <*> value .: "habit_day_starts_at" <*> value .: "workday_starts_at"

recurrenceFamilyText :: RecurrenceFamily -> Text
recurrenceFamilyText = \case
  DailyRecurrence -> "daily"
  WeeklyRecurrence -> "weekly"
  MonthlyRecurrence -> "monthly"
  YearlyRecurrence -> "yearly"

parseRecurrenceFamily :: Text -> Parser RecurrenceFamily
parseRecurrenceFamily = \case
  "daily" -> pure DailyRecurrence
  "weekly" -> pure WeeklyRecurrence
  "monthly" -> pure MonthlyRecurrence
  "yearly" -> pure YearlyRecurrence
  value -> fail ("unknown recurrence family: " <> Text.unpack value)

dayOfWeekText :: DayOfWeek -> Text
dayOfWeekText = Text.toLower . Text.pack . show

parseDayOfWeek :: Text -> Parser DayOfWeek
parseDayOfWeek value =
  maybe (fail ("unknown weekday: " <> Text.unpack value)) pure (lookup (Text.toLower value) table)
 where
  table = [(dayOfWeekText day, day) | day <- [Monday .. Sunday]]

noticeKindText :: NoticeKind -> Text
noticeKindText = \case
  BestBeforeNotice -> "best_before"
  DeadlineNotice -> "deadline"
  RecurringReleaseNotice -> "recurring_release"
  TemporalTransitionNotice -> "temporal_transition"

parseNoticeKind :: Text -> Parser NoticeKind
parseNoticeKind = \case
  "best_before" -> pure BestBeforeNotice
  "deadline" -> pure DeadlineNotice
  "recurring_release" -> pure RecurringReleaseNotice
  "temporal_transition" -> pure TemporalTransitionNotice
  value -> fail ("unknown notice kind: " <> Text.unpack value)

standingOutcomeText :: StandingOutcomeKind -> Text
standingOutcomeText = \case
  StandingDone -> "done"
  StandingUnfulfilled -> "unfulfilled"
  StandingBlocked -> "blocked"
  StandingPaused -> "paused"
  StandingInapplicable -> "inapplicable"
  StandingAttended -> "attended"
  StandingMissed -> "missed"
  StandingCancelled -> "cancelled"

parseStandingOutcome :: Text -> Parser StandingOutcomeKind
parseStandingOutcome = \case
  "done" -> pure StandingDone
  "unfulfilled" -> pure StandingUnfulfilled
  "blocked" -> pure StandingBlocked
  "paused" -> pure StandingPaused
  "inapplicable" -> pure StandingInapplicable
  "attended" -> pure StandingAttended
  "missed" -> pure StandingMissed
  "cancelled" -> pure StandingCancelled
  value -> fail ("unknown standing outcome: " <> Text.unpack value)

returnPolicyValue :: ReturnPolicy -> Value
returnPolicyValue = \case
  ManualOnlyReturn -> object ["kind" .= ("manual_only" :: Text)]
  AfterCompletionReturn center unit variation zone ->
    object
      [ "kind" .= ("after_completion" :: Text)
      , "center" .= center
      , "unit" .= returnUnitText unit
      , "variation" .= variation
      , "zone" .= zone
      ]

parseReturnPolicy :: Value -> Parser ReturnPolicy
parseReturnPolicy = withObject "ReturnPolicy" $ \value -> do
  kind <- value .: "kind"
  case (kind :: Text) of
    "manual_only" -> pure ManualOnlyReturn
    "after_completion" ->
      AfterCompletionReturn
        <$> value .: "center"
        <*> (value .: "unit" >>= parseReturnUnit)
        <*> value .: "variation"
        <*> value .: "zone"
    _ -> fail ("unknown return policy: " <> Text.unpack kind)

returnUnitText :: ReturnUnit -> Text
returnUnitText = \case
  ReturnDays -> "days"
  ReturnWeeks -> "weeks"
  ReturnMonths -> "months"
  ReturnYears -> "years"

parseReturnUnit :: Text -> Parser ReturnUnit
parseReturnUnit = \case
  "days" -> pure ReturnDays
  "weeks" -> pure ReturnWeeks
  "months" -> pure ReturnMonths
  "years" -> pure ReturnYears
  value -> fail ("unknown return unit: " <> Text.unpack value)

templateValue :: TemplateSelection -> Value
templateValue template = object ["id" .= templateIdentifier template, "catalog_version" .= templateCatalogVersion template, "source" .= templateSource template]

parseTemplate :: Value -> Parser TemplateSelection
parseTemplate = withObject "TemplateSelection" $ \value -> TemplateSelection <$> value .: "id" <*> value .: "catalog_version" <*> value .: "source"

confidenceValue :: ImportanceConfidence -> Value
confidenceValue = \case
  HumanComparison -> object ["type" .= ("human_comparison" :: Text)]
  DeterministicPosition reason -> object ["type" .= ("deterministic" :: Text), "reason" .= reason]
  Provisional reason -> object ["type" .= ("provisional" :: Text), "reason" .= reason]

parseConfidence :: Value -> Parser ImportanceConfidence
parseConfidence = withObject "ImportanceConfidence" $ \value ->
  value .: "type" >>= \case
    ("human_comparison" :: Text) -> pure HumanComparison
    "deterministic" -> DeterministicPosition <$> value .: "reason"
    "provisional" -> Provisional <$> value .: "reason"
    other -> fail ("unknown importance confidence: " <> Text.unpack other)

axisText :: JudgmentAxis -> Text
axisText = \case
  ImportanceAxis -> "importance"
  ImpactAxis -> "impact"
  EffortAxis -> "effort"

parseAxis :: Text -> Parser JudgmentAxis
parseAxis = \case
  "importance" -> pure ImportanceAxis
  "impact" -> pure ImpactAxis
  "effort" -> pure EffortAxis
  value -> fail ("unknown judgment axis: " <> Text.unpack value)

relationText :: JudgmentRelation -> Text
relationText = \case
  MoreThan -> "more_than"
  EitherOrder -> "either_order"
  AboutSame -> "about_same"

parseRelation :: Text -> Parser JudgmentRelation
parseRelation = \case
  "more_than" -> pure MoreThan
  "either_order" -> pure EitherOrder
  "about_same" -> pure AboutSame
  value -> fail ("unknown judgment relation: " <> Text.unpack value)

provenanceValue :: JudgmentProvenance -> Value
provenanceValue = \case
  DirectHuman -> object ["type" .= ("direct_human" :: Text)]
  AssistedAccepted provider -> object ["type" .= ("assisted_accepted" :: Text), "provider" .= provider]
  HumanEitherOrder -> object ["type" .= ("human_either_order" :: Text)]
  DeterministicProvisional -> object ["type" .= ("deterministic_provisional" :: Text)]
  ModelOnly provider -> object ["type" .= ("model_only" :: Text), "provider" .= provider]

parseProvenance :: Value -> Parser JudgmentProvenance
parseProvenance = withObject "JudgmentProvenance" $ \value ->
  value .: "type" >>= \case
    ("direct_human" :: Text) -> pure DirectHuman
    "assisted_accepted" -> AssistedAccepted <$> value .: "provider"
    "human_either_order" -> pure HumanEitherOrder
    "deterministic_provisional" -> pure DeterministicProvisional
    "model_only" -> ModelOnly <$> value .: "provider"
    other -> fail ("unknown judgment provenance: " <> Text.unpack other)

judgmentStatusValue :: JudgmentStatus -> Value
judgmentStatusValue = \case
  JudgmentCurrent -> object ["type" .= ("current" :: Text)]
  JudgmentRetired resolution reason -> object ["type" .= ("retired" :: Text), "resolution_id" .= renderUUIDv7 resolution, "reason" .= reason]
  JudgmentRetracted resolution reason -> object ["type" .= ("retracted" :: Text), "resolution_id" .= renderUUIDv7 resolution, "reason" .= reason]
  JudgmentUnresolved reason -> object ["type" .= ("unresolved" :: Text), "reason" .= reason]

parseJudgmentStatus :: Value -> Parser JudgmentStatus
parseJudgmentStatus = withObject "JudgmentStatus" $ \value ->
  value .: "type" >>= \case
    ("current" :: Text) -> pure JudgmentCurrent
    "retired" -> JudgmentRetired <$> (value .: "resolution_id" >>= parseId) <*> value .: "reason"
    "retracted" -> JudgmentRetracted <$> (value .: "resolution_id" >>= parseId) <*> value .: "reason"
    "unresolved" -> JudgmentUnresolved <$> value .: "reason"
    other -> fail ("unknown judgment status: " <> Text.unpack other)

phaseText :: WorkPhase -> Text
phaseText = \case
  IdeaPhase -> "idea"
  SpecPhase -> "spec"
  ExecutionPhase -> "execution"
  ValidationPhase -> "validation"

parsePhase :: Text -> Parser WorkPhase
parsePhase = \case
  "idea" -> pure IdeaPhase
  "spec" -> pure SpecPhase
  "execution" -> pure ExecutionPhase
  "validation" -> pure ValidationPhase
  value -> fail ("unknown phase: " <> Text.unpack value)

skipSymptomValue :: SkipSymptom -> Value
skipSymptomValue = \case
  VagueSymptom -> object ["type" .= ("vague" :: Text)]
  HardSymptom -> object ["type" .= ("hard" :: Text)]
  BigSymptom -> object ["type" .= ("big" :: Text)]
  BlockedOrWaitingSymptom -> object ["type" .= ("blocked_or_waiting" :: Text)]
  BlockedSymptom -> object ["type" .= ("blocked" :: Text)]
  WaitingSymptom -> object ["type" .= ("waiting" :: Text)]
  TiredSymptom -> object ["type" .= ("tired" :: Text)]
  BoredSymptom -> object ["type" .= ("bored" :: Text)]
  FearSymptom -> object ["type" .= ("fear" :: Text)]
  LessImportantSymptom -> object ["type" .= ("less_important" :: Text)]
  OutOfDateSymptom -> object ["type" .= ("out_of_date" :: Text)]
  OtherSymptom explanation -> object ["type" .= ("other" :: Text), "explanation" .= explanation]

parseSkipSymptom :: Value -> Parser SkipSymptom
parseSkipSymptom = withObject "SkipSymptom" $ \value ->
  value .: "type" >>= \case
    ("vague" :: Text) -> pure VagueSymptom
    "hard" -> pure HardSymptom
    "big" -> pure BigSymptom
    "blocked_or_waiting" -> pure BlockedOrWaitingSymptom
    "blocked" -> pure BlockedSymptom
    "waiting" -> pure WaitingSymptom
    "tired" -> pure TiredSymptom
    "bored" -> pure BoredSymptom
    "fear" -> pure FearSymptom
    "less_important" -> pure LessImportantSymptom
    "out_of_date" -> pure OutOfDateSymptom
    "other" -> OtherSymptom <$> value .: "explanation"
    other -> fail ("unknown skip symptom: " <> Text.unpack other)

skipReactionValue :: SkipReaction -> Value
skipReactionValue = \case
  SkipAnywayReaction -> object ["type" .= ("skip_anyway" :: Text)]
  PauseForNowReaction -> object ["type" .= ("pause_for_now" :: Text)]
  StartSprintReaction minutes -> object ["type" .= ("start_sprint" :: Text), "minutes" .= minutes]
  ArchiveReaction -> object ["type" .= ("archive" :: Text)]
  KeepAndUpdateReaction -> object ["type" .= ("keep_and_update" :: Text)]
  BreakIntoPartsReaction -> object ["type" .= ("break_into_parts" :: Text)]
  CollectContextReaction -> object ["type" .= ("collect_context" :: Text)]
  LearnFirstReaction -> object ["type" .= ("learn_first" :: Text)]
  FindEasierApproachReaction -> object ["type" .= ("find_easier_approach" :: Text)]
  GetHelpReaction -> object ["type" .= ("get_help" :: Text)]
  ChangeSubjectReaction -> object ["type" .= ("change_subject" :: Text)]
  EasierWorkReaction identity -> object ["type" .= ("easier_work" :: Text), "brick_id" .= renderUUIDv7 identity]
  OrderLowerReaction -> object ["type" .= ("order_lower" :: Text)]
  LaterReaction -> object ["type" .= ("later" :: Text)]
  CreateRequestReaction -> object ["type" .= ("create_request" :: Text)]

parseSkipReaction :: Value -> Parser SkipReaction
parseSkipReaction = withObject "SkipReaction" $ \value ->
  value .: "type" >>= \case
    ("skip_anyway" :: Text) -> pure SkipAnywayReaction
    "pause_for_now" -> pure PauseForNowReaction
    "start_sprint" -> StartSprintReaction <$> value .: "minutes"
    "archive" -> pure ArchiveReaction
    "keep_and_update" -> pure KeepAndUpdateReaction
    "break_into_parts" -> pure BreakIntoPartsReaction
    "collect_context" -> pure CollectContextReaction
    "learn_first" -> pure LearnFirstReaction
    "find_easier_approach" -> pure FindEasierApproachReaction
    "get_help" -> pure GetHelpReaction
    "change_subject" -> pure ChangeSubjectReaction
    "easier_work" -> EasierWorkReaction <$> (value .: "brick_id" >>= parseId)
    "order_lower" -> pure OrderLowerReaction
    "later" -> pure LaterReaction
    "create_request" -> pure CreateRequestReaction
    other -> fail ("unknown skip reaction: " <> Text.unpack other)

impactClassText :: ImpactClass -> Text
impactClassText = \case
  VeryLowImpact -> "very_low"
  LowImpact -> "low"
  MediumImpact -> "medium"
  HighImpact -> "high"
  VeryHighImpact -> "very_high"
  CriticalImpact -> "critical"

parseImpactClass :: Text -> Parser ImpactClass
parseImpactClass = \case
  "very_low" -> pure VeryLowImpact
  "low" -> pure LowImpact
  "medium" -> pure MediumImpact
  "high" -> pure HighImpact
  "very_high" -> pure VeryHighImpact
  "critical" -> pure CriticalImpact
  value -> fail ("unknown Impact class: " <> Text.unpack value)

impactMaturityText :: ImpactMaturity -> Text
impactMaturityText = \case
  SpeculativeImpact -> "speculative"
  SupportedImpact -> "supported"
  ValidatedImpact -> "validated"
  ObservedImpact -> "observed"

parseImpactMaturity :: Text -> Parser ImpactMaturity
parseImpactMaturity = \case
  "speculative" -> pure SpeculativeImpact
  "supported" -> pure SupportedImpact
  "validated" -> pure ValidatedImpact
  "observed" -> pure ObservedImpact
  value -> fail ("unknown Impact maturity: " <> Text.unpack value)

effortClassText :: EffortClass -> Text
effortClassText = \case
  VeryEasyEffort -> "very_easy"
  EasyEffort -> "easy"
  NormalEffort -> "normal"
  ModerateEffort -> "moderate"
  HardEffort -> "hard"
  VeryHardEffort -> "very_hard"
  MiniProjectEffort -> "mini_project"
  ProjectEffort -> "project"

parseEffortClass :: Text -> Parser EffortClass
parseEffortClass = \case
  "very_easy" -> pure VeryEasyEffort
  "easy" -> pure EasyEffort
  "normal" -> pure NormalEffort
  "moderate" -> pure ModerateEffort
  "hard" -> pure HardEffort
  "very_hard" -> pure VeryHardEffort
  "mini_project" -> pure MiniProjectEffort
  "project" -> pure ProjectEffort
  value -> fail ("unknown Effort class: " <> Text.unpack value)
quantityValue :: Quantity -> Value
quantityValue quantity = object ["coefficient" .= quantityCoefficient quantity, "scale" .= quantityScale quantity, "unit" .= quantityUnit quantity]

parseQuantity :: Value -> Parser Quantity
parseQuantity = withObject "Quantity" $ \value -> Quantity <$> value .: "coefficient" <*> value .: "scale" <*> value .: "unit"

roleText :: RawLinkRole -> Text
roleText = \case
  DescriptionRole -> "description"
  MaterializationSourceRole -> "materialization_source"
  AttachmentRole -> "attachment"
  EvidenceRole -> "evidence"
  DerivedFromRole -> "derived_from"
  DuplicateOfRole -> "duplicate_of"

parseRole :: Text -> Parser RawLinkRole
parseRole = \case
  "description" -> pure DescriptionRole
  "materialization_source" -> pure MaterializationSourceRole
  "attachment" -> pure AttachmentRole
  "evidence" -> pure EvidenceRole
  "derived_from" -> pure DerivedFromRole
  "duplicate_of" -> pure DuplicateOfRole
  value -> fail ("unknown RawLink role: " <> Text.unpack value)

rawLinkTargetValue :: RawLinkTarget -> Value
rawLinkTargetValue = \case
  RawLinkBrick identity -> object ["type" .= ("brick" :: Text), "id" .= renderUUIDv7 identity]
  RawLinkListEntry identity -> object ["type" .= ("list_entry" :: Text), "id" .= renderUUIDv7 identity]
  RawLinkRaw identity -> object ["type" .= ("raw" :: Text), "id" .= renderUUIDv7 identity]

parseRawLinkTarget :: Value -> Parser RawLinkTarget
parseRawLinkTarget = withObject "RawLinkTarget" $ \value -> do
  identity <- value .: "id" >>= parseId
  value .: "type" >>= \case
    ("brick" :: Text) -> pure (RawLinkBrick identity)
    "list_entry" -> pure (RawLinkListEntry identity)
    "raw" -> pure (RawLinkRaw identity)
    other -> fail ("unknown RawLink target: " <> Text.unpack other)

dispositionValue :: RawDisposition -> Value
dispositionValue = \case
  RawKeptStandalone -> object ["type" .= ("standalone" :: Text)]
  RawGroupedAsDuplicate identity -> object ["type" .= ("duplicate_receipt" :: Text), "raw_id" .= renderUUIDv7 identity]
  RawMaterializedAsWork identity -> object ["type" .= ("work" :: Text), "brick_id" .= renderUUIDv7 identity]
  RawMaterializedAsListEntry owner entry -> object ["type" .= ("list_entry" :: Text), "owner_id" .= renderUUIDv7 owner, "entry_id" .= renderUUIDv7 entry]
  RawPlacedOnShelf identity -> object ["type" .= ("shelf" :: Text), "shelf_id" .= renderUUIDv7 identity]
  RawAttachedTo identity role -> object ["type" .= ("attachment" :: Text), "brick_id" .= renderUUIDv7 identity, "role" .= roleText role]

parseDisposition :: Value -> Parser RawDisposition
parseDisposition = withObject "RawDisposition" $ \value ->
  value .: "type" >>= \case
    ("standalone" :: Text) -> pure RawKeptStandalone
    "duplicate_receipt" -> RawGroupedAsDuplicate <$> (value .: "raw_id" >>= parseId)
    "work" -> RawMaterializedAsWork <$> (value .: "brick_id" >>= parseId)
    "list_entry" -> RawMaterializedAsListEntry <$> (value .: "owner_id" >>= parseId) <*> (value .: "entry_id" >>= parseId)
    "shelf" -> RawPlacedOnShelf <$> (value .: "shelf_id" >>= parseId)
    "attachment" -> RawAttachedTo <$> (value .: "brick_id" >>= parseId) <*> (value .: "role" >>= parseRole)
    other -> fail ("unknown Raw disposition: " <> Text.unpack other)

externalEntityValue :: ExternalEntity -> Value
externalEntityValue entity =
  object
    [ "entity_id" .= renderUUIDv7 (externalEntityId entity)
    , "handle" .= unHandle (externalEntityHandle entity)
    , "name" .= externalEntityName entity
    , "kind" .= externalEntityKindText (externalEntityKind entity)
    , "active" .= externalEntityActive entity
    , "created_at" .= externalEntityCreatedAt entity
    ]

parseExternalEntity :: Value -> Parser ExternalEntity
parseExternalEntity = withObject "ExternalEntity" $ \value ->
  ExternalEntity
    <$> (value .: "entity_id" >>= parseId)
    <*> (Handle <$> value .: "handle")
    <*> value .: "name"
    <*> (value .: "kind" >>= parseExternalEntityKind)
    <*> value .: "active"
    <*> value .: "created_at"

externalEntityKindText :: ExternalEntityKind -> Text
externalEntityKindText = \case
  PersonEntity -> "person"
  TeamEntity -> "team"
  OrganizationEntity -> "organization"
  AIAgentEntity -> "ai_agent"
  ServiceEntity -> "service"

parseExternalEntityKind :: Text -> Parser ExternalEntityKind
parseExternalEntityKind = \case
  "person" -> pure PersonEntity
  "team" -> pure TeamEntity
  "organization" -> pure OrganizationEntity
  "ai_agent" -> pure AIAgentEntity
  "service" -> pure ServiceEntity
  value -> fail ("unknown ExternalEntity kind: " <> Text.unpack value)

contactPointValue' :: ContactPoint -> Value
contactPointValue' contact =
  object $
    [ "contact_id" .= renderUUIDv7 (contactPointId contact)
    , "owner_id" .= renderUUIDv7 (contactPointOwner contact)
    , "kind" .= contactPointKindText (contactPointKind contact)
    , "value" .= contactPointValue contact
    , "active" .= contactPointActive contact
    , "source" .= contactPointSource contact
    ]
      <> maybe [] (pure . ("label" .=)) (contactPointLabel contact)
      <> maybe [] (pure . ("provider" .=)) (contactPointProvider contact)
      <> maybe [] (pure . ("verified_at" .=)) (contactPointVerifiedAt contact)

parseContactPoint :: Value -> Parser ContactPoint
parseContactPoint = withObject "ContactPoint" $ \value ->
  ContactPoint
    <$> (value .: "contact_id" >>= parseId)
    <*> (value .: "owner_id" >>= parseId)
    <*> (value .: "kind" >>= parseContactPointKind)
    <*> value .:? "label"
    <*> value .: "value"
    <*> value .:? "provider"
    <*> value .: "active"
    <*> value .: "source"
    <*> value .:? "verified_at"

contactPointKindText :: ContactPointKind -> Text
contactPointKindText = \case
  EmailContact -> "email"
  PhoneContact -> "phone"
  URIContact -> "uri"
  ProviderRecipientContact -> "provider_recipient"

parseContactPointKind :: Text -> Parser ContactPointKind
parseContactPointKind = \case
  "email" -> pure EmailContact
  "phone" -> pure PhoneContact
  "uri" -> pure URIContact
  "provider_recipient" -> pure ProviderRecipientContact
  value -> fail ("unknown ContactPoint kind: " <> Text.unpack value)

waitGateValue :: WaitGate -> Value
waitGateValue gate =
  object
    [ "wait_id" .= renderUUIDv7 (waitId gate)
    , "brick_id" .= renderUUIDv7 (waitAffectedBrick gate)
    , "kind" .= waitKindValue (waitKind gate)
    , "review_not_before" .= zonedInstantValue (waitReviewNotBefore gate)
    , "review_cooldown_until" .= waitReviewCooldownUntil gate
    , "status" .= waitStatusText (waitStatus gate)
    , "activated_at" .= waitActivatedAt gate
    , "deferral_count" .= waitDeferralCount gate
    , "revision" .= waitRevision gate
    ]

parseWaitGate :: Value -> Parser WaitGate
parseWaitGate = withObject "WaitGate" $ \value ->
  WaitGate
    <$> (value .: "wait_id" >>= parseId)
    <*> (value .: "brick_id" >>= parseId)
    <*> (value .: "kind" >>= parseWaitKind)
    <*> (value .: "review_not_before" >>= parseZonedInstant)
    <*> value .:? "review_cooldown_until"
    <*> (value .: "status" >>= parseWaitStatus)
    <*> value .: "activated_at"
    <*> value .: "deferral_count"
    <*> value .: "revision"

waitSuccessorValue :: WaitSuccessor -> Value
waitSuccessorValue successor =
  object
    [ "wait_id" .= renderUUIDv7 (waitSuccessorWait successor)
    , "enabling_brick_id" .= renderUUIDv7 (waitSuccessorEnablingBrick successor)
    , "affected_brick_id" .= renderUUIDv7 (waitSuccessorAffectedBrick successor)
    , "kind" .= waitKindValue (waitSuccessorKind successor)
    , "review_delay_seconds" .= waitSuccessorReviewDelaySeconds successor
    , "declared_at" .= waitSuccessorDeclaredAt successor
    ]

parseWaitSuccessor :: Value -> Parser WaitSuccessor
parseWaitSuccessor = withObject "WaitSuccessor" $ \value ->
  WaitSuccessor
    <$> (value .: "wait_id" >>= parseId)
    <*> (value .: "enabling_brick_id" >>= parseId)
    <*> (value .: "affected_brick_id" >>= parseId)
    <*> (value .: "kind" >>= parseWaitKind)
    <*> value .: "review_delay_seconds"
    <*> value .: "declared_at"

waitKindValue :: WaitKind -> Value
waitKindValue = \case
  HumanResponseWait entity -> object ["type" .= ("human_response" :: Text), "entity_id" .= renderUUIDv7 entity]
  ExternalConditionWait condition -> object ["type" .= ("external_condition" :: Text), "condition" .= condition]

parseWaitKind :: Value -> Parser WaitKind
parseWaitKind = withObject "WaitKind" $ \value ->
  value .: "type" >>= \case
    ("human_response" :: Text) -> HumanResponseWait <$> (value .: "entity_id" >>= parseId)
    "external_condition" -> ExternalConditionWait <$> value .: "condition"
    other -> fail ("unknown Wait kind: " <> Text.unpack other)

waitStatusText :: WaitStatus -> Text
waitStatusText = \case
  WaitActive -> "active"
  WaitResolved -> "resolved"
  WaitCancelled -> "cancelled"

parseWaitStatus :: Text -> Parser WaitStatus
parseWaitStatus = \case
  "active" -> pure WaitActive
  "resolved" -> pure WaitResolved
  "cancelled" -> pure WaitCancelled
  value -> fail ("unknown Wait status: " <> Text.unpack value)

waitObservationValue :: WaitObservation -> Value
waitObservationValue observation =
  object $
    [ "observation_id" .= renderUUIDv7 (waitObservationId observation)
    , "wait_id" .= renderUUIDv7 (waitObservationWait observation)
    , "kind" .= waitObservationKindText (waitObservationKind observation)
    , "observed_at" .= waitObservationAt observation
    , "actor" .= waitObservationActor observation
    ]
      <> maybe [] (pure . ("note" .=)) (waitObservationNote observation)

parseWaitObservation :: Value -> Parser WaitObservation
parseWaitObservation = withObject "WaitObservation" $ \value ->
  WaitObservation
    <$> (value .: "observation_id" >>= parseId)
    <*> (value .: "wait_id" >>= parseId)
    <*> (value .: "kind" >>= parseWaitObservationKind)
    <*> value .: "observed_at"
    <*> value .: "actor"
    <*> value .:? "note"

waitObservationKindText :: WaitObservationKind -> Text
waitObservationKindText = \case
  WaitActivatedObservation -> "activated"
  WaitResponseReceivedObservation -> "response_received"
  WaitLongerObservation -> "wait_longer"
  WaitFollowUpObservation -> "follow_up"
  WaitReviewSkippedObservation -> "review_skipped"
  WaitReclassifiedObservation -> "reclassified"

parseWaitObservationKind :: Text -> Parser WaitObservationKind
parseWaitObservationKind = \case
  "activated" -> pure WaitActivatedObservation
  "response_received" -> pure WaitResponseReceivedObservation
  "wait_longer" -> pure WaitLongerObservation
  "follow_up" -> pure WaitFollowUpObservation
  "review_skipped" -> pure WaitReviewSkippedObservation
  "reclassified" -> pure WaitReclassifiedObservation
  value -> fail ("unknown Wait observation kind: " <> Text.unpack value)

delegationValue :: Delegation -> Value
delegationValue delegation =
  object $
    [ "delegation_id" .= renderUUIDv7 (delegationId delegation)
    , "brick_id" .= renderUUIDv7 (delegationBrick delegation)
    , "target_id" .= renderUUIDv7 (delegationTarget delegation)
    , "scope" .= delegationScopeText (delegationScope delegation)
    , "follow_up_policy" .= followUpPolicyText (delegationFollowUpPolicy delegation)
    , "review_delay_seconds" .= delegationReviewDelaySeconds delegation
    , "status" .= delegationStatusText (delegationStatus delegation)
    , "message" .= delegationMessage delegation
    , "follow_up_handoffs" .= delegationFollowUpHandoffs delegation
    , "extra_follow_ups" .= delegationExtraFollowUps delegation
    , "revision" .= delegationRevision delegation
    ]
      <> maybe [] (pure . ("review_not_before" .=) . zonedInstantValue) (delegationReviewNotBefore delegation)
      <> maybe [] (pure . ("last_observation" .=)) (delegationLastObservation delegation)
      <> maybe [] (pure . ("last_observed_at" .=)) (delegationLastObservedAt delegation)
      <> maybe [] (pure . ("initial_handoff_at" .=)) (delegationInitialHandoffAt delegation)

parseDelegation :: Value -> Parser Delegation
parseDelegation = withObject "Delegation" $ \value ->
  Delegation
    <$> (value .: "delegation_id" >>= parseId)
    <*> (value .: "brick_id" >>= parseId)
    <*> (value .: "target_id" >>= parseId)
    <*> (value .: "scope" >>= parseDelegationScope)
    <*> (value .: "follow_up_policy" >>= parseFollowUpPolicy)
    <*> value .: "review_delay_seconds"
    <*> (value .:? "review_not_before" >>= traverse parseZonedInstant)
    <*> (value .: "status" >>= parseDelegationStatus)
    <*> value .: "message"
    <*> value .:? "last_observation"
    <*> value .:? "last_observed_at"
    <*> value .:? "initial_handoff_at"
    <*> value .: "follow_up_handoffs"
    <*> value .: "extra_follow_ups"
    <*> value .: "revision"

delegationScopeText :: DelegationScope -> Text
delegationScopeText BrickOnlyDelegation = "brick_only"
delegationScopeText WholeScopeDelegation = "whole_scope"

parseDelegationScope :: Text -> Parser DelegationScope
parseDelegationScope "brick_only" = pure BrickOnlyDelegation
parseDelegationScope "whole_scope" = pure WholeScopeDelegation
parseDelegationScope value = fail ("unknown Delegation scope: " <> Text.unpack value)

followUpPolicyText :: FollowUpPolicy -> Text
followUpPolicyText FollowUpOnce = "once"
followUpPolicyText FollowUpEvery = "every"
followUpPolicyText FollowUpNone = "none"

parseFollowUpPolicy :: Text -> Parser FollowUpPolicy
parseFollowUpPolicy "once" = pure FollowUpOnce
parseFollowUpPolicy "every" = pure FollowUpEvery
parseFollowUpPolicy "none" = pure FollowUpNone
parseFollowUpPolicy value = fail ("unknown follow-up policy: " <> Text.unpack value)

delegationStatusText :: DelegationStatus -> Text
delegationStatusText = Text.toLower . Text.drop (Text.length ("Delegation" :: Text)) . Text.pack . show

parseDelegationStatus :: Text -> Parser DelegationStatus
parseDelegationStatus = \case
  "proposed" -> pure DelegationProposed
  "active" -> pure DelegationActive
  "completed" -> pure DelegationCompleted
  "refused" -> pure DelegationRefused
  "takenback" -> pure DelegationTakenBack
  "cancelled" -> pure DelegationCancelled
  "reassigned" -> pure DelegationReassigned
  value -> fail ("unknown Delegation status: " <> Text.unpack value)

externalEffectRequestDigest :: ExternalEffectRequest -> Text
externalEffectRequestDigest = digestJson . externalEffectRequestValue

externalEffectConsentDigest :: ExternalEffect -> Text
externalEffectConsentDigest effect =
  digestJson $
    object $
      [ "effect_id" .= renderUUIDv7 (externalEffectId effect)
      , "request" .= externalEffectRequestValue (externalEffectRequest effect)
      , "purpose" .= externalEffectPurposeText (externalEffectPurpose effect)
      , "revision" .= externalEffectRevision effect
      , "redacted_preview" .= externalEffectRedactedPreview effect
      , "payload_digest" .= externalEffectPayloadDigest effect
      , "originating_command" .= renderUUIDv7 (externalEffectOriginatingCommand effect)
      , "originating_cursor" .= externalEffectOriginatingCursor effect
      ]
        <> maybe [] (pure . ("idempotency_key" .=)) (externalEffectIdempotencyKey effect)

digestJson :: Value -> Text
digestJson = TextEncoding.decodeUtf8 . Base16.encode . SHA256.hash . LazyByteString.toStrict . encode

allUnique :: (Ord value) => [value] -> Bool
allUnique values = Set.size (Set.fromList values) == length values

validSha256 :: Text -> Bool
validSha256 digest = Text.length digest == 64 && Text.all lowerHex digest
 where
  lowerHex character = isAscii character && (isDigit character || (character >= 'a' && character <= 'f'))

externalEffectValue :: ExternalEffect -> Value
externalEffectValue effect =
  object $
    [ "effect_id" .= renderUUIDv7 (externalEffectId effect)
    , "request" .= externalEffectRequestValue (externalEffectRequest effect)
    , "purpose" .= externalEffectPurposeText (externalEffectPurpose effect)
    , "revision" .= externalEffectRevision effect
    , "record_version" .= externalEffectRecordVersion effect
    , "redacted_preview" .= externalEffectRedactedPreview effect
    , "payload_digest" .= externalEffectPayloadDigest effect
    , "originating_command" .= renderUUIDv7 (externalEffectOriginatingCommand effect)
    , "originating_cursor" .= externalEffectOriginatingCursor effect
    , "status" .= externalEffectStatusText (externalEffectStatus effect)
    ]
      <> maybe [] (pure . ("idempotency_key" .=)) (externalEffectIdempotencyKey effect)
      <> maybe [] (pure . ("review_not_before" .=) . zonedInstantValue) (externalEffectReviewNotBefore effect)
      <> maybe [] (pure . ("approval_grant_id" .=) . renderUUIDv7) (externalEffectApprovalGrant effect)
      <> maybe [] (pure . ("approved_digest" .=)) (externalEffectApprovedDigest effect)

parseExternalEffect :: Value -> Parser ExternalEffect
parseExternalEffect = withObject "ExternalEffect" $ \value -> do
  request <- value .: "request" >>= parseExternalEffectRequest
  declaredPurpose <- value .: "purpose" >>= parseExternalEffectPurpose
  effect <-
    ExternalEffect
      <$> (value .: "effect_id" >>= parseId)
      <*> pure request
      <*> value .: "revision"
      <*> value .: "record_version"
      <*> value .: "redacted_preview"
      <*> value .: "payload_digest"
      <*> (value .: "originating_command" >>= parseId)
      <*> value .: "originating_cursor"
      <*> value .:? "idempotency_key"
      <*> (value .: "status" >>= parseExternalEffectStatus)
      <*> (value .:? "review_not_before" >>= traverse parseZonedInstant)
      <*> (value .:? "approval_grant_id" >>= traverse parseId)
      <*> value .:? "approved_digest"
  unless (externalEffectPurpose effect == declaredPurpose) $ fail "ExternalEffect purpose differs from its typed request"
  pure effect

externalEffectRequestValue :: ExternalEffectRequest -> Value
externalEffectRequestValue = \case
  DelegationDeliveryRequest delegationId reason targetId contactId adapter message ->
    object $
      [ "kind" .= ("delegation_delivery" :: Text)
      , "delegation_id" .= renderUUIDv7 delegationId
      , "reason" .= delegationDeliveryReasonText reason
      , "target_id" .= renderUUIDv7 targetId
      , "message" .= message
      ]
        <> maybe [] (pure . ("contact_id" .=) . renderUUIDv7) contactId
        <> maybe [] (pure . ("adapter" .=)) adapter
  DelegationTakeBackNoticeRequest delegationId targetId contactId adapter message ->
    object $
      [ "kind" .= ("delegation_take_back_notice" :: Text)
      , "delegation_id" .= renderUUIDv7 delegationId
      , "target_id" .= renderUUIDv7 targetId
      , "message" .= message
      ]
        <> maybe [] (pure . ("contact_id" .=) . renderUUIDv7) contactId
        <> maybe [] (pure . ("adapter" .=)) adapter
  SourceCleanupItemRequest custody target ->
    object
      [ "kind" .= ("source_cleanup_item" :: Text)
      , "adapter" .= effectAdapterCustodyValue custody
      , "target" .= sourceCleanupItemTargetValue target
      ]
  SourceCleanupContainerRequest custody target ->
    object
      [ "kind" .= ("source_cleanup_container" :: Text)
      , "adapter" .= effectAdapterCustodyValue custody
      , "target" .= sourceCleanupContainerTargetValue target
      ]

parseExternalEffectRequest :: Value -> Parser ExternalEffectRequest
parseExternalEffectRequest = withObject "ExternalEffectRequest" $ \value -> do
  kind <- value .: "kind" :: Parser Text
  case kind of
    "delegation_delivery" ->
      DelegationDeliveryRequest
        <$> (value .: "delegation_id" >>= parseId)
        <*> (value .: "reason" >>= parseDelegationDeliveryReason)
        <*> (value .: "target_id" >>= parseId)
        <*> (value .:? "contact_id" >>= traverse parseId)
        <*> value .:? "adapter"
        <*> value .: "message"
    "delegation_take_back_notice" ->
      DelegationTakeBackNoticeRequest
        <$> (value .: "delegation_id" >>= parseId)
        <*> (value .: "target_id" >>= parseId)
        <*> (value .:? "contact_id" >>= traverse parseId)
        <*> value .:? "adapter"
        <*> value .: "message"
    "source_cleanup_item" -> SourceCleanupItemRequest <$> (value .: "adapter" >>= parseEffectAdapterCustody) <*> (value .: "target" >>= parseSourceCleanupItemTarget)
    "source_cleanup_container" -> SourceCleanupContainerRequest <$> (value .: "adapter" >>= parseEffectAdapterCustody) <*> (value .: "target" >>= parseSourceCleanupContainerTarget)
    _ -> fail ("unknown ExternalEffect request kind: " <> Text.unpack kind)

effectAdapterCustodyValue :: EffectAdapterCustody -> Value
effectAdapterCustodyValue custody =
  object
    [ "component_id" .= effectAdapterComponentId custody
    , "contract_major" .= effectAdapterContractMajor custody
    , "provider_account" .= effectAdapterProviderAccount custody
    , "credential_binding" .= effectAdapterCredentialBinding custody
    , "pack_publisher" .= effectAdapterPackPublisher custody
    , "pack_name" .= effectAdapterPackName custody
    , "pack_version" .= effectAdapterPackVersion custody
    , "pack_manifest_digest" .= effectAdapterPackManifestDigest custody
    , "pack_archive_digest" .= effectAdapterPackArchiveDigest custody
    , "signer_fingerprint" .= effectAdapterSignerFingerprint custody
    ]

parseEffectAdapterCustody :: Value -> Parser EffectAdapterCustody
parseEffectAdapterCustody = withObject "EffectAdapterCustody" $ \value ->
  EffectAdapterCustody
    <$> value .: "component_id"
    <*> value .: "contract_major"
    <*> value .: "provider_account"
    <*> value .: "credential_binding"
    <*> value .: "pack_publisher"
    <*> value .: "pack_name"
    <*> value .: "pack_version"
    <*> value .: "pack_manifest_digest"
    <*> value .: "pack_archive_digest"
    <*> value .: "signer_fingerprint"

sourceCleanupItemTargetValue :: SourceCleanupItemTarget -> Value
sourceCleanupItemTargetValue target =
  object $
    [ "import_invocation_id" .= renderUUIDv7 (cleanupItemImportInvocation target)
    , "source_binding_id" .= renderUUIDv7 (cleanupItemSourceBinding target)
    , "raw_id" .= renderUUIDv7 (cleanupItemRaw target)
    , "external_identity" .= cleanupItemExternalIdentity target
    , "locator" .= cleanupItemLocator target
    ]
      <> maybe [] (pure . ("container_identity" .=)) (cleanupItemContainerIdentity target)

parseSourceCleanupItemTarget :: Value -> Parser SourceCleanupItemTarget
parseSourceCleanupItemTarget = withObject "SourceCleanupItemTarget" $ \value ->
  SourceCleanupItemTarget
    <$> (value .: "import_invocation_id" >>= parseId)
    <*> (value .: "source_binding_id" >>= parseId)
    <*> (value .: "raw_id" >>= parseId)
    <*> value .: "external_identity"
    <*> value .: "locator"
    <*> value .:? "container_identity"

sourceCleanupContainerTargetValue :: SourceCleanupContainerTarget -> Value
sourceCleanupContainerTargetValue target =
  object
    [ "import_profile_id" .= renderUUIDv7 (cleanupContainerImportProfile target)
    , "import_invocation_id" .= renderUUIDv7 (cleanupContainerImportInvocation target)
    , "external_identity" .= cleanupContainerExternalIdentity target
    , "label" .= cleanupContainerLabel target
    , "inspection_digest" .= cleanupContainerInspectionDigest target
    , "inspected_at" .= cleanupContainerInspectedAt target
    ]

parseSourceCleanupContainerTarget :: Value -> Parser SourceCleanupContainerTarget
parseSourceCleanupContainerTarget = withObject "SourceCleanupContainerTarget" $ \value ->
  SourceCleanupContainerTarget
    <$> (value .: "import_profile_id" >>= parseId)
    <*> (value .: "import_invocation_id" >>= parseId)
    <*> value .: "external_identity"
    <*> value .: "label"
    <*> value .: "inspection_digest"
    <*> value .: "inspected_at"

externalEffectPurposeText :: ExternalEffectPurpose -> Text
externalEffectPurposeText DelegationDeliveryEffect = "delegation_delivery"
externalEffectPurposeText DelegationTakeBackNoticeEffect = "delegation_take_back_notice"
externalEffectPurposeText SourceCleanupItemEffect = "source_cleanup_item"
externalEffectPurposeText SourceCleanupContainerEffect = "source_cleanup_container"
externalEffectPurposeText CalendarCreateEffect = "calendar_create"
externalEffectPurposeText CalendarUpdateEffect = "calendar_update"
externalEffectPurposeText CalendarCancelEffect = "calendar_cancel"

parseExternalEffectPurpose :: Text -> Parser ExternalEffectPurpose
parseExternalEffectPurpose "delegation_delivery" = pure DelegationDeliveryEffect
parseExternalEffectPurpose "delegation_take_back_notice" = pure DelegationTakeBackNoticeEffect
parseExternalEffectPurpose "source_cleanup_item" = pure SourceCleanupItemEffect
parseExternalEffectPurpose "source_cleanup_container" = pure SourceCleanupContainerEffect
parseExternalEffectPurpose "calendar_create" = pure CalendarCreateEffect
parseExternalEffectPurpose "calendar_update" = pure CalendarUpdateEffect
parseExternalEffectPurpose "calendar_cancel" = pure CalendarCancelEffect
parseExternalEffectPurpose value = fail ("unknown ExternalEffect purpose: " <> Text.unpack value)

delegationDeliveryReasonText :: DelegationDeliveryReason -> Text
delegationDeliveryReasonText InitialDelegationDelivery = "initial"
delegationDeliveryReasonText FollowUpDelegationDelivery = "follow_up"

parseDelegationDeliveryReason :: Text -> Parser DelegationDeliveryReason
parseDelegationDeliveryReason "initial" = pure InitialDelegationDelivery
parseDelegationDeliveryReason "follow_up" = pure FollowUpDelegationDelivery
parseDelegationDeliveryReason value = fail ("unknown Delegation delivery reason: " <> Text.unpack value)

externalEffectStatusText :: ExternalEffectStatus -> Text
externalEffectStatusText = \case
  EffectProposed -> "proposed"
  EffectApproved -> "approved"
  EffectDispatching -> "dispatching"
  EffectSucceeded -> "succeeded"
  EffectFailedRetryable -> "failed_retryable"
  EffectFailedTerminal -> "failed_terminal"
  EffectOutcomeUnknown -> "outcome_unknown"
  EffectRejected -> "rejected"
  EffectWithdrawn -> "withdrawn"

parseExternalEffectStatus :: Text -> Parser ExternalEffectStatus
parseExternalEffectStatus = \case
  "proposed" -> pure EffectProposed
  "approved" -> pure EffectApproved
  "dispatching" -> pure EffectDispatching
  "succeeded" -> pure EffectSucceeded
  "failed_retryable" -> pure EffectFailedRetryable
  "failed_terminal" -> pure EffectFailedTerminal
  "outcome_unknown" -> pure EffectOutcomeUnknown
  "rejected" -> pure EffectRejected
  "withdrawn" -> pure EffectWithdrawn
  value -> fail ("unknown ExternalEffect status: " <> Text.unpack value)

externalEffectApprovalGrantValue :: ExternalEffectApprovalGrant -> Value
externalEffectApprovalGrantValue grant =
  object
    [ "grant_id" .= renderUUIDv7 (externalEffectApprovalGrantId grant)
    , "items" .= fmap externalEffectApprovalItemValue (externalEffectApprovalItems grant)
    , "approved_at" .= externalEffectApprovalAt grant
    , "command_id" .= renderUUIDv7 (externalEffectApprovalCommand grant)
    , "dataset_cursor" .= externalEffectApprovalCursor grant
    ]

externalEffectApprovalItemValue :: ExternalEffectApprovalItem -> Value
externalEffectApprovalItemValue item =
  object
    [ "effect_id" .= renderUUIDv7 (approvedEffectId item)
    , "revision" .= approvedEffectRevision item
    , "digest" .= approvedEffectDigest item
    ]

parseExternalEffectApprovalGrant :: Value -> Parser ExternalEffectApprovalGrant
parseExternalEffectApprovalGrant = withObject "ExternalEffectApprovalGrant" $ \value ->
  ExternalEffectApprovalGrant
    <$> (value .: "grant_id" >>= parseId)
    <*> (value .: "items" >>= traverse parseExternalEffectApprovalItem)
    <*> value .: "approved_at"
    <*> (value .: "command_id" >>= parseId)
    <*> value .: "dataset_cursor"

parseExternalEffectApprovalItem :: Value -> Parser ExternalEffectApprovalItem
parseExternalEffectApprovalItem = withObject "ExternalEffectApprovalItem" $ \value ->
  ExternalEffectApprovalItem
    <$> (value .: "effect_id" >>= parseId)
    <*> value .: "revision"
    <*> value .: "digest"

externalEffectReceiptValue :: ExternalEffectReceipt -> Value
externalEffectReceiptValue receipt =
  object $
    [ "receipt_id" .= renderUUIDv7 (externalEffectReceiptId receipt)
    , "effect_id" .= renderUUIDv7 (externalEffectReceiptEffect receipt)
    , "received_at" .= externalEffectReceiptAt receipt
    , "outcome" .= externalEffectStatusText (externalEffectReceiptOutcome receipt)
    ]
      <> maybe [] (pure . ("provider_reference" .=)) (externalEffectReceiptProviderReference receipt)
      <> maybe [] (pure . ("redacted_detail" .=)) (externalEffectReceiptRedactedDetail receipt)

parseExternalEffectReceipt :: Value -> Parser ExternalEffectReceipt
parseExternalEffectReceipt = withObject "ExternalEffectReceipt" $ \value ->
  ExternalEffectReceipt
    <$> (value .: "receipt_id" >>= parseId)
    <*> (value .: "effect_id" >>= parseId)
    <*> value .: "received_at"
    <*> (value .: "outcome" >>= parseExternalEffectStatus)
    <*> value .:? "provider_reference"
    <*> value .:? "redacted_detail"

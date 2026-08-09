module LittleAnt.Decision (
  DraftImportanceAnswer (..),
  BreakDraft (..),
  FeedDecision (..),
  ImportAcceptanceDecision (..),
  MutationDecision (..),
  UndoDecision (..),
  WorkDraft (..),
  RecurrenceReleaseFact (..),
  HabitWindowFact (..),
  HabitExpiryFact (..),
  TemporalTickPlan (..),
  decideCompleteBrick,
  decideArchiveBrick,
  decideRestoreBrick,
  decideKeepArchived,
  archiveUUIDCount,
  restoreUUIDCount,
  decideBreakBrick,
  decideAddDependency,
  decideDomainFocus,
  completionUUIDCount,
  supportsChildParts,
  decideDeferRawTriage,
  decideFeed,
  decideAppendRawRevision,
  decideAcceptEnglishNormalization,
  decideAcceptBrickTitleNormalization,
  decideAttachSourceBinding,
  decideAcceptFileImport,
  importAcceptanceUUIDCount,
  decideChangeSourceBinding,
  decideRecordSourceObservation,
  decideAcceptSourceObservationAsRevision,
  decideDeriveSourceObservation,
  decideIgnoreSourceObservation,
  decideFocusBrick,
  decideRecordedFocus,
  decidePauseFocus,
  decideStartSprint,
  decideWorkReaction,
  decideKeepRawStandalone,
  decideCreateRawShelf,
  decidePlaceRawOnShelf,
  decideMaterializeListEntry,
  decideReuseListEntry,
  decideAddListEntryQuantity,
  decideStartChecklistRun,
  decideChangeListEntryState,
  decideFinishChecklistRun,
  finishChecklistRunUUIDCount,
  decideSetTemporalConstraints,
  prepareRepeatableReturn,
  decideSetRepeatableReturn,
  decideSetScheduledInterval,
  decideScheduledOutcome,
  decideSetRecurrenceSchedule,
  decideSetHabitSchedule,
  decideSetOperationalDayConfig,
  decideNoticeDisposition,
  decideHabitWindowOutcome,
  decideTemporalTick,
  temporalTickUUIDCount,
  decideRegisterExternalEntity,
  decideAddContactPoint,
  decideActivateWait,
  decideCreateRequestHandoff,
  decideReviewWait,
  decideProposeDelegation,
  decideReviseProposedDelegationMessage,
  decideCancelProposedDelegation,
  decideObserveDelegationHandoff,
  decideReviewDelegation,
  decideReviewDelegationWithFollowUp,
  decideAllowDelegationFollowUp,
  decideProposeExternalEffect,
  decideReviseExternalEffect,
  decideApproveExternalEffect,
  decideRejectExternalEffect,
  decideRetryExternalEffect,
  decideDeferExternalEffect,
  decideStartExternalEffectDispatch,
  decideRecordExternalEffectReceipt,
  externalEffectReceiptUUIDCount,
  externalEffectDigest,
  decideAttachRaw,
  decideMaterializeWork,
  decideRawDuplicateNo,
  decideRawDuplicateYes,
  decideReuseExistingWork,
  decideRedoFeed,
  decideUndoFeed,
  statePreconditionHash,
)
where

import Control.Applicative ((<|>))
import Control.Monad (unless, when)
import Data.ByteString qualified as ByteString
import Data.Foldable (traverse_)
import Data.List (maximumBy, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust, isNothing, listToMaybe)
import Data.Ord (comparing)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (UTCTime, addUTCTime)
import LittleAnt.Catalog
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Forecast
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Model
import LittleAnt.Pack.Trust (PackArtifactIdentity (..))
import LittleAnt.Schedule (validateCalendarRule)
import LittleAnt.Source
import LittleAnt.Store (sha256Hex)

{-# ANN module ("HLint: ignore Use when" :: String) #-}

data FeedDecision = FeedDecision
  { feedDecisionCommandId :: UUIDv7
  , feedDecisionRaw :: Raw
  , feedDecisionEvents :: [EventDraft]
  }
  deriving stock (Eq, Show)

data ImportAcceptanceDecision = ImportAcceptanceDecision
  { importAcceptanceCommandId :: Maybe UUIDv7
  , importAcceptanceProfileId :: UUIDv7
  , importAcceptanceInvocationId :: UUIDv7
  , importAcceptanceImportedRaws :: [UUIDv7]
  , importAcceptanceReusedRaws :: [UUIDv7]
  , importAcceptanceEvents :: [EventDraft]
  }
  deriving stock (Eq, Show)

data RecurrenceReleaseFact = RecurrenceReleaseFact
  { releaseFactOwner :: UUIDv7
  , releaseFactAnchor :: ZonedInstant
  , releaseFactLabel :: Text
  , releaseFactTemporal :: TemporalConstraints
  , releaseFactInterval :: Maybe (ZonedInstant, ZonedInstant)
  }
  deriving stock (Eq, Show)

data HabitWindowFact = HabitWindowFact
  { habitWindowFactOwner :: UUIDv7
  , habitWindowFactOpensAt :: ZonedInstant
  , habitWindowFactClosesAt :: ZonedInstant
  , habitWindowFactTarget :: Int
  , habitWindowFactScheduleRevision :: Int
  , habitWindowFactExpiredUnits :: Int
  }
  deriving stock (Eq, Show)

data HabitExpiryFact = HabitExpiryFact
  { habitExpiryWindow :: UUIDv7
  , habitExpiryOwner :: UUIDv7
  , habitExpiryUnits :: Int
  , habitExpiryOutcome :: StandingOutcomeKind
  }
  deriving stock (Eq, Show)

data TemporalTickPlan = TemporalTickPlan
  { temporalTickReleases :: [RecurrenceReleaseFact]
  , temporalTickNewHabitWindows :: [HabitWindowFact]
  , temporalTickHabitExpiries :: [HabitExpiryFact]
  }
  deriving stock (Eq, Show)

data UndoDecision = UndoDecision
  { undoDecisionCommandId :: UUIDv7
  , undoDecisionTargetCommandId :: UUIDv7
  , undoDecisionRaw :: Raw
  , undoDecisionEvents :: [EventDraft]
  }
  deriving stock (Eq, Show)

data DraftImportanceAnswer
  = DraftAbove UUIDv7
  | DraftBelow UUIDv7
  deriving stock (Eq, Ord, Show)

data BreakDraft = BreakDraft
  { breakDraftBrick :: UUIDv7
  , breakDraftTargetNature :: Maybe BrickNature
  , breakDraftTitles :: [Text]
  , breakDraftServedSelection :: Maybe UUIDv7
  , breakDraftSymptom :: Maybe SkipSymptom
  }
  deriving stock (Eq, Show)

data WorkDraft = WorkDraft
  { workDraftRawId :: UUIDv7
  , workDraftTitle :: Text
  , workDraftNature :: BrickNature
  , workDraftTemplate :: Maybe TemplateSelection
  , workDraftParent :: Maybe UUIDv7
  , workDraftDomains :: Set UUIDv7
  , workDraftSiblingPosition :: Int
  , workDraftImportanceConfidence :: ImportanceConfidence
  , workDraftComparisons :: [DraftImportanceAnswer]
  }
  deriving stock (Eq, Show)

data MutationDecision = MutationDecision
  { mutationDecisionCommandId :: UUIDv7
  , mutationDecisionBrick :: Maybe Brick
  , mutationDecisionRaw :: Maybe Raw
  , mutationDecisionEvents :: [EventDraft]
  }
  deriving stock (Eq, Show)

statePreconditionHash :: State -> Text
statePreconditionHash state =
  sha256Hex . Text.encodeUtf8 . Text.intercalate "\n" $
    rawLines
      <> dispositionLines
      <> rejectionLines
      <> brickLines
      <> shelfLines
      <> entryLines
      <> linkLines
      <> judgmentLines
      <> reviewLines
      <> dependencyLines
      <> deferralLines
      <> domainLines
      <> focusLines
      <> temporalScheduleLines
      <> responsibilityLines
 where
  rawLines =
    [ "raw:"
        <> renderUUIDv7 (rawId raw)
        <> ":"
        <> unHandle (rawHandle raw)
        <> ":"
        <> Text.pack (show (rawStatus raw))
        <> ":"
        <> Text.pack (show (rawRevision raw))
    | raw <- Map.elems (stateRaws state)
    ]
  dispositionLines =
    ["disposition:" <> renderUUIDv7 identity <> ":" <> Text.pack (show disposition) | (identity, disposition) <- Map.toAscList (stateRawDispositions state)]
  rejectionLines = ["duplicate-rejected:" <> Text.pack (show evidence) | evidence <- Set.toAscList (stateRejectedRawDuplicates state)]
  brickLines =
    [ "brick:"
        <> renderUUIDv7 (brickId brick)
        <> ":"
        <> unHandle (brickHandle brick)
        <> ":"
        <> Text.pack (show (brickStatus brick, brickWorkState brick, brickParent brick, brickSiblingPosition brick))
    | brick <- Map.elems (stateBricks state)
    ]
  shelfLines = ["raw-shelf:" <> renderUUIDv7 identity <> ":" <> Text.pack (show (rawShelfName shelf, rawShelfActive shelf, rawShelfMembers shelf)) | (identity, shelf) <- Map.toAscList (stateRawShelves state)]
  entryLines = ["list-entry:" <> renderUUIDv7 identity <> ":" <> Text.pack (show (listEntryOwner entry, listEntryLabel entry, listEntryQuantity entry, listEntryState entry)) | (identity, entry) <- Map.toAscList (stateListEntries state)]
  linkLines =
    ["raw-link:" <> renderUUIDv7 (rawLinkId link) <> ":" <> Text.pack (show (rawLinkRaw link, rawLinkTarget link, rawLinkRole link)) | link <- Map.elems (stateRawLinks state)]
  judgmentLines =
    ["pair-judgment:" <> renderUUIDv7 identity <> ":" <> Text.pack (show judgment) | (identity, judgment) <- Map.toAscList (statePairJudgments state)]
      <> ["impact:" <> renderUUIDv7 identity <> ":" <> Text.pack (show claim) | (identity, claim) <- Map.toAscList (stateImpactClaims state)]
      <> ["effort:" <> renderUUIDv7 identity <> ":" <> Text.pack (show claim) | (identity, claim) <- Map.toAscList (stateEffortClaims state)]
      <> ["phase:" <> renderUUIDv7 identity <> ":" <> Text.pack (show claim) | (identity, claim) <- Map.toAscList (statePhaseClaims state)]
  reviewLines =
    ["lazy-review:" <> renderUUIDv7 identity <> ":" <> Text.pack (show claim) | (identity, claim) <- Map.toAscList (stateLazyReviews state)]
  dependencyLines =
    ["dependency:" <> renderUUIDv7 identity <> ":" <> Text.pack (show dependency) | (identity, dependency) <- Map.toAscList (stateDependencies state)]
      <> ["checklist-run:" <> renderUUIDv7 identity <> ":" <> Text.pack (show run) | (identity, run) <- Map.toAscList (stateChecklistRuns state)]
      <> ["temporal:" <> renderUUIDv7 identity <> ":" <> Text.pack (show constraints) | (identity, constraints) <- Map.toAscList (stateTemporalConstraints state)]
      <> ["standing-outcome:" <> renderUUIDv7 identity <> ":" <> Text.pack (show outcome) | (identity, outcome) <- Map.toAscList (stateStandingOutcomes state)]
      <> ["return-schedule:" <> renderUUIDv7 identity <> ":" <> Text.pack (show schedule) | (identity, schedule) <- Map.toAscList (stateReturnSchedules state)]
      <> ["scheduled-interval:" <> renderUUIDv7 identity <> ":" <> Text.pack (show interval) | (identity, interval) <- Map.toAscList (stateScheduledIntervals state)]
  deferralLines =
    ["deferral:" <> renderUUIDv7 identity <> ":" <> Text.pack (show deferral) | (identity, deferral) <- Map.toAscList (stateWorkDeferrals state)]
  domainLines =
    ["domain:" <> renderUUIDv7 identity <> ":" <> Text.pack (show domain) | (identity, domain) <- Map.toAscList (stateDomains state)]
  focusLines =
    [ "focus:" <> maybe "idle" renderUUIDv7 (stateCurrentFocus state)
    , "active-domain:" <> maybe "none" renderUUIDv7 (stateActiveDomain state)
    , "domain-scope:" <> Text.pack (show (stateDomainScope state))
    , "active-sprint:" <> Text.pack (show (stateActiveSprint state))
    , "forecast-cursors:" <> Text.pack (show (stateRandomCursors state))
    , "forecast-count:" <> Text.pack (show (Map.size (stateForecastSelections state)))
    ]
  temporalScheduleLines =
    [ "recurrence-schedules:" <> Text.pack (show (Map.toAscList (stateRecurrenceSchedules state)))
    , "recurring-occurrences:" <> Text.pack (show (Map.toAscList (stateRecurringOccurrences state)))
    , "habit-schedules:" <> Text.pack (show (Map.toAscList (stateHabitSchedules state)))
    , "habit-windows:" <> Text.pack (show (Map.toAscList (stateHabitWindows state)))
    , "habit-outcomes:" <> Text.pack (show (Map.toAscList (stateHabitOutcomes state)))
    , "notice-dispositions:" <> Text.pack (show (Map.toAscList (stateNoticeDispositions state)))
    , "operational-day:" <> Text.pack (show (stateOperationalDayConfig state))
    ]
  responsibilityLines =
    [ "external-entities:" <> Text.pack (show (Map.toAscList (stateExternalEntities state)))
    , "contact-points:" <> Text.pack (show (Map.toAscList (stateContactPoints state)))
    , "waits:" <> Text.pack (show (Map.toAscList (stateWaits state)))
    , "wait-observations:" <> Text.pack (show (Map.toAscList (stateWaitObservations state)))
    , "delegations:" <> Text.pack (show (Map.toAscList (stateDelegations state)))
    , "external-effects:" <> Text.pack (show (Map.toAscList (stateExternalEffects state)))
    , "external-effect-receipts:" <> Text.pack (show (Map.toAscList (stateExternalEffectReceipts state)))
    , "raw-content-revisions:" <> Text.pack (show (Map.toAscList (stateRawContentRevisions state)))
    , "english-normalizations:" <> Text.pack (show (Map.toAscList (stateEnglishNormalizations state)))
    , "brick-title-normalizations:" <> Text.pack (show (Map.toAscList (stateBrickTitleNormalizations state)))
    , "import-profiles:" <> Text.pack (show (Map.toAscList (stateImportProfiles state)))
    , "import-invocations:" <> Text.pack (show (Map.toAscList (stateImportInvocations state)))
    , "source-bindings:" <> Text.pack (show (Map.toAscList (stateSourceBindings state)))
    , "source-observations:" <> Text.pack (show (Map.toAscList (stateSourceObservations state)))
    , "source-reconciliations:" <> Text.pack (show (Map.toAscList (stateSourceReconciliations state)))
    ]

decideFeed :: State -> Actor -> Text -> Text -> RuntimeFacts -> Either AppError FeedDecision
decideFeed state actor origin material facts
  | Text.null (Text.strip material) =
      Left $
        (appError InvalidInput "Feed material cannot be empty.")
          { appErrorRecovery = [RecoveryAction "edit" "Enter nonempty material and submit again." Nothing]
          }
  | otherwise = do
      identities <- requireUUIDs 3 facts
      (commandId, eventId, identity) <- case identities of
        [commandIdentity, eventIdentity, rawIdentity] -> Right (commandIdentity, eventIdentity, rawIdentity)
        _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
      let handle = allocateHandle RawHandle (stateRetiredRawHandles state) (rawSeed material)
          payload = RawFed identity handle material origin Nothing
          event = makeDraft facts actor state identities eventId commandId (RawFedV1 payload)
          raw = Raw identity handle material (runtimeNow facts) actor RawAwaitingReview 1 commandId
      pure (FeedDecision commandId raw [event])

decideAppendRawRevision :: State -> Actor -> UUIDv7 -> RawContent -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideAppendRawRevision state actor rawId content provenance facts = do
  raw <- requirePreservedRaw state rawId
  unless (rawStatus raw /= RawRetracted) $ Left (appError PreconditionFailed "A retracted Raw cannot receive a content revision.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let payload = RawContentRevisionAppended rawId (rawRevision raw + 1) (Text.strip provenance) content (rawContentDigest content)
      event = makeDraft facts actor state allocated eventId commandId (RawContentRevisionAppendedV1 payload)
  pure (MutationDecision commandId Nothing (Just raw) [event])

decideAcceptEnglishNormalization :: State -> Actor -> UUIDv7 -> Text -> NormalizationSource -> Maybe Text -> Maybe Fixed -> RuntimeFacts -> Either AppError MutationDecision
decideAcceptEnglishNormalization state actor revisionId normalized source producer confidence facts = do
  revision <- maybe (Left (appError NotFound "No Raw content revision matches that identity.")) Right (Map.lookup revisionId (stateRawContentRevisions state))
  unless (Map.lookup (rawContentRevisionRaw revision) (stateCurrentRawRevisions state) == Just revisionId) $ Left (appError PreconditionFailed "Only the current Raw revision can receive a new current English normalization.")
  case rawContentRevisionContent revision of
    RawTextContent{} -> pure ()
    _ -> Left (appError PreconditionFailed "Non-text Raw material requires an explicit textual extraction before English normalization.")
  unless (not (Text.null (Text.strip normalized))) $ Left (appError InvalidInput "English normalization cannot be empty.")
  traverse_ (\value -> unless (value >= Fixed 0 && value <= Fixed 1000000) (Left (appError InvalidInput "Normalization confidence must be within [0,1]."))) confidence
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let payload = EnglishNormalizationAccepted revisionId (Text.strip normalized) source (Text.strip <$> producer) confidence
      event = makeDraft facts actor state allocated eventId commandId (EnglishNormalizationAcceptedV1 payload)
  pure (MutationDecision commandId Nothing (Map.lookup (rawContentRevisionRaw revision) (stateRaws state)) [event])

decideAcceptBrickTitleNormalization :: State -> Actor -> UUIDv7 -> Text -> NormalizationSource -> Maybe Text -> Maybe Fixed -> RuntimeFacts -> Either AppError MutationDecision
decideAcceptBrickTitleNormalization state actor brickId normalized source producer confidence facts = do
  brick <- maybe (Left (appError NotFound "No Brick matches that identity.")) Right (Map.lookup brickId (stateBricks state))
  unless (not (Text.null (Text.strip normalized))) $ Left (appError InvalidInput "A normalized Brick title cannot be empty.")
  traverse_ (\value -> unless (value >= Fixed 0 && value <= Fixed 1000000) (Left (appError InvalidInput "Title-normalization confidence must be within [0,1]."))) confidence
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let payload = BrickTitleNormalizationAccepted brickId (brickTitle brick) (Text.strip normalized) source (Text.strip <$> producer) confidence
      event = makeDraft facts actor state allocated eventId commandId (BrickTitleNormalizationAcceptedV1 payload)
  pure (MutationDecision commandId Nothing Nothing [event])

decideAttachSourceBinding :: State -> Actor -> UUIDv7 -> Text -> Maybe UUIDv7 -> Maybe Text -> Maybe Text -> Text -> SourceMode -> SourceCheckPolicy -> RuntimeFacts -> Either AppError MutationDecision
decideAttachSourceBinding state actor rawId kind importProfile externalIdentity containerIdentity locator mode policy facts = do
  raw <- requirePreservedRaw state rawId
  validateSourceBindingInput kind locator policy
  allocated <- requireUUIDs 3 facts
  (commandId, bindingId, eventId) <- exactlyThree allocated
  let binding = SourceBinding bindingId rawId (Text.strip kind) importProfile (Text.strip <$> externalIdentity) (Text.strip <$> containerIdentity) (Text.strip locator) mode policy SourceBindingActive Nothing 1
      event = makeDraft facts actor state allocated eventId commandId (SourceBindingChangedV1 (SourceBindingChanged binding))
  pure (MutationDecision commandId Nothing (Just raw) [event])

importAcceptanceUUIDCount :: State -> Text -> SourcePreflight -> Either AppError Int
importAcceptanceUUIDCount state sourceReference preflight = do
  (sourceObject, _) <- validatePlainTextAcceptance sourceReference preflight
  profile <- uniqueMatchingProfile state sourceReference preflight
  case profile of
    Nothing -> pure 9
    Just existingProfile -> do
      invocation <- uniqueMatchingInvocation state (importProfileId existingProfile) preflight
      case invocation of
        Just prior -> validateExistingInvocation state sourceObject prior >> pure 0
        Nothing -> do
          existing <- existingImportedRaw state (Just (importProfileId existingProfile)) preflight sourceObject
          pure (if isJust existing then 3 else 7)

decideAcceptFileImport :: State -> Actor -> Text -> SourceInput -> SourcePreflight -> RuntimeFacts -> Either AppError ImportAcceptanceDecision
decideAcceptFileImport state actor sourceReference input preflight facts = do
  (sourceObject, identity) <- validatePlainTextAcceptance sourceReference preflight
  content <- validateInputCustody input preflight
  profileMatch <- uniqueMatchingProfile state sourceReference preflight
  priorInvocation <- case profileMatch of
    Nothing -> pure Nothing
    Just profile -> uniqueMatchingInvocation state (importProfileId profile) preflight
  case (profileMatch, priorInvocation) of
    (Just profile, Just invocation) -> do
      raw <- validateExistingInvocation state sourceObject invocation
      pure (ImportAcceptanceDecision Nothing (importProfileId profile) (importInvocationId invocation) [] [rawId raw] [])
    _ -> do
      existing <- case profileMatch of
        Nothing -> pure Nothing
        Just profile -> existingImportedRaw state (Just (importProfileId profile)) preflight sourceObject
      let allocationCount = case (profileMatch, existing) of
            (Nothing, Nothing) -> 9
            (Just _, Nothing) -> 7
            (Just _, Just _) -> 3
            (Nothing, Just _) -> 0
      when (allocationCount == 0) $ Left (appError CorruptData "An imported Raw exists without its owning ImportProfile.")
      allocated <- requireUUIDs allocationCount facts
      case allocated of
        commandId : remainder -> do
          (profile, profileEvents, afterProfile) <- allocateProfile allocated commandId remainder profileMatch
          (invocationId, invocationEventId, objectAllocations) <- takeInvocationAllocation afterProfile
          (objectEvents, mapping, imported, reused) <- allocateObject sourceObject content allocated commandId profile objectAllocations existing
          let invocation = buildInvocation invocationId profile mapping identity
              invocationEvent = makeDraft facts actor state allocated invocationEventId commandId (ImportInvocationRecordedV1 (ImportInvocationRecorded invocation))
              events = profileEvents <> objectEvents <> [invocationEvent]
          pure (ImportAcceptanceDecision (Just commandId) (importProfileId profile) invocationId imported reused events)
        [] -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
 where
  allocateProfile allocated commandId remainder profileMatch = case profileMatch of
    Just profile -> pure (profile, [], remainder)
    Nothing -> case remainder of
      profileId : profileEventId : objectAllocations -> do
        let observation = sourcePreflightObservation preflight
            profile =
              ImportProfile
                profileId
                (sourcePreflightAdapterId preflight)
                (observedSourceLabel observation)
                (observedAccountLabel observation)
                (Text.strip sourceReference)
                (sourcePreflightMode preflight)
                (observedCleanupSupported observation)
                ImportProfileActive
                1
            event = makeDraft facts actor state allocated profileEventId commandId (ImportProfileChangedV1 (ImportProfileChanged profile))
        pure (profile, [event], objectAllocations)
      _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  takeInvocationAllocation = \case
    invocationId : invocationEventId : rest -> Right (invocationId, invocationEventId, rest)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  allocateObject sourceObject content allocated commandId profile objectAllocations = \case
    Just raw -> do
      unless (null objectAllocations) $ Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
      pure ([], ImportObjectMapping (sourceObjectExternalId sourceObject) (rawId raw) ImportReusedRaw, [], [rawId raw])
    Nothing -> do
      (rawIdValue, rawEventId, bindingId, bindingEventId) <- exactlyFour objectAllocations
      let rawHandleValue = allocateHandle RawHandle (stateRetiredRawHandles state) (rawSeed (sourceObjectTitle sourceObject))
          rawPayload = RawFed rawIdValue rawHandleValue (sourceObjectTitle sourceObject) ("import:" <> sourcePreflightAdapterId preflight) (Just content)
          binding =
            SourceBinding
              bindingId
              rawIdValue
              (sourcePreflightAdapterId preflight)
              (Just (importProfileId profile))
              (Just (sourceObjectExternalId sourceObject))
              (sourceObjectContainerId sourceObject)
              (sourceObjectLocator sourceObject)
              (sourcePreflightMode preflight)
              SourceManualCheck
              SourceBindingActive
              Nothing
              1
          events =
            [ makeDraft facts actor state allocated rawEventId commandId (RawFedV1 rawPayload)
            , makeDraft facts actor state allocated bindingEventId commandId (SourceBindingChangedV1 (SourceBindingChanged binding))
            ]
      pure (events, ImportObjectMapping (sourceObjectExternalId sourceObject) rawIdValue ImportCreatedRaw, [rawIdValue], [])
  buildInvocation invocationId profile mapping packIdentity =
    ImportInvocation
      invocationId
      (importProfileId profile)
      (sourcePreflightAdapterId preflight)
      (sourcePreflightContractMajor preflight)
      (sourcePreflightPermissions preflight)
      (sourcePreflightInputLabel preflight)
      (sourcePreflightInputMediaType preflight)
      (sourcePreflightInputDigest preflight)
      (sourcePreflightInputByteCount preflight)
      (sourcePreflightMode preflight)
      (artifactPublisher packIdentity)
      (artifactName packIdentity)
      (artifactVersion packIdentity)
      (artifactManifestDigest packIdentity)
      (artifactArchiveDigest packIdentity)
      (sourcePreflightSignerFingerprint preflight)
      [mapping]

validatePlainTextAcceptance :: Text -> SourcePreflight -> Either AppError (SourceObject, PackArtifactIdentity)
validatePlainTextAcceptance sourceReference preflight = do
  unless (not (Text.null (Text.strip sourceReference))) $ Left (appError InvalidInput "An import source reference cannot be empty.")
  unless (sourcePreflightAdapterId preflight == "plain_text") $ Left (appError Unsupported "This acceptance boundary currently supports only the signed plain-text SourceAdapter.")
  sourceObject <- case observedObjects (sourcePreflightObservation preflight) of
    [candidate] -> Right candidate
    _ -> Left (appError CorruptData "The plain-text SourceAdapter must describe exactly one source object.")
  unless (sourceObjectShape sourceObject == SourceNoteShape) $ Left (appError CorruptData "The plain-text SourceAdapter returned a non-note object shape.")
  unless (sourceMaterialKind (sourceObjectMaterial sourceObject) == SourceTextKind) $ Left (appError CorruptData "The plain-text SourceAdapter returned non-text material.")
  pure (sourceObject, sourcePreflightPackIdentity preflight)

validateInputCustody :: SourceInput -> SourcePreflight -> Either AppError RawContent
validateInputCustody input preflight = do
  unless (sourceInputLabel input == sourcePreflightInputLabel preflight) $ stale "The selected input label changed after preflight."
  unless (sourceInputMediaType input == sourcePreflightInputMediaType preflight) $ stale "The selected input media type changed after preflight."
  unless (sha256Hex (sourceInputBytes input) == sourcePreflightInputDigest preflight) $ stale "The selected input bytes changed after preflight."
  unless (lengthBytes == sourcePreflightInputByteCount preflight) $ stale "The selected input byte count changed after preflight."
  text <- either (const (Left (appError CorruptData "The plain-text import input is not valid UTF-8."))) Right (Text.decodeUtf8' (sourceInputBytes input))
  let material = summarizeSourceMaterial (SourceTextMaterial text)
  sourceObject <- case observedObjects (sourcePreflightObservation preflight) of
    [candidate] -> Right candidate
    _ -> Left (appError CorruptData "The plain-text SourceAdapter must describe exactly one source object.")
  unless (sourceObjectMaterial sourceObject == material) $ stale "The source material no longer matches its preflight summary."
  pure (RawTextContent text)
 where
  lengthBytes = ByteString.length (sourceInputBytes input)
  stale message =
    Left
      ( (appError Conflict message)
          { appErrorRecovery = [RecoveryAction "refresh-preflight" "Regenerate the import preview from the current source." Nothing]
          }
      )

uniqueMatchingProfile :: State -> Text -> SourcePreflight -> Either AppError (Maybe ImportProfile)
uniqueMatchingProfile state sourceReference preflight =
  case filter matches (Map.elems (stateImportProfiles state)) of
    [] -> Right Nothing
    [profile] -> Right (Just profile)
    _ -> Left (appError CorruptData "Several active ImportProfiles claim the same source scope.")
 where
  matches profile =
    importProfileAdapterId profile == sourcePreflightAdapterId preflight
      && importProfileInputReference profile == Text.strip sourceReference
      && importProfileMode profile == sourcePreflightMode preflight
      && importProfileLifecycle profile == ImportProfileActive

uniqueMatchingInvocation :: State -> UUIDv7 -> SourcePreflight -> Either AppError (Maybe ImportInvocation)
uniqueMatchingInvocation state profileId preflight =
  case filter matches (Map.elems (stateImportInvocations state)) of
    [] -> Right Nothing
    [invocation] -> Right (Just invocation)
    _ -> Left (appError CorruptData "Several ImportInvocations claim the same exact input custody.")
 where
  identity = sourcePreflightPackIdentity preflight
  matches invocation =
    importInvocationProfileId invocation == profileId
      && importInvocationComponentId invocation == sourcePreflightAdapterId preflight
      && importInvocationContractMajor invocation == sourcePreflightContractMajor preflight
      && importInvocationPermissions invocation == sourcePreflightPermissions preflight
      && importInvocationInputLabel invocation == sourcePreflightInputLabel preflight
      && importInvocationInputMediaType invocation == sourcePreflightInputMediaType preflight
      && importInvocationInputDigest invocation == sourcePreflightInputDigest preflight
      && importInvocationInputByteCount invocation == sourcePreflightInputByteCount preflight
      && importInvocationMode invocation == sourcePreflightMode preflight
      && importInvocationPackPublisher invocation == artifactPublisher identity
      && importInvocationPackName invocation == artifactName identity
      && importInvocationPackVersion invocation == artifactVersion identity
      && importInvocationPackManifestDigest invocation == artifactManifestDigest identity
      && importInvocationPackArchiveDigest invocation == artifactArchiveDigest identity
      && importInvocationSignerFingerprint invocation == sourcePreflightSignerFingerprint preflight

validateExistingInvocation :: State -> SourceObject -> ImportInvocation -> Either AppError Raw
validateExistingInvocation state sourceObject invocation =
  case importInvocationMappings invocation of
    [mapping]
      | importObjectExternalIdentity mapping == sourceObjectExternalId sourceObject -> do
          raw <- maybe (Left (appError CorruptData "An ImportInvocation maps to a missing Raw.")) Right (Map.lookup (importObjectRawId mapping) (stateRaws state))
          validateImportedMaterial state sourceObject raw
          pure raw
    _ -> Left (appError CorruptData "An exact plain-text ImportInvocation has an inconsistent object mapping.")

existingImportedRaw :: State -> Maybe UUIDv7 -> SourcePreflight -> SourceObject -> Either AppError (Maybe Raw)
existingImportedRaw _ Nothing _ _ = Right Nothing
existingImportedRaw state (Just profileId) preflight sourceObject =
  case matchingBindings of
    [] -> Right Nothing
    [binding] -> do
      raw <- maybe (Left (appError CorruptData "An imported SourceBinding points to a missing Raw.")) Right (Map.lookup (sourceBindingRaw binding) (stateRaws state))
      validateImportedMaterial state sourceObject raw
      pure (Just raw)
    _ -> Left (appError CorruptData "Several SourceBindings claim one external identity inside the same ImportProfile.")
 where
  matchingBindings =
    [ binding
    | binding <- Map.elems (stateSourceBindings state)
    , sourceBindingImportProfile binding == Just profileId
    , sourceBindingKind binding == sourcePreflightAdapterId preflight
    , sourceBindingExternalIdentity binding == Just (sourceObjectExternalId sourceObject)
    ]

validateImportedMaterial :: State -> SourceObject -> Raw -> Either AppError ()
validateImportedMaterial state sourceObject raw = do
  revisionId <- maybe (Left (appError CorruptData "An imported Raw has no current material revision.")) Right (Map.lookup (rawId raw) (stateCurrentRawRevisions state))
  revision <- maybe (Left (appError CorruptData "An imported Raw current revision is missing.")) Right (Map.lookup revisionId (stateRawContentRevisions state))
  importedDigest <- case rawContentRevisionContent revision of
    RawTextContent text -> Right (sourceMaterialDigest (summarizeSourceMaterial (SourceTextMaterial text)))
    _ -> Left (appError CorruptData "A plain-text SourceBinding points to non-text Raw material.")
  unless (importedDigest == sourceMaterialDigest (sourceObjectMaterial sourceObject)) $
    Left (appError Conflict "The source identity already maps to different local Raw material; reconcile it instead of importing a duplicate.")

decideChangeSourceBinding :: State -> Actor -> UUIDv7 -> Text -> SourceCheckPolicy -> SourceBindingLifecycle -> Maybe UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideChangeSourceBinding state actor bindingId locator policy lifecycle baseline facts = do
  binding <- maybe (Left (appError NotFound "No SourceBinding matches that identity.")) Right (Map.lookup bindingId (stateSourceBindings state))
  validateSourceBindingInput (sourceBindingKind binding) locator policy
  traverse_ validateBaseline baseline
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed = binding{sourceBindingLocator = Text.strip locator, sourceBindingCheckPolicy = policy, sourceBindingLifecycle = lifecycle, sourceBindingAcceptedObservation = baseline, sourceBindingRevision = sourceBindingRevision binding + 1}
      event = makeDraft facts actor state allocated eventId commandId (SourceBindingChangedV1 (SourceBindingChanged changed))
  pure (MutationDecision commandId Nothing (Map.lookup (sourceBindingRaw binding) (stateRaws state)) [event])
 where
  validateBaseline observationId = do
    observation <- maybe (Left (appError NotFound "The accepted SourceObservation is missing.")) Right (Map.lookup observationId (stateSourceObservations state))
    unless (sourceObservationBinding observation == bindingId) $ Left (appError InvalidInput "The accepted baseline belongs to another SourceBinding.")
    when (sourceObservationOutcome observation == SourceChanged && not (sourceObservationIsReconciled state observationId)) $
      Left (appError PreconditionFailed "A changed SourceObservation must be reconciled before it becomes the accepted baseline.")

decideRecordSourceObservation :: State -> Actor -> UUIDv7 -> Text -> SourceObservationOutcome -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe RawContent -> RuntimeFacts -> Either AppError MutationDecision
decideRecordSourceObservation state actor bindingId locator outcome providerVersion fingerprint snapshotDigest snapshot facts = do
  binding <- maybe (Left (appError NotFound "No SourceBinding matches that identity.")) Right (Map.lookup bindingId (stateSourceBindings state))
  unless (sourceBindingLifecycle binding /= SourceBindingDetached) $ Left (appError PreconditionFailed "A detached SourceBinding cannot be checked.")
  unless (not (Text.null (Text.strip locator))) $ Left (appError InvalidInput "A SourceObservation locator cannot be empty.")
  when (any (pendingChangedObservation state bindingId) (Map.elems (stateSourceObservations state))) $
    Left (appError PreconditionFailed "Reconcile the pending changed SourceObservation before checking this binding again.")
  case (outcome, snapshot, snapshotDigest) of
    (SourceChanged, Just content, Just digest) -> unless (rawContentDigest content == digest) $ Left (appError Conflict "The SourceObservation snapshot digest does not match its canonical material.")
    (SourceChanged, _, _) -> Left (appError InvalidInput "A changed SourceObservation requires canonical snapshot material and its digest.")
    (_, Just content, Just digest) -> unless (rawContentDigest content == digest) $ Left (appError Conflict "The SourceObservation snapshot digest does not match its canonical material.")
    (_, Just _, Nothing) -> Left (appError InvalidInput "Canonical SourceObservation snapshot material requires its digest.")
    _ -> pure ()
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let payload = SourceObservationRecorded bindingId (Text.strip locator) outcome providerVersion fingerprint snapshotDigest snapshot
      event = makeDraft facts actor state allocated eventId commandId (SourceObservationRecordedV1 payload)
  pure (MutationDecision commandId Nothing (Map.lookup (sourceBindingRaw binding) (stateRaws state)) [event])

decideAcceptSourceObservationAsRevision :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideAcceptSourceObservationAsRevision state actor observationId facts = do
  (observation, binding, raw, content) <- requirePendingChangedObservation state observationId
  allocated <- requireUUIDs 4 facts
  (commandId, revisionEventId, reconciliationEventId, bindingEventId) <- exactlyFour allocated
  let revisionPayload = RawContentRevisionAppended (rawId raw) (rawRevision raw + 1) ("source:" <> sourceBindingKind binding) content (rawContentDigest content)
      reconciliation = SourceObservationReconciled observationId (SourceAcceptedAsRevision revisionEventId)
      changedBinding = binding{sourceBindingAcceptedObservation = Just observationId, sourceBindingRevision = sourceBindingRevision binding + 1}
      events =
        [ makeDraft facts actor state allocated revisionEventId commandId (RawContentRevisionAppendedV1 revisionPayload)
        , makeDraft facts actor state allocated reconciliationEventId commandId (SourceObservationReconciledV1 reconciliation)
        , makeDraft facts actor state allocated bindingEventId commandId (SourceBindingChangedV1 (SourceBindingChanged changedBinding))
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

decideDeriveSourceObservation :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideDeriveSourceObservation state actor observationId facts = do
  (observation, binding, sourceRaw, content) <- requirePendingChangedObservation state observationId
  allocated <- requireUUIDs 7 facts
  (commandId, derivedRawId, fedEventId, linkId, linkEventId, reconciliationEventId, bindingEventId) <- exactlySeven allocated
  let original = rawContentHumanLabel content
      handle = allocateHandle RawHandle (stateRetiredRawHandles state) (rawSeed original)
      derivedRaw = Raw derivedRawId handle original (runtimeNow facts) actor RawAwaitingReview 1 commandId
      fed = RawFed derivedRawId handle original ("source:" <> sourceBindingKind binding) (Just content)
      link = RawLinkAdded linkId derivedRawId (RawLinkRaw (rawId sourceRaw)) DerivedFromRole
      reconciliation = SourceObservationReconciled observationId (SourceAcceptedAsDerivedRaw derivedRawId)
      changedBinding = binding{sourceBindingAcceptedObservation = Just observationId, sourceBindingRevision = sourceBindingRevision binding + 1}
      events =
        [ makeDraft facts actor state allocated fedEventId commandId (RawFedV1 fed)
        , makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated reconciliationEventId commandId (SourceObservationReconciledV1 reconciliation)
        , makeDraft facts actor state allocated bindingEventId commandId (SourceBindingChangedV1 (SourceBindingChanged changedBinding))
        ]
  pure (MutationDecision commandId Nothing (Just derivedRaw) events)

decideIgnoreSourceObservation :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideIgnoreSourceObservation state actor observationId facts = do
  (_, binding, raw, _) <- requirePendingChangedObservation state observationId
  allocated <- requireUUIDs 3 facts
  (commandId, reconciliationEventId, bindingEventId) <- exactlyThree allocated
  let reconciliation = SourceObservationReconciled observationId SourceIgnoredAsUnrelated
      changedBinding = binding{sourceBindingAcceptedObservation = Just observationId, sourceBindingRevision = sourceBindingRevision binding + 1}
      events =
        [ makeDraft facts actor state allocated reconciliationEventId commandId (SourceObservationReconciledV1 reconciliation)
        , makeDraft facts actor state allocated bindingEventId commandId (SourceBindingChangedV1 (SourceBindingChanged changedBinding))
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

requirePendingChangedObservation :: State -> UUIDv7 -> Either AppError (SourceObservation, SourceBinding, Raw, RawContent)
requirePendingChangedObservation state observationId = do
  observation <- maybe (Left (appError NotFound "No SourceObservation matches that identity.")) Right (Map.lookup observationId (stateSourceObservations state))
  binding <- maybe (Left (appError CorruptData "The SourceObservation binding is missing.")) Right (Map.lookup (sourceObservationBinding observation) (stateSourceBindings state))
  raw <- requirePreservedRaw state (sourceBindingRaw binding)
  unless (sourceBindingLifecycle binding /= SourceBindingDetached) $ Left (appError PreconditionFailed "A detached SourceBinding cannot be reconciled.")
  unless (sourceObservationOutcome observation == SourceChanged) $ Left (appError PreconditionFailed "Only a changed SourceObservation can become a new Raw revision.")
  when (sourceObservationIsReconciled state observationId) $ Left (appError Conflict "This SourceObservation has already been reconciled.")
  content <- maybe (Left (appError CorruptData "The changed SourceObservation has no canonical snapshot material.")) Right (sourceObservationSnapshot observation)
  pure (observation, binding, raw, content)

pendingChangedObservation :: State -> UUIDv7 -> SourceObservation -> Bool
pendingChangedObservation state bindingId observation =
  sourceObservationBinding observation == bindingId
    && sourceObservationOutcome observation == SourceChanged
    && not (sourceObservationIsReconciled state (sourceObservationId observation))

sourceObservationIsReconciled :: State -> UUIDv7 -> Bool
sourceObservationIsReconciled state observationId =
  any ((== observationId) . sourceReconciliationObservation) (Map.elems (stateSourceReconciliations state))

rawContentHumanLabel :: RawContent -> Text
rawContentHumanLabel = \case
  RawTextContent text -> Text.strip text
  RawUriContent locator label -> fromMaybe locator (Text.strip <$> label)
  RawBlobContent digest _ _ filename -> fromMaybe ("blob " <> Text.take 12 digest) (Text.strip <$> filename)
  RawStructuredContent schema _ -> "structured " <> schema

validateSourceBindingInput :: Text -> Text -> SourceCheckPolicy -> Either AppError ()
validateSourceBindingInput kind locator policy = do
  unless (not (Text.null (Text.strip kind)) && not (Text.null (Text.strip locator))) $ Left (appError InvalidInput "A SourceBinding needs a source kind and locator.")
  case policy of
    SourceIntervalCheck seconds | seconds <= 0 -> Left (appError InvalidInput "A SourceBinding interval must be positive.")
    _ -> pure ()

decideKeepRawStandalone :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideKeepRawStandalone state actor identity facts = do
  raw <- requireInboxRaw state identity
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (RawDispositionAcceptedV1 (RawDispositionAccepted identity RawKeptStandalone))
  pure (MutationDecision commandId Nothing (Just raw) [event])

decideDeferRawTriage :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideDeferRawTriage state actor identity facts = do
  raw <- requireInboxRaw state identity
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let count = Map.findWithDefault 0 identity (stateRawTriageDeferrals state) + 1
      event = makeDraft facts actor state allocated eventId commandId (RawTriageDeferredV1 (RawTriageDeferred identity count))
  pure (MutationDecision commandId Nothing (Just raw) [event])

decideRawDuplicateYes :: State -> Actor -> UUIDv7 -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideRawDuplicateYes state actor candidateId rootId facts = do
  candidate <- requireInboxRaw state candidateId
  _ <- requireActiveRaw state rootId
  if candidateId == rootId
    then Left (appError InvalidInput "A Raw cannot be a duplicate receipt of itself.")
    else pure ()
  allocated <- requireUUIDs 4 facts
  (commandId, linkId, linkEventId, dispositionEventId) <- case allocated of
    [commandIdentity, linkIdentity, firstEvent, secondEvent] -> Right (commandIdentity, linkIdentity, firstEvent, secondEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let link = RawLinkAdded linkId candidateId (RawLinkRaw rootId) DuplicateOfRole
      events =
        [ makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 (RawDispositionAccepted candidateId (RawGroupedAsDuplicate rootId)))
        ]
  pure (MutationDecision commandId Nothing (Just candidate) events)

decideRawDuplicateNo :: State -> Actor -> UUIDv7 -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideRawDuplicateNo state actor candidateId comparedId facts = do
  candidate <- requireInboxRaw state candidateId
  compared <- requireActiveRaw state comparedId
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let payload = RawDuplicateRejected candidateId comparedId (rawRevision candidate) (rawRevision compared)
      event = makeDraft facts actor state allocated eventId commandId (RawDuplicateRejectedV1 payload)
  pure (MutationDecision commandId Nothing (Just candidate) [event])

decideReuseExistingWork :: State -> Actor -> UUIDv7 -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideReuseExistingWork state actor rawIdentity brickIdentity facts = do
  raw <- requireInboxRaw state rawIdentity
  _ <- requireActiveBrick state brickIdentity
  allocated <- requireUUIDs 4 facts
  (commandId, linkId, linkEventId, dispositionEventId) <- case allocated of
    [commandIdentity, linkIdentity, firstEvent, secondEvent] -> Right (commandIdentity, linkIdentity, firstEvent, secondEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let link = RawLinkAdded linkId rawIdentity (RawLinkBrick brickIdentity) MaterializationSourceRole
      disposition = RawDispositionAccepted rawIdentity (RawMaterializedAsWork brickIdentity)
      events =
        [ makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

decideMaterializeWork :: State -> Actor -> WorkDraft -> RuntimeFacts -> Either AppError MutationDecision
decideMaterializeWork state actor draft facts = do
  raw <- requireInboxRaw state (workDraftRawId draft)
  validateWorkDraft state draft
  let comparisonCount = length (workDraftComparisons draft)
  allocated <- requireUUIDs (6 + comparisonCount) facts
  (commandId, brickId, linkId, brickEventId, linkEventId, dispositionEventId, comparisonEventIds) <-
    case allocated of
      commandIdentity : brickIdentity : linkIdentity : firstEvent : secondEvent : thirdEvent : rest
        | length rest == comparisonCount -> Right (commandIdentity, brickIdentity, linkIdentity, firstEvent, secondEvent, thirdEvent, rest)
      _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let handle = allocateHandle BrickHandle (stateRetiredBrickHandles state) (workDraftTitle draft)
      created =
        BrickCreated
          brickId
          handle
          (Text.strip (workDraftTitle draft))
          (workDraftNature draft)
          "factory@1"
          "human"
          (workDraftTemplate draft)
          (workDraftParent draft)
          (workDraftDomains draft)
          (workDraftSiblingPosition draft)
          (workDraftImportanceConfidence draft)
          (rawId raw)
      link = RawLinkAdded linkId (rawId raw) (RawLinkBrick brickId) MaterializationSourceRole
      disposition = RawDispositionAccepted (rawId raw) (RawMaterializedAsWork brickId)
      coreEvents =
        [ makeDraft facts actor state allocated brickEventId commandId (BrickCreatedV1 created)
        , makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
      comparisonEvents =
        zipWith
          (\eventId answer -> makeDraft facts actor state allocated eventId commandId (ImportanceComparedV1 (comparisonPayload brickId answer)))
          comparisonEventIds
          (workDraftComparisons draft)
      brick =
        Brick
          brickId
          handle
          (Text.strip (workDraftTitle draft))
          (workDraftNature draft)
          "factory@1"
          "human"
          (workDraftTemplate draft)
          (workDraftParent draft)
          (workDraftDomains draft)
          (workDraftSiblingPosition draft)
          (workDraftImportanceConfidence draft)
          BrickActive
          Idle
          (runtimeNow facts)
          actor
          commandId
  pure (MutationDecision commandId (Just brick) (Just raw) (coreEvents <> comparisonEvents))

decidePlaceRawOnShelf :: State -> Actor -> UUIDv7 -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decidePlaceRawOnShelf state actor rawIdentity shelfIdentity facts = do
  raw <- requireInboxRaw state rawIdentity
  shelf <- requireActiveShelf state shelfIdentity
  if rawIdentity `elem` rawShelfMembers shelf
    then Left (appError InvalidInput "This Raw is already a member of the selected RawShelf.")
    else pure ()
  allocated <- requireUUIDs 3 facts
  (commandId, membershipEventId, dispositionEventId) <- case allocated of
    [commandIdentity, firstEvent, secondEvent] -> Right (commandIdentity, firstEvent, secondEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let membership = RawShelfMemberAdded shelfIdentity rawIdentity (length (rawShelfMembers shelf))
      disposition = RawDispositionAccepted rawIdentity (RawPlacedOnShelf shelfIdentity)
      events =
        [ makeDraft facts actor state allocated membershipEventId commandId (RawShelfMemberAddedV1 membership)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

decideCreateRawShelf :: State -> Actor -> UUIDv7 -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideCreateRawShelf state actor rawIdentity proposedName facts = do
  raw <- requireInboxRaw state rawIdentity
  let name = Text.strip proposedName
      normalized = Text.toCaseFold name
  if Text.null name
    then Left (appError InvalidInput "A RawShelf name cannot be empty.")
    else pure ()
  if any (\shelf -> rawShelfActive shelf && Text.toCaseFold (rawShelfName shelf) == normalized) (Map.elems (stateRawShelves state))
    then Left (appError InvalidInput "An active RawShelf with that name already exists; choose it instead.")
    else pure ()
  allocated <- requireUUIDs 5 facts
  (commandId, shelfId, shelfEventId, membershipEventId, dispositionEventId) <- case allocated of
    [commandIdentity, shelfIdentity, firstEvent, secondEvent, thirdEvent] -> Right (commandIdentity, shelfIdentity, firstEvent, secondEvent, thirdEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let shelfCreated = RawShelfCreated shelfId name rawIdentity
      membership = RawShelfMemberAdded shelfId rawIdentity 0
      disposition = RawDispositionAccepted rawIdentity (RawPlacedOnShelf shelfId)
      events =
        [ makeDraft facts actor state allocated shelfEventId commandId (RawShelfCreatedV1 shelfCreated)
        , makeDraft facts actor state allocated membershipEventId commandId (RawShelfMemberAddedV1 membership)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

decideFocusBrick :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideMaterializeListEntry :: State -> Actor -> UUIDv7 -> UUIDv7 -> Text -> Quantity -> RuntimeFacts -> Either AppError MutationDecision
decideAttachRaw :: State -> Actor -> UUIDv7 -> UUIDv7 -> RawLinkRole -> RuntimeFacts -> Either AppError MutationDecision
decideAttachRaw state actor rawIdentity targetIdentity role facts = do
  raw <- requireInboxRaw state rawIdentity
  _ <- requireActiveBrick state targetIdentity
  if role == DescriptionRole && any (\link -> rawLinkRole link == DescriptionRole && (rawLinkRaw link == rawIdentity || rawLinkTarget link == RawLinkBrick targetIdentity)) (Map.elems (stateRawLinks state))
    then Left (appError InvalidInput "A description Raw and a described Brick each have cardinality one.")
    else pure ()
  if role `elem` [DescriptionRole, AttachmentRole, EvidenceRole]
    then pure ()
    else Left (appError InvalidInput "This RawLink role is not available in the attachment flow.")
  allocated <- requireUUIDs 4 facts
  (commandId, linkId, linkEventId, dispositionEventId) <- case allocated of
    [commandIdentity, linkIdentity, firstEvent, secondEvent] -> Right (commandIdentity, linkIdentity, firstEvent, secondEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let link = RawLinkAdded linkId rawIdentity (RawLinkBrick targetIdentity) role
      disposition = RawDispositionAccepted rawIdentity (RawAttachedTo targetIdentity role)
      events =
        [ makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

decideMaterializeListEntry state actor rawIdentity ownerIdentity label quantity facts = do
  raw <- requireInboxRaw state rawIdentity
  _ <- requireChecklistOwner state ownerIdentity
  if Text.null (Text.strip label) || quantityCoefficient quantity <= 0 || quantityScale quantity < 0
    then Left (appError InvalidInput "A ListEntry needs a nonempty label and positive normalized quantity.")
    else pure ()
  allocated <- requireUUIDs 6 facts
  (commandId, entryId, linkId, entryEventId, linkEventId, dispositionEventId) <- case allocated of
    [commandIdentity, entryIdentity, linkIdentity, firstEvent, secondEvent, thirdEvent] -> Right (commandIdentity, entryIdentity, linkIdentity, firstEvent, secondEvent, thirdEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let ordinal = length [entry | entry <- Map.elems (stateListEntries state), listEntryOwner entry == ownerIdentity]
      created = ListEntryCreated entryId ownerIdentity (Text.strip label) quantity ordinal rawIdentity
      link = RawLinkAdded linkId rawIdentity (RawLinkListEntry entryId) MaterializationSourceRole
      disposition = RawDispositionAccepted rawIdentity (RawMaterializedAsListEntry ownerIdentity entryId)
      events =
        [ makeDraft facts actor state allocated entryEventId commandId (ListEntryCreatedV1 created)
        , makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

decideReuseListEntry :: State -> Actor -> UUIDv7 -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideReuseListEntry state actor rawIdentity entryIdentity facts = do
  raw <- requireInboxRaw state rawIdentity
  entry <- requireOpenListEntry state entryIdentity
  allocated <- requireUUIDs 4 facts
  (commandId, linkId, linkEventId, dispositionEventId) <- case allocated of
    [commandIdentity, linkIdentity, firstEvent, secondEvent] -> Right (commandIdentity, linkIdentity, firstEvent, secondEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let link = RawLinkAdded linkId rawIdentity (RawLinkListEntry entryIdentity) MaterializationSourceRole
      disposition = RawDispositionAccepted rawIdentity (RawMaterializedAsListEntry (listEntryOwner entry) entryIdentity)
      events =
        [ makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

decideAddListEntryQuantity :: State -> Actor -> UUIDv7 -> UUIDv7 -> Quantity -> RuntimeFacts -> Either AppError MutationDecision
decideAddListEntryQuantity state actor rawIdentity entryIdentity fedQuantity facts = do
  raw <- requireInboxRaw state rawIdentity
  entry <- requireOpenListEntry state entryIdentity
  combined <- addQuantity (listEntryQuantity entry) fedQuantity
  allocated <- requireUUIDs 5 facts
  (commandId, linkId, quantityEventId, linkEventId, dispositionEventId) <- case allocated of
    [commandIdentity, linkIdentity, firstEvent, secondEvent, thirdEvent] -> Right (commandIdentity, linkIdentity, firstEvent, secondEvent, thirdEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let changed = ListEntryQuantityChanged entryIdentity rawIdentity (listEntryQuantity entry) combined
      link = RawLinkAdded linkId rawIdentity (RawLinkListEntry entryIdentity) MaterializationSourceRole
      disposition = RawDispositionAccepted rawIdentity (RawMaterializedAsListEntry (listEntryOwner entry) entryIdentity)
      events =
        [ makeDraft facts actor state allocated quantityEventId commandId (ListEntryQuantityChangedV1 changed)
        , makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        ]
  pure (MutationDecision commandId Nothing (Just raw) events)

requireChecklistOwner :: State -> UUIDv7 -> Either AppError Brick
requireChecklistOwner state identity = do
  owner <- requireActiveBrick state identity
  if brickNature owner `elem` [LivingChecklist, FiniteChecklist]
    then Right owner
    else Left (appError InvalidInput "The selected Brick does not own ListEntries.")

requireOpenListEntry :: State -> UUIDv7 -> Either AppError ListEntry
requireOpenListEntry state identity = case Map.lookup identity (stateListEntries state) of
  Just entry | listEntryState entry == EntryOpen -> Right entry
  _ -> Left (appError NotFound "No open ListEntry matches the requested identity.")

addQuantity :: Quantity -> Quantity -> Either AppError Quantity
addQuantity first second
  | quantityScale first /= quantityScale second || quantityUnit first /= quantityUnit second =
      Left (appError InvalidInput "ListEntry quantities can be added only when their normalized scale and unit match.")
  | otherwise = Right first{quantityCoefficient = quantityCoefficient first + quantityCoefficient second}

decideStartChecklistRun :: State -> Actor -> UUIDv7 -> Maybe UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideSetTemporalConstraints :: State -> Actor -> UUIDv7 -> Maybe ZonedInstant -> Maybe ZonedInstant -> Maybe ZonedInstant -> RuntimeFacts -> Either AppError MutationDecision
decideSetTemporalConstraints state actor identity notBefore bestBefore deadline facts = do
  brick <- requireActiveBrick state identity
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let revision = maybe 1 ((+ 1) . temporalRevision) (Map.lookup identity (stateTemporalConstraints state))
      payload = TemporalConstraintsChanged identity notBefore bestBefore deadline revision
      event = makeDraft facts actor state allocated eventId commandId (TemporalConstraintsChangedV1 payload)
  pure (MutationDecision commandId (Just brick) Nothing [event])

prepareRepeatableReturn ::
  State ->
  UUIDv7 ->
  ReturnPolicy ->
  (UTCTime -> ReturnUnit -> Int -> Either AppError (ZonedInstant, Text)) ->
  RuntimeFacts ->
  Either AppError RepeatableReturnSet
prepareRepeatableReturn state ownerId policy resolveInstant facts = do
  owner <- requireActiveBrick state ownerId
  unless (brickNature owner == Repeatable) $
    Left (appError PreconditionFailed "Only a repeatable Brick has a completion-relative return policy.")
  completedAt <-
    case sortOn standingOutcomeAt [outcome | outcome <- Map.elems (stateStandingOutcomes state), standingOutcomeOwner outcome == ownerId, standingOutcomeKind outcome == StandingDone] of
      [] -> Left (appError PreconditionFailed "A return policy requires a recorded completed run.")
      outcomes -> Right (standingOutcomeAt (last outcomes))
  schedule completedAt
 where
  schedule completedAt = case policy of
    ManualOnlyReturn ->
      Right (RepeatableReturnSet ownerId policy Nothing Nothing Nothing Nothing Nothing)
    AfterCompletionReturn center unit variation zone -> do
      unless (center > 0 && variation >= 0 && variation <= center && not (Text.null (Text.strip zone))) $
        Left (appError InvalidInput "A return needs a positive center, a variation no larger than the center, and an IANA zone.")
      seed <-
        maybe
          (Left (appError PreconditionFailed "A repeatable return needs one 32-byte random seed fact."))
          Right
          (stateRandomSeed state <|> (Map.lookup RepeatableReturnJitter (runtimeRandomBlocks facts) >>= listToMaybe))
      let offsets = [center - variation .. center + variation]
          candidates = fmap returnCandidate offsets
          cursor = Map.findWithDefault 0 (randomPurposeName RepeatableReturnJitter) (stateRandomCursors state)
      record <-
        either
          (Left . appError CorruptData)
          Right
          (sampleRecorded factoryForecastProfile seed cursor RepeatableReturnJitter candidates)
      let chosen = drawChosenSubject record
          evidence =
            ForecastDrawEvidence
              (randomPurposeName (drawPurpose record))
              [(drawCandidateIdentity candidate, drawCandidateWeight candidate) | candidate <- drawCandidates record]
              (drawTotal record)
              (drawStartingCursor record)
              (drawEndingCursor record)
              (drawSampledInteger record)
              (drawChosenIdentity record)
      (notBefore, resolution) <- resolveInstant completedAt unit chosen
      unless (zonedInstantZone notBefore == zone) $
        Left (appError CorruptData "The return resolver changed the policy IANA zone.")
      Right (RepeatableReturnSet ownerId policy (Just chosen) (Just notBefore) (Just resolution) (Just seed) (Just evidence))
   where
    returnCandidate offset =
      WeightedCandidate
        (Text.pack (show offset))
        offset
        1
        (Fixed 1_000_000)
        (Fixed 0)
        (Fixed 0)
        (Fixed 0)
        (Fixed 0)
        Nothing
        []

decideSetRepeatableReturn ::
  State ->
  Actor ->
  UUIDv7 ->
  RepeatableReturnSet ->
  RuntimeFacts ->
  Either AppError MutationDecision
decideSetRepeatableReturn state actor reviewId scheduled facts = do
  let ownerId = repeatableReturnOwner scheduled
  owner <- requireActiveBrick state ownerId
  unless (brickNature owner == Repeatable) $
    Left (appError PreconditionFailed "Only a repeatable Brick has a completion-relative return policy.")
  review <-
    maybe
      (Left (appError PreconditionFailed "The repeatable completion checkpoint is missing or already settled."))
      Right
      (Map.lookup reviewId (stateLazyReviews state))
  unless (lazyReviewSubject review == ownerId && lazyReviewKind review == "repeatable_return_policy") $
    Left (appError PreconditionFailed "The selected review is not this repeatable completion checkpoint.")
  allocated <- requireUUIDs 3 facts
  (commandId, policyEventId, settleEventId) <- case allocated of
    [commandIdentity, policyIdentity, settleIdentity] -> Right (commandIdentity, policyIdentity, settleIdentity)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let policyEvent = makeDraft facts actor state allocated policyEventId commandId (RepeatableReturnSetV1 scheduled)
      settled = makeDraft facts actor state allocated settleEventId commandId (LazyReviewSettledV1 (LazyReviewSettled reviewId "return_policy_set"))
  pure (MutationDecision commandId (Just owner) Nothing [policyEvent, settled])

decideSetScheduledInterval :: State -> Actor -> UUIDv7 -> ZonedInstant -> ZonedInstant -> RuntimeFacts -> Either AppError MutationDecision
decideSetScheduledInterval state actor ownerId startsAt endsAt facts = do
  owner <- requireActiveBrick state ownerId
  unless (brickNature owner == ScheduledCommitment) $
    Left (appError PreconditionFailed "Only a scheduled-commitment Brick owns an exact interval.")
  unless (zonedInstantUtc endsAt > zonedInstantUtc startsAt) $
    Left (appError InvalidInput "A scheduled commitment must end after it starts.")
  unless (all (not . Text.null . Text.strip . zonedInstantZone) [startsAt, endsAt]) $
    Left (appError InvalidInput "Both scheduled endpoints need named IANA display zones.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let revision = maybe 1 ((+ 1) . scheduledIntervalRevision) (Map.lookup ownerId (stateScheduledIntervals state))
      event = makeDraft facts actor state allocated eventId commandId (ScheduledIntervalSetV1 (ScheduledIntervalSet ownerId startsAt endsAt revision))
  pure (MutationDecision commandId (Just owner) Nothing [event])

decideScheduledOutcome :: State -> Actor -> UUIDv7 -> StandingOutcomeKind -> RuntimeFacts -> Either AppError MutationDecision
decideScheduledOutcome state actor ownerId outcome facts = do
  owner <- requireActiveBrick state ownerId
  unless (brickNature owner == ScheduledCommitment) $
    Left (appError PreconditionFailed "Only a scheduled commitment accepts attended, missed, or cancelled.")
  unless (outcome `elem` [StandingAttended, StandingMissed, StandingCancelled]) $
    Left (appError InvalidInput "Choose attended, missed, or cancelled for this commitment.")
  unless (Map.member ownerId (stateScheduledIntervals state)) $
    Left (appError PreconditionFailed "This scheduled commitment has no exact interval.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (StandingOutcomeRecordedV1 (StandingOutcomeRecorded ownerId outcome))
  pure (MutationDecision commandId (Just owner) Nothing [event])

decideSetRecurrenceSchedule :: State -> Actor -> RecurrenceSchedule -> RuntimeFacts -> Either AppError MutationDecision
decideSetRecurrenceSchedule state actor proposed facts = do
  owner <- requireActiveBrick state (recurrenceOwner proposed)
  unless (brickNature owner == RecurringObligation) $ Left (appError PreconditionFailed "Only a recurring-obligation series accepts a recurrence schedule.")
  validateCalendarRule (recurrenceRule proposed)
  unless (recurrenceOccurrenceNature proposed `elem` [AtomicTask, ScheduledCommitment]) $
    Left (appError InvalidInput "A recurring occurrence must be atomic work or a scheduled commitment.")
  unless (not (Text.null (Text.strip (recurrenceZone proposed)))) $
    Left (appError InvalidInput "A recurrence schedule needs one named IANA timezone.")
  unless (maybe True (> 0) (recurrenceDurationSeconds proposed)) $
    Left (appError InvalidInput "A scheduled occurrence duration must be positive.")
  let revision = maybe 1 ((+ 1) . recurrenceRevision) (Map.lookup (brickId owner) (stateRecurrenceSchedules state))
      schedule = proposed{recurrenceRevision = revision}
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (RecurrenceScheduleSetV1 (RecurrenceScheduleSet schedule))
  pure (MutationDecision commandId (Just owner) Nothing [event])

decideSetHabitSchedule :: State -> Actor -> HabitSchedule -> RuntimeFacts -> Either AppError MutationDecision
decideSetHabitSchedule state actor proposed facts = do
  owner <- requireActiveBrick state (habitScheduleOwner proposed)
  unless (brickNature owner == Habit) $ Left (appError PreconditionFailed "Only a habit accepts a habit schedule.")
  validateHabit proposed
  let revision = maybe 1 ((+ 1) . habitScheduleRevision) (Map.lookup (brickId owner) (stateHabitSchedules state))
      schedule = setHabitRevision revision proposed
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (HabitScheduleSetV1 (HabitScheduleSet schedule))
  pure (MutationDecision commandId (Just owner) Nothing [event])
 where
  setHabitRevision revision = \case
    schedule@FixedSlotHabit{} -> schedule{habitScheduleRevision = revision}
    schedule@QuotaWindowHabit{} -> schedule{habitScheduleRevision = revision}
  validateHabit schedule = do
    unless (not (Text.null (Text.strip (habitScheduleZone schedule)))) $
      Left (appError InvalidInput "A habit schedule needs one named IANA timezone.")
    case schedule of
      FixedSlotHabit{habitFixedRule, habitSlotDurationSeconds} -> do
        validateCalendarRule habitFixedRule
        unless (habitSlotDurationSeconds > 0) $ Left (appError InvalidInput "A fixed habit slot duration must be positive.")
      QuotaWindowHabit{habitQuotaTarget, habitQuotaSpan} -> do
        unless (habitQuotaTarget > 0) $ Left (appError InvalidInput "A habit quota target must be positive.")
        unless (habitQuotaSpan > 0) $ Left (appError InvalidInput "A habit quota span must be positive.")

decideSetOperationalDayConfig :: State -> Actor -> OperationalDayConfig -> RuntimeFacts -> Either AppError MutationDecision
decideSetOperationalDayConfig state actor config facts = do
  unless (not (Text.null (Text.strip (operationalZone config)))) $
    Left (appError InvalidInput "Operational days need one named IANA timezone.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (OperationalDayConfigChangedV1 (OperationalDayConfigChanged config))
  pure (MutationDecision commandId Nothing Nothing [event])

decideRejectExternalEffect :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideRejectExternalEffect state actor identity facts = do
  effect <- requireExternalEffect state identity
  unless (externalEffectStatus effect `elem` [EffectPendingApproval, EffectApproved, EffectFailed, EffectOutcomeUnknown]) $
    Left (appError PreconditionFailed "Only an undispatched or terminally unresolved external effect can be stopped.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed =
        effect
          { externalEffectRevision = externalEffectRevision effect + 1
          , externalEffectStatus = EffectRejected
          , externalEffectReviewNotBefore = Nothing
          , externalEffectApprovedDigest = Nothing
          }
      event = makeDraft facts actor state allocated eventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged changed))
  pure (MutationDecision commandId Nothing Nothing [event])

decideRetryExternalEffect :: State -> Actor -> UUIDv7 -> Bool -> RuntimeFacts -> Either AppError MutationDecision
decideRetryExternalEffect state actor identity duplicateRiskAccepted facts = do
  effect <- requireExternalEffect state identity
  case externalEffectStatus effect of
    EffectFailed -> pure ()
    EffectOutcomeUnknown
      | duplicateRiskAccepted -> pure ()
      | otherwise -> Left (appError PreconditionFailed "Retrying an unknown provider outcome requires explicit duplicate-risk consent.")
    _ -> Left (appError PreconditionFailed "Only a failed or unknown-outcome external effect can enter retry approval.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed =
        effect
          { externalEffectRevision = externalEffectRevision effect + 1
          , externalEffectStatus = EffectPendingApproval
          , externalEffectReviewNotBefore = Nothing
          , externalEffectApprovedDigest = Nothing
          }
      event = makeDraft facts actor state allocated eventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged changed))
  pure (MutationDecision commandId Nothing Nothing [event])

decideDeferExternalEffect :: State -> Actor -> UUIDv7 -> ZonedInstant -> RuntimeFacts -> Either AppError MutationDecision
decideDeferExternalEffect state actor identity reviewAt facts = do
  effect <- requireExternalEffect state identity
  unless (externalEffectStatus effect == EffectPendingApproval) $
    Left (appError PreconditionFailed "Only a pending external effect can be deferred.")
  unless (zonedInstantUtc reviewAt > runtimeNow facts) $
    Left (appError InvalidInput "An external-effect review must be deferred into the future.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed =
        effect
          { externalEffectRevision = externalEffectRevision effect + 1
          , externalEffectReviewNotBefore = Just reviewAt
          }
      event = makeDraft facts actor state allocated eventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged changed))
  pure (MutationDecision commandId Nothing Nothing [event])

decideNoticeDisposition :: State -> Actor -> NoticeIdentity -> NoticeDisposition -> RuntimeFacts -> Either AppError MutationDecision
decideNoticeDisposition state actor notice disposition facts = do
  _ <- requireActiveBrick state (noticeSubject notice)
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (NoticeDispositionChangedV1 (NoticeDispositionChanged notice disposition))
  pure (MutationDecision commandId Nothing Nothing [event])

decideHabitWindowOutcome :: State -> Actor -> UUIDv7 -> StandingOutcomeKind -> RuntimeFacts -> Either AppError MutationDecision
decideHabitWindowOutcome state actor windowId outcome facts = do
  window <- maybe (Left (appError NotFound "The selected habit window does not exist.")) Right (Map.lookup windowId (stateHabitWindows state))
  owner <- requireActiveBrick state (habitWindowOwner window)
  unless (brickNature owner == Habit && not (habitWindowSettled window)) $ Left (appError PreconditionFailed "The selected habit window is not open.")
  unless (outcome `elem` [StandingDone, StandingUnfulfilled, StandingBlocked, StandingPaused, StandingInapplicable]) $
    Left (appError InvalidInput "Choose done, unfulfilled, blocked, paused, or inapplicable for a habit window.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let payload = HabitWindowOutcomeRecorded eventId windowId (brickId owner) outcome
      event = makeDraft facts actor state allocated eventId commandId (HabitWindowOutcomeRecordedV1 payload)
  pure (MutationDecision commandId (Just owner) Nothing [event])

decideTemporalTick :: State -> Actor -> TemporalTickPlan -> RuntimeFacts -> Either AppError (Maybe MutationDecision)
decideTemporalTick state actor plan facts
  | eventCount == 0 = Right Nothing
  | otherwise = do
      allocated <- requireUUIDs allocationCount facts
      (commandId, remaining) <- case allocated of
        identity : rest -> Right (identity, rest)
        [] -> Left (appError PreconditionFailed "The temporal tick has no command identity.")
      (releaseEvents, afterReleases, _) <- buildReleases allocated commandId remaining (stateRetiredBrickHandles state) Map.empty (temporalTickReleases plan)
      (windowEvents, afterWindows) <- buildWindows allocated commandId afterReleases (temporalTickNewHabitWindows plan)
      (expiryEvents, afterExpiries) <- buildExpiries allocated commandId afterWindows (temporalTickHabitExpiries plan)
      unless (null afterExpiries) $ Left (appError PreconditionFailed "The temporal tick UUID allocation count changed unexpectedly.")
      pure (Just (MutationDecision commandId Nothing Nothing (releaseEvents <> windowEvents <> expiryEvents)))
 where
  releaseEventCount = length (temporalTickReleases plan)
  newWindowEventCount = sum [1 + habitWindowFactExpiredUnits fact | fact <- temporalTickNewHabitWindows plan]
  expiryEventCount = sum (fmap habitExpiryUnits (temporalTickHabitExpiries plan))
  eventCount = releaseEventCount + newWindowEventCount + expiryEventCount
  allocationCount = 1 + 2 * releaseEventCount + 2 * length (temporalTickNewHabitWindows plan) + sum (fmap habitWindowFactExpiredUnits (temporalTickNewHabitWindows plan)) + expiryEventCount

  buildReleases _ _ ids handles positions [] = Right ([], ids, (handles, positions))
  buildReleases replay commandId ids handles positions (fact : rest) = do
    (occurrenceId, eventId, remaining) <- takeTwo ids
    owner <- requireActiveBrick state (releaseFactOwner fact)
    schedule <- maybe (Left (appError PreconditionFailed "A tick release references a missing recurrence schedule.")) Right (Map.lookup (brickId owner) (stateRecurrenceSchedules state))
    let handle = allocateHandle BrickHandle handles (brickTitle owner)
        priorPosition = Map.findWithDefault (existingOccurrenceCount (brickId owner)) (brickId owner) positions
        occurrence = RecurringOccurrence occurrenceId (brickId owner) occurrenceId (releaseFactAnchor fact) (releaseFactLabel fact) (recurrenceRevision schedule)
        interval = fmap (\(startsAt, endsAt) -> ScheduledInterval occurrenceId startsAt endsAt 1) (releaseFactInterval fact)
        payload = RecurringOccurrenceReleased occurrence handle (brickTitle owner) (recurrenceOccurrenceNature schedule) (brickDomains owner) priorPosition (releaseFactTemporal fact) interval
        event = makeDraft facts actor state replay eventId commandId (RecurringOccurrenceReleasedV1 payload)
    (later, finalIds, finalState) <- buildReleases replay commandId remaining (Set.insert handle handles) (Map.insert (brickId owner) (priorPosition + 1) positions) rest
    pure (event : later, finalIds, finalState)

  buildWindows _ _ ids [] = Right ([], ids)
  buildWindows replay commandId ids (fact : rest) = do
    (windowId, openEventId, remaining) <- takeTwo ids
    let window = HabitWindow windowId (habitWindowFactOwner fact) (habitWindowFactOpensAt fact) (habitWindowFactClosesAt fact) (habitWindowFactTarget fact) (habitWindowFactScheduleRevision fact) False
        openEvent = makeDraft facts actor state replay openEventId commandId (HabitWindowOpenedV1 (HabitWindowOpened window))
    (outcomeEvents, afterOutcomes) <- buildOutcomeEvents replay commandId remaining windowId (habitWindowFactOwner fact) StandingUnfulfilled (habitWindowFactExpiredUnits fact)
    (later, finalIds) <- buildWindows replay commandId afterOutcomes rest
    pure (openEvent : outcomeEvents <> later, finalIds)

  buildExpiries _ _ ids [] = Right ([], ids)
  buildExpiries replay commandId ids (fact : rest) = do
    (events, remaining) <- buildOutcomeEvents replay commandId ids (habitExpiryWindow fact) (habitExpiryOwner fact) (habitExpiryOutcome fact) (habitExpiryUnits fact)
    (later, finalIds) <- buildExpiries replay commandId remaining rest
    pure (events <> later, finalIds)

  buildOutcomeEvents _ _ ids _ _ _ 0 = Right ([], ids)
  buildOutcomeEvents replay commandId (eventId : remaining) windowId ownerId outcome count = do
    let payload = HabitWindowOutcomeRecorded eventId windowId ownerId outcome
        event = makeDraft facts actor state replay eventId commandId (HabitWindowOutcomeRecordedV1 payload)
    (later, finalIds) <- buildOutcomeEvents replay commandId remaining windowId ownerId outcome (count - 1)
    pure (event : later, finalIds)
  buildOutcomeEvents _ _ [] _ _ _ _ = Left (appError PreconditionFailed "The temporal tick ran out of outcome identities.")

  existingOccurrenceCount ownerId = length [() | occurrence <- Map.elems (stateRecurringOccurrences state), recurringOccurrenceOwner occurrence == ownerId]

  takeTwo = \case
    first : second : rest -> Right (first, second, rest)
    _ -> Left (appError PreconditionFailed "The temporal tick ran out of generated identities.")

temporalTickUUIDCount :: TemporalTickPlan -> Int
temporalTickUUIDCount plan
  | eventCount == 0 = 0
  | otherwise =
      1
        + 2 * length (temporalTickReleases plan)
        + 2 * length (temporalTickNewHabitWindows plan)
        + sum (fmap habitWindowFactExpiredUnits (temporalTickNewHabitWindows plan))
        + sum (fmap habitExpiryUnits (temporalTickHabitExpiries plan))
 where
  eventCount =
    length (temporalTickReleases plan)
      + sum [1 + habitWindowFactExpiredUnits fact | fact <- temporalTickNewHabitWindows plan]
      + sum (fmap habitExpiryUnits (temporalTickHabitExpiries plan))
decideStartChecklistRun state actor ownerIdentity selection facts = do
  owner <- requireChecklistOwner state ownerIdentity
  if Map.member ownerIdentity (stateChecklistRuns state)
    then Left (appError PreconditionFailed "This checklist already has an active run.")
    else pure ()
  activeDomain <- case selection of
    Nothing -> pure Nothing
    Just selectionId -> do
      evidence <- maybe (Left (appError NotFound "The recorded forecast selection no longer exists.")) Right (Map.lookup selectionId (stateForecastSelections state))
      if forecastSelectionEndpointSubject evidence == Just ownerIdentity
        then pure (forecastSelectionDomainPath evidence >>= lastMaybe)
        else Left (appError PreconditionFailed "The proposed checklist does not match the recorded forecast endpoint.")
  allocated <- requireUUIDs 4 facts
  (commandId, runId, focusEventId, runEventId) <- case allocated of
    [commandIdentity, runIdentity, firstEvent, secondEvent] -> Right (commandIdentity, runIdentity, firstEvent, secondEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let focusPayload = case selection of
        Nothing -> BrickFocusedV1 (BrickFocused ownerIdentity)
        Just selectionId -> ForecastFocusAcceptedV1 (ForecastFocusAccepted selectionId ownerIdentity activeDomain)
      events =
        [ makeDraft facts actor state allocated focusEventId commandId focusPayload
        , makeDraft facts actor state allocated runEventId commandId (ChecklistRunStartedV1 (ChecklistRunStarted runId ownerIdentity))
        ]
  pure (MutationDecision commandId (Just owner) Nothing events)
 where
  lastMaybe [] = Nothing
  lastMaybe values = Just (last values)

decideChangeListEntryState :: State -> Actor -> UUIDv7 -> ListEntryState -> RuntimeFacts -> Either AppError MutationDecision
decideChangeListEntryState state actor entryIdentity target facts = do
  entry <- maybe (Left (appError NotFound "No ListEntry matches the requested identity.")) Right (Map.lookup entryIdentity (stateListEntries state))
  run <- maybe (Left (appError PreconditionFailed "Start the checklist run before changing its entries.")) Right (Map.lookup (listEntryOwner entry) (stateChecklistRuns state))
  if allowed (listEntryState entry) target
    then pure ()
    else Left (appError PreconditionFailed "This ListEntry transition is not available from its current state.")
  owner <- requireChecklistOwner state (listEntryOwner entry)
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let payload = ListEntryStateChanged entryIdentity (checklistRunId run) (listEntryState entry) target
      event = makeDraft facts actor state allocated eventId commandId (ListEntryStateChangedV1 payload)
  pure (MutationDecision commandId (Just owner) Nothing [event])
 where
  allowed EntryOpen EntryResolved = True
  allowed EntryOpen EntryCancelled = True
  allowed EntryResolved EntryOpen = True
  allowed EntryCancelled EntryOpen = True
  allowed _ _ = False

decideFinishChecklistRun :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideFinishChecklistRun state actor ownerIdentity facts = do
  owner <- requireChecklistOwner state ownerIdentity
  run <- maybe (Left (appError PreconditionFailed "This checklist has no active run.")) Right (Map.lookup ownerIdentity (stateChecklistRuns state))
  if checklistRunMutationCount run > 0
    then pure ()
    else Left (appError PreconditionFailed "Change at least one checklist entry before finishing this run.")
  let requestClosure = needsScopeClosureReview state owner
      count = finishChecklistRunUUIDCount state ownerIdentity
  allocated <- requireUUIDs count facts
  (commandId, finishEventId, remaining) <- case allocated of
    commandIdentity : eventIdentity : rest -> Right (commandIdentity, eventIdentity, rest)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let finishEvent = makeDraft facts actor state allocated finishEventId commandId (ChecklistRunFinishedV1 (ChecklistRunFinished (checklistRunId run) ownerIdentity))
      reviewEvents = case (requestClosure, remaining) of
        (True, [reviewEventId]) -> [makeDraft facts actor state allocated reviewEventId commandId (LazyReviewRequestedV1 (LazyReviewRequested ownerIdentity "scope_closure_review" "all finite checklist entries are closed; review the owner's scope"))]
        (False, []) -> []
        _ -> []
  if length reviewEvents == length remaining
    then pure (MutationDecision commandId (Just owner) Nothing (finishEvent : reviewEvents))
    else Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

finishChecklistRunUUIDCount :: State -> UUIDv7 -> Int
finishChecklistRunUUIDCount state ownerIdentity =
  2 + if maybe False (needsScopeClosureReview state) (Map.lookup ownerIdentity (stateBricks state)) then 1 else 0

needsScopeClosureReview :: State -> Brick -> Bool
needsScopeClosureReview state owner =
  brickNature owner == FiniteChecklist
    && null [entry | entry <- Map.elems (stateListEntries state), listEntryOwner entry == brickId owner, listEntryState entry == EntryOpen]
    && null [review | review <- Map.elems (stateLazyReviews state), lazyReviewSubject review == brickId owner, lazyReviewKind review == "scope_closure_review"]

decideFocusBrick state actor identity facts = do
  brick <- requireActiveBrick state identity
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (BrickFocusedV1 (BrickFocused identity))
  pure (MutationDecision commandId (Just brick) Nothing [event])

decideRecordedFocus :: State -> Actor -> UUIDv7 -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideRecordedFocus state actor identity selectionId facts = do
  brick <- requireActiveBrick state identity
  evidence <-
    maybe
      (Left (appError NotFound "The recorded forecast selection no longer exists."))
      Right
      (Map.lookup selectionId (stateForecastSelections state))
  if forecastSelectionEndpointSubject evidence == Just identity
    then pure ()
    else Left (appError PreconditionFailed "The proposed Brick does not match the recorded forecast endpoint.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let activeDomain = forecastSelectionDomainPath evidence >>= lastMaybe
      payload = ForecastFocusAccepted selectionId identity activeDomain
      event = makeDraft facts actor state allocated eventId commandId (ForecastFocusAcceptedV1 payload)
  pure (MutationDecision commandId (Just brick) Nothing [event])
 where
  lastMaybe [] = Nothing
  lastMaybe values = Just (last values)

decideWorkReaction :: State -> Actor -> UUIDv7 -> Maybe UUIDv7 -> SkipSymptom -> SkipReaction -> RuntimeFacts -> Either AppError MutationDecision
decideWorkReaction state actor identity selection symptom reaction facts = do
  brick <- requireActiveBrick state identity
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let cooldown = Just (addUTCTime (15 * 60) (runtimeNow facts))
      payload = WorkReactionRecorded identity selection symptom reaction cooldown
      event = makeDraft facts actor state allocated eventId commandId (WorkReactionRecordedV1 payload)
  pure (MutationDecision commandId (Just brick) Nothing [event])

decidePauseFocus :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decidePauseFocus state actor identity facts = do
  brick <- requireActiveBrick state identity
  if stateCurrentFocus state == Just identity && brickWorkState brick == Wip
    then pure ()
    else Left (appError PreconditionFailed "Only the current WIP can be paused.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (FocusPausedV1 (FocusPaused identity))
  pure (MutationDecision commandId (Just brick) Nothing [event])

decideStartSprint :: State -> Actor -> UUIDv7 -> Maybe UUIDv7 -> Int -> RuntimeFacts -> Either AppError MutationDecision
decideStartSprint state actor identity selection minutes facts = do
  brick <- requireActiveBrick state identity
  if minutes >= 1 && minutes <= 120
    then pure ()
    else Left (appError InvalidInput "Sprint minutes must be between 1 and 120.")
  allocated <- requireUUIDs 3 facts
  (commandId, reactionEventId, sprintEventId) <- case allocated of
    [commandIdentity, firstEvent, secondEvent] -> Right (commandIdentity, firstEvent, secondEvent)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let endsAt = addUTCTime (fromIntegral (minutes * 60)) (runtimeNow facts)
      reaction = WorkReactionRecorded identity selection BoredSymptom (StartSprintReaction minutes) Nothing
      events =
        [ makeDraft facts actor state allocated reactionEventId commandId (WorkReactionRecordedV1 reaction)
        , makeDraft facts actor state allocated sprintEventId commandId (SprintStartedV1 (SprintStarted identity minutes endsAt))
        ]
  pure (MutationDecision commandId (Just brick) Nothing events)

decideBreakBrick :: State -> Actor -> BreakDraft -> RuntimeFacts -> Either AppError MutationDecision
decideBreakBrick state actor draft facts = do
  parent <- requireActiveBrick state (breakDraftBrick draft)
  target <- validateBreakTarget parent
  let titles = fmap Text.strip (breakDraftTitles draft)
      minimumParts = if supportsChildParts (brickNature parent) then 1 else 2
  if length titles >= minimumParts
    then pure ()
    else Left (appError InvalidInput ("This decomposition needs at least " <> Text.pack (show minimumParts) <> " part titles."))
  if all (not . Text.null) titles
    then pure ()
    else Left (appError InvalidInput "A part title cannot be empty.")
  let normalized = fmap normalizeTitle titles
  if length normalized == Set.size (Set.fromList normalized)
    then pure ()
    else Left (appError InvalidInput "A decomposition cannot create indistinguishable sibling titles.")
  let existingTitles =
        Set.fromList
          [ normalizeTitle (brickTitle child)
          | child <- Map.elems (stateBricks state)
          , brickParent child == Just (brickId parent)
          ]
  if all (not . flip Set.member existingTitles) normalized
    then pure ()
    else Left (appError InvalidInput "A proposed part matches an existing child title; review duplicate intent first.")
  let hasReaction = isJust (breakDraftSymptom draft)
      hasNatureChange = target /= brickNature parent
      allocationCount = 1 + boolCount hasReaction + boolCount hasNatureChange + 3 * length titles
  allocated <- requireUUIDs allocationCount facts
  (commandId, afterCommand) <-
    case allocated of
      commandIdentity : rest -> Right (commandIdentity, rest)
      [] -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let (reactionIds, afterReaction) = splitAt (boolCount hasReaction) afterCommand
      (natureIds, childAllocations) = splitAt (boolCount hasNatureChange) afterReaction
      existingPositions =
        [ brickSiblingPosition child
        | child <- Map.elems (stateBricks state)
        , brickParent child == Just (brickId parent)
        ]
      firstPosition = case existingPositions of [] -> 0; values -> maximum values + 1
  triples <- chunksOfExactly 3 childAllocations
  if length triples == length titles
    then pure ()
    else Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let children = buildChildren (stateRetiredBrickHandles state) firstPosition titles triples
      reactionEvents =
        case (breakDraftSymptom draft, reactionIds) of
          (Nothing, []) -> []
          (Just symptom, [eventId]) ->
            [ makeDraft
                facts
                actor
                state
                allocated
                eventId
                commandId
                (WorkReactionRecordedV1 (WorkReactionRecorded (brickId parent) (breakDraftServedSelection draft) symptom BreakIntoPartsReaction Nothing))
            ]
          _ -> []
      natureEvents =
        case natureIds of
          [] -> []
          [eventId] ->
            [ makeDraft
                facts
                actor
                state
                allocated
                eventId
                commandId
                (BrickNatureChangedV1 (BrickNatureChanged (brickId parent) (brickNature parent) target "human_break"))
            ]
          _ -> []
      childEvents =
        concatMap
          ( \(childId, handle, title, position, createEventId, reviewEventId) ->
              [ makeDraft
                  facts
                  actor
                  state
                  allocated
                  createEventId
                  commandId
                  ( BrickChildCreatedV1
                      ( BrickChildCreated
                          childId
                          handle
                          title
                          AtomicTask
                          "factory@1"
                          "break_default"
                          (brickId parent)
                          position
                          (DeterministicPosition "entered_order")
                      )
                  )
              , makeDraft
                  facts
                  actor
                  state
                  allocated
                  reviewEventId
                  commandId
                  (LazyReviewRequestedV1 (LazyReviewRequested childId "nature" "break_default atomic task"))
              ]
          )
          children
      events = reactionEvents <> natureEvents <> childEvents
      changedParent =
        parent
          { brickNature = target
          , brickNatureVersion = if hasNatureChange then "factory@1" else brickNatureVersion parent
          , brickNatureSource = if hasNatureChange then "human_break" else brickNatureSource parent
          }
  pure (MutationDecision commandId (Just changedParent) Nothing events)
 where
  validateBreakTarget parent =
    case (supportsChildParts (brickNature parent), breakDraftTargetNature draft) of
      (True, Nothing) -> Right (brickNature parent)
      (True, Just same) | same == brickNature parent -> Right same
      (True, Just _) -> Left (appError InvalidInput "Adding parts to a compatible Brick cannot silently change its Nature.")
      (False, Just target) | target == Project || target == Collection -> Right target
      (False, _) -> Left (appError InvalidInput "Choose whether finished parts complete one project or remain an open collection.")

  buildChildren used firstPosition titles triples =
    snd (foldl build (used, []) (zip3 [firstPosition ..] titles triples))
   where
    build (handles, built) (position, title, [childId, createEventId, reviewEventId]) =
      let handle = allocateHandle BrickHandle handles title
       in (Set.insert handle handles, built <> [(childId, handle, title, position, createEventId, reviewEventId)])
    build accumulator _ = accumulator

  normalizeTitle = Text.toCaseFold . Text.unwords . Text.words
  boolCount True = 1
  boolCount False = 0

supportsChildParts :: BrickNature -> Bool
supportsChildParts nature =
  case natureStructureCapability <$> findNature nature of
    Just FiniteChildBricks -> True
    Just OpenChildBricks -> True
    Just PreparationBricks -> True
    _ -> False

decideAddDependency :: State -> Actor -> UUIDv7 -> UUIDv7 -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideAddDependency state actor blockedId blockerId source facts = do
  blocked <- requireActiveBrick state blockedId
  blocker <- requireActiveBrick state blockerId
  if brickId blocked == brickId blocker
    then Left (appError InvalidInput "A Brick cannot block itself.")
    else pure ()
  if any sameEdge (Map.elems (stateDependencies state))
    then Left (appError PreconditionFailed "That Dependency is already active.")
    else pure ()
  if dependencyReaches state blockerId blockedId
    then Left (appError PreconditionFailed "That Dependency would create a cycle.")
    else pure ()
  allocated <- requireUUIDs 3 facts
  (commandId, dependencyId, eventId) <- case allocated of
    [commandIdentity, dependencyIdentity, eventIdentity] -> Right (commandIdentity, dependencyIdentity, eventIdentity)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let payload = DependencyAdded dependencyId blockedId blockerId source
      event = makeDraft facts actor state allocated eventId commandId (DependencyAddedV1 payload)
  pure (MutationDecision commandId (Just blocked) Nothing [event])
 where
  sameEdge dependency =
    dependencyStatus dependency == DependencyActive
      && dependencyBlockedBrick dependency == blockedId
      && dependencyBlockerBrick dependency == blockerId

{- | Materialize one already-fed request as enabling Work and declare the Wait
that must replace its Dependency when the request Work is completed.
-}
decideCreateRequestHandoff :: State -> Actor -> UUIDv7 -> UUIDv7 -> UUIDv7 -> Maybe UUIDv7 -> Integer -> RuntimeFacts -> Either AppError MutationDecision
decideCreateRequestHandoff state actor affectedId targetId rawId servedSelection reviewDelay facts = do
  affected <- requireActiveBrick state affectedId
  raw <- requireInboxRaw state rawId
  case Map.lookup targetId (stateExternalEntities state) of
    Just entity | externalEntityActive entity -> pure ()
    _ -> Left (appError NotFound "The response target is missing or inactive.")
  unless (reviewDelay > 0) $ Left (appError InvalidInput "A response Wait needs a positive review delay.")
  let title = Text.unwords (Text.words (rawOriginal raw))
  unless (not (Text.null title)) $ Left (appError InvalidInput "An enabling request title cannot be empty.")
  allocated <- requireUUIDs 11 facts
  (commandId, brickId, linkId, dependencyId, waitIdentity, brickEventId, linkEventId, dispositionEventId, dependencyEventId, successorEventId, reactionEventId) <-
    case allocated of
      [commandIdentity, brickIdentity, linkIdentity, dependencyIdentity, waitId, firstEvent, secondEvent, thirdEvent, fourthEvent, fifthEvent, sixthEvent] ->
        Right (commandIdentity, brickIdentity, linkIdentity, dependencyIdentity, waitId, firstEvent, secondEvent, thirdEvent, fourthEvent, fifthEvent, sixthEvent)
      _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let handle = allocateHandle BrickHandle (stateRetiredBrickHandles state) title
      position = brickSiblingPosition affected
      created =
        BrickCreated
          brickId
          handle
          title
          AtomicTask
          "factory@1"
          "request_handoff"
          Nothing
          (brickParent affected)
          (brickDomains affected)
          position
          (Provisional "local_midpoint")
          rawId
      link = RawLinkAdded linkId rawId (RawLinkBrick brickId) MaterializationSourceRole
      disposition = RawDispositionAccepted rawId (RawMaterializedAsWork brickId)
      dependency = DependencyAdded dependencyId affectedId brickId "request_before_response_wait"
      successor = WaitSuccessor waitIdentity brickId affectedId (HumanResponseWait targetId) reviewDelay (runtimeNow facts)
      reaction = WorkReactionRecorded affectedId servedSelection WaitingSymptom CreateRequestReaction Nothing
      events =
        [ makeDraft facts actor state allocated brickEventId commandId (BrickCreatedV1 created)
        , makeDraft facts actor state allocated linkEventId commandId (RawLinkAddedV1 link)
        , makeDraft facts actor state allocated dispositionEventId commandId (RawDispositionAcceptedV1 disposition)
        , makeDraft facts actor state allocated dependencyEventId commandId (DependencyAddedV1 dependency)
        , makeDraft facts actor state allocated successorEventId commandId (WaitSuccessorDeclaredV1 (WaitSuccessorDeclared successor))
        , makeDraft facts actor state allocated reactionEventId commandId (WorkReactionRecordedV1 reaction)
        ]
      brick =
        Brick
          brickId
          handle
          title
          AtomicTask
          "factory@1"
          "request_handoff"
          Nothing
          (brickParent affected)
          (brickDomains affected)
          position
          (Provisional "local_midpoint")
          BrickActive
          Idle
          (runtimeNow facts)
          actor
          commandId
  pure (MutationDecision commandId (Just brick) (Just raw) events)

decideDomainFocus :: State -> Actor -> Maybe UUIDv7 -> Maybe DomainFocusMode -> RuntimeFacts -> Either AppError MutationDecision
decideDomainFocus state actor target mode facts = do
  case (target, mode) of
    (Just identity, Just _) ->
      case Map.lookup identity (stateDomains state) of
        Just domain | domainActive domain -> pure ()
        _ -> Left (appError NotFound "The selected Domain is missing or inactive.")
    (Nothing, Nothing) -> pure ()
    _ -> Left (appError InvalidInput "A Domain focus target and mode must be selected together.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let modeName = case mode of
        Just OneSuggestion -> "one_suggestion"
        Just StayWithin -> "stay_within"
        Just PreferDomain -> "prefer"
        Nothing -> "clear"
      event = makeDraft facts actor state allocated eventId commandId (DomainFocusChangedV1 (DomainFocusChanged target modeName))
  pure (MutationDecision commandId Nothing Nothing [event])

dependencyReaches :: State -> UUIDv7 -> UUIDv7 -> Bool
dependencyReaches state start target = go Set.empty start
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

chunksOfExactly :: Int -> [value] -> Either AppError [[value]]
chunksOfExactly width values
  | width <= 0 = Left (appError CorruptData "An internal allocation width is invalid.")
  | null values = Right []
  | length prefix /= width = Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  | otherwise = (prefix :) <$> chunksOfExactly width suffix
 where
  (prefix, suffix) = splitAt width values

decideCompleteBrick :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideCompleteBrick state actor identity facts = do
  brick <- requireActiveBrick state identity
  case brickNature brick of
    Repeatable -> completeStanding brick True
    Habit -> completeHabit brick
    LivingChecklist -> Left (appError PreconditionFailed "A living checklist uses finish for its current run; done would falsely terminalize the standing owner.")
    ScheduledCommitment -> Left (appError PreconditionFailed "A scheduled commitment needs an explicit attended, missed, or cancelled outcome.")
    RecurringObligation -> Left (appError PreconditionFailed "Complete a released recurring occurrence, not its standing series owner.")
    _ -> completeFinite brick
 where
  completeHabit brick =
    case sortOn (zonedInstantUtc . habitWindowOpensAt) (applicableHabitWindows brick) of
      [] ->
        Left
          (appError PreconditionFailed "This habit has no open occurrence window.")
            { appErrorRecovery = [RecoveryAction "next" "Let tick open the next due habit window, then try again." (Just "lant tick")]
            }
      windows -> decideHabitWindowOutcome state actor (habitWindowId (last windows)) StandingDone facts

  applicableHabitWindows brick =
    [ window
    | window <- Map.elems (stateHabitWindows state)
    , habitWindowOwner window == brickId brick
    , not (habitWindowSettled window)
    , zonedInstantUtc (habitWindowOpensAt window) <= runtimeNow facts
    , runtimeNow facts < zonedInstantUtc (habitWindowClosesAt window)
    ]

  completeStanding brick needsReturnPolicy = do
    let count = if needsReturnPolicy then 3 else 2
    allocated <- requireUUIDs count facts
    (commandId, outcomeEventId, remaining) <- case allocated of
      commandIdentity : eventIdentity : rest -> Right (commandIdentity, eventIdentity, rest)
      _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
    let outcome = makeDraft facts actor state allocated outcomeEventId commandId (StandingOutcomeRecordedV1 (StandingOutcomeRecorded identity StandingDone))
        reviews = case (needsReturnPolicy, remaining) of
          (True, [reviewEventId]) -> [makeDraft facts actor state allocated reviewEventId commandId (LazyReviewRequestedV1 (LazyReviewRequested identity "repeatable_return_policy" "choose when this repeatable Work may return"))]
          (False, []) -> []
          _ -> []
    if length reviews == length remaining
      then pure (MutationDecision commandId (Just brick) Nothing (outcome : reviews))
      else Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

  completeFinite brick = do
    let released =
          [ dependency
          | dependency <- Map.elems (stateDependencies state)
          , dependencyStatus dependency == DependencyActive
          , dependencyBlockerBrick dependency == identity
          ]
        successors =
          [ successor
          | successor <- Map.elems (stateWaitSuccessors state)
          , waitSuccessorEnablingBrick successor == identity
          , Map.notMember (waitSuccessorWait successor) (stateWaits state)
          ]
    allocated <- requireUUIDs (2 + length released + 2 * length successors) facts
    (commandId, eventId, successorIds, resolutionIds) <- case allocated of
      commandIdentity : completeEventId : remaining
        | let (waitIds, dependencyIds) = splitAt (2 * length successors) remaining
        , length waitIds == 2 * length successors
        , length dependencyIds == length released ->
            Right (commandIdentity, completeEventId, waitIds, dependencyIds)
      _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
    let completion = makeDraft facts actor state allocated eventId commandId (BrickCompletedV1 (BrickCompleted identity))
        waitEvents =
          concat $
            zipWith
              ( \successor identifiers -> case identifiers of
                  [observationId, waitEventId] ->
                    let reviewAt = ZonedInstant (addUTCTime (fromIntegral (waitSuccessorReviewDelaySeconds successor)) (runtimeNow facts)) (operationalZone (stateOperationalDayConfig state))
                        gate = WaitGate (waitSuccessorWait successor) (waitSuccessorAffectedBrick successor) (waitSuccessorKind successor) reviewAt Nothing WaitActive (runtimeNow facts) 0 1
                        observation = WaitObservation observationId (waitSuccessorWait successor) WaitActivatedObservation (runtimeNow facts) actor (Just "Activated after enabling request Work completed.")
                     in [makeDraft facts actor state allocated waitEventId commandId (WaitChangedV1 (WaitChanged gate observation))]
                  _ -> []
              )
              successors
              (either (const []) id (chunksOfExactly 2 successorIds))
        resolutions =
          zipWith
            (\resolutionEventId dependency -> makeDraft facts actor state allocated resolutionEventId commandId (DependencyResolvedV1 (DependencyResolution (dependencyId dependency))))
            resolutionIds
            released
    pure (MutationDecision commandId (Just brick) Nothing (completion : waitEvents <> resolutions))

completionUUIDCount :: State -> UUIDv7 -> Int
completionUUIDCount state identity =
  case brickNature <$> Map.lookup identity (stateBricks state) of
    Just Repeatable -> 3
    Just Habit -> 2
    _ ->
      2
        + length
          [ ()
          | dependency <- Map.elems (stateDependencies state)
          , dependencyStatus dependency == DependencyActive
          , dependencyBlockerBrick dependency == identity
          ]
        + 2
          * length
            [ ()
            | successor <- Map.elems (stateWaitSuccessors state)
            , waitSuccessorEnablingBrick successor == identity
            , Map.notMember (waitSuccessorWait successor) (stateWaits state)
            ]

decideArchiveBrick :: State -> Actor -> UUIDv7 -> Maybe (Maybe UUIDv7, SkipSymptom) -> RuntimeFacts -> Either AppError MutationDecision
decideArchiveBrick state actor identity served facts = do
  brick <- requireActiveBrick state identity
  let count = archiveUUIDCount served
  allocated <- requireUUIDs count facts
  (commandId, eventIds) <- case allocated of
    commandIdentity : remaining | length remaining == count - 1 -> Right (commandIdentity, remaining)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let (reactionEvents, lifecycleIds) =
        case (served, eventIds) of
          (Just (selection, symptom), reactionEventId : remaining) ->
            (
              [ makeDraft
                  facts
                  actor
                  state
                  allocated
                  reactionEventId
                  commandId
                  (WorkReactionRecordedV1 (WorkReactionRecorded identity selection symptom ArchiveReaction Nothing))
              ]
            , remaining
            )
          _ -> ([], eventIds)
  case lifecycleIds of
    [statusEventId, reviewEventId] ->
      let events =
            reactionEvents
              <> [ makeDraft facts actor state allocated statusEventId commandId (BrickStatusChangedV1 (BrickStatusChanged identity BrickActive BrickArchived "archive"))
                 , makeDraft facts actor state allocated reviewEventId commandId (LazyReviewRequestedV1 (LazyReviewRequested identity "archive_relevance_review" "confirm whether archived Work remains irrelevant"))
                 ]
       in pure (MutationDecision commandId (Just brick) Nothing events)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

archiveUUIDCount :: Maybe (Maybe UUIDv7, SkipSymptom) -> Int
archiveUUIDCount served = 3 + maybe 0 (const 1) served

decideRestoreBrick :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideRestoreBrick state actor identity facts = do
  brick <- maybe (Left (appError NotFound "No Brick matches the requested identity.")) Right (Map.lookup identity (stateBricks state))
  if brickStatus brick == BrickArchived
    then pure ()
    else Left (appError PreconditionFailed "Only archived Work can be restored.")
  let reviews =
        sortOn
          lazyReviewId
          [ claim
          | claim <- Map.elems (stateLazyReviews state)
          , lazyReviewSubject claim == identity
          , lazyReviewKind claim == "archive_relevance_review"
          ]
      count = restoreUUIDCount state identity
  allocated <- requireUUIDs count facts
  (commandId, statusEventId, remaining) <- case allocated of
    commandIdentity : statusIdentity : rest -> Right (commandIdentity, statusIdentity, rest)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let (settleIds, importanceIds) = splitAt (length reviews) remaining
  case importanceIds of
    [importanceEventId] ->
      let events =
            [makeDraft facts actor state allocated statusEventId commandId (BrickStatusChangedV1 (BrickStatusChanged identity BrickArchived BrickActive "restore"))]
              <> zipWith
                (\eventId review -> makeDraft facts actor state allocated eventId commandId (LazyReviewSettledV1 (LazyReviewSettled (lazyReviewId review) "restored")))
                settleIds
                reviews
              <> [makeDraft facts actor state allocated importanceEventId commandId (LazyReviewRequestedV1 (LazyReviewRequested identity "importance_run_review" "restored local placement needs review"))]
       in pure (MutationDecision commandId (Just brick) Nothing events)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

restoreUUIDCount :: State -> UUIDv7 -> Int
restoreUUIDCount state identity =
  3
    + length
      [ ()
      | claim <- Map.elems (stateLazyReviews state)
      , lazyReviewSubject claim == identity
      , lazyReviewKind claim == "archive_relevance_review"
      ]

decideKeepArchived :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideKeepArchived state actor reviewId facts = do
  review <- maybe (Left (appError NotFound "The archive relevance review is no longer pending.")) Right (Map.lookup reviewId (stateLazyReviews state))
  brick <- maybe (Left (appError CorruptData "The archive review references missing Work.")) Right (Map.lookup (lazyReviewSubject review) (stateBricks state))
  if lazyReviewKind review == "archive_relevance_review" && brickStatus brick == BrickArchived
    then pure ()
    else Left (appError PreconditionFailed "This review no longer describes archived Work.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let event = makeDraft facts actor state allocated eventId commandId (LazyReviewSettledV1 (LazyReviewSettled reviewId "kept_archived"))
  pure (MutationDecision commandId (Just brick) Nothing [event])

validateWorkDraft :: State -> WorkDraft -> Either AppError ()
validateWorkDraft state draft = do
  if Text.null (Text.strip (workDraftTitle draft))
    then Left (appError InvalidInput "A Brick title cannot be empty.")
    else pure ()
  case findNature (workDraftNature draft) of
    Nothing -> Left (appError InvalidInput "The selected Nature is not in the validated factory catalog.")
    Just _ -> pure ()
  case workDraftTemplate draft of
    Nothing -> pure ()
    Just selected -> case findTemplate (templateIdentifier selected) of
      Just definition
        | templateNature definition == workDraftNature draft
        , templateDefinitionVersion definition == templateCatalogVersion selected ->
            pure ()
      _ -> Left (appError InvalidInput "The selected Template is unknown or incompatible with the Nature.")
  case workDraftParent draft of
    Nothing -> pure ()
    Just parentId -> do
      _ <- requireActiveBrick state parentId
      pure ()
  if all (`Map.member` stateDomains state) (Set.toList (workDraftDomains draft))
    then pure ()
    else Left (appError NotFound "The Work draft references an unknown Domain.")
  let siblings = sortOn brickSiblingPosition (siblingBricks state (workDraftParent draft))
      position = workDraftSiblingPosition draft
  if position < 0 || position > length siblings
    then Left (appError InvalidInput "The Work draft has no valid sibling position.")
    else pure ()
  mapM_ (validateComparison siblings position) (workDraftComparisons draft)
  case (siblings, workDraftImportanceConfidence draft, workDraftComparisons draft) of
    ([], DeterministicPosition _, []) -> pure ()
    (_ : _, HumanComparison, _ : _) -> pure ()
    (_ : _, Provisional _, []) -> pure ()
    _ -> Left (appError InvalidInput "The importance confidence does not match the draft evidence.")

validateComparison :: [Brick] -> Int -> DraftImportanceAnswer -> Either AppError ()
validateComparison siblings position answer = do
  other <-
    maybe
      (Left (appError InvalidInput "An importance answer references a non-sibling Brick."))
      Right
      (firstWhere ((== answerIdentity answer) . brickId) siblings)
  case answer of
    DraftAbove _
      | position <= brickSiblingPosition other -> pure ()
      | otherwise -> invalidDirection
    DraftBelow _
      | position > brickSiblingPosition other -> pure ()
      | otherwise -> invalidDirection
 where
  invalidDirection = Left (appError InvalidInput "The importance answer contradicts the chosen insertion position.")

comparisonPayload :: UUIDv7 -> DraftImportanceAnswer -> ImportanceCompared
comparisonPayload brickId = \case
  DraftAbove other -> ImportanceCompared brickId other "human"
  DraftBelow other -> ImportanceCompared other brickId "human"

answerIdentity :: DraftImportanceAnswer -> UUIDv7
answerIdentity = \case DraftAbove identity -> identity; DraftBelow identity -> identity

decideUndoFeed :: State -> Actor -> RuntimeFacts -> Either AppError UndoDecision
decideUndoFeed state actor facts = do
  target <- case reversible of
    [] ->
      Left $
        (appError PreconditionFailed "There is no reversible Feed command for this profile.")
          { appErrorRecovery = [RecoveryAction "history" "Inspect recent semantic history." (Just "lant history")]
          }
    candidates -> Right (maximumBy (comparing rawCreatedAt) candidates)
  effect <- maybe (Left (appError CorruptData "The Feed command effect is missing.")) Right (Map.lookup (rawCreatedByCommand target) (stateCommandEffects state))
  if rawRevision target /= 1 || isJust (effectCompensatedBy effect)
    then
      Left $
        (appError PreconditionFailed "Later changes depend on this Raw, so Feed cannot be undone safely.")
          { appErrorSubject = Just (renderRaw target)
          , appErrorRecovery = [RecoveryAction "show" "Inspect the current Raw before choosing another action." (Just ("lant show " <> renderHandle RawHandle (rawHandle target)))]
          }
    else do
      allocated <- requireUUIDs 2 facts
      (commandId, eventId) <- exactlyTwo allocated
      let payload = RawFeedRetracted (rawId target) (rawCreatedByCommand target)
          event = makeDraft facts actor state allocated eventId commandId (RawFeedRetractedV1 payload)
      pure (UndoDecision commandId (rawCreatedByCommand target) target [event])
 where
  reversible =
    [ raw
    | raw <- Map.elems (stateRaws state)
    , rawStatus raw == RawAwaitingReview
    , Map.notMember (rawId raw) (stateRawDispositions state)
    , rawCreatedBy raw == actor
    ]

decideRedoFeed :: State -> Actor -> RuntimeFacts -> Either AppError UndoDecision
decideRedoFeed state actor facts = do
  feedCommandId <- maybe (Left (appError RedoConflict "There is no Feed command available to redo.")) Right (stateLastRedo state)
  effect <- maybe (Left (appError RedoConflict "The redo target is no longer available.")) Right (Map.lookup feedCommandId (stateCommandEffects state))
  rawIdentity <- case effectCreatedRaws effect of [identity] -> Right identity; _ -> Left (appError RedoConflict "The original command no longer has one restorable Raw.")
  raw <- maybe (Left (appError RedoConflict "The original Raw is missing.")) Right (Map.lookup rawIdentity (stateRaws state))
  retractionId <- maybe (Left (appError RedoConflict "The Feed command was not undone.")) Right (effectCompensatedBy effect)
  if effectActor effect /= actor || rawStatus raw /= RawRetracted
    then Left (appError RedoConflict "Current preconditions no longer allow this Feed redo.")
    else do
      allocated <- requireUUIDs 2 facts
      (commandId, eventId) <- exactlyTwo allocated
      let payload = RawFeedRestored rawIdentity feedCommandId retractionId
          event = makeDraft facts actor state allocated eventId commandId (RawFeedRestoredV1 payload)
      pure (UndoDecision commandId feedCommandId raw [event])

decideRegisterExternalEntity :: State -> Actor -> ExternalEntityKind -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideRegisterExternalEntity state actor kind suppliedName facts = do
  let name = Text.strip suppliedName
  unless (not (Text.null name)) $ Left (appError InvalidInput "A person or company name cannot be empty.")
  allocated <- requireUUIDs 3 facts
  (commandId, entityId, eventId) <- exactlyThree allocated
  let handle = allocateHandle EntityHandle (stateRetiredExternalEntityHandles state) name
      entity = ExternalEntity entityId handle name kind True (runtimeNow facts)
      event = makeDraft facts actor state allocated eventId commandId (ExternalEntityRegisteredV1 (ExternalEntityRegistered entity))
  pure (MutationDecision commandId Nothing Nothing [event])

decideAddContactPoint :: State -> Actor -> UUIDv7 -> ContactPointKind -> Maybe Text -> Text -> Maybe Text -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideAddContactPoint state actor ownerId kind label suppliedValue provider source facts = do
  entity <- maybe (Left (appError NotFound "No person or company matches that identity.")) Right (Map.lookup ownerId (stateExternalEntities state))
  unless (externalEntityActive entity) $ Left (appError PreconditionFailed "The selected person or company is inactive.")
  let value = Text.strip suppliedValue
  unless (not (Text.null value)) $ Left (appError InvalidInput "A contact value cannot be empty.")
  allocated <- requireUUIDs 3 facts
  (commandId, contactId, eventId) <- exactlyThree allocated
  let contact = ContactPoint contactId ownerId kind label value provider True source Nothing
      event = makeDraft facts actor state allocated eventId commandId (ContactPointRegisteredV1 (ContactPointRegistered contact))
  pure (MutationDecision commandId Nothing Nothing [event])

decideActivateWait :: State -> Actor -> UUIDv7 -> WaitKind -> ZonedInstant -> RuntimeFacts -> Either AppError MutationDecision
decideActivateWait state actor brickId kind reviewAt facts = do
  brick <- requireActiveBrick state brickId
  unless (not (hasActiveWait state brickId)) $ Left (appError PreconditionFailed "This Brick already has an active Wait.")
  validateWaitKind state kind
  unless (zonedInstantUtc reviewAt > runtimeNow facts) $ Left (appError InvalidInput "A Wait review must be scheduled in the future.")
  allocated <- requireUUIDs 4 facts
  (commandId, waitIdentity, observationId, eventId) <- exactlyFour allocated
  let gate = WaitGate waitIdentity brickId kind reviewAt Nothing WaitActive (runtimeNow facts) 0 1
      observation = WaitObservation observationId waitIdentity WaitActivatedObservation (runtimeNow facts) actor Nothing
      event = makeDraft facts actor state allocated eventId commandId (WaitChangedV1 (WaitChanged gate observation))
  pure (MutationDecision commandId (Just brick) Nothing [event])

decideReviewWait :: State -> Actor -> UUIDv7 -> WaitObservationKind -> WaitStatus -> Maybe ZonedInstant -> Maybe Text -> RuntimeFacts -> Either AppError MutationDecision
decideReviewWait state actor identity observationKind targetStatus nextReview note facts = do
  gate <- maybe (Left (appError NotFound "No Wait matches that identity.")) Right (Map.lookup identity (stateWaits state))
  unless (waitStatus gate == WaitActive) $ Left (appError PreconditionFailed "Only an active Wait can be reviewed.")
  case targetStatus of
    WaitActive -> case observationKind of
      WaitLongerObservation -> do
        reviewAt <- maybe (Left (appError InvalidInput "Waiting longer requires the next review time.")) Right nextReview
        unless (zonedInstantUtc reviewAt > runtimeNow facts) $ Left (appError InvalidInput "The next Wait review must be in the future.")
      WaitReviewSkippedObservation -> unless (isNothing nextReview) $ Left (appError InvalidInput "Skipping a Wait review cannot move its review threshold.")
      WaitReclassifiedObservation -> pure ()
      _ -> Left (appError InvalidInput "That observation cannot keep a Wait active.")
    WaitResolved -> unless (observationKind == WaitResponseReceivedObservation) $ Left (appError InvalidInput "Resolving a Wait requires an observed response or condition.")
    WaitCancelled -> unless (observationKind == WaitReclassifiedObservation) $ Left (appError InvalidInput "Cancelling a Wait requires explicit reclassification.")
  allocated <- requireUUIDs 3 facts
  (commandId, observationId, eventId) <- exactlyThree allocated
  let deferred = observationKind `elem` [WaitLongerObservation, WaitReviewSkippedObservation]
      changed =
        gate
          { waitReviewNotBefore = fromMaybe (waitReviewNotBefore gate) nextReview
          , waitReviewCooldownUntil = if observationKind == WaitReviewSkippedObservation then Just (addUTCTime (24 * 60 * 60) (runtimeNow facts)) else Nothing
          , waitStatus = targetStatus
          , waitDeferralCount = waitDeferralCount gate + if deferred then 1 else 0
          , waitRevision = waitRevision gate + 1
          }
      observation = WaitObservation observationId identity observationKind (runtimeNow facts) actor (Text.strip <$> note)
      event = makeDraft facts actor state allocated eventId commandId (WaitChangedV1 (WaitChanged changed observation))
  pure (MutationDecision commandId (Map.lookup (waitAffectedBrick gate) (stateBricks state)) Nothing [event])

decideProposeDelegation :: State -> Actor -> UUIDv7 -> UUIDv7 -> DelegationScope -> FollowUpPolicy -> Integer -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideProposeDelegation state actor brickId targetId scope policy reviewDelay suppliedMessage facts = do
  brick <- requireActiveBrick state brickId
  _ <- requireActiveEntity state targetId
  unless (brickNature brick `notElem` [Habit, ScheduledCommitment]) $
    Left (appError PreconditionFailed "Habit and scheduled-commitment responsibility cannot be delegated in V1.")
  validateDelegationScope (brickNature brick) scope
  unless (reviewDelay > 0) $ Left (appError InvalidInput "A follow-up delay must be positive.")
  let message = Text.strip suppliedMessage
  unless (not (Text.null message)) $ Left (appError InvalidInput "A Delegation message cannot be empty.")
  unless (not (any activeForBrick (Map.elems (stateDelegations state)))) $ Left (appError PreconditionFailed "This Brick already has an active or proposed Delegation.")
  allocated <- requireUUIDs 3 facts
  (commandId, delegationId, eventId) <- exactlyThree allocated
  let delegation = Delegation delegationId brickId targetId scope policy reviewDelay Nothing DelegationProposed message Nothing Nothing Nothing 0 0 1
      event = makeDraft facts actor state allocated eventId commandId (DelegationChangedV1 (DelegationChanged delegation))
  pure (MutationDecision commandId (Just brick) Nothing [event])
 where
  activeForBrick delegation = delegationBrick delegation == brickId && delegationStatus delegation `elem` [DelegationProposed, DelegationActive]

decideReviseProposedDelegationMessage :: State -> Actor -> UUIDv7 -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideReviseProposedDelegationMessage state actor identity suppliedMessage facts = do
  delegation <- requireDelegation state identity
  unless (delegationStatus delegation == DelegationProposed) $
    Left (appError PreconditionFailed "Only a proposed Delegation can be edited before handoff.")
  let message = Text.strip suppliedMessage
  unless (not (Text.null message)) $ Left (appError InvalidInput "A Delegation message cannot be empty.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed = delegation{delegationMessage = message, delegationRevision = delegationRevision delegation + 1}
      event = makeDraft facts actor state allocated eventId commandId (DelegationChangedV1 (DelegationChanged changed))
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing [event])

{- | Record no-response evidence and create a separate immutable follow-up
effect proposal when the declared policy still permits one. Nothing is sent
or counted as a handoff by this decision.
-}
decideReviewDelegationWithFollowUp :: State -> Actor -> UUIDv7 -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideReviewDelegationWithFollowUp state actor identity suppliedMessage facts = do
  delegation <- requireDelegation state identity
  unless (delegationStatus delegation == DelegationActive) $ Left (appError PreconditionFailed "Only an active Delegation can be followed up.")
  unless (followUpPermitted delegation) $ Left (appError PreconditionFailed "The declared follow-up policy does not permit another message proposal.")
  let message = Text.strip suppliedMessage
  unless (not (Text.null message)) $ Left (appError InvalidInput "A follow-up message cannot be empty.")
  allocated <- requireUUIDs 4 facts
  (commandId, effectId, delegationEventId, effectEventId) <- exactlyFour allocated
  let reviewAt = ZonedInstant (addUTCTime (fromIntegral (delegationReviewDelaySeconds delegation)) (runtimeNow facts)) (operationalZone (stateOperationalDayConfig state))
      changed =
        delegation
          { delegationReviewNotBefore = Just reviewAt
          , delegationLastObservation = Just "no_response"
          , delegationLastObservedAt = Just (runtimeNow facts)
          , delegationRevision = delegationRevision delegation + 1
          }
      effect = ExternalEffect effectId identity DelegationFollowUpEffect 1 (delegationTarget delegation) Nothing Nothing message EffectPendingApproval Nothing Nothing
      events =
        [ makeDraft facts actor state allocated delegationEventId commandId (DelegationChangedV1 (DelegationChanged changed))
        , makeDraft facts actor state allocated effectEventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged effect))
        ]
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing events)
 where
  followUpPermitted delegation = case delegationFollowUpPolicy delegation of
    FollowUpNone -> False
    FollowUpOnce -> delegationFollowUpHandoffs delegation == 0
    FollowUpEvery -> delegationFollowUpHandoffs delegation < 2 + delegationExtraFollowUps delegation

decideCancelProposedDelegation :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideCancelProposedDelegation state actor identity facts = do
  delegation <- requireDelegation state identity
  unless (delegationStatus delegation == DelegationProposed) $
    Left (appError PreconditionFailed "Only a proposed Delegation can be cancelled without reconciliation.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed = delegation{delegationStatus = DelegationCancelled, delegationRevision = delegationRevision delegation + 1}
      event = makeDraft facts actor state allocated eventId commandId (DelegationChangedV1 (DelegationChanged changed))
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing [event])

decideObserveDelegationHandoff :: State -> Actor -> UUIDv7 -> Maybe ZonedInstant -> RuntimeFacts -> Either AppError MutationDecision
decideObserveDelegationHandoff state actor identity reviewAt facts = do
  delegation <- requireDelegation state identity
  unless (delegationStatus delegation == DelegationProposed) $ Left (appError PreconditionFailed "Only a proposed Delegation can observe its initial handoff.")
  validateDelegationReviewAt facts (delegationFollowUpPolicy delegation) reviewAt
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed = delegation{delegationStatus = DelegationActive, delegationInitialHandoffAt = Just (runtimeNow facts), delegationReviewNotBefore = reviewAt, delegationRevision = delegationRevision delegation + 1}
      event = makeDraft facts actor state allocated eventId commandId (DelegationChangedV1 (DelegationChanged changed))
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing [event])

decideReviseExternalEffect :: State -> Actor -> UUIDv7 -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideReviseExternalEffect state actor identity suppliedMessage facts = do
  effect <- requireExternalEffect state identity
  unless (externalEffectStatus effect == EffectPendingApproval) $
    Left (appError PreconditionFailed "Only a pending external effect can be edited.")
  let message = Text.strip suppliedMessage
  unless (not (Text.null message)) $
    Left (appError InvalidInput "An external-effect message cannot be empty.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed =
        effect
          { externalEffectRevision = externalEffectRevision effect + 1
          , externalEffectMessage = message
          , externalEffectReviewNotBefore = Nothing
          , externalEffectApprovedDigest = Nothing
          }
      event = makeDraft facts actor state allocated eventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged changed))
  pure (MutationDecision commandId Nothing Nothing [event])

decideAllowDelegationFollowUp :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideAllowDelegationFollowUp state actor identity facts = do
  delegation <- requireDelegation state identity
  unless (delegationStatus delegation == DelegationActive) $ Left (appError PreconditionFailed "Only an active Delegation can extend its follow-up allowance.")
  unless (delegationFollowUpHandoffs delegation >= 2 + delegationExtraFollowUps delegation) $
    Left (appError PreconditionFailed "The current follow-up allowance has not been exhausted.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed = delegation{delegationExtraFollowUps = delegationExtraFollowUps delegation + 1, delegationRevision = delegationRevision delegation + 1}
      event = makeDraft facts actor state allocated eventId commandId (DelegationChangedV1 (DelegationChanged changed))
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing [event])

decideReviewDelegation :: State -> Actor -> UUIDv7 -> DelegationStatus -> Maybe ZonedInstant -> Maybe Text -> Bool -> RuntimeFacts -> Either AppError MutationDecision
decideReviewDelegation state actor identity targetStatus reviewAt observation followedUp facts = do
  delegation <- requireDelegation state identity
  unless (delegationStatus delegation == DelegationActive) $ Left (appError PreconditionFailed "Only an active Delegation can be reviewed.")
  unless (targetStatus `elem` [DelegationActive, DelegationCompleted, DelegationRefused, DelegationTakenBack, DelegationCancelled, DelegationReassigned]) $
    Left (appError InvalidInput "That Delegation review outcome is invalid.")
  when (targetStatus == DelegationActive) $ validateDelegationReviewAt facts (delegationFollowUpPolicy delegation) reviewAt
  let nextFollowups = delegationFollowUpHandoffs delegation + if followedUp then 1 else 0
      allowedFollowups = 2 + delegationExtraFollowUps delegation
  when (followedUp && nextFollowups > allowedFollowups) $ Left (appError PreconditionFailed "Change strategy before sending another follow-up.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let normalizedObservation = Text.strip <$> observation
      changed = delegation{delegationStatus = targetStatus, delegationReviewNotBefore = reviewAt, delegationLastObservation = normalizedObservation <|> delegationLastObservation delegation, delegationLastObservedAt = if isJust normalizedObservation then Just (runtimeNow facts) else delegationLastObservedAt delegation, delegationFollowUpHandoffs = nextFollowups, delegationRevision = delegationRevision delegation + 1}
      event = makeDraft facts actor state allocated eventId commandId (DelegationChangedV1 (DelegationChanged changed))
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing [event])

decideProposeExternalEffect :: State -> Actor -> UUIDv7 -> ExternalEffectPurpose -> Maybe UUIDv7 -> Maybe Text -> Text -> RuntimeFacts -> Either AppError MutationDecision
decideProposeExternalEffect state actor delegationId purpose contactId adapter suppliedMessage facts = do
  delegation <- requireDelegation state delegationId
  unless (delegationStatus delegation `elem` [DelegationProposed, DelegationActive]) $ Left (appError PreconditionFailed "This Delegation cannot propose an external effect.")
  let message = Text.strip suppliedMessage
  unless (not (Text.null message)) $ Left (appError InvalidInput "An external-effect message cannot be empty.")
  traverse_ (validateContact state (delegationTarget delegation)) contactId
  allocated <- requireUUIDs 3 facts
  (commandId, effectId, eventId) <- exactlyThree allocated
  let effect = ExternalEffect effectId delegationId purpose 1 (delegationTarget delegation) contactId adapter message EffectPendingApproval Nothing Nothing
      event = makeDraft facts actor state allocated eventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged effect))
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing [event])

decideApproveExternalEffect :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideApproveExternalEffect state actor identity facts = do
  effect <- requireExternalEffect state identity
  unless (externalEffectStatus effect == EffectPendingApproval) $ Left (appError PreconditionFailed "Only the exact pending revision can be approved.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed = effect{externalEffectRevision = externalEffectRevision effect + 1, externalEffectStatus = EffectApproved, externalEffectApprovedDigest = Just (externalEffectDigest effect)}
      event = makeDraft facts actor state allocated eventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged changed))
  pure (MutationDecision commandId Nothing Nothing [event])

decideStartExternalEffectDispatch :: State -> Actor -> UUIDv7 -> RuntimeFacts -> Either AppError MutationDecision
decideStartExternalEffectDispatch state actor identity facts = do
  effect <- requireExternalEffect state identity
  unless (externalEffectStatus effect == EffectApproved && externalEffectApprovedDigest effect == Just (externalEffectDigest effect)) $
    Left (appError PreconditionFailed "Dispatch requires the exact durably approved effect revision.")
  allocated <- requireUUIDs 2 facts
  (commandId, eventId) <- exactlyTwo allocated
  let changed = effect{externalEffectRevision = externalEffectRevision effect + 1, externalEffectStatus = EffectDispatching}
      event = makeDraft facts actor state allocated eventId commandId (ExternalEffectChangedV1 (ExternalEffectChanged changed))
  pure (MutationDecision commandId Nothing Nothing [event])

decideRecordExternalEffectReceipt :: State -> Actor -> UUIDv7 -> ExternalEffectStatus -> Maybe Text -> Maybe Text -> RuntimeFacts -> Either AppError MutationDecision
decideRecordExternalEffectReceipt state actor identity outcome providerReference redactedDetail facts = do
  effect <- requireExternalEffect state identity
  unless (externalEffectStatus effect == EffectDispatching) $ Left (appError PreconditionFailed "A receipt can follow only a durably dispatching effect.")
  unless (outcome `elem` [EffectSucceeded, EffectFailed, EffectOutcomeUnknown]) $ Left (appError InvalidInput "Choose succeeded, failed, or outcome unknown.")
  delegation <- requireDelegation state (externalEffectDelegation effect)
  let reconciliation = successfulEffectReconciliation state facts effect delegation
  allocated <- requireUUIDs (externalEffectReceiptUUIDCount state identity outcome) facts
  (commandId, receiptId, receiptEventId, remaining) <- case allocated of
    commandIdentity : receiptIdentity : eventIdentity : rest -> Right (commandIdentity, receiptIdentity, eventIdentity, rest)
    _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  let receipt = ExternalEffectReceipt receiptId identity (runtimeNow facts) outcome providerReference redactedDetail
      receiptEvent = makeDraft facts actor state allocated receiptEventId commandId (ExternalEffectReceiptRecordedV1 (ExternalEffectReceiptRecorded receipt))
      reconciliationEvents = case (reconciliation, remaining) of
        (Just changed, [delegationEventId]) -> [makeDraft facts actor state allocated delegationEventId commandId (DelegationChangedV1 (DelegationChanged changed))]
        _ -> []
  unless (length reconciliationEvents == length remaining) $
    Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")
  pure (MutationDecision commandId (Map.lookup (delegationBrick delegation) (stateBricks state)) Nothing (receiptEvent : reconciliationEvents))

externalEffectReceiptUUIDCount :: State -> UUIDv7 -> ExternalEffectStatus -> Int
externalEffectReceiptUUIDCount state identity outcome =
  case Map.lookup identity (stateExternalEffects state) >>= \effect -> Map.lookup (externalEffectDelegation effect) (stateDelegations state) >>= successfulEffectReconciliationAt effect of
    Just{} | outcome == EffectSucceeded -> 4
    _ -> 3

successfulEffectReconciliation :: State -> RuntimeFacts -> ExternalEffect -> Delegation -> Maybe Delegation
successfulEffectReconciliation state facts effect delegation = do
  _ <- successfulEffectReconciliationAt effect delegation
  let reviewAt =
        ZonedInstant
          (addUTCTime (fromIntegral (delegationReviewDelaySeconds delegation)) (runtimeNow facts))
          (operationalZone (stateOperationalDayConfig state))
  case externalEffectPurpose effect of
    DelegationDeliveryEffect ->
      Just
        delegation
          { delegationStatus = DelegationActive
          , delegationInitialHandoffAt = Just (runtimeNow facts)
          , delegationReviewNotBefore = Just reviewAt
          , delegationRevision = delegationRevision delegation + 1
          }
    DelegationFollowUpEffect ->
      Just
        delegation
          { delegationFollowUpHandoffs = delegationFollowUpHandoffs delegation + 1
          , delegationReviewNotBefore = Just reviewAt
          , delegationLastObservation = Just "follow_up_delivered"
          , delegationLastObservedAt = Just (runtimeNow facts)
          , delegationRevision = delegationRevision delegation + 1
          }
    DelegationTakeBackEffect -> Nothing

successfulEffectReconciliationAt :: ExternalEffect -> Delegation -> Maybe Delegation
successfulEffectReconciliationAt effect delegation
  | externalEffectPurpose effect == DelegationDeliveryEffect && delegationStatus delegation == DelegationProposed = Just delegation
  | externalEffectPurpose effect == DelegationFollowUpEffect && delegationStatus delegation == DelegationActive = Just delegation
  | otherwise = Nothing

externalEffectDigest :: ExternalEffect -> Text
externalEffectDigest effect =
  sha256Hex . Text.encodeUtf8 . Text.intercalate "\n" $
    [ renderUUIDv7 (externalEffectId effect)
    , renderUUIDv7 (externalEffectDelegation effect)
    , Text.pack (show (externalEffectPurpose effect))
    , renderUUIDv7 (externalEffectTarget effect)
    , maybe "" renderUUIDv7 (externalEffectContactPoint effect)
    , fromMaybe "" (externalEffectAdapter effect)
    , externalEffectMessage effect
    ]

validateWaitKind :: State -> WaitKind -> Either AppError ()
validateWaitKind state = \case
  HumanResponseWait entityId -> () <$ requireActiveEntity state entityId
  ExternalConditionWait condition -> unless (not (Text.null (Text.strip condition))) $ Left (appError InvalidInput "A waiting condition cannot be empty.")

hasActiveWait :: State -> UUIDv7 -> Bool
hasActiveWait state brickId = any (\gate -> waitAffectedBrick gate == brickId && waitStatus gate == WaitActive) (Map.elems (stateWaits state))

requireActiveEntity :: State -> UUIDv7 -> Either AppError ExternalEntity
requireActiveEntity state identity = case Map.lookup identity (stateExternalEntities state) of
  Just entity | externalEntityActive entity -> Right entity
  _ -> Left (appError NotFound "No active person or company matches that identity.")

requireDelegation :: State -> UUIDv7 -> Either AppError Delegation
requireDelegation state identity = maybe (Left (appError NotFound "No Delegation matches that identity.")) Right (Map.lookup identity (stateDelegations state))

requireExternalEffect :: State -> UUIDv7 -> Either AppError ExternalEffect
requireExternalEffect state identity = maybe (Left (appError NotFound "No external effect matches that identity.")) Right (Map.lookup identity (stateExternalEffects state))

validateContact :: State -> UUIDv7 -> UUIDv7 -> Either AppError ()
validateContact state ownerId identity = case Map.lookup identity (stateContactPoints state) of
  Just contact | contactPointOwner contact == ownerId && contactPointActive contact -> Right ()
  _ -> Left (appError PreconditionFailed "The selected contact does not belong to the Delegation target.")

validateDelegationReviewAt :: RuntimeFacts -> FollowUpPolicy -> Maybe ZonedInstant -> Either AppError ()
validateDelegationReviewAt facts _ reviewAt = case reviewAt of
  Just instant | zonedInstantUtc instant > runtimeNow facts -> Right ()
  _ -> Left (appError InvalidInput "Every active Delegation requires a future internal review time.")

validateDelegationScope :: BrickNature -> DelegationScope -> Either AppError ()
validateDelegationScope nature scope =
  unless (scope `elem` allowed) $
    Left (appError InvalidInput "That Delegation scope is not available for this Nature.")
 where
  allowed = case nature of
    AtomicTask -> [BrickOnlyDelegation]
    Project -> [BrickOnlyDelegation, WholeScopeDelegation]
    Collection -> [BrickOnlyDelegation]
    Repeatable -> [BrickOnlyDelegation]
    LivingChecklist -> [WholeScopeDelegation]
    FiniteChecklist -> [WholeScopeDelegation]
    RecurringObligation -> [WholeScopeDelegation]
    Habit -> []
    ScheduledCommitment -> []

requireActiveShelf :: State -> UUIDv7 -> Either AppError RawShelf
requireActiveShelf state identity = case Map.lookup identity (stateRawShelves state) of
  Nothing -> Left (appError NotFound "The selected RawShelf does not exist.")
  Just shelf
    | not (rawShelfActive shelf) -> Left (appError PreconditionFailed "The selected RawShelf is archived.")
    | otherwise -> Right shelf

makeDraft :: RuntimeFacts -> Actor -> State -> [UUIDv7] -> UUIDv7 -> UUIDv7 -> EventPayload -> EventDraft
makeDraft facts actor state allocated eventId commandId =
  EventDraft eventId commandId actor (runtimeNow facts) (statePreconditionHash state) allocated

requireUUIDs :: Int -> RuntimeFacts -> Either AppError [UUIDv7]
requireUUIDs count facts
  | length allocations < count = Left (appError PreconditionFailed "The runtime did not allocate enough UUIDv7 values.")
  | otherwise = traverse (either (const (Left invalid)) Right . parseUUIDv7 . unUUIDAllocation) (take count allocations)
 where
  allocations = runtimeUUIDs facts
  invalid = appError PreconditionFailed "The runtime supplied an invalid UUIDv7 allocation."

exactlyTwo :: [value] -> Either AppError (value, value)
exactlyTwo = \case
  [first, second] -> Right (first, second)
  _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

exactlyThree :: [value] -> Either AppError (value, value, value)
exactlyThree = \case
  [first, second, third] -> Right (first, second, third)
  _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

exactlyFour :: [value] -> Either AppError (value, value, value, value)
exactlyFour = \case
  [first, second, third, fourth] -> Right (first, second, third, fourth)
  _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

exactlySeven :: [value] -> Either AppError (value, value, value, value, value, value, value)
exactlySeven = \case
  [first, second, third, fourth, fifth, sixth, seventh] -> Right (first, second, third, fourth, fifth, sixth, seventh)
  _ -> Left (appError PreconditionFailed "The runtime UUID allocation count changed unexpectedly.")

requireInboxRaw :: State -> UUIDv7 -> Either AppError Raw
requireInboxRaw state identity = do
  raw <- requireActiveRaw state identity
  if Map.member identity (stateRawDispositions state)
    then Left (appError PreconditionFailed "The Raw already has an accepted triage disposition.")
    else pure raw

requirePreservedRaw :: State -> UUIDv7 -> Either AppError Raw
requirePreservedRaw state identity =
  case Map.lookup identity (stateRaws state) of
    Just raw | rawStatus raw /= RawRetracted -> Right raw
    _ -> Left (appError NotFound "No preserved Raw matches the requested identity.")

requireActiveRaw :: State -> UUIDv7 -> Either AppError Raw
requireActiveRaw state identity =
  case Map.lookup identity (stateRaws state) of
    Just raw | rawStatus raw == RawAwaitingReview -> Right raw
    _ -> Left (appError NotFound "No active Raw matches the requested identity.")

requireActiveBrick :: State -> UUIDv7 -> Either AppError Brick
requireActiveBrick state identity =
  case Map.lookup identity (stateBricks state) of
    Just brick | brickStatus brick == BrickActive -> Right brick
    _ -> Left (appError NotFound "No active Brick matches the requested identity.")

rawSeed :: Text -> Text
rawSeed material = case filter (not . Text.null) (fmap Text.strip (Text.lines material)) of
  firstLine : _ -> firstLine
  [] -> "raw"

renderRaw :: Raw -> Text
renderRaw raw = renderHandle RawHandle (rawHandle raw) <> " \"" <> Text.take 80 (rawOriginal raw) <> "\""

firstWhere :: (value -> Bool) -> [value] -> Maybe value
firstWhere _ [] = Nothing
firstWhere predicate (value : rest)
  | predicate value = Just value
  | otherwise = firstWhere predicate rest

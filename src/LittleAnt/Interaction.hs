module LittleAnt.Interaction (
  Action (..),
  CommandOption (..),
  EnvelopeContent (..),
  Footer (..),
  InteractionEnvelope (..),
  InteractionResponse (..),
  NatureDiscovery (..),
  ImportanceDiscoveryNode (..),
  ImpactMaturityQuestion (..),
  SkipDiscoveryNode (..),
  OrderCadence (..),
  OrderScope (..),
  OrderSession (..),
  TranslationScope (..),
  TranslationCandidate (..),
  TranslationQueue (..),
  SourceReconciliationChoice (..),
  NatureQuestion (..),
  Opportunity (..),
  ResponseValidation (..),
  ScreenGrammar (..),
  WorkContext (..),
  EntitySelectionPurpose (..),
  DelegationDraft (..),
  advanceEnvelope,
  envelopeIntegrityIsValid,
  makeCompletionResultEnvelope,
  makeRepeatableReturnEnvelope,
  makeRepeatableReturnCenterEnvelope,
  makeRepeatableReturnUnitEnvelope,
  makeRepeatableReturnVariationEnvelope,
  makeRepeatableReturnZoneEnvelope,
  makeRepeatableReturnPreviewEnvelope,
  makeRepeatableReturnResultEnvelope,
  makeScheduledCommitmentEnvelope,
  makeScheduledOverlapEnvelope,
  makeScheduledOutcomeResultEnvelope,
  makeNoticeListEnvelope,
  makeTemporalNoticeEnvelope,
  makeNoticeSnoozeEnvelope,
  makeNoticeResultEnvelope,
  makeWaitReviewEnvelope,
  makeWaitDelayEnvelope,
  makeEntitySelectEnvelope,
  makeEntityKindEnvelope,
  makeEntityNameEnvelope,
  makeWaitRequestStatusEnvelope,
  makeWaitRequestInputEnvelope,
  makeWaitRequestDelayEnvelope,
  makeWaitRequestPreviewEnvelope,
  makeWaitRequestHandoffResultEnvelope,
  makeWaitConditionInputEnvelope,
  makeDependencySelectEnvelope,
  makeDependencyPreviewEnvelope,
  makeDependencyResultEnvelope,
  makeWaitActivationDelayEnvelope,
  makeWaitActivationResultEnvelope,
  makeWaitResultEnvelope,
  makeDelegationScopeEnvelope,
  makeDelegationPolicyEnvelope,
  makeDelegationDelayEnvelope,
  makeDelegationPreviewEnvelope,
  makeDelegationMessageEnvelope,
  makeDelegationHandoffEnvelope,
  makeDelegationTakeBackPreviewEnvelope,
  makeDelegationReviewEnvelope,
  makeDelegationResultEnvelope,
  makeExternalEffectApprovalEnvelope,
  makeExternalEffectRecoveryEnvelope,
  makeExternalEffectDuplicateRiskEnvelope,
  makeExternalEffectEditEnvelope,
  makeExternalEffectDelayEnvelope,
  makeExternalEffectResultEnvelope,
  makeChecklistRunEnvelope,
  makeChecklistRunResultEnvelope,
  makeArchivePreviewEnvelope,
  makeArchiveResultEnvelope,
  makeArchiveReviewResultEnvelope,
  makeRestorePreviewEnvelope,
  makeRestoreResultEnvelope,
  makeArchiveReviewEnvelope,
  makeCurrentFocusEnvelope,
  makeDomainSelectionEnvelope,
  makeDomainFocusEnvelope,
  makeDomainFocusResultEnvelope,
  makeExistingWorkReuseResultEnvelope,
  makeExistingWorkSuspicionEnvelope,
  makeFocusProposalEnvelope,
  makeRecordedFocusProposalEnvelope,
  makeNatureChoiceEnvelope,
  makeNatureConfirmationEnvelope,
  makeNatureDiscoveryEnvelope,
  makePristineEnvelope,
  makeRawDestinationEnvelope,
  makeRawGroupDiscoveryEnvelope,
  makeRawShelfCreatePreviewEnvelope,
  makeRawShelfMembershipPreviewEnvelope,
  makeRawShelfNameEnvelope,
  makeRawShelfResultEnvelope,
  makeRawDuplicateEnvelope,
  makeTranslationScopeEnvelope,
  makeTranslationEditorEnvelope,
  makeTranslationPreviewEnvelope,
  makeTranslationCompleteEnvelope,
  makeRawDetailEnvelope,
  makeRawOriginListEnvelope,
  makeSourceBindingEnvelope,
  makeSourceReconciliationEnvelope,
  makeSourceReconciliationPreviewEnvelope,
  makeSourceFailureEnvelope,
  makeSourceRelocateEnvelope,
  makeSourceRelocatePreviewEnvelope,
  makeSourceLifecyclePreviewEnvelope,
  makeSourceResultEnvelope,
  makeImportPreflightEnvelope,
  makeImportResultEnvelope,
  makePackInstallEnvelope,
  makePackInstallResultEnvelope,
  makePackTrustEnvelope,
  makePackTrustResultEnvelope,
  makeRawAttachmentEnvelope,
  makeRawAttachmentResultEnvelope,
  makeRawUnderBrickEnvelope,
  makeRawTriageEnvelope,
  makeRepairCandidateEnvelope,
  makeRepairCompleteEnvelope,
  makeRepairPreviewEnvelope,
  makeSafeEmptyEnvelope,
  makeSkipAcknowledgedEnvelope,
  makeWorkSkipConfirmationEnvelope,
  makeWorkSkipDiscoveryEnvelope,
  makeWorkSkipReactionEnvelope,
  makeWorkSkipSymptomEnvelope,
  makeWorkOtherExplanationEnvelope,
  makeWorkOtherPreviewEnvelope,
  makeWorkInterestingEnvelope,
  makeWorkBreakDraftEnvelope,
  makeWorkBreakNatureEnvelope,
  makeWorkBreakPreviewEnvelope,
  makeWorkBreakResultEnvelope,
  makeWorkSprintDurationEnvelope,
  makeStandaloneResultEnvelope,
  makeTemplateChoiceEnvelope,
  makeWorkCreatedResultEnvelope,
  makeImportanceInsertionEnvelope,
  makeListEntryPreviewEnvelope,
  makeListEntryReuseEnvelope,
  makeListEntryResultEnvelope,
  makeWorkPreviewEnvelope,
  makeWorkTitleEnvelope,
  resealEnvelope,
  validateResponse,
)
where

import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Pair, Parser)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base16 qualified as Base16
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAsciiLower)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Catalog
import LittleAnt.Decision (DraftImportanceAnswer (..), WorkDraft (..))
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Model
import LittleAnt.Notice
import LittleAnt.Pack.Admin
import LittleAnt.Pack.Format
import LittleAnt.Pack.Trust
import LittleAnt.Source
import LittleAnt.Store

data ScreenGrammar
  = FocusGrammar
  | ComparisonGrammar
  | ConfirmationGrammar
  | ChoiceGrammar
  | InputGrammar
  deriving stock (Eq, Ord, Show)

data NatureQuestion
  = FixedTimeQuestion
  | FiniteIntentionQuestion
  | MultipartQuestion
  | IndependentPartsQuestion
  | ChangingMembersQuestion
  | IndependentMemberQuestion
  | OpenOccurrenceQuestion
  | StreakQuestion
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data SkipDiscoveryNode
  = OutsidePrerequisiteNode
  | UnclearWorkNode
  | TrackedPartsNode
  | DifficultWorkNode
  | StaleWorkNode
  | RelativeImportanceNode
  | EnergyNode
  | InterestNode
  | RiskNode
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data NatureDiscovery = NatureDiscovery
  { discoveryQuestion :: NatureQuestion
  , discoveryAlternateProbe :: Bool
  , discoveryHistory :: [NatureQuestion]
  }
  deriving stock (Eq, Show)

data SourceReconciliationChoice
  = ReconcileSameRaw
  | ReconcileDerivedRaw
  | ReconcileUnrelated
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data TranslationScope = TranslationScope
  { translationScopeTitles :: Bool
  , translationScopeRaws :: Bool
  , translationScopeArchived :: Bool
  }
  deriving stock (Eq, Show)

data TranslationCandidate
  = TranslationBrickTitle UUIDv7
  | TranslationRawRevision UUIDv7 UUIDv7
  deriving stock (Eq, Ord, Show)

data TranslationQueue = TranslationQueue
  { translationQueueScope :: TranslationScope
  , translationQueueRemaining :: [TranslationCandidate]
  , translationQueueAccepted :: Int
  , translationQueueSkipped :: Int
  , translationQueueTotal :: Int
  }
  deriving stock (Eq, Show)

data EntitySelectionPurpose = WaitTargetPurpose | DelegationTargetPurpose
  deriving stock (Eq, Ord, Show)

data DelegationDraft = DelegationDraft
  { delegationDraftBrick :: UUIDv7
  , delegationDraftSelection :: Maybe UUIDv7
  , delegationDraftTarget :: UUIDv7
  , delegationDraftScope :: Maybe DelegationScope
  , delegationDraftPolicy :: Maybe FollowUpPolicy
  , delegationDraftReviewDelaySeconds :: Maybe Integer
  , delegationDraftMessage :: Text
  }
  deriving stock (Eq, Show)

data WorkContext = WorkContext
  { workContextRawId :: UUIDv7
  , workContextParent :: Maybe UUIDv7
  , workContextDomains :: Set.Set UUIDv7
  }
  deriving stock (Eq, Show)

data OrderCadence = LotteryOrder | ContinuousOrder
  deriving stock (Eq, Ord, Show)

data OrderScope
  = AllSiblingGroups
  | OneSiblingGroup (Maybe UUIDv7)
  | DomainSiblingGroups UUIDv7
  deriving stock (Eq, Ord, Show)

data OrderSession = OrderSession
  { orderSessionScope :: OrderScope
  , orderSessionGroups :: [Maybe UUIDv7]
  , orderSessionGroupIndex :: Int
  , orderSessionComparisons :: Int
  , orderSessionCadence :: OrderCadence
  }
  deriving stock (Eq, Show)

data ImportanceDiscoveryNode
  = UnderstandFirstResult
  | InspectFirstContext
  | UnderstandSecondResult
  | InspectSecondContext
  | ChooseFirstForever
  | ChooseSecondForever
  | AcceptEitherOrder
  | SeekNewEvidence
  | TryNearbySibling
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ImpactMaturityQuestion
  = ObservedResultQuestion
  | RepresentativeTestQuestion
  | RelevantSupportQuestion
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data DestinationCandidate
  = DestinationBrick Brick
  | DestinationShelf RawShelf
  deriving stock (Eq, Show)

data Opportunity
  = PristineOpportunity
  | SafeEmptyOpportunity
  | RawTriageOpportunity UUIDv7 Handle Text
  | RawDuplicateOpportunity UUIDv7 UUIDv7
  | TranslationScopeOpportunity TranslationScope
  | TranslationEditOpportunity TranslationQueue (Maybe Text) (Maybe Text)
  | TranslationPreviewOpportunity TranslationQueue Text NormalizationSource (Maybe Text) (Maybe Fixed)
  | TranslationCompleteOpportunity Int Int Int
  | RawDetailOpportunity UUIDv7
  | RawOriginListOpportunity UUIDv7
  | SourceBindingOpportunity UUIDv7
  | SourceChangeOpportunity UUIDv7
  | SourceReconciliationPreviewOpportunity UUIDv7 SourceReconciliationChoice
  | SourceFailureOpportunity UUIDv7
  | SourceRelocateOpportunity UUIDv7 Text
  | SourceRelocatePreviewOpportunity UUIDv7 Text
  | SourceLifecyclePreviewOpportunity UUIDv7 SourceBindingLifecycle
  | SourceResultOpportunity UUIDv7 Text
  | ImportPreflightOpportunity Text SourcePreflight Bool
  | ImportResultOpportunity [UUIDv7] [UUIDv7] Bool
  | PackInstallOpportunity PackInstallDraft
  | PackTrustOpportunity PackTrustDraft
  | PackInstallResultOpportunity PackArtifactIdentity
  | PackTrustResultOpportunity TrustedCommunityPublisher
  | RawDestinationOpportunity UUIDv7 Int
  | RawGroupDiscoveryOpportunity UUIDv7
  | RawShelfNameOpportunity UUIDv7 Text
  | RawShelfCreatePreviewOpportunity UUIDv7 Text
  | RawShelfMembershipPreviewOpportunity UUIDv7 UUIDv7
  | RawShelfResultOpportunity UUIDv7 UUIDv7
  | RawUnderBrickOpportunity UUIDv7 UUIDv7
  | RawAttachmentOpportunity UUIDv7 UUIDv7
  | RawAttachmentResultOpportunity UUIDv7 UUIDv7 RawLinkRole
  | NatureChoiceOpportunity WorkContext
  | NatureDiscoveryOpportunity WorkContext NatureDiscovery
  | NatureConfirmationOpportunity WorkContext BrickNature Text NatureQuestion
  | TemplateChoiceOpportunity WorkContext BrickNature
  | WorkTitleOpportunity WorkContext BrickNature (Maybe TemplateSelection) Text
  | DomainSelectionOpportunity WorkDraft [UUIDv7]
  | DomainFocusOpportunity UUIDv7
  | DomainFocusResultOpportunity UUIDv7 DomainFocusMode
  | ExistingWorkSuspicionOpportunity WorkDraft UUIDv7
  | ExistingWorkReuseResultOpportunity UUIDv7 UUIDv7
  | ListEntryPreviewOpportunity UUIDv7 UUIDv7 Text Quantity
  | ListEntryReuseOpportunity UUIDv7 UUIDv7 UUIDv7 Quantity
  | ListEntryResultOpportunity UUIDv7 UUIDv7 UUIDv7
  | ImportanceInsertionOpportunity WorkDraft Int Int [UUIDv7] UUIDv7
  | OrderScopeOpportunity
  | ImportanceReviewOpportunity OrderSession UUIDv7 UUIDv7 Int [UUIDv7] Bool
  | ImportanceContradictionOpportunity OrderSession UUIDv7 UUIDv7 [UUIDv7]
  | ImportanceContradictionAidOpportunity OrderSession [UUIDv7]
  | ImportanceDiscoveryOpportunity OrderSession UUIDv7 UUIDv7 ImportanceDiscoveryNode Bool
  | ImportanceDirectionConfirmationOpportunity OrderSession UUIDv7 UUIDv7
  | ImportanceEitherConfirmationOpportunity OrderSession UUIDv7 UUIDv7
  | ImportanceProvisionalConfirmationOpportunity OrderSession UUIDv7 UUIDv7
  | OrderResultOpportunity OrderSession Bool Int
  | ImpactClassOpportunity UUIDv7
  | ImpactBasisOpportunity UUIDv7 ImpactClass
  | ImpactEvidenceOpportunity UUIDv7 ImpactClass [UUIDv7]
  | ImpactMaturityOpportunity UUIDv7 ImpactClass UUIDv7 ImpactMaturityQuestion Bool
  | ImpactMaturityPreviewOpportunity UUIDv7 ImpactClass UUIDv7 ImpactMaturity
  | ImpactComparisonOpportunity UUIDv7 UUIDv7 Int [UUIDv7] Bool
  | ImpactContradictionOpportunity UUIDv7 UUIDv7 UUIDv7 UUIDv7 JudgmentRelation [UUIDv7]
  | EffortClassOpportunity UUIDv7
  | EffortExemplarOpportunity UUIDv7 UUIDv7 Int [EffortClass] [UUIDv7]
  | EffortContradictionOpportunity UUIDv7 UUIDv7 Int [EffortClass] [UUIDv7] UUIDv7 UUIDv7 JudgmentRelation [UUIDv7]
  | JudgmentContradictionAidOpportunity JudgmentAxis UUIDv7 [UUIDv7] [UUIDv7]
  | EffortNarrowedOpportunity UUIDv7 [EffortClass]
  | EffortProposalOpportunity UUIDv7 EffortClass
  | PhaseOpportunity UUIDv7
  | JudgmentResultOpportunity JudgmentAxis UUIDv7 Text
  | WorkPreviewOpportunity WorkDraft
  | StandaloneResultOpportunity UUIDv7
  | WorkCreatedResultOpportunity UUIDv7 UUIDv7
  | FocusProposalOpportunity UUIDv7 (Maybe UUIDv7)
  | CurrentFocusOpportunity UUIDv7
  | ChecklistRunOpportunity UUIDv7 (Maybe UUIDv7)
  | ChecklistRunResultOpportunity UUIDv7
  | RepeatableReturnOpportunity UUIDv7 UUIDv7
  | RepeatableReturnCenterOpportunity UUIDv7 UUIDv7 Text
  | RepeatableReturnUnitOpportunity UUIDv7 UUIDv7 Int
  | RepeatableReturnVariationOpportunity UUIDv7 UUIDv7 Int ReturnUnit Text
  | RepeatableReturnZoneOpportunity UUIDv7 UUIDv7 Int ReturnUnit Int Text
  | RepeatableReturnPreviewOpportunity UUIDv7 UUIDv7 ReturnPolicy Int ZonedInstant Text ByteString
  | RepeatableReturnResultOpportunity UUIDv7
  | ScheduledCommitmentOpportunity UUIDv7
  | ScheduledOverlapOpportunity [UUIDv7]
  | ScheduledOutcomeResultOpportunity UUIDv7 StandingOutcomeKind
  | NoticeListOpportunity [NoticeIdentity]
  | TemporalNoticeOpportunity NoticeIdentity
  | NoticeSnoozeOpportunity NoticeIdentity
  | NoticeResultOpportunity NoticeIdentity Text
  | WaitReviewScreenOpportunity UUIDv7
  | WaitDelayOpportunity UUIDv7
  | EntitySelectOpportunity UUIDv7 (Maybe UUIDv7) EntitySelectionPurpose
  | EntityKindOpportunity UUIDv7 (Maybe UUIDv7) EntitySelectionPurpose
  | EntityNameOpportunity UUIDv7 (Maybe UUIDv7) EntitySelectionPurpose ExternalEntityKind Text
  | WaitRequestStatusOpportunity UUIDv7 (Maybe UUIDv7) UUIDv7
  | WaitRequestInputOpportunity UUIDv7 (Maybe UUIDv7) UUIDv7 Text
  | WaitRequestDelayOpportunity UUIDv7 (Maybe UUIDv7) UUIDv7 UUIDv7
  | WaitRequestPreviewOpportunity UUIDv7 (Maybe UUIDv7) UUIDv7 UUIDv7 Integer
  | WaitRequestHandoffResultOpportunity UUIDv7 UUIDv7 UUIDv7
  | WaitConditionInputOpportunity UUIDv7 (Maybe UUIDv7) Text
  | DependencySelectOpportunity UUIDv7 (Maybe UUIDv7)
  | DependencyPreviewOpportunity UUIDv7 (Maybe UUIDv7) UUIDv7
  | DependencyResultOpportunity UUIDv7 UUIDv7
  | WaitActivationDelayOpportunity UUIDv7 (Maybe UUIDv7) WaitKind
  | WaitActivationResultOpportunity UUIDv7
  | WaitResultOpportunity UUIDv7 Text
  | DelegationScopeOpportunity DelegationDraft
  | DelegationPolicyOpportunity DelegationDraft
  | DelegationDelayOpportunity DelegationDraft
  | DelegationPreviewOpportunity DelegationDraft
  | DelegationMessageOpportunity DelegationDraft
  | DelegationHandoffOpportunity UUIDv7
  | DelegationTakeBackPreviewOpportunity UUIDv7
  | DelegationReviewScreenOpportunity UUIDv7
  | DelegationResultOpportunity UUIDv7 Text
  | ExternalEffectApprovalScreenOpportunity UUIDv7
  | ExternalEffectRecoveryScreenOpportunity UUIDv7
  | ExternalEffectDuplicateRiskOpportunity UUIDv7
  | ExternalEffectEditOpportunity UUIDv7 Text
  | ExternalEffectDelayOpportunity UUIDv7
  | ExternalEffectResultOpportunity UUIDv7 Text
  | WorkSkipSymptomOpportunity UUIDv7 (Maybe UUIDv7)
  | WorkSkipReactionOpportunity UUIDv7 (Maybe UUIDv7) SkipSymptom
  | WorkSkipDiscoveryOpportunity UUIDv7 (Maybe UUIDv7) SkipDiscoveryNode Bool
  | WorkSkipConfirmationOpportunity UUIDv7 (Maybe UUIDv7) SkipSymptom
  | WorkOtherExplanationOpportunity UUIDv7 (Maybe UUIDv7) Text
  | WorkOtherPreviewOpportunity UUIDv7 (Maybe UUIDv7) Text
  | WorkInterestingOpportunity UUIDv7 (Maybe UUIDv7)
  | WorkBreakNatureOpportunity UUIDv7 (Maybe UUIDv7) (Maybe SkipSymptom)
  | WorkBreakDraftOpportunity UUIDv7 (Maybe UUIDv7) (Maybe SkipSymptom) (Maybe BrickNature) [Text]
  | WorkBreakPreviewOpportunity UUIDv7 (Maybe UUIDv7) (Maybe SkipSymptom) (Maybe BrickNature) [Text]
  | WorkBreakResultOpportunity UUIDv7 [UUIDv7]
  | WorkSprintDurationOpportunity UUIDv7 (Maybe UUIDv7)
  | WorkSkipAcknowledgedOpportunity UUIDv7 SkipSymptom SkipReaction
  | ArchivePreviewOpportunity UUIDv7 (Maybe UUIDv7) (Maybe SkipSymptom)
  | ArchiveResultOpportunity UUIDv7
  | RestorePreviewOpportunity UUIDv7
  | RestoreResultOpportunity UUIDv7
  | ArchiveReviewOpportunity UUIDv7 UUIDv7
  | CompletionResultOpportunity UUIDv7
  | RepairPreviewOpportunity Text FilePath FilePath FilePath FilePath Integer
  | RepairCandidateOpportunity Text Text FilePath FilePath FilePath DatasetCursor Integer
  | RepairCompleteOpportunity Text FilePath Bool
  deriving stock (Eq, Show)

data EnvelopeContent = EnvelopeContent
  { contentHeading :: Text
  , contentSubject :: Maybe Text
  , contentBody :: [Text]
  , contentQuestion :: Maybe Text
  }
  deriving stock (Eq, Show)

data Action = Action
  { actionId :: Text
  , actionLabel :: Text
  , actionShortcut :: Text
  , actionDefault :: Bool
  , actionConsequence :: Text
  }
  deriving stock (Eq, Show)

data CommandOption = CommandOption
  { commandOptionId :: Text
  , commandOptionCommand :: Text
  , commandOptionDescription :: Text
  }
  deriving stock (Eq, Show)

data Footer = Footer
  { footerParent :: Text
  , footerDomain :: Text
  , footerTimeLabel :: Text
  , footerTimeValue :: Text
  , footerNow :: Text
  , footerBrickCount :: Int
  , footerRawCount :: Int
  , footerReviewCount :: Int
  , footerMode :: Text
  , footerFocus :: Text
  , footerNotice :: Maybe Text
  , footerNoticeCount :: Int
  }
  deriving stock (Eq, Show)

data InteractionEnvelope = InteractionEnvelope
  { envelopeInteractionId :: UUIDv7
  , envelopeRevision :: Int
  , envelopeDatasetCursor :: DatasetCursor
  , envelopePreconditionHash :: Text
  , envelopeGrammar :: ScreenGrammar
  , envelopeOpportunity :: Opportunity
  , envelopeContent :: EnvelopeContent
  , envelopeActions :: [Action]
  , envelopeCommands :: [CommandOption]
  , envelopeUncertaintyRoute :: Maybe Text
  , envelopeFooter :: Footer
  , envelopeNoticeTurn :: Int
  , envelopeProvenance :: Text
  , envelopeIntegrityToken :: Text
  }
  deriving stock (Eq, Show)

data InteractionResponse = InteractionResponse
  { responseInteractionId :: UUIDv7
  , responseRevision :: Int
  , responseActionId :: Text
  , responseIntegrityToken :: Text
  , responseAnsweredCursor :: DatasetCursor
  }
  deriving stock (Eq, Show)

data ResponseValidation
  = ResponseAccepted DatasetCursor DatasetCursor
  | ResponseStale InteractionEnvelope
  deriving stock (Eq, Show)

makePristineEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> InteractionEnvelope
makePristineEnvelope identity cursor precondition now =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    PristineOpportunity
    (EnvelopeContent "No Bricks yet." Nothing ["Feed Little Ant its first raw material to get started."] Nothing)
    [ Action "feed.open" "feed" "f" False "Open the Feed text editor."
    , moreAction
    ]
    [feedCommand, helpCommand, exitCommand]
    Nothing
    (commonFooter now 0 0 0)

makeSafeEmptyEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> InteractionEnvelope
makeSafeEmptyEnvelope identity cursor precondition now =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    SafeEmptyOpportunity
    (EnvelopeContent "Nothing needs attention right now." Nothing ["Feed new raw material or come back later."] Nothing)
    [Action "next" "next" "n" False "Run the focus forecast again.", moreAction]
    [feedCommand, helpCommand, exitCommand]
    Nothing
    (commonFooter now 0 0 0)

makeRawTriageEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> InteractionEnvelope
makeRawTriageEnvelope identity cursor precondition now state raw =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (RawTriageOpportunity (rawId raw) (rawHandle raw) (rawPreview raw))
    (EnvelopeContent "Review raw material" (Just (rawCitation raw)) [] (Just "Is this something you could work on by itself?"))
    [ Action "raw.materialize-work" "yes" "y" False "Enter Work materialization."
    , Action "raw.choose-destination" "no" "n" False "Choose a compatible destination."
    , Action "raw.defer-triage" "skip" "s" False "Defer this Raw triage."
    , Action "raw.triage-assistance" "I don't know" "?" False "Clarify whether this material communicates one useful action."
    , moreAction
    ]
    (rawCommands raw)
    (Just "understand_subject")
    (rawFooter now state raw)

makeRawDuplicateEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> Raw -> InteractionEnvelope
makeRawDuplicateEnvelope identity cursor precondition now state candidate root =
  sealed
    identity
    1
    cursor
    precondition
    ConfirmationGrammar
    (RawDuplicateOpportunity (rawId candidate) (rawId root))
    ( EnvelopeContent
        "Review raw material:"
        Nothing
        ["Is", rawCitation candidate, "      a duplicate receipt of", rawCitation root]
        Nothing
    )
    [ Action "raw.duplicate.accept" "yes" "y" exact "Group the later receipt under the canonical Raw receipt."
    , Action "raw.duplicate.reject" "no" "n" False "Record revision-scoped negative duplicate evidence."
    , Action "raw.duplicate.defer" "skip" "s" False "Leave this duplicate review unresolved."
    , Action "raw.duplicate.inspect" "I don't know" "?" False "Inspect both complete Raw revisions side by side."
    , moreAction
    ]
    (rawCommands candidate)
    (Just "inspect_duplicate_receipts")
    (rawFooter now state candidate)
 where
  exact = rawOriginal candidate == rawOriginal root

makeTranslationScopeEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> TranslationScope -> Int -> Int -> Int -> InteractionEnvelope
makeTranslationScopeEnvelope identity cursor precondition now state scope titleCount rawTextCount unsupportedCount =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (TranslationScopeOpportunity scope)
    (EnvelopeContent "Translate what?" Nothing unsupportedBody Nothing)
    [ Action "translate.scope.all" ("all active titles and Raw material    " <> count (titleCount + rawTextCount) <> " candidates") "a" (translationScopeTitles scope && translationScopeRaws scope) "Review both Brick titles and supported Raw text."
    , Action "translate.scope.titles" ("titles only    " <> count titleCount <> " candidates") "t" (translationScopeTitles scope && not (translationScopeRaws scope)) "Review Brick titles only."
    , Action "translate.scope.raws" ("raw material only    " <> count rawTextCount <> " candidates") "r" (translationScopeRaws scope && not (translationScopeTitles scope)) "Review supported Raw text only."
    , Action "translate.scope.archived" "include archived material" "i" (translationScopeArchived scope) "Toggle archived Bricks and Raws in this queue."
    , Action "translate.scope.unknown" "I don't know" "?" False "Explain the review scope without changing data."
    , Action "translate.scope.continue" "continue" "enter" False "Begin the selected interruptible review queue."
    , moreAction
    ]
    [CommandOption "translate" "/translate" "Restart translation scope selection.", helpCommand, exitCommand]
    (Just "choose_translation_scope")
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  count = Text.pack . show
  unsupportedBody = [count unsupportedCount <> " unsupported non-text Raw revisions will be reported, not guessed." | unsupportedCount > 0]

makeTranslationEditorEnvelope :: InteractionEnvelope -> ZonedTime -> State -> TranslationQueue -> Maybe Text -> Maybe Text -> InteractionEnvelope
makeTranslationEditorEnvelope previous now state queue suggestion attribution =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (TranslationEditOpportunity queue suggestion attribution)
      (EnvelopeContent "English normalization for" (Just citation) (["Original", original, progress] <> attributionBody) Nothing)
      [ Action "translate.edit.submit" "preview" "enter" False "Preview this English normalization before accepting it."
      , Action "translate.edit.skip" "skip" "s" False "Leave this candidate unresolved and continue."
      , Action "translate.edit.unknown" "I don't know" "?" False "Explain normalization while preserving this candidate."
      , moreAction
      ]
      [CommandOption "translate" "/translate" "Restart translation scope selection.", helpCommand, exitCommand]
      (Just "enter_english_normalization")
      footer
 where
  (citation, original, footer) = translationCandidateView now state (currentTranslationCandidate queue)
  progress = "Progress: " <> Text.pack (show (translationQueueAccepted queue + translationQueueSkipped queue + 1)) <> " of " <> Text.pack (show (translationQueueTotal queue))
  attributionBody = maybe [] (pure . ("Suggested by: " <>)) attribution

makeTranslationPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> TranslationQueue -> Text -> NormalizationSource -> Maybe Text -> Maybe Fixed -> InteractionEnvelope
makeTranslationPreviewEnvelope previous now state queue proposed source producer confidence =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (TranslationPreviewOpportunity queue proposed source producer confidence)
      (EnvelopeContent "Use this English normalization?" (Just citation) ["Original: " <> original, "English: " <> proposed, consequence] Nothing)
      [ Action "translate.preview.accept" "yes" "y" True "Accept only this title or Raw-revision normalization."
      , Action "translate.preview.edit" "edit" "e" False "Return to the editor with this proposal selected."
      , Action "translate.preview.reject" "no" "n" False "Reject the proposal and return to a blank dumb editor."
      , Action "translate.preview.unknown" "I don't know" "?" False "Explain identity and history consequences."
      , moreAction
      ]
      [CommandOption "translate" "/translate" "Restart translation scope selection.", helpCommand, exitCommand]
      (Just "confirm_english_normalization")
      footer
 where
  candidate = currentTranslationCandidate queue
  (citation, original, footer) = translationCandidateView now state candidate
  consequence = case candidate of
    TranslationBrickTitle{} -> "The Brick handle and identity stay unchanged; event history preserves the prior title."
    TranslationRawRevision{} -> "The original Raw revision stays unchanged; this adds attributed normalization on the same Raw."

makeTranslationCompleteEnvelope :: InteractionEnvelope -> ZonedTime -> State -> TranslationQueue -> InteractionEnvelope
makeTranslationCompleteEnvelope previous now state queue =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (TranslationCompleteOpportunity (translationQueueAccepted queue) (translationQueueSkipped queue) (translationQueueTotal queue))
      (EnvelopeContent "Translation review complete." Nothing [progress] Nothing)
      [Action "next" "next" "n" False "Return to the ordinary opportunity forecast.", moreAction]
      [CommandOption "translate" "/translate" "Review unresolved translation candidates again.", helpCommand, exitCommand]
      Nothing
      (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  progress = Text.pack (show (translationQueueAccepted queue)) <> " accepted · " <> Text.pack (show (translationQueueSkipped queue)) <> " unresolved · " <> Text.pack (show (translationQueueTotal queue)) <> " total"

makeRawDetailEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> InteractionEnvelope
makeRawDetailEnvelope identity cursor precondition now state raw =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (RawDetailOpportunity (rawId raw))
    (EnvelopeContent "Raw:" (Just (rawCitation raw)) (rawDetailBody state raw) Nothing)
    [ Action "raw.detail.origin" "origin" "o" False "Inspect or reconcile external origins."
    , Action "raw.detail.translate" "translate" "t" False "Review English normalization for this Raw."
    , moreAction
    ]
    (CommandOption "translate" ("/translate " <> rawCitation raw) "Review this Raw's English normalization" : rawCommands raw)
    Nothing
    (rawFooter now state raw)

makeRawOriginListEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> InteractionEnvelope
makeRawOriginListEnvelope previous now state raw =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (RawOriginListOpportunity (rawId raw))
      (EnvelopeContent "External origins:" (Just (rawCitation raw)) emptyBody Nothing)
      (bindingActions <> [Action "raw.origin.add" "add an origin..." "a" False "Open the typed SourceBinding builder.", Action "raw.origin.back" "back" "esc" False "Return to Raw detail.", Action "raw.origin.unknown" "I don't know" "?" False "Explain origins without changing data.", moreAction])
      (rawCommands raw)
      Nothing
      (rawFooter now state raw)
 where
  bindings = sortOn sourceBindingLocator [binding | binding <- Map.elems (stateSourceBindings state), sourceBindingRaw binding == rawId raw]
  bindingActions = zipWith bindingAction [1 :: Int ..] bindings
  bindingAction number binding = Action ("raw.origin.select." <> renderUUIDv7 (sourceBindingId binding)) (sourceBindingKind binding <> " · " <> sourceBindingLocator binding <> " · " <> sourceLifecycleLabel (sourceBindingLifecycle binding)) (Text.pack (show number)) False "Inspect this stable origin and its latest observation."
  emptyBody = ["No external origin is attached." | null bindings]

makeSourceBindingEnvelope :: InteractionEnvelope -> ZonedTime -> State -> SourceBinding -> InteractionEnvelope
makeSourceBindingEnvelope previous now state binding =
  case if sourceBindingLifecycle binding == SourceBindingActive then latestPendingSourceObservation state binding else Nothing of
    Just observation | sourceObservationOutcome observation == SourceChanged -> makeSourceReconciliationEnvelope previous now state observation
    Just observation | sourceObservationOutcome observation /= SourceUnchanged -> makeSourceFailureEnvelope previous now state observation
    _ ->
      advanceEnvelope previous $
        sealed
          (envelopeInteractionId previous)
          (envelopeRevision previous)
          (envelopeDatasetCursor previous)
          (envelopePreconditionHash previous)
          ChoiceGrammar
          (SourceBindingOpportunity (sourceBindingId binding))
          (EnvelopeContent "External origin:" (rawCitation <$> Map.lookup (sourceBindingRaw binding) (stateRaws state)) ["Type: " <> sourceBindingKind binding, "Origin: " <> sourceBindingLocator binding, "Mode: " <> sourceModeLabel (sourceBindingMode binding), "Checks: " <> sourceCheckPolicyLabel (sourceBindingCheckPolicy binding), "State: " <> sourceLifecycleLabel (sourceBindingLifecycle binding)] Nothing)
          (sourceBindingActions binding <> [Action "source.binding.back" "back" "esc" False "Return to the Raw's origin list.", Action "source.binding.unknown" "I don't know" "?" False "Explain this origin without changing it.", moreAction])
          [helpCommand, exitCommand]
          Nothing
          (sourceFooter now state binding)

makeSourceReconciliationEnvelope :: InteractionEnvelope -> ZonedTime -> State -> SourceObservation -> InteractionEnvelope
makeSourceReconciliationEnvelope previous now state observation =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (SourceChangeOpportunity (sourceObservationId observation))
      (EnvelopeContent "Source changed:" citation ["Origin: " <> sourceObservationLocator observation, "Checked: " <> Text.pack (show (sourceObservationAt observation)), sourceDifferenceSummary state observation] (Just "What does the observed content mean?"))
      [ Action "source.change.same" "update the same Raw" "u" True "Append one immutable revision and advance this origin's accepted baseline."
      , Action "source.change.derived" "derive new Raw material" "d" False "Preserve a new Raw linked derived_from while retaining this binding on its original Raw."
      , Action "source.change.unrelated" "ignore as unrelated" "i" False "Record this decision and advance only the source baseline."
      , Action "source.change.view" "view differences" "v" False "Inspect the bounded old and observed representations."
      , Action "source.change.unknown" "I don't know" "?" False "Explain revision, derivation, and unrelated content."
      , moreAction
      ]
      [helpCommand, exitCommand]
      (Just "reconcile_source_change")
      footer
 where
  (citation, footer) = sourceObservationContext now state observation

makeSourceReconciliationPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> SourceObservation -> SourceReconciliationChoice -> InteractionEnvelope
makeSourceReconciliationPreviewEnvelope previous now state observation choice =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (SourceReconciliationPreviewOpportunity (sourceObservationId observation) choice)
      (EnvelopeContent (sourceChoiceHeading choice) citation (sourceChoiceConsequences state observation choice) Nothing)
      [ Action "source.reconcile.accept" "yes" "y" True "Commit exactly this reconciliation and accepted baseline."
      , Action "source.reconcile.edit" "edit" "e" False "Return to the three-way source decision."
      , Action "source.reconcile.reject" "no" "n" False "Return without recording this proposal."
      , Action "source.reconcile.unknown" "I don't know" "?" False "Explain the exact identity, content, and baseline consequences."
      , moreAction
      ]
      [helpCommand, exitCommand]
      (Just "confirm_source_reconciliation")
      footer
 where
  (citation, footer) = sourceObservationContext now state observation

makeSourceFailureEnvelope :: InteractionEnvelope -> ZonedTime -> State -> SourceObservation -> InteractionEnvelope
makeSourceFailureEnvelope previous now state observation =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (SourceFailureOpportunity (sourceObservationId observation))
      (EnvelopeContent ("We could not read this origin: " <> sourceOutcomeLabel (sourceObservationOutcome observation)) citation ["Origin: " <> sourceObservationLocator observation, "Checked: " <> Text.pack (show (sourceObservationAt observation)), "Local Raw content and Work state are unchanged."] Nothing)
      [ Action "source.failure.retry" "retry" "r" False "Ask the owning adapter to check again without changing local truth."
      , Action "source.failure.pause" "pause checks" "p" False "Preview pausing this binding while preserving its policy."
      , Action "source.failure.move" "move origin" "m" False "Enter a replacement locator and preview identity consequences."
      , Action "source.failure.detach" "detach origin" "d" False "Preview stopping future checks while retaining all local history."
      , Action "source.failure.later" "later" "l" False "Return to Raw detail without changing the binding."
      , Action "source.failure.unknown" "I don't know" "?" False "Explain why source failure is not completion or archive."
      , moreAction
      ]
      [helpCommand, exitCommand]
      (Just "recover_source_failure")
      footer
 where
  (citation, footer) = sourceObservationContext now state observation

makeSourceRelocateEnvelope :: InteractionEnvelope -> ZonedTime -> State -> SourceBinding -> Text -> InteractionEnvelope
makeSourceRelocateEnvelope previous now state binding draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (SourceRelocateOpportunity (sourceBindingId binding) draft)
      (EnvelopeContent "Move external origin" (rawCitation <$> Map.lookup (sourceBindingRaw binding) (stateRaws state)) ["Current: " <> sourceBindingLocator binding, draft] Nothing)
      [Action "source.relocate.submit" "preview" "enter" False "Preview the new locator before changing the binding.", moreAction]
      [helpCommand, exitCommand]
      Nothing
      (sourceFooter now state binding)

makeSourceRelocatePreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> SourceBinding -> Text -> InteractionEnvelope
makeSourceRelocatePreviewEnvelope previous now state binding locator =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (SourceRelocatePreviewOpportunity (sourceBindingId binding) locator)
      (EnvelopeContent "Move this external origin?" (rawCitation <$> Map.lookup (sourceBindingRaw binding) (stateRaws state)) ["From: " <> sourceBindingLocator binding, "To: " <> locator, identityWarning] Nothing)
      [Action "source.relocate.accept" "yes" "y" False "Preserve binding identity and accept this visible locator move.", Action "source.relocate.edit" "edit" "e" False "Edit the proposed locator.", Action "source.relocate.reject" "no" "n" True "Keep the current locator.", Action "source.relocate.unknown" "I don't know" "?" False "Explain provider identity and human confirmation.", moreAction]
      [helpCommand, exitCommand]
      Nothing
      (sourceFooter now state binding)
 where
  identityWarning = maybe "Provider identity is unavailable; yes is explicit human confirmation." ("Stable provider identity: " <>) (sourceBindingExternalIdentity binding)

makeSourceLifecyclePreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> SourceBinding -> SourceBindingLifecycle -> InteractionEnvelope
makeSourceLifecyclePreviewEnvelope previous now state binding lifecycle =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (SourceLifecyclePreviewOpportunity (sourceBindingId binding) lifecycle)
      (EnvelopeContent (sourceLifecycleHeading lifecycle) (rawCitation <$> Map.lookup (sourceBindingRaw binding) (stateRaws state)) ["Origin: " <> sourceBindingLocator binding, lifecycleConsequence lifecycle] Nothing)
      [Action "source.lifecycle.accept" "yes" "y" False "Apply only this binding lifecycle change.", Action "source.lifecycle.reject" "no" "n" True "Keep the binding unchanged.", Action "source.lifecycle.unknown" "I don't know" "?" False "Explain what local material remains preserved.", moreAction]
      [helpCommand, exitCommand]
      Nothing
      (sourceFooter now state binding)

makeSourceResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> Text -> InteractionEnvelope
makeSourceResultEnvelope identity cursor precondition now state raw result =
  sealed identity 1 cursor precondition ChoiceGrammar (SourceResultOpportunity (rawId raw) result) (EnvelopeContent "Origin updated." (Just (rawCitation raw)) [result] Nothing) [Action "source.result.back" "back to Raw" "enter" True "Return to Raw detail.", Action "next" "next" "n" False "Return to the ordinary opportunity forecast.", moreAction] (rawCommands raw) Nothing (rawFooter now state raw)

makeImportPreflightEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Text -> Text -> Bool -> SourcePreflight -> InteractionEnvelope
makeImportPreflightEnvelope identity cursor precondition now state profileName sourceReference eraseAfterImport preflight =
  sealed
    identity
    1
    cursor
    precondition
    ConfirmationGrammar
    (ImportPreflightOpportunity sourceReference preflight eraseAfterImport)
    ( EnvelopeContent
        "Import preview:"
        Nothing
        ( [ observedSourceLabel observation <> accountSuffix
          , "Mode: " <> sourceModeName (sourcePreflightMode preflight)
          ]
            <> identityLines
            <> [ ""
               , "Containers: " <> count containers
               , "Items: " <> count openObjects <> " open · " <> count completedObjects <> " completed"
               , "Attachments: " <> Text.pack (show attachments)
               , "Will preserve: " <> count objects <> " Raws with source identity"
               , "Destination profile: " <> profileName
               , "Possible duplicates: " <> Text.pack (show duplicateSuspicions)
               ]
            <> unsupportedLine
            <> warningLines
            <> ["", "Nothing will be deleted from the source."]
        )
        Nothing
    )
    [ Action "import.accept" "import" "i" False "Rerun this preflight and atomically preserve verified Raw truth."
    , Action "import.back" "back" "b" False "Leave this preview without importing."
    , Action "import.unknown" "I don't know" "?" False "Explain Raw-first import and source cleanup."
    , moreAction
    ]
    [CommandOption "import" "/import" "Choose another import source", helpCommand, exitCommand]
    Nothing
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  observation = sourcePreflightObservation preflight
  containers = observedContainers observation
  objects = observedObjects observation
  openObjects = filter (not . sourceObjectCompleted) objects
  completedObjects = filter sourceObjectCompleted objects
  attachments = sum (sourceObjectAttachmentCount <$> objects)
  duplicateSuspicions = length (filter (not . null . sourceObjectDuplicateKeys) objects)
  accountSuffix = maybe "" (" · " <>) (observedAccountLabel observation)
  identityLines =
    ["Planning manifest: " <> value | Just value <- [Map.lookup "planning_manifest_sha256" (observedIdentity observation)]]
      <> ["Actuals as of: " <> value | Just value <- [Map.lookup "actuals_as_of" (observedIdentity observation)]]
      <> ["Actual records: " <> value | Just value <- [Map.lookup "actual_record_count" (observedIdentity observation)]]
  unsupportedLine = case observedUnsupportedFields observation of
    [] -> []
    unsupported -> ["Unsupported fields: " <> Text.intercalate "; " unsupported]
  warningLines = ("Warning: " <>) <$> observedWarnings observation
  count = Text.pack . show . length

makeImportResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> [UUIDv7] -> [UUIDv7] -> Bool -> Bool -> InteractionEnvelope
makeImportResultEnvelope identity cursor precondition now state imported reused cleanupReady dryRun =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (ImportResultOpportunity imported reused cleanupReady)
    ( EnvelopeContent
        (if dryRun then "Import simulation verified." else "Import verified.")
        Nothing
        [ count imported <> newRawSuffix <> " · " <> count reused <> existingRawSuffix
        , if dryRun then "0 source items would change" else "0 source items changed"
        ]
        Nothing
    )
    ( triageAction
        <> [Action "next" "next" "n" False "Return to the ordinary opportunity forecast."]
        <> cleanupAction
        <> [moreAction]
    )
    [CommandOption "import" "/import" "Import another source", helpCommand, exitCommand]
    Nothing
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  triageAction = [Action "import.triage" "triage imported material" "t" False "Open ordinary lazy Raw triage." | not (null (imported <> reused))]
  cleanupAction = [Action "import.cleanup" "clean up the source..." "c" False "Open a separate exact cleanup approval." | cleanupReady]
  newRawSuffix = if dryRun then " new Raws would be preserved" else " new Raws preserved"
  existingRawSuffix = " already preserved"
  count = Text.pack . show . length

makePackInstallEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> PackInstallDraft -> AuthenticatedPack -> InteractionEnvelope
makePackInstallEnvelope identity cursor precondition now state draft authenticated =
  sealed
    identity
    1
    cursor
    precondition
    ConfirmationGrammar
    (PackInstallOpportunity draft)
    ( EnvelopeContent
        "Install Pack?"
        (Just (packName manifest))
        ( [ packDisplayName manifest <> " " <> packVersion manifest
          , "Publisher: " <> packPublisher manifest <> " · " <> packInstallTrustClass draft
          , "Digest: sha256:" <> abbreviatedDigest (artifactArchiveDigest (packInstallArtifact draft))
          , ""
          , "Components:"
          ]
            <> fmap componentLine (packComponents manifest)
            <> [ "HTTP: " <> orNone httpHosts
               , "Credentials: " <> orNone credentials
               , "External effects: " <> orNone effects
               , "Local UI authority: " <> orNone localUiAuthority
               ]
        )
        Nothing
    )
    actions
    [CommandOption "packs" "/packs" "Inspect Packs and installation state", helpCommand, exitCommand]
    (Just "binary_consent")
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  manifest = structurallyValidManifest (authenticatedStructuralPack authenticated)
  actions
    | packInstallTrustClass draft == "untrusted" =
        [ Action "pack.install.trust" "trust publisher..." "t" False "Inspect and separately trust this exact publisher key."
        , Action "pack.install.back" "back" "b" False "Leave the candidate uninstalled and untrusted."
        , Action "pack.install.unknown" "I don't know" "?" False "Explain the separate trust and installation decisions."
        , moreAction
        ]
    | otherwise =
        [ Action "pack.install.accept" "install" "i" False "Store this exact signed archive and pin its displayed components."
        , Action "pack.install.back" "back" "b" False "Leave the candidate uninstalled."
        , Action "pack.install.unknown" "I don't know" "?" False "Explain the authority granted by this installation."
        , moreAction
        ]
  componentLine component =
    let common = componentCommon component
     in "  " <> componentKindText (componentKind common) <> ": " <> componentId common
  executablePermissions = [permissions | ExecutableComponent _ _ permissions <- packComponents manifest]
  httpHosts = Set.toAscList . Set.fromList $ httpPermissionHost <$> (permissionHttp =<< executablePermissions)
  credentials =
    Set.toAscList . Set.fromList $
      [ credentialSlotId slot <> " (" <> credentialSchemeText (credentialSlotScheme slot) <> ")"
      | permissions <- executablePermissions
      , slot <- permissionCredentialSlots permissions
      ]
  effects = Set.toAscList . Set.fromList $ effectPermissionText <$> (permissionEffectPurposes =<< executablePermissions)
  localUiAuthority =
    Set.toAscList . Set.fromList $
      [ componentId common <> " (" <> Text.intercalate ", " (hostCapabilityText <$> permissionHostCapabilities permissions) <> ")"
      | ExecutableComponent common _ permissions <- packComponents manifest
      , componentKind common == UIAdapterComponent
      ]
  orNone [] = "none"
  orNone values = Text.intercalate ", " values

makePackTrustEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> PackTrustDraft -> InteractionEnvelope
makePackTrustEnvelope identity cursor precondition now state draft =
  sealed
    identity
    1
    cursor
    precondition
    ConfirmationGrammar
    (PackTrustOpportunity draft)
    ( EnvelopeContent
        "Trust Pack publisher?"
        (Just (communityPublisher publisher))
        [ "Publisher: " <> communityPublisher publisher
        , "Full fingerprint:"
        , communityKeyFingerprint publisher
        , ""
        , "Trust is local to the selected profile. It does not install a Pack."
        ]
        Nothing
    )
    [ Action "pack.trust.accept" "trust" "t" False "Trust this exact publisher and public key in the selected profile."
    , Action "pack.trust.back" "back" "b" False "Leave this publisher untrusted."
    , Action "pack.trust.unknown" "I don't know" "?" False "Explain publisher-key trust without changing it."
    , moreAction
    ]
    [CommandOption "packs" "/packs" "Inspect trusted publishers and Packs", helpCommand, exitCommand]
    (Just "binary_consent")
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  publisher = packTrustPublisher draft

makePackInstallResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> PackArtifactIdentity -> InteractionEnvelope
makePackInstallResultEnvelope identity cursor precondition now state artifact =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (PackInstallResultOpportunity artifact)
    "Pack installed."
    [artifactName artifact <> " " <> artifactVersion artifact, "sha256:" <> abbreviatedDigest (artifactArchiveDigest artifact)]

makePackTrustResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> TrustedCommunityPublisher -> InteractionEnvelope
makePackTrustResultEnvelope identity cursor precondition now state publisher =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (PackTrustResultOpportunity publisher)
    "Publisher trusted."
    [communityPublisher publisher, communityKeyFingerprint publisher]

abbreviatedDigest :: Text -> Text
abbreviatedDigest digest = Text.take 8 digest <> "…" <> Text.takeEnd 4 digest

rawDetailBody :: State -> Raw -> [Text]
rawDetailBody state raw =
  [rawRepresentationLabel content <> " · revision " <> Text.pack (show (rawContentRevisionOrdinal revision)), rawContentPreview content, englishLine, "Links: " <> count links, "Shelves: " <> count shelves, "Domains: " <> count domains, "Sources: " <> count sources]
 where
  revision = currentRawContentRevision state raw
  content = rawContentRevisionContent revision
  englishLine = case Map.lookup (rawContentRevisionId revision) (stateCurrentEnglishNormalizations state) >>= (`Map.lookup` stateEnglishNormalizations state) of
    Just normalization -> "English: " <> englishNormalizationText normalization
    Nothing -> "English: missing"
  links = [() | link <- Map.elems (stateRawLinks state), rawLinkRaw link == rawId raw || rawLinkTarget link == RawLinkRaw (rawId raw)]
  shelves = [() | shelf <- Map.elems (stateRawShelves state), rawId raw `elem` rawShelfMembers shelf]
  domains = []
  sources = [() | binding <- Map.elems (stateSourceBindings state), sourceBindingRaw binding == rawId raw]
  count = Text.pack . show . length

currentRawContentRevision :: State -> Raw -> RawContentRevision
currentRawContentRevision state raw =
  case Map.lookup (rawId raw) (stateCurrentRawRevisions state) >>= (`Map.lookup` stateRawContentRevisions state) of
    Just revision -> revision
    Nothing -> error "A preserved Raw requires one current content revision."

rawRepresentationLabel :: RawContent -> Text
rawRepresentationLabel = \case RawTextContent{} -> "Original · text"; RawUriContent{} -> "Original · URI"; RawBlobContent{} -> "Original · blob"; RawStructuredContent{} -> "Original · structured"

rawContentPreview :: RawContent -> Text
rawContentPreview =
  Text.take 240 . \case
    RawTextContent text -> text
    RawUriContent locator label -> fromMaybe locator label
    RawBlobContent digest mediaType lengthBytes filename -> fromMaybe "blob" filename <> " · " <> mediaType <> " · " <> Text.pack (show lengthBytes) <> " bytes · " <> Text.take 12 digest
    RawStructuredContent schema json -> schema <> " · " <> json

latestPendingSourceObservation :: State -> SourceBinding -> Maybe SourceObservation
latestPendingSourceObservation state binding =
  case reverse . sortOn sourceObservationAt $ filter pending (Map.elems (stateSourceObservations state)) of
    observation : _ -> Just observation
    [] -> Nothing
 where
  pending observation = sourceObservationBinding observation == sourceBindingId binding && sourceObservationOutcome observation /= SourceUnchanged && not (any ((== sourceObservationId observation) . sourceReconciliationObservation) (Map.elems (stateSourceReconciliations state)))

sourceBindingActions :: SourceBinding -> [Action]
sourceBindingActions binding = case sourceBindingLifecycle binding of
  SourceBindingActive -> [check, move, Action "source.binding.pause" "pause checks" "p" False "Preview pausing future checks.", detach]
  SourceBindingPaused -> [move, Action "source.binding.resume" "resume checks" "r" False "Preview restoring the declared check policy.", detach]
  SourceBindingDetached -> []
 where
  check = Action "source.binding.check" "check now" "c" False "Ask the owning adapter for one immutable observation."
  move = Action "source.binding.move" "move origin" "m" False "Preview a locator change."
  detach = Action "source.binding.detach" "detach origin" "d" False "Preview permanent detachment from future checks."

sourceObservationContext :: ZonedTime -> State -> SourceObservation -> (Maybe Text, Footer)
sourceObservationContext now state observation =
  case Map.lookup (sourceObservationBinding observation) (stateSourceBindings state) >>= (\binding -> Map.lookup (sourceBindingRaw binding) (stateRaws state)) of
    Just raw -> (Just (rawCitation raw), rawFooter now state raw)
    Nothing -> (Nothing, commonFooter now (brickCount state) (rawCount state) (reviewCount state))

sourceFooter :: ZonedTime -> State -> SourceBinding -> Footer
sourceFooter now state binding = maybe (commonFooter now (brickCount state) (rawCount state) (reviewCount state)) (rawFooter now state) (Map.lookup (sourceBindingRaw binding) (stateRaws state))

sourceDifferenceSummary :: State -> SourceObservation -> Text
sourceDifferenceSummary state observation =
  case (Map.lookup (sourceObservationBinding observation) (stateSourceBindings state) >>= (\binding -> Map.lookup (sourceBindingRaw binding) (stateRaws state)), sourceObservationSnapshot observation) of
    (Just raw, Just observed) -> "Current: " <> rawContentPreview (rawContentRevisionContent (currentRawContentRevision state raw)) <> "\nObserved: " <> rawContentPreview observed
    _ -> "Changed content is available as canonical snapshot material."

sourceChoiceHeading :: SourceReconciliationChoice -> Text
sourceChoiceHeading = \case ReconcileSameRaw -> "Update this same Raw?"; ReconcileDerivedRaw -> "Create derived Raw material?"; ReconcileUnrelated -> "Ignore this observation as unrelated?"

sourceChoiceConsequences :: State -> SourceObservation -> SourceReconciliationChoice -> [Text]
sourceChoiceConsequences state observation = \case
  ReconcileSameRaw -> ["Append one immutable revision to the bound Raw.", "Advance the accepted source baseline to this observation.", sourceDifferenceSummary state observation]
  ReconcileDerivedRaw -> ["Create one new Inbox Raw with the observed snapshot.", "Link it derived_from the bound Raw; keep the SourceBinding on the original Raw.", "Advance the accepted source baseline to this observation."]
  ReconcileUnrelated -> ["Do not change or create Raw content.", "Record the observation as unrelated and advance only the accepted source baseline."]

sourceOutcomeLabel :: SourceObservationOutcome -> Text
sourceOutcomeLabel = \case SourceUnchanged -> "unchanged"; SourceChanged -> "changed"; SourceMissing -> "missing"; SourceUnreachable -> "unreachable"; SourceUnauthorized -> "unauthorized"; SourceMalformed -> "malformed"

sourceModeLabel :: SourceMode -> Text
sourceModeLabel = \case SourceSnapshot -> "snapshot"; SourceSynchronize -> "synchronize"; SourceMigrate -> "migrate"

sourceCheckPolicyLabel :: SourceCheckPolicy -> Text
sourceCheckPolicyLabel = \case SourceManualCheck -> "manual"; SourceIntervalCheck seconds -> "every " <> Text.pack (show seconds) <> " seconds"

sourceLifecycleLabel :: SourceBindingLifecycle -> Text
sourceLifecycleLabel = \case SourceBindingActive -> "active"; SourceBindingPaused -> "paused"; SourceBindingDetached -> "detached"

sourceLifecycleHeading :: SourceBindingLifecycle -> Text
sourceLifecycleHeading = \case SourceBindingActive -> "Resume checks for this origin?"; SourceBindingPaused -> "Pause checks for this origin?"; SourceBindingDetached -> "Detach this external origin?"

lifecycleConsequence :: SourceBindingLifecycle -> Text
lifecycleConsequence = \case SourceBindingActive -> "The declared schedule becomes active again; no missed observation is invented."; SourceBindingPaused -> "Future automatic checks stop until resumed; all content and observations remain."; SourceBindingDetached -> "Future checks stop permanently for this binding; all local content and history remain."

currentTranslationCandidate :: TranslationQueue -> TranslationCandidate
currentTranslationCandidate queue = case translationQueueRemaining queue of
  candidate : _ -> candidate
  [] -> error "A translation editor requires one remaining candidate."

translationCandidateView :: ZonedTime -> State -> TranslationCandidate -> (Text, Text, Footer)
translationCandidateView now state = \case
  TranslationBrickTitle identity -> case Map.lookup identity (stateBricks state) of
    Just brick -> (brickCitation brick, brickTitle brick, brickFooter now state brick)
    Nothing -> ("<missing Brick>", "<missing>", commonFooter now (brickCount state) (rawCount state) (reviewCount state))
  TranslationRawRevision rawIdentity revisionIdentity ->
    case (Map.lookup rawIdentity (stateRaws state), Map.lookup revisionIdentity (stateRawContentRevisions state)) of
      (Just raw, Just revision) ->
        let original = case rawContentRevisionContent revision of
              RawTextContent text -> text
              _ -> "<unsupported non-text representation>"
         in (rawCitation raw, original, rawFooter now state raw)
      _ -> ("<missing Raw>", "<missing>", commonFooter now (brickCount state) (rawCount state) (reviewCount state))

makeRawDestinationEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> Int -> InteractionEnvelope
makeRawDestinationEnvelope previous now state raw page =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (RawDestinationOpportunity (rawId raw) page)
      (EnvelopeContent ("Does " <> rawCitation raw <> " belong with any of these?") Nothing [] Nothing)
      (candidateActions <> [keepAction, createAction, unknownAction, menuAction])
      (rawCommands raw)
      (Just "choose_raw_destination")
      (rawFooter now state raw)
 where
  candidates = take 4 . drop (page * 4) $ destinationCandidates state
  candidateActions = zipWith candidateAction [1 :: Int ..] candidates
  candidateAction number = \case
    DestinationBrick brick -> Action ("raw.destination.brick." <> renderUUIDv7 (brickId brick)) (brickCitation brick <> " — " <> natureLabel (brickNature brick)) (Text.pack (show number)) False "Continue according to the selected Brick.s Nature."
    DestinationShelf shelf -> Action ("raw.destination.shelf." <> renderUUIDv7 (rawShelfId shelf)) ("Shelf \"" <> rawShelfName shelf <> "\" — raw shelf") (Text.pack (show number)) False "Preview one direct ordered RawShelf membership."
  keepAction = Action "raw.keep-standalone" "keep as standalone raw material" "k" False "Settle triage without creating another object."
  createAction = Action "raw.create-group" "create a new group..." "c" False "Choose list, shelf, or independently focusable Work behavior."
  unknownAction = Action "raw.destination-assistance" "I don't know" "?" False "Clarify what kind of destination is needed."
  menuAction = moreAction{actionLabel = "menu..."}

makeRawUnderBrickEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> Brick -> InteractionEnvelope
makeRawUnderBrickEnvelope previous now state raw target =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (RawUnderBrickOpportunity (rawId raw) (brickId target))
      ( EnvelopeContent
          (rawCitation raw)
          Nothing
          []
          (Just ("Should Little Ant suggest this independently as Work within " <> brickCitation target <> "?"))
      )
      [ Action "raw.child-work" "yes" "y" False "Enter ordinary child-Work materialization."
      , Action "raw.attach" "no" "n" False "Choose how this Raw supports the selected Brick."
      , Action "raw.under-brick-assistance" "I don't know" "?" False "Explain independent Work versus supporting material."
      , moreAction
      ]
      (rawCommands raw)
      (Just "distinguish_child_work_from_attachment")
      (brickFooter now state target)

makeRawAttachmentEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> Brick -> InteractionEnvelope
makeRawAttachmentEnvelope previous now state raw target =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (RawAttachmentOpportunity (rawId raw) (brickId target))
      (EnvelopeContent ("How does " <> rawCitation raw <> " support " <> brickCitation target <> "?") Nothing [] Nothing)
      [ Action "raw.attach.description" "description    show this text as the Brick's description" "d" False "Create the Brick's single description link."
      , Action "raw.attach.attachment" "attachment     keep useful material beside the Brick" "a" False "Attach this Raw without making a claim."
      , Action "raw.attach.evidence" "evidence       record material that supports a judgment or claim" "e" False "Attach this Raw as evidence."
      , Action "raw.attachment-assistance" "I don't know" "?" False "Distinguish the three allowed consequences."
      , moreAction
      ]
      (rawCommands raw)
      (Just "choose_raw_link_role")
      (brickFooter now state target)

makeRawAttachmentResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> Brick -> RawLinkRole -> InteractionEnvelope
makeRawAttachmentResultEnvelope identity cursor precondition now state raw target role =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (RawAttachmentResultOpportunity (rawId raw) (brickId target) role)
    "Linked raw material:"
    [rawCitation raw, roleLabel role <> " for " <> brickCitation target]
 where
  roleLabel = \case
    DescriptionRole -> "Description"
    AttachmentRole -> "Attachment"
    EvidenceRole -> "Evidence"
    _ -> "Raw link"
makeRawGroupDiscoveryEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> InteractionEnvelope
makeRawGroupDiscoveryEnvelope previous now state raw =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (RawGroupDiscoveryOpportunity (rawId raw))
      (EnvelopeContent ("Create a new group for " <> rawCitation raw) Nothing [] (Just "How should this group behave?"))
      [ Action "raw-group.list" "list    show its items together as one working unit" "l" False "Start a checklist builder."
      , Action "raw-group.shelf" "shelf    organize raw material without turning it into Work" "s" False "Name and preview a RawShelf."
      , Action "raw-group.work" "work group    let its children appear independently in next" "w" False "Start ordinary Work-container discovery."
      , Action "raw-group.assistance" "I don't know" "?" False "Distinguish list, shelf, and independently suggestible Work."
      , moreAction
      ]
      (rawCommands raw)
      (Just "discover_group_mechanics")
      (rawFooter now state raw)

makeRawShelfNameEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> Text -> InteractionEnvelope
makeRawShelfNameEnvelope previous now state raw name =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (RawShelfNameOpportunity (rawId raw) name)
      (EnvelopeContent "Raw shelf name" (Just ("First member: " <> rawCitation raw)) [name, "", "Tip: write canonical names in English when practical."] Nothing)
      [Action "raw-shelf.name.submit" "preview" "enter" False "Validate the edited name and open the complete preview."]
      (rawCommands raw)
      Nothing
      (rawFooter now state raw)

makeRawShelfCreatePreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> Text -> InteractionEnvelope
makeRawShelfCreatePreviewEnvelope previous now state raw name =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (RawShelfCreatePreviewOpportunity (rawId raw) name)
      (EnvelopeContent "Create this raw shelf?" Nothing ["Shelf: " <> name, "First member: " <> rawCitation raw, "Raw material remains preserved."] Nothing)
      [ Action "raw-shelf.create" "yes" "y" True "Create the RawShelf, ordered membership, and Raw disposition atomically."
      , Action "raw-shelf.edit" "edit" "e" False "Return to the selected shelf name."
      , Action "raw-shelf.cancel" "no" "n" False "Discard only the shelf draft."
      , Action "raw-shelf.assistance" "I don't know" "?" False "Explain the shelf's flat organizational semantics."
      , moreAction
      ]
      (rawCommands raw)
      (Just "confirm_raw_shelf")
      (rawFooter now state raw)

makeRawShelfMembershipPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> RawShelf -> InteractionEnvelope
makeRawShelfMembershipPreviewEnvelope previous now state raw shelf =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (RawShelfMembershipPreviewOpportunity (rawId raw) (rawShelfId shelf))
      (EnvelopeContent "Add this raw material to the shelf?" (Just ("Shelf \"" <> rawShelfName shelf <> "\"")) [rawCitation raw, "Position: " <> Text.pack (show (length (rawShelfMembers shelf) + 1)), "Raw material remains preserved."] Nothing)
      [ Action "raw-shelf.add" "yes" "y" True "Append one direct ordered membership and settle Raw triage."
      , Action "raw-shelf.cancel" "no" "n" False "Return to destination selection unchanged."
      , Action "raw-shelf.assistance" "I don't know" "?" False "Explain that shelves organize Raw without creating Work."
      , moreAction
      ]
      (rawCommands raw)
      (Just "confirm_raw_shelf_membership")
      (rawFooter now state raw)

makeRawShelfResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> RawShelf -> InteractionEnvelope
makeRawShelfResultEnvelope identity cursor precondition now state raw shelf =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (RawShelfResultOpportunity (rawId raw) (rawShelfId shelf))
    "Raw material organized:"
    [rawCitation raw, "Shelf \"" <> rawShelfName shelf <> "\""]
makeNatureChoiceEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkContext -> InteractionEnvelope
makeNatureChoiceEnvelope previous now state raw context =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (NatureChoiceOpportunity context)
      (EnvelopeContent (quotedDraft raw) Nothing [] (Just "How should this behave?"))
      (fmap natureAction factoryNatures <> [Action "nature.discover" "I don't know" "?" False "Start bounded behavioral discovery."])
      (rawCommands raw)
      (Just "discover_nature")
      (rawFooter now state raw)
 where
  natureAction definition =
    Action
      ("nature.choose." <> natureDefinitionId definition)
      (natureDisplayLabel definition <> "    e.g. \"" <> natureExample definition <> "\"")
      (natureShortcut definition)
      False
      ("Select the " <> natureDefinitionId definition <> " factory Nature.")

makeNatureDiscoveryEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkContext -> NatureDiscovery -> InteractionEnvelope
makeNatureDiscoveryEnvelope previous now state raw context discovery =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (NatureDiscoveryOpportunity context discovery)
      (EnvelopeContent (quotedDraft raw) Nothing explanation (Just (natureQuestionText discovery)))
      [ Action "nature.answer.yes" "yes" "y" False "Follow the yes branch."
      , Action "nature.answer.no" "no" "n" False "Follow the no branch."
      , Action "nature.answer.unknown" "I don't know" "?" False "Ask the alternate probe or leave the draft pending."
      ]
      (rawCommands raw)
      (Just "nature_discovery")
      (rawFooter now state raw)
 where
  explanation = [natureProbeExplanation (discoveryQuestion discovery) | discoveryAlternateProbe discovery]

makeNatureConfirmationEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkContext -> BrickNature -> Text -> NatureQuestion -> InteractionEnvelope
makeNatureConfirmationEnvelope previous now state raw context nature reason lastQuestion =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (NatureConfirmationOpportunity context nature reason lastQuestion)
      (EnvelopeContent (quotedDraft raw) Nothing ["Classification: " <> natureLabel nature, "Because: " <> reason] (Just "Is this right?"))
      [ Action "nature.confirm" "yes" "y" True "Accept this Nature and continue."
      , Action "nature.reject" "no" "n" False "Return to direct factory Nature choice."
      , Action "nature.restart" "I don't know" "?" False "Restart behavioral discovery from its first question."
      ]
      (rawCommands raw)
      (Just "confirm_nature")
      (rawFooter now state raw)

makeTemplateChoiceEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkContext -> BrickNature -> InteractionEnvelope
makeTemplateChoiceEnvelope previous now state raw context nature =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (TemplateChoiceOpportunity context nature)
      (EnvelopeContent ("Nature: " <> natureLabel nature) Nothing [] (Just "Choose an optional setup:"))
      (templateActions <> [Action "template.none" "no template    keep only the Nature behavior" "n" False "Continue without a Template.", Action "template.assistance" "I don't know" "?" False "Inspect compatible setup differences."])
      (rawCommands raw)
      (Just "choose_template")
      (rawFooter now state raw)
 where
  definitions = compatibleTemplates nature
  assigned = assignTemplateShortcuts definitions
  templateActions =
    [ Action ("template.choose." <> templateDefinitionId definition) (templateDisplayLabel definition <> "    e.g. \"" <> templateExample definition <> "\"") shortcut False "Apply this one-time creation recipe."
    | (definition, shortcut) <- assigned
    ]

makeWorkTitleEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkContext -> BrickNature -> Maybe TemplateSelection -> Text -> InteractionEnvelope
makeWorkTitleEnvelope previous now state raw context nature template title =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (WorkTitleOpportunity context nature template title)
      (EnvelopeContent "Brick title" (Just ("Source: " <> rawCitation raw)) [title] Nothing)
      [Action "work.title.submit" "continue" "enter" False "Accept the edited title and continue."]
      (rawCommands raw)
      Nothing
      (rawFooter now state raw)

makeWorkPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkDraft -> InteractionEnvelope
makeDomainSelectionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkDraft -> [UUIDv7] -> InteractionEnvelope
makeDomainSelectionEnvelope previous now state raw draft candidates =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (DomainSelectionOpportunity draft candidates)
      (EnvelopeContent "Select zero or more Domains:" (Just ("Work: \"" <> workDraftTitle draft <> "\"")) [] Nothing)
      (domainActions <> [clearAction, continueAction, assistanceAction, moreAction])
      (rawCommands raw)
      (Just "confirm_direct_domains")
      (rawFooter now state raw)
 where
  domainActions =
    [ Action
        ("domain.toggle." <> renderUUIDv7 identity)
        ((if identity `Set.member` workDraftDomains draft then "* " else "  ") <> domainPath state identity)
        (Text.pack (show number))
        False
        "Toggle this direct Domain membership proposal."
    | (number, identity) <- zip [1 :: Int ..] candidates
    ]
  clearAction = Action "domain.clear" "no Domain" "n" False "Clear every proposed direct Domain membership."
  continueAction = Action "domain.continue" "continue" "enter" True "Accept this visible membership set and continue."
  assistanceAction = Action "domain.assistance" "I don't know" "?" False "Explain direct Domain membership without changing the selection."

makeExistingWorkSuspicionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkDraft -> Brick -> InteractionEnvelope
makeExistingWorkSuspicionEnvelope previous now state raw draft existing =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (ExistingWorkSuspicionOpportunity draft (brickId existing))
      ( EnvelopeContent
          "Similar Work already exists:"
          (Just (brickCitation existing))
          ["Proposed Work: \"" <> workDraftTitle draft <> "\"", "Source: " <> rawCitation raw]
          (Just "Would completing the existing Work also handle this intention?")
      )
      [ Action "work-reuse.use" "use existing Work" "u" False "Link this Raw to the existing Brick and create no new importance slot."
      , Action "work-reuse.separate" "create separate Work" "c" False "Keep equal titles valid and continue this draft."
      , Action "work-reuse.differences" "show differences" "s" False "Inspect the bounded structural differences without changing the draft."
      , Action "work-reuse.assistance" "I don't know" "?" False "Restate the completion-equivalence question after inspection."
      , moreAction
      ]
      (rawCommands raw)
      (Just "resolve_existing_work_suspicion")
      (brickFooter now state existing)

makeExistingWorkReuseResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> Brick -> InteractionEnvelope
makeExistingWorkReuseResultEnvelope identity cursor precondition now state raw brick =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (ExistingWorkReuseResultOpportunity (rawId raw) (brickId brick))
    (rawCitation raw <> " now supports")
    [brickCitation brick]
makeImportanceInsertionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> WorkDraft -> Int -> Int -> [UUIDv7] -> UUIDv7 -> InteractionEnvelope
makeImportanceInsertionEnvelope previous now state raw draft low high skipped comparatorId =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ComparisonGrammar
      (ImportanceInsertionOpportunity draft low high skipped comparatorId)
      ( EnvelopeContent
          "Is this proposed Work"
          Nothing
          [ "\"" <> workDraftTitle draft <> "\""
          , ""
          , "      more important than"
          , ""
          , maybe "<missing sibling>" brickCitation (Map.lookup comparatorId (stateBricks state))
          , "?"
          ]
          Nothing
      )
      [ Action "importance.more" "more important" "m" False "Place the proposed Work above the displayed sibling."
      , Action "importance.less" "less important" "l" False "Place the proposed Work below the displayed sibling."
      , Action "importance.skip" "skip" "s" False "Try one nearby sibling before using provisional placement."
      , Action "importance.assistance" "I don't know" "?" False "Clarify this comparison without implying equality."
      , moreAction
      ]
      (rawCommands raw)
      (Just "compare_sibling_importance")
      (rawFooter now state raw)
makeWorkPreviewEnvelope previous now state raw draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (WorkPreviewOpportunity draft)
      ( EnvelopeContent
          "Create this Work?"
          Nothing
          [ "Source: " <> rawCitation raw
          , "Title: \"" <> workDraftTitle draft <> "\""
          , "Nature: " <> natureLabel (workDraftNature draft)
          , "Template: " <> maybe "none" templateIdentifier (workDraftTemplate draft)
          , "Parent: " <> maybe "<root>" (brickReference state) (workDraftParent draft)
          , "Domains: " <> domainsText state (workDraftDomains draft)
          , "Importance: " <> importanceText state draft
          , "Confidence: " <> confidenceText (workDraftImportanceConfidence draft)
          , "Raw material remains preserved."
          ]
          Nothing
      )
      [ Action "work.create" "yes" "y" True "Atomically create every previewed fact."
      , Action "work.edit" "edit" "e" False "Return to the nearest editable draft fact."
      , Action "work.cancel" "no" "n" False "Discard only this Work draft."
      , Action "work.preview-assistance" "I don't know" "?" False "Inspect consequences without accepting."
      , moreAction
      ]
      (rawCommands raw)
      (Just "confirm_work_materialization")
      (rawFooter now state raw)

makeStandaloneResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> InteractionEnvelope
makeStandaloneResultEnvelope identity cursor precondition now state raw =
  resultEnvelope identity cursor precondition now state (StandaloneResultOpportunity (rawId raw)) "Kept as standalone raw material:" [rawCitation raw]

makeWorkCreatedResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> Brick -> InteractionEnvelope
makeWorkCreatedResultEnvelope identity cursor precondition now state raw brick =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (WorkCreatedResultOpportunity (rawId raw) (brickId brick))
    "Created:"
    [brickCitation brick, "From: " <> rawCitation raw, "Importance: " <> createdImportanceText state brick]

makeFocusProposalEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeFocusProposalEnvelope identity cursor precondition now state brick =
  focusProposalEnvelope identity cursor precondition now state brick Nothing

makeRecordedFocusProposalEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> ForecastSelectionEvidence -> InteractionEnvelope
makeRecordedFocusProposalEnvelope identity cursor precondition now state brick evidence =
  focusProposalEnvelope identity cursor precondition now state brick (Just evidence)

makeDomainFocusEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Domain -> InteractionEnvelope
makeDomainFocusEnvelope identity cursor precondition now state domain =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (DomainFocusOpportunity (domainId domain))
    (EnvelopeContent "Focus Domain:" (Just (domainPath state (domainId domain))) [] (Just "How should this affect next?"))
    [ Action "domain-focus.one" "one suggestion" "o" False "Constrain exactly one forecast draw, then expire the scope."
    , Action "domain-focus.stay" "stay within" "s" False "Keep a visible hard scope until it is cleared."
    , Action "domain-focus.prefer" "prefer" "p" False "Change only the soft Domain-continuity reference."
    , Action "domain-focus.unknown" "I don't know" "?" False "Explain hard scope versus soft continuity."
    , moreAction
    ]
    [helpCommand, exitCommand]
    (Just "choose_domain_focus")
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))

makeDomainFocusResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Domain -> DomainFocusMode -> InteractionEnvelope
makeDomainFocusResultEnvelope identity cursor precondition now state domain mode =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (DomainFocusResultOpportunity (domainId domain) mode)
    "Domain focus updated:"
    [domainPath state (domainId domain), domainFocusModeLabel mode]

focusProposalEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Maybe ForecastSelectionEvidence -> InteractionEnvelope
focusProposalEnvelope identity cursor precondition now state brick evidence =
  sealed
    identity
    1
    cursor
    precondition
    FocusGrammar
    (FocusProposalOpportunity (brickId brick) (forecastSelectionId <$> evidence))
    (EnvelopeContent "Work:" (Just (brickCitation brick)) (maybe [] (focusPathBody state brick) evidence <> standingContext state brick) (Just "Focus?"))
    [ Action "focus.accept" "yes" "y" False "Make this Brick current and WIP."
    , Action "focus.skip" "skip" "s" False "Open the typed skip-symptom flow."
    , Action "focus.assistance" "I don't know" "?" False "Clarify this Focus decision."
    , moreAction
    ]
    [CommandOption "done" ("/done " <> brickCitation brick) "Complete this finite Work directly", feedCommand, showBrickCommand brick, helpCommand, exitCommand]
    (Just "understand_focus")
    (brickFooter now state brick)

makeExternalEffectRecoveryEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> ExternalEffect -> InteractionEnvelope
makeExternalEffectRecoveryEnvelope identity cursor precondition now state brick effect =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (ExternalEffectRecoveryScreenOpportunity (externalEffectId effect))
    ( EnvelopeContent
        heading
        (Just (brickCitation brick))
        [ "To: " <> entityReference state (externalEffectTarget effect)
        , "Message:"
        , externalEffectMessage effect
        , explanation
        ]
        (Just "What should happen?")
    )
    (actions <> [Action "effect.recovery.stop" "stop" "s" False "Keep the exact history and stop retrying this effect.", Action "effect.recovery.unknown" "I don't know" "?" False "Explain what is known without guessing provider truth.", moreAction])
    [helpCommand, exitCommand]
    (Just "recover_external_effect")
    (brickFooter now state brick)
 where
  (heading, explanation, actions) = case externalEffectStatus effect of
    EffectFailed ->
      ( "External action failed"
      , "The provider reported a failure. A retry creates a new revision and returns to exact approval."
      , [Action "effect.recovery.retry" "retry" "r" False "Create a new pending revision; do not dispatch it yet."]
      )
    EffectOutcomeUnknown ->
      ( "External action outcome is unknown"
      , "The provider may have applied the action. Little Ant will not guess or repeat it silently."
      ,
        [ Action "effect.recovery.verify" "verify externally" "v" False "Inspect provider truth without dispatching another effect."
        , Action "effect.recovery.retry-risk" "retry with duplicate risk" "r" False "Open a separate duplicate-risk confirmation."
        ]
      )
    _ -> ("External action", "This effect no longer needs recovery.", [])

makeExternalEffectDuplicateRiskEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> ExternalEffect -> InteractionEnvelope
makeExternalEffectDuplicateRiskEnvelope previous now state brick effect =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (ExternalEffectDuplicateRiskOpportunity (externalEffectId effect))
      ( EnvelopeContent
          "Retry despite an unknown outcome?"
          (Just (brickCitation brick))
          [ "The previous request may already have succeeded."
          , "Retrying can duplicate the outside action."
          , "Yes creates a new pending revision; it still requires ordinary approval before dispatch."
          ]
          Nothing
      )
      [ Action "effect.risk.accept" "yes" "y" False "Accept the duplicate risk and create a new pending revision."
      , Action "effect.risk.reject" "no" "n" False "Return without changing the unresolved effect."
      , Action "effect.risk.unknown" "I don't know" "?" False "Explain why provider truth cannot be inferred from local history."
      , moreAction
      ]
      [helpCommand, exitCommand]
      (Just "confirm_duplicate_risk")
      (brickFooter now state brick)

makeChecklistRunEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> InteractionEnvelope
makeChecklistRunEnvelope identity cursor precondition now state owner selected =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (ChecklistRunOpportunity (brickId owner) selected)
    (EnvelopeContent "Checklist:" (Just (brickCitation owner)) (fmap entryLine visibleEntries) (Just question))
    (selectionActions <> mutationActions <> finishActions <> [Action "checklist.skip" "skip" "s" False "Explain why this checklist run is getting in the way.", moreAction])
    [feedCommand, showBrickCommand owner, helpCommand, exitCommand]
    (Just "work_checklist_run")
    (brickFooter now state owner)
 where
  run = Map.lookup (brickId owner) (stateChecklistRuns state)
  ownedEntries =
    sortOn
      listEntryInsertionOrdinal
      [entry | entry <- Map.elems (stateListEntries state), listEntryOwner entry == brickId owner]
  visibleEntries = take 9 ownedEntries
  question = case selected >>= (`Map.lookup` stateListEntries state) of
    Nothing -> "Choose an item."
    Just entry -> "What should happen to " <> listEntryLabel entry <> "?"
  entryLine entry =
    marker entry <> " " <> listEntryLabel entry <> quantitySuffix entry
  marker entry = case listEntryState entry of
    EntryOpen -> "☐"
    EntryResolved -> "☑"
    EntryCancelled -> "⊘"
  quantitySuffix entry =
    if listEntryQuantity entry == Quantity 1 0 "" then "" else " × " <> quantityText (listEntryQuantity entry)
  selectionActions =
    zipWith
      (\index entry -> Action ("checklist.select." <> renderUUIDv7 (listEntryId entry)) (entryLine entry) (Text.pack (show index)) False "Select this owner-scoped ListEntry without changing it.")
      ([1 ..] :: [Int])
      visibleEntries
  mutationActions = case selected >>= (`Map.lookup` stateListEntries state) of
    Just entry | listEntryOwner entry == brickId owner -> case listEntryState entry of
      EntryOpen ->
        [ Action "checklist.entry.done" "done" "d" False "Resolve the selected ListEntry."
        , Action "checklist.entry.cancel" "cancel" "c" False "Cancel the selected ListEntry without resolving it."
        ]
      _ -> [Action "checklist.entry.reopen" "reopen" "r" False "Reopen the selected ListEntry."]
    _ -> []
  finishActions = case run of
    Just activeRun | checklistRunMutationCount activeRun > 0 -> [Action "checklist.finish" "finish this run" "f" False "End this checklist run after at least one mutation."]
    _ -> []

makeChecklistRunResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeChecklistRunResultEnvelope identity cursor precondition now state owner =
  resultEnvelope identity cursor precondition now state (ChecklistRunResultOpportunity (brickId owner)) "Checklist run finished:" [brickCitation owner]

makeWorkSkipSymptomEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> InteractionEnvelope
makeWorkSkipSymptomEnvelope previous now state brick selection =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WorkSkipSymptomOpportunity (brickId brick) selection)
      (EnvelopeContent "" (Just (brickCitation brick)) [] (Just "What's getting in the way?"))
      [ Action "work.symptom.vague" "💭 vague" "v" False "Open vague-work recovery."
      , Action "work.symptom.hard" "🧗 hard" "h" False "Open difficult-work recovery."
      , Action "work.symptom.big" "🏔️ big" "g" False "Open decomposition recovery."
      , Action "work.symptom.blocked" "🚧 blocked or waiting" "b" False "Classify an external prerequisite."
      , Action "work.symptom.tired" "🥱 tired" "t" False "Open low-energy recovery."
      , Action "work.symptom.bored" "😐 bored" "r" False "Open low-interest recovery."
      , Action "work.symptom.fear" "😨 fear" "f" False "Open risk recovery."
      , Action "work.symptom.less-important" "⬇️ less important" "l" False "Open importance, time, or subject recovery."
      , Action "work.symptom.out-of-date" "🕰️ out of date" "u" False "Open stale-work recovery."
      , Action "work.symptom.other" "🧩 other" "o" False "Preserve another obstacle verbatim."
      , Action "work.symptom.unknown" "❓ I don't know" "?" False "Discover the symptom through one question at a time."
      , Action "work.symptom.done" "✅ done" "d" False "Complete this finite Work."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "discover_skip_symptom")
      (brickFooter now state brick)

makeWaitRequestInputEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> ExternalEntity -> Text -> InteractionEnvelope
makeWaitRequestInputEnvelope previous now state brick selection entity draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (WaitRequestInputOpportunity (brickId brick) selection (externalEntityId entity) draft)
      (EnvelopeContent "Enabling request" (Just (brickCitation brick)) ["To: " <> entityReference state (externalEntityId entity), "", draft, "", "Tip: write the Work title in English when possible."] (Just "What request still needs to be made?"))
      [Action "wait.request.input.submit" "continue" "enter" False "Preserve this title as Raw material before the complete handoff preview."]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeWaitRequestDelayEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> ExternalEntity -> Raw -> InteractionEnvelope
makeWaitRequestDelayEnvelope previous now state brick selection entity raw =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WaitRequestDelayOpportunity (brickId brick) selection (externalEntityId entity) (rawId raw))
      (EnvelopeContent "After the request is handed off" (Just (rawCitation raw)) ["Waiting for: " <> entityReference state (externalEntityId entity)] (Just "When may we start checking again?"))
      [ Action "wait.request.delay.tomorrow" "tomorrow" "t" False "Review no earlier than 24 hours after the request handoff."
      , Action "wait.request.delay.three-days" "three days" "d" True "Review no earlier than 72 hours after the request handoff."
      , Action "wait.request.delay.week" "one week" "w" False "Review no earlier than 168 hours after the request handoff."
      , Action "wait.request.delay.unknown" "I don't know" "?" False "This is a review threshold, not a promised response time."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_successor_wait_review_time")
      (brickFooter now state brick)

makeWaitRequestPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> ExternalEntity -> Raw -> Integer -> InteractionEnvelope
makeWaitRequestPreviewEnvelope previous now state brick selection entity raw reviewDelay =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (WaitRequestPreviewOpportunity (brickId brick) selection (externalEntityId entity) (rawId raw) reviewDelay)
      ( EnvelopeContent
          "Request handoff:"
          (Just (rawCitation raw))
          [ "Sibling of: " <> brickCitation brick
          , "Blocks: " <> brickCitation brick
          , "Then waits for: " <> entityReference state (externalEntityId entity)
          , "Review delay after handoff: " <> Text.pack (show (reviewDelay `div` 3600)) <> " hours"
          , "Importance: unresolved local midpoint"
          ]
          (Just "Create this enabling Work and declared successor Wait?")
      )
      [ Action "wait.request.preview.accept" "yes" "y" False "Create the Work, Dependency, and declared successor Wait in one command group."
      , Action "wait.request.preview.reject" "no" "n" False "Keep the Raw in the Inbox without creating Work or a gate."
      , Action "wait.request.preview.unknown" "I don't know" "?" False "Explain why the Wait activates only after this Work completes."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeWaitRequestHandoffResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Brick -> WaitSuccessor -> InteractionEnvelope
makeWaitRequestHandoffResultEnvelope identity cursor precondition now state affected enabling successor =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (WaitRequestHandoffResultOpportunity (brickId affected) (brickId enabling) (waitSuccessorWait successor))
    "Blocked for now:"
    [ brickCitation affected
    , "Blocked by: " <> brickCitation enabling
    , "After completion: wait for " <> waitKindLabel (waitSuccessorKind successor)
    ]
 where
  waitKindLabel = \case
    HumanResponseWait entityId -> entityReference state entityId
    ExternalConditionWait condition -> condition

makeDependencySelectEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> InteractionEnvelope
makeDependencySelectEnvelope previous now state blocked selection =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (DependencySelectOpportunity (brickId blocked) selection)
      (EnvelopeContent "Choose the prerequisite Work" (Just (brickCitation blocked)) [] (Just "What must be completed first?"))
      (candidateActions <> [Action "dependency.feed" "Feed new prerequisite Work..." "f" False "Preserve new Raw, then create prerequisite Work through the ordinary flow.", Action "dependency.unknown" "I don't know" "?" False "A prerequisite is Work you can complete; a Wait is an outside response or condition.", moreAction])
      [showBrickCommand blocked, helpCommand, exitCommand]
      (Just "choose_prerequisite")
      (brickFooter now state blocked)
 where
  candidates = take 8 [brick | brick <- activeBricks state, brickId brick /= brickId blocked]
  candidateActions =
    zipWith
      (\index brick -> Action ("dependency.select." <> renderUUIDv7 (brickId brick)) (brickCitation brick) (Text.pack (show index)) False "Preview this exact Dependency edge.")
      [(1 :: Int) ..]
      candidates

makeDependencyPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Brick -> InteractionEnvelope
makeDependencyPreviewEnvelope previous now state blocked selection blocker =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (DependencyPreviewOpportunity (brickId blocked) selection (brickId blocker))
      (EnvelopeContent "Add this prerequisite?" Nothing [brickCitation blocked, "is blocked by", brickCitation blocker, "", "If the blocked Work is drawn, next may follow this chain to an executable blocker."] Nothing)
      [ Action "dependency.accept" "yes" "y" False "Create one directed Dependency edge."
      , Action "dependency.reject" "no" "n" False "Return without recording an edge."
      , Action "dependency.unknown" "I don't know" "?" False "Explain the direction and cycle checks."
      , moreAction
      ]
      [showBrickCommand blocked, showBrickCommand blocker, helpCommand, exitCommand]
      (Just "confirm_prerequisite")
      (brickFooter now state blocked)

makeDependencyResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Brick -> InteractionEnvelope
makeDependencyResultEnvelope identity cursor precondition now state blocked blocker =
  resultEnvelope identity cursor precondition now state (DependencyResultOpportunity (brickId blocked) (brickId blocker)) "Prerequisite recorded:" [brickCitation blocked, "is blocked by", brickCitation blocker]

makeDelegationMessageEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> DelegationDraft -> InteractionEnvelope
makeDelegationMessageEnvelope previous now state brick draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (DelegationMessageOpportunity draft)
      (EnvelopeContent "Edit delegation message" (Just (brickCitation brick)) ["To: " <> entityReference state (delegationDraftTarget draft), "", delegationDraftMessage draft] (Just "Message"))
      [Action "delegation.message.submit" "review" "enter" False "Return to the complete Delegation preview with this exact message."]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeWorkBreakNatureEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Maybe SkipSymptom -> InteractionEnvelope
makeWorkBreakNatureEnvelope previous now state brick selection symptom =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WorkBreakNatureOpportunity (brickId brick) selection symptom)
      (EnvelopeContent "Break into parts:" (Just (brickCitation brick)) [] (Just "What should the whole become?"))
      [ Action "work.break.nature.project" "finite project — the parts complete one outcome" "p" False "Reclassify the same Brick as a Project."
      , Action "work.break.nature.collection" "open collection — it may keep accepting parts" "c" False "Reclassify the same Brick as a Collection."
      , Action "work.break.nature.unknown" "I don't know" "?" False "Explain the lifecycle distinction without changing anything."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_break_structure")
      (brickFooter now state brick)

makeWorkBreakDraftEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Maybe SkipSymptom -> Maybe BrickNature -> [Text] -> InteractionEnvelope
makeWorkBreakDraftEnvelope previous now state brick selection symptom target titles =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (WorkBreakDraftOpportunity (brickId brick) selection symptom target titles)
      ( EnvelopeContent
          (if null titles then "Break into parts:" else "Parts so far:")
          (Just (brickCitation brick))
          (zipWith (\index title -> Text.pack (show index) <> ". " <> title) [(1 :: Int) ..] titles <> ["Tip: write Brick titles in English when possible."])
          (Just question)
      )
      [Action "work.break.submit" "add or review" "enter" False "Add the typed part; empty input reviews a complete draft.", moreAction]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)
 where
  minimumParts = if target == Nothing then 1 else 2
  question
    | length titles < minimumParts = "Enter part " <> Text.pack (show (length titles + 1)) <> "."
    | otherwise = "Enter another part, or press Enter to review."

makeWorkBreakPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Maybe SkipSymptom -> Maybe BrickNature -> [Text] -> InteractionEnvelope
makeWorkBreakPreviewEnvelope previous now state brick selection symptom target titles =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (WorkBreakPreviewOpportunity (brickId brick) selection symptom target titles)
      ( EnvelopeContent
          "Create these parts?"
          (Just (brickCitation brick))
          ( maybe [] (\nature -> ["The same parent becomes: " <> natureLabel nature]) target
              <> zipWith (\index title -> Text.pack (show index) <> ". " <> title) [(1 :: Int) ..] titles
              <> [ "Each part starts as an atomic task with a lazy Nature review."
                 , "Entered order seeds their local importance; it is not a dependency claim."
                 ]
          )
          Nothing
      )
      [ Action "work.break.accept" "yes" "y" True "Create all parts and any required parent reclassification atomically."
      , Action "work.break.edit" "edit" "e" False "Return to the part draft."
      , Action "work.break.cancel" "no" "n" False "Discard the draft without recording a symptom."
      , Action "work.break.unknown" "I don't know" "?" False "Explain identity, ordering, and lazy review."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "confirm_break")
      (brickFooter now state brick)

makeWorkBreakResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> [Brick] -> InteractionEnvelope
makeWorkBreakResultEnvelope identity cursor precondition now state parent children =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (WorkBreakResultOpportunity (brickId parent) (fmap brickId children))
    "Parts created:"
    (brickCitation parent : fmap ("  ↳ " <>) (fmap brickCitation children))

makeWorkInterestingEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> InteractionEnvelope
makeWorkInterestingEnvelope previous now state brick selection =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WorkInterestingOpportunity (brickId brick) selection)
      (EnvelopeContent "" (Just (brickCitation brick)) [] (Just "How could we make this more interesting?"))
      [ Action "work.interesting.sprint" "⏱️ try a short sprint" "t" False "Choose a bounded focus interval."
      , Action "work.interesting.break" "🧩 break it into visible steps" "b" False "Open the decomposition preview."
      , Action "work.interesting.method" "🔧 find a better way" "f" False "Classify a deterministic method improvement."
      , Action "work.interesting.unknown" "I don't know" "?" False "Explain method change without selecting one."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "make_work_interesting")
      (brickFooter now state brick)

makeWorkSkipReactionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> SkipSymptom -> InteractionEnvelope
makeWorkSkipReactionEnvelope previous now state brick selection symptom =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WorkSkipReactionOpportunity (brickId brick) selection symptom)
      (EnvelopeContent (reactionHeading symptom) (Just (brickCitation brick)) [] (Just (reactionQuestion symptom)))
      (reactionActions symptom <> [moreAction])
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just ("understand_" <> skipSymptomName symptom))
      (brickFooter now state brick)

makeWorkSkipDiscoveryEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> SkipDiscoveryNode -> Bool -> InteractionEnvelope
makeWorkSkipDiscoveryEnvelope previous now state brick selection node alternate =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (WorkSkipDiscoveryOpportunity (brickId brick) selection node alternate)
      (EnvelopeContent "" (Just (brickCitation brick)) (if alternate then [skipDiscoveryExplanation node] else []) (Just (skipDiscoveryQuestion node alternate)))
      [ Action "work.discovery.yes" "yes" "y" False "Follow the yes branch."
      , Action "work.discovery.no" "no" "n" False "Follow the no branch."
      , Action "work.discovery.unknown" "I don't know" "?" False "Show the alternate probe without choosing a branch."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "discover_skip_symptom")
      (brickFooter now state brick)

makeWorkSkipConfirmationEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> SkipSymptom -> InteractionEnvelope
makeWorkSkipConfirmationEnvelope previous now state brick selection symptom =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (WorkSkipConfirmationOpportunity (brickId brick) selection symptom)
      ( EnvelopeContent
          "It sounds like the main obstacle is:"
          (Just (brickCitation brick))
          [skipSymptomDisplay symptom, skipSymptomReason symptom]
          (Just "Is this what's getting in the way?")
      )
      [ Action "work.discovery.confirm" "yes" "y" True "Open this symptom's recovery without recording it yet."
      , Action "work.discovery.reject" "no" "n" False "Return to the symptom list."
      , Action "work.discovery.restart" "I don't know" "?" False "Restart the mechanical discovery tree."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "confirm_skip_symptom")
      (brickFooter now state brick)

makeWorkOtherExplanationEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Text -> InteractionEnvelope
makeWorkOtherExplanationEnvelope previous now state brick selection draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (WorkOtherExplanationOpportunity (brickId brick) selection draft)
      (EnvelopeContent "" (Just (brickCitation brick)) ["Tip: write in English when possible."] (Just "What else is getting in the way?"))
      [ Action "work.other.submit" "review" "enter" False "Review the exact explanation before recording it."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeWorkOtherPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Text -> InteractionEnvelope
makeWorkOtherPreviewEnvelope previous now state brick selection explanation =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (WorkOtherPreviewOpportunity (brickId brick) selection explanation)
      (EnvelopeContent "" (Just (brickCitation brick)) ["Skip this Brick for now because:", "\"" <> explanation <> "\""] Nothing)
      [ Action "work.other.accept" "yes" "y" False "Record the verbatim obstacle with ordinary cooldown."
      , Action "work.other.edit" "edit" "e" False "Edit the selected explanation."
      , Action "work.other.reject" "no" "n" False "Return without recording evidence."
      , Action "work.other.unknown" "I don't know" "?" False "Explain how the verbatim evidence will be used."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "confirm_other_skip")
      (brickFooter now state brick)

makeWorkSprintDurationEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> InteractionEnvelope
makeWorkSprintDurationEnvelope previous now state brick selection =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WorkSprintDurationOpportunity (brickId brick) selection)
      (EnvelopeContent "" (Just (brickCitation brick)) [] (Just "How long would you like to give it?"))
      [ Action "work.sprint.5" "5 minutes — just get started" "1" False "Start a five-minute sprint."
      , Action "work.sprint.15" "15 minutes — a short attempt" "2" False "Start a fifteen-minute sprint."
      , Action "work.sprint.25" "25 minutes — a Pomodoro" "3" True "Start the factory-default Pomodoro."
      , Action "work.sprint.custom" "custom..." "c" False "Enter a duration from 1 to 120 minutes."
      , Action "work.sprint.unknown" "I don't know" "?" False "Explain that this is a bounded attempt, not an estimate."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_sprint_duration")
      (brickFooter now state brick)

makeSkipAcknowledgedEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> SkipSymptom -> SkipReaction -> InteractionEnvelope
makeSkipAcknowledgedEnvelope identity cursor precondition now state brick symptom reaction =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (WorkSkipAcknowledgedOpportunity (brickId brick) symptom reaction)
    "Skip acknowledged:"
    [brickCitation brick, skipSymptomDisplay symptom <> " · " <> skipReactionName reaction]

focusPathBody :: State -> Brick -> ForecastSelectionEvidence -> [Text]
focusPathBody state endpoint evidence =
  case path of
    original : _ : _ ->
      ["🚧 reached through " <> maybeCitation original]
        <> fmap middle (drop 1 (init path))
        <> ["   → blocked by this Brick"]
    _ -> []
 where
  path = forecastSelectionDependencyPath evidence
  maybeCitation identity =
    maybe ("#<missing> " <> renderUUIDv7 identity) brickCitation (Map.lookup identity (stateBricks state))
  middle identity
    | identity == brickId endpoint = "   → blocked by this Brick"
    | otherwise = "   → blocked by " <> maybeCitation identity

standingContext :: State -> Brick -> [Text]
standingContext state brick = occurrenceContext <> habitContext
 where
  occurrenceContext = case findOccurrence of
    Nothing -> []
    Just occurrence ->
      [ "Occurrence: " <> recurringOccurrenceLabel occurrence
      , "Series: " <> maybe ("#<missing> " <> renderUUIDv7 (recurringOccurrenceOwner occurrence)) brickCitation (Map.lookup (recurringOccurrenceOwner occurrence) (stateBricks state))
      ]
  findOccurrence =
    case [occurrence | occurrence <- Map.elems (stateRecurringOccurrences state), recurringOccurrenceBrick occurrence == brickId brick] of
      occurrence : _ -> Just occurrence
      [] -> Nothing
  habitContext
    | brickNature brick /= Habit = []
    | otherwise =
        ["History: " <> Text.concat (habitMark <$> take 8 recentWindows)]
          <> maybe [] (pure . ("Last completed: " <>) . Text.pack . show . habitOutcomeAt) lastCompleted
  recentWindows = reverse . sortOn habitWindowOpensAt $ [window | window <- Map.elems (stateHabitWindows state), habitWindowOwner window == brickId brick]
  outcomesFor window =
    sortOn habitOutcomeAt [outcome | outcome <- Map.elems (stateHabitOutcomes state), habitOutcomeWindow outcome == habitWindowId window]
  habitMark window = case reverse (outcomesFor window) of
    outcome : _ -> case habitOutcomeKind outcome of
      StandingDone -> "[x]"
      StandingUnfulfilled -> "[-]"
      StandingBlocked -> "[!]"
      StandingPaused -> "[~]"
      StandingInapplicable -> "[·]"
      _ -> "[?]"
    [] -> "[ ]"
  lastCompleted =
    case reverse . sortOn habitOutcomeAt $ [outcome | outcome <- Map.elems (stateHabitOutcomes state), habitOutcomeOwner outcome == brickId brick, habitOutcomeKind outcome == StandingDone] of
      outcome : _ -> Just outcome
      [] -> Nothing

makeCurrentFocusEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeCurrentFocusEnvelope identity cursor precondition now state brick =
  sealed
    identity
    1
    cursor
    precondition
    FocusGrammar
    (CurrentFocusOpportunity (brickId brick))
    (EnvelopeContent "Current focus:" (Just (brickCitation brick)) (standingContext state brick) Nothing)
    [ Action "focus.done" "done" "d" False "Complete this finite Work and clear focus."
    , Action "focus.skip" "skip" "s" False "Explain what is getting in the way."
    , moreAction
    ]
    [CommandOption "pause" "/pause" "Clear current focus while retaining WIP", feedCommand, showBrickCommand brick, helpCommand, exitCommand]
    Nothing
    (brickFooter now state brick)

makeCompletionResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeCompletionResultEnvelope identity cursor precondition now state brick =
  resultEnvelope identity cursor precondition now state (CompletionResultOpportunity (brickId brick)) "Completed:" [brickCitation brick]

makeRepeatableReturnEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> LazyReviewClaim -> InteractionEnvelope
makeRepeatableReturnEnvelope identity cursor precondition now state brick review =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (RepeatableReturnOpportunity (brickId brick) (lazyReviewId review))
    (EnvelopeContent "Run completed:" (Just (brickCitation brick)) [Text.pack (show completionCount) <> " completed runs"] (Just "What should happen next?"))
    (policyActions <> [manualAction, archiveAction, unknownAction, moreAction])
    [showBrickCommand brick, helpCommand, exitCommand]
    Nothing
    (brickFooter now state brick)
 where
  existing = Map.lookup (brickId brick) (stateReturnSchedules state)
  completionCount =
    length
      [ ()
      | outcome <- Map.elems (stateStandingOutcomes state)
      , standingOutcomeOwner outcome == brickId brick
      , standingOutcomeKind outcome == StandingDone
      ]
  policyActions = case existing of
    Just schedule ->
      [ Action "return.keep" "keep this return" "k" True (returnPolicySummary (returnSchedulePolicy schedule))
      , Action "return.change" "change return..." "c" False "Edit structured center, unit, variation, and IANA zone fields."
      ]
    Nothing -> [Action "return.set" "set a return..." "r" False "Choose structured center, unit, variation, and IANA zone fields."]
  manualAction = Action "return.manual" "manual only" "m" False "Keep this standing Brick available only through explicit /focus."
  archiveAction = Action "return.archive" "archive" "a" False "Open the ordinary archive preview for this standing Brick."
  unknownAction = Action "return.unknown" "I don't know" "?" False "Explain return, manual-only, and archive without choosing."

makeRepeatableReturnCenterEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> LazyReviewClaim -> Text -> InteractionEnvelope
makeRepeatableReturnCenterEnvelope previous now state brick review draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (RepeatableReturnCenterOpportunity (brickId brick) (lazyReviewId review) draft)
      (EnvelopeContent "Set a return:" (Just (brickCitation brick)) ["Center › " <> draft] (Just "Enter a positive whole number."))
      [Action "return.center.submit" "continue" "enter" False "Continue to the finite unit selector.", moreAction]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeRepeatableReturnUnitEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> LazyReviewClaim -> Int -> InteractionEnvelope
makeRepeatableReturnUnitEnvelope previous now state brick review center =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (RepeatableReturnUnitOpportunity (brickId brick) (lazyReviewId review) center)
      (EnvelopeContent "Set a return:" (Just (brickCitation brick)) ["Center › " <> Text.pack (show center)] (Just "Choose the calendar unit."))
      [ Action "return.unit.days" "days" "d" False "Use calendar days."
      , Action "return.unit.weeks" "weeks" "w" False "Use seven-day calendar intervals."
      , Action "return.unit.months" "months" "m" False "Use calendar months with month-end clamping."
      , Action "return.unit.years" "years" "y" False "Use calendar years with date clamping."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeRepeatableReturnVariationEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> LazyReviewClaim -> Int -> ReturnUnit -> Text -> InteractionEnvelope
makeRepeatableReturnVariationEnvelope previous now state brick review center unit draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (RepeatableReturnVariationOpportunity (brickId brick) (lazyReviewId review) center unit draft)
      (EnvelopeContent "Set a return:" (Just (brickCitation brick)) ["Center › " <> Text.pack (show center), "Unit › " <> returnUnitName unit, "Variation › " <> draft] (Just "Enter zero for an exact return, or a whole number no larger than the center."))
      [Action "return.variation.submit" "continue" "enter" False "Continue to the IANA zone field.", moreAction]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeRepeatableReturnZoneEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> LazyReviewClaim -> Int -> ReturnUnit -> Int -> Text -> InteractionEnvelope
makeRepeatableReturnZoneEnvelope previous now state brick review center unit variation draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (RepeatableReturnZoneOpportunity (brickId brick) (lazyReviewId review) center unit variation draft)
      (EnvelopeContent "Set a return:" (Just (brickCitation brick)) ["Center › " <> Text.pack (show center), "Unit › " <> returnUnitName unit, "Variation › " <> Text.pack (show variation), "Zone › " <> draft] (Just "Enter one named IANA time zone."))
      [Action "return.zone.submit" "review" "enter" False "Validate the zone and build a deterministic preview.", moreAction]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeRepeatableReturnPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> LazyReviewClaim -> ReturnPolicy -> Int -> ZonedInstant -> Text -> ByteString -> InteractionEnvelope
makeRepeatableReturnPreviewEnvelope previous now state brick review policy chosen notBefore resolution seed =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (RepeatableReturnPreviewOpportunity (brickId brick) (lazyReviewId review) policy chosen notBefore resolution seed)
      ( EnvelopeContent
          "Return preview:"
          (Just (brickCitation brick))
          [ returnPolicySummary policy
          , "Chosen offset › " <> Text.pack (show chosen) <> " " <> returnUnitName (policyUnit policy)
          , "Not before › " <> Text.pack (show (zonedInstantUtc notBefore))
          , "Zone › " <> zonedInstantZone notBefore
          , "Importance remains unchanged."
          ]
          Nothing
      )
      [ Action "return.accept" "yes" "y" False "Record this policy, chosen offset, and absolute return instant."
      , Action "return.edit" "edit" "e" False "Return to the structured editor."
      , Action "return.reject" "no" "n" False "Return to the completion checkpoint without changing the policy."
      , Action "return.unknown" "I don't know" "?" False "Explain the chosen deterministic date and DST resolution."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)
 where
  policyUnit (AfterCompletionReturn _ unit _ _) = unit
  policyUnit ManualOnlyReturn = ReturnDays

makeRepeatableReturnResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeRepeatableReturnResultEnvelope identity cursor precondition now state brick =
  resultEnvelope identity cursor precondition now state (RepeatableReturnResultOpportunity (brickId brick)) "Return recorded:" [brickCitation brick, maybe "Manual only." (returnPolicySummary . returnSchedulePolicy) (Map.lookup (brickId brick) (stateReturnSchedules state))]

makeScheduledCommitmentEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> ScheduledInterval -> InteractionEnvelope
makeScheduledCommitmentEnvelope identity cursor precondition now state brick interval =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (ScheduledCommitmentOpportunity (brickId brick))
    (EnvelopeContent "Commitment:" (Just (brickCitation brick)) (focusContext <> intervalLines) (Just question))
    actions
    [showBrickCommand brick, helpCommand, exitCommand]
    Nothing
    (brickFooter now state brick)
 where
  current = stateCurrentFocus state == Just (brickId brick)
  ended = zonedTimeToUTC now >= zonedInstantUtc (scheduledEndsAt interval)
  focusContext = case stateCurrentFocus state >>= (`Map.lookup` stateBricks state) of
    Just focused | brickId focused /= brickId brick -> ["Current focus remains WIP: " <> brickCitation focused]
    _ -> []
  intervalLines =
    [ "Starts › " <> Text.pack (show (zonedInstantUtc (scheduledStartsAt interval))) <> " · " <> zonedInstantZone (scheduledStartsAt interval)
    , "Ends › " <> Text.pack (show (zonedInstantUtc (scheduledEndsAt interval))) <> " · " <> zonedInstantZone (scheduledEndsAt interval)
    ]
  question
    | current = "What happened?"
    | ended = "What happened?"
    | otherwise = "Attend now?"
  actions
    | current || ended =
        [ Action "commitment.attended" "attended" "a" False "Record the truthful attended outcome."
        , Action "commitment.missed" "missed" "m" False "Record the truthful missed outcome."
        , Action "commitment.cancelled" "cancelled" "c" False "Record the truthful cancelled outcome."
        , Action "commitment.unknown" "I don't know" "?" False "Explain that time alone never infers an outcome."
        , moreAction
        ]
    | otherwise =
        [ Action "commitment.attend" "attend now" "a" False "Leave any previous current Work WIP and focus this commitment."
        , Action "commitment.cancelled" "cancelled" "c" False "Record an explicit cancellation."
        , Action "commitment.missed" "missed" "m" False "Record missed only when that is already known."
        , Action "commitment.unknown" "I don't know" "?" False "Inspect the interval without changing focus or outcome."
        , moreAction
        ]

makeScheduledOverlapEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> [(Brick, ScheduledInterval)] -> InteractionEnvelope
makeScheduledOverlapEnvelope identity cursor precondition now state commitments =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (ScheduledOverlapOpportunity (fmap (brickId . fst) visible))
    (EnvelopeContent "Overlapping commitments:" Nothing (zipWith row [1 :: Int ..] visible) (Just "Which commitment should we handle?"))
    (zipWith action [1 :: Int ..] visible <> [Action "commitment.overlap.unknown" "I don't know" "?" False "Explain why no commitment is selected automatically.", moreAction])
    [helpCommand, exitCommand]
    Nothing
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  visible = take 9 commitments
  row index (brick, interval) = Text.pack (show index) <> ". " <> brickCitation brick <> " · starts " <> Text.pack (show (zonedInstantUtc (scheduledStartsAt interval)))
  action index (brick, _) = Action ("commitment.overlap.select." <> renderUUIDv7 (brickId brick)) (brickTitle brick) (Text.pack (show index)) False "Open this active commitment."

makeScheduledOutcomeResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> StandingOutcomeKind -> InteractionEnvelope
makeScheduledOutcomeResultEnvelope identity cursor precondition now state brick outcome =
  resultEnvelope identity cursor precondition now state (ScheduledOutcomeResultOpportunity (brickId brick) outcome) "Commitment recorded:" [brickCitation brick, scheduledOutcomeName outcome]

makeNoticeListEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> [NoticeCandidate] -> InteractionEnvelope
makeNoticeListEnvelope identity cursor precondition now state candidates =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (NoticeListOpportunity (candidateNoticeIdentity <$> candidates))
    (EnvelopeContent "Notices:" Nothing body question)
    (selectionActions <> [Action "next" "next" "n" False "Return to one ordinary focus opportunity.", moreAction])
    [helpCommand, exitCommand]
    Nothing
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
 where
  body = ["No temporal notices are available." | null candidates]
  question = if null candidates then Nothing else Just "Open which notice?"
  selectionActions =
    [ Action
        ("notice.select." <> Text.pack (show index))
        (brickCitation (candidateNoticeBrick candidate) <> " · " <> noticeKindLabel (noticeKind (candidateNoticeIdentity candidate)) <> " · " <> noticeStateLabel (candidateNoticeState candidate))
        (Text.pack (show (index + 1)))
        False
        "Open this exact notice identity."
    | (index, candidate) <- zip [0 :: Int .. 8] (take 9 candidates)
    ]

makeTemporalNoticeEnvelope :: InteractionEnvelope -> ZonedTime -> State -> NoticeCandidate -> InteractionEnvelope
makeTemporalNoticeEnvelope previous now state candidate =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (TemporalNoticeOpportunity identity)
      ( EnvelopeContent
          "Notice:"
          (Just (brickCitation brick))
          [ noticeKindLabel (noticeKind identity) <> ": " <> formatFact
          , zonedInstantZone (candidateNoticeFactAt candidate)
          , "State: " <> noticeStateLabel (candidateNoticeState candidate)
          ]
          Nothing
      )
      [ Action "notice.open-work" "open Work" "o" False "Open the existing Work proposal without focusing it."
      , Action "notice.acknowledge" "acknowledge this notice" "a" False "Hide only this exact notice identity permanently."
      , Action "notice.snooze" "snooze this notice" "s" False "Choose when this notice may return."
      , Action "notice.unknown" "I don't know" "?" False "Explain notice state without changing the underlying dates."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "understand_notice_actions")
      (brickFooter now state brick)
 where
  identity = candidateNoticeIdentity candidate
  brick = candidateNoticeBrick candidate
  formatFact = formatLocalDateTime (utcToZonedTime (zonedTimeZone now) (zonedInstantUtc (candidateNoticeFactAt candidate)))

makeNoticeSnoozeEnvelope :: InteractionEnvelope -> ZonedTime -> State -> NoticeCandidate -> InteractionEnvelope
makeNoticeSnoozeEnvelope previous now state candidate =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (NoticeSnoozeOpportunity (candidateNoticeIdentity candidate))
      (EnvelopeContent "Snooze notice:" (Just (brickCitation (candidateNoticeBrick candidate))) [] (Just "When may this notice return?"))
      [ Action "notice.snooze.hour" "in one hour" "h" False "Snooze to an exact instant one hour from now."
      , Action "notice.snooze.tomorrow" "tomorrow" "t" False "Snooze to the same local clock time tomorrow."
      , Action "notice.snooze.week" "in one week" "w" False "Snooze to the same local clock time in seven days."
      , Action "notice.snooze.unknown" "I don't know" "?" False "Explain snooze without changing any Work date."
      , moreAction
      ]
      [helpCommand, exitCommand]
      (Just "choose_notice_not_before")
      (brickFooter now state (candidateNoticeBrick candidate))

makeNoticeResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> NoticeCandidate -> Text -> InteractionEnvelope
makeNoticeResultEnvelope identity cursor precondition now state candidate result =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (NoticeResultOpportunity (candidateNoticeIdentity candidate) result)
    "Notice updated:"
    [brickCitation (candidateNoticeBrick candidate), result, "Underlying Work dates and importance remain unchanged."]

makeEntitySelectEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> EntitySelectionPurpose -> InteractionEnvelope
makeEntitySelectEnvelope previous now state brick selection purpose =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (EntitySelectOpportunity (brickId brick) selection purpose)
      (EnvelopeContent heading (Just (brickCitation brick)) [] (Just question))
      (entityActions <> [Action "entity.new" "New person or company..." "n" False "Create one typed local identity, then return here.", moreAction])
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_person_or_company")
      (brickFooter now state brick)
 where
  heading = case purpose of WaitTargetPurpose -> "Waiting for a response"; DelegationTargetPurpose -> "Responsibility"
  question = case purpose of WaitTargetPurpose -> "Who needs to respond?"; DelegationTargetPurpose -> "Who should do this work?"
  entities = take 8 . sortOn (Text.toCaseFold . externalEntityName) $ filter externalEntityActive (Map.elems (stateExternalEntities state))
  entityActions =
    zipWith
      (\index entity -> Action ("entity.select." <> renderUUIDv7 (externalEntityId entity)) (entityReference state (externalEntityId entity)) (Text.pack (show index)) False "Use this exact person or company.")
      [(1 :: Int) ..]
      entities

makeEntityKindEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> EntitySelectionPurpose -> InteractionEnvelope
makeEntityKindEnvelope previous now state brick selection purpose =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (EntityKindOpportunity (brickId brick) selection purpose)
      (EnvelopeContent "New person or company" (Just (brickCitation brick)) [] (Just "What kind of identity is this?"))
      [ Action "entity.kind.person" "person" "p" False "Create a person identity."
      , Action "entity.kind.team" "team" "t" False "Create a team identity."
      , Action "entity.kind.organization" "company or organization" "o" False "Create an organization identity."
      , Action "entity.kind.service" "service" "s" False "Create a service identity."
      , Action "entity.kind.agent" "AI agent" "a" False "Create an AI-agent identity."
      , Action "entity.kind.unknown" "I don't know" "?" False "A person or company is usually enough; the kind does not grant capabilities."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "classify_person_or_company")
      (brickFooter now state brick)

makeEntityNameEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> EntitySelectionPurpose -> ExternalEntityKind -> Text -> InteractionEnvelope
makeEntityNameEnvelope previous now state brick selection purpose kind draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (EntityNameOpportunity (brickId brick) selection purpose kind draft)
      (EnvelopeContent "New person or company" (Just (brickCitation brick)) [draft] (Just "Name"))
      [Action "entity.name.submit" "create and continue" "enter" False "Create the identity and continue the uncommitted responsibility flow."]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeWaitRequestStatusEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> ExternalEntity -> InteractionEnvelope
makeWaitRequestStatusEnvelope previous now state brick selection entity =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (WaitRequestStatusOpportunity (brickId brick) selection (externalEntityId entity))
      (EnvelopeContent (brickCitation brick) Nothing ["Needs a response from:", entityReference state (externalEntityId entity)] (Just "Has the request already been made?"))
      [ Action "wait.request.yes" "yes" "y" False "Choose the first Wait review threshold."
      , Action "wait.request.no" "no" "n" False "Create explicit enabling Work before the response Wait."
      , Action "wait.request.unknown" "I don't know" "?" False "Distinguish your pending request from the other person's pending response."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "distinguish_request_from_response")
      (brickFooter now state brick)

makeWaitConditionInputEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Text -> InteractionEnvelope
makeWaitConditionInputEnvelope previous now state brick selection draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (WaitConditionInputOpportunity (brickId brick) selection draft)
      (EnvelopeContent "Wait for an event or condition" (Just (brickCitation brick)) [draft, "", "Tip: write the condition in English when possible."] (Just "What must happen before this Work can continue?"))
      [Action "wait.condition.submit" "continue" "enter" False "Use the exact condition in the Wait preview."]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeWaitActivationDelayEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> WaitKind -> InteractionEnvelope
makeWaitActivationDelayEnvelope previous now state brick selection kind =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WaitActivationDelayOpportunity (brickId brick) selection kind)
      (EnvelopeContent (brickCitation brick) Nothing ["Waiting for:", waitKindCitation] (Just "When may we start checking again?"))
      [ Action "wait.activate.tomorrow" "tomorrow" "t" False "Review no earlier than 24 hours from now."
      , Action "wait.activate.three-days" "three days" "d" True "Review no earlier than 72 hours from now."
      , Action "wait.activate.week" "one week" "w" False "Review no earlier than 168 hours from now."
      , Action "wait.activate.choose" "choose..." "c" False "Open structured date and time selection."
      , Action "wait.activate.unknown" "I don't know" "?" False "This is a review threshold, not a deadline or promise."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_wait_review_time")
      (brickFooter now state brick)
 where
  waitKindCitation = case kind of HumanResponseWait entityId -> entityReference state entityId; ExternalConditionWait condition -> condition

makeWaitActivationResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> WaitGate -> InteractionEnvelope
makeWaitActivationResultEnvelope identity cursor precondition now state brick gate =
  resultEnvelope identity cursor precondition now state (WaitActivationResultOpportunity (waitId gate)) "Wait activated:" [brickCitation brick, "Waiting for: " <> waitTargetCitation state gate, "Review no earlier than " <> Text.pack (show (zonedInstantUtc (waitReviewNotBefore gate))) <> "."]

makeDelegationScopeEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> DelegationDraft -> InteractionEnvelope
makeDelegationScopeEnvelope previous now state brick draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (DelegationScopeOpportunity draft)
      (EnvelopeContent "Responsibility" (Just (brickCitation brick)) ["To: " <> entityReference state (delegationDraftTarget draft)] (Just ("Delegate what to " <> entityReference state (delegationDraftTarget draft) <> "?")))
      [ Action "delegation.scope.brick" "brick only — related parts remain yours" "b" False "Delegate only this durable Brick."
      , Action "delegation.scope.whole" "whole scope — current and future parts are included" "w" False "Delegate this Brick and its complete scope."
      , Action "delegation.scope.unknown" "I don't know" "?" False "Explain the two mechanically distinct coverage choices."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_delegation_scope")
      (brickFooter now state brick)

makeDelegationPolicyEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> DelegationDraft -> InteractionEnvelope
makeDelegationPolicyEnvelope previous now state brick draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (DelegationPolicyOpportunity draft)
      (EnvelopeContent "Responsibility" (Just (brickCitation brick)) ["To: " <> entityReference state (delegationDraftTarget draft)] (Just "How should Little Ant follow up?"))
      [ Action "delegation.policy.once" "once — suggest at most one follow-up message" "o" False "Permit one approval-bearing follow-up after the initial handoff."
      , Action "delegation.policy.every" "every review — keep suggesting while unresolved" "e" False "Permit bounded follow-ups, each with separate approval."
      , Action "delegation.policy.none" "no automatic follow-up — keep internal reviews only" "n" False "Never propose an outbound follow-up automatically."
      , Action "delegation.policy.unknown" "I don't know" "?" False "All choices retain internal status reviews and send nothing automatically."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_delegation_follow_up")
      (brickFooter now state brick)

makeDelegationDelayEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> DelegationDraft -> InteractionEnvelope
makeDelegationDelayEnvelope previous now state brick draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (DelegationDelayOpportunity draft)
      (EnvelopeContent "Responsibility" (Just (brickCitation brick)) [] (Just "How long after a handoff should we check again?"))
      [ Action "delegation.delay.day" "one day" "o" False "Review 24 hours after the observed handoff."
      , Action "delegation.delay.three-days" "three days" "t" True "Review 72 hours after the observed handoff."
      , Action "delegation.delay.week" "one week" "w" False "Review 168 hours after the observed handoff."
      , Action "delegation.delay.custom" "custom..." "c" False "Enter a positive number of hours, days, or weeks."
      , Action "delegation.delay.unknown" "I don't know" "?" False "The delay begins only after an observed handoff."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "choose_delegation_review_delay")
      (brickFooter now state brick)

makeDelegationPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> DelegationDraft -> InteractionEnvelope
makeDelegationPreviewEnvelope previous now state brick draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (DelegationPreviewOpportunity draft)
      ( EnvelopeContent
          "Delegate this work?"
          Nothing
          [ "Work: " <> brickCitation brick
          , "To: " <> entityReference state (delegationDraftTarget draft)
          , "Scope: " <> maybe "<missing>" delegationScopeLabel (delegationDraftScope draft)
          , "Follow-up: " <> maybe "<missing>" followUpPolicyLabel (delegationDraftPolicy draft)
          , "Review after: " <> maybe "<missing>" (\seconds -> Text.pack (show (seconds `div` 3600)) <> " hours from each handoff or status update") (delegationDraftReviewDelaySeconds draft)
          , "Handoff: manually"
          , ""
          , "Suggested message:"
          , delegationDraftMessage draft
          ]
          Nothing
      )
      [ Action "delegation.preview.accept" "yes" "y" False "Create only a proposed Delegation; human execution remains eligible."
      , Action "delegation.preview.edit" "edit" "e" False "Edit the initial message before creating anything."
      , Action "delegation.preview.reject" "no" "n" False "Discard this uncommitted builder."
      , Action "delegation.preview.unknown" "I don't know" "?" False "Explain proposed versus active responsibility."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "confirm_delegation")
      (brickFooter now state brick)

makeDelegationHandoffEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Delegation -> InteractionEnvelope
makeDelegationHandoffEnvelope identity cursor precondition now state brick delegation =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (DelegationHandoffOpportunity (delegationId delegation))
    (EnvelopeContent "Proposed delegation:" (Just (brickCitation brick)) ["To: " <> entityReference state (delegationTarget delegation), "Message:", delegationMessage delegation, "", "Human execution is still eligible."] (Just "After you have delivered this message or otherwise made the responsibility clear:"))
    [ Action "delegation.handoff.observed" "handed it off" "h" False "Record only that responsibility was communicated."
    , Action "delegation.handoff.edit" "edit message" "e" False "Revise the proposal without claiming delivery."
    , Action "delegation.handoff.cancel" "cancel delegation" "c" False "Cancel this proposed Delegation without an external message."
    , moreAction
    ]
    [showBrickCommand brick, helpCommand, exitCommand]
    Nothing
    (brickFooter now state brick)

makeDelegationTakeBackPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Delegation -> InteractionEnvelope
makeDelegationTakeBackPreviewEnvelope previous now state brick delegation =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (DelegationTakeBackPreviewOpportunity (delegationId delegation))
      (EnvelopeContent "Take responsibility back?" Nothing ["Work: " <> brickCitation brick, "From: " <> entityReference state (delegationTarget delegation), "Human work becomes eligible again: yes", "Optional take-back message: not sent"] Nothing)
      [ Action "delegation.take-back.accept" "yes" "y" False "Terminate this Delegation as taken back and restore human eligibility."
      , Action "delegation.take-back.reject" "no" "n" False "Keep current delegated responsibility."
      , Action "delegation.take-back.unknown" "I don't know" "?" False "Taking back changes responsibility but never claims completion."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "confirm_delegation_take_back")
      (brickFooter now state brick)

makeExternalEffectEditEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> ExternalEffect -> Text -> InteractionEnvelope
makeExternalEffectEditEnvelope previous now state brick effect draft =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      InputGrammar
      (ExternalEffectEditOpportunity (externalEffectId effect) draft)
      (EnvelopeContent "Edit external message" (Just (brickCitation brick)) ["To: " <> entityReference state (externalEffectTarget effect), "", draft] (Just "Message"))
      [Action "effect.edit.submit" "review" "enter" False "Create a new immutable pending revision and return to approval."]
      [showBrickCommand brick, helpCommand, exitCommand]
      Nothing
      (brickFooter now state brick)

makeExternalEffectDelayEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> ExternalEffect -> InteractionEnvelope
makeExternalEffectDelayEnvelope previous now state brick effect =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (ExternalEffectDelayOpportunity (externalEffectId effect))
      (EnvelopeContent "Review this external action later" (Just (brickCitation brick)) [] (Just "When may it return?"))
      [ Action "effect.delay.tomorrow" "tomorrow" "t" True "Defer approval review for 24 hours."
      , Action "effect.delay.three-days" "three days" "d" False "Defer approval review for 72 hours."
      , Action "effect.delay.week" "one week" "w" False "Defer approval review for 168 hours."
      , Action "effect.delay.unknown" "I don't know" "?" False "Deferral changes no approval, delivery, or Delegation fact."
      , moreAction
      ]
      [showBrickCommand brick, helpCommand, exitCommand]
      (Just "defer_external_effect")
      (brickFooter now state brick)

makeWaitReviewEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> WaitGate -> InteractionEnvelope
makeWaitReviewEnvelope identity cursor precondition now state brick gate =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (WaitReviewScreenOpportunity (waitId gate))
    ( EnvelopeContent
        "Review:"
        (Just (brickCitation brick))
        ["Waiting for:", waitTargetCitation state gate, "", "Waiting since " <> formatLocalDateTime (utcToZonedTime (zonedTimeZone now) (waitActivatedAt gate))]
        (Just "What happened?")
    )
    [ Action "wait.response" (if isCondition then "condition met" else "response received") (if isCondition then "c" else "r") False "Resolve only this Wait."
    , Action "wait.longer" "wait longer" "w" False "Choose a new review threshold."
    , Action "wait.follow-up" "follow up" "f" False "Create explicit enabling Work; do not claim that a message was sent."
    , Action "wait.change-blocker" "change what is blocking it" "b" False "Return to typed blocker classification."
    , Action "wait.skip" "skip" "s" False "Keep the review threshold and apply only a review cooldown."
    , Action "wait.unknown" "I don't know" "?" False "Clarify this review through bounded questions."
    , moreAction
    ]
    [helpCommand, exitCommand]
    (Just "understand_wait_review")
    (brickFooter now state brick)
 where
  isCondition = case waitKind gate of ExternalConditionWait{} -> True; _ -> False

makeWaitDelayEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> WaitGate -> InteractionEnvelope
makeWaitDelayEnvelope previous now state brick gate =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (WaitDelayOpportunity (waitId gate))
      (EnvelopeContent (brickCitation brick) Nothing ["Waiting for:", waitTargetCitation state gate] (Just "When may we start checking again?"))
      [ Action "wait.delay.tomorrow" "tomorrow" "t" False "Set the next review 24 hours from now."
      , Action "wait.delay.three-days" "three days" "d" True "Set the next review 72 hours from now."
      , Action "wait.delay.week" "one week" "w" False "Set the next review 168 hours from now."
      , Action "wait.delay.choose" "choose..." "c" False "Open structured date and time selection."
      , Action "wait.delay.unknown" "I don't know" "?" False "Explain the finite review-delay choices."
      , moreAction
      ]
      [helpCommand, exitCommand]
      (Just "choose_wait_review_time")
      (brickFooter now state brick)

makeWaitResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> WaitGate -> Text -> InteractionEnvelope
makeWaitResultEnvelope identity cursor precondition now state brick gate message =
  resultEnvelope identity cursor precondition now state (WaitResultOpportunity (waitId gate) message) "Wait updated:" [brickCitation brick, message]

makeDelegationReviewEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Delegation -> InteractionEnvelope
makeDelegationReviewEnvelope identity cursor precondition now state brick delegation =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (DelegationReviewScreenOpportunity (delegationId delegation))
    ( EnvelopeContent
        "Review:"
        (Just (brickCitation brick <> "\nDelegated to " <> entityReference state (delegationTarget delegation)))
        (maybe [] (pure . ("Last handoff: " <>) . formatLocalDateTime . utcToZonedTime (zonedTimeZone now)) (delegationInitialHandoffAt delegation))
        (Just "What happened?")
    )
    [ Action "delegation.progress" "progress update" "p" False "Record progress and schedule the next internal review."
    , Action "delegation.complete-report" "reported complete" "c" False "Enter Nature-aware completion reconciliation."
    , Action "delegation.refused" "refused" "r" False "Record refusal and enter responsibility reconciliation."
    , Action "delegation.no-response" "no response" "n" False "Record no response; any follow-up remains a separate approved effect."
    , Action "delegation.take-back" "take it back" "t" False "Preview restoring human responsibility."
    , Action "delegation.skip" "skip" "s" False "Preserve responsibility and defer only this review."
    , Action "delegation.unknown" "I don't know" "?" False "Use the bounded outcome question tree."
    , moreAction
    ]
    [helpCommand, exitCommand]
    (Just "understand_delegation_review")
    (brickFooter now state brick)

makeDelegationResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Delegation -> Text -> InteractionEnvelope
makeDelegationResultEnvelope identity cursor precondition now state brick delegation message =
  resultEnvelope identity cursor precondition now state (DelegationResultOpportunity (delegationId delegation) message) "Delegation updated:" [brickCitation brick, message]

makeExternalEffectApprovalEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> ExternalEffect -> InteractionEnvelope
makeExternalEffectApprovalEnvelope identity cursor precondition now state brick effect =
  sealed
    identity
    1
    cursor
    precondition
    ConfirmationGrammar
    (ExternalEffectApprovalScreenOpportunity (externalEffectId effect))
    ( EnvelopeContent
        "Approve this external action?"
        (Just (brickCitation brick))
        [ "To: " <> entityReference state (externalEffectTarget effect)
        , "Purpose: " <> Text.pack (show (externalEffectPurpose effect))
        , "Message:"
        , externalEffectMessage effect
        , "Nothing has been sent yet."
        ]
        Nothing
    )
    [ Action "effect.approve" "yes" "y" False "Approve this exact immutable effect revision."
    , Action "effect.edit" "edit" "e" False "Return to the message draft without approving."
    , Action "effect.reject" "no" "n" False "Reject only this effect instance."
    , Action "effect.later" "later" "l" False "Choose a later approval review."
    , Action "effect.skip" "skip" "s" False "Preserve this effect and its current review threshold."
    , Action "effect.unknown" "I don't know" "?" False "Explain approval and transport truth."
    , moreAction
    ]
    [helpCommand, exitCommand]
    (Just "understand_external_effect")
    (brickFooter now state brick)

makeExternalEffectResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> ExternalEffect -> Text -> InteractionEnvelope
makeExternalEffectResultEnvelope identity cursor precondition now state brick effect message =
  resultEnvelope identity cursor precondition now state (ExternalEffectResultOpportunity (externalEffectId effect) message) "External action updated:" [brickCitation brick, message]

scheduledOutcomeName :: StandingOutcomeKind -> Text
scheduledOutcomeName = \case
  StandingAttended -> "Attended"
  StandingMissed -> "Missed"
  StandingCancelled -> "Cancelled"
  other -> Text.pack (show other)

returnPolicySummary :: ReturnPolicy -> Text
returnPolicySummary = \case
  ManualOnlyReturn -> "Manual only."
  AfterCompletionReturn center unit variation zone ->
    "Around "
      <> Text.pack (show center)
      <> " "
      <> returnUnitName unit
      <> " after completion"
      <> (if variation == 0 then "." else ", with ±" <> Text.pack (show variation) <> " " <> returnUnitName unit <> " variation.")
      <> " Zone: "
      <> zone

returnUnitName :: ReturnUnit -> Text
returnUnitName = \case
  ReturnDays -> "days"
  ReturnWeeks -> "weeks"
  ReturnMonths -> "months"
  ReturnYears -> "years"

makeArchivePreviewEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Maybe UUIDv7 -> Maybe SkipSymptom -> InteractionEnvelope
makeArchivePreviewEnvelope identity cursor precondition now state brick selection symptom =
  sealed
    identity
    1
    cursor
    precondition
    ConfirmationGrammar
    (ArchivePreviewOpportunity (brickId brick) selection symptom)
    ( EnvelopeContent
        "Archive this Work?"
        (Just (brickCitation brick))
        [ "It will leave active Work without being marked done."
        , "Its identity, history, importance evidence, and local placement remain preserved."
        , "One later relevance review will be created."
        ]
        Nothing
    )
    [ Action "archive.accept" "yes" "y" False "Archive reversibly and create one relevance review."
    , Action "archive.reject" "no" "n" False "Return without changing lifecycle."
    , Action "archive.unknown" "I don't know" "?" False "Explain archive versus completion."
    , moreAction
    ]
    [showBrickCommand brick, helpCommand, exitCommand]
    (Just "confirm_archive")
    (brickFooter now state brick)

makeArchiveResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeArchiveResultEnvelope identity cursor precondition now state brick =
  resultEnvelope identity cursor precondition now state (ArchiveResultOpportunity (brickId brick)) "Archived:" [brickCitation brick, "One relevance review is pending."]

makeArchiveReviewResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> Text -> InteractionEnvelope
makeArchiveReviewResultEnvelope identity cursor precondition now state brick message =
  resultEnvelope identity cursor precondition now state (ArchiveResultOpportunity (brickId brick)) "Archive review settled:" [brickCitation brick, message]

makeRestorePreviewEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeRestorePreviewEnvelope identity cursor precondition now state brick =
  sealed
    identity
    1
    cursor
    precondition
    ConfirmationGrammar
    (RestorePreviewOpportunity (brickId brick))
    ( EnvelopeContent
        "Restore this Work?"
        (Just (brickCitation brick))
        [ "The same Brick becomes active again."
        , "Its previous local placement is retained provisionally and queued for lazy importance review."
        ]
        Nothing
    )
    [ Action "restore.accept" "yes" "y" False "Restore the same identity without starting focus."
    , Action "restore.reject" "no" "n" False "Leave the Brick archived."
    , Action "restore.unknown" "I don't know" "?" False "Explain forward restoration versus undo."
    , moreAction
    ]
    [showBrickCommand brick, helpCommand, exitCommand]
    (Just "confirm_restore")
    (brickFooter now state brick)

makeRestoreResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeRestoreResultEnvelope identity cursor precondition now state brick =
  resultEnvelope identity cursor precondition now state (RestoreResultOpportunity (brickId brick)) "Restored:" [brickCitation brick, "Importance placement is provisional and will be reviewed lazily."]

makeArchiveReviewEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> LazyReviewClaim -> InteractionEnvelope
makeArchiveReviewEnvelope identity cursor precondition now state brick review =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    (ArchiveReviewOpportunity (brickId brick) (lazyReviewId review))
    ( EnvelopeContent
        "Archived Work review:"
        (Just (brickCitation brick))
        [ "Archived: " <> formatLocalDateTime (utcToZonedTime (zonedTimeZone now) (lazyReviewCreatedAt review))
        , lazyReviewReason review
        ]
        (Just "Does it still make sense to keep this archived?")
    )
    [ Action "archive-review.keep" "keep archived" "k" False "Resolve this one review without creating another reminder."
    , Action "archive-review.restore" "restore it" "r" False "Preview restoring the same Brick."
    , Action "archive-review.update" "update and restore" "u" False "Enter semantic update before restoration."
    , Action "archive-review.supersede" "newer Work replaced it" "n" False "Enter explicit supersession."
    , Action "archive-review.skip" "skip" "s" False "Keep the review pending with review pressure."
    , Action "archive-review.unknown" "I don't know" "?" False "Discover whether the Work remains relevant."
    , moreAction
    ]
    [showBrickCommand brick, helpCommand, exitCommand]
    (Just "review_archived_work")
    (brickFooter now state brick)

makeRepairPreviewEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> FilePath -> FilePath -> FilePath -> FilePath -> Integer -> InteractionEnvelope
makeRepairPreviewEnvelope identity cursor planHash now state source original replacement candidate validEvents =
  sealed
    identity
    1
    cursor
    planHash
    ConfirmationGrammar
    (RepairPreviewOpportunity planHash source original replacement candidate validEvents)
    ( EnvelopeContent
        "Repair available."
        Nothing
        [ "Problem: one canonical segment has a filename that does not match its content hash."
        , "Validated prefix: " <> Text.pack (show validEvents) <> " events"
        , "Rename in candidate: " <> Text.pack original <> " → " <> Text.pack replacement
        , "Live dataset: " <> Text.pack source
        , "Separate candidate: " <> Text.pack candidate
        , "The live dataset will not be changed while the candidate is built and replayed."
        ]
        (Just "Build and fully replay this separate candidate?")
    )
    [ Action "repair.build" "build candidate" "b" False "Copy the dataset, apply only this typed repair, and replay it from zero."
    , Action "repair.assistance" "I don't know" "?" False "Explain the candidate boundary without changing either dataset."
    , moreAction
    ]
    repairCommands
    (Just "confirm_repair_candidate_build")
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))

makeRepairCandidateEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Text -> Text -> FilePath -> FilePath -> FilePath -> DatasetCursor -> Integer -> InteractionEnvelope
makeRepairCandidateEnvelope previous now state repairHash cutoverHash source candidate backup candidateCursor candidateEvents =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      repairHash
      ConfirmationGrammar
      (RepairCandidateOpportunity repairHash cutoverHash source candidate backup candidateCursor candidateEvents)
      ( EnvelopeContent
          "Repair candidate ready."
          Nothing
          [ "Live dataset: " <> Text.pack source
          , "Current live repair plan: " <> repairHash
          , "Candidate: " <> Text.pack candidate
          , "Validated events: " <> Text.pack (show candidateEvents)
          , "Validated cursor: " <> renderCursor candidateCursor
          , "Retained backup: " <> Text.pack backup
          , "Cutover uses an atomic filesystem exchange and keeps the old live dataset read-only."
          ]
          (Just "Replace the live dataset with this validated candidate?")
      )
      [ Action "repair.cutover" "cut over" "c" False "Durably record consent, atomically exchange datasets, and retain the old authority."
      , Action "repair.assistance" "I don't know" "?" False "Explain atomic cutover, recovery, and the retained backup."
      , moreAction
      ]
      repairCommands
      (Just "confirm_repair_cutover")
      (commonFooter now (brickCount state) (rawCount state) (reviewCount state))

makeRepairCompleteEnvelope :: InteractionEnvelope -> DatasetCursor -> Text -> ZonedTime -> State -> Text -> FilePath -> Bool -> InteractionEnvelope
makeRepairCompleteEnvelope previous cursor precondition now state cutoverHash backup recovered =
  resealEnvelope $
    ( resultEnvelope
        (envelopeInteractionId previous)
        cursor
        precondition
        now
        state
        (RepairCompleteOpportunity cutoverHash backup recovered)
        (if recovered then "Repair recovered and completed." else "Repair completed.")
        [ "The validated candidate is now live."
        , "Read-only backup: " <> Text.pack backup
        , "The canonical event history was never edited in place."
        ]
    )
      { envelopeRevision = envelopeRevision previous + 1
      }

repairCommands :: [CommandOption]
repairCommands =
  [ CommandOption "doctor" "/doctor" "Inspect the exact dataset boundary"
  , helpCommand
  , exitCommand
  ]

resultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Opportunity -> Text -> [Text] -> InteractionEnvelope
makeListEntryPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> Brick -> Text -> Quantity -> InteractionEnvelope
makeListEntryPreviewEnvelope previous now state raw owner label quantity =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ConfirmationGrammar
      (ListEntryPreviewOpportunity (rawId raw) (brickId owner) label quantity)
      ( EnvelopeContent
          "Add this list item?"
          (Just (brickCitation owner))
          ["Item: " <> label, "Quantity: " <> quantityText quantity, "Source: " <> rawCitation raw, "Raw material remains preserved."]
          Nothing
      )
      [ Action "list-entry.create" "yes" "y" True "Create one owner-scoped ListEntry and link the Raw receipt."
      , Action "list-entry.cancel" "no" "n" False "Return to destination selection without changing the Raw."
      , Action "list-entry.assistance" "I don't know" "?" False "Explain checklist ownership and quantity."
      , moreAction
      ]
      (rawCommands raw)
      (Just "confirm_list_entry")
      (brickFooter now state owner)

makeListEntryReuseEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Raw -> Brick -> ListEntry -> Quantity -> InteractionEnvelope
makeListEntryReuseEnvelope previous now state raw owner entry fedQuantity =
  advanceEnvelope previous $
    sealed
      (envelopeInteractionId previous)
      (envelopeRevision previous)
      (envelopeDatasetCursor previous)
      (envelopePreconditionHash previous)
      ChoiceGrammar
      (ListEntryReuseOpportunity (rawId raw) (brickId owner) (listEntryId entry) fedQuantity)
      ( EnvelopeContent
          "A similar list item already exists:"
          (Just (listEntryLabel entry))
          [ "Within: " <> brickCitation owner
          , "Existing quantity: " <> quantityText (listEntryQuantity entry)
          , "Fed quantity: " <> quantityText fedQuantity
          ]
          (Just "What should happen?")
      )
      ( [Action "list-entry.keep" "keep it as is" "k" True "Link this Raw receipt without changing quantity."]
          <> addAction
          <> [ Action "list-entry.change" "change the quantity..." "c" False "Edit the resulting quantity explicitly."
             , Action "list-entry.separate" "separate item..." "s" False "Distinguish a deliberately separate owner-scoped entry before creation."
             , Action "list-entry.assistance" "I don't know" "?" False "Explain owner-scoped reuse and quantity choices."
             , moreAction
             ]
      )
      (rawCommands raw)
      (Just "resolve_list_entry_reuse")
      (brickFooter now state owner)
 where
  sameUnit = quantityScale (listEntryQuantity entry) == quantityScale fedQuantity && quantityUnit (listEntryQuantity entry) == quantityUnit fedQuantity
  addAction =
    [ Action
        "list-entry.add-quantity"
        ("add the fed quantity    " <> quantityText (listEntryQuantity entry) <> " + " <> quantityText fedQuantity)
        "a"
        False
        "Add quantities with the same normalized unit."
    | sameUnit
    ]

makeListEntryResultEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Raw -> Brick -> ListEntry -> InteractionEnvelope
makeListEntryResultEnvelope identity cursor precondition now state raw owner entry =
  resultEnvelope
    identity
    cursor
    precondition
    now
    state
    (ListEntryResultOpportunity (rawId raw) (brickId owner) (listEntryId entry))
    "List item ready:"
    [listEntryLabel entry <> " × " <> quantityText (listEntryQuantity entry), "Within: " <> brickCitation owner, "From: " <> rawCitation raw]

quantityText :: Quantity -> Text
quantityText quantity =
  Text.pack (show (quantityCoefficient quantity))
    <> (if quantityScale quantity == 0 then "" else "e-" <> Text.pack (show (quantityScale quantity)))
    <> (if Text.null (quantityUnit quantity) then "" else " " <> quantityUnit quantity)

resultEnvelope identity cursor precondition now state opportunity heading body =
  sealed
    identity
    1
    cursor
    precondition
    ChoiceGrammar
    opportunity
    (EnvelopeContent heading Nothing body Nothing)
    [Action "next" "next" "n" False "Obtain the next useful opportunity.", moreAction]
    [feedCommand, helpCommand, exitCommand]
    Nothing
    (commonFooter now (brickCount state) (rawCount state) (reviewCount state))

advanceEnvelope :: InteractionEnvelope -> InteractionEnvelope -> InteractionEnvelope
advanceEnvelope previous candidate =
  resealEnvelope $
    candidate
      { envelopeInteractionId = envelopeInteractionId previous
      , envelopeRevision = envelopeRevision previous + 1
      , envelopeDatasetCursor = envelopeDatasetCursor previous
      , envelopePreconditionHash = envelopePreconditionHash previous
      , envelopeNoticeTurn = envelopeNoticeTurn previous + 1
      }

resealEnvelope :: InteractionEnvelope -> InteractionEnvelope
resealEnvelope envelope = sealEnvelope envelope{envelopeIntegrityToken = ""}

validateResponse :: InteractionEnvelope -> InteractionEnvelope -> InteractionResponse -> Either AppError ResponseValidation
validateResponse original replacement response
  | responseInteractionId response /= envelopeInteractionId original = invalid "The interaction identity is unknown."
  | responseRevision response /= envelopeRevision original = invalid "The interaction revision does not match."
  | responseIntegrityToken response /= envelopeIntegrityToken original = invalid "The interaction integrity token does not match."
  | responseActionId response `notElem` fmap actionId (envelopeActions original) = invalid "That action is not available on this screen."
  | responseAnsweredCursor response == envelopeDatasetCursor replacement = Right (ResponseAccepted (responseAnsweredCursor response) (envelopeDatasetCursor replacement))
  | envelopePreconditionHash original == envelopePreconditionHash replacement = Right (ResponseAccepted (responseAnsweredCursor response) (envelopeDatasetCursor replacement))
  | otherwise = Right (ResponseStale replacement)
 where
  invalid message =
    Left
      (appError PreconditionFailed message)
        { appErrorCursor = Just (renderCursor (envelopeDatasetCursor replacement))
        , appErrorRetrySafety = RetryAfterRefresh
        , appErrorRecovery = [RecoveryAction "continue" "Continue with the updated question." Nothing]
        }

envelopeIntegrityIsValid :: InteractionEnvelope -> Bool
envelopeIntegrityIsValid envelope = envelopeIntegrityToken envelope == integrityFor envelope

sealed :: UUIDv7 -> Int -> DatasetCursor -> Text -> ScreenGrammar -> Opportunity -> EnvelopeContent -> [Action] -> [CommandOption] -> Maybe Text -> Footer -> InteractionEnvelope
sealed identity revision cursor precondition grammar opportunity content actions commands uncertainty footer =
  sealEnvelope $ InteractionEnvelope identity revision cursor precondition grammar opportunity content actions commands uncertainty footer 0 "core" ""

sealEnvelope :: InteractionEnvelope -> InteractionEnvelope
sealEnvelope envelope = envelope{envelopeIntegrityToken = integrityFor envelope}

integrityFor :: InteractionEnvelope -> Text
integrityFor = sha256Hex . LazyByteString.toStrict . encode . unsignedEnvelopeValue

unsignedEnvelopeValue :: InteractionEnvelope -> Value
unsignedEnvelopeValue envelope =
  object $
    [ "interaction_id" .= renderUUIDv7 (envelopeInteractionId envelope)
    , "revision" .= envelopeRevision envelope
    , "dataset_cursor" .= renderCursor (envelopeDatasetCursor envelope)
    , "precondition_hash" .= envelopePreconditionHash envelope
    , "grammar" .= envelopeGrammar envelope
    , "opportunity" .= envelopeOpportunity envelope
    , "content" .= envelopeContent envelope
    , "actions" .= envelopeActions envelope
    , "commands" .= envelopeCommands envelope
    , "context" .= envelopeFooter envelope
    , "notice_turn" .= envelopeNoticeTurn envelope
    , "provenance" .= envelopeProvenance envelope
    ]
      <> maybe [] (pure . ("uncertainty_route" .=)) (envelopeUncertaintyRoute envelope)

commonFooter :: ZonedTime -> Int -> Int -> Int -> Footer
commonFooter now bricks raws reviews =
  Footer "<root>" "<no Domain>" "Workday" (formatWorkday now) (formatLocalDateTime now) bricks raws reviews "dumb" "idle" Nothing 0

rawFooter :: ZonedTime -> State -> Raw -> Footer
rawFooter now state raw =
  (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
    { footerTimeLabel = "Fed"
    , footerTimeValue = formatLocalDateTime (utcToZonedTime (zonedTimeZone now) (rawCreatedAt raw))
    , footerFocus = maybe "idle" (brickHandleText state) (stateCurrentFocus state)
    }

brickFooter :: ZonedTime -> State -> Brick -> Footer
brickFooter now state brick =
  sprintFooter
    ( (commonFooter now (brickCount state) (rawCount state) (reviewCount state))
        { footerParent = maybe "<root>" (brickReference state) (brickParent brick)
        , footerDomain = domainsText state (brickDomains brick)
        , footerFocus = maybe "idle" (brickHandleText state) (stateCurrentFocus state)
        }
    )
 where
  sprintFooter footer =
    case stateActiveSprint state of
      Just sprint
        | activeSprintBrick sprint == brickId brick ->
            let remaining = diffUTCTime (activeSprintEndsAt sprint) (zonedTimeToUTC now)
                ended = remaining <= 0
             in footer
                  { footerTimeLabel = if ended then "Sprint ended" else "Sprint"
                  , footerTimeValue =
                      if ended
                        then formatLocalDateTime (utcToZonedTime (zonedTimeZone now) (activeSprintEndsAt sprint))
                        else sprintRemaining remaining <> " remaining · ends " <> formatLocalDateTime (utcToZonedTime (zonedTimeZone now) (activeSprintEndsAt sprint))
                  }
      _ -> footer

sprintRemaining :: NominalDiffTime -> Text
sprintRemaining remaining =
  let totalSeconds = max 0 (floor remaining :: Int)
      (minutes, seconds) = divMod totalSeconds 60
   in Text.pack (show minutes) <> ":" <> Text.justifyRight 2 '0' (Text.pack (show seconds))

reviewCount :: State -> Int
reviewCount state = rawCount state + Map.size (stateLazyReviews state)

formatWorkday :: ZonedTime -> Text
formatWorkday now = Text.pack (formatTime defaultTimeLocale "%a, %b %-d" workday)
 where
  local = zonedTimeToLocalTime now
  day = localDay local
  workday = if localTimeOfDay local < TimeOfDay 6 0 0 then addDays (-1) day else day

formatLocalDateTime :: ZonedTime -> Text
formatLocalDateTime = Text.pack . formatTime defaultTimeLocale "%a, %b %-d, %H:%M"

rawPreview :: Raw -> Text
rawPreview = Text.take 80 . Text.unwords . Text.words . rawOriginal

rawCitation :: Raw -> Text
rawCitation raw = renderHandle RawHandle (rawHandle raw) <> " \"" <> rawPreview raw <> "\""

brickCitation :: Brick -> Text
brickCitation brick = renderHandle BrickHandle (brickHandle brick) <> " \"" <> brickTitle brick <> "\""

entityReference :: State -> UUIDv7 -> Text
entityReference state identity =
  maybe
    ("<missing @" <> renderUUIDv7 identity <> ">")
    (\entity -> renderHandle EntityHandle (externalEntityHandle entity) <> " \"" <> externalEntityName entity <> "\"")
    (Map.lookup identity (stateExternalEntities state))

waitTargetCitation :: State -> WaitGate -> Text
waitTargetCitation state gate = case waitKind gate of
  HumanResponseWait identity -> entityReference state identity
  ExternalConditionWait condition -> condition

delegationScopeLabel :: DelegationScope -> Text
delegationScopeLabel = \case
  BrickOnlyDelegation -> "brick only"
  WholeScopeDelegation -> "whole scope"

followUpPolicyLabel :: FollowUpPolicy -> Text
followUpPolicyLabel = \case
  FollowUpOnce -> "once"
  FollowUpEvery -> "every review"
  FollowUpNone -> "no automatic follow-up"

brickReference :: State -> UUIDv7 -> Text
brickReference state identity = maybe ("<missing " <> renderUUIDv7 identity <> ">") brickCitation (Map.lookup identity (stateBricks state))

brickHandleText :: State -> UUIDv7 -> Text
brickHandleText state identity = maybe "idle" (renderHandle BrickHandle . brickHandle) (Map.lookup identity (stateBricks state))

domainsText :: State -> Set.Set UUIDv7 -> Text
domainsText state identities
  | Set.null identities = "<no Domain>"
  | otherwise = Text.intercalate ", " [domainPath state identity | identity <- Set.toAscList identities]

domainPath :: State -> UUIDv7 -> Text
domainPath state identity = case Map.lookup identity (stateDomains state) of
  Nothing -> "<missing Domain>"
  Just domain -> maybe "" (\parent -> domainPath state parent <> " › ") (domainParent domain) <> domainName domain

destinationCandidates :: State -> [DestinationCandidate]
destinationCandidates state =
  fmap DestinationBrick (sortOn (\brick -> (brickSiblingPosition brick, brickTitle brick, brickId brick)) (activeBricks state))
    <> fmap DestinationShelf (sortOn (\shelf -> (rawShelfName shelf, rawShelfId shelf)) (filter rawShelfActive (Map.elems (stateRawShelves state))))

quotedDraft :: Raw -> Text
quotedDraft raw = "\"" <> titleDraft raw <> "\""

titleDraft :: Raw -> Text
titleDraft raw = case filter (not . Text.null) (fmap Text.strip (Text.lines (rawOriginal raw))) of
  first : _ -> titleCaseFirst first
  [] -> ""

titleCaseFirst :: Text -> Text
titleCaseFirst text = case Text.uncons text of
  Nothing -> text
  Just (first, rest) -> Text.cons (toUpperAscii first) rest
 where
  toUpperAscii character
    | isAsciiLower character = toEnum (fromEnum character - 32)
    | otherwise = character

natureQuestionText :: NatureDiscovery -> Text
natureQuestionText discovery
  | discoveryAlternateProbe discovery = alternateQuestion (discoveryQuestion discovery)
  | otherwise = directQuestion (discoveryQuestion discovery)

directQuestion :: NatureQuestion -> Text
directQuestion = \case
  FixedTimeQuestion -> "Must this happen during an externally fixed time or time window?"
  FiniteIntentionQuestion -> "Will completing this once finish the whole intention?"
  MultipartQuestion -> "Does completion require tracking multiple parts?"
  IndependentPartsQuestion -> "Do any parts need independent focus, importance, blockers, dates, Domain membership, or history?"
  ChangingMembersQuestion -> "Does it maintain a changing set of members or entries?"
  IndependentMemberQuestion -> "Should next ever serve one member independently?"
  OpenOccurrenceQuestion -> "Does each required occurrence remain open until completed or explicitly closed?"
  StreakQuestion -> "Are missed time windows recorded and are streaks meaningful?"

alternateQuestion :: NatureQuestion -> Text
alternateQuestion = \case
  FixedTimeQuestion -> "Would doing it earlier still satisfy the intention?"
  FiniteIntentionQuestion -> "Should this Brick remain active after a successful run?"
  MultipartQuestion -> "Would one done action lose progress that should be tracked separately?"
  IndependentPartsQuestion -> "Could any part need its own next, importance, blocker, date, Domain, or history?"
  ChangingMembersQuestion -> "Will items be added or removed while the parent remains?"
  IndependentMemberQuestion -> "At focus time, must the whole open set appear together?"
  OpenOccurrenceQuestion -> "If one due period is not completed, should its occurrence remain open or overdue?"
  StreakQuestion -> "Should an unfulfilled window affect history or a streak?"

natureProbeExplanation :: NatureQuestion -> Text
natureProbeExplanation = \case
  FixedTimeQuestion -> "A flight is fixed-time; writing a report is flexible."
  FiniteIntentionQuestion -> "A project ends; a recurring practice remains active."
  MultipartQuestion -> "One errand is atomic; a migration may need tracked parts."
  IndependentPartsQuestion -> "Project parts can be served alone; checklist entries appear together."
  ChangingMembersQuestion -> "A collection changes membership; repeatable work records executions."
  IndependentMemberQuestion -> "A book can be served alone; a grocery list appears together."
  OpenOccurrenceQuestion -> "An unpaid bill remains open; a repeatable review does not accumulate."
  StreakQuestion -> "A missed walk affects history; a reread simply returns later."

rawCommands :: Raw -> [CommandOption]
rawCommands raw =
  [ feedCommand
  , CommandOption "show" ("/show " <> rawCitation raw) ("Inspect " <> rawCitation raw)
  , CommandOption "history" "/history" "Open interaction history"
  , helpCommand
  , exitCommand
  ]

feedCommand :: CommandOption
feedCommand = CommandOption "feed" "/feed" "Feed Little Ant"

helpCommand :: CommandOption
helpCommand = CommandOption "help" "/help" "Open Little Ant help"

exitCommand :: CommandOption
exitCommand = CommandOption "exit" "/exit" "Leave this presentation session"

showBrickCommand :: Brick -> CommandOption
showBrickCommand brick = CommandOption "show" ("/show " <> brickCitation brick) ("Inspect " <> brickCitation brick)

moreAction :: Action
moreAction = Action "palette.open" "more..." "/" False "Open contextual commands."

reactionHeading :: SkipSymptom -> Text
reactionHeading = \case
  TiredSymptom -> "You're tired. What would help?"
  BoredSymptom -> "You're bored. What would help?"
  FearSymptom -> "You're worried about this. What would help?"
  VagueSymptom -> "This Brick is vague. What is missing?"
  HardSymptom -> "This feels hard. What would help?"
  BigSymptom -> "What would help?"
  BlockedOrWaitingSymptom -> "What needs to happen before you can continue?"
  LessImportantSymptom -> "What should change?"
  OutOfDateSymptom -> "What does \"out of date\" mean here?"
  OtherSymptom{} -> "What else is getting in the way?"
  BlockedSymptom -> "What would unblock this?"
  WaitingSymptom -> "What are we waiting for?"

reactionQuestion :: SkipSymptom -> Text
reactionQuestion = \case
  VagueSymptom -> "What kind of clarity is missing?"
  BlockedOrWaitingSymptom -> "Choose the human situation."
  _ -> "Choose one recovery."

reactionActions :: SkipSymptom -> [Action]
reactionActions = \case
  VagueSymptom ->
    [ action "work.reaction.goal" "🎯 goal — the intended result is unclear" "g" "Clarify the Brick's Description."
    , action "work.reaction.information" "📚 information — more context is needed" "i" "Create enabling information Work."
    , action "work.reaction.first-step" "🧭 first step — it is unclear how to begin" "f" "Find one actionable first step."
    , skip
    , unknown
    ]
  HardSymptom ->
    [ action "work.reaction.learn" "📚 learn or practice first" "l" "Create enabling learning Work."
    , action "work.reaction.break" "🧩 break into smaller parts" "b" "Open the decomposition preview."
    , action "work.reaction.easier-approach" "🔧 find an easier approach" "f" "Create enabling method-improvement Work."
    , action "work.reaction.support" "🤝 get help" "g" "Open a typed handoff."
    , skip
    , unknown
    ]
  BigSymptom ->
    [ action "work.reaction.break" "break it into parts" "b" "Open the decomposition preview."
    , action "work.reaction.context" "collect more context" "c" "Create enabling context Work."
    , action "work.reaction.learn" "learn about the subject" "l" "Create enabling learning Work."
    , skip
    , unknown
    ]
  BlockedOrWaitingSymptom ->
    [ action "work.reaction.prerequisite" "🧱 another task must be completed" "t" "Find or create a prerequisite Brick."
    , action "work.reaction.response" "👤 someone must respond" "r" "Choose an ExternalEntity and request state."
    , action "work.reaction.until" "🗓️ wait until a date or time" "u" "Choose an absolute not-before instant."
    , action "work.reaction.location" "📍 be at a location" "l" "Choose a required Place."
    , action "work.reaction.condition" "🔔 an event or condition must occur" "e" "Describe a Wait condition."
    , skip
    , unknown
    ]
  TiredSymptom ->
    [ action "work.reaction.easier-work" "🪶 easier work" "e" "Choose from a bounded easier-work shortlist."
    , action "work.reaction.change-subject" "🔀 change subject" "c" "Choose a positive Domain target."
    , action "work.reaction.pause" "🌙 pause for now" "p" "Clear current focus while leaving Work WIP."
    , skip
    , unknown
    ]
  BoredSymptom ->
    [ action "work.reaction.change-subject" "change subject" "c" "Choose a positive Domain target."
    , action "work.reaction.interesting" "make it more interesting" "m" "Choose a bounded method change."
    , skip
    , unknown
    ]
  FearSymptom ->
    [ action "work.reaction.validate-risk" "🔬 validate the risk first" "v" "Create validation Work."
    , action "work.reaction.safer-move" "🪜 make a safer first move" "m" "Create a safer enabling Brick."
    , action "work.reaction.support" "🤝 get support" "g" "Open a typed handoff."
    , skip
    , unknown
    ]
  LessImportantSymptom ->
    [ action "work.reaction.order-lower" "⚖️ order it lower" "o" "Start targeted importance ordering."
    , action "work.reaction.later" "🕒 later" "l" "Choose an absolute not-before instant."
    , action "work.reaction.change-subject" "🧭 change subject" "c" "Choose a positive Domain target."
    , skip
    , unknown
    ]
  OutOfDateSymptom ->
    [ action "work.reaction.archive" "🗄️ archive it" "a" "Archive reversibly and create one relevance review."
    , action "work.reaction.replace" "🔁 replaced by newer Work" "r" "Open explicit supersession."
    , action "work.reaction.update" "✏️ update it" "u" "Open inspected semantic editing."
    , skip
    , unknown
    ]
  OtherSymptom{} -> [skip, unknown]
  BlockedSymptom -> [skip, unknown]
  WaitingSymptom -> [skip, unknown]
 where
  action identity label shortcut consequence = Action identity label shortcut False consequence
  skip = action "work.reaction.skip" "⏭️ skip anyway" "s" "Record this symptom with ordinary cooldown."
  unknown = action "work.reaction.unknown" "❓ I don't know" "?" "Explain these recoveries without selecting one."

skipSymptomName :: SkipSymptom -> Text
skipSymptomName = \case
  VagueSymptom -> "vague"
  HardSymptom -> "hard"
  BigSymptom -> "big"
  BlockedOrWaitingSymptom -> "blocked_or_waiting"
  BlockedSymptom -> "blocked"
  WaitingSymptom -> "waiting"
  TiredSymptom -> "tired"
  BoredSymptom -> "bored"
  FearSymptom -> "fear"
  LessImportantSymptom -> "less_important"
  OutOfDateSymptom -> "out_of_date"
  OtherSymptom{} -> "other"

skipSymptomDetail :: SkipSymptom -> [Pair]
skipSymptomDetail = \case
  OtherSymptom explanation -> ["explanation" .= explanation]
  _ -> []

parseSkipSymptomFields :: Object -> Parser SkipSymptom
parseSkipSymptomFields value =
  value .: "symptom" >>= \case
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

skipSymptomDisplay :: SkipSymptom -> Text
skipSymptomDisplay = \case
  VagueSymptom -> "💭 vague"
  HardSymptom -> "🧗 hard"
  BigSymptom -> "🏔️ big"
  BlockedOrWaitingSymptom -> "🚧 blocked or waiting"
  BlockedSymptom -> "🚧 blocked"
  WaitingSymptom -> "⏳ waiting"
  TiredSymptom -> "🥱 tired"
  BoredSymptom -> "😐 bored"
  FearSymptom -> "😨 fear"
  LessImportantSymptom -> "⬇️ less important"
  OutOfDateSymptom -> "🕰️ out of date"
  OtherSymptom explanation -> "🧩 other — " <> explanation

skipSymptomReason :: SkipSymptom -> Text
skipSymptomReason = \case
  BlockedOrWaitingSymptom -> "Something outside this Brick must happen first."
  VagueSymptom -> "A clearer result, more information, or a first step would help."
  BigSymptom -> "Independently tracked parts would make this manageable."
  HardSymptom -> "The Work is clear but knowledge, skill, or approach is missing."
  OutOfDateSymptom -> "Changed facts or context may have made this Brick stale."
  LessImportantSymptom -> "More-important Work would win if only one could ever be completed."
  TiredSymptom -> "Rest or easier Work would help without changing the Brick."
  BoredSymptom -> "A more engaging method would help without changing the result."
  FearSymptom -> "Validating or reducing perceived risk would help."
  OtherSymptom explanation -> explanation
  BlockedSymptom -> "Another Brick must be completed first."
  WaitingSymptom -> "A person, time, place, event, or condition must change first."

skipReactionName :: SkipReaction -> Text
skipReactionName = \case
  SkipAnywayReaction -> "skip anyway"
  PauseForNowReaction -> "pause for now"
  StartSprintReaction minutes -> "short sprint · " <> Text.pack (show minutes) <> " minutes"
  ArchiveReaction -> "archive"
  KeepAndUpdateReaction -> "keep and update"
  BreakIntoPartsReaction -> "break into parts"
  CollectContextReaction -> "collect context"
  LearnFirstReaction -> "learn first"
  FindEasierApproachReaction -> "find an easier approach"
  GetHelpReaction -> "get help"
  ChangeSubjectReaction -> "change subject"
  EasierWorkReaction identity -> "easier Work · " <> renderUUIDv7 identity
  OrderLowerReaction -> "order lower"
  LaterReaction -> "later"
  CreateRequestReaction -> "create request"

parseSkipReactionName :: Object -> Text -> Parser SkipReaction
parseSkipReactionName value = \case
  "skip anyway" -> pure SkipAnywayReaction
  "pause for now" -> pure PauseForNowReaction
  "archive" -> pure ArchiveReaction
  "keep and update" -> pure KeepAndUpdateReaction
  "break into parts" -> pure BreakIntoPartsReaction
  "collect context" -> pure CollectContextReaction
  "learn first" -> pure LearnFirstReaction
  "find an easier approach" -> pure FindEasierApproachReaction
  "get help" -> pure GetHelpReaction
  "change subject" -> pure ChangeSubjectReaction
  "order lower" -> pure OrderLowerReaction
  "later" -> pure LaterReaction
  "create request" -> pure CreateRequestReaction
  text
    | Just minutesText <- Text.stripPrefix "short sprint · " text
    , Just numberText <- Text.stripSuffix " minutes" minutesText ->
        maybe (fail "invalid sprint reaction") (pure . StartSprintReaction) (readMaybeInt numberText)
  text
    | Just identityText <- Text.stripPrefix "easier Work · " text ->
        EasierWorkReaction <$> parseUuid identityText
  other -> fail ("unknown skip reaction: " <> Text.unpack other)
 where
  _unused = value

skipDiscoveryNodeName :: SkipDiscoveryNode -> Text
skipDiscoveryNodeName = \case
  OutsidePrerequisiteNode -> "outside_prerequisite"
  UnclearWorkNode -> "unclear_work"
  TrackedPartsNode -> "tracked_parts"
  DifficultWorkNode -> "difficult_work"
  StaleWorkNode -> "stale_work"
  RelativeImportanceNode -> "relative_importance"
  EnergyNode -> "energy"
  InterestNode -> "interest"
  RiskNode -> "risk"

parseSkipDiscoveryNode :: Text -> Parser SkipDiscoveryNode
parseSkipDiscoveryNode name =
  maybe (fail ("unknown skip discovery node: " <> Text.unpack name)) pure (lookup name table)
 where
  table = [(skipDiscoveryNodeName node, node) | node <- [minBound .. maxBound]]

skipDiscoveryQuestion :: SkipDiscoveryNode -> Bool -> Text
skipDiscoveryQuestion node alternate =
  if alternate then skipAlternateQuestion node else primaryQuestion node

primaryQuestion :: SkipDiscoveryNode -> Text
primaryQuestion = \case
  OutsidePrerequisiteNode -> "Must something outside this Brick happen before you can continue?"
  UnclearWorkNode -> "Is the main problem that the result, required information, or first step is unclear?"
  TrackedPartsNode -> "Would independently tracked parts make this manageable?"
  DifficultWorkNode -> "Is the Work clear and small enough, but beyond your current knowledge, skill, or available approach?"
  StaleWorkNode -> "Have changed facts or context made this Brick stale?"
  RelativeImportanceNode -> "If this Brick and more-important Work were mutually exclusive forever, would you leave this Brick undone?"
  EnergyNode -> "Is insufficient energy the main obstacle?"
  InterestNode -> "Is lack of interest or stimulation the main obstacle?"
  RiskNode -> "Is worry about risk or consequences the main obstacle?"

skipAlternateQuestion :: SkipDiscoveryNode -> Text
skipAlternateQuestion = \case
  OutsidePrerequisiteNode -> "If that outside fact changed now, could you proceed without changing the Brick?"
  UnclearWorkNode -> "Would a clearer result, more information, or a defined first step be enough to get moving?"
  TrackedPartsNode -> "Would one done action hide progress worth tracking separately?"
  DifficultWorkNode -> "Do you know what needs doing but not how to do it effectively?"
  StaleWorkNode -> "Would current facts make you archive, replace, or revise this Brick rather than merely postpone it?"
  RelativeImportanceNode -> "If only this Brick or more-important Work could ever be completed, would you give this one up?"
  EnergyNode -> "Would rest or easier Work help without changing the Brick?"
  InterestNode -> "Would a more engaging method help without changing the intended result?"
  RiskNode -> "Would validating or reducing a perceived risk help?"

skipDiscoveryExplanation :: SkipDiscoveryNode -> Text
skipDiscoveryExplanation node =
  "This alternate probe distinguishes " <> skipDiscoveryNodeName node <> " without recording an answer."

readMaybeInt :: Text -> Maybe Int
readMaybeInt text =
  case reads (Text.unpack text) of
    [(value, "")] -> Just value
    _ -> Nothing

assignTemplateShortcuts :: [TemplateDefinition] -> [(TemplateDefinition, Text)]
assignTemplateShortcuts definitions = snd (foldl assign (Set.singleton "n", []) definitions)
 where
  assign (used, result) definition =
    let preferred = templateShortcut definition
        candidates = maybe [] pure preferred <> fmap Text.singleton (Text.unpack (Text.filter (/= '_') (templateDefinitionId definition)))
        chosen = fromMaybe "?" (firstUnused used candidates)
     in (Set.insert chosen used, result <> [(definition, chosen)])
  firstUnused _ [] = Nothing
  firstUnused used (candidate : rest)
    | candidate `Set.member` used = firstUnused used rest
    | otherwise = Just candidate

importanceText :: State -> WorkDraft -> Text
importanceText state draft = case sortOn brickSiblingPosition (siblingBricks state (workDraftParent draft)) of
  [] -> "only sibling"
  siblings ->
    let before = [brick | brick <- siblings, brickSiblingPosition brick < workDraftSiblingPosition draft]
        after = [brick | brick <- siblings, brickSiblingPosition brick >= workDraftSiblingPosition draft]
     in Text.intercalate "; " (maybeText "below " (lastMaybe before) <> maybeText "above " (firstMaybe after))
 where
  maybeText prefix = maybe [] (pure . (prefix <>) . brickCitation)

createdImportanceText :: State -> Brick -> Text
createdImportanceText state brick = importanceText state (WorkDraft (brickId brick) (brickTitle brick) (brickNature brick) (brickTemplate brick) (brickParent brick) (brickDomains brick) (brickSiblingPosition brick) (brickImportanceConfidence brick) [])

confidenceText :: ImportanceConfidence -> Text
confidenceText = \case
  HumanComparison -> "human comparison"
  DeterministicPosition reason -> "deterministic · " <> reason
  Provisional reason -> "provisional · " <> reason

firstMaybe :: [value] -> Maybe value
firstMaybe = \case [] -> Nothing; value : _ -> Just value

lastMaybe :: [value] -> Maybe value
lastMaybe = foldl (\_ value -> Just value) Nothing

rawLinkRoleText :: RawLinkRole -> Text
rawLinkRoleText = \case
  DescriptionRole -> "description"
  MaterializationSourceRole -> "materialization_source"
  AttachmentRole -> "attachment"
  EvidenceRole -> "evidence"
  DerivedFromRole -> "derived_from"
  DuplicateOfRole -> "duplicate_of"

parseRawLinkRoleText :: Text -> Parser RawLinkRole
parseRawLinkRoleText = \case
  "description" -> pure DescriptionRole
  "materialization_source" -> pure MaterializationSourceRole
  "attachment" -> pure AttachmentRole
  "evidence" -> pure EvidenceRole
  "derived_from" -> pure DerivedFromRole
  "duplicate_of" -> pure DuplicateOfRole
  value -> fail ("unknown RawLink role: " <> Text.unpack value)

instance ToJSON ScreenGrammar where toJSON = toJSON . grammarText
instance FromJSON ScreenGrammar where
  parseJSON = withText "ScreenGrammar" $ \case
    "focus" -> pure FocusGrammar
    "comparison" -> pure ComparisonGrammar
    "confirmation" -> pure ConfirmationGrammar
    "choice" -> pure ChoiceGrammar
    "input" -> pure InputGrammar
    _ -> fail "unknown screen grammar"

grammarText :: ScreenGrammar -> Text
grammarText = \case
  FocusGrammar -> "focus"
  ComparisonGrammar -> "comparison"
  ConfirmationGrammar -> "confirmation"
  ChoiceGrammar -> "choice"
  InputGrammar -> "input"

instance ToJSON Opportunity where toJSON = opportunityValue
instance FromJSON Opportunity where parseJSON = parseOpportunity

opportunityValue :: Opportunity -> Value
opportunityValue = \case
  PristineOpportunity -> typed "pristine" []
  SafeEmptyOpportunity -> typed "safe_empty" []
  RawTriageOpportunity identity handle preview -> typed "raw_triage" ["raw_id" .= renderUUIDv7 identity, "handle" .= unHandle handle, "preview" .= preview]
  RawDuplicateOpportunity candidate root -> typed "raw_duplicate" ["candidate_raw_id" .= renderUUIDv7 candidate, "root_raw_id" .= renderUUIDv7 root]
  TranslationScopeOpportunity scope -> typed "translation_scope" ["scope" .= translationScopeValue scope]
  TranslationEditOpportunity queue suggestion attribution -> typed "translation_edit" (["queue" .= translationQueueValue queue] <> maybe [] (pure . ("suggestion" .=)) suggestion <> maybe [] (pure . ("attribution" .=)) attribution)
  TranslationPreviewOpportunity queue proposed source producer confidence -> typed "translation_preview" (["queue" .= translationQueueValue queue, "proposed" .= proposed, "source" .= normalizationSourceName source] <> maybe [] (pure . ("producer" .=)) producer <> maybe [] (pure . ("confidence" .=) . unFixed) confidence)
  TranslationCompleteOpportunity accepted skipped total -> typed "translation_complete" ["accepted" .= accepted, "skipped" .= skipped, "total" .= total]
  RawDetailOpportunity identity -> typed "raw_detail" ["raw_id" .= renderUUIDv7 identity]
  RawOriginListOpportunity identity -> typed "raw_origin_list" ["raw_id" .= renderUUIDv7 identity]
  SourceBindingOpportunity identity -> typed "source_binding" ["binding_id" .= renderUUIDv7 identity]
  SourceChangeOpportunity identity -> typed "source_change" ["observation_id" .= renderUUIDv7 identity]
  SourceReconciliationPreviewOpportunity identity choice -> typed "source_reconciliation_preview" ["observation_id" .= renderUUIDv7 identity, "choice" .= sourceChoiceName choice]
  SourceFailureOpportunity identity -> typed "source_failure" ["observation_id" .= renderUUIDv7 identity]
  SourceRelocateOpportunity identity draft -> typed "source_relocate" ["binding_id" .= renderUUIDv7 identity, "draft" .= draft]
  SourceRelocatePreviewOpportunity identity locator -> typed "source_relocate_preview" ["binding_id" .= renderUUIDv7 identity, "locator" .= locator]
  SourceLifecyclePreviewOpportunity identity lifecycle -> typed "source_lifecycle_preview" ["binding_id" .= renderUUIDv7 identity, "lifecycle" .= sourceLifecycleLabel lifecycle]
  SourceResultOpportunity identity result -> typed "source_result" ["raw_id" .= renderUUIDv7 identity, "result" .= result]
  ImportPreflightOpportunity source preflight eraseAfterImport -> typed "import_preflight" ["source" .= source, "preflight" .= preflight, "erase_after_import" .= eraseAfterImport]
  ImportResultOpportunity imported reused cleanupReady -> typed "import_result" ["imported_raw_ids" .= fmap renderUUIDv7 imported, "reused_raw_ids" .= fmap renderUUIDv7 reused, "cleanup_ready" .= cleanupReady]
  PackInstallOpportunity draft -> typed "pack_install" ["draft" .= draft]
  PackTrustOpportunity draft -> typed "pack_trust" ["draft" .= draft]
  PackInstallResultOpportunity artifact -> typed "pack_install_result" ["artifact" .= artifact]
  PackTrustResultOpportunity publisher -> typed "pack_trust_result" ["publisher" .= publisher]
  RawDestinationOpportunity identity page -> typed "raw_destination" ["raw_id" .= renderUUIDv7 identity, "page" .= page]
  RawGroupDiscoveryOpportunity rawId -> typed "raw_group_discovery" ["raw_id" .= renderUUIDv7 rawId]
  RawShelfNameOpportunity rawId name -> typed "raw_shelf_name" ["raw_id" .= renderUUIDv7 rawId, "name" .= name]
  RawShelfCreatePreviewOpportunity rawId name -> typed "raw_shelf_create_preview" ["raw_id" .= renderUUIDv7 rawId, "name" .= name]
  RawShelfMembershipPreviewOpportunity rawId shelfId -> typed "raw_shelf_membership_preview" ["raw_id" .= renderUUIDv7 rawId, "shelf_id" .= renderUUIDv7 shelfId]
  RawShelfResultOpportunity rawId shelfId -> typed "raw_shelf_result" ["raw_id" .= renderUUIDv7 rawId, "shelf_id" .= renderUUIDv7 shelfId]
  RawUnderBrickOpportunity rawId brickId -> typed "raw_under_brick" ["raw_id" .= renderUUIDv7 rawId, "brick_id" .= renderUUIDv7 brickId]
  RawAttachmentOpportunity rawId brickId -> typed "raw_attachment" ["raw_id" .= renderUUIDv7 rawId, "brick_id" .= renderUUIDv7 brickId]
  RawAttachmentResultOpportunity rawId brickId role -> typed "raw_attachment_result" ["raw_id" .= renderUUIDv7 rawId, "brick_id" .= renderUUIDv7 brickId, "role" .= rawLinkRoleText role]
  NatureChoiceOpportunity context -> typed "nature_choice" ["context" .= workContextValue context]
  NatureDiscoveryOpportunity context discovery -> typed "nature_discovery" ["context" .= workContextValue context, "discovery" .= discoveryValue discovery]
  NatureConfirmationOpportunity context nature reason lastQuestion -> typed "nature_confirmation" ["context" .= workContextValue context, "nature" .= natureText nature, "reason" .= reason, "last_question" .= questionText lastQuestion]
  TemplateChoiceOpportunity context nature -> typed "template_choice" ["context" .= workContextValue context, "nature" .= natureText nature]
  WorkTitleOpportunity context nature template title -> typed "work_title" (["context" .= workContextValue context, "nature" .= natureText nature, "title" .= title] <> maybe [] (pure . ("template" .=) . templateSelectionValue) template)
  DomainSelectionOpportunity draft candidates -> typed "domain_selection" ["draft" .= workDraftValue draft, "candidates" .= fmap renderUUIDv7 candidates]
  DomainFocusOpportunity identity -> typed "domain_focus" ["domain_id" .= renderUUIDv7 identity]
  DomainFocusResultOpportunity identity mode -> typed "domain_focus_result" ["domain_id" .= renderUUIDv7 identity, "mode" .= domainFocusModeName mode]
  ExistingWorkSuspicionOpportunity draft brickId -> typed "existing_work_suspicion" ["draft" .= workDraftValue draft, "brick_id" .= renderUUIDv7 brickId]
  ExistingWorkReuseResultOpportunity rawId brickId -> typed "existing_work_reuse_result" ["raw_id" .= renderUUIDv7 rawId, "brick_id" .= renderUUIDv7 brickId]
  ListEntryPreviewOpportunity rawId ownerId label quantity -> typed "list_entry_preview" ["raw_id" .= renderUUIDv7 rawId, "owner_id" .= renderUUIDv7 ownerId, "label" .= label, "quantity" .= quantityValue quantity]
  ListEntryReuseOpportunity rawId ownerId entryId quantity -> typed "list_entry_reuse" ["raw_id" .= renderUUIDv7 rawId, "owner_id" .= renderUUIDv7 ownerId, "entry_id" .= renderUUIDv7 entryId, "fed_quantity" .= quantityValue quantity]
  ListEntryResultOpportunity rawId ownerId entryId -> typed "list_entry_result" ["raw_id" .= renderUUIDv7 rawId, "owner_id" .= renderUUIDv7 ownerId, "entry_id" .= renderUUIDv7 entryId]
  ImportanceInsertionOpportunity draft low high skipped comparator -> typed "importance_insertion" ["draft" .= workDraftValue draft, "low" .= low, "high" .= high, "skipped" .= fmap renderUUIDv7 skipped, "comparator_id" .= renderUUIDv7 comparator]
  OrderScopeOpportunity -> typed "order_scope" []
  ImportanceReviewOpportunity session first second skips skipped provocative -> typed "importance_review" ["session" .= orderSessionValue session, "first" .= renderUUIDv7 first, "second" .= renderUUIDv7 second, "skip_count" .= skips, "skipped" .= fmap renderUUIDv7 skipped, "provocative" .= provocative]
  ImportanceContradictionOpportunity session first second path -> typed "importance_contradiction" ["session" .= orderSessionValue session, "first" .= renderUUIDv7 first, "second" .= renderUUIDv7 second, "path" .= fmap renderUUIDv7 path]
  ImportanceContradictionAidOpportunity session triad -> typed "importance_contradiction_aid" ["session" .= orderSessionValue session, "triad" .= fmap renderUUIDv7 triad]
  ImportanceDiscoveryOpportunity session first second node alternate -> typed "importance_discovery" ["session" .= orderSessionValue session, "first" .= renderUUIDv7 first, "second" .= renderUUIDv7 second, "node" .= importanceNodeText node, "alternate_probe" .= alternate]
  ImportanceDirectionConfirmationOpportunity session first second -> typed "importance_direction_confirmation" ["session" .= orderSessionValue session, "first" .= renderUUIDv7 first, "second" .= renderUUIDv7 second]
  ImportanceEitherConfirmationOpportunity session first second -> typed "importance_either_confirmation" ["session" .= orderSessionValue session, "first" .= renderUUIDv7 first, "second" .= renderUUIDv7 second]
  ImportanceProvisionalConfirmationOpportunity session first second -> typed "importance_provisional_confirmation" ["session" .= orderSessionValue session, "first" .= renderUUIDv7 first, "second" .= renderUUIDv7 second]
  OrderResultOpportunity session complete remaining -> typed "order_result" ["session" .= orderSessionValue session, "complete" .= complete, "remaining" .= remaining]
  ImpactClassOpportunity brickId -> typed "impact_class" ["brick_id" .= renderUUIDv7 brickId]
  ImpactBasisOpportunity brickId impact -> typed "impact_basis" ["brick_id" .= renderUUIDv7 brickId, "class" .= impactClassText impact]
  ImpactEvidenceOpportunity brickId impact candidates -> typed "impact_evidence" ["brick_id" .= renderUUIDv7 brickId, "class" .= impactClassText impact, "candidates" .= fmap renderUUIDv7 candidates]
  ImpactMaturityOpportunity brickId impact evidence question alternate -> typed "impact_maturity" ["brick_id" .= renderUUIDv7 brickId, "class" .= impactClassText impact, "evidence_id" .= renderUUIDv7 evidence, "question" .= impactMaturityQuestionText question, "alternate_probe" .= alternate]
  ImpactMaturityPreviewOpportunity brickId impact evidence maturity -> typed "impact_maturity_preview" ["brick_id" .= renderUUIDv7 brickId, "class" .= impactClassText impact, "evidence_id" .= renderUUIDv7 evidence, "maturity" .= impactMaturityTextValue maturity]
  ImpactComparisonOpportunity first second skips skipped provocative -> typed "impact_comparison" ["first" .= renderUUIDv7 first, "second" .= renderUUIDv7 second, "skip_count" .= skips, "skipped" .= fmap renderUUIDv7 skipped, "provocative" .= provocative]
  ImpactContradictionOpportunity subject comparator above below relation path -> typed "impact_contradiction" ["subject" .= renderUUIDv7 subject, "comparator" .= renderUUIDv7 comparator, "above" .= renderUUIDv7 above, "below" .= renderUUIDv7 below, "relation" .= judgmentRelationText relation, "path" .= fmap renderUUIDv7 path]
  EffortClassOpportunity brickId -> typed "effort_class" ["brick_id" .= renderUUIDv7 brickId]
  EffortExemplarOpportunity brickId exemplar index remaining tried -> typed "effort_exemplar" ["brick_id" .= renderUUIDv7 brickId, "exemplar_id" .= renderUUIDv7 exemplar, "index" .= index, "remaining" .= fmap effortClassTextValue remaining, "tried" .= fmap renderUUIDv7 tried]
  EffortContradictionOpportunity brickId exemplar index remaining tried above below relation path -> typed "effort_contradiction" ["brick_id" .= renderUUIDv7 brickId, "exemplar_id" .= renderUUIDv7 exemplar, "index" .= index, "remaining" .= fmap effortClassTextValue remaining, "tried" .= fmap renderUUIDv7 tried, "above" .= renderUUIDv7 above, "below" .= renderUUIDv7 below, "relation" .= judgmentRelationText relation, "path" .= fmap renderUUIDv7 path]
  JudgmentContradictionAidOpportunity axis subject triad retired -> typed "judgment_contradiction_aid" ["axis" .= judgmentAxisText axis, "subject" .= renderUUIDv7 subject, "triad" .= fmap renderUUIDv7 triad, "retired" .= fmap renderUUIDv7 retired]
  EffortNarrowedOpportunity brickId remaining -> typed "effort_narrowed" ["brick_id" .= renderUUIDv7 brickId, "remaining" .= fmap effortClassTextValue remaining]
  EffortProposalOpportunity brickId effort -> typed "effort_proposal" ["brick_id" .= renderUUIDv7 brickId, "class" .= effortClassTextValue effort]
  PhaseOpportunity brickId -> typed "phase" ["brick_id" .= renderUUIDv7 brickId]
  JudgmentResultOpportunity axis brickId message -> typed "judgment_result" ["axis" .= judgmentAxisText axis, "brick_id" .= renderUUIDv7 brickId, "message" .= message]
  WorkPreviewOpportunity draft -> typed "work_preview" ["draft" .= workDraftValue draft]
  StandaloneResultOpportunity identity -> typed "standalone_result" ["raw_id" .= renderUUIDv7 identity]
  WorkCreatedResultOpportunity rawId brickId -> typed "work_created_result" ["raw_id" .= renderUUIDv7 rawId, "brick_id" .= renderUUIDv7 brickId]
  FocusProposalOpportunity identity selection ->
    typed
      "focus_proposal"
      ( ["brick_id" .= renderUUIDv7 identity]
          <> maybe [] (pure . ("selection_id" .=) . renderUUIDv7) selection
      )
  CurrentFocusOpportunity identity -> typed "current_focus" ["brick_id" .= renderUUIDv7 identity]
  ChecklistRunOpportunity identity selected ->
    typed "checklist_run" (["owner_id" .= renderUUIDv7 identity] <> maybe [] (pure . ("selected_entry_id" .=) . renderUUIDv7) selected)
  ChecklistRunResultOpportunity identity -> typed "checklist_run_result" ["owner_id" .= renderUUIDv7 identity]
  RepeatableReturnOpportunity identity review -> typed "repeatable_return" ["owner_id" .= renderUUIDv7 identity, "review_id" .= renderUUIDv7 review]
  RepeatableReturnCenterOpportunity identity review draft -> typed "repeatable_return_center" ["owner_id" .= renderUUIDv7 identity, "review_id" .= renderUUIDv7 review, "draft" .= draft]
  RepeatableReturnUnitOpportunity identity review center -> typed "repeatable_return_unit" ["owner_id" .= renderUUIDv7 identity, "review_id" .= renderUUIDv7 review, "center" .= center]
  RepeatableReturnVariationOpportunity identity review center unit draft -> typed "repeatable_return_variation" ["owner_id" .= renderUUIDv7 identity, "review_id" .= renderUUIDv7 review, "center" .= center, "unit" .= returnUnitName unit, "draft" .= draft]
  RepeatableReturnZoneOpportunity identity review center unit variation draft -> typed "repeatable_return_zone" ["owner_id" .= renderUUIDv7 identity, "review_id" .= renderUUIDv7 review, "center" .= center, "unit" .= returnUnitName unit, "variation" .= variation, "draft" .= draft]
  RepeatableReturnPreviewOpportunity identity review policy chosen notBefore resolution seed ->
    typed "repeatable_return_preview" ["owner_id" .= renderUUIDv7 identity, "review_id" .= renderUUIDv7 review, "policy" .= interactionReturnPolicyValue policy, "chosen_offset" .= chosen, "not_before" .= interactionZonedInstantValue notBefore, "resolution" .= resolution, "seed" .= TextEncoding.decodeUtf8 (Base16.encode seed)]
  RepeatableReturnResultOpportunity identity -> typed "repeatable_return_result" ["owner_id" .= renderUUIDv7 identity]
  ScheduledCommitmentOpportunity identity -> typed "scheduled_commitment" ["owner_id" .= renderUUIDv7 identity]
  ScheduledOverlapOpportunity identities -> typed "scheduled_overlap" ["owner_ids" .= fmap renderUUIDv7 identities]
  ScheduledOutcomeResultOpportunity identity outcome -> typed "scheduled_outcome_result" ["owner_id" .= renderUUIDv7 identity, "outcome" .= scheduledOutcomeName outcome]
  NoticeListOpportunity notices -> typed "notice_list" ["notices" .= fmap noticeIdentityValue notices]
  TemporalNoticeOpportunity notice -> typed "temporal_notice" ["notice" .= noticeIdentityValue notice]
  NoticeSnoozeOpportunity notice -> typed "notice_snooze" ["notice" .= noticeIdentityValue notice]
  NoticeResultOpportunity notice result -> typed "notice_result" ["notice" .= noticeIdentityValue notice, "result" .= result]
  WaitReviewScreenOpportunity identity -> typed "wait_review" ["wait_id" .= renderUUIDv7 identity]
  WaitDelayOpportunity identity -> typed "wait_delay" ["wait_id" .= renderUUIDv7 identity]
  EntitySelectOpportunity brickId selection purpose -> typed "entity_select" (selectionFields brickId selection <> ["purpose" .= entityPurposeText purpose])
  EntityKindOpportunity brickId selection purpose -> typed "entity_kind" (selectionFields brickId selection <> ["purpose" .= entityPurposeText purpose])
  EntityNameOpportunity brickId selection purpose kind draft -> typed "entity_name" (selectionFields brickId selection <> ["purpose" .= entityPurposeText purpose, "kind" .= externalEntityKindName kind, "draft" .= draft])
  WaitRequestStatusOpportunity brickId selection entityId -> typed "wait_request_status" (selectionFields brickId selection <> ["entity_id" .= renderUUIDv7 entityId])
  WaitRequestInputOpportunity brickId selection entityId draft -> typed "wait_request_input" (selectionFields brickId selection <> ["entity_id" .= renderUUIDv7 entityId, "draft" .= draft])
  WaitRequestDelayOpportunity brickId selection entityId rawId -> typed "wait_request_delay" (selectionFields brickId selection <> ["entity_id" .= renderUUIDv7 entityId, "raw_id" .= renderUUIDv7 rawId])
  WaitRequestPreviewOpportunity brickId selection entityId rawId delay -> typed "wait_request_preview" (selectionFields brickId selection <> ["entity_id" .= renderUUIDv7 entityId, "raw_id" .= renderUUIDv7 rawId, "review_delay_seconds" .= delay])
  WaitRequestHandoffResultOpportunity brickId enablingId waitId -> typed "wait_request_handoff_result" ["brick_id" .= renderUUIDv7 brickId, "enabling_brick_id" .= renderUUIDv7 enablingId, "wait_id" .= renderUUIDv7 waitId]
  WaitConditionInputOpportunity brickId selection draft -> typed "wait_condition_input" (selectionFields brickId selection <> ["draft" .= draft])
  DependencySelectOpportunity brickId selection -> typed "dependency_select" (selectionFields brickId selection)
  DependencyPreviewOpportunity brickId selection blockerId -> typed "dependency_preview" (selectionFields brickId selection <> ["blocker_id" .= renderUUIDv7 blockerId])
  DependencyResultOpportunity brickId blockerId -> typed "dependency_result" ["brick_id" .= renderUUIDv7 brickId, "blocker_id" .= renderUUIDv7 blockerId]
  WaitActivationDelayOpportunity brickId selection kind -> typed "wait_activation_delay" (selectionFields brickId selection <> ["wait_kind" .= interactionWaitKindValue kind])
  WaitActivationResultOpportunity identity -> typed "wait_activation_result" ["wait_id" .= renderUUIDv7 identity]
  WaitResultOpportunity identity result -> typed "wait_result" ["wait_id" .= renderUUIDv7 identity, "result" .= result]
  DelegationScopeOpportunity draft -> typed "delegation_scope" ["draft" .= delegationDraftValue draft]
  DelegationPolicyOpportunity draft -> typed "delegation_policy" ["draft" .= delegationDraftValue draft]
  DelegationDelayOpportunity draft -> typed "delegation_delay" ["draft" .= delegationDraftValue draft]
  DelegationPreviewOpportunity draft -> typed "delegation_preview" ["draft" .= delegationDraftValue draft]
  DelegationMessageOpportunity draft -> typed "delegation_message" ["draft" .= delegationDraftValue draft]
  DelegationHandoffOpportunity identity -> typed "delegation_handoff" ["delegation_id" .= renderUUIDv7 identity]
  DelegationTakeBackPreviewOpportunity identity -> typed "delegation_take_back_preview" ["delegation_id" .= renderUUIDv7 identity]
  DelegationReviewScreenOpportunity identity -> typed "delegation_review" ["delegation_id" .= renderUUIDv7 identity]
  DelegationResultOpportunity identity result -> typed "delegation_result" ["delegation_id" .= renderUUIDv7 identity, "result" .= result]
  ExternalEffectApprovalScreenOpportunity identity -> typed "external_effect_approval" ["effect_id" .= renderUUIDv7 identity]
  ExternalEffectRecoveryScreenOpportunity identity -> typed "external_effect_recovery" ["effect_id" .= renderUUIDv7 identity]
  ExternalEffectDuplicateRiskOpportunity identity -> typed "external_effect_duplicate_risk" ["effect_id" .= renderUUIDv7 identity]
  ExternalEffectEditOpportunity identity draft -> typed "external_effect_edit" ["effect_id" .= renderUUIDv7 identity, "draft" .= draft]
  ExternalEffectDelayOpportunity identity -> typed "external_effect_delay" ["effect_id" .= renderUUIDv7 identity]
  ExternalEffectResultOpportunity identity result -> typed "external_effect_result" ["effect_id" .= renderUUIDv7 identity, "result" .= result]
  WorkSkipSymptomOpportunity identity selection ->
    typed "work_skip_symptom" (selectionFields identity selection)
  WorkSkipReactionOpportunity identity selection symptom ->
    typed "work_skip_reaction" (selectionFields identity selection <> ["symptom" .= skipSymptomName symptom] <> skipSymptomDetail symptom)
  WorkSkipDiscoveryOpportunity identity selection node alternate ->
    typed "work_skip_discovery" (selectionFields identity selection <> ["node" .= skipDiscoveryNodeName node, "alternate_probe" .= alternate])
  WorkSkipConfirmationOpportunity identity selection symptom ->
    typed "work_skip_confirmation" (selectionFields identity selection <> ["symptom" .= skipSymptomName symptom] <> skipSymptomDetail symptom)
  WorkOtherExplanationOpportunity identity selection draft ->
    typed "work_other_explanation" (selectionFields identity selection <> ["draft" .= draft])
  WorkOtherPreviewOpportunity identity selection explanation ->
    typed "work_other_preview" (selectionFields identity selection <> ["explanation" .= explanation])
  WorkInterestingOpportunity identity selection ->
    typed "work_interesting" (selectionFields identity selection)
  WorkBreakNatureOpportunity identity selection symptom ->
    typed "work_break_nature" (selectionFields identity selection <> optionalSymptomFields symptom)
  WorkBreakDraftOpportunity identity selection symptom target titles ->
    typed "work_break_draft" (selectionFields identity selection <> optionalSymptomFields symptom <> optionalNatureFields target <> ["titles" .= titles])
  WorkBreakPreviewOpportunity identity selection symptom target titles ->
    typed "work_break_preview" (selectionFields identity selection <> optionalSymptomFields symptom <> optionalNatureFields target <> ["titles" .= titles])
  WorkBreakResultOpportunity identity children ->
    typed "work_break_result" ["brick_id" .= renderUUIDv7 identity, "children" .= fmap renderUUIDv7 children]
  WorkSprintDurationOpportunity identity selection ->
    typed "work_sprint_duration" (selectionFields identity selection)
  WorkSkipAcknowledgedOpportunity identity symptom reaction ->
    typed
      "work_skip_acknowledged"
      ( ["brick_id" .= renderUUIDv7 identity, "symptom" .= skipSymptomName symptom, "reaction" .= skipReactionName reaction]
          <> skipSymptomDetail symptom
      )
  ArchivePreviewOpportunity identity selection symptom ->
    typed "archive_preview" (selectionFields identity selection <> optionalSymptomFields symptom)
  ArchiveResultOpportunity identity -> typed "archive_result" ["brick_id" .= renderUUIDv7 identity]
  RestorePreviewOpportunity identity -> typed "restore_preview" ["brick_id" .= renderUUIDv7 identity]
  RestoreResultOpportunity identity -> typed "restore_result" ["brick_id" .= renderUUIDv7 identity]
  ArchiveReviewOpportunity identity review -> typed "archive_review" ["brick_id" .= renderUUIDv7 identity, "review_id" .= renderUUIDv7 review]
  CompletionResultOpportunity identity -> typed "completion_result" ["brick_id" .= renderUUIDv7 identity]
  RepairPreviewOpportunity planHash source original replacement candidate validEvents ->
    typed
      "repair_preview"
      [ "plan_hash" .= planHash
      , "source_root" .= source
      , "original_segment" .= original
      , "replacement_segment" .= replacement
      , "candidate_root" .= candidate
      , "valid_event_count" .= validEvents
      ]
  RepairCandidateOpportunity repairHash cutoverHash source candidate backup cursor eventCount ->
    typed
      "repair_candidate"
      [ "repair_plan_hash" .= repairHash
      , "cutover_plan_hash" .= cutoverHash
      , "source_root" .= source
      , "candidate_root" .= candidate
      , "backup_root" .= backup
      , "candidate_cursor" .= cursor
      , "candidate_event_count" .= eventCount
      ]
  RepairCompleteOpportunity cutoverHash backup recovered ->
    typed "repair_complete" ["cutover_plan_hash" .= cutoverHash, "backup_root" .= backup, "recovered" .= recovered]
 where
  typed typeName fields = object ("type" .= (typeName :: Text) : fields)
  selectionFields identity selection =
    ["brick_id" .= renderUUIDv7 identity]
      <> maybe [] (pure . ("selection_id" .=) . renderUUIDv7) selection
  optionalSymptomFields = maybe [] (\symptom -> ["symptom" .= skipSymptomName symptom] <> skipSymptomDetail symptom)
  optionalNatureFields = maybe [] (\nature -> ["target_nature" .= natureText nature])

parseOpportunity :: Value -> Parser Opportunity
parseOpportunity = withObject "Opportunity" $ \value ->
  value .: "type" >>= \case
    ("pristine" :: Text) -> pure PristineOpportunity
    "safe_empty" -> pure SafeEmptyOpportunity
    "raw_triage" -> RawTriageOpportunity <$> uuidField value "raw_id" <*> (Handle <$> value .: "handle") <*> value .: "preview"
    "raw_duplicate" -> RawDuplicateOpportunity <$> uuidField value "candidate_raw_id" <*> uuidField value "root_raw_id"
    "translation_scope" -> TranslationScopeOpportunity <$> (value .: "scope" >>= parseTranslationScope)
    "translation_edit" -> TranslationEditOpportunity <$> (value .: "queue" >>= parseTranslationQueue) <*> value .:? "suggestion" <*> value .:? "attribution"
    "translation_preview" -> TranslationPreviewOpportunity <$> (value .: "queue" >>= parseTranslationQueue) <*> value .: "proposed" <*> (value .: "source" >>= parseNormalizationSourceName) <*> value .:? "producer" <*> (fmap Fixed <$> value .:? "confidence")
    "translation_complete" -> TranslationCompleteOpportunity <$> value .: "accepted" <*> value .: "skipped" <*> value .: "total"
    "raw_detail" -> RawDetailOpportunity <$> uuidField value "raw_id"
    "raw_origin_list" -> RawOriginListOpportunity <$> uuidField value "raw_id"
    "source_binding" -> SourceBindingOpportunity <$> uuidField value "binding_id"
    "source_change" -> SourceChangeOpportunity <$> uuidField value "observation_id"
    "source_reconciliation_preview" -> SourceReconciliationPreviewOpportunity <$> uuidField value "observation_id" <*> (value .: "choice" >>= parseSourceChoice)
    "source_failure" -> SourceFailureOpportunity <$> uuidField value "observation_id"
    "source_relocate" -> SourceRelocateOpportunity <$> uuidField value "binding_id" <*> value .: "draft"
    "source_relocate_preview" -> SourceRelocatePreviewOpportunity <$> uuidField value "binding_id" <*> value .: "locator"
    "source_lifecycle_preview" -> SourceLifecyclePreviewOpportunity <$> uuidField value "binding_id" <*> (value .: "lifecycle" >>= parseSourceLifecycleLabel)
    "source_result" -> SourceResultOpportunity <$> uuidField value "raw_id" <*> value .: "result"
    "import_preflight" -> ImportPreflightOpportunity <$> value .: "source" <*> value .: "preflight" <*> value .: "erase_after_import"
    "import_result" -> ImportResultOpportunity <$> (value .: "imported_raw_ids" >>= traverse parseUuid) <*> (value .: "reused_raw_ids" >>= traverse parseUuid) <*> value .: "cleanup_ready"
    "pack_install" -> PackInstallOpportunity <$> value .: "draft"
    "pack_trust" -> PackTrustOpportunity <$> value .: "draft"
    "pack_install_result" -> PackInstallResultOpportunity <$> value .: "artifact"
    "pack_trust_result" -> PackTrustResultOpportunity <$> value .: "publisher"
    "raw_destination" -> RawDestinationOpportunity <$> uuidField value "raw_id" <*> value .: "page"
    "raw_group_discovery" -> RawGroupDiscoveryOpportunity <$> uuidField value "raw_id"
    "raw_shelf_name" -> RawShelfNameOpportunity <$> uuidField value "raw_id" <*> value .: "name"
    "raw_shelf_create_preview" -> RawShelfCreatePreviewOpportunity <$> uuidField value "raw_id" <*> value .: "name"
    "raw_shelf_membership_preview" -> RawShelfMembershipPreviewOpportunity <$> uuidField value "raw_id" <*> uuidField value "shelf_id"
    "raw_shelf_result" -> RawShelfResultOpportunity <$> uuidField value "raw_id" <*> uuidField value "shelf_id"
    "raw_under_brick" -> RawUnderBrickOpportunity <$> uuidField value "raw_id" <*> uuidField value "brick_id"
    "raw_attachment" -> RawAttachmentOpportunity <$> uuidField value "raw_id" <*> uuidField value "brick_id"
    "raw_attachment_result" -> RawAttachmentResultOpportunity <$> uuidField value "raw_id" <*> uuidField value "brick_id" <*> (value .: "role" >>= parseRawLinkRoleText)
    "nature_choice" -> NatureChoiceOpportunity <$> (value .: "context" >>= parseWorkContext)
    "nature_discovery" -> NatureDiscoveryOpportunity <$> (value .: "context" >>= parseWorkContext) <*> (value .: "discovery" >>= parseDiscovery)
    "nature_confirmation" -> NatureConfirmationOpportunity <$> (value .: "context" >>= parseWorkContext) <*> (value .: "nature" >>= parseNature) <*> value .: "reason" <*> (value .: "last_question" >>= parseQuestion)
    "template_choice" -> TemplateChoiceOpportunity <$> (value .: "context" >>= parseWorkContext) <*> (value .: "nature" >>= parseNature)
    "work_title" -> WorkTitleOpportunity <$> (value .: "context" >>= parseWorkContext) <*> (value .: "nature" >>= parseNature) <*> (value .:? "template" >>= traverse parseTemplateSelection) <*> value .: "title"
    "domain_selection" -> DomainSelectionOpportunity <$> (value .: "draft" >>= parseWorkDraft) <*> (value .: "candidates" >>= traverse parseUuid)
    "domain_focus" -> DomainFocusOpportunity <$> uuidField value "domain_id"
    "domain_focus_result" -> DomainFocusResultOpportunity <$> uuidField value "domain_id" <*> (value .: "mode" >>= parseDomainFocusMode)
    "existing_work_suspicion" -> ExistingWorkSuspicionOpportunity <$> (value .: "draft" >>= parseWorkDraft) <*> uuidField value "brick_id"
    "existing_work_reuse_result" -> ExistingWorkReuseResultOpportunity <$> uuidField value "raw_id" <*> uuidField value "brick_id"
    "list_entry_preview" -> ListEntryPreviewOpportunity <$> uuidField value "raw_id" <*> uuidField value "owner_id" <*> value .: "label" <*> (value .: "quantity" >>= parseQuantity)
    "list_entry_reuse" -> ListEntryReuseOpportunity <$> uuidField value "raw_id" <*> uuidField value "owner_id" <*> uuidField value "entry_id" <*> (value .: "fed_quantity" >>= parseQuantity)
    "list_entry_result" -> ListEntryResultOpportunity <$> uuidField value "raw_id" <*> uuidField value "owner_id" <*> uuidField value "entry_id"
    "importance_insertion" -> ImportanceInsertionOpportunity <$> (value .: "draft" >>= parseWorkDraft) <*> value .: "low" <*> value .: "high" <*> (value .: "skipped" >>= traverse parseUuid) <*> uuidField value "comparator_id"
    "order_scope" -> pure OrderScopeOpportunity
    "importance_review" -> ImportanceReviewOpportunity <$> (value .: "session" >>= parseOrderSession) <*> uuidField value "first" <*> uuidField value "second" <*> value .: "skip_count" <*> (value .: "skipped" >>= traverse parseUuid) <*> value .: "provocative"
    "importance_contradiction" -> ImportanceContradictionOpportunity <$> (value .: "session" >>= parseOrderSession) <*> uuidField value "first" <*> uuidField value "second" <*> (value .: "path" >>= traverse parseUuid)
    "importance_contradiction_aid" -> ImportanceContradictionAidOpportunity <$> (value .: "session" >>= parseOrderSession) <*> (value .: "triad" >>= traverse parseUuid)
    "importance_discovery" -> ImportanceDiscoveryOpportunity <$> (value .: "session" >>= parseOrderSession) <*> uuidField value "first" <*> uuidField value "second" <*> (value .: "node" >>= parseImportanceNode) <*> value .: "alternate_probe"
    "importance_direction_confirmation" -> ImportanceDirectionConfirmationOpportunity <$> (value .: "session" >>= parseOrderSession) <*> uuidField value "first" <*> uuidField value "second"
    "importance_either_confirmation" -> ImportanceEitherConfirmationOpportunity <$> (value .: "session" >>= parseOrderSession) <*> uuidField value "first" <*> uuidField value "second"
    "importance_provisional_confirmation" -> ImportanceProvisionalConfirmationOpportunity <$> (value .: "session" >>= parseOrderSession) <*> uuidField value "first" <*> uuidField value "second"
    "order_result" -> OrderResultOpportunity <$> (value .: "session" >>= parseOrderSession) <*> value .: "complete" <*> value .: "remaining"
    "impact_class" -> ImpactClassOpportunity <$> uuidField value "brick_id"
    "impact_basis" -> ImpactBasisOpportunity <$> uuidField value "brick_id" <*> (value .: "class" >>= parseImpactClassText)
    "impact_evidence" -> ImpactEvidenceOpportunity <$> uuidField value "brick_id" <*> (value .: "class" >>= parseImpactClassText) <*> (value .: "candidates" >>= traverse parseUuid)
    "impact_maturity" -> ImpactMaturityOpportunity <$> uuidField value "brick_id" <*> (value .: "class" >>= parseImpactClassText) <*> uuidField value "evidence_id" <*> (value .: "question" >>= parseImpactMaturityQuestion) <*> value .: "alternate_probe"
    "impact_maturity_preview" -> ImpactMaturityPreviewOpportunity <$> uuidField value "brick_id" <*> (value .: "class" >>= parseImpactClassText) <*> uuidField value "evidence_id" <*> (value .: "maturity" >>= parseImpactMaturityTextValue)
    "impact_comparison" -> ImpactComparisonOpportunity <$> uuidField value "first" <*> uuidField value "second" <*> value .: "skip_count" <*> (value .: "skipped" >>= traverse parseUuid) <*> value .: "provocative"
    "impact_contradiction" -> ImpactContradictionOpportunity <$> uuidField value "subject" <*> uuidField value "comparator" <*> uuidField value "above" <*> uuidField value "below" <*> (value .: "relation" >>= parseJudgmentRelationText) <*> (value .: "path" >>= traverse parseUuid)
    "effort_class" -> EffortClassOpportunity <$> uuidField value "brick_id"
    "effort_exemplar" -> EffortExemplarOpportunity <$> uuidField value "brick_id" <*> uuidField value "exemplar_id" <*> value .: "index" <*> (value .: "remaining" >>= traverse parseEffortClassTextValue) <*> (value .: "tried" >>= traverse parseUuid)
    "effort_contradiction" -> EffortContradictionOpportunity <$> uuidField value "brick_id" <*> uuidField value "exemplar_id" <*> value .: "index" <*> (value .: "remaining" >>= traverse parseEffortClassTextValue) <*> (value .: "tried" >>= traverse parseUuid) <*> uuidField value "above" <*> uuidField value "below" <*> (value .: "relation" >>= parseJudgmentRelationText) <*> (value .: "path" >>= traverse parseUuid)
    "judgment_contradiction_aid" -> JudgmentContradictionAidOpportunity <$> (value .: "axis" >>= parseJudgmentAxisText) <*> uuidField value "subject" <*> (value .: "triad" >>= traverse parseUuid) <*> (value .: "retired" >>= traverse parseUuid)
    "effort_narrowed" -> EffortNarrowedOpportunity <$> uuidField value "brick_id" <*> (value .: "remaining" >>= traverse parseEffortClassTextValue)
    "effort_proposal" -> EffortProposalOpportunity <$> uuidField value "brick_id" <*> (value .: "class" >>= parseEffortClassTextValue)
    "phase" -> PhaseOpportunity <$> uuidField value "brick_id"
    "judgment_result" -> JudgmentResultOpportunity <$> (value .: "axis" >>= parseJudgmentAxisText) <*> uuidField value "brick_id" <*> value .: "message"
    "work_preview" -> WorkPreviewOpportunity <$> (value .: "draft" >>= parseWorkDraft)
    "standalone_result" -> StandaloneResultOpportunity <$> uuidField value "raw_id"
    "work_created_result" -> WorkCreatedResultOpportunity <$> uuidField value "raw_id" <*> uuidField value "brick_id"
    "focus_proposal" -> FocusProposalOpportunity <$> uuidField value "brick_id" <*> (value .:? "selection_id" >>= traverse parseUuid)
    "current_focus" -> CurrentFocusOpportunity <$> uuidField value "brick_id"
    "checklist_run" -> ChecklistRunOpportunity <$> uuidField value "owner_id" <*> (value .:? "selected_entry_id" >>= traverse parseUuid)
    "checklist_run_result" -> ChecklistRunResultOpportunity <$> uuidField value "owner_id"
    "repeatable_return" -> RepeatableReturnOpportunity <$> uuidField value "owner_id" <*> uuidField value "review_id"
    "repeatable_return_center" -> RepeatableReturnCenterOpportunity <$> uuidField value "owner_id" <*> uuidField value "review_id" <*> value .: "draft"
    "repeatable_return_unit" -> RepeatableReturnUnitOpportunity <$> uuidField value "owner_id" <*> uuidField value "review_id" <*> value .: "center"
    "repeatable_return_variation" -> RepeatableReturnVariationOpportunity <$> uuidField value "owner_id" <*> uuidField value "review_id" <*> value .: "center" <*> (value .: "unit" >>= parseInteractionReturnUnit) <*> value .: "draft"
    "repeatable_return_zone" -> RepeatableReturnZoneOpportunity <$> uuidField value "owner_id" <*> uuidField value "review_id" <*> value .: "center" <*> (value .: "unit" >>= parseInteractionReturnUnit) <*> value .: "variation" <*> value .: "draft"
    "repeatable_return_preview" -> RepeatableReturnPreviewOpportunity <$> uuidField value "owner_id" <*> uuidField value "review_id" <*> (value .: "policy" >>= parseInteractionReturnPolicy) <*> value .: "chosen_offset" <*> (value .: "not_before" >>= parseInteractionZonedInstant) <*> value .: "resolution" <*> (value .: "seed" >>= parseInteractionSeed)
    "repeatable_return_result" -> RepeatableReturnResultOpportunity <$> uuidField value "owner_id"
    "scheduled_commitment" -> ScheduledCommitmentOpportunity <$> uuidField value "owner_id"
    "scheduled_overlap" -> ScheduledOverlapOpportunity <$> (value .: "owner_ids" >>= traverse parseUuid)
    "scheduled_outcome_result" -> ScheduledOutcomeResultOpportunity <$> uuidField value "owner_id" <*> (value .: "outcome" >>= parseInteractionScheduledOutcome)
    "notice_list" -> NoticeListOpportunity <$> (value .: "notices" >>= traverse parseNoticeIdentity)
    "temporal_notice" -> TemporalNoticeOpportunity <$> (value .: "notice" >>= parseNoticeIdentity)
    "notice_snooze" -> NoticeSnoozeOpportunity <$> (value .: "notice" >>= parseNoticeIdentity)
    "notice_result" -> NoticeResultOpportunity <$> (value .: "notice" >>= parseNoticeIdentity) <*> value .: "result"
    "wait_review" -> WaitReviewScreenOpportunity <$> uuidField value "wait_id"
    "wait_delay" -> WaitDelayOpportunity <$> uuidField value "wait_id"
    "entity_select" -> EntitySelectOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> (value .: "purpose" >>= parseEntityPurpose)
    "entity_kind" -> EntityKindOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> (value .: "purpose" >>= parseEntityPurpose)
    "entity_name" -> EntityNameOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> (value .: "purpose" >>= parseEntityPurpose) <*> (value .: "kind" >>= parseExternalEntityKindName) <*> value .: "draft"
    "wait_request_status" -> WaitRequestStatusOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> uuidField value "entity_id"
    "wait_request_input" -> WaitRequestInputOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> uuidField value "entity_id" <*> value .: "draft"
    "wait_request_delay" -> WaitRequestDelayOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> uuidField value "entity_id" <*> uuidField value "raw_id"
    "wait_request_preview" -> WaitRequestPreviewOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> uuidField value "entity_id" <*> uuidField value "raw_id" <*> value .: "review_delay_seconds"
    "wait_request_handoff_result" -> WaitRequestHandoffResultOpportunity <$> uuidField value "brick_id" <*> uuidField value "enabling_brick_id" <*> uuidField value "wait_id"
    "wait_condition_input" -> WaitConditionInputOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> value .: "draft"
    "dependency_select" -> DependencySelectOpportunity <$> uuidField value "brick_id" <*> selectionId value
    "dependency_preview" -> DependencyPreviewOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> uuidField value "blocker_id"
    "dependency_result" -> DependencyResultOpportunity <$> uuidField value "brick_id" <*> uuidField value "blocker_id"
    "wait_activation_delay" -> WaitActivationDelayOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> (value .: "wait_kind" >>= parseInteractionWaitKind)
    "wait_activation_result" -> WaitActivationResultOpportunity <$> uuidField value "wait_id"
    "wait_result" -> WaitResultOpportunity <$> uuidField value "wait_id" <*> value .: "result"
    "delegation_scope" -> DelegationScopeOpportunity <$> (value .: "draft" >>= parseDelegationDraft)
    "delegation_policy" -> DelegationPolicyOpportunity <$> (value .: "draft" >>= parseDelegationDraft)
    "delegation_delay" -> DelegationDelayOpportunity <$> (value .: "draft" >>= parseDelegationDraft)
    "delegation_preview" -> DelegationPreviewOpportunity <$> (value .: "draft" >>= parseDelegationDraft)
    "delegation_message" -> DelegationMessageOpportunity <$> (value .: "draft" >>= parseDelegationDraft)
    "delegation_handoff" -> DelegationHandoffOpportunity <$> uuidField value "delegation_id"
    "delegation_take_back_preview" -> DelegationTakeBackPreviewOpportunity <$> uuidField value "delegation_id"
    "delegation_review" -> DelegationReviewScreenOpportunity <$> uuidField value "delegation_id"
    "delegation_result" -> DelegationResultOpportunity <$> uuidField value "delegation_id" <*> value .: "result"
    "external_effect_approval" -> ExternalEffectApprovalScreenOpportunity <$> uuidField value "effect_id"
    "external_effect_recovery" -> ExternalEffectRecoveryScreenOpportunity <$> uuidField value "effect_id"
    "external_effect_duplicate_risk" -> ExternalEffectDuplicateRiskOpportunity <$> uuidField value "effect_id"
    "external_effect_edit" -> ExternalEffectEditOpportunity <$> uuidField value "effect_id" <*> value .: "draft"
    "external_effect_delay" -> ExternalEffectDelayOpportunity <$> uuidField value "effect_id"
    "external_effect_result" -> ExternalEffectResultOpportunity <$> uuidField value "effect_id" <*> value .: "result"
    "work_skip_symptom" -> WorkSkipSymptomOpportunity <$> uuidField value "brick_id" <*> selectionId value
    "work_skip_reaction" -> WorkSkipReactionOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> parseSkipSymptomFields value
    "work_skip_discovery" -> WorkSkipDiscoveryOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> (value .: "node" >>= parseSkipDiscoveryNode) <*> value .: "alternate_probe"
    "work_skip_confirmation" -> WorkSkipConfirmationOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> parseSkipSymptomFields value
    "work_other_explanation" -> WorkOtherExplanationOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> value .: "draft"
    "work_other_preview" -> WorkOtherPreviewOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> value .: "explanation"
    "work_interesting" -> WorkInterestingOpportunity <$> uuidField value "brick_id" <*> selectionId value
    "work_break_nature" -> WorkBreakNatureOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> optionalSymptom value
    "work_break_draft" -> WorkBreakDraftOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> optionalSymptom value <*> optionalNature value <*> value .: "titles"
    "work_break_preview" -> WorkBreakPreviewOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> optionalSymptom value <*> optionalNature value <*> value .: "titles"
    "work_break_result" -> WorkBreakResultOpportunity <$> uuidField value "brick_id" <*> (value .: "children" >>= traverse parseUuid)
    "work_sprint_duration" -> WorkSprintDurationOpportunity <$> uuidField value "brick_id" <*> selectionId value
    "work_skip_acknowledged" ->
      WorkSkipAcknowledgedOpportunity
        <$> uuidField value "brick_id"
        <*> parseSkipSymptomFields value
        <*> (value .: "reaction" >>= parseSkipReactionName value)
    "archive_preview" -> ArchivePreviewOpportunity <$> uuidField value "brick_id" <*> selectionId value <*> optionalSymptom value
    "archive_result" -> ArchiveResultOpportunity <$> uuidField value "brick_id"
    "restore_preview" -> RestorePreviewOpportunity <$> uuidField value "brick_id"
    "restore_result" -> RestoreResultOpportunity <$> uuidField value "brick_id"
    "archive_review" -> ArchiveReviewOpportunity <$> uuidField value "brick_id" <*> uuidField value "review_id"
    "completion_result" -> CompletionResultOpportunity <$> uuidField value "brick_id"
    "repair_preview" -> RepairPreviewOpportunity <$> value .: "plan_hash" <*> value .: "source_root" <*> value .: "original_segment" <*> value .: "replacement_segment" <*> value .: "candidate_root" <*> value .: "valid_event_count"
    "repair_candidate" -> RepairCandidateOpportunity <$> value .: "repair_plan_hash" <*> value .: "cutover_plan_hash" <*> value .: "source_root" <*> value .: "candidate_root" <*> value .: "backup_root" <*> value .: "candidate_cursor" <*> value .: "candidate_event_count"
    "repair_complete" -> RepairCompleteOpportunity <$> value .: "cutover_plan_hash" <*> value .: "backup_root" <*> value .: "recovered"
    _ -> fail "unknown opportunity type"
 where
  selectionId value = value .:? "selection_id" >>= traverse parseUuid
  optionalSymptom value = do
    present <- value .:? "symptom" :: Parser (Maybe Text)
    traverse (const (parseSkipSymptomFields value)) present
  optionalNature value = value .:? "target_nature" >>= traverse parseNature

translationScopeValue :: TranslationScope -> Value
translationScopeValue scope = object ["titles" .= translationScopeTitles scope, "raws" .= translationScopeRaws scope, "archived" .= translationScopeArchived scope]

parseTranslationScope :: Value -> Parser TranslationScope
parseTranslationScope = withObject "TranslationScope" $ \value -> TranslationScope <$> value .: "titles" <*> value .: "raws" <*> value .: "archived"

translationCandidateValue :: TranslationCandidate -> Value
translationCandidateValue = \case
  TranslationBrickTitle identity -> object ["kind" .= ("brick_title" :: Text), "brick_id" .= renderUUIDv7 identity]
  TranslationRawRevision rawIdentity revisionIdentity -> object ["kind" .= ("raw_revision" :: Text), "raw_id" .= renderUUIDv7 rawIdentity, "revision_id" .= renderUUIDv7 revisionIdentity]

parseTranslationCandidate :: Value -> Parser TranslationCandidate
parseTranslationCandidate = withObject "TranslationCandidate" $ \value ->
  value .: "kind" >>= \case
    ("brick_title" :: Text) -> TranslationBrickTitle <$> uuidField value "brick_id"
    "raw_revision" -> TranslationRawRevision <$> uuidField value "raw_id" <*> uuidField value "revision_id"
    _ -> fail "unknown translation candidate kind"

translationQueueValue :: TranslationQueue -> Value
translationQueueValue queue =
  object
    [ "scope" .= translationScopeValue (translationQueueScope queue)
    , "remaining" .= fmap translationCandidateValue (translationQueueRemaining queue)
    , "accepted" .= translationQueueAccepted queue
    , "skipped" .= translationQueueSkipped queue
    , "total" .= translationQueueTotal queue
    ]

parseTranslationQueue :: Value -> Parser TranslationQueue
parseTranslationQueue = withObject "TranslationQueue" $ \value ->
  TranslationQueue
    <$> (value .: "scope" >>= parseTranslationScope)
    <*> (value .: "remaining" >>= traverse parseTranslationCandidate)
    <*> value .: "accepted"
    <*> value .: "skipped"
    <*> value .: "total"

sourceChoiceName :: SourceReconciliationChoice -> Text
sourceChoiceName = \case ReconcileSameRaw -> "same_raw"; ReconcileDerivedRaw -> "derived_raw"; ReconcileUnrelated -> "unrelated"

parseSourceChoice :: Text -> Parser SourceReconciliationChoice
parseSourceChoice = \case "same_raw" -> pure ReconcileSameRaw; "derived_raw" -> pure ReconcileDerivedRaw; "unrelated" -> pure ReconcileUnrelated; _ -> fail "unknown source reconciliation choice"

parseSourceLifecycleLabel :: Text -> Parser SourceBindingLifecycle
parseSourceLifecycleLabel = \case "active" -> pure SourceBindingActive; "paused" -> pure SourceBindingPaused; "detached" -> pure SourceBindingDetached; _ -> fail "unknown source binding lifecycle"

normalizationSourceName :: NormalizationSource -> Text
normalizationSourceName = \case
  HumanNormalization -> "human"
  PoweredUpNormalization -> "powered_up"
  SkillNormalization -> "skill"
  ImportNormalization -> "import"

parseNormalizationSourceName :: Text -> Parser NormalizationSource
parseNormalizationSourceName = \case
  "human" -> pure HumanNormalization
  "powered_up" -> pure PoweredUpNormalization
  "skill" -> pure SkillNormalization
  "import" -> pure ImportNormalization
  _ -> fail "unknown normalization source"

noticeIdentityValue :: NoticeIdentity -> Value
noticeIdentityValue notice =
  object
    [ "subject" .= renderUUIDv7 (noticeSubject notice)
    , "fact_revision" .= noticeFactRevision notice
    , "kind" .= noticeKindText (noticeKind notice)
    , "threshold" .= noticeThreshold notice
    ]

parseNoticeIdentity :: Value -> Parser NoticeIdentity
parseNoticeIdentity = withObject "NoticeIdentity" $ \value ->
  NoticeIdentity
    <$> uuidField value "subject"
    <*> value .: "fact_revision"
    <*> (value .: "kind" >>= parseNoticeKind)
    <*> value .: "threshold"

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
  other -> fail ("unknown notice kind: " <> Text.unpack other)

domainFocusModeName :: DomainFocusMode -> Text
domainFocusModeName = \case
  OneSuggestion -> "one_suggestion"
  StayWithin -> "stay_within"
  PreferDomain -> "prefer"

domainFocusModeLabel :: DomainFocusMode -> Text
domainFocusModeLabel = \case
  OneSuggestion -> "One suggestion only"
  StayWithin -> "Stay within this Domain"
  PreferDomain -> "Prefer this Domain"

parseDomainFocusMode :: Text -> Parser DomainFocusMode
parseDomainFocusMode = \case
  "one_suggestion" -> pure OneSuggestion
  "stay_within" -> pure StayWithin
  "prefer" -> pure PreferDomain
  _ -> fail "unknown Domain focus mode"

interactionReturnPolicyValue :: ReturnPolicy -> Value
interactionReturnPolicyValue = \case
  ManualOnlyReturn -> object ["kind" .= ("manual_only" :: Text)]
  AfterCompletionReturn center unit variation zone -> object ["kind" .= ("after_completion" :: Text), "center" .= center, "unit" .= returnUnitName unit, "variation" .= variation, "zone" .= zone]

parseInteractionReturnPolicy :: Value -> Parser ReturnPolicy
parseInteractionReturnPolicy = withObject "interaction return policy" $ \value ->
  value .: "kind" >>= \case
    ("manual_only" :: Text) -> pure ManualOnlyReturn
    "after_completion" -> AfterCompletionReturn <$> value .: "center" <*> (value .: "unit" >>= parseInteractionReturnUnit) <*> value .: "variation" <*> value .: "zone"
    _ -> fail "unknown interaction return policy"

parseInteractionReturnUnit :: Text -> Parser ReturnUnit
parseInteractionReturnUnit = \case
  "days" -> pure ReturnDays
  "weeks" -> pure ReturnWeeks
  "months" -> pure ReturnMonths
  "years" -> pure ReturnYears
  _ -> fail "unknown interaction return unit"

interactionZonedInstantValue :: ZonedInstant -> Value
interactionZonedInstantValue instant = object ["utc" .= zonedInstantUtc instant, "zone" .= zonedInstantZone instant]

parseInteractionZonedInstant :: Value -> Parser ZonedInstant
parseInteractionZonedInstant = withObject "interaction ZonedInstant" $ \value -> ZonedInstant <$> value .: "utc" <*> value .: "zone"

parseInteractionSeed :: Text -> Parser ByteString
parseInteractionSeed encoded =
  case Base16.decode (TextEncoding.encodeUtf8 encoded) of
    Right seed | ByteString.length seed == 32 -> pure seed
    _ -> fail "invalid interaction random seed"

parseInteractionScheduledOutcome :: Text -> Parser StandingOutcomeKind
parseInteractionScheduledOutcome = \case
  "Attended" -> pure StandingAttended
  "Missed" -> pure StandingMissed
  "Cancelled" -> pure StandingCancelled
  _ -> fail "unknown scheduled-commitment outcome"

orderSessionValue :: OrderSession -> Value
orderSessionValue session =
  object
    [ "scope" .= orderScopeValue (orderSessionScope session)
    , "groups" .= fmap parentValue (orderSessionGroups session)
    , "group_index" .= orderSessionGroupIndex session
    , "comparisons" .= orderSessionComparisons session
    , "cadence" .= cadenceText (orderSessionCadence session)
    ]
 where
  parentValue = maybe (String "root") (String . renderUUIDv7)

parseOrderSession :: Value -> Parser OrderSession
parseOrderSession = withObject "OrderSession" $ \value ->
  OrderSession
    <$> (value .: "scope" >>= parseOrderScope)
    <*> (value .: "groups" >>= traverse parseParent)
    <*> value .: "group_index"
    <*> value .: "comparisons"
    <*> (value .: "cadence" >>= parseCadence)
 where
  parseParent = withText "order parent" $ \case
    "root" -> pure Nothing
    identity -> Just <$> parseUuid identity

orderScopeValue :: OrderScope -> Value
orderScopeValue = \case
  AllSiblingGroups -> object ["type" .= ("all" :: Text)]
  OneSiblingGroup parent -> object $ ["type" .= ("group" :: Text)] <> maybe [] (pure . ("parent_id" .=) . renderUUIDv7) parent
  DomainSiblingGroups identity -> object ["type" .= ("domain" :: Text), "domain_id" .= renderUUIDv7 identity]

parseOrderScope :: Value -> Parser OrderScope
parseOrderScope = withObject "OrderScope" $ \value ->
  value .: "type" >>= \case
    ("all" :: Text) -> pure AllSiblingGroups
    "group" -> OneSiblingGroup <$> (value .:? "parent_id" >>= traverse parseUuid)
    "domain" -> DomainSiblingGroups <$> uuidField value "domain_id"
    other -> fail ("unknown order scope: " <> Text.unpack other)

cadenceText :: OrderCadence -> Text
cadenceText = \case LotteryOrder -> "lottery"; ContinuousOrder -> "continuous"

parseCadence :: Text -> Parser OrderCadence
parseCadence = \case
  "lottery" -> pure LotteryOrder
  "continuous" -> pure ContinuousOrder
  other -> fail ("unknown order cadence: " <> Text.unpack other)

importanceNodeText :: ImportanceDiscoveryNode -> Text
importanceNodeText = \case
  UnderstandFirstResult -> "understand_first"
  InspectFirstContext -> "inspect_first"
  UnderstandSecondResult -> "understand_second"
  InspectSecondContext -> "inspect_second"
  ChooseFirstForever -> "choose_first"
  ChooseSecondForever -> "choose_second"
  AcceptEitherOrder -> "either_order"
  SeekNewEvidence -> "new_evidence"
  TryNearbySibling -> "nearby"

parseImportanceNode :: Text -> Parser ImportanceDiscoveryNode
parseImportanceNode value = maybe (fail ("unknown importance discovery node: " <> Text.unpack value)) pure (lookup value table)
 where
  table = [(importanceNodeText node, node) | node <- [minBound .. maxBound]]

impactClassText :: ImpactClass -> Text
impactClassText = \case
  VeryLowImpact -> "very_low"
  LowImpact -> "low"
  MediumImpact -> "medium"
  HighImpact -> "high"
  VeryHighImpact -> "very_high"
  CriticalImpact -> "critical"

parseImpactClassText :: Text -> Parser ImpactClass
parseImpactClassText value = maybe (fail ("unknown Impact class: " <> Text.unpack value)) pure (lookup value table)
 where
  table = [(impactClassText impact, impact) | impact <- [minBound .. maxBound]]

impactMaturityQuestionText :: ImpactMaturityQuestion -> Text
impactMaturityQuestionText = \case
  ObservedResultQuestion -> "observed_result"
  RepresentativeTestQuestion -> "representative_test"
  RelevantSupportQuestion -> "relevant_support"

parseImpactMaturityQuestion :: Text -> Parser ImpactMaturityQuestion
parseImpactMaturityQuestion = \case
  "observed_result" -> pure ObservedResultQuestion
  "representative_test" -> pure RepresentativeTestQuestion
  "relevant_support" -> pure RelevantSupportQuestion
  other -> fail ("unknown Impact maturity question: " <> Text.unpack other)

impactMaturityTextValue :: ImpactMaturity -> Text
impactMaturityTextValue = \case
  SpeculativeImpact -> "speculative"
  SupportedImpact -> "supported"
  ValidatedImpact -> "validated"
  ObservedImpact -> "observed"

parseImpactMaturityTextValue :: Text -> Parser ImpactMaturity
parseImpactMaturityTextValue = \case
  "speculative" -> pure SpeculativeImpact
  "supported" -> pure SupportedImpact
  "validated" -> pure ValidatedImpact
  "observed" -> pure ObservedImpact
  other -> fail ("unknown Impact maturity: " <> Text.unpack other)

effortClassTextValue :: EffortClass -> Text
effortClassTextValue = \case
  VeryEasyEffort -> "very_easy"
  EasyEffort -> "easy"
  NormalEffort -> "normal"
  ModerateEffort -> "moderate"
  HardEffort -> "hard"
  VeryHardEffort -> "very_hard"
  MiniProjectEffort -> "mini_project"
  ProjectEffort -> "project"

parseEffortClassTextValue :: Text -> Parser EffortClass
parseEffortClassTextValue value = maybe (fail ("unknown Effort class: " <> Text.unpack value)) pure (lookup value table)
 where
  table = [(effortClassTextValue effort, effort) | effort <- [minBound .. maxBound]]

judgmentRelationText :: JudgmentRelation -> Text
judgmentRelationText = \case
  MoreThan -> "more_than"
  EitherOrder -> "either_order"
  AboutSame -> "about_same"

parseJudgmentRelationText :: Text -> Parser JudgmentRelation
parseJudgmentRelationText = \case
  "more_than" -> pure MoreThan
  "either_order" -> pure EitherOrder
  "about_same" -> pure AboutSame
  other -> fail ("unknown judgment relation: " <> Text.unpack other)

judgmentAxisText :: JudgmentAxis -> Text
judgmentAxisText = \case ImportanceAxis -> "importance"; ImpactAxis -> "impact"; EffortAxis -> "effort"

parseJudgmentAxisText :: Text -> Parser JudgmentAxis
parseJudgmentAxisText = \case
  "importance" -> pure ImportanceAxis
  "impact" -> pure ImpactAxis
  "effort" -> pure EffortAxis
  other -> fail ("unknown judgment axis: " <> Text.unpack other)
discoveryValue :: NatureDiscovery -> Value
discoveryValue discovery = object ["question" .= questionText (discoveryQuestion discovery), "alternate_probe" .= discoveryAlternateProbe discovery, "history" .= fmap questionText (discoveryHistory discovery)]

parseDiscovery :: Value -> Parser NatureDiscovery
parseDiscovery = withObject "NatureDiscovery" $ \value -> NatureDiscovery <$> (value .: "question" >>= parseQuestion) <*> value .: "alternate_probe" <*> (value .: "history" >>= traverse parseQuestion)

questionText :: NatureQuestion -> Text
questionText = \case
  FixedTimeQuestion -> "fixed_time"
  FiniteIntentionQuestion -> "finite_intention"
  MultipartQuestion -> "multipart"
  IndependentPartsQuestion -> "independent_parts"
  ChangingMembersQuestion -> "changing_members"
  IndependentMemberQuestion -> "independent_member"
  OpenOccurrenceQuestion -> "open_occurrence"
  StreakQuestion -> "streak"

parseQuestion :: Text -> Parser NatureQuestion
parseQuestion = \case
  "fixed_time" -> pure FixedTimeQuestion
  "finite_intention" -> pure FiniteIntentionQuestion
  "multipart" -> pure MultipartQuestion
  "independent_parts" -> pure IndependentPartsQuestion
  "changing_members" -> pure ChangingMembersQuestion
  "independent_member" -> pure IndependentMemberQuestion
  "open_occurrence" -> pure OpenOccurrenceQuestion
  "streak" -> pure StreakQuestion
  other -> fail ("unknown Nature question: " <> Text.unpack other)

natureText :: BrickNature -> Text
natureText = natureIdentifier

parseNature :: Text -> Parser BrickNature
parseNature identifier = maybe (fail ("unknown Nature: " <> Text.unpack identifier)) (pure . natureValue) (firstWhere ((== identifier) . natureDefinitionId) factoryNatures)

templateSelectionValue :: TemplateSelection -> Value
templateSelectionValue selected = object ["id" .= templateIdentifier selected, "catalog_version" .= templateCatalogVersion selected, "source" .= templateSource selected]

parseTemplateSelection :: Value -> Parser TemplateSelection
parseTemplateSelection = withObject "TemplateSelection" $ \value -> TemplateSelection <$> value .: "id" <*> value .: "catalog_version" <*> value .: "source"

workDraftValue :: WorkDraft -> Value
workContextValue :: WorkContext -> Value
workContextValue context =
  object $
    [ "raw_id" .= renderUUIDv7 (workContextRawId context)
    , "domains" .= fmap renderUUIDv7 (Set.toAscList (workContextDomains context))
    ]
      <> maybe [] (pure . ("parent_id" .=) . renderUUIDv7) (workContextParent context)

parseWorkContext :: Value -> Parser WorkContext
parseWorkContext = withObject "WorkContext" $ \value ->
  WorkContext
    <$> uuidField value "raw_id"
    <*> (value .:? "parent_id" >>= traverse parseUuid)
    <*> (Set.fromList <$> (value .: "domains" >>= traverse parseUuid))

entityPurposeText :: EntitySelectionPurpose -> Text
entityPurposeText = \case
  WaitTargetPurpose -> "wait_target"
  DelegationTargetPurpose -> "delegation_target"

parseEntityPurpose :: Text -> Parser EntitySelectionPurpose
parseEntityPurpose = \case
  "wait_target" -> pure WaitTargetPurpose
  "delegation_target" -> pure DelegationTargetPurpose
  other -> fail ("unknown entity selection purpose: " <> Text.unpack other)

externalEntityKindName :: ExternalEntityKind -> Text
externalEntityKindName = \case
  PersonEntity -> "person"
  TeamEntity -> "team"
  OrganizationEntity -> "organization"
  AIAgentEntity -> "ai_agent"
  ServiceEntity -> "service"

parseExternalEntityKindName :: Text -> Parser ExternalEntityKind
parseExternalEntityKindName = \case
  "person" -> pure PersonEntity
  "team" -> pure TeamEntity
  "organization" -> pure OrganizationEntity
  "ai_agent" -> pure AIAgentEntity
  "service" -> pure ServiceEntity
  other -> fail ("unknown person or company kind: " <> Text.unpack other)

interactionWaitKindValue :: WaitKind -> Value
interactionWaitKindValue = \case
  HumanResponseWait entityId -> object ["kind" .= ("human_response" :: Text), "entity_id" .= renderUUIDv7 entityId]
  ExternalConditionWait condition -> object ["kind" .= ("external_condition" :: Text), "condition" .= condition]

parseInteractionWaitKind :: Value -> Parser WaitKind
parseInteractionWaitKind = withObject "WaitKind" $ \value ->
  (value .: "kind" :: Parser Text) >>= \case
    "human_response" -> HumanResponseWait <$> uuidField value "entity_id"
    "external_condition" -> ExternalConditionWait <$> value .: "condition"
    other -> fail ("unknown Wait kind: " <> Text.unpack other)

delegationDraftValue :: DelegationDraft -> Value
delegationDraftValue draft =
  object
    ( [ "brick_id" .= renderUUIDv7 (delegationDraftBrick draft)
      , "target_id" .= renderUUIDv7 (delegationDraftTarget draft)
      , "message" .= delegationDraftMessage draft
      ]
        <> maybe [] (pure . ("selection_id" .=) . renderUUIDv7) (delegationDraftSelection draft)
        <> maybe [] (pure . ("scope" .=) . delegationScopeName) (delegationDraftScope draft)
        <> maybe [] (pure . ("policy" .=) . followUpPolicyName) (delegationDraftPolicy draft)
        <> maybe [] (pure . ("review_delay_seconds" .=)) (delegationDraftReviewDelaySeconds draft)
    )

parseDelegationDraft :: Value -> Parser DelegationDraft
parseDelegationDraft = withObject "DelegationDraft" $ \value ->
  DelegationDraft
    <$> uuidField value "brick_id"
    <*> (value .:? "selection_id" >>= traverse parseUuid)
    <*> uuidField value "target_id"
    <*> (value .:? "scope" >>= traverse parseDelegationScopeName)
    <*> (value .:? "policy" >>= traverse parseFollowUpPolicyName)
    <*> value .:? "review_delay_seconds"
    <*> value .: "message"

delegationScopeName :: DelegationScope -> Text
delegationScopeName = \case BrickOnlyDelegation -> "brick_only"; WholeScopeDelegation -> "whole_scope"

parseDelegationScopeName :: Text -> Parser DelegationScope
parseDelegationScopeName = \case
  "brick_only" -> pure BrickOnlyDelegation
  "whole_scope" -> pure WholeScopeDelegation
  other -> fail ("unknown Delegation scope: " <> Text.unpack other)

followUpPolicyName :: FollowUpPolicy -> Text
followUpPolicyName = \case FollowUpOnce -> "once"; FollowUpEvery -> "every"; FollowUpNone -> "none"

parseFollowUpPolicyName :: Text -> Parser FollowUpPolicy
parseFollowUpPolicyName = \case
  "once" -> pure FollowUpOnce
  "every" -> pure FollowUpEvery
  "none" -> pure FollowUpNone
  other -> fail ("unknown Delegation follow-up policy: " <> Text.unpack other)

workDraftValue draft =
  object $
    [ "raw_id" .= renderUUIDv7 (workDraftRawId draft)
    , "title" .= workDraftTitle draft
    , "nature" .= natureText (workDraftNature draft)
    , "domains" .= fmap renderUUIDv7 (Set.toAscList (workDraftDomains draft))
    , "sibling_position" .= workDraftSiblingPosition draft
    , "importance_confidence" .= confidenceValue (workDraftImportanceConfidence draft)
    , "comparisons" .= fmap comparisonValue (workDraftComparisons draft)
    ]
      <> maybe [] (pure . ("template" .=) . templateSelectionValue) (workDraftTemplate draft)
      <> maybe [] (pure . ("parent_id" .=) . renderUUIDv7) (workDraftParent draft)

parseWorkDraft :: Value -> Parser WorkDraft
parseWorkDraft = withObject "WorkDraft" $ \value ->
  WorkDraft
    <$> uuidField value "raw_id"
    <*> value .: "title"
    <*> (value .: "nature" >>= parseNature)
    <*> (value .:? "template" >>= traverse parseTemplateSelection)
    <*> (value .:? "parent_id" >>= traverse parseUuid)
    <*> (Set.fromList <$> (value .: "domains" >>= traverse parseUuid))
    <*> value .: "sibling_position"
    <*> (value .: "importance_confidence" >>= parseConfidence)
    <*> (value .: "comparisons" >>= traverse parseComparison)

quantityValue :: Quantity -> Value
quantityValue quantity = object ["coefficient" .= quantityCoefficient quantity, "scale" .= quantityScale quantity, "unit" .= quantityUnit quantity]

parseQuantity :: Value -> Parser Quantity
parseQuantity = withObject "Quantity" $ \value -> Quantity <$> value .: "coefficient" <*> value .: "scale" <*> value .: "unit"

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
    other -> fail ("unknown confidence: " <> Text.unpack other)

comparisonValue :: DraftImportanceAnswer -> Value
comparisonValue = \case
  DraftAbove identity -> object ["direction" .= ("above" :: Text), "brick_id" .= renderUUIDv7 identity]
  DraftBelow identity -> object ["direction" .= ("below" :: Text), "brick_id" .= renderUUIDv7 identity]

parseComparison :: Value -> Parser DraftImportanceAnswer
parseComparison = withObject "DraftImportanceAnswer" $ \value -> do
  identity <- uuidField value "brick_id"
  value .: "direction" >>= \case
    ("above" :: Text) -> pure (DraftAbove identity)
    "below" -> pure (DraftBelow identity)
    other -> fail ("unknown draft comparison: " <> Text.unpack other)

uuidField :: Object -> Key -> Parser UUIDv7
uuidField value key = value .: key >>= parseUuid

parseUuid :: Text -> Parser UUIDv7
parseUuid = either (fail . Text.unpack) pure . parseUUIDv7

instance ToJSON EnvelopeContent where
  toJSON content = object $ ["heading" .= contentHeading content, "body" .= contentBody content] <> maybe [] (pure . ("subject" .=)) (contentSubject content) <> maybe [] (pure . ("question" .=)) (contentQuestion content)
instance FromJSON EnvelopeContent where
  parseJSON = withObject "EnvelopeContent" $ \value -> EnvelopeContent <$> value .: "heading" <*> value .:? "subject" <*> value .: "body" <*> value .:? "question"

instance ToJSON Action where
  toJSON action = object ["id" .= actionId action, "label" .= actionLabel action, "shortcut" .= actionShortcut action, "default" .= actionDefault action, "consequence" .= actionConsequence action]
instance FromJSON Action where
  parseJSON = withObject "Action" $ \value -> Action <$> value .: "id" <*> value .: "label" <*> value .: "shortcut" <*> value .: "default" <*> value .: "consequence"

instance ToJSON CommandOption where
  toJSON command = object ["id" .= commandOptionId command, "command" .= commandOptionCommand command, "description" .= commandOptionDescription command]
instance FromJSON CommandOption where
  parseJSON = withObject "CommandOption" $ \value -> CommandOption <$> value .: "id" <*> value .: "command" <*> value .: "description"

instance ToJSON Footer where
  toJSON footer =
    object $
      ["parent" .= footerParent footer, "domain" .= footerDomain footer, "time_label" .= footerTimeLabel footer, "time_value" .= footerTimeValue footer, "now" .= footerNow footer, "bricks" .= footerBrickCount footer, "raws" .= footerRawCount footer, "reviews" .= footerReviewCount footer, "mode" .= footerMode footer, "focus" .= footerFocus footer]
        <> maybe [] (pure . ("notice" .=)) (footerNotice footer)
        <> ["notice_count" .= footerNoticeCount footer | footerNoticeCount footer > 0]
instance FromJSON Footer where
  parseJSON = withObject "Footer" $ \value -> Footer <$> value .: "parent" <*> value .: "domain" <*> value .: "time_label" <*> value .: "time_value" <*> value .: "now" <*> value .: "bricks" <*> value .: "raws" <*> value .: "reviews" <*> value .: "mode" <*> value .: "focus" <*> value .:? "notice" <*> (value .:? "notice_count" .!= 0)

instance ToJSON InteractionEnvelope where
  toJSON envelope = case unsignedEnvelopeValue envelope of
    Object fields -> Object (KeyMap.insert "integrity_token" (toJSON (envelopeIntegrityToken envelope)) fields)
    other -> other
instance FromJSON InteractionEnvelope where
  parseJSON = withObject "InteractionEnvelope" $ \value -> InteractionEnvelope <$> (value .: "interaction_id" >>= parseUuid) <*> value .: "revision" <*> value .: "dataset_cursor" <*> value .: "precondition_hash" <*> value .: "grammar" <*> value .: "opportunity" <*> value .: "content" <*> value .: "actions" <*> value .: "commands" <*> value .:? "uncertainty_route" <*> value .: "context" <*> (value .:? "notice_turn" .!= 0) <*> value .: "provenance" <*> value .: "integrity_token"

firstWhere :: (value -> Bool) -> [value] -> Maybe value
firstWhere _ [] = Nothing
firstWhere predicate (value : rest)
  | predicate value = Just value
  | otherwise = firstWhere predicate rest

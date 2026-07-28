{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Canonical Little Ant 1.0 domain vocabulary and definition catalog.
--
-- Entity identity is allocated from one domain-wide sequence and is never
-- derived from mutable human text. Published behavior and template versions
-- are immutable values: catalog updates only add a new version or return an
-- existing semantically equivalent behavior.
module LittleAnt.V1.Domain
  ( Applicability (..)
  , Atomicity (..)
  , Authority (..)
  , BehaviorConfiguration (..)
  , BehaviorDraft (..)
  , Brick (..)
  , BrickBehavior (..)
  , BrickClosure (..)
  , BrickDraft (..)
  , BrickId (..)
  , BrickPhase (..)
  , BrickStatus (..)
  , BrickTemplate (..)
  , CanonicalText (..)
  , DecompositionCoverage (..)
  , DefinitionCatalog
  , DefinitionKey (..)
  , DomainError (..)
  , DomainState (..)
  , EntityRevision (..)
  , FocusRegister (..)
  , FocusUnit (..)
  , Lifetime (..)
  , ListEntry (..)
  , ListEntryDraft (..)
  , ListEntryId (..)
  , ListEntryStatus (..)
  , Mode (..)
  , Party (..)
  , PartyId (..)
  , PartyType (..)
  , PublicationResult (..)
  , RepetitionKind (..)
  , TemplateDraft (..)
  , WorkState (..)
  , addAlternatePartyLabel
  , behaviorConfiguration
  , behaviorConfigurationValid
  , behaviorVersions
  , brickProjection
  , canonicalEnglishText
  , catalogContainsBehavior
  , collectionV1
  , createBrick
  , createListEntry
  , createParty
  , clearBrickAbout
  , clearBrickBestBefore
  , clearBrickContext
  , clearBrickDeadline
  , clearBrickDescription
  , clearBrickMode
  , clearBrickNotBefore
  , clearBrickOriginalTitle
  , clearBrickPhase
  , clearBrickRequester
  , closeBrickSubtree
  , describeBrick
  , domainProjection
  , effectiveBestBefore
  , effectiveContext
  , effectiveDateRevision
  , effectiveDeadline
  , effectiveMode
  , effectiveNotBefore
  , emptyDomainState
  , findBehaviors
  , findTemplates
  , finiteChecklistV1
  , focusBrick
  , initialDefinitionCatalog
  , instantiateTemplate
  , listEntryProjection
  , mkCanonicalText
  , ordinaryBrickDraft
  , partyProjection
  , moveBrickSubtree
  , practiceV1
  , projectV1
  , publishPersonalBehavior
  , publishPersonalTemplate
  , recurringObligationV1
  , renameBrick
  , renameParty
  , repeatableV1
  , retireStandingBrick
  , returnBrickToIdle
  , removeListEntry
  , resolveListEntry
  , setBrickAbout
  , setBrickBestBefore
  , setBrickContext
  , setBrickDeadline
  , setBrickMode
  , setBrickNotBefore
  , setBrickOriginalTitle
  , setBrickParent
  , setBrickPhase
  , setBrickRequester
  , setBrickWorkState
  , standardV1
  , standingChecklistV1
  , subtreeBricks
  , supersedeBrickWithChildren
  , templateVersions
  , transitionBrickStatus
  , unfocusCurrentBrick
  , validateDomainState
  ) where

import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey,
   Value (..), defaultOptions, genericParseJSON, object, withObject, withText,
   (.:), (.=))
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy as LBS
import Data.Char (isControl)
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.List (find, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (catMaybes, isJust, mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Text.Read (readMaybe)

------------------------------------------------------------
-- Closed vocabulary
------------------------------------------------------------

data Authority = Human | Ai | Adapter | Core
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data PartyType = Person | AiAgent | Company | Area
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data BrickStatus = Active | Done | Dropped | Superseded
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data BrickPhase = Idea | Spec | Exec | Validation
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data WorkState = Idle | Wip
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data Atomicity = Atomic | Divisible | Unknown
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data Mode = Digital | Physical | Hybrid | Any
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data DecompositionCoverage = NotApplicable | Open | Complete
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data FocusUnit = BrickFocus | ChildrenFocus | BatchFocus
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data Lifetime = Finite | Standing
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data Applicability = Applicable | Disabled
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data RepetitionKind
  = NoRepetition
  | CompletionTriggered
  | RecurringObligation
  | Practice
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ListEntryStatus = EntryOpen | EntryResolved | EntryRemoved
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON Authority where toJSON = enumJSON authorityText
instance FromJSON Authority where parseJSON = parseEnumJSON "Authority" authorityValues
instance ToJSON PartyType where toJSON = enumJSON partyTypeText
instance FromJSON PartyType where parseJSON = parseEnumJSON "PartyType" partyTypeValues
instance ToJSON BrickStatus where toJSON = enumJSON brickStatusText
instance FromJSON BrickStatus where parseJSON = parseEnumJSON "BrickStatus" brickStatusValues
instance ToJSON BrickPhase where toJSON = enumJSON brickPhaseText
instance FromJSON BrickPhase where parseJSON = parseEnumJSON "BrickPhase" brickPhaseValues
instance ToJSON WorkState where toJSON = enumJSON workStateText
instance FromJSON WorkState where parseJSON = parseEnumJSON "WorkState" workStateValues
instance ToJSON Atomicity where toJSON = enumJSON atomicityText
instance FromJSON Atomicity where parseJSON = parseEnumJSON "Atomicity" atomicityValues
instance ToJSON Mode where toJSON = enumJSON modeText
instance FromJSON Mode where parseJSON = parseEnumJSON "Mode" modeValues
instance ToJSON DecompositionCoverage where toJSON = enumJSON decompositionText
instance FromJSON DecompositionCoverage where parseJSON = parseEnumJSON "DecompositionCoverage" decompositionValues
instance ToJSON FocusUnit where toJSON = enumJSON focusUnitText
instance FromJSON FocusUnit where parseJSON = parseEnumJSON "FocusUnit" focusUnitValues
instance ToJSON Lifetime where toJSON = enumJSON lifetimeText
instance FromJSON Lifetime where parseJSON = parseEnumJSON "Lifetime" lifetimeValues
instance ToJSON Applicability where toJSON = enumJSON applicabilityText
instance FromJSON Applicability where parseJSON = parseEnumJSON "Applicability" applicabilityValues
instance ToJSON RepetitionKind where toJSON = enumJSON repetitionText
instance FromJSON RepetitionKind where parseJSON = parseEnumJSON "RepetitionKind" repetitionValues
instance ToJSON ListEntryStatus where toJSON = enumJSON listEntryStatusText
instance FromJSON ListEntryStatus where parseJSON = parseEnumJSON "ListEntryStatus" listEntryStatusValues

enumJSON :: (value -> Text) -> value -> Value
enumJSON render = String . render

parseEnumJSON :: String -> [(Text, value)] -> Value -> AesonTypes.Parser value
parseEnumJSON name values = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate values)

authorityText :: Authority -> Text
authorityText value = case value of
  Human -> "human"
  Ai -> "ai"
  Adapter -> "adapter"
  Core -> "core"

authorityValues :: [(Text, Authority)]
authorityValues = [(authorityText value, value) | value <- [minBound .. maxBound]]

partyTypeText :: PartyType -> Text
partyTypeText value = case value of
  Person -> "person"
  AiAgent -> "ai_agent"
  Company -> "company"
  Area -> "area"

partyTypeValues :: [(Text, PartyType)]
partyTypeValues = [(partyTypeText value, value) | value <- [minBound .. maxBound]]

brickStatusText :: BrickStatus -> Text
brickStatusText value = case value of
  Active -> "active"
  Done -> "done"
  Dropped -> "dropped"
  Superseded -> "superseded"

brickStatusValues :: [(Text, BrickStatus)]
brickStatusValues = [(brickStatusText value, value) | value <- [minBound .. maxBound]]

brickPhaseText :: BrickPhase -> Text
brickPhaseText value = case value of
  Idea -> "idea"
  Spec -> "spec"
  Exec -> "exec"
  Validation -> "validation"

brickPhaseValues :: [(Text, BrickPhase)]
brickPhaseValues = [(brickPhaseText value, value) | value <- [minBound .. maxBound]]

workStateText :: WorkState -> Text
workStateText value = case value of
  Idle -> "idle"
  Wip -> "wip"

workStateValues :: [(Text, WorkState)]
workStateValues = [(workStateText value, value) | value <- [minBound .. maxBound]]

atomicityText :: Atomicity -> Text
atomicityText value = case value of
  Atomic -> "atomic"
  Divisible -> "divisible"
  Unknown -> "unknown"

atomicityValues :: [(Text, Atomicity)]
atomicityValues = [(atomicityText value, value) | value <- [minBound .. maxBound]]

modeText :: Mode -> Text
modeText value = case value of
  Digital -> "digital"
  Physical -> "physical"
  Hybrid -> "hybrid"
  Any -> "any"

modeValues :: [(Text, Mode)]
modeValues = [(modeText value, value) | value <- [minBound .. maxBound]]

decompositionText :: DecompositionCoverage -> Text
decompositionText value = case value of
  NotApplicable -> "not_applicable"
  Open -> "open"
  Complete -> "complete"

decompositionValues :: [(Text, DecompositionCoverage)]
decompositionValues = [(decompositionText value, value) | value <- [minBound .. maxBound]]

focusUnitText :: FocusUnit -> Text
focusUnitText value = case value of
  BrickFocus -> "brick"
  ChildrenFocus -> "children"
  BatchFocus -> "batch"

focusUnitValues :: [(Text, FocusUnit)]
focusUnitValues = [(focusUnitText value, value) | value <- [minBound .. maxBound]]

lifetimeText :: Lifetime -> Text
lifetimeText value = case value of
  Finite -> "finite"
  Standing -> "standing"

lifetimeValues :: [(Text, Lifetime)]
lifetimeValues = [(lifetimeText value, value) | value <- [minBound .. maxBound]]

applicabilityText :: Applicability -> Text
applicabilityText value = case value of
  Applicable -> "applicable"
  Disabled -> "disabled"

applicabilityValues :: [(Text, Applicability)]
applicabilityValues = [(applicabilityText value, value) | value <- [minBound .. maxBound]]

repetitionText :: RepetitionKind -> Text
repetitionText value = case value of
  NoRepetition -> "none"
  CompletionTriggered -> "completion_triggered"
  RecurringObligation -> "recurring_obligation"
  Practice -> "practice"

repetitionValues :: [(Text, RepetitionKind)]
repetitionValues = [(repetitionText value, value) | value <- [minBound .. maxBound]]

listEntryStatusText :: ListEntryStatus -> Text
listEntryStatusText value = case value of
  EntryOpen -> "open"
  EntryResolved -> "resolved"
  EntryRemoved -> "removed"

listEntryStatusValues :: [(Text, ListEntryStatus)]
listEntryStatusValues = [(listEntryStatusText value, value) | value <- [minBound .. maxBound]]

------------------------------------------------------------
-- Identity and entities
------------------------------------------------------------

newtype EntityRevision = EntityRevision { unEntityRevision :: Integer }
  deriving stock (Eq, Ord, Show, Generic)

newtype PartyId = PartyId { unPartyId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

newtype BrickId = BrickId { unBrickId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

newtype ListEntryId = ListEntryId { unListEntryId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

instance ToJSON EntityRevision where toJSON = toJSON . unEntityRevision
instance FromJSON EntityRevision where parseJSON value = EntityRevision <$> parseJSON value

data CanonicalText = CanonicalText
  { canonicalTextEnglish :: Text
  , canonicalTextOriginal :: Maybe Text
  , canonicalTextAuthority :: Authority
  }
  deriving stock (Eq, Show, Generic)

data Party = Party
  { partyId :: PartyId
  , partyRevision :: EntityRevision
  , partyLabel :: Text
  , partyType :: PartyType
  , partyAlternateLabels :: [Text]
  , partyCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data BehaviorConfiguration = BehaviorConfiguration
  { configurationFocusUnit :: FocusUnit
  , configurationLifetime :: Lifetime
  , configurationOwnsEntries :: Bool
  , configurationRendersAllOpenEntries :: Bool
  , configurationEmptyIsDormant :: Bool
  , configurationPhase :: Applicability
  , configurationEffort :: Applicability
  , configurationRepetition :: RepetitionKind
  }
  deriving stock (Eq, Ord, Show, Generic)

data BrickBehavior = BrickBehavior
  { behaviorId :: Text
  , behaviorNamespace :: Text
  , behaviorVersion :: Integer
  , behaviorRevision :: EntityRevision
  , behaviorFocusUnit :: FocusUnit
  , behaviorLifetime :: Lifetime
  , behaviorOwnsEntries :: Bool
  , behaviorRendersAllOpenEntries :: Bool
  , behaviorEmptyIsDormant :: Bool
  , behaviorPhase :: Applicability
  , behaviorEffort :: Applicability
  , behaviorRepetition :: RepetitionKind
  }
  deriving stock (Eq, Show, Generic)

data BrickTemplate = BrickTemplate
  { templateId :: Text
  , templateNamespace :: Text
  , templateVersion :: Integer
  , templateRevision :: EntityRevision
  , templateDisplayName :: Text
  , templateCategory :: Text
  , templatePurpose :: Text
  , templateSearchTerms :: [Text]
  , templateBehavior :: BrickBehavior
  , templateDefaultTitle :: Maybe Text
  , templateDefaultDescription :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data Brick = Brick
  { brickId :: BrickId
  , brickRevision :: EntityRevision
  , brickTitle :: Text
  , brickOriginalTitle :: Maybe Text
  , brickTitleAuthority :: Authority
  , brickDescription :: Maybe Text
  , brickDescriptionRevision :: Integer
  , brickStatus :: BrickStatus
  , brickPhase :: Maybe BrickPhase
  , brickPhaseAuthority :: Maybe Authority
  , brickWorkState :: WorkState
  , brickBehavior :: BrickBehavior
  , brickParent :: Maybe BrickId
  , brickAtomicity :: Atomicity
  , brickContext :: Maybe Text
  , brickMode :: Maybe Mode
  , brickAbout :: Maybe BrickId
  , brickRequester :: Maybe PartyId
  , brickNotBefore :: Maybe UTCTime
  , brickBestBefore :: Maybe UTCTime
  , brickDeadline :: Maybe UTCTime
  , brickDateRevision :: Integer
  , brickDecompositionCoverage :: DecompositionCoverage
  , brickCreatedAt :: UTCTime
  , brickStatusChangedAt :: UTCTime
  , brickSupersededBy :: Maybe BrickId
  , brickSupersedeReason :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data ListEntry = ListEntry
  { listEntryId :: ListEntryId
  , listEntryRevision :: EntityRevision
  , listEntryOwner :: BrickId
  , listEntryLabel :: Text
  , listEntryOriginalLabel :: Maybe Text
  , listEntryLabelAuthority :: Authority
  , listEntryQuantity :: Maybe Double
  , listEntryNote :: Maybe Text
  , listEntryStatus :: ListEntryStatus
  , listEntryCreatedAt :: UTCTime
  , listEntryResolvedAt :: Maybe UTCTime
  , listEntryRemovedAt :: Maybe UTCTime
  , listEntryRemovalReason :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data FocusRegister = FocusRegister
  { focusRegisterRevision :: EntityRevision
  , focusRegisterCurrent :: Maybe BrickId
  , focusRegisterChangedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON Party where parseJSON = genericParseJSON (recordOptions "party")
instance FromJSON BrickBehavior where parseJSON = genericParseJSON (recordOptions "behavior")
instance FromJSON BrickTemplate where parseJSON = genericParseJSON (recordOptions "template")
instance FromJSON Brick where parseJSON = genericParseJSON (recordOptions "brick")
instance FromJSON ListEntry where parseJSON = genericParseJSON (recordOptions "listEntry")
instance FromJSON FocusRegister where parseJSON = genericParseJSON (recordOptions "focusRegister")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLowerAscii first : rest)
    toLowerAscii character
      | character >= 'A' && character <= 'Z' =
          toEnum (fromEnum character + fromEnum 'a' - fromEnum 'A')
      | otherwise = character

instance ToJSON Party where
  toJSON party = object
    [ "id" .= partyId party
    , "revision" .= partyRevision party
    , "label" .= partyLabel party
    , "party_type" .= partyType party
    , "alternate_labels" .= partyAlternateLabels party
    , "created_at" .= partyCreatedAt party
    ]

instance ToJSON BrickBehavior where
  toJSON behavior = object
    [ "id" .= behaviorId behavior
    , "namespace" .= behaviorNamespace behavior
    , "version" .= behaviorVersion behavior
    , "revision" .= behaviorRevision behavior
    , "focus_unit" .= behaviorFocusUnit behavior
    , "lifetime" .= behaviorLifetime behavior
    , "owns_entries" .= behaviorOwnsEntries behavior
    , "renders_all_open_entries" .= behaviorRendersAllOpenEntries behavior
    , "empty_is_dormant" .= behaviorEmptyIsDormant behavior
    , "phase" .= behaviorPhase behavior
    , "effort" .= behaviorEffort behavior
    , "repetition" .= behaviorRepetition behavior
    ]

instance ToJSON BrickTemplate where
  toJSON template = object
    [ "id" .= templateId template
    , "namespace" .= templateNamespace template
    , "version" .= templateVersion template
    , "revision" .= templateRevision template
    , "display_name" .= templateDisplayName template
    , "category" .= templateCategory template
    , "purpose" .= templatePurpose template
    , "search_terms" .= templateSearchTerms template
    , "behavior" .= templateBehavior template
    , "default_title" .= templateDefaultTitle template
    , "default_description" .= templateDefaultDescription template
    ]

instance ToJSON Brick where
  toJSON brick = object
    [ "id" .= brickId brick
    , "revision" .= brickRevision brick
    , "title" .= brickTitle brick
    , "original_title" .= brickOriginalTitle brick
    , "title_authority" .= brickTitleAuthority brick
    , "description" .= brickDescription brick
    , "description_revision" .= brickDescriptionRevision brick
    , "status" .= brickStatus brick
    , "phase" .= brickPhase brick
    , "phase_authority" .= brickPhaseAuthority brick
    , "work_state" .= brickWorkState brick
    , "behavior" .= brickBehavior brick
    , "parent" .= brickParent brick
    , "atomicity" .= brickAtomicity brick
    , "context" .= brickContext brick
    , "mode" .= brickMode brick
    , "about" .= brickAbout brick
    , "requester" .= brickRequester brick
    , "not_before" .= brickNotBefore brick
    , "best_before" .= brickBestBefore brick
    , "deadline" .= brickDeadline brick
    , "date_revision" .= brickDateRevision brick
    , "decomposition_coverage" .= brickDecompositionCoverage brick
    , "created_at" .= brickCreatedAt brick
    , "status_changed_at" .= brickStatusChangedAt brick
    , "superseded_by" .= brickSupersededBy brick
    , "supersede_reason" .= brickSupersedeReason brick
    ]

instance ToJSON ListEntry where
  toJSON entry = object
    [ "id" .= listEntryId entry
    , "revision" .= listEntryRevision entry
    , "owner" .= listEntryOwner entry
    , "label" .= listEntryLabel entry
    , "original_label" .= listEntryOriginalLabel entry
    , "label_authority" .= listEntryLabelAuthority entry
    , "quantity" .= listEntryQuantity entry
    , "note" .= listEntryNote entry
    , "status" .= listEntryStatus entry
    , "created_at" .= listEntryCreatedAt entry
    , "resolved_at" .= listEntryResolvedAt entry
    , "removed_at" .= listEntryRemovedAt entry
    , "removal_reason" .= listEntryRemovalReason entry
    ]

instance ToJSON FocusRegister where
  toJSON focus = object
    [ "revision" .= focusRegisterRevision focus
    , "current" .= focusRegisterCurrent focus
    , "changed_at" .= focusRegisterChangedAt focus
    ]

------------------------------------------------------------
-- Versioned definition catalog
------------------------------------------------------------

data DefinitionKey = DefinitionKey
  { definitionId :: Text
  , definitionNamespace :: Text
  , definitionVersion :: Integer
  }
  deriving stock (Eq, Ord, Show, Generic)

data DefinitionCatalog = DefinitionCatalog
  { catalogBehaviors :: Map DefinitionKey BrickBehavior
  , catalogTemplates :: Map DefinitionKey BrickTemplate
  }
  deriving stock (Eq, Show, Generic)

data BehaviorDraft = BehaviorDraft
  { behaviorDraftId :: Text
  , behaviorDraftNamespace :: Text
  , behaviorDraftVersion :: Integer
  , behaviorDraftConfiguration :: BehaviorConfiguration
  }
  deriving stock (Eq, Show, Generic)

data TemplateDraft = TemplateDraft
  { templateDraftId :: Text
  , templateDraftNamespace :: Text
  , templateDraftVersion :: Integer
  , templateDraftDisplayName :: Text
  , templateDraftCategory :: Text
  , templateDraftPurpose :: Text
  , templateDraftSearchTerms :: [Text]
  , templateDraftBehavior :: BrickBehavior
  , templateDraftDefaultTitle :: Maybe Text
  , templateDraftDefaultDescription :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data PublicationResult value
  = Published value
  | ExistingDefinitionSelected value
  deriving stock (Eq, Show, Generic)

data DomainError
  = EmptyText Text
  | InvalidCanonicalEnglish Text
  | UnknownParty PartyId
  | UnknownBrick BrickId
  | UnknownListEntry ListEntryId
  | BehaviorIsNotPublished Text
  | TemplateIsNotPublished Text
  | InvalidRelationship Text
  | InvalidTransition Text
  | InvalidBehaviorConfiguration [Text]
  | NamespaceIsNotPersonal Text
  | VersionMustBe Integer Integer
  | DefinitionVersionAlreadyExists DefinitionKey
  | AlternateLabelAlreadyPresent Text
  | AlternateLabelMatchesCurrent Text
  | InvalidPageSize Int
  | InvalidCursor Text
  | DomainInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

behaviorConfiguration :: BrickBehavior -> BehaviorConfiguration
behaviorConfiguration behavior = BehaviorConfiguration
  { configurationFocusUnit = behaviorFocusUnit behavior
  , configurationLifetime = behaviorLifetime behavior
  , configurationOwnsEntries = behaviorOwnsEntries behavior
  , configurationRendersAllOpenEntries = behaviorRendersAllOpenEntries behavior
  , configurationEmptyIsDormant = behaviorEmptyIsDormant behavior
  , configurationPhase = behaviorPhase behavior
  , configurationEffort = behaviorEffort behavior
  , configurationRepetition = behaviorRepetition behavior
  }

behaviorConfigurationValid :: BehaviorConfiguration -> Either DomainError ()
behaviorConfigurationValid configuration = case problems of
  [] -> Right ()
  _ -> Left (InvalidBehaviorConfiguration problems)
  where
    ownsEntries = configurationOwnsEntries configuration
    focusUnit = configurationFocusUnit configuration
    lifetime = configurationLifetime configuration
    repetition = configurationRepetition configuration
    problems = catMaybes
      [ problemWhen
          (configurationRendersAllOpenEntries configuration && not ownsEntries)
          "rendering all open entries requires entry ownership"
      , problemWhen (ownsEntries && focusUnit /= BatchFocus)
          "entry ownership requires batch focus"
      , problemWhen (focusUnit == BatchFocus && not ownsEntries)
          "batch focus requires entry ownership"
      , problemWhen
          (configurationEmptyIsDormant configuration && lifetime /= Standing)
          "empty dormancy requires standing lifetime"
      , problemWhen (repetition /= NoRepetition && lifetime /= Standing)
          "repetition requires standing lifetime"
      , problemWhen (ownsEntries && repetition /= NoRepetition)
          "entry ownership and repetition cannot be combined"
      , problemWhen
          (repetition == CompletionTriggered && focusUnit /= BrickFocus)
          "completion-triggered work focuses the Brick"
      , problemWhen
          (repetition == RecurringObligation && focusUnit /= ChildrenFocus)
          "recurring obligations focus released children"
      , problemWhen (repetition == Practice && focusUnit /= BrickFocus)
          "practice focuses the standing Brick"
      ]

problemWhen :: Bool -> Text -> Maybe Text
problemWhen condition problem = if condition then Just problem else Nothing

standardV1, projectV1, collectionV1, repeatableV1 :: BrickBehavior
standingChecklistV1, finiteChecklistV1, recurringObligationV1, practiceV1 :: BrickBehavior
standardV1 = builtInBehavior "core/standard" BrickFocus Finite False False False Applicable Applicable NoRepetition
projectV1 = builtInBehavior "core/project" ChildrenFocus Finite False False False Applicable Applicable NoRepetition
collectionV1 = builtInBehavior "core/collection" ChildrenFocus Standing False False True Disabled Disabled NoRepetition
repeatableV1 = builtInBehavior "core/repeatable" BrickFocus Standing False False False Applicable Applicable CompletionTriggered
standingChecklistV1 = builtInBehavior "core/standing_checklist" BatchFocus Standing True True True Disabled Disabled NoRepetition
finiteChecklistV1 = builtInBehavior "core/finite_checklist" BatchFocus Finite True True False Disabled Disabled NoRepetition
recurringObligationV1 = builtInBehavior "core/recurring_obligation" ChildrenFocus Standing False False True Disabled Disabled RecurringObligation
practiceV1 = builtInBehavior "core/practice" BrickFocus Standing False False True Disabled Disabled Practice

builtInBehavior ::
  Text -> FocusUnit -> Lifetime -> Bool -> Bool -> Bool ->
  Applicability -> Applicability -> RepetitionKind -> BrickBehavior
builtInBehavior identifier focusUnit lifetime ownsEntries rendersEntries dormant phase effort repetition = BrickBehavior
  { behaviorId = identifier
  , behaviorNamespace = "core"
  , behaviorVersion = 1
  , behaviorRevision = EntityRevision 1
  , behaviorFocusUnit = focusUnit
  , behaviorLifetime = lifetime
  , behaviorOwnsEntries = ownsEntries
  , behaviorRendersAllOpenEntries = rendersEntries
  , behaviorEmptyIsDormant = dormant
  , behaviorPhase = phase
  , behaviorEffort = effort
  , behaviorRepetition = repetition
  }

builtInBehaviors :: [BrickBehavior]
builtInBehaviors =
  [ standardV1, projectV1, collectionV1, repeatableV1
  , standingChecklistV1, finiteChecklistV1, recurringObligationV1, practiceV1
  ]

builtInTemplates :: [BrickTemplate]
builtInTemplates =
  [ builtInTemplate "standard/grocery_list" "Grocery list" "checklists"
      "Keep one reusable grocery list and resolve its entries in shopping runs."
      ["groceries", "shopping", "supermarket"] standingChecklistV1
      (Just "Buy groceries") Nothing
  , builtInTemplate "standard/packing_checklist" "Packing checklist" "checklists"
      "Prepare one finite set of things for a trip, move, or event."
      ["packing", "trip", "travel"] finiteChecklistV1 Nothing Nothing
  , builtInTemplate "standard/reading_list" "Reading list" "collections"
      "Keep independently focusable reading work without FIFO semantics."
      ["reading", "books", "articles"] collectionV1 Nothing Nothing
  , builtInTemplate "standard/article_reading" "Article reading" "reading"
      "Read material now and optionally return the same Brick after completion."
      ["article", "read", "revisit"] repeatableV1 Nothing Nothing
  , builtInTemplate "standard/feature_backlog" "Feature backlog" "software"
      "Keep software improvements ordered as independently focusable work."
      ["feature", "software", "backlog"] collectionV1 Nothing Nothing
  , builtInTemplate "standard/wishlist" "Wishlist" "collections"
      "Keep long-term purchase candidates without FIFO semantics."
      ["wishlist", "buy", "purchase"] collectionV1 Nothing Nothing
  , builtInTemplate "standard/bills_to_pay" "Bills to pay" "obligations"
      "Release independently resolvable and possibly overdue bill occurrences."
      ["bills", "payments", "obligations"] recurringObligationV1
      (Just "Pay bills") Nothing
  , builtInTemplate "standard/exercise_practice" "Exercise practice" "practices"
      "Track recurring physical practice opportunities without backlog."
      ["exercise", "walking", "swimming", "running"] practiceV1 Nothing Nothing
  ]

builtInTemplate ::
  Text -> Text -> Text -> Text -> [Text] -> BrickBehavior ->
  Maybe Text -> Maybe Text -> BrickTemplate
builtInTemplate identifier displayName category purpose searchTerms behavior defaultTitle defaultDescription = BrickTemplate
  { templateId = identifier
  , templateNamespace = "standard"
  , templateVersion = 1
  , templateRevision = EntityRevision 1
  , templateDisplayName = displayName
  , templateCategory = category
  , templatePurpose = purpose
  , templateSearchTerms = searchTerms
  , templateBehavior = behavior
  , templateDefaultTitle = defaultTitle
  , templateDefaultDescription = defaultDescription
  }

initialDefinitionCatalog :: DefinitionCatalog
initialDefinitionCatalog = DefinitionCatalog
  { catalogBehaviors = Map.fromList
      [(behaviorKey behavior, behavior) | behavior <- builtInBehaviors]
  , catalogTemplates = Map.fromList
      [(templateKey template, template) | template <- builtInTemplates]
  }

behaviorKey :: BrickBehavior -> DefinitionKey
behaviorKey behavior = DefinitionKey
  (behaviorId behavior) (behaviorNamespace behavior) (behaviorVersion behavior)

templateKey :: BrickTemplate -> DefinitionKey
templateKey template = DefinitionKey
  (templateId template) (templateNamespace template) (templateVersion template)

behaviorVersions :: DefinitionCatalog -> [BrickBehavior]
behaviorVersions = Map.elems . catalogBehaviors

templateVersions :: DefinitionCatalog -> [BrickTemplate]
templateVersions = Map.elems . catalogTemplates

catalogContainsBehavior :: DefinitionCatalog -> BrickBehavior -> Bool
catalogContainsBehavior catalog behavior =
  Map.lookup (behaviorKey behavior) (catalogBehaviors catalog) == Just behavior

publishPersonalBehavior ::
  BehaviorDraft -> DefinitionCatalog ->
  Either DomainError (PublicationResult BrickBehavior, DefinitionCatalog)
publishPersonalBehavior draft catalog = do
  validateDefinitionIdentity (behaviorDraftId draft)
  requirePersonalNamespace (behaviorDraftNamespace draft)
  behaviorConfigurationValid (behaviorDraftConfiguration draft)
  case find ((== behaviorDraftConfiguration draft) . behaviorConfiguration)
      (behaviorVersions catalog) of
    Just existing -> Right (ExistingDefinitionSelected existing, catalog)
    Nothing -> do
      let expected = nextVersion definitionId definitionNamespace
            (Map.keys (catalogBehaviors catalog))
          actual = behaviorDraftVersion draft
          key = DefinitionKey definitionId definitionNamespace actual
      unless (actual == expected) (Left (VersionMustBe expected actual))
      when (Map.member key (catalogBehaviors catalog))
        (Left (DefinitionVersionAlreadyExists key))
      let created = behaviorFromConfiguration draft
          updated = catalog
            { catalogBehaviors = Map.insert key created (catalogBehaviors catalog) }
      Right (Published created, updated)
  where
    definitionId = behaviorDraftId draft
    definitionNamespace = behaviorDraftNamespace draft

behaviorFromConfiguration :: BehaviorDraft -> BrickBehavior
behaviorFromConfiguration draft = BrickBehavior
  { behaviorId = behaviorDraftId draft
  , behaviorNamespace = behaviorDraftNamespace draft
  , behaviorVersion = behaviorDraftVersion draft
  , behaviorRevision = EntityRevision 1
  , behaviorFocusUnit = configurationFocusUnit configuration
  , behaviorLifetime = configurationLifetime configuration
  , behaviorOwnsEntries = configurationOwnsEntries configuration
  , behaviorRendersAllOpenEntries = configurationRendersAllOpenEntries configuration
  , behaviorEmptyIsDormant = configurationEmptyIsDormant configuration
  , behaviorPhase = configurationPhase configuration
  , behaviorEffort = configurationEffort configuration
  , behaviorRepetition = configurationRepetition configuration
  }
  where
    configuration = behaviorDraftConfiguration draft

publishPersonalTemplate ::
  TemplateDraft -> DefinitionCatalog ->
  Either DomainError (BrickTemplate, DefinitionCatalog)
publishPersonalTemplate draft catalog = do
  validateDefinitionIdentity (templateDraftId draft)
  requirePersonalNamespace (templateDraftNamespace draft)
  validateNonEmpty "template display name" (templateDraftDisplayName draft)
  validateNonEmpty "template category" (templateDraftCategory draft)
  validateNonEmpty "template purpose" (templateDraftPurpose draft)
  mapM_ (validateNonEmpty "template search term") (templateDraftSearchTerms draft)
  mapM_ validateCanonicalEnglish (templateDraftDefaultTitle draft)
  mapM_ validateCanonicalEnglish (templateDraftDefaultDescription draft)
  unless (catalogContainsBehavior catalog (templateDraftBehavior draft))
    (Left (BehaviorIsNotPublished (behaviorId (templateDraftBehavior draft))))
  let expected = nextVersion definitionId definitionNamespace
        (Map.keys (catalogTemplates catalog))
      actual = templateDraftVersion draft
      key = DefinitionKey definitionId definitionNamespace actual
  unless (actual == expected) (Left (VersionMustBe expected actual))
  when (Map.member key (catalogTemplates catalog))
    (Left (DefinitionVersionAlreadyExists key))
  let created = BrickTemplate
        { templateId = definitionId
        , templateNamespace = definitionNamespace
        , templateVersion = actual
        , templateRevision = EntityRevision 1
        , templateDisplayName = templateDraftDisplayName draft
        , templateCategory = templateDraftCategory draft
        , templatePurpose = templateDraftPurpose draft
        , templateSearchTerms = templateDraftSearchTerms draft
        , templateBehavior = templateDraftBehavior draft
        , templateDefaultTitle = templateDraftDefaultTitle draft
        , templateDefaultDescription = templateDraftDefaultDescription draft
        }
      updated = catalog
        { catalogTemplates = Map.insert key created (catalogTemplates catalog) }
  Right (created, updated)
  where
    definitionId = templateDraftId draft
    definitionNamespace = templateDraftNamespace draft

nextVersion :: Text -> Text -> [DefinitionKey] -> Integer
nextVersion identifier namespace keys = case matchingVersions of
  [] -> 1
  versions -> maximum versions + 1
  where
    matchingVersions =
      [definitionVersion key | key <- keys,
        definitionId key == identifier,
        definitionNamespace key == namespace]

requirePersonalNamespace :: Text -> Either DomainError ()
requirePersonalNamespace namespace = unless
  (namespace == "personal" || "personal/" `Text.isPrefixOf` namespace)
  (Left (NamespaceIsNotPersonal namespace))

validateDefinitionIdentity :: Text -> Either DomainError ()
validateDefinitionIdentity = validateNonEmpty "definition ID"

findBehaviors ::
  Text -> Maybe Text -> Int -> DefinitionCatalog ->
  Either DomainError [BrickBehavior]
findBehaviors query cursor pageSize catalog = do
  offset <- validateCatalogRequest cursor pageSize
  pure (take pageSize (drop offset matching))
  where
    needle = Text.toCaseFold (Text.strip query)
    matching = sortOn behaviorDiscoveryKey
      [ behavior
      | behavior <- behaviorVersions catalog
      , Text.null needle || any (Text.isInfixOf needle . Text.toCaseFold)
          [behaviorId behavior, behaviorNamespace behavior]
      ]

findTemplates ::
  Text -> Maybe Text -> Maybe Text -> Int -> DefinitionCatalog ->
  Either DomainError [BrickTemplate]
findTemplates query category cursor pageSize catalog = do
  offset <- validateCatalogRequest cursor pageSize
  pure (take pageSize (drop offset matching))
  where
    needle = Text.toCaseFold (Text.strip query)
    categoryNeedle = Text.toCaseFold . Text.strip <$> category
    matchesCategory template = maybe True
      (== Text.toCaseFold (templateCategory template)) categoryNeedle
    matchesQuery template = Text.null needle || any
      (Text.isInfixOf needle . Text.toCaseFold)
      ( [ templateId template
        , templateNamespace template
        , templateDisplayName template
        , templateCategory template
        , templatePurpose template
        ] <> templateSearchTerms template)
    matching = sortOn templateDiscoveryKey
      [template | template <- templateVersions catalog,
        matchesCategory template, matchesQuery template]

validateCatalogRequest :: Maybe Text -> Int -> Either DomainError Int
validateCatalogRequest cursor pageSize = do
  unless (pageSize > 0 && pageSize <= 50) (Left (InvalidPageSize pageSize))
  case cursor of
    Nothing -> Right 0
    Just value -> case Text.stripPrefix "offset:" value >>= readMaybe . Text.unpack of
      Just offset | offset >= (0 :: Int) -> Right offset
      _ -> Left (InvalidCursor value)

behaviorDiscoveryKey :: BrickBehavior -> (Text, Text, Integer)
behaviorDiscoveryKey behavior =
  (behaviorNamespace behavior, behaviorId behavior, behaviorVersion behavior)

templateDiscoveryKey :: BrickTemplate -> (Text, Text, Text, Integer)
templateDiscoveryKey template =
  ( templateCategory template, templateNamespace template
  , templateId template, templateVersion template)

------------------------------------------------------------
-- Domain state and transitions
------------------------------------------------------------

data DomainState = DomainState
  { domainNextIdentityOrdinal :: Integer
  , domainCatalog :: DefinitionCatalog
  , domainParties :: Map PartyId Party
  , domainBricks :: Map BrickId Brick
  , domainListEntries :: Map ListEntryId ListEntry
  , domainFocusRegister :: FocusRegister
  }
  deriving stock (Eq, Show, Generic)

-- The immutable built-in catalog is reconstructed rather than duplicated in
-- every persisted domain slice.  Personal catalog publication will gain its
-- own event representation when that operation is exposed through the v1
-- kernel; operational entities round-trip here without derived projections.
instance ToJSON DomainState where
  toJSON state = object
    [ "next_identity_ordinal" .= domainNextIdentityOrdinal state
    , "parties" .= Map.elems (domainParties state)
    , "bricks" .= Map.elems (domainBricks state)
    , "list_entries" .= Map.elems (domainListEntries state)
    , "focus_register" .= domainFocusRegister state
    ]

instance FromJSON DomainState where
  parseJSON = withObject "DomainState" $ \value -> do
    nextOrdinal <- value .: "next_identity_ordinal"
    parties <- value .: "parties"
    bricks <- value .: "bricks"
    entries <- value .: "list_entries"
    focus <- value .: "focus_register"
    pure DomainState
      { domainNextIdentityOrdinal = nextOrdinal
      , domainCatalog = initialDefinitionCatalog
      , domainParties = Map.fromList [(partyId party, party) | party <- parties]
      , domainBricks = Map.fromList [(brickId brick, brick) | brick <- bricks]
      , domainListEntries = Map.fromList
          [(listEntryId entry, entry) | entry <- entries]
      , domainFocusRegister = focus
      }

data BrickDraft = BrickDraft
  { brickDraftTitle :: CanonicalText
  , brickDraftDescription :: Maybe Text
  , brickDraftPhase :: Maybe BrickPhase
  , brickDraftPhaseAuthority :: Maybe Authority
  , brickDraftBehavior :: BrickBehavior
  , brickDraftParent :: Maybe BrickId
  , brickDraftAtomicity :: Atomicity
  , brickDraftContext :: Maybe Text
  , brickDraftMode :: Maybe Mode
  , brickDraftAbout :: Maybe BrickId
  , brickDraftRequester :: Maybe PartyId
  , brickDraftNotBefore :: Maybe UTCTime
  , brickDraftBestBefore :: Maybe UTCTime
  , brickDraftDeadline :: Maybe UTCTime
  , brickDraftDecompositionCoverage :: DecompositionCoverage
  , brickDraftCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data ListEntryDraft = ListEntryDraft
  { listEntryDraftOwner :: BrickId
  , listEntryDraftLabel :: CanonicalText
  , listEntryDraftQuantity :: Maybe Double
  , listEntryDraftNote :: Maybe Text
  , listEntryDraftCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data BrickClosure
  = MarkDone
  | MarkDropped
  | MarkSuperseded BrickId (Maybe Text)
  deriving stock (Eq, Show, Generic)

emptyDomainState :: DomainState
emptyDomainState = DomainState
  { domainNextIdentityOrdinal = 0
  , domainCatalog = initialDefinitionCatalog
  , domainParties = Map.empty
  , domainBricks = Map.empty
  , domainListEntries = Map.empty
  , domainFocusRegister = FocusRegister (EntityRevision 0) Nothing Nothing
  }

canonicalEnglishText :: Text -> Bool
canonicalEnglishText value =
  not (Text.null value)
  && Text.strip value == value
  && not (Text.any isControl value)

validateCanonicalEnglish :: Text -> Either DomainError ()
validateCanonicalEnglish value = unless (canonicalEnglishText value)
  (Left (InvalidCanonicalEnglish value))

mkCanonicalText :: Text -> Maybe Text -> Authority -> Either DomainError CanonicalText
mkCanonicalText english original authority = do
  validateCanonicalEnglish english
  pure CanonicalText
    { canonicalTextEnglish = english
    , canonicalTextOriginal = original
    , canonicalTextAuthority = authority
    }

ordinaryBrickDraft :: CanonicalText -> BrickBehavior -> UTCTime -> BrickDraft
ordinaryBrickDraft title behavior createdAt = BrickDraft
  { brickDraftTitle = title
  , brickDraftDescription = Nothing
  , brickDraftPhase = Nothing
  , brickDraftPhaseAuthority = Nothing
  , brickDraftBehavior = behavior
  , brickDraftParent = Nothing
  , brickDraftAtomicity = Unknown
  , brickDraftContext = Nothing
  , brickDraftMode = Nothing
  , brickDraftAbout = Nothing
  , brickDraftRequester = Nothing
  , brickDraftNotBefore = Nothing
  , brickDraftBestBefore = Nothing
  , brickDraftDeadline = Nothing
  , brickDraftDecompositionCoverage = NotApplicable
  , brickDraftCreatedAt = createdAt
  }

createParty ::
  Text -> PartyType -> UTCTime -> DomainState ->
  Either DomainError (Party, DomainState)
createParty label partyKind createdAt state = do
  validateNonEmpty "party label" label
  let (identifier, nextOrdinal) = allocatePartyId (domainNextIdentityOrdinal state)
      party = Party
        { partyId = identifier
        , partyRevision = EntityRevision 1
        , partyLabel = label
        , partyType = partyKind
        , partyAlternateLabels = []
        , partyCreatedAt = createdAt
        }
      next = state
        { domainNextIdentityOrdinal = nextOrdinal
        , domainParties = Map.insert identifier party (domainParties state)
        }
  validateAndReturn party next

renameParty ::
  PartyId -> Text -> DomainState -> Either DomainError (Party, DomainState)
renameParty identifier nextLabel state = do
  validateNonEmpty "party label" nextLabel
  party <- lookupParty identifier state
  let priorLabel = partyLabel party
      labels = appendDistinct priorLabel (partyAlternateLabels party)
      updated = party
        { partyLabel = nextLabel
        , partyAlternateLabels = labels
        , partyRevision = bumpRevision (partyRevision party)
        }
      next = state {domainParties = Map.insert identifier updated (domainParties state)}
  validateAndReturn updated next

addAlternatePartyLabel ::
  PartyId -> Text -> DomainState -> Either DomainError (Party, DomainState)
addAlternatePartyLabel identifier label state = do
  validateNonEmpty "alternate party label" label
  party <- lookupParty identifier state
  when (label == partyLabel party) (Left (AlternateLabelMatchesCurrent label))
  when (label `elem` partyAlternateLabels party)
    (Left (AlternateLabelAlreadyPresent label))
  let updated = party
        { partyAlternateLabels = partyAlternateLabels party <> [label]
        , partyRevision = bumpRevision (partyRevision party)
        }
      next = state {domainParties = Map.insert identifier updated (domainParties state)}
  validateAndReturn updated next

createBrick ::
  BrickDraft -> DomainState -> Either DomainError (Brick, DomainState)
createBrick draft state = do
  validateCanonicalEnglish (canonicalTextEnglish (brickDraftTitle draft))
  mapM_ validateCanonicalEnglish (brickDraftDescription draft)
  unless (catalogContainsBehavior (domainCatalog state) (brickDraftBehavior draft))
    (Left (BehaviorIsNotPublished (behaviorId (brickDraftBehavior draft))))
  validatePhaseSelection (brickDraftBehavior draft)
    (brickDraftPhase draft) (brickDraftPhaseAuthority draft)
  mapM_ (`lookupBrick` state) (brickDraftParent draft)
  mapM_ (`lookupBrick` state) (brickDraftAbout draft)
  mapM_ (`lookupParty` state) (brickDraftRequester draft)
  let (identifier, nextOrdinal) = allocateBrickId (domainNextIdentityOrdinal state)
      brick = Brick
        { brickId = identifier
        , brickRevision = EntityRevision 1
        , brickTitle = canonicalTextEnglish (brickDraftTitle draft)
        , brickOriginalTitle = canonicalTextOriginal (brickDraftTitle draft)
        , brickTitleAuthority = canonicalTextAuthority (brickDraftTitle draft)
        , brickDescription = brickDraftDescription draft
        , brickDescriptionRevision = maybe 0 (const 1) (brickDraftDescription draft)
        , brickStatus = Active
        , brickPhase = brickDraftPhase draft
        , brickPhaseAuthority = brickDraftPhaseAuthority draft
        , brickWorkState = Idle
        , brickBehavior = brickDraftBehavior draft
        , brickParent = brickDraftParent draft
        , brickAtomicity = brickDraftAtomicity draft
        , brickContext = brickDraftContext draft
        , brickMode = brickDraftMode draft
        , brickAbout = brickDraftAbout draft
        , brickRequester = brickDraftRequester draft
        , brickNotBefore = brickDraftNotBefore draft
        , brickBestBefore = brickDraftBestBefore draft
        , brickDeadline = brickDraftDeadline draft
        , brickDateRevision = 0
        , brickDecompositionCoverage = brickDraftDecompositionCoverage draft
        , brickCreatedAt = brickDraftCreatedAt draft
        , brickStatusChangedAt = brickDraftCreatedAt draft
        , brickSupersededBy = Nothing
        , brickSupersedeReason = Nothing
        }
      next = state
        { domainNextIdentityOrdinal = nextOrdinal
        , domainBricks = Map.insert identifier brick (domainBricks state)
        }
  validateAndReturn brick next

instantiateTemplate ::
  BrickTemplate -> Maybe CanonicalText -> UTCTime -> DomainState ->
  Either DomainError (Brick, DomainState)
instantiateTemplate template titleOverride createdAt state = do
  unless (Map.lookup (templateKey template)
      (catalogTemplates (domainCatalog state)) == Just template)
    (Left (TemplateIsNotPublished (templateId template)))
  title <- case titleOverride of
    Just supplied -> Right supplied
    Nothing -> case templateDefaultTitle template of
      Just defaultTitle -> mkCanonicalText defaultTitle Nothing Core
      Nothing -> Left (EmptyText "template instantiation title")
  createBrick
    ((ordinaryBrickDraft title (templateBehavior template) createdAt)
      {brickDraftDescription = templateDefaultDescription template}) state

createListEntry ::
  ListEntryDraft -> DomainState -> Either DomainError (ListEntry, DomainState)
createListEntry draft state = do
  validateCanonicalEnglish
    (canonicalTextEnglish (listEntryDraftLabel draft))
  owner <- lookupBrick (listEntryDraftOwner draft) state
  unless (brickStatus owner == Active)
    (Left (InvalidRelationship "ListEntry owner must be active"))
  unless (behaviorOwnsEntries (brickBehavior owner))
    (Left (InvalidRelationship "ListEntry owner behavior does not own entries"))
  let (identifier, nextOrdinal) = allocateListEntryId
        (domainNextIdentityOrdinal state)
      entry = ListEntry
        { listEntryId = identifier
        , listEntryRevision = EntityRevision 1
        , listEntryOwner = listEntryDraftOwner draft
        , listEntryLabel = canonicalTextEnglish (listEntryDraftLabel draft)
        , listEntryOriginalLabel = canonicalTextOriginal (listEntryDraftLabel draft)
        , listEntryLabelAuthority = canonicalTextAuthority (listEntryDraftLabel draft)
        , listEntryQuantity = listEntryDraftQuantity draft
        , listEntryNote = listEntryDraftNote draft
        , listEntryStatus = EntryOpen
        , listEntryCreatedAt = listEntryDraftCreatedAt draft
        , listEntryResolvedAt = Nothing
        , listEntryRemovedAt = Nothing
        , listEntryRemovalReason = Nothing
        }
      next = state
        { domainNextIdentityOrdinal = nextOrdinal
        , domainListEntries = Map.insert identifier entry (domainListEntries state)
        }
  validateAndReturn entry next

resolveListEntry ::
  ListEntryId -> UTCTime -> DomainState ->
  Either DomainError (ListEntry, DomainState)
resolveListEntry identifier resolvedAt state = do
  entry <- lookupListEntry identifier state
  unless (listEntryStatus entry == EntryOpen)
    (Left (InvalidTransition "only an open ListEntry can resolve"))
  let updated = entry
        { listEntryStatus = EntryResolved
        , listEntryResolvedAt = Just resolvedAt
        , listEntryRevision = bumpRevision (listEntryRevision entry)
        }
      next = state
        {domainListEntries = Map.insert identifier updated (domainListEntries state)}
  validateAndReturn updated next

removeListEntry ::
  ListEntryId -> Maybe Text -> UTCTime -> DomainState ->
  Either DomainError (ListEntry, DomainState)
removeListEntry identifier reason removedAt state = do
  entry <- lookupListEntry identifier state
  unless (listEntryStatus entry == EntryOpen)
    (Left (InvalidTransition "only an open ListEntry can be removed"))
  let updated = entry
        { listEntryStatus = EntryRemoved
        , listEntryRemovedAt = Just removedAt
        , listEntryRemovalReason = reason
        , listEntryRevision = bumpRevision (listEntryRevision entry)
        }
      next = state
        {domainListEntries = Map.insert identifier updated (domainListEntries state)}
  validateAndReturn updated next

setBrickWorkState ::
  BrickId -> WorkState -> DomainState -> Either DomainError (Brick, DomainState)
setBrickWorkState identifier nextWorkState state = do
  brick <- lookupBrick identifier state
  unless (brickStatus brick == Active)
    (Left (InvalidTransition "terminal Bricks cannot enter WIP"))
  when (brickWorkState brick == nextWorkState)
    (Left (InvalidTransition "work-state transition must change state"))
  when (nextWorkState == Idle
      && focusRegisterCurrent (domainFocusRegister state) == Just identifier)
    (Left (InvalidTransition "the currently focused Brick must be unfocused first"))
  replaceActiveBrick identifier
    (brick {brickWorkState = nextWorkState}) state

renameBrick ::
  BrickId -> Text -> Authority -> DomainState ->
  Either DomainError (Brick, DomainState)
renameBrick identifier title authority state = do
  validateCanonicalEnglish title
  brick <- requireActiveBrick identifier state
  replaceBrick identifier brick
    { brickTitle = title
    , brickTitleAuthority = authority
    } state

setBrickOriginalTitle ::
  BrickId -> Text -> DomainState -> Either DomainError (Brick, DomainState)
setBrickOriginalTitle identifier originalTitle state = do
  brick <- requireActiveBrick identifier state
  replaceBrick identifier brick {brickOriginalTitle = Just originalTitle} state

clearBrickOriginalTitle ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickOriginalTitle identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick original title is already absent" (brickOriginalTitle brick)
  replaceBrick identifier brick {brickOriginalTitle = Nothing} state

describeBrick ::
  BrickId -> Text -> DomainState -> Either DomainError (Brick, DomainState)
describeBrick identifier description state = do
  brick <- requireActiveBrick identifier state
  replaceBrick identifier brick
    { brickDescription = Just description
    , brickDescriptionRevision = brickDescriptionRevision brick + 1
    } state

clearBrickDescription ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickDescription identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick description is already absent" (brickDescription brick)
  replaceBrick identifier brick
    { brickDescription = Nothing
    , brickDescriptionRevision = brickDescriptionRevision brick + 1
    } state

setBrickPhase ::
  BrickId -> Maybe BrickPhase -> Maybe Authority -> DomainState ->
  Either DomainError (Brick, DomainState)
setBrickPhase identifier phase authority state = do
  brick <- requireActiveBrick identifier state
  unless (behaviorPhase (brickBehavior brick) == Applicable)
    (Left (InvalidRelationship "behavior disables phase"))
  validatePhaseSelection (brickBehavior brick) phase authority
  replaceBrick identifier brick
    { brickPhase = phase
    , brickPhaseAuthority = authority
    } state

clearBrickPhase ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickPhase identifier state = setBrickPhase identifier Nothing Nothing state

setBrickContext ::
  BrickId -> Text -> DomainState -> Either DomainError (Brick, DomainState)
setBrickContext identifier context state = do
  brick <- requireActiveBrick identifier state
  replaceBrick identifier brick {brickContext = Just context} state

clearBrickContext ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickContext identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick context is already absent" (brickContext brick)
  replaceBrick identifier brick {brickContext = Nothing} state

setBrickMode ::
  BrickId -> Mode -> DomainState -> Either DomainError (Brick, DomainState)
setBrickMode identifier mode state = do
  brick <- requireActiveBrick identifier state
  replaceBrick identifier brick {brickMode = Just mode} state

clearBrickMode ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickMode identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick mode is already absent" (brickMode brick)
  replaceBrick identifier brick {brickMode = Nothing} state

setBrickNotBefore ::
  BrickId -> UTCTime -> DomainState -> Either DomainError (Brick, DomainState)
setBrickNotBefore identifier value = setBrickDate identifier
  (\brick -> brick {brickNotBefore = Just value})

clearBrickNotBefore ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickNotBefore identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick not-before is already absent" (brickNotBefore brick)
  setBrickDate identifier (\value -> value {brickNotBefore = Nothing}) state

setBrickBestBefore ::
  BrickId -> UTCTime -> DomainState -> Either DomainError (Brick, DomainState)
setBrickBestBefore identifier value = setBrickDate identifier
  (\brick -> brick {brickBestBefore = Just value})

clearBrickBestBefore ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickBestBefore identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick best-before is already absent" (brickBestBefore brick)
  setBrickDate identifier (\value -> value {brickBestBefore = Nothing}) state

setBrickDeadline ::
  BrickId -> UTCTime -> DomainState -> Either DomainError (Brick, DomainState)
setBrickDeadline identifier value = setBrickDate identifier
  (\brick -> brick {brickDeadline = Just value})

clearBrickDeadline ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickDeadline identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick deadline is already absent" (brickDeadline brick)
  setBrickDate identifier (\value -> value {brickDeadline = Nothing}) state

setBrickDate ::
  BrickId -> (Brick -> Brick) -> DomainState ->
  Either DomainError (Brick, DomainState)
setBrickDate identifier change state = do
  brick <- requireActiveBrick identifier state
  replaceBrick identifier
    ((change brick) {brickDateRevision = brickDateRevision brick + 1}) state

setBrickRequester ::
  BrickId -> PartyId -> DomainState -> Either DomainError (Brick, DomainState)
setBrickRequester identifier requester state = do
  _ <- lookupParty requester state
  brick <- requireActiveBrick identifier state
  replaceBrick identifier brick {brickRequester = Just requester} state

clearBrickRequester ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickRequester identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick requester is already absent" (brickRequester brick)
  replaceBrick identifier brick {brickRequester = Nothing} state

setBrickAbout ::
  BrickId -> BrickId -> DomainState -> Either DomainError (Brick, DomainState)
setBrickAbout identifier about state = do
  when (identifier == about)
    (Left (InvalidRelationship "a Brick cannot be about itself"))
  _ <- lookupBrick about state
  brick <- requireActiveBrick identifier state
  replaceBrick identifier brick {brickAbout = Just about} state

clearBrickAbout ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
clearBrickAbout identifier state = do
  brick <- requireActiveBrick identifier state
  requirePresent "Brick about relationship is already absent" (brickAbout brick)
  replaceBrick identifier brick {brickAbout = Nothing} state

setBrickParent ::
  BrickId -> Maybe BrickId -> DomainState -> Either DomainError (Brick, DomainState)
setBrickParent identifier parent state = do
  brick <- requireActiveBrick identifier state
  when (parent == Just identifier)
    (Left (InvalidRelationship "a Brick cannot parent itself"))
  mapM_ (\parentId -> do
      parentBrick <- lookupBrick parentId state
      unless (brickStatus parentBrick == Active)
        (Left (InvalidRelationship "new parent must be active"))) parent
  mapM_ (rejectDescendant identifier state) parent
  when (brickParent brick == parent)
    (Left (InvalidRelationship "parent relationship is unchanged"))
  replaceBrick identifier brick {brickParent = parent} state

rejectDescendant :: BrickId -> DomainState -> BrickId -> Either DomainError ()
rejectDescendant child state candidate = do
  ancestors <- lineage state candidate
  when (any ((== child) . brickId) ancestors)
    (Left (InvalidRelationship "parent relationship would create a cycle"))

focusBrick ::
  Maybe BrickId -> UTCTime -> DomainState ->
  Either DomainError (FocusRegister, DomainState)
focusBrick current changedAt state = case current of
  Nothing -> unfocusCurrentBrick changedAt state
  Just identifier -> do
    brick <- requireActiveBrick identifier state
    notBefore <- effectiveNotBefore state identifier
    when (maybe False (> changedAt) notBefore)
      (Left (InvalidTransition "Brick cannot be focused before its effective not-before"))
    let focus = domainFocusRegister state
        updatedFocus = focus
          { focusRegisterCurrent = Just identifier
          , focusRegisterChangedAt = Just changedAt
          , focusRegisterRevision = bumpRevision (focusRegisterRevision focus)
          }
        updatedBrick = if brickWorkState brick == Idle
          then brick
            { brickWorkState = Wip
            , brickRevision = bumpRevision (brickRevision brick)
            }
          else brick
        next = state
          { domainBricks = Map.insert identifier updatedBrick (domainBricks state)
          , domainFocusRegister = updatedFocus
          }
    validateAndReturn updatedFocus next

unfocusCurrentBrick ::
  UTCTime -> DomainState -> Either DomainError (FocusRegister, DomainState)
unfocusCurrentBrick changedAt state = do
  let focus = domainFocusRegister state
  when (focusRegisterCurrent focus == Nothing)
    (Left (InvalidTransition "there is no current Brick to unfocus"))
  let updated = focus
        { focusRegisterCurrent = Nothing
        , focusRegisterChangedAt = Just changedAt
        , focusRegisterRevision = bumpRevision (focusRegisterRevision focus)
        }
  validateAndReturn updated state {domainFocusRegister = updated}

returnBrickToIdle ::
  BrickId -> DomainState -> Either DomainError (Brick, DomainState)
returnBrickToIdle identifier state = do
  brick <- requireActiveBrick identifier state
  unless (brickWorkState brick == Wip)
    (Left (InvalidTransition "only WIP can return to idle"))
  when (focusRegisterCurrent (domainFocusRegister state) == Just identifier)
    (Left (InvalidTransition "the current Brick must be unfocused first"))
  replaceBrick identifier brick {brickWorkState = Idle} state

transitionBrickStatus ::
  BrickId -> BrickClosure -> UTCTime -> DomainState ->
  Either DomainError (Brick, DomainState)
transitionBrickStatus identifier closure changedAt state = do
  brick <- requireActiveBrick identifier state
  let activeChildren = directActiveChildren state identifier
  unless (null activeChildren)
    (Left (InvalidTransition "Brick has active children; use an explicit subtree or child-transfer action"))
  (nextStatus, replacement, reason) <- case closure of
    MarkDone -> do
      unless (behaviorLifetime (brickBehavior brick) == Finite)
        (Left (InvalidTransition "standing work must be explicitly retired"))
      Right (Done, Nothing, Nothing)
    MarkDropped -> Right (Dropped, Nothing, Nothing)
    MarkSuperseded replacementId supersedeReason -> do
      when (replacementId == identifier)
        (Left (InvalidRelationship "a Brick cannot supersede itself"))
      replacementBrick <- lookupBrick replacementId state
      unless (brickStatus replacementBrick == Active)
        (Left (InvalidRelationship "superseding Brick must be active"))
      unless (brickParent replacementBrick == brickParent brick)
        (Left (InvalidRelationship "superseding Bricks must be siblings"))
      Right (Superseded, Just replacementId, supersedeReason)
  let updated = brick
        { brickStatus = nextStatus
        , brickStatusChangedAt = changedAt
        , brickWorkState = Idle
        , brickSupersededBy = replacement
        , brickSupersedeReason = reason
        , brickRevision = bumpRevision (brickRevision brick)
        }
      focus = domainFocusRegister state
      nextFocus
        | focusRegisterCurrent focus == Just identifier = focus
            { focusRegisterCurrent = Nothing
            , focusRegisterChangedAt = Just changedAt
            , focusRegisterRevision = bumpRevision (focusRegisterRevision focus)
            }
        | otherwise = focus
      next = state
        { domainBricks = Map.insert identifier updated (domainBricks state)
        , domainFocusRegister = nextFocus
        }
  validateAndReturn updated next

retireStandingBrick ::
  BrickId -> UTCTime -> DomainState -> Either DomainError (Brick, DomainState)
retireStandingBrick identifier changedAt state = do
  brick <- requireActiveBrick identifier state
  unless (behaviorLifetime (brickBehavior brick) == Standing)
    (Left (InvalidTransition "only standing work uses explicit retirement"))
  unless (null (directActiveChildren state identifier))
    (Left (InvalidTransition "Brick has active children; use an explicit subtree action"))
  closeOneBrick identifier Done Nothing Nothing changedAt state

supersedeBrickWithChildren ::
  BrickId -> BrickId -> [BrickId] -> Maybe Text -> UTCTime -> DomainState ->
  Either DomainError (Brick, [Brick], DomainState)
supersedeBrickWithChildren identifier replacementId selected reason changedAt state = do
  brick <- requireActiveBrick identifier state
  replacement <- requireActiveBrick replacementId state
  when (identifier == replacementId)
    (Left (InvalidRelationship "a Brick cannot supersede itself"))
  unless (brickParent brick == brickParent replacement)
    (Left (InvalidRelationship "superseding Bricks must be siblings"))
  let activeChildren = directActiveChildren state identifier
      activeIds = map brickId activeChildren
  unless (not (null selected) && Set.fromList selected == Set.fromList activeIds
      && length selected == length activeIds)
    (Left (InvalidRelationship "selected children must name every active direct child exactly once"))
  selectedChildren <- mapM (\childId -> maybe
      (Left (InvalidRelationship "selected child is not active under source"))
      Right (find ((== childId) . brickId) activeChildren)) selected
  let moved =
        [ child
            { brickParent = Just replacementId
            , brickRevision = bumpRevision (brickRevision child)
            }
        | child <- selectedChildren
        ]
      movedById = Map.fromList [(brickId child, child) | child <- moved]
      replacementUpdated = replacement
        { brickDecompositionCoverage = Open
        , brickRevision = bumpRevision (brickRevision replacement)
        }
      beforeClose = state {domainBricks = Map.union movedById
        (Map.insert replacementId replacementUpdated (domainBricks state))}
  (closed, final) <- closeOneBrick identifier Superseded
    (Just replacementId) reason changedAt beforeClose
  validateDomainState final
  Right (closed, moved, final)

closeBrickSubtree ::
  BrickId -> BrickStatus -> UTCTime -> DomainState ->
  Either DomainError ([Brick], DomainState)
closeBrickSubtree root status changedAt state = do
  _ <- requireActiveBrick root state
  unless (status `elem` [Done, Dropped])
    (Left (InvalidTransition "a subtree can only be completed or dropped"))
  members <- subtreeBricks state root
  let active = filter ((== Active) . brickStatus) members
      activeIds = Set.fromList (map brickId active)
      close brick = brick
        { brickStatus = status
        , brickStatusChangedAt = changedAt
        , brickWorkState = Idle
        , brickSupersededBy = Nothing
        , brickSupersedeReason = Nothing
        , brickRevision = bumpRevision (brickRevision brick)
        }
      closed = map close active
      nextBricks = foldr (\brick -> Map.insert (brickId brick) brick)
        (domainBricks state) closed
      focus = domainFocusRegister state
      nextFocus = if maybe False (`Set.member` activeIds) (focusRegisterCurrent focus)
        then focus
          { focusRegisterCurrent = Nothing
          , focusRegisterChangedAt = Just changedAt
          , focusRegisterRevision = bumpRevision (focusRegisterRevision focus)
          }
        else focus
      next = state {domainBricks = nextBricks, domainFocusRegister = nextFocus}
  validateDomainState next
  Right (closed, next)

moveBrickSubtree ::
  BrickId -> Maybe BrickId -> DomainState ->
  Either DomainError (Brick, DomainState)
moveBrickSubtree identifier newParent state = do
  brick <- requireActiveBrick identifier state
  when (brickParent brick == newParent)
    (Left (InvalidRelationship "parent relationship is unchanged"))
  when (newParent == Just identifier)
    (Left (InvalidRelationship "a Brick cannot parent itself"))
  mapM_ (\parentId -> do
      parent <- requireActiveBrick parentId state
      rejectDescendant identifier state parentId
      pure parent) newParent
  let reopen parentId bricks = Map.adjust (\parent -> parent
        { brickDecompositionCoverage = Open
        , brickRevision = bumpRevision (brickRevision parent)
        }) parentId bricks
      moved = brick
        { brickParent = newParent
        , brickRevision = bumpRevision (brickRevision brick)
        }
      withMoved = Map.insert identifier moved (domainBricks state)
      withOld = maybe withMoved (`reopen` withMoved) (brickParent brick)
      withNew = maybe withOld (`reopen` withOld) newParent
      next = state {domainBricks = withNew}
  validateAndReturn moved next

subtreeBricks :: DomainState -> BrickId -> Either DomainError [Brick]
subtreeBricks state root = do
  rootBrick <- lookupBrick root state
  let collect brick = brick : concatMap collect
        [ child
        | child <- Map.elems (domainBricks state)
        , brickParent child == Just (brickId brick)
        ]
  pure (collect rootBrick)

closeOneBrick ::
  BrickId -> BrickStatus -> Maybe BrickId -> Maybe Text -> UTCTime ->
  DomainState -> Either DomainError (Brick, DomainState)
closeOneBrick identifier status replacement reason changedAt state = do
  brick <- requireActiveBrick identifier state
  let updated = brick
        { brickStatus = status
        , brickStatusChangedAt = changedAt
        , brickWorkState = Idle
        , brickSupersededBy = replacement
        , brickSupersedeReason = reason
        , brickRevision = bumpRevision (brickRevision brick)
        }
      focus = domainFocusRegister state
      nextFocus = if focusRegisterCurrent focus == Just identifier
        then focus
          { focusRegisterCurrent = Nothing
          , focusRegisterChangedAt = Just changedAt
          , focusRegisterRevision = bumpRevision (focusRegisterRevision focus)
          }
        else focus
      next = state
        { domainBricks = Map.insert identifier updated (domainBricks state)
        , domainFocusRegister = nextFocus
        }
  validateAndReturn updated next

validatePhaseSelection ::
  BrickBehavior -> Maybe BrickPhase -> Maybe Authority -> Either DomainError ()
validatePhaseSelection behavior phase authority = do
  when (behaviorPhase behavior == Disabled && isJust phase)
    (Left (InvalidRelationship "behavior disables phase"))
  unless (isJust phase == isJust authority)
    (Left (InvalidRelationship "phase and phase authority must be set together"))

------------------------------------------------------------
-- Relationships, derived values, and projections
------------------------------------------------------------

effectiveContext :: DomainState -> BrickId -> Either DomainError (Maybe Text)
effectiveContext state identifier = firstExplicit brickContext <$> lineage state identifier

effectiveMode :: DomainState -> BrickId -> Either DomainError (Maybe Mode)
effectiveMode state identifier = firstExplicit brickMode <$> lineage state identifier

effectiveNotBefore :: DomainState -> BrickId -> Either DomainError (Maybe UTCTime)
effectiveNotBefore state identifier = maximumMaybe . mapMaybe brickNotBefore
  <$> lineage state identifier

effectiveBestBefore :: DomainState -> BrickId -> Either DomainError (Maybe UTCTime)
effectiveBestBefore state identifier = minimumMaybe . mapMaybe brickBestBefore
  <$> lineage state identifier

effectiveDeadline :: DomainState -> BrickId -> Either DomainError (Maybe UTCTime)
effectiveDeadline state identifier = minimumMaybe . mapMaybe brickDeadline
  <$> lineage state identifier

effectiveDateRevision :: DomainState -> BrickId -> Either DomainError Text
effectiveDateRevision state identifier = do
  ancestors <- lineage state identifier
  pure (digestText (Text.intercalate "|"
    [unBrickId (brickId brick) <> ":" <> Text.pack (show (brickDateRevision brick))
    | brick <- ancestors]))

firstExplicit :: (value -> Maybe result) -> [value] -> Maybe result
firstExplicit _ [] = Nothing
firstExplicit project (value : rest) = case project value of
  Just result -> Just result
  Nothing -> firstExplicit project rest

maximumMaybe :: Ord value => [value] -> Maybe value
maximumMaybe [] = Nothing
maximumMaybe values = Just (maximum values)

minimumMaybe :: Ord value => [value] -> Maybe value
minimumMaybe [] = Nothing
minimumMaybe values = Just (minimum values)

lineage :: DomainState -> BrickId -> Either DomainError [Brick]
lineage state start = go Set.empty start
  where
    go visited identifier
      | Set.member identifier visited =
          Left (InvalidRelationship "Brick parent cycle")
      | otherwise = do
          brick <- lookupBrick identifier state
          rest <- maybe (Right []) (go (Set.insert identifier visited))
            (brickParent brick)
          Right (brick : rest)

partyProjection :: Party -> Value
partyProjection = toJSON

listEntryProjection :: ListEntry -> Value
listEntryProjection = toJSON

brickProjection :: DomainState -> BrickId -> Either DomainError Value
brickProjection state identifier = do
  brick <- lookupBrick identifier state
  context <- effectiveContext state identifier
  mode <- effectiveMode state identifier
  notBefore <- effectiveNotBefore state identifier
  bestBefore <- effectiveBestBefore state identifier
  deadline <- effectiveDeadline state identifier
  dateRevision <- effectiveDateRevision state identifier
  let children = filter ((== Just identifier) . brickParent)
        (Map.elems (domainBricks state))
      activeChildren = filter ((== Active) . brickStatus) children
      entries = filter ((== identifier) . listEntryOwner)
        (Map.elems (domainListEntries state))
      openEntries = filter ((== EntryOpen) . listEntryStatus) entries
      dormant = behaviorEmptyIsDormant (brickBehavior brick)
        && null activeChildren && null openEntries
      extra = object
        [ "children" .= map brickId children
        , "active_children" .= map brickId activeChildren
        , "entries" .= map listEntryId entries
        , "open_entries" .= map listEntryId openEntries
        , "is_active" .= (brickStatus brick == Active)
        , "has_active_children" .= not (null activeChildren)
        , "is_dormant" .= dormant
        , "phase_is_applicable" .= (behaviorPhase (brickBehavior brick) == Applicable)
        , "effort_is_applicable" .= (behaviorEffort (brickBehavior brick) == Applicable)
        , "effective_context" .= context
        , "effective_mode" .= mode
        , "effective_not_before" .= notBefore
        , "effective_best_before" .= bestBefore
        , "effective_deadline" .= deadline
        , "effective_date_revision" .= dateRevision
        ]
  case (toJSON brick, extra) of
    (Object base, Object derived) -> Right (Object (KeyMap.union base derived))
    _ -> Left (DomainInvariantViolation ["Brick projection is not an object"])

domainProjection :: DomainState -> Either DomainError Value
domainProjection state = do
  bricks <- mapM (brickProjection state . brickId)
    (Map.elems (domainBricks state))
  pure (object
    [ "next_identity_ordinal" .= domainNextIdentityOrdinal state
    , "parties" .= map partyProjection (Map.elems (domainParties state))
    , "behaviors" .= behaviorVersions (domainCatalog state)
    , "templates" .= templateVersions (domainCatalog state)
    , "bricks" .= bricks
    , "list_entries" .= map listEntryProjection
        (Map.elems (domainListEntries state))
    , "focus_register" .= domainFocusRegister state
    ])

------------------------------------------------------------
-- Invariants and helpers
------------------------------------------------------------

validateDomainState :: DomainState -> Either DomainError ()
validateDomainState state = case violations of
  [] -> Right ()
  _ -> Left (DomainInvariantViolation violations)
  where
    parties = Map.elems (domainParties state)
    bricks = Map.elems (domainBricks state)
    entries = Map.elems (domainListEntries state)
    allOpaqueIds = map (unPartyId . partyId) parties
      <> map (unBrickId . brickId) bricks
      <> map (unListEntryId . listEntryId) entries
    violations = concat
      [ ["next identity ordinal is negative" | domainNextIdentityOrdinal state < 0]
      , ["entity identities are not globally unique" |
          Set.size (Set.fromList allOpaqueIds) /= length allOpaqueIds]
      , ["Party map key differs from entity ID" |
          any (uncurry (/=)) [(key, partyId party) |
            (key, party) <- Map.toList (domainParties state)]]
      , ["Brick map key differs from entity ID" |
          any (uncurry (/=)) [(key, brickId brick) |
            (key, brick) <- Map.toList (domainBricks state)]]
      , ["ListEntry map key differs from entity ID" |
          any (uncurry (/=)) [(key, listEntryId entry) |
            (key, entry) <- Map.toList (domainListEntries state)]]
      , ["entity revision is not positive" |
          any ((< EntityRevision 1) . partyRevision) parties
          || any ((< EntityRevision 1) . brickRevision) bricks
          || any ((< EntityRevision 1) . listEntryRevision) entries]
      , ["opaque identity equals mutable display text" |
          any (\party -> unPartyId (partyId party) == partyLabel party) parties
          || any (\brick -> unBrickId (brickId brick) == brickTitle brick) bricks]
      , ["canonical Brick title is invalid" |
          any (not . canonicalEnglishText . brickTitle) bricks]
      , ["canonical ListEntry label is invalid" |
          any (not . canonicalEnglishText . listEntryLabel) entries]
      , ["Brick is its own parent" |
          any (\brick -> brickParent brick == Just (brickId brick)) bricks]
      , ["Brick relationship references an unknown entity" |
          any invalidBrickRelationship bricks]
      , ["terminal Brick is WIP" |
          any (\brick -> brickStatus brick /= Active && brickWorkState brick /= Idle) bricks]
      , ["Brick phase violates behavior or authority pairing" |
          any invalidPhase bricks]
      , ["Brick date revision is negative" |
          any ((< 0) . brickDateRevision) bricks]
      , ["superseded fields violate conditional presence" |
          any invalidSupersession bricks]
      , ["ListEntry owner does not support entries" |
          any invalidEntryOwner entries]
      , ["ListEntry terminal fields violate conditional presence" |
          any invalidEntryPresence entries]
      , ["focus register references a non-active or non-WIP Brick" | invalidFocus]
      , ["Brick composition contains a parent cycle" |
          any (hasParentCycle state . brickId) bricks]
      , catalogViolations (domainCatalog state)
      ]
    invalidBrickRelationship brick =
      maybe False (`Map.notMember` domainBricks state) (brickParent brick)
      || maybe False (`Map.notMember` domainBricks state) (brickAbout brick)
      || maybe False (`Map.notMember` domainParties state) (brickRequester brick)
    invalidPhase brick =
      (behaviorPhase (brickBehavior brick) == Disabled && isJust (brickPhase brick))
      || isJust (brickPhase brick) /= isJust (brickPhaseAuthority brick)
      || not (catalogContainsBehavior (domainCatalog state) (brickBehavior brick))
    invalidSupersession brick = case brickStatus brick of
      Superseded -> maybe True (`Map.notMember` domainBricks state)
        (brickSupersededBy brick)
      _ -> isJust (brickSupersededBy brick) || isJust (brickSupersedeReason brick)
    invalidEntryOwner entry = case Map.lookup (listEntryOwner entry) (domainBricks state) of
      Nothing -> True
      Just owner -> not (behaviorOwnsEntries (brickBehavior owner))
    invalidEntryPresence entry = case listEntryStatus entry of
      EntryOpen -> isJust (listEntryResolvedAt entry)
        || isJust (listEntryRemovedAt entry)
        || isJust (listEntryRemovalReason entry)
      EntryResolved -> not (isJust (listEntryResolvedAt entry))
        || isJust (listEntryRemovedAt entry)
        || isJust (listEntryRemovalReason entry)
      EntryRemoved -> not (isJust (listEntryRemovedAt entry))
        || isJust (listEntryResolvedAt entry)
    invalidFocus = case focusRegisterCurrent (domainFocusRegister state) of
      Nothing -> False
      Just identifier -> maybe True
        (\brick -> brickStatus brick /= Active || brickWorkState brick /= Wip)
        (Map.lookup identifier (domainBricks state))

catalogViolations :: DefinitionCatalog -> [Text]
catalogViolations catalog = concat
  [ ["behavior version key differs from value" |
      any (uncurry (/=)) [(key, behaviorKey behavior) |
        (key, behavior) <- Map.toList (catalogBehaviors catalog)]]
  , ["template version key differs from value" |
      any (uncurry (/=)) [(key, templateKey template) |
        (key, template) <- Map.toList (catalogTemplates catalog)]]
  , ["catalog contains invalid behavior configuration" |
      any (isLeft . behaviorConfigurationValid . behaviorConfiguration)
        (behaviorVersions catalog)]
  , ["template resolves an unpublished behavior" |
      any (not . catalogContainsBehavior catalog . templateBehavior)
        (templateVersions catalog)]
  ]

isLeft :: Either left right -> Bool
isLeft value = case value of
  Left _ -> True
  Right _ -> False

hasParentCycle :: DomainState -> BrickId -> Bool
hasParentCycle state start = go Set.empty start
  where
    go seen identifier
      | Set.member identifier seen = True
      | otherwise = case Map.lookup identifier (domainBricks state) >>= brickParent of
          Nothing -> False
          Just parent -> go (Set.insert identifier seen) parent

requireActiveBrick :: BrickId -> DomainState -> Either DomainError Brick
requireActiveBrick identifier state = do
  brick <- lookupBrick identifier state
  unless (brickStatus brick == Active)
    (Left (InvalidTransition "Brick status is terminal"))
  pure brick

requirePresent :: Text -> Maybe value -> Either DomainError ()
requirePresent problem value = unless (isJust value)
  (Left (InvalidTransition problem))

replaceActiveBrick ::
  BrickId -> Brick -> DomainState -> Either DomainError (Brick, DomainState)
replaceActiveBrick identifier replacement state = do
  _ <- requireActiveBrick identifier state
  replaceBrick identifier replacement state

replaceBrick ::
  BrickId -> Brick -> DomainState -> Either DomainError (Brick, DomainState)
replaceBrick identifier replacement state =
  let updated = replacement
        { brickRevision = bumpRevision (brickRevision replacement) }
      next = state
        {domainBricks = Map.insert identifier updated (domainBricks state)}
  in validateAndReturn updated next

directActiveChildren :: DomainState -> BrickId -> [Brick]
directActiveChildren state identifier =
  [ child
  | child <- Map.elems (domainBricks state)
  , brickParent child == Just identifier
  , brickStatus child == Active
  ]

lookupParty :: PartyId -> DomainState -> Either DomainError Party
lookupParty identifier state = maybe (Left (UnknownParty identifier)) Right
  (Map.lookup identifier (domainParties state))

lookupBrick :: BrickId -> DomainState -> Either DomainError Brick
lookupBrick identifier state = maybe (Left (UnknownBrick identifier)) Right
  (Map.lookup identifier (domainBricks state))

lookupListEntry :: ListEntryId -> DomainState -> Either DomainError ListEntry
lookupListEntry identifier state = maybe (Left (UnknownListEntry identifier)) Right
  (Map.lookup identifier (domainListEntries state))

validateAndReturn :: value -> DomainState -> Either DomainError (value, DomainState)
validateAndReturn value state = do
  validateDomainState state
  Right (value, state)

validateNonEmpty :: Text -> Text -> Either DomainError ()
validateNonEmpty field value = when (Text.null (Text.strip value))
  (Left (EmptyText field))

appendDistinct :: Eq value => value -> [value] -> [value]
appendDistinct value values = if value `elem` values then values else values <> [value]

bumpRevision :: EntityRevision -> EntityRevision
bumpRevision (EntityRevision revision) = EntityRevision (revision + 1)

allocatePartyId :: Integer -> (PartyId, Integer)
allocatePartyId ordinal = (PartyId (opaqueEntityId ordinal), ordinal + 1)

allocateBrickId :: Integer -> (BrickId, Integer)
allocateBrickId ordinal = (BrickId (opaqueEntityId ordinal), ordinal + 1)

allocateListEntryId :: Integer -> (ListEntryId, Integer)
allocateListEntryId ordinal = (ListEntryId (opaqueEntityId ordinal), ordinal + 1)

opaqueEntityId :: Integer -> Text
opaqueEntityId ordinal = "la1_" <> digestText
  ("little-ant-v1:entity:" <> Text.pack (show ordinal))

digestText :: Text -> Text
digestText = Text.pack . showDigest . sha256 . LBS.fromStrict
  . TextEncoding.encodeUtf8

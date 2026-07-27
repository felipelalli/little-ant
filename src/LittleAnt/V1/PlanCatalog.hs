{-# LANGUAGE DerivingStrategies #-}

-- | Semantic Allium conformance probes backed by the real v1 kernel and
-- domain model. Registrations are keyed by module, category, and source
-- construct; obligation identifiers are deliberately unavailable here.
module LittleAnt.V1.PlanCatalog
  ( domainPlanProbes
  , kernelPlanProbes
  , v1PlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson
  (Object, ToJSON (toJSON), Value (..), encode)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (find)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Domain
import LittleAnt.V1.JudgmentPlanCatalog (priorityPlanProbes)
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..),
   EventBatch (..), EventEnvelope (..), KernelError (..), OpaqueId (..),
   ProposedEvent (..), ReplayResult (..), appendSemanticAction,
   emptyKernelState, kernelEntity, kernelEventBatches, kernelRevision,
   kernelValue, replayAll)
import LittleAnt.V1.MaterialPlanCatalog (materialPlanProbes)

v1PlanProbes :: Map ProbeKey PlanProbe
v1PlanProbes = Map.unions
  [ kernelPlanProbes
  , domainPlanProbes
  , materialPlanProbes
  , priorityPlanProbes
  ]

kernelPlanProbes :: Map ProbeKey PlanProbe
kernelPlanProbes = Map.fromList
  [ (ProbeKey "interaction" "contract_signature" "CanonicalEventStore.append",
      appendProbe)
  , (ProbeKey "interaction" "contract_signature" "CanonicalEventStore.replay",
      replayProbe)
  , (ProbeKey "root" "invariant" "GloballyOpaqueEntityIds", opaqueIdentityProbe)
  ]

domainPlanProbes :: Map ProbeKey PlanProbe
domainPlanProbes = Map.fromList
  ( enumRegistrations
  <> entityFieldRegistrations
  <> optionalFieldRegistrations
  <> catalogRegistrations
  <> partyRuleRegistrations
  <> behaviorRuleRegistrations
  <> templateRuleRegistrations
  <> invariantRegistrations
  <> surfaceRegistrations
  )

appendProbe :: PlanProbe
appendProbe input = do
  checkMetadata "interaction" "contract_signature"
    "CanonicalEventStore.append" input
  accepted <- mapKernelError (appendSemanticAction multiEventRequest emptyKernelState)
  let next = appendResultState accepted
      batch = appendResultBatch accepted
      envelopes = eventBatchEvents batch
  require (kernelRevision next == DomainRevision 1)
    "accepted action did not advance the domain revision exactly once"
  require (length (kernelEventBatches next) == 1)
    "accepted action did not commit exactly one event batch"
  require (length envelopes == 2)
    "atomic event batch did not retain all proposed events"
  require (map eventIndexInAction envelopes == [0, 1])
    "event envelopes do not preserve action-local order"
  require (all ((== DomainRevision 1) . eventDomainRevision) envelopes)
    "events in one semantic action do not share its revision"
  require (kernelValue "first" next == Just (String "accepted"))
    "first event was not projected"
  require (kernelValue "second" next == Just (toJSON (2 :: Int)))
    "second event was not projected"
  case appendSemanticAction
      (multiEventRequest {appendExpectedRevision = DomainRevision 0}) next of
    Left (RevisionConflict (DomainRevision 0) (DomainRevision 1)) -> pure ()
    Left problem -> Left ("unexpected optimistic-append rejection: "
      <> Text.pack (show problem))
    Right _ -> Left "stale append unexpectedly succeeded"
  require (encode next == encode (appendResultState accepted))
    "rejected append mutated previously accepted state"

replayProbe :: PlanProbe
replayProbe input = do
  checkMetadata "interaction" "contract_signature"
    "CanonicalEventStore.replay" input
  first <- mapKernelError
    (appendSemanticAction multiEventRequest emptyKernelState)
  second <- mapKernelError (appendSemanticAction
    AppendRequest
      { appendExpectedRevision = DomainRevision 1
      , appendSemanticActionId = "probe:replay:second"
      , appendActorOrOrigin = "core:contract-probe"
      , appendOccurredAt = Just "2026-07-27T00:00:01Z"
      , appendProposedEvents = [ProposeValueRemoved "first"]
      }
    (appendResultState first))
  replayed <- mapKernelError
    (replayAll (kernelEventBatches (appendResultState second)))
  require (encode (replayResultState replayed)
      == encode (appendResultState second))
    "deterministic replay did not reconstruct byte-equivalent state"
  require (null (replayResultExternalTrace replayed))
    "canonical replay produced an external adapter trace"

opaqueIdentityProbe :: PlanProbe
opaqueIdentityProbe input = do
  checkMetadata "root" "invariant" "GloballyOpaqueEntityIds" input
  accepted <- mapKernelError (appendSemanticAction
    AppendRequest
      { appendExpectedRevision = DomainRevision 0
      , appendSemanticActionId = "probe:opaque-identities"
      , appendActorOrOrigin = "core:contract-probe"
      , appendOccurredAt = Nothing
      , appendProposedEvents =
          [ ProposeEntityCreated "brick" (objectFields "Repeated title")
          , ProposeEntityCreated "party" (objectFields "Repeated title")
          ]
      }
    emptyKernelState)
  case appendResultAllocatedIds accepted of
    [first@(OpaqueId firstText), second@(OpaqueId secondText)] -> do
      require (first /= second) "two creations reused one entity identity"
      require (not ("Repeated title" `Text.isInfixOf` firstText))
        "entity identity contains its display title"
      require (not ("Repeated title" `Text.isInfixOf` secondText))
        "entity identity contains its display title"
      require (kernelEntity first (appendResultState accepted) /= Nothing)
        "first allocated entity is absent after append"
      require (kernelEntity second (appendResultState accepted) /= Nothing)
        "second allocated entity is absent after append"
    identifiers -> Left ("identity probe allocated an unexpected number of IDs: "
      <> Text.pack (show identifiers))

------------------------------------------------------------
-- Domain probes
------------------------------------------------------------

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ enumRegistration "Authority"
      [toJSON Human, toJSON Ai, toJSON Adapter, toJSON Core]
  , enumRegistration "PartyType"
      [toJSON Person, toJSON AiAgent, toJSON Company, toJSON Area]
  , enumRegistration "BrickStatus"
      [toJSON Active, toJSON Done, toJSON Dropped, toJSON Superseded]
  , enumRegistration "BrickPhase"
      [toJSON Idea, toJSON Spec, toJSON Exec, toJSON Validation]
  , enumRegistration "WorkState" [toJSON Idle, toJSON Wip]
  , enumRegistration "Atomicity"
      [toJSON Atomic, toJSON Divisible, toJSON Unknown]
  , enumRegistration "Mode"
      [toJSON Digital, toJSON Physical, toJSON Hybrid, toJSON Any]
  , enumRegistration "DecompositionCoverage"
      [toJSON NotApplicable, toJSON Open, toJSON Complete]
  , enumRegistration "FocusUnit"
      [toJSON BrickFocus, toJSON ChildrenFocus, toJSON BatchFocus]
  , enumRegistration "Lifetime" [toJSON Finite, toJSON Standing]
  , enumRegistration "Applicability" [toJSON Applicable, toJSON Disabled]
  , enumRegistration "RepetitionKind"
      [ toJSON NoRepetition, toJSON CompletionTriggered
      , toJSON RecurringObligation, toJSON Practice
      ]
  , enumRegistration "ListEntryStatus"
      [toJSON EntryOpen, toJSON EntryResolved, toJSON EntryRemoved]
  ]

enumRegistration :: Text -> [Value] -> (ProbeKey, PlanProbe)
enumRegistration construct values =
  ( ProbeKey "domain" "enum_comparable" construct
  , semanticProbe "enum_comparable" construct $ do
      require (not (null values)) "closed enum has no constructors"
      require (Set.size (Set.fromList (map encode values)) == length values)
        "closed enum constructors do not have unique canonical encodings"
      require (all isCanonicalEnumValue values)
        "closed enum did not encode as canonical English text"
  )

isCanonicalEnumValue :: Value -> Bool
isCanonicalEnumValue value = case value of
  String text -> not (Text.null text) && Text.toLower text == text
  _ -> False

entityFieldRegistrations :: [(ProbeKey, PlanProbe)]
entityFieldRegistrations =
  [ entityFields "Party"
      ["id", "label", "party_type", "alternate_labels", "created_at"]
  , entityFields "BrickBehavior"
      [ "id", "namespace", "version", "focus_unit", "lifetime"
      , "owns_entries", "renders_all_open_entries", "empty_is_dormant"
      , "phase", "effort", "repetition"
      ]
  , entityFields "BrickTemplate"
      [ "id", "namespace", "version", "display_name", "category", "purpose"
      , "search_terms", "behavior", "default_title", "default_description"
      ]
  , entityFields "Brick"
      [ "id", "title", "original_title", "title_authority", "description"
      , "description_revision", "status", "phase", "phase_authority"
      , "work_state", "behavior", "parent", "atomicity", "context", "mode"
      , "about", "requester", "not_before", "best_before", "deadline"
      , "date_revision", "decomposition_coverage", "created_at"
      , "status_changed_at", "superseded_by", "supersede_reason", "children"
      , "active_children", "entries", "open_entries", "is_active"
      , "has_active_children", "is_dormant", "phase_is_applicable"
      , "effort_is_applicable", "effective_context", "effective_mode"
      , "effective_not_before", "effective_best_before", "effective_deadline"
      , "effective_date_revision"
      ]
  , entityFields "ListEntry"
      [ "id", "owner", "label", "original_label", "label_authority"
      , "quantity", "note", "status", "created_at", "resolved_at"
      , "removed_at", "removal_reason"
      ]
  , entityFields "FocusRegister" ["current", "changed_at"]
  ]

entityFields :: Text -> [Text] -> (ProbeKey, PlanProbe)
entityFields construct fields =
  ( ProbeKey "domain" "entity_fields" construct
  , semanticProbe "entity_fields" construct $ do
      value <- entityFixtureValue construct
      objectValue <- asObject construct value
      let present = Set.fromList (map Key.toText (KeyMap.keys objectValue))
      require (all (`Set.member` present) fields)
        (construct <> " projection omits one or more declared fields")
      requireEntityFieldTypes construct objectValue
  )

optionalFieldRegistrations :: [(ProbeKey, PlanProbe)]
optionalFieldRegistrations = map optionalField
  [ "BrickTemplate.default_title"
  , "BrickTemplate.default_description"
  , "Brick.original_title"
  , "Brick.description"
  , "Brick.phase"
  , "Brick.phase_authority"
  , "Brick.parent"
  , "Brick.mode"
  , "Brick.about"
  , "Brick.requester"
  , "Brick.not_before"
  , "Brick.best_before"
  , "Brick.deadline"
  , "Brick.supersede_reason"
  , "ListEntry.original_label"
  , "ListEntry.quantity"
  , "ListEntry.note"
  , "ListEntry.removal_reason"
  , "FocusRegister.current"
  , "FocusRegister.changed_at"
  ]

optionalField :: Text -> (ProbeKey, PlanProbe)
optionalField construct =
  ( ProbeKey "domain" "entity_optional" construct
  , semanticProbe "entity_optional" construct $ do
      value <- optionalEntityFixtureValue construct
      objectValue <- asObject construct value
      let field = Text.takeWhileEnd (/= '.') construct
      require (KeyMap.lookup (Key.fromText field) objectValue == Just Null)
        (construct <> " does not represent the absent optional value")
  )

catalogRegistrations :: [(ProbeKey, PlanProbe)]
catalogRegistrations = map registration
  ["DefinitionCatalog.find_behaviors", "DefinitionCatalog.find_templates"]
  where
    registration construct =
      ( ProbeKey "domain" "contract_signature" construct
      , semanticProbe "contract_signature" construct catalogContractProbe
      )

partyRuleRegistrations :: [(ProbeKey, PlanProbe)]
partyRuleRegistrations =
  [ ruleRegistration "rule_success" "PartyCreated" partyRulesProbe
  , ruleRegistration "rule_entity_creation" "PartyCreated" partyRulesProbe
  , ruleRegistration "rule_success" "PartyRenamed" partyRulesProbe
  , ruleRegistration "rule_success" "AlternatePartyLabelAdded" partyRulesProbe
  , ruleRegistration "rule_failure" "AlternatePartyLabelAdded" partyRulesProbe
  ]

behaviorRuleRegistrations :: [(ProbeKey, PlanProbe)]
behaviorRuleRegistrations =
  [ ruleRegistration category construct behaviorRulesProbe
  | (category, construct) <-
      [ ("rule_success", "PersonalBehaviorVersionPublished")
      , ("rule_failure", "PersonalBehaviorVersionPublished")
      , ("rule_entity_creation", "PersonalBehaviorVersionPublished")
      , ("rule_success", "EquivalentBehaviorReused")
      , ("rule_failure", "EquivalentBehaviorReused")
      ]
  ]

templateRuleRegistrations :: [(ProbeKey, PlanProbe)]
templateRuleRegistrations =
  [ ruleRegistration category "PersonalTemplateVersionPublished" templateRulesProbe
  | category <- ["rule_success", "rule_failure", "rule_entity_creation"]
  ]

ruleRegistration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
ruleRegistration category construct probe =
  (ProbeKey "domain" category construct, semanticProbe category construct probe)

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ ( ProbeKey "domain" "invariant" construct
    , semanticProbe "invariant" construct (domainInvariantProbe construct)
    )
  | construct <-
      [ "OpaqueEntityIdentity"
      , "CanonicalWorkTitlesAreEnglish"
      , "NoSelfParent"
      , "OneFocusRegister"
      , "BehaviorVersionIdentityIsUnique"
      , "TemplateVersionIdentityIsUnique"
      , "EntryOwnerSupportsEntries"
      , "TerminalBrickIsNotWip"
      , "PhaseRespectsBehavior"
      ]
  ]

surfaceRegistrations :: [(ProbeKey, PlanProbe)]
surfaceRegistrations =
  [ ( ProbeKey "domain" category "DefinitionLibrary"
    , semanticProbe category "DefinitionLibrary" definitionLibraryProbe
    )
  | category <- ["surface_actor", "surface_exposure", "surface_provides"]
  ]

semanticProbe :: Text -> Text -> Either Text () -> PlanProbe
semanticProbe category construct probe input = do
  checkMetadata "domain" category construct input
  probe

entityFixtureValue :: Text -> Either Text Value
entityFixtureValue construct = do
  sample <- sampleDomain
  case construct of
    "Party" -> Right (partyProjection (sampleParty sample))
    "BrickBehavior" -> Right (toJSON standardV1)
    "BrickTemplate" -> Right (toJSON (sampleTemplate sample))
    "Brick" -> mapDomainError
      (brickProjection (sampleState sample) (brickId (sampleBrick sample)))
    "ListEntry" -> Right (listEntryProjection (sampleEntry sample))
    "FocusRegister" -> Right (toJSON (domainFocusRegister (sampleState sample)))
    _ -> Left ("no entity fixture for semantic construct: " <> construct)

optionalEntityFixtureValue :: Text -> Either Text Value
optionalEntityFixtureValue construct
  | "BrickTemplate." `Text.isPrefixOf` construct = do
      templates <- mapDomainError
        (findTemplates "packing" Nothing Nothing 1 initialDefinitionCatalog)
      case templates of
        [template] -> Right (toJSON template)
        _ -> Left "packing template fixture is unavailable"
  | "Brick." `Text.isPrefixOf` construct = do
      sample <- optionalSampleDomain
      mapDomainError (brickProjection (sampleState sample)
        (brickId (sampleBrick sample)))
  | "ListEntry." `Text.isPrefixOf` construct = do
      sample <- optionalSampleDomain
      Right (toJSON (sampleEntry sample))
  | "FocusRegister." `Text.isPrefixOf` construct =
      Right (toJSON (domainFocusRegister emptyDomainState))
  | otherwise = Left ("no optional fixture for semantic construct: " <> construct)

requireEntityFieldTypes :: Text -> Object -> Either Text ()
requireEntityFieldTypes construct fields = case construct of
  "Party" -> do
    requireString "id"
    requireInteger "revision"
    requireString "label"
    requireArray "alternate_labels"
  "BrickBehavior" -> do
    requireString "id"
    requireInteger "version"
    requireBoolean "owns_entries"
    requireBoolean "renders_all_open_entries"
  "BrickTemplate" -> do
    requireString "display_name"
    requireArray "search_terms"
    requireObject "behavior"
  "Brick" -> do
    requireString "id"
    requireInteger "revision"
    requireString "title"
    requireObject "behavior"
    requireArray "children"
    requireBoolean "is_active"
  "ListEntry" -> do
    requireString "id"
    requireObjectOrString "owner"
    requireString "label"
  "FocusRegister" -> requireInteger "revision"
  _ -> Left ("unknown entity type check: " <> construct)
  where
    field name = maybe (Left ("missing field: " <> name)) Right
      (KeyMap.lookup (Key.fromText name) fields)
    requireString name = field name >>= \case
      String _ -> Right ()
      _ -> Left (name <> " must be text")
    requireInteger name = field name >>= \case
      Number _ -> Right ()
      _ -> Left (name <> " must be an integer")
    requireArray name = field name >>= \case
      Array _ -> Right ()
      _ -> Left (name <> " must be an array")
    requireBoolean name = field name >>= \case
      Bool _ -> Right ()
      _ -> Left (name <> " must be Boolean")
    requireObject name = field name >>= \case
      Object _ -> Right ()
      _ -> Left (name <> " must be an object")
    requireObjectOrString name = field name >>= \case
      Object _ -> Right ()
      String _ -> Right ()
      _ -> Left (name <> " must be a relationship reference")

catalogContractProbe :: Either Text ()
catalogContractProbe = do
  behaviors <- mapDomainError
    (findBehaviors "core" Nothing 3 initialDefinitionCatalog)
  require (length behaviors == 3) "behavior discovery is not page-bounded"
  require (all ((== "core") . behaviorNamespace) behaviors)
    "behavior discovery did not return resolved namespace/version data"
  nextBehaviors <- mapDomainError
    (findBehaviors "core" (Just "offset:3") 3 initialDefinitionCatalog)
  require (not (null nextBehaviors) && null (filter (`elem` behaviors) nextBehaviors))
    "behavior cursor did not advance deterministically"
  templates <- mapDomainError
    (findTemplates "shopping" (Just "checklists") Nothing 5
      initialDefinitionCatalog)
  require (map templateId templates == ["standard/grocery_list"])
    "template discovery did not apply query and category"
  case findTemplates "" Nothing Nothing 51 initialDefinitionCatalog of
    Left (InvalidPageSize 51) -> Right ()
    result -> Left ("unbounded catalog request was not rejected: "
      <> Text.pack (show result))

partyRulesProbe :: Either Text ()
partyRulesProbe = do
  (created, first) <- mapDomainError
    (createParty "Ada" Person sampleTime emptyDomainState)
  require (partyRevision created == EntityRevision 1)
    "Party creation did not start its entity revision"
  require (unPartyId (partyId created) /= partyLabel created)
    "Party ID was derived from its label"
  (renamed, second) <- mapDomainError
    (renameParty (partyId created) "Ada Lovelace" first)
  require (partyId renamed == partyId created)
    "Party identity changed during rename"
  require (partyAlternateLabels renamed == ["Ada"])
    "Party rename did not retain its prior label"
  (withAlternate, third) <- mapDomainError
    (addAlternatePartyLabel (partyId renamed) "A. Lovelace" second)
  require (partyRevision withAlternate == EntityRevision 3)
    "Party transitions did not advance per-entity revision"
  case addAlternatePartyLabel (partyId renamed) "Ada Lovelace" third of
    Left (AlternateLabelMatchesCurrent _) -> Right ()
    result -> Left ("current label was accepted as an alternate: "
      <> Text.pack (show result))
  case addAlternatePartyLabel (partyId renamed) "A. Lovelace" third of
    Left (AlternateLabelAlreadyPresent _) -> Right ()
    result -> Left ("duplicate alternate label was accepted: "
      <> Text.pack (show result))

behaviorRulesProbe :: Either Text ()
behaviorRulesProbe = do
  let firstConfiguration = BehaviorConfiguration
        BrickFocus Standing False False False Disabled Applicable NoRepetition
      firstDraft = BehaviorDraft "personal/deep_work" "personal/test" 1
        firstConfiguration
  (firstResult, firstCatalog) <- mapDomainError
    (publishPersonalBehavior firstDraft initialDefinitionCatalog)
  first <- case firstResult of
    Published behavior -> Right behavior
    _ -> Left "new behavior configuration was not published"
  require (behaviorVersion first == 1 && behaviorRevision first == EntityRevision 1)
    "published behavior version has invalid identity or revision"
  let secondConfiguration = BehaviorConfiguration
        BrickFocus Finite False False False Applicable Disabled NoRepetition
      secondDraft = firstDraft
        { behaviorDraftVersion = 2
        , behaviorDraftConfiguration = secondConfiguration
        }
  (secondResult, secondCatalog) <- mapDomainError
    (publishPersonalBehavior secondDraft firstCatalog)
  second <- case secondResult of
    Published behavior -> Right behavior
    _ -> Left "second immutable behavior version was not published"
  require (behaviorVersion second == 2)
    "second behavior version did not use the next version"
  require (find ((== behaviorKeyTuple first) . behaviorKeyTuple)
      (behaviorVersions secondCatalog) == Just first)
    "publishing a later behavior version mutated the first version"
  let equivalentDraft = BehaviorDraft "personal/duplicate_standard"
        "personal/test" 99 (behaviorConfiguration standardV1)
  (equivalentResult, equivalentCatalog) <- mapDomainError
    (publishPersonalBehavior equivalentDraft secondCatalog)
  case equivalentResult of
    ExistingDefinitionSelected existing ->
      require (existing == standardV1 && equivalentCatalog == secondCatalog)
        "equivalent behavior did not reuse the exact published definition"
    _ -> Left "equivalent behavior created a duplicate definition"
  case publishPersonalBehavior
      (firstDraft {behaviorDraftNamespace = "core"}) initialDefinitionCatalog of
    Left (NamespaceIsNotPersonal "core") -> Right ()
    result -> Left ("non-personal behavior publication was accepted: "
      <> Text.pack (show result))
  case publishPersonalBehavior
      (firstDraft {behaviorDraftVersion = 2}) initialDefinitionCatalog of
    Left (VersionMustBe 1 2) -> Right ()
    result -> Left ("out-of-sequence behavior version was accepted: "
      <> Text.pack (show result))
  let invalidConfiguration = firstConfiguration
        {configurationRendersAllOpenEntries = True}
  case publishPersonalBehavior
      (firstDraft {behaviorDraftConfiguration = invalidConfiguration})
      initialDefinitionCatalog of
    Left (InvalidBehaviorConfiguration _) -> Right ()
    result -> Left ("invalid behavior configuration was accepted: "
      <> Text.pack (show result))

behaviorKeyTuple :: BrickBehavior -> (Text, Text, Integer)
behaviorKeyTuple behavior =
  (behaviorId behavior, behaviorNamespace behavior, behaviorVersion behavior)

templateRulesProbe :: Either Text ()
templateRulesProbe = do
  let firstDraft = TemplateDraft
        { templateDraftId = "personal/deep_work_template"
        , templateDraftNamespace = "personal/test"
        , templateDraftVersion = 1
        , templateDraftDisplayName = "Deep work"
        , templateDraftCategory = "focus"
        , templateDraftPurpose = "Create a finite focused unit."
        , templateDraftSearchTerms = ["focus", "deep work"]
        , templateDraftBehavior = standardV1
        , templateDraftDefaultTitle = Just "Focus deeply"
        , templateDraftDefaultDescription = Nothing
        }
  (first, firstCatalog) <- mapDomainError
    (publishPersonalTemplate firstDraft initialDefinitionCatalog)
  let secondDraft = firstDraft
        { templateDraftVersion = 2
        , templateDraftDefaultTitle = Just "Focus deeply today"
        }
  (second, secondCatalog) <- mapDomainError
    (publishPersonalTemplate secondDraft firstCatalog)
  require (templateVersion second == 2)
    "template did not publish the next immutable version"
  require (find ((== templateKeyTuple first) . templateKeyTuple)
      (templateVersions secondCatalog) == Just first)
    "publishing a later template version mutated an earlier version"
  case publishPersonalTemplate
      (firstDraft {templateDraftNamespace = "standard"}) initialDefinitionCatalog of
    Left (NamespaceIsNotPersonal "standard") -> Right ()
    result -> Left ("non-personal template was accepted: "
      <> Text.pack (show result))
  case publishPersonalTemplate
      (firstDraft {templateDraftVersion = 2}) initialDefinitionCatalog of
    Left (VersionMustBe 1 2) -> Right ()
    result -> Left ("out-of-sequence template version was accepted: "
      <> Text.pack (show result))
  case publishPersonalTemplate
      (firstDraft {templateDraftDefaultTitle = Just " invalid "})
      initialDefinitionCatalog of
    Left (InvalidCanonicalEnglish _) -> Right ()
    result -> Left ("invalid canonical default title was accepted: "
      <> Text.pack (show result))

templateKeyTuple :: BrickTemplate -> (Text, Text, Integer)
templateKeyTuple template =
  (templateId template, templateNamespace template, templateVersion template)

domainInvariantProbe :: Text -> Either Text ()
domainInvariantProbe construct = do
  sample <- sampleDomain
  mapDomainError (validateDomainState (sampleState sample))
  case construct of
    "OpaqueEntityIdentity" -> do
      let party = sampleParty sample
          brick = sampleBrick sample
          entry = sampleEntry sample
          identifiers =
            [unPartyId (partyId party), unBrickId (brickId brick),
             unListEntryId (listEntryId entry)]
      require (Set.size (Set.fromList identifiers) == length identifiers)
        "typed domain entities did not receive globally unique IDs"
      require (all (not . Text.isInfixOf "Plan migration") identifiers)
        "opaque identity contains mutable canonical text"
    "CanonicalWorkTitlesAreEnglish" -> do
      require (brickOriginalTitle (sampleBrick sample) == Just "Planejar migração")
        "verbatim source title was not preserved separately"
      require (listEntryOriginalLabel (sampleEntry sample) == Just "Leite")
        "verbatim source entry label was not preserved separately"
      case mkCanonicalText " invalid " Nothing Human of
        Left (InvalidCanonicalEnglish _) -> Right ()
        result -> Left ("invalid canonical text was accepted: "
          <> Text.pack (show result))
    "NoSelfParent" ->
      case setBrickParent (brickId (sampleBrick sample))
          (Just (brickId (sampleBrick sample))) (sampleState sample) of
        Left (InvalidRelationship _) -> Right ()
        result -> Left ("self-parent relationship was accepted: "
          <> Text.pack (show result))
    "OneFocusRegister" -> do
      let current = focusRegisterCurrent (domainFocusRegister (sampleState sample))
      require (current == Just (brickId (sampleBrick sample)))
        "singleton focus register did not retain the selected Brick"
    "BehaviorVersionIdentityIsUnique" -> do
      let versions = map behaviorKeyTuple
            (behaviorVersions (domainCatalog (sampleState sample)))
      require (Set.size (Set.fromList versions) == length versions)
        "behavior version identities are not unique"
      behaviorRulesProbe
    "TemplateVersionIdentityIsUnique" -> do
      let versions = map templateKeyTuple
            (templateVersions (domainCatalog (sampleState sample)))
      require (Set.size (Set.fromList versions) == length versions)
        "template version identities are not unique"
      templateRulesProbe
    "EntryOwnerSupportsEntries" -> do
      label <- mapDomainError (mkCanonicalText "Unsupported entry" Nothing Human)
      let invalidDraft = ListEntryDraft
            (brickId (sampleBrick sample)) label Nothing Nothing sampleTime
      case createListEntry invalidDraft (sampleState sample) of
        Left (InvalidRelationship _) -> Right ()
        result -> Left ("entry on non-entry behavior was accepted: "
          <> Text.pack (show result))
    "TerminalBrickIsNotWip" -> terminalWorkInvariantProbe
    "PhaseRespectsBehavior" -> phaseInvariantProbe
    _ -> Left ("unknown domain invariant probe: " <> construct)

terminalWorkInvariantProbe :: Either Text ()
terminalWorkInvariantProbe = do
  title <- mapDomainError (mkCanonicalText "Terminal work" Nothing Human)
  (brick, first) <- mapDomainError
    (createBrick (ordinaryBrickDraft title standardV1 sampleTime) emptyDomainState)
  (_, second) <- mapDomainError (setBrickWorkState (brickId brick) Wip first)
  (_, third) <- mapDomainError (focusBrick (Just (brickId brick)) sampleTime second)
  (terminal, fourth) <- mapDomainError
    (transitionBrickStatus (brickId brick) MarkDone sampleTime third)
  require (brickWorkState terminal == Idle)
    "terminal transition did not clear WIP"
  require (focusRegisterCurrent (domainFocusRegister fourth) == Nothing)
    "terminal transition did not clear focus"
  case setBrickWorkState (brickId brick) Wip fourth of
    Left (InvalidTransition _) -> Right ()
    result -> Left ("terminal Brick re-entered WIP: " <> Text.pack (show result))

phaseInvariantProbe :: Either Text ()
phaseInvariantProbe = do
  title <- mapDomainError (mkCanonicalText "Collection" Nothing Human)
  let invalidDraft = (ordinaryBrickDraft title collectionV1 sampleTime)
        {brickDraftPhase = Just Idea, brickDraftPhaseAuthority = Just Human}
  case createBrick invalidDraft emptyDomainState of
    Left (InvalidRelationship _) -> Right ()
    result -> Left ("phase-disabled behavior accepted a phase: "
      <> Text.pack (show result))
  (brick, state) <- mapDomainError
    (createBrick (ordinaryBrickDraft title standardV1 sampleTime) emptyDomainState)
  (updated, _) <- mapDomainError
    (setBrickPhase (brickId brick) (Just Validation) (Just Human) state)
  require (brickPhase updated == Just Validation
      && brickPhaseAuthority updated == Just Human)
    "phase-applicable behavior did not retain phase authority"

definitionLibraryProbe :: Either Text ()
definitionLibraryProbe = do
  partyRulesProbe
  behaviorRulesProbe
  templateRulesProbe
  catalogContractProbe
  (user, _) <- mapDomainError (createParty "User" Person sampleTime emptyDomainState)
  require (partyType user == Person && not (Text.null (unPartyId (partyId user))))
    "DefinitionLibrary user is not identified by an opaque person Party"

------------------------------------------------------------
-- Real sample constructors shared by probes and protocol fixtures
------------------------------------------------------------

data SampleDomain = SampleDomain
  { sampleState :: DomainState
  , sampleParty :: Party
  , sampleBrick :: Brick
  , sampleEntry :: ListEntry
  , sampleTemplate :: BrickTemplate
  }

sampleDomain :: Either Text SampleDomain
sampleDomain = do
  (party, first) <- mapDomainError
    (createParty "Ada" Person sampleTime emptyDomainState)
  title <- mapDomainError
    (mkCanonicalText "Plan migration" (Just "Planejar migração") Human)
  let brickDraft = (ordinaryBrickDraft title standardV1 sampleTime)
        { brickDraftPhase = Just Spec
        , brickDraftPhaseAuthority = Just Human
        , brickDraftContext = Just "computer"
        , brickDraftRequester = Just (partyId party)
        }
  (brick, second) <- mapDomainError (createBrick brickDraft first)
  checklistTitle <- mapDomainError
    (mkCanonicalText "Buy groceries" Nothing Core)
  (checklist, third) <- mapDomainError
    (createBrick (ordinaryBrickDraft checklistTitle standingChecklistV1 sampleTime)
      second)
  entryLabel <- mapDomainError
    (mkCanonicalText "Milk" (Just "Leite") Human)
  (entry, fourth) <- mapDomainError
    (createListEntry (ListEntryDraft (brickId checklist) entryLabel
      (Just 2) (Just "Whole milk") sampleTime) third)
  (_, fifth) <- mapDomainError
    (focusBrick (Just (brickId brick)) sampleTime fourth)
  templates <- mapDomainError
    (findTemplates "grocery" Nothing Nothing 1 (domainCatalog fifth))
  template <- case templates of
    [value] -> Right value
    _ -> Left "grocery template fixture is unavailable"
  Right SampleDomain
    { sampleState = fifth
    , sampleParty = party
    , sampleBrick = brick
    , sampleEntry = entry
    , sampleTemplate = template
    }

optionalSampleDomain :: Either Text SampleDomain
optionalSampleDomain = do
  title <- mapDomainError (mkCanonicalText "Plain work" Nothing Human)
  (brick, first) <- mapDomainError
    (createBrick (ordinaryBrickDraft title standardV1 sampleTime) emptyDomainState)
  checklistTitle <- mapDomainError
    (mkCanonicalText "Plain checklist" Nothing Human)
  (checklist, second) <- mapDomainError
    (createBrick (ordinaryBrickDraft checklistTitle finiteChecklistV1 sampleTime) first)
  entryLabel <- mapDomainError (mkCanonicalText "Plain entry" Nothing Human)
  (entry, third) <- mapDomainError
    (createListEntry (ListEntryDraft (brickId checklist) entryLabel Nothing Nothing
      sampleTime) second)
  templates <- mapDomainError
    (findTemplates "packing" Nothing Nothing 1 (domainCatalog third))
  template <- case templates of
    [value] -> Right value
    _ -> Left "packing template fixture is unavailable"
  let placeholderParty = Party (PartyId "unused") (EntityRevision 1)
        "Unused" Person [] sampleTime
  Right SampleDomain
    { sampleState = third
    , sampleParty = placeholderParty
    , sampleBrick = brick
    , sampleEntry = entry
    , sampleTemplate = template
    }

sampleTime :: UTCTime
sampleTime = UTCTime (fromGregorian 2026 7 27) 0

------------------------------------------------------------
-- Common helpers
------------------------------------------------------------

multiEventRequest :: AppendRequest
multiEventRequest = AppendRequest
  { appendExpectedRevision = DomainRevision 0
  , appendSemanticActionId = "probe:append:atomic"
  , appendActorOrOrigin = "core:contract-probe"
  , appendOccurredAt = Just "2026-07-27T00:00:00Z"
  , appendProposedEvents =
      [ ProposeValueStored "first" (String "accepted")
      , ProposeValueStored "second" (toJSON (2 :: Int))
      ]
  }

objectFields :: Text -> Object
objectFields title = KeyMap.singleton "title" (String title)

asObject :: Text -> Value -> Either Text Object
asObject name value = case value of
  Object result -> Right result
  _ -> Left (name <> " fixture is not a JSON object")

checkMetadata :: Text -> Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata expectedModule expectedCategory expectedConstruct input = do
  require (planProbeModule input == expectedModule)
    "plan probe received the wrong module"
  require (planProbeCategory input == expectedCategory)
    "plan probe received the wrong category"
  require (planProbeSourceConstruct input == expectedConstruct)
    "plan probe received the wrong semantic construct"

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

mapKernelError :: Either KernelError value -> Either Text value
mapKernelError = either (Left . Text.pack . show) Right

mapDomainError :: Either DomainError value -> Either Text value
mapDomainError = either (Left . Text.pack . show) Right

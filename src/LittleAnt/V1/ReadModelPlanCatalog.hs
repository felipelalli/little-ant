{-# LANGUAGE DerivingStrategies #-}

-- | Allium probes for sparse commands, semantic history, and typed text
-- annotations. Every registration executes the named behavior and all of its
-- declared precondition variants.
module LittleAnt.V1.ReadModelPlanCatalog
  ( readModelPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson
  (FromJSON, Object, Result (..), ToJSON, Value (..), fromJSON, toJSON)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.V1.Contract (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Domain
  (Authority (Human), Brick (..), BrickDraft (..), BrickId, DomainError,
   DomainState (..), Party (..), PartyType (Person), createBrick,
   createParty, describeBrick, emptyDomainState, mkCanonicalText,
   ordinaryBrickDraft, standardV1)
import LittleAnt.V1.Interaction
  (CompactEntityReference (..), OperationalResponse (..), ProjectionKind (..),
   operationalResponseMatchesProjection, operationalResponseProjection)
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..), KernelError,
   KernelState, ProposedEvent (..), appendSemanticAction, emptyKernelState,
   kernelEventBatches, kernelRevision)
import LittleAnt.V1.ReadModel

readModelPlanProbes :: Map ProbeKey PlanProbe
readModelPlanProbes = Map.fromList
  (valueRegistrations
  <> contractRegistrations
  <> enumRegistrations
  <> annotationRegistrations)

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations = concat
  [ valueType "CompactEntityReference" sampleReference
      ["id", "title", "revision", "state"]
  , valueType "HistoryQuery" sampleQuery
      [ "from", "through", "brick_ids", "related_entity_ids", "scope_ids"
      , "actor_ids", "origins", "action_families", "minimum_relevance"
      , "cursor", "page_size"
      ]
  , valueType "SemanticActionSummary" sampleSummary
      [ "action_id", "domain_revision", "occurred_at", "actor_or_origin"
      , "family", "relevance", "outcome", "summary", "affected"
      , "event_references"
      ]
  , valueType "HistoryPage" samplePage
      ["snapshot_domain_revision", "items", "next_cursor", "exact_total"]
  , valueType "HistoryBrief" sampleBrief
      [ "snapshot_domain_revision", "from", "through", "facts"
      , "source_action_ids"
      ]
  ]
  where
    valueType construct value fields =
      [ registration "value_equality" construct $ do
          require (toJSON value /= Null) (construct <> " encoded as null")
          roundTrip construct value
      , registration "entity_fields" construct $ do
          encoded <- asObject construct (toJSON value)
          requireFields construct fields encoded
          roundTrip construct value
      ]

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "CommandProtocol.execute" commandProbe
  , registration "contract_signature" "CommandProtocol.project" projectionProbe
  , registration "contract_signature" "HistoryQueryProtocol.query" historyProbe
  , registration "contract_signature" "HistoryQueryProtocol.brief" historyProbe
  ]

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ enumRegistration "HistoryRelevance" [Routine, Relevant, Important, Critical]
  , enumRegistration "AnnotationTargetKind" [AnnotationParty, AnnotationBrick]
  , enumRegistration "AnnotationStatus" [AnnotationActive, AnnotationStale]
  ]

annotationRegistrations :: [(ProbeKey, PlanProbe)]
annotationRegistrations =
  [ registration "transition_edge" "TextAnnotation.status" annotationProbe
  , registration "transition_rejected" "TextAnnotation.status" annotationProbe
  , registration "entity_fields" "TextAnnotation" annotationEntityProbe
  , registration "entity_optional" "TextAnnotation.target_party"
      annotationEntityProbe
  , registration "entity_optional" "TextAnnotation.target_brick"
      annotationEntityProbe
  ]
  <> categories "PartyAnnotationConfirmed" partyAnnotationProbe
      ["rule_success", "rule_failure", "rule_entity_creation"]
  <> categories "BrickAnnotationConfirmed" brickAnnotationProbe
      ["rule_success", "rule_failure", "rule_entity_creation"]
  <> categories "AnnotationMarkedStale" annotationProbe
      ["rule_success", "rule_failure"]
  <> [ registration "invariant" "AnnotationHasExactlyOneTarget"
        annotationInvariantProbe
     , registration "invariant" "AnnotationKindMatchesTarget"
        annotationInvariantProbe
     ]
  where
    categories construct probe = map
      (\category -> registration category construct probe)

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct probe =
  ( ProbeKey "interaction" category construct
  , \input -> do
      checkMetadata category construct input
      probe
  )

enumRegistration :: ToJSON value => Text -> [value] -> (ProbeKey, PlanProbe)
enumRegistration construct values = registration "enum_comparable" construct $ do
  let encoded = map toJSON values
  require (Set.size (Set.fromList encoded) == length encoded)
    (construct <> " enum encodings are not unique")
  require (all canonical encoded)
    (construct <> " enum is not canonical lowercase text")
  where
    canonical (String value) = value == Text.toLower value
    canonical _ = False

------------------------------------------------------------
-- Command and history probes
------------------------------------------------------------

commandProbe :: Either Text ()
commandProbe = do
  let request = AppendRequest
        { appendExpectedRevision = DomainRevision 0
        , appendSemanticActionId = "probe:command:execute"
        , appendActorOrOrigin = "human:probe"
        , appendOccurredAt = Just "2026-07-27T19:00:00Z"
        , appendProposedEvents =
            [ProposeValueStored "probe.command" (Bool False)]
        }
      reference = CompactEntityReference "brick:probe" (Just "Probe") 0
        (Just "active")
  (response, accepted) <- mapKernel (runOperationalMutation request "Updated."
    "brick_changed" (Just reference) ["title"] [] (Just False)
    emptyKernelState)
  require (kernelRevision (appendResultState accepted) == DomainRevision 1)
    "successful command did not append exactly one domain revision"
  require (operationalResponseDomainRevision response == 1
      && operationalResponseOk response)
    "successful command response does not identify committed revision"
  let sparse = operationalResponseProjection response
  require (operationalResponseMatchesProjection sparse)
    "successful command response violates its sparse schema"
  fields <- asObject "sparse OperationalResponse" sparse
  require (KeyMap.lookup "dry_run" fields == Just (Bool False))
    "meaningful false dry_run was recursively erased"
  require (KeyMap.lookup "warnings" fields == Just (toJSON ([] :: [Text])))
    "required empty warnings were recursively erased"
  require (not (KeyMap.member "error_code" fields)
      && not (KeyMap.member "hint" fields))
    "absent success optionals were serialized as null"
  let failed = commandFailure "precondition_failed" "Rejected."
        (Just "Choose an active Brick.") [] emptyKernelState
      failedFields = operationalResponseProjection failed
  require (operationalResponseMatchesProjection failedFields)
    "failed command response violates its sparse schema"
  require (operationalResponseDomainRevision failed == 0
      && null (kernelEventBatches emptyKernelState))
    "failed command advanced canonical state"

projectionProbe :: Either Text ()
projectionProbe = do
  (_, accepted) <- mapKernel (runOperationalMutation request "Stored."
    "value_changed" Nothing ["projection.target"] [] Nothing emptyKernelState)
  let state = appendResultState accepted
  summary <- commandProject ProjectionSummary Nothing state
  operational <- commandProject ProjectionOperational
    (Just "projection.target") state
  relationships <- commandProject ProjectionRelationships Nothing state
  history <- commandProject ProjectionHistory Nothing state
  complete <- commandProject ProjectionComplete Nothing state
  require (containsField "domain_revision" summary
      && containsField "value" operational
      && containsField "relationships" relationships
      && containsField "items" history
      && containsField "event_batches" complete)
    "projection kinds did not derive their declared bounded views"
  case commandProject ProjectionOperational (Just "missing") state of
    Left _ -> Right ()
    Right _ -> Left "unknown operational projection reference was accepted"
  where
    request = AppendRequest (DomainRevision 0) "probe:command:project"
      "human:probe" (Just "2026-07-27T19:00:00Z")
      [ProposeValueStored "projection.target" (toJSON (0 :: Integer))]

historyProbe :: Either Text ()
historyProbe = do
  state <- historyFixture
  pageOne <- mapHistory (historyQuery sampleQuery
    { historyQueryPageSize = 1
    , historyQueryActionFamilies = ["content", "lifecycle"]
    , historyQueryMinimumRelevance = Just Relevant
    } state)
  require (length (historyPageItems pageOne) == 1
      && historyPageNextCursor pageOne /= Nothing
      && historyPageSnapshotDomainRevision pageOne == 2)
    "history first page was not stable and bounded"
  cursor <- maybe (Left "history omitted its required next cursor") Right
    (historyPageNextCursor pageOne)
  pageTwo <- mapHistory (historyQuery sampleQuery
    { historyQueryPageSize = 1
    , historyQueryActionFamilies = ["content", "lifecycle"]
    , historyQueryMinimumRelevance = Just Relevant
    , historyQueryCursor = Just cursor
    } state)
  let items = historyPageItems pageOne <> historyPageItems pageTwo
      actionIds = map semanticActionSummaryActionId items
  require (length items == 2
      && Set.size (Set.fromList actionIds) == 2
      && all (not . null . semanticActionSummaryEventReferences) items)
    "history did not emit one traceable summary per semantic action"
  require (all (not . containsField "event_payload" . toJSON) items)
    "ordinary history leaked raw event bodies"
  filtered <- mapHistory (historyQuery sampleQuery
    { historyQueryBrickIds = ["brick:history"]
    , historyQueryRelatedEntityIds = ["party:history"]
    , historyQueryScopeIds = ["scope:history"]
    , historyQueryActorIds = ["human:probe"]
    , historyQueryOrigins = ["human:probe"]
    , historyQueryActionFamilies = ["content"]
    , historyQueryMinimumRelevance = Just Relevant
    } state)
  require (map semanticActionSummaryActionId (historyPageItems filtered)
      == ["history:rename"])
    "typed relevance/entity/scope/actor/family filters did not compose"
  brief <- mapHistory (historyBrief sampleQuery state)
  require (historyBriefSourceActionIds brief
      == ["history:create", "history:rename"]
      && length (historyBriefFacts brief) == 2)
    "history brief is not traceable to every source action"
  case historyQuery sampleQuery {historyQueryPageSize = 0} state of
    Left (InvalidHistoryPageSize 0) -> Right ()
    result -> Left ("unbounded history page was accepted: "
      <> Text.pack (show result))

historyFixture :: Either Text KernelState
historyFixture = do
  first <- append "history:create" "lifecycle" Important "Created Brick."
    (DomainRevision 0) emptyKernelState
  append "history:rename" "content" Relevant "Renamed Brick."
    (DomainRevision 1) (appendResultState first) >>= pure . appendResultState
  where
    append action family relevance summary expected state = mapKernel
      (appendSemanticAction AppendRequest
        { appendExpectedRevision = expected
        , appendSemanticActionId = action
        , appendActorOrOrigin = "human:probe"
        , appendOccurredAt = Just (if expected == DomainRevision 0
            then "2026-07-27T19:00:00Z" else "2026-07-27T19:01:00Z")
        , appendProposedEvents =
            [ ProposeValueStored ("value:" <> action) (Bool False)
            , historyMetadataEvent SemanticActionMetadata
                { semanticActionMetadataActionId = action
                , semanticActionMetadataFamily = family
                , semanticActionMetadataRelevance = relevance
                , semanticActionMetadataOutcome = "accepted"
                , semanticActionMetadataSummary = summary
                , semanticActionMetadataAffected = [sampleReference]
                , semanticActionMetadataRelatedEntityIds = ["party:history"]
                , semanticActionMetadataScopeIds = ["scope:history"]
                }
            ]
        } state)

------------------------------------------------------------
-- Annotation probes
------------------------------------------------------------

partyAnnotationProbe :: Either Text ()
partyAnnotationProbe = do
  (domain, owner, party, _) <- annotationDomain
  (annotation, next) <- mapAnnotation (annotatePartyInBrickText domain owner
    "description" 1 4 8 "@Ada" (LittleAnt.V1.Domain.partyId party) Human
    sampleTime emptyAnnotationState)
  require (textAnnotationTargetKind annotation == AnnotationParty
      && textAnnotationTargetParty annotation == Just
        (LittleAnt.V1.Domain.partyId party)
      && textAnnotationTargetBrick annotation == Nothing
      && textAnnotationStatus annotation == AnnotationActive)
    "Party annotation did not retain exactly one typed target"
  require (Map.lookup (textAnnotationId annotation)
      (annotationStateAnnotations next) == Just annotation)
    "Party annotation creation was not retained"
  expectUnsupported (annotatePartyInBrickText domain owner "title" 1 4 8
    "@Ada" (LittleAnt.V1.Domain.partyId party) Human sampleTime
    emptyAnnotationState)
  expectRevision (annotatePartyInBrickText domain owner "description" 0 4 8
    "@Ada" (LittleAnt.V1.Domain.partyId party) Human sampleTime
    emptyAnnotationState)
  expectStart (annotatePartyInBrickText domain owner "description" 1 (-1) 8
    "@Ada" (LittleAnt.V1.Domain.partyId party) Human sampleTime
    emptyAnnotationState)
  expectRange (annotatePartyInBrickText domain owner "description" 1 4 4
    "@Ada" (LittleAnt.V1.Domain.partyId party) Human sampleTime
    emptyAnnotationState)

brickAnnotationProbe :: Either Text ()
brickAnnotationProbe = do
  (domain, owner, _, target) <- annotationDomain
  (annotation, next) <- mapAnnotation (annotateBrickInBrickText domain owner
    "description" 1 15 22 "#Target" (brickId target) Human sampleTime
    emptyAnnotationState)
  require (textAnnotationTargetKind annotation == AnnotationBrick
      && textAnnotationTargetBrick annotation == Just (brickId target)
      && textAnnotationTargetParty annotation == Nothing
      && Map.size (annotationStateAnnotations next) == 1)
    "Brick annotation did not retain exactly one typed target"
  expectUnsupported (annotateBrickInBrickText domain owner "title" 1 15 22
    "#Target" (brickId target) Human sampleTime emptyAnnotationState)
  expectRevision (annotateBrickInBrickText domain owner "description" 0 15 22
    "#Target" (brickId target) Human sampleTime emptyAnnotationState)
  expectStart (annotateBrickInBrickText domain owner "description" 1 (-1) 22
    "#Target" (brickId target) Human sampleTime emptyAnnotationState)
  expectRange (annotateBrickInBrickText domain owner "description" 1 15 15
    "#Target" (brickId target) Human sampleTime emptyAnnotationState)

annotationProbe :: Either Text ()
annotationProbe = do
  (domain, owner, party, _) <- annotationDomain
  (annotation, active) <- mapAnnotation (annotatePartyInBrickText domain owner
    "description" 1 4 8 "@Ada" (LittleAnt.V1.Domain.partyId party) Human
    sampleTime emptyAnnotationState)
  (stale, staleState) <- mapAnnotation
    (markAnnotationStale (textAnnotationId annotation) active)
  require (textAnnotationStatus stale == AnnotationStale)
    "active annotation did not reach stale"
  case markAnnotationStale (textAnnotationId annotation) staleState of
    Left (AnnotationAlreadyStale _) -> Right ()
    result -> Left ("stale annotation transitioned again: "
      <> Text.pack (show result))
  (_, editedDomain) <- mapDomain (describeBrick owner
    "Ask @Ada after editing." domain)
  let editedOwner = maybe owner brickId
        (Map.lookup owner (LittleAnt.V1.Domain.domainBricks editedDomain))
      afterEdit = staleAnnotationsAfterTextEdit editedOwner "description" 2 active
  require (fmap textAnnotationStatus (Map.lookup (textAnnotationId annotation)
      (annotationStateAnnotations afterEdit)) == Just AnnotationStale)
    "text edit silently moved a prior-revision annotation"

annotationEntityProbe :: Either Text ()
annotationEntityProbe = do
  (domain, owner, party, target) <- annotationDomain
  (partyAnnotation, _) <- mapAnnotation (annotatePartyInBrickText domain owner
    "description" 1 4 8 "@Ada" (LittleAnt.V1.Domain.partyId party) Human
    sampleTime emptyAnnotationState)
  (brickAnnotation, _) <- mapAnnotation (annotateBrickInBrickText domain owner
    "description" 1 15 22 "#Target" (brickId target) Human sampleTime
    emptyAnnotationState)
  partyFields <- asObject "party TextAnnotation" (toJSON partyAnnotation)
  brickFields <- asObject "brick TextAnnotation" (toJSON brickAnnotation)
  requireFields "TextAnnotation"
    [ "id", "owner_brick", "field", "text_revision", "start_offset"
    , "end_offset", "displayed_token", "target_kind", "target_party"
    , "target_brick", "authority", "status", "created_at"
    ] partyFields
  require (KeyMap.lookup "target_party" partyFields /= Just Null
      && KeyMap.lookup "target_brick" partyFields == Just Null
      && KeyMap.lookup "target_party" brickFields == Just Null
      && KeyMap.lookup "target_brick" brickFields /= Just Null)
    "TextAnnotation optionals did not accept both null and non-null variants"
  roundTrip "TextAnnotation" partyAnnotation
  roundTrip "TextAnnotation" brickAnnotation

annotationInvariantProbe :: Either Text ()
annotationInvariantProbe = do
  partyAnnotationProbe
  brickAnnotationProbe
  (domain, owner, party, target) <- annotationDomain
  (partyAnnotation, first) <- mapAnnotation (annotatePartyInBrickText domain owner
    "description" 1 4 8 "@Ada" (LittleAnt.V1.Domain.partyId party) Human
    sampleTime emptyAnnotationState)
  (_, second) <- mapAnnotation (annotateBrickInBrickText domain owner
    "description" 1 15 22 "#Target" (brickId target) Human sampleTime first)
  mapAnnotation (validateAnnotationState second)
  let bothTargets = partyAnnotation
        {textAnnotationTargetBrick = Just (brickId target)}
      wrongKind = partyAnnotation {textAnnotationTargetKind = AnnotationBrick}
      invalidWith annotation = first
        {annotationStateAnnotations = Map.singleton
          (textAnnotationId annotation) annotation}
  expectInvariantFailure (validateAnnotationState (invalidWith bothTargets))
  expectInvariantFailure (validateAnnotationState (invalidWith wrongKind))

annotationDomain :: Either Text (DomainState, BrickId, Party, Brick)
annotationDomain = do
  (party, first) <- mapDomain
    (createParty "Ada" Person sampleTime emptyDomainState)
  targetTitle <- mapDomain (mkCanonicalText "Target" Nothing Human)
  (target, second) <- mapDomain
    (createBrick (ordinaryBrickDraft targetTitle standardV1 sampleTime) first)
  ownerTitle <- mapDomain (mkCanonicalText "Owner" Nothing Human)
  let draft = (ordinaryBrickDraft ownerTitle standardV1 sampleTime)
        {brickDraftDescription = Just "Ask @Ada about #Target"}
  (owner, third) <- mapDomain (createBrick draft second)
  pure (third, brickId owner, party, target)

------------------------------------------------------------
-- Fixtures and helpers
------------------------------------------------------------

sampleReference :: CompactEntityReference
sampleReference = CompactEntityReference "brick:history"
  (Just "History Brick") 2 (Just "active")

sampleQuery :: HistoryQuery
sampleQuery = HistoryQuery Nothing Nothing [] [] [] [] [] [] Nothing Nothing 10

sampleSummary :: SemanticActionSummary
sampleSummary = SemanticActionSummary "history:rename" 2 sampleTime "human:probe"
  "content" Relevant "accepted" "Renamed Brick." [sampleReference]
  ["event:rename:0"]

samplePage :: HistoryPage
samplePage = HistoryPage 2 [sampleSummary] (Just "2.cursor.1") (Just 2)

sampleBrief :: HistoryBrief
sampleBrief = HistoryBrief 2 Nothing Nothing ["Renamed Brick."]
  ["history:rename"]

sampleTime :: UTCTime
sampleTime = UTCTime (fromGregorian 2026 7 27) 0

checkMetadata :: Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata category construct input = do
  require (planProbeModule input == "interaction")
    "read-model probe received another module"
  require (planProbeCategory input == category)
    "read-model probe received another category"
  require (planProbeSourceConstruct input == construct)
    "read-model probe received another semantic construct"

containsField :: Key.Key -> Value -> Bool
containsField field (Object fields) = KeyMap.member field fields
containsField _ _ = False

expectUnsupported :: Either AnnotationError value -> Either Text ()
expectUnsupported result = case result of
  Left (UnsupportedAnnotationField _) -> Right ()
  _ -> Left ("unsupported annotation field was not rejected: "
    <> Text.pack (showAnnotationResult result))

expectRevision :: Either AnnotationError value -> Either Text ()
expectRevision result = case result of
  Left (AnnotationTextRevisionMismatch _ _) -> Right ()
  _ -> Left ("stale annotation revision was not rejected: "
    <> Text.pack (showAnnotationResult result))

expectStart :: Either AnnotationError value -> Either Text ()
expectStart result = case result of
  Left (InvalidAnnotationStart _) -> Right ()
  _ -> Left ("negative annotation start was not rejected: "
    <> Text.pack (showAnnotationResult result))

expectRange :: Either AnnotationError value -> Either Text ()
expectRange result = case result of
  Left (InvalidAnnotationRange _ _) -> Right ()
  _ -> Left ("empty annotation range was not rejected: "
    <> Text.pack (showAnnotationResult result))

showAnnotationResult :: Either AnnotationError value -> String
showAnnotationResult = either show (const "accepted")

expectInvariantFailure :: Either AnnotationError () -> Either Text ()
expectInvariantFailure result = case result of
  Left (AnnotationInvariantViolation _) -> Right ()
  _ -> Left ("invalid annotation target shape was accepted: "
    <> Text.pack (show result))

requireFields :: Text -> [Text] -> Object -> Either Text ()
requireFields construct fields encoded = require
  (all (\field -> KeyMap.member (Key.fromText field) encoded) fields)
  (construct <> " omits a declared field")

roundTrip :: (Eq value, ToJSON value, FromJSON value) =>
  Text -> value -> Either Text ()
roundTrip construct value = case fromJSON (toJSON value) of
  Success decoded -> require (decoded == value)
    (construct <> " lost fields in JSON round-trip")
  Error problem -> Left (construct <> " failed typed decode: "
    <> Text.pack problem)

asObject :: Text -> Value -> Either Text Object
asObject construct = \case
  Object fields -> Right fields
  _ -> Left (construct <> " did not encode as an object")

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

mapKernel :: Either KernelError value -> Either Text value
mapKernel = either (Left . Text.pack . show) Right

mapHistory :: Either HistoryError value -> Either Text value
mapHistory = either (Left . Text.pack . show) Right

mapAnnotation :: Either AnnotationError value -> Either Text value
mapAnnotation = either (Left . Text.pack . show) Right

mapDomain :: Either DomainError value -> Either Text value
mapDomain = either (Left . Text.pack . show) Right

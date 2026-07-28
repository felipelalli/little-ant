{-# LANGUAGE DerivingStrategies #-}

-- | Composed-root conformance probes.  Each registration is keyed only by
-- semantic Allium metadata and crosses the real module boundaries named by
-- the root invariant.
module LittleAnt.V1.RootPlanCatalog
  ( rootPlanProbes
  ) where

import Control.Monad (foldM, unless)
import Data.Aeson
  (Result (..), Value (..), encode, fromJSON, object, toJSON, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.Event (Body (BrickCaptured), Event (..), eventToJSON)
import LittleAnt.Ids (Id (..))
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import qualified LittleAnt.V1.Coordination as Coordination
import qualified LittleAnt.V1.Domain as Domain
import qualified LittleAnt.V1.Execution as Execution
import qualified LittleAnt.V1.Integration as Integration
import qualified LittleAnt.V1.Interaction as Interaction
import qualified LittleAnt.V1.Judgment as Judgment
import qualified LittleAnt.V1.Material as Material
import qualified LittleAnt.V1.Migration as Migration
import qualified LittleAnt.V1.Priority as Priority
import qualified LittleAnt.V1.Selection as Selection
import qualified LittleAnt.V1.Standing as Standing

rootPlanProbes :: Map ProbeKey PlanProbe
rootPlanProbes = Map.fromList
  [ registration "OneCanonicalBrickModel" oneCanonicalBrickModelProbe
  , registration "RawIsMaterialAndBrickIsWork" rawAndWorkSeparationProbe
  , registration "EveryActiveBrickHasOneStrictSiblingPosition"
      strictSiblingPositionProbe
  , registration "PriorityIsImportanceOnly" priorityIsImportanceProbe
  , registration "ForecastIsNotAnotherStoredOrder" derivedForecastProbe
  , registration "OptionalAxesStayLazy" optionalAxesProbe
  , registration "CoreMechanismAndExternalJudgmentAreSeparated"
      authorityBoundaryProbe
  , registration "CanonicalEnglishWithVerbatimProvenance"
      canonicalProvenanceProbe
  , registration "NoGenericPluginAuthority" typedPackAuthorityProbe
  , registration "LegacyBehaviorIsNotSpecAuthority" legacyProjectionProbe
  ]
  where
    registration construct probe =
      ( ProbeKey "root" "invariant" construct
      , semanticProbe construct probe
      )

semanticProbe :: Text -> Either Text () -> PlanProbe
semanticProbe construct probe input = do
  require (planProbeModule input == "root")
    "root probe received a different module"
  require (planProbeCategory input == "invariant")
    "root probe received a different category"
  require (planProbeSourceConstruct input == construct)
    "root probe received a different semantic construct"
  probe

-- Grocery-like checklists, projects, ordinary work, recurring obligations,
-- and practices are all created through the same Brick transition.  Their
-- behavior is data from the immutable catalog, not a subtype constructor.
oneCanonicalBrickModelProbe :: Either Text ()
oneCanonicalBrickModelProbe = do
  let definitions =
        [ ("Handle one task", Domain.standardV1)
        , ("Deliver a project", Domain.projectV1)
        , ("Pay the synthetic rent", Domain.recurringObligationV1)
        , ("Practice a synthetic skill", Domain.practiceV1)
        , ("Pack for a synthetic trip", Domain.finiteChecklistV1)
        ]
  (created, state) <- createExecutionBricks definitions
  mapExecution (Execution.validateExecutionState state)
  let domain = Execution.executionStateDomain state
      stored = Domain.domainBricks domain
      createdIds = Set.fromList (map Domain.brickId created)
      storedIds = Map.keysSet stored
      configuredBehaviors = Set.fromList
        (map (Domain.behaviorId . Domain.brickBehavior) created)
      requestedBehaviors = Set.fromList
        (map (Domain.behaviorId . snd) definitions)
  require (createdIds == storedIds && configuredBehaviors == requestedBehaviors)
    "behavior variants did not remain one canonical Brick model"
  require (all (Domain.catalogContainsBehavior (Domain.domainCatalog domain)
      . Domain.brickBehavior) created)
    "created Brick references a hard-coded behavior outside the catalog"
  projections <- mapM (mapDomain . Domain.brickProjection domain . Domain.brickId)
    created
  require (all (projectionHasFields ["id", "title", "behavior", "status"])
      projections)
    "behavior variants do not expose the common Brick projection"

-- Raw and ListEntry are deliberately unable to enter work mechanics.  The
-- paired Brick is focused through Execution so this probe fails if it only
-- inspects an empty priority state.
rawAndWorkSeparationProbe :: Either Text ()
rawAndWorkSeparationProbe = do
  (created, execution0) <- createExecutionBricks
    [("Review material", Domain.standardV1),
     ("Synthetic checklist", Domain.finiteChecklistV1)]
  (work, checklist) <- exactlyTwo "work separation Bricks" created
  label <- mapDomain
    (Domain.mkCanonicalText "Synthetic item" Nothing Domain.Human)
  (entry, domainWithEntry) <- mapDomain (Domain.createListEntry
    (Domain.ListEntryDraft (Domain.brickId checklist) label Nothing Nothing
      rootTime)
    (Execution.executionStateDomain execution0))
  focused <- mapExecution
    (Execution.focusExecutionBrick (Domain.brickId work) rootTime execution0)
  (raw, material) <- mapMaterial (Material.captureInlineRaw
    "Mensagem sintética preservada" (Just "Synthetic preserved message")
    (Just Domain.Adapter) rootTime Material.emptyMaterialState)
  rawValue <- mapMaterial (Material.rawProjection material (Material.rawId raw))
  rawFields <- asObject "Raw projection" rawValue
  let priority = Execution.executionStatePriority focused
      positioned = Set.fromList
        [ Domain.unBrickId identifier
        | scope <- Map.elems (Priority.priorityStateScopes priority)
        , identifier <- Priority.priorityScopeMembers scope
        ]
      focus = Domain.focusRegisterCurrent (Domain.domainFocusRegister
        (Execution.executionStateDomain focused))
  require (focus == Just (Domain.brickId work)
      && Execution.activeHumanWipCount focused == 1
      && Set.member (Domain.unBrickId (Domain.brickId work)) positioned)
    "real Brick did not receive focus, WIP, and sibling priority mechanics"
  require (Set.notMember (Material.unRawId (Material.rawId raw)) positioned
      && Set.notMember (Domain.unListEntryId (Domain.listEntryId entry)) positioned
      && Map.member (Domain.listEntryId entry)
        (Domain.domainListEntries domainWithEntry))
    "Raw or ListEntry entered independently focusable work priority"
  require (all (not . (`KeyMap.member` rawFields))
      ["status", "work_state", "priority", "current_focus"])
    "Raw projection exposed Brick work semantics"

strictSiblingPositionProbe :: Either Text ()
strictSiblingPositionProbe = do
  (roots, initial) <- createExecutionBricks
    [("First root", Domain.projectV1), ("Second root", Domain.standardV1)]
  (firstRoot, _) <- exactlyTwo "strict root Bricks" roots
  childTitle <- mapDomain
    (Domain.mkCanonicalText "Nested sibling" Nothing Domain.Human)
  (child, _, state) <- mapExecution (Execution.createExecutionBrick
    ((Domain.ordinaryBrickDraft childTitle Domain.standardV1 rootTime)
      {Domain.brickDraftParent = Just (Domain.brickId firstRoot)})
    "root:strict-child" rootTime initial)
  mapExecution (Execution.validateExecutionState state)
  let domain = Execution.executionStateDomain state
      priority = Execution.executionStatePriority state
      active = filter ((== Domain.Active) . Domain.brickStatus)
        (Map.elems (Domain.domainBricks domain))
      memberships identifier =
        [ scope
        | scope <- Map.elems (Priority.priorityStateScopes priority)
        , identifier `elem` Priority.priorityScopeMembers scope
        ]
  require (not (null active) && all
      ((== 1) . length . memberships . Domain.brickId) active)
    "an active Brick lacks exactly one sibling-priority membership"
  require (all strictScope (Map.elems (Priority.priorityStateScopes priority)))
    "a sibling priority scope is not a strict duplicate-free order"
  childView <- mapPriority
    (Priority.priorityViewItem priority (Domain.brickId child))
  require (not (null (Priority.priorityViewItemTreePath childView)))
    "nested active Brick has no concrete strict tree position"
  where
    strictScope scope =
      let members = Priority.priorityScopeMembers scope
      in Set.size (Set.fromList members) == length members

-- Impact and effort evidence are recorded in Judgment while the strict human
-- sibling order remains byte-for-byte the order owned by Priority.
priorityIsImportanceProbe :: Either Text ()
priorityIsImportanceProbe = do
  (created, initial) <- createExecutionBricks
    [("Important first", Domain.standardV1),
     ("Large impact second", Domain.standardV1)]
  (first, second) <- exactlyTwo "priority independence Bricks" created
  let priorityBefore = Execution.executionStatePriority initial
      judgment0 = Execution.executionStateJudgment initial
  (_, _, judgment1) <- mapJudgment (Judgment.classifyImpact
    (Domain.brickId first) Judgment.LowImpact Judgment.Supported Domain.Human
    (Just "synthetic low impact evidence") rootTime judgment0)
  (_, _, judgment2) <- mapJudgment (Judgment.classifyImpact
    (Domain.brickId second) Judgment.HighImpact Judgment.Supported Domain.Human
    (Just "synthetic high impact evidence") rootTime judgment1)
  band <- mapJudgment (Judgment.effortBandById Judgment.initialEffortProfile
    "HARD" judgment2)
  (_, _, judgment3) <- mapJudgment (Judgment.classifyEffort
    (Domain.brickId second) band Domain.Human False
    (Just "synthetic effort evidence") rootTime judgment2)
  let withJudgment = initial {Execution.executionStateJudgment = judgment3}
  mapExecution (Execution.validateExecutionState withJudgment)
  require (Priority.priorityStateScopes
      (Execution.executionStatePriority withJudgment)
      == Priority.priorityStateScopes priorityBefore)
    "impact or effort evidence implicitly rewrote human priority"
  require (not (Map.null (Judgment.judgmentStateImpactAssessments judgment3))
      && not (Map.null (Judgment.judgmentStateEffortAssessments judgment3)))
    "priority independence probe did not record external judgment evidence"

-- A draw stores only the selected outcome and replay evidence.  The ordered
-- ForecastView returned to the caller remains a derived value.
derivedForecastProbe :: Either Text ()
derivedForecastProbe = do
  standing <- createStandingBricks ["Forecast alpha", "Forecast beta"]
  let context = Selection.SelectionContext standing Material.emptyMaterialState
      empty = Selection.emptySelectionState
  forecast <- mapSelection (Selection.buildForecast rootTime 2 context empty)
  (draw, selected) <- mapSelection
    (Selection.requestNext rootTime 2 "root:forecast-seed" context empty)
  stored <- exactlyOne "stored next draws"
    (Map.elems (Selection.selectionStateDraws selected))
  storedFields <- asObject "StoredNextDraw" (toJSON stored)
  require (length (Selection.forecastViewItems forecast) == 2
      && length (Selection.forecastViewItems
        (Selection.nextDrawSourceForecast draw)) == 2)
    "forecast did not derive the live eligible candidates"
  require (Map.size (Selection.selectionStateDraws selected) == 1
      && not (KeyMap.member "source_forecast" storedFields)
      && not (KeyMap.member "items" storedFields))
    "canonical selection state persisted a forecast order"

optionalAxesProbe :: Either Text ()
optionalAxesProbe = do
  standing <- createStandingBricks ["Work without optional judgments"]
  brick <- exactlyOne "optional-axis Bricks" (Map.elems (Domain.domainBricks
    (standingDomain standing)))
  let judgment = Execution.executionStateJudgment
        (standingExecution standing)
      context = Selection.SelectionContext standing Material.emptyMaterialState
  forecast <- mapSelection
    (Selection.buildForecast rootTime 1 context Selection.emptySelectionState)
  require (Domain.brickDescription brick == Nothing
      && Domain.brickPhase brick == Nothing
      && Domain.brickMode brick == Nothing
      && Domain.brickContext brick == Nothing
      && Domain.brickStatus brick == Domain.Active
      && Map.null (Judgment.judgmentStateImpactAssessments judgment)
      && Map.null (Judgment.judgmentStateEffortAssessments judgment))
    "optional axes were populated as a mandatory capture form"
  require (Selection.forecastItemForBrick (Domain.brickId brick) forecast /= Nothing)
    "missing optional axes blocked ordinary active work"

-- Pack output and interaction actions are proposals at typed boundaries.  A
-- Brick changes only after the canonical Execution transition is invoked.
authorityBoundaryProbe :: Either Text ()
authorityBoundaryProbe = do
  (created, execution0) <- createExecutionBricks
    [("Original canonical title", Domain.standardV1)]
  brick <- exactlyOne "authority-boundary Bricks" created
  let manifest = Integration.PackInstallManifest
        { Integration.packInstallManifestId = "synthetic/root-authority"
        , Integration.packInstallManifestVersion = 1
        , Integration.packInstallManifestPublisher = "Synthetic publisher"
        , Integration.packInstallManifestContentHash = "sha256:synthetic-root-pack"
        , Integration.packInstallManifestComponents =
            [Integration.PackComponentManifest "synthetic/root-enricher" 1
              Integration.EnricherComponent True []]
        }
      evidence = Integration.PackInstallEvidence
        "sha256:synthetic-root-pack" 1 True
  (_, components, installed) <- mapIntegration
    (Integration.installPack rootTime evidence manifest Integration.emptyPackState)
  component <- exactlyOne "installed authority components" components
  let proposedTitle = "Accepted canonical title"
      packResult = Integration.PackExecutionResult 1 True
        (Just (object ["proposed_title" .= proposedTitle])) Nothing []
  (_, invoked) <- mapIntegration (Integration.recordPackInvocation rootTime
    (Integration.packComponentId component) "propose_title" "1"
    "sha256:synthetic-request" [] packResult installed)
  (session, interaction) <- mapInteraction (Interaction.openInteraction
    "review_external_judgment" (Just (Domain.unBrickId (Domain.brickId brick)))
    Nothing Nothing rootTime (Execution.executionStateRevision execution0)
    Interaction.emptyInteractionState)
  envelope <- mapInteraction
    (Interaction.currentInteraction (Interaction.interactionSessionId session)
      interaction)
  action <- exactlyOne "canonical interaction actions"
    (Interaction.interactionEnvelopeActions envelope)
  unchanged <- lookupBrick (Domain.brickId brick) execution0
  require (Domain.brickTitle unchanged == "Original canonical title"
      && length (Integration.packStateInvocations invoked) == 1
      && "la interaction submit" `Text.isPrefixOf`
        Interaction.interactionActionCanonicalCommand action)
    "external proposal bypassed or omitted the canonical mechanism"
  (renamed, execution1) <- mapExecution (Execution.renameExecutionBrick
    (Domain.brickId brick) proposedTitle Domain.Human rootTime execution0)
  require (Domain.brickTitle renamed == proposedTitle
      && Execution.executionStateRevision execution1
        == Execution.executionStateRevision execution0 + 1)
    "canonical operation did not own the accepted semantic change"

canonicalProvenanceProbe :: Either Text ()
canonicalProvenanceProbe = do
  title <- mapDomain (Domain.mkCanonicalText "Buy synthetic milk"
    (Just "Comprar leite sintético") Domain.Adapter)
  (brick, _, _) <- mapExecution (Execution.createExecutionBrick
    (Domain.ordinaryBrickDraft title Domain.standardV1 rootTime)
    "root:canonical-provenance" rootTime Execution.emptyExecutionState)
  (raw, material) <- mapMaterial (Material.captureInlineRaw
    "Mensagem sintética em português" (Just "Synthetic message in Portuguese")
    (Just Domain.Adapter) rootTime Material.emptyMaterialState)
  require (Domain.brickTitle brick == "Buy synthetic milk"
      && Domain.brickOriginalTitle brick == Just "Comprar leite sintético"
      && Domain.brickTitleAuthority brick == Domain.Adapter
      && Material.rawOriginalText raw == Just "Mensagem sintética em português"
      && Material.rawCanonicalEnglish raw == Just "Synthetic message in Portuguese"
      && Map.lookup (Material.rawId raw) (Material.materialRaws material)
        == Just raw)
    "canonical English replaced or lost verbatim attributed provenance"
  case Domain.mkCanonicalText " invalid canonical title "
      (Just "verbatim remains allowed") Domain.Human of
    Left (Domain.InvalidCanonicalEnglish _) -> Right ()
    result -> Left ("invalid canonical title result: " <> Text.pack (show result))

typedPackAuthorityProbe :: Either Text ()
typedPackAuthorityProbe = do
  case (fromJSON (String "generic_plugin") :: Result Integration.PackComponentKind) of
    Error _ -> Right ()
    Success _ -> Left "generic plugin kind entered the closed Pack vocabulary"
  let typedComponent = Integration.PackComponentManifest
        "synthetic/typed-source" 1 Integration.SourceAdapterComponent True
        ["http:api.example.test"]
      manifest = Integration.PackInstallManifest "synthetic/typed-pack" 1
        "Synthetic publisher" "sha256:synthetic-typed-pack" [typedComponent]
      evidence = Integration.PackInstallEvidence
        "sha256:synthetic-typed-pack" 1 True
  (_, components, installed) <- mapIntegration (Integration.installPack
    rootTime evidence manifest Integration.emptyPackState)
  component <- exactlyOne "typed Pack components" components
  require (Integration.packComponentKind component
      == Integration.SourceAdapterComponent
      && Integration.packComponentCapabilities component
        == ["http:api.example.test"]
      && Map.size (Integration.packStatePacks installed) == 1)
    "Pack installation broadened typed bounded component authority"
  let genericHook = typedComponent
        {Integration.packComponentManifestCapabilities = ["hook:anything"]}
  case Integration.installPack rootTime evidence
      (manifest {Integration.packInstallManifestComponents = [genericHook]})
      Integration.emptyPackState of
    Left (Integration.InvalidPackManifest _) -> Right ()
    result -> Left ("generic hook capability result: " <> Text.pack (show result))

-- The one-time v0 reader projects removed stages into canonical v1 status,
-- work state, behavior, and strict placement.  It never publishes a legacy
-- behavior as current specification authority.
legacyProjectionProbe :: Either Text ()
legacyProjectionProbe = do
  let event = Event "synthetic-legacy-event" rootTime
        (BrickCaptured (Id "sha256:synthetic-title-derived")
          "Synthetic legacy task")
      bytes = LBS.snoc (encode (eventToJSON event)) 10
  (archive, plannedCutover, planned) <- mapMigration
    (Migration.planV0V1CutoverFromBytes rootTime
      "synthetic/root-legacy.jsonl" "synthetic/root-v1.jsonl" bytes
      Migration.emptyMigrationState)
  (_, verifiedCutover, verified) <- mapMigration (Migration.verifyV0Archive
    rootTime (Migration.v1CutoverId plannedCutover)
    (Migration.v0ArchiveSha256 archive) 1 planned)
  (_, projected) <- mapMigration (Migration.projectV0Events
    (Migration.v1CutoverId verifiedCutover) [event] verified)
  migrated <- mapMigration
    (Migration.findProjectedBrick "sha256:synthetic-title-derived" projected)
  plans <- mapMigration
    (Migration.stagedIdentityPlans (Migration.v1CutoverId verifiedCutover) projected)
  (newId, kind) <- maybe (Left "legacy identity plan is absent") Right
    (Map.lookup "sha256:synthetic-title-derived" plans)
  require (Migration.projectedBrickBehavior migrated
      == Domain.behaviorId Domain.standardV1
      && Migration.projectedBrickStatus migrated == "active"
      && Migration.projectedBrickWorkState migrated == "idle"
      && Migration.projectedBrickPriorityMembershipCount migrated == 1
      && kind == Migration.MigratedBrick
      && newId /= "sha256:synthetic-title-derived"
      && "la1:migration:entity:" `Text.isPrefixOf` newId)
    "legacy behavior or title-derived identity became v1 authority"

------------------------------------------------------------
-- Fixtures and helpers
------------------------------------------------------------

createExecutionBricks ::
  [(Text, Domain.BrickBehavior)] -> Either Text ([Domain.Brick], Execution.ExecutionState)
createExecutionBricks definitions = do
  (reversed, state) <- foldM create ([], Execution.emptyExecutionState) definitions
  pure (reverse reversed, state)
  where
    create (created, state) (titleText, behavior) = do
      title <- mapDomain (Domain.mkCanonicalText titleText Nothing Domain.Human)
      (brick, _, next) <- mapExecution (Execution.createExecutionBrick
        (Domain.ordinaryBrickDraft title behavior rootTime)
        ("root:" <> titleText) rootTime state)
      pure (brick : created, next)

createStandingBricks :: [Text] -> Either Text Standing.StandingState
createStandingBricks = foldM create Standing.emptyStandingState
  where
    create state titleText = do
      title <- mapDomain (Domain.mkCanonicalText titleText Nothing Domain.Human)
      (_, _, next) <- mapStanding (Standing.createStandingBrick
        (Domain.ordinaryBrickDraft title Domain.standardV1 rootTime)
        ("root:standing:" <> titleText) rootTime state)
      pure next

standingExecution :: Standing.StandingState -> Execution.ExecutionState
standingExecution = Coordination.coordinationStateExecution
  . Standing.standingStateCoordination

standingDomain :: Standing.StandingState -> Domain.DomainState
standingDomain = Execution.executionStateDomain . standingExecution

lookupBrick :: Domain.BrickId -> Execution.ExecutionState -> Either Text Domain.Brick
lookupBrick identifier state = maybe (Left "composed Brick is missing") Right
  (Map.lookup identifier
    (Domain.domainBricks (Execution.executionStateDomain state)))

projectionHasFields :: [Text] -> Value -> Bool
projectionHasFields fields (Object values) =
  all (\field -> KeyMap.member (Key.fromText field) values) fields
projectionHasFields _ _ = False

asObject :: Text -> Value -> Either Text (KeyMap.KeyMap Value)
asObject _ (Object values) = Right values
asObject label _ = Left (label <> " is not an object")

exactlyOne :: Text -> [value] -> Either Text value
exactlyOne _ [value] = Right value
exactlyOne label values = Left
  (label <> " expected one value, got " <> Text.pack (show (length values)))

exactlyTwo :: Text -> [value] -> Either Text (value, value)
exactlyTwo _ [first, second] = Right (first, second)
exactlyTwo label values = Left
  (label <> " expected two values, got " <> Text.pack (show (length values)))

rootTime :: UTCTime
rootTime = UTCTime (fromGregorian 2026 7 27) (12 * 60 * 60)

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

mapDomain :: Either Domain.DomainError value -> Either Text value
mapDomain = either (Left . Text.pack . show) Right

mapExecution :: Either Execution.ExecutionError value -> Either Text value
mapExecution = either (Left . Text.pack . show) Right

mapIntegration :: Either Integration.IntegrationError value -> Either Text value
mapIntegration = either (Left . Text.pack . show) Right

mapInteraction :: Either Interaction.InteractionError value -> Either Text value
mapInteraction = either (Left . Text.pack . show) Right

mapJudgment :: Either Judgment.JudgmentError value -> Either Text value
mapJudgment = either (Left . Text.pack . show) Right

mapMaterial :: Either Material.MaterialError value -> Either Text value
mapMaterial = either (Left . Text.pack . show) Right

mapMigration :: Either Migration.MigrationError value -> Either Text value
mapMigration = either (Left . Text.pack . show) Right

mapPriority :: Either Priority.PriorityError value -> Either Text value
mapPriority = either (Left . Text.pack . show) Right

mapSelection :: Either Selection.SelectionError value -> Either Text value
mapSelection = either (Left . Text.pack . show) Right

mapStanding :: Either Standing.StandingError value -> Either Text value
mapStanding = either (Left . Text.pack . show) Right

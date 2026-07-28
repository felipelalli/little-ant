{-# LANGUAGE DerivingStrategies #-}

-- | Semantic integration probes for planning exporters and thin UI adapters.
-- Registrations are selected only by Allium module/category/construct metadata;
-- obligation IDs are deliberately unavailable here.
module LittleAnt.V1.PlanningPlanCatalog
  ( planningPlanProbes
  , planningRuntimePlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson
  (FromJSON, Result (..), ToJSON (toJSON), Value (..), encode, fromJSON,
   object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..), RuntimePlanProbe)
import LittleAnt.V1.Domain
  (Authority (Human), Brick (..), BrickDraft (..), BrickId, DomainState,
   createBrick, emptyDomainState, mkCanonicalText, ordinaryBrickDraft, projectV1,
   standardV1)
import qualified LittleAnt.V1.Domain as Domain
import LittleAnt.V1.Integration
  (ComponentStatus (..), PackComponent (..), PackComponentKind (..))
import qualified LittleAnt.V1.Interaction as Interaction
import LittleAnt.V1.Judgment
  (EffortProfile (..), JudgmentState, classifyEffort, effortBandById,
   emptyJudgmentState, initialEffortProfile, registerJudgmentBrick)
import LittleAnt.V1.Planning

planningPlanProbes :: Map ProbeKey PlanProbe
planningPlanProbes = Map.fromList
  ( valueRegistrations
  <> contractRegistrations
  <> enumRegistrations
  <> entityRegistrations
  <> transitionRegistrations
  <> ruleRegistrations
  <> invariantRegistrations
  <> surfaceRegistrations
  )

planningRuntimePlanProbes :: Map ProbeKey RuntimePlanProbe
planningRuntimePlanProbes = Map.fromList
  [ runtimeRegistration "contract_signature" "ReadOnlyExporterContract.export"
      exporterContractProbe
  , runtimeRegistration "contract_signature" "UIAdapterContract.render"
      uiRenderContractProbe
  , runtimeRegistration "contract_signature" "UIAdapterContract.decode"
      uiDecodeContractProbe
  ]

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations =
  [ registration "value_equality" "ExportPayload" exportPayloadProbe
  , registration "entity_fields" "ExportPayload" exportPayloadProbe
  ]

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "EnricherContract.propose" enricherProbe ]

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ registration "enum_comparable" "WebSessionStatus" webSessionEnumProbe ]

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ registration "entity_fields" "PlanningManifest" planningEntityProbe
  , registration "entity_fields" "ImportedActual" planningEntityProbe
  , registration "entity_fields" "WebUiSession" planningEntityProbe
  , registration "entity_optional" "WebUiSession.closed_at" planningEntityProbe
  ]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [ registration category "WebUiSession.status" webUiLifecycleProbe
  | category <- ["transition_edge", "transition_rejected", "transition_terminal"]
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ rules "TaskJugglerManifestGenerated"
      ["rule_success", "rule_failure", "rule_entity_creation"] manifestRuleProbe
  , rules "TaskJugglerActualImported"
      ["rule_success", "rule_failure", "rule_entity_creation"] actualRuleProbe
  , rules "LocalWebUiOpened"
      ["rule_success", "rule_failure", "rule_entity_creation"] webUiOpenRuleProbe
  , rules "LocalWebUiClosed"
      ["rule_success", "rule_failure"] webUiLifecycleProbe
  , rules "WebUiInputForwarded"
      ["rule_success", "rule_failure"] webUiForwardRuleProbe
  ]
  where
    rules construct categories probe =
      [registration category construct probe | category <- categories]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" "PlanningCutDoesNotDoubleCount" manifestRuleProbe
  , registration "invariant" "OneActualPerManifestBrick" actualRuleProbe
  , registration "invariant" "WebUiIsLoopbackOnly" webUiOpenRuleProbe
  ]

surfaceRegistrations :: [(ProbeKey, PlanProbe)]
surfaceRegistrations =
  [ registration category "ExtensionDesk" extensionDeskProbe
  | category <- ["surface_actor", "surface_exposure", "surface_provides"]
  ]

registration :: Text -> Text -> PlanProbe -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "integration" category construct, \input -> do
    checkMetadata category construct input
    probe input)

runtimeRegistration ::
  Text -> Text -> RuntimePlanProbe -> (ProbeKey, RuntimePlanProbe)
runtimeRegistration category construct probe =
  (ProbeKey "integration" category construct, \input ->
    case checkMetadata category construct input of
      Left problem -> pure (Left problem)
      Right () -> probe input)

checkMetadata :: Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata category construct input = do
  require (planProbeModule input == "integration")
    "planning probe received a different module"
  require (planProbeCategory input == category)
    "planning probe received a different category"
  require (planProbeSourceConstruct input == construct)
    "planning probe received a different source construct"

exportPayloadProbe :: PlanProbe
exportPayloadProbe _ = roundTripAndFields validPayload
  ["media_type", "suggested_filename", "content_hash", "size"]

enricherProbe :: PlanProbe
enricherProbe _ = do
  let component = sampleEnricher
      projection = object ["brick" .= ("brick-1" :: Text)]
  proposed <- mapPlanning (enrichmentProposal component projection)
  fields proposed ["component", "component_version", "projection", "authority"]
  require (valueAt "projection" proposed == Just projection)
    "Enricher changed the bounded projection while proposing"
  expectError InvalidEnricherComponent
    (enrichmentProposal (component {packComponentKind = SourceAdapterComponent})
      projection)

webSessionEnumProbe :: PlanProbe
webSessionEnumProbe _ = do
  let values = map toJSON [WebSessionOpen, WebSessionClosed]
  require (Set.size (Set.fromList (map encode values)) == 2)
    "WebSessionStatus values do not have distinct encodings"
  require (values == [String "open", String "closed"])
    "WebSessionStatus is not the declared closed vocabulary"

planningEntityProbe :: PlanProbe
planningEntityProbe input = do
  fixture <- planningFixture
  (manifest, _, planned) <- successfulManifest fixture
  (actual, withActual) <- mapPlanning (importTaskJugglerActual probeTime
    (planningManifestId manifest) (fixtureFirstChild fixture) 51.5 planned)
  (session, opened) <- mapPlanning
    (openLocalWebUi probeTime 4400 metroWebUiV1 emptyPlanningState)
  case planProbeSourceConstruct input of
    "PlanningManifest" -> fields (toJSON manifest)
      [ "id", "exporter", "dataset_revision", "selected_bricks"
      , "effort_profile", "generated_at", "payload", "content_hash"
      ]
    "ImportedActual" -> do
      require (Map.lookup (importedActualId actual)
          (planningStateActuals withActual) == Just actual)
        "ImportedActual was not retained as separate evidence"
      fields (toJSON actual)
        ["id", "manifest", "brick", "observed_hours", "imported_at"]
    "WebUiSession" -> fields (toJSON session)
      [ "id", "component", "bind_host", "port", "status", "opened_at"
      , "closed_at"
      ]
    "WebUiSession.closed_at" -> do
      require (valueAt "closed_at" (toJSON session) == Just Null)
        "open WebUiSession did not represent absent closed_at as null"
      (closed, _) <- mapPlanning
        (closeLocalWebUi (addUTCTime 1 probeTime) (webUiSessionId session) opened)
      require (valueAt "closed_at" (toJSON closed) /= Just Null)
        "closed WebUiSession did not retain its close time"
    construct -> Left ("unsupported planning entity probe: " <> construct)

manifestRuleProbe :: PlanProbe
manifestRuleProbe _ = do
  fixture <- planningFixture
  (manifest, planningExport, planned) <- successfulManifest fixture
  let selected = [fixtureFirstChild fixture, fixtureSecondChild fixture]
      items = planningProjectionItems (planningExportProjection planningExport)
  require (planningManifestDatasetRevision manifest == 7)
    "manifest did not pin the current dataset revision"
  require (planningManifestSelectedBricks manifest == selected)
    "manifest did not pin the confirmed planning cut"
  require (planningManifestEffortProfile manifest == initialEffortProfile)
    "manifest did not pin effort profile ID and version"
  require (map planningItemMacro items == ["EFFORT_4D", "EFFORT_2D"])
    "planning projection did not pin one selected profile macro per item"
  require (Map.lookup (planningManifestId manifest)
      (planningStateManifests planned) == Just manifest)
    "PlanningManifest creation did not retain every ensured field"
  expectError EmptyPlanningCut (attempt fixture 7 [] initialEffortProfile
    validPayload taskJugglerExporterV1)
  expectError (OverlappingPlanningCut
      (brickId (fixtureProject fixture)) (fixtureFirstChild fixture))
    (attempt fixture 7 [brickId (fixtureProject fixture), fixtureFirstChild fixture]
      initialEffortProfile validPayload taskJugglerExporterV1)
  let differentProfile = initialEffortProfile
        {effortProfileId = "personal/effort", effortProfileVersion = 9}
  expectError (PlanningEffortProfileMismatch (fixtureFirstChild fixture))
    (attempt fixture 7 selected differentProfile validPayload
      taskJugglerExporterV1)
  expectError (StalePlanningRevision 6 7)
    (attempt fixture 6 selected initialEffortProfile validPayload
      taskJugglerExporterV1)
  expectError TaskJugglerExporterUnavailable
    (attempt fixture 7 selected initialEffortProfile validPayload
      (taskJugglerExporterV1 {packComponentStatus = ComponentDisabled}))
  expectError (InvalidExportPayload "size must be positive")
    (attempt fixture 7 selected initialEffortProfile
      (validPayload {exportPayloadSize = 0}) taskJugglerExporterV1)
  where
    attempt fixture revision selected profile payload exporter = () <$
      createTaskJugglerManifest probeTime revision 7 selected profile payload
        exporter (fixtureDomain fixture) (fixtureJudgment fixture)
        emptyPlanningState

actualRuleProbe :: PlanProbe
actualRuleProbe _ = do
  fixture <- planningFixture
  (manifest, _, planned) <- successfulManifest fixture
  let manifestId = planningManifestId manifest
      brick = fixtureFirstChild fixture
      manifestsBefore = planningStateManifests planned
      effortBefore = encode (fixtureJudgment fixture)
  (actual, withActual) <- mapPlanning
    (importTaskJugglerActual probeTime manifestId brick 51.5 planned)
  require (importedActualManifest actual == manifestId
      && importedActualBrick actual == brick
      && importedActualObservedHours actual == 51.5)
    "ImportedActual creation omitted an ensured field"
  require (planningStateManifests withActual == manifestsBefore
      && encode (fixtureJudgment fixture) == effortBefore)
    "actual evidence rewrote a manifest or effort assessment"
  expectError (ActualBrickNotSelected (brickId (fixtureProject fixture)))
    (importTaskJugglerActual probeTime manifestId
      (brickId (fixtureProject fixture)) 1 planned)
  expectError (InvalidObservedHours (-1))
    (importTaskJugglerActual probeTime manifestId brick (-1) planned)
  expectError (DuplicateImportedActual manifestId brick)
    (importTaskJugglerActual probeTime manifestId brick 52 withActual)
  mapPlanning (validatePlanningState withActual)

webUiOpenRuleProbe :: PlanProbe
webUiOpenRuleProbe _ = do
  (session, opened) <- mapPlanning
    (openLocalWebUi probeTime 4400 metroWebUiV1 emptyPlanningState)
  require (webUiSessionBindHost session == "127.0.0.1"
      && webUiSessionStatus session == WebSessionOpen
      && webUiSessionClosedAt session == Nothing)
    "LocalWebUiOpened did not create an open loopback-only session"
  require (map webUiTransitionKind (planningStateWebTransitions opened)
      == [WebUiOpened])
    "LocalWebUiOpened did not record its transition"
  expectError WebUiComponentUnavailable
    (openLocalWebUi probeTime 4400
      (metroWebUiV1 {packComponentStatus = ComponentDisabled})
      emptyPlanningState)

webUiLifecycleProbe :: PlanProbe
webUiLifecycleProbe _ = do
  (session, opened) <- mapPlanning
    (openLocalWebUi probeTime 4400 metroWebUiV1 emptyPlanningState)
  (closed, closedState) <- mapPlanning
    (closeLocalWebUi (addUTCTime 1 probeTime) (webUiSessionId session) opened)
  require (webUiSessionStatus closed == WebSessionClosed
      && webUiSessionClosedAt closed == Just (addUTCTime 1 probeTime))
    "open -> closed transition did not retain close evidence"
  expectError (WebUiSessionNotOpen (webUiSessionId session))
    (closeLocalWebUi (addUTCTime 2 probeTime) (webUiSessionId session) closedState)
  expectError (WebUiSessionNotOpen (webUiSessionId session))
    (forwardWebUiInput (addUTCTime 2 probeTime) (webUiSessionId session)
      sampleForward closedState)
  require (map webUiTransitionKind (planningStateWebTransitions closedState)
      == [WebUiOpened, WebUiClosed])
    "close transition was not retained"

webUiForwardRuleProbe :: PlanProbe
webUiForwardRuleProbe _ = do
  (envelope, _) <- interactionFixture
  (session, opened) <- mapPlanning
    (openLocalWebUi probeTime 4400 metroWebUiV1 emptyPlanningState)
  rendered <- mapPlanning (renderUiEnvelope (webUiSessionId session) envelope opened)
  require (uiRenderedEnvelopeReadOnly rendered
      && uiRenderedEnvelopeEnvelope rendered == envelope)
    "web UI did not render the canonical read-only envelope"
  decoded <- mapPlanning (decodeUiInput envelope (toJSON sampleForward))
  forwarded <- mapPlanning (forwardWebUiInput probeTime
    (webUiSessionId session) decoded opened)
  require (map webUiTransitionKind (planningStateWebTransitions forwarded)
      == [WebUiOpened, WebUiForwarded])
    "valid decoded input was not forwarded as one canonical action"
  (_, closed) <- mapPlanning
    (closeLocalWebUi (addUTCTime 1 probeTime) (webUiSessionId session) opened)
  expectError (WebUiSessionNotOpen (webUiSessionId session))
    (forwardWebUiInput (addUTCTime 2 probeTime) (webUiSessionId session)
      decoded closed)

extensionDeskProbe :: PlanProbe
extensionDeskProbe _ = do
  let surface = extensionDeskSurface
      exposed = extensionDeskSurfaceExposedItems surface
      provided = extensionDeskSurfaceProvidedOperations surface
      demanded = extensionDeskSurfaceDemandedContracts surface
  require (extensionDeskSurfaceActorPartyType surface == "person")
    "ExtensionDesk is not restricted to the declared person actor"
  require (Set.fromList exposed == Set.fromList
      [ "user.id", "little-ant/standard", "standard/microsoft-todo"
      , "standard/notesnook", "standard/taskjuggler", "standard/web-metro"
      ]) "ExtensionDesk does not expose the complete standard integration set"
  require (Set.fromList provided == Set.fromList
      [ "InstallPack", "RecordPackInvocation", "DisablePack", "EnablePack"
      , "RevokePack", "StoreCredential", "BindCredential"
      , "LockCredentialBinding", "UnlockCredentialBinding"
      , "RevokeCredentialBinding", "CreateImportProfile", "RetireImportProfile"
      , "PlanImport", "StartImport", "AcceptImportCandidate"
      , "ObserveExternalCompletion", "FinishImportCapture", "VerifyImport"
      , "CompleteSynchronization", "PlanEraseAfterImport"
      , "ApproveSourceEffect", "DeclineSourceEffect", "RetrySourceEffect"
      , "RecordSourceEffectApplied", "RecordSourceEffectFailed", "CutOverImport"
      , "ProposeEmptyContainerDeletion", "ExportTaskJuggler"
      , "ImportTaskJugglerActual", "OpenLocalWebUi", "CloseLocalWebUi"
      , "SubmitWebUiInput"
      ]) "ExtensionDesk provided operations differ from the declared surface"
  require (all (`elem` demanded)
      [ "PackRunner", "HostHttp", "CredentialBroker", "SourceAdapterContract"
      , "EnricherContract", "ReadOnlyExporterContract", "UIAdapterContract"
      ]) "ExtensionDesk omits a demanded typed contract"

exporterContractProbe :: RuntimePlanProbe
exporterContractProbe _ = case planningFixture >>= successfulManifest of
  Left problem -> pure (Left problem)
  Right (_, planningExport, _) -> do
    let projection = planningExportProjection planningExport
        before = encode projection
    first <- runTaskJugglerExporter projection "probe.tjp"
    second <- runTaskJugglerExporter projection "probe.tjp"
    pure $ do
      one <- mapPlanning first
      two <- mapPlanning second
      require (one == two) "read-only exporter is not deterministic"
      require (encode projection == before)
        "read-only exporter mutated its pinned input projection"
      require (taskJugglerExporterOutputMediaType one == "text/x-taskjuggler"
          && taskJugglerExporterOutputSuggestedFilename one == "probe.tjp")
        "reference exporter returned malformed payload metadata"
      require (taskJugglerExportMetadataMacros
          (taskJugglerExporterOutputExportMetadata one)
          == ["EFFORT_4D", "EFFORT_2D"])
        "reference exporter did not emit selected profile macros"

uiRenderContractProbe :: RuntimePlanProbe
uiRenderContractProbe _ = case interactionFixture of
  Left problem -> pure (Left problem)
  Right (envelope, _) -> do
    rendered <- runMetroWebUiRender envelope
    pure $ do
      result <- mapPlanning rendered
      require (uiRenderedEnvelopeReadOnly result
          && uiRenderedEnvelopeEnvelope result == envelope)
        "UIAdapter.render changed canonical interaction content"

uiDecodeContractProbe :: RuntimePlanProbe
uiDecodeContractProbe _ = case interactionFixture of
  Left problem -> pure (Left problem)
  Right (envelope, _) -> do
    decoded <- runMetroWebUiDecode envelope (toJSON sampleForward)
    forged <- runMetroWebUiDecode envelope (toJSON sampleForward
      {uiForwardActionId = "invented"})
    stale <- runMetroWebUiDecode envelope (toJSON sampleForward
      {uiForwardInteractionRevision = 2})
    pure $ do
      result <- mapPlanning decoded
      require (result == sampleForward)
        "UIAdapter.decode did not preserve canonical identity and revisions"
      expectError (UiActionNotAvailable "invented") forged
      expectError (UiEnvelopeMismatch "interaction revision") stale

------------------------------------------------------------
-- Probe fixtures and helpers
------------------------------------------------------------

data PlanningFixture = PlanningFixture
  { fixtureProject :: Brick
  , fixtureFirstChild :: BrickId
  , fixtureSecondChild :: BrickId
  , fixtureDomain :: DomainState
  , fixtureJudgment :: JudgmentState
  }

planningFixture :: Either Text PlanningFixture
planningFixture = do
  projectTitle <- domain (mkCanonicalText "Release Little Ant 1.0" Nothing Human)
  firstTitle <- domain (mkCanonicalText "Implement event store" Nothing Human)
  secondTitle <- domain (mkCanonicalText "Implement REPL" Nothing Human)
  (project, firstDomain) <- domain (createBrick
    (ordinaryBrickDraft projectTitle projectV1 probeTime) emptyDomainState)
  (firstChild, secondDomain) <- domain (createBrick
    ((ordinaryBrickDraft firstTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId project)}) firstDomain)
  (secondChild, finalDomain) <- domain (createBrick
    ((ordinaryBrickDraft secondTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId project)}) secondDomain)
  registeredProject <- judgment (registerJudgmentBrick
    (brickId project) Nothing Domain.Active True emptyJudgmentState)
  registeredFirst <- judgment (registerJudgmentBrick
    (brickId firstChild) (Just (brickId project)) Domain.Active True registeredProject)
  registeredSecond <- judgment (registerJudgmentBrick
    (brickId secondChild) (Just (brickId project)) Domain.Active True registeredFirst)
  hard <- judgment (effortBandById initialEffortProfile "HARD" registeredSecond)
  moderated <- judgment
    (effortBandById initialEffortProfile "MODERATED" registeredSecond)
  (_, _, withFirst) <- judgment (classifyEffort (brickId firstChild) hard Human
    False (Just "planning fixture") probeTime registeredSecond)
  (_, _, finalJudgment) <- judgment (classifyEffort (brickId secondChild)
    moderated Human False (Just "planning fixture") probeTime withFirst)
  pure PlanningFixture
    { fixtureProject = project
    , fixtureFirstChild = brickId firstChild
    , fixtureSecondChild = brickId secondChild
    , fixtureDomain = finalDomain
    , fixtureJudgment = finalJudgment
    }

successfulManifest ::
  PlanningFixture -> Either Text (PlanningManifest, PlanningExport, PlanningState)
successfulManifest fixture = mapPlanning (createTaskJugglerManifest probeTime 7 7
  [fixtureFirstChild fixture, fixtureSecondChild fixture]
  initialEffortProfile validPayload taskJugglerExporterV1
  (fixtureDomain fixture) (fixtureJudgment fixture) emptyPlanningState)

interactionFixture ::
  Either Text (Interaction.InteractionEnvelope, Interaction.InteractionState)
interactionFixture = do
  (session, state) <- interaction (Interaction.openInteraction
    "guided" Nothing Nothing Nothing probeTime 7 Interaction.emptyInteractionState)
  envelope <- interaction
    (Interaction.currentInteraction (Interaction.interactionSessionId session) state)
  pure (envelope, state)

sampleForward :: UiForward
sampleForward = UiForward (Interaction.InteractionId "interaction-0") 1 7 "continue"

validPayload :: ExportPayload
validPayload = ExportPayload "text/x-taskjuggler" "little-ant.tjp"
  "sha256:planning" 4096

sampleEnricher :: PackComponent
sampleEnricher = PackComponent "example/enricher" 1 "example/pack" 1
  EnricherComponent True ComponentEnabled []

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) (21 * 60 * 60)

roundTripAndFields ::
  (Eq value, ToJSON value, FromJSON value) =>
  value -> [Text] -> Either Text ()
roundTripAndFields value expectedFields = do
  fields (toJSON value) expectedFields
  decoded <- case fromJSON (toJSON value) of
    Success result -> Right result
    Error problem -> Left (Text.pack problem)
  require (decoded == value) "typed value failed structural round-trip equality"

fields :: Value -> [Text] -> Either Text ()
fields value expected = case value of
  Object objectValue -> require (all
    (\field -> KeyMap.member (Key.fromText field) objectValue) expected)
    "projection omits one or more declared fields"
  _ -> Left "expected object projection"

valueAt :: Text -> Value -> Maybe Value
valueAt field = \case
  Object values -> KeyMap.lookup (Key.fromText field) values
  _ -> Nothing

mapPlanning :: Either PlanningError value -> Either Text value
mapPlanning = either (Left . Text.pack . show) Right

domain :: Show problem => Either problem value -> Either Text value
domain = either (Left . Text.pack . show) Right

judgment :: Show problem => Either problem value -> Either Text value
judgment = either (Left . Text.pack . show) Right

interaction :: Show problem => Either problem value -> Either Text value
interaction = either (Left . Text.pack . show) Right

expectError ::
  (Eq problem, Show problem) => problem -> Either problem value -> Either Text ()
expectError expected result = case result of
  Left actual | actual == expected -> Right ()
              | otherwise -> Left ("unexpected rejection: " <> Text.pack (show actual))
  Right _ -> Left ("expected rejection was accepted: " <> Text.pack (show expected))

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

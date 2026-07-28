{-# LANGUAGE DerivingStrategies #-}

-- | Semantic integration probes for source imports and reviewed cleanup.
module LittleAnt.V1.SourceImportPlanCatalog
  ( sourceImportPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson
  (FromJSON, Result (..), ToJSON (toJSON), Value (..), encode, fromJSON)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (isJust)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import qualified LittleAnt.V1.Coordination as Coordination
import qualified LittleAnt.V1.Domain as Domain
import qualified LittleAnt.V1.Execution as Execution
import qualified LittleAnt.V1.Integration as Integration
import qualified LittleAnt.V1.Material as Material
import qualified LittleAnt.V1.Priority as Priority
import qualified LittleAnt.V1.Selection as Selection
import qualified LittleAnt.V1.SourceImport as SourceImport
import qualified LittleAnt.V1.Standing as Standing

sourceImportPlanProbes :: Map ProbeKey PlanProbe
sourceImportPlanProbes = Map.fromList
  ( valueRegistrations
  <> contractRegistrations
  <> enumRegistrations
  <> entityRegistrations
  <> transitionRegistrations
  <> ruleRegistrations
  <> invariantRegistrations
  )

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations =
  [ registration "value_equality" "ImportCandidate" candidateValueProbe
  , registration "entity_fields" "ImportCandidate" candidateValueProbe
  ]

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "SourceAdapterContract.discover"
      discoverContractProbe
  , registration "contract_signature" "SourceAdapterContract.observe"
      observeContractProbe
  , registration "contract_signature" "SourceAdapterContract.apply_approved_effect"
      applyEffectContractProbe
  ]

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ registration "enum_comparable" "ImportProfileStatus" enumProbe
  , registration "enum_comparable" "ImportRoute" enumProbe
  , registration "enum_comparable" "ImportRunMode" enumProbe
  , registration "enum_comparable" "ImportRunStatus" enumProbe
  , registration "enum_comparable" "SourceEffectKind" enumProbe
  , registration "enum_comparable" "SourceEffectStatus" enumProbe
  ]

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ registration "entity_fields" "ImportProfile" entityProbe
  , registration "entity_optional" "ImportProfile.destination_parent" entityProbe
  , registration "entity_optional" "ImportProfile.destination_owner" entityProbe
  , registration "entity_optional" "ImportProfile.destination_shelf" entityProbe
  , registration "entity_fields" "ExternalRecord" entityProbe
  , registration "entity_optional" "ExternalRecord.container_id" entityProbe
  , registration "entity_optional" "ExternalRecord.brick" entityProbe
  , registration "entity_optional" "ExternalRecord.entry" entityProbe
  , registration "entity_optional" "ExternalRecord.last_revision" entityProbe
  , registration "entity_fields" "ImportRun" entityProbe
  , registration "entity_optional" "ImportRun.finished_at" entityProbe
  , registration "entity_optional" "ImportRun.source_cursor" entityProbe
  , registration "entity_optional" "ImportRun.receipt_hash" entityProbe
  , registration "entity_fields" "SourceEffect" entityProbe
  , registration "entity_optional" "SourceEffect.run" entityProbe
  , registration "entity_optional" "SourceEffect.record" entityProbe
  , registration "entity_optional" "SourceEffect.approved_at" entityProbe
  , registration "entity_optional" "SourceEffect.applied_at" entityProbe
  , registration "entity_optional" "SourceEffect.receipt" entityProbe
  , registration "entity_optional" "SourceEffect.failure" entityProbe
  ]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations = concat
  [ [registration category "ImportProfile.status" profileLifecycleProbe |
      category <- ["transition_edge", "transition_rejected", "transition_terminal"]]
  , [registration category "ImportRun.status" runLifecycleProbe |
      category <- ["transition_edge", "transition_rejected", "transition_terminal"]]
  , [registration category "SourceEffect.status" effectLifecycleProbe |
      category <- ["transition_edge", "transition_rejected", "transition_terminal"]]
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ rules "ImportProfileCreated"
      ["rule_success", "rule_failure", "rule_entity_creation"] profileCreationProbe
  , rules "ImportProfileRetired" ["rule_success", "rule_failure"]
      profileLifecycleProbe
  , rules "ImportRunPlanned"
      ["rule_success", "rule_failure", "rule_entity_creation"] runPlanningProbe
  , rules "ImportRunStarted" ["rule_success", "rule_failure"] runStartProbe
  , rules "NewCandidatePreservedAsRaw"
      ["rule_success", "rule_failure", "rule_entity_creation"] preservationProbe
  , rules "StructuredTaskAutomaticallyAdoptedAtRoot"
      ["rule_success", "rule_failure", "rule_entity_creation", "rule_guarantee"]
      rootAdoptionProbe
  , rules "StructuredTaskAutomaticallyAdoptedUnderParent"
      ["rule_success", "rule_failure", "rule_entity_creation"] parentAdoptionProbe
  , rules "StructuredItemAutomaticallyAdoptedAsListEntry"
      ["rule_success", "rule_failure", "rule_entity_creation", "rule_guarantee"]
      entryAdoptionProbe
  , rules "ExistingExternalObjectReconciled"
      ["rule_success", "rule_failure"] reconciliationProbe
  , rules "ExternalCompletionCreatesReviewProposal"
      ["rule_success", "rule_failure", "rule_entity_creation"] completionReviewProbe
  , rules "ImportCaptureFinished" ["rule_success", "rule_failure"] captureFinishProbe
  , rules "ImportVerified" ["rule_success", "rule_failure"] verificationProbe
  , rules "ImportVerificationFailed" ["rule_success", "rule_failure"]
      verificationFailureProbe
  , rules "SynchronizationCompleted" ["rule_success", "rule_failure"]
      synchronizationProbe
  , rules "VerifiedMigrationProposesItemCleanup"
      ["rule_success", "rule_failure", "rule_entity_creation", "rule_guarantee"]
      cleanupPlanningProbe
  , rules "SourceEffectApproved" ["rule_success", "rule_failure"]
      effectApprovalProbe
  , rules "SourceEffectDeclined" ["rule_success", "rule_failure"]
      effectDeclineProbe
  , rules "FailedSourceEffectRetried" ["rule_success", "rule_failure", "rule_guarantee"]
      effectRetryProbe
  , rules "ApprovedSourceEffectApplied" ["rule_success", "rule_failure"]
      effectApplyProbe
  , rules "ApprovedSourceEffectFailed" ["rule_success", "rule_failure"]
      effectFailureProbe
  , rules "MigrationCutOver" ["rule_success", "rule_failure"] cutoverProbe
  , rules "EmptyContainerDeletionProposedSeparately"
      ["rule_success", "rule_failure", "rule_entity_creation", "rule_guarantee"]
      containerEffectProbe
  ]
  where
    rules construct categories probe =
      [registration category construct probe | category <- categories]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" "ExternalIdentityIsStablePerProfile"
      externalIdentityProbe
  , registration "invariant" "ExternalRecordHasAtMostOneWorkAdoption"
      workAdoptionInvariantProbe
  , registration "invariant" "RootPriorityBindingIsCanonical"
      canonicalBindingsProbe
  , registration "invariant" "StandardBehaviorBindingIsCanonical"
      canonicalBindingsProbe
  ]

registration :: Text -> Text -> PlanProbe -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "integration" category construct, \input -> do
    require (planProbeModule input == "integration") "probe received wrong module"
    require (planProbeCategory input == category) "probe received wrong category"
    require (planProbeSourceConstruct input == construct)
      "probe received wrong source construct"
    probe input)

------------------------------------------------------------
-- Values, contracts, enums, and entities
------------------------------------------------------------

candidateValueProbe :: PlanProbe
candidateValueProbe _ = roundTripAndFields sampleCandidate
  [ "provider", "account", "external_id", "container_id", "kind"
  , "original_title", "canonical_english", "normalization_authority", "body"
  , "content_hash", "revision", "presence", "work_state"
  ]

discoverContractProbe :: PlanProbe
discoverContractProbe _ = do
  candidates <- mapImport (SourceImport.reconcileAdapterCandidates
    [sampleCandidate, sampleCandidateTwo])
  require (length candidates == 2) "discover dropped normalized candidates"
  expectImportError isInvalidCandidate (SourceImport.reconcileAdapterCandidates
    [sampleCandidate, sampleCandidate])
  -- An empty page is valid and produces no inferred tombstone.
  empty <- mapImport (SourceImport.reconcileAdapterCandidates [])
  require (null empty) "empty discovery page invented removal evidence"
  where
    isInvalidCandidate (SourceImport.InvalidImportCandidate _) = True
    isInvalidCandidate _ = False

observeContractProbe :: PlanProbe
observeContractProbe _ = do
  observed <- mapImport (SourceImport.validateImportCandidate sampleCandidate
    { SourceImport.importCandidatePresence = Material.Removed
    , SourceImport.importCandidateWorkState = Material.WorkUnknown
    })
  require (SourceImport.importCandidatePresence observed == Material.Removed
      && SourceImport.importCandidateWorkState observed == Material.WorkUnknown)
    "adapter observation collapsed presence into work state"
  expectImportError isInvalidCandidate (SourceImport.validateImportCandidate
    sampleCandidate {SourceImport.importCandidateNormalizationAuthority = Nothing})
  where
    isInvalidCandidate (SourceImport.InvalidImportCandidate _) = True
    isInvalidCandidate _ = False

applyEffectContractProbe :: PlanProbe
applyEffectContractProbe _ = do
  fixture <- migrationFixture
  effect <- onlyEffect fixture
  approved <- mapImport (uncurryState2 (SourceImport.approveSourceEffect testTime)
    (SourceImport.sourceEffectId effect) fixture)
  let (approvedEffect, approvedFixture) = approved
  authorized <- mapImport (SourceImport.authorizeApprovedSourceEffect
    (SourceImport.sourceEffectId approvedEffect) (fixtureImports approvedFixture))
  require (authorized == approvedEffect) "approved effect identity changed at adapter boundary"
  expectImportError isTransition (SourceImport.authorizeApprovedSourceEffect
    (SourceImport.sourceEffectId effect) (fixtureImports fixture))
  where
    isTransition (SourceImport.InvalidSourceEffectTransition _) = True
    isTransition _ = False

valueEnums :: [[Value]]
valueEnums =
  [ map toJSON [minBound .. maxBound :: SourceImport.ImportProfileStatus]
  , map toJSON [minBound .. maxBound :: SourceImport.ImportRoute]
  , map toJSON [minBound .. maxBound :: SourceImport.ImportRunMode]
  , map toJSON [minBound .. maxBound :: SourceImport.ImportRunStatus]
  , map toJSON [minBound .. maxBound :: SourceImport.SourceEffectKind]
  , map toJSON [minBound .. maxBound :: SourceImport.SourceEffectStatus]
  ]

enumProbe :: PlanProbe
enumProbe _ = mapM_ check valueEnums
  where
    check values = do
      require (Set.size (Set.fromList (map encode values)) == length values)
        "enum variants are not structurally distinct"
      require (all canonical values) "enum did not encode as canonical text"
    canonical (String text) = not (Text.null text) && Text.toLower text == text
    canonical _ = False

entityProbe :: PlanProbe
entityProbe input = do
  fixture <- migrationFixture
  profile <- fixtureProfileValue fixture
  record <- fixtureRecordValue fixture
  run <- fixtureRunValue fixture
  effect <- onlyEffect fixture
  let construct = planProbeSourceConstruct input
      profileValue = SourceImport.importProfileProjection profile
      recordValue = SourceImport.sourceRecordProjection record
      runValue = SourceImport.importRunProjection run
      effectValue = SourceImport.sourceEffectProjection effect
  case construct of
    "ImportProfile" -> fields profileValue
      [ "id", "version", "name", "adapter", "source_scope", "candidate_kind"
      , "route", "destination_parent", "destination_owner", "destination_shelf"
      , "automatic_adoption", "status", "created_at"
      ]
    "ImportProfile.destination_parent" -> optionalPair profileValue
      (SourceImport.importProfileProjection profile
        {SourceImport.importProfileDestinationParent = Just sampleBrickId})
      "destination_parent"
    "ImportProfile.destination_owner" -> optionalPair profileValue
      (SourceImport.importProfileProjection profile
        {SourceImport.importProfileDestinationOwner = Just sampleBrickId})
      "destination_owner"
    "ImportProfile.destination_shelf" -> optionalPair profileValue
      (SourceImport.importProfileProjection profile
        {SourceImport.importProfileDestinationShelf = Just sampleShelfId})
      "destination_shelf"
    "ExternalRecord" -> fields recordValue
      [ "id", "profile", "provider", "account", "external_id", "container_id"
      , "raw", "brick", "entry", "presence", "work_state", "last_revision"
      , "last_observed_at"
      ]
    "ExternalRecord.container_id" -> optionalPair
      (SourceImport.sourceRecordProjection record
        {SourceImport.externalRecordContainerId = Nothing}) recordValue "container_id"
    "ExternalRecord.brick" -> optionalPair
      (SourceImport.sourceRecordProjection record
        {SourceImport.externalRecordBrick = Nothing}) recordValue "brick"
    "ExternalRecord.entry" -> optionalPair recordValue
      (SourceImport.sourceRecordProjection record
        { SourceImport.externalRecordBrick = Nothing
        , SourceImport.externalRecordEntry = Just sampleEntryId
        }) "entry"
    "ExternalRecord.last_revision" -> optionalPair
      (SourceImport.sourceRecordProjection record
        {SourceImport.externalRecordLastRevision = Nothing}) recordValue "last_revision"
    "ImportRun" -> fields runValue
      [ "id", "profile", "mode", "status", "erase_after_import", "started_at"
      , "finished_at", "source_cursor", "captured_count", "verified_count"
      , "failure_count", "receipt_hash"
      ]
    "ImportRun.finished_at" -> optionalPair
      (SourceImport.importRunProjection run {SourceImport.importRunFinishedAt = Nothing})
      (SourceImport.importRunProjection run {SourceImport.importRunFinishedAt = Just testTime})
      "finished_at"
    "ImportRun.source_cursor" -> optionalPair runValue
      (SourceImport.importRunProjection run {SourceImport.importRunSourceCursor = Just "next"})
      "source_cursor"
    "ImportRun.receipt_hash" -> optionalPair runValue
      (SourceImport.importRunProjection run {SourceImport.importRunReceiptHash = Just "sha256:r"})
      "receipt_hash"
    "SourceEffect" -> fields effectValue
      [ "id", "run", "record", "kind", "preview", "status", "proposed_at"
      , "approved_at", "applied_at", "receipt", "failure"
      ]
    "SourceEffect.run" -> optionalPair
      (SourceImport.sourceEffectProjection effect {SourceImport.sourceEffectRun = Nothing})
      effectValue "run"
    "SourceEffect.record" -> optionalPair
      (SourceImport.sourceEffectProjection effect {SourceImport.sourceEffectRecord = Nothing})
      effectValue "record"
    "SourceEffect.approved_at" -> optionalPair effectValue
      (SourceImport.sourceEffectProjection effect
        {SourceImport.sourceEffectApprovedAt = Just testTime}) "approved_at"
    "SourceEffect.applied_at" -> optionalPair effectValue
      (SourceImport.sourceEffectProjection effect
        {SourceImport.sourceEffectAppliedAt = Just testTime}) "applied_at"
    "SourceEffect.receipt" -> optionalPair effectValue
      (SourceImport.sourceEffectProjection effect
        {SourceImport.sourceEffectReceipt = Just "receipt"}) "receipt"
    "SourceEffect.failure" -> optionalPair effectValue
      (SourceImport.sourceEffectProjection effect
        {SourceImport.sourceEffectFailure = Just "failure"}) "failure"
    _ -> Left ("unsupported source-import entity probe: " <> construct)

------------------------------------------------------------
-- Profiles, runs, and candidate routing
------------------------------------------------------------

profileCreationProbe :: PlanProbe
profileCreationProbe _ = do
  base <- sampleBase
  (rawProfile, rawState) <- createProfile SourceImport.PreserveRaw Nothing Nothing
    (Just (fixtureShelf base)) False base
  require (SourceImport.importProfileStatus rawProfile == SourceImport.ImportProfileActive)
    "new profile is not active"
  (rootProfile, rootState) <- createProfileFrom rawState SourceImport.AdoptBrick
    Nothing Nothing Nothing True base
  (parentProfile, parentState) <- createProfileFrom rootState SourceImport.AdoptBrick
    (Just (Domain.brickId (fixtureParent base))) Nothing Nothing True base
  (entryProfile, _) <- createProfileFrom parentState SourceImport.AdoptListEntry
    Nothing (Just (Domain.brickId (fixtureOwner base))) Nothing True base
  require (all ((== 1) . SourceImport.importProfileVersion)
      [rawProfile, rootProfile, parentProfile, entryProfile])
    "profile creation did not pin version 1"
  let wrongKind = SourceImport.microsoftTodoAdapterV1
        {Integration.packComponentKind = Integration.ReadOnlyExporterComponent}
      disabled = SourceImport.microsoftTodoAdapterV1
        {Integration.packComponentStatus = Integration.ComponentDisabled}
  expectCreateFailure wrongKind SourceImport.AdoptBrick Nothing Nothing Nothing base
  expectCreateFailure disabled SourceImport.AdoptBrick Nothing Nothing Nothing base
  expectCreateFailure SourceImport.microsoftTodoAdapterV1 SourceImport.AdoptBrick
    Nothing (Just (Domain.brickId (fixtureOwner base))) Nothing base
  expectCreateFailure SourceImport.microsoftTodoAdapterV1 SourceImport.AdoptListEntry
    Nothing Nothing Nothing base
  expectCreateFailure SourceImport.microsoftTodoAdapterV1 SourceImport.AdoptListEntry
    (Just (Domain.brickId (fixtureParent base)))
    (Just (Domain.brickId (fixtureOwner base))) Nothing base
  expectCreateFailure SourceImport.microsoftTodoAdapterV1 SourceImport.AdoptListEntry
    Nothing (Just (Domain.brickId (fixtureParent base))) Nothing base
  expectCreateFailure SourceImport.microsoftTodoAdapterV1 SourceImport.AdoptBrick
    Nothing Nothing (Just (fixtureShelf base)) base

profileLifecycleProbe :: PlanProbe
profileLifecycleProbe _ = do
  captured <- capturedRootFixture
  let profileId = SourceImport.importProfileId (fixtureProfile captured)
  (retired, material, imports) <- mapImport (SourceImport.retireImportProfile
    profileId (fixtureStanding captured) (fixtureMaterial captured)
    (fixtureImports captured))
  require (SourceImport.importProfileStatus retired == SourceImport.ImportProfileRetired)
    "active profile did not retire"
  require (all Material.rawOriginHistoricalOnly
      (Map.elems (Material.materialOrigins material)))
    "retirement did not make captured origins historical"
  expectImportError isProfileTransition (SourceImport.retireImportProfile profileId
    (fixtureStanding captured) material imports)
  where
    isProfileTransition (SourceImport.InvalidImportProfileTransition _) = True
    isProfileTransition _ = False

runPlanningProbe :: PlanProbe
runPlanningProbe _ = do
  fixture <- profileFixture SourceImport.AdoptBrick Nothing Nothing Nothing True
  (sync, syncState) <- planRun SourceImport.Synchronize False fixture
  (migration, _) <- planRunFrom syncState SourceImport.Migrate True fixture
  require (SourceImport.importRunStatus sync == SourceImport.ImportPlanned
      && SourceImport.importRunCapturedCount sync == 0
      && SourceImport.importRunStatus migration == SourceImport.ImportPlanned)
    "planned run did not start with zeroed counters"
  expectImportError (== SourceImport.MigrationCleanupNotAllowed)
    (planRunResult SourceImport.Synchronize True fixture)
  let profileId = SourceImport.importProfileId (fixtureProfile fixture)
  (_, material, retiredImports) <- mapImport (SourceImport.retireImportProfile
    profileId (fixtureStanding fixture) (fixtureMaterial fixture)
    (fixtureImports fixture))
  expectImportError isProfileTransition (SourceImport.planImport testTime profileId
    SourceImport.Migrate False (fixtureStanding fixture) material retiredImports)
  where
    isProfileTransition (SourceImport.InvalidImportProfileTransition _) = True
    isProfileTransition _ = False

runStartProbe :: PlanProbe
runStartProbe _ = do
  fixture <- plannedRootFixture SourceImport.Synchronize False
  (running, imports) <- mapImport (SourceImport.startImport
    (SourceImport.importRunId (fixtureRun fixture)) (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture))
  require (SourceImport.importRunStatus running == SourceImport.ImportRunning)
    "planned run did not start"
  expectImportError isRunTransition (SourceImport.startImport
    (SourceImport.importRunId running) (fixtureStanding fixture)
    (fixtureMaterial fixture) imports)
  where
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

preservationProbe :: PlanProbe
preservationProbe _ = do
  rawFixture <- runningFixture SourceImport.PreserveRaw Nothing NoOwner Nothing True
  rawCaptured <- captureCandidate sampleCandidate rawFixture
  assertPreserved rawCaptured
  manualFixture <- runningFixture SourceImport.AdoptBrick Nothing NoOwner Nothing False
  captureCandidate sampleCandidate manualFixture >>= assertPreserved
  missingCanonicalFixture <- runningFixture SourceImport.AdoptBrick Nothing NoOwner Nothing True
  captureCandidate sampleCandidate
    { SourceImport.importCandidateCanonicalEnglish = Nothing
    , SourceImport.importCandidateNormalizationAuthority = Nothing
    } missingCanonicalFixture >>= assertPreserved
  wrongKindFixture <- runningFixture SourceImport.AdoptBrick Nothing NoOwner Nothing True
  captureCandidate sampleCandidate {SourceImport.importCandidateKind = "note"}
    wrongKindFixture >>= assertPreserved
  listWrongKind <- runningFixture SourceImport.AdoptListEntry Nothing
    FixtureOwner Nothing True
  captureCandidate sampleCandidate {SourceImport.importCandidateKind = "note"}
    listWrongKind >>= assertPreserved
  planned <- plannedRootFixture SourceImport.Synchronize False
  expectImportError isRunTransition (captureResult sampleCandidate planned)
  where
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

rootAdoptionProbe :: PlanProbe
rootAdoptionProbe _ = do
  fixture <- runningFixture SourceImport.AdoptBrick Nothing NoOwner Nothing True
  adopted <- captureCandidate sampleCandidate fixture
  assertBrickAdoption Nothing adopted
  let recordId = SourceImport.externalRecordId (fixtureRecord adopted)
      rawCount = Map.size (Material.materialRaws (fixtureMaterial adopted))
  reconciled <- captureCandidate sampleCandidate
    {SourceImport.importCandidateRevision = Just "2"
    , SourceImport.importCandidateContentHash = "sha256:task-42-v2"
    } adopted
  require (SourceImport.externalRecordId (fixtureRecord reconciled) == recordId
      && Map.size (Material.materialRaws (fixtureMaterial reconciled)) == rawCount)
    "root adoption duplicated stable external identity"
  -- Every non-adoption branch named by the rule remains captured as Raw.
  mapM_ (\candidate -> do
      branch <- runningFixture SourceImport.AdoptBrick Nothing NoOwner Nothing True
      captureCandidate candidate branch >>= assertPreserved)
    [ sampleCandidate {SourceImport.importCandidateKind = "note"}
    , sampleCandidate
        { SourceImport.importCandidateCanonicalEnglish = Nothing
        , SourceImport.importCandidateNormalizationAuthority = Nothing
        }
    ]

parentAdoptionProbe :: PlanProbe
parentAdoptionProbe _ = do
  base <- sampleBase
  fixture <- runningFixtureWithBase base SourceImport.AdoptBrick
    (Just (Domain.brickId (fixtureParent base))) Nothing Nothing True
  adopted <- captureCandidate sampleCandidate fixture
  assertBrickAdoption (Just (Domain.brickId (fixtureParent base))) adopted
  let domain = standingDomain (fixtureStanding adopted)
      brick = fixtureBrick adopted
  require (Domain.brickParent brick == Just (Domain.brickId (fixtureParent base))
      && Map.member (Domain.brickId (fixtureParent base)) (Domain.domainBricks domain))
    "under-parent adoption ignored its active destination"

entryAdoptionProbe :: PlanProbe
entryAdoptionProbe _ = do
  base <- sampleBase
  fixture <- runningFixtureWithBase base SourceImport.AdoptListEntry Nothing
    (Just (Domain.brickId (fixtureOwner base))) Nothing True
  adopted <- captureCandidate sampleCandidate fixture
  entry <- maybe (Left "list-entry adoption did not create an entry") Right
    (fixtureMaybeEntry adopted)
  require (Domain.listEntryOwner entry == Domain.brickId (fixtureOwner base)
      && SourceImport.externalRecordBrick (fixtureRecord adopted) == Nothing
      && SourceImport.externalRecordEntry (fixtureRecord adopted)
        == Just (Domain.listEntryId entry))
    "ListEntry adoption created an independent Brick adoption"
  let priority = standingPriority (fixtureStanding adopted)
  require (all (notElem (Domain.listEntryOwner entry) . Priority.priorityScopeMembers)
      [] || Map.size (Priority.priorityStateInsertions priority) == 2)
    "ListEntry received an independent priority insertion"
  require (any ((== Just (Domain.listEntryId entry)) . Material.rawLinkOwnerEntry)
      (Map.elems (Material.materialLinks (fixtureMaterial adopted))))
    "ListEntry adoption omitted its source RawLink"
  listItem <- runningFixtureWithBase base SourceImport.AdoptListEntry Nothing
    (Just (Domain.brickId (fixtureOwner base))) Nothing True
  captureCandidate sampleCandidate {SourceImport.importCandidateKind = "list_item"}
    listItem >>= \result -> require (isJust (fixtureMaybeEntry result))
      "list_item was not adopted by a compatible owner"

reconciliationProbe :: PlanProbe
reconciliationProbe _ = do
  first <- capturedRootFixture
  let record = fixtureRecord first
      brick = fixtureBrick first
      oldRaw = SourceImport.externalRecordRaw record
      oldStatus = Domain.brickStatus brick
  second <- captureCandidate sampleCandidate
    { SourceImport.importCandidateRevision = Just "2"
    , SourceImport.importCandidateContentHash = "sha256:changed"
    , SourceImport.importCandidatePresence = Material.Removed
    , SourceImport.importCandidateWorkState = Material.WorkCompleted
    } first
  let changed = fixtureRecord second
  require (SourceImport.externalRecordId changed == SourceImport.externalRecordId record
      && SourceImport.externalRecordRaw changed == oldRaw
      && SourceImport.externalRecordPresence changed == Material.Removed
      && SourceImport.externalRecordWorkState changed == Material.WorkCompleted)
    "existing external object was duplicated or not reconciled"
  require (Domain.brickStatus (fixtureBrick second) == oldStatus)
    "provider state silently changed local Brick lifecycle"
  require (length [snapshot | snapshot <- Map.elems
      (Material.materialSnapshots (fixtureMaterial second)),
      Material.rawSnapshotRaw snapshot == oldRaw] == 2)
    "changed provider content did not append an immutable snapshot"
  completed <- completeCapture second
  expectImportError isRunTransition (captureResult sampleCandidate completed)
  where
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

completionReviewProbe :: PlanProbe
completionReviewProbe _ = do
  captured <- capturedRootFixture
  completed <- captureCandidate sampleCandidate
    { SourceImport.importCandidateWorkState = Material.WorkCompleted
    , SourceImport.importCandidateRevision = Just "2"
    } captured
  let recordId = SourceImport.externalRecordId (fixtureRecord completed)
      brickId = Domain.brickId (fixtureBrick completed)
  (proposal, selection, imports) <- mapImport
    (SourceImport.observeExternalCompletion testTime recordId
      (fixtureStanding completed) (fixtureMaterial completed)
      Selection.emptySelectionState (fixtureImports completed))
  require (Selection.proposalKind proposal == Selection.BrickReview
      && Selection.proposalBrick proposal == Just brickId
      && Selection.proposalReason proposal
        == "the attributed external source reports completion"
      && Selection.proposalStatus proposal == Selection.ProposalOpen
      && Selection.proposalCreatedAt proposal == testTime
      && Selection.proposalAvailableAt proposal == testTime
      && Map.lookup (Selection.proposalId proposal)
          (Selection.selectionStateProposals selection) == Just proposal
      && Set.member brickId (SourceImport.sourceImportCompletionReviews imports))
    "external completion did not persist the declared open Brick-review Proposal"
  expectImportError isCandidate
    (SourceImport.observeExternalCompletion testTime recordId
      (fixtureStanding completed) (fixtureMaterial completed) selection imports)
  preserved <- runningFixture SourceImport.PreserveRaw Nothing NoOwner Nothing True
    >>= captureCandidate sampleCandidate
      {SourceImport.importCandidateWorkState = Material.WorkCompleted}
  expectImportError isCandidate (SourceImport.observeExternalCompletion testTime
    (SourceImport.externalRecordId (fixtureRecord preserved))
    (fixtureStanding preserved) (fixtureMaterial preserved)
    Selection.emptySelectionState (fixtureImports preserved))
  open <- capturedRootFixture
  expectImportError isCandidate (SourceImport.observeExternalCompletion testTime
    (SourceImport.externalRecordId (fixtureRecord open))
    (fixtureStanding open) (fixtureMaterial open)
    Selection.emptySelectionState (fixtureImports open))
  terminalStanding <- mapStanding (Standing.completeStandingBrick
    brickId Nothing "external-completion-probe" testTime (fixtureStanding completed))
  expectImportError isTerminal (SourceImport.observeExternalCompletion testTime
    recordId terminalStanding (fixtureMaterial completed)
    Selection.emptySelectionState (fixtureImports completed))
  where
    isCandidate (SourceImport.InvalidImportCandidate _) = True
    isCandidate _ = False
    isTerminal (SourceImport.InvalidImportDestination _) = True
    isTerminal _ = False

captureFinishProbe :: PlanProbe
captureFinishProbe _ = do
  captured <- capturedRootFixture
  (run, imports) <- mapImport (SourceImport.finishImportCapture
    (SourceImport.importRunId (fixtureRun captured)) (Just "cursor:next")
    (fixtureStanding captured) (fixtureMaterial captured) (fixtureImports captured))
  require (SourceImport.importRunStatus run == SourceImport.ImportCaptured
      && SourceImport.importRunSourceCursor run == Just "cursor:next")
    "capture checkpoint omitted status or cursor"
  expectImportError isRunTransition (SourceImport.finishImportCapture
    (SourceImport.importRunId run) Nothing (fixtureStanding captured)
    (fixtureMaterial captured) imports)
  where
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

verificationProbe :: PlanProbe
verificationProbe _ = do
  captured <- completeCapture =<< capturedRootFixture
  let run = fixtureRun captured
  (verified, imports) <- mapImport (SourceImport.verifyImport testTime
    (SourceImport.importRunId run) (SourceImport.importRunCapturedCount run) 0
    (fixtureStanding captured) (fixtureMaterial captured) (fixtureImports captured))
  require (SourceImport.importRunStatus verified == SourceImport.ImportVerifiedStatus
      && SourceImport.importRunVerifiedCount verified
        == SourceImport.importRunCapturedCount run)
    "verification did not retain exact counts"
  expectImportError isRunTransition (SourceImport.verifyImport testTime
    (SourceImport.importRunId verified) 1 0 (fixtureStanding captured)
    (fixtureMaterial captured) imports)
  migration <- unreviewedMigrationFixture
  let migrationRun = fixtureRun migration
  expectImportError (== SourceImport.ImportVerificationIncomplete)
    (SourceImport.verifyImport testTime (SourceImport.importRunId migrationRun)
      (SourceImport.importRunCapturedCount migrationRun) 0
      (fixtureStanding migration) (fixtureMaterial migration) (fixtureImports migration))
  where
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

verificationFailureProbe :: PlanProbe
verificationFailureProbe _ = do
  first <- completeCapture =<< capturedRootFixture
  let firstRun = fixtureRun first
  (mismatch, _) <- mapImport (SourceImport.verifyImport testTime
    (SourceImport.importRunId firstRun) 0 0 (fixtureStanding first)
    (fixtureMaterial first) (fixtureImports first))
  require (SourceImport.importRunStatus mismatch == SourceImport.ImportFailed
      && SourceImport.importRunVerifiedCount mismatch == 0)
    "count mismatch did not fail verification"
  second <- completeCapture =<< capturedRootFixture
  let secondRun = fixtureRun second
  (failed, imports) <- mapImport (SourceImport.verifyImport testTime
    (SourceImport.importRunId secondRun) (SourceImport.importRunCapturedCount secondRun)
    1 (fixtureStanding second) (fixtureMaterial second) (fixtureImports second))
  require (SourceImport.importRunStatus failed == SourceImport.ImportFailed
      && SourceImport.importRunFailureCount failed == 1
      && isJust (SourceImport.importRunFinishedAt failed))
    "reported failure did not terminally fail verification"
  expectImportError isRunTransition (SourceImport.verifyImport testTime
    (SourceImport.importRunId failed) 1 0 (fixtureStanding second)
    (fixtureMaterial second) imports)
  where
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

synchronizationProbe :: PlanProbe
synchronizationProbe _ = do
  verified <- verifiedSyncFixture
  let run = fixtureRun verified
      profileId = SourceImport.importRunProfile run
  (completed, imports) <- mapImport (SourceImport.completeSynchronization testTime
    (SourceImport.importRunId run) "sha256:sync" (fixtureStanding verified)
    (fixtureMaterial verified) (fixtureImports verified))
  profile <- lookupProfile profileId imports
  require (SourceImport.importRunStatus completed == SourceImport.ImportCompleted
      && SourceImport.importRunReceiptHash completed == Just "sha256:sync"
      && SourceImport.importProfileStatus profile == SourceImport.ImportProfileActive)
    "synchronization completion retired the profile or omitted receipt"
  migration <- verifiedMigrationNoCleanupFixture
  expectImportError isRunTransition (SourceImport.completeSynchronization testTime
    (SourceImport.importRunId (fixtureRun migration)) "wrong-mode"
    (fixtureStanding migration) (fixtureMaterial migration) (fixtureImports migration))
  expectImportError isRunTransition (SourceImport.completeSynchronization testTime
    (SourceImport.importRunId completed) "again" (fixtureStanding verified)
    (fixtureMaterial verified) imports)
  where
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

------------------------------------------------------------
-- Cleanup transitions, cutover, and invariants
------------------------------------------------------------

cleanupPlanningProbe :: PlanProbe
cleanupPlanningProbe _ = do
  fixture <- migrationFixture
  effect <- onlyEffect fixture
  require (SourceImport.sourceEffectKind effect == SourceImport.EraseObject
      && SourceImport.sourceEffectStatus effect == SourceImport.EffectProposed
      && isJust (SourceImport.sourceEffectRecord effect)
      && not (Text.null (SourceImport.sourceEffectPreview effect)))
    "migration cleanup was not item-scoped and previewed"
  sync <- verifiedSyncFixture
  expectPlanCleanupFailure sync
  noErase <- verifiedMigrationNoCleanupFixture
  expectPlanCleanupFailure noErase
  planned <- plannedRootFixture SourceImport.Migrate True
  expectPlanCleanupFailure planned
  noCapability <- verifiedMigrationNoCleanupFixture
  let profile = fixtureProfile noCapability
      adapter = (SourceImport.importProfileAdapter profile)
        {Integration.packComponentCapabilities = []}
      changedProfile = profile {SourceImport.importProfileAdapter = adapter}
      changedImports = (fixtureImports noCapability)
        {SourceImport.sourceImportProfiles = Map.insert
          (SourceImport.importProfileId profile) changedProfile
          (SourceImport.sourceImportProfiles (fixtureImports noCapability))}
      incapable = noCapability {fixtureImports = changedImports}
  expectPlanCleanupFailure incapable
  mixed <- multiRecordVerifiedMigrationFixture
  let records = Map.elems
        (SourceImport.sourceImportRecords (fixtureImports mixed))
      byExternal externalId = case filter
          ((== externalId) . SourceImport.externalRecordExternalId) records of
        [record] -> Right record
        _ -> Left ("missing cleanup record " <> externalId)
  eligibleRecord <- byExternal "task-42"
  unavailableRecord <- byExternal "task-43"
  conflictedRecord <- byExternal "task-44"
  snapshot <- latestSnapshotFor unavailableRecord (fixtureMaterial mixed)
  let brokenSnapshot = snapshot
        { Material.rawSnapshotAvailability = Material.SnapshotMissing
        , Material.rawSnapshotVerifiedAt = Nothing
        }
      brokenMaterial = (fixtureMaterial mixed)
        {Material.materialSnapshots = Map.insert (Material.rawSnapshotId snapshot)
          brokenSnapshot (Material.materialSnapshots (fixtureMaterial mixed))}
      conflictImports = (fixtureImports mixed)
        {SourceImport.sourceImportUnresolvedConflicts = Set.singleton
          (SourceImport.externalRecordId conflictedRecord)}
  (effects, plannedImports) <- mapImport (SourceImport.planEraseAfterImport testTime
    (SourceImport.importRunId (fixtureRun mixed)) (fixtureStanding mixed)
    brokenMaterial conflictImports)
  require (map SourceImport.sourceEffectRecord effects
      == [Just (SourceImport.externalRecordId eligibleRecord)]
      && Map.member (SourceImport.externalRecordId unavailableRecord)
        (SourceImport.sourceImportRecords plannedImports)
      && Set.member (SourceImport.externalRecordId conflictedRecord)
        (SourceImport.sourceImportUnresolvedConflicts plannedImports))
    "one lossy or conflicted item blocked another item's cleanup or disappeared"
  expectImportError (== SourceImport.ImportCleanupUnresolved)
    (SourceImport.cutOverImport testTime
      (SourceImport.importRunId (fixtureRun mixed)) "premature"
      (fixtureStanding mixed) brokenMaterial plannedImports)
  (recovered, _) <- mapImport (SourceImport.planEraseAfterImport testTime
    (SourceImport.importRunId (fixtureRun mixed)) (fixtureStanding mixed)
    (fixtureMaterial mixed) (plannedImports
      {SourceImport.sourceImportUnresolvedConflicts = Set.empty}))
  require (Set.fromList (map SourceImport.sourceEffectRecord recovered)
      == Set.fromList
        [ Just (SourceImport.externalRecordId unavailableRecord)
        , Just (SourceImport.externalRecordId conflictedRecord)
        ])
    "resolving item dispositions did not plan only their still-missing effects"

effectApprovalProbe :: PlanProbe
effectApprovalProbe _ = do
  fixture <- migrationFixture
  effect <- onlyEffect fixture
  (approved, next) <- mapImport (uncurryState2
    (SourceImport.approveSourceEffect testTime)
    (SourceImport.sourceEffectId effect) fixture)
  require (SourceImport.sourceEffectStatus approved == SourceImport.EffectApproved
      && SourceImport.sourceEffectApprovedAt approved == Just testTime)
    "effect approval omitted explicit time"
  expectImportError isTransition (uncurryState2
    (SourceImport.approveSourceEffect testTime)
    (SourceImport.sourceEffectId approved) next)
  where
    isTransition (SourceImport.InvalidSourceEffectTransition _) = True
    isTransition _ = False

effectDeclineProbe :: PlanProbe
effectDeclineProbe _ = do
  proposed <- migrationFixture
  effect <- onlyEffect proposed
  (declined, _) <- mapImport (uncurryState2 SourceImport.declineSourceEffect
    (SourceImport.sourceEffectId effect) proposed)
  require (SourceImport.sourceEffectStatus declined == SourceImport.EffectDeclined)
    "proposed effect was not declined"
  failed <- failedEffectFixture
  failedEffect <- onlyEffect failed
  (declinedFailed, terminal) <- mapImport (uncurryState2
    SourceImport.declineSourceEffect (SourceImport.sourceEffectId failedEffect) failed)
  require (SourceImport.sourceEffectStatus declinedFailed == SourceImport.EffectDeclined)
    "failed effect was not declineable"
  expectImportError isTransition (uncurryState2 SourceImport.declineSourceEffect
    (SourceImport.sourceEffectId declinedFailed) terminal)
  where
    isTransition (SourceImport.InvalidSourceEffectTransition _) = True
    isTransition _ = False

effectRetryProbe :: PlanProbe
effectRetryProbe _ = do
  failed <- failedEffectFixture
  effect <- onlyEffect failed
  (retried, next) <- mapImport (uncurryState2 SourceImport.retrySourceEffect
    (SourceImport.sourceEffectId effect) failed)
  require (SourceImport.sourceEffectStatus retried == SourceImport.EffectApproved
      && SourceImport.sourceEffectFailure retried == Nothing
      && SourceImport.sourceEffectId retried == SourceImport.sourceEffectId effect)
    "retry broadened or replaced the approved effect"
  expectImportError isTransition (uncurryState2 SourceImport.retrySourceEffect
    (SourceImport.sourceEffectId retried) next)
  let record = fixtureRecord failed
      changedRecord = record {SourceImport.externalRecordLastRevision = Just "changed"}
      changedImports = (fixtureImports failed)
        {SourceImport.sourceImportRecords = Map.insert
          (SourceImport.externalRecordId record) changedRecord
          (SourceImport.sourceImportRecords (fixtureImports failed))}
  expectImportError (== SourceImport.SourceEffectTargetChanged)
    (uncurryState2 SourceImport.retrySourceEffect (SourceImport.sourceEffectId effect)
      failed {fixtureImports = changedImports})
  where
    isTransition (SourceImport.InvalidSourceEffectTransition _) = True
    isTransition _ = False

effectApplyProbe :: PlanProbe
effectApplyProbe _ = do
  approved <- approvedEffectFixture
  effect <- onlyEffect approved
  (applied, next) <- mapImport (uncurryState3 (SourceImport.applySourceEffect testTime)
    (SourceImport.sourceEffectId effect) "provider:req-1" approved)
  let changedRecord = fixtureRecord next
  require (SourceImport.sourceEffectStatus applied == SourceImport.EffectApplied
      && SourceImport.sourceEffectReceipt applied == Just "provider:req-1"
      && SourceImport.externalRecordPresence changedRecord == Material.Removed)
    "applied source effect omitted receipt or removal evidence"
  require (Domain.brickStatus (fixtureBrick next) == Domain.Active)
    "source erase silently completed local work"
  expectImportError isTransition (uncurryState3 (SourceImport.applySourceEffect testTime)
    (SourceImport.sourceEffectId applied) "again" next)
  where
    isTransition (SourceImport.InvalidSourceEffectTransition _) = True
    isTransition _ = False

effectFailureProbe :: PlanProbe
effectFailureProbe _ = do
  approved <- approvedEffectFixture
  effect <- onlyEffect approved
  (failed, next) <- mapImport (uncurryState3 SourceImport.failSourceEffect
    (SourceImport.sourceEffectId effect) "HTTP 503" approved)
  require (SourceImport.sourceEffectStatus failed == SourceImport.EffectFailed
      && SourceImport.sourceEffectFailure failed == Just "HTTP 503")
    "approved effect failure was not retained"
  expectImportError isTransition (uncurryState3 SourceImport.failSourceEffect
    (SourceImport.sourceEffectId failed) "again" next)
  where
    isTransition (SourceImport.InvalidSourceEffectTransition _) = True
    isTransition _ = False

cutoverProbe :: PlanProbe
cutoverProbe _ = do
  applied <- appliedEffectFixture
  let run = fixtureRun applied
      profileId = SourceImport.importRunProfile run
  (cutover, material, imports) <- mapImport (SourceImport.cutOverImport testTime
    (SourceImport.importRunId run) "sha256:cutover" (fixtureStanding applied)
    (fixtureMaterial applied) (fixtureImports applied))
  profile <- lookupProfile profileId imports
  require (SourceImport.importRunStatus cutover == SourceImport.ImportCutOver
      && SourceImport.importRunReceiptHash cutover == Just "sha256:cutover"
      && SourceImport.importProfileStatus profile == SourceImport.ImportProfileRetired
      && all Material.rawOriginHistoricalOnly
        (Map.elems (Material.materialOrigins material)))
    "verified migration cutover omitted receipt or retirement"
  sync <- verifiedSyncFixture
  expectCutoverFailure sync
  planned <- plannedRootFixture SourceImport.Migrate False
  expectCutoverFailure planned
  unresolved <- failedEffectFixture
  expectImportError (== SourceImport.ImportCleanupUnresolved)
    (SourceImport.cutOverImport testTime
      (SourceImport.importRunId (fixtureRun unresolved)) "too-early"
      (fixtureStanding unresolved) (fixtureMaterial unresolved)
      (fixtureImports unresolved))
  unreviewed <- unreviewedVerifiedState
  expectCutoverFailure unreviewed

containerEffectProbe :: PlanProbe
containerEffectProbe _ = do
  applied <- appliedEffectFixture
  (effect, _) <- mapImport (SourceImport.proposeEmptyContainerDeletion testTime
    (SourceImport.importRunId (fixtureRun applied)) "Delete empty list inbox"
    (fixtureStanding applied) (fixtureMaterial applied) (fixtureImports applied))
  require (SourceImport.sourceEffectKind effect == SourceImport.EraseContainer
      && SourceImport.sourceEffectRecord effect == Nothing
      && SourceImport.sourceEffectStatus effect == SourceImport.EffectProposed)
    "container deletion was not separately previewed"
  failed <- failedEffectFixture
  expectContainerFailure failed
  planned <- plannedRootFixture SourceImport.Migrate True
  expectContainerFailure planned
  let profile = fixtureProfile applied
      adapter = (SourceImport.importProfileAdapter profile)
        {Integration.packComponentCapabilities = ["effect:erase-object"]}
      changed = profile {SourceImport.importProfileAdapter = adapter}
      imports = (fixtureImports applied)
        {SourceImport.sourceImportProfiles = Map.insert
          (SourceImport.importProfileId profile) changed
          (SourceImport.sourceImportProfiles (fixtureImports applied))}
  expectContainerFailure applied {fixtureImports = imports}

runLifecycleProbe :: PlanProbe
runLifecycleProbe _ = do
  -- planned -> running and running -> captured
  started <- plannedRootFixture SourceImport.Synchronize False >>= startFixture
  captured <- completeCapture started
  require (SourceImport.importRunStatus (fixtureRun captured) == SourceImport.ImportCaptured)
    "running -> captured edge is unreachable"
  -- planned/running/verified -> failed
  mapM_ assertFailEdge =<< sequence
    [plannedRootFixture SourceImport.Synchronize False,
     plannedRootFixture SourceImport.Synchronize False >>= startFixture,
     verifiedSyncFixture]
  -- captured -> verified and captured -> failed
  verified <- capturedRootFixture >>= completeCapture >>= verifyFixture
  require (SourceImport.importRunStatus (fixtureRun verified)
      == SourceImport.ImportVerifiedStatus) "captured -> verified edge is unreachable"
  mismatch <- capturedRootFixture >>= completeCapture >>= verifyMismatchFixture
  require (SourceImport.importRunStatus (fixtureRun mismatch) == SourceImport.ImportFailed)
    "captured -> failed edge is unreachable"
  -- verified -> completed and cut_over
  synchronized <- verifiedSyncFixture >>= completeSyncFixture
  require (SourceImport.importRunStatus (fixtureRun synchronized)
      == SourceImport.ImportCompleted) "verified -> completed edge is unreachable"
  migrated <- verifiedMigrationNoCleanupFixture >>= cutoverFixture
  require (SourceImport.importRunStatus (fixtureRun migrated)
      == SourceImport.ImportCutOver) "verified -> cut_over edge is unreachable"
  mapM_ assertTerminal [synchronized, migrated, mismatch]
  where
    assertFailEdge fixture = do
      (failed, _) <- mapImport (SourceImport.failImportRun testTime
        (SourceImport.importRunId (fixtureRun fixture)) (fixtureStanding fixture)
        (fixtureMaterial fixture) (fixtureImports fixture))
      require (SourceImport.importRunStatus failed == SourceImport.ImportFailed)
        "declared run failure edge is unreachable"
    assertTerminal fixture = expectImportError isRunTransition
      (SourceImport.startImport (SourceImport.importRunId (fixtureRun fixture))
        (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture))
    isRunTransition (SourceImport.InvalidImportRunTransition _) = True
    isRunTransition _ = False

effectLifecycleProbe :: PlanProbe
effectLifecycleProbe _ = do
  proposed <- migrationFixture
  effect <- onlyEffect proposed
  approvedPair <- mapImport (uncurryState2 (SourceImport.approveSourceEffect testTime)
    (SourceImport.sourceEffectId effect) proposed)
  let (approved, approvedFixture) = approvedPair
  require (SourceImport.sourceEffectStatus approved == SourceImport.EffectApproved)
    "proposed -> approved edge failed"
  appliedPair <- mapImport (uncurryState3 (SourceImport.applySourceEffect testTime)
    (SourceImport.sourceEffectId approved) "receipt" approvedFixture)
  let (applied, appliedFixture) = appliedPair
  require (SourceImport.sourceEffectStatus applied == SourceImport.EffectApplied)
    "approved -> applied edge failed"
  failedFixture <- approvedEffectFixture >>= \fixture -> do
    item <- onlyEffect fixture
    (failed, changed) <- mapImport (uncurryState3 SourceImport.failSourceEffect
      (SourceImport.sourceEffectId item) "failure" fixture)
    require (SourceImport.sourceEffectStatus failed == SourceImport.EffectFailed)
      "approved -> failed edge failed"
    pure changed
  failed <- onlyEffect failedFixture
  (retried, _) <- mapImport (uncurryState2 SourceImport.retrySourceEffect
    (SourceImport.sourceEffectId failed) failedFixture)
  require (SourceImport.sourceEffectStatus retried == SourceImport.EffectApproved)
    "failed -> approved edge failed"
  declinedProposed <- mapImport (uncurryState2 SourceImport.declineSourceEffect
    (SourceImport.sourceEffectId effect) proposed)
  declinedFailed <- mapImport (uncurryState2 SourceImport.declineSourceEffect
    (SourceImport.sourceEffectId failed) failedFixture)
  mapM_ (\(terminal, fixture) -> do
      require (SourceImport.sourceEffectStatus terminal == SourceImport.EffectDeclined)
        "decline edge failed"
      expectImportError isTransition (uncurryState2 SourceImport.retrySourceEffect
        (SourceImport.sourceEffectId terminal) fixture))
    [declinedProposed, declinedFailed]
  expectImportError isTransition (uncurryState2 SourceImport.retrySourceEffect
    (SourceImport.sourceEffectId applied) appliedFixture)
  where
    isTransition (SourceImport.InvalidSourceEffectTransition _) = True
    isTransition _ = False

externalIdentityProbe :: PlanProbe
externalIdentityProbe _ = do
  first <- capturedRootFixture
  let identity = SourceImport.externalRecordId (fixtureRecord first)
  refreshed <- captureCandidate sampleCandidate
    {SourceImport.importCandidateRevision = Just "2"} first
  require (SourceImport.externalRecordId (fixtureRecord refreshed) == identity
      && Map.size (SourceImport.sourceImportRecords (fixtureImports refreshed)) == 1)
    "same profile/external tuple did not preserve stable identity"
  (secondProfile, withSecondProfile) <- createProfileFrom
    (fixtureImports refreshed) SourceImport.AdoptBrick Nothing Nothing Nothing True refreshed
  (planned, withSecondRun) <- planRunFrom withSecondProfile
    SourceImport.Synchronize False refreshed {fixtureProfile = secondProfile}
  (running, ready) <- mapImport (SourceImport.startImport
    (SourceImport.importRunId planned) (fixtureStanding refreshed)
    (fixtureMaterial refreshed) withSecondRun)
  second <- captureCandidate sampleCandidate refreshed
    { fixtureProfile = secondProfile
    , fixtureRun = running
    , fixtureImports = ready
    }
  require (SourceImport.externalRecordId (fixtureRecord second) /= identity
      && Map.size (SourceImport.sourceImportRecords (fixtureImports second)) == 2)
    "external identity leaked across profiles"

workAdoptionInvariantProbe :: PlanProbe
workAdoptionInvariantProbe _ = do
  root <- capturedRootFixture
  require (isJust (SourceImport.externalRecordBrick (fixtureRecord root))
      && SourceImport.externalRecordEntry (fixtureRecord root) == Nothing)
    "Brick adoption also created a ListEntry adoption"
  base <- sampleBase
  entry <- runningFixtureWithBase base SourceImport.AdoptListEntry Nothing
    (Just (Domain.brickId (fixtureOwner base))) Nothing True
    >>= captureCandidate sampleCandidate
  require (SourceImport.externalRecordBrick (fixtureRecord entry) == Nothing
      && isJust (SourceImport.externalRecordEntry (fixtureRecord entry)))
    "ListEntry adoption also created a Brick adoption"
  mapImport (SourceImport.validateSourceImportState (fixtureStanding entry)
    (fixtureMaterial entry) (fixtureImports entry))

canonicalBindingsProbe :: PlanProbe
canonicalBindingsProbe _ = do
  base <- sampleBase
  let priority = standingPriority (fixtureStanding base)
  root <- maybe (Left "canonical root priority scope is missing") Right
    (findRoot (Map.elems (Priority.priorityStateScopes priority)))
  require (Priority.priorityScopeParent root == Nothing)
    "root priority binding has a parent"
  require (Domain.behaviorId Domain.standardV1 == "core/standard")
    "automatic adoption does not use the canonical standard behavior"
  where
    findRoot [] = Nothing
    findRoot (scope : rest)
      | Priority.priorityScopeParent scope == Nothing = Just scope
      | otherwise = findRoot rest

------------------------------------------------------------
-- Pure fixture builders
------------------------------------------------------------

data Fixture = Fixture
  { fixtureStanding :: Standing.StandingState
  , fixtureMaterial :: Material.MaterialState
  , fixtureImports :: SourceImport.SourceImportState
  , fixtureProfile :: SourceImport.ImportProfile
  , fixtureRun :: SourceImport.ImportRun
  , fixtureRecord :: SourceImport.ExternalRecord
  , fixtureMaybeBrick :: Maybe Domain.Brick
  , fixtureMaybeEntry :: Maybe Domain.ListEntry
  , fixtureParent :: Domain.Brick
  , fixtureOwner :: Domain.Brick
  , fixtureShelf :: Material.RawShelfId
  }
  deriving stock (Eq, Show)

emptyFixture :: Fixture
emptyFixture = Fixture Standing.emptyStandingState Material.emptyMaterialState
  SourceImport.emptySourceImportState placeholderProfile placeholderRun
  placeholderRecord Nothing Nothing placeholderBrick placeholderBrick sampleShelfId

placeholderProfile :: SourceImport.ImportProfile
placeholderProfile = SourceImport.ImportProfile "missing" 1 "missing"
  SourceImport.microsoftTodoAdapterV1 "missing" "missing" SourceImport.PreserveRaw
  Nothing Nothing Nothing False SourceImport.ImportProfileActive testTime

placeholderRun :: SourceImport.ImportRun
placeholderRun = SourceImport.ImportRun "missing" "missing" SourceImport.Synchronize
  SourceImport.ImportPlanned False testTime Nothing Nothing 0 0 0 Nothing

placeholderRecord :: SourceImport.ExternalRecord
placeholderRecord = SourceImport.ExternalRecord "missing" "missing" "provider" "account"
  "external" Nothing (Material.RawId "missing") Nothing Nothing Material.PresenceUnknown
  Material.WorkUnknown Nothing testTime

placeholderBrick :: Domain.Brick
placeholderBrick = Domain.Brick (Domain.BrickId "missing") (Domain.EntityRevision 1)
  "Missing" Nothing Domain.Core Nothing 0 Domain.Active Nothing Nothing Domain.Idle
  Domain.standardV1 Nothing Domain.Unknown Nothing Nothing Nothing Nothing Nothing
  Nothing Nothing 0 Domain.NotApplicable testTime testTime Nothing Nothing

sampleBase :: Either Text Fixture
sampleBase = do
  parentTitle <- mapDomain (Domain.mkCanonicalText "Import destination" Nothing Domain.Human)
  (parent, _, standing1) <- mapStanding (Standing.createStandingBrick
    (Domain.ordinaryBrickDraft parentTitle Domain.standardV1 testTime)
    "parent-evidence" testTime Standing.emptyStandingState)
  ownerTitle <- mapDomain (Domain.mkCanonicalText "Imported checklist" Nothing Domain.Human)
  (owner, _, standing2) <- mapStanding (Standing.createStandingBrick
    (Domain.ordinaryBrickDraft ownerTitle Domain.finiteChecklistV1 testTime)
    "owner-evidence" testTime standing1)
  (shelf, material) <- mapMaterial (Material.createRawShelf "imports" testTime
    Material.emptyMaterialState)
  pure emptyFixture
    { fixtureStanding = standing2
    , fixtureMaterial = material
    , fixtureParent = parent
    , fixtureOwner = owner
    , fixtureShelf = Material.rawShelfId shelf
    }

profileFixture :: SourceImport.ImportRoute -> Maybe Domain.BrickId ->
  Maybe Domain.BrickId -> Maybe Material.RawShelfId -> Bool -> Either Text Fixture
profileFixture route parent owner shelf automatic = do
  base <- sampleBase
  (profile, imports) <- createProfileFrom (fixtureImports base) route parent owner shelf
    automatic base
  pure base {fixtureProfile = profile, fixtureImports = imports}

createProfile :: SourceImport.ImportRoute -> Maybe Domain.BrickId ->
  Maybe Domain.BrickId -> Maybe Material.RawShelfId -> Bool -> Fixture ->
  Either Text (SourceImport.ImportProfile, SourceImport.SourceImportState)
createProfile route parent owner shelf automatic fixture = createProfileFrom
  (fixtureImports fixture) route parent owner shelf automatic fixture

createProfileFrom :: SourceImport.SourceImportState -> SourceImport.ImportRoute ->
  Maybe Domain.BrickId -> Maybe Domain.BrickId -> Maybe Material.RawShelfId -> Bool ->
  Fixture -> Either Text (SourceImport.ImportProfile, SourceImport.SourceImportState)
createProfileFrom imports route parent owner shelf automatic fixture = mapImport
  (SourceImport.createImportProfile testTime "Microsoft To Do inbox"
    SourceImport.microsoftTodoAdapterV1 "account:felipe/list:inbox"
    "structured_task" route parent owner shelf automatic
    (fixtureStanding fixture) (fixtureMaterial fixture) imports)

plannedRootFixture :: SourceImport.ImportRunMode -> Bool -> Either Text Fixture
plannedRootFixture mode erase = do
  fixture <- profileFixture SourceImport.AdoptBrick Nothing Nothing Nothing True
  (run, imports) <- planRun mode erase fixture
  pure fixture {fixtureRun = run, fixtureImports = imports}

runningFixture :: SourceImport.ImportRoute -> Maybe Domain.BrickId ->
  MaybeOwner -> Maybe Material.RawShelfId -> Bool -> Either Text Fixture
runningFixture route parent owner shelf automatic = do
  base <- sampleBase
  runningFixtureWithBase base route parent (ownerValue owner base) shelf automatic

data MaybeOwner = NoOwner | FixtureOwner

ownerValue :: MaybeOwner -> Fixture -> Maybe Domain.BrickId
ownerValue NoOwner _ = Nothing
ownerValue FixtureOwner fixture = Just (Domain.brickId (fixtureOwner fixture))

runningFixtureWithBase :: Fixture -> SourceImport.ImportRoute -> Maybe Domain.BrickId ->
  Maybe Domain.BrickId -> Maybe Material.RawShelfId -> Bool -> Either Text Fixture
runningFixtureWithBase base route parent owner shelf automatic = do
  (profile, profiled) <- createProfileFrom (fixtureImports base) route parent owner shelf
    automatic base
  (run, planned) <- planRunFrom profiled SourceImport.Synchronize False base
    {fixtureProfile = profile}
  (running, imports) <- mapImport (SourceImport.startImport
    (SourceImport.importRunId run) (fixtureStanding base) (fixtureMaterial base) planned)
  pure base {fixtureProfile = profile, fixtureRun = running, fixtureImports = imports}

capturedRootFixture :: Either Text Fixture
capturedRootFixture = runningFixture SourceImport.AdoptBrick Nothing
  NoOwner Nothing True >>= captureCandidate sampleCandidate

planRun :: SourceImport.ImportRunMode -> Bool -> Fixture ->
  Either Text (SourceImport.ImportRun, SourceImport.SourceImportState)
planRun mode erase fixture = planRunFrom (fixtureImports fixture) mode erase fixture

planRunFrom :: SourceImport.SourceImportState -> SourceImport.ImportRunMode -> Bool ->
  Fixture -> Either Text (SourceImport.ImportRun, SourceImport.SourceImportState)
planRunFrom imports mode erase fixture = mapImport (SourceImport.planImport testTime
  (SourceImport.importProfileId (fixtureProfile fixture)) mode erase
  (fixtureStanding fixture) (fixtureMaterial fixture) imports)

planRunResult :: SourceImport.ImportRunMode -> Bool -> Fixture ->
  Either SourceImport.ImportError (SourceImport.ImportRun, SourceImport.SourceImportState)
planRunResult mode erase fixture = SourceImport.planImport testTime
  (SourceImport.importProfileId (fixtureProfile fixture)) mode erase
  (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture)

startFixture :: Fixture -> Either Text Fixture
startFixture fixture = do
  (run, imports) <- mapImport (SourceImport.startImport
    (SourceImport.importRunId (fixtureRun fixture)) (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture))
  pure fixture {fixtureRun = run, fixtureImports = imports}

captureCandidate :: SourceImport.ImportCandidate -> Fixture -> Either Text Fixture
captureCandidate candidate fixture = do
  (record, brick, entry, standing, material, imports) <- mapImport
    (captureResult candidate fixture)
  run <- lookupRun (SourceImport.importRunId (fixtureRun fixture)) imports
  pure fixture
    { fixtureStanding = standing
    , fixtureMaterial = material
    , fixtureImports = imports
    , fixtureRun = run
    , fixtureRecord = record
    , fixtureMaybeBrick = brick
    , fixtureMaybeEntry = entry
    }

captureResult :: SourceImport.ImportCandidate -> Fixture -> Either SourceImport.ImportError
  (SourceImport.ExternalRecord, Maybe Domain.Brick, Maybe Domain.ListEntry,
   Standing.StandingState, Material.MaterialState, SourceImport.SourceImportState)
captureResult candidate fixture = SourceImport.acceptImportCandidate testTime
  (SourceImport.importRunId (fixtureRun fixture)) candidate
  (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture)

completeCapture :: Fixture -> Either Text Fixture
completeCapture fixture = do
  (run, imports) <- mapImport (SourceImport.finishImportCapture
    (SourceImport.importRunId (fixtureRun fixture)) Nothing (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture))
  pure fixture {fixtureRun = run, fixtureImports = imports}

verifyFixture :: Fixture -> Either Text Fixture
verifyFixture fixture = do
  let run = fixtureRun fixture
  (verified, imports) <- mapImport (SourceImport.verifyImport testTime
    (SourceImport.importRunId run) (SourceImport.importRunCapturedCount run) 0
    (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture))
  pure fixture {fixtureRun = verified, fixtureImports = imports}

verifyMismatchFixture :: Fixture -> Either Text Fixture
verifyMismatchFixture fixture = do
  let run = fixtureRun fixture
  (failed, imports) <- mapImport (SourceImport.verifyImport testTime
    (SourceImport.importRunId run) 0 0 (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture))
  pure fixture {fixtureRun = failed, fixtureImports = imports}

verifiedSyncFixture :: Either Text Fixture
verifiedSyncFixture = capturedRootFixture >>= completeCapture >>= verifyFixture

completeSyncFixture :: Fixture -> Either Text Fixture
completeSyncFixture fixture = do
  (run, imports) <- mapImport (SourceImport.completeSynchronization testTime
    (SourceImport.importRunId (fixtureRun fixture)) "sha256:sync"
    (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture))
  pure fixture {fixtureRun = run, fixtureImports = imports}

verifiedMigrationNoCleanupFixture :: Either Text Fixture
verifiedMigrationNoCleanupFixture = do
  captured <- capturedRootFixture
  (run, planned) <- mapImport (SourceImport.planImport testTime
    (SourceImport.importProfileId (fixtureProfile captured)) SourceImport.Migrate False
    (fixtureStanding captured) (fixtureMaterial captured) (fixtureImports captured))
  (verified, imports) <- mapImport (SourceImport.prepareVerifiedMigration testTime
    (SourceImport.importRunId run) (fixtureStanding captured) (fixtureMaterial captured)
    planned)
  pure captured {fixtureRun = verified, fixtureImports = imports}

multiRecordVerifiedMigrationFixture :: Either Text Fixture
multiRecordVerifiedMigrationFixture = do
  first <- capturedRootFixture
  second <- captureCandidate sampleCandidate
    { SourceImport.importCandidateExternalId = "task-43"
    , SourceImport.importCandidateContentHash = "sha256:task-43-v1"
    } first
  third <- captureCandidate sampleCandidate
    { SourceImport.importCandidateExternalId = "task-44"
    , SourceImport.importCandidateContentHash = "sha256:task-44-v1"
    } second
  (run, planned) <- mapImport (SourceImport.planImport testTime
    (SourceImport.importProfileId (fixtureProfile third)) SourceImport.Migrate True
    (fixtureStanding third) (fixtureMaterial third) (fixtureImports third))
  (verified, prepared) <- mapImport (SourceImport.prepareVerifiedMigration testTime
    (SourceImport.importRunId run) (fixtureStanding third) (fixtureMaterial third)
    planned)
  pure third {fixtureRun = verified, fixtureImports = prepared}

latestSnapshotFor :: SourceImport.ExternalRecord -> Material.MaterialState ->
  Either Text Material.RawSnapshot
latestSnapshotFor record material = case
    [ snapshot
    | snapshot <- Map.elems (Material.materialSnapshots material)
    , Material.rawSnapshotRaw snapshot == SourceImport.externalRecordRaw record
    ] of
  [snapshot] -> Right snapshot
  _ -> Left "cleanup record does not have exactly one snapshot"

migrationFixture :: Either Text Fixture
migrationFixture = do
  captured <- capturedRootFixture
  (run, planned) <- mapImport (SourceImport.planImport testTime
    (SourceImport.importProfileId (fixtureProfile captured)) SourceImport.Migrate True
    (fixtureStanding captured) (fixtureMaterial captured) (fixtureImports captured))
  (verified, prepared) <- mapImport (SourceImport.prepareVerifiedMigration testTime
    (SourceImport.importRunId run) (fixtureStanding captured) (fixtureMaterial captured)
    planned)
  (effects, imports) <- mapImport (SourceImport.planEraseAfterImport testTime
    (SourceImport.importRunId verified) (fixtureStanding captured)
    (fixtureMaterial captured) prepared)
  case effects of
    [_] -> Right ()
    _ -> Left "migration fixture did not produce exactly one item effect"
  pure captured {fixtureRun = verified, fixtureImports = imports}

approvedEffectFixture :: Either Text Fixture
approvedEffectFixture = do
  fixture <- migrationFixture
  effect <- onlyEffect fixture
  (_, next) <- mapImport (uncurryState2
    (SourceImport.approveSourceEffect testTime)
    (SourceImport.sourceEffectId effect) fixture)
  pure next

failedEffectFixture :: Either Text Fixture
failedEffectFixture = do
  fixture <- approvedEffectFixture
  effect <- onlyEffect fixture
  (_, next) <- mapImport (uncurryState3 SourceImport.failSourceEffect
    (SourceImport.sourceEffectId effect) "HTTP 503" fixture)
  pure next

appliedEffectFixture :: Either Text Fixture
appliedEffectFixture = do
  fixture <- approvedEffectFixture
  effect <- onlyEffect fixture
  (_, next) <- mapImport (uncurryState3 (SourceImport.applySourceEffect testTime)
    (SourceImport.sourceEffectId effect) "provider:receipt" fixture)
  pure next

cutoverFixture :: Fixture -> Either Text Fixture
cutoverFixture fixture = do
  (run, material, imports) <- mapImport (SourceImport.cutOverImport testTime
    (SourceImport.importRunId (fixtureRun fixture)) "sha256:cutover"
    (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture))
  pure fixture {fixtureRun = run, fixtureMaterial = material, fixtureImports = imports}

unreviewedMigrationFixture :: Either Text Fixture
unreviewedMigrationFixture = do
  raw <- runningFixture SourceImport.PreserveRaw Nothing NoOwner Nothing True
    >>= captureCandidate sampleCandidate >>= completeCapture
  let prior = fixtureRun raw
  (run, imports) <- mapImport (SourceImport.planImport testTime
    (SourceImport.importRunProfile prior) SourceImport.Migrate False
    (fixtureStanding raw) (fixtureMaterial raw) (fixtureImports raw))
  (running, started) <- mapImport (SourceImport.startImport (SourceImport.importRunId run)
    (fixtureStanding raw) (fixtureMaterial raw) imports)
  let counted = running {SourceImport.importRunCapturedCount = 1}
      withCount = started {SourceImport.sourceImportRuns = Map.insert
        (SourceImport.importRunId counted) counted (SourceImport.sourceImportRuns started)}
  (captured, finished) <- mapImport (SourceImport.finishImportCapture
    (SourceImport.importRunId counted) Nothing (fixtureStanding raw)
    (fixtureMaterial raw) withCount)
  pure raw {fixtureRun = captured, fixtureImports = finished}

unreviewedVerifiedState :: Either Text Fixture
unreviewedVerifiedState = do
  fixture <- unreviewedMigrationFixture
  let run = fixtureRun fixture
      rawId = SourceImport.externalRecordRaw (fixtureRecord fixture)
      raw = (Material.materialRaws (fixtureMaterial fixture)) Map.! rawId
      reviewedRaw = raw {Material.rawReviewState = Material.RawReviewedState}
      reviewedMaterial = (fixtureMaterial fixture)
        {Material.materialRaws = Map.insert rawId reviewedRaw
          (Material.materialRaws (fixtureMaterial fixture))}
  (verified, imports) <- mapImport (SourceImport.verifyImport testTime
    (SourceImport.importRunId run) (SourceImport.importRunCapturedCount run) 0
    (fixtureStanding fixture) reviewedMaterial (fixtureImports fixture))
  -- Remove the disposition again after reaching the status to exercise the
  -- independent cutover review precondition.
  let unreviewedMaterial = reviewedMaterial
        {Material.materialRaws = Map.insert rawId raw
          (Material.materialRaws reviewedMaterial)}
  pure fixture {fixtureRun = verified, fixtureImports = imports,
    fixtureMaterial = unreviewedMaterial}

onlyEffect :: Fixture -> Either Text SourceImport.SourceEffect
onlyEffect fixture = case Map.elems
    (SourceImport.sourceImportEffects (fixtureImports fixture)) of
  [effect] -> Right effect
  effects -> Left ("expected one source effect, got " <> Text.pack (show (length effects)))

fixtureProfileValue :: Fixture -> Either Text SourceImport.ImportProfile
fixtureProfileValue fixture = lookupProfile
  (SourceImport.importRunProfile (fixtureRun fixture)) (fixtureImports fixture)

fixtureRecordValue :: Fixture -> Either Text SourceImport.ExternalRecord
fixtureRecordValue fixture = case Map.elems
    (SourceImport.sourceImportRecords (fixtureImports fixture)) of
  [record] -> Right record
  _ -> Left "fixture does not contain exactly one ExternalRecord"

fixtureRunValue :: Fixture -> Either Text SourceImport.ImportRun
fixtureRunValue fixture = lookupRun (SourceImport.importRunId (fixtureRun fixture))
  (fixtureImports fixture)

fixtureBrick :: Fixture -> Domain.Brick
fixtureBrick fixture = case fixtureMaybeBrick fixture of
  Just brick -> brick
  Nothing -> placeholderBrick

assertPreserved :: Fixture -> Either Text ()
assertPreserved fixture = do
  let record = fixtureRecord fixture
      raw = (Material.materialRaws (fixtureMaterial fixture)) Map.!
        SourceImport.externalRecordRaw record
  require (SourceImport.externalRecordBrick record == Nothing
      && SourceImport.externalRecordEntry record == Nothing)
    "preserve route created work adoption"
  require (Material.rawReviewState raw == Material.RawPending
      && not (null [snapshot | snapshot <- Map.elems
        (Material.materialSnapshots (fixtureMaterial fixture)),
        Material.rawSnapshotRaw snapshot == Material.rawId raw]))
    "preserve route omitted pending Raw evidence"

assertBrickAdoption :: Maybe Domain.BrickId -> Fixture -> Either Text ()
assertBrickAdoption expectedParent fixture = do
  brick <- maybe (Left "automatic adoption did not create Brick") Right
    (fixtureMaybeBrick fixture)
  let record = fixtureRecord fixture
      material = fixtureMaterial fixture
      priority = standingPriority (fixtureStanding fixture)
      memberships = [scope | scope <- Map.elems (Priority.priorityStateScopes priority),
        Domain.brickId brick `elem` Priority.priorityScopeMembers scope]
      insertions = [item | item <- Map.elems (Priority.priorityStateInsertions priority),
        Priority.priorityInsertionBrick item == Domain.brickId brick]
      raw = (Material.materialRaws material) Map.! SourceImport.externalRecordRaw record
  require (Domain.brickParent brick == expectedParent
      && Domain.behaviorId (Domain.brickBehavior brick) == "core/standard")
    "adopted Brick used wrong parent or behavior"
  require (length memberships == 1 && case insertions of
      [item] -> Priority.priorityInsertionStatus item == Priority.InsertionDeferred
      _ -> False)
    "adopted Brick is not provisionally positioned exactly once"
  require (Material.rawReviewState raw == Material.RawReviewedState
      && any ((== Just (Domain.brickId brick)) . Material.rawLinkOwnerBrick)
        (Map.elems (Material.materialLinks material)))
    "automatic adoption omitted reviewed Raw source evidence"

expectCreateFailure :: Integration.PackComponent -> SourceImport.ImportRoute ->
  Maybe Domain.BrickId -> Maybe Domain.BrickId -> Maybe Material.RawShelfId ->
  Fixture -> Either Text ()
expectCreateFailure adapter route parent owner shelf fixture = expectImportError
  (const True) (SourceImport.createImportProfile testTime "invalid" adapter "scope"
    "structured_task" route parent owner shelf True (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture))

expectPlanCleanupFailure :: Fixture -> Either Text ()
expectPlanCleanupFailure fixture = expectImportError (const True)
  (SourceImport.planEraseAfterImport testTime
    (SourceImport.importRunId (fixtureRun fixture)) (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture))

expectCutoverFailure :: Fixture -> Either Text ()
expectCutoverFailure fixture = expectImportError (const True)
  (SourceImport.cutOverImport testTime
    (SourceImport.importRunId (fixtureRun fixture)) "receipt"
    (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture))

expectContainerFailure :: Fixture -> Either Text ()
expectContainerFailure fixture = expectImportError (const True)
  (SourceImport.proposeEmptyContainerDeletion testTime
    (SourceImport.importRunId (fixtureRun fixture)) "preview"
    (fixtureStanding fixture) (fixtureMaterial fixture) (fixtureImports fixture))

uncurryState2 ::
  (Text -> Standing.StandingState -> Material.MaterialState ->
    SourceImport.SourceImportState -> Either SourceImport.ImportError
      (value, SourceImport.SourceImportState)) ->
  Text -> Fixture -> Either SourceImport.ImportError (value, Fixture)
uncurryState2 operation identifier fixture = do
  (value, imports) <- operation identifier (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture)
  pure (value, fixture {fixtureImports = imports})

uncurryState3 ::
  (Text -> Text -> Standing.StandingState -> Material.MaterialState ->
    SourceImport.SourceImportState -> Either SourceImport.ImportError
      (value, SourceImport.SourceImportState)) ->
  Text -> Text -> Fixture -> Either SourceImport.ImportError (value, Fixture)
uncurryState3 operation identifier detail fixture = do
  (value, imports) <- operation identifier detail (fixtureStanding fixture)
    (fixtureMaterial fixture) (fixtureImports fixture)
  let record = case Map.elems (SourceImport.sourceImportRecords imports) of
        [item] -> item
        _ -> fixtureRecord fixture
  pure (value, fixture {fixtureImports = imports, fixtureRecord = record})

lookupProfile :: Text -> SourceImport.SourceImportState -> Either Text SourceImport.ImportProfile
lookupProfile identifier imports = maybe (Left "fixture profile is missing") Right
  (Map.lookup identifier (SourceImport.sourceImportProfiles imports))

lookupRun :: Text -> SourceImport.SourceImportState -> Either Text SourceImport.ImportRun
lookupRun identifier imports = maybe (Left "fixture run is missing") Right
  (Map.lookup identifier (SourceImport.sourceImportRuns imports))

standingDomain :: Standing.StandingState -> Domain.DomainState
standingDomain = Execution.executionStateDomain
  . Coordination.coordinationStateExecution . Standing.standingStateCoordination

standingPriority :: Standing.StandingState -> Priority.PriorityState
standingPriority = Execution.executionStatePriority
  . Coordination.coordinationStateExecution . Standing.standingStateCoordination

sampleCandidate :: SourceImport.ImportCandidate
sampleCandidate = SourceImport.ImportCandidate
  { SourceImport.importCandidateProvider = "microsoft-todo"
  , SourceImport.importCandidateAccount = "felipe"
  , SourceImport.importCandidateExternalId = "task-42"
  , SourceImport.importCandidateContainerId = Just "inbox"
  , SourceImport.importCandidateKind = "structured_task"
  , SourceImport.importCandidateOriginalTitle = Just "Comprar filtro"
  , SourceImport.importCandidateCanonicalEnglish = Just "Buy a water filter"
  , SourceImport.importCandidateNormalizationAuthority = Just Domain.Adapter
  , SourceImport.importCandidateBody = Just "For the kitchen"
  , SourceImport.importCandidateContentHash = "sha256:task-42-v1"
  , SourceImport.importCandidateRevision = Just "1"
  , SourceImport.importCandidatePresence = Material.Present
  , SourceImport.importCandidateWorkState = Material.WorkOpen
  }

sampleCandidateTwo :: SourceImport.ImportCandidate
sampleCandidateTwo = sampleCandidate
  { SourceImport.importCandidateExternalId = "task-43"
  , SourceImport.importCandidateContentHash = "sha256:task-43-v1"
  }

sampleBrickId :: Domain.BrickId
sampleBrickId = Domain.BrickId "sample-brick"

sampleEntryId :: Domain.ListEntryId
sampleEntryId = Domain.ListEntryId "sample-entry"

sampleShelfId :: Material.RawShelfId
sampleShelfId = Material.RawShelfId "sample-shelf"

testTime :: UTCTime
testTime = UTCTime (fromGregorian 2026 7 27) (17 * 60 * 60)

------------------------------------------------------------
-- Generic assertions
------------------------------------------------------------

roundTripAndFields :: (Eq value, ToJSON value, FromJSON value) =>
  value -> [Text] -> Either Text ()
roundTripAndFields value expected = do
  fields (toJSON value) expected
  case fromJSON (toJSON value) of
    Success decoded -> require (decoded == value) "typed value failed JSON equality"
    Error problem -> Left (Text.pack problem)

fields :: Value -> [Text] -> Either Text ()
fields value expected = do
  objectValue <- asObject value
  require (all (\field -> KeyMap.member (Key.fromText field) objectValue) expected)
    "typed projection omits declared fields"

optionalPair :: Value -> Value -> Text -> Either Text ()
optionalPair absent present name = do
  absentObject <- asObject absent
  presentObject <- asObject present
  require (KeyMap.lookup (Key.fromText name) absentObject == Just Null)
    (name <> " does not accept null")
  require (maybe False (/= Null) (KeyMap.lookup (Key.fromText name) presentObject))
    (name <> " does not accept a non-null value")

asObject :: Value -> Either Text (KeyMap.KeyMap Value)
asObject = \case
  Object value -> Right value
  _ -> Left "expected object projection"

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

mapImport :: Either SourceImport.ImportError value -> Either Text value
mapImport = either (Left . Text.pack . show) Right

mapDomain :: Either Domain.DomainError value -> Either Text value
mapDomain = either (Left . Text.pack . show) Right

mapStanding :: Either Standing.StandingError value -> Either Text value
mapStanding = either (Left . Text.pack . show) Right

mapMaterial :: Either Material.MaterialError value -> Either Text value
mapMaterial = either (Left . Text.pack . show) Right

expectImportError :: (SourceImport.ImportError -> Bool) ->
  Either SourceImport.ImportError value -> Either Text ()
expectImportError predicate result = case result of
  Left problem | predicate problem -> Right ()
               | otherwise -> Left ("unexpected rejection: " <> Text.pack (show problem))
  Right _ -> Left "expected source-import rejection was accepted"

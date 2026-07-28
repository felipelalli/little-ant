{-# LANGUAGE DerivingStrategies #-}

-- | Semantic conformance probes for the immutable v0 archive and atomic v1
-- cutover.  Registrations are keyed only by Allium construct metadata.
module LittleAnt.V1.MigrationPlanCatalog
  ( migrationPlanProbes
  ) where

import Control.Monad (foldM, unless)
import Data.Aeson
  (FromJSON, Result (..), ToJSON (toJSON), Value (..), encode, fromJSON)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.Event (Body (..), Event (..), eventToJSON)
import LittleAnt.Ids (Id (..))
import qualified LittleAnt.Types as V0
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import qualified LittleAnt.V1.Domain as Domain
import LittleAnt.V1.Migration

migrationPlanProbes :: Map ProbeKey PlanProbe
migrationPlanProbes = Map.fromList
  ( contractRegistrations
  <> enumRegistrations
  <> entityRegistrations
  <> transitionRegistrations
  <> ruleRegistrations
  <> invariantRegistrations
  <> surfaceRegistrations
  )

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "V0ArchiveReader.inspect" readerInspectProbe
  , registration "contract_signature" "V0ArchiveReader.hash" readerHashProbe
  , registration "contract_signature" "V1CutoverWriter.stage" writerStageProbe
  , registration "contract_signature" "V1CutoverWriter.verify" writerVerifyProbe
  , registration "contract_signature" "V1CutoverWriter.activate" writerActivateProbe
  ]

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ registration "enum_comparable" "CutoverStatus" enumProbe
  , registration "enum_comparable" "MigratedEntityKind" enumProbe
  ]

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ registration "entity_fields" "V0Archive" entityProbe
  , registration "entity_fields" "V0V1IdentityMap" entityProbe
  , registration "entity_fields" "MigrationEvidence" entityProbe
  , registration "entity_optional" "MigrationEvidence.old_event_id" entityProbe
  , registration "entity_optional" "MigrationEvidence.subject_old_id" entityProbe
  , registration "entity_fields" "V1Cutover" entityProbe
  , registration "entity_optional" "V1Cutover.finished_at" entityProbe
  , registration "entity_optional" "V1Cutover.v1_log_hash" entityProbe
  , registration "entity_optional" "V1Cutover.receipt_hash" entityProbe
  , registration "entity_optional" "V1Cutover.failure" entityProbe
  ]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [ registration category "V1Cutover.status" transitionProbe
  | category <- ["transition_edge", "transition_rejected", "transition_terminal"]
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ rules "CutoverPlanned"
      ["rule_success", "rule_failure", "rule_entity_creation"] planningRuleProbe
  , rules "HistoricalArchiveVerified"
      ["rule_success", "rule_failure"] archiveVerificationProbe
  , rules "HistoricalArchiveVerificationFailed"
      ["rule_success", "rule_failure"] archiveVerificationFailureProbe
  , rules "CurrentStateProjected"
      ["rule_success", "rule_failure"] projectionRuleProbe
  , rules "MigratedIdentityMapped"
      ["rule_success", "rule_failure", "rule_entity_creation"] identityRuleProbe
  , rules "MigratedEvidenceRecorded"
      ["rule_success", "rule_failure", "rule_entity_creation"] evidenceRuleProbe
  , rules "V1ProjectionVerified"
      ["rule_success", "rule_failure"] projectionVerificationProbe
  , rules "V1ProjectionVerificationFailed"
      ["rule_success", "rule_failure"] projectionRejectionProbe
  , rules "V1CutoverCommitted"
      ["rule_success", "rule_failure"] commitRuleProbe
  ]
  where
    rules construct categories probe =
      [registration category construct probe | category <- categories]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" "OneMapEntryPerOldId" identityInvariantProbe
  , registration "invariant" "ArchiveIsImmutable" archiveInvariantProbe
  , registration "invariant" "CommittedCutoverIsVerifiable" receiptInvariantProbe
  ]

surfaceRegistrations :: [(ProbeKey, PlanProbe)]
surfaceRegistrations =
  [ registration category "MigrationDesk" migrationDeskProbe
  | category <- ["surface_actor", "surface_exposure", "surface_provides"]
  ]

registration :: Text -> Text -> PlanProbe -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "migration-v0-v1" category construct, \input -> do
    require (planProbeModule input == "migration-v0-v1")
      "migration probe received a different module"
    require (planProbeCategory input == category)
      "migration probe received a different category"
    require (planProbeSourceConstruct input == construct)
      "migration probe received a different source construct"
    probe input)

readerInspectProbe :: PlanProbe
readerInspectProbe _ = do
  inspection <- migration (inspectV0Archive sourcePath sampleArchiveBytes)
  require (archiveInspectionSourcePath inspection == sourcePath
      && archiveInspectionByteSize inspection
        == fromIntegral (LBS.length sampleArchiveBytes)
      && archiveInspectionEventCount inspection
        == fromIntegral (length sampleEvents))
    "v0 reader inspection did not report exact immutable archive metadata"
  expectError isInvalidSource (inspectV0Archive sourcePath "not-json\n")
  where
    isInvalidSource (InvalidArchiveSource _) = True
    isInvalidSource _ = False

readerHashProbe :: PlanProbe
readerHashProbe _ = do
  let first = hashV0ArchiveBytes sampleArchiveBytes
      second = hashV0ArchiveBytes sampleArchiveBytes
      changed = hashV0ArchiveBytes (sampleArchiveBytes <> " ")
  require ("sha256:" `Text.isPrefixOf` first && first == second && first /= changed)
    "v0 reader hash was not deterministic and content-sensitive"

writerStageProbe :: PlanProbe
writerStageProbe _ = do
  fixture <- projectedFixture
  staged <- fixtureStaged fixture
  let cutoverId = v1CutoverId (fixtureCutover fixture)
  plans <- migration (stagedIdentityPlans cutoverId (fixtureState fixture))
  (firstPlan, remainingPlans) <- case Map.toAscList plans of
    firstPlan : remaining -> Right (firstPlan, remaining)
    [] -> Left "writer stage has no concrete identity plans"
  partiallyMapped <- recordIdentityPlan cutoverId (fixtureState fixture) firstPlan
  partialStaged <- maybe (Left "partially mapped writer stage disappeared") Right
    (Map.lookup cutoverId (migrationStateStagedDatasets partiallyMapped))
  mapped <- foldM (recordIdentityPlan cutoverId) partiallyMapped remainingPlans
  mappedStaged <- maybe (Left "mapped writer stage disappeared") Right
    (Map.lookup cutoverId (migrationStateStagedDatasets mapped))
  replayed <- migration (replayProjectedBricks (stagedV1DatasetCleanLog staged))
  require (stagedV1DatasetMode staged == MaterializedProjection
      && not (null (stagedV1DatasetCleanLog staged))
      && all cleanRecord (stagedV1DatasetCleanLog staged)
      && stagedV1DatasetComputedLogHash staged
        == Just (hashCleanLog (stagedV1DatasetCleanLog staged))
      && not (Text.null (stagedV1DatasetContentHash staged))
      && replayed == stagedV1DatasetProjectedBricks staged
      && stagedV1DatasetInvariantsSatisfied staged
      && not (stagedV1DatasetIdentityCoverageComplete staged)
      && not (Map.null (migrationStateIdentityMaps partiallyMapped))
      && not (stagedV1DatasetIdentityCoverageComplete partialStaged)
      && stagedV1DatasetIdentityCoverageComplete mappedStaged
      && stagedV1DatasetEvidenceCoverageComplete staged)
    "v1 writer did not stage concrete clean records and derive coverage"
  where
    cleanRecord value = valueAt "record_type" value `elem`
      [Just (String "v1_entity_created"), Just (String "migration_evidence")]

writerVerifyProbe :: PlanProbe
writerVerifyProbe = projectionVerificationProbe

writerActivateProbe :: PlanProbe
writerActivateProbe = commitRuleProbe

enumProbe :: PlanProbe
enumProbe input = case planProbeSourceConstruct input of
  "CutoverStatus" -> distinctRoundTrip
    [ CutoverPlanned, ArchiveVerified, StateProjected, ProjectionVerified
    , CutoverCommitted, CutoverFailed
    ]
  "MigratedEntityKind" -> distinctRoundTrip
    [MigratedBrick, MigratedRaw, MigratedParty, MigratedListEntry]
  construct -> Left ("unsupported migration enum: " <> construct)

entityProbe :: PlanProbe
entityProbe input = do
  fixture <- committedFixture
  let archive = fixtureArchive fixture
      cutover = fixtureCutover fixture
      mappings = Map.elems (migrationStateIdentityMaps (fixtureState fixture))
      evidences = Map.elems (migrationStateEvidence (fixtureState fixture))
  mapping <- maybe (Left "migration fixture has no identity mapping") Right
    (safeHead mappings)
  evidence <- maybe (Left "migration fixture has no evidence") Right
    (safeHead evidences)
  case planProbeSourceConstruct input of
    "V0Archive" -> roundTripAndFields archive
      ["id", "source_path", "byte_size", "event_count", "sha256",
       "archived_at", "immutable", "verified"]
    "V0V1IdentityMap" -> roundTripAndFields mapping
      ["id", "archive", "old_id", "new_id", "kind", "recorded_at"]
    "MigrationEvidence" -> roundTripAndFields evidence
      ["id", "archive", "old_event_id", "subject_old_id", "semantic_kind",
       "summary", "recorded_at"]
    "MigrationEvidence.old_event_id" -> optionalEvidenceProbe True fixture
    "MigrationEvidence.subject_old_id" -> optionalEvidenceProbe False fixture
    "V1Cutover" -> roundTripAndFields cutover
      ["id", "archive", "status", "planned_at", "finished_at",
       "projected_entity_count", "mapped_identity_count",
       "retained_evidence_count", "v1_log_hash", "receipt_hash", "failure"]
    "V1Cutover.finished_at" -> cutoverOptional "finished_at" fixture
    "V1Cutover.v1_log_hash" -> cutoverOptional "v1_log_hash" fixture
    "V1Cutover.receipt_hash" -> cutoverOptional "receipt_hash" fixture
    "V1Cutover.failure" -> do
      planned <- plannedFixture
      failed <- migration (failCutover (addUTCTime 1 probeTime)
        (v1CutoverId (fixtureCutover planned)) "writer failure"
        (fixtureState planned))
      require (valueAt "failure" (toJSON (firstOfPair failed))
          == Just (String "writer failure"))
        "failed cutover did not retain a failure value"
      require (valueAt "failure" (toJSON (fixtureCutover planned)) == Just Null)
        "planned cutover did not represent absent failure as null"
    construct -> Left ("unsupported migration entity: " <> construct)

transitionProbe :: PlanProbe
transitionProbe _ = do
  planned <- plannedFixture
  let plannedId = v1CutoverId (fixtureCutover planned)
  (_, verified, archiveState) <- migration (verifyV0Archive probeTime plannedId
    (v0ArchiveSha256 (fixtureArchive planned))
    (v0ArchiveEventCount (fixtureArchive planned)) (fixtureState planned))
  require (v1CutoverStatus verified == ArchiveVerified)
    "planned -> archive_verified is unreachable"
  (projected, projectedState) <- migration (projectV0Events plannedId sampleEvents
    archiveState)
  require (v1CutoverStatus projected == StateProjected)
    "archive_verified -> state_projected is unreachable"
  mapped <- mapEveryIdentity plannedId projectedState
  verifiedProjection <- verifyFixtureState plannedId mapped
  require (v1CutoverStatus (fst verifiedProjection) == ProjectionVerified)
    "state_projected -> projection_verified is unreachable"
  (committed, _, committedState) <- migration (commitV1Cutover
    (addUTCTime 2 probeTime) plannedId "sha256:receipt" (snd verifiedProjection))
  require (v1CutoverStatus committed == CutoverCommitted)
    "projection_verified -> committed is unreachable"
  expectTransitionError (stageWriterProjection plannedId 1 1
    emptyWriterProjection committedState)
  expectTransitionError (failCutover (addUTCTime 3 probeTime) plannedId
    "terminal mutation" committedState)
  mapM_ failureEdge
    [ CutoverPlanned, ArchiveVerified, StateProjected, ProjectionVerified ]
  where
    failureEdge status = do
      fixture <- stateAt status
      let before = migrationStateActiveDataset (fixtureState fixture)
      (failed, failedState) <- migration (failCutover (addUTCTime 4 probeTime)
        (v1CutoverId (fixtureCutover fixture)) "edge failure"
        (fixtureState fixture))
      require (v1CutoverStatus failed == CutoverFailed
          && migrationStateActiveDataset failedState == before)
        "declared failure edge changed active authority"

planningRuleProbe :: PlanProbe
planningRuleProbe _ = do
  fixture <- plannedFixture
  let archive = fixtureArchive fixture
      cutover = fixtureCutover fixture
  require (v0ArchiveImmutable archive && not (v0ArchiveVerified archive)
      && v1CutoverStatus cutover == CutoverPlanned
      && v1CutoverProjectedEntityCount cutover == 0
      && v1CutoverMappedIdentityCount cutover == 0
      && migrationStateActiveDataset (fixtureState fixture)
        == migrationStateActiveDataset emptyMigrationState)
    "cutover planning changed active authority or omitted ensured fields"
  expectError isInvalidSize (planV0V1Cutover probeTime sourcePath targetPath
    0 1 "sha256:x" emptyMigrationState)
  expectError isInvalidCount (planV0V1Cutover probeTime sourcePath targetPath
    1 0 "sha256:x" emptyMigrationState)
  where
    isInvalidSize (InvalidArchiveSize _) = True
    isInvalidSize _ = False
    isInvalidCount (InvalidArchiveEventCount _) = True
    isInvalidCount _ = False

archiveVerificationProbe :: PlanProbe
archiveVerificationProbe _ = do
  fixture <- archivedFixture
  require (v0ArchiveVerified (fixtureArchive fixture)
      && v1CutoverStatus (fixtureCutover fixture) == ArchiveVerified)
    "matching archive verification did not advance both archive and cutover"
  expectTransitionError (verifyV0Archive probeTime
    (v1CutoverId (fixtureCutover fixture))
    (v0ArchiveSha256 (fixtureArchive fixture))
    (v0ArchiveEventCount (fixtureArchive fixture)) (fixtureState fixture))

archiveVerificationFailureProbe :: PlanProbe
archiveVerificationFailureProbe _ = do
  mapM_ mismatch [True, False]
  archived <- archivedFixture
  expectTransitionError (verifyV0Archive probeTime
    (v1CutoverId (fixtureCutover archived)) "sha256:wrong"
    (v0ArchiveEventCount (fixtureArchive archived)) (fixtureState archived))
  where
    mismatch wrongHash = do
      fixture <- plannedFixture
      let archive = fixtureArchive fixture
          hashValue = if wrongHash then "sha256:wrong" else v0ArchiveSha256 archive
          countValue = if wrongHash then v0ArchiveEventCount archive
            else v0ArchiveEventCount archive + 1
          before = migrationStateActiveDataset (fixtureState fixture)
      (_, failed, state) <- migration (verifyV0Archive probeTime
        (v1CutoverId (fixtureCutover fixture)) hashValue countValue
        (fixtureState fixture))
      require (v1CutoverStatus failed == CutoverFailed
          && v1CutoverFailure failed == Just "v0_archive_verification_failed"
          && Map.null (migrationStateStagedDatasets state)
          && migrationStateActiveDataset state == before)
        "archive mismatch created projection state or changed active authority"

projectionRuleProbe :: PlanProbe
projectionRuleProbe _ = do
  fixture <- projectedFixture
  staged <- fixtureStaged fixture
  let bricks = Map.elems (stagedV1DatasetProjectedBricks staged)
      stage title = maybe (Left ("missing projected stage: " <> title)) Right
        (safeHead [brick | brick <- bricks, projectedBrickTitle brick == title])
  seed <- stage "Seed"
  committed <- stage "Committed"
  ready <- stage "Ready"
  wip <- stage "WIP"
  done <- stage "Done"
  dropped <- stage "Dropped"
  superseded <- stage "Superseded"
  require (all ((== "active") . projectedBrickStatus) [seed, committed, ready, wip]
      && all ((== 1) . projectedBrickPriorityMembershipCount)
        [seed, committed, ready, wip]
      && projectedBrickWorkState wip == "wip"
      && map projectedBrickStatus [done, dropped, superseded]
        == ["done", "dropped", "superseded"]
      && all ((== 0) . projectedBrickPriorityMembershipCount)
        [done, dropped, superseded]
      && all ((== Domain.behaviorId Domain.standardV1)
          . projectedBrickBehavior) bricks
      && validOpaqueIds bricks)
    "legacy stages were not semantically projected to canonical v1 axes"
  archived <- archivedFixture
  let cutoverId = v1CutoverId (fixtureCutover archived)
  expectError (== ProjectionCountInvalid)
    (stageWriterProjection cutoverId (-1) 0 emptyWriterProjection
      (fixtureState archived))
  expectError (== ProjectionCountInvalid)
    (stageWriterProjection cutoverId 0 (-1) emptyWriterProjection
      (fixtureState archived))
  planned <- plannedFixture
  expectTransitionError (stageWriterProjection
    (v1CutoverId (fixtureCutover planned)) 1 1 emptyWriterProjection
    (fixtureState planned))
  expectTransitionError (projectV0Events cutoverId sampleEvents (fixtureState fixture))

identityRuleProbe :: PlanProbe
identityRuleProbe _ = do
  fixture <- projectedFixture
  plans <- migration (stagedIdentityPlans
    (v1CutoverId (fixtureCutover fixture)) (fixtureState fixture))
  ((oldId, (newId, kind)), _) <- maybe (Left "identity plans are empty") Right
    (uncons (Map.toAscList plans))
  (mapping, cutover, mapped) <- migration (recordMigratedIdentity probeTime
    (v1CutoverId (fixtureCutover fixture)) oldId newId kind (fixtureState fixture))
  require (v0V1IdentityMapOldId mapping == oldId
      && v0V1IdentityMapNewId mapping == newId
      && oldId /= newId
      && v1CutoverMappedIdentityCount cutover == 1)
    "identity mapping omitted ensured fields or reused old identity"
  expectError isDuplicateOld (recordMigratedIdentity probeTime
    (v1CutoverId cutover) oldId (newId <> ":other") kind mapped)
  other <- maybe (Left "identity fixture needs a second plan") Right
    (safeHead [entry | entry@(candidate, _) <- Map.toAscList plans, candidate /= oldId])
  let (otherOld, (_, otherKind)) = other
  expectError isDuplicateNew (recordMigratedIdentity probeTime
    (v1CutoverId cutover) otherOld newId otherKind mapped)
  expectError isInvalidIdentity (recordMigratedIdentity probeTime
    (v1CutoverId cutover) "sha256:title-derived" "sha256:title-derived"
    MigratedBrick mapped)
  archived <- archivedFixture
  expectTransitionError (recordMigratedIdentity probeTime
    (v1CutoverId (fixtureCutover archived)) "old" "opaque:new" MigratedBrick
    (fixtureState archived))
  where
    isDuplicateOld (DuplicateOldIdentity _) = True
    isDuplicateOld _ = False
    isDuplicateNew (DuplicateNewIdentity _) = True
    isDuplicateNew _ = False
    isInvalidIdentity (InvalidMigratedIdentity _) = True
    isInvalidIdentity _ = False

evidenceRuleProbe :: PlanProbe
evidenceRuleProbe _ = do
  fixture <- projectedFixture
  (evidence, state) <- migration (recordMigrationEvidence probeTime
    (v1CutoverId (fixtureCutover fixture)) (Just "legacy-event-0")
    (Just "sha256:seed-title") "legacy_stage" "retained semantic evidence"
    (fixtureState fixture))
  require (Map.lookup (migrationEvidenceId evidence)
      (migrationStateEvidence state) == Just evidence)
    "MigrationEvidence was not retained"
  expectError isInvalidEvidence (recordMigrationEvidence probeTime
    (v1CutoverId (fixtureCutover fixture)) Nothing Nothing "" "summary"
    (fixtureState fixture))
  archived <- archivedFixture
  expectTransitionError (recordMigrationEvidence probeTime
    (v1CutoverId (fixtureCutover archived)) Nothing Nothing "stage" "summary"
    (fixtureState archived))
  where
    isInvalidEvidence (InvalidMigrationEvidence _) = True
    isInvalidEvidence _ = False

projectionVerificationProbe :: PlanProbe
projectionVerificationProbe _ = do
  fixture <- mappedFixture
  (verified, state) <- verifyFixtureState
    (v1CutoverId (fixtureCutover fixture)) (fixtureState fixture)
  require (v1CutoverStatus verified == ProjectionVerified
      && v1CutoverV1LogHash verified /= Nothing
      && migrationStateActiveDataset state
        == migrationStateActiveDataset (fixtureState fixture))
    "projection verification activated or omitted its log hash"
  mismatch <- mappedFixture
  expectError (== ProjectionCountMismatch) (verifyV1Projection
    (v1CutoverId (fixtureCutover mismatch))
    (v1CutoverMappedIdentityCount (fixtureCutover mismatch) + 1)
    (v1CutoverProjectedEntityCount (fixtureCutover mismatch))
    (fixtureLogHash mismatch) (fixtureState mismatch))
  expectError (== ProjectionCountMismatch) (verifyV1Projection
    (v1CutoverId (fixtureCutover mismatch))
    (v1CutoverMappedIdentityCount (fixtureCutover mismatch))
    (v1CutoverProjectedEntityCount (fixtureCutover mismatch) + 1)
    (fixtureLogHash mismatch) (fixtureState mismatch))
  expectError (== ProjectionHashMismatch) (verifyV1Projection
    (v1CutoverId (fixtureCutover mismatch))
    (v1CutoverMappedIdentityCount (fixtureCutover mismatch))
    (v1CutoverProjectedEntityCount (fixtureCutover mismatch))
    "sha256:wrong" (fixtureState mismatch))
  archived <- archivedFixture
  expectTransitionError (verifyV1Projection
    (v1CutoverId (fixtureCutover archived)) 0 0 "sha256:x"
    (fixtureState archived))

projectionRejectionProbe :: PlanProbe
projectionRejectionProbe _ = do
  fixture <- projectedFixture
  let before = migrationStateActiveDataset (fixtureState fixture)
  (failed, state) <- migration (rejectV1Projection (addUTCTime 1 probeTime)
    (v1CutoverId (fixtureCutover fixture)) "projection_invalid"
    (fixtureState fixture))
  require (v1CutoverStatus failed == CutoverFailed
      && v1CutoverFailure failed == Just "projection_invalid"
      && migrationStateActiveDataset state == before)
    "projection rejection did not roll back authority cleanly"
  archived <- archivedFixture
  expectTransitionError (rejectV1Projection probeTime
    (v1CutoverId (fixtureCutover archived)) "invalid" (fixtureState archived))

commitRuleProbe :: PlanProbe
commitRuleProbe _ = do
  fixture <- verifiedFixture
  let beforeBytes = archiveBytes (v0ArchiveId (fixtureArchive fixture))
        (fixtureState fixture)
  (committed, receipt, state) <- migration (commitV1Cutover
    (addUTCTime 1 probeTime) (v1CutoverId (fixtureCutover fixture))
    "sha256:receipt" (fixtureState fixture))
  staged <- fixtureStaged fixture
  activeBricks <- migration (replayProjectedBricks
    (migrationStateActiveV1Log state))
  require (v1CutoverStatus committed == CutoverCommitted
      && v1CutoverReceiptHash committed == Just "sha256:receipt"
      && activeDatasetFormat (migrationStateActiveDataset state) == "v1"
      && activeDatasetLogHash (migrationStateActiveDataset state)
        == fixtureLogHash fixture
      && migrationStateActiveV1Log state == stagedV1DatasetCleanLog staged
      && activeBricks == stagedV1DatasetProjectedBricks staged
      && archiveBytes (v0ArchiveId (fixtureArchive fixture)) state == beforeBytes
      && cutoverReceiptArchiveHash receipt == v0ArchiveSha256 (fixtureArchive fixture))
    "atomic commit omitted receipt, clean log authority, or immutable archive"
  _ <- migration (verifyCutoverReceipt (v1CutoverId committed) state)
  expectTransitionError (commitV1Cutover probeTime
    (v1CutoverId committed) "sha256:again" state)
  projected <- projectedFixture
  expectTransitionError (commitV1Cutover probeTime
    (v1CutoverId (fixtureCutover projected)) "sha256:early"
    (fixtureState projected))
  expectError (== InvalidReceipt) (commitV1Cutover probeTime
    (v1CutoverId (fixtureCutover fixture)) "" (fixtureState fixture))

identityInvariantProbe :: PlanProbe
identityInvariantProbe _ = do
  fixture <- mappedFixture
  migration (validateMigrationState (fixtureState fixture))
  let mappings = Map.elems (migrationStateIdentityMaps (fixtureState fixture))
      keys = [(v0V1IdentityMapArchive item, v0V1IdentityMapOldId item)
        | item <- mappings]
  require (Set.size (Set.fromList keys) == length keys)
    "one archive contains duplicate old-ID mappings"

archiveInvariantProbe :: PlanProbe
archiveInvariantProbe _ = do
  fixture <- committedFixture
  require (all v0ArchiveImmutable
      (Map.elems (migrationStateArchives (fixtureState fixture))))
    "migration state contains a mutable historical archive"
  migration (validateMigrationState (fixtureState fixture))

receiptInvariantProbe :: PlanProbe
receiptInvariantProbe _ = do
  fixture <- committedFixture
  _ <- migration (verifyCutoverReceipt
    (v1CutoverId (fixtureCutover fixture)) (fixtureState fixture))
  migration (validateMigrationState (fixtureState fixture))

migrationDeskProbe :: PlanProbe
migrationDeskProbe _ = do
  fixture <- committedFixture
  require (v1CutoverStatus (fixtureCutover fixture) == CutoverCommitted
      && activeDatasetFormat (migrationStateActiveDataset (fixtureState fixture))
        == "v1")
    "MigrationDesk did not provide its complete verified workflow"
  _ <- migration (verifyCutoverReceipt
    (v1CutoverId (fixtureCutover fixture)) (fixtureState fixture))
  pure ()

------------------------------------------------------------
-- Fixtures and helpers
------------------------------------------------------------

data Fixture = Fixture
  { fixtureArchive :: V0Archive
  , fixtureCutover :: V1Cutover
  , fixtureState :: MigrationState
  }
  deriving stock (Eq, Show)

plannedFixture :: Either Text Fixture
plannedFixture = do
  (archive, cutover, state) <- migration (planV0V1CutoverFromBytes probeTime
    sourcePath targetPath sampleArchiveBytes emptyMigrationState)
  pure (Fixture archive cutover state)

archivedFixture :: Either Text Fixture
archivedFixture = do
  planned <- plannedFixture
  (archive, cutover, state) <- migration (verifyV0Archive probeTime
    (v1CutoverId (fixtureCutover planned))
    (v0ArchiveSha256 (fixtureArchive planned))
    (v0ArchiveEventCount (fixtureArchive planned)) (fixtureState planned))
  pure (Fixture archive cutover state)

projectedFixture :: Either Text Fixture
projectedFixture = do
  archived <- archivedFixture
  (cutover, state) <- migration (projectV0Events
    (v1CutoverId (fixtureCutover archived)) sampleEvents (fixtureState archived))
  pure archived {fixtureCutover = cutover, fixtureState = state}

mappedFixture :: Either Text Fixture
mappedFixture = do
  projected <- projectedFixture
  let cutoverId = v1CutoverId (fixtureCutover projected)
  mapped <- mapEveryIdentity cutoverId (fixtureState projected)
  (_, state) <- migration (recordMigrationEvidence probeTime cutoverId
    (Just "legacy-event-0") (Just "sha256:seed-title") "legacy_stage"
    "seed mapped to one active positioned v1 Brick" mapped)
  cutover <- migration (findCutover cutoverId state)
  pure projected {fixtureCutover = cutover, fixtureState = state}

verifiedFixture :: Either Text Fixture
verifiedFixture = do
  mapped <- mappedFixture
  (cutover, state) <- verifyFixtureState
    (v1CutoverId (fixtureCutover mapped)) (fixtureState mapped)
  pure mapped {fixtureCutover = cutover, fixtureState = state}

committedFixture :: Either Text Fixture
committedFixture = do
  verified <- verifiedFixture
  (cutover, _, state) <- migration (commitV1Cutover (addUTCTime 1 probeTime)
    (v1CutoverId (fixtureCutover verified)) "sha256:fixture-receipt"
    (fixtureState verified))
  pure verified {fixtureCutover = cutover, fixtureState = state}

mapEveryIdentity :: Text -> MigrationState -> Either Text MigrationState
mapEveryIdentity cutoverId state = do
  plans <- migration (stagedIdentityPlans cutoverId state)
  foldM (recordIdentityPlan cutoverId) state (Map.toAscList plans)

recordIdentityPlan ::
  Text -> MigrationState -> (Text, (Text, MigratedEntityKind)) ->
  Either Text MigrationState
recordIdentityPlan cutoverId state (oldId, (newId, kind)) = do
  (_, _, next) <- migration (recordMigratedIdentity probeTime cutoverId
    oldId newId kind state)
  pure next

verifyFixtureState ::
  Text -> MigrationState -> Either Text (V1Cutover, MigrationState)
verifyFixtureState cutoverId state = do
  cutover <- migration (findCutover cutoverId state)
  staged <- maybe (Left "missing staged fixture") Right
    (Map.lookup cutoverId (migrationStateStagedDatasets state))
  logHash <- maybe (Left "materialized fixture has no log hash") Right
    (stagedV1DatasetComputedLogHash staged)
  migration (verifyV1Projection cutoverId
    (v1CutoverMappedIdentityCount cutover)
    (v1CutoverProjectedEntityCount cutover) logHash state)

fixtureStaged :: Fixture -> Either Text StagedV1Dataset
fixtureStaged fixture = maybe (Left "fixture has no staged dataset") Right
  (Map.lookup (v1CutoverId (fixtureCutover fixture))
    (migrationStateStagedDatasets (fixtureState fixture)))

fixtureLogHash :: Fixture -> Text
fixtureLogHash fixture = case Map.lookup (v1CutoverId (fixtureCutover fixture))
    (migrationStateStagedDatasets (fixtureState fixture))
    >>= stagedV1DatasetComputedLogHash of
  Just value -> value
  Nothing -> "missing-log-hash"

stateAt :: CutoverStatus -> Either Text Fixture
stateAt status = case status of
  CutoverPlanned -> plannedFixture
  ArchiveVerified -> archivedFixture
  StateProjected -> projectedFixture
  ProjectionVerified -> verifiedFixture
  CutoverCommitted -> committedFixture
  CutoverFailed -> do
    planned <- plannedFixture
    (failed, state) <- migration (failCutover probeTime
      (v1CutoverId (fixtureCutover planned)) "fixture failure"
      (fixtureState planned))
    pure planned {fixtureCutover = failed, fixtureState = state}

optionalEvidenceProbe :: Bool -> Fixture -> Either Text ()
optionalEvidenceProbe oldEvent fixture = do
  let cutoverId = v1CutoverId (fixtureCutover fixture)
      projectedState = case projectedFixture of
        Left problem -> Left problem
        Right value -> Right (fixtureState value, v1CutoverId (fixtureCutover value))
  (state, projectedId) <- projectedState
  (absent, stateWithAbsent) <- migration (recordMigrationEvidence probeTime
    projectedId Nothing Nothing "stage" "summary" state)
  (present, _) <- migration (recordMigrationEvidence probeTime projectedId
    (Just "legacy-event-0") (Just "sha256:seed-title") "stage" "summary"
    stateWithAbsent)
  let field = if oldEvent then "old_event_id" else "subject_old_id"
  require (valueAt field (toJSON absent) == Just Null
      && valueAt field (toJSON present) /= Just Null
      && not (Text.null cutoverId))
    "optional MigrationEvidence field did not accept null and non-null values"

cutoverOptional :: Text -> Fixture -> Either Text ()
cutoverOptional field committed = do
  planned <- plannedFixture
  require (valueAt field (toJSON (fixtureCutover planned)) == Just Null
      && valueAt field (toJSON (fixtureCutover committed)) /= Just Null)
    "optional V1Cutover field did not accept null and non-null values"

emptyWriterProjection :: WriterProjection
emptyWriterProjection = WriterProjection "sha256:unused" Map.empty Map.empty []
  "sha256:empty"

sampleEvents :: [Event]
sampleEvents =
  [ event 0 (BrickCaptured seed "Seed")
  , event 1 (BrickCaptured committed "Committed")
  , event 2 (SeedPromoted committed)
  , event 3 (BrickCaptured ready "Ready")
  , event 4 (BrickReady ready)
  , event 5 (BrickCaptured wip "WIP")
  , event 6 (BrickStarted wip)
  , event 7 (BrickCaptured done "Done")
  , event 8 (BrickCompleted done)
  , event 9 (BrickCaptured dropped "Dropped")
  , event 10 (BrickKilled dropped)
  , event 11 (BrickCaptured superseded "Superseded")
  , event 12 (BricksUnified superseded committed (Just "duplicate"))
  , event 13 (Fed raw "legacy material")
  , event 14 (PartyRegistered party "Ada" V0.Person)
  ]
  where
    event :: Integer -> Body -> Event
    event offset body = Event ("legacy-event-" <> Text.pack (show offset))
      (addUTCTime (fromIntegral offset) probeTime) body
    seed = Id "sha256:seed-title"
    committed = Id "sha256:committed-title"
    ready = Id "sha256:ready-title"
    wip = Id "sha256:wip-title"
    done = Id "sha256:done-title"
    dropped = Id "sha256:dropped-title"
    superseded = Id "sha256:superseded-title"
    raw = Id "sha256:raw"
    party = Id "sha256:party"

sampleArchiveBytes :: LBS.ByteString
sampleArchiveBytes = mconcat [encode (eventToJSON event) <> "\n" | event <- sampleEvents]

sourcePath :: Text
sourcePath = "/archive/v0/events.jsonl"

targetPath :: Text
targetPath = "/datasets/v1/events.jsonl"

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 72000

roundTripAndFields :: (Eq value, ToJSON value, FromJSON value) =>
  value -> [Text] -> Either Text ()
roundTripAndFields value expected = do
  let encoded = toJSON value
  case fromJSON encoded of
    Error problem -> Left ("round-trip failed: " <> Text.pack problem)
    Success decoded -> require (decoded == value) "round-trip changed value"
  fields encoded expected

fields :: Value -> [Text] -> Either Text ()
fields value expected = case value of
  Object objectValue -> mapM_ (\field -> require
    (KeyMap.member (Key.fromText field) objectValue)
    ("missing field: " <> field)) expected
  _ -> Left "entity projection is not an object"

valueAt :: Text -> Value -> Maybe Value
valueAt field (Object objectValue) = KeyMap.lookup (Key.fromText field) objectValue
valueAt _ _ = Nothing

distinctRoundTrip :: (Ord value, ToJSON value, FromJSON value) =>
  [value] -> Either Text ()
distinctRoundTrip values = do
  require (Set.size (Set.fromList values) == length values)
    "enum constructors are not distinct"
  mapM_ (\value -> case fromJSON (toJSON value) of
    Success decoded -> require (decoded == value) "enum round-trip changed value"
    Error problem -> Left (Text.pack problem)) values

validOpaqueIds :: [ProjectedBrick] -> Bool
validOpaqueIds bricks =
  let identifiers = map projectedBrickNewId bricks
  in Set.size (Set.fromList identifiers) == length identifiers
    && all ("la1:migration:entity:" `Text.isPrefixOf`) identifiers
    && all (\brick -> projectedBrickOldId brick /= projectedBrickNewId brick) bricks

expectError ::
  (MigrationError -> Bool) -> Either MigrationError value -> Either Text ()
expectError predicate result = case result of
  Left problem | predicate problem -> Right ()
  Left problem -> Left ("unexpected migration failure: " <> Text.pack (show problem))
  Right _ -> Left "migration operation unexpectedly succeeded"

expectTransitionError :: Either MigrationError value -> Either Text ()
expectTransitionError = expectError isTransition
  where
    isTransition (InvalidCutoverTransition _ _) = True
    isTransition _ = False

migration :: Either MigrationError value -> Either Text value
migration = either (Left . Text.pack . show) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

safeHead :: [value] -> Maybe value
safeHead [] = Nothing
safeHead (value : _) = Just value

uncons :: [value] -> Maybe (value, [value])
uncons [] = Nothing
uncons (value : rest) = Just (value, rest)

firstOfPair :: (first, second) -> first
firstOfPair = fst

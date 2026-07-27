{-# LANGUAGE DerivingStrategies #-}

-- | Semantic Allium probes for the material module. Every registration runs
-- constructors, transitions, projections, or explicit adapter/blob boundaries;
-- no obligation identifier is inspected.
module LittleAnt.V1.MaterialPlanCatalog
  ( materialPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson (Object, ToJSON (toJSON), Value (..), encode, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy.Char8 as LBS8
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.V1.Contract (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Domain
  (Authority (..), Brick (brickId), BrickId, BrickStatus (Active),
   ListEntry (listEntryId), ListEntryDraft (..), ListEntryId, createBrick,
   createListEntry, emptyDomainState,
   finiteChecklistV1, mkCanonicalText, ordinaryBrickDraft, standardV1)
import LittleAnt.V1.Material

materialPlanProbes :: Map ProbeKey PlanProbe
materialPlanProbes = Map.fromList
  ( contractRegistrations
  <> enumRegistrations
  <> entityFieldRegistrations
  <> optionalFieldRegistrations
  <> relationshipRegistrations
  <> derivedRegistrations
  <> ruleRegistrations
  <> transitionRegistrations
  <> invariantRegistrations
  <> surfaceRegistrations
  )

------------------------------------------------------------
-- Registry declarations
------------------------------------------------------------

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" construct probe
  | (construct, probe) <-
      [ ("SourceReader.observe", sourceReaderContractProbe)
      , ("SourceReader.fetch", sourceReaderContractProbe)
      , ("CanonicalBlobStore.put", blobStoreContractProbe)
      , ("CanonicalBlobStore.read", blobStoreContractProbe)
      , ("CanonicalBlobStore.verify", blobStoreContractProbe)
      ]
  ]

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ enumRegistration "RawReviewState" [toJSON RawPending, toJSON RawReviewedState]
  , enumRegistration "RawStorageState" [toJSON RawActive, toJSON RawArchivedState]
  , enumRegistration "SnapshotAvailability"
      [toJSON SnapshotAvailable, toJSON SnapshotMissing, toJSON SnapshotCorrupt]
  , enumRegistration "RawLinkRole"
      [toJSON Attachment, toJSON Source, toJSON Evidence, toJSON DerivedFrom]
  , enumRegistration "ExternalPresence"
      [toJSON PresenceUnknown, toJSON Present, toJSON Removed, toJSON Unavailable]
  , enumRegistration "ExternalWorkState"
      [toJSON WorkUnknown, toJSON WorkOpen, toJSON WorkCompleted]
  , enumRegistration "ReviewDispositionKind"
      [toJSON Retained, toJSON Linked, toJSON ProducedWork, toJSON NoWork]
  ]

entityFieldRegistrations :: [(ProbeKey, PlanProbe)]
entityFieldRegistrations =
  [ entityFields "Raw"
      [ "id", "title", "original_text", "canonical_english"
      , "normalization_authority", "review_state", "storage_state", "created_at"
      ]
  , entityFields "RawOrigin"
      [ "id", "raw", "adapter", "locator", "external_id", "last_checked_at"
      , "last_observed_revision", "historical_only", "created_at"
      ]
  , entityFields "RawSnapshot"
      [ "id", "raw", "content_hash", "size", "media_type", "captured_at"
      , "origin_revision", "availability", "verified_at"
      ]
  , entityFields "RawLink"
      [ "id", "raw", "role", "owner_brick", "owner_entry", "owner_raw"
      , "reconciled_snapshot", "created_at"
      ]
  , entityFields "RawShelf" ["id", "name", "created_at"]
  , entityFields "RawShelfMembership" ["id", "raw", "shelf", "added_at"]
  , entityFields "SourceObservation"
      [ "id", "origin", "observed_at", "authority"
      , "external_observation_id", "revision", "presence", "work_state"
      , "failure_detail"
      ]
  , entityFields "RawReviewDisposition"
      ["id", "raw", "kind", "brick", "recorded_at", "authority", "note"]
  ]

optionalFieldRegistrations :: [(ProbeKey, PlanProbe)]
optionalFieldRegistrations = map optionalField
  [ "Raw.title", "Raw.original_text", "Raw.canonical_english"
  , "Raw.normalization_authority", "RawOrigin.external_id"
  , "RawOrigin.last_checked_at", "RawOrigin.last_observed_revision"
  , "RawSnapshot.origin_revision", "RawSnapshot.verified_at"
  , "RawLink.owner_brick", "RawLink.owner_entry", "RawLink.owner_raw"
  , "RawLink.reconciled_snapshot", "SourceObservation.external_observation_id"
  , "SourceObservation.revision", "SourceObservation.failure_detail"
  , "RawReviewDisposition.brick", "RawReviewDisposition.note"
  ]

relationshipRegistrations :: [(ProbeKey, PlanProbe)]
relationshipRegistrations =
  [ relationship "Raw.origin"
  , relationship "Raw.snapshots"
  , relationship "Raw.links"
  , relationship "Raw.memberships"
  , relationship "RawOrigin.observations"
  , relationship "RawShelf.memberships"
  ]

derivedRegistrations :: [(ProbeKey, PlanProbe)]
derivedRegistrations =
  [registration "derived" "Raw.latest_snapshot" latestSnapshotProbe]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations =
  [ registration category construct allMaterialRulesProbe
  | (category, constructs) <-
      [ ("rule_success",
          [ "InlineRawCaptured", "ExternalRawCaptured", "RawSnapshotCaptured"
          , "ExistingRawSnapshotObservedAgain", "SnapshotReportedMissing"
          , "SnapshotReportedCorrupt", "SnapshotRepaired", "OriginObserved"
          , "OriginRelocated", "OriginRetiredAfterMigration", "RawReviewed"
          , "RawReopened", "RawArchived", "RawUnarchived", "RawLinkedToBrick"
          , "RawLinkedToEntry", "RawDerivedFromRaw", "SourceLinkReconciled"
          , "RawShelfCreated", "RawAddedToShelf", "RawRemovedFromShelf"
          ])
      , ("rule_failure",
          [ "InlineRawCaptured", "RawSnapshotCaptured"
          , "ExistingRawSnapshotObservedAgain", "SnapshotReportedMissing"
          , "SnapshotReportedCorrupt", "SnapshotRepaired"
          , "OriginRetiredAfterMigration", "RawReviewed", "RawReopened"
          , "RawArchived", "RawUnarchived", "RawLinkedToBrick"
          , "RawLinkedToEntry", "RawDerivedFromRaw", "SourceLinkReconciled"
          , "RawAddedToShelf", "RawRemovedFromShelf"
          ])
      , ("rule_entity_creation",
          [ "InlineRawCaptured", "ExternalRawCaptured", "RawSnapshotCaptured"
          , "OriginObserved", "RawReviewed", "RawLinkedToBrick"
          , "RawLinkedToEntry", "RawDerivedFromRaw", "RawShelfCreated"
          , "RawAddedToShelf"
          ])
      ]
  , construct <- constructs
  ]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [ registration "transition_edge" construct materialTransitionProbe
  | construct <- ["Raw.review_state", "Raw.storage_state", "RawSnapshot.availability"]
  ] <>
  [ registration "transition_rejected" construct materialTransitionProbe
  | construct <- ["Raw.review_state", "Raw.storage_state", "RawSnapshot.availability"]
  ]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" construct materialInvariantProbe
  | construct <-
      [ "AtMostOneOriginPerRaw", "RawNormalizationIsAttributed"
      , "DerivedRawLinkOwnsRaw", "WorkRawLinkOwnsBrickOrEntry"
      , "RawLinkHasExactlyOneOwner", "SnapshotBelongsToLinkedRaw"
      , "ShelvesAreFlat", "NoPermanentRawDeletion"
      ]
  ]

surfaceRegistrations :: [(ProbeKey, PlanProbe)]
surfaceRegistrations =
  [registration category "MaterialDesk" materialDeskProbe
  | category <- ["surface_actor", "surface_exposure", "surface_provides"]]

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct probe =
  ( ProbeKey "material" category construct
  , \input -> do
      checkMetadata category construct input
      probe
  )

enumRegistration :: Text -> [Value] -> (ProbeKey, PlanProbe)
enumRegistration construct values = registration "enum_comparable" construct $ do
  require (not (null values)) "material enum has no values"
  require (Set.size (Set.fromList (map encode values)) == length values)
    "material enum encodings are not unique"
  require (all canonicalEnum values) "material enum does not encode as canonical text"
  where
    canonicalEnum (String value) = Text.toLower value == value && not (Text.null value)
    canonicalEnum _ = False

entityFields :: Text -> [Text] -> (ProbeKey, PlanProbe)
entityFields construct fields = registration "entity_fields" construct $ do
  projection <- entityFixture construct
  objectValue <- asObject construct projection
  require (all (\field -> KeyMap.member (Key.fromText field) objectValue) fields)
    (construct <> " projection omits a declared field")
  requireEntityTypes construct objectValue

optionalField :: Text -> (ProbeKey, PlanProbe)
optionalField construct = registration "entity_optional" construct $ do
  projection <- optionalEntityFixture construct
  objectValue <- asObject construct projection
  let field = Text.takeWhileEnd (/= '.') construct
  require (KeyMap.lookup (Key.fromText field) objectValue == Just Null)
    (construct <> " does not preserve null optional presence")

relationship :: Text -> (ProbeKey, PlanProbe)
relationship construct = registration "entity_relationship" construct $ do
  projection <- relationshipFixture construct
  let field = Text.takeWhileEnd (/= '.') construct
  selected <- selectField field projection
  case construct of
    "Raw.origin" -> require (selected /= Null) "Raw origin relationship is absent"
    _ -> case selected of
      Array values -> require (not (null values)) (construct <> " is empty")
      _ -> Left (construct <> " is not projected as a relationship collection")

------------------------------------------------------------
-- Contract and entity probes
------------------------------------------------------------

sourceReaderContractProbe :: Either Text ()
sourceReaderContractProbe = do
  let originalState = emptyMaterialState
      reader = SourceReader $ \kind adapter locator -> Right SourceReadResult
        { sourceReadAdapter = adapter
        , sourceReadLocator = locator
        , sourceReadObservedAt = probeTime
        , sourceReadAuthority = Adapter
        , sourceReadExternalRevision = Just (case kind of
            ObserveSource -> "observed-r1"
            FetchSource -> "fetched-r1")
        , sourceReadPayload = object ["read_kind" .= show kind]
        }
  observed <- mapMaterialError (sourceReaderObserve reader "fake" "item:1")
  fetched <- mapMaterialError (sourceReaderFetch reader "fake" "item:1")
  _ <- mapMaterialError (validateSourceReadResult "fake" "item:1" observed)
  _ <- mapMaterialError (validateSourceReadResult "fake" "item:1" fetched)
  require (sourceReadExternalRevision observed /= sourceReadExternalRevision fetched)
    "observe and fetch did not traverse their explicit boundary methods"
  require (originalState == emptyMaterialState)
    "source read mutated local material state"
  case validateSourceReadResult "other" "item:1" observed of
    Left (InvalidSourceAttribution _) -> Right ()
    result -> Left ("misattributed source result was accepted: " <> tshow result)

blobStoreContractProbe :: Either Text ()
blobStoreContractProbe = do
  let bytes = LBS8.pack "immutable material bytes"
      contentHash = canonicalContentHash bytes
      size = fromIntegral (LBS8.length bytes)
  stored <- mapMaterialError
    (canonicalBlobPut contentHash size "text/plain" bytes emptyCanonicalBlobStore)
  readBack <- mapMaterialError (canonicalBlobRead contentHash stored)
  require (readBack == bytes) "canonical blob read changed bytes"
  require (canonicalBlobVerify contentHash stored)
    "canonical blob verification rejected intact bytes"
  reused <- mapMaterialError
    (canonicalBlobPut contentHash size "text/plain" bytes stored)
  require (reused == stored) "equal canonical bytes were not deduplicated"
  case canonicalBlobPut "sha256:not-the-content" size "text/plain" bytes stored of
    Left (BlobHashMismatch _ _) -> Right ()
    result -> Left ("blob store accepted mismatched content hash: " <> tshow result)
  case canonicalBlobPut contentHash (size + 1) "text/plain" bytes stored of
    Left (BlobSizeMismatch _ _) -> Right ()
    result -> Left ("blob store accepted mismatched size: " <> tshow result)
  require (not (canonicalBlobVerify "sha256:missing" stored))
    "missing blob verified successfully"

entityFixture :: Text -> Either Text Value
entityFixture construct = do
  sample <- materialSample
  case construct of
    "Raw" -> mapMaterialError (rawProjection (sampleState sample) (rawId (sampleExternalRaw sample)))
    "RawOrigin" -> Right (rawOriginProjection (sampleState sample) (sampleOrigin sample))
    "RawSnapshot" -> Right (rawSnapshotProjection (sampleFirstSnapshot sample))
    "RawLink" -> mapMaterialError
      (rawLinkProjection (sampleState sample) (rawLinkId (sampleSourceLink sample)))
    "RawShelf" -> Right (rawShelfProjection (sampleState sample) (sampleShelf sample))
    "RawShelfMembership" -> Right (rawShelfMembershipProjection (sampleMembership sample))
    "SourceObservation" -> Right (sourceObservationProjection (sampleObservation sample))
    "RawReviewDisposition" -> Right
      (rawReviewDispositionProjection (sampleDisposition sample))
    _ -> Left ("unknown material entity fixture: " <> construct)

optionalEntityFixture :: Text -> Either Text Value
optionalEntityFixture construct
  | "Raw." `Text.isPrefixOf` construct = do
      sample <- materialSample
      let selected = if construct == "Raw.original_text"
            then sampleExternalRaw sample
            else sampleInlineRaw sample
      mapMaterialError (rawProjection (sampleState sample) (rawId selected))
  | "RawOrigin." `Text.isPrefixOf` construct = do
      ((_, origin), state) <- mapMaterialError (captureExternalRaw Nothing "fake"
        "item:optional" Nothing probeTime emptyMaterialState)
      Right (rawOriginProjection state origin)
  | "RawSnapshot." `Text.isPrefixOf` construct = do
      (raw, first) <- mapMaterialError
        (captureInlineRaw "snapshot optional" Nothing Nothing probeTime emptyMaterialState)
      (captured, second) <- mapMaterialError (captureRawSnapshot (rawId raw)
        "sha256:optional" 1 "text/plain" Nothing probeTime first)
      snapshot <- createdSnapshot captured
      if construct == "RawSnapshot.verified_at"
        then do
          (missing, _) <- mapMaterialError
            (reportSnapshotMissing (rawSnapshotId snapshot) second)
          Right (rawSnapshotProjection missing)
        else Right (rawSnapshotProjection snapshot)
  | "RawLink." `Text.isPrefixOf` construct = optionalLinkFixture construct
  | "SourceObservation." `Text.isPrefixOf` construct = do
      ((_, origin), first) <- mapMaterialError (captureExternalRaw Nothing "fake"
        "item:observation" Nothing probeTime emptyMaterialState)
      (observation, _) <- mapMaterialError (recordSourceObservation
        (rawOriginId origin) Adapter Nothing Nothing PresenceUnknown WorkUnknown
        Nothing probeTime first)
      Right (sourceObservationProjection observation)
  | "RawReviewDisposition." `Text.isPrefixOf` construct = do
      (raw, first) <- mapMaterialError
        (captureInlineRaw "review optional" Nothing Nothing probeTime emptyMaterialState)
      ((_, disposition), _) <- mapMaterialError
        (reviewRaw (rawId raw) Retained Nothing Human Nothing probeTime first)
      Right (rawReviewDispositionProjection disposition)
  | otherwise = Left ("unknown optional material fixture: " <> construct)

optionalLinkFixture :: Text -> Either Text Value
optionalLinkFixture construct = do
  work <- domainWorkFixture
  (raw, first) <- mapMaterialError
    (captureInlineRaw "link optional" Nothing Nothing probeTime emptyMaterialState)
  let registered = registerMaterialListEntry (workEntry work)
        (registerMaterialBrick (workBrick work) Active first)
  (link, final) <- if construct == "RawLink.owner_brick"
    then mapMaterialError
      (linkRawToEntry (rawId raw) (workEntry work) Attachment probeTime registered)
    else mapMaterialError
      (linkRawToBrick (rawId raw) (workBrick work) Attachment Nothing probeTime registered)
  rawLinkProjection final (rawLinkId link) & mapMaterialError

relationshipFixture :: Text -> Either Text Value
relationshipFixture construct = do
  sample <- materialSample
  case construct of
    "Raw.origin" -> mapMaterialError
      (rawProjection (sampleState sample) (rawId (sampleExternalRaw sample)))
    "Raw.snapshots" -> mapMaterialError
      (rawProjection (sampleState sample) (rawId (sampleExternalRaw sample)))
    "Raw.links" -> mapMaterialError
      (rawProjection (sampleState sample) (rawId (sampleExternalRaw sample)))
    "Raw.memberships" -> mapMaterialError
      (rawProjection (sampleState sample) (rawId (sampleExternalRaw sample)))
    "RawOrigin.observations" -> Right
      (rawOriginProjection (sampleState sample) (sampleOrigin sample))
    "RawShelf.memberships" -> Right
      (rawShelfProjection (sampleState sample) (sampleShelf sample))
    _ -> Left ("unknown material relationship fixture: " <> construct)

latestSnapshotProbe :: Either Text ()
latestSnapshotProbe = do
  sample <- materialSample
  latest <- mapMaterialError
    (rawLatestSnapshot (sampleState sample) (rawId (sampleExternalRaw sample)))
  require (latest == Just (sampleSecondSnapshot sample))
    "latest_snapshot did not select the newest immutable capture"
  require (sampleFirstSnapshot sample /= sampleSecondSnapshot sample)
    "two content versions collapsed to one snapshot"

requireEntityTypes :: Text -> Object -> Either Text ()
requireEntityTypes construct fields = case construct of
  "Raw" -> requireString "id" >> requireString "review_state" >> requireString "storage_state"
  "RawOrigin" -> requireString "id" >> requireString "adapter" >> requireBoolean "historical_only"
  "RawSnapshot" -> requireString "id" >> requireString "content_hash" >> requireNumber "size"
  "RawLink" -> requireString "id" >> requireString "role"
  "RawShelf" -> requireString "id" >> requireString "name"
  "RawShelfMembership" -> requireString "id" >> requireString "raw" >> requireString "shelf"
  "SourceObservation" -> requireString "id" >> requireString "presence" >> requireString "work_state"
  "RawReviewDisposition" -> requireString "id" >> requireString "kind"
  _ -> Left ("unknown material entity type check: " <> construct)
  where
    field name = maybe (Left ("missing field: " <> name)) Right
      (KeyMap.lookup (Key.fromText name) fields)
    requireString name = field name >>= \case
      String _ -> Right ()
      _ -> Left (name <> " must be text")
    requireBoolean name = field name >>= \case
      Bool _ -> Right ()
      _ -> Left (name <> " must be Boolean")
    requireNumber name = field name >>= \case
      Number _ -> Right ()
      _ -> Left (name <> " must be numeric")

------------------------------------------------------------
-- Rules, transitions, invariants, and surface
------------------------------------------------------------

allMaterialRulesProbe :: Either Text ()
allMaterialRulesProbe = do
  work <- domainWorkFixture
  -- Inline attribution and external one-origin capture.
  (inline, first) <- mapMaterialError
    (captureInlineRaw "entrada original" (Just "Original input") (Just Human)
      probeTime emptyMaterialState)
  require (rawReviewState inline == RawPending && rawStorageState inline == RawActive)
    "inline Raw did not begin pending and active"
  case captureInlineRaw "bad" (Just "Canonical") Nothing probeTime first of
    Left InvalidNormalizationAttribution -> Right ()
    result -> Left ("unattributed normalization was accepted: " <> tshow result)
  case captureInlineRaw "bad" Nothing (Just Human) probeTime first of
    Left InvalidNormalizationAttribution -> Right ()
    result -> Left ("authority without normalization was accepted: " <> tshow result)
  ((external, origin), second) <- mapMaterialError
    (captureExternalRaw (Just "External") "fake" "item:1" (Just "upstream:1")
      probeTime first)
  require (length [candidate | candidate <- Map.elems (materialOrigins second),
    rawOriginRaw candidate == rawId external] == 1)
    "external capture did not create exactly one origin"

  -- Immutable snapshots, duplicate reuse, and all availability edges.
  (firstCapture, third) <- mapMaterialError (captureRawSnapshot (rawId external)
    "sha256:first" 5 "text/plain" (Just "r1") probeTime second)
  snapshot <- createdSnapshot firstCapture
  (reused, unchanged) <- mapMaterialError (captureRawSnapshot (rawId external)
    "sha256:first" 5 "text/plain" (Just "r1-again") probeLater third)
  require (reused == SnapshotReused snapshot && unchanged == third)
    "same Raw content did not reuse immutable snapshot identity"
  case captureRawSnapshot (rawId external) "sha256:negative" (-1)
      "text/plain" Nothing probeTime third of
    Left (InvalidSnapshotSize (-1)) -> Right ()
    result -> Left ("negative snapshot size was accepted: " <> tshow result)
  (missing, fourth) <- mapMaterialError
    (reportSnapshotMissing (rawSnapshotId snapshot) third)
  require (rawSnapshotAvailability missing == SnapshotMissing
      && rawSnapshotVerifiedAt missing == Nothing)
    "missing transition retained available verification"
  case reportSnapshotMissing (rawSnapshotId snapshot) fourth of
    Left (InvalidMaterialTransition _) -> Right ()
    result -> Left ("duplicate missing transition was accepted: " <> tshow result)
  (repairedMissing, fifth) <- mapMaterialError
    (verifySnapshotBytes (rawSnapshotId snapshot) probeLater fourth)
  require (rawSnapshotAvailability repairedMissing == SnapshotAvailable)
    "missing snapshot did not repair to available"
  (corrupt, sixth) <- mapMaterialError
    (reportSnapshotCorrupt (rawSnapshotId snapshot) fifth)
  require (rawSnapshotAvailability corrupt == SnapshotCorrupt)
    "available snapshot did not transition to corrupt"
  (repairedCorrupt, seventh) <- mapMaterialError
    (verifySnapshotBytes (rawSnapshotId snapshot) probeLater sixth)
  require (rawSnapshotAvailability repairedCorrupt == SnapshotAvailable)
    "corrupt snapshot did not repair to available"
  case verifySnapshotBytes (rawSnapshotId snapshot) probeLater seventh of
    Left (InvalidMaterialTransition _) -> Right ()
    result -> Left ("available snapshot repaired again: " <> tshow result)

  -- Presence and work state are independent and do not change local axes.
  (observation, eighth) <- mapMaterialError (recordSourceObservation
    (rawOriginId origin) Adapter (Just "obs:1") (Just "r2") Removed WorkUnknown
    Nothing probeLater seventh)
  require (sourceObservationPresence observation == Removed
      && sourceObservationWorkState observation == WorkUnknown)
    "source observation compressed presence into work state"
  observedRaw <- requireRaw (rawId external) eighth
  require (rawStorageState observedRaw == RawActive)
    "external removal archived local Raw"
  (relocated, ninth) <- mapMaterialError
    (relocateRawOrigin (rawOriginId origin) "item:2" eighth)
  require (rawOriginLocator relocated == "item:2" && rawOriginLocator origin == "item:1")
    "origin relocation did not preserve the prior immutable value"
  (retired, tenth) <- mapMaterialError (retireRawOrigin (rawOriginId origin) ninth)
  require (rawOriginHistoricalOnly retired) "origin retirement did not mark provenance historical"
  case retireRawOrigin (rawOriginId origin) tenth of
    Left (InvalidMaterialTransition _) -> Right ()
    result -> Left ("historical origin retired twice: " <> tshow result)

  -- Independent review/storage transitions and durable disposition.
  let withWork = registerMaterialBrick (workBrick work) Active tenth
  ((reviewed, disposition), eleventh) <- mapMaterialError
    (reviewRaw (rawId inline) ProducedWork (Just (workBrick work)) Human
      (Just "created work") probeLater withWork)
  require (rawReviewState reviewed == RawReviewedState
      && rawStorageState reviewed == RawActive
      && rawReviewDispositionBrick disposition == Just (workBrick work))
    "review changed storage state or lost its disposition"
  case reviewRaw (rawId inline) Retained Nothing Human Nothing probeLater eleventh of
    Left (InvalidMaterialTransition _) -> Right ()
    result -> Left ("reviewed Raw reviewed again: " <> tshow result)
  (archived, twelfth) <- mapMaterialError (archiveRaw (rawId inline) eleventh)
  require (rawStorageState archived == RawArchivedState
      && rawReviewState archived == RawReviewedState)
    "archive changed review state"
  case archiveRaw (rawId inline) twelfth of
    Left (InvalidMaterialTransition _) -> Right ()
    result -> Left ("archived Raw archived again: " <> tshow result)
  (reopened, thirteenth) <- mapMaterialError (reopenRaw (rawId inline) twelfth)
  require (rawReviewState reopened == RawPending
      && rawStorageState reopened == RawArchivedState)
    "reopen changed storage state"
  case reopenRaw (rawId inline) thirteenth of
    Left (InvalidMaterialTransition _) -> Right ()
    result -> Left ("pending Raw reopened: " <> tshow result)
  (unarchived, fourteenth) <- mapMaterialError (unarchiveRaw (rawId inline) thirteenth)
  require (rawStorageState unarchived == RawActive
      && rawReviewState unarchived == RawPending)
    "unarchive changed review state"
  case unarchiveRaw (rawId inline) fourteenth of
    Left (InvalidMaterialTransition _) -> Right ()
    result -> Left ("active Raw unarchived: " <> tshow result)

  -- Typed owners, duplicate rejection, derived ownership, and reconciliation.
  let withEntry = registerMaterialListEntry (workEntry work) fourteenth
  (brickLink, fifteenth) <- mapMaterialError
    (linkRawToBrick (rawId external) (workBrick work) Source
      (Just (rawSnapshotId snapshot)) probeLater withEntry)
  require (rawLinkOwnerBrick brickLink == Just (workBrick work)
      && rawLinkOwnerEntry brickLink == Nothing && rawLinkOwnerRaw brickLink == Nothing)
    "Brick RawLink does not have exactly one owner"
  case linkRawToBrick (rawId external) (workBrick work) Source Nothing probeLater fifteenth of
    Left DuplicateRawLink -> Right ()
    result -> Left ("duplicate Brick link was accepted: " <> tshow result)
  case linkRawToBrick (rawId external) (workBrick work) DerivedFrom Nothing probeLater fifteenth of
    Left (InvalidRawLinkRole DerivedFrom) -> Right ()
    result -> Left ("derived role accepted for Brick owner: " <> tshow result)
  (entryLink, sixteenth) <- mapMaterialError
    (linkRawToEntry (rawId inline) (workEntry work) Evidence probeLater fifteenth)
  require (rawLinkOwnerEntry entryLink == Just (workEntry work))
    "entry link did not retain its valid owner"
  case linkRawToEntry (rawId inline) (workEntry work) Evidence probeLater sixteenth of
    Left DuplicateRawLink -> Right ()
    result -> Left ("duplicate entry link was accepted: " <> tshow result)
  (derivedLink, seventeenth) <- mapMaterialError
    (linkDerivedRaw (rawId inline) (rawId external) probeLater sixteenth)
  require (rawLinkRaw derivedLink == rawId external
      && rawLinkOwnerRaw derivedLink == Just (rawId inline)
      && rawLinkRole derivedLink == DerivedFrom)
    "derived link did not make the derived Raw its owner"
  case linkDerivedRaw (rawId external) (rawId external) probeLater seventeenth of
    Left (InvalidRawLinkOwner _) -> Right ()
    result -> Left ("self-derived Raw was accepted: " <> tshow result)
  (secondCapture, eighteenth) <- mapMaterialError
    (captureRawSnapshot (rawId external) "sha256:second" 6 "text/plain"
      (Just "r3") probeLater seventeenth)
  secondSnapshot <- createdSnapshot secondCapture
  require (openSourceReconciliationKinds eighteenth (workBrick work)
      == ["source_reconciliation"])
    "new source snapshot did not derive reconciliation pressure"
  (reconciled, nineteenth) <- mapMaterialError
    (reconcileRawLink (rawLinkId brickLink) (rawSnapshotId secondSnapshot) eighteenth)
  require (rawLinkReconciledSnapshot reconciled == Just (rawSnapshotId secondSnapshot))
    "explicit reconciliation did not advance the baseline"
  case reconcileRawLink (rawLinkId entryLink) (rawSnapshotId secondSnapshot) nineteenth of
    Left (InvalidRawLinkOwner _) -> Right ()
    result -> Left ("cross-Raw snapshot baseline was accepted: " <> tshow result)
  case reconcileRawLink (rawLinkId derivedLink) (rawSnapshotId secondSnapshot) nineteenth of
    Left (InvalidRawLinkRole DerivedFrom) -> Right ()
    result -> Left ("derived link was reconciled as source: " <> tshow result)

  -- Flat, unique, reversible memberships; Raw entities are never deleted.
  (shelf, twentieth) <- mapMaterialError
    (createRawShelf "Evidence" probeTime nineteenth)
  (_, twentyFirst) <- mapMaterialError
    (addRawToShelf (rawId external) (rawShelfId shelf) probeLater twentieth)
  case addRawToShelf (rawId external) (rawShelfId shelf) probeLater twentyFirst of
    Left (DuplicateShelfMembership _ _) -> Right ()
    result -> Left ("duplicate shelf membership was accepted: " <> tshow result)
  twentySecond <- mapMaterialError
    (removeRawFromShelf (rawId external) (rawShelfId shelf) twentyFirst)
  case removeRawFromShelf (rawId external) (rawShelfId shelf) twentySecond of
    Left (MissingShelfMembership _ _) -> Right ()
    result -> Left ("missing shelf membership removed: " <> tshow result)
  require (Map.member (rawId external) (materialRaws twentySecond)
      && Map.member (rawId inline) (materialRaws twentySecond))
    "material operation permanently deleted Raw history"
  mapMaterialError (validateMaterialState twentySecond)

materialTransitionProbe :: Either Text ()
materialTransitionProbe = allMaterialRulesProbe

materialInvariantProbe :: Either Text ()
materialInvariantProbe = do
  sample <- materialSample
  mapMaterialError (validateMaterialState (sampleState sample))
  allMaterialRulesProbe
  -- Projection has no work-state operations, priority position, focus, or done.
  projection <- mapMaterialError (materialProjection (sampleState sample))
  require (all (`notDeepField` projection) ["priority_position", "focus", "done"])
    "material projection exposed work semantics"

materialDeskProbe :: Either Text ()
materialDeskProbe = do
  work <- domainWorkFixture
  require (not (Text.null (showText (workBrick work))))
    "MaterialDesk fixture has no identified domain actor/work boundary"
  sourceReaderContractProbe
  blobStoreContractProbe
  allMaterialRulesProbe

------------------------------------------------------------
-- Real sample constructors
------------------------------------------------------------

data DomainWork = DomainWork
  { workBrick :: BrickId
  , workEntry :: ListEntryId
  }

data MaterialSample = MaterialSample
  { sampleState :: MaterialState
  , sampleExternalRaw :: Raw
  , sampleInlineRaw :: Raw
  , sampleOrigin :: RawOrigin
  , sampleFirstSnapshot :: RawSnapshot
  , sampleSecondSnapshot :: RawSnapshot
  , sampleSourceLink :: RawLink
  , sampleShelf :: RawShelf
  , sampleMembership :: RawShelfMembership
  , sampleObservation :: SourceObservation
  , sampleDisposition :: RawReviewDisposition
  }

domainWorkFixture :: Either Text DomainWork
domainWorkFixture = do
  title <- mapDomainError (mkCanonicalText "Material owner" Nothing Human)
  (brick, first) <- mapDomainError
    (createBrick (ordinaryBrickDraft title standardV1 probeTime) emptyDomainState)
  checklistTitle <- mapDomainError (mkCanonicalText "Material entries" Nothing Human)
  (checklist, second) <- mapDomainError
    (createBrick (ordinaryBrickDraft checklistTitle finiteChecklistV1 probeTime) first)
  label <- mapDomainError (mkCanonicalText "Attached entry" Nothing Human)
  (entry, _) <- mapDomainError
    (createListEntry (ListEntryDraft (brickId checklist) label Nothing Nothing probeTime) second)
  pure DomainWork {workBrick = brickId brick, workEntry = listEntryId entry}

materialSample :: Either Text MaterialSample
materialSample = do
  work <- domainWorkFixture
  ((external, origin), first) <- mapMaterialError
    (captureExternalRaw Nothing "fake" "item:sample" Nothing probeTime emptyMaterialState)
  (inline, second) <- mapMaterialError
    (captureInlineRaw "sample input" Nothing Nothing probeTime first)
  let registered = registerMaterialListEntry (workEntry work)
        (registerMaterialBrick (workBrick work) Active second)
  (capturedFirst, third) <- mapMaterialError
    (captureRawSnapshot (rawId external) "sha256:sample-v1" 1
      "text/plain" Nothing probeTime registered)
  firstSnapshot <- createdSnapshot capturedFirst
  (sourceLink, fourth) <- mapMaterialError
    (linkRawToBrick (rawId external) (workBrick work) Source
      (Just (rawSnapshotId firstSnapshot)) probeTime third)
  (capturedSecond, fifth) <- mapMaterialError
    (captureRawSnapshot (rawId external) "sha256:sample-v2" 2
      "text/plain" (Just "r2") probeLater fourth)
  secondSnapshot <- createdSnapshot capturedSecond
  (observation, sixth) <- mapMaterialError
    (recordSourceObservation (rawOriginId origin) Adapter (Just "obs:sample")
      (Just "r2") Present WorkOpen Nothing probeLater fifth)
  (shelf, seventh) <- mapMaterialError (createRawShelf "Sample shelf" probeTime sixth)
  (membership, eighth) <- mapMaterialError
    (addRawToShelf (rawId external) (rawShelfId shelf) probeLater seventh)
  ((_, disposition), ninth) <- mapMaterialError
    (reviewRaw (rawId inline) Retained Nothing Human Nothing probeLater eighth)
  pure MaterialSample
    { sampleState = ninth
    , sampleExternalRaw = external
    , sampleInlineRaw = inline
    , sampleOrigin = fromMaybeOrigin origin ninth
    , sampleFirstSnapshot = firstSnapshot
    , sampleSecondSnapshot = secondSnapshot
    , sampleSourceLink = sourceLink
    , sampleShelf = shelf
    , sampleMembership = membership
    , sampleObservation = observation
    , sampleDisposition = disposition
    }

fromMaybeOrigin :: RawOrigin -> MaterialState -> RawOrigin
fromMaybeOrigin fallback state = Map.findWithDefault fallback (rawOriginId fallback)
  (materialOrigins state)

createdSnapshot :: SnapshotCaptureResult -> Either Text RawSnapshot
createdSnapshot result = case result of
  SnapshotCreated snapshot -> Right snapshot
  SnapshotReused _ -> Left "expected a distinct snapshot creation"

requireRaw :: RawId -> MaterialState -> Either Text Raw
requireRaw identifier state = maybe (Left "Raw disappeared from material state") Right
  (Map.lookup identifier (materialRaws state))

------------------------------------------------------------
-- Common helpers
------------------------------------------------------------

checkMetadata :: Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata category construct input = do
  require (planProbeModule input == "material") "probe received wrong module"
  require (planProbeCategory input == category) "probe received wrong category"
  require (planProbeSourceConstruct input == construct)
    "probe received wrong semantic construct"

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

mapMaterialError :: Either MaterialError value -> Either Text value
mapMaterialError = either (Left . tshow) Right

mapDomainError :: Show problem => Either problem value -> Either Text value
mapDomainError = either (Left . tshow) Right

asObject :: Text -> Value -> Either Text Object
asObject name value = case value of
  Object result -> Right result
  _ -> Left (name <> " projection is not an object")

selectField :: Text -> Value -> Either Text Value
selectField field value = do
  objectValue <- asObject "relationship" value
  maybe (Left ("missing relationship field: " <> field)) Right
    (KeyMap.lookup (Key.fromText field) objectValue)

notDeepField :: Text -> Value -> Bool
notDeepField target value = case value of
  Object fields -> not (KeyMap.member (Key.fromText target) fields)
    && all (notDeepField target) (KeyMap.elems fields)
  Array values -> all (notDeepField target) values
  _ -> True

showText :: Show value => value -> Text
showText = Text.pack . show

tshow :: Show value => value -> Text
tshow = Text.pack . show

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 0

probeLater :: UTCTime
probeLater = addUTCTime 60 probeTime

infixl 1 &
(&) :: value -> (value -> result) -> result
value & function = function value

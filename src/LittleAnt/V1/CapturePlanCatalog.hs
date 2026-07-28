{-# LANGUAGE DerivingStrategies #-}

-- | Semantic Allium probes for routed capture and duplicate suspicion.
-- Registrations are keyed by semantic construct; obligation IDs are never
-- available to the probes.
module LittleAnt.V1.CapturePlanCatalog
  ( capturePlanProbes
  ) where

import Control.Monad (foldM, unless)
import Data.Aeson (encode, toJSON)
import Data.List (find, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.V1.Capture
import LittleAnt.V1.Contract (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Coordination (CoordinationState (..))
import LittleAnt.V1.Domain
  (Authority (..), Brick (..), BrickId, BrickStatus (..), BrickTemplate,
   DecompositionCoverage (..), DomainError, DomainState (..), ListEntry (..),
   ListEntryDraft (..), ListEntryStatus (..), behaviorId, canonicalEnglishText,
   initialDefinitionCatalog, mkCanonicalText, ordinaryBrickDraft, standardV1,
   standingChecklistV1, templateId, templateVersions)
import LittleAnt.V1.Execution (ExecutionState (..))
import LittleAnt.V1.Material
  (MaterialError, MaterialState (..), Raw (..), RawLink (..), RawLinkRole (..),
   RawReviewState (..), captureInlineRaw, emptyMaterialState,
   registerMaterialBrick, registerMaterialListEntry)
import qualified LittleAnt.V1.Priority as Priority
import LittleAnt.V1.Standing
  (StandingError, StandingState (..), addStandingListEntry,
   completeStandingBrick, createStandingBrick, emptyStandingState,
   retireStandingTarget)

capturePlanProbes :: Map ProbeKey PlanProbe
capturePlanProbes = Map.fromList
  (shapeRegistrations <> ruleRegistrations <> invariantRegistrations)

shapeRegistrations :: [(ProbeKey, PlanProbe)]
shapeRegistrations =
  [ registration category construct captureShapeProbe
  | (category, constructs) <-
      [ ("enum_comparable",
          ["CaptureRoute", "CaptureStatus", "DuplicateTargetKind",
           "DuplicateDecisionKind"])
      , ("transition_edge", ["CaptureIntent.status"])
      , ("transition_rejected", ["CaptureIntent.status"])
      , ("transition_terminal", ["CaptureIntent.status"])
      , ("entity_fields",
          ["CaptureIntent", "DuplicateSuspicion", "DuplicateDecision",
           "DuplicateMatch"])
      , ("entity_optional",
          [ "CaptureIntent.canonical_english"
          , "CaptureIntent.normalization_authority"
          , "CaptureIntent.proposed_route"
          , "CaptureIntent.proposed_parent"
          , "CaptureIntent.proposed_owner"
          , "CaptureIntent.proposed_behavior"
          , "CaptureIntent.proposed_template"
          , "DuplicateSuspicion.target_brick"
          , "DuplicateSuspicion.target_entry"
          , "DuplicateSuspicion.target_raw"
          , "DuplicateDecision.suspicion"
          ])
      , ("derived", ["DuplicateSuspicion.match_view"])
      , ("value_equality", ["DuplicateMatch"])
      , ("contract_signature", ["DuplicateMatcher.rank"])
      ]
  , construct <- constructs
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concatMap registerRule
  [ ("CaptureIntentOpened", ["rule_success", "rule_failure", "rule_entity_creation"])
  , ("DeterministicDuplicateSuspicionsGenerated",
      ["rule_success", "rule_entity_creation"])
  , ("DuplicateReuseConfirmed",
      ["rule_success", "rule_failure", "rule_entity_creation"])
  , ("SeparateCaptureConfirmed",
      ["rule_success", "rule_failure", "rule_entity_creation"])
  , ("CaptureCancelled", ["rule_success", "rule_failure"])
  , ("ConfirmedCapturePreservedAsRaw",
      ["rule_success", "rule_entity_creation"])
  , ("ConfirmedCaptureCreatesPositionedBrick",
      ["rule_success", "rule_failure", "rule_entity_creation"])
  , ("ConfirmedCaptureCreatesListEntry",
      ["rule_success", "rule_failure", "rule_entity_creation"])
  , ("ConfirmedDuplicateEnrichesWithoutIdentityMerge",
      ["rule_success", "rule_failure", "rule_entity_creation"])
  ]
  where
    registerRule (construct, categories) =
      [registration category construct captureRulesProbe | category <- categories]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [registration "invariant" construct captureInvariantProbe
  | construct <-
      [ "DuplicateSuspicionHasOneTarget"
      , "OneDuplicateDecisionPerCapture"
      , "CaptureBindingsAreCanonical"
      ]
  ]

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "selection" category construct,
    semanticProbe category construct probe)

semanticProbe :: Text -> Text -> Either Text () -> PlanProbe
semanticProbe category construct probe input = do
  require (planProbeModule input == "selection")
    "capture probe received the wrong module"
  require (planProbeCategory input == category)
    "capture probe received the wrong category"
  require (planProbeSourceConstruct input == construct)
    "capture probe received the wrong semantic construct"
  probe

------------------------------------------------------------
-- Shape, transition, matcher, and invariant probes
------------------------------------------------------------

captureShapeProbe :: Either Text ()
captureShapeProbe = do
  fixture <- captureFixture
  let context = fixtureContext fixture
      optionalDraft = CaptureDraft "verbatim only" Nothing Nothing Nothing
        Nothing Nothing Nothing Nothing
  (optionalCapture, _, optionalState) <- capture
    (beginCapture optionalDraft probeTime context emptyCaptureState)
  require (captureIntentCanonicalEnglish optionalCapture == Nothing
      && captureIntentNormalizationAuthority optionalCapture == Nothing
      && captureIntentProposedRoute optionalCapture == Nothing
      && captureIntentProposedParent optionalCapture == Nothing
      && captureIntentProposedOwner optionalCapture == Nothing
      && captureIntentProposedBehavior optionalCapture == Nothing
      && captureIntentProposedTemplate optionalCapture == Nothing)
    "CaptureIntent optional fields do not accept null"
  (cancelled, cancelledState) <- capture
    (cancelCapture (captureIntentId optionalCapture) context optionalState)
  require (captureIntentStatus cancelled == CaptureCancelled)
    "pending_review-to-cancelled edge was not reachable"
  expectFailure (cancelCapture (captureIntentId optionalCapture) context cancelledState)
    "cancelled CaptureIntent had an outbound transition"
  let fullDraft = CaptureDraft "comprar leite" (Just "Buy milk") (Just Ai)
        (Just CreateListEntry) Nothing (Just (brickId (fixtureOwner fixture)))
        (Just standardV1) (Just (fixtureTemplate fixture))
  (fullCapture, suspicions, opened) <- capture
    (beginCapture fullDraft probeTime context emptyCaptureState)
  require (captureIntentStatus fullCapture == CapturePendingReview
      && captureIntentCanonicalEnglish fullCapture == Just "Buy milk"
      && captureIntentNormalizationAuthority fullCapture == Just Ai
      && captureIntentProposedRoute fullCapture == Just CreateListEntry
      && captureIntentProposedOwner fullCapture == Just (brickId (fixtureOwner fixture))
      && captureIntentProposedBehavior fullCapture == Just standardV1
      && captureIntentProposedTemplate fullCapture == Just (fixtureTemplate fixture))
    "CaptureIntent omits a declared non-null field"
  suspicion <- exactlyOne "entry DuplicateSuspicion" suspicions
  require (duplicateSuspicionTargetKind suspicion == DuplicateListEntry
      && duplicateSuspicionTargetBrick suspicion == Nothing
      && duplicateSuspicionTargetEntry suspicion
        == Just (listEntryId (fixtureEntry fixture))
      && duplicateSuspicionTargetRaw suspicion == Nothing
      && duplicateSuspicionStrength suspicion > 0
      && not (null (duplicateSuspicionReasons suspicion))
      && duplicateSuspicionMatchView suspicion == DuplicateMatch
        DuplicateListEntry Nothing (Just (listEntryId (fixtureEntry fixture))) Nothing
        (duplicateSuspicionStrength suspicion) (duplicateSuspicionReasons suspicion))
    "DuplicateSuspicion does not expose one typed target and its derived match_view"
  let ranked = duplicateMatcherRank context fullCapture
  require (ranked == sortOn (\match ->
      (negate (duplicateMatchStrength match), duplicateMatchTargetKind match)) ranked
      && ranked == duplicateMatcherRank context fullCapture
      && encode ranked == encode ranked)
    "DuplicateMatcher.rank is not deterministic, ordered, or structurally equal"
  (result, nextContext, routed) <- capture (confirmDuplicateDecision
    (captureIntentId fullCapture) (duplicateSuspicionId suspicion) DuplicateEnrich
    Human probeTime context opened)
  routedCapture <- lookupCapture (captureIntentId fullCapture) routed
  require (captureDecisionResultEnrichedTarget result
        == Just (duplicateSuspicionMatchView suspicion)
      && captureIntentStatus routedCapture == CaptureRouted)
    "pending_review-to-routed edge or DuplicateDecision fields failed"
  decision <- lookupDecision (captureDecisionResultDecision result) routed
  require (duplicateDecisionSuspicion decision == Just (duplicateSuspicionId suspicion)
      && duplicateDecisionDecision decision == DuplicateEnrich
      && duplicateDecisionAuthority decision == Human)
    "DuplicateDecision omits a declared field"
  expectFailure (cancelCapture (captureIntentId fullCapture) nextContext routed)
    "routed CaptureIntent had an outbound transition"
  require (toJSON (minBound :: CaptureRoute) /= toJSON (maxBound :: CaptureRoute)
      && toJSON (minBound :: CaptureStatus) /= toJSON (maxBound :: CaptureStatus)
      && toJSON (minBound :: DuplicateTargetKind)
        /= toJSON (maxBound :: DuplicateTargetKind)
      && toJSON (minBound :: DuplicateDecisionKind)
        /= toJSON (maxBound :: DuplicateDecisionKind))
    "capture enum encodings collide"
  require (all canonicalEnglishText (matchingFingerprints "  Buy\nMILKS!  "))
    "matching fingerprints are not rebuildable canonical text projections"
  capture (validateCaptureState nextContext routed)

captureInvariantProbe :: Either Text ()
captureInvariantProbe = do
  captureRulesProbe
  fixture <- captureFixture
  require (Priority.priorityScopeParent (fixtureRootScope fixture) == Nothing
      && Priority.priorityScopeId (fixtureRootScope fixture)
        == Priority.priorityRootScopeId
      && behaviorId standardV1 == "core/standard")
    "capture bindings are not canonical"

------------------------------------------------------------
-- Routed materialization and every declared rejection
------------------------------------------------------------

captureRulesProbe :: Either Text ()
captureRulesProbe = do
  fixture <- captureFixture
  let context0 = fixtureContext fixture
      owner = fixtureOwner fixture
      entry = fixtureEntry fixture
      baseState = emptyCaptureState

  -- CaptureIntentOpened requires paired normalization attribution and retains
  -- the exact submitted bytes rather than a cleaned substitute.
  let entryDraft = CaptureDraft "comprar leite" (Just "Buy milk") (Just Ai)
        (Just CreateListEntry) Nothing (Just (brickId owner)) Nothing Nothing
  (entryCapture, entrySuspicions, opened) <- capture
    (beginCapture entryDraft probeTime context0 baseState)
  require (captureIntentOriginalText entryCapture == "comprar leite"
      && not (null entrySuspicions))
    "BeginCapture did not preserve verbatim text or create deterministic suspicions"
  expectFailure (beginCapture (entryDraft
    {captureDraftNormalizationAuthority = Nothing}) probeTime context0 baseState)
    "canonical English without authority was accepted"
  expectFailure (beginCapture (entryDraft
    {captureDraftCanonicalEnglish = Nothing}) probeTime context0 baseState)
    "normalization authority without canonical English was accepted"
  expectFailure (beginCapture (entryDraft
    {captureDraftCanonicalEnglish = Just " invalid "}) probeTime context0 baseState)
    "invalid canonical English was accepted"

  suspicion <- exactlyOne "Milk suspicion" entrySuspicions
  selected <- capture (selectDuplicateSuspicion (captureIntentId entryCapture)
    Nothing (Just (listEntryId entry)) Nothing opened)
  require (selected == suspicion) "typed duplicate selection was not deterministic"
  expectFailure (selectDuplicateSuspicion (captureIntentId entryCapture)
    (Just (brickId owner)) (Just (listEntryId entry)) Nothing opened)
    "duplicate selection accepted multiple target kinds"

  -- Both reuse and enrich are explicit decisions.  Enrichment preserves the
  -- entry identity, creates one reviewed Raw, and links that evidence once.
  (enriched, context1, routed) <- capture (confirmDuplicateDecision
    (captureIntentId entryCapture) (duplicateSuspicionId suspicion)
    DuplicateEnrich Human probeTime context0 opened)
  require (captureDecisionResultRaw enriched /= Nothing
      && captureDecisionResultEnrichedTarget enriched
        == Just (duplicateSuspicionMatchView suspicion)
      && Map.size (domainListEntries (captureDomain context1))
        == Map.size (domainListEntries (captureDomain context0))
      && Map.member (listEntryId entry) (domainListEntries (captureDomain context1)))
    "duplicate enrichment created a second entry or changed target identity"
  evidenceRaw <- maybe (Left "enrichment omitted Raw evidence") Right
    (captureDecisionResultRaw enriched)
  retainedRaw <- maybe (Left "enrichment Raw is absent") Right
    (Map.lookup evidenceRaw (materialRaws (captureContextMaterial context1)))
  require (rawOriginalText retainedRaw == Just "comprar leite"
      && rawReviewState retainedRaw == RawReviewedState
      && length [link | link <- Map.elems
          (materialLinks (captureContextMaterial context1)),
          rawLinkRaw link == evidenceRaw,
          rawLinkOwnerEntry link == Just (listEntryId entry),
          rawLinkRole link == Evidence] == 1)
    "enrichment did not retain reviewed verbatim Raw evidence on the entry"
  expectFailure (confirmDuplicateDecision (captureIntentId entryCapture)
    (duplicateSuspicionId suspicion) DuplicateEnrich Human probeTime context1 routed)
    "terminal capture accepted a second duplicate decision"
  expectFailure (confirmDuplicateDecision (captureIntentId entryCapture)
    (duplicateSuspicionId suspicion) DuplicateSeparate Human probeTime context0 opened)
    "duplicate confirmation accepted separate as a reuse decision"

  -- A suspicion from another capture is rejected even when it names the same
  -- target, so capture-local identity cannot become a global alias.
  (otherCapture, _, withOther) <- capture (beginCapture entryDraft probeTime context0 opened)
  expectFailure (confirmDuplicateDecision (captureIntentId otherCapture)
    (duplicateSuspicionId suspicion) DuplicateReuse Human probeTime context0 withOther)
    "capture accepted another capture's suspicion"

  -- Explicit separate preserve_raw creates exactly one pending active Raw.
  let rawDraft = CaptureDraft "nota original" Nothing Nothing (Just PreserveRaw)
        Nothing Nothing Nothing Nothing
  (rawCapture, _, rawOpened) <- capture
    (beginCapture rawDraft probeTime context0 emptyCaptureState)
  (rawResult, rawContext, rawRouted) <- capture (confirmSeparateCapture
    (captureIntentId rawCapture) Human probeTime context0 rawOpened)
  rawIdValue <- maybe (Left "preserve_raw omitted created Raw") Right
    (captureDecisionResultRaw rawResult)
  rawValue <- maybe (Left "preserved Raw disappeared") Right
    (Map.lookup rawIdValue (materialRaws (captureContextMaterial rawContext)))
  rawDecision <- lookupDecision (captureDecisionResultDecision rawResult) rawRouted
  require (rawOriginalText rawValue == Just "nota original"
      && rawReviewState rawValue == RawPending
      && captureDecisionResultBrick rawResult == Nothing
      && captureDecisionResultEntry rawResult == Nothing
      && duplicateDecisionSuspicion rawDecision == Nothing)
    "preserve_raw did not create exactly one canonical Raw decision outcome"

  -- create_brick and instantiate_template both create one active positioned
  -- Brick.  Template behavior/default description are immutable data inputs.
  let brickDraft = CaptureDraft "Criar tarefa" (Just "Create task") (Just Ai)
        (Just CreateBrick) Nothing Nothing (Just standardV1) Nothing
  (brickCapture, _, brickOpened) <- capture
    (beginCapture brickDraft probeTime context0 emptyCaptureState)
  (brickResult, brickContext, _) <- capture (confirmSeparateCapture
    (captureIntentId brickCapture) Human probeTime context0 brickOpened)
  createdBrick <- resultBrick brickResult brickContext
  require (brickOriginalTitle createdBrick == Just "Criar tarefa"
      && brickTitle createdBrick == "Create task"
      && priorityMembershipCount (brickId createdBrick) brickContext == 1)
    "create_brick omitted provenance or strict priority placement"

  let templateDraft = CaptureDraft "Lista de compras" (Just "Shopping list")
        (Just Ai) (Just InstantiateTemplate) Nothing Nothing Nothing
        (Just (fixtureTemplate fixture))
  (templateCapture, _, templateOpened) <- capture
    (beginCapture templateDraft probeTime context0 emptyCaptureState)
  (templateResult, templateContext, _) <- capture (confirmSeparateCapture
    (captureIntentId templateCapture) Human probeTime context0 templateOpened)
  templateBrick <- resultBrick templateResult templateContext
  require (behaviorIdOf templateBrick == "core/standing_checklist"
      && priorityMembershipCount (brickId templateBrick) templateContext == 1)
    "instantiate_template did not create one positioned behavior-bound Brick"

  -- Parent binding is validated and child creation reopens decomposition.
  let childDraft = brickDraft
        { captureDraftOriginalText = "Filho"
        , captureDraftCanonicalEnglish = Just "Child"
        , captureDraftProposedParent = Just (brickId owner)
        }
  (childCapture, _, childOpened) <- capture
    (beginCapture childDraft probeTime context0 emptyCaptureState)
  (childResult, childContext, _) <- capture (confirmSeparateCapture
    (captureIntentId childCapture) Human probeTime context0 childOpened)
  child <- resultBrick childResult childContext
  ownerAfter <- requireBrick (brickId owner) childContext
  require (brickParent child == Just (brickId owner)
      && brickDecompositionCoverage ownerAfter == Open
      && priorityMembershipCount (brickId child) childContext == 1)
    "parent route did not create exactly one positioned child or reopen decomposition"

  -- A list-entry route creates one owner-scoped occurrence with verbatim input.
  let separateEntryDraft = CaptureDraft "ovos" (Just "Eggs") (Just Ai)
        (Just CreateListEntry) Nothing (Just (brickId owner)) Nothing Nothing
  (separateEntryCapture, _, separateEntryOpened) <- capture
    (beginCapture separateEntryDraft probeTime context0 emptyCaptureState)
  (entryResult, entryContext, _) <- capture (confirmSeparateCapture
    (captureIntentId separateEntryCapture) Human probeTime context0
    separateEntryOpened)
  createdEntry <- maybe (Left "create_list_entry omitted its occurrence") Right
    (captureDecisionResultEntry entryResult >>= (`Map.lookup`
      domainListEntries (captureDomain entryContext)))
  require (listEntryOwner createdEntry == brickId owner
      && listEntryLabel createdEntry == "Eggs"
      && listEntryOriginalLabel createdEntry == Just "ovos"
      && listEntryStatus createdEntry == EntryOpen
      && priorityMembershipCount (brickId owner) entryContext == 1)
    "ListEntry route lost owner scope, language, or lightweight semantics"

  -- Cancellation is terminal and creates no decision or routed entity.
  (cancelIntent, _, cancelOpened) <- capture
    (beginCapture rawDraft probeTime context0 emptyCaptureState)
  (_, cancelled) <- capture
    (cancelCapture (captureIntentId cancelIntent) context0 cancelOpened)
  expectFailure (confirmSeparateCapture (captureIntentId cancelIntent) Human
    probeTime context0 cancelled) "cancelled capture was routed"

  captureRouteRejections fixture context0 brickDraft templateDraft
    separateEntryDraft
  captureTargetVariants fixture
  capture (validateCaptureState rawContext rawRouted)

-- Every requires-clause variant on confirmed Brick/ListEntry routing is
-- independently exercised here, including malformed replayed state that the
-- opening command itself would normally prevent from being stored.
captureRouteRejections ::
  CaptureFixture -> CaptureContext -> CaptureDraft -> CaptureDraft -> CaptureDraft ->
  Either Text ()
captureRouteRejections fixture context brickDraft templateDraft entryDraft = do
  let noRoute = brickDraft {captureDraftProposedRoute = Nothing}
  (noRouteCapture, _, noRouteState) <- capture
    (beginCapture noRoute probeTime context emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId noRouteCapture) Human
    probeTime context noRouteState) "separate capture without route was accepted"
  let enrichRoute = brickDraft {captureDraftProposedRoute = Just EnrichExisting}
  (enrichCapture, _, enrichState) <- capture
    (beginCapture enrichRoute probeTime context emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId enrichCapture) Human
    probeTime context enrichState) "enrich_existing was accepted without suspicion"

  let missingCanonical = brickDraft
        {captureDraftCanonicalEnglish = Nothing,
         captureDraftNormalizationAuthority = Nothing}
  (missingCapture, _, missingState) <- capture
    (beginCapture missingCanonical probeTime context emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId missingCapture) Human
    probeTime context missingState) "Brick route accepted missing canonical English"

  let noTemplate = templateDraft {captureDraftProposedTemplate = Nothing}
  (noTemplateCapture, _, noTemplateState) <- capture
    (beginCapture noTemplate probeTime context emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId noTemplateCapture) Human
    probeTime context noTemplateState) "template route accepted missing template"

  let noOwner = entryDraft {captureDraftProposedOwner = Nothing}
  (noOwnerCapture, _, noOwnerState) <- capture
    (beginCapture noOwner probeTime context emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId noOwnerCapture) Human
    probeTime context noOwnerState) "ListEntry route accepted missing owner"
  let unsupportedOwner = entryDraft
        {captureDraftProposedOwner = Just (brickId (fixtureOrdinary fixture))}
  (unsupportedCapture, _, unsupportedState) <- capture
    (beginCapture unsupportedOwner probeTime context emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId unsupportedCapture) Human
    probeTime context unsupportedState) "non-entry behavior accepted ListEntry"

  -- Complete ordinary and checklist owners through canonical standing
  -- lifecycle, then prove both parent/owner active requirements reject.
  terminalOrdinary <- standing (completeStandingBrick
    (brickId (fixtureOrdinary fixture)) Nothing "capture-probe:terminal-parent"
    probeTime (captureContextStanding context))
  let terminalOrdinaryContext = context {captureContextStanding = terminalOrdinary}
      terminalParentDraft = brickDraft
        {captureDraftProposedParent = Just (brickId (fixtureOrdinary fixture))}
  (terminalParent, _, terminalParentState) <- capture
    (beginCapture terminalParentDraft probeTime terminalOrdinaryContext emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId terminalParent) Human
    probeTime terminalOrdinaryContext terminalParentState)
    "terminal parent accepted a child route"

  terminalOwner <- standing (retireStandingTarget
    (brickId (fixtureOwner fixture)) probeTime (captureContextStanding context))
  let terminalOwnerContext = context {captureContextStanding = terminalOwner}
  (terminalEntry, _, terminalEntryState) <- capture
    (beginCapture entryDraft probeTime terminalOwnerContext emptyCaptureState)
  expectFailure (confirmSeparateCapture (captureIntentId terminalEntry) Human
    probeTime terminalOwnerContext terminalEntryState)
    "terminal owner accepted a ListEntry route"

  -- Route validation still rejects malformed persisted canonical fields even
  -- though BeginCapture normally prevents these states.
  (validCapture, _, validState) <- capture
    (beginCapture brickDraft probeTime context emptyCaptureState)
  let malformedIntent = validCapture
        {captureIntentCanonicalEnglish = Just " invalid "}
      malformedState = validState {captureStateIntents = Map.insert
        (captureIntentId validCapture) malformedIntent
        (captureStateIntents validState)}
  expectFailure (confirmSeparateCapture (captureIntentId validCapture) Human
    probeTime context malformedState) "malformed persisted canonical title was routed"
  let missingAuthorityIntent = validCapture
        {captureIntentNormalizationAuthority = Nothing}
      missingAuthorityState = validState {captureStateIntents = Map.insert
        (captureIntentId validCapture) missingAuthorityIntent
        (captureStateIntents validState)}
  expectFailure (confirmSeparateCapture (captureIntentId validCapture) Human
    probeTime context missingAuthorityState) "missing persisted title authority was routed"

  (validEntry, _, validEntryState) <- capture
    (beginCapture entryDraft probeTime context emptyCaptureState)
  let entryWithoutCanonical = validEntry
        {captureIntentCanonicalEnglish = Nothing}
      entryNoCanonicalState = validEntryState {captureStateIntents = Map.insert
        (captureIntentId validEntry) entryWithoutCanonical
        (captureStateIntents validEntryState)}
  expectFailure (confirmSeparateCapture (captureIntentId validEntry) Human
    probeTime context entryNoCanonicalState) "ListEntry accepted missing canonical label"
  let entryWithoutAuthority = validEntry
        {captureIntentNormalizationAuthority = Nothing}
      entryNoAuthorityState = validEntryState {captureStateIntents = Map.insert
        (captureIntentId validEntry) entryWithoutAuthority
        (captureStateIntents validEntryState)}
  expectFailure (confirmSeparateCapture (captureIntentId validEntry) Human
    probeTime context entryNoAuthorityState) "ListEntry accepted missing label authority"

-- Exercise all three conditional enrichment owners and both allowed decision
-- kinds.  This proves each branch creates retained evidence without aliasing.
captureTargetVariants :: CaptureFixture -> Either Text ()
captureTargetVariants fixture = do
  let context = fixtureContext fixture
      variants =
        [ ( CaptureDraft "Owner work" (Just "Owner work") (Just Human)
              (Just CreateBrick) Nothing Nothing Nothing Nothing
          , DuplicateBrick, Just (brickId (fixtureOrdinary fixture)), Nothing, Nothing
          )
        , ( CaptureDraft "source note" (Just "source note") (Just Human)
              (Just PreserveRaw) Nothing Nothing Nothing Nothing
          , DuplicateRaw, Nothing, Nothing, Just (rawId (fixtureRaw fixture))
          )
        ]
  _ <- foldM (exercise context) DuplicateReuse variants
  pure ()
  where
    exercise context decision (draft, expectedKind, brick, entry, raw) = do
      (intent, suspicions, state) <- capture
        (beginCapture draft probeTime context emptyCaptureState)
      suspicion <- maybe (Left "typed enrichment target was not suspected") Right
        (find (\candidate -> duplicateSuspicionTargetKind candidate == expectedKind
          && duplicateSuspicionTargetBrick candidate == brick
          && duplicateSuspicionTargetEntry candidate == entry
          && duplicateSuspicionTargetRaw candidate == raw) suspicions)
      (result, next, _) <- capture (confirmDuplicateDecision
        (captureIntentId intent) (duplicateSuspicionId suspicion) decision Human
        probeTime context state)
      evidence <- maybe (Left "typed enrichment omitted Raw") Right
        (captureDecisionResultRaw result)
      let links = Map.elems (materialLinks (captureContextMaterial next))
      require (case expectedKind of
          DuplicateBrick -> any (\link -> rawLinkRaw link == evidence
            && rawLinkOwnerBrick link == brick && rawLinkRole link == Evidence) links
          DuplicateListEntry -> any (\link -> rawLinkRaw link == evidence
            && rawLinkOwnerEntry link == entry && rawLinkRole link == Evidence) links
          DuplicateRaw -> any (\link -> Just (rawLinkRaw link) == raw
            && rawLinkOwnerRaw link == Just evidence
            && rawLinkRole link == DerivedFrom) links)
        "typed duplicate target did not receive the declared evidence link"
      pure DuplicateEnrich

------------------------------------------------------------
-- Fixture and helpers
------------------------------------------------------------

data CaptureFixture = CaptureFixture
  { fixtureContext :: CaptureContext
  , fixtureOwner :: Brick
  , fixtureOrdinary :: Brick
  , fixtureEntry :: ListEntry
  , fixtureRaw :: Raw
  , fixtureTemplate :: BrickTemplate
  , fixtureRootScope :: Priority.PriorityScope
  }

captureFixture :: Either Text CaptureFixture
captureFixture = do
  ownerTitle <- domain (mkCanonicalText "Buy groceries" Nothing Human)
  (owner, _, first) <- standing (createStandingBrick
    (ordinaryBrickDraft ownerTitle standingChecklistV1 probeTime)
    "capture-fixture:owner" probeTime emptyStandingState)
  ordinaryTitle <- domain (mkCanonicalText "Owner work" Nothing Human)
  (ordinary, _, second) <- standing (createStandingBrick
    (ordinaryBrickDraft ordinaryTitle standardV1 probeTime)
    "capture-fixture:ordinary" probeTime first)
  milk <- domain (mkCanonicalText "Milk" (Just "leite") Ai)
  (entry, third) <- standing (addStandingListEntry
    (ListEntryDraft (brickId owner) milk Nothing Nothing probeTime) second)
  (raw, rawMaterial) <- material (captureInlineRaw "source note"
    (Just "source note") (Just Human) probeTime emptyMaterialState)
  let registered = registerMaterialListEntry (listEntryId entry)
        (registerMaterialBrick (brickId ordinary) Active
          (registerMaterialBrick (brickId owner) Active rawMaterial))
      context = CaptureContext third registered
      priority = executionStatePriority . coordinationStateExecution
        . standingStateCoordination $ third
  rootScope <- maybe (Left "canonical root priority scope is absent") Right
    (Map.lookup Priority.priorityRootScopeId (Priority.priorityStateScopes priority))
  template <- maybe (Left "grocery template fixture is absent") Right
    (find ((== "standard/grocery_list") . templateId)
      (templateVersions initialDefinitionCatalog))
  pure CaptureFixture
    { fixtureContext = context
    , fixtureOwner = owner
    , fixtureOrdinary = ordinary
    , fixtureEntry = entry
    , fixtureRaw = raw
    , fixtureTemplate = template
    , fixtureRootScope = rootScope
    }

captureDomain :: CaptureContext -> DomainState
captureDomain = executionStateDomain . coordinationStateExecution
  . standingStateCoordination . captureContextStanding

priorityMembershipCount :: BrickId -> CaptureContext -> Int
priorityMembershipCount identifier context = length
  [() | scope <- Map.elems (Priority.priorityStateScopes priority),
    identifier `elem` Priority.priorityScopeMembers scope]
  where
    priority = executionStatePriority . coordinationStateExecution
      . standingStateCoordination $ captureContextStanding context

resultBrick :: CaptureDecisionResult -> CaptureContext -> Either Text Brick
resultBrick result context = do
  identifier <- maybe (Left "capture result omitted Brick") Right
    (captureDecisionResultBrick result)
  requireBrick identifier context

requireBrick :: BrickId -> CaptureContext -> Either Text Brick
requireBrick identifier context = maybe (Left "routed Brick is absent") Right
  (Map.lookup identifier (domainBricks (captureDomain context)))

lookupCapture :: CaptureIntentId -> CaptureState -> Either Text CaptureIntent
lookupCapture identifier state = maybe (Left "capture probe lost CaptureIntent") Right
  (Map.lookup identifier (captureStateIntents state))

lookupDecision ::
  DuplicateDecisionId -> CaptureState -> Either Text DuplicateDecision
lookupDecision identifier state = maybe
  (Left "capture probe lost DuplicateDecision") Right
  (Map.lookup identifier (captureStateDecisions state))

behaviorIdOf :: Brick -> Text
behaviorIdOf = behaviorId . brickBehavior

exactlyOne :: Text -> [value] -> Either Text value
exactlyOne _ [value] = Right value
exactlyOne label values = Left (label <> " expected one value, found "
  <> Text.pack (show (length values)))

expectFailure :: Either problem value -> Text -> Either Text ()
expectFailure result problem = case result of
  Left _ -> Right ()
  Right _ -> Left problem

capture :: Either CaptureError value -> Either Text value
capture = either (Left . Text.pack . show) Right

standing :: Either StandingError value -> Either Text value
standing = either (Left . Text.pack . show) Right

material :: Either MaterialError value -> Either Text value
material = either (Left . Text.pack . show) Right

domain :: Either DomainError value -> Either Text value
domain = either (Left . Text.pack . show) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 0

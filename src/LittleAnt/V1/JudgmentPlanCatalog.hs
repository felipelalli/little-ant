{-# LANGUAGE DerivingStrategies #-}

-- | Judgment-module conformance probes for strict human priority.
--
-- Registrations are semantic construct keys.  Each probe executes the typed
-- priority model; obligation identifiers are intentionally never inspected.
module LittleAnt.V1.JudgmentPlanCatalog
  ( priorityPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson (Value (..), encode, toJSON)
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
  (PlanProbe, PlanProbeInput (..), ProbeKey (..), selectJsonPath)
import LittleAnt.V1.Domain (Authority (Human), BrickId, BrickStatus (Done))
import LittleAnt.V1.Priority

priorityPlanProbes :: Map ProbeKey PlanProbe
priorityPlanProbes = Map.fromList
  ( enumRegistrations
  <> entityRegistrations
  <> optionalRegistrations
  <> derivedRegistrations
  <> transitionRegistrations
  <> valueRegistrations
  <> contractRegistrations
  <> configRegistrations
  <> ruleRegistrations
  <> invariantRegistrations
  <> surfaceRegistrations
  )

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ enumRegistration "PrioritySkipKind"
      (map toJSON [minBound .. maxBound :: PrioritySkipKind])
  , enumRegistration "InsertionStatus"
      (map toJSON [minBound .. maxBound :: InsertionStatus])
  , enumRegistration "RecalibrationStatus"
      (map toJSON [minBound .. maxBound :: PriorityRecalibrationStatus])
  , enumRegistration "JudgmentAxis"
      (map toJSON [minBound .. maxBound :: JudgmentAxis])
  , enumRegistration "ProbePurpose"
      (map toJSON [minBound .. maxBound :: ProbePurpose])
  , enumRegistration "JudgmentProbeStatus"
      (map toJSON [minBound .. maxBound :: JudgmentProbeStatus])
  ]

enumRegistration :: Text -> [Value] -> (ProbeKey, PlanProbe)
enumRegistration construct values = registration "enum_comparable" construct $ do
  require (not (null values)) "closed judgment enum is empty"
  require (Set.size (Set.fromList (map encode values)) == length values)
    "judgment enum encodings are not unique"
  require (all canonicalText values) "judgment enum encoding is not canonical text"
  where
    canonicalText (String value) = value == Text.toLower value
      && not (Text.null value)
    canonicalText _ = False

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ entityRegistration "PriorityScope"
      ["id", "parent", "members", "revision", "view"]
  , entityRegistration "PriorityInsertion"
      [ "id", "brick", "scope", "status", "current_candidate"
      , "comparisons_recorded", "consecutive_skips", "random_evidence"
      , "started_at", "finished_at"
      ]
  , entityRegistration "PriorityJudgment"
      [ "id", "scope", "scope_revision", "more_important", "less_important"
      , "authority", "recorded_at", "reason", "applicable", "is_current"
      , "evidence_view"
      ]
  , entityRegistration "PriorityComparisonSkip"
      ["id", "insertion", "candidate", "kind", "recorded_at"]
  , entityRegistration "PriorityRecalibration"
      [ "id", "scope", "segment", "proposed_order", "status", "created_at"
      , "resolved_at"
      ]
  , entityRegistration "JudgmentProbe"
      [ "id", "axis", "purpose", "scope", "left", "right", "reason"
      , "status", "created_at", "resolved_at"
      ]
  , entityRegistration "PriorityEvidenceView"
      [ "scope", "left", "right", "current_more_important", "confidence"
      , "confidence_reasons", "provisional"
      ]
  , entityRegistration "PriorityViewItem"
      [ "brick", "scope", "sibling_index", "tree_path", "confidence"
      , "confidence_reasons", "provisional"
      ]
  , entityRegistration "PriorityView"
      ["root_scope", "revision_fingerprint", "items"]
  ]

entityRegistration :: Text -> [Text] -> (ProbeKey, PlanProbe)
entityRegistration construct fields = registration "entity_fields" construct $ do
  value <- priorityFixtureValue construct
  objectValue <- asObject construct value
  let present = Set.fromList (map Key.toText (KeyMap.keys objectValue))
  require (all (`Set.member` present) fields)
    (construct <> " projection omits declared fields")
  checkEntityTypes construct objectValue

optionalRegistrations :: [(ProbeKey, PlanProbe)]
optionalRegistrations =
  [ optionalRegistration "PriorityScope.parent" rootScopeValue "parent"
  , optionalRegistration "PriorityInsertion.current_candidate"
      firstInsertionValue "current_candidate"
  , optionalRegistration "PriorityInsertion.finished_at"
      openInsertionValue "finished_at"
  , optionalRegistration "PriorityJudgment.reason" judgmentValue "reason"
  , optionalRegistration "PriorityRecalibration.resolved_at"
      recalibrationValue "resolved_at"
  , optionalRegistration "JudgmentProbe.scope" noScopeProbeValue "scope"
  , optionalRegistration "JudgmentProbe.resolved_at" probeValue "resolved_at"
  ]
  where
    rootScopeValue = priorityFixtureValue "PriorityScope"
    firstInsertionValue = samplePriority >>= \sample ->
      firstBy ((== InsertionResolved) . priorityInsertionStatus)
        (Map.elems (priorityStateInsertions (sampleState sample)))
        >>= Right . toJSON
    openInsertionValue = samplePriority >>= Right . toJSON . sampleOpenInsertion
    judgmentValue = samplePriority >>= Right . toJSON . sampleJudgment
    recalibrationValue = contradictionSample >>= Right . toJSON . contradictionRecalibration
    probeValue = do
      sample <- contradictionSample
      pure (toJSON ((contradictionProbe sample)
        { judgmentProbeStatus = ProbeOpen
        , judgmentProbeResolvedAt = Nothing
        }))
    noScopeProbeValue = do
      sample <- contradictionSample
      let probe = (contradictionProbe sample)
            { judgmentProbeAxis = ImpactAxis
            , judgmentProbeScope = Nothing
            , judgmentProbeStatus = ProbeOpen
            , judgmentProbeResolvedAt = Nothing
            }
      pure (toJSON probe)

optionalRegistration ::
  Text -> Either Text Value -> Text -> (ProbeKey, PlanProbe)
optionalRegistration construct fixture field = registration "entity_optional" construct $ do
  value <- fixture
  selected <- selectJsonPath field value
  require (selected == Null) (construct <> " does not expose absent optional state")

derivedRegistrations :: [(ProbeKey, PlanProbe)]
derivedRegistrations =
  [ derivedRegistration "PriorityScope.view" "PriorityScope" "view"
  , derivedRegistration "PriorityJudgment.is_current" "PriorityJudgment" "is_current"
  , derivedRegistration "PriorityJudgment.evidence_view"
      "PriorityJudgment" "evidence_view"
  ]

derivedRegistration ::
  Text -> Text -> Text -> (ProbeKey, PlanProbe)
derivedRegistration construct fixture path = registration "derived" construct $ do
  value <- priorityFixtureValue fixture
  selected <- selectJsonPath path value
  require (selected /= Null) (construct <> " derivation is absent")

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [ registration category construct transitionProbe
  | (category, construct) <-
      [ ("transition_edge", "PriorityInsertion.status")
      , ("transition_rejected", "PriorityInsertion.status")
      , ("transition_terminal", "PriorityInsertion.status")
      , ("when_presence", "PriorityRecalibration.resolved_at")
      , ("transition_edge", "PriorityRecalibration.status")
      , ("transition_rejected", "PriorityRecalibration.status")
      , ("transition_terminal", "PriorityRecalibration.status")
      , ("transition_edge", "JudgmentProbe.status")
      , ("transition_rejected", "JudgmentProbe.status")
      , ("transition_terminal", "JudgmentProbe.status")
      ]
  ]

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations =
  [ registration "value_equality" construct valueEqualityProbe
  | construct <- ["PriorityEvidenceView", "PriorityViewItem", "PriorityView"]
  ]

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "JudgmentDerivation.priority"
      projectionProbe
  , registration "contract_signature" "PriorityProjection.build"
      projectionProbe
  ]

configRegistrations :: [(ProbeKey, PlanProbe)]
configRegistrations =
  [ registration "config_default" "config.priority_nearby_distance" configProbe
  , registration "config_default" "config.priority_skip_limit" configProbe
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations =
  [ registration category construct priorityRulesProbe
  | construct <-
      [ "FirstRootBrickCreated"
      , "AdditionalRootBrickCreated"
      , "FirstChildBrickCreated"
      , "AdditionalChildBrickCreated"
      , "PriorityInsertionAnsweredYes"
      , "PriorityInsertionAnsweredNo"
      , "PriorityComparisonSkippedBeforeThreshold"
      , "PriorityComparisonSkippedAtThreshold"
      , "DeferredInsertionReopened"
      , "DirectPriorityJudgmentRecorded"
      , "PriorityProbeResolvedByJudgment"
      , "PriorityContradictionStartsRecalibration"
      , "CoherentPriorityRecalibrationCommitted"
      ]
  , category <- categoriesFor construct
  ]
  where
    categoriesFor construct
      | construct == "DeferredInsertionReopened" = ["rule_success", "rule_failure"]
      | construct == "PriorityProbeResolvedByJudgment" = ["rule_success"]
      | construct == "CoherentPriorityRecalibrationCommitted" =
          ["rule_success", "rule_failure"]
      | otherwise = ["rule_success", "rule_failure", "rule_entity_creation"]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" construct invariantProbe
  | construct <-
      [ "OnePriorityScopePerParent"
      , "PriorityScopeContainsNoDuplicates"
      , "EveryActiveBrickIsPositionedExactlyOnce"
      , "PriorityScopeMatchesComposition"
      , "TerminalBricksAreNotInActivePriority"
      , "PriorityJudgmentsAreSiblingOnly"
      , "PrioritySkipThresholdIsPositive"
      , "PriorityProbeIsSiblingScoped"
      , "JudgmentProbeComparesDistinctBricks"
      ]
  ]

surfaceRegistrations :: [(ProbeKey, PlanProbe)]
surfaceRegistrations =
  [ registration "surface_actor" "PriorityAndAssessmentDesk" surfaceProbe
  , registration "surface_exposure" "PriorityAndAssessmentDesk" surfaceProbe
  ]

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct action =
  ( ProbeKey "judgment" category construct
  , \input -> do
      checkMetadata category construct input
      action
  )

checkMetadata :: Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata category construct input = do
  require (planProbeModule input == "judgment") "probe received the wrong module"
  require (planProbeCategory input == category) "probe received the wrong category"
  require (planProbeSourceConstruct input == construct)
    "probe received the wrong source construct"

------------------------------------------------------------
-- Executable semantic probes
------------------------------------------------------------

transitionProbe :: Either Text ()
transitionProbe = do
  sample <- samplePriority
  let openInsertion = sampleOpenInsertion sample
  (firstSkip, _, skipped) <- mapPriorityError
    (skipPriorityComparison (priorityInsertionId openInsertion) Unresolved
      probeTime (sampleState sample))
  require (priorityInsertionStatus firstSkip == InsertionOpen)
    "first skip did not preserve an open insertion"
  (deferred, _, deferredState) <- mapPriorityError
    (skipPriorityComparison (priorityInsertionId firstSkip) Unresolved
      probeTime skipped)
  require (priorityInsertionStatus deferred == InsertionDeferred
      && priorityInsertionFinishedAt deferred /= Nothing)
    "threshold skip did not defer and finish the insertion round"
  (reopened, reopenedState) <- mapPriorityError
    (reopenPriorityInsertion (priorityInsertionId deferred) deferredState)
  require (priorityInsertionStatus reopened == InsertionOpen)
    "deferred insertion did not reopen"
  (resolved, _, resolvedState) <- resolveInsertion reopened reopenedState
  require (priorityInsertionStatus resolved == InsertionResolved)
    "reopened insertion did not resolve"
  case answerPriorityInsertion (priorityInsertionId resolved) True Human Nothing
      probeTime resolvedState of
    Left (InvalidPriorityTransition _) -> pure ()
    result -> Left ("terminal insertion accepted an answer: " <> tshow result)
  contradiction <- contradictionSample
  (resolvedRecalibration, final) <- mapPriorityError
    (commitPriorityRecalibration
      (priorityRecalibrationId (contradictionRecalibration contradiction))
      probeTime (contradictionState contradiction))
  require (priorityRecalibrationStatus resolvedRecalibration == RecalibrationResolved
      && priorityRecalibrationResolvedAt resolvedRecalibration /= Nothing)
    "recalibration did not reach its resolved terminal state"
  case commitPriorityRecalibration
      (priorityRecalibrationId resolvedRecalibration) probeTime final of
    Left (InvalidPriorityTransition _) -> pure ()
    result -> Left ("terminal recalibration accepted a second commit: " <> tshow result)
  probeSample <- contradictionSample
  let resolvedProbe = contradictionProbe probeSample
      reopenedProbe = resolvedProbe
        { judgmentProbeStatus = ProbeOpen
        , judgmentProbeResolvedAt = Nothing
        }
      probeState = (contradictionState probeSample)
        { priorityStateProbes = Map.insert (judgmentProbeId reopenedProbe)
            reopenedProbe (priorityStateProbes (contradictionState probeSample)) }
  (deferredProbe, deferredProbeState) <- mapPriorityError
    (deferJudgmentProbe (judgmentProbeId reopenedProbe) probeState)
  require (judgmentProbeStatus deferredProbe == ProbeDeferred)
    "open judgment probe did not defer"
  (openProbe, openProbeState) <- mapPriorityError
    (reopenJudgmentProbe (judgmentProbeId deferredProbe) deferredProbeState)
  require (judgmentProbeStatus openProbe == ProbeOpen)
    "deferred judgment probe did not reopen"
  (_, _, resolvedProbeState) <- mapPriorityError
    (recordPriorityJudgment priorityRootScopeId
      (judgmentProbeLeft openProbe) (judgmentProbeRight openProbe)
      Human Nothing probeTime openProbeState)
  let finalProbe = Map.lookup (judgmentProbeId openProbe)
        (priorityStateProbes resolvedProbeState)
  require (fmap judgmentProbeStatus finalProbe == Just ProbeResolved)
    "matching priority judgment did not resolve its probe"
  case reopenJudgmentProbe (judgmentProbeId openProbe) resolvedProbeState of
    Left (InvalidPriorityTransition _) -> pure ()
    result -> Left ("resolved judgment probe reopened: " <> tshow result)

valueEqualityProbe :: Either Text ()
valueEqualityProbe = do
  sample <- samplePriority
  evidence <- mapPriorityError (priorityEvidence (sampleState sample)
    priorityRootScopeId (sampleA sample) (sampleB sample))
  item <- mapPriorityError (priorityViewItem (sampleState sample) (sampleA sample))
  view <- mapPriorityError (priorityView (sampleState sample))
  require (evidence == evidence && item == item && view == view)
    "judgment values do not support structural equality"

projectionProbe :: Either Text ()
projectionProbe = do
  sample <- samplePriority
  view <- mapPriorityError (priorityView (sampleState sample))
  evidence <- mapPriorityError (priorityEvidence (sampleState sample)
    priorityRootScopeId (sampleA sample) (sampleB sample))
  require (length (priorityViewItems view) == Map.size
      (priorityStateBricks (sampleState sample)))
    "priority projection omitted an active Brick"
  require (priorityEvidenceContainsEquality evidence == False)
    "priority derivation invented equality"
  require (priorityEvidenceConfidence evidence >= 0
      && priorityEvidenceConfidence evidence <= 1)
    "priority confidence is outside its declared range"

configProbe :: Either Text ()
configProbe = do
  require (priorityStateNearbyDistance emptyPriorityState == 3)
    "priority nearby-distance default changed"
  require (priorityStateSkipLimit emptyPriorityState == 2)
    "priority skip-limit default changed"
  configured <- mapPriorityError (configurePriorityState 1 1 emptyPriorityState)
  require (priorityStateNearbyDistance configured == 1
      && priorityStateSkipLimit configured == 1)
    "positive priority overrides were not applied"
  case configurePriorityState 1 0 emptyPriorityState of
    Left (InvalidPriorityConfig _) -> pure ()
    result -> Left ("non-positive skip threshold was accepted: " <> tshow result)

priorityRulesProbe :: Either Text ()
priorityRulesProbe = do
  (firstRoot, firstInsertion, first) <- mapPriorityError
    (createPriorityRoot "Root A" "rules" probeTime emptyPriorityState)
  require (priorityInsertionStatus firstInsertion == InsertionResolved)
    "first root insertion was not immediately resolved"
  (secondRoot, secondInsertion, second) <- mapPriorityError
    (createPriorityRoot "Root B" "rules" probeTime first)
  require (priorityInsertionStatus secondInsertion == InsertionOpen)
    "additional root did not start binary insertion"
  (resolvedSecond, judgmentNo, third) <- mapPriorityError
    (answerPriorityInsertion (priorityInsertionId secondInsertion) False Human
      Nothing probeTime second)
  require (priorityInsertionStatus resolvedSecond == InsertionResolved
      && priorityJudgmentMoreImportant judgmentNo == priorityBrickId firstRoot)
    "no answer did not retain directional human evidence"
  (firstChild, firstChildInsertion, fourth) <- mapPriorityError
    (createPriorityChild (priorityBrickId firstRoot) "Child A" "rules"
      probeTime third)
  require (priorityInsertionStatus firstChildInsertion == InsertionResolved)
    "first child was not immediately positioned"
  (_, secondChildInsertion, fifth) <- mapPriorityError
    (createPriorityChild (priorityBrickId firstRoot) "Child B" "rules"
      probeTime fourth)
  (resolvedChild, judgmentYes, sixth) <- mapPriorityError
    (answerPriorityInsertion (priorityInsertionId secondChildInsertion) True Human
      Nothing probeTime fifth)
  require (priorityInsertionStatus resolvedChild == InsertionResolved
      && priorityJudgmentLessImportant judgmentYes == priorityBrickId firstChild)
    "yes answer did not place the new child deterministically"
  case createPriorityChild (priorityBrickId secondRoot) "" "rules" probeTime sixth of
    Left (InvalidPriorityRelationship _) -> pure ()
    result -> Left ("empty canonical title was accepted: " <> tshow result)
  sample <- samplePriority
  let insertion = sampleOpenInsertion sample
      beforeJudgments = Map.size (priorityStateJudgments (sampleState sample))
  (skippedOnce, firstSkip, seventh) <- mapPriorityError
    (skipPriorityComparison (priorityInsertionId insertion) Unresolved
      probeTime (sampleState sample))
  require (priorityInsertionStatus skippedOnce == InsertionOpen
      && priorityInsertionCurrentCandidate skippedOnce
        /= Just (priorityComparisonSkipCandidate firstSkip)
      && Map.size (priorityStateJudgments seventh) == beforeJudgments)
    "first skip stored an answer or failed to choose a distinct candidate"
  (deferred, _, eighth) <- mapPriorityError
    (skipPriorityComparison (priorityInsertionId skippedOnce) Unresolved
      probeTime seventh)
  require (priorityInsertionStatus deferred == InsertionDeferred
      && priorityProposalKinds eighth (priorityInsertionBrick deferred)
        == ["priority_probe"])
    "threshold skip did not retain provisional investigation pressure"
  (reopened, _) <- mapPriorityError
    (reopenPriorityInsertion (priorityInsertionId deferred) eighth)
  require (priorityInsertionStatus reopened == InsertionOpen)
    "deferred insertion did not reopen"
  contradiction <- contradictionSample
  let recalibration = contradictionRecalibration contradiction
      evidenceState = contradictionState contradiction
      evidence = priorityEvidence evidenceState priorityRootScopeId
        (contradictionA contradiction) (contradictionC contradiction)
  derived <- mapPriorityError evidence
  require (priorityEvidenceConfidence derived < contradictionConfidenceBefore contradiction)
    "contradiction did not lower derived confidence"
  require (priorityRecalibrationSegment recalibration ==
      [contradictionA contradiction, contradictionB contradiction,
       contradictionC contradiction])
    "contradiction did not choose the smallest affected segment"
  (_, committed) <- mapPriorityError (commitPriorityRecalibration
    (priorityRecalibrationId recalibration) probeTime evidenceState)
  root <- requireRoot committed
  require (last (priorityScopeMembers root) == contradictionD contradiction)
    "local recalibration moved an unrelated tail"
  mapPriorityError (validatePriorityState committed)

invariantProbe :: Either Text ()
invariantProbe = do
  sample <- samplePriority
  mapPriorityError (validatePriorityState (sampleState sample))
  let before = priorityScopeMembers <$> Map.lookup priorityRootScopeId
        (priorityStateScopes (sampleState sample))
  withDependency <- mapPriorityError
    (recordPriorityDependency (sampleA sample) (sampleB sample) (sampleState sample))
  let after = priorityScopeMembers <$> Map.lookup priorityRootScopeId
        (priorityStateScopes withDependency)
  require (before == after) "dependency edge rewrote human importance"
  (_, terminal) <- mapPriorityError
    (setPriorityBrickStatus (sampleB sample) Done probeTime withDependency)
  require (all (notElem (sampleB sample) . priorityScopeMembers)
      (Map.elems (priorityStateScopes terminal)))
    "terminal Brick remained in active priority"
  mapPriorityError (validatePriorityState terminal)

surfaceProbe :: Either Text ()
surfaceProbe = do
  sample <- samplePriority
  root <- requireRoot (sampleState sample)
  view <- mapPriorityError (priorityView (sampleState sample))
  require (priorityScopeId root == priorityViewRootScope view)
    "priority desk does not expose the user's root priority view"

------------------------------------------------------------
-- Probe fixtures
------------------------------------------------------------

data PrioritySample = PrioritySample
  { sampleState :: PriorityState
  , sampleA :: BrickId
  , sampleB :: BrickId
  , sampleC :: BrickId
  , sampleOpenInsertion :: PriorityInsertion
  , sampleJudgment :: PriorityJudgment
  }
  deriving stock (Eq, Show)

samplePriority :: Either Text PrioritySample
samplePriority = do
  (byTitle, base) <- mapPriorityError (createStrictRootFixture
    ["A", "B"] [("A", "B")] "sample" probeTime emptyPriorityState)
  a <- named "A" byTitle
  b <- named "B" byTitle
  (cBrick, insertion, state) <- mapPriorityError
    (createPriorityRoot "C" "sample" probeTime base)
  judgment <- firstBy (\item ->
      priorityJudgmentMoreImportant item == a
      && priorityJudgmentLessImportant item == b)
    (Map.elems (priorityStateJudgments state))
  pure PrioritySample
    { sampleState = state
    , sampleA = a
    , sampleB = b
    , sampleC = priorityBrickId cBrick
    , sampleOpenInsertion = insertion
    , sampleJudgment = judgment
    }

data ContradictionSample = ContradictionSample
  { contradictionState :: PriorityState
  , contradictionA :: BrickId
  , contradictionB :: BrickId
  , contradictionC :: BrickId
  , contradictionD :: BrickId
  , contradictionProbe :: JudgmentProbe
  , contradictionRecalibration :: PriorityRecalibration
  , contradictionConfidenceBefore :: Double
  }
  deriving stock (Eq, Show)

contradictionSample :: Either Text ContradictionSample
contradictionSample = do
  (byTitle, ordered) <- mapPriorityError (createStrictRootFixture
    ["A", "B", "C", "D"] [("A", "B"), ("B", "C")]
    "contradiction" probeTime emptyPriorityState)
  a <- named "A" byTitle
  b <- named "B" byTitle
  c <- named "C" byTitle
  d <- named "D" byTitle
  before <- mapPriorityError (priorityEvidence ordered priorityRootScopeId a c)
  (probe, withProbe) <- mapPriorityError
    (openPriorityProbe priorityRootScopeId a c Validation
      "test transitive edge" probeTime ordered)
  (_, recalibration, state) <- mapPriorityError
    (recordPriorityJudgment priorityRootScopeId c a Human
      (Just "new evidence") probeTime withProbe)
  selected <- maybe (Left "contradiction did not open recalibration") Right recalibration
  resolvedProbe <- maybe (Left "priority probe disappeared") Right
    (Map.lookup (judgmentProbeId probe) (priorityStateProbes state))
  pure ContradictionSample
    { contradictionState = state
    , contradictionA = a
    , contradictionB = b
    , contradictionC = c
    , contradictionD = d
    , contradictionProbe = resolvedProbe
    , contradictionRecalibration = selected
    , contradictionConfidenceBefore = priorityEvidenceConfidence before
    }

priorityFixtureValue :: Text -> Either Text Value
priorityFixtureValue construct = do
  sample <- samplePriority
  case construct of
    "PriorityScope" -> mapPriorityError
      (priorityScopeProjection (sampleState sample) priorityRootScopeId)
    "PriorityInsertion" -> pure (toJSON (sampleOpenInsertion sample))
    "PriorityJudgment" -> mapPriorityError (priorityJudgmentProjection
      (sampleState sample) (priorityJudgmentId (sampleJudgment sample)))
    "PriorityComparisonSkip" -> do
      (_, skipped, _) <- mapPriorityError (skipPriorityComparison
        (priorityInsertionId (sampleOpenInsertion sample)) Unresolved
        probeTime (sampleState sample))
      pure (toJSON skipped)
    "PriorityRecalibration" -> toJSON . contradictionRecalibration
      <$> contradictionSample
    "JudgmentProbe" -> toJSON . contradictionProbe <$> contradictionSample
    "PriorityEvidenceView" -> toJSON <$> mapPriorityError
      (priorityEvidence (sampleState sample) priorityRootScopeId
        (sampleA sample) (sampleB sample))
    "PriorityViewItem" -> toJSON <$> mapPriorityError
      (priorityViewItem (sampleState sample) (sampleA sample))
    "PriorityView" -> toJSON <$> mapPriorityError (priorityView (sampleState sample))
    _ -> Left ("no priority fixture for: " <> construct)

checkEntityTypes :: Text -> KeyMap.KeyMap Value -> Either Text ()
checkEntityTypes construct fields = case construct of
  "PriorityScope" -> requireArray "members" >> requireNumber "revision"
  "PriorityInsertion" -> requireString "status" >> requireNumber "consecutive_skips"
  "PriorityJudgment" -> requireString "authority" >> requireBool "applicable"
  "PriorityComparisonSkip" -> requireString "kind"
  "PriorityRecalibration" -> requireArray "segment" >> requireString "status"
  "JudgmentProbe" -> requireString "axis" >> requireString "purpose"
  "PriorityEvidenceView" -> requireNumber "confidence" >> requireBool "provisional"
  "PriorityViewItem" -> requireArray "tree_path" >> requireNumber "sibling_index"
  "PriorityView" -> requireArray "items" >> requireString "revision_fingerprint"
  _ -> Left ("unknown priority entity fixture: " <> construct)
  where
    field name = maybe (Left ("missing field: " <> name)) Right
      (KeyMap.lookup (Key.fromText name) fields)
    requireString name = field name >>= \case
      String _ -> Right ()
      _ -> Left (name <> " must be text")
    requireNumber name = field name >>= \case
      Number _ -> Right ()
      _ -> Left (name <> " must be numeric")
    requireArray name = field name >>= \case
      Array _ -> Right ()
      _ -> Left (name <> " must be an array")
    requireBool name = field name >>= \case
      Bool _ -> Right ()
      _ -> Left (name <> " must be Boolean")

resolveInsertion ::
  PriorityInsertion -> PriorityState ->
  Either Text (PriorityInsertion, PriorityJudgment, PriorityState)
resolveInsertion insertion state = do
  (next, judgment, nextState) <- mapPriorityError
    (answerPriorityInsertion (priorityInsertionId insertion) False Human Nothing
      probeTime state)
  if priorityInsertionStatus next == InsertionResolved
    then pure (next, judgment, nextState)
    else resolveInsertion next nextState

requireRoot :: PriorityState -> Either Text PriorityScope
requireRoot state = maybe (Left "root priority scope is absent") Right
  (Map.lookup priorityRootScopeId (priorityStateScopes state))

firstBy :: (value -> Bool) -> [value] -> Either Text value
firstBy predicate values = maybe (Left "expected probe fixture value is absent") Right
  (find predicate values)

named :: Text -> Map Text BrickId -> Either Text BrickId
named title values = maybe (Left ("missing fixture title: " <> title)) Right
  (Map.lookup title values)

asObject :: Text -> Value -> Either Text (KeyMap.KeyMap Value)
asObject _ (Object value) = Right value
asObject name _ = Left (name <> " projection is not an object")

mapPriorityError :: Either PriorityError value -> Either Text value
mapPriorityError = either (Left . tshow) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

tshow :: Show value => value -> Text
tshow = Text.pack . show

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 0

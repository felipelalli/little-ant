{-# LANGUAGE DerivingStrategies #-}

-- | Conformance probes for impact, effort, and shared judgment correction.
-- Registrations use semantic construct metadata and execute the real model;
-- obligation IDs are never available to the probes.
module LittleAnt.V1.JudgmentAssessmentPlanCatalog
  ( assessmentPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson (Value (..), encode, toJSON)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..), selectJsonPath)
import LittleAnt.V1.Domain
  (Authority (..), BrickId (..), BrickStatus (..),
   DecompositionCoverage (..))
import LittleAnt.V1.Judgment
import LittleAnt.V1.Priority
  (JudgmentProbe (..), JudgmentProbeStatus (..), ProbePurpose (..))

assessmentPlanProbes :: Map ProbeKey PlanProbe
assessmentPlanProbes = Map.fromList
  (enumRegistrations <> entityRegistrations <> optionalRegistrations
    <> derivedRegistrations <> valueRegistrations <> contractRegistrations
    <> configRegistrations <> ruleRegistrations <> invariantRegistrations
    <> surfaceRegistrations)

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ enumRegistration "ImpactClass" (map toJSON [minBound .. maxBound :: ImpactClass])
  , enumRegistration "ImpactMaturity"
      (map toJSON [minBound .. maxBound :: ImpactMaturity])
  , enumRegistration "RelativeAssessment"
      (map toJSON [minBound .. maxBound :: RelativeAssessment])
  , enumRegistration "EffortComparison"
      (map toJSON [minBound .. maxBound :: EffortComparison])
  ]

enumRegistration :: Text -> [Value] -> (ProbeKey, PlanProbe)
enumRegistration construct values = registration "enum_comparable" construct $ do
  require (not (null values)) "closed assessment enum is empty"
  require (Set.size (Set.fromList (map encode values)) == length values)
    "assessment enum values are not unique"
  require (all isText values) "assessment enum value is not canonical text"
  where
    isText (String value) = not (Text.null value)
    isText _ = False

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ entityRegistration "ImpactAssessment"
      ["id", "root", "impact", "maturity", "authority", "reason",
       "recorded_at", "applicable", "is_current", "evidence_view"]
  , entityRegistration "ImpactComparison"
      ["id", "left", "right", "result", "authority", "reason",
       "recorded_at", "applicable", "is_current"]
  , entityRegistration "EffortProfile" ["id", "version", "name"]
  , entityRegistration "EffortBand"
      ["id", "profile", "ordinal", "macro", "optimistic_hours",
       "realistic_hours", "pessimistic_hours"]
  , entityRegistration "EffortAssessment"
      ["id", "brick", "band", "authority", "provisional", "reason",
       "recorded_at", "applicable", "is_current", "evidence_view",
       "remaining_view"]
  , entityRegistration "EffortComparisonEvidence"
      ["id", "subject", "exemplar", "result", "authority", "recorded_at",
       "applicable", "is_current"]
  , entityRegistration "ScopeRevision"
      ["id", "brick", "reason", "authority", "confirmed_at"]
  , entityRegistration "ImpactEvidenceView"
      ["root", "current", "reliability_reasons", "needs_validation"]
  , entityRegistration "EffortEvidenceView"
      ["brick", "current", "confidence_reasons", "needs_validation"]
  , entityRegistration "RemainingEffortProjection"
      ["brick", "effort_profile", "total_band", "optimistic_hours",
       "realistic_hours", "pessimistic_hours", "evidence",
       "confidence_reasons"]
  ]

entityRegistration :: Text -> [Text] -> (ProbeKey, PlanProbe)
entityRegistration construct fields = registration "entity_fields" construct $ do
  value <- assessmentFixtureValue construct
  objectValue <- asObject construct value
  let present = Set.fromList (map Key.toText (KeyMap.keys objectValue))
  require (all (`Set.member` present) fields)
    (construct <> " projection omits declared fields")
  checkTypes construct objectValue

optionalRegistrations :: [(ProbeKey, PlanProbe)]
optionalRegistrations =
  [ optionalRegistration "ImpactAssessment.reason" "ImpactAssessment" "reason"
  , optionalRegistration "ImpactComparison.reason" "ImpactComparison" "reason"
  , optionalRegistration "EffortAssessment.reason" "EffortAssessment" "reason"
  ]

optionalRegistration :: Text -> Text -> Text -> (ProbeKey, PlanProbe)
optionalRegistration construct fixture field = registration "entity_optional" construct $ do
  value <- assessmentFixtureValue fixture
  selected <- selectJsonPath field value
  require (selected == Null) (construct <> " does not expose absent optional state")

derivedRegistrations :: [(ProbeKey, PlanProbe)]
derivedRegistrations =
  [ derivedRegistration "ImpactAssessment.is_current" "ImpactAssessment" "is_current"
  , derivedRegistration "ImpactAssessment.evidence_view" "ImpactAssessment" "evidence_view"
  , derivedRegistration "ImpactComparison.is_current" "ImpactComparison" "is_current"
  , derivedRegistration "EffortAssessment.is_current" "EffortAssessment" "is_current"
  , derivedRegistration "EffortAssessment.evidence_view" "EffortAssessment" "evidence_view"
  , derivedRegistration "EffortAssessment.remaining_view" "EffortAssessment" "remaining_view"
  , derivedRegistration "EffortComparisonEvidence.is_current"
      "EffortComparisonEvidence" "is_current"
  ]

derivedRegistration :: Text -> Text -> Text -> (ProbeKey, PlanProbe)
derivedRegistration construct fixture field = registration "derived" construct $ do
  value <- assessmentFixtureValue fixture
  selected <- selectJsonPath field value
  require (selected /= Null) (construct <> " derivation is absent")

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations =
  [ registration "value_equality" construct valueProbe
  | construct <- ["ImpactEvidenceView", "EffortEvidenceView",
      "RemainingEffortProjection"]
  ]

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "JudgmentDerivation.impact" derivationProbe
  , registration "contract_signature" "JudgmentDerivation.effort" derivationProbe
  , registration "contract_signature" "JudgmentDerivation.remaining_effort"
      derivationProbe
  ]

configRegistrations :: [(ProbeKey, PlanProbe)]
configRegistrations =
  [registration "config_default" "config.effort_assistance_limit" configProbe]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ rulesFor impactRulesProbe
      [ ("ImpactClassified", ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("ContradictoryImpactAssessmentStartsRecalibration",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("ImpactCompared", ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("ImpactProbeResolvedByComparison", ["rule_success"])
      , ("ContradictoryImpactComparisonStartsRecalibration",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("ImpactMaturityExplicitlyRevised",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      ]
  , rulesFor effortRulesProbe
      [ ("EffortClassified", ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("ContradictoryEffortAssessmentStartsRecalibration",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("EffortComparedWithExemplar",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      , ("EffortProbeResolvedByComparison", ["rule_success"])
      , ("ContradictoryEffortComparisonStartsRecalibration",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      ]
  , rulesFor lifecycleRulesProbe
      [ ("JudgmentProbeDeferred", ["rule_success", "rule_failure"])
      , ("JudgmentProbeReopened", ["rule_success", "rule_failure"])
      , ("TerminalBrickResolvesPendingJudgmentProbes", ["rule_success"])
      , ("DecompositionCoverageConfirmed", ["rule_success", "rule_failure"])
      , ("ScopeRevisionConfirmed",
          ["rule_success", "rule_failure", "rule_entity_creation"])
      ]
  ]
  where
    rulesFor probe constructs =
      [registration category construct probe |
        (construct, categories) <- constructs, category <- categories]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" construct invariantProbe
  | construct <-
      [ "ImpactProbeIsRootScoped"
      , "EffortProbeUsesApplicableBricks"
      , "ImpactIsRootScoped"
      , "EffortBandOrdinalIsUniqueWithinProfile"
      ]
  ]

surfaceRegistrations :: [(ProbeKey, PlanProbe)]
surfaceRegistrations =
  [registration "surface_provides" "PriorityAndAssessmentDesk" surfaceProbe]

registration :: Text -> Text -> Either Text () -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "judgment" category construct, \input -> do
    checkMetadata category construct input
    probe)

checkMetadata :: Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata category construct input = do
  require (planProbeModule input == "judgment") "probe received wrong module"
  require (planProbeCategory input == category) "probe received wrong category"
  require (planProbeSourceConstruct input == construct)
    "probe received wrong semantic construct"

------------------------------------------------------------
-- Executable semantics
------------------------------------------------------------

impactRulesProbe :: Either Text ()
impactRulesProbe = do
  sample <- assessmentSample
  let initial = sampleState sample
      rootA = sampleRootA sample
      rootB = sampleRootB sample
      child = sampleChild sample
  (first, _, firstState) <- mapJudgmentError
    (classifyImpact rootA HighImpact Supported Human Nothing probeTime initial)
  require (impactAssessmentRoot first == rootA) "root impact was not classified"
  case classifyImpact child LowImpact Speculative Human Nothing probeTime firstState of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("child impact classification was accepted: " <> tshow result)
  (second, _, secondState) <- mapJudgmentError
    (classifyImpact rootB LowImpact Supported Human Nothing probeTime firstState)
  require (impactAssessmentImpact second == LowImpact) "second impact is absent"
  (validationProbe, withProbe) <- mapJudgmentError
    (openImpactProbe rootA rootB Validation "validate impact" probeTime secondState)
  (_, contradictoryProbe, compared) <- mapJudgmentError
    (compareImpact rootA rootB RelativelyLess Human Nothing probeTime withProbe)
  require (contradictoryProbe /= Nothing)
    "contradictory impact comparison did not open recalibration"
  let resolvedValidation = Map.lookup (judgmentProbeId validationProbe)
        (judgmentStateProbes compared)
  require (fmap judgmentProbeStatus resolvedValidation == Just ProbeResolved)
    "impact comparison did not resolve its matching probe"
  beforeCount <- pure (Map.size (judgmentStateImpactComparisons compared))
  (_, _, comparedAgain) <- mapJudgmentError
    (compareImpact rootA rootB RelativelyMore Ai Nothing probeTime compared)
  require (Map.size (judgmentStateImpactComparisons comparedAgain) == beforeCount + 1)
    "impact comparison history was overwritten"
  require (length (filter (\probe -> judgmentProbeStatus probe == ProbeOpen)
      (Map.elems (judgmentStateProbes comparedAgain))) == 1)
    "contradiction created duplicate simultaneously open recalibration probes"
  case compareImpact rootA rootA RelativelySimilar Human Nothing probeTime comparedAgain of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("self impact comparison was accepted: " <> tshow result)
  (revised, _, revisedState) <- mapJudgmentError
    (reviseImpactMaturity rootA Validated Human "purposeful validation"
      probeTime comparedAgain)
  require (impactAssessmentMaturity revised == Validated
      && Map.size (judgmentStateImpactAssessments revisedState) == 3)
    "explicit maturity revision did not append immutable evidence"
  case reviseImpactMaturity (sampleUnassessedRoot sample) Observed Human
      "missing baseline" probeTime initial of
    Left (InvalidJudgmentTransition _) -> pure ()
    result -> Left ("maturity without an assessment was accepted: " <> tshow result)
  case reviseImpactMaturity rootA Observed Human "" probeTime revisedState of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("reasonless maturity revision was accepted: " <> tshow result)
  view <- mapJudgmentError (impactEvidence revisedState rootA)
  require (length (impactEvidenceHistory view) >= 2)
    "impact current view deleted historical evidence"

effortRulesProbe :: Either Text ()
effortRulesProbe = do
  sample <- assessmentSample
  easy <- mapJudgmentError
    (effortBandById initialEffortProfile "EASY" (sampleState sample))
  hard <- mapJudgmentError
    (effortBandById initialEffortProfile "HARD" (sampleState sample))
  (first, _, firstState) <- mapJudgmentError
    (classifyEffort (sampleRootA sample) easy Human False Nothing probeTime
      (sampleState sample))
  require (effortAssessmentBand first == easy) "effort class was not retained"
  (_, _, secondState) <- mapJudgmentError
    (classifyEffort (sampleRootB sample) hard Human False Nothing probeTime firstState)
  case classifyEffort (sampleDisabled sample) easy Human False Nothing probeTime secondState of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("effort-disabled Brick was classified: " <> tshow result)
  (_, terminalState) <- mapJudgmentError
    (setJudgmentBrickStatus (sampleUnassessedRoot sample) Done probeTime secondState)
  case classifyEffort (sampleUnassessedRoot sample) easy Human False Nothing
      probeTime terminalState of
    Left (InvalidJudgmentTransition _) -> pure ()
    result -> Left ("terminal Brick effort was classified: " <> tshow result)
  (validationProbe, withProbe) <- mapJudgmentError
    (openEffortProbe (sampleRootA sample) (sampleRootB sample) Validation
      "validate effort" probeTime secondState)
  (_, contradiction, compared) <- mapJudgmentError
    (compareEffort (sampleRootA sample) (sampleRootB sample) MuchMoreEffort Human
      probeTime withProbe)
  require (contradiction /= Nothing)
    "contradictory effort comparison did not open recalibration"
  require (fmap judgmentProbeStatus
      (Map.lookup (judgmentProbeId validationProbe) (judgmentStateProbes compared))
        == Just ProbeResolved)
    "effort comparison did not resolve matching probe"
  case compareEffort (sampleRootA sample) (sampleRootA sample) SimilarEffort Human
      probeTime compared of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("self effort comparison was accepted: " <> tshow result)
  case compareEffort (sampleRootA sample) (sampleDisabled sample) SimilarEffort Human
      probeTime compared of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("inapplicable effort exemplar was accepted: " <> tshow result)
  (_, _, withClassificationConflict) <- mapJudgmentError
    (classifyEffort (sampleRootA sample) hard Human False Nothing probeTime compared)
  require (not (null (judgmentProposalKinds withClassificationConflict
      (sampleRootA sample)))) "effort contradiction has no probe pressure"
  let drafts =
        [EffortBandDraft "SMALL" 1 "EFFORT_SMALL" 1 2 3,
         EffortBandDraft "LARGE" 2 "EFFORT_LARGE" 4 6 8]
  (profileV2, _, profileState) <- mapJudgmentError
    (publishEffortProfile "core/effort" 2 "Recalibrated" drafts compared)
  require (effortProfileVersion profileV2 == 2
      && Map.member "core/effort@1" (judgmentStateEffortProfiles profileState))
    "publishing effort calibration mutated the initial profile"
  case publishEffortProfile "core/effort" 2 "Mutated" drafts profileState of
    Left (InvalidEffortProfile _) -> pure ()
    result -> Left ("published effort version was mutated: " <> tshow result)
  case publishEffortProfile "personal/bad" 1 "Bad"
      [EffortBandDraft "A" 1 "A" 1 2 3,
       EffortBandDraft "B" 1 "B" 2 3 4] compared of
    Left (InvalidEffortProfile _) -> pure ()
    result -> Left ("duplicate effort ordinal was accepted: " <> tshow result)

lifecycleRulesProbe :: Either Text ()
lifecycleRulesProbe = do
  sample <- assessmentSample
  let initial = sampleState sample
      left = sampleRootA sample
      right = sampleRootB sample
  (probe, withProbe) <- mapJudgmentError
    (openImpactProbe left right Discovery "discover impact" probeTime initial)
  (deferred, deferredState) <- mapJudgmentError
    (deferAssessmentProbe (judgmentProbeId probe) withProbe)
  require (judgmentProbeStatus deferred == ProbeDeferred)
    "open judgment probe did not defer"
  case deferAssessmentProbe (judgmentProbeId deferred) deferredState of
    Left (InvalidJudgmentTransition _) -> pure ()
    result -> Left ("deferred probe deferred again: " <> tshow result)
  (reopened, reopenedState) <- mapJudgmentError
    (reopenAssessmentProbe (judgmentProbeId deferred) deferredState)
  require (judgmentProbeStatus reopened == ProbeOpen)
    "deferred judgment probe did not reopen"
  (_, terminalState) <- mapJudgmentError
    (setJudgmentBrickStatus right Done probeTime reopenedState)
  require (fmap judgmentProbeStatus
      (Map.lookup (judgmentProbeId reopened) (judgmentStateProbes terminalState))
        == Just ProbeResolved)
    "terminal Brick did not resolve pending probe"
  case reopenAssessmentProbe (judgmentProbeId reopened) terminalState of
    Left (InvalidJudgmentTransition _) -> pure ()
    result -> Left ("resolved probe reopened: " <> tshow result)
  (covered, coveredState) <- mapJudgmentError
    (confirmDecompositionCoverage (sampleParent sample) initial)
  require (judgmentBrickDecompositionCoverage covered == Complete)
    "open decomposition coverage was not confirmed"
  case confirmDecompositionCoverage (sampleUnassessedRoot sample) initial of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("childless decomposition was confirmed: " <> tshow result)
  case confirmDecompositionCoverage (sampleParent sample) coveredState of
    Left (InvalidJudgmentTransition _) -> pure ()
    result -> Left ("complete decomposition was reconfirmed: " <> tshow result)
  easy <- mapJudgmentError (effortBandById initialEffortProfile "EASY" initial)
  (_, _, evidenceState) <- mapJudgmentError
    (classifyEffort left easy Human False Nothing probeTime initial)
  (revision, revised) <- mapJudgmentError
    (confirmScopeRevision left "scope changed" Human probeTime evidenceState)
  require (scopeRevisionBrick revision == left
      && all (not . effortAssessmentApplicable)
        (Map.elems (judgmentStateEffortAssessments revised)))
    "scope revision did not retain and retire affected effort evidence"
  case confirmScopeRevision right "terminal" Human probeTime terminalState of
    Left (InvalidJudgmentTransition _) -> pure ()
    result -> Left ("terminal scope revision was accepted: " <> tshow result)

valueProbe :: Either Text ()
valueProbe = do
  sample <- assessmentSampleWithEvidence
  impact <- mapJudgmentError (impactEvidence (sampleState sample) (sampleRootA sample))
  effort <- mapJudgmentError (effortEvidence (sampleState sample) (sampleRootA sample))
  remaining <- mapJudgmentError (remainingEffortProjection (sampleState sample)
    (sampleRootA sample) initialEffortProfile)
  require (impact == impact && effort == effort && remaining == remaining)
    "assessment value types lack structural equality"

derivationProbe :: Either Text ()
derivationProbe = do
  sample <- assessmentSampleWithEvidence
  let state = sampleState sample
      root = sampleRootA sample
      absent = sampleUnassessedRoot sample
  impact <- mapJudgmentError (impactEvidence state root)
  effort <- mapJudgmentError (effortEvidence state root)
  remaining <- mapJudgmentError
    (remainingEffortProjection state root initialEffortProfile)
  lazyProjection <- mapJudgmentError (judgmentProjection state absent)
  require (impactEvidenceCurrent impact /= Nothing) "impact derivation lost current evidence"
  require (effortEvidenceCurrent effort /= Nothing) "effort derivation lost current evidence"
  require (remainingEffortTotalBand remaining /= Nothing)
    "remaining effort is disconnected from total effort"
  eligibility <- selectJsonPath "eligible_without_assessments" lazyProjection
  controls <- selectJsonPath "controls_eligibility" lazyProjection
  require (eligibility == Bool True && controls == Bool False)
    "absent optional assessments changed eligibility"

configProbe :: Either Text ()
configProbe = do
  require (judgmentStateEffortAssistanceLimit emptyJudgmentState == 3)
    "effort assistance default changed"
  configured <- mapJudgmentError (configureEffortAssistance 1 emptyJudgmentState)
  require (judgmentStateEffortAssistanceLimit configured == 1)
    "positive effort assistance override was ignored"
  case configureEffortAssistance 0 emptyJudgmentState of
    Left (InvalidEffortProfile _) -> pure ()
    result -> Left ("non-positive effort assistance was accepted: " <> tshow result)

invariantProbe :: Either Text ()
invariantProbe = do
  sample <- assessmentSampleWithEvidence
  mapJudgmentError (validateJudgmentState (sampleState sample))
  case openImpactProbe (sampleChild sample) (sampleRootB sample) Validation
      "invalid root probe" probeTime (sampleState sample) of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("non-root impact probe was accepted: " <> tshow result)
  case openEffortProbe (sampleRootA sample) (sampleDisabled sample) Validation
      "invalid effort probe" probeTime (sampleState sample) of
    Left (InvalidJudgmentRelationship _) -> pure ()
    result -> Left ("inapplicable effort probe was accepted: " <> tshow result)

surfaceProbe :: Either Text ()
surfaceProbe = do
  impactRulesProbe
  effortRulesProbe
  lifecycleRulesProbe

------------------------------------------------------------
-- Fixtures
------------------------------------------------------------

data AssessmentSample = AssessmentSample
  { sampleState :: JudgmentState
  , sampleRootA :: BrickId
  , sampleRootB :: BrickId
  , sampleUnassessedRoot :: BrickId
  , sampleDisabled :: BrickId
  , sampleParent :: BrickId
  , sampleChild :: BrickId
  }
  deriving stock (Eq, Show)

assessmentSample :: Either Text AssessmentSample
assessmentSample = do
  let rootA = BrickId "judgment-fixture:root-a"
      rootB = BrickId "judgment-fixture:root-b"
      unassessed = BrickId "judgment-fixture:unassessed"
      disabled = BrickId "judgment-fixture:disabled"
      parent = BrickId "judgment-fixture:parent"
      child = BrickId "judgment-fixture:child"
  first <- register rootA Nothing Active True emptyJudgmentState
  second <- register rootB Nothing Active True first
  third <- register unassessed Nothing Active True second
  fourth <- register disabled Nothing Active False third
  fifth <- register parent Nothing Active True fourth
  final <- register child (Just parent) Active True fifth
  pure AssessmentSample
    { sampleState = final
    , sampleRootA = rootA
    , sampleRootB = rootB
    , sampleUnassessedRoot = unassessed
    , sampleDisabled = disabled
    , sampleParent = parent
    , sampleChild = child
    }
  where
    register identifier parent status effort state =
      mapJudgmentError (registerJudgmentBrick identifier parent status effort state)

assessmentSampleWithEvidence :: Either Text AssessmentSample
assessmentSampleWithEvidence = do
  sample <- assessmentSample
  (_, _, first) <- mapJudgmentError
    (classifyImpact (sampleRootA sample) HighImpact Supported Human Nothing
      probeTime (sampleState sample))
  easy <- mapJudgmentError (effortBandById initialEffortProfile "EASY" first)
  (_, _, second) <- mapJudgmentError
    (classifyEffort (sampleRootA sample) easy Human False Nothing probeTime first)
  (_, third) <- mapJudgmentError
    (recordProgressEvidence (sampleRootA sample) ExplicitHumanProgress 0.25
      probeTime second)
  pure sample {sampleState = third}

assessmentFixtureValue :: Text -> Either Text Value
assessmentFixtureValue construct = do
  sample <- assessmentSampleWithEvidence
  let state = sampleState sample
      firstImpact = firstMapValue (judgmentStateImpactAssessments state)
      firstEffort = firstMapValue (judgmentStateEffortAssessments state)
  case construct of
    "ImpactAssessment" -> firstImpact >>= \value -> mapJudgmentError
      (impactAssessmentProjection state (impactAssessmentId value))
    "ImpactComparison" -> do
      (_, _, compared) <- mapJudgmentError
        (compareImpact (sampleRootA sample) (sampleRootB sample) RelativelyMore
          Human Nothing probeTime state)
      value <- firstMapValue (judgmentStateImpactComparisons compared)
      mapJudgmentError (impactComparisonProjection compared (impactComparisonId value))
    "EffortProfile" -> pure (toJSON initialEffortProfile)
    "EffortBand" -> pure (toJSON (headBand initialEffortBands))
    "EffortAssessment" -> firstEffort >>= \value -> mapJudgmentError
      (effortAssessmentProjection state (effortAssessmentId value))
    "EffortComparisonEvidence" -> do
      (_, _, classified) <- classifySecond sample state
      (_, _, compared) <- mapJudgmentError
        (compareEffort (sampleRootA sample) (sampleRootB sample) MuchLessEffort
          Human probeTime classified)
      value <- firstMapValue (judgmentStateEffortComparisons compared)
      mapJudgmentError (effortComparisonProjection compared
        (effortComparisonEvidenceId value))
    "ScopeRevision" -> do
      (revision, _) <- mapJudgmentError
        (confirmScopeRevision (sampleRootA sample) "fixture revision" Human
          probeTime state)
      pure (toJSON revision)
    "ImpactEvidenceView" -> toJSON <$> mapJudgmentError
      (impactEvidence state (sampleRootA sample))
    "EffortEvidenceView" -> toJSON <$> mapJudgmentError
      (effortEvidence state (sampleRootA sample))
    "RemainingEffortProjection" -> toJSON <$> mapJudgmentError
      (remainingEffortProjection state (sampleRootA sample) initialEffortProfile)
    _ -> Left ("no assessment fixture for: " <> construct)
  where
    classifySecond sample state = do
      hard <- mapJudgmentError (effortBandById initialEffortProfile "HARD" state)
      mapJudgmentError (classifyEffort (sampleRootB sample) hard Human False
        Nothing probeTime state)

checkTypes :: Text -> KeyMap.KeyMap Value -> Either Text ()
checkTypes construct fields = case construct of
  "ImpactAssessment" -> string "impact" >> string "maturity" >> bool "applicable"
  "ImpactComparison" -> string "result" >> bool "is_current"
  "EffortProfile" -> string "id" >> number "version"
  "EffortBand" -> objectValue "profile" >> number "ordinal" >> number "realistic_hours"
  "EffortAssessment" -> objectValue "band" >> bool "provisional" >> bool "is_current"
  "EffortComparisonEvidence" -> string "result" >> bool "applicable"
  "ScopeRevision" -> string "reason" >> string "authority"
  "ImpactEvidenceView" -> array "reliability_reasons" >> bool "needs_validation"
  "EffortEvidenceView" -> array "confidence_reasons" >> bool "needs_validation"
  "RemainingEffortProjection" -> objectValue "effort_profile" >> array "evidence"
  _ -> Left ("unknown assessment fixture type: " <> construct)
  where
    field name = maybe (Left ("missing field: " <> name)) Right
      (KeyMap.lookup (Key.fromText name) fields)
    string name = field name >>= \case String _ -> Right (); _ -> Left (name <> " must be text")
    number name = field name >>= \case Number _ -> Right (); _ -> Left (name <> " must be numeric")
    bool name = field name >>= \case Bool _ -> Right (); _ -> Left (name <> " must be Boolean")
    array name = field name >>= \case Array _ -> Right (); _ -> Left (name <> " must be an array")
    objectValue name = field name >>= \case Object _ -> Right (); _ -> Left (name <> " must be an object")

asObject :: Text -> Value -> Either Text (KeyMap.KeyMap Value)
asObject _ (Object value) = Right value
asObject name _ = Left (name <> " projection is not an object")

firstMapValue :: Map key value -> Either Text value
firstMapValue values = case Map.elems values of
  value : _ -> Right value
  [] -> Left "fixture map is empty"

headBand :: [EffortBand] -> EffortBand
headBand values = case values of
  value : _ -> value
  [] -> error "initial effort profile must contain bands"

mapJudgmentError :: Either JudgmentError value -> Either Text value
mapJudgmentError = either (Left . tshow) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

tshow :: Show value => value -> Text
tshow = Text.pack . show

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 0

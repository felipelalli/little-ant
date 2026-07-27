{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Lazy impact and effort judgments backed by immutable evidence.
--
-- Impact is root-scoped and effort is behavior-applicable.  Neither axis is an
-- eligibility or priority input: absent assessments remain neutral.  Current
-- views are rebuilt from retained evidence, while scope revisions only retire
-- applicability.
module LittleAnt.V1.Judgment
  ( EffortAssessment (..)
  , EffortAssessmentId (..)
  , EffortBand (..)
  , EffortBandDraft (..)
  , EffortComparison (..)
  , EffortComparisonEvidence (..)
  , EffortComparisonEvidenceId (..)
  , EffortEvidenceView (..)
  , EffortProfile (..)
  , ImpactAssessment (..)
  , ImpactAssessmentId (..)
  , ImpactClass (..)
  , ImpactComparison (..)
  , ImpactComparisonId (..)
  , ImpactEvidenceView (..)
  , ImpactMaturity (..)
  , JudgmentBrick (..)
  , JudgmentError (..)
  , JudgmentState (..)
  , ProgressEvidence (..)
  , ProgressEvidenceKind (..)
  , RelativeAssessment (..)
  , RemainingEffortProjection (..)
  , ScopeRevision (..)
  , ScopeRevisionId (..)
  , classifyEffort
  , classifyImpact
  , compareEffort
  , compareImpact
  , configureEffortAssistance
  , confirmDecompositionCoverage
  , confirmScopeRevision
  , currentEffortAssessment
  , currentImpactAssessment
  , deferAssessmentProbe
  , effortAssessmentProjection
  , effortBandById
  , effortComparisonProjection
  , effortEvidence
  , emptyJudgmentState
  , impactAssessmentProjection
  , impactComparisonProjection
  , impactEvidence
  , initialEffortBands
  , initialEffortProfile
  , judgmentProjection
  , judgmentProposalKinds
  , judgmentProbeProjection
  , openEffortProbe
  , openImpactProbe
  , publishEffortProfile
  , recordProgressEvidence
  , registerJudgmentBrick
  , remainingEffortProjection
  , reopenAssessmentProbe
  , reviseImpactMaturity
  , setJudgmentBrickStatus
  , validateJudgmentState
  ) where

import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey, Value,
   defaultOptions, genericParseJSON, genericToJSON, object, withText, (.=))
import qualified Data.Aeson.Types as AesonTypes
import Data.Char (toLower)
import Data.List (find, nub, sort, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (isJust)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain
  (Authority (..), BrickId, BrickStatus (..), DecompositionCoverage (..))
import LittleAnt.V1.Priority
  (JudgmentAxis (..), JudgmentProbe (..), JudgmentProbeId (..),
   JudgmentProbeStatus (..), ProbePurpose (..))

------------------------------------------------------------
-- Closed vocabulary and identities
------------------------------------------------------------

data ImpactClass
  = VeryLowImpact
  | LowImpact
  | MediumImpact
  | HighImpact
  | VeryHighImpact
  | CriticalImpact
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ImpactMaturity
  = Speculative
  | Supported
  | Validated
  | Observed
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data RelativeAssessment = RelativelyLess | RelativelySimilar | RelativelyMore
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data EffortComparison
  = MuchLessEffort
  | ALittleLessEffort
  | SimilarEffort
  | ALittleMoreEffort
  | MuchMoreEffort
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ProgressEvidenceKind
  = CompletedDescendant
  | ExplicitHumanProgress
  | ImportedActual
  | FocusDuration
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON ImpactClass where toJSON = toJSON . impactClassText
instance FromJSON ImpactClass where
  parseJSON = parseEnum "ImpactClass"
    [(impactClassText value, value) | value <- [minBound .. maxBound]]
instance ToJSON ImpactMaturity where toJSON = toJSON . impactMaturityText
instance FromJSON ImpactMaturity where
  parseJSON = parseEnum "ImpactMaturity"
    [(impactMaturityText value, value) | value <- [minBound .. maxBound]]
instance ToJSON RelativeAssessment where toJSON = toJSON . relativeAssessmentText
instance FromJSON RelativeAssessment where
  parseJSON = parseEnum "RelativeAssessment"
    [(relativeAssessmentText value, value) | value <- [minBound .. maxBound]]
instance ToJSON EffortComparison where toJSON = toJSON . effortComparisonText
instance FromJSON EffortComparison where
  parseJSON = parseEnum "EffortComparison"
    [(effortComparisonText value, value) | value <- [minBound .. maxBound]]
instance ToJSON ProgressEvidenceKind where toJSON = toJSON . progressKindText
instance FromJSON ProgressEvidenceKind where
  parseJSON = parseEnum "ProgressEvidenceKind"
    [(progressKindText value, value) | value <- [minBound .. maxBound]]

parseEnum :: String -> [(Text, value)] -> Value -> AesonTypes.Parser value
parseEnum name values = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate values)

impactClassText :: ImpactClass -> Text
impactClassText value = case value of
  VeryLowImpact -> "VERY_LOW"
  LowImpact -> "LOW"
  MediumImpact -> "MEDIUM"
  HighImpact -> "HIGH"
  VeryHighImpact -> "VERY_HIGH"
  CriticalImpact -> "CRITICAL"

impactMaturityText :: ImpactMaturity -> Text
impactMaturityText value = case value of
  Speculative -> "SPECULATIVE"
  Supported -> "SUPPORTED"
  Validated -> "VALIDATED"
  Observed -> "OBSERVED"

relativeAssessmentText :: RelativeAssessment -> Text
relativeAssessmentText value = case value of
  RelativelyLess -> "less"
  RelativelySimilar -> "similar"
  RelativelyMore -> "more"

effortComparisonText :: EffortComparison -> Text
effortComparisonText value = case value of
  MuchLessEffort -> "much_less"
  ALittleLessEffort -> "a_little_less"
  SimilarEffort -> "similar"
  ALittleMoreEffort -> "a_little_more"
  MuchMoreEffort -> "much_more"

progressKindText :: ProgressEvidenceKind -> Text
progressKindText value = case value of
  CompletedDescendant -> "completed_descendant"
  ExplicitHumanProgress -> "explicit_human_progress"
  ImportedActual -> "imported_actual"
  FocusDuration -> "focus_duration"

newtype ImpactAssessmentId = ImpactAssessmentId {unImpactAssessmentId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype ImpactComparisonId = ImpactComparisonId {unImpactComparisonId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype EffortAssessmentId = EffortAssessmentId {unEffortAssessmentId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype EffortComparisonEvidenceId = EffortComparisonEvidenceId
  {unEffortComparisonEvidenceId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype ScopeRevisionId = ScopeRevisionId {unScopeRevisionId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

------------------------------------------------------------
-- Canonical entities and derived values
------------------------------------------------------------

data JudgmentBrick = JudgmentBrick
  { judgmentBrickId :: BrickId
  , judgmentBrickParent :: Maybe BrickId
  , judgmentBrickStatus :: BrickStatus
  , judgmentBrickEffortApplicable :: Bool
  , judgmentBrickDecompositionCoverage :: DecompositionCoverage
  , judgmentBrickActiveChildren :: Set BrickId
  }
  deriving stock (Eq, Show, Generic)

data ImpactAssessment = ImpactAssessment
  { impactAssessmentId :: ImpactAssessmentId
  , impactAssessmentRoot :: BrickId
  , impactAssessmentImpact :: ImpactClass
  , impactAssessmentMaturity :: ImpactMaturity
  , impactAssessmentAuthority :: Authority
  , impactAssessmentReason :: Maybe Text
  , impactAssessmentRecordedAt :: UTCTime
  , impactAssessmentApplicable :: Bool
  }
  deriving stock (Eq, Show, Generic)

data ImpactComparison = ImpactComparison
  { impactComparisonId :: ImpactComparisonId
  , impactComparisonLeft :: BrickId
  , impactComparisonRight :: BrickId
  , impactComparisonResult :: RelativeAssessment
  , impactComparisonAuthority :: Authority
  , impactComparisonReason :: Maybe Text
  , impactComparisonRecordedAt :: UTCTime
  , impactComparisonApplicable :: Bool
  }
  deriving stock (Eq, Show, Generic)

data EffortProfile = EffortProfile
  { effortProfileId :: Text
  , effortProfileVersion :: Integer
  , effortProfileName :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)

data EffortBand = EffortBand
  { effortBandId :: Text
  , effortBandProfile :: EffortProfile
  , effortBandOrdinal :: Integer
  , effortBandMacro :: Text
  , effortBandOptimisticHours :: Double
  , effortBandRealisticHours :: Double
  , effortBandPessimisticHours :: Double
  }
  deriving stock (Eq, Show, Generic)

data EffortBandDraft = EffortBandDraft
  { effortBandDraftId :: Text
  , effortBandDraftOrdinal :: Integer
  , effortBandDraftMacro :: Text
  , effortBandDraftOptimisticHours :: Double
  , effortBandDraftRealisticHours :: Double
  , effortBandDraftPessimisticHours :: Double
  }
  deriving stock (Eq, Show, Generic)

data EffortAssessment = EffortAssessment
  { effortAssessmentId :: EffortAssessmentId
  , effortAssessmentBrick :: BrickId
  , effortAssessmentBand :: EffortBand
  , effortAssessmentAuthority :: Authority
  , effortAssessmentProvisional :: Bool
  , effortAssessmentReason :: Maybe Text
  , effortAssessmentRecordedAt :: UTCTime
  , effortAssessmentApplicable :: Bool
  }
  deriving stock (Eq, Show, Generic)

data EffortComparisonEvidence = EffortComparisonEvidence
  { effortComparisonEvidenceId :: EffortComparisonEvidenceId
  , effortComparisonEvidenceSubject :: BrickId
  , effortComparisonEvidenceExemplar :: BrickId
  , effortComparisonEvidenceResult :: EffortComparison
  , effortComparisonEvidenceAuthority :: Authority
  , effortComparisonEvidenceRecordedAt :: UTCTime
  , effortComparisonEvidenceApplicable :: Bool
  }
  deriving stock (Eq, Show, Generic)

data ScopeRevision = ScopeRevision
  { scopeRevisionId :: ScopeRevisionId
  , scopeRevisionBrick :: BrickId
  , scopeRevisionReason :: Text
  , scopeRevisionAuthority :: Authority
  , scopeRevisionConfirmedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data ProgressEvidence = ProgressEvidence
  { progressEvidenceId :: Text
  , progressEvidenceBrick :: BrickId
  , progressEvidenceKind :: ProgressEvidenceKind
  , progressEvidenceAmount :: Double
  , progressEvidenceRecordedAt :: UTCTime
  , progressEvidenceApplicable :: Bool
  }
  deriving stock (Eq, Show, Generic)

data ImpactEvidenceView = ImpactEvidenceView
  { impactEvidenceRoot :: BrickId
  , impactEvidenceCurrent :: Maybe ImpactAssessment
  , impactEvidenceReliabilityReasons :: [Text]
  , impactEvidenceNeedsValidation :: Bool
  , impactEvidenceHistory :: [ImpactAssessment]
  , impactEvidenceComparisons :: [ImpactComparison]
  }
  deriving stock (Eq, Show, Generic)

data EffortEvidenceView = EffortEvidenceView
  { effortEvidenceBrick :: BrickId
  , effortEvidenceCurrent :: Maybe EffortAssessment
  , effortEvidenceConfidenceReasons :: [Text]
  , effortEvidenceNeedsValidation :: Bool
  , effortEvidenceHistory :: [EffortAssessment]
  , effortEvidenceComparisons :: [EffortComparisonEvidence]
  }
  deriving stock (Eq, Show, Generic)

data RemainingEffortProjection = RemainingEffortProjection
  { remainingEffortBrick :: BrickId
  , remainingEffortEffortProfile :: EffortProfile
  , remainingEffortTotalBand :: Maybe EffortBand
  , remainingEffortOptimisticHours :: Maybe Double
  , remainingEffortRealisticHours :: Maybe Double
  , remainingEffortPessimisticHours :: Maybe Double
  , remainingEffortEvidence :: [Text]
  , remainingEffortConfidenceReasons :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data JudgmentState = JudgmentState
  { judgmentStateNextOrdinal :: Integer
  , judgmentStateEffortAssistanceLimit :: Int
  , judgmentStateBricks :: Map BrickId JudgmentBrick
  , judgmentStateImpactAssessments :: Map ImpactAssessmentId ImpactAssessment
  , judgmentStateImpactComparisons :: Map ImpactComparisonId ImpactComparison
  , judgmentStateEffortProfiles :: Map Text EffortProfile
  , judgmentStateEffortBands :: Map Text EffortBand
  , judgmentStateEffortAssessments :: Map EffortAssessmentId EffortAssessment
  , judgmentStateEffortComparisons ::
      Map EffortComparisonEvidenceId EffortComparisonEvidence
  , judgmentStateScopeRevisions :: Map ScopeRevisionId ScopeRevision
  , judgmentStateProbes :: Map JudgmentProbeId JudgmentProbe
  , judgmentStateProgressEvidence :: [ProgressEvidence]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON JudgmentBrick where toJSON = genericToJSON (recordOptions "judgmentBrick")
instance FromJSON JudgmentBrick where parseJSON = genericParseJSON (recordOptions "judgmentBrick")
instance ToJSON ImpactAssessment where toJSON = genericToJSON (recordOptions "impactAssessment")
instance FromJSON ImpactAssessment where parseJSON = genericParseJSON (recordOptions "impactAssessment")
instance ToJSON ImpactComparison where toJSON = genericToJSON (recordOptions "impactComparison")
instance FromJSON ImpactComparison where parseJSON = genericParseJSON (recordOptions "impactComparison")
instance ToJSON EffortProfile where toJSON = genericToJSON (recordOptions "effortProfile")
instance FromJSON EffortProfile where parseJSON = genericParseJSON (recordOptions "effortProfile")
instance ToJSON EffortBand where toJSON = genericToJSON (recordOptions "effortBand")
instance FromJSON EffortBand where parseJSON = genericParseJSON (recordOptions "effortBand")
instance ToJSON EffortBandDraft where toJSON = genericToJSON (recordOptions "effortBandDraft")
instance FromJSON EffortBandDraft where parseJSON = genericParseJSON (recordOptions "effortBandDraft")
instance ToJSON EffortAssessment where toJSON = genericToJSON (recordOptions "effortAssessment")
instance FromJSON EffortAssessment where parseJSON = genericParseJSON (recordOptions "effortAssessment")
instance ToJSON EffortComparisonEvidence where toJSON = genericToJSON (recordOptions "effortComparisonEvidence")
instance FromJSON EffortComparisonEvidence where parseJSON = genericParseJSON (recordOptions "effortComparisonEvidence")
instance ToJSON ScopeRevision where toJSON = genericToJSON (recordOptions "scopeRevision")
instance FromJSON ScopeRevision where parseJSON = genericParseJSON (recordOptions "scopeRevision")
instance ToJSON ProgressEvidence where toJSON = genericToJSON (recordOptions "progressEvidence")
instance FromJSON ProgressEvidence where parseJSON = genericParseJSON (recordOptions "progressEvidence")
instance ToJSON ImpactEvidenceView where toJSON = genericToJSON (recordOptions "impactEvidence")
instance FromJSON ImpactEvidenceView where parseJSON = genericParseJSON (recordOptions "impactEvidence")
instance ToJSON EffortEvidenceView where toJSON = genericToJSON (recordOptions "effortEvidence")
instance FromJSON EffortEvidenceView where parseJSON = genericParseJSON (recordOptions "effortEvidence")
instance ToJSON RemainingEffortProjection where toJSON = genericToJSON (recordOptions "remainingEffort")
instance FromJSON RemainingEffortProjection where parseJSON = genericParseJSON (recordOptions "remainingEffort")
instance ToJSON JudgmentState where toJSON = genericToJSON (recordOptions "judgmentState")
instance FromJSON JudgmentState where parseJSON = genericParseJSON (recordOptions "judgmentState")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLower first : rest)

------------------------------------------------------------
-- Effort calibration and initial state
------------------------------------------------------------

initialEffortProfile :: EffortProfile
initialEffortProfile = EffortProfile
  { effortProfileId = "core/effort"
  , effortProfileVersion = 1
  , effortProfileName = "Little Ant default effort profile"
  }

initialEffortBands :: [EffortBand]
initialEffortBands =
  [ band "VERY_EASY" 1 "EFFORT_2H" 2 3 4
  , band "EASY" 2 "EFFORT_4H" 4 6 8
  , band "NORMAL" 3 "EFFORT_1D" 8 12 16
  , band "MODERATED" 4 "EFFORT_2D" 16 24 32
  , band "HARD" 5 "EFFORT_4D" 32 48 64
  , band "VERY_HARD" 6 "EFFORT_8D" 64 96 128
  , band "MINI_PROJECT" 7 "EFFORT_16D" 128 192 256
  , band "PROJECT" 8 "EFFORT_32D" 256 384 512
  ]
  where
    band identifier ordinal macro optimistic realistic pessimistic = EffortBand
      identifier initialEffortProfile ordinal macro optimistic realistic pessimistic

emptyJudgmentState :: JudgmentState
emptyJudgmentState = JudgmentState
  { judgmentStateNextOrdinal = 1
  , judgmentStateEffortAssistanceLimit = 3
  , judgmentStateBricks = Map.empty
  , judgmentStateImpactAssessments = Map.empty
  , judgmentStateImpactComparisons = Map.empty
  , judgmentStateEffortProfiles = Map.singleton
      (profileKey initialEffortProfile) initialEffortProfile
  , judgmentStateEffortBands = Map.fromList
      [(bandKey value, value) | value <- initialEffortBands]
  , judgmentStateEffortAssessments = Map.empty
  , judgmentStateEffortComparisons = Map.empty
  , judgmentStateScopeRevisions = Map.empty
  , judgmentStateProbes = Map.empty
  , judgmentStateProgressEvidence = []
  }

configureEffortAssistance :: Int -> JudgmentState -> Either JudgmentError JudgmentState
configureEffortAssistance limit state = do
  when (limit < 1) (Left (InvalidEffortProfile "effort assistance limit must be positive"))
  pure state {judgmentStateEffortAssistanceLimit = limit}

publishEffortProfile ::
  Text -> Integer -> Text -> [EffortBandDraft] -> JudgmentState ->
  Either JudgmentError (EffortProfile, [EffortBand], JudgmentState)
publishEffortProfile identifier version name drafts state = do
  when (Text.null (Text.strip identifier) || Text.null (Text.strip name))
    (Left (InvalidEffortProfile "profile identity and name must not be empty"))
  let versions =
        [ effortProfileVersion profile
        | profile <- Map.elems (judgmentStateEffortProfiles state)
        , effortProfileId profile == identifier
        ]
      expected = maybe 1 (+ 1) (lastMay (sort versions))
  unless (version == expected)
    (Left (InvalidEffortProfile "profile version is not the next immutable version"))
  when (null drafts) (Left (InvalidEffortProfile "profile must contain bands"))
  let ids = map effortBandDraftId drafts
      ordinals = map effortBandDraftOrdinal drafts
      macros = map effortBandDraftMacro drafts
  unless (all (not . Text.null . Text.strip) (ids <> macros))
    (Left (InvalidEffortProfile "band IDs and macros must not be empty"))
  unless (unique ids && unique ordinals && unique macros)
    (Left (InvalidEffortProfile "band IDs, ordinals, and macros must be unique"))
  unless (sort ordinals == [1 .. fromIntegral (length drafts)])
    (Left (InvalidEffortProfile "band ordinals must form one strict order"))
  unless (all validHours drafts)
    (Left (InvalidEffortProfile "band hours must be non-negative and ordered"))
  let profile = EffortProfile identifier version name
      bands = map (fromDraft profile) drafts
      next = state
        { judgmentStateEffortProfiles = Map.insert (profileKey profile) profile
            (judgmentStateEffortProfiles state)
        , judgmentStateEffortBands = foldr
            (\value -> Map.insert (bandKey value) value)
            (judgmentStateEffortBands state) bands
        }
  validateJudgmentState next
  pure (profile, bands, next)
  where
    unique values = length values == length (nub values)
    validHours draft = effortBandDraftOptimisticHours draft >= 0
      && effortBandDraftOptimisticHours draft <= effortBandDraftRealisticHours draft
      && effortBandDraftRealisticHours draft <= effortBandDraftPessimisticHours draft
    fromDraft profile draft = EffortBand
      { effortBandId = effortBandDraftId draft
      , effortBandProfile = profile
      , effortBandOrdinal = effortBandDraftOrdinal draft
      , effortBandMacro = effortBandDraftMacro draft
      , effortBandOptimisticHours = effortBandDraftOptimisticHours draft
      , effortBandRealisticHours = effortBandDraftRealisticHours draft
      , effortBandPessimisticHours = effortBandDraftPessimisticHours draft
      }

effortBandById ::
  EffortProfile -> Text -> JudgmentState -> Either JudgmentError EffortBand
effortBandById profile identifier state = maybe
  (Left (UnknownEffortBand identifier)) Right
  (Map.lookup (bandKeyFrom profile identifier) (judgmentStateEffortBands state))

------------------------------------------------------------
-- Brick scope, impact, and effort evidence
------------------------------------------------------------

registerJudgmentBrick ::
  BrickId -> Maybe BrickId -> BrickStatus -> Bool -> JudgmentState ->
  Either JudgmentError JudgmentState
registerJudgmentBrick identifier parent status effortApplicable state = do
  case Map.lookup identifier (judgmentStateBricks state) of
    Just existing -> do
      unless (judgmentBrickParent existing == parent
          && judgmentBrickEffortApplicable existing == effortApplicable)
        (Left (InvalidJudgmentRelationship "Brick registration conflicts with retained scope"))
      pure state
    Nothing -> do
      parentBrick <- traverse (`requireBrick` state) parent
      case parentBrick of
        Just value -> unless (judgmentBrickStatus value == Active)
          (Left (InvalidJudgmentRelationship "parent Brick is terminal"))
        Nothing -> pure ()
      let brick = JudgmentBrick
            { judgmentBrickId = identifier
            , judgmentBrickParent = parent
            , judgmentBrickStatus = status
            , judgmentBrickEffortApplicable = effortApplicable
            , judgmentBrickDecompositionCoverage = NotApplicable
            , judgmentBrickActiveChildren = Set.empty
            }
          withBrick = Map.insert identifier brick (judgmentStateBricks state)
          withParent = case (parent, status) of
            (Just parentId, Active) -> Map.adjust (\value -> value
              { judgmentBrickActiveChildren = Set.insert identifier
                  (judgmentBrickActiveChildren value)
              , judgmentBrickDecompositionCoverage = Open
              }) parentId withBrick
            _ -> withBrick
          next = state {judgmentStateBricks = withParent}
      validateJudgmentState next
      pure next

classifyImpact ::
  BrickId -> ImpactClass -> ImpactMaturity -> Authority -> Maybe Text -> UTCTime ->
  JudgmentState ->
  Either JudgmentError (ImpactAssessment, Maybe JudgmentProbe, JudgmentState)
classifyImpact root impact maturity authority reason now state = do
  _ <- requireRoot root state
  let ordinal = judgmentStateNextOrdinal state
      assessment = ImpactAssessment
        { impactAssessmentId = ImpactAssessmentId (opaque "impact-assessment" ordinal)
        , impactAssessmentRoot = root
        , impactAssessmentImpact = impact
        , impactAssessmentMaturity = maturity
        , impactAssessmentAuthority = authority
        , impactAssessmentReason = reason
        , impactAssessmentRecordedAt = now
        , impactAssessmentApplicable = True
        }
      withAssessment = state
        { judgmentStateNextOrdinal = ordinal + 1
        , judgmentStateImpactAssessments = Map.insert
            (impactAssessmentId assessment) assessment
            (judgmentStateImpactAssessments state)
        }
      conflict = firstImpactAssessmentConflict assessment withAssessment
  (probe, next) <- case conflict of
    Nothing -> pure (Nothing, withAssessment)
    Just other -> openRecalibrationProbe ImpactAxis root other
      "impact class conflicts with retained comparison evidence" now withAssessment
  validateJudgmentState next
  pure (assessment, probe, next)

compareImpact ::
  BrickId -> BrickId -> RelativeAssessment -> Authority -> Maybe Text -> UTCTime ->
  JudgmentState ->
  Either JudgmentError (ImpactComparison, Maybe JudgmentProbe, JudgmentState)
compareImpact left right result authority reason now state = do
  when (left == right)
    (Left (InvalidJudgmentRelationship "impact comparison requires distinct roots"))
  _ <- requireRoot left state
  _ <- requireRoot right state
  let ordinal = judgmentStateNextOrdinal state
      comparison = ImpactComparison
        { impactComparisonId = ImpactComparisonId (opaque "impact-comparison" ordinal)
        , impactComparisonLeft = left
        , impactComparisonRight = right
        , impactComparisonResult = result
        , impactComparisonAuthority = authority
        , impactComparisonReason = reason
        , impactComparisonRecordedAt = now
        , impactComparisonApplicable = True
        }
      resolved = resolveComparisonProbes ImpactAxis left right now
        (judgmentStateProbes state)
      withComparison = state
        { judgmentStateNextOrdinal = ordinal + 1
        , judgmentStateImpactComparisons = Map.insert
            (impactComparisonId comparison) comparison
            (judgmentStateImpactComparisons state)
        , judgmentStateProbes = resolved
        }
      contradiction = impactComparisonContradicts comparison state
        || impactComparisonContradictsAssessments comparison withComparison
  (probe, next) <- if contradiction
    then openRecalibrationProbe ImpactAxis left right
      "impact evidence is locally contradictory" now withComparison
    else pure (Nothing, withComparison)
  validateJudgmentState next
  pure (comparison, probe, next)

reviseImpactMaturity ::
  BrickId -> ImpactMaturity -> Authority -> Text -> UTCTime -> JudgmentState ->
  Either JudgmentError (ImpactAssessment, Maybe JudgmentProbe, JudgmentState)
reviseImpactMaturity root maturity authority reason now state = do
  _ <- requireRoot root state
  when (Text.null (Text.strip reason))
    (Left (InvalidJudgmentRelationship "maturity revision requires a reason"))
  current <- maybe (Left (InvalidJudgmentTransition
      "impact maturity requires a current assessment")) Right
    (currentImpactAssessment state root)
  classifyImpact root (impactAssessmentImpact current) maturity authority
    (Just reason) now state

classifyEffort ::
  BrickId -> EffortBand -> Authority -> Bool -> Maybe Text -> UTCTime ->
  JudgmentState ->
  Either JudgmentError (EffortAssessment, Maybe JudgmentProbe, JudgmentState)
classifyEffort brick band authority provisional reason now state = do
  _ <- requireEffortBrick True brick state
  canonicalBand <- effortBandById (effortBandProfile band) (effortBandId band) state
  unless (canonicalBand == band)
    (Left (InvalidEffortProfile "assessment band is not a published immutable version"))
  let ordinal = judgmentStateNextOrdinal state
      assessment = EffortAssessment
        { effortAssessmentId = EffortAssessmentId (opaque "effort-assessment" ordinal)
        , effortAssessmentBrick = brick
        , effortAssessmentBand = band
        , effortAssessmentAuthority = authority
        , effortAssessmentProvisional = provisional
        , effortAssessmentReason = reason
        , effortAssessmentRecordedAt = now
        , effortAssessmentApplicable = True
        }
      withAssessment = state
        { judgmentStateNextOrdinal = ordinal + 1
        , judgmentStateEffortAssessments = Map.insert
            (effortAssessmentId assessment) assessment
            (judgmentStateEffortAssessments state)
        }
      conflict = firstEffortAssessmentConflict assessment withAssessment
  (probe, next) <- case conflict of
    Nothing -> pure (Nothing, withAssessment)
    Just other -> openRecalibrationProbe EffortAxis brick other
      "effort class conflicts with retained comparison evidence" now withAssessment
  validateJudgmentState next
  pure (assessment, probe, next)

compareEffort ::
  BrickId -> BrickId -> EffortComparison -> Authority -> UTCTime ->
  JudgmentState ->
  Either JudgmentError
    (EffortComparisonEvidence, Maybe JudgmentProbe, JudgmentState)
compareEffort subject exemplar result authority now state = do
  when (subject == exemplar)
    (Left (InvalidJudgmentRelationship "effort comparison requires distinct Bricks"))
  _ <- requireEffortBrick False subject state
  _ <- requireEffortBrick False exemplar state
  let ordinal = judgmentStateNextOrdinal state
      comparison = EffortComparisonEvidence
        { effortComparisonEvidenceId = EffortComparisonEvidenceId
            (opaque "effort-comparison" ordinal)
        , effortComparisonEvidenceSubject = subject
        , effortComparisonEvidenceExemplar = exemplar
        , effortComparisonEvidenceResult = result
        , effortComparisonEvidenceAuthority = authority
        , effortComparisonEvidenceRecordedAt = now
        , effortComparisonEvidenceApplicable = True
        }
      resolved = resolveComparisonProbes EffortAxis subject exemplar now
        (judgmentStateProbes state)
      withComparison = state
        { judgmentStateNextOrdinal = ordinal + 1
        , judgmentStateEffortComparisons = Map.insert
            (effortComparisonEvidenceId comparison) comparison
            (judgmentStateEffortComparisons state)
        , judgmentStateProbes = resolved
        }
      contradiction = effortComparisonContradicts comparison state
        || effortComparisonContradictsAssessments comparison withComparison
  (probe, next) <- if contradiction
    then openRecalibrationProbe EffortAxis subject exemplar
      "effort evidence is locally contradictory" now withComparison
    else pure (Nothing, withComparison)
  validateJudgmentState next
  pure (comparison, probe, next)

------------------------------------------------------------
-- Probes, decomposition, correction, and progress
------------------------------------------------------------

openImpactProbe ::
  BrickId -> BrickId -> ProbePurpose -> Text -> UTCTime -> JudgmentState ->
  Either JudgmentError (JudgmentProbe, JudgmentState)
openImpactProbe left right purpose reason now state = do
  when (left == right)
    (Left (InvalidJudgmentRelationship "impact probe requires distinct Bricks"))
  _ <- requireRoot left state
  _ <- requireRoot right state
  createProbe ImpactAxis left right purpose reason now state

openEffortProbe ::
  BrickId -> BrickId -> ProbePurpose -> Text -> UTCTime -> JudgmentState ->
  Either JudgmentError (JudgmentProbe, JudgmentState)
openEffortProbe left right purpose reason now state = do
  when (left == right)
    (Left (InvalidJudgmentRelationship "effort probe requires distinct Bricks"))
  _ <- requireEffortBrick False left state
  _ <- requireEffortBrick False right state
  createProbe EffortAxis left right purpose reason now state

createProbe ::
  JudgmentAxis -> BrickId -> BrickId -> ProbePurpose -> Text -> UTCTime ->
  JudgmentState -> Either JudgmentError (JudgmentProbe, JudgmentState)
createProbe axis left right purpose reason now state = do
  when (Text.null (Text.strip reason))
    (Left (InvalidJudgmentRelationship "judgment probe requires a reason"))
  let ordinal = judgmentStateNextOrdinal state
      probe = JudgmentProbe
        { judgmentProbeId = JudgmentProbeId (opaque "assessment-probe" ordinal)
        , judgmentProbeAxis = axis
        , judgmentProbePurpose = purpose
        , judgmentProbeScope = Nothing
        , judgmentProbeLeft = left
        , judgmentProbeRight = right
        , judgmentProbeReason = reason
        , judgmentProbeStatus = ProbeOpen
        , judgmentProbeCreatedAt = now
        , judgmentProbeResolvedAt = Nothing
        }
      next = state
        { judgmentStateNextOrdinal = ordinal + 1
        , judgmentStateProbes = Map.insert (judgmentProbeId probe) probe
            (judgmentStateProbes state)
        }
  validateJudgmentState next
  pure (probe, next)

deferAssessmentProbe ::
  JudgmentProbeId -> JudgmentState -> Either JudgmentError (JudgmentProbe, JudgmentState)
deferAssessmentProbe identifier state = do
  probe <- requireProbe identifier state
  unless (judgmentProbeStatus probe == ProbeOpen)
    (Left (InvalidJudgmentTransition "only an open judgment probe can defer"))
  let deferred = probe {judgmentProbeStatus = ProbeDeferred}
      next = state {judgmentStateProbes = Map.insert identifier deferred
        (judgmentStateProbes state)}
  validateJudgmentState next
  pure (deferred, next)

reopenAssessmentProbe ::
  JudgmentProbeId -> JudgmentState -> Either JudgmentError (JudgmentProbe, JudgmentState)
reopenAssessmentProbe identifier state = do
  probe <- requireProbe identifier state
  unless (judgmentProbeStatus probe == ProbeDeferred)
    (Left (InvalidJudgmentTransition "only a deferred judgment probe can reopen"))
  let reopened = probe {judgmentProbeStatus = ProbeOpen}
      next = state {judgmentStateProbes = Map.insert identifier reopened
        (judgmentStateProbes state)}
  validateJudgmentState next
  pure (reopened, next)

setJudgmentBrickStatus ::
  BrickId -> BrickStatus -> UTCTime -> JudgmentState ->
  Either JudgmentError (JudgmentBrick, JudgmentState)
setJudgmentBrickStatus identifier status now state = do
  brick <- requireBrick identifier state
  unless (judgmentBrickStatus brick == Active && status /= Active)
    (Left (InvalidJudgmentTransition "only an active Brick can become terminal"))
  let updated = brick {judgmentBrickStatus = status}
      withoutChild = case judgmentBrickParent brick of
        Nothing -> judgmentStateBricks state
        Just parent -> Map.adjust (\value -> value
          {judgmentBrickActiveChildren = Set.delete identifier
            (judgmentBrickActiveChildren value)}) parent (judgmentStateBricks state)
      bricks = Map.insert identifier updated withoutChild
      probes = Map.map (resolveForTerminal identifier now)
        (judgmentStateProbes state)
      next = state {judgmentStateBricks = bricks, judgmentStateProbes = probes}
  validateJudgmentState next
  pure (updated, next)

confirmDecompositionCoverage ::
  BrickId -> JudgmentState -> Either JudgmentError (JudgmentBrick, JudgmentState)
confirmDecompositionCoverage identifier state = do
  brick <- requireBrick identifier state
  unless (judgmentBrickStatus brick == Active)
    (Left (InvalidJudgmentTransition "decomposition owner is terminal"))
  when (Set.null (judgmentBrickActiveChildren brick))
    (Left (InvalidJudgmentRelationship "decomposition has no active children"))
  unless (judgmentBrickDecompositionCoverage brick == Open)
    (Left (InvalidJudgmentTransition "decomposition coverage is not open"))
  let confirmed = brick {judgmentBrickDecompositionCoverage = Complete}
      next = state {judgmentStateBricks = Map.insert identifier confirmed
        (judgmentStateBricks state)}
  validateJudgmentState next
  pure (confirmed, next)

confirmScopeRevision ::
  BrickId -> Text -> Authority -> UTCTime -> JudgmentState ->
  Either JudgmentError (ScopeRevision, JudgmentState)
confirmScopeRevision identifier reason authority now state = do
  brick <- requireBrick identifier state
  unless (judgmentBrickStatus brick == Active)
    (Left (InvalidJudgmentTransition "scope revision requires an active Brick"))
  when (Text.null (Text.strip reason))
    (Left (InvalidJudgmentRelationship "scope revision requires a reason"))
  let ordinal = judgmentStateNextOrdinal state
      revision = ScopeRevision
        { scopeRevisionId = ScopeRevisionId (opaque "scope-revision" ordinal)
        , scopeRevisionBrick = identifier
        , scopeRevisionReason = reason
        , scopeRevisionAuthority = authority
        , scopeRevisionConfirmedAt = now
        }
      rootRevision = judgmentBrickParent brick == Nothing
      retireImpactAssessment value
        | rootRevision && impactAssessmentRoot value == identifier =
            value {impactAssessmentApplicable = False}
        | otherwise = value
      retireImpactComparison value
        | rootRevision && identifier `elem`
            [impactComparisonLeft value, impactComparisonRight value] =
              value {impactComparisonApplicable = False}
        | otherwise = value
      retireEffortAssessment value
        | effortAssessmentBrick value == identifier =
            value {effortAssessmentApplicable = False}
        | otherwise = value
      retireEffortComparison value
        | identifier `elem`
            [ effortComparisonEvidenceSubject value
            , effortComparisonEvidenceExemplar value
            ] = value {effortComparisonEvidenceApplicable = False}
        | otherwise = value
      retireProgress value
        | progressEvidenceBrick value == identifier =
            value {progressEvidenceApplicable = False}
        | otherwise = value
      revisedBrick = brick {judgmentBrickDecompositionCoverage = Open}
      next = state
        { judgmentStateNextOrdinal = ordinal + 1
        , judgmentStateBricks = Map.insert identifier revisedBrick
            (judgmentStateBricks state)
        , judgmentStateImpactAssessments = Map.map retireImpactAssessment
            (judgmentStateImpactAssessments state)
        , judgmentStateImpactComparisons = Map.map retireImpactComparison
            (judgmentStateImpactComparisons state)
        , judgmentStateEffortAssessments = Map.map retireEffortAssessment
            (judgmentStateEffortAssessments state)
        , judgmentStateEffortComparisons = Map.map retireEffortComparison
            (judgmentStateEffortComparisons state)
        , judgmentStateProgressEvidence = map retireProgress
            (judgmentStateProgressEvidence state)
        , judgmentStateScopeRevisions = Map.insert (scopeRevisionId revision)
            revision (judgmentStateScopeRevisions state)
        }
  validateJudgmentState next
  pure (revision, next)

recordProgressEvidence ::
  BrickId -> ProgressEvidenceKind -> Double -> UTCTime -> JudgmentState ->
  Either JudgmentError (ProgressEvidence, JudgmentState)
recordProgressEvidence identifier kind amount now state = do
  _ <- requireBrick identifier state
  when (amount < 0 || (kind == ExplicitHumanProgress && amount > 1))
    (Left (InvalidJudgmentRelationship "progress evidence amount is outside its range"))
  let ordinal = judgmentStateNextOrdinal state
      evidence = ProgressEvidence
        { progressEvidenceId = opaque "progress-evidence" ordinal
        , progressEvidenceBrick = identifier
        , progressEvidenceKind = kind
        , progressEvidenceAmount = amount
        , progressEvidenceRecordedAt = now
        , progressEvidenceApplicable = True
        }
      next = state
        { judgmentStateNextOrdinal = ordinal + 1
        , judgmentStateProgressEvidence = judgmentStateProgressEvidence state
            <> [evidence]
        }
  validateJudgmentState next
  pure (evidence, next)

------------------------------------------------------------
-- Derivations and projections
------------------------------------------------------------

currentImpactAssessment :: JudgmentState -> BrickId -> Maybe ImpactAssessment
currentImpactAssessment state root = chooseAuthoritative
  impactAssessmentAuthority impactAssessmentRecordedAt
  [ value
  | value <- Map.elems (judgmentStateImpactAssessments state)
  , impactAssessmentRoot value == root
  , impactAssessmentApplicable value
  ]

currentEffortAssessment :: JudgmentState -> BrickId -> Maybe EffortAssessment
currentEffortAssessment state brick = chooseAuthoritative
  effortAssessmentAuthority effortAssessmentRecordedAt
  [ value
  | value <- Map.elems (judgmentStateEffortAssessments state)
  , effortAssessmentBrick value == brick
  , effortAssessmentApplicable value
  ]

chooseAuthoritative ::
  (value -> Authority) -> (value -> UTCTime) -> [value] -> Maybe value
chooseAuthoritative authority recorded values =
  let humans = filter ((== Human) . authority) values
      candidates = if null humans then values else humans
  in lastMay (sortOn recorded candidates)

impactEvidence :: JudgmentState -> BrickId -> Either JudgmentError ImpactEvidenceView
impactEvidence state root = do
  _ <- requireRoot root state
  let history = sortOn impactAssessmentRecordedAt
        [value | value <- Map.elems (judgmentStateImpactAssessments state),
          impactAssessmentRoot value == root]
      comparisons = sortOn impactComparisonRecordedAt
        [value | value <- Map.elems (judgmentStateImpactComparisons state),
          root `elem` [impactComparisonLeft value, impactComparisonRight value]]
      current = currentImpactAssessment state root
      conflict = any (\comparison -> impactComparisonContradictsAssessments
          comparison state) (filter impactComparisonApplicable comparisons)
        || authorityImpactConflict current history
      openProbe = any (probeTouches ImpactAxis root)
        (Map.elems (judgmentStateProbes state))
      speculative = maybe False ((== Speculative) . impactAssessmentMaturity) current
      reasons = concat
        [ ["impact is absent and remains lazy and neutral" | current == Nothing]
        , ["current human evidence has authority over AI evidence" |
            humanEvidenceExists impactAssessmentAuthority history]
        , ["retained impact evidence is contradictory" | conflict]
        , ["current impact maturity is speculative" | speculative]
        , ["impact validation or recalibration probe is open" | openProbe]
        ]
  pure ImpactEvidenceView
    { impactEvidenceRoot = root
    , impactEvidenceCurrent = current
    , impactEvidenceReliabilityReasons = reasons
    , impactEvidenceNeedsValidation = isJust current && (conflict || speculative || openProbe)
    , impactEvidenceHistory = history
    , impactEvidenceComparisons = comparisons
    }

effortEvidence :: JudgmentState -> BrickId -> Either JudgmentError EffortEvidenceView
effortEvidence state brick = do
  _ <- requireBrick brick state
  let history = sortOn effortAssessmentRecordedAt
        [value | value <- Map.elems (judgmentStateEffortAssessments state),
          effortAssessmentBrick value == brick]
      comparisons = sortOn effortComparisonEvidenceRecordedAt
        [ value
        | value <- Map.elems (judgmentStateEffortComparisons state)
        , brick `elem`
            [ effortComparisonEvidenceSubject value
            , effortComparisonEvidenceExemplar value
            ]
        ]
      current = currentEffortAssessment state brick
      conflict = any (\comparison -> effortComparisonContradictsAssessments
          comparison state) (filter effortComparisonEvidenceApplicable comparisons)
        || authorityEffortConflict current history
      openProbe = any (probeTouches EffortAxis brick)
        (Map.elems (judgmentStateProbes state))
      provisional = maybe False effortAssessmentProvisional current
      reasons = concat
        [ ["effort is absent and remains lazy and neutral" | current == Nothing]
        , ["current human evidence has authority over AI evidence" |
            humanEvidenceExists effortAssessmentAuthority history]
        , ["retained effort evidence is contradictory" | conflict]
        , ["current effort classification is provisional" | provisional]
        , ["effort validation or recalibration probe is open" | openProbe]
        ]
  pure EffortEvidenceView
    { effortEvidenceBrick = brick
    , effortEvidenceCurrent = current
    , effortEvidenceConfidenceReasons = reasons
    , effortEvidenceNeedsValidation = isJust current
        && (conflict || provisional || openProbe)
    , effortEvidenceHistory = history
    , effortEvidenceComparisons = comparisons
    }

remainingEffortProjection ::
  JudgmentState -> BrickId -> EffortProfile ->
  Either JudgmentError RemainingEffortProjection
remainingEffortProjection state brick profile = do
  _ <- requireBrick brick state
  unless (Map.member (profileKey profile) (judgmentStateEffortProfiles state))
    (Left (InvalidEffortProfile "remaining-effort profile is unpublished"))
  let assessment = currentEffortAssessment state brick
      total = do
        value <- assessment
        let band = effortAssessmentBand value
        if effortBandProfile band == profile then Just band else Nothing
      evidence = filter (\value -> progressEvidenceBrick value == brick
          && progressEvidenceApplicable value)
        (judgmentStateProgressEvidence state)
      ratio = maybe 0 (conservativeCompletionRatio evidence) total
      remaining field = fmap (\band -> max 0 (field band * (1 - ratio))) total
      descriptions = map progressDescription evidence
      confidence = concat
        [ ["no total effort assessment; remaining effort stays absent" | total == Nothing]
        , ["focus duration is not completion evidence" |
            any ((== FocusDuration) . progressEvidenceKind) evidence]
        , ["remaining effort uses the strongest conservative progress signal" |
            ratio > 0]
        ]
  pure RemainingEffortProjection
    { remainingEffortBrick = brick
    , remainingEffortEffortProfile = profile
    , remainingEffortTotalBand = total
    , remainingEffortOptimisticHours = remaining effortBandOptimisticHours
    , remainingEffortRealisticHours = remaining effortBandRealisticHours
    , remainingEffortPessimisticHours = remaining effortBandPessimisticHours
    , remainingEffortEvidence = descriptions
    , remainingEffortConfidenceReasons = confidence
    }

conservativeCompletionRatio :: [ProgressEvidence] -> EffortBand -> Double
conservativeCompletionRatio evidence band = min 1 (maximum (0 : map ratio evidence))
  where
    realistic = max 0.000001 (effortBandRealisticHours band)
    ratio value = case progressEvidenceKind value of
      CompletedDescendant -> progressEvidenceAmount value / realistic
      ExplicitHumanProgress -> progressEvidenceAmount value
      ImportedActual -> progressEvidenceAmount value / realistic
      FocusDuration -> 0

progressDescription :: ProgressEvidence -> Text
progressDescription value = progressKindText (progressEvidenceKind value)
  <> ":" <> Text.pack (show (progressEvidenceAmount value))

impactAssessmentProjection ::
  JudgmentState -> ImpactAssessmentId -> Either JudgmentError Value
impactAssessmentProjection state identifier = do
  assessment <- maybe (Left (UnknownImpactAssessment identifier)) Right
    (Map.lookup identifier (judgmentStateImpactAssessments state))
  evidence <- impactEvidence state (impactAssessmentRoot assessment)
  pure (object
    [ "id" .= impactAssessmentId assessment
    , "root" .= impactAssessmentRoot assessment
    , "impact" .= impactAssessmentImpact assessment
    , "maturity" .= impactAssessmentMaturity assessment
    , "authority" .= impactAssessmentAuthority assessment
    , "reason" .= impactAssessmentReason assessment
    , "recorded_at" .= impactAssessmentRecordedAt assessment
    , "applicable" .= impactAssessmentApplicable assessment
    , "is_current" .= (impactEvidenceCurrent evidence == Just assessment)
    , "evidence_view" .= evidence
    ])

impactComparisonProjection ::
  JudgmentState -> ImpactComparisonId -> Either JudgmentError Value
impactComparisonProjection state identifier = do
  comparison <- maybe (Left (UnknownImpactComparison identifier)) Right
    (Map.lookup identifier (judgmentStateImpactComparisons state))
  pure (object
    [ "id" .= impactComparisonId comparison
    , "left" .= impactComparisonLeft comparison
    , "right" .= impactComparisonRight comparison
    , "result" .= impactComparisonResult comparison
    , "authority" .= impactComparisonAuthority comparison
    , "reason" .= impactComparisonReason comparison
    , "recorded_at" .= impactComparisonRecordedAt comparison
    , "applicable" .= impactComparisonApplicable comparison
    , "is_current" .= comparisonIsCurrent impactComparisonAuthority
        impactComparisonRecordedAt impactComparisonApplicable
        impactComparisonLeft impactComparisonRight comparison
        (Map.elems (judgmentStateImpactComparisons state))
    ])

effortAssessmentProjection ::
  JudgmentState -> EffortAssessmentId -> Either JudgmentError Value
effortAssessmentProjection state identifier = do
  assessment <- maybe (Left (UnknownEffortAssessment identifier)) Right
    (Map.lookup identifier (judgmentStateEffortAssessments state))
  evidence <- effortEvidence state (effortAssessmentBrick assessment)
  remaining <- remainingEffortProjection state (effortAssessmentBrick assessment)
    (effortBandProfile (effortAssessmentBand assessment))
  pure (object
    [ "id" .= effortAssessmentId assessment
    , "brick" .= effortAssessmentBrick assessment
    , "band" .= effortAssessmentBand assessment
    , "authority" .= effortAssessmentAuthority assessment
    , "provisional" .= effortAssessmentProvisional assessment
    , "reason" .= effortAssessmentReason assessment
    , "recorded_at" .= effortAssessmentRecordedAt assessment
    , "applicable" .= effortAssessmentApplicable assessment
    , "is_current" .= (effortEvidenceCurrent evidence == Just assessment)
    , "evidence_view" .= evidence
    , "remaining_view" .= remaining
    ])

effortComparisonProjection ::
  JudgmentState -> EffortComparisonEvidenceId -> Either JudgmentError Value
effortComparisonProjection state identifier = do
  comparison <- maybe (Left (UnknownEffortComparison identifier)) Right
    (Map.lookup identifier (judgmentStateEffortComparisons state))
  pure (object
    [ "id" .= effortComparisonEvidenceId comparison
    , "subject" .= effortComparisonEvidenceSubject comparison
    , "exemplar" .= effortComparisonEvidenceExemplar comparison
    , "result" .= effortComparisonEvidenceResult comparison
    , "authority" .= effortComparisonEvidenceAuthority comparison
    , "recorded_at" .= effortComparisonEvidenceRecordedAt comparison
    , "applicable" .= effortComparisonEvidenceApplicable comparison
    , "is_current" .= comparisonIsCurrent effortComparisonEvidenceAuthority
        effortComparisonEvidenceRecordedAt effortComparisonEvidenceApplicable
        effortComparisonEvidenceSubject effortComparisonEvidenceExemplar comparison
        (Map.elems (judgmentStateEffortComparisons state))
    ])

judgmentProbeProjection ::
  JudgmentState -> JudgmentProbeId -> Either JudgmentError Value
judgmentProbeProjection state identifier = toJSON <$> requireProbe identifier state

judgmentProjection :: JudgmentState -> BrickId -> Either JudgmentError Value
judgmentProjection state brick = do
  value <- requireBrick brick state
  effort <- effortEvidence state brick
  let root = rootOf state value
  impact <- impactEvidence state root
  remaining <- remainingEffortProjection state brick initialEffortProfile
  pure (object
    [ "brick" .= brick
    , "impact" .= impact
    , "effort" .= effort
    , "remaining_effort" .= remaining
    , "controls_priority" .= False
    , "controls_eligibility" .= False
    , "eligible_without_assessments" .= (judgmentBrickStatus value == Active)
    ])

judgmentProposalKinds :: JudgmentState -> BrickId -> [Text]
judgmentProposalKinds state brick = concat
  [ ["impact_probe" | any (probeTouches ImpactAxis (rootFor brick)) openProbes]
  , ["effort_probe" | any (probeTouches EffortAxis brick) openProbes]
  ]
  where
    openProbes = filter ((/= ProbeResolved) . judgmentProbeStatus)
      (Map.elems (judgmentStateProbes state))
    rootFor identifier = maybe identifier (rootOf state)
      (Map.lookup identifier (judgmentStateBricks state))

------------------------------------------------------------
-- Invariants and evidence helpers
------------------------------------------------------------

data JudgmentError
  = UnknownJudgmentBrick BrickId
  | UnknownImpactAssessment ImpactAssessmentId
  | UnknownImpactComparison ImpactComparisonId
  | UnknownEffortAssessment EffortAssessmentId
  | UnknownEffortComparison EffortComparisonEvidenceId
  | UnknownEffortBand Text
  | UnknownJudgmentProbe JudgmentProbeId
  | InvalidJudgmentRelationship Text
  | InvalidJudgmentTransition Text
  | InvalidEffortProfile Text
  | JudgmentInvariantViolation [Text]
  deriving stock (Eq, Show)

validateJudgmentState :: JudgmentState -> Either JudgmentError ()
validateJudgmentState state = do
  let bricks = judgmentStateBricks state
      impactAssessments = Map.elems (judgmentStateImpactAssessments state)
      impactComparisons = Map.elems (judgmentStateImpactComparisons state)
      effortAssessments = Map.elems (judgmentStateEffortAssessments state)
      effortComparisons = Map.elems (judgmentStateEffortComparisons state)
      probes = Map.elems (judgmentStateProbes state)
      bands = Map.elems (judgmentStateEffortBands state)
      bandOrdinals =
        [ (profileKey (effortBandProfile band), effortBandOrdinal band)
        | band <- bands
        ]
      violations = concat
        [ ["effort assistance limit is not positive" |
            judgmentStateEffortAssistanceLimit state < 1]
        , ["impact assessment is not root-scoped" |
            any (not . isRootId state . impactAssessmentRoot) impactAssessments]
        , ["impact comparison is not between distinct roots" |
            any (\value -> impactComparisonLeft value == impactComparisonRight value
              || not (isRootId state (impactComparisonLeft value))
              || not (isRootId state (impactComparisonRight value))) impactComparisons]
        , ["effort assessment uses an inapplicable Brick or unpublished band" |
            any (invalidEffortAssessment state) effortAssessments]
        , ["effort comparison does not use distinct applicable Bricks" |
            any (invalidEffortComparison state) effortComparisons]
        , ["judgment probe has invalid axis scope" |
            any (invalidProbe state) probes]
        , ["effort band ordinal is duplicated within a profile" |
            length bandOrdinals /= length (nub bandOrdinals)]
        , ["effort band references an unpublished profile" |
            any (\band -> Map.notMember (profileKey (effortBandProfile band))
              (judgmentStateEffortProfiles state)) bands]
        , ["active child relation is inconsistent" |
            any (invalidActiveChildren bricks) (Map.elems bricks)]
        ]
  unless (null violations) (Left (JudgmentInvariantViolation violations))

invalidEffortAssessment :: JudgmentState -> EffortAssessment -> Bool
invalidEffortAssessment state value =
  case Map.lookup (effortAssessmentBrick value) (judgmentStateBricks state) of
    Nothing -> True
    Just brick -> not (judgmentBrickEffortApplicable brick)
      || Map.lookup (bandKey (effortAssessmentBand value))
          (judgmentStateEffortBands state) /= Just (effortAssessmentBand value)

invalidEffortComparison :: JudgmentState -> EffortComparisonEvidence -> Bool
invalidEffortComparison state value =
  effortComparisonEvidenceSubject value == effortComparisonEvidenceExemplar value
  || any (not . applicableBrick) [effortComparisonEvidenceSubject value,
      effortComparisonEvidenceExemplar value]
  where
    applicableBrick identifier = maybe False judgmentBrickEffortApplicable
      (Map.lookup identifier (judgmentStateBricks state))

invalidProbe :: JudgmentState -> JudgmentProbe -> Bool
invalidProbe state probe
  | judgmentProbeLeft probe == judgmentProbeRight probe = True
  | judgmentProbeAxis probe == ImpactAxis =
      judgmentProbeScope probe /= Nothing
      || not (isRootId state (judgmentProbeLeft probe))
      || not (isRootId state (judgmentProbeRight probe))
  | judgmentProbeAxis probe == EffortAxis =
      judgmentProbeScope probe /= Nothing
      || any (not . applicable) [judgmentProbeLeft probe, judgmentProbeRight probe]
  | otherwise = judgmentProbeScope probe == Nothing
  where
    applicable identifier = maybe False judgmentBrickEffortApplicable
      (Map.lookup identifier (judgmentStateBricks state))

invalidActiveChildren :: Map BrickId JudgmentBrick -> JudgmentBrick -> Bool
invalidActiveChildren bricks parent = any invalid
  (Set.toList (judgmentBrickActiveChildren parent))
  where
    invalid identifier = case Map.lookup identifier bricks of
      Nothing -> True
      Just child -> judgmentBrickParent child /= Just (judgmentBrickId parent)
        || judgmentBrickStatus child /= Active

firstImpactAssessmentConflict ::
  ImpactAssessment -> JudgmentState -> Maybe BrickId
firstImpactAssessmentConflict assessment state = firstJust
  [ otherSide (impactAssessmentRoot assessment) comparison
  | comparison <- Map.elems (judgmentStateImpactComparisons state)
  , impactComparisonApplicable comparison
  , impactAssessmentRoot assessment `elem`
      [impactComparisonLeft comparison, impactComparisonRight comparison]
  , impactComparisonContradictsAssessments comparison state
  ]

firstEffortAssessmentConflict ::
  EffortAssessment -> JudgmentState -> Maybe BrickId
firstEffortAssessmentConflict assessment state = firstJust
  [ otherEffortSide (effortAssessmentBrick assessment) comparison
  | comparison <- Map.elems (judgmentStateEffortComparisons state)
  , effortComparisonEvidenceApplicable comparison
  , effortAssessmentBrick assessment `elem`
      [ effortComparisonEvidenceSubject comparison
      , effortComparisonEvidenceExemplar comparison
      ]
  , effortComparisonContradictsAssessments comparison state
  ]

impactComparisonContradictsAssessments :: ImpactComparison -> JudgmentState -> Bool
impactComparisonContradictsAssessments comparison state = case
    ( currentImpactAssessment state (impactComparisonLeft comparison)
    , currentImpactAssessment state (impactComparisonRight comparison)
    ) of
  (Just left, Just right) -> not (relativeMatches
    (compare (impactAssessmentImpact left) (impactAssessmentImpact right))
    (impactComparisonResult comparison))
  _ -> False

impactComparisonContradicts :: ImpactComparison -> JudgmentState -> Bool
impactComparisonContradicts comparison state = maybe False
  ((/= impactRelation comparison) . impactRelation)
  (currentImpactComparisonFor state
    (impactComparisonLeft comparison) (impactComparisonRight comparison))

effortComparisonContradictsAssessments ::
  EffortComparisonEvidence -> JudgmentState -> Bool
effortComparisonContradictsAssessments comparison state = case
    ( currentEffortAssessment state (effortComparisonEvidenceSubject comparison)
    , currentEffortAssessment state (effortComparisonEvidenceExemplar comparison)
    ) of
  (Just subject, Just exemplar) ->
    broadEffortRelation (effortComparisonEvidenceResult comparison)
      /= compare
        (effortBandOrdinal (effortAssessmentBand subject))
        (effortBandOrdinal (effortAssessmentBand exemplar))
  _ -> False

effortComparisonContradicts :: EffortComparisonEvidence -> JudgmentState -> Bool
effortComparisonContradicts comparison state = maybe False
  ((/= broadEffortRelation (effortComparisonEvidenceResult comparison))
    . broadEffortRelation . effortComparisonEvidenceResult)
  (currentEffortComparisonFor state
    (effortComparisonEvidenceSubject comparison)
    (effortComparisonEvidenceExemplar comparison))

relativeMatches :: Ordering -> RelativeAssessment -> Bool
relativeMatches ordering result = case (ordering, result) of
  (LT, RelativelyLess) -> True
  (EQ, RelativelySimilar) -> True
  (GT, RelativelyMore) -> True
  _ -> False

broadEffortRelation :: EffortComparison -> Ordering
broadEffortRelation result = case result of
  MuchLessEffort -> LT
  ALittleLessEffort -> LT
  SimilarEffort -> EQ
  ALittleMoreEffort -> GT
  MuchMoreEffort -> GT

impactRelation :: ImpactComparison -> (BrickId, BrickId, Ordering)
impactRelation value = orderedRelation (impactComparisonLeft value)
  (impactComparisonRight value) (relativeOrdering (impactComparisonResult value))

relativeOrdering :: RelativeAssessment -> Ordering
relativeOrdering value = case value of
  RelativelyLess -> LT
  RelativelySimilar -> EQ
  RelativelyMore -> GT

orderedRelation :: Ord identifier =>
  identifier -> identifier -> Ordering -> (identifier, identifier, Ordering)
orderedRelation left right ordering
  | left <= right = (left, right, ordering)
  | otherwise = (right, left, invertOrdering ordering)

invertOrdering :: Ordering -> Ordering
invertOrdering ordering = case ordering of
  LT -> GT
  EQ -> EQ
  GT -> LT

currentImpactComparisonFor ::
  JudgmentState -> BrickId -> BrickId -> Maybe ImpactComparison
currentImpactComparisonFor state left right = chooseAuthoritative
  impactComparisonAuthority impactComparisonRecordedAt
  [ value
  | value <- Map.elems (judgmentStateImpactComparisons state)
  , impactComparisonApplicable value
  , samePair left right (impactComparisonLeft value) (impactComparisonRight value)
  ]

currentEffortComparisonFor ::
  JudgmentState -> BrickId -> BrickId -> Maybe EffortComparisonEvidence
currentEffortComparisonFor state left right = chooseAuthoritative
  effortComparisonEvidenceAuthority effortComparisonEvidenceRecordedAt
  [ value
  | value <- Map.elems (judgmentStateEffortComparisons state)
  , effortComparisonEvidenceApplicable value
  , samePair left right (effortComparisonEvidenceSubject value)
      (effortComparisonEvidenceExemplar value)
  ]

authorityImpactConflict :: Maybe ImpactAssessment -> [ImpactAssessment] -> Bool
authorityImpactConflict current history = case current of
  Nothing -> False
  Just selected -> any (\value -> impactAssessmentApplicable value
      && impactAssessmentAuthority value /= Human
      && impactAssessmentImpact value /= impactAssessmentImpact selected) history

authorityEffortConflict :: Maybe EffortAssessment -> [EffortAssessment] -> Bool
authorityEffortConflict current history = case current of
  Nothing -> False
  Just selected -> any (\value -> effortAssessmentApplicable value
      && effortAssessmentAuthority value /= Human
      && effortBandOrdinal (effortAssessmentBand value)
        /= effortBandOrdinal (effortAssessmentBand selected)) history

humanEvidenceExists :: (value -> Authority) -> [value] -> Bool
humanEvidenceExists authority = any ((== Human) . authority)

openRecalibrationProbe ::
  JudgmentAxis -> BrickId -> BrickId -> Text -> UTCTime -> JudgmentState ->
  Either JudgmentError (Maybe JudgmentProbe, JudgmentState)
openRecalibrationProbe axis left right reason now state =
  case find (\probe -> judgmentProbeAxis probe == axis
      && judgmentProbePurpose probe == Recalibration
      && judgmentProbeStatus probe == ProbeOpen
      && samePair left right (judgmentProbeLeft probe) (judgmentProbeRight probe))
      (Map.elems (judgmentStateProbes state)) of
    Just _ -> pure (Nothing, state)
    Nothing -> do
      (probe, next) <- createProbe axis left right Recalibration reason now state
      pure (Just probe, next)

resolveComparisonProbes ::
  JudgmentAxis -> BrickId -> BrickId -> UTCTime ->
  Map JudgmentProbeId JudgmentProbe -> Map JudgmentProbeId JudgmentProbe
resolveComparisonProbes axis left right now = Map.map resolve
  where
    resolve probe
      | judgmentProbeAxis probe == axis
          && judgmentProbeStatus probe `elem` [ProbeOpen, ProbeDeferred]
          && samePair left right (judgmentProbeLeft probe) (judgmentProbeRight probe) =
            probe {judgmentProbeStatus = ProbeResolved,
              judgmentProbeResolvedAt = Just now}
      | otherwise = probe

resolveForTerminal :: BrickId -> UTCTime -> JudgmentProbe -> JudgmentProbe
resolveForTerminal identifier now probe
  | judgmentProbeStatus probe `elem` [ProbeOpen, ProbeDeferred]
      && identifier `elem` [judgmentProbeLeft probe, judgmentProbeRight probe] =
        probe {judgmentProbeStatus = ProbeResolved,
          judgmentProbeResolvedAt = Just now}
  | otherwise = probe

probeTouches :: JudgmentAxis -> BrickId -> JudgmentProbe -> Bool
probeTouches axis identifier probe = judgmentProbeAxis probe == axis
  && judgmentProbeStatus probe /= ProbeResolved
  && identifier `elem` [judgmentProbeLeft probe, judgmentProbeRight probe]

comparisonIsCurrent :: Eq value =>
  (value -> Authority) -> (value -> UTCTime) -> (value -> Bool) ->
  (value -> BrickId) -> (value -> BrickId) -> value -> [value] -> Bool
comparisonIsCurrent authority recorded applicable left right candidate values =
  applicable candidate && chooseAuthoritative authority recorded
    [value | value <- values, applicable value,
      samePair (left candidate) (right candidate) (left value) (right value)]
      == Just candidate

requireRoot :: BrickId -> JudgmentState -> Either JudgmentError JudgmentBrick
requireRoot identifier state = do
  brick <- requireBrick identifier state
  unless (judgmentBrickParent brick == Nothing)
    (Left (InvalidJudgmentRelationship "impact is root-scoped"))
  pure brick

requireEffortBrick ::
  Bool -> BrickId -> JudgmentState -> Either JudgmentError JudgmentBrick
requireEffortBrick requireActive identifier state = do
  brick <- requireBrick identifier state
  unless (judgmentBrickEffortApplicable brick)
    (Left (InvalidJudgmentRelationship "effort is disabled for this Brick behavior"))
  when (requireActive && judgmentBrickStatus brick /= Active)
    (Left (InvalidJudgmentTransition "effort classification requires an active Brick"))
  pure brick

requireBrick :: BrickId -> JudgmentState -> Either JudgmentError JudgmentBrick
requireBrick identifier state = maybe (Left (UnknownJudgmentBrick identifier)) Right
  (Map.lookup identifier (judgmentStateBricks state))

requireProbe ::
  JudgmentProbeId -> JudgmentState -> Either JudgmentError JudgmentProbe
requireProbe identifier state = maybe (Left (UnknownJudgmentProbe identifier)) Right
  (Map.lookup identifier (judgmentStateProbes state))

isRootId :: JudgmentState -> BrickId -> Bool
isRootId state identifier = maybe False ((== Nothing) . judgmentBrickParent)
  (Map.lookup identifier (judgmentStateBricks state))

rootOf :: JudgmentState -> JudgmentBrick -> BrickId
rootOf state brick = case judgmentBrickParent brick of
  Nothing -> judgmentBrickId brick
  Just parent -> maybe parent (rootOf state)
    (Map.lookup parent (judgmentStateBricks state))

otherSide :: BrickId -> ImpactComparison -> Maybe BrickId
otherSide identifier comparison
  | impactComparisonLeft comparison == identifier = Just (impactComparisonRight comparison)
  | impactComparisonRight comparison == identifier = Just (impactComparisonLeft comparison)
  | otherwise = Nothing

otherEffortSide :: BrickId -> EffortComparisonEvidence -> Maybe BrickId
otherEffortSide identifier comparison
  | effortComparisonEvidenceSubject comparison == identifier =
      Just (effortComparisonEvidenceExemplar comparison)
  | effortComparisonEvidenceExemplar comparison == identifier =
      Just (effortComparisonEvidenceSubject comparison)
  | otherwise = Nothing

samePair :: Eq value => value -> value -> value -> value -> Bool
samePair first second third fourth =
  (first == third && second == fourth) || (first == fourth && second == third)

profileKey :: EffortProfile -> Text
profileKey profile = effortProfileId profile <> "@"
  <> Text.pack (show (effortProfileVersion profile))

bandKey :: EffortBand -> Text
bandKey value = bandKeyFrom (effortBandProfile value) (effortBandId value)

bandKeyFrom :: EffortProfile -> Text -> Text
bandKeyFrom profile identifier = profileKey profile <> ":" <> identifier

opaque :: Text -> Integer -> Text
opaque prefix ordinal = "judgment:" <> prefix <> ":"
  <> Text.justifyRight 8 '0' (Text.pack (show ordinal))

firstJust :: [Maybe value] -> Maybe value
firstJust = foldr (\candidate rest -> case candidate of
  Just _ -> candidate
  Nothing -> rest) Nothing

lastMay :: [value] -> Maybe value
lastMay = foldl (\_ value -> Just value) Nothing

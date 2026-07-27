{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Strict, sibling-scoped human priority and its retained evidence.
--
-- Priority is deliberately independent from eligibility and forecast data.
-- Every active Brick has one strict position from creation; low confidence is
-- represented as evidence metadata and never as equality.
module LittleAnt.V1.Priority
  ( InsertionStatus (..)
  , JudgmentAxis (..)
  , JudgmentProbe (..)
  , JudgmentProbeId (..)
  , JudgmentProbeStatus (..)
  , PriorityBrick (..)
  , PriorityComparisonSkip (..)
  , PriorityEvidenceView (..)
  , PriorityError (..)
  , PriorityInsertion (..)
  , PriorityInsertionId (..)
  , PriorityJudgment (..)
  , PriorityJudgmentId (..)
  , PriorityRecalibration (..)
  , PriorityRecalibrationId (..)
  , PriorityRecalibrationStatus (..)
  , PriorityScope (..)
  , PriorityScopeId (..)
  , PrioritySkipKind (..)
  , PriorityState (..)
  , PriorityView (..)
  , PriorityViewItem (..)
  , ProbePurpose (..)
  , answerPriorityInsertion
  , commitPriorityRecalibration
  , configurePriorityState
  , createPriorityChild
  , createPriorityRoot
  , createStrictRootFixture
  , deferJudgmentProbe
  , invalidatePriorityJudgmentsFor
  , emptyPriorityState
  , movePrioritySubtree
  , openPriorityProbe
  , priorityEvidence
  , priorityInsertionProjection
  , priorityJudgmentProjection
  , priorityProposalKinds
  , priorityRecalibrationProjection
  , priorityRootScopeId
  , priorityScopeProjection
  , priorityView
  , priorityViewItem
  , probeProjection
  , recordPriorityDependency
  , registerPriorityBrick
  , recordPriorityJudgment
  , reopenJudgmentProbe
  , reopenPriorityInsertion
  , setPriorityBrickStatus
  , skipPriorityComparison
  , transferPriorityChildren
  , validatePriorityState
  ) where

import Control.Monad (foldM, unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey, Value (..),
   defaultOptions, genericParseJSON, genericToJSON, withText)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import Data.Char (ord, toLower)
import Data.List (elemIndex, find, nub, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe, isJust, mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain (Authority (..), BrickId (..), BrickStatus (..))

------------------------------------------------------------
-- Closed vocabulary and identity
------------------------------------------------------------

data PrioritySkipKind = Unresolved | TieBreakForMe
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data InsertionStatus = InsertionOpen | InsertionResolved | InsertionDeferred
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data PriorityRecalibrationStatus = RecalibrationOpen | RecalibrationResolved
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data JudgmentAxis = PriorityAxis | ImpactAxis | EffortAxis
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data ProbePurpose = Discovery | Validation | Recalibration
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data JudgmentProbeStatus = ProbeOpen | ProbeDeferred | ProbeResolved
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON PrioritySkipKind where toJSON = enumJSON prioritySkipKindText
instance FromJSON PrioritySkipKind where
  parseJSON = parseEnumJSON "PrioritySkipKind"
    [(prioritySkipKindText value, value) | value <- [minBound .. maxBound]]
instance ToJSON InsertionStatus where toJSON = enumJSON insertionStatusText
instance FromJSON InsertionStatus where
  parseJSON = parseEnumJSON "InsertionStatus"
    [(insertionStatusText value, value) | value <- [minBound .. maxBound]]
instance ToJSON PriorityRecalibrationStatus where
  toJSON = enumJSON recalibrationStatusText
instance FromJSON PriorityRecalibrationStatus where
  parseJSON = parseEnumJSON "PriorityRecalibrationStatus"
    [(recalibrationStatusText value, value) | value <- [minBound .. maxBound]]
instance ToJSON JudgmentAxis where toJSON = enumJSON judgmentAxisText
instance FromJSON JudgmentAxis where
  parseJSON = parseEnumJSON "JudgmentAxis"
    [(judgmentAxisText value, value) | value <- [minBound .. maxBound]]
instance ToJSON ProbePurpose where toJSON = enumJSON probePurposeText
instance FromJSON ProbePurpose where
  parseJSON = parseEnumJSON "ProbePurpose"
    [(probePurposeText value, value) | value <- [minBound .. maxBound]]
instance ToJSON JudgmentProbeStatus where toJSON = enumJSON probeStatusText
instance FromJSON JudgmentProbeStatus where
  parseJSON = parseEnumJSON "JudgmentProbeStatus"
    [(probeStatusText value, value) | value <- [minBound .. maxBound]]

enumJSON :: (value -> Text) -> value -> Value
enumJSON render = toJSON . render

parseEnumJSON :: String -> [(Text, value)] -> Value -> AesonTypes.Parser value
parseEnumJSON name values = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate values)

prioritySkipKindText :: PrioritySkipKind -> Text
prioritySkipKindText value = case value of
  Unresolved -> "unresolved"
  TieBreakForMe -> "tie_break_for_me"

insertionStatusText :: InsertionStatus -> Text
insertionStatusText value = case value of
  InsertionOpen -> "open"
  InsertionResolved -> "resolved"
  InsertionDeferred -> "deferred"

recalibrationStatusText :: PriorityRecalibrationStatus -> Text
recalibrationStatusText value = case value of
  RecalibrationOpen -> "open"
  RecalibrationResolved -> "resolved"

judgmentAxisText :: JudgmentAxis -> Text
judgmentAxisText value = case value of
  PriorityAxis -> "priority"
  ImpactAxis -> "impact"
  EffortAxis -> "effort"

probePurposeText :: ProbePurpose -> Text
probePurposeText value = case value of
  Discovery -> "discovery"
  Validation -> "validation"
  Recalibration -> "recalibration"

probeStatusText :: JudgmentProbeStatus -> Text
probeStatusText value = case value of
  ProbeOpen -> "open"
  ProbeDeferred -> "deferred"
  ProbeResolved -> "resolved"

newtype PriorityScopeId = PriorityScopeId { unPriorityScopeId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

newtype PriorityInsertionId = PriorityInsertionId { unPriorityInsertionId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

newtype PriorityJudgmentId = PriorityJudgmentId { unPriorityJudgmentId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

newtype PriorityRecalibrationId = PriorityRecalibrationId
  { unPriorityRecalibrationId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

newtype JudgmentProbeId = JudgmentProbeId { unJudgmentProbeId :: Text }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

------------------------------------------------------------
-- Canonical state and projections
------------------------------------------------------------

data PriorityBrick = PriorityBrick
  { priorityBrickId :: BrickId
  , priorityBrickTitle :: Text
  , priorityBrickParent :: Maybe BrickId
  , priorityBrickStatus :: BrickStatus
  }
  deriving stock (Eq, Show, Generic)

data PriorityScope = PriorityScope
  { priorityScopeId :: PriorityScopeId
  , priorityScopeParent :: Maybe BrickId
  , priorityScopeMembers :: [BrickId]
  , priorityScopeRevision :: Integer
  }
  deriving stock (Eq, Show, Generic)

data PriorityInsertion = PriorityInsertion
  { priorityInsertionId :: PriorityInsertionId
  , priorityInsertionBrick :: BrickId
  , priorityInsertionScope :: PriorityScopeId
  , priorityInsertionStatus :: InsertionStatus
  , priorityInsertionCurrentCandidate :: Maybe BrickId
  , priorityInsertionComparisonsRecorded :: Integer
  , priorityInsertionConsecutiveSkips :: Integer
  , priorityInsertionRandomEvidence :: Text
  , priorityInsertionStartedAt :: UTCTime
  , priorityInsertionFinishedAt :: Maybe UTCTime
  , priorityInsertionSearchLow :: Int
  , priorityInsertionSearchHigh :: Int
  , priorityInsertionPreviousCandidate :: Maybe BrickId
  , priorityInsertionCandidateDistanceFromPrevious :: Maybe Int
  }
  deriving stock (Eq, Show, Generic)

data PriorityJudgment = PriorityJudgment
  { priorityJudgmentId :: PriorityJudgmentId
  , priorityJudgmentScope :: PriorityScopeId
  , priorityJudgmentScopeRevision :: Integer
  , priorityJudgmentMoreImportant :: BrickId
  , priorityJudgmentLessImportant :: BrickId
  , priorityJudgmentAuthority :: Authority
  , priorityJudgmentRecordedAt :: UTCTime
  , priorityJudgmentReason :: Maybe Text
  , priorityJudgmentApplicable :: Bool
  }
  deriving stock (Eq, Show, Generic)

data PriorityComparisonSkip = PriorityComparisonSkip
  { priorityComparisonSkipId :: Text
  , priorityComparisonSkipInsertion :: PriorityInsertionId
  , priorityComparisonSkipCandidate :: BrickId
  , priorityComparisonSkipKind :: PrioritySkipKind
  , priorityComparisonSkipRecordedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data PriorityRecalibration = PriorityRecalibration
  { priorityRecalibrationId :: PriorityRecalibrationId
  , priorityRecalibrationScope :: PriorityScopeId
  , priorityRecalibrationSegment :: [BrickId]
  , priorityRecalibrationProposedOrder :: [BrickId]
  , priorityRecalibrationStatus :: PriorityRecalibrationStatus
  , priorityRecalibrationCreatedAt :: UTCTime
  , priorityRecalibrationResolvedAt :: Maybe UTCTime
  , priorityRecalibrationTriggeringJudgment :: PriorityJudgmentId
  }
  deriving stock (Eq, Show, Generic)

data JudgmentProbe = JudgmentProbe
  { judgmentProbeId :: JudgmentProbeId
  , judgmentProbeAxis :: JudgmentAxis
  , judgmentProbePurpose :: ProbePurpose
  , judgmentProbeScope :: Maybe PriorityScopeId
  , judgmentProbeLeft :: BrickId
  , judgmentProbeRight :: BrickId
  , judgmentProbeReason :: Text
  , judgmentProbeStatus :: JudgmentProbeStatus
  , judgmentProbeCreatedAt :: UTCTime
  , judgmentProbeResolvedAt :: Maybe UTCTime
  }
  deriving stock (Eq, Show, Generic)

data PriorityEvidenceView = PriorityEvidenceView
  { priorityEvidenceScope :: PriorityScopeId
  , priorityEvidenceLeft :: BrickId
  , priorityEvidenceRight :: BrickId
  , priorityEvidenceCurrentMoreImportant :: Maybe BrickId
  , priorityEvidenceConfidence :: Double
  , priorityEvidenceConfidenceReasons :: [Text]
  , priorityEvidenceProvisional :: Bool
  , priorityEvidenceHistory :: [PriorityJudgment]
  , priorityEvidenceTransitiveSupport :: [[BrickId]]
  , priorityEvidenceContainsEquality :: Bool
  }
  deriving stock (Eq, Show, Generic)

data PriorityViewItem = PriorityViewItem
  { priorityViewItemBrick :: BrickId
  , priorityViewItemScope :: PriorityScopeId
  , priorityViewItemSiblingIndex :: Int
  , priorityViewItemTreePath :: [Int]
  , priorityViewItemConfidence :: Double
  , priorityViewItemConfidenceReasons :: [Text]
  , priorityViewItemProvisional :: Bool
  }
  deriving stock (Eq, Show, Generic)

data PriorityView = PriorityView
  { priorityViewRootScope :: PriorityScopeId
  , priorityViewRevisionFingerprint :: Text
  , priorityViewItems :: [PriorityViewItem]
  }
  deriving stock (Eq, Show, Generic)

data PriorityState = PriorityState
  { priorityStateNextOrdinal :: Integer
  , priorityStateNearbyDistance :: Int
  , priorityStateSkipLimit :: Int
  , priorityStateBricks :: Map BrickId PriorityBrick
  , priorityStateScopes :: Map PriorityScopeId PriorityScope
  , priorityStateInsertions :: Map PriorityInsertionId PriorityInsertion
  , priorityStateJudgments :: Map PriorityJudgmentId PriorityJudgment
  , priorityStateSkips :: [PriorityComparisonSkip]
  , priorityStateRecalibrations :: Map PriorityRecalibrationId PriorityRecalibration
  , priorityStateProbes :: Map JudgmentProbeId JudgmentProbe
  , priorityStateProposalPressure :: Set BrickId
  , priorityStateDependencies :: Set (BrickId, BrickId)
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON PriorityBrick where toJSON = genericToJSON (recordOptions "priorityBrick")
instance FromJSON PriorityBrick where parseJSON = genericParseJSON (recordOptions "priorityBrick")
instance ToJSON PriorityScope where toJSON = genericToJSON (recordOptions "priorityScope")
instance FromJSON PriorityScope where parseJSON = genericParseJSON (recordOptions "priorityScope")
instance ToJSON PriorityInsertion where toJSON = genericToJSON (recordOptions "priorityInsertion")
instance FromJSON PriorityInsertion where parseJSON = genericParseJSON (recordOptions "priorityInsertion")
instance ToJSON PriorityJudgment where toJSON = genericToJSON (recordOptions "priorityJudgment")
instance FromJSON PriorityJudgment where parseJSON = genericParseJSON (recordOptions "priorityJudgment")
instance ToJSON PriorityComparisonSkip where toJSON = genericToJSON (recordOptions "priorityComparisonSkip")
instance FromJSON PriorityComparisonSkip where parseJSON = genericParseJSON (recordOptions "priorityComparisonSkip")
instance ToJSON PriorityRecalibration where toJSON = genericToJSON (recordOptions "priorityRecalibration")
instance FromJSON PriorityRecalibration where parseJSON = genericParseJSON (recordOptions "priorityRecalibration")
instance ToJSON JudgmentProbe where toJSON = genericToJSON (recordOptions "judgmentProbe")
instance FromJSON JudgmentProbe where parseJSON = genericParseJSON (recordOptions "judgmentProbe")
instance ToJSON PriorityEvidenceView where toJSON = genericToJSON (recordOptions "priorityEvidence")
instance FromJSON PriorityEvidenceView where parseJSON = genericParseJSON (recordOptions "priorityEvidence")
instance ToJSON PriorityViewItem where toJSON = genericToJSON (recordOptions "priorityViewItem")
instance FromJSON PriorityViewItem where parseJSON = genericParseJSON (recordOptions "priorityViewItem")
instance ToJSON PriorityView where toJSON = genericToJSON (recordOptions "priorityView")
instance FromJSON PriorityView where parseJSON = genericParseJSON (recordOptions "priorityView")
instance ToJSON PriorityState where toJSON = genericToJSON (recordOptions "priorityState")
instance FromJSON PriorityState where parseJSON = genericParseJSON (recordOptions "priorityState")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  { AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)
  }
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLower first : rest)

priorityRootScopeId :: PriorityScopeId
priorityRootScopeId = PriorityScopeId "core/root-priority"

emptyPriorityState :: PriorityState
emptyPriorityState = PriorityState
  { priorityStateNextOrdinal = 1
  , priorityStateNearbyDistance = 3
  , priorityStateSkipLimit = 2
  , priorityStateBricks = Map.empty
  , priorityStateScopes = Map.singleton priorityRootScopeId PriorityScope
      { priorityScopeId = priorityRootScopeId
      , priorityScopeParent = Nothing
      , priorityScopeMembers = []
      , priorityScopeRevision = 0
      }
  , priorityStateInsertions = Map.empty
  , priorityStateJudgments = Map.empty
  , priorityStateSkips = []
  , priorityStateRecalibrations = Map.empty
  , priorityStateProbes = Map.empty
  , priorityStateProposalPressure = Set.empty
  , priorityStateDependencies = Set.empty
  }

configurePriorityState :: Int -> Int -> PriorityState -> Either PriorityError PriorityState
configurePriorityState nearbyDistance skipLimit state = do
  when (nearbyDistance < 1) (Left (InvalidPriorityConfig "nearby distance must be positive"))
  when (skipLimit < 1) (Left (InvalidPriorityConfig "skip limit must be positive"))
  pure state
    { priorityStateNearbyDistance = nearbyDistance
    , priorityStateSkipLimit = skipLimit
    }

data PriorityError
  = UnknownPriorityBrick BrickId
  | UnknownPriorityScope PriorityScopeId
  | UnknownPriorityInsertion PriorityInsertionId
  | UnknownPriorityRecalibration PriorityRecalibrationId
  | InvalidPriorityConfig Text
  | InvalidPriorityRelationship Text
  | InvalidPriorityTransition Text
  | PriorityInvariantViolation [Text]
  deriving stock (Eq, Show)

------------------------------------------------------------
-- Creation and binary insertion
------------------------------------------------------------

createPriorityRoot ::
  Text -> Text -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityBrick, PriorityInsertion, PriorityState)
createPriorityRoot title randomEvidence now =
  createPriorityBrick Nothing title randomEvidence now

createPriorityChild ::
  BrickId -> Text -> Text -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityBrick, PriorityInsertion, PriorityState)
createPriorityChild parent title randomEvidence now =
  createPriorityBrick (Just parent) title randomEvidence now

-- | Register a Brick whose opaque identity was allocated by the domain
-- authority. This is the composition-safe counterpart of the standalone
-- priority fixture constructors.
registerPriorityBrick ::
  BrickId -> Maybe BrickId -> Text -> Text -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityInsertion, PriorityState)
registerPriorityBrick identifier parent title randomEvidence now state = do
  when (Map.member identifier (priorityStateBricks state))
    (Left (InvalidPriorityRelationship "Brick is already registered in priority"))
  when (Text.null (Text.strip title))
    (Left (InvalidPriorityRelationship "Brick title must not be empty"))
  case parent of
    Nothing -> pure ()
    Just parentId -> do
      parentBrick <- requireBrick parentId state
      unless (priorityBrickStatus parentBrick == Active)
        (Left (InvalidPriorityRelationship "parent Brick is terminal"))
  scope <- requireScope (scopeIdForParent parent) state
  let ordinal = priorityStateNextOrdinal state
      insertionId = PriorityInsertionId (opaqueText "priority-insertion" ordinal)
      previousMembers = priorityScopeMembers scope
      firstInScope = null previousMembers
      members = previousMembers <> [identifier]
      nextScope = scope
        { priorityScopeMembers = members
        , priorityScopeRevision = priorityScopeRevision scope + 1
        }
      insertion = PriorityInsertion
        { priorityInsertionId = insertionId
        , priorityInsertionBrick = identifier
        , priorityInsertionScope = priorityScopeId scope
        , priorityInsertionStatus = if firstInScope
            then InsertionResolved else InsertionOpen
        , priorityInsertionCurrentCandidate = if firstInScope then Nothing
            else atMay previousMembers (length previousMembers `div` 2)
        , priorityInsertionComparisonsRecorded = 0
        , priorityInsertionConsecutiveSkips = 0
        , priorityInsertionRandomEvidence = randomEvidence
        , priorityInsertionStartedAt = now
        , priorityInsertionFinishedAt = if firstInScope then Just now else Nothing
        , priorityInsertionSearchLow = 0
        , priorityInsertionSearchHigh = length previousMembers
        , priorityInsertionPreviousCandidate = Nothing
        , priorityInsertionCandidateDistanceFromPrevious = Nothing
        }
      brick = PriorityBrick identifier title parent Active
      childScope = PriorityScope
        { priorityScopeId = scopeIdForParent (Just identifier)
        , priorityScopeParent = Just identifier
        , priorityScopeMembers = []
        , priorityScopeRevision = 0
        }
      next = state
        { priorityStateNextOrdinal = ordinal + 1
        , priorityStateBricks = Map.insert identifier brick
            (priorityStateBricks state)
        , priorityStateScopes = Map.insert (priorityScopeId childScope) childScope
            (Map.insert (priorityScopeId nextScope) nextScope
              (priorityStateScopes state))
        , priorityStateInsertions = Map.insert insertionId insertion
            (priorityStateInsertions state)
        }
  validatePriorityState next
  pure (insertion, next)

createPriorityBrick ::
  Maybe BrickId -> Text -> Text -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityBrick, PriorityInsertion, PriorityState)
createPriorityBrick parent title randomEvidence now state = do
  when (Text.null (Text.strip title))
    (Left (InvalidPriorityRelationship "Brick title must not be empty"))
  case parent of
    Nothing -> pure ()
    Just parentId -> do
      parentBrick <- requireBrick parentId state
      unless (priorityBrickStatus parentBrick == Active)
        (Left (InvalidPriorityRelationship "parent Brick is terminal"))
  scope <- requireScope (scopeIdForParent parent) state
  let ordinal = priorityStateNextOrdinal state
      identifier = BrickId (opaqueText "priority-brick" ordinal)
      insertionId = PriorityInsertionId (opaqueText "priority-insertion" (ordinal + 1))
      brick = PriorityBrick identifier title parent Active
      previousMembers = priorityScopeMembers scope
      firstInScope = null previousMembers
      members = previousMembers <> [identifier]
      nextScope = scope
        { priorityScopeMembers = members
        , priorityScopeRevision = priorityScopeRevision scope + 1
        }
      candidate = if firstInScope then Nothing
        else atMay previousMembers (length previousMembers `div` 2)
      insertion = PriorityInsertion
        { priorityInsertionId = insertionId
        , priorityInsertionBrick = identifier
        , priorityInsertionScope = priorityScopeId scope
        , priorityInsertionStatus = if firstInScope
            then InsertionResolved else InsertionOpen
        , priorityInsertionCurrentCandidate = candidate
        , priorityInsertionComparisonsRecorded = 0
        , priorityInsertionConsecutiveSkips = 0
        , priorityInsertionRandomEvidence = randomEvidence
        , priorityInsertionStartedAt = now
        , priorityInsertionFinishedAt = if firstInScope then Just now else Nothing
        , priorityInsertionSearchLow = 0
        , priorityInsertionSearchHigh = length previousMembers
        , priorityInsertionPreviousCandidate = Nothing
        , priorityInsertionCandidateDistanceFromPrevious = Nothing
        }
      childScope = PriorityScope
        { priorityScopeId = scopeIdForParent (Just identifier)
        , priorityScopeParent = Just identifier
        , priorityScopeMembers = []
        , priorityScopeRevision = 0
        }
      next = state
        { priorityStateNextOrdinal = ordinal + 2
        , priorityStateBricks = Map.insert identifier brick (priorityStateBricks state)
        , priorityStateScopes = Map.insert (priorityScopeId childScope) childScope
            (Map.insert (priorityScopeId nextScope) nextScope
              (priorityStateScopes state))
        , priorityStateInsertions = Map.insert insertionId insertion
            (priorityStateInsertions state)
        }
  validatePriorityState next
  pure (brick, insertion, next)

answerPriorityInsertion ::
  PriorityInsertionId -> Bool -> Authority -> Maybe Text -> UTCTime ->
  PriorityState ->
  Either PriorityError (PriorityInsertion, PriorityJudgment, PriorityState)
answerPriorityInsertion identifier answer authority reason now state = do
  insertion <- requireInsertion identifier state
  unless (priorityInsertionStatus insertion == InsertionOpen)
    (Left (InvalidPriorityTransition "priority insertion is not open"))
  candidate <- maybe
    (Left (InvalidPriorityTransition "priority insertion has no candidate"))
    Right
    (priorityInsertionCurrentCandidate insertion)
  scope <- requireScope (priorityInsertionScope insertion) state
  let brick = priorityInsertionBrick insertion
      oldMembers = filter (/= brick) (priorityScopeMembers scope)
  candidateIndex <- maybe
    (Left (InvalidPriorityRelationship "insertion candidate is outside its scope"))
    Right
    (elemIndex candidate oldMembers)
  let nextLow = if answer then priorityInsertionSearchLow insertion
        else candidateIndex + 1
      nextHigh = if answer then candidateIndex
        else priorityInsertionSearchHigh insertion
  when (nextLow > nextHigh)
    (Left (InvalidPriorityTransition "binary insertion bounds crossed"))
  let complete = nextLow == nextHigh
      nextCandidate = if complete then Nothing
        else atMay oldMembers ((nextLow + nextHigh) `div` 2)
      placedMembers = insertAt nextLow brick oldMembers
      nextScope = scope
        { priorityScopeMembers = placedMembers
        , priorityScopeRevision = priorityScopeRevision scope + 1
        }
      nextInsertion = insertion
        { priorityInsertionStatus = if complete then InsertionResolved else InsertionOpen
        , priorityInsertionCurrentCandidate = nextCandidate
        , priorityInsertionComparisonsRecorded =
            priorityInsertionComparisonsRecorded insertion + 1
        , priorityInsertionConsecutiveSkips = 0
        , priorityInsertionFinishedAt = if complete then Just now else Nothing
        , priorityInsertionSearchLow = nextLow
        , priorityInsertionSearchHigh = nextHigh
        , priorityInsertionPreviousCandidate = Just candidate
        , priorityInsertionCandidateDistanceFromPrevious =
            candidateDistance placedMembers candidate nextCandidate
        }
      judgmentOrdinal = priorityStateNextOrdinal state
      judgment = PriorityJudgment
        { priorityJudgmentId = PriorityJudgmentId
            (opaqueText "priority-judgment" judgmentOrdinal)
        , priorityJudgmentScope = priorityScopeId scope
        , priorityJudgmentScopeRevision = priorityScopeRevision scope
        , priorityJudgmentMoreImportant = if answer then brick else candidate
        , priorityJudgmentLessImportant = if answer then candidate else brick
        , priorityJudgmentAuthority = authority
        , priorityJudgmentRecordedAt = now
        , priorityJudgmentReason = reason
        , priorityJudgmentApplicable = True
        }
      next = state
        { priorityStateNextOrdinal = judgmentOrdinal + 1
        , priorityStateScopes = Map.insert (priorityScopeId scope) nextScope
            (priorityStateScopes state)
        , priorityStateInsertions = Map.insert identifier nextInsertion
            (priorityStateInsertions state)
        , priorityStateJudgments = Map.insert (priorityJudgmentId judgment) judgment
            (priorityStateJudgments state)
        }
  validatePriorityState next
  pure (nextInsertion, judgment, next)

skipPriorityComparison ::
  PriorityInsertionId -> PrioritySkipKind -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityInsertion, PriorityComparisonSkip, PriorityState)
skipPriorityComparison identifier kind now state = do
  insertion <- requireInsertion identifier state
  unless (priorityInsertionStatus insertion == InsertionOpen)
    (Left (InvalidPriorityTransition "priority insertion is not open"))
  candidate <- maybe
    (Left (InvalidPriorityTransition "priority insertion has no candidate"))
    Right
    (priorityInsertionCurrentCandidate insertion)
  scope <- requireScope (priorityInsertionScope insertion) state
  let ordinal = priorityStateNextOrdinal state
      skip = PriorityComparisonSkip
        { priorityComparisonSkipId = opaqueText "priority-skip" ordinal
        , priorityComparisonSkipInsertion = identifier
        , priorityComparisonSkipCandidate = candidate
        , priorityComparisonSkipKind = kind
        , priorityComparisonSkipRecordedAt = now
        }
      skippedCount = priorityInsertionConsecutiveSkips insertion + 1
      atThreshold = skippedCount >= fromIntegral (priorityStateSkipLimit state)
      tieBrokenMembers = case kind of
        Unresolved -> priorityScopeMembers scope
        TieBreakForMe -> replaySafeTieBreak insertion candidate
          (priorityScopeMembers scope)
      alternative = if atThreshold then Nothing
        else Just (fromMaybe candidate
          (nearbyDistinctCandidate state insertion candidate tieBrokenMembers))
      mustDefer = atThreshold
      nextScope = scope
        { priorityScopeMembers = tieBrokenMembers
        , priorityScopeRevision = priorityScopeRevision scope
            + if tieBrokenMembers == priorityScopeMembers scope then 0 else 1
        }
      nextInsertion = insertion
        { priorityInsertionStatus = if mustDefer
            then InsertionDeferred else InsertionOpen
        , priorityInsertionCurrentCandidate = if mustDefer then Nothing else alternative
        , priorityInsertionConsecutiveSkips = skippedCount
        , priorityInsertionFinishedAt = if mustDefer then Just now else Nothing
        , priorityInsertionPreviousCandidate = Just candidate
        , priorityInsertionCandidateDistanceFromPrevious =
            candidateDistance tieBrokenMembers candidate alternative
        }
      pressure = if mustDefer
        then Set.insert (priorityInsertionBrick insertion)
          (priorityStateProposalPressure state)
        else priorityStateProposalPressure state
      next = state
        { priorityStateNextOrdinal = ordinal + 1
        , priorityStateScopes = Map.insert (priorityScopeId scope) nextScope
            (priorityStateScopes state)
        , priorityStateInsertions = Map.insert identifier nextInsertion
            (priorityStateInsertions state)
        , priorityStateSkips = priorityStateSkips state <> [skip]
        , priorityStateProposalPressure = pressure
        }
  validatePriorityState next
  pure (nextInsertion, skip, next)

reopenPriorityInsertion ::
  PriorityInsertionId -> PriorityState ->
  Either PriorityError (PriorityInsertion, PriorityState)
reopenPriorityInsertion identifier state = do
  insertion <- requireInsertion identifier state
  unless (priorityInsertionStatus insertion == InsertionDeferred)
    (Left (InvalidPriorityTransition "only a deferred insertion can reopen"))
  scope <- requireScope (priorityInsertionScope insertion) state
  let oldMembers = filter (/= priorityInsertionBrick insertion)
        (priorityScopeMembers scope)
      candidate = atMay oldMembers (length oldMembers `div` 2)
  when (candidate == Nothing)
    (Left (InvalidPriorityTransition "deferred insertion has no sibling candidate"))
  let reopened = insertion
        { priorityInsertionStatus = InsertionOpen
        , priorityInsertionCurrentCandidate = candidate
        , priorityInsertionConsecutiveSkips = 0
        , priorityInsertionFinishedAt = Nothing
        , priorityInsertionSearchLow = 0
        , priorityInsertionSearchHigh = length oldMembers
        , priorityInsertionPreviousCandidate = Nothing
        , priorityInsertionCandidateDistanceFromPrevious = Nothing
        }
      next = state
        { priorityStateInsertions = Map.insert identifier reopened
            (priorityStateInsertions state)
        , priorityStateProposalPressure = Set.delete
            (priorityInsertionBrick insertion) (priorityStateProposalPressure state)
        }
  validatePriorityState next
  pure (reopened, next)

------------------------------------------------------------
-- Direct evidence, contradiction, and local recalibration
------------------------------------------------------------

openPriorityProbe ::
  PriorityScopeId -> BrickId -> BrickId -> ProbePurpose -> Text -> UTCTime ->
  PriorityState -> Either PriorityError (JudgmentProbe, PriorityState)
openPriorityProbe scopeId left right purpose reason now state = do
  scope <- requireScope scopeId state
  when (left == right)
    (Left (InvalidPriorityRelationship "a judgment probe requires distinct Bricks"))
  unless (left `elem` priorityScopeMembers scope && right `elem` priorityScopeMembers scope)
    (Left (InvalidPriorityRelationship "priority probe must compare siblings"))
  let ordinal = priorityStateNextOrdinal state
      probe = JudgmentProbe
        { judgmentProbeId = JudgmentProbeId (opaqueText "judgment-probe" ordinal)
        , judgmentProbeAxis = PriorityAxis
        , judgmentProbePurpose = purpose
        , judgmentProbeScope = Just scopeId
        , judgmentProbeLeft = left
        , judgmentProbeRight = right
        , judgmentProbeReason = reason
        , judgmentProbeStatus = ProbeOpen
        , judgmentProbeCreatedAt = now
        , judgmentProbeResolvedAt = Nothing
        }
      next = state
        { priorityStateNextOrdinal = ordinal + 1
        , priorityStateProbes = Map.insert (judgmentProbeId probe) probe
            (priorityStateProbes state)
        }
  validatePriorityState next
  pure (probe, next)

deferJudgmentProbe ::
  JudgmentProbeId -> PriorityState -> Either PriorityError (JudgmentProbe, PriorityState)
deferJudgmentProbe identifier state = do
  probe <- maybe
    (Left (InvalidPriorityRelationship "unknown judgment probe")) Right
    (Map.lookup identifier (priorityStateProbes state))
  unless (judgmentProbeStatus probe == ProbeOpen)
    (Left (InvalidPriorityTransition "only an open judgment probe can defer"))
  let deferred = probe {judgmentProbeStatus = ProbeDeferred}
      next = state {priorityStateProbes = Map.insert identifier deferred
        (priorityStateProbes state)}
  validatePriorityState next
  pure (deferred, next)

reopenJudgmentProbe ::
  JudgmentProbeId -> PriorityState -> Either PriorityError (JudgmentProbe, PriorityState)
reopenJudgmentProbe identifier state = do
  probe <- maybe
    (Left (InvalidPriorityRelationship "unknown judgment probe")) Right
    (Map.lookup identifier (priorityStateProbes state))
  unless (judgmentProbeStatus probe == ProbeDeferred)
    (Left (InvalidPriorityTransition "only a deferred judgment probe can reopen"))
  let reopened = probe {judgmentProbeStatus = ProbeOpen}
      next = state {priorityStateProbes = Map.insert identifier reopened
        (priorityStateProbes state)}
  validatePriorityState next
  pure (reopened, next)

recordPriorityJudgment ::
  PriorityScopeId -> BrickId -> BrickId -> Authority -> Maybe Text -> UTCTime ->
  PriorityState ->
  Either PriorityError
    (PriorityJudgment, Maybe PriorityRecalibration, PriorityState)
recordPriorityJudgment scopeId moreImportant lessImportant authority reason now state = do
  scope <- requireScope scopeId state
  when (moreImportant == lessImportant)
    (Left (InvalidPriorityRelationship "priority does not store ties"))
  unless (moreImportant `elem` priorityScopeMembers scope
      && lessImportant `elem` priorityScopeMembers scope)
    (Left (InvalidPriorityRelationship "priority judgment must compare siblings"))
  let ordinal = priorityStateNextOrdinal state
      judgment = PriorityJudgment
        { priorityJudgmentId = PriorityJudgmentId
            (opaqueText "priority-judgment" ordinal)
        , priorityJudgmentScope = scopeId
        , priorityJudgmentScopeRevision = priorityScopeRevision scope
        , priorityJudgmentMoreImportant = moreImportant
        , priorityJudgmentLessImportant = lessImportant
        , priorityJudgmentAuthority = authority
        , priorityJudgmentRecordedAt = now
        , priorityJudgmentReason = reason
        , priorityJudgmentApplicable = True
        }
      contradiction = authority == Human
        && appearsAfter moreImportant lessImportant (priorityScopeMembers scope)
      existingOpen = find (\item ->
          priorityRecalibrationScope item == scopeId
          && priorityRecalibrationStatus item == RecalibrationOpen)
        (Map.elems (priorityStateRecalibrations state))
      recalibration = if contradiction && existingOpen == Nothing
        then Just (newRecalibration (ordinal + 1) judgment scope now)
        else Nothing
      nextOrdinal = ordinal + 1 + if isJust recalibration then 1 else 0
      resolvedProbes = Map.map (resolveMatchingProbe judgment now)
        (priorityStateProbes state)
      next = state
        { priorityStateNextOrdinal = nextOrdinal
        , priorityStateJudgments = Map.insert (priorityJudgmentId judgment) judgment
            (priorityStateJudgments state)
        , priorityStateRecalibrations = maybe
            (priorityStateRecalibrations state)
            (\item -> Map.insert (priorityRecalibrationId item) item
              (priorityStateRecalibrations state))
            recalibration
        , priorityStateProbes = resolvedProbes
        }
  validatePriorityState next
  pure (judgment, recalibration, next)

commitPriorityRecalibration ::
  PriorityRecalibrationId -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityRecalibration, PriorityState)
commitPriorityRecalibration identifier now state = do
  recalibration <- requireRecalibration identifier state
  unless (priorityRecalibrationStatus recalibration == RecalibrationOpen)
    (Left (InvalidPriorityTransition "priority recalibration is not open"))
  scope <- requireScope (priorityRecalibrationScope recalibration) state
  let members = priorityScopeMembers scope
      segment = priorityRecalibrationSegment recalibration
      proposal = priorityRecalibrationProposedOrder recalibration
  unless (Set.fromList segment == Set.fromList proposal
      && length segment == length proposal && length proposal == length (nub proposal))
    (Left (InvalidPriorityTransition "recalibration proposal is not a strict segment permutation"))
  start <- segmentStart segment members
  unless (take (length segment) (drop start members) == segment)
    (Left (InvalidPriorityTransition "recalibration segment is no longer contiguous"))
  triggering <- maybe
    (Left (InvalidPriorityTransition "recalibration lost its triggering judgment"))
    Right
    (Map.lookup (priorityRecalibrationTriggeringJudgment recalibration)
      (priorityStateJudgments state))
  unless (appearsBefore (priorityJudgmentMoreImportant triggering)
      (priorityJudgmentLessImportant triggering) proposal)
    (Left (InvalidPriorityTransition "proposed order does not satisfy the new human evidence"))
  let nextMembers = take start members <> proposal <> drop (start + length segment) members
      nextScope = scope
        { priorityScopeMembers = nextMembers
        , priorityScopeRevision = priorityScopeRevision scope + 1
        }
      resolved = recalibration
        { priorityRecalibrationStatus = RecalibrationResolved
        , priorityRecalibrationResolvedAt = Just now
        }
      revisedJudgments = Map.map (supersedeIncoherent segment nextMembers)
        (priorityStateJudgments state)
      next = state
        { priorityStateScopes = Map.insert (priorityScopeId scope) nextScope
            (priorityStateScopes state)
        , priorityStateRecalibrations = Map.insert identifier resolved
            (priorityStateRecalibrations state)
        , priorityStateJudgments = revisedJudgments
        }
  validatePriorityState next
  pure (resolved, next)

newRecalibration ::
  Integer -> PriorityJudgment -> PriorityScope -> UTCTime -> PriorityRecalibration
newRecalibration ordinal judgment scope now =
  let members = priorityScopeMembers scope
      more = priorityJudgmentMoreImportant judgment
      less = priorityJudgmentLessImportant judgment
      firstIndex = fromMaybe 0 (elemIndex more members)
      secondIndex = fromMaybe 0 (elemIndex less members)
      start = min firstIndex secondIndex
      finish = max firstIndex secondIndex
      segment = take (finish - start + 1) (drop start members)
      proposed = more : filter (/= more) segment
  in PriorityRecalibration
      { priorityRecalibrationId = PriorityRecalibrationId
          (opaqueText "priority-recalibration" ordinal)
      , priorityRecalibrationScope = priorityScopeId scope
      , priorityRecalibrationSegment = segment
      , priorityRecalibrationProposedOrder = proposed
      , priorityRecalibrationStatus = RecalibrationOpen
      , priorityRecalibrationCreatedAt = now
      , priorityRecalibrationResolvedAt = Nothing
      , priorityRecalibrationTriggeringJudgment = priorityJudgmentId judgment
      }

resolveMatchingProbe :: PriorityJudgment -> UTCTime -> JudgmentProbe -> JudgmentProbe
resolveMatchingProbe judgment now probe
  | judgmentProbeAxis probe == PriorityAxis
      && judgmentProbeScope probe == Just (priorityJudgmentScope judgment)
      && samePair (judgmentProbeLeft probe) (judgmentProbeRight probe)
        (priorityJudgmentMoreImportant judgment)
        (priorityJudgmentLessImportant judgment)
      && judgmentProbeStatus probe `elem` [ProbeOpen, ProbeDeferred] =
          probe {judgmentProbeStatus = ProbeResolved,
            judgmentProbeResolvedAt = Just now}
  | otherwise = probe

supersedeIncoherent :: [BrickId] -> [BrickId] -> PriorityJudgment -> PriorityJudgment
supersedeIncoherent segment members judgment
  | priorityJudgmentApplicable judgment
      && priorityJudgmentMoreImportant judgment `elem` segment
      && priorityJudgmentLessImportant judgment `elem` segment
      && not (appearsBefore (priorityJudgmentMoreImportant judgment)
        (priorityJudgmentLessImportant judgment) members) =
          judgment {priorityJudgmentApplicable = False}
  | otherwise = judgment

------------------------------------------------------------
-- Lifecycle, composition rebinding, dependencies, and evidence
------------------------------------------------------------

-- | Rebind only a moved subtree root. Descendant scopes and identities remain
-- byte-for-byte untouched; old-scope judgments become historical.
movePrioritySubtree ::
  BrickId -> Maybe BrickId -> Text -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityInsertion, PriorityState)
movePrioritySubtree identifier newParent movementEvidence now state = do
  brick <- requireBrick identifier state
  unless (priorityBrickStatus brick == Active)
    (Left (InvalidPriorityTransition "only an active subtree can move"))
  when (priorityBrickParent brick == newParent)
    (Left (InvalidPriorityRelationship "priority parent is unchanged"))
  case newParent of
    Nothing -> pure ()
    Just parentId -> do
      parent <- requireBrick parentId state
      unless (priorityBrickStatus parent == Active)
        (Left (InvalidPriorityRelationship "new priority parent must be active"))
      when (priorityDescendsFrom state parentId identifier)
        (Left (InvalidPriorityRelationship "priority move would create a cycle"))
  oldScope <- requireScope (scopeIdForParent (priorityBrickParent brick)) state
  newScope <- requireScope (scopeIdForParent newParent) state
  unless (identifier `elem` priorityScopeMembers oldScope)
    (Left (InvalidPriorityRelationship "moved Brick is absent from its old scope"))
  let ordinal = priorityStateNextOrdinal state
      newWasEmpty = null (priorityScopeMembers newScope)
      oldUpdated = oldScope
        { priorityScopeMembers = filter (/= identifier) (priorityScopeMembers oldScope)
        , priorityScopeRevision = priorityScopeRevision oldScope + 1
        }
      newUpdated = newScope
        { priorityScopeMembers = priorityScopeMembers newScope <> [identifier]
        , priorityScopeRevision = priorityScopeRevision newScope + 1
        }
      updatedBrick = brick {priorityBrickParent = newParent}
      insertion = movedInsertion ordinal identifier newUpdated newWasEmpty
        movementEvidence now
      judgments = Map.map (retireMovedJudgment identifier (priorityScopeId oldScope))
        (priorityStateJudgments state)
      next = state
        { priorityStateNextOrdinal = ordinal + 1
        , priorityStateBricks = Map.insert identifier updatedBrick
            (priorityStateBricks state)
        , priorityStateScopes = Map.insert (priorityScopeId newUpdated) newUpdated
            (Map.insert (priorityScopeId oldUpdated) oldUpdated
              (priorityStateScopes state))
        , priorityStateInsertions = Map.insert (priorityInsertionId insertion) insertion
            (priorityStateInsertions state)
        , priorityStateJudgments = judgments
        , priorityStateProbes = Map.map
            (resolveMovedProbe identifier (priorityScopeId oldScope) now)
            (priorityStateProbes state)
        , priorityStateProposalPressure = if newWasEmpty
            then Set.delete identifier (priorityStateProposalPressure state)
            else Set.insert identifier (priorityStateProposalPressure state)
        }
  validatePriorityState next
  pure (insertion, next)

-- | Atomically transfer every selected direct child while preserving their
-- old relative order as one provisional block in the replacement scope.
transferPriorityChildren ::
  BrickId -> BrickId -> [BrickId] -> Text -> UTCTime -> PriorityState ->
  Either PriorityError ([PriorityInsertion], PriorityState)
transferPriorityChildren source replacement selected transferEvidence now state = do
  sourceBrick <- requireBrick source state
  replacementBrick <- requireBrick replacement state
  unless (priorityBrickStatus sourceBrick == Active
      && priorityBrickStatus replacementBrick == Active)
    (Left (InvalidPriorityTransition "child transfer requires active Bricks"))
  unless (priorityBrickParent sourceBrick == priorityBrickParent replacementBrick)
    (Left (InvalidPriorityRelationship "superseding Bricks must be siblings"))
  oldScope <- requireScope (scopeIdForParent (Just source)) state
  newScope <- requireScope (scopeIdForParent (Just replacement)) state
  let ordered = filter (`elem` selected) (priorityScopeMembers oldScope)
  unless (not (null selected) && length ordered == length selected
      && Set.fromList ordered == Set.fromList selected
      && Set.fromList selected == Set.fromList (priorityScopeMembers oldScope))
    (Left (InvalidPriorityRelationship "transfer must name all active direct children exactly once"))
  let startOrdinal = priorityStateNextOrdinal state
      oldUpdated = oldScope
        { priorityScopeMembers = []
        , priorityScopeRevision = priorityScopeRevision oldScope + 1
        }
      newUpdated = newScope
        { priorityScopeMembers = priorityScopeMembers newScope <> ordered
        , priorityScopeRevision = priorityScopeRevision newScope + 1
        }
      updateParent child = child {priorityBrickParent = Just replacement}
      bricks = foldr (Map.adjust updateParent) (priorityStateBricks state) ordered
      makeInsertion (offset, child) = deferredTransferInsertion
        (startOrdinal + fromIntegral offset) child newUpdated transferEvidence now
      insertions = map makeInsertion (zip [0 :: Int ..] ordered)
      insertionMap = foldr (\item -> Map.insert (priorityInsertionId item) item)
        (priorityStateInsertions state) insertions
      next = state
        { priorityStateNextOrdinal = startOrdinal + fromIntegral (length ordered)
        , priorityStateBricks = bricks
        , priorityStateScopes = Map.insert (priorityScopeId newUpdated) newUpdated
            (Map.insert (priorityScopeId oldUpdated) oldUpdated
              (priorityStateScopes state))
        , priorityStateInsertions = insertionMap
        , priorityStateJudgments = Map.map
            (retireScopeJudgment (priorityScopeId oldScope))
            (priorityStateJudgments state)
        , priorityStateProbes = Map.map
            (resolveScopeProbe (priorityScopeId oldScope) now)
            (priorityStateProbes state)
        , priorityStateProposalPressure = foldr Set.insert
            (priorityStateProposalPressure state) ordered
        }
  validatePriorityState next
  pure (insertions, next)

movedInsertion ::
  Integer -> BrickId -> PriorityScope -> Bool -> Text -> UTCTime ->
  PriorityInsertion
movedInsertion ordinal identifier scope newWasEmpty evidence now = PriorityInsertion
  { priorityInsertionId = PriorityInsertionId (opaqueText "priority-insertion" ordinal)
  , priorityInsertionBrick = identifier
  , priorityInsertionScope = priorityScopeId scope
  , priorityInsertionStatus = if newWasEmpty then InsertionResolved else InsertionDeferred
  , priorityInsertionCurrentCandidate = Nothing
  , priorityInsertionComparisonsRecorded = 0
  , priorityInsertionConsecutiveSkips = 0
  , priorityInsertionRandomEvidence = evidence
  , priorityInsertionStartedAt = now
  , priorityInsertionFinishedAt = Just now
  , priorityInsertionSearchLow = 0
  , priorityInsertionSearchHigh = max 0 (length (priorityScopeMembers scope) - 1)
  , priorityInsertionPreviousCandidate = Nothing
  , priorityInsertionCandidateDistanceFromPrevious = Nothing
  }

deferredTransferInsertion ::
  Integer -> BrickId -> PriorityScope -> Text -> UTCTime -> PriorityInsertion
deferredTransferInsertion ordinal identifier scope evidence now =
  (movedInsertion ordinal identifier scope False
    (evidence <> ":" <> unBrickId identifier) now)
      {priorityInsertionStatus = InsertionDeferred}

retireMovedJudgment :: BrickId -> PriorityScopeId -> PriorityJudgment -> PriorityJudgment
retireMovedJudgment identifier oldScope judgment
  | priorityJudgmentScope judgment == oldScope
      && identifier `elem`
        [priorityJudgmentMoreImportant judgment, priorityJudgmentLessImportant judgment] =
          judgment {priorityJudgmentApplicable = False}
  | otherwise = judgment

retireScopeJudgment :: PriorityScopeId -> PriorityJudgment -> PriorityJudgment
retireScopeJudgment oldScope judgment
  | priorityJudgmentScope judgment == oldScope =
      judgment {priorityJudgmentApplicable = False}
  | otherwise = judgment

-- A probe records evidence from the scope in which it was opened.  Moving a
-- participant does not erase that evidence, but an unresolved probe cannot
-- remain actionable after its participants stop being siblings.
resolveMovedProbe ::
  BrickId -> PriorityScopeId -> UTCTime -> JudgmentProbe -> JudgmentProbe
resolveMovedProbe identifier oldScope now probe
  | judgmentProbeScope probe == Just oldScope
      && identifier `elem` [judgmentProbeLeft probe, judgmentProbeRight probe] =
          resolveHistoricalProbe now probe
  | otherwise = probe

resolveScopeProbe :: PriorityScopeId -> UTCTime -> JudgmentProbe -> JudgmentProbe
resolveScopeProbe oldScope now probe
  | judgmentProbeScope probe == Just oldScope = resolveHistoricalProbe now probe
  | otherwise = probe

resolveHistoricalProbe :: UTCTime -> JudgmentProbe -> JudgmentProbe
resolveHistoricalProbe now probe
  | judgmentProbeStatus probe `elem` [ProbeOpen, ProbeDeferred] = probe
      { judgmentProbeStatus = ProbeResolved
      , judgmentProbeResolvedAt = Just now
      }
  | otherwise = probe

priorityDescendsFrom :: PriorityState -> BrickId -> BrickId -> Bool
priorityDescendsFrom state candidate ancestor = go Set.empty candidate
  where
    go seen current
      | current == ancestor = True
      | Set.member current seen = True
      | otherwise = case Map.lookup current (priorityStateBricks state)
          >>= priorityBrickParent of
            Nothing -> False
            Just parent -> go (Set.insert current seen) parent

setPriorityBrickStatus ::
  BrickId -> BrickStatus -> UTCTime -> PriorityState ->
  Either PriorityError (PriorityBrick, PriorityState)
setPriorityBrickStatus identifier status now state = do
  brick <- requireBrick identifier state
  let updated = brick {priorityBrickStatus = status}
      scopes = if status == Active
        then priorityStateScopes state
        else Map.map removeFromScope (priorityStateScopes state)
      probes = if status == Active
        then priorityStateProbes state
        else Map.map resolveProbe (priorityStateProbes state)
      judgments = if status == Active
        then priorityStateJudgments state
        else Map.map retireJudgment (priorityStateJudgments state)
      next = state
        { priorityStateBricks = Map.insert identifier updated
            (priorityStateBricks state)
        , priorityStateScopes = scopes
        , priorityStateJudgments = judgments
        , priorityStateProbes = probes
        , priorityStateProposalPressure = if status == Active
            then priorityStateProposalPressure state
            else Set.delete identifier (priorityStateProposalPressure state)
        }
  validatePriorityState next
  pure (updated, next)
  where
    removeFromScope scope
      | identifier `elem` priorityScopeMembers scope = scope
          { priorityScopeMembers = filter (/= identifier) (priorityScopeMembers scope)
          , priorityScopeRevision = priorityScopeRevision scope + 1
          }
      | otherwise = scope
    retireJudgment judgment
      | identifier `elem`
          [ priorityJudgmentMoreImportant judgment
          , priorityJudgmentLessImportant judgment
          ] = judgment {priorityJudgmentApplicable = False}
      | otherwise = judgment
    resolveProbe probe
      | judgmentProbeStatus probe `elem` [ProbeOpen, ProbeDeferred]
          && identifier `elem` [judgmentProbeLeft probe, judgmentProbeRight probe] =
            probe {judgmentProbeStatus = ProbeResolved,
              judgmentProbeResolvedAt = Just now}
      | otherwise = probe

-- | Retire only evidence whose semantic scope changed.  Human importance
-- order and unrelated evidence are deliberately left untouched.
invalidatePriorityJudgmentsFor ::
  BrickId -> PriorityState -> Either PriorityError PriorityState
invalidatePriorityJudgmentsFor identifier state = do
  _ <- requireBrick identifier state
  let retire judgment
        | identifier `elem`
            [ priorityJudgmentMoreImportant judgment
            , priorityJudgmentLessImportant judgment
            ] = judgment {priorityJudgmentApplicable = False}
        | otherwise = judgment
      next = state
        { priorityStateJudgments = Map.map retire (priorityStateJudgments state) }
  validatePriorityState next
  pure next

recordPriorityDependency ::
  BrickId -> BrickId -> PriorityState -> Either PriorityError PriorityState
recordPriorityDependency blocker blocked state = do
  _ <- requireBrick blocker state
  _ <- requireBrick blocked state
  when (blocker == blocked)
    (Left (InvalidPriorityRelationship "a Brick cannot depend on itself"))
  let beforeOrders = Map.map priorityScopeMembers (priorityStateScopes state)
      next = state
        { priorityStateDependencies = Set.insert (blocker, blocked)
            (priorityStateDependencies state) }
  unless (Map.map priorityScopeMembers (priorityStateScopes next) == beforeOrders)
    (Left (PriorityInvariantViolation ["dependency rewrote human priority"]))
  pure next

priorityEvidence ::
  PriorityState -> PriorityScopeId -> BrickId -> BrickId ->
  Either PriorityError PriorityEvidenceView
priorityEvidence state scopeId left right = do
  scope <- requireScope scopeId state
  when (left == right)
    (Left (InvalidPriorityRelationship "priority evidence requires distinct Bricks"))
  unless (left `elem` priorityScopeMembers scope && right `elem` priorityScopeMembers scope)
    (Left (InvalidPriorityRelationship "priority evidence requires sibling Bricks"))
  let history = sortOn priorityJudgmentRecordedAt
        [ judgment
        | judgment <- Map.elems (priorityStateJudgments state)
        , priorityJudgmentScope judgment == scopeId
        , samePair left right
            (priorityJudgmentMoreImportant judgment)
            (priorityJudgmentLessImportant judgment)
        ]
      applicable = filter priorityJudgmentApplicable history
      humans = filter ((== Human) . priorityJudgmentAuthority) applicable
      current = lastMay (if null humans then applicable else humans)
      currentMore = priorityJudgmentMoreImportant <$> current
      leftToRight = transitivePath state scopeId left right
      rightToLeft = transitivePath state scopeId right left
      canonicalMore = if appearsBefore left right (priorityScopeMembers scope)
        then left else right
      contradicts = maybe False (/= canonicalMore) currentMore
        || (isJust leftToRight && currentMore == Just right)
        || (isJust rightToLeft && currentMore == Just left)
      provisional = memberIsProvisional state left || memberIsProvisional state right
        || pairInOpenRecalibration state scopeId left right
      confidence
        | contradicts = 0.30
        | provisional = 0.25
        | isJust current = 0.95
        | isJust leftToRight || isJust rightToLeft = 0.80
        | otherwise = 0.50
      reasons = concat
        [ ["retained human judgment conflicts with canonical/transitive order" | contradicts]
        , ["priority position is provisional" | provisional]
        , ["current direct human evidence" | isJust current && not contradicts]
        , ["transitive human support" | isJust leftToRight || isJust rightToLeft]
        , ["no direct pairwise evidence" | current == Nothing]
        ]
      support = maybeToListPath leftToRight <> maybeToListPath rightToLeft
  pure PriorityEvidenceView
    { priorityEvidenceScope = scopeId
    , priorityEvidenceLeft = left
    , priorityEvidenceRight = right
    , priorityEvidenceCurrentMoreImportant = currentMore
    , priorityEvidenceConfidence = confidence
    , priorityEvidenceConfidenceReasons = reasons
    , priorityEvidenceProvisional = provisional
    , priorityEvidenceHistory = history
    , priorityEvidenceTransitiveSupport = support
    , priorityEvidenceContainsEquality = False
    }

priorityView :: PriorityState -> Either PriorityError PriorityView
priorityView state = do
  root <- requireScope priorityRootScopeId state
  items <- concat <$> mapM (viewBranch []) (zip [0 ..] (priorityScopeMembers root))
  let fingerprint = Text.intercalate ":"
        [ unPriorityScopeId identifier <> "@" <> Text.pack (show (priorityScopeRevision scope))
        | (identifier, scope) <- Map.toAscList (priorityStateScopes state)
        ]
  pure PriorityView
    { priorityViewRootScope = priorityRootScopeId
    , priorityViewRevisionFingerprint = fingerprint
    , priorityViewItems = items
    }
  where
    viewBranch parentPath (index, brick) = do
      item <- priorityViewItemWithPath state brick (parentPath <> [index])
      child <- requireScope (scopeIdForParent (Just brick)) state
      descendants <- concat <$> mapM (viewBranch (parentPath <> [index]))
        (zip [0 ..] (priorityScopeMembers child))
      pure (item : descendants)

priorityViewItem :: PriorityState -> BrickId -> Either PriorityError PriorityViewItem
priorityViewItem state identifier = do
  paths <- priorityView state
  maybe (Left (UnknownPriorityBrick identifier)) Right
    (find ((== identifier) . priorityViewItemBrick) (priorityViewItems paths))

priorityViewItemWithPath ::
  PriorityState -> BrickId -> [Int] -> Either PriorityError PriorityViewItem
priorityViewItemWithPath state identifier path = do
  brick <- requireBrick identifier state
  let scopeId = scopeIdForParent (priorityBrickParent brick)
      siblingIndex = fromMaybe 0 (lastMay path)
      confidence = minimumConfidenceForMember state scopeId identifier
      provisional = memberIsProvisional state identifier
  pure PriorityViewItem
    { priorityViewItemBrick = identifier
    , priorityViewItemScope = scopeId
    , priorityViewItemSiblingIndex = siblingIndex
    , priorityViewItemTreePath = path
    , priorityViewItemConfidence = confidence
    , priorityViewItemConfidenceReasons =
        ["insertion or local recalibration is unresolved" | provisional]
    , priorityViewItemProvisional = provisional
    }

priorityProposalKinds :: PriorityState -> BrickId -> [Text]
priorityProposalKinds state identifier =
  ["priority_probe" | Set.member identifier (priorityStateProposalPressure state)]

priorityScopeProjection :: PriorityState -> PriorityScopeId -> Either PriorityError Value
priorityScopeProjection state identifier = do
  scope <- requireScope identifier state
  view <- priorityView state
  pure (genericToJSON (recordOptions "priorityScope") scope
    `mergeObjectValue` [("view", toJSON view)])

priorityInsertionProjection :: PriorityState -> PriorityInsertionId -> Either PriorityError Value
priorityInsertionProjection state identifier = toJSON <$> requireInsertion identifier state

priorityJudgmentProjection :: PriorityState -> PriorityJudgmentId -> Either PriorityError Value
priorityJudgmentProjection state identifier = do
  judgment <- maybe (Left (InvalidPriorityRelationship "unknown priority judgment")) Right
    (Map.lookup identifier (priorityStateJudgments state))
  evidence <- priorityEvidence state (priorityJudgmentScope judgment)
    (priorityJudgmentMoreImportant judgment) (priorityJudgmentLessImportant judgment)
  let current = priorityEvidenceCurrentMoreImportant evidence
        == Just (priorityJudgmentMoreImportant judgment)
        && priorityJudgmentApplicable judgment
  pure (toJSON judgment `mergeObjectValue`
    [("is_current", toJSON current), ("evidence_view", toJSON evidence)])

priorityRecalibrationProjection ::
  PriorityState -> PriorityRecalibrationId -> Either PriorityError Value
priorityRecalibrationProjection state identifier = toJSON <$> requireRecalibration identifier state

probeProjection :: PriorityState -> JudgmentProbeId -> Either PriorityError Value
probeProjection state identifier = maybe
  (Left (InvalidPriorityRelationship "unknown judgment probe"))
  (Right . toJSON)
  (Map.lookup identifier (priorityStateProbes state))

------------------------------------------------------------
-- Invariants and helpers
------------------------------------------------------------

validatePriorityState :: PriorityState -> Either PriorityError ()
validatePriorityState state = do
  let scopes = Map.elems (priorityStateScopes state)
      activeBricks = [brick | brick <- Map.elems (priorityStateBricks state),
        priorityBrickStatus brick == Active]
      terminalBricks = [brick | brick <- Map.elems (priorityStateBricks state),
        priorityBrickStatus brick /= Active]
      violations = concat
        [ ["priority skip limit is not positive" | priorityStateSkipLimit state < 1]
        , ["priority nearby distance is not positive" |
            priorityStateNearbyDistance state < 1]
        , ["root priority scope is absent" |
            Map.notMember priorityRootScopeId (priorityStateScopes state)]
        , ["two priority scopes have the same parent" |
            hasDuplicates (map priorityScopeParent scopes)]
        , ["priority scope contains duplicate members" |
            any (hasDuplicates . priorityScopeMembers) scopes]
        , ["active Brick is not positioned exactly once" |
            any ((/= 1) . membershipCount scopes . priorityBrickId) activeBricks]
        , ["terminal Brick remains in active priority" |
            any ((/= 0) . membershipCount scopes . priorityBrickId) terminalBricks]
        , ["priority scope does not match composition parent" |
            any (scopeHasWrongParent state) scopes]
        , ["applicable priority judgment is not sibling-scoped" |
            any (judgmentInvalid state) (Map.elems (priorityStateJudgments state))]
        , ["open priority probe is not sibling-scoped" |
            any (probeInvalid state) (Map.elems (priorityStateProbes state))]
        ]
  unless (null violations) (Left (PriorityInvariantViolation violations))

scopeHasWrongParent :: PriorityState -> PriorityScope -> Bool
scopeHasWrongParent state scope = any wrong (priorityScopeMembers scope)
  where
    wrong identifier = case Map.lookup identifier (priorityStateBricks state) of
      Nothing -> True
      Just brick -> priorityBrickParent brick /= priorityScopeParent scope

judgmentInvalid :: PriorityState -> PriorityJudgment -> Bool
judgmentInvalid state judgment
  | priorityJudgmentMoreImportant judgment == priorityJudgmentLessImportant judgment = True
  | not (priorityJudgmentApplicable judgment) = False
  | otherwise = case Map.lookup (priorityJudgmentScope judgment)
      (priorityStateScopes state) of
        Nothing -> True
        Just scope -> not (priorityJudgmentMoreImportant judgment
          `elem` priorityScopeMembers scope
          && priorityJudgmentLessImportant judgment
          `elem` priorityScopeMembers scope
          && priorityJudgmentScopeRevision judgment <= priorityScopeRevision scope)

probeInvalid :: PriorityState -> JudgmentProbe -> Bool
probeInvalid state probe
  | judgmentProbeLeft probe == judgmentProbeRight probe = True
  | judgmentProbeAxis probe /= PriorityAxis = False
  | judgmentProbeStatus probe == ProbeResolved = False
  | otherwise = case judgmentProbeScope probe >>= (\scopeId ->
      Map.lookup scopeId (priorityStateScopes state)) of
        Nothing -> True
        Just scope -> not (judgmentProbeLeft probe `elem` priorityScopeMembers scope
          && judgmentProbeRight probe `elem` priorityScopeMembers scope)

createStrictRootFixture ::
  [Text] -> [(Text, Text)] -> Text -> UTCTime -> PriorityState ->
  Either PriorityError (Map Text BrickId, PriorityState)
createStrictRootFixture titles directJudgments randomEvidence now initial = do
  (byTitle, positioned) <- foldM addAtTail (Map.empty, initial) titles
  final <- foldM (recordNamed byTitle) positioned directJudgments
  pure (byTitle, final)
  where
    addAtTail (byTitle, state) title = do
      (brick, insertion, created) <- createPriorityRoot title randomEvidence now state
      positioned <- settleAtTail insertion created
      pure (Map.insert title (priorityBrickId brick) byTitle, positioned)
    settleAtTail insertion state
      | priorityInsertionStatus insertion == InsertionResolved = Right state
      | otherwise = do
          (nextInsertion, _, next) <- answerPriorityInsertion
            (priorityInsertionId insertion) False Human Nothing now state
          settleAtTail nextInsertion next
    recordNamed byTitle state (moreTitle, lessTitle) = do
      more <- maybe (Left (InvalidPriorityRelationship
        ("unknown fixture title: " <> moreTitle))) Right (Map.lookup moreTitle byTitle)
      less <- maybe (Left (InvalidPriorityRelationship
        ("unknown fixture title: " <> lessTitle))) Right (Map.lookup lessTitle byTitle)
      (_, _, next) <- recordPriorityJudgment priorityRootScopeId more less
        Human Nothing now state
      pure next

scopeIdForParent :: Maybe BrickId -> PriorityScopeId
scopeIdForParent Nothing = priorityRootScopeId
scopeIdForParent (Just (BrickId identifier)) = PriorityScopeId ("priority-children:" <> identifier)

requireBrick :: BrickId -> PriorityState -> Either PriorityError PriorityBrick
requireBrick identifier state = maybe (Left (UnknownPriorityBrick identifier)) Right
  (Map.lookup identifier (priorityStateBricks state))

requireScope :: PriorityScopeId -> PriorityState -> Either PriorityError PriorityScope
requireScope identifier state = maybe (Left (UnknownPriorityScope identifier)) Right
  (Map.lookup identifier (priorityStateScopes state))

requireInsertion ::
  PriorityInsertionId -> PriorityState -> Either PriorityError PriorityInsertion
requireInsertion identifier state = maybe (Left (UnknownPriorityInsertion identifier)) Right
  (Map.lookup identifier (priorityStateInsertions state))

requireRecalibration ::
  PriorityRecalibrationId -> PriorityState -> Either PriorityError PriorityRecalibration
requireRecalibration identifier state = maybe
  (Left (UnknownPriorityRecalibration identifier)) Right
  (Map.lookup identifier (priorityStateRecalibrations state))

nearbyDistinctCandidate ::
  PriorityState -> PriorityInsertion -> BrickId -> [BrickId] -> Maybe BrickId
nearbyDistinctCandidate state insertion current members =
  case elemIndex current members of
    Nothing -> Nothing
    Just currentIndex -> choose candidates
      (priorityInsertionRandomEvidence insertion <> ":"
        <> Text.pack (show (priorityInsertionConsecutiveSkips insertion)))
      where
        siblingMembers = filter (/= priorityInsertionBrick insertion) members
        searchLow = priorityInsertionSearchLow insertion
        searchHigh = priorityInsertionSearchHigh insertion
        candidates =
          [ candidate
          | (searchIndex, candidate) <- zip [0 ..] siblingMembers
          , searchIndex >= searchLow
          , searchIndex < searchHigh
          , candidate /= current
          , Just memberIndex <- [elemIndex candidate members]
          , abs (memberIndex - currentIndex) >= 1
          , abs (memberIndex - currentIndex) <= priorityStateNearbyDistance state
          ]

choose :: [value] -> Text -> Maybe value
choose [] _ = Nothing
choose values evidence = atMay values
  (abs (Text.foldl' (\total character -> total * 33 + ord character) 17 evidence)
    `mod` length values)

replaySafeTieBreak :: PriorityInsertion -> BrickId -> [BrickId] -> [BrickId]
replaySafeTieBreak insertion candidate members =
  let brick = priorityInsertionBrick insertion
      without = filter (/= brick) members
      candidateIndex = fromMaybe (length without) (elemIndex candidate without)
      evidenceScore = Text.foldl' (\total character -> total + ord character) 0
        (priorityInsertionRandomEvidence insertion)
      index = if even evidenceScore then candidateIndex else candidateIndex + 1
  in insertAt index brick without

candidateDistance :: [BrickId] -> BrickId -> Maybe BrickId -> Maybe Int
candidateDistance _ _ Nothing = Nothing
candidateDistance members previous (Just current) = do
  previousIndex <- elemIndex previous members
  currentIndex <- elemIndex current members
  pure (abs (previousIndex - currentIndex))

minimumConfidenceForMember :: PriorityState -> PriorityScopeId -> BrickId -> Double
minimumConfidenceForMember state scopeId identifier =
  let scope = Map.lookup scopeId (priorityStateScopes state)
      others = maybe [] (filter (/= identifier) . priorityScopeMembers) scope
      confidences = mapMaybe (either (const Nothing)
        (Just . priorityEvidenceConfidence) . priorityEvidence state scopeId identifier) others
  in if null confidences
      then if memberIsProvisional state identifier then 0.25 else 1.0
      else minimum confidences

memberIsProvisional :: PriorityState -> BrickId -> Bool
memberIsProvisional state identifier =
  any (\insertion -> priorityInsertionBrick insertion == identifier
      && priorityInsertionStatus insertion /= InsertionResolved)
    (Map.elems (priorityStateInsertions state))
  || any (\recalibration ->
      priorityRecalibrationStatus recalibration == RecalibrationOpen
      && identifier `elem` priorityRecalibrationSegment recalibration)
    (Map.elems (priorityStateRecalibrations state))

pairInOpenRecalibration ::
  PriorityState -> PriorityScopeId -> BrickId -> BrickId -> Bool
pairInOpenRecalibration state scopeId left right = any (\recalibration ->
    priorityRecalibrationScope recalibration == scopeId
    && priorityRecalibrationStatus recalibration == RecalibrationOpen
    && left `elem` priorityRecalibrationSegment recalibration
    && right `elem` priorityRecalibrationSegment recalibration)
  (Map.elems (priorityStateRecalibrations state))

transitivePath ::
  PriorityState -> PriorityScopeId -> BrickId -> BrickId -> Maybe [BrickId]
transitivePath state scopeId start target = search Set.empty start
  where
    edges =
      [ (priorityJudgmentMoreImportant judgment, priorityJudgmentLessImportant judgment)
      | judgment <- Map.elems (priorityStateJudgments state)
      , priorityJudgmentScope judgment == scopeId
      , priorityJudgmentApplicable judgment
      , priorityJudgmentAuthority judgment == Human
      ]
    search visited current
      | current == target = Just [target]
      | Set.member current visited = Nothing
      | otherwise = firstJust
          [ (current :) <$> search (Set.insert current visited) next
          | (source, next) <- edges
          , source == current
          ]

firstJust :: [Maybe value] -> Maybe value
firstJust = foldr (\candidate rest -> case candidate of
  Just _ -> candidate
  Nothing -> rest) Nothing

maybeToListPath :: Maybe [BrickId] -> [[BrickId]]
maybeToListPath (Just path) | length path > 1 = [path]
maybeToListPath _ = []

samePair :: Eq value => value -> value -> value -> value -> Bool
samePair first second third fourth =
  (first == third && second == fourth) || (first == fourth && second == third)

appearsBefore :: Eq value => value -> value -> [value] -> Bool
appearsBefore first second values = case (elemIndex first values, elemIndex second values) of
  (Just firstIndex, Just secondIndex) -> firstIndex < secondIndex
  _ -> False

appearsAfter :: Eq value => value -> value -> [value] -> Bool
appearsAfter first second = appearsBefore second first

segmentStart :: Eq value => [value] -> [value] -> Either PriorityError Int
segmentStart [] _ = Left (InvalidPriorityTransition "recalibration segment is empty")
segmentStart (first : _) members = maybe
  (Left (InvalidPriorityTransition "recalibration segment is absent")) Right
  (elemIndex first members)

membershipCount :: [PriorityScope] -> BrickId -> Int
membershipCount scopes identifier = length
  [() | scope <- scopes, identifier `elem` priorityScopeMembers scope]

hasDuplicates :: Ord value => [value] -> Bool
hasDuplicates values = Set.size (Set.fromList values) /= length values

opaqueText :: Text -> Integer -> Text
opaqueText prefix ordinal = prefix <> ":" <> Text.justifyRight 8 '0' (Text.pack (show ordinal))

insertAt :: Int -> value -> [value] -> [value]
insertAt index value values =
  let bounded = max 0 (min index (length values))
  in take bounded values <> [value] <> drop bounded values

atMay :: [value] -> Int -> Maybe value
atMay values index
  | index < 0 = Nothing
  | otherwise = case drop index values of
      value : _ -> Just value
      [] -> Nothing

lastMay :: [value] -> Maybe value
lastMay = foldl' (\_ value -> Just value) Nothing

mergeObjectValue :: Value -> [(Text, Value)] -> Value
mergeObjectValue value fields = case value of
  Object objectValue -> Object (foldl' insert objectValue fields)
  _ -> value
  where
    insert objectValue (key, fieldValue) =
      KeyMap.insert (Key.fromText key) fieldValue objectValue

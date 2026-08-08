module LittleAnt.Foundation (
  ExternalFact (..),
  FilesystemFacts (..),
  RandomPurpose (..),
  RuntimeFacts (..),
  TerminalCapabilities (..),
  UUIDAllocation (..),
  randomPurposeName,
  randomPurposeRegistry,
)
where

import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Time (UTCTime)

data RandomPurpose
  = ForecastSubjectDraw
  | ForecastChildDraw
  | ForecastOpportunityDraw
  | ForecastDependencyDraw
  | ForecastOccurrenceDraw
  | ForecastDomainPathDraw
  | ImportanceNearbyComparator
  | ImportanceProvisionalDirection
  | ImportanceValidationBranch
  | EasierWorkSample
  | DomainTargetSample
  | RepeatableReturnJitter
  | PersonalityPhrase
  deriving stock (Bounded, Enum, Eq, Ord, Show)

randomPurposeRegistry :: [RandomPurpose]
randomPurposeRegistry = [minBound .. maxBound]

randomPurposeName :: RandomPurpose -> Text
randomPurposeName = \case
  ForecastSubjectDraw -> "forecast_subject_draw"
  ForecastChildDraw -> "forecast_child_draw"
  ForecastOpportunityDraw -> "forecast_opportunity_draw"
  ForecastDependencyDraw -> "forecast_dependency_draw"
  ForecastOccurrenceDraw -> "forecast_occurrence_draw"
  ForecastDomainPathDraw -> "forecast_domain_path_draw"
  ImportanceNearbyComparator -> "importance_nearby_comparator"
  ImportanceProvisionalDirection -> "importance_provisional_direction"
  ImportanceValidationBranch -> "importance_validation_branch"
  EasierWorkSample -> "easier_work_sample"
  DomainTargetSample -> "domain_target_sample"
  RepeatableReturnJitter -> "repeatable_return_jitter"
  PersonalityPhrase -> "personality_phrase"

newtype UUIDAllocation = UUIDAllocation {unUUIDAllocation :: Text}
  deriving stock (Eq, Ord, Show)

data TerminalCapabilities = TerminalCapabilities
  { terminalInteractive :: Bool
  , terminalColor :: Bool
  , terminalEmoji :: Bool
  , terminalWidth :: Int
  , terminalHeight :: Int
  , terminalMotion :: Bool
  }
  deriving stock (Eq, Show)

data FilesystemFacts = FilesystemFacts
  { filesystemDatasetExists :: Bool
  , filesystemWritable :: Bool
  , filesystemCursor :: Maybe Text
  }
  deriving stock (Eq, Show)

data ExternalFact = ExternalFact
  { externalFactKind :: Text
  , externalFactPayload :: ByteString
  }
  deriving stock (Eq, Show)

data RuntimeFacts = RuntimeFacts
  { runtimeNow :: UTCTime
  , runtimeUUIDs :: [UUIDAllocation]
  , runtimeRandomBlocks :: Map RandomPurpose [ByteString]
  , runtimeFilesystem :: FilesystemFacts
  , runtimeTerminal :: TerminalCapabilities
  , runtimeExternalFacts :: [ExternalFact]
  }
  deriving stock (Eq, Show)

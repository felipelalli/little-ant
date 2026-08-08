module LittleAnt.Conformance (
  ContractDescriptor (..),
  EvidenceKind (..),
  SpecHash (..),
)
where

import Data.Aeson (ToJSON (toJSON))
import Data.Text (Text)
import GHC.Generics (Generic)

data EvidenceKind
  = UnitEvidence
  | PropertyEvidence
  | StateMachineEvidence
  | ProtocolEvidence
  | GoldenEvidence
  | EndToEndEvidence
  deriving stock (Eq, Generic, Show)
  deriving anyclass (ToJSON)

newtype SpecHash = SpecHash {unSpecHash :: Text}
  deriving stock (Eq, Generic, Show)
instance ToJSON SpecHash where
  toJSON = toJSON . unSpecHash

data ContractDescriptor = ContractDescriptor
  { evidenceId :: Text
  , rules :: [Text]
  , screens :: [Text]
  , flow :: Maybe Text
  , kind :: EvidenceKind
  , specHashes :: [SpecHash]
  , obligations :: [Text]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (ToJSON)

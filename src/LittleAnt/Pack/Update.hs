module LittleAnt.Pack.Update (
  PackUpdateCandidate (..),
  discoverOfficialPackUpdates,
)
where

import Data.Aeson (ToJSON (..), object, (.=))
import Data.List (maximumBy, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Set qualified as Set
import Data.Text (Text)
import LittleAnt.Pack.Trust
import LittleAnt.SemVer

data PackUpdateCandidate = PackUpdateCandidate
  { updateInstalledArtifact :: PackArtifactIdentity
  , updateCandidateArtifact :: PackArtifactIdentity
  , updateCandidateSignerFingerprint :: Text
  , updateCatalogSequence :: Integer
  }
  deriving stock (Eq, Show)

instance ToJSON PackUpdateCandidate where
  toJSON candidate =
    object
      [ "installed" .= updateInstalledArtifact candidate
      , "candidate" .= updateCandidateArtifact candidate
      , "signer_fingerprint" .= updateCandidateSignerFingerprint candidate
      , "catalog_sequence" .= updateCatalogSequence candidate
      ]

discoverOfficialPackUpdates :: Map Text PackPin -> PackTrustPolicy -> [PackUpdateCandidate]
discoverOfficialPackUpdates installed policy =
  sortOn (artifactName . updateInstalledArtifact) (mapMaybe discoverOne (Map.elems installed))
 where
  discoverOne pin = case (pinTrustOrigin pin, trustOfficialCatalogSequence policy) of
    (PinVerifiedOfficial _, Just sequenceNumber) -> do
      candidate <- newestCandidate (pinArtifact pin)
      pure
        PackUpdateCandidate
          { updateInstalledArtifact = pinArtifact pin
          , updateCandidateArtifact = grantIdentity candidate
          , updateCandidateSignerFingerprint = officialGrantKeyFingerprint candidate
          , updateCatalogSequence = sequenceNumber
          }
    _ -> Nothing

  newestCandidate installedArtifact =
    case filter (isNewerRelease installedArtifact) (Set.toList (trustOfficialReleaseGrants policy)) of
      [] -> Nothing
      candidates -> Just (maximumBy compareGrantVersion candidates)

  isNewerRelease installedArtifact grant =
    officialGrantPublisher grant == artifactPublisher installedArtifact
      && officialGrantName grant == artifactName installedArtifact
      && compareSemVer (officialGrantVersion grant) (artifactVersion installedArtifact) == Just GT

compareGrantVersion :: OfficialReleaseGrant -> OfficialReleaseGrant -> Ordering
compareGrantVersion left right =
  case compareSemVer (officialGrantVersion left) (officialGrantVersion right) of
    Just ordering -> ordering
    Nothing -> comparing officialGrantVersion left right

grantIdentity :: OfficialReleaseGrant -> PackArtifactIdentity
grantIdentity grant =
  PackArtifactIdentity
    { artifactPublisher = officialGrantPublisher grant
    , artifactName = officialGrantName grant
    , artifactVersion = officialGrantVersion grant
    , artifactManifestDigest = officialGrantManifestDigest grant
    , artifactArchiveDigest = officialGrantArchiveDigest grant
    }

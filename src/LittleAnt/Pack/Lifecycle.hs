module LittleAnt.Pack.Lifecycle (
  PackRemovalDisposition (..),
  PackRemovalReference (..),
  PackRemovalDraft (..),
  PackProfileRetention (..),
  PackGcCandidate (..),
  PackGcDraft (..),
  buildPackRemovalDraft,
  profilePackRetention,
  buildPackGcDraft,
)
where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Id (renderUUIDv7)
import LittleAnt.Model
import LittleAnt.Pack.Store (PackStoreEntry (..))
import LittleAnt.Pack.Trust
import LittleAnt.Profile qualified as Profile
import LittleAnt.Store (DatasetCursor)

data PackRemovalDisposition
  = RemovalRetained
  | RemovalMustResolve
  deriving stock (Eq, Ord, Show)

data PackRemovalReference = PackRemovalReference
  { removalReferenceKind :: Text
  , removalReferenceName :: Text
  , removalReferenceComponent :: Maybe Text
  , removalReferenceDisposition :: PackRemovalDisposition
  , removalReferenceReason :: Text
  }
  deriving stock (Eq, Show)

data PackRemovalDraft = PackRemovalDraft
  { packRemovalDisplayName :: Text
  , packRemovalPin :: PackPin
  , packRemovalReferences :: [PackRemovalReference]
  , packRemovalCanApply :: Bool
  , packRemovalProfileRevision :: Text
  }
  deriving stock (Eq, Show)

data PackProfileRetention = PackProfileRetention
  { retentionProfileName :: Text
  , retentionProfileRevision :: Text
  , retentionDatasetCursor :: DatasetCursor
  , retentionArchiveDigests :: Set Text
  }
  deriving stock (Eq, Show)

data PackGcCandidate = PackGcCandidate
  { packGcCandidateArtifact :: PackArtifactIdentity
  , packGcCandidateSignerFingerprint :: Text
  , packGcCandidatePath :: FilePath
  , packGcCandidateByteCount :: Integer
  }
  deriving stock (Eq, Show)

data PackGcDraft = PackGcDraft
  { packGcStoreRoot :: FilePath
  , packGcCandidates :: [PackGcCandidate]
  , packGcTotalBytes :: Integer
  , packGcProfileRevisions :: Map Text Text
  , packGcDatasetCursors :: Map Text DatasetCursor
  }
  deriving stock (Eq, Show)

instance ToJSON PackRemovalDisposition where
  toJSON =
    String . \case
      RemovalRetained -> "retained"
      RemovalMustResolve -> "must_resolve"

instance FromJSON PackRemovalDisposition where
  parseJSON = withText "PackRemovalDisposition" $ \case
    "retained" -> pure RemovalRetained
    "must_resolve" -> pure RemovalMustResolve
    other -> fail ("unknown Pack removal disposition: " <> Text.unpack other)

instance ToJSON PackRemovalReference where
  toJSON reference =
    object $
      [ "kind" .= removalReferenceKind reference
      , "name" .= removalReferenceName reference
      , "disposition" .= removalReferenceDisposition reference
      , "reason" .= removalReferenceReason reference
      ]
        <> maybe [] (pure . ("component" .=)) (removalReferenceComponent reference)

instance FromJSON PackRemovalReference where
  parseJSON = withObject "PackRemovalReference" $ \fields -> do
    rejectUnknown fields ["kind", "name", "component", "disposition", "reason"]
    PackRemovalReference
      <$> fields .: "kind"
      <*> fields .: "name"
      <*> fields .:? "component"
      <*> fields .: "disposition"
      <*> fields .: "reason"

instance ToJSON PackRemovalDraft where
  toJSON draft =
    object
      [ "display_name" .= packRemovalDisplayName draft
      , "pin" .= packRemovalPin draft
      , "references" .= packRemovalReferences draft
      , "can_apply" .= packRemovalCanApply draft
      , "profile_revision" .= packRemovalProfileRevision draft
      ]

instance FromJSON PackRemovalDraft where
  parseJSON = withObject "PackRemovalDraft" $ \fields -> do
    rejectUnknown fields ["display_name", "pin", "references", "can_apply", "profile_revision"]
    PackRemovalDraft
      <$> fields .: "display_name"
      <*> fields .: "pin"
      <*> fields .: "references"
      <*> fields .: "can_apply"
      <*> fields .: "profile_revision"

instance ToJSON PackGcCandidate where
  toJSON candidate =
    object
      [ "artifact" .= packGcCandidateArtifact candidate
      , "signer_fingerprint" .= packGcCandidateSignerFingerprint candidate
      , "path" .= packGcCandidatePath candidate
      , "byte_count" .= packGcCandidateByteCount candidate
      ]

instance FromJSON PackGcCandidate where
  parseJSON = withObject "PackGcCandidate" $ \fields -> do
    rejectUnknown fields ["artifact", "signer_fingerprint", "path", "byte_count"]
    PackGcCandidate
      <$> fields .: "artifact"
      <*> fields .: "signer_fingerprint"
      <*> fields .: "path"
      <*> fields .: "byte_count"

instance ToJSON PackGcDraft where
  toJSON draft =
    object
      [ "store_root" .= packGcStoreRoot draft
      , "candidates" .= packGcCandidates draft
      , "total_bytes" .= packGcTotalBytes draft
      , "profile_revisions" .= packGcProfileRevisions draft
      , "dataset_cursors" .= packGcDatasetCursors draft
      ]

instance FromJSON PackGcDraft where
  parseJSON = withObject "PackGcDraft" $ \fields -> do
    rejectUnknown fields ["store_root", "candidates", "total_bytes", "profile_revisions", "dataset_cursors"]
    PackGcDraft
      <$> fields .: "store_root"
      <*> fields .: "candidates"
      <*> fields .: "total_bytes"
      <*> fields .: "profile_revisions"
      <*> fields .: "dataset_cursors"

buildPackRemovalDraft :: Text -> Text -> Profile.IntegrationsConfig -> State -> PackPin -> PackRemovalDraft
buildPackRemovalDraft profileRevision displayName integrations state pin =
  PackRemovalDraft
    { packRemovalDisplayName = displayName
    , packRemovalPin = pin
    , packRemovalReferences = references
    , packRemovalCanApply = all ((/= RemovalMustResolve) . removalReferenceDisposition) references
    , packRemovalProfileRevision = profileRevision
    }
 where
  identity = pinArtifact pin
  enabled = pinEnabledComponents pin
  references = providerReferences <> sourceReferences <> deliveryReferences <> effectReferences <> reproducibilityReferences
  providerReferences =
    [ PackRemovalReference
        "provider_account"
        name
        (Just (Profile.providerAccountComponent account))
        RemovalRetained
        "This account has an exact Pack pin and will keep using this release after it stops being preferred."
    | (name, account) <- Map.toAscList (Profile.providerAccounts integrations)
    , pinArtifact (Profile.providerAccountPackPin account) == identity
    ]
  sourceReferences =
    [ PackRemovalReference
        "source_binding"
        (renderUUIDv7 (sourceBindingId binding))
        (Just (importProfileAdapterId profile))
        RemovalMustResolve
        "Pause, detach, or rebind this active source before removing its preferred adapter."
    | binding <- Map.elems (stateSourceBindings state)
    , sourceBindingLifecycle binding == SourceBindingActive
    , Just profileId <- [sourceBindingImportProfile binding]
    , Just profile <- [Map.lookup profileId (stateImportProfiles state)]
    , importProfileAdapterId profile `Set.member` enabled
    , not (profileHasExactProviderPin integrations profile identity)
    ]
  deliveryReferences =
    [ PackRemovalReference
        "delivery_binding"
        name
        (Just component)
        RemovalMustResolve
        "This delivery binding has no exact Pack pin; rebind or pause it before removal."
    | (name, component) <- Map.toAscList (Profile.deliveryBindings integrations)
    , component `Set.member` enabled
    ]
  effectReferences =
    [ PackRemovalReference
        "pending_effect"
        (renderUUIDv7 (externalEffectId effect))
        (Just (effectAdapterComponentId custody))
        RemovalMustResolve
        "Reject, withdraw, or finish this nonterminal effect before removing its preferred authority."
    | effect <- Map.elems (stateExternalEffects state)
    , not (terminalEffectStatus (externalEffectStatus effect))
    , Just custody <- [requestCustody (externalEffectRequest effect)]
    , custodyMatches identity (pinSignerFingerprint pin) custody
    ]
  matchingInvocations =
    [ invocation
    | invocation <- Map.elems (stateImportInvocations state)
    , invocationMatches identity (pinSignerFingerprint pin) invocation
    ]
  reproducibilityReferences =
    [ PackRemovalReference
        "reproducibility"
        (Text.pack (show (length matchingInvocations)) <> " accepted import invocation(s)")
        Nothing
        RemovalRetained
        "Their exact signed archive remains retained for reproducibility until those manifests are no longer retained."
    | not (null matchingInvocations)
    ]

profilePackRetention :: Text -> Text -> DatasetCursor -> Profile.IntegrationsConfig -> State -> PackProfileRetention
profilePackRetention name revision cursor integrations state =
  PackProfileRetention name revision cursor (preferred <> providers <> invocations <> effects)
 where
  preferred = Set.fromList [artifactArchiveDigest (pinArtifact pin) | pin <- Map.elems (Profile.installedComponents integrations)]
  providers = Set.fromList [artifactArchiveDigest (pinArtifact (Profile.providerAccountPackPin account)) | account <- Map.elems (Profile.providerAccounts integrations)]
  invocations = Set.fromList [importInvocationPackArchiveDigest invocation | invocation <- Map.elems (stateImportInvocations state)]
  effects =
    Set.fromList
      [ effectAdapterPackArchiveDigest custody
      | effect <- Map.elems (stateExternalEffects state)
      , not (terminalEffectStatus (externalEffectStatus effect))
      , Just custody <- [requestCustody (externalEffectRequest effect)]
      ]

buildPackGcDraft :: FilePath -> [PackProfileRetention] -> [PackStoreEntry] -> PackGcDraft
buildPackGcDraft storeRoot profiles entries =
  PackGcDraft
    { packGcStoreRoot = storeRoot
    , packGcCandidates = candidates
    , packGcTotalBytes = sum (packGcCandidateByteCount <$> candidates)
    , packGcProfileRevisions = Map.fromList [(retentionProfileName profile, retentionProfileRevision profile) | profile <- profiles]
    , packGcDatasetCursors = Map.fromList [(retentionProfileName profile, retentionDatasetCursor profile) | profile <- profiles]
    }
 where
  retained = Set.unions (retentionArchiveDigests <$> profiles)
  candidates =
    [ PackGcCandidate
        (packStoreEntryArtifact entry)
        (packStoreEntrySignerFingerprint entry)
        (packStoreEntryPath entry)
        (packStoreEntryByteCount entry)
    | entry <- entries
    , artifactArchiveDigest (packStoreEntryArtifact entry) `Set.notMember` retained
    ]

profileHasExactProviderPin :: Profile.IntegrationsConfig -> ImportProfile -> PackArtifactIdentity -> Bool
profileHasExactProviderPin integrations profile identity =
  any matches (Map.toAscList (Profile.providerAccounts integrations))
 where
  matches (name, account) =
    Profile.providerAccountComponent account == importProfileAdapterId profile
      && importProfileInputReference profile == importProfileAdapterId profile <> "@" <> name
      && pinArtifact (Profile.providerAccountPackPin account) == identity

invocationMatches :: PackArtifactIdentity -> Text -> ImportInvocation -> Bool
invocationMatches identity signer invocation =
  importInvocationPackPublisher invocation == artifactPublisher identity
    && importInvocationPackName invocation == artifactName identity
    && importInvocationPackVersion invocation == artifactVersion identity
    && importInvocationPackManifestDigest invocation == artifactManifestDigest identity
    && importInvocationPackArchiveDigest invocation == artifactArchiveDigest identity
    && importInvocationSignerFingerprint invocation == signer

custodyMatches :: PackArtifactIdentity -> Text -> EffectAdapterCustody -> Bool
custodyMatches identity signer custody =
  effectAdapterPackPublisher custody == artifactPublisher identity
    && effectAdapterPackName custody == artifactName identity
    && effectAdapterPackVersion custody == artifactVersion identity
    && effectAdapterPackManifestDigest custody == artifactManifestDigest identity
    && effectAdapterPackArchiveDigest custody == artifactArchiveDigest identity
    && effectAdapterSignerFingerprint custody == signer

requestCustody :: ExternalEffectRequest -> Maybe EffectAdapterCustody
requestCustody = \case
  SourceCleanupItemRequest custody _ -> Just custody
  SourceCleanupContainerRequest custody _ -> Just custody
  _ -> Nothing

terminalEffectStatus :: ExternalEffectStatus -> Bool
terminalEffectStatus = \case
  EffectSucceeded -> True
  EffectFailedTerminal -> True
  EffectRejected -> True
  EffectWithdrawn -> True
  _ -> False

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (\key -> Set.notMember key accepted) (fmap Key.toText (KeyMap.keys fields))
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

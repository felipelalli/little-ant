module LittleAnt.Pack.Update (
  PackUpdateCandidate (..),
  PackUpdateDisposition (..),
  PackUpdateBindingPlan (..),
  PackUpdateChange (..),
  PackUpdateDraft (..),
  discoverOfficialPackUpdates,
  buildPackUpdateDraft,
  updateReboundAccounts,
)
where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.List (maximumBy, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import LittleAnt.Error
import LittleAnt.Model
import LittleAnt.Pack.Format
import LittleAnt.Pack.Trust
import LittleAnt.Profile qualified as Profile
import LittleAnt.SemVer
import LittleAnt.Store (sha256Hex)
import LittleAnt.Vault qualified as Vault

data PackUpdateCandidate = PackUpdateCandidate
  { updateInstalledArtifact :: PackArtifactIdentity
  , updateCandidateArtifact :: PackArtifactIdentity
  , updateCandidateSignerFingerprint :: Text
  , updateCatalogSequence :: Integer
  }
  deriving stock (Eq, Show)

data PackUpdateDisposition
  = RebindToCandidate
  | KeepInstalledRelease
  | BindingUnavailable
  deriving stock (Eq, Ord, Show)

data PackUpdateBindingPlan = PackUpdateBindingPlan
  { updateBindingKind :: Text
  , updateBindingName :: Text
  , updateBindingComponent :: Text
  , updateBindingDisposition :: PackUpdateDisposition
  , updateBindingReason :: Text
  }
  deriving stock (Eq, Show)

data PackUpdateChange = PackUpdateChange
  { updateChangeCategory :: Text
  , updateChangeSubject :: Text
  , updateChangeBefore :: Maybe Text
  , updateChangeAfter :: Maybe Text
  }
  deriving stock (Eq, Show)

data PackUpdateDraft = PackUpdateDraft
  { packUpdateSourcePath :: FilePath
  , packUpdateSourceSha256 :: Text
  , packUpdateDisplayName :: Text
  , packUpdateInstalledPin :: PackPin
  , packUpdateCandidateArtifact :: PackArtifactIdentity
  , packUpdateCandidateSignerFingerprint :: Text
  , packUpdateCandidateTrustClass :: Text
  , packUpdateCandidateEnabledComponents :: [Text]
  , packUpdateChanges :: [PackUpdateChange]
  , packUpdateBindings :: [PackUpdateBindingPlan]
  , packUpdateCanApply :: Bool
  , packUpdateProfileRevision :: Text
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

instance ToJSON PackUpdateDisposition where
  toJSON = String . dispositionText

instance FromJSON PackUpdateDisposition where
  parseJSON = withText "PackUpdateDisposition" $ \case
    "rebind" -> pure RebindToCandidate
    "keep_installed" -> pure KeepInstalledRelease
    "unavailable" -> pure BindingUnavailable
    other -> fail ("unknown Pack update disposition: " <> Text.unpack other)

instance ToJSON PackUpdateBindingPlan where
  toJSON plan =
    object
      [ "kind" .= updateBindingKind plan
      , "name" .= updateBindingName plan
      , "component" .= updateBindingComponent plan
      , "disposition" .= updateBindingDisposition plan
      , "reason" .= updateBindingReason plan
      ]

instance FromJSON PackUpdateBindingPlan where
  parseJSON = withObject "PackUpdateBindingPlan" $ \fields -> do
    rejectUnknown fields ["kind", "name", "component", "disposition", "reason"]
    PackUpdateBindingPlan
      <$> fields .: "kind"
      <*> fields .: "name"
      <*> fields .: "component"
      <*> fields .: "disposition"
      <*> fields .: "reason"

instance ToJSON PackUpdateChange where
  toJSON change =
    object $
      [ "category" .= updateChangeCategory change
      , "subject" .= updateChangeSubject change
      ]
        <> maybe [] (pure . ("before" .=)) (updateChangeBefore change)
        <> maybe [] (pure . ("after" .=)) (updateChangeAfter change)

instance FromJSON PackUpdateChange where
  parseJSON = withObject "PackUpdateChange" $ \fields -> do
    rejectUnknown fields ["category", "subject", "before", "after"]
    PackUpdateChange
      <$> fields .: "category"
      <*> fields .: "subject"
      <*> fields .:? "before"
      <*> fields .:? "after"

instance ToJSON PackUpdateDraft where
  toJSON draft =
    object
      [ "source_path" .= packUpdateSourcePath draft
      , "source_sha256" .= packUpdateSourceSha256 draft
      , "display_name" .= packUpdateDisplayName draft
      , "installed_pin" .= packUpdateInstalledPin draft
      , "candidate_artifact" .= packUpdateCandidateArtifact draft
      , "candidate_signer_fingerprint" .= packUpdateCandidateSignerFingerprint draft
      , "candidate_trust_class" .= packUpdateCandidateTrustClass draft
      , "candidate_enabled_components" .= packUpdateCandidateEnabledComponents draft
      , "changes" .= packUpdateChanges draft
      , "bindings" .= packUpdateBindings draft
      , "can_apply" .= packUpdateCanApply draft
      , "profile_revision" .= packUpdateProfileRevision draft
      ]

instance FromJSON PackUpdateDraft where
  parseJSON = withObject "PackUpdateDraft" $ \fields -> do
    rejectUnknown
      fields
      [ "source_path"
      , "source_sha256"
      , "display_name"
      , "installed_pin"
      , "candidate_artifact"
      , "candidate_signer_fingerprint"
      , "candidate_trust_class"
      , "candidate_enabled_components"
      , "changes"
      , "bindings"
      , "can_apply"
      , "profile_revision"
      ]
    PackUpdateDraft
      <$> fields .: "source_path"
      <*> fields .: "source_sha256"
      <*> fields .: "display_name"
      <*> fields .: "installed_pin"
      <*> fields .: "candidate_artifact"
      <*> fields .: "candidate_signer_fingerprint"
      <*> fields .: "candidate_trust_class"
      <*> fields .: "candidate_enabled_components"
      <*> fields .: "changes"
      <*> fields .: "bindings"
      <*> fields .: "can_apply"
      <*> fields .: "profile_revision"

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

buildPackUpdateDraft :: FilePath -> Text -> Text -> Text -> Profile.IntegrationsConfig -> State -> PackPin -> AuthenticatedPack -> AuthenticatedPack -> Either AppError PackUpdateDraft
buildPackUpdateDraft sourcePath sourceDigest trustClass profileRevision integrations state installedPin installed candidate = do
  let installedIdentity = authenticatedPackIdentity installed
      candidateIdentity = authenticatedPackIdentity candidate
      candidateManifest = structurallyValidManifest (authenticatedStructuralPack candidate)
      enabled = sort (componentId . componentCommon <$> packComponents candidateManifest)
  unless (installedIdentity == pinArtifact installedPin) $
    Left (updateProblem CorruptData "The installed Pack bytes do not match the preferred profile pin." [artifactName installedIdentity])
  unless
    ( artifactName installedIdentity == artifactName candidateIdentity
        && artifactPublisher installedIdentity == artifactPublisher candidateIdentity
        && compareSemVer (artifactVersion candidateIdentity) (artifactVersion installedIdentity) == Just GT
    )
    (Left (updateProblem Conflict "The candidate is not a newer release of the installed Pack." [artifactVersion installedIdentity, artifactVersion candidateIdentity]))
  let changes = manifestChanges installed candidate
      bindings = bindingPlan integrations state installedPin installed candidate
      canApply = all ((/= BindingUnavailable) . updateBindingDisposition) bindings
  pure
    PackUpdateDraft
      { packUpdateSourcePath = sourcePath
      , packUpdateSourceSha256 = sourceDigest
      , packUpdateDisplayName = packDisplayName candidateManifest
      , packUpdateInstalledPin = installedPin
      , packUpdateCandidateArtifact = candidateIdentity
      , packUpdateCandidateSignerFingerprint = authenticatedSignerFingerprint candidate
      , packUpdateCandidateTrustClass = trustClass
      , packUpdateCandidateEnabledComponents = enabled
      , packUpdateChanges = changes
      , packUpdateBindings = bindings
      , packUpdateCanApply = canApply
      , packUpdateProfileRevision = profileRevision
      }

updateReboundAccounts :: PackPin -> PackUpdateDraft -> Profile.IntegrationsConfig -> Profile.IntegrationsConfig
updateReboundAccounts candidatePin draft integrations =
  integrations
    { Profile.providerAccounts =
        foldr rebind (Profile.providerAccounts integrations) (packUpdateBindings draft)
    }
 where
  rebind plan accounts
    | updateBindingKind plan == "provider_account" && updateBindingDisposition plan == RebindToCandidate =
        Map.adjust (\account -> account{Profile.providerAccountPackPin = candidatePin}) (updateBindingName plan) accounts
    | otherwise = accounts

manifestChanges :: AuthenticatedPack -> AuthenticatedPack -> [PackUpdateChange]
manifestChanges installed candidate =
  concatMap compareComponent allIds
 where
  installedStructural = authenticatedStructuralPack installed
  candidateStructural = authenticatedStructuralPack candidate
  installedComponents = Map.fromList [(componentId (componentCommon component), component) | component <- packComponents (structurallyValidManifest installedStructural)]
  candidateComponents = Map.fromList [(componentId (componentCommon component), component) | component <- packComponents (structurallyValidManifest candidateStructural)]
  allIds = Set.toAscList (Map.keysSet installedComponents `Set.union` Map.keysSet candidateComponents)
  compareComponent identifier = case (Map.lookup identifier installedComponents, Map.lookup identifier candidateComponents) of
    (Nothing, Just added) -> [PackUpdateChange "component" identifier Nothing (Just (componentSummary added))]
    (Just removed, Nothing) -> [PackUpdateChange "component" identifier (Just (componentSummary removed)) Nothing]
    (Just before, Just after) -> compareFacts identifier (componentFacts installedStructural before) (componentFacts candidateStructural after)
    (Nothing, Nothing) -> []

compareFacts :: Text -> Map Text Text -> Map Text Text -> [PackUpdateChange]
compareFacts subject before after =
  [ PackUpdateChange category subject old new
  | category <- Set.toAscList (Map.keysSet before `Set.union` Map.keysSet after)
  , let old = Map.lookup category before
        new = Map.lookup category after
  , old /= new
  ]

componentFacts :: StructurallyValidPack -> PackComponent -> Map Text Text
componentFacts structural component =
  Map.fromList
    ( [ ("kind", componentKindText (componentKind common))
      , ("contract", Text.pack (show (componentContractMajor common)))
      , ("root", componentRoot common)
      , ("configuration", schemaFact structural common)
      , ("payload", payloadFact structural common)
      ]
        <> executableFacts component
    )
 where
  common = componentCommon component

executableFacts :: PackComponent -> [(Text, Text)]
executableFacts = \case
  DeclarativeComponent _ body -> [("declarative body", body)]
  ExecutableComponent _ entry permissions ->
    [ ("entry point", entry)
    , ("credentials", comma (credentialFact <$> permissionCredentialSlots permissions))
    , ("OAuth device authorization", comma (oauthDeviceFact <$> permissionOAuthDeviceAuthorizations permissions))
    , ("OAuth PKCE authorization", comma (oauthPkceFact <$> permissionOAuthAuthorizationCodePkce permissions))
    , ("HTTP", comma (httpFact <$> permissionHttp permissions))
    , ("external effects", comma (effectPermissionText <$> permissionEffectPurposes permissions))
    , ("projections", comma (permissionProjections permissions))
    , ("host capabilities", comma (hostCapabilityText <$> permissionHostCapabilities permissions))
    ]

schemaFact :: StructurallyValidPack -> ComponentCommon -> Text
schemaFact structural common =
  let declared = componentConfigurationSchema common
      path = componentRoot common <> "/" <> declared
      digest = maybe "missing" sha256Hex (Map.lookup path (structurallyValidPayload structural))
   in declared <> " · sha256:" <> digest

payloadFact :: StructurallyValidPack -> ComponentCommon -> Text
payloadFact structural common =
  Text.pack (show (length entries)) <> " files · sha256:" <> sha256Hex (TextEncoding.encodeUtf8 (Text.intercalate "\n" entries))
 where
  entries =
    [ path <> "@" <> sha256Hex bytes
    | (path, bytes) <- Map.toAscList (structurallyValidPayload structural)
    , componentRoot common == path || (componentRoot common <> "/") `Text.isPrefixOf` path
    ]

componentSummary :: PackComponent -> Text
componentSummary component =
  let common = componentCommon component
   in componentKindText (componentKind common) <> " · contract " <> Text.pack (show (componentContractMajor common))

bindingPlan :: Profile.IntegrationsConfig -> State -> PackPin -> AuthenticatedPack -> AuthenticatedPack -> [PackUpdateBindingPlan]
bindingPlan integrations state installedPin installed candidate =
  sortOn (\plan -> (updateBindingKind plan, updateBindingName plan)) (providerPlans <> deliveryPlans)
 where
  installedIdentity = pinArtifact installedPin
  candidateComponents = Map.fromList [(componentId (componentCommon component), component) | component <- packComponents (structurallyValidManifest (authenticatedStructuralPack candidate))]
  installedComponents = Map.fromList [(componentId (componentCommon component), component) | component <- packComponents (structurallyValidManifest (authenticatedStructuralPack installed))]
  affectedAccounts =
    [ (name, account)
    | (name, account) <- Map.toAscList (Profile.providerAccounts integrations)
    , pinArtifact (Profile.providerAccountPackPin account) == installedIdentity
    ]
  providerPlans = fmap providerPlan affectedAccounts
  providerPlan (name, account) =
    let identifier = Profile.providerAccountComponent account
        accountBindings = [(bindingName, binding) | (bindingName, binding) <- Map.toAscList (Profile.credentialBindings integrations), Profile.credentialBindingAccount binding == name]
        keep reason = PackUpdateBindingPlan "provider_account" name identifier KeepInstalledRelease reason
        rebind = PackUpdateBindingPlan "provider_account" name identifier RebindToCandidate "The compatible static binding will use the reviewed candidate release."
     in case (Map.lookup identifier installedComponents, Map.lookup identifier candidateComponents) of
          (_, Nothing) -> keep "The candidate removes this component; the account keeps its installed release."
          (Nothing, _) -> keep "The installed component cannot be inspected; the account keeps its installed release."
          (Just oldComponent, Just newComponent)
            | componentContractMajor (componentCommon oldComponent) /= componentContractMajor (componentCommon newComponent) -> keep "The component contract major changed."
            | schemaFact (authenticatedStructuralPack installed) (componentCommon oldComponent) /= schemaFact (authenticatedStructuralPack candidate) (componentCommon newComponent) -> keep "The component configuration schema changed."
            | any (isOAuthBinding . snd) accountBindings -> keep "OAuth authority is artifact-bound; reconnect this account before rebinding it."
            | hasPendingEffect state installedIdentity (fmap fst accountBindings) -> keep "A nonterminal external effect still carries the installed Pack authority."
            | not (all (bindingSupported newComponent . snd) accountBindings) -> keep "The candidate no longer declares this static credential slot and scheme."
            | otherwise -> rebind
  affectedDelivery =
    [ (name, component)
    | (name, component) <- Map.toAscList (Profile.deliveryBindings integrations)
    , component `Set.member` pinEnabledComponents installedPin
    ]
  deliveryPlans =
    [ PackUpdateBindingPlan "delivery_binding" name component BindingUnavailable "This binding kind does not yet carry an exact Pack pin; updating it would be ambiguous."
    | (name, component) <- affectedDelivery
    ]

bindingSupported :: PackComponent -> Profile.CredentialBinding -> Bool
bindingSupported component binding = case component of
  ExecutableComponent _ _ permissions ->
    any
      (\slot -> credentialSlotId slot == Profile.credentialBindingSlot binding && credentialSchemeMatches (credentialSlotScheme slot) (Profile.credentialBindingScheme binding))
      (permissionCredentialSlots permissions)
  DeclarativeComponent{} -> False

credentialSchemeMatches :: CredentialScheme -> Vault.CredentialScheme -> Bool
credentialSchemeMatches packScheme vaultScheme = case (packScheme, vaultScheme) of
  (OAuthAuthorizationCodePkce, Vault.OAuthAuthorizationCodePKCE) -> True
  (OAuthDeviceAuthorization, Vault.OAuthDeviceAuthorization) -> True
  (BearerToken, Vault.BearerCredential) -> True
  (ApiKey, Vault.ApiKeyCredential) -> True
  _ -> False

isOAuthBinding :: Profile.CredentialBinding -> Bool
isOAuthBinding binding =
  Profile.credentialBindingScheme binding `elem` [Vault.OAuthAuthorizationCodePKCE, Vault.OAuthDeviceAuthorization]

hasPendingEffect :: State -> PackArtifactIdentity -> [Text] -> Bool
hasPendingEffect state identity bindingNames =
  any matches (Map.elems (stateExternalEffects state))
 where
  matches effect =
    not (terminalEffectStatus (externalEffectStatus effect))
      && maybe False custodyMatches (requestCustody (externalEffectRequest effect))
  custodyMatches custody =
    effectAdapterCredentialBinding custody `elem` bindingNames
      && effectAdapterPackPublisher custody == artifactPublisher identity
      && effectAdapterPackName custody == artifactName identity
      && effectAdapterPackVersion custody == artifactVersion identity
      && effectAdapterPackManifestDigest custody == artifactManifestDigest identity
      && effectAdapterPackArchiveDigest custody == artifactArchiveDigest identity

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

credentialFact :: CredentialSlot -> Text
credentialFact slot = credentialSlotId slot <> ":" <> credentialSchemeText (credentialSlotScheme slot)

oauthDeviceFact :: OAuthDeviceAuthorizationPermission -> Text
oauthDeviceFact permission =
  Text.intercalate
    " | "
    [ oauthDeviceCredentialSlot permission
    , oauthDeviceAuthorizationEndpoint permission
    , oauthDeviceTokenEndpoint permission
    , oauthDeviceClientIdConfigurationKey permission
    , comma (Set.toAscList (oauthDeviceScopes permission))
    ]

oauthPkceFact :: OAuthAuthorizationCodePkcePermission -> Text
oauthPkceFact permission =
  Text.intercalate
    " | "
    [ oauthPkceCredentialSlot permission
    , oauthPkceAuthorizationEndpoint permission
    , oauthPkceTokenEndpoint permission
    , oauthPkceClientIdConfigurationKey permission
    , comma (Set.toAscList (oauthPkceScopes permission))
    , comma [key <> "=" <> value | (key, value) <- Map.toAscList (oauthPkceAuthorizationParameters permission)]
    ]

httpFact :: HttpPermission -> Text
httpFact permission =
  Text.intercalate
    " "
    [ comma (httpPermissionMethods permission)
    , "https://" <> httpPermissionHost permission <> httpPermissionPathPrefix permission
    , maybe "without credentials" ("credential " <>) (httpPermissionCredentialSlot permission)
    ]

comma :: [Text] -> Text
comma = Text.intercalate ", " . sort

dispositionText :: PackUpdateDisposition -> Text
dispositionText = \case
  RebindToCandidate -> "rebind"
  KeepInstalledRelease -> "keep_installed"
  BindingUnavailable -> "unavailable"

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

updateProblem :: ErrorCode -> Text -> [Text] -> AppError
updateProblem code message details =
  (appError code message)
    { appErrorDetails = details
    , appErrorRecovery = [RecoveryAction "inspect" "Keep the installed release and inspect the signed update plan." (Just "lant packs updates")]
    }

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (\key -> Set.notMember key accepted) (fmap Key.toText (KeyMap.keys fields))
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

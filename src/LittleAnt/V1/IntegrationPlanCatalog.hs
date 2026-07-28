{-# LANGUAGE DerivingStrategies #-}

-- | Integration conformance probes for the typed Pack and credential boundary.
-- Registrations use semantic Allium metadata only; obligation IDs are never
-- visible to this module.
module LittleAnt.V1.IntegrationPlanCatalog
  ( integrationPlanProbes
  , integrationRuntimePlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson
  (FromJSON, Result (..), ToJSON (toJSON), Value (..), encode, fromJSON, object,
   (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Char8 as BS8
import Data.IORef (modifyIORef', newIORef, readIORef)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..), RuntimePlanProbe)
import LittleAnt.V1.Integration

integrationPlanProbes :: Map ProbeKey PlanProbe
integrationPlanProbes = Map.fromList
  ( valueRegistrations
  <> contractRegistrations
  <> enumRegistrations
  <> entityRegistrations
  <> transitionRegistrations
  <> ruleRegistrations
  <> invariantRegistrations
  )

integrationRuntimePlanProbes :: Map ProbeKey RuntimePlanProbe
integrationRuntimePlanProbes = Map.singleton
  (ProbeKey "integration" "contract_signature" "PackRunner.execute")
  executionBoundaryProbe

valueRegistrations :: [(ProbeKey, PlanProbe)]
valueRegistrations = concatMap valueRegistration
  [ "PackExecutionRequest", "PackExecutionResult"
  , "PackComponentManifest", "PackInstallManifest"
  ]
  where
    valueRegistration construct =
      [ registration "value_equality" construct valueProbe
      , registration "entity_fields" construct valueProbe
      ]

contractRegistrations :: [(ProbeKey, PlanProbe)]
contractRegistrations =
  [ registration "contract_signature" "HostHttp.request" hostHttpProbe
  , registration "contract_signature" "CredentialBroker.authorize"
      credentialBrokerProbe
  ]

enumRegistrations :: [(ProbeKey, PlanProbe)]
enumRegistrations =
  [ registration "enum_comparable" "PackComponentKind" enumProbe
  , registration "enum_comparable" "PackStatus" enumProbe
  , registration "enum_comparable" "ComponentStatus" enumProbe
  , registration "enum_comparable" "CredentialBindingStatus" enumProbe
  ]

entityRegistrations :: [(ProbeKey, PlanProbe)]
entityRegistrations =
  [ registration "entity_fields" "LittleAntPack" entityProbe
  , registration "entity_fields" "PackComponent" entityProbe
  , registration "entity_fields" "PackInvocation" entityProbe
  , registration "entity_fields" "PackInstallation" entityProbe
  , registration "entity_fields" "CredentialSlot" entityProbe
  , registration "entity_fields" "VaultEntry" entityProbe
  , registration "entity_optional" "VaultEntry.rotated_at" entityProbe
  , registration "entity_fields" "CredentialBinding" entityProbe
  ]

transitionRegistrations :: [(ProbeKey, PlanProbe)]
transitionRegistrations =
  [ registration category "CredentialBinding.status" credentialLifecycleProbe
  | category <- ["transition_edge", "transition_rejected", "transition_terminal"]
  ]

ruleRegistrations :: [(ProbeKey, PlanProbe)]
ruleRegistrations = concat
  [ rules "VerifiedPackInstalled"
      ["rule_success", "rule_failure", "rule_entity_creation"] packInstallProbe
  , rules "PackDisabled" ["rule_success", "rule_failure"] packDisableProbe
  , rules "PackInvocationRecorded"
      ["rule_success", "rule_failure", "rule_entity_creation"] invocationProbe
  , rules "PackReenabled" ["rule_success", "rule_failure"] packEnableProbe
  , rules "PackRevoked" ["rule_success", "rule_failure"] packRevokeProbe
  , rules "CredentialStored"
      ["rule_success", "rule_entity_creation"] credentialStoredProbe
  , rules "CredentialBound"
      ["rule_success", "rule_failure", "rule_entity_creation"] credentialBoundProbe
  , rules "CredentialBindingLocked"
      ["rule_success", "rule_failure"] credentialLifecycleProbe
  , rules "CredentialBindingUnlocked"
      ["rule_success", "rule_failure"] credentialLifecycleProbe
  , rules "CredentialBindingRevoked"
      ["rule_success", "rule_failure"] credentialLifecycleProbe
  ]
  where
    rules construct categories probe =
      [registration category construct probe | category <- categories]

invariantRegistrations :: [(ProbeKey, PlanProbe)]
invariantRegistrations =
  [ registration "invariant" "ComponentKindIsClosed" typedKindsProbe
  , registration "invariant" "PackVersionIdentityIsUnique" packInstallProbe
  , registration "invariant" "ExecutableComponentsUseTypedKinds" typedKindsProbe
  , registration "invariant" "DeclarativeComponentsAreNotExecutable" typedKindsProbe
  , registration "invariant" "OneLiveCredentialBindingPerSlotAndAccount"
      credentialBoundProbe
  , registration "invariant" "VaultIsNotPackContent" vaultIsolationProbe
  ]

registration :: Text -> Text -> PlanProbe -> (ProbeKey, PlanProbe)
registration category construct probe =
  (ProbeKey "integration" category construct, \input -> do
    checkMetadata category construct input
    probe input)

checkMetadata :: Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata category construct input = do
  require (planProbeModule input == "integration")
    "integration probe received a different module"
  require (planProbeCategory input == category)
    "integration probe received a different category"
  require (planProbeSourceConstruct input == construct)
    "integration probe received a different source construct"

valueProbe :: PlanProbe
valueProbe input = case planProbeSourceConstruct input of
  "PackExecutionRequest" -> roundTripAndFields sampleRequest
    ["protocol_version", "component_id", "operation", "input", "capability_grants"]
  "PackExecutionResult" -> roundTripAndFields sampleSuccess
    ["protocol_version", "ok", "output", "error_code", "diagnostics"]
  "PackComponentManifest" -> roundTripAndFields sourceManifest
    ["id", "version", "kind", "executable", "capabilities"]
  "PackInstallManifest" -> roundTripAndFields sampleManifest
    ["id", "version", "publisher", "content_hash", "components"]
  construct -> Left ("unsupported Pack value probe: " <> construct)

roundTripAndFields ::
  (Eq value, ToJSON value, FromJSON value) =>
  value -> [Text] -> Either Text ()
roundTripAndFields value expectedFields = do
  let encoded = toJSON value
  objectValue <- asObject encoded
  require (all (\field -> KeyMap.member (Key.fromText field) objectValue)
      expectedFields) "typed projection omits a declared field"
  decoded <- case fromJSON encoded of
    Success result -> Right result
    Error problem -> Left (Text.pack problem)
  require (decoded == value) "typed value failed structural round-trip equality"

contractFixture :: Either Text
  (PackState, PackDeployment, Text, Text, Text)
contractFixture = do
  (_, components, installed) <- mapIntegration
    (installPack testTime sampleEvidence sampleManifest emptyPackState)
  component <- case components of
    value : _ -> Right value
    [] -> Left "installed Pack has no component"
  (entry, vault1) <- mapIntegration
    (storeCredential testTime "Example API" "ciphertext:never-runtime" emptyVaultState)
  (slot, vault2) <- mapIntegration
    (declareCredentialSlot (packComponentId component) "api-token" "api_key" True vault1)
  (binding, vault3) <- mapIntegration
    (bindCredential testTime (credentialSlotId slot) "felipe" (vaultEntryId entry) vault2)
  pure (installed, defaultPackDeployment {packDeploymentVault = vault3},
    packComponentId component, credentialBindingId binding, credentialSlotId slot)

executionBoundaryProbe :: RuntimePlanProbe
executionBoundaryProbe input = case do
    checkMetadata "contract_signature" "PackRunner.execute" input
    contractFixture of
  Left problem -> pure (Left problem)
  Right (installed, deployment, component, binding, _) -> do
    let source = BS8.pack
          "return lant.http.request {method='GET', url='https://api.example.com/v1/tasks', body_size=0}"
        beforeBackoff = providerBackoff component "felipe" installed
    providerCalls <- newIORef (0 :: Integer)
    let provider _ = do
          modifyIORef' providerCalls (+ 1)
          pure (ProviderFailed "rate limit")
        notReached _ = do
          modifyIORef' providerCalls (+ 1000)
          pure (ProviderFailed "must not run")
    case lockCredentialBinding binding (packDeploymentVault deployment) of
      Left problem -> pure (Left (Text.pack (show problem)))
      Right (_, lockedVault) -> do
        lockedAttempt <- executePackRuntime False testTime "felipe" notReached
          source sampleRequest installed
          (deployment {packDeploymentVault = lockedVault})
        let revokedResult = do
              (revokedBinding, revokedVault) <- revokeCredentialBinding binding
                (packDeploymentVault deployment)
              pure (revokedBinding, revokedVault)
        case revokedResult of
          Left problem -> pure (Left (Text.pack (show problem)))
          Right (revokedBinding, revokedVault) -> do
            revokedAttempt <- executePackRuntime False testTime "felipe" notReached
              source sampleRequest installed
              (deployment {packDeploymentVault = revokedVault})
            let unauthorized = deployment
                  {packDeploymentVault = (packDeploymentVault deployment)
                    {vaultStateBindings = Map.empty}}
            unauthorizedAttempt <- executePackRuntime False testTime "felipe"
              notReached source sampleRequest installed unauthorized
            providerAttempt <- executePackRuntime False testTime "felipe" provider
              source sampleRequest installed deployment
            replayAttempt <- executePackRuntime True testTime "felipe" notReached
              source sampleRequest installed deployment
            callCount <- readIORef providerCalls
            pure $ do
              (lockedResult, afterLocked, lockedAfterDeployment) <-
                mapIntegration lockedAttempt
              require (packExecutionResultErrorCode lockedResult
                  == Just "credential_locked")
                "locked credentials did not return credential_locked"
              require (null (packDeploymentHttpTrace lockedAfterDeployment))
                "locked credential performed HTTP"
              require (packDeploymentExecutionCount lockedAfterDeployment == 0)
                "locked credential executed Pack code"
              require (providerBackoff component "felipe" afterLocked
                  == beforeBackoff)
                "locked credential advanced provider backoff"
              require (credentialBindingStatus revokedBinding == CredentialRevoked)
                "credential revocation was not retained"
              (revokedExecution, _, revokedDeployment) <-
                mapIntegration revokedAttempt
              require (packExecutionResultErrorCode revokedExecution
                  == Just "credential_revoked")
                "revoked credentials did not return credential_revoked"
              require (null (packDeploymentHttpTrace revokedDeployment))
                "revoked credential performed HTTP"
              (unauthorizedResult, _, unauthorizedDeployment) <-
                mapIntegration unauthorizedAttempt
              require (packExecutionResultErrorCode unauthorizedResult
                  == Just "credential_unauthorized")
                "missing authorization did not return credential_unauthorized"
              require (null (packDeploymentHttpTrace unauthorizedDeployment))
                "unauthorized request performed HTTP"
              (providerResult, providerState, providerDeployment) <-
                mapIntegration providerAttempt
              require (packExecutionResultErrorCode providerResult
                  == Just "provider_failure")
                "authorized provider failure was not classified distinctly"
              require (length (packDeploymentHttpTrace providerDeployment) == 1)
                "Lua host request did not reach HTTP exactly once"
              require (providerBackoff component "felipe" providerState
                  == beforeBackoff + 1)
                "actual authorized provider failure did not advance backoff"
              require (length (packStateInvocations providerState) == 1)
                "authorized Pack execution omitted invocation evidence"
              require (not (containsSecretName
                  (toJSON (packStateInvocations providerState))))
                "invocation evidence contains credential material"
              require (callCount == 1)
                "provider was called without one authorized Lua host request"
              expectError ReplayExecutionForbidden replayAttempt

hostHttpProbe :: PlanProbe
hostHttpProbe _ = do
  (installed, _, componentId, _, _) <- contractFixture
  component <- mapIntegration (findComponent componentId installed)
  mapIntegration (validateHostHttpRequest component
    ["http:api.example.com"]
    (HostHttpRequest "GET" "https://api.example.com/v1/tasks" 0 Nothing))
  expectError (UndeclaredCapability "http:evil.example")
    (validateHostHttpRequest component ["http:api.example.com"]
      (HostHttpRequest "GET" "https://evil.example/v1/tasks" 0 Nothing))
  expectErrorMatching isHostError
    (validateHostHttpRequest component ["http:api.example.com"]
      (HostHttpRequest "TRACE" "https://api.example.com/" 0 Nothing))
  expectErrorMatching isHostError
    (validateHostHttpRequest component ["http:api.example.com"]
      (HostHttpRequest "POST" "https://api.example.com/" 1048577 Nothing))
  expectErrorMatching isHostError
    (validateHostHttpRequest component ["http:api.example.com"]
      (HostHttpRequest "GET" "https://api.example.com/" 0
        (Just "https://evil.example/")))
  where
    isHostError (InvalidHostHttpRequest _) = True
    isHostError _ = False

credentialBrokerProbe :: PlanProbe
credentialBrokerProbe _ = do
  (_, deployment, component, binding, _) <- contractFixture
  active <- mapIntegration
    (authorizeCredential component "felipe" (packDeploymentVault deployment))
  require (credentialBindingId active == binding)
    "authorized binding identity changed"
  (_, locked) <- mapIntegration
    (lockCredentialBinding binding (packDeploymentVault deployment))
  expectError CredentialAccessLocked
    (authorizeCredential component "felipe" locked)
  (_, revoked) <- mapIntegration
    (revokeCredentialBinding binding (packDeploymentVault deployment))
  expectError CredentialAccessRevoked
    (authorizeCredential component "felipe" revoked)
  expectError CredentialAccessUnauthorized
    (authorizeCredential component "different-account"
      (packDeploymentVault deployment))
  expectError VaultUnavailable
    (authorizeCredential component "felipe"
      ((packDeploymentVault deployment) {vaultStateUnlocked = False}))

valueEnums :: [[Value]]
valueEnums =
  [ map toJSON
      [ BrickBehaviorComponent, BrickTemplateComponent
      , ImportProfilePresetComponent, SourceAdapterComponent
      , EnricherComponent, ReadOnlyExporterComponent, UiAdapterComponent
      ]
  , map toJSON [PackInstalled, PackDisabled, PackRevoked]
  , map toJSON [ComponentEnabled, ComponentDisabled, ComponentRevoked]
  , map toJSON [CredentialActive, CredentialLocked, CredentialRevoked]
  ]

enumProbe :: PlanProbe
enumProbe _ = mapM_ checkEnum valueEnums
  where
    checkEnum values = do
      require (Set.size (Set.fromList (map encode values)) == length values)
        "closed enum values do not have distinct encodings"
      require (all canonical values) "closed enum value is not canonical text"
    canonical (String value) = Text.toLower value == value && not (Text.null value)
    canonical _ = False

entityProbe :: PlanProbe
entityProbe input = do
  (state, deployment, _, bindingId, slotId) <- contractFixture
  pack <- mapIntegration (findPack "community/example" state)
  component <- mapIntegration (findComponent "example/source" state)
  binding <- maybe (Left "fixture binding missing") Right
    (Map.lookup bindingId (vaultStateBindings (packDeploymentVault deployment)))
  slot <- maybe (Left "fixture slot missing") Right
    (Map.lookup slotId (vaultStateSlots (packDeploymentVault deployment)))
  entry <- case Map.elems (vaultStateEntries (packDeploymentVault deployment)) of
    value : _ -> Right value
    [] -> Left "fixture VaultEntry missing"
  let installation = case packStateInstallations state of
        value : _ -> Just value
        [] -> Nothing
      invocationResult = recordPackInvocation testTime "example/source" "discover"
        "1" "sha256:req" ["http:api.example.com"] sampleSuccess state
  (invocation, _) <- mapIntegration invocationResult
  case planProbeSourceConstruct input of
    "LittleAntPack" -> fields (toJSON pack)
      ["id", "version", "publisher", "content_hash", "status"]
    "PackComponent" -> fields (toJSON component)
      ["id", "version", "pack", "kind", "executable", "status", "capabilities"]
    "PackInvocation" -> fields (toJSON invocation)
      [ "id", "component", "pack_content_hash", "component_version", "operation"
      , "input_revision", "request_hash", "capability_grants", "result", "invoked_at"
      ]
    "PackInstallation" -> maybe (Left "installation missing")
      (\value -> fields (toJSON value)
        ["id", "pack", "manifest", "installed_at"]) installation
    "CredentialSlot" -> fields (toJSON slot)
      ["id", "component", "name", "authentication_kind", "required"]
    "VaultEntry" -> fields (toJSON entry)
      ["id", "label", "encrypted_payload", "created_at", "rotated_at"]
    "VaultEntry.rotated_at" -> do
      objectValue <- asObject (toJSON entry)
      require (KeyMap.lookup "rotated_at" objectValue == Just Null)
        "absent Vault rotation is not represented as null"
      fields (toJSON (entry {vaultEntryRotatedAt = Just testTime})) ["rotated_at"]
    "CredentialBinding" -> fields (credentialBindingProjection binding)
      ["id", "slot", "account", "vault_entry_id", "status", "created_at"]
    construct -> Left ("unsupported Pack entity probe: " <> construct)

packInstallProbe :: PlanProbe
packInstallProbe _ = do
  (pack, components, installed) <- mapIntegration
    (installPack testTime allKindsEvidence allKindsManifest emptyPackState)
  require (littleAntPackStatus pack == PackInstalled)
    "verified Pack was not activated"
  require (length components == 7 && all
      ((== ComponentEnabled) . packComponentStatus) components)
    "installation did not create every declared enabled component"
  require (length (packStateInstallations installed) == 1)
    "installation provenance was not recorded"
  expectError PackArchiveNotVerified
    (installPack testTime (allKindsEvidence
      {packInstallEvidenceVerifiedContentHash = "sha256:different"})
      allKindsManifest emptyPackState)
  expectError PackManifestIncompatible
    (installPack testTime (allKindsEvidence
      {packInstallEvidenceCompatibleProtocol = 2})
      allKindsManifest emptyPackState)
  expectError PackPublisherUntrusted
    (installPack testTime (allKindsEvidence
      {packInstallEvidenceTrustedPublisher = False})
      allKindsManifest emptyPackState)
  expectErrorMatching isInvalidManifest
    (installPack testTime allKindsEvidence
      (allKindsManifest {packInstallManifestComponents = []}) emptyPackState)
  expectError (PackVersionAlreadyInstalled "community/all-kinds" 1)
    (installPack testTime allKindsEvidence allKindsManifest installed)
  where
    isInvalidManifest (InvalidPackManifest _) = True
    isInvalidManifest _ = False

packDisableProbe :: PlanProbe
packDisableProbe _ = do
  (_, _, installed) <- mapIntegration
    (installPack testTime sampleEvidence sampleManifest emptyPackState)
  disabled <- mapIntegration (disablePack "community/example" installed)
  pack <- mapIntegration (findPack "community/example" disabled)
  require (littleAntPackStatus pack == PackDisabled)
    "DisablePack did not disable the Pack"
  require (all ((== ComponentDisabled) . packComponentStatus)
      (Map.elems (packStateComponents disabled)))
    "DisablePack did not disable every enabled component"
  expectError (InvalidPackStatus PackDisabled)
    (disablePack "community/example" disabled)

packEnableProbe :: PlanProbe
packEnableProbe _ = do
  (_, _, installed) <- mapIntegration
    (installPack testTime sampleEvidence sampleManifest emptyPackState)
  expectError (InvalidPackStatus PackInstalled)
    (enablePack "community/example" installed)
  disabled <- mapIntegration (disablePack "community/example" installed)
  enabled <- mapIntegration (enablePack "community/example" disabled)
  require (all ((== ComponentEnabled) . packComponentStatus)
      (Map.elems (packStateComponents enabled)))
    "EnablePack did not re-enable disabled components"

packRevokeProbe :: PlanProbe
packRevokeProbe _ = do
  (_, _, installed) <- mapIntegration
    (installPack testTime sampleEvidence sampleManifest emptyPackState)
  revokedFromInstalled <- mapIntegration (revokePack "community/example" installed)
  checkRevoked revokedFromInstalled
  expectError (InvalidPackStatus PackRevoked)
    (revokePack "community/example" revokedFromInstalled)
  disabled <- mapIntegration (disablePack "community/example" installed)
  revokedFromDisabled <- mapIntegration (revokePack "community/example" disabled)
  checkRevoked revokedFromDisabled
  where
    checkRevoked state = do
      pack <- mapIntegration (findPack "community/example" state)
      require (littleAntPackStatus pack == PackRevoked)
        "RevokePack did not revoke Pack status"
      require (all ((== ComponentRevoked) . packComponentStatus)
          (Map.elems (packStateComponents state)))
        "RevokePack did not revoke every component"

invocationProbe :: PlanProbe
invocationProbe _ = do
  (_, _, installed) <- mapIntegration
    (installPack testTime sampleEvidence sampleManifest emptyPackState)
  (invocation, invoked) <- mapIntegration (recordPackInvocation testTime
    "example/source" "discover" "7" "sha256:req"
    ["http:api.example.com", "credential:example"] sampleSuccess installed)
  require (packInvocationPackContentHash invocation == "sha256:pack")
    "invocation did not pin Pack content hash"
  require (packInvocationComponentVersion invocation == 1)
    "invocation did not pin component version"
  require (length (packStateInvocations invoked) == 1)
    "invocation evidence was not retained"
  expectError (UndeclaredCapability "http:evil.example")
    (recordPackInvocation testTime "example/source" "discover" "7"
      "sha256:req" ["http:evil.example"] sampleSuccess installed)
  disabled <- mapIntegration (disablePack "community/example" installed)
  expectError (InvalidComponentStatus ComponentDisabled)
    (recordPackInvocation testTime "example/source" "discover" "7"
      "sha256:req" [] sampleSuccess disabled)

credentialStoredProbe :: PlanProbe
credentialStoredProbe _ = do
  (entry, vault) <- mapIntegration
    (storeCredential testTime "Example" "ciphertext:opaque" emptyVaultState)
  require (Map.lookup (vaultEntryId entry) (vaultStateEntries vault) == Just entry)
    "stored credential is absent from the local vault"
  require (vaultEntryRotatedAt entry == Nothing)
    "new VaultEntry unexpectedly has rotation evidence"

credentialBoundProbe :: PlanProbe
credentialBoundProbe _ = do
  (_, deployment, component, bindingId, slotId) <- contractFixture
  let vault = packDeploymentVault deployment
  binding <- maybe (Left "fixture binding missing") Right
    (Map.lookup bindingId (vaultStateBindings vault))
  require (credentialBindingStatus binding == CredentialActive)
    "new credential binding is not active"
  expectError (DuplicateLiveCredentialBinding slotId "felipe")
    (bindCredential testTime slotId "felipe"
      (credentialBindingVaultEntryId binding) vault)
  (_, locked) <- mapIntegration (lockCredentialBinding bindingId vault)
  expectError (DuplicateLiveCredentialBinding slotId "felipe")
    (bindCredential testTime slotId "felipe"
      (credentialBindingVaultEntryId binding) locked)
  (_, revoked) <- mapIntegration (revokeCredentialBinding bindingId vault)
  (_, rebound) <- mapIntegration (bindCredential testTime slotId "felipe"
    (credentialBindingVaultEntryId binding) revoked)
  mapIntegration (validateVaultState rebound)
  _ <- mapIntegration (authorizeCredential component "felipe" rebound)
  pure ()

credentialLifecycleProbe :: PlanProbe
credentialLifecycleProbe _ = do
  (_, deployment, _, bindingId, _) <- contractFixture
  let active = packDeploymentVault deployment
  (lockedBinding, locked) <- mapIntegration
    (lockCredentialBinding bindingId active)
  require (credentialBindingStatus lockedBinding == CredentialLocked)
    "active -> locked transition failed"
  (unlockedBinding, _) <- mapIntegration
    (unlockCredentialBinding bindingId locked)
  require (credentialBindingStatus unlockedBinding == CredentialActive)
    "locked -> active transition failed"
  (revokedFromActive, activeRevoked) <- mapIntegration
    (revokeCredentialBinding bindingId active)
  require (credentialBindingStatus revokedFromActive == CredentialRevoked)
    "active -> revoked transition failed"
  (revokedFromLocked, lockedRevoked) <- mapIntegration
    (revokeCredentialBinding bindingId locked)
  require (credentialBindingStatus revokedFromLocked == CredentialRevoked)
    "locked -> revoked transition failed"
  let expectTerminal vault operation = expectError
        (InvalidCredentialBindingStatus CredentialRevoked)
        (operation bindingId vault)
  mapM_ (expectTerminal activeRevoked)
    [lockCredentialBinding, unlockCredentialBinding, revokeCredentialBinding]
  mapM_ (expectTerminal lockedRevoked)
    [lockCredentialBinding, unlockCredentialBinding, revokeCredentialBinding]
  expectError (InvalidCredentialBindingStatus CredentialLocked)
    (lockCredentialBinding bindingId locked)
  expectError (InvalidCredentialBindingStatus CredentialActive)
    (unlockCredentialBinding bindingId active)

-- Every declared kind is installed in one manifest so executable/declarative
-- checks fail if any individual variant is accidentally broadened.
typedKindsProbe :: PlanProbe
typedKindsProbe _ = do
  (_, components, state) <- mapIntegration
    (installPack testTime allKindsEvidence allKindsManifest emptyPackState)
  require (Set.fromList (map packComponentKind components)
      == Set.fromList allKinds)
    "closed component vocabulary is incomplete"
  require (all (\component -> packComponentExecutable component
      == executableKind (packComponentKind component)) components)
    "typed component execution invariant does not hold for every kind"
  mapIntegration (validatePackState state)
  mapM_ rejectWrongExecutable allKinds
  where
    rejectWrongExecutable kind = expectErrorMatching isInvalidManifest
      (installPack testTime singleEvidence
        (singleManifest kind (not (executableKind kind))) emptyPackState)
    isInvalidManifest (InvalidPackManifest _) = True
    isInvalidManifest _ = False

vaultIsolationProbe :: PlanProbe
vaultIsolationProbe _ = do
  (_, deployment, _, _, _) <- contractFixture
  let content = packContentProjection sampleManifest
      canonical = packStateProjection emptyPackState
      vault = packDeploymentVault deployment
  require (not (containsSecretName content))
    "Pack content projection contains a vault or credential secret field"
  require (not (containsSecretName canonical))
    "canonical Pack state contains local vault content"
  require (not (Map.null (vaultStateEntries vault)))
    "isolation probe did not create real local vault state"

fields :: Value -> [Text] -> Either Text ()
fields value expected = do
  objectValue <- asObject value
  require (all (\field -> KeyMap.member (Key.fromText field) objectValue) expected)
    "entity projection omits one or more declared fields"

asObject :: Value -> Either Text (KeyMap.KeyMap Value)
asObject = \case
  Object fieldsValue -> Right fieldsValue
  _ -> Left "expected object projection"

containsSecretName :: Value -> Bool
containsSecretName = \case
  Object values -> any forbidden (map (Text.toLower . Key.toText)
      (KeyMap.keys values)) || any containsSecretName (KeyMap.elems values)
  Array values -> any containsSecretName values
  _ -> False
  where
    forbidden key = key `elem`
      ["secret", "token", "vault_payload", "encrypted_payload"]

mapIntegration :: Either IntegrationError value -> Either Text value
mapIntegration = either (Left . Text.pack . show) Right

expectError ::
  (Eq problem, Show problem) => problem -> Either problem value -> Either Text ()
expectError expected result = case result of
  Left actual | actual == expected -> Right ()
              | otherwise -> Left ("unexpected rejection: " <> Text.pack (show actual))
  Right _ -> Left ("expected rejection was accepted: " <> Text.pack (show expected))

expectErrorMatching ::
  Show problem => (problem -> Bool) -> Either problem value -> Either Text ()
expectErrorMatching predicate result = case result of
  Left actual | predicate actual -> Right ()
              | otherwise -> Left ("unexpected rejection: " <> Text.pack (show actual))
  Right _ -> Left "expected rejection was accepted"

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

testTime :: UTCTime
testTime = UTCTime (fromGregorian 2026 7 27) (22 * 60 * 60)

sourceManifest :: PackComponentManifest
sourceManifest = PackComponentManifest
  { packComponentManifestId = "example/source"
  , packComponentManifestVersion = 1
  , packComponentManifestKind = SourceAdapterComponent
  , packComponentManifestExecutable = True
  , packComponentManifestCapabilities =
      ["http:api.example.com", "credential:example"]
  }

sampleManifest :: PackInstallManifest
sampleManifest = PackInstallManifest
  { packInstallManifestId = "community/example"
  , packInstallManifestVersion = 1
  , packInstallManifestPublisher = "Example"
  , packInstallManifestContentHash = "sha256:pack"
  , packInstallManifestComponents = [sourceManifest]
  }

sampleEvidence :: PackInstallEvidence
sampleEvidence = PackInstallEvidence "sha256:pack" 1 True

sampleRequest :: PackExecutionRequest
sampleRequest = PackExecutionRequest 1 "example/source" "discover"
  (object ["account" .= ("felipe" :: Text)])
  ["http:api.example.com", "credential:example"]

sampleSuccess :: PackExecutionResult
sampleSuccess = PackExecutionResult 1 True (Just (object ["items" .= ([] :: [Value])]))
  Nothing []

allKinds :: [PackComponentKind]
allKinds =
  [ BrickBehaviorComponent, BrickTemplateComponent, ImportProfilePresetComponent
  , SourceAdapterComponent, EnricherComponent, ReadOnlyExporterComponent
  , UiAdapterComponent
  ]

allKindsManifest :: PackInstallManifest
allKindsManifest = PackInstallManifest
  { packInstallManifestId = "community/all-kinds"
  , packInstallManifestVersion = 1
  , packInstallManifestPublisher = "Example"
  , packInstallManifestContentHash = "sha256:all-kinds"
  , packInstallManifestComponents = zipWith component allKinds [1 :: Int ..]
  }
  where
    component kind ordinal = PackComponentManifest
      { packComponentManifestId = "all-kinds/component-" <> Text.pack (show ordinal)
      , packComponentManifestVersion = 1
      , packComponentManifestKind = kind
      , packComponentManifestExecutable = executableKind kind
      , packComponentManifestCapabilities = if kind == SourceAdapterComponent
          then ["http:api.example.com"] else []
      }

allKindsEvidence :: PackInstallEvidence
allKindsEvidence = PackInstallEvidence "sha256:all-kinds" 1 True

singleManifest :: PackComponentKind -> Bool -> PackInstallManifest
singleManifest kind executable = PackInstallManifest
  { packInstallManifestId = "community/single"
  , packInstallManifestVersion = 1
  , packInstallManifestPublisher = "Example"
  , packInstallManifestContentHash = "sha256:single"
  , packInstallManifestComponents =
      [PackComponentManifest "single/component" 1 kind executable []]
  }

singleEvidence :: PackInstallEvidence
singleEvidence = PackInstallEvidence "sha256:single" 1 True

executableKind :: PackComponentKind -> Bool
executableKind kind = kind `elem`
  [SourceAdapterComponent, EnricherComponent, ReadOnlyExporterComponent,
   UiAdapterComponent]

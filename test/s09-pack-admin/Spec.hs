module Main (main) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar, threadDelay)
import Control.Exception (bracket)
import Data.Aeson (Value (Object), encode, object, toJSON, (.=))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bits ((.&.))
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.IORef
import Data.List (isInfixOf)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust, isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Import
import LittleAnt.Interaction
import LittleAnt.Model (SourceMode (..))
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Admin
import LittleAnt.Pack.Official
import LittleAnt.Pack.Store
import LittleAnt.Pack.Trust
import LittleAnt.Profile qualified as Profile
import LittleAnt.Protocol
import LittleAnt.Provider
import LittleAnt.Provider.Connection
import LittleAnt.REPL
import LittleAnt.Result
import LittleAnt.Source (SourceContainer (..))
import LittleAnt.Store (DatasetCursor (Genesis))
import LittleAnt.Surface
import LittleAnt.Vault qualified as Vault
import LittleAnt.Vault.Age (makePassphrase)
import LittleAnt.Vault.Agent
import System.Directory (doesFileExist, doesPathExist)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Files (fileMode, getFileStatus)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 Pack administration"
      [ testCase "list exposes the exact bundled Pack without mutating the dataset" listBuiltIn
      , testCase "show resolves only the exact Pack name and returns component authority" showBuiltIn
      , testCase "show rejects an unknown Pack with an educational recovery" rejectUnknown
      , testCase "read-only dry-run remains visibly read-only and sparse" dryRunList
      , testCase "Pack inspection remains available when one configured archive is unavailable" inspectBrokenRegistry
      , testCase "community installation separates signer trust from archive installation" communityTrustThenInstall
      , testCase "Pack dry-run exposes the same preview without arming a checkpoint" installDryRunLeavesNothing
      , testCase "standalone publisher trust is profile-local and separately consented" standalonePublisherTrust
      , testCase "profile drift regenerates an unapproved trust preview" trustProfileDrift
      , testCase "archive drift invalidates and discards the pending consent" archiveDriftInvalidates
      , testCase "profile compare-and-swap never clobbers a newer integration revision" profileCompareAndSwap
      , testCase "publisher-key transport requires its closed canonical schema" strictPublisherKeyDocument
      , testCase "the dumb REPL Pack manager stays navigational and keyboard-first" replPackManager
      , testCase "the dumb scoped-import selector has exact checkboxes and no default" replScopedImportSelector
      , testCase "the published root refreshes once and rejects catalog equivocation" officialCatalogRefresh
      , testCase "an official name installs the exact catalog release without publisher trust" officialCatalogInstall
      , testCase "official refresh dry-run persists no accepted authority" officialCatalogRefreshDryRun
      , testCase "provider connection keeps OAuth transient and enables the production import source" providerConnectionEnablesImport
      ]

listBuiltIn :: Assertion
listBuiltIn = withHarness $ \environment -> do
  result <- run environment False PacksListCommand
  case result of
    PacksResult Genesis "list" [pack] Nothing False -> do
      projectedPackName pack @?= "org.littleant.standard"
      projectedPackDisplayName pack @?= "Little Ant Standard Pack"
      projectedPackTrustClass pack @?= "built in"
      length (projectedPackComponents pack) @?= 12
      assertBool "all bundled components are enabled" (all projectedPackComponentEnabled (projectedPackComponents pack))
    other -> assertFailure ("unexpected list result: " <> show other)

showBuiltIn :: Assertion
showBuiltIn = withHarness $ \environment -> do
  result <- run environment False (PacksShowCommand "org.littleant.standard")
  case result of
    PacksResult Genesis "show" [pack] Nothing False -> do
      projectedPackPublisher pack @?= "org.littleant.project"
      assertBool "archive digest is complete" (Text.length (projectedPackArchiveDigest pack) == 64)
      assertBool "signer fingerprint is complete" (Text.length (projectedPackSignerFingerprint pack) == 64)
      let sourceAdapters = filter ((== "SourceAdapter") . projectedPackComponentKind) (projectedPackComponents pack)
      fmap projectedPackComponentId sourceAdapters @?= ["apple_reminders_export", "document_file", "evernote_enex", "notesnook_export", "plain_text", "taskjuggler_actuals"]
    other -> assertFailure ("unexpected show result: " <> show other)

rejectUnknown :: Assertion
rejectUnknown = withHarness $ \environment -> do
  observed <- runAppCommand environment False silentProgress (PacksShowCommand "org.example.missing")
  case observed of
    Left problem -> do
      appErrorCode problem @?= NotFound
      fmap recoveryActionCommand (appErrorRecovery problem) @?= [Just "lant packs list"]
    Right result -> assertFailure ("expected not-found, got: " <> show result)

dryRunList :: Assertion
dryRunList = withHarness $ \environment -> do
  result <- run environment True PacksListCommand
  case result of
    PacksResult Genesis "list" [_] Nothing True -> pure ()
    other -> assertFailure ("unexpected dry-run result: " <> show other)
  case toJSON result of
    Object fields -> do
      assertBool "dry_run is present when true" (KeyMap.member "dry_run" fields)
      assertBool "the sparse projection has no mutation command id" (not (KeyMap.member "command_id" fields))
      assertBool "encoded output never includes Pack bytes" (not ("payload" `isInfixOf` LazyByteString.unpack (encode result)))
    other -> assertFailure ("expected object JSON, got: " <> show other)

inspectBrokenRegistry :: Assertion
inspectBrokenRegistry = withSystemTempDirectory "little-ant-pack-admin-broken" $ \root ->
  withEnvironment (xdgAssignments root) $ do
    _ <- productionAppEnv Nothing >>= either (assertFailure . show) pure
    roots <- Profile.resolveXdgRoots
    loaded <- Profile.loadProfile roots "default" >>= either (assertFailure . show) pure
    let (paths, _, _, _, integrations) = loaded
        identity = PackArtifactIdentity "org.example" "org.example.missing" "1.0.0" (Text.replicate 64 "a") (Text.replicate 64 "b")
        pin = PackPin identity (Text.replicate 64 "c") PinTrustedPublisher (Set.singleton "example")
        changed = integrations{Profile.installedComponents = Map.singleton "org.example.missing" pin}
    Profile.writeIntegrationsConfig paths changed >>= either (assertFailure . show) pure
    restarted <- productionAppEnv Nothing >>= either (assertFailure . show) pure
    assertBool "startup retains the Pack registry failure" (isJust (appPackRegistryProblem restarted))
    listed <- run restarted False PacksListCommand
    case listed of
      PacksResult Genesis "list" packs (Just _) False ->
        case filter ((== "org.example.missing") . projectedPackName) packs of
          [missing] -> do
            projectedPackStatus missing @?= "unavailable"
            assertBool "the exact inspection problem is retained" (isJust (projectedPackProblem missing))
          other -> assertFailure ("expected one unavailable Pack, got: " <> show other)
      other -> assertFailure ("unexpected degraded list result: " <> show other)
    ordinary <- run restarted False NextCommand
    case ordinary of
      NextResult{} -> pure ()
      other -> assertFailure ("ordinary canonical work became unavailable: " <> show other)

communityTrustThenInstall :: Assertion
communityTrustThenInstall = withHarness $ \environment -> do
  preview <- run environment False (PacksInstallCommand (Text.pack connectorArchive))
  installEnvelope <- expectNextInteraction preview
  case envelopeOpportunity installEnvelope of
    PackInstallOpportunity draft -> do
      packInstallTrustClass draft @?= "untrusted"
      fmap actionId (envelopeActions installEnvelope) @?= ["pack.install.trust", "pack.install.back", "pack.install.unknown", "palette.open"]
      assertBool "the untrusted preview has no default" (not (any actionDefault (envelopeActions installEnvelope)))
    other -> assertFailure ("expected untrusted install preview, got: " <> show other)
  guidedAction "t" installEnvelope @?= "pack.install.trust"
  let previewBody = contentBody (envelopeContent installEnvelope)
  assertBool "the preview names the signed HTTP host" (any (Text.isInfixOf "graph.microsoft.com") previewBody)
  assertBool "the preview names credential authority" (any (Text.isInfixOf "oauth2_device_authorization") previewBody)
  assertBool "the preview names external effects" (any (Text.isInfixOf "source_cleanup_item") previewBody)
  assertBool "the preview explicitly reports local UI authority" ("Local UI authority: none" `elem` previewBody)

  trustPreview <- respond environment False installEnvelope "pack.install.trust"
  trustEnvelope <- expectRespondInteraction trustPreview
  case envelopeOpportunity trustEnvelope of
    PackTrustOpportunity draft -> do
      packTrustSource draft @?= PackArchiveSigner
      communityKeyFingerprint (packTrustPublisher draft) @?= connectorSignerFingerprint
      assertBool "the full fingerprint is rendered" (connectorSignerFingerprint `elem` contentBody (envelopeContent trustEnvelope))
      assertBool "trust has no default" (not (any actionDefault (envelopeActions trustEnvelope)))
    other -> assertFailure ("expected trust preview, got: " <> show other)
  guidedAction "t" trustEnvelope @?= "pack.trust.accept"

  installAgain <- respond environment False trustEnvelope "pack.trust.accept"
  trustedInstallEnvelope <- expectRespondInteraction installAgain
  case envelopeOpportunity trustedInstallEnvelope of
    PackInstallOpportunity draft -> packInstallTrustClass draft @?= "trusted publisher"
    other -> assertFailure ("expected still-unapproved install preview, got: " <> show other)
  guidedAction "i" trustedInstallEnvelope @?= "pack.install.accept"
  profileAfterTrust <- loadCurrentIntegrations
  assertBool "publisher trust is stored" (any ((== connectorSignerFingerprint) . communityKeyFingerprint) (Profile.trustedPublishers profileAfterTrust))
  assertBool "trust alone does not pin the Pack" (Map.notMember connectorPackName (Profile.installedComponents profileAfterTrust))
  paths <- currentProfilePaths
  let storedPath = packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) connectorArchiveDigest
  storedBeforeInstall <- doesFileExist storedPath
  assertBool "trust alone does not store the archive" (not storedBeforeInstall)

  installed <- respond environment False trustedInstallEnvelope "pack.install.accept"
  resultEnvelope <- expectRespondInteraction installed
  case envelopeOpportunity resultEnvelope of
    PackInstallResultOpportunity artifact -> artifactName artifact @?= connectorPackName
    other -> assertFailure ("expected install result, got: " <> show other)
  profileAfterInstall <- loadCurrentIntegrations
  case Map.lookup connectorPackName (Profile.installedComponents profileAfterInstall) of
    Nothing -> assertFailure "the Pack pin was not written"
    Just pin -> do
      pinTrustOrigin pin @?= PinTrustedPublisher
      pinEnabledComponents pin @?= Set.fromList ["google_calendar", "google_tasks", "microsoft_todo"]
  storedAfterInstall <- doesFileExist storedPath
  assertBool "the exact archive is present in the content-addressed store" storedAfterInstall

installDryRunLeavesNothing :: Assertion
installDryRunLeavesNothing = withHarness $ \environment -> do
  before <- loadCurrentIntegrations
  result <- run environment True (PacksInstallCommand (Text.pack connectorArchive))
  envelope <- expectNextInteraction result
  case envelopeOpportunity envelope of
    PackInstallOpportunity draft -> packInstallTrustClass draft @?= "untrusted"
    other -> assertFailure ("expected install preview, got: " <> show other)
  observedAfter <- loadCurrentIntegrations
  observedAfter @?= before
  paths <- currentProfilePaths
  pending <- doesFileExist (Profile.datasetDirectory paths </> "checkpoints" </> "pending-envelope.json")
  assertBool "dry-run did not persist a consent checkpoint" (not pending)
  stored <- doesFileExist (packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) connectorArchiveDigest)
  assertBool "dry-run did not store the archive" (not stored)

standalonePublisherTrust :: Assertion
standalonePublisherTrust = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-publisher-key" $ \temporary -> do
    let keyPath = temporary </> "publisher-key.json"
    writeConnectorKey keyPath
    before <- loadCurrentIntegrations
    simulated <- run environment True (PacksTrustCommand (Text.pack keyPath))
    simulatedEnvelope <- expectNextInteraction simulated
    case envelopeOpportunity simulatedEnvelope of
      PackTrustOpportunity{} -> pure ()
      other -> assertFailure ("expected dry-run trust preview, got: " <> show other)
    afterSimulation <- loadCurrentIntegrations
    afterSimulation @?= before
    paths <- currentProfilePaths
    dryPending <- doesFileExist (Profile.datasetDirectory paths </> "checkpoints" </> "pending-envelope.json")
    assertBool "trust dry-run did not arm a checkpoint" (not dryPending)
    preview <- run environment False (PacksTrustCommand (Text.pack keyPath))
    envelope <- expectNextInteraction preview
    case envelopeOpportunity envelope of
      PackTrustOpportunity draft -> do
        packTrustSource draft @?= StandalonePublisherKey
        assertBool "standalone trust has no default" (not (any actionDefault (envelopeActions envelope)))
      other -> assertFailure ("expected standalone trust preview, got: " <> show other)
    accepted <- respond environment False envelope "pack.trust.accept"
    acceptedEnvelope <- expectRespondInteraction accepted
    case envelopeOpportunity acceptedEnvelope of
      PackTrustResultOpportunity publisher -> communityKeyFingerprint publisher @?= connectorSignerFingerprint
      other -> assertFailure ("expected publisher-trust result, got: " <> show other)
    integrations <- loadCurrentIntegrations
    Set.size (Profile.trustedPublishers integrations) @?= 1
    assertBool "standalone trust installed no Pack" (Map.null (Profile.installedComponents integrations))

trustProfileDrift :: Assertion
trustProfileDrift = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-profile-drift" $ \temporary -> do
    let keyPath = temporary </> "publisher-key.json"
    writeConnectorKey keyPath
    preview <- run environment False (PacksTrustCommand (Text.pack keyPath))
    envelope <- expectNextInteraction preview
    beforeDraft <- case envelopeOpportunity envelope of
      PackTrustOpportunity draft -> pure draft
      other -> assertFailure ("expected trust preview, got: " <> show other) >> fail "unreachable"
    paths <- currentProfilePaths
    integrations <- loadCurrentIntegrations
    let externallyChanged = integrations{Profile.deliveryBindings = Map.singleton "notice" "stdout"}
    Profile.writeIntegrationsConfig paths externallyChanged >>= either (assertFailure . show) pure
    response <- respond environment False envelope "pack.trust.accept"
    refreshed <- expectRespondInteraction response
    case envelopeOpportunity refreshed of
      PackTrustOpportunity draft -> do
        assertBool "the profile revision changed" (packTrustProfileRevision draft /= packTrustProfileRevision beforeDraft)
        assertBool "the decision remains unapproved" (not (any actionDefault (envelopeActions refreshed)))
      other -> assertFailure ("expected refreshed trust preview, got: " <> show other)
    observedAfter <- loadCurrentIntegrations
    Profile.deliveryBindings observedAfter @?= Profile.deliveryBindings externallyChanged
    assertBool "the stale acceptance did not trust the publisher" (Set.null (Profile.trustedPublishers observedAfter))

archiveDriftInvalidates :: Assertion
archiveDriftInvalidates = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-pack-drift" $ \temporary -> do
    original <- ByteString.readFile connectorArchive
    let copied = temporary </> "candidate.lantpack"
    ByteString.writeFile copied original
    preview <- run environment False (PacksInstallCommand (Text.pack copied))
    envelope <- expectNextInteraction preview
    ByteString.writeFile copied "changed after preview"
    observed <- runAppCommand environment False silentProgress (RespondCommand (responseFor envelope "pack.install.trust"))
    case observed of
      Left problem -> appErrorCode problem @?= Conflict
      Right result -> assertFailure ("expected drift rejection, got: " <> show result)
    paths <- currentProfilePaths
    pending <- doesFileExist (Profile.datasetDirectory paths </> "checkpoints" </> "pending-envelope.json")
    assertBool "foreign-byte drift discarded the pending consent" (not pending)
    observedAfter <- loadCurrentIntegrations
    assertBool "drift stored no publisher trust" (Set.null (Profile.trustedPublishers observedAfter))
    assertBool "drift installed no Pack" (Map.null (Profile.installedComponents observedAfter))

profileCompareAndSwap :: Assertion
profileCompareAndSwap = withHarness $ \_ -> do
  paths <- currentProfilePaths
  revision <- Profile.integrationsConfigRevision paths >>= either (assertFailure . show) pure
  original <- loadCurrentIntegrations
  let newer = original{Profile.deliveryBindings = Map.singleton "notice" "stdout"}
      staleProposal = original{Profile.trustedPublishers = Set.singleton connectorPublisher}
  Profile.writeIntegrationsConfig paths newer >>= either (assertFailure . show) pure
  written <- Profile.writeIntegrationsConfigIfRevision paths revision staleProposal >>= either (assertFailure . show) pure
  assertBool "stale compare-and-swap was rejected" (not written)
  observed <- loadCurrentIntegrations
  observed @?= newer

strictPublisherKeyDocument :: Assertion
strictPublisherKeyDocument = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-noncanonical-key" $ \temporary -> do
    let keyPath = temporary </> "publisher-key.json"
    ByteString.writeFile keyPath . TextEncoding.encodeUtf8 $
      "{\n  \"schema\": \"little-ant/pack-publisher-key@1\",\n  \"publisher\": \"org.littleant.project\",\n  \"public_key\": \""
        <> connectorPublicKey
        <> "\",\n  \"key_fingerprint\": \""
        <> connectorSignerFingerprint
        <> "\"\n}\n"
    observed <- runAppCommand environment False silentProgress (PacksTrustCommand (Text.pack keyPath))
    case observed of
      Left problem -> appErrorCode problem @?= CorruptData
      Right result -> assertFailure ("expected canonical-key rejection, got: " <> show result)

replPackManager :: Assertion
replPackManager = withHarness $ \environment -> do
  owner <- run environment False NextCommand >>= expectNextInteraction
  listed <- run environment False PacksListCommand
  case listed of
    PacksResult _ "list" packs problem False -> do
      fmap commandOptionId (filteredCommands owner "/packs") @?= ["packs"]
      let manager = renderPlain (packManagerModel owner packs problem 0 Nothing)
          installEditor = renderPlain (packPathEditorModel owner InstallPackArchive (EditorState "" "" Nothing) Nothing)
          trustEditor = renderPlain (packPathEditorModel owner TrustPublisherKey (EditorState "" "" Nothing) Nothing)
      assertBool "the selected Pack is visible" ("> Little Ant Standard Pack 1.0.0" `Text.isInfixOf` manager)
      assertBool "the manager exposes Pack navigation" ("[s]how" `Text.isInfixOf` manager && "[i]nstall..." `Text.isInfixOf` manager)
      assertBool "the manager exposes explicit catalog refresh" ("[r]efresh catalog" `Text.isInfixOf` manager)
      assertBool "the manager keeps publisher trust separate" ("[t]rust publisher..." `Text.isInfixOf` manager)
      assertBool "the ordinary palette remains reachable" ("[/] more..." `Text.isInfixOf` manager)
      assertBool "install accepts an official name or local archive" ("official Pack name" `Text.isInfixOf` installEditor && "local signed .lantpack" `Text.isInfixOf` installEditor)
      assertBool "install explains the separate preview" ("Nothing changes before the" `Text.isInfixOf` installEditor && "preview is accepted." `Text.isInfixOf` installEditor)
      assertBool "trust explains profile-local custody" ("Trust is profile-local" `Text.isInfixOf` trustEditor && "installs nothing." `Text.isInfixOf` trustEditor)
      mapM_ (assertWidth 80) [packManagerModel owner packs problem 0 Nothing, packPathEditorModel owner InstallPackArchive (EditorState "" "" Nothing) Nothing, packPathEditorModel owner TrustPublisherKey (EditorState "" "" Nothing) Nothing]
    other -> assertFailure ("expected Pack list, got: " <> show other)

replScopedImportSelector :: Assertion
replScopedImportSelector = withHarness $ \environment -> do
  envelope <- run environment False NextCommand >>= expectNextInteraction
  let descriptor = ImportSourceDescriptor "google_calendar@personal" "Google Calendar · Personal" [] [SourceSnapshot, SourceSynchronize] True
      selection = ImportSelection descriptor "google_calendar@personal"
      containers =
        [ SourceContainer "calendar:personal@example.com" "Personal"
        , SourceContainer "calendar:a-very-long-team-calendar-identity@group.calendar.google.com" "Rock Splitter team"
        ]
      model = importContainerModelAtWidth 46 envelope selection SourceSynchronize containers 1 (Set.singleton "calendar:personal@example.com") Nothing
      rendered = renderPlain model
  assertBool "the scoped selector omitted its plain-language question" ("Keep synchronizing from which containers?" `Text.isInfixOf` rendered)
  assertBool "the checked container was not visible" ("[x] Personal" `Text.isInfixOf` rendered)
  assertBool "the cursor did not identify the active row" ("> [ ] Rock Splitter team" `Text.isInfixOf` rendered)
  assertBool "the toggle instruction was omitted" ("[space] toggle" `Text.isInfixOf` rendered)
  assertBool "the explicit continuation was omitted" ("[i]mport selected" `Text.isInfixOf` rendered)
  assertBool "the selector introduced a default" (not ("*" `Text.isInfixOf` rendered))
  assertWidth 46 model

officialCatalogRefresh :: Assertion
officialCatalogRefresh = withHarness $ \base -> do
  remote <- publishedRemote
  let environment = base{appOfficialPackRemote = Just remote}
  refreshed <- run environment False PacksRefreshCommand
  case refreshed of
    ConfigurationResult Genesis "packs_refresh" Nothing [] facts False -> do
      Map.lookup "catalog_sequence" facts @?= Just "1"
      Map.lookup "status" facts @?= Just "updated"
    other -> assertFailure ("unexpected catalog refresh result: " <> show other)
  paths <- currentProfilePaths
  stateExists <- doesFileExist (Profile.officialCatalogStateFile paths)
  assertBool "the accepted signed history was persisted" stateExists
  current <- run environment False PacksRefreshCommand
  case current of
    ConfigurationResult _ "packs_refresh" _ _ facts False -> Map.lookup "status" facts @?= Just "already current"
    other -> assertFailure ("unexpected current-catalog result: " <> show other)

  valid <- ByteString.readFile officialCatalogDocument
  signature <- ByteString.readFile officialCatalogSignature
  let tampered = remote{fetchOfficialCatalog = pure (Right (OfficialCatalogPayload (valid <> " ") signature))}
  rejected <- runAppCommand (environment{appOfficialPackRemote = Just tampered}) False silentProgress PacksRefreshCommand
  case rejected of
    Left problem -> appErrorCode problem @?= CorruptData
    Right value -> assertFailure ("tampered catalog was accepted: " <> show value)
  retained <- run environment False PacksRefreshCommand
  case retained of
    ConfigurationResult _ "packs_refresh" _ _ facts False -> Map.lookup "status" facts @?= Just "already current"
    other -> assertFailure ("accepted catalog was not retained after rejection: " <> show other)

officialCatalogInstall :: Assertion
officialCatalogInstall = withHarness $ \base -> do
  remote <- publishedRemote
  let environment = base{appOfficialPackRemote = Just remote}
  _ <- run environment False PacksRefreshCommand
  preview <- run environment False (PacksInstallCommand connectorPackName)
  envelope <- expectNextInteraction preview
  case envelopeOpportunity envelope of
    PackInstallOpportunity draft -> do
      packInstallTrustClass draft @?= "verified official"
      packInstallArtifact draft @?= connectorIdentity
      fmap actionId (envelopeActions envelope) @?= ["pack.install.accept", "pack.install.back", "pack.install.unknown", "palette.open"]
      assertBool "official installation still has no default" (not (any actionDefault (envelopeActions envelope)))
      status <- getFileStatus (packInstallSourcePath draft)
      fileMode status .&. 0o077 @?= 0
    other -> assertFailure ("expected official installation preview, got: " <> show other)
  accepted <- respond environment False envelope "pack.install.accept"
  resultEnvelope <- expectRespondInteraction accepted
  case envelopeOpportunity resultEnvelope of
    PackInstallResultOpportunity artifact -> artifact @?= connectorIdentity
    other -> assertFailure ("expected official install result, got: " <> show other)
  integrations <- loadCurrentIntegrations
  case Map.lookup connectorPackName (Profile.installedComponents integrations) of
    Just pin -> pinTrustOrigin pin @?= PinVerifiedOfficial 1
    Nothing -> assertFailure "the official release was not pinned"
  assertBool "official install did not add community trust" (Set.null (Profile.trustedPublishers integrations))
  restarted <- productionAppEnv Nothing >>= either (assertFailure . show) pure
  assertBool "the accepted official pin loads through the compiled root" (isNothing (appPackRegistryProblem restarted))
  listed <- run restarted False PacksListCommand
  case listed of
    PacksResult _ "list" packs Nothing False ->
      case filter ((== connectorPackName) . projectedPackName) packs of
        [pack] -> do
          projectedPackTrustClass pack @?= "verified official"
          projectedPackStatus pack @?= "enabled"
        other -> assertFailure ("expected one enabled official Pack, got: " <> show other)
    other -> assertFailure ("unexpected restarted Pack list: " <> show other)

officialCatalogRefreshDryRun :: Assertion
officialCatalogRefreshDryRun = withHarness $ \base -> do
  remote <- publishedRemote
  let environment = base{appOfficialPackRemote = Just remote}
  result <- run environment True PacksRefreshCommand
  case result of
    ConfigurationResult _ "packs_refresh" _ _ facts True -> Map.lookup "status" facts @?= Just "would update"
    other -> assertFailure ("unexpected dry refresh result: " <> show other)
  paths <- currentProfilePaths
  stateExists <- doesFileExist (Profile.officialCatalogStateFile paths)
  assertBool "dry-run wrote no accepted catalog history" (not stateExists)
  unavailable <- runAppCommand environment False silentProgress (PacksInstallCommand connectorPackName)
  case unavailable of
    Left problem -> do
      appErrorCode problem @?= NotFound
      fmap recoveryActionCommand (appErrorRecovery problem) @?= [Just "lant packs refresh"]
    Right value -> assertFailure ("official install unexpectedly bypassed catalog acceptance: " <> show value)

providerConnectionEnablesImport :: Assertion
providerConnectionEnablesImport = withHarness $ \base -> do
  remote <- publishedRemote
  let catalogEnvironment = base{appOfficialPackRemote = Just remote}
  _ <- run catalogEnvironment False PacksRefreshCommand
  installPreview <- run catalogEnvironment False (PacksInstallCommand connectorPackName) >>= expectNextInteraction
  _ <- respond catalogEnvironment False installPreview "pack.install.accept"

  connectedBase <- productionAppEnv Nothing >>= either (assertFailure . show) pure
  owner <- run connectedBase False NextCommand >>= expectNextInteraction
  let connectableChoices = importSourceChoices connectedBase
      connectableScreen = renderPlain (importSourceModel owner connectableChoices "micro" 0 Nothing)
  fmap providerDefinitionAdapterId [definition | ConnectImportSource definition <- connectableChoices]
    @?= ["google_calendar", "google_tasks", "microsoft_todo"]
  assertBool "the searchable source selector omitted the unconfigured connector" ("Microsoft To Do · connect..." `Text.isInfixOf` connectableScreen)
  assertBool "the ordinary palette omitted /import" (not (null (filteredCommands owner "/import")))
  paths <- currentProfilePaths
  passphrase <- either (assertFailure . show) pure (makePassphrase "provider connection fixture")
  vaultIdentity <- appAllocateUUID connectedBase
  Vault.writeVault (Profile.vaultFile paths) passphrase (Vault.emptyVault vaultIdentity) >>= either (assertFailure . show) pure
  stopped <- newEmptyMVar
  _ <- forkIO (runVaultAgent (Profile.vaultSocket paths) (Profile.vaultFile paths) 60 >>= putMVar stopped)
  waitForPath (Profile.vaultSocket paths) 100

  responses <- newIORef [deviceAuthorizationResponse, deviceTokenResponse]
  prompts <- newIORef []
  let transport = OAuthFormTransport $ \_ ->
        atomicModifyIORef' responses $ \case
          [] -> ([], Left (appError ExternalFailure "OAuth fixture exhausted"))
          response : remaining -> (remaining, Right response)
      runtime =
        case appProviderConnectionRuntime connectedBase of
          Nothing -> error "production provider connection runtime is unavailable"
          Just value ->
            value
              { providerConnectionOAuthTransport = transport
              , providerConnectionPresentPrompt = \prompt -> modifyIORef' prompts (<> [prompt])
              , providerConnectionWaitSeconds = const (pure ())
              }
      environment = connectedBase{appProviderConnectionRuntime = Just runtime}

  preview <-
    run environment False (ConfigConnectCommand "microsoft_todo" "personal" "Personal account" "11111111-1111-1111-1111-111111111111")
      >>= expectNextInteraction
  case envelopeOpportunity preview of
    ProviderConnectionOpportunity draft -> do
      providerConnectionSource draft @?= "microsoft_todo"
      providerConnectionScopes draft @?= Set.fromList ["Tasks.ReadWrite", "offline_access"]
      fmap actionId (envelopeActions preview) @?= ["provider.connect.accept", "provider.connect.back", "provider.connect.unknown", "palette.open"]
      assertBool "connection has no default" (not (any actionDefault (envelopeActions preview)))
      let serialized = LazyByteString.unpack (encode preview)
      assertBool "preview leaked no OAuth device code or token" (not ("PRIVATE-DEVICE-CODE" `isInfixOf` serialized || "ACCESS-TOKEN" `isInfixOf` serialized))
    other -> assertFailure ("expected provider connection preview, got: " <> show other)
  before <- loadCurrentIntegrations
  assertBool "preview changed provider configuration" (Map.null (Profile.providerAccounts before))

  locked <- runAppCommand environment False silentProgress (RespondCommand (responseFor preview "provider.connect.accept"))
  case locked of
    Left problem -> appErrorCode problem @?= PermissionRequired
    Right result -> assertFailure ("locked vault unexpectedly began authorization: " <> show result)
  pendingResponses <- readIORef responses
  length pendingResponses @?= 2
  readIORef prompts >>= (@?= [])

  sendVaultAgentRequest (Profile.vaultSocket paths) (agentUnlockRequest "provider connection fixture") >>= either (assertFailure . show) assertAgentSuccess
  accepted <- respond environment False preview "provider.connect.accept" >>= expectRespondInteraction
  case envelopeOpportunity accepted of
    ProviderConnectionResultOpportunity "microsoft_todo" "personal" "Personal account" -> pure ()
    other -> assertFailure ("expected provider connection result, got: " <> show other)
  observedPrompts <- readIORef prompts
  fmap devicePromptUserCode observedPrompts @?= ["ABCD-EFGH"]
  configured <- loadCurrentIntegrations
  Map.keys (Profile.providerAccounts configured) @?= ["personal"]
  Map.keys (Profile.credentialBindings configured) @?= ["microsoft_todo-personal"]

  restarted <- productionAppEnv Nothing >>= either (assertFailure . show) pure
  assertBool "connected provider made the production adapter registry unavailable" (isNothing (appPackRegistryProblem restarted))
  let restartedChoices = importSourceChoices restarted
      providerDescriptors = [descriptor | ReadyImportSource descriptor <- restartedChoices, importSourceId descriptor == "microsoft_todo"]
  assertBool "the connected provider remained incorrectly connectable" (null [() | ConnectImportSource definition <- restartedChoices, providerDefinitionAdapterId definition == "microsoft_todo"])
  case providerDescriptors of
    [descriptor] -> do
      connectedProviderImportSelection restarted "microsoft_todo" "personal" @?= Just (ImportSelection descriptor "microsoft_todo")
      importSourceDisplayName descriptor @?= "Microsoft To Do · Personal account"
      let modeScreen = renderPlain (importModeModel accepted (ImportSelection descriptor "microsoft_todo") Nothing)
      assertBool "snapshot was omitted from the dumb mode selector" ("[s]napshot once" `Text.isInfixOf` modeScreen)
      assertBool "synchronization was omitted from the dumb mode selector" ("[k]eep synchronizing" `Text.isInfixOf` modeScreen)
      assertBool "migration was omitted from the dumb mode selector" ("[m]igrate" `Text.isInfixOf` modeScreen)
      assertBool "the dumb mode selector introduced an Enter default" (not ("Enter" `Text.isInfixOf` modeScreen))
    other -> assertFailure ("expected one exact connected import target, got: " <> show other)

  sendVaultAgentRequest (Profile.vaultSocket paths) agentShutdownRequest >>= either (assertFailure . show) assertAgentSuccess
  takeMVar stopped >>= either (assertFailure . show) pure

deviceAuthorizationResponse :: OAuthFormResponse
deviceAuthorizationResponse =
  OAuthFormResponse
    200
    ( object
        [ "device_code" .= ("PRIVATE-DEVICE-CODE" :: Text)
        , "user_code" .= ("ABCD-EFGH" :: Text)
        , "verification_uri" .= ("https://microsoft.com/devicelogin" :: Text)
        , "expires_in" .= (900 :: Int)
        , "interval" .= (5 :: Int)
        ]
    )

deviceTokenResponse :: OAuthFormResponse
deviceTokenResponse =
  OAuthFormResponse
    200
    ( object
        [ "token_type" .= ("Bearer" :: Text)
        , "access_token" .= ("ACCESS-TOKEN" :: Text)
        , "refresh_token" .= ("REFRESH-TOKEN" :: Text)
        , "expires_in" .= (3600 :: Int)
        , "scope" .= ("Tasks.ReadWrite" :: Text)
        ]
    )

assertAgentSuccess :: AgentReply -> Assertion
assertAgentSuccess reply = assertBool "vault agent did not acknowledge the request" (agentReplySucceeded reply)

waitForPath :: FilePath -> Int -> Assertion
waitForPath path attempts
  | attempts <= 0 = assertFailure ("timed out waiting for " <> path)
  | otherwise = do
      exists <- doesPathExist path
      if exists then pure () else threadDelay 10_000 >> waitForPath path (attempts - 1)

publishedRemote :: IO OfficialPackRemote
publishedRemote = do
  catalog <- ByteString.readFile officialCatalogDocument
  signature <- ByteString.readFile officialCatalogSignature
  archive <- ByteString.readFile connectorArchive
  pure
    OfficialPackRemote
      { fetchOfficialCatalog = pure (Right (OfficialCatalogPayload catalog signature))
      , fetchOfficialPackArchive = \digest ->
          pure $
            if digest == connectorArchiveDigest
              then Right archive
              else Left (appError NotFound "fixture archive missing")
      }

guidedAction :: Text -> InteractionEnvelope -> Text
guidedAction shortcut envelope = case dispatchGuidedShortcut envelope envelope shortcut of
  Right GuidedAccepted{guidedActionId} -> guidedActionId
  other -> error ("expected guided action for " <> Text.unpack shortcut <> ", got: " <> show other)

assertWidth :: Int -> ScreenModel -> Assertion
assertWidth width model =
  assertBool
    ("screen exceeds " <> show width <> " columns: " <> show oversized)
    (null oversized)
 where
  oversized = filter ((> width) . Text.length) (plainLine <$> screenLines model)

expectNextInteraction :: CommandResult -> IO InteractionEnvelope
expectNextInteraction = \case
  NextResult _ envelope _ -> pure envelope
  other -> assertFailure ("expected NextResult, got: " <> show other) >> fail "unreachable"

expectRespondInteraction :: CommandResult -> IO InteractionEnvelope
expectRespondInteraction = \case
  RespondResult _ envelope Nothing _ -> pure envelope
  other -> assertFailure ("expected noncanonical RespondResult, got: " <> show other) >> fail "unreachable"

respond :: AppEnv -> Bool -> InteractionEnvelope -> Text -> IO CommandResult
respond environment dryRun envelope action = run environment dryRun (RespondCommand (responseFor envelope action))

responseFor :: InteractionEnvelope -> Text -> InteractionResponse
responseFor envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

writeConnectorKey :: FilePath -> IO ()
writeConnectorKey path = do
  encoded <- either (assertFailure . show) pure (encodePackPublisherKeyDocument (PackPublisherKeyDocument connectorPublisher))
  ByteString.writeFile path encoded

loadCurrentIntegrations :: IO Profile.IntegrationsConfig
loadCurrentIntegrations = do
  roots <- Profile.resolveXdgRoots
  Profile.loadProfile roots "default" >>= \case
    Left problem -> assertFailure (show problem) >> fail "unreachable"
    Right (_, _, _, _, integrations) -> pure integrations

currentProfilePaths :: IO Profile.ProfilePaths
currentProfilePaths = do
  roots <- Profile.resolveXdgRoots
  either (\problem -> assertFailure (show problem) >> fail "unreachable") pure (Profile.profilePaths roots "default")

connectorPublisher :: TrustedCommunityPublisher
connectorPublisher = TrustedCommunityPublisher "org.littleant.project" connectorPublicKey connectorSignerFingerprint

connectorPackName, connectorArchiveDigest, connectorPublicKey, connectorSignerFingerprint :: Text
connectorPackName = "org.littleant.official-connectors"
connectorArchiveDigest = "9349deb470969bddbe2dff4137c5efa2a87308128b366ccd362b04665eead5ad"
connectorPublicKey = "RMZDabxcwifaT2P7G7dnHfyE-vB7-IEgT7AdylbG85s"
connectorSignerFingerprint = "23dc6985cba495bc638011c42bd25188a37fb7cef4fdec492a5f2db73a05b444"

connectorArchive :: FilePath
connectorArchive = "packs" </> "official-connectors" </> "official-connectors.lantpack"

officialCatalogDocument, officialCatalogSignature :: FilePath
officialCatalogDocument = "packs" </> "official" </> "catalog.json"
officialCatalogSignature = "packs" </> "official" </> "catalog-signature.json"

connectorIdentity :: PackArtifactIdentity
connectorIdentity =
  PackArtifactIdentity
    "org.littleant.project"
    connectorPackName
    "1.0.0"
    "7aaf954377d5c67e10807bf72d962b7e81399457687a159eea2ab38cfc5a2ccc"
    connectorArchiveDigest

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-pack-admin" $ \root ->
  withEnvironment
    (xdgAssignments root)
    ( productionAppEnv Nothing >>= \case
        Left problem -> assertFailure (show problem) >> fail "unreachable"
        Right environment -> action environment
    )

xdgAssignments :: FilePath -> [(String, String)]
xdgAssignments root =
  [ ("XDG_CONFIG_HOME", root </> "config")
  , ("XDG_DATA_HOME", root </> "data")
  , ("XDG_STATE_HOME", root </> "state")
  , ("XDG_RUNTIME_DIR", root </> "runtime")
  ]

withEnvironment :: [(String, String)] -> IO a -> IO a
withEnvironment assignments action = bracket save restore (const (setAll >> action))
 where
  save = traverse (\(name, _) -> (name,) <$> lookupEnv name) assignments
  restore = mapM_ restoreOne
  restoreOne (name, Just value) = setEnv name value
  restoreOne (name, Nothing) = unsetEnv name
  setAll = mapM_ (uncurry setEnv) assignments

run :: AppEnv -> Bool -> AppCommand -> IO CommandResult
run environment dryRun command =
  runAppCommand environment dryRun silentProgress command >>= either (assertFailure . show) pure

silentProgress :: Integer -> IO ()
silentProgress _ = pure ()

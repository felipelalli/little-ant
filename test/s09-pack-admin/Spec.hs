module Main (main) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar, threadDelay)
import Control.Exception (bracket)
import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Aeson (Value (Object), encode, object, toJSON, (.=))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bits ((.&.))
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.IORef
import Data.List (find, isInfixOf)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust, isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Id (UUIDv7, parseUUIDv7)
import LittleAnt.Import
import LittleAnt.Interaction
import LittleAnt.Model (SourceMode (..), emptyState)
import LittleAnt.OAuth.Device
import LittleAnt.Pack.Admin
import LittleAnt.Pack.Format
import LittleAnt.Pack.Lifecycle
import LittleAnt.Pack.Official
import LittleAnt.Pack.Store
import LittleAnt.Pack.Trust
import LittleAnt.Pack.Update
import LittleAnt.Profile qualified as Profile
import LittleAnt.Protocol
import LittleAnt.Provider
import LittleAnt.Provider.Connection
import LittleAnt.REPL
import LittleAnt.Result
import LittleAnt.SemVer
import LittleAnt.Source (SourceContainer (..))
import LittleAnt.Store (DatasetCursor (Genesis), sha256Hex)
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
      , testCase "static provider connection captures one token only after reviewed consent" staticProviderConnectionEnablesImport
      , testCase "Pack update discovery chooses the newest signed SemVer release" discoverNewestOfficialUpdate
      , testCase "Pack update ordering follows SemVer prerelease precedence" semVerUpdatePrecedence
      , testCase "Pack update inspection is read-only and performs no network request" packUpdatesStayReadOnly
      , testCase "a reviewed local update keeps or replaces the preferred pin without deleting either release" reviewedLocalPackUpdate
      , testCase "the update plan rebinds compatible static accounts but retains artifact-bound OAuth accounts" selectiveProviderRebinding
      , testCase "a changed configuration schema retains the exact installed provider release" changedSchemaRetainsProvider
      , testCase "an unpinned delivery binding blocks an ambiguous Pack update" unpinnedDeliveryBlocksUpdate
      , testCase "Pack update dry-run arms no checkpoint and changes no preferred pin" packUpdateDryRun
      , testCase "profile drift regenerates the complete Pack update plan without accepting it" packUpdateProfileDrift
      , testCase "candidate-byte drift invalidates the Pack update checkpoint" packUpdateArchiveDrift
      , testCase "Pack removal deactivates only the preferred pin and leaves collection separate" removeThenCollectPack
      , testCase "an exact provider account survives preferred Pack removal and retains its archive" retainedProviderSurvivesRemoval
      , testCase "component-only delivery authority blocks Pack removal" deliveryBindingBlocksRemoval
      , testCase "profile drift refreshes Pack removal without carrying consent" packRemovalProfileDrift
      , testCase "Pack garbage-collection dry-run changes no profile, checkpoint, or archive" packGcDryRun
      , testCase "garbage collection retains archives referenced by another profile" gcScansEveryProfile
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
      pinEnabledComponents pin @?= Set.fromList ["github_issues", "google_calendar", "google_tasks", "microsoft_todo"]
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
      assertBool "the manager exposes explicit selected-Pack update" ("[u]pdate" `Text.isInfixOf` manager)
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
      Map.lookup "catalog_sequence" facts @?= Just "2"
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
    Just pin -> pinTrustOrigin pin @?= PinVerifiedOfficial 2
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
    @?= ["github_issues", "google_calendar", "google_tasks", "microsoft_todo"]
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
    run environment False (ConfigConnectCommand "microsoft_todo" "personal" "Personal account" (Just "11111111-1111-1111-1111-111111111111"))
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
  case Map.lookup "personal" (Profile.providerAccounts configured) of
    Just account -> pinArtifact (Profile.providerAccountPackPin account) @?= connectorIdentity
    Nothing -> assertFailure "the connected provider account was not retained"

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

staticProviderConnectionEnablesImport :: Assertion
staticProviderConnectionEnablesImport = withHarness $ \base -> do
  remote <- publishedRemote
  let catalogEnvironment = base{appOfficialPackRemote = Just remote}
  _ <- run catalogEnvironment False PacksRefreshCommand
  installPreview <- run catalogEnvironment False (PacksInstallCommand connectorPackName) >>= expectNextInteraction
  _ <- respond catalogEnvironment False installPreview "pack.install.accept"

  connectedBase <- productionAppEnv Nothing >>= either (assertFailure . show) pure
  paths <- currentProfilePaths
  passphrase <- either (assertFailure . show) pure (makePassphrase "static provider fixture")
  vaultIdentity <- appAllocateUUID connectedBase
  Vault.writeVault (Profile.vaultFile paths) passphrase (Vault.emptyVault vaultIdentity) >>= either (assertFailure . show) pure
  stopped <- newEmptyMVar
  _ <- forkIO (runVaultAgent (Profile.vaultSocket paths) (Profile.vaultFile paths) 60 >>= putMVar stopped)
  waitForPath (Profile.vaultSocket paths) 100

  credentialPrompts <- newIORef []
  let runtime =
        case appProviderConnectionRuntime connectedBase of
          Nothing -> error "production provider connection runtime is unavailable"
          Just value ->
            value
              { providerConnectionAcquireCredential = \label -> do
                  modifyIORef' credentialPrompts (<> [label])
                  pure (Right "PRIVATE-GITHUB-TOKEN")
              }
      environment = connectedBase{appProviderConnectionRuntime = Just runtime}
  preview <-
    run environment False (ConfigConnectCommand "github_issues" "github" "Personal GitHub" Nothing)
      >>= expectNextInteraction
  case envelopeOpportunity preview of
    ProviderConnectionOpportunity draft -> do
      providerConnectionSource draft @?= "github_issues"
      providerConnectionClientId draft @?= Nothing
      providerConnectionScopes draft @?= Set.empty
      Profile.credentialBindingScheme (providerConnectionBinding draft) @?= Vault.BearerCredential
      Profile.credentialBindingSlot (providerConnectionBinding draft) @?= "github"
      let serialized = LazyByteString.unpack (encode preview)
      assertBool "static preview leaked the supplied token" (not ("PRIVATE-GITHUB-TOKEN" `isInfixOf` serialized))
      assertBool "sparse static preview retained a null client ID" (not ("client_id" `isInfixOf` serialized))
    other -> assertFailure ("expected static provider connection preview, got: " <> show other)

  locked <- runAppCommand environment False silentProgress (RespondCommand (responseFor preview "provider.connect.accept"))
  case locked of
    Left problem -> appErrorCode problem @?= PermissionRequired
    Right result -> assertFailure ("locked vault unexpectedly requested a static credential: " <> show result)
  readIORef credentialPrompts >>= (@?= [])

  sendVaultAgentRequest (Profile.vaultSocket paths) (agentUnlockRequest "static provider fixture") >>= either (assertFailure . show) assertAgentSuccess
  accepted <- respond environment False preview "provider.connect.accept" >>= expectRespondInteraction
  case envelopeOpportunity accepted of
    ProviderConnectionResultOpportunity "github_issues" "github" "Personal GitHub" -> pure ()
    other -> assertFailure ("expected static provider connection result, got: " <> show other)
  readIORef credentialPrompts >>= (@?= ["GitHub Issues · Personal GitHub"])

  configured <- loadCurrentIntegrations
  Map.keys (Profile.providerAccounts configured) @?= ["github"]
  Map.keys (Profile.credentialBindings configured) @?= ["github_issues-github"]
  case Map.lookup "github" (Profile.providerAccounts configured) of
    Just account -> pinArtifact (Profile.providerAccountPackPin account) @?= connectorIdentity
    Nothing -> assertFailure "the connected provider account was not retained"
  inventoryReply <- sendVaultAgentRequest (Profile.vaultSocket paths) agentInventoryRequest >>= either (assertFailure . show) pure
  case agentReplyInventory inventoryReply of
    Just [entry] -> do
      Vault.inventoryScheme entry @?= Vault.BearerCredential
      Vault.inventoryRedactedSuffix entry @?= Just "OKEN"
    other -> assertFailure ("expected one redacted bearer credential, got: " <> show other)

  restarted <- productionAppEnv Nothing >>= either (assertFailure . show) pure
  let restartedChoices = importSourceChoices restarted
      githubDescriptors = [descriptor | ReadyImportSource descriptor <- restartedChoices, importSourceId descriptor == "github_issues"]
  assertBool "the connected GitHub provider remained connectable" (null [() | ConnectImportSource definition <- restartedChoices, providerDefinitionAdapterId definition == "github_issues"])
  case githubDescriptors of
    [descriptor] -> do
      importSourceDisplayName descriptor @?= "GitHub Issues · Personal GitHub"
      importSourceModes descriptor @?= [SourceSnapshot, SourceSynchronize]
    other -> assertFailure ("expected one exact GitHub import target, got: " <> show other)

  sendVaultAgentRequest (Profile.vaultSocket paths) agentShutdownRequest >>= either (assertFailure . show) assertAgentSuccess
  takeMVar stopped >>= either (assertFailure . show) pure

discoverNewestOfficialUpdate :: Assertion
discoverNewestOfficialUpdate = do
  let installedIdentity = connectorIdentity{artifactVersion = "1.9.0", artifactManifestDigest = Text.replicate 64 "1", artifactArchiveDigest = Text.replicate 64 "2"}
      installedPin = PackPin installedIdentity connectorSignerFingerprint (PinVerifiedOfficial 4) (Set.singleton "github_issues")
      candidates =
        [ updateGrant "1.9.1" "3"
        , updateGrant "1.10.0-alpha.1" "4"
        , updateGrant "1.10.0" "5"
        , (updateGrant "9.0.0" "6"){officialGrantName = "org.littleant.unrelated"}
        ]
      policy =
        PackTrustPolicy
          { trustSupportedLittleAntMajor = 1
          , trustBuiltInArtifacts = Set.empty
          , trustOfficialCatalogSequence = Just 8
          , trustOfficialCatalogExpiresAt = Just (read "2028-08-09 00:00:00 UTC")
          , trustOfficialReleaseGrants = Set.fromList candidates
          , trustOfficialPinAuthorizations = Set.empty
          , trustCommunityPublishers = Set.empty
          , trustRevokedKeyFingerprints = Set.empty
          , trustRevokedArchiveDigests = Set.empty
          }
  case discoverOfficialPackUpdates (Map.singleton connectorPackName installedPin) policy of
    [candidate] -> do
      updateInstalledArtifact candidate @?= installedIdentity
      artifactVersion (updateCandidateArtifact candidate) @?= "1.10.0"
      updateCandidateSignerFingerprint candidate @?= connectorSignerFingerprint
      updateCatalogSequence candidate @?= 8
    other -> assertFailure ("expected one newest update, got: " <> show other)

semVerUpdatePrecedence :: Assertion
semVerUpdatePrecedence = do
  let ordered =
        [ "1.0.0-alpha"
        , "1.0.0-alpha.1"
        , "1.0.0-alpha.beta"
        , "1.0.0-beta"
        , "1.0.0-beta.2"
        , "1.0.0-beta.11"
        , "1.0.0-rc.1"
        , "1.0.0"
        ]
  mapM_
    (\(left, right) -> compareSemVer left right @?= Just LT)
    (zip ordered (drop 1 ordered))
  compareSemVer "1.10.0" "1.9.9" @?= Just GT
  compareSemVer "1.0.0+build.1" "1.0.0+build.2" @?= Just EQ
  assertBool "a prerelease numeric identifier accepted a leading zero" (not (validSemVer "1.0.0-alpha.01"))
  assertBool "an incomplete release was accepted" (not (validSemVer "1.0"))

packUpdatesStayReadOnly :: Assertion
packUpdatesStayReadOnly = withHarness $ \base -> do
  requested <- newIORef False
  let forbiddenRemote =
        OfficialPackRemote
          { fetchOfficialCatalog = writeIORef requested True >> pure (Left (appError ExternalFailure "unexpected catalog request"))
          , fetchOfficialPackArchive = \_ -> writeIORef requested True >> pure (Left (appError ExternalFailure "unexpected archive request"))
          }
      environment = base{appOfficialPackRemote = Just forbiddenRemote}
  before <- loadCurrentIntegrations
  observed <- run environment False PacksUpdatesCommand
  case observed of
    PackUpdatesResult Genesis [] False -> pure ()
    other -> assertFailure ("unexpected Pack updates result: " <> show other)
  readIORef requested >>= (@?= False)
  loadCurrentIntegrations >>= (@?= before)
  case toJSON observed of
    Object fields -> do
      KeyMap.lookup "schema" fields @?= Just "little-ant/pack-updates@1"
      assertBool "read-only update discovery exposed a command id" (not (KeyMap.member "command_id" fields))
    other -> assertFailure ("expected object JSON, got: " <> show other)

reviewedLocalPackUpdate :: Assertion
reviewedLocalPackUpdate = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-local-update" $ \directory -> do
    (oldBytes, oldIdentity) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    (newBytes, newIdentity) <- updateFixtureArchive "1.1.0" "return { version = 2 }\n"
    let oldPath = directory </> "old.lantpack"
        newPath = directory </> "new.lantpack"
    ByteString.writeFile oldPath oldBytes
    ByteString.writeFile newPath newBytes

    installPreview <- run environment False (PacksInstallCommand (Text.pack oldPath)) >>= expectNextInteraction
    trustPreview <- respond environment False installPreview (guidedAction "t" installPreview) >>= expectRespondInteraction
    returnedInstall <- respond environment False trustPreview (guidedAction "t" trustPreview) >>= expectRespondInteraction
    _ <- respond environment False returnedInstall (guidedAction "i" returnedInstall)

    keepPreview <- run environment False (PacksUpdateCommand (Text.pack newPath)) >>= expectNextInteraction
    case envelopeOpportunity keepPreview of
      PackUpdateOpportunity draft -> do
        packUpdateInstalledPin draft @?= PackPin oldIdentity updateFixtureFingerprint PinTrustedPublisher (Set.singleton "demo_export")
        packUpdateCandidateArtifact draft @?= newIdentity
        assertBool "the signed payload change was not visible" (not (null (packUpdateChanges draft)))
        assertBool "an update without live bindings should be applicable" (packUpdateCanApply draft)
        packUpdateBindings draft @?= []
      other -> assertFailure ("expected Pack update preview, got: " <> show other)
    kept <- respond environment False keepPreview (guidedAction "k" keepPreview) >>= expectRespondInteraction
    case envelopeOpportunity kept of
      PackUpdateResultOpportunity installed candidate False 0 -> do
        installed @?= oldIdentity
        candidate @?= newIdentity
      other -> assertFailure ("expected keep-current result, got: " <> show other)
    profileAfterKeep <- loadCurrentIntegrations
    fmap pinArtifact (Map.lookup updateFixtureName (Profile.installedComponents profileAfterKeep)) @?= Just oldIdentity

    updatePreview <- run environment False (PacksUpdateCommand (Text.pack newPath)) >>= expectNextInteraction
    inspected <- respond environment False updatePreview (guidedAction "i" updatePreview) >>= expectRespondInteraction
    updated <- respond environment False inspected (guidedAction "u" inspected) >>= expectRespondInteraction
    case envelopeOpportunity updated of
      PackUpdateResultOpportunity installed candidate True 0 -> do
        installed @?= oldIdentity
        candidate @?= newIdentity
      other -> assertFailure ("expected applied update result, got: " <> show other)
    profileAfterUpdate <- loadCurrentIntegrations
    fmap pinArtifact (Map.lookup updateFixtureName (Profile.installedComponents profileAfterUpdate)) @?= Just newIdentity
    paths <- currentProfilePaths
    doesFileExist (packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) (artifactArchiveDigest oldIdentity)) >>= (@?= True)
    doesFileExist (packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) (artifactArchiveDigest newIdentity)) >>= (@?= True)

selectiveProviderRebinding :: Assertion
selectiveProviderRebinding = do
  oldCandidate <- readPackArchiveCandidate connectorArchive >>= either (assertFailure . show) pure
  let oldPack = packCandidateAuthenticated oldCandidate
      oldIdentity = authenticatedPackIdentity oldPack
      candidateIdentity =
        oldIdentity
          { artifactVersion = "1.1.0"
          , artifactManifestDigest = Text.replicate 64 "a"
          , artifactArchiveDigest = Text.replicate 64 "b"
          }
      candidatePack = oldPack{authenticatedPackIdentity = candidateIdentity}
      enabled = Set.fromList [componentId (componentCommon component) | component <- packComponents (structurallyValidManifest (authenticatedStructuralPack oldPack))]
      oldPin = PackPin oldIdentity (authenticatedSignerFingerprint oldPack) PinTrustedPublisher enabled
      githubAccount =
        Profile.ProviderAccount
          oldPin
          "github_issues"
          "github"
          "github-personal"
          "Personal GitHub"
          (object [])
      microsoftAccount =
        Profile.ProviderAccount
          oldPin
          "microsoft_todo"
          "microsoft_todo"
          "microsoft-personal"
          "Personal Microsoft"
          (object ["client_id" .= ("public-client" :: Text)])
      githubBinding =
        Profile.CredentialBinding
          "github_issues"
          "github"
          "github"
          Vault.BearerCredential
          fixtureCredentialId
          Nothing
          (Set.singleton "source_read")
      microsoftBinding =
        Profile.CredentialBinding
          "microsoft_todo"
          "microsoft"
          "microsoft"
          Vault.OAuthDeviceAuthorization
          fixtureCredentialId
          (Just (Text.replicate 64 "c"))
          (Set.singleton "source_read")
      integrations =
        Profile.IntegrationsConfig
          (Map.singleton connectorPackName oldPin)
          (Map.fromList [("github", githubAccount), ("microsoft", microsoftAccount)])
          (Map.fromList [("github-binding", githubBinding), ("microsoft-binding", microsoftBinding)])
          Map.empty
          Set.empty
  draft <-
    assertRight
      ( buildPackUpdateDraft
          "/tmp/candidate.lantpack"
          (Text.replicate 64 "b")
          "trusted publisher"
          "profile-revision"
          integrations
          emptyState
          oldPin
          oldPack
          candidatePack
      )
  fmap (\plan -> (updateBindingName plan, updateBindingDisposition plan)) (packUpdateBindings draft)
    @?= [("github", RebindToCandidate), ("microsoft", KeepInstalledRelease)]
  let candidatePin = oldPin{pinArtifact = candidateIdentity}
      changed = updateReboundAccounts candidatePin draft integrations
  fmap (pinArtifact . Profile.providerAccountPackPin) (Map.lookup "github" (Profile.providerAccounts changed)) @?= Just candidateIdentity
  fmap (pinArtifact . Profile.providerAccountPackPin) (Map.lookup "microsoft" (Profile.providerAccounts changed)) @?= Just oldIdentity

changedSchemaRetainsProvider :: Assertion
changedSchemaRetainsProvider = do
  (oldPack, candidatePack, oldPin, integrations) <- providerUpdateFixture
  let structural = authenticatedStructuralPack candidatePack
      changedCandidate =
        candidatePack
          { authenticatedStructuralPack =
              structural
                { structurallyValidPayload =
                    Map.adjust
                      (const "{\"additionalProperties\":false,\"properties\":{\"new\":{\"type\":\"string\"}},\"type\":\"object\"}")
                      "sources/github_issues/config.schema.json"
                      (structurallyValidPayload structural)
                }
          }
  draft <- buildUpdateDraft oldPin integrations oldPack changedCandidate
  dispositionFor "github" draft @?= Just KeepInstalledRelease

unpinnedDeliveryBlocksUpdate :: Assertion
unpinnedDeliveryBlocksUpdate = do
  (oldPack, candidatePack, oldPin, integrations) <- providerUpdateFixture
  let withDelivery = integrations{Profile.deliveryBindings = Map.singleton "daily-summary" "github_issues"}
  draft <- buildUpdateDraft oldPin withDelivery oldPack candidatePack
  dispositionFor "daily-summary" draft @?= Just BindingUnavailable
  assertBool "the ambiguous delivery binding allowed the update" (not (packUpdateCanApply draft))

providerUpdateFixture :: IO (AuthenticatedPack, AuthenticatedPack, PackPin, Profile.IntegrationsConfig)
providerUpdateFixture = do
  oldCandidate <- readPackArchiveCandidate connectorArchive >>= either (assertFailure . show) pure
  let oldPack = packCandidateAuthenticated oldCandidate
      oldIdentity = authenticatedPackIdentity oldPack
      candidateIdentity =
        oldIdentity
          { artifactVersion = "1.1.0"
          , artifactManifestDigest = Text.replicate 64 "a"
          , artifactArchiveDigest = Text.replicate 64 "b"
          }
      candidatePack = oldPack{authenticatedPackIdentity = candidateIdentity}
      enabled = Set.fromList [componentId (componentCommon component) | component <- packComponents (structurallyValidManifest (authenticatedStructuralPack oldPack))]
      oldPin = PackPin oldIdentity (authenticatedSignerFingerprint oldPack) PinTrustedPublisher enabled
      githubAccount =
        Profile.ProviderAccount oldPin "github_issues" "github" "github-personal" "Personal GitHub" (object [])
      githubBinding =
        Profile.CredentialBinding "github_issues" "github" "github" Vault.BearerCredential fixtureCredentialId Nothing (Set.singleton "source_read")
      integrations =
        Profile.IntegrationsConfig
          (Map.singleton connectorPackName oldPin)
          (Map.singleton "github" githubAccount)
          (Map.singleton "github-binding" githubBinding)
          Map.empty
          Set.empty
  pure (oldPack, candidatePack, oldPin, integrations)

buildUpdateDraft :: PackPin -> Profile.IntegrationsConfig -> AuthenticatedPack -> AuthenticatedPack -> IO PackUpdateDraft
buildUpdateDraft oldPin integrations oldPack candidatePack =
  assertRight
    ( buildPackUpdateDraft
        "/tmp/candidate.lantpack"
        (Text.replicate 64 "b")
        "trusted publisher"
        "profile-revision"
        integrations
        emptyState
        oldPin
        oldPack
        candidatePack
    )

dispositionFor :: Text -> PackUpdateDraft -> Maybe PackUpdateDisposition
dispositionFor name draft =
  updateBindingDisposition <$> find ((== name) . updateBindingName) (packUpdateBindings draft)

packUpdateDryRun :: Assertion
packUpdateDryRun = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-update-dry-run" $ \directory -> do
    (oldBytes, oldIdentity) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    (newBytes, newIdentity) <- updateFixtureArchive "1.1.0" "return { version = 2 }\n"
    let oldPath = directory </> "old.lantpack"
        newPath = directory </> "new.lantpack"
    ByteString.writeFile oldPath oldBytes
    ByteString.writeFile newPath newBytes
    installCommunityPack environment oldPath
    before <- loadCurrentIntegrations
    paths <- currentProfilePaths
    let checkpoint = Profile.datasetDirectory paths </> "checkpoints" </> "pending-envelope.json"
    checkpointBefore <- ByteString.readFile checkpoint
    preview <- run environment True (PacksUpdateCommand (Text.pack newPath)) >>= expectNextInteraction
    case envelopeOpportunity preview of
      PackUpdateOpportunity draft -> do
        pinArtifact (packUpdateInstalledPin draft) @?= oldIdentity
        packUpdateCandidateArtifact draft @?= newIdentity
      other -> assertFailure ("expected dry-run Pack update preview, got: " <> show other)
    loadCurrentIntegrations >>= (@?= before)
    ByteString.readFile checkpoint >>= (@?= checkpointBefore)
    storedCandidate <- doesFileExist (packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) (artifactArchiveDigest newIdentity))
    assertBool "dry-run published the candidate archive" (not storedCandidate)

packUpdateProfileDrift :: Assertion
packUpdateProfileDrift = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-update-profile-drift" $ \directory -> do
    (oldBytes, oldIdentity) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    (newBytes, _) <- updateFixtureArchive "1.1.0" "return { version = 2 }\n"
    let oldPath = directory </> "old.lantpack"
        newPath = directory </> "new.lantpack"
    ByteString.writeFile oldPath oldBytes
    ByteString.writeFile newPath newBytes
    installCommunityPack environment oldPath
    preview <- run environment False (PacksUpdateCommand (Text.pack newPath)) >>= expectNextInteraction
    oldRevision <- case envelopeOpportunity preview of
      PackUpdateOpportunity draft -> pure (packUpdateProfileRevision draft)
      other -> assertFailure ("expected Pack update preview, got: " <> show other) >> fail "unreachable"
    paths <- currentProfilePaths
    integrations <- loadCurrentIntegrations
    let externalChange = integrations{Profile.deliveryBindings = Map.singleton "unrelated" "some_other_component"}
    Profile.writeIntegrationsConfig paths externalChange >>= either (assertFailure . show) pure
    refreshed <- respond environment False preview (guidedAction "u" preview) >>= expectRespondInteraction
    case envelopeOpportunity refreshed of
      PackUpdateOpportunity draft -> do
        assertBool "profile drift retained the old draft revision" (packUpdateProfileRevision draft /= oldRevision)
        assertBool "the refreshed plan acquired a default" (not (any actionDefault (envelopeActions refreshed)))
      other -> assertFailure ("expected refreshed Pack update preview, got: " <> show other)
    observedAfter <- loadCurrentIntegrations
    fmap pinArtifact (Map.lookup updateFixtureName (Profile.installedComponents observedAfter)) @?= Just oldIdentity
    Profile.deliveryBindings observedAfter @?= Profile.deliveryBindings externalChange

packUpdateArchiveDrift :: Assertion
packUpdateArchiveDrift = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-update-archive-drift" $ \directory -> do
    (oldBytes, oldIdentity) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    (newBytes, _) <- updateFixtureArchive "1.1.0" "return { version = 2 }\n"
    let oldPath = directory </> "old.lantpack"
        newPath = directory </> "new.lantpack"
    ByteString.writeFile oldPath oldBytes
    ByteString.writeFile newPath newBytes
    installCommunityPack environment oldPath
    preview <- run environment False (PacksUpdateCommand (Text.pack newPath)) >>= expectNextInteraction
    ByteString.writeFile newPath "changed after preview"
    observed <- runAppCommand environment False silentProgress (RespondCommand (responseFor preview "pack.update.accept"))
    case observed of
      Left problem -> appErrorCode problem @?= Conflict
      Right result -> assertFailure ("expected update drift rejection, got: " <> show result)
    paths <- currentProfilePaths
    pending <- doesFileExist (Profile.datasetDirectory paths </> "checkpoints" </> "pending-envelope.json")
    assertBool "candidate drift retained the Pack update consent" (not pending)
    observedAfter <- loadCurrentIntegrations
    fmap pinArtifact (Map.lookup updateFixtureName (Profile.installedComponents observedAfter)) @?= Just oldIdentity

removeThenCollectPack :: Assertion
removeThenCollectPack = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-remove-collect" $ \directory -> do
    (archive, artifact) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    let path = directory </> "pack.lantpack"
    ByteString.writeFile path archive
    installCommunityPack environment path
    paths <- currentProfilePaths
    let stored = packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) (artifactArchiveDigest artifact)
    doesFileExist stored >>= (@?= True)

    keepPreview <- run environment False (PacksRemoveCommand updateFixtureName) >>= expectNextInteraction
    case envelopeOpportunity keepPreview of
      PackRemovalOpportunity draft -> do
        packRemovalCanApply draft @?= True
        packRemovalReferences draft @?= []
      other -> assertFailure ("expected Pack removal preview, got: " <> show other)
    kept <- respond environment False keepPreview (guidedAction "k" keepPreview) >>= expectRespondInteraction
    case envelopeOpportunity kept of
      PackRemovalResultOpportunity observed False 0 -> observed @?= artifact
      other -> assertFailure ("expected keep-current removal result, got: " <> show other)
    current <- loadCurrentIntegrations
    fmap pinArtifact (Map.lookup updateFixtureName (Profile.installedComponents current)) @?= Just artifact

    removePreview <- run environment False (PacksRemoveCommand updateFixtureName) >>= expectNextInteraction
    removed <- respond environment False removePreview (guidedAction "r" removePreview) >>= expectRespondInteraction
    case envelopeOpportunity removed of
      PackRemovalResultOpportunity observed True 0 -> observed @?= artifact
      other -> assertFailure ("expected Pack removal result, got: " <> show other)
    afterRemoval <- loadCurrentIntegrations
    Map.lookup updateFixtureName (Profile.installedComponents afterRemoval) @?= Nothing
    doesFileExist stored >>= (@?= True)

    keepGcPreview <- run environment False PacksGcCommand >>= expectNextInteraction
    case envelopeOpportunity keepGcPreview of
      PackGcOpportunity draft -> do
        fmap packGcCandidateArtifact (packGcCandidates draft) @?= [artifact]
        packGcTotalBytes draft @?= fromIntegral (ByteString.length archive)
      other -> assertFailure ("expected Pack GC preview, got: " <> show other)
    keptGc <- respond environment False keepGcPreview (guidedAction "k" keepGcPreview) >>= expectRespondInteraction
    case envelopeOpportunity keptGc of
      PackGcResultOpportunity False 1 bytes -> bytes @?= fromIntegral (ByteString.length archive)
      other -> assertFailure ("expected keep-archives result, got: " <> show other)
    doesFileExist stored >>= (@?= True)

    collectPreview <- run environment False PacksGcCommand >>= expectNextInteraction
    collected <- respond environment False collectPreview (guidedAction "c" collectPreview) >>= expectRespondInteraction
    case envelopeOpportunity collected of
      PackGcResultOpportunity True 1 bytes -> bytes @?= fromIntegral (ByteString.length archive)
      other -> assertFailure ("expected collected-archives result, got: " <> show other)
    doesFileExist stored >>= (@?= False)
    loadCurrentIntegrations >>= (@?= afterRemoval)

retainedProviderSurvivesRemoval :: Assertion
retainedProviderSurvivesRemoval = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-remove-retained" $ \directory -> do
    (archive, artifact) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    let path = directory </> "pack.lantpack"
    ByteString.writeFile path archive
    installCommunityPack environment path
    integrations <- loadCurrentIntegrations
    pin <- maybe (assertFailure "fixture Pack pin missing" >> fail "unreachable") pure (Map.lookup updateFixtureName (Profile.installedComponents integrations))
    let account = Profile.ProviderAccount pin "demo_export" "demo" "demo-account" "Demo account" (object [])
        withAccount = integrations{Profile.providerAccounts = Map.singleton "demo" account}
    paths <- currentProfilePaths
    Profile.writeIntegrationsConfig paths withAccount >>= either (assertFailure . show) pure

    preview <- run environment False (PacksRemoveCommand updateFixtureName) >>= expectNextInteraction
    case envelopeOpportunity preview of
      PackRemovalOpportunity draft -> do
        packRemovalCanApply draft @?= True
        fmap removalReferenceDisposition (packRemovalReferences draft) @?= [RemovalRetained]
      other -> assertFailure ("expected retained-reference removal preview, got: " <> show other)
    result <- respond environment False preview (guidedAction "r" preview) >>= expectRespondInteraction
    case envelopeOpportunity result of
      PackRemovalResultOpportunity observed True 1 -> observed @?= artifact
      other -> assertFailure ("expected retained-reference removal result, got: " <> show other)
    afterRemovalConfig <- loadCurrentIntegrations
    Map.lookup updateFixtureName (Profile.installedComponents afterRemovalConfig) @?= Nothing
    fmap (pinArtifact . Profile.providerAccountPackPin) (Map.lookup "demo" (Profile.providerAccounts afterRemovalConfig)) @?= Just artifact
    noGarbage <- run environment False PacksGcCommand >>= expectNextInteraction
    case envelopeOpportunity noGarbage of
      PackGcResultOpportunity False 0 0 -> pure ()
      other -> assertFailure ("expected no garbage while an exact account retains the archive, got: " <> show other)
    doesFileExist (packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) (artifactArchiveDigest artifact)) >>= (@?= True)

deliveryBindingBlocksRemoval :: Assertion
deliveryBindingBlocksRemoval = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-remove-delivery" $ \directory -> do
    (archive, artifact) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    let path = directory </> "pack.lantpack"
    ByteString.writeFile path archive
    installCommunityPack environment path
    integrations <- loadCurrentIntegrations
    paths <- currentProfilePaths
    let withDelivery = integrations{Profile.deliveryBindings = Map.singleton "daily" "demo_export"}
    Profile.writeIntegrationsConfig paths withDelivery >>= either (assertFailure . show) pure
    preview <- run environment False (PacksRemoveCommand updateFixtureName) >>= expectNextInteraction
    case envelopeOpportunity preview of
      PackRemovalOpportunity draft -> do
        assertBool "an unpinned delivery binding allowed removal" (not (packRemovalCanApply draft))
        fmap removalReferenceDisposition (packRemovalReferences draft) @?= [RemovalMustResolve]
        assertBool "blocked removal still exposed acceptance" (all ((/= "pack.remove.accept") . actionId) (envelopeActions preview))
      other -> assertFailure ("expected blocked Pack removal preview, got: " <> show other)
    inspected <- respond environment False preview (guidedAction "i" preview) >>= expectRespondInteraction
    kept <- respond environment False inspected (guidedAction "k" inspected) >>= expectRespondInteraction
    case envelopeOpportunity kept of
      PackRemovalResultOpportunity observed False 0 -> observed @?= artifact
      other -> assertFailure ("expected blocked keep-current result, got: " <> show other)
    loadCurrentIntegrations >>= (@?= withDelivery)

packRemovalProfileDrift :: Assertion
packRemovalProfileDrift = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-remove-profile-drift" $ \directory -> do
    (archive, artifact) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    let path = directory </> "pack.lantpack"
    ByteString.writeFile path archive
    installCommunityPack environment path
    preview <- run environment False (PacksRemoveCommand updateFixtureName) >>= expectNextInteraction
    oldRevision <- case envelopeOpportunity preview of
      PackRemovalOpportunity draft -> pure (packRemovalProfileRevision draft)
      other -> assertFailure ("expected Pack removal preview, got: " <> show other) >> fail "unreachable"
    paths <- currentProfilePaths
    integrations <- loadCurrentIntegrations
    let externalChange = integrations{Profile.deliveryBindings = Map.singleton "unrelated" "some_other_component"}
    Profile.writeIntegrationsConfig paths externalChange >>= either (assertFailure . show) pure
    refreshed <- respond environment False preview (guidedAction "r" preview) >>= expectRespondInteraction
    case envelopeOpportunity refreshed of
      PackRemovalOpportunity draft -> do
        assertBool "profile drift retained the old removal revision" (packRemovalProfileRevision draft /= oldRevision)
        assertBool "the refreshed removal acquired a default" (not (any actionDefault (envelopeActions refreshed)))
      other -> assertFailure ("expected refreshed Pack removal preview, got: " <> show other)
    observed <- loadCurrentIntegrations
    fmap pinArtifact (Map.lookup updateFixtureName (Profile.installedComponents observed)) @?= Just artifact
    Profile.deliveryBindings observed @?= Profile.deliveryBindings externalChange

packGcDryRun :: Assertion
packGcDryRun = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-gc-dry-run" $ \directory -> do
    (archive, artifact) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    let path = directory </> "pack.lantpack"
    ByteString.writeFile path archive
    installCommunityPack environment path
    removal <- run environment False (PacksRemoveCommand updateFixtureName) >>= expectNextInteraction
    _ <- respond environment False removal (guidedAction "r" removal) >>= expectRespondInteraction
    paths <- currentProfilePaths
    let stored = packArchivePath (PackStoreConfig (Profile.packStoreDirectory paths)) (artifactArchiveDigest artifact)
        checkpoint = Profile.datasetDirectory paths </> "checkpoints" </> "pending-envelope.json"
    integrationsBefore <- loadCurrentIntegrations
    checkpointBefore <- ByteString.readFile checkpoint
    preview <- run environment True PacksGcCommand >>= expectNextInteraction
    case envelopeOpportunity preview of
      PackGcOpportunity draft -> fmap packGcCandidateArtifact (packGcCandidates draft) @?= [artifact]
      other -> assertFailure ("expected dry-run Pack GC preview, got: " <> show other)
    loadCurrentIntegrations >>= (@?= integrationsBefore)
    ByteString.readFile checkpoint >>= (@?= checkpointBefore)
    doesFileExist stored >>= (@?= True)

gcScansEveryProfile :: Assertion
gcScansEveryProfile = withHarness $ \environment ->
  withSystemTempDirectory "little-ant-gc-profiles" $ \directory -> do
    (archive, artifact) <- updateFixtureArchive "1.0.0" "return { version = 1 }\n"
    let path = directory </> "pack.lantpack"
    ByteString.writeFile path archive
    installCommunityPack environment path
    defaultIntegrations <- loadCurrentIntegrations
    pin <- maybe (assertFailure "fixture Pack pin missing" >> fail "unreachable") pure (Map.lookup updateFixtureName (Profile.installedComponents defaultIntegrations))
    roots <- Profile.resolveXdgRoots
    workPaths <- Profile.createProfile roots "work" gcProfileId >>= either (assertFailure . show) pure
    let workIntegrations =
          Profile.IntegrationsConfig
            (Map.singleton updateFixtureName pin)
            Map.empty
            Map.empty
            Map.empty
            (Profile.trustedPublishers defaultIntegrations)
    Profile.writeIntegrationsConfig workPaths workIntegrations >>= either (assertFailure . show) pure

    removal <- run environment False (PacksRemoveCommand updateFixtureName) >>= expectNextInteraction
    _ <- respond environment False removal (guidedAction "r" removal) >>= expectRespondInteraction
    retained <- run environment False PacksGcCommand >>= expectNextInteraction
    case envelopeOpportunity retained of
      PackGcResultOpportunity False 0 0 -> pure ()
      other -> assertFailure ("expected the second profile to retain the archive, got: " <> show other)

    Profile.writeIntegrationsConfig workPaths workIntegrations{Profile.installedComponents = Map.empty} >>= either (assertFailure . show) pure
    preview <- run environment False PacksGcCommand >>= expectNextInteraction
    case envelopeOpportunity preview of
      PackGcOpportunity draft -> do
        Map.keys (packGcProfileRevisions draft) @?= ["default", "work"]
        fmap packGcCandidateArtifact (packGcCandidates draft) @?= [artifact]
      other -> assertFailure ("expected global Pack GC preview, got: " <> show other)
    collected <- respond environment False preview (guidedAction "c" preview) >>= expectRespondInteraction
    case envelopeOpportunity collected of
      PackGcResultOpportunity True 1 _ -> pure ()
      other -> assertFailure ("expected global Pack GC result, got: " <> show other)

updateGrant :: Text -> Text -> OfficialReleaseGrant
updateGrant version digestCharacter =
  OfficialReleaseGrant
    { officialGrantPublisher = "org.littleant.project"
    , officialGrantNamePrefix = "org.littleant."
    , officialGrantPublicKey = connectorPublicKey
    , officialGrantKeyFingerprint = connectorSignerFingerprint
    , officialGrantName = connectorPackName
    , officialGrantVersion = version
    , officialGrantManifestDigest = Text.replicate 64 digestCharacter
    , officialGrantArchiveDigest = Text.replicate 64 digestCharacter
    }

updateFixtureArchive :: Text -> ByteString -> IO (ByteString, PackArtifactIdentity)
updateFixtureArchive version lua = do
  let payload =
        Map.fromList
          [ ("exporters/demo/config.schema.json", "{\"additionalProperties\":false,\"type\":\"object\"}")
          , ("exporters/demo/main.lua", lua)
          ]
      manifest =
        PackManifest
          { packName = updateFixtureName
          , packVersion = version
          , packDisplayName = "Update Fixture"
          , packPublisher = "org.example"
          , packLittleAntMajor = 1
          , packComponents = [updateFixtureComponent]
          , packFiles = fmap updatePayloadRecord (Map.toAscList payload)
          , packLinks = Nothing
          }
  manifestBytes <- assertRight (encodePackManifest manifest)
  signatureBytes <- assertRight (encodePackSignature (updateSignatureDocument manifestBytes))
  archive <- assertRight (buildCanonicalPackArchive manifestBytes signatureBytes payload)
  authenticated <- assertRight (validatePackArchive archive >>= authenticatePack)
  pure (archive, authenticatedPackIdentity authenticated)

updateFixtureComponent :: PackComponent
updateFixtureComponent =
  ExecutableComponent
    ComponentCommon
      { componentId = "demo_export"
      , componentKind = ReadOnlyExporterComponent
      , componentContractMajor = 1
      , componentRoot = "exporters/demo"
      , componentConfigurationSchema = "config.schema.json"
      }
    "main.lua"
    (ComponentPermissions [] [] [] [] [] ["little-ant/structure@1"] [])

updatePayloadRecord :: (Text, ByteString) -> PayloadFile
updatePayloadRecord (path, bytes) =
  PayloadFile
    path
    (fromIntegral (ByteString.length bytes))
    (if ".lua" `Text.isSuffixOf` path then "text/x-lua; charset=utf-8" else "application/schema+json")
    (sha256Hex bytes)

updateSignatureDocument :: ByteString -> PackSignatureDocument
updateSignatureDocument manifestBytes =
  PackSignatureDocument
    { packSignaturePublicKey = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded updateFixturePublicKeyBytes)
    , packSignatureKeyFingerprint = updateFixtureFingerprint
    , packSignatureValue = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded (convert (Ed25519.sign updateFixtureSecretKey updateFixturePublicKey manifestBytes)))
    }

updateFixtureSecretKey :: Ed25519.SecretKey
updateFixtureSecretKey = cryptoPassed (Ed25519.secretKey (ByteString.pack [96 .. 127]))

updateFixturePublicKey :: Ed25519.PublicKey
updateFixturePublicKey = Ed25519.toPublic updateFixtureSecretKey

updateFixturePublicKeyBytes :: ByteString
updateFixturePublicKeyBytes = convert updateFixturePublicKey

updateFixtureName, updateFixtureFingerprint :: Text
updateFixtureName = "org.example.update-fixture"
updateFixtureFingerprint = sha256Hex updateFixturePublicKeyBytes

fixtureCredentialId :: UUIDv7
fixtureCredentialId = either (error . Text.unpack) id (parseUUIDv7 "019fe436-5e25-7ee2-9eaf-eff23cfb54fc")

gcProfileId :: UUIDv7
gcProfileId = either (error . Text.unpack) id (parseUUIDv7 "019fe436-5e25-7ee2-9eaf-eff23cfb54fd")

cryptoPassed :: CryptoFailable value -> value
cryptoPassed = \case
  CryptoPassed value -> value
  CryptoFailed problem -> error (show problem)

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

installCommunityPack :: AppEnv -> FilePath -> Assertion
installCommunityPack environment path = do
  installPreview <- run environment False (PacksInstallCommand (Text.pack path)) >>= expectNextInteraction
  trustPreview <- respond environment False installPreview (guidedAction "t" installPreview) >>= expectRespondInteraction
  returnedInstall <- respond environment False trustPreview (guidedAction "t" trustPreview) >>= expectRespondInteraction
  _ <- respond environment False returnedInstall (guidedAction "i" returnedInstall)
  pure ()

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
connectorArchiveDigest = "5099f106d1defd27962509b19f2b5d8028a00630f1ed85ccbcc1e07f5ebe8dc1"
connectorPublicKey = "AXSF4TtjKekOfN29Rggaf0CM-utgjpVDuYSmy1y3G6Y"
connectorSignerFingerprint = "68fefb5f485e46af963e23d4904924123bba9ff8463206679808a64da0bd5d68"

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
    "5d47de9338c3f9e6d2a049652748534cbf0eb9ee9f49ae64f91a92937ce38da6"
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

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

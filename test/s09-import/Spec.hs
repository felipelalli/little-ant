module Main (main) where

import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Id
import LittleAnt.Import
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Pack.Trust
import LittleAnt.Result
import LittleAnt.Source
import LittleAnt.Store
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 verified Raw-first import"
      [ testCase "preflight is complete, explicit, and read-only" readOnlyPreflight
      , testCase "acceptance atomically preserves one Raw and its source custody" acceptancePreservesRawTruth
      , testCase "acceptance atomically preserves every previewed source object" multiObjectAcceptance
      , testCase "materialization drift fails before any Raw is preserved" materializationDrift
      , testCase "repeating the same verified import reuses the canonical Raw" repeatedAcceptance
      , testCase "a new signed adapter invocation reuses the stable source mapping" changedAdapterInvocation
      , testCase "a later file snapshot reuses its profile without overwriting Raw truth" changedSnapshot
      , testCase "changed material under one provider identity requires reconciliation" stableIdentityConflict
      , testCase "changed source bytes regenerate preflight without mutation" stalePreflight
      , testCase "unsupported modes and cleanup requests fail before mutation" unsupportedAuthority
      , testCase "dry-run verifies the decision without persisting it" dryRunAcceptance
      ]

multiObjectAcceptance :: Assertion
multiObjectAcceptance = withHarness $ \environment _ -> do
  let source = "notesnook.zip"
      importedEnvironment = environment{appImportPort = multiObjectImportPort}
  preview <- run importedEnvironment False (ImportCommand source SourceMigrate False) >>= interactionOf
  result <- run importedEnvironment False (RespondCommand (response preview "import.accept"))
  envelope <- interactionOf result
  imported <- case envelopeOpportunity envelope of
    ImportResultOpportunity _ identities [] False -> pure identities
    opportunity -> assertFailure ("unexpected multi-object import result: " <> show opportunity) >> fail "unreachable"
  length imported @?= 2
  dataset <- load importedEnvironment
  loadedEventCount dataset @?= 6
  let state = loadedState dataset
  Map.size (stateRaws state) @?= 2
  Map.size (stateSourceBindings state) @?= 2
  Map.size (stateImportInvocations state) @?= 1
  Set.fromList (unHandle . rawHandle <$> Map.elems (stateRaws state)) @?= Set.fromList ["st", "st2"]
  let invocation = only "ImportInvocation" (Map.elems (stateImportInvocations state))
  Set.fromList (importObjectExternalIdentity <$> importInvocationMappings invocation) @?= Set.fromList ["path:Inbox/Same title.md", "path:Projects/Same title.md"]

  secondPreview <- run importedEnvironment False (ImportCommand source SourceMigrate False) >>= interactionOf
  second <- run importedEnvironment False (RespondCommand (response secondPreview "import.accept"))
  secondEnvelope <- interactionOf second
  case envelopeOpportunity secondEnvelope of
    ImportResultOpportunity _ [] reused False -> Set.fromList reused @?= Set.fromList imported
    opportunity -> assertFailure ("multi-object retry was not idempotent: " <> show opportunity)
  resultMutationCommandId second @?= Nothing
  finalDataset <- load importedEnvironment
  loadedEventCount finalDataset @?= 6

materializationDrift :: Assertion
materializationDrift = withHarness $ \environment _ -> do
  let source = "notesnook.zip"
      driftedPort =
        multiObjectImportPort
          { importPortMaterialize = \reference mode -> pure $ do
              readValue <- ImportRead reference multiInput <$> multiPreflight mode
              pure (ImportMaterialization readValue (Map.delete "path:Projects/Same title.md" multiMaterials))
          }
      driftedEnvironment = environment{appImportPort = driftedPort}
  preview <- run driftedEnvironment False (ImportCommand source SourceMigrate False) >>= interactionOf
  runAppCommand driftedEnvironment False silentProgress (RespondCommand (response preview "import.accept")) >>= assertError Conflict
  dataset <- load driftedEnvironment
  loadedEventCount dataset @?= 0
  loadedState dataset @?= emptyState

readOnlyPreflight :: Assertion
readOnlyPreflight = withHarness $ \environment _ -> do
  result <- run environment False (ImportCommand fixtureReference SourceSnapshot False)
  envelope <- interactionOf result
  case envelopeOpportunity envelope of
    ImportPreflightOpportunity source preflight False -> do
      source @?= fixtureReference
      sourcePreflightMode preflight @?= SourceSnapshot
      observedSourceLabel (sourcePreflightObservation preflight) @?= "Plain text fixture"
    opportunity -> assertFailure ("unexpected preflight opportunity: " <> show opportunity)
  map actionId (envelopeActions envelope) @?= ["import.accept", "import.back", "import.unknown", "palette.open"]
  assertBool "import preview unexpectedly has a default action" (not (any actionDefault (envelopeActions envelope)))
  contentHeading (envelopeContent envelope) @?= "Import preview:"
  assertBodyContains "Nothing will be deleted from the source." envelope
  dataset <- load environment
  loadedCursor dataset @?= Genesis
  loadedEventCount dataset @?= 0
  loadedState dataset @?= emptyState

acceptancePreservesRawTruth :: Assertion
acceptancePreservesRawTruth = withHarness $ \environment _ -> do
  preview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  result <- run environment False (RespondCommand (response preview "import.accept"))
  envelope <- interactionOf result
  importedRaw <- case envelopeOpportunity envelope of
    ImportResultOpportunity _ [identity] [] False -> pure identity
    opportunity -> assertFailure ("unexpected import result: " <> show opportunity) >> fail "unreachable"
  contentHeading (envelopeContent envelope) @?= "Import verified."
  assertBodyContains "1 new Raws preserved · 0 already preserved" envelope
  dataset <- load environment
  loadedEventCount dataset @?= 4
  let state = loadedState dataset
  Map.size (stateImportProfiles state) @?= 1
  Map.size (stateImportInvocations state) @?= 1
  Map.size (stateRaws state) @?= 1
  Map.size (stateSourceBindings state) @?= 1
  Map.size (stateBricks state) @?= 0
  Map.size (stateDomains state) @?= 0
  Set.size (stateImportanceEdges state) @?= 0
  let profile = only "ImportProfile" (Map.elems (stateImportProfiles state))
      invocation = only "ImportInvocation" (Map.elems (stateImportInvocations state))
      raw = stateRaws state Map.! importedRaw
      binding = only "SourceBinding" (Map.elems (stateSourceBindings state))
      revision = stateRawContentRevisions state Map.! (stateCurrentRawRevisions state Map.! importedRaw)
  importProfileInputReference profile @?= fixtureReference
  importProfileMode profile @?= SourceSnapshot
  importInvocationProfileId invocation @?= importProfileId profile
  importInvocationInputDigest invocation @?= sha256Hex fixtureBytes
  importInvocationInputByteCount invocation @?= ByteString.length fixtureBytes
  importInvocationContractMajor invocation @?= 1
  importInvocationPermissions invocation @?= fixturePermissions
  importInvocationMappings invocation @?= [ImportObjectMapping (fixtureExternalId fixtureBytes) importedRaw ImportCreatedRaw]
  rawOriginal raw @?= fixtureTitle
  rawContentRevisionContent revision @?= RawTextContent fixtureText
  sourceBindingRaw binding @?= importedRaw
  sourceBindingImportProfile binding @?= Just (importProfileId profile)
  sourceBindingExternalIdentity binding @?= Just (fixtureExternalId fixtureBytes)
  sourceBindingContainerIdentity binding @?= Just fixtureContainerId
  sourceBindingLocator binding @?= fixtureLocator

repeatedAcceptance :: Assertion
repeatedAcceptance = withHarness $ \environment _ -> do
  firstPreview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  firstResult <- run environment False (RespondCommand (response firstPreview "import.accept")) >>= interactionOf
  firstRaw <- case envelopeOpportunity firstResult of
    ImportResultOpportunity _ [identity] [] False -> pure identity
    opportunity -> assertFailure ("unexpected first import result: " <> show opportunity) >> fail "unreachable"
  before <- load environment
  secondPreview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  secondResult <- run environment False (RespondCommand (response secondPreview "import.accept"))
  secondEnvelope <- interactionOf secondResult
  case envelopeOpportunity secondEnvelope of
    ImportResultOpportunity _ [] [identity] False -> identity @?= firstRaw
    opportunity -> assertFailure ("repeat import was not idempotent: " <> show opportunity)
  resultMutationCommandId secondResult @?= Nothing
  finalDataset <- load environment
  loadedCursor finalDataset @?= loadedCursor before
  loadedEventCount finalDataset @?= loadedEventCount before
  Map.size (stateImportProfiles (loadedState finalDataset)) @?= 1
  Map.size (stateImportInvocations (loadedState finalDataset)) @?= 1
  Map.size (stateRaws (loadedState finalDataset)) @?= 1
  Map.size (stateSourceBindings (loadedState finalDataset)) @?= 1

changedAdapterInvocation :: Assertion
changedAdapterInvocation = withHarness $ \environment bytesRef -> do
  firstPreview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  _ <- run environment False (RespondCommand (response firstPreview "import.accept"))
  let upgraded = environment{appImportPort = fixtureImportPortWithIdentity fixturePackIdentityV2 bytesRef}
  secondPreview <- run upgraded False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  secondResult <- run upgraded False (RespondCommand (response secondPreview "import.accept")) >>= interactionOf
  case envelopeOpportunity secondResult of
    ImportResultOpportunity _ [] [_] False -> pure ()
    opportunity -> assertFailure ("new adapter invocation duplicated stable source material: " <> show opportunity)
  dataset <- load upgraded
  loadedEventCount dataset @?= 5
  Map.size (stateImportProfiles (loadedState dataset)) @?= 1
  Map.size (stateImportInvocations (loadedState dataset)) @?= 2
  Map.size (stateRaws (loadedState dataset)) @?= 1
  Map.size (stateSourceBindings (loadedState dataset)) @?= 1

changedSnapshot :: Assertion
changedSnapshot = withHarness $ \environment bytesRef -> do
  firstPreview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  _ <- run environment False (RespondCommand (response firstPreview "import.accept"))
  writeIORef bytesRef "a genuinely new snapshot\n"
  secondPreview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  secondResult <- run environment False (RespondCommand (response secondPreview "import.accept")) >>= interactionOf
  case envelopeOpportunity secondResult of
    ImportResultOpportunity _ [_] [] False -> pure ()
    opportunity -> assertFailure ("changed snapshot was not preserved separately: " <> show opportunity)
  dataset <- load environment
  Map.size (stateImportProfiles (loadedState dataset)) @?= 1
  Map.size (stateImportInvocations (loadedState dataset)) @?= 2
  Map.size (stateRaws (loadedState dataset)) @?= 2
  Map.size (stateSourceBindings (loadedState dataset)) @?= 2

stableIdentityConflict :: Assertion
stableIdentityConflict = withHarness $ \environment bytesRef -> do
  let stablePort = fixtureImportPortWithExternalIdentity "provider-note-42" bytesRef
      stableEnvironment = environment{appImportPort = stablePort}
  firstPreview <- run stableEnvironment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  _ <- run stableEnvironment False (RespondCommand (response firstPreview "import.accept"))
  writeIORef bytesRef "provider changed the same note\n"
  secondPreview <- run stableEnvironment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  runAppCommand stableEnvironment False silentProgress (RespondCommand (response secondPreview "import.accept")) >>= assertError Conflict
  dataset <- load stableEnvironment
  loadedEventCount dataset @?= 4
  Map.size (stateImportInvocations (loadedState dataset)) @?= 1
  Map.size (stateRaws (loadedState dataset)) @?= 1
  Map.size (stateSourceBindings (loadedState dataset)) @?= 1

stalePreflight :: Assertion
stalePreflight = withHarness $ \environment bytesRef -> do
  preview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  writeIORef bytesRef "changed after preview\n"
  refreshedResult <- run environment False (RespondCommand (response preview "import.accept"))
  refreshed <- interactionOf refreshedResult
  case envelopeOpportunity refreshed of
    ImportPreflightOpportunity _ preflight False ->
      sourcePreflightInputDigest preflight @?= sha256Hex "changed after preview\n"
    opportunity -> assertFailure ("stale source did not regenerate preflight: " <> show opportunity)
  assertBodyContains "The source or its signed adapter changed after the prior preview." refreshed
  dataset <- load environment
  loadedEventCount dataset @?= 0
  Map.size (stateRaws (loadedState dataset)) @?= 0

unsupportedAuthority :: Assertion
unsupportedAuthority = withHarness $ \environment _ -> do
  runAppCommand environment False silentProgress (ImportCommand fixtureReference SourceSynchronize False) >>= assertError Unsupported
  runAppCommand environment False silentProgress (ImportCommand fixtureReference SourceSnapshot True) >>= assertError Unsupported
  runAppCommand environment False silentProgress (ImportCommand fixtureReference SourceMigrate True) >>= assertError Unsupported
  dataset <- load environment
  loadedEventCount dataset @?= 0
  loadedState dataset @?= emptyState

dryRunAcceptance :: Assertion
dryRunAcceptance = withHarness $ \environment _ -> do
  preview <- run environment False (ImportCommand fixtureReference SourceSnapshot False) >>= interactionOf
  result <- run environment True (RespondCommand (response preview "import.accept"))
  resultDryRun result @?= True
  envelope <- interactionOf result
  contentHeading (envelopeContent envelope) @?= "Import simulation verified."
  assertBodyContains "1 new Raws would be preserved · 0 already preserved" envelope
  assertBodyContains "0 source items would change" envelope
  dataset <- load environment
  loadedCursor dataset @?= Genesis
  loadedEventCount dataset @?= 0
  Map.size (stateRaws (loadedState dataset)) @?= 0

withHarness :: (AppEnv -> IORef ByteString -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s09-import" $ \root -> do
  bytesRef <- newIORef fixtureBytes
  counter <- newIORef (2000 :: Int)
  let allocate = atomicModifyIORef' counter $ \seed -> (seed + 1, fixtureUuid seed)
      environment =
        AppEnv
          (StoreConfig (root </> "dataset") 2_000_000 20_000)
          actor
          (pure now)
          (pure (utcToZonedTime utc now))
          allocate
          emptyExportPort
          (fixtureImportPort bytesRef)
          Nothing
          Nothing
          Nothing
          Nothing
  action environment bytesRef

fixtureImportPort :: IORef ByteString -> ImportPort
fixtureImportPort = fixtureImportPortWithIdentity fixturePackIdentity

fixtureImportPortWithIdentity :: PackArtifactIdentity -> IORef ByteString -> ImportPort
fixtureImportPortWithIdentity identity bytesRef =
  ImportPort
    [ImportSourceDescriptor "plain_text" "Plain text fixture" [".txt"] [SourceSnapshot, SourceMigrate]]
    preflight
    materialize
    (importPortCleanupCustody emptyImportPort)
    (importPortCleanupItem emptyImportPort)
 where
  preflight source mode = do
    bytes <- readIORef bytesRef
    pure $ ImportRead source (fixtureInput bytes) <$> fixturePreflight identity (fixtureExternalId bytes) mode bytes
  materialize source mode = do
    bytes <- readIORef bytesRef
    pure $ do
      readValue <- ImportRead source (fixtureInput bytes) <$> fixturePreflight identity (fixtureExternalId bytes) mode bytes
      pure (ImportMaterialization readValue (Map.singleton (fixtureExternalId bytes) (SourceTextMaterial (decodeFixture bytes))))

fixtureImportPortWithExternalIdentity :: Text -> IORef ByteString -> ImportPort
fixtureImportPortWithExternalIdentity externalIdentity bytesRef =
  ImportPort
    [ImportSourceDescriptor "plain_text" "Plain text fixture" [".txt"] [SourceSnapshot, SourceMigrate]]
    preflight
    materialize
    (importPortCleanupCustody emptyImportPort)
    (importPortCleanupItem emptyImportPort)
 where
  preflight source mode = do
    bytes <- readIORef bytesRef
    pure $ ImportRead source (fixtureInput bytes) <$> fixturePreflight fixturePackIdentity externalIdentity mode bytes
  materialize source mode = do
    bytes <- readIORef bytesRef
    pure $ do
      readValue <- ImportRead source (fixtureInput bytes) <$> fixturePreflight fixturePackIdentity externalIdentity mode bytes
      pure (ImportMaterialization readValue (Map.singleton externalIdentity (SourceTextMaterial (decodeFixture bytes))))

multiObjectImportPort :: ImportPort
multiObjectImportPort =
  ImportPort
    [descriptor]
    preflight
    materialize
    (importPortCleanupCustody emptyImportPort)
    (importPortCleanupItem emptyImportPort)
 where
  descriptor = ImportSourceDescriptor "notesnook_export" "Notesnook export" [".zip"] [SourceSnapshot, SourceMigrate]
  preflight source mode = pure $ ImportRead source multiInput <$> multiPreflight mode
  materialize source mode = pure $ do
    readValue <- ImportRead source multiInput <$> multiPreflight mode
    pure (ImportMaterialization readValue multiMaterials)

multiPreflight :: SourceMode -> Either AppError SourcePreflight
multiPreflight mode =
  makeSourcePreflight
    "notesnook_export"
    fixturePackIdentity
    fixtureSigner
    1
    fixturePermissions
    mode
    multiInput
    ( SourceAdapterObservation
        "Notesnook export"
        Nothing
        (Map.singleton "archive_sha256" (sha256Hex (sourceInputBytes multiInput)))
        [SourceSnapshot, SourceMigrate]
        False
        [SourceContainer "path:Inbox" "Inbox", SourceContainer "path:Projects" "Projects"]
        [ multiObject "path:Inbox/Same title.md" "zip:fixture!/Inbox/Same title.md" "path:Inbox" "First note"
        , multiObject "path:Projects/Same title.md" "zip:fixture!/Projects/Same title.md" "path:Projects" "Second note"
        ]
        []
        []
    )
 where
  multiObject externalIdentity locator container text =
    SourceObject
      externalIdentity
      locator
      (Just container)
      "Same title"
      SourceNoteShape
      False
      0
      (summarizeSourceMaterial (SourceTextMaterial text))
      [sha256Hex (TextEncoding.encodeUtf8 text)]

multiInput :: SourceInput
multiInput = SourceInput "notesnook.zip" "application/zip" "fixture archive"

multiMaterials :: Map.Map Text SourceMaterial
multiMaterials =
  Map.fromList
    [ ("path:Inbox/Same title.md", SourceTextMaterial "First note")
    , ("path:Projects/Same title.md", SourceTextMaterial "Second note")
    ]

fixturePreflight :: PackArtifactIdentity -> Text -> SourceMode -> ByteString -> Either AppError SourcePreflight
fixturePreflight identity externalIdentity mode bytes =
  makeSourcePreflight
    "plain_text"
    identity
    fixtureSigner
    1
    fixturePermissions
    mode
    (fixtureInput bytes)
    (fixtureObservation externalIdentity bytes)

fixtureInput :: ByteString -> SourceInput
fixtureInput = SourceInput "notes.txt" "text/plain; charset=utf-8"

fixtureObservation :: Text -> ByteString -> SourceAdapterObservation
fixtureObservation externalIdentity bytes =
  SourceAdapterObservation
    "Plain text fixture"
    (Just "Local file")
    (Map.singleton "content_sha256" (sha256Hex bytes))
    [SourceSnapshot, SourceMigrate]
    False
    [SourceContainer fixtureContainerId "Fixture directory"]
    [ SourceObject
        externalIdentity
        fixtureLocator
        (Just fixtureContainerId)
        fixtureTitle
        SourceNoteShape
        False
        0
        (summarizeSourceMaterial (SourceTextMaterial (decodeFixture bytes)))
        [sha256Hex bytes]
    ]
    []
    []

fixturePackIdentity :: PackArtifactIdentity
fixturePackIdentity =
  PackArtifactIdentity
    "org.littleant"
    "org.littleant.standard"
    "1.0.0"
    (sha256Hex "fixture manifest")
    (sha256Hex "fixture archive")

fixturePackIdentityV2 :: PackArtifactIdentity
fixturePackIdentityV2 =
  fixturePackIdentity
    { artifactVersion = "1.0.1"
    , artifactManifestDigest = sha256Hex "fixture manifest v2"
    , artifactArchiveDigest = sha256Hex "fixture archive v2"
    }

fixtureSigner :: Text
fixtureSigner = sha256Hex "fixture signer"

fixturePermissions :: Text
fixturePermissions = "{\"credential_slots\":[],\"effect_purposes\":[],\"host_capabilities\":[\"input_bytes\"],\"http\":[],\"projections\":[]}"

fixtureReference, fixtureContainerId, fixtureLocator, fixtureTitle :: Text
fixtureReference = "notes.txt"
fixtureContainerId = "fixture-directory"
fixtureLocator = "fixture://notes.txt"
fixtureTitle = "notes.txt"

fixtureExternalId :: ByteString -> Text
fixtureExternalId = sha256Hex

fixtureText :: Text
fixtureText = "First line\nSecond line\n"

fixtureBytes :: ByteString
fixtureBytes = "First line\nSecond line\n"

decodeFixture :: ByteString -> Text
decodeFixture = either (error . show) id . TextEncoding.decodeUtf8'

run :: AppEnv -> Bool -> AppCommand -> IO CommandResult
run environment dryRun command = assertRight =<< runAppCommand environment dryRun silentProgress command

load :: AppEnv -> IO LoadedDataset
load environment = assertRight =<< loadDataset (appStore environment) silentProgress

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no import interaction: " <> show other) >> fail "unreachable"

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

assertBodyContains :: Text -> InteractionEnvelope -> Assertion
assertBodyContains expected envelope =
  assertBool
    ("missing body line: " <> Text.unpack expected)
    (any (expected `Text.isInfixOf`) (contentBody (envelopeContent envelope)))

assertError :: ErrorCode -> Either AppError CommandResult -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right result -> assertFailure ("expected " <> show expected <> ", got " <> show result)

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

only :: String -> [value] -> value
only label = \case
  [value] -> value
  values -> error ("expected one " <> label <> ", got " <> show (length values))

silentProgress :: Integer -> IO ()
silentProgress _ = pure ()

actor :: Actor
actor = Actor "human" "test"

now :: UTCTime
now = UTCTime (fromGregorian 2026 8 9) (secondsToDiffTime (3 * 3600))

fixtureUuid :: Int -> UUIDv7
fixtureUuid number =
  either (error . show) id $
    uuidV7FromEntropy
      (0x019f12340000 + fromIntegral number)
      (ByteString.replicate 10 (fromIntegral (number `mod` 251 + 1)))

module Main (main) where

import Control.Monad (forM)
import Data.Aeson (Value (..), eitherDecodeStrict', object, toJSON, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Model (SourceMode (..))
import LittleAnt.Pack.Format
import LittleAnt.Pack.Http
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Trust
import LittleAnt.Source
import LittleAnt.Store (sha256Hex)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (makeRelative, splitDirectories, (</>))
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 official connector Pack"
      [ testCase "the committed connector tree reconstructs one exact signed official artifact" canonicalArchive
      , testCase "Microsoft To Do paginates lists and tasks into sparse structured Raw previews" microsoftTodoSnapshot
      , testCase "completed tasks remain an explicit import choice" completedTaskChoice
      , testCase "migration refuses unmaterialized attachment bodies without explicit acknowledgment" attachmentMigrationGuard
      , testCase "a provider-controlled nextLink cannot leave the signed Graph route" nextLinkConfinement
      ]

canonicalArchive :: Assertion
canonicalArchive = do
  manifestBytes <- ByteString.readFile (connectorRoot </> "pack.json")
  signatureBytes <- ByteString.readFile (connectorRoot </> "signature.json")
  payload <- readPayload
  rebuilt <- assertRight (buildCanonicalPackArchive manifestBytes signatureBytes payload)
  committed <- ByteString.readFile (connectorRoot </> "official-connectors.lantpack")
  rebuilt @?= committed
  structural <- assertRight (validatePackArchive committed)
  authenticated <- assertRight (authenticatePack structural)
  let identity = authenticatedPackIdentity authenticated
  identity @?= connectorIdentity
  registry <- officialRegistry authenticated
  let registered = registryComponents registry
  Set.fromList (componentId . componentCommon . registeredComponent <$> registered) @?= Set.singleton microsoftTodoComponentId
  case registered of
    [registeredComponent'] -> case registeredComponent registeredComponent' of
      ExecutableComponent common _ permissions -> do
        componentKind common @?= SourceAdapterComponent
        permissionCredentialSlots permissions @?= [CredentialSlot "microsoft" OAuthDeviceAuthorization]
        permissionHttp permissions @?= [HttpPermission ["GET"] "graph.microsoft.com" "/v1.0/me/todo" (Just "microsoft")]
        permissionEffectPurposes permissions @?= [SourceCleanupItemPermission, SourceCleanupContainerPermission]
      component -> assertFailure ("unexpected connector component: " <> show component)
    components -> assertFailure ("unexpected connector component count: " <> show (length components))

microsoftTodoSnapshot :: Assertion
microsoftTodoSnapshot = do
  (client, registered) <- connectorRuntime
  calls <- newIORef []
  let broker = graphBroker False calls
  (input, preflight) <- invokePackSourcePreflightHttp client broker registered SourceSnapshot sourceLabel sourceWithoutCompleted >>= assertRight
  sourceInputMediaType input @?= "application/vnd.little-ant.http-transcript+json"
  sourcePreflightInputDigest preflight @?= sha256Hex (sourceInputBytes input)
  sourcePreflightAdapterId preflight @?= microsoftTodoComponentId
  let observation = sourcePreflightObservation preflight
  observedSourceLabel observation @?= "Microsoft To Do"
  observedAccountLabel observation @?= Just "Personal account"
  observedSupportedModes observation @?= [SourceSnapshot, SourceSynchronize, SourceMigrate]
  observedCleanupSupported observation @?= True
  observedIdentity observation
    @?= Map.fromList
      [ ("account_id", "account-42")
      , ("completed_item_count", "1")
      , ("deferred_attachment_task_count", "1")
      , ("included_item_count", "2")
      , ("list_count", "2")
      , ("open_item_count", "2")
      , ("provider", "microsoft_todo")
      ]
  (sourceContainerExternalId <$> observedContainers observation) @?= ["list:list+one=", "list:list-two"]
  (sourceObjectExternalId <$> observedObjects observation)
    @?= ["task:list+one=:task-1", "task:list-two:task-3"]
  assertBool "attachment limitation was hidden" (any ("attachment bodies" `Text.isInfixOf`) (observedUnsupportedFields observation))
  case observedObjects observation of
    firstObject : _ -> do
      sourceObjectShape firstObject @?= SourceTaskShape
      sourceObjectCompleted firstObject @?= False
      sourceObjectContainerId firstObject @?= Just "list:list+one="
      sourceObjectAttachmentCount firstObject @?= 0
      case sourceObjectMaterial firstObject of
        SourceMaterialSummary SourceStructuredKind _ _ preview -> assertBool "structured preview omitted its schema" ("microsoft-graph" `Text.isInfixOf` preview)
        material -> assertFailure ("unexpected task material: " <> show material)
    [] -> assertFailure "Microsoft To Do returned no source objects"
  preflightBytes <- assertRight (canonicalJsonBytes (toJSON preflight))
  assertBool "private provider task body escaped sparse preflight" (not ("::PRIVATE_GRAPH_BODY::" `ByteString.isInfixOf` preflightBytes))

  (materializedInput, materializedPreflight, materialization) <-
    invokePackSourceMaterializeHttp client broker registered SourceSnapshot sourceLabel sourceWithoutCompleted >>= assertRight
  materializedInput @?= input
  materializedPreflight @?= preflight
  let materials = materializedObjects materialization
  Map.keys materials @?= ["task:list+one=:task-1", "task:list-two:task-3"]
  case Map.lookup "task:list+one=:task-1" materials of
    Just (SourceStructuredMaterial schema encoded) -> do
      schema @?= "microsoft-graph/todo-task@1"
      assertBool "structured Raw omitted the complete task body" ("::PRIVATE_GRAPH_BODY::" `Text.isInfixOf` encoded)
      value <- either assertFailure pure (eitherDecodeStrict' (TextEncoding.encodeUtf8 encoded) :: Either String Value)
      assertBool "structured Raw omitted the original provider object" (hasObjectKey "task" value)
    material -> assertFailure ("unexpected materialized task: " <> show material)
  observedCalls <- readIORef calls
  length observedCalls @?= 8
  assertBool "Lua attempted to supply provider credentials" (all (Map.notMember "authorization" . brokerHttpHeaders) observedCalls)
  assertBool "path segments were not encoded canonically" (any ((== tasksListOneUrl) . brokerHttpUrl) observedCalls)

completedTaskChoice :: Assertion
completedTaskChoice = do
  (client, registered) <- connectorRuntime
  calls <- newIORef []
  (_, preflight) <- invokePackSourcePreflightHttp client (graphBroker False calls) registered SourceSynchronize sourceLabel sourceWithCompleted >>= assertRight
  let objects = observedObjects (sourcePreflightObservation preflight)
  (sourceObjectExternalId <$> objects)
    @?= ["task:list+one=:task-1", "task:list+one=:task-2", "task:list-two:task-3"]
  (sourceObjectCompleted <$> objects) @?= [False, True, False]

attachmentMigrationGuard :: Assertion
attachmentMigrationGuard = do
  (client, registered) <- connectorRuntime
  deniedCalls <- newIORef []
  denied <- invokePackSourcePreflightHttp client (graphBroker False deniedCalls) registered SourceMigrate sourceLabel sourceWithoutCompleted
  assertError ExternalFailure denied
  approvedCalls <- newIORef []
  (_, approved) <- invokePackSourcePreflightHttp client (graphBroker False approvedCalls) registered SourceMigrate sourceLabel sourceAllowingIncompleteAttachments >>= assertRight
  assertBool "explicitly partial migration lost its warning" (not (null (observedWarnings (sourcePreflightObservation approved))))

nextLinkConfinement :: Assertion
nextLinkConfinement = do
  (client, registered) <- connectorRuntime
  calls <- newIORef []
  result <- invokePackSourcePreflightHttp client (graphBroker True calls) registered SourceSnapshot sourceLabel sourceWithoutCompleted
  assertError PermissionRequired result
  readIORef calls >>= \observed -> length observed @?= 1

connectorRuntime :: IO (PackRunnerClient, RegisteredPackComponent)
connectorRuntime = do
  client <- defaultPackRunnerClient
  archive <- ByteString.readFile (connectorRoot </> "official-connectors.lantpack")
  structural <- assertRight (validatePackArchive archive)
  authenticated <- assertRight (authenticatePack structural)
  registry <- officialRegistry authenticated
  registered <- assertRight (lookupPackComponent microsoftTodoComponentId registry)
  pure (client, registered)

officialRegistry :: AuthenticatedPack -> IO PackRegistry
officialRegistry authenticated = do
  scope <- assertRight (mkProfileScope "default")
  let identity = authenticatedPackIdentity authenticated
      grant =
        OfficialReleaseGrant
          { officialGrantPublisher = artifactPublisher identity
          , officialGrantNamePrefix = "org.littleant."
          , officialGrantPublicKey = authenticatedSignerPublicKey authenticated
          , officialGrantKeyFingerprint = authenticatedSignerFingerprint authenticated
          , officialGrantName = artifactName identity
          , officialGrantVersion = artifactVersion identity
          , officialGrantManifestDigest = artifactManifestDigest identity
          , officialGrantArchiveDigest = artifactArchiveDigest identity
          }
      policy =
        PackTrustPolicy
          { trustSupportedLittleAntMajor = 1
          , trustBuiltInArtifacts = Set.empty
          , trustOfficialCatalogSequence = Just 1
          , trustOfficialCatalogExpiresAt = Just (read "2027-01-01 00:00:00 UTC")
          , trustOfficialReleaseGrants = Set.singleton grant
          , trustCommunityPublishers = Set.empty
          , trustRevokedKeyFingerprints = Set.empty
          , trustRevokedArchiveDigests = Set.empty
          }
  install <- assertRight (authorizePackInstall fixtureTime scope policy (Set.singleton microsoftTodoComponentId) authenticated)
  assessedTrustClass (installAuthorizedAssessment install) @?= VerifiedOfficialTrust
  execution <- assertRight (authorizePinnedPackExecution fixtureTime scope policy (installAuthorizedPin install) authenticated)
  assertRight (buildPackRegistry scope [execution])

graphBroker :: Bool -> IORef [BrokerHttpRequest] -> PackHttpBroker
graphBroker maliciousNextLink calls = PackHttpBroker $ \permission request -> do
  httpPermissionCredentialSlot permission @?= Just "microsoft"
  modifyIORef' calls (<> [request])
  pure $ case brokerHttpUrl request of
    url
      | url == listsUrl ->
          Right . jsonResponse $
            object
              [ "value" .= [listObject "list-two" "Work"]
              , "@odata.nextLink" .= if maliciousNextLink then ("https://example.com/v1.0/me/todo/lists?page=2" :: Text) else listsPageTwoUrl
              ]
      | url == listsPageTwoUrl -> Right (jsonResponse (object ["value" .= [listObject "list+one=" "Personal"]]))
      | url == tasksListOneUrl ->
          Right . jsonResponse $
            object
              [ "value"
                  .= [ taskObject "task-1" "Buy milk" "notStarted" True "::PRIVATE_GRAPH_BODY::"
                     , taskObject "task-2" "File taxes" "completed" False "Already done"
                     ]
              ]
      | url == tasksListTwoUrl -> Right (jsonResponse (object ["value" .= [taskObject "task-3" "Review contract" "inProgress" False "Read every clause"]]))
      | otherwise -> Left ((appError ExternalFailure "The fake Graph provider received an unexpected URL."){appErrorDetails = [url]})

jsonResponse :: Value -> BrokerHttpResponse
jsonResponse = BrokerHttpResponse 200 (Map.singleton "content-type" "application/json")

listObject :: Text -> Text -> Value
listObject identifier label =
  object
    [ "id" .= identifier
    , "displayName" .= label
    , "isOwner" .= True
    , "isShared" .= False
    , "wellknownListName" .= ("none" :: Text)
    ]

taskObject :: Text -> Text -> Text -> Bool -> Text -> Value
taskObject identifier title status hasAttachments body =
  object
    [ "id" .= identifier
    , "title" .= title
    , "status" .= status
    , "hasAttachments" .= hasAttachments
    , "importance" .= ("normal" :: Text)
    , "body" .= object ["contentType" .= ("text" :: Text), "content" .= body]
    ]

sourceWithoutCompleted, sourceWithCompleted, sourceAllowingIncompleteAttachments :: Value
sourceWithoutCompleted = sourceValue False False
sourceWithCompleted = sourceValue True False
sourceAllowingIncompleteAttachments = sourceValue False True

sourceValue :: Bool -> Bool -> Value
sourceValue includeCompleted allowIncompleteAttachments =
  object
    [ "provider" .= ("microsoft_todo" :: Text)
    , "account_id" .= ("account-42" :: Text)
    , "account_label" .= ("Personal account" :: Text)
    , "include_completed" .= includeCompleted
    , "allow_incomplete_attachments" .= allowIncompleteAttachments
    , "list_ids" .= ([] :: [Text])
    ]

hasObjectKey :: Text -> Value -> Bool
hasObjectKey key = \case
  Object fields -> KeyMap.member (Key.fromText key) fields
  _ -> False

readPayload :: IO (Map Text ByteString)
readPayload = do
  paths <- listFiles payloadRoot
  Map.fromList
    <$> forM
      paths
      ( \path -> do
          bytes <- ByteString.readFile path
          pure (portablePath (makeRelative payloadRoot path), bytes)
      )

listFiles :: FilePath -> IO [FilePath]
listFiles directory = do
  entries <- sort <$> listDirectory directory
  fmap concat . forM entries $ \entry -> do
    let path = directory </> entry
    isDirectory <- doesDirectoryExist path
    if isDirectory then listFiles path else pure [path]

portablePath :: FilePath -> Text
portablePath = Text.intercalate "/" . fmap Text.pack . splitDirectories

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertError :: ErrorCode -> Either AppError value -> Assertion
assertError expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure ("expected " <> show expected <> " failure")

connectorRoot, payloadRoot :: FilePath
connectorRoot = "packs" </> "official-connectors"
payloadRoot = connectorRoot </> "payload"

sourceLabel, microsoftTodoComponentId, listsUrl, listsPageTwoUrl, tasksListOneUrl, tasksListTwoUrl :: Text
sourceLabel = "Microsoft To Do · Personal account"
microsoftTodoComponentId = "microsoft_todo"
listsUrl = "https://graph.microsoft.com/v1.0/me/todo/lists"
listsPageTwoUrl = listsUrl <> "?page=2"
tasksListOneUrl = "https://graph.microsoft.com/v1.0/me/todo/lists/list%2Bone%3D/tasks"
tasksListTwoUrl = "https://graph.microsoft.com/v1.0/me/todo/lists/list-two/tasks"

fixtureTime :: UTCTime
fixtureTime = read "2026-08-09 09:00:00 UTC"

connectorIdentity :: PackArtifactIdentity
connectorIdentity =
  PackArtifactIdentity
    { artifactPublisher = "org.littleant.project"
    , artifactName = "org.littleant.official-connectors"
    , artifactVersion = "1.0.0"
    , artifactManifestDigest = "ee2c595318a7c0060206c7aa94c77e7f2f0ad10f8a2fc7ea9c02872c4845a065"
    , artifactArchiveDigest = "c6f8b9f46d261710fc8ff16d3ef82071d551b810bd00f0f859ec8764b91913ac"
    }

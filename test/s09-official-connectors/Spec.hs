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
      , testCase "Google Tasks paginates opaque tokens into sparse structured Raw previews" googleTasksSnapshot
      , testCase "Google Tasks completed and hidden tasks remain an explicit import choice" googleCompletedTaskChoice
      , testCase "Google Tasks cleanup verifies exact items and protects the default list" googleCleanupSafety
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
  Set.fromList (componentId . componentCommon . registeredComponent <$> registered) @?= Set.fromList [googleTasksComponentId, microsoftTodoComponentId]
  microsoft <- assertRight (lookupPackComponent microsoftTodoComponentId registry)
  case registeredComponent microsoft of
    ExecutableComponent common _ permissions -> do
      componentKind common @?= SourceAdapterComponent
      permissionCredentialSlots permissions @?= [CredentialSlot "microsoft" OAuthDeviceAuthorization]
      permissionOAuthDeviceAuthorizations permissions
        @?= [ OAuthDeviceAuthorizationPermission
                "microsoft"
                "https://login.microsoftonline.com/common/oauth2/v2.0/devicecode"
                "https://login.microsoftonline.com/common/oauth2/v2.0/token"
                "client_id"
                (Set.fromList ["Tasks.ReadWrite", "offline_access"])
            ]
      permissionHttp permissions @?= [HttpPermission ["GET", "DELETE"] "graph.microsoft.com" "/v1.0/me/todo" (Just "microsoft")]
      permissionEffectPurposes permissions @?= [SourceCleanupItemPermission, SourceCleanupContainerPermission]
    component -> assertFailure ("unexpected Microsoft To Do component: " <> show component)
  google <- assertRight (lookupPackComponent googleTasksComponentId registry)
  case registeredComponent google of
    ExecutableComponent common _ permissions -> do
      componentKind common @?= SourceAdapterComponent
      permissionCredentialSlots permissions @?= [CredentialSlot "google" OAuthAuthorizationCodePkce]
      permissionOAuthAuthorizationCodePkce permissions
        @?= [ OAuthAuthorizationCodePkcePermission
                "google"
                "https://accounts.google.com/o/oauth2/v2/auth"
                "https://oauth2.googleapis.com/token"
                "client_id"
                (Set.singleton googleTasksScope)
                (Map.fromList [("access_type", "offline"), ("prompt", "consent")])
            ]
      permissionHttp permissions @?= [HttpPermission ["GET", "DELETE"] "tasks.googleapis.com" "/tasks/v1" (Just "google")]
      permissionEffectPurposes permissions @?= [SourceCleanupItemPermission, SourceCleanupContainerPermission]
    component -> assertFailure ("unexpected Google Tasks component: " <> show component)

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

googleTasksSnapshot :: Assertion
googleTasksSnapshot = do
  (client, registered) <- connectorRuntimeFor googleTasksComponentId
  calls <- newIORef []
  (input, preflight) <- invokePackSourcePreflightHttp client (googleBroker False calls) registered SourceSnapshot googleSourceLabel googleSourceWithoutCompleted >>= assertRight
  sourcePreflightAdapterId preflight @?= googleTasksComponentId
  sourcePreflightInputDigest preflight @?= sha256Hex (sourceInputBytes input)
  let observation = sourcePreflightObservation preflight
  observedSourceLabel observation @?= "Google Tasks"
  observedAccountLabel observation @?= Just "Personal Google account"
  observedSupportedModes observation @?= [SourceSnapshot, SourceSynchronize, SourceMigrate]
  observedCleanupSupported observation @?= True
  observedIdentity observation
    @?= Map.fromList
      [ ("account_id", "google-account-42")
      , ("completed_item_count", "1")
      , ("included_item_count", "2")
      , ("list_count", "2")
      , ("open_item_count", "2")
      , ("provider", "google_tasks")
      ]
  (sourceContainerExternalId <$> observedContainers observation) @?= ["list:list+one=", "list:list-two"]
  (sourceObjectExternalId <$> observedObjects observation)
    @?= ["task:8:list-twotask-3", "task:9:list+one=task-1"]
  case observedObjects observation of
    firstObject : _ -> do
      sourceObjectShape firstObject @?= SourceTaskShape
      sourceObjectCompleted firstObject @?= False
      case sourceObjectMaterial firstObject of
        SourceMaterialSummary SourceStructuredKind _ _ preview -> assertBool "Google structured preview omitted its schema" ("google-tasks" `Text.isInfixOf` preview)
        material -> assertFailure ("unexpected Google task material: " <> show material)
    [] -> assertFailure "Google Tasks returned no source objects"
  preflightBytes <- assertRight (canonicalJsonBytes (toJSON preflight))
  assertBool "private Google task notes escaped sparse preflight" (not ("::PRIVATE_GOOGLE_BODY::" `ByteString.isInfixOf` preflightBytes))
  observedCalls <- readIORef calls
  length observedCalls @?= 4
  assertBool "Google page token was not encoded as one query component" (any ((== googleListsPageTwoUrl) . brokerHttpUrl) observedCalls)
  assertBool "Google task path segment was not encoded canonically" (any ((== googleTasksListOneOpenUrl) . brokerHttpUrl) observedCalls)

  materialCalls <- newIORef []
  (_, materializedPreflight, materialization) <- invokePackSourceMaterializeHttp client (googleBroker False materialCalls) registered SourceSnapshot googleSourceLabel googleSourceWithoutCompleted >>= assertRight
  materializedPreflight @?= preflight
  case Map.lookup "task:9:list+one=task-1" (materializedObjects materialization) of
    Just (SourceStructuredMaterial schema encoded) -> do
      schema @?= "google-tasks/task@1"
      assertBool "structured Google Raw omitted the complete task body" ("::PRIVATE_GOOGLE_BODY::" `Text.isInfixOf` encoded)
    material -> assertFailure ("unexpected materialized Google task: " <> show material)

googleCompletedTaskChoice :: Assertion
googleCompletedTaskChoice = do
  (client, registered) <- connectorRuntimeFor googleTasksComponentId
  calls <- newIORef []
  (_, preflight) <- invokePackSourcePreflightHttp client (googleBroker True calls) registered SourceSynchronize googleSourceLabel googleSourceWithCompleted >>= assertRight
  let objects = observedObjects (sourcePreflightObservation preflight)
  (sourceObjectExternalId <$> objects)
    @?= ["task:8:list-twotask-3", "task:9:list+one=task-1", "task:9:list+one=task-2"]
  (sourceObjectCompleted <$> objects) @?= [False, False, True]
  readIORef calls >>= \observed -> assertBool "completed Google Tasks were requested without showHidden" (any ((== googleTasksListOneCompleteUrl) . brokerHttpUrl) observed)

googleCleanupSafety :: Assertion
googleCleanupSafety = do
  (client, registered) <- connectorRuntimeFor googleTasksComponentId
  itemCalls <- newIORef []
  let itemBroker = PackHttpBroker $ \permission request -> do
        httpPermissionCredentialSlot permission @?= Just "google"
        modifyIORef' itemCalls (<> [request])
        if brokerHttpMethod request == "DELETE" && brokerHttpUrl request == googleTaskOneUrl
          then pure (Right (BrokerHttpResponse 204 Map.empty Null))
          else pure (Left ((appError ExternalFailure "Unexpected Google item-cleanup request."){appErrorDetails = [brokerHttpMethod request, brokerHttpUrl request]}))
  receipt <- invokePackSourceCleanupItemHttp client itemBroker registered googleSourceWithoutCompleted "task:9:list+one=task-1" googleTaskOneLocator (Just "list:list+one=") >>= assertRight
  sourceCleanupOutcome receipt @?= SourceCleanupSucceeded
  readIORef itemCalls >>= \calls -> fmap brokerHttpUrl calls @?= [googleTaskOneUrl]

  protectedCalls <- newIORef []
  protected <- invokePackSourceCleanupContainerInspectHttp client (googleContainerBroker True protectedCalls) registered googleSourceWithoutCompleted "list:list+one=" >>= assertRight
  inspectedContainerOutcome protected @?= SourceContainerProtected
  assertBool "default-list inspection unexpectedly enumerated or deleted tasks" . all ((/= "DELETE") . brokerHttpMethod) =<< readIORef protectedCalls

  emptyCalls <- newIORef []
  deleted <- invokePackSourceCleanupContainerHttp client (googleContainerBroker False emptyCalls) registered googleSourceWithoutCompleted "list:list+one=" >>= assertRight
  sourceCleanupOutcome deleted @?= SourceCleanupSucceeded
  readIORef emptyCalls >>= \calls -> assertBool "verified empty Google list was not deleted" (any (\request -> brokerHttpMethod request == "DELETE" && brokerHttpUrl request == googleListOneUrl) calls)

connectorRuntime :: IO (PackRunnerClient, RegisteredPackComponent)
connectorRuntime = connectorRuntimeFor microsoftTodoComponentId

connectorRuntimeFor :: Text -> IO (PackRunnerClient, RegisteredPackComponent)
connectorRuntimeFor componentId' = do
  client <- defaultPackRunnerClient
  archive <- ByteString.readFile (connectorRoot </> "official-connectors.lantpack")
  structural <- assertRight (validatePackArchive archive)
  authenticated <- assertRight (authenticatePack structural)
  registry <- officialRegistry authenticated
  registered <- assertRight (lookupPackComponent componentId' registry)
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
          , trustOfficialPinAuthorizations = Set.singleton (officialPinAuthorizationFromGrant 1 grant)
          , trustCommunityPublishers = Set.empty
          , trustRevokedKeyFingerprints = Set.empty
          , trustRevokedArchiveDigests = Set.empty
          }
  install <- assertRight (authorizePackInstall fixtureTime scope policy (Set.fromList [googleTasksComponentId, microsoftTodoComponentId]) authenticated)
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

googleBroker :: Bool -> IORef [BrokerHttpRequest] -> PackHttpBroker
googleBroker includeCompleted calls = PackHttpBroker $ \permission request -> do
  httpPermissionCredentialSlot permission @?= Just "google"
  modifyIORef' calls (<> [request])
  pure $ case brokerHttpUrl request of
    url
      | url == googleListsUrl ->
          Right . jsonResponse $
            object
              [ "items" .= [googleListObject "list-two" "Work"]
              , "nextPageToken" .= ("next &=" :: Text)
              ]
      | url == googleListsPageTwoUrl -> Right (jsonResponse (object ["items" .= [googleListObject "list+one=" "Personal"]]))
      | url == expectedListOne ->
          Right . jsonResponse $
            object
              [ "items"
                  .= [ googleTaskObject "task-1" "Buy milk" "needsAction" "::PRIVATE_GOOGLE_BODY::"
                     , googleTaskObject "task-2" "File taxes" "completed" "Already done"
                     ]
              ]
      | url == expectedListTwo -> Right (jsonResponse (object ["items" .= [googleTaskObject "task-3" "Review contract" "needsAction" "Read every clause"]]))
      | otherwise -> Left ((appError ExternalFailure "The fake Google Tasks provider received an unexpected URL."){appErrorDetails = [url]})
 where
  expectedListOne = if includeCompleted then googleTasksListOneCompleteUrl else googleTasksListOneOpenUrl
  expectedListTwo = if includeCompleted then googleTasksListTwoCompleteUrl else googleTasksListTwoOpenUrl

googleContainerBroker :: Bool -> IORef [BrokerHttpRequest] -> PackHttpBroker
googleContainerBroker targetIsDefault calls = PackHttpBroker $ \permission request -> do
  httpPermissionCredentialSlot permission @?= Just "google"
  modifyIORef' calls (<> [request])
  pure $ case (brokerHttpMethod request, brokerHttpUrl request) of
    ("GET", url) | url == googleListOneUrl -> Right (jsonResponse (googleListObject "list+one=" "Personal"))
    ("GET", url) | url == googleDefaultListUrl -> Right (jsonResponse (googleListObject (if targetIsDefault then "list+one=" else "default-list") "My Tasks"))
    ("GET", url) | url == googleContainerTasksUrl -> Right (jsonResponse (object ["items" .= ([] :: [Value])]))
    ("DELETE", url) | url == googleListOneUrl -> Right (BrokerHttpResponse 204 Map.empty Null)
    _ -> Left ((appError ExternalFailure "The fake Google container provider received an unexpected request."){appErrorDetails = [brokerHttpMethod request, brokerHttpUrl request]})

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

googleListObject :: Text -> Text -> Value
googleListObject identifier title =
  object
    [ "kind" .= ("tasks#taskList" :: Text)
    , "id" .= identifier
    , "etag" .= ("etag-" <> identifier)
    , "title" .= title
    , "updated" .= ("2026-08-09T12:00:00.000Z" :: Text)
    ]

googleTaskObject :: Text -> Text -> Text -> Text -> Value
googleTaskObject identifier title status notes =
  object
    [ "kind" .= ("tasks#task" :: Text)
    , "id" .= identifier
    , "etag" .= ("etag-" <> identifier)
    , "title" .= title
    , "status" .= status
    , "notes" .= notes
    , "updated" .= ("2026-08-09T12:00:00.000Z" :: Text)
    , "position" .= ("00000000000000000000" :: Text)
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

googleSourceWithoutCompleted, googleSourceWithCompleted :: Value
googleSourceWithoutCompleted = googleSourceValue False
googleSourceWithCompleted = googleSourceValue True

googleSourceValue :: Bool -> Value
googleSourceValue includeCompleted =
  object
    [ "provider" .= ("google_tasks" :: Text)
    , "account_id" .= ("google-account-42" :: Text)
    , "account_label" .= ("Personal Google account" :: Text)
    , "include_completed" .= includeCompleted
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

googleSourceLabel, googleTasksComponentId, googleTasksScope, googleListsUrl, googleListsPageTwoUrl, googleTasksListOneOpenUrl, googleTasksListTwoOpenUrl, googleTasksListOneCompleteUrl, googleTasksListTwoCompleteUrl, googleTaskOneUrl, googleTaskOneLocator, googleListOneUrl, googleDefaultListUrl, googleContainerTasksUrl :: Text
googleSourceLabel = "Google Tasks · Personal Google account"
googleTasksComponentId = "google_tasks"
googleTasksScope = "https://www.googleapis.com/auth/tasks"
googleListsUrl = "https://tasks.googleapis.com/tasks/v1/users/@me/lists?maxResults=1000"
googleListsPageTwoUrl = googleListsUrl <> "&pageToken=next%20%26%3D"
googleTasksListOneOpenUrl = "https://tasks.googleapis.com/tasks/v1/lists/list%2Bone%3D/tasks?maxResults=100&showAssigned=false&showCompleted=false&showDeleted=false&showHidden=false"
googleTasksListTwoOpenUrl = "https://tasks.googleapis.com/tasks/v1/lists/list-two/tasks?maxResults=100&showAssigned=false&showCompleted=false&showDeleted=false&showHidden=false"
googleTasksListOneCompleteUrl = "https://tasks.googleapis.com/tasks/v1/lists/list%2Bone%3D/tasks?maxResults=100&showAssigned=false&showCompleted=true&showDeleted=false&showHidden=true"
googleTasksListTwoCompleteUrl = "https://tasks.googleapis.com/tasks/v1/lists/list-two/tasks?maxResults=100&showAssigned=false&showCompleted=true&showDeleted=false&showHidden=true"
googleTaskOneUrl = "https://tasks.googleapis.com/tasks/v1/lists/list%2Bone%3D/tasks/task-1"
googleTaskOneLocator = "google-tasks://google-account-42/lists/list%2Bone%3D/tasks/task-1"
googleListOneUrl = "https://tasks.googleapis.com/tasks/v1/users/@me/lists/list%2Bone%3D"
googleDefaultListUrl = "https://tasks.googleapis.com/tasks/v1/users/@me/lists/@default"
googleContainerTasksUrl = "https://tasks.googleapis.com/tasks/v1/lists/list%2Bone%3D/tasks?maxResults=100&showAssigned=true&showCompleted=true&showDeleted=false&showHidden=true"

fixtureTime :: UTCTime
fixtureTime = read "2026-08-09 09:00:00 UTC"

connectorIdentity :: PackArtifactIdentity
connectorIdentity =
  PackArtifactIdentity
    { artifactPublisher = "org.littleant.project"
    , artifactName = "org.littleant.official-connectors"
    , artifactVersion = "1.0.0"
    , artifactManifestDigest = "23ec374a45ccf8ac839db91ec1b590b86ef042c832275b8e9025aeda95747cd6"
    , artifactArchiveDigest = "8722c8879e6534523d1b8fcb15aecd8f667f750096e28c9c28339b80ddd5b24d"
    }

module Main (main) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar, threadDelay)
import Control.Monad (foldM)
import Data.Bits ((.&.))
import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.ForecastWorld
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Profile
import LittleAnt.Result
import LittleAnt.Store
import LittleAnt.Vault
import LittleAnt.Vault.Age
import LittleAnt.Vault.Agent
import System.Directory (doesFileExist, doesPathExist)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Files (fileMode, getFileStatus)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S08 waits, delegation, and effects"
      [ testCase "Wait gates execution until its review opens and resolution releases only the gate" waitLifecycle
      , testCase "request Work atomically hands a Dependency over to its declared Wait" requestHandoffLifecycle
      , testCase "proposed Delegation preserves human execution and observed handoff suppresses it" delegationActivation
      , testCase "whole-scope Delegation covers current and future descendants" wholeScopeCoverage
      , testCase "follow-up none still produces internal Delegation review" explicitNoFollowUpStillReviews
      , testCase "Nature matrix rejects invalid Delegation scope" delegationNatureMatrix
      , testCase "external effect requires exact approval and durable dispatch before receipt" effectProtocol
      , testCase "external effect edit, defer, and reject are durable distinct transitions" effectReviewTransitions
      , testCase "follow-up counts only after a successful provider receipt" followUpReceiptReconciliation
      , testCase "unknown provider outcome cannot retry without duplicate-risk consent" unknownOutcomeRecovery
      , testCase "dumb skip flow activates an external-condition Wait" guidedWaitFlow
      , testCase "dumb response flow preserves request Raw and hands completion to Wait" guidedRequestHandoffFlow
      , testCase "dumb support flow creates and activates a manual Delegation" guidedDelegationFlow
      , testCase "new responsibility events round-trip through canonical JSONL" eventRoundTrip
      , testCase "vault ciphertext uses fixed age-v1 scrypt and round-trips" vaultRoundTrip
      , testCase "vault rejects a wrong passphrase without exposing it" vaultWrongPassphrase
      , testCase "vault file is private, atomic-format, and redacted in inventory" vaultFileLifecycle
      , testCase "vault backup is exclusive and passphrase rotation remains readable" vaultBackupAndRotation
      , testCase "profile-scoped vault agent locks, unlocks, resolves, and expires privately" vaultAgentLifecycle
      , testCase "profiles resolve separate typed XDG stores without merging" profileLifecycle
      ]

profileLifecycle :: Assertion
profileLifecycle = withSystemTempDirectory "lant-profile" $ \root -> do
  let roots = XdgRoots (root </> "config") (root </> "data") (root </> "state") (root </> "run")
  defaultPaths <- createProfile roots "default" (fixtureUuid 310) >>= assertRight
  assertBool "profile.yaml must exist" =<< doesFileExist (profileFile defaultPaths)
  assertBool "preferences.yaml must exist" =<< doesFileExist (preferencesFile defaultPaths)
  assertBool "calibration.yaml must exist" =<< doesFileExist (calibrationFile defaultPaths)
  assertBool "integrations.yaml must exist" =<< doesFileExist (integrationsFile defaultPaths)
  (_, defaultConfig, preferences, _, _) <- loadProfile roots "default" >>= assertRight
  configuredDataset defaultConfig @?= datasetDirectory defaultPaths
  preferredPresentationLanguage preferences @?= "en"
  workPaths <- createProfile roots "work" (fixtureUuid 311) >>= assertRight
  assertBool "profiles must not share datasets" (datasetDirectory defaultPaths /= datasetDirectory workPaths)
  writeSelectedProfile roots "work" >>= assertRight
  readSelectedProfile roots >>= assertRight >>= (@?= Just "work")
  assertBool "uppercase profile names are rejected" (not (validProfileName "Work"))

vaultBackupAndRotation :: Assertion
vaultBackupAndRotation = withSystemTempDirectory "lant-vault-rotation" $ \root -> do
  original <- assertRight (makePassphrase "original passphrase")
  replacement <- assertRight (makePassphrase "replacement passphrase")
  populated <- assertRight (insertVaultEntry (fixtureUuid 307) BearerCredential "Rotation fixture" "rotation-secret-4567" Map.empty (emptyVault (fixtureUuid 306)))
  let path = root </> "default.age"
      backup = root </> "default-backup.age"
  writeVault path original populated >>= assertRight
  backupVault path backup >>= assertRight
  assertBool "backup must exist" =<< doesFileExist backup
  assertLeftIO (backupVault path backup)
  rotateVault path original replacement >>= assertRight
  assertLeftIO (readVault path original)
  rotated <- readVault path replacement >>= assertRight
  vaultRevision rotated @?= vaultRevision populated
  diagnostics <- diagnoseVault path >>= assertRight
  assertBool "diagnostics must identify age-v1 without plaintext" ("age_header: age-v1-scrypt-2^18" `elem` diagnostics)

vaultAgentLifecycle :: Assertion
vaultAgentLifecycle = withSystemTempDirectory "lant-vault-agent" $ \root -> do
  passphrase <- assertRight (makePassphrase "agent passphrase")
  populated <- assertRight (insertVaultEntry (fixtureUuid 305) ApiKeyCredential "Test API" "agent-secret-9876" Map.empty (emptyVault (fixtureUuid 304)))
  let vaultPath = root </> "vaults" </> "default.age"
      socketPath = root </> "runtime" </> "default" </> "vault.sock"
  writeVault vaultPath passphrase populated >>= assertRight
  finished <- newEmptyMVar
  _ <- forkIO (runVaultAgent socketPath vaultPath 1 >>= putMVar finished)
  waitForPath socketPath 100
  locked <- sendVaultAgentRequest socketPath agentStatusRequest >>= assertRight
  agentReplyUnlocked locked @?= Just False
  unlocked <- sendVaultAgentRequest socketPath (agentUnlockRequest "agent passphrase") >>= assertRight
  assertBool "unlock must return only an acknowledgement" (agentReplySucceeded unlocked)
  inventory <- sendVaultAgentRequest socketPath agentInventoryRequest >>= assertRight
  fmap inventoryRedactedSuffix <$> agentReplyInventory inventory @?= Just [Just "9876"]
  resolved <- sendVaultAgentRequest socketPath (agentResolveRequest (fixtureUuid 305) "test_effect") >>= assertRight
  agentReplySecret resolved @?= Just "agent-secret-9876"
  threadDelay 1_200_000
  expired <- sendVaultAgentRequest socketPath agentStatusRequest >>= assertRight
  agentReplyUnlocked expired @?= Just False
  stopped <- sendVaultAgentRequest socketPath agentShutdownRequest >>= assertRight
  assertBool "shutdown must acknowledge before closing" (agentReplySucceeded stopped)
  takeMVar finished >>= assertRight

waitForPath :: FilePath -> Int -> Assertion
waitForPath path attempts
  | attempts <= 0 = assertFailure ("timed out waiting for " <> path)
  | otherwise = do
      exists <- doesPathExist path
      if exists then pure () else threadDelay 10_000 >> waitForPath path (attempts - 1)

vaultFileLifecycle :: Assertion
vaultFileLifecycle = withSystemTempDirectory "lant-vault" $ \root -> do
  passphrase <- assertRight (makePassphrase "correct horse battery staple")
  populated <- assertRight (insertVaultEntry (fixtureUuid 303) ApiKeyCredential "Work API" "super-secret-1234" Map.empty (emptyVault (fixtureUuid 302)))
  let path = root </> "vaults" </> "default.age"
  writeVault path passphrase populated >>= assertRight
  ciphertext <- ByteString.readFile path
  assertBool "ciphertext must not expose the secret" (not ("super-secret-1234" `ByteString.isInfixOf` ciphertext))
  status <- getFileStatus path
  fileMode status .&. 0o077 @?= 0
  loaded <- readVault path passphrase >>= assertRight
  vaultRevision loaded @?= vaultRevision populated
  fmap inventoryRedactedSuffix (vaultInventory loaded) @?= [Just "1234"]

vaultRoundTrip :: Assertion
vaultRoundTrip = do
  passphrase <- assertRight (makePassphrase "correct horse battery staple")
  encrypted <- encryptAge passphrase "{\"schema\":\"little-ant/vault@1\"}" >>= assertRight
  validateAgeHeader encrypted @?= Right ()
  decrypted <- decryptAge passphrase encrypted >>= assertRight
  decrypted @?= "{\"schema\":\"little-ant/vault@1\"}"

vaultWrongPassphrase :: Assertion
vaultWrongPassphrase = do
  correct <- assertRight (makePassphrase "correct horse battery staple")
  wrong <- assertRight (makePassphrase "not the passphrase")
  encrypted <- encryptAge correct "secret" >>= assertRight
  result <- decryptAge wrong encrypted
  case result of
    Left problem -> do
      assertBool "error must be present" (not (null (show problem)))
      let rendered = Text.pack (show problem)
      assertBool "error must not contain either passphrase" (all (not . (`Text.isInfixOf` rendered)) ["correct horse battery staple", "not the passphrase"])
    Right _ -> assertFailure "a wrong passphrase decrypted the vault"

waitLifecycle :: Assertion
waitLifecycle = do
  let state0 = workState AtomicTask
      actor = testActor
      reviewAt = zoned (addUTCTime 3600 now)
  mutation <- assertRight (decideActivateWait state0 actor mainBrickId (ExternalConditionWait "Legal approval") reviewAt (facts now 10 4))
  state1 <- applyMutation state0 mutation
  ordinaryKinds state1 now @?= []
  ordinaryKinds state1 (addUTCTime 3599 now) @?= []
  ordinaryKinds state1 (addUTCTime 3600 now) @?= [WaitReviewOpportunity]
  let gate = head (Map.elems (stateWaits state1))
  resolved <- assertRight (decideReviewWait state1 actor (waitId gate) WaitResponseReceivedObservation WaitResolved Nothing (Just "Condition observed") (facts (addUTCTime 3600 now) 20 3))
  state2 <- applyMutation state1 resolved
  ordinaryKinds state2 (addUTCTime 3600 now) @?= [FiniteWorkOpportunity]
  Map.size (stateWaitObservations state2) @?= 2

requestHandoffLifecycle :: Assertion
requestHandoffLifecycle = do
  state1 <- withEntity (workState AtomicTask)
  fed <- assertRight (decideFeed state1 testActor "guided_request" "Ask Alice Moreira for the production access" (facts now 320 3))
  state2 <- applyEvents state1 (feedDecisionEvents fed)
  declared <- assertRight (decideCreateRequestHandoff state2 testActor mainBrickId entityId (rawId (feedDecisionRaw fed)) Nothing 259200 (facts now 330 11))
  state3 <- applyMutation state2 declared
  let enabling =
        case [brick | brick <- Map.elems (stateBricks state3), brickId brick /= mainBrickId] of
          [brick] -> brick
          other -> error ("expected one enabling Brick, got " <> show other)
      successor = head (Map.elems (stateWaitSuccessors state3))
  waitSuccessorEnablingBrick successor @?= brickId enabling
  waitSuccessorAffectedBrick successor @?= mainBrickId
  assertBool "the response Wait must not exist before the request handoff" (Map.null (stateWaits state3))
  fmap dependencyStatus (Map.elems (stateDependencies state3)) @?= [DependencyActive]
  let completedAt = addUTCTime 60 now
  completed <- assertRight (decideCompleteBrick state3 testActor (brickId enabling) (facts completedAt 350 (completionUUIDCount state3 (brickId enabling))))
  state4 <- applyMutation state3 completed
  brickStatus (stateBricks state4 Map.! brickId enabling) @?= BrickDone
  fmap dependencyStatus (Map.elems (stateDependencies state4)) @?= [DependencyResolved]
  fmap waitStatus (Map.elems (stateWaits state4)) @?= [WaitActive]
  ordinaryKinds state4 (addUTCTime (259200 - 1) completedAt) @?= []
  ordinaryKinds state4 (addUTCTime 259200 completedAt) @?= [WaitReviewOpportunity]

delegationActivation :: Assertion
delegationActivation = do
  state1 <- withEntity (workState AtomicTask)
  proposed <- assertRight (decideProposeDelegation state1 testActor mainBrickId entityId BrickOnlyDelegation FollowUpOnce 259200 "Please handle this." (facts now 30 3))
  state2 <- applyMutation state1 proposed
  ordinaryKinds state2 now @?= [FiniteWorkOpportunity]
  let delegation = head (Map.elems (stateDelegations state2))
      reviewAt = zoned (addUTCTime 259200 now)
  activated <- assertRight (decideObserveDelegationHandoff state2 testActor (delegationId delegation) (Just reviewAt) (facts now 40 2))
  state3 <- applyMutation state2 activated
  ordinaryKinds state3 now @?= []
  ordinaryKinds state3 (addUTCTime 259200 now) @?= [DelegationReviewOpportunity]

wholeScopeCoverage :: Assertion
wholeScopeCoverage = do
  let child = mkBrick childId (Handle "child") "Child" AtomicTask (Just mainBrickId) 0
      future = mkBrick futureChildId (Handle "future") "Future child" AtomicTask (Just mainBrickId) 1
      state0 = (workState Project){stateBricks = Map.insert childId child (stateBricks (workState Project)), stateBrickHandles = Map.insert (brickHandle child) childId (stateBrickHandles (workState Project))}
  state1 <- withEntity state0
  proposed <- assertRight (decideProposeDelegation state1 testActor mainBrickId entityId WholeScopeDelegation FollowUpEvery 86400 "Own this scope." (facts now 50 3))
  state2 <- applyMutation state1 proposed
  let delegation = head (Map.elems (stateDelegations state2))
  activated <- assertRight (decideObserveDelegationHandoff state2 testActor (delegationId delegation) (Just (zoned (addUTCTime 86400 now))) (facts now 60 2))
  state3 <- applyMutation state2 activated
  ordinaryKindsFor state3 now childId @?= []
  let state4 = state3{stateBricks = Map.insert futureChildId future (stateBricks state3), stateBrickHandles = Map.insert (brickHandle future) futureChildId (stateBrickHandles state3)}
  ordinaryKindsFor state4 now futureChildId @?= []

explicitNoFollowUpStillReviews :: Assertion
explicitNoFollowUpStillReviews = do
  state1 <- withEntity (workState AtomicTask)
  proposed <- assertRight (decideProposeDelegation state1 testActor mainBrickId entityId BrickOnlyDelegation FollowUpNone 86400 "Please handle this." (facts now 70 3))
  state2 <- applyMutation state1 proposed
  let delegation = head (Map.elems (stateDelegations state2))
  activated <- assertRight (decideObserveDelegationHandoff state2 testActor (delegationId delegation) (Just (zoned (addUTCTime 86400 now))) (facts now 80 2))
  state3 <- applyMutation state2 activated
  ordinaryKinds state3 (addUTCTime 86400 now) @?= [DelegationReviewOpportunity]

delegationNatureMatrix :: Assertion
delegationNatureMatrix = do
  state1 <- withEntity (workState Collection)
  assertLeft (decideProposeDelegation state1 testActor mainBrickId entityId WholeScopeDelegation FollowUpOnce 86400 "Wrong scope" (facts now 90 3))
  habitState <- withEntity (workState Habit)
  assertLeft (decideProposeDelegation habitState testActor mainBrickId entityId BrickOnlyDelegation FollowUpOnce 86400 "Wrong nature" (facts now 100 3))

effectProtocol :: Assertion
effectProtocol = do
  state1 <- activeDelegationState
  let delegation = head (Map.elems (stateDelegations state1))
  proposed <- assertRight (decideProposeExternalEffect state1 testActor (delegationId delegation) DelegationDeliveryEffect Nothing Nothing "Please handle this." (facts now 110 3))
  state2 <- applyMutation state1 proposed
  let effect = head (Map.elems (stateExternalEffects state2))
  assertLeft (decideStartExternalEffectDispatch state2 testActor (externalEffectId effect) (facts now 120 2))
  approved <- assertRight (decideApproveExternalEffect state2 testActor (externalEffectId effect) (facts now 130 2))
  state3 <- applyMutation state2 approved
  dispatching <- assertRight (decideStartExternalEffectDispatch state3 testActor (externalEffectId effect) (facts now 140 2))
  state4 <- applyMutation state3 dispatching
  receipt <- assertRight (decideRecordExternalEffectReceipt state4 testActor (externalEffectId effect) EffectSucceeded (Just "provider-42") Nothing (facts now 150 3))
  state5 <- applyMutation state4 receipt
  externalEffectStatus (stateExternalEffects state5 Map.! externalEffectId effect) @?= EffectSucceeded
  Map.size (stateExternalEffectReceipts state5) @?= 1

effectReviewTransitions :: Assertion
effectReviewTransitions = do
  state1 <- activeDelegationState
  let delegation = head (Map.elems (stateDelegations state1))
  proposed <- assertRight (decideProposeExternalEffect state1 testActor (delegationId delegation) DelegationFollowUpEffect Nothing Nothing "First draft" (facts now 190 3))
  state2 <- applyMutation state1 proposed
  let effect = head (Map.elems (stateExternalEffects state2))
  revised <- assertRight (decideReviseExternalEffect state2 testActor (externalEffectId effect) "Clearer draft" (facts now 200 2))
  state3 <- applyMutation state2 revised
  externalEffectMessage (stateExternalEffects state3 Map.! externalEffectId effect) @?= "Clearer draft"
  deferred <- assertRight (decideDeferExternalEffect state3 testActor (externalEffectId effect) (zoned (addUTCTime 7200 now)) (facts now 210 2))
  state4 <- applyMutation state3 deferred
  assertBool "deferred effect must not be selectable early" (ExternalEffectApprovalOpportunity `notElem` ordinaryKinds state4 (addUTCTime 7199 now))
  assertBool "deferred effect must return at its gate" (ExternalEffectApprovalOpportunity `elem` ordinaryKinds state4 (addUTCTime 7200 now))
  rejected <- assertRight (decideRejectExternalEffect state4 testActor (externalEffectId effect) (facts now 220 2))
  state5 <- applyMutation state4 rejected
  externalEffectStatus (stateExternalEffects state5 Map.! externalEffectId effect) @?= EffectRejected

followUpReceiptReconciliation :: Assertion
followUpReceiptReconciliation = do
  state1 <- activeDelegationState
  let delegation = head (Map.elems (stateDelegations state1))
  reviewed <- assertRight (decideReviewDelegationWithFollowUp state1 testActor (delegationId delegation) "Could you share an update?" (facts now 230 4))
  state2 <- applyMutation state1 reviewed
  let proposedEffect = head (Map.elems (stateExternalEffects state2))
      reviewedDelegation = stateDelegations state2 Map.! delegationId delegation
  externalEffectStatus proposedEffect @?= EffectPendingApproval
  delegationFollowUpHandoffs reviewedDelegation @?= 0
  approved <- assertRight (decideApproveExternalEffect state2 testActor (externalEffectId proposedEffect) (facts now 240 2))
  state3 <- applyMutation state2 approved
  dispatching <- assertRight (decideStartExternalEffectDispatch state3 testActor (externalEffectId proposedEffect) (facts now 250 2))
  state4 <- applyMutation state3 dispatching
  delegationFollowUpHandoffs (stateDelegations state4 Map.! delegationId delegation) @?= 0
  received <-
    assertRight
      ( decideRecordExternalEffectReceipt
          state4
          testActor
          (externalEffectId proposedEffect)
          EffectSucceeded
          (Just "provider-follow-up-1")
          Nothing
          (facts now 260 (externalEffectReceiptUUIDCount state4 (externalEffectId proposedEffect) EffectSucceeded))
      )
  state5 <- applyMutation state4 received
  let reconciled = stateDelegations state5 Map.! delegationId delegation
  delegationStatus reconciled @?= DelegationActive
  delegationFollowUpHandoffs reconciled @?= 1
  delegationLastObservation reconciled @?= Just "follow_up_delivered"

unknownOutcomeRecovery :: Assertion
unknownOutcomeRecovery = do
  state1 <- activeDelegationState
  let delegation = head (Map.elems (stateDelegations state1))
  proposed <- assertRight (decideProposeExternalEffect state1 testActor (delegationId delegation) DelegationFollowUpEffect Nothing Nothing "Could you share an update?" (facts now 270 3))
  state2 <- applyMutation state1 proposed
  let effect = head (Map.elems (stateExternalEffects state2))
  approved <- assertRight (decideApproveExternalEffect state2 testActor (externalEffectId effect) (facts now 280 2))
  state3 <- applyMutation state2 approved
  dispatching <- assertRight (decideStartExternalEffectDispatch state3 testActor (externalEffectId effect) (facts now 290 2))
  state4 <- applyMutation state3 dispatching
  unknown <- assertRight (decideRecordExternalEffectReceipt state4 testActor (externalEffectId effect) EffectOutcomeUnknown Nothing (Just "connection closed") (facts now 300 3))
  state5 <- applyMutation state4 unknown
  externalEffectStatus (stateExternalEffects state5 Map.! externalEffectId effect) @?= EffectOutcomeUnknown
  assertLeft (decideRetryExternalEffect state5 testActor (externalEffectId effect) False (facts now 310 2))
  retry <- assertRight (decideRetryExternalEffect state5 testActor (externalEffectId effect) True (facts now 320 2))
  state6 <- applyMutation state5 retry
  let revised = stateExternalEffects state6 Map.! externalEffectId effect
  externalEffectStatus revised @?= EffectPendingApproval
  externalEffectApprovedDigest revised @?= Nothing
  stopped <- assertRight (decideRejectExternalEffect state6 testActor (externalEffectId effect) (facts now 330 2))
  state7 <- applyMutation state6 stopped
  externalEffectStatus (stateExternalEffects state7 Map.! externalEffectId effect) @?= EffectRejected

guidedWaitFlow :: Assertion
guidedWaitFlow = withAppHarness $ \environment -> do
  seedGuidedBrick environment
  proposal <- runCommand environment (FocusCommand "#work") >>= interactionFrom
  symptom <- answerInteraction environment proposal "focus.skip"
  classifier <- answerInteraction environment symptom "work.symptom.blocked"
  reaction <- answerInteraction environment classifier "work.reaction.condition"
  delay <- submitInteraction environment reaction "wait.condition.submit" "Legal approval arrives"
  case envelopeOpportunity delay of
    WaitActivationDelayOpportunity identity _ (ExternalConditionWait condition) -> do
      identity @?= mainBrickId
      condition @?= "Legal approval arrives"
    other -> assertFailure ("expected Wait activation delay, got " <> show other)
  receipt <- answerInteraction environment delay "wait.activate.three-days"
  case envelopeOpportunity receipt of
    WaitActivationResultOpportunity{} -> pure ()
    other -> assertFailure ("expected Wait activation receipt, got " <> show other)
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  fmap waitKind (Map.elems (stateWaits (loadedState loaded))) @?= [ExternalConditionWait "Legal approval arrives"]

guidedRequestHandoffFlow :: Assertion
guidedRequestHandoffFlow = withAppHarness $ \environment -> do
  seedGuidedBrick environment
  proposal <- runCommand environment (FocusCommand "#work") >>= interactionFrom
  symptom <- answerInteraction environment proposal "focus.skip"
  classifier <- answerInteraction environment symptom "work.symptom.blocked"
  people <- answerInteraction environment classifier "work.reaction.response"
  kind <- answerInteraction environment people "entity.new"
  name <- answerInteraction environment kind "entity.kind.person"
  requestStatus <- submitInteraction environment name "entity.name.submit" "Alice Moreira"
  input <- answerInteraction environment requestStatus "wait.request.no"
  delay <- submitInteraction environment input "wait.request.input.submit" "Ask Alice Moreira for production access"
  preview <- answerInteraction environment delay "wait.request.delay.three-days"
  result <- answerInteraction environment preview "wait.request.preview.accept"
  case envelopeOpportunity result of
    WaitRequestHandoffResultOpportunity{} -> pure ()
    other -> assertFailure ("expected request handoff result, got " <> show other)
  declared <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let declaredState = loadedState declared
      enabling =
        case [brick | brick <- Map.elems (stateBricks declaredState), brickId brick /= mainBrickId] of
          [brick] -> brick
          other -> error ("expected one enabling request Brick, got " <> show other)
  fmap dependencyStatus (Map.elems (stateDependencies declaredState)) @?= [DependencyActive]
  Map.size (stateWaitSuccessors declaredState) @?= 1
  Map.size (stateRaws declaredState) @?= 2
  focusProposal <- runCommand environment (FocusCommand (renderHandle BrickHandle (brickHandle enabling))) >>= interactionFrom
  focused <- answerInteraction environment focusProposal "focus.accept"
  _ <- answerInteraction environment focused "focus.done"
  completed <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  fmap dependencyStatus (Map.elems (stateDependencies (loadedState completed))) @?= [DependencyResolved]
  fmap waitStatus (Map.elems (stateWaits (loadedState completed))) @?= [WaitActive]

guidedDelegationFlow :: Assertion
guidedDelegationFlow = withAppHarness $ \environment -> do
  seedGuidedBrick environment
  proposal <- runCommand environment (FocusCommand "#work") >>= interactionFrom
  symptom <- answerInteraction environment proposal "focus.skip"
  hard <- answerInteraction environment symptom "work.symptom.hard"
  people <- answerInteraction environment hard "work.reaction.support"
  kind <- answerInteraction environment people "entity.new"
  name <- answerInteraction environment kind "entity.kind.person"
  policy <- submitInteraction environment name "entity.name.submit" "Alice Moreira"
  case envelopeOpportunity policy of
    DelegationPolicyOpportunity draft -> delegationDraftScope draft @?= Just BrickOnlyDelegation
    other -> assertFailure ("expected fixed-scope Delegation policy, got " <> show other)
  delay <- answerInteraction environment policy "delegation.policy.once"
  preview <- answerInteraction environment delay "delegation.delay.three-days"
  handoff <- answerInteraction environment preview "delegation.preview.accept"
  case envelopeOpportunity handoff of
    DelegationHandoffOpportunity{} -> pure ()
    other -> assertFailure ("expected proposed manual handoff, got " <> show other)
  _ <- answerInteraction environment handoff "delegation.handoff.observed"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  fmap delegationStatus (Map.elems (stateDelegations (loadedState loaded))) @?= [DelegationActive]
  fmap externalEntityName (Map.elems (stateExternalEntities (loadedState loaded))) @?= ["Alice Moreira"]

eventRoundTrip :: Assertion
eventRoundTrip = do
  mutation <- assertRight (decideRegisterExternalEntity (workState AtomicTask) testActor PersonEntity "Alice Moreira" (facts now 160 3))
  let persisted = persist 1 (head (mutationDecisionEvents mutation))
  decodeEvent (encodeEvent persisted) @?= Right persisted

activeDelegationState :: IO State
activeDelegationState = do
  state1 <- withEntity (workState AtomicTask)
  proposed <- assertRight (decideProposeDelegation state1 testActor mainBrickId entityId BrickOnlyDelegation FollowUpEvery 86400 "Please handle this." (facts now 170 3))
  state2 <- applyMutation state1 proposed
  let delegation = head (Map.elems (stateDelegations state2))
  activated <- assertRight (decideObserveDelegationHandoff state2 testActor (delegationId delegation) (Just (zoned (addUTCTime 86400 now))) (facts now 180 2))
  applyMutation state2 activated

withEntity :: State -> IO State
withEntity state = do
  mutation <- assertRight (decideRegisterExternalEntity state testActor PersonEntity "Alice Moreira" (facts now 1 3))
  applyMutation state mutation

withAppHarness :: (AppEnv -> IO a) -> IO a
withAppHarness action = withSystemTempDirectory "little-ant-s08-flow" $ \root -> do
  counter <- newIORef (6000 :: Int)
  let allocate = atomicModifyIORef' counter $ \number -> (number + 1, fixtureUuid number)
      environment =
        AppEnv
          (StoreConfig root 2_000_000 20_000)
          testActor
          (pure now)
          (pure (utcToZonedTime utc now))
          allocate
          emptyExportPort
  action environment

seedGuidedBrick :: AppEnv -> IO ()
seedGuidedBrick environment = do
  let rawIdentity = fixtureUuid 500
      commandId = fixtureUuid 501
      eventIds = fmap fixtureUuid [502 .. 505]
      linkId = fixtureUuid 506
      precondition = statePreconditionHash emptyState
      replayIds = rawIdentity : mainBrickId : commandId : linkId : eventIds
      draft eventId payload = EventDraft eventId commandId testActor now precondition replayIds payload
      events =
        [ draft (eventIds !! 0) (RawFedV1 (RawFed rawIdentity (Handle "work") "Work" "test" Nothing))
        , draft
            (eventIds !! 1)
            ( BrickCreatedV1
                ( BrickCreated
                    mainBrickId
                    (Handle "work")
                    "Work"
                    AtomicTask
                    "factory@1"
                    "test"
                    Nothing
                    Nothing
                    Set.empty
                    0
                    (DeterministicPosition "fixture")
                    rawIdentity
                )
            )
        , draft (eventIds !! 2) (RawLinkAddedV1 (RawLinkAdded linkId rawIdentity (RawLinkBrick mainBrickId) MaterializationSourceRole))
        , draft (eventIds !! 3) (RawDispositionAcceptedV1 (RawDispositionAccepted rawIdentity (RawMaterializedAsWork mainBrickId)))
        ]
  accepted <- appendCommand (appStore environment) Genesis events
  either (assertFailure . show) (const (pure ())) accepted

runCommand :: AppEnv -> AppCommand -> IO CommandResult
runCommand environment command = assertRight =<< runAppCommand environment False (const (pure ())) command

answerInteraction :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answerInteraction environment envelope action =
  runCommand environment (RespondCommand (interactionResponse envelope action)) >>= interactionFrom

submitInteraction :: AppEnv -> InteractionEnvelope -> Text -> Text -> IO InteractionEnvelope
submitInteraction environment envelope action value =
  runCommand environment (SubmitInteractionTextCommand (interactionResponse envelope action) value) >>= interactionFrom

interactionResponse :: InteractionEnvelope -> Text -> InteractionResponse
interactionResponse envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

interactionFrom :: CommandResult -> IO InteractionEnvelope
interactionFrom = \case
  NextResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other)

ordinaryKinds :: State -> UTCTime -> [SelectableOpportunityKind]
ordinaryKinds state instant = ordinaryKindsFor state instant mainBrickId

ordinaryKindsFor :: State -> UTCTime -> UUIDv7 -> [SelectableOpportunityKind]
ordinaryKindsFor state instant identity =
  case filter ((== identity) . ticketIdentity) (buildForecastWorld state instant) of
    [ticket] -> fmap selectableKind (ticketOpportunities ticket)
    _ -> []

workState :: BrickNature -> State
workState nature =
  emptyState
    { stateBricks = Map.singleton mainBrickId brick
    , stateBrickHandles = Map.singleton (brickHandle brick) mainBrickId
    , stateRetiredBrickHandles = Set.singleton (brickHandle brick)
    }
 where
  brick = mkBrick mainBrickId (Handle "work") "Work" nature Nothing 0

mkBrick :: UUIDv7 -> Handle -> Text -> BrickNature -> Maybe UUIDv7 -> Int -> Brick
mkBrick identity handle title nature parent position =
  Brick identity handle title nature "factory@1" "test" Nothing parent Set.empty position (DeterministicPosition "fixture") BrickActive Idle now testActor (fixtureUuid 900)

applyMutation :: State -> MutationDecision -> IO State
applyMutation state mutation = assertRight (foldM applyEvent state (zipWith persist [stateEventCount state + 1 ..] (mutationDecisionEvents mutation)))

applyEvents :: State -> [EventDraft] -> IO State
applyEvents state events = assertRight (foldM applyEvent state (zipWith persist [stateEventCount state + 1 ..] events))

persist :: Integer -> EventDraft -> PersistedEvent
persist sequenceNumber draft =
  PersistedEvent
    (draftEventId draft)
    (draftCommandId draft)
    sequenceNumber
    0
    (draftActor draft)
    (draftRecordedAt draft)
    (if sequenceNumber == 1 then "GENESIS" else "fixture")
    (draftPreconditionHash draft)
    (draftReplayUUIDs draft)
    (draftPayload draft)

facts :: UTCTime -> Int -> Int -> RuntimeFacts
facts instant base count =
  RuntimeFacts
    instant
    [UUIDAllocation (renderUUIDv7 (fixtureUuid number)) | number <- [base .. base + count - 1]]
    Map.empty
    (FilesystemFacts True True Nothing)
    (TerminalCapabilities False False False 80 24 False)
    []

zoned :: UTCTime -> ZonedInstant
zoned instant = ZonedInstant instant "America/Montevideo"

testActor :: Actor
testActor = Actor "human" "test"

mainBrickId, childId, futureChildId, entityId :: UUIDv7
mainBrickId = fixtureUuid 700
childId = fixtureUuid 701
futureChildId = fixtureUuid 702
entityId = fixtureUuid 2

now :: UTCTime
now = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))

fixtureUuid :: Int -> UUIDv7
fixtureUuid number =
  either (error . show) id $
    uuidV7FromEntropy
      (0x0198f8a34c21 + fromIntegral number)
      (ByteString.replicate 10 (fromIntegral (rem number 251 + 1)))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertLeft :: (Show right) => Either left right -> Assertion
assertLeft value = case value of
  Left _ -> pure ()
  Right result -> assertFailure ("expected failure, got " <> show result)

assertLeftIO :: IO (Either left right) -> Assertion
assertLeftIO action =
  action >>= \case
    Left _ -> pure ()
    Right _ -> assertFailure "expected failure"

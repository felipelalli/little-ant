module Main (main) where

import Control.Exception (finally)
import Control.Monad (foldM)
import Data.Aeson (Object, Value (..), encode, object, toJSON, (.=))
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.Lazy.Char8 as LBS8
import Data.List (find, isInfixOf)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (NominalDiffTime, UTCTime (..), addUTCTime, fromGregorian)
import qualified LittleAnt.V1.Capture as Capture
import LittleAnt.V1.Contract
  (AmbientInputs (..), ContractRegistry (..), DriverResponse (..),
   ObservationInput (..), OperationInput (..), OperationResult (..),
   PlanProbeInput (..), ProbeKey (..), ReferenceInput (..),
   ReferenceSnapshot (..), ResultItem (..),
   decodeAndRunContractRequest, emptyContractRegistry,
   evaluateAssertionOperator, runContractRequest, standardAssertionOperators)
import qualified LittleAnt.V1.Coordination as Coordination
import LittleAnt.V1.Domain
import qualified LittleAnt.V1.Execution as Execution
import LittleAnt.V1.Implementation (contractRegistry)
import qualified LittleAnt.V1.Interaction as Interaction
import qualified LittleAnt.V1.Judgment as Judgment
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..),
   EventBatch (..), KernelError (..), OpaqueId (..), ProposedEvent (..),
   ReplayResult (..), appendSemanticAction, emptyKernelState, kernelArtifact,
   kernelEventBatches, kernelRevision, kernelValue, putKernelArtifact, replayAll)
import LittleAnt.V1.Material
import qualified LittleAnt.V1.Priority as Priority
import qualified LittleAnt.V1.Selection as Selection
import qualified LittleAnt.V1.Standing as Standing
import System.Directory
  (executable, getPermissions, getTemporaryDirectory, removeFile, setPermissions)
import System.IO (hClose, hPutStr, openTempFile)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit
  (Assertion, assertBool, assertFailure, testCase, (@?=))

main :: IO ()
main = defaultMain $ testGroup "v1 contract runner"
  [ kernelTests
  , domainTests
  , executionLifecycleTests
  , standingExecutionTests
  , selectionTests
  , captureTests
  , interactionTests
  , coordinationTests
  , materialTests
  , priorityTests
  , judgmentTests
  , implementationBridgeTests
  , planTests
  , scenarioTests
  , operatorTests
  , rejectionTests
  , protocolTests
  ]

kernelTests :: TestTree
kernelTests = testGroup "v1 action kernel"
  [ testCase "commits one atomic batch and advances revision once" $ do
      accepted <- requireKernelSuccess (appendSemanticAction atomicKernelRequest
        emptyKernelState)
      let state = appendResultState accepted
      kernelRevision state @?= DomainRevision 1
      length (kernelEventBatches state) @?= 1
      length (eventBatchEvents (appendResultBatch accepted)) @?= 2
      kernelValue "first" state @?= Just (String "one")
      kernelValue "second" state @?= Just (toJSON (2 :: Int))
  , testCase "rejects stale and partially invalid actions without state" $ do
      accepted <- requireKernelSuccess (appendSemanticAction atomicKernelRequest
        emptyKernelState)
      let before = appendResultState accepted
          stale = atomicKernelRequest
            { appendSemanticActionId = "test:stale"
            , appendExpectedRevision = DomainRevision 0
            }
      case appendSemanticAction stale before of
        Left (RevisionConflict (DomainRevision 0) (DomainRevision 1)) -> pure ()
        result -> assertFailure ("unexpected stale append result: " <> show result)
      encode before @?= encode (appendResultState accepted)
      let invalid = atomicKernelRequest
            { appendSemanticActionId = "test:invalid-batch"
            , appendProposedEvents =
                [ ProposeValueStored "would-have-been-partial" (Bool True)
                , ProposeValueRemoved "missing"
                ]
            }
      case appendSemanticAction invalid emptyKernelState of
        Left (ValueDoesNotExist "missing") -> pure ()
        result -> assertFailure ("unexpected invalid append result: " <> show result)
      kernelRevision emptyKernelState @?= DomainRevision 0
      kernelValue "would-have-been-partial" emptyKernelState @?= Nothing
  , testCase "keeps bounded interaction artifacts outside the domain clock" $ do
      withCheckpoint <- case putKernelArtifact "surface:terminal"
          (object ["text_buffer" .= ("unsubmitted" :: Text)]) emptyKernelState of
        Left problem -> assertFailure ("artifact update failed: " <> show problem)
        Right next -> pure next
      kernelRevision withCheckpoint @?= DomainRevision 0
      kernelEventBatches withCheckpoint @?= []
      kernelArtifact "surface:terminal" withCheckpoint @?=
        Just (object ["text_buffer" .= ("unsubmitted" :: Text)])
      encode withCheckpoint @?= encode emptyKernelState
  , testCase "allocates opaque creation-derived identities" $ do
      accepted <- requireKernelSuccess (appendSemanticAction
        atomicKernelRequest
          { appendSemanticActionId = "test:opaque-identities"
          , appendProposedEvents =
              [ ProposeEntityCreated "brick"
                  (objectMap ["title" .= ("Repeated title" :: Text)])
              , ProposeEntityCreated "brick"
                  (objectMap ["title" .= ("Repeated title" :: Text)])
              ]
          }
        emptyKernelState)
      case appendResultAllocatedIds accepted of
        [first@(OpaqueId firstText), second@(OpaqueId secondText)] -> do
          assertBool "identities collide" (first /= second)
          assertBool "first identity contains title"
            (not ("Repeated title" `Text.isInfixOf` firstText))
          assertBool "second identity contains title"
            (not ("Repeated title" `Text.isInfixOf` secondText))
        identifiers -> assertFailure ("unexpected identities: " <> show identifiers)
  , testCase "replay is byte-equivalent and adapter-free" $ do
      first <- requireKernelSuccess (appendSemanticAction atomicKernelRequest
        emptyKernelState)
      second <- requireKernelSuccess (appendSemanticAction
        AppendRequest
          { appendExpectedRevision = DomainRevision 1
          , appendSemanticActionId = "test:second-action"
          , appendActorOrOrigin = "human:test"
          , appendOccurredAt = Just "2026-07-27T00:00:01Z"
          , appendProposedEvents = [ProposeValueRemoved "first"]
          }
        (appendResultState first))
      replayed <- case replayAll (kernelEventBatches (appendResultState second)) of
        Left problem -> assertFailure ("replay failed: " <> show problem)
        Right result -> pure result
      encode (replayResultState replayed) @?= encode (appendResultState second)
      replayResultExternalTrace replayed @?= []
  ]

domainTests :: TestTree
domainTests = testGroup "v1 domain model and definition catalog"
  [ testCase "allocates stable opaque identities and preserves text provenance" $ do
      (party, first) <- requireDomainSuccess
        (createParty "Ada" Person domainTestTime emptyDomainState)
      title <- requireDomainSuccess
        (mkCanonicalText "Plan migration" (Just "Planejar migração") Human)
      (brick, second) <- requireDomainSuccess
        (createBrick (ordinaryBrickDraft title standardV1 domainTestTime) first)
      (sameTitle, _) <- requireDomainSuccess
        (createBrick (ordinaryBrickDraft title standardV1 domainTestTime) second)
      partyRevision party @?= EntityRevision 1
      brickRevision brick @?= EntityRevision 1
      brickOriginalTitle brick @?= Just "Planejar migração"
      assertBool "two entity kinds reused an identity"
        (unPartyId (partyId party) /= unBrickId (brickId brick))
      assertBool "equal titles reused an identity" (brickId brick /= brickId sameTitle)
      assertBool "opaque Brick ID contains its title"
        (not (brickTitle brick `Text.isInfixOf` unBrickId (brickId brick)))
  , testCase "increments Party revisions without changing identity" $ do
      (party, first) <- requireDomainSuccess
        (createParty "Ada" Person domainTestTime emptyDomainState)
      (renamed, second) <- requireDomainSuccess
        (renameParty (partyId party) "Ada Lovelace" first)
      (withAlternate, _) <- requireDomainSuccess
        (addAlternatePartyLabel (partyId party) "A. Lovelace" second)
      partyId renamed @?= partyId party
      partyAlternateLabels renamed @?= ["Ada"]
      partyRevision withAlternate @?= EntityRevision 3
      case addAlternatePartyLabel (partyId party) "Ada Lovelace" second of
        Left (AlternateLabelMatchesCurrent _) -> pure ()
        result -> assertFailure ("unexpected alternate-label result: " <> show result)
  , testCase "enforces parent, focus, phase, entry-owner, and terminal constraints" $ do
      title <- requireDomainSuccess
        (mkCanonicalText "Ordinary work" Nothing Human)
      (ordinary, first) <- requireDomainSuccess
        (createBrick (ordinaryBrickDraft title standardV1 domainTestTime)
          emptyDomainState)
      case setBrickParent (brickId ordinary) (Just (brickId ordinary)) first of
        Left (InvalidRelationship _) -> pure ()
        result -> assertFailure ("self-parent unexpectedly accepted: " <> show result)
      entryLabel <- requireDomainSuccess
        (mkCanonicalText "Unsupported entry" Nothing Human)
      case createListEntry (ListEntryDraft (brickId ordinary) entryLabel Nothing
          Nothing domainTestTime) first of
        Left (InvalidRelationship _) -> pure ()
        result -> assertFailure ("unsupported ListEntry unexpectedly accepted: "
          <> show result)
      let phaseDraft = (ordinaryBrickDraft title collectionV1 domainTestTime)
            { brickDraftPhase = Just Idea
            , brickDraftPhaseAuthority = Just Human
            }
      case createBrick phaseDraft first of
        Left (InvalidRelationship _) -> pure ()
        result -> assertFailure ("disabled phase unexpectedly accepted: " <> show result)
      (_, second) <- requireDomainSuccess
        (setBrickWorkState (brickId ordinary) Wip first)
      (_, third) <- requireDomainSuccess
        (focusBrick (Just (brickId ordinary)) domainTestTime second)
      (terminal, fourth) <- requireDomainSuccess
        (transitionBrickStatus (brickId ordinary) MarkDone domainTestTime third)
      brickWorkState terminal @?= Idle
      focusRegisterCurrent (domainFocusRegister fourth) @?= Nothing
      case setBrickWorkState (brickId ordinary) Wip fourth of
        Left (InvalidTransition _) -> pure ()
        result -> assertFailure ("terminal Brick unexpectedly entered WIP: "
          <> show result)
  , testCase "models ListEntry shape and one singleton focus register" $ do
      firstTitle <- requireDomainSuccess
        (mkCanonicalText "Packing" Nothing Human)
      (owner, first) <- requireDomainSuccess
        (createBrick (ordinaryBrickDraft firstTitle finiteChecklistV1 domainTestTime)
          emptyDomainState)
      secondTitle <- requireDomainSuccess
        (mkCanonicalText "Other work" Nothing Human)
      (other, second) <- requireDomainSuccess
        (createBrick (ordinaryBrickDraft secondTitle standardV1 domainTestTime) first)
      label <- requireDomainSuccess
        (mkCanonicalText "Passport" (Just "Passaporte") Human)
      (entry, third) <- requireDomainSuccess
        (createListEntry (ListEntryDraft (brickId owner) label (Just 1) Nothing
          domainTestTime) second)
      (_, fourth) <- requireDomainSuccess
        (focusBrick (Just (brickId owner)) domainTestTime third)
      (focus, final) <- requireDomainSuccess
        (focusBrick (Just (brickId other)) domainTestTime fourth)
      listEntryOriginalLabel entry @?= Just "Passaporte"
      listEntryRevision entry @?= EntityRevision 1
      focusRegisterCurrent focus @?= Just (brickId other)
      domainFocusRegister final @?= focus
      requireDomainSuccess (validateDomainState final)
  , testCase "ships bounded searchable built-in definitions" $ do
      length (behaviorVersions initialDefinitionCatalog) @?= 8
      length (templateVersions initialDefinitionCatalog) @?= 8
      behaviorPage <- requireDomainSuccess
        (findBehaviors "core" Nothing 3 initialDefinitionCatalog)
      length behaviorPage @?= 3
      templatePage <- requireDomainSuccess
        (findTemplates "shopping" (Just "checklists") Nothing 5
          initialDefinitionCatalog)
      map templateId templatePage @?= ["standard/grocery_list"]
      case findTemplates "" Nothing Nothing 51 initialDefinitionCatalog of
        Left (InvalidPageSize 51) -> pure ()
        result -> assertFailure ("unbounded catalog result: " <> show result)
  , testCase "publishes immutable behavior versions and reuses equivalents" $ do
      let firstConfiguration = BehaviorConfiguration BrickFocus Standing False
            False False Disabled Applicable NoRepetition
          firstDraft = BehaviorDraft "personal/deep_work" "personal/test" 1
            firstConfiguration
      (firstResult, firstCatalog) <- requireDomainSuccess
        (publishPersonalBehavior firstDraft initialDefinitionCatalog)
      first <- case firstResult of
        Published value -> pure value
        result -> assertFailure ("unexpected publication result: " <> show result)
      let secondDraft = firstDraft
            { behaviorDraftVersion = 2
            , behaviorDraftConfiguration = BehaviorConfiguration BrickFocus Finite
                False False False Applicable Disabled NoRepetition
            }
      (secondResult, secondCatalog) <- requireDomainSuccess
        (publishPersonalBehavior secondDraft firstCatalog)
      second <- case secondResult of
        Published value -> pure value
        result -> assertFailure ("unexpected second publication: " <> show result)
      behaviorVersion first @?= 1
      behaviorVersion second @?= 2
      assertBool "first version disappeared"
        (first `elem` behaviorVersions secondCatalog)
      let duplicateDraft = BehaviorDraft "personal/duplicate" "personal/test" 99
            (behaviorConfiguration standardV1)
      (duplicateResult, unchanged) <- requireDomainSuccess
        (publishPersonalBehavior duplicateDraft secondCatalog)
      duplicateResult @?= ExistingDefinitionSelected standardV1
      unchanged @?= secondCatalog
  , testCase "publishes immutable templates and copies one version on expansion" $ do
      let firstDraft = TemplateDraft
            { templateDraftId = "personal/deep_work_template"
            , templateDraftNamespace = "personal/test"
            , templateDraftVersion = 1
            , templateDraftDisplayName = "Deep work"
            , templateDraftCategory = "focus"
            , templateDraftPurpose = "Create focused work."
            , templateDraftSearchTerms = ["focus"]
            , templateDraftBehavior = standardV1
            , templateDraftDefaultTitle = Just "Focus deeply"
            , templateDraftDefaultDescription = Nothing
            }
      (first, firstCatalog) <- requireDomainSuccess
        (publishPersonalTemplate firstDraft initialDefinitionCatalog)
      (second, secondCatalog) <- requireDomainSuccess
        (publishPersonalTemplate
          (firstDraft {templateDraftVersion = 2,
            templateDraftDefaultTitle = Just "Focus deeply today"}) firstCatalog)
      assertBool "published first template was mutated"
        (first `elem` templateVersions secondCatalog)
      templateVersion second @?= 2
      (brick, _) <- requireDomainSuccess
        (instantiateTemplate first Nothing domainTestTime
          (emptyDomainState {domainCatalog = secondCatalog}))
      brickTitle brick @?= "Focus deeply"
      brickBehavior brick @?= standardV1
  ]

executionLifecycleTests :: TestTree
executionLifecycleTests = testGroup "v1 Brick metadata, focus, lifecycle, and subtree"
  [ testCase "mutates metadata and derives nearest/strongest inherited values" $ do
      parentTitle <- requireDomainSuccess (mkCanonicalText "Parent" Nothing Human)
      let parentDraft = (ordinaryBrickDraft parentTitle projectV1 domainTestTime)
            { brickDraftContext = Just "office"
            , brickDraftMode = Just Digital
            , brickDraftDeadline = Just (addUTCTime 100 domainTestTime)
            }
      (parent, first) <- requireDomainSuccess
        (createBrick parentDraft emptyDomainState)
      childTitle <- requireDomainSuccess (mkCanonicalText "Child" Nothing Human)
      (child, second) <- requireDomainSuccess (createBrick
        ((ordinaryBrickDraft childTitle standardV1 domainTestTime)
          { brickDraftParent = Just (brickId parent)
          , brickDraftDeadline = Just (addUTCTime 200 domainTestTime)
          }) first)
      (renamed, third) <- requireDomainSuccess
        (renameBrick (brickId child) "Renamed child" Ai second)
      (described, fourth) <- requireDomainSuccess
        (describeBrick (brickId child) " leading is a valid String" third)
      (_, fifth) <- requireDomainSuccess
        (setBrickContext (brickId child) "home" fourth)
      (_, sixth) <- requireDomainSuccess
        (clearBrickContext (brickId child) fifth)
      context <- requireDomainSuccess (effectiveContext sixth (brickId child))
      deadline <- requireDomainSuccess (effectiveDeadline sixth (brickId child))
      fingerprint <- requireDomainSuccess
        (effectiveDateRevision sixth (brickId child))
      brickId renamed @?= brickId child
      brickTitleAuthority renamed @?= Ai
      brickDescriptionRevision described @?= 1
      brickDescription described @?= Just " leading is a valid String"
      context @?= Just "office"
      deadline @?= Just (addUTCTime 100 domainTestTime)
      assertBool "effective date fingerprint is empty" (not (Text.null fingerprint))
      assertBool "metadata revisions did not advance atomically"
        (brickRevision described > brickRevision renamed)
  , testCase "rejects phase clearing when behavior disables phase" $ do
      title <- requireDomainSuccess (mkCanonicalText "Collection" Nothing Human)
      (collection, state) <- requireDomainSuccess (createBrick
        (ordinaryBrickDraft title collectionV1 domainTestTime) emptyDomainState)
      case clearBrickPhase (brickId collection) state of
        Left (InvalidRelationship "behavior disables phase") -> pure ()
        result -> assertFailure
          ("phase-disabled Brick accepted phase clear: " <> show result)
  , testCase "keeps singleton focus while multiple Bricks remain WIP" $ do
      (first, stateOne) <- createUnitExecutionBrick "First" standardV1 Nothing
        Execution.emptyExecutionState
      (second, stateTwo) <- createUnitExecutionBrick "Second" standardV1 Nothing
        stateOne
      focusedFirst <- requireExecutionSuccess
        (Execution.focusExecutionBrick (brickId first) domainTestTime stateTwo)
      focusedSecond <- requireExecutionSuccess
        (Execution.focusExecutionBrick (brickId second)
          (addUTCTime 1 domainTestTime) focusedFirst)
      refocusedFirst <- requireExecutionSuccess
        (Execution.focusExecutionBrick (brickId first)
          (addUTCTime 2 domainTestTime) focusedSecond)
      Execution.activeHumanWipCount refocusedFirst @?= 2
      focusRegisterCurrent (domainFocusRegister
        (Execution.executionStateDomain refocusedFirst)) @?= Just (brickId first)
      delegated <- requireExecutionSuccess
        (Execution.delegateExecutionBrick (brickId second)
          (addUTCTime 3 domainTestTime) refocusedFirst)
      Execution.activeHumanWipCount delegated @?= 1
  , testCase "closes whole subtrees atomically without cascading parent review" $ do
      (root, first) <- createUnitExecutionBrick "Root" projectV1 Nothing
        Execution.emptyExecutionState
      (child, second) <- createUnitExecutionBrick "Child" projectV1
        (Just (brickId root)) first
      (leaf, third) <- createUnitExecutionBrick "Leaf" standardV1
        (Just (brickId child)) second
      case Execution.completeExecutionBrick (brickId root) domainTestTime third of
        Left _ -> pure ()
        Right _ -> assertFailure "parent with active descendants completed directly"
      closed <- requireExecutionSuccess
        (Execution.closeExecutionSubtree (brickId root) Done domainTestTime third)
      map (\identifier -> brickStatus <$> Map.lookup identifier
          (domainBricks (Execution.executionStateDomain closed)))
        [brickId root, brickId child, brickId leaf] @?=
          replicate 3 (Just Done)
      Execution.executionStateRevision closed @?=
        Execution.executionStateRevision third + 1
      length (Execution.executionStateHistory closed) @?=
        fromIntegral (Execution.executionStateRevision closed)
  , testCase "supersedes with child transfer and resolves displaced priority probes" $ do
      (source, first) <- createUnitExecutionBrick "Source" projectV1 Nothing
        Execution.emptyExecutionState
      (replacement, second) <- createUnitExecutionBrick "Replacement" projectV1
        Nothing first
      (childA, third) <- createUnitExecutionBrick "Child A" standardV1
        (Just (brickId source)) second
      (childB, fourth) <- createUnitExecutionBrick "Child B" standardV1
        (Just (brickId source)) third
      case Execution.supersedeExecutionBrickWithChildren (brickId source)
          (brickId replacement) [brickId childA] Nothing "partial"
          domainTestTime fourth of
        Left _ -> pure ()
        Right _ -> assertFailure "partial child transfer was accepted"
      oldScope <- requireExactlyOneScope (Just (brickId source))
        (Execution.executionStatePriority fourth)
      (probe, priorityWithProbe) <- requirePrioritySuccess
        (Priority.openPriorityProbe (Priority.priorityScopeId oldScope)
          (brickId childA) (brickId childB) Priority.Discovery "before transfer"
          domainTestTime (Execution.executionStatePriority fourth))
      let withProbe = fourth
            {Execution.executionStatePriority = priorityWithProbe}
      (insertions, transferred) <- requireExecutionSuccess
        (Execution.supersedeExecutionBrickWithChildren (brickId source)
          (brickId replacement) [brickId childA, brickId childB]
          (Just "replacement scope") "complete" domainTestTime withProbe)
      length insertions @?= 2
      map Priority.priorityInsertionStatus insertions @?=
        replicate 2 Priority.InsertionDeferred
      let domain = Execution.executionStateDomain transferred
      fmap brickStatus (Map.lookup (brickId source) (domainBricks domain)) @?=
        Just Superseded
      fmap brickSupersededBy (Map.lookup (brickId source) (domainBricks domain)) @?=
        Just (Just (brickId replacement))
      map (fmap brickParent . (`Map.lookup` domainBricks domain))
        [brickId childA, brickId childB] @?=
          replicate 2 (Just (Just (brickId replacement)))
      let retainedProbe = Map.lookup (Priority.judgmentProbeId probe)
            (Priority.priorityStateProbes
              (Execution.executionStatePriority transferred))
      fmap Priority.judgmentProbeStatus retainedProbe @?=
        Just Priority.ProbeResolved
      fmap Priority.judgmentProbeResolvedAt retainedProbe @?=
        Just (Just domainTestTime)
  , testCase "moves subtree IDs and resolves displaced old-scope probes" $ do
      (firstParent, first) <- createUnitExecutionBrick "First parent" projectV1
        Nothing Execution.emptyExecutionState
      (secondParent, second) <- createUnitExecutionBrick "Second parent" projectV1
        Nothing first
      (movedRoot, third) <- createUnitExecutionBrick "Moved root" projectV1
        (Just (brickId firstParent)) second
      (oldSibling, fourth) <- createUnitExecutionBrick "Old sibling" standardV1
        (Just (brickId firstParent)) third
      (_, fifth) <- createUnitExecutionBrick "Target sibling" standardV1
        (Just (brickId secondParent)) fourth
      (grandchild, sixth) <- createUnitExecutionBrick "Grandchild" standardV1
        (Just (brickId movedRoot)) fifth
      oldScope <- requireExactlyOneScope (Just (brickId firstParent))
        (Execution.executionStatePriority sixth)
      (_, _, priorityWithEvidence) <- requirePrioritySuccess
        (Priority.recordPriorityJudgment (Priority.priorityScopeId oldScope)
          (brickId movedRoot) (brickId oldSibling) Human Nothing domainTestTime
          (Execution.executionStatePriority sixth))
      (probe, priorityWithProbe) <- requirePrioritySuccess
        (Priority.openPriorityProbe (Priority.priorityScopeId oldScope)
          (brickId movedRoot) (brickId oldSibling) Priority.Validation
          "before move" domainTestTime priorityWithEvidence)
      let withEvidence = sixth
            {Execution.executionStatePriority = priorityWithProbe}
      (insertion, moved) <- requireExecutionSuccess
        (Execution.moveExecutionSubtree (brickId movedRoot)
          (Just (brickId secondParent)) "unit-move" domainTestTime withEvidence)
      Priority.priorityInsertionStatus insertion @?= Priority.InsertionDeferred
      let domain = Execution.executionStateDomain moved
      fmap brickParent (Map.lookup (brickId movedRoot) (domainBricks domain)) @?=
        Just (Just (brickId secondParent))
      fmap brickParent (Map.lookup (brickId grandchild) (domainBricks domain)) @?=
        Just (Just (brickId movedRoot))
      assertBool "old-scope evidence remained current"
        (all (not . Priority.priorityJudgmentApplicable)
          (Map.elems (Priority.priorityStateJudgments
            (Execution.executionStatePriority moved))))
      let retainedProbe = Map.lookup (Priority.judgmentProbeId probe)
            (Priority.priorityStateProbes (Execution.executionStatePriority moved))
      fmap Priority.judgmentProbeStatus retainedProbe @?=
        Just Priority.ProbeResolved
      fmap Priority.judgmentProbeResolvedAt retainedProbe @?=
        Just (Just domainTestTime)
      case Execution.moveExecutionSubtree (brickId secondParent)
          (Just (brickId grandchild)) "cycle" domainTestTime moved of
        Left _ -> pure ()
        Right _ -> assertFailure "composition cycle was accepted"
  , testCase "retires but retains impact evidence when a root becomes a child" $ do
      (movedRoot, first) <- createUnitExecutionBrick "Impact root" projectV1
        Nothing Execution.emptyExecutionState
      (newParent, second) <- createUnitExecutionBrick "Impact parent" projectV1
        Nothing first
      (movedAssessment, _, firstImpact) <- requireJudgmentSuccess
        (Judgment.classifyImpact (brickId movedRoot) Judgment.HighImpact
          Judgment.Supported Human (Just "before nesting") domainTestTime
          (Execution.executionStateJudgment second))
      (_, _, secondImpact) <- requireJudgmentSuccess
        (Judgment.classifyImpact (brickId newParent) Judgment.LowImpact
          Judgment.Supported Human (Just "target root") domainTestTime firstImpact)
      (comparison, _, withImpact) <- requireJudgmentSuccess
        (Judgment.compareImpact (brickId movedRoot) (brickId newParent)
          Judgment.RelativelyMore Human (Just "before nesting") domainTestTime
          secondImpact)
      let before = second {Execution.executionStateJudgment = withImpact}
          assessmentCount = Map.size
            (Judgment.judgmentStateImpactAssessments withImpact)
          comparisonCount = Map.size
            (Judgment.judgmentStateImpactComparisons withImpact)
      (_, moved) <- requireExecutionSuccess (Execution.moveExecutionSubtree
        (brickId movedRoot) (Just (brickId newParent)) "root-to-child"
        domainTestTime before)
      let judgment = Execution.executionStateJudgment moved
      fmap Judgment.impactAssessmentApplicable
        (Map.lookup (Judgment.impactAssessmentId movedAssessment)
          (Judgment.judgmentStateImpactAssessments judgment)) @?= Just False
      fmap Judgment.impactComparisonApplicable
        (Map.lookup (Judgment.impactComparisonId comparison)
          (Judgment.judgmentStateImpactComparisons judgment)) @?= Just False
      Map.size (Judgment.judgmentStateImpactAssessments judgment) @?=
        assessmentCount
      Map.size (Judgment.judgmentStateImpactComparisons judgment) @?=
        comparisonCount
      fmap Judgment.judgmentBrickParent
        (Map.lookup (brickId movedRoot) (Judgment.judgmentStateBricks judgment)) @?=
          Just (Just (brickId newParent))
      Execution.executionStateRevision moved @?=
        Execution.executionStateRevision before + 1
  ]

standingExecutionTests :: TestTree
standingExecutionTests = testGroup "standing execution and recurrence"
  [ testCase "keeps one running occurrence and records honest outcomes" $ do
      (owner, first) <- createUnitStandingBrick "Standing checklist"
        standingChecklistV1 Standing.emptyStandingState
      (running, second) <- requireStandingSuccess
        (Standing.startStandingExecution (brickId owner) domainTestTime first)
      Standing.executionOccurrenceStartedAt running @?= Just domainTestTime
      case Standing.startStandingExecution (brickId owner) domainTestTime second of
        Left _ -> pure ()
        Right _ -> assertFailure "second running occurrence was accepted"
      (finished, third) <- requireStandingSuccess
        (Standing.finishStandingExecution (Standing.executionOccurrenceId running)
          Standing.OutcomePartial (Just "some work remains")
          (addUTCTime 1 domainTestTime) second)
      Standing.executionOccurrenceStatus finished @?= Standing.ExecutionFinished
      Standing.executionOccurrenceOutcome finished @?= Just Standing.OutcomePartial
      let ownerAfter = lookupStandingBrick (brickId owner) third
      fmap brickStatus ownerAfter @?= Just Active
      fmap brickWorkState ownerAfter @?= Just Idle
      case Standing.finishStandingExecution (Standing.executionOccurrenceId running)
          Standing.OutcomeDone Nothing (addUTCTime 2 domainTestTime) third of
        Left _ -> pure ()
        Right _ -> assertFailure "terminal occurrence transitioned twice"
  , testCase "chooses repeat jitter deterministically and reuses its Brick" $ do
      (repeatable, first) <- createUnitStandingBrick "Read again" repeatableV1
        Standing.emptyStandingState
      (running, second) <- requireStandingSuccess
        (Standing.startStandingExecution (brickId repeatable) domainTestTime first)
      (_, evidence, third) <- requireStandingSuccess
        (Standing.finishRepeatableAndSchedule
          (Standing.executionOccurrenceId running) (Just "annotated")
          "P6M" "P3M" "repeat-seed" domainTestTime second)
      replayed <- requireStandingSuccess
        (Standing.deterministicRepeatDate domainTestTime "P6M" "P3M" "repeat-seed")
      replayed @?= (Standing.repeatScheduleSelectedMonths evidence,
        Standing.repeatScheduleNotBefore evidence)
      assertBool "selected jitter escaped range"
        (Standing.repeatScheduleSelectedMonths evidence >= 3
          && Standing.repeatScheduleSelectedMonths evidence <= 9)
      let sameBrick = lookupStandingBrick (brickId repeatable) third
      fmap brickId sameBrick @?= Just (brickId repeatable)
      fmap brickNotBefore sameBrick @?= Just
        (Just (Standing.repeatScheduleNotBefore evidence))
  , testCase "revises recurrence without replacing identity or history" $ do
      (practice, first) <- createUnitStandingBrick "Swim" practiceV1
        Standing.emptyStandingState
      (rule, second) <- requireStandingSuccess (Standing.configureRecurrence
        (brickId practice) Standing.PracticeRecurrence "2 times per ISO week"
        "UTC" domainTestTime domainTestTime first)
      (_, opportunities, third) <- requireStandingSuccess
        (Standing.advanceSchedules domainTestTime second)
      length opportunities @?= 2
      (revision, fourth) <- requireStandingSuccess (Standing.reviseRecurrence
        (Standing.recurrenceRuleId rule) "2 times per ISO week" "UTC"
        (addUTCTime standingWeek domainTestTime) "new pool" Human
        domainTestTime third)
      Standing.recurrenceRevisionRule revision @?= Standing.recurrenceRuleId rule
      Map.size (Standing.standingStatePracticeOpportunities fourth) @?= 2
      Map.size (Standing.standingStateRecurrenceRevisions fourth) @?= 1
  , testCase "releases one positioned obligation per period idempotently" $ do
      (owner, first) <- createUnitStandingBrick "Pay electricity bill"
        recurringObligationV1 Standing.emptyStandingState
      (rule, second) <- requireStandingSuccess (Standing.configureRecurrence
        (brickId owner) Standing.ObligationRecurrence "monthly on day 1" "UTC"
        domainTestTime domainTestTime first)
      (released, _, third) <- requireStandingSuccess
        (Standing.advanceSchedules domainTestTime second)
      length released @?= 1
      (_, _, fourth) <- requireStandingSuccess
        (Standing.advanceSchedules domainTestTime third)
      length (Standing.obligationOccurrencesFor (Standing.recurrenceRuleId rule)
        Nothing fourth) @?= 1
      occurrence <- case released of
        [value] -> pure value
        values -> assertFailure ("unexpected obligations: " <> show values)
      fmap brickParent (lookupStandingBrick
        (Standing.obligationOccurrenceBrick occurrence) fourth) @?=
          Just (Just (brickId owner))
      let priority = Execution.executionStatePriority
            (Coordination.coordinationStateExecution
              (Standing.standingStateCoordination fourth))
      item <- requirePrioritySuccess (Priority.priorityViewItem priority
        (Standing.obligationOccurrenceBrick occurrence))
      Priority.priorityViewItemProvisional item @?= True
      completed <- requireStandingSuccess (Standing.completeStandingBrick
        (Standing.obligationOccurrenceBrick occurrence) (Just "paid")
        "test:paid" domainTestTime fourth)
      fmap brickStatus (lookupStandingBrick (brickId owner) completed) @?= Just Active
  , testCase "derives practice marks and excludes blocked windows from failures" $ do
      (practice, first) <- createUnitStandingBrick "Swim twice per week" practiceV1
        Standing.emptyStandingState
      (rule, second) <- requireStandingSuccess (Standing.configureRecurrence
        (brickId practice) Standing.PracticeRecurrence "2 times per ISO week"
        "UTC" domainTestTime domainTestTime first)
      (_, opportunities, third) <- requireStandingSuccess
        (Standing.advanceSchedules domainTestTime second)
      (firstOpportunity, secondOpportunity) <- case opportunities of
        [firstValue, secondValue] -> pure (firstValue, secondValue)
        values -> assertFailure ("unexpected practice opportunities: " <> show values)
      (_, directExecution, fourth) <- requireStandingSuccess
        (Standing.completePracticeOpportunity
          (Standing.practiceOpportunityId firstOpportunity) (Just "morning")
          domainTestTime third)
      Standing.executionOccurrenceStartedAt directExecution @?= Nothing
      (_, fifth) <- requireStandingSuccess (Standing.abandonPracticeOpportunity
        (Standing.practiceOpportunityId secondOpportunity) (Just "cold")
        domainTestTime fourth)
      (blocker, sixth) <- createUnitStandingBrick "Find pool" standardV1 fifth
      blocked <- requireStandingSuccess (Standing.addStandingDependency
        (brickId practice) (brickId blocker) domainTestTime sixth)
      (_, blockedOpportunities, seventh) <- requireStandingSuccess
        (Standing.advanceSchedules (addUTCTime standingWeek domainTestTime) blocked)
      map Standing.practiceOpportunityStatus blockedOpportunities @?=
        replicate 2 Standing.OpportunityNotApplicable
      history <- requireStandingSuccess (Standing.practiceHistory
        (Standing.recurrenceRuleId rule) Nothing 20 seventh)
      Standing.practiceHistoryMarks history @?= ["x", "-", "n/a", "n/a"]
      Standing.practiceHistoryNotDoneCount history @?= 1
  , testCase "releases triggers idempotently and consumes at most one" $ do
      (source, first) <- createUnitStandingBrick "Have lunch" standingChecklistV1
        Standing.emptyStandingState
      (target, second) <- createUnitStandingBrick "Brush teeth" practiceV1 first
      (trigger, third) <- requireStandingSuccess (Standing.configureOpportunityTrigger
        (brickId source) (brickId target) domainTestTime second)
      (sourceRun, fourth) <- requireStandingSuccess
        (Standing.startStandingExecution (brickId source) domainTestTime third)
      (_, fifth) <- requireStandingSuccess (Standing.finishStandingExecution
        (Standing.executionOccurrenceId sourceRun) Standing.OutcomeDone Nothing
        (addUTCTime 1 domainTestTime) fourth)
      Map.size (Standing.standingStateTriggeredOpportunities fifth) @?= 1
      let sourceEventId = "execution-finished:"
            <> Standing.unExecutionOccurrenceId
              (Standing.executionOccurrenceId sourceRun)
      retried <- requireStandingSuccess (Standing.releaseTriggeredOpportunities
        (brickId source) sourceEventId (addUTCTime 1 domainTestTime) fifth)
      Map.size (Standing.standingStateTriggeredOpportunities retried) @?= 1
      (targetRun, sixth) <- requireStandingSuccess
        (Standing.startStandingExecution (brickId target)
          (addUTCTime 2 domainTestTime) retried)
      (_, seventh) <- requireStandingSuccess (Standing.finishStandingExecution
        (Standing.executionOccurrenceId targetRun) Standing.OutcomeDone Nothing
        (addUTCTime 3 domainTestTime) sixth)
      length [opportunity | opportunity <- Map.elems
        (Standing.standingStateTriggeredOpportunities seventh),
        Standing.triggeredOpportunityConsumedAt opportunity /= Nothing] @?= 1
      retired <- requireStandingSuccess (Standing.retireStandingTarget
        (brickId target) (addUTCTime 4 domainTestTime) seventh)
      fmap Standing.opportunityTriggerStatus
        (Map.lookup (Standing.opportunityTriggerId trigger)
          (Standing.standingStateOpportunityTriggers retired)) @?=
            Just Standing.TriggerRetired
  , testCase "retires recurrence, opportunities, and triggers for every terminal status" $
      mapM_ assertStandingTerminalTransition [Done, Dropped, Superseded]
  , testCase "retires mechanics for done and dropped standing subtrees" $
      mapM_ assertStandingTerminalSubtree [Done, Dropped]
  , testCase "retires source mechanics when superseding with child transfer" $ do
      (source, first) <- createUnitStandingBrick "Old recurring owner"
        recurringObligationV1 Standing.emptyStandingState
      (replacement, second) <- createUnitStandingBrick "New recurring owner"
        recurringObligationV1 first
      (child, third) <- createUnitStandingChild "Transferred occurrence" standardV1
        (brickId source) second
      (practiceTarget, fourth) <- createUnitStandingBrick "Practice target" practiceV1
        third
      (rule, fifth) <- requireStandingSuccess (Standing.configureRecurrence
        (brickId source) Standing.ObligationRecurrence "monthly on day 1" "UTC"
        (addUTCTime standingWeek domainTestTime) domainTestTime fourth)
      (trigger, sixth) <- requireStandingSuccess
        (Standing.configureOpportunityTrigger (brickId source) (brickId practiceTarget)
          domainTestTime fifth)
      (_, terminal) <- requireStandingSuccess
        (Standing.supersedeStandingBrickWithChildren (brickId source)
          (brickId replacement) [brickId child] (Just "replace series")
          "transfer-child" domainTestTime sixth)
      fmap brickStatus (lookupStandingBrick (brickId source) terminal) @?=
        Just Superseded
      fmap brickParent (lookupStandingBrick (brickId child) terminal) @?=
        Just (Just (brickId replacement))
      fmap brickStatus (lookupStandingBrick (brickId child) terminal) @?= Just Active
      assertTerminalStandingMechanics Superseded source rule [] [trigger]
        domainTestTime terminal
  ]

selectionTests :: TestTree
selectionTests = testGroup "v1 proposals, forecast, next, and skip pressure"
  [ testCase "builds a read-only explained forecast and replays simulation" $ do
      (bricks, context) <- selectionFixture
        [("Critical", standardV1), ("Guide", standardV1),
         ("Background", standardV1)]
      beforeContext <- pure context
      forecast <- requireSelectionSuccess (Selection.buildForecast domainTestTime 9
        context Selection.emptySelectionState)
      context @?= beforeContext
      length (Selection.forecastViewItems forecast) @?= 3
      assertBool "forecast omitted positive explained mass" (all
        (\item -> Selection.forecastItemWeight item > 0
          && Selection.forecastItemProbability item > 0
          && not (null (Selection.forecastItemReasons item)))
        (Selection.forecastViewItems forecast))
      first <- requireSelectionSuccess (Selection.simulateReplaySafeDraws
        "unit-selection-seed" 10000 forecast)
      second <- requireSelectionSuccess (Selection.simulateReplaySafeDraws
        "unit-selection-seed" 10000 forecast)
      first @?= second
      assertBool "simulation escaped declared tolerance" (all
        (\metric -> abs (Selection.simulationCandidateObservedFrequency metric
          - Selection.simulationCandidateForecastProbability metric) <= 0.02)
        (Selection.simulationMetricsPerCandidate first))
      assertBool "fixture identity disappeared" (all (\brick ->
        Selection.forecastItemForBrick (brickId brick) forecast /= Nothing) bricks)
  , testCase "returns valid focus first and otherwise draws one forecast item" $ do
      (bricks, context) <- selectionFixture
        [("Focus me", standardV1), ("Alternate", standardV1)]
      (focusBrickValue, _) <- requireExactlyTwo "selection focus Bricks" bricks
      focused <- focusSelectionContext (brickId focusBrickValue) context
      (focusedDraw, focusedState) <- requireSelectionSuccess (Selection.requestNext
        domainTestTime 3 "focus-seed" focused Selection.emptySelectionState)
      Selection.nextDrawSelectedBrick focusedDraw @?= Just (brickId focusBrickValue)
      Selection.nextDrawSelectedProposal focusedDraw @?= Nothing
      Selection.nextDrawReasons focusedDraw @?= ["current focus remains valid"]
      requireSelectionSuccess
        (Selection.validateSelectionState focused focusedState)
      assertBool "canonical draw persisted its derived source forecast"
        (not ("source_forecast" `isInfixOf`
          LBS8.unpack (encode focusedState)))
      (ordinary, _) <- requireSelectionSuccess (Selection.requestNext domainTestTime
        3 "ordinary-seed" context Selection.emptySelectionState)
      assertBool "ordinary next selected zero or two kinds"
        ((Selection.nextDrawSelectedBrick ordinary /= Nothing)
          /= (Selection.nextDrawSelectedProposal ordinary /= Nothing))
  , testCase "retains repeated skips, cools immediately, and restores pressure" $ do
      (bricks, context) <- selectionFixture
        [("Taxes", standardV1), ("Tidy", standardV1)]
      (taxes, _) <- requireExactlyTwo "selection skip Bricks" bricks
      baseline <- requireSelectionSuccess (Selection.buildForecast domainTestTime 1
        context Selection.emptySelectionState)
      baselineItem <- requireSelectionForecastItem (brickId taxes) baseline
      (_, firstCooldown, first) <- requireSelectionSuccess
        (Selection.recordServedSkip (brickId taxes) Selection.SkipVague
          (Just "find statements") domainTestTime context Selection.emptySelectionState)
      Selection.selectionCooldownRecentSkipCount firstCooldown @?= 1
      during <- requireSelectionSuccess (Selection.buildForecast
        (addUTCTime 1800 domainTestTime) 1 context first)
      duringItem <- requireSelectionForecastItem (brickId taxes) during
      assertBool "cooldown did not lower probability"
        (Selection.forecastItemProbability duringItem
          < Selection.forecastItemProbability baselineItem)
      (_, repeatedCooldown, repeated) <- requireSelectionSuccess
        (Selection.recordServedSkip (brickId taxes) Selection.SkipVague Nothing
          (addUTCTime 7201 domainTestTime) context first)
      Selection.selectionCooldownRecentSkipCount repeatedCooldown @?= 2
      after <- requireSelectionSuccess (Selection.buildForecast
        (addUTCTime 7200 domainTestTime) 1 context first)
      afterItem <- requireSelectionForecastItem (brickId taxes) after
      assertBool "expired cooldown did not restore retained pressure"
        ("retained served-skip pressure" `elem`
          Selection.forecastItemReasons afterItem)
      requireSelectionSuccess (Selection.validateSelectionState context repeated)
  , testCase "derives practice review and blocker unlock pressure" $ do
      (bricks, context) <- selectionFixture
        [("Swim", practiceV1), ("Find pool", standardV1)]
      (practice, blocker) <- requireExactlyTwo "selection practice Bricks" bricks
      blockedStanding <- requireStandingSuccess (Standing.addStandingDependency
        (brickId practice) (brickId blocker) domainTestTime
        (Selection.selectionContextStanding context))
      let blocked = context {Selection.selectionContextStanding = blockedStanding}
      forecast <- requireSelectionSuccess (Selection.buildForecast domainTestTime 2
        blocked Selection.emptySelectionState)
      blockerItem <- requireSelectionForecastItem (brickId blocker) forecast
      assertBool "blocker lacks practice unlock explanation"
        ("unlocks important practice" `elem` Selection.forecastItemReasons blockerItem)
      (_, _, first) <- requireSelectionSuccess (Selection.recordServedSkip
        (brickId practice) Selection.SkipHard Nothing domainTestTime context
        Selection.emptySelectionState)
      (_, _, second) <- requireSelectionSuccess (Selection.recordServedSkip
        (brickId practice) Selection.SkipHard Nothing
        (addUTCTime 1 domainTestTime) context first)
      (_, _, third) <- requireSelectionSuccess (Selection.recordServedSkip
        (brickId practice) Selection.SkipHard Nothing
        (addUTCTime 2 domainTestTime) context second)
      (_, proposed) <- requireSelectionSuccess (Selection.advanceSelection
        (addUTCTime 2 domainTestTime) context third)
      assertBool "practice review was not derived" (any
        ((== Selection.PracticeReview) . Selection.proposalKind)
        (Map.elems (Selection.selectionStateProposals proposed)))
  , testCase "resolves forecast checkpoint references from real state" $
      assertResponsePassed
        (runContractRequest contractRegistry selectionForecastReferenceScenario)
        ["real-forecast-reference"]
  , testCase "keeps build, simulation, and next forecast orders noncanonical" $
      assertResponsePassed
        (runContractRequest contractRegistry selectionForecastPersistenceScenario)
        [ "build-kept-forecast-derived"
        , "simulation-kept-forecast-derived"
        , "next-kept-forecast-derived"
        , "observation-detects-persisted-forecast"
        ]
  ]

captureTests :: TestTree
captureTests = testGroup "v1 routed capture and duplicate suspicion"
  [ testCase "preserves verbatim input and ranks one typed scoped duplicate" $ do
      (owner, entry, _raw, context) <- captureFixture
      let draft = Capture.CaptureDraft "comprar leite" (Just "Buy milk") (Just Ai)
            (Just Capture.CreateListEntry) Nothing (Just (brickId owner))
            Nothing Nothing
      (intent, suspicions, state) <- requireCaptureSuccess
        (Capture.beginCapture draft domainTestTime context Capture.emptyCaptureState)
      Capture.captureIntentOriginalText intent @?= "comprar leite"
      Capture.captureIntentCanonicalEnglish intent @?= Just "Buy milk"
      Capture.captureIntentNormalizationAuthority intent @?= Just Ai
      case suspicions of
        [suspicion] -> do
          Capture.duplicateSuspicionTargetKind suspicion @?=
            Capture.DuplicateListEntry
          Capture.duplicateSuspicionTargetBrick suspicion @?= Nothing
          Capture.duplicateSuspicionTargetEntry suspicion @?=
            Just (listEntryId entry)
          Capture.duplicateSuspicionTargetRaw suspicion @?= Nothing
          assertBool "duplicate reasons are absent"
            (not (null (Capture.duplicateSuspicionReasons suspicion)))
          selected <- requireCaptureSuccess (Capture.selectDuplicateSuspicion
            (Capture.captureIntentId intent) Nothing (Just (listEntryId entry))
            Nothing state)
          selected @?= suspicion
        values -> assertFailure ("expected one entry suspicion, found "
          <> show (length values))
      Capture.matchingFingerprints "  Buy\nMILKS! " @?=
        Capture.matchingFingerprints "Buy MILKS!"
  , testCase "enriches an entry with reviewed Raw without a second occurrence" $ do
      (owner, entry, _raw, context) <- captureFixture
      let draft = Capture.CaptureDraft "comprar leite" (Just "Buy milk") (Just Ai)
            (Just Capture.CreateListEntry) Nothing (Just (brickId owner))
            Nothing Nothing
      (intent, suspicions, opened) <- requireCaptureSuccess
        (Capture.beginCapture draft domainTestTime context Capture.emptyCaptureState)
      suspicion <- case suspicions of
        [value] -> pure value
        _ -> assertFailure "entry suspicion fixture is not unique"
      (result, nextContext, routed) <- requireCaptureSuccess
        (Capture.confirmDuplicateDecision (Capture.captureIntentId intent)
          (Capture.duplicateSuspicionId suspicion) Capture.DuplicateEnrich Human
          domainTestTime context opened)
      let beforeEntries = domainListEntries (captureTestDomain context)
          afterEntries = domainListEntries (captureTestDomain nextContext)
      Map.keysSet afterEntries @?= Map.keysSet beforeEntries
      Map.lookup (listEntryId entry) afterEntries @?= Just entry
      evidence <- maybe (assertFailure "enrichment omitted Raw evidence") pure
        (Capture.captureDecisionResultRaw result)
      let material = Capture.captureContextMaterial nextContext
          links = [link | link <- Map.elems (materialLinks material),
            rawLinkRaw link == evidence,
            rawLinkOwnerEntry link == Just (listEntryId entry),
            rawLinkRole link == Evidence]
      length links @?= 1
      fmap rawOriginalText (Map.lookup evidence (materialRaws material)) @?=
        Just (Just "comprar leite")
      case Capture.confirmDuplicateDecision (Capture.captureIntentId intent)
          (Capture.duplicateSuspicionId suspicion) Capture.DuplicateReuse Human
          domainTestTime nextContext routed of
        Left _ -> pure ()
        Right _ -> assertFailure "capture accepted a second duplicate decision"
  , testCase "creates positioned template Bricks and owner-scoped original entries" $ do
      (owner, _entry, _raw, context) <- captureFixture
      template <- maybe (assertFailure "grocery template is absent") pure
        (find ((== "standard/grocery_list") . templateId)
          (templateVersions initialDefinitionCatalog))
      let brickDraft = Capture.CaptureDraft "Nova lista" (Just "New list")
            (Just Ai) (Just Capture.InstantiateTemplate) Nothing Nothing Nothing
            (Just template)
      (brickIntent, _, brickOpened) <- requireCaptureSuccess
        (Capture.beginCapture brickDraft domainTestTime context
          Capture.emptyCaptureState)
      (brickResult, brickContext, _) <- requireCaptureSuccess
        (Capture.confirmSeparateCapture (Capture.captureIntentId brickIntent) Human
          domainTestTime context brickOpened)
      createdBrickId <- maybe (assertFailure "template route omitted Brick") pure
        (Capture.captureDecisionResultBrick brickResult)
      createdBrick <- maybe (assertFailure "template Brick disappeared") pure
        (Map.lookup createdBrickId (domainBricks (captureTestDomain brickContext)))
      behaviorId (brickBehavior createdBrick) @?= "core/standing_checklist"
      brickOriginalTitle createdBrick @?= Just "Nova lista"
      capturePriorityMemberships createdBrickId brickContext @?= 1

      let entryDraft = Capture.CaptureDraft "ovos" (Just "Eggs") (Just Ai)
            (Just Capture.CreateListEntry) Nothing (Just (brickId owner))
            Nothing Nothing
      (entryIntent, _, entryOpened) <- requireCaptureSuccess
        (Capture.beginCapture entryDraft domainTestTime context
          Capture.emptyCaptureState)
      (entryResult, entryContext, _) <- requireCaptureSuccess
        (Capture.confirmSeparateCapture (Capture.captureIntentId entryIntent) Human
          domainTestTime context entryOpened)
      createdEntryId <- maybe (assertFailure "entry route omitted ListEntry") pure
        (Capture.captureDecisionResultEntry entryResult)
      createdEntry <- maybe (assertFailure "created ListEntry disappeared") pure
        (Map.lookup createdEntryId
          (domainListEntries (captureTestDomain entryContext)))
      listEntryOwner createdEntry @?= brickId owner
      listEntryLabel createdEntry @?= "Eggs"
      listEntryOriginalLabel createdEntry @?= Just "ovos"
      capturePriorityMemberships (brickId owner) entryContext @?= 1
  , testCase "routes one verbatim capture to one canonical Raw" $ do
      (_owner, _entry, _raw, context) <- captureFixture
      let draft = Capture.CaptureDraft "  nota exatamente assim  " Nothing Nothing
            (Just Capture.PreserveRaw) Nothing Nothing Nothing Nothing
          beforeCount = Map.size
            (materialRaws (Capture.captureContextMaterial context))
      (intent, _, opened) <- requireCaptureSuccess
        (Capture.beginCapture draft domainTestTime context Capture.emptyCaptureState)
      (result, nextContext, _) <- requireCaptureSuccess
        (Capture.confirmSeparateCapture (Capture.captureIntentId intent) Human
          domainTestTime context opened)
      identifier <- maybe (assertFailure "preserve_raw omitted Raw") pure
        (Capture.captureDecisionResultRaw result)
      let material = Capture.captureContextMaterial nextContext
      Map.size (materialRaws material) @?= beforeCount + 1
      fmap rawOriginalText (Map.lookup identifier (materialRaws material)) @?=
        Just (Just "  nota exatamente assim  ")
  , testCase "cancels terminally and rejects invalid route bindings" $ do
      (_owner, _entry, _raw, context) <- captureFixture
      let cancellable = Capture.CaptureDraft "verbatim" Nothing Nothing
            (Just Capture.PreserveRaw) Nothing Nothing Nothing Nothing
      (intent, _, opened) <- requireCaptureSuccess
        (Capture.beginCapture cancellable domainTestTime context
          Capture.emptyCaptureState)
      (cancelled, terminal) <- requireCaptureSuccess
        (Capture.cancelCapture (Capture.captureIntentId intent) context opened)
      Capture.captureIntentStatus cancelled @?= Capture.CaptureCancelled
      case Capture.confirmSeparateCapture (Capture.captureIntentId intent) Human
          domainTestTime context terminal of
        Left _ -> pure ()
        Right _ -> assertFailure "cancelled capture was routed"
      let unsupported = Capture.CaptureDraft "subitem" (Just "Subitem")
            (Just Human) (Just Capture.CreateListEntry) Nothing Nothing
            Nothing Nothing
      (unsupportedIntent, _, unsupportedState) <- requireCaptureSuccess
        (Capture.beginCapture unsupported domainTestTime context
          Capture.emptyCaptureState)
      case Capture.confirmSeparateCapture
          (Capture.captureIntentId unsupportedIntent) Human domainTestTime context
          unsupportedState of
        Left _ -> pure ()
        Right _ -> assertFailure "ListEntry route accepted no owner"
      case Capture.beginCapture (cancellable
          {Capture.captureDraftCanonicalEnglish = Just "Canonical"})
          domainTestTime context Capture.emptyCaptureState of
        Left _ -> pure ()
        Right _ -> assertFailure "unattributed canonical input was accepted"
  ]

coordinationTests :: TestTree
coordinationTests = testGroup "v1 coordination, entries, date notices, and places"
  [ testCase "enforces Wait and acyclic Dependency lifecycles" $ do
      (_, firstBrick, initial) <- coordinationFixture "Blocked"
      (blocker, second) <- createUnitCoordinationBrick "Blocker" standardV1 Nothing
        initial
      (thirdBrick, third) <- createUnitCoordinationBrick "Third" standardV1 Nothing
        second
      (wait, fourth) <- requireCoordinationSuccess
        (Coordination.addCoordinationWait (brickId firstBrick) Nothing
          "response received" domainTestTime third)
      (_, fifth) <- requireCoordinationSuccess
        (Coordination.resolveCoordinationWait (Coordination.waitId wait)
          domainTestTime fourth)
      case Coordination.cancelCoordinationWait (Coordination.waitId wait)
          domainTestTime fifth of
        Left _ -> pure ()
        Right _ -> assertFailure "terminal Wait transitioned twice"
      (dependency, sixth) <- requireCoordinationSuccess
        (Coordination.addCoordinationDependency (brickId firstBrick)
          (brickId blocker) domainTestTime fifth)
      (_, seventh) <- requireCoordinationSuccess
        (Coordination.addCoordinationDependency (brickId blocker)
          (brickId thirdBrick) domainTestTime sixth)
      case Coordination.addCoordinationDependency (brickId thirdBrick)
          (brickId firstBrick) domainTestTime seventh of
        Left _ -> pure ()
        Right _ -> assertFailure "dependency cycle was accepted"
      satisfied <- requireCoordinationSuccess
        (Coordination.completeCoordinationBrick (brickId blocker)
          domainTestTime seventh)
      fmap Coordination.dependencyStatus
        (Map.lookup (Coordination.dependencyId dependency)
          (Coordination.coordinationStateDependencies satisfied)) @?=
            Just Coordination.DependencySatisfied
  , testCase "keeps Delegation lifecycle separate from human WIP and focus" $ do
      (party, brick, initial) <- coordinationFixture "Delegated"
      focusedExecution <- requireExecutionSuccess (Execution.focusExecutionBrick
        (brickId brick) domainTestTime
        (Coordination.coordinationStateExecution initial))
      let focused = initial
            {Coordination.coordinationStateExecution = focusedExecution}
          executionBefore = Coordination.coordinationStateExecution focused
      Execution.activeHumanWipCount executionBefore @?= 1
      (draft, first) <- requireCoordinationSuccess
        (Coordination.draftDelegation (brickId brick) (partyId party)
          "Handle externally" Nothing domainTestTime focused)
      Coordination.coordinationStateExecution first @?= executionBefore
      Execution.activeHumanWipCount
        (Coordination.coordinationStateExecution first) @?= 1
      (_, second) <- requireCoordinationSuccess
        (Coordination.approveDelegationNotice (Coordination.delegationId draft)
          domainTestTime first)
      (_, third) <- requireCoordinationSuccess
        (Coordination.markDelegationInProgress
          (Coordination.delegationId draft) second)
      (completed, fourth) <- requireCoordinationSuccess
        (Coordination.completeDelegation (Coordination.delegationId draft)
          (Just "finished") third)
      Coordination.delegationStatus completed @?=
        Coordination.DelegationCompleted
      Coordination.coordinationStateExecution fourth @?= executionBefore
      case Coordination.abandonDelegation (Coordination.delegationId draft)
          Nothing fourth of
        Left _ -> pure ()
        Right _ -> assertFailure "terminal Delegation transitioned twice"
  , testCase "retains ListEntry identity/history and reviews finite empty owners" $ do
      (_, _, initial) <- coordinationFixture "Ordinary"
      (owner, first) <- createUnitCoordinationBrick "Checklist"
        finiteChecklistV1 Nothing initial
      (child, second) <- createUnitCoordinationBrick "Checklist child"
        standardV1 (Just (brickId owner)) first
      label <- requireDomainSuccess
        (mkCanonicalText "Passport" (Just "Passaporte") Human)
      (entry, third) <- requireCoordinationSuccess
        (Coordination.addCoordinationListEntry
          (ListEntryDraft (brickId owner) label (Just 1) Nothing domainTestTime)
          second)
      (resolved, fourth) <- requireCoordinationSuccess
        (Coordination.resolveCoordinationListEntry (listEntryId entry)
          domainTestTime third)
      listEntryId resolved @?= listEntryId entry
      Set.member (brickId owner)
        (Coordination.coordinationStateChecklistReviews fourth) @?= True
      fmap listEntryStatus (Map.lookup (listEntryId entry)
        (domainListEntries (Execution.executionStateDomain
          (Coordination.coordinationStateExecution fourth)))) @?=
            Just EntryResolved
      case Coordination.completeFiniteChecklist (brickId owner)
          domainTestTime fourth of
        Left _ -> pure ()
        Right _ -> assertFailure "finite checklist with active child completed"
      childClosed <- requireCoordinationSuccess
        (Coordination.completeCoordinationBrick (brickId child)
          domainTestTime fourth)
      ownerClosed <- requireCoordinationSuccess
        (Coordination.completeFiniteChecklist (brickId owner)
          domainTestTime childClosed)
      fmap brickStatus (Map.lookup (brickId owner)
        (domainBricks (Execution.executionStateDomain
          (Coordination.coordinationStateExecution ownerClosed)))) @?= Just Done
  , testCase "revises inherited date notices idempotently and preserves history" $ do
      (_, _, initial) <- coordinationFixture "Ordinary"
      (parent, first) <- createUnitCoordinationBrick "Dated parent" projectV1
        Nothing initial
      (child, second) <- createUnitCoordinationBrick "Dated child" standardV1
        (Just (brickId parent)) first
      dated <- requireCoordinationSuccess
        (Coordination.setCoordinationDeadline (brickId parent)
          (addUTCTime (2 * 24 * 60 * 60) domainTestTime) second)
      (created, advanced) <- requireCoordinationSuccess
        (Coordination.advanceCoordinationTime domainTestTime dated)
      let childNotices = [notice | notice <- created,
            Coordination.dateNoticeBrick notice == brickId child]
      childNotice <- case childNotices of
        [notice] -> pure notice
        values -> assertFailure ("expected one child notice: " <> show values)
      (_, repeated) <- requireCoordinationSuccess
        (Coordination.advanceCoordinationTime domainTestTime advanced)
      Map.size (Coordination.coordinationStateDateNotices repeated) @?=
        Map.size (Coordination.coordinationStateDateNotices advanced)
      (_, snoozed) <- requireCoordinationSuccess
        (Coordination.snoozeDateNotice (Coordination.dateNoticeId childNotice)
          (addUTCTime 60 domainTestTime) repeated)
      (_, beforeWake) <- requireCoordinationSuccess
        (Coordination.advanceCoordinationTime (addUTCTime 59 domainTestTime)
          snoozed)
      fmap Coordination.dateNoticeStatus
        (Map.lookup (Coordination.dateNoticeId childNotice)
          (Coordination.coordinationStateDateNotices beforeWake)) @?=
            Just Coordination.NoticeSnoozed
      (_, woken) <- requireCoordinationSuccess
        (Coordination.advanceCoordinationTime (addUTCTime 60 domainTestTime)
          beforeWake)
      fmap Coordination.dateNoticeStatus
        (Map.lookup (Coordination.dateNoticeId childNotice)
          (Coordination.coordinationStateDateNotices woken)) @?=
            Just Coordination.NoticePending
      revised <- requireCoordinationSuccess
        (Coordination.setCoordinationDeadline (brickId parent)
          (addUTCTime (3 * 24 * 60 * 60) domainTestTime) woken)
      fmap Coordination.dateNoticeStatus
        (Map.lookup (Coordination.dateNoticeId childNotice)
          (Coordination.coordinationStateDateNotices revised)) @?=
            Just Coordination.NoticeResolved
      (newRevisionNotices, withNewRevision) <- requireCoordinationSuccess
        (Coordination.advanceCoordinationTime domainTestTime revised)
      let newChildNotices = [notice | notice <- newRevisionNotices,
            Coordination.dateNoticeBrick notice == brickId child]
      assertBool "new date revision emitted no child notice"
        (not (null newChildNotices))
      withNotBefore <- requireCoordinationSuccess
        (Coordination.setCoordinationNotBefore (brickId child)
          (addUTCTime 30 domainTestTime) withNewRevision)
      assertBool "not-before revision did not resolve superseded notices"
        (all ((== Coordination.NoticeResolved) . Coordination.dateNoticeStatus)
          [notice | notice <- Map.elems
            (Coordination.coordinationStateDateNotices withNotBefore),
            Coordination.dateNoticeBrick notice == brickId child])
      _ <- requireCoordinationSuccess
        (Coordination.clearCoordinationNotBefore (brickId child) withNotBefore)
      pure ()
  , testCase "derives hard and soft Place conditions from non-stale evidence only" $ do
      (_, hardBrick, initial) <- coordinationFixture "At home"
      (softBrick, first) <- createUnitCoordinationBrick "Near office"
        standardV1 Nothing initial
      (home, second) <- requireCoordinationSuccess
        (Coordination.createPlace "Home" domainTestTime first)
      (office, third) <- requireCoordinationSuccess
        (Coordination.createPlace "Office" domainTestTime second)
      (_, fourth) <- requireCoordinationSuccess
        (Coordination.addPlaceCondition (brickId hardBrick)
          (Coordination.placeId home) Coordination.PlaceHard domainTestTime third)
      (_, fifth) <- requireCoordinationSuccess
        (Coordination.addPlaceCondition (brickId softBrick)
          (Coordination.placeId office) Coordination.PlaceSoft domainTestTime fourth)
      hardBefore <- requireCoordinationSuccess
        (Coordination.evaluatePlaceConditions domainTestTime (brickId hardBrick)
          fifth)
      softBefore <- requireCoordinationSuccess
        (Coordination.evaluatePlaceConditions domainTestTime (brickId softBrick)
          fifth)
      Coordination.placeEvaluationEligible hardBefore @?= False
      Coordination.placeEvaluationEligible softBefore @?= True
      let executionBefore = Coordination.coordinationStateExecution fifth
      (observation, observed) <- requireCoordinationSuccess
        (Coordination.recordLocationObservation (Coordination.placeId home)
          Coordination.LocationEntered domainTestTime Nothing Human "manual"
          (Just "manual:home:1") fifth)
      Coordination.locationObservationExpiresAt observation @?=
        addUTCTime Coordination.locationObservationTtl domainTestTime
      Coordination.coordinationStateExecution observed @?= executionBefore
      current <- requireCoordinationSuccess
        (Coordination.evaluatePlaceConditions (addUTCTime 1 domainTestTime)
          (brickId hardBrick) observed)
      Coordination.placeEvaluationEligible current @?= True
      Coordination.placeEvaluationExternalTrace current @?= []
      stale <- requireCoordinationSuccess
        (Coordination.evaluatePlaceConditions
          (addUTCTime Coordination.locationObservationTtl domainTestTime)
          (brickId hardBrick) observed)
      Coordination.placeEvaluationEligible stale @?= False
      case Coordination.recordLocationObservation (Coordination.placeId home)
          Coordination.LocationPresent domainTestTime Nothing Adapter "manual"
          (Just "manual:home:1") observed of
        Left _ -> pure ()
        Right _ -> assertFailure "duplicate external observation was accepted"
  , testCase "passes inherited date move scenario through the real protocol" $
      assertResponsePassed
        (runContractRequest contractRegistry inheritedDatesScenario)
        [ "child-inherits-first-deadline-before-move"
        , "first-notice-uses-effective-fingerprint"
        , "move-preserves-child-id-and-descendants"
        , "move-recalculates-inherited-deadline"
        , "old-notice-is-resolved-not-deleted"
        , "old-scope-judgments-become-historical"
        , "new-scope-placement-is-provisional"
        , "new-date-can-create-one-new-notice"
        ]
  ]

materialTests :: TestTree
materialTests = testGroup "v1 Raw material, blobs, provenance, and shelves"
  [ testCase "content-addresses, reads, deduplicates, and verifies canonical blobs" $ do
      let bytes = LBS8.pack "canonical evidence"
          contentHash = canonicalContentHash bytes
          size = fromIntegral (LBS.length bytes)
      stored <- requireMaterialSuccess
        (canonicalBlobPut contentHash size "text/plain" bytes emptyCanonicalBlobStore)
      canonicalBlobRead contentHash stored @?= Right bytes
      canonicalBlobVerify contentHash stored @?= True
      canonicalBlobPut contentHash size "text/plain" bytes stored @?= Right stored
      case canonicalBlobPut "sha256:wrong" size "text/plain" bytes stored of
        Left (BlobHashMismatch _ _) -> pure ()
        result -> assertFailure ("mismatched hash accepted: " <> show result)
      case canonicalBlobPut contentHash (size + 1) "text/plain" bytes stored of
        Left (BlobSizeMismatch _ _) -> pure ()
        result -> assertFailure ("mismatched size accepted: " <> show result)
  , testCase "retains immutable distinct snapshots through missing, corrupt, and repair" $ do
      (raw, first) <- requireMaterialSuccess
        (captureInlineRaw "evidence" Nothing Nothing domainTestTime emptyMaterialState)
      (capturedV1, second) <- requireMaterialSuccess
        (captureRawSnapshot (rawId raw) "sha256:v1" 1 "text/plain"
          (Just "r1") domainTestTime first)
      snapshotV1 <- requireCreatedSnapshot capturedV1
      (capturedV2, third) <- requireMaterialSuccess
        (captureRawSnapshot (rawId raw) "sha256:v2" 2 "text/plain"
          (Just "r2") (addUTCTime 1 domainTestTime) second)
      snapshotV2 <- requireCreatedSnapshot capturedV2
      snapshotV1 @?= Map.findWithDefault snapshotV1 (rawSnapshotId snapshotV1)
        (materialSnapshots third)
      assertBool "snapshot versions collapsed" (snapshotV1 /= snapshotV2)
      latest <- requireMaterialSuccess (rawLatestSnapshot third (rawId raw))
      latest @?= Just snapshotV2
      (missing, fourth) <- requireMaterialSuccess
        (reportSnapshotMissing (rawSnapshotId snapshotV1) third)
      rawSnapshotAvailability missing @?= SnapshotMissing
      rawSnapshotVerifiedAt missing @?= Nothing
      (repaired, fifth) <- requireMaterialSuccess
        (verifySnapshotBytes (rawSnapshotId snapshotV1)
          (addUTCTime 2 domainTestTime) fourth)
      rawSnapshotAvailability repaired @?= SnapshotAvailable
      (corrupt, sixth) <- requireMaterialSuccess
        (reportSnapshotCorrupt (rawSnapshotId snapshotV1) fifth)
      rawSnapshotAvailability corrupt @?= SnapshotCorrupt
      (repairedAgain, _) <- requireMaterialSuccess
        (verifySnapshotBytes (rawSnapshotId snapshotV1)
          (addUTCTime 3 domainTestTime) sixth)
      rawSnapshotAvailability repairedAgain @?= SnapshotAvailable
  , testCase "keeps source presence, work state, local review, and storage independent" $ do
      ((raw, origin), first) <- requireMaterialSuccess
        (captureExternalRaw (Just "Issue") "fake" "issue:1" (Just "1")
          domainTestTime emptyMaterialState)
      (observation, second) <- requireMaterialSuccess
        (recordSourceObservation (rawOriginId origin) Adapter (Just "obs:1")
          (Just "r2") Removed WorkUnknown Nothing
          (addUTCTime 1 domainTestTime) first)
      sourceObservationPresence observation @?= Removed
      sourceObservationWorkState observation @?= WorkUnknown
      let unchangedRaw = Map.findWithDefault raw (rawId raw) (materialRaws second)
      rawReviewState unchangedRaw @?= RawPending
      rawStorageState unchangedRaw @?= RawActive
      let updatedOrigin = Map.findWithDefault origin (rawOriginId origin)
            (materialOrigins second)
      rawOriginLastObservedRevision updatedOrigin @?= Just "r2"
      (relocated, third) <- requireMaterialSuccess
        (relocateRawOrigin (rawOriginId origin) "issue:2" second)
      rawOriginLocator origin @?= "issue:1"
      rawOriginLocator relocated @?= "issue:2"
      (retired, _) <- requireMaterialSuccess
        (retireRawOrigin (rawOriginId origin) third)
      rawOriginHistoricalOnly retired @?= True
  , testCase "enforces typed single-owner links and explicit reconciliation" $ do
      ((raw, _), first) <- requireMaterialSuccess
        (captureExternalRaw Nothing "fake" "source:1" Nothing
          domainTestTime emptyMaterialState)
      (other, second) <- requireMaterialSuccess
        (captureInlineRaw "derived" Nothing Nothing domainTestTime first)
      let brick = BrickId "brick:material-test"
          entry = ListEntryId "entry:material-test"
          registered = registerMaterialListEntry entry
            (registerMaterialBrick brick Active second)
      (capturedV1, third) <- requireMaterialSuccess
        (captureRawSnapshot (rawId raw) "sha256:one" 1 "text/plain" Nothing
          domainTestTime registered)
      snapshotV1 <- requireCreatedSnapshot capturedV1
      (sourceLink, fourth) <- requireMaterialSuccess
        (linkRawToBrick (rawId raw) brick Source (Just (rawSnapshotId snapshotV1))
          domainTestTime third)
      (entryLink, fifth) <- requireMaterialSuccess
        (linkRawToEntry (rawId other) entry Evidence domainTestTime fourth)
      rawLinkOwnerBrick sourceLink @?= Just brick
      rawLinkOwnerEntry sourceLink @?= Nothing
      rawLinkOwnerEntry entryLink @?= Just entry
      (derived, sixth) <- requireMaterialSuccess
        (linkDerivedRaw (rawId other) (rawId raw) domainTestTime fifth)
      rawLinkRaw derived @?= rawId raw
      rawLinkOwnerRaw derived @?= Just (rawId other)
      (capturedV2, seventh) <- requireMaterialSuccess
        (captureRawSnapshot (rawId raw) "sha256:two" 2 "text/plain" Nothing
          (addUTCTime 1 domainTestTime) sixth)
      snapshotV2 <- requireCreatedSnapshot capturedV2
      openSourceReconciliationKinds seventh brick @?= ["source_reconciliation"]
      (reconciled, eighth) <- requireMaterialSuccess
        (reconcileRawLink (rawLinkId sourceLink) (rawSnapshotId snapshotV2) seventh)
      rawLinkReconciledSnapshot reconciled @?= Just (rawSnapshotId snapshotV2)
      openSourceReconciliationKinds eighth brick @?= []
      case linkRawToBrick (rawId raw) brick Source Nothing domainTestTime eighth of
        Left DuplicateRawLink -> pure ()
        result -> assertFailure ("duplicate source link accepted: " <> show result)
  , testCase "transitions review and archive axes without deleting history" $ do
      (raw, first) <- requireMaterialSuccess
        (captureInlineRaw "review me" (Just "Review me") (Just Human)
          domainTestTime emptyMaterialState)
      ((reviewed, disposition), second) <- requireMaterialSuccess
        (reviewRaw (rawId raw) NoWork Nothing Human (Just "nothing actionable")
          domainTestTime first)
      rawReviewState reviewed @?= RawReviewedState
      rawStorageState reviewed @?= RawActive
      rawReviewDispositionKind disposition @?= NoWork
      (archived, third) <- requireMaterialSuccess (archiveRaw (rawId raw) second)
      rawReviewState archived @?= RawReviewedState
      rawStorageState archived @?= RawArchivedState
      (reopened, fourth) <- requireMaterialSuccess (reopenRaw (rawId raw) third)
      rawReviewState reopened @?= RawPending
      rawStorageState reopened @?= RawArchivedState
      (unarchived, final) <- requireMaterialSuccess (unarchiveRaw (rawId raw) fourth)
      rawStorageState unarchived @?= RawActive
      assertBool "Raw history was deleted"
        (Map.member (rawId raw) (materialRaws final)
          && Map.member (rawReviewDispositionId disposition)
            (materialReviewDispositions final))
  , testCase "keeps shelf membership flat, unique, and reversible" $ do
      (raw, first) <- requireMaterialSuccess
        (captureInlineRaw "shelf item" Nothing Nothing domainTestTime emptyMaterialState)
      (shelf, second) <- requireMaterialSuccess
        (createRawShelf "References" domainTestTime first)
      (membership, third) <- requireMaterialSuccess
        (addRawToShelf (rawId raw) (rawShelfId shelf) domainTestTime second)
      rawShelfMembershipRaw membership @?= rawId raw
      rawShelfMembershipShelf membership @?= rawShelfId shelf
      case addRawToShelf (rawId raw) (rawShelfId shelf) domainTestTime third of
        Left (DuplicateShelfMembership _ _) -> pure ()
        result -> assertFailure ("duplicate shelf membership accepted: " <> show result)
      final <- requireMaterialSuccess
        (removeRawFromShelf (rawId raw) (rawShelfId shelf) third)
      Map.null (materialMemberships final) @?= True
      Map.member (rawId raw) (materialRaws final) @?= True
  , testCase "runs the seven raw source reconciliation assertions on real state" $
      assertResponsePassed (runContractRequest contractRegistry materialScenario)
        [ "new-snapshot-is-immutable-and-distinct"
        , "new-source-snapshot-proposes-reconciliation"
        , "external-removal-is-not-local-done"
        , "external-removal-does-not-archive-raw"
        , "observation-keeps-presence-separate-from-work-state"
        , "reconciliation-advances-baseline-explicitly"
        , "reconciliation-does-not-fetch-hidden-io"
        ]
  ]

priorityTests :: TestTree
priorityTests = testGroup "strict human priority and recalibration"
  [ testCase "keeps one strict sibling position and ignores dependency ordering" $ do
      (byTitle, ordered) <- requirePrioritySuccess
        (Priority.createStrictRootFixture ["A", "B", "C"]
          [("A", "B"), ("B", "C")] "unit-order" domainTestTime
          Priority.emptyPriorityState)
      a <- requireNamedPriority "A" byTitle
      b <- requireNamedPriority "B" byTitle
      c <- requireNamedPriority "C" byTitle
      let rootBefore = Map.lookup Priority.priorityRootScopeId
            (Priority.priorityStateScopes ordered)
      fmap Priority.priorityScopeMembers rootBefore @?= Just [a, b, c]
      withDependency <- requirePrioritySuccess
        (Priority.recordPriorityDependency c a ordered)
      fmap Priority.priorityScopeMembers
        (Map.lookup Priority.priorityRootScopeId
          (Priority.priorityStateScopes withDependency)) @?= Just [a, b, c]
      (_, terminal) <- requirePrioritySuccess
        (Priority.setPriorityBrickStatus b Done domainTestTime withDependency)
      assertBool "terminal Brick remained positioned"
        (all (notElem b . Priority.priorityScopeMembers)
          (Map.elems (Priority.priorityStateScopes terminal)))
      requirePrioritySuccess (Priority.validatePriorityState terminal)
  , testCase "skips choose a nearby distinct candidate without false evidence" $ do
      (byTitle, ordered) <- requirePrioritySuccess
        (Priority.createStrictRootFixture ["A", "B"] [("A", "B")]
          "unit-skip" domainTestTime Priority.emptyPriorityState)
      (c, insertion, created) <- requirePrioritySuccess
        (Priority.createPriorityRoot "C" "unit-skip" domainTestTime ordered)
      let beforeEvidence = Map.size (Priority.priorityStateJudgments created)
          previous = Priority.priorityInsertionCurrentCandidate insertion
      previousCandidate <- maybe
        (assertFailure "open insertion has no comparison candidate") pure previous
      (afterFirst, firstSkip, first) <- requirePrioritySuccess
        (Priority.skipPriorityComparison (Priority.priorityInsertionId insertion)
          Priority.Unresolved domainTestTime created)
      Priority.priorityInsertionStatus afterFirst @?= Priority.InsertionOpen
      assertBool "first skip repeated its candidate"
        (Priority.priorityInsertionCurrentCandidate afterFirst /= previous)
      assertBool "alternate candidate was not nearby"
        (maybe False (\distance -> distance >= 1 && distance <= 3)
          (Priority.priorityInsertionCandidateDistanceFromPrevious afterFirst))
      Priority.priorityComparisonSkipCandidate firstSkip @?= previousCandidate
      Map.size (Priority.priorityStateJudgments first) @?= beforeEvidence
      (deferred, _, final) <- requirePrioritySuccess
        (Priority.skipPriorityComparison (Priority.priorityInsertionId afterFirst)
          Priority.Unresolved domainTestTime first)
      Priority.priorityInsertionStatus deferred @?= Priority.InsertionDeferred
      Priority.priorityProposalKinds final (Priority.priorityBrickId c) @?=
        ["priority_probe"]
      viewItem <- requirePrioritySuccess
        (Priority.priorityViewItem final (Priority.priorityBrickId c))
      Priority.priorityViewItemProvisional viewItem @?= True
      deferredCandidate <- maybe
        (assertFailure "deferred insertion forgot its final candidate") pure
        (Priority.priorityInsertionPreviousCandidate deferred)
      evidence <- requirePrioritySuccess (Priority.priorityEvidence final
        Priority.priorityRootScopeId (Priority.priorityBrickId c) deferredCandidate)
      Priority.priorityEvidenceContainsEquality evidence @?= False
      assertBool "fixture lost title bindings"
        (all (`Map.member` byTitle) ["A", "B"])
  , testCase "keeps a single-candidate insertion open until the skip threshold" $ do
      (firstRoot, _, first) <- requirePrioritySuccess
        (Priority.createPriorityRoot "A" "unit-single-skip" domainTestTime
          Priority.emptyPriorityState)
      (secondRoot, insertion, created) <- requirePrioritySuccess
        (Priority.createPriorityRoot "B" "unit-single-skip" domainTestTime first)
      let candidate = Just (Priority.priorityBrickId firstRoot)
          beforeEvidence = Map.size (Priority.priorityStateJudgments created)
      Priority.priorityInsertionCurrentCandidate insertion @?= candidate
      (afterFirst, _, skippedOnce) <- requirePrioritySuccess
        (Priority.skipPriorityComparison (Priority.priorityInsertionId insertion)
          Priority.Unresolved domainTestTime created)
      Priority.priorityInsertionStatus afterFirst @?= Priority.InsertionOpen
      Priority.priorityInsertionConsecutiveSkips afterFirst @?= 1
      Priority.priorityInsertionCurrentCandidate afterFirst @?= candidate
      Priority.priorityInsertionFinishedAt afterFirst @?= Nothing
      Priority.priorityProposalKinds skippedOnce
        (Priority.priorityBrickId secondRoot) @?= []
      Map.size (Priority.priorityStateJudgments skippedOnce) @?= beforeEvidence
      (deferred, _, final) <- requirePrioritySuccess
        (Priority.skipPriorityComparison (Priority.priorityInsertionId afterFirst)
          Priority.Unresolved domainTestTime skippedOnce)
      Priority.priorityInsertionStatus deferred @?= Priority.InsertionDeferred
      Priority.priorityInsertionConsecutiveSkips deferred @?= 2
      Priority.priorityInsertionCurrentCandidate deferred @?= Nothing
      assertBool "threshold skip did not finish the insertion"
        (Priority.priorityInsertionFinishedAt deferred /= Nothing)
      Priority.priorityProposalKinds final
        (Priority.priorityBrickId secondRoot) @?= ["priority_probe"]
  , testCase "keeps skip candidates inside bounds narrowed by earlier answers" $ do
      (byTitle, ordered) <- requirePrioritySuccess
        (Priority.createStrictRootFixture ["A", "B", "C", "D", "E"] []
          "x" domainTestTime Priority.emptyPriorityState)
      a <- requireNamedPriority "A" byTitle
      b <- requireNamedPriority "B" byTitle
      c <- requireNamedPriority "C" byTitle
      d <- requireNamedPriority "D" byTitle
      e <- requireNamedPriority "E" byTitle
      (f, insertion, created) <- requirePrioritySuccess
        (Priority.createPriorityRoot "F" "x" domainTestTime ordered)
      Priority.priorityInsertionCurrentCandidate insertion @?= Just c
      (afterAnswer, _, answered) <- requirePrioritySuccess
        (Priority.answerPriorityInsertion (Priority.priorityInsertionId insertion)
          True Human Nothing domainTestTime created)
      Priority.priorityInsertionCurrentCandidate afterAnswer @?= Just b
      Priority.priorityInsertionSearchLow afterAnswer @?= 0
      Priority.priorityInsertionSearchHigh afterAnswer @?= 2
      (afterSkip, _, skipped) <- requirePrioritySuccess
        (Priority.skipPriorityComparison
          (Priority.priorityInsertionId afterAnswer) Priority.Unresolved
          domainTestTime answered)
      Priority.priorityInsertionCurrentCandidate afterSkip @?= Just a
      (afterSecondAnswer, _, answeredAgain) <- requirePrioritySuccess
        (Priority.answerPriorityInsertion (Priority.priorityInsertionId afterSkip)
          False Human Nothing domainTestTime skipped)
      Priority.priorityInsertionStatus afterSecondAnswer @?= Priority.InsertionOpen
      Priority.priorityInsertionCurrentCandidate afterSecondAnswer @?= Just b
      (resolved, _, final) <- requirePrioritySuccess
        (Priority.answerPriorityInsertion
          (Priority.priorityInsertionId afterSecondAnswer) True Human Nothing
          domainTestTime answeredAgain)
      Priority.priorityInsertionStatus resolved @?= Priority.InsertionResolved
      fmap Priority.priorityScopeMembers
        (Map.lookup Priority.priorityRootScopeId
          (Priority.priorityStateScopes final)) @?=
            Just [a, Priority.priorityBrickId f, b, c, d, e]
  , testCase "retains contradiction history and commits only the local segment" $ do
      (byTitle, ordered) <- requirePrioritySuccess
        (Priority.createStrictRootFixture ["A", "B", "C", "D"]
          [("A", "B"), ("B", "C")] "unit-contradiction" domainTestTime
          Priority.emptyPriorityState)
      a <- requireNamedPriority "A" byTitle
      b <- requireNamedPriority "B" byTitle
      c <- requireNamedPriority "C" byTitle
      d <- requireNamedPriority "D" byTitle
      before <- requirePrioritySuccess
        (Priority.priorityEvidence ordered Priority.priorityRootScopeId a c)
      (probe, withProbe) <- requirePrioritySuccess
        (Priority.openPriorityProbe Priority.priorityRootScopeId a c
          Priority.Validation "test transitive edge" domainTestTime ordered)
      (_, recalibrationResult, contradicted) <- requirePrioritySuccess
        (Priority.recordPriorityJudgment Priority.priorityRootScopeId c a Human
          (Just "new evidence") domainTestTime withProbe)
      recalibration <- maybe
        (assertFailure "contradiction did not open recalibration") pure
        recalibrationResult
      after <- requirePrioritySuccess
        (Priority.priorityEvidence contradicted Priority.priorityRootScopeId a c)
      assertBool "contradiction did not lower confidence"
        (Priority.priorityEvidenceConfidence after
          < Priority.priorityEvidenceConfidence before)
      assertBool "new human judgment was not retained"
        (any (\judgment ->
          Priority.priorityJudgmentMoreImportant judgment == c
          && Priority.priorityJudgmentLessImportant judgment == a)
          (Priority.priorityEvidenceHistory after))
      assertBool "transitive support disappeared"
        (not (null (Priority.priorityEvidenceTransitiveSupport after)))
      Priority.priorityRecalibrationSegment recalibration @?= [a, b, c]
      fmap Priority.judgmentProbeStatus
        (Map.lookup (Priority.judgmentProbeId probe)
          (Priority.priorityStateProbes contradicted)) @?= Just Priority.ProbeResolved
      let historySize = Map.size (Priority.priorityStateJudgments contradicted)
      (resolved, committed) <- requirePrioritySuccess
        (Priority.commitPriorityRecalibration
          (Priority.priorityRecalibrationId recalibration)
          domainTestTime contradicted)
      Priority.priorityRecalibrationStatus resolved @?=
        Priority.RecalibrationResolved
      fmap (last . Priority.priorityScopeMembers)
        (Map.lookup Priority.priorityRootScopeId
          (Priority.priorityStateScopes committed)) @?= Just d
      Map.size (Priority.priorityStateJudgments committed) @?= historySize
      requirePrioritySuccess (Priority.validatePriorityState committed)
  , testCase "runs both owned priority scenarios on immutable checkpoints" $ do
      assertResponsePassed
        (runContractRequest contractRegistry priorityUncertaintyScenario)
        [ "first-skip-selects-nearby-distinct-candidate"
        , "skip-records-no-directional-judgment"
        , "skip-records-no-equality"
        , "insertion-defers-at-threshold"
        , "brick-remains-strictly-positioned"
        , "position-is-marked-provisional"
        , "uncertainty-creates-future-pressure"
        ]
      assertResponsePassed
        (runContractRequest contractRegistry priorityContradictionScenario)
        [ "provocative-question-tests-transitive-edge"
        , "new-human-judgment-is-retained"
        , "older-evidence-is-not-deleted"
        , "contradiction-lowers-confidence"
        , "smallest-local-segment-is-selected"
        , "unrelated-tail-does-not-move"
        , "committed-segment-is-strict-and-coherent"
        ]
  ]

judgmentTests :: TestTree
judgmentTests = testGroup "impact, effort, and judgment evidence"
  [ testCase "keeps root impact history and opens contradiction recalibration" $ do
      (rootA, rootB, _, _, state) <- judgmentFixtureState
      (_, _, first) <- requireJudgmentSuccess
        (Judgment.classifyImpact rootA Judgment.HighImpact Judgment.Supported
          Human Nothing domainTestTime state)
      (_, _, second) <- requireJudgmentSuccess
        (Judgment.classifyImpact rootA Judgment.LowImpact Judgment.Speculative
          Ai (Just "AI prior") (addUTCTime 1 domainTestTime) first)
      humanView <- requireJudgmentSuccess (Judgment.impactEvidence second rootA)
      fmap Judgment.impactAssessmentImpact
        (Judgment.impactEvidenceCurrent humanView) @?= Just Judgment.HighImpact
      assertBool "conflicting AI evidence did not lower reliability"
        (Judgment.impactEvidenceNeedsValidation humanView)
      (_, _, third) <- requireJudgmentSuccess
        (Judgment.classifyImpact rootB Judgment.LowImpact Judgment.Supported
          Human Nothing domainTestTime second)
      (_, probe, contradicted) <- requireJudgmentSuccess
        (Judgment.compareImpact rootA rootB Judgment.RelativelyLess Human Nothing
          (addUTCTime 2 domainTestTime) third)
      assertBool "contradictory impact did not open a recalibration probe"
        (probe /= Nothing)
      finalView <- requireJudgmentSuccess
        (Judgment.impactEvidence contradicted rootA)
      length (Judgment.impactEvidenceHistory finalView) @?= 2
      assertBool "impact comparison history is absent"
        (not (null (Judgment.impactEvidenceComparisons finalView)))
  , testCase "versions ordered effort profiles and preserves assessment calibration" $ do
      (rootA, _, _, disabled, state) <- judgmentFixtureState
      map Judgment.effortBandId Judgment.initialEffortBands @?=
        [ "VERY_EASY", "EASY", "NORMAL", "MODERATED", "HARD"
        , "VERY_HARD", "MINI_PROJECT", "PROJECT"
        ]
      map Judgment.effortBandOrdinal Judgment.initialEffortBands @?= [1 .. 8]
      easy <- requireJudgmentSuccess
        (Judgment.effortBandById Judgment.initialEffortProfile "EASY" state)
      (assessment, _, classified) <- requireJudgmentSuccess
        (Judgment.classifyEffort rootA easy Human False Nothing domainTestTime state)
      let drafts =
            [ Judgment.EffortBandDraft "SMALL" 1 "EFFORT_SMALL" 1 2 3
            , Judgment.EffortBandDraft "LARGE" 2 "EFFORT_LARGE" 4 6 8
            ]
      (profileV2, _, versioned) <- requireJudgmentSuccess
        (Judgment.publishEffortProfile "core/effort" 2 "Recalibrated" drafts
          classified)
      Judgment.effortProfileVersion profileV2 @?= 2
      Judgment.effortBandProfile (Judgment.effortAssessmentBand assessment) @?=
        Judgment.initialEffortProfile
      case Judgment.publishEffortProfile "core/effort" 2 "Mutation" drafts
          versioned of
        Left (Judgment.InvalidEffortProfile _) -> pure ()
        result -> assertFailure ("published effort version mutated: " <> show result)
      case Judgment.classifyEffort disabled easy Human False Nothing domainTestTime
          versioned of
        Left (Judgment.InvalidJudgmentRelationship _) -> pure ()
        result -> assertFailure ("effort-disabled Brick classified: " <> show result)
  , testCase "derives remaining effort only from conservative progress evidence" $ do
      (rootA, _, _, _, state) <- judgmentFixtureState
      normal <- requireJudgmentSuccess
        (Judgment.effortBandById Judgment.initialEffortProfile "NORMAL" state)
      (_, _, classified) <- requireJudgmentSuccess
        (Judgment.classifyEffort rootA normal Human False Nothing domainTestTime state)
      (_, focused) <- requireJudgmentSuccess
        (Judgment.recordProgressEvidence rootA Judgment.FocusDuration 100
          domainTestTime classified)
      unchanged <- requireJudgmentSuccess
        (Judgment.remainingEffortProjection focused rootA
          Judgment.initialEffortProfile)
      Judgment.remainingEffortRealisticHours unchanged @?= Just 12
      (_, progressed) <- requireJudgmentSuccess
        (Judgment.recordProgressEvidence rootA Judgment.ExplicitHumanProgress 0.25
          (addUTCTime 1 domainTestTime) focused)
      remaining <- requireJudgmentSuccess
        (Judgment.remainingEffortProjection progressed rootA
          Judgment.initialEffortProfile)
      Judgment.remainingEffortRealisticHours remaining @?= Just 9
      fmap Judgment.effortBandId (Judgment.remainingEffortTotalBand remaining) @?=
        Just "NORMAL"
      current <- requireJudgmentSuccess (Judgment.effortEvidence progressed rootA)
      fmap (Judgment.effortBandId . Judgment.effortAssessmentBand)
        (Judgment.effortEvidenceCurrent current) @?= Just "NORMAL"
  , testCase "enforces probe scope, decomposition, terminal cleanup, and correction" $ do
      (rootA, rootB, child, disabled, state) <- judgmentFixtureState
      case Judgment.openImpactProbe child rootB Priority.Validation "bad scope"
          domainTestTime state of
        Left (Judgment.InvalidJudgmentRelationship _) -> pure ()
        result -> assertFailure ("child impact probe accepted: " <> show result)
      case Judgment.openEffortProbe rootA disabled Priority.Validation
          "bad applicability" domainTestTime state of
        Left (Judgment.InvalidJudgmentRelationship _) -> pure ()
        result -> assertFailure ("inapplicable effort probe accepted: " <> show result)
      (probe, opened) <- requireJudgmentSuccess
        (Judgment.openEffortProbe rootA rootB Priority.Validation "calibrate"
          domainTestTime state)
      (_, deferred) <- requireJudgmentSuccess
        (Judgment.deferAssessmentProbe (Priority.judgmentProbeId probe) opened)
      (_, reopened) <- requireJudgmentSuccess
        (Judgment.reopenAssessmentProbe (Priority.judgmentProbeId probe) deferred)
      (_, terminal) <- requireJudgmentSuccess
        (Judgment.setJudgmentBrickStatus rootB Done domainTestTime reopened)
      fmap Priority.judgmentProbeStatus
        (Map.lookup (Priority.judgmentProbeId probe)
          (Judgment.judgmentStateProbes terminal)) @?= Just Priority.ProbeResolved
      (parent, covered) <- requireJudgmentSuccess
        (Judgment.confirmDecompositionCoverage rootA state)
      Judgment.judgmentBrickDecompositionCoverage parent @?= Complete
      easy <- requireJudgmentSuccess
        (Judgment.effortBandById Judgment.initialEffortProfile "EASY" covered)
      (_, _, assessed) <- requireJudgmentSuccess
        (Judgment.classifyEffort rootA easy Human False Nothing domainTestTime covered)
      (_, revised) <- requireJudgmentSuccess
        (Judgment.confirmScopeRevision rootA "scope changed" Human
          (addUTCTime 1 domainTestTime) assessed)
      assertBool "scope revision deleted evidence"
        (not (Map.null (Judgment.judgmentStateEffortAssessments revised)))
      assertBool "scope revision left affected evidence applicable"
        (all (not . Judgment.effortAssessmentApplicable)
          (Map.elems (Judgment.judgmentStateEffortAssessments revised)))
  , testCase "retires priority evidence on scope revision without moving Bricks" $ do
      (byTitle, ordered) <- requirePrioritySuccess
        (Priority.createStrictRootFixture ["A", "B"] [("A", "B")]
          "scope-revision" domainTestTime Priority.emptyPriorityState)
      a <- requireNamedPriority "A" byTitle
      let membersBefore = fmap Priority.priorityScopeMembers
            (Map.lookup Priority.priorityRootScopeId
              (Priority.priorityStateScopes ordered))
      revised <- requirePrioritySuccess
        (Priority.invalidatePriorityJudgmentsFor a ordered)
      fmap Priority.priorityScopeMembers
        (Map.lookup Priority.priorityRootScopeId
          (Priority.priorityStateScopes revised)) @?= membersBefore
      assertBool "affected priority evidence remained applicable"
        (all (not . Priority.priorityJudgmentApplicable)
          (Map.elems (Priority.priorityStateJudgments revised)))
  ]

interactionTests :: TestTree
interactionTests = testGroup "v1 revision-scoped interactions and powered-up mode"
  [ testCase "keeps help read-only and advances current answers exactly once" $ do
      (session, state) <- requireInteractionSuccess (Interaction.openInteraction
        "priority_comparison" Nothing Nothing (Just "seed") domainTestTime 0
        Interaction.emptyInteractionState)
      before <- requireInteractionSuccess
        (Interaction.currentInteraction (Interaction.interactionSessionId session) state)
      helped <- requireInteractionSuccess (Interaction.requestInteractionHelp
        (Interaction.interactionSessionId session) state)
      helped @?= before
      (_, response, accepted) <- requireInteractionSuccess
        (Interaction.acceptCurrentInteractionAction
          (Interaction.interactionSessionId session) 0 1 0 "yes" domainTestTime state)
      let acceptedSession = Map.lookup (Interaction.interactionSessionId session)
            (Interaction.interactionStateSessions accepted)
      Interaction.operationalResponseDomainRevision response @?= 1
      fmap Interaction.interactionSessionDomainRevision acceptedSession @?= Just 1
      fmap Interaction.interactionSessionInteractionRevision acceptedSession @?=
        Just 2
      fmap Interaction.interactionSessionConfirmedActions acceptedSession @?= Just 1
      assertBool "accepted prompt key was reused"
        (fmap Interaction.interactionSessionPromptKey acceptedSession
          /= Just (Interaction.interactionSessionPromptKey session))
  , testCase "rejects a stale key without domain work and rebases independently" $ do
      (session, state) <- requireInteractionSuccess (Interaction.openInteraction
        "priority_comparison" Nothing Nothing Nothing domainTestTime 0
        Interaction.emptyInteractionState)
      (_, _, accepted) <- requireInteractionSuccess
        (Interaction.acceptCurrentInteractionAction
          (Interaction.interactionSessionId session) 0 1 0 "yes" domainTestTime state)
      decision <- requireInteractionSuccess (Interaction.classifyInteractionSubmission
        (Interaction.interactionSessionId session) 0 1 1 "yes"
        (addUTCTime 1 domainTestTime) accepted)
      stale <- case decision of
        Interaction.StaleSubmission response next -> do
          Interaction.operationalResponseErrorCode response @?=
            Just "stale_interaction"
          pure next
        result -> assertFailure ("stale key was accepted: " <> show result)
      let staleSession = Map.lookup (Interaction.interactionSessionId session)
            (Interaction.interactionStateSessions stale)
      fmap Interaction.interactionSessionConfirmedActions staleSession @?= Just 1
      fmap Interaction.interactionSessionDomainRevision staleSession @?= Just 1
      (rebased, _) <- requireInteractionSuccess (Interaction.rebaseInteraction
        (Interaction.interactionSessionId session) 1
        (addUTCTime 2 domainTestTime) stale)
      Interaction.interactionSessionStatus rebased @?= Interaction.InteractionOpen
      Interaction.interactionSessionDomainRevision rebased @?= 1
      Interaction.interactionSessionInteractionRevision rebased @?= 3
  , testCase "restores one complete presentation checkpoint per surface" $ do
      let response = Interaction.OperationalResponse True "accepted"
            (Just "interaction_action") Nothing ["domain"] [] Nothing Nothing
            Nothing 4
          summary = Interaction.StatusSummary "mode: dumb" "dumb" Nothing
            Nothing 0 0 0
          query = object ["page_size" .= (20 :: Integer)]
          page = object ["snapshot_domain_revision" .= (4 :: Integer)]
          brief = object ["facts" .= (["confirmed"] :: [Text])]
          firstDraft = Interaction.SurfaceCheckpointDraft "terminal"
            (Just (Interaction.InteractionId "interaction-1")) 4 (Just 2)
            "dialog" (Just "row-2") (Just "pending text") (Just 5)
            ["question", "answer"] (Just response) (Just summary)
            (Just Interaction.ProjectionHistory) (Just query) (Just page)
            (Just brief)
      (first, firstState) <- requireInteractionSuccess
        (Interaction.saveFirstSurfaceCheckpoint firstDraft domainTestTime
          Interaction.emptyInteractionState)
      let updatedDraft = firstDraft
            { Interaction.checkpointDraftSelectedItem = Just "row-3"
            , Interaction.checkpointDraftTextBuffer = Just "recovered text"
            , Interaction.checkpointDraftCursorOffset = Just 9
            }
      (updated, updatedState) <- requireInteractionSuccess
        (Interaction.saveExistingSurfaceCheckpoint updatedDraft
          (addUTCTime 1 domainTestTime) firstState)
      Interaction.surfaceCheckpointId updated @?=
        Interaction.surfaceCheckpointId first
      Map.size (Interaction.interactionStateCheckpoints updatedState) @?= 1
      Interaction.surfaceCheckpointSelectedItem updated @?= Just "row-3"
      Interaction.surfaceCheckpointTextBuffer updated @?= Just "recovered text"
      Interaction.surfaceCheckpointCursorOffset updated @?= Just 9
      Interaction.surfaceCheckpointLastResponse updated @?= Just response
      Interaction.surfaceCheckpointLastStatus updated @?= Just summary
      Interaction.surfaceCheckpointLastProjection updated @?=
        Just Interaction.ProjectionHistory
      Interaction.surfaceCheckpointHistoryQuery updated @?= Just query
      Interaction.surfaceCheckpointLastHistoryPage updated @?= Just page
      Interaction.surfaceCheckpointLastHistoryBrief updated @?= Just brief
  , testCase "reports only confirmed work as adaptive progress" $ do
      (session, state) <- requireInteractionSuccess (Interaction.openInteraction
        "priority_comparison" Nothing Nothing Nothing domainTestTime 0
        Interaction.emptyInteractionState)
      Interaction.interactionProgressFacts
        (Interaction.honestInteractionProgress session) @?=
          ["0 confirmed actions"]
      _ <- requireInteractionSuccess (Interaction.requestInteractionHelp
        (Interaction.interactionSessionId session) state)
      (_, _, accepted) <- requireInteractionSuccess
        (Interaction.acceptCurrentInteractionAction
          (Interaction.interactionSessionId session) 0 1 0 "yes" domainTestTime state)
      acceptedSession <- maybe (assertFailure "accepted session disappeared") pure
        (Map.lookup (Interaction.interactionSessionId session)
          (Interaction.interactionStateSessions accepted))
      let progress = Interaction.honestInteractionProgress acceptedSession
      Interaction.interactionProgressFacts progress @?= ["1 confirmed action"]
      assertBool "adaptive estimate is not a range"
        (Interaction.interactionProgressEstimatedRemainingMin progress
          <= Interaction.interactionProgressEstimatedRemainingMax progress)
  , testCase "fails ambiguous adapters and exposes only validated powered mode" $ do
      let ambiguous = "{\"protocol_version\":1,\"status\":\"OK\"}"
            <> "{\"protocol_version\":1,\"status\":\"NO\"}"
          (rejected, _, dumb) = Interaction.validatePoweredUpAdapter
            "/tmp/broken" "stdin" ambiguous Interaction.emptyInteractionState
      assertBool "ambiguous adapter was accepted" (case rejected of
        Interaction.PoweredUpRejected _ -> True
        _ -> False)
      Interaction.replRuntimeMode (Interaction.interactionStateReplRuntime dumb)
        @?= Interaction.Dumb
      let (acceptedResult, _, powered) = Interaction.validatePoweredUpAdapter
            "/opt/lant/model" "stdin"
            "{\"protocol_version\":1,\"status\":\"OK\"}"
            Interaction.emptyInteractionState
          summary = Interaction.statusSummary Nothing 0 0 0 powered
      acceptedResult @?= Interaction.PoweredUpAccepted
      Interaction.statusSummaryMode summary @?= "powered_up"
      Interaction.statusSummaryPoweredBy summary @?= Just "/opt/lant/model"
      trace <- maybe (assertFailure "powered-up trace disappeared") pure
        (Map.lookup "/opt/lant/model"
          (Interaction.interactionStateProcessTraces powered))
      Interaction.processInvocationTraceArgumentCount trace @?= 0
      Interaction.processInvocationTraceArgumentsContainPrompt trace @?= False
      Interaction.processInvocationTraceStdinContainsProbe trace @?= True
      Interaction.processInvocationTraceSecretValuesRecorded trace @?= False
  , testCase "executes the configured adapter with its probe on stdin only" $ do
      temporary <- getTemporaryDirectory
      (path, handle) <- openTempFile temporary "lant-powered-probe.sh"
      hPutStr handle (unlines
        [ "#!/bin/sh"
        , "[ \"$#\" -eq 0 ] || exit 41"
        , "input=$(cat)"
        , "case \"$input\" in"
        , "  *'\"kind\":\"probe\"'*) printf '%s\\n' '{\"protocol_version\":1,\"status\":\"OK\"}' ;;"
        , "  *) exit 42 ;;"
        , "esac"
        ])
      hClose handle
      permissions <- getPermissions path
      setPermissions path permissions {executable = True}
      result <- Interaction.probePoweredUpAdapter path
        `finally` removeFile path
      trace <- case result of
        Left problem -> assertFailure ("adapter probe failed: " <> show problem)
        Right value -> pure value
      Interaction.processInvocationTraceArgumentCount trace @?= 0
      Interaction.processInvocationTraceArgumentsContainPrompt trace @?= False
      Interaction.processInvocationTraceStdinContainsProbe trace @?= True
  ]

implementationBridgeTests :: TestTree
implementationBridgeTests = testGroup "real implementation registry"
  [ testCase "populates every contract extension point" $ do
      assertBool "plan probes are empty" (not (Map.null
        (registryPlanProbes contractRegistry)))
      assertBool "operations are empty" (not (Map.null
        (registryOperations contractRegistry)))
      assertBool "observations are empty" (not (Map.null
        (registryObservations contractRegistry)))
      assertBool "fixtures are empty" (not (Map.null
        (registryFixtures contractRegistry)))
      assertBool "paths are empty" (not (Map.null
        (registryPaths contractRegistry)))
      assertBool "assertion operators are empty" (not (Map.null
        (registryAssertionOperators contractRegistry)))
      assertBool "reference resolvers are empty" (not (Map.null
        (registryReferences contractRegistry)))
  , testCase "kernel plan probes execute real append and replay" $ do
      assertResponsePassed (runContractRequest contractRegistry kernelInteractionPlan)
        [ "contract-signature.CanonicalEventStore.append"
        , "contract-signature.CanonicalEventStore.replay"
        ]
      assertResponsePassed (runContractRequest contractRegistry kernelRootPlan)
        ["invariant.GloballyOpaqueEntityIds"]
  , testCase "binds the DomainClock obligation to authoritative kernel state" $ do
      kernelRevision emptyKernelState @?= DomainRevision 0
      assertResponsePassed
        (runContractRequest contractRegistry interactionDomainClockPlan)
        ["entity-fields.DomainClock"]
  , testCase "dispatches confidence_before and forecast references" $
      assertResponsePassed (runContractRequest contractRegistry
        implementationReferenceScenario)
        ["confidence-reference", "forecast-reference"]
  , testCase "validates schema presence through a structured response query" $
      assertResponsePassed (runContractRequest contractRegistry
        implementationSchemaScenario)
        ["structured-schema-presence"]
  , testCase "serves real domain entity and definition fixtures" $
      assertResponsePassed (runContractRequest contractRegistry
        implementationDomainFixtureScenario)
        ["domain-fixture", "catalog-fixture"]
  , testCase "executes domain probes by semantic construct" $
      assertResponsePassed (runContractRequest contractRegistry domainPlanRequest)
        [ "enum-comparable.Authority"
        , "entity-fields.Brick"
        , "contract-signature.DefinitionCatalog.find_templates"
        , "rule-success.PersonalBehaviorVersionPublished"
        , "invariant.TerminalBrickIsNotWip"
        ]
  , testCase "executes material probes through real constructors and boundaries" $
      assertResponsePassed (runContractRequest contractRegistry materialPlanRequest)
        [ "contract-signature.CanonicalBlobStore.put"
        , "entity-fields.RawSnapshot"
        , "rule-success.SourceLinkReconciled"
        , "invariant.RawLinkHasExactlyOneOwner"
        , "surface-provides.MaterialDesk"
        ]
  , testCase "executes priority probes through strict ordering and evidence" $
      assertResponsePassed (runContractRequest contractRegistry judgmentPlanRequest)
        [ "enum-comparable.PrioritySkipKind"
        , "entity-fields.PriorityInsertion"
        , "rule-success.PriorityComparisonSkippedAtThreshold"
        , "rule-success.CoherentPriorityRecalibrationCommitted"
        , "invariant.EveryActiveBrickIsPositionedExactlyOnce"
        ]
  , testCase "serves impact, effort, remaining-work, and probe projections" $
      assertResponsePassed (runContractRequest contractRegistry judgmentBridgeScenario)
        [ "impact-history-is-retained"
        , "impact-contradiction-opens-probe"
        , "remaining-effort-uses-explicit-progress"
        , "judgments-do-not-control-eligibility"
        ]
  ]

planTests :: TestTree
planTests = testGroup "Allium registry"
  [ testCase "selects probes by semantic metadata and preserves IDs" $ do
      let response = runContractRequest testRegistry planRequest
      map resultItemId (driverResponseResults response) @?= ["known", "unknown"]
      map resultItemPassed (driverResponseResults response) @?= [True, False]
      case driverResponseResults response of
        [_, unknown] -> assertDetailContains "unregistered Allium construct" unknown
        results -> assertFailure ("unexpected results: " <> show results)
      driverResponseOk response @?= False
  , testCase "collapses duplicate requested IDs without inventing one" $ do
      let response = runContractRequest testRegistry duplicatePlanRequest
      map resultItemId (driverResponseResults response) @?= ["known"]
      assertBool "duplicate diagnostic is absent"
        (not (null (driverResponseDiagnostics response)))
      driverResponseOk response @?= False
  ]

scenarioTests :: TestTree
scenarioTests = testGroup "scenario execution"
  [ testCase "resolves bind and bind_result symbols" $
      assertResponsePassed (runContractRequest testRegistry bindingScenario)
        ["complete-binding", "scalar-binding", "array-binding", "expression"]
  , testCase "retains before and after checkpoints" $
      assertResponsePassed (runContractRequest testRegistry checkpointScenario)
        ["after-first", "before-second", "at-anchor", "at-final"]
  , testCase "creates assertion-local fixtures from fresh state" $
      assertResponsePassed (runContractRequest testRegistry localFixtureScenario)
        ["fixture-state"]
  , testCase "passes pinned ambient inputs to operations" $
      assertResponsePassed (runContractRequest testRegistry ambientScenario)
        ["pinned-context"]
  , testCase "resolves registered value_from references with bindings and checkpoints" $
      assertResponsePassed (runContractRequest testRegistry referenceScenario)
        ["confidence-snapshot", "forecast-reference"]
  , testCase "does not rerun assertion operations for snapshot expectations" $
      assertSingleFailure "equals_snapshot comparison failed"
        operationSnapshotScenario
  , testCase "starts every request from isolated state" $ do
      let first = runContractRequest testRegistry isolatedScenario
          second = runContractRequest testRegistry isolatedScenario
      let expected = ["one-in-first-request", "dynamic-revision-reference"]
      assertResponsePassed first expected
      assertResponsePassed second expected
  ]

operatorTests :: TestTree
operatorTests = testGroup "declared assertion operators"
  [ testCase "registry contains every checked-in operator" $
      Set.fromList (Map.keys standardAssertionOperators) @?=
        Set.fromList declaredOperators
  , testCase "all operators implement their literal comparisons" $ do
      assertOperator "all_equal" (toJSON ([1, 1] :: [Int])) (Just (toJSON (1 :: Int))) emptyObject
      assertOperator "all_match"
        (toJSON [object ["n" .= (2 :: Int)], object ["n" .= (3 :: Int)]])
        (Just (object ["n" .= object ["greater_than" .= (1 :: Int)]]))
        emptyObject
      assertOperator "all_omit" (toJSON [object ["id" .= (1 :: Int)]])
        (Just (String "secret")) emptyObject
      assertOperator "all_unique_by"
        (toJSON [object ["id" .= (1 :: Int)], object ["id" .= (2 :: Int)]])
        (Just (String "id")) emptyObject
      assertOperator "all_within_absolute_tolerance"
        (toJSON [object ["expected" .= (0.4 :: Double), "actual" .= (0.41 :: Double)]])
        Nothing
        (objectValue
          [ "expected_path" .= ("expected" :: Text)
          , "actual_path" .= ("actual" :: Text)
          , "tolerance" .= (0.02 :: Double)
          ])
      assertOperator "between_inclusive" (toJSON (2 :: Int))
        (Just (toJSON ([1, 3] :: [Int]))) emptyObject
      assertOperator "contains" (object ["status" .= ("active" :: Text), "n" .= (1 :: Int)])
        (Just (object ["status" .= ("active" :: Text)])) emptyObject
      assertOperator "contains_all" (toJSON (["a", "b", "c"] :: [Text]))
        (Just (toJSON (["a", "c"] :: [Text]))) emptyObject
      assertOperator "contains_once" (toJSON (["a", "b"] :: [Text]))
        (Just (String "a")) emptyObject
      assertOperator "contains_references"
        (object ["first" .= ("brick:a" :: Text), "nested" .= ["brick:b" :: Text]])
        (Just (toJSON (["brick:a", "brick:b"] :: [Text]))) emptyObject
      assertOperator "count_equals" (toJSON ([1, 2] :: [Int]))
        (Just (toJSON (2 :: Int))) emptyObject
      assertOperator "equals" (String "x") (Just (String "x")) emptyObject
      assertOperator "equals_expression" (toJSON (2 :: Int))
        (Just (toJSON (2 :: Int))) emptyObject
      assertOperator "equals_reference" (String "id") (Just (String "id")) emptyObject
      assertOperator "equals_set" (toJSON ([2, 1, 1] :: [Int]))
        (Just (toJSON ([1, 2] :: [Int]))) emptyObject
      assertOperator "equals_snapshot" (String "same") (Just (String "same")) emptyObject
      assertOperator "greater_than" (toJSON (3 :: Int)) (Just (toJSON (2 :: Int))) emptyObject
      assertOperator "is_null" Null Nothing emptyObject
      assertOperator "less_than" (String "2026-01") (Just (String "2026-02")) emptyObject
      assertOperator "not_contains" (toJSON (["a"] :: [Text])) (Just (String "b")) emptyObject
      assertOperator "not_empty" (toJSON ([1] :: [Int])) Nothing emptyObject
      assertOperator "not_equals" (String "a") (Just (String "b")) emptyObject
      assertOperator "omits" (object ["safe" .= True])
        (Just (toJSON (["secret", "nested.token"] :: [Text]))) emptyObject
      assertOperator "omits_paths" (object ["safe" .= True])
        (Just (String "secret")) emptyObject
      assertOperator "rejected_with" (object ["error_code" .= ("precondition_failed" :: Text)])
        (Just (String "precondition_failed")) emptyObject
      assertOperator "results_in" (object ["status" .= ("failed" :: Text), "changed" .= False])
        (Just (object ["status" .= ("failed" :: Text)])) emptyObject
      let sparseResponse = object
            [ "ok" .= False
            , "human" .= ("precondition failed" :: Text)
            , "changed" .= ([] :: [Text])
            , "warnings" .= ([] :: [Text])
            , "domain_revision" .= (0 :: Int)
            , "entity" .= object
                [ "id" .= ("brick:zero" :: Text)
                , "revision" .= (0 :: Int)
                , "state" .= ("active" :: Text)
                ]
            ]
      assertOperator "schema_presence_matches_projection" sparseResponse
        (Just (Bool True)) emptyObject
      assertOperator "schema_presence_matches_projection"
        (object ["human" .= ("missing required fields" :: Text)])
        (Just (Bool False)) emptyObject
      assertOperator "unique_by"
        (toJSON [object ["id" .= (1 :: Int)], object ["id" .= (2 :: Int)]])
        (Just (String "id")) emptyObject
  ]

rejectionTests :: TestTree
rejectionTests = testGroup "fail-closed behavior"
  [ testCase "unknown operation fails requested assertion with a diagnostic" $ do
      let response = runContractRequest testRegistry unknownOperationScenario
      map resultItemId (driverResponseResults response) @?= ["still-returned"]
      map resultItemPassed (driverResponseResults response) @?= [False]
      case driverResponseResults response of
        [result] -> assertDetailContains "unregistered operation" result
        results -> assertFailure ("unexpected results: " <> show results)
  , testCase "unknown fixture fails only its assertion" $
      assertSingleFailure "unregistered fixture"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-fixture" :: Text)
          , "fixture" .= ("absent" :: Text)
          , "query" .= ("State" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown reference is rejected" $
      assertSingleFailure "unregistered reference"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-reference" :: Text)
          , "query" .= ("Argument($absent)" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown observation is rejected" $
      assertSingleFailure "unregistered observation"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-observation" :: Text)
          , "query" .= ("NotRegistered" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown path is rejected" $
      assertSingleFailure "unknown path segment"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-path" :: Text)
          , "query" .= ("View" :: Text)
          , "path" .= ("absent" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value" .= (0 :: Int)
          ]))
  , testCase "unknown value_from reference is rejected" $
      assertSingleFailure "unregistered value_from reference"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-value-from" :: Text)
          , "query" .= ("State" :: Text)
          , "operator" .= ("equals" :: Text)
          , "value_from" .= ("mystery:source" :: Text)
          ]))
  , testCase "unknown operator is rejected" $
      assertSingleFailure "unregistered assertion operator"
        (scenarioWithAssertion (object
          [ "id" .= ("unknown-operator" :: Text)
          , "query" .= ("State" :: Text)
          , "operator" .= ("approximately_magic" :: Text)
          , "value" .= (0 :: Int)
          ]))
  ]

protocolTests :: TestTree
protocolTests = testGroup "wire protocol"
  [ testCase "rejects unsupported protocol versions" $ do
      let response = runContractRequest testRegistry
            (object ["protocol_version" .= (2 :: Int), "request_kind" .= ("scenario" :: Text)])
      driverResponseProtocolVersion response @?= 1
      driverResponseOk response @?= False
  , testCase "rejects a second JSON request on stdin" $ do
      let response = decodeAndRunContractRequest testRegistry
            (LBS8.pack "{\"protocol_version\":1} {\"protocol_version\":1}")
      driverResponseOk response @?= False
      assertBool "missing invalid JSON diagnostic"
        (any (Text.isInfixOf "invalid JSON request")
          (driverResponseDiagnostics response))
  , testCase "scenario result IDs are unique even when requested twice" $ do
      let duplicateAssertion = object
            [ "id" .= ("same" :: Text)
            , "query" .= ("State" :: Text)
            , "operator" .= ("equals" :: Text)
            , "value" .= (0 :: Int)
            ]
          response = runContractRequest testRegistry
            (scenarioRequest [] [duplicateAssertion, duplicateAssertion])
      map resultItemId (driverResponseResults response) @?= ["same"]
      driverResponseOk response @?= False
  ]

testRegistry :: ContractRegistry Int
testRegistry = (emptyContractRegistry (0 :: Int))
  { registryInitialState = const 0
  , registryPlanProbes = Map.singleton
      (ProbeKey "domain" "invariant" "KnownConstruct") knownProbe
  , registryOperations = Map.fromList
      [ ("Increment", incrementOperation)
      , ("Echo", echoOperation)
      , ("CaptureAmbient", ambientOperation)
      , ("ReplayFromEvents", replayFromEventsOperation)
      ]
  , registryObservations = Map.fromList
      [ ("State", stateObservation)
      , ("Argument", argumentObservation)
      , ("View", viewObservation)
      , ("DomainRevision", stateObservation)
      ]
  , registryFixtures = Map.fromList
      [ ("binding_fixture", bindingFixture)
      , ("state_five", stateFiveFixture)
      ]
  , registryReferences = Map.fromList
      [ ("confidence_before", confidenceBeforeReference)
      , ("forecast", forecastReference)
      ]
  }

knownProbe :: PlanProbeInput -> Either Text ()
knownProbe input
  | planProbeCategory input == "invariant" = Right ()
  | otherwise = Left "wrong category"

incrementOperation :: OperationInput -> Int -> Either Text (OperationResult Int)
incrementOperation _ state = Right OperationResult
  { operationResultValue = toJSON (state + 1)
  , operationResultState = state + 1
  }

echoOperation :: OperationInput -> Int -> Either Text (OperationResult Int)
echoOperation input state = Right OperationResult
  { operationResultValue = operationArguments input
  , operationResultState = state
  }

ambientOperation :: OperationInput -> Int -> Either Text (OperationResult Int)
ambientOperation input state = Right OperationResult
  { operationResultValue = ambientValue (operationAmbient input)
  , operationResultState = state
  }

replayFromEventsOperation ::
  OperationInput -> Int -> Either Text (OperationResult Int)
replayFromEventsOperation _ state = Right OperationResult
  { operationResultValue = Null
  , operationResultState = state + 10
  }

confidenceBeforeReference :: ReferenceInput Int -> Either Text Value
confidenceBeforeReference input = do
  stepId <- maybe
    (Left "invalid confidence_before reference")
    Right
    (Text.stripPrefix "confidence_before:" (referenceInputSource input))
  snapshot <- maybe
    (Left ("unknown checkpoint in confidence reference: " <> stepId))
    Right
    (Map.lookup ("before:" <> stepId) (referenceInputCheckpoints input))
  Right (toJSON (referenceSnapshotState snapshot))

forecastReference :: ReferenceInput Int -> Either Text Value
forecastReference input =
  case ( referenceInputSource input
       , Map.lookup "taxes"
           (referenceSnapshotBindings (referenceInputCurrent input))
       , Map.lookup "before:skip-once" (referenceInputCheckpoints input)
       ) of
    ("forecast:before-skip:$taxes.probability", Just (String "brick:taxes"),
        Just _) -> Right (toJSON (0.25 :: Double))
    _ -> Left "invalid forecast reference context"

bindingFixture :: OperationInput -> Int -> Either Text (OperationResult Int)
bindingFixture _ state = Right OperationResult
  { operationResultValue = object
      [ "token" .= ("fixture-token" :: Text)
      , "numbers" .= ([1, 2] :: [Int])
      ]
  , operationResultState = state
  }

stateFiveFixture :: OperationInput -> Int -> Either Text (OperationResult Int)
stateFiveFixture _ _ = Right OperationResult
  { operationResultValue = Null
  , operationResultState = 5
  }

stateObservation :: ObservationInput -> Int -> Either Text Value
stateObservation _ = Right . toJSON

argumentObservation :: ObservationInput -> Int -> Either Text Value
argumentObservation input _ = case observationArguments input of
  [value] -> Right value
  _ -> Left "Argument expects exactly one value"

viewObservation :: ObservationInput -> Int -> Either Text Value
viewObservation _ state = Right (object
  [ "state" .= state
  , "items" .= ([object ["id" .= (1 :: Int)]] :: [Value])
  ])

ambientValue :: AmbientInputs -> Value
ambientValue ambient = object
  [ "clock" .= ambientClock ambient
  , "random_evidence" .= ambientRandomEvidence ambient
  , "parameter_overrides" .= ambientParameterOverrides ambient
  ]

atomicKernelRequest :: AppendRequest
atomicKernelRequest = AppendRequest
  { appendExpectedRevision = DomainRevision 0
  , appendSemanticActionId = "test:atomic-action"
  , appendActorOrOrigin = "human:test"
  , appendOccurredAt = Just "2026-07-27T00:00:00Z"
  , appendProposedEvents =
      [ ProposeValueStored "first" (String "one")
      , ProposeValueStored "second" (toJSON (2 :: Int))
      ]
  }

kernelInteractionPlan :: Value
kernelInteractionPlan = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("interaction" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "contract-signature.CanonicalEventStore.append"
              "contract_signature" "CanonicalEventStore.append"
          , obligation "contract-signature.CanonicalEventStore.replay"
              "contract_signature" "CanonicalEventStore.replay"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

interactionDomainClockPlan :: Value
interactionDomainClockPlan = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("interaction" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [obligation "entity-fields.DomainClock" "entity_fields" "DomainClock"]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

kernelRootPlan :: Value
kernelRootPlan = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("root" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "invariant.GloballyOpaqueEntityIds"
              "invariant" "GloballyOpaqueEntityIds"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

implementationReferenceScenario :: Value
implementationReferenceScenario = scenarioRequest
  [ object
      [ "id" .= ("fixture" :: Text)
      , "operation" .= ("CreateFixture" :: Text)
      , "arguments" .= object
          ["fixture" .= ("kernel_reference_state" :: Text)]
      , "bind_result" .= object ["taxes" .= ("taxes" :: Text)]
      ]
  , object
      [ "id" .= ("lower-confidence" :: Text)
      , "operation" .= ("KernelSetValue" :: Text)
      , "arguments" .= object
          [ "key" .= ("confidence" :: Text)
          , "value" .= (0.4 :: Double)
          ]
      ]
  , object
      [ "id" .= ("skip-once" :: Text)
      , "operation" .= ("KernelSetValue" :: Text)
      , "arguments" .= object
          [ "key" .= ("skip-recorded" :: Text)
          , "value" .= True
          ]
      ]
  ]
  [ object
      [ "id" .= ("confidence-reference" :: Text)
      , "after" .= ("lower-confidence" :: Text)
      , "query" .= ("KernelValue(confidence)" :: Text)
      , "operator" .= ("less_than" :: Text)
      , "value_from" .= ("confidence_before:lower-confidence" :: Text)
      ]
  , object
      [ "id" .= ("forecast-reference" :: Text)
      , "after" .= ("skip-once" :: Text)
      , "query" .= ("KernelValue(actual_probability)" :: Text)
      , "operator" .= ("greater_than" :: Text)
      , "value_from" .= ("forecast:before-skip:$taxes.probability" :: Text)
      ]
  ]

implementationSchemaScenario :: Value
implementationSchemaScenario = scenarioRequest []
  [ object
      [ "id" .= ("structured-schema-presence" :: Text)
      , "query" .= ("LatestOperationalResponse" :: Text)
      , "operator" .= ("schema_presence_matches_projection" :: Text)
      , "value" .= True
      ]
  ]

implementationDomainFixtureScenario :: Value
implementationDomainFixtureScenario = scenarioRequest []
  [ object
      [ "id" .= ("domain-fixture" :: Text)
      , "fixture" .= ("domain_entities" :: Text)
      , "query" .= ("DomainState" :: Text)
      , "path" .= ("state.bricks" :: Text)
      , "operator" .= ("count_equals" :: Text)
      , "value" .= (1 :: Int)
      ]
  , object
      [ "id" .= ("catalog-fixture" :: Text)
      , "fixture" .= ("definition_catalog" :: Text)
      , "query" .= ("BuiltInDefinitionCatalog" :: Text)
      , "path" .= ("behavior_count" :: Text)
      , "operator" .= ("equals" :: Text)
      , "value" .= (8 :: Int)
      ]
  ]

domainPlanRequest :: Value
domainPlanRequest = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("domain" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "enum-comparable.Authority"
              "enum_comparable" "Authority"
          , obligation "entity-fields.Brick" "entity_fields" "Brick"
          , obligation "contract-signature.DefinitionCatalog.find_templates"
              "contract_signature" "DefinitionCatalog.find_templates"
          , obligation "rule-success.PersonalBehaviorVersionPublished"
              "rule_success" "PersonalBehaviorVersionPublished"
          , obligation "invariant.TerminalBrickIsNotWip"
              "invariant" "TerminalBrickIsNotWip"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

materialPlanRequest :: Value
materialPlanRequest = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("material" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "contract-signature.CanonicalBlobStore.put"
              "contract_signature" "CanonicalBlobStore.put"
          , obligation "entity-fields.RawSnapshot"
              "entity_fields" "RawSnapshot"
          , obligation "rule-success.SourceLinkReconciled"
              "rule_success" "SourceLinkReconciled"
          , obligation "invariant.RawLinkHasExactlyOneOwner"
              "invariant" "RawLinkHasExactlyOneOwner"
          , obligation "surface-provides.MaterialDesk"
              "surface_provides" "MaterialDesk"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

judgmentPlanRequest :: Value
judgmentPlanRequest = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("judgment" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "enum-comparable.PrioritySkipKind"
              "enum_comparable" "PrioritySkipKind"
          , obligation "entity-fields.PriorityInsertion"
              "entity_fields" "PriorityInsertion"
          , obligation "rule-success.PriorityComparisonSkippedAtThreshold"
              "rule_success" "PriorityComparisonSkippedAtThreshold"
          , obligation "rule-success.CoherentPriorityRecalibrationCommitted"
              "rule_success" "CoherentPriorityRecalibrationCommitted"
          , obligation "invariant.EveryActiveBrickIsPositionedExactlyOnce"
              "invariant" "EveryActiveBrickIsPositionedExactlyOnce"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

priorityUncertaintyScenario :: Value
priorityUncertaintyScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("priority-uncertainty-unit" :: Text)
      , "clock" .= ("2026-07-27T10:00:00Z" :: Text)
      , "parameter_overrides" .= object
          [ "priority_nearby_distance" .= (3 :: Int)
          , "priority_skip_limit" .= (2 :: Int)
          ]
      , "random_evidence" .= ("priority-uncertainty-seed-001" :: Text)
      , "steps" .=
          [ object
              [ "id" .= ("create-a" :: Text)
              , "operation" .= ("CreateRootBrick" :: Text)
              , "arguments" .= object
                  [ "title" .= ("Validate product A" :: Text)
                  , "title_authority" .= ("human" :: Text)
                  , "behavior" .= ("core/standard" :: Text)
                  ]
              , "bind_result" .= object ["brick" .= ("a" :: Text)]
              ]
          , object
              [ "id" .= ("create-b" :: Text)
              , "operation" .= ("CreateRootBrick" :: Text)
              , "arguments" .= object
                  [ "title" .= ("Validate product B" :: Text)
                  , "title_authority" .= ("human" :: Text)
                  , "behavior" .= ("core/standard" :: Text)
                  ]
              , "bind_result" .= object
                  ["brick" .= ("b" :: Text), "insertion" .= ("b_insertion" :: Text)]
              ]
          , object
              [ "id" .= ("answer-b" :: Text)
              , "operation" .= ("AnswerPriorityComparison" :: Text)
              , "arguments" .= object
                  [ "insertion" .= ("$b_insertion" :: Text)
                  , "answer" .= ("no" :: Text)
                  , "authority" .= ("human" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("create-c" :: Text)
              , "operation" .= ("CreateRootBrick" :: Text)
              , "arguments" .= object
                  [ "title" .= ("Run customer interviews" :: Text)
                  , "title_authority" .= ("human" :: Text)
                  , "behavior" .= ("core/standard" :: Text)
                  ]
              , "bind_result" .= object
                  ["brick" .= ("c" :: Text), "insertion" .= ("c_insertion" :: Text)]
              ]
          , object
              [ "id" .= ("first-skip" :: Text)
              , "operation" .= ("SkipPriorityComparison" :: Text)
              , "arguments" .= object
                  [ "insertion" .= ("$c_insertion" :: Text)
                  , "kind" .= ("unresolved" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("second-skip" :: Text)
              , "operation" .= ("SkipPriorityComparison" :: Text)
              , "arguments" .= object
                  [ "insertion" .= ("$c_insertion" :: Text)
                  , "kind" .= ("unresolved" :: Text)
                  ]
              ]
          ]
      , "assertions" .=
          [ priorityAssertion "first-skip-selects-nearby-distinct-candidate"
              "first-skip" "PriorityInsertion($c_insertion)"
              "candidate_distance_from_previous" "between_inclusive"
              (toJSON ([1, 3] :: [Int]))
          , priorityAssertion "skip-records-no-directional-judgment"
              "second-skip" "PriorityJudgmentsFor($c)" "items"
              "count_equals" (toJSON (0 :: Int))
          , priorityAssertion "skip-records-no-equality" "second-skip"
              "PriorityEvidenceFor($c)" "contains_equality" "equals" (Bool False)
          , priorityAssertion "insertion-defers-at-threshold" "second-skip"
              "PriorityInsertion($c_insertion)" "status" "equals"
              (String "deferred")
          , priorityAssertion "brick-remains-strictly-positioned" "second-skip"
              "RootPriority" "members" "contains_once" (String "$c")
          , priorityAssertion "position-is-marked-provisional" "second-skip"
              "PriorityViewItem($c)" "provisional" "equals" (Bool True)
          , priorityAssertion "uncertainty-creates-future-pressure" "second-skip"
              "OpenProposalsFor($c)" "kinds" "contains" (String "priority_probe")
          ]
      ]
  ]

priorityContradictionScenario :: Value
priorityContradictionScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("priority-contradiction-unit" :: Text)
      , "clock" .= ("2026-07-27T11:00:00Z" :: Text)
      , "steps" .=
          [ object
              [ "id" .= ("create-ordered-run" :: Text)
              , "operation" .= ("CreateFixture" :: Text)
              , "arguments" .= object
                  [ "fixture" .= ("strict_root_priority" :: Text)
                  , "titles" .=
                      ([ "Ship feature A", "Ship feature B", "Ship feature C"
                       , "Clean old screenshots"] :: [Text])
                  , "direct_human_judgments" .=
                      ([ ["Ship feature A", "Ship feature B"]
                       , ["Ship feature B", "Ship feature C"]] :: [[Text]])
                  ]
              , "bind_result" .= object
                  [ "scope" .= ("scope" :: Text)
                  , "Ship feature A" .= ("a" :: Text)
                  , "Ship feature B" .= ("b" :: Text)
                  , "Ship feature C" .= ("c" :: Text)
                  , "Clean old screenshots" .= ("d" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("validate-transitive-edge" :: Text)
              , "operation" .= ("OpenProvocativeValidation" :: Text)
              , "arguments" .= object
                  [ "axis" .= ("priority" :: Text), "scope" .= ("$scope" :: Text)
                  , "left" .= ("$a" :: Text), "right" .= ("$c" :: Text)
                  , "purpose" .= ("validation" :: Text)
                  ]
              , "bind" .= ("probe" :: Text)
              ]
          , object
              [ "id" .= ("record-contradiction" :: Text)
              , "operation" .= ("RecordPriorityJudgment" :: Text)
              , "arguments" .= object
                  [ "scope" .= ("$scope" :: Text)
                  , "more_important" .= ("$c" :: Text)
                  , "less_important" .= ("$a" :: Text)
                  , "authority" .= ("human" :: Text)
                  , "reason" .= ("New evidence changed the decision" :: Text)
                  ]
              , "bind_result" .= object
                  ["recalibration" .= ("recalibration" :: Text)]
              ]
          , object
              [ "id" .= ("commit-local-order" :: Text)
              , "operation" .= ("CommitPriorityRecalibration" :: Text)
              , "arguments" .= object
                  ["recalibration" .= ("$recalibration" :: Text)]
              ]
          ]
      , "assertions" .=
          [ priorityAssertion "provocative-question-tests-transitive-edge"
              "validate-transitive-edge" "JudgmentProbe($probe)" "purpose"
              "equals" (String "validation")
          , priorityAssertion "new-human-judgment-is-retained"
              "record-contradiction" "PriorityEvidence($scope,$a,$c)" "history"
              "contains" (object
                [ "more_important" .= ("$c" :: Text)
                , "less_important" .= ("$a" :: Text)
                , "authority" .= ("human" :: Text)
                ])
          , priorityAssertion "older-evidence-is-not-deleted"
              "record-contradiction" "PriorityEvidence($scope,$a,$c)"
              "transitive_support" "not_empty" Null
          , object
              [ "id" .= ("contradiction-lowers-confidence" :: Text)
              , "after" .= ("record-contradiction" :: Text)
              , "query" .= ("PriorityEvidence($scope,$a,$c)" :: Text)
              , "path" .= ("confidence" :: Text)
              , "operator" .= ("less_than" :: Text)
              , "value_from" .= ("confidence_before:record-contradiction" :: Text)
              ]
          , priorityAssertion "smallest-local-segment-is-selected"
              "record-contradiction" "PriorityRecalibration($recalibration)"
              "segment" "equals" (toJSON (["$a", "$b", "$c"] :: [Text]))
          , priorityAssertion "unrelated-tail-does-not-move" "commit-local-order"
              "RootPriority" "members.last" "equals_reference" (String "$d")
          , priorityAssertion "committed-segment-is-strict-and-coherent"
              "commit-local-order" "PriorityRecalibration($recalibration)"
              "status" "equals" (String "resolved")
          ]
      ]
  ]

priorityAssertion :: Text -> Text -> Text -> Text -> Text -> Value -> Value
priorityAssertion identifier afterStep query path operator expected = object
  ([ "id" .= identifier
   , "after" .= afterStep
   , "query" .= query
   , "path" .= path
   , "operator" .= operator
   ] <> ["value" .= expected | expected /= Null])

judgmentBridgeScenario :: Value
judgmentBridgeScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("judgment-bridge-unit" :: Text)
      , "clock" .= ("2026-07-27T16:00:00Z" :: Text)
      , "steps" .=
          [ object
              [ "id" .= ("fixture" :: Text)
              , "operation" .= ("CreateFixture" :: Text)
              , "arguments" .= object
                  ["fixture" .= ("judgment_entities" :: Text)]
              , "bind_result" .= object
                  [ "root_a" .= ("root_a" :: Text)
                  , "root_b" .= ("root_b" :: Text)
                  , "easy" .= ("easy" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("impact-a" :: Text)
              , "operation" .= ("ClassifyImpact" :: Text)
              , "arguments" .= object
                  [ "root" .= ("$root_a" :: Text)
                  , "impact" .= ("HIGH" :: Text)
                  , "maturity" .= ("SUPPORTED" :: Text)
                  , "authority" .= ("human" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("impact-b" :: Text)
              , "operation" .= ("ClassifyImpact" :: Text)
              , "arguments" .= object
                  [ "root" .= ("$root_b" :: Text)
                  , "impact" .= ("LOW" :: Text)
                  , "maturity" .= ("SUPPORTED" :: Text)
                  , "authority" .= ("human" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("contradict-impact" :: Text)
              , "operation" .= ("CompareImpact" :: Text)
              , "arguments" .= object
                  [ "left" .= ("$root_a" :: Text)
                  , "right" .= ("$root_b" :: Text)
                  , "result" .= ("less" :: Text)
                  , "authority" .= ("human" :: Text)
                  ]
              , "bind_result" .= object ["probe" .= ("impact_probe" :: Text)]
              ]
          , object
              [ "id" .= ("effort" :: Text)
              , "operation" .= ("ClassifyEffort" :: Text)
              , "arguments" .= object
                  [ "brick" .= ("$root_a" :: Text)
                  , "band" .= ("$easy" :: Text)
                  , "authority" .= ("human" :: Text)
                  , "provisional" .= False
                  ]
              ]
          , object
              [ "id" .= ("progress" :: Text)
              , "operation" .= ("RecordProgressEvidence" :: Text)
              , "arguments" .= object
                  [ "brick" .= ("$root_a" :: Text)
                  , "kind" .= ("explicit_human_progress" :: Text)
                  , "amount" .= (0.25 :: Double)
                  ]
              ]
          ]
      , "assertions" .=
          [ priorityAssertion "impact-history-is-retained" "contradict-impact"
              "ImpactEvidence($root_a)" "history" "count_equals" (toJSON (1 :: Int))
          , priorityAssertion "impact-contradiction-opens-probe" "contradict-impact"
              "JudgmentProbe($impact_probe)" "status" "equals" (String "open")
          , priorityAssertion "remaining-effort-uses-explicit-progress" "progress"
              "RemainingEffort($root_a)" "realistic_hours" "equals"
              (toJSON (4.5 :: Double))
          , priorityAssertion "judgments-do-not-control-eligibility" "progress"
              "JudgmentProjection($root_a)" "controls_eligibility" "equals"
              (Bool False)
          ]
      ]
  ]

inheritedDatesScenario :: Value
inheritedDatesScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("inherited-dates-after-move-unit" :: Text)
      , "clock" .= ("2026-07-27T15:00:00Z" :: Text)
      , "steps" .=
          [ object
              [ "id" .= ("create-projects" :: Text)
              , "operation" .= ("CreateFixture" :: Text)
              , "arguments" .= object
                  [ "fixture" .= ("two_projects_with_child" :: Text)
                  , "first_parent" .= ("Launch website" :: Text)
                  , "second_parent" .= ("Maintain website" :: Text)
                  , "child" .= ("Write landing page copy" :: Text)
                  ]
              , "bind_result" .= object
                  [ "first_parent" .= ("launch" :: Text)
                  , "second_parent" .= ("maintain" :: Text)
                  , "child" .= ("copy" :: Text)
                  , "first_scope" .= ("launch_scope" :: Text)
                  , "second_scope" .= ("maintain_scope" :: Text)
                  ]
              ]
          , coordinationStep "set-first-deadline" "SetBrickDeadline" (object
              [ "brick" .= ("$launch" :: Text)
              , "value" .= ("2026-08-01T18:00:00Z" :: Text)
              ]) Nothing
          , coordinationStep "set-second-deadline" "SetBrickDeadline" (object
              [ "brick" .= ("$maintain" :: Text)
              , "value" .= ("2026-09-01T18:00:00Z" :: Text)
              ]) Nothing
          , coordinationStep "emit-first-notice" "AdvanceTime" (object
              ["at" .= ("2026-07-27T15:00:00Z" :: Text)])
              (Just (object ["deadline_notice_for_copy" .= ("old_notice" :: Text)]))
          , coordinationStep "move-child" "MoveSubtreeUnderParent" (object
              [ "root" .= ("$copy" :: Text)
              , "new_parent" .= ("$maintain" :: Text)
              ]) (Just (object ["priority_insertion" .= ("new_insertion" :: Text)]))
          , coordinationStep "advance-near-new-deadline" "AdvanceTime" (object
              ["at" .= ("2026-08-27T15:00:00Z" :: Text)])
              (Just (object ["deadline_notice_for_copy" .= ("new_notice" :: Text)]))
          ]
      , "assertions" .=
          [ priorityAssertion "child-inherits-first-deadline-before-move"
              "set-second-deadline" "BrickSummary($copy)" "effective_deadline"
              "equals" (String "2026-08-01T18:00:00Z")
          , priorityAssertion "first-notice-uses-effective-fingerprint"
              "emit-first-notice" "DateNotice($old_notice)" "date_revision"
              "equals_reference" (String "BrickSummary($copy).effective_date_revision")
          , priorityAssertion "move-preserves-child-id-and-descendants" "move-child"
              "BrickSummary($copy)" "id" "equals_reference" (String "$copy")
          , priorityAssertion "move-recalculates-inherited-deadline" "move-child"
              "BrickSummary($copy)" "effective_deadline" "equals"
              (String "2026-09-01T18:00:00Z")
          , priorityAssertion "old-notice-is-resolved-not-deleted" "move-child"
              "DateNotice($old_notice)" "status" "equals" (String "resolved")
          , priorityAssertion "old-scope-judgments-become-historical" "move-child"
              "PriorityEvidenceFor($copy,$launch_scope)" "applicable" "all_equal"
              (Bool False)
          , priorityAssertion "new-scope-placement-is-provisional" "move-child"
              "PriorityInsertion($new_insertion)" "status" "equals"
              (String "deferred")
          , priorityAssertion "new-date-can-create-one-new-notice"
              "advance-near-new-deadline"
              "ActiveDateNotices($copy,deadline_approaching)" "items"
              "count_equals" (toJSON (1 :: Int))
          ]
      ]
  ]

coordinationStep :: Text -> Text -> Value -> Maybe Value -> Value
coordinationStep identifier operation arguments bindings = object
  ([ "id" .= identifier
   , "operation" .= operation
   , "arguments" .= arguments
   ] <> maybe [] (\value -> ["bind_result" .= value]) bindings)

materialScenario :: Value
materialScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("raw-source-reconciliation-unit" :: Text)
      , "clock" .= ("2026-07-27T16:00:00Z" :: Text)
      , "steps" .=
          [ object
              [ "id" .= ("create-brick" :: Text)
              , "operation" .= ("CreateFixture" :: Text)
              , "arguments" .= object
                  [ "fixture" .= ("active_root_brick" :: Text)
                  , "title" .= ("Implement issue 412" :: Text)
                  ]
              , "bind_result" .= object ["brick" .= ("brick" :: Text)]
              ]
          , object
              [ "id" .= ("capture-source" :: Text)
              , "operation" .= ("CaptureExternalRaw" :: Text)
              , "arguments" .= object
                  [ "title" .= ("Issue 412" :: Text)
                  , "adapter" .= ("github-issues" :: Text)
                  , "locator" .= ("https://example.test/issues/412" :: Text)
                  , "external_id" .= ("example#412" :: Text)
                  ]
              , "bind_result" .= object
                  [ "raw" .= ("raw" :: Text), "origin" .= ("origin" :: Text)]
              ]
          , object
              [ "id" .= ("capture-v1" :: Text)
              , "operation" .= ("CaptureRawSnapshot" :: Text)
              , "arguments" .= object
                  [ "raw" .= ("$raw" :: Text), "content_hash" .= ("sha256:v1" :: Text)
                  , "size" .= (1200 :: Int), "media_type" .= ("application/json" :: Text)
                  , "origin_revision" .= ("etag-1" :: Text)
                  ]
              , "bind_result" .= object ["snapshot" .= ("snapshot_v1" :: Text)]
              ]
          , object
              [ "id" .= ("link-source" :: Text)
              , "operation" .= ("LinkRawToBrick" :: Text)
              , "arguments" .= object
                  [ "raw" .= ("$raw" :: Text), "brick" .= ("$brick" :: Text)
                  , "role" .= ("source" :: Text), "baseline" .= ("$snapshot_v1" :: Text)
                  ]
              , "bind_result" .= object ["link" .= ("link" :: Text)]
              ]
          , object
              [ "id" .= ("capture-v2" :: Text)
              , "operation" .= ("CaptureRawSnapshot" :: Text)
              , "arguments" .= object
                  [ "raw" .= ("$raw" :: Text), "content_hash" .= ("sha256:v2" :: Text)
                  , "size" .= (1400 :: Int), "media_type" .= ("application/json" :: Text)
                  , "origin_revision" .= ("etag-2" :: Text)
                  ]
              , "bind_result" .= object ["snapshot" .= ("snapshot_v2" :: Text)]
              ]
          , object
              [ "id" .= ("observe-removed" :: Text)
              , "operation" .= ("RecordSourceObservation" :: Text)
              , "arguments" .= object
                  [ "origin" .= ("$origin" :: Text), "authority" .= ("adapter" :: Text)
                  , "external_observation_id" .= ("observation-3" :: Text)
                  , "revision" .= ("etag-3" :: Text), "presence" .= ("removed" :: Text)
                  , "work_state" .= ("unknown" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("reconcile" :: Text)
              , "operation" .= ("ReconcileRawLink" :: Text)
              , "arguments" .= object
                  ["link" .= ("$link" :: Text), "snapshot" .= ("$snapshot_v2" :: Text)]
              ]
          ]
      , "assertions" .=
          [ materialAssertion "new-snapshot-is-immutable-and-distinct" "capture-v2"
              "RawSnapshots($raw)" (Just "content_hashes") "equals_set"
              (toJSON (["sha256:v1", "sha256:v2"] :: [Text]))
          , materialAssertion "new-source-snapshot-proposes-reconciliation" "capture-v2"
              "OpenProposalsFor($brick)" (Just "kinds") "contains"
              (String "source_reconciliation")
          , materialAssertion "external-removal-is-not-local-done" "observe-removed"
              "BrickSummary($brick)" (Just "status") "equals" (String "active")
          , materialAssertion "external-removal-does-not-archive-raw" "observe-removed"
              "RawSummary($raw)" (Just "storage_state") "equals" (String "active")
          , object
              [ "id" .= ("observation-keeps-presence-separate-from-work-state" :: Text)
              , "after" .= ("observe-removed" :: Text)
              , "query" .= ("LatestSourceObservation($origin)" :: Text)
              , "operator" .= ("contains" :: Text)
              , "value" .= object
                  ["presence" .= ("removed" :: Text), "work_state" .= ("unknown" :: Text)]
              ]
          , object
              [ "id" .= ("reconciliation-advances-baseline-explicitly" :: Text)
              , "after" .= ("reconcile" :: Text)
              , "query" .= ("RawLink($link)" :: Text)
              , "path" .= ("reconciled_snapshot.id" :: Text)
              , "operator" .= ("equals_reference" :: Text)
              , "value" .= ("$snapshot_v2" :: Text)
              ]
          , materialAssertion "reconciliation-does-not-fetch-hidden-io" "reconcile"
              "ExternalIoTrace" (Just "implicit_reads") "count_equals" (toJSON (0 :: Int))
          ]
      ]
  ]

materialAssertion :: Text -> Text -> Text -> Maybe Text -> Text -> Value -> Value
materialAssertion identifier afterStep query path operator expected = object
  ([ "id" .= identifier
   , "after" .= afterStep
   , "query" .= query
   , "operator" .= operator
   , "value" .= expected
   ] <> maybe [] (\selected -> ["path" .= selected]) path)

planRequest :: Value
planRequest = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("domain" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "known" "invariant" "KnownConstruct"
          , obligation "unknown" "invariant" "MissingConstruct"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

duplicatePlanRequest :: Value
duplicatePlanRequest = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("allium_plan" :: Text)
  , "module" .= ("domain" :: Text)
  , "plan" .= object
      [ "version" .= (3 :: Int)
      , "obligations" .=
          [ obligation "known" "invariant" "KnownConstruct"
          , obligation "known" "invariant" "KnownConstruct"
          ]
      ]
  , "model" .= object ["version" .= (3 :: Int)]
  ]

obligation :: Text -> Text -> Text -> Value
obligation identifier category construct = object
  [ "id" .= identifier
  , "category" .= category
  , "source_construct" .= construct
  ]

bindingScenario :: Value
bindingScenario = scenarioRequest
  [ object
      [ "id" .= ("fixture" :: Text)
      , "operation" .= ("CreateFixture" :: Text)
      , "arguments" .= object ["fixture" .= ("binding_fixture" :: Text)]
      , "bind" .= ("whole" :: Text)
      , "bind_result" .= object
          [ "token" .= ("token" :: Text)
          , "numbers" .= (["one", "two"] :: [Text])
          ]
      ]
  , object
      [ "id" .= ("echo" :: Text)
      , "operation" .= ("Echo" :: Text)
      , "arguments" .= String "$token"
      , "bind" .= ("echoed" :: Text)
      ]
  ]
  [ assertion "complete-binding" "Argument($whole)" "contains"
      (object ["token" .= ("fixture-token" :: Text)])
  , assertion "scalar-binding" "Argument($echoed)" "equals_reference"
      (String "$token")
  , assertion "array-binding" "Argument($two)" "equals" (toJSON (2 :: Int))
  , assertion "expression" "Argument($two)" "equals_expression"
      (String "$one + 1")
  ]

checkpointScenario :: Value
checkpointScenario = scenarioRequest
  [ step "first" "Increment"
  , step "second" "Increment"
  ]
  [ object
      [ "id" .= ("after-first" :: Text)
      , "after" .= ("first" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals" :: Text)
      , "value" .= (1 :: Int)
      ]
  , object
      [ "id" .= ("before-second" :: Text)
      , "after" .= ("first" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals_snapshot" :: Text)
      , "value_from" .= ("before:second" :: Text)
      ]
  , object
      [ "id" .= ("at-anchor" :: Text)
      , "at" .= ("after:first" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals" :: Text)
      , "value" .= (1 :: Int)
      ]
  , assertion "at-final" "State" "equals" (toJSON (2 :: Int))
  ]

referenceScenario :: Value
referenceScenario = scenarioRequest
  [ step "bootstrap" "Increment"
  , object
      [ "id" .= ("capture-tax-brick" :: Text)
      , "operation" .= ("Echo" :: Text)
      , "arguments" .= ("brick:taxes" :: Text)
      , "bind" .= ("taxes" :: Text)
      ]
  , step "skip-once" "Increment"
  ]
  [ object
      [ "id" .= ("confidence-snapshot" :: Text)
      , "after" .= ("skip-once" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("greater_than" :: Text)
      , "value_from" .= ("confidence_before:skip-once" :: Text)
      ]
  , object
      [ "id" .= ("forecast-reference" :: Text)
      , "after" .= ("skip-once" :: Text)
      , "query" .= ("Argument(0.5)" :: Text)
      , "operator" .= ("greater_than" :: Text)
      , "value_from" .=
          ("forecast:before-skip:$taxes.probability" :: Text)
      ]
  ]

operationSnapshotScenario :: Value
operationSnapshotScenario = scenarioRequest
  [step "first" "Increment"]
  [ object
      [ "id" .= ("operation-snapshot" :: Text)
      , "after" .= ("first" :: Text)
      , "operation" .= ("ReplayFromEvents" :: Text)
      , "query" .= ("State" :: Text)
      , "operator" .= ("equals_snapshot" :: Text)
      , "value_from" .= ("after:first" :: Text)
      ]
  ]

localFixtureScenario :: Value
localFixtureScenario = scenarioWithAssertion (object
  [ "id" .= ("fixture-state" :: Text)
  , "fixture" .= ("state_five" :: Text)
  , "query" .= ("State" :: Text)
  , "operator" .= ("equals" :: Text)
  , "value" .= (5 :: Int)
  ])

ambientScenario :: Value
ambientScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("ambient" :: Text)
      , "clock" .= ("2026-07-27T12:00:00Z" :: Text)
      , "random_evidence" .= object ["seed" .= ("fixed" :: Text)]
      , "parameter_overrides" .= object ["limit" .= (2 :: Int)]
      , "steps" .=
          [ object
              [ "id" .= ("capture" :: Text)
              , "operation" .= ("CaptureAmbient" :: Text)
              , "bind" .= ("ambient" :: Text)
              ]
          ]
      , "assertions" .=
          [ assertion "pinned-context" "Argument($ambient)" "equals"
              (object
                [ "clock" .= ("2026-07-27T12:00:00Z" :: Text)
                , "random_evidence" .= object ["seed" .= ("fixed" :: Text)]
                , "parameter_overrides" .= object ["limit" .= (2 :: Int)]
                ])
          ]
      ]
  ]

isolatedScenario :: Value
isolatedScenario = scenarioRequest
  [ step "increment" "Increment"
  , object
      [ "id" .= ("capture-revision" :: Text)
      , "operation" .= ("Echo" :: Text)
      , "arguments" .= String "$current_domain_revision"
      , "bind" .= ("captured_revision" :: Text)
      ]
  ]
  [ assertion "one-in-first-request" "State" "equals" (toJSON (1 :: Int))
  , assertion "dynamic-revision-reference" "Argument($captured_revision)"
      "equals" (toJSON (1 :: Int))
  ]

unknownOperationScenario :: Value
unknownOperationScenario = scenarioRequest
  [step "unknown" "NotRegistered"]
  [assertion "still-returned" "State" "equals" (toJSON (0 :: Int))]

selectionForecastPersistenceScenario :: Value
selectionForecastPersistenceScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("selection-forecast-persistence-test" :: Text)
      , "clock" .= ("2026-07-27T12:00:00Z" :: Text)
      , "steps" .=
          [ object
              [ "id" .= ("create-work" :: Text)
              , "operation" .= ("CreateFixture" :: Text)
              , "arguments" .= object
                  [ "fixture" .= ("two_eligible_root_bricks" :: Text)
                  , "titles" .= (["Critical", "Background"] :: [Text])
                  ]
              ]
          , object
              [ "id" .= ("build" :: Text)
              , "operation" .= ("BuildForecast" :: Text)
              , "arguments" .= object
                  [ "at" .= ("2026-07-27T12:00:00Z" :: Text)
                  , "domain_revision" .= ("$current_domain_revision" :: Text)
                  ]
              , "bind" .= ("forecast" :: Text)
              ]
          , object
              [ "id" .= ("simulate" :: Text)
              , "operation" .= ("SimulateReplaySafeDraws" :: Text)
              , "arguments" .= object
                  [ "forecast" .= ("$forecast" :: Text)
                  , "samples" .= (1000 :: Int)
                  , "seed" .= ("persistence-test-seed" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("next" :: Text)
              , "operation" .= ("RequestNext" :: Text)
              , "arguments" .= object
                  [ "at" .= ("2026-07-27T12:00:00Z" :: Text)
                  , "domain_revision" .= ("$current_domain_revision" :: Text)
                  , "random_evidence" .= ("persistence-next-seed" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("inject-order" :: Text)
              , "operation" .= ("KernelSetValue" :: Text)
              , "arguments" .= object
                  [ "key" .= ("test.injected-forecast" :: Text)
                  , "value" .= ("$forecast" :: Text)
                  ]
              ]
          ]
      , "assertions" .=
          [ noStoredForecastAssertion "build-kept-forecast-derived" "build" 0
          , noStoredForecastAssertion
              "simulation-kept-forecast-derived" "simulate" 0
          , noStoredForecastAssertion "next-kept-forecast-derived" "next" 0
          , noStoredForecastAssertion
              "observation-detects-persisted-forecast" "inject-order" 1
          ]
      ]
  ]
  where
    noStoredForecastAssertion identifier checkpoint expected = object
      [ "id" .= (identifier :: Text)
      , "after" .= (checkpoint :: Text)
      , "query" .= ("CanonicalEntities" :: Text)
      , "path" .= ("stored_forecast_orders" :: Text)
      , "operator" .= ("count_equals" :: Text)
      , "value" .= (expected :: Int)
      ]

selectionForecastReferenceScenario :: Value
selectionForecastReferenceScenario = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("selection-reference-test" :: Text)
      , "clock" .= ("2026-07-27T13:00:00Z" :: Text)
      , "steps" .=
          [ object
              [ "id" .= ("create-work" :: Text)
              , "operation" .= ("CreateFixture" :: Text)
              , "arguments" .= object
                  [ "fixture" .= ("two_eligible_root_bricks" :: Text)
                  , "titles" .= (["Taxes", "Tidy"] :: [Text])
                  ]
              , "bind_result" .= object
                  [ "Taxes" .= ("taxes" :: Text)
                  , "Tidy" .= ("tidy" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("skip-once" :: Text)
              , "operation" .= ("SkipServedBrick" :: Text)
              , "arguments" .= object
                  [ "brick" .= ("$taxes" :: Text)
                  , "reason" .= ("vague" :: Text)
                  ]
              ]
          , object
              [ "id" .= ("cooldown-forecast" :: Text)
              , "operation" .= ("BuildForecast" :: Text)
              , "arguments" .= object
                  [ "at" .= ("2026-07-27T13:30:00Z" :: Text)
                  , "domain_revision" .= ("$current_domain_revision" :: Text)
                  ]
              , "bind" .= ("cooldown" :: Text)
              ]
          ]
      , "assertions" .=
          [ object
              [ "id" .= ("real-forecast-reference" :: Text)
              , "after" .= ("cooldown-forecast" :: Text)
              , "query" .= ("ForecastItem($cooldown,$taxes)" :: Text)
              , "path" .= ("probability" :: Text)
              , "operator" .= ("less_than" :: Text)
              , "value_from" .=
                  ("forecast:before-skip:$taxes.probability" :: Text)
              ]
          ]
      ]
  ]

scenarioWithAssertion :: Value -> Value
scenarioWithAssertion assertionValue = scenarioRequest [] [assertionValue]

scenarioRequest :: [Value] -> [Value] -> Value
scenarioRequest steps assertions = object
  [ "protocol_version" .= (1 :: Int)
  , "request_kind" .= ("scenario" :: Text)
  , "scenario" .= object
      [ "id" .= ("runner-test" :: Text)
      , "steps" .= steps
      , "assertions" .= assertions
      ]
  ]

step :: Text -> Text -> Value
step identifier operation = object
  [ "id" .= identifier
  , "operation" .= operation
  ]

assertion :: Text -> Text -> Text -> Value -> Value
assertion identifier query operator expected = object
  [ "id" .= identifier
  , "query" .= query
  , "operator" .= operator
  , "value" .= expected
  ]

declaredOperators :: [Text]
declaredOperators =
  [ "all_equal", "all_match", "all_omit", "all_unique_by"
  , "all_within_absolute_tolerance", "between_inclusive", "contains"
  , "contains_all", "contains_once", "contains_references", "count_equals"
  , "equals", "equals_expression", "equals_reference", "equals_set"
  , "equals_snapshot", "greater_than", "is_null", "less_than"
  , "not_contains", "not_empty", "not_equals", "omits", "omits_paths"
  , "rejected_with", "results_in", "schema_presence_matches_projection"
  , "unique_by"
  ]

assertOperator :: Text -> Value -> Maybe Value -> Object -> Assertion
assertOperator name actual expected metadata =
  case evaluateAssertionOperator standardAssertionOperators
      name actual expected metadata of
    Left problem -> assertFailure
      (Text.unpack (name <> " unexpectedly failed: " <> problem))
    Right () -> pure ()

assertResponsePassed :: DriverResponse -> [Text] -> Assertion
assertResponsePassed response expectedIds = do
  map resultItemId (driverResponseResults response) @?= expectedIds
  map resultItemPassed (driverResponseResults response) @?=
    replicate (length expectedIds) True
  driverResponseOk response @?= True

assertSingleFailure :: Text -> Value -> Assertion
assertSingleFailure detail request = do
  let response = runContractRequest testRegistry request
  case driverResponseResults response of
    [result] -> do
      resultItemPassed result @?= False
      assertDetailContains detail result
    results -> assertFailure ("unexpected results: " <> show results)

assertDetailContains :: Text -> ResultItem -> Assertion
assertDetailContains expected result = case resultItemDetail result of
  Nothing -> assertFailure "result has no failure detail"
  Just detail -> assertBool
    ("detail does not contain " <> Text.unpack expected <> ": " <> Text.unpack detail)
    (expected `Text.isInfixOf` detail)

requireKernelSuccess ::
  Either KernelError AppendResult -> IO AppendResult
requireKernelSuccess result = case result of
  Left problem -> assertFailure ("kernel action failed: " <> show problem)
  Right accepted -> pure accepted

requireDomainSuccess :: Show problem => Either problem value -> IO value
requireDomainSuccess result = case result of
  Left problem -> assertFailure ("domain operation failed: " <> show problem)
  Right value -> pure value

requireExecutionSuccess :: Either Execution.ExecutionError value -> IO value
requireExecutionSuccess result = case result of
  Left problem -> assertFailure ("execution operation failed: " <> show problem)
  Right value -> pure value

requireCoordinationSuccess ::
  Either Coordination.CoordinationError value -> IO value
requireCoordinationSuccess result = case result of
  Left problem -> assertFailure ("coordination operation failed: " <> show problem)
  Right value -> pure value

coordinationFixture :: Text -> IO (Party, Brick, Coordination.CoordinationState)
coordinationFixture title = do
  (party, first) <- requireCoordinationSuccess
    (Coordination.createCoordinationParty "Contract user" Person domainTestTime
      Coordination.emptyCoordinationState)
  (brick, second) <- createUnitCoordinationBrick title standardV1 Nothing first
  pure (party, brick, second)

createUnitCoordinationBrick ::
  Text -> BrickBehavior -> Maybe BrickId -> Coordination.CoordinationState ->
  IO (Brick, Coordination.CoordinationState)
createUnitCoordinationBrick title behavior parent state = do
  canonical <- requireDomainSuccess (mkCanonicalText title Nothing Human)
  (brick, _, next) <- requireCoordinationSuccess
    (Coordination.createCoordinationBrick
      ((ordinaryBrickDraft canonical behavior domainTestTime)
        {brickDraftParent = parent}) ("unit:" <> title) domainTestTime state)
  pure (brick, next)

createUnitExecutionBrick ::
  Text -> BrickBehavior -> Maybe BrickId -> Execution.ExecutionState ->
  IO (Brick, Execution.ExecutionState)
createUnitExecutionBrick title behavior parent state = do
  canonical <- requireDomainSuccess (mkCanonicalText title Nothing Human)
  (brick, _, next) <- requireExecutionSuccess (Execution.createExecutionBrick
    ((ordinaryBrickDraft canonical behavior domainTestTime)
      {brickDraftParent = parent}) ("unit:" <> title) domainTestTime state)
  pure (brick, next)

createUnitStandingBrick ::
  Text -> BrickBehavior -> Standing.StandingState ->
  IO (Brick, Standing.StandingState)
createUnitStandingBrick title behavior state = do
  canonical <- requireDomainSuccess (mkCanonicalText title Nothing Human)
  (brick, _, next) <- requireStandingSuccess (Standing.createStandingBrick
    (ordinaryBrickDraft canonical behavior domainTestTime)
    ("unit:" <> title) domainTestTime state)
  pure (brick, next)

createUnitStandingChild ::
  Text -> BrickBehavior -> BrickId -> Standing.StandingState ->
  IO (Brick, Standing.StandingState)
createUnitStandingChild title behavior parent state = do
  canonical <- requireDomainSuccess (mkCanonicalText title Nothing Human)
  (brick, _, next) <- requireStandingSuccess (Standing.createStandingBrick
    ((ordinaryBrickDraft canonical behavior domainTestTime)
      {brickDraftParent = Just parent}) ("unit:" <> title) domainTestTime state)
  pure (brick, next)

assertStandingTerminalTransition :: BrickStatus -> Assertion
assertStandingTerminalTransition status = do
  (target, first) <- createUnitStandingBrick "Terminal practice" practiceV1
    Standing.emptyStandingState
  (replacement, second) <- createUnitStandingBrick "Replacement practice" practiceV1
    first
  (source, third) <- createUnitStandingBrick "Trigger source" standingChecklistV1
    second
  (rule, fourth) <- requireStandingSuccess (Standing.configureRecurrence
    (brickId target) Standing.PracticeRecurrence "2 times per ISO week" "UTC"
    domainTestTime domainTestTime third)
  (_, opportunities, fifth) <- requireStandingSuccess
    (Standing.advanceSchedules domainTestTime fourth)
  (incoming, sixth) <- requireStandingSuccess (Standing.configureOpportunityTrigger
    (brickId source) (brickId target) domainTestTime fifth)
  (outgoing, seventh) <- requireStandingSuccess (Standing.configureOpportunityTrigger
    (brickId target) (brickId replacement) domainTestTime sixth)
  terminal <- case status of
    Done -> requireStandingSuccess
      (Standing.retireStandingTarget (brickId target) domainTestTime seventh)
    Dropped -> requireStandingSuccess
      (Standing.dropStandingBrick (brickId target) domainTestTime seventh)
    Superseded -> requireStandingSuccess
      (Standing.supersedeStandingBrick (brickId target) (brickId replacement)
        (Just "method changed") domainTestTime seventh)
    Active -> assertFailure "active is not a terminal test transition"
  assertTerminalStandingMechanics status target rule opportunities
    [incoming, outgoing] domainTestTime terminal

assertStandingTerminalSubtree :: BrickStatus -> Assertion
assertStandingTerminalSubtree status = do
  (root, first) <- createUnitStandingBrick "Standing collection" collectionV1
    Standing.emptyStandingState
  (target, second) <- createUnitStandingChild "Nested practice" practiceV1
    (brickId root) first
  (rule, third) <- requireStandingSuccess (Standing.configureRecurrence
    (brickId target) Standing.PracticeRecurrence "2 times per ISO week" "UTC"
    domainTestTime domainTestTime second)
  (_, opportunities, fourth) <- requireStandingSuccess
    (Standing.advanceSchedules domainTestTime third)
  (trigger, fifth) <- requireStandingSuccess (Standing.configureOpportunityTrigger
    (brickId root) (brickId target) domainTestTime fourth)
  terminal <- requireStandingSuccess
    (Standing.closeStandingSubtree (brickId root) status domainTestTime fifth)
  fmap brickStatus (lookupStandingBrick (brickId root) terminal) @?= Just status
  assertTerminalStandingMechanics status target rule opportunities [trigger]
    domainTestTime terminal

assertTerminalStandingMechanics ::
  BrickStatus -> Brick -> Standing.RecurrenceRule ->
  [Standing.PracticeOpportunity] -> [Standing.OpportunityTrigger] -> UTCTime ->
  Standing.StandingState -> Assertion
assertTerminalStandingMechanics status target rule opportunities triggers now state = do
  fmap brickStatus (lookupStandingBrick (brickId target) state) @?= Just status
  fmap Standing.recurrenceRuleStatus
    (Map.lookup (Standing.recurrenceRuleId rule)
      (Standing.standingStateRecurrences state)) @?= Just Standing.ScheduleRetired
  mapM_ (assertOpportunityClosed state) opportunities
  mapM_ (assertTriggerRetired state) triggers
  requireStandingSuccess (Standing.validateStandingState state)
  where
    assertOpportunityClosed current original = do
      let retained = Map.lookup (Standing.practiceOpportunityId original)
            (Standing.standingStatePracticeOpportunities current)
      fmap Standing.practiceOpportunityStatus retained @?=
        Just Standing.OpportunityNotApplicable
      fmap Standing.practiceOpportunityResolvedAt retained @?= Just (Just now)
      fmap Standing.practiceOpportunityReason retained @?=
        Just (Just "target_terminal")
    assertTriggerRetired current original =
      fmap Standing.opportunityTriggerStatus
        (Map.lookup (Standing.opportunityTriggerId original)
          (Standing.standingStateOpportunityTriggers current)) @?=
            Just Standing.TriggerRetired

lookupStandingBrick :: BrickId -> Standing.StandingState -> Maybe Brick
lookupStandingBrick identifier state = Map.lookup identifier
  (domainBricks (Execution.executionStateDomain
    (Coordination.coordinationStateExecution
      (Standing.standingStateCoordination state))))

requireStandingSuccess :: Either Standing.StandingError value -> IO value
requireStandingSuccess result = case result of
  Left problem -> assertFailure ("unexpected standing error: " <> show problem)
  Right value -> pure value

requireSelectionSuccess :: Either Selection.SelectionError value -> IO value
requireSelectionSuccess result = case result of
  Left problem -> assertFailure ("selection action failed: " <> show problem)
  Right value -> pure value

selectionFixture :: [(Text, BrickBehavior)] -> IO ([Brick], Selection.SelectionContext)
selectionFixture values = do
  (reversed, standing) <- foldM create
    ([], Standing.emptyStandingState) values
  let bricks = reverse reversed
      material = foldr (\brick -> registerMaterialBrick (brickId brick) Active)
        emptyMaterialState bricks
  pure (bricks, Selection.SelectionContext standing material)
  where
    create (bricks, standing) (titleText, behavior) = do
      title <- requireDomainSuccess (mkCanonicalText titleText Nothing Human)
      (brick, _, next) <- requireStandingSuccess (Standing.createStandingBrick
        (ordinaryBrickDraft title behavior domainTestTime)
        ("test:" <> titleText) domainTestTime standing)
      pure (brick : bricks, next)

captureFixture :: IO (Brick, ListEntry, Raw, Capture.CaptureContext)
captureFixture = do
  title <- requireDomainSuccess
    (mkCanonicalText "Buy groceries" Nothing Human)
  (owner, _, first) <- requireStandingSuccess (Standing.createStandingBrick
    (ordinaryBrickDraft title standingChecklistV1 domainTestTime)
    "test:capture-owner" domainTestTime Standing.emptyStandingState)
  label <- requireDomainSuccess (mkCanonicalText "Milk" (Just "leite") Ai)
  (entry, second) <- requireStandingSuccess (Standing.addStandingListEntry
    (ListEntryDraft (brickId owner) label Nothing Nothing domainTestTime) first)
  (raw, captured) <- requireMaterialSuccess (captureInlineRaw "source note"
    (Just "source note") (Just Human) domainTestTime emptyMaterialState)
  let material = registerMaterialListEntry (listEntryId entry)
        (registerMaterialBrick (brickId owner) Active captured)
  pure (owner, entry, raw, Capture.CaptureContext second material)

captureTestDomain :: Capture.CaptureContext -> DomainState
captureTestDomain = Execution.executionStateDomain
  . Coordination.coordinationStateExecution
  . Standing.standingStateCoordination
  . Capture.captureContextStanding

capturePriorityMemberships :: BrickId -> Capture.CaptureContext -> Int
capturePriorityMemberships identifier context = length
  [() | scope <- Map.elems (Priority.priorityStateScopes priority),
    identifier `elem` Priority.priorityScopeMembers scope]
  where
    priority = Execution.executionStatePriority
      . Coordination.coordinationStateExecution
      . Standing.standingStateCoordination
      $ Capture.captureContextStanding context

requireCaptureSuccess :: Either Capture.CaptureError value -> IO value
requireCaptureSuccess result = case result of
  Left problem -> assertFailure ("capture action failed: " <> show problem)
  Right value -> pure value

requireInteractionSuccess :: Either Interaction.InteractionError value -> IO value
requireInteractionSuccess result = case result of
  Left problem -> assertFailure ("interaction action failed: " <> show problem)
  Right value -> pure value

focusSelectionContext :: BrickId -> Selection.SelectionContext ->
  IO Selection.SelectionContext
focusSelectionContext identifier context = do
  let standing = Selection.selectionContextStanding context
      coordination = Standing.standingStateCoordination standing
  execution <- requireExecutionSuccess (Execution.focusExecutionBrick identifier
    domainTestTime (Coordination.coordinationStateExecution coordination))
  let standing' = standing {Standing.standingStateCoordination = coordination
        {Coordination.coordinationStateExecution = execution}}
  requireStandingSuccess (Standing.validateStandingState standing')
  pure context {Selection.selectionContextStanding = standing'}

requireExactlyTwo :: String -> [value] -> IO (value, value)
requireExactlyTwo _ [first, second] = pure (first, second)
requireExactlyTwo label values = assertFailure (label <> " expected two values, found "
  <> show (length values))

requireSelectionForecastItem :: BrickId -> Selection.ForecastView ->
  IO Selection.ForecastItem
requireSelectionForecastItem identifier forecast = maybe
  (assertFailure "forecast omitted expected Brick") pure
  (Selection.forecastItemForBrick identifier forecast)

standingWeek :: NominalDiffTime
standingWeek = 7 * 24 * 60 * 60

requireExactlyOneScope ::
  Maybe BrickId -> Priority.PriorityState -> IO Priority.PriorityScope
requireExactlyOneScope parent state = case filter
    ((== parent) . Priority.priorityScopeParent)
    (Map.elems (Priority.priorityStateScopes state)) of
  [scope] -> pure scope
  scopes -> assertFailure ("unexpected priority scopes: " <> show scopes)

requireMaterialSuccess :: Either MaterialError value -> IO value
requireMaterialSuccess result = case result of
  Left problem -> assertFailure ("material operation failed: " <> show problem)
  Right value -> pure value

requirePrioritySuccess :: Either Priority.PriorityError value -> IO value
requirePrioritySuccess result = case result of
  Left problem -> assertFailure ("priority operation failed: " <> show problem)
  Right value -> pure value

requireJudgmentSuccess :: Either Judgment.JudgmentError value -> IO value
requireJudgmentSuccess result = case result of
  Left problem -> assertFailure ("judgment operation failed: " <> show problem)
  Right value -> pure value

judgmentFixtureState ::
  IO (BrickId, BrickId, BrickId, BrickId, Judgment.JudgmentState)
judgmentFixtureState = do
  let rootA = BrickId "test:judgment:root-a"
      rootB = BrickId "test:judgment:root-b"
      child = BrickId "test:judgment:child"
      disabled = BrickId "test:judgment:disabled"
  first <- requireJudgmentSuccess
    (Judgment.registerJudgmentBrick rootA Nothing Active True
      Judgment.emptyJudgmentState)
  second <- requireJudgmentSuccess
    (Judgment.registerJudgmentBrick rootB Nothing Active True first)
  third <- requireJudgmentSuccess
    (Judgment.registerJudgmentBrick child (Just rootA) Active True second)
  final <- requireJudgmentSuccess
    (Judgment.registerJudgmentBrick disabled Nothing Active False third)
  pure (rootA, rootB, child, disabled, final)

requireNamedPriority :: Text -> Map.Map Text BrickId -> IO BrickId
requireNamedPriority title values = maybe
  (assertFailure ("priority fixture title is missing: " <> Text.unpack title))
  pure
  (Map.lookup title values)

requireCreatedSnapshot :: SnapshotCaptureResult -> IO RawSnapshot
requireCreatedSnapshot result = case result of
  SnapshotCreated snapshot -> pure snapshot
  SnapshotReused snapshot -> assertFailure
    ("expected a new snapshot, reused: " <> show (rawSnapshotId snapshot))

domainTestTime :: UTCTime
domainTestTime = UTCTime (fromGregorian 2026 7 27) 0

objectMap :: [AesonTypes.Pair] -> Object
objectMap = objectValue

emptyObject :: Object
emptyObject = KeyMap.empty

objectValue :: [AesonTypes.Pair] -> Object
objectValue pairs = case object pairs of
  Object value -> value
  _ -> KeyMap.empty

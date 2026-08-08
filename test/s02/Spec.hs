module Main (main) where

import Control.Monad (foldM)
import Data.Aeson (eitherDecode, encode)
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Catalog
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Store
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "S02 domain foundation"
    [ testCase "factory catalog is complete, versioned, and compatible" $ do
        validateFactoryCatalog @?= Right ()
        length factoryNatures @?= 9
        fmap natureValue factoryNatures @?= [AtomicTask, Project, Collection, FiniteChecklist, LivingChecklist, Repeatable, RecurringObligation, Habit, ScheduledCommitment]
        assertBool "the offline catalog is intentionally broad" (length factoryTemplates >= 80)
        assertBool "feature backlog remains a collection" (matchesTemplate "feature_backlog" Collection)
        assertBool "trip checklist is understandable" (matchesTemplate "trip_checklist" FiniteChecklist)
    , testCase "singleton materialization is one replayable atomic command group" $ do
        (state, raw, sourceCommand) <- stateWithRaw "fix a bug on website" 10
        facts <- factsFrom 100 6
        let draft =
              WorkDraft
                (rawId raw)
                "Fix a bug on website"
                AtomicTask
                (Just (TemplateSelection "bug_fix" "factory@1" "factory"))
                Nothing
                Set.empty
                0
                (DeterministicPosition "sole_sibling")
                []
        decision <- assertRight (decideMaterializeWork state actor draft facts)
        length (mutationDecisionEvents decision) @?= 3
        let commandIds = fmap draftCommandId (mutationDecisionEvents decision)
        assertBool "one command identity" (all (== mutationDecisionCommandId decision) commandIds)
        (_, bytes, events) <- pure (encodeSegment 2 "previous" (mutationDecisionEvents decision))
        replayed <- assertRight (foldM applyEvent state events)
        Map.size (stateBricks replayed) @?= 1
        Map.size (stateRawLinks replayed) @?= 1
        Map.lookup (rawId raw) (stateRawDispositions replayed) @?= RawMaterializedAsWork . brickId <$> mutationDecisionBrick decision
        inboxRaws replayed @?= []
        Map.member sourceCommand (stateCommandEffects replayed) @? "Feed history must remain inspectable"
        traverse decodeEvent (init (ByteString.split 10 bytes)) @?= Right events
    , testCase "draft comparisons reject a Brick under another parent" $ do
        (base, raw, _) <- stateWithRaw "new child" 200
        parentA <- testUuid 230
        parentB <- testUuid 231
        child <- testUuid 232
        let existing = fixtureBrick child (Handle "existing") "Existing" (Just parentB) 0
            parentOne = fixtureBrick parentA (Handle "a") "A" Nothing 0
            parentTwo = fixtureBrick parentB (Handle "b") "B" Nothing 1
            state =
              base
                { stateBricks = Map.fromList [(parentA, parentOne), (parentB, parentTwo), (child, existing)]
                , stateBrickHandles = Map.fromList [(Handle "a", parentA), (Handle "b", parentB), (Handle "existing", child)]
                , stateRetiredBrickHandles = Set.fromList [Handle "a", Handle "b", Handle "existing"]
                }
            draft = WorkDraft (rawId raw) "Draft" AtomicTask Nothing (Just parentA) Set.empty 0 HumanComparison [DraftAbove child]
        materializeFacts <- factsFrom 240 7
        assertErrorCode InvalidInput (decideMaterializeWork state actor draft materializeFacts)
    , testCase "duplicate receipt grouping preserves both Raw identities" $ do
        (firstState, firstRaw, _) <- stateWithRaw "milk" 300
        (secondState, secondRaw) <- addRaw firstState "milk" 320
        duplicateFacts <- factsFrom 340 4
        decision <- assertRight (decideRawDuplicateYes secondState actor (rawId secondRaw) (rawId firstRaw) duplicateFacts)
        replayed <- foldDecision secondState decision
        Map.size (stateRaws replayed) @?= 2
        Map.lookup (rawId secondRaw) (stateRawDispositions replayed) @?= Just (RawGroupedAsDuplicate (rawId firstRaw))
        assertBool "duplicate_of remains an explicit link" (any ((== DuplicateOfRole) . rawLinkRole) (Map.elems (stateRawLinks replayed)))
        inboxRaws replayed @?= [firstRaw]
    , testCase "rejecting duplicate suspicion records no disposition" $ do
        (firstState, firstRaw, _) <- stateWithRaw "milk" 400
        (secondState, secondRaw) <- addRaw firstState "milk" 420
        noFacts <- factsFrom 440 2
        decision <- assertRight (decideRawDuplicateNo secondState actor (rawId secondRaw) (rawId firstRaw) noFacts)
        replayed <- foldDecision secondState decision
        Map.lookup (rawId secondRaw) (stateRawDispositions replayed) @?= Nothing
        length (inboxRaws replayed) @?= 2
    , testCase "standalone disposition removes only the Raw from Inbox" $ do
        (state, raw, _) <- stateWithRaw "a useful note" 500
        keepFacts <- factsFrom 520 2
        decision <- assertRight (decideKeepRawStandalone state actor (rawId raw) keepFacts)
        replayed <- foldDecision state decision
        Map.lookup (rawId raw) (stateRawDispositions replayed) @?= Just RawKeptStandalone
        Map.size (stateRaws replayed) @?= 1
        stateBricks replayed @?= Map.empty
        stateRawLinks replayed @?= Map.empty
    , testCase "triage deferral is contiguous and preserves Inbox" $ do
        (state, raw, _) <- stateWithRaw "later" 600
        firstFacts <- factsFrom 620 2
        first <- assertRight (decideDeferRawTriage state actor (rawId raw) firstFacts)
        once <- foldDecision state first
        Map.lookup (rawId raw) (stateRawTriageDeferrals once) @?= Just 1
        secondFacts <- factsFrom 640 2
        second <- assertRight (decideDeferRawTriage once actor (rawId raw) secondFacts)
        twice <- foldDecision once second
        Map.lookup (rawId raw) (stateRawTriageDeferrals twice) @?= Just 2
        length (inboxRaws twice) @?= 1
    , testCase "RawShelf creation and membership are one replayable command group" $ do
        (state, raw, _) <- stateWithRaw "an article" 800
        shelfFacts <- factsFrom 820 5
        decision <- assertRight (decideCreateRawShelf state actor (rawId raw) "Technical articles" shelfFacts)
        length (mutationDecisionEvents decision) @?= 3
        let (_, bytes, events) = encodeSegment 2 "previous" (mutationDecisionEvents decision)
        traverse decodeEvent (init (ByteString.split 10 bytes)) @?= Right events
        replayed <- assertRight (foldM applyEvent state events)
        shelf <- case Map.elems (stateRawShelves replayed) of
          [value] -> pure value
          values -> assertFailure ("expected one RawShelf, got " <> show values)
        rawShelfName shelf @?= "Technical articles"
        rawShelfMembers shelf @?= [rawId raw]
        Map.lookup (rawId raw) (stateRawDispositions replayed) @?= Just (RawPlacedOnShelf (rawShelfId shelf))
        assertBool "the complete group uses one command identity" (all ((== mutationDecisionCommandId decision) . persistedCommandId) events)
    , testCase "description cardinality is rejected before allocation and remains a replay invariant" $ do
        (base, sourceRaw, _) <- stateWithRaw "make a Brick" 900
        materializeFacts <- factsFrom 920 6
        materialized <- assertRight (decideMaterializeWork base actor (singletonDraft sourceRaw) materializeFacts)
        withBrick <- foldDecision base materialized
        brick <- maybe (assertFailure "no created Brick") pure (mutationDecisionBrick materialized)
        (withSecondRaw, secondRaw) <- addRaw withBrick "first description" 940
        firstAttachFacts <- factsFrom 960 4
        firstAttach <- assertRight (decideAttachRaw withSecondRaw actor (rawId secondRaw) (brickId brick) DescriptionRole firstAttachFacts)
        described <- foldDecision withSecondRaw firstAttach
        (withThirdRaw, thirdRaw) <- addRaw described "second description" 980
        secondAttachFacts <- factsFrom 1000 4
        assertErrorCode InvalidInput (decideAttachRaw withThirdRaw actor (rawId thirdRaw) (brickId brick) DescriptionRole secondAttachFacts)
    , testCase "optional Domain proposal is explicit and checkpoint-codec stable" $ do
        (base, raw, _) <- stateWithRaw "domain child" 1020
        parentId <- testUuid 1040
        domainId <- testUuid 1041
        interactionId <- testUuid 1042
        let parent = (fixtureBrick parentId (Handle "parent") "Parent" Nothing 0){brickDomains = Set.singleton domainId}
            domain = Domain domainId "Rock Splitter" Nothing True
            state =
              base
                { stateBricks = Map.singleton parentId parent
                , stateBrickHandles = Map.singleton (Handle "parent") parentId
                , stateRetiredBrickHandles = Set.singleton (Handle "parent")
                , stateDomains = Map.singleton domainId domain
                }
            draft = WorkDraft (rawId raw) "Domain child" AtomicTask Nothing (Just parentId) (Set.singleton domainId) 0 (Provisional "importance insertion pending") []
            previous = makeRawTriageEnvelope interactionId Genesis (statePreconditionHash state) (utcToZonedTime utc fixedTime) state raw
            envelope = makeDomainSelectionEnvelope previous (utcToZonedTime utc fixedTime) state raw draft [domainId]
        assertBool "the parent Domain is visibly selected" (any ((== "domain.toggle." <> renderUUIDv7 domainId) . actionId) (envelopeActions envelope))
        eitherDecode (encode envelope) @?= Right envelope
    , testCase "ListEntry creation and quantity addition retain complete undo evidence" $ do
        (base, checklistRaw, _) <- stateWithRaw "buy groceries" 1060
        checklistFacts <- factsFrom 1080 6
        let checklistDraft = (singletonDraft checklistRaw){workDraftTitle = "Buy groceries", workDraftNature = LivingChecklist}
        checklistDecision <- assertRight (decideMaterializeWork base actor checklistDraft checklistFacts)
        withChecklist <- foldDecision base checklistDecision
        owner <- maybe (assertFailure "no checklist Brick") pure (mutationDecisionBrick checklistDecision)
        (withMilk, milkRaw) <- addRaw withChecklist "milk" 1100
        entryFacts <- factsFrom 1120 6
        entryDecision <- assertRight (decideMaterializeListEntry withMilk actor (rawId milkRaw) (brickId owner) "Milk" (Quantity 1 0 "item") entryFacts)
        withEntry <- foldDecision withMilk entryDecision
        entry <- case Map.elems (stateListEntries withEntry) of
          [value] -> pure value
          values -> assertFailure ("expected one ListEntry, got " <> show values)
        createdEffect <- maybe (assertFailure "missing ListEntry materialization effect") pure (Map.lookup (mutationDecisionCommandId entryDecision) (stateMaterializationEffects withEntry))
        materializationEntryIds createdEffect @?= [listEntryId entry]

        (withMoreMilk, moreMilkRaw) <- addRaw withEntry "milk" 1140
        quantityFacts <- factsFrom 1160 5
        quantityDecision <- assertRight (decideAddListEntryQuantity withMoreMilk actor (rawId moreMilkRaw) (listEntryId entry) (Quantity 1 0 "item") quantityFacts)
        let (_, bytes, events) = encodeSegment 5 "previous" (mutationDecisionEvents quantityDecision)
        traverse decodeEvent (init (ByteString.split 10 bytes)) @?= Right events
        withQuantity <- assertRight (foldM applyEvent withMoreMilk events)
        quantityEffect <- maybe (assertFailure "missing quantity compensation evidence") pure (Map.lookup (mutationDecisionCommandId quantityDecision) (stateMaterializationEffects withQuantity))
        materializationPreviousQuantities quantityEffect @?= Map.singleton (listEntryId entry) (Quantity 1 0 "item")
        listEntryQuantity <$> Map.lookup (listEntryId entry) (stateListEntries withQuantity) @?= Just (Quantity 2 0 "item")
    , testCase "focus and done keep one direct finite Work lifecycle" $ do
        (state, raw, _) <- stateWithRaw "finish me" 700
        materializeFacts <- factsFrom 720 6
        materialized <- assertRight (decideMaterializeWork state actor (singletonDraft raw) materializeFacts)
        created <- foldDecision state materialized
        brick <- maybe (assertFailure "no created Brick") pure (mutationDecisionBrick materialized)
        focusFacts <- factsFrom 740 2
        focusedDecision <- assertRight (decideFocusBrick created actor (brickId brick) focusFacts)
        focused <- foldDecision created focusedDecision
        stateCurrentFocus focused @?= Just (brickId brick)
        brickWorkState <$> Map.lookup (brickId brick) (stateBricks focused) @?= Just Wip
        doneFacts <- factsFrom 760 2
        doneDecision <- assertRight (decideCompleteBrick focused actor (brickId brick) doneFacts)
        completed <- foldDecision focused doneDecision
        stateCurrentFocus completed @?= Nothing
        brickStatus <$> Map.lookup (brickId brick) (stateBricks completed) @?= Just BrickDone
    ]

matchesTemplate :: Text.Text -> BrickNature -> Bool
matchesTemplate identifier nature = maybe False ((== nature) . templateNature) (findTemplate identifier)

actor :: Actor
actor = Actor "human" "test"

stateWithRaw :: Text.Text -> Int -> IO (State, Raw, UUIDv7)
stateWithRaw material seed = do
  feedFacts <- factsFrom seed 3
  decision <- assertRight (decideFeed emptyState actor "test" material feedFacts)
  let (_, _, events) = encodeSegment 1 "genesis" (feedDecisionEvents decision)
  state <- assertRight (foldM applyEvent emptyState events)
  pure (state, feedDecisionRaw decision, feedDecisionCommandId decision)

addRaw :: State -> Text.Text -> Int -> IO (State, Raw)
addRaw state material seed = do
  feedFacts <- factsFrom seed 3
  decision <- assertRight (decideFeed state actor "test" material feedFacts)
  let (_, _, events) = encodeSegment 2 "previous" (feedDecisionEvents decision)
  replayed <- assertRight (foldM applyEvent state events)
  pure (replayed, feedDecisionRaw decision)

foldDecision :: State -> MutationDecision -> IO State
foldDecision state decision = do
  let (_, _, events) = encodeSegment (stateEventCount state + 1) "previous" (mutationDecisionEvents decision)
  assertRight (foldM applyEvent state events)

singletonDraft :: Raw -> WorkDraft
singletonDraft raw =
  WorkDraft (rawId raw) "Finish me" AtomicTask Nothing Nothing Set.empty 0 (DeterministicPosition "sole_sibling") []

fixtureBrick :: UUIDv7 -> Handle -> Text.Text -> Maybe UUIDv7 -> Int -> Brick
fixtureBrick identity handle title parent position =
  Brick identity handle title Project "factory@1" "human" Nothing parent Set.empty position (DeterministicPosition "fixture") BrickActive Idle fixedTime actor identity

factsFrom :: Int -> Int -> IO RuntimeFacts
factsFrom seed count = do
  identities <- traverse testUuid [seed .. seed + count - 1]
  pure
    RuntimeFacts
      { runtimeNow = fixedTime
      , runtimeUUIDs = fmap (UUIDAllocation . renderUUIDv7) identities
      , runtimeRandomBlocks = mempty
      , runtimeFilesystem = FilesystemFacts False True (Just "fixture")
      , runtimeTerminal = TerminalCapabilities False False False 80 24 False
      , runtimeExternalFacts = []
      }

testUuid :: Int -> IO UUIDv7
testUuid seed =
  assertRight $
    uuidV7FromEntropy
      (0x0198f8a34c21 + fromIntegral seed)
      (ByteString.replicate 10 (fromIntegral (seed `mod` 251 + 1)))

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertErrorCode :: ErrorCode -> Either AppError value -> Assertion
assertErrorCode expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure "expected a typed error"

module Main (main) where

import Data.ByteString qualified as ByteString
import Data.Char (isAsciiLower)
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision (WorkDraft (..))
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Result
import LittleAnt.Store
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "S02 daily loop"
    [ testCase "Raw becomes finite Work and reaches focus/done through canonical envelopes" $ withHarness $ \environment -> do
        fed <- run environment (FeedCommand "test" "fix a bug on website")
        rawTriage <- interactionOf fed
        assertOpportunity "raw triage" isRawTriage rawTriage

        natureChoice <- answer environment rawTriage "raw.materialize-work"
        assertOpportunity "Nature choice" isNatureChoice natureChoice

        templateChoice <- answer environment natureChoice "nature.choose.atomic_task"
        assertOpportunity "Template choice" isTemplateChoice templateChoice

        title <- answer environment templateChoice "template.none"
        case envelopeOpportunity title of
          WorkTitleOpportunity _ AtomicTask Nothing suggested -> suggested @?= "Fix a bug on website"
          other -> assertFailure ("expected Work title, got " <> show other)

        preview <- submit environment title "work.title.submit" "Fix a bug on website"
        case envelopeOpportunity preview of
          WorkPreviewOpportunity draft -> do
            workDraftNature draft @?= AtomicTask
            workDraftSiblingPosition draft @?= 0
            workDraftImportanceConfidence draft @?= DeterministicPosition "sole_sibling"
          other -> assertFailure ("expected Work preview, got " <> show other)

        created <- answer environment preview "work.create"
        assertOpportunity "creation result" isCreated created

        proposal <- answer environment created "next"
        assertOpportunity "focus proposal" isFocusProposal proposal

        focused <- answer environment proposal "focus.accept"
        assertOpportunity "current focus" isCurrentFocus focused

        completed <- answer environment focused "focus.done"
        assertOpportunity "completion result" isCompleted completed

        empty <- answer environment completed "next"
        assertOpportunity "safe empty" (== SafeEmptyOpportunity) empty

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        Map.size (stateRaws (loadedState loaded)) @?= 1
        Map.size (stateBricks (loadedState loaded)) @?= 1
        fmap brickStatus (Map.elems (stateBricks (loadedState loaded))) @?= [BrickDone]
        stateCurrentFocus (loadedState loaded) @?= Nothing
    , testCase "pending draft survives restart and local back/forward emit no events" $ withHarness $ \environment -> do
        fed <- run environment (FeedCommand "test" "draft me") >>= interactionOf
        choice <- answer environment fed "raw.materialize-work"
        discovery <- answer environment choice "nature.discover"
        let cursorBefore = envelopeDatasetCursor discovery

        restarted <- run environment NextCommand >>= interactionOf
        restarted @?= discovery

        alternate <- answer environment restarted "nature.answer.unknown"
        case envelopeOpportunity alternate of
          NatureDiscoveryOpportunity _ state -> discoveryAlternateProbe state @?= True
          other -> assertFailure ("expected alternate Nature probe, got " <> show other)

        previous <- navigate environment alternate True
        previous @?= restarted
        forward <- navigate environment previous False
        forward @?= alternate

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        loadedCursor loaded @?= cursorBefore
        stateEventCount (loadedState loaded) @?= 1
        stateBricks (loadedState loaded) @?= Map.empty
    , testCase "factory Nature tree reaches every leaf without ambiguity" $ do
        direct [True] @?= ScheduledCommitment
        direct [False, True, False] @?= AtomicTask
        direct [False, True, True, True] @?= Project
        direct [False, True, True, False] @?= FiniteChecklist
        direct [False, False, True, True] @?= Collection
        direct [False, False, True, False] @?= LivingChecklist
        direct [False, False, False, True] @?= RecurringObligation
        direct [False, False, False, False, True] @?= Habit
        direct [False, False, False, False, False] @?= Repeatable
    , testCase "exact duplicate rejection is revision-scoped and prevents immediate repeat" $ withHarness $ \environment -> do
        _ <- run environment (FeedCommand "test" "milk")
        second <- run environment (FeedCommand "test" "  MILK  ") >>= interactionOf
        case envelopeOpportunity second of
          RawDuplicateOpportunity{} -> pure ()
          other -> assertFailure ("expected exact normalized duplicate review, got " <> show other)
        afterNo <- answer environment second "raw.duplicate.reject"
        assertBool "the same negative evidence is respected" (not (isDuplicate (envelopeOpportunity afterNo)))
        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        length (stateRejectedRawDuplicates (loadedState loaded)) @?= 1
        Map.size (stateRaws (loadedState loaded)) @?= 2
    , testCase "grocery Raw receipts become one owner-scoped ListEntry with additive quantity" $ withHarness $ \environment -> do
        groceryRaw <- run environment (FeedCommand "test" "buy groceries") >>= interactionOf
        nature <- answer environment groceryRaw "raw.materialize-work"
        templates <- answer environment nature "nature.choose.living_checklist"
        title <- answer environment templates "template.none"
        preview <- submit environment title "work.title.submit" "Buy groceries"
        created <- answer environment preview "work.create"
        ownerId <- case envelopeOpportunity created of
          WorkCreatedResultOpportunity _ identity -> pure identity
          other -> assertFailure ("expected grocery Work result, got " <> show other)

        firstMilk <- run environment (FeedCommand "test" "milk") >>= interactionOf
        destination <- answer environment firstMilk "raw.choose-destination"
        firstPreview <- answer environment destination (destinationAction destination ownerId)
        case envelopeOpportunity firstPreview of
          ListEntryPreviewOpportunity{} -> pure ()
          other -> assertFailure ("expected ListEntry preview, got " <> show other)
        firstResult <- answer environment firstPreview "list-entry.create"
        assertOpportunity "first ListEntry result" isListEntryResult firstResult

        secondMilk <- run environment (FeedCommand "test" "milk") >>= interactionOf
        assertBool "a materialized list receipt is not offered as a generic Raw duplicate" (not (isDuplicate (envelopeOpportunity secondMilk)))
        secondDestination <- answer environment secondMilk "raw.choose-destination"
        reuse <- answer environment secondDestination (destinationAction secondDestination ownerId)
        case envelopeOpportunity reuse of
          ListEntryReuseOpportunity{} -> pure ()
          other -> assertFailure ("expected owner-scoped reuse, got " <> show other)
        secondResult <- answer environment reuse "list-entry.add-quantity"
        assertOpportunity "quantity result" isListEntryResult secondResult

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        Map.size (stateRaws (loadedState loaded)) @?= 3
        Map.size (stateListEntries (loadedState loaded)) @?= 1
        fmap listEntryQuantity (Map.elems (stateListEntries (loadedState loaded))) @?= [Quantity 2 0 "item"]
    , testCase "second root Work enters sibling-only binary insertion before atomic creation" $ withHarness $ \environment -> do
        first <- createAtomicWork environment "write documentation"
        firstBrick <- case envelopeOpportunity first of
          WorkCreatedResultOpportunity _ identity -> pure identity
          other -> assertFailure ("expected first Work result, got " <> show other)

        raw <- run environment (FeedCommand "test" "fix the release") >>= interactionOf
        nature <- answer environment raw "raw.materialize-work"
        templates <- answer environment nature "nature.choose.atomic_task"
        title <- answer environment templates "template.none"
        comparison <- submit environment title "work.title.submit" "Fix the release"
        case envelopeOpportunity comparison of
          ImportanceInsertionOpportunity draft 0 1 [] comparator -> do
            workDraftParent draft @?= Nothing
            comparator @?= firstBrick
          other -> assertFailure ("expected binary insertion, got " <> show other)

        preview <- answer environment comparison "importance.more"
        case envelopeOpportunity preview of
          WorkPreviewOpportunity draft -> do
            workDraftSiblingPosition draft @?= 0
            workDraftImportanceConfidence draft @?= HumanComparison
          other -> assertFailure ("expected ordered preview, got " <> show other)
        _ <- answer environment preview "work.create"

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        let ordered = Map.elems (stateBricks (loadedState loaded))
            byPosition = Map.fromList [(brickSiblingPosition brick, brickTitle brick) | brick <- ordered]
        Map.lookup 0 byPosition @?= Just "Fix the release"
        Map.lookup 1 byPosition @?= Just "Write documentation"
        length (stateImportanceEdges (loadedState loaded)) @?= 1
    , testCase "two comparison skips produce visible provisional placement without false equality" $ withHarness $ \environment -> do
        _ <- createAtomicWork environment "alpha"
        _ <- createAtomicWorkBelow environment "bravo"
        raw <- run environment (FeedCommand "test" "charlie") >>= interactionOf
        nature <- answer environment raw "raw.materialize-work"
        templates <- answer environment nature "nature.choose.atomic_task"
        title <- answer environment templates "template.none"
        firstComparison <- submit environment title "work.title.submit" "Charlie"
        secondComparison <- answer environment firstComparison "importance.skip"
        case envelopeOpportunity secondComparison of
          ImportanceInsertionOpportunity _ _ _ skipped _ -> length skipped @?= 1
          other -> assertFailure ("expected nearby comparison, got " <> show other)
        preview <- answer environment secondComparison "importance.skip"
        case envelopeOpportunity preview of
          WorkPreviewOpportunity draft -> do
            workDraftImportanceConfidence draft @?= Provisional "nearby importance comparisons skipped"
            workDraftComparisons draft @?= []
          other -> assertFailure ("expected provisional preview, got " <> show other)
    , testCase "explicit project destination carries one parent through preview and sibling scope" $ withHarness $ \environment -> do
        source <- run environment (FeedCommand "test" "release the website") >>= interactionOf
        nature <- answer environment source "raw.materialize-work"
        templates <- answer environment nature "nature.choose.project"
        title <- answer environment templates "template.none"
        projectPreview <- submit environment title "work.title.submit" "Release the website"
        projectResult <- answer environment projectPreview "work.create"
        projectId <- case envelopeOpportunity projectResult of
          WorkCreatedResultOpportunity _ identity -> pure identity
          other -> assertFailure ("expected project result, got " <> show other)

        childRaw <- run environment (FeedCommand "test" "write launch copy") >>= interactionOf
        destinations <- answer environment childRaw "raw.choose-destination"
        childPlacement <- answer environment destinations (destinationAction destinations projectId)
        case envelopeOpportunity childPlacement of
          RawUnderBrickOpportunity _ identity -> identity @?= projectId
          other -> assertFailure ("expected child-or-attachment question, got " <> show other)
        childNature <- answer environment childPlacement "raw.child-work"
        case envelopeOpportunity childNature of
          NatureChoiceOpportunity context -> workContextParent context @?= Just projectId
          other -> assertFailure ("expected contextual Nature choice, got " <> show other)
        childTemplates <- answer environment childNature "nature.choose.atomic_task"
        childTitle <- answer environment childTemplates "template.none"
        childPreview <- submit environment childTitle "work.title.submit" "Write launch copy"
        case envelopeOpportunity childPreview of
          WorkPreviewOpportunity draft -> do
            workDraftParent draft @?= Just projectId
            workDraftSiblingPosition draft @?= 0
          other -> assertFailure ("expected child preview, got " <> show other)
        _ <- answer environment childPreview "work.create"

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        let children = [brick | brick <- Map.elems (stateBricks (loadedState loaded)), brickParent brick == Just projectId]
        fmap brickTitle children @?= ["Write launch copy"]
    , testCase "ordinary Brick destination distinguishes child Work from attached Raw" $ withHarness $ \environment -> do
        targetResult <- createAtomicWork environment "implement rock splitter"
        targetId <- case envelopeOpportunity targetResult of
          WorkCreatedResultOpportunity _ identity -> pure identity
          other -> assertFailure ("expected target Work result, got " <> show other)

        source <- run environment (FeedCommand "test" "API error notes") >>= interactionOf
        destinations <- answer environment source "raw.choose-destination"
        underBrick <- answer environment destinations (destinationAction destinations targetId)
        case envelopeOpportunity underBrick of
          RawUnderBrickOpportunity _ identity -> identity @?= targetId
          other -> assertFailure ("expected child-or-attachment question, got " <> show other)

        roles <- answer environment underBrick "raw.attach"
        case envelopeOpportunity roles of
          RawAttachmentOpportunity _ identity -> identity @?= targetId
          other -> assertFailure ("expected typed attachment role choice, got " <> show other)

        linked <- answer environment roles "raw.attach.description"
        case envelopeOpportunity linked of
          RawAttachmentResultOpportunity _ identity DescriptionRole -> identity @?= targetId
          other -> assertFailure ("expected attachment result, got " <> show other)

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        assertBool "the description link was created" (DescriptionRole `elem` fmap rawLinkRole (Map.elems (stateRawLinks (loadedState loaded))))
        assertBool "the Raw received an attachment disposition" (RawAttachedTo targetId DescriptionRole `elem` Map.elems (stateRawDispositions (loadedState loaded)))
    , testCase "RawShelf builder and existing destination preserve ordered Raw membership" $ withHarness $ \environment -> do
        first <- run environment (FeedCommand "test" "https://example.com/article-one") >>= interactionOf
        destinations <- answer environment first "raw.choose-destination"
        group <- answer environment destinations "raw.create-group"
        name <- answer environment group "raw-group.shelf"
        case envelopeOpportunity name of
          RawShelfNameOpportunity{} -> pure ()
          other -> assertFailure ("expected RawShelf name editor, got " <> show other)
        preview <- submit environment name "raw-shelf.name.submit" "Technical articles"
        created <- answer environment preview "raw-shelf.create"
        shelfId <- case envelopeOpportunity created of
          RawShelfResultOpportunity _ identity -> pure identity
          other -> assertFailure ("expected RawShelf result, got " <> show other)

        second <- run environment (FeedCommand "test" "https://example.com/article-two") >>= interactionOf
        secondDestinations <- answer environment second "raw.choose-destination"
        membership <- answer environment secondDestinations (shelfDestinationAction secondDestinations shelfId)
        case envelopeOpportunity membership of
          RawShelfMembershipPreviewOpportunity _ identity -> identity @?= shelfId
          other -> assertFailure ("expected RawShelf membership preview, got " <> show other)
        _ <- answer environment membership "raw-shelf.add"

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        shelf <- maybe (assertFailure "RawShelf disappeared after replay") pure (Map.lookup shelfId (stateRawShelves (loadedState loaded)))
        rawShelfName shelf @?= "Technical articles"
        length (rawShelfMembers shelf) @?= 2
        length [disposition | disposition@RawPlacedOnShelf{} <- Map.elems (stateRawDispositions (loadedState loaded))] @?= 2
    , testCase "Feed preserves current focus and shows one transient receipt fact" $ withHarness $ \environment -> do
        created <- createAtomicWork environment "review the release"
        proposal <- answer environment created "next"
        _ <- answer environment proposal "focus.accept"
        fed <- run environment (FeedCommand "test" "remember the API note") >>= interactionOf
        case envelopeOpportunity fed of
          CurrentFocusOpportunity{} -> pure ()
          other -> assertFailure ("Feed displaced current focus with " <> show other)
        assertBool "one transient Feed fact is visible" (any (Text.isPrefixOf "Fed: +") (contentBody (envelopeContent fed)))
        restarted <- run environment NextCommand >>= interactionOf
        restarted @?= fed
        completed <- answer environment restarted "focus.done"
        assertBool "the transient fact does not survive the next semantic screen" (not (any (Text.isPrefixOf "Fed: +") (contentBody (envelopeContent completed))))
    , testCase "existing Work suspicion can reuse one Brick without allocating another slot" $ withHarness $ \environment -> do
        first <- createAtomicWork environment "fix a bug on website"
        existingId <- case envelopeOpportunity first of
          WorkCreatedResultOpportunity _ identity -> pure identity
          other -> assertFailure ("expected first Work result, got " <> show other)

        source <- run environment (FeedCommand "test" "repair the website defect") >>= interactionOf
        nature <- answer environment source "raw.materialize-work"
        templates <- answer environment nature "nature.choose.atomic_task"
        title <- answer environment templates "template.none"
        suspicion <- submit environment title "work.title.submit" "Fix a bug on website"
        case envelopeOpportunity suspicion of
          ExistingWorkSuspicionOpportunity _ identity -> identity @?= existingId
          other -> assertFailure ("expected existing Work suspicion, got " <> show other)
        reused <- answer environment suspicion "work-reuse.use"
        case envelopeOpportunity reused of
          ExistingWorkReuseResultOpportunity _ identity -> identity @?= existingId
          other -> assertFailure ("expected existing Work reuse result, got " <> show other)

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        Map.size (stateBricks (loadedState loaded)) @?= 1
        length [disposition | disposition@(RawMaterializedAsWork identity) <- Map.elems (stateRawDispositions (loadedState loaded)), identity == existingId] @?= 2
    , testCase "stale guided response returns the current envelope and records nothing" $ withHarness $ \environment -> do
        old <- run environment (FeedCommand "test" "old material") >>= interactionOf
        current <- run environment (FeedCommand "test" "new material") >>= interactionOf
        staleResult <- run environment (RespondCommand (response old "raw.materialize-work"))
        stale <- interactionOf staleResult
        stale @?= current
        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        stateEventCount (loadedState loaded) @?= 2
        stateBricks (loadedState loaded) @?= Map.empty
    , testCase "dry-run final Work acceptance changes neither JSONL nor pending draft" $ withHarness $ \environment -> do
        raw <- run environment (FeedCommand "test" "dry run me") >>= interactionOf
        nature <- answer environment raw "raw.materialize-work"
        templates <- answer environment nature "nature.choose.atomic_task"
        title <- answer environment templates "template.none"
        preview <- submit environment title "work.title.submit" "Dry run me"

        simulated <- assertRight =<< runAppCommand environment True (const (pure ())) (RespondCommand (response preview "work.create"))
        case simulated of
          RespondResult{resultInteraction, resultDryRun = True} -> assertOpportunity "simulated creation result" isCreated resultInteraction
          other -> assertFailure ("expected dry-run RespondResult, got " <> show other)

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        stateEventCount (loadedState loaded) @?= 1
        stateBricks (loadedState loaded) @?= Map.empty
        restored <- run environment NextCommand >>= interactionOf
        restored @?= preview
    ]

createAtomicWork :: AppEnv -> Text -> IO InteractionEnvelope
createAtomicWork environment material = do
  raw <- run environment (FeedCommand "test" material) >>= interactionOf
  nature <- answer environment raw "raw.materialize-work"
  templates <- answer environment nature "nature.choose.atomic_task"
  title <- answer environment templates "template.none"
  preview <- submit environment title "work.title.submit" (titleCase material)
  answer environment preview "work.create"

createAtomicWorkBelow :: AppEnv -> Text -> IO InteractionEnvelope
createAtomicWorkBelow environment material = do
  raw <- run environment (FeedCommand "test" material) >>= interactionOf
  nature <- answer environment raw "raw.materialize-work"
  templates <- answer environment nature "nature.choose.atomic_task"
  title <- answer environment templates "template.none"
  comparison <- submit environment title "work.title.submit" (titleCase material)
  preview <- answer environment comparison "importance.less"
  answer environment preview "work.create"

titleCase :: Text -> Text
titleCase value = case Text.uncons value of
  Nothing -> value
  Just (character, rest)
    | isAsciiLower character -> Text.cons (toEnum (fromEnum character - 32)) rest
    | otherwise -> value

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s02" $ \root -> do
  counter <- newIORef (1000 :: Int)
  let allocate = atomicModifyIORef' counter $ \seed -> (seed + 1, fixtureUuid seed)
      environment =
        AppEnv
          (StoreConfig root 2000000 20000)
          (Actor "human" "test")
          (pure fixedTime)
          (pure (utcToZonedTime utc fixedTime))
          allocate
          emptyExportPort
  action environment

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command = assertRight =<< runAppCommand environment False (const (pure ())) command

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  FeedResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no guided interaction: " <> show other)

answer :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answer environment envelope action =
  run environment (RespondCommand (response envelope action)) >>= interactionOf

submit :: AppEnv -> InteractionEnvelope -> Text -> Text -> IO InteractionEnvelope
submit environment envelope action value =
  run environment (SubmitInteractionTextCommand (response envelope action) value) >>= interactionOf

navigate :: AppEnv -> InteractionEnvelope -> Bool -> IO InteractionEnvelope
navigate environment envelope backward =
  run environment (if backward then NavigateBackCommand request else NavigateForwardCommand request) >>= interactionOf
 where
  request = response envelope (if backward then "navigation.back" else "navigation.forward")

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

direct :: [Bool] -> BrickNature
direct = go (NatureDiscovery FixedTimeQuestion False [])
 where
  go _ [] = error "incomplete direct Nature path"
  go discovery (answerValue : rest) = case natureBranch discovery answerValue of
    Left (nature, _) -> if null rest then nature else error "Nature path continued after a leaf"
    Right question -> go (NatureDiscovery question False (discoveryHistory discovery <> [discoveryQuestion discovery])) rest

isRawTriage, isNatureChoice, isTemplateChoice, isCreated, isFocusProposal, isCurrentFocus, isCompleted :: Opportunity -> Bool
isRawTriage RawTriageOpportunity{} = True
isRawTriage _ = False
isNatureChoice NatureChoiceOpportunity{} = True
isNatureChoice _ = False
isTemplateChoice TemplateChoiceOpportunity{} = True
isTemplateChoice _ = False
isCreated WorkCreatedResultOpportunity{} = True
isCreated _ = False
isFocusProposal FocusProposalOpportunity{} = True
isFocusProposal _ = False
isCurrentFocus CurrentFocusOpportunity{} = True
isCurrentFocus _ = False
isCompleted CompletionResultOpportunity{} = True
isCompleted _ = False

isDuplicate :: Opportunity -> Bool
isDuplicate RawDuplicateOpportunity{} = True
isDuplicate _ = False

destinationAction :: InteractionEnvelope -> UUIDv7 -> Text
destinationAction envelope ownerId =
  case [actionId action | action <- envelopeActions envelope, actionId action == "raw.destination.brick." <> renderUUIDv7 ownerId] of
    [identifier] -> identifier
    _ -> error ("destination action not found: " <> show (envelopeActions envelope))

shelfDestinationAction :: InteractionEnvelope -> UUIDv7 -> Text
shelfDestinationAction envelope shelfId =
  case [actionId action | action <- envelopeActions envelope, actionId action == "raw.destination.shelf." <> renderUUIDv7 shelfId] of
    [identifier] -> identifier
    _ -> error ("RawShelf destination action not found: " <> show (envelopeActions envelope))

isListEntryResult :: Opportunity -> Bool
isListEntryResult ListEntryResultOpportunity{} = True
isListEntryResult _ = False

assertOpportunity :: String -> (Opportunity -> Bool) -> InteractionEnvelope -> Assertion
assertOpportunity label predicate envelope =
  assertBool (label <> ": " <> show (envelopeOpportunity envelope)) (predicate (envelopeOpportunity envelope))

fixtureUuid :: Int -> UUIDv7
fixtureUuid seed =
  either (error . show) id $
    uuidV7FromEntropy
      (0x0198f8a34c21 + fromIntegral seed)
      (ByteString.replicate 10 (fromIntegral (seed `mod` 251 + 1)))

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

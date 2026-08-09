module Main (main) where

import Data.ByteString qualified as ByteString
import Data.IORef
import Data.List (find, sortOn)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.ForecastWorld
import LittleAnt.Id
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Result
import LittleAnt.Store
import System.IO.Temp
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S06 decomposition"
      [ testCase "atomic break previews and atomically reclassifies the same parent" atomicBreak
      , testCase "compatible parent accepts one additional part without reclassification" additiveBreak
      , testCase "served big recovery records typed evidence with the structure" servedBreak
      , testCase "living checklist run requires a mutation and leaves its owner active" livingChecklistRun
      , testCase "finite checklist closure releases review without auto-completing its owner" finiteChecklistRun
      ]

atomicBreak :: Assertion
atomicBreak = withHarness $ \environment -> do
  seedParent environment AtomicTask
  choose <- run environment (BreakCommand "#parent") >>= interactionOf
  envelopeOpportunity choose @?= WorkBreakNatureOpportunity parentId Nothing Nothing
  draft0 <- answer environment choose "work.break.nature.project"
  draft1 <- submit environment draft0 "Inspect the route"
  draft2 <- submit environment draft1 "Carry the first load"
  preview <- submit environment draft2 ""
  case envelopeOpportunity preview of
    WorkBreakPreviewOpportunity identity Nothing Nothing (Just Project) titles -> do
      identity @?= parentId
      titles @?= ["Inspect the route", "Carry the first load"]
    other -> assertFailure ("expected break preview, got " <> show other)
  receipt <- answer environment preview "work.break.accept"
  case envelopeOpportunity receipt of
    WorkBreakResultOpportunity identity children -> do
      identity @?= parentId
      length children @?= 2
    other -> assertFailure ("expected break result, got " <> show other)
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
      parent = stateBricks state Map.! parentId
      children = sortOn brickSiblingPosition [brick | brick <- Map.elems (stateBricks state), brickParent brick == Just parentId]
  brickHandle parent @?= Handle "parent"
  brickNature parent @?= Project
  fmap brickNature children @?= [AtomicTask, AtomicTask]
  fmap brickSiblingPosition children @?= [0, 1]
  length (stateLazyReviews state) @?= 2
  Map.size (stateRaws state) @?= 1
  case find ((== parentId) . ticketIdentity) (buildForecastWorld state fixedTime) of
    Nothing -> assertFailure "parent forecast ticket missing"
    Just ticket -> assertBool "decomposed parent is still directly focusable" (all ((/= FiniteWorkOpportunity) . selectableKind) (ticketOpportunities ticket))

additiveBreak :: Assertion
additiveBreak = withHarness $ \environment -> do
  seedParent environment Project
  draft0 <- run environment (BreakCommand "#parent") >>= interactionOf
  envelopeOpportunity draft0 @?= WorkBreakDraftOpportunity parentId Nothing Nothing Nothing []
  draft1 <- submit environment draft0 "One useful part"
  preview <- submit environment draft1 ""
  _ <- answer environment preview "work.break.accept"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  brickNature (stateBricks (loadedState loaded) Map.! parentId) @?= Project
  length [() | brick <- Map.elems (stateBricks (loadedState loaded)), brickParent brick == Just parentId] @?= 1

servedBreak :: Assertion
servedBreak = withHarness $ \environment -> do
  seedParent environment AtomicTask
  proposal <- run environment NextCommand >>= interactionOf
  symptom <- answer environment proposal "focus.skip"
  big <- answer environment symptom "work.symptom.big"
  choose <- answer environment big "work.reaction.break"
  draft0 <- answer environment choose "work.break.nature.project"
  draft1 <- submit environment draft0 "Prepare"
  draft2 <- submit environment draft1 "Execute"
  preview <- submit environment draft2 ""
  _ <- answer environment preview "work.break.accept"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  case Map.elems (stateWorkDeferrals (loadedState loaded)) of
    [evidence] -> do
      workDeferralSymptom evidence @?= BigSymptom
      workDeferralReaction evidence @?= BreakIntoPartsReaction
      workDeferralCooldownUntil evidence @?= Nothing
    other -> assertFailure ("expected one typed break reaction, got " <> show other)

livingChecklistRun :: Assertion
livingChecklistRun = withHarness $ \environment -> do
  seedChecklist environment LivingChecklist
  proposal <- run environment NextCommand >>= interactionOf
  run0 <- answer environment proposal "focus.accept"
  envelopeOpportunity run0 @?= ChecklistRunOpportunity parentId Nothing
  rejected <- runAppCommand environment False (const (pure ())) (RespondCommand (response run0 "checklist.finish"))
  case rejected of
    Left problem -> appErrorCode problem @?= PreconditionFailed
    Right result -> assertFailure ("zero-mutation finish unexpectedly succeeded: " <> show result)
  selected <- answer environment run0 ("checklist.select." <> renderUUIDv7 entryOneId)
  run1 <- answer environment selected "checklist.entry.done"
  finished <- answer environment run1 "checklist.finish"
  envelopeOpportunity finished @?= ChecklistRunResultOpportunity parentId
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  brickStatus (stateBricks state Map.! parentId) @?= BrickActive
  listEntryState (stateListEntries state Map.! entryOneId) @?= EntryResolved
  stateCurrentFocus state @?= Nothing
  Map.size (stateChecklistRuns state) @?= 0
  Map.size (stateLazyReviews state) @?= 0

finiteChecklistRun :: Assertion
finiteChecklistRun = withHarness $ \environment -> do
  seedChecklist environment FiniteChecklist
  proposal <- run environment NextCommand >>= interactionOf
  run0 <- answer environment proposal "focus.accept"
  selectedOne <- answer environment run0 ("checklist.select." <> renderUUIDv7 entryOneId)
  run1 <- answer environment selectedOne "checklist.entry.done"
  selectedTwo <- answer environment run1 ("checklist.select." <> renderUUIDv7 entryTwoId)
  run2 <- answer environment selectedTwo "checklist.entry.cancel"
  _ <- answer environment run2 "checklist.finish"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let state = loadedState loaded
  brickStatus (stateBricks state Map.! parentId) @?= BrickActive
  fmap listEntryState (sortOn listEntryInsertionOrdinal (Map.elems (stateListEntries state))) @?= [EntryResolved, EntryCancelled]
  fmap lazyReviewKind (Map.elems (stateLazyReviews state)) @?= ["scope_closure_review"]

seedChecklist :: AppEnv -> BrickNature -> IO ()
seedChecklist environment nature = do
  let actor = Actor "human" "test"
      command = fixtureUuid 200
      eventIds = fmap fixtureUuid [201 .. 212]
      ownerRaw = fixtureUuid 190
      firstRaw = fixtureUuid 191
      secondRaw = fixtureUuid 192
      replay = [command, ownerRaw, firstRaw, secondRaw, parentId, entryOneId, entryTwoId] <> eventIds
      draft eventId payload = EventDraft eventId command actor fixedTime (statePreconditionHash emptyState) replay payload
      one = Quantity 1 0 ""
      events =
        [ draft (eventIds !! 0) (RawFedV1 (RawFed ownerRaw (Handle "groceries") "Buy groceries" "test" Nothing))
        , draft (eventIds !! 1) (BrickCreatedV1 (BrickCreated parentId (Handle "groceries") "Buy groceries" nature "factory@1" "human" Nothing Nothing Set.empty 0 (DeterministicPosition "singleton") ownerRaw))
        , draft (eventIds !! 2) (RawLinkAddedV1 (RawLinkAdded (fixtureUuid 220) ownerRaw (RawLinkBrick parentId) MaterializationSourceRole))
        , draft (eventIds !! 3) (RawDispositionAcceptedV1 (RawDispositionAccepted ownerRaw (RawMaterializedAsWork parentId)))
        , draft (eventIds !! 4) (RawFedV1 (RawFed firstRaw (Handle "milk") "milk" "test" Nothing))
        , draft (eventIds !! 5) (ListEntryCreatedV1 (ListEntryCreated entryOneId parentId "Milk" one 0 firstRaw))
        , draft (eventIds !! 6) (RawLinkAddedV1 (RawLinkAdded (fixtureUuid 221) firstRaw (RawLinkListEntry entryOneId) MaterializationSourceRole))
        , draft (eventIds !! 7) (RawDispositionAcceptedV1 (RawDispositionAccepted firstRaw (RawMaterializedAsListEntry parentId entryOneId)))
        , draft (eventIds !! 8) (RawFedV1 (RawFed secondRaw (Handle "bread") "bread" "test" Nothing))
        , draft (eventIds !! 9) (ListEntryCreatedV1 (ListEntryCreated entryTwoId parentId "Bread" one 1 secondRaw))
        , draft (eventIds !! 10) (RawLinkAddedV1 (RawLinkAdded (fixtureUuid 222) secondRaw (RawLinkListEntry entryTwoId) MaterializationSourceRole))
        , draft (eventIds !! 11) (RawDispositionAcceptedV1 (RawDispositionAccepted secondRaw (RawMaterializedAsListEntry parentId entryTwoId)))
        ]
  accepted <- appendCommand (appStore environment) Genesis events
  either (assertFailure . show) (const (pure ())) accepted

seedParent :: AppEnv -> BrickNature -> IO ()
seedParent environment nature = do
  let actor = Actor "human" "test"
      command = fixtureUuid 10
      eventIds = fmap fixtureUuid [11 .. 14]
      replay = rawIdValue : parentId : command : eventIds
      draft eventId payload = EventDraft eventId command actor fixedTime (statePreconditionHash emptyState) replay payload
      events =
        [ draft (eventIds !! 0) (RawFedV1 (RawFed rawIdValue (Handle "parent") "Carry this enormous stone" "test" Nothing))
        , draft
            (eventIds !! 1)
            (BrickCreatedV1 (BrickCreated parentId (Handle "parent") "Carry this enormous stone" nature "factory@1" "human" Nothing Nothing Set.empty 0 (DeterministicPosition "singleton") rawIdValue))
        , draft (eventIds !! 2) (RawLinkAddedV1 (RawLinkAdded (fixtureUuid 20) rawIdValue (RawLinkBrick parentId) MaterializationSourceRole))
        , draft (eventIds !! 3) (RawDispositionAcceptedV1 (RawDispositionAccepted rawIdValue (RawMaterializedAsWork parentId)))
        ]
  accepted <- appendCommand (appStore environment) Genesis events
  either (assertFailure . show) (const (pure ())) accepted

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s06" $ \root -> do
  counter <- newIORef (6000 :: Int)
  let allocate = atomicModifyIORef' counter $ \number -> (number + 1, fixtureUuid number)
      environment =
        AppEnv
          (StoreConfig root 2_000_000 20_000)
          (Actor "human" "test")
          (pure fixedTime)
          (pure (utcToZonedTime utc fixedTime))
          allocate
          emptyExportPort
          emptyImportPort
          Nothing
  action environment

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command = assertRight =<< runAppCommand environment False (const (pure ())) command

answer :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answer environment envelope action =
  run environment (RespondCommand (response envelope action)) >>= interactionOf

submit :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
submit environment envelope text =
  run environment (SubmitInteractionTextCommand (response envelope "work.break.submit") text) >>= interactionOf

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other)

rawIdValue :: UUIDv7
rawIdValue = fixtureUuid 1

parentId :: UUIDv7
parentId = fixtureUuid 2

entryOneId :: UUIDv7
entryOneId = fixtureUuid 193

entryTwoId :: UUIDv7
entryTwoId = fixtureUuid 194

fixtureUuid :: Int -> UUIDv7
fixtureUuid number =
  either (error . show) id $
    uuidV7FromEntropy
      (0x0198f8a34c21 + fromIntegral number)
      (ByteString.replicate 10 (fromIntegral (rem number 251 + 1)))

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

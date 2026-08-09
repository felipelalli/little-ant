module Main (main) where

import Control.Monad (foldM)
import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision (completionUUIDCount, decideAddDependency, decideCompleteBrick, mutationDecisionEvents, statePreconditionHash)
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.Foundation
import LittleAnt.Id
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
      "S04 vertical forecast"
      [ testCase "next records one immutable draw and restart restores it" recordedNext
      , testCase "completion releases every Dependency for which the Brick is the blocker" dependencyRelease
      ]

recordedNext :: Assertion
recordedNext =
  withHarness $ \environment -> do
    seedOneBrick environment
    first <- run environment NextCommand
    firstEnvelope <- interactionOf first
    selectionId <- case envelopeOpportunity firstEnvelope of
      FocusProposalOpportunity identity (Just selected) -> do
        identity @?= brickIdValue
        pure selected
      other -> assertFailure ("expected recorded Focus proposal, got " <> show other)
    afterFirst <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
    Map.size (stateForecastSelections (loadedState afterFirst)) @?= 1
    assertBool "selection evidence is missing" (Map.member selectionId (stateForecastSelections (loadedState afterFirst)))
    stateEventCount (loadedState afterFirst) @?= 5
    second <- run environment NextCommand
    secondEnvelope <- interactionOf second
    secondEnvelope @?= firstEnvelope
    resultCursor second @?= resultCursor first
    afterSecond <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
    stateEventCount (loadedState afterSecond) @?= 5

dependencyRelease :: Assertion
dependencyRelease = do
  let blocked = brickIdValue
      blocker = fixtureUuid 3
      state0 =
        emptyState
          { stateBricks = Map.fromList [(blocked, fixtureBrick blocked "blocked"), (blocker, fixtureBrick blocker "blocker")]
          , stateBrickHandles = Map.fromList [(Handle "blocked", blocked), (Handle "blocker", blocker)]
          , stateRetiredBrickHandles = Set.fromList [Handle "blocked", Handle "blocker"]
          }
  added <- assertRight (decideAddDependency state0 actor blocked blocker "human" (facts [100 .. 102]))
  state1 <- assertRight (foldDrafts state0 (mutationDecisionEvents added))
  completionUUIDCount state1 blocker @?= 3
  completed <- assertRight (decideCompleteBrick state1 actor blocker (facts [110 .. 112]))
  state2 <- assertRight (foldDrafts state1 (mutationDecisionEvents completed))
  brickStatus (stateBricks state2 Map.! blocker) @?= BrickDone
  fmap dependencyStatus (Map.elems (stateDependencies state2)) @?= [DependencyResolved]
 where
  actor = Actor "human" "test"
  facts numbers =
    RuntimeFacts
      fixedTime
      (fmap (UUIDAllocation . renderUUIDv7 . fixtureUuid) numbers)
      Map.empty
      (FilesystemFacts True True Nothing)
      (TerminalCapabilities False False False 80 24 False)
      []

  fixtureBrick identity handle =
    Brick identity (Handle handle) handle AtomicTask "factory@1" "test" Nothing Nothing Set.empty 0 (DeterministicPosition "fixture") BrickActive Idle fixedTime actor (fixtureUuid 99)

  foldDrafts state drafts =
    foldM apply state (zip [1 ..] drafts)

  apply state (sequenceNumber, draft) =
    applyEvent
      state
      PersistedEvent
        { persistedEventId = draftEventId draft
        , persistedCommandId = draftCommandId draft
        , persistedSegmentSequence = 1
        , persistedEventSequence = sequenceNumber
        , persistedActor = draftActor draft
        , persistedRecordedAt = draftRecordedAt draft
        , persistedPreviousSegmentHash = "genesis"
        , persistedPreconditionHash = draftPreconditionHash draft
        , persistedReplayUUIDs = draftReplayUUIDs draft
        , persistedPayload = draftPayload draft
        }

seedOneBrick :: AppEnv -> IO ()
seedOneBrick environment = do
  let actor = Actor "human" "test"
      command = fixtureUuid 10
      eventIds = fmap fixtureUuid [11 .. 14]
      precondition = statePreconditionHash emptyState
      replay = rawIdValue : brickIdValue : command : eventIds
      draft eventId payload =
        EventDraft eventId command actor fixedTime precondition replay payload
      events =
        [ draft (eventIds !! 0) (RawFedV1 (RawFed rawIdValue (Handle "wtms") "Write the migration specification" "test" Nothing))
        , draft
            (eventIds !! 1)
            ( BrickCreatedV1
                ( BrickCreated
                    brickIdValue
                    (Handle "wtms")
                    "Write the migration specification"
                    AtomicTask
                    "nature-v1"
                    "human"
                    Nothing
                    Nothing
                    Set.empty
                    0
                    (DeterministicPosition "singleton")
                    rawIdValue
                )
            )
        , draft (eventIds !! 2) (RawLinkAddedV1 (RawLinkAdded (fixtureUuid 20) rawIdValue (RawLinkBrick brickIdValue) MaterializationSourceRole))
        , draft (eventIds !! 3) (RawDispositionAcceptedV1 (RawDispositionAccepted rawIdValue (RawMaterializedAsWork brickIdValue)))
        ]
  accepted <- appendCommand (appStore environment) Genesis events
  case accepted of
    Left problem -> assertFailure (show problem)
    Right _ -> pure ()

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s04" $ \root -> do
  counter <- newIORef (4000 :: Int)
  let allocate = atomicModifyIORef' counter $ \number -> (number + 1, fixtureUuid number)
      environment =
        AppEnv
          (StoreConfig root 2_000_000 20_000)
          (Actor "human" "test")
          (pure fixedTime)
          (pure (utcToZonedTime utc fixedTime))
          allocate
          emptyExportPort
  action environment

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command =
  assertRight =<< runAppCommand environment False (const (pure ())) command

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other)

rawIdValue :: UUIDv7
rawIdValue = fixtureUuid 1

brickIdValue :: UUIDv7
brickIdValue = fixtureUuid 2

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

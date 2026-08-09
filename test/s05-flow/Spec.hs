module Main (main) where

import Data.ByteString qualified as ByteString
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
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
      "S05 served-work recovery"
      [ testCase "symptom navigation records nothing until a final reaction" provisionalSymptom
      , testCase "skip records typed evidence and cooldown atomically" committedSkip
      , testCase "a Pomodoro records bored plus sprint and resumes focus" boundedSprint
      , testCase "other preserves exact event evidence rather than Raw" verbatimOther
      , testCase "mechanical discovery reaches an explicit confirmed leaf" mechanicalDiscovery
      , testCase "archive leaves Work inactive and releases one bounded relevance review" archiveReview
      , testCase "restore keeps identity and queues only local importance review" restoreWork
      ]

provisionalSymptom :: Assertion
provisionalSymptom = withFocusedProposal $ \environment proposal -> do
  symptom <- answer environment proposal "focus.skip"
  envelopeOpportunity symptom @?= WorkSkipSymptomOpportunity brickIdValue (selectionOf proposal)
  tired <- answer environment symptom "work.symptom.tired"
  envelopeOpportunity tired @?= WorkSkipReactionOpportunity brickIdValue (selectionOf proposal) TiredSymptom
  back <- navigate environment tired True
  envelopeOpportunity back @?= envelopeOpportunity symptom
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  Map.size (stateWorkDeferrals (loadedState loaded)) @?= 0

committedSkip :: Assertion
committedSkip = withFocusedProposal $ \environment proposal -> do
  symptom <- answer environment proposal "focus.skip"
  tired <- answer environment symptom "work.symptom.tired"
  receipt <- answer environment tired "work.reaction.skip"
  case envelopeOpportunity receipt of
    WorkSkipAcknowledgedOpportunity identity TiredSymptom SkipAnywayReaction -> identity @?= brickIdValue
    other -> assertFailure ("expected skip receipt, got " <> show other)
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  case Map.elems (stateWorkDeferrals (loadedState loaded)) of
    [deferral] -> do
      workDeferralSymptom deferral @?= TiredSymptom
      workDeferralReaction deferral @?= SkipAnywayReaction
      assertBool "ordinary cooldown missing" (workDeferralCooldownUntil deferral > Just fixedTime)
    other -> assertFailure ("expected one deferral, got " <> show other)

boundedSprint :: Assertion
boundedSprint = withFocusedProposal $ \environment proposal -> do
  symptom <- answer environment proposal "focus.skip"
  bored <- answer environment symptom "work.symptom.bored"
  interesting <- answer environment bored "work.reaction.interesting"
  duration <- answer environment interesting "work.interesting.sprint"
  focused <- answer environment duration "work.sprint.25"
  envelopeOpportunity focused @?= CurrentFocusOpportunity brickIdValue
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  stateCurrentFocus (loadedState loaded) @?= Just brickIdValue
  case stateActiveSprint (loadedState loaded) of
    Just sprint -> do
      activeSprintMinutes sprint @?= 25
      activeSprintEndsAt sprint @?= addUTCTime (25 * 60) fixedTime
    Nothing -> assertFailure "active sprint missing"
  case Map.elems (stateWorkDeferrals (loadedState loaded)) of
    [deferral] -> do
      workDeferralSymptom deferral @?= BoredSymptom
      workDeferralReaction deferral @?= StartSprintReaction 25
      workDeferralCooldownUntil deferral @?= Nothing
    other -> assertFailure ("expected one sprint reaction, got " <> show other)

verbatimOther :: Assertion
verbatimOther = withFocusedProposal $ \environment proposal -> do
  symptom <- answer environment proposal "focus.skip"
  editor <- answer environment symptom "work.symptom.other"
  preview <- submit environment editor "The office is too noisy"
  _ <- answer environment preview "work.other.accept"
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  case Map.elems (stateWorkDeferrals (loadedState loaded)) of
    [deferral] -> workDeferralSymptom deferral @?= OtherSymptom "The office is too noisy"
    other -> assertFailure ("expected one verbatim deferral, got " <> show other)
  Map.size (stateRaws (loadedState loaded)) @?= 1

mechanicalDiscovery :: Assertion
mechanicalDiscovery = withFocusedProposal $ \environment proposal -> do
  symptom <- answer environment proposal "focus.skip"
  q0 <- answer environment symptom "work.symptom.unknown"
  let descend envelope =
        case envelopeOpportunity envelope of
          WorkSkipDiscoveryOpportunity{} -> answer environment envelope "work.discovery.no" >>= descend
          _ -> pure envelope
  leaf <- descend q0
  case envelopeOpportunity leaf of
    WorkSkipConfirmationOpportunity identity selection (OtherSymptom "") -> do
      identity @?= brickIdValue
      selection @?= selectionOf proposal
    other -> assertFailure ("expected explicit other leaf, got " <> show other)

archiveReview :: Assertion
archiveReview = withHarness $ \environment -> do
  seedOneBrick environment
  preview <- run environment (ArchiveCommand "#rrsr") >>= interactionOf
  envelopeOpportunity preview @?= ArchivePreviewOpportunity brickIdValue Nothing Nothing
  receipt <- answer environment preview "archive.accept"
  envelopeOpportunity receipt @?= ArchiveResultOpportunity brickIdValue
  archived <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  brickStatus (stateBricks (loadedState archived) Map.! brickIdValue) @?= BrickArchived
  length (stateLazyReviews (loadedState archived)) @?= 1
  review <- answer environment receipt "next"
  case envelopeOpportunity review of
    ArchiveReviewOpportunity identity _ -> identity @?= brickIdValue
    other -> assertFailure ("expected archive relevance review, got " <> show other)
  _ <- answer environment review "archive-review.keep"
  settled <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  brickStatus (stateBricks (loadedState settled) Map.! brickIdValue) @?= BrickArchived
  Map.size (stateLazyReviews (loadedState settled)) @?= 0

restoreWork :: Assertion
restoreWork = withHarness $ \environment -> do
  seedOneBrick environment
  preview <- run environment (ArchiveCommand "#rrsr") >>= interactionOf
  _ <- answer environment preview "archive.accept"
  restore <- run environment (RestoreCommand "#rrsr") >>= interactionOf
  envelopeOpportunity restore @?= RestorePreviewOpportunity brickIdValue
  receipt <- answer environment restore "restore.accept"
  envelopeOpportunity receipt @?= RestoreResultOpportunity brickIdValue
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let brick = stateBricks (loadedState loaded) Map.! brickIdValue
  brickStatus brick @?= BrickActive
  brickHandle brick @?= Handle "rrsr"
  case brickImportanceConfidence brick of
    Provisional{} -> pure ()
    other -> assertFailure ("expected provisional restored placement, got " <> show other)
  fmap lazyReviewKind (Map.elems (stateLazyReviews (loadedState loaded))) @?= ["importance_run_review"]

withFocusedProposal :: (AppEnv -> InteractionEnvelope -> IO a) -> IO a
withFocusedProposal action =
  withHarness $ \environment -> do
    seedOneBrick environment
    proposal <- run environment NextCommand >>= interactionOf
    action environment proposal

selectionOf :: InteractionEnvelope -> Maybe UUIDv7
selectionOf envelope =
  case envelopeOpportunity envelope of
    FocusProposalOpportunity _ selection -> selection
    _ -> Nothing

seedOneBrick :: AppEnv -> IO ()
seedOneBrick environment = do
  let actor = Actor "human" "test"
      command = fixtureUuid 10
      eventIds = fmap fixtureUuid [11 .. 14]
      precondition = statePreconditionHash emptyState
      replay = rawIdValue : brickIdValue : command : eventIds
      draft eventId payload = EventDraft eventId command actor fixedTime precondition replay payload
      events =
        [ draft (eventIds !! 0) (RawFedV1 (RawFed rawIdValue (Handle "rrsr") "Review Rock Splitter rules" "test" Nothing))
        , draft
            (eventIds !! 1)
            ( BrickCreatedV1
                ( BrickCreated
                    brickIdValue
                    (Handle "rrsr")
                    "Review Rock Splitter rules"
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
  either (assertFailure . show) (const (pure ())) accepted

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s05" $ \root -> do
  counter <- newIORef (5000 :: Int)
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
          Nothing
          Nothing
          Nothing
  action environment

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command =
  assertRight =<< runAppCommand environment False (const (pure ())) command

answer :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answer environment envelope action =
  run environment (RespondCommand (response envelope action)) >>= interactionOf

submit :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
submit environment envelope text =
  run environment (SubmitInteractionTextCommand (response envelope "work.other.submit") text) >>= interactionOf

navigate :: AppEnv -> InteractionEnvelope -> Bool -> IO InteractionEnvelope
navigate environment envelope backward =
  run environment ((if backward then NavigateBackCommand else NavigateForwardCommand) (response envelope "navigate")) >>= interactionOf

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

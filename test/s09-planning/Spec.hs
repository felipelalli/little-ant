module Main (main) where

import Data.Aeson
import Data.Aeson.Types (parseEither)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Judgment
import LittleAnt.Model
import LittleAnt.Pack.Format (canonicalJsonBytes)
import LittleAnt.Planning
import LittleAnt.Store
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 core-owned planning cut"
      [ testCase "the cut is deterministic, non-overlapping, sparse, and reproducible" deterministicPlanningCut
      , testCase "an unavailable effort profile fails before serialization" staleEffortProfile
      , testCase "latest explicit remaining effort is projected without rewriting total effort" explicitRemainingEffort
      , testCase "a latest observation without remaining effort does not reuse stale evidence" missingLatestRemainingEffort
      ]

deterministicPlanningCut :: Assertion
deterministicPlanningCut = do
  first <- assertRight (buildTaskJugglerPayload fixtureExporter fixedTime fixtureCursor fixtureState (object ["kind" .= ("all" :: Text)]) fixtureBricks)
  second <- assertRight (buildTaskJugglerPayload fixtureExporter fixedTime fixtureCursor fixtureState (object ["kind" .= ("all" :: Text)]) fixtureBricks)
  first @?= second
  encoded <- assertRight (canonicalJsonBytes first)

  assertContains encoded (rendered "0198f000-0000-7000-8000-000000000001")
  assertBool "a child overlapped its effort-bearing parent in the cut" (not (rendered "0198f000-0000-7000-8000-000000000002" `ByteString.isInfixOf` encoded))
  assertContains encoded (rendered "0198f000-0000-7000-8000-000000000003")
  assertContains encoded "\"effort_macro\":\"EFFORT_4D\""
  assertContains encoded "\"missing-effort\""
  assertContains encoded "\"wip-total-effort\""
  assertContains encoded "\"dependencies\":[\"t_0198f000000070008000000000000001\"]"

  (manifest, digest) <- either (assertFailure . show) pure (parseEither payloadCustody first)
  manifestBytes <- assertRight (canonicalJsonBytes manifest)
  sha256Hex manifestBytes @?= digest
 where
  payloadCustody = withObject "planning payload" $ \payload -> (,) <$> payload .: "manifest" <*> payload .: "manifest_digest"

staleEffortProfile :: Assertion
staleEffortProfile = do
  let parent = parentBrick
      stale = (fixtureEffort parent HardEffort){effortClaimProfileHash = "little-ant/judgment-profile@0"}
      state = fixtureState{stateEffortClaims = Map.singleton (brickId parent) stale}
  case buildTaskJugglerPayload fixtureExporter fixedTime fixtureCursor state (object ["kind" .= ("all" :: Text)]) fixtureBricks of
    Left problem -> appErrorCode problem @?= PreconditionFailed
    Right value -> assertFailure ("expected unavailable profile failure, got " <> show value)

explicitRemainingEffort :: Assertion
explicitRemainingEffort = do
  let parent = parentBrick
      evidence = fixtureActual 101 parent fixedTime (Just 7_000_000) (Just 2_500_000)
      state = fixtureState{stateEffortActualEvidence = Map.singleton (effortActualEvidenceId evidence) evidence}
  payload <- assertRight (buildTaskJugglerPayload fixtureExporter fixedTime fixtureCursor state (object ["kind" .= ("all" :: Text)]) fixtureBricks)
  encoded <- assertRight (canonicalJsonBytes payload)
  assertContains encoded "\"effort_macro\":\"EFFORT_4D\""
  assertContains encoded "\"microhours\":\"2500000\""
  assertContains encoded "\"remaining-effort-point-estimate\""
  assertBool "remaining evidence did not suppress the total-effort WIP warning" (not ("\"wip-total-effort\"" `ByteString.isInfixOf` encoded))
  stateEffortClaims state @?= stateEffortClaims fixtureState

missingLatestRemainingEffort :: Assertion
missingLatestRemainingEffort = do
  let parent = parentBrick
      older = fixtureActual 101 parent fixedTime Nothing (Just 2_500_000)
      newer = fixtureActual 102 parent (addUTCTime 60 fixedTime) (Just 8_000_000) Nothing
      state =
        fixtureState
          { stateEffortActualEvidence =
              Map.fromList
                [ (effortActualEvidenceId older, older)
                , (effortActualEvidenceId newer, newer)
                ]
          }
  payload <- assertRight (buildTaskJugglerPayload fixtureExporter fixedTime fixtureCursor state (object ["kind" .= ("all" :: Text)]) fixtureBricks)
  encoded <- assertRight (canonicalJsonBytes payload)
  assertBool "stale remaining evidence leaked past a newer missing observation" (not ("\"remaining_effort\"" `ByteString.isInfixOf` encoded))
  assertContains encoded "\"wip-total-effort\""

fixtureState :: State
fixtureState =
  emptyState
    { stateBricks = Map.fromList [(brickId brick, brick) | brick <- fixtureBricks]
    , stateEffortClaims =
        Map.fromList
          [ (brickId parent, fixtureEffort parent HardEffort)
          , (brickId child, fixtureEffort child EasyEffort)
          ]
    , stateDependencies = Map.singleton (dependencyId dependency) dependency
    }
 where
  parent = parentBrick
  child = childBrick
  missing = missingBrick
  dependency =
    Dependency
      (uuid "0198f000-0000-7000-8000-000000000090")
      (brickId missing)
      (brickId child)
      DependencyActive
      "fixture"
      fixedTime

fixtureBricks :: [Brick]
fixtureBricks = [parentBrick, childBrick, missingBrick]

parentBrick :: Brick
parentBrick = fixtureBrick "0198f000-0000-7000-8000-000000000001" "parent" "Parent cut" Project Nothing 0 Wip

childBrick :: Brick
childBrick = fixtureBrick "0198f000-0000-7000-8000-000000000002" "child" "Overlapping child" AtomicTask (Just (brickId parentBrick)) 0 Idle

missingBrick :: Brick
missingBrick = fixtureBrick "0198f000-0000-7000-8000-000000000003" "gap" "Visible effort gap" AtomicTask Nothing 1 Idle

fixtureBrick :: Text -> Text -> Text -> BrickNature -> Maybe UUIDv7 -> Int -> WorkState -> Brick
fixtureBrick identity handle title nature parent position workState =
  Brick
    (uuid identity)
    (Handle handle)
    title
    nature
    "factory@1"
    "fixture"
    Nothing
    parent
    Set.empty
    position
    (DeterministicPosition "fixture")
    BrickActive
    workState
    fixedTime
    fixtureActor
    (uuid "0198f000-0000-7000-8000-000000000099")

fixtureEffort :: Brick -> EffortClass -> EffortClaim
fixtureEffort brick effortClass = EffortClaim (brickId brick) effortClass fixedTime DirectHuman factoryJudgmentProfileHash

fixtureActual :: Int -> Brick -> UTCTime -> Maybe Integer -> Maybe Integer -> EffortActualEvidence
fixtureActual suffix brick asOf completed remaining =
  EffortActualEvidence
    (fixtureIdentity suffix)
    (brickId brick)
    (fixtureIdentity (suffix + 100))
    (fixtureIdentity (suffix + 200))
    (text64 (if suffix == 101 then 'a' else 'b'))
    ("t_" <> Text.filter (/= '-') (renderUUIDv7 (brickId brick)))
    asOf
    completed
    remaining
    asOf

fixtureIdentity :: Int -> UUIDv7
fixtureIdentity suffix = uuid ("0198f000-0000-7000-8000-" <> Text.justifyRight 12 '0' (Text.pack (show suffix)))

fixtureExporter :: PlanningExporterIdentity
fixtureExporter =
  PlanningExporterIdentity
    "org.littleant.project"
    "org.littleant.standard"
    "1.0.0"
    (text64 'a')
    (text64 'b')
    "taskjuggler"
    (text64 'c')
    (text64 'd')

fixtureCursor :: DatasetCursor
fixtureCursor = DatasetCursor 42 (text64 'e')

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 9) (secondsToDiffTime (9 * 3600))

fixtureActor :: Actor
fixtureActor = Actor "human" "test"

uuid :: Text -> UUIDv7
uuid value = either (error . show) id (parseUUIDv7 value)

rendered :: ByteString -> ByteString
rendered = id

text64 :: Char -> Text
text64 character = Text.replicate 64 (Text.singleton character)

assertContains :: ByteString -> ByteString -> Assertion
assertContains haystack needle = assertBool ("missing fragment: " <> show needle) (needle `ByteString.isInfixOf` haystack)

assertRight :: (Show problem) => Either problem value -> IO value
assertRight = either (assertFailure . show) pure

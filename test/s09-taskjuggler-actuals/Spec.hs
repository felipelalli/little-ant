module Main (main) where

import Control.Monad (foldM)
import Data.Aeson (Value, object, (.=))
import Data.ByteString (ByteString)
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Decision
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Model
import LittleAnt.Pack.Format (canonicalJsonBytes)
import LittleAnt.Pack.Trust (PackArtifactIdentity (..))
import LittleAnt.Source
import LittleAnt.Store (sha256Hex)
import LittleAnt.TaskJugglerActuals
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 TaskJuggler actuals custody"
      [ testCase "partial actuals preserve present zero separately from absent evidence" validPartialActuals
      , testCase "manifest custody rejects a changed digest and noncontiguous chunks" invalidManifestCustody
      , testCase "actuals reject unknown, duplicate, nested, and missing manifest tasks" invalidTaskStructure
      , testCase "actuals reject unsupported fields and imprecise effort syntax" invalidActualFields
      , testCase "actuals require one explicit canonical UTC progress cutoff" invalidAsOf
      , testCase "acceptance persists Raw before immutable evidence and exact retry is event-free" acceptsRawFirstEvidence
      , testCase "acceptance rejects stale, equal nonidentical, and unknown-Brick observations" rejectsUnsafeEvidence
      ]

validPartialActuals :: Assertion
validPartialActuals = do
  parsed <- fixtureSource [(taskOne, ["  actual:effortdone 2.5h"]), (taskTwo, ["  actual:effortleft 0h"])] >>= assertRight . parseTaskJugglerActuals
  actualsAsOf parsed @?= UTCTime (fromGregorian 2026 8 9) (secondsToDiffTime (12 * 3600))
  actualsManifestDigest parsed @?= sha256Hex (actualsManifestBytes parsed)
  actualsRecords parsed
    @?= [ TaskJugglerActual taskOne brickOne (Just (Microhours 2_500_000)) Nothing
        , TaskJugglerActual taskTwo brickTwo Nothing (Just (Microhours 0))
        ]

invalidManifestCustody :: Assertion
invalidManifestCustody = do
  valid <- fixtureSource [(taskOne, ["  actual:effortdone 1h"]), (taskTwo, [])]
  assertCorrupt "changed manifest digest" (Text.replace "LANT-MANIFEST-SHA256: " "LANT-MANIFEST-SHA256: f" (decodeUtf8 valid))
  assertCorrupt "noncontiguous chunks" (Text.replace "BASE64URL-0001" "BASE64URL-0002" (decodeUtf8 valid))

invalidTaskStructure :: Assertion
invalidTaskStructure = do
  valid <- decodeUtf8 <$> fixtureSource [(taskOne, ["  actual:effortdone 1h"]), (taskTwo, [])]
  let unknown = valid <> "\ntask t_unknown \"Unknown\" {\n  actual:effortdone 1h\n}\n"
      duplicate = valid <> "\ntask " <> taskOne <> " \"Again\" {\n}\n"
      nested = Text.replace "  actual:effortdone 1h" "  task t_nested \"Nested\" {\n  }\n  actual:effortdone 1h" valid
      missing = Text.replace ("task " <> taskTwo <> " \"Two\" {\n}\n") "" valid
  mapM_ (uncurry assertCorrupt) [("unknown actual task", unknown), ("duplicate task", duplicate), ("nested task", nested), ("missing manifest task", missing)]

invalidActualFields :: Assertion
invalidActualFields = do
  unsupported <- fixtureSource [(taskOne, ["  actual:complete 1h"]), (taskTwo, [])]
  tooPrecise <- fixtureSource [(taskOne, ["  actual:effortleft 0.1234567h"]), (taskTwo, [])]
  implicitUnit <- fixtureSource [(taskOne, ["  actual:effortdone 2"]), (taskTwo, [])]
  duplicate <- fixtureSource [(taskOne, ["  actual:effortdone 1h", "  actual:effortdone 2h"]), (taskTwo, [])]
  mapM_ (uncurry assertCorruptBytes) [("unsupported actual", unsupported), ("over-precise actual", tooPrecise), ("missing hours unit", implicitUnit), ("duplicate actual", duplicate)]

invalidAsOf :: Assertion
invalidAsOf = do
  valid <- decodeUtf8 <$> fixtureSource [(taskOne, ["  actual:effortdone 1h"]), (taskTwo, [])]
  assertCorrupt "placeholder now" (Text.replace "now 2026-08-09-12:00" "now ${projectstart}" valid)
  assertCorrupt "multiple now values" (Text.replace "now 2026-08-09-12:00" "now 2026-08-09-12:00\n  now 2026-08-09-13:00" valid)
  assertCorrupt "noncanonical now" (Text.replace "now 2026-08-09-12:00" "now 2026-8-9-12:00" valid)
  assertCorrupt "non-UTC project" (Text.replace "timezone \"UTC\"" "timezone \"Europe/Berlin\"" valid)
  assertCorrupt "now outside project" (Text.replace "  now 2026-08-09-12:00" "" valid <> "\nnow 2026-08-09-12:00\n")
  assertCorrupt "unbalanced project" (Text.replace "\n}\n\ntask" "\n\ntask" valid)

acceptsRawFirstEvidence :: Assertion
acceptsRawFirstEvidence = do
  bytes <- fixtureSource [(taskOne, ["  actual:effortdone 2.5h"]), (taskTwo, ["  actual:effortleft 0h"])]
  preflight <- fixturePreflight bytes
  count <- assertRight (importAcceptanceUUIDCount fixtureState fixtureReference Set.empty preflight)
  count @?= 11
  decision <- assertRight (decideAcceptImport fixtureState fixtureActor fixtureReference Set.empty (fixtureInput bytes) preflight (fixtureMaterials bytes preflight) (facts 1 count))
  fmap (eventTypeName . draftPayload) (importAcceptanceEvents decision)
    @?= [ "import_profile_changed"
        , "raw_fed"
        , "source_binding_changed"
        , "import_invocation_recorded"
        , "effort_actual_observed"
        , "effort_actual_observed"
        ]
  accepted <- applyEvents fixtureState (importAcceptanceEvents decision)
  Map.size (stateRaws accepted) @?= 1
  Map.size (stateEffortActualEvidence accepted) @?= 2
  stateEffortClaims accepted @?= Map.empty
  let evidence = Map.elems (stateEffortActualEvidence accepted)
  assertBool "present zero was lost" (any ((== Just 0) . effortActualRemainingMicrohours) evidence)
  assertBool "missing remaining became zero" (any ((== Nothing) . effortActualRemainingMicrohours) evidence)
  retryCount <- assertRight (importAcceptanceUUIDCount accepted fixtureReference Set.empty preflight)
  retryCount @?= 0
  retry <- assertRight (decideAcceptImport accepted fixtureActor fixtureReference Set.empty (fixtureInput bytes) preflight (fixtureMaterials bytes preflight) (facts 50 0))
  importAcceptanceCommandId retry @?= Nothing
  importAcceptanceEvents retry @?= []

rejectsUnsafeEvidence :: Assertion
rejectsUnsafeEvidence = do
  initialBytes <- fixtureSource [(taskOne, ["  actual:effortleft 4h"]), (taskTwo, ["  actual:effortdone 1h"])]
  initialPreflight <- fixturePreflight initialBytes
  initialCount <- assertRight (importAcceptanceUUIDCount fixtureState fixtureReference Set.empty initialPreflight)
  initialDecision <- assertRight (decideAcceptImport fixtureState fixtureActor fixtureReference Set.empty (fixtureInput initialBytes) initialPreflight (fixtureMaterials initialBytes initialPreflight) (facts 1 initialCount))
  accepted <- applyEvents fixtureState (importAcceptanceEvents initialDecision)

  let equalChanged = TextEncoding.encodeUtf8 (Text.replace "actual:effortleft 4h" "actual:effortleft 3h" (TextEncoding.decodeUtf8 initialBytes))
      older = TextEncoding.encodeUtf8 (Text.replace "now 2026-08-09-12:00" "now 2026-08-09-11:59" (TextEncoding.decodeUtf8 initialBytes))
  equalPreflight <- fixturePreflight equalChanged
  olderPreflight <- fixturePreflight older
  assertCode Conflict (importAcceptanceUUIDCount accepted fixtureReference Set.empty equalPreflight)
  olderCount <- assertRight (importAcceptanceUUIDCount accepted fixtureReference Set.empty olderPreflight)
  assertCode Conflict (decideAcceptImport accepted fixtureActor fixtureReference Set.empty (fixtureInput older) olderPreflight (fixtureMaterials older olderPreflight) (facts 80 olderCount))

  let missingBrickState = fixtureState{stateBricks = Map.delete brickTwo (stateBricks fixtureState)}
  missingCount <- assertRight (importAcceptanceUUIDCount missingBrickState fixtureReference Set.empty initialPreflight)
  assertCode NotFound (decideAcceptImport missingBrickState fixtureActor fixtureReference Set.empty (fixtureInput initialBytes) initialPreflight (fixtureMaterials initialBytes initialPreflight) (facts 110 missingCount))

fixtureSource :: [(Text, [Text])] -> IO ByteString
fixtureSource taskActuals = do
  manifestBytes <- assertRight (canonicalJsonBytes manifest)
  let digest = sha256Hex manifestBytes
      encoded = TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded manifestBytes)
      chunks = chunksOf 80 encoded
      manifestLines =
        ["# LANT-MANIFEST-SHA256: " <> digest]
          <> zipWith (\index chunk -> "# LANT-MANIFEST-JCS-BASE64URL-" <> fourDigits index <> ": " <> chunk) [1 :: Int ..] chunks
      sourceLines =
        manifestLines
          <> [ ""
             , "project p \"Fixture\" \"1.0\" 2026-08-01 +1m {"
             , "  timezone \"UTC\""
             , "  now 2026-08-09-12:00"
             , "  scenario plan \"Plan\" {"
             , "    scenario actual \"Actual\""
             , "  }"
             , "  trackingscenario actual"
             , "}"
             , ""
             ]
          <> concatMap taskLines taskActuals
  pure (TextEncoding.encodeUtf8 (Text.unlines sourceLines))
 where
  manifest =
    object
      [ "schema" .= ("little-ant/planning-manifest@1" :: Text)
      , "cut"
          .= [ object ["task_id" .= taskOne, "brick_id" .= renderUUIDv7 brickOne, "order" .= (0 :: Int), "dependencies" .= ([] :: [Text])]
             , object ["task_id" .= taskTwo, "brick_id" .= renderUUIDv7 brickTwo, "order" .= (1 :: Int), "dependencies" .= ([] :: [Text])]
             ]
      , "source" .= object ["cursor" .= ("42:fixture" :: Text), "hash" .= Text.replicate 64 "a"]
      , "scope" .= object ["kind" .= ("all" :: Text)]
      , "planned_at" .= ("2026-08-09T12:00:00Z" :: Text)
      , "roots" .= ([] :: [Text])
      , "effort_profile" .= object ["id" .= ("fixture" :: Text)]
      , "warnings" .= ([] :: [Value])
      , "resources" .= ([] :: [Value])
      , "calendars" .= ([] :: [Value])
      , "projection" .= object ["schema" .= ("little-ant/taskjuggler@1" :: Text)]
      , "exporter" .= object ["component" .= ("taskjuggler" :: Text)]
      ]
  taskLines (taskId, fields) = ["task " <> taskId <> " \"" <> title taskId <> "\" {"] <> fields <> ["}", ""]
  title taskId = if taskId == taskOne then "One" else "Two"

chunksOf :: Int -> Text -> [Text]
chunksOf width value
  | Text.null value = []
  | otherwise = let (prefix, suffix) = Text.splitAt width value in prefix : chunksOf width suffix

fourDigits :: Int -> Text
fourDigits = Text.justifyRight 4 '0' . Text.pack . show

taskOne, taskTwo :: Text
taskOne = "t_0198f000000070008000000000000011"
taskTwo = "t_0198f000000070008000000000000012"

brickOne, brickTwo :: UUIDv7
brickOne = uuid "0198f000-0000-7000-8000-000000000011"
brickTwo = uuid "0198f000-0000-7000-8000-000000000012"

fixtureState :: State
fixtureState =
  emptyState
    { stateBricks = Map.fromList [(brickOne, fixtureBrick brickOne "one" "One" 0), (brickTwo, fixtureBrick brickTwo "two" "Two" 1)]
    }

fixtureBrick :: UUIDv7 -> Text -> Text -> Int -> Brick
fixtureBrick identity handle title position =
  Brick
    identity
    (Handle handle)
    title
    AtomicTask
    "factory@1"
    "fixture"
    Nothing
    Nothing
    Set.empty
    position
    (DeterministicPosition "fixture")
    BrickActive
    Wip
    observedAt
    fixtureActor
    (fixtureUuid 999)

fixturePreflight :: ByteString -> IO SourcePreflight
fixturePreflight bytes = do
  actuals <- assertRight (parseTaskJugglerActuals bytes)
  text <- either (assertFailure . show) pure (TextEncoding.decodeUtf8' bytes)
  let digest = sha256Hex bytes
      asOf = Text.pack (formatTime defaultTimeLocale "%Y-%m-%d-%H:%MZ" (actualsAsOf actuals))
      observation =
        SourceAdapterObservation
          "TaskJuggler actuals"
          Nothing
          ( Map.fromList
              [ ("planning_manifest_sha256", actualsManifestDigest actuals)
              , ("actuals_as_of", asOf)
              , ("actual_record_count", Text.pack (show (length (actualsRecords actuals))))
              ]
          )
          [SourceSnapshot]
          False
          []
          [ SourceObject
              ("manifest:" <> actualsManifestDigest actuals <> "@" <> asOf)
              ("manifest-sha256:" <> actualsManifestDigest actuals)
              Nothing
              "actuals.tjp"
              SourceOtherShape
              False
              0
              (summarizeSourceMaterial (SourceTextMaterial text))
              [digest, actualsManifestDigest actuals]
          ]
          []
          ["Actual effort remains evidence; historical estimates are unchanged."]
  assertRight
    ( makeSourcePreflight
        "taskjuggler_actuals"
        fixturePack
        (sha256Hex "fixture signer")
        1
        fixturePermissions
        SourceSnapshot
        (fixtureInput bytes)
        observation
    )

fixtureInput :: ByteString -> SourceInput
fixtureInput = SourceInput "actuals.tjp" "text/x-taskjuggler; charset=utf-8"

fixtureMaterials :: ByteString -> SourcePreflight -> Map.Map Text SourceMaterial
fixtureMaterials bytes preflight =
  case observedObjects (sourcePreflightObservation preflight) of
    [sourceObject] -> Map.singleton (sourceObjectExternalId sourceObject) (SourceTextMaterial (TextEncoding.decodeUtf8 bytes))
    _ -> Map.empty

fixturePack :: PackArtifactIdentity
fixturePack =
  PackArtifactIdentity
    "org.littleant.project"
    "org.littleant.standard"
    "1.0.0"
    (sha256Hex "fixture manifest")
    (sha256Hex "fixture archive")

fixturePermissions :: Text
fixturePermissions = "{\"credential_slots\":[],\"effect_purposes\":[],\"host_capabilities\":[\"input_bytes\"],\"http\":[],\"projections\":[]}"

fixtureReference :: Text
fixtureReference = "actuals.tjp"

fixtureActor :: Actor
fixtureActor = Actor "human" "test"

observedAt :: UTCTime
observedAt = UTCTime (fromGregorian 2026 8 9) (secondsToDiffTime (13 * 3600))

facts :: Int -> Int -> RuntimeFacts
facts base count =
  RuntimeFacts
    observedAt
    [UUIDAllocation (renderUUIDv7 (fixtureUuid number)) | number <- [base .. base + count - 1]]
    Map.empty
    (FilesystemFacts True True Nothing)
    (TerminalCapabilities False False False 80 24 False)
    []

fixtureUuid :: Int -> UUIDv7
fixtureUuid number =
  either (error . show) id $
    uuidV7FromEntropy
      (0x019f22340000 + fromIntegral number)
      (TextEncoding.encodeUtf8 (Text.justifyRight 10 'x' (Text.pack (show (number `mod` 1000000000)))))

applyEvents :: State -> [EventDraft] -> IO State
applyEvents state events = do
  persisted <- traverse (assertRight . decodeEvent . encodeEvent) (zipWith persist [stateEventCount state + 1 ..] events)
  assertRight (foldM applyEvent state persisted)

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

assertCode :: ErrorCode -> Either AppError value -> Assertion
assertCode expected = \case
  Left problem -> appErrorCode problem @?= expected
  Right _ -> assertFailure ("expected " <> show expected <> " failure")

uuid :: Text -> UUIDv7
uuid value = either (error . Text.unpack) id (parseUUIDv7 value)

decodeUtf8 :: ByteString -> Text
decodeUtf8 = TextEncoding.decodeUtf8

assertCorrupt :: String -> Text -> Assertion
assertCorrupt label = assertCorruptBytes label . TextEncoding.encodeUtf8

assertCorruptBytes :: String -> ByteString -> Assertion
assertCorruptBytes label bytes = case parseTaskJugglerActuals bytes of
  Left problem -> appErrorCode problem @?= CorruptData
  Right parsed -> assertFailure (label <> ": expected corrupt-data failure, got " <> show parsed)

assertRight :: (Show problem) => Either problem value -> IO value
assertRight = either (assertFailure . show) pure

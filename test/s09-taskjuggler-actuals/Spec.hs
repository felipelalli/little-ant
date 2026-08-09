module Main (main) where

import Data.Aeson (Value, object, (.=))
import Data.ByteString (ByteString)
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Pack.Format (canonicalJsonBytes)
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

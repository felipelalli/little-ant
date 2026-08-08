module Main (main) where

import Data.Aeson (encode)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Protocol
import LittleAnt.Store
import System.Directory qualified
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "S01 protocol contract"
    [ testCase "headless shortcut dispatch consumes the envelope action identity" $ do
        envelope <- pristine "same" Genesis
        dispatchGuidedShortcut envelope envelope "f"
          @?= Right (GuidedAccepted "feed.open" OpenFeedInput Genesis Genesis)
        case dispatchGuidedShortcut envelope envelope "x" of
          Left problem -> appErrorCode problem @?= InvalidInput
          Right other -> assertFailure ("unbound key unexpectedly dispatched: " <> show other)
    , testCase "headless dispatch returns the replacement for a relevant stale response" $ do
        original <- pristine "before" Genesis
        current <- pristine "after" (DatasetCursor 1 (Text.replicate 64 "a"))
        case dispatchGuidedShortcut original current "f" of
          Right (GuidedStale replacement) -> envelopePreconditionHash replacement @?= "after"
          other -> assertFailure ("expected stale replacement, got: " <> show other)
    , testCase "accepted current event bytes round-trip byte-identically" $ do
        names <- System.Directory.listDirectory "test/fixtures/s01-current/events"
        case names of
          [name] -> do
            bytes <- ByteString.readFile ("test/fixtures/s01-current/events/" <> name)
            let line = ByteString.init bytes
            event <- either (assertFailure . show) pure (decodeEvent line)
            encodeEvent event @?= line
          _ -> assertFailure "expected one current fixture"
    , testCase "pristine structured envelope has the closed schema-owned shape" $ do
        envelope <- pristine (statePreconditionHash emptyState) Genesis
        let bytes = LazyByteString.toStrict (encode envelope)
        assertBool "required integrity token" ("\"integrity_token\"" `ByteString.isInfixOf` bytes)
        assertBool "required ordered actions" ("\"actions\"" `ByteString.isInfixOf` bytes)
        assertBool "inapplicable uncertainty is absent" (not ("uncertainty_route" `ByteString.isInfixOf` bytes))
    ]

pristine :: Text.Text -> DatasetCursor -> IO InteractionEnvelope
pristine precondition cursor = do
  identity <-
    either
      (assertFailure . Text.unpack)
      pure
      (parseUUIDv7 "0198f8a3-4c21-7b6e-9d05-82fa731c4e60")
  pure (makePristineEnvelope identity cursor precondition fixedNow)

fixedNow :: ZonedTime
fixedNow =
  ZonedTime
    (LocalTime (fromGregorian 2026 8 3) (TimeOfDay 9 0 0))
    (minutesToTimeZone (-180))

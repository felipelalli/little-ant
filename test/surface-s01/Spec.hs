module Main (main) where

import Data.Text qualified as Text
import Data.Time
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Projection
import LittleAnt.REPL
import LittleAnt.Reference
import LittleAnt.Store
import LittleAnt.Surface
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "S01 guided-surface parity"
    [ testCase "Raw autocomplete ranks exact handle and preserves a UUID-backed choice" $ do
        dataset <- loadFixture
        let candidates = searchRawReferences True "+cl" (loadedState dataset)
        case candidates of
          ExistingRawCandidate identity (Handle "cl") "comprar leite" 0 : _ ->
            renderUUIDv7 identity @?= "019fe080-4345-7968-beff-225371464a95"
          other -> assertFailure ("unexpected ranking: " <> show other)
        let plain = renderPlain (renderRawAutocomplete "+cl" 0 candidates)
        assertBool "ASCII selection cursor survives styling" ("> +cl \"comprar leite\"" `Text.isInfixOf` plain)
        assertBool "creation is explicit" ("New raw material..." `Text.isInfixOf` plain)
    , testCase "reference search never fabricates a candidate" $ do
        dataset <- loadFixture
        searchRawReferences False "definitely absent" (loadedState dataset) @?= []
    , testCase "palette filters only commands declared by the current envelope" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            commands = filteredCommands envelope "/f"
        fmap commandOptionId commands @?= ["feed"]
        let plain = renderPlain (paletteModel envelope "/f" 0)
        assertBool "palette has stable cursor" ("> /feed" `Text.isInfixOf` plain)
        assertBool "palette has exact navigation hint" ("↑/↓ select · Enter run · Esc back" `Text.isInfixOf` plain)
    , testCase "the reference REPL frame exposes a direct quit gesture" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            wide = renderPlain (replEnvelopeModelAtWidth 80 envelope)
            narrowLines = fmap plainLine (screenLines (replEnvelopeModelAtWidth 20 envelope))
            narrowQuitLines = filter ("[q] quit" `Text.isInfixOf`) narrowLines
        assertBool "wide frame must place quit beside more" ("[/] more...   [q] quit" `Text.isInfixOf` wide)
        assertBool "narrow frame must retain quit" (not (null narrowQuitLines))
        assertBool "narrow quit control must not overflow" (all ((<= 20) . Text.length) narrowQuitLines)
    , testCase "loading splash reports factual counts without a six-digit ceiling" $ do
        let small = renderPlain (progressModel 7)
            large = renderPlain (progressModel 1000000)
        assertBool "small count is padded" ("Loading 000007..." `Text.isInfixOf` small)
        assertBool "large count grows" ("Loading 1000000..." `Text.isInfixOf` large)
    , testCase "narrow rendering reflows every action without semantic truncation" $ do
        dataset <- loadFixture
        identity <- fixtureIdentity
        raw <- case inboxRaws (loadedState dataset) of
          one : _ -> pure one
          [] -> assertFailure "fixture has no Inbox Raw"
        let state = loadedState dataset
            envelope = makeRawTriageEnvelope identity (loadedCursor dataset) (statePreconditionHash state) fixedNow state raw
            renderedLines = fmap plainLine (screenLines (renderEnvelopeAtWidth 28 envelope))
            rendered = Text.unlines renderedLines
        mapM_
          (\label -> assertBool ("missing action: " <> Text.unpack label) (label `Text.isInfixOf` rendered))
          ["[y]es", "[n]o", "[s]kip", "[?] I don't know", "[/] more..."]
        assertBool ("oversized rows: " <> show (filter ((> 28) . Text.length) renderedLines)) (all ((<= 28) . Text.length) renderedLines)
    ]

loadFixture :: IO LoadedDataset
loadFixture =
  loadDataset (StoreConfig "test/fixtures/s01-current" 100000 1000) (const (pure ()))
    >>= either (assertFailure . show) pure

fixtureIdentity :: IO UUIDv7
fixtureIdentity =
  either
    (assertFailure . Text.unpack)
    pure
    (parseUUIDv7 "0198f8a3-4c21-7b6e-9d05-82fa731c4e60")

fixedNow :: ZonedTime
fixedNow =
  ZonedTime
    (LocalTime (fromGregorian 2026 8 3) (TimeOfDay 9 0 0))
    (minutesToTimeZone (-180))

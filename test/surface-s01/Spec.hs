module Main (main) where

import Data.Text qualified as Text
import Data.Time
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Markdown
import LittleAnt.Model
import LittleAnt.Projection
import LittleAnt.REPL
import LittleAnt.Reference
import LittleAnt.Result
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
    , testCase "loading splash reports factual counts without a six-digit ceiling" $ do
        let small = renderPlain (progressModel 7)
            large = renderPlain (progressModel 1000000)
        assertBool "small count is padded" ("Loading 000007..." `Text.isInfixOf` small)
        assertBool "large count grows" ("Loading 1000000..." `Text.isInfixOf` large)
    , testCase "palette bounds long citations without changing commands or search" $ do
        identity <- fixtureIdentity
        let title = "Avaliar a variante " <> Text.replicate 80 "界🙂 contexto " <> "LAST_TITLE_WORD"
            citation = "#longtitle \"" <> title <> "\""
            command = CommandOption "show" ("/show " <> citation) ("Inspect " <> citation)
            envelope = (makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow){envelopeCommands = [command]}
            model = paletteModel envelope "/" 0
            plain = renderPlain model
        assertBool "palette rows overflow the terminal" (all ((<= 80) . textDisplayWidth . plainLine) (screenLines model))
        assertBool "a truncated title needs a visible marker" ("(...)" `Text.isInfixOf` plain)
        Text.count "Avaliar a variante" plain @?= 1
        assertBool "the description repeated the complete title" (not ("LAST_TITLE_WORD" `Text.isInfixOf` plain))
        paletteCommandSelection envelope "/show" 0 @?= Just command
        filteredCommands envelope "/LAST_TITLE_WORD" @?= [command]
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
          ["[y]es", "[n]o", "[s]kip", "I don't [k]now", "[/] more..."]
        assertBool ("oversized rows: " <> show (filter ((> 28) . Text.length) renderedLines)) (all ((<= 28) . Text.length) renderedLines)
    , testCase "legacy uncertainty reserves k without selecting keep or colliding with edit" $ do
        identity <- fixtureIdentity
        let base = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            old = resealEnvelope base{envelopeActions = [Action "keep" "keep current" "k" True "Keep the current value.", Action "edit" "edit" "e" False "Edit the value.", Action "unknown" "I don't know" "?" False "Inspect the choices."]}
            resumed = upgradePresentationEnvelope old
        fmap actionShortcut (envelopeActions resumed) @?= ["p", "e", "k"]
        fmap actionId (envelopeActions resumed) @?= ["keep", "edit", "unknown"]
        fmap actionDefault (envelopeActions resumed) @?= [True, False, False]
        envelopeOpportunity resumed @?= envelopeOpportunity old
        assertBool "updated shortcuts invalidated the envelope" (envelopeIntegrityIsValid resumed)
        upgradePresentationEnvelope resumed @?= resumed
    , testCase "global browsing commands are available during an ordinary pending question" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
        assertBool "list is missing" ("list" `elem` fmap commandOptionId (envelopeCommands envelope))
        assertBool "search is missing" ("search" `elem` fmap commandOptionId (envelopeCommands envelope))
        case paletteCommandSelection envelope "/search +milk" 0 of
          Just command -> commandOptionCommand command @?= "/search +milk"
          Nothing -> assertFailure "a typed search argument disappeared from the palette"
    , testCase "a shortcut inside a label preserves the complete word" $ do
        identity <- fixtureIdentity
        let envelope = (makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow){envelopeActions = [Action "choose" "one off purchase" "e" False "Choose this setup."]}
        assertBool "shortcut corrupted the label" ("on[e] off purchase" `Text.isInfixOf` renderPlain (renderEnvelope envelope))
    , testCase "only the exact quit spelling selects the canonical exit command" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
        fmap commandOptionId (paletteCommandSelection envelope "/quit" 0) @?= Just "exit"
        fmap commandOptionCommand (paletteCommandSelection envelope "/quit" 0) @?= Just "/exit"
        paletteCommandSelection envelope "/quit extra" 0 @?= Nothing
        paletteCommandSelection envelope "/quitter" 0 @?= Nothing
        assertBool "the palette duplicated exit vocabulary" (not ("/quit" `Text.isInfixOf` renderPlain (paletteModel envelope "/" 0)))
    , testCase "target-less Brick commands list eligible Bricks and preselect the screen's Brick" $ do
        identity <- fixtureIdentity
        let pristine = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            envelope = pristine{envelopeContent = (envelopeContent pristine){contentSubject = Just "#ctailip \"Create the label\""}}
            hit handle status = SearchHit "brick" handle ("Title " <> handle) ("status: " <> status <> " · atomic task")
            hits =
              [ hit "#aaa" "done"
              , hit "#bbb" "active"
              , hit "#ccc" "archived"
              , hit "#ctailip" "active"
              , hit "#ddd" "in progress"
              , SearchHit "raw" "+raw" "Raw" "inbox"
              ]
            handles (targets, selected) = (fmap searchHitHandle targets, selected)
        handles (brickCommandTargets envelope "archive" hits) @?= (["#bbb", "#ctailip", "#ddd"], 1)
        handles (brickCommandTargets envelope "restore" hits) @?= (["#ccc"], 0)
        handles (brickCommandTargets envelope "update" hits) @?= (["#aaa", "#bbb", "#ccc", "#ctailip", "#ddd"], 3)
        handles (brickCommandTargets pristine "archive" hits) @?= (["#bbb", "#ctailip", "#ddd"], 0)
    , testCase "forecast browsing explains chance and sibling-local position" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            plain = renderPlain (browserModel 80 envelope "Focus forecast" [] "" 0 Nothing)
        assertBool "chance lacks its draw context" ("when next draws flexible work" `Text.isInfixOf` plain)
        assertBool "position appears global" ("local to each sibling group" `Text.isInfixOf` plain)
    , testCase "list controls stay pinned while categories retain context and forecast chances" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            parent = ListRow "#talk" "Prepare presentation" "position 1 · project · context only"
            child = ListRow "#diagram" "Draw diagram" "60.0% · importance position 1"
            others = [ListRow ("#b" <> Text.pack (show index)) "Other task" "1.0%" | index <- [1 .. 35 :: Int]]
            categories = [ListCategory "Work" [ListCategory "Talks" [ListItem parent True [ListItem child False []]]], ListCategory "Other" [ListItem row False [] | row <- others]]
            view = ListView "forecast" [] (child : others) categories True "diagram" True 1 Nothing
            filtered = renderPlain (listModel 80 envelope view)
        mapM_ (\fragment -> assertBool ("missing grouped context: " <> Text.unpack fragment) (fragment `Text.isInfixOf` filtered)) ["Work", "Talks", "#talk", "#diagram", "60.0%", "context only"]
        assertBool "search retained an unrelated category" (not ("Other task" `Text.isInfixOf` filtered))
        [spanText spanValue | row <- screenLines (listModel 80 envelope view), spanValue <- row, spanRole spanValue == Selected] @?= ["Draw diagram"]
        mapM_
          ( \width -> do
              let model = viewportModel width 24 0 (listModel width envelope view{listViewGrouped = False, listViewQuery = "", listViewSearching = False, listViewSelected = 35})
                  plain = renderPlain model
              mapM_ (\fragment -> assertBool ("pinned list control missing: " <> Text.unpack fragment) (fragment `Text.isInfixOf` plain)) ["#b35", "[v]", "[t]", "Ctrl+F", "mode:"]
              assertBool "viewport is taller than the terminal" (length (screenLines model) <= 24)
              assertBool "list overflowed its width" (all ((<= width) . textDisplayWidth . plainLine) (screenLines model))
          )
          [80, 28]
        let longRow = ListRow "#long" "A detailed selected task with several wrapped words and lastword" "active"
            page = viewportModel 28 24 0 (listModel 28 envelope view{listViewEntries = others <> [longRow] <> others, listViewGrouped = False, listViewQuery = "", listViewSearching = False, listViewSelected = 35})
        assertBool "pagination clipped the last line of the selected title" ("lastword" `Text.isInfixOf` renderPlain page)
    , testCase "selection scrolling preserves context in both directions and clamps at list ends" $ do
        let source chosen = ScreenModel ([[Span (if index == chosen then Selected else Normal) ("Row " <> Text.pack (show index))] | index <- [1 .. 80 :: Int]] <> [[Span Dim "────────────────────"], [Span Dim "Fixed footer"]]) Nothing
            linesAt chosen offset = plainLine <$> screenLines (viewportModel 80 14 offset (source chosen))
        mapM_
          ( \offset -> do
              let rows = linesAt 40 offset
              mapM_ (\index -> assertBool "selection lost its surrounding context" (("Row " <> Text.pack (show index)) `elem` rows)) [37 .. 43 :: Int]
              assertBool "context displaced the pinned footer" ("Fixed footer" `elem` rows)
              assertBool "context exceeded the terminal height" (length rows <= 14)
          )
          [0, 60]
        assertBool "scrolling above the first item hid it" ("Row 1" `elem` linesAt 1 60)
        assertBool "scrolling below the last item hid it" ("Row 80" `elem` linesAt 80 0)
        linesAt 40 36 @?= linesAt 41 36
    , testCase "a large browser keeps its last selected Brick and footer visible" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            entries = [SearchHit "brick" ("#b" <> Text.pack (show index)) ("Task " <> Text.pack (show index)) "active" | index <- [1 .. 50 :: Int]]
            model = viewportModel 80 24 0 (browserModel 80 envelope "Importance order" entries "" 49 Nothing)
            plain = renderPlain model
        assertBool "selection was clipped" ("#b50 Task 50" `Text.isInfixOf` plain)
        assertBool "footer was clipped" ("mode:" `Text.isInfixOf` plain)
        assertBool "viewport is taller than the terminal" (length (screenLines model) <= 24)
    , testCase "composition branches survive filtering, narrow pages, and CLI rendering" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            entries =
              [ SearchHit "brick" "#talk" "Prepare presentation" "project"
              , SearchHit "brick" "#outline" "  Define outline" "atomic task"
              , SearchHit "brick" "#slides" "  Prepare slides" "project"
              , SearchHit "brick" "#intro" "    Write introduction" "atomic task"
              , SearchHit "brick" "#diagram" "    Draw diagram" "atomic task"
              , SearchHit "brick" "#rehearse" "  Rehearse talk" "atomic task"
              , SearchHit "brick" "#other" "Other root" "atomic task"
              ]
            model query selected = browserModel 80 envelope "Importance order" entries query selected Nothing
            full = renderPlain (model "" 0)
            filtered = model "diagram" 2
            plain = renderPlain filtered
            cli = renderCommandResult (ListResult Genesis "importance" [ListRow (searchHitHandle hit) (searchHitTitle hit) "" | hit <- entries] [] False)
        mapM_ (\branch -> assertBool ("missing branch " <> Text.unpack branch) (branch `Text.isInfixOf` full)) ["├── #outline", "├── #slides", "│   ├── #intro", "│   └── #diagram", "└── #rehearse"]
        mapM_ (\handle -> assertBool "search lost ancestor context" (handle `Text.isInfixOf` plain)) ["#talk", "#slides", "#diagram"]
        assertBool "search retained an unrelated root or sibling" (not ("#other" `Text.isInfixOf` plain || "#outline" `Text.isInfixOf` plain))
        [spanText spanValue | row <- screenLines filtered, spanValue <- row, spanRole spanValue == Selected] @?= ["Draw diagram"]
        assertBool "parent matches should retain their parts" ("#rehearse" `Text.isInfixOf` renderPlain (model "presentation" 0))
        assertBool "CLI connectors must precede the handle" ("│   └── #diagram Draw diagram" `Text.isInfixOf` cli)
        assertBool "CLI must not prefix tree nodes with a second bullet" (not ("- ├──" `Text.isInfixOf` cli))
        let narrow = viewportModel 28 24 0 (browserModel 28 envelope "Importance order" entries "" 5 Nothing)
        assertBool "selected leaf was clipped" ("#rehearse" `Text.isInfixOf` renderPlain narrow)
        assertBool "tree overflowed the terminal" (all ((<= 28) . textDisplayWidth . plainLine) (screenLines narrow))
        let wrapped = browserModel 28 envelope "Importance order" [SearchHit "brick" "#talk" "Prepare presentation" "project", SearchHit "brick" "#part" "  Draw a detailed illustration" "atomic task"] "" 1 Nothing
            wrappedLines = plainLine <$> screenLines wrapped
        assertBool "wrapped title lost its tree continuation" ("      illustration" `elem` wrappedLines)
        assertBool "tree wrapping split an ordinary word" (not (any (Text.isSuffixOf "illustra") wrappedLines))
    , testCase "long words and wide characters fit the declared terminal cells" $ do
        let text = Text.replicate 30 "界" <> " https://example.com/" <> Text.replicate 100 "x"
            linesAtWidth = wrapDisplayText 28 text
            styled = wrapScreenLine 28 [Span Selected text]
        assertBool "wide prose overflowed" (all ((<= 28) . textDisplayWidth) linesAtWidth)
        assertBool "wide styled prose overflowed" (all ((<= 28) . textDisplayWidth . plainLine) styled)
        Text.concat (plainLine <$> styled) @?= text
    , testCase "Markdown distinguishes hierarchy, emphasis, code, and visible links" $ do
        let rows = markdownLines 80 "## Heading\n\nA **strong** word, *emphasis*, `state_raw_original`, and [docs](https://example.com)."
            spans = concat rows
        assertBool "heading was left as literal Markdown" (Span Heading "Heading" `elem` spans)
        assertBool "strong emphasis disappeared" (any ((== Strong) . spanRole) spans)
        assertBool "italic emphasis disappeared" (any ((== Emphasis) . spanRole) spans)
        assertBool "code lost its identifier or style" (Span Code "state_raw_original" `elem` spans)
        assertBool "a link hid its destination" (any (Text.isInfixOf "https://example.com" . spanText) spans)
        assertBool "an unmatched code marker consumed text" ("`unfinished" `Text.isInfixOf` Text.concat (plainLine <$> markdownLines 80 "`unfinished"))
    , testCase "only prose is reflowed and justified inside a bounded reading width" $ do
        let prose = "Ordinary prose with enough words to span several lines\ncontinues the same paragraph without hard source wrapping."
            rows = plainLine <$> markdownLines 32 prose
        assertBool "prose did not wrap" (length rows > 1)
        assertBool "non-final prose lines were not justified" (all ((== 32) . textDisplayWidth) (init rows))
        assertBool "final line must remain left aligned" (textDisplayWidth (last rows) < 32)
        let structured = plainLine <$> markdownLines 32 "- alpha beta gamma\n* delta epsilon zeta\n`source identifier`\n#handle citation\nNature: atomic task"
        structured @?= ["- alpha beta gamma", "* delta epsilon zeta", "source identifier", "#handle citation", "Nature: atomic task"]
        assertBool "wide terminal produced an unreadable measure" (all ((<= 96) . textDisplayWidth . plainLine) (markdownLines 160 (Text.replicate 50 "word ")))
    , testCase "fenced code keeps spaces and Unicode documents fit narrow cells" $ do
        let rows = markdownLines 28 "```haskell\n  let value =  a +  b\n```\n\nOlá 界界 com `a  b` e um identificador muito longo: https://example.com/abcdefghijklmnopqrstuvwxyz"
        assertBool "code indentation or internal spacing changed" ([Span Code "  let value =  a +  b"] `elem` rows)
        assertBool "inline code spacing changed" (Span Code "a  b" `elem` concat rows)
        assertBool "Markdown overflowed terminal cells" (all ((<= 28) . textDisplayWidth . plainLine) rows)
        assertBool "terminal escape was allowed into material" (not ("\ESC" `Text.isInfixOf` Text.concat (plainLine <$> markdownLines 80 "before\ESC[31mafter")))
    , testCase "wrapped inspection titles retain one hierarchy and narrow scroll hints remain whole" $ do
        identity <- fixtureIdentity
        let envelope = makePristineEnvelope identity Genesis (statePreconditionHash emptyState) fixedNow
            model = documentModel 28 envelope ("#handle \"A long Brick title that spans several terminal lines\"\n\n" <> Text.replicate 40 "An ordinary paragraph.\n\n") "Esc back"
            title = takeWhile (not . null) (screenLines model)
            viewport = renderPlain (viewportModel 28 18 0 model)
        assertBool "fixture title did not wrap" (length title > 1)
        assertBool "a title continuation lost its emphasis" (all (all ((== Heading) . spanRole)) title)
        assertBool "the narrow view hid its scroll controls" (" · ↑/↓" `Text.isInfixOf` viewport)
        assertBool "a page-key hint was cut in half" (not ("PgUp/P" `Text.isInfixOf` viewport))
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

module LittleAnt.REPL (filteredCommands, paletteModel, progressModel, runRepl) where

import Control.Exception (bracket)
import Control.Monad (void)
import Data.Maybe (fromMaybe, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Graphics.Vty (Modifier (MCtrl), Vty, nextEvent, picForImage, shutdown, update)
import Graphics.Vty.Config (defaultConfig)
import Graphics.Vty.CrossPlatform qualified as CrossPlatform
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Interaction
import LittleAnt.Projection
import LittleAnt.Protocol
import LittleAnt.Result
import LittleAnt.Surface
import LittleAnt.Terminal
import System.Environment (lookupEnv)
import System.IO (hIsTerminalDevice, stdin, stdout)

data ReplScreen
  = EnvelopeScreen InteractionEnvelope (Maybe Text)
  | FeedEditor InteractionEnvelope EditorState (Maybe Text)
  | InteractionEditor InteractionEnvelope Text EditorState (Maybe Text)
  | PaletteScreen InteractionEnvelope Text Int
  | ReadOnlyScreen InteractionEnvelope Text

runRepl :: AppEnv -> IO ()
runRepl environment = do
  interactive <- (&&) <$> hIsTerminalDevice stdin <*> hIsTerminalDevice stdout
  term <- lookupEnv "TERM"
  if not interactive || term == Just "dumb"
    then runInline
    else bracket (CrossPlatform.mkVty defaultConfig) shutdown runInteractive
 where
  runInline =
    runAppCommand environment False (const (pure ())) NextCommand >>= \case
      Left problem -> Text.putStrLn (renderError problem)
      Right result -> Text.putStrLn (renderCommandResult result)
  runInteractive vty = do
    color <- terminalColorMode
    result <- runAppCommand environment False (showProgress vty color) NextCommand
    case result of
      Left problem -> paint vty color (errorModel problem) >> waitForExit vty
      Right NextResult{resultInteraction} -> loop environment vty color 80 (screenForEnvelope resultInteraction)
      Right other -> paint vty color (textModel (renderCommandResult other)) >> waitForExit vty

loop :: AppEnv -> Vty -> ColorMode -> Int -> ReplScreen -> IO ()
loop environment vty color width screen = do
  paint vty color (modelFor width screen)
  event <- nextEvent vty
  case eventToInput event of
    Nothing -> loop environment vty color width screen
    Just (Resized nextWidth _) -> loop environment vty color nextWidth screen
    Just input -> transition input >>= maybe (pure ()) (loop environment vty color width)
 where
  transition input = case screen of
    EnvelopeScreen envelope _ -> envelopeInput envelope input
    FeedEditor envelope editor message -> feedEditorInput envelope editor message input
    InteractionEditor envelope action editor message -> interactionEditorInput envelope action editor message input
    PaletteScreen envelope query selected -> paletteInput envelope query selected input
    ReadOnlyScreen envelope _ -> case input of
      Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
      Escape _ -> pure (Just (screenForEnvelope envelope))
      Backspace _ -> pure (Just (screenForEnvelope envelope))
      ArrowLeft _ -> pure (Just (screenForEnvelope envelope))
      _ -> pure (Just (screenForEnvelope envelope))

  envelopeInput envelope = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> dispatchShortcut envelope (Text.singleton character)
    Enter [] -> dispatchShortcut envelope "*"
    Escape _ -> navigate envelope True
    Backspace _ -> navigate envelope True
    ArrowLeft _ -> navigate envelope True
    ArrowRight _ -> navigate envelope False
    _ -> pure (Just screen)

  dispatchShortcut envelope shortcut =
    case dispatchGuidedShortcut envelope envelope shortcut of
      Left problem -> pure . Just $ EnvelopeScreen envelope (Just (appErrorMessage problem))
      Right (GuidedStale replacement) -> pure (Just (screenForEnvelope replacement))
      Right GuidedAccepted{guidedActionId, guidedOutcome = OpenFeedInput} ->
        pure (Just (FeedEditor envelope (EditorState "" "" Nothing) Nothing))
      Right GuidedAccepted{guidedOutcome = OpenCommandPalette} ->
        pure (Just (PaletteScreen envelope "/" 0))
      Right GuidedAccepted{guidedOutcome = InvokeNext} -> runNextFrom envelope
      Right GuidedAccepted{guidedActionId} -> invokeAction envelope guidedActionId

  invokeAction envelope action =
    runAppCommand environment False (const (pure ())) (RespondCommand (interactionResponse envelope action)) >>= \case
      Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
      Right result -> screenFromResult envelope result

  navigate envelope backward =
    let response = interactionResponse envelope (if backward then "navigation.back" else "navigation.forward")
        command = if backward then NavigateBackCommand response else NavigateForwardCommand response
     in runAppCommand environment False (const (pure ())) command >>= \case
          Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
          Right result -> screenFromResult envelope result

  feedEditorInput envelope editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ FeedEditor envelope (applyEditorCommand (InsertText (Text.singleton character)) editor) Nothing
    Enter [] -> submitFeed envelope editor
    Escape _ -> pure (Just (screenForEnvelope envelope))
    Backspace _
      | Text.null (editorText editor) -> pure (Just (screenForEnvelope envelope))
      | otherwise -> pure . Just $ FeedEditor envelope (applyEditorCommand DeleteBackward editor) Nothing
    Delete _ -> pure . Just $ FeedEditor envelope (applyEditorCommand DeleteForward editor) Nothing
    ArrowLeft _ -> pure . Just $ FeedEditor envelope (applyEditorCommand MoveEditorLeft editor) Nothing
    ArrowRight _ -> pure . Just $ FeedEditor envelope (applyEditorCommand MoveEditorRight editor) Nothing
    _ -> pure (Just screen)

  interactionEditorInput envelope action editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ InteractionEditor envelope action (applyEditorCommand (InsertText (Text.singleton character)) editor) Nothing
    Enter [] -> submitInteractionText envelope action editor
    Escape _ -> navigate envelope True
    Backspace _
      | Text.null (editorText editor) -> navigate envelope True
      | otherwise -> pure . Just $ InteractionEditor envelope action (applyEditorCommand DeleteBackward editor) Nothing
    Delete _ -> pure . Just $ InteractionEditor envelope action (applyEditorCommand DeleteForward editor) Nothing
    ArrowLeft _ -> pure . Just $ InteractionEditor envelope action (applyEditorCommand MoveEditorLeft editor) Nothing
    ArrowRight _ -> pure . Just $ InteractionEditor envelope action (applyEditorCommand MoveEditorRight editor) Nothing
    _ -> pure (Just screen)

  paletteInput envelope query selected = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Escape _ -> pure (Just (screenForEnvelope envelope))
    Backspace _
      | Text.length query <= 1 -> pure (Just (screenForEnvelope envelope))
      | otherwise -> pure . Just $ PaletteScreen envelope (Text.dropEnd 1 query) 0
    Printable character [] -> pure . Just $ PaletteScreen envelope (query <> Text.singleton character) 0
    ArrowUp _ -> pure . Just $ PaletteScreen envelope query (max 0 (selected - 1))
    ArrowDown _ -> pure . Just $ PaletteScreen envelope query (min (max 0 (length (filteredCommands envelope query) - 1)) (selected + 1))
    Enter _ -> runPaletteCommand envelope query selected
    _ -> pure (Just screen)

  submitFeed envelope editor
    | Text.null (Text.strip material) = pure . Just $ FeedEditor envelope editor (Just "Feed material cannot be empty.")
    | otherwise =
        runAppCommand environment False (const (pure ())) (FeedCommand "repl" material) >>= \case
          Left problem -> pure . Just $ FeedEditor envelope editor (Just (appErrorMessage problem))
          Right FeedResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
          Right other -> pure (Just (ReadOnlyScreen envelope (renderCommandResult other)))
   where
    material = editorText editor

  allowsEmptySubmission WorkBreakDraftOpportunity{} = True
  allowsEmptySubmission _ = False

  submitInteractionText envelope action editor
    | Text.null (Text.strip material) && not (allowsEmptySubmission (envelopeOpportunity envelope)) = pure . Just $ InteractionEditor envelope action editor (Just "This value cannot be empty.")
    | otherwise =
        runAppCommand environment False (const (pure ())) (SubmitInteractionTextCommand (interactionResponse envelope action) material) >>= \case
          Left problem -> pure . Just $ InteractionEditor envelope action editor (Just (appErrorMessage problem))
          Right result -> screenFromResult envelope result
   where
    material = editorText editor

  runNextFrom envelope =
    runAppCommand environment False (const (pure ())) NextCommand >>= \case
      Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
      Right NextResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
      Right other -> pure (Just (ReadOnlyScreen envelope (renderCommandResult other)))

  screenFromResult envelope = \case
    RespondResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    NextResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    FeedResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    other -> pure (Just (ReadOnlyScreen envelope (renderCommandResult other)))

  runPaletteCommand envelope query selected = case safeIndex selected (filteredCommands envelope query) of
    Nothing -> pure (Just (PaletteScreen envelope query selected))
    Just command -> case commandOptionId command of
      "feed" -> pure (Just (FeedEditor envelope (EditorState "" "" Nothing) Nothing))
      "exit" -> pure Nothing
      "show" -> runShowCommand envelope command
      "help" -> pure (Just (ReadOnlyScreen envelope helpText))
      "undo" -> runSimpleCommand envelope UndoCommand
      "redo" -> runSimpleCommand envelope RedoCommand
      "pause" -> runSimpleCommand envelope PauseCommand
      "break" -> runBrickCommand envelope command BreakCommand
      "archive" -> runBrickCommand envelope command ArchiveCommand
      "restore" -> runBrickCommand envelope command RestoreCommand
      "translate" -> runSimpleCommand envelope (TranslateCommand Nothing)
      "tie-break" -> runSimpleCommand envelope TieBreakCommand
      _ -> pure (Just (EnvelopeScreen envelope (Just "That command is not implemented yet.")))

  runSimpleCommand envelope command =
    runAppCommand environment False (const (pure ())) command >>= \case
      Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
      Right result -> screenFromResult envelope result

  runShowCommand envelope command =
    let reference = Text.drop 6 (commandOptionCommand command)
     in runAppCommand environment False (const (pure ())) (ShowRawCommand reference GuidedView) >>= \case
          Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
          Right result -> pure (Just (ReadOnlyScreen envelope (renderCommandResult result)))

  runBrickCommand envelope command constructor =
    case Text.words (commandOptionCommand command) of
      _ : reference : _ -> runSimpleCommand envelope (constructor reference)
      _ -> pure (Just (EnvelopeScreen envelope (Just "Choose a Brick reference for this command.")))

screenForEnvelope :: InteractionEnvelope -> ReplScreen
screenForEnvelope envelope = case envelopeOpportunity envelope of
  WorkTitleOpportunity _ _ _ title -> InteractionEditor envelope "work.title.submit" (selectedEditor title) Nothing
  TranslationEditOpportunity _ suggestion _ -> InteractionEditor envelope "translate.edit.submit" (maybe (EditorState "" "" Nothing) selectedEditor suggestion) Nothing
  SourceRelocateOpportunity _ draft -> InteractionEditor envelope "source.relocate.submit" (selectedEditor draft) Nothing
  RawShelfNameOpportunity _ name -> InteractionEditor envelope "raw-shelf.name.submit" (selectedEditor name) Nothing
  WorkOtherExplanationOpportunity _ _ draft -> InteractionEditor envelope "work.other.submit" (selectedEditor draft) Nothing
  WorkBreakDraftOpportunity _ _ _ _ _ -> InteractionEditor envelope "work.break.submit" (EditorState "" "" Nothing) Nothing
  RepeatableReturnCenterOpportunity _ _ draft -> InteractionEditor envelope "return.center.submit" (selectedEditor draft) Nothing
  RepeatableReturnVariationOpportunity _ _ _ _ draft -> InteractionEditor envelope "return.variation.submit" (selectedEditor draft) Nothing
  RepeatableReturnZoneOpportunity _ _ _ _ _ draft -> InteractionEditor envelope "return.zone.submit" (selectedEditor draft) Nothing
  _ -> EnvelopeScreen envelope Nothing

interactionResponse :: InteractionEnvelope -> Text -> InteractionResponse
interactionResponse envelope action =
  InteractionResponse
    (envelopeInteractionId envelope)
    (envelopeRevision envelope)
    action
    (envelopeIntegrityToken envelope)
    (envelopeDatasetCursor envelope)

modelFor :: Int -> ReplScreen -> ScreenModel
modelFor width = \case
  EnvelopeScreen envelope message -> prependMessage message (renderEnvelopeAtWidth width envelope)
  FeedEditor envelope editor message -> editorModel width envelope "Feed Little Ant" "Tip: prefer English for consistent titles and search." editor message
  InteractionEditor envelope _ editor message -> editorModel width envelope (contentHeading (envelopeContent envelope)) "Tip: write Brick titles in English." editor message
  PaletteScreen envelope query selected -> paletteModelAtWidth width envelope query selected
  ReadOnlyScreen envelope text ->
    ScreenModel (fmap (pure . Span Normal) (Text.lines text) <> [[], [Span Dim "Press any key to return."], []] <> footerFrom width envelope) Nothing

editorModel :: Int -> InteractionEnvelope -> Text -> Text -> EditorState -> Maybe Text -> ScreenModel
editorModel width envelope heading hint editor message =
  ScreenModel
    ( [ [Span Normal heading]
      , []
      , [Span Dim hint]
      , []
      , [Span Normal "› ", Span Normal (editorBefore editor), Span Selected (fromMaybe " " (editorSelection editor)), Span Normal (editorAfter editor)]
      ]
        <> maybe [] (\problem -> [[], [Span Warning problem]]) message
        <> [[], [Span Dim "[Enter] continue · [Esc] back"], []]
        <> footerFrom width envelope
    )
    Nothing

paletteModel :: InteractionEnvelope -> Text -> Int -> ScreenModel
paletteModel = paletteModelAtWidth 80

paletteModelAtWidth :: Int -> InteractionEnvelope -> Text -> Int -> ScreenModel
paletteModelAtWidth width envelope query selected =
  ScreenModel
    ( [[Span Normal "More:"], [], [Span Normal "› ", Span Normal query], []]
        <> zipWith renderRow [0 ..] commands
        <> [[], [Span Dim "Type to filter available commands."], [Span Dim "↑/↓ select · Enter run · Esc back"], []]
        <> footerFrom width envelope
    )
    Nothing
 where
  commands = filteredCommands envelope query
  renderRow index command =
    [ Span Normal (if index == selected then "> " else "  ")
    , Span (if index == selected then Selected else Normal) (Text.justifyLeft 12 ' ' (commandOptionCommand command) <> commandOptionDescription command)
    ]

filteredCommands :: InteractionEnvelope -> Text -> [CommandOption]
filteredCommands envelope query = filter matches (envelopeCommands envelope)
 where
  needle = Text.toLower (Text.dropWhile (== '/') query)
  matches command = Text.null needle || needle `Text.isInfixOf` Text.toLower (commandOptionCommand command <> " " <> commandOptionDescription command)

footerFrom :: Int -> InteractionEnvelope -> [ScreenLine]
footerFrom width envelope = dropWhile null . dropToDivider . screenLines $ renderEnvelopeAtWidth width envelope
 where
  dropToDivider [] = []
  dropToDivider rows@(line : rest)
    | not (Text.null (plainLine line)) && Text.all (== '─') (plainLine line) = rows
    | otherwise = dropToDivider rest

prependMessage :: Maybe Text -> ScreenModel -> ScreenModel
prependMessage Nothing model = model
prependMessage (Just message) model = model{screenLines = [Span Warning message] : [] : screenLines model}

progressModel :: Integer -> ScreenModel
progressModel count =
  textModel $
    Text.unlines
      [ "       /\\/\\"
      , "     __\\_\\  _..._"
      , "    (\"  )  (_..._)"
      , "     ^^      // \\"
      , ""
      , "        L I T T L E    A N T"
      , ""
      , "Loading " <> Text.justifyRight 6 '0' (Text.pack (show count)) <> "..."
      ]

showProgress :: Vty -> ColorMode -> Integer -> IO ()
showProgress vty color = paint vty color . progressModel

paint :: Vty -> ColorMode -> ScreenModel -> IO ()
paint vty color model = update vty (picForImage (screenImage color model))

terminalColorMode :: IO ColorMode
terminalColorMode = do
  noColor <- lookupEnv "NO_COLOR"
  pure (if isNothing noColor then ColorEnabled else Monochrome)

editorText :: EditorState -> Text
editorText editor = editorBefore editor <> fromMaybe "" (editorSelection editor) <> editorAfter editor

safeIndex :: Int -> [value] -> Maybe value
safeIndex index _ | index < 0 = Nothing
safeIndex index values = case drop index values of value : _ -> Just value; [] -> Nothing

textModel :: Text -> ScreenModel
textModel text = ScreenModel (fmap (pure . Span Normal) (Text.lines text)) Nothing

errorModel :: AppError -> ScreenModel
errorModel = textModel . renderError

waitForExit :: Vty -> IO ()
waitForExit vty = void (nextEvent vty)

helpText :: Text
helpText = "Little Ant shows one useful opportunity at a time.\n\nUse the visible keys or return with Escape."

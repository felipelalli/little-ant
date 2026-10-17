module LittleAnt.REPL (
  ImportCatalogChoice (..),
  ImportSelection (..),
  PackPathPurpose (..),
  connectedProviderImportSelection,
  filteredCommands,
  importContainerModel,
  importContainerModelAtWidth,
  importModeModel,
  importSourceChoices,
  importSourceModel,
  packManagerModel,
  packPathEditorModel,
  paletteModel,
  paletteCommandSelection,
  browserModel,
  brickCommandTargets,
  documentModel,
  ListView (..),
  listModel,
  viewportModel,
  progressModel,
  runRepl,
  runReplWithCommand,
) where

import Control.Applicative ((<|>))
import Control.Exception (bracket)
import Control.Monad (void)
import Data.ByteString qualified as ByteString
import Data.Char (ord)
import Data.Functor qualified
import Data.IORef
import Data.List (find, findIndex, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as Text
import Graphics.Vty (Modifier (MCtrl), Vty, nextEvent, picForImage, shutdown, update)
import Graphics.Vty qualified as Vty
import Graphics.Vty.Config (defaultConfig)
import Graphics.Vty.CrossPlatform qualified as CrossPlatform
import Graphics.Vty.Output (Mode (Mouse), setMode)
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Import
import LittleAnt.Interaction
import LittleAnt.Markdown
import LittleAnt.Model (Actor (actorProfile), SourceMode (..))
import LittleAnt.Profile qualified as Profile
import LittleAnt.Projection
import LittleAnt.Protocol
import LittleAnt.Provider
import LittleAnt.RecurrenceInput (recurrenceFieldIsChoice)
import LittleAnt.Result
import LittleAnt.Source (SourceContainer (..))
import LittleAnt.Surface
import LittleAnt.Terminal
import LittleAnt.Tree qualified as Tree
import LittleAnt.Vault.Agent (wipeAgentSecret)
import System.Environment (lookupEnv)
import System.IO (hIsTerminalDevice, stdin, stdout)

data ReplScreen
  = EnvelopeScreen InteractionEnvelope (Maybe Text)
  | FeedEditor InteractionEnvelope EditorState (Maybe Text)
  | InteractionEditor InteractionEnvelope Text EditorState (Maybe Text)
  | PaletteScreen InteractionEnvelope Text Int PaletteReturn
  | PackManagerScreen InteractionEnvelope [PackProjection] (Maybe AppError) Int (Maybe Text)
  | PackPathEditor InteractionEnvelope PackPathPurpose EditorState (Maybe Text)
  | ImportSourceScreen InteractionEnvelope [ImportCatalogChoice] Text Int (Maybe Text)
  | ImportPathEditor InteractionEnvelope ImportSourceDescriptor EditorState (Maybe Text)
  | ImportModeScreen InteractionEnvelope ImportSelection (Maybe Text)
  | ImportContainerScreen InteractionEnvelope ImportSelection SourceMode [SourceContainer] Int (Set.Set Text) (Maybe Text)
  | ProviderConnectionEditor InteractionEnvelope ProviderSourceDefinition ProviderConnectionInput EditorState (Maybe Text)
  | ListScreen ReplScreen ListView
  | SearchEditor ReplScreen EditorState (Maybe Text)
  | BrowserScreen ReplScreen Text [SearchHit] Text Int (Maybe Text)
  | CommandTargetScreen InteractionEnvelope CommandOption [SearchHit] Text Int (Maybe Text)
  | InspectionScreen ReplScreen SearchHit Text
  | WhyScreen ReplScreen [Text] [Text] Bool
  | ReadOnlyScreen ReplScreen Text
  | SuspendedScreen ReplScreen Int
  | CompletionNoticeScreen Text ReplScreen
  deriving stock (Eq, Show)

-- Presentation state is kept across inspection and view changes, never as a
-- semantic event or an additional forecast draw.
data ListView = ListView
  { listViewName :: Text
  , listViewScope :: [Text]
  , listViewEntries :: [ListRow]
  , listViewCategories :: [ListTree]
  , listViewGrouped :: Bool
  , listViewQuery :: Text
  , listViewSearching :: Bool
  , listViewSelected :: Int
  , listViewMessage :: Maybe Text
  , listViewHeader :: [Text]
  , listViewFlatDays :: Bool
  }
  deriving stock (Eq, Show)

data ImportCatalogChoice
  = ReadyImportSource ImportSourceDescriptor
  | ConnectImportSource ProviderSourceDefinition
  deriving stock (Eq, Show)

data ImportSelection = ImportSelection
  { importSelectionDescriptor :: ImportSourceDescriptor
  , importSelectionReference :: Text
  }
  deriving stock (Eq, Show)

data ProviderConnectionInput
  = ProviderAccountKey
  | ProviderAccountLabel Text
  | ProviderClientId Text Text
  deriving stock (Eq, Show)

data PackPathPurpose
  = InstallPackArchive
  | TrustPublisherKey
  deriving stock (Eq, Show)

data PaletteReturn
  = ReturnToEnvelope
  | ReturnToScreen ReplScreen
  | ReturnToPackManager [PackProjection] (Maybe AppError) Int
  | ReturnToImportMode ImportSelection
  | ReturnToImportContainers ImportSelection SourceMode [SourceContainer] Int (Set.Set Text)
  deriving stock (Eq, Show)

runRepl :: AppEnv -> IO ()
runRepl environment = runReplWithCommand environment NextCommand

runReplWithCommand :: AppEnv -> AppCommand -> IO ()
runReplWithCommand environment initialCommand = do
  interactive <- (&&) <$> hIsTerminalDevice stdin <*> hIsTerminalDevice stdout
  term <- lookupEnv "TERM"
  if not interactive || term == Just "dumb"
    then runInline
    else bracket (CrossPlatform.mkVty defaultConfig) shutdown runInteractive
 where
  runInline =
    runAppCommand environment False (const (pure ())) initialCommand >>= \case
      Left problem -> Text.putStrLn (renderError problem)
      Right result -> Text.putStrLn (renderCommandResult result)
  runInteractive vty = do
    color <- terminalColorMode
    Vty.setMode (Vty.outputIface vty) Vty.BracketedPaste True
    (width, height) <- Vty.displayBounds (Vty.outputIface vty)
    let interactiveEnvironment =
          environment
            { appProviderConnectionRuntime =
                (\runtime -> runtime{providerConnectionAcquireCredential = acquireCredentialWithVty vty color})
                  <$> appProviderConnectionRuntime environment
            }
    environmentRef <- newIORef interactiveEnvironment
    result <- runAppCommand interactiveEnvironment False (showProgress vty color) initialCommand
    case result of
      Left problem -> paint vty color (errorModel problem) >> waitForExit vty
      Right NextResult{resultInteraction} -> do
        screen <- presentCompletedEnvelope interactiveEnvironment resultInteraction
        loop environmentRef vty color width height 0 screen
      Right RepairResult{resultInteraction} -> loop environmentRef vty color width height 0 (screenForEnvelope resultInteraction)
      Right other -> paint vty color (textModel (renderCommandResult other)) >> waitForExit vty

loop :: IORef AppEnv -> Vty -> ColorMode -> Int -> Int -> Int -> ReplScreen -> IO ()
loop environmentRef vty color width height requestedOffset = \case
  CompletionNoticeScreen receipt screen -> loopWithNotice environmentRef vty color width height requestedOffset (Just receipt) screen
  screen -> loopWithNotice environmentRef vty color width height requestedOffset Nothing screen

loopWithNotice :: IORef AppEnv -> Vty -> ColorMode -> Int -> Int -> Int -> Maybe Text -> ReplScreen -> IO ()
loopWithNotice environmentRef vty color width height requestedOffset notice screen = do
  setMode (Vty.outputIface vty) Mouse ((scrollable || selectable) && maximumOffset > 0)
  paint vty color (viewportModel width height offset model)
  event <- nextEvent vty
  case eventToInput event of
    Nothing -> loopWithNotice environmentRef vty color width height offset notice screen
    Just (Resized nextWidth nextHeight) -> loopWithNotice environmentRef vty color nextWidth nextHeight offset notice screen
    Just (Printable 'f' modifiers)
      | MCtrl `elem` modifiers
      , not (isRepairScreen (screenEnvelope screen)) ->
          case screen of
            ListScreen previous view -> continue offset (ListScreen previous view{listViewSearching = not (listViewSearching view)})
            SearchEditor{} -> continue offset screen
            _ -> continue 0 (SearchEditor (SuspendedScreen screen offset) (EditorState "" "" Nothing) Nothing)
    Just (PageUp _) | scrollable -> continue (max 0 (offset - max 1 (height - 10))) screen
    Just (PageDown _) | scrollable -> continue (min maximumOffset (offset + max 1 (height - 10))) screen
    Just (ArrowUp _) | scrollable -> continue (max 0 (offset - 1)) screen
    Just (ArrowDown _) | scrollable -> continue (min maximumOffset (offset + 1)) screen
    Just (WheelUp _) | scrollable -> continue (max 0 (offset - 3)) screen
    Just (WheelDown _) | scrollable -> continue (min maximumOffset (offset + 3)) screen
    Just (WheelUp modifiers) | selectable -> stepScreen (ArrowUp modifiers)
    Just (WheelDown modifiers) | selectable -> stepScreen (ArrowDown modifiers)
    Just (Home _) | scrollable -> continue 0 screen
    Just (End _) | scrollable -> continue maximumOffset screen
    Just input -> stepScreen input
 where
  stepScreen input = transition input >>= maybe (pure ()) (\nextScreen -> continue (if selectionView nextScreen == selectionView screen then offset else 0) nextScreen)
  selectionView (ListScreen previous view) = ListScreen previous view{listViewSelected = 0}
  selectionView (BrowserScreen previous heading entries query _ message) = BrowserScreen previous heading entries query 0 message
  selectionView other = other
  continue _ (SuspendedScreen previous previousOffset) = loop environmentRef vty color width height previousOffset previous
  continue nextOffset nextScreen = loop environmentRef vty color width height nextOffset nextScreen
  model = prependCompletionNotice width notice (modelFor width screen)
  (contentRows, _, bodyRoom, _) = viewportRows width height model
  maximumOffset = max 0 (length contentRows - bodyRoom)
  offset = viewportStart bodyRoom requestedOffset contentRows
  scrollable = case screen of ReadOnlyScreen{} -> True; WhyScreen{} -> True; InspectionScreen{} -> True; EnvelopeScreen{} -> True; _ -> False
  selectable = case screen of ListScreen{} -> True; BrowserScreen{} -> True; CommandTargetScreen{} -> True; PaletteScreen{} -> True; PackManagerScreen{} -> True; ImportSourceScreen{} -> True; ImportContainerScreen{} -> True; _ -> False
  transition input = case screen of
    EnvelopeScreen envelope _ -> envelopeInput envelope input
    FeedEditor envelope editor message -> feedEditorInput envelope editor message input
    InteractionEditor envelope action editor message -> interactionEditorInput envelope action editor message input
    PaletteScreen envelope query selected target -> paletteInput envelope query selected target input
    PackManagerScreen envelope packs problem selected message -> packManagerInput envelope packs problem selected message input
    PackPathEditor envelope purpose editor message -> packPathInput envelope purpose editor message input
    ImportSourceScreen envelope choices query selected message -> importSourceInput envelope choices query selected message input
    ImportPathEditor envelope descriptor editor message -> importPathInput envelope descriptor editor message input
    ImportModeScreen envelope selection message -> importModeInput envelope selection message input
    ImportContainerScreen envelope selection mode containers selected chosen message -> importContainerInput envelope selection mode containers selected chosen message input
    ProviderConnectionEditor envelope definition stage editor message -> providerConnectionInput envelope definition stage editor message input
    ListScreen previous view -> listInput previous view input
    SearchEditor previous editor message -> searchEditorInput previous editor message input
    BrowserScreen previous heading entries query selected message -> browserInput previous heading entries query selected message input
    CommandTargetScreen envelope command entries query selected message -> commandTargetInput envelope command entries query selected message input
    InspectionScreen previous hit _ -> case input of
      Printable 'f' [] | searchHitKind hit == "brick" -> runSimpleCommand (screenEnvelope previous) (FocusCommand (searchHitHandle hit))
      Printable 'u' [] | searchHitKind hit == "brick" -> runSimpleCommand (screenEnvelope previous) (UpdateCommand (searchHitHandle hit) Nothing)
      _ -> readOnlyInput previous input
    WhyScreen previous summary details complete -> case input of
      Printable 'd' [] -> pure (Just (WhyScreen previous summary details (not complete)))
      Printable 'b' [] -> pure (Just previous)
      _ -> readOnlyInput previous input
    ReadOnlyScreen previous _ -> readOnlyInput previous input
    SuspendedScreen previous _ -> readOnlyInput previous input
    CompletionNoticeScreen _ previous -> readOnlyInput previous input

  readOnlyInput previous = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Escape _ -> pure (Just previous)
    Backspace _ -> pure (Just previous)
    ArrowLeft _ -> pure (Just previous)
    _ -> pure (Just screen)

  openList previous name =
    runCurrent (ListCommand (Just name)) >>= \case
      Left problem -> pure . Just $ ReadOnlyScreen previous (renderError problem)
      Right ListResult{resultListName, resultListEntries, resultListCategories, resultListHeader} ->
        pure . Just $ ListScreen previous (ListView resultListName (drop 1 (Text.words name)) resultListEntries resultListCategories False "" False 0 Nothing resultListHeader False)
      Right other -> pure . Just $ ReadOnlyScreen previous (renderCommandResult other)

  listInput previous view input = case input of
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Escape _ | listViewSearching view || not (Text.null query) -> changed view{listViewQuery = "", listViewSearching = False, listViewSelected = 0}
    Escape _ -> pure (Just previous)
    Backspace _ | listViewSearching view -> search (Text.dropEnd 1 query)
    Printable character [] | listViewSearching view -> search (query <> Text.singleton character)
    Pasted material | listViewSearching view -> search (query <> material)
    Printable 'v' [] ->
      let name = nextListView (listViewName view)
       in runCurrent (ListCommand (Just (Text.unwords (name : listViewScope view)))) >>= \case
            Left problem -> changed view{listViewMessage = Just (appErrorMessage problem)}
            Right ListResult{resultListEntries, resultListCategories, resultListHeader} -> preserve view{listViewName = name, listViewEntries = resultListEntries, listViewCategories = resultListCategories, listViewHeader = resultListHeader}
            Right _ -> pure (Just screen)
    -- The agenda's days and the other views' categories toggle independently.
    Printable 't' [] | listViewName view == "agenda" -> preserve view{listViewFlatDays = not (listViewFlatDays view)}
    Printable 't' [] -> preserve view{listViewGrouped = not (listViewGrouped view)}
    Printable '/' [] -> pure . Just $ PaletteScreen (screenEnvelope previous) "/" 0 (ReturnToScreen screen)
    Printable 'k' [] -> changed view{listViewMessage = Just "Importance is your sibling order. Forecast shows current chances. Agenda shows dated facts of the coming days, overdue first. Categories group the same items; repeated references share one chance. Ctrl+F searches this list."}
    ArrowLeft _ | not (listViewSearching view) -> pure (Just previous)
    Backspace _ -> pure (Just previous)
    ArrowUp _ -> select (selected - 1)
    ArrowDown _ -> select (selected + 1)
    PageUp _ -> select (selected - max 1 ((height - 10) `div` 3))
    PageDown _ -> select (selected + max 1 ((height - 10) `div` 3))
    Home _ -> select 0
    End _ -> select lastIndex
    Enter _ -> case safeIndex selected visible of
      Nothing -> pure (Just screen)
      Just hit ->
        runCurrent (ShowRawCommand (searchHitHandle hit) CompleteView) >>= \case
          Left problem -> changed view{listViewMessage = Just (appErrorMessage problem)}
          Right result -> pure . Just $ InspectionScreen (SuspendedScreen screen offset) hit (renderCommandResult result)
    _ -> pure (Just screen)
   where
    query = listViewQuery view
    selected = listViewSelected view
    visible = listViewHits view
    lastIndex = max 0 (length visible - 1)
    changed next = pure . Just $ ListScreen previous next
    select index = changed view{listViewSelected = max 0 (min lastIndex index), listViewMessage = Nothing}
    search text = changed view{listViewQuery = text, listViewSelected = 0, listViewMessage = Nothing}
    preserve next =
      let currentHandle = searchHitHandle <$> safeIndex selected visible
          index = fromMaybe 0 (currentHandle >>= \identity -> findIndex ((== identity) . searchHitHandle) (listViewHits next))
       in changed next{listViewSelected = index, listViewMessage = Nothing}

  searchEditorInput previous editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> changed (InsertText (Text.singleton character))
    Pasted material -> changed (InsertText material)
    Backspace _ | Text.null (editorText editor) -> pure (Just previous)
    Backspace _ -> changed DeleteBackward
    Delete _ -> changed DeleteForward
    ArrowLeft _ -> changed MoveEditorLeft
    ArrowRight _ -> changed MoveEditorRight
    Escape _ -> pure (Just previous)
    Enter _ -> runSearchFrom previous (editorText editor)
    _ -> pure (Just screen)
   where
    changed command = pure . Just $ SearchEditor previous (applyEditorCommand command editor) Nothing

  runSearchFrom previous query =
    runCurrent (SearchCommand query) >>= \case
      Left problem -> pure . Just $ SearchEditor previous (EditorState query "" Nothing) (Just (appErrorMessage problem))
      Right SearchResult{resultSearchHits} -> pure . Just $ BrowserScreen previous ("Search: " <> Text.strip query) resultSearchHits "" 0 Nothing
      Right other -> pure . Just $ ReadOnlyScreen previous (renderCommandResult other)

  browserInput previous heading entries query selected _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Escape _ -> pure (Just previous)
    ArrowLeft _ -> pure (Just previous)
    Backspace _ | Text.null query -> pure (Just previous)
    Backspace _ -> changed (Text.dropEnd 1 query) 0
    Printable character [] -> changed (query <> Text.singleton character) 0
    Pasted material -> changed (query <> material) 0
    ArrowUp _ -> changed query (max 0 (selected - 1))
    ArrowDown _ -> changed query (min lastIndex (selected + 1))
    PageUp _ -> changed query (max 0 (selected - max 1 ((height - 10) `div` 3)))
    PageDown _ -> changed query (min lastIndex (selected + max 1 ((height - 10) `div` 3)))
    Home _ -> changed query 0
    End _ -> changed query lastIndex
    Enter _ -> case safeIndex selected visible of
      Nothing -> pure (Just screen)
      Just hit ->
        runCurrent (ShowRawCommand (searchHitHandle hit) CompleteView) >>= \case
          Left problem -> pure . Just $ BrowserScreen previous heading entries query selected (Just (appErrorMessage problem))
          Right result -> pure . Just $ InspectionScreen (SuspendedScreen screen offset) hit (renderCommandResult result)
    _ -> pure (Just screen)
   where
    visible = browserHits heading query entries
    lastIndex = max 0 (length visible - 1)
    changed nextQuery nextSelected = pure . Just $ BrowserScreen previous heading entries nextQuery nextSelected Nothing

  commandTargetInput envelope command entries query selected message input = case input of
    Enter _ -> case safeIndex selected (filteredHits query entries) of
      Nothing -> pure (Just screen)
      Just hit -> runPaletteCommand envelope ("/" <> commandOptionId command <> " " <> searchHitHandle hit) 0 ReturnToEnvelope
    _ ->
      browserInput (screenForEnvelope envelope) ("Choose Work for /" <> commandOptionId command) entries query selected message input
        Data.Functor.<&> fmap (\case BrowserScreen _ _ nextEntries nextQuery nextSelected nextMessage -> CommandTargetScreen envelope command nextEntries nextQuery nextSelected nextMessage; other -> other)

  envelopeInput envelope = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable 'q' [] | all ((/= "q") . actionShortcut) (envelopeActions envelope) -> pure Nothing
    Printable character [] -> dispatchShortcut envelope (Text.singleton character)
    Enter [] -> dispatchShortcut envelope "*"
    Escape _ | isRepairScreen envelope -> pure Nothing
    Escape _ | ProviderConnectionOpportunity{} <- envelopeOpportunity envelope -> invokeAction envelope "provider.connect.back"
    Escape _ -> navigateOrExit envelope
    Backspace _ | isRepairScreen envelope -> pure Nothing
    Backspace _ | ProviderConnectionOpportunity{} <- envelopeOpportunity envelope -> invokeAction envelope "provider.connect.back"
    Backspace _ -> navigate envelope True
    ArrowLeft _ | isRepairScreen envelope -> pure Nothing
    ArrowLeft _ | ProviderConnectionOpportunity{} <- envelopeOpportunity envelope -> invokeAction envelope "provider.connect.back"
    ArrowLeft _ -> navigate envelope True
    ArrowRight _ -> navigate envelope False
    _ -> pure (Just screen)

  dispatchShortcut envelope shortcut =
    case dispatchGuidedShortcut envelope envelope shortcut of
      Left problem -> pure . Just $ EnvelopeScreen envelope (Just (appErrorMessage problem))
      Right (GuidedStale replacement) -> pure (Just (screenForEnvelope replacement))
      Right GuidedAccepted{guidedOutcome = OpenFeedInput} ->
        pure (Just (FeedEditor envelope (EditorState "" "" Nothing) Nothing))
      Right GuidedAccepted{guidedOutcome = OpenCommandPalette} ->
        pure (Just (PaletteScreen envelope "/" 0 ReturnToEnvelope))
      -- The next response advances a checkpoint; startup NextCommand restores it.
      Right GuidedAccepted{guidedActionId} -> invokeAction envelope guidedActionId

  invokeAction envelope action =
    runCurrent (RespondCommand (interactionResponse envelope action)) >>= \case
      Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
      Right RespondResult{resultInteraction}
        | action == "provider.connect.back" -> openImportSourceSelector resultInteraction Nothing
      Right result -> screenFromResult envelope result

  navigate envelope backward =
    let response = interactionResponse envelope (if backward then "navigation.back" else "navigation.forward")
        command = if backward then NavigateBackCommand response else NavigateForwardCommand response
     in runCurrent command >>= \case
          Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
          Right result -> screenFromResult envelope result

  navigateOrExit envelope =
    runCurrent (NavigateBackCommand (interactionResponse envelope "navigation.back")) >>= \case
      Left _ | isMainOpportunity (envelopeOpportunity envelope) -> pure Nothing
      Left problem -> pure . Just $ EnvelopeScreen envelope (Just (appErrorMessage problem))
      Right RespondResult{resultInteraction}
        | resultInteraction == envelope, isMainOpportunity (envelopeOpportunity envelope) -> pure Nothing
      Right result -> screenFromResult envelope result

  feedEditorInput envelope editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ FeedEditor envelope (applyEditorCommand (InsertText (Text.singleton character)) editor) Nothing
    Pasted material -> pure . Just $ FeedEditor envelope (applyEditorCommand (InsertText material) editor) Nothing
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
    Pasted material -> pure . Just $ InteractionEditor envelope action (applyEditorCommand (InsertText material) editor) Nothing
    Enter [] -> submitInteractionText envelope action editor
    Escape _ -> navigate envelope True
    Backspace _
      | Text.null (editorText editor) -> navigate envelope True
      | otherwise -> pure . Just $ InteractionEditor envelope action (applyEditorCommand DeleteBackward editor) Nothing
    Delete _ -> pure . Just $ InteractionEditor envelope action (applyEditorCommand DeleteForward editor) Nothing
    ArrowLeft _ -> pure . Just $ InteractionEditor envelope action (applyEditorCommand MoveEditorLeft editor) Nothing
    ArrowRight _ -> pure . Just $ InteractionEditor envelope action (applyEditorCommand MoveEditorRight editor) Nothing
    _ -> pure (Just screen)

  paletteInput envelope query selected target = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Escape _ -> pure (Just (paletteReturnScreen envelope target))
    Backspace _
      | Text.length query <= 1 -> pure (Just (paletteReturnScreen envelope target))
      | otherwise -> pure . Just $ PaletteScreen envelope (Text.dropEnd 1 query) 0 target
    Printable character [] -> pure . Just $ PaletteScreen envelope (query <> Text.singleton character) 0 target
    Pasted material -> pure . Just $ PaletteScreen envelope (query <> material) 0 target
    ArrowUp _ -> pure . Just $ PaletteScreen envelope query (max 0 (selected - 1)) target
    ArrowDown _ -> pure . Just $ PaletteScreen envelope query (min (max 0 (length (filteredCommands envelope query) - 1)) (selected + 1)) target
    Home _ -> pure . Just $ PaletteScreen envelope query 0 target
    End _ -> pure . Just $ PaletteScreen envelope query (max 0 (length (filteredCommands envelope query) - 1)) target
    PageUp _ -> pure . Just $ PaletteScreen envelope query (max 0 (selected - 10)) target
    PageDown _ -> pure . Just $ PaletteScreen envelope query (min (max 0 (length (filteredCommands envelope query) - 1)) (selected + 10)) target
    Enter _ -> runPaletteCommand envelope query selected target
    _ -> pure (Just screen)

  submitFeed envelope editor
    | Text.null (Text.strip material) = pure . Just $ FeedEditor envelope editor (Just "Feed material cannot be empty.")
    | otherwise =
        runCurrent (FeedCommand "repl" material) >>= \case
          Left problem -> pure . Just $ FeedEditor envelope editor (Just (appErrorMessage problem))
          Right FeedResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
          Right other -> pure (Just (ReadOnlyScreen (screenForEnvelope envelope) (renderCommandResult other)))
   where
    material = editorText editor

  allowsEmptySubmission WorkBreakDraftOpportunity{} = True
  allowsEmptySubmission _ = False

  submitInteractionText envelope action editor
    | Text.null (Text.strip material) && not (allowsEmptySubmission (envelopeOpportunity envelope)) = pure . Just $ InteractionEditor envelope action editor (Just "This value cannot be empty.")
    | otherwise =
        runCurrent (SubmitInteractionTextCommand (interactionResponse envelope action) material) >>= \case
          Left problem -> pure . Just $ InteractionEditor envelope action editor (Just (appErrorMessage problem))
          Right result -> screenFromResult envelope result
   where
    material = editorText editor

  screenFromResult envelope = \case
    RespondResult{resultInteraction} -> refreshAndShow resultInteraction
    NextResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    FeedResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    RepairResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    UndoResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    other -> pure (Just (ReadOnlyScreen (screenForEnvelope envelope) (renderCommandResult other)))

  refreshAndShow envelope = case envelopeOpportunity envelope of
    CompletionResultOpportunity{} -> do
      current <- readIORef environmentRef
      Just <$> presentCompletedEnvelope current envelope
    ProviderConnectionResultOpportunity source accountName _ ->
      reloadCurrentEnvironment >>= \case
        Left problem -> pure . Just $ EnvelopeScreen envelope (Just ("The provider connected, but this REPL could not reload its import catalog: " <> appErrorMessage problem))
        Right () -> openConnectedProviderMode envelope source accountName
    opportunity
      | refreshesPackRegistry opportunity ->
          readIORef environmentRef >>= \current ->
            productionAppEnv (Just (actorProfile (appActor current))) >>= \case
              Left problem ->
                pure . Just $
                  EnvelopeScreen
                    envelope
                    (Just ("Pack state changed, but this REPL could not reload its component registry: " <> appErrorMessage problem))
              Right refreshed -> writeIORef environmentRef (withInteractiveCredentialInput refreshed) >> pure (Just (screenForEnvelope envelope))
      | otherwise -> pure (Just (screenForEnvelope envelope))

  runPaletteCommand envelope query selected target = case paletteCommandSelection envelope query selected of
    Nothing -> pure (Just (PaletteScreen envelope query selected target))
    Just command -> case commandOptionId command of
      "feed" -> pure (Just (FeedEditor envelope (EditorState "" "" Nothing) Nothing))
      "exit" -> pure Nothing
      "why" ->
        runCurrent (WhyCommand SummaryView) >>= \case
          Left problem -> pure (Just (ReadOnlyScreen previous (appErrorMessage problem)))
          Right WhyResult{resultWhySummary, resultWhyDetails} -> pure (Just (WhyScreen previous resultWhySummary resultWhyDetails False))
          Right result -> pure (Just (ReadOnlyScreen previous (renderCommandResult result)))
      "show" -> runShowCommand envelope command
      "list" -> case Text.words (commandOptionCommand command) of
        _ : names@(_ : _) -> openList previous (Text.unwords names)
        _ -> openList previous "importance"
      "search" -> case Text.words (commandOptionCommand command) of
        _ : terms@(_ : _) -> runSearchFrom previous (Text.unwords terms)
        _ -> pure . Just $ SearchEditor previous (EditorState "" "" Nothing) Nothing
      "help" -> pure (Just (paletteReadOnlyScreen envelope target helpText))
      "undo" -> runSimpleCommand envelope UndoCommand
      "redo" -> runSimpleCommand envelope RedoCommand
      "pause" -> runSimpleCommand envelope PauseCommand
      "history" -> runSimpleCommand envelope (HistoryCommand Nothing)
      "doctor" -> runSimpleCommand envelope DoctorCommand
      "config" -> runSimpleCommand envelope ConfigShowCommand
      "notices" -> runSimpleCommand envelope NoticesCommand
      "order" -> runSimpleCommand envelope (OrderCommand (commandReference command))
      "done" -> runBrickCommand envelope command (DoneCommand . Just)
      "focus" -> runBrickCommand envelope command FocusCommand
      "finish" -> runBrickCommand envelope command FinishCommand
      "return" -> runBrickCommand envelope command (ReturnToIdleCommand . Just)
      "impact" -> runBrickCommand envelope command ImpactCommand
      "effort" -> runBrickCommand envelope command EffortCommand
      "phase" -> runBrickCommand envelope command PhaseCommand
      "packs" -> openPackManager envelope
      "import" -> openImportSourceSelector envelope Nothing
      "break" -> runBrickCommand envelope command BreakCommand
      "archive" -> runBrickCommand envelope command ArchiveCommand
      "restore" -> runBrickCommand envelope command RestoreCommand
      "update" -> runBrickCommand envelope command (`UpdateCommand` Nothing)
      "translate" -> runSimpleCommand envelope (TranslateCommand Nothing)
      "tie-break" -> runSimpleCommand envelope TieBreakCommand
      _ -> pure (Just (EnvelopeScreen envelope (Just "That command is not implemented yet.")))
   where
    previous = paletteReturnScreen envelope target
    commandReference command = case Text.words (commandOptionCommand command) of _ : terms@(_ : _) -> Just (Text.unwords terms); _ -> Nothing

  openImportSourceSelector envelope message = do
    current <- readIORef environmentRef
    let choices = importSourceChoices current
        emptyMessage =
          if null choices
            then Just "No import source is available. Install or repair a SourceAdapter through /packs."
            else message
    pure (Just (ImportSourceScreen envelope choices "" 0 emptyMessage))

  openConnectedProviderMode envelope source accountName = do
    current <- readIORef environmentRef
    pure . Just $ case connectedProviderImportSelection current source accountName of
      Just selection ->
        ImportModeScreen
          envelope
          selection
          (Just "Provider connected. No source data was imported.")
      Nothing -> EnvelopeScreen envelope (Just "The provider connected, but its exact import account is not available. Inspect /config and /packs.")

  importSourceInput envelope choices query selected _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ ImportSourceScreen envelope choices (query <> Text.singleton character) 0 Nothing
    Backspace _
      | Text.null query -> pure (Just (screenForEnvelope envelope))
      | otherwise -> pure . Just $ ImportSourceScreen envelope choices (Text.dropEnd 1 query) 0 Nothing
    Escape _ -> pure (Just (screenForEnvelope envelope))
    ArrowLeft _ -> pure (Just (screenForEnvelope envelope))
    ArrowUp _ -> pure . Just $ ImportSourceScreen envelope choices query (max 0 (selected - 1)) Nothing
    ArrowDown _ ->
      pure . Just $
        ImportSourceScreen
          envelope
          choices
          query
          (min (max 0 (length (filteredImportSources choices query) - 1)) (selected + 1))
          Nothing
    Enter _ -> case safeIndex selected (filteredImportSources choices query) of
      Nothing -> pure (Just (ImportSourceScreen envelope choices query selected (Just "No import source matches this filter.")))
      Just choice -> chooseImportSource envelope choice
    _ -> pure (Just screen)

  chooseImportSource envelope = \case
    ReadyImportSource descriptor
      | null (importSourceExtensions descriptor) ->
          pure . Just $ ImportModeScreen envelope (ImportSelection descriptor (importSourceId descriptor)) Nothing
      | otherwise ->
          pure . Just $ ImportPathEditor envelope descriptor (EditorState "" "" Nothing) Nothing
    ConnectImportSource definition ->
      pure . Just $ ProviderConnectionEditor envelope definition ProviderAccountKey (EditorState "" "" Nothing) Nothing

  importPathInput envelope descriptor editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ ImportPathEditor envelope descriptor (applyEditorCommand (InsertText (Text.singleton character)) editor) Nothing
    Pasted material -> pure . Just $ ImportPathEditor envelope descriptor (applyEditorCommand (InsertText material) editor) Nothing
    Enter [] ->
      let reference = Text.strip (editorText editor)
       in if Text.null reference
            then pure . Just $ ImportPathEditor envelope descriptor editor (Just "Choose one local source file.")
            else pure . Just $ ImportModeScreen envelope (ImportSelection descriptor reference) Nothing
    Escape _ -> openImportSourceSelector envelope Nothing
    Backspace _
      | Text.null (editorText editor) -> openImportSourceSelector envelope Nothing
      | otherwise -> pure . Just $ ImportPathEditor envelope descriptor (applyEditorCommand DeleteBackward editor) Nothing
    Delete _ -> pure . Just $ ImportPathEditor envelope descriptor (applyEditorCommand DeleteForward editor) Nothing
    ArrowLeft _
      | Text.null (editorText editor) -> openImportSourceSelector envelope Nothing
      | otherwise -> pure . Just $ ImportPathEditor envelope descriptor (applyEditorCommand MoveEditorLeft editor) Nothing
    ArrowRight _ -> pure . Just $ ImportPathEditor envelope descriptor (applyEditorCommand MoveEditorRight editor) Nothing
    _ -> pure (Just screen)

  importModeInput envelope selection _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable 's' [] -> chooseImportMode envelope selection SourceSnapshot
    Printable 'y' [] -> chooseImportMode envelope selection SourceSynchronize
    Printable 'm' [] -> chooseImportMode envelope selection SourceMigrate
    Printable 'k' [] -> pure . Just $ ImportModeScreen envelope selection (Just "Snapshot copies what exists now. Keep synchronizing observes later changes. Migrate prepares a verified move away from the source; cleanup is always a later separate decision.")
    Printable '/' [] -> pure . Just $ PaletteScreen envelope "/" 0 (ReturnToImportMode selection)
    Enter _ -> pure . Just $ ImportModeScreen envelope selection (Just "Choose one explicit mode; this screen has no default.")
    Escape _ -> openImportSourceSelector envelope Nothing
    Backspace _ -> openImportSourceSelector envelope Nothing
    ArrowLeft _ -> openImportSourceSelector envelope Nothing
    _ -> pure (Just screen)

  chooseImportMode envelope selection mode
    | mode `notElem` importSourceModes (importSelectionDescriptor selection) =
        pure . Just $ ImportModeScreen envelope selection (Just "That mode is not declared by this SourceAdapter.")
    | otherwise =
        runCurrent (ImportCommand (importSelectionReference selection) mode [] False) >>= \case
          Left problem
            | importSourceRequiresContainerSelection (importSelectionDescriptor selection)
            , any ((== "select-containers") . recoveryActionId) (appErrorRecovery problem) ->
                openImportContainerSelector envelope selection mode
            | otherwise -> pure . Just $ ImportModeScreen envelope selection (Just (appErrorMessage problem))
          Right result -> screenFromResult envelope result

  openImportContainerSelector envelope selection mode = do
    current <- readIORef environmentRef
    importPortDiscoverContainers (appImportPort current) (importSelectionReference selection) >>= \case
      Left problem -> pure . Just $ ImportModeScreen envelope selection (Just (appErrorMessage problem))
      Right Nothing -> pure . Just $ ImportModeScreen envelope selection (Just "This SourceAdapter does not expose selectable remote containers.")
      Right (Just []) -> pure . Just $ ImportModeScreen envelope selection (Just "No selectable remote container is available.")
      Right (Just containers) ->
        pure . Just $ ImportContainerScreen envelope selection mode (sortOn sourceContainerExternalId containers) 0 Set.empty Nothing

  importContainerInput envelope selection mode containers selected chosen _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable ' ' [] ->
      case safeIndex selected containers of
        Nothing -> pure . Just $ ImportContainerScreen envelope selection mode containers selected chosen (Just "No container is selected by the cursor.")
        Just container ->
          let identity = sourceContainerExternalId container
              changed = if identity `Set.member` chosen then Set.delete identity chosen else Set.insert identity chosen
           in pure . Just $ ImportContainerScreen envelope selection mode containers selected changed Nothing
    Printable 'i' []
      | Set.null chosen -> pure . Just $ ImportContainerScreen envelope selection mode containers selected chosen (Just "Select at least one container before importing.")
      | otherwise ->
          runCurrent (ImportCommand (importSelectionReference selection) mode (Set.toAscList chosen) False) >>= \case
            Left problem -> pure . Just $ ImportContainerScreen envelope selection mode containers selected chosen (Just (appErrorMessage problem))
            Right result -> screenFromResult envelope result
    Printable 'k' [] ->
      pure . Just $
        ImportContainerScreen
          envelope
          selection
          mode
          containers
          selected
          chosen
          (Just "Only checked containers are observed. Space toggles the highlighted row; importing records this exact allowlist and grants no authority over another container.")
    Printable '/' [] -> pure . Just $ PaletteScreen envelope "/" 0 (ReturnToImportContainers selection mode containers selected chosen)
    ArrowUp _ -> pure . Just $ ImportContainerScreen envelope selection mode containers (max 0 (selected - 1)) chosen Nothing
    ArrowDown _ ->
      pure . Just $
        ImportContainerScreen envelope selection mode containers (min (max 0 (length containers - 1)) (selected + 1)) chosen Nothing
    Enter _ -> pure . Just $ ImportContainerScreen envelope selection mode containers selected chosen (Just "Use Space to check containers, then [i] import selected.")
    Escape _ -> pure (Just (ImportModeScreen envelope selection Nothing))
    Backspace _ -> pure (Just (ImportModeScreen envelope selection Nothing))
    ArrowLeft _ -> pure (Just (ImportModeScreen envelope selection Nothing))
    _ -> pure (Just screen)

  providerConnectionInput envelope definition stage editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ ProviderConnectionEditor envelope definition stage (applyEditorCommand (InsertText (Text.singleton character)) editor) Nothing
    Pasted material -> pure . Just $ ProviderConnectionEditor envelope definition stage (applyEditorCommand (InsertText material) editor) Nothing
    Enter [] -> submitProviderConnectionField envelope definition stage editor
    Escape _ -> backFromProviderConnectionField envelope definition stage
    Backspace _
      | Text.null (editorText editor) -> backFromProviderConnectionField envelope definition stage
      | otherwise -> pure . Just $ ProviderConnectionEditor envelope definition stage (applyEditorCommand DeleteBackward editor) Nothing
    Delete _ -> pure . Just $ ProviderConnectionEditor envelope definition stage (applyEditorCommand DeleteForward editor) Nothing
    ArrowLeft _
      | Text.null (editorText editor) -> backFromProviderConnectionField envelope definition stage
      | otherwise -> pure . Just $ ProviderConnectionEditor envelope definition stage (applyEditorCommand MoveEditorLeft editor) Nothing
    ArrowRight _ -> pure . Just $ ProviderConnectionEditor envelope definition stage (applyEditorCommand MoveEditorRight editor) Nothing
    _ -> pure (Just screen)

  submitProviderConnectionField envelope definition stage editor = case stage of
    ProviderAccountKey ->
      let account = Text.strip (editorText editor)
       in if Profile.validIntegrationName account
            then pure . Just $ ProviderConnectionEditor envelope definition (ProviderAccountLabel account) (EditorState "" "" Nothing) Nothing
            else pure . Just $ ProviderConnectionEditor envelope definition stage editor (Just "Use a lowercase local key with letters, digits, hyphens, or underscores.")
    ProviderAccountLabel account ->
      let entered = Text.strip (editorText editor)
          label = if Text.null entered then account else entered
       in if providerDefinitionRequiresClientId definition
            then pure . Just $ ProviderConnectionEditor envelope definition (ProviderClientId account label) (EditorState "" "" Nothing) Nothing
            else beginProviderConnection envelope definition account label Nothing
    ProviderClientId account label ->
      let clientId = Text.strip (editorText editor)
       in if Text.null clientId
            then pure . Just $ ProviderConnectionEditor envelope definition stage editor (Just "The public OAuth client ID is required by this signed connector.")
            else
              beginProviderConnection envelope definition account label (Just clientId)

  beginProviderConnection envelope definition account label clientId =
    runCurrent (ConfigConnectCommand (providerDefinitionAdapterId definition) account label clientId) >>= \case
      Left problem -> pure . Just $ ProviderConnectionEditor envelope definition (fallbackStage account label) (EditorState "" "" Nothing) (Just (appErrorMessage problem))
      Right result -> screenFromResult envelope result
   where
    fallbackStage account' label'
      | providerDefinitionRequiresClientId definition = ProviderClientId account' label'
      | otherwise = ProviderAccountLabel account'

  backFromProviderConnectionField envelope definition = \case
    ProviderAccountKey -> openImportSourceSelector envelope Nothing
    ProviderAccountLabel account -> pure . Just $ ProviderConnectionEditor envelope definition ProviderAccountKey (selectedEditor account) Nothing
    ProviderClientId account label -> pure . Just $ ProviderConnectionEditor envelope definition (ProviderAccountLabel account) (selectedEditor label) Nothing

  openPackManager envelope =
    runCurrent PacksListCommand >>= \case
      Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
      Right PacksResult{resultPacks, resultPacksProblem} ->
        pure (Just (PackManagerScreen envelope resultPacks resultPacksProblem 0 Nothing))
      Right other -> pure (Just (ReadOnlyScreen (screenForEnvelope envelope) (renderCommandResult other)))

  packManagerInput envelope packs problem selected _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable 's' [] -> showSelectedPack envelope packs problem selected
    Printable 'u' [] -> updateSelectedPack envelope packs problem selected
    Printable 'm' [] -> removeSelectedPack envelope packs problem selected
    Printable 'g' [] -> collectPackGarbage envelope packs problem selected
    Printable 'i' [] -> pure (Just (PackPathEditor envelope InstallPackArchive (EditorState "" "" Nothing) Nothing))
    Printable 'r' [] -> refreshPackCatalog envelope packs problem selected
    Printable 't' [] -> pure (Just (PackPathEditor envelope TrustPublisherKey (EditorState "" "" Nothing) Nothing))
    Printable '/' [] -> pure (Just (PaletteScreen envelope "/" 0 (ReturnToPackManager packs problem selected)))
    Enter [] -> showSelectedPack envelope packs problem selected
    Escape _ -> pure (Just (screenForEnvelope envelope))
    Backspace _ -> pure (Just (screenForEnvelope envelope))
    ArrowLeft _ -> pure (Just (screenForEnvelope envelope))
    ArrowUp _ -> pure . Just $ PackManagerScreen envelope packs problem (max 0 (selected - 1)) Nothing
    ArrowDown _ -> pure . Just $ PackManagerScreen envelope packs problem (min (max 0 (length packs - 1)) (selected + 1)) Nothing
    _ -> pure (Just screen)

  refreshPackCatalog envelope packs registryProblem selected =
    runCurrent PacksRefreshCommand >>= \case
      Left failure -> pure (Just (PackManagerScreen envelope packs registryProblem selected (Just (appErrorMessage failure))))
      Right result ->
        reloadCurrentEnvironment >>= \case
          Left failure -> pure (Just (PackManagerScreen envelope packs (Just failure) selected (Just "The catalog was accepted, but the Pack registry could not be reloaded.")))
          Right () ->
            runCurrent PacksListCommand >>= \case
              Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
              Right PacksResult{resultPacks, resultPacksProblem} ->
                pure (Just (PackManagerScreen envelope resultPacks resultPacksProblem 0 (Just (catalogRefreshMessage result))))
              Right other -> pure (Just (ReadOnlyScreen (screenForEnvelope envelope) (renderCommandResult other)))

  showSelectedPack envelope packs problem selected = case safeIndex selected packs of
    Nothing -> pure (Just (PackManagerScreen envelope packs problem selected (Just "No Pack is selected.")))
    Just pack ->
      runCurrent (PacksShowCommand (projectedPackName pack)) >>= \case
        Left failure -> pure (Just (PackManagerScreen envelope packs problem selected (Just (appErrorMessage failure))))
        Right result -> pure (Just (ReadOnlyScreen (PackManagerScreen envelope packs problem selected Nothing) (renderCommandResult result)))

  updateSelectedPack envelope packs problem selected = case safeIndex selected packs of
    Nothing -> pure (Just (PackManagerScreen envelope packs problem selected (Just "No Pack is selected.")))
    Just pack
      | projectedPackTrustClass pack == "built in" ->
          pure (Just (PackManagerScreen envelope packs problem selected (Just "The bundled Pack is updated only with Little Ant itself.")))
      | otherwise ->
          runCurrent (PacksUpdateCommand (projectedPackName pack)) >>= \case
            Left failure -> pure (Just (PackManagerScreen envelope packs problem selected (Just (appErrorMessage failure))))
            Right result -> screenFromResult envelope result

  removeSelectedPack envelope packs problem selected = case safeIndex selected packs of
    Nothing -> pure (Just (PackManagerScreen envelope packs problem selected (Just "No Pack is selected.")))
    Just pack
      | projectedPackTrustClass pack == "built in" ->
          pure (Just (PackManagerScreen envelope packs problem selected (Just "The bundled Pack is part of Little Ant itself and has no profile pin to remove.")))
      | otherwise ->
          runCurrent (PacksRemoveCommand (projectedPackName pack)) >>= \case
            Left failure -> pure (Just (PackManagerScreen envelope packs problem selected (Just (appErrorMessage failure))))
            Right result -> screenFromResult envelope result

  collectPackGarbage envelope packs problem selected =
    runCurrent PacksGcCommand >>= \case
      Left failure -> pure (Just (PackManagerScreen envelope packs problem selected (Just (appErrorMessage failure))))
      Right result -> screenFromResult envelope result

  packPathInput envelope purpose editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ PackPathEditor envelope purpose (applyEditorCommand (InsertText (Text.singleton character)) editor) Nothing
    Pasted material -> pure . Just $ PackPathEditor envelope purpose (applyEditorCommand (InsertText material) editor) Nothing
    Enter [] -> submitPackPath envelope purpose editor
    Escape _ -> openPackManager envelope
    Backspace _
      | Text.null (editorText editor) -> openPackManager envelope
      | otherwise -> pure . Just $ PackPathEditor envelope purpose (applyEditorCommand DeleteBackward editor) Nothing
    Delete _ -> pure . Just $ PackPathEditor envelope purpose (applyEditorCommand DeleteForward editor) Nothing
    ArrowLeft _ -> pure . Just $ PackPathEditor envelope purpose (applyEditorCommand MoveEditorLeft editor) Nothing
    ArrowRight _ -> pure . Just $ PackPathEditor envelope purpose (applyEditorCommand MoveEditorRight editor) Nothing
    _ -> pure (Just screen)

  submitPackPath envelope purpose editor
    | Text.null path = pure . Just $ PackPathEditor envelope purpose editor (Just requiredInput)
    | otherwise =
        runCurrent command >>= \case
          Left problem -> pure . Just $ PackPathEditor envelope purpose editor (Just (appErrorMessage problem))
          Right result -> screenFromResult envelope result
   where
    path = Text.strip (editorText editor)
    command = case purpose of
      InstallPackArchive -> PacksInstallCommand path
      TrustPublisherKey -> PacksTrustCommand path
    requiredInput = case purpose of
      InstallPackArchive -> "An official Pack name or local archive path is required."
      TrustPublisherKey -> "A local publisher-key path is required."

  runSimpleCommand envelope command =
    runCurrent command >>= \case
      Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
      Right result -> screenFromResult envelope result

  runShowCommand envelope command =
    let reference = Text.drop 6 (commandOptionCommand command)
        completeView =
          runCurrent (ShowRawCommand reference CompleteView) >>= \case
            Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
            Right result -> pure (Just (ReadOnlyScreen (screenForEnvelope envelope) (renderCommandResult result)))
     in -- A recurring-obligation occurrence opens its guided inspection (UX-RO02).
        if "#" `Text.isPrefixOf` reference
          then
            runCurrent (ShowRawCommand reference GuidedView) >>= \case
              Right result@NextResult{resultInteraction}
                | ObligationOccurrenceOpportunity{} <- envelopeOpportunity resultInteraction -> screenFromResult envelope result
              _ -> completeView
          else completeView

  runBrickCommand envelope command constructor =
    case Text.words (commandOptionCommand command) of
      _ : references@(_ : _) -> runSimpleCommand envelope (constructor (Text.unwords references))
      _ ->
        runCurrent (SearchCommand "#") >>= \case
          Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
          Right SearchResult{resultSearchHits} ->
            let (targets, selected) = brickCommandTargets envelope (commandOptionId command) resultSearchHits
             in pure (Just (CommandTargetScreen envelope command targets "" selected Nothing))
          Right other -> pure (Just (ReadOnlyScreen (screenForEnvelope envelope) (renderCommandResult other)))

  runCurrent command =
    readIORef environmentRef >>= \current -> runAppCommand current False (const (pure ())) command

  reloadCurrentEnvironment =
    readIORef environmentRef >>= \current ->
      productionAppEnv (Just (actorProfile (appActor current))) >>= \case
        Left problem -> pure (Left problem)
        Right refreshed -> writeIORef environmentRef (withInteractiveCredentialInput refreshed) >> pure (Right ())

  withInteractiveCredentialInput refreshed =
    refreshed
      { appProviderConnectionRuntime =
          (\runtime -> runtime{providerConnectionAcquireCredential = acquireCredentialWithVty vty color})
            <$> appProviderConnectionRuntime refreshed
      }

isRepairScreen :: InteractionEnvelope -> Bool
isRepairScreen envelope = case envelopeOpportunity envelope of
  RepairPreviewOpportunity{} -> True
  RepairCandidateOpportunity{} -> True
  _ -> False

screenEnvelope :: ReplScreen -> InteractionEnvelope
screenEnvelope = \case
  EnvelopeScreen envelope _ -> envelope
  FeedEditor envelope _ _ -> envelope
  InteractionEditor envelope _ _ _ -> envelope
  PaletteScreen envelope _ _ _ -> envelope
  PackManagerScreen envelope _ _ _ _ -> envelope
  PackPathEditor envelope _ _ _ -> envelope
  ImportSourceScreen envelope _ _ _ _ -> envelope
  ImportPathEditor envelope _ _ _ -> envelope
  ImportModeScreen envelope _ _ -> envelope
  ImportContainerScreen envelope _ _ _ _ _ _ -> envelope
  ProviderConnectionEditor envelope _ _ _ _ -> envelope
  ListScreen previous _ -> screenEnvelope previous
  SearchEditor previous _ _ -> screenEnvelope previous
  BrowserScreen previous _ _ _ _ _ -> screenEnvelope previous
  CommandTargetScreen envelope _ _ _ _ _ -> envelope
  InspectionScreen previous _ _ -> screenEnvelope previous
  WhyScreen previous _ _ _ -> screenEnvelope previous
  ReadOnlyScreen previous _ -> screenEnvelope previous
  SuspendedScreen previous _ -> screenEnvelope previous
  CompletionNoticeScreen _ previous -> screenEnvelope previous

refreshesPackRegistry :: Opportunity -> Bool
refreshesPackRegistry = \case
  PackInstallOpportunity{} -> True
  PackInstallResultOpportunity{} -> True
  PackUpdateOpportunity{} -> True
  PackUpdateResultOpportunity{} -> True
  PackRemovalResultOpportunity _ True _ -> True
  PackTrustResultOpportunity{} -> True
  ProviderConnectionResultOpportunity{} -> True
  _ -> False

{- | Bricks a target-less Brick command can act on, with the Brick of the
current screen preselected. Lifecycle commands list only Bricks in the state
they accept: archived ones for restore, any for update, active otherwise.
-}
brickCommandTargets :: InteractionEnvelope -> Text -> [SearchHit] -> ([SearchHit], Int)
brickCommandTargets envelope commandId hits = (targets, fromMaybe 0 (contextHandle >>= \handle -> findIndex ((== handle) . searchHitHandle) targets))
 where
  targets = filter (\hit -> searchHitKind hit == "brick" && accepts (hitStatus hit)) hits
  hitStatus = fst . Text.breakOn " · " . fromMaybe "" . Text.stripPrefix "status: " . searchHitDetails
  accepts status = case commandId of
    "restore" -> status == "archived"
    "update" -> True
    _ -> status `elem` ["active", "in progress"]
  contextHandle = case Text.words <$> contentSubject (envelopeContent envelope) of
    Just (handle : _) | "#" `Text.isPrefixOf` handle -> Just handle
    _ -> Nothing

screenForEnvelope :: InteractionEnvelope -> ReplScreen
screenForEnvelope envelope = case envelopeOpportunity envelope of
  WorkTitleOpportunity _ _ _ title -> InteractionEditor envelope "work.title.submit" (selectedEditor title) Nothing
  TranslationEditOpportunity _ suggestion _ -> InteractionEditor envelope "translate.edit.submit" (maybe (EditorState "" "" Nothing) selectedEditor suggestion) Nothing
  SourceRelocateOpportunity _ draft -> InteractionEditor envelope "source.relocate.submit" (selectedEditor draft) Nothing
  RawShelfNameOpportunity _ name -> InteractionEditor envelope "raw-shelf.name.submit" (selectedEditor name) Nothing
  WorkOtherExplanationOpportunity _ _ draft -> InteractionEditor envelope "work.other.submit" (selectedEditor draft) Nothing
  WorkBreakDraftOpportunity{} -> InteractionEditor envelope "work.break.submit" (EditorState "" "" Nothing) Nothing
  RepeatableReturnCenterOpportunity _ _ draft -> InteractionEditor envelope "return.center.submit" (selectedEditor draft) Nothing
  RepeatableReturnVariationOpportunity _ _ _ _ draft -> InteractionEditor envelope "return.variation.submit" (selectedEditor draft) Nothing
  RepeatableReturnZoneOpportunity _ _ _ _ _ draft -> InteractionEditor envelope "return.zone.submit" (selectedEditor draft) Nothing
  UpdateTextOpportunity _ _ _ draft -> InteractionEditor envelope "update.text.submit" (selectedEditor draft) Nothing
  ObligationExcuseOpportunity _ draft -> InteractionEditor envelope "occurrence.excuse.submit" (selectedEditor draft) Nothing
  RecurrenceFieldOpportunity _ field _ draft
    | not (recurrenceFieldIsChoice field) -> InteractionEditor envelope "recurrence.field.submit" (selectedEditor draft) Nothing
  _ -> EnvelopeScreen envelope Nothing

-- Advance only the already committed completion checkpoint. The usual
-- response pipeline records the next draw, and never accepts its Focus offer.
presentCompletedEnvelope :: AppEnv -> InteractionEnvelope -> IO ReplScreen
presentCompletedEnvelope environment envelope = case envelopeOpportunity envelope of
  CompletionResultOpportunity{} ->
    runAppCommand environment False (const (pure ())) (RespondCommand (interactionResponse envelope "next")) >>= \case
      Left problem -> pure (EnvelopeScreen envelope (Just ("Work completed. Could not get the next opportunity: " <> appErrorMessage problem <> " Press n to retry.")))
      Right RespondResult{resultInteraction} -> pure (CompletionNoticeScreen receipt (screenForEnvelope resultInteraction))
      Right other -> pure (CompletionNoticeScreen receipt (ReadOnlyScreen (screenForEnvelope envelope) (renderCommandResult other)))
  _ -> pure (screenForEnvelope envelope)
 where
  receipt = "✓ Completed: " <> Text.intercalate " " (take 1 (contentBody (envelopeContent envelope)))

paletteReturnScreen :: InteractionEnvelope -> PaletteReturn -> ReplScreen
paletteReturnScreen envelope = \case
  ReturnToEnvelope -> screenForEnvelope envelope
  ReturnToScreen previous -> previous
  ReturnToPackManager packs problem selected -> PackManagerScreen envelope packs problem selected Nothing
  ReturnToImportMode selection -> ImportModeScreen envelope selection Nothing
  ReturnToImportContainers selection mode containers selected chosen -> ImportContainerScreen envelope selection mode containers selected chosen Nothing

paletteReadOnlyScreen :: InteractionEnvelope -> PaletteReturn -> Text -> ReplScreen
paletteReadOnlyScreen envelope target =
  ReadOnlyScreen (paletteReturnScreen envelope target)

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
  PaletteScreen envelope query selected _ -> paletteModelAtWidth width envelope query selected
  PackManagerScreen envelope packs problem selected message -> packManagerModelAtWidth width envelope packs problem selected message
  PackPathEditor envelope purpose editor message -> packPathEditorModelAtWidth width envelope purpose editor message
  ImportSourceScreen envelope choices query selected message -> importSourceModelAtWidth width envelope choices query selected message
  ImportPathEditor envelope descriptor editor message -> importPathEditorModelAtWidth width envelope descriptor editor message
  ImportModeScreen envelope selection message -> importModeModelAtWidth width envelope selection message
  ImportContainerScreen envelope selection mode containers selected chosen message -> importContainerModelAtWidth width envelope selection mode containers selected chosen message
  ProviderConnectionEditor envelope definition stage editor message -> providerConnectionEditorModelAtWidth width envelope definition stage editor message
  ListScreen previous view -> listModel width (screenEnvelope previous) view
  SearchEditor previous editor message -> editorModel width (screenEnvelope previous) "Search" "Search titles, contents, or typed handles such as #brick and +raw." editor message
  BrowserScreen previous heading entries query selected message -> browserModel width (screenEnvelope previous) heading entries query selected message
  CommandTargetScreen envelope command entries query selected message -> browserModelWithVerb "preview" width envelope ("Choose Work for /" <> commandOptionId command) entries query selected message
  InspectionScreen previous hit text -> documentModel width (screenEnvelope previous) text (if searchHitKind hit == "brick" then "[f] focus · [u] update · ↑/↓ scroll · Esc back" else "↑/↓ scroll · PgUp/PgDn page · Esc back")
  WhyScreen previous summary details complete -> documentModel width (screenEnvelope previous) (Text.unlines (summary <> if complete then details else [])) "[d] details · [b] back · Esc back"
  ReadOnlyScreen previous text -> documentModel width (screenEnvelope previous) text "↑/↓ scroll · PgUp/PgDn page · Esc back"
  SuspendedScreen previous _ -> modelFor width previous
  CompletionNoticeScreen receipt previous -> prependCompletionNotice width (Just receipt) (modelFor width previous)

listHit :: ListRow -> SearchHit
listHit row = SearchHit kind (listEntryHandle row) (listEntryTitle row) (listEntryDetails row)
 where
  kind
    | "+" `Text.isPrefixOf` listEntryHandle row = "raw"
    | "#" `Text.isPrefixOf` listEntryHandle row = "brick"
    | otherwise = "external_effect"

listViewRows :: ListView -> [(Text, Text, SearchHit)]
listViewRows view
  | listViewName view == "agenda" =
      if listViewFlatDays view
        then [("", "", hit) | hit <- filteredHits query entries]
        else Tree.treeRows (Tree.filterForest matches (fmap categoryTree (listViewCategories view)))
  | listViewGrouped view = Tree.treeRows (Tree.filterForest matches (fmap categoryTree (listViewCategories view)))
  | listViewName view == "importance" = importanceTreeRows query entries
  | otherwise = [("", "", hit) | hit <- filteredHits query entries]
 where
  query = listViewQuery view
  entries = fmap listHit (listViewEntries view)
  matches = not . null . filteredHits query . pure
  categoryTree (ListCategory label children) = Tree.Node (SearchHit "category" "" label "") (categoryTree <$> children)
  categoryTree (ListItem row _ children) = Tree.Node (listHit row) (categoryTree <$> children)

listViewHits :: ListView -> [SearchHit]
listViewHits view = [hit | (_, _, hit) <- listViewRows view, searchHitKind hit /= "category"]

listModel :: Int -> InteractionEnvelope -> ListView -> ScreenModel
listModel width envelope view = ScreenModel (content <> pinned) Nothing
 where
  heading = case listViewName view of
    "importance" -> "Importance order"
    "agenda" -> "Agenda"
    _ -> "Focus forecast"
  agenda = listViewName view == "agenda"
  rows = listViewRows view
  indices = scanl (\index (_, _, hit) -> index + if searchHitKind hit == "category" then 0 else 1) 0 rows
  content =
    styledLines Heading (heading <> if listViewGrouped view && not agenda then " · Categories + parts" else "")
      <> concat [styledLines Dim ("Scope: " <> Text.unwords (listViewScope view)) | not (null (listViewScope view))]
      <> concat [styledLines Dim "Chances apply when next draws flexible work." | listViewName view == "forecast"]
      <> (if agenda then fmap (pure . Span Normal) (listViewHeader view) else styledLines Dim "Positions are local to each sibling group.")
      <> [[Span Accent "Search: ", Span Normal (listViewQuery view <> if listViewSearching view then "▏" else "")] | listViewSearching view || not (Text.null (listViewQuery view))]
      <> [[]]
      <> (if null rows then [[Span Dim "No matches."]] else concat (zipWith (renderBrowserHit width True (listViewSelected view)) indices rows))
      <> maybe [] (fmap (pure . Span Warning) . wrapWords width) (listViewMessage view)
  hints
    | listViewSearching view = ["Type to search · ↑/↓ select", "Ctrl+F finish · Enter inspect", "Esc clear search"]
    | width < 50 = [viewHint, treeHint, "Ctrl+F search · Enter show", "↑/↓ select · " <> escapeHint]
    | otherwise = [viewHint <> " · " <> treeHint <> " · Ctrl+F search", "↑/↓ select · Enter inspect · " <> escapeHint <> " · [/] more"]
  viewHint = "[v] " <> nextListView (listViewName view)
  treeHint
    | agenda = "[t] days " <> if listViewFlatDays view then "on" else "off"
    | otherwise = "[t] categories " <> if listViewGrouped view then "off" else "on"
  escapeHint = if Text.null (listViewQuery view) then "Esc back" else "Esc clear search"
  footer = footerFrom width envelope
  pinned = take 1 footer <> concatMap (fmap (pure . Span Dim) . wrapWords width) hints <> drop 1 footer
  styledLines role = fmap (pure . Span role) . wrapWords width

-- | UX-280: @v@ cycles importance, forecast, and agenda.
nextListView :: Text -> Text
nextListView = \case
  "importance" -> "forecast"
  "forecast" -> "agenda"
  _ -> "importance"

filteredHits :: Text -> [SearchHit] -> [SearchHit]
filteredHits query = filter matches
 where
  needle = Text.toCaseFold (Text.unwords (Text.words query))
  matches hit = Text.null needle || needle `Text.isInfixOf` Text.toCaseFold (searchHitHandle hit <> " " <> searchHitTitle hit <> " " <> searchHitDetails hit)

browserHits :: Text -> Text -> [SearchHit] -> [SearchHit]
browserHits heading query entries
  | heading == "Importance order" = [hit | (_, _, hit) <- importanceTreeRows query entries]
  | otherwise = filteredHits query entries

importanceTreeRows :: Text -> [SearchHit] -> [(Text, Text, SearchHit)]
importanceTreeRows query = Tree.treeRows . Tree.filterForest (not . null . filteredHits query . pure) . Tree.fromIndentedLabels searchHitTitle

browserModel :: Int -> InteractionEnvelope -> Text -> [SearchHit] -> Text -> Int -> Maybe Text -> ScreenModel
browserModel = browserModelWithVerb "inspect"

browserModelWithVerb :: Text -> Int -> InteractionEnvelope -> Text -> [SearchHit] -> Text -> Int -> Maybe Text -> ScreenModel
browserModelWithVerb verb width envelope heading entries query selected message =
  ScreenModel
    ( [[Span Normal heading]]
        <> [ [Span Dim line]
           | heading == "Focus forecast"
           , line <- ["Chances apply when next draws flexible work.", "Importance positions are local to each sibling group."]
           ]
        <> [[Span Dim "Filter: ", Span Normal query], []]
        <> (if null visible then [[Span Dim "No matches."]] else concat (zipWith (renderBrowserHit width (heading == "Importance order") selected) [0 ..] rows))
        <> maybe [] (\note -> [] : fmap (pure . Span Warning) (wrapWords width note)) message
        <> [[]]
        <> fmap (pure . Span Dim) (wrapWords width ("Showing " <> Text.pack (show (length visible)) <> " of " <> Text.pack (show (length entries)) <> " · Type to filter"))
        <> fmap (pure . Span Dim) (wrapWords width ("↑/↓ select · Enter " <> verb <> " · Esc back"))
        <> [[]]
        <> footerFrom width envelope
    )
    Nothing
 where
  rows
    | heading == "Importance order" = importanceTreeRows query entries
    | otherwise = [("", "", hit) | hit <- filteredHits query entries]
  visible = [hit | (_, _, hit) <- rows]
renderBrowserHit :: Int -> Bool -> Int -> Int -> (Text, Text, SearchHit) -> [ScreenLine]
renderBrowserHit width tree selected index (prefix, continuation, hit)
  | searchHitKind hit == "category" = [[Span Dim ("  " <> prefix), Span Heading (searchHitTitle hit)], [Span Dim ("  " <> continuation)]]
  | otherwise =
      let role = if index == selected then Selected else Normal
          label = Text.dropWhile (== ' ') (searchHitTitle hit)
          cursor = if index == selected then "> " else "  "
          titlePrefix = cursor <> prefix <> searchHitHandle hit <> " "
          labelRoom = width - textDisplayWidth titlePrefix
          detailPrefix = if Text.null continuation then "    " else "  " <> continuation
          detailRoom = width - textDisplayWidth detailPrefix
          firstRow text = [Span Normal cursor, Span Dim prefix, Span Accent (searchHitHandle hit), Span Normal " ", Span role text]
          bodyRows style text = [[Span Dim detailPrefix, Span style line] | paragraph <- Text.lines text, line <- wrapWords detailRoom paragraph]
          spacer = [Span Dim ("  " <> continuation)]
       in if tree && labelRoom >= 4 && detailRoom >= 4
            then case wrapWords labelRoom label of
              first : _ ->
                let remaining = Text.dropWhile (== ' ') (Text.drop (Text.length first) label)
                 in [firstRow first]
                      <> (if Text.null remaining then [] else bodyRows role remaining)
                      <> bodyRows Dim (searchHitDetails hit)
                      <> [spacer]
              [] -> [firstRow "", spacer]
            else [firstRow label] <> bodyRows Dim (searchHitDetails hit) <> [spacer]

documentModel :: Int -> InteractionEnvelope -> Text -> Text -> ScreenModel
documentModel width envelope text hint =
  ScreenModel (document <> [[], [Span Dim hint], []] <> footerFrom width envelope) Nothing
 where
  document = case Text.lines text of
    title : body ->
      fmap (fmap (\spanValue -> spanValue{spanRole = Heading})) (filter (not . null) (markdownLines width title))
        <> [[]]
        <> markdownLines width (Text.unlines (dropWhile (Text.null . Text.strip) body))
    [] -> []

-- Pin the product footer while exposing every content row. Selectors keep the
-- active item in view; read-only documents use an explicit scroll offset.
viewportModel :: Int -> Int -> Int -> ScreenModel -> ScreenModel
viewportModel width requestedHeight requestedOffset model = ScreenModel visibleLines Nothing
 where
  height = max 1 requestedHeight
  (content, footer, bodyRoom, overflowing) = viewportRows width requestedHeight model
  start = viewportStart bodyRoom requestedOffset content
  range = Text.pack (show (start + 1)) <> "–" <> Text.pack (show (min (length content) (start + bodyRoom))) <> "/" <> Text.pack (show (length content))
  scrollHint = [Span Dim (fromMaybe "↑/↓" (find ((<= width) . textDisplayWidth) ["Rows " <> range <> " · ↑/↓ · PgUp/PgDn", "Rows " <> range <> " · ↑/↓", "↑/↓ scroll"]))]
  visibleLines = take height (take bodyRoom (drop start content) <> take 1 (concat [wrapScreenLine (max 1 width) scrollHint | overflowing]) <> footer)

-- Keep three context rows on each side where the page permits it. A wrapped
-- title takes priority over the margin, and list ends clamp to actual content.
-- Applying this to an already adjusted offset leaves the viewport unchanged.
viewportStart :: Int -> Int -> [ScreenLine] -> Int
viewportStart bodyRoom requestedOffset content = case selected of
  [] -> offset
  first : rest ->
    let final = foldl max first rest
        titleHeight = final - first + 1
        margin = min 3 (max 0 ((bodyRoom - titleHeight) `div` 2))
        earliest = final + margin - bodyRoom + 1
        latest = first - margin
     in clamp (if titleHeight > bodyRoom then first else max earliest (min latest offset))
 where
  clamp = max 0 . min (max 0 (length content - bodyRoom))
  offset = clamp requestedOffset
  selected = [index | (index, row) <- zip [0 ..] content, any ((== Selected) . spanRole) row]

viewportRows :: Int -> Int -> ScreenModel -> ([ScreenLine], [ScreenLine], Int, Bool)
viewportRows width requestedHeight model = (content, footer, bodyRoom, overflowing)
 where
  height = max 1 requestedHeight
  rows = concatMap (wrapScreenLine (max 1 width)) (screenLines model)
  (content, footerRows) = break isDivider rows
  isDivider line = not (Text.null (plainLine line)) && Text.all (== '─') (plainLine line)
  footer = take (max 0 (height - 3)) footerRows
  room = max 1 (height - length footer)
  overflowing = length content > room
  bodyRoom = max 1 (room - if overflowing then 1 else 0)

packManagerModel :: InteractionEnvelope -> [PackProjection] -> Maybe AppError -> Int -> Maybe Text -> ScreenModel
packManagerModel = packManagerModelAtWidth 80

packManagerModelAtWidth :: Int -> InteractionEnvelope -> [PackProjection] -> Maybe AppError -> Int -> Maybe Text -> ScreenModel
packManagerModelAtWidth requestedWidth envelope packs problem selected message =
  ScreenModel
    ( [[Span Normal "Packs"]]
        <> (if null packs then [[], [Span Dim "No Packs are available."]] else [])
        <> concat (zipWith packRows [0 ..] packs)
        <> maybe [] (warningRows . ("Pack registry unavailable: " <>) . appErrorMessage) problem
        <> maybe [] warningRows message
        <> [[]]
        <> actionRows
        <> [[Span Dim "↑/↓ select · Enter show · Esc back"], []]
        <> footerFrom width envelope
    )
    Nothing
 where
  width = max 20 requestedWidth
  packRows index pack =
    let cursor = if index == selected then "> " else "  "
        title = projectedPackDisplayName pack <> " " <> projectedPackVersion pack
        details =
          projectedPackName pack
            <> " · "
            <> projectedPackTrustClass pack
            <> " · "
            <> projectedPackStatus pack
            <> " · "
            <> Text.pack (show (length (filter projectedPackComponentEnabled (projectedPackComponents pack))))
            <> " components"
        titleLines = wrapWords (max 1 (width - 2)) title
        detailLines = wrapWords (max 1 (width - 4)) details
        selectedRole = if index == selected then Selected else Normal
     in [ [Span Normal cursor, Span selectedRole first]
        | first <- take 1 titleLines
        ]
          <> [[Span Normal "  ", Span selectedRole continuation] | continuation <- drop 1 titleLines]
          <> [[Span Dim "    ", Span Dim detail] | detail <- detailLines]
  actionRows =
    concatMap
      fitActionGroup
      [ [("s", "show"), ("u", "update"), ("m", "remove")]
      , [("i", "install..."), ("r", "refresh catalog"), ("t", "trust publisher...")]
      , [("g", "collect garbage"), ("/", "more...")]
      ]
  fitActionGroup actions =
    let joined = joinActionSpans actions
     in if Text.length (plainLine joined) <= width
          then [joined]
          else [actionSpans shortcut label | (shortcut, label) <- actions]
  joinActionSpans = intercalateSpans [Span Normal "   "] . fmap (uncurry actionSpans)
  intercalateSpans _ [] = []
  intercalateSpans separator (first : rest) = first <> foldMap (separator <>) rest
  warningRows warning = [] : fmap (pure . Span Warning) (wrapWords width warning)

importSourceChoices :: AppEnv -> [ImportCatalogChoice]
importSourceChoices environment = sortOn importChoiceLabel (ready <> connectable)
 where
  ready = ReadyImportSource <$> importPortCatalog (appImportPort environment)
  installed = maybe [] providerConnectionInstalledDefinitions (appProviderConnectionRuntime environment)
  connectable =
    [ ConnectImportSource definition
    | definition <- installed
    , not (any (descriptorBelongsTo definition) (importPortCatalog (appImportPort environment)))
    ]
  descriptorBelongsTo definition descriptor =
    let source = providerDefinitionAdapterId definition
        reference = importSourceId descriptor
     in reference == source || (source <> "@") `Text.isPrefixOf` reference

connectedProviderImportSelection :: AppEnv -> Text -> Text -> Maybe ImportSelection
connectedProviderImportSelection environment source accountName = do
  let exactReference = source <> "@" <> accountName
      descriptors = importPortCatalog (appImportPort environment)
  descriptor <-
    find ((== exactReference) . importSourceId) descriptors
      <|> find ((== source) . importSourceId) descriptors
  pure (ImportSelection descriptor (importSourceId descriptor))

importChoiceLabel :: ImportCatalogChoice -> Text
importChoiceLabel = \case
  ReadyImportSource descriptor -> importSourceDisplayName descriptor
  ConnectImportSource definition -> providerDefinitionDisplayName definition <> " · connect..."

filteredImportSources :: [ImportCatalogChoice] -> Text -> [ImportCatalogChoice]
filteredImportSources choices query = filter matches choices
 where
  needle = Text.toLower (Text.strip query)
  matches choice = Text.null needle || needle `Text.isInfixOf` Text.toLower (importChoiceLabel choice <> " " <> importChoiceIdentity choice)
  importChoiceIdentity = \case
    ReadyImportSource descriptor -> importSourceId descriptor
    ConnectImportSource definition -> providerDefinitionAdapterId definition

importSourceModel :: InteractionEnvelope -> [ImportCatalogChoice] -> Text -> Int -> Maybe Text -> ScreenModel
importSourceModel = importSourceModelAtWidth 80

importSourceModelAtWidth :: Int -> InteractionEnvelope -> [ImportCatalogChoice] -> Text -> Int -> Maybe Text -> ScreenModel
importSourceModelAtWidth width envelope choices query selected message =
  ScreenModel
    ( [[Span Normal "Import from:"], [], [Span Normal "› ", Span Normal query], []]
        <> concat (zipWith renderChoice [0 ..] visible)
        <> maybe [] (\problem -> [] : fmap (pure . Span Warning) (wrapWords width problem)) message
        <> [[], [Span Dim "Type to filter available sources."], [Span Dim "↑/↓ select · Enter choose · Esc back"], []]
        <> footerFrom width envelope
    )
    Nothing
 where
  visible = filteredImportSources choices query
  renderChoice index choice =
    let selectedRole = if index == selected then Selected else Normal
        marker = if index == selected then "> " else "  "
        detail = case choice of
          ReadyImportSource descriptor
            | null (importSourceExtensions descriptor) -> "configured account · " <> modeSummary descriptor
            | otherwise -> Text.intercalate ", " (importSourceExtensions descriptor) <> " · " <> modeSummary descriptor
          ConnectImportSource _ -> "installed connector · account required"
     in [Span Normal marker, Span selectedRole (importChoiceLabel choice)] : [[Span Dim "    ", Span Dim detail]]
  modeSummary descriptor = Text.intercalate ", " (sourceModeName <$> importSourceModes descriptor)

importPathEditorModelAtWidth :: Int -> InteractionEnvelope -> ImportSourceDescriptor -> EditorState -> Maybe Text -> ScreenModel
importPathEditorModelAtWidth width envelope descriptor =
  editorModel
    width
    envelope
    ("Choose " <> importSourceDisplayName descriptor)
    ("Enter one local " <> Text.intercalate " or " (importSourceExtensions descriptor) <> " file. Little Ant opens it read-only and follows no symlink.")

importModeModel :: InteractionEnvelope -> ImportSelection -> Maybe Text -> ScreenModel
importModeModel = importModeModelAtWidth 80

importModeModelAtWidth :: Int -> InteractionEnvelope -> ImportSelection -> Maybe Text -> ScreenModel
importModeModelAtWidth width envelope selection message =
  ScreenModel
    ( [[Span Normal ("Import " <> importSourceDisplayName descriptor <> ":")], []]
        <> concatMap renderMode supported
        <> [actionSpans "k" "I don't know"]
        <> maybe [] (\note -> [] : fmap (pure . Span Normal) (wrapWords width note)) message
        <> [[], actionSpans "/" "more...", []]
        <> footerFrom width envelope
    )
    Nothing
 where
  descriptor = importSelectionDescriptor selection
  supported = importSourceModes descriptor
  renderMode mode =
    [ actionSpans (sourceModeShortcut mode) (sourceModeAction mode)
    , [Span Dim "     ", Span Dim (sourceModeExplanation mode)]
    ]

importContainerModel :: InteractionEnvelope -> ImportSelection -> SourceMode -> [SourceContainer] -> Int -> Set.Set Text -> Maybe Text -> ScreenModel
importContainerModel = importContainerModelAtWidth 80

importContainerModelAtWidth :: Int -> InteractionEnvelope -> ImportSelection -> SourceMode -> [SourceContainer] -> Int -> Set.Set Text -> Maybe Text -> ScreenModel
importContainerModelAtWidth width envelope selection mode containers selected chosen message =
  ScreenModel
    ( (pure . Span Normal <$> wrapWords width heading)
        <> (pure . Span Dim <$> wrapWords width (importSourceDisplayName (importSelectionDescriptor selection)))
        <> [[]]
        <> concat (zipWith renderContainer [0 ..] containers)
        <> maybe [] (\note -> [] : fmap (pure . Span Normal) (wrapWords width note)) message
        <> [[]]
        <> actionRows
        <> [actionSpans "k" "I don't know", actionSpans "/" "more...", []]
        <> footerFrom width envelope
    )
    Nothing
 where
  heading = case mode of
    SourceSnapshot -> "Snapshot which containers?"
    SourceSynchronize -> "Keep synchronizing from which containers?"
    SourceMigrate -> "Migrate which containers?"
  renderContainer index container =
    let identity = sourceContainerExternalId container
        checked = identity `Set.member` chosen
        active = index == selected
        role = if active then Selected else Normal
        cursor = if active then "> " else "  "
        mark = if checked then "x" else " "
        labelLines = wrapWords (max 1 (width - 6)) (sourceContainerLabel container)
        identityLines = Text.chunksOf (max 1 (width - 6)) identity
        firstLabel = fromMaybe "" (safeIndex 0 labelLines)
     in [[Span Normal cursor, Span Dim "[", Span Accent mark, Span Dim "] ", Span role firstLabel]]
          <> [[Span Normal "      ", Span role line] | line <- drop 1 labelLines]
          <> [[Span Dim "      ", Span Dim line] | line <- identityLines]
  spaceAction = [Span Dim "[", Span Accent "space", Span Dim "]", Span Normal " toggle"]
  combinedActions = spaceAction <> [Span Normal "   "] <> actionSpans "i" "import selected"
  actionRows
    | Text.length (plainLine combinedActions) <= width = [combinedActions]
    | otherwise = [spaceAction, actionSpans "i" "import selected"]

providerConnectionEditorModelAtWidth :: Int -> InteractionEnvelope -> ProviderSourceDefinition -> ProviderConnectionInput -> EditorState -> Maybe Text -> ScreenModel
providerConnectionEditorModelAtWidth width envelope definition stage =
  editorModel width envelope heading hint
 where
  provider = providerDefinitionDisplayName definition
  (heading, hint) = case stage of
    ProviderAccountKey ->
      ( "Connect " <> provider <> " — account key"
      , "Choose a short lowercase local key, such as personal or work. This is not sent to the provider."
      )
    ProviderAccountLabel _ ->
      ( "Connect " <> provider <> " — account label"
      , "Optional. Use a recognizable English label; press Enter to reuse the account key."
      )
    ProviderClientId _ _ ->
      ( "Connect " <> provider <> " — public client ID"
      , "Enter the public OAuth client ID for this connector. It is configuration, not a secret; the next screen previews exact authority."
      )

sourceModeName :: SourceMode -> Text
sourceModeName = \case
  SourceSnapshot -> "snapshot"
  SourceSynchronize -> "synchronize"
  SourceMigrate -> "migrate"

sourceModeShortcut :: SourceMode -> Text
sourceModeShortcut = \case
  SourceSnapshot -> "s"
  SourceSynchronize -> "y"
  SourceMigrate -> "m"

sourceModeAction :: SourceMode -> Text
sourceModeAction = \case
  SourceSnapshot -> "snapshot once"
  SourceSynchronize -> "keep synchronizing"
  SourceMigrate -> "migrate"

sourceModeExplanation :: SourceMode -> Text
sourceModeExplanation = \case
  SourceSnapshot -> "Preserve what exists now without checking again."
  SourceSynchronize -> "Observe later source changes for review."
  SourceMigrate -> "Verify a local cutover and stop relying on the source."

packPathEditorModel :: InteractionEnvelope -> PackPathPurpose -> EditorState -> Maybe Text -> ScreenModel
packPathEditorModel = packPathEditorModelAtWidth 80

packPathEditorModelAtWidth :: Int -> InteractionEnvelope -> PackPathPurpose -> EditorState -> Maybe Text -> ScreenModel
packPathEditorModelAtWidth width envelope purpose =
  editorModel width envelope heading hint
 where
  (heading, hint) = case purpose of
    InstallPackArchive ->
      ( "Install a Pack"
      , "Enter an official Pack name or the path to one local signed .lantpack archive. Nothing changes before the separate preview is accepted."
      )
    TrustPublisherKey ->
      ( "Trust a Pack publisher"
      , "Enter the path to one canonical publisher-key JSON file. Trust is profile-local and installs nothing."
      )

catalogRefreshMessage :: CommandResult -> Text
catalogRefreshMessage = \case
  ConfigurationResult{resultAdministrationAction = "packs_refresh", resultConfigurationFacts} ->
    let status = Map.findWithDefault "verified" "status" resultConfigurationFacts
        sequenceNumber = Map.findWithDefault "?" "catalog_sequence" resultConfigurationFacts
     in "Official catalog " <> status <> " · sequence " <> sequenceNumber <> "."
  other -> renderCommandResult other

actionSpans :: Text -> Text -> ScreenLine
actionSpans shortcut label = case Text.breakOn shortcut label of
  (before, after)
    | Text.null after -> [Span Dim "[", Span Accent shortcut, Span Dim "]", Span Normal (" " <> label)]
    | otherwise -> [Span Normal before, Span Dim "[", Span Accent shortcut, Span Dim "]", Span Normal (Text.drop 1 after)]

editorModel :: Int -> InteractionEnvelope -> Text -> Text -> EditorState -> Maybe Text -> ScreenModel
editorModel width envelope heading hint editor message =
  ScreenModel
    ( [[Span Normal heading], []]
        <> fmap (pure . Span Dim) (wrapWords (max 20 width) hint)
        <> [[], [Span Normal "› ", Span Normal (editorBefore editor), Span Selected selection, Span Normal after]]
        <> maybe [] (\problem -> [] : fmap (pure . Span Warning) (wrapWords (max 20 width) problem)) message
        <> [[], [Span Dim "[Enter] continue · [Esc] back"], []]
        <> footerFrom width envelope
    )
    Nothing
 where
  (selection, after) = case editorSelection editor of
    Just selected -> (selected, editorAfter editor)
    Nothing -> case Text.uncons (editorAfter editor) of
      Just (character, rest) -> (Text.singleton character, rest)
      Nothing -> (" ", "")

paletteModel :: InteractionEnvelope -> Text -> Int -> ScreenModel
paletteModel = paletteModelAtWidth 80

paletteModelAtWidth :: Int -> InteractionEnvelope -> Text -> Int -> ScreenModel
paletteModelAtWidth width envelope query selected =
  ScreenModel
    ( [[Span Normal "More:"], [], [Span Normal "› ", Span Normal query], []]
        <> concat (zipWith renderRow [0 ..] commands)
        <> [[], [Span Dim "Type to filter available commands."], [Span Dim "↑/↓ select · Enter run · Esc back"], []]
        <> footerFrom width envelope
    )
    Nothing
 where
  commands = filteredCommands envelope query
  rowWidth = max 1 (min 100 width)
  labelBudget = max 12 ((rowWidth - 2) * 3 `div` 5)
  renderRow index command =
    let label = paletteDisplayLabel labelBudget (commandOptionCommand command)
        description = paletteDisplayDescription command
        labelColumns = max 12 (textDisplayWidth label)
        descriptionRoom = rowWidth - 2 - labelColumns - 2
        prefix = Span Normal (if index == selected then "> " else "  ")
        labelSpan = Span (if index == selected then Selected else Normal) label
     in if descriptionRoom < 16
          then wrapScreenLine rowWidth [prefix, labelSpan] <> [[Span Dim ("    " <> ellipsizeCells (rowWidth - 4) description)]]
          else [[prefix, labelSpan, Span Normal (Text.replicate (labelColumns - textDisplayWidth label + 2) " "), Span Dim (ellipsizeCells descriptionRoom description)]]

-- Abbreviate display-only title previews. Filtering and dispatch retain the
-- complete CommandOption, including its exact reference and original title.
paletteDisplayLabel :: Int -> Text -> Text
paletteDisplayLabel budget command = case Text.words command of
  verb : reference : titleWords@(_ : _) ->
    let base = verb <> " " <> reference
        title = Text.unwords titleWords
        unquoted = Text.stripPrefix "\"" title >>= Text.stripSuffix "\""
        room = budget - textDisplayWidth base - 3
     in case unquoted of
          Nothing -> command
          Just preview -> if room < 8 then base else base <> " \"" <> ellipsizeCells room preview <> "\""
  _ -> command

paletteDisplayDescription :: CommandOption -> Text
paletteDisplayDescription command =
  let arguments = Text.strip (Text.dropWhile (/= ' ') (commandOptionCommand command))
      original = commandOptionDescription command
   in case if Text.null arguments then Nothing else Text.stripSuffix arguments original of
        Nothing -> original
        Just prefix ->
          let trimmed = Text.strip prefix
           in fromMaybe trimmed (Text.stripSuffix " for" trimmed)

ellipsizeCells :: Int -> Text -> Text
ellipsizeCells requestedWidth text
  | textDisplayWidth text <= width = text
  | width < 5 = Text.replicate (min 3 width) "."
  | width == 5 = "(...)"
  | otherwise = Text.stripEnd (takeCells (width - 6) text) <> " (...)"
 where
  width = max 0 requestedWidth
  takeCells remaining value = case Text.uncons value of
    Just (character, rest)
      | let cells = textDisplayWidth (Text.singleton character)
      , cells <= remaining ->
          Text.cons character (takeCells (remaining - cells) rest)
    _ -> ""

filteredCommands :: InteractionEnvelope -> Text -> [CommandOption]
filteredCommands envelope query = if null namedMatches then filter matchesDescription available else namedMatches
 where
  available = envelopeCommands envelope
  namedMatches = filter matches available
  needle = Text.toLower (Text.dropWhile (== '/') (canonicalExitQuery query))
  namedCommand = case Text.words query of first : _ : _ -> Just first; _ -> Nothing
  matches command = Text.null needle || needle `Text.isInfixOf` Text.toLower (commandOptionCommand command) || maybe False (\name -> take 1 (Text.words (commandOptionCommand command)) == [name]) namedCommand
  matchesDescription command = needle `Text.isInfixOf` Text.toLower (commandOptionDescription command)

-- The only compatibility spelling is exact and presentation-only. Text input
-- and command arguments never acquire an exit meaning through prefix matching.
canonicalExitQuery :: Text -> Text
canonicalExitQuery query
  | Text.strip query == "/quit" = "/exit"
  | otherwise = query

isMainOpportunity :: Opportunity -> Bool
isMainOpportunity = \case
  PristineOpportunity -> True
  SafeEmptyOpportunity -> True
  RawTriageOpportunity{} -> True
  RawDuplicateOpportunity{} -> True
  FocusProposalOpportunity{} -> True
  CurrentFocusOpportunity{} -> True
  ScheduledCommitmentOpportunity{} -> True
  ScheduledOverlapOpportunity{} -> True
  _ -> False

paletteCommandSelection :: InteractionEnvelope -> Text -> Int -> Maybe CommandOption
paletteCommandSelection envelope query selected = do
  command <- safeIndex selected (filteredCommands envelope query)
  pure $ case Text.words query of
    name : arguments@(_ : _) | take 1 (Text.words (commandOptionCommand command)) == [name] -> command{commandOptionCommand = Text.unwords (name : arguments)}
    _ -> command

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

prependCompletionNotice :: Int -> Maybe Text -> ScreenModel -> ScreenModel
prependCompletionNotice _ Nothing model = model
prependCompletionNotice width (Just receipt) model =
  model
    { screenLines = prefix <> screenLines model
    , screenCursor = (\cursor -> cursor{cursorRow = cursorRow cursor + length prefix}) <$> screenCursor model
    }
 where
  prefix = wrapScreenLine (max 1 width) [Span Accent receipt] <> [[]]

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

wrapWords :: Int -> Text -> [Text]
wrapWords = wrapDisplayText

textModel :: Text -> ScreenModel
textModel text = ScreenModel (fmap (pure . Span Normal) (Text.lines text)) Nothing

errorModel :: AppError -> ScreenModel
errorModel = textModel . renderError

waitForExit :: Vty -> IO ()
waitForExit vty = void (nextEvent vty)

acquireCredentialWithVty :: Vty -> ColorMode -> Text -> IO (Either AppError ByteString.ByteString)
acquireCredentialWithVty vty color label = collect ByteString.empty Nothing
 where
  collect secret message = do
    paint vty color (credentialInputModel label (ByteString.length secret) message)
    nextEvent vty >>= \event -> case eventToInput event of
      Just (Printable 'c' modifiers) | MCtrl `elem` modifiers -> cancel secret
      Just (Printable character [])
        | character >= '!' && character <= '~' -> collect (ByteString.snoc secret (fromIntegral (ord character))) Nothing
      Just (Pasted material)
        | let credential = Text.strip material
        , not (Text.null credential)
        , Text.all (\character -> character >= '!' && character <= '~') credential
        , ByteString.length secret + Text.length credential <= 16 * 1024 ->
            collect (secret <> TextEncoding.encodeUtf8 credential) Nothing
        | otherwise -> collect secret (Just "Paste one credential of at most 16 KiB without embedded whitespace.")
      Just (Backspace _)
        | ByteString.null secret -> collect secret Nothing
        | otherwise -> collect (ByteString.init secret) Nothing
      Just (Enter _)
        | ByteString.null secret -> collect secret (Just "The credential cannot be empty.")
        | otherwise -> pure (Right secret)
      Just (Escape _) -> cancel secret
      Just (ArrowLeft _) -> collect secret Nothing
      Just (ArrowRight _) -> collect secret Nothing
      _ -> collect secret message
  cancel secret = do
    wipeAgentSecret secret
    pure . Left $ appError PreconditionFailed "Credential input was cancelled; the provider remains unconfigured."

credentialInputModel :: Text -> Int -> Maybe Text -> ScreenModel
credentialInputModel label length' message =
  ScreenModel
    ( [ [Span Normal "Connect provider — credential"]
      , []
      , [Span Normal label]
      , []
      , [Span Normal "› ", Span Accent (Text.replicate length' "•")]
      , []
      , [Span Dim "Input is hidden. The credential goes only to this profile's encrypted vault."]
      ]
        <> maybe [] (\problem -> [[], [Span Warning problem]]) message
        <> [[], [Span Dim "Enter continue · Esc cancel"]]
    )
    Nothing

helpText :: Text
helpText = "Little Ant shows one useful opportunity at a time.\n\nUse the visible keys or return with Escape.\nUse /why to inspect the recorded selection without drawing again."

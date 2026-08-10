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
  progressModel,
  runRepl,
  runReplWithCommand,
) where

import Control.Applicative ((<|>))
import Control.Exception (bracket)
import Control.Monad (void)
import Data.ByteString qualified as ByteString
import Data.Char (ord)
import Data.IORef
import Data.List (find, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Graphics.Vty (Modifier (MCtrl), Vty, nextEvent, picForImage, shutdown, update)
import Graphics.Vty.Config (defaultConfig)
import Graphics.Vty.CrossPlatform qualified as CrossPlatform
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Import
import LittleAnt.Interaction
import LittleAnt.Model (Actor (actorProfile), SourceMode (..))
import LittleAnt.Profile qualified as Profile
import LittleAnt.Projection
import LittleAnt.Protocol
import LittleAnt.Provider
import LittleAnt.Result
import LittleAnt.Source (SourceContainer (..))
import LittleAnt.Surface
import LittleAnt.Terminal
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
  | PackDetailScreen InteractionEnvelope [PackProjection] (Maybe AppError) Int Text
  | ImportSourceScreen InteractionEnvelope [ImportCatalogChoice] Text Int (Maybe Text)
  | ImportPathEditor InteractionEnvelope ImportSourceDescriptor EditorState (Maybe Text)
  | ImportModeScreen InteractionEnvelope ImportSelection (Maybe Text)
  | ImportContainerScreen InteractionEnvelope ImportSelection SourceMode [SourceContainer] Int (Set.Set Text) (Maybe Text)
  | ProviderConnectionEditor InteractionEnvelope ProviderSourceDefinition ProviderConnectionInput EditorState (Maybe Text)
  | ReadOnlyScreen InteractionEnvelope Text

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
  | ReturnToPackManager [PackProjection] (Maybe AppError) Int
  | ReturnToImportMode ImportSelection
  | ReturnToImportContainers ImportSelection SourceMode [SourceContainer] Int (Set.Set Text)

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
      Right NextResult{resultInteraction} -> loop environmentRef vty color 80 (screenForEnvelope resultInteraction)
      Right RepairResult{resultInteraction} -> loop environmentRef vty color 80 (screenForEnvelope resultInteraction)
      Right other -> paint vty color (textModel (renderCommandResult other)) >> waitForExit vty

loop :: IORef AppEnv -> Vty -> ColorMode -> Int -> ReplScreen -> IO ()
loop environmentRef vty color width screen = do
  paint vty color (modelFor width screen)
  event <- nextEvent vty
  case eventToInput event of
    Nothing -> loop environmentRef vty color width screen
    Just (Resized nextWidth _) -> loop environmentRef vty color nextWidth screen
    Just input -> transition input >>= maybe (pure ()) (loop environmentRef vty color width)
 where
  transition input = case screen of
    EnvelopeScreen envelope _ -> envelopeInput envelope input
    FeedEditor envelope editor message -> feedEditorInput envelope editor message input
    InteractionEditor envelope action editor message -> interactionEditorInput envelope action editor message input
    PaletteScreen envelope query selected target -> paletteInput envelope query selected target input
    PackManagerScreen envelope packs problem selected message -> packManagerInput envelope packs problem selected message input
    PackPathEditor envelope purpose editor message -> packPathInput envelope purpose editor message input
    PackDetailScreen envelope packs problem selected _ -> case input of
      Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
      _ -> pure (Just (PackManagerScreen envelope packs problem selected Nothing))
    ImportSourceScreen envelope choices query selected message -> importSourceInput envelope choices query selected message input
    ImportPathEditor envelope descriptor editor message -> importPathInput envelope descriptor editor message input
    ImportModeScreen envelope selection message -> importModeInput envelope selection message input
    ImportContainerScreen envelope selection mode containers selected chosen message -> importContainerInput envelope selection mode containers selected chosen message input
    ProviderConnectionEditor envelope definition stage editor message -> providerConnectionInput envelope definition stage editor message input
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
    Escape _ | isRepairScreen envelope -> pure Nothing
    Escape _ | ProviderConnectionOpportunity{} <- envelopeOpportunity envelope -> invokeAction envelope "provider.connect.back"
    Escape _ -> navigate envelope True
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
      Right GuidedAccepted{guidedOutcome = InvokeNext} -> runNextFrom envelope
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

  paletteInput envelope query selected target = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Escape _ -> pure (Just (paletteReturnScreen envelope target))
    Backspace _
      | Text.length query <= 1 -> pure (Just (paletteReturnScreen envelope target))
      | otherwise -> pure . Just $ PaletteScreen envelope (Text.dropEnd 1 query) 0 target
    Printable character [] -> pure . Just $ PaletteScreen envelope (query <> Text.singleton character) 0 target
    ArrowUp _ -> pure . Just $ PaletteScreen envelope query (max 0 (selected - 1)) target
    ArrowDown _ -> pure . Just $ PaletteScreen envelope query (min (max 0 (length (filteredCommands envelope query) - 1)) (selected + 1)) target
    Enter _ -> runPaletteCommand envelope query selected target
    _ -> pure (Just screen)

  submitFeed envelope editor
    | Text.null (Text.strip material) = pure . Just $ FeedEditor envelope editor (Just "Feed material cannot be empty.")
    | otherwise =
        runCurrent (FeedCommand "repl" material) >>= \case
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
        runCurrent (SubmitInteractionTextCommand (interactionResponse envelope action) material) >>= \case
          Left problem -> pure . Just $ InteractionEditor envelope action editor (Just (appErrorMessage problem))
          Right result -> screenFromResult envelope result
   where
    material = editorText editor

  runNextFrom envelope =
    runCurrent NextCommand >>= \case
      Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
      Right NextResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
      Right other -> pure (Just (ReadOnlyScreen envelope (renderCommandResult other)))

  screenFromResult envelope = \case
    RespondResult{resultInteraction} -> refreshAndShow resultInteraction
    NextResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    FeedResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    RepairResult{resultInteraction} -> pure (Just (screenForEnvelope resultInteraction))
    other -> pure (Just (ReadOnlyScreen envelope (renderCommandResult other)))

  refreshAndShow envelope = case envelopeOpportunity envelope of
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

  runPaletteCommand envelope query selected target = case safeIndex selected (filteredCommands envelope query) of
    Nothing -> pure (Just (PaletteScreen envelope query selected target))
    Just command -> case commandOptionId command of
      "feed" -> pure (Just (FeedEditor envelope (EditorState "" "" Nothing) Nothing))
      "exit" -> pure Nothing
      "show" -> runShowCommand envelope command
      "help" -> pure (Just (paletteReadOnlyScreen envelope target helpText))
      "undo" -> runSimpleCommand envelope UndoCommand
      "redo" -> runSimpleCommand envelope RedoCommand
      "pause" -> runSimpleCommand envelope PauseCommand
      "history" -> runSimpleCommand envelope (HistoryCommand Nothing)
      "doctor" -> runSimpleCommand envelope DoctorCommand
      "packs" -> openPackManager envelope
      "import" -> openImportSourceSelector envelope Nothing
      "break" -> runBrickCommand envelope command BreakCommand
      "archive" -> runBrickCommand envelope command ArchiveCommand
      "restore" -> runBrickCommand envelope command RestoreCommand
      "translate" -> runSimpleCommand envelope (TranslateCommand Nothing)
      "tie-break" -> runSimpleCommand envelope TieBreakCommand
      _ -> pure (Just (EnvelopeScreen envelope (Just "That command is not implemented yet.")))

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
    Printable 'k' [] -> chooseImportMode envelope selection SourceSynchronize
    Printable 'm' [] -> chooseImportMode envelope selection SourceMigrate
    Printable '?' [] -> pure . Just $ ImportModeScreen envelope selection (Just "Snapshot copies what exists now. Keep synchronizing observes later changes. Migrate prepares a verified move away from the source; cleanup is always a later separate decision.")
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
    Printable '?' [] ->
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
      Right other -> pure (Just (ReadOnlyScreen envelope (renderCommandResult other)))

  packManagerInput envelope packs problem selected _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable 's' [] -> showSelectedPack envelope packs problem selected
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
              Right other -> pure (Just (ReadOnlyScreen envelope (renderCommandResult other)))

  showSelectedPack envelope packs problem selected = case safeIndex selected packs of
    Nothing -> pure (Just (PackManagerScreen envelope packs problem selected (Just "No Pack is selected.")))
    Just pack ->
      runCurrent (PacksShowCommand (projectedPackName pack)) >>= \case
        Left failure -> pure (Just (PackManagerScreen envelope packs problem selected (Just (appErrorMessage failure))))
        Right result -> pure (Just (PackDetailScreen envelope packs problem selected (renderCommandResult result)))

  packPathInput envelope purpose editor _ = \case
    Printable 'c' modifiers | MCtrl `elem` modifiers -> pure Nothing
    Printable character [] -> pure . Just $ PackPathEditor envelope purpose (applyEditorCommand (InsertText (Text.singleton character)) editor) Nothing
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
     in runCurrent (ShowRawCommand reference GuidedView) >>= \case
          Left problem -> pure (Just (EnvelopeScreen envelope (Just (appErrorMessage problem))))
          Right result -> pure (Just (ReadOnlyScreen envelope (renderCommandResult result)))

  runBrickCommand envelope command constructor =
    case Text.words (commandOptionCommand command) of
      _ : reference : _ -> runSimpleCommand envelope (constructor reference)
      _ -> pure (Just (EnvelopeScreen envelope (Just "Choose a Brick reference for this command.")))

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

refreshesPackRegistry :: Opportunity -> Bool
refreshesPackRegistry = \case
  PackInstallOpportunity{} -> True
  PackInstallResultOpportunity{} -> True
  PackTrustResultOpportunity{} -> True
  ProviderConnectionResultOpportunity{} -> True
  _ -> False

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
  _ -> EnvelopeScreen envelope Nothing

paletteReturnScreen :: InteractionEnvelope -> PaletteReturn -> ReplScreen
paletteReturnScreen envelope = \case
  ReturnToEnvelope -> screenForEnvelope envelope
  ReturnToPackManager packs problem selected -> PackManagerScreen envelope packs problem selected Nothing
  ReturnToImportMode selection -> ImportModeScreen envelope selection Nothing
  ReturnToImportContainers selection mode containers selected chosen -> ImportContainerScreen envelope selection mode containers selected chosen Nothing

paletteReadOnlyScreen :: InteractionEnvelope -> PaletteReturn -> Text -> ReplScreen
paletteReadOnlyScreen envelope target text = case target of
  ReturnToEnvelope -> ReadOnlyScreen envelope text
  ReturnToPackManager packs problem selected -> PackDetailScreen envelope packs problem selected text
  ReturnToImportMode selection -> ImportModeScreen envelope selection (Just text)
  ReturnToImportContainers selection mode containers selected chosen -> ImportContainerScreen envelope selection mode containers selected chosen (Just text)

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
  PackDetailScreen envelope _ _ _ text ->
    ScreenModel (fmap (pure . Span Normal) (Text.lines text) <> [[], [Span Dim "Press any key to return to Packs."], []] <> footerFrom width envelope) Nothing
  ImportSourceScreen envelope choices query selected message -> importSourceModelAtWidth width envelope choices query selected message
  ImportPathEditor envelope descriptor editor message -> importPathEditorModelAtWidth width envelope descriptor editor message
  ImportModeScreen envelope selection message -> importModeModelAtWidth width envelope selection message
  ImportContainerScreen envelope selection mode containers selected chosen message -> importContainerModelAtWidth width envelope selection mode containers selected chosen message
  ProviderConnectionEditor envelope definition stage editor message -> providerConnectionEditorModelAtWidth width envelope definition stage editor message
  ReadOnlyScreen envelope text ->
    ScreenModel (fmap (pure . Span Normal) (Text.lines text) <> [[], [Span Dim "Press any key to return."], []] <> footerFrom width envelope) Nothing

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
  joinedActions =
    actionSpans "s" "show"
      <> [Span Normal "   "]
      <> actionSpans "i" "install..."
      <> [Span Normal "   "]
      <> actionSpans "r" "refresh catalog"
      <> [Span Normal "   "]
      <> actionSpans "t" "trust publisher..."
  actionRows
    | Text.length (plainLine joinedActions) <= width = [joinedActions, actionSpans "/" "more..."]
    | otherwise = [actionSpans "s" "show", actionSpans "i" "install...", actionSpans "r" "refresh catalog", actionSpans "t" "trust publisher...", actionSpans "/" "more..."]
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
        <> [actionSpans "?" "I don't know"]
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
        <> [actionSpans "?" "I don't know", actionSpans "/" "more...", []]
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
  SourceSynchronize -> "k"
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
        <> [[], [Span Normal "› ", Span Normal (editorBefore editor), Span Selected (fromMaybe " " (editorSelection editor)), Span Normal (editorAfter editor)]]
        <> maybe [] (\problem -> [] : fmap (pure . Span Warning) (wrapWords (max 20 width) problem)) message
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

wrapWords :: Int -> Text -> [Text]
wrapWords width text
  | Text.length text <= width = [text]
  | otherwise = go [] "" (Text.words text)
 where
  go result current [] = result <> [current | not (Text.null current)]
  go result current (word : rest)
    | Text.null current = go result word rest
    | Text.length current + 1 + Text.length word <= width = go result (current <> " " <> word) rest
    | otherwise = go (result <> [current]) word rest

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
helpText = "Little Ant shows one useful opportunity at a time.\n\nUse the visible keys or return with Escape."

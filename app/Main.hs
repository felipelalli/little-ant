-- | The two v1 executable aliases.  Parsing and rendering live here; every
-- mutation/query is delegated to the typed protocols in 'LittleAnt.V1.CLI'.
module Main (main) where

import Control.Exception (bracket_)
import Control.Monad (unless)
import Data.Aeson (ToJSON (toJSON), Value, encode)
import qualified Data.Aeson.Encode.Pretty as Pretty
import qualified Data.ByteString.Lazy.Char8 as LBS8
import Data.List (find)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Time (UTCTime, getCurrentTime)
import LittleAnt.Store (resolveDataDir)
import LittleAnt.V1.CLI
import LittleAnt.V1.Interaction
  (InteractionAction (..), InteractionEnvelope (..),
   InteractionError (..), InteractionId (..),
   OperationalResponse (..), ProjectionKind (..), StatusSummary (..),
   operationalResponseProjection)
import LittleAnt.V1.ReadModel
  (HistoryBrief, HistoryPage (..), HistoryQuery (..), HistoryRelevance,
   SemanticActionSummary (..), commandFailure)
import Options.Applicative hiding (action)
import System.Exit (ExitCode (..), exitWith)
import System.IO
  (BufferMode (..), hGetBuffering, hGetEcho, hIsEOF, hIsTerminalDevice,
   hSetBuffering, hSetEcho, stderr, stdin)

------------------------------------------------------------
-- Grammar
------------------------------------------------------------

data Global = Global
  { globalJson :: Bool
  , globalDataDirectory :: Maybe FilePath
  }

data Command
  = Capture Text
  | Complete Text Integer
  | Project ProjectionKind (Maybe Text)
  | Status
  | History HistoryOptions
  | Interaction InteractionCommand
  | Repl ReplOptions

data HistoryOptions = HistoryOptions
  { historyOptionPageSize :: Integer
  , historyOptionCursor :: Maybe Text
  , historyOptionBrief :: Bool
  }

data InteractionCommand
  = InteractionOpen Text
  | InteractionCurrent InteractionId
  | InteractionSubmit InteractionId Text Integer Integer
  | InteractionHelp InteractionId
  | InteractionRebase InteractionId
  | InteractionComplete InteractionId
  | InteractionAbandon InteractionId
  | InteractionResume Text

data ReplOptions = ReplOptions
  { replOptionPowerUp :: Maybe FilePath
  , replOptionSurface :: Text
  }

options :: ParserInfo (Global, Command)
options = info (((,) <$> globalParser <*> commandParser) <**> helper)
  (fullDesc
    <> header "la / lant - Little Ant 1.0"
    <> progDesc "Canonical v1 commands and deterministic guided interaction")

globalParser :: Parser Global
globalParser = Global
  <$> switch (long "json" <> help "emit the typed machine-readable projection")
  <*> optional (strOption
        (long "data" <> metavar "DIR" <> help "isolated Little Ant data directory"))

commandParser :: Parser Command
commandParser = hsubparser (mconcat
  [ command "capture" (info captureParser
      (progDesc "capture one canonical active Brick"))
  , command "complete" (info completeParser
      (progDesc "complete a Brick with an optimistic revision precondition"))
  , command "project" (info projectParser
      (progDesc "query a purpose-bounded canonical projection"))
  , command "status" (info (pure Status)
      (progDesc "show the one canonical status summary"))
  , command "history" (info historyParser
      (progDesc "query bounded semantic-action history"))
  , command "interaction" (info interactionParser
      (progDesc "operate a revision-scoped interaction"))
  , command "repl" (info replParser
      (progDesc "start the deterministic v1 interaction harness"))
  ])

captureParser :: Parser Command
captureParser = Capture . Text.pack <$> strArgument
  (metavar "TITLE" <> help "canonical English title")

completeParser :: Parser Command
completeParser = Complete
  <$> textArgument "BRICK_ID"
  <*> option auto
      (long "expected-revision" <> metavar "N"
        <> help "current DomainClock revision")

projectParser :: Parser Command
projectParser = Project
  <$> option (eitherReader parseProjection)
      (long "projection" <> short 'p' <> value ProjectionOperational
        <> metavar "summary|operational|relationships|history|complete")
  <*> optional (textArgument "REFERENCE")

historyParser :: Parser Command
historyParser = History <$> (HistoryOptions
  <$> option auto (long "page-size" <> value 20 <> metavar "1..100")
  <*> optional (textOption "cursor" "revision-bound page cursor")
  <*> switch (long "brief" <> help "return a traceable derived brief"))

interactionParser :: Parser Command
interactionParser = Interaction <$> hsubparser (mconcat
  [ command "open" (info
      (InteractionOpen <$> textOptionDefault "kind" "priority_comparison"
        "deterministic interaction kind")
      (progDesc "open a new guided interaction"))
  , command "current" (info
      (InteractionCurrent <$> interactionArgument)
      (progDesc "return the current revision-bearing envelope"))
  , command "submit" (info
      (InteractionSubmit
        <$> interactionArgument
        <*> textArgument "ACTION_ID"
        <*> option auto (long "domain-revision" <> metavar "N")
        <*> option auto (long "interaction-revision" <> metavar "N"))
      (progDesc "submit one exact state-scoped action ID"))
  , command "help" (info
      (InteractionHelp <$> interactionArgument)
      (progDesc "show contextual help without answering"))
  , command "rebase" (info
      (InteractionRebase <$> interactionArgument)
      (progDesc "rebase a stale interaction without reusing its key"))
  , command "complete" (info
      (InteractionComplete <$> interactionArgument)
      (progDesc "finish an open interaction"))
  , command "abandon" (info
      (InteractionAbandon <$> interactionArgument)
      (progDesc "abandon an open or stale interaction"))
  , command "resume" (info
      (InteractionResume <$> textOptionDefault "surface" "terminal"
        "saved surface identity")
      (progDesc "restore the exact saved interaction checkpoint"))
  ])

replParser :: Parser Command
replParser = Repl <$> (ReplOptions
  <$> optional (strOption
        (long "power-up" <> metavar "EXECUTABLE"
          <> help "validate a protocol-v1 model adapter through stdin"))
  <*> textOptionDefault "surface" "terminal" "checkpoint surface identity")

interactionArgument :: Parser InteractionId
interactionArgument = InteractionId <$> textArgument "INTERACTION_ID"

textArgument :: String -> Parser Text
textArgument name = Text.pack <$> strArgument (metavar name)

textOption :: String -> String -> Parser Text
textOption name description = Text.pack <$> strOption
  (long name <> metavar (map dashToUnderscore name) <> help description)
  where
    dashToUnderscore '-' = '_'
    dashToUnderscore character = character

textOptionDefault :: String -> Text -> String -> Parser Text
textOptionDefault name fallback description = Text.pack <$> strOption
  (long name <> value (Text.unpack fallback) <> showDefault
    <> help description)

parseProjection :: String -> Either String ProjectionKind
parseProjection candidate = case candidate of
  "summary" -> Right ProjectionSummary
  "operational" -> Right ProjectionOperational
  "relationships" -> Right ProjectionRelationships
  "history" -> Right ProjectionHistory
  "complete" -> Right ProjectionComplete
  _ -> Left "projection must be summary, operational, relationships, history, or complete"

------------------------------------------------------------
-- Driver
------------------------------------------------------------

main :: IO ()
main = do
  (global, commandValue) <- execParser options
  directory <- resolveDataDir (globalDataDirectory global)
  loaded <- loadCliState directory
  case loaded of
    Left problem -> fatalText global "storage_error" problem
    Right state -> case commandValue of
      Repl replOptions -> runRepl global directory replOptions state
      _ -> runCommand global directory state commandValue

runCommand :: Global -> FilePath -> CliState -> Command -> IO ()
runCommand global directory before commandValue = do
  now <- getCurrentTime
  case commandValue of
    Capture title -> do
      let (response, after) = captureBrick title now before
      persistAndEmitResponse global directory before after response
    Complete identifier revision -> do
      let (response, after) = completeBrick identifier revision now before
      persistAndEmitResponse global directory before after response
    Project kind reference -> case projectCliState kind reference before of
      Left problem -> emitFailure global before "projection_failed" problem Nothing
      Right projectionValue -> emitProjection global projectionValue
        "projection returned"
    Status -> emitStatus global (statusFor before)
    History historyOptions -> runHistory global before historyOptions
    Interaction interactionCommand ->
      runInteractionCommand global directory now before interactionCommand
    Repl _ -> fatalText global "internal_error" "REPL dispatch was duplicated."

runHistory :: Global -> CliState -> HistoryOptions -> IO ()
runHistory global state optionsValue =
  let query = defaultHistoryQuery
        { historyQueryPageSize = historyOptionPageSize optionsValue
        , historyQueryCursor = historyOptionCursor optionsValue
        }
  in if historyOptionBrief optionsValue
      then case historyBriefFor query state of
        Left problem -> emitFailure global state "history_query_failed"
          (Text.pack (show problem)) Nothing
        Right brief -> emitHistoryBrief global brief
      else case historyPageFor query state of
        Left problem -> emitFailure global state "history_query_failed"
          (Text.pack (show problem)) Nothing
        Right page -> emitHistoryPage global page

runInteractionCommand ::
  Global -> FilePath -> UTCTime -> CliState -> InteractionCommand -> IO ()
runInteractionCommand global directory now before interactionCommand =
  case interactionCommand of
    InteractionOpen kind -> persistEnvelope
      (openCliInteraction kind now before)
    InteractionCurrent identifier -> emitEnvelopeResult
      (currentCliInteraction identifier before)
    InteractionSubmit identifier action domainRevision interactionRevision ->
      case submitCliInteraction identifier domainRevision interactionRevision
          action now before of
        Left problem -> interactionFailure problem
        Right (response, after) ->
          persistAndEmitResponse global directory before after response
    InteractionHelp identifier -> emitEnvelopeResult
      (requestCliInteractionHelp identifier before)
    InteractionRebase identifier -> persistEnvelope
      (rebaseCliInteraction identifier now before)
    InteractionComplete identifier -> persistSession
      (completeCliInteraction identifier now before) "interaction completed"
    InteractionAbandon identifier -> persistSession
      (abandonCliInteraction identifier now before) "interaction abandoned"
    InteractionResume surface -> emitEnvelopeResult
      (resumeCliInteraction surface before)
  where
    persistEnvelope result = case result of
      Left problem -> interactionFailure problem
      Right (envelope, after) -> do
        persisted <- saveCliState directory before after
        either (fatalText global "storage_error")
          (const (emitEnvelope global envelope)) persisted
    persistSession result human = case result of
      Left problem -> interactionFailure problem
      Right (session, after) -> do
        persisted <- saveCliState directory before after
        either (fatalText global "storage_error")
          (const (emitTyped global session human)) persisted
    emitEnvelopeResult = either interactionFailure (emitEnvelope global)
    interactionFailure problem = emitFailure global before "interaction_error"
      (Text.pack (show problem)) (Just "Reload or rebase the interaction.")

defaultHistoryQuery :: HistoryQuery
defaultHistoryQuery = HistoryQuery
  { historyQueryFrom = Nothing
  , historyQueryThrough = Nothing
  , historyQueryBrickIds = []
  , historyQueryRelatedEntityIds = []
  , historyQueryScopeIds = []
  , historyQueryActorIds = []
  , historyQueryOrigins = []
  , historyQueryActionFamilies = []
  , historyQueryMinimumRelevance = Nothing :: Maybe HistoryRelevance
  , historyQueryCursor = Nothing
  , historyQueryPageSize = 20
  }

------------------------------------------------------------
-- REPL
------------------------------------------------------------

runRepl :: Global -> FilePath -> ReplOptions -> CliState -> IO ()
runRepl global directory replOptions initial = do
  prepared <- prepareMode directory replOptions initial
  case prepared of
    Left problem -> fatalText global "invalid_powered_up_adapter" problem
    Right state -> do
      now <- getCurrentTime
      let surface = replOptionSurface replOptions
      opened <- case resumeCliInteraction surface state of
        Right envelope -> pure (Right (envelope, state, ["resumed " <> surface]))
        Left (CheckpointDoesNotExist _) -> pure $ do
          (envelope, next) <- firstInteraction
            (openCliInteraction "priority_comparison" now state)
          pure (envelope, next, ["opened " <> surface])
        Left problem -> pure (Left (Text.pack (show problem)))
      case opened of
        Left problem -> fatalText global "interaction_error" problem
        Right (envelope, next, transcript) -> do
          persisted <- saveCliState directory state next
          case persisted of
            Left problem -> fatalText global "storage_error" problem
            Right () -> withInputMode (replLoop global directory surface
              transcript envelope next)
  where
    firstInteraction = either (Left . Text.pack . show) Right

prepareMode ::
  FilePath -> ReplOptions -> CliState -> IO (Either Text CliState)
prepareMode directory optionsValue before = case replOptionPowerUp optionsValue of
  Just executable -> do
    powered <- powerUpCli executable before
    case powered of
      Left problem -> pure (Left (Text.pack (show problem)))
      Right (response, after)
        | not (operationalResponseOk response) ->
            pure (Left (operationalResponseHuman response))
        | otherwise -> do
            saved <- saveCliState directory before after
            pure (after <$ saved)
  Nothing -> case statusSummaryMode (statusFor before) of
    "powered_up" -> case useDumbCli before of
      Left problem -> pure (Left (Text.pack (show problem)))
      Right after -> do
        saved <- saveCliState directory before after
        pure (after <$ saved)
    _ -> pure (Right before)

withInputMode :: IO value -> IO value
withInputMode action = do
  terminal <- hIsTerminalDevice stdin
  if not terminal
    then action
    else do
      oldBuffering <- hGetBuffering stdin
      oldEcho <- hGetEcho stdin
      bracket_
        (hSetBuffering stdin NoBuffering >> hSetEcho stdin False)
        (hSetEcho stdin oldEcho >> hSetBuffering stdin oldBuffering)
        action

replLoop ::
  Global -> FilePath -> Text -> [Text] -> InteractionEnvelope -> CliState -> IO ()
replLoop global directory surface transcript envelope state = do
  now <- getCurrentTime
  let withCheckpoint = checkpointInteraction surface "prompt" transcript
        envelope now state
  checkpointed <- case withCheckpoint of
    Left problem -> fatalText global "checkpoint_error" (Text.pack (show problem))
    Right next -> pure next
  saved <- saveCliState directory state checkpointed
  case saved of
    Left problem -> fatalText global "storage_error" problem
    Right () -> do
      renderReplFrame envelope checkpointed
      eof <- hIsEOF stdin
      unless eof $ do
        input <- getChar
        case input of
          'q' -> TextIO.putStrLn "bye"
          '\n' -> replLoop global directory surface transcript envelope checkpointed
          '\r' -> replLoop global directory surface transcript envelope checkpointed
          '?' -> do
            case requestCliInteractionHelp
                (interactionEnvelopeInteractionId envelope) checkpointed of
              Left problem -> TextIO.putStrLn ("error: " <> Text.pack (show problem))
              Right helped -> TextIO.putStrLn
                (fromMaybe "No contextual help." (interactionEnvelopeHelp helped))
            replLoop global directory surface (transcript <> ["help"])
              envelope checkpointed
          '/' -> do
            commandLine <- Text.strip . Text.pack <$> getLine
            handleReplCommand global directory surface transcript envelope
              checkpointed commandLine
          key -> case find ((== Text.singleton key) . interactionActionShortcut)
              (interactionEnvelopeActions envelope) of
            Nothing -> do
              TextIO.putStrLn "unknown key (? for help, / for commands, q to quit)"
              replLoop global directory surface transcript envelope checkpointed
            Just selectedAction -> submitReplAction global directory surface transcript
              envelope selectedAction

handleReplCommand ::
  Global -> FilePath -> Text -> [Text] -> InteractionEnvelope -> CliState ->
  Text -> IO ()
handleReplCommand global directory surface transcript envelope state commandLine =
  case commandLine of
    "quit" -> TextIO.putStrLn "bye"
    "status" -> do
      emitStatus global (statusFor state)
      replLoop global directory surface (transcript <> ["status"])
        envelope state
    "history" -> do
      runHistory global state (HistoryOptions 5 Nothing False)
      replLoop global directory surface (transcript <> ["history"])
        envelope state
    "help" -> do
      TextIO.putStrLn (fromMaybe "No contextual help."
        (interactionEnvelopeHelp envelope))
      replLoop global directory surface (transcript <> ["help"])
        envelope state
    "resume" -> case resumeCliInteraction surface state of
      Left problem -> do
        TextIO.putStrLn ("resume failed: " <> Text.pack (show problem))
        replLoop global directory surface transcript envelope state
      Right resumed -> replLoop global directory surface
        (transcript <> ["resumed " <> surface]) resumed state
    _ -> do
      TextIO.putStrLn "commands: /status /history /help /resume /quit"
      replLoop global directory surface transcript envelope state

submitReplAction ::
  Global -> FilePath -> Text -> [Text] -> InteractionEnvelope ->
  InteractionAction -> IO ()
submitReplAction global directory surface transcript envelope selectedAction = do
  latestResult <- loadCliState directory
  case latestResult of
    Left problem -> fatalText global "storage_error" problem
    Right latest -> do
      now <- getCurrentTime
      let identifier = interactionEnvelopeInteractionId envelope
      case submitCliInteraction identifier
          (interactionEnvelopeDomainRevision envelope)
          (interactionEnvelopeInteractionRevision envelope)
          (interactionActionId selectedAction) now latest of
        Left problem -> fatalText global "interaction_error" (Text.pack (show problem))
        Right (response, after) -> do
          saved <- saveCliState directory latest after
          case saved of
            Left problem -> fatalText global "storage_error" problem
            Right () -> do
              TextIO.putStrLn ("$ "
                <> interactionActionCanonicalCommand selectedAction)
              TextIO.putStrLn (operationalResponseHuman response)
              if operationalResponseOk response
                then nextEnvelope after response
                else do
                  let rebased = rebaseCliInteraction identifier now after
                  case rebased of
                    Left problem -> fatalText global "interaction_error"
                      (Text.pack (show problem))
                    Right (next, rebasedState) -> do
                      savedRebase <- saveCliState directory after rebasedState
                      case savedRebase of
                        Left problem -> fatalText global "storage_error" problem
                        Right () -> replLoop global directory surface
                          (transcript <> [operationalResponseHuman response])
                          next rebasedState
  where
    nextEnvelope after response = case currentCliInteraction
        (interactionEnvelopeInteractionId envelope) after of
      Left problem -> fatalText global "interaction_error" (Text.pack (show problem))
      Right next -> replLoop global directory surface
        (transcript <> [operationalResponseHuman response]) next after

renderReplFrame :: InteractionEnvelope -> CliState -> IO ()
renderReplFrame envelope state = do
  TextIO.putStrLn (statusSummaryHuman (statusFor state))
  TextIO.putStrLn ("interaction "
    <> unInteractionId (interactionEnvelopeInteractionId envelope)
    <> " · domain " <> showText (interactionEnvelopeDomainRevision envelope)
    <> " · prompt " <> showText (interactionEnvelopeInteractionRevision envelope))
  TextIO.putStrLn (interactionEnvelopePrompt envelope)
  mapM_ renderAction (interactionEnvelopeActions envelope)
  TextIO.putStrLn "[?] help  [/] commands  [q] quit"
  where
    renderAction availableAction = TextIO.putStrLn
      ("[" <> interactionActionShortcut availableAction <> "] "
        <> interactionActionLabel availableAction <> " — $ "
        <> interactionActionCanonicalCommand availableAction)

------------------------------------------------------------
-- Rendering and exits
------------------------------------------------------------

persistAndEmitResponse ::
  Global -> FilePath -> CliState -> CliState -> OperationalResponse -> IO ()
persistAndEmitResponse global directory before after response = do
  saved <- saveCliState directory before after
  case saved of
    Left problem -> fatalText global "storage_error" problem
    Right () -> emitResponse global response

emitResponse :: Global -> OperationalResponse -> IO ()
emitResponse global response = do
  if globalJson global
    then emitJson (operationalResponseProjection response)
    else if operationalResponseOk response
      then TextIO.putStrLn (operationalResponseHuman response)
      else TextIO.hPutStrLn stderr (operationalResponseHuman response)
  unless (operationalResponseOk response) (exitWith (ExitFailure 2))

emitFailure ::
  Global -> CliState -> Text -> Text -> Maybe Text -> IO value
emitFailure global state code human hint = do
  emitResponse global (commandFailure code human hint [] (cliKernelState state))
  exitWith (ExitFailure 2)

fatalText :: Global -> Text -> Text -> IO value
fatalText global code human = do
  if globalJson global
    then emitJson (operationalResponseProjection (OperationalResponse
      False human Nothing Nothing [] [] (Just code) Nothing Nothing 0))
    else TextIO.hPutStrLn stderr ("error (" <> code <> "): " <> human)
  exitWith (ExitFailure 2)

emitProjection :: Global -> Value -> Text -> IO ()
emitProjection global projectionValue human
  | globalJson global = emitJson projectionValue
  | otherwise = TextIO.putStrLn human

emitStatus :: Global -> StatusSummary -> IO ()
emitStatus global summary
  | globalJson global = emitJson (toJSON summary)
  | otherwise = TextIO.putStrLn (statusSummaryHuman summary)

emitEnvelope :: Global -> InteractionEnvelope -> IO ()
emitEnvelope global envelope
  | globalJson global = emitJson (toJSON envelope)
  | otherwise = do
      TextIO.putStrLn (interactionEnvelopePrompt envelope)
      mapM_ (TextIO.putStrLn . interactionActionCanonicalCommand)
        (interactionEnvelopeActions envelope)

emitTyped :: ToJSON value => Global -> value -> Text -> IO ()
emitTyped global typedValue human
  | globalJson global = emitJson (toJSON typedValue)
  | otherwise = TextIO.putStrLn human

emitHistoryPage :: Global -> HistoryPage -> IO ()
emitHistoryPage global page
  | globalJson global = emitJson (toJSON page)
  | otherwise = if null (historyPageItems page)
      then TextIO.putStrLn "No semantic actions."
      else mapM_ renderHistoryItem (historyPageItems page)
  where
    renderHistoryItem item = TextIO.putStrLn
      (showText (semanticActionSummaryDomainRevision item) <> " · "
        <> semanticActionSummaryActorOrOrigin item <> " · "
        <> semanticActionSummaryOutcome item <> " · "
        <> semanticActionSummarySummary item)

emitHistoryBrief :: Global -> HistoryBrief -> IO ()
emitHistoryBrief global brief
  | globalJson global = emitJson (toJSON brief)
  | otherwise = LBS8.putStrLn (encode brief)

emitJson :: Value -> IO ()
emitJson = LBS8.putStrLn . Pretty.encodePretty'
  Pretty.defConfig {Pretty.confIndent = Pretty.Spaces 2}

showText :: Show value => value -> Text
showText = Text.pack . show

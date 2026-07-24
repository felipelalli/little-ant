-- | The @la@ CLI. Designed for an LLM operator first: @--json@ everywhere,
-- stable output schemas, @--dry-run@, semantic exit codes, and error
-- messages that teach correct usage.
--
-- Every invocation auto-ticks: temporal rules (dangling WIP, stale
-- comparisons, due nudges, taxonomy review) fire lazily and their events are
-- appended before the command runs (skipped under @--dry-run@).
module Main (main) where

import Data.Aeson (Value (..), object, toJSON, (.=))
import qualified Data.Aeson.Encode.Pretty as Pretty
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Time (UTCTime, getCurrentTime)
import Options.Applicative
import System.Exit
import System.IO (hPutStrLn, stderr)

import LittleAnt.Command
import LittleAnt.Config
import LittleAnt.Event
import LittleAnt.Grammar (grammarHuman, grammarView)
import LittleAnt.Ids (shortId, unId)
import LittleAnt.Order
  (SortOutcome (..), mergeSortStep, orderQuestions, placeBrick)
import LittleAnt.Render
import LittleAnt.Scheduler
import LittleAnt.State
import LittleAnt.Store
import LittleAnt.Tick (dueBodies)
import LittleAnt.Types
import LittleAnt.Views

-- --------------------------------------------------------------------------
-- CLI grammar
-- --------------------------------------------------------------------------

data Global = Global
  { gJson :: Bool
  , gDataDir :: Maybe FilePath
  , gDryRun :: Bool
  }

data Cmd
  = CPartyAdd Text Text
  | CPartyLs
  | CCapture Text
  | CRawAdd Text
  | CRawLs
  | CExtract Text [Text]
  | CPromote Text
  | CKill Text
  | CReady Text
  | CRequester Text Text
  | CSet Text (Maybe Text) (Maybe Text) (Maybe Double) (Maybe Text) (Maybe Text) (Maybe Double) (Maybe Text) (Maybe Text)
  | CBreak Text [Text]
  | CUnify Text Text (Maybe Text)
  | CSupersede Text Text (Maybe Text)
  | CSessionOpen (Maybe Text) Text
  | CSessionClose (Maybe Text)
  | CSessionLs
  | CNext (Maybe Text)
  | CStart Text
  | CStop Text
  | CDone Text
  | CSkip Text Text (Maybe Text)
  | CClarify Text Text
  | CWaitAdd Text (Maybe Text) (Maybe Text)
  | CWaitResolve Text
  | CWaitLs
  | CDepAdd Text Text
  | CCompare Text Text Text
  | COrder Bool Int (Maybe Text) Bool
  | CExportTj Double
  | CDelegate Text Text
  | CDelegLs
  | CDelegNotice Text
  | CDelegCancel Text
  | CDelegOutcome Text Text
  | CNudgeApprove Text
  | CNudgeDecline Text
  | CEffectAdd Text Text Text
  | CEffectApprove Text
  | CEffectDecline Text
  | CEffectLs
  | CSourceAttach Text Text Text
  | CSourceCheck Text Text
  | CSourceResolve Text Text
  | CSourceLs
  | CLs (Maybe Text) Bool
  | CShow Text
  | CStatus
  | CGrammar
  | CMigrate
  | CTick
  | CRender Text
  | CEvents (Maybe Int)

textArg :: String -> String -> Parser Text
textArg name h = strArgument (metavar name <> help h)

textOpt :: String -> String -> Parser Text
textOpt name h = strOption (long name <> metavar (map toUpperSnake name) <> help h)
  where toUpperSnake c = if c == '-' then '_' else toUpper' c
        toUpper' ch = if ch >= 'a' && ch <= 'z'
                        then toEnum (fromEnum ch - 32) else ch

optTextOpt :: String -> String -> Parser (Maybe Text)
optTextOpt name h = optional (textOpt name h)

pCmd :: Parser Cmd
pCmd = hsubparser $ mconcat
  [ command "capture" $ info
      (CCapture <$> textArg "TITLE" "capture a seed — a title and nothing else")
      (progDesc "Capture a seed into the idea bucket")
  , command "raw" $ info
      (hsubparser $ mconcat
        [ command "add" $ info
            (CRawAdd <$> textArg "CONTENT" "raw material to extract later")
            (progDesc "Capture raw input (brainstorm, pasted conversation)")
        , command "ls" $ info (pure CRawLs) (progDesc "List raw inputs")
        ])
      (progDesc "Raw input (pre-brick material)")
  , command "extract" $ info
      (CExtract
        <$> textArg "RAW" "raw input ref"
        <*> many (strOption (long "seed" <> metavar "TITLE"
                             <> help "seed title (repeatable; zero is valid)")))
      (progDesc "Extract 0..n seeds from a raw input")
  , command "promote" $ info
      (CPromote <$> textArg "BRICK" "seed ref")
      (progDesc "Promote a seed to committed")
  , command "kill" $ info
      (CKill <$> textArg "BRICK" "brick ref")
      (progDesc "Drop a brick (shouldn't exist / obsolete)")
  , command "ready" $ info
      (CReady <$> textArg "BRICK" "brick ref")
      (progDesc "Mark a committed brick ready to be served")
  , command "requester" $ info
      (CRequester
        <$> textArg "BRICK" "brick ref"
        <*> textArg "PARTY" "party ref or name")
      (progDesc "Attribute who asked for this brick")
  , command "set" $ info
      (CSet
        <$> textArg "BRICK" "brick ref"
        <*> optional (strOption (long "kind"
              <> metavar "spec|exec|delegation|decision|meta"))
        <*> optTextOpt "context" "namespaced context (e.g. acme/api)"
        <*> optional (option auto (long "energy" <> metavar "0..1"))
        <*> optional (strOption (long "mode" <> metavar "digital|physical"))
        <*> optional (strOption (long "atomicity"
              <> metavar "atomic|divisible|unknown"))
        <*> optional (option auto (long "estimate" <> metavar "HOURS"
              <> help "effort estimate in hours"))
        <*> optional (strOption (long "estimate-by" <> metavar "human|ai"
              <> help "who estimated (default human; guesses are marked)"))
        <*> optTextOpt "desc"
              "longer body/description (content, not identity)")
      (progDesc "Enrich a brick lazily (never a form — metadata in drips)")
  , command "break" $ info
      (CBreak
        <$> textArg "BRICK" "brick ref"
        <*> some (strOption (long "part" <> metavar "TITLE"
                             <> help "part title (repeatable)")))
      (progDesc "Break a brick into smaller bricks")
  , command "unify" $ info
      (CUnify
        <$> textArg "BRICK" "brick to absorb"
        <*> textOpt "into" "surviving brick ref"
        <*> optTextOpt "reason" "why they are the same")
      (progDesc "Unify two bricks (the first is superseded by the second)")
  , command "supersede" $ info
      (CSupersede
        <$> textArg "BRICK" "brick ref"
        <*> textOpt "with" "replacement title"
        <*> optTextOpt "reason" "why the method changed")
      (progDesc "Replace the method, keep the goal (inherits slot & lineage)")
  , command "session" $ info
      (hsubparser $ mconcat
        [ command "open" $ info
            (CSessionOpen
              <$> optTextOpt "context" "sticky context hint (e.g. acme/api)"
              <*> strOption (long "strictness" <> value "prefer"
                             <> metavar "ignore|prefer|require"
                             <> help "context strictness (default: prefer)"))
            (progDesc "Open a focus session")
        , command "close" $ info
            (CSessionClose <$> optional (textArg "SESSION" "session ref"))
            (progDesc "Close a focus session (default: latest open)")
        , command "ls" $ info (pure CSessionLs) (progDesc "List sessions")
        ])
      (progDesc "Focus sessions")
  , command "next" $ info
      (CNext <$> optional (strOption (long "session" <> metavar "SESSION")))
      (progDesc "Where should I focus now?")
  , command "start" $ info
      (CStart <$> textArg "BRICK" "brick ref")
      (progDesc "Start working on a brick")
  , command "stop" $ info
      (CStop <$> textArg "BRICK" "brick ref")
      (progDesc "Stop working on a brick (back to ready)")
  , command "done" $ info
      (CDone <$> textArg "BRICK" "brick ref")
      (progDesc "Complete a brick (fires its completion effects)")
  , command "skip" $ info
      (CSkip
        <$> textArg "BRICK" "brick ref"
        <*> strOption (long "reason"
              <> metavar "hard|vague|not_priority|waiting|tired|meh|kill|alternatives|other"
              <> help "why (a skip is never a bare dismissal)")
        <*> optTextOpt "text" "the raw utterance (always preserved)")
      (progDesc "Skip a served brick — with a reason")
  , command "clarify" $ info
      (CClarify
        <$> textArg "BRICK" "vague brick ref"
        <*> textOpt "title" "title of the clarify meta-brick")
      (progDesc "Defer clarification of a vague brick to a meta-brick")
  , command "wait" $ info
      (hsubparser $ mconcat
        [ command "add" $ info
            (CWaitAdd
              <$> textArg "BRICK" "brick ref"
              <*> optTextOpt "party" "who the world is waiting on"
              <*> optTextOpt "condition" "world condition (place, hours...)")
            (progDesc "Record a wait (person or world condition)")
        , command "resolve" $ info
            (CWaitResolve <$> textArg "WAIT" "wait ref")
            (progDesc "Resolve a wait")
        , command "ls" $ info (pure CWaitLs) (progDesc "List waits")
        ])
      (progDesc "Waits (waiting on a brick? use `la dep add`)")
  , command "dep" $ info
      (hsubparser $ mconcat
        [ command "add" $ info
            (CDepAdd
              <$> textArg "BLOCKED" "brick that must wait"
              <*> textOpt "on" "brick that must come first")
            (progDesc "Add a dependency (kept acyclic)")
        ])
      (progDesc "Dependencies")
  , command "compare" $ info
      (CCompare
        <$> textArg "EARLIER" "brick that should be done first"
        <*> textArg "LATER" "brick that should be done after"
        <*> strOption (long "author" <> value "human"
                       <> metavar "human|ai"
                       <> help "who judged (default: human)"))
      (progDesc "Record a pairwise comparison: EARLIER before LATER")
  , command "order" $ info
      (COrder
        <$> switch (long "questions"
                    <> help "propose the most informative pairs to ask")
        <*> option auto (long "limit" <> value 3 <> metavar "N"
                         <> help "max questions (default 3)")
        <*> optional (strOption (long "place" <> metavar "BRICK"
              <> help "binary-insertion placement: the next question for ONE brick"))
        <*> switch (long "sort"
              <> help "bulk sort (org-sort-tasks strategy): the next question, or the settled order"))
      (progDesc "Show the frontier's total order (or the open questions)")
  , command "export" $ info
      (hsubparser $ mconcat
        [ command "tj" $ info
            (CExportTj
              <$> option auto (long "default-effort" <> value 4
                    <> metavar "HOURS"
                    <> help "effort for bricks with no estimate (marked as gap)"))
            (progDesc "Emit a TaskJuggler 3 project (feed to tj3 to simulate)")
        ])
      (progDesc "Exports (projections into other tools)")
  , command "delegate" $ info
      (CDelegate
        <$> textArg "BRICK" "brick ref"
        <*> textOpt "to" "party ref or name")
      (progDesc "Delegate a brick to someone (notice is proposed, not sent)")
  , command "delegation" $ info
      (hsubparser $ mconcat
        [ command "ls" $ info (pure CDelegLs) (progDesc "List delegations")
        , command "notice" $ info
            (CDelegNotice <$> textArg "DELEGATION" "delegation ref")
            (progDesc "Approve the delegation notice (content was previewed)")
        , command "cancel" $ info
            (CDelegCancel <$> textArg "DELEGATION" "delegation ref")
            (progDesc "Cancel a delegation before notifying")
        , command "done" $ info
            (flip CDelegOutcome "completed" <$> textArg "DELEGATION" "ref")
            (progDesc "The delegate completed it")
        , command "refused" $ info
            (flip CDelegOutcome "refused" <$> textArg "DELEGATION" "ref")
            (progDesc "The delegate refused it")
        , command "abandoned" $ info
            (flip CDelegOutcome "abandoned" <$> textArg "DELEGATION" "ref")
            (progDesc "Give up on this delegation")
        ])
      (progDesc "Delegations and follow-ups")
  , command "nudge" $ info
      (hsubparser $ mconcat
        [ command "approve" $ info
            (CNudgeApprove <$> textArg "DELEGATION" "delegation ref")
            (progDesc "Approve the due nudge (content was previewed)")
        , command "decline" $ info
            (CNudgeDecline <$> textArg "DELEGATION" "delegation ref")
            (progDesc "Skip this nudge; re-ask next interval")
        ])
      (progDesc "Follow-up nudges")
  , command "effect" $ info
      (hsubparser $ mconcat
        [ command "add" $ info
            (CEffectAdd
              <$> textArg "BRICK" "brick ref"
              <*> strOption (long "kind" <> metavar "write_back|notify|spawn")
              <*> textOpt "detail" "what should happen on completion")
            (progDesc "Arm an on-done effect")
        , command "approve" $ info
            (CEffectApprove <$> textArg "EFFECT" "effect ref")
            (progDesc "Approve a proposed external action")
        , command "decline" $ info
            (CEffectDecline <$> textArg "EFFECT" "effect ref")
            (progDesc "Decline a proposed external action")
        , command "ls" $ info (pure CEffectLs) (progDesc "List effects")
        ])
      (progDesc "Completion effects (external ones always stop for approval)")
  , command "source" $ info
      (hsubparser $ mconcat
        [ command "attach" $ info
            (CSourceAttach
              <$> textArg "BRICK" "brick ref"
              <*> textOpt "type"
                    "source type (free vocab: github_issue, file, chat, ...)"
              <*> textOpt "url" "URL or path of the source of truth")
            (progDesc "Attach an external source to a brick")
        , command "check" $ info
            (CSourceCheck
              <$> textArg "LINK" "source link ref"
              <*> textOpt "fingerprint" "current content fingerprint")
            (progDesc "Record a source check (drift spawns a reconcile brick)")
        , command "resolve" $ info
            (CSourceResolve
              <$> textArg "LINK" "source link ref"
              <*> textOpt "fingerprint" "reconciled content fingerprint")
            (progDesc "Mark a diverged source as reconciled")
        , command "ls" $ info (pure CSourceLs) (progDesc "List source links")
        ])
      (progDesc "External sources (referenced, never copied)")
  , command "party" $ info
      (hsubparser $ mconcat
        [ command "add" $ info
            (CPartyAdd
              <$> textArg "NAME" "canonical name (identity = hash of it)"
              <*> strOption (long "type"
                    <> metavar "person|ai_agent|company|area"))
            (progDesc "Register a party in the entity registry")
        , command "ls" $ info (pure CPartyLs) (progDesc "List parties")
        ])
      (progDesc "The entity registry (people, agents, companies, areas)")
  , command "ls" $ info
      (CLs
        <$> optional (strOption (long "stage" <> metavar "STAGE"))
        <*> switch (long "frontier" <> help "servable frontier only"))
      (progDesc "List bricks")
  , command "show" $ info
      (CShow <$> textArg "BRICK" "brick ref")
      (progDesc "Show one brick in full")
  , command "status" $ info (pure CStatus)
      (progDesc "Everything the operator needs for the opening line")
  , command "grammar" $ info (pure CGrammar)
      (progDesc "The canonical interaction grammar: namespaces, letters, markers")
  , command "migrate" $ info (pure CMigrate)
      (progDesc "Rewrite log + archives to the current wire format (admin; backs up originals)")
  , command "tick" $ info (pure CTick)
      (progDesc "Fire due temporal rules explicitly (every command auto-ticks)")
  , command "render" $ info
      (CRender <$> strOption (long "format" <> value "md"
                              <> metavar "md|org"
                              <> help "projection format (default md)"))
      (progDesc "Render human-readable projections of the truth")
  , command "events" $ info
      (CEvents <$> optional (option auto (long "tail" <> metavar "N")))
      (progDesc "Show the raw event log (the truth)")
  ]

pGlobal :: Parser Global
pGlobal = Global
  <$> switch (long "json" <> help "machine-readable output (for operators)")
  <*> optional (strOption (long "data" <> metavar "DIR"
                           <> help "data directory (default: $ANT_DATA_DIR or XDG)"))
  <*> switch (long "dry-run" <> help "validate and show events without writing")

opts :: ParserInfo (Global, Cmd)
opts = info (((,) <$> pGlobal <*> pCmd) <**> helper)
  ( fullDesc
  <> progDesc "Little Ant — a personal focus engine. One brick at a time."
  <> header "la - little ant" )

-- --------------------------------------------------------------------------
-- Driver
-- --------------------------------------------------------------------------

main :: IO ()
main = do
  (g, cmd) <- execParser opts
  dir <- resolveDataDir (gDataDir g)
  case cmd of
    CMigrate -> runMigrate g dir
    _ -> runNormal g dir cmd

-- | @la migrate@ bypasses the normal replay/tick/dispatch pipeline: it is
-- an offline admin operation on the log's REPRESENTATION, not a domain
-- command — no auto-tick events are appended during a rewrite.
runMigrate :: Global -> FilePath -> IO ()
runMigrate g dir = do
  r <- migrateLog dir (gDryRun g)
  case r of
    Left err -> do
      emitError g CmdError
        { ceCode = "migrate_failed"
        , ceMessage = err
        , ceHint = Just "nothing was rewritten; fix the log (or move the stale backup) and retry"
        }
      exitWith (ExitFailure 2)
    Right files -> emit g "la" Out
      { oResult = toJSON
          [ object [ "file" .= f, "events" .= n, "backup" .= b ]
          | (f, n, b) <- files ]
      , oHuman = T.intercalate "\n"
          [ "migrated " <> tshow n <> " events: " <> T.pack f
              <> " (backup: " <> T.pack b <> ")"
          | (f, n, b) <- files ]
      , oEvents = []
      , oWarnings = []
      , oDryRun = gDryRun g
      }

runNormal :: Global -> FilePath -> Cmd -> IO ()
runNormal g dir cmd = do
  cfgE <- loadConfigIO dir
  cfg <- case cfgE of
    Left e -> hPutStrLn stderr e >> exitWith (ExitFailure 1)
    Right c -> pure c
  (events, warns) <- loadEvents dir
  now <- getCurrentTime
  let st0 = replay events
      tickEvs = mkEvents now (dueBodies cfg now st0)
      st = foldl (flip applyEvent) st0 tickEvs
  case dispatch cfg now st cmd of
    Left err -> do
      emitError g err
      exitWith (ExitFailure (exitCodeFor err))
    Right (bodies, result, human) -> do
      let newEvs = mkEvents now bodies
          st' = foldl (flip applyEvent) st newEvs
      if gDryRun g
        then pure ()
        else appendEvents dir (tickEvs ++ newEvs)
      emit g cmdName Out
        { oResult = result st'
        , oHuman = human st'
        , oEvents = tickEvs ++ newEvs
        , oWarnings = warns
        , oDryRun = gDryRun g
        }
  where
    cmdName = "la" :: Text

data Out = Out
  { oResult :: Value
  , oHuman :: Text
  , oEvents :: [Event]
  , oWarnings :: [Text]
  , oDryRun :: Bool
  }

emit :: Global -> Text -> Out -> IO ()
emit g _ Out {..}
  | gJson g = BL.putStrLn . Pretty.encodePretty' compactCfg $ object
      [ "ok" .= True
      , "dry_run" .= oDryRun
      , "result" .= oResult
      , "human" .= oHuman
      , "events" .= map eventToJSON oEvents
      , "warnings" .= oWarnings
      ]
  | otherwise = do
      mapM_ (TIO.putStrLn . ("warning: " <>)) oWarnings
      TIO.putStrLn oHuman
  where
    compactCfg = Pretty.defConfig { Pretty.confIndent = Pretty.Spaces 2 }

emitError :: Global -> CmdError -> IO ()
emitError g CmdError {..}
  | gJson g = BL.putStrLn . Pretty.encodePretty $ object
      [ "ok" .= False
      , "error" .= object
          [ "code" .= ceCode, "message" .= ceMessage, "hint" .= ceHint ]
      , "human" .= ("error (" <> ceCode <> "): " <> ceMessage
                    <> maybe "" ("\nhint: " <>) ceHint)
      ]
  | otherwise = do
      TIO.hPutStrLn stderr ("error (" <> ceCode <> "): " <> ceMessage)
      mapM_ (TIO.hPutStrLn stderr . ("hint: " <>)) ceHint

exitCodeFor :: CmdError -> Int
exitCodeFor e = case ceCode e of
  "ref_not_found" -> 3
  "ref_ambiguous" -> 4
  "title_collision" -> 5
  _ -> 2

-- --------------------------------------------------------------------------
-- Dispatch
-- --------------------------------------------------------------------------

type Output = ([Body], State -> Value, State -> Text)

pureOut :: Value -> Text -> Output
pureOut v t = ([], const v, const t)

evOut :: [Body] -> (State -> Value) -> (State -> Text) -> Output
evOut = (,,)

parseEnum :: Text -> (Text -> Maybe a) -> Text -> Either CmdError a
parseEnum what parse t = case parse t of
  Just a -> Right a
  Nothing -> Left (CmdError "invalid_argument"
    ("invalid " <> what <> ": " <> t) Nothing)

dispatch :: Config -> UTCTime -> State -> Cmd -> Either CmdError Output
dispatch cfg now st = \case
  CMigrate -> Left (CmdError "internal"
    "migrate is handled before the dispatch pipeline" Nothing)
  CPartyAdd name ptypeT -> do
    ptype <- parseEnum "party type" parsePartyType ptypeT
    bodies <- cmdPartyAdd st name ptype
    pure $ evOut bodies
      (\st' -> lastParty st')
      (\_ -> "party registered: " <> name)
  CPartyLs ->
    Right $ pureOut
      (toJSON (map partyView (Map.elems (stParties st))))
      (T.unlines [ shortId (pId p) <> "  " <> pName p
                 | p <- Map.elems (stParties st) ])
  CCapture title -> do
    bodies <- cmdCapture st title
    pure $ withBrickOf bodies "seed captured"
  CRawAdd content -> do
    bodies <- cmdRawCapture st content
    pure $ evOut bodies (const (toJSON True)) (const "raw input captured")
  CRawLs ->
    Right $ pureOut
      (toJSON (map rawView (Map.elems (stRawInputs st))))
      (T.unlines [ shortId (rawId r) <> "  ["
                     <> rawStatusText (rawStatus r) <> "] "
                     <> T.take 60 (rawContent r)
                 | r <- Map.elems (stRawInputs st) ])
  CExtract rawRef titles -> do
    bodies <- cmdExtract st rawRef titles
    pure $ evOut bodies (const (toJSON (length titles)))
      (const ("extracted " <> tshow (length titles) <> " seed(s)"))
  CPromote r -> simple (cmdPromote st r) "promoted"
  CKill r -> simple (cmdKill st r) "killed"
  CReady r -> simple (cmdReady st r) "ready"
  CRequester r p -> simple (cmdRequester st r p) "requester attributed"
  CSet r kT c en mT aT est estByT desc -> do
    k <- traverse (parseEnum "kind" parseKind) kT
    m <- traverse (parseEnum "mode" parseMode) mT
    a <- traverse (parseEnum "atomicity" parseAtomicity) aT
    estBy <- traverse (parseEnum "estimate author" parseAuthor) estByT
    simple (cmdEnrich st r k c en m a est estBy desc) "enriched"
  CBreak r parts -> do
    bodies <- cmdBreak st r parts
    pure $ evOut bodies (const (toJSON (length parts)))
      (const ("broken into " <> tshow (length parts) <> " part(s)"))
  CUnify r into reason -> simple (cmdUnify st r into reason) "unified"
  CSupersede r title reason ->
    simple (cmdSupersede st r title reason) "superseded"
  CSessionOpen ctx strictT -> do
    strict <- parseEnum "strictness" parseStrictness strictT
    bodies <- cmdSessionOpen st ctx strict
    pure $ evOut bodies
      (\st' -> maybe (toJSON True) sessionView (latestOpenSession st'))
      (const "session open")
  CSessionClose mref -> simple (cmdSessionClose st mref) "session closed"
  CSessionLs ->
    Right $ pureOut
      (toJSON (map sessionView
        (sortOn (Down . sesOpenedAt) (Map.elems (stSessions st)))))
      "sessions listed (use --json)"
  CNext mref -> do
    (bodies, outcome) <- cmdNext cfg st mref
    pure $ evOut bodies
      (\st' -> nextResultJson st' outcome)
      (\st' -> nextResultHuman st' outcome)
  CStart r -> simple (cmdStart st r) "started"
  CStop r -> simple (cmdStop st r) "stopped"
  CDone r -> do
    bodies <- cmdDone st r
    let spawned = length [ () | EffectApplied _ (Just _) <- bodies ]
        proposed = length [ () | EffectProposed _ <- bodies ]
    pure $ evOut bodies
      (const (object
        [ "completed" .= True
        , "spawned_bricks" .= spawned
        , "effects_awaiting_approval" .= proposed
        ]))
      (const ("done ✓ (" <> tshow spawned <> " spawned, "
               <> tshow proposed <> " awaiting approval)"))
  CSkip r reasonT rawText -> do
    reason <- parseEnum "skip reason" parseSkipReason reasonT
    (bodies, reaction) <- cmdSkip st r reason rawText
    pure $ evOut bodies
      (const (object [ "reaction" .= reaction ]))
      (const ("skip recorded → " <> reaction))
  CClarify r title -> simple (cmdClarify st r title) "clarify meta-brick created"
  CWaitAdd r p c -> simple (cmdWait st r p c) "wait recorded (off the frontier)"
  CWaitResolve r -> simple (cmdWaitResolve st r) "wait resolved"
  CWaitLs ->
    Right $ pureOut
      (toJSON (map (waitView st) (Map.elems (stWaits st))))
      "waits listed (use --json)"
  CDepAdd blocked blocker ->
    simple (cmdDepAdd st blocked blocker) "dependency added"
  CCompare a b authorT -> do
    author <- parseEnum "author" parseAuthor authorT
    simple (cmdCompare st a b author) "comparison recorded"
  COrder _ _ Nothing True ->
    Right $ case mergeSortStep st (frontier st) of
      SortedOrder sorted -> pureOut
        (object
          [ "sorted" .= True
          , "order" .= map brickSummary sorted ])
        (T.unlines $ "fully ordered ✓" :
          [ tshow i <> ". " <> shortId (bId b) <> "  " <> bTitle b
          | (i, b) <- zip [1 :: Int ..] sorted ])
      AskPair a b -> pureOut
        (object
          [ "sorted" .= False
          , "ask" .= object
              [ "earlier_candidate" .= brickSummary a
              , "later_candidate" .= brickSummary b ] ])
        ("? should \"" <> bTitle a <> "\" be done BEFORE \""
          <> bTitle b <> "\"? (record with `la compare`, then sort again)")
  COrder _ _ (Just placeRef) _ -> do
    target <- resolveBrick st placeRef
    let others = frontier st
    pure $ case placeBrick st others target of
      Left pos -> pureOut
        (object [ "placed" .= True, "position" .= (pos + 1) ])
        ("placed: position " <> tshow (pos + 1) <> " of "
          <> tshow (length [ o | o <- others, bId o /= bId target ] + 1))
      Right m -> pureOut
        (object
          [ "placed" .= False
          , "ask" .= object
              [ "target" .= brickSummary target
              , "against" .= brickSummary m ] ])
        ("? should \"" <> bTitle target <> "\" be done before \""
          <> bTitle m <> "\"? (record with `la compare`, then place again)")
  COrder questions limit Nothing False ->
    Right $
      if questions
        then
          let qs = orderQuestions st (frontier st) limit
           in pureOut
                (toJSON [ object [ "earlier_candidate" .= brickSummary a
                                 , "later_candidate" .= brickSummary b ]
                        | (a, b) <- qs ])
                (T.unlines
                  [ "? " <> bTitle a <> "  vs  " <> bTitle b
                  | (a, b) <- qs ])
        else pureOut
          (toJSON (map brickSummary (frontier st)))
          (T.unlines
            [ tshow i <> ". " <> shortId (bId b) <> "  " <> bTitle b
            | (i, b) <- zip [1 :: Int ..] (frontier st) ])
  CExportTj defEffort ->
    let tjp = renderTaskJuggler st now defEffort
     in Right $ pureOut (toJSON tjp) tjp
  CDelegate r p -> do
    bodies <- cmdDelegate st r p
    pure $ evOut bodies
      (const (object [ "reaction" .= ("delegation_notice_proposed" :: Text) ]))
      (const "delegation created — draft the notice and approve it")
  CDelegLs ->
    Right $ pureOut
      (toJSON (map (delegationView st) (Map.elems (stDelegations st))))
      "delegations listed (use --json)"
  CDelegNotice r ->
    simple (cmdDelegationNotice cfg st now r) "notice approved — notified"
  CDelegCancel r -> simple (cmdDelegationCancel st r) "delegation cancelled"
  CDelegOutcome r outcome ->
    simple (cmdDelegationOutcome st r outcome) ("delegation " <> outcome)
  CNudgeApprove r ->
    simple (cmdNudgeApprove cfg st now r) "nudge approved"
  CNudgeDecline r ->
    simple (cmdNudgeDecline cfg st now r) "nudge declined"
  CEffectAdd r kindT detail -> do
    kind <- parseEnum "effect kind" parseEffectKind kindT
    simple (cmdEffectAdd st r kind detail) "effect armed"
  CEffectApprove r -> simple (cmdEffectApprove st r) "effect applied"
  CEffectDecline r -> simple (cmdEffectDecline st r) "effect declined"
  CEffectLs ->
    Right $ pureOut
      (toJSON (map (effectView st) (Map.elems (stEffects st))))
      "effects listed (use --json)"
  CSourceAttach r stype url ->
    simple (cmdSourceAttach st r stype url) "source attached"
  CSourceCheck l fp -> do
    bodies <- cmdSourceCheck st l fp
    let diverged = any isDivergedEv bodies
    pure $ evOut bodies
      (const (object [ "diverged" .= diverged ]))
      (const (if diverged
                then "source DIVERGED — a reconcile meta-brick was created"
                else "source fresh"))
  CSourceResolve l fp -> simple (cmdSourceResolve st l fp) "source reconciled"
  CSourceLs ->
    Right $ pureOut
      (toJSON (map (linkView st) (Map.elems (stSourceLinks st))))
      "source links listed (use --json)"
  CLs mstage frontierOnly -> do
    bricks <-
      if frontierOnly
        then Right (frontier st)
        else case mstage of
          Nothing -> Right
            (sortOn bCreatedSeq
              [ b | b <- Map.elems (stBricks st), isOpen b ])
          Just sT -> do
            s <- parseEnum "stage" parseStage sT
            Right (sortOn bCreatedSeq
              [ b | b <- Map.elems (stBricks st), bStage b == s ])
    pure $ pureOut
      (toJSON (map (brickView st) bricks))
      (T.unlines
        [ shortId (bId b) <> "  [" <> stageText (bStage b) <> "] " <> bTitle b
        | b <- bricks ])
  CShow r -> do
    b <- resolveBrick st r
    pure $ pureOut
      (object
        [ "brick" .= brickView st b
        , "skips" .= [ skipView st s
                     | s <- Map.elems (stSkips st), skBrick s == bId b ]
        , "waits" .= map (waitView st) (brickWaits st b)
        , "sources" .= map (linkView st) (brickSources st b)
        , "effects" .= map (effectView st) (brickEffects st b)
        , "delegations" .= [ delegationView st d
                           | d <- Map.elems (stDelegations st)
                           , dBrick d == bId b ]
        ])
      (bTitle b <> "  [" <> stageText (bStage b) <> "]  "
        <> shortId (bId b))
  CStatus ->
    Right $ pureOut (statusView st) (statusHuman st)
  CGrammar ->
    Right $ pureOut grammarView grammarHuman
  CTick ->
    -- auto-tick already ran; this command exists to make it explicit
    Right $ pureOut (toJSON True) "ticked"
  CRender fmt -> case fmt of
    "org" -> Right $ pureOut (toJSON (renderOrg st)) (renderOrg st)
    _ -> Right $ pureOut (toJSON (renderMarkdown st)) (renderMarkdown st)
  CEvents mtail ->
    Right $ pureOut
      (toJSON (stEventCount st))
      ("events: " <> tshow (stEventCount st)
        <> maybe "" (\n -> " (tail " <> tshow n <> " — use --json / the log file)") mtail)
  where
    simple :: Either CmdError [Body] -> Text -> Either CmdError Output
    simple e msg = do
      bodies <- e
      pure $ evOut bodies (const (toJSON True)) (const ("✓ " <> msg))

    withBrickOf bodies msg = evOut bodies
      (\st' -> case [ i | BrickCaptured i _ <- bodies ] of
          (i : _) -> maybe (toJSON True) (brickView st')
            (Map.lookup i (stBricks st'))
          [] -> toJSON True)
      (\_ -> case [ (i, t) | BrickCaptured i t <- bodies ] of
          ((i, t) : _) -> "✓ " <> msg <> ": " <> shortId i <> " · " <> t
          [] -> "✓ " <> msg)

    lastParty st' =
      case sortOn (Down . unId . pId) (Map.elems (stParties st')) of
        (p : _) -> partyView p
        [] -> toJSON True

    isDivergedEv = \case
      SourceDiverged {} -> True
      _ -> False

    nextResultJson st' = \case
      Right ch -> object
        [ "brick" .= brickView st' (chBrick ch)
        , "queue" .= chQueue ch
        , "context_matched" .= chContextMatched ch
        ]
      Left nc -> object
        [ "brick" .= Null
        , "reason" .= noChoiceText nc
        ]
    nextResultHuman _st' = \case
      Right ch ->
        "→ focus: " <> shortId (bId (chBrick ch)) <> " · "
          <> bTitle (chBrick ch)
          <> " (" <> chQueue ch <> ")"
      Left nc -> "no focus: " <> noChoiceText nc
    noChoiceText = \case
      FrontierEmpty ->
        "frontier is empty — promote/ready a brick, resolve waits, or triage seeds"
      ContextExcludedAll ->
        "strictness=require excluded every candidate — relax it or switch context"

    statusHuman st' =
      let fr = frontier st'
       in "frontier " <> tshow (length fr)
            <> " · seeds " <> tshow (countStage Seed)
            <> " · wip " <> tshow (countStage Wip)
            <> " · nudges " <> tshow (length
                 [ d | d <- Map.elems (stDelegations st'), dNudgePending d ])
            <> " · other-skips " <> tshow
                 (twUnreviewedOtherCount (stTaxonomy st'))
      where
        countStage s =
          length [ b | b <- Map.elems (stBricks st'), bStage b == s ]

tshow :: Show a => a -> Text
tshow = T.pack . show

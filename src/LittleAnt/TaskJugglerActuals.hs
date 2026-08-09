module LittleAnt.TaskJugglerActuals (
  Microhours (..),
  TaskJugglerActual (..),
  TaskJugglerActuals (..),
  parseTaskJugglerActuals,
)
where

import Control.Monad (foldM, unless, when)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Char (isAscii, isAsciiLower, isAsciiUpper, isDigit)
import Data.List (findIndices, nub)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Pack.Format (canonicalJsonBytes)
import LittleAnt.Store (sha256Hex)

{- | TaskJuggler actual values are retained exactly to six decimal places.
Presence is represented by the surrounding 'Maybe', so @0h@ is evidence
and remains distinguishable from an absent field.
-}
newtype Microhours = Microhours {unMicrohours :: Integer}
  deriving stock (Eq, Ord, Show)

data TaskJugglerActual = TaskJugglerActual
  { actualTaskId :: Text
  , actualBrickId :: UUIDv7
  , actualCompleted :: Maybe Microhours
  , actualRemaining :: Maybe Microhours
  }
  deriving stock (Eq, Show)

data TaskJugglerActuals = TaskJugglerActuals
  { actualsManifestDigest :: Text
  , actualsManifestBytes :: ByteString
  , actualsAsOf :: UTCTime
  , actualsRecords :: [TaskJugglerActual]
  }
  deriving stock (Eq, Show)

data ManifestCutItem = ManifestCutItem
  { manifestTaskId :: Text
  , manifestBrickId :: UUIDv7
  }
  deriving stock (Eq, Show)

data TaskFields = TaskFields
  { taskCompleted :: Maybe Microhours
  , taskRemaining :: Maybe Microhours
  }
  deriving stock (Eq, Show)

emptyTaskFields :: TaskFields
emptyTaskFields = TaskFields Nothing Nothing

data ScanState = ScanState
  { scanDepth :: Int
  , scanTask :: Maybe Text
  , scanTasks :: Map Text TaskFields
  , scanInProject :: Bool
  , scanProjectSeen :: Bool
  , scanProjectTimezones :: [Text]
  , scanNowValues :: [Text]
  }
  deriving stock (Eq, Show)

parseTaskJugglerActuals :: ByteString -> Either AppError TaskJugglerActuals
parseTaskJugglerActuals bytes = do
  source <- firstProblem "The TaskJuggler source is not valid UTF-8." (TextEncoding.decodeUtf8' bytes)
  (manifestDigest, manifestBytes) <- extractManifest (Text.lines source)
  manifestValue <- firstProblem "The embedded planning manifest is not valid JSON." (eitherDecodeStrict' manifestBytes)
  canonical <- canonicalJsonBytes manifestValue
  unless (canonical == manifestBytes) $ invalid "The embedded planning manifest is not canonical JCS."
  cut <- firstProblem "The embedded planning manifest violates its custody schema." (parseEither parseManifestCut manifestValue)
  validateManifestCut cut
  scanned <- scanTaskJuggler (Text.lines source)
  asOf <- parseAsOf (scanNowValues scanned)
  let expected = Map.fromList [(manifestTaskId item, manifestBrickId item) | item <- cut]
      actualTaskIds = Map.keysSet (Map.filter hasActual (scanTasks scanned))
      unknownActuals = Set.toAscList (actualTaskIds `Set.difference` Map.keysSet expected)
      missingTasks = Set.toAscList (Map.keysSet expected `Set.difference` Map.keysSet (scanTasks scanned))
  unless (null unknownActuals) $
    invalidWith "Actuals reference tasks outside the embedded planning cut." unknownActuals
  unless (null missingTasks) $
    invalidWith "The TaskJuggler source does not contain every task in its embedded planning cut." missingTasks
  let records =
        [ TaskJugglerActual taskId brickId (taskCompleted fields) (taskRemaining fields)
        | (taskId, brickId) <- Map.toAscList expected
        , Just fields <- [Map.lookup taskId (scanTasks scanned)]
        , hasActual fields
        ]
  when (null records) $ invalid "The TaskJuggler source contains no actual effort evidence."
  pure (TaskJugglerActuals manifestDigest manifestBytes asOf records)
 where
  hasActual fields = isJust (taskCompleted fields) || isJust (taskRemaining fields)

extractManifest :: [Text] -> Either AppError (Text, ByteString)
extractManifest lines_ = do
  let digestPrefix = "# LANT-MANIFEST-SHA256: "
      digestLines = findIndices (Text.isPrefixOf digestPrefix) lines_
      allChunkLines = findIndices (Text.isPrefixOf chunkPrefix) lines_
  digestIndex <- case digestLines of
    [index] -> Right index
    [] -> invalid "The TaskJuggler source has no embedded planning-manifest digest."
    _ -> invalid "The TaskJuggler source contains more than one planning-manifest digest."
  let digest = Text.drop (Text.length digestPrefix) (lines_ !! digestIndex)
  requireDigest digest
  (chunks, consumedIndices) <- collectChunks (digestIndex + 1) (1 :: Int) [] []
  when (null chunks) $ invalid "The TaskJuggler source has no embedded planning-manifest body."
  unless (allChunkLines == consumedIndices) $
    invalid "The embedded planning-manifest chunks are not one contiguous, ordered block."
  let encoded = TextEncoding.encodeUtf8 (Text.concat chunks)
  decoded <- firstProblem "The embedded planning manifest is not canonical unpadded base64url." (Base64Url.decodeUnpadded encoded)
  unless (Base64Url.encodeUnpadded decoded == encoded) $
    invalid "The embedded planning manifest is not canonical unpadded base64url."
  unless (sha256Hex decoded == digest) $
    invalid "The embedded planning-manifest digest does not match its canonical bytes."
  pure (digest, decoded)
 where
  chunkPrefix = "# LANT-MANIFEST-JCS-BASE64URL-"
  collectChunks index sequenceNumber chunks indices
    | index >= length lines_ = Right (reverse chunks, reverse indices)
    | otherwise =
        let line = lines_ !! index
            expected = chunkPrefix <> fourDigits sequenceNumber <> ": "
         in if Text.isPrefixOf expected line
              then
                let chunk = Text.drop (Text.length expected) line
                 in if Text.null chunk
                      then invalid "An embedded planning-manifest chunk is empty."
                      else collectChunks (index + 1) (sequenceNumber + 1) (chunk : chunks) (index : indices)
              else Right (reverse chunks, reverse indices)
  fourDigits value = Text.justifyRight 4 '0' (Text.pack (show value))

parseManifestCut :: Value -> Parser [ManifestCutItem]
parseManifestCut = withObject "planning manifest" $ \manifest -> do
  rejectUnknownKeys manifest ["schema", "source", "scope", "planned_at", "roots", "cut", "effort_profile", "warnings", "resources", "calendars", "projection", "exporter"]
  schema <- manifest .: "schema"
  unless (schema == ("little-ant/planning-manifest@1" :: Text)) $ fail "unsupported planning manifest schema"
  _ <- manifest .: "source" >>= withObject "planning source" (\source -> (,) <$> source .: "cursor" <*> source .: "hash" :: Parser (Text, Text))
  _ <- manifest .: "scope" :: Parser Object
  _ <- manifest .: "planned_at" :: Parser Text
  roots <- manifest .: "roots" :: Parser [Text]
  _ <- traverse (either (fail . Text.unpack) pure . parseUUIDv7) roots
  _ <- manifest .: "effort_profile" :: Parser Object
  _ <- manifest .: "warnings" :: Parser [Value]
  _ <- manifest .: "resources" :: Parser [Value]
  _ <- manifest .: "calendars" :: Parser [Value]
  projectionSchema <- manifest .: "projection" >>= withObject "planning projection" (.: "schema")
  unless (projectionSchema == ("little-ant/taskjuggler@1" :: Text)) $ fail "unsupported TaskJuggler projection schema"
  _ <- manifest .: "exporter" :: Parser Object
  manifest .: "cut" >>= traverse parseCutItem
 where
  parseCutItem = withObject "planning cut item" $ \item -> do
    rejectUnknownKeys item ["task_id", "brick_id", "order", "dependencies", "effort_macro"]
    taskId <- item .: "task_id"
    brickText <- item .: "brick_id"
    _ <- item .: "order" :: Parser Int
    _ <- item .: "dependencies" :: Parser [Text]
    _ <- item .:? "effort_macro" :: Parser (Maybe Text)
    brickId <- either (fail . Text.unpack) pure (parseUUIDv7 brickText)
    pure (ManifestCutItem taskId brickId)

rejectUnknownKeys :: Object -> [Text] -> Parser ()
rejectUnknownKeys fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

validateManifestCut :: [ManifestCutItem] -> Either AppError ()
validateManifestCut cut = do
  unless (unique (manifestTaskId <$> cut)) $ invalid "The planning manifest contains duplicate TaskJuggler task identities."
  unless (unique (manifestBrickId <$> cut)) $ invalid "The planning manifest contains duplicate Brick identities."
  mapM_ validateItem cut
 where
  validateItem item = do
    let expected = "t_" <> Text.filter (/= '-') (renderUUIDv7 (manifestBrickId item))
    unless (manifestTaskId item == expected) $
      invalid "A planning-manifest task identity is not the canonical projection of its Brick UUID."
  unique values = length values == length (nub values)

scanTaskJuggler :: [Text] -> Either AppError ScanState
scanTaskJuggler lines_ = do
  scanned <- foldM scanLine (ScanState 0 Nothing Map.empty False False [] []) lines_
  when (scanDepth scanned /= 0) $ invalid "The TaskJuggler source contains unbalanced opening braces."
  unless (scanProjectSeen scanned) $ invalid "The TaskJuggler source contains no top-level project declaration."
  unless (scanProjectTimezones scanned == ["UTC"]) $ invalid "TaskJuggler actuals require exactly one UTC project timezone."
  pure scanned
 where
  scanLine state original = do
    let line = Text.strip (stripComment original)
        depthBefore = scanDepth state
        opens = countOutsideQuotes '{' line
        closes = countOutsideQuotes '}' line
    when (closes > depthBefore + opens) $ invalid "The TaskJuggler source contains unbalanced closing braces."
    when (isProjectKeyword line && not (isProjectDeclaration line)) $
      invalid "A top-level TaskJuggler project declaration is malformed."
    taskStart <- parseTaskStart depthBefore line
    when (depthBefore > 0 && isTaskDeclaration line) $
      invalid "Nested TaskJuggler task declarations are ambiguous for actuals custody."
    stateWithProject <- case isProjectDeclaration line of
      False -> Right state
      True -> do
        when (depthBefore /= 0 || scanProjectSeen state) $ invalid "The TaskJuggler source contains an ambiguous project declaration."
        pure state{scanInProject = True, scanProjectSeen = True}
    stateWithTask <- case taskStart of
      Nothing -> Right stateWithProject
      Just taskId -> do
        when (Map.member taskId (scanTasks stateWithProject)) $
          invalid "The TaskJuggler source contains a duplicate top-level task identity."
        pure stateWithProject{scanTask = Just taskId, scanTasks = Map.insert taskId emptyTaskFields (scanTasks stateWithProject)}
    stateWithActual <- parseActualLine line >>= applyActual stateWithTask
    let words_ = Text.words line
    when (isNowLine words_ && not (scanInProject stateWithActual && depthBefore == 1)) $
      invalid "The TaskJuggler project 'now' timestamp is outside the top-level project body."
    let nowValues = case words_ of
          ["now", value] -> value : scanNowValues stateWithActual
          _ -> scanNowValues stateWithActual
        timezones = case words_ of
          ["timezone", quoted] | scanInProject stateWithActual && depthBefore == 1 -> stripQuotedValue quoted : scanProjectTimezones stateWithActual
          _ -> scanProjectTimezones stateWithActual
        depthAfter = depthBefore + opens - closes
        activeTask = if depthAfter == 0 then Nothing else scanTask stateWithActual
        inProject = scanInProject stateWithActual && depthAfter /= 0
    pure stateWithActual{scanDepth = depthAfter, scanTask = activeTask, scanInProject = inProject, scanProjectTimezones = timezones, scanNowValues = nowValues}

  applyActual state Nothing = Right state
  applyActual state (Just (field, value)) = do
    taskId <- maybe (invalid "An actual effort field appears outside a top-level task.") Right (scanTask state)
    fields <- maybe (invalid "An actual effort field appears before its task declaration.") Right (Map.lookup taskId (scanTasks state))
    updated <- case field of
      "effortdone" -> do
        when (isJust (taskCompleted fields)) $ invalid "A task contains duplicate actual:effortdone fields."
        pure fields{taskCompleted = Just value}
      "effortleft" -> do
        when (isJust (taskRemaining fields)) $ invalid "A task contains duplicate actual:effortleft fields."
        pure fields{taskRemaining = Just value}
      _ -> invalid "The TaskJuggler source contains an unsupported actual field."
    pure state{scanTasks = Map.insert taskId updated (scanTasks state)}

  isNowLine = \case
    "now" : _ -> True
    _ -> False
  stripQuotedValue value = maybe value id (Text.stripPrefix "\"" value >>= Text.stripSuffix "\"")

parseTaskStart :: Int -> Text -> Either AppError (Maybe Text)
parseTaskStart depth line
  | depth /= 0 || not (isTaskDeclaration line) = Right Nothing
  | otherwise = case Text.words line of
      "task" : taskId : _
        | "{" `Text.isSuffixOf` line && validTaskId taskId -> Right (Just taskId)
        | otherwise -> invalid "A top-level TaskJuggler task declaration is malformed."
      _ -> invalid "A top-level TaskJuggler task declaration is malformed."
 where
  validTaskId value = case Text.uncons value of
    Nothing -> False
    Just (first, rest) -> asciiLetter first && Text.all (\character -> asciiLetter character || isDigit character || character == '_') rest
  asciiLetter character = isAscii character && (isAsciiLower character || isAsciiUpper character || character == '_')

isTaskDeclaration :: Text -> Bool
isTaskDeclaration line = case Text.words line of
  "task" : _ -> True
  _ -> False

isProjectDeclaration :: Text -> Bool
isProjectDeclaration line = case Text.words line of
  "project" : _ -> "{" `Text.isSuffixOf` line
  _ -> False

isProjectKeyword :: Text -> Bool
isProjectKeyword line = case Text.words line of
  "project" : _ -> True
  _ -> False

parseActualLine :: Text -> Either AppError (Maybe (Text, Microhours))
parseActualLine line
  | not ("actual:" `Text.isPrefixOf` line) = Right Nothing
  | otherwise = case Text.words line of
      [fieldToken, value] -> do
        field <- maybe (invalid "A TaskJuggler actual field is malformed.") Right (Text.stripPrefix "actual:" fieldToken)
        unless (field `elem` ["effortdone", "effortleft"]) $
          invalid "The TaskJuggler source contains an unsupported actual field."
        Just . (field,) <$> parseHours value
      _ -> invalid "A TaskJuggler actual field is malformed."

parseHours :: Text -> Either AppError Microhours
parseHours value = do
  number <- maybe (invalid "TaskJuggler actual effort must use explicit hours, such as 2h or 1.5h.") Right (Text.stripSuffix "h" value)
  let pieces = Text.splitOn "." number
  (whole, fraction) <- case pieces of
    [wholePart] -> Right (wholePart, "")
    [wholePart, fractionPart] -> Right (wholePart, fractionPart)
    _ -> invalid "TaskJuggler actual effort must be a nonnegative decimal number of hours."
  when (Text.null whole || Text.length whole > 12 || not (Text.all isDigit whole)) $
    invalid "TaskJuggler actual effort must be a bounded nonnegative decimal number of hours."
  when (Text.length fraction > 6 || (not (Text.null fraction) && not (Text.all isDigit fraction))) $
    invalid "TaskJuggler actual effort supports at most six decimal places."
  let wholeValue = read (Text.unpack whole) :: Integer
      fractionValue = if Text.null fraction then 0 else read (Text.unpack (Text.justifyLeft 6 '0' fraction))
  pure (Microhours (wholeValue * 1_000_000 + fractionValue))

parseAsOf :: [Text] -> Either AppError UTCTime
parseAsOf values = do
  value <- case reverse values of
    [one] -> Right one
    [] -> invalid "TaskJuggler actuals require one explicit project 'now' timestamp."
    _ -> invalid "TaskJuggler actuals contain more than one project 'now' timestamp."
  local <- maybe (invalid "TaskJuggler actuals require 'now' in YYYY-MM-DD-HH:MM UTC form.") Right (parseTimeM True defaultTimeLocale "%Y-%m-%d-%H:%M" (Text.unpack value) :: Maybe LocalTime)
  unless (Text.pack (formatTime defaultTimeLocale "%Y-%m-%d-%H:%M" local) == value) $
    invalid "TaskJuggler actuals require an exact canonical 'now' timestamp."
  pure (localTimeToUTC utc local)

stripComment :: Text -> Text
stripComment = Text.pack . go False False . Text.unpack
 where
  go _ _ [] = []
  go quoted escaped (character : rest)
    | quoted && escaped = character : go quoted False rest
    | quoted && character == '\\' = character : go quoted True rest
    | character == '"' = character : go (not quoted) False rest
    | character == '#' && not quoted = []
    | otherwise = character : go quoted False rest

countOutsideQuotes :: Char -> Text -> Int
countOutsideQuotes needle = length . filter (== needle) . Text.unpack . stripQuoted
 where
  stripQuoted = Text.pack . go False False . Text.unpack
  go _ _ [] = []
  go quoted escaped (character : rest)
    | quoted && escaped = go quoted False rest
    | quoted && character == '\\' = go quoted True rest
    | character == '"' = go (not quoted) False rest
    | quoted = go quoted False rest
    | otherwise = character : go quoted False rest

requireDigest :: Text -> Either AppError ()
requireDigest digest =
  unless (Text.length digest == 64 && Text.all hexadecimal digest) $
    invalid "The embedded planning-manifest digest is not lowercase SHA-256."
 where
  hexadecimal character = isAscii character && (isDigit character || character >= 'a' && character <= 'f')

firstProblem :: Text -> Either problem value -> Either AppError value
firstProblem message = either (const (invalid message)) Right

invalidWith :: Text -> [Text] -> Either AppError value
invalidWith message details = Left (actualsProblem message){appErrorDetails = details}

invalid :: Text -> Either AppError value
invalid = Left . actualsProblem

actualsProblem :: Text -> AppError
actualsProblem message =
  (appError CorruptData message)
    { appErrorRecovery =
        [ RecoveryAction
            "taskjuggler-actuals"
            "Use an unambiguous TaskJuggler file exported by Little Ant, retain its embedded manifest, set one explicit UTC 'now', and add only supported actual effort fields."
            Nothing
        ]
    }

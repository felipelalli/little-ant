-- | Storage: an append-only JSONL event log in a plain data directory.
--
-- Data dir resolution: @--data@ flag > @ANT_DATA_DIR@ env > XDG data dir
-- (@~\/.local\/share\/little-ant@). The log is `events.jsonl`; an optional
-- `config.json` overrides scheduler knobs.
module LittleAnt.Store
  ( resolveDataDir
  , eventsPath
  , configPath
  , loadEvents
  , appendEvents
  , loadConfigIO
  , mkEvents
  , migrateLog
  ) where

import Control.Monad (unless)
import Data.Aeson (Value, eitherDecodeStrict, encode, withObject, (.:))
import Data.Aeson.Types (parseEither)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import LittleAnt.Config
import LittleAnt.Event
import LittleAnt.Upcast (eventFromJSONVersioned)
import System.Directory
import System.Environment (lookupEnv)
import System.FilePath (takeExtension, (</>))

resolveDataDir :: Maybe FilePath -> IO FilePath
resolveDataDir = \case
  Just d -> pure d
  Nothing -> do
    env <- lookupEnv "ANT_DATA_DIR"
    case env of
      Just d | not (null d) -> pure d
      _ -> getXdgDirectory XdgData "little-ant"

eventsPath :: FilePath -> FilePath
eventsPath dir = dir </> "events.jsonl"

configPath :: FilePath -> FilePath
configPath dir = dir </> "config.json"

-- | Load the log. Malformed or unknown lines are skipped with a warning —
-- forward compatibility over strictness.
loadEvents :: FilePath -> IO ([Event], [Text])
loadEvents dir = do
  let path = eventsPath dir
  exists <- doesFileExist path
  if not exists
    then pure ([], [])
    else do
      raw <- BS.readFile path
      let ls = filter (not . BS.null) (BC.lines raw)
          parse (n, l) = case eitherDecodeStrict l of
            Left e -> Left (lineWarn n e)
            Right v -> case parseEither eventFromJSONVersioned (v :: Value) of
              Left e -> Left (lineWarn n e)
              Right ev -> Right ev
          lineWarn :: Int -> String -> Text
          lineWarn n e =
            "events.jsonl line " <> T.pack (show n) <> " skipped: "
              <> T.pack e
          results = map parse (zip [1 :: Int ..] ls)
      pure ([ ev | Right ev <- results ], [ w | Left w <- results ])

appendEvents :: FilePath -> [Event] -> IO ()
appendEvents dir events = unless (null events) $ do
  createDirectoryIfMissing True dir
  let path = eventsPath dir
      payload = BL.concat [ encode (eventToJSON e) <> "\n" | e <- events ]
  BL.appendFile path payload

loadConfigIO :: FilePath -> IO (Either String Config)
loadConfigIO dir = do
  let path = configPath dir
  exists <- doesFileExist path
  if not exists
    then pure (Right defaultConfig)
    else do
      raw <- BS.readFile path
      pure $ case eitherDecodeStrict raw of
        Left e -> Left ("config.json: " <> e)
        Right (v :: Value) -> case parseConfig v of
          Left e -> Left ("config.json: " <> e)
          Right c -> Right c

-- | Stamp bodies into full events (same timestamp; intrinsic ids).
mkEvents :: UTCTime -> [Body] -> [Event]
mkEvents at bodies =
  [ Event (computeEventId at b) at b | b <- bodies ]

-- | @la migrate@: rewrite the hot log and every archive to the current
-- wire format in one pass. Administrative and deliberate — the one
-- sanctioned exception to append-only, viable because v1 is
-- single-master (ids are intrinsic and travel with the event, so ids,
-- order and meaning survive; only the representation changes).
--
-- All-or-nothing per run: every file is fully parsed (through the
-- upcasters) BEFORE anything is written; any bad line aborts the whole
-- migration. Each rewritten file leaves the original bytes behind as
-- @<file>.v<N>.bak@ where N is the oldest version found in it. The
-- snapshot, if one ever exists, is derived state and is NOT migrated.
--
-- Returns @(file, event count, backup path)@ per file; with @dryRun@
-- nothing is written and the backup path is what WOULD be used.
migrateLog :: FilePath -> Bool -> IO (Either Text [(FilePath, Int, FilePath)])
migrateLog dir dryRun = do
  let hot = eventsPath dir
      archDir = dir </> "archive"
  hotExists <- doesFileExist hot
  if not hotExists
    then pure (Left "no events.jsonl to migrate")
    else do
      archExists <- doesDirectoryExist archDir
      archives <- if archExists
        then map (archDir </>) . sort . filter ((== ".jsonl") . takeExtension)
               <$> listDirectory archDir
        else pure []
      plans <- traverse planFile (hot : archives)
      case sequence plans of
        Left err -> pure (Left err)
        Right infos
          | dryRun -> pure (Right [ i | (i, _) <- infos ])
          | otherwise -> do
              stale <- mapM (doesFileExist . backupOf) infos
              if or stale
                then pure (Left "a .bak backup from an earlier migration exists — move it away first")
                else do
                  mapM_ writeFilePlan infos
                  pure (Right [ i | (i, _) <- infos ])
  where
    backupOf ((_, _, bak), _) = bak
    planFile path = do
      raw <- BS.readFile path
      let ls = filter (not . BS.null) (BC.lines raw)
          parseLine (n, l) = case eitherDecodeStrict l of
            Left e -> Left (bad n e)
            Right v -> case ( parseEither (withObject "event" (.: "v")) v
                            , parseEither eventFromJSONVersioned (v :: Value) ) of
              (Left e, _) -> Left (bad n e)
              (_, Left e) -> Left (bad n e)
              (Right ver, Right ev) -> Right (ver :: Int, ev)
          bad n e = T.pack path <> " line " <> T.pack (show n) <> ": "
            <> T.pack e <> " — migration aborted, nothing was written"
      pure $ case traverse parseLine (zip [1 :: Int ..] ls) of
        Left err -> Left err
        Right parsed ->
          let minV = if null parsed then 1 else minimum (map fst parsed)
              bak = path <> ".v" <> show minV <> ".bak"
          in Right ((path, length parsed, bak), map snd parsed)
    writeFilePlan ((path, _, bak), events) = do
      let tmp = path <> ".migrate.tmp"
      BL.writeFile tmp (BL.concat [ encode (eventToJSON e) <> "\n" | e <- events ])
      renameFile path bak
      renameFile tmp path

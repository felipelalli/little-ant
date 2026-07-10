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
  ) where

import Control.Monad (unless)
import Data.Aeson (Value, eitherDecodeStrict, encode)
import Data.Aeson.Types (parseEither)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import LittleAnt.Config
import LittleAnt.Event
import System.Directory
import System.Environment (lookupEnv)
import System.FilePath ((</>))

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
            Right v -> case parseEither eventFromJSON (v :: Value) of
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

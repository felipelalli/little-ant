-- | The version boundary of the event log. Every event READ enters the
-- system through this module: the wire-side @(type, v)@ pair is resolved
-- to the current in-memory form here, and nowhere else — the domain fold
-- never sees an old shape.
--
-- Policy:
--
--   * additive change (new field, new event type): no bump, old events
--     parse as-is;
--   * breaking change: bump that event type's version in
--     'currentVersionFor' and add an upcaster under the OLD @(type, v)@
--     key — a small pure function producing the current 'Body';
--   * when the chain grows noisy, run @la migrate@ once and delete the
--     upcasters it made unreachable. Without a migration, an upcaster
--     lives exactly as long as events of its shape live in some log.
module LittleAnt.Upcast
  ( eventFromJSONVersioned
  , eventFromJSONWith
  , LegacyTable
  , legacyUpcasters
  ) where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.Text (Text)
import qualified Data.Text as T
import LittleAnt.Event
import LittleAnt.Types
  (parseAtomicity, parseAuthor, parseKind, parseMode)

-- | Upcasters for shapes no longer written, keyed by wire-side
-- @(type, v)@. Example: when @session_opened@ becomes @flow_opened@, the
-- entry @(("session_opened", 1), \\o -> FlowOpened \<$\> ...)@ keeps old
-- logs readable with zero version ifs in the domain.
legacyUpcasters :: LegacyTable
legacyUpcasters =
  [ ( ("raw_captured", 1)  -- renamed to fed, 2026-07-24 (feed rename)
    , \o -> Fed <$> o .: "raw" <*> o .: "content" )
  , ( ("brick_enriched", 1)  -- v1 carried the weight as "energy"
    , \o ->
        BrickEnriched
          <$> o .: "brick"
          <*> optEnumField "kind" parseKind o "kind"
          <*> o .:? "context"
          <*> o .:? "energy"
          <*> optEnumField "mode" parseMode o "mode"
          <*> optEnumField "atomicity" parseAtomicity o "atomicity"
          <*> o .:? "estimate_hours"
          <*> optEnumField "estimate_by" parseAuthor o "estimate_by" )
  ]

type LegacyTable = [((Text, Int), Object -> Parser Body)]

-- | The production read path: dispatch against 'legacyUpcasters'.
eventFromJSONVersioned :: Value -> Parser Event
eventFromJSONVersioned = eventFromJSONWith legacyUpcasters

-- | Table-parameterised variant so tests can prove the dispatch with a
-- synthetic legacy shape.
eventFromJSONWith :: LegacyTable -> Value -> Parser Event
eventFromJSONWith table = withObject "event" $ \o -> do
  eid <- o .: "id"
  at <- o .: "at"
  ty <- o .: "type"
  v <- o .: "v"
  d <- o .: "data"
  body <- withObject "data" (decodeBody ty v) d
  pure (Event eid at body)
  where
    decodeBody :: Text -> Int -> Object -> Parser Body
    decodeBody ty v obj
      | Just up <- lookup (ty, v) table = up obj
      | v == currentVersionFor ty = parseBody ty obj
      | otherwise = fail . T.unpack $
          "unknown version " <> T.pack (show v) <> " for event type " <> ty
            <> " — written by a newer binary? upgrade it, or run la migrate there"

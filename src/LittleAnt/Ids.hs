-- | Identity: content-addressed ids, git-style prefix references.
--
-- A brick's id is the sha256 of its original title; renaming never changes
-- identity. A collision is a feature: it forces a more specific title.
module LittleAnt.Ids
  ( Id (..)
  , mkTitleId
  , derivedId
  , shortId
  , ResolveError (..)
  , resolvePrefix
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..))
import qualified Data.ByteString.Lazy as BL
import Data.Digest.Pure.SHA (sha256, showDigest)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

newtype Id = Id { unId :: Text }
  deriving (Eq, Ord, Show)

instance ToJSON Id where
  toJSON = toJSON . unId

instance FromJSON Id where
  parseJSON v = Id <$> parseJSON v

hashText :: Text -> Text
hashText = T.pack . showDigest . sha256 . BL.fromStrict . TE.encodeUtf8

-- | Brick and party ids: sha256 of the canonical (trimmed) original title.
mkTitleId :: Text -> Id
mkTitleId = Id . hashText . T.strip

-- | Deterministic ids for secondary entities (skips, waits, comparisons,
-- delegations, effects, source links, sessions, raw inputs), derived from
-- the entity kind plus its defining parts (usually including the event
-- sequence number) so replays produce identical ids.
derivedId :: Text -> [Text] -> Id
derivedId kind parts = Id (hashText (T.intercalate "\x1f" (kind : parts)))

-- | Display prefix, git-style.
shortId :: Id -> Text
shortId (Id t) = T.take 7 t

data ResolveError
  = RefNotFound Text
  | RefAmbiguous Text [Id]
  deriving (Eq, Show)

-- | Resolve a (possibly short) hex prefix against a set of known ids.
resolvePrefix :: Text -> [Id] -> Either ResolveError Id
resolvePrefix raw candidates =
  let prefix = T.toLower (T.strip raw)
      matches = [ i | i <- candidates, prefix `T.isPrefixOf` unId i ]
   in case matches of
        [i] -> Right i
        []  -> Left (RefNotFound prefix)
        is  -> Left (RefAmbiguous prefix is)

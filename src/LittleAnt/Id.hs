module LittleAnt.Id (
  Handle (..),
  HandleKind (..),
  UUIDv7,
  allocateHandle,
  generateUUIDv7,
  handleBase,
  parseUUIDv7,
  renderHandle,
  renderUUIDv7,
  uuidV7FromEntropy,
)
where

import Data.Bits (shiftR, (.&.), (.|.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (GeneralCategory (..), generalCategory, isAlphaNum, ord, toLower)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Normalize (NormalizationMode (NFKD), normalize)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.Word (Word64)
import System.Entropy (getEntropy)
import Text.Printf (printf)

newtype UUIDv7 = UUIDv7 {renderUUIDv7 :: Text}
  deriving stock (Eq, Ord, Show)

data HandleKind = BrickHandle | RawHandle | EntityHandle
  deriving stock (Eq, Ord, Show)

newtype Handle = Handle {unHandle :: Text}
  deriving stock (Eq, Ord, Show)

parseUUIDv7 :: Text -> Either Text UUIDv7
parseUUIDv7 candidate
  | Text.length candidate /= 36 = Left "UUIDv7 must contain 36 characters."
  | fmap (Text.index candidate) [8, 13, 18, 23] /= "----" = Left "UUIDv7 separators are invalid."
  | Text.index candidate 14 /= '7' = Left "UUID does not use version 7."
  | Text.index candidate 19 `notElem` ("89abAB" :: String) = Left "UUID uses an invalid RFC variant."
  | not (Text.all isUuidCharacter candidate) = Left "UUIDv7 contains a non-hexadecimal character."
  | otherwise = Right (UUIDv7 (Text.toLower candidate))
 where
  isUuidCharacter character = character == '-' || character `elem` ("0123456789abcdefABCDEF" :: String)

generateUUIDv7 :: IO UUIDv7
generateUUIDv7 = do
  milliseconds <- floor . (* 1000) <$> getPOSIXTime
  entropy <- getEntropy 10
  case uuidV7FromEntropy milliseconds entropy of
    Left problem -> fail (Text.unpack problem)
    Right value -> pure value

uuidV7FromEntropy :: Word64 -> ByteString -> Either Text UUIDv7
uuidV7FromEntropy milliseconds entropy
  | milliseconds > 0xFFFFFFFFFFFF = Left "UUIDv7 timestamp exceeds 48 bits."
  | ByteString.length entropy < 10 = Left "UUIDv7 requires at least 10 entropy bytes."
  | otherwise = Right . UUIDv7 . Text.pack $ format bytes
 where
  randomBytes = ByteString.unpack (ByteString.take 10 entropy)
  entropyAt index = randomBytes !! index
  timestampByte shift = fromIntegral ((milliseconds `shiftR` shift) .&. 0xFF)
  bytes =
    [ timestampByte 40
    , timestampByte 32
    , timestampByte 24
    , timestampByte 16
    , timestampByte 8
    , timestampByte 0
    , 0x70 .|. ((entropyAt 0 `shiftR` 4) .&. 0x0F)
    , (entropyAt 0 .&. 0x0F) * 16 .|. ((entropyAt 1 `shiftR` 4) .&. 0x0F)
    , 0x80 .|. (entropyAt 2 .&. 0x3F)
    , entropyAt 3
    , entropyAt 4
    , entropyAt 5
    , entropyAt 6
    , entropyAt 7
    , entropyAt 8
    , entropyAt 9
    ]
  byteHex = printf "%02x"
  format source =
    concatMap byteHex (take 4 source)
      <> "-"
      <> concatMap byteHex (take 2 (drop 4 source))
      <> "-"
      <> concatMap byteHex (take 2 (drop 6 source))
      <> "-"
      <> concatMap byteHex (take 2 (drop 8 source))
      <> "-"
      <> concatMap byteHex (drop 10 source)

handleBase :: HandleKind -> Text -> Text
handleBase kind seed = case tokens of
  [] -> fallback kind
  [one] -> Text.take 12 one
  many -> Text.take 12 (Text.pack (fmap Text.head many))
 where
  normalized = normalize NFKD seed
  withoutMarks = Text.filter (not . isCombiningMark . generalCategory) normalized
  tokens = Text.words (Text.map toAsciiTokenCharacter withoutMarks)
  isCombiningMark category = category `elem` [NonSpacingMark, SpacingCombiningMark, EnclosingMark]
  toAsciiTokenCharacter character
    | ord character <= 127 && isAlphaNum character = toLower character
    | otherwise = ' '
  fallback = \case
    BrickHandle -> "brick"
    RawHandle -> "raw"
    EntityHandle -> "entity"

allocateHandle :: HandleKind -> Set Handle -> Text -> Handle
allocateHandle kind used seed = choose Nothing
 where
  base = handleBase kind seed
  choose suffix
    | candidate `Set.notMember` used = candidate
    | otherwise = choose (Just (maybe 2 (+ 1) suffix))
   where
    candidate = Handle (base <> maybe "" (Text.pack . show) suffix)

renderHandle :: HandleKind -> Handle -> Text
renderHandle kind (Handle handle) = sigil kind <> handle
 where
  sigil = \case
    BrickHandle -> "#"
    RawHandle -> "+"
    EntityHandle -> "@"

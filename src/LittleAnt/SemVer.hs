module LittleAnt.SemVer (
  validSemVer,
  compareSemVer,
)
where

import Data.Char (isAscii, isAsciiLower, isAsciiUpper, isDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Read qualified as Text

data SemVer = SemVer
  { semVerMajor :: Integer
  , semVerMinor :: Integer
  , semVerPatch :: Integer
  , semVerPrerelease :: [PrereleaseIdentifier]
  }
  deriving stock (Eq, Show)

data PrereleaseIdentifier
  = NumericIdentifier Integer
  | TextIdentifier Text
  deriving stock (Eq, Ord, Show)

instance Ord SemVer where
  compare left right =
    compare
      (semVerMajor left, semVerMinor left, semVerPatch left)
      (semVerMajor right, semVerMinor right, semVerPatch right)
      <> comparePrerelease (semVerPrerelease left) (semVerPrerelease right)

validSemVer :: Text -> Bool
validSemVer = maybe False (const True) . parseSemVer

compareSemVer :: Text -> Text -> Maybe Ordering
compareSemVer left right = compare <$> parseSemVer left <*> parseSemVer right

parseSemVer :: Text -> Maybe SemVer
parseSemVer value = do
  let (withoutBuild, buildSuffix) = Text.breakOn "+" value
      build = Text.drop 1 buildSuffix
  if Text.null buildSuffix || validIdentifiers False build then pure () else Nothing
  let (core, prereleaseSuffix) = Text.breakOn "-" withoutBuild
      prerelease = Text.drop 1 prereleaseSuffix
  prereleaseIdentifiers <-
    if Text.null prereleaseSuffix
      then pure []
      else traverse parsePrereleaseIdentifier =<< identifierParts True prerelease
  case Text.splitOn "." core of
    [major, minor, patch] ->
      SemVer
        <$> parseNumeric major
        <*> parseNumeric minor
        <*> parseNumeric patch
        <*> pure prereleaseIdentifiers
    _ -> Nothing

parsePrereleaseIdentifier :: Text -> Maybe PrereleaseIdentifier
parsePrereleaseIdentifier part
  | Text.all isDigit part = NumericIdentifier <$> parseNumeric part
  | otherwise = Just (TextIdentifier part)

parseNumeric :: Text -> Maybe Integer
parseNumeric part
  | Text.null part = Nothing
  | not (Text.all isDigit part) = Nothing
  | Text.length part > 1 && Text.head part == '0' = Nothing
  | otherwise = case Text.decimal part of
      Right (number, remainder) | Text.null remainder -> Just number
      _ -> Nothing

validIdentifiers :: Bool -> Text -> Bool
validIdentifiers numericLeadingZeroRule text = maybe False (const True) (identifierParts numericLeadingZeroRule text)

identifierParts :: Bool -> Text -> Maybe [Text]
identifierParts numericLeadingZeroRule text =
  let parts = Text.splitOn "." text
   in if not (null parts) && all (validIdentifier numericLeadingZeroRule) parts
        then Just parts
        else Nothing

validIdentifier :: Bool -> Text -> Bool
validIdentifier numericLeadingZeroRule part =
  not (Text.null part)
    && Text.all validIdentifierCharacter part
    && (not numericLeadingZeroRule || not (Text.all isDigit part) || Text.length part == 1 || Text.head part /= '0')

validIdentifierCharacter :: Char -> Bool
validIdentifierCharacter character =
  isAscii character
    && (isAsciiLower character || isAsciiUpper character || isDigit character || character == '-')

comparePrerelease :: [PrereleaseIdentifier] -> [PrereleaseIdentifier] -> Ordering
comparePrerelease [] [] = EQ
comparePrerelease [] _ = GT
comparePrerelease _ [] = LT
comparePrerelease left right = compare left right

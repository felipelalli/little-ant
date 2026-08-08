module LittleAnt.Reference (
  ReferenceCandidate (..),
  ReferenceKind (..),
  candidateCitation,
  renderRawAutocomplete,
  searchRawReferences,
)
where

import Data.Char (isAlphaNum, toLower)
import Data.List (sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Id
import LittleAnt.Model
import LittleAnt.Surface

data ReferenceKind = BrickReference | RawReference | EntityReference
  deriving stock (Eq, Ord, Show)
data ReferenceCandidate
  = ExistingRawCandidate UUIDv7 Handle Text Int
  | NewRawCandidate
  deriving stock (Eq, Show)

searchRawReferences :: Bool -> Text -> State -> [ReferenceCandidate]
searchRawReferences allowCreation query state = existing <> [NewRawCandidate | allowCreation]
 where
  existing =
    sortOn
      ordering
      [ ExistingRawCandidate (rawId raw) (rawHandle raw) (preview raw) rank
      | raw <- inboxRaws state
      , Just rank <- [matchRank needle raw]
      ]
  needle = normalizeQuery query
  ordering = \case
    ExistingRawCandidate identity handle content rank ->
      (rank, Text.toLower content, unHandle handle, renderUUIDv7 identity)
    NewRawCandidate -> (maxBound, "", "", "")

candidateCitation :: ReferenceCandidate -> Text
candidateCitation = \case
  ExistingRawCandidate _ handle content _ -> renderHandle RawHandle handle <> " \"" <> content <> "\""
  NewRawCandidate -> "New raw material..."

renderRawAutocomplete :: Text -> Int -> [ReferenceCandidate] -> ScreenModel
renderRawAutocomplete query selected candidates =
  ScreenModel
    ( [[Span Normal "Choose raw material:"], [], [Span Normal "› ", Span Normal query], []]
        <> zipWith renderCandidate [0 ..] candidates
        <> [[], [Span Dim "↑/↓ select · Enter choose · Esc back"]]
    )
    Nothing
 where
  renderCandidate index candidate =
    [ Span Normal (if index == selected then "> " else "  ")
    , Span (if index == selected then Selected else Normal) (candidateCitation candidate)
    ]

matchRank :: Text -> Raw -> Maybe Int
matchRank needle raw
  | Text.null needle = Just 50
  | needle == handle = Just 0
  | needle == content = Just 1
  | needle `Text.isPrefixOf` handle = Just 2
  | needle `Text.isPrefixOf` content = Just 3
  | all (`elem` Text.words content) (Text.words needle) = Just 4
  | needle `Text.isInfixOf` content = Just 5
  | distance <= 3 = Just (10 + distance)
  | otherwise = Nothing
 where
  handle = Text.toLower (unHandle (rawHandle raw))
  content = normalizeQuery (rawOriginal raw)
  distance = levenshtein needle content

normalizeQuery :: Text -> Text
normalizeQuery =
  Text.unwords
    . Text.words
    . Text.map normalizeCharacter
    . Text.toLower
    . Text.dropWhile (== '+')
 where
  normalizeCharacter character
    | isAlphaNum character = toLower character
    | otherwise = ' '

preview :: Raw -> Text
preview = Text.take 80 . Text.unwords . Text.words . rawOriginal

levenshtein :: Text -> Text -> Int
levenshtein left right = foldl (\_ value -> value) 0 finalRow
 where
  rightCharacters = Text.unpack right
  finalRow = foldl step [0 .. Text.length right] (Text.unpack left)
  step previous leftCharacter = case previous of
    [] -> []
    first : _ -> scanl cell (first + 1) (zip3 rightCharacters previous (drop 1 previous))
   where
    cell before (rightCharacter, diagonal, above) =
      minimum
        [ above + 1
        , before + 1
        , diagonal + if leftCharacter == rightCharacter then 0 else 1
        ]

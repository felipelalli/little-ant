-- A small terminal presentation layer, not a rewrite of stored material.
-- Unsupported Markdown stays visible. No HTML, ANSI, or external resources run.
module LittleAnt.Markdown (markdownLines, inlineMarkdown) where

import Data.Char (isAlphaNum, isControl, isSpace)
import Data.Maybe (isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Surface

markdownLines :: Int -> Text -> [ScreenLine]
markdownLines requestedWidth = blocks Nothing . Text.lines . Text.map safeCharacter
 where
  width = max 1 (min 96 requestedWidth)
  safeCharacter character
    | character == '\t' = ' '
    | character == '\n' || not (isControl character) = character
    | otherwise = '\xfffd'
  blocks _ [] = []
  blocks fence (line : rest)
    | Just marker <- fence =
        if closesFence marker line
          then wrapScreenLine width [Span Dim line] <> [[]] <> blocks Nothing rest
          else wrapScreenLine width [Span Code line] <> blocks fence rest
    | Just marker <- opensFence line =
        wrapScreenLine width [Span Dim line] <> blocks (Just marker) rest
    | Text.null (Text.strip line) = [] : blocks Nothing rest
    | Just heading <- headingText line =
        layoutWords width False [Span Heading heading] <> [[]] <> blocks Nothing rest
    | "    " `Text.isPrefixOf` line = wrapScreenLine width [Span Code line] <> blocks Nothing rest
    | protectedLine line =
        let indent = Text.takeWhile isSpace line
            (prefix, colon) = Text.breakOn ":" (Text.stripStart line)
            styled = if metadataLabel line then Span Strong (prefix <> ":") : inlineMarkdown (Text.drop 1 colon) else inlineMarkdown (Text.stripStart line)
            rows = if textDisplayWidth indent >= width then wrapScreenLine width [Span Normal line] else fmap (\row -> [Span Normal indent | not (Text.null indent)] <> row) (layoutWords (width - textDisplayWidth indent) False styled)
            material = "Material (" `Text.isPrefixOf` prefix && metadataLabel line
         in [[] | material] <> rows <> [[] | material] <> blocks Nothing rest
    | otherwise =
        let (continuation, remaining) = span ordinaryLine rest
            paragraph = Text.unwords (Text.strip <$> (line : continuation))
         in layoutWords width True (inlineMarkdown paragraph) <> blocks Nothing remaining
  ordinaryLine line = not (Text.null (Text.strip line)) && not (protectedLine line) && isNothing (headingText line)

opensFence :: Text -> Maybe Text
opensFence line
  | "```" `Text.isPrefixOf` stripped = Just (Text.takeWhile (== '`') stripped)
  | "~~~" `Text.isPrefixOf` stripped = Just (Text.takeWhile (== '~') stripped)
  | otherwise = Nothing
 where
  stripped = Text.stripStart line

closesFence :: Text -> Text -> Bool
closesFence marker line = marker `Text.isPrefixOf` stripped && Text.all (== Text.head marker) stripped
 where
  stripped = Text.strip line

headingText :: Text -> Maybe Text
headingText line =
  let (marker, rest) = Text.span (== '#') (Text.stripStart line)
   in if not (Text.null marker) && Text.length marker <= 6 && " " `Text.isPrefixOf` rest
        then Just (Text.strip rest)
        else Nothing

-- Literal lines, bullets, tables, quoted passages, handles, and metadata retain
-- their line boundaries and left alignment. Only prose paragraphs are reflowed.
protectedLine :: Text -> Bool
protectedLine line = indented || symbolic || numbered || label
 where
  stripped = Text.stripStart line
  indented = line /= stripped
  symbolic = maybe False (not . isAlphaNum . fst) (Text.uncons stripped)
  (digits, afterDigits) = Text.span (`elem` ['0' .. '9']) stripped
  numbered = not (Text.null digits) && any (`Text.isPrefixOf` afterDigits) [". ", ") "]
  label = metadataLabel line

metadataLabel :: Text -> Bool
metadataLabel line = not (Text.null colon) && not (Text.null prefix) && Text.length prefix <= 40 && Text.all (\c -> isAlphaNum c || c `elem` [' ', '_', '/', '(', ')']) prefix
 where
  (prefix, colon) = Text.breakOn ":" (Text.stripStart line)

inlineMarkdown :: Text -> ScreenLine
inlineMarkdown = parse Normal
 where
  parse _ text | Text.null text = []
  parse role text
    | "\\" `Text.isPrefixOf` text
    , Just (character, rest) <- Text.uncons (Text.drop 1 text)
    , character `elem` ("\\`*_[]#" :: String) =
        Span role (Text.singleton character) : parse role rest
    | "`" `Text.isPrefixOf` text =
        let marker = Text.takeWhile (== '`') text
            (body, suffix) = Text.breakOn marker (Text.drop (Text.length marker) text)
         in if Text.null suffix
              then literal role text
              else Span Code body : parse role (Text.drop (Text.length marker) suffix)
    | Just (marker, style) <- firstDelimiter text =
        let (body, suffix) = Text.breakOn marker (Text.drop (Text.length marker) text)
         in if Text.null suffix || Text.null body || isSpace (Text.head body) || isSpace (Text.last body)
              then literal role text
              else parse style body <> parse role (Text.drop (Text.length marker) suffix)
    | "[" `Text.isPrefixOf` text
    , (label, suffix) <- Text.breakOn "](" (Text.drop 1 text)
    , not (Text.null suffix)
    , (target, ending) <- Text.breakOn ")" (Text.drop 2 suffix)
    , not (Text.null ending) =
        [Span Link label, Span Dim " (", Span Link target, Span Dim ")"] <> parse role (Text.drop 1 ending)
    | otherwise = literal role text
  literal role text = case Text.uncons text of
    Nothing -> []
    Just (character, rest) -> Span role (Text.singleton character) : parse role rest
  firstDelimiter text = first [(marker, role) | (marker, role) <- [("**", Strong), ("*", Emphasis)], marker `Text.isPrefixOf` text]
  first [] = Nothing
  first (value : _) = Just value

layoutWords :: Int -> Bool -> ScreenLine -> [ScreenLine]
layoutWords width justify spans = zipWith render [0 ..] rows
 where
  rows = pack [] 0 (styledWords spans)
  pack current _ [] = [current | not (null current)]
  pack current cells (word : rest)
    | wordWidth > width =
        let chunks = wrapScreenLine width word
         in [current | not (null current)] <> fmap pure (init chunks) <> pack [last chunks] (textDisplayWidth (plainLine (last chunks))) rest
    | cells + separator + wordWidth <= width = pack (current <> [word]) (cells + separator + wordWidth) rest
    | otherwise = current : pack [word] wordWidth rest
   where
    wordWidth = textDisplayWidth (plainLine word)
    separator = if null current then 0 else 1
  render index wordsOnLine =
    let gaps = max 0 (length wordsOnLine - 1)
        used = sum (textDisplayWidth . plainLine <$> wordsOnLine) + gaps
        extra = if justify && index < length rows - 1 && gaps > 0 then max 0 (width - used) else 0
        spaceAt gap = 1 + extra `div` max 1 gaps + if gap < extra `mod` max 1 gaps then 1 else 0
     in concat (zipWith (\wordIndex word -> [Span Normal (Text.replicate (spaceAt (wordIndex - 1)) " ") | wordIndex > 0] <> word) [0 ..] wordsOnLine)

styledWords :: ScreenLine -> [ScreenLine]
styledWords spans = reverse (finish current wordsSoFar)
 where
  (wordsSoFar, current) = foldl addSpan ([], []) spans
  finish word wordsDone = [reverse word | not (null word)] <> wordsDone
  addSpan state (Span Code text) = append state (Span Code text)
  addSpan state (Span role text) = foldl (addCharacter role) state (Text.unpack text)
  addCharacter role (done, word) character
    | isSpace character = (finish word done, [])
    | otherwise = append (done, word) (Span role (Text.singleton character))
  append (done, Span previousRole previousText : word) (Span role text)
    | previousRole == role = (done, Span role (previousText <> text) : word)
  append (done, word) spanValue = (done, spanValue : word)

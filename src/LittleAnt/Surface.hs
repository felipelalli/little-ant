module LittleAnt.Surface (
  Cursor (..),
  EditorCommand (..),
  EditorState (..),
  ScreenLine,
  ScreenModel (..),
  SemanticRole (..),
  Span (..),
  applyEditorCommand,
  plainLine,
  renderPlain,
  selectedEditor,
  textDisplayWidth,
  wrapDisplayText,
  wrapScreenLine,
)
where

import Data.Text (Text)
import Data.Text qualified as Text
import Graphics.Text.Width (safeWcswidth)

data SemanticRole
  = Normal
  | Dim
  | Accent
  | Selected
  | Warning
  | Heading
  | Strong
  | Emphasis
  | Code
  | Link
  | -- | A due date that matters now, such as an agenda deadline mark.
    Urgent
  | -- | A softer date mark, such as an agenda best-before day.
    Caution
  | -- | Today's calendar cell; it looks selected without being the selection.
    Today
  | -- | The calendar cell of the selected agenda row.
    Pointed
  | -- | An agenda opening, the mildest dated fact.
    Opening
  | -- | Ends the rows a viewport keeps pinned above the scrolling body.
    PinBoundary
  deriving stock (Eq, Ord, Show)

data Span = Span
  { spanRole :: SemanticRole
  , spanText :: Text
  }
  deriving stock (Eq, Show)

type ScreenLine = [Span]

data Cursor = Cursor
  { cursorColumn :: Int
  , cursorRow :: Int
  }
  deriving stock (Eq, Show)

data ScreenModel = ScreenModel
  { screenLines :: [ScreenLine]
  , screenCursor :: Maybe Cursor
  }
  deriving stock (Eq, Show)

data EditorState = EditorState
  { editorBefore :: Text
  , editorAfter :: Text
  , editorSelection :: Maybe Text
  }
  deriving stock (Eq, Show)

data EditorCommand
  = InsertText Text
  | DeleteBackward
  | DeleteForward
  | MoveEditorLeft
  | MoveEditorRight
  deriving stock (Eq, Show)

selectedEditor :: Text -> EditorState
selectedEditor text = EditorState "" "" (Just text)

applyEditorCommand :: EditorCommand -> EditorState -> EditorState
applyEditorCommand command state@EditorState{editorBefore, editorAfter, editorSelection} =
  case editorSelection of
    Just selected ->
      case command of
        InsertText text -> EditorState text "" Nothing
        DeleteBackward -> EditorState "" "" Nothing
        DeleteForward -> EditorState "" "" Nothing
        MoveEditorLeft -> EditorState "" selected Nothing
        MoveEditorRight -> EditorState selected "" Nothing
    Nothing ->
      case command of
        InsertText text -> state{editorBefore = editorBefore <> text}
        DeleteBackward ->
          case Text.unsnoc editorBefore of
            Nothing -> state
            Just (remaining, _) -> state{editorBefore = remaining}
        DeleteForward ->
          case Text.uncons editorAfter of
            Nothing -> state
            Just (_, remaining) -> state{editorAfter = remaining}
        MoveEditorLeft ->
          case Text.unsnoc editorBefore of
            Nothing -> state
            Just (remaining, character) ->
              state{editorBefore = remaining, editorAfter = Text.cons character editorAfter}
        MoveEditorRight ->
          case Text.uncons editorAfter of
            Nothing -> state
            Just (character, remaining) ->
              state{editorBefore = Text.snoc editorBefore character, editorAfter = remaining}

plainLine :: ScreenLine -> Text
plainLine = Text.concat . fmap spanText

renderPlain :: ScreenModel -> Text
renderPlain = Text.intercalate "\n" . fmap plainLine . screenLines

textDisplayWidth :: Text -> Int
textDisplayWidth = max 0 . safeWcswidth . Text.unpack

-- Keep explicit line breaks and hard-wrap long words (handles, URLs, and CJK
-- text) as well as ordinary prose. Layout is measured in terminal cells.
wrapDisplayText :: Int -> Text -> [Text]
wrapDisplayText requestedWidth = concatMap wrapLine . Text.splitOn "\n"
 where
  width = max 1 requestedWidth
  wrapLine line
    | textDisplayWidth line <= width = [line]
    | otherwise =
        let (chunk, rest) = splitCells width line
            (beforeSpace, afterSpace) = Text.breakOnEnd " " chunk
         in if not (Text.null beforeSpace) && not (Text.null (Text.strip beforeSpace))
              then Text.stripEnd beforeSpace : wrapLine (afterSpace <> rest)
              else chunk : wrapLine rest

splitCells :: Int -> Text -> (Text, Text)
splitCells width = go 0 ""
 where
  go cells prefix remaining = case Text.uncons remaining of
    Nothing -> (prefix, "")
    Just (character, rest)
      | cells + textDisplayWidth (Text.singleton character) > width && not (Text.null prefix) -> (prefix, remaining)
      | otherwise -> go (cells + textDisplayWidth (Text.singleton character)) (Text.snoc prefix character) rest

wrapScreenLine :: Int -> ScreenLine -> [ScreenLine]
wrapScreenLine requestedWidth spans = reverse (reverse current : completed)
 where
  width = max 1 requestedWidth
  (completed, current, _) = foldl addSpan ([], [], 0) spans
  addSpan state (Span role text) = Text.foldl' (addCharacter role) state text
  addCharacter role (rows, line, cells) character
    | character == '\n' = (reverse line : rows, [], 0)
    | cells + charWidth > width && not (null line) = (reverse line : rows, [Span role (Text.singleton character)], charWidth)
    | otherwise = (rows, appendCharacter line, cells + charWidth)
   where
    charWidth = textDisplayWidth (Text.singleton character)
    appendCharacter (Span previousRole previousText : rest)
      | previousRole == role = Span role (Text.snoc previousText character) : rest
    appendCharacter previous = Span role (Text.singleton character) : previous

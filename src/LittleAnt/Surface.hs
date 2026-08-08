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
)
where

import Data.Text (Text)
import Data.Text qualified as Text

data SemanticRole
  = Normal
  | Dim
  | Accent
  | Selected
  | Warning
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

module LittleAnt.Terminal (
  ColorMode (..),
  TerminalInput (..),
  displayWidth,
  eventToInput,
  roleAttribute,
  screenImage,
  withTerminal,
  withTerminalResources,
)
where

import Control.Exception (bracket)
import Data.Text qualified as Text
import Graphics.Text.Width (safeWcswidth)
import Graphics.Vty (
  Attr,
  Event (..),
  Image,
  Key (..),
  Modifier,
  Vty,
  bold,
  char,
  cyan,
  defAttr,
  dim,
  emptyImage,
  horizCat,
  picForImage,
  reverseVideo,
  shutdown,
  string,
  update,
  vertCat,
  withForeColor,
  withStyle,
 )
import Graphics.Vty.Config (defaultConfig)
import Graphics.Vty.CrossPlatform qualified as CrossPlatform
import LittleAnt.Surface

data ColorMode = ColorEnabled | Monochrome
  deriving stock (Eq, Show)

data TerminalInput
  = Printable Char [Modifier]
  | Enter [Modifier]
  | Escape [Modifier]
  | Backspace [Modifier]
  | Delete [Modifier]
  | ArrowLeft [Modifier]
  | ArrowRight [Modifier]
  | ArrowUp [Modifier]
  | ArrowDown [Modifier]
  | Resized Int Int
  deriving stock (Eq, Show)

eventToInput :: Event -> Maybe TerminalInput
eventToInput = \case
  EvKey (KChar c) modifiers -> Just (Printable c modifiers)
  EvKey KEnter modifiers -> Just (Enter modifiers)
  EvKey KEsc modifiers -> Just (Escape modifiers)
  EvKey KBS modifiers -> Just (Backspace modifiers)
  EvKey KDel modifiers -> Just (Delete modifiers)
  EvKey KLeft modifiers -> Just (ArrowLeft modifiers)
  EvKey KRight modifiers -> Just (ArrowRight modifiers)
  EvKey KUp modifiers -> Just (ArrowUp modifiers)
  EvKey KDown modifiers -> Just (ArrowDown modifiers)
  EvResize width height -> Just (Resized width height)
  _ -> Nothing

displayWidth :: Text.Text -> Int
displayWidth = safeWcswidth . Text.unpack

roleAttribute :: ColorMode -> SemanticRole -> Attr
roleAttribute mode role =
  case role of
    Normal -> defAttr
    Dim -> defAttr `withStyle` dim
    Accent ->
      case mode of
        ColorEnabled -> (defAttr `withForeColor` cyan) `withStyle` bold
        Monochrome -> defAttr `withStyle` bold
    Selected -> defAttr `withStyle` reverseVideo
    Warning -> defAttr `withStyle` bold

spanImage :: ColorMode -> Span -> Image
spanImage mode (Span role text)
  | Text.null text = emptyImage
  | Text.length text == 1 = char (roleAttribute mode role) (Text.head text)
  | otherwise = string (roleAttribute mode role) (Text.unpack text)

lineImage :: ColorMode -> ScreenLine -> Image
lineImage mode = horizCat . fmap (spanImage mode)

screenImage :: ColorMode -> ScreenModel -> Image
screenImage mode = vertCat . fmap (lineImage mode) . screenLines

withTerminalResources :: IO resource -> (resource -> IO ()) -> (resource -> IO a) -> IO a
withTerminalResources = bracket

withTerminal :: ColorMode -> ScreenModel -> (Vty -> IO a) -> IO a
withTerminal mode model action =
  withTerminalResources
    (CrossPlatform.mkVty defaultConfig)
    shutdown
    (\vty -> update vty (picForImage (screenImage mode model)) >> action vty)

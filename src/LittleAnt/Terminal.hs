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
import Data.Text.Encoding qualified as TextEncoding
import Graphics.Vty (
  Attr,
  Button (..),
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
  green,
  horizCat,
  italic,
  magenta,
  picForImage,
  red,
  reverseVideo,
  shutdown,
  string,
  underline,
  update,
  vertCat,
  withForeColor,
  withStyle,
  yellow,
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
  | PageUp [Modifier]
  | PageDown [Modifier]
  | Home [Modifier]
  | End [Modifier]
  | WheelUp [Modifier]
  | WheelDown [Modifier]
  | Pasted Text.Text
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
  EvKey KPageUp modifiers -> Just (PageUp modifiers)
  EvKey KPageDown modifiers -> Just (PageDown modifiers)
  EvKey KHome modifiers -> Just (Home modifiers)
  EvKey KEnd modifiers -> Just (End modifiers)
  EvMouseDown _ _ BScrollUp modifiers -> Just (WheelUp modifiers)
  EvMouseDown _ _ BScrollDown modifiers -> Just (WheelDown modifiers)
  EvPaste bytes -> either (const Nothing) (Just . Pasted) (TextEncoding.decodeUtf8' bytes)
  EvResize width height -> Just (Resized width height)
  _ -> Nothing

displayWidth :: Text.Text -> Int
displayWidth = textDisplayWidth

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
    Today -> defAttr `withStyle` reverseVideo
    Pointed -> (defAttr `withStyle` underline) `withStyle` bold
    Opening -> case mode of
      ColorEnabled -> defAttr `withForeColor` green
      Monochrome -> defAttr
    PinBoundary -> defAttr
    Habit -> case mode of
      ColorEnabled -> defAttr `withForeColor` magenta
      Monochrome -> defAttr `withStyle` italic
    Warning -> defAttr `withStyle` bold
    Heading -> roleAttribute mode Accent
    Strong -> defAttr `withStyle` bold
    Emphasis -> defAttr `withStyle` italic
    Code -> case mode of
      ColorEnabled -> defAttr `withForeColor` cyan
      Monochrome -> defAttr `withStyle` underline
    Link -> case mode of
      ColorEnabled -> (defAttr `withForeColor` cyan) `withStyle` underline
      Monochrome -> defAttr `withStyle` underline
    Urgent -> case mode of
      ColorEnabled -> (defAttr `withForeColor` red) `withStyle` bold
      Monochrome -> defAttr `withStyle` bold
    Caution -> case mode of
      ColorEnabled -> (defAttr `withForeColor` yellow) `withStyle` bold
      Monochrome -> defAttr `withStyle` bold

spanImage :: ColorMode -> Span -> Image
spanImage mode (Span role text)
  | Text.null text = emptyImage
  | Text.length text == 1 = char (roleAttribute mode role) (Text.head text)
  | otherwise = string (roleAttribute mode role) (Text.unpack text)

lineImage :: ColorMode -> ScreenLine -> Image
lineImage mode spans
  | all (Text.null . spanText) spans = char defAttr ' '
  | otherwise = horizCat (fmap (spanImage mode) spans)

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

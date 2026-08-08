module Main (main) where

import Control.Exception (SomeException, throwIO, try)
import Data.IORef
import Data.List (nub)
import Data.Text qualified as Text
import Graphics.Vty (Event (EvResize))
import LittleAnt.Foundation
import LittleAnt.Surface
import LittleAnt.Terminal
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "unit and property"
    [ testCase "random-purpose registry is closed and unique" $ do
        length randomPurposeRegistry @?= 13
        let names = fmap randomPurposeName randomPurposeRegistry
        length names @?= length (nub names)
    , testCase "plain rendering ignores styling roles" $ do
        let model = ScreenModel [[Span Dim "[", Span Accent "n", Span Dim "]", Span Normal "ext"]] Nothing
        renderPlain model @?= "[n]ext"
    , testCase "monochrome accents retain emphasis without color" $
        assertBool "color and monochrome attributes must differ" (roleAttribute ColorEnabled Accent /= roleAttribute Monochrome Accent)
    , testCase "selection uses a stable non-color role" $
        roleAttribute ColorEnabled Selected @?= roleAttribute Monochrome Selected
    , testCase "selected input is replaced by the first printable text" $
        applyEditorCommand (InsertText "new") (selectedEditor "old")
          @?= EditorState "new" "" Nothing
    , testCase "an arrow collapses selected input without editing" $ do
        applyEditorCommand MoveEditorLeft (selectedEditor "old")
          @?= EditorState "" "old" Nothing
        applyEditorCommand MoveEditorRight (selectedEditor "old")
          @?= EditorState "old" "" Nothing
    , testCase "backspace edits or clears selected input" $ do
        applyEditorCommand DeleteBackward (EditorState "ab" "cd" Nothing)
          @?= EditorState "a" "cd" Nothing
        applyEditorCommand DeleteBackward (selectedEditor "old")
          @?= EditorState "" "" Nothing
    , testCase "Vty resize is a presentation input" $
        eventToInput (EvResize 80 24) @?= Just (Resized 80 24)
    , testCase "display width handles wide and accented text" $ do
        displayWidth "ação" @?= 4
        displayWidth "界" @?= 2
    , testCase "terminal resources are released after interruption" $ do
        released <- newIORef False
        result <-
          try
            ( withTerminalResources
                (pure ())
                (\_ -> writeIORef released True)
                (\_ -> throwIO (userError "injected interruption"))
            ) ::
            IO (Either SomeException ())
        assertBool "injected failure must escape" (either (const True) (const False) result)
        readIORef released >>= assertBool "terminal cleanup must run"
    , testProperty "plain rendering preserves concatenated text" $ \parts ->
        let texts = fmap Text.pack (parts :: [String])
            line = zipWith Span (cycle [Normal, Dim, Accent, Selected]) texts
         in plainLine line == Text.concat texts
    ]

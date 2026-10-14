module Main (main) where

import Data.List (isInfixOf)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.FilePath ((</>))
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "end-to-end package boundary"
    [ testCase "the package exposes only lant and relocates its private runner" $ do
        root <- findProjectRoot
        cabalFile <- readFile (root </> "little-ant.cabal")
        flakeFile <- readFile (root </> "flake.nix")
        mainFile <- readFile (root </> "app/Main.hs")
        assertBool "lant executable must exist" ("executable lant" `isInfixOf` cabalFile)
        assertBool "retired executable must not exist" (not ("executable la\n" `isInfixOf` cabalFile))
        assertBool "the private runner component must exist" ("executable lant-pack-runner" `isInfixOf` cabalFile)
        assertBool "the release package must relocate the runner out of bin" ("mv $out/bin/lant-pack-runner $out/libexec/little-ant/lant-pack-runner" `isInfixOf` flakeFile)
        assertBool "the Nix artifact must carry the alpha release identity" ("version = \"1.0.0-alpha.2\"" `isInfixOf` flakeFile)
        assertBool "the CLI must report the same alpha release identity" ("lant 1.0.0-alpha.2" `isInfixOf` mainFile)
    , testCase "the CLI E2E scripts cover Feed, migration, and durable restart" $ do
        root <- findProjectRoot
        doesFileExist (root </> "test/e2e/s01-cli.sh") >>= assertBool "S01 CLI E2E script must exist"
        migrationTest <- readFile (root </> "test/s10-migration/Spec.hs")
        assertBool "the migration E2E must exercise restart recovery" ("a migrated Brick completes the alpha daily loop after restart" `isInfixOf` migrationTest)
    ]

findProjectRoot :: IO FilePath
findProjectRoot = getCurrentDirectory >>= walk
 where
  walk directory = do
    found <- doesFileExist (directory </> "little-ant.cabal")
    if found
      then pure directory
      else do
        let parent = directory </> ".."
        if parent == directory
          then assertFailure "could not locate project root"
          else walk parent

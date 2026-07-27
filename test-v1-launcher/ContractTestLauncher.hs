-- | Cabal launcher that makes the package's contract driver available to the
-- immutable v1 harness.  An explicitly configured driver still wins.
module ContractTestLauncher (main) where

import Data.Char (isSpace)
import System.Directory (doesFileExist, findExecutable)
import System.Environment (getArgs, lookupEnv, setEnv)
import System.Exit (ExitCode (..), exitWith)
import System.Process (rawSystem, readProcessWithExitCode)

main :: IO ()
main = do
  configured <- lookupEnv "LANT_V1_TEST_DRIVER"
  case configured of
    Just _ -> pure ()
    Nothing -> resolveBuiltExecutable "lant-v1-test-driver"
      >>= setEnv "LANT_V1_TEST_DRIVER"
  harness <- resolveBuiltExecutable "lant-v1-contract-harness"
  arguments <- getArgs
  rawSystem harness arguments >>= exitWith

resolveBuiltExecutable :: String -> IO FilePath
resolveBuiltExecutable name = do
  onPath <- findExecutable name
  case onPath of
    Just executable -> pure executable
    Nothing -> do
      (exitCode, output, diagnostics) <- readProcessWithExitCode
        "cabal" ["list-bin", name] ""
      let executable = trim output
      exists <- doesFileExist executable
      case (exitCode, exists) of
        (ExitSuccess, True) -> pure executable
        _ -> fail ("could not resolve " <> name <> ": " <> diagnostics)

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

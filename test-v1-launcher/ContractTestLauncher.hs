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
  ensureExecutableEnv "LANT_V1_TEST_DRIVER" "lant-v1-test-driver"
  ensureExecutableEnv "LANT_PACK_RUNNER" "lant-pack-runner"
  harness <- resolveBuiltExecutable "lant-v1-contract-harness"
  arguments <- getArgs
  rawSystem harness arguments >>= exitWith

ensureExecutableEnv :: String -> String -> IO ()
ensureExecutableEnv variable executableName = do
  configured <- lookupEnv variable
  case configured of
    Just _ -> pure ()
    Nothing -> resolveBuiltExecutable executableName >>= setEnv variable

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

module VaultTest (withShortRuntime, waitForAgent) where

import Control.Concurrent (MVar, threadDelay, tryReadMVar)
import LittleAnt.Error
import LittleAnt.Vault.Agent
import System.Directory (doesPathExist)
import System.IO.Temp (withTempDirectory)
import Test.Tasty.HUnit

-- Unix sockets have a portable address limit independent of TMPDIR depth.
-- temporary creates this unique directory privately and removes it afterwards.
withShortRuntime :: (FilePath -> IO a) -> IO a
withShortRuntime = withTempDirectory "/tmp" "lant-vault-"

waitForAgent :: FilePath -> MVar (Either AppError ()) -> Int -> Assertion
waitForAgent path finished attempts = do
  terminated <- tryReadMVar finished
  case terminated of
    Just result -> assertFailure ("vault agent terminated before readiness: " <> show result)
    Nothing | attempts <= 0 -> assertFailure ("timed out waiting for vault agent: " <> path)
    Nothing -> do
      exists <- doesPathExist path
      ready <-
        if exists
          then either (const False) (const True) <$> sendVaultAgentRequest path agentStatusRequest
          else pure False
      if ready then pure () else threadDelay 10_000 >> waitForAgent path finished (attempts - 1)

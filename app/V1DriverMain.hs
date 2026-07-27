-- | Stdin/stdout bridge for the Little Ant 1.0 executable contract.
module Main (main) where

import Data.Aeson (encode)
import qualified Data.ByteString.Lazy.Char8 as LBS8
import LittleAnt.V1.Contract
  (DriverResponse (..), decodeAndRunContractRequest)
import LittleAnt.V1.Implementation (contractRegistry)
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  input <- LBS8.getContents
  let response
        | null arguments =
            decodeAndRunContractRequest contractRegistry input
        | otherwise = DriverResponse
            { driverResponseProtocolVersion = 1
            , driverResponseOk = False
            , driverResponseResults = []
            , driverResponseDiagnostics =
                ["lant-v1-test-driver accepts no command-line arguments"]
            }
  LBS8.putStrLn (encode response)

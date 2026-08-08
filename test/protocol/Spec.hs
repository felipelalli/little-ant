module Main (main) where

import Data.Aeson (encode)
import Data.ByteString.Lazy.Char8 qualified as ByteString
import LittleAnt.Conformance
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "protocol and golden"
    [ testCase "contract descriptors remain structured data" $ do
        let descriptor =
              ContractDescriptor
                { evidenceId = "S00-DESCRIPTOR-001"
                , rules = ["MIG-019"]
                , screens = []
                , flow = Nothing
                , kind = ProtocolEvidence
                , specHashes = [SpecHash "sha256:fixture"]
                , obligations = ["gate"]
                }
        ByteString.unpack (encode descriptor)
          @?= "{\"evidenceId\":\"S00-DESCRIPTOR-001\",\"flow\":null,\"kind\":\"ProtocolEvidence\",\"obligations\":[\"gate\"],\"rules\":[\"MIG-019\"],\"screens\":[],\"specHashes\":[\"sha256:fixture\"]}"
    ]

{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (forM)
import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Aeson (eitherDecodeStrict')
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import LittleAnt.Error (AppError)
import LittleAnt.Pack.Format
import LittleAnt.Pack.Trust (authenticatePack, authenticatedPackIdentity)
import LittleAnt.Store (sha256Hex)
import System.Directory (doesDirectoryExist, listDirectory)
import System.Entropy (getEntropy)
import System.Environment (getArgs)
import System.FilePath (makeRelative, splitDirectories, (</>))
import System.IO (hPutStrLn, stderr)

packRoot :: FilePath
packRoot = "packs/standard"

payloadRoot :: FilePath
payloadRoot = packRoot </> "payload"

main :: IO ()
main =
  getArgs >>= \case
    ["refresh-manifest"] -> refreshManifest
    ["new-signature"] -> createSignature
    ["archive"] -> createArchive
    ["verify"] -> verifyArchive
    _ -> die "usage: cabal exec runghc -- -isrc tools/rebuild-standard-pack.hs refresh-manifest|new-signature|archive|verify"

refreshManifest :: IO ()
refreshManifest = do
  manifest <- readTyped (packRoot </> "pack.json")
  payload <- readPayload
  let updated = manifest{packFiles = fmap payloadRecord (Map.toAscList payload)}
  bytes <- rightOrDie (encodePackManifest updated)
  ByteString.writeFile (packRoot </> "pack.json") bytes
  putStrLn ("refreshed manifest: " <> show (Map.size payload) <> " payload files")

createSignature :: IO ()
createSignature = do
  manifestBytes <- ByteString.readFile (packRoot </> "pack.json")
  secretBytes <- getEntropy 32
  secret <- cryptoOrDie (Ed25519.secretKey secretBytes)
  let public = Ed25519.toPublic secret
      publicBytes = convert public
      document =
        PackSignatureDocument
          { packSignaturePublicKey = encodeBase64 publicBytes
          , packSignatureKeyFingerprint = sha256Hex publicBytes
          , packSignatureValue = encodeBase64 (convert (Ed25519.sign secret public manifestBytes))
          }
  bytes <- rightOrDie (encodePackSignature document)
  ByteString.writeFile (packRoot </> "signature.json") bytes
  putStrLn ("created one-off built-in signature: " <> Text.unpack (packSignatureKeyFingerprint document))

createArchive :: IO ()
createArchive = do
  manifestBytes <- ByteString.readFile (packRoot </> "pack.json")
  signatureBytes <- ByteString.readFile (packRoot </> "signature.json")
  payload <- readPayload
  archive <- rightOrDie (buildCanonicalPackArchive manifestBytes signatureBytes payload)
  ByteString.writeFile (packRoot </> "standard.lantpack") archive
  structural <- rightOrDie (validatePackArchive archive)
  authenticated <- rightOrDie (authenticatePack structural)
  print (authenticatedPackIdentity authenticated)

verifyArchive :: IO ()
verifyArchive = do
  manifestBytes <- ByteString.readFile (packRoot </> "pack.json")
  signatureBytes <- ByteString.readFile (packRoot </> "signature.json")
  payload <- readPayload
  expected <- rightOrDie (buildCanonicalPackArchive manifestBytes signatureBytes payload)
  actual <- ByteString.readFile (packRoot </> "standard.lantpack")
  if expected /= actual
    then die "standard.lantpack is not the canonical archive of the committed source tree"
    else do
      structural <- rightOrDie (validatePackArchive actual)
      authenticated <- rightOrDie (authenticatePack structural)
      print (authenticatedPackIdentity authenticated)

readPayload :: IO (Map Text ByteString)
readPayload = do
  files <- listFiles payloadRoot
  Map.fromList
    <$> forM
      files
      ( \path -> do
          bytes <- ByteString.readFile path
          pure (portablePath (makeRelative payloadRoot path), bytes)
      )

listFiles :: FilePath -> IO [FilePath]
listFiles directory = do
  entries <- sort <$> listDirectory directory
  fmap concat . forM entries $ \entry -> do
    let path = directory </> entry
    directoryEntry <- doesDirectoryExist path
    if directoryEntry then listFiles path else pure [path]

portablePath :: FilePath -> Text
portablePath = Text.intercalate "/" . fmap Text.pack . splitDirectories

payloadRecord :: (Text, ByteString) -> PayloadFile
payloadRecord (path, bytes) =
  PayloadFile
    { payloadFilePath = path
    , payloadFileLength = fromIntegral (ByteString.length bytes)
    , payloadFileMediaType = mediaType path
    , payloadFileSha256 = sha256Hex bytes
    }

mediaType :: Text -> Text
mediaType path
  | ".lua" `Text.isSuffixOf` path = "text/x-lua; charset=utf-8"
  | ".json" `Text.isSuffixOf` path = "application/json"
  | ".md" `Text.isSuffixOf` path = "text/markdown; charset=utf-8"
  | otherwise = "application/octet-stream"

readTyped :: FilePath -> IO PackManifest
readTyped path = do
  bytes <- ByteString.readFile path
  either (\problem -> die (path <> ": " <> problem)) pure (eitherDecodeStrict' bytes)

rightOrDie :: Either AppError value -> IO value
rightOrDie = either (die . show) pure

cryptoOrDie :: CryptoFailable value -> IO value
cryptoOrDie = \case
  CryptoPassed value -> pure value
  CryptoFailed problem -> die (show problem)

encodeBase64 :: ByteString -> Text
encodeBase64 = TextEncoding.decodeUtf8 . Base64Url.encodeUnpadded

die :: String -> IO value
die message = hPutStrLn stderr message >> fail message

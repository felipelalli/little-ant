module Main (main) where

import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word8)
import LittleAnt.Pack.Format
import LittleAnt.Store (sha256Hex)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 canonical Pack format"
      [ testCase "the canonical writer is reproducible and round-trips structural identity" canonicalRoundTrip
      , testCase "noncanonical ZIP bytes and trailing data fail closed" zipMutations
      , testCase "pack.json and signature.json require exact JCS and closed keys" controlDocuments
      , testCase "permissions are component-local and kind constrained" permissionIsolation
      , testCase "component roots and file ownership are unambiguous" componentOwnership
      , testCase "payload length, digest, and entry set are verified before authority" payloadIntegrity
      , testCase "unsafe and Unicode-colliding paths are rejected by the writer" pathSafety
      , testCase "JCS object ordering follows UTF-16 code units" jcsOrdering
      ]

canonicalRoundTrip :: Assertion
canonicalRoundTrip = do
  first <- fixtureArchive fixtureManifest fixturePayload
  second <- fixtureArchive fixtureManifest fixturePayload
  first @?= second
  validated <- assertRight (validatePackArchive first)
  packName (structurallyValidManifest validated) @?= "org.littleant.standard"
  packVersion (structurallyValidManifest validated) @?= "1.0.0"
  structurallyValidPayload validated @?= fixturePayload
  structurallyValidManifestDigest validated @?= sha256Hex (structurallyValidManifestBytes validated)
  structurallyValidArchiveDigest validated @?= sha256Hex first

zipMutations :: Assertion
zipMutations = do
  archive <- fixtureArchive fixtureManifest fixturePayload
  assertLeft "local timestamp" (validatePackArchive (replaceByte 10 1 archive))
  assertLeft "UTF-8 flag" (validatePackArchive (replaceByte 7 0 archive))
  assertLeft "compression method" (validatePackArchive (replaceByte 8 8 archive))
  assertLeft "payload byte" (validatePackArchive (replaceNeedleByte "return" archive))
  assertLeft "trailing data" (validatePackArchive (archive <> "x"))

controlDocuments :: Assertion
controlDocuments = do
  manifestBytes <- assertRight (encodePackManifest fixtureManifest)
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  assertLeft "manifest whitespace" (buildCanonicalPackArchive (" " <> manifestBytes) signatureBytes fixturePayload)
  assertLeft "signature whitespace" (buildCanonicalPackArchive manifestBytes (signatureBytes <> "\n") fixturePayload)

  manifestObject <- assertObject (toJSON fixtureManifest)
  let extraManifest = Object (KeyMap.insert "permissions" (object []) manifestObject)
  extraManifestBytes <- assertRight (canonicalJsonBytes extraManifest)
  archiveWithPackPermission <- assertRight (buildCanonicalPackArchive extraManifestBytes signatureBytes fixturePayload)
  assertLeft "Pack-wide permissions" (validatePackArchive archiveWithPackPermission)

  signatureObject <- assertObject (toJSON fixtureSignature)
  let extraSignature = Object (KeyMap.insert "label" "not authority" signatureObject)
  extraSignatureBytes <- assertRight (canonicalJsonBytes extraSignature)
  archiveWithSignatureLabel <- assertRight (buildCanonicalPackArchive manifestBytes extraSignatureBytes fixturePayload)
  assertLeft "signature display label" (validatePackArchive archiveWithSignatureLabel)

permissionIsolation :: Assertion
permissionIsolation = do
  let escalated =
        emptyPermissions
          { permissionCredentialSlots = [CredentialSlot "account" BearerToken]
          , permissionHttp = [HttpPermission ["GET"] "example.com" "/v1" (Just "account")]
          }
      exporter = ExecutableComponent fixtureCommon "main.lua" escalated
  assertLeft "exporter authority escalation" (encodePackManifest fixtureManifest{packComponents = [exporter]})

  let sourceCommon = fixtureCommon{componentKind = SourceAdapterComponent}
      invalidSource = ExecutableComponent sourceCommon "main.lua" emptyPermissions{permissionHostCapabilities = [LoopbackHttpCapability]}
  assertLeft "SourceAdapter UI authority" (encodePackManifest fixtureManifest{packComponents = [invalidSource]})

  let uiCommon = fixtureCommon{componentKind = UIAdapterComponent}
      invalidUi = ExecutableComponent uiCommon "main.lua" emptyPermissions{permissionEffectPurposes = [CalendarCreatePermission]}
  assertLeft "UIAdapter effect authority" (encodePackManifest fixtureManifest{packComponents = [invalidUi]})

componentOwnership :: Assertion
componentOwnership = do
  let secondCommon =
        fixtureCommon
          { componentId = "nested"
          , componentRoot = "exporters/tree/nested"
          }
      second = ExecutableComponent secondCommon "main.lua" emptyPermissions{permissionProjections = ["little-ant/structure@1"]}
  assertLeft "overlapping roots" (encodePackManifest fixtureManifest{packComponents = [fixtureComponent, second]})

  let orphan = PayloadFile "orphan.txt" 1 "text/plain" (sha256Hex "x")
  assertLeft "orphan payload" (encodePackManifest fixtureManifest{packFiles = packFiles fixtureManifest <> [orphan]})

  let missingReference = fixtureCommon{componentConfigurationSchema = "missing.json"}
  assertLeft "missing component file" (encodePackManifest fixtureManifest{packComponents = [ExecutableComponent missingReference "main.lua" emptyPermissions{permissionProjections = ["little-ant/structure@1"]}]})

payloadIntegrity :: Assertion
payloadIntegrity = do
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  let wrongLength = case packFiles fixtureManifest of
        first : rest -> first{payloadFileLength = payloadFileLength first + 1} : rest
        [] -> error "fixture has files"
      wrongDigest = case packFiles fixtureManifest of
        first : rest -> first{payloadFileSha256 = TextEncoding.decodeUtf8 (ByteString.replicate 64 48)} : rest
        [] -> error "fixture has files"
  lengthManifest <- assertRight (canonicalJsonBytes (toJSON fixtureManifest{packFiles = wrongLength}))
  digestManifest <- assertRight (canonicalJsonBytes (toJSON fixtureManifest{packFiles = wrongDigest}))
  lengthArchive <- assertRight (buildCanonicalPackArchive lengthManifest signatureBytes fixturePayload)
  digestArchive <- assertRight (buildCanonicalPackArchive digestManifest signatureBytes fixturePayload)
  assertLeft "declared length" (validatePackArchive lengthArchive)
  assertLeft "declared digest" (validatePackArchive digestArchive)

pathSafety :: Assertion
pathSafety = do
  manifestBytes <- assertRight (encodePackManifest fixtureManifest)
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  assertLeft "parent traversal" (buildCanonicalPackArchive manifestBytes signatureBytes (Map.singleton "../escape.lua" "x"))
  assertLeft "backslash" (buildCanonicalPackArchive manifestBytes signatureBytes (Map.singleton "bad\\path.lua" "x"))
  assertLeft
    "Unicode normalization collision"
    ( buildCanonicalPackArchive
        manifestBytes
        signatureBytes
        (Map.fromList [("caf\x00e9.lua", "x"), ("cafe\x0301.lua", "y")])
    )

jcsOrdering :: Assertion
jcsOrdering = do
  let supplementary = "\x10000"
      privateUse = "\xe000"
  bytes <- assertRight (canonicalJsonBytes (object [Key.fromText privateUse .= (2 :: Int), Key.fromText supplementary .= (1 :: Int)]))
  indexOf (TextEncoding.encodeUtf8 supplementary) bytes @?= 2
  assertBool "UTF-16 order placed the supplementary key first" (indexOf (TextEncoding.encodeUtf8 supplementary) bytes < indexOf (TextEncoding.encodeUtf8 privateUse) bytes)
  assertLeft "fractional control number" (canonicalJsonBytes (Number 1.5))

fixtureArchive :: PackManifest -> Map Text ByteString -> IO ByteString
fixtureArchive manifest payload = do
  manifestBytes <- assertRight (encodePackManifest manifest)
  signatureBytes <- assertRight (encodePackSignature fixtureSignature)
  assertRight (buildCanonicalPackArchive manifestBytes signatureBytes payload)

fixtureManifest :: PackManifest
fixtureManifest =
  PackManifest
    { packName = "org.littleant.standard"
    , packVersion = "1.0.0"
    , packDisplayName = "Little Ant Standard Pack"
    , packPublisher = "org.littleant.project"
    , packLittleAntMajor = 1
    , packComponents = [fixtureComponent]
    , packFiles = fmap payloadRecord (Map.toAscList fixturePayload)
    , packLinks = Just (PackLinks (Just "https://example.com/little-ant") Nothing Nothing)
    }

fixtureComponent :: PackComponent
fixtureComponent = ExecutableComponent fixtureCommon "main.lua" emptyPermissions{permissionProjections = ["little-ant/structure@1"]}

fixtureCommon :: ComponentCommon
fixtureCommon =
  ComponentCommon
    { componentId = "tree"
    , componentKind = ReadOnlyExporterComponent
    , componentContractMajor = 1
    , componentRoot = "exporters/tree"
    , componentConfigurationSchema = "config.schema.json"
    }

emptyPermissions :: ComponentPermissions
emptyPermissions = ComponentPermissions [] [] [] [] []

fixturePayload :: Map Text ByteString
fixturePayload =
  Map.fromList
    [ ("exporters/tree/config.schema.json", "{\"additionalProperties\":false,\"type\":\"object\"}")
    , ("exporters/tree/main.lua", "return {}\n")
    ]

payloadRecord :: (Text, ByteString) -> PayloadFile
payloadRecord (path, bytes) = PayloadFile path (fromIntegral (ByteString.length bytes)) (mediaType path) (sha256Hex bytes)
 where
  mediaType value
    | ".lua" `Text.isSuffixOf` value = "text/x-lua; charset=utf-8"
    | otherwise = "application/schema+json"

fixtureSignature :: PackSignatureDocument
fixtureSignature =
  PackSignatureDocument
    { packSignaturePublicKey = TextEncoding.decodeUtf8 (ByteString.replicate 43 65)
    , packSignatureKeyFingerprint = TextEncoding.decodeUtf8 (ByteString.replicate 64 48)
    , packSignatureValue = TextEncoding.decodeUtf8 (ByteString.replicate 86 65)
    }

replaceByte :: Int -> Word8 -> ByteString -> ByteString
replaceByte offset byte bytes = ByteString.take offset bytes <> ByteString.singleton byte <> ByteString.drop (offset + 1) bytes

replaceNeedleByte :: ByteString -> ByteString -> ByteString
replaceNeedleByte needle bytes =
  let (before, suffix) = ByteString.breakSubstring needle bytes
   in if ByteString.null suffix
        then error "fixture needle not found"
        else before <> ByteString.singleton (ByteString.head suffix + 1) <> ByteString.tail suffix

indexOf :: ByteString -> ByteString -> Int
indexOf needle haystack = ByteString.length (fst (ByteString.breakSubstring needle haystack))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

assertObject :: Value -> IO Object
assertObject = \case
  Object fields -> pure fields
  other -> assertFailure ("expected object, got " <> show other)

assertLeft :: (Show right) => String -> Either left right -> Assertion
assertLeft label = \case
  Left _ -> pure ()
  Right value -> assertFailure (label <> " unexpectedly succeeded: " <> show value)

module LittleAnt.Source (
  SourceInput (..),
  SourceObjectShape (..),
  SourceMaterial (..),
  SourceAdapterMaterialization (..),
  SourceMaterialKind (..),
  SourceMaterialSummary (..),
  SourceContainer (..),
  SourceObject (..),
  SourceAdapterObservation (..),
  SourcePreflight (..),
  SourceCleanupOutcome (..),
  SourceCleanupReceipt (..),
  validateSourceCleanupReceipt,
  sourceModeName,
  validateSourceAdapterObservation,
  validateSourceAdapterMaterialization,
  validateSourceMaterial,
  summarizeSourceMaterial,
  makeSourcePreflight,
)
where

import Control.Monad (unless, when)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.Char (isAscii, isDigit)
import Data.Foldable (traverse_)
import Data.List (nub)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import LittleAnt.Error
import LittleAnt.Model
import LittleAnt.Pack.Trust
import LittleAnt.Store (sha256Hex)

data SourceInput = SourceInput
  { sourceInputLabel :: Text
  , sourceInputMediaType :: Text
  , sourceInputBytes :: ByteString
  }
  deriving stock (Eq, Show)

data SourceObjectShape
  = SourceTaskShape
  | SourceNoteShape
  | SourceOtherShape
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data SourceMaterial
  = SourceTextMaterial Text
  | SourceUriMaterial Text (Maybe Text)
  | SourceBlobMaterial ByteString Text (Maybe Text)
  | SourceStructuredMaterial Text Text
  deriving stock (Eq, Show)

data SourceMaterialKind
  = SourceTextKind
  | SourceUriKind
  | SourceBlobKind
  | SourceStructuredKind
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data SourceMaterialSummary = SourceMaterialSummary
  { sourceMaterialKind :: SourceMaterialKind
  , sourceMaterialDigest :: Text
  , sourceMaterialByteCount :: Int
  , sourceMaterialPreview :: Text
  }
  deriving stock (Eq, Show)

data SourceContainer = SourceContainer
  { sourceContainerExternalId :: Text
  , sourceContainerLabel :: Text
  }
  deriving stock (Eq, Show)

data SourceObject = SourceObject
  { sourceObjectExternalId :: Text
  , sourceObjectLocator :: Text
  , sourceObjectContainerId :: Maybe Text
  , sourceObjectTitle :: Text
  , sourceObjectShape :: SourceObjectShape
  , sourceObjectCompleted :: Bool
  , sourceObjectAttachmentCount :: Int
  , sourceObjectMaterial :: SourceMaterialSummary
  , sourceObjectDuplicateKeys :: [Text]
  }
  deriving stock (Eq, Show)

{- | The closed, side-effect-free value returned by SourceAdapter Lua code.
Host-owned input custody and Pack identity are deliberately absent here.
-}
data SourceAdapterObservation = SourceAdapterObservation
  { observedSourceLabel :: Text
  , observedAccountLabel :: Maybe Text
  , observedIdentity :: Map Text Text
  , observedSupportedModes :: [SourceMode]
  , observedCleanupSupported :: Bool
  , observedContainers :: [SourceContainer]
  , observedObjects :: [SourceObject]
  , observedUnsupportedFields :: [Text]
  , observedWarnings :: [Text]
  }
  deriving stock (Eq, Show)

{- | Full source material is a transient acceptance value. It crosses the
isolated runner boundary only after the human accepts a preflight and is never
stored in an interaction checkpoint. The observation remains alongside the
material so the host can prove that every accepted byte matches the preview.
-}
data SourceAdapterMaterialization = SourceAdapterMaterialization
  { materializedObservation :: SourceAdapterObservation
  , materializedObjects :: Map Text SourceMaterial
  }
  deriving stock (Eq, Show)

{- | A complete preflight joins the adapter observation to facts owned by the
trusted host. These facts are the custody boundary used by later import
acceptance and stale-preview detection.
-}
data SourcePreflight = SourcePreflight
  { sourcePreflightAdapterId :: Text
  , sourcePreflightPackIdentity :: PackArtifactIdentity
  , sourcePreflightSignerFingerprint :: Text
  , sourcePreflightContractMajor :: Int
  , sourcePreflightPermissions :: Text
  , sourcePreflightMode :: SourceMode
  , sourcePreflightInputLabel :: Text
  , sourcePreflightInputMediaType :: Text
  , sourcePreflightInputDigest :: Text
  , sourcePreflightInputByteCount :: Int
  , sourcePreflightObservation :: SourceAdapterObservation
  }
  deriving stock (Eq, Show)

data SourceCleanupOutcome
  = SourceCleanupSucceeded
  | SourceCleanupFailedRetryable
  | SourceCleanupFailedTerminal
  | SourceCleanupOutcomeUnknown
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data SourceCleanupReceipt = SourceCleanupReceipt
  { sourceCleanupOutcome :: SourceCleanupOutcome
  , sourceCleanupProviderReference :: Maybe Text
  , sourceCleanupRedactedDetail :: Maybe Text
  }
  deriving stock (Eq, Show)

validateSourceCleanupReceipt :: SourceCleanupReceipt -> Either AppError ()
validateSourceCleanupReceipt receipt = do
  traverse_ (requireBounded "provider reference" 2048) (sourceCleanupProviderReference receipt)
  traverse_ (requireBounded "redacted detail" 4096) (sourceCleanupRedactedDetail receipt)
 where
  requireBounded label limit value =
    when (Text.null (Text.strip value) || Text.length value > limit) $
      Left (sourceProblem CorruptData ("A SourceAdapter returned an invalid cleanup " <> label <> "."))

sourceModeName :: SourceMode -> Text
sourceModeName = \case
  SourceSnapshot -> "snapshot"
  SourceSynchronize -> "synchronize"
  SourceMigrate -> "migrate"

validateSourceAdapterObservation :: SourceAdapterObservation -> Either AppError ()
validateSourceAdapterObservation observation = do
  requireText "source label" (observedSourceLabel observation)
  traverse_ (requireText "account label") (observedAccountLabel observation)
  unless (Map.size (observedIdentity observation) <= 64) $ invalid "A SourceAdapter returned too many source-identity facts."
  traverse_ (requireText "source-identity key") (Map.keys (observedIdentity observation))
  traverse_ (requireText "source-identity value") (Map.elems (observedIdentity observation))
  when (any ((> 128) . Text.length) (Map.keys (observedIdentity observation))) $ invalid "A SourceAdapter returned an oversized source-identity key."
  when (any ((> 2048) . Text.length) (Map.elems (observedIdentity observation))) $ invalid "A SourceAdapter returned an oversized source-identity value."
  unless (not (null modes) && unique modes) $ invalid "A SourceAdapter must return a nonempty unique mode list."
  unless (unique (sourceContainerExternalId <$> containers)) $ invalid "A SourceAdapter returned duplicate container identities."
  unless (unique (sourceObjectExternalId <$> objects)) $ invalid "A SourceAdapter returned duplicate object identities."
  traverse_ validateContainer containers
  traverse_ validateObject objects
  traverse_ (requireText "unsupported-field description") (observedUnsupportedFields observation)
  traverse_ (requireText "warning") (observedWarnings observation)
 where
  modes = observedSupportedModes observation
  containers = observedContainers observation
  objects = observedObjects observation
  containerIds = Set.fromList (sourceContainerExternalId <$> containers)
  validateContainer container = do
    requireText "container external identity" (sourceContainerExternalId container)
    requireText "container label" (sourceContainerLabel container)
  validateObject sourceObject = do
    requireText "object external identity" (sourceObjectExternalId sourceObject)
    requireText "object locator" (sourceObjectLocator sourceObject)
    requireText "object title" (sourceObjectTitle sourceObject)
    when (sourceObjectAttachmentCount sourceObject < 0) $ invalid "A SourceAdapter returned a negative attachment count."
    traverse_
      (\container -> unless (container `Set.member` containerIds) $ invalid "A source object references an unknown container identity.")
      (sourceObjectContainerId sourceObject)
    unless (unique (sourceObjectDuplicateKeys sourceObject)) $ invalid "A source object returned duplicate duplicate-suspicion keys."
    traverse_ (requireText "duplicate-suspicion key") (sourceObjectDuplicateKeys sourceObject)
    validateMaterial (sourceObjectMaterial sourceObject)
  validateMaterial material = do
    requireDigest "material digest" (sourceMaterialDigest material)
    when (sourceMaterialByteCount material < 0) $ invalid "A source material summary cannot have a negative byte count."
    requireText "material preview" (sourceMaterialPreview material)
  requireText label value = when (Text.null (Text.strip value)) $ invalid ("A SourceAdapter returned an empty " <> label <> ".")
  requireDigest label value = unless (Text.length value == 64 && Text.all hexadecimal value) $ invalid ("A SourceAdapter returned an invalid " <> label <> ".")
  hexadecimal character = isAscii character && (isDigit character || character >= 'a' && character <= 'f')
  unique values = length values == length (nub values)
  invalid message = Left (sourceProblem CorruptData message)

validateSourceAdapterMaterialization :: SourceAdapterMaterialization -> Either AppError ()
validateSourceAdapterMaterialization materialization = do
  validateSourceAdapterObservation observation
  unless (Map.keysSet materials == Map.keysSet expected) $
    invalid "A SourceAdapter materialization does not contain exactly the previewed object identities."
  traverse_
    ( \(externalIdentity, material) -> do
        validateSourceMaterial material
        case Map.lookup externalIdentity expected of
          Nothing -> invalid "A SourceAdapter materialized an unknown object identity."
          Just summary ->
            unless (summarizeSourceMaterial material == summary) $
              invalid "A SourceAdapter materialization does not match its previewed content summary."
    )
    (Map.toAscList materials)
 where
  observation = materializedObservation materialization
  materials = materializedObjects materialization
  expected =
    Map.fromList
      [ (sourceObjectExternalId sourceObject, sourceObjectMaterial sourceObject)
      | sourceObject <- observedObjects observation
      ]
  invalid message = Left (sourceProblem CorruptData message)

validateSourceMaterial :: SourceMaterial -> Either AppError ()
validateSourceMaterial = \case
  SourceTextMaterial text -> requireText "text content" text
  SourceUriMaterial uri _ -> requireText "URI content" uri
  SourceBlobMaterial _ mediaType _ -> requireText "blob media type" mediaType
  SourceStructuredMaterial schema canonicalJson -> do
    requireText "structured-content schema" schema
    requireText "structured content" canonicalJson
 where
  requireText label value =
    when (Text.null (Text.strip value)) $
      Left (sourceProblem CorruptData ("A SourceAdapter returned empty " <> label <> "."))

makeSourcePreflight :: Text -> PackArtifactIdentity -> Text -> Int -> Text -> SourceMode -> SourceInput -> SourceAdapterObservation -> Either AppError SourcePreflight
makeSourcePreflight adapter identity signer contractMajor permissions mode input observation = do
  when (Text.null (Text.strip adapter)) $ Left (sourceProblem InvalidInput "A SourceAdapter identifier cannot be empty.")
  when (contractMajor < 1) $ Left (sourceProblem InvalidInput "A SourceAdapter contract major must be positive.")
  when (Text.null (Text.strip permissions)) $ Left (sourceProblem InvalidInput "SourceAdapter invocation permissions cannot be empty.")
  when (Text.null (Text.strip (sourceInputLabel input))) $ Left (sourceProblem InvalidInput "A source input label cannot be empty.")
  when (Text.null (Text.strip (sourceInputMediaType input))) $ Left (sourceProblem InvalidInput "A source input media type cannot be empty.")
  validateSourceAdapterObservation observation
  unless (mode `elem` observedSupportedModes observation) $
    Left
      ( (sourceProblem Unsupported "The selected SourceAdapter does not support the requested import mode.")
          { appErrorSubject = Just (sourceModeName mode)
          , appErrorRecovery =
              [ RecoveryAction
                  "choose-mode"
                  ("Choose one of: " <> Text.intercalate ", " (sourceModeName <$> observedSupportedModes observation) <> ".")
                  Nothing
              ]
          }
      )
  pure
    SourcePreflight
      { sourcePreflightAdapterId = Text.strip adapter
      , sourcePreflightPackIdentity = identity
      , sourcePreflightSignerFingerprint = signer
      , sourcePreflightContractMajor = contractMajor
      , sourcePreflightPermissions = Text.strip permissions
      , sourcePreflightMode = mode
      , sourcePreflightInputLabel = Text.strip (sourceInputLabel input)
      , sourcePreflightInputMediaType = Text.strip (sourceInputMediaType input)
      , sourcePreflightInputDigest = sha256Hex (sourceInputBytes input)
      , sourcePreflightInputByteCount = ByteString.length (sourceInputBytes input)
      , sourcePreflightObservation = observation
      }

instance ToJSON SourceContainer where
  toJSON container = object ["external_id" .= sourceContainerExternalId container, "label" .= sourceContainerLabel container]

instance FromJSON SourceContainer where
  parseJSON = withObject "SourceContainer" $ \fields -> do
    rejectUnknown fields ["external_id", "label"]
    SourceContainer <$> fields .: "external_id" <*> fields .: "label"

instance ToJSON SourceObjectShape where
  toJSON = toJSON . sourceObjectShapeName

instance FromJSON SourceObjectShape where
  parseJSON = withText "SourceObjectShape" $ \case
    "task" -> pure SourceTaskShape
    "note" -> pure SourceNoteShape
    "other" -> pure SourceOtherShape
    value -> fail ("unknown source object shape: " <> Text.unpack value)

instance ToJSON SourceObject where
  toJSON sourceObject =
    object $
      [ "external_id" .= sourceObjectExternalId sourceObject
      , "locator" .= sourceObjectLocator sourceObject
      , "title" .= sourceObjectTitle sourceObject
      , "shape" .= sourceObjectShape sourceObject
      , "completed" .= sourceObjectCompleted sourceObject
      , "attachment_count" .= sourceObjectAttachmentCount sourceObject
      , "material" .= sourceObjectMaterial sourceObject
      ]
        <> maybe [] (pure . ("container_id" .=)) (sourceObjectContainerId sourceObject)
        <> ["duplicate_keys" .= sourceObjectDuplicateKeys sourceObject | not (null (sourceObjectDuplicateKeys sourceObject))]

instance FromJSON SourceObject where
  parseJSON = withObject "SourceObject" $ \fields -> do
    rejectUnknown fields ["external_id", "locator", "container_id", "title", "shape", "completed", "attachment_count", "material", "duplicate_keys"]
    SourceObject
      <$> fields .: "external_id"
      <*> fields .: "locator"
      <*> fields .:? "container_id"
      <*> fields .: "title"
      <*> fields .: "shape"
      <*> fields .: "completed"
      <*> fields .: "attachment_count"
      <*> fields .: "material"
      <*> (fields .:? "duplicate_keys" .!= [])

instance ToJSON SourceMaterialKind where
  toJSON = toJSON . sourceMaterialKindName

instance FromJSON SourceMaterialKind where
  parseJSON = withText "SourceMaterialKind" $ \case
    "text" -> pure SourceTextKind
    "uri" -> pure SourceUriKind
    "blob" -> pure SourceBlobKind
    "structured" -> pure SourceStructuredKind
    value -> fail ("unknown source material kind: " <> Text.unpack value)

instance ToJSON SourceMaterialSummary where
  toJSON material =
    object
      [ "kind" .= sourceMaterialKind material
      , "digest" .= sourceMaterialDigest material
      , "byte_count" .= sourceMaterialByteCount material
      , "preview" .= sourceMaterialPreview material
      ]

instance FromJSON SourceMaterialSummary where
  parseJSON = withObject "SourceMaterialSummary" $ \fields -> do
    rejectUnknown fields ["kind", "digest", "byte_count", "preview"]
    SourceMaterialSummary <$> fields .: "kind" <*> fields .: "digest" <*> fields .: "byte_count" <*> fields .: "preview"

instance ToJSON SourceMaterial where
  toJSON = \case
    SourceTextMaterial text -> object ["kind" .= ("text" :: Text), "text" .= text]
    SourceUriMaterial uri label ->
      object $ ["kind" .= ("uri" :: Text), "uri" .= uri] <> maybe [] (pure . ("label" .=)) label
    SourceBlobMaterial bytes mediaType filename ->
      object $
        [ "kind" .= ("blob" :: Text)
        , "bytes" .= TextEncoding.decodeUtf8 (Base64Url.encodeUnpadded bytes)
        , "media_type" .= mediaType
        ]
          <> maybe [] (pure . ("filename" .=)) filename
    SourceStructuredMaterial schema canonicalJson ->
      object ["kind" .= ("structured" :: Text), "schema" .= schema, "json" .= canonicalJson]

instance FromJSON SourceMaterial where
  parseJSON = withObject "SourceMaterial" $ \fields -> do
    kind <- fields .: "kind"
    material <- case (kind :: Text) of
      "text" -> rejectUnknown fields ["kind", "text"] >> SourceTextMaterial <$> fields .: "text"
      "uri" -> rejectUnknown fields ["kind", "uri", "label"] >> SourceUriMaterial <$> fields .: "uri" <*> fields .:? "label"
      "blob" -> do
        rejectUnknown fields ["kind", "bytes", "media_type", "filename"]
        encoded <- fields .: "bytes"
        bytes <- either fail pure (decodeCanonicalBase64 encoded)
        SourceBlobMaterial bytes <$> fields .: "media_type" <*> fields .:? "filename"
      "structured" -> rejectUnknown fields ["kind", "schema", "json"] >> SourceStructuredMaterial <$> fields .: "schema" <*> fields .: "json"
      value -> fail ("unknown source material kind: " <> Text.unpack value)
    either (fail . Text.unpack . appErrorMessage) (const (pure material)) (validateSourceMaterial material)

instance ToJSON SourceAdapterMaterialization where
  toJSON materialization =
    object
      [ "schema" .= ("little-ant/source-adapter-materialization@1" :: Text)
      , "observation" .= materializedObservation materialization
      , "objects"
          .= [ object ["external_id" .= externalIdentity, "content" .= material]
             | (externalIdentity, material) <- Map.toAscList (materializedObjects materialization)
             ]
      ]

instance FromJSON SourceAdapterMaterialization where
  parseJSON = withObject "SourceAdapterMaterialization" $ \fields -> do
    rejectUnknown fields ["schema", "observation", "objects"]
    schema <- fields .: "schema"
    unless (schema == ("little-ant/source-adapter-materialization@1" :: Text)) $ fail "unsupported SourceAdapter materialization schema"
    observation <- fields .: "observation"
    entries <- fields .: "objects" >>= traverse parseEntry
    let externalIdentities = fst <$> entries
    unless (length externalIdentities == Set.size (Set.fromList externalIdentities)) $ fail "duplicate materialized source-object identity"
    let materialization = SourceAdapterMaterialization observation (Map.fromList entries)
    either (fail . Text.unpack . appErrorMessage) (const (pure materialization)) (validateSourceAdapterMaterialization materialization)
   where
    parseEntry = withObject "SourceAdapterMaterializedObject" $ \fields -> do
      rejectUnknown fields ["external_id", "content"]
      (,) <$> fields .: "external_id" <*> fields .: "content"

instance ToJSON SourceAdapterObservation where
  toJSON observation =
    object $
      [ "schema" .= ("little-ant/source-adapter-observation@1" :: Text)
      , "source_label" .= observedSourceLabel observation
      , "identity" .= observedIdentity observation
      , "supported_modes" .= fmap sourceModeName (observedSupportedModes observation)
      , "cleanup_supported" .= observedCleanupSupported observation
      , "containers" .= observedContainers observation
      , "objects" .= observedObjects observation
      ]
        <> maybe [] (pure . ("account_label" .=)) (observedAccountLabel observation)
        <> ["unsupported_fields" .= observedUnsupportedFields observation | not (null (observedUnsupportedFields observation))]
        <> ["warnings" .= observedWarnings observation | not (null (observedWarnings observation))]

instance FromJSON SourceAdapterObservation where
  parseJSON = withObject "SourceAdapterObservation" $ \fields -> do
    rejectUnknown fields ["schema", "source_label", "account_label", "identity", "supported_modes", "cleanup_supported", "containers", "objects", "unsupported_fields", "warnings"]
    schema <- fields .: "schema"
    unless (schema == ("little-ant/source-adapter-observation@1" :: Text)) $ fail "unsupported SourceAdapter observation schema"
    modes <- fields .: "supported_modes" >>= traverse parseSourceMode
    observation <-
      SourceAdapterObservation
        <$> fields .: "source_label"
        <*> fields .:? "account_label"
        <*> fields .: "identity"
        <*> pure modes
        <*> fields .: "cleanup_supported"
        <*> fields .: "containers"
        <*> fields .: "objects"
        <*> (fields .:? "unsupported_fields" .!= [])
        <*> (fields .:? "warnings" .!= [])
    either (fail . Text.unpack . appErrorMessage) (const (pure observation)) (validateSourceAdapterObservation observation)

instance ToJSON SourcePreflight where
  toJSON preflight =
    object
      [ "schema" .= ("little-ant/source-preflight@1" :: Text)
      , "adapter_id" .= sourcePreflightAdapterId preflight
      , "pack" .= sourcePreflightPackIdentity preflight
      , "signer_fingerprint" .= sourcePreflightSignerFingerprint preflight
      , "contract_major" .= sourcePreflightContractMajor preflight
      , "permissions" .= sourcePreflightPermissions preflight
      , "mode" .= sourceModeName (sourcePreflightMode preflight)
      , "input_label" .= sourcePreflightInputLabel preflight
      , "input_media_type" .= sourcePreflightInputMediaType preflight
      , "input_digest" .= sourcePreflightInputDigest preflight
      , "input_byte_count" .= sourcePreflightInputByteCount preflight
      , "observation" .= sourcePreflightObservation preflight
      ]

instance FromJSON SourcePreflight where
  parseJSON = withObject "SourcePreflight" $ \fields -> do
    rejectUnknown fields ["schema", "adapter_id", "pack", "signer_fingerprint", "contract_major", "permissions", "mode", "input_label", "input_media_type", "input_digest", "input_byte_count", "observation"]
    schema <- fields .: "schema"
    unless (schema == ("little-ant/source-preflight@1" :: Text)) $ fail "unsupported SourcePreflight schema"
    preflight <-
      SourcePreflight
        <$> fields .: "adapter_id"
        <*> fields .: "pack"
        <*> fields .: "signer_fingerprint"
        <*> fields .: "contract_major"
        <*> fields .: "permissions"
        <*> (fields .: "mode" >>= parseSourceMode)
        <*> fields .: "input_label"
        <*> fields .: "input_media_type"
        <*> fields .: "input_digest"
        <*> fields .: "input_byte_count"
        <*> fields .: "observation"
    when (any (Text.null . Text.strip) [sourcePreflightAdapterId preflight, sourcePreflightSignerFingerprint preflight, sourcePreflightPermissions preflight, sourcePreflightInputLabel preflight, sourcePreflightInputMediaType preflight]) $ fail "SourcePreflight contains an empty custody field"
    when (sourcePreflightContractMajor preflight < 1) $ fail "SourcePreflight contains an invalid contract major"
    unless (Text.length (sourcePreflightInputDigest preflight) == 64 && Text.all hexadecimal (sourcePreflightInputDigest preflight)) $ fail "SourcePreflight contains an invalid input digest"
    when (sourcePreflightInputByteCount preflight < 0) $ fail "SourcePreflight contains a negative input byte count"
    unless (sourcePreflightMode preflight `elem` observedSupportedModes (sourcePreflightObservation preflight)) $ fail "SourcePreflight mode is not supported by its observation"
    pure preflight
   where
    hexadecimal character = isAscii character && (isDigit character || character >= 'a' && character <= 'f')

sourceObjectShapeName :: SourceObjectShape -> Text
sourceObjectShapeName = \case
  SourceTaskShape -> "task"
  SourceNoteShape -> "note"
  SourceOtherShape -> "other"

summarizeSourceMaterial :: SourceMaterial -> SourceMaterialSummary
summarizeSourceMaterial material =
  SourceMaterialSummary
    { sourceMaterialKind = kind
    , sourceMaterialDigest = sha256Hex bytes
    , sourceMaterialByteCount = ByteString.length bytes
    , sourceMaterialPreview = preview
    }
 where
  (kind, bytes, preview) = case material of
    SourceTextMaterial text -> (SourceTextKind, TextEncoding.encodeUtf8 text, concise text)
    SourceUriMaterial uri label ->
      (SourceUriKind, TextEncoding.encodeUtf8 ("uri\n" <> uri <> "\n" <> fromMaybe "" label), maybe uri concise label)
    SourceBlobMaterial sourceBytes _ filename ->
      (SourceBlobKind, sourceBytes, maybe "binary material" concise filename)
    SourceStructuredMaterial schema canonicalJson ->
      (SourceStructuredKind, TextEncoding.encodeUtf8 ("structured\n" <> schema <> "\n" <> canonicalJson), "structured " <> schema)
  concise = Text.take 160 . Text.unwords . Text.words

sourceMaterialKindName :: SourceMaterialKind -> Text
sourceMaterialKindName = \case
  SourceTextKind -> "text"
  SourceUriKind -> "uri"
  SourceBlobKind -> "blob"
  SourceStructuredKind -> "structured"

parseSourceMode :: Text -> Parser SourceMode
parseSourceMode = \case
  "snapshot" -> pure SourceSnapshot
  "synchronize" -> pure SourceSynchronize
  "migrate" -> pure SourceMigrate
  value -> fail ("unknown source mode: " <> Text.unpack value)

decodeCanonicalBase64 :: Text -> Either String ByteString
decodeCanonicalBase64 encoded = do
  let bytes = TextEncoding.encodeUtf8 encoded
  decoded <- Base64Url.decodeUnpadded bytes
  unless (Base64Url.encodeUnpadded decoded == bytes) (Left "noncanonical base64url source material")
  pure decoded

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

sourceProblem :: ErrorCode -> Text -> AppError
sourceProblem code message =
  (appError code message)
    { appErrorRecovery = [RecoveryAction "inspect-source" "Inspect the selected source and its signed SourceAdapter before retrying." Nothing]
    }

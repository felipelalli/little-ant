module LittleAnt.Pack.Format (
  PackComponentKind (..),
  ComponentCommon (..),
  PackComponent (..),
  componentCommon,
  CredentialScheme (..),
  CredentialSlot (..),
  OAuthDeviceAuthorizationPermission (..),
  HttpPermission (..),
  EffectPermission (..),
  HostCapability (..),
  ComponentPermissions (..),
  PayloadFile (..),
  PackLinks (..),
  PackManifest (..),
  PackSignatureDocument (..),
  StructurallyValidPack,
  structurallyValidManifest,
  structurallyValidSignature,
  structurallyValidManifestBytes,
  structurallyValidSignatureBytes,
  structurallyValidArchiveBytes,
  structurallyValidPayload,
  structurallyValidManifestDigest,
  structurallyValidArchiveDigest,
  canonicalJsonBytes,
  encodePackManifest,
  encodePackSignature,
  buildCanonicalPackArchive,
  validatePackArchive,
)
where

import Control.Monad (replicateM, unless, when)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.Binary.Get (Get, getByteString, getWord16le, getWord32le, runGetOrFail)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAscii, isAsciiLower, isAsciiUpper, isDigit, isSpace, ord)
import Data.Digest.CRC32 (crc32)
import Data.Foldable (toList, traverse_)
import Data.List (mapAccumL, sortBy)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes)
import Data.Ord (comparing)
import Data.Scientific (floatingOrInteger)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Text.Normalize qualified as Unicode
import Data.Word
import LittleAnt.Error
import LittleAnt.Store (sha256Hex)
import Network.URI (URI (..), URIAuth (..), parseURI)
import Numeric (showHex)

data PackComponentKind
  = BrickNatureComponent
  | BrickTemplateComponent
  | ImportProfilePresetComponent
  | SourceAdapterComponent
  | ReadOnlyExporterComponent
  | UIAdapterComponent
  deriving stock (Eq, Ord, Show)

data ComponentCommon = ComponentCommon
  { componentId :: Text
  , componentKind :: PackComponentKind
  , componentContractMajor :: Int
  , componentRoot :: Text
  , componentConfigurationSchema :: Text
  }
  deriving stock (Eq, Show)

data PackComponent
  = DeclarativeComponent ComponentCommon Text
  | ExecutableComponent ComponentCommon Text ComponentPermissions
  deriving stock (Eq, Show)

data CredentialScheme
  = OAuthAuthorizationCodePkce
  | OAuthDeviceAuthorization
  | BearerToken
  | ApiKey
  deriving stock (Eq, Ord, Show)

data CredentialSlot = CredentialSlot
  { credentialSlotId :: Text
  , credentialSlotScheme :: CredentialScheme
  }
  deriving stock (Eq, Ord, Show)

data OAuthDeviceAuthorizationPermission = OAuthDeviceAuthorizationPermission
  { oauthDeviceCredentialSlot :: Text
  , oauthDeviceAuthorizationEndpoint :: Text
  , oauthDeviceTokenEndpoint :: Text
  , oauthDeviceClientIdConfigurationKey :: Text
  , oauthDeviceScopes :: Set Text
  }
  deriving stock (Eq, Ord, Show)

data HttpPermission = HttpPermission
  { httpPermissionMethods :: [Text]
  , httpPermissionHost :: Text
  , httpPermissionPathPrefix :: Text
  , httpPermissionCredentialSlot :: Maybe Text
  }
  deriving stock (Eq, Ord, Show)

data EffectPermission
  = DelegationDeliveryPermission
  | DelegationTakeBackNoticePermission
  | SourceCleanupItemPermission
  | SourceCleanupContainerPermission
  | CalendarCreatePermission
  | CalendarUpdatePermission
  | CalendarCancelPermission
  deriving stock (Eq, Ord, Show)

data HostCapability
  = InputBytesCapability
  | LoopbackHttpCapability
  | StaticAssetsCapability
  deriving stock (Eq, Ord, Show)

data ComponentPermissions = ComponentPermissions
  { permissionCredentialSlots :: [CredentialSlot]
  , permissionOAuthDeviceAuthorizations :: [OAuthDeviceAuthorizationPermission]
  , permissionHttp :: [HttpPermission]
  , permissionEffectPurposes :: [EffectPermission]
  , permissionProjections :: [Text]
  , permissionHostCapabilities :: [HostCapability]
  }
  deriving stock (Eq, Show)

data PayloadFile = PayloadFile
  { payloadFilePath :: Text
  , payloadFileLength :: Integer
  , payloadFileMediaType :: Text
  , payloadFileSha256 :: Text
  }
  deriving stock (Eq, Show)

data PackLinks = PackLinks
  { packHomepage :: Maybe Text
  , packSource :: Maybe Text
  , packChangelog :: Maybe Text
  }
  deriving stock (Eq, Show)

data PackManifest = PackManifest
  { packName :: Text
  , packVersion :: Text
  , packDisplayName :: Text
  , packPublisher :: Text
  , packLittleAntMajor :: Int
  , packComponents :: [PackComponent]
  , packFiles :: [PayloadFile]
  , packLinks :: Maybe PackLinks
  }
  deriving stock (Eq, Show)

data PackSignatureDocument = PackSignatureDocument
  { packSignaturePublicKey :: Text
  , packSignatureKeyFingerprint :: Text
  , packSignatureValue :: Text
  }
  deriving stock (Eq, Show)

data StructurallyValidPack = StructurallyValidPack
  { structurallyValidManifest :: PackManifest
  , structurallyValidSignature :: PackSignatureDocument
  , structurallyValidManifestBytes :: ByteString
  , structurallyValidSignatureBytes :: ByteString
  , structurallyValidArchiveBytes :: ByteString
  , structurallyValidPayload :: Map Text ByteString
  , structurallyValidManifestDigest :: Text
  , structurallyValidArchiveDigest :: Text
  }
  deriving stock (Eq, Show)

instance ToJSON PackManifest where
  toJSON manifest =
    object $
      [ "schema" .= ("little-ant/pack@1" :: Text)
      , "name" .= packName manifest
      , "version" .= packVersion manifest
      , "display_name" .= packDisplayName manifest
      , "publisher" .= packPublisher manifest
      , "little_ant_major" .= packLittleAntMajor manifest
      , "components" .= packComponents manifest
      , "files" .= packFiles manifest
      ]
        <> maybe [] (pure . ("links" .=)) (packLinks manifest)

instance FromJSON PackManifest where
  parseJSON = withObject "PackManifest" $ \fields -> do
    rejectUnknown fields ["schema", "name", "version", "display_name", "publisher", "little_ant_major", "components", "files", "links"]
    requireSchema fields "little-ant/pack@1"
    PackManifest
      <$> fields .: "name"
      <*> fields .: "version"
      <*> fields .: "display_name"
      <*> fields .: "publisher"
      <*> fields .: "little_ant_major"
      <*> fields .: "components"
      <*> fields .: "files"
      <*> fields .:? "links"

instance ToJSON PackComponent where
  toJSON = \case
    DeclarativeComponent common body -> object (commonFields common <> ["declarative_body" .= body])
    ExecutableComponent common entry permissions -> object (commonFields common <> ["entry_point" .= entry, "permissions" .= permissions])
   where
    commonFields common =
      [ "id" .= componentId common
      , "kind" .= componentKindText (componentKind common)
      , "contract_major" .= componentContractMajor common
      , "root" .= componentRoot common
      , "configuration_schema" .= componentConfigurationSchema common
      ]

instance FromJSON PackComponent where
  parseJSON = withObject "PackComponent" $ \fields -> do
    kind <- fields .: "kind" >>= parseComponentKind
    common <-
      ComponentCommon
        <$> fields .: "id"
        <*> pure kind
        <*> fields .: "contract_major"
        <*> fields .: "root"
        <*> fields .: "configuration_schema"
    if isDeclarativeKind kind
      then do
        rejectUnknown fields ["id", "kind", "contract_major", "root", "configuration_schema", "declarative_body"]
        DeclarativeComponent common <$> fields .: "declarative_body"
      else do
        rejectUnknown fields ["id", "kind", "contract_major", "root", "configuration_schema", "entry_point", "permissions"]
        ExecutableComponent common <$> fields .: "entry_point" <*> fields .: "permissions"

instance ToJSON ComponentPermissions where
  toJSON permissions =
    object $
      [ "credential_slots" .= permissionCredentialSlots permissions
      , "http" .= permissionHttp permissions
      , "effect_purposes" .= fmap effectPermissionText (permissionEffectPurposes permissions)
      , "projections" .= permissionProjections permissions
      , "host_capabilities" .= fmap hostCapabilityText (permissionHostCapabilities permissions)
      ]
        <> ["oauth_device_authorization" .= permissionOAuthDeviceAuthorizations permissions | not (null (permissionOAuthDeviceAuthorizations permissions))]

instance FromJSON ComponentPermissions where
  parseJSON = withObject "ComponentPermissions" $ \fields -> do
    rejectUnknown fields ["credential_slots", "oauth_device_authorization", "http", "effect_purposes", "projections", "host_capabilities"]
    ComponentPermissions
      <$> fields .: "credential_slots"
      <*> fields .:? "oauth_device_authorization" .!= []
      <*> fields .: "http"
      <*> (fields .: "effect_purposes" >>= traverse parseEffectPermission)
      <*> fields .: "projections"
      <*> (fields .: "host_capabilities" >>= traverse parseHostCapability)

instance ToJSON CredentialSlot where
  toJSON slot = object ["id" .= credentialSlotId slot, "scheme" .= credentialSchemeText (credentialSlotScheme slot)]

instance FromJSON CredentialSlot where
  parseJSON = withObject "CredentialSlot" $ \fields -> do
    rejectUnknown fields ["id", "scheme"]
    CredentialSlot <$> fields .: "id" <*> (fields .: "scheme" >>= parseCredentialScheme)

instance ToJSON OAuthDeviceAuthorizationPermission where
  toJSON permission =
    object
      [ "credential_slot" .= oauthDeviceCredentialSlot permission
      , "device_authorization_endpoint" .= oauthDeviceAuthorizationEndpoint permission
      , "token_endpoint" .= oauthDeviceTokenEndpoint permission
      , "client_id_configuration_key" .= oauthDeviceClientIdConfigurationKey permission
      , "scopes" .= Set.toAscList (oauthDeviceScopes permission)
      ]

instance FromJSON OAuthDeviceAuthorizationPermission where
  parseJSON = withObject "OAuthDeviceAuthorizationPermission" $ \fields -> do
    rejectUnknown fields ["credential_slot", "device_authorization_endpoint", "token_endpoint", "client_id_configuration_key", "scopes"]
    OAuthDeviceAuthorizationPermission
      <$> fields .: "credential_slot"
      <*> fields .: "device_authorization_endpoint"
      <*> fields .: "token_endpoint"
      <*> fields .: "client_id_configuration_key"
      <*> (Set.fromList <$> fields .: "scopes")

instance ToJSON HttpPermission where
  toJSON permission =
    object $
      [ "methods" .= httpPermissionMethods permission
      , "host" .= httpPermissionHost permission
      , "path_prefix" .= httpPermissionPathPrefix permission
      ]
        <> maybe [] (pure . ("credential_slot" .=)) (httpPermissionCredentialSlot permission)

instance FromJSON HttpPermission where
  parseJSON = withObject "HttpPermission" $ \fields -> do
    rejectUnknown fields ["methods", "host", "path_prefix", "credential_slot"]
    HttpPermission <$> fields .: "methods" <*> fields .: "host" <*> fields .: "path_prefix" <*> fields .:? "credential_slot"

instance ToJSON PayloadFile where
  toJSON payload =
    object
      [ "path" .= payloadFilePath payload
      , "length" .= payloadFileLength payload
      , "media_type" .= payloadFileMediaType payload
      , "sha256" .= payloadFileSha256 payload
      ]

instance FromJSON PayloadFile where
  parseJSON = withObject "PayloadFile" $ \fields -> do
    rejectUnknown fields ["path", "length", "media_type", "sha256"]
    PayloadFile <$> fields .: "path" <*> fields .: "length" <*> fields .: "media_type" <*> fields .: "sha256"

instance ToJSON PackLinks where
  toJSON links =
    object $
      maybe [] (pure . ("homepage" .=)) (packHomepage links)
        <> maybe [] (pure . ("source" .=)) (packSource links)
        <> maybe [] (pure . ("changelog" .=)) (packChangelog links)

instance FromJSON PackLinks where
  parseJSON = withObject "PackLinks" $ \fields -> do
    rejectUnknown fields ["homepage", "source", "changelog"]
    PackLinks <$> fields .:? "homepage" <*> fields .:? "source" <*> fields .:? "changelog"

instance ToJSON PackSignatureDocument where
  toJSON signature =
    object
      [ "schema" .= ("little-ant/pack-signature@1" :: Text)
      , "algorithm" .= ("Ed25519" :: Text)
      , "public_key" .= packSignaturePublicKey signature
      , "key_fingerprint" .= packSignatureKeyFingerprint signature
      , "signature" .= packSignatureValue signature
      ]

instance FromJSON PackSignatureDocument where
  parseJSON = withObject "PackSignatureDocument" $ \fields -> do
    rejectUnknown fields ["schema", "algorithm", "public_key", "key_fingerprint", "signature"]
    requireSchema fields "little-ant/pack-signature@1"
    algorithm <- fields .: "algorithm"
    unless (algorithm == ("Ed25519" :: Text)) (fail "unsupported signature algorithm")
    PackSignatureDocument <$> fields .: "public_key" <*> fields .: "key_fingerprint" <*> fields .: "signature"

encodePackManifest :: PackManifest -> Either AppError ByteString
encodePackManifest manifest = validateManifest manifest >> canonicalJsonBytes (toJSON manifest)

encodePackSignature :: PackSignatureDocument -> Either AppError ByteString
encodePackSignature = canonicalJsonBytes . toJSON

canonicalJsonBytes :: Value -> Either AppError ByteString
canonicalJsonBytes value =
  case renderJcs value of
    Left detail -> Left (packProblem "A Pack control document cannot be represented as RFC 8785 JSON." [detail])
    Right builder -> Right (LazyByteString.toStrict (toLazyByteString builder))

buildCanonicalPackArchive :: ByteString -> ByteString -> Map Text ByteString -> Either AppError ByteString
buildCanonicalPackArchive manifestBytes signatureBytes payload = do
  _ <- canonicalDocument "pack.json" manifestBytes
  _ <- canonicalDocument "signature.json" signatureBytes
  let payloadEntries = Map.toAscList payload
  traverse_ (validatePayloadPath . fst) payloadEntries
  unless (sum (fromIntegral . ByteString.length . snd <$> payloadEntries) <= maxPayloadBytes) (Left (packProblem "The payload exceeds the 64 MiB total limit." []))
  validateNormalizationCollisions ("pack.json" : "signature.json" : fmap ("payload/" <>) (Map.keys payload))
  buildZip ([("pack.json", manifestBytes), ("signature.json", signatureBytes)] <> [("payload/" <> path, bytes) | (path, bytes) <- payloadEntries])

validatePackArchive :: ByteString -> Either AppError StructurallyValidPack
validatePackArchive archiveBytes = do
  entries <- parseCanonicalZip archiveBytes
  (manifestBytes, signatureBytes, payload) <- splitArchive entries
  manifestValue <- canonicalDocument "pack.json" manifestBytes
  signatureValue <- canonicalDocument "signature.json" signatureBytes
  manifest <- decodeTyped "pack.json" manifestValue
  signature <- decodeTyped "signature.json" signatureValue
  validateManifest manifest
  validateSignatureShape signature
  validatePayload manifest payload
  pure
    StructurallyValidPack
      { structurallyValidManifest = manifest
      , structurallyValidSignature = signature
      , structurallyValidManifestBytes = manifestBytes
      , structurallyValidSignatureBytes = signatureBytes
      , structurallyValidArchiveBytes = archiveBytes
      , structurallyValidPayload = payload
      , structurallyValidManifestDigest = sha256Hex manifestBytes
      , structurallyValidArchiveDigest = sha256Hex archiveBytes
      }

canonicalDocument :: Text -> ByteString -> Either AppError Value
canonicalDocument label bytes = do
  value <-
    either
      (\problem -> Left (packProblem (label <> " is not valid UTF-8 JSON.") [Text.pack problem]))
      Right
      (eitherDecodeStrict' bytes)
  canonical <- canonicalJsonBytes value
  unless (canonical == bytes) (Left (packProblem (label <> " is not RFC 8785 canonical JSON.") []))
  pure value

decodeTyped :: (FromJSON value) => Text -> Value -> Either AppError value
decodeTyped label value =
  either
    (\problem -> Left (packProblem (label <> " does not match its closed schema.") [Text.pack problem]))
    Right
    (parseEither parseJSON value)

validateManifest :: PackManifest -> Either AppError ()
validateManifest manifest = do
  unless (validReverseDns (packName manifest)) (invalid "Pack name must be a lowercase reverse-DNS identifier.")
  unless (validSemVer (packVersion manifest)) (invalid "Pack version must be a complete SemVer 2.0.0 string.")
  unless (nonemptyText (packDisplayName manifest)) (invalid "Pack display name must be nonempty.")
  unless (validReverseDns (packPublisher manifest)) (invalid "Pack publisher must be a lowercase reverse-DNS identifier.")
  unless (packLittleAntMajor manifest > 0) (invalid "Little Ant compatibility major must be positive.")
  when (null (packComponents manifest)) (invalid "A Pack must declare at least one component.")
  traverse_ validateComponent (packComponents manifest)
  traverse_ validatePayloadFile (packFiles manifest)
  traverse_ validateLinks (packLinks manifest)
  uniqueBy "component ID" (componentId . componentCommon) (packComponents manifest)
  uniqueBy "component root" (componentRoot . componentCommon) (packComponents manifest)
  uniqueBy "payload path" payloadFilePath (packFiles manifest)
  let roots = fmap (componentRoot . componentCommon) (packComponents manifest)
  unless (pairwiseNonoverlapping roots) (invalid "Component roots must be pairwise non-overlapping.")
  unless (isSortedUtf8 (fmap payloadFilePath (packFiles manifest))) (invalid "Manifest payload files must be sorted by unsigned UTF-8 path bytes.")
  unless (sum (payloadFileLength <$> packFiles manifest) <= maxPayloadBytes) (invalid "The declared payload exceeds the 64 MiB total limit.")
  validateNormalizationCollisions (fmap payloadFilePath (packFiles manifest))
  let declared = Set.fromList (payloadFilePath <$> packFiles manifest)
  traverse_ (validateComponentFiles declared) (packComponents manifest)
  traverse_ (validateOwnedExactlyOnce roots . payloadFilePath) (packFiles manifest)
 where
  invalid message = Left (packProblem message [])

validateComponent :: PackComponent -> Either AppError ()
validateComponent component = do
  let common = componentCommon component
  unless (validLocalId (componentId common)) (invalid "A component ID does not match [a-z][a-z0-9._-]{0,63}.")
  unless (componentContractMajor common > 0) (invalid "A component contract major must be positive.")
  validatePayloadPath (componentRoot common)
  validateRelativeReference (componentConfigurationSchema common)
  case component of
    DeclarativeComponent _ body -> validateRelativeReference body
    ExecutableComponent _ entry permissions -> do
      validateRelativeReference entry
      unless (".lua" `Text.isSuffixOf` entry) (invalid "An executable component entry point must be a Lua file.")
      validatePermissions (componentKind common) permissions
 where
  invalid message = Left (packProblem message [])

validatePermissions :: PackComponentKind -> ComponentPermissions -> Either AppError ()
validatePermissions kind permissions = do
  unique "credential slot" (credentialSlotId <$> permissionCredentialSlots permissions)
  unique "OAuth device-authorization credential slot" (oauthDeviceCredentialSlot <$> permissionOAuthDeviceAuthorizations permissions)
  unique "HTTP permission" (permissionHttp permissions)
  unique "effect purpose" (permissionEffectPurposes permissions)
  unique "projection" (permissionProjections permissions)
  unique "host capability" (permissionHostCapabilities permissions)
  traverse_ validateCredentialSlot (permissionCredentialSlots permissions)
  traverse_ (validateOAuthDeviceAuthorization slots) (permissionOAuthDeviceAuthorizations permissions)
  let deviceSlots = Set.fromList [credentialSlotId slot | slot <- slots, credentialSlotScheme slot == OAuthDeviceAuthorization]
      authorizedDeviceSlots = Set.fromList (oauthDeviceCredentialSlot <$> permissionOAuthDeviceAuthorizations permissions)
  unless (deviceSlots == authorizedDeviceSlots) (invalid "Every OAuth device-authorization slot must have exactly one signed authorization permission.")
  traverse_ (validateHttpPermission slots) (permissionHttp permissions)
  unless (httpPermissionsNonoverlapping (permissionHttp permissions)) (invalid "HTTP permissions cannot overlap for one method, host, and path.")
  traverse_ validateProjection (permissionProjections permissions)
  case kind of
    ReadOnlyExporterComponent -> do
      when (null (permissionProjections permissions)) (invalid "A ReadOnlyExporter must declare at least one projection.")
      unless
        (null slots && null (permissionHttp permissions) && null (permissionEffectPurposes permissions) && null (permissionHostCapabilities permissions))
        (invalid "A ReadOnlyExporter cannot request credentials, HTTP, effects, or host capabilities.")
    SourceAdapterComponent ->
      unless
        (all (== InputBytesCapability) (permissionHostCapabilities permissions))
        (invalid "A SourceAdapter may request only the input_bytes host capability.")
    UIAdapterComponent ->
      unless
        (null (permissionEffectPurposes permissions))
        (invalid "A UIAdapter cannot request external-effect purposes.")
    _ -> invalid "A declarative component cannot contain executable permissions."
 where
  slots = permissionCredentialSlots permissions
  invalid message = Left (packProblem message [])

httpPermissionsNonoverlapping :: [HttpPermission] -> Bool
httpPermissionsNonoverlapping [] = True
httpPermissionsNonoverlapping (permission : rest) = not (any (overlaps permission) rest) && httpPermissionsNonoverlapping rest
 where
  overlaps left right =
    httpPermissionHost left == httpPermissionHost right
      && not (Set.disjoint (Set.fromList (httpPermissionMethods left)) (Set.fromList (httpPermissionMethods right)))
      && (pathContains (httpPermissionPathPrefix left) (httpPermissionPathPrefix right) || pathContains (httpPermissionPathPrefix right) (httpPermissionPathPrefix left))
  pathContains prefix path = prefix == "/" || path == prefix || (prefix <> "/") `Text.isPrefixOf` path

validateCredentialSlot :: CredentialSlot -> Either AppError ()
validateCredentialSlot slot = unless (validLocalId (credentialSlotId slot)) (Left (packProblem "A credential slot ID is invalid." []))

validateOAuthDeviceAuthorization :: [CredentialSlot] -> OAuthDeviceAuthorizationPermission -> Either AppError ()
validateOAuthDeviceAuthorization slots permission = do
  case filter ((== oauthDeviceCredentialSlot permission) . credentialSlotId) slots of
    [slot] ->
      unless
        (credentialSlotScheme slot == OAuthDeviceAuthorization)
        (invalid "An OAuth device-authorization permission must reference a slot with the matching scheme.")
    _ -> invalid "An OAuth device-authorization permission references an unknown credential slot."
  validateOAuthEndpoint "device authorization" (oauthDeviceAuthorizationEndpoint permission)
  validateOAuthEndpoint "token" (oauthDeviceTokenEndpoint permission)
  unless (validLocalId (oauthDeviceClientIdConfigurationKey permission)) $
    invalid "An OAuth client-id configuration key is invalid."
  let scopes = oauthDeviceScopes permission
  unless (not (Set.null scopes) && Set.size scopes <= 32 && all validOAuthScope (Set.toList scopes)) $
    invalid "OAuth scopes must be a nonempty bounded set of visible ASCII scope tokens."
  unless ("offline_access" `Set.member` scopes) $
    invalid "An OAuth device-authorization permission must request offline_access for refresh custody."
 where
  invalid message = Left (packProblem message [])

validateOAuthEndpoint :: Text -> Text -> Either AppError ()
validateOAuthEndpoint label endpoint = do
  uri <- maybe (invalid "is not an absolute URI") Right (parseURI (Text.unpack endpoint))
  unless (uriScheme uri == "https:") (invalid "must use HTTPS")
  authority <- maybe (invalid "has no authority") Right (uriAuthority uri)
  unless (null (uriUserInfo authority) && null (uriPort authority)) (invalid "cannot contain user information or an explicit port")
  unless (validDnsHost (Text.pack (uriRegName authority))) (invalid "has a noncanonical host")
  unless (null (uriQuery uri) && null (uriFragment uri)) (invalid "cannot contain a query or fragment")
  unless (validAbsolutePathPrefix (Text.pack (uriPath uri))) (invalid "has an invalid absolute path")
 where
  invalid detail = Left (packProblem ("The OAuth " <> label <> " endpoint " <> detail <> ".") [endpoint])

validOAuthScope :: Text -> Bool
validOAuthScope scope =
  not (Text.null scope)
    && Text.length scope <= 512
    && Text.all (\character -> isAscii character && ord character >= 0x21 && ord character <= 0x7e) scope

validateHttpPermission :: [CredentialSlot] -> HttpPermission -> Either AppError ()
validateHttpPermission slots permission = do
  let methods = httpPermissionMethods permission
      validMethods = Set.fromList ["GET", "POST", "PUT", "PATCH", "DELETE"]
      slotIds = Set.fromList (credentialSlotId <$> slots)
  unless (not (null methods) && uniqueList methods && all (`Set.member` validMethods) methods) (invalid "HTTP methods must be a nonempty unique subset of the closed method catalog.")
  unless (validDnsHost (httpPermissionHost permission)) (invalid "An HTTP permission host must be one exact lowercase DNS name without wildcard or port.")
  unless (validAbsolutePathPrefix (httpPermissionPathPrefix permission)) (invalid "An HTTP permission path prefix is invalid.")
  traverse_ (\slot -> unless (slot `Set.member` slotIds) (invalid "An HTTP permission references an undeclared credential slot.")) (httpPermissionCredentialSlot permission)
 where
  invalid message = Left (packProblem message [])

validateProjection :: Text -> Either AppError ()
validateProjection projection =
  let (prefix, major) = Text.breakOnEnd "@" projection
   in unless
        ( not (Text.null prefix)
            && not (Text.null major)
            && Text.all isDigit major
            && Text.head major /= '0'
            && Text.all validProjectionCharacter (Text.dropEnd 1 prefix)
        )
        (Left (packProblem "A projection must be a named schema with an explicit positive major version." []))
 where
  validProjectionCharacter character = isAsciiLower character || isDigit character || character `elem` ("-._/" :: String)

validatePayloadFile :: PayloadFile -> Either AppError ()
validatePayloadFile payload = do
  validatePayloadPath (payloadFilePath payload)
  unless (payloadFileLength payload >= 0 && payloadFileLength payload <= fromIntegral maxFileBytes) (invalid "A payload file length is outside the 1.0 limit.")
  unless (validMediaType (payloadFileMediaType payload)) (invalid "A payload media type must be nonempty printable ASCII.")
  unless (validDigest (payloadFileSha256 payload)) (invalid "A payload SHA-256 must contain 64 lowercase hexadecimal characters.")
 where
  invalid message = Left (packProblem message [])

validateLinks :: PackLinks -> Either AppError ()
validateLinks links = traverse_ validateHttps (catMaybes [packHomepage links, packSource links, packChangelog links])
 where
  validateHttps value = unless ("https://" `Text.isPrefixOf` value && not (Text.any isSpace value)) (Left (packProblem "Pack informational links must be absolute HTTPS URLs." []))

validateComponentFiles :: Set Text -> PackComponent -> Either AppError ()
validateComponentFiles declared component = do
  requireDeclared (componentConfigurationSchema common)
  case component of
    DeclarativeComponent _ body -> requireDeclared body
    ExecutableComponent _ entry _ -> requireDeclared entry
 where
  common = componentCommon component
  requireDeclared relative =
    let path = componentRoot common <> "/" <> relative
     in unless (path `Set.member` declared) (Left (packProblem "A component references a payload file that is not declared." [path]))

validateOwnedExactlyOnce :: [Text] -> Text -> Either AppError ()
validateOwnedExactlyOnce roots path =
  unless (length (filter (`ownsPath` path) roots) == 1) (Left (packProblem "Every payload file must belong to exactly one component root." [path]))

validateSignatureShape :: PackSignatureDocument -> Either AppError ()
validateSignatureShape signature = do
  unless (validBase64UrlText (packSignaturePublicKey signature)) (invalid "The publisher public key is not unpadded base64url.")
  unless (validDigest (packSignatureKeyFingerprint signature)) (invalid "The publisher key fingerprint is not a lowercase SHA-256 digest.")
  unless (validBase64UrlText (packSignatureValue signature)) (invalid "The Pack signature is not unpadded base64url.")
 where
  invalid message = Left (packProblem message [])

validatePayload :: PackManifest -> Map Text ByteString -> Either AppError ()
validatePayload manifest payload = do
  let declared = Map.fromList [(payloadFilePath file, file) | file <- packFiles manifest]
  unless (Map.keysSet declared == Map.keysSet payload) (invalid "Archive payload entries do not match the manifest one-for-one.")
  traverse_
    ( \(path, bytes) -> case Map.lookup path declared of
        Nothing -> invalid "The archive contains an undeclared payload file."
        Just file -> do
          unless (payloadFileLength file == fromIntegral (ByteString.length bytes)) (invalid "A payload file length does not match the manifest.")
          unless (payloadFileSha256 file == sha256Hex bytes) (invalid "A payload file digest does not match the manifest.")
    )
    (Map.toAscList payload)
 where
  invalid message = Left (packProblem message [])

splitArchive :: [(Text, ByteString)] -> Either AppError (ByteString, ByteString, Map Text ByteString)
splitArchive entries = case entries of
  ("pack.json", manifest) : ("signature.json", signature) : rest -> do
    payload <- traverse stripPayload rest
    let paths = fmap fst payload
    unless (isSortedUtf8 paths) (invalid "Payload archive entries are not sorted by unsigned UTF-8 path bytes.")
    unless (uniqueList paths) (invalid "The archive contains a duplicate payload path.")
    pure (manifest, signature, Map.fromAscList payload)
  _ -> invalid "A Pack archive must begin with pack.json and signature.json."
 where
  stripPayload (path, bytes) = case Text.stripPrefix "payload/" path of
    Just relative -> validatePayloadPath relative >> pure (relative, bytes)
    Nothing -> invalid "Every entry after signature.json must be under payload/."
  invalid message = Left (packProblem message [])

parseCanonicalZip :: ByteString -> Either AppError [(Text, ByteString)]
parseCanonicalZip bytes = do
  unless (ByteString.length bytes <= maxArchiveBytes) (invalid "The Pack archive exceeds the bounded 1.0 size.")
  unless (ByteString.length bytes >= endRecordBytes) (invalid "The Pack archive is truncated.")
  let endOffset = ByteString.length bytes - endRecordBytes
      endBytes = ByteString.drop endOffset bytes
  (count, centralSize, centralOffset) <- runExactGet "end record" getEndRecord endBytes
  unless (count >= 2 && count <= maxEntryCount) (invalid "The Pack archive entry count is outside the 1.0 limit.")
  unless (centralOffset >= 0 && centralSize >= 0 && centralOffset + centralSize == endOffset) (invalid "The Pack central directory boundaries are invalid.")
  let localBytes = ByteString.take centralOffset bytes
      centralBytes = ByteString.take centralSize (ByteString.drop centralOffset bytes)
  localEntries <- runExactGet "local records" (replicateM count getLocalEntry) localBytes
  _ <- runExactGet "central directory" (replicateM count getCentralEntry) centralBytes
  decoded <- traverse decodeEntry localEntries
  rebuilt <- buildZip decoded
  unless (rebuilt == bytes) (invalid "The Pack ZIP is valid but not in the one canonical .lantpack encoding.")
  validateArchivePaths (fst <$> decoded)
  pure decoded
 where
  invalid message = Left (packProblem message [])

getEndRecord :: Get (Int, Int, Int)
getEndRecord = do
  expectWord32 0x06054b50
  disk <- getWord16le
  centralDisk <- getWord16le
  countOnDisk <- getWord16le
  count <- getWord16le
  centralSize <- getWord32le
  centralOffset <- getWord32le
  commentLength <- getWord16le
  unless (disk == 0 && centralDisk == 0 && countOnDisk == count && commentLength == 0) (fail "multi-disk or commented ZIP is not canonical")
  pure (fromIntegral count, fromIntegral centralSize, fromIntegral centralOffset)

getLocalEntry :: Get (ByteString, ByteString)
getLocalEntry = do
  expectWord32 0x04034b50
  _version <- getWord16le
  _flags <- getWord16le
  _method <- getWord16le
  _time <- getWord16le
  _date <- getWord16le
  _crc <- getWord32le
  compressedSize <- getWord32le
  _uncompressedSize <- getWord32le
  nameLength <- getWord16le
  extraLength <- getWord16le
  name <- getByteString (fromIntegral nameLength)
  _extra <- getByteString (fromIntegral extraLength)
  when (fromIntegral compressedSize > maxFileBytes) (fail "entry exceeds the per-file limit")
  content <- getByteString (fromIntegral compressedSize)
  pure (name, content)

getCentralEntry :: Get ()
getCentralEntry = do
  expectWord32 0x02014b50
  _ <- getWord16le
  _ <- getWord16le
  _ <- getWord16le
  _ <- getWord16le
  _ <- getWord16le
  _ <- getWord16le
  _ <- getWord32le
  _ <- getWord32le
  _ <- getWord32le
  nameLength <- getWord16le
  extraLength <- getWord16le
  commentLength <- getWord16le
  _ <- getWord16le
  _ <- getWord16le
  _ <- getWord32le
  _ <- getWord32le
  _ <- getByteString (fromIntegral nameLength)
  _ <- getByteString (fromIntegral extraLength)
  _ <- getByteString (fromIntegral commentLength)
  pure ()

decodeEntry :: (ByteString, ByteString) -> Either AppError (Text, ByteString)
decodeEntry (name, content) =
  either
    (const (Left (packProblem "A Pack ZIP entry name is not valid UTF-8." [])))
    (\decoded -> Right (decoded, content))
    (Text.decodeUtf8' name)

buildZip :: [(Text, ByteString)] -> Either AppError ByteString
buildZip entries = do
  unless (length entries <= maxEntryCount) (invalid "The Pack archive has too many entries.")
  traverse_ validateEntrySize entries
  let (_, records) = mapAccumL accumulate 0 entries
      localBuilders = [builder | (_, builder, _) <- records]
      centralOffset = sum [size | (size, _, _) <- records]
      centralBuilders = [central | (_, _, central) <- records]
      centralSize = sum (centralRecordSize <$> entries)
      count = fromIntegral (length entries)
      archive = mconcat localBuilders <> mconcat centralBuilders <> endRecord count centralSize centralOffset
  pure (LazyByteString.toStrict (toLazyByteString archive))
 where
  accumulate offset entry =
    let record@(size, _, _) = localRecord offset entry
     in (offset + size, record)
  invalid message = Left (packProblem message [])
  validateEntrySize (path, content) = do
    let nameLength = ByteString.length (Text.encodeUtf8 path)
    unless (nameLength <= maxPathBytes) (invalid "A Pack archive path exceeds 240 UTF-8 bytes.")
    unless (ByteString.length content <= maxFileBytes) (invalid "A Pack archive entry exceeds 16 MiB.")

localRecord :: Int -> (Text, ByteString) -> (Int, Builder, Builder)
localRecord offset (path, content) =
  let name = Text.encodeUtf8 path
      size = ByteString.length content
      checksum = crc32 content
      local =
        word32LE 0x04034b50
          <> word16LE 20
          <> word16LE 0x0800
          <> word16LE 0
          <> word16LE 0
          <> word16LE 0x0021
          <> word32LE checksum
          <> word32LE (fromIntegral size)
          <> word32LE (fromIntegral size)
          <> word16LE (fromIntegral (ByteString.length name))
          <> word16LE 0
          <> byteString name
          <> byteString content
      localSize = 30 + ByteString.length name + size
      central = centralRecord offset path content
   in (localSize, local, central)

centralRecord :: Int -> Text -> ByteString -> Builder
centralRecord offset path content =
  let name = Text.encodeUtf8 path
      size = ByteString.length content
   in word32LE 0x02014b50
        <> word16LE 0x0314
        <> word16LE 20
        <> word16LE 0x0800
        <> word16LE 0
        <> word16LE 0
        <> word16LE 0x0021
        <> word32LE (crc32 content)
        <> word32LE (fromIntegral size)
        <> word32LE (fromIntegral size)
        <> word16LE (fromIntegral (ByteString.length name))
        <> word16LE 0
        <> word16LE 0
        <> word16LE 0
        <> word16LE 0
        <> word32LE ((0o100644 :: Word32) * 0x10000)
        <> word32LE (fromIntegral offset)
        <> byteString name

centralRecordSize :: (Text, ByteString) -> Int
centralRecordSize (path, _) = 46 + ByteString.length (Text.encodeUtf8 path)

endRecord :: Word16 -> Int -> Int -> Builder
endRecord count centralSize centralOffset =
  word32LE 0x06054b50
    <> word16LE 0
    <> word16LE 0
    <> word16LE count
    <> word16LE count
    <> word32LE (fromIntegral centralSize)
    <> word32LE (fromIntegral centralOffset)
    <> word16LE 0

runExactGet :: Text -> Get value -> ByteString -> Either AppError value
runExactGet label parser bytes = case runGetOrFail parser (LazyByteString.fromStrict bytes) of
  Left (_, _, problem) -> Left (packProblem ("The Pack ZIP " <> label <> " is invalid.") [Text.pack problem])
  Right (remaining, _, value)
    | LazyByteString.null remaining -> Right value
    | otherwise -> Left (packProblem ("The Pack ZIP " <> label <> " has trailing bytes.") [])

expectWord32 :: Word32 -> Get ()
expectWord32 expected = do
  actual <- getWord32le
  unless (actual == expected) (fail "unexpected ZIP signature")

renderJcs :: Value -> Either Text Builder
renderJcs = \case
  Null -> Right "null"
  Bool True -> Right "true"
  Bool False -> Right "false"
  String value -> renderJcsString value
  Number value -> case floatingOrInteger value :: Either Double Integer of
    Left _ -> Left "Pack control JSON uses only interoperable integers"
    Right integer
      | abs integer > maxSafeJsonInteger -> Left "JSON integer exceeds the interoperable range"
      | otherwise -> Right (integerDec integer)
  Array values -> commaSeparated '[' ']' (traverse renderJcs (toList values))
  Object fields -> do
    let ordered = sortBy (comparing (utf16Units . Key.toText . fst)) (KeyMap.toList fields)
    rendered <- traverse renderField ordered
    commaSeparated '{' '}' (Right rendered)
 where
  renderField (key, value) = do
    renderedKey <- renderJcsString (Key.toText key)
    renderedValue <- renderJcs value
    pure (renderedKey <> char8 ':' <> renderedValue)

renderJcsString :: Text -> Either Text Builder
renderJcsString value
  | Text.any isSurrogate value = Left "JSON strings cannot contain Unicode surrogate code points"
  | otherwise = Right (char8 '"' <> foldMap renderCharacter (Text.unpack value) <> char8 '"')
 where
  renderCharacter = \case
    '"' -> "\\\""
    '\\' -> "\\\\"
    '\b' -> "\\b"
    '\t' -> "\\t"
    '\n' -> "\\n"
    '\f' -> "\\f"
    '\r' -> "\\r"
    character
      | ord character <= 0x1f -> string8 ("\\u" <> pad4 (showHex (ord character) ""))
      | otherwise -> byteString (Text.encodeUtf8 (Text.singleton character))
  pad4 digits = replicate (4 - length digits) '0' <> digits

commaSeparated :: Char -> Char -> Either Text [Builder] -> Either Text Builder
commaSeparated open close builders = do
  values <- builders
  pure (char8 open <> mconcat (intersperseBuilders (char8 ',') values) <> char8 close)

intersperseBuilders :: Builder -> [Builder] -> [Builder]
intersperseBuilders _ [] = []
intersperseBuilders separator (first : rest) = first : concatMap (\value -> [separator, value]) rest

utf16Units :: Text -> [Word16]
utf16Units = concatMap units . Text.unpack
 where
  units character
    | code <= 0xffff = [fromIntegral code]
    | otherwise =
        let adjusted = code - 0x10000
         in [fromIntegral (0xd800 + adjusted `div` 0x400), fromIntegral (0xdc00 + adjusted `mod` 0x400)]
   where
    code = ord character

validateArchivePaths :: [Text] -> Either AppError ()
validateArchivePaths paths = do
  traverse_ validateArchivePath paths
  unless (uniqueList paths) (Left (packProblem "The archive contains duplicate entry paths." []))
  validateNormalizationCollisions paths

validateArchivePath :: Text -> Either AppError ()
validateArchivePath path = do
  validatePath path
  unless (ByteString.length (Text.encodeUtf8 path) <= maxPathBytes) (Left (packProblem "An archive path exceeds 240 UTF-8 bytes." [path]))

validatePayloadPath :: Text -> Either AppError ()
validatePayloadPath path = validatePath path >> unless (ByteString.length (Text.encodeUtf8 ("payload/" <> path)) <= maxPathBytes) (Left (packProblem "A payload archive path exceeds 240 UTF-8 bytes." [path]))

validateRelativeReference :: Text -> Either AppError ()
validateRelativeReference = validatePath

validatePath :: Text -> Either AppError ()
validatePath path =
  let components = Text.splitOn "/" path
   in unless
        ( not (Text.null path)
            && not ("/" `Text.isPrefixOf` path)
            && not (Text.any (\character -> character == '\\' || character == '\0') path)
            && all (\component -> not (Text.null component) && component /= "." && component /= "..") components
        )
        (Left (packProblem "A Pack path is unsafe or noncanonical." [path]))

validateNormalizationCollisions :: [Text] -> Either AppError ()
validateNormalizationCollisions paths =
  let normalized = fmap (Unicode.normalize Unicode.NFC) paths
   in unless (uniqueList normalized) (Left (packProblem "Pack paths collide after Unicode normalization." []))

componentCommon :: PackComponent -> ComponentCommon
componentCommon = \case
  DeclarativeComponent common _ -> common
  ExecutableComponent common _ _ -> common

ownsPath :: Text -> Text -> Bool
ownsPath root path = (root <> "/") `Text.isPrefixOf` path

pairwiseNonoverlapping :: [Text] -> Bool
pairwiseNonoverlapping roots = and [not (left `ownsPath` right || right `ownsPath` left || left == right) | (index, left) <- zip [0 :: Int ..] roots, right <- drop (index + 1) roots]

uniqueBy :: (Ord key) => Text -> (value -> key) -> [value] -> Either AppError ()
uniqueBy label key values = unless (uniqueList (key <$> values)) (Left (packProblem ("The Pack contains a duplicate " <> label <> ".") []))

unique :: (Ord value) => Text -> [value] -> Either AppError ()
unique label values = unless (uniqueList values) (Left (packProblem ("The Pack contains a duplicate " <> label <> ".") []))

uniqueList :: (Ord value) => [value] -> Bool
uniqueList values = Set.size (Set.fromList values) == length values

isSortedUtf8 :: [Text] -> Bool
isSortedUtf8 values = values == sortBy (comparing Text.encodeUtf8) values

validReverseDns :: Text -> Bool
validReverseDns value =
  let labels = Text.splitOn "." value
   in length labels >= 2 && all validDnsLabel labels

validDnsHost :: Text -> Bool
validDnsHost value =
  let labels = Text.splitOn "." value
   in not (null labels) && all validDnsLabel labels

validDnsLabel :: Text -> Bool
validDnsLabel label =
  not (Text.null label)
    && Text.length label <= 63
    && lowerDigit (Text.head label)
    && lowerDigit (Text.last label)
    && Text.all (\character -> lowerDigit character || character == '-') label
 where
  lowerDigit character = isAsciiLower character || isDigit character

validLocalId :: Text -> Bool
validLocalId value =
  not (Text.null value)
    && Text.length value <= 64
    && isAsciiLower (Text.head value)
    && Text.all (\character -> isAsciiLower character || isDigit character || character `elem` ("._-" :: String)) value

validSemVer :: Text -> Bool
validSemVer value = case Text.breakOn "+" value of
  (withoutBuild, buildWithPlus) ->
    let build = Text.drop 1 buildWithPlus
        buildValid = Text.null buildWithPlus || validIdentifiers False build
        (core, preWithHyphen) = Text.breakOn "-" withoutBuild
        pre = Text.drop 1 preWithHyphen
        preValid = Text.null preWithHyphen || validIdentifiers True pre
     in buildValid && preValid && validCore core
 where
  validCore core = case Text.splitOn "." core of
    [major, minor, patch] -> all validNumeric [major, minor, patch]
    _ -> False
  validNumeric part = not (Text.null part) && Text.all isDigit part && (Text.length part == 1 || Text.head part /= '0')
  validIdentifiers numericRule text =
    let parts = Text.splitOn "." text
     in not (null parts) && all (validIdentifier numericRule) parts
  validIdentifier numericRule part =
    not (Text.null part)
      && Text.all (\character -> isAscii character && (isAsciiLower character || isAsciiUpper character || isDigit character || character == '-')) part
      && (not numericRule || not (Text.all isDigit part) || Text.length part == 1 || Text.head part /= '0')

validAbsolutePathPrefix :: Text -> Bool
validAbsolutePathPrefix path =
  "/" `Text.isPrefixOf` path
    && not (Text.any (\character -> character == '?' || character == '#' || character == '\\' || character == '\0') path)
    && (path == "/" || all (\part -> not (Text.null part) && part /= "." && part /= "..") (Text.splitOn "/" (Text.drop 1 path)))

validMediaType :: Text -> Bool
validMediaType value = nonemptyText value && value == Text.strip value && Text.all (\character -> isAscii character && ord character >= 0x20 && ord character <= 0x7e) value

validDigest :: Text -> Bool
validDigest value = Text.length value == 64 && Text.all (\character -> isDigit character || character >= 'a' && character <= 'f') value

validBase64UrlText :: Text -> Bool
validBase64UrlText value = not (Text.null value) && Text.all (\character -> isAscii character && (isAsciiLower character || isAsciiUpper character || isDigit character || character == '-' || character == '_')) value

nonemptyText :: Text -> Bool
nonemptyText = not . Text.null . Text.strip

isSurrogate :: Char -> Bool
isSurrogate character = let code = ord character in code >= 0xd800 && code <= 0xdfff

componentKindText :: PackComponentKind -> Text
componentKindText = \case
  BrickNatureComponent -> "BrickNature"
  BrickTemplateComponent -> "BrickTemplate"
  ImportProfilePresetComponent -> "ImportProfilePreset"
  SourceAdapterComponent -> "SourceAdapter"
  ReadOnlyExporterComponent -> "ReadOnlyExporter"
  UIAdapterComponent -> "UIAdapter"

parseComponentKind :: Text -> Parser PackComponentKind
parseComponentKind = \case
  "BrickNature" -> pure BrickNatureComponent
  "BrickTemplate" -> pure BrickTemplateComponent
  "ImportProfilePreset" -> pure ImportProfilePresetComponent
  "SourceAdapter" -> pure SourceAdapterComponent
  "ReadOnlyExporter" -> pure ReadOnlyExporterComponent
  "UIAdapter" -> pure UIAdapterComponent
  value -> fail ("unknown Pack component kind: " <> Text.unpack value)

isDeclarativeKind :: PackComponentKind -> Bool
isDeclarativeKind kind = kind `elem` [BrickNatureComponent, BrickTemplateComponent, ImportProfilePresetComponent]

credentialSchemeText :: CredentialScheme -> Text
credentialSchemeText = \case
  OAuthAuthorizationCodePkce -> "oauth2_authorization_code_pkce"
  OAuthDeviceAuthorization -> "oauth2_device_authorization"
  BearerToken -> "bearer_token"
  ApiKey -> "api_key"

parseCredentialScheme :: Text -> Parser CredentialScheme
parseCredentialScheme = \case
  "oauth2_authorization_code_pkce" -> pure OAuthAuthorizationCodePkce
  "oauth2_device_authorization" -> pure OAuthDeviceAuthorization
  "bearer_token" -> pure BearerToken
  "api_key" -> pure ApiKey
  value -> fail ("unknown credential scheme: " <> Text.unpack value)

effectPermissionText :: EffectPermission -> Text
effectPermissionText = \case
  DelegationDeliveryPermission -> "delegation_delivery"
  DelegationTakeBackNoticePermission -> "delegation_take_back_notice"
  SourceCleanupItemPermission -> "source_cleanup_item"
  SourceCleanupContainerPermission -> "source_cleanup_container"
  CalendarCreatePermission -> "calendar_create"
  CalendarUpdatePermission -> "calendar_update"
  CalendarCancelPermission -> "calendar_cancel"

parseEffectPermission :: Text -> Parser EffectPermission
parseEffectPermission = \case
  "delegation_delivery" -> pure DelegationDeliveryPermission
  "delegation_take_back_notice" -> pure DelegationTakeBackNoticePermission
  "source_cleanup_item" -> pure SourceCleanupItemPermission
  "source_cleanup_container" -> pure SourceCleanupContainerPermission
  "calendar_create" -> pure CalendarCreatePermission
  "calendar_update" -> pure CalendarUpdatePermission
  "calendar_cancel" -> pure CalendarCancelPermission
  value -> fail ("unknown effect purpose: " <> Text.unpack value)

hostCapabilityText :: HostCapability -> Text
hostCapabilityText = \case
  InputBytesCapability -> "input_bytes"
  LoopbackHttpCapability -> "loopback_http"
  StaticAssetsCapability -> "static_assets"

parseHostCapability :: Text -> Parser HostCapability
parseHostCapability = \case
  "input_bytes" -> pure InputBytesCapability
  "loopback_http" -> pure LoopbackHttpCapability
  "static_assets" -> pure StaticAssetsCapability
  value -> fail ("unknown host capability: " <> Text.unpack value)

requireSchema :: Object -> Text -> Parser ()
requireSchema fields expected = do
  actual <- fields .: "schema"
  unless (actual == expected) (fail ("unsupported schema: " <> Text.unpack actual))

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown fields allowed =
  let accepted = Set.fromList allowed
      unknown = filter (`Set.notMember` accepted) (Key.toText <$> KeyMap.keys fields)
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

packProblem :: Text -> [Text] -> AppError
packProblem message details =
  (appError InvalidInput message)
    { appErrorDetails = details
    , appErrorRecovery = [RecoveryAction "inspect-pack" "Inspect the signed Pack source and build a canonical archive before retrying." Nothing]
    }

maxEntryCount :: Int
maxEntryCount = 4096

maxPathBytes :: Int
maxPathBytes = 240

maxFileBytes :: Int
maxFileBytes = 16 * 1024 * 1024

maxPayloadBytes :: Integer
maxPayloadBytes = 64 * 1024 * 1024

maxArchiveBytes :: Int
maxArchiveBytes = fromIntegral (maxPayloadBytes + 32 * 1024 * 1024)

endRecordBytes :: Int
endRecordBytes = 22

maxSafeJsonInteger :: Integer
maxSafeJsonInteger = 9007199254740991

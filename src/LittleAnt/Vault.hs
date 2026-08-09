module LittleAnt.Vault (
  CredentialScheme (..),
  Vault,
  VaultEntry,
  VaultInventoryEntry (..),
  emptyVault,
  insertVaultEntry,
  updateVaultEntry,
  removeVaultEntry,
  vaultInventory,
  resolveVaultEntrySecret,
  credentialSchemeName,
  parseCredentialSchemeName,
  vaultRevision,
  readVault,
  writeVault,
  backupVault,
  rotateVault,
  diagnoseVault,
)
where

import Control.Exception (IOException, bracketOnError, catch)
import Control.Monad (unless, when)
import Data.Aeson
import Data.Aeson.Encoding qualified as Encoding
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.Bits ((.&.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Vault.Age
import System.Directory hiding (isSymbolicLink)
import System.FilePath (takeDirectory)
import System.IO
import System.Posix.Files
import System.Posix.IO (FdOption (CloseOnExec), OpenFileFlags (cloexec, creat, exclusive), OpenMode (ReadOnly, WriteOnly), closeFd, defaultFileFlags, fdToHandle, handleToFd, openFd, setFdOption)
import System.Posix.Unistd (fileSynchronise)

data CredentialScheme
  = OAuthAuthorizationCodePKCE
  | OAuthDeviceAuthorization
  | BearerCredential
  | ApiKeyCredential
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data Vault = Vault
  { vaultIdentity :: UUIDv7
  , vaultRevision :: Integer
  , vaultEntries :: Map UUIDv7 VaultEntry
  }
  deriving stock (Eq)

data VaultEntry = VaultEntry
  { vaultEntryIdentity :: UUIDv7
  , vaultEntryScheme :: CredentialScheme
  , vaultEntryLabel :: Text
  , vaultEntrySecret :: Text
  , vaultEntryMetadata :: Map Text Text
  }
  deriving stock (Eq)

data VaultInventoryEntry = VaultInventoryEntry
  { inventoryIdentity :: UUIDv7
  , inventoryScheme :: CredentialScheme
  , inventoryLabel :: Text
  , inventoryRedactedSuffix :: Maybe Text
  }
  deriving stock (Eq, Show)

emptyVault :: UUIDv7 -> Vault
emptyVault identity = Vault identity 1 Map.empty

insertVaultEntry :: UUIDv7 -> CredentialScheme -> Text -> Text -> Map Text Text -> Vault -> Either AppError Vault
insertVaultEntry identity scheme suppliedLabel suppliedSecret metadata vault
  | Map.member identity (vaultEntries vault) = Left (appError Conflict "That vault-entry identity already exists.")
  | Text.null label = Left (appError InvalidInput "A vault entry label cannot be empty.")
  | Text.null suppliedSecret = Left (appError InvalidInput "Secret material cannot be empty.")
  | otherwise =
      Right
        vault
          { vaultRevision = vaultRevision vault + 1
          , vaultEntries = Map.insert identity (VaultEntry identity scheme label suppliedSecret metadata) (vaultEntries vault)
          }
 where
  label = Text.strip suppliedLabel

updateVaultEntry :: UUIDv7 -> CredentialScheme -> Text -> Map Text Text -> Vault -> Either AppError Vault
updateVaultEntry identity suppliedScheme suppliedSecret metadata vault
  | Text.null suppliedSecret = Left (appError InvalidInput "Secret material cannot be empty.")
  | otherwise = case Map.lookup identity (vaultEntries vault) of
      Nothing -> Left (appError NotFound "No vault entry matches that identity.")
      Just entry
        | vaultEntryScheme entry /= suppliedScheme ->
            Left (appError PreconditionFailed "A vault entry cannot change credential scheme during an atomic update.")
      Just entry ->
        Right
          vault
            { vaultRevision = vaultRevision vault + 1
            , vaultEntries = Map.insert identity entry{vaultEntrySecret = suppliedSecret, vaultEntryMetadata = metadata} (vaultEntries vault)
            }

removeVaultEntry :: UUIDv7 -> Vault -> Either AppError Vault
removeVaultEntry identity vault
  | Map.notMember identity (vaultEntries vault) = Left (appError NotFound "No vault entry matches that identity.")
  | otherwise =
      Right
        vault
          { vaultRevision = vaultRevision vault + 1
          , vaultEntries = Map.delete identity (vaultEntries vault)
          }

vaultInventory :: Vault -> [VaultInventoryEntry]
vaultInventory vault = fmap inventory (Map.elems (vaultEntries vault))
 where
  inventory entry =
    VaultInventoryEntry
      (vaultEntryIdentity entry)
      (vaultEntryScheme entry)
      (vaultEntryLabel entry)
      (redactedSuffix (vaultEntryScheme entry) (vaultEntrySecret entry))
  redactedSuffix scheme secret
    | elem scheme [BearerCredential, ApiKeyCredential] && Text.length secret >= 4 = Just (Text.takeEnd 4 secret)
    | otherwise = Nothing

resolveVaultEntrySecret :: UUIDv7 -> Vault -> Either AppError Text
resolveVaultEntrySecret identity vault =
  maybe
    (Left (appError NotFound "No vault entry matches that identity."))
    (Right . vaultEntrySecret)
    (Map.lookup identity (vaultEntries vault))

credentialSchemeName :: CredentialScheme -> Text
credentialSchemeName = schemeName

parseCredentialSchemeName :: Text -> Either AppError CredentialScheme
parseCredentialSchemeName supplied =
  maybe
    (Left (appError InvalidInput "The credential scheme is unsupported."))
    Right
    (lookup supplied [(schemeName scheme, scheme) | scheme <- [minBound .. maxBound]])

writeVault :: FilePath -> Passphrase -> Vault -> IO (Either AppError ())
writeVault path passphrase vault =
  encryptAge passphrase (encodeVault vault) >>= \case
    Left problem -> pure (Left problem)
    Right ciphertext ->
      decryptAge passphrase ciphertext >>= \case
        Left problem -> pure (Left problem)
        Right verifiedPlaintext ->
          case eitherDecodeStrict' verifiedPlaintext of
            Right verified | verified == vault -> writeVerifiedCiphertext path ciphertext
            _ -> pure (Left (appError CorruptData "The encrypted vault candidate failed verification before replacement."))

writeVerifiedCiphertext :: FilePath -> ByteString -> IO (Either AppError ())
writeVerifiedCiphertext path ciphertext = handleVaultIO $ do
  let directory = takeDirectory path
  ensurePrivateDirectory directory
  rejectSymlink path
  bracketOnError
    (openBinaryTempFile directory ".lant-vault.tmp")
    (\(temporary, handle) -> catch (hClose handle) ignoreIOException >> removeIfPresent temporary)
    ( \(temporary, handle) -> do
        setFileMode temporary 0o600
        ByteString.hPut handle ciphertext
        hFlush handle
        descriptor <- handleToFd handle
        setFdOption descriptor CloseOnExec True
        fileSynchronise descriptor
        closeFd descriptor
        renameFile temporary path
        setFileMode path 0o600
        syncDirectory directory
        pure (Right ())
    )

readVault :: FilePath -> Passphrase -> IO (Either AppError Vault)
readVault path passphrase =
  handleVaultIO $ do
    status <- getSymbolicLinkStatus path
    when (isSymbolicLink status || not (isRegularFile status)) $
      ioError (userError "vault path is not a regular non-symlink file")
    when (fileMode status .&. 0o077 /= 0) $
      ioError (userError "vault permissions expose data beyond the owner")
    ciphertext <- ByteString.readFile path
    decryptAge passphrase ciphertext >>= \case
      Left problem -> pure (Left problem)
      Right plaintext ->
        pure $
          case eitherDecodeStrict' plaintext of
            Left _ ->
              Left
                (appError CorruptData "The decrypted vault payload is invalid.")
                  { appErrorRecovery = [RecoveryAction "diagnose" "Inspect vault integrity without revealing secrets." (Just "lant vault diagnose")]
                  }
            Right vault -> Right vault

backupVault :: FilePath -> FilePath -> IO (Either AppError ())
backupVault source destination =
  handleVaultIO $ do
    sourceStatus <- getSymbolicLinkStatus source
    when (isSymbolicLink sourceStatus || not (isRegularFile sourceStatus)) $
      ioError (userError "vault source is not a regular non-symlink file")
    ciphertext <- ByteString.readFile source
    case validateAgeHeader ciphertext of
      Left problem -> pure (Left problem)
      Right () -> do
        let parent = takeDirectory destination
        parentExists <- doesDirectoryExist parent
        unless parentExists (ioError (userError "backup parent directory does not exist"))
        destinationExists <- doesPathExist destination
        when destinationExists (ioError (userError "backup destination already exists"))
        descriptor <- openFd destination WriteOnly defaultFileFlags{exclusive = True, creat = Just 0o600, cloexec = True}
        handle <- fdToHandle descriptor
        ByteString.hPut handle ciphertext
        hFlush handle
        synced <- handleToFd handle
        fileSynchronise synced
        closeFd synced
        syncDirectory parent
        pure (Right ())

rotateVault :: FilePath -> Passphrase -> Passphrase -> IO (Either AppError ())
rotateVault path current replacement =
  readVault path current >>= \case
    Left problem -> pure (Left problem)
    Right vault ->
      writeVault path replacement vault >>= \case
        Left problem -> pure (Left problem)
        Right () ->
          readVault path replacement >>= \case
            Left problem -> pure (Left problem)
            Right verified
              | verified == vault -> pure (Right ())
              | otherwise -> pure (Left (appError CorruptData "The rotated vault failed verification."))

diagnoseVault :: FilePath -> IO (Either AppError [Text])
diagnoseVault path =
  handleVaultIO $ do
    status <- getSymbolicLinkStatus path
    when (isSymbolicLink status || not (isRegularFile status)) $
      ioError (userError "vault path is not a regular non-symlink file")
    let permissionsSafe = fileMode status .&. 0o077 == 0
    unless permissionsSafe (ioError (userError "vault permissions expose data beyond the owner"))
    ciphertext <- ByteString.readFile path
    pure $ do
      validateAgeHeader ciphertext
      Right
        [ "path_type: regular_file"
        , "permissions: private"
        , "age_header: age-v1-scrypt-2^18"
        , "ciphertext_bytes: " <> Text.pack (show (ByteString.length ciphertext))
        ]

encodeVault :: Vault -> ByteString
encodeVault =
  LazyByteString.toStrict
    . Encoding.encodingToLazyByteString
    . vaultEncoding

vaultEncoding :: Vault -> Encoding.Encoding
vaultEncoding vault =
  Encoding.pairs $
    Encoding.pair "schema" (Encoding.text "little-ant/vault@1")
      <> Encoding.pair "vault_id" (Encoding.text (renderUUIDv7 (vaultIdentity vault)))
      <> Encoding.pair "revision" (Encoding.integer (vaultRevision vault))
      <> Encoding.pair "entries" (Encoding.list vaultEntryEncoding (Map.elems (vaultEntries vault)))

vaultEntryEncoding :: VaultEntry -> Encoding.Encoding
vaultEntryEncoding entry =
  Encoding.pairs $
    Encoding.pair "id" (Encoding.text (renderUUIDv7 (vaultEntryIdentity entry)))
      <> Encoding.pair "scheme" (Encoding.text (schemeName (vaultEntryScheme entry)))
      <> Encoding.pair "label" (Encoding.text (vaultEntryLabel entry))
      <> Encoding.pair "secret" (Encoding.text (vaultEntrySecret entry))
      <> Encoding.pair "metadata" (Encoding.pairs (foldMap encodeMetadata (Map.toAscList (vaultEntryMetadata entry))))
 where
  encodeMetadata (key, value) = Encoding.pair (Key.fromText key) (Encoding.text value)

instance FromJSON Vault where
  parseJSON = withObject "Vault" $ \object -> do
    rejectUnknown object ["schema", "vault_id", "revision", "entries"]
    schema <- object .: "schema"
    unless (schema == ("little-ant/vault@1" :: Text)) (fail "unsupported vault schema")
    identity <- object .: "vault_id" >>= parseIdentity
    revision <- object .: "revision"
    unless (revision >= (1 :: Integer)) (fail "vault revision must be positive")
    entries <- object .: "entries"
    parsed <- traverse parseJSON entries
    let identities = fmap vaultEntryIdentity parsed
    unless (length identities == Set.size (Set.fromList identities)) (fail "duplicate vault-entry identity")
    pure (Vault identity revision (Map.fromList [(vaultEntryIdentity entry, entry) | entry <- parsed]))

instance FromJSON VaultEntry where
  parseJSON = withObject "VaultEntry" $ \object -> do
    rejectUnknown object ["id", "scheme", "label", "secret", "metadata"]
    identity <- object .: "id" >>= parseIdentity
    scheme <- object .: "scheme" >>= parseScheme
    label <- object .: "label"
    secret <- object .: "secret"
    metadata <- object .: "metadata"
    unless (not (Text.null (Text.strip label)) && not (Text.null secret)) (fail "vault entry label and secret must be nonempty")
    pure (VaultEntry identity scheme label secret metadata)

instance ToJSON VaultInventoryEntry where
  toJSON entry =
    object $
      [ "id" .= renderUUIDv7 (inventoryIdentity entry)
      , "scheme" .= schemeName (inventoryScheme entry)
      , "label" .= inventoryLabel entry
      ]
        <> maybe [] (pure . ("redacted_suffix" .=)) (inventoryRedactedSuffix entry)

instance FromJSON VaultInventoryEntry where
  parseJSON = withObject "VaultInventoryEntry" $ \fields -> do
    rejectUnknown fields ["id", "scheme", "label", "redacted_suffix"]
    identity <- fields .: "id" >>= parseIdentity
    scheme <- fields .: "scheme" >>= parseScheme
    VaultInventoryEntry identity scheme <$> fields .: "label" <*> fields .:? "redacted_suffix"

parseIdentity :: Text -> Parser UUIDv7
parseIdentity supplied = either (fail . Text.unpack) pure (parseUUIDv7 supplied)

parseScheme :: Text -> Parser CredentialScheme
parseScheme supplied = maybe (fail "unknown credential scheme") pure (lookup supplied [(schemeName scheme, scheme) | scheme <- [minBound .. maxBound]])

schemeName :: CredentialScheme -> Text
schemeName = \case
  OAuthAuthorizationCodePKCE -> "oauth2_authorization_code_pkce"
  OAuthDeviceAuthorization -> "oauth2_device_authorization"
  BearerCredential -> "bearer"
  ApiKeyCredential -> "api_key"

rejectUnknown :: Object -> [Text] -> Parser ()
rejectUnknown object allowed =
  let accepted = Set.fromList allowed
      unknown = filter (\key -> Set.notMember key accepted) (fmap Key.toText (KeyMap.keys object))
   in unless (null unknown) (fail ("unknown keys: " <> Text.unpack (Text.intercalate ", " unknown)))

ensurePrivateDirectory :: FilePath -> IO ()
ensurePrivateDirectory directory = do
  exists <- doesPathExist directory
  if exists
    then do
      status <- getSymbolicLinkStatus directory
      when (isSymbolicLink status || not (isDirectory status)) (ioError (userError "vault parent is not a regular directory"))
    else createDirectoryIfMissing True directory
  setFileMode directory 0o700

rejectSymlink :: FilePath -> IO ()
rejectSymlink path = do
  exists <- doesPathExist path
  when exists $ do
    status <- getSymbolicLinkStatus path
    when (isSymbolicLink status || not (isRegularFile status)) (ioError (userError "vault target is not a regular file"))

syncDirectory :: FilePath -> IO ()
syncDirectory path = do
  descriptor <- openFd path ReadOnly defaultFileFlags
  fileSynchronise descriptor
  closeFd descriptor

removeIfPresent :: FilePath -> IO ()
removeIfPresent path = do
  exists <- doesFileExist path
  when exists (removeFile path)

handleVaultIO :: IO (Either AppError value) -> IO (Either AppError value)
handleVaultIO action = catch action $ \problem ->
  pure . Left $
    (appError ExternalFailure "Little Ant could not access the encrypted vault safely.")
      { appErrorDetails = [Text.pack (show (problem :: IOException))]
      , appErrorRetrySafety = DoNotRetry
      , appErrorRecovery = [RecoveryAction "diagnose" "Inspect permissions, path type, and ciphertext integrity." (Just "lant vault diagnose")]
      }

ignoreIOException :: IOException -> IO ()
ignoreIOException _ = pure ()

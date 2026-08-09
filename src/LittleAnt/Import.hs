module LittleAnt.Import (
  ImportSourceDescriptor (..),
  ImportRead (..),
  ImportMaterialization (..),
  ProviderImportSource (..),
  ImportPort (..),
  emptyImportPort,
  packRegistryImportPort,
  packRegistryImportPortWithProviders,
)
where

import Control.Exception (IOException, displayException, finally, try)
import Control.Monad (unless, void)
import Data.Aeson (Value)
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (defaultTimeLocale, formatTime)
import LittleAnt.Error
import LittleAnt.Model (EffectAdapterCustody (..), SourceCleanupContainerTarget (..), SourceCleanupItemTarget (..), SourceMode (..))
import LittleAnt.Pack.Format (EffectPermission (SourceCleanupContainerPermission, SourceCleanupItemPermission), PackComponent (..), componentContractMajor, componentId, permissionEffectPurposes)
import LittleAnt.Pack.Http (PackHttpBroker)
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Trust (PackArtifactIdentity (..))
import LittleAnt.Source
import LittleAnt.TaskJugglerActuals
import System.FilePath (normalise, takeFileName)
import System.IO (hClose)
import System.Posix.Files (fileSize, getFdStatus, getSymbolicLinkStatus, isRegularFile, isSymbolicLink)
import System.Posix.IO (OpenMode (ReadOnly), cloexec, closeFd, defaultFileFlags, fdToHandle, nofollow, openFd)
import System.Posix.Types (FileOffset)

data ImportSourceDescriptor = ImportSourceDescriptor
  { importSourceId :: Text
  , importSourceDisplayName :: Text
  , importSourceExtensions :: [Text]
  , importSourceModes :: [SourceMode]
  }
  deriving stock (Eq, Show)

data ImportRead = ImportRead
  { importReadSourceReference :: Text
  , importReadInput :: SourceInput
  , importReadPreflight :: SourcePreflight
  }
  deriving stock (Eq, Show)

data ImportMaterialization = ImportMaterialization
  { importMaterializationRead :: ImportRead
  , importMaterializationObjects :: Map.Map Text SourceMaterial
  }
  deriving stock (Eq, Show)

data ProviderImportSource = ProviderImportSource
  { providerImportReference :: Text
  , providerImportCanonicalReference :: Text
  , providerImportAdapterId :: Text
  , providerImportDisplayName :: Text
  , providerImportInputLabel :: Text
  , providerImportModes :: [SourceMode]
  , providerImportConfiguration :: Value
  , providerImportCredentialBindingReference :: Text
  , providerImportBroker :: PackHttpBroker
  }

data ImportPort = ImportPort
  { importPortCatalog :: [ImportSourceDescriptor]
  , importPortPreflight :: Text -> SourceMode -> IO (Either AppError ImportRead)
  , importPortMaterialize :: Text -> SourceMode -> IO (Either AppError ImportMaterialization)
  , importPortCleanupCustody :: Text -> Either AppError EffectAdapterCustody
  , importPortCleanupItem :: EffectAdapterCustody -> SourceCleanupItemTarget -> IO (Either AppError SourceCleanupReceipt)
  , importPortVerifyCleanupItem :: EffectAdapterCustody -> SourceCleanupItemTarget -> IO (Either AppError SourceCleanupReceipt)
  , importPortInspectCleanupContainer :: EffectAdapterCustody -> Text -> IO (Either AppError SourceContainerInspection)
  , importPortCleanupContainer :: EffectAdapterCustody -> SourceCleanupContainerTarget -> IO (Either AppError SourceCleanupReceipt)
  , importPortVerifyCleanupContainer :: EffectAdapterCustody -> SourceCleanupContainerTarget -> IO (Either AppError SourceCleanupReceipt)
  }

emptyImportPort :: ImportPort
emptyImportPort =
  ImportPort
    []
    (\source _ -> pure . Left $ unavailable source)
    (\source _ -> pure . Left $ unavailable source)
    (Left . unavailable)
    (\custody _ -> pure . Left $ unavailable (effectAdapterProviderAccount custody))
    (\custody _ -> pure . Left $ unavailable (effectAdapterProviderAccount custody))
    (\custody _ -> pure . Left $ unavailable (effectAdapterProviderAccount custody))
    (\custody _ -> pure . Left $ unavailable (effectAdapterProviderAccount custody))
    (\custody _ -> pure . Left $ unavailable (effectAdapterProviderAccount custody))
 where
  unavailable source =
    (appError Unsupported "No SourceAdapter is available in this host environment.")
      { appErrorSubject = Just source
      , appErrorRecovery = [RecoveryAction "packs" "Inspect the enabled SourceAdapters." (Just "lant packs list")]
      }

packRegistryImportPort :: PackRunnerClient -> PackRegistry -> ImportPort
packRegistryImportPort runner registry = packRegistryImportPortWithProviders runner registry []

packRegistryImportPortWithProviders :: PackRunnerClient -> PackRegistry -> [ProviderImportSource] -> ImportPort
packRegistryImportPortWithProviders runner registry providers =
  ImportPort
    (fileDescriptors <> providerDescriptors)
    preflight
    materialize
    cleanupCustody
    cleanupItem
    verifyCleanupItem
    inspectCleanupContainer
    cleanupContainer
    verifyCleanupContainer
 where
  preflight source mode = case providersFor source of
    [provider] -> preflightProvider provider mode
    [] -> readFileWith source mode $ \descriptor component input -> do
      invokePackSourcePreflight runner component mode input >>= \case
        Left problem -> pure (Left problem)
        Right preview -> pure $ do
          verifyCoreCustody descriptor input preview
          Right (ImportRead (normalizedReference source) input preview)
    _ -> pure (Left (ambiguousProviderReference source))
  materialize source mode = case providersFor source of
    [provider] -> materializeProvider provider mode
    [] -> readFileWith source mode $ \descriptor component input -> do
      invokePackSourceMaterialize runner component mode input >>= \case
        Left problem -> pure (Left problem)
        Right (preview, materialization) -> pure $ do
          verifyCoreCustody descriptor input preview
          validateSourceAdapterMaterialization materialization
          Right
            ( ImportMaterialization
                (ImportRead (normalizedReference source) input preview)
                (materializedObjects materialization)
            )
    _ -> pure (Left (ambiguousProviderReference source))
  preflightProvider provider mode = case validateProviderMode provider mode >> lookupPackComponent (providerImportAdapterId provider) registry of
    Left problem -> pure (Left problem)
    Right component ->
      invokePackSourcePreflightHttp runner (providerImportBroker provider) component mode (providerImportInputLabel provider) (providerImportConfiguration provider) >>= \case
        Left problem -> pure (Left problem)
        Right (input, preview) -> pure (Right (ImportRead (providerImportCanonicalReference provider) input preview))
  materializeProvider provider mode = case validateProviderMode provider mode >> lookupPackComponent (providerImportAdapterId provider) registry of
    Left problem -> pure (Left problem)
    Right component ->
      invokePackSourceMaterializeHttp runner (providerImportBroker provider) component mode (providerImportInputLabel provider) (providerImportConfiguration provider) >>= \case
        Left problem -> pure (Left problem)
        Right (input, preview, materialization) -> pure $ do
          validateSourceAdapterMaterialization materialization
          Right
            ( ImportMaterialization
                (ImportRead (providerImportCanonicalReference provider) input preview)
                (materializedObjects materialization)
            )
  cleanupCustody source = do
    provider <- uniqueProvider source
    component <- lookupPackComponent (providerImportAdapterId provider) registry
    makeCleanupCustody provider component
  cleanupItem suppliedCustody target = case matchingCleanupProviders suppliedCustody of
    [(provider, component)] ->
      case makeCleanupCustody provider component of
        Left problem -> pure (Left problem)
        Right currentCustody
          | currentCustody /= suppliedCustody -> pure . Left $ cleanupAuthorityChanged suppliedCustody
          | otherwise ->
              invokePackSourceCleanupItemHttp
                runner
                (providerImportBroker provider)
                component
                (providerImportConfiguration provider)
                (cleanupItemExternalIdentity target)
                (cleanupItemLocator target)
                (cleanupItemContainerIdentity target)
    [] -> pure . Left $ cleanupAuthorityChanged suppliedCustody
    _ -> pure . Left $ sourceProblem CorruptData "Several current provider bindings claim one cleanup authority."
  verifyCleanupItem suppliedCustody target = case matchingCleanupProviders suppliedCustody of
    [(provider, component)] ->
      case makeCleanupCustody provider component of
        Left problem -> pure (Left problem)
        Right currentCustody
          | currentCustody /= suppliedCustody -> pure . Left $ cleanupAuthorityChanged suppliedCustody
          | otherwise ->
              invokePackSourceCleanupItemVerifyHttp
                runner
                (providerImportBroker provider)
                component
                (providerImportConfiguration provider)
                (cleanupItemExternalIdentity target)
                (cleanupItemLocator target)
                (cleanupItemContainerIdentity target)
    [] -> pure . Left $ cleanupAuthorityChanged suppliedCustody
    _ -> pure . Left $ sourceProblem CorruptData "Several current provider bindings claim one cleanup authority."
  inspectCleanupContainer suppliedCustody externalIdentity = case matchingCleanupProviders suppliedCustody of
    [(provider, component)] ->
      case makeContainerCleanupCustody provider component of
        Left problem -> pure (Left problem)
        Right currentCustody
          | currentCustody /= suppliedCustody -> pure . Left $ cleanupAuthorityChanged suppliedCustody
          | otherwise ->
              invokePackSourceCleanupContainerInspectHttp
                runner
                (providerImportBroker provider)
                component
                (providerImportConfiguration provider)
                externalIdentity
    [] -> pure . Left $ cleanupAuthorityChanged suppliedCustody
    _ -> pure . Left $ sourceProblem CorruptData "Several current provider bindings claim one cleanup authority."
  cleanupContainer suppliedCustody target = case matchingCleanupProviders suppliedCustody of
    [(provider, component)] ->
      case makeContainerCleanupCustody provider component of
        Left problem -> pure (Left problem)
        Right currentCustody
          | currentCustody /= suppliedCustody -> pure . Left $ cleanupAuthorityChanged suppliedCustody
          | otherwise ->
              invokePackSourceCleanupContainerHttp
                runner
                (providerImportBroker provider)
                component
                (providerImportConfiguration provider)
                (cleanupContainerExternalIdentity target)
    [] -> pure . Left $ cleanupAuthorityChanged suppliedCustody
    _ -> pure . Left $ sourceProblem CorruptData "Several current provider bindings claim one cleanup authority."
  verifyCleanupContainer suppliedCustody target = case matchingCleanupProviders suppliedCustody of
    [(provider, component)] ->
      case makeContainerCleanupCustody provider component of
        Left problem -> pure (Left problem)
        Right currentCustody
          | currentCustody /= suppliedCustody -> pure . Left $ cleanupAuthorityChanged suppliedCustody
          | otherwise ->
              invokePackSourceCleanupContainerVerifyHttp
                runner
                (providerImportBroker provider)
                component
                (providerImportConfiguration provider)
                (cleanupContainerExternalIdentity target)
    [] -> pure . Left $ cleanupAuthorityChanged suppliedCustody
    _ -> pure . Left $ sourceProblem CorruptData "Several current provider bindings claim one cleanup authority."
  readFileWith source mode continue = do
    case fileDescriptorFor source of
      Left problem -> pure (Left problem)
      Right descriptor
        | mode `notElem` importSourceModes descriptor -> pure . Left $ unsupportedMode descriptor mode
        | otherwise -> do
            selected <- readFileInput descriptor source
            case selected of
              Left problem -> pure (Left problem)
              Right input ->
                case lookupPackComponent (importSourceId descriptor) registry of
                  Left problem -> pure (Left problem)
                  Right component -> continue descriptor component input
  fileDescriptorFor source =
    let normalized = Text.toLower (Text.strip source)
        ranked =
          [ (descriptor, maximum matchingLengths)
          | descriptor <- fileDescriptors
          , let matchingLengths = [Text.length suffix | suffix <- importSourceExtensions descriptor, suffix `Text.isSuffixOf` normalized]
          , not (null matchingLengths)
          ]
        bestLength = maximum (0 : fmap snd ranked)
        matches = [descriptor | (descriptor, length_) <- ranked, length_ == bestLength]
     in case matches of
          [descriptor] -> Right descriptor
          _ ->
            Left $
              (sourceProblem Unsupported "No enabled file SourceAdapter unambiguously accepts this source path.")
                { appErrorSubject = Just (Text.strip source)
                , appErrorDetails =
                    [ "Configured provider references: " <> Text.intercalate ", " (providerImportReference <$> providers)
                    , "Recognized file extensions: " <> Text.intercalate ", " (concatMap importSourceExtensions fileDescriptors)
                    ]
                , appErrorRecovery = [RecoveryAction "choose-source" "Choose a source whose format identifies one enabled SourceAdapter." Nothing]
                }
  providersFor source = filter (matchesProviderReference (Text.strip source)) providers
  uniqueProvider source = case providersFor source of
    [provider] -> Right provider
    [] ->
      Left
        ( (sourceProblem Unsupported "No configured provider account owns this cleanup source.")
            { appErrorSubject = Just (Text.strip source)
            }
        )
    _ -> Left (ambiguousProviderReference source)
  matchingCleanupProviders custody =
    [ (provider, component)
    | provider <- providers
    , providerImportCanonicalReference provider == effectAdapterProviderAccount custody
    , Right component <- [lookupPackComponent (providerImportAdapterId provider) registry]
    ]
  matchesProviderReference source provider =
    source == providerImportReference provider || source == providerImportCanonicalReference provider
  providerDescriptors =
    [ ImportSourceDescriptor
        (providerImportReference provider)
        (providerImportInputLabel provider)
        []
        (providerImportModes provider)
    | provider <- providers
    ]
  fileDescriptors =
    [ ImportSourceDescriptor "plain_text" "Plain text file" [".txt", ".text"] [SourceSnapshot, SourceMigrate]
    , ImportSourceDescriptor "document_file" "Markdown, HTML, JSON, CSV, or Org file" [".markdown", ".html", ".json", ".csv", ".org", ".md", ".htm"] [SourceSnapshot, SourceMigrate]
    , ImportSourceDescriptor "evernote_enex" "Evernote ENEX export" [".enex"] [SourceSnapshot, SourceMigrate]
    , ImportSourceDescriptor "notesnook_export" "Notesnook export" [".zip"] [SourceSnapshot, SourceMigrate]
    , ImportSourceDescriptor "taskjuggler_actuals" "TaskJuggler actuals" [".tjp"] [SourceSnapshot]
    ]

makeCleanupCustody :: ProviderImportSource -> RegisteredPackComponent -> Either AppError EffectAdapterCustody
makeCleanupCustody = makeCleanupCustodyFor SourceCleanupItemPermission "item"

makeContainerCleanupCustody :: ProviderImportSource -> RegisteredPackComponent -> Either AppError EffectAdapterCustody
makeContainerCleanupCustody = makeCleanupCustodyFor SourceCleanupContainerPermission "container"

makeCleanupCustodyFor :: EffectPermission -> Text -> ProviderImportSource -> RegisteredPackComponent -> Either AppError EffectAdapterCustody
makeCleanupCustodyFor requiredPermission label provider registered = case registeredComponent registered of
  ExecutableComponent common _ permissions -> do
    unless (requiredPermission `elem` permissionEffectPurposes permissions) $
      Left (sourceProblem Unsupported ("The selected SourceAdapter does not declare " <> label <> " cleanup."))
    let identity = registeredPackIdentity registered
    pure
      EffectAdapterCustody
        { effectAdapterComponentId = componentId common
        , effectAdapterContractMajor = componentContractMajor common
        , effectAdapterProviderAccount = providerImportCanonicalReference provider
        , effectAdapterCredentialBinding = providerImportCredentialBindingReference provider
        , effectAdapterPackPublisher = artifactPublisher identity
        , effectAdapterPackName = artifactName identity
        , effectAdapterPackVersion = artifactVersion identity
        , effectAdapterPackManifestDigest = artifactManifestDigest identity
        , effectAdapterPackArchiveDigest = artifactArchiveDigest identity
        , effectAdapterSignerFingerprint = registeredSignerFingerprint registered
        }
  _ -> Left (sourceProblem Unsupported "A declarative Pack component cannot clean up a source.")

cleanupAuthorityChanged :: EffectAdapterCustody -> AppError
cleanupAuthorityChanged custody =
  (sourceProblem Conflict "The provider cleanup authority changed after approval; nothing was dispatched.")
    { appErrorSubject = Just (effectAdapterProviderAccount custody)
    , appErrorRetrySafety = DoNotRetry
    , appErrorRecovery = [RecoveryAction "review-again" "Create and approve a new effect revision against the current Pack and credential binding." Nothing]
    }

validateProviderMode :: ProviderImportSource -> SourceMode -> Either AppError ()
validateProviderMode provider mode =
  if mode `elem` providerImportModes provider
    then Right ()
    else Left (unsupportedMode descriptor mode)
 where
  descriptor = ImportSourceDescriptor (providerImportAdapterId provider) (providerImportDisplayName provider) [] (providerImportModes provider)

unsupportedMode :: ImportSourceDescriptor -> SourceMode -> AppError
unsupportedMode descriptor mode =
  (sourceProblem Unsupported "The selected SourceAdapter does not support this import mode.")
    { appErrorSubject = Just (importSourceId descriptor)
    , appErrorDetails = ["Requested: " <> sourceModeLabel mode, "Supported: " <> Text.intercalate ", " (sourceModeLabel <$> importSourceModes descriptor)]
    }

sourceModeLabel :: SourceMode -> Text
sourceModeLabel = \case
  SourceSnapshot -> "snapshot"
  SourceSynchronize -> "synchronize"
  SourceMigrate -> "migrate"

ambiguousProviderReference :: Text -> AppError
ambiguousProviderReference source =
  (sourceProblem AmbiguousReference "More than one configured provider account owns this import reference.")
    { appErrorSubject = Just (Text.strip source)
    , appErrorRecovery = [RecoveryAction "choose-account" "Choose one exact provider account reference." Nothing]
    }

readFileInput :: ImportSourceDescriptor -> Text -> IO (Either AppError SourceInput)
readFileInput descriptor source
  | Text.null stripped = pure . Left $ sourceProblem InvalidInput "A file import needs a nonempty source path."
  | not (any (`Text.isSuffixOf` Text.toLower stripped) (importSourceExtensions descriptor)) = pure . Left $ sourceProblem Unsupported "The selected SourceAdapter does not accept this file suffix."
  | otherwise = do
      inspected <- try (getSymbolicLinkStatus path)
      case inspected of
        Left problem -> pure (Left (readProblem source problem))
        Right status
          | isSymbolicLink status -> pure . Left $ sourceProblem PreconditionFailed "A file import source cannot be a symbolic link."
          | not (isRegularFile status) -> pure . Left $ sourceProblem PreconditionFailed "A file import source must be one regular file."
          | fileSize status > maximumInputBytes ->
              pure . Left $
                (sourceProblem PreconditionFailed "The selected file exceeds the bounded import-input limit.")
                  { appErrorDetails = ["Maximum bytes: " <> Text.pack (show maximumInputBytes)]
                  }
          | otherwise -> do
              loaded <- readOpenedRegularFile source path
              pure $ SourceInput (Text.pack (takeFileName path)) (mediaTypeFor descriptor stripped) <$> loaded
 where
  stripped = Text.strip source
  path = Text.unpack stripped

mediaTypeFor :: ImportSourceDescriptor -> Text -> Text
mediaTypeFor descriptor source = case importSourceId descriptor of
  "taskjuggler_actuals" -> "text/x-taskjuggler; charset=utf-8"
  "notesnook_export" -> "application/zip"
  "evernote_enex" -> "application/vnd.evernote.enex+xml"
  "document_file"
    | ".markdown" `Text.isSuffixOf` lower || ".md" `Text.isSuffixOf` lower -> "text/markdown; charset=utf-8"
    | ".html" `Text.isSuffixOf` lower || ".htm" `Text.isSuffixOf` lower -> "text/html; charset=utf-8"
    | ".json" `Text.isSuffixOf` lower -> "application/json"
    | ".csv" `Text.isSuffixOf` lower -> "text/csv; charset=utf-8"
    | ".org" `Text.isSuffixOf` lower -> "text/org; charset=utf-8"
    | otherwise -> "application/octet-stream"
  _ -> "text/plain; charset=utf-8"
 where
  lower = Text.toLower source

verifyCoreCustody :: ImportSourceDescriptor -> SourceInput -> SourcePreflight -> Either AppError ()
verifyCoreCustody descriptor input preflight
  | importSourceId descriptor /= "taskjuggler_actuals" = Right ()
  | otherwise = do
      actuals <- parseTaskJugglerActuals (sourceInputBytes input)
      let identity = observedIdentity (sourcePreflightObservation preflight)
          expected =
            Map.fromList
              [ ("planning_manifest_sha256", actualsManifestDigest actuals)
              , ("actuals_as_of", Text.pack (formatTime defaultTimeLocale "%Y-%m-%d-%H:%MZ" (actualsAsOf actuals)))
              , ("actual_record_count", Text.pack (show (length (actualsRecords actuals))))
              ]
      if expected == identity
        then Right ()
        else
          Left
            ( (sourceProblem CorruptData "The TaskJuggler SourceAdapter observation disagrees with the core custody parser.")
                { appErrorDetails = ["Expected: " <> Text.pack (show expected), "Observed: " <> Text.pack (show identity)]
                }
            )

normalizedReference :: Text -> Text
normalizedReference = Text.pack . normalise . Text.unpack . Text.strip

maximumInputBytes :: FileOffset
maximumInputBytes = 64 * 1024 * 1024

readOpenedRegularFile :: Text -> FilePath -> IO (Either AppError ByteString.ByteString)
readOpenedRegularFile source path =
  try (openFd path ReadOnly defaultFileFlags{nofollow = True, cloexec = True}) >>= \case
    Left problem -> pure (Left (readProblem source problem))
    Right descriptor ->
      try (getFdStatus descriptor) >>= \case
        Left problem -> closeQuietly descriptor >> pure (Left (readProblem source problem))
        Right status
          | not (isRegularFile status) -> closeQuietly descriptor >> pure (Left (sourceProblem PreconditionFailed "A file import source must remain one regular file while it is opened."))
          | fileSize status > maximumInputBytes -> closeQuietly descriptor >> pure (Left tooLarge)
          | otherwise ->
              try (fdToHandle descriptor) >>= \case
                Left problem -> closeQuietly descriptor >> pure (Left (readProblem source problem))
                Right handle -> do
                  loaded <- try (ByteString.hGetContents handle `finally` hClose handle)
                  pure $ case loaded of
                    Left problem -> Left (readProblem source problem)
                    Right bytes
                      | fromIntegral (ByteString.length bytes) > maximumInputBytes -> Left tooLarge
                      | otherwise -> Right bytes
 where
  tooLarge =
    (sourceProblem PreconditionFailed "The selected file exceeds the bounded import-input limit.")
      { appErrorDetails = ["Maximum bytes: " <> Text.pack (show maximumInputBytes)]
      }
  closeQuietly descriptor = void (try (closeFd descriptor) :: IO (Either IOException ()))

readProblem :: Text -> IOException -> AppError
readProblem source problem =
  (sourceProblem NotFound "The selected import source could not be read.")
    { appErrorSubject = Just (Text.strip source)
    , appErrorDetails = [Text.pack (displayException problem)]
    }

sourceProblem :: ErrorCode -> Text -> AppError
sourceProblem code message =
  (appError code message)
    { appErrorRecovery = [RecoveryAction "choose-source" "Choose one readable regular source file and try again." Nothing]
    }

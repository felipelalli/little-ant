module LittleAnt.Export (
  ExportArtifact (..),
  ExportDescriptor (..),
  ExportHostResult (..),
  ExportPort (..),
  ExportProjection (..),
  ExportScope (..),
  buildStructuralProjection,
  emptyExportPort,
  packRegistryExportPort,
  runExportHost,
)
where

import Control.Exception (IOException, bracketOnError, catch, try)
import Data.Aeson
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (isUpper, toLower, toUpper)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import LittleAnt.Catalog (natureIdentifier)
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Model
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Runner
import LittleAnt.Pack.Trust
import LittleAnt.Planning
import LittleAnt.Store
import System.Directory hiding (isSymbolicLink)
import System.FilePath (isAbsolute, normalise, takeDirectory, takeFileName)
import System.IO (hClose, hFlush, openBinaryTempFile)
import System.IO.Error (isAlreadyExistsError, isDoesNotExistError)
import System.Posix.Files (FileStatus, createLink, getSymbolicLinkStatus, isDirectory, isRegularFile, isSymbolicLink, setFileMode)
import System.Posix.IO (OpenMode (ReadOnly), closeFd, defaultFileFlags, openFd)
import System.Posix.Unistd (fileSynchronise)

data ExportDescriptor = ExportDescriptor
  { exportDescriptorId :: Text
  , exportDescriptorDisplayName :: Text
  , exportDescriptorFormat :: Text
  , exportDescriptorProjection :: Text
  }
  deriving stock (Eq, Show)

data ExportScope
  = ExportWholeDataset
  | ExportBrickSubtree UUIDv7
  | ExportDomain UUIDv7
  deriving stock (Eq, Show)

data ExportProjection = ExportProjection
  { exportProjectionSchema :: Text
  , exportProjectionCursor :: DatasetCursor
  , exportProjectionScope :: ExportScope
  , exportProjectionPayload :: Value
  }
  deriving stock (Eq, Show)

data ExportArtifact = ExportArtifact
  { exportArtifactBytes :: ByteString
  , exportArtifactMediaType :: Text
  , exportArtifactSuggestedFilename :: FilePath
  , exportArtifactWarnings :: [Text]
  , exportArtifactMetadata :: Map Text Text
  }
  deriving stock (Eq, Show)

data ExportPort = ExportPort
  { exportPortCatalog :: [ExportDescriptor]
  , exportPortPrepare :: ExportDescriptor -> UTCTime -> DatasetCursor -> State -> ExportScope -> Either AppError ExportProjection
  , exportPortInvoke :: ExportDescriptor -> ExportProjection -> IO (Either AppError ExportArtifact)
  }

data ExportHostResult = ExportHostResult
  { exportHostDescriptor :: ExportDescriptor
  , exportHostScopeLabel :: Text
  , exportHostArtifact :: ExportArtifact
  , exportHostDestination :: Maybe FilePath
  , exportHostDigest :: Text
  , exportHostWroteFile :: Bool
  }
  deriving stock (Eq, Show)

instance ToJSON ExportDescriptor where
  toJSON descriptor =
    object
      [ "id" .= exportDescriptorId descriptor
      , "display_name" .= exportDescriptorDisplayName descriptor
      , "format" .= exportDescriptorFormat descriptor
      , "projection" .= exportDescriptorProjection descriptor
      ]

instance ToJSON ExportScope where
  toJSON = \case
    ExportWholeDataset -> object ["kind" .= ("all" :: Text)]
    ExportBrickSubtree identity -> object ["kind" .= ("brick" :: Text), "brick_id" .= renderUUIDv7 identity]
    ExportDomain identity -> object ["kind" .= ("domain" :: Text), "domain_id" .= renderUUIDv7 identity]

instance ToJSON ExportProjection where
  toJSON projection =
    object
      [ "schema" .= exportProjectionSchema projection
      , "dataset_cursor" .= renderCursor (exportProjectionCursor projection)
      , "scope" .= exportProjectionScope projection
      , "payload" .= exportProjectionPayload projection
      ]

emptyExportPort :: ExportPort
emptyExportPort =
  ExportPort
    []
    (\descriptor _ _ _ _ -> Left (missingPortExporter descriptor))
    (\descriptor _ -> pure (Left (missingPortExporter descriptor)))
 where
  missingPortExporter descriptor =
    (appError NotFound "The requested exporter is not installed.")
      { appErrorSubject = Just (exportDescriptorId descriptor)
      , appErrorRecovery = [RecoveryAction "packs" "Inspect installed exporter components." (Just "lant packs list")]
      }

packRegistryExportPort :: PackRunnerClient -> PackRegistry -> ExportPort
packRegistryExportPort client registry = ExportPort descriptors prepare invoke
 where
  descriptors = mapMaybeExporterDescriptor (componentsOfKind ReadOnlyExporterComponent registry)
  prepare descriptor plannedAt cursor state scope = do
    registered <- lookupPackComponent (exportDescriptorId descriptor) registry
    case exportDescriptorProjection descriptor of
      projection
        | projection == structuralProjectionSchema -> Right (buildStructuralProjection cursor state scope)
        | projection == taskJugglerProjectionSchema -> do
            identity <- planningIdentity registered
            payload <- buildTaskJugglerPayload identity plannedAt cursor state (toJSON scope) (orderedSelectedBricks state scope)
            Right (ExportProjection taskJugglerProjectionSchema cursor scope payload)
        | otherwise -> Left (unsupportedProjection descriptor)
  invoke descriptor projection = case lookupPackComponent (exportDescriptorId descriptor) registry of
    Left problem -> pure (Left problem)
    Right registered ->
      invokePackExporter client registered (toJSON projection) >>= \case
        Left problem -> pure (Left problem)
        Right artifact ->
          pure . Right $
            ExportArtifact
              { exportArtifactBytes = runnerArtifactBytes artifact
              , exportArtifactMediaType = runnerArtifactMediaType artifact
              , exportArtifactSuggestedFilename = runnerArtifactSuggestedFilename artifact
              , exportArtifactWarnings = runnerArtifactWarnings artifact
              , exportArtifactMetadata = runnerArtifactMetadata artifact
              }

planningIdentity :: RegisteredPackComponent -> Either AppError PlanningExporterIdentity
planningIdentity registered = case registeredComponent registered of
  ExecutableComponent common entryPoint _ -> do
    entrypointBytes <-
      maybe
        ( Left
            ( (appError CorruptData "The planning exporter entry point is absent from its authorized payload.")
                { appErrorSubject = Just (componentId common)
                }
            )
        )
        Right
        (Map.lookup entryPoint (registeredComponentPayload registered))
    let identity = registeredPackIdentity registered
    Right
      PlanningExporterIdentity
        { planningPublisher = artifactPublisher identity
        , planningPackName = artifactName identity
        , planningPackVersion = artifactVersion identity
        , planningManifestDigest = artifactManifestDigest identity
        , planningArchiveDigest = artifactArchiveDigest identity
        , planningComponentId = componentId common
        , planningEntrypointDigest = sha256Hex entrypointBytes
        , planningSignerFingerprint = registeredSignerFingerprint registered
        }
  _ -> Left (appError CorruptData "The planning exporter is not an executable Pack component.")

mapMaybeExporterDescriptor :: [RegisteredPackComponent] -> [ExportDescriptor]
mapMaybeExporterDescriptor = mapMaybe exporterDescriptor

exporterDescriptor :: RegisteredPackComponent -> Maybe ExportDescriptor
exporterDescriptor registered = case registeredComponent registered of
  ExecutableComponent common _ permissions
    | componentKind common == ReadOnlyExporterComponent
    , projections@(projection : rest) <- permissionProjections permissions ->
        let selectedProjection =
              if structuralProjectionSchema `elem` projections
                then structuralProjectionSchema
                else foldl min projection rest
         in Just
              ExportDescriptor
                { exportDescriptorId = componentId common
                , exportDescriptorDisplayName = humanizeComponentId (componentId common)
                , exportDescriptorFormat = componentId common
                , exportDescriptorProjection = selectedProjection
                }
  _ -> Nothing

humanizeComponentId :: Text -> Text
humanizeComponentId "taskjuggler" = "TaskJuggler"
humanizeComponentId identifier =
  Text.unwords (capitalize <$> Text.words (Text.map separator identifier))
 where
  separator character
    | character `elem` ("._-" :: String) = ' '
    | otherwise = character
  capitalize value = case Text.uncons value of
    Nothing -> value
    Just (first, rest) -> Text.cons (toUpper first) rest

runExportHost :: ExportPort -> Bool -> UTCTime -> DatasetCursor -> State -> Text -> ExportScope -> Maybe FilePath -> IO (Either AppError ExportHostResult)
runExportHost port dryRun plannedAt cursor state requestedExporter scope outputPath =
  case filter ((== requestedExporter) . exportDescriptorId) (exportPortCatalog port) of
    [] -> pure (Left missingExporter)
    [descriptor] -> do
      preparedDestination <- traverse preflightDestination outputPath
      case sequence preparedDestination of
        Left problem -> pure (Left problem)
        Right destination -> case exportPortPrepare port descriptor plannedAt cursor state scope of
          Left problem -> pure (Left problem)
          Right projection -> do
            invoked <- try (exportPortInvoke port descriptor projection)
            case invoked of
              Left problem -> pure (Left (exporterException problem))
              Right (Left problem) -> pure (Left problem)
              Right (Right artifact) ->
                case validateArtifact artifact of
                  Left problem -> pure (Left problem)
                  Right () -> finish descriptor destination artifact
    _ -> pure (Left duplicateExporter)
 where
  missingExporter =
    (appError NotFound "The requested exporter is not installed.")
      { appErrorSubject = Just requestedExporter
      , appErrorRecovery = [RecoveryAction "packs" "Inspect installed exporter components." (Just "lant packs list")]
      }
  duplicateExporter =
    (appError Conflict "More than one installed exporter has the same canonical identifier.")
      { appErrorSubject = Just requestedExporter
      , appErrorRecovery = [RecoveryAction "packs" "Inspect Pack pins before exporting." (Just "lant packs list")]
      }
  finish descriptor destination artifact = do
    let digest = sha256Hex (exportArtifactBytes artifact)
        result =
          ExportHostResult
            descriptor
            (scopeLabel state scope)
            artifact
            (destinationPath <$> destination)
            digest
    if dryRun
      then pure (Right (result False))
      else case destination of
        Nothing -> pure (Right (result False))
        Just prepared ->
          commitExportBytes prepared (exportArtifactBytes artifact) >>= \case
            Left problem -> pure (Left problem)
            Right () -> pure (Right (result True))

structuralProjectionSchema :: Text
structuralProjectionSchema = "little-ant/structure@1"

buildStructuralProjection :: DatasetCursor -> State -> ExportScope -> ExportProjection
buildStructuralProjection cursor state scope =
  ExportProjection
    structuralProjectionSchema
    cursor
    scope
    ( object
        [ "bricks" .= fmap brickValue selectedBricks
        , "domains" .= fmap domainValue selectedDomains
        ]
    )
 where
  selectedIds = Set.fromList (brickId <$> selectBricks state scope)
  selectedBricks = orderedBricks state selectedIds
  selectedDomainIds = Set.unions (fmap brickDomains selectedBricks) <> scopeDomainIds state scope
  selectedDomains = filter ((`Set.member` selectedDomainIds) . domainId) (Map.elems (stateDomains state))
  brickValue brick =
    object $
      [ "id" .= renderUUIDv7 (brickId brick)
      , "handle" .= renderHandle BrickHandle (brickHandle brick)
      , "title" .= brickTitle brick
      , "nature" .= natureIdentifier (brickNature brick)
      , "nature_version" .= brickNatureVersion brick
      , "domain_ids" .= fmap renderUUIDv7 (Set.toAscList (brickDomains brick))
      , "sibling_position" .= brickSiblingPosition brick
      , "status" .= brickStatusText (brickStatus brick)
      , "work_state" .= workStateText (brickWorkState brick)
      ]
        <> maybe [] (pure . ("parent_id" .=) . renderUUIDv7) (brickParent brick)
        <> maybe [] (pure . ("template" .=) . templateIdentifier) (brickTemplate brick)
        <> maybe [] (pure . ("phase" .=) . phaseText . phaseClaimValue) (Map.lookup (brickId brick) (statePhaseClaims state))
        <> maybe [] (pure . ("effort" .=) . effortText . effortClaimClass) (Map.lookup (brickId brick) (stateEffortClaims state))
        <> maybe [] (pure . ("impact" .=) . impactValue) (Map.lookup (brickId brick) (stateImpactClaims state))
  domainValue domain =
    object $
      [ "id" .= renderUUIDv7 (domainId domain)
      , "name" .= domainName domain
      , "path" .= domainPath state (domainId domain)
      ]
        <> maybe [] (pure . ("parent_id" .=) . renderUUIDv7) (domainParent domain)
  impactValue claim = object ["class" .= impactText (impactClaimClass claim), "maturity" .= maturityText (impactClaimMaturity claim)]

selectBricks :: State -> ExportScope -> [Brick]
selectBricks state = \case
  ExportWholeDataset -> activeBricks state
  ExportBrickSubtree root -> filter (belongsToSubtree root) (activeBricks state)
  ExportDomain root ->
    let domains = domainDescendants state root
     in filter (not . Set.null . Set.intersection domains . brickDomains) (activeBricks state)
 where
  belongsToSubtree root brick
    | brickId brick == root = True
    | otherwise = maybe False (belongsToSubtree root) (brickParent brick >>= (`Map.lookup` stateBricks state))

orderedSelectedBricks :: State -> ExportScope -> [Brick]
orderedSelectedBricks state scope =
  let selectedIds = Set.fromList (brickId <$> selectBricks state scope)
   in orderedBricks state selectedIds

orderedBricks :: State -> Set.Set UUIDv7 -> [Brick]
orderedBricks state included = concatMap visit roots
 where
  selected = filter ((`Set.member` included) . brickId) (activeBricks state)
  roots = ordered [brick | brick <- selected, maybe True (`Set.notMember` included) (brickParent brick)]
  ordered = Map.elems . Map.fromList . fmap (\brick -> ((brickSiblingPosition brick, brickId brick), brick))
  visit brick = brick : concatMap visit (ordered [child | child <- selected, brickParent child == Just (brickId brick)])

scopeDomainIds :: State -> ExportScope -> Set.Set UUIDv7
scopeDomainIds state = \case
  ExportDomain root -> domainDescendants state root
  _ -> Set.empty

domainDescendants :: State -> UUIDv7 -> Set.Set UUIDv7
domainDescendants state root = Set.fromList [domainId domain | domain <- Map.elems (stateDomains state), descendsFrom (domainId domain)]
 where
  descendsFrom identity
    | identity == root = True
    | otherwise = maybe False descendsFrom (Map.lookup identity (stateDomains state) >>= domainParent)

scopeLabel :: State -> ExportScope -> Text
scopeLabel state = \case
  ExportWholeDataset -> "all"
  ExportBrickSubtree identity -> maybe ("brick:" <> renderUUIDv7 identity) (renderHandle BrickHandle . brickHandle) (Map.lookup identity (stateBricks state))
  ExportDomain identity -> maybe ("domain:" <> renderUUIDv7 identity) (domainPath state . domainId) (Map.lookup identity (stateDomains state))

domainPath :: State -> UUIDv7 -> Text
domainPath state identity = case Map.lookup identity (stateDomains state) of
  Nothing -> "<missing Domain>"
  Just domain -> maybe "" (\parent -> domainPath state parent <> " › ") (domainParent domain) <> domainName domain

data PreparedDestination = PreparedDestination
  { destinationPath :: FilePath
  , destinationParent :: FilePath
  }

preflightDestination :: FilePath -> IO (Either AppError PreparedDestination)
preflightDestination requested = handleDestinationIO requested $ do
  absolute <- normalise <$> makeAbsolute requested
  let parent = takeDirectory absolute
      name = takeFileName absolute
  if null name || name == "." || name == ".." || isAbsolute name
    then pure (Left (invalidDestination requested "The output filename is invalid."))
    else do
      parentExists <- doesPathExist parent
      if not parentExists
        then pure (Left (invalidDestination requested "The output parent does not exist."))
        else do
          parentStatus <- getSymbolicLinkStatus parent
          canonicalParent <- normalise <$> canonicalizePath parent
          if isSymbolicLink parentStatus || not (isDirectory parentStatus) || canonicalParent /= parent
            then pure (Left (invalidDestination requested "The output parent must be one real directory path without symlinks."))
            else
              pathStatus absolute >>= \case
                Just status
                  | isSymbolicLink status -> pure (Left (invalidDestination requested "The output path is a symlink."))
                  | isRegularFile status -> pure (Left (invalidDestination requested "The output file already exists."))
                  | otherwise -> pure (Left (invalidDestination requested "The output path already exists and is not a regular file."))
                Nothing -> pure (Right (PreparedDestination absolute parent))

commitExportBytes :: PreparedDestination -> ByteString -> IO (Either AppError ())
commitExportBytes destination bytes =
  catch
    ( Right
        <$> bracketOnError
          (openBinaryTempFile (destinationParent destination) ".lant-export-")
          cleanupTemporary
          writeAndPublish
    )
    handleFailure
 where
  cleanupTemporary (temporary, handle) = do
    ignoreIO (hClose handle)
    ignoreIO (removeFile temporary)
  writeAndPublish (temporary, handle) = do
    ByteString.hPut handle bytes
    hFlush handle
    hClose handle
    setFileMode temporary 0o600
    syncFile temporary
    createLink temporary (destinationPath destination)
    syncDirectory (destinationParent destination)
    removeFile temporary
    syncDirectory (destinationParent destination)
  handleFailure problem
    | isAlreadyExistsError problem = pure (Left (invalidDestination (destinationPath destination) "The output path appeared before publication; nothing was overwritten."))
    | otherwise =
        pure . Left $
          (appError ExternalFailure "Little Ant could not publish the export safely.")
            { appErrorSubject = Just (Text.pack (destinationPath destination))
            , appErrorDetails = [Text.pack (show (problem :: IOException))]
            , appErrorRecovery = [RecoveryAction "change-file" "Choose another new output file and retry." Nothing]
            }

validateArtifact :: ExportArtifact -> Either AppError ()
validateArtifact artifact
  | Text.null (Text.strip (exportArtifactMediaType artifact)) = Left invalid
  | null filename || filename /= takeFileName filename || filename == "." || filename == ".." = Left invalid
  | otherwise = Right ()
 where
  filename = exportArtifactSuggestedFilename artifact
  invalid =
    (appError ExternalFailure "The exporter returned invalid output metadata.")
      { appErrorDetails = ["media type and suggested filename must be nonempty; filename must be one basename"]
      , appErrorRecovery = [RecoveryAction "packs" "Inspect or replace the exporter component." (Just "lant packs list")]
      }

invalidDestination :: FilePath -> Text -> AppError
invalidDestination path message =
  (appError PreconditionFailed message)
    { appErrorSubject = Just (Text.pack path)
    , appErrorRecovery = [RecoveryAction "change-file" "Choose a new regular output file under an existing real directory." Nothing]
    }

exporterException :: IOException -> AppError
exporterException problem =
  (appError ExternalFailure "The exporter failed before returning a validated artifact.")
    { appErrorDetails = [Text.pack (show problem)]
    , appErrorRecovery = [RecoveryAction "packs" "Inspect the exporter and retry only after its failure is understood." (Just "lant packs list")]
    }

handleDestinationIO :: FilePath -> IO (Either AppError value) -> IO (Either AppError value)
handleDestinationIO path action = catch action $ \problem ->
  pure . Left $
    (appError ExternalFailure "Little Ant could not inspect the requested export destination safely.")
      { appErrorSubject = Just (Text.pack path)
      , appErrorDetails = [Text.pack (show (problem :: IOException))]
      , appErrorRecovery = [RecoveryAction "change-file" "Choose a path under an accessible existing directory." Nothing]
      }

pathStatus :: FilePath -> IO (Maybe FileStatus)
pathStatus path = catch (Just <$> getSymbolicLinkStatus path) $ \problem ->
  if isDoesNotExistError problem then pure Nothing else ioError problem

syncFile :: FilePath -> IO ()
syncFile path = do
  descriptor <- openFd path ReadOnly defaultFileFlags
  fileSynchronise descriptor
  closeFd descriptor

syncDirectory :: FilePath -> IO ()
syncDirectory = syncFile

ignoreIO :: IO () -> IO ()
ignoreIO action = catch action (const (pure ()) :: IOException -> IO ())

brickStatusText :: BrickStatus -> Text
brickStatusText = Text.toLower . Text.pack . drop 5 . show

workStateText :: WorkState -> Text
workStateText = Text.toLower . Text.pack . show

phaseText :: WorkPhase -> Text
phaseText = Text.toLower . Text.pack . dropEnd "Phase" . show

effortText :: EffortClass -> Text
effortText = snakeCase . dropEnd "Effort" . show

impactText :: ImpactClass -> Text
impactText = snakeCase . dropEnd "Impact" . show

maturityText :: ImpactMaturity -> Text
maturityText = snakeCase . dropEnd "Impact" . show

dropEnd :: String -> String -> String
dropEnd suffix value = reverse (drop (length suffix) (reverse value))

snakeCase :: String -> Text
snakeCase = Text.pack . go True
 where
  go _ [] = []
  go first (character : rest)
    | isUpper character = (if first then [] else "_") <> [toLower character] <> go False rest
    | otherwise = character : go False rest

unsupportedProjection :: ExportDescriptor -> AppError
unsupportedProjection descriptor =
  (appError Unsupported "The exporter requires an unsupported projection contract.")
    { appErrorSubject = Just (exportDescriptorId descriptor)
    , appErrorDetails = ["required: " <> exportDescriptorProjection descriptor, "available: " <> Text.intercalate ", " [structuralProjectionSchema, taskJugglerProjectionSchema]]
    }

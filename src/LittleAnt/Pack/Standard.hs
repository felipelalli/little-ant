module LittleAnt.Pack.Standard (
  standardPackIdentity,
  standardPackComponentIds,
  loadStandardPackAuthorization,
  loadStandardPackRegistry,
)
where

import Control.Exception (IOException, try)
import Control.Monad (filterM, unless)
import Data.ByteString qualified as ByteString
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Pack.Format
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Trust
import Paths_little_ant (getDataFileName)
import System.Directory (doesFileExist)
import System.Environment (getExecutablePath)
import System.FilePath (normalise, takeDirectory, (</>))

standardPackIdentity :: PackArtifactIdentity
standardPackIdentity =
  PackArtifactIdentity
    { artifactPublisher = "org.littleant.project"
    , artifactName = "org.littleant.standard"
    , artifactVersion = "1.0.0"
    , artifactManifestDigest = "6f7038ba8a9efe7846923271f11afd2034e4b936f3b333d7de902f8ba88e3b8a"
    , artifactArchiveDigest = "eee9c120e860af20a00b0157f7d09f0d563c9821558585ad69155bd8ac809d99"
    }

standardPackComponentIds :: Set Text
standardPackComponentIds =
  Set.fromList
    [ "csv"
    , "document_file"
    , "evernote_enex"
    , "html"
    , "notesnook_export"
    , "org"
    , "plain_text"
    , "table"
    , "taskjuggler"
    , "taskjuggler_actuals"
    , "tree"
    ]

loadStandardPackRegistry :: UTCTime -> ProfileScope -> IO (Either AppError PackRegistry)
loadStandardPackRegistry now scope =
  loadStandardPackAuthorization now scope >>= pure . (>>= buildPackRegistry scope . pure)

loadStandardPackAuthorization :: UTCTime -> ProfileScope -> IO (Either AppError ExecutionAuthorizedPack)
loadStandardPackAuthorization now scope = do
  archivePath <- locateStandardPackArchive
  loaded <- try (ByteString.readFile archivePath)
  pure $ do
    archiveBytes <- either (Left . archiveReadProblem archivePath) Right (loaded :: Either IOException ByteString.ByteString)
    structural <- validatePackArchive archiveBytes
    authenticated <- authenticatePack structural
    unless
      (authenticatedPackIdentity authenticated == standardPackIdentity)
      ( Left
          ( (appError CorruptData "The bundled standard Pack does not match the identity compiled into Little Ant.")
              { appErrorDetails = [Text.pack archivePath, artifactArchiveDigest (authenticatedPackIdentity authenticated)]
              }
          )
      )
    let policy =
          PackTrustPolicy
            { trustSupportedLittleAntMajor = 1
            , trustBuiltInArtifacts = Set.singleton standardPackIdentity
            , trustOfficialCatalogSequence = Nothing
            , trustOfficialCatalogExpiresAt = Nothing
            , trustOfficialReleaseGrants = Set.empty
            , trustOfficialPinAuthorizations = Set.empty
            , trustCommunityPublishers = Set.empty
            , trustRevokedKeyFingerprints = Set.empty
            , trustRevokedArchiveDigests = Set.empty
            }
    install <- authorizePackInstall now scope policy standardPackComponentIds authenticated
    authorizePinnedPackExecution now scope policy (installAuthorizedPin install) authenticated

locateStandardPackArchive :: IO FilePath
locateStandardPackArchive = do
  installed <- getDataFileName relativeArchivePath
  executable <- getExecutablePath
  let development = fmap (</> relativeArchivePath) (take 16 (ancestors (takeDirectory executable)))
  existing <- filterM doesFileExist (installed : development)
  pure $ case existing of
    path : _ -> path
    [] -> installed
 where
  relativeArchivePath = "packs" </> "standard" </> "standard.lantpack"
  ancestors path =
    let parent = takeDirectory path
     in normalise path : if parent == path then [] else ancestors parent

archiveReadProblem :: FilePath -> IOException -> AppError
archiveReadProblem path problem =
  (appError CorruptData "The bundled standard Pack cannot be read.")
    { appErrorSubject = Just "org.littleant.standard"
    , appErrorDetails = [Text.pack path, Text.pack (show problem)]
    }

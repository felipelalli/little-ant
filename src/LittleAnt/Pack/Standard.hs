module LittleAnt.Pack.Standard (
  standardPackIdentity,
  standardPackComponentIds,
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
    , artifactManifestDigest = "12b8e83a57f3515cddcc8550a0fe433a2fdfa8bf9ef524494a6c57863e330d45"
    , artifactArchiveDigest = "8dc0442739899a792cfa26a58e1548c7429fa12f4226d5fe8929aa1c3269201d"
    }

standardPackComponentIds :: Set Text
standardPackComponentIds = Set.fromList ["csv", "html", "org", "table", "taskjuggler", "tree"]

loadStandardPackRegistry :: UTCTime -> ProfileScope -> IO (Either AppError PackRegistry)
loadStandardPackRegistry now scope = do
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
            , trustCommunityPublishers = Set.empty
            , trustRevokedKeyFingerprints = Set.empty
            , trustRevokedArchiveDigests = Set.empty
            }
    install <- authorizePackInstall now scope policy standardPackComponentIds authenticated
    execution <- authorizePinnedPackExecution now scope policy (installAuthorizedPin install) authenticated
    buildPackRegistry scope [execution]

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

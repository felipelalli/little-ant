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
    , artifactManifestDigest = "9cb38686872b0880f3f12f7e111a8c2c8c9d0e5ed7e57c0befe7d6cd22fdc761"
    , artifactArchiveDigest = "1c5881822b33b23b353731b9ac26b2c20b31e467091aac8acecb883d5b545380"
    }

standardPackComponentIds :: Set Text
standardPackComponentIds =
  Set.fromList
    [ "apple_reminders_export"
    , "csv"
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

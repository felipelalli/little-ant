module LittleAnt.Pack.Installed (
  OfficialCatalogAuthority (..),
  loadProfileAuthorizedPacks,
  loadProfilePackRegistry,
  loadProfileTrustPolicy,
)
where

import Control.Exception (IOException, try)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Pack.Catalog
import LittleAnt.Pack.Registry
import LittleAnt.Pack.Standard
import LittleAnt.Pack.Store
import LittleAnt.Pack.Trust
import LittleAnt.Profile
import System.Directory (doesPathExist)

data OfficialCatalogAuthority
  = OfficialCatalogUnavailable
  | OfficialCatalogCompiledRoot CatalogRoot

loadProfilePackRegistry :: UTCTime -> ProfileScope -> ProfilePaths -> IntegrationsConfig -> OfficialCatalogAuthority -> IO (Either AppError PackRegistry)
loadProfilePackRegistry now scope paths integrations authority = do
  loadProfileAuthorizedPacks now scope paths integrations authority
    >>= pure . (>>= buildPackRegistry scope)

loadProfileAuthorizedPacks :: UTCTime -> ProfileScope -> ProfilePaths -> IntegrationsConfig -> OfficialCatalogAuthority -> IO (Either AppError [ExecutionAuthorizedPack])
loadProfileAuthorizedPacks now scope paths integrations authority = do
  standard <- loadStandardPackAuthorization now scope
  policy <- loadProfileTrustPolicy now paths integrations authority
  case (standard, policy) of
    (Left problem, _) -> pure (Left problem)
    (_, Left problem) -> pure (Left problem)
    (Right builtIn, Right trusted) -> do
      configured <- loadConfiguredPacks now scope paths trusted (Map.toAscList (installedComponents integrations))
      pure ((builtIn :) <$> configured)

loadProfileTrustPolicy :: UTCTime -> ProfilePaths -> IntegrationsConfig -> OfficialCatalogAuthority -> IO (Either AppError PackTrustPolicy)
loadProfileTrustPolicy now paths integrations = \case
  OfficialCatalogCompiledRoot root ->
    readAcceptedCatalogState (CatalogStateConfig (officialCatalogStateFile paths)) root
      >>= pure
        . fmap
          ( catalogTrustPolicy
              now
              1
              (Set.singleton standardPackIdentity)
              (trustedPublishers integrations)
          )
  OfficialCatalogUnavailable -> do
    catalogState <- try (doesPathExist (officialCatalogStateFile paths)) :: IO (Either IOException Bool)
    pure $ do
      present <-
        either
          (\problem -> Left (catalogStateReadProblem paths problem))
          Right
          catalogState
      let officialPins =
            [ name
            | (name, pin) <- Map.toAscList (installedComponents integrations)
            , PinVerifiedOfficial _ <- [pinTrustOrigin pin]
            ]
      if present || not (null officialPins)
        then Left (officialAuthorityProblem paths officialPins present)
        else
          Right
            PackTrustPolicy
              { trustSupportedLittleAntMajor = 1
              , trustBuiltInArtifacts = Set.singleton standardPackIdentity
              , trustOfficialCatalogSequence = Nothing
              , trustOfficialCatalogExpiresAt = Nothing
              , trustOfficialReleaseGrants = Set.empty
              , trustOfficialPinAuthorizations = Set.empty
              , trustCommunityPublishers = trustedPublishers integrations
              , trustRevokedKeyFingerprints = Set.empty
              , trustRevokedArchiveDigests = Set.empty
              }

loadConfiguredPacks :: UTCTime -> ProfileScope -> ProfilePaths -> PackTrustPolicy -> [(Text, PackPin)] -> IO (Either AppError [ExecutionAuthorizedPack])
loadConfiguredPacks now scope paths policy = go []
 where
  store = PackStoreConfig (packStoreDirectory paths)
  go loaded [] = pure (Right (reverse loaded))
  go loaded ((_, pin) : remaining) =
    loadPinnedPack store now scope policy pin >>= \case
      Left problem -> pure (Left problem)
      Right authorized -> go (authorized : loaded) remaining

officialAuthorityProblem :: ProfilePaths -> [Text] -> Bool -> AppError
officialAuthorityProblem paths pins statePresent =
  (appError PermissionRequired "Official Pack trust is unavailable in this build; configured official authority cannot be verified.")
    { appErrorSubject = case pins of
        name : _ -> Just name
        [] -> Just "official Pack catalog"
    , appErrorDetails =
        ["catalog state: " <> (if statePresent then "present" else "absent")]
          <> ["official pin: " <> name | name <- pins]
          <> [Text.pack (officialCatalogStateFile paths)]
    , appErrorRecovery =
        [ RecoveryAction
            "catalog-root"
            "Use a Little Ant build that embeds the official catalog root; do not rewrite the pin as another trust class."
            Nothing
        ]
    }

catalogStateReadProblem :: ProfilePaths -> IOException -> AppError
catalogStateReadProblem paths problem =
  (appError CorruptData "The official Pack catalog state path could not be inspected safely.")
    { appErrorSubject = Just "official Pack catalog"
    , appErrorDetails = [Text.pack (officialCatalogStateFile paths), Text.pack (show problem)]
    , appErrorRecovery = [RecoveryAction "diagnose" "Inspect profile paths and permissions without discarding accepted catalog history." (Just "lant config paths")]
    }

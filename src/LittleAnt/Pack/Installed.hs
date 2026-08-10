module LittleAnt.Pack.Installed (
  OfficialCatalogAuthority (..),
  loadProfileAuthorizedPacks,
  loadProfilePackRegistry,
  loadProfileTrustPolicy,
)
where

import Control.Exception (IOException, try)
import Control.Monad (foldM)
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
  standard <- loadStandardPackAuthorization now scope
  policy <- loadProfileTrustPolicy now paths integrations authority
  case (standard, policy, retainedPackPins integrations) of
    (Left problem, _, _) -> pure (Left problem)
    (_, Left problem, _) -> pure (Left problem)
    (_, _, Left problem) -> pure (Left problem)
    (Right builtIn, Right trusted, Right retainedPins) -> do
      active <- loadConfiguredPacks now scope paths trusted (Map.toAscList (installedComponents integrations))
      let activeArtifacts = Set.fromList (standardPackIdentity : (pinArtifact <$> Map.elems (installedComponents integrations)))
          retained = filter ((`Set.notMember` activeArtifacts) . pinArtifact) retainedPins
      retainedAuthorized <- loadConfiguredPacks now scope paths trusted [(artifactArchiveDigest (pinArtifact pin), pin) | pin <- retained]
      pure $ do
        activeAuthorized <- active
        olderAuthorized <- retainedAuthorized
        buildPackRegistryWithRetained scope (builtIn : activeAuthorized) olderAuthorized

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
            | (name, pin) <- allConfiguredPins integrations
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

allConfiguredPins :: IntegrationsConfig -> [(Text, PackPin)]
allConfiguredPins integrations =
  Map.toAscList (installedComponents integrations)
    <> [ (accountName <> ":" <> artifactVersion (pinArtifact pin), pin)
       | (accountName, account) <- Map.toAscList (providerAccounts integrations)
       , let pin = providerAccountPackPin account
       ]

retainedPackPins :: IntegrationsConfig -> Either AppError [PackPin]
retainedPackPins integrations =
  Map.elems <$> foldM insertPin Map.empty (providerAccountPackPin <$> Map.elems (providerAccounts integrations))
 where
  insertPin pins candidate =
    let identity = pinArtifact candidate
     in case Map.lookup identity pins of
          Nothing -> Right (Map.insert identity candidate pins)
          Just existing
            | pinSignerFingerprint existing == pinSignerFingerprint candidate
                && pinTrustOrigin existing == pinTrustOrigin candidate ->
                Right
                  ( Map.insert
                      identity
                      existing{pinEnabledComponents = pinEnabledComponents existing `Set.union` pinEnabledComponents candidate}
                      pins
                  )
            | otherwise ->
                Left
                  ( (appError CorruptData "Configured bindings disagree about the trust identity of one exact Pack artifact.")
                      { appErrorSubject = Just (artifactName identity)
                      , appErrorDetails = [artifactVersion identity, artifactArchiveDigest identity]
                      }
                  )

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

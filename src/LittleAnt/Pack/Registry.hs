module LittleAnt.Pack.Registry (
  RegisteredPackComponent (..),
  PackRegistry,
  registryProfileScope,
  registryComponents,
  buildPackRegistry,
  buildPackRegistryWithRetained,
  lookupPackComponent,
  lookupPackComponentForArtifact,
  componentsOfKind,
)
where

import Control.Monad (foldM, unless)
import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Pack.Format
import LittleAnt.Pack.Trust

data RegisteredPackComponent = RegisteredPackComponent
  { registeredPackIdentity :: PackArtifactIdentity
  , registeredSignerFingerprint :: Text
  , registeredComponent :: PackComponent
  , registeredComponentPayload :: Map Text ByteString
  }
  deriving stock (Eq, Show)

data PackRegistry = PackRegistry
  { registryProfileScope :: ProfileScope
  , registryComponentMap :: Map Text RegisteredPackComponent
  , registryExactComponentMap :: Map (PackArtifactIdentity, Text) RegisteredPackComponent
  }
  deriving stock (Eq, Show)

registryComponents :: PackRegistry -> [RegisteredPackComponent]
registryComponents = Map.elems . registryComponentMap

buildPackRegistry :: ProfileScope -> [ExecutionAuthorizedPack] -> Either AppError PackRegistry
buildPackRegistry scope authorizedPacks = buildPackRegistryWithRetained scope authorizedPacks []

buildPackRegistryWithRetained :: ProfileScope -> [ExecutionAuthorizedPack] -> [ExecutionAuthorizedPack] -> Either AppError PackRegistry
buildPackRegistryWithRetained scope activePacks retainedPacks = do
  mapM_ ensureScope (activePacks <> retainedPacks)
  components <- foldM insertAuthorized Map.empty activePacks
  exactComponents <- foldM insertExactAuthorized Map.empty (activePacks <> retainedPacks)
  pure (PackRegistry scope components exactComponents)
 where
  ensureScope authorized =
    unless
      (executionAuthorizedScope authorized == scope)
      (Left (appError PermissionRequired "A Pack execution authorization belongs to another profile."))
  insertAuthorized registry authorized =
    foldM (insertComponent authorized) registry (enabledComponents authorized)
  insertExactAuthorized registry authorized =
    foldM (insertExactComponent authorized) registry (enabledComponents authorized)
  insertComponent authorized registry component =
    let identifier = componentId (componentCommon component)
     in case Map.lookup identifier registry of
          Nothing -> Right (Map.insert identifier (registered authorized component) registry)
          Just existing ->
            Left
              ( (appError Conflict "Installed Packs expose the same component identifier.")
                  { appErrorSubject = Just identifier
                  , appErrorDetails =
                      [ artifactName (registeredPackIdentity existing)
                      , artifactName (authenticatedPackIdentity (executionAuthorizedPack authorized))
                      ]
                  , appErrorRecovery = [RecoveryAction "packs" "Disable one conflicting component pin." (Just "lant packs list")]
                  }
              )
  insertExactComponent authorized registry component =
    let identifier = componentId (componentCommon component)
        identity = authenticatedPackIdentity (executionAuthorizedPack authorized)
        key = (identity, identifier)
        candidate = registered authorized component
     in case Map.lookup key registry of
          Nothing -> Right (Map.insert key candidate registry)
          Just existing
            | existing == candidate -> Right registry
            | otherwise ->
                Left
                  ( (appError Conflict "The same exact Pack artifact exposes inconsistent component material.")
                      { appErrorSubject = Just identifier
                      , appErrorDetails = [artifactName identity, artifactVersion identity, artifactArchiveDigest identity]
                      }
                  )

lookupPackComponent :: Text -> PackRegistry -> Either AppError RegisteredPackComponent
lookupPackComponent identifier registry =
  maybe
    ( Left
        ( (appError NotFound "The requested Pack component is not enabled.")
            { appErrorSubject = Just identifier
            , appErrorRecovery = [RecoveryAction "packs" "Inspect enabled Pack components." (Just "lant packs list")]
            }
        )
    )
    Right
    (Map.lookup identifier (registryComponentMap registry))

lookupPackComponentForArtifact :: PackArtifactIdentity -> Text -> PackRegistry -> Either AppError RegisteredPackComponent
lookupPackComponentForArtifact artifact identifier registry =
  maybe
    ( Left
        ( (appError NotFound "The requested exact Pack component is not available.")
            { appErrorSubject = Just identifier
            , appErrorDetails = [artifactName artifact, artifactVersion artifact, artifactArchiveDigest artifact]
            , appErrorRecovery = [RecoveryAction "packs" "Inspect the exact Pack pins retained by configured integrations." (Just "lant packs list")]
            }
        )
    )
    Right
    (Map.lookup (artifact, identifier) (registryExactComponentMap registry))

componentsOfKind :: PackComponentKind -> PackRegistry -> [RegisteredPackComponent]
componentsOfKind kind = filter ((== kind) . componentKind . componentCommon . registeredComponent) . registryComponents

enabledComponents :: ExecutionAuthorizedPack -> [PackComponent]
enabledComponents authorized =
  let enabled = pinEnabledComponents (executionAuthorizedPin authorized)
      manifest = structurallyValidManifest (authenticatedStructuralPack (executionAuthorizedPack authorized))
   in filter ((`Set.member` enabled) . componentId . componentCommon) (packComponents manifest)

registered :: ExecutionAuthorizedPack -> PackComponent -> RegisteredPackComponent
registered authorized component =
  let authenticated = executionAuthorizedPack authorized
      structural = authenticatedStructuralPack authenticated
      root = componentRoot (componentCommon component)
      prefix = root <> "/"
      payload =
        Map.fromList
          [ (Text.drop (Text.length prefix) path, bytes)
          | (path, bytes) <- Map.toAscList (structurallyValidPayload structural)
          , prefix `Text.isPrefixOf` path
          ]
   in RegisteredPackComponent
        { registeredPackIdentity = authenticatedPackIdentity authenticated
        , registeredSignerFingerprint = authenticatedSignerFingerprint authenticated
        , registeredComponent = component
        , registeredComponentPayload = payload
        }

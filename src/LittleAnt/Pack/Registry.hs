module LittleAnt.Pack.Registry (
  RegisteredPackComponent (..),
  PackRegistry,
  registryProfileScope,
  registryComponents,
  buildPackRegistry,
  lookupPackComponent,
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
  }
  deriving stock (Eq, Show)

registryComponents :: PackRegistry -> [RegisteredPackComponent]
registryComponents = Map.elems . registryComponentMap

buildPackRegistry :: ProfileScope -> [ExecutionAuthorizedPack] -> Either AppError PackRegistry
buildPackRegistry scope authorizedPacks = do
  mapM_ ensureScope authorizedPacks
  components <- foldM insertAuthorized Map.empty authorizedPacks
  pure (PackRegistry scope components)
 where
  ensureScope authorized =
    unless
      (executionAuthorizedScope authorized == scope)
      (Left (appError PermissionRequired "A Pack execution authorization belongs to another profile."))
  insertAuthorized registry authorized =
    foldM (insertComponent authorized) registry (enabledComponents authorized)
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

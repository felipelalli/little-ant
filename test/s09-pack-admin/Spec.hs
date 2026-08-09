module Main (main) where

import Control.Exception (bracket)
import Data.Aeson (Value (Object), encode, toJSON)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.List (isInfixOf)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import LittleAnt.Application
import LittleAnt.Error
import LittleAnt.Pack.Trust
import LittleAnt.Profile qualified as Profile
import LittleAnt.Result
import LittleAnt.Store (DatasetCursor (Genesis))
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain $
    testGroup
      "S09 Pack administration"
      [ testCase "list exposes the exact bundled Pack without mutating the dataset" listBuiltIn
      , testCase "show resolves only the exact Pack name and returns component authority" showBuiltIn
      , testCase "show rejects an unknown Pack with an educational recovery" rejectUnknown
      , testCase "read-only dry-run remains visibly read-only and sparse" dryRunList
      , testCase "Pack inspection remains available when one configured archive is unavailable" inspectBrokenRegistry
      ]

listBuiltIn :: Assertion
listBuiltIn = withHarness $ \environment -> do
  result <- run environment False PacksListCommand
  case result of
    PacksResult Genesis "list" [pack] Nothing False -> do
      projectedPackName pack @?= "org.littleant.standard"
      projectedPackDisplayName pack @?= "Little Ant Standard Pack"
      projectedPackTrustClass pack @?= "built in"
      length (projectedPackComponents pack) @?= 9
      assertBool "all bundled components are enabled" (all projectedPackComponentEnabled (projectedPackComponents pack))
    other -> assertFailure ("unexpected list result: " <> show other)

showBuiltIn :: Assertion
showBuiltIn = withHarness $ \environment -> do
  result <- run environment False (PacksShowCommand "org.littleant.standard")
  case result of
    PacksResult Genesis "show" [pack] Nothing False -> do
      projectedPackPublisher pack @?= "org.littleant.project"
      assertBool "archive digest is complete" (Text.length (projectedPackArchiveDigest pack) == 64)
      assertBool "signer fingerprint is complete" (Text.length (projectedPackSignerFingerprint pack) == 64)
      let sourceAdapters = filter ((== "SourceAdapter") . projectedPackComponentKind) (projectedPackComponents pack)
      fmap projectedPackComponentId sourceAdapters @?= ["notesnook_export", "plain_text", "taskjuggler_actuals"]
    other -> assertFailure ("unexpected show result: " <> show other)

rejectUnknown :: Assertion
rejectUnknown = withHarness $ \environment -> do
  observed <- runAppCommand environment False silentProgress (PacksShowCommand "org.example.missing")
  case observed of
    Left problem -> do
      appErrorCode problem @?= NotFound
      fmap recoveryActionCommand (appErrorRecovery problem) @?= [Just "lant packs list"]
    Right result -> assertFailure ("expected not-found, got: " <> show result)

dryRunList :: Assertion
dryRunList = withHarness $ \environment -> do
  result <- run environment True PacksListCommand
  case result of
    PacksResult Genesis "list" [_] Nothing True -> pure ()
    other -> assertFailure ("unexpected dry-run result: " <> show other)
  case toJSON result of
    Object fields -> do
      assertBool "dry_run is present when true" (KeyMap.member "dry_run" fields)
      assertBool "the sparse projection has no mutation command id" (not (KeyMap.member "command_id" fields))
      assertBool "encoded output never includes Pack bytes" (not ("payload" `isInfixOf` LazyByteString.unpack (encode result)))
    other -> assertFailure ("expected object JSON, got: " <> show other)

inspectBrokenRegistry :: Assertion
inspectBrokenRegistry = withSystemTempDirectory "little-ant-pack-admin-broken" $ \root ->
  withEnvironment (xdgAssignments root) $ do
    _ <- productionAppEnv Nothing >>= either (assertFailure . show) pure
    roots <- Profile.resolveXdgRoots
    loaded <- Profile.loadProfile roots "default" >>= either (assertFailure . show) pure
    let (paths, _, _, _, integrations) = loaded
        identity = PackArtifactIdentity "org.example" "org.example.missing" "1.0.0" (Text.replicate 64 "a") (Text.replicate 64 "b")
        pin = PackPin identity (Text.replicate 64 "c") PinTrustedPublisher (Set.singleton "example")
        changed = integrations{Profile.installedComponents = Map.singleton "org.example.missing" pin}
    Profile.writeIntegrationsConfig paths changed >>= either (assertFailure . show) pure
    restarted <- productionAppEnv Nothing >>= either (assertFailure . show) pure
    assertBool "startup retains the Pack registry failure" (maybe False (const True) (appPackRegistryProblem restarted))
    listed <- run restarted False PacksListCommand
    case listed of
      PacksResult Genesis "list" packs (Just _) False ->
        case filter ((== "org.example.missing") . projectedPackName) packs of
          [missing] -> do
            projectedPackStatus missing @?= "unavailable"
            assertBool "the exact inspection problem is retained" (maybe False (const True) (projectedPackProblem missing))
          other -> assertFailure ("expected one unavailable Pack, got: " <> show other)
      other -> assertFailure ("unexpected degraded list result: " <> show other)
    ordinary <- run restarted False NextCommand
    case ordinary of
      NextResult{} -> pure ()
      other -> assertFailure ("ordinary canonical work became unavailable: " <> show other)

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-pack-admin" $ \root ->
  withEnvironment
    (xdgAssignments root)
    ( productionAppEnv Nothing >>= \case
        Left problem -> assertFailure (show problem) >> fail "unreachable"
        Right environment -> action environment
    )

xdgAssignments :: FilePath -> [(String, String)]
xdgAssignments root =
  [ ("XDG_CONFIG_HOME", root </> "config")
  , ("XDG_DATA_HOME", root </> "data")
  , ("XDG_STATE_HOME", root </> "state")
  , ("XDG_RUNTIME_DIR", root </> "runtime")
  ]

withEnvironment :: [(String, String)] -> IO a -> IO a
withEnvironment assignments action = bracket save restore (const (setAll >> action))
 where
  save = traverse (\(name, _) -> (name,) <$> lookupEnv name) assignments
  restore previous = mapM_ restoreOne previous
  restoreOne (name, Just value) = setEnv name value
  restoreOne (name, Nothing) = unsetEnv name
  setAll = mapM_ (uncurry setEnv) assignments

run :: AppEnv -> Bool -> AppCommand -> IO CommandResult
run environment dryRun command =
  runAppCommand environment dryRun silentProgress command >>= either (assertFailure . show) pure

silentProgress :: Integer -> IO ()
silentProgress _ = pure ()

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE TypeApplications #-}

-- | Isolated HsLua process for executable Little Ant Pack components.
module Main (main) where

import Control.Exception (SomeException, try)
import Control.Monad (when)
import Data.Aeson
  (FromJSON (parseJSON), Value (..), eitherDecode, encode, object, withObject,
   (.:), (.=))
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.Lazy.Char8 as LBS8
import Data.Foldable (toList)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import GHC.Generics (Generic)
import qualified HsLua as Lua
import qualified HsLua.Aeson as LuaAeson
import LittleAnt.V1.Integration
  (PackExecutionResult (..), SandboxLimits (..))
import System.IO (BufferMode (LineBuffering), hFlush, hSetBuffering, stdin, stdout)
import System.Posix.Resource
  (Resource (ResourceTotalMemory), ResourceLimit (ResourceLimit),
   ResourceLimits (..), setResourceLimit)
import System.Timeout (timeout)

-- The process protocol is intentionally private.  Pack authors see only the
-- versioned Pack request/result and lant host APIs.
data RunnerRequest = RunnerRequest
  { runnerRequestProtocolVersion :: Integer
  , runnerRequestLimits :: SandboxLimits
  , runnerRequestCapabilityGrants :: [Text]
  , runnerRequestInput :: Value
  , runnerRequestSource :: Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON RunnerRequest where
  parseJSON = withObject "RunnerRequest" $ \fields -> RunnerRequest
    <$> fields .: "protocol_version"
    <*> fields .: "limits"
    <*> fields .: "capability_grants"
    <*> fields .: "input"
    <*> fields .: "source"

main :: IO ()
main = do
  hSetBuffering stdin LineBuffering
  hSetBuffering stdout LineBuffering
  line <- LBS.fromStrict <$> BS8.getLine
  result <- case eitherDecode line of
    Left _ -> pure (failed "runner_protocol_error")
    Right request -> executeRequest request
  emitResult result

executeRequest :: RunnerRequest -> IO PackExecutionResult
executeRequest request
  | runnerRequestProtocolVersion request /= 1 =
      pure (failed "runner_protocol_error")
  | not (validLimits (runnerRequestLimits request)) =
      pure (failed "invalid_runtime_limits")
  | BS.length source > sandboxLimitSourceBytes limits =
      pure (failed "source_limit")
  | otherwise = do
      applyProcessMemoryCeiling limits
      attempted <- timeout (sandboxLimitWallMicros limits)
        (try (Lua.run @Lua.Exception (luaProgram request)) ::
          IO (Either SomeException Value))
      pure $ case attempted of
        Nothing -> failed "timeout"
        Just (Left problem)
          | containsProblem "instruction_limit" problem ->
              failed "instruction_limit"
          | containsProblem "memory_limit" problem
              || containsProblem "not enough memory" problem ->
              failed "memory_limit"
          | otherwise -> failed "lua_error"
        Just (Right output)
          | LBS.length (encode output) >
              fromIntegral (sandboxLimitOutputBytes limits) ->
              failed "output_limit"
          | valueDepth output > sandboxLimitNestingDepth limits ->
              failed "nesting_limit"
          | otherwise -> succeeded output
  where
    limits = runnerRequestLimits request
    source = TextEncoding.encodeUtf8 (runnerRequestSource request)

luaProgram :: RunnerRequest -> Lua.Lua Value
luaProgram request = do
  Lua.openbase
  Lua.openmath
  Lua.setglobal "math"
  Lua.openstring
  Lua.setglobal "string"
  Lua.opentable
  Lua.setglobal "table"
  Lua.opendebug
  Lua.setglobal "debug"
  Lua.settop 0
  mapM_ removeGlobal ["dofile", "loadfile", "print", "warn"]
  installTypedHost (runnerRequestCapabilityGrants request)
  LuaAeson.pushValue (runnerRequestInput request)
  Lua.setglobal "input"
  let limits = runnerRequestLimits request
      hookPeriod = 100 :: Integer
      hookCalls = max 1 (sandboxLimitInstructions limits `div` hookPeriod)
      memoryBytes = sandboxLimitMemoryBytes limits
      prefix = BS8.pack
        ("do local __lant_count=0; local __lant_error=error; "
          <> "local __lant_memory=debug.getregistry and collectgarbage; "
          <> "local __lant_base=__lant_memory('count')*1024; "
          <> "debug.sethook(function() __lant_count=__lant_count+1; "
          <> "if __lant_count>" <> show hookCalls
          <> " then __lant_error('instruction_limit') end; "
          <> "if (__lant_memory('count')*1024-__lant_base)>"
          <> show memoryBytes
          <> " then __lant_error('memory_limit') end end, '', "
          <> show hookPeriod <> "); end; debug=nil; collectgarbage=nil; ")
  _ <- Lua.loadstring (prefix <> TextEncoding.encodeUtf8
    (runnerRequestSource request))
  Lua.call 0 1
  memoryKilobytes <- Lua.gc Lua.GCCount
  memoryRemainder <- Lua.gc Lua.GCCountb
  let allocated = fromIntegral memoryKilobytes * 1024
        + fromIntegral memoryRemainder
  when (allocated > sandboxLimitMemoryBytes limits)
    (Lua.failLua "memory_limit")
  Lua.forcePeek (LuaAeson.peekValue Lua.top)

removeGlobal :: Lua.Name -> Lua.Lua ()
removeGlobal name = Lua.pushnil *> Lua.setglobal name

installTypedHost :: [Text] -> Lua.Lua ()
installTypedHost grants =
  when (any ("http:" `Text.isPrefixOf`) grants) $ do
    Lua.newtable
    Lua.newtable
    Lua.pushHaskellFunction typedHttpRequest
    Lua.setfield (-2) "request"
    Lua.setfield (-2) "http"
    Lua.setglobal "lant"

typedHttpRequest :: Lua.LuaE Lua.Exception Lua.NumResults
typedHttpRequest = do
  request <- Lua.forcePeek (LuaAeson.peekValue 1)
  response <- Lua.liftIO (brokerHostRequest request)
  LuaAeson.pushValue response
  pure (Lua.NumResults 1)

brokerHostRequest :: Value -> IO Value
brokerHostRequest request = do
  LBS8.putStrLn (encode (object
    [ "protocol_version" .= (1 :: Integer)
    , "message_kind" .= ("host_http_request" :: Text)
    , "request" .= request
    ]))
  hFlush stdout
  responseLine <- LBS.fromStrict <$> BS8.getLine
  case eitherDecode responseLine of
    Right (Object fields)
      | Just (String "host_http_response") <-
          KeyMap.lookup "message_kind" fields
      , Just response <- KeyMap.lookup "response" fields -> pure response
    _ -> pure (object
      ["ok" .= False, "error_code" .= ("host_protocol_error" :: Text)])

emitResult :: PackExecutionResult -> IO ()
emitResult result = do
  LBS8.putStrLn (encode (object
    [ "protocol_version" .= (1 :: Integer)
    , "message_kind" .= ("result" :: Text)
    , "result" .= result
    ]))
  hFlush stdout

-- RLIMIT_AS prevents one allocation from escaping between instruction-hook
-- checks.  The ceiling is relative to the already-mapped runner image; the
-- exact Lua budget is still enforced by the hook and final GC accounting.
applyProcessMemoryCeiling :: SandboxLimits -> IO ()
applyProcessMemoryCeiling limits = do
  status <- readFile "/proc/self/status"
  let currentKilobytes = case find ((== "VmSize:") . take 7) (lines status) of
        Just line -> case words line of
          ["VmSize:", amount, "kB"] -> case reads amount of
            [(kilobytes, "")] -> kilobytes
            _ -> 0
          _ -> 0
        Nothing -> 0 :: Integer
      currentBytes = currentKilobytes * 1024
      runtimeCushion = 32 * 1024 * 1024
      memoryCeiling = currentBytes + sandboxLimitMemoryBytes limits + runtimeCushion
      resourceLimit = ResourceLimit memoryCeiling
  setResourceLimit ResourceTotalMemory ResourceLimits
    {softLimit = resourceLimit, hardLimit = resourceLimit}

containsProblem :: String -> SomeException -> Bool
containsProblem needle = Text.isInfixOf (Text.pack needle) . Text.pack . show

failed :: Text -> PackExecutionResult
failed code = PackExecutionResult 1 False Nothing (Just code) []

succeeded :: Value -> PackExecutionResult
succeeded output = PackExecutionResult 1 True (Just output) Nothing []

validLimits :: SandboxLimits -> Bool
validLimits limits = and
  [ sandboxLimitWallMicros limits > 0
  , sandboxLimitInstructions limits > 0
  , sandboxLimitMemoryBytes limits > 0
  , sandboxLimitSourceBytes limits > 0
  , sandboxLimitOutputBytes limits > 0
  , sandboxLimitNestingDepth limits > 0
  ]

valueDepth :: Value -> Int
valueDepth = \case
  Object fields -> 1 + maximumOrZero (map valueDepth (KeyMap.elems fields))
  Array values -> 1 + maximumOrZero (map valueDepth (toList values))
  _ -> 1

maximumOrZero :: [Int] -> Int
maximumOrZero [] = 0
maximumOrZero values = maximum values

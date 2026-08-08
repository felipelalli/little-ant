{-# LANGUAGE CPP #-}

module LittleAnt.Vault.Agent (
  AgentRequest,
  AgentReply,
  agentStatusRequest,
  agentUnlockRequest,
  agentLockRequest,
  agentInventoryRequest,
  agentResolveRequest,
  agentPutRequest,
  agentRemoveRequest,
  agentRotateRequest,
  agentShutdownRequest,
  agentReplyUnlocked,
  agentReplySucceeded,
  agentReplyInventory,
  agentReplySecret,
  wipeAgentSecret,
  runVaultAgent,
  sendVaultAgentRequest,
) where

import Control.Concurrent (MVar, forkIO, modifyMVar, modifyMVar_, newMVar, threadDelay)
import Control.Exception (IOException, bracket, catch, finally)
import Control.Monad (forever, unless, when)
import Data.Aeson (eitherDecodeStrict', encode)
import Data.Bits (shiftL, (.&.), (.|.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Data.Word (Word32, Word8)
import Foreign
import Foreign.C.Error (throwErrnoIfMinus1_)
import Foreign.C.Types
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Vault
import LittleAnt.Vault.Age
import Network.Socket
import Network.Socket.ByteString qualified as Socket
import System.Directory hiding (isSymbolicLink)
import System.FilePath (takeDirectory)
import System.Posix.Files
import System.Posix.Types (CGid, CPid, CUid)
import System.Posix.User (getEffectiveUserID)

data AgentRequest
  = StatusRequest
  | UnlockRequest ByteString
  | LockRequest
  | InventoryRequest
  | ResolveRequest UUIDv7 Text
  | PutRequest UUIDv7 CredentialScheme Text (Map Text Text) ByteString
  | RemoveRequest UUIDv7
  | RotateRequest ByteString
  | ShutdownRequest

data AgentReply
  = OkReply
  | StatusReply Bool
  | InventoryReply [VaultInventoryEntry]
  | SecretReply ByteString
  | ErrorReply AppError

data UnlockedVault = UnlockedVault
  { unlockedPassphrase :: Passphrase
  , unlockedContents :: Vault
  , unlockedExpiresAt :: UTCTime
  }

newtype AgentMemory = AgentMemory (Maybe UnlockedVault)

agentStatusRequest :: AgentRequest
agentStatusRequest = StatusRequest

agentUnlockRequest :: ByteString -> AgentRequest
agentUnlockRequest = UnlockRequest

agentLockRequest :: AgentRequest
agentLockRequest = LockRequest

agentInventoryRequest :: AgentRequest
agentInventoryRequest = InventoryRequest

agentResolveRequest :: UUIDv7 -> Text -> AgentRequest
agentResolveRequest = ResolveRequest

agentPutRequest :: UUIDv7 -> CredentialScheme -> Text -> Map Text Text -> ByteString -> AgentRequest
agentPutRequest = PutRequest

agentRemoveRequest :: UUIDv7 -> AgentRequest
agentRemoveRequest = RemoveRequest

agentRotateRequest :: ByteString -> AgentRequest
agentRotateRequest = RotateRequest

agentShutdownRequest :: AgentRequest
agentShutdownRequest = ShutdownRequest

agentReplyUnlocked :: AgentReply -> Maybe Bool
agentReplyUnlocked = \case
  StatusReply unlocked -> Just unlocked
  _ -> Nothing

wipeAgentSecret :: ByteString -> IO ()
wipeAgentSecret = wipeBytes

agentReplySucceeded :: AgentReply -> Bool
agentReplySucceeded = \case
  OkReply -> True
  _ -> False

agentReplyInventory :: AgentReply -> Maybe [VaultInventoryEntry]
agentReplyInventory = \case
  InventoryReply inventory -> Just inventory
  _ -> Nothing

agentReplySecret :: AgentReply -> Maybe ByteString
agentReplySecret = \case
  SecretReply secret -> Just secret
  _ -> Nothing

runVaultAgent :: FilePath -> FilePath -> Int -> IO (Either AppError ())
runVaultAgent socketPath vaultPath idleSeconds
  | idleSeconds <= 0 = pure (Left (appError InvalidInput "The vault-agent idle timeout must be positive."))
  | otherwise = handleAgentIO $ do
      prepareSocketDirectory socketPath
      rejectExistingSocketPath socketPath
      memory <- newMVar (AgentMemory Nothing)
      _ <- forkIO (idleReaper idleSeconds memory)
      bracket (openServer socketPath) close $ \server ->
        finally (acceptLoop server memory) (removeSocketPath socketPath)
      pure (Right ())
 where
  acceptLoop server memory = do
    (client, _) <- accept server
    shouldStop <-
      finally
        ( do
            sameUser <- peerMatchesEffectiveUser client
            if not sameUser
              then sendFrame client (encodeReply (ErrorReply (appError PreconditionFailed "The vault agent rejected a peer with a different user identity."))) >> pure False
              else do
                requestBytes <- receiveFrame client
                case requestBytes >>= decodeRequest of
                  Left problem -> sendFrame client (encodeReply (ErrorReply problem)) >> pure False
                  Right request -> do
                    (reply, stop) <- handleRequest vaultPath idleSeconds memory request
                    sendFrame client (encodeReply reply)
                    pure stop
        )
        (close client)
    unless shouldStop (acceptLoop server memory)

sendVaultAgentRequest :: FilePath -> AgentRequest -> IO (Either AppError AgentReply)
sendVaultAgentRequest socketPath request =
  finally
    ( handleAgentIO $ do
        validateSocketPath socketPath
        bracket (socket AF_UNIX Stream defaultProtocol) close $ \client -> do
          connect client (SockAddrUnix socketPath)
          sendFrame client (encodeRequest request)
          receiveFrame client >>= \case
            Left problem -> pure (Left problem)
            Right bytes ->
              pure $ case decodeReply bytes of
                Left problem -> Left problem
                Right (ErrorReply problem) -> Left problem
                Right reply -> Right reply
    )
    (wipeRequest request)

handleRequest :: FilePath -> Int -> MVar AgentMemory -> AgentRequest -> IO (AgentReply, Bool)
handleRequest vaultPath idleSeconds memory = \case
  StatusRequest -> do
    unlocked <- modifyMVar memory $ \current -> do
      refreshed <- expireIfNeeded current
      pure (refreshed, isUnlocked refreshed)
    pure (StatusReply unlocked, False)
  UnlockRequest supplied -> do
    let passphraseResult = makePassphraseBytes supplied
    wipeBytes supplied
    case passphraseResult of
      Left problem -> pure (ErrorReply problem, False)
      Right passphrase ->
        readVault vaultPath passphrase >>= \case
          Left _ -> pure (ErrorReply (appError PermissionRequired "Could not unlock these credentials."), False)
          Right vault -> do
            now <- getCurrentTime
            modifyMVar_ memory (const (pure (AgentMemory (Just (UnlockedVault passphrase vault (addUTCTime (fromIntegral idleSeconds) now))))))
            pure (OkReply, False)
  LockRequest -> do
    modifyMVar_ memory (const (pure (AgentMemory Nothing)))
    pure (OkReply, False)
  InventoryRequest -> withUnlocked idleSeconds memory $ \unlocked ->
    pure (InventoryReply (vaultInventory (unlockedContents unlocked)))
  ResolveRequest identity _purpose -> withUnlocked idleSeconds memory $ \unlocked ->
    case resolveVaultEntrySecret identity (unlockedContents unlocked) of
      Left problem -> pure (ErrorReply problem)
      Right secret -> pure (SecretReply (Text.encodeUtf8 secret))
  PutRequest identity scheme label metadata suppliedSecret -> do
    reply <- case Text.decodeUtf8' suppliedSecret of
      Left _ -> pure (ErrorReply (appError InvalidInput "Credential text must be valid UTF-8."))
      Right secret ->
        withUnlockedMutation vaultPath idleSeconds memory $ \vault ->
          case resolveVaultEntrySecret identity vault of
            Right _ -> updateVaultEntry identity secret metadata vault
            Left _ -> insertVaultEntry identity scheme label secret metadata vault
    wipeBytes suppliedSecret
    pure (reply, False)
  RotateRequest supplied -> do
    let replacementResult = makePassphraseBytes supplied
    wipeBytes supplied
    reply <- case replacementResult of
      Left problem -> pure (ErrorReply problem)
      Right replacement -> rotateUnlocked vaultPath idleSeconds memory replacement
    pure (reply, False)
  RemoveRequest identity -> do
    reply <- withUnlockedMutation vaultPath idleSeconds memory (removeVaultEntry identity)
    pure (reply, False)
  ShutdownRequest -> do
    modifyMVar_ memory (const (pure (AgentMemory Nothing)))
    pure (OkReply, True)

withUnlocked :: Int -> MVar AgentMemory -> (UnlockedVault -> IO AgentReply) -> IO (AgentReply, Bool)
withUnlocked idleSeconds memory action = do
  now <- getCurrentTime
  reply <- modifyMVar memory $ \current -> do
    refreshed <- expireIfNeededAt now current
    case refreshed of
      AgentMemory Nothing -> pure (refreshed, ErrorReply (appError PermissionRequired "Credentials are locked."))
      AgentMemory (Just unlocked) -> do
        result <- action unlocked
        pure (AgentMemory (Just unlocked{unlockedExpiresAt = addUTCTime (fromIntegral idleSeconds) now}), result)
  pure (reply, False)

withUnlockedMutation :: FilePath -> Int -> MVar AgentMemory -> (Vault -> Either AppError Vault) -> IO AgentReply
withUnlockedMutation vaultPath idleSeconds memory mutation = do
  now <- getCurrentTime
  modifyMVar memory $ \current -> do
    refreshed <- expireIfNeededAt now current
    case refreshed of
      AgentMemory Nothing -> pure (refreshed, ErrorReply (appError PermissionRequired "Credentials are locked."))
      AgentMemory (Just unlocked) ->
        case mutation (unlockedContents unlocked) of
          Left problem -> pure (refreshed, ErrorReply problem)
          Right changed ->
            writeVault vaultPath (unlockedPassphrase unlocked) changed >>= \case
              Left problem -> pure (refreshed, ErrorReply problem)
              Right () ->
                pure
                  ( AgentMemory (Just unlocked{unlockedContents = changed, unlockedExpiresAt = addUTCTime (fromIntegral idleSeconds) now})
                  , OkReply
                  )

rotateUnlocked :: FilePath -> Int -> MVar AgentMemory -> Passphrase -> IO AgentReply
rotateUnlocked vaultPath idleSeconds memory replacement = do
  now <- getCurrentTime
  modifyMVar memory $ \current -> do
    refreshed <- expireIfNeededAt now current
    case refreshed of
      AgentMemory Nothing -> pure (refreshed, ErrorReply (appError PermissionRequired "Credentials are locked."))
      AgentMemory (Just unlocked) ->
        writeVault vaultPath replacement (unlockedContents unlocked) >>= \case
          Left problem -> pure (refreshed, ErrorReply problem)
          Right () ->
            readVault vaultPath replacement >>= \case
              Left problem -> pure (refreshed, ErrorReply problem)
              Right verified
                | verified /= unlockedContents unlocked ->
                    pure (refreshed, ErrorReply (appError CorruptData "The rotated vault failed verification."))
                | otherwise ->
                    pure
                      ( AgentMemory (Just unlocked{unlockedPassphrase = replacement, unlockedExpiresAt = addUTCTime (fromIntegral idleSeconds) now})
                      , OkReply
                      )

idleReaper :: Int -> MVar AgentMemory -> IO ()
idleReaper idleSeconds memory = forever $ do
  threadDelay (min 1 idleSeconds * 1_000_000)
  modifyMVar_ memory expireIfNeeded

expireIfNeeded :: AgentMemory -> IO AgentMemory
expireIfNeeded current = getCurrentTime >>= \now -> expireIfNeededAt now current

expireIfNeededAt :: UTCTime -> AgentMemory -> IO AgentMemory
expireIfNeededAt now current@(AgentMemory unlocked) =
  pure $ case unlocked of
    Just active | unlockedExpiresAt active <= now -> AgentMemory Nothing
    _ -> current

isUnlocked :: AgentMemory -> Bool
isUnlocked (AgentMemory value) = case value of Just _ -> True; Nothing -> False

openServer :: FilePath -> IO Socket
openServer path = do
  server <- socket AF_UNIX Stream defaultProtocol
  setSocketOption server ReuseAddr 1
  bind server (SockAddrUnix path)
  setFileMode path 0o600
  listen server 16
  pure server

prepareSocketDirectory :: FilePath -> IO ()
prepareSocketDirectory path = do
  let directory = takeDirectory path
  createDirectoryIfMissing True directory
  status <- getSymbolicLinkStatus directory
  when (isSymbolicLink status || not (isDirectory status)) (ioError (userError "vault-agent runtime path is unsafe"))
  setFileMode directory 0o700

rejectExistingSocketPath :: FilePath -> IO ()
rejectExistingSocketPath path = do
  exists <- doesPathExist path
  when exists (ioError (userError "vault-agent socket path already exists"))

removeSocketPath :: FilePath -> IO ()
removeSocketPath path = do
  exists <- doesPathExist path
  when exists $ do
    status <- getSymbolicLinkStatus path
    when (isSocket status && not (isSymbolicLink status)) (removeFile path)

validateSocketPath :: FilePath -> IO ()
validateSocketPath path = do
  status <- getSymbolicLinkStatus path
  uid <- getEffectiveUserID
  when
    ( isSymbolicLink status
        || not (isSocket status)
        || fileOwner status /= uid
        || fileMode status .&. 0o077 /= 0
    )
    (ioError (userError "vault-agent socket ownership or permissions are unsafe"))

peerMatchesEffectiveUser :: Socket -> IO Bool
peerMatchesEffectiveUser connection = do
  expected <- getEffectiveUserID
  actual <- peerUserId connection
  pure (actual == expected)

#if defined(linux_HOST_OS)
data UCred = UCred CPid CUid CGid

instance Storable UCred where
  sizeOf _ = sizeOf (undefined :: CInt) * 3
  alignment _ = alignment (undefined :: CInt)
  peek pointer =
    UCred
      <$> peekByteOff pointer 0
      <*> peekByteOff pointer (sizeOf (undefined :: CInt))
      <*> peekByteOff pointer (sizeOf (undefined :: CInt) * 2)
  poke pointer (UCred pid uid gid) = do
    pokeByteOff pointer 0 pid
    pokeByteOff pointer (sizeOf (undefined :: CInt)) uid
    pokeByteOff pointer (sizeOf (undefined :: CInt) * 2) gid

peerUserId :: Socket -> IO CUid
peerUserId connection =
  withFdSocket connection $ \descriptor ->
    alloca $ \credentials ->
      alloca $ \lengthPointer -> do
        poke lengthPointer (fromIntegral (sizeOf (undefined :: UCred)) :: CUInt)
        throwErrnoIfMinus1_ "getsockopt(SO_PEERCRED)" $
          c_getsockopt descriptor 1 17 credentials lengthPointer
        UCred _ uid _ <- peek credentials
        pure uid

foreign import ccall unsafe "getsockopt"
  c_getsockopt :: CInt -> CInt -> CInt -> Ptr UCred -> Ptr CUInt -> IO CInt
#elif defined(darwin_HOST_OS)
peerUserId :: Socket -> IO CUid
peerUserId connection =
  withFdSocket connection $ \descriptor ->
    alloca $ \uidPointer ->
      alloca $ \gidPointer -> do
        throwErrnoIfMinus1_ "getpeereid" (c_getpeereid descriptor uidPointer gidPointer)
        peek uidPointer

foreign import ccall unsafe "getpeereid"
  c_getpeereid :: CInt -> Ptr CUid -> Ptr CGid -> IO CInt
#else
peerUserId :: Socket -> IO CUid
peerUserId _ = ioError (userError "peer credential checks are unsupported on this platform")
#endif

sendFrame :: Socket -> ByteString -> IO ()
sendFrame connection payload = do
  when (ByteString.length payload > maximumFrameSize) (ioError (userError "vault-agent frame is too large"))
  Socket.sendAll connection (frame payload)

receiveFrame :: Socket -> IO (Either AppError ByteString)
receiveFrame connection = do
  header <- receiveExact connection 4
  if ByteString.length header /= 4
    then pure (Left (protocolError "The vault-agent frame header is truncated."))
    else do
      let lengthInBytes = fromIntegral (decodeWord32 header)
      if lengthInBytes > maximumFrameSize
        then pure (Left (protocolError "The vault-agent frame exceeds the size limit."))
        else do
          payload <- receiveExact connection lengthInBytes
          pure $
            if ByteString.length payload == lengthInBytes
              then Right payload
              else Left (protocolError "The vault-agent frame body is truncated.")

receiveExact :: Socket -> Int -> IO ByteString
receiveExact connection expected = go [] 0
 where
  go chunks received
    | received >= expected = pure (ByteString.concat (reverse chunks))
    | otherwise = do
        chunk <- Socket.recv connection (expected - received)
        if ByteString.null chunk
          then pure (ByteString.concat (reverse chunks))
          else go (chunk : chunks) (received + ByteString.length chunk)

frame :: ByteString -> ByteString
frame payload =
  LazyByteString.toStrict . Builder.toLazyByteString $
    Builder.word32BE (fromIntegral (ByteString.length payload)) <> Builder.byteString payload

encodeRequest :: AgentRequest -> ByteString
encodeRequest = \case
  StatusRequest -> payload 1 []
  UnlockRequest passphrase -> payload 2 [passphrase]
  LockRequest -> payload 3 []
  InventoryRequest -> payload 4 []
  ResolveRequest identity purpose -> payload 5 [Text.encodeUtf8 (renderUUIDv7 identity), Text.encodeUtf8 purpose]
  PutRequest identity scheme label metadata secret ->
    payload
      6
      [ Text.encodeUtf8 (renderUUIDv7 identity)
      , Text.encodeUtf8 (credentialSchemeName scheme)
      , Text.encodeUtf8 label
      , LazyByteString.toStrict (encode metadata)
      , secret
      ]
  RemoveRequest identity -> payload 7 [Text.encodeUtf8 (renderUUIDv7 identity)]
  ShutdownRequest -> payload 8 []
  RotateRequest replacement -> payload 9 [replacement]
 where
  payload opcode fields = ByteString.pack [protocolVersion, opcode] <> encodeFields fields

decodeRequest :: ByteString -> Either AppError AgentRequest
decodeRequest encoded = do
  (opcode, fields) <- decodePayload encoded
  case (opcode, fields) of
    (1, []) -> Right StatusRequest
    (2, [passphrase]) -> Right (UnlockRequest passphrase)
    (3, []) -> Right LockRequest
    (4, []) -> Right InventoryRequest
    (5, [identity, purpose]) -> ResolveRequest <$> parseIdentityBytes identity <*> pure (Text.decodeUtf8Lenient purpose)
    (6, [identity, scheme, label, metadata, secret]) ->
      PutRequest
        <$> parseIdentityBytes identity
        <*> parseCredentialSchemeName (Text.decodeUtf8Lenient scheme)
        <*> pure (Text.decodeUtf8Lenient label)
        <*> either (const (Left (protocolError "Vault-entry metadata is invalid."))) Right (eitherDecodeStrict' metadata)
        <*> pure secret
    (7, [identity]) -> RemoveRequest <$> parseIdentityBytes identity
    (8, []) -> Right ShutdownRequest
    (9, [replacement]) -> Right (RotateRequest replacement)
    _ -> Left (protocolError "The vault-agent operation or field shape is unknown.")

encodeReply :: AgentReply -> ByteString
encodeReply = \case
  OkReply -> payload 0 []
  StatusReply unlocked -> payload 1 [ByteString.singleton (if unlocked then 1 else 0)]
  InventoryReply inventory -> payload 2 [LazyByteString.toStrict (encode inventory)]
  SecretReply secret -> payload 3 [secret]
  ErrorReply problem -> payload 255 [Text.encodeUtf8 (appErrorMessage problem)]
 where
  payload opcode fields = ByteString.pack [protocolVersion, opcode] <> encodeFields fields

decodeReply :: ByteString -> Either AppError AgentReply
decodeReply encoded = do
  (opcode, fields) <- decodePayload encoded
  case (opcode, fields) of
    (0, []) -> Right OkReply
    (1, [flag]) | flag == "\NUL" -> Right (StatusReply False)
    (1, [flag]) | flag == "\SOH" -> Right (StatusReply True)
    (2, [inventory]) ->
      InventoryReply <$> either (const (Left (protocolError "The vault-agent inventory is invalid."))) Right (eitherDecodeStrict' inventory)
    (3, [secret]) -> Right (SecretReply secret)
    (255, [message]) -> Right (ErrorReply (appError ExternalFailure (Text.decodeUtf8Lenient message)))
    _ -> Left (protocolError "The vault-agent reply shape is unknown.")

decodePayload :: ByteString -> Either AppError (Word8, [ByteString])
decodePayload encoded
  | ByteString.length encoded < 2 = Left (protocolError "The vault-agent payload is truncated.")
  | ByteString.index encoded 0 /= protocolVersion = Left (protocolError "The vault-agent protocol version is unsupported.")
  | otherwise = (ByteString.index encoded 1,) <$> decodeFields (ByteString.drop 2 encoded)

encodeFields :: [ByteString] -> ByteString
encodeFields =
  LazyByteString.toStrict
    . Builder.toLazyByteString
    . foldMap (\field -> Builder.word32BE (fromIntegral (ByteString.length field)) <> Builder.byteString field)

decodeFields :: ByteString -> Either AppError [ByteString]
decodeFields = go []
 where
  go fields remaining
    | ByteString.null remaining = Right (reverse fields)
    | ByteString.length remaining < 4 = Left (protocolError "A vault-agent field length is truncated.")
    | otherwise =
        let fieldLength = fromIntegral (decodeWord32 (ByteString.take 4 remaining))
            afterLength = ByteString.drop 4 remaining
         in if fieldLength > maximumFrameSize || ByteString.length afterLength < fieldLength
              then Left (protocolError "A vault-agent field is truncated or too large.")
              else go (ByteString.take fieldLength afterLength : fields) (ByteString.drop fieldLength afterLength)

decodeWord32 :: ByteString -> Word32
decodeWord32 bytes =
  foldl
    (\result byte -> shiftL result 8 .|. fromIntegral byte)
    0
    (ByteString.unpack (ByteString.take 4 bytes))

parseIdentityBytes :: ByteString -> Either AppError UUIDv7
parseIdentityBytes supplied =
  either
    (const (Left (protocolError "The vault-agent request contains an invalid identity.")))
    Right
    (parseUUIDv7 (Text.decodeUtf8Lenient supplied))

wipeRequest :: AgentRequest -> IO ()
wipeRequest = \case
  UnlockRequest secret -> wipeBytes secret
  PutRequest _ _ _ _ secret -> wipeBytes secret
  RotateRequest secret -> wipeBytes secret
  _ -> pure ()

wipeBytes :: ByteString -> IO ()
wipeBytes bytes =
  ByteString.useAsCStringLen bytes $ \(pointer, lengthInBytes) ->
    fillBytes pointer 0 lengthInBytes

protocolError :: Text -> AppError
protocolError message =
  (appError CorruptData message)
    { appErrorRetrySafety = DoNotRetry
    }

handleAgentIO :: IO (Either AppError value) -> IO (Either AppError value)
handleAgentIO action =
  catch action $ \problem ->
    pure . Left $
      (appError ExternalFailure "The local vault agent could not complete the request.")
        { appErrorDetails = [Text.pack (show (problem :: IOException))]
        , appErrorRetrySafety = DoNotRetry
        }

protocolVersion :: Word8
protocolVersion = 1

maximumFrameSize :: Int
maximumFrameSize = 1024 * 1024

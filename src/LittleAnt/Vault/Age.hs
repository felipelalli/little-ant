module LittleAnt.Vault.Age (
  Passphrase,
  makePassphrase,
  makePassphraseBytes,
  encryptAge,
  decryptAge,
  validateAgeHeader,
)
where

import Control.Exception (bracket)
import Data.ByteArray (ScrubbedBytes, convert, withByteArray)
import Data.ByteArray qualified as ByteArray
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Foreign
import Foreign.C.Types
import LittleAnt.Error

newtype Passphrase = Passphrase ScrubbedBytes
  deriving stock (Eq)

instance Show Passphrase where
  show _ = "<redacted>"

makePassphrase :: Text -> Either AppError Passphrase
makePassphrase supplied
  | ByteString.null encoded = Left (appError InvalidInput "A vault passphrase cannot be empty.")
  | otherwise = makePassphraseBytes encoded
 where
  encoded = Text.encodeUtf8 supplied

makePassphraseBytes :: ByteString -> Either AppError Passphrase
makePassphraseBytes supplied
  | ByteString.null supplied = Left (appError InvalidInput "A vault passphrase cannot be empty.")
  | otherwise = Right (Passphrase (convert supplied))

encryptAge :: Passphrase -> ByteString -> IO (Either AppError ByteString)
encryptAge passphrase plaintext =
  callAge "encrypt" c_lant_age_encrypt passphrase plaintext >>= \case
    Left problem -> pure (Left problem)
    Right ciphertext -> pure (ciphertext <$ validateAgeHeader ciphertext)

decryptAge :: Passphrase -> ByteString -> IO (Either AppError ByteString)
decryptAge passphrase ciphertext =
  case validateAgeHeader ciphertext of
    Left problem -> pure (Left problem)
    Right () -> callAge "decrypt" c_lant_age_decrypt passphrase ciphertext

validateAgeHeader :: ByteString -> Either AppError ()
validateAgeHeader ciphertext =
  case ByteString.Char8.lines ciphertext of
    first : stanza : _
      | first == "age-encryption.org/v1"
      , ["->", "scrypt", salt, "18"] <- ByteString.Char8.words stanza
      , not (ByteString.null salt) ->
          Right ()
    _ ->
      Left
        (appError CorruptData "The vault is not a supported age-v1 scrypt file with work factor 2^18.")
          { appErrorRecovery =
              [ RecoveryAction "diagnose" "Inspect the vault header and restore a verified ciphertext backup." (Just "lant vault diagnose")
              ]
          }

type AgeFunction =
  Ptr Word8 ->
  CSize ->
  Ptr Word8 ->
  CSize ->
  Ptr (Ptr Word8) ->
  Ptr CSize ->
  IO CInt

callAge :: Text -> AgeFunction -> Passphrase -> ByteString -> IO (Either AppError ByteString)
callAge operation function (Passphrase secret) input =
  withByteArray secret $ \secretPointer ->
    ByteString.useAsCStringLen input $ \(inputPointer, inputLength) ->
      alloca $ \outputPointer ->
        alloca $ \outputLength -> do
          poke outputPointer nullPtr
          poke outputLength 0
          result <-
            function
              (castPtr secretPointer)
              (fromIntegral (ByteArray.length secret))
              (castPtr inputPointer)
              (fromIntegral inputLength)
              outputPointer
              outputLength
          if result /= 0
            then Left <$> backendError operation result
            else do
              pointer <- peek outputPointer
              lengthInBytes <- fromIntegral <$> peek outputLength
              if pointer == nullPtr && lengthInBytes /= 0
                then pure (Left (appError CorruptData "The age backend returned an invalid output buffer."))
                else
                  Right
                    <$> bracket
                      (pure pointer)
                      (\owned -> c_lant_age_free owned (fromIntegral lengthInBytes))
                      (\owned -> ByteString.packCStringLen (castPtr owned, lengthInBytes))

backendError :: Text -> CInt -> IO AppError
backendError operation code = do
  required <- c_lant_age_last_error nullPtr 0
  detail <-
    if required == 0
      then pure "No diagnostic was returned."
      else allocaBytes (fromIntegral required) $ \buffer -> do
        _ <- c_lant_age_last_error buffer required
        Text.decodeUtf8Lenient <$> ByteString.packCStringLen (castPtr buffer, fromIntegral required)
  pure
    (appError CorruptData ("The vault could not " <> operation <> " through the age backend."))
      { appErrorDetails = ["backend code " <> Text.pack (show code), detail]
      , appErrorRecovery =
          [ RecoveryAction "retry" "Retry after checking the passphrase and vault integrity." Nothing
          , RecoveryAction "diagnose" "Inspect redacted vault diagnostics." (Just "lant vault diagnose")
          ]
      }

foreign import ccall safe "lant_age_encrypt"
  c_lant_age_encrypt :: AgeFunction

foreign import ccall safe "lant_age_decrypt"
  c_lant_age_decrypt :: AgeFunction

foreign import ccall unsafe "lant_age_free"
  c_lant_age_free :: Ptr Word8 -> CSize -> IO ()

foreign import ccall unsafe "lant_age_last_error"
  c_lant_age_last_error :: Ptr Word8 -> CSize -> IO CSize

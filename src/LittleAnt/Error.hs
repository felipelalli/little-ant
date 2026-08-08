module LittleAnt.Error (
  AppError (..),
  ErrorCode (..),
  RecoveryAction (..),
  RetrySafety (..),
  appError,
  errorCodeText,
)
where

import Data.Aeson (ToJSON (..), object, (.=))
import Data.Text (Text)

data ErrorCode
  = InvalidInput
  | PreconditionFailed
  | NotFound
  | AmbiguousReference
  | StaleInteraction
  | Conflict
  | RedoConflict
  | Unsupported
  | PermissionRequired
  | ExternalFailure
  | CorruptData
  | UnknownEventVersion
  deriving stock (Eq, Ord, Show)

errorCodeText :: ErrorCode -> Text
errorCodeText = \case
  InvalidInput -> "invalid_input"
  PreconditionFailed -> "precondition_failed"
  NotFound -> "not_found"
  AmbiguousReference -> "ambiguous_reference"
  StaleInteraction -> "stale_interaction"
  Conflict -> "conflict"
  RedoConflict -> "redo_conflict"
  Unsupported -> "unsupported"
  PermissionRequired -> "permission_required"
  ExternalFailure -> "external_failure"
  CorruptData -> "corrupt_data"
  UnknownEventVersion -> "unknown_event_version"

data RetrySafety = RetrySafe | RetryAfterRefresh | DoNotRetry
  deriving stock (Eq, Ord, Show)

data RecoveryAction = RecoveryAction
  {recoveryActionId :: Text, recoveryActionLabel :: Text, recoveryActionCommand :: Maybe Text}
  deriving stock (Eq, Show)

data AppError = AppError
  { appErrorCode :: ErrorCode
  , appErrorMessage :: Text
  , appErrorSubject :: Maybe Text
  , appErrorCursor :: Maybe Text
  , appErrorRetrySafety :: RetrySafety
  , appErrorDetails :: [Text]
  , appErrorRecovery :: [RecoveryAction]
  }
  deriving stock (Eq, Show)

appError :: ErrorCode -> Text -> AppError
appError code message = AppError code message Nothing Nothing DoNotRetry [] []

instance ToJSON RetrySafety where
  toJSON = toJSON . \case RetrySafe -> ("safe" :: Text); RetryAfterRefresh -> "after_refresh"; DoNotRetry -> "no"

instance ToJSON RecoveryAction where
  toJSON action =
    object $
      ["id" .= recoveryActionId action, "label" .= recoveryActionLabel action]
        <> maybe [] (pure . ("command" .=)) (recoveryActionCommand action)

instance ToJSON AppError where
  toJSON problem =
    object $
      [ "schema" .= ("little-ant/error@1" :: Text)
      , "code" .= errorCodeText (appErrorCode problem)
      , "message" .= appErrorMessage problem
      , "retry_safe" .= appErrorRetrySafety problem
      , "recovery" .= appErrorRecovery problem
      ]
        <> maybe [] (pure . ("subject" .=)) (appErrorSubject problem)
        <> maybe [] (pure . ("dataset_cursor" .=)) (appErrorCursor problem)
        <> ["details" .= appErrorDetails problem | not (null (appErrorDetails problem))]

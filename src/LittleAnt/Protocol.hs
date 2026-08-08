module LittleAnt.Protocol (
  GuidedDispatch (..),
  GuidedOutcome (..),
  dispatchGuidedShortcut,
)
where

import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Interaction
import LittleAnt.Store qualified

data GuidedOutcome
  = OpenFeedInput
  | OpenCommandPalette
  | InvokeNext
  | PendingLaterSlice Text
  deriving stock (Eq, Show)

data GuidedDispatch
  = GuidedAccepted
      { guidedActionId :: Text
      , guidedOutcome :: GuidedOutcome
      , guidedPriorCursor :: LittleAnt.Store.DatasetCursor
      , guidedAcceptedCursor :: LittleAnt.Store.DatasetCursor
      }
  | GuidedStale InteractionEnvelope
  deriving stock (Eq, Show)

dispatchGuidedShortcut ::
  InteractionEnvelope ->
  InteractionEnvelope ->
  Text ->
  Either AppError GuidedDispatch
dispatchGuidedShortcut original current shortcut = do
  action <- case matchingActions of
    [one] -> Right one
    [] ->
      Left $
        (appError InvalidInput (unboundMessage shortcut original))
          { appErrorCursor = Just (LittleAnt.Store.renderCursor (envelopeDatasetCursor current))
          , appErrorRecovery = [RecoveryAction "choose-visible-action" "Choose one of the visible actions." Nothing]
          }
    _ -> Left (appError CorruptData "The pending screen binds one shortcut more than once.")
  let response =
        InteractionResponse
          (envelopeInteractionId original)
          (envelopeRevision original)
          (actionId action)
          (envelopeIntegrityToken original)
          (envelopeDatasetCursor original)
  validation <- validateResponse original current response
  case validation of
    ResponseStale replacement -> pure (GuidedStale replacement)
    ResponseAccepted prior accepted ->
      pure
        ( GuidedAccepted
            (actionId action)
            (outcomeFor (actionId action))
            prior
            accepted
        )
 where
  matchingActions
    | shortcut == "*" = filter actionDefault (envelopeActions original)
    | otherwise = filter ((== shortcut) . actionShortcut) (envelopeActions original)

outcomeFor :: Text -> GuidedOutcome
outcomeFor = \case
  "feed.open" -> OpenFeedInput
  "palette.open" -> OpenCommandPalette
  "next" -> InvokeNext
  identifier -> PendingLaterSlice identifier

unboundMessage :: Text -> InteractionEnvelope -> Text
unboundMessage shortcut envelope
  | shortcut == "n" && any ((== "raw.defer-triage") . actionId) (envelopeActions envelope) =
      "[n] is not available here. To decline this suggestion, use [s]kip."
  | otherwise = "[" <> shortcut <> "] is not available here. Choose a visible action."

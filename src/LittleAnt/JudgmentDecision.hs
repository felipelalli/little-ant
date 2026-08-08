module LittleAnt.JudgmentDecision (
  JudgmentMutation (..),
  decideTriadWinner,
  decideAxisTriadRelations,
  decideImportanceProvisional,
  decideEffortClass,
  decideImpactClass,
  decidePairJudgment,
  decidePhase,
)
where

import Control.Monad (when)
import Data.Map.Strict qualified as Map
import Data.Maybe (isNothing)
import Data.Text (Text)
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Error
import LittleAnt.Event
import LittleAnt.Foundation
import LittleAnt.Id
import LittleAnt.Judgment
import LittleAnt.Model

data JudgmentMutation = JudgmentMutation
  { judgmentMutationCommandId :: UUIDv7
  , judgmentMutationEvents :: [EventDraft]
  }
  deriving stock (Eq, Show)

decidePairJudgment :: State -> Actor -> JudgmentAxis -> UUIDv7 -> UUIDv7 -> JudgmentRelation -> JudgmentProvenance -> JudgmentStatus -> [UUIDv7] -> Text -> Text -> RuntimeFacts -> Either AppError JudgmentMutation
decidePairJudgment state actor axis first second relation provenance status retired context reason facts = do
  (commandId, eventId) <- twoIds facts
  let payload =
        PairJudgmentRecorded
          eventId
          axis
          first
          second
          relation
          provenance
          (initialConfidence provenance)
          factoryJudgmentProfileHash
          context
          reason
          status
          retired
      event = draft facts actor state eventId commandId (PairJudgmentRecordedV1 payload)
  pure (JudgmentMutation commandId [event])

decideTriadWinner :: State -> Actor -> UUIDv7 -> [UUIDv7] -> [UUIDv7] -> RuntimeFacts -> Either AppError JudgmentMutation
decideTriadWinner state actor winner losers retired facts = do
  (commandId, firstEventId, secondEventId) <- threeIds facts
  case losers of
    [firstLoser, secondLoser]
      | winner /= firstLoser && winner /= secondLoser && firstLoser /= secondLoser -> do
          let make eventId loser retiredIds =
                PairJudgmentRecordedV1 $
                  PairJudgmentRecorded
                    eventId
                    ImportanceAxis
                    winner
                    loser
                    MoreThan
                    DirectHuman
                    (initialConfidence DirectHuman)
                    factoryJudgmentProfileHash
                    "contradiction_aid"
                    "triad_winner"
                    JudgmentCurrent
                    retiredIds
              allocated = [commandId, firstEventId, secondEventId]
              makeDraft eventId =
                EventDraft eventId commandId actor (runtimeNow facts) (statePreconditionHash state) allocated
          pure $
            JudgmentMutation
              commandId
              [ makeDraft firstEventId (make firstEventId firstLoser retired)
              , makeDraft secondEventId (make secondEventId secondLoser [])
              ]
    _ -> Left (appError InvalidInput "A contradiction aid requires one winner and exactly two different losers.")

decideAxisTriadRelations :: State -> Actor -> JudgmentAxis -> [(UUIDv7, UUIDv7, JudgmentRelation)] -> [UUIDv7] -> RuntimeFacts -> Either AppError JudgmentMutation
decideAxisTriadRelations state actor axis relations retired facts = do
  when (null relations) $
    Left (appError InvalidInput "A contradiction aid must record at least one pair relation.")
  let subjects = concatMap (\(first, second, _) -> [first, second]) relations
  mapM_ (requireActive state) subjects
  identities <- traverse parseAllocation (take (length relations + 1) (runtimeUUIDs facts))
  case identities of
    commandId : eventIds
      | length eventIds == length relations ->
          let allocated = identities
              makeDraft eventId payload =
                EventDraft eventId commandId actor (runtimeNow facts) (statePreconditionHash state) allocated (PairJudgmentRecordedV1 payload)
              makePayload index eventId (first, second, relation) =
                PairJudgmentRecorded
                  eventId
                  axis
                  first
                  second
                  relation
                  DirectHuman
                  (initialConfidence DirectHuman)
                  factoryJudgmentProfileHash
                  "contradiction_aid"
                  "bounded_recalibration"
                  JudgmentCurrent
                  (if index == (0 :: Int) then retired else [])
              events = zipWith3 (\index eventId relation -> makeDraft eventId (makePayload index eventId relation)) [0 ..] eventIds relations
           in Right (JudgmentMutation commandId events)
    _ -> Left (appError PreconditionFailed "The runtime did not allocate enough UUIDv7 values for the contradiction aid.")
 where
  parseAllocation =
    either
      (const (Left (appError CorruptData "The runtime allocated an invalid UUIDv7.")))
      Right
      . parseUUIDv7
      . unUUIDAllocation

decideImportanceProvisional :: State -> Actor -> UUIDv7 -> Text -> RuntimeFacts -> Either AppError JudgmentMutation
decideImportanceProvisional state actor brickId reason facts = do
  _ <- requireActive state brickId
  (commandId, eventId) <- twoIds facts
  let payload = ImportancePlacementMarked brickId (Provisional reason) reason
  pure (JudgmentMutation commandId [draft facts actor state eventId commandId (ImportancePlacementMarkedV1 payload)])

decidePhase :: State -> Actor -> UUIDv7 -> Maybe WorkPhase -> JudgmentProvenance -> RuntimeFacts -> Either AppError JudgmentMutation
decidePhase state actor brickId phase provenance facts = do
  _ <- requireActive state brickId
  (commandId, eventId) <- twoIds facts
  let payload = PhaseChanged brickId phase provenance
  pure (JudgmentMutation commandId [draft facts actor state eventId commandId (PhaseChangedV1 payload)])

decideImpactClass :: State -> Actor -> UUIDv7 -> Maybe ImpactClass -> ImpactMaturity -> [UUIDv7] -> JudgmentProvenance -> RuntimeFacts -> Either AppError JudgmentMutation
decideImpactClass state actor brickId impact maturity evidence provenance facts = do
  brick <- requireActive state brickId
  if isNothing (brickParent brick)
    then pure ()
    else Left (appError InvalidInput "Impact is classified only on the composition root.")
  (commandId, eventId) <- twoIds facts
  let payload = ImpactClassified brickId impact maturity evidence provenance factoryJudgmentProfileHash
  pure (JudgmentMutation commandId [draft facts actor state eventId commandId (ImpactClassifiedV1 payload)])

decideEffortClass :: State -> Actor -> UUIDv7 -> Maybe EffortClass -> JudgmentProvenance -> RuntimeFacts -> Either AppError JudgmentMutation
decideEffortClass state actor brickId effort provenance facts = do
  _ <- requireActive state brickId
  (commandId, eventId) <- twoIds facts
  let payload = EffortClassified brickId effort provenance factoryJudgmentProfileHash
  pure (JudgmentMutation commandId [draft facts actor state eventId commandId (EffortClassifiedV1 payload)])

requireActive :: State -> UUIDv7 -> Either AppError Brick
requireActive state identity = case Map.lookup identity (stateBricks state) of
  Nothing -> Left (appError NotFound "The selected Brick does not exist.")
  Just brick
    | brickStatus brick /= BrickActive -> Left (appError PreconditionFailed "The selected Brick is not active.")
    | otherwise -> Right brick

twoIds :: RuntimeFacts -> Either AppError (UUIDv7, UUIDv7)
twoIds facts = case runtimeUUIDs facts of
  first : second : _ -> (,) <$> parse first <*> parse second
  _ -> Left (appError PreconditionFailed "The runtime did not allocate enough UUIDv7 values.")
 where
  parse = either (const (Left (appError CorruptData "The runtime allocated an invalid UUIDv7."))) Right . parseUUIDv7 . unUUIDAllocation

threeIds :: RuntimeFacts -> Either AppError (UUIDv7, UUIDv7, UUIDv7)
threeIds facts = case runtimeUUIDs facts of
  first : second : third : _ -> (,,) <$> parse first <*> parse second <*> parse third
  _ -> Left (appError PreconditionFailed "The runtime did not allocate enough UUIDv7 values.")
 where
  parse =
    either
      (const (Left (appError CorruptData "The runtime allocated an invalid UUIDv7.")))
      Right
      . parseUUIDv7
      . unUUIDAllocation

draft :: RuntimeFacts -> Actor -> State -> UUIDv7 -> UUIDv7 -> EventPayload -> EventDraft
draft facts actor state eventId commandId =
  EventDraft eventId commandId actor (runtimeNow facts) (statePreconditionHash state) allocated
 where
  allocated = either (const []) (\(first, second) -> [first, second]) (twoIds facts)

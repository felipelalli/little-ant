module LittleAnt.Planning (
  PlanningExporterIdentity (..),
  buildTaskJugglerPayload,
  factoryEffortMacros,
  taskJugglerProjectionSchema,
)
where

import Control.Monad (unless)
import Data.Aeson
import Data.ByteString.Base64.URL qualified as Base64Url
import Data.List (find)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, isJust, isNothing, mapMaybe)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time
import LittleAnt.Catalog (natureIdentifier)
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Judgment (factoryJudgmentProfileHash)
import LittleAnt.Model
import LittleAnt.Pack.Format (canonicalJsonBytes)
import LittleAnt.Store

taskJugglerProjectionSchema :: Text
taskJugglerProjectionSchema = "little-ant/taskjuggler@1"

data PlanningExporterIdentity = PlanningExporterIdentity
  { planningPublisher :: Text
  , planningPackName :: Text
  , planningPackVersion :: Text
  , planningManifestDigest :: Text
  , planningArchiveDigest :: Text
  , planningComponentId :: Text
  , planningEntrypointDigest :: Text
  , planningSignerFingerprint :: Text
  }
  deriving stock (Eq, Show)

data EffortMacro = EffortMacro
  { macroClass :: EffortClass
  , macroName :: Text
  , macroOptimisticHours :: Int
  , macroRealisticHours :: Int
  , macroPessimisticHours :: Int
  }
  deriving stock (Eq, Show)

factoryEffortMacros :: [(EffortClass, Text, Int, Int, Int)]
factoryEffortMacros =
  [ (VeryEasyEffort, "EFFORT_2H", 2, 3, 4)
  , (EasyEffort, "EFFORT_4H", 4, 6, 8)
  , (NormalEffort, "EFFORT_1D", 8, 12, 16)
  , (ModerateEffort, "EFFORT_2D", 16, 24, 32)
  , (HardEffort, "EFFORT_4D", 32, 48, 64)
  , (VeryHardEffort, "EFFORT_8D", 64, 96, 128)
  , (MiniProjectEffort, "EFFORT_16D", 128, 192, 256)
  , (ProjectEffort, "EFFORT_32D", 256, 384, 512)
  ]

data PlanningWarning = PlanningWarning
  { warningCode :: Text
  , warningMessage :: Text
  , warningBricks :: [UUIDv7]
  }
  deriving stock (Eq, Show)

data CutItem = CutItem
  { cutBrick :: Brick
  , cutEffort :: Maybe EffortMacro
  , cutRemainingEffort :: Maybe RemainingEffortProjection
  , cutDependencies :: [UUIDv7]
  , cutOrder :: Int
  }
  deriving stock (Eq, Show)

data RemainingEffortProjection = RemainingEffortProjection
  { remainingMicrohours :: Integer
  , remainingAsOf :: UTCTime
  , remainingEvidenceIds :: [UUIDv7]
  , remainingRawIds :: [UUIDv7]
  , remainingManifestDigests :: [Text]
  }
  deriving stock (Eq, Show)

buildTaskJugglerPayload ::
  PlanningExporterIdentity ->
  UTCTime ->
  DatasetCursor ->
  State ->
  Value ->
  [Brick] ->
  Either AppError Value
buildTaskJugglerPayload exporter plannedAt cursor state scopeValue selected = do
  let selectedIds = Set.fromList (brickId <$> selected)
      selectedRoots = [brick | brick <- selected, maybe True (`Set.notMember` selectedIds) (brickParent brick)]
      (cutBricks, cutWarnings) = planningCut state selected selectedRoots
  cutWithEffort <- traverse (attachEffort state) cutBricks
  let cutIds = Set.fromList (brickId . fst <$> cutWithEffort)
      dependencyMap = planningDependencies state selectedIds cutIds
      cutItems =
        zipWith
          ( \position (brick, effort) ->
              CutItem
                brick
                effort
                (latestRemainingEffort state (brickId brick))
                (Map.findWithDefault [] (brickId brick) dependencyMap)
                position
          )
          [0 ..]
          cutWithEffort
      warnings =
        normalizeWarnings
          ( factoryCalendarWarning
              : cutWarnings
                <> concatMap (itemWarnings state) cutItems
                <> dependencyWarnings state selectedIds cutIds
          )
      effortProfileWithoutHash =
        object
          [ "id" .= ("little-ant/effort-profile@1" :: Text)
          , "claim_profile_hash" .= factoryJudgmentProfileHash
          , "macros" .= fmap effortMacroValue effortMacros
          ]
  effortProfileBytes <- canonicalJsonBytes effortProfileWithoutHash
  let effortProfile =
        object
          [ "id" .= ("little-ant/effort-profile@1" :: Text)
          , "hash" .= sha256Hex effortProfileBytes
          , "claim_profile_hash" .= factoryJudgmentProfileHash
          , "macros" .= fmap effortMacroValue effortMacros
          ]
      manifest =
        object
          [ "schema" .= ("little-ant/planning-manifest@1" :: Text)
          , "source" .= object ["cursor" .= renderCursor cursor, "hash" .= cursorHash cursor]
          , "scope" .= scopeValue
          , "planned_at" .= utcText plannedAt
          , "roots" .= fmap (renderUUIDv7 . brickId) selectedRoots
          , "cut" .= fmap cutManifestValue cutItems
          , "effort_profile" .= effortProfile
          , "warnings" .= fmap warningValue warnings
          , "resources" .= [factoryResourceValue]
          , "calendars" .= [factoryCalendarValue]
          , "projection" .= object ["schema" .= taskJugglerProjectionSchema]
          , "exporter" .= exporterValue exporter
          ]
  manifestBytes <- canonicalJsonBytes manifest
  let manifestDigest = sha256Hex manifestBytes
  pure $
    object
      [ "manifest" .= manifest
      , "manifest_digest" .= manifestDigest
      , "manifest_jcs_base64url" .= Text.decodeUtf8 (Base64Url.encodeUnpadded manifestBytes)
      , "project"
          .= object
            [ "id" .= ("little_ant" :: Text)
            , "name" .= ("Little Ant planning cut" :: Text)
            , "version" .= ("1.0" :: Text)
            , "start" .= dayText (utctDay plannedAt)
            , "end" .= dayText (addGregorianYearsClip 10 (utctDay plannedAt))
            , "timezone" .= ("UTC" :: Text)
            ]
      , "tasks" .= fmap (taskValue state (length cutItems)) cutItems
      , "warnings" .= fmap warningValue warnings
      ]
 where
  effortMacros = [EffortMacro effortClass name optimistic realistic pessimistic | (effortClass, name, optimistic, realistic, pessimistic) <- factoryEffortMacros]

planningCut :: State -> [Brick] -> [Brick] -> ([Brick], [PlanningWarning])
planningCut state selected roots = foldl' combine ([], []) (walk <$> roots)
 where
  selectedIds = Set.fromList (brickId <$> selected)
  children identity = [brick | brick <- selected, brickParent brick == Just identity]
  walk brick
    | finiteNature (brickNature brick)
    , Map.member (brickId brick) (stateEffortClaims state) =
        ([brick], [])
    | null descendants
    , finiteNature (brickNature brick) =
        ([brick], [])
    | finiteNature (brickNature brick) = foldl' combine ([], []) (walk <$> descendants)
    | otherwise =
        let (items, warnings) = foldl' combine ([], []) (walk <$> descendants)
         in ( items
            , PlanningWarning
                "standing-owner-omitted"
                "A standing Brick is not a finite planning item; its finite descendants remain eligible."
                [brickId brick]
                : warnings
            )
   where
    descendants = filter ((`Set.member` selectedIds) . brickId) (children (brickId brick))
  combine (leftItems, leftWarnings) (rightItems, rightWarnings) = (leftItems <> rightItems, leftWarnings <> rightWarnings)

attachEffort :: State -> Brick -> Either AppError (Brick, Maybe EffortMacro)
attachEffort state brick = case Map.lookup (brickId brick) (stateEffortClaims state) of
  Nothing -> Right (brick, Nothing)
  Just claim -> do
    unless
      (effortClaimProfileHash claim == factoryJudgmentProfileHash)
      ( Left
          ( (appError PreconditionFailed "The planning cut contains an effort claim from an unavailable EffortProfile revision.")
              { appErrorSubject = Just (renderHandle BrickHandle (brickHandle brick))
              , appErrorDetails = ["claim profile: " <> effortClaimProfileHash claim, "available profile: " <> factoryJudgmentProfileHash]
              , appErrorRecovery = [RecoveryAction "review-effort" "Review the Brick effort under the active profile before exporting." (Just ("lant effort " <> renderHandle BrickHandle (brickHandle brick)))]
              }
          )
      )
    case find ((== effortClaimClass claim) . macroClass) effortMacros of
      Nothing -> Left (appError CorruptData "The active EffortProfile does not define the recorded effort class.")
      Just macro -> Right (brick, Just macro)
 where
  effortMacros = [EffortMacro effortClass name optimistic realistic pessimistic | (effortClass, name, optimistic, realistic, pessimistic) <- factoryEffortMacros]

planningDependencies :: State -> Set UUIDv7 -> Set UUIDv7 -> Map UUIDv7 [UUIDv7]
planningDependencies state selectedIds cutIds =
  foldl' addDependency Map.empty activeDependencies
 where
  activeDependencies = filter ((== DependencyActive) . dependencyStatus) (Map.elems (stateDependencies state))
  addDependency accumulator dependency =
    let blocked = representatives state selectedIds cutIds (dependencyBlockedBrick dependency)
        blockers = representatives state selectedIds cutIds (dependencyBlockerBrick dependency)
     in foldl'
          (\current blockedId -> Map.insertWith merge blockedId (filter (/= blockedId) blockers) current)
          accumulator
          blocked
  merge new old = Set.toAscList (Set.fromList (new <> old))

representatives :: State -> Set UUIDv7 -> Set UUIDv7 -> UUIDv7 -> [UUIDv7]
representatives state selectedIds cutIds identity
  | identity `Set.notMember` selectedIds = []
  | Just ancestor <- firstCutAncestor identity = [ancestor]
  | otherwise = Set.toAscList (Set.filter (descendsFrom identity) cutIds)
 where
  firstCutAncestor current
    | current `Set.member` cutIds = Just current
    | otherwise = Map.lookup current (stateBricks state) >>= brickParent >>= firstCutAncestor
  descendsFrom ancestor current
    | current == ancestor = True
    | otherwise = maybe False (descendsFrom ancestor) (Map.lookup current (stateBricks state) >>= brickParent)

dependencyWarnings :: State -> Set UUIDv7 -> Set UUIDv7 -> [PlanningWarning]
dependencyWarnings state selectedIds cutIds = mapMaybe warningFor activeDependencies
 where
  activeDependencies = filter ((== DependencyActive) . dependencyStatus) (Map.elems (stateDependencies state))
  warningFor dependency
    | dependencyBlockedBrick dependency `Set.notMember` selectedIds && dependencyBlockerBrick dependency `Set.notMember` selectedIds = Nothing
    | null blocked || null blockers =
        Just
          ( PlanningWarning
              "dependency-outside-cut"
              "An active dependency has no representable endpoint in this planning cut."
              [dependencyBlockedBrick dependency, dependencyBlockerBrick dependency]
          )
    | otherwise = Nothing
   where
    blocked = representatives state selectedIds cutIds (dependencyBlockedBrick dependency)
    blockers = representatives state selectedIds cutIds (dependencyBlockerBrick dependency)

itemWarnings :: State -> CutItem -> [PlanningWarning]
itemWarnings state item =
  catMaybes
    [ if isNothing (cutEffort item) && isNothing (cutRemainingEffort item)
        then Just (one "missing-effort" "No EffortProfile class is recorded; no planning duration was invented.")
        else Nothing
    , if brickWorkState brick == Wip && isJust (cutEffort item) && isNothing (cutRemainingEffort item)
        then Just (one "wip-total-effort" "The Brick is WIP, but no conservative remaining-effort evidence exists; total effort is exported.")
        else Nothing
    , case (cutRemainingEffort item, Map.lookup (brickId brick) (stateScheduledIntervals state)) of
        (Just _, Nothing) -> Just (one "remaining-effort-point-estimate" "Explicit remaining effort is exported unchanged in every scenario because no remaining-effort uncertainty spread was observed.")
        _ -> Nothing
    , case Map.lookup (brickId brick) (stateTemporalConstraints state) >>= temporalBestBefore of
        Just _ -> Just (one "best-before-advisory" "best_before remains advisory and is not serialized as a hard TaskJuggler constraint.")
        Nothing -> Nothing
    , case (Map.lookup (brickId brick) (stateScheduledIntervals state), isJust (cutEffort item) || isJust (cutRemainingEffort item)) of
        (Just _, True) -> Just (one "fixed-interval-effort" "The exact scheduled interval governs scheduling; effort claims and remaining evidence remain in the manifest for review.")
        _ -> Nothing
    ]
 where
  brick = cutBrick item
  one code message = PlanningWarning code message [brickId brick]

normalizeWarnings :: [PlanningWarning] -> [PlanningWarning]
normalizeWarnings = Map.elems . Map.fromListWith combine . fmap (\warning -> ((warningCode warning, warningMessage warning), warning))
 where
  combine newer older = older{warningBricks = Set.toAscList (Set.fromList (warningBricks older <> warningBricks newer))}

factoryCalendarWarning :: PlanningWarning
factoryCalendarWarning =
  PlanningWarning
    "factory-planning-resource"
    "Planning uses the explicit factory assumption of one UTC resource, Monday-Friday 09:00-15:00, with a 6-hour daily maximum."
    []

finiteNature :: BrickNature -> Bool
finiteNature = \case
  AtomicTask -> True
  Project -> True
  FiniteChecklist -> True
  ScheduledCommitment -> True
  Collection -> False
  Repeatable -> False
  LivingChecklist -> False
  RecurringObligation -> False
  Habit -> False

taskValue :: State -> Int -> CutItem -> Value
taskValue state totalItems item =
  object $
    [ "id" .= taskId (brickId brick)
    , "brick_id" .= renderUUIDv7 (brickId brick)
    , "handle" .= renderHandle BrickHandle (brickHandle brick)
    , "title" .= brickTitle brick
    , "nature" .= natureIdentifier (brickNature brick)
    , "order" .= cutOrder item
    , "taskjuggler_priority" .= taskPriority totalItems (cutOrder item)
    , "work_state" .= workStateText (brickWorkState brick)
    , "dependencies" .= fmap taskId (cutDependencies item)
    ]
      <> maybe [] (pure . ("effort" .=) . effortMacroValue) (cutEffort item)
      <> maybe [] (pure . ("remaining_effort" .=) . remainingEffortValue) (cutRemainingEffort item)
      <> maybe [] temporalFields (Map.lookup (brickId brick) (stateTemporalConstraints state))
      <> maybe [] (pure . ("scheduled_interval" .=) . intervalValue) (Map.lookup (brickId brick) (stateScheduledIntervals state))
 where
  brick = cutBrick item
  temporalFields constraints =
    catMaybes
      [ ("not_before" .=) . zonedValue <$> temporalNotBefore constraints
      , ("best_before" .=) . zonedValue <$> temporalBestBefore constraints
      , ("deadline" .=) . zonedValue <$> temporalDeadline constraints
      ]

cutManifestValue :: CutItem -> Value
cutManifestValue item =
  object $
    [ "brick_id" .= renderUUIDv7 (brickId brick)
    , "task_id" .= taskId (brickId brick)
    , "order" .= cutOrder item
    , "dependencies" .= fmap taskId (cutDependencies item)
    ]
      <> maybe [] (pure . ("effort_macro" .=) . macroName) (cutEffort item)
      <> maybe [] (pure . ("remaining_effort" .=) . remainingEffortValue) (cutRemainingEffort item)
 where
  brick = cutBrick item

effortMacroValue :: EffortMacro -> Value
effortMacroValue macro =
  object
    [ "class" .= effortClassText (macroClass macro)
    , "macro" .= macroName macro
    , "optimistic_hours" .= macroOptimisticHours macro
    , "realistic_hours" .= macroRealisticHours macro
    , "pessimistic_hours" .= macroPessimisticHours macro
    ]

latestRemainingEffort :: State -> UUIDv7 -> Maybe RemainingEffortProjection
latestRemainingEffort state brickIdentity = do
  latestAsOf <- maximumMaybe (effortActualAsOf <$> relevant)
  let latest = filter ((== latestAsOf) . effortActualAsOf) relevant
  remaining <- case latest of
    first : rest -> do
      value <- effortActualRemainingMicrohours first
      if all ((== Just value) . effortActualRemainingMicrohours) rest then Just value else Nothing
    [] -> Nothing
  pure
    RemainingEffortProjection
      { remainingMicrohours = remaining
      , remainingAsOf = latestAsOf
      , remainingEvidenceIds = Set.toAscList (Set.fromList (effortActualEvidenceId <$> latest))
      , remainingRawIds = Set.toAscList (Set.fromList (effortActualRaw <$> latest))
      , remainingManifestDigests = Set.toAscList (Set.fromList (effortActualPlanningManifestDigest <$> latest))
      }
 where
  relevant = filter ((== brickIdentity) . effortActualBrick) (Map.elems (stateEffortActualEvidence state))
  maximumMaybe = \case
    [] -> Nothing
    values -> Just (maximum values)

remainingEffortValue :: RemainingEffortProjection -> Value
remainingEffortValue projection =
  object
    [ "microhours" .= Text.pack (show (remainingMicrohours projection))
    , "as_of" .= utcText (remainingAsOf projection)
    , "evidence_ids" .= fmap renderUUIDv7 (remainingEvidenceIds projection)
    , "raw_ids" .= fmap renderUUIDv7 (remainingRawIds projection)
    , "planning_manifest_sha256" .= remainingManifestDigests projection
    ]

warningValue :: PlanningWarning -> Value
warningValue warning =
  object $
    [ "code" .= warningCode warning
    , "message" .= warningMessage warning
    ]
      <> ["brick_ids" .= fmap renderUUIDv7 (warningBricks warning) | not (null (warningBricks warning))]

exporterValue :: PlanningExporterIdentity -> Value
exporterValue exporter =
  object
    [ "publisher" .= planningPublisher exporter
    , "pack" .= planningPackName exporter
    , "pack_version" .= planningPackVersion exporter
    , "pack_manifest_digest" .= planningManifestDigest exporter
    , "pack_archive_digest" .= planningArchiveDigest exporter
    , "component" .= planningComponentId exporter
    , "entrypoint_sha256" .= planningEntrypointDigest exporter
    , "signer_fingerprint" .= planningSignerFingerprint exporter
    ]

factoryResourceValue :: Value
factoryResourceValue =
  object
    [ "id" .= ("me" :: Text)
    , "name" .= ("Little Ant user" :: Text)
    , "calendar" .= ("factory_utc" :: Text)
    , "daily_max_hours" .= (6 :: Int)
    ]

factoryCalendarValue :: Value
factoryCalendarValue =
  object
    [ "id" .= ("factory_utc" :: Text)
    , "timezone" .= ("UTC" :: Text)
    , "working_days" .= (["mon", "tue", "wed", "thu", "fri"] :: [Text])
    , "starts_at" .= ("09:00" :: Text)
    , "ends_at" .= ("15:00" :: Text)
    ]

intervalValue :: ScheduledInterval -> Value
intervalValue interval =
  object
    [ "starts_at" .= zonedValue (scheduledStartsAt interval)
    , "ends_at" .= zonedValue (scheduledEndsAt interval)
    ]

zonedValue :: ZonedInstant -> Value
zonedValue instant = object ["utc" .= utcText (zonedInstantUtc instant), "zone" .= zonedInstantZone instant]

taskId :: UUIDv7 -> Text
taskId = ("t_" <>) . Text.filter (/= '-') . renderUUIDv7

taskPriority :: Int -> Int -> Int
taskPriority totalItems position = max 100 (1000 - position * 900 `div` max 1 (totalItems - 1))

effortClassText :: EffortClass -> Text
effortClassText = \case
  VeryEasyEffort -> "VERY_EASY"
  EasyEffort -> "EASY"
  NormalEffort -> "NORMAL"
  ModerateEffort -> "MODERATE"
  HardEffort -> "HARD"
  VeryHardEffort -> "VERY_HARD"
  MiniProjectEffort -> "MINI_PROJECT"
  ProjectEffort -> "PROJECT"

workStateText :: WorkState -> Text
workStateText = Text.toLower . Text.pack . show

utcText :: UTCTime -> Text
utcText = Text.pack . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ"

dayText :: Day -> Text
dayText = Text.pack . formatTime defaultTimeLocale "%Y-%m-%d"

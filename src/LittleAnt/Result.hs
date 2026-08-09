module LittleAnt.Result (
  CommandResult (..),
  DiagnosticCheck (..),
  HistoryEntry (..),
  SearchHit (..),
  ListRow (..),
  RawProjection (..),
  UndoClass (..),
  resultCursor,
)
where

import Data.Aeson
import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Time (UTCTime)
import LittleAnt.Error
import LittleAnt.Export
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Store

data UndoClass = CreateUndo
  deriving stock (Eq, Ord, Show)

data RawProjection = RawProjection
  { projectedRawId :: UUIDv7
  , projectedRawHandle :: Handle
  , projectedRawPreview :: Text
  , projectedRawOriginal :: Maybe Text
  , projectedRawCreatedAt :: Maybe UTCTime
  , projectedRawStatus :: Maybe Text
  }
  deriving stock (Eq, Show)

data HistoryEntry = HistoryEntry
  { historyCommandId :: UUIDv7
  , historyRecordedAt :: UTCTime
  , historyActor :: Actor
  , historyEventCount :: Int
  , historyEventTypes :: [Text]
  }
  deriving stock (Eq, Show)

data SearchHit = SearchHit
  { searchHitKind :: Text
  , searchHitHandle :: Text
  , searchHitTitle :: Text
  , searchHitDetails :: Text
  }
  deriving stock (Eq, Show)

data ListRow = ListRow
  { listEntryHandle :: Text
  , listEntryTitle :: Text
  , listEntryDetails :: Text
  }
  deriving stock (Eq, Show)

data DiagnosticCheck = DiagnosticCheck
  { diagnosticCheckName :: Text
  , diagnosticCheckPassed :: Bool
  , diagnosticCheckSummary :: Text
  , diagnosticCheckProblem :: Maybe AppError
  }
  deriving stock (Eq, Show)

data CommandResult
  = NextResult
      { resultDatasetCursor :: DatasetCursor
      , resultInteraction :: InteractionEnvelope
      , resultDryRun :: Bool
      }
  | ConfigurationResult
      { resultDatasetCursor :: DatasetCursor
      , resultAdministrationAction :: Text
      , resultSelectedProfile :: Maybe Text
      , resultAvailableProfiles :: [Text]
      , resultConfigurationFacts :: Map Text Text
      , resultDryRun :: Bool
      }
  | RespondResult
      { resultDatasetCursor :: DatasetCursor
      , resultInteraction :: InteractionEnvelope
      , resultMutationCommandId :: Maybe UUIDv7
      , resultDryRun :: Bool
      }
  | FeedResult
      { resultCommandId :: UUIDv7
      , resultDatasetCursor :: DatasetCursor
      , resultRaw :: RawProjection
      , resultUndoClass :: UndoClass
      , resultUndoToken :: Text
      , resultInteraction :: InteractionEnvelope
      , resultDryRun :: Bool
      }
  | ShowRawResult
      { resultDatasetCursor :: DatasetCursor
      , resultRaw :: RawProjection
      , resultDryRun :: Bool
      }
  | UndoResult
      { resultCommandId :: UUIDv7
      , resultTargetCommandId :: UUIDv7
      , resultDatasetCursor :: DatasetCursor
      , resultRaw :: RawProjection
      , resultRedoToken :: Maybe Text
      , resultWasRedo :: Bool
      , resultInteraction :: InteractionEnvelope
      , resultDryRun :: Bool
      }
  | GrammarResult
      { resultDatasetCursor :: DatasetCursor
      , resultGrammarNames :: [Text]
      , resultDryRun :: Bool
      }
  | TickResult
      { resultDatasetCursor :: DatasetCursor
      , resultReleasedOccurrences :: Int
      , resultOpenedHabitWindows :: Int
      , resultSettledHabitUnits :: Int
      , resultDryRun :: Bool
      }
  | HistoryResult
      { resultDatasetCursor :: DatasetCursor
      , resultHistory :: [HistoryEntry]
      , resultDryRun :: Bool
      }
  | SearchResult
      { resultDatasetCursor :: DatasetCursor
      , resultSearchQuery :: Text
      , resultSearchHits :: [SearchHit]
      , resultDryRun :: Bool
      }
  | ListResult
      { resultDatasetCursor :: DatasetCursor
      , resultListName :: Text
      , resultListEntries :: [ListRow]
      , resultDryRun :: Bool
      }
  | DoctorResult
      { resultDatasetCursor :: DatasetCursor
      , resultDatasetHealthy :: Bool
      , resultValidatedEvents :: Integer
      , resultDiagnosticChecks :: [DiagnosticCheck]
      , resultDryRun :: Bool
      }
  | RepairResult
      { resultDatasetCursor :: DatasetCursor
      , resultRepairStage :: Text
      , resultInteraction :: InteractionEnvelope
      , resultDryRun :: Bool
      }
  | ExportResult
      { resultDatasetCursor :: DatasetCursor
      , resultExporter :: ExportDescriptor
      , resultExportScope :: Text
      , resultExportMediaType :: Text
      , resultExportSuggestedFilename :: FilePath
      , resultExportDestination :: Maybe FilePath
      , resultExportByteCount :: Int
      , resultExportDigest :: Text
      , resultExportWarnings :: [Text]
      , resultExportMetadata :: Map Text Text
      , resultExportBytes :: Maybe ByteString
      , resultDryRun :: Bool
      }
  deriving stock (Eq, Show)

resultCursor :: CommandResult -> DatasetCursor
resultCursor = resultDatasetCursor

instance ToJSON UndoClass where toJSON CreateUndo = toJSON ("create" :: Text)
instance ToJSON HistoryEntry where
  toJSON history =
    object
      [ "command_id" .= renderUUIDv7 (historyCommandId history)
      , "recorded_at" .= historyRecordedAt history
      , "actor" .= historyActor history
      , "event_count" .= historyEventCount history
      , "event_types" .= historyEventTypes history
      ]

instance ToJSON SearchHit where
  toJSON hit =
    object
      [ "kind" .= searchHitKind hit
      , "handle" .= searchHitHandle hit
      , "title" .= searchHitTitle hit
      , "details" .= searchHitDetails hit
      ]

instance ToJSON ListRow where
  toJSON entry =
    object
      [ "handle" .= listEntryHandle entry
      , "title" .= listEntryTitle entry
      , "details" .= listEntryDetails entry
      ]

instance ToJSON DiagnosticCheck where
  toJSON check =
    object $
      [ "name" .= diagnosticCheckName check
      , "status" .= (if diagnosticCheckPassed check then ("pass" :: Text) else "fail")
      , "summary" .= diagnosticCheckSummary check
      ]
        <> maybe [] (pure . ("problem" .=)) (diagnosticCheckProblem check)

instance ToJSON RawProjection where
  toJSON raw =
    object $
      [ "id" .= renderUUIDv7 (projectedRawId raw)
      , "handle" .= renderHandle RawHandle (projectedRawHandle raw)
      , "preview" .= projectedRawPreview raw
      ]
        <> maybe [] (pure . ("original" .=)) (projectedRawOriginal raw)
        <> maybe [] (pure . ("created_at" .=)) (projectedRawCreatedAt raw)
        <> maybe [] (pure . ("status" .=)) (projectedRawStatus raw)
instance ToJSON CommandResult where
  toJSON = \case
    NextResult cursor interaction dryRun ->
      object $
        [ "schema" .= ("little-ant/next@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "interaction" .= interaction
        ]
          <> dryRunPair dryRun
    ConfigurationResult cursor action selected profiles facts dryRun ->
      object $
        [ "schema" .= ("little-ant/configuration@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "action" .= action
        ]
          <> maybe [] (pure . ("selected_profile" .=)) selected
          <> [("profiles" .= profiles) | not (null profiles)]
          <> [("facts" .= facts) | not (null facts)]
          <> dryRunPair dryRun
    TickResult cursor releases windows outcomes dryRun ->
      object $
        [ "schema" .= ("little-ant/tick@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "released_occurrences" .= releases
        , "opened_habit_windows" .= windows
        , "settled_habit_units" .= outcomes
        ]
          <> dryRunPair dryRun
    HistoryResult cursor history dryRun ->
      object $
        [ "schema" .= ("little-ant/history@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "history" .= history
        ]
          <> dryRunPair dryRun
    SearchResult cursor query hits dryRun ->
      object $
        [ "schema" .= ("little-ant/search@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "query" .= query
        , "hits" .= hits
        ]
          <> dryRunPair dryRun
    ListResult cursor name entries dryRun ->
      object $
        [ "schema" .= ("little-ant/list@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "list" .= name
        , "entries" .= entries
        ]
          <> dryRunPair dryRun
    DoctorResult cursor healthy validated checks dryRun ->
      object $
        [ "schema" .= ("little-ant/doctor@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "healthy" .= healthy
        , "validated_events" .= validated
        , "checks" .= checks
        ]
          <> dryRunPair dryRun
    RepairResult cursor stage interaction dryRun ->
      object $
        [ "schema" .= ("little-ant/repair@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "stage" .= stage
        , "interaction" .= interaction
        ]
          <> dryRunPair dryRun
    ExportResult cursor exporter scope mediaType suggested destination byteCount digest warnings metadata _ dryRun ->
      object $
        [ "schema" .= ("little-ant/export@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "exporter" .= exporter
        , "scope" .= scope
        , "media_type" .= mediaType
        , "suggested_filename" .= suggested
        , "byte_count" .= byteCount
        , "sha256" .= digest
        ]
          <> maybe [] (pure . ("created_path" .=)) destination
          <> ["warnings" .= warnings | not (null warnings)]
          <> ["metadata" .= metadata | not (Map.null metadata)]
          <> dryRunPair dryRun
    RespondResult cursor interaction commandId dryRun ->
      object $
        [ "schema" .= ("little-ant/respond@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "interaction" .= interaction
        ]
          <> maybe [] (pure . ("command_id" .=) . renderUUIDv7) commandId
          <> dryRunPair dryRun
    FeedResult commandId cursor raw undoClass undoToken interaction dryRun ->
      object $
        [ "schema" .= ("little-ant/feed@1" :: Text)
        , "command_id" .= renderUUIDv7 commandId
        , "dataset_cursor" .= renderCursor cursor
        , "raw" .= raw
        , "undo_class" .= undoClass
        , "undo_token" .= undoToken
        , "interaction" .= interaction
        ]
          <> dryRunPair dryRun
    ShowRawResult cursor raw dryRun ->
      object $
        [ "schema" .= ("little-ant/show-raw@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "raw" .= raw
        ]
          <> dryRunPair dryRun
    UndoResult commandId target cursor raw redoToken wasRedo interaction dryRun ->
      object $
        [ "schema" .= (if wasRedo then ("little-ant/redo@1" :: Text) else "little-ant/undo@1")
        , "command_id" .= renderUUIDv7 commandId
        , "target_command_id" .= renderUUIDv7 target
        , "dataset_cursor" .= renderCursor cursor
        , "raw" .= raw
        , "interaction" .= interaction
        ]
          <> maybe [] (pure . ("redo_token" .=)) redoToken
          <> dryRunPair dryRun
    GrammarResult cursor names dryRun ->
      object $
        [ "schema" .= ("little-ant/grammar@1" :: Text)
        , "dataset_cursor" .= renderCursor cursor
        , "grammars" .= names
        ]
          <> dryRunPair dryRun
   where
    dryRunPair True = ["dry_run" .= True]; dryRunPair False = []

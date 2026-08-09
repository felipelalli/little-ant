module LittleAnt.Projection (
  rawProjection,
  renderCommandResult,
  renderEnvelope,
  renderEnvelopeAtWidth,
  renderError,
)
where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Error
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Model
import LittleAnt.Result
import LittleAnt.Surface

rawProjection :: Bool -> Raw -> RawProjection
rawProjection complete raw =
  RawProjection
    { projectedRawId = rawId raw
    , projectedRawHandle = rawHandle raw
    , projectedRawPreview = preview (rawOriginal raw)
    , projectedRawOriginal = if complete then Just (rawOriginal raw) else Nothing
    , projectedRawCreatedAt = if complete then Just (rawCreatedAt raw) else Nothing
    , projectedRawStatus = if complete then Just (statusText (rawStatus raw)) else Nothing
    }
 where
  statusText RawAwaitingReview = "awaiting_review"
  statusText RawRetracted = "retracted"
  statusText RawArchived = "archived"

renderEnvelope :: InteractionEnvelope -> ScreenModel
renderEnvelope = renderEnvelopeAtWidth 80

renderEnvelopeAtWidth :: Int -> InteractionEnvelope -> ScreenModel
renderEnvelopeAtWidth requestedWidth envelope =
  ScreenModel
    (mainLines <> actionLines <> [blank] <> footerLines)
    Nothing
 where
  width = max 20 requestedWidth
  content = envelopeContent envelope
  mainLines =
    textBlock (contentHeading content)
      <> maybe [] textBlock (contentSubject content)
      <> concatMap textBlock (contentBody content)
      <> maybe [] textBlock (contentQuestion content)
  textBlock text = fmap (pure . normal) (wrapText width text) <> [blank]
  actions = envelopeActions envelope
  primaryActions = filter ((/= "/") . actionShortcut) actions
  paletteActions = filter ((== "/") . actionShortcut) actions
  firstRowSpacing = case envelopeOpportunity envelope of
    PristineOpportunity -> 3
    _ -> 4
  firstRow = joinActions firstRowSpacing primaryActions
  primaryRows
    | Text.length (plainLine firstRow) <= width = [firstRow]
    | otherwise = fmap actionLine primaryActions
  actionLines = primaryRows <> fmap actionLine paletteActions
  footerLines =
    [dimLine (Text.replicate (min 40 width) "─")]
      <> noticeLines (envelopeFooter envelope)
      <> renderFooterAtWidth width (envelopeFooter envelope)
  noticeLines footer = case footerNotice footer of
    Nothing -> []
    Just summary ->
      [ [dim "⚠ ", dim summary, dim (if footerNoticeCount footer > 1 then " · +" <> tshow (footerNoticeCount footer - 1) <> " notices" else "")]
      ]

renderFooterAtWidth :: Int -> Footer -> [ScreenLine]
renderFooterAtWidth width footer =
  [ [dim ". ", dim (footerParent footer)]
  , [dim "  ", dim (footerDomain footer)]
  , [dim (". " <> footerTimeLabel footer <> ": "), normal (footerTimeValue footer)]
  , [dim (Text.replicate nowIndent " " <> "Now: "), dim (footerNow footer)]
  ]
    <> countLines
    <> [[dim "  mode: ", normal (footerMode footer), dim ", focus: ", normal (footerFocus footer)]]
 where
  nowIndent = max 2 (min (Text.length (footerTimeLabel footer) + 3) (width - Text.length ("Now: " <> footerNow footer)))
  completeCountLine =
    [ dim ". "
    , normal (tshow (footerBrickCount footer))
    , dim " bricks, "
    , normal (tshow (footerRawCount footer))
    , dim " raws, "
    , normal (tshow (footerReviewCount footer))
    , dim " reviews"
    ]
  countLines
    | Text.length (plainLine completeCountLine) <= width = [completeCountLine]
    | otherwise =
        [
          [ dim ". "
          , normal (tshow (footerBrickCount footer))
          , dim " bricks, "
          , normal (tshow (footerRawCount footer))
          , dim " raws,"
          ]
        , [dim "  ", normal (tshow (footerReviewCount footer)), dim " reviews"]
        ]

renderCommandResult :: CommandResult -> Text
renderCommandResult = \case
  NextResult _ interaction dryRun -> dryRunFact dryRun <> renderPlain (renderEnvelope interaction)
  RespondResult _ interaction _ dryRun -> dryRunFact dryRun <> renderPlain (renderEnvelope interaction)
  FeedResult _ _ _ _ _ interaction dryRun -> dryRunFact dryRun <> renderPlain (renderEnvelope interaction)
  ShowRawResult _ raw dryRun ->
    dryRunFact dryRun
      <> rawCitation raw
      <> maybe "" ("\n\nOriginal:\n" <>) (projectedRawOriginal raw)
      <> maybe "" ("\nStatus: " <>) (projectedRawStatus raw)
  SearchResult _ query hits dryRun ->
    dryRunFact dryRun
      <> "Search: "
      <> query
      <> "\n"
      <> ( if null hits
            then "No matches."
            else Text.unlines [searchHitLine hit | hit <- hits]
         )
  UndoResult _ _ _ raw redoToken wasRedo interaction dryRun ->
    dryRunFact dryRun
      <> (if wasRedo then "Feed restored: " else "Feed undone: ")
      <> rawCitation raw
      <> (if wasRedo then "" else maybe "" (const "\nRedo is available.") redoToken)
      <> "\n\n"
      <> renderPlain (renderEnvelope interaction)
  ListResult _ name rows dryRun ->
    dryRunFact dryRun
      <> name
      <> ":\n"
      <> ( if null rows
            then "  (empty)"
            else Text.unlines ["- " <> renderListRow row | row <- rows]
         )
  GrammarResult _ names dryRun ->
    dryRunFact dryRun
      <> "Screen grammars:\n"
      <> Text.unlines ["- " <> name | name <- names]
  ConfigurationResult _ action selected profiles facts dryRun ->
    dryRunFact dryRun
      <> administrationHeading action
      <> maybe "" ("\nSelected profile: " <>) selected
      <> (if null profiles then "" else "\nProfiles:\n" <> Text.unlines ["- " <> profile | profile <- profiles])
      <> (if Map.null facts then "" else "\n" <> Text.unlines [key <> ": " <> value | (key, value) <- Map.toAscList facts])
  TickResult _ released opened settled dryRun ->
    dryRunFact dryRun
      <> "Tick complete: "
      <> tshow released
      <> " occurrences released, "
      <> tshow opened
      <> " habit windows opened, "
      <> tshow settled
      <> " habit units settled."
  HistoryResult _ history dryRun ->
    dryRunFact dryRun
      <> "History:"
      <> ( if null history
             then "\n(no events)"
             else "\n" <> Text.unlines (fmap formatHistoryLine (zip [1 :: Int ..] history))
         )
   where
    formatHistoryLine (index, entry) =
      "  "
        <> tshow index
        <> ". "
        <> renderUUIDv7 (historyCommandId entry)
        <> " "
        <> Text.intercalate ", " (historyEventTypes entry)
        <> " ("
        <> tshow (historyEventCount entry)
        <> " events)"

renderError :: AppError -> Text
renderError problem =
  "Error ["
    <> errorCodeText (appErrorCode problem)
    <> "]: "
    <> appErrorMessage problem
    <> maybe "" ("\nSubject: " <>) (appErrorSubject problem)
    <> Text.concat ["\n- " <> recoveryActionLabel action | action <- appErrorRecovery problem]

actionLine :: Action -> ScreenLine
actionLine action = [normal (if actionDefault action then "*" else " "), dim "[", accent (actionShortcut action), dim "]", normal (labelSuffix action)]
 where
  labelSuffix current
    | actionShortcut current == "/" = " " <> actionLabel current
    | otherwise = case Text.breakOn (actionShortcut current) (actionLabel current) of
        (before, after)
          | Text.null after -> " " <> actionLabel current
          | otherwise -> before <> Text.drop 1 after

joinActions :: Int -> [Action] -> ScreenLine
joinActions spacing = intercalateSpans [normal (Text.replicate spacing " ")] . fmap actionLine
intercalateSpans :: [value] -> [[value]] -> [value]
intercalateSpans _ [] = []
intercalateSpans separator (first : rest) = first <> concatMap (separator <>) rest

wrapText :: Int -> Text -> [Text]
wrapText width text
  | Text.length text <= width = [text]
  | otherwise = go [] "" (Text.words text)
 where
  go result current [] = result <> [current | not (Text.null current)]
  go result current (word : rest)
    | Text.null current = go result word rest
    | Text.length current + 1 + Text.length word <= width = go result (current <> " " <> word) rest
    | otherwise = go (result <> [current]) word rest

preview :: Text -> Text
preview = Text.take 80 . Text.unwords . Text.words
rawCitation :: RawProjection -> Text
rawCitation raw = renderHandle RawHandle (projectedRawHandle raw) <> " \"" <> projectedRawPreview raw <> "\""
searchHitLine :: SearchHit -> Text
searchHitLine hit =
  "[" <> searchHitKind hit <> "] " <> searchHitHandle hit <> " " <> searchHitTitle hit <> " — " <> searchHitDetails hit

renderListRow :: ListRow -> Text
renderListRow row =
  listEntryHandle row <> " " <> listEntryTitle row <> (if Text.null (listEntryDetails row) then "" else " · " <> listEntryDetails row)

dryRunFact :: Bool -> Text
dryRunFact True = "Dry run: nothing was recorded.\n\n"
dryRunFact False = ""
administrationHeading :: Text -> Text
administrationHeading action = case action of
  "profile_list" -> "Profiles"
  "profile_show" -> "Profile"
  "profile_create" -> "Profile created."
  "profile_create_preview" -> "Profile creation preview."
  "profile_use" -> "Profile selected for future starts."
  "profile_use_preview" -> "Profile selection preview."
  "config_show" -> "Configuration"
  "config_paths" -> "Resolved paths"
  "config_validate" -> "Configuration is valid."
  _ -> action
normal :: Text -> Span
normal = Span Normal
dim :: Text -> Span
dim = Span Dim
accent :: Text -> Span
accent = Span Accent
blank :: ScreenLine
blank = []
dimLine :: Text -> ScreenLine
dimLine text = [dim text]
tshow :: Int -> Text
tshow = Text.pack . show

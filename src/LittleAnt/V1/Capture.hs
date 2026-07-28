{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Explicit routed capture and deterministic duplicate suspicion.
--
-- Capture text is retained verbatim before any work entity is created.  Text
-- fingerprints are rebuildable projections only: a suspicion never aliases,
-- merges, removes, or redirects an opaque entity identity.  A separate,
-- attributed decision is required before one canonical Raw, Brick, or
-- ListEntry is materialized.
module LittleAnt.V1.Capture
  ( CaptureContext (..)
  , CaptureDecisionResult (..)
  , CaptureDraft (..)
  , CaptureError (..)
  , CaptureIntent (..)
  , CaptureIntentId (..)
  , CaptureRoute (..)
  , CaptureState (..)
  , CaptureStatus (..)
  , DuplicateDecision (..)
  , DuplicateDecisionId (..)
  , DuplicateDecisionKind (..)
  , DuplicateMatch (..)
  , DuplicateSuspicion (..)
  , DuplicateSuspicionId (..)
  , DuplicateTargetKind (..)
  , beginCapture
  , cancelCapture
  , confirmDuplicateDecision
  , confirmSeparateCapture
  , duplicateMatcherRank
  , emptyCaptureState
  , matchingFingerprints
  , selectDuplicateSuspicion
  , validateCaptureState
  ) where

import Control.Applicative ((<|>))
import Control.Monad (unless, when)
import Data.Aeson
  (FromJSON (parseJSON), FromJSONKey, ToJSON (toJSON), ToJSONKey, Value (..),
   defaultOptions, genericParseJSON, genericToJSON, withText)
import qualified Data.Aeson.Types as AesonTypes
import Data.Char (isAlphaNum, toLower)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (catMaybes, fromMaybe, isJust, mapMaybe)
import Data.Ord (Down (..))
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Coordination (CoordinationState (..))
import LittleAnt.V1.Domain
  (Authority, Brick (..), BrickBehavior, BrickDraft (..), BrickId,
   BrickStatus (..), BrickTemplate (..), CanonicalText (..), DomainState (..),
   ListEntry (..), ListEntryDraft (..), ListEntryId, ListEntryStatus (..),
   behaviorId, canonicalEnglishText, ordinaryBrickDraft,
   standardV1, templateBehavior)
import LittleAnt.V1.Execution (ExecutionState (..))
import LittleAnt.V1.Material
  (MaterialError, MaterialState (..), Raw (..), RawId, RawLinkRole (Evidence),
   ReviewDispositionKind (Linked), captureInlineRaw, linkDerivedRaw,
   linkRawToBrick, linkRawToEntry, registerMaterialBrick,
   registerMaterialListEntry, reviewRaw)
import qualified LittleAnt.V1.Priority as Priority
import LittleAnt.V1.Standing
  (StandingError, StandingState (..), addStandingListEntry,
   createStandingBrick, validateStandingState)

------------------------------------------------------------
-- Vocabulary and canonical capture state
------------------------------------------------------------

data CaptureRoute
  = PreserveRaw
  | CreateBrick
  | CreateListEntry
  | InstantiateTemplate
  | EnrichExisting
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data CaptureStatus = CapturePendingReview | CaptureRouted | CaptureCancelled
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data DuplicateTargetKind = DuplicateBrick | DuplicateListEntry | DuplicateRaw
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

data DuplicateDecisionKind = DuplicateReuse | DuplicateEnrich | DuplicateSeparate
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON CaptureRoute where toJSON = String . captureRouteText
instance FromJSON CaptureRoute where
  parseJSON = parseEnum "CaptureRoute" captureRouteText
instance ToJSON CaptureStatus where toJSON = String . captureStatusText
instance FromJSON CaptureStatus where
  parseJSON = parseEnum "CaptureStatus" captureStatusText
instance ToJSON DuplicateTargetKind where toJSON = String . duplicateTargetKindText
instance FromJSON DuplicateTargetKind where
  parseJSON = parseEnum "DuplicateTargetKind" duplicateTargetKindText
instance ToJSON DuplicateDecisionKind where toJSON = String . duplicateDecisionKindText
instance FromJSON DuplicateDecisionKind where
  parseJSON = parseEnum "DuplicateDecisionKind" duplicateDecisionKindText

parseEnum :: (Bounded value, Enum value) =>
  String -> (value -> Text) -> Value -> AesonTypes.Parser value
parseEnum name render = withText name $ \candidate ->
  maybe (fail ("unknown " <> name <> ": " <> Text.unpack candidate)) pure
    (lookup candidate [(render value, value) | value <- [minBound .. maxBound]])

captureRouteText :: CaptureRoute -> Text
captureRouteText route = case route of
  PreserveRaw -> "preserve_raw"
  CreateBrick -> "create_brick"
  CreateListEntry -> "create_list_entry"
  InstantiateTemplate -> "instantiate_template"
  EnrichExisting -> "enrich_existing"

captureStatusText :: CaptureStatus -> Text
captureStatusText status = case status of
  CapturePendingReview -> "pending_review"
  CaptureRouted -> "routed"
  CaptureCancelled -> "cancelled"

duplicateTargetKindText :: DuplicateTargetKind -> Text
duplicateTargetKindText kind = case kind of
  DuplicateBrick -> "brick"
  DuplicateListEntry -> "list_entry"
  DuplicateRaw -> "raw"

duplicateDecisionKindText :: DuplicateDecisionKind -> Text
duplicateDecisionKindText decision = case decision of
  DuplicateReuse -> "reuse"
  DuplicateEnrich -> "enrich"
  DuplicateSeparate -> "separate"

newtype CaptureIntentId = CaptureIntentId {unCaptureIntentId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype DuplicateSuspicionId = DuplicateSuspicionId {unDuplicateSuspicionId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)
newtype DuplicateDecisionId = DuplicateDecisionId {unDuplicateDecisionId :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON, ToJSONKey, FromJSONKey)

data CaptureIntent = CaptureIntent
  { captureIntentId :: CaptureIntentId
  , captureIntentOriginalText :: Text
  , captureIntentCanonicalEnglish :: Maybe Text
  , captureIntentNormalizationAuthority :: Maybe Authority
  , captureIntentProposedRoute :: Maybe CaptureRoute
  , captureIntentProposedParent :: Maybe BrickId
  , captureIntentProposedOwner :: Maybe BrickId
  , captureIntentProposedBehavior :: Maybe BrickBehavior
  , captureIntentProposedTemplate :: Maybe BrickTemplate
  , captureIntentStatus :: CaptureStatus
  , captureIntentCreatedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data DuplicateMatch = DuplicateMatch
  { duplicateMatchTargetKind :: DuplicateTargetKind
  , duplicateMatchTargetBrick :: Maybe BrickId
  , duplicateMatchTargetEntry :: Maybe ListEntryId
  , duplicateMatchTargetRaw :: Maybe RawId
  , duplicateMatchStrength :: Double
  , duplicateMatchReasons :: [Text]
  }
  deriving stock (Eq, Show, Generic)

data DuplicateSuspicion = DuplicateSuspicion
  { duplicateSuspicionId :: DuplicateSuspicionId
  , duplicateSuspicionCapture :: CaptureIntentId
  , duplicateSuspicionTargetKind :: DuplicateTargetKind
  , duplicateSuspicionTargetBrick :: Maybe BrickId
  , duplicateSuspicionTargetEntry :: Maybe ListEntryId
  , duplicateSuspicionTargetRaw :: Maybe RawId
  , duplicateSuspicionStrength :: Double
  , duplicateSuspicionReasons :: [Text]
  , duplicateSuspicionMatchView :: DuplicateMatch
  }
  deriving stock (Eq, Show, Generic)

data DuplicateDecision = DuplicateDecision
  { duplicateDecisionId :: DuplicateDecisionId
  , duplicateDecisionCapture :: CaptureIntentId
  , duplicateDecisionSuspicion :: Maybe DuplicateSuspicionId
  , duplicateDecisionDecision :: DuplicateDecisionKind
  , duplicateDecisionAuthority :: Authority
  , duplicateDecisionRecordedAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data CaptureDraft = CaptureDraft
  { captureDraftOriginalText :: Text
  , captureDraftCanonicalEnglish :: Maybe Text
  , captureDraftNormalizationAuthority :: Maybe Authority
  , captureDraftProposedRoute :: Maybe CaptureRoute
  , captureDraftProposedParent :: Maybe BrickId
  , captureDraftProposedOwner :: Maybe BrickId
  , captureDraftProposedBehavior :: Maybe BrickBehavior
  , captureDraftProposedTemplate :: Maybe BrickTemplate
  }
  deriving stock (Eq, Show, Generic)

data CaptureContext = CaptureContext
  { captureContextStanding :: StandingState
  , captureContextMaterial :: MaterialState
  }
  deriving stock (Eq, Show, Generic)

data CaptureDecisionResult = CaptureDecisionResult
  { captureDecisionResultCapture :: CaptureIntentId
  , captureDecisionResultDecision :: DuplicateDecisionId
  , captureDecisionResultRaw :: Maybe RawId
  , captureDecisionResultBrick :: Maybe BrickId
  , captureDecisionResultEntry :: Maybe ListEntryId
  , captureDecisionResultInsertion :: Maybe Priority.PriorityInsertionId
  , captureDecisionResultEnrichedTarget :: Maybe DuplicateMatch
  }
  deriving stock (Eq, Show, Generic)

data CaptureState = CaptureState
  { captureStateRevision :: Integer
  , captureStateNextOrdinal :: Integer
  , captureStateIntents :: Map CaptureIntentId CaptureIntent
  , captureStateSuspicions :: Map DuplicateSuspicionId DuplicateSuspicion
  , captureStateDecisions :: Map DuplicateDecisionId DuplicateDecision
  , captureStateHistory :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON CaptureIntent where
  toJSON = genericToJSON (recordOptions "captureIntent")
instance FromJSON CaptureIntent where
  parseJSON = genericParseJSON (recordOptions "captureIntent")
instance ToJSON DuplicateMatch where
  toJSON = genericToJSON (recordOptions "duplicateMatch")
instance FromJSON DuplicateMatch where
  parseJSON = genericParseJSON (recordOptions "duplicateMatch")
instance ToJSON DuplicateSuspicion where
  toJSON = genericToJSON (recordOptions "duplicateSuspicion")
instance FromJSON DuplicateSuspicion where
  parseJSON = genericParseJSON (recordOptions "duplicateSuspicion")
instance ToJSON DuplicateDecision where
  toJSON = genericToJSON (recordOptions "duplicateDecision")
instance FromJSON DuplicateDecision where
  parseJSON = genericParseJSON (recordOptions "duplicateDecision")
instance ToJSON CaptureDecisionResult where
  toJSON = genericToJSON (recordOptions "captureDecisionResult")
instance FromJSON CaptureDecisionResult where
  parseJSON = genericParseJSON (recordOptions "captureDecisionResult")
instance ToJSON CaptureState where
  toJSON = genericToJSON (recordOptions "captureState")
instance FromJSON CaptureState where
  parseJSON = genericParseJSON (recordOptions "captureState")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLower first : rest)

data CaptureError
  = CaptureUnknownEntity Text
  | CaptureInvalidTransition Text
  | CaptureInvalidBinding Text
  | CaptureDomainInvariant Text
  | CaptureStandingError StandingError
  | CaptureMaterialError MaterialError
  | CaptureInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

emptyCaptureState :: CaptureState
emptyCaptureState = CaptureState
  { captureStateRevision = 0
  , captureStateNextOrdinal = 1
  , captureStateIntents = Map.empty
  , captureStateSuspicions = Map.empty
  , captureStateDecisions = Map.empty
  , captureStateHistory = []
  }

------------------------------------------------------------
-- Intent, ranking, and explicit decisions
------------------------------------------------------------

beginCapture ::
  CaptureDraft -> UTCTime -> CaptureContext -> CaptureState ->
  Either CaptureError (CaptureIntent, [DuplicateSuspicion], CaptureState)
beginCapture draft now context state = do
  validateOriginal (captureDraftOriginalText draft)
  validateCanonicalPair (captureDraftCanonicalEnglish draft)
    (captureDraftNormalizationAuthority draft)
  let (identifier, afterIntentId) = allocateId "capture" CaptureIntentId state
      intent = CaptureIntent
        { captureIntentId = identifier
        , captureIntentOriginalText = captureDraftOriginalText draft
        , captureIntentCanonicalEnglish = captureDraftCanonicalEnglish draft
        , captureIntentNormalizationAuthority = captureDraftNormalizationAuthority draft
        , captureIntentProposedRoute = captureDraftProposedRoute draft
        , captureIntentProposedParent = captureDraftProposedParent draft
        , captureIntentProposedOwner = captureDraftProposedOwner draft
        , captureIntentProposedBehavior = captureDraftProposedBehavior draft
        , captureIntentProposedTemplate = captureDraftProposedTemplate draft
        , captureIntentStatus = CapturePendingReview
        , captureIntentCreatedAt = now
        }
      matches = duplicateMatcherRank context intent
      withIntent = afterIntentId {captureStateIntents = Map.insert identifier intent
        (captureStateIntents afterIntentId)}
      (suspicions, withSuspicions) = materializeSuspicions identifier matches withIntent
  committed <- commit "capture_opened" withSuspicions
  validateCaptureState context committed
  pure (intent, suspicions, committed)

cancelCapture ::
  CaptureIntentId -> CaptureContext -> CaptureState ->
  Either CaptureError (CaptureIntent, CaptureState)
cancelCapture identifier context state = do
  capture <- requirePendingCapture identifier state
  let cancelled = capture {captureIntentStatus = CaptureCancelled}
  committed <- commit "capture_cancelled" state
    {captureStateIntents = Map.insert identifier cancelled (captureStateIntents state)}
  validateCaptureState context committed
  pure (cancelled, committed)

selectDuplicateSuspicion ::
  CaptureIntentId -> Maybe BrickId -> Maybe ListEntryId -> Maybe RawId ->
  CaptureState -> Either CaptureError DuplicateSuspicion
selectDuplicateSuspicion capture brick entry raw state = do
  _ <- requireCapture capture state
  unless (length (catMaybes [() <$ brick, () <$ entry, () <$ raw]) == 1)
    (Left (CaptureInvalidBinding "duplicate selection must name exactly one typed target"))
  maybe (Left (CaptureUnknownEntity "DuplicateSuspicion")) Right
    (findFirst matches (Map.elems (captureStateSuspicions state)))
  where
    requireCapture identifier current = maybe
      (Left (CaptureUnknownEntity "CaptureIntent")) Right
      (Map.lookup identifier (captureStateIntents current))
    matches suspicion = duplicateSuspicionCapture suspicion == capture
      && duplicateSuspicionTargetBrick suspicion == brick
      && duplicateSuspicionTargetEntry suspicion == entry
      && duplicateSuspicionTargetRaw suspicion == raw

confirmSeparateCapture ::
  CaptureIntentId -> Authority -> UTCTime -> CaptureContext -> CaptureState ->
  Either CaptureError (CaptureDecisionResult, CaptureContext, CaptureState)
confirmSeparateCapture captureId authority now context state = do
  capture <- requirePendingCapture captureId state
  route <- maybe (Left (CaptureInvalidBinding "separate capture requires a proposed route"))
    Right (captureIntentProposedRoute capture)
  when (route == EnrichExisting)
    (Left (CaptureInvalidBinding "enrich_existing requires a selected suspicion"))
  ensureNoDecision captureId state
  (raw, brick, entry, insertion, nextContext) <-
    routeSeparate route capture now context
  let (decisionId, allocated) = allocateId "duplicate-decision"
        DuplicateDecisionId state
      decision = DuplicateDecision decisionId captureId Nothing DuplicateSeparate
        authority now
      routed = capture {captureIntentStatus = CaptureRouted}
      changed = allocated
        { captureStateIntents = Map.insert captureId routed
            (captureStateIntents allocated)
        , captureStateDecisions = Map.insert decisionId decision
            (captureStateDecisions allocated)
        }
      result = CaptureDecisionResult captureId decisionId raw brick entry insertion Nothing
  committed <- commit "capture_routed_separately" changed
  validateCaptureState nextContext committed
  pure (result, nextContext, committed)

confirmDuplicateDecision ::
  CaptureIntentId -> DuplicateSuspicionId -> DuplicateDecisionKind -> Authority ->
  UTCTime -> CaptureContext -> CaptureState ->
  Either CaptureError (CaptureDecisionResult, CaptureContext, CaptureState)
confirmDuplicateDecision captureId suspicionId decisionKind authority now context state = do
  capture <- requirePendingCapture captureId state
  suspicion <- requireSuspicion suspicionId state
  unless (duplicateSuspicionCapture suspicion == captureId)
    (Left (CaptureInvalidBinding "DuplicateSuspicion belongs to another capture"))
  unless (decisionKind `elem` [DuplicateReuse, DuplicateEnrich])
    (Left (CaptureInvalidBinding "duplicate decision must be reuse or enrich"))
  ensureNoDecision captureId state
  let canonical = captureIntentCanonicalEnglish capture
      normalizationAuthority = captureIntentNormalizationAuthority capture
      material0 = synchronizeMaterial context
  (raw, material1) <- mapMaterial (captureInlineRaw
    (captureIntentOriginalText capture) canonical normalizationAuthority now material0)
  let target = duplicateSuspicionMatchView suspicion
      ownerBrick = duplicateOwnerBrick context suspicion
  ((_, _disposition), material2) <- mapMaterial
    (reviewRaw (rawId raw) Linked ownerBrick authority
      (Just ("explicit " <> duplicateDecisionKindText decisionKind
        <> " duplicate decision")) now material1)
  material3 <- enrichTarget raw suspicion now material2
  let nextContext = context {captureContextMaterial = material3}
      (decisionId, allocated) = allocateId "duplicate-decision"
        DuplicateDecisionId state
      decision = DuplicateDecision decisionId captureId (Just suspicionId)
        decisionKind authority now
      routed = capture {captureIntentStatus = CaptureRouted}
      changed = allocated
        { captureStateIntents = Map.insert captureId routed
            (captureStateIntents allocated)
        , captureStateDecisions = Map.insert decisionId decision
            (captureStateDecisions allocated)
        }
      result = CaptureDecisionResult captureId decisionId (Just (rawId raw))
        Nothing Nothing Nothing (Just target)
  committed <- commit "duplicate_capture_enriched" changed
  validateCaptureState nextContext committed
  pure (result, nextContext, committed)

-- | Rank compatible targets using rebuildable fingerprints and explicit
-- scope/history evidence.  The stable order is strength descending, then
-- target kind and opaque identity.  No canonical state is changed.
duplicateMatcherRank :: CaptureContext -> CaptureIntent -> [DuplicateMatch]
duplicateMatcherRank context capture = sortOn rankKey
  (brickMatches <> entryMatches <> rawMatches)
  where
    standing = captureContextStanding context
    execution = coordinationStateExecution
      (standingStateCoordination standing)
    domain = executionStateDomain execution
    material = captureContextMaterial context
    route = captureIntentProposedRoute capture
    compatible kind = case route of
      Just CreateListEntry -> kind == DuplicateListEntry
      Just CreateBrick -> kind == DuplicateBrick
      Just InstantiateTemplate -> kind == DuplicateBrick
      Just PreserveRaw -> kind == DuplicateRaw
      _ -> True
    candidateMatch kind brick entry raw candidateText scopeReasons = do
      unlessMaybe (compatible kind)
      let (strength, lexicalReasons) = lexicalSimilarity capture candidateText
      unlessMaybe (strength > 0)
      pure DuplicateMatch
        { duplicateMatchTargetKind = kind
        , duplicateMatchTargetBrick = brick
        , duplicateMatchTargetEntry = entry
        , duplicateMatchTargetRaw = raw
        , duplicateMatchStrength = min 1 (strength + scopeBoost scopeReasons)
        , duplicateMatchReasons = lexicalReasons <> scopeReasons
        }
    brickMatches = mapMaybe (\brick -> candidateMatch DuplicateBrick
      (Just (brickId brick)) Nothing Nothing (brickTitle brick)
      (brickScopeReasons capture brick)) (Map.elems (domainBricks domain))
    entryMatches = mapMaybe (\entry -> candidateMatch DuplicateListEntry
      Nothing (Just (listEntryId entry)) Nothing (listEntryLabel entry)
      (entryScopeReasons capture entry)) (Map.elems (domainListEntries domain))
    rawMatches = mapMaybe (\raw -> do
      text <- rawCanonicalEnglish raw <|> rawTitle raw <|> rawOriginalText raw
      candidateMatch DuplicateRaw Nothing Nothing (Just (rawId raw)) text
        ["active material history" | rawStorageStateIsActive raw])
      (Map.elems (materialRaws material))
    rankKey match =
      ( Down (duplicateMatchStrength match)
      , duplicateMatchTargetKind match
      , duplicateIdentity match
      )

matchingFingerprints :: Text -> [Text]
matchingFingerprints input = deduplicate
  [ conservative
  , Text.toCaseFold conservative
  , Text.unwords (meaningfulTokens conservative)
  ]
  where
    conservative = normalizeWhitespace input

------------------------------------------------------------
-- Route materialization
------------------------------------------------------------

routeSeparate ::
  CaptureRoute -> CaptureIntent -> UTCTime -> CaptureContext ->
  Either CaptureError
    (Maybe RawId, Maybe BrickId, Maybe ListEntryId,
     Maybe Priority.PriorityInsertionId, CaptureContext)
routeSeparate route capture now context = case route of
  PreserveRaw -> do
    let material0 = synchronizeMaterial context
    (raw, material) <- mapMaterial (captureInlineRaw
      (captureIntentOriginalText capture) (captureIntentCanonicalEnglish capture)
      (captureIntentNormalizationAuthority capture) now material0)
    pure (Just (rawId raw), Nothing, Nothing, Nothing,
      context {captureContextMaterial = material})
  CreateBrick -> createRoutedBrick capture now context
  InstantiateTemplate -> createRoutedBrick capture now context
  CreateListEntry -> createRoutedEntry capture now context
  EnrichExisting -> Left
    (CaptureInvalidBinding "enrich_existing cannot be routed without suspicion")

createRoutedBrick ::
  CaptureIntent -> UTCTime -> CaptureContext ->
  Either CaptureError
    (Maybe RawId, Maybe BrickId, Maybe ListEntryId,
     Maybe Priority.PriorityInsertionId, CaptureContext)
createRoutedBrick capture now context = do
  route <- maybe (Left (CaptureInvalidBinding "Brick route is absent")) Right
    (captureIntentProposedRoute capture)
  unless (route `elem` [CreateBrick, InstantiateTemplate])
    (Left (CaptureInvalidBinding "route does not create a Brick"))
  canonical <- requireCanonical capture
  authority <- maybe (Left (CaptureInvalidBinding
    "normalization authority is required for canonical work")) Right
    (captureIntentNormalizationAuthority capture)
  when (route == InstantiateTemplate && captureIntentProposedTemplate capture == Nothing)
    (Left (CaptureInvalidBinding "instantiate_template requires proposed_template"))
  let behavior = case route of
        InstantiateTemplate -> maybe standardV1 templateBehavior
          (captureIntentProposedTemplate capture)
        _ -> fromMaybe standardV1 (captureIntentProposedBehavior capture)
      description = if route == InstantiateTemplate
        then captureIntentProposedTemplate capture >>= templateDefaultDescription
        else Nothing
      title = CanonicalText canonical
        (Just (captureIntentOriginalText capture)) authority
      draft = (ordinaryBrickDraft title behavior now)
        { brickDraftDescription = description
        , brickDraftParent = captureIntentProposedParent capture
        }
  (brick, insertion, standing) <- mapStanding (createStandingBrick draft
    (unCaptureIntentId (captureIntentId capture)) now
    (captureContextStanding context))
  let material = registerMaterialBrick (brickId brick) Active
        (synchronizeMaterial context {captureContextStanding = standing})
      next = CaptureContext standing material
  pure (Nothing, Just (brickId brick), Nothing,
    Just (Priority.priorityInsertionId insertion), next)

createRoutedEntry ::
  CaptureIntent -> UTCTime -> CaptureContext ->
  Either CaptureError
    (Maybe RawId, Maybe BrickId, Maybe ListEntryId,
     Maybe Priority.PriorityInsertionId, CaptureContext)
createRoutedEntry capture now context = do
  unless (captureIntentProposedRoute capture == Just CreateListEntry)
    (Left (CaptureInvalidBinding "route does not create a ListEntry"))
  owner <- maybe (Left (CaptureInvalidBinding "ListEntry route requires proposed_owner"))
    Right (captureIntentProposedOwner capture)
  canonical <- requireCanonical capture
  authority <- maybe (Left (CaptureInvalidBinding
    "ListEntry route requires normalization authority")) Right
    (captureIntentNormalizationAuthority capture)
  let label = CanonicalText canonical (Just (captureIntentOriginalText capture)) authority
      draft = ListEntryDraft owner label Nothing Nothing now
  (entry, standing) <- mapStanding
    (addStandingListEntry draft (captureContextStanding context))
  let material = registerMaterialListEntry (listEntryId entry)
        (synchronizeMaterial context {captureContextStanding = standing})
      next = CaptureContext standing material
  pure (Nothing, Nothing, Just (listEntryId entry), Nothing, next)

requireCanonical :: CaptureIntent -> Either CaptureError Text
requireCanonical capture = do
  canonical <- maybe (Left (CaptureInvalidBinding
    "canonical English is required for canonical work")) Right
    (captureIntentCanonicalEnglish capture)
  _ <- maybe (Left (CaptureInvalidBinding
    "normalization authority is required for canonical work")) Right
    (captureIntentNormalizationAuthority capture)
  unless (canonicalEnglishText canonical)
    (Left (CaptureInvalidBinding "canonical English is invalid"))
  pure canonical

synchronizeMaterial :: CaptureContext -> MaterialState
synchronizeMaterial context = foldr registerEntry withBricks
  (Map.elems (domainListEntries domain))
  where
    domain = executionStateDomain . coordinationStateExecution
      . standingStateCoordination $ captureContextStanding context
    withBricks = foldr (\brick -> registerMaterialBrick
      (brickId brick) (brickStatus brick)) (captureContextMaterial context)
      (Map.elems (domainBricks domain))
    registerEntry entry = registerMaterialListEntry (listEntryId entry)

enrichTarget ::
  Raw -> DuplicateSuspicion -> UTCTime -> MaterialState ->
  Either CaptureError MaterialState
enrichTarget raw suspicion now material = case
    ( duplicateSuspicionTargetBrick suspicion
    , duplicateSuspicionTargetEntry suspicion
    , duplicateSuspicionTargetRaw suspicion
    ) of
  (Just brick, Nothing, Nothing) -> snd <$> mapMaterial
    (linkRawToBrick (rawId raw) brick Evidence Nothing now material)
  (Nothing, Just entry, Nothing) -> snd <$> mapMaterial
    (linkRawToEntry (rawId raw) entry Evidence now material)
  (Nothing, Nothing, Just targetRaw) -> snd <$> mapMaterial
    (linkDerivedRaw (rawId raw) targetRaw now material)
  _ -> Left (CaptureInvalidBinding
    "DuplicateSuspicion must have exactly one typed target")

duplicateOwnerBrick :: CaptureContext -> DuplicateSuspicion -> Maybe BrickId
duplicateOwnerBrick context suspicion =
  duplicateSuspicionTargetBrick suspicion <|>
  (duplicateSuspicionTargetEntry suspicion >>= \entryId ->
    listEntryOwner <$> Map.lookup entryId (domainListEntries domain))
  where
    domain = executionStateDomain . coordinationStateExecution
      . standingStateCoordination $ captureContextStanding context

------------------------------------------------------------
-- Similarity evidence
------------------------------------------------------------

lexicalSimilarity :: CaptureIntent -> Text -> (Double, [Text])
lexicalSimilarity capture candidate =
  let source = fromMaybe (captureIntentOriginalText capture)
        (captureIntentCanonicalEnglish capture)
      sourcePrints = matchingFingerprints source
      targetPrints = matchingFingerprints candidate
      exact = any (`elem` targetPrints) sourcePrints
      sourceTokens = Set.fromList (meaningfulTokens source)
      targetTokens = Set.fromList (meaningfulTokens candidate)
      overlap = Set.size (Set.intersection sourceTokens targetTokens)
      unionSize = Set.size (Set.union sourceTokens targetTokens)
      tokenScore = if unionSize == 0 then 0
        else fromIntegral overlap / fromIntegral unionSize
  in if exact
      then (0.9, ["canonical text fingerprint match"])
      else if overlap > 0
        then (0.55 * tokenScore + 0.2,
          ["canonical token overlap", "conservative English lexical evidence"])
        else (0, [])

normalizeWhitespace :: Text -> Text
normalizeWhitespace = Text.unwords . Text.words

meaningfulTokens :: Text -> [Text]
meaningfulTokens = map singularize . filter (`Set.notMember` stopWords)
  . filter (not . Text.null) . Text.words . Text.map punctuationToSpace
  . Text.toCaseFold . normalizeWhitespace
  where
    punctuationToSpace character
      | isAlphaNum character = character
      | otherwise = ' '

stopWords :: Set.Set Text
stopWords = Set.fromList
  ["a", "an", "the", "to", "buy", "purchase", "get", "read", "article"]

singularize :: Text -> Text
singularize token
  | Text.length token > 4 && "ies" `Text.isSuffixOf` token =
      Text.dropEnd 3 token <> "y"
  | Text.length token > 3 && "s" `Text.isSuffixOf` token
      && not ("ss" `Text.isSuffixOf` token) = Text.dropEnd 1 token
  | otherwise = token

brickScopeReasons :: CaptureIntent -> Brick -> [Text]
brickScopeReasons capture brick =
  ["same parent scope" | captureIntentProposedParent capture == brickParent brick]
  <> ["active target history" | brickStatus brick == Active]
  <> ["compatible behavior" | maybe False
      ((== behaviorId (brickBehavior brick)) . behaviorId)
      (captureIntentProposedBehavior capture)]

entryScopeReasons :: CaptureIntent -> ListEntry -> [Text]
entryScopeReasons capture entry =
  ["same owner scope" | captureIntentProposedOwner capture == Just (listEntryOwner entry)]
  <> ["open target history" | listEntryStatus entry == EntryOpen]

scopeBoost :: [Text] -> Double
scopeBoost reasons = min 0.1 (0.03 * fromIntegral (length reasons))

rawStorageStateIsActive :: Raw -> Bool
rawStorageStateIsActive raw = toJSON (rawStorageState raw) == String "active"

duplicateIdentity :: DuplicateMatch -> Text
duplicateIdentity match = fromMaybe ""
  ( fmap (Text.pack . show) (duplicateMatchTargetBrick match)
  <|> fmap (Text.pack . show) (duplicateMatchTargetEntry match)
  <|> fmap (Text.pack . show) (duplicateMatchTargetRaw match)
  )

materializeSuspicions ::
  CaptureIntentId -> [DuplicateMatch] -> CaptureState ->
  ([DuplicateSuspicion], CaptureState)
materializeSuspicions capture matches initial = foldl create ([], initial) matches
  where
    create (created, state) match =
      let (identifier, allocated) = allocateId "duplicate-suspicion"
            DuplicateSuspicionId state
          suspicion = DuplicateSuspicion
            { duplicateSuspicionId = identifier
            , duplicateSuspicionCapture = capture
            , duplicateSuspicionTargetKind = duplicateMatchTargetKind match
            , duplicateSuspicionTargetBrick = duplicateMatchTargetBrick match
            , duplicateSuspicionTargetEntry = duplicateMatchTargetEntry match
            , duplicateSuspicionTargetRaw = duplicateMatchTargetRaw match
            , duplicateSuspicionStrength = duplicateMatchStrength match
            , duplicateSuspicionReasons = duplicateMatchReasons match
            , duplicateSuspicionMatchView = match
            }
          next = allocated {captureStateSuspicions = Map.insert identifier suspicion
            (captureStateSuspicions allocated)}
      in (created <> [suspicion], next)

------------------------------------------------------------
-- Validation and helpers
------------------------------------------------------------

validateCaptureState :: CaptureContext -> CaptureState -> Either CaptureError ()
validateCaptureState context state = do
  mapStanding (validateStandingState (captureContextStanding context))
  let captures = captureStateIntents state
      suspicions = captureStateSuspicions state
      decisions = captureStateDecisions state
      decisionCaptures = map duplicateDecisionCapture (Map.elems decisions)
      invalidTarget suspicion = length (catMaybes
        [ () <$ duplicateSuspicionTargetBrick suspicion
        , () <$ duplicateSuspicionTargetEntry suspicion
        , () <$ duplicateSuspicionTargetRaw suspicion
        ]) /= 1
      invalidKind suspicion = case duplicateSuspicionTargetKind suspicion of
        DuplicateBrick -> not (isJust (duplicateSuspicionTargetBrick suspicion))
        DuplicateListEntry -> not (isJust (duplicateSuspicionTargetEntry suspicion))
        DuplicateRaw -> not (isJust (duplicateSuspicionTargetRaw suspicion))
      violations = concat
        [ ["capture revision/history/allocator is inconsistent" |
            captureStateRevision state < 0 || captureStateNextOrdinal state < 1
            || captureStateRevision state
              /= fromIntegral (length (captureStateHistory state))]
        , ["CaptureIntent map key differs from identity" | any (uncurry (/=))
            [(identifier, captureIntentId capture) |
              (identifier, capture) <- Map.toList captures]]
        , ["CaptureIntent normalization is not attributed" | any
            (\capture -> isJust (captureIntentCanonicalEnglish capture)
              /= isJust (captureIntentNormalizationAuthority capture))
            (Map.elems captures)]
        , ["DuplicateSuspicion map key differs from identity" | any (uncurry (/=))
            [(identifier, duplicateSuspicionId suspicion) |
              (identifier, suspicion) <- Map.toList suspicions]]
        , ["DuplicateSuspicion has zero or multiple typed targets" | any
            invalidTarget (Map.elems suspicions)]
        , ["DuplicateSuspicion target kind disagrees with its target" | any
            invalidKind (Map.elems suspicions)]
        , ["DuplicateSuspicion references an unknown capture" | any
            ((`Map.notMember` captures) . duplicateSuspicionCapture)
            (Map.elems suspicions)]
        , ["DuplicateSuspicion match_view is not derived from retained fields" | any
            (\suspicion -> duplicateSuspicionMatchView suspicion /=
              DuplicateMatch (duplicateSuspicionTargetKind suspicion)
                (duplicateSuspicionTargetBrick suspicion)
                (duplicateSuspicionTargetEntry suspicion)
                (duplicateSuspicionTargetRaw suspicion)
                (duplicateSuspicionStrength suspicion)
                (duplicateSuspicionReasons suspicion))
            (Map.elems suspicions)]
        , ["DuplicateDecision map key differs from identity" | any (uncurry (/=))
            [(identifier, duplicateDecisionId decision) |
              (identifier, decision) <- Map.toList decisions]]
        , ["DuplicateDecision references an unknown capture or suspicion" | any
            (\decision -> Map.notMember (duplicateDecisionCapture decision) captures
              || maybe False (`Map.notMember` suspicions)
                (duplicateDecisionSuspicion decision))
            (Map.elems decisions)]
        , ["CaptureIntent has more than one DuplicateDecision" |
            length decisionCaptures /= Set.size (Set.fromList decisionCaptures)]
        , ["routed CaptureIntent does not have exactly one decision" | any
            (\capture -> captureIntentStatus capture == CaptureRouted
              && length (filter (== captureIntentId capture) decisionCaptures) /= 1)
            (Map.elems captures)]
        ]
  unless (null violations) (Left (CaptureInvariantViolation violations))

requirePendingCapture :: CaptureIntentId -> CaptureState -> Either CaptureError CaptureIntent
requirePendingCapture identifier state = do
  capture <- maybe (Left (CaptureUnknownEntity "CaptureIntent")) Right
    (Map.lookup identifier (captureStateIntents state))
  unless (captureIntentStatus capture == CapturePendingReview)
    (Left (CaptureInvalidTransition "CaptureIntent is terminal"))
  pure capture

requireSuspicion :: DuplicateSuspicionId -> CaptureState -> Either CaptureError DuplicateSuspicion
requireSuspicion identifier state = maybe
  (Left (CaptureUnknownEntity "DuplicateSuspicion")) Right
  (Map.lookup identifier (captureStateSuspicions state))

ensureNoDecision :: CaptureIntentId -> CaptureState -> Either CaptureError ()
ensureNoDecision capture state = when (any
  ((== capture) . duplicateDecisionCapture) (Map.elems (captureStateDecisions state)))
  (Left (CaptureInvalidTransition "CaptureIntent already has a duplicate decision"))

validateOriginal :: Text -> Either CaptureError ()
validateOriginal original = when (Text.null original)
  (Left (CaptureInvalidBinding "original capture text must not be empty"))

validateCanonicalPair :: Maybe Text -> Maybe Authority -> Either CaptureError ()
validateCanonicalPair canonical authority = do
  unless (isJust canonical == isJust authority)
    (Left (CaptureInvalidBinding
      "canonical English and normalization authority must appear together"))
  mapM_ (\value -> unless (canonicalEnglishText value)
    (Left (CaptureInvalidBinding "canonical English is invalid"))) canonical

commit :: Text -> CaptureState -> Either CaptureError CaptureState
commit action state = Right state
  { captureStateRevision = captureStateRevision state + 1
  , captureStateHistory = captureStateHistory state <> [action]
  }

allocateId ::
  Text -> (Text -> identifier) -> CaptureState -> (identifier, CaptureState)
allocateId kind wrap state =
  let ordinal = captureStateNextOrdinal state
      identifier = wrap ("la1:" <> kind <> ":" <> Text.pack (show ordinal))
  in (identifier, state {captureStateNextOrdinal = ordinal + 1})

mapStanding :: Either StandingError value -> Either CaptureError value
mapStanding = either (Left . CaptureStandingError) Right

mapMaterial :: Either MaterialError value -> Either CaptureError value
mapMaterial = either (Left . CaptureMaterialError) Right

unlessMaybe :: Bool -> Maybe ()
unlessMaybe condition = if condition then Just () else Nothing

findFirst :: (value -> Bool) -> [value] -> Maybe value
findFirst _ [] = Nothing
findFirst predicate (value : rest)
  | predicate value = Just value
  | otherwise = findFirst predicate rest

deduplicate :: Ord value => [value] -> [value]
deduplicate = Set.toList . Set.fromList

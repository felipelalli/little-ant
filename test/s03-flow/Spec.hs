module Main (main) where

import Control.Monad (forM_, when, (>=>))
import Data.Aeson (eitherDecode, encode)
import Data.ByteString qualified as ByteString
import Data.Char (isAsciiLower)
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Application
import LittleAnt.Decision (statePreconditionHash)
import LittleAnt.Event
import LittleAnt.Export (emptyExportPort)
import LittleAnt.ForecastWorld qualified as World
import LittleAnt.Id
import LittleAnt.Import (emptyImportPort)
import LittleAnt.Interaction
import LittleAnt.JudgmentReview
import LittleAnt.Model
import LittleAnt.Result
import LittleAnt.Store
import System.Directory (doesFileExist, removeFile)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "S03 judgment flows"
    [ testCase "missing metadata is neutral until a demand and read-only views do not create work" demandIsLazy
    , testCase "effort and impact requests produce recorded short lottery rounds" demandLotteryRounds
    , testCase "equivalent requests coalesce and skip preserves Work with durable cooldown" demandCooldown
    , testCase "changed scope preserves the public estimate but marks it review due" scopeReview
    , testCase "new evidence requests impact review without promoting the judgment" impactEvidenceReview
    , testCase "easier-work recovery records a stable shortlist and offers consent without assigning a class" easierWorkRecovery
    , testCase "a fresh effort contradiction needs changed or revise before recording" effortConflict
    , testCase "an isolated demand cannot offer an invalid comparison" isolatedDemand
    , testCase "explicit order maintains one unresolved sibling run continuously" $ withHarness $ \environment -> do
        _ <- createProvisionalWork environment "alpha"
        _ <- createProvisionalWork environment "bravo"
        _ <- createProvisionalWork environment "charlie"

        scope <- run environment (OrderCommand Nothing) >>= interactionOf
        envelopeOpportunity scope @?= OrderScopeOpportunity
        case envelopeActions scope of
          firstAction : _ -> actionDefault firstAction @?= True
          [] -> assertFailure "order scope has no actions"

        first <- answer environment scope "order.all"
        case envelopeOpportunity first of
          ImportanceReviewOpportunity session _ _ 0 [] False -> orderSessionCadence session @?= ContinuousOrder
          other -> assertFailure ("expected importance comparison, got " <> show other)

        second <- answer environment first "importance.more"
        assertBool "continuous ordering does not emit a per-pair receipt" $
          case envelopeOpportunity second of
            ImportanceReviewOpportunity{} -> True
            OrderResultOpportunity{} -> True
            _ -> False

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        Map.size (statePairJudgments (loadedState loaded)) @?= 1
        let current = Map.elems (statePairJudgments (loadedState loaded))
        fmap judgmentProvenance current @?= [DirectHuman]
    , testCase "two ordering skips preserve order and persist provisional review pressure" $ withHarness $ \environment -> do
        _ <- createProvisionalWork environment "alpha"
        _ <- createProvisionalWork environment "bravo"
        _ <- createProvisionalWork environment "charlie"
        scope <- run environment (OrderCommand Nothing) >>= interactionOf
        first <- answer environment scope "order.all"
        second <- answer environment first "importance.skip"
        case envelopeOpportunity second of
          ImportanceReviewOpportunity _ _ replacement 1 skipped _ -> assertBool "nearby comparator changed" (replacement `notElem` skipped)
          other -> assertFailure ("expected bounded nearby comparison, got " <> show other)
        afterSecondSkip <- answer environment second "importance.skip"
        assertBool "the direct session advances or ends stably" $
          case envelopeOpportunity afterSecondSkip of
            ImportanceReviewOpportunity{} -> True
            OrderResultOpportunity{} -> True
            _ -> False
        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        Map.size (stateLazyReviews (loadedState loaded)) @?= 1
        assertBool "one Brick is visibly provisional" (Provisional "nearby importance comparisons skipped" `elem` fmap brickImportanceConfidence (Map.elems (stateBricks (loadedState loaded))))
        Map.size (statePairJudgments (loadedState loaded)) @?= 0
    , testCase "impact, effort, and phase remain independent direct commands" $ withHarness $ \environment -> do
        created <- createProvisionalWork environment "reduce payment fraud"
        brick <- brickFromResult environment created
        let reference = "#" <> unHandle (brickHandle brick)

        impact <- run environment (ImpactCommand reference) >>= interactionOf
        envelopeOpportunity impact @?= ImpactClassOpportunity (brickId brick)
        basis <- answer environment impact "impact.class.high"
        envelopeOpportunity basis @?= ImpactBasisOpportunity (brickId brick) HighImpact
        impactResult <- answer environment basis "impact.speculative"
        assertJudgmentResult ImpactAxis impactResult

        effort <- run environment (EffortCommand reference) >>= interactionOf
        envelopeOpportunity effort @?= EffortClassOpportunity (brickId brick)
        effortResult <- answer environment effort "effort.class.easy"
        assertJudgmentResult EffortAxis effortResult

        phase <- run environment (PhaseCommand reference) >>= interactionOf
        envelopeOpportunity phase @?= PhaseOpportunity (brickId brick)
        _ <- answer environment phase "phase.spec"

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        impactClaimClass (stateImpactClaims (loadedState loaded) Map.! brickId brick) @?= HighImpact
        impactClaimMaturity (stateImpactClaims (loadedState loaded) Map.! brickId brick) @?= SpeculativeImpact
        effortClaimClass (stateEffortClaims (loadedState loaded) Map.! brickId brick) @?= EasyEffort
        phaseClaimValue (statePhaseClaims (loadedState loaded) Map.! brickId brick) @?= SpecPhase
        Map.size (statePairJudgments (loadedState loaded)) @?= 0
    , testCase "ordering checkpoint survives restart and reverse navigation records nothing" $ withHarness $ \environment -> do
        _ <- createProvisionalWork environment "alpha"
        _ <- createProvisionalWork environment "bravo"
        scope <- run environment (OrderCommand Nothing) >>= interactionOf
        comparison <- answer environment scope "order.all"
        restarted <- run environment NextCommand >>= interactionOf
        restarted @?= comparison
        back <- navigate environment restarted True
        envelopeOpportunity back @?= OrderScopeOpportunity
        forward <- navigate environment back False
        forward @?= comparison
        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        Map.size (statePairJudgments (loadedState loaded)) @?= 0
    , testCase "impact evidence ladder records selected evidence and explicit maturity" $ withHarness $ \environment -> do
        created <- createProvisionalWork environment "reduce payment fraud"
        brick <- brickFromResult environment created
        fed <- run environment (FeedCommand "test" "Rock Splitter pilot results") >>= interactionOf
        evidenceId <- case envelopeOpportunity fed of
          RawTriageOpportunity identity _ _ -> pure identity
          other -> assertFailure ("expected Raw triage, got " <> show other)
        destinations <- answer environment fed "raw.choose-destination"
        under <- answer environment destinations ("raw.destination.brick." <> renderUUIDv7 (brickId brick))
        attach <- answer environment under "raw.attach"
        _ <- answer environment attach "raw.attach.evidence"

        impact <- run environment (ImpactCommand ("#" <> unHandle (brickHandle brick))) >>= interactionOf
        basis <- answer environment impact "impact.class.high"
        evidence <- answer environment basis "impact.evidence"
        case envelopeOpportunity evidence of
          ImpactEvidenceOpportunity identity HighImpact candidates -> do
            identity @?= brickId brick
            assertBool "attached Raw is offered" (evidenceId `elem` candidates)
          other -> assertFailure ("expected impact evidence selection, got " <> show other)
        q0 <- answer environment evidence ("impact.evidence.select." <> renderUUIDv7 evidenceId)
        q1 <- answer environment q0 "impact.maturity.no"
        preview <- answer environment q1 "impact.maturity.yes"
        case envelopeOpportunity preview of
          ImpactMaturityPreviewOpportunity identity HighImpact selected ValidatedImpact -> do
            identity @?= brickId brick
            selected @?= evidenceId
          other -> assertFailure ("expected validated preview, got " <> show other)
        _ <- answer environment preview "impact.preview.accept"

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        let claim = stateImpactClaims (loadedState loaded) Map.! brickId brick
        impactClaimMaturity claim @?= ValidatedImpact
        impactClaimEvidence claim @?= [evidenceId]
    , testCase "impact comparison creates relative evidence without assigning a class" $ withHarness $ \environment -> do
        firstCreated <- createProvisionalWork environment "reduce payment fraud"
        first <- brickFromResult environment firstCreated
        secondCreated <- createProvisionalWork environment "improve statements"
        second <- brickFromResult environment secondCreated
        secondImpact <- run environment (ImpactCommand ("#" <> unHandle (brickHandle second))) >>= interactionOf
        secondBasis <- answer environment secondImpact "impact.class.medium"
        _ <- answer environment secondBasis "impact.speculative"

        firstImpact <- run environment (ImpactCommand ("#" <> unHandle (brickHandle first))) >>= interactionOf
        comparison <- answer environment firstImpact "impact.unknown"
        case envelopeOpportunity comparison of
          ImpactComparisonOpportunity subject comparator 0 [] False -> do
            subject @?= brickId first
            comparator @?= brickId second
          other -> assertFailure ("expected impact comparison, got " <> show other)
        result <- answer environment comparison "impact.more"
        assertJudgmentResult ImpactAxis result

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        assertBool "relative comparison does not classify the subject" (Map.notMember (brickId first) (stateImpactClaims (loadedState loaded)))
        let relations = [judgment | judgment <- Map.elems (statePairJudgments (loadedState loaded)), judgmentAxis judgment == ImpactAxis]
        case relations of
          [judgment] -> do
            judgmentFirst judgment @?= brickId first
            judgmentSecond judgment @?= brickId second
          _ -> assertFailure "expected exactly one Impact relation"
    , testCase "effort assistance narrows by reviewed exemplar without NORMAL fallback" $ withHarness $ \environment -> do
        exemplarCreated <- createProvisionalWork environment "complete chargeback migration"
        exemplar <- brickFromResult environment exemplarCreated
        exemplarEffort <- run environment (EffortCommand ("#" <> unHandle (brickHandle exemplar))) >>= interactionOf
        _ <- answer environment exemplarEffort "effort.class.hard"

        subjectCreated <- createProvisionalWork environment "reduce payment fraud"
        subject <- brickFromResult environment subjectCreated
        effort <- run environment (EffortCommand ("#" <> unHandle (brickHandle subject))) >>= interactionOf
        comparison <- answer environment effort "effort.unknown"
        case envelopeOpportunity comparison of
          EffortExemplarOpportunity identity exemplarId 0 remaining [] -> do
            identity @?= brickId subject
            exemplarId @?= brickId exemplar
            assertBool "all classes begin plausible" (NormalEffort `elem` remaining && ProjectEffort `elem` remaining)
          other -> assertFailure ("expected effort exemplar, got " <> show other)
        narrowed <- answer environment comparison "effort.less"
        case envelopeOpportunity narrowed of
          EffortNarrowedOpportunity identity remaining -> do
            identity @?= brickId subject
            assertBool "HARD and larger classes were removed" (HardEffort `notElem` remaining)
            assertBool "no class was selected" (EasyEffort `elem` remaining)
          other -> assertFailure ("expected narrowed effort ladder, got " <> show other)
        _ <- answer environment narrowed "effort.class.easy"

        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        effortClaimClass (stateEffortClaims (loadedState loaded) Map.! brickId subject) @?= EasyEffort
        let relative = [judgment | judgment <- Map.elems (statePairJudgments (loadedState loaded)), judgmentAxis judgment == EffortAxis]
        length relative @?= 1
    , testCase "contextual tie-break creates provisional pressure but no human edge" $ withHarness $ \environment -> do
        _ <- createProvisionalWork environment "alpha"
        _ <- createProvisionalWork environment "bravo"
        _ <- createProvisionalWork environment "charlie"
        scope <- run environment (OrderCommand Nothing) >>= interactionOf
        comparison <- answer environment scope "order.all"
        afterTieBreak <- run environment TieBreakCommand >>= interactionOf
        assertBool "tie-break immediately validates nearby or ends stably" $
          case envelopeOpportunity afterTieBreak of
            ImportanceReviewOpportunity{} -> True
            OrderResultOpportunity{} -> True
            _ -> False
        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        Map.size (statePairJudgments (loadedState loaded)) @?= 0
        assertBool "provisional review pressure is durable" (not (Map.null (stateLazyReviews (loadedState loaded))))
        assertBool "the original comparison was a real checkpoint" $
          case envelopeOpportunity comparison of ImportanceReviewOpportunity{} -> True; _ -> False
    , testCase "dry-run judgment changes neither JSONL nor durable claim" $ withHarness $ \environment -> do
        created <- createProvisionalWork environment "reduce fraud"
        brick <- brickFromResult environment created
        impact <- run environment (ImpactCommand ("#" <> unHandle (brickHandle brick))) >>= interactionOf
        basis <- answer environment impact "impact.class.high"
        _ <- assertRight =<< runAppCommand environment True (const (pure ())) (RespondCommand (response basis "impact.speculative"))
        loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
        stateImpactClaims (loadedState loaded) @?= Map.empty
        restored <- run environment NextCommand >>= interactionOf
        restored @?= basis
    ]

demandIsLazy :: Assertion
demandIsLazy = withHarness $ \environment -> do
  first <- createProvisionalWork environment "alpha" >>= brickFromResult environment
  _ <- createProvisionalWork environment "bravo"
  before <- loadState environment
  stateJudgmentReviews before @?= Map.empty
  _ <- run environment (ListCommand (Just "forecast") Nothing Nothing)
  _ <- run environment (WhyCommand CompleteView)
  loadState environment >>= (@?= before)
  _ <- run environment (EffortCommand (ref first))
  requested <- loadState environment
  Map.size (stateJudgmentReviews requested) @?= 1
  stateEffortClaims requested @?= Map.empty
  _ <- run environment (EffortCommand (ref first))
  loadState environment >>= (@?= requested)
  _ <- run environment (ListCommand (Just "forecast") Nothing Nothing)
  loadState environment >>= (@?= requested)
  assertBool "effort review was not eligible" (World.EffortComparisonOpportunity `elem` offeredKinds requested fixedTime)

demandLotteryRounds :: Assertion
demandLotteryRounds = withHarness $ \environment -> do
  bricks <- mapM (createProvisionalWork environment >=> brickFromResult environment) ["alpha", "bravo", "charlie"]
  let owner = head bricks
  _ <- run environment (EffortCommand (ref owner))
  seedLottery environment owner
  roundEnvelope <- drawUntil environment isEffort 128
  restored <- run environment NextCommand >>= interactionOf
  restored @?= roundEnvelope
  why <- run environment (WhyCommand CompleteView)
  assertBool "why omitted the frozen demand reason" (any (Text.isInfixOf "requested an effort judgment") (resultWhySummary why))
  eitherDecode (encode roundEnvelope) @?= Right roundEnvelope
  case envelopeOpportunity roundEnvelope of
    EffortComparisonOpportunity identity candidates -> do
      length candidates @?= 3
      _ <- answer environment roundEnvelope ("effort.choose." <> renderUUIDv7 (last candidates))
      state <- loadState environment
      let review = stateJudgmentReviews state Map.! (EffortDiscovery, identity)
      judgmentReviewResolved review @?= True
      stateEffortClaims state @?= Map.empty
      length [judgment | judgment <- Map.elems (statePairJudgments state), judgmentAxis judgment == EffortAxis] @?= 2
    other -> assertFailure (show other)
  _ <- run environment (ImpactCommand (ref owner))
  impact <- drawUntil environment isImpact 128
  case envelopeOpportunity impact of
    ImpactComparisonOpportunity first _ _ _ _ -> do
      _ <- answer environment impact "impact.more"
      state <- loadState environment
      judgmentReviewResolved (stateJudgmentReviews state Map.! (ImpactDiscovery, first)) @?= True
      stateImpactClaims state @?= Map.empty
    other -> assertFailure (show other)
 where
  isEffort = \case EffortComparisonOpportunity{} -> True; _ -> False
  isImpact = \case ImpactComparisonOpportunity{} -> True; _ -> False

demandCooldown :: Assertion
demandCooldown = withHarness $ \environment -> do
  first <- createProvisionalWork environment "alpha" >>= brickFromResult environment
  second <- createProvisionalWork environment "bravo" >>= brickFromResult environment
  _ <- run environment (EffortCommand (ref first))
  _ <- run environment (EffortCommand (ref second))
  before <- loadState environment
  length (pendingJudgmentReviews before) @?= 1
  seedLottery environment first
  envelope <- drawUntil environment (\case EffortComparisonOpportunity{} -> True; _ -> False) 128
  _ <- answer environment envelope "effort.round.skip"
  after <- loadState environment
  stateWorkDeferrals after @?= stateWorkDeferrals before
  statePairJudgments after @?= statePairJudgments before
  assertBool "review was not cooled" (World.EffortComparisonOpportunity `notElem` offeredKinds after fixedTime)
  assertBool "Work disappeared on review skip" (World.FiniteWorkOpportunity `elem` offeredKinds after fixedTime)
  assertBool "review did not return at expiry" (World.EffortComparisonOpportunity `elem` offeredKinds after (addUTCTime 86400 fixedTime))
  forM_ (Map.elems (stateJudgmentReviews after)) $ \review -> judgmentReviewCooldown review @?= Just (addUTCTime 86400 fixedTime)
  _ <- run environment (EffortCommand (ref first))
  loadState environment >>= (@?= after)

scopeReview :: Assertion
scopeReview = withHarness $ \environment -> do
  first <- createProvisionalWork environment "alpha" >>= brickFromResult environment
  _ <- createProvisionalWork environment "bravo"
  classification <- run environment (EffortCommand (ref first)) >>= interactionOf
  _ <- answer environment classification "effort.class.easy"
  before <- loadState environment
  editor <- run environment (UpdateCommand (ref first) (Just "title")) >>= interactionOf
  preview <- submit environment editor "update.text.submit" "Alpha with an expanded outcome"
  _ <- answer environment preview "update.accept"
  after <- loadState environment
  stateEffortClaims after @?= stateEffortClaims before
  reviewClassDue after EffortAxis (brickId first) @?= True
  currentEffort after (brickId first) @?= Nothing
  assertBool "scope review was not offered" (World.EffortComparisonOpportunity `elem` offeredKinds after fixedTime)
  showResult <- run environment (ShowRawCommand (ref first) CompleteView)
  assertBool "inspection concealed stale class" (any (Text.isInfixOf "review due") (resultObjectDetails showResult))
  seedLottery environment first
  relative <- drawUntil environment (\case EffortComparisonOpportunity{} -> True; _ -> False) 128
  _ <- answer environment relative ("effort.choose." <> renderUUIDv7 (brickId first))
  relativeOnly <- loadState environment
  reviewClassDue relativeOnly EffortAxis (brickId first) @?= True
  currentEffort relativeOnly (brickId first) @?= Nothing
  renewed <- run environment (EffortCommand (ref first)) >>= interactionOf
  _ <- answer environment renewed "effort.class.hard"
  final <- loadState environment
  reviewClassDue final EffortAxis (brickId first) @?= False
  assertBool "reclassification did not restore current effort" (isJust (currentEffort final (brickId first)))

impactEvidenceReview :: Assertion
impactEvidenceReview = withHarness $ \environment -> do
  first <- createProvisionalWork environment "alpha" >>= brickFromResult environment
  classification <- run environment (ImpactCommand (ref first)) >>= interactionOf
  basis <- answer environment classification "impact.class.high"
  _ <- answer environment basis "impact.speculative"
  before <- loadState environment
  fed <- run environment (FeedCommand "test" "Pilot supporting evidence") >>= interactionOf
  destinations <- answer environment fed "raw.choose-destination"
  under <- answer environment destinations ("raw.destination.brick." <> renderUUIDv7 (brickId first))
  attach <- answer environment under "raw.attach"
  _ <- answer environment attach "raw.attach.evidence"
  after <- loadState environment
  stateImpactClaims after @?= stateImpactClaims before
  reviewClassDue after ImpactAxis (brickId first) @?= True
  assertBool "new support did not request review" (World.ImpactMaturityReviewOpportunity `elem` offeredKinds after fixedTime)
  seedLottery environment first
  envelope <- drawUntil environment (\case ImpactEvidenceReviewOpportunity{} -> True; _ -> False) 128
  _ <- answer environment envelope "impact.review.retain"
  final <- loadState environment
  reviewClassDue final ImpactAxis (brickId first) @?= False
  impactClaimMaturity (stateImpactClaims final Map.! brickId first) @?= SpeculativeImpact
  let archived = final{stateBricks = Map.adjust (\brick -> brick{brickStatus = BrickArchived}) (brickId first) (stateBricks final)}
      historicalChange = archived{stateBricks = Map.adjust (\brick -> brick{brickTitle = "Revised historical outcome"}) (brickId first) (stateBricks archived), stateRaws = Map.map (\raw -> raw{rawStatus = RawRetracted}) (stateRaws archived)}
  reviewChanges fixedTime archived historicalChange @?= []

easierWorkRecovery :: Assertion
easierWorkRecovery = withHarness $ \environment -> do
  bricks <- mapM (createProvisionalWork environment >=> brickFromResult environment) ["alpha", "bravo", "charlie", "delta"]
  let source = head bricks
  proposal <- run environment (FocusCommand (ref source)) >>= interactionOf
  skipped <- answer environment proposal "focus.skip"
  tired <- answer environment skipped "work.symptom.tired"
  shortlist <- answer environment tired "work.reaction.easier-work"
  state <- loadState environment
  stateCurrentFocus state @?= Nothing
  stateWorkDeferrals state @?= Map.empty
  stateEffortClaims state @?= Map.empty
  Map.keys (stateRandomCursors state) @?= ["easier_work_sample"]
  assertBool "missing evidence did not retain dedicated help" (not (null (pendingJudgmentReviews state)))
  restored <- run environment NextCommand >>= interactionOf
  restored @?= shortlist
  loadState environment >>= (@?= state)
  eitherDecode (encode shortlist) @?= Right shortlist
  case envelopeOpportunity shortlist of
    EasierWorkOpportunity owner _ candidates -> do
      owner @?= brickId source
      length candidates @?= 3
      assertBool "source appeared as easier work" (brickId source `notElem` candidates)
      let selected = head candidates
      offered <- answer environment shortlist ("work.easier.choose." <> renderUUIDv7 selected)
      envelopeOpportunity offered @?= FocusProposalOpportunity selected Nothing
      final <- loadState environment
      stateCurrentFocus final @?= Nothing
      stateEffortClaims final @?= Map.empty
      let contextual = [judgment | judgment <- Map.elems (statePairJudgments final), judgmentContext judgment == "easier_recovery"]
      length contextual @?= 2
      fmap judgmentInitialConfidence contextual @?= replicate 2 (Fixed 250000)
      assertBool "recovery erased the dedicated review" (not (null (pendingJudgmentReviews final)))
    other -> assertFailure (show other)

effortConflict :: Assertion
effortConflict = withHarness $ \environment -> do
  first <- createProvisionalWork environment "alpha" >>= brickFromResult environment
  second <- createProvisionalWork environment "bravo" >>= brickFromResult environment
  _ <- run environment (EffortCommand (ref first))
  seedLottery environment first
  initial <- drawUntil environment (\case EffortComparisonOpportunity{} -> True; _ -> False) 128
  _ <- answer environment initial ("effort.choose." <> renderUUIDv7 (brickId first))
  _ <- run environment (EffortCommand (ref second))
  next <- drawUntil environment (\case EffortComparisonOpportunity{} -> True; _ -> False) 128
  before <- loadState environment
  conflict <- answer environment next ("effort.choose." <> renderUUIDv7 (brickId second))
  assertBool "new answer bypassed fresh conflict gate" (case envelopeOpportunity conflict of EffortRoundConflictOpportunity{} -> True; _ -> False)
  loadState environment >>= (@?= before)
  revised <- answer environment conflict "effort.conflict.revise"
  loadState environment >>= (@?= before)
  conflictAgain <- answer environment revised ("effort.choose." <> renderUUIDv7 (brickId second))
  _ <- answer environment conflictAgain "effort.conflict.changed"
  after <- loadState environment
  length [judgment | judgment <- Map.elems (statePairJudgments after), judgmentStatus judgment == JudgmentCurrent] @?= 1

isolatedDemand :: Assertion
isolatedDemand = withHarness $ \environment -> do
  first <- createProvisionalWork environment "alpha" >>= brickFromResult environment
  _ <- run environment (EffortCommand (ref first))
  state <- loadState environment
  length (pendingJudgmentReviews state) @?= 1
  assertBool "one unit offered an invalid comparison" (World.EffortComparisonOpportunity `notElem` offeredKinds state fixedTime)
  assertBool "missing comparator blocked Work" (World.FiniteWorkOpportunity `elem` offeredKinds state fixedTime)

ref :: Brick -> Text
ref brick = "#" <> unHandle (brickHandle brick)

loadState :: AppEnv -> IO State
loadState environment = loadedState <$> (assertRight =<< loadDataset (appStore environment) (const (pure ())))

offeredKinds :: State -> UTCTime -> [World.SelectableOpportunityKind]
offeredKinds state now = [World.selectableKind opportunity | ticket <- World.buildForecastWorld state now, opportunity <- World.ticketOpportunities ticket]

seedLottery :: AppEnv -> Brick -> IO ()
seedLottery environment owner = do
  loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
  let selection = fixtureUuid 90000
      eventId = fixtureUuid 90001
      commandId = fixtureUuid 90002
      evidence = ForecastSelectionEvidence selection "little-ant-forecast-v1-factory" (ByteString.replicate 32 7) [(brickId owner, 1)] (brickId owner) (Just (brickId owner)) "finite_work" [brickId owner] Nothing Nothing [] [] Nothing
      event = EventDraft eventId commandId (appActor environment) fixedTime (statePreconditionHash (loadedState loaded)) [selection, eventId, commandId] (ForecastSelectedV1 (ForecastSelected evidence))
  _ <- assertRight =<< appendCommand (appStore environment) (loadedCursor loaded) [event]
  pure ()

drawUntil :: AppEnv -> (Opportunity -> Bool) -> Int -> IO InteractionEnvelope
drawUntil _ _ 0 = assertFailure "the deterministic test stream did not serve the requested review"
drawUntil environment matches attempts = do
  let checkpoint = storeRoot (appStore environment) </> "checkpoints" </> "pending-envelope.json"
  exists <- doesFileExist checkpoint
  when exists (removeFile checkpoint)
  envelope <- run environment NextCommand >>= interactionOf
  if matches (envelopeOpportunity envelope) then pure envelope else drawUntil environment matches (attempts - 1)

createProvisionalWork :: AppEnv -> Text -> IO InteractionEnvelope
createProvisionalWork environment material = do
  raw <- run environment (FeedCommand "test" material) >>= interactionOf
  nature <- answer environment raw "raw.materialize-work"
  templates <- answer environment nature "nature.choose.atomic_task"
  title <- answerPlainSetup environment templates
  comparisonOrPreview <- submit environment title "work.title.submit" (titleCase material)
  preview <- settle comparisonOrPreview
  answer environment preview "work.create"
 where
  settle envelope = case envelopeOpportunity envelope of
    WorkPreviewOpportunity{} -> pure envelope
    ImportanceInsertionOpportunity{} -> answer environment envelope "importance.skip" >>= settle
    other -> assertFailure ("unexpected creation step: " <> show other)

brickFromResult :: AppEnv -> InteractionEnvelope -> IO Brick
brickFromResult environment envelope = case envelopeOpportunity envelope of
  WorkCreatedResultOpportunity _ identity -> do
    loaded <- assertRight =<< loadDataset (appStore environment) (const (pure ()))
    maybe (assertFailure "created Brick is missing after replay") pure (Map.lookup identity (stateBricks (loadedState loaded)))
  other -> assertFailure ("expected Work result, got " <> show other)

assertJudgmentResult :: JudgmentAxis -> InteractionEnvelope -> Assertion
assertJudgmentResult axis envelope = case envelopeOpportunity envelope of
  JudgmentResultOpportunity actual _ _ -> actual @?= axis
  other -> assertFailure ("expected judgment result, got " <> show other)

withHarness :: (AppEnv -> IO a) -> IO a
withHarness action = withSystemTempDirectory "little-ant-s03" $ \root -> do
  counter <- newIORef (3000 :: Int)
  let allocate = atomicModifyIORef' counter $ \seed -> (seed + 1, fixtureUuid seed)
      environment =
        AppEnv
          (StoreConfig root 2000000 20000)
          (Actor "human" "test")
          (pure fixedTime)
          (pure (utcToZonedTime utc fixedTime))
          allocate
          emptyExportPort
          emptyImportPort
          Nothing
          Nothing
          Nothing
          Nothing
  action environment

run :: AppEnv -> AppCommand -> IO CommandResult
run environment command = assertRight =<< runAppCommand environment False (const (pure ())) command

interactionOf :: CommandResult -> IO InteractionEnvelope
interactionOf = \case
  NextResult{resultInteraction} -> pure resultInteraction
  FeedResult{resultInteraction} -> pure resultInteraction
  RespondResult{resultInteraction} -> pure resultInteraction
  other -> assertFailure ("result has no interaction: " <> show other)

-- | The plain setup: no Template, or the generic digital task for an atomic task.
answerPlainSetup :: AppEnv -> InteractionEnvelope -> IO InteractionEnvelope
answerPlainSetup environment envelope = case envelopeOpportunity envelope of
  TemplateSettingOpportunity{} -> answer environment envelope "template.setting.digital" >>= \digital -> answer environment digital "template.choose.digital_task"
  _ -> answer environment envelope "template.none"

answer :: AppEnv -> InteractionEnvelope -> Text -> IO InteractionEnvelope
answer environment envelope action = run environment (RespondCommand (response envelope action)) >>= interactionOf

submit :: AppEnv -> InteractionEnvelope -> Text -> Text -> IO InteractionEnvelope
submit environment envelope action value = run environment (SubmitInteractionTextCommand (response envelope action) value) >>= interactionOf

navigate :: AppEnv -> InteractionEnvelope -> Bool -> IO InteractionEnvelope
navigate environment envelope backward =
  run environment (if backward then NavigateBackCommand request else NavigateForwardCommand request) >>= interactionOf
 where
  request = response envelope (if backward then "navigation.back" else "navigation.forward")

response :: InteractionEnvelope -> Text -> InteractionResponse
response envelope action = InteractionResponse (envelopeInteractionId envelope) (envelopeRevision envelope) action (envelopeIntegrityToken envelope) (envelopeDatasetCursor envelope)

titleCase :: Text -> Text
titleCase value = case Text.uncons value of
  Just (character, rest) | isAsciiLower character -> Text.cons (toEnum (fromEnum character - 32)) rest
  _ -> value

fixtureUuid :: Int -> UUIDv7
fixtureUuid seed = either (error . show) id $ uuidV7FromEntropy (0x0198f8a34c21 + fromIntegral seed) (ByteString.replicate 10 (fromIntegral (seed `mod` 251 + 1)))

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 8 3) (secondsToDiffTime (12 * 3600))

assertRight :: (Show left) => Either left right -> IO right
assertRight = either (assertFailure . show) pure

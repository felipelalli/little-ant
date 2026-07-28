{-# LANGUAGE DerivingStrategies #-}

-- | Executable Allium probes for Brick mutation and coordinated lifecycle.
module LittleAnt.V1.ExecutionPlanCatalog
  ( executionLifecyclePlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson (Value (..), toJSON)
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime (..), addUTCTime, fromGregorian)
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Domain
import LittleAnt.V1.Execution
import qualified LittleAnt.V1.Judgment as Judgment
import qualified LittleAnt.V1.Priority as Priority
import qualified LittleAnt.V1.Standing as Standing

executionLifecyclePlanProbes :: Map ProbeKey PlanProbe
executionLifecyclePlanProbes = Map.fromList
  ( registrations ["rule_success", "rule_failure"] metadataConstructs metadataProbe
  <> registrations ["rule_success", "rule_failure"] focusConstructs focusProbe
  <> registrations ["rule_success", "rule_failure"] lifecycleConstructs lifecycleProbe
  <> registrations ["rule_success", "rule_failure"] moveConstructs moveProbe
  <> registrations ["rule_entity_creation"] moveConstructs moveProbe
  <> [ registration "config_default" "config.soft_wip_limit" focusProbe
     , registration "invariant" "DelegationDoesNotConsumeHumanWip" focusProbe
     , registration "invariant" "RootPriorityBindingIsCanonical" bindingProbe
     , registration "invariant" "StandardBehaviorBindingIsCanonical" bindingProbe
     , registration "surface_actor" "WorkDesk" workDeskActorProbe
     , registration "surface_exposure" "WorkDesk" workDeskExposureProbe
     , registration "surface_provides" "WorkDesk" workDeskProvidesProbe
     , registration "surface_actor" "DeterministicClock" deterministicClockProbe
     , registration "surface_provides" "DeterministicClock" deterministicClockProbe
     ]
  )
  where
    registrations categories constructs probe =
      [registration category construct probe
      | category <- categories, construct <- constructs]
    registration category construct probe =
      ( ProbeKey "execution" category construct
      , semanticProbe category construct probe
      )

metadataConstructs :: [Text]
metadataConstructs =
  [ "BrickRenamed"
  , "BrickOriginalTitleSet", "BrickOriginalTitleCleared"
  , "BrickDescribed", "BrickDescriptionCleared"
  , "BrickPhaseSet", "BrickPhaseCleared"
  , "BrickContextSet", "BrickContextCleared"
  , "BrickModeSet", "BrickModeCleared"
  , "BrickNotBeforeSet", "BrickNotBeforeCleared"
  , "BrickBestBeforeSet", "BrickBestBeforeCleared"
  , "BrickDeadlineSet", "BrickDeadlineCleared"
  , "BrickRequesterSet", "BrickRequesterCleared"
  , "BrickAboutSet", "BrickAboutCleared"
  ]

focusConstructs :: [Text]
focusConstructs =
  [ "IdleBrickFocused", "ExistingWipFocused"
  , "CurrentBrickUnfocused", "WipReturnedToIdle"
  ]

lifecycleConstructs :: [Text]
lifecycleConstructs =
  [ "FiniteBrickCompletedDirectly", "StandingBrickRetiredAsDone"
  , "LeafBrickDropped", "BrickSupersededByExistingBrick"
  , "BrickSupersededWithExplicitChildTransfer"
  , "WholeSubtreeCompleted", "WholeSubtreeDropped"
  , "TerminalRootRemovedFromPriority", "TerminalChildRemovedFromPriority"
  , "LastActiveChildClosed"
  ]

moveConstructs :: [Text]
moveConstructs = ["ActiveSubtreeMoved", "ActiveSubtreeMovedToRoot"]

semanticProbe :: Text -> Text -> Either Text () -> PlanProbe
semanticProbe category construct probe input = do
  require (planProbeModule input == "execution")
    "execution probe received the wrong module"
  require (planProbeCategory input == category)
    "execution probe received the wrong category"
  require (planProbeSourceConstruct input == construct)
    "execution probe received the wrong semantic construct"
  probe

metadataProbe :: Either Text ()
metadataProbe = do
  (party, first) <- domain (createParty "Requester" Person probeTime emptyDomainState)
  parentTitle <- domain (mkCanonicalText "Parent" Nothing Human)
  let parentDraft = (ordinaryBrickDraft parentTitle projectV1 probeTime)
        {brickDraftContext = Just "office", brickDraftMode = Just Digital}
  (parent, second) <- domain (createBrick parentDraft first)
  childTitle <- domain (mkCanonicalText "Child" (Just "Filho") Human)
  (child, third) <- domain (createBrick
    ((ordinaryBrickDraft childTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId parent)}) second)
  aboutTitle <- domain (mkCanonicalText "About target" Nothing Human)
  (about, fourth) <- domain (createBrick
    (ordinaryBrickDraft aboutTitle standardV1 probeTime) third)
  (renamed, fifth) <- domain
    (renameBrick (brickId child) "Renamed child" Ai fourth)
  require (brickId renamed == brickId child && brickOriginalTitle renamed == Just "Filho"
      && brickTitleAuthority renamed == Ai)
    "rename changed identity/provenance or lost authority"
  expectDomainFailure (renameBrick (brickId child) " invalid " Human fifth)
    "non-canonical rename was accepted"
  (withOriginal, sixth) <- domain
    (setBrickOriginalTitle (brickId child) "Criança" fifth)
  require (brickOriginalTitle withOriginal == Just "Criança")
    "original title was not set verbatim"
  (_, seventh) <- domain (clearBrickOriginalTitle (brickId child) sixth)
  expectDomainFailure (clearBrickOriginalTitle (brickId child) seventh)
    "absent original title was cleared"
  (described, eighth) <- domain
    (describeBrick (brickId child) "Canonical scope" seventh)
  require (brickDescriptionRevision described == 1)
    "description revision did not advance"
  (descriptionCleared, ninth) <- domain
    (clearBrickDescription (brickId child) eighth)
  require (brickDescriptionRevision descriptionCleared == 2)
    "description clear did not advance revision"
  expectDomainFailure (clearBrickDescription (brickId child) ninth)
    "absent description was cleared"
  (phased, tenth) <- domain
    (setBrickPhase (brickId child) (Just Exec) (Just Human) ninth)
  require (brickPhase phased == Just Exec && brickPhaseAuthority phased == Just Human)
    "phase and authority were not stored together"
  (_, eleventh) <- domain (clearBrickPhase (brickId child) tenth)
  collectionTitle <- domain (mkCanonicalText "Collection" Nothing Human)
  (collection, twelfth) <- domain (createBrick
    (ordinaryBrickDraft collectionTitle collectionV1 probeTime) eleventh)
  expectDomainFailure
    (setBrickPhase (brickId collection) (Just Idea) (Just Human) twelfth)
    "phase-disabled behavior accepted a phase"
  expectDomainFailure (clearBrickPhase (brickId collection) twelfth)
    "phase-disabled behavior accepted a phase clear"
  (contextual, thirteenth) <- domain
    (setBrickContext (brickId child) "home" twelfth)
  effectiveChildContext <- domain (effectiveContext thirteenth (brickId child))
  require (effectiveChildContext == Just "home") "explicit context did not override parent"
  (_, fourteenth) <- domain (clearBrickContext (brickId child) thirteenth)
  inheritedContext <- domain (effectiveContext fourteenth (brickId child))
  require (inheritedContext == Just "office") "cleared context did not reveal nearest ancestor"
  expectDomainFailure (clearBrickContext (brickId child) fourteenth)
    "absent context was cleared"
  (_, fifteenth) <- domain (setBrickMode (brickId child) Physical fourteenth)
  childMode <- domain (effectiveMode fifteenth (brickId child))
  require (childMode == Just Physical) "explicit mode did not override parent"
  (_, sixteenth) <- domain (clearBrickMode (brickId child) fifteenth)
  inheritedMode <- domain (effectiveMode sixteenth (brickId child))
  require (inheritedMode == Just Digital) "cleared mode did not reveal nearest ancestor"
  expectDomainFailure (clearBrickMode (brickId child) sixteenth)
    "absent mode was cleared"
  let notBefore = addUTCTime 10 probeTime
      bestBefore = addUTCTime 20 probeTime
      deadline = addUTCTime 30 probeTime
  (withNotBefore, seventeenth) <- domain
    (setBrickNotBefore (brickId child) notBefore sixteenth)
  (withBestBefore, eighteenth) <- domain
    (setBrickBestBefore (brickId child) bestBefore seventeenth)
  (withDeadline, nineteenth) <- domain
    (setBrickDeadline (brickId child) deadline eighteenth)
  require (map brickDateRevision [withNotBefore, withBestBefore, withDeadline]
      == [1, 2, 3])
    "date setters did not atomically advance one local revision each"
  (_, twentieth) <- domain (clearBrickNotBefore (brickId child) nineteenth)
  (_, twentyFirst) <- domain (clearBrickBestBefore (brickId child) twentieth)
  (datesCleared, twentySecond) <- domain
    (clearBrickDeadline (brickId child) twentyFirst)
  require (brickDateRevision datesCleared == 6)
    "date clears did not advance the local revision"
  expectDomainFailure (clearBrickDeadline (brickId child) twentySecond)
    "absent deadline was cleared"
  (requested, twentyThird) <- domain
    (setBrickRequester (brickId child) (partyId party) twentySecond)
  require (brickRequester requested == Just (partyId party)) "requester was not stored"
  (_, twentyFourth) <- domain (clearBrickRequester (brickId child) twentyThird)
  expectDomainFailure (clearBrickRequester (brickId child) twentyFourth)
    "absent requester was cleared"
  (related, twentyFifth) <- domain
    (setBrickAbout (brickId child) (brickId about) twentyFourth)
  require (brickAbout related == Just (brickId about)) "about relationship was not stored"
  expectDomainFailure
    (setBrickAbout (brickId child) (brickId child) twentyFifth)
    "self-about relationship was accepted"
  (_, twentySixth) <- domain (clearBrickAbout (brickId child) twentyFifth)
  expectDomainFailure (clearBrickAbout (brickId child) twentySixth)
    "absent about relationship was cleared"
  (closed, terminal) <- domain
    (transitionBrickStatus (brickId child) MarkDone probeTime twentySixth)
  require (brickStatus closed == Done) "metadata fixture did not become terminal"
  expectDomainFailure (renameBrick (brickId child) "Too late" Human terminal)
    "terminal metadata mutation was accepted"
  require (all ((> EntityRevision 1) . brickRevision)
      [renamed, withOriginal, described, descriptionCleared, phased, contextual,
       withNotBefore, withBestBefore, withDeadline, datesCleared, requested, related])
    "accepted metadata mutation did not advance the Brick revision"

focusProbe :: Either Text ()
focusProbe = do
  require (softWipLimit == 3) "soft WIP limit is not the declared default of three"
  titleA <- domain (mkCanonicalText "A" Nothing Human)
  (a, _, first) <- execution
    (createExecutionBrick (ordinaryBrickDraft titleA standardV1 probeTime)
      "focus-a" probeTime emptyExecutionState)
  titleB <- domain (mkCanonicalText "B" Nothing Human)
  (b, _, second) <- execution
    (createExecutionBrick (ordinaryBrickDraft titleB standardV1 probeTime)
      "focus-b" probeTime first)
  focusedA <- execution (focusExecutionBrick (brickId a) probeTime second)
  require (activeHumanWipCount focusedA == 1)
    "focusing idle work did not create one human WIP"
  focusedB <- execution
    (focusExecutionBrick (brickId b) (addUTCTime 1 probeTime) focusedA)
  let focusedDomain = executionStateDomain focusedB
      aAfter = Map.lookup (brickId a) (domainBricks focusedDomain)
      bAfter = Map.lookup (brickId b) (domainBricks focusedDomain)
  require (fmap brickWorkState aAfter == Just Wip
      && fmap brickWorkState bAfter == Just Wip
      && focusRegisterCurrent (domainFocusRegister focusedDomain) == Just (brickId b)
      && activeHumanWipCount focusedB == 2)
    "refocus did not preserve multiple WIPs with singleton current focus"
  refocused <- execution
    (focusExecutionBrick (brickId a) (addUTCTime 2 probeTime) focusedB)
  require (focusRegisterCurrent (domainFocusRegister (executionStateDomain refocused))
      == Just (brickId a))
    "existing WIP could not be focused again"
  delegated <- execution
    (delegateExecutionBrick (brickId b) (addUTCTime 3 probeTime) refocused)
  require (activeHumanWipCount delegated == 1)
    "delegation consumed a human WIP slot"
  (_, unfocusedDomain) <- domain
    (unfocusCurrentBrick (addUTCTime 4 probeTime) (executionStateDomain delegated))
  (_, idleDomain) <- domain (returnBrickToIdle (brickId a) unfocusedDomain)
  require (focusRegisterCurrent (domainFocusRegister idleDomain) == Nothing)
    "explicit unfocus did not clear current focus"
  expectDomainFailure (returnBrickToIdle (brickId a) idleDomain)
    "idle Brick returned to idle again"
  let futureDraft = (ordinaryBrickDraft titleA standardV1 probeTime)
        {brickDraftNotBefore = Just (addUTCTime 100 probeTime)}
  (future, futureState) <- domain (createBrick futureDraft emptyDomainState)
  expectDomainFailure (focusBrick (Just (brickId future)) probeTime futureState)
    "temporally ineligible Brick was focused"

lifecycleProbe :: Either Text ()
lifecycleProbe = do
  projectTitle <- domain (mkCanonicalText "Finite parent" Nothing Human)
  (parent, _, first) <- execution (createExecutionBrick
    (ordinaryBrickDraft projectTitle projectV1 probeTime) "parent" probeTime
    emptyExecutionState)
  childTitle <- domain (mkCanonicalText "Only child" Nothing Human)
  (child, _, second) <- execution (createExecutionBrick
    ((ordinaryBrickDraft childTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId parent)}) "child" probeTime first)
  expectExecutionFailure (completeExecutionBrick (brickId parent) probeTime second)
    "finite parent with an active child completed directly"
  childClosed <- execution
    (completeExecutionBrick (brickId child) probeTime second)
  require (Set.member (brickId parent) (executionStateParentReviews childClosed))
    "last active finite child did not suggest parent review"
  require (fmap brickStatus (Map.lookup (brickId parent)
      (domainBricks (executionStateDomain childClosed))) == Just Active)
    "closing the final child cascaded completion"
  parentClosed <- execution
    (completeExecutionBrick (brickId parent) probeTime childClosed)
  require (priorityAbsent (brickId parent) parentClosed
      && priorityAbsent (brickId child) parentClosed)
    "terminal root/child remained in active priority"
  standingTitle <- domain (mkCanonicalText "Standing" Nothing Human)
  (standing, _, standingState) <- execution (createExecutionBrick
    (ordinaryBrickDraft standingTitle collectionV1 probeTime) "standing" probeTime
    parentClosed)
  expectExecutionFailure (completeExecutionBrick (brickId standing) probeTime standingState)
    "standing Brick used finite direct completion"
  standingClosed <- execution
    (retireStandingExecutionBrick (brickId standing) probeTime standingState)
  require (priorityAbsent (brickId standing) standingClosed)
    "retired standing Brick remained in active priority"
  dropTitle <- domain (mkCanonicalText "Drop me" Nothing Human)
  (dropMe, _, dropState) <- execution (createExecutionBrick
    (ordinaryBrickDraft dropTitle standardV1 probeTime) "drop" probeTime standingClosed)
  dropped <- execution (dropExecutionBrick (brickId dropMe) probeTime dropState)
  require (brickStatusFor (brickId dropMe) dropped == Just Dropped)
    "leaf drop did not retain dropped status"
  supersedeTransferProbe dropped
  subtreeCloseProbe

supersedeTransferProbe :: ExecutionState -> Either Text ()
supersedeTransferProbe initial = do
  sourceTitle <- domain (mkCanonicalText "Old plan" Nothing Human)
  (source, _, first) <- execution (createExecutionBrick
    (ordinaryBrickDraft sourceTitle projectV1 probeTime) "source" probeTime initial)
  replacementTitle <- domain (mkCanonicalText "New plan" Nothing Human)
  (replacement, _, second) <- execution (createExecutionBrick
    (ordinaryBrickDraft replacementTitle projectV1 probeTime) "replacement" probeTime first)
  firstChildTitle <- domain (mkCanonicalText "First child" Nothing Human)
  (firstChild, _, third) <- execution (createExecutionBrick
    ((ordinaryBrickDraft firstChildTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId source)}) "first-child" probeTime second)
  secondChildTitle <- domain (mkCanonicalText "Second child" Nothing Human)
  (secondChild, _, fourth) <- execution (createExecutionBrick
    ((ordinaryBrickDraft secondChildTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId source)}) "second-child" probeTime third)
  expectExecutionFailure
    (supersedeExecutionBrick (brickId source) (brickId replacement) Nothing probeTime fourth)
    "supersession silently abandoned active children"
  expectExecutionFailure
    (supersedeExecutionBrickWithChildren (brickId source) (brickId replacement)
      [brickId firstChild] Nothing "incomplete" probeTime fourth)
    "partial explicit child transfer was accepted"
  sourceScope <- findScope (Just (brickId source)) (executionStatePriority fourth)
  (_, _, withEvidencePriority) <- priority (Priority.recordPriorityJudgment
    (Priority.priorityScopeId sourceScope) (brickId firstChild) (brickId secondChild)
    Human (Just "old scope") probeTime (executionStatePriority fourth))
  let withEvidence = fourth {executionStatePriority = withEvidencePriority}
  (insertions, transferred) <- execution
    (supersedeExecutionBrickWithChildren (brickId source) (brickId replacement)
      [brickId firstChild, brickId secondChild] (Just "scope replaced")
      "transfer" probeTime withEvidence)
  require (length insertions == 2
      && all ((== Priority.InsertionDeferred) . Priority.priorityInsertionStatus)
        insertions)
    "explicit transfer did not create deferred provisional insertions"
  require (brickStatusFor (brickId source) transferred == Just Superseded)
    "superseded identity did not retain terminal status"
  sourceBrick <- lookupExecutionBrick (brickId source) transferred
  require (brickSupersededBy sourceBrick == Just (brickId replacement)
      && brickSupersedeReason sourceBrick == Just "scope replaced")
    "superseded identity/reason were not preserved"
  mapM_ (\identifier -> do
      child <- lookupExecutionBrick identifier transferred
      require (brickParent child == Just (brickId replacement))
        "transferred child did not rebind to replacement")
    [brickId firstChild, brickId secondChild]
  require (all (not . Priority.priorityJudgmentApplicable)
      (Map.elems (Priority.priorityStateJudgments
        (executionStatePriority transferred))))
    "old-scope evidence was deleted or remained applicable"

subtreeCloseProbe :: Either Text ()
subtreeCloseProbe = do
  rootTitle <- domain (mkCanonicalText "Tree" Nothing Human)
  (root, _, first) <- execution (createExecutionBrick
    (ordinaryBrickDraft rootTitle projectV1 probeTime) "tree" probeTime
    emptyExecutionState)
  childTitle <- domain (mkCanonicalText "Branch" Nothing Human)
  (child, _, second) <- execution (createExecutionBrick
    ((ordinaryBrickDraft childTitle projectV1 probeTime)
      {brickDraftParent = Just (brickId root)}) "branch" probeTime first)
  leafTitle <- domain (mkCanonicalText "Leaf" Nothing Human)
  (leaf, _, third) <- execution (createExecutionBrick
    ((ordinaryBrickDraft leafTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId child)}) "leaf" probeTime second)
  completed <- execution
    (closeExecutionSubtree (brickId root) Done probeTime third)
  require (all ((== Just Done) . (`brickStatusFor` completed))
      [brickId root, brickId child, brickId leaf])
    "whole-subtree completion was partial"
  require (all (`priorityAbsent` completed)
      [brickId root, brickId child, brickId leaf])
    "completed subtree remained in active priority"
  expectExecutionFailure
    (closeExecutionSubtree (brickId root) Dropped probeTime completed)
    "terminal subtree closed twice"
  dropRootTitle <- domain (mkCanonicalText "Drop tree" Nothing Human)
  (dropRoot, _, dropFirst) <- execution (createExecutionBrick
    (ordinaryBrickDraft dropRootTitle projectV1 probeTime) "drop-tree" probeTime
    emptyExecutionState)
  dropChildTitle <- domain (mkCanonicalText "Drop branch" Nothing Human)
  (dropChild, _, dropSecond) <- execution (createExecutionBrick
    ((ordinaryBrickDraft dropChildTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId dropRoot)}) "drop-branch" probeTime dropFirst)
  allDropped <- execution
    (closeExecutionSubtree (brickId dropRoot) Dropped probeTime dropSecond)
  require (all ((== Just Dropped) . (`brickStatusFor` allDropped))
      [brickId dropRoot, brickId dropChild])
    "whole-subtree drop was partial"

bindingProbe :: Either Text ()
bindingProbe = do
  title <- domain (mkCanonicalText "Canonical binding" Nothing Human)
  (brick, _, state) <- execution (createExecutionBrick
    (ordinaryBrickDraft title standardV1 probeTime) "binding" probeTime
    emptyExecutionState)
  root <- maybe (Left "canonical root priority scope is absent") Right
    (Map.lookup Priority.priorityRootScopeId
      (Priority.priorityStateScopes (executionStatePriority state)))
  require (Priority.priorityScopeParent root == Nothing
      && brickId brick `elem` Priority.priorityScopeMembers root)
    "root priority binding is not the parentless canonical scope"
  require (behaviorId (brickBehavior brick) == behaviorId standardV1
      && behaviorId standardV1 == "core/standard"
      && catalogContainsBehavior (domainCatalog (executionStateDomain state))
        (brickBehavior brick))
    "standard behavior binding is not the canonical catalog definition"

workDeskActorProbe :: Either Text ()
workDeskActorProbe = do
  (user, _, focused) <- workDeskFixture
  _ <- execution (workDeskProjection (partyId user) focused)
  (agent, domainWithAgent) <- domain (createParty "Synthetic agent" AiAgent
    probeTime (executionStateDomain focused))
  let withAgent = focused {executionStateDomain = domainWithAgent}
  case workDeskProjection (partyId agent) withAgent of
    Left _ -> Right ()
    Right _ -> Left "non-person Party obtained the user-facing WorkDesk"

workDeskExposureProbe :: Either Text ()
workDeskExposureProbe = do
  (user, brick, focused) <- workDeskFixture
  value <- execution (workDeskProjection (partyId user) focused)
  fields <- asObject "WorkDesk" value
  userFields <- case KeyMap.lookup "user" fields of
    Just (Object values) -> Right values
    _ -> Left "WorkDesk user exposure is not an object"
  require (KeyMap.lookup "id" userFields == Just (toJSON (partyId user))
      && KeyMap.lookup "current" fields == Just (toJSON (Just (brickId brick))))
    "WorkDesk did not expose user.id and the live current focus"

workDeskProvidesProbe :: Either Text ()
workDeskProvidesProbe = do
  workDeskExposureProbe
  metadataProbe
  focusProbe
  lifecycleProbe
  moveProbe

-- The clock has no user-facing actor: callers supply the instant explicitly.
-- Reapplying one instant must not release a second occurrence for its key.
deterministicClockProbe :: Either Text ()
deterministicClockProbe = do
  title <- domain (mkCanonicalText "Synthetic monthly obligation" Nothing Human)
  (owner, _, first) <- mapStanding (Standing.createStandingBrick
    (ordinaryBrickDraft title recurringObligationV1 probeTime)
    "clock:owner" probeTime Standing.emptyStandingState)
  let releaseAt = addUTCTime 60 probeTime
  (rule, scheduled) <- mapStanding (Standing.configureRecurrence (brickId owner)
    Standing.ObligationRecurrence "monthly on day 1" "UTC" releaseAt
    probeTime first)
  (beforeOccurrences, _, before) <- mapStanding
    (Standing.advanceSchedules (addUTCTime 59 probeTime) scheduled)
  (released, _, atRelease) <- mapStanding
    (Standing.advanceSchedules releaseAt before)
  (repeated, _, replayed) <- mapStanding
    (Standing.advanceSchedules releaseAt atRelease)
  let retained = Standing.obligationOccurrencesFor
        (Standing.recurrenceRuleId rule) Nothing replayed
      retainedAt = case retained of
        [occurrence] -> Just (Standing.obligationOccurrenceReleasedAt occurrence)
        _ -> Nothing
  require (null beforeOccurrences && length released == 1 && null repeated
      && retainedAt == Just releaseAt)
    "explicit deterministic clock duplicated or mistimed a schedule release"

workDeskFixture :: Either Text (Party, Brick, ExecutionState)
workDeskFixture = do
  (user, domainWithUser) <- domain
    (createParty "Synthetic user" Person probeTime emptyDomainState)
  title <- domain (mkCanonicalText "Focused desk work" Nothing Human)
  (brick, _, created) <- execution (createExecutionBrick
    (ordinaryBrickDraft title standardV1 probeTime) "work-desk" probeTime
    emptyExecutionState {executionStateDomain = domainWithUser})
  focused <- execution (focusExecutionBrick (brickId brick) probeTime created)
  pure (user, brick, focused)

asObject :: Text -> Value -> Either Text (KeyMap.KeyMap Value)
asObject _ (Object fields) = Right fields
asObject label _ = Left (label <> " projection is not an object")

moveProbe :: Either Text ()
moveProbe = do
  firstTitle <- domain (mkCanonicalText "First parent" Nothing Human)
  (firstParent, _, first) <- execution (createExecutionBrick
    (ordinaryBrickDraft firstTitle projectV1 probeTime) "first" probeTime
    emptyExecutionState)
  secondTitle <- domain (mkCanonicalText "Second parent" Nothing Human)
  (secondParent, _, second) <- execution (createExecutionBrick
    (ordinaryBrickDraft secondTitle projectV1 probeTime) "second" probeTime first)
  movedTitle <- domain (mkCanonicalText "Moved root" Nothing Human)
  (movedRoot, _, third) <- execution (createExecutionBrick
    ((ordinaryBrickDraft movedTitle projectV1 probeTime)
      {brickDraftParent = Just (brickId firstParent)}) "moved" probeTime second)
  siblingTitle <- domain (mkCanonicalText "Old sibling" Nothing Human)
  (oldSibling, _, fourth) <- execution (createExecutionBrick
    ((ordinaryBrickDraft siblingTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId firstParent)}) "old-sibling" probeTime third)
  targetTitle <- domain (mkCanonicalText "Target sibling" Nothing Human)
  (_, _, fifth) <- execution (createExecutionBrick
    ((ordinaryBrickDraft targetTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId secondParent)}) "target" probeTime fourth)
  grandchildTitle <- domain (mkCanonicalText "Grandchild" Nothing Human)
  (grandchild, _, sixth) <- execution (createExecutionBrick
    ((ordinaryBrickDraft grandchildTitle standardV1 probeTime)
      {brickDraftParent = Just (brickId movedRoot)}) "grandchild" probeTime fifth)
  oldScope <- findScope (Just (brickId firstParent)) (executionStatePriority sixth)
  (_, _, withEvidencePriority) <- priority (Priority.recordPriorityJudgment
    (Priority.priorityScopeId oldScope) (brickId movedRoot) (brickId oldSibling)
    Human Nothing probeTime (executionStatePriority sixth))
  let withEvidence = sixth {executionStatePriority = withEvidencePriority}
  (insertion, moved) <- execution (moveExecutionSubtree (brickId movedRoot)
    (Just (brickId secondParent)) "move" probeTime withEvidence)
  require (Priority.priorityInsertionStatus insertion == Priority.InsertionDeferred)
    "nonempty new scope did not receive provisional deferred placement"
  movedBrick <- lookupExecutionBrick (brickId movedRoot) moved
  descendant <- lookupExecutionBrick (brickId grandchild) moved
  require (brickId movedBrick == brickId movedRoot
      && brickParent movedBrick == Just (brickId secondParent)
      && brickParent descendant == Just (brickId movedRoot))
    "move changed identity or internal descendant structure"
  let judgments = Map.elems
        (Priority.priorityStateJudgments (executionStatePriority moved))
  require (all (not . Priority.priorityJudgmentApplicable) judgments)
    "old-scope movement evidence did not become historical"
  expectExecutionFailure (moveExecutionSubtree (brickId secondParent)
    (Just (brickId grandchild)) "cycle" probeTime moved)
    "move accepted a composition cycle"
  (rootInsertion, rooted) <- execution (moveExecutionSubtree (brickId movedRoot)
    Nothing "to-root" probeTime moved)
  require (brickParentFor (brickId movedRoot) rooted == Just Nothing
      && Priority.priorityInsertionBrick rootInsertion == brickId movedRoot)
    "move-to-root did not preserve/rebind the moved identity"
  (movedImpact, _, firstImpact) <- judgment (Judgment.classifyImpact
    (brickId movedRoot) Judgment.HighImpact Judgment.Supported Human
    (Just "root scope before nesting") probeTime (executionStateJudgment rooted))
  (_, _, secondImpact) <- judgment (Judgment.classifyImpact
    (brickId secondParent) Judgment.LowImpact Judgment.Supported Human
    (Just "target root") probeTime firstImpact)
  (comparison, _, withImpact) <- judgment (Judgment.compareImpact
    (brickId movedRoot) (brickId secondParent) Judgment.RelativelyMore Human
    (Just "root comparison before nesting") probeTime secondImpact)
  let impactAssessmentCount = Map.size (Judgment.judgmentStateImpactAssessments withImpact)
      impactComparisonCount = Map.size (Judgment.judgmentStateImpactComparisons withImpact)
      withRootEvidence = rooted {executionStateJudgment = withImpact}
  (_, nested) <- execution (moveExecutionSubtree (brickId movedRoot)
    (Just (brickId secondParent)) "root-to-child" probeTime withRootEvidence)
  let nestedJudgment = executionStateJudgment nested
  require (fmap Judgment.impactAssessmentApplicable
      (Map.lookup (Judgment.impactAssessmentId movedImpact)
        (Judgment.judgmentStateImpactAssessments nestedJudgment)) == Just False)
    "root-to-child move did not retire the moved root's impact assessment"
  require (fmap Judgment.impactComparisonApplicable
      (Map.lookup (Judgment.impactComparisonId comparison)
        (Judgment.judgmentStateImpactComparisons nestedJudgment)) == Just False)
    "root-to-child move did not retire the moved root's impact comparison"
  require (Map.size (Judgment.judgmentStateImpactAssessments nestedJudgment)
      == impactAssessmentCount
      && Map.size (Judgment.judgmentStateImpactComparisons nestedJudgment)
        == impactComparisonCount)
    "root-to-child move deleted historical impact evidence"

findScope :: Maybe BrickId -> Priority.PriorityState -> Either Text Priority.PriorityScope
findScope parent priorityState = case
    filter ((== parent) . Priority.priorityScopeParent)
      (Map.elems (Priority.priorityStateScopes priorityState)) of
  [scope] -> Right scope
  _ -> Left "expected exactly one priority scope for parent"

lookupExecutionBrick :: BrickId -> ExecutionState -> Either Text Brick
lookupExecutionBrick identifier state = maybe
  (Left "execution Brick is missing") Right
  (Map.lookup identifier (domainBricks (executionStateDomain state)))

brickStatusFor :: BrickId -> ExecutionState -> Maybe BrickStatus
brickStatusFor identifier state = brickStatus <$> Map.lookup identifier
  (domainBricks (executionStateDomain state))

brickParentFor :: BrickId -> ExecutionState -> Maybe (Maybe BrickId)
brickParentFor identifier state = brickParent <$> Map.lookup identifier
  (domainBricks (executionStateDomain state))

priorityAbsent :: BrickId -> ExecutionState -> Bool
priorityAbsent identifier state = all
  (notElem identifier . Priority.priorityScopeMembers)
  (Map.elems (Priority.priorityStateScopes (executionStatePriority state)))

probeTime :: UTCTime
probeTime = UTCTime (fromGregorian 2026 7 27) 0

expectDomainFailure :: Either DomainError value -> Text -> Either Text ()
expectDomainFailure result problem = case result of
  Left _ -> Right ()
  Right _ -> Left problem

expectExecutionFailure :: Either ExecutionError value -> Text -> Either Text ()
expectExecutionFailure result problem = case result of
  Left _ -> Right ()
  Right _ -> Left problem

domain :: Either DomainError value -> Either Text value
domain = either (Left . Text.pack . show) Right

execution :: Either ExecutionError value -> Either Text value
execution = either (Left . Text.pack . show) Right

priority :: Either Priority.PriorityError value -> Either Text value
priority = either (Left . Text.pack . show) Right

judgment :: Either Judgment.JudgmentError value -> Either Text value
judgment = either (Left . Text.pack . show) Right

mapStanding :: Either Standing.StandingError value -> Either Text value
mapStanding = either (Left . Text.pack . show) Right

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

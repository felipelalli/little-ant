{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

-- | Atomic composition of Brick lifecycle state and sibling priority.
--
-- Domain mutations are pure, so a failed coordinated action cannot expose a
-- partially moved tree or a priority state that disagrees with composition.
module LittleAnt.V1.Execution
  ( ExecutionError (..)
  , ExecutionRecord (..)
  , ExecutionState (..)
  , activeHumanWipCount
  , closeExecutionSubtree
  , createExecutionBrick
  , delegateExecutionBrick
  , dropExecutionBrick
  , emptyExecutionState
  , focusExecutionBrick
  , moveExecutionSubtree
  , retireStandingExecutionBrick
  , softWipLimit
  , supersedeExecutionBrick
  , supersedeExecutionBrickWithChildren
  , completeExecutionBrick
  , validateExecutionState
  ) where

import Control.Monad (foldM, unless)
import Data.Aeson
  (FromJSON (parseJSON), ToJSON (toJSON), defaultOptions, genericParseJSON,
   genericToJSON)
import qualified Data.Aeson.Types as AesonTypes
import Data.Char (toLower)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import LittleAnt.V1.Domain
  (Applicability (..), Brick (..), BrickClosure (..), BrickDraft, BrickId,
   BrickStatus (..), DomainError, DomainState (..), Lifetime (..), WorkState (..),
   behaviorEffort, behaviorLifetime, closeBrickSubtree, createBrick,
   emptyDomainState, focusBrick, moveBrickSubtree, retireStandingBrick,
   supersedeBrickWithChildren, transitionBrickStatus, validateDomainState)
import qualified LittleAnt.V1.Judgment as Judgment
import qualified LittleAnt.V1.Priority as Priority

-- | One accepted semantic lifecycle action advances this revision once and
-- appends one audit record, even when it changes an entire subtree.
data ExecutionRecord = ExecutionRecord
  { executionRecordRevision :: Integer
  , executionRecordAction :: Text
  , executionRecordBricks :: [BrickId]
  , executionRecordAt :: UTCTime
  }
  deriving stock (Eq, Show, Generic)

data ExecutionState = ExecutionState
  { executionStateRevision :: Integer
  , executionStateDomain :: DomainState
  , executionStatePriority :: Priority.PriorityState
  , executionStateJudgment :: Judgment.JudgmentState
  , executionStateDelegated :: Set BrickId
  , executionStateParentReviews :: Set BrickId
  , executionStateHistory :: [ExecutionRecord]
  }
  deriving stock (Eq, Show, Generic)

data ExecutionError
  = ExecutionDomainError DomainError
  | ExecutionPriorityError Priority.PriorityError
  | ExecutionJudgmentError Judgment.JudgmentError
  | ExecutionInvariantViolation [Text]
  deriving stock (Eq, Show, Generic)

instance ToJSON ExecutionRecord where
  toJSON = genericToJSON (recordOptions "executionRecord")
instance FromJSON ExecutionRecord where
  parseJSON = genericParseJSON (recordOptions "executionRecord")
instance ToJSON ExecutionState where
  toJSON = genericToJSON (recordOptions "executionState")
instance FromJSON ExecutionState where
  parseJSON = genericParseJSON (recordOptions "executionState")

recordOptions :: String -> AesonTypes.Options
recordOptions prefix = defaultOptions
  {AesonTypes.fieldLabelModifier = snakeField . drop (length prefix)}
  where
    snakeField [] = []
    snakeField (first : rest) = AesonTypes.camelTo2 '_' (toLower first : rest)

softWipLimit :: Int
softWipLimit = 3

emptyExecutionState :: ExecutionState
emptyExecutionState = ExecutionState
  { executionStateRevision = 0
  , executionStateDomain = emptyDomainState
  , executionStatePriority = Priority.emptyPriorityState
  , executionStateJudgment = Judgment.emptyJudgmentState
  , executionStateDelegated = Set.empty
  , executionStateParentReviews = Set.empty
  , executionStateHistory = []
  }

createExecutionBrick ::
  BrickDraft -> Text -> UTCTime -> ExecutionState ->
  Either ExecutionError (Brick, Priority.PriorityInsertion, ExecutionState)
createExecutionBrick draft evidence now state = do
  (brick, domain) <- mapDomain
    (createBrick draft (executionStateDomain state))
  (insertion, priority) <- mapPriority
    (Priority.registerPriorityBrick (brickId brick) (brickParent brick)
      (brickTitle brick) evidence now (executionStatePriority state))
  judgment <- mapJudgment
    (Judgment.registerJudgmentBrick (brickId brick) (brickParent brick) Active
      (behaviorEffort (brickBehavior brick) == Applicable)
      (executionStateJudgment state))
  next <- commit "brick_created" [brickId brick] now state
    { executionStateDomain = domain
    , executionStatePriority = priority
    , executionStateJudgment = judgment
    }
  pure (brick, insertion, next)

focusExecutionBrick ::
  BrickId -> UTCTime -> ExecutionState -> Either ExecutionError ExecutionState
focusExecutionBrick identifier now state = do
  (_, domain) <- mapDomain
    (focusBrick (Just identifier) now (executionStateDomain state))
  commit "brick_focused" [identifier] now state {executionStateDomain = domain}

completeExecutionBrick ::
  BrickId -> UTCTime -> ExecutionState -> Either ExecutionError ExecutionState
completeExecutionBrick identifier now state = do
  (closed, domain) <- mapDomain
    (transitionBrickStatus identifier MarkDone now (executionStateDomain state))
  priority <- terminalPriority identifier Done now (executionStatePriority state)
  judgment <- terminalJudgment identifier Done now (executionStateJudgment state)
  commitTerminal "brick_completed" closed now state domain priority judgment

retireStandingExecutionBrick ::
  BrickId -> UTCTime -> ExecutionState -> Either ExecutionError ExecutionState
retireStandingExecutionBrick identifier now state = do
  (closed, domain) <- mapDomain
    (retireStandingBrick identifier now (executionStateDomain state))
  priority <- terminalPriority identifier Done now (executionStatePriority state)
  judgment <- terminalJudgment identifier Done now (executionStateJudgment state)
  commitTerminal "standing_brick_retired" closed now state domain priority judgment

dropExecutionBrick ::
  BrickId -> UTCTime -> ExecutionState -> Either ExecutionError ExecutionState
dropExecutionBrick identifier now state = do
  (closed, domain) <- mapDomain
    (transitionBrickStatus identifier MarkDropped now (executionStateDomain state))
  priority <- terminalPriority identifier Dropped now (executionStatePriority state)
  judgment <- terminalJudgment identifier Dropped now (executionStateJudgment state)
  commitTerminal "brick_dropped" closed now state domain priority judgment

supersedeExecutionBrick ::
  BrickId -> BrickId -> Maybe Text -> UTCTime -> ExecutionState ->
  Either ExecutionError ExecutionState
supersedeExecutionBrick identifier replacement reason now state = do
  (closed, domain) <- mapDomain
    (transitionBrickStatus identifier (MarkSuperseded replacement reason) now
      (executionStateDomain state))
  priority <- terminalPriority identifier Superseded now
    (executionStatePriority state)
  judgment <- terminalJudgment identifier Superseded now
    (executionStateJudgment state)
  commitTerminal "brick_superseded" closed now state domain priority judgment

supersedeExecutionBrickWithChildren ::
  BrickId -> BrickId -> [BrickId] -> Maybe Text -> Text -> UTCTime ->
  ExecutionState -> Either ExecutionError
    ([Priority.PriorityInsertion], ExecutionState)
supersedeExecutionBrickWithChildren identifier replacement selected reason evidence now state = do
  (closed, _, domain) <- mapDomain
    (supersedeBrickWithChildren identifier replacement selected reason now
      (executionStateDomain state))
  (insertions, transferred) <- mapPriority
    (Priority.transferPriorityChildren identifier replacement selected evidence now
      (executionStatePriority state))
  priority <- terminalPriority identifier Superseded now transferred
  movedJudgment <- foldM
    (\current child -> mapJudgment
      (Judgment.moveJudgmentSubtree child (Just replacement) now current))
    (executionStateJudgment state) selected
  judgment <- terminalJudgment identifier Superseded now movedJudgment
  next <- commitTerminal "brick_superseded_with_children" closed now state
    domain priority judgment
  pure (insertions, next)

closeExecutionSubtree ::
  BrickId -> BrickStatus -> UTCTime -> ExecutionState ->
  Either ExecutionError ExecutionState
closeExecutionSubtree root status now state = do
  (closed, domain) <- mapDomain
    (closeBrickSubtree root status now (executionStateDomain state))
  priority <- foldM
    (\current brick -> terminalPriority (brickId brick) status now current)
    (executionStatePriority state) closed
  judgment <- foldM
    (\current brick -> terminalJudgment (brickId brick) status now current)
    (executionStateJudgment state) closed
  let identifiers = map brickId closed
      delegated = foldr Set.delete (executionStateDelegated state) identifiers
      reviews = maybeParentReview domain root
        (executionStateParentReviews state)
  commit (if status == Done then "subtree_completed" else "subtree_dropped")
    identifiers now state
      { executionStateDomain = domain
      , executionStatePriority = priority
      , executionStateJudgment = judgment
      , executionStateDelegated = delegated
      , executionStateParentReviews = reviews
      }

moveExecutionSubtree ::
  BrickId -> Maybe BrickId -> Text -> UTCTime -> ExecutionState ->
  Either ExecutionError (Priority.PriorityInsertion, ExecutionState)
moveExecutionSubtree identifier newParent evidence now state = do
  (moved, domain) <- mapDomain
    (moveBrickSubtree identifier newParent (executionStateDomain state))
  (insertion, priority) <- mapPriority
    (Priority.movePrioritySubtree identifier newParent evidence now
      (executionStatePriority state))
  judgment <- mapJudgment
    (Judgment.moveJudgmentSubtree identifier newParent now
      (executionStateJudgment state))
  next <- commit "subtree_moved" [brickId moved] now state
    { executionStateDomain = domain
    , executionStatePriority = priority
    , executionStateJudgment = judgment
    }
  pure (insertion, next)

-- | Delegation is deliberately orthogonal to work_state and current focus.
-- Recording it cannot start WIP or consume one slot in the human count.
delegateExecutionBrick ::
  BrickId -> UTCTime -> ExecutionState -> Either ExecutionError ExecutionState
delegateExecutionBrick identifier now state = do
  brick <- maybe
    (Left (ExecutionInvariantViolation ["delegation references an unknown Brick"]))
    Right
    (Map.lookup identifier
      (domainBricks (executionStateDomain state)))
  unless (brickStatus brick == Active)
    (Left (ExecutionInvariantViolation ["terminal Brick cannot be delegated"]))
  commit "brick_delegated" [identifier] now state
    {executionStateDelegated = Set.insert identifier (executionStateDelegated state)}

activeHumanWipCount :: ExecutionState -> Int
activeHumanWipCount state = length
  [ brick
  | brick <- Map.elems (domainBricks (executionStateDomain state))
  , brickStatus brick == Active
  , brickWorkState brick == Wip
  , Set.notMember (brickId brick) (executionStateDelegated state)
  ]

commitTerminal ::
  Text -> Brick -> UTCTime -> ExecutionState -> DomainState ->
  Priority.PriorityState -> Judgment.JudgmentState ->
  Either ExecutionError ExecutionState
commitTerminal action closed now state domain priority judgment =
  commit action [brickId closed] now state
    { executionStateDomain = domain
    , executionStatePriority = priority
    , executionStateJudgment = judgment
    , executionStateDelegated = Set.delete (brickId closed)
        (executionStateDelegated state)
    , executionStateParentReviews = maybeParentReview domain (brickId closed)
        (executionStateParentReviews state)
    }

terminalPriority ::
  BrickId -> BrickStatus -> UTCTime -> Priority.PriorityState ->
  Either ExecutionError Priority.PriorityState
terminalPriority identifier status now priority = snd <$> mapPriority
  (Priority.setPriorityBrickStatus identifier status now priority)

terminalJudgment ::
  BrickId -> BrickStatus -> UTCTime -> Judgment.JudgmentState ->
  Either ExecutionError Judgment.JudgmentState
terminalJudgment identifier status now judgment = snd <$> mapJudgment
  (Judgment.setJudgmentBrickStatus identifier status now judgment)

maybeParentReview :: DomainState -> BrickId -> Set BrickId -> Set BrickId
maybeParentReview domain child reviews = case Map.lookup child (domainBricks domain)
    >>= brickParent >>= (`Map.lookup` domainBricks domain) of
  Just parent
    | brickStatus parent == Active
    , priorityCompatibleFinite parent
    , null
        [ active
        | active <- Map.elems (domainBricks domain)
        , brickParent active == Just (brickId parent)
        , brickStatus active == Active
        ] -> Set.insert (brickId parent) reviews
  _ -> reviews
  where
    priorityCompatibleFinite brick =
      behaviorLifetime (brickBehavior brick) == Finite

commit ::
  Text -> [BrickId] -> UTCTime -> ExecutionState ->
  Either ExecutionError ExecutionState
commit action identifiers now state = do
  let revision = executionStateRevision state + 1
      record = ExecutionRecord revision action identifiers now
      next = state
        { executionStateRevision = revision
        , executionStateHistory = executionStateHistory state <> [record]
        }
  validateExecutionState next
  pure next

validateExecutionState :: ExecutionState -> Either ExecutionError ()
validateExecutionState state = do
  mapDomain (validateDomainState (executionStateDomain state))
  mapPriority (Priority.validatePriorityState (executionStatePriority state))
  mapJudgment (Judgment.validateJudgmentState (executionStateJudgment state))
  let domainById = domainBricks (executionStateDomain state)
      priorityById = Priority.priorityStateBricks (executionStatePriority state)
      judgmentById = Judgment.judgmentStateBricks (executionStateJudgment state)
      mismatches =
        [ "domain, priority, and judgment Brick sets differ"
        | Map.keysSet domainById /= Map.keysSet priorityById
          || Map.keysSet domainById /= Map.keysSet judgmentById
        ] <>
        [ "domain and priority parent/status disagree"
        | any (not . priorityAgrees domainById) (Map.elems priorityById)
        ] <>
        [ "domain and judgment parent/status disagree"
        | any (not . judgmentAgrees domainById) (Map.elems judgmentById)
        ] <>
        [ "delegation references an inactive or missing Brick"
        | any (not . delegatedActive domainById)
            (Set.toList (executionStateDelegated state))
        ] <>
        [ "execution revision/history are inconsistent"
        | executionStateRevision state < 0
          || fromIntegral (length (executionStateHistory state))
              /= executionStateRevision state
        ]
  unless (null mismatches) (Left (ExecutionInvariantViolation mismatches))
  where
    priorityAgrees domainById priorityBrick = case Map.lookup
        (Priority.priorityBrickId priorityBrick) domainById of
      Nothing -> False
      Just brick -> brickParent brick == Priority.priorityBrickParent priorityBrick
        && brickStatus brick == Priority.priorityBrickStatus priorityBrick
    judgmentAgrees domainById judgmentBrick = case Map.lookup
        (Judgment.judgmentBrickId judgmentBrick) domainById of
      Nothing -> False
      Just brick -> brickParent brick == Judgment.judgmentBrickParent judgmentBrick
        && brickStatus brick == Judgment.judgmentBrickStatus judgmentBrick
    delegatedActive domainById identifier = maybe False
      ((== Active) . brickStatus) (Map.lookup identifier domainById)

mapDomain :: Either DomainError value -> Either ExecutionError value
mapDomain = either (Left . ExecutionDomainError) Right

mapPriority ::
  Either Priority.PriorityError value -> Either ExecutionError value
mapPriority = either (Left . ExecutionPriorityError) Right

mapJudgment ::
  Either Judgment.JudgmentError value -> Either ExecutionError value
mapJudgment = either (Left . ExecutionJudgmentError) Right

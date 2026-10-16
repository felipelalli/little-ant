module LittleAnt.JudgmentReview (
  reviewKindText,
  parseReviewKind,
  reviewAxis,
  reviewCandidates,
  reviewClassDue,
  reviewDemand,
  reviewEligible,
  pendingJudgmentReviews,
  reviewChanges,
  reviewScope,
  reviewEvidence,
  comparableEffort,
  compatibleEffortUnits,
  currentEffort,
)
where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString.Base16 qualified as Base16
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time
import LittleAnt.Id
import LittleAnt.Model

reviewKindText :: JudgmentReviewKind -> Text
reviewKindText = \case
  EffortDiscovery -> "effort_comparison"
  ImpactDiscovery -> "impact_comparison"
  ImpactEvidenceReview -> "impact_maturity_review"

parseReviewKind :: Text -> Maybe JudgmentReviewKind
parseReviewKind value = case value of
  "effort_comparison" -> Just EffortDiscovery
  "impact_comparison" -> Just ImpactDiscovery
  "impact_maturity_review" -> Just ImpactEvidenceReview
  _ -> Nothing

reviewAxis :: JudgmentReviewKind -> JudgmentAxis
reviewAxis EffortDiscovery = EffortAxis
reviewAxis _ = ImpactAxis

reviewClassDue :: State -> JudgmentAxis -> UUIDv7 -> Bool
reviewClassDue state axis identity = any due (Map.elems (stateJudgmentReviews state))
 where
  due review = judgmentReviewSubject review == identity && reviewAxis (judgmentReviewKind review) == axis && judgmentReviewClassDue review

currentEffort :: State -> UUIDv7 -> Maybe EffortClaim
currentEffort state identity
  | reviewClassDue state EffortAxis identity = Nothing
  | otherwise = Map.lookup identity (stateEffortClaims state)

comparableEffort :: Brick -> Bool
comparableEffort brick = brickStatus brick == BrickActive && brickNature brick `elem` [AtomicTask, Project, FiniteChecklist]

compatibleEffortUnits :: State -> [UUIDv7] -> Bool
compatibleEffortUnits state identities = all (maybe False comparableEffort . (`Map.lookup` stateBricks state)) identities && and [not (contains state first second || contains state second first) | first <- identities, second <- identities, first /= second]

-- Compare finite total scopes, never a parent's scope against one of its parts.
reviewCandidates :: State -> JudgmentReview -> [UUIDv7]
reviewCandidates state review
  | judgmentReviewKind review == ImpactEvidenceReview = [owner | active owner]
  | not (active owner) = []
  | otherwise = take limit (foldl add [owner] (preferred <> remaining))
 where
  owner = judgmentReviewSubject review
  limit = if judgmentReviewKind review == EffortDiscovery then 4 else 2
  add selected identity = if judgmentReviewKind review == EffortDiscovery && not (compatibleEffortUnits state (selected <> [identity])) then selected else selected <> [identity]
  active identity = maybe False ((== BrickActive) . brickStatus) (Map.lookup identity (stateBricks state))
  usable identity = case Map.lookup identity (stateBricks state) of
    Nothing -> False
    Just brick ->
      active identity && inScope brick && case judgmentReviewKind review of
        EffortDiscovery -> comparableEffort brick && comparableOwner && not (contains state owner identity || contains state identity owner)
        _ -> isNothing (brickParent brick)
  comparableOwner = maybe False comparableEffort (Map.lookup owner (stateBricks state))
  preferred = filter (\identity -> identity /= owner && usable identity) (judgmentReviewCandidates review)
  remaining = [brickId brick | brick <- sortOn (\brick -> (brickSiblingPosition brick, brickId brick)) (activeBricks state), brickId brick /= owner, brickId brick `notElem` preferred, usable (brickId brick)]
  inScope brick = case stateDomainScope state of
    Nothing -> True
    Just scope -> any (domainContains Set.empty (domainScopeTarget scope)) (Set.toList (brickDomains brick))
  domainContains seen target identity
    | identity == target = True
    | identity `Set.member` seen = False
    | otherwise = maybe False (maybe False (domainContains (Set.insert identity seen) target) . domainParent) (Map.lookup identity (stateDomains state))

-- Equivalent questions have one owner even when several commands requested
-- the same pair/shortlist. Completion and cooldown still retain each origin.
pendingJudgmentReviews :: State -> [JudgmentReview]
pendingJudgmentReviews state = Map.elems (Map.fromListWith earlier [(key review, review) | review <- Map.elems (stateJudgmentReviews state), not (judgmentReviewResolved review), maybe False ((== BrickActive) . brickStatus) (Map.lookup (judgmentReviewSubject review) (stateBricks state))])
 where
  key review = (judgmentReviewKind review, Set.fromList (reviewCandidates state review))
  earlier first second = if (judgmentReviewCooldown first, judgmentReviewCreatedAt first, judgmentReviewSubject first) <= (judgmentReviewCooldown second, judgmentReviewCreatedAt second, judgmentReviewSubject second) then first else second

reviewEligible :: State -> UTCTime -> JudgmentReview -> Bool
reviewEligible state now review =
  not (judgmentReviewResolved review)
    && maybe True (<= now) (judgmentReviewCooldown review)
    && length (reviewCandidates state review) >= (if judgmentReviewKind review == ImpactEvidenceReview then 1 else 2)
    && case judgmentReviewKind review of
      ImpactEvidenceReview -> Map.member (judgmentReviewSubject review) (stateImpactClaims state)
      _ -> True

reviewDemand :: State -> UTCTime -> JudgmentReviewKind -> UUIDv7 -> [UUIDv7] -> Text -> Bool -> JudgmentReview
reviewDemand state now kind owner candidates reason =
  JudgmentReview kind owner candidates reason revision now Nothing 0 False
 where
  revision = digest (reason, [(identity, reviewScope state identity) | identity <- Set.toAscList (Set.fromList (owner : candidates))], if kind == ImpactEvidenceReview then reviewEvidence state owner else "")

-- Only a committed change to already-judged material requests an automatic
-- review. Merely loading missing values, exporting, or browsing is read-only.
reviewChanges :: UTCTime -> State -> State -> [JudgmentReview]
reviewChanges now before after = effort <> impact <> maturity
 where
  effort =
    [ reviewDemand after now EffortDiscovery identity [] "The scope changed after its effort judgment; review total effort." True
    | (identity, claim) <- Map.toAscList (stateEffortClaims before)
    , Map.lookup identity (stateEffortClaims after) == Just claim
    , reviewScope before identity /= reviewScope after identity
    , maybe False comparableEffort (Map.lookup identity (stateBricks after))
    ]
  activeRoot identity = maybe False (\brick -> brickStatus brick == BrickActive && isNothing (brickParent brick)) (Map.lookup identity (stateBricks after))
  impact =
    [ reviewDemand after now ImpactDiscovery identity [] "The expected outcome changed after its impact judgment; compare the current roots." True
    | (identity, claim) <- Map.toAscList (stateImpactClaims before)
    , activeRoot identity
    , Map.lookup identity (stateImpactClaims after) == Just claim
    , ownOutcome before identity /= ownOutcome after identity
    ]
  maturity =
    [ reviewDemand after now ImpactEvidenceReview identity [] "Supporting evidence changed or validation work completed; review the impact evidence." True
    | (identity, claim) <- Map.toAscList (stateImpactClaims before)
    , activeRoot identity
    , Map.lookup identity (stateImpactClaims after) == Just claim
    , reviewEvidence before identity /= reviewEvidence after identity
    ]

reviewScope :: State -> UUIDv7 -> Text
reviewScope state root = digest [(identity, ownOutcome state identity, brickNature brick, brickParent brick, [(listEntryLabel entry, listEntryQuantity entry) | entry <- Map.elems (stateListEntries state), listEntryOwner entry == identity]) | (identity, brick) <- Map.toAscList (stateBricks state), identity == root || contains state root identity, brickStatus brick `elem` [BrickActive, BrickDone]]

ownOutcome :: State -> UUIDv7 -> Text
ownOutcome state identity = digest (brickTitle <$> Map.lookup identity (stateBricks state), [(rawLinkRaw link, Map.lookup (rawLinkRaw link) (stateCurrentRawRevisions state)) | link <- Map.elems (stateRawLinks state), rawLinkTarget link == RawLinkBrick identity, rawLinkRole link == DescriptionRole])

reviewEvidence :: State -> UUIDv7 -> Text
reviewEvidence state root = digest (raws, validations, selected)
 where
  raws = [(rawLinkRaw link, rawStatus <$> Map.lookup (rawLinkRaw link) (stateRaws state), Map.lookup (rawLinkRaw link) (stateCurrentRawRevisions state)) | link <- Map.elems (stateRawLinks state), rawLinkTarget link == RawLinkBrick root, rawLinkRole link `elem` [EvidenceRole, AttachmentRole]]
  validations = [(brickId brick, brickStatus brick) | brick <- Map.elems (stateBricks state), contains state root (brickId brick), brickStatus brick == BrickDone, maybe False ((== ValidationPhase) . phaseClaimValue) (Map.lookup (brickId brick) (statePhaseClaims state))]
  selected = [(identity, Map.lookup identity (stateCurrentRawRevisions state), rawStatus <$> Map.lookup identity (stateRaws state), brickStatus <$> Map.lookup identity (stateBricks state)) | identity <- maybe [] impactClaimEvidence (Map.lookup root (stateImpactClaims state))]

contains :: State -> UUIDv7 -> UUIDv7 -> Bool
contains state root = walk Set.empty
 where
  walk seen identity
    | identity `Set.member` seen = False
    | otherwise = case Map.lookup identity (stateBricks state) >>= brickParent of
        Nothing -> False
        Just parent -> parent == root || walk (Set.insert identity seen) parent

digest :: (Show value) => value -> Text
digest = Text.decodeUtf8 . Base16.encode . SHA256.hash . Text.encodeUtf8 . Text.pack . show

module LittleAnt.Notice (
  NoticeCandidate (..),
  NoticeState (..),
  activeNoticeCandidates,
  noticeCandidates,
  noticeKindLabel,
  noticeStateLabel,
)
where

import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Time
import LittleAnt.Model

data NoticeState
  = CurrentNotice
  | SnoozedNotice ZonedInstant
  | AcknowledgedNotice UTCTime
  deriving stock (Eq, Show)

data NoticeCandidate = NoticeCandidate
  { candidateNoticeIdentity :: NoticeIdentity
  , candidateNoticeFactAt :: ZonedInstant
  , candidateNoticeBrick :: Brick
  , candidateNoticeState :: NoticeState
  }
  deriving stock (Eq, Show)

noticeCandidates :: State -> UTCTime -> [NoticeCandidate]
noticeCandidates state now = take 100 . sortOn noticeOrder $ dateCandidates <> releaseCandidates
 where
  dateCandidates =
    [ candidate brick kind revision factAt
    | (subject, constraints) <- Map.toAscList (stateTemporalConstraints state)
    , Just brick <- [Map.lookup subject (stateBricks state)]
    , brickStatus brick == BrickActive
    , (kind, factAt) <- [(BestBeforeNotice, temporalBestBefore constraints), (DeadlineNotice, temporalDeadline constraints)]
    , Just factAt <- [factAt]
    , thresholdFor kind factAt <= now
    , let revision = temporalRevision constraints
    ]
  releaseCandidates =
    [ candidate brick RecurringReleaseNotice (recurringOccurrenceScheduleRevision occurrence) (recurringOccurrenceNominalAnchor occurrence)
    | occurrence <- Map.elems (stateRecurringOccurrences state)
    , Just brick <- [Map.lookup (recurringOccurrenceBrick occurrence) (stateBricks state)]
    , brickStatus brick == BrickActive
    , zonedInstantUtc (recurringOccurrenceNominalAnchor occurrence) <= now
    ]
  candidate brick kind revision factAt =
    let identity = NoticeIdentity (brickId brick) revision kind (thresholdFor kind factAt)
     in NoticeCandidate identity factAt brick (noticeState identity)
  noticeState identity = case Map.lookup identity (stateNoticeDispositions state) of
    Just (NoticeAcknowledged at) -> AcknowledgedNotice at
    Just (NoticeSnoozed until) -> SnoozedNotice until
    Nothing -> CurrentNotice
  noticeOrder candidate =
    ( severity (noticeKind (candidateNoticeIdentity candidate))
    , zonedInstantUtc (candidateNoticeFactAt candidate)
    , noticeSubject (candidateNoticeIdentity candidate)
    )

activeNoticeCandidates :: State -> UTCTime -> [NoticeCandidate]
activeNoticeCandidates state now =
  [ candidate
  | candidate <- noticeCandidates state now
  , case candidateNoticeState candidate of
      CurrentNotice -> True
      SnoozedNotice until -> zonedInstantUtc until <= now
      AcknowledgedNotice{} -> False
  ]

thresholdFor :: NoticeKind -> ZonedInstant -> UTCTime
thresholdFor kind instant =
  addUTCTime (negate lead) (zonedInstantUtc instant)
 where
  lead = case kind of
    BestBeforeNotice -> 7 * nominalDay
    DeadlineNotice -> 7 * nominalDay
    RecurringReleaseNotice -> 0
    TemporalTransitionNotice -> 0

severity :: NoticeKind -> Int
severity = \case
  DeadlineNotice -> 0
  BestBeforeNotice -> 1
  TemporalTransitionNotice -> 2
  RecurringReleaseNotice -> 3

noticeKindLabel :: NoticeKind -> Text
noticeKindLabel = \case
  BestBeforeNotice -> "Best before"
  DeadlineNotice -> "Deadline"
  RecurringReleaseNotice -> "Occurrence"
  TemporalTransitionNotice -> "Transition"

noticeStateLabel :: NoticeState -> Text
noticeStateLabel = \case
  CurrentNotice -> "current"
  SnoozedNotice{} -> "snoozed"
  AcknowledgedNotice{} -> "acknowledged"

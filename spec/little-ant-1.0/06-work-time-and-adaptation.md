# 6. Work, time, and adaptation

## Focus, WIP, and completion

- **WRK-001 [core] — One focus, several WIPs.** Human focus points to zero or
  one Brick globally. Several Bricks may remain `wip`; focusing another Brick
  removes attention from the previous one but leaves it WIP.
- **WRK-002 [core] — Focus starts WIP.** Accepting focus on an idle Brick
  atomically makes it WIP and current. Focus changes are event history.
- **WRK-003 [calibration] — Soft WIP limit.** The factory soft limit is three.
  Additional WIPs are allowed and increase review pressure.
- **WRK-004 [core] — No silent clearing.** Stale focus and WIP create
  opportunities to continue, unfocus, return to idle, complete, drop, or
  supersede. Nothing is silently completed or cleared.
- **WRK-005 [core] — Done is direct.** A served Brick exposes `done` alongside
  focus and skip. Completion without a prior start is ordinary `done` with
  unknown observed duration, not `already done` or a synthetic zero-length run.
- **WRK-006 [core] — Terminal distinctions.** `done`, `dropped`, and
  `superseded` preserve different outcomes and lineage. Stopping an execution,
  missing a habit opportunity, and abandoning an external delegation are
  context-specific outcomes, not one generic `abandon` command.

## Skip as evidence

- **WRK-007 [core] — Symptom before reaction.** Served-work skip first records
  what prevented focus, then may offer a separate remedy. Skip is not itself a
  remediation command.
- **WRK-008 [core] — Canonical symptom family.**

  ```text
  vague | hard | big | waiting | blocked | tired | bored | fear
  | not_important_now | other
  ```

  `meh`, `kill`, `alternatives`, and `change subject` are not symptoms.

- **WRK-009 [core] — Waiting versus blocked.** `waiting` means an unresolved
  external person, event, or condition with no known action. `blocked` means a
  missing actionable prerequisite such as a Brick, information, access, or
  material.
- **WRK-010 [core] — Cooldown plus memory.** A served skip creates a short,
  replay-deterministic cooldown while preserving longer-term evidence and
  pressure. It never changes importance.
- **WRK-011 [standard] — Scoped fatigue.** An accepted reaction may apply
  tiredness or boredom to a Domain branch, producing a bounded decaying signal.
  The symptom alone never chooses scope or changes Domain.
- **WRK-012 [standard] — Taxonomy watch.** Repeated attributed `other` evidence
  may create a taxonomy-review opportunity. Human, skill, or powered-up
  judgment proposes a label; acceptance is explicit and versioned.
- **WRK-013 [core] — Contextual skip.** Ordering, effort/impact
  classification, repeatable work, and habit opportunities each have
  distinct skip semantics and never reuse served-work evidence incorrectly.

## Time

- **WRK-014 [core] — Three date meanings.**

  ```text
  not_before  — ordinary execution must not be proposed before this instant
  best_before — usefulness degrades after this instant
  deadline    — an external commitment or consequence occurs at this instant
  ```

- **WRK-015 [core] — Dates inform forecast, not importance.** Date pressure,
  notices, and overdue state affect focus chance and explanation without
  rewriting human importance.
- **WRK-016 [core] — Contextual later.** `later` appears only where a proposal
  can honestly be deferred. It always shows and records an explicit absolute
  date; it is not a universal response.
- **WRK-017 [core] — Deterministic tick.** Every command advances due temporal
  rules from its canonical clock. An explicit administrative `tick` performs
  the same advancement without inventing other work.
- **WRK-018 [standard] — Discreet notices.** Date notices are deduplicated,
  inspectable, acknowledgeable or snoozable as applicable, and rendered
  discreetly in secondary context rather than hijacking every screen.

## Standing work and recurrence

- **WRK-019 [standard] — Standing execution.** Finishing one run of a standing
  Brick records an execution outcome, clears focus/WIP as applicable, and
  leaves the standing responsibility active.
- **WRK-020 [standard] — Living checklist.** All open entries render
  together. Bought or resolved entries leave the open view but remain in
  history; unresolved entries remain. Empty state is dormant, not done.
- **WRK-021 [standard] — Repeatable Brick.** Completing a repeatable execution
  may finish the Brick terminally or schedule the same identity behind one
  future `not_before`. It is never reinserted in importance.
- **WRK-022 [standard] — Deterministic jitter.** An approximate return such as
  six months plus or minus three months chooses and records one replay-safe
  date, preventing a batch of completions from necessarily returning together.
- **WRK-023 [standard] — Recurring obligation.** A standing series releases
  independently completable occurrence Bricks. Unpaid occurrences remain open
  and may coexist with later periods.
- **WRK-024 [standard] — Habit.** A habit retains one standing identity
  while applicable windows record `done` or an unfulfilled outcome. Expired
  opportunities do not accumulate as overdue task backlog.
- **WRK-025 [standard] — Blocked or paused habit.** Inapplicable, blocked,
  or explicitly paused windows do not fabricate failure or break a streak.
- **WRK-026 [standard] — Derived motivation.** Streaks and compact projections
  such as `[x][x][x][-][x][x]` derive from occurrence history. Before an
  explicit outcome would end a streak, UI may confirm the concrete consequence.
- **WRK-027 [calibration] — Introspection.** Repeated skips or unfulfilled
  intentions can create a review using configurable evidence thresholds.
  Possible remedies remain explicit: revise schedule, add a dependency or
  enabling Brick, pause, retire, or gather more evidence.
- **WRK-028 [standard] — Event-triggered opportunity.** A supported canonical
  source event may idempotently release one opportunity on an existing
  compatible standing Brick. This is closed core data, not generic automation.
## Delegation

- **WRK-029 [standard] — ExternalEntity target.** Delegation targets an
  ExternalEntity and never consumes human WIP merely because it is active.
- **WRK-030 [standard] — Mandatory follow-up policy.** Before the initial
  notice can be approved, every Delegation chooses exactly one:

  ```text
  once | every | explicitly none
  ```

  Repeating policy creates approval-bearing follow-up opportunities and never
  authorizes automatic messages.

- **WRK-031 [standard] — Nature-aware scope.**

  ```text
  brick_only | whole_scope | ask | disabled
  ```

  `whole_scope` derivatively covers current and future descendants and
  Nature-owned entries; `ask` stores the concrete choice; `disabled` still
  permits separate enabling work.

- **WRK-032 [standard] — Factory delegation scopes.**

  | Nature | Scope |
  |---|---|
  | `atomic_task` | `brick_only` |
  | `project` | `ask` |
  | `collection` | `brick_only` |
  | `repeatable` | `ask` |
  | `living_checklist` | `ask` |
  | `finite_checklist` | `whole_scope` |
  | `recurring_obligation` | `ask` |
  | `habit` | `disabled` |

- **WRK-033 [standard] — Preview and reconciliation.** Initial notice,
  cancellation, follow-up, nudge, refusal, and reported completion preserve
  explicit previews and approvals. Existing human focus, WIP, or incompatible
  delegation inside a proposed whole scope must be reconciled first.
- **WRK-034 [standard] — No cascading truth.** A reported delegated outcome
  returns for Nature-aware validation and never cascades completion through a
  project tree.

## Place context

- **WRK-035 [standard] — Place conditions.** A Brick may have hard or soft
  conditions associated with a named Place.
- **WRK-036 [standard] — Attributed observations.** Current location is a
  time-bounded, attributed observation from a human or adapter. It affects
  eligibility or chance only within its declared strength and validity.
- **WRK-037 [standard] — Privacy boundary.** Adapters provide observations;
  the core does not continuously track location or silently perform external
  actions.

## Schedule semantics

- **WRK-038 [standard] — Habit schedule shapes.** A habit schedule resolves to
  either fixed slots or a quota window. A fixed slot anchors an opportunity to
  a recurring calendar position. A quota window requires a positive completion
  count within a positive number of days, weeks, months, or years. Both are
  canonical structured data; neither depends on interpreting stored prose.
- **WRK-039 [core] — Monthly anchor clamping.** A monthly fixed slot stores its
  intended day from 1 through 31. In a month without that day, the occurrence
  uses the month's last valid day. Later occurrences are always calculated
  from the intended day rather than the preceding adjusted date, so an anchor
  of 31 produces January 31, February 28 or 29, March 31, April 30, and May 31
  without drift.
- **WRK-040 [core] — Discrete habit outcome.** Every applicable habit
  opportunity records one discrete outcome: `done` or the canonical
  unfulfilled outcome chosen under `OPEN-WRK-002`. The 1.0 core does not add
  generic target quantity, unit, observed value, or percentage-progress fields
  for habits. A desired amount such as pages, minutes, distance, or repetitions
  may remain in the title, description, completion criterion, or optional
  execution note without changing the outcome model.

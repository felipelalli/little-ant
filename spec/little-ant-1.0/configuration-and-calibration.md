# Configuration and calibration

Configuration changes degree, cadence, and resource limits. It never changes
the meaning of an action, adds a state transition, removes an invariant, or
grants authority.

## Contract

- **CAL-001 — Versioned YAML profile.** Factory and user-adjusted parameters
  use a schema-validated, versioned YAML profile. The exact filesystem path is
  deployment configuration rather than domain semantics.
- **CAL-002 — Replay evidence.** Every event or draw affected by configuration
  records or references the effective profile version and content hash.
- **CAL-003 — Explicit change.** A parameter update is inspectable and
  reversible. The system never silently “learns” a new policy from behavior.
- **CAL-004 — Safe range.** Each numeric parameter declares units, allowed
  range, factory value, and whether changing it affects only future operations
  or requires a derived-projection rebuild.
- **CAL-005 — No semantic switches.** Enabling a new Nature capability,
  opportunity kind, event, command, authority, or Pack permission requires a
  product/core version, not YAML.
- **CAL-006 — Simulation calibration.** Scenario fixtures may sweep parameters
  and compare outcomes while holding state, clock, and random stream constant.
- **CAL-007 — Named operational time zone.** Day-boundary configuration uses
  one explicit IANA time-zone identifier. Exact instants retain their own
  named zones independently and are never interpreted through an operational
  boundary.
- **CAL-008 — Prospective boundary changes.** Changing an operational time
  zone or day boundary affects future attribution and future habit windows.
  Historical sessions, habit outcomes, and derived nominal-day evidence retain
  the effective profile recorded under `CAL-002`; they are not silently
  relabeled.

## Settled factory defaults

Unless a row says otherwise, changing it affects future interactions and
temporal openings only; it does not rewrite history. Array entries obey the
listed per-entry range, remain ordered and unique, and use at most eight
entries.

| Parameter | Factory | Allowed range or schema | Meaning |
|---|---:|---|---|
| `work.wip_soft_limit` | `3` | integer `1..50` | More WIPs are allowed but add review pressure. |
| `work.short_sprint_durations_minutes` | `[5, 15, 25]` | integer entries `1..240` | Visible dumb duration choices for bounded attempts. |
| `work.short_sprint_default_minutes` | `25` | one configured duration | Visible default, labeled `a Pomodoro`. |
| `work.served_skip_cooldown_minutes` | `30` | integer `1..1440` | Cooldown after an accepted skip reaction for an execution opportunity. |
| `review.skip_cooldown_hours` | `24` | integer `1..720` | Default cooldown after skipping a non-execution lottery review. |
| `work.stale_focus_hours` | `8` | integer `1..168` | Elapsed time after the latest focus activity before UX-080 checks in. |
| `importance.nearby_skip_min_distance` | `1` | integer `1..10` | Minimum alternative-comparator distance. |
| `importance.nearby_skip_max_distance` | `3` | integer `min..20` | Maximum alternative-comparator distance. |
| `importance.skips_before_uncertain_placement` | `2` | integer `1..10` | Consecutive unresolved comparisons before provisional placement. |
| `importance.sanity_new_arrivals` | `7` | integer `1..100` | New-arrival trigger for a bulk sanity opportunity. |
| `importance.sanity_interval_days` | `14` | integer `1..365` | Drift interval for a bulk sanity opportunity. |
| `taxonomy.other_evidence_count` | `3` | integer `2..20` | Matching accepted `other` observations needed for one taxonomy watch. |
| `taxonomy.other_window_days` | `30` | integer `1..365` | Window in which the matching observations count. |
| `taxonomy.other_decay_days` | `90` | integer `window..3650` | Age after which an observation no longer helps current clustering. |
| `ui.max_visible_warnings` | `1` | integer `0..10` | Additional warnings appear as a count. |
| `ui.microcopy_variants_per_intent` | `16` | integer `1..64` | Factory English phrases for each declared personality intent. |
| `ui.color_mode` | `auto` | `auto | always | never` | ANSI presentation policy. |
| `ui.emoji_mode` | `auto` | `auto | always | never` | Decorative emoji presentation policy. |
| `ui.external_editor.argv` | `null` | null or `1..32` nonempty argv strings | Optional direct executable invocation for UX-162; otherwise resolve `$VISUAL`, then `$EDITOR`, without a shell. |
| `effort.assisted_comparison_limit` | `3` | integer `1..10` | Maximum exemplar questions in one assistance flow. |
| `impact.assisted_comparison_limit` | `3` | integer `1..10` | Maximum reviewed-root exemplar questions in one assistance flow. |
| `time.habit_day_starts_at` | `04:00` | valid local `HH:MM` | Boundary between nominal habit days. |
| `time.workday_starts_at` | `06:00` | valid local `HH:MM` | Boundary between nominal workdays. |
| `wait.human_response_first_review_days` | `3` | integer `0..365` | Suggested delay before a human-response Wait first enters review eligibility. |
| `wait.response_history_min_samples` | `3` | integer `1..100` | Comparable resolved Waits needed before history may move that suggestion. |
| `wait.unanswered_follow_up_soft_cap` | `2` | integer `1..20` | Unanswered follow-ups before strategy review replaces ordinary follow-up. |
| `habit.introspection_consecutive_unfulfilled` | `3` | integer `1..100` | Applicable unfulfilled outcomes that admit one introspection review. |
| `habit.introspection_skip_count` | `3` | integer `1..100` | Explicit habit skips that admit the same review. |
| `habit.introspection_window_count` | `2` | integer `1..52` | Applicable windows inspected for the skip threshold. |
| `recurrence.release_batch_limit` | `1000` | integer `1..100000` | Overdue occurrences materialized by one tick before continuation. |
| `vault.agent_idle_lock_minutes` | `30` | integer `1..1440` | Credential inactivity before the profile agent locks. |
| `delegation.review_delay_hours` | `72` | integer `0..8760` | Default delay from a handoff or observation to internal review. |
| `delegation.review_skip_cooldown_hours` | `24` | integer `1..720` | Override after deferring an internal Delegation review. |
| `delegation.unanswered_follow_up_soft_cap` | `2` | integer `1..20` | Handoffs without outcome before explicit strategy review. |
| `place.negative_answer_cooldown_minutes` | `60` | integer `0..1440` | Cooldown after a selected required PlaceCondition is not met. |
| `powered_up.handshake_timeout_seconds` | `10` | integer `1..60` | Startup challenge execution and parse limit. |
| `powered_up.request_timeout_seconds` | `30` | integer `1..300` | Per-request adapter execution limit. |
| `powered_up.max_request_bytes` | `262144` | integer `1024..4194304` | Maximum structured prompt written to adapter stdin. |
| `powered_up.max_response_bytes` | `262144` | integer `1024..4194304` | Maximum captured stdout before rejection. |
| `powered_up.max_json_depth` | `32` | integer `4..128` | Maximum accepted structured-response nesting. |
| `powered_up.max_extraction_candidates` | `4` | integer `1..16` | Bounded objects considered when framing text surrounds output. |
| `pack.runner_timeout_seconds` | `30` | integer `1..300` | Maximum fresh Lua invocation wall time. |
| `pack.instruction_limit` | `10000000` | integer `10000..1000000000` | Lua instruction budget before termination. |
| `pack.memory_limit_bytes` | `67108864` | integer `1048576..1073741824` | Fresh runner memory cap. |
| `pack.input_limit_bytes` | `8388608` | integer `1024..67108864` | Maximum serialized invocation input. |
| `pack.result_limit_bytes` | `8388608` | integer `1024..67108864` | Maximum validated component result. |
| `pack.max_value_depth` | `32` | integer `4..128` | Maximum input/result structured nesting. |
| `pack.http_body_limit_bytes` | `16777216` | integer `1024..134217728` | Maximum host-brokered HTTP response body. |
| `pack.http_redirect_limit` | `5` | integer `0..20` | Redirect hops, each revalidated against allowed hosts. |
| `provider.read_retry_attempts` | `3` | integer `0..10` | Retries for idempotent reads or pre-dispatch failures only. |
| `provider.retry_base_seconds` | `1` | integer `1..60` | Initial exponential-backoff delay. |
| `provider.retry_max_seconds` | `60` | integer `base..3600` | Maximum exact exponential-backoff delay; v1 adds no retry jitter. |

FOC-037 execution variants use `work.served_skip_cooldown_minutes` after an
accepted skip reaction. FOC-054 non-execution variants use
`review.skip_cooldown_hours` unless their canonical rule names a more specific
row above or the human chooses an explicit future instant. Active scheduled
commitments have truthful outcomes rather than either generic skip. The date
notice defaults reuse the deterministic calculation profile's
`best_before`/`deadline` lead windows; notice identity and WRK-146 round-robin
make a separate deduplication or rotation duration unnecessary.

The complete fixed-point selection and confidence defaults live in the
[deterministic calculation profile](deterministic-calculation-profile.md).
Those values are part of the factory calibration profile and obey CAL-001..008
exactly like the table above.

`time.operational_timezone` is required profile data rather than a universal
factory value. It is an IANA identifier such as `America/Montevideo`. A
habit-specific schedule may override `time.habit_day_starts_at`; there is no
corresponding implicit override for exact instants.

The two importance-sanity values are restored v0 defaults, not universal human
truth. Synthetic and real shadow-day simulations may recommend a later
versioned profile revision without changing their meaning.

## EffortProfile v1

| Class | Macro | Optimistic | Realistic | Pessimistic |
|---|---|---:|---:|---:|
| `VERY_EASY` | `EFFORT_2H` | 2h | 3h | 4h |
| `EASY` | `EFFORT_4H` | 4h | 6h | 8h |
| `NORMAL` | `EFFORT_1D` | 8h | 12h | 16h |
| `MODERATE` | `EFFORT_2D` | 16h | 24h | 32h |
| `HARD` | `EFFORT_4D` | 32h | 48h | 64h |
| `VERY_HARD` | `EFFORT_8D` | 64h | 96h | 128h |
| `MINI_PROJECT` | `EFFORT_16D` | 128h | 192h | 256h |
| `PROJECT` | `EFFORT_32D` | 256h | 384h | 512h |

These hours are planning references, not Brick fields or promises.

## Provisional phase placement

When phase is already known, applicable, and no direct importance evidence
exists, the v1 starting profile may use:

| Phase | Provisional center |
|---|---:|
| `validation` | 12.5% |
| `execution` | 37.5% |
| `spec` | 50% |
| `idea` | 75% |

The percentage is a binary-insertion prior, not a band, constraint, or sort
key. Missing phase uses the Nature/default neutral prior.

## Calibration boundary

The keys in this file and the deterministic calculation profile are the
complete 1.0 calibration registry. Simulation may recommend a versioned value
change within its declared range, but it may not invent an unregistered key,
replace a formula, add a signal, collapse Nature-specific skip meaning, or
silently learn policy from behavior. Archive review, Wait review, WIP review,
recurrence, habits, and source/effect reviews reuse the registered availability,
age, deferral, uncertainty, date, schedule, and consequence formulas; they do
not own hidden coefficients.

The synthetic week and real shadow day check for starvation, interruption,
repetition, warning noise, unsafe resource use, and awkward cooldowns while
holding state, time, and random streams fixed. A change after 1.0 records a new
profile version and hash under CAL-002.

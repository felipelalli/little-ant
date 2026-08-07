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

| Parameter | Factory value | Meaning |
|---|---:|---|
| `work.wip_soft_limit` | `3` | More WIPs are allowed but add review pressure. |
| `work.short_sprint_durations_minutes` | `[5, 15, 25]` | Visible dumb duration choices for the bounded-attempt recovery. |
| `work.short_sprint_default_minutes` | `25` | Visible default, labeled `a Pomodoro`; it must be one of the configured choices. |
| `importance.nearby_skip_min_distance` | `1` | Minimum alternative-comparator distance. |
| `importance.nearby_skip_max_distance` | `3` | Maximum alternative-comparator distance. |
| `importance.skips_before_uncertain_placement` | `2` | Consecutive unresolved comparisons before provisional placement. |
| `importance.sanity_new_arrivals` | `7` | V0-proven starting trigger for a bulk sanity opportunity. |
| `importance.sanity_interval_days` | `14` | V0-proven starting drift interval. |
| `ui.max_visible_warnings` | `1` | Additional warnings appear as a count. |
| `ui.microcopy_variants_per_intent` | `16` | Factory English phrases for every declared personality intent. |
| `ui.color_mode` | `auto` | Emit ANSI styles only when terminal capability and user environment allow it; explicit `always` and `never` remain presentation overrides. |
| `ui.external_editor.argv` | `null` | Optional executable-plus-arguments array for UX-162. When absent, the local surface resolves `$VISUAL` then `$EDITOR`; all forms execute directly without a shell. |
| `effort.assisted_comparison_limit` | `3` | Maximum exemplar questions in one assistance flow. |
| `impact.assisted_comparison_limit` | `3` | Maximum reviewed-root exemplar questions in one assistance flow. |
| `time.habit_day_starts_at` | `04:00` | Local boundary between nominal habit days. |
| `time.workday_starts_at` | `06:00` | Local boundary between nominal workdays. |
| `wait.human_response_first_review_days` | `3` | Factory suggestion before a human-response Wait first enters weighted review eligibility. |
| `wait.response_history_min_samples` | `3` | Comparable resolved Waits required before history may move the visible timing suggestion. |
| `wait.unanswered_follow_up_soft_cap` | `2` | Consecutive follow-up handoffs without a meaningful response before strategy review replaces the ordinary follow-up action. |
| `habit.introspection_consecutive_unfulfilled` | `3` | Applicable unfulfilled outcomes that admit one lazy habit-introspection review. |
| `habit.introspection_skip_count` | `3` | Explicit habit skips inside the configured evidence window that admit the same review. |
| `habit.introspection_window_count` | `2` | Open habit windows inspected for the factory skip threshold. |
| `recurrence.release_batch_limit` | `1000` | Maximum overdue obligation occurrences materialized by one tick before a required continuation. |
| `delegation.review_delay_hours` | `72` | Visible default delay from a handoff or reviewed observation to the next internal Delegation review. |
| `delegation.review_skip_cooldown_hours` | `24` | Cooldown after deferring an internal Delegation review without changing its facts or authorizing a message. |
| `delegation.unanswered_follow_up_soft_cap` | `2` | Recorded follow-up handoffs without a meaningful outcome before automatic proposals pause for an explicit strategy review. |

`time.operational_timezone` is required profile data rather than a universal
factory value. It is an IANA identifier such as `America/Montevideo`. A
habit-specific schedule may override `time.habit_day_starts_at`; there is no
corresponding implicit override for exact instants.

The two importance-sanity values are restored v0 defaults, not universal human
truth. Synthetic and real shadow-day simulations may recommend changing them
before the 1.0 factory profile is frozen.

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
| `exec` | 37.5% |
| `spec` | 50% |
| `idea` | 75% |

The percentage is a binary-insertion prior, not a band, constraint, or sort
key. Missing phase uses the Nature/default neutral prior.

## Defaults to calibrate before implementation freeze

The semantic behavior is settled, but factory numbers still require scenario
evidence:

- importance-to-chance curve and positive-tail base-weight floor;
- strongest-signal bonus curve, independence test, and cap;
- Domain-affinity strength and decay after accepted focus;
- interaction-family affinity strength, per-family contribution, skip
  reduction, and decay after an accepted interaction;
- served-skip cooldown plus separately calibrated repeatable aging,
  quota-window schedule pressure, and recurring-obligation avoidance
  pressure; these parameters never collapse the semantic distinctions in
  `WRK-062..064`;
- Domain fatigue cooldown and bounded negative signal;
- per-axis direct-judgment confidence by provenance, temporal decay shape,
  relevance horizon, and fresh-conflict threshold;
- per-axis transitive path-length penalty and weakest-edge policy;
- per-axis provocative-validation target share within served judgment
  maintenance, candidate scoring, cooldown, and confidence/consequence
  multipliers;
- taxonomy-watch evidence count, window, and decay;
- archive-relevance initial review weight, aging pressure, evidence bonus, and
  review-skip cooldown;
- habit-review coefficient tuning around the settled factory evidence counts,
  plus carried-entry evidence thresholds;
- date-notice lead times, deduplication windows, and rotation;
- repeatable-work default jitter seeds and template-specific ranges;
- stale-focus and stale-comparison thresholds;
- Wait review age curve, unresolved-review bonus, historical-response evidence
  threshold, and caps;
- powered-up handshake timeout, response bytes, nesting, and extraction bounds;
- Pack runner time, instruction, memory, result, and nesting limits;
- vault idle timeout and provider retry/backoff defaults.

The synthetic-week fixture establishes initial values. The real shadow day
checks whether they produce surprising starvation, interruption, repetition,
or warning noise. Parameters remain adjustable after 1.0 while their semantics
and safe ranges remain versioned.

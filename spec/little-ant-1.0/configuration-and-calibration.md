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
| `importance.nearby_skip_min_distance` | `1` | Minimum alternative-comparator distance. |
| `importance.nearby_skip_max_distance` | `3` | Maximum alternative-comparator distance. |
| `importance.skips_before_uncertain_placement` | `2` | Consecutive unresolved comparisons before provisional placement. |
| `importance.sanity_new_arrivals` | `7` | V0-proven starting trigger for a bulk sanity opportunity. |
| `importance.sanity_interval_days` | `14` | V0-proven starting drift interval. |
| `ui.max_visible_warnings` | `1` | Additional warnings appear as a count. |
| `ui.microcopy_variants_per_intent` | `16` | Factory English phrases for every declared personality intent. |
| `ui.color_mode` | `auto` | Emit ANSI styles only when terminal capability and user environment allow it; explicit `always` and `never` remain presentation overrides. |
| `effort.assisted_comparison_limit` | `3` | Maximum exemplar questions in one assistance flow. |
| `time.habit_day_starts_at` | `04:00` | Local boundary between nominal habit days. |
| `time.workday_starts_at` | `06:00` | Local boundary between nominal workdays. |
| `wait.human_response_first_review_days` | `3` | Factory suggestion before a human-response Wait first enters weighted review eligibility. |
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
| `MODERATED` | `EFFORT_2D` | 16h | 24h | 32h |
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

- importance-to-chance curve and positive-tail floor;
- strongest-signal bonus curve, independence test, and cap;
- Domain-affinity strength and decay after accepted focus;
- interaction-family affinity strength, per-family contribution, skip
  reduction, and decay after an accepted interaction;
- served-skip cooldown plus separately calibrated repeatable aging,
  quota-window schedule pressure, and recurring-obligation avoidance
  pressure; these parameters never collapse the semantic distinctions in
  `WRK-062..064`;
- Domain fatigue cooldown and bounded negative signal;
- direct-judgment confidence by provenance, temporal decay shape, relevance
  horizon, and fresh-conflict threshold;
- transitive path-length penalty and weakest-edge policy;
- provocative-validation target share within served importance maintenance,
  candidate scoring, cooldown, and confidence/consequence multipliers;
- taxonomy-watch evidence count, window, and decay;
- habit-review and carried-entry evidence thresholds;
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

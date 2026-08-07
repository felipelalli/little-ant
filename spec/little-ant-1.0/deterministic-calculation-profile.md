# Deterministic calculation profile

Status: **normative 1.0 calculation and factory-default contract**

This profile makes confidence and weighted choice reproducible without
pretending that their numbers are human truth. Public UI continues to show
plain labels, chances, and reasons. The fixed-point values below are internal,
versioned, inspectable, and calibratable under CAL-001..008.

## Common arithmetic

All configurable ratios are decimal fixed point with scale `1_000_000`.
Parsing rejects a value that cannot be represented at that scale. Addition
saturates at the declared bound. Multiplication divides by the scale and
rounds half away from zero after each named formula step. Time differences use
integer seconds. Candidate and evidence ties use the canonical UUID byte order
unless a subject rule declares a different stable order.

Each dataset owns one 256-bit random seed created from the operating system's
cryptographic random source. Replay-safe randomness uses one independently
advanced counter stream per closed semantic purpose:
`SHA-256("little-ant/random/v1" || purpose_length || purpose || seed ||
cursor_u128_be)`. The prefix is its literal ASCII bytes, `purpose_length` is
one unsigned byte, `purpose` is that many ASCII bytes, `seed` is 32 bytes, and
the cursor is a 16-byte unsigned big-endian integer. The purpose is a closed ASCII identifier such as
`forecast_subject_draw` or `repeatable_return_jitter`; its starting cursor,
every consumed block, and ending cursor are recorded. Digest bytes are read as
unsigned big-endian words. The purpose-to-cursor map is canonical dataset
state, not hidden implementation state. Consumption in one purpose therefore
cannot perturb another purpose, which keeps personality isolated from the
Focus forecast. Merely rendering, inspecting, paging an
already-created envelope, or replaying a proposal consumes no block.

The complete v1 purpose registry is:

```text
forecast_subject_draw
forecast_child_draw
forecast_opportunity_draw
forecast_dependency_draw
forecast_occurrence_draw
forecast_domain_path_draw
importance_nearby_comparator
importance_provisional_direction
importance_validation_branch
easier_work_sample
domain_target_sample
repeatable_return_jitter
personality_phrase
```

The first six are uniform integer draws over the weighted intervals defined
below. `importance_nearby_comparator` is uniform without replacement over the
eligible siblings one to three positions away;
`importance_provisional_direction` is uniform over `before | after` when no
existing stable local order decides it. `importance_validation_branch` draws
one integer in `[0, 1_000_000)` when both an unresolved sorter pair and a
transitive-only validation pair exist; values below the configured target rate
select validation. When only one branch exists it is selected without random
consumption. A provocative pair is chosen deterministically by lowest path
confidence, then the oldest most-recent edge on that path, shortest path, and
canonical UUID pair order.
`domain_target_sample` is a uniform without-replacement permutation of the
eligible complete Domain paths for one UX-S09 envelope. Warning selection
instead uses WRK-146's recorded round-robin cursor and consumes no random
stream. The remaining purposes follow their explicit helper rules below. A
core release must add a registry entry
before adding another semantic use of randomness. UUIDv7 entropy is not a
semantic choice stream: the allocated UUID is recorded as event input under
MOD-008 and replay reuses it.

Changing a numeric parameter affects only calculations whose recorded instant
is at or after the accepted profile revision. Replay uses the recorded profile
hash. Rebuilding a projection never applies today's parameters to an old draw
or judgment.

## Judgment confidence

Every judgment record has a provenance class, `initial_confidence`,
`recorded_at`, axis, and optional invalidation evidence. Current effective
confidence at time `t` is:

```text
age       = max(0, t - recorded_at)
remaining = max(0, horizon - age)
effective = initial_confidence * remaining / horizon
```

The factory classes are:

| Provenance | Authority tier | Initial confidence | Horizon |
|---|---:|---:|---:|
| direct human answer | 3 | `1.00` | 365 days |
| explicit human acceptance of an assisted proposal | 2 | `0.80` | 270 days |
| human `either_order` judgment | 3 | `1.00` | 365 days |
| deterministic provisional placement | 1 | `0.15` | 30 days |
| model-only pre-order proposal | 1 | `0.30` | 30 days |

An accepted model proposal remains lower-confidence attributed evidence; it
does not masquerade as a direct comparison. For conflicting current evidence,
the highest authority tier at or above the relevance threshold is considered
before numeric confidence, so model-only evidence never overrides a
still-relevant human answer. A later
direct human answer starts with `1.00` regardless of direction. Expired
evidence remains in history but contributes zero to the current relation.

Factory thresholds are `0.20` for relevance and `0.60` for a fresh conflict.
An inferred path has confidence equal to its weakest effective edge multiplied
by `0.90` for every edge after the first. Path search first maximizes this
confidence, then minimizes edge count, then uses canonical UUID path order.
Thus recent direct evidence normally outranks an old path, while a cycle among
recent strong answers becomes an explicit contradiction instead of being
silently resolved by recency.

Impact and Effort judgments use the same provenance classes. The effective
horizon is the smaller of the provenance horizon and the axis horizon; factory
axis horizons are 365 days for Importance, 365 for Impact, and 180 for Effort
because effort is more sensitive to scope change. Explicit invalidation,
retraction, or a scope mismatch may reduce effective confidence sooner under
the owning semantic rule; it cannot raise confidence or erase history.

Public comparison or placement-confidence labels derive without exposing
floats, in this order:

```text
effective == 0     historical only
effective >= 0.60  reviewed
effective >= 0.20  provisional
effective >  0     review due
```

These labels do not replace the separate Impact evidence-maturity vocabulary.

## Weighted choice

The same calculation is used at each hierarchical subject draw and each local
opportunity draw. Eligibility, cooldown, hard Domain scope, current-focus
continuation, scheduled-commitment precedence, and typed gates run first; the
formula never weakens them.

### Importance factor

For `n > 1` active siblings, a candidate at zero-based position `i` has
`rank = i / (n - 1)`, where `0` is most important. A singleton has rank `0`.
With effective local order confidence `c`:

```text
ranked = bottom + (1 - bottom) * (1 - rank) ^ exponent
factor = neutral + c * (ranked - neutral)
```

Factory values are `bottom = 0.05`, `neutral = 0.35`, and `exponent = 2`.
The top-to-bottom factor ratio is therefore 20:1 before other bounded signals,
while every position remains positive. A Raw subject and any subject without
current active importance use `neutral`. An archived relevance review may use
the Brick's last active rank with its decayed confidence; it never restores
the Brick to the active order.

Local order confidence for a positioned Brick is the minimum effective
confidence of its current relations to its immediate active predecessor and
successor, omitting a missing side. A singleton is `1.00`; a position with no
supporting relation uses its provisional-placement confidence. The relation
may be direct or the deterministic best transitive path above. This makes a
weak local segment reduce the strength of its rank without making the display
order incomplete.

### Positive pressure

Each typed rule may emit a signal in `[0,1]` with a declared correlation key
and human explanation. Signals with the same key collapse to their maximum.
Let the remaining independent values in descending order be `s1..sk`:

```text
extra    = 1 - product(1 - s2 ... 1 - sk)
pressure = s1 + additional_fraction * (1 - s1) * extra
```

No signals means pressure zero. Factory `additional_fraction = 0.35`, so the
strongest signal anchors the result and extra evidence contributes a bounded
diminishing bonus. The pressure factor is
`1 + pressure_gain * pressure`, with factory `pressure_gain = 2.0`.

The factory signal strengths are intentionally coarse:

| Signal | Value or curve |
|---|---|
| ordinary executable Work availability | `0.25` |
| new Inbox Raw triage | `0.15` |
| fresh lazy maintenance claim | `0.05` |
| newly open operational review | `0.20` |
| neglect age | linear from `0` to `0.50` over 30 days |
| explicit deferrals after cooldown | `0.50 * (1 - 2^-count)` |
| uncertainty or contradiction | owning confidence/consequence rule, capped at `0.75` |
| `best_before` or `deadline` pressure | linear over its configured lead window, capped at `1.00` |
| matching preferred Place | `0.10` |
| phase `idea/spec/execution/validation` | `0/0.05/0.15/0.10` |
| impact `VERY_LOW..CRITICAL` | `0/0.02/0.04/0.06/0.08/0.10` |

The closed correlation keys are `availability`, `age`, `date`, `avoidance`,
`uncertainty`, `phase`, `impact`, `place`, `wip`, `schedule`, and
`review_consequence`. A rule emitting several observations about one fact uses
one key; it cannot multiply pressure by renaming the same cause. Factory lead
windows are seven days for both ordinary `best_before` and `deadline`; a
Template may declare a different visible lead window as part of its accepted
configuration.

Availability base signals are exhaustive: FOC-037's five execution variants
use `work`; `raw_triage` uses `raw_triage`; every FOC-061 organization-
maintenance member uses `lazy_review`; and every other FOC-054 non-execution
variant uses `operational_review`. Hard-precedence commitments and explicit
continuations do not receive an availability signal because they do not enter
the ordinary lottery.

The remaining derived signals use these closed formulas:

- an unresolved attributed claim has uncertainty
  `min(uncertainty.max, 1 - effective_confidence)`; an active contradiction
  uses the cap;
- excess-WIP review pressure is
  `min(0.50, 0.10 * max(0, wip_count - work.wip_soft_limit))`;
- quota-window schedule pressure is elapsed-window fraction times unmet-quota
  fraction, each clamped to `[0,1]`; fixed slots and finite occurrences use
  their date, age, and deferral evidence instead;
- review consequence is `min(0.50, 0.10 * affected_count)`, where
  `affected_count` is the number of additional distinct active attention
  subjects whose execution is currently gated by resolving this exact
  opportunity; and
- missing evidence yields no signal. It never substitutes a middle value.

The neglect-age clock starts when that exact opportunity first becomes
eligible: Feed time for Inbox Raw, release/opening time for a run, occurrence,
habit window, or review, and the latest completed attempt boundary for Work
that can be run again. A cooldown pauses admission but does not reset age.
Resolving the opportunity, replacing its semantic revision, or beginning a new
run/window resets the relevant origin. Consecutive deferral count likewise
resets only on a meaningful result or semantic replacement, not on viewing or
cooldown expiry. The `0.50 * (1 - 2^-count)` curve is evaluated by repeated
fixed-point halving. A zero-day date lead is a step: zero before the instant
and one at or after it.

`not_before` controls admission and never emits pressure before it opens.
Effort emits no ordinary-lottery signal: it informs planning, decomposition,
and the explicit tired/easier-work route. This avoids turning “easy” into an
undeclared meaning of important. Nature itself is neutral; its typed time,
recurrence, and review behavior emits the relevant signal instead.

### Context and negative evidence

Active-Domain affinity is `shared_depth / max(active_depth, candidate_depth)`;
an exact effective path is `1`, unrelated roots are `0`, and no active Domain
is neutral. Its factory factor is `1 + 0.75 * affinity`.

An accepted interaction-family result creates affinity `1` for that family,
then linearly decays to zero over 90 minutes. Its factor is
`1 + 0.50 * affinity`. A family-specific skip clears the current affinity for
that family in addition to its normal opportunity cooldown.

Domain fatigue or another explicitly declared negative contextual signal is
in `[0,1]`. Equal correlation keys collapse to their maximum; independent
values combine as `1 - product(1 - value)`. Factory fatigue linearly decays to
zero over 8 hours and multiplies weight by `1 - 0.75 * fatigue`, never by zero.
A known preferred-Place nonmatch contributes `0.10` in its own negative key;
missing or expired location evidence is neutral.

### Final integer weight and draw

For a subject:

```text
weight = importance_factor
       * pressure_factor
       * domain_factor
       * family_factor
       * negative_factor
```

For a local opportunity, the inherited subject factors cancel, so the same
formula uses neutral importance and only opportunity pressure, family, and
declared local context. The subject-level pressure input is the strongest
aggregated pressure among its eligible local opportunities; this preserves one
subject ticket.

The final fixed-point weight is clamped to at least `1`. Candidates are sorted
by canonical subject/opportunity identity, and cumulative totals use
nonnegative arbitrary-precision integers. For total `T > 1`, let `k` be the
bit length of `T - 1`. Each attempt concatenates `ceil(k / 256)` fresh digest
blocks, takes the first `k` bits most-significant first, and discards unused
bits. With integer `x` and `limit = floor(2^k / T) * T`, values at or above
`limit` retry; an accepted attempt samples `x mod T`. Total one selects its
sole interval without consuming a block. This rejection sampler maps
uniformly into `[0, total_weight)` without modulo bias. The first cumulative
interval containing that integer wins. Every admitted candidate therefore has
positive probability. The draw records purpose, ordered identities, integer
weights, total, starting/ending cursors, sampled integer, and chosen interval.

Displayed chance is `weight / total_weight`, rounded to one decimal percent
below 10% and to a whole percent at or above 10%; `<0.1%` replaces a nonzero
value that would round to zero. Display rounding never participates in a draw.
Hierarchical leaf chance is the product of recorded local probabilities along
its path and is explicitly labeled a projection rather than a second flat
lottery.

### Reference vectors

Three equally confident siblings at top, middle, and bottom position, with no
other signal, produce integer weights:

```text
A  1_000_000
B    287_500
C     50_000
total 1_337_500
```

If A then has maximum fatigue, B exact active-Domain affinity, and C maximum
positive pressure, the weights become:

```text
A    250_000
B    503_125
C    150_000
total   903_125
```

A sampled integer `600_000` selects B from canonical order. These vectors,
the zero/singleton boundaries, fixed-point rounding boundaries, maximum signal
sets, and rejection-sampling edge values are mandatory conformance fixtures.

## Bounded random helpers

The tired-flow `easier_work_sample` builds a weighted sample without
replacement of at most three executable alternatives. It multiplies the same
Domain factor by this explicit ease factor and uses no ordinary importance,
Impact, phase, pressure, or fatigue factor:

| Effort class | Ease factor |
|---|---:|
| `VERY_EASY` | `8` |
| `EASY` | `7` |
| `NORMAL` | `6` |
| `MODERATE` | `5` |
| `HARD` | `4` |
| `VERY_HARD` | `3` |
| `MINI_PROJECT` | `2` |
| `PROJECT` | `1` |
| not classified | `1` |

Each winner is removed before the next draw. Relative Effort evidence may
break an otherwise equal class only when its effective confidence is current;
otherwise canonical UUID order breaks a displayed tie. The chosen shortlist
is evidence only after the human selects one candidate, as FOC-044 requires.

`repeatable_return_jitter` draws uniformly from the inclusive integer range
accepted by WRK-142. `personality_phrase` draws uniformly from the 16 phrase
IDs for the declared intent. Both record the chosen value or stable phrase ID
in the resulting interaction so redraw never consumes again.

## Parameter registry

Every key below changes future calculations and rebuilds only current derived
confidence/forecast projections. It never rewrites canonical history. Ratio
ranges are inclusive; cross-key invariants are validated atomically.

| Key | Factory | Allowed range |
|---|---:|---:|
| `judgment.relevance_threshold` | `0.20` | `0.01..0.49` |
| `judgment.fresh_conflict_threshold` | `0.60` | `0.50..1.00` and greater than relevance |
| `judgment.transitive_extra_edge_factor` | `0.90` | `0.50..1.00` |
| `judgment.direct.initial` | `1.00` | `0.75..1.00` |
| `judgment.direct.horizon_days` | `365` | `30..3650` |
| `judgment.assisted.initial` | `0.80` | `0.25..0.95` and below direct |
| `judgment.assisted.horizon_days` | `270` | `30..3650` |
| `judgment.provisional.initial` | `0.15` | `0.01..0.49` |
| `judgment.provisional.horizon_days` | `30` | `1..365` |
| `judgment.model.initial` | `0.30` | `0.01..0.49` |
| `judgment.model.horizon_days` | `30` | `1..365` |
| `importance.validation.target_rate` | `0.10` | `0.00..0.50` |
| `judgment.axis.importance_horizon_days` | `365` | `30..3650` |
| `judgment.axis.impact_horizon_days` | `365` | `30..3650` |
| `judgment.axis.effort_horizon_days` | `180` | `7..1825` |
| `forecast.importance.bottom_factor` | `0.05` | `0.001..0.50` |
| `forecast.importance.neutral_factor` | `0.35` | `bottom..1.00` |
| `forecast.importance.exponent` | `2` | integer `1..4` |
| `forecast.pressure.additional_fraction` | `0.35` | `0.00..1.00` |
| `forecast.pressure.gain` | `2.00` | `0.00..4.00` |
| `forecast.domain.gain` | `0.75` | `0.00..2.00` |
| `forecast.family.gain` | `0.50` | `0.00..2.00` |
| `forecast.family.decay_minutes` | `90` | `1..1440` |
| `forecast.fatigue.max_reduction` | `0.75` | `0.00..0.95` |
| `forecast.fatigue.decay_hours` | `8` | `1..168` |
| `forecast.age.full_days` | `30` | `1..3650` |
| `forecast.age.max_signal` | `0.50` | `0.00..1.00` |
| `forecast.wip.per_excess_signal` | `0.10` | `0.00..1.00` |
| `forecast.wip.max_signal` | `0.50` | `0.00..1.00` |
| `forecast.review_consequence.per_subject_signal` | `0.10` | `0.00..1.00` |
| `forecast.review_consequence.max_signal` | `0.50` | `0.00..1.00` |
| `forecast.date.best_before_lead_days` | `7` | `0..365` |
| `forecast.date.deadline_lead_days` | `7` | `0..365` |

Factory phase, Impact, Place, availability, deferral, and review signal maps
are versioned arrays under `forecast.signal.*`; every entry is constrained to
`0..1` and starts with the values in the Positive pressure table. Removing an
entry is invalid because missing evidence must remain a deliberate neutral
mapping rather than an accidental semantic switch. The fixed-point scale,
authority tiers, PRNG construction, candidate order, and rounding mode are not
configuration keys.

The v1 signal-map registry is exact:

| Key | Factory |
|---|---:|
| `forecast.signal.availability.work` | `0.25` |
| `forecast.signal.availability.raw_triage` | `0.15` |
| `forecast.signal.availability.lazy_review` | `0.05` |
| `forecast.signal.availability.operational_review` | `0.20` |
| `forecast.signal.deferral.max` | `0.50` |
| `forecast.signal.uncertainty.max` | `0.75` |
| `forecast.signal.place.preferred_match` | `0.10` |
| `forecast.signal.place.known_mismatch` | `0.10` |
| `forecast.signal.phase.idea` | `0.00` |
| `forecast.signal.phase.spec` | `0.05` |
| `forecast.signal.phase.execution` | `0.15` |
| `forecast.signal.phase.validation` | `0.10` |
| `forecast.signal.impact.very_low` | `0.00` |
| `forecast.signal.impact.low` | `0.02` |
| `forecast.signal.impact.medium` | `0.04` |
| `forecast.signal.impact.high` | `0.06` |
| `forecast.signal.impact.very_high` | `0.08` |
| `forecast.signal.impact.critical` | `0.10` |

All are ratios in `0..1`. `known_mismatch` feeds the negative combiner; every
other entry feeds the positive correlation key named by its prefix or owning
rule. Age, date, and deferral use their declared curves rather than a second
lookup value. A typed rule without a registry entry may reuse an existing
meaningful key and curve; it may not create a new numeric signal in YAML.

## Calibration boundary

The formula family, signal meanings, fixed-point precision, and positive-tail
invariant are 1.0 semantics. Factory numbers may be revised before release
only by fixed-stream simulation that records the old/new profile hashes and
starvation, interruption, and continuity distributions. After release, a
number change is a versioned profile revision, never silent learning. Adding a
signal source, command, state, or hard gate requires a product specification
revision rather than YAML.

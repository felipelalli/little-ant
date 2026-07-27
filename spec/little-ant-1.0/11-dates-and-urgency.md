# 11. Dates and urgency

Three distinct date concepts are retained:

```text
not_before
best_before
deadline
```

- `not_before` is a hard eligibility constraint before its date.
- `best_before` is a soft target whose pressure rises before and after it.
- `deadline` is a hard deadline with strong approaching and overdue pressure.
- Dates never reorder the human priority tree.
- Dates affect forecast, `next`, warnings, and planning export.
- An earlier `due_at + delay_cost` proposal is superseded by these three
  explicit meanings.

## 11.1 Date pressure

Date pressure is a derived forecast input:

- before `not_before`, the Brick is ineligible;
- pressure from `best_before` rises as the preferred completion date
  approaches and may continue rising after it passes;
- pressure from `deadline` rises more strongly as the hard limit approaches
  and remains explicit while overdue;
- none of these conditions rewrites human priority.

The exact curves and thresholds remain configurable design details. Every
forecast explanation must identify the applicable date and condition rather
than hiding urgency inside an opaque score.

## 11.2 Date notices

Crossing a meaningful date threshold may create one informational notice
occurrence, such as:

```text
best_before_approaching
best_before_passed
deadline_approaching
deadline_overdue
```

These are working names. Notice production is idempotent. Its deduplication
identity includes at least the Brick, date field, applicable date revision,
and threshold. Repeated auto-ticks while the same threshold remains true do
not emit another occurrence or prepend the same warning to every command.

The continuing condition remains visible in status and forecast even after
the notice occurrence is acknowledged. Acknowledging a notice changes only
its presentation state. Snoozing it suppresses that occurrence until an
explicit time; it does not change the Brick's date, eligibility, priority, or
forecast pressure.

Changing the date creates a new revision against which thresholds are
evaluated. Completing or otherwise making the Brick inapplicable resolves its
active date notices. A later distinct threshold may create a new occurrence.

The REPL renders informational occurrences in its notice region. A canonical
CLI response may surface a newly crossed or immediately relevant warning once,
but ordinary command results are not permanently polluted by an unchanged
condition. No date notice authorizes an external notification without the
ordinary approval boundary.

A recurrence rule produces occurrence windows and may assign these date
semantics to each released Brick. Recurrence itself is not another deadline:

- an unpaid recurring obligation may remain overdue after a later occurrence
  is released;
- a practice opportunity uses an applicability window and records an
  unfulfilled outcome when that window expires;
- a blocked or explicitly paused practice does not accumulate false missed
  outcomes.

A completion-triggered repeat uses the same date vocabulary without creating a
window:

- finishing one execution may assign the same active Brick a future
  `not_before`;
- a requested delay such as six months plus or minus three months is converted
  into one replay-safe date using deterministic pseudo-random jitter;
- the base delay, jitter range, draw evidence, and selected `not_before` must be
  explainable from persisted history;
- this does not imply a `best_before`, `deadline`, expiry, missed occurrence,
  or another Brick;
- before `not_before`, the Brick is ineligible; at and after it, the same Brick
  is eligible under ordinary forecast pressure until executed or changed.

Timezone, daylight-saving, calendar arithmetic, and release-offset rules remain
open.

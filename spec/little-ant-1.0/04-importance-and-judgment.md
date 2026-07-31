# 4. Importance and judgment

## Human importance order

- **IMP-001 [core] — Meaning.** Human importance answers only which sibling is
  more important to the user. It is not urgency, dependency, execution
  sequence, impact, phase, or forecast probability.
- **IMP-002 [core] — Hierarchical strict order.** Every active Brick has one
  deterministic position among siblings. Root Bricks are siblings. Direct
  comparisons across parents are invalid.
- **IMP-003 [core] — Stable display.** The global importance view is a
  lexicographic traversal of sibling orders. Blocking may be displayed but
  never rewrites the order.
- **IMP-004 [core] — Binary insertion.** A new or locally displaced Brick is
  placed through resumable binary insertion, requiring approximately
  logarithmic human comparisons.
- **IMP-005 [core] — Adaptive bulk maintenance.** Initial and sanity-round
  ordering uses the v0 `org-sort-tasks` strategy: insertion sort for short
  runs, merge for longer runs, and an already-ordered short circuit.
  Each core step reuses applicable direct and transitive evidence and returns
  at most one genuinely unresolved pair. Comparisons persist independently so
  a round may stop and resume after any answer. The current deterministic
  position may guide traversal but is never treated as human comparison
  evidence, especially inside a provisional segment.

## Comparison grammar

The canonical semantic question is:

```text
Is

#a12345 "X"

    more important than

#b12345 "Y"
?

[m]ore important   [l]ess important   [s]kip   [?] I don't know
```

- **IMP-006 [core] — Directional answers.** `more important` records X above
  Y; `less important` records Y above X; `skip` records no edge; `?` asks for
  information or help and restores the same pending comparison. Importance
  comparisons do not use `yes` or `no`, because naming both directions is more
  precise than interpreting a negative proposition. The mnemonic `m/l` pair
  also supports fast repeated ordering rounds and is conveniently close on
  common Latin keyboard layouts; semantics remain authoritative on layouts
  where that physical convenience does not hold.
- **IMP-007 [core] — No equality answer.** The strict order has no
  `equally important` response. Not knowing, not caring now, and believing two
  things are close are different evidence and must not become false equality.
- **IMP-008 [core] — Nearby alternative.** The first ordering skip selects,
  replay-deterministically, another eligible sibling one to three positions
  above or below the current comparison neighborhood.
- **IMP-009 [core] — Provisional uncertain placement.** If the alternative is
  also skipped, the Brick is placed near the last comparator with low
  importance confidence. A `tie-break for me` skip subreason may delegate a
  strict provisional direction but still triggers a nearby validation attempt.
- **IMP-010 [core] — Uncertainty pressure.** Provisional placement remains a
  complete deterministic order while creating bounded future pressure for
  another comparison. It never blocks feeding or ordinary focus.

## Evidence and contradiction

- **IMP-011 [core] — Evidence history.** Comparisons retain direction,
  author, timestamp, context, reason, and supersession history. Newer
  applicable judgment receives more weight than older judgment.
- **IMP-012 [core] — Authority.** Direct human judgment overrides attributed
  AI evidence. AI may pre-order and suggest a default but cannot overwrite a
  human relation in either direction.
- **IMP-013 [core] — Contradiction is evidence.** Cycles, direct reversals,
  and conflicts with transitive implications lower confidence; they do not
  corrupt or delete history.
- **IMP-014 [core] — Local recalibration.** Contradiction schedules a bounded
  recalibration of the smallest affected sibling segment. Replacement evidence
  becomes current only when the segment is coherent.
- **IMP-015 [calibration] — Provocative validation.** The forecast may
  occasionally ask a direct comparison already implied transitively, with
  probability increased by low confidence, age, contradiction, or consequence.
- **IMP-016 [standard] — Investigation work.** Repeated uncertainty that could
  materially change focus may propose an ordinary Brick such as an interview,
  questionnaire, experiment, POC, or MVP. The core never invents the method or
  creates the Brick automatically.

## Expected impact

- **IMP-017 [standard] — Expected impact.** Impact is the expected magnitude,
  already accounting for uncertainty of success. It is classified directly
  only on roots and inherited by descendants.
- **IMP-018 [standard] — Public classes.**

  ```text
  VERY_LOW < LOW < MEDIUM < HIGH < VERY_HIGH < CRITICAL
  ```

  There is no public impact float.

- **IMP-019 [standard] — Evidence maturity.**

  ```text
  SPECULATIVE < SUPPORTED < VALIDATED < OBSERVED
  ```

  Maturity describes evidence quality and directness, not probability of
  success.

- **IMP-020 [standard] — Explicit reassessment.** Stale, contested, or
  scope-inapplicable evidence may lower internal reliability, but changing the
  public class or maturity requires an explicit attributed judgment. History
  remains intact.
- **IMP-021 [standard] — Validation is work.** Completing a validation Brick
  records evidence but never silently changes another Brick's impact.

## Effort

- **IMP-022 [standard] — Total effort.** Effort means all work required to
  complete the Brick's current scope from start to finish. It is not elapsed
  time, remaining effort, urgency, impact, emotional friction, or a promise in
  hours.
- **IMP-023 [standard] — Lazy and Nature-aware.** Missing effort is neutral.
  It is requested only when selection, decomposition, or planning would
  materially benefit.
- **IMP-024 [standard] — Versioned classes.** The factory EffortProfile is:

  ```text
  VERY_EASY < EASY < NORMAL < MODERATED < HARD < VERY_HARD
            < MINI_PROJECT < PROJECT
  ```

  A Brick retains the profile version under which it was classified.

- **IMP-025 [standard] — Planning references.** Profile macros may expose
  optimistic, realistic, and pessimistic hours, for example
  `EASY (~6 work hours, realistic)`. Hours belong to the profile and planning
  projection, never canonical Brick state.
- **IMP-026 [standard] — Derived remaining effort.** Remaining effort is a
  conservative projection from completed descendants, explicit progress, or
  imported actuals. Focus duration alone never reduces it.
- **IMP-027 [standard] — Assisted classification.** `?` may run at most three
  adaptive comparisons against high-confidence historical exemplars. `skip`
  records no effort evidence and never blocks work.
- **IMP-028 [standard] — Parent scope.** Parent effort includes descendant
  scope rather than adding to it. Decomposition coverage is explicitly
  reviewed as open or complete; structural edits reopen that judgment.
- **IMP-029 [standard] — Actuals remain evidence.** Observed hours never
  rewrite the historical estimate. A large mismatch may provoke a profile or
  scope review.

Importance, impact, effort, and phase remain independent. None is a hidden
sort key for another. The remaining impact/effort assistance grammar and
confidence presentation are `OPEN-JUD-001`.

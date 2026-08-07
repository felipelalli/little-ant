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
  logarithmic human comparisons. After reusable evidence narrows the interval,
  the first unresolved comparator is its ordinary midpoint. A Dependency
  target is not privileged as an insertion anchor, because prerequisite order
  is not importance evidence. IMP-030 is the explicit batch-creation case:
  it creates a complete provisional sibling order first and defers human
  refinement rather than blocking the transaction on comparisons.
- **IMP-005 [core] — Adaptive bulk maintenance.** Initial and sanity-round
  ordering uses the v0 `org-sort-tasks` strategy: insertion sort for short
  runs, merge for longer runs, and an already-ordered short circuit.
  Each core step reuses applicable direct and transitive evidence and returns
  at most one genuinely unresolved pair. Comparisons between existing Bricks
  persist independently so a round may stop and resume after any answer. When
  one side is a not-yet-created Feed draft, answers remain in the recoverable
  Interaction checkpoint and become evidence only in the atomic creation;
  cancelling the draft discards them. The current deterministic position may
  guide traversal but is never treated as human comparison evidence,
  especially inside a provisional segment.
- **IMP-030 [core] — Entered batch order seeds a provisional run.** An accepted
  break creates its new siblings contiguously in the order entered by the
  user, or in an explicitly accepted assisted order. This gives every child a
  deterministic position at birth without claiming that entry sequence is an
  importance comparison, dependency, or execution sequence. The run starts
  with low importance confidence and claim-scoped lazy review pressure. An
  assisted run also retains AI provenance and never becomes human comparison
  evidence merely because the whole preview was accepted. Later adaptive
  maintenance starts from this existing run, reuses applicable evidence, and
  asks only unresolved comparisons; it does not first shuffle or rebuild the
  list. This run-sensitive requirement preserves the useful intuition behind
  adaptive sorting without mandating Timsort instead of the resumable
  `org-sort-tasks` strategy in IMP-005.
- **IMP-045 [core] — Added sibling batches start as one low-confidence
  tail run.** When one accepted operation adds one or more active children to
  a parent that already has active children, the new Bricks form one
  contiguous provisional run after the current active siblings, in accepted
  draft order. This lower-end placement is a deterministic birth position,
  not human importance evidence, a dependency, or an execution sequence. It
  does not reinterpret IMP-004's midpoint comparator as an unasked answer.
  The whole added run contributes one `importance_run_review`; later adaptive
  maintenance reuses the existing sibling order and asks only unresolved
  comparisons. If no active sibling exists, the run is simply the complete
  active sibling order. Inactive children occupy no current importance slot
  and cannot anchor the new run.
- **IMP-031 [core] — One algorithm, two cadences.** A lottery-selected
  `importance_run_review` serves one genuinely unresolved pair chosen by the
  resumable `org-sort-tasks` state. An accepted `more` or `less` answer records
  that comparison and ends only the current lottery interaction; if the run
  remains unresolved, its review marker stays pending. The first ordering
  skip may try the bounded nearby alternative required by IMP-008, while the
  second ends that lottery interaction with provisional confidence and
  review-specific cooldown. Explicit `/order` instead enters continuous
  maintenance: after
  each accepted answer it asks the next pair from the same algorithm
  immediately, until the selected scope is coherent or the user exits. Both
  cadences read and write the same comparison history, checkpoints, current
  order, and contradiction state; `/order` is not a second sorter.
- **IMP-032 [core] — Explicit ordering scopes preserve sibling locality.**
  `/order` can maintain the current sibling group, every unresolved sibling
  group intersecting the current Domain, every unresolved sibling group in
  the dataset, or a specifically selected parent or Domain. Domain-wide and
  dataset-wide sessions orchestrate several independent sibling runs; they
  never compare Bricks that have different parents. Groups without unresolved
  maintenance are omitted. A Brick argument names the parent whose direct
  children form the group, while a Domain argument selects all qualifying
  groups intersecting that Domain. The guided surface resolves either target
  through UX-092 rather than depending on memorized handles or Domain paths.
- **IMP-039 [core] — Lower-order recovery still requires comparisons.** A
  served-work `order it lower` reaction carries one Brick into the existing
  continuous `/order` cadence for its sibling group. The current position
  narrows the first search interval toward lower siblings, but the reaction
  itself creates no edge and moves nothing. Every actual relation still comes
  only from the canonical `more important` or `less important` answer, with
  normal evidence reuse, contradiction handling, nearby skip, and resumable
  `org-sort-tasks` behavior. The resulting position may move less than the user
  expected or remain unchanged when answers and existing evidence require it;
  the system never fabricates a downward comparison from the symptom.

## Comparison grammar

The canonical semantic question is:

```text
Is

#x "X"

    more important than

#y "Y"
?

[m]ore important   [l]ess important   [s]kip   [?] I don't know
```

- **IMP-006 [core] — Directional answers.** `more important` records X above
  Y; `less important` records Y above X; `skip` records no edge; `?` enters
  the IMP-040 honest-answer tree while preserving the pending comparison.
  Importance comparisons do not use `yes` or `no`, because naming both
  directions is more precise than interpreting a negative proposition. The
  mnemonic `m/l` pair
  also supports fast repeated ordering rounds and is conveniently close on
  common Latin keyboard layouts; semantics remain authoritative on layouts
  where that physical convenience does not hold.
- **IMP-007 [core] — No equality answer.** The strict order has no
  `equally important` response. Not knowing, not caring now, and believing two
  things are close are different evidence and must not become false equality.
  An explicit `either_order` judgment under IMP-042 means only that this pair
  needs no human precedence; it neither asserts equal importance nor creates
  an equivalence class.
- **IMP-008 [core] — Nearby alternative.** The first ordering skip selects,
  replay-deterministically, another eligible sibling one to three positions
  above or below the current comparison neighborhood. The same comparison
  grammar redraws immediately with the replacement; no acknowledgment or
  explanatory interstitial interrupts either ordering cadence.
- **IMP-009 [core] — Provisional uncertain placement.** If the alternative is
  also skipped, the Brick is placed near the last comparator with low
  importance confidence. In lottery cadence this closes the selected cycle;
  in explicit `/order` cadence the next unresolved pair appears immediately.
  A pass can therefore finish with a complete deterministic order and pending
  low-confidence placements; those placements schedule later review rather
  than keeping the direct command in a loop. A `tie-break for me` skip
  subreason may delegate a strict provisional direction but still triggers a
  nearby validation attempt.
- **IMP-010 [core] — Uncertainty pressure.** Provisional placement remains a
  complete deterministic order while creating bounded future pressure for
  another comparison. It never blocks feeding or ordinary focus.

## Evidence and contradiction

- **IMP-011 [core] — Evidence history.** Comparisons retain direction,
  author, timestamp, context, reason, and supersession history. Current
  calculation uses effective confidence rather than deleting inconvenient
  evidence.
- **IMP-012 [core] — Authority.** Direct human judgment overrides attributed
  AI evidence. AI may pre-order and suggest a default but cannot overwrite a
  human relation in either direction.
- **IMP-013 [core] — Contradiction is confidence-sensitive evidence.** Cycles,
  direct reversals, and conflicts with transitive implications never corrupt
  or delete history. A new direct judgment may silently outrank an old path
  whose effective confidence has decayed below the configured relevance
  threshold. A cycle among recent, independently strong judgments is not
  resolved by recency alone; it enters the explicit UX-O06 resolution gate.
- **IMP-014 [core] — Local recalibration.** Contradiction schedules a bounded
  recalibration of the smallest affected sibling segment. Replacement evidence
  becomes current only when the segment is coherent.
- **IMP-015 [core] — Provocative validation is not sorting.** A separate
  validator may choose two siblings whose strict relation is currently implied
  only by a transitive path and has never been asked directly. Its
  replay-deterministic configured probability is evaluated outside the
  `org-sort-tasks` pair selector, so the minimal sorter never invents a
  redundant comparison and explicit `/order` never interleaves validation
  questions. Confirmation records a direct edge and strengthens the path. A
  contrary answer follows IMP-013: weak old support yields to the new judgment,
  while a recent strong cycle opens UX-O06. Candidate scoring may favor age,
  low confidence, consequence, or a weak path, but never changes the implied
  direction into a suggested default or leading question.
- **IMP-016 [standard] — Investigation work.** Honest-answer assistance that
  identifies missing material evidence, or repeated uncertainty that could
  materially change focus, may propose an ordinary Brick such as an interview,
  questionnaire, experiment, POC, or MVP. The core never invents the method or
  creates the Brick automatically.
- **IMP-040 [core] — Honest importance discovery.** Question mark on an
  ordinary two-Brick importance comparison asks one question per screen and
  follows this bounded factory tree, where A is the first displayed Brick and
  B is the second:

  ```text
  Q0. Do you understand the result A is meant to produce and what would be
      lost if it were never done?
  ├─ yes → Q2
  └─ no or unknown
     Q1. Would reviewing A's existing context and linked material be enough?
     ├─ yes → inspect A, then return to Q0
     └─ no  → propose investigation work about A

  Q2. Do you understand the result B is meant to produce and what would be
      lost if it were never done?
  ├─ yes → Q4
  └─ no or unknown
     Q3. Would reviewing B's existing context and linked material be enough?
     ├─ yes → inspect B, then return to Q2
     └─ no  → propose investigation work about B

  Q4. If only one could ever be completed, would you choose A?
  ├─ yes → A is more important than B
  └─ no or unknown → Q5

  Q5. Would you choose B instead?
  ├─ yes → B is more important than A
  └─ no or unknown → Q6

  Q6. Would either order be acceptable because neither Brick needs
      precedence over the other?
  ├─ yes → either_order
  └─ no  → Q7

  Q7. Could new evidence change which one you would choose?
  ├─ yes → propose investigation work about the relationship
  └─ no  → Q8

  Q8. Would comparing one of them with another nearby sibling help?
  ├─ yes → one bounded nearby comparison
  └─ no  → provisional uncertain placement
  ```

  Q1, Q3, and Q6..Q8 use UX-017 alternate probes for uncertainty; repeated
  uncertainty leaves the comparison pending. Every consequential leaf is
  explicitly confirmed under UX-136 before mutation.
- **IMP-041 [core] — Unknown transitions are node-local.** An uncertainty
  answer may reach the same next screen as `no` only when both truthfully
  require the same recovery. At Q0 and Q2, absence of a confident `yes` means
  that more understanding is required. At Q4 and Q5, uncertainty may continue
  to the next discriminator but remains distinct from an explicit rejection;
  it creates no negative judgment. At Q1, Q3, and Q6..Q8, uncertainty asks an
  alternate probe and never follows `no` silently. These policies are part of
  the versioned tree rather than a global alias from question mark to `no`.
- **IMP-042 [core] — Either order is pair-local evidence.** Explicitly
  confirmed `either_order` is symmetric direct human evidence that the exact
  relative order of A and B is immaterial for the current judgment. It creates
  neither A > B nor B > A, does not mean that either Brick is globally
  unimportant, and is not transitive. The sorter still materializes one total
  deterministic order: during insertion it places the subject immediately
  before or after the comparator through a versioned stable tie-break; during
  maintenance it preserves the stable local order unless other effective
  evidence requires movement. Adjacency is a placement result, not a permanent
  invariant. The evidence decays normally, suppresses redundant review while
  relevant, remains inspectable, and yields to a later direct human direction
  without deleting history.
- **IMP-043 [core] — Investigation gates only the relationship review.** An
  accepted investigation recovery enters contextual Feed for one ordinary
  user-defined Brick linked to the pending A/B comparison. Dumb mode never
  invents its method or title; Skill or powered-up mode may make one attributed
  proposal. The investigation neither becomes a child or blocker of A or B
  nor makes either ineligible for focus. It suppresses only that comparison's
  maintenance opportunity until the investigation is completed or explicitly
  closed; that outcome then creates high but bounded pressure to compare the
  pair again and never determines the direction automatically.
- **IMP-044 [core] — Importance recovery is bounded.** Inspecting existing
  context reuses the read-only `/show` projection and returns to the exact Q0
  or Q2 checkpoint without an event. A nearby-comparator recovery uses at most
  one eligible sibling one to three positions away, records no skip, and marks
  that local aid as spent only inside the interaction. If it still cannot
  resolve the insertion, the tree may offer explicit provisional placement.
  Confirming that leaf applies IMP-009's deterministic low-confidence
  placement and future review pressure with reason `uncertain_after_help`, but
  records no comparison edge, equality, `either_order`, or skip.
- **IMP-033 [core] — Temporal confidence decay.** Every direct judgment has a
  provenance-derived initial confidence and a monotonic age-decay curve. The
  versioned factory configuration defines its shape, relevance threshold, and
  finite horizon after which effective confidence is zero for current
  calculation. Expired evidence remains inspectable history and may explain a
  later recalibration, but it cannot keep a stale relation artificially
  authoritative. Refresh requires a new judgment; merely replaying or viewing
  history never resets age.
- **IMP-034 [core] — Transitive confidence and fresh-cycle resolution.** The
  effective confidence of an inferred relation is no greater than the weakest
  applicable edge on its path and is reduced by a versioned path-length
  penalty. When a contrary direct answer conflicts only with a path below the
  relevance threshold, the answer becomes current and the old path becomes
  inactive or reviewable without interruption. When every edge needed to form
  the minimal cycle remains above the fresh-conflict threshold, the new answer
  stays pending and UX-O06 must resolve it atomically. Choosing `changed`
  activates the new relation and retires every older edge on that conflicting
  path from current calculation; choosing `mistake` retracts the pending
  direction and records its direct reverse. Retired and retracted evidence
  remains in the append-only history with its resolution reason.
- **IMP-035 [core] — Unresolved contradiction remains explicit.** If the user
  still cannot choose after the bounded contradiction aid, every displayed
  judgment remains preserved as unresolved evidence while the last coherent
  effective order stays operational. The smallest affected sibling segment
  receives low confidence and bounded future recalibration pressure; no edge
  becomes equality, no latest answer wins silently, and no history is retired.
  Explicit `/order` may continue with an unaffected segment rather than trap
  the user. Repeated material uncertainty may invoke the proposal-only
  investigation policy in IMP-016, but never creates a Brick automatically.
- **IMP-036 [core] — Longer cycles reduce to bounded three-way judgments.** A
  fresh minimal cycle longer than three never creates an unbounded choice
  screen. The resolver chooses the pending contrary edge's two endpoints plus
  the next sibling on the conflicting path, asks the same UX-O07 three-way
  counterfactual, records its winner above the other two, retires incompatible
  current edges, and recomputes the smallest remaining cycle. It repeats only
  while a cycle remains. Each step is deterministic from the same evidence and
  creates no judgment about the two non-winners. A second uncertainty response
  at any step follows IMP-035 immediately rather than forcing the remainder.
- **IMP-037 [core] — Provocative skip preserves the inferred order.** The first
  skip on an IMP-015 validation may try one other eligible transitive-only pair
  from the same sibling group without invoking `org-sort-tasks` or a forecast
  draw. A second skip, or a first skip when no alternative exists, ends the
  validation with a pair-specific cooldown. No skip creates an edge,
  provisional placement, equality, confidence penalty, or persistent review
  marker; the previously inferred relation keeps only the confidence it
  already had and continues ordinary temporal decay. The independent validator
  may consider the pair again after cooldown.

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
- **IMP-038 [standard] — Recovery choices are weak relative evidence.** When
  UX-S08 asks which of three currently executable opportunities feels easiest
  to tackle while tired, selecting one records weak, attributed evidence that
  its offered work unit requires less effort than each unchosen work unit.
  This bounded contextual comparison never assigns a numeric estimate or an
  EffortProfile class. It is weaker than a dedicated effort judgment because
  current energy may affect the answer. For finite work with comparable
  current scopes it may inform later Brick effort classification; for a run,
  occurrence, or checklist session it describes only the offered work unit
  and never the standing Brick's unbounded lifetime. The same choice is strong
  short-lived forecast evidence under FOC-044.

Importance, impact, effort, and phase remain independent. None is a hidden
sort key for another. The remaining impact/effort assistance grammar and
confidence presentation are `OPEN-JUD-001`.

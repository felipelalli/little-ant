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
- **IMP-046 [core] — A missing nearby alternative never traps insertion.** If
  the first comparison skip has no other eligible sibling within IMP-008's
  configured distance, the draft or Brick is placed immediately adjacent to
  the last comparator using replay-deterministic direction, low confidence,
  reason `no_nearby_alternative_after_skip`, and ordinary future review
  pressure. The skip remains uncertainty, not indifference or human direction.
  A pending comparison also exposes contextual `/tie-break`: it records an
  attributed deterministic provisional direction, attempts the same nearby
  validation when one exists, and otherwise reaches low-confidence placement.
  It creates no human comparison edge. Cancelling an uncommitted creation
  still discards that provisional placement with its draft.
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
  VERY_EASY < EASY < NORMAL < MODERATE < HARD < VERY_HARD
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
- **IMP-047 [core] — Judgment units are explicit and comparable.** Importance
  continues to compare sibling Bricks under IMP-001..016. Impact compares only
  active composition roots and means the difference their outcomes are
  currently expected to make; a child displays its current root's impact as
  inherited evidence and cannot acquire a competing direct impact value. Effort compares
  the complete current finite scope of Bricks with compatible execution
  boundaries. A standing identity is compared only as one named run, window,
  session, or occurrence, never as its unbounded lifetime. A screen that
  cannot state comparable units does not ask the question.
- **IMP-048 [standard] — Missing judgment is honest and neutral.** Impact and
  effort remain absent until evidence or an explicit human classification
  exists. Missing impact is not `MEDIUM`; missing effort is not `NORMAL`; and
  neither receives a hidden weakest or strongest value. Forecasting preserves
  positive probability for missing values. Compact views omit the absent
  field, while a judgment screen says `not classified` rather than displaying
  a fabricated class.
- **IMP-049 [standard] — Direct impact classification has no class default.**
  `/impact #brick` presents the six ordered public classes with short semantic
  anchors and no selected row. After the human chooses a class, evidence
  maturity defaults visibly to `SPECULATIVE` only when no supporting evidence
  is selected. The default says that the class is a judgment without evidence;
  it does not choose the class. A child route cites and opens its composition
  root instead of storing a child override. Clearing a direct root judgment is
  explicit and leaves history intact.
- **IMP-050 [standard] — Impact comparison uses expected difference.** Two
  comparable roots use `more impact`, `less impact`, `about the same`, `skip`,
  and uncertainty. The comparison uses what is currently known about both
  likely result and uncertainty of success; it never silently switches to
  best-case or success-assumed magnitude. `About the same` is pair-local
  evidence that the two outcomes plausibly occupy the same public class; it
  is not equality of importance, a permanent equivalence class, or transitive
  identity. Relative evidence never silently assigns a class. When reviewed
  class anchors and comparisons narrow one root to a single class, the core
  may propose that class for explicit confirmation.
- **IMP-051 [standard] — Maturity is derived through one evidence ladder.**
  Maturity exists only with a direct impact class. The dumb evidence review
  selects attached Raw material or completed validation Work, then asks one
  question per screen in descending order:

  ```text
  Q0. Was the claimed result observed in its real intended setting?
  ├─ yes → OBSERVED
  └─ no or unknown → Q1

  Q1. Was it directly tested in a representative setting?
  ├─ yes → VALIDATED
  └─ no or unknown → Q2

  Q2. Is there relevant support beyond intuition or the original claim?
  ├─ yes → SUPPORTED
  └─ no or unknown → SPECULATIVE
  ```

  `SUPPORTED` requires at least one selected relevant Raw or outcome;
  `VALIDATED` requires an applicable deliberate test, analysis, POC, MVP,
  questionnaire, experiment, or equivalent completed validation result; and
  `OBSERVED` requires an applicable real-setting observation. The selected
  evidence and applicability assertion remain attributed. A description alone
  is not support merely because it is attached.
- **IMP-052 [standard] — Promotion and demotion are explicit.** New or
  completed evidence creates an `impact_maturity_review`; it never changes the
  class or maturity itself. Removed, stale, contradicted, or scope-inapplicable
  evidence marks the current judgment `review due` without silently demoting
  it. Review may retain the level with replacement or reaffirmed applicable
  evidence, choose the highest level supported by IMP-051, revise the impact
  class, or clear the judgment. The accepted preview lists evidence added,
  retained, and no longer relied upon. History preserves every former class,
  maturity, and reason.
- **IMP-053 [standard] — Direct effort classification uses the versioned
  ladder.** `/effort #brick` lists all current EffortProfile classes in order,
  with their realistic planning reference, and has no dumb default. The
  question always names total effort from the current scope's start to finish.
  A direct human choice is reviewed evidence; observed hours, elapsed focus,
  emotional friction, and remaining effort do not silently select or rewrite
  it. A structural scope change marks the value `review due` rather than
  guessing a replacement.
- **IMP-054 [standard] — Effort discovery favors small human comparisons.** A
  lottery `effort_comparison` shows two to four comparable work units and asks
  which looks easiest to complete. One selection records direct relative
  evidence that the chosen unit is easier than every unchosen unit, but no
  EffortProfile class or hour value. Uncertainty on direct classification may
  instead compare the subject, one at a time, with at most three reviewed
  historical exemplars using `more effort`, `less effort`, or `about the
  same`. Each answer narrows the remaining class interval. If one class
  remains, it is proposed explicitly; if several remain after the limit, only
  those classes are shown for direct choice. With no suitable exemplar, the
  direct ladder returns unchanged and no `NORMAL` fallback is invented.
- **IMP-055 [core] — All pairwise judgments share recency and contradiction
  discipline.** Impact and effort comparisons retain the same provenance,
  temporal decay, weakest-path confidence, immutable history, fresh-cycle
  gate, and smallest-segment recalibration principles as IMP-011..015 and
  IMP-033..037. Each axis has an independent provocative validator outside
  both the importance sorter and ordinary classification selector. It may ask
  a never-directly-asked relation implied by recent evidence; explicit
  `/order`, `/impact`, and `/effort` never inject such a question into their
  direct cadence.

  A recent strong impact or effort contradiction offers `changed`, `revise
  answer`, and uncertainty. `Changed` accepts the pending relation and retires
  only the conflicting current path; `revise answer` restores the original
  comparison with no pending relation. The bounded uncertainty aid asks which
  outcome has the greatest expected effect for impact, or which unit would
  require the least total effort for effort, and also permits
  `about the same`. Old weak paths yield to a newer direct human judgment
  without interruption. Unresolved recent conflict preserves the last
  coherent result and creates bounded future review pressure.
- **IMP-056 [standard] — Confidence is useful without a public score.**
  Ordinary rendering uses only `reviewed`, `provisional`, or `review due`, plus
  concise provenance when it matters. A direct human class is `reviewed`;
  enough compatible human comparisons may produce a reviewed class proposal
  only after confirmation. An accepted powered-up or Skill proposal remains
  `provisional · assisted by <provider>` until a later human review, even
  though it is usable immediately. A stale or structurally invalidated class
  is `review due`. Relative-only evidence renders as `not classified · N
  comparisons`. Numeric confidence is available only in explicit structured
  evidence/forecast inspection, never as a user-facing target to optimize.
- **IMP-057 [core] — Generated obligation occurrences reuse series
  importance.** A `recurring_obligation` series owns one ordinary human
  importance position. Its generated occurrences are independent Bricks for
  lifecycle, focus, history, and references, but they do not create sibling
  insertion questions or additional root importance positions. The importance
  projection nests them beneath the series in nominal-anchor order; the focus
  forecast chooses among open occurrences with ordinary age and temporal
  evidence after the series attention subject wins. This is a closed
  Nature-owned generated lane, not FIFO execution, manual composition, or a
  general exception available to Packs.

Importance, impact, effort, and phase remain independent. None is a hidden
sort key for another.

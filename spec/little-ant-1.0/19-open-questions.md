# 19. Open questions

These questions must be resolved through continued discovery before changing
the Allium specification. An item listed here is not an implicit 1.0
commitment.

## 19.1 Recommended resumption order

The next session should begin with these four clusters:

1. evidence rules for promoting and lowering impact maturity;
2. the assisted impact-classification dialog;
3. the public representation of effort confidence;
4. the exact REPL key grammar, terminal behavior, and command-palette flow.

After those clusters, continue the other conceptual questions and then perform
the existing Little Ant Brick review described in chapter 20.

## 19.2 Raw and source semantics

- What are the exact link relation names: `source`, `attachment`,
  `derived_from`, `target`, `about`, or a smaller set?
- Can a Brick inherit Raw or source links from ancestors?
- Does the current `SourceLink` concept merge into Raw, remain separate, or
  represent a live upstream object distinct from captured material?
- What does “consumable” mean now that Raw use is non-consuming?
- How are snapshot failures, inaccessible files, HTTP errors, retries, and
  backoff represented?
- When may unreferenced blobs be garbage-collected, if ever?
- Is permanent Raw deletion supported, or only archive?

## 19.3 Brick metadata and phase

- Exact phase emojis and terminal markers.
- Exact phase-confidence evidence and UI threshold.
- Whether `atomicity` remains unchanged or needs a better model.
- Exact `mode` values: only `digital | physical`, or also `hybrid`, `any`, or
  `unknown`.
- How mode uncertainty interacts with nearest-ancestor inheritance.
- Whether `about`, requester, Raw links, and source links inherit.

## 19.4 Tree operations, decomposition, and scope

- Exact commands and event semantics for batch done, drop, move, and
  supersede.
- How active delegations, waits, dependencies, and proposed effects behave
  when a subtree is closed.
- How supersede transfers selected children without ambiguity.
- Whether dependencies crossing a moved or closed subtree require explicit
  reconciliation.
- The final field and command names for decomposition coverage
  (`open | complete` is working vocabulary).
- Which mechanical changes create `scope_review`, and how several suspicions
  are coalesced.
- The exact confirmation grammar and event shape for `scope_revised`.
- How the core determines the smallest set of affected relationships without
  erasing unrelated judgments.
- The exact relationship by which a validation Brick targets an impact
  assessment, including whether it may simultaneously be a child and a
  dependency.

## 19.5 Priority comparison and confidence

- Exact formula for priority confidence, recency, and decay.
- Baseline provocative-validation probability and its adaptive multipliers.
- How a recalibration round persists and resumes.
- The minimum coherent evidence required before an affected segment is
  atomically replaced.
- How reasons and semantic changes affect priority-evidence staleness.
- Whether priority-confidence thresholds are global or configurable.

## 19.6 Impact classification and maturity

- The evidence required to promote each transition between `SPECULATIVE`,
  `SUPPORTED`, `VALIDATED`, and `OBSERVED`.
- The explicit process for lowering maturity when evidence becomes stale,
  contested, or inapplicable.
- Whether a human may directly select an impact class, request assistance, or
  both.
- The canonical impact question wording, answers, skip behavior, and maximum
  number of assisted comparisons.
- The default impact class when there is no reasonable basis for a judgment.
- How comparison history maps to the six public classes without exposing a
  public float.
- The internal reliability calculation from maturity, recency, provenance,
  and consistency.
- The threshold for proposing real validation work based on expected value of
  information, and the proposal's canonical name.

## 19.7 Effort classification and calibration

- The public representation of effort confidence: discrete labels, reasons
  only, another model, or some combination.
- Exact exemplar-selection and adaptive-comparison rules for the three-question
  assisted flow.
- How the five comparison answers map to a provisional class.
- How users edit an EffortProfile and how profile revisions are versioned.
- How old estimates behave when a newer profile becomes active.
- How open-ended outliers affect confidence and break-work pressure.
- Exact conservative derivation of remaining effort from descendants, explicit
  progress, and imported actuals.
- Thresholds that provoke profile or scope review after an actual-estimate
  mismatch.

## 19.8 Selection and proposals

- Exact forecast formula and normalization.
- Exact cooldown and aging curves for served-Brick, ordering, and
  classification skips.
- Whether every candidate needs only positive probability or a bounded service
  guarantee.
- Exact deterministic precedence before the lottery.
- Which proposals are fully derived and which require persisted resumable
  state.
- How interrupted question rounds resume.
- Whether proposal weights are configuration, learned policy, or both.
- Final command names for priority and forecast views.
- How internal impact reliability and effort confidence affect selection
  without becoming hidden public scores.

## 19.9 WIP and focus grammar

- Canonical commands for focus, unfocus, WIP start, and return to idle.
- Exact stale-focus threshold and what counts as activity.
- Exact soft-limit review pressure above three WIPs.
- Whether current focus may point to a temporarily ineligible Brick.

## 19.10 Served-Brick skip taxonomy

- Which existing skip reasons survive unchanged in 1.0.
- Whether fear or anxiety deserves its own reason after evidence review.
- Exact English shortcut letters after all command namespaces are known.
- How reason-specific reactions become proposals without meta-Bricks.
- Whether snooze is distinct from cooldown, wait, and `not_before`.

## 19.11 TaskJuggler and planning

- The exact planning-manifest schema, location, naming, retention, and adapter
  versioning.
- How dependencies outside selected export scopes are represented.
- How resources, efficiency, calendars, and scenario inputs are selected.
- How a newer EffortProfile affects a plan containing older estimates.
- Exact preview and confirmation grammar for actual import.
- Thresholds and presentation for estimate-versus-actual warnings.

The following are settled and must not be treated as open: a parent effort
includes descendant scope; the planning cut is non-overlapping; each selected
cut node uses one macro; and each confirmed run produces an immutable manifest
outside operational domain state.

## 19.12 REPL harness

- Exact one-key grammar, including global, screen-local, and answer shortcuts.
- Exact command-palette selection behavior and whether it accepts raw canonical
  command syntax.
- Terminal layout, resize behavior, colors, accessibility, and UI library.
- Exact non-TTY behavior.
- Idle tick cadence and safe-boundary scheduling.
- Notice rotation, dismissal, snooze, and recurrence details.
- Recent-activity length and the metadata used to group several events into
  one semantic action.
- `/history` search and navigation grammar.
- Checkpoint file naming, transcript size and retention, cleanup, and
  multi-device conflict behavior.
- Exact rebase and recovery choices when the event log advanced.
- How outbound integrations are displayed without weakening approval rules.

## 19.13 Core surfaces and migration

- Final canonical command names, flags, output fields, and English grammar.
- Projection formats for priority confidence, effort confidence, evidence
  maturity, and internal warning reasons.
- Exact event schema and upcast path from v0 to 1.0.
- Whether migration rewrites historical events or only upcasts them on read
  before an explicit normalization command.
- How existing stage, weight, kind, estimate, Raw, and WIP data map into the
  new axes and discrete profiles.
- Exact version bump point and migration rollback or backup procedure.

## 19.14 Existing feature review

- Recurrence and habits.
- Source reconciliation policy.
- Start-time effects.
- Mobile and multi-device event union.
- Concurrent event-log behavior.
- Search, rendering, web UI, and status-line projections.
- Remaining bugs and ergonomic requests in the current backlog.

These are not implicitly accepted into 1.0. They will be reviewed Brick by
Brick with the user.

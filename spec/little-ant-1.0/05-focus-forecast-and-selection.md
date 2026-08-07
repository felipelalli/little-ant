# 5. Focus forecast and selection

## The derived distribution

- **FOC-001 [core] — Forecast, not a second order.** The focus forecast is a
  read-only derived probability distribution over currently selectable
  opportunities. It is never persisted as another ranked list.
- **FOC-002 [core] — Explainable probability.** Forecast inspection exposes
  current chance, relevant signals, uncertainty, context, blockers, and
  actionable endpoints without consuming randomness or changing a future draw.
- **FOC-003 [core] — Positive long tail.** Every admitted candidate retains a
  strictly positive chance. Importance strongly informs probability but never
  creates a deterministic frontier that starves unusual work.
- **FOC-004 [calibration] — Configurable curve.** The importance curve, long
  tail, aging, cooldowns, Domain and interaction-family affinity strength and
  decay, signal bonuses, and caps use versioned factory defaults and
  replay-safe configuration.
- **FOC-005 [core] — Replay-deterministic draw.** `next` records the clock,
  configuration version, random seed or cursor, admitted set, probabilities,
  every branch choice, and the final opportunity so replay reproduces it.

## Subjects and opportunities

- **FOC-006 [core] — One subject ticket.** Every selectable opportunity belongs
  to one canonical attention subject. A subject receives one surrounding
  chance regardless of how many reviews or questions currently apply to it.
- **FOC-007 [core] — Local opportunity draw.** After a subject is chosen, a
  locally normalized weighted subdraw selects one applicable opportunity.
  Adding a proposal therefore cannot create a duplicate top-level ticket.
- **FOC-008 [core] — Strongest signal plus bonus.** Subject pressure is
  anchored by its strongest applicable signal. Additional sufficiently
  independent signals contribute a bounded diminishing-return bonus rather
  than being summed as independent tickets.
- **FOC-009 [core] — Closed opportunity family.** Work focus, comparisons,
  judgment probes, reviews, approvals, delegation follow-ups, Raw/source
  decisions, and other v1 opportunities use a versioned closed catalog of
  canonical variants. There is no generic `interaction` command or
  Pack-defined opportunity kind. Each variant is a discriminated semantic
  schema with its own required payload, valid actions, and transition family;
  there is no generic `review` variant assembled from mutually exclusive
  optional fields. Two offers share one variant plus a typed `purpose` only
  when their action set and transition family are the same and only their
  trigger or provenance differs. Different actions or consequences require
  different variants even when both render through the same primary screen
  grammar. Forecast signals, warnings, and secondary context modify selection
  or presentation and never become opportunities merely because they exist.

The exact final catalog is a release-blocking decision tracked as
`OPEN-FOC-001`; extending it later requires an explicit core version.

- **FOC-037 [core] — Distinct execution opportunities.** The ordinary 1.0
  lottery contains five canonical execution variants:

  ```text
  finite_work
  repeatable_run
  habit_window
  living_checklist_run
  finite_checklist_run
  ```

  `finite_work` serves one finite focus unit, including an undecomposed
  `atomic_task` or `project`, an independently focusable child reached through
  project or collection descent, a released recurring-obligation occurrence,
  an eligible preparation Brick, or an actionable Brick reached through
  Dependency resolution. `repeatable_run` serves one execution of a standing
  identity that may later return. `habit_window` serves one applicable
  opportunity of a standing habit without creating overdue task backlog. The
  two checklist variants present their owning checklist and entries, but
  finishing a `living_checklist_run` never retires its standing owner, while
  completion of a `finite_checklist_run` may finish its finite owner.

  These variants may reuse `Work:` composition or other shared visual
  fragments, but they never collapse into one union-shaped payload. Their
  accept, skip, run-completion, and terminal transitions remain independently
  typed. Review of a decomposed project after its children finish is a review
  opportunity rather than execution; an active `scheduled_commitment` remains
  the hard-precedence result defined by FOC-030 rather than a sixth
  ordinary-lottery execution variant.

## Hierarchical selection

- **FOC-010 [core] — Local hierarchy.** Selection begins among root attention
  subjects, then descends through composition using locally normalized draws
  until reaching a concrete subject or a Nature-defined boundary.
- **FOC-011 [core] — Structure-owned focus boundary.** A finite Brick without
  child parts may be served itself, including a Brick already classified as
  `project`. After decomposition, a project parent is not an execution
  candidate: selection descends to an eligible child. When every child is
  done, the parent may contribute a typed scope-closure review instead of
  returning as Work. A `collection` descends to an independent child;
  checklist Natures present the parent with its entries; `repeatable`,
  `habit`, and `scheduled_commitment` normally present the Brick itself.
- **FOC-012 [core] — No title heuristics.** Decomposition or descent follows
  resolved Nature capabilities, never the apparent grandeur of a title.
- **FOC-013 [core] — Flat view is projection.** A flat forecast may display
  leaf probabilities but must preserve the hierarchical calculation and never
  redefine it.

## Domain continuity

- **FOC-014 [core] — Active Domain.** The core persists zero or one active
  Domain as a soft focus-continuity reference, not a hard filter.
- **FOC-015 [core] — Hierarchical affinity.** Candidate affinity uses the
  deepest shared Domain ancestry. Exact membership is strongest; related
  branches receive a smaller bonus; unrelated work keeps positive probability.
- **FOC-016 [core] — Multi-membership without multiplication.** For a Brick in
  several Domains, use the strongest applicable affinity; memberships never
  create additive tickets.
- **FOC-017 [core] — Focus changes subject.** Accepting `Focus?` starts focus
  and atomically changes or narrows the active Domain to the most specific
  applicable descendant membership. Drawing, displaying, completing directly,
  or skipping does not change it.
- **FOC-018 [core] — No switch pre-dialog.** A cross-Domain suggestion uses the
  ordinary `Focus?` screen. Its secondary context shows the proposed and
  current Domains; `yes` performs the atomic transition.
- **FOC-019 [standard] — Explicit Domain command.** The user may deliberately
  change the active Domain without waiting for a draw.

Equal-specificity Domain target selection and the exact ordering of container
descent versus dependency resolution remain `OPEN-FOC-002`.

## Dependencies and waits

- **FOC-020 [core] — Blocked Bricks remain drawable.** Dependency does not
  remove an otherwise admitted Brick from the initial lottery. Drawing it
  redirects attention through its blockers.
- **FOC-021 [core] — N-step resolution.** For a path
  `B0 -> B1 -> ... -> BN`, each Brick is blocked by the next and `BN` is the
  actionable endpoint. The displayed result cites both the endpoint and the
  original drawn Brick.
- **FOC-022 [core] — Branching blockers.** When a Brick has several admitted
  immediate blockers, reuse the focus-forecast weighting function in a local
  replay-deterministic subdraw. Every admitted branch has positive chance.
- **FOC-023 [core] — Truthful provenance.** The draw records the complete
  selected path. Compact UI may show a folded explanation; `?` exposes the
  full chain and unchosen blocker alternatives without another draw.
- **FOC-024 [standard] — Non-Brick endpoint.** If resolution reaches an
  external wait, temporal gate, missing permission, or corrupt dependency,
  `next` returns a typed canonical recovery opportunity only when that
  endpoint is currently reviewable or actionable; it never pretends it found
  ordinary focusable work.
- **FOC-034 [core] — Wait review uses its Brick's subject ticket.** An active
  Wait suppresses the affected Brick's ordinary work-focus opportunity until
  the gate resolves. Before `review_not_before`, the Wait creates no selectable
  opportunity. At or after that threshold, it contributes one review
  opportunity to the affected Brick's existing attention subject under
  `FOC-006..008`; the Wait never receives its own top-level ticket. Its chance
  begins positive and grows through a bounded calibrated age signal, previous
  unresolved reviews, and the affected Brick's ordinary importance and time
  evidence. Crossing the threshold is neither a deadline nor an overdue
  state. Drawing that opportunity renders the canonical Wait review rather
  than `Focus?`.

## Delegated execution

- **FOC-035 [core] — Active delegation suppresses human execution.** An
  active Delegation removes the ordinary human work-focus opportunity for
  exactly its resolved `brick_only` or `whole_scope` coverage. It does not
  remove any covered Brick from the Importance order, erase its signals, or
  create a second delegation list. The same attention subject may still be
  admitted for a typed Delegation review, follow-up, external-effect approval,
  reported-outcome reconciliation, or other non-execution opportunity. A
  dependency outside the delegated coverage remains independently selectable
  when otherwise eligible. Drafting, proposing, or merely approving a
  Delegation notice does not invoke this rule; activation follows the observed
  handoff boundary in `WRK-058`.
- **FOC-036 [core] — Delegation review is not a message.** Internal Delegation
  review and approval of a proposed outbound follow-up are distinct canonical
  opportunity variants because their actions and transitions differ. They use
  the same attention subject under FOC-006..008 and therefore never become
  duplicate top-level tickets. Follow-up policy may prevent the outbound
  variant, but it never suppresses otherwise warranted internal review. An
  active Delegation contributes no internal review before its WRK-120
  `review_not_before`; at or after that instant the review has positive lottery
  weight derived from the covered Brick's importance, elapsed review age,
  unresolved observations, and bounded prior deferrals. It has no hard
  precedence and no due/overdue label. A proposed Delegation instead exposes
  only its pending handoff, cancellation, or effect-approval continuations and
  never masquerades as an active status review.

## Continuation and precedence

- **FOC-025 [core] — Resume before redraw.** A valid pending envelope resumes
  with the same identity and revision. A current focus resumes when the user
  requests focus while it remains active. Before its stale threshold it uses
  the resting screen; at or after that threshold it uses the stale-focus
  check-in under `UX-080`. Both are continuations, not privileged lottery
  entries.
- **FOC-026 [core] — One lottery otherwise.** Every newly selectable
  opportunity kind participates in the same subject-first lottery. No review,
  approval, or question family receives an invisible pre-lottery lane. Every
  opportunity selected by this lottery exposes a visible typed `skip` action:
  it records that this particular opportunity was deferred, applies its
  replay-deterministic cooldown, then invokes the opportunity variant's
  declared outcome and future-pressure policy under `WRK-062`. It never
  fabricates generic completion or a terminal Brick outcome. Continuations,
  useful-empty recovery, and hard precedence are not lottery selections and
  do not acquire a misleading universal skip from this rule.
- **FOC-027 [core] — Explicit failure.** Invalid state that prevents a valid
  forecast yields a typed diagnostic and concrete recovery suggestion, not a
  fake focus opportunity.
- **FOC-028 [core] — Useful empty state.** With no eligible work, `next`
  proposes the most relevant canonical recovery, such as changing Domain,
  reviewing a temporal gate, feeding work, or inspecting dormant standing
  work.
- **FOC-029 [core] — Pristine first start.** When no pending interaction,
  Brick, Raw material, or import candidate exists, `next` returns the
  canonical first-Brick screen instead of the ordinary no-eligible recovery.
  This screen creates nothing by itself; Feed remains an explicit user action.
  A store with historical, blocked, temporal, dormant, delegated, or Raw work
  is not pristine.
- **FOC-030 [core] — Active commitment precedence.** Once a
  `scheduled_commitment` interval begins, an unresolved commitment suspends
  the ordinary weighted draw. `next` returns that commitment until it is
  accepted as current focus, completed, cancelled, or classified as missed.
  This is an explicit temporal precedence rule, not a hidden probability
  multiplier or duplicate ticket. Because this is hard precedence rather than
  a lottery result, it requires truthful commitment-specific outcomes instead
  of the universal lottery skip. Conflicts with an already-current focus or
  another overlapping commitment remain `OPEN-SCH-001`.
- **FOC-031 [core] — Preparation before commitment.** Before the interval
  begins, a scheduled-commitment subject may descend to currently eligible
  preparatory descendants or resolve a hard prerequisite through the ordinary
  hierarchical and Dependency mechanisms. Relative `not_before` constraints
  determine when preparation first becomes selectable; `best_before` and
  `deadline` contribute their ordinary meanings. Preparation never gives the
  commitment extra root tickets.
- **FOC-032 [core] — Current focus rests outside the draw.** Accepting a Focus
  opportunity does not invoke `next` again. The current Brick becomes an
  explicit continuation and is excluded from the ordinary eligible-draw count
  until focus ends. Other selectable opportunities remain eligible but are
  not surfaced over the resting or stale-focus continuation. Staleness changes
  the continuation grammar under `UX-080`; it never admits a second
  `focus_review` ticket. An in-progress Brick that is no longer current may
  independently contribute a typed WIP-review opportunity.
- **FOC-033 [core] — Transactional browsing from focus.** `/next` from a
  current-focus screen draws and presents another proposal without first
  clearing or pausing the current focus. Escape, uncertainty, or rejecting the
  proposal leaves the current focus unchanged. Accepting another Brick
  atomically leaves the previous Brick WIP, starts the accepted Brick when
  needed, and moves current focus to it. Merely browsing never destroys the
  user's working context.
- **FOC-038 [core] — Non-current WIP review.** A WIP Brick that is not the
  current focus may contribute one typed `wip_review` opportunity to the
  ordinary subject-first lottery. It is a non-execution opportunity on the
  same attention subject, not another Brick, another root ticket, or a stale
  current-focus continuation. Its pressure may increase with WIP age and work
  above the soft limit, but it retains positive-probability competition and
  the ordinary typed-review skip under `FOC-026`. Selecting it never resumes
  work by itself.
- **FOC-039 [core] — Scope closure is a review.** An active finite parent whose
  tracked child Bricks are all `done`, or an active `finite_checklist` with no
  open ListEntry, contributes one typed `scope_closure_review` opportunity to
  the ordinary subject-first lottery. Its typed purpose is `child_parts` or
  `list_entries`; the two payloads remain discriminated. It is attached to the
  existing parent attention subject and never creates a second Brick or root
  ticket. The subject remains excluded from execution and cannot return as
  `finite_work` or `finite_checklist_run` while its scope is empty. Selection
  only asks whether the whole outcome is complete or whether more tracked work
  is needed; it never completes the parent by inference. A newly active child
  or open entry invalidates the pending review. The entry payload reports
  resolved and cancelled counts separately, so cancellation is never
  presented as completion evidence. Archived and superseded child boundaries
  remain governed by `OPEN-TREE-001`.
- **FOC-040 [core] — Lazy review means weighted review.** A lazy human-review
  marker immediately contributes one typed non-execution opportunity to the
  ordinary subject-first lottery with positive, initially low weight. It is
  neither hard precedence nor exclusion from the draw. Age, low confidence,
  relevance, consequence, and later evidence may increase its pressure under
  replay-stable configuration. A break batch contributes one `nature_review`
  per provisionally classified child and one `importance_run_review` for its
  provisional sibling run; accepting three default children therefore adds
  four unresolved reviews. Review-specific skip leaves the underlying marker
  unresolved, applies its own cooldown, and never opens served-work diagnosis.
  Cooldown or a temporal gate may make a review temporarily ineligible without
  removing it from the unresolved footer count in UX-025. Settling or
  invalidating the exact claim removes that opportunity; one review never
  settles another claim by implication.
- **FOC-053 [core] — Archived relevance review remains drawable.** An archived
  Brick is excluded from every execution variant and from the active
  importance projection, but its unresolved `archive_relevance_review` marker
  contributes one typed non-execution opportunity through the same subject
  ticket and lazy weighting rules as FOC-040. The opportunity's initially low
  chance may gain pressure from age or new linked evidence without making the
  archived Brick ordinary Work. `keep archived`, restoration, or supersession
  resolves the marker; typed review skip preserves it with cooldown. After
  `keep archived`, no recurring review is synthesized, though explicit search,
  inspection, restoration, and archive history remain available.
- **FOC-041 [core] — Interaction-family continuity.** Completing an
  ordinary-lottery interaction may establish a transient, replay-recorded
  affinity for its semantic activity family. A successful importance
  comparison therefore increases the chance that a later global draw selects
  another `importance_maintenance` opportunity, with additional ordinary
  locality from subject, parent, and Domain. This is a decaying weighted bonus,
  never a hard filter or duplicate ticket; every unrelated admitted candidate
  retains the positive tail in FOC-003. Repeated family-specific skips reduce
  the affinity and apply their normal cooldowns. The signal is session context,
  not a Brick field, human importance evidence, active Domain, or public score.
  Explicit continuous commands such as `/order` suspend the global draw while
  their bounded flow is active, then leave subsequent draws governed by the
  same recorded affinity and decay.
- **FOC-042 [core] — Provocative importance-validation opportunity.** After
  the ordinary lottery selects the importance-maintenance family, a separate
  replay-recorded branch uses the configured target rate to choose either the
  unresolved `org-sort-tasks` pair or one eligible IMP-015 transitive-only
  validation pair. If no validation candidate exists, the branch falls back
  to ordinary maintenance without fabricating a question. The resulting
  `importance_validation` is a typed, one-comparison, non-execution opportunity
  with ordinary positive-tail, skip, cooldown, and no hard precedence. It uses
  the same proposition grammar as UX-O01 but is never emitted inside explicit
  `/order`. Its contextual help exposes the inferred path and reason for
  validation; the primary question does not label itself provocative or reveal
  the inferred answer. Its skip route follows IMP-037 and UX-102: one local
  alternative at most, then pair-specific cooldown without a durable review
  marker or unresolved-footer count.
- **FOC-043 [core] — Unresolved importance recalibration.** IMP-035 contributes
  one typed `importance_recalibration` opportunity for the smallest affected
  sibling segment. It preserves a complete current order, enters the ordinary
  lottery after a bounded uncertainty cooldown, and gains pressure from low
  confidence, age, repeated contradiction, and forecast consequence. It is a
  non-execution opportunity with ordinary skip and no hard precedence. One
  segment contributes one opportunity regardless of the number of conflicting
  edges, preventing duplicate lottery tickets for the same unresolved cycle.
- **FOC-044 [core] — Easier-work recovery uses a bounded shortlist.** Choosing
  `easier work` after `tired` does not invoke the global lottery. The core
  replay-deterministically samples up to three other currently executable Work
  opportunities, preferring the served Brick's effective Domain and existing
  lower-effort evidence while preserving positive probability for missing
  effort. Hard-gated endpoints are excluded and no candidate is a default.
  Selecting one records WRK-069 atomically and presents that exact candidate
  through the ordinary `Work:`/`Focus?` envelope without a second draw.
  The selection is strong, decaying contextual evidence for similar
  low-energy recovery, not a new Brick axis or a rewrite of importance.
  If no other executable Work opportunity exists, UX-S08 is not rendered; the
  exact useful recovery remains an explicit `OPEN-SKIP-001` edge case.
- **FOC-045 [core] — Positive subject change infers the branch left behind.**
  UX-S09 offers target Domain paths that contain currently executable Work and
  do not contain the served Brick's current effective Domain path. Selecting
  one scopes exactly one replacement draw to that target, then presents the
  selected Work through ordinary focus consent. The current-side child below
  the source/target paths' deepest shared ancestor receives one bounded
  replay-deterministic fatigue penalty; the target receives a bounded affinity
  bonus. With different top-level roots, the whole source root is the
  current-side branch. Both signals decay with time and intervening accepted
  work, and all Domains retain positive probability after the one scoped draw.
  Their calibrated magnitude and decay may differ for originating `tired` and
  `bored` evidence without changing this semantic mechanism. Neither signal
  changes importance or active Domain. Exact no-target and multi-membership
  recovery remains under `OPEN-SKIP-001` and `OPEN-DOM-001`.
- **FOC-046 [core] — Organize and review targets an interaction family.**
  UX-S09 `organize and review` is not a Domain, Brick, persistent mode, or new
  forecast axis. It scopes one draw to an eligible organization-maintenance
  opportunity outside the served Brick's most-specific effective source path,
  records fatigue on that source path and affinity to the interaction family,
  and then lets FOC-041 continuity favor subsequent related opportunities with
  ordinary decay and positive tails. This one-path rule does not guess among
  equal multi-memberships. The versioned 1.0 family includes Raw triage,
  Nature review, importance maintenance and recalibration, Domain/taxonomy
  review, duplicate reconciliation, WIP review, and scope-closure review.
  Membership is by typed opportunity variant, never title or Nature. Hard
  precedence is unchanged. Exact payloads and actions for still-unsettled
  family members remain under `OPEN-FOC-001`; no-eligible recovery remains
  under `OPEN-SKIP-001`.
- **FOC-047 [core] — Less-important subject change is scoped, not fatigued.**
  Choosing a target Domain from a `less important` reaction performs exactly
  one replacement draw among currently executable Work in that target and
  presents it through ordinary Focus consent. It records no source-Domain
  fatigue or target-affinity signal merely from the symptom: accepting the
  proposed Focus changes active Domain under FOC-017, after which ordinary
  continuity applies. Rejecting or leaving the proposal changes no active
  Domain. All other Domains retain positive probability after the scoped draw;
  no-target and ambiguous multi-membership recovery remain explicit open
  boundaries.
- **FOC-048 [core] — Focus uncertainty is consent assistance.** Question mark
  on an ordinary Focus proposal asks one question per screen and follows this
  bounded tree for the proposed Brick:

  ```text
  Q0. Do you understand what this Brick asks you to do?
  ├─ yes → Q2
  └─ no or unknown
     Q1. Would reviewing its existing context and linked material be enough?
     ├─ yes → inspect through /show, then ask whether it is now enough
     │  ├─ yes → Q2
     │  └─ no  → confirm vague through UX-S34
     └─ no  → confirm vague through UX-S34

  Q2. Do you understand why Little Ant selected this Brick?
  ├─ yes → Q4
  └─ no or unknown
     Q3. Would reviewing the selection evidence help you decide?
     ├─ yes → inspect the recorded forecast explanation, then continue to Q4
     └─ no  → Q4

  Q4. Start focusing this Brick?
  ├─ yes → accept the original Focus proposal
  └─ no or unknown → open UX-S33 symptom discovery
  ```

  Q0, Q2, and Q4 permit uncertainty to reach the same recovery as `no`
  because neither supplies the confident understanding or consent required by
  the `yes` branch. This navigation is not a negative answer or skip. Q1 and
  Q3 use alternate probes under UX-017; repeated uncertainty remains pending.
- **FOC-049 [core] — Forecast explanation is the recorded draw.** The Focus
  aid's explanation reads the immutable selection record from FOC-002 and
  FOC-005: the proposed Brick, strongest signal, bounded additional signals,
  admitted-set size, final subject and local opportunity choices, Domain or
  blocker path when applicable, and replay identity. It never redraws,
  recomputes against later state, invents a causal story, or exposes a hidden
  score as human importance. The read-only screen continues to Q4 or returns
  to Q2. Its nested explanation-specific uncertainty tree remains explicitly
  under `OPEN-UX-004` until reviewed.
- **FOC-050 [core] — Assistance preserves the prior attention state.** Every
  Q0..Q4 answer, `/show` view, forecast explanation, symptom question, and
  unaccepted reaction preserves the proposal, random cursor, active Domain,
  WIP set, and any previous current focus. Only Q4 `yes` accepts the original
  proposal and performs the ordinary FOC-017 focus or Domain transition. A
  final accepted symptom reaction defers only the proposed Brick under its
  canonical semantics; it never pauses, closes, or replaces an unrelated
  current focus. Confirming `vague` alone still records nothing until its
  reaction is accepted under WRK-047.
- **FOC-051 [core] — Inbox Raw creates triage opportunities.** Each active Raw
  without an accepted disposition may contribute one typed `raw_triage`
  opportunity to the ordinary lottery. Raw has no importance position and its
  selection never pretends to be execution Work. Its weight may use age,
  prior deferrals, recent-Feed locality, duplicate evidence, and the current
  organization-maintenance continuity established by FOC-046. Every admitted
  Raw retains positive probability, and selecting one consumes only the
  recorded draw required to present its triage interaction. Its visible typed
  skip defers only that Raw, applies the review cooldown and pressure policy,
  and leaves its disposition unresolved in the Inbox.
- **FOC-052 [standard] — Assisted batching does not multiply tickets.** An
  accepted Skill or powered-up batch proposal may include bounded recent Raws
  after one `raw_triage` opportunity is selected, but merely appearing in a
  semantic cluster gives no Raw additional top-level lottery ticket. The
  interaction enumerates the affected identities, and rejection returns to
  the originally selected Raw's dumb triage without resolving its neighbors.

## Forecast inputs

The closed weighting function may use importance path and confidence, impact,
effort, dates, Domain and Place context, mode, Nature, current WIP, phase,
dependencies, waits, skip evidence, recurrence, habits, delegation,
reviews, and aging. Optional missing axes are neutral. There is no universal
phase multiplier and no hidden public score.

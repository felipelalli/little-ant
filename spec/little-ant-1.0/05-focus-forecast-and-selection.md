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
  tail, aging, cooldowns, Domain affinity strength, signal bonuses, and caps
  use versioned factory defaults and replay-safe configuration.
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

  `finite_work` serves one finite focus unit, including an `atomic_task`, an
  independently focusable child reached through project or collection
  descent, a released recurring-obligation occurrence, an eligible
  preparation Brick, or an actionable Brick reached through Dependency
  resolution. `repeatable_run` serves one execution of a standing identity
  that may later return. `habit_window` serves one applicable opportunity of
  a standing habit without creating overdue task backlog. The two checklist
  variants present their owning checklist and entries, but finishing a
  `living_checklist_run` never retires its standing owner, while completion of
  a `finite_checklist_run` may finish its finite owner.

  These variants may reuse `Work:` composition or other shared visual
  fragments, but they never collapse into one union-shaped payload. Their
  accept, skip, run-completion, and terminal transitions remain independently
  typed. Project scope review is a review opportunity rather than execution;
  an active `scheduled_commitment` remains the hard-precedence result defined
  by FOC-030 rather than a sixth ordinary-lottery execution variant.

## Hierarchical selection

- **FOC-010 [core] — Local hierarchy.** Selection begins among root attention
  subjects, then descends through composition using locally normalized draws
  until reaching a concrete subject or a Nature-defined boundary.
- **FOC-011 [core] — Nature-owned focus unit.** `project` may descend to a
  child or offer decomposition/review; `collection` descends to an independent
  child; checklist Natures present the parent with its entries; `atomic_task`,
  `repeatable`, `habit`, and `scheduled_commitment` normally present the Brick
  itself.
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
  variant, but it never suppresses otherwise warranted internal review.

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

## Forecast inputs

The closed weighting function may use importance path and confidence, impact,
effort, dates, Domain and Place context, mode, Nature, current WIP, phase,
dependencies, waits, skip evidence, recurrence, habits, delegation,
reviews, and aging. Optional missing axes are neutral. There is no universal
phase multiplier and no hidden public score.

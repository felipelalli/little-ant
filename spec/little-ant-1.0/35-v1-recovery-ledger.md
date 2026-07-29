# 35. Little Ant 1.0 recovery ledger

This chapter records decisions confirmed during the regression audit and
structured recovery of Little Ant 1.0. It exists so that a context compaction
or later consolidation cannot silently replace a nuanced decision with an
inference.

## 35.1 Method and authority

- Each confirmed decision is recorded immediately and committed as a small,
  reviewable change.
- Confirmed recovery entries override conflicting earlier design wording until
  the correction is deliberately propagated.
- Open implications remain explicitly open; they are not filled in during
  consolidation.
- The v0 implementation, tests, history, and current operator skill are
  evidence of existing capabilities, not authority for 1.0 terminology or
  behavior.
- The rewritten Allium garden, generated tests, failed v1 implementation, and
  gap-analysis branch are audit evidence, not automatic product authority.
- Allium is changed only after the surrounding behavioral slice has been
  reviewed coherently.

## 35.2 Canonical vocabulary: remove `priority`

Confirmed on 2026-07-28:

- `priority` is not a canonical Little Ant 1.0 term.
- It must not name a new core concept, command, projection, field, event,
  Allium declaration, or normative documentation concept.
- It may remain only when quoting v0 history or preserving the literal
  vocabulary of an external source.
- Natural language such as “prioritize this” is interpreted by the operator.
  If context does not distinguish importance from immediate focus, the
  operator asks instead of passing an ambiguous alias into the core.
- The persistent human judgment is currently called the **importance order**.
- The dynamic derived view is currently called the **focus forecast**.
- One outcome drawn from that view is currently called a **next suggestion**.

The three replacement names remain working terms until their complete
semantics and command grammar are reviewed. Removal of `priority` itself is
settled.

Propagation through older Markdown, Allium, generated tests, README, and the
operator skill is deliberately deferred until the importance/forecast slice is
coherent. Until then, this entry overrides their legacy vocabulary.

## 35.3 Probabilistic, replay-deterministic `next`

Confirmed on 2026-07-28:

- The focus forecast is a derived probability distribution, not a second
  persisted human order.
- `next` uses a weighted pseudo-random draw rather than always selecting the
  candidate with the greatest derived score.
- The stochastic choice must be deterministic under replay: the same
  authoritative state, configuration revision, candidate set, and recorded
  random evidence produce the same result.
- A useful long tail is intentional. Low-scoring or unusual eligible work
  should retain some opportunity to surface instead of being permanently
  hidden by the head of the distribution.
- A Brick excluded by a hard eligibility rule has probability zero in the
  initial attention draw. Being blocked by another Brick is not, by itself,
  such an exclusion.
- Every Brick admitted to that initial draw has probability strictly greater
  than zero. Weight transformation, normalization, and tail controls must not
  turn a still-admitted Brick into an implicit exclusion.
- Viewing the forecast must not consume random evidence or change a future
  draw.
- A draw changes neither the importance order nor the underlying judgments.

The analogy with an LLM is motivational, not mathematical. LLM sampling is
normally based on transformed logits rather than a guaranteed normal
distribution. Little Ant therefore does not yet mandate a normal curve,
softmax, temperature, top-p, or another exact formula.

Calibration direction:

- tunable selection parameters should have validated factory defaults;
- users may revise calibratable parameters over time;
- forecasts and draws must identify the configuration revision that produced
  them;
- tests and simulations may sweep parameter sets and report calibration
  metrics;
- calibration must never silently alter hard eligibility rules, historical
  evidence, or semantic invariants.

Current proposal, not yet confirmed:

- expose the calibratable profile in a human-editable YAML file;
- define one or more explicit tail controls analogous to sampling temperature
  or probability-mass cutoffs.

Open implications:

- which conditions are hard exclusions before weighting;
- the exact scoring, normalization, tail, and aging functions;
- whether positive probability also needs a bounded service guarantee;
- configuration schema, validation ranges, revision storage, and migration;
- which calibration changes require explicit confirmation.

## 35.4 Contextual `?` and Nature-aware decomposition

Confirmed on 2026-07-28:

- A minimal `next` prompt does not need a separate `open project` action.
- `?` is the single progressive-disclosure entry point for more information
  about the pending suggestion. It may reveal the suggestion explanation,
  ancestry, relevant project or collection context, children, blockers,
  supporting evidence, and navigation actions.
- Requesting that context preserves the same pending suggestion. It consumes
  no random evidence, records no answer or skip, and performs no domain
  mutation.
- “Full context” means that all relevant canonical context remains reachable
  through bounded, paginated navigation. It does not mean dumping an entire
  sparse projection or event history onto the main prompt.
- A container selected during hierarchical sampling is resolved according to
  its `BrickNature`. A project-like finite outcome normally directs focus to
  an eligible descendant rather than being presented as vague executable
  work.
- If a project-like Brick has no suitable descendant, the system may propose
  reviewing or decomposing it. That is a distinct useful action, not an
  automatic child creation.
- Decomposition is never a universal reaction to a high-level title. It is
  available only when the Brick's resolved Nature has finite
  descendant-scope or another explicit decomposition capability.
- The operator skill and powered-up REPL may classify the input's likely
  Nature and propose a concrete Nature or template. The dumb REPL uses the
  same core-provided candidates and asks a bounded deterministic question when
  the choice materially changes semantics. The core validates and records the
  chosen Nature; it does not infer a Nature from title keywords.

Open implications:

- whether a project-like Brick may be directly focusable when it also has
  active descendants;
- the exact hierarchical allocation of probability between a container and
  its descendants;
- when uncertain Nature classification must be resolved rather than safely
  retaining the generic `standard` Nature.

## 35.5 Resolve a drawn blocked Brick through N dependency steps

Confirmed on 2026-07-28:

- `next` distinguishes the initial attention draw from the final actionable
  result.
- Being blocked by another Brick does not remove an otherwise admitted active
  Brick from the initial draw.
- Let `B0` be the drawn Brick. Dependency resolution produces a recorded path:

  ```text
  B0 -> B1 -> ... -> BN
  ```

  For every step `i < N`, `Bi` is blocked by `B(i+1)`. `BN` is the actionable
  Brick returned as `Next`. An unblocked draw has `N = 0`.
- Resolution follows as many dependency steps as necessary; it is not limited
  to one redirect.
- When the current path node has several unresolved immediate Brick blockers,
  resolution performs a replay-deterministic weighted subdraw among the
  admitted blocker branches.
- That subdraw reuses the focus-forecast weighting function, evaluated and
  normalized locally over those admitted branches. Dependency resolution does
  not introduce a second blocker-specific ranking policy.
- Every blocker branch admitted to that subdraw has probability strictly
  greater than zero. The selected edge and its random evidence are recorded,
  and resolution continues from the chosen blocker.
- Unchosen blockers remain unresolved relationships. The compact `Why` path
  shows the selected branch, while `?` exposes the other immediate blockers
  considered at each branching step.
- The initial random outcome and complete resolution path are replay-safe
  provenance. A renderer may therefore truthfully say which Brick was drawn,
  which dependency steps were followed, and why the endpoint became the
  suggestion.
- Blocker pressure is derived from this resolution model rather than stored as
  a separate mutable field. An actionable Brick's effective chance may include
  the attention mass of drawn Bricks whose resolution paths end at it.
- A blocked Brick is never presented as though it were itself executable.
- Dependency cycles remain invalid, so a valid resolution path cannot loop.

The compact rendering has three semantic regions: the actionable endpoint, its
containing Brick when relevant, and the explanation. With an illustrative
two-edge path:

```text
Next: #cccc "Specify importance-order maintenance"
Within: #zzzz "Recover Little Ant v1"
Why:
  drawn       #aaaa "Release Little Ant v1"
  blocked by  #bbbb "Implement importance-order maintenance"
  blocked by  #cccc "Specify importance-order maintenance"
```

Every cited Brick uses the canonical compact label:

```text
#shortid "Canonical English title"
```

A containing project, collection, or other Brick follows the same rule.
Renderer-owned markers may later occupy a defined optional marker slot, but
the short ID and quoted canonical English title remain present. The label is
presentation, not identity authority; canonical state and typed annotations
continue to use opaque immutable IDs.

`?` exposes the full resolution path and dependency context without consuming
another draw or changing the pending suggestion. Exact one-line versus
multiline rendering, folding of unusually long paths, and cross-parent
`Within` rendering remain open.

Open implications:

- how nested subdraws derive and record replay evidence from the random stream;
- how a branching dependency DAG contributes effective probability without
  double-counting;
- what result is produced when the path reaches an external wait, temporal
  gate, unavailable permission, or another condition with no actionable Brick
  endpoint;
- how inspection and `next` fail if imported or corrupted state violates the
  acyclic dependency invariant;
- how dependency resolution composes with Nature-driven descent through a
  project or collection;
- whether and where attenuation or caps are needed after practical
  calibration.

## 35.6 Correct the phase and emoji record before renaming anything

Confirmed on 2026-07-28:

- The former seed glyph `🌱` had already been abandoned. It is not a Little
  Ant 1.0 phase-marker candidate.
- The canonical optional phase set remains
  `idea | spec | exec | validation`.
- `spec` means planning or specification. It remains the one canonical core
  value; `design` is neither a second phase nor an alias.
- `📐` is the canonical renderer marker for `spec`.
- Keep phase, status, focus, WIP, blocking, and confidence visually distinct
  rather than overloading one emoji with several independent axes.

## 35.7 Keep recovery discovery at the model boundary

Confirmed on 2026-07-28:

- Subsequent recovery questions should prioritize decisions that change the
  core domain model, public UI mental model, or authority boundary between
  them.
- Low-risk mechanical consequences should be derived from confirmed
  principles, documented, and validated later rather than presented as
  interview questions.
- Calibration details remain explicit open issues, but should return to the
  discussion only when different answers would materially change observable
  behavior.

## 35.8 Define `next` as a closed family of concrete opportunities

Confirmed on 2026-07-28:

- `next` returns one member of a versioned closed set of core-defined
  focus-opportunity variants.
- The examples previously discussed were illustrative, not an exhaustive list.
  The complete 1.0 catalog remains a macro/core/UI decision.
- `interaction` is not a public generic command, and neither a Nature,
  template, Pack, powered-up model, operator, nor UIAdapter may invent a new
  fundamental variant or canonical action.
- A surface presents the concrete action or domain question instead of
  foregrounding an abstract proposal-kind label.
- For importance comparison, the primary prompt is the proposition
  `Is #A "…" more important than #B "…"?`, with `yes`, `no`, `skip`, and
  `?` interpreted against that displayed direction.
- Provenance remains typed and inspectable through `?`. A renderer may show a
  restrained reason summary in an optional status region, but a prominent
  `Why` block is not required for a self-explanatory question.
- The REPL is the reference interaction design. Web, mobile, UIAdapters, and
  the operator skill preserve its domain prompts, action semantics,
  information hierarchy, and progressive disclosure while adapting controls
  and layout to the channel.
- Future elicitation presents concrete REPL mini-simulations for macro
  alternatives so their user-visible consequences can be evaluated directly.

## 35.9 Preserve one response language across focus opportunities

Confirmed on 2026-07-28:

- A Brick focus suggestion uses this reference shape:

  ```text
  #c12345 "Write the migration specification"

  Focus?

  [y]es · [d]one · [s]kip · [?]

  ----------------------------------------
  ↳ #a12345 "Recover Little Ant v1"
  🏷️ Personal > Little Ant
  ```

- Parentage, Domain, warnings, and compact status are secondary context below
  the focal proposition rather than fields inside it.

- Response letters retain stable meanings across screens and channels whenever
  applicable. `y` confirms the displayed proposition, `n` rejects it, `d`
  completes the cited Brick, `s` skips without answering, and `?` requests
  information or help without answering.
- An inapplicable action is omitted; its letter is not reassigned.
- Approval screens therefore ask a concrete yes/no question instead of
  relabeling `y` and `n` as local `approve` and `decline` verbs.
- The previously illustrated review form is acceptable, subject to this
  stable response grammar.
- The operator skill or powered-up REPL may pre-order through attributed
  low-authority comparison evidence. The core validates the evidence and owns
  provisional binary insertion; applicable human judgment remains stronger.
- AI-assisted provisional placement need not block on confirmation, but must
  remain visible in recap, history, and inspection. Dumb mode, model failure,
  or abstention asks the ordinary human placement question.
- The core never calls a skill. The operator skill and powered-up model adapter
  are alternative judgment providers used by their respective surfaces.

## 35.10 Use one lottery for every newly selectable opportunity kind

Confirmed on 2026-07-28:

- Executable work, questions, reviews, approvals, follow-ups, and every other
  admitted newly selectable variant participate in the same
  replay-deterministic hierarchical weighted lottery.
- Opportunity type alone never creates a fixed precedence lane.
- Urgency, aging, accumulated pressure, and other forecast evidence may change
  weights without turning a kind into a deterministic interrupt.
- Status continues to expose pending counts when another opportunity wins.
- An already pending interaction resumes with the same identity and revision
  before a new draw.
- An active current focus also resumes while genuinely in progress.
- These are continuations, not privileged new candidates.
- A consistency failure that makes a valid forecast or mutation impossible
  stops the draw with an explicit diagnostic. It is not a focus opportunity.
- The earlier working list that placed approvals and overdue follow-ups before
  the ordinary lottery is superseded.

Clarified on 2026-07-29:

- “The same lottery” rejects deterministic precedence by opportunity type. It
  does not require a flat top-level array of every applicable opportunity.

## 35.11 Restore hierarchical forecast selection

Confirmed on 2026-07-29:

- The focus forecast is hierarchical. The flat `ForecastItem` draw currently
  present in the propagated Allium is a specification divergence, not the
  intended 1.0 model.
- Every newly selectable opportunity belongs to one canonical attention
  subject.
- Each admitted subject participates once in its applicable attention scope,
  regardless of the number of executable actions, questions, reviews, or
  other opportunity variants currently attached to it.
- After selecting a subject, the core makes a replay-deterministic weighted
  local subdraw among that subject's admitted opportunity variants.
- Every admitted variant in that local subdraw retains strictly positive
  probability. Opportunity type creates no fixed lane or automatic winner.
- A project-like container introduces recursive, Nature-aware selection over
  its admitted descendant scope. Descendants and their opportunities are not
  flattened into unrelated top-level tickets.
- A flattened forecast may exist as a read-only presentation derived from the
  hierarchical probabilities. It cannot define or alter draw semantics.
- This restoration is consistent with sibling-scoped human importance but is
  a separate rule: human comparisons establish strict order among siblings,
  while hierarchical forecast sampling determines where attention is offered.

Open implications:

- the exact subject catalog and applicable scope for non-Brick opportunities;
- how several opportunity signals contribute to one subject weight without
  ticket multiplication;
- the probability allocation between a selected container and its descendant
  scopes;
- the order in which container descent, dependency-path resolution, and the
  final opportunity subdraw consume replay evidence;
- the new Allium obligations and high-level simulations required to prevent a
  future flattening regression.

## 35.12 Aggregate opportunity signals with a bounded bonus

Confirmed on 2026-07-29:

- A subject still receives one participation in its applicable attention
  scope.
- Its strongest applicable opportunity signal anchors the subject weight.
- Additional independent signals may add a bounded bonus with diminishing
  returns.
- Additional proposal records never act as additional top-level tickets.
- Duplicating, splitting, or rewording one underlying concern must not
  increase the result.
- The exact curve, cap, correlated-signal treatment, numeric representation,
  and YAML parameters remain open calibration mechanics.

## 35.13 Replace exclusive string context with multi-membership classification

Confirmed on 2026-07-29:

- The future organizational-classification model is hierarchical.
- One Brick may belong to several branches simultaneously.
- Classification is orthogonal to the Brick parent-child composition tree,
  human importance, Place, mode, waits, and other execution conditions.
- The current propagated `context: String?` plus nearest-ancestor inheritance
  is insufficient to express the confirmed model.
- `Domain` is accepted as the current working product name. It may receive one
  final naming review before Allium propagation, but `Area`, `Folder`, and
  generic `context` are not current choices.
- The v1 core must support deterministic recursive filtering and aggregation
  capable of answering requests equivalent to selecting within `Orbit`,
  selecting within `Housekeeping`, and counting Bricks within `R&D`.

Working classification boundary, not yet fully confirmed:

- The core owns classification identities, hierarchy, membership, candidate
  retrieval, validation, queries, and provenance.
- The skill and powered-up adapter may rank bounded existing candidates and
  submit attributed multi-membership proposals.
- Dumb mode uses deterministic evidence such as an explicit current branch,
  parent membership, or configured import route; it never guesses from a
  title through hidden domain keywords.
- Missing or uncertain classification does not block `feed`.
- Creation of a new branch, destructive merge, or removal of an authoritative
  human membership always requires explicit confirmation.
- Whether an assisted adapter may attach existing memberships provisionally
  without a blocking confirmation remains open.

## 35.14 Make feeding the sole ingress vocabulary

Confirmed on 2026-07-29:

- `feed` and `feeding` replace the previous product-ingress term everywhere in
  1.0.
- Commands, prompts, responses, README examples, Markdown specification,
  Allium entity and trigger names, implementation identifiers, tests, and
  generated artifacts must converge on this vocabulary.
- The core provides no compatibility alias.
- A mechanical replacement is not always correct. Snapshot, observation,
  refresh, import, and reconciliation operations use their own precise names
  when they are not the act of feeding input into Little Ant.
- This checkpoint records the cross-artifact requirement; Allium, generated
  tests, and implementation are changed only during their deliberate
  propagation stages.

## 35.15 Require one Nature from Brick birth

Confirmed concept on 2026-07-29:

- Nature is a required core concept, not an optional operator tag.
- `Nature` is the preferred canonical term.
- Every Brick has exactly one Nature from birth.
- A human may select it explicitly, a template may imply it, and the skill or
  powered-up adapter may submit an attributed judgment.
- If the user skips and no accepted route implies another Nature, the core
  uses `standard`.
- Nature governs focus unit, decomposition, entries, standing lifetime,
  repetition, phase applicability, effort applicability, and the other
  generic mechanics previously assigned to the obsolete field.
- Domain templates such as grocery lists remain recipes that select a generic
  Nature and defaults; they do not become hard-coded Natures.

Naming confirmed on 2026-07-29:

- `BrickNature` is the canonical entity and `nature` is the canonical Brick
  field.
- No parallel behavioral-classification entity or field remains.
- The propagated Allium, generated tests, README, skill, and implementation
  must be reconciled to this name during their deliberate propagation stages.

## 35.16 Preserve Domain continuity in `next`

Confirmed on 2026-07-29:

- Recently accepted focus creates cognitive continuity pressure for its
  applicable Domain.
- Subjects sharing that Domain receive a bounded soft forecast bonus.
- A displayed, rejected, or skipped suggestion does not itself switch the
  continuity Domain.
- An explicit user request may switch Domain.
- Multiple shared Domain memberships contribute evidence to one subject
  weight; they never create multiple subject tickets.
- Unrelated eligible work retains positive probability unless the user has
  explicitly requested a future hard Domain filter.
- Domain continuity affects the focus forecast, never human importance order.

Open implications:

- the exact active-Domain event and projection schema, lifetime, and decay;
- choosing an active Domain when the accepted Brick belongs to several;
- command grammar for an explicit switch and any hard filter;
- how generic recurring time windows and Place evidence can make standing
  grocery work timely without a grocery-specific core branch.

## 35.17 Keep Domain transitions inside `Focus?`

Confirmed on 2026-07-29:

- The active Domain is explicit persisted focus-continuity state. It remains a
  soft forecast preference rather than an implicit hard filter.
- A cross-Domain draw does not open a separate `Switch Domain?` prompt. The
  ordinary focus suggestion visibly shows the current Domain, candidate
  Domain, and prospective transition.
- `y` atomically starts focus and changes the active Domain. No second
  confirmation follows.
- `d` directly completes the served Brick without changing the active Domain.
- `s` records the ordinary served-work skip and cooldown, preserves the active
  Domain, and returns to another global weighted draw.
- `?` exposes the Domain transition and relevant forecast evidence without
  answering.
- `n` is not offered on `Focus?`, because it would ambiguously duplicate the
  explicit skip action. Stable letters keep the same meaning, but inapplicable
  actions are omitted.
- Domain continuity follows the hierarchy. For active Domain `A` and candidate
  Domain `C`, the default structural affinity is
  `depth(LCA(A,C)) / max(depth(A), depth(C))`: exact membership is strongest,
  shared nearby ancestry is weaker, and unrelated top-level branches receive
  no continuity bonus.
- A Brick with several memberships uses the strongest applicable affinity.
  Memberships never add tickets or independent continuity bonuses.
- Affinity scales one bounded Domain signal inside the previously confirmed
  strongest-signal-plus-bonus forecast model. Intensity, cap, and temporal
  decay remain calibration parameters, and unrelated eligible work retains
  positive probability.

Open implications:

- active-Domain event and projection names, lifetime, decay, and clearing;
- selecting the displayed target Domain for equal-specificity or unrelated
  memberships;
- exact compact terminal rendering and expanded `?` explanation;
- explicit Domain-switch command and whether a separate hard filter exists.

## 35.18 Narrow accepted focus into the descendant Domain

Confirmed on 2026-07-29:

- When the active Domain is an ancestor of one or more Domains assigned to an
  accepted Brick, focus narrows the active Domain to the most specific
  applicable descendant membership.
- With `Orbit / R&D` active, accepting focus on a Brick in
  `Orbit / R&D / Rock Splitter` changes the active Domain to
  `Orbit / R&D / Rock Splitter`.
- An additional unrelated membership on that Brick, such as
  `Research / Fraud Detection`, does not prevent narrowing through the active
  branch.
- This transition is part of the same atomic focus acceptance already
  confirmed in section 35.17.

Open implications:

- deterministic selection or human interaction when several qualifying
  descendant memberships are equally specific;
- target selection when no candidate membership is an ancestor or descendant
  of the active Domain.

## 35.19 Treat skip as a symptom before proposing a reaction

Confirmed on 2026-07-29:

- A served-work skip reports a symptom; it is not itself a remediation action.
- Pressing `s` opens one bounded screen with several applicable symptoms
  visible together. It is not limited to “this Brick” and `change subject`.
- An action such as changing subject, retreating a Domain, snoozing, adding a
  dependency, or breaking work down may be proposed only on a subsequent
  screen after the symptom is known.
- The selected symptom and any later accepted reaction are recorded
  separately. The symptom alone authorizes no silent remediation.
- The previously discussed correction is restored: `meh` is removed and
  `fear` replaces it in the 1.0 candidate symptom inventory.
- When an accepted later reaction applies the symptom to a Domain branch, that
  branch and its descendants receive a short cooldown followed by a bounded,
  replay-deterministic decaying negative forecast signal. It does not change
  human importance.
- Exact cooldown duration, decay curve, and caps are configurable calibration
  parameters.
- The initial symptom screen and every subsequent finite-choice screen use
  consistent in-word shortcut notation: `[s]kip`, `[c]hange subject`, or
  `e[x]change` when a collision requires a later character. An unrelated
  prefix shortcut is forbidden. `[?] dunno` is an exceptional fallback and
  should be avoided.

Open implications:

- the complete symptom taxonomy, labels, order, applicability, and free-text
  route;
- the reaction catalog and symptom-to-reaction proposal rules;
- Domain-scope selection and whether the active Domain retreats only after a
  second confirmation;
- whether Domain-scoped evidence also adds Brick-specific skip pressure;
- shortcut collision resolution, especially the exceptional fallback versus
  universal contextual help.

## 35.20 Refine skip labels, grouping, and uncertainty help

Confirmed on 2026-07-29:

- `big` is a distinct symptom from `hard`. It describes work that feels too
  large for the current opportunity without asserting an objective duration,
  and its UI label is `bi[g]`.
- `[n]ot important now` replaces timeless or priority-based wording. Reusing
  `n` from another screen is valid because shortcut uniqueness is local to the
  currently displayed finite-choice screen.
- Related symptoms are grouped on the same visual row while remaining
  individually selectable, such as `[v]ague / [h]ard / bi[g]` and
  `[t]ired / [b]ored / [f]ear`.
- `alternatives` is not a symptom. Alternative approaches are possible
  reactions to several symptoms rather than belonging to exactly one.
- A visible bare `[?]` is insufficient. One `?` is labeled as human
  uncertainty about the pending decision, preferably `[?] I don't know`, and
  opens contextual decision assistance without answering.
- Within that assistance screen, another `?` opens Little Ant system help.
  Thus `??` is the effective system-help route.

Open implications:

- `waiting` versus actionable blocking and repeated `done` were resolved in
  section 35.21;
- final full symptom screen, row order, and exact uncertainty label;
- contextual uncertainty-screen actions and exact Little Ant help label.

## 35.21 Separate waiting from blocking and repeat direct completion

Confirmed on 2026-07-29:

- `waiting` and `blocked` are separate served-work symptoms.
- `waiting` means that an external person, event, or condition remains
  unresolved and there is no known directly actionable work now.
- `blocked` means that a representable prerequisite is missing, such as
  another Brick, information, access, or material.
- A Dependency or enabling Brick is a possible later reaction to `blocked`;
  choosing the symptom never creates that relationship silently.
- Their working row is `[w]aiting / bloc[k]ed`.
- `[d]one` remains on the focus screen and is repeated in a separate
  “Already finished?” region on the symptom screen.
- This repeated action records direct completion only. It creates no skip
  symptom, cooldown, or avoidance pressure.

Open implications:

- exact boundary examples where external waiting becomes actionable blocking;
- main/context visual hierarchy was resolved in section 35.22; the exact
  symptom-icon catalog remains open;
- the specific subsequent reactions offered for each symptom.

## 35.22 Separate navigation, semantic reversal, and contextual rendering

Confirmed on 2026-07-29:

- `Escape` cancels an uncommitted screen and restores its prior presentation
  state. It is not semantic undo.
- `Backspace` remains text deletion. `C-z`, `C-y`, and `C-S-z` are not
  repurposed as Little Ant reversal commands.
- `C-_` and `/undo` perform semantic undo; `C-M-_` and `/redo` perform redo.
- Undo preserves append-only history through a typed compensating event.
  It restores the affected interaction with its recorded random evidence and
  never obtains an approximate replacement by drawing again.
- Default undo is scoped to the current interaction. Reversing an action from
  another session, surface, or device requires an explicit event target.
- Redo must still satisfy current preconditions. External compensation remains
  a separately proposed and approved effect.
- The focal panel contains only the subject, concrete question, and answers.
  Parentage, Domain, warnings, provenance, and compact statistics move to a
  visually separate sparse context region.
- Composition and Domain paths run broadest to most specific. Empty rows are
  omitted, one warning slot exposes an additional count, and statistics use
  at most one line marked by the Little Ant mascot `🐜`.
- Product emoji are renderer-owned and have an accessible no-emoji fallback.

Open implications:

- the warning-slot selection and stability policy;
- exact undoable action inventory and compensating-event schema;
- final context-region width, truncation, severity, and statistics fields;
- the exhaustive opportunity catalog and its smaller set of reusable screen
  grammars.

## 35.23 Keep review orchestration visually discreet

Confirmed on 2026-07-29:

- A guided review does not create an additional primary screen grammar or a
  prominent `Review` heading.
- Each current review question uses the same ordinary concrete layout that it
  would use outside a review.
- Review identity and honest progress appear discreetly in the secondary
  context region.
- The progress label may report known facts such as answers accepted in the
  current session, but never invents a fixed denominator for an adaptive flow.

Open implication:

- the exact compact review-context wording and optional renderer marker.

## 35.24 Restore the suggested-default marker

Confirmed on 2026-07-29:

- `*` is part of the canonical Little Ant interaction grammar, not decorative
  operator prose.
- It marks one already-valid action as the suggested default. It is neither a
  separate domain action nor another answer alongside `yes`, `no`, `skip`, or
  `?`.
- At most one visible action may be marked on a pending screen.
- Pressing bare `*` accepts the exact marked action for the displayed
  interaction revision, with the same result as pressing that action's own
  shortcut.
- If the core or an attributed judgment provider has no defensible basis for
  a suggestion, no default marker is shown. A renderer must never invent one
  merely to make the dialog faster.
- The ordinary action label and shortcut remain visible, for example
  `*[y]es` or `*[d]one`; `*` does not replace them.
- REPL, operator skill, and UIAdapters preserve the same marker semantics. A
  stale bare `*` is rejected exactly like any other stale action submission.

Open implications:

- which core derivations, human configuration, operator judgments, or
  powered-up evidence may nominate a suggested action;
- whether destructive or externally visible actions may ever receive a
  default and, if so, under which preview and authority rules;
- how suggestion provenance and confidence appear through the secondary
  context region or `?`;
- exact spacing, accessible rendering, and alternate-channel controls.

The prior four-screen discussion omitted this v0 capability. The final
comparison and confirmation layouts must demonstrate it explicitly.

## 35.25 Separate comparison from confirmation

Confirmed on 2026-07-29:

- “Proposition” is not the final generic user-facing screen grammar.
- The reusable primary grammar set is `focus`, `comparison`, `confirmation`,
  `choice`, and `input`.
- Comparison and confirmation remain separate even when both expose
  `yes`, `no`, `skip`, and `?`.
- Comparison presents two peer subjects and one directional relation. The
  reference importance layout is:

  ```text
  #a12345 "Launch the landing page"

      is more important than

  #b45678 "Interview prospective customers"

  Is that right?

  *[y]es · [n]o · [s]kip
  [?] I don't know

  ----------------------------------------
  ↳ #p12345 "Release the new website"
  🐜 importance insertion · powered-up suggestion
  ```

- `yes` accepts the displayed direction. `no` records the reverse direction
  because sibling importance is a strict total order with no equality answer.
- Confirmation presents one proposed action or effect and any preview needed
  to decide it; it does not imitate the two-subject comparison layout.
- The displayed `*` remains conditional. It may mark another valid action or
  be absent according to section 35.24.
- Guided review remains discreet orchestration over these ordinary grammars;
  it does not become a sixth primary type.

Open implications:

- exact focus, choice, and input reference layouts;
- narrow-terminal folding for long titles and comparison context;
- which confirmation previews permit a suggested default under external
  effect rules.

## 35.26 Restore operational safety and productive empty states

Confirmed on 2026-07-29:

- `--dry-run` is a global contract for every state-changing canonical CLI
  operation, not a command-specific convenience.
- It performs the real operation's parsing, resolution, validation,
  preconditions, and deterministic calculation while appending no event,
  writing no checkpoint, invoking no Pack or external effect, and consuming no
  persistent random draw.
- Precondition, not-found, and ambiguous-reference failures remain stable typed
  errors. Their recovery actions are state-scoped canonical affordances that
  the core can validate, not prose the client must reinterpret.
- A session never ends in unexplained silence. When no ordinary opportunity is
  eligible, Little Ant offers one useful bounded next step derived from the
  actual reason, including an explicit option to end or rest.
- The empty-state guarantee never manufactures a Brick or pretends that
  ineligible work is executable.

Open implications:

- exact error codes, exit codes, response field names, and recovery-action
  limits;
- exact time and revision token needed to reproduce a dry-run preview;
- the closed empty-state reason and proposal catalog.

## 35.27 Restore taxonomy watch without automatic taxonomy mutation

Confirmed on 2026-07-29:

- `other` preserves the user's verbatim skip explanation as attributed
  evidence.
- Repeated evidence produces a derived taxonomy-review opportunity after a
  configurable threshold.
- The core owns deterministic counting, scheduling, and evidence retrieval.
  Human, operator, or powered-up judgment may propose semantic clustering.
- No symptom is added, renamed, or remapped automatically. An accepted
  taxonomy revision is explicit, inspectable, and versioned.
- Taxonomy review joins the ordinary weighted focus lottery rather than
  gaining a fixed lane or interrupting a pending interaction.

Open implication:

- the default threshold, evidence window, decay, review layout, and exact
  taxonomy-revision event.

## 35.28 Move standard structural formats to the Lua Pack

Confirmed on 2026-07-29:

- Tree text, table text, CSV, Org, and self-contained HTML ship in the
  standard Little Ant 1.0 Pack as Lua `ReadOnlyExporter` components.
- The core owns versioned structural projections, stable identities,
  relationships, and semantic validation. It does not hard-code those target
  renderers.
- A static self-contained HTML artifact is an exporter result. A stateful
  interactive HTML client is a `UIAdapter`.
- Community exporters may vary presentation freely but cannot redefine domain
  meaning.

Open implication:

- whether these are five components or format variants of fewer components,
  plus exact format options and fixtures.

## 35.29 Keep the deterministic product English

Confirmed on 2026-07-29:

- CLI, REPL, first-party UIAdapter content, canonical human renderings,
  commands, shortcuts, values, stored data, and Little Ant action or effect
  drafts remain English.
- The operator skill may localize only its surrounding conversation, and only
  when the user explicitly asks or an operator preference selects a language.
- Localization does not change the canonical interaction envelope or persisted
  content.
- The current v0 skill reads operator/deployment preferences from
  `~/.config/little-ant/ANT.md`. The final 1.0 preference-file shape remains a
  deployment design question, not domain semantics.

This replaces the earlier v0 policy that automatically selected a third-party
recipient's language.

## 35.30 Restore contextual later and global grammar inspection

Confirmed on 2026-07-29:

- `[l]ater` is not a universal answer. It is available only when the same
  temporal proposal can be explicitly rescheduled.
- It does not appear on `Focus?` or comparison screens and does not pretend
  that the underlying Brick was skipped.
- Pressing it opens a date choice or input; no deferral is recorded until that
  choice is confirmed, and the result always renders the absolute date.
- The context owns the changed time field. A follow-up deferral changes its
  follow-up time, while a notice deferral snoozes that notice; neither
  silently changes a Brick's `not_before`.
- `la grammar`, `la grammar --screen <screen>`, and `la grammar --json` inspect
  one core-owned versioned global grammar registry.
- InteractionEnvelope remains the sole state-scoped source of actions valid
  for one pending interaction revision.

Open implications:

- exact date presets, date-input grammar, timezone rendering, and which
  temporal opportunity kinds admit `later`;
- final machine-readable grammar schema and version-negotiation fields.

## 35.31 Restore deterministic time advancement

Confirmed on 2026-07-29:

- Every canonical command first advances all due temporal rules against one
  captured `now`.
- Each subject, condition, and revision fires at most once. Repeating a command
  against unchanged state does not append duplicate temporal events.
- The phase may release due opportunities but never invokes a Pack, sends a
  message, approves an effect, or infers a human outcome.
- `la tick` invokes the same phase explicitly for administration, scheduling,
  diagnostics, and tests.
- `la tick --dry-run` previews due changes under the global dry-run contract.
- The REPL may advance time while idle only at safe screen boundaries.

Open implications:

- exact clock-injection and temporal-event schemas, timezone rules, REPL idle
  cadence, and concurrency behavior when time advances beside another writer.

## 35.32 Replace ambiguous unify with explicit merge

Confirmed on 2026-07-29:

- Duplicate suspicion, same/different judgment, feeding reuse, and structural
  merge are four distinct concepts.
- A new feeding candidate reuses or enriches an existing Brick without first
  creating another Brick. Two already-existing Bricks require `merge`.
- Neither `unify` nor `mark as duplicated` survives as a public core command or
  alias.
- Merge names one source and one survivor and requires a typed preview of
  composition, importance position, children, Dependencies, Waits, RawLinks,
  Domains, dates, recurrence, delegation, effects, annotations, evidence, and
  invalid would-be self-relations.
- `--dry-run` exposes the same plan. Unresolved conflicts block confirmation
  rather than being guessed away.
- An accepted merge is atomic. The survivor keeps its ID; the source becomes
  terminal with `merged_into` lineage; immutable historical events remain
  unchanged and auditable.

Open implications:

- exact per-category transfer defaults, interactive conflict resolution,
  receipt schema, and compact rendering;
- placement treatment when source and survivor have different parents or
  sibling importance scopes.

## 35.33 Require an explicit delegation follow-up policy

Confirmed on 2026-07-29:

- Before its initial external notice may be approved, every Delegation declares
  exactly one follow-up policy.
- The policy choices are one scheduled follow-up, a repeating cadence, or
  explicit no follow-up.
- Missing policy is invalid; `none` is an inspectable decision rather than a
  null that might mean forgotten configuration.
- A repeating policy creates due review and approval opportunities. It never
  authorizes automatic message delivery.
- Terminal Delegation outcomes stop future follow-up opportunities.

Open implications:

- final enum names, one-time date grammar, cadence representation, anchoring,
  defaults, and limits;
- how replies, approved sends, declined drafts, and contextual `later`
  recalculate the next occurrence;
- whether delegation scope is a BrickNature capability and its factory
  defaults.

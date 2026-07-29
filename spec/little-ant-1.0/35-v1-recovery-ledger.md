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
  Next:

      #c12345 "Write the migration specification"
      Within: #a12345 "Recover Little Ant v1"

      Focus?

      [y]es · [d]one · [s]kip · [?]
  ```

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
- selecting the displayed target Domain for a multiply classified Brick;
- exact compact terminal rendering and expanded `?` explanation;
- explicit Domain-switch command and whether a separate hard filter exists.

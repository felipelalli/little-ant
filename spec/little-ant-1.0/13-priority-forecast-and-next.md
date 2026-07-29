# 13. The two lists

The user experiences two lists, but only one is a persistent human order.

## 13.1 Priority

`la priority` is the working name for the stable hierarchical commitment tree.
It exposes:

- composition;
- sibling order and global lexicographic order;
- position confidence and reasons;
- blocking without rewriting position.

The final command and projection name remains to be confirmed.

## 13.2 Forecast and next

The selection list is a derived probability distribution, not another stored
order.

`la forecast` is the working name for a read-only projection that exposes:

- initial attention candidates and maintenance proposals;
- current weight or probability;
- relevant dates;
- reasons contributing pressure;
- confidence;
- blockers, derived resolution paths, actionable endpoints, and contextual
  effects where useful.

Forecast must not consume randomness or mutate the result of a future draw.

The forecast is hierarchical rather than one flat candidate array. Every
newly selectable opportunity belongs to one canonical attention subject. An
admitted subject receives one entry in its applicable attention scope,
regardless of how many opportunity variants currently apply to it. After a
subject is selected, a replay-deterministic weighted local subdraw chooses
among its applicable opportunities. Consequently, adding another review or
question about one Brick does not silently give that Brick another ticket in
the surrounding attention draw.

One subject weight is anchored by its strongest applicable opportunity signal.
Additional independent signals may contribute a bounded bonus with diminishing
returns. They are never summed as independent top-level tickets, and merely
splitting one concern into several proposal records must not increase the
weight. The exact bonus curve, independence or correlation treatment, cap,
and configuration schema remain calibration questions.

The core persists one explicit active Domain as the current focus-continuity
reference. It is a soft forecast preference, not a hard filter. Merely drawing,
displaying, completing directly, or skipping a suggestion does not change it.
Accepting `Focus?` for a suggestion whose displayed target Domain differs
atomically starts focus and changes the active Domain. An explicit Domain
command may also change it without requiring a draw.

Domain continuity follows hierarchy rather than exact-label equality. For one
active Domain `A` and one candidate Domain `C`, the default structural affinity
is:

```text
affinity(A, C) =
  depth(lowest_common_ancestor(A, C))
  ──────────────────────────────────
        max(depth(A), depth(C))
```

Unrelated top-level branches have affinity zero. Exact membership has affinity
one; a shared nearby ancestor produces a smaller positive affinity. When a
Brick belongs to several Domains, the subject uses its strongest applicable
affinity and never receives one ticket or an additive bonus per membership.
Affinity scales one bounded Domain-continuity signal inside the ordinary
strongest-signal-plus-bonus model. Bonus intensity, cap, and temporal decay are
calibration parameters; unrelated eligible work always retains positive
probability.

Forecast weighting and accepted-focus transition are related but distinct. If
the active Domain is an ancestor of one or more Domains assigned to the
accepted Brick, focus narrows the active Domain to the most specific applicable
descendant membership. For example, accepting a Brick in
`Orbit / R&D / Rock Splitter` while `Orbit / R&D` is active changes the active
Domain to `Orbit / R&D / Rock Splitter`. The Brick may also belong to an
unrelated branch; that membership does not prevent narrowing through the
current branch. A tie among equally specific descendants, or target selection
without an ancestor-descendant relationship, remains an explicit design
question rather than an inferred rule.

Composition adds another level to the same hierarchy. When the selected
subject is a project-like container, its resolved BrickNature determines
whether selection descends through a locally normalized weighted draw over
admitted children, presents the container itself, or produces an applicable
review or decomposition opportunity. Descendant selection repeats by scope
until it reaches a concrete attention subject or an explicit Nature-defined
boundary. A flat forecast table may be offered as a derived display, but it
must preserve the probabilities produced by this hierarchy and must not define
selection semantics.

`la next`:

- performs one reproducible hierarchical attention selection, recording the
  random evidence consumed at every weighted branch;
- records the draw seed or cursor, drawn Brick, complete dependency-resolution
  path, and actionable endpoint;
- follows `B0 -> B1 -> ... -> BN` when the drawn `B0` is transitively blocked,
  where each Brick is blocked by the next and `BN` is actionable;
- performs a replay-deterministic weighted subdraw whenever a path node has
  several admitted immediate blockers, giving every admitted branch a
  strictly positive chance and recording the selected edge;
- reuses the same focus-forecast weighting function for that branch subdraw,
  evaluated over and normalized within the admitted immediate blockers rather
  than introducing a second blocker-specific ranking policy;
- proposes the endpoint as the next action while explaining the drawn Brick
  and blocker chain;
- does not rewrite the priority tree.

The Brick examples above describe only one variant of the public result.
`next` draws from a versioned, core-defined closed set of focus-opportunity
variants. A result may therefore ask the user to focus on work, answer a
domain question, perform a review, or cross another explicitly defined
decision boundary. `interaction` is not a public catch-all command or an
extension point for inventing new actions. Natures, templates, Packs, the
powered-up REPL, and the operator may supply candidates or evidence only
through variants and canonical actions already supported by the core.

The exact exhaustive 1.0 variant catalog and its grouping remain open. Earlier
examples were illustrative, not an assertion that Brick execution,
importance comparison, blocker review, project decomposition, Raw triage, and
duplicate review were the complete set.

Dependency blocking alone does not exclude an otherwise admitted active Brick
from the initial draw. Every candidate admitted to that draw has a positive
chance. An actionable endpoint's effective chance may therefore include the
attention mass of Bricks whose dependency paths resolve to it; this is derived
rather than stored as a separate pressure field. Aging increases the chance of
neglected candidates. There is no confirmed bounded guarantee that every item
must appear within a fixed number of draws.

An unchosen immediate blocker remains unresolved and may participate in future
draws. The compact explanation shows the selected dependency path; `?` exposes
the alternative blockers considered at every branching step without changing
the recorded path or consuming more randomness.

## 13.3 Inputs to selection

Selection may take into account:

- priority path and confidence;
- phase and phase confidence;
- expected-impact class, evidence maturity, and internal reliability;
- total effort class, derived remaining effort, and applicable confidence;
- dates and overdue state;
- context and mode;
- Domain membership, explicit Domain scope, and recent accepted-focus
  continuity;
- hard or soft Place conditions and current location observations;
- dependencies and waits;
- current focus and WIP review pressure;
- skip cooldown and accumulated skip pressure;
- stale or contradictory judgments;
- Raw review and refresh;
- delegation, approval, and follow-up state;
- BrickNature, standing-work eligibility, recurrence windows, practice
  progress, and unresolved recurring obligations;
- aging;
- other derived proposals.

There is no fixed global phase multiplier. Phase changes what action is useful
and may affect contextual selection, but it does not act as a universal
priority substitute.

## 13.4 Deterministic precedence

Every newly selectable focus-opportunity variant participates in the same
hierarchical weighted lottery. Work, importance questions, reviews,
external-effect approvals, delegation follow-ups, and other admitted variants
do not receive a fixed pre-lottery lane merely because of their type. “The
same lottery” does not mean that all variants are flattened into one
top-level array: attention is first allocated to a subject and then locally
among that subject's applicable variants. Urgency, aging, accumulated
pressure, and other forecast inputs may increase weights at the appropriate
scope. Pending counts remain visible in status even when another opportunity
wins.

Only continuity and validity precede a new draw:

1. an already pending interaction resumes with the same identity and revision;
2. an active current focus resumes when the user asks for the next focus
   decision while that focus is still in progress;
3. a consistency failure that prevents a valid forecast or mutation stops the
   draw and produces an explicit diagnostic.

The first two cases are continuations, not newly privileged candidates. A
consistency failure is not a `NextSuggestion`.

## 13.5 Proposal vocabulary

The pre-recovery inventory currently includes:

```text
priority_probe
impact_probe
effort_probe
brick_review
review_parent
review_wip
phase_review
practice_review
review_raw
refresh_raw
stale_focus
stale_comparison
scope_review
source_reconciliation
delegation_followup
effect_approval
duplicate_review
place_batch
```

This is discovery evidence, not yet the exhaustive or canonical
`NextSuggestion` variant catalog. Some names still contain vocabulary already
rejected by the recovery ledger and must not be copied into the 1.0 core
unchanged. These are maintenance or decision opportunities, not meta-Bricks.
Their relative weights and the minimum domain state required by atomic
multi-step operations remain partly open. Every guided proposal follows the
shared resume protocol in
[Resumable interactions and honest progress](31-resumable-interactions-and-honest-progress.md);
interruption never creates a continuation Brick.

The forecast may also surface a proposal to plan real impact-validation work
when the expected value of information is high. Its exact canonical proposal
name remains open. The proposal is not itself a Brick and must not
automatically create a questionnaire, experiment, POC, or MVP.

## 13.6 Concrete question rendering

A decision suggestion presents the actual domain question as the primary UI.
It does not headline an abstract operation such as `Compare importance` or
require a prominent `Why` block when the question explains itself.

The confirmed comparison shape is:

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

This preserves the directional yes/no semantics: `yes` confirms the displayed
relation, while `no` records the reverse relation because the sibling order is
strict and has no equality answer. The shown `*` is illustrative: it appears
beside `y`, beside another valid action, or not at all according to the
suggested-default rules. Provenance remains present in the structured result
and available through `?`; a restrained summary may appear in the secondary
context region without becoming a prominent `Why` block.

Comparison is a distinct screen grammar because it presents two peer subjects
and one directional relationship. Confirmation presents one proposed action
or external effect and asks whether to apply it. It does not reuse the
two-subject comparison arrangement merely because both grammars may expose
`yes`, `no`, `skip`, and `?`.

The confirmed focus shape is:

```text
#c12345 "Write the migration specification"

Focus?

[y]es · [d]one · [s]kip · [?]

----------------------------------------
↳ #a12345 "Recover Little Ant v1"
🏷️ Personal > Little Ant
```

The prompt preserves the stable response language: `y` confirms the displayed
question, `d` records that the served Brick is already complete, `s` skips the
opportunity, and `?` opens contextual information without answering. Parentage,
Domain, warnings, and compact status are secondary context rather than part of
the focal question.

A cross-Domain result remains the same focus interaction. It does not introduce
a preliminary `Switch Domain?` confirmation:

```text
#h12345 "Buy groceries"

Focus?

[y]es · [d]one · [s]kip · [?]

----------------------------------------
🏷️ Personal > Housekeeping
   from Orbit > R&D > Rock Splitter
```

Here `y` starts focus and changes the active Domain in one atomic canonical
action. `d` completes the Brick directly without changing the active Domain.
`s` records the ordinary served-work skip and its cooldown, preserves the
active Domain, and returns to the global weighted draw; that next draw may
select the current branch, another related branch, or an unrelated Domain.
`?` explains the cross-Domain result and its relevant forecast evidence
without answering. `n` is omitted because rejecting focus would duplicate the
meaning already carried by the explicit skip action.

## 13.7 Guided Brick review

`brick_review` is the working proposal name for inspecting one Brick's
currently relevant preparation questions. It replaces grooming meta-Bricks.
The same guided flow may be requested manually through a working surface such
as `la review <brick>` or surfaced by forecast when unresolved mechanics could
materially change eligibility, selection, execution, or planning.

A Brick review:

- is an interaction over the target Brick, not another Brick;
- does not claim a dedicated primary screen grammar or prominent `Review`
  heading; its presence is shown discreetly in the secondary context region
  while each current question uses its ordinary concrete layout;
- has no parent, priority position, phase, effort, status, or terminal event;
- asks only questions that are applicable and materially useful now;
- may route into an ordinary priority, impact, effort, phase, dependency,
  wait, decomposition, scope, date, or description operation;
- does not require every Brick to pass a universal preparation checklist;
- records each accepted answer through its ordinary canonical event;
- resumes through the shared interaction and checkpoint mechanisms rather
  than through a meta-Brick lifecycle;
- ends when no useful question remains or the user exits.

Placement itself is no longer a grooming step because every Brick is positioned
from birth. Low placement confidence may still make an ordinary
`priority_probe` useful.

If review reveals real semantic work, such as researching a dependency or
clarifying an uncertain scope, the core or operator may propose an ordinary
Brick. It is never created automatically merely to make the review appear
complete.

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

`la next`:

- performs one reproducible pseudo-random attention draw;
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
- hard or soft Place conditions and current location observations;
- dependencies and waits;
- current focus and WIP review pressure;
- skip cooldown and accumulated skip pressure;
- stale or contradictory judgments;
- Raw review and refresh;
- delegation, approval, and follow-up state;
- BrickBehavior, standing-work eligibility, recurrence windows, practice
  progress, and unresolved recurring obligations;
- aging;
- other derived proposals.

There is no fixed global phase multiplier. Phase changes what action is useful
and may affect contextual selection, but it does not act as a universal
priority substitute.

## 13.4 Deterministic precedence

Some conditions are resolved before the ordinary lottery:

1. current focus, when it remains valid;
2. stale-focus resolution;
3. external effects or messages already proposed and awaiting approval;
4. overdue follow-ups.

The exact ordering and completeness of this precedence list still needs a
formal review against current delegation and effect semantics.

## 13.5 Proposal vocabulary

The current proposal set includes:

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

These are maintenance or decision opportunities, not meta-Bricks. Their
relative weights and the minimum domain state required by atomic multi-step
operations remain partly open. Every guided proposal follows the shared
resume protocol in
[Resumable interactions and honest progress](31-resumable-interactions-and-honest-progress.md);
interruption never creates a continuation Brick.

The forecast may also surface a proposal to plan real impact-validation work
when the expected value of information is high. Its exact canonical proposal
name remains open. The proposal is not itself a Brick and must not
automatically create a questionnaire, experiment, POC, or MVP.

## 13.6 Guided Brick review

`brick_review` is the working proposal name for inspecting one Brick's
currently relevant preparation questions. It replaces grooming meta-Bricks.
The same guided flow may be requested manually through a working surface such
as `la review <brick>` or surfaced by forecast when unresolved mechanics could
materially change eligibility, selection, execution, or planning.

A Brick review:

- is an interaction over the target Brick, not another Brick;
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

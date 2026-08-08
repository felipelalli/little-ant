# S03 — Importance and lazy judgment

Status: **implemented; full CI green**

## Outcome

Implement the complete human importance order and the separate lazy Impact,
Effort, phase, confidence, contradiction, and recalibration mechanisms without
creating a public priority score.

## Canonical flow rows owned

- Ordering uncertainty, skip, and provisional placement
- Contradiction/recalibration
- Adaptive bulk ordering
- Impact, maturity, and effort judgment
- Optional phase review

Generate all references in those rows plus the complete
[`importance chapter`](../../spec/little-ant-1.0/04-importance-and-judgment.md),
the Judgment confidence and bounded importance-randomness sections of the
[`calculation profile`](../../spec/little-ant-1.0/deterministic-calculation-profile.md),
and UX-O01..O15, UX-J00..J08, UX-PH00.

## Work

1. Implement sibling comparison evidence, strict current display order,
   confidence decay, provisional positions, `either_order`, and inactive
   historical relations.
2. Port the observable `org-sort-tasks`-style adaptive ordering behavior from
   the canonical rules, not from deleted code. Preserve runs and continuous
   `/order` momentum.
3. Implement skip-nearby selection, two-skip placement, `/tie-break`, and
   deterministic midpoint entry.
4. Implement transitive inference, provocative validation, recent-cycle
   detection, explicit contradiction screens, invalidation, and recalibration.
5. Implement separate Impact evidence/maturity and subjective Effort classes,
   exemplars, comparisons, decay, and contradiction handling.
6. Implement optional phase review with no phase-derived ordering authority.
7. Add importance and judgment projections with provenance and confidence,
   without a global numeric score in the human surface.

## Gate

- fixed confidence vectors and all decay boundaries pass;
- a fresh direct human answer cannot be silently overridden by model evidence;
- old evidence remains inspectable after reaching zero effective confidence;
- direct and transitive contradictions produce the exact canonical recovery;
- `/order` compares only siblings and preserves continuous-session behavior;
- Effort never becomes an ordinary-lottery preference;
- acceptance, skip, uncertainty, no-nearby-alternative, dry-run, undo, and
  stale interaction all have deterministic replays.

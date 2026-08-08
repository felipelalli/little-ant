# ADR 0004 — Derived adaptive importance maintenance

## Context

Little Ant must preserve the observable org-sort-tasks behavior: short sibling
runs use insertion-style binary comparisons, longer runs reuse ordered runs and
merge them, and every step may stop after one unresolved pair. Current
positions can seed traversal but are not human evidence.

Persisting an opaque sorter machine would introduce a second semantic source
of truth and make old checkpoints brittle after judgment decay or concurrent
changes.

## Decision

The canonical event log stores only accepted pair judgments, provisional
placement claims, and their immutable history. The next adaptive comparison is
derived deterministically from the current sibling sequence and effective
evidence.

A presentation checkpoint may retain its currently displayed pair and ordering
scope. It is a versioned, revalidatable interaction checkpoint rather than a
semantic sorter event. If its cursor or precondition is stale, the core
recomputes the next unresolved pair from canonical state.

Short groups use insertion-style binary search. Longer groups detect coherent
runs and compare run heads through stable merge traversal. Both paths reuse
direct and transitive evidence and return at most one unresolved pair.

## Consequences

- restart and cancellation do not fabricate comparison evidence;
- decay, retirement, and contradiction resolution automatically affect the
  next derived pair;
- current positions remain useful traversal hints without becoming judgments;
- a sorter implementation can evolve behind its deterministic contract without
  migrating semantic history.

## Evidence

little-ant-s03-judgment-test verifies adaptive evidence reuse, decay,
provocative separation, and contradiction detection. little-ant-s03-flow-test
verifies continuous ordering, provisional placement, tie-break, restart,
dry-run, and separate Impact/Effort/phase flows.

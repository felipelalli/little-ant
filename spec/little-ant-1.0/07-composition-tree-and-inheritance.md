# 7. Composition tree and inherited metadata

## 7.1 Priority hierarchy

The composition tree is also the scope of human priority comparisons.

- Every Brick is a root unless it has an explicit parent.
- The operator may infer a parent from language, but must ask for confirmation
  before recording the relationship.
- Only siblings are directly comparable.
- A cross-parent or cross-level priority comparison is invalid and must be
  rejected with guidance.
- Each active sibling set has a total order.
- The global display order is lexicographic by priority path: a root's position
  dominates every descendant position.

Example:

```text
A
  A1
  A2
B
  B1
```

`A2` still appears before `B1` because root `A` comes before root `B`.

## 7.2 Breaking and moving

- Breaking a Brick keeps the parent in its current sibling position.
- New children form a local ordered sibling set and need initial placement.
- Breaking or adding relevant children makes the parent's decomposition
  coverage `open`.
- A child with no explicit phase inherits the parent's phase initially, but
  that inferred phase is uncertain.
- Moving a subtree preserves all internal structure and internal sibling
  order.
- The moved root is reinserted into its new sibling set with low priority
  confidence.
- Comparisons are scoped to their parent. Evidence from the old scope becomes
  inactive but remains historical.
- If the Brick later returns to the same scope, old evidence may become
  relevant again but can require revalidation.
- Moving, adding, or removing a relevant child reopens previously confirmed
  decomposition coverage for each affected parent.

## 7.3 Closing containers

- A parent with active descendants must reject a simple `done`, `drop`, or
  `supersede`.
- The error must explain how to resolve or batch-handle the subtree.
- Closing the last active child does not automatically complete the parent.
- Instead, it produces a `review_parent` proposal.

Little Ant 1.0 must support explicit batch operations for:

- completing a whole subtree;
- dropping a whole subtree;
- moving a whole subtree while preserving its internal tree;
- superseding a root while transferring selected children or subtrees
  explicitly.

Behavior for active waits, delegations, and pending external effects during
these operations remains open.

## 7.4 Decomposition coverage

A parent effort classification represents its total scope, including children.
To plan that scope without double-counting, the decomposition has an explicit
coverage judgment:

```text
open | complete
```

`complete` means a human or operator has confirmed that the children cover the
parent's planned work. It is never inferred merely because children exist or
because the last child was completed. A structural edit reopens the judgment.
The exact public field and command names remain open.

## 7.5 Scope review

The core may detect a mechanical reason to suspect that scope changed, but it
cannot infer semantic meaning. Description changes, decomposition edits, and
source divergence may therefore create `scope_review`.

Only an explicit human or operator confirmation records `scope_revised`.
Affected evidence loses confidence or applicability without being erased.
Unrelated sibling judgments and metadata remain unchanged.

## 7.6 Effective inherited fields

`context` and `mode` use nearest-ancestor inheritance:

- an explicit child value overrides its parent;
- otherwise, the effective value is found dynamically at the nearest ancestor;
- changing an ancestor therefore changes effective values for descendants that
  do not override it.

Dates accumulate as constraints:

```text
effective_not_before = latest non-null not_before on self and ancestors
effective_best_before = earliest non-null best_before on self and ancestors
effective_deadline = earliest non-null deadline on self and ancestors
```

Inheritance for requester, about, Raw/source links, and other relationships
remains open.

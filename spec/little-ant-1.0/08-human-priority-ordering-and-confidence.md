# 8. Human priority

## 8.1 Meaning and invariants

Human priority is a hierarchical total order of commitment or preference.

- Every active Brick has a position from birth, even when confidence is low.
- Higher means the human currently prefers or commits to it before lower
  siblings.
- Priority does not directly mean impact, urgency, maturity, effort, or
  readiness.
- Dependencies never reorder priority.
- A blocked high-priority Brick remains high priority.
- Its blocker may receive additional selection pressure without moving in the
  human tree.

## 8.2 Canonical question

The canonical English priority question is:

```text
Does "X" come before "Y"?
[y] yes · [n] no · [s] skip
```

There is no tie answer because every sibling set has a total order.

- `y` records `X` before `Y`.
- `n` records `Y` before `X`.
- `s` records no comparison evidence.

Placement uses binary insertion and asks one discriminating midpoint question
at a time.

## 8.3 Ordering skip

Ordering skip is different from skipping a served Brick.

- On the first ordering skip, the core selects a different nearby sibling,
  one to three positions above or below.
- The alternate must be distinct and chosen with reproducible pseudo-randomness.
- On the second consecutive skip for that placement, the round ends.
- The Brick remains in the current provisional slot.
- Its priority confidence stays low.
- A future weighted `priority_probe` proposal will revisit it.

The interpretation is evidence-sensitive:

- an early skip may mean the comparison target is poorly understood;
- repeated skips make “either position is acceptable” more plausible;
- this never creates false y/n evidence;
- uncertainty creates future pressure rather than blocking capture.

## 8.4 Comparison evidence and confidence

Priority uncertainty is not a stored boolean. The public model is:

```text
priority_confidence: 0..1  # derived
```

The UI may show an `uncertain` marker below a configurable threshold.
Confidence reasons must be inspectable.

For each comparable pair, the system retains:

- the current judgment;
- the full judgment history;
- author (`human`, `ai`, or future explicit source);
- timestamp;
- optional reason;
- provenance and relevant scope.

Evidence policy:

- newer evidence weighs more than older evidence;
- human judgment has higher authority than AI judgment;
- an AI judgment must never replace a current human judgment;
- newer AI evidence may lower confidence and provoke a human validation;
- repeated confirmations increase confidence modestly;
- reversals reduce confidence strongly;
- old evidence decays according to axis- and event-specific policies.

Priority should decay slowly. Structural changes, reparenting, and explicit
reversals matter more than elapsed time alone.

A confirmed scope revision may lower the applicability or confidence of
priority evidence, but it never silently repositions the Brick. Any required
movement happens through ordinary priority probes and an explicit coherent
recalibration.

## 8.5 Discovery, validation, and recalibration

The core supports three kinds of priority probe:

1. **discovery** — obtains evidence needed to place or distinguish Bricks;
2. **validation** — asks a deliberately provocative direct question about an
   implied relation;
3. **recalibration** — repairs a locally inconsistent or low-confidence region.

Example validation:

```text
A comes before B
B comes before C
therefore the current order implies A comes before C
```

The system may occasionally ask whether `A` really comes before `C`.

When a human answer contradicts the current transitive order:

- do not reject the answer;
- do not immediately perform a hidden weighted reorder;
- keep the current tree as a clearly provisional canonical order;
- mark the smallest affected sibling segment low-confidence;
- start or schedule a resumable local recalibration using discriminating
  comparisons;
- apply the newly resolved segment atomically only after the local order is
  coherent;
- if the human skips out, keep the segment provisional and revisit it through
  aging.

Validation has a small background rate. Its probability rises after structural
changes, stale evidence, reversals, or detected contradictions. Exact rates and
decay functions remain open.

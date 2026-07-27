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
Is "X" more important than "Y"?
[y] yes · [n] no · [s] skip · [?]
```

There is no tie answer because every sibling set has a total order.

- `y` records that `X` is more important than `Y`.
- `n` records that `Y` is more important than `X`.
- `s` records no comparison evidence.
- `?` records no answer. It requests more information, explanation, or help
  deciding and then returns to the same pending comparison.

Placement uses binary insertion and asks one discriminating midpoint question
at a time.

An ordering-skip subreason may be:

```text
[t] tie-break for me
```

This does not assert equal importance. It authorizes a strict provisional
order while stating that the human has no useful directional preference for
that pair. The exact subdialog key path remains open.

## 8.3 Ordering skip

Ordering skip is different from skipping a served Brick.

- On the first ordering skip, the core selects a different nearby sibling,
  one to three positions above or below.
- `tie-break for me` still causes one nearby comparison so the core can test
  whether a meaningful local boundary exists.
- The alternate must be distinct and chosen with reproducible pseudo-randomness.
- On the second consecutive skip for that placement, the round ends.
- The Brick remains in the current provisional slot.
- Its priority confidence stays low.
- A future weighted `priority_probe` proposal will revisit it.

The interpretation is evidence-sensitive:

- an early skip may mean the comparison target is poorly understood;
- repeated skips make “either position is acceptable” more plausible;
- `tie-break for me` makes deliberate indifference more plausible without
  asserting equality;
- this never creates false y/n evidence;
- uncertainty creates future pressure rather than blocking capture.

If unresolved importance could change a relevant near-term choice, the core
may propose creating an ordinary Brick such as:

```text
Determine whether "A" is more important than "B"
```

The proposal must not create the Brick automatically. The core does not invent
whether the useful method is research, a meeting, a questionnaire, an
experiment, a POC, or an MVP. The operator or powered-up REPL may propose a
method. Completing that work contributes Raw or attributed evidence and
reopens the comparison; it never chooses the answer automatically.

Deliberate `tie-break for me` evidence should create less investigation
pressure than lack of information. Deep-backlog uncertainty that cannot alter
a relevant choice does not deserve mandatory research.

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
A is more important than B
B is more important than C
therefore the current order implies A is more important than C
```

The system may occasionally ask whether `A` really is more important than `C`.

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

## 8.6 Dependency does not constrain importance

The dependency graph and the human priority tree answer different questions:

- priority asks which sibling is more important;
- dependency asks which Brick is currently blocked by another.

A dependency therefore does not force a comparison answer, prohibit a pairwise
importance question, or move either Brick. A blocked Brick keeps its position
and confidence. It is temporarily excluded from executable selection, while
its blocker may gain forecast pressure because completing it unlocks important
work.

Example:

```text
human priority
1. Implement the feature       blocked by Write the specification
2. Publish the announcement
3. Write the specification

currently eligible
- Publish the announcement
- Write the specification
```

`Implement the feature` remains the most important sibling even though it
cannot be executed yet. When `Write the specification` completes,
implementation becomes eligible at its existing position. It is not newly
inserted, and the human is not asked to reconstruct an importance judgment
that already exists.

Structural views should show both position and blocking clearly. Forecast and
`next` use eligibility; the priority projection continues to show the complete
active importance order.

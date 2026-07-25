# 10. Effort and calibration

## 10.1 Meaning

The canonical concept is **effort**: the total work required to complete the
Brick's current scope from start to finish.

It is not:

- elapsed or calendar time;
- a promise in hours;
- remaining effort;
- intrinsic technical difficulty;
- emotional friction;
- urgency;
- impact.

Progress alone never reduces a Brick's effort. A better estimate or a
confirmed scope change may revise it, and the complete estimate history is
retained. In this sense effort represents the original total work for the
current scope, not an immutable first guess.

The selected public name is `effort`. `difficulty`, `complexity`, `size`,
`cost`, and `load` were considered, but each captures only part of the concept
or introduces another ambiguity.

## 10.2 Remaining effort

Remaining effort is a derived planning projection, not a second rating that
the user must continually maintain.

It may decrease only from conservative evidence, such as:

- completed descendants in an applicable decomposition;
- an explicit human progress update;
- imported actuals associated with the Brick.

Focus duration alone never reduces remaining effort. Unexpected duration may
lower confidence or provoke a progress or scope question, but it is not proof
of completed work.

## 10.3 EffortProfile

Effort uses a discrete, ordered, versioned `EffortProfile`; there is no public
`effort_score` float and no global effort ranking of all Bricks.

The initial profile contains exactly these canonical class IDs:

```text
VERY_EASY < EASY < NORMAL < MODERATED < HARD < VERY_HARD <
MINI_PROJECT < PROJECT
```

| Class | Structural macro | Optimistic | Realistic | Pessimistic |
|---|---|---:|---:|---:|
| `VERY_EASY` | `EFFORT_2H` | 2h | 3h | 4h |
| `EASY` | `EFFORT_4H` | 4h | 6h | 8h |
| `NORMAL` | `EFFORT_1D` | 8h | 12h | 16h |
| `MODERATED` | `EFFORT_2D` | 16h | 24h | 32h |
| `HARD` | `EFFORT_4D` | 32h | 48h | 64h |
| `VERY_HARD` | `EFFORT_8D` | 64h | 96h | 128h |
| `MINI_PROJECT` | `EFFORT_16D` | 128h | 192h | 256h |
| `PROJECT` | `EFFORT_32D` | 256h | 384h | 512h |

`A_DAY`, `TWO_DAYS`, and `COMPLEX` are not canonical aliases. The core grammar
has one name per class and one structural macro per class.

Hours belong to the profile and planning boundary, never to canonical Brick
state. A classification surface may display the profile's realistic reference,
for example:

```text
EASY (~6 work hours, realistic)
```

Profiles are versioned so an old estimate preserves the calibration under
which it was made. Profile-editing and migration rules remain open.

The two extreme classes are open-ended: work below the lowest reference is
still `VERY_EASY`, and work above the highest reference is still `PROJECT`.
An outlier lowers confidence. A very large `PROJECT` may also increase the
pressure to propose breaking the Brick down.

## 10.4 Classification dialog

A human may select a class directly. At the classification prompt:

- `?` asks Little Ant to help classify the Brick;
- `s` skips or cancels the classification without recording evidence.

Help uses at most three adaptive comparisons against high-confidence
historical exemplars. Comparisons describe effort, not the colloquial
easy/hard meaning of the class labels:

```text
much less effort
a little less effort
similar effort
a little more effort
much more effort
```

If three comparisons remain ambiguous, the core chooses the best-supported
provisional class with low confidence and allows future probes. Classification
must not block capture or ordinary work.

The core selects exemplars mechanically from applicable historical evidence.
The operator may find semantic analogs or contribute clearly attributed AI
evidence, but that evidence begins with low authority until a human confirms
it.

## 10.5 Parents, decomposition, and scope

A parent's effort describes the total scope of the parent, including the work
represented by its descendants. Descendant estimates do not become additional
work on top of that total.

Every decomposed Brick has a coverage judgment with the current working
vocabulary:

```text
open | complete
```

- Breaking a Brick or adding relevant children makes coverage `open`.
- A human or operator explicitly confirms when the decomposition covers the
  parent scope completely.
- Adding, moving, or removing a relevant child after confirmation reopens the
  coverage judgment.
- Completing the last child still creates `review_parent`; it does not
  automatically complete the parent.

The exact public field and command names for decomposition coverage remain
open.

## 10.6 Scope revision

The deterministic core can detect mechanical reasons to suspect a scope
change, such as description edits, child changes, or source reconciliation.
It cannot determine the semantic meaning of those changes.

Mechanical changes therefore create a `scope_review` proposal. A human or
operator must explicitly confirm `scope_revised` before the domain records a
semantic scope change.

A confirmed revision:

- lowers the applicability or confidence of affected judgments;
- preserves all old evidence;
- lets ordinary weighted probes return after cooldown and aging;
- propagates only through affected relationships, such as the Brick's own
  axes, ancestor total and remaining effort, root impact, and child coverage
  or relevance.

It does not silently change sibling position, phase, dates, or unrelated
judgments. There is no separate bundled `scope_recalibration` workflow.

## 10.7 Evidence, actuals, and confidence

Effort evidence includes:

1. direct human classifications and comparisons;
2. trustworthy historical exemplars;
3. human-confirmed semantic analogies;
4. imported actuals;
5. clearly attributed AI priors.

Human judgment remains authoritative, and newer applicable evidence receives
more weight. The exact public representation of effort confidence remains
open.

When actual effort differs from an estimate, Little Ant preserves:

- the estimated class;
- its confidence;
- the EffortProfile version;
- the observed hours and derived observed class as separate evidence.

Actuals never rewrite the historical estimate. A significant mismatch may
provoke a profile review or scope review.

Effort is gathered lazily when selection or planning needs it; capture should
not become a form. Difficulty and friction remain derived signals from
behavior, context, and skip reasons. There is no canonical
`difficulty_score`.

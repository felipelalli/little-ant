# 14. Contextual skip semantics

The word `skip` is contextual. The core must distinguish the contexts without
ambiguity.

## 14.1 Served-Brick skip

Skipping a selected Brick:

- records a symptom and optional raw text;
- creates a short cooldown;
- preserves longer-term pressure so repeated avoidance is not forgotten;
- may trigger a symptom-specific reaction;
- never means the same thing as an unanswered comparison.

Reporting that the work is complete is `done`, not a served-Brick skip or skip
reason. A served interaction exposes completion as a separate context-valid
action even when no start event exists.

Skip is evidence about what prevented focus, not a remediation command. Pressing
`s` opens one bounded screen containing several applicable symptoms; it does
not force a two-choice split between “this Brick” and an action such as
`change subject`. After the user selects a symptom, a subsequent screen may
offer one or more reactions. The core records the selected symptom separately
from any accepted reaction.

The existing reason family remains evidence for redesign, but several
corrections are fixed. `meh` is removed and `fear` replaces it. `big` is
separate from `hard`; it means that the served work feels too large for the
current focus opportunity, not that its total duration is objectively “too
long.” `not_important_now` replaces the obsolete priority wording and preserves
the temporal nature of that judgment. `bored` is distinct from low general
energy. `waiting` and `blocked` are also distinct symptoms. `waiting` means
that an external person, event, or condition remains unresolved and no
directly actionable work is currently known. `blocked` means that an
actionable prerequisite is missing, such as another Brick, information,
access, or material. A later reaction to `blocked` may therefore propose or
connect a Dependency or enabling Brick without treating that reaction as the
symptom itself.

Confirmed candidate symptom families now include:

```text
vague | hard | big | waiting | blocked | tired | bored | fear |
not_important_now | other
```

`kill` and `alternatives` are not symptoms: the former is a terminal action,
while alternative methods may be proposed as a reaction to several symptoms.

Similar symptoms are visually grouped on the same row while each retains its
own one-key choice. A working layout is:

```text
- [v]ague / [h]ard / bi[g]
- [w]aiting / bloc[k]ed
- [t]ired / [b]ored / [f]ear
- [n]ot important now
- [o]ther
- [?] I don't know

Already finished?

- [d]one
```

`done` remains available on the preceding focus screen and is repeated in a
visually separate “Already finished?” region on the symptom screen. It records
direct completion only: it does not record a skip symptom, create a skip
cooldown, or add avoidance pressure.

When a later accepted reaction applies a reported symptom to a Domain branch,
the selected Domain and its descendants receive a short cooldown followed by
a decaying negative forecast signal. That calculation is core-owned,
replay-deterministic, bounded, and configurable. It never changes human
importance. The symptom alone does not silently choose the Domain scope,
retreat the active Domain, or select another remediation.

## 14.2 Ordering skip

`s` during priority placement means “I cannot or do not want to answer this
comparison.” It records no priority edge, tries one nearby alternative, then
keeps a provisional placement with low confidence.

`tie-break for me` is an ordering-skip subreason. It delegates a strict
provisional order without asserting equal importance and still tries a nearby
comparison. `?` is not skip: it requests information or help and then restores
the same pending comparison.

## 14.3 Classification and rating skip

`s` during impact or effort classification records no assessment evidence.

- In the effort dialog, `s` cancels or defers classification, while `?`
  explicitly asks for up to three assisted comparisons.
- In an impact comparison, skip records no win, loss, or tie. The exact
  alternate-comparison and cooldown policy remains open with the rest of the
  impact dialog.

Neither use is equivalent to skipping a Brick served by `next`.

## 14.4 Practice-opportunity skip

Skipping a served practice suggestion may defer it within the current
applicability window and record a reason. It does not automatically record an
unfulfilled occurrence.

An explicit abandonment action, or deterministic expiry of an applicable
window, may finalize the working `not_done` outcome. Before an explicit action
would end a streak, the REPL may show the concrete consequence and request
confirmation. A blocked or paused practice produces neither a skip failure nor
a missed occurrence.

## 14.5 Repeatable-Brick skip

Once a repeatable Brick reaches its `not_before` and is served again, skipping
it is an ordinary served-Brick skip. It records the ordinary skip evidence,
cooldown, and pressure; it does not create a missed occurrence, advance the
repeat schedule, or assign a new `not_before`.

Only finishing an execution may offer and schedule another repeat.

## 14.6 Taxonomy watch

Selecting `other` records the user's verbatim explanation as attributed skip
evidence. Repeated `other` evidence produces a derived taxonomy-review
opportunity after a configurable threshold. It does not automatically add a
symptom, create a meta-Brick, or rewrite historical evidence.

The review presents the recent evidence that triggered it and asks whether a
recurring missing pattern should become a named symptom or map to an existing
one. Mechanical counting, deduplication, and scheduling are core-owned.
Semantic clustering and label proposals may come from the human, operator
skill, or powered-up REPL. Any accepted taxonomy change is explicit,
inspectable, and versioned.

The opportunity participates in the ordinary focus lottery. It has no fixed
priority lane and does not interrupt a pending interaction. Exact default
thresholds, evidence windows, and decay remain calibration questions.

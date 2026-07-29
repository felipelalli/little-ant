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

The existing reason family remains evidence for redesign, but `meh` is removed
and `fear` replaces it in the 1.0 candidate inventory. The complete enum,
wording, applicability, and shortcuts require the dedicated screen review:

```text
hard | vague | not_priority | waiting | tired | fear |
kill | alternatives | other
```

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

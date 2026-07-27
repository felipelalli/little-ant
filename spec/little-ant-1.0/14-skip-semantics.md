# 14. Contextual skip semantics

The word `skip` is contextual. The core must distinguish the contexts without
ambiguity.

## 14.1 Served-Brick skip

Skipping a selected Brick:

- records a reason and optional raw text;
- creates a short cooldown;
- preserves longer-term pressure so repeated avoidance is not forgotten;
- may trigger a reason-specific reaction;
- never means the same thing as an unanswered comparison.

Reporting that the work is complete is `done`, not a served-Brick skip or skip
reason. A served interaction exposes completion as a separate context-valid
action even when no start event exists.

The existing reason family remains evidence for redesign, but its exact 1.0
enum and letters require a separate review:

```text
hard | vague | not_priority | waiting | tired | meh |
kill | alternatives | other
```

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

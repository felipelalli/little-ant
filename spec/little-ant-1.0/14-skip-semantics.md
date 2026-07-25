# 14. Three different skip semantics

The word `skip` is contextual. The core must distinguish the contexts without
ambiguity.

## 14.1 Served-Brick skip

Skipping a selected Brick:

- records a reason and optional raw text;
- creates a short cooldown;
- preserves longer-term pressure so repeated avoidance is not forgotten;
- may trigger a reason-specific reaction;
- never means the same thing as an unanswered comparison.

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

## 14.3 Classification and rating skip

`s` during impact or effort classification records no assessment evidence.

- In the effort dialog, `s` cancels or defers classification, while `?`
  explicitly asks for up to three assisted comparisons.
- In an impact comparison, skip records no win, loss, or tie. The exact
  alternate-comparison and cooldown policy remains open with the rest of the
  impact dialog.

Neither use is equivalent to skipping a Brick served by `next`.

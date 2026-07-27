# 3. Design center

Little Ant 1.0 is centered on an ordered hierarchy of Bricks.

- **Raw** is durable material that is not orderable work.
- A **Brick** is work and is always positioned in the human priority tree from
  birth.
- Priority position represents commitment or preference: higher means the
  human is more committed to doing it sooner.
- Named commitment stages such as `seed`, `committed`, and `ready` disappear.
- A Brick's optional **phase** describes the currently useful work phase,
  independently of priority. It is collected lazily only when applicable.
- A versioned **BrickBehavior** selects generic interaction mechanics without
  hard-coding domains. A **BrickTemplate** is only a creation recipe.
- A non-focusable structured **ListEntry** belongs to a batch Brick; it is
  neither Raw nor another independently prioritized Brick.
- Entity identity is independent from titles. Duplicate suspicion is
  scope-sensitive evidence, not a hash collision or silent merge.
- The stable priority tree and the dynamic selection forecast are two
  different views. They must not be conflated.
- Human classifications, pairwise judgments, their full history, and
  provenance are principal evidence. Priority derives an order and
  confidence; impact and effort use discrete public classes.
- Effort describes total work for the current scope. Remaining work is a
  conservative projection rather than a moving second estimate.
- TaskJuggler planning uses a confirmed, non-overlapping cut through the Brick
  tree so parent and descendant effort are never double-counted.
- A `Little Ant Pack` contains only typed components. Declarative behaviors,
  templates, and import presets select validated core contracts; executable
  SourceAdapters, Enrichers, ReadOnlyExporters, and UIAdapters run as isolated
  Lua 5.4 components and never execute during replay.
- The standard Pack ships a Lua TaskJuggler exporter as both supported
  integration and the reference implementation for community Pack authors.
- The 1.0 REPL is a deterministic guided harness over the canonical command
  pipeline, with one-key decisions, recoverable dialog state, and an optional
  powered-up judgment adapter.
- Standing work, completion-triggered repetition, recurring obligations, and
  recurring practices are distinct. A repeatable Brick retains its identity
  and priority position while sleeping behind `not_before`; obligations remain
  open when overdue, while an unfulfilled practice opportunity is recorded
  without becoming an infinite backlog.
- The core owns deterministic state, invariants, evidence folding, and
  selection mechanics. The operator owns interpretation, semantic inference,
  external tools, and AI judgment.
- Credentials remain local deployment authority in a Little-Ant-owned
  encrypted vault. Pack code names a credential binding but never receives a
  stored secret or token.

The central distinction is:

> The priority tree records what the human says matters first. The selection
> engine estimates what is useful to surface next under current conditions.

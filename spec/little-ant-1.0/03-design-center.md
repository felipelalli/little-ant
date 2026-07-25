# 3. Design center

Little Ant 1.0 is centered on an ordered hierarchy of Bricks.

- **Raw** is durable material that is not orderable work.
- A **Brick** is work and is always positioned in the human priority tree from
  birth.
- Priority position represents commitment or preference: higher means the
  human is more committed to doing it sooner.
- Named commitment stages such as `seed`, `committed`, and `ready` disappear.
- A Brick's **phase** describes the current nature of the work, independently
  of its priority.
- The stable priority tree and the dynamic selection forecast are two
  different views. They must not be conflated.
- Human classifications, pairwise judgments, their full history, and
  provenance are principal evidence. Priority derives an order and
  confidence; impact and effort use discrete public classes.
- Effort describes total work for the current scope. Remaining work is a
  conservative projection rather than a moving second estimate.
- TaskJuggler planning uses a confirmed, non-overlapping cut through the Brick
  tree so parent and descendant effort are never double-counted.
- The 1.0 REPL is a deterministic guided harness over the canonical command
  pipeline, with one-key decisions and recoverable dialog state.
- The core owns deterministic state, invariants, evidence folding, and
  selection mechanics. The operator owns interpretation, semantic inference,
  external tools, and AI judgment.

The central distinction is:

> The priority tree records what the human says matters first. The selection
> engine estimates what is useful to surface next under current conditions.

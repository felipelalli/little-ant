# Little Ant 1.0 alpha feedback

This log preserves concrete daily-use feedback before a correction is accepted.
Product behavior remains authoritative in the canonical specification; this
file records observations that still need a coherent design.

## ALPHA-FEEDBACK-001 — The REPL needs a direct keyboard exit

- **Observed:** 2026-08-10, immediately after the first real v0-to-v1 cutover.
- **Actual:** `/exit` is available through the command palette, but neither
  `Escape` nor `q` provides an obvious direct way to leave the REPL.
- **Expected:** `Escape` and/or `q` should offer a quick exit for a lazy human.
- **Rejected attempt:** displaying `[q] quit` in the main frame made a terminal
  gesture unnecessarily prominent and introduced `quit` alongside the
  canonical `/exit` vocabulary without a corresponding `/quit` command.
- **Constraint:** a future proposal must preserve one coherent `exit`
  vocabulary and should not add `[q]` to the main interface merely to expose a
  keyboard convenience.
- **Accepted correction (2026-10-10):** retain canonical `/exit`, accept the
  exact REPL-only `/quit` spelling, and support an undisplayed `q` outside
  editable input and filtering selectors when no current action owns it.
  Escape navigates backward first and exits only at the root main opportunity
  screen. Nested views and unfinished input keep their cancel/back behavior.
  Exiting retains the pending interaction and focus, without a domain event.
- **Status:** implemented; real-PTY regression coverage verifies exit and
  ordinary `q` input separately.

## ALPHA-FEEDBACK-002 — Archive orphans the dependency neighbourhood it was part of

- **Observed:** 2026-10-16, while moving four Bricks to an external tracker
  (a GitHub issue) after it was found to cover the same intention. One Brick
  (`P`, a proposal) waited on three prerequisites (`A`, `B`, `C`); the four
  existed only as one line of work.
- **Actual:** the archive preview is honest about each edge (MOD-021): archiving
  `A` listed "Stop blocking: `P`" and warned that dependent Work may become
  executable; archiving `P` listed "Remove prerequisite" for `A`, `B` and `C`.
  But it stops there. Archiving `P` left `B` and `C` active, blocking nothing
  and competing for focus, with no question about them. Noticing them took a
  manual `show` of each neighbour, and archiving them took two more preview and
  confirmation rounds. Had `P` alone been archived, `B` and `C` would have kept
  drawing focus for a goal that no longer exists.
- **Expected:** when archiving removes the last edge that gives a neighbour its
  purpose, the same preview should notice it and let the human decide, instead
  of leaving the neighbour silently orphaned or silently cascading.
- **Constraint:** dependency is not ownership. A prerequisite can be worth doing
  on its own (here, measuring a Pix field's character budget had value beyond
  `P`), and a dependent released by its prerequisite's archive may still be
  wanted. So the fix must never cascade by default; it is a declared choice,
  like MOD-084's `this Brick only` / `entire subtree` and WRK-129's "waits owned
  only by retiring Work may be explicitly cancelled".
- **Possible direction (not a design):**
  - *Upstream:* when archiving `P` leaves prerequisites that now block nothing,
    the preview offers `this Brick only` (default) or `also archive the N
    prerequisites that only served it`, listing them. The scope could follow
    the transitive closure of prerequisites that would end up blocking
    nothing.
  - *Downstream:* when archiving a prerequisite releases dependents, the
    preview offers to archive them too, or to leave them active with an
    explicit marker, because their premise changed but they did not.
  - Either choice is one preview and one accepted operation, so the headless
    `archive --yes` stays single-shot (for example, a flag naming the scope
    instead of a second question).
- **Note:** modelling the four Bricks as children of one parent would have let
  MOD-084's `entire subtree` archive them in one step. The gap is specific to
  work linked only by dependency edges, which the composition tree does not
  cover.
- **Status:** open; needs a coherent design against MOD-021, MOD-084 and
  WRK-129.

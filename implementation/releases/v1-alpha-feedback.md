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
- **Status:** open; design before implementation.

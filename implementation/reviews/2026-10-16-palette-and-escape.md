# Command palette and Escape review — 2026-10-16

Long Brick titles appeared in both a palette command's reference and its
description. The renderer appended both strings without a separator once the
command exceeded its twelve-character padding. A few commands could consequently
fill the entire terminal with repeated title text.

The palette now presents a bounded quoted title preview with `(...)`, an
explicit gap before its description, and no repeated citation in that
description. Rows use at most 100 terminal columns; narrow terminals stack the
description below the command. Typed references remain whole, and truncation
uses terminal cell width for wide characters. Canonical command strings,
descriptions, title search, and dispatch arguments remain unchanged.

Escape from the palette already returned to its owning screen locally. A second
Escape requested backward navigation from that screen. If another client had
replaced the pending checkpoint, the engine correctly rejected that navigation,
but the REPL displayed the stale-navigation error instead of allowing exit.
The main-screen exit gesture now also closes the presentation session on that
failure. Valid backward navigation still restores its preceding checkpoint;
responses and headless navigation retain their strict validation. This does not
provide concurrent-session isolation or fix concurrent checkpoint publication.

The regression was reproduced before the change with a second public `focus`
call replacing the question while the first REPL's palette was open. The new
test checks that two Escapes exit without rewriting the replacement checkpoint
or changing history. An existing regression retains ordinary guided backward
navigation before exit.

A surface regression checks bounded rows, Unicode width, display truncation,
full-title filtering, and unchanged command selection. Real PTY coverage checks
long-title palettes at 28, 80, and 160 columns, then executes the original command
against its exact target and verifies the full title is preserved.

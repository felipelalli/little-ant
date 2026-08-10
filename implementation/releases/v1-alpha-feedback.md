# Little Ant 1.0 alpha feedback

This log preserves concrete daily-use feedback before and alongside each
alpha correction. Product behavior remains authoritative in the canonical
specification; this file records why a correction entered the release.

## ALPHA-FEEDBACK-001 — The REPL had no obvious direct exit

- **Observed:** 2026-08-10, immediately after the first real v0-to-v1 cutover.
- **Actual:** `/exit` was available through the command palette, while `Escape`
  silently stopped at the root navigation boundary and `q` was ignored.
- **Expected:** a lazy human can leave without opening a menu or remembering a
  slash command.
- **Decision:** `Escape` keeps returning through local uncommitted screens and
  exits at the root; lowercase `q` exits from non-text screens; text editors,
  searchable selectors, and the palette retain literal `q`; the main frame
  shows `[/] more...   [q] quit`; `/exit` remains equivalent.
- **Safety:** every exit is presentation-only and appends no event.
- **Status:** implemented; covered by pure input and reference-frame tests.

## ALPHA-FEEDBACK-002 — Very narrow date footer can exceed its width

- **Observed:** while testing ALPHA-FEEDBACK-001 at an artificial 20-column
  terminal width.
- **Actual:** an existing date/status line may exceed that extremely narrow
  width; the new quit control reflows correctly.
- **Impact:** cosmetic at unusually narrow widths; it does not block exit or
  daily use.
- **Status:** queued for the alpha polish batch.

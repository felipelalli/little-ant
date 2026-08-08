# ADR 0001 — Thin Vty terminal backend

Status: **accepted for implementation; replaceable without product change**

## Canonical constraints

PRD-002, PRD-006, UX-001..005, UX-011..015, SCN-015, and S00 require an
immediate-key dumb REPL with editing, resize, Unicode display-cell width,
theme-safe roles, selected text, no-color output, interruption cleanup, and a
deterministic headless renderer. The terminal may not own domain decisions or
reconstruct an `InteractionEnvelope`.

## Alternatives considered

- `haskeline` provides mature line editing but does not naturally model the
  complete immediate-key screen and resize loop.
- `ansi-terminal` plus custom raw `termios` keeps dependencies small but would
  make Little Ant own input decoding, width tables, resize handling, and
  terminal restoration.
- `brick` provides a complete widget framework but adds an unnecessary second
  UI composition layer between the canonical screen model and the terminal.
- Vty provides event decoding, resize, width tables, attributes, painting, and
  cleanup without requiring Brick.

## Decision

Use `vty` 6.4 with `vty-crossplatform` 0.4 as a thin backend. Little Ant owns a
pure, backend-neutral `ScreenModel`, editing state, navigation checkpoints, and
semantic role names. Vty maps roles to terminal attributes, converts events to
backend-neutral input, and paints the already-composed model.

Factory styling uses default terminal colors wherever possible: dim for
secondary material, bold cyan for shortcut accents, and reverse video for the
active selection. Plain rendering discards roles while preserving identical
text and action order.

## Evidence and replacement boundary

The S00 unit/property suite checks event mapping, wide-character width,
role-independent plain output, and stable random-purpose seams. The backend is
always acquired with `bracket`, so interruption and exceptions run Vty's
terminal restoration. Later PTY tests will cover actual resize, immediate-key
input, selected text, no-color behavior, and injected interruption before S01
claims the shared-frame flow.

`LittleAnt.Terminal` may be replaced when the same pure `ScreenModel`, input
algebra, PTY fixtures, and golden text continue to pass. Such a replacement
cannot change any command, shortcut, envelope, event, or screen grammar.

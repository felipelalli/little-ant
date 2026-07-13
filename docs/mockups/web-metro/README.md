# Web mockup — Metro (Windows Phone) style

A navigable HTML mockup exploring a **fourth surface** for Little Ant (after the
CLI, the LLM skill, and the planned REPL): a touch/click web UI. It is a design
exploration, **not committed direction** — the core stays the owner; any web UI
would talk to `la` (or a thin `la serve` over the same binary).

This file is the **source of truth**. The claude.ai artifact below is only a live
preview; git history (`git log -- docs/mockups/web-metro/`) is the real version
record.

## Preview & open

- **Live preview (private, opens logged in at claude.ai):**
  <https://claude.ai/code/artifact/74280abd-3895-4201-8b76-a10327e013ed>
- **Local:** open [`index.html`](index.html) directly in a browser (`file://`).
  It is self-contained — no build, no assets, no network.

Keyboard works too: with a brick on screen, press `y`, `s`, `!`, letters, `Enter`
(default), `Esc` (back) — same grammar as the CLI.

## Design principles (the ones the mockup commits to)

- **Metro / WP7 dark**, panorama title in light lowercase ("what now?").
- **Fixed colour per command** — colour *is* the command's identity, consistent
  across every screen (`y` green · `s` orange · `b` teal · `d` violet · `c`/feed
  magenta · `k` red · `?` steel).
- **Tiles fill 100% of the screen**, sized dynamically; the suggested default
  (`!`) is the biggest tile.
- **Stable spatial anchors** — `skip` always sits in the top-right (2nd quadrant);
  muscle memory over menus.
- **The page never scrolls.** Content cards (subject, detail "card") may scroll
  *invisibly* under the finger (no scrollbar, contained overscroll); controls
  (tiles) never move.
- **`?` is always a small tile** — no keyboard on touch, so the universal `?`
  becomes a persistent square that also opens the brick's details card.
- **Bold mnemonic letter, not an isolated letter-as-icon** — e.g. **y**es,
  **s**kip; the glyph in the tile is an icon, the label carries the emphasised key.

See `DRAFT.md §3.8` (working notes, local) and the main
[`README.md`](../../../README.md) for the fuller rationale.

## Screens

- **flow** — the focus proposal: subject + `!`/`skip` + aux commands.
- **skip** — the 8 skip reasons in a grid (hard, vague, not priority, waiting,
  tired, meh, kill, alternatives), each its own hue and the reaction it fires.
- **compare** — A vs B, for total-order sorting.
- **capture / feed** — a single no-forms input box.
- **details** — the brick's "card" (long description, refs, URLs, history),
  reached via `?`.

## Changelog

Milestones are the git commits; this is the human-readable summary.

### 2026-07-12

- **Trail replaces toast.** The quick flash-and-vanish confirmation popup is gone;
  a persistent "trail" line (coloured dot + last-action text) sits under the
  status strip and stays until the next action, so it's actually readable.
- **Landscape reflow on any height.** The wide-screen grids (skip → 4×2, plus
  flow/compare/wip/details) were gated behind `max-height:520px` and only fired on
  short phones; they now trigger on any `orientation:landscape`, fixing overflow
  and clipped label descenders on desktop Chrome landscape.

### 2026-07-11 (v1 → ~v14)

- Authentic WP7 dark theme; fixed colour per command; `skip` anchored top-right;
  tiles at 100% with dynamic sizing; no page scroll.
- Mobile `file://` fixes: `<meta viewport>` and `<meta charset=utf-8>` (accents
  were breaking, text was invisible at 980px virtual width).
- Fluid `vmin` typography; aux row reworked to a full-width 3/4-col grid so tiles
  stop overflowing vertically; 2-line label clamp; landscape minis go letter+label
  side by side.
- `?` promoted to an always-present small tile that opens the brick details card.
- "capture" renamed toward **feed** (better for a Portuguese speaker; `add` stays
  as a skill alias) — see DRAFT for the full rename decision.
- Isolated-letter-as-icon dropped in favour of an icon glyph + **bold mnemonic**
  in the label; contrast tuned (white key, command-coloured label).
- Staggered flip-in on arrival, flip-out on choice; `prefers-reduced-motion`
  respected; invisible scroll inside content cards only.
- Real data wired in (the "Revisar README" brick, the 1:1 round, frontier count).

# Little Ant 🐜🧱

> *One brick at a time.*

Little Ant is a personal focus engine: a small, deterministic CLI that keeps every
executable task of your life — work or personal — as a **brick** that can be stacked,
broken into smaller bricks, prioritized by pairwise comparison, and served back to you
one at a time when you ask the only question that matters: **"where should I focus now?"**

It is *not* another todo app. Its founding bet is that the interesting data is not the
task list — it's what happens when you **refuse** a task. Every skip demands a reason,
and every reason changes the system.

## Philosophy

1. **Dumb core, smart outside.** The CLI is a deterministic state machine: offline,
   fast, testable, vendor-neutral. It has no AI inside and doesn't know GitHub exists.
   Judgment (triage, suggestions, policy, integrations) belongs to an LLM operating the
   CLI from outside — a generic agent skill ships with this repo.
2. **Designed for an LLM operator.** The primary user of the CLI is often an agent, not
   a human: `--json` everywhere, stable output schemas, idempotent operations,
   `--dry-run`, semantic exit codes, and error messages that teach correct usage.
3. **Plain text is the source of truth.** An append-only event log in JSONL. Versionable
   with git, greppable, readable by any AI without this tool, and it survives the tool's
   death. Databases may appear only as disposable, rebuildable lenses.
4. **Skips are signal, not evasion.** Procrastination becomes structured data. The
   system gets *antifragile to your own discouragement*: each dodge enriches the graph.
5. **No forms, ever.** Capture takes a title and nothing else. Metadata is collected
   lazily, in tiny drips, at the moment it is needed — never as a toll right before
   execution.
6. **External actions are always proposed, never silent.** Anything that leaves the
   system (a message, a write-back, a deploy) is shown in full and approved first, even
   in the tersest UI mode.

## Install

The binary is called **`la`** (little ant — short enough to type dozens of times a
day). Heads-up: many shells alias `la` to `ls -A`; an interactive alias shadows the
binary, so check `type la` and drop or rename the alias.

**Nix (flake):**

```sh
nix profile install github:felipelalli/little-ant
# or run without installing:
nix run github:felipelalli/little-ant -- status
```

**Cabal** (GHC ≥ 9.6):

```sh
git clone https://github.com/felipelalli/little-ant && cd little-ant
cabal install exe:la
```

**Data** lives in `~/.local/share/little-ant/` (override with `$ANT_DATA_DIR` or
`--data DIR`): an append-only `events.jsonl` (the truth) plus an optional
`config.json` for the scheduler knobs (`background_serve_ratio`,
`foreground_window`, `comparison_shelf_life_days`, `nudge_interval_days`,
`wip_check_after_hours`).

**The agent skill** ships in this repo. For Claude Code:

```sh
ln -s "$(pwd)/skills/little-ant" ~/.claude/skills/little-ant
```

Then talk to your agent: `/ant`, "where should I focus?" — the skill operates the
CLI (always via `--json`) and drives the conversation. Personalize by creating
`~/.config/little-ant/ANT.md` declaring your bindings: which integrations deliver
messages, calendar sources, your contexts, UI language.

Sanity check without an agent:

```sh
la capture "my first brick" && la promote <ref> && la ready <ref>
la session open && la next
```

## Core concepts

### Brick

The single abstraction. A brick can be the fuzzy idea of a huge project or "tighten one
screw" — every brick can be broken into smaller bricks (composition tree) and connected
by dependencies (DAG). The word "task" is banned from this project's vocabulary.

Lifecycle (`stage`):

```
raw material ──extract──▶ seed ──promote──▶ committed ─▶ ready ─▶ wip ─▶ done
                                                                       ├▶ dropped
                                                                       └▶ superseded
```

- **raw** is pre-brick material — a pasted brainstorm, a loose conversation. Extraction
  yields *zero or more* seeds. Triaging raw = extraction; triaging a seed = decision
  (promote / incubate / kill).
- **seed** is the idea bucket: a real brick, but uncommitted. Seeds are *invisible* to
  the focus loop — they only surface in triage rounds. Nothing nags you.
- `next` only ever serves bricks at `committed` or beyond.

Key fields (all data always in English):

| Field | Values | Notes |
|---|---|---|
| `kind` | `spec \| exec \| delegation \| decision \| meta` | canonical, extensible |
| `atomic` | `true \| false \| "unknown"` | atomic bricks can't be broken — skip(hard) offers learn/delegate instead |
| `energy` | float `0..1` | nobody types floats; the skill maps words ("light" → 0.2) |
| `mode` | `digital \| physical` | physical bricks carry conditions (place, time window) and get batched |
| `context` | free, namespaced | `acme/api`, `personal/home` — namespacing gives per-project vocab for free |
| `estimate` | `{value, by: ai\|human}` | guesses are always marked as guesses |
| `meta.*` | free bag | the core never rejects unknown values |

### Identity

`id = sha256(original title)`, referenced by short prefix, git-style (`a3f9e21`).
Renaming never changes identity — the title is pure display. A title collision is a
*feature*: the CLI rejects it and forces a more specific title ("buy paper" → "buy
paper (Jul)"). Entities use the same scheme.

### Entities

A first-class registry of who/what surrounds your bricks:

```jsonc
{
  "id": "e8f3a21…",              // sha256 of canonical name
  "type": "person",              // person | ai_agent | company | area
  "name": "João Silva",
  "refs": { "gchat": "users/1128…", "github": "@joaosilva",
            "email": "joao@…", "docs": "https://…/joao" }
}
```

Used by `requested_by` (structured: entity, channel, date, notes, context),
`stakeholders`, delegation, and `on_done` notifications. One registry, N uses. The
skill resolves `refs` when it needs to act (nudge João → knows his Chat id).

### Delegation

Bricks owned by someone else get their own state machine and history:

```
notified ─▶ nudged(1) ─▶ nudged(2) ─▶ … ─▶ done | refused | abandoned
```

with `next_nudge` dates. Overdue follow-ups are served by `next` like any other brick
("João has had X for 6 days — nudge again?").

### Triggers

`on_done` (declarative on the brick): `writeback: close #412`, `notify: <entity>`,
`spawn: "deploy to staging"`. The core only records and spawns; the *skill* executes
external effects — always proposing first.

### Supersede

When you keep the goal but reject the method ("order online instead of going to the
store"), the old brick enters the terminal state **`superseded`** — deliberately neither
`done` nor `dropped`, so statistics stay honest. The replacement **inherits** parent,
deps, `requested_by`, inputs, and the slot in the total order (the goal's priority
didn't change — only the method). History preserves the chain A→B→C and estimate
learning sees through it.

## The skip taxonomy (the heart of the system)

`next` suggests a focus. You either start it — or skip it, and **a skip demands a
reason**. Each reason is a different diagnosis with a different cure:

| Key | Reason | Meaning | System response |
|---|---|---|---|
| `h` | **hard** | I know what to do, but it's heavy | offer break / learning-brick / delegate |
| `v` | **vague** | I don't know where to start; "done" is undefined | spawn a spec meta-brick — *vague gets specified, not broken* |
| `p` | **not a priority** | the ordering is wrong | "then what IS?" → local re-sort |
| `w` | **waiting** | the world isn't ready: a person, another brick, or **conditions** (place, store hours, weekend) | record the wait; brick leaves the frontier until the condition holds |
| `t` | **tired** | no mental energy | offer a question round, a lighter brick, or "go rest" |
| `m` | **meh** | aversion — boredom, conflict, dread | *no judgment*: offer a 2-minute first step, pairing with AI, or a break-down |
| `k` | **kill** | shouldn't exist / obsolete | archive with a record |
| `a` | **alternatives** | I reject the *method*, not the goal | propose 2–3 alternative paths → supersede |

Design notes that took years of procrastination to learn:

- **`h` ≠ `v`.** "Hard" and "vague" are usually conflated, and their cures are
  opposite: hard gets *broken*, vague gets *specified*. Breaking a vague brick only
  multiplies the vagueness.
- **`m` (meh)** is the skip no tool admits exists — and the most common one in real
  life. Acknowledging it without judgment and answering tactically is where Little Ant
  becomes a coach instead of a whip.
- **Free text always works.** The skill classifies it into a canonical reason (with
  confirmation); if nothing fits it records `reason: "other"` — and the raw utterance is
  *always* preserved in the event, classified or not. Accumulated `other`s are the
  sensor for evolving the taxonomy: the taxonomy grows by evidence, not by guesswork.

## Architecture

```
┌────────────────────────────────────────────────────────┐
│  YOU  (terminal, or Telegram / anything → your agent)  │
└─────────────────────────┬──────────────────────────────┘
                          │ natural language
┌─────────────────────────▼──────────────────────────────┐
│  AGENT SKILL (generic, ships in this repo)             │
│  judgment · triage · policy · question rounds          │
│  integrations via YOUR manifest (ANT.md)               │
└─────────────────────────┬──────────────────────────────┘
                          │ CLI calls (--json)
┌─────────────────────────▼──────────────────────────────┐
│  little-ant CORE (dumb, deterministic, offline)        │
│  state machine · scheduler mechanics · event log       │
└────────────────────────────────────────────────────────┘
```

- **Core** — this repo. No AI, no network, no opinions about your life.
- **Generic skill** — also this repo (`skills/little-ant/`). Teaches any Claude (or
  other agent) to operate the CLI.
- **Personal manifest** (`~/.config/little-ant/ANT.md`) — *yours*, not in this repo.
  Declares your sources and bindings: "calendar via this MCP, chats via that skill,
  capture via Telegram, my contexts, my aliases". The core defines the slots; your
  manifest does the binding. A user with no integrations uses the bare core; you use it
  with your whole arsenal.

A planned oracle hook keeps the core vendor-neutral while allowing wiring:
`la next --oracle <cmd>` piping JSON to any external command (not in v0).

## Data model

**Event sourcing.** The truth is `events.jsonl`, append-only. Current state is a
deterministic fold over events, held in memory (personal scale: years of history fold in
milliseconds). Everything else is a projection.

```jsonc
{"event": "skipped", "brick": "8e02bd", "reason": "vague",
 "raw": "sei lá, nem sei direito o que era pra fazer aqui", "at": "2026-07-10T10:12:03Z"}

{"event": "superseded", "brick": "f4a91c", "by": "8e02bd",
 "reason": "buy online instead of going to the store"}
```

What this buys:

- **The journal is free.** "When did I start/stop X", every decision, every skip — the
  log *is* the journal, not a parallel record.
- **Sync is set-union.** Events have unique ids; syncing devices = exchanging missing
  events; state = fold of the union. Git is merely the v1 transport
  (`events.jsonl merge=union` in `.gitattributes`); a future Android app or web UI just
  swaps the transport. No model change.
- **Archiving is log rotation.** A monthly meta-brick moves bricks in a final state for
  more than `archive_after` (default: 3 months) to `archive/YYYY-QN.jsonl` — always the
  *whole brick, atomically*. A snapshot file keeps startup fast forever. Referencing an
  archived brick prompts to load it. Reports, statistics and estimate-learning read the
  archives on demand (DuckDB reads JSONL natively — analytics without owning storage).
- **Human views are projections.** `la render` regenerates the backlog view — and
  `la render --format org` emits org-mode for Emacs muscle memory. Conflicts in
  projections are irrelevant by construction.

External sources are referenced, never copied: `inputs: [{ref, seen, hash}]` where
`ref` is typed (`github:org/repo#123`, `life:trips/x.md`, `chat:…`, `frill:…`).
Umbrella bricks aggregate many refs ("10 backlog issues become one big brick here").
The sync contract has three moments: **on execution** (re-read sources, compare hash —
"did anything change since last seen?"), **write-back** (state changes here are
mirrored there — always proposed), and **periodic reconciliation** (drip). Divergence
never auto-resolves: it becomes a `reconcile` meta-brick.

## Prioritization

A **total order, decided by pairwise human comparison** — the
[org-sort-tasks](https://github.com/felipelalli/org-sort-tasks) lineage, upgraded:

- The order lives on the **unblocked actionable leaves** (the frontier) only. You never
  compare "Project A vs Project B" — abstractions produce dishonest answers. You compare
  next concrete actions. A parent's rank derives from its best leaf.
- The dependency DAG **constrains** the sort: a question that would violate a dependency
  is never asked; blocked bricks inherit "after their blocker".
- **The AI pre-orders, the human settles.** AI-suggested order arrives as long
  pre-sorted runs; a timsort-style merge exploits those runs, so the human answers a
  handful of genuinely ambiguous comparisons instead of O(n·log n). Inserting a new
  brick is a binary search — ~log n questions, usually zero.
- **Comparisons are events** with timestamp and author (human/AI). Human answers
  override AI ones. Comparisons **age**; revalidation ("is X still ahead of Y?")
  happens as a drip — 1–2 questions per session, targeting stale comparisons *near the
  top* (the bottom doesn't matter, the top does). The full list is never re-sorted.
- The drip is a floor, not a ceiling: when you have the energy — or precisely when you
  are skipping everything with `tired` — the `q`uestions command runs a batch round
  (comparisons, triage, enrichment). Fatigue becomes system maintenance.
- `?` (dunno) on any comparison collects proxies (complexity, urgency, criticality) and
  lets the AI break the tie.

## Scheduler: mechanism in the core, policy in the skill

The `next` engine is a scheduling problem, and the cut is the classic OS one:

**Core mechanisms** (dumb, deterministic, configurable knobs):

- **Two queues + ratio** (drip-feed): every Nth `next` serves the background queue, so
  low-priority work provably moves.
- **Aging** (anti-starvation): waiting/skipped bricks accumulate pressure and eventually
  surface.
- **Sticky context sessions**: `next` prefers the current session's context until it
  ends or a time quantum expires — with strictness levels `ignore | prefer | require`.
- Meta-bricks are first-class citizens generated by rules: skip(vague) → "clarify X",
  overdue follow-up → "nudge João", accumulated `other` skips → "consider new reason",
  monthly → "compact archive".

**Skill policy** (contextual, iterated freely — it's a prompt, not a release): which
context today (meeting-shredded day → shallow bricks), maker/manager day themes,
energy-to-time matching, holidays, when to override the ratio — informed by your skip
history and mood. The CLI exposes the knobs; the skill turns them.

One behavioral guarantee: **a session always ends in a proposal**, never in silence.

## Interaction grammar

Terse by default; depth on demand. Single letters, two consistent namespaces:

| Commands | Answers | Skip reasons |
|---|---|---|
| `x` next · `s` skip · `b` break · `u` unify · `d` delegate · `c` capture · `q` questions | `y` yes · `n` no · `l` later (absolute dates) | `h v p w t m k a` (table above) |

- `!` marks the AI-suggested default; typing `!` alone accepts it. When the AI has no
  basis to guess, there is no default — it doesn't bluff.
- `?` is universal — dunno / more info / hints ("help me out here"). Like `!`, it is
  global and never listed in menus.
- With a question pending, a bare letter is an *answer*; a whole word is always a
  *command* (`next` works even where `n` means "no").
- Letters are for frequent paths; rare/deep dialogs are free text ("waiting on what?
  — just type it").
- Natural language always works everywhere; the skill maps it (with confirmation when
  unsure).
- UI language: English by default, configurable (`lang`) — but data is always English,
  and messages to third parties are written in the *recipient's* language.

A session, at real size:

```
🐜 little ant · Fri 10:07 · frontier 9 · inbox 4 · wip 0 · follow-ups: 1 due

ant > João has had "Review Gateway contract draft" for 6 days (nudged Mon). Nudge again?
      ![y] · [n] · [l]ater (Mon, Jul 13)
me  > y
ant > Draft (Google Chat → João):
      ┃ Oi João! Conseguiu avançar na revisão da minuta? Qualquer bloqueio me avisa.
      ![y] send · [e]dit · [n] cancel
me  > y
ant > Sent ✓ — nudge #2 (next: Wed, Jul 15)

ant > Focus: "Spec: reconciliation endpoint — error cases" · acme/api · spec · ~2h (est: ai)
      ![y] start · [s]kip · [b]reak
me  > s
ant > Skip — why?
      [h]ard · [v]ague · [p] not priority · [w]aiting · [t]ired · [m]eh · [k]ill · [a]lternatives
me  > v
ant > Vague ✓ — clarify now with me? (~2 min, I'll draft "done criteria" from #412)
      ![y] now · [l]ater → spawns "Clarify: error cases" (keeps its slot), then next focus
```

## Personalization & vocabulary governance

The rule of thumb: **is there code hanging off the value?**

| Regime | Examples | Change requires |
|---|---|---|
| Fixed, versioned in the tool | `stage` transitions, event types, delegation FSM | a release — these have behavior attached |
| Canonical + extensible | skip reasons (8 + `other`), `kind` | new values are born as `other`/free and get *promoted* when they earn code |
| Free, yours | `context`, `energy`, `meta.*` | nothing — just use them (`la set <ref> --context whatever/new`); the core never rejects unknown values |

Dynamic first, harden later — the same philosophy as the whole project. Renames never
rewrite history (the log is immutable): the manifest holds `aliases: {"old": "new"}`
and projections apply the mask.

## Roadmap

- **v0 — the Haskell core + generic skill** *(done)*: the full spec implemented as a
  typed, event-folding state machine; the `la` CLI designed for an LLM operator;
  36 spec-derived tests. Now: daily use — discover which skip reasons actually occur,
  whether the total order survives contact with the DAG, what `next` really needs to
  know. The open questions in [`spec/`](spec/) close with usage evidence.
- **v1 — planning & estimates**: TaskJuggler export (`la export tj`) with AI-filled
  estimate gaps explicitly marked as guesses, scenarios simulated from real
  started/stopped durations; the oracle hook; richer question rounds.
- **v2 — richer world**: multi-device transport (event-union endpoint; the model is
  already ready), richer write-back, opportunity scanning over live sources.

## Open questions

Mirrored as `open question` declarations in [`spec/`](spec/):

1. Core language & timing: Haskell is the leaning; v0 validates semantics as
   skill+files first — confirm the sequence.
2. Estimates: unit/format, when collected, the AI-guesses-human-corrects flow.
3. Scheduler defaults: queue ratio N, context quantum, aging curve.
4. Comparison staleness: decay function / half-life.
5. Question-round (`q`) composition: mix of comparisons, triage, enrichment.
6. Fine-grained reconciliation policy: which upstream changes auto-apply vs. notify.
7. Multi-device transport (v2): event-union endpoint vs. pure git.
8. `on_start` triggers — do they exist?
9. Definition-of-ready per kind: which metadata is mandatory before serving each kind.
10. Session-opening status line: exact content (signal vs. noise).

## Status

**v0 implemented** (2026-07): the `la` CLI in Haskell covering the full
[Allium spec](spec/) (`allium check` clean), the generic agent skill in
[`skills/little-ant/`](skills/little-ant/), and a spec-derived test suite. The spec
remains the authority on behaviour; divergences are bugs. Open questions close with
usage evidence — see Roadmap.

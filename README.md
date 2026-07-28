# Little Ant 🐜🧱

[![CI](https://github.com/felipelalli/little-ant/actions/workflows/ci.yml/badge.svg)](https://github.com/felipelalli/little-ant/actions/workflows/ci.yml)

<p align="center">
  <img src="assets/littleant.png" alt="A little ant carrying a brick" width="220">
</p>

> *One brick at a time. Inch by inch, anything's a cinch.*

Little Ant is a personal focus engine. It captures unfinished material, keeps
work in a human-defined importance order, and helps answer one practical
question:

> **Where should I focus now?**

It is designed around a deterministic, inspectable core. Humans and optional
operators provide judgment; the core owns identity, history, ordering
mechanics, validation, recurrence, eligibility, and replay.

Little Ant 1.0 is defined by the composed
[Allium specification](spec/little-ant.allium). The Markdown files under
[spec/little-ant-1.0](spec/little-ant-1.0.md) retain design history and
rationale; when they disagree with Allium, Allium wins.

The core has one unambiguous command vocabulary and no compatibility aliases.
A skill or operator may translate natural language into those canonical
commands.

## The model

### Raw

`Raw` is source material, not work: a URL, note, pasted conversation,
brainstorm, file, or imported object that has not yet been routed.

Raw material:

- is never prioritized, focused, started, or completed;
- preserves verbatim content and attributed provenance;
- may have an attributed canonical English representation for search;
- may live on one or more flat shelves;
- may be linked to a Brick or ListEntry as source, evidence, or attachment;
- is archived rather than permanently deleted.

See [material.allium](spec/little-ant/material.allium).

### Brick

`Brick` is the single work abstraction. A Brick may be a small action, a
project, a standing responsibility, a collection, a repeatable activity, or a
recurring practice.

Its lifecycle is deliberately small:

```text
active ──▶ done
   ├─────▶ dropped
   └─────▶ superseded
```

`seed`, `committed`, and `ready` do not exist in 1.0. Commitment is inferred
from position in the human priority tree: higher means more important.

Optional phase is a separate axis:

```text
idea · spec · exec · validation
```

Phase does not determine priority, completion, or WIP. Behaviors may disable
phase or effort when those concepts would only add noise.

Brick IDs are opaque and survive renames. Canonical searchable titles are
English; original titles remain available as provenance.

See [domain.allium](spec/little-ant/domain.allium) and
[execution.allium](spec/little-ant/execution.allium).

### ListEntry

A `ListEntry` is a lightweight item owned by a checklist Brick, such as
“Milk” under “Buy groceries.” It has no independent priority, phase, effort,
WIP, or `next` eligibility. The owning Brick remains the focus unit and may
render all open entries together.

This avoids turning every grocery item, packing item, or similar occurrence
into a full task.

### Behaviors and templates

Behaviors are small, closed combinations of capabilities understood by the
core. Templates are inspectable recipes that select a behavior and optional
defaults; they do not inject hidden domain logic.

The 1.0 catalog includes generic behaviors for standard work, projects,
collections, repeatable work, finite and standing checklists, recurring
obligations, and practices. Standard templates include:

- grocery and packing checklists;
- reading lists and repeatable article reading;
- software feature backlogs and wishlists;
- bills to pay;
- exercise practices.

Users may publish versioned personal behaviors and templates from the same
closed capability vocabulary.

## Two views, two different questions

Little Ant intentionally has two list-like projections:

| View | Question answered | Authority |
|---|---|---|
| **Human priority** | “What is more important?” | Strict sibling order settled by human judgment |
| **Forecast / next** | “What is useful and eligible now?” | Read-only deterministic forecast plus replay-safe draw |

Human priority is a persistent tree. Within each sibling scope, every active
Brick has exactly one strict position. A global view is the lexicographic
composition of those local paths.

Forecast does not rewrite priority. It may consider current focus, inherited
dates and context, phase when applicable, dependencies, waits, place
conditions, cooldowns, recurrence opportunities, unresolved reviews, and
pressure accumulated from skips.

See [judgment.allium](spec/little-ant/judgment.allium) and
[selection.allium](spec/little-ant/selection.allium).

## Common flows

The transcripts below use the canonical terminal interaction. Other surfaces
preserve the same actions and revisions while adapting their presentation.

### Capture a grocery item

```text
$ lant
ant> /feed Buy milk

Possible destination: "Buy groceries" (Grocery list)
[y] add as a list entry · [n] choose another route · [?]
```

Duplicate suspicion runs before creation. Nothing is merged silently. In dumb
mode, the REPL asks for a route when it cannot infer one safely; a skill or
powered-up adapter may make an attributed proposal.

### Insert work into human priority

```text
Is "Replace the laptop battery" more important than
"Read the storage design paper"?
[y] yes · [n] no · [s] skip · [?]
```

Insertion uses binary comparison. `skip` never means “equally important.”
It can mean unresolved or “break the tie for me.” Nearby candidates are tried;
after the configured threshold, the Brick keeps a strict but provisional
position and gains future validation pressure.

### Ask what to do next

```text
ant> /next

Focus: "Replace the laptop battery"
Why: high human priority · available now · unlocks another Brick
[y] focus · [d] done · [s] skip · [?]
```

Direct `done` is honest: it does not invent a start time or zero-duration
execution. A served-work skip records a reason and changes later pressure; it
does not imply completion.

### Read an article again later

```text
ant> /feed https://example.com/paper
Route: preserve as Raw, then create "Read the storage design paper"

...after reading...

Read it again in roughly six months?
[y] schedule the same Brick with a jittered not-before date · [n] retire
```

Completion-triggered repetition reuses the same Brick and history. It does not
create a backlog of cloned tasks.

### Track a practice

```text
Swim twice per week
[x][x][x][-][x][x]

Skipping now will end a streak of 2. Continue?
```

Practice opportunities are recorded as `done`, `not_done`, or
`not_applicable`. A paused or blocked practice does not fabricate failure.
Repeated friction may propose a review to discover an enabling Brick or revise
the schedule.

### Inspect priority and forecast separately

```text
ant> /priority
# strict human importance tree

ant> /forecast
# weighted, explained, read-only candidates for next
```

### Review concise history

```text
ant> /history
ant> /history --brick <id> --family priority --relevance important
```

History queries are typed, composable, bounded, and paginated. Ordinary
history returns one concise summary per semantic action instead of dumping
complete event JSON into an agent context.

### Use the powered-up REPL

```sh
lant --power-up /path/to/claude-fast.sh
```

The executable is validated before the REPL starts, receives requests only via
stdin, and must return one bounded structured result. Powered-up mode can
propose translations, routes, comparisons, and pre-ordering; it cannot mutate
state directly or bypass confirmation.

```text
mode: powered up · by: /path/to/claude-fast.sh
```

Without it, the same interaction protocol runs in deterministic dumb mode.

See [interaction.allium](spec/little-ant/interaction.allium).

## Imports, Packs, and external effects

Little Ant Packs are the only 1.0 extension unit. Component kinds are closed:
behaviors, templates, import-profile presets, source adapters, enrichers,
read-only exporters, and UI adapters. There is no generic arbitrary plugin
hook.

Executable Pack components use a fresh bounded Lua 5.4 runtime. Host-mediated
HTTP, credentials, and approved effects are typed capabilities; Pack code
never runs during event replay.

The standard 1.0 Pack includes:

- Microsoft To Do source adapter;
- Notesnook source adapter;
- TaskJuggler read-only exporter;
- local Metro-style web UI adapter.

Normal synchronization treats upstream completion or removal as evidence, not
as local completion or deletion. Destructive migration is a separate reviewed
flow:

```sh
lant import microsoft-todo
lant import microsoft-todo --migrate --erase-after-import
```

`--erase-after-import` is valid only for migration. Every imported item must be
locally reconstructible and verified, and every external deletion is previewed,
approved, and receipted. Container deletion requires a separate approval.

See [integration.allium](spec/little-ant/integration.allium).

## Architecture

```text
human
  │
  ├── deterministic REPL
  ├── powered-up REPL
  ├── LLM skill/operator
  └── UI adapter
          │ canonical actions + revisions
          ▼
Little Ant core
  identity · event authority · ordering · recurrence · eligibility · replay
          │
          ├── rebuildable projections
          ├── canonical Raw blobs
          └── typed Pack boundaries
```

The core is deterministic and offline by default. AI output, provider data,
calendar observations, imports, and Pack results are attributed proposals or
evidence. Canonical mutations still pass through ordinary validated core
operations.

Operational state is reconstructed from an append-only event history.
Snapshots, indexes, databases, search structures, and rendered views are
rebuildable. Raw blob bytes are part of the logical dataset and must be backed
up with their metadata.

## Install

### Nix

```sh
nix profile install github:felipelalli/little-ant
nix run github:felipelalli/little-ant -- status
```

### Cabal

GHC 9.6 or newer is required.

```sh
git clone https://github.com/felipelalli/little-ant
cd little-ant
cabal install exe:la exe:lant
```

Both executable names refer to the same program. `lant` avoids the common
interactive-shell alias `la='ls -A'`.

## Development

Validate the complete Allium target:

```sh
allium check spec/little-ant.allium spec/little-ant
allium analyse spec/little-ant.allium spec/little-ant
```

Run the existing v0 tests:

```sh
cabal test little-ant-test
```

The generated 1.0 contract suite lives under `test-v1/`. It includes
high-level lifecycle tests and deterministic mini-simulations for ordering,
forecast, skip pressure, recurrence, and imports.

```sh
bash test-v1/generate-allium-artifacts.sh
LANT_V1_TEST_DRIVER=/path/to/lant-v1-test-driver \
  cabal test little-ant-v1-contract-test
```

See [the contract-test guide](test-v1/README.md) for the stdin protocol and
the intentionally red pre-implementation phase.

## What changed from v0 to v1

| v0 | v1 |
|---|---|
| `seed → committed → ready → wip` mixed commitment, readiness, and execution | A Brick is simply `active`, `done`, `dropped`, or `superseded`; WIP and optional phase are independent axes |
| Only frontier tasks were ordered | Every active Brick has one strict position among its siblings |
| Ordering asked whether one task came before another | Human priority asks which Brick is **more important**; uncertainty is retained instead of treated as equality |
| `next` and priority were easy to conflate | Human priority and the read-only forecast are explicit, separate views |
| IDs were derived from original titles | IDs are opaque and survive renames |
| Most captured items became full tasks | Raw remains material; lightweight ListEntries belong to checklist Bricks |
| Domain-specific behavior tended to emerge in operator policy | Closed generic behaviors plus inspectable templates cover projects, collections, checklists, repetition, obligations, and practices |
| Effort was a generic weight or direct hour estimate | Effort uses subjective comparable bands; hour ranges belong to a versioned planning profile |
| Recurrence was mostly future work | Repeatable work, recurring obligations, practice opportunities, streaks, and schedule revision have explicit history |
| JSON responses commonly exposed complete objects | Typed sparse projections, semantic history queries, and concise action summaries keep human and LLM context bounded |
| The agent skill was the main interactive harness | The deterministic one-key REPL, powered-up REPL, skill, CLI, and UI adapters share one revision-safe interaction protocol |
| Integrations were informal external policy | Typed Lua Packs, brokered credentials, reviewed imports, TaskJuggler export, and a local web UI have bounded contracts |
| Migration implied preserving old concepts and aliases | v0 is archived and semantically projected into a clean v1 model with an explicit identity map |

See [CHANGELOG.md](CHANGELOG.md) for the detailed release summary and migration
notes.

## Roadmap

### 1.1 — Bulk re-ordering as priority maintenance

**The gap.** A human priority order decays. People change their minds, work
changes shape, and evidence recorded months ago stops describing what the
person believes today. The 1.0 specification recognises this: chapter 8 of the
design record states that old evidence decays according to axis- and
event-specific policies, that priority should decay slowly, and that stale
evidence, reversals, and detected contradictions all reduce confidence.

But 1.0 offers no way to act on that signal. Binary insertion places one new
Brick into an already-ordered list in `log n` questions, which is the right
cost model for *placement* — the comparator is a human and every comparison is
a question. It cannot repair an order that has drifted, because it never
revisits pairs that were already settled. 1.0 therefore keeps the diagnosis and
drops the treatment.

**What v0 had.** `la order --sort` ran a resumable, faithful port of
`org-sort-tasks`' adapted merge sort (`src/LittleAnt/Order.hs`, introduced in
`b35df00`):

- insertion sort, walking backward from the end, for runs of up to 8 elements,
  because below that insertion asks fewer questions than merging;
- a merge that first probes whether two halves are already ordered relative to
  each other and concatenates them after a single question if they are;
- every already-known pair — recorded comparisons, dependencies, and their
  transitive closure — answered from the graph instead of being asked;
- statelessness across invocations by replay: each recorded answer extends the
  graph, the replay follows the same deterministic path and stops at the next
  unknown pair.

**Why that strategy specifically.** The merge short-circuit is what makes
periodic maintenance affordable. On a mostly-sorted list — which is exactly
what a drifted priority order is — the sort collapses to near-zero questions,
and the number of questions grows with how much the order actually moved rather
than with its length. A sort that ignored existing runs would ask `n log n`
questions of a human, which nobody answers.

**Status.** This capability exists in the v0 implementation and is documented
in `skills/little-ant/SKILL.md`, but it appears in neither
`spec/little-ant.allium` nor the 1.0 design record. It was lost in the
specification rewrite rather than deliberately removed, so 1.1 should
re-specify it as an explicit maintenance operation over a `PriorityScope`,
including when it should be offered, how its questions interact with skip
semantics and confidence, and how the resulting evidence is recorded.

### 1.1 — Other capabilities to recover from v0

The bulk re-ordering gap above prompted a sweep of the whole v0 command surface
against the 1.0 specification. The findings below are graded by how certain the
loss is; each names the v0 evidence so it can be re-verified.

| Capability | v0 evidence | 1.0 status |
|---|---|---|
| Bulk re-ordering (`la order --sort`) | `src/LittleAnt/Order.hs`, `b35df00` | absent — see above |
| Delegation follow-up cycle | `Types.hs` delegation states, `la nudge` | field kept, behaviour dropped |
| Flow strictness | `la flow open --strictness`, `floStrictness` | absent |
| Human-readable render formats | `la render --format org\|csv\|html-static` | unspecified |
| Interaction grammar command | `la grammar` | design record only, not normative |
| Explicit temporal tick | `la tick` | design record only, not normative |
| Merging two existing Bricks | `cmdUnify`, `la unify` | needs verification |

**Delegation follow-up cycle.** v0 modelled delegation as a lifecycle —
`DToNotify`, `DNotified`, `DNudged`, `DCompleted`, `DRefused`, `DAbandoned` —
carrying `dNudgeCount`, `dNextNudgeAt` and `dNudgePending`, with
`la nudge approve` to send a previewed follow-up and `la nudge decline` to skip
it and re-ask at the next interval. 1.0 keeps a `next_followup_at` field on the
delegation entity and accepts it in `DelegateBrick`, but only one rule
(`DelegationDrafted`) ever writes it, and nothing fires when it comes due.
Delegating therefore records an intention to follow up and then never follows
up. 1.1 should re-specify the due-follow-up trigger, the nudge counter, and the
approve/decline interaction.

**Flow strictness.** A v0 flow carried a strictness setting
(`la flow open --context C --strictness prefer`), stored on the flow and
exposed in its projection, which governed how hard the engine pushed the
declared context. The word does not appear anywhere in the 1.0 specification.
1.1 should decide whether context preference is a flow property, a selection
weight, or something the 1.0 model already expresses differently — and if the
last, say so explicitly instead of leaving it silently absent.

**Human-readable render formats.** v0 could project the truth as a table,
one-line summaries, a unified view, Org-mode, CSV, HTML and static HTML.
1.0 specifies a generic `ReadOnlyExporterContract`, typed sparse projections
and a loopback web UI, but names no concrete human-readable output format.
Org-mode output in particular is what let the tool feed an existing Emacs
workflow, which is where the ordering strategy came from in the first place.

**Interaction grammar and explicit tick.** `la grammar` printed the canonical
interaction grammar — namespaces, letters, markers — and `la tick` fired due
temporal rules explicitly (every other command auto-ticks). Both are discussed
in the 1.0 design record but neither appears in the normative Allium spec, so
neither is covered by a conformance obligation. This is a specification-coverage
gap rather than a lost capability: 1.1 should either specify them or state that
they are deliberately implementation-level affordances.

**Merging two existing Bricks.** v0's `la unify` superseded one Brick with
another and merged their lineage. 1.0 has duplicate suspicion and supersession,
but supersession is defined as replacing the method while keeping the goal,
which is not the same operation. This one needs verification against the
capture and material modules before being treated as a real gap.

**Not regressions.** Two v0 concepts are absent by design, and 1.1 should not
resurrect them. The priority *frontier* was deliberately replaced: 1.0 positions
every active Brick from birth, and chapter 21 of the design record explicitly
instructs the README to stop using the frontier-only model. The
*seed → committed* promotion step (`la promote`) was likewise restructured into
the Raw-to-Brick phase model.

**How this list was produced.** Every v0 sub-command in `app/Main.hs` was
extracted and each concept was searched across `spec/little-ant/*.allium` and
`spec/little-ant-1.0/*.md`. Absence of a word is not proof of absence of a
capability, since 1.0 renamed several concepts, so each zero-hit candidate was
checked by hand against the module that would own it. The sweep covered the CLI
surface only; the agent skill, REPL grammar and Pack surface deserve the same
treatment before 1.1 is scoped.

## Specification map

| Area | Authoritative file |
|---|---|
| Composition root and cross-module invariants | [little-ant.allium](spec/little-ant.allium) |
| Brick, ListEntry, behavior, template, identity | [domain.allium](spec/little-ant/domain.allium) |
| Raw, snapshots, shelves, links, provenance | [material.allium](spec/little-ant/material.allium) |
| Human priority, confidence, impact, effort | [judgment.allium](spec/little-ant/judgment.allium) |
| Lifecycle, WIP, dates, recurrence, practices | [execution.allium](spec/little-ant/execution.allium) |
| Forecast, next, proposals, duplicate suspicion | [selection.allium](spec/little-ant/selection.allium) |
| CLI/REPL protocol, sparse responses, history | [interaction.allium](spec/little-ant/interaction.allium) |
| Packs, imports, TaskJuggler, local web UI | [integration.allium](spec/little-ant/integration.allium) |
| Auditable v0 → v1 cutover | [migration-v0-v1.allium](spec/little-ant/migration-v0-v1.allium) |

## License

BSD-3-Clause. See [LICENSE](LICENSE).

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

The transcripts below use the shipped `lant` command surface. Other surfaces
preserve the same actions and revisions while adapting their presentation.

Every guided decision follows the same three-step protocol: open an
interaction, read its current envelope to see the offered action IDs, then
submit exactly one of them against the revisions the envelope reported. That
optimistic-concurrency loop is what keeps the CLI, the REPL, the skill and the
UI adapters on one identical set of actions.

### Capture a grocery item

```text
$ lant capture "Buy milk"
```

Duplicate suspicion runs before creation. Nothing is merged silently. When the
core cannot infer a route safely it opens a guided interaction rather than
guessing; a skill or powered-up adapter may make an attributed proposal.

### Insert work into human priority

```text
$ lant interaction open --kind priority_comparison
$ lant interaction current <INTERACTION_ID>

Is "Replace the laptop battery" more important than
"Read the storage design paper"?

$ lant interaction submit <INTERACTION_ID> <ACTION_ID> \
    --domain-revision N --interaction-revision N
```

Insertion uses binary comparison. Skipping never means “equally important.”
It can mean unresolved or “break the tie for me.” Nearby candidates are tried;
after the configured threshold, the Brick keeps a strict but provisional
position and gains future validation pressure.

### Ask what to do next

```text
$ lant status

Focus: "Replace the laptop battery"
Why: high human priority · available now · unlocks another Brick
```

`lant status` returns the one canonical status summary and `lant complete`
closes a Brick against an optimistic revision precondition. An open interaction
is dropped with `lant interaction abandon <INTERACTION_ID>`, which is a
different act from closing work. Direct completion is honest: it does not
invent a start time or a
zero-duration execution. A served-work skip records a reason and changes later
pressure; it does not imply completion.

### Read an article again later

```text
$ lant capture "https://example.com/paper"
Route: preserve as Raw, then create "Read the storage design paper"

...after reading...

Read it again in roughly six months?
schedule the same Brick with a jittered not-before date, or retire it
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
$ lant project --projection operational
# the working view: what is available, focused, and pressing

$ lant project --projection relationships
# structure: composition, dependencies, and delegation edges

$ lant project --projection complete <REFERENCE>
# everything the core holds about one entity
```

Strict human importance and the weighted forecast are separate concerns in the
model and never collapse into one ranked list. Purpose-bounded projections
return only what a caller asked for, so a projection request cannot become a
general-purpose data dump.

### Review concise history

```text
$ lant history
$ lant history --page-size 50 --cursor <REVISION_CURSOR>
$ lant history --brief
```

History queries are typed, composable, bounded, and paginated. Ordinary
history returns one concise summary per semantic action instead of dumping
complete event JSON into an agent context.

### Use the powered-up REPL

```sh
lant repl --power-up /path/to/claude-fast.sh
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
flow, distinguished by an explicit erase-after-import plan.

`--erase-after-import` is valid only for migration. Every imported item must be
locally reconstructible and verified, and every external deletion is previewed,
approved, and receipted. Container deletion requires a separate approval.

Import and synchronization are enforced in `LittleAnt.V1.SourceImport`. The
1.0 command surface does not yet expose a `lant import` entry point; the flow
is reachable through the Pack source adapters.

See [integration.allium](spec/little-ant/integration.allium).

### Safe v0-to-1.0 cutover

The 1.0 cutover reads and hashes an immutable v0 archive, projects a clean v1
event log with explicit opaque identity mappings, verifies entity, evidence,
and identity coverage, and only then atomically switches the active dataset.
The checked-in `fixtures/v0-v1-atomic-cutover.jsonl` is wholly synthetic and
covers mixed entity kinds, terminal and delegated work, recurrence, and a
same-title collision. It contains no personal event-log data.

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

The implemented `lant-v1-test-driver` executable runs the generated plans and
16 end-to-end scenarios. The progress runner requires one unique, well-formed
result per target and reports full conformance as `TOTAL 1566/1566`.

```sh
cabal build all --ghc-options=-Werror
python3 tools/v1-progress.py
bash tools/probe-mutation-check.sh --verify-audit tools/probe-audit.md
bash tools/story-gate.sh
```

`tools/story-gate.sh` is the complete release path: it runs the v0 and driver
tests, checks the monotonic `1566/1566` baseline, validates and reruns the
30-obligation behavior mutation audit, and then runs `cabal test all`.
Regenerate checked-in Allium artifacts only after an authoritative spec change:

```sh
bash test-v1/generate-allium-artifacts.sh
```

See [the contract-test guide](test-v1/README.md) for the executable stdin
protocol, exact-result validation, synthetic cutover fixture, and mutation
audit workflow.

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

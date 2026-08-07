# Little Ant 🐜🧱

[![CI](https://github.com/felipelalli/little-ant/actions/workflows/ci.yml/badge.svg)](https://github.com/felipelalli/little-ant/actions/workflows/ci.yml)

<p align="center">
  <img src="assets/littleant.png" alt="A little ant carrying a brick" width="220">
</p>

> *One brick at a time. Inch by inch, anything's a cinch.*

Little Ant is a personal focus engine. It feeds unfinished material into an
inspectable system, keeps work in a human-defined importance order, and helps
answer one practical question:

> **Where should I focus now?**

It is designed around a deterministic, inspectable core. Humans and optional
operators provide judgment; the core owns identity, history, ordering
mechanics, validation, recurrence, eligibility, and replay.

Little Ant 1.0 is currently defined by the reviewed
[1.0 specification](spec/little-ant-1.0.md). The old implementation, Allium
files, and generated tests are not current product authority; the 1.0
implementation starts from this greenfield behavioral baseline.

The maintained [v0→1.0 capability matrix](spec/little-ant-1.0/v0-v1-capability-matrix.md)
prevents accidental regressions, while the finite
[specification completion record](spec/little-ant-1.0/spec-completion-plan.md)
shows how the UX-first contract reached its final audit.

The core has one unambiguous command vocabulary and no compatibility aliases.
A skill or operator may translate natural language into those canonical
commands.

## The model

### Raw

`Raw` is the general durable content record, not work: a Brick description,
URL, note, pasted conversation, brainstorm, file, source snapshot, attachment,
or imported object. Linking or routing a Raw never consumes it.

Every accepted `feed` creates Raw material immediately. Untriaged Raw appears
in a derived Inbox and is organized later through ordinary weighted review;
feeding never begins with a metadata form.

Raw material:

- is never ordered by importance, focused, started, or completed;
- preserves its original representation and attributed provenance;
- may keep an attributed canonical English normalization on the same Raw;
- may live on one or more flat shelves;
- may be linked to a Brick, ListEntry, or Raw as description, source,
  evidence, attachment, or another typed role;
- is archived rather than permanently deleted.

A Brick does not own a separate scalar description field or a special
Description object. Its visible description is the projection of one ordinary
Raw linked with role `description`. A Brick has at most one such active link,
and that role is exclusive to one Brick; reusable supporting material uses
another link role. Detaching the description never deletes the Raw.

Editing a description appends a revision to that same Raw identity. Previous
revisions remain in history, and any canonical-English normalization becomes
explicitly stale until `/translate` reviews it. Translating content never
creates a second Raw: original and canonical-English forms remain
distinguishable on the same identity.

See [concepts and identity](spec/little-ant-1.0/02-concepts-identity-and-hierarchy.md)
and [feeding and organization](spec/little-ant-1.0/03-feeding-and-organization.md).

### Brick

`Brick` is the single work abstraction. A Brick may be an atomic task, a
project, a living checklist, a collection, a repeatable activity, a recurring
obligation, a habit, or a scheduled commitment.

Its lifecycle is deliberately small:

```text
active ──▶ done
   ├─────▶ archived
   ├─────▶ superseded
   └─────▶ merged
```

Only a scheduled commitment may instead end as `missed` or `cancelled`; those
statuses record the truth of its anchored interval rather than inventing a
generic failure state.

`archived` means that the Work is no longer being pursued without claiming it
was completed. It remains searchable, reversible, and eligible for one lazy
relevance review; it is not ordinary executable Work while archived.

`seed`, `committed`, and `ready` do not exist in 1.0. Commitment is inferred
from position in the human importance tree: higher means more important.

Optional phase is a separate axis:

```text
idea · spec · execution · validation
```

Phase does not determine importance, completion, or WIP. Natures may disable
phase or effort when those concepts would only add noise.

Every durable record has an immutable internal UUIDv7 identity. Bricks use a
separate mnemonic human handle such as `#rs "Rock Splitter"`; Raw uses `+`,
such as `+milk "milk"`; and people or companies use `@`, such as
`@am "Alice Moreira"`. Handles are searchable, survive ordinary title,
content, and name changes, and never replace UUIDs inside relationships or
events. Typing `#`, `+`, or `@` opens the corresponding autocomplete, so users
do not need to memorize technical identifiers. English is the canonical target
for searchable Brick titles, but dumb mode accepts any language. Explicit
`/translate` can review all active titles rather than guessing their language.

See [concepts and identity](spec/little-ant-1.0/02-concepts-identity-and-hierarchy.md)
and [work, time, and adaptation](spec/little-ant-1.0/06-work-time-and-adaptation.md).

### ListEntry

A `ListEntry` is a lightweight item owned by a checklist Brick, such as
“Milk” under “Buy groceries.” It has no independent importance, phase, effort,
WIP, or `next` eligibility. The owning Brick remains the focus unit and may
render all open entries together.

This avoids turning every grocery item, trip-checklist item, or similar entry
into a full task.

### Natures and templates

Natures are small, closed combinations of capabilities understood by the
core. Templates are inspectable recipes that select a Nature and optional
defaults; they do not inject hidden domain logic.

The 1.0 catalog includes generic Natures for atomic tasks, projects,
collections, repeatable work, finite and living checklists, recurring
obligations, habits, and scheduled commitments. Standard templates include:

- grocery and trip checklists;
- reading lists and repeatable article reading;
- software feature backlogs and wishlists;
- bills to pay;
- exercise habits.

Users may publish versioned personal Natures and templates from the same
closed capability vocabulary.

## Two views, two different questions

Little Ant intentionally has two list-like projections:

| View | Question answered | Authority |
|---|---|---|
| **Importance order** | “What is more important?” | Strict sibling order settled by human judgment |
| **Forecast / next** | “What is useful and eligible now?” | Read-only deterministic forecast plus replay-safe draw |

Importance order is a persistent tree. Within each sibling scope, every active
Brick has exactly one strict position. A global view is the lexicographic
composition of those local paths.

Forecast does not rewrite importance. It may consider current focus, inherited
dates and context, phase when applicable, dependencies, waits, place
conditions, cooldowns, recurrence opportunities, unresolved reviews, and
pressure accumulated from skips.

See [importance and judgment](spec/little-ant-1.0/04-importance-and-judgment.md)
and [focus forecast and selection](spec/little-ant-1.0/05-focus-forecast-and-selection.md).
The exact fixed-point confidence, long-tail curve, signal combination, and
replay-safe sampling contract is the
[deterministic calculation profile](spec/little-ant-1.0/deterministic-calculation-profile.md).

## Common flows

The transcripts below use the canonical terminal interaction. Other surfaces
preserve the same actions and revisions while adapting their presentation.

### Feed a grocery item

```text
$ lant
› /feed

Feed Little Ant

Tip: prefer English for consistent titles and search.

› milk
```

Enter saves one Raw immediately. A later triage opportunity may ask:

```text
Review raw material

"milk"

Is this something you could work on by itself?

[y]es    [n]o    [s]kip    [?] I don't know
```

After `no`, compatible existing destinations are ranked:

```text
Does "milk" belong with any of these?

*[1] #bg "Buy groceries"
     living checklist

 [m]ore matches...
 [s]earch...
 [c]reate a new group...
[?] I don't know
```

`more matches` pages additional existing targets; `search` autocompletes across
all compatible existing destinations; and `create a new group` asks whether
the result should behave as a list, Raw shelf, or independently focusable Work
container. `Group` is only interface language, never a core object. Duplicate
review distinguishes keeping an existing list item, adding quantity, changing
quantity, reopening a resolved item, and creating a separate distinguishable
item. Nothing is merged or incremented silently. Powered-up mode or a Skill
may propose routing several recent Raws such as `milk`, `coffee`, and `bread`,
but requires the same explicit consent.

### Insert work into importance order

```text
Is

#rtlb "Replace the laptop battery"

    more important than

#rtsdp "Read the storage design paper"
?

[m]ore important   [l]ess important   [s]kip   [?] I don't know
```

Insertion uses binary comparison. `skip` never means “equally important.”
It can mean unresolved or “break the tie for me.” Nearby candidates are tried;
after the configured threshold, the Brick keeps a strict but provisional
position and gains future validation pressure.

### Ask what to do next

```text
› /next

Work:

#rtlb "Replace the laptop battery"

Focus?

[y]es    [s]kip    [?] I don't know
[/] more...
```

After `yes`, the resting focus screen is deliberately smaller:

```text
Current focus:

#rtlb "Replace the laptop battery"

[d]one    [s]kip    [/] more...
```

Direct `done` is honest: it records completion without inventing a start time
or zero-duration execution. A served-work skip records a reason and changes
later pressure; it does not imply completion.

### Archive Work that has lost its meaning

From the served Work screen, press `[s]kip`, then choose `o[u]t of date`:

```text
What does "out of date" mean here?

[a]rchive it
    It no longer seems worth pursuing; review that decision later.

[r]eplaced by newer Work
    Preserve the relationship by superseding it.

[u]pdate it
    The intention remains, but its content or structure is stale.

[s]kip anyway
[?] I don't know
```

Archive removes the Brick from active Work without claiming completion and
creates one low-pressure relevance review. That later review may keep it
archived, restore the same identity, update and restore it, or link newer Work
as its replacement. `/undo` can compensate the original archive immediately;
later restoration is a new recorded action rather than deleted history.

`/update #brick` opens the same semantic maintenance hub directly, without
requiring a skip or recording `out_of_date`. The stale-work choices `update
it` and `update and restore` also enter this hub, but retain their own atomic
stale-evidence and restoration consequences. It asks what you want to update
rather than exposing an arbitrary field editor:

```text
[m]eaning          Title or description.
[b]ehavior         Task, checklist, habit, recurrence, or similar behavior.
[p]lan             Parts, prerequisites, waits, or delegation.
[t]iming           When it may start, should happen, or repeat.
[c]ontext          Domains, people or companies, and related Work.
[s]ource material  Linked Raw material or external sources.
[v]iew everything  Inspect without changing anything.
[?] I don't know
```

Each branch invokes a typed canonical operation with its own preview. One
accepted change produces one history and undo boundary; `update something
else` returns to the same hub instead of accumulating an unbounded generic
patch. Powered-up mode or a Skill may mark one likely branch and explain why,
but cannot mutate or bypass its normal preview.

`plan` is only the human-facing route to parts, prerequisites, waits, and
delegation. It is not a Plan entity, phase, or classification axis. `/update`
is the sole general maintenance command; there are no overlapping `/edit` or
`/plan` aliases. Its blocker route reuses the same plain-language prerequisite
questions as skip diagnosis, but omits `skip anyway` and records no skip
evidence or cooldown of its own. Any stale-update or restoration consequence
still belongs atomically to the hub's original entry path.

Structure stays intent-first across every Nature: move the Brick within larger
Work, organize independently tracked child parts, or manage list items shown
together. All three intentions remain discoverable. If the current Nature
cannot represent the selected structure, Little Ant previews the necessary
Nature change and reconciliation instead of hiding the choice or converting
state silently.

Composition and Domains remain independent. Domain memberships are explicit
and direct; a parent may inform a visible suggestion but never grants
membership. Moving Work preserves its Domains. When the new parent has a
different Domain path set, dumb mode shows the exact structural contrast and
offers either to keep the current memberships or edit them before one combined
preview. Only powered-up mode or a Skill may add a semantic recommendation.
The parent selector searches complete Brick handles and titles, includes
`<root>`, and can draft `New larger Work...` inside the same atomic move; a
cancelled move never leaves an orphan parent.

Within `meaning`, title and description are independent choices. Renaming
preserves the Brick UUID, `#handle`, hierarchy, order, relationships,
lifecycle, and focus; the former title remains history but does not become an
alias. Description editing revises the ordinary Raw attached with role
`description`, or atomically creates that Raw and link when absent. The exact
multiline editor uses Enter for a newline, `Ctrl-D` to review, and a protected
Escape path for an altered draft. Empty text reaches an explicit removal
preview rather than deleting or detaching anything immediately.

Within `behavior`, the only mutable classification is Nature. Schedules remain
under `timing`, structure remains under `plan`, and a Template remains
inspectable creation provenance rather than live behavior. A Nature change
preserves identity and history, gathers any target-required configuration, and
cannot proceed until incompatible active state has an explicit reconciliation.

In the terminal editor, `Ctrl-X Ctrl-E` may hand the same pending text to a
configured external editor. Little Ant imports the result back into its normal
preview; the external program never commits a Raw revision or bypasses human
confirmation.

### Read an article again later

```text
› /feed https://example.com/paper
Raw material saved to Inbox.

...during later triage...

Create Work: "Read the storage design paper"

...after reading...

What should happen next?
[s]et a return... — configure 6 months with ±3 months variation
[m]anual only    — keep the same Brick available only through explicit focus
[a]rchive        — archive the standing Brick
[?] I don't know
```

The return preview resolves to one replay-stable absolute `not_before`.
Completion-triggered repetition reuses the same Brick and history; it does not
create a backlog of cloned tasks.

### Track a habit

```text
Swim twice per week
[x][x][x][-][x][x]

Skipping now will end a streak of 2. Continue?
```

Habit opportunities are recorded as `done` or `unfulfilled`. `blocked`,
`paused`, and `inapplicable` remain distinct and do not fabricate failure.
Repeated friction may propose a review to discover an enabling Brick or revise
the schedule.

### Inspect importance and forecast separately

```text
› /list

List:

[i]mportance order
    The strict sibling tree settled by human judgment.

[f]ocus forecast
    Current chances and reasons used by next.

[?] I don't know
```

There is no `/forecast` or `/importance` alias. The single `/list` command
keeps the distinction visible without creating overlapping vocabulary.

### Review concise history

```text
› /history
› /history --brick #rtlb
```

History queries are typed, composable, bounded, and paginated. Ordinary
history returns one concise summary per semantic action instead of dumping
complete event JSON into an agent context.

### Search globally without losing the current screen

```text
› /search milk
```

`/search` is available from every ordinary interaction. In the REPL,
`Ctrl-F` opens the same type-visible search across Bricks, Raw, list items,
people or companies, Domains, and Raw shelves. Escape returns to the exact
pending screen, including an unfinished draft. Selecting a global result only
inspects it; contextual selectors use their own narrower searches. Event
history remains under `/history`, and the core intentionally has no `/find`
alias.

### Use the powered-up REPL

```sh
lant --power-up /path/to/claude-fast.sh
```

The executable is validated before the REPL starts, receives requests only via
stdin, and must return one bounded structured result. Powered-up mode can
propose translations, Raw dispositions, recent-Feed batches, comparisons, and
pre-ordering; it cannot delay Feed persistence, mutate state directly, or
bypass confirmation.

```text
mode: powered up · by: /path/to/claude-fast.sh
```

Without it, the same interaction protocol runs in deterministic dumb mode.

See [interaction and surfaces](spec/little-ant-1.0/07-interaction-and-surface-contract.md).

## Imports, Packs, and external effects

Little Ant Packs are the only 1.0 extension unit. Component kinds are closed:
Natures, templates, import-profile presets, source adapters, enrichers,
read-only exporters, and UI adapters. There is no generic arbitrary plugin
hook.

Executable Pack components use a fresh bounded Lua 5.4 runtime. Host-mediated
HTTP, credentials, and approved effects are typed capabilities; Pack code
never runs during event replay.

The offline standard Pack includes file importers for Markdown, HTML, JSON,
CSV, Org, Evernote ENEX, Notesnook exports, Apple Reminders Shortcut JSON, and
TaskJuggler actuals; structural and TaskJuggler exporters; factory content; and
the loopback-only `local_web` UI adapter.

The separately installed, pinned official connector Pack includes Microsoft
To Do, Google Tasks, Google Calendar, and GitHub Issues. Each source advertises
its honest modes: file exports do not pretend to offer live sync, and sources
without deletion do not accept destructive cleanup. See the exact
[integration catalog](spec/little-ant-1.0/standard-integration-catalog.md).

Packs are immutable, content-addressed, reproducible, and Ed25519-signed.
There are no cross-Pack dependencies, install scripts, or automatic updates.
Every install/update previews signer trust, components, permissions, and
affected bindings; known revocations disable code without deleting Little Ant
data. See [Pack format and trust](spec/little-ant-1.0/pack-format-and-trust.md).

Normal synchronization treats upstream completion or removal as evidence, not
as local completion or deletion. Destructive migration is a separate reviewed
flow:

```sh
lant import microsoft-todo
lant import microsoft-todo --migrate --erase-after-import
```

`--erase-after-import` is valid only for a migration adapter that declares
cleanup support. It never deletes during import: every item is locally
reconstructible and verified first, then the exact external deletion set is
previewed, approved, and receipted. Container deletion requires a separate
approval.

Migrating the Little Ant v0 archive itself is a separate three-step local
protocol. The harmless default only verifies and reports:

```sh
lant migrate --from ~/archive/lant-v0/events.jsonl --into ~/.local/share/little-ant/profiles/default
lant migrate --build <plan>
lant migrate --cutover <candidate>
```

Build writes an isolated candidate; cutover presents a final exact consent,
retains the previous target as a backup, preserves the v0 archive, and never
runs legacy effects. See the [migration contract](spec/little-ant-1.0/09-migration-and-release-contract.md).

See [data, integrations, and extensions](spec/little-ant-1.0/08-data-integrations-and-extension-boundary.md).

The complete, alias-free public vocabulary is in the
[canonical command catalog](spec/little-ant-1.0/command-catalog.md).

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

The `v1` branch currently contains the frozen implementation contract, not an
installable 1.0 binary. The implementation phase will restore Nix and Cabal
instructions only after they are executable and verified. The sole canonical
executable name is `lant`; 1.0 will not install an `la` compatibility alias.

## Development

Little Ant 1.0 is a greenfield implementation target. The current authority is
the [reviewed specification](spec/little-ant-1.0.md), including its
[UX simulations](spec/little-ant-1.0/ux/01-synthetic-week.md). Fresh Allium
obligations and tests must be generated only after the behavioral and UX
baseline is accepted; removed v0 code, Allium, and generated tests are
historical evidence, not implementation guidance.

## What changed from v0 to v1

| v0 | v1 |
|---|---|
| `seed → committed → ready → wip` mixed commitment, readiness, and execution | A Brick is simply `active`, `done`, `archived`, `superseded`, or `merged`; only scheduled commitments add `missed`/`cancelled`, while WIP and optional phase are independent axes |
| Only frontier tasks were ordered | Every active Brick has one strict position among its siblings |
| Ordering asked whether one task came before another | Importance ordering asks which Brick is **more important**; uncertainty is retained instead of treated as equality |
| `next` and priority were easy to conflate | Importance order and the read-only focus forecast are explicit, separate views |
| IDs were derived from original titles | IDs are opaque and survive renames |
| Most fed items became full tasks | Every Feed becomes Inbox Raw first; lazy triage may later create linked Work or lightweight checklist entries |
| Domain-specific mechanics tended to emerge in operator policy | Closed generic Natures plus inspectable templates cover projects, collections, checklists, repetition, obligations, and habits |
| Effort was a generic weight or direct hour estimate | Effort uses subjective comparable bands; hour ranges belong to a versioned planning profile |
| Recurrence was mostly future work | Repeatable work, recurring obligations, habit opportunities, streaks, and schedule revision have explicit history |
| JSON responses commonly exposed complete objects | Typed sparse projections, semantic history queries, and concise action summaries keep human and LLM context bounded |
| The agent skill was the main interactive harness | The deterministic one-key REPL, powered-up REPL, skill, CLI, and UI adapters share one revision-safe interaction protocol |
| Integrations were informal external policy | Typed Lua Packs, brokered credentials, reviewed imports, TaskJuggler export, and a local web UI have bounded contracts |
| Migration implied preserving old concepts and aliases | v0 is archived and semantically projected into a clean v1 model with an explicit identity map |

See [CHANGELOG.md](CHANGELOG.md) for the detailed release summary and migration
notes.

## Specification map

| Subject | Current specification |
|---|---|
| Product language and scope | [Chapter 1](spec/little-ant-1.0/01-product-language-and-scope.md) |
| Brick, ListEntry, Nature, template, identity | [Chapter 2](spec/little-ant-1.0/02-concepts-identity-and-hierarchy.md) |
| Raw, feeding, duplicate suspicion, Domain classification | [Chapter 3](spec/little-ant-1.0/03-feeding-and-organization.md) |
| Importance, confidence, impact, effort | [Chapter 4](spec/little-ant-1.0/04-importance-and-judgment.md) |
| Forecast, next, blockers, Domain continuity | [Chapter 5](spec/little-ant-1.0/05-focus-forecast-and-selection.md) |
| Lifecycle, WIP, dates, recurrence, habits | [Chapter 6](spec/little-ant-1.0/06-work-time-and-adaptation.md) |
| CLI/REPL protocol, sparse responses, history | [Chapter 7](spec/little-ant-1.0/07-interaction-and-surface-contract.md) |
| Packs, imports, TaskJuggler, local web UI | [Chapter 8](spec/little-ant-1.0/08-data-integrations-and-extension-boundary.md) |
| Auditable v0 → v1 cutover | [Chapter 9](spec/little-ant-1.0/09-migration-and-release-contract.md) |

## License

BSD-3-Clause. See [LICENSE](LICENSE).

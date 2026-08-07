# Changelog

All notable user-visible changes to Little Ant are documented here.

The reviewed [1.0 specification](spec/little-ant-1.0.md) is authoritative.
Removed implementation, Allium, and generated-test artifacts are historical
evidence only. This changelog summarizes the intended release; it does not
replace the specification.

## 1.0.0

Little Ant 1.0 replaces the v0 lifecycle with a smaller Brick model, makes
human importance order the organizing spine of the system, and introduces a
deterministic REPL, typed history, recurrence, and bounded extension Packs.

### Breaking changes

- Removed the `seed`, `committed`, and `ready` Brick stages.
- Removed title-derived identity. Brick, Raw, ExternalEntity, and ListEntry IDs
  are now opaque and remain stable across renames.
- Removed core compatibility aliases. Operators may interpret natural
  language, but the core exposes one canonical English command vocabulary.
- Changed the ordering question from “Does X come before Y?” to “Is X more
  important than Y?”
- Separated human importance order from the `next` forecast. Forecast results
  never rewrite the importance tree.
- Split work, material, and checklist occurrences into `Brick`, `Raw`, and
  `ListEntry` instead of treating all fed content as task-shaped.
- Replaced generic effort weight and direct hour promises with comparable
  effort bands backed by versioned planning profiles.
- Replaced generic extension hooks with closed, typed Little Ant Pack
  component kinds.

### Added

#### Human importance and judgment

- Strict sibling importance order for every active Brick.
- Binary insertion for newly fed or moved Bricks.
- Nearby replay-safe comparison selection after an unresolved answer.
- Explicit `unresolved` and `tie_break_for_me` skip meanings; neither means
  equal importance.
- Provisional placement, confidence explanations, contradiction detection, and
  local recalibration.
- Provocative validation probes for direct checks of transitive importance,
  impact, and effort evidence.
- Root-scoped impact classes with maturity and attributed evidence.
- Comparable effort bands with optimistic, realistic, and pessimistic planning
  ranges.

#### Work model

- Independent Brick lifecycle, optional phase, and WIP state.
- Composition trees with explicit parentage, direct Domain memberships, and
  separately typed temporal constraints; hierarchy does not invent inherited
  classification.
- Explicit subtree move, completion, archive, merge, and supersede operations.
- Natures for atomic tasks, projects, collections, finite and living
  checklists, repeatable work, recurring obligations, habits, and scheduled
  commitments.
- Versioned factory and personal templates.
- Structured checklist entries that remain subordinate to their owner Brick.
- Direct completion without fabricated execution history.

#### Recurrence and habits

- Completion-triggered repetition on the same Brick with a jittered
  `not_before`.
- Recurring obligation occurrences with stable period identities.
- Habit opportunities recorded as `done` or `unfulfilled`, with `blocked`,
  `paused`, and `inapplicable` kept distinct.
- Derived streak history that does not count paused or blocked periods as
  failures.
- Schedule and timezone revisions that preserve prior occurrence history.

#### Selection and feeding

- Read-only, explainable forecast with replay-safe weighted `next` draws.
- Separate importance and forecast projections.
- Proposal pressure for unresolved importance, stale focus, source
  reconciliation, repeated habit friction, approvals, and reviews.
- Zero-toll Feed: every accepted submission immediately becomes preserved Raw
  in a derived Inbox; routing and classification happen later through weighted
  triage rather than an ingress metadata form.
- Dumb Raw triage that distinguishes independently suggestible Work from
  ranked compatible checklists, RawShelves, and Bricks without presenting one
  abstract ontology form.
- Contextual destination ranking from inspectable mechanics, focus/Domain,
  recency, accepted destinations, lexical evidence, and recent-Feed locality;
  assisted modes may add attributed semantic and bounded batch proposals.
- Deterministic layered duplicate suspicion with explicit reuse, attachment,
  owner-scoped ListEntry reopening, quantity changes, or distinguishable
  separate decisions.
- Investigation-Brick proposals for decision-relevant uncertainty.

#### Raw material and provenance

- Immutable Raw snapshots backed by a content-addressed blob-store contract.
- Flat Raw shelves.
- A derived Inbox for active Raw without an accepted triage disposition; it is
  not a shelf, Domain, Nature, or parent.
- Source, evidence, attachment, and derived-from links.
- Brick descriptions represented as linked Raw content rather than a separate
  scalar field.
- Attributed canonical English alongside verbatim original content on the same
  Raw identity.
- Explicit missing and corrupt snapshot states.
- Archive and restore without permanent Raw deletion.

#### Interaction

- One-key REPL choices without requiring Enter.
- `/` command palette and contextual `?` help.
- Revision-scoped interactions that reject stale keypresses.
- Deterministic dumb mode and validated powered-up mode.
- Stdin-only powered-up model requests with bounded structured output.
- Typed sparse command responses and explicit complete projections.
- Typed, composable, paginated history queries.
- One concise history summary per semantic action, with event-level
  drill-down.
- Typed `@ExternalEntity` and `#Brick` annotations without implicit behavioral
  effects.

#### Integrations and Packs

- Closed Pack components for Natures, templates, import-profile presets,
  source adapters, read-only exporters, and UI adapters. Raw revision and
  derivation stay inside typed source and assisted-proposal flows rather than
  a generic executable content hook.
- Fresh bounded Lua 5.4 execution through HsLua.
- Host-mediated HTTP and credential brokering without exposing secrets to Lua.
- Pinned Pack manifests, capability grants, and invocation provenance.
- Offline file adapters for Markdown, HTML, JSON, CSV, Org, Evernote ENEX,
  Notesnook exports, and Apple Reminders Shortcut JSON, plus a separately
  installed official connector Pack for Microsoft To Do, Google Tasks, Google
  Calendar, and GitHub Issues.
- TaskJuggler exporter with immutable planning manifests and separate imported
  actuals.
- Loopback-only local web UI adapter using the canonical screen grammar.
- Safe synchronization where upstream completion or removal is evidence, not
  an automatic local state change.
- Reviewed migration cleanup with item-level previews, approvals, retries, and
  receipts.

### Changed

- English is the canonical target for searchable work titles and product
  vocabulary. Dumb title input remains non-blocking; explicit `/translate`
  can review all active titles without hidden language classification, while
  original Raw input stays verbatim and attributed.
- Phase is now optional (`idea`, `spec`, `execution`, or `validation`) and may
  be disabled by Nature.
- Done, archive, merge, and supersede are distinct terminal outcomes; only a
  scheduled commitment may instead end as missed or cancelled.
- `next` considers eligibility, focus, dates, dependencies, places, recurrence,
  pressure, and reviews while treating importance as one contribution.
- External reads and writes are explicit. Ordinary rendering performs no
  hidden I/O, and external mutations always require approved effects.
- Operational projections are rebuildable from canonical events and required
  Raw blobs.

### Migration from v0

- The v0 source is archived and hash-verified before any v1 activation.
- Migration folds v0 history into a clean semantic v1 projection rather than
  replaying obsolete event kinds forever.
- Former `seed`, `committed`, and `ready` work becomes active, positioned
  Bricks; former WIP also retains independent WIP state.
- Every migrated title-derived ID maps to a new opaque ID through an explicit
  audit record.
- Useful descriptions, old precedence comparisons, dependencies, waits,
  delegation, provenance, execution facts, and timestamps are retained as
  evidence; old before/after answers never become v1 importance judgments.
- Preflight is read-only, candidate construction is isolated and replayed, and
  cutover is a separate atomic consent that retains the prior target backup and
  never runs legacy effects.

See [the migration and release contract](spec/little-ant-1.0/09-migration-and-release-contract.md)
for the complete cutover contract.

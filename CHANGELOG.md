# Changelog

All notable user-visible changes to Little Ant are documented here.

The authoritative behavioral definition remains the composed
[Allium specification](spec/little-ant.allium). This changelog summarizes that
contract; it does not replace it.

## 1.0.0

Little Ant 1.0 replaces the v0 lifecycle with a smaller Brick model, makes
human importance order the organizing spine of the system, and introduces a
deterministic REPL, typed history, recurrence, and bounded extension Packs.

### Breaking changes

- Removed the `seed`, `committed`, and `ready` Brick stages.
- Removed title-derived identity. Brick, Raw, Party, and ListEntry IDs are now
  opaque and remain stable across renames.
- Removed core compatibility aliases. Operators may interpret natural
  language, but the core exposes one canonical English command vocabulary.
- Changed the ordering question from “Does X come before Y?” to “Is X more
  important than Y?”
- Separated human priority from the `next` forecast. Forecast results never
  rewrite the priority tree.
- Split work, material, and checklist occurrences into `Brick`, `Raw`, and
  `ListEntry` instead of treating all captured content as task-shaped.
- Replaced generic effort weight and direct hour promises with comparable
  effort bands backed by versioned planning profiles.
- Replaced generic extension hooks with closed, typed Little Ant Pack
  component kinds.

### Added

#### Human priority and judgment

- Strict sibling importance order for every active Brick.
- Binary insertion for newly captured or moved Bricks.
- Nearby replay-safe comparison selection after an unresolved answer.
- Explicit `unresolved` and `tie_break_for_me` skip meanings; neither means
  equal importance.
- Provisional placement, confidence explanations, contradiction detection, and
  local recalibration.
- Provocative validation probes for direct checks of transitive priority,
  impact, and effort evidence.
- Root-scoped impact classes with maturity and attributed evidence.
- Comparable effort bands with optimistic, realistic, and pessimistic planning
  ranges.

#### Work model

- Independent Brick lifecycle, optional phase, and WIP state.
- Composition trees with inherited context, mode, and date constraints.
- Explicit subtree move, complete, drop, and supersede operations.
- Behaviors for standard work, projects, collections, checklists, repeatable
  work, recurring obligations, and practices.
- Versioned factory and personal templates.
- Structured checklist entries that remain subordinate to their owner Brick.
- Direct completion without fabricated execution history.

#### Recurrence and habits

- Completion-triggered repetition on the same Brick with a jittered
  `not_before`.
- Recurring obligation occurrences with stable period identities.
- Practice opportunities recorded as `done`, `not_done`, or
  `not_applicable`.
- Derived streak history that does not count paused or blocked periods as
  failures.
- Schedule and timezone revisions that preserve prior occurrence history.
- Event-triggered opportunities with replay-safe source-event identities.

#### Selection and capture

- Read-only, explainable forecast with replay-safe weighted `next` draws.
- Separate priority and forecast projections.
- Proposal pressure for unresolved priority, stale focus, source
  reconciliation, repeated practice friction, approvals, and reviews.
- Capture intents with explicit routes to Raw, Brick, ListEntry, template
  instantiation, or enrichment of an existing target.
- Deterministic layered duplicate suspicion with explicit reuse, enrich, or
  separate decisions.
- Investigation-Brick proposals for decision-relevant uncertainty.

#### Raw material and provenance

- Immutable Raw snapshots backed by a content-addressed blob-store contract.
- Flat Raw shelves.
- Source, evidence, attachment, and derived-from links.
- Attributed canonical English alongside verbatim original content.
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
- Typed `@Party` and `#Brick` annotations without implicit behavioral effects.

#### Integrations and Packs

- Closed Pack components for behaviors, templates, import-profile presets,
  source adapters, enrichers, read-only exporters, and UI adapters.
- Fresh bounded Lua 5.4 execution through HsLua.
- Host-mediated HTTP and credential brokering without exposing secrets to Lua.
- Pinned Pack manifests, capability grants, and invocation provenance.
- Microsoft To Do and Notesnook source adapters in the standard Pack.
- TaskJuggler exporter with immutable planning manifests and separate imported
  actuals.
- Loopback-only Metro-style local web UI adapter.
- Safe synchronization where upstream completion or removal is evidence, not
  an automatic local state change.
- Reviewed migration cleanup with item-level previews, approvals, retries, and
  receipts.

### Changed

- Canonical searchable work titles and product vocabulary are English, while
  original input remains verbatim and attributed.
- Phase is now optional (`idea`, `spec`, `exec`, or `validation`) and may be
  disabled by behavior.
- “Done,” “drop,” and “supersede” are distinct terminal outcomes.
- `next` considers eligibility, focus, dates, dependencies, places, recurrence,
  pressure, and reviews while treating priority as one contribution.
- External reads and writes are explicit. Ordinary rendering performs no
  hidden I/O, and external mutations always require approved effects.
- Operational projections are rebuildable from canonical events and required
  Raw blobs.

### Release verification

- Shipped the executable `lant-v1-test-driver` implementation bridge for all
  generated plans and the 16 end-to-end scenarios.
- Completed all 1,446 Allium plan obligations and 120 scenario assertions;
  `python3 tools/v1-progress.py` reports `TOTAL 1566/1566`.
- Added `tools/probe-mutation-check.sh`, a repeatable 30-obligation sample
  across all nine modules that mutates production behavior one target at a
  time and requires the exact green probe to turn red.
- Made `bash tools/story-gate.sh` the final release gate for the Werror build,
  v0 and v1 tests, monotonic conformance baseline, mutation audit, and full
  `cabal test all` suite.

### Migration from v0

- The v0 source is archived and hash-verified before any v1 activation.
- Migration folds v0 history into a clean semantic v1 projection rather than
  replaying obsolete event kinds forever.
- Former `seed`, `committed`, and `ready` work becomes active, positioned
  Bricks; former WIP also retains independent WIP state.
- Every migrated title-derived ID maps to a new opaque ID through an explicit
  audit record.
- Useful descriptions, comparisons, dependencies, waits, delegation,
  provenance, execution facts, and timestamps are retained as evidence.
- Activation is atomic and only available after archive and projection
  verification.
- The checked-in cutover exercise uses a wholly synthetic mixed-history fixture
  with opaque identity collisions; personal v0 logs are never release data.

See [migration-v0-v1.allium](spec/little-ant/migration-v0-v1.allium) for the
complete cutover contract.

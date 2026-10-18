# Changelog

All notable user-visible changes to Little Ant are documented here.

The reviewed [1.0 specification](spec/little-ant-1.0.md) is authoritative.
Removed implementation, Allium, and generated-test artifacts are historical
evidence only. This changelog summarizes the intended release; it does not
replace the specification.

## Unreleased

- Fix the agenda calendar scrolling away: the pinned header was never found
  once lines were wrapped. The grid now also keeps six week rows, so its
  height stays the same between months.
- Show habits in the agenda: a fixed slot is a `habit` row at its start
  with `until` its end, and a quota window is a `habit due` row at its close
  with its progress, such as `1/3 done`; later windows are projected. Habits
  have their own calendar mark `◦`, legend entry, and magenta color.
- Leave the REPL with Escape from a receipt whose only action is next, such
  as one reopened in a new session.
- Refine the agenda: the calendar starts on Monday with an ISO week column,
  stays pinned above the rows in the REPL, and marks the selected day. A
  heading such as `Week 44/53, Oct, 2026`, `Sep, 2026`, or `2027` separates
  turning weeks, months, and years. Facts of one Work at the same instant
  collapse to the strongest (opens < best before < deadline), and the kinds
  are green, yellow, and red. With `[c]ategories`, Domain folders start
  collapsed and open with Tab or Enter, and loading more days keeps the
  selection on its row, which fixes the endless first category.
- Show dates in `show`: a Brick lists its own opens, best-before, and
  deadline, plus the effective best-before and deadline when an ancestor or an
  open descendant sets an earlier one, as `Effective deadline: … · via #part`.
  A descendant's date never makes the parent overdue or adds pressure to it.
- Step through the list views with Right and Left Arrow: importance,
  forecast, agenda. Left Arrow on importance still returns.
- Ask, when restoring archived Work, which Dependencies removed by the
  archive to relink: each relinkable one is a numbered, pre-marked row, and
  yes recreates the marked ones as new Dependencies in the same command.
- Undo any latest reversible action, not only Feed: `/undo` appends one
  `command_undone` event that restores the state recorded before that
  command, so an archive's removed Dependencies come back too, and `/redo`
  appends `command_redone`. Draws and system releases after the action are
  discarded with it; external effects and source facts end the chain. In the
  REPL, Escape at a commit boundary after an action of this session asks
  `Undo the last recorded action?`; Escape on that question keeps everything
  and continues leaving. Ctrl+Z (or C-_) undoes and Ctrl+Y redoes at once,
  and the palette offers `/undo` and `/redo` on every screen.
- Defer a review with `[l]ater` instead of `[s]kip`, which stays reserved for
  served Work. Wait, Delegation, impact-evidence, total-effort, and
  importance-comparison reviews gain `[o]ut of date`; a review that involves
  several Works first asks which one is out of date, then opens archive,
  replace, or update for it. The review itself is never archived.
- Give the agenda no fixed horizon: it projects 35 days at a time, the REPL
  loads the next days as the selection reaches the end, and `lant list agenda
  --days N` sets the CLI window. A day with one fact stays a flat row; only
  days with several facts and `Overdue` form groups, so `[d]ays` is gone.
  `[c]ategories` now works in the agenda, grouping by Domain, then by day,
  with dated parts under their dated parent. The REPL calendar shows the
  selected row's month, today's highlight no longer pulls the viewport back
  to the calendar, and the categories toggle names its current state.
- Assign Domains to Work at the root: the final triage preview offers
  `[d]omains` over the parent's and every other active Domain and returns to
  the same preview, and `/update` gains `Domains` to change an existing
  Brick's direct memberships through one previewed batch.
- Let Escape leave the REPL from a review the forecast served as the session's
  root screen, as it already did from a Focus proposal or triage.
- Highlight the current list view among `[i]mportance · [f]orecast ·
  [a]genda`, toggle categories with `[c]ategories` and the agenda's days with
  `[d]ays` instead of `t`, and let `/archive` be found by typing out of date,
  obsolete, or no longer.
- Switch list views directly with `[i]mportance`, `[f]orecast`, and
  `[a]genda` instead of cycling with `v`. The agenda calendar now gives each
  day four columns so a mark sits beside its own day, highlights today, colors
  deadline `!` red and best-before `•` yellow, and ends with a legend.
- Add `list agenda`, a dated read-only outlook of the next 14 days like an
  org-mode agenda: an Overdue group, then one group per day with `opens`,
  `best before`, `deadline`, and `starts` facts, projected rows for
  recurring occurrences not yet released, and a month calendar header that
  marks deadlines `!` and best-before days `•`. In the REPL, `v` now cycles
  importance, forecast, and agenda, and `t` toggles the agenda's day groups.
- Make `update it` after an out-of-date skip open the update hub for the same
  Brick; it previously only appended a note and stayed on the screen.
- Open a target-less Brick command such as `/archive` in the REPL with only
  the Bricks it can act on (archived ones for `/restore`, any for `/update`,
  active ones otherwise) and the Brick of the current screen preselected.
- Answer `no` to the final `Start focusing this Brick?` with the ordinary skip
  symptoms, so an obstacle such as out of date can be named directly; only
  `I don't know` opens the guided symptom discovery.
- Give each recurring obligation a deadline policy: an unfinished period
  either stays open as debt, as for a bill, or counts as missed at its
  deadline, as for a required weekly shift, with an optional consequence text.
  The tick closes lapsing periods as missed (scheduled ones after a 24-hour
  grace); `show --view guided '#occurrence'` lets a missed period be done late
  or excused and an open one be excused, keeping every fact in a period
  history such as `[x][~][!][-]` with totals.
- Move the forecast to profile `little-ant-forecast-v5-factory-deadline-approach`:
  an approaching deadline raises a subject's importance factor toward the top
  without ever lowering it, `best_before` pressure ramps from when the Work
  became eligible (at most 30 days) to 1.00 at `best_before` itself, recent
  misses of a lapsing series press its next occurrence, and quota-window habits
  gain elapsed-and-unmet pressure. Recurring-obligation series and their
  occurrences use the neutral importance factor and no longer shift the
  positions of their siblings.
- Stop asking importance questions for recurring obligations: creating a
  series skips binary insertion, ordering reviews and comparisons ignore
  series and occurrences, and `list importance` shows active series in a
  closing Obligations group by next deadline with their open occurrences.
  The Nature-discovery question that leads to a recurring obligation now asks
  whether something outside you requires each period.
- Offer escalated obligation occurrences before the ordinary draw: from its
  `best_before`, or 24 hours before its deadline, an open occurrence comes
  first by earliest deadline with `Due first` and the reason in the footer.
  Skipping it pauses that occurrence for 120 minutes.
- Honor the skip cooldown of served Work in the forecast; a recorded
  cooldown was previously looked up under the wrong key and never applied.
- Offer `[c]lassify` on the detail of a Raw still awaiting triage
  (`show --view guided '+raw'`), opening triage for that exact Raw instead of
  only the oldest Inbox item.
- Add the structured recurring-obligation editor: offered right after a series
  is created and through `update BRICK repetition`, it records family,
  occurrence Nature, interval, weekdays or day, local times, IANA zone, and
  opens/best-before/deadline offsets, previewing the next three anchors. Edits
  govern only anchors from the current day on.
- Release occurrences made due by an accepted recurrence before showing its
  receipt, which lists the occurrences open now, so answering the receipt is
  not stale. Label new occurrences by their period (`Fri, Oct 16 2026`,
  `Oct 2026`, `2026`) and show the occurrence deadline beside it.

- Limit newly allocated Brick, Raw, and ExternalEntity handle bases to six
  characters, preserving collision suffixes and all existing handles.

- Bound title previews in the command palette to terminal width, omit repeated
  citations from descriptions, and keep full command targets and search text.
- Allow Escape from a stale main opportunity to exit after closing the palette,
  without replacing the pending question owned by another client.

- Add `--non-interactive`, explicit result status/exit codes, and bound
  `interaction show|respond|back|forward` transport for every implemented guided
  CLI flow, with stale-response rejection and explicit secret input on stdin.
- Support direct archive/restore confirmation with `--yes` and exact title or
  description input for update; expose archive/restore/update in the REPL with
  searchable target selection and no prerequisite Focus.
- Move the packaged operator skill from terminal automation to the public CLI.

- Offer on-demand effort/impact comparisons and impact-evidence reviews in the
  ordinary lottery, coalescing equivalent requests and preserving Work on skip.
- Connect tired/easier-work recovery to a recorded executable shortlist and
  ordinary Focus consent, with separate weak contextual effort evidence.
- Mark changed scope/evidence judgments review due, retain their history, and
  explain the recorded review trigger through `/why`.

- Admit unresolved sibling-order reviews to the ordinary lottery, with bounded
  uncertainty/age pressure, one-comparison cadence, and review-only skip cooldown.
- Show separate opportunity chances beneath each forecast subject's total.
- Add read-only `/why` and `lant why`, using immutable selection-time facts and
  optional calculation details; retain partial explanations for legacy records.
- Fix vault idle renewal after slow cryptographic writes and stabilize socket
  fixtures under deep temporary paths in CI.

## 1.0.0-alpha.2 (2026-10-14)

- Improve the guided REPL with direct exit gestures, task-context assistance,
  explicit navigation, and automatic advance after completion.
- Open importance order directly with `/list`; pin view controls, support local
  Ctrl+F search, and compose categories with projects and subtasks. Keep a
  scrolling margin around the selected title.
- Render Markdown with readable wrapping and styling, and support mouse-wheel
  scrolling in paginated screens.
- Adopt Forte+ for the factory importance forecast: approximately 60% for the
  first fully confident sibling and a softer geometric tail, with uniform
  exploration. Preserve confidence dilution and recorded historical draws.
- Add rebuildable fold snapshots and immutable quarterly archives; validate the
  complete historical event chain during diagnostics and repair.
- Stop retired Work from blocking active dependents, and disclose dependency
  removal before archival.
- Align the offline HTML explorer with category/project/part trees while
  retaining separate composition and dependency sections.
- Fix the reviewed import, OAuth, Pack, and vault boundary cases, and add real
  terminal regression coverage.

This prerelease retains the alpha scope. Powered-up mode, the v1 Skill, local
web, and the remaining beta obligations are still pending. Older executables
that read only the hot event directory cannot replay rotated archives; retain
a complete backup and use the updated executable with these datasets. See the
[alpha.2 release notes](implementation/releases/v1-alpha.2.md).

## 1.0.0-alpha.1 (2026-08-10)

The first alpha narrows the release gate to the local dumb daily loop and a
safe, staged migration of the author's observed v0 dataset. Existing Packs,
vault, provider, Calendar, and advanced time capabilities remain available for
experimental testing but are not alpha compatibility promises. Assisted mode,
the v1 Skill, local web, complete migration breadth, and public packaging move
to the beta backlog.

The supported alpha includes guided title and Raw-backed description updates,
strict preflight of the 25 observed legacy event types, isolated candidate
replay, exact source custody, and resumable atomic cutover into an empty v1
profile. Migration boots through a recovery-only environment, so stale optional
integration, Pack, vault, or provider configuration cannot prevent v0
inspection and recovery. A sanitized end-to-end simulation exercises ordering,
weighted next, focus, skip diagnosis, decomposition, completion, restart,
search, and doctor against migrated data.

## 1.0.0 (target)

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
- Versioned fixed-point confidence decay and weighted-choice formulas with
  recorded random streams, reference vectors, and positive long-tail chance.
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
  separate decisions. Repeated Feed preserves each Raw receipt; an accepted
  Raw `duplicate_of` relation groups receipts without merging their identity or
  history, while downstream review avoids duplicate Work or ListEntries.
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
- `/` command palette and contextual uncertainty assistance.
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

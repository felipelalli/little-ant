# 2. Concepts, identity, and hierarchy

## Core concepts

- **MOD-001 [core] — Raw.** Raw is the durable general content record. It may
  hold a description, note, URL, imported object, pasted conversation, source
  snapshot, attachment, or other material. It can be reviewed, linked,
  enriched, archived, and reconciled with an external origin. It is not work,
  is not importance-orderable, and has no `done` operation.
- **MOD-002 [core] — Brick.** A Brick is one durable unit of intention or
  responsibility. Every active Brick has one Nature and one deterministic
  position among its siblings from birth.
- **MOD-003 [standard] — ListEntry.** A ListEntry is a structured member owned
  by a Nature that treats entries as part of one execution unit. It is not
  automatically an independent Brick or globally unique world object.
- **MOD-004 [core] — BrickNature.** A BrickNature is a versioned,
  core-validated set of observable capabilities governing focus unit,
  structure, completion, standing execution, recurrence, entry ownership,
  lazy axes, and delegation scope.
- **MOD-005 [standard] — BrickTemplate.** A BrickTemplate is an inspectable,
  one-time creation recipe. After expansion, it has provenance but no hidden
  runtime authority.
- **MOD-006 [core] — Domain.** A Domain is a hierarchical, non-exclusive
  classification used for retrieval, context, and focus continuity. It is not
  a folder owner, a Brick parent, or an organizational person.
- **MOD-007 [standard] — ExternalEntity.** An ExternalEntity is a durable
  reference to a person, team, organization, AI agent, or service involved in
  requests, delegation, waiting, provenance, or delivery. Proper names retain
  their declared spelling and are not translated merely to satisfy the
  English canonical-data policy.

## Identity

- **MOD-008 [core] — UUIDv7 internal identity.** Every durable record and event
  receives one globally unique, immutable 128-bit UUIDv7 identity from one
  type-neutral namespace. No type bits or type-specific prefixes are embedded
  in it. The UUID is never derived from title, display handle, type, Domain,
  parent, or other mutable content. Its RFC 9562 layout is 48 Unix-millisecond
  timestamp bits, four version bits set to `7`, 12 random bits, two RFC
  variant bits, and 62 random bits. Technical projections encode the canonical
  UUID string (for example `0198f8a3-4c21-7b6e-9d05-82fa731c4e60`) or its
  equivalent 16-byte value. The embedded timestamp is only a
  generation-locality and indexing aid: explicit event time and authoritative
  log position determine semantic history. Replay and import reuse the stored
  UUID and never generate a replacement. See [RFC 9562, UUID Version
  7](https://www.rfc-editor.org/rfc/rfc9562.html#name-uuid-version-7).
- **MOD-009 [core] — Repeated titles.** Equal canonical titles do not imply
  identity. Scope, Nature, parent, source, and history participate in
  duplicate suspicion.
- **MOD-010 [core] — Typed mnemonic handles and complete rendering.** Each
  Brick has one dataset-local canonical human handle rendered as
  `#handle "canonical title"`; each ExternalEntity has one rendered as
  `@handle "declared name"`. Optional kind emoji or text may supplement but
  never replace the sigil. A bare handle is insufficient. The handle is a
  discoverable human reference, not identity: relationships, events, and
  annotations store the target UUID and render its current handle. Normal
  surfaces do not expose UUIDs unless a technical or diagnostic projection
  explicitly requests them. The default mnemonic base for a multi-word title
  or name is its normalized lowercase ASCII initials without stop-word
  removal. The first available base is unsuffixed; a collision receives the
  smallest never-used integer suffix beginning at `2`, as in `#rs` and
  `#rs2`. The
  allocator is deterministic within one dataset and maintains separate `#`
  and `@` namespaces. Retired handles are not reused. Renaming a title or name
  keeps its handle by default. An explicit previewed handle rename creates no
  compatibility alias. Exact normalization of single-word, non-Latin, empty,
  or punctuation-only names remains `OPEN-REF-001`.
- **MOD-011 [core] — Suspicion is not equivalence.** Duplicate detection
  creates a reviewable suspicion. Only an explicit canonical outcome may
  reuse, enrich, merge, or keep entities separate.
- **MOD-012 [core] — Explicit object merge.** `merge` chooses a surviving UUID,
  previews affected relationships and conflicts, preserves lineage and source
  provenance, and supports dry-run. It is not a title- or handle-based
  deduplication. A dataset merge compares UUIDs before handles. The same UUID
  with compatible lineage denotes the same object and is reconciled;
  incompatible content or lineage under the same UUID is an explicit identity
  conflict and is never silently remapped. Different UUIDs remain different
  objects even when their handles or titles match. In an import into an
  existing target dataset, a conflicting target handle remains stable and the
  incoming object receives the next never-used suffix after a dry-run preview;
  UUIDs remain unchanged. The report names every public-handle change, and
  externally stored literal references require an inspectable mapping report
  rather than a hidden alias.

The initial ExternalEntity kinds are:

```text
person | team | organization | ai_agent | service
```

`area` is not an entity kind; hierarchical organizational classification uses
Domain. The exact ContactPoint and local delivery-binding schema remains an
open release decision rather than an inferred v1 commitment.

## Brick state

- **MOD-013 [core] — Independent axes.**

  ```text
  status     = active | done | dropped | superseded
  phase?     = idea | spec | exec | validation
  work_state = idle | wip
  focus      = zero or one current Brick globally
  ```

- **MOD-014 [core] — Direct completion.** `done` is a direct transition from
  any structurally completable active Brick. It requires no invented
  intermediate stage or start event.
- **MOD-015 [core] — Structural completion.** A finite Brick with no tracked
  child parts remains directly executable regardless of whether its Nature is
  `atomic_task` or `project`. Once it has been decomposed into child Bricks,
  the parent stops being an ordinary Work candidate while any child remains
  incomplete. Completing the final child never cascades completion to the
  parent; it releases a parent-scope review that may confirm completion or
  introduce more work. Standing execution, repeatable work, and pending
  external effects retain their Nature-aware closure paths. Whether dropped
  or superseded children satisfy the all-children-finished boundary remains
  part of `OPEN-TREE-001`.
- **MOD-016 [core] — Removed stages.** `seed`, `committed`, and `ready` do not
  exist in v1. Backlog-like or commitment-like meaning derives from importance
  position, not lifecycle mutation.
- **MOD-017 [standard] — Optional phase.** A Nature may make phase applicable,
  irrelevant, or disabled. Missing phase is neutral and never blocks feeding
  or focus.
- **MOD-018 [standard] — Descriptive phase.** Phase is not a required workflow
  and never sorts importance. `spec` uses `📐`; the remaining exact phase
  markers must be approved through the UX catalog under `OPEN-MOD-002`.

## Composition and relationships

- **MOD-019 [core] — Composition tree.** A Brick has at most one parent.
  Composition expresses scope; moving a Brick changes scope and may require
  review without changing identity.
- **MOD-020 [core] — Sibling locality.** Direct human importance comparisons
  are valid only between Bricks with the same parent, including root siblings.
  Global display order is the lexicographic traversal of sibling orders.
- **MOD-021 [core] — Dependency is orthogonal.** A dependency says what must
  become actionable first. It neither reparents nor reorders either Brick.
- **MOD-022 [core] — Multi-Domain membership.** A Brick may belong to several
  Domains. Membership does not duplicate the Brick or give it multiple
  top-level lottery tickets. Domain lifecycle, multiple-taxonomy, exclusion,
  and recursive-reference behavior remain `OPEN-DOM-002`.
- **MOD-023 [standard] — Raw links.** Typed links connect Raw to a Brick,
  ListEntry, or other Raw with an explicit content role and provenance. The
  same Raw may participate in several links without being consumed or copied.
- **MOD-024 [standard] — Explicit typed annotations.** `@` and `#` text becomes
  an ExternalEntity or Brick annotation only after an explicit target
  selection from the corresponding handle autocomplete on an
  annotation-capable field. The annotation stores target UUID and the
  applicable content revision, then renders the current canonical handle.
  Unselected lookalike text remains literal. An annotation supports navigation
  and retrieval but never creates requester, delegation, waiting, dependency,
  Domain, or other behavioral semantics by itself.

## Factory Natures

The factory library contains:

| Nature | Focus and lifetime |
|---|---|
| `atomic_task` | one finite intention focused and completed as a single unit |
| `project` | one finite outcome; executable before decomposition, then represented by child work and a final scope review |
| `collection` | open-ended independently focusable child Bricks |
| `repeatable` | the same Brick returns after completed executions |
| `living_checklist` | one durable parent owns changing entries and renders all open entries together |
| `finite_checklist` | finite parent and entries render together |
| `recurring_obligation` | standing series releases independent occurrence Bricks |
| `habit` | standing intention exposes expiring opportunities, streaks, and history |
| `scheduled_commitment` | one externally anchored interval that cannot be performed at an arbitrary time |

- **MOD-025 [core] — Required Nature.** Every Brick receives exactly one
  validated Nature at birth. There is no hidden fallback Nature. `[?] I don't
  know` starts bounded capability questions whose `yes`, `no`, and uncertainty
  answers resolve an existing validated Nature. If uncertainty remains, the
  Feed interaction remains pending and no Brick is created.
- **MOD-026 [core] — Closed capabilities.** Nature definitions can compose only
  capabilities implemented by the core. No scripts, prompts, network calls,
  title-keyword branches, or arbitrary lifecycle hooks are allowed.
- **MOD-027 [standard] — Version stability.** Existing Bricks retain a
  replay-safe Nature version or resolved snapshot; editing a definition never
  silently changes them.
- **MOD-028 [standard] — Template library.** The product ships an offline,
  inspectable declarative Template library. Confirmed release commitments and
  candidates under review are listed in the
  [standard Template catalog](standard-template-catalog.md). Additional
  checklist Templates should name a concrete situation rather than a vague
  generic checklist category. Templates expand generic Natures rather than add
  domain branches. `feature_backlog` has a `collection` root whose features
  are independently focusable child Bricks, not ListEntries.

## Content, movement, and effective metadata

- **MOD-029 [core] — Description is Raw.** A Brick has no scalar description
  field. Descriptive content is a Raw linked to the Brick in a description
  role, so it retains the same provenance, original-representation,
  normalization, revision, and reuse semantics as other durable content. This
  does not make the Raw focusable or importance-orderable.
- **MOD-030 [standard] — Explicit participants.** A requester or responsible
  outside actor references an ExternalEntity. Delegation, waiting, requester,
  and `about`/annotation relationships remain distinct even when they cite the
  same entity.
- **MOD-031 [core] — Break and move preserve truth.** Breaking retains the
  parent's sibling position and creates a locally ordered child set. Moving a
  subtree preserves its internal tree/order, reinserts only the moved root in
  its new sibling set with low confidence, and keeps old-scope comparisons as
  inactive history.
- **MOD-032 [core] — Coverage follows structure.** Adding, moving, or removing
  relevant descendant scope reopens decomposition coverage for affected finite
  parents and may create a scope review; it never rewrites unrelated evidence.
- **MOD-033 [core] — Date constraints accumulate.**

  ```text
  effective_not_before = latest value on self and ancestors
  effective_best_before = earliest value on self and ancestors
  effective_deadline = earliest value on self and ancestors
  ```

- **MOD-034 [standard] — Inheritance must be explicit.** Final mode vocabulary,
  nearest-ancestor mode behavior, direct versus inherited Domain membership,
  and inheritance of requester, `about`, or RawLinks remain
  `OPEN-MOD-003`. Implementations must not infer them from the old free-text
  `context` field.

## Nature behavioral boundaries

- **MOD-035 [standard] — Living checklist.** A `living_checklist` is one
  durable Brick that owns changing ListEntries. When it has open entries,
  `next` serves the parent as the focus unit and the surface renders every
  open entry together. Resolved entries remain in history. An empty list is
  dormant rather than done, and adding a new entry makes it eligible again.
- **MOD-036 [core] — Checklist versus collection.** A `finite_checklist` and a
  `living_checklist` own ListEntries and focus the parent as one unit. A
  `collection` owns independently focusable child Bricks, each of which may
  have its own importance position, blockers, dates, Domain memberships, and
  history.
- **MOD-037 [core] — Finite versus living.** A `finite_checklist` represents
  one completable scope. A `living_checklist` represents a continuing
  responsibility whose current entries may all be resolved without completing
  the parent.
- **MOD-038 [standard] — Nature names describe mechanics.** Factory Nature
  names describe lifecycle and focus mechanics rather than a domain. Templates
  provide names and defaults for concrete uses such as groceries, trips,
  reading, software backlogs, bills, or exercise.
- **MOD-039 [standard] — Composite Template expansion.** A Template advertises
  one root Nature for compatibility and may atomically instantiate a finite,
  previewed initial structure containing child Bricks of other Natures and
  Nature-owned ListEntries. Every created Brick still has exactly one
  validated Nature. Accepted expansion becomes ordinary canonical state;
  Template provenance remains inspectable, but the Template cannot create
  later descendants or retain runtime authority.
- **MOD-040 [standard] — Relationship-habit Templates.** The standard library
  includes `keep_in_touch`, which creates one `habit` Brick for one specific
  ExternalEntity target so relationship-specific history remains honest, and
  `social_time`, which creates a `habit` without requiring one fixed person or
  group. They are distinct Templates, not aliases for one another.
- **MOD-041 [standard] — Physical-activity Template.** The standard library
  includes `physical_activity` with root Nature `habit`. It preserves the
  already fed title as the chosen activity and requires either a fixed-slot or
  quota-window schedule under `WRK-038`. Place, preferred time, weather,
  season, and blockers remain optional enrichment. No compatibility alias is
  defined.
- **MOD-042 [standard] — Reading-habit Template.** The standard library
  includes `reading_habit` with root Nature `habit`. The fed title or
  completion criterion may state an intended duration or amount, but the
  Template requires only a structured schedule and the ordinary discrete
  habit outcome under `WRK-040`.
- **MOD-043 [core] — Scheduled commitment.** A `scheduled_commitment`
  represents one externally anchored interval rather than work that may be
  performed at any convenient time. Its exact instants retain their named
  time zones under `WRK-041..044`. It is a mechanical Nature shared by
  flights, appointments, meetings, reservations, attendance, transport, and
  other concrete Templates; it is not a domain-specific branch.
- **MOD-044 [standard] — Broad offline Template library.** The standard
  offline distribution intentionally offers many common, inspectable
  Templates across each Nature. Companion extensions are primarily for highly
  specialized domains, integrations, or recipes, not a reason to omit useful
  everyday choices from the built-in catalog.
- **MOD-045 [core] — Atomic decomposition changes Nature.** An `atomic_task`
  cannot gain independently tracked child parts while remaining atomic.
  `break` first determines whether the proposed parts require `project`,
  `finite_checklist`, or `collection` mechanics and previews that Nature
  change. A mere prerequisite remains an orthogonal Dependency and does not
  by itself make the task non-atomic; notes or instructions remain content
  rather than child Bricks. The operation is reachable explicitly through
  contextual `/break` and through accepted recovery routes; a `project`
  Nature, large-sounding title, or model suggestion never invokes it by
  itself.
- **MOD-046 [core] — Reclassification preserves identity.** Confirming an
  atomic `break` changes the existing Brick's Nature and creates its proposed
  parts in one atomic operation. The parent retains its ID, title, history,
  sibling importance position, relationships, and Template provenance. Every
  new child receives its own Nature and local sibling position. Rejecting or
  escaping the preview changes nothing; semantic undo follows `UX-020`. Once
  accepted, the decomposed parent is no longer served as ordinary Work; its
  descendants carry execution until the scope-review boundary in `MOD-015`.
- **MOD-047 [standard] — Previewed preparation expansion.** A
  `scheduled_commitment` Template may propose a finite preparation structure
  containing child Bricks of other Natures and explicitly identified hard
  Dependencies. The complete structure and relative timing are previewed
  before creation. After acceptance, ordinary canonical relationships and
  temporal constraints own the behavior; the Template retains provenance but
  no runtime authority.
- **MOD-048 [standard] — Declarative classification guidance.** A Template
  may publish bounded, inspectable guidance containing representative
  canonical-English examples, positive semantic or structural cues,
  counterexamples, and source-shape evidence. Guidance is neither an
  exhaustive keyword list nor executable behavior. A Pack cannot inject a
  free-form prompt for the host to obey; the Skill or powered-up host composes
  its own bounded classification request over validated catalog data.
- **MOD-049 [core] — Same-Raw English normalization.** A Raw preserves its
  original representation and may also carry one attributed canonical-English
  normalization on the same Raw identity. Translation or normalization alone
  never creates a second Raw. The normalization records its source and remains
  distinguishable from the original; exact revision and stale-normalization
  behavior is settled under `OPEN-RAW-002`.
- **MOD-050 [core] — Wait is a gate, not work.** A Wait is a durable typed gate
  attached to an affected Brick because progress depends on an external
  response, event, or condition for which no current human action is known. It
  may reference an ExternalEntity, source, and linked Raw evidence, and it
  preserves activation, review, and resolution history. It has no Nature,
  parent, sibling importance position, focus, WIP, or `done` operation. A
  temporal `not_before`, Place condition, or actionable Brick Dependency is
  not represented as a Wait merely because ordinary language says "waiting."
- **MOD-051 [core] — Delegation and Wait are orthogonal.** A Delegation records
  transferred execution responsibility and owns any review or follow-up
  schedule implied by its policy. Activating one never creates an implicit
  Wait for its target. A Wait is added only when a separate external response,
  event, or condition is explicitly observed and classified under MOD-050;
  neither record substitutes for or silently resolves the other. When both
  affect the same attention subject, FOC-006..008 still provide one subject
  ticket and a local opportunity draw rather than duplicate top-level chances.
- **MOD-052 [core] — Break defaults remain reviewable.** A confirmed break
  draft that does not explicitly resolve a child's Nature stores
  `atomic_task`, attributed to the deterministic `break_default`, so every new
  Brick is immediately valid. Each such assignment carries a claim-scoped
  lazy human-review marker; it is not an invisible fallback or a permanent
  assertion. An accepted assisted Nature or Dependency retains its AI
  provenance and its own lazy human-review marker even though it becomes
  effective in the atomic transaction. The preview identifies every
  non-human claim and review marker before commit. Reviewing one claim never
  silently settles another child, axis, or relationship.
- **MOD-053 [core] — Nature review settles one claim.** Confirming a
  `nature_review` appends direct human judgment for the Brick's current Nature,
  retains the factory or AI source in history, and resolves only that claim's
  lazy-review marker. Choosing another Nature enters the canonical Nature
  choice and previews any consequential reclassification before the same
  isolated settlement. Review skip changes neither Nature nor provenance and
  leaves the marker unresolved under FOC-040. Confirmation or reclassification
  cannot settle sibling Natures, importance, or Dependencies by implication.

# 2. Concepts, identity, and hierarchy

## Core concepts

- **MOD-001 [core] — Raw.** Raw is durable material that can be reviewed,
  linked, enriched, archived, and reconciled with an external origin. It is
  not work, is not importance-orderable, and has no `done` operation.
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
  requests, delegation, waiting, provenance, or delivery.

## Identity

- **MOD-008 [core] — Opaque identity.** Canonical IDs are opaque and are never
  hashes of mutable titles. Renaming preserves identity.
- **MOD-009 [core] — Repeated titles.** Equal canonical titles do not imply
  identity. Scope, Nature, parent, source, and history participate in
  duplicate suspicion.
- **MOD-010 [core] — Complete rendering.** Whenever UI text cites a Brick, it
  renders `#shortid "canonical title"`; a bare ID is insufficient.
- **MOD-011 [core] — Suspicion is not equivalence.** Duplicate detection
  creates a reviewable suspicion. Only an explicit canonical outcome may
  reuse, enrich, merge, or keep entities separate.
- **MOD-012 [core] — Explicit merge.** `merge` chooses a surviving identity,
  previews affected relationships and conflicts, preserves lineage and source
  provenance, and supports dry-run. It is not a title-based deduplication.

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
- **MOD-015 [core] — Structural completion.** Active descendants, standing
  execution, repeatable work, and pending external effects follow their
  Nature-aware closure paths; completing a child never cascades completion to
  an ancestor.
- **MOD-016 [core] — Removed stages.** `seed`, `committed`, and `ready` do not
  exist in v1. Backlog-like or commitment-like meaning derives from importance
  position, not lifecycle mutation.
- **MOD-017 [standard] — Optional phase.** A Nature may make phase applicable,
  irrelevant, or disabled. Missing phase is neutral and never blocks feeding
  or focus.
- **MOD-018 [standard] — Descriptive phase.** Phase is not a required workflow
  and never sorts importance. `spec` uses `📐`; the remaining exact phase
  markers must be approved through the UX catalog.

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
  top-level lottery tickets.
- **MOD-023 [standard] — Raw links.** Typed links connect Raw to a Brick,
  ListEntry, or other Raw while retaining exactly one link owner and explicit
  provenance.
- **MOD-024 [standard] — External annotations.** Human-readable mentions may
  resolve to stable ExternalEntity or Brick references, but text tokens never
  gain behavioral authority by themselves.

## Factory Natures

The factory library contains:

| Nature | Focus and lifetime |
|---|---|
| `atomic_task` | one finite intention focused and completed as a single unit |
| `project` | one finite outcome whose descendant scope participates in review |
| `collection` | open-ended independently focusable child Bricks |
| `repeatable` | the same Brick returns after completed executions |
| `living_checklist` | one durable parent owns changing entries and renders all open entries together |
| `finite_checklist` | finite parent and entries render together |
| `recurring_obligation` | standing series releases independent occurrence Bricks |
| `habit` | standing intention exposes expiring opportunities, streaks, and history |

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

- **MOD-029 [core] — Description is canonical content.** A Brick may keep an
  English description directly. Durable source material, attachments,
  original-language bodies, and independently reusable notes remain Raw and
  link to it; a description is not forced to masquerade as Raw.
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

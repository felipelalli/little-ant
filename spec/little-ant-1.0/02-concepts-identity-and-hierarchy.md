# 2. Concepts, identity, and hierarchy

## Core concepts

- **MOD-001 [core] — Raw.** Raw is the durable general content record and the
  immediate result of every accepted `feed`. It may hold a description, note,
  URL, imported object, pasted conversation, source snapshot, attachment, or
  other material. It can be reviewed, linked, enriched, archived, and
  reconciled with an external origin. It is not work, is not
  importance-orderable, and has no `done` operation. Routing it later never
  consumes it.
- **MOD-056 [core] — Description is an ordinary Raw attachment.** A Brick has
  no description string, Description entity, DescriptionRaw subtype, or owned
  content slot. What surfaces render as `Description` is derived solely from
  an ordinary RawLink whose local role is `description`:

  ```text
  Brick -- RawLink(role = description) --> Raw
  ```

  The target remains a normal Raw with ordinary identity, revisions,
  normalization, RawShelf membership, Domain classification, provenance,
  source reconciliation, and non-description links. The role changes only how
  that one relationship is interpreted. Detaching it removes the description
  projection without deleting, consuming, transforming, or archiving the Raw.
- **MOD-057 [core] — Description-role cardinality is one-to-one.** One Brick
  has at most one active RawLink with role `description`, and one Raw may be
  the `description` target of at most one Brick. A Raw serving that role may
  still have any otherwise-valid non-description links and memberships.
  Shared supporting content therefore uses another compatible RawLink role
  rather than making one mutable description govern several Bricks. Role
  uniqueness is validated before commit and never repaired by silent copying.
- **MOD-002 [core] — Brick.** A Brick is one durable unit of intention or
  responsibility. Every active Brick has one Nature and one deterministic
  position among its siblings from birth.
- **MOD-003 [standard] — ListEntry.** A ListEntry is a structured member owned
  by a Nature that treats entries as part of one execution unit. It is not
  automatically an independent Brick or globally unique world object. Its
  identity is stable only within one owning Brick: resolving, cancelling, or
  reopening it appends history to that same identity rather than replacing it.
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
  `#handle "canonical title"`; each Raw has one rendered as
  `+handle "bounded original-content preview"`; and each ExternalEntity has
  one rendered as `@handle "declared name"`. The Raw preview is a projection
  of its original material, source label, or filename rather than a new title
  field. Optional kind emoji or text may supplement but never replace the
  sigil. A bare handle is insufficient. The handle is a discoverable human
  reference, not identity: relationships, events, and annotations store the
  target UUID and render its current handle. Normal surfaces do not expose
  UUIDs unless a technical or diagnostic projection explicitly requests
  them. The default mnemonic base for a multi-word title, name, or Raw display
  seed is its normalized lowercase ASCII initials without stop-word removal.
  A Raw's immutable allocation seed is the first available human-visible
  source label, filename, or first nonblank line of its original material;
  when none exists, it is `raw`. Later content revision, English
  normalization, source reconciliation, or role changes retain the allocated
  handle. The first available base is unsuffixed; a collision receives the
  smallest never-used integer suffix beginning at `2`, as in `#rs`, `#rs2`,
  `+milk`, and `+milk2`. The allocator is deterministic within one dataset
  and maintains separate `#`, `+`, and `@` namespaces. Retired handles are not
  reused. Renaming a title or name keeps its handle by default. An explicit
  previewed handle rename creates no compatibility alias. UX-201 defines exact
  edge normalization for single-word, non-Latin, empty, and punctuation-only
  seeds.
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
  status     = active | done | archived | superseded | merged
             | missed | cancelled
  phase?     = idea | spec | exec | validation
  work_state = idle | wip
  focus      = zero or one current Brick globally
  ```

- **MOD-014 [core] — Direct completion.** `done` is a direct transition from
  any structurally completable active Brick. It requires no invented
  intermediate stage or start event.
- **MOD-055 [core] — Archived Work is retained, not completed.** `archived` is
  the canonical Brick status for Work the user has stopped pursuing without
  claiming completion or replacement. An archived Brick keeps its identity,
  content, relationships, provenance, history, and prior importance evidence,
  but leaves the active importance projection and is not served as ordinary
  executable Work. It remains searchable and may be restored as the same
  Brick. `dropped` is not a v1 status, command alias, or UI synonym. Raw
  archival remains the independent Raw disposition in MOD-001 rather than a
  Brick lifecycle transition.
- **MOD-015 [core] — Structural completion.** A finite Brick with no tracked
  child parts remains directly executable regardless of whether its Nature is
  `atomic_task` or `project`. Once it has been decomposed into child Bricks,
  the parent stops being an ordinary Work candidate while any child remains
  incomplete. Completing the final child never cascades completion to the
  parent; it releases a parent-scope review that may confirm completion or
  introduce more work. Standing execution, repeatable work, scheduled
  commitments with preparation children, and pending external effects retain
  their Nature-aware focus and closure paths. MOD-083 defines the mixed
  terminal-child boundary.
- **MOD-016 [core] — Removed stages.** `seed`, `committed`, and `ready` do not
  exist in v1. Backlog-like or commitment-like meaning derives from importance
  position, not lifecycle mutation.
- **MOD-017 [standard] — Optional phase.** A Nature may make phase applicable,
  irrelevant, or disabled. Missing phase is neutral and never blocks feeding
  or focus.
- **MOD-018 [standard] — Descriptive phase.** Phase is not a required workflow
  and never sorts importance. Its closed human rendering is `💡 idea`,
  `📐 spec`, `🔨 execution`, and `🧪 validation`; the stored value behind
  `execution` is `exec`. Every icon is decorative and the adjacent English
  label is mandatory. With emoji disabled, the exact labels remain `idea`,
  `spec`, `execution`, and `validation`. A phase change is an ordinary
  explicit update, not an automatic lifecycle transition.

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
  top-level lottery tickets. MOD-073..076 define the single forest, lifecycle,
  absence of exclusion, and recursive-query behavior.
- **MOD-023 [standard] — Raw links.** Typed links connect Raw to a Brick,
  ListEntry, or other Raw with an explicit content role and provenance. The
  same Raw may participate in several links without being consumed or copied.
- **MOD-024 [standard] — Explicit typed annotations.** `#`, `+`, or `@` text
  becomes a Brick, Raw, or ExternalEntity annotation only after an explicit
  target selection from the corresponding handle autocomplete on an
  annotation-capable field. The annotation stores target UUID and, for Raw,
  the applicable content revision, then renders the current canonical handle.
  Unselected lookalike text remains literal. An annotation supports navigation
  and retrieval but never creates RawLink, requester, delegation, waiting,
  dependency, Domain, or other behavioral semantics by itself.

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
  Raw-to-Work materialization remains pending and no Brick is created.
- **MOD-026 [core] — Closed capabilities.** Nature definitions can compose only
  capabilities implemented by the core. No scripts, prompts, network calls,
  title-keyword branches, or arbitrary lifecycle hooks are allowed.
- **MOD-027 [standard] — Version stability.** Existing Bricks retain a
  replay-safe Nature version or resolved snapshot; editing a definition never
  silently changes them.
- **MOD-028 [standard] — Template library.** The product ships an offline,
  inspectable declarative Template library. Its release commitments are listed
  in the
  [standard Template catalog](standard-template-catalog.md). Additional
  checklist Templates should name a concrete situation rather than a vague
  generic checklist category. Templates expand generic Natures rather than add
  domain branches. `feature_backlog` has a `collection` root whose features
  are independently focusable child Bricks, not ListEntries.
- **MOD-058 [core] — Behavior has one canonical classification axis.** In the
  semantic update hub, human-facing `behavior` means the Brick's Nature and
  nothing else. Cadence, schedule, and recurrence timing belong to `timing`;
  parts, Dependencies, Waits, and Delegation belong to `plan`. A Template is a
  one-time creation recipe whose immutable provenance may be inspected but not
  changed as if it were live behavior. Applying later explicit plan or timing
  changes never rewrites their original Template provenance.
- **MOD-059 [core] — Nature reclassification never discards active truth.** A
  proposed Nature change retains the Brick UUID, handle, title, description,
  importance position and evidence, Domains, compatible relationships, and
  complete typed history. Target-required configuration is collected before
  preview. Any current structure, entry, occurrence, schedule, focus, WIP, or
  other active state that the target Nature cannot represent requires one
  explicit typed reconciliation before confirmation. The core never silently
  deletes, archives, completes, detaches, flattens, converts, or forgets that
  state merely to make the new Nature validate.
- **MOD-060 [core] — Structure keeps three human intents distinct.** A Brick's
  structural maintenance distinguishes: placement within larger Work, child
  Brick parts, and Nature-owned ListEntries. Placement changes the composition
  parent or moves the Brick to root. Parts are independently tracked Bricks
  with their own identities, sibling importance, gates, and histories.
  ListEntries are executed and shown together through their owning checklist
  Brick under MOD-003 and MOD-036. Choosing one intent never silently converts
  an existing child Brick into a ListEntry or vice versa.
- **MOD-061 [core] — Composition never grants Domain membership.** Every Brick
  Domain membership is explicit and direct. A parent, ancestor, child, or
  sibling may inform a visible proposal, but accepting that proposal stores
  ordinary direct memberships on the target Brick. Moving or decomposing Work
  never adds, removes, or rewrites a Brick's Domains implicitly, and Domain
  membership never reparents Work. Retrieval and focus continuity traverse the
  declared Domain hierarchy independently of the composition tree. An
  `effective Domain path` is therefore the ancestor path of an explicit direct
  membership for query and display, not membership inherited from a Brick
  parent.
- **MOD-062 [core] — Structural compatibility is a Nature capability.** The
  factory structural slice is authoritative for Structure dispatch; generated
  recurring occurrences are a separate lifecycle capability rather than
  manually managed parts:

  | Nature | independently focusable child parts | owned ListEntries |
  |---|---|---|
  | `atomic_task` | none | none |
  | `project` | finite outcome | none |
  | `collection` | open-ended members | none |
  | `repeatable` | none | none |
  | `living_checklist` | none | continuing |
  | `finite_checklist` | none | finite scope |
  | `recurring_obligation` | none; occurrences are system-released | none |
  | `habit` | none | none |
  | `scheduled_commitment` | preparation | none |

  A supported cell enters its existing manager without reclassification. An
  unsupported intent first resolves a compatible target under WRK-112. A
  `scheduled_commitment` preparation child can be focused independently before
  the interval, while the commitment itself remains the anchored focus unit
  under MOD-043, MOD-047, and FOC-030. MOD-077..081 close the remaining
  behavior-capability deltas.
- **MOD-063 [standard] — ListEntry state and quantity stay small.** A
  ListEntry has exactly one lifecycle state: `open`, `resolved`, or
  `cancelled`. Reopening either closed state preserves its owner-scoped
  identity and prior outcomes. Display order is stable insertion order in
  1.0; entries have no sibling importance, independent focus, global handle,
  or reorder operation.

  Quantity is one positive finite decimal amount and one normalized unit. An
  omitted quantity canonicalizes to `1 count`; the ordinary projection omits
  that default. Dumb entry input accepts exactly `label`, `N x label`, or
  `N UNIT x label`, where `N` uses `.` as its decimal separator, `x` has
  surrounding whitespace, and `UNIT` is one non-whitespace Unicode token.
  The confirmation or batch preview always renders the parsed label, amount,
  and unit separately before commit. Unit normalization is Unicode case-fold
  plus surrounding-whitespace removal; the core performs no conversion,
  plural interpretation, or dimensional inference. Quantity addition is
  valid only for equal normalized units. Editing exposes label, amount, and
  unit as separate fields rather than reparsing the display form.
- **MOD-064 [standard] — Delegation state follows observed responsibility.** A
  durable Delegation is either `proposed` or `active`, or has exactly one
  terminal outcome: `completed`, `cancelled`, `taken_back`, or `reassigned`.
  Proposed means its target, coverage, follow-up policy, review delay, handoff
  method, and initial message have been accepted internally, but no handoff is
  known; it suppresses no human work. Active begins only with WRK-058's
  observed handoff and suppresses human execution only for its explicit
  coverage. A reported completion, refusal, progress update, or lack of
  response is an attributed observation awaiting or supporting a transition,
  never another lifecycle state. Terminal history remains attached to the
  Delegation and never becomes a Wait or another Brick. Two nonterminal
  Delegations may not cover the same execution responsibility; a builder that
  would overlap current coverage must edit, take back, reassign, or narrow it
  explicitly before confirmation. Disjoint sibling coverage remains valid.

- **MOD-077 [core] — Nature behavior is one closed capability profile.** The
  following matrix is sufficient to derive every factory source-to-target
  reclassification. Empty cells mean that the Nature does not own that
  capability; they are not permission to invent a fallback.

  | Nature | lifetime | execution boundary | owned structure | required target builder | closure behavior |
  |---|---|---|---|---|---|
  | `atomic_task` | finite | the Brick | none | none | direct `done` |
  | `project` | finite | the Brick until decomposed, then child Bricks | finite child parts | none | final child releases scope review |
  | `collection` | standing | independently selected child Bricks | open child members | none | explicit retirement only |
  | `repeatable` | standing | one run of the Brick | none | none | finish or choose one completion-relative return |
  | `living_checklist` | standing | owner and open entries together | continuing ListEntries | none | finishing a run leaves the owner active |
  | `finite_checklist` | finite | owner and entries together | finite ListEntries | none | finished entries release scope review |
  | `recurring_obligation` | standing | independently released occurrence Bricks | generated occurrences, never manual parts | recurrence rule | occurrences close independently; series retires explicitly |
  | `habit` | standing | one expiring opportunity | none | fixed-slot or quota-window schedule | window outcomes extend history; owner retires explicitly |
  | `scheduled_commitment` | anchored finite | the exact commitment interval | optional preparation child Bricks | zoned interval | attended, missed, or cancelled outcome |

  Lazy axes such as phase and effort, ordinary relationships, and Template
  provenance are outside this profile. A generated occurrence is an ordinary
  independently identified Brick after release, but generation remains a
  capability of its series rather than a kind of manually managed child part.
- **MOD-078 [core] — Reclassification first preserves universal truth.** For
  every source and target Nature, the existing UUID, handle, title,
  description RawLink, sibling importance and evidence, direct Domains,
  ordinary compatible relationships, annotations, source provenance,
  Template provenance, terminal historical runs or windows, and complete
  typed history carry forward unchanged. Target-required builders in MOD-077
  run before reconciliation and preview. A target with an incomplete or
  invalid builder cannot be accepted. History is never converted to make it
  look native to the new Nature: past habit windows do not become obligation
  occurrences, for example.
- **MOD-079 [core] — Structure changes by explicit disposition, never
  conversion.** Equal owned-structure capabilities retain current live
  structure. `project` to `collection` retains child Bricks and removes only
  finite-scope closure; `collection` to `project` retains them only after the
  preview confirms that the current child set represents a finite outcome.
  Leaving a child-owning Nature requires every active direct child to be moved
  to another valid parent or root, or the change is cancelled. Leaving a
  checklist Nature requires every open ListEntry to be resolved or cancelled,
  or the change is cancelled. Closed entries remain historical. Entering a
  child-owning or checklist Nature starts empty unless the same atomic preview
  explicitly adds valid children or entries. A child Brick never converts to
  a ListEntry, a ListEntry never converts to a Brick, and a recurring
  occurrence never converts into either merely because its series changes.
- **MOD-080 [core] — Standing and anchored state has one explicit stop rule.**
  Leaving `repeatable` retires its future-return rule but retains prior runs.
  Leaving `recurring_obligation` stops future releases only after every open
  occurrence is independently resolved or moved out as ordinary Work; already
  closed occurrences remain history of the series. Leaving `habit` stops
  future windows only after any currently open opportunity is settled as
  `done`, unfulfilled, blocked, paused, or inapplicable. Leaving an active
  `scheduled_commitment` is unavailable until that interval is attended,
  missed, or cancelled. Its preparation children follow MOD-079, and any
  still-relative temporal constraint must be converted to an explicit
  absolute constraint or removed in the same preview. Entering a standing or
  anchored capability creates no retroactive runs, windows, occurrences, or
  intervals.
- **MOD-081 [core] — Focus consequences are disclosed and atomic.** Current
  focus and WIP survive only when the target still exposes that same Brick as
  an executable focus unit at the acceptance instant. A change that transfers
  execution to children, entries, a generated occurrence, a habit window, or
  a future interval closes the current focus interval and clears invalid WIP
  in the same preview; it never claims completion. If live focus or WIP cannot
  be reconciled truthfully, the change is unavailable. Reclassification,
  required target configuration, every accepted disposition, and focus
  consequence commit as one revalidated batch. Semantic undo restores the
  complete prior Nature snapshot and all batch members only while their
  recorded compensation preconditions still hold; otherwise it explains the
  intervening conflict and changes nothing.
- **MOD-082 [standard] — The listed standard Templates ship offline.** Every
  Template in the [standard Template catalog](standard-template-catalog.md)
  is a Little Ant 1.0 built-in recipe, not a pending release candidate. Each
  adds inspectable classification guidance, creation defaults, or structure
  beyond merely renaming its root Nature. Specialized integrations and
  uncommon domain recipes may remain in Packs, but ordinary daily-use
  Templates are deliberately broad in the offline product.
- **MOD-083 [core] — Terminal child outcomes release review, not completion.**
  A finite parent has unfinished child scope while any direct child is
  `active`. When none remains active, `done`, `archived`, `superseded`,
  `merged`, `missed`, and `cancelled` children all satisfy the mechanical
  no-active-child boundary and release one scope-closure review. The review
  reports the count of each outcome separately. It never treats archive,
  replacement, deduplication, absence, or cancellation as completion and never
  completes the parent automatically. Restoring or adding an active child
  invalidates that review.
- **MOD-089 [core] — Missed and cancelled are narrow terminal truth.** In 1.0,
  only a `scheduled_commitment` may enter Brick status `missed` or `cancelled`.
  `missed` means its externally anchored interval passed without attendance;
  `cancelled` means the commitment ceased to apply. Neither is `done`, archive,
  skip, or an inferred source outcome. `attended` is the commitment-specific
  successful outcome and closes the Brick as `done`. Missed and cancelled
  Bricks are excluded from execution and current importance exactly like other
  terminal Bricks, remain searchable and inspectable, and do not create an
  archive-relevance review. Reopening either requires an explicit replacement
  interval and preview; `/restore` is only for archived Work.
- **MOD-084 [core] — Parent archive always declares its scope.** Archiving a
  Brick without children affects that Brick only. With direct children, the
  human must choose `this Brick only` or `entire subtree`. The first moves all
  direct children to the archived Brick's former parent, or root, as one
  provisional contiguous sibling run preserving their relative order and
  complete internal subtrees. The second archives every active descendant;
  already terminal descendants retain their exact terminal outcome. Both
  variants preserve history and require the gate reconciliations in WRK-129.
  No archive command silently reparents, completes, supersedes, or merges any
  descendant.
- **MOD-085 [core] — Merge and supersede answer different questions.** Merge
  is valid only when two durable Bricks represent the same intention or
  responsibility and one identity should survive. The absorbed Brick becomes
  terminal `merged` with an explicit `merged_into` lineage edge and remains
  inspectable under its retired handle; commands never silently redirect that
  handle. Supersede is valid only when distinct newer Work replaces older
  Work; the old Brick becomes terminal `superseded` with a `superseded_by`
  lineage edge. “Mark duplicate” is not a third mutation: duplicate suspicion
  may end in merge, supersede, or keep separate.
- **MOD-086 [core] — Merge uses one closed transfer matrix.** The human first
  chooses the surviving Brick. The following rules then determine every
  category; `choose` means that a conflict must be resolved before the final
  preview.

  | Category | Merge into survivor |
  |---|---|
  | identity, handles, lifecycle | survivor UUID and handle remain; loser becomes `merged`; terminal-status conflict is `choose` |
  | title, Nature, current phase | equal values coalesce; differing values are `choose`, and Nature uses MOD-077..081 |
  | Template provenance | survivor provenance remains active; loser provenance remains attributed merge history |
  | parent and child structure | one parent is `choose`; children union by UUID and must fit survivor capability; cycles or duplicate scope are reconciled |
  | sibling importance | survivor keeps evidence in the chosen parent; compatible loser edges in that same sibling group retarget, self-edges vanish, and all other edges become inactive history |
  | Domains | union direct memberships, deduplicated |
  | RawLinks and annotations | union exact direct links, deduplicated; two descriptions are `choose` and no Raw is copied |
  | Dependencies | union directional edges; merge-created self-edges vanish; any new cycle is `choose` edge by edge |
  | Waits | distinct active gates remain; equivalent gates are `choose` between keeping both or closing one as duplicate, never inferred response |
  | dates | one-sided values carry; unequal values of the same meaning are `choose`, never silently tightened |
  | recurrence, runs, windows, occurrences | closed history unions by identity; incompatible active state uses MOD-077..081 and never combines two live opportunities |
  | Delegations | disjoint coverage may carry; overlapping nonterminal coverage is `choose` through take-back, reassignment, or narrowing |
  | focus and WIP | survivor retains compatible WIP; loser focus may retarget only when the same executable unit survives, otherwise explicit pause/clear is previewed |
  | pending and dispatched effects | pending effects are cancelled or reissued explicitly; dispatched receipts remain on their originating history |
  | SourceBindings and external provenance | union distinct bindings; equal provider identity with conflicting baselines enters ordinary source reconciliation |

  Historical events never change subject UUID. Inspection of an absorbed
  history shows both its original subject and the surviving Brick.
- **MOD-087 [core] — Supersede transfers nothing by resemblance.** Existing
  replacement facts remain unchanged. A newly drafted replacement may visibly
  propose the old parent, direct Domains, and a provisional sibling position
  near the old Brick, but acceptance is explicit. Identity, title, Template
  provenance, importance comparisons, history, RawLinks, annotations,
  SourceBindings, occurrence history, and dispatched-effect receipts remain
  with the old Brick. Children are explicitly moved to the replacement when
  it can own them, or moved one level up under MOD-084's ordering rule. Each
  inbound or outbound Dependency, Wait, date, recurrence rule, Delegation, or
  pending effect is individually kept with the old history, closed, retargeted,
  or recreated through its typed manager. No category silently follows the
  `superseded_by` edge.
- **MOD-088 [core] — Lifecycle composition is one atomic reviewed batch.** A
  merge, parent archive, subtree archive, or supersede preview names scope,
  terminal outcomes, movement, transferred facts, retained facts, conflicts,
  gates, focus/WIP, external effects, and resulting reviews before one
  confirmation. Every unavailable reconciliation is an educational stop.
  Acceptance revalidates the complete write set and commits all members or
  none. Dry-run returns the same preview without mutation. Undo uses UX-198
  `batch` compensation and is rejected after any dependent structural,
  lifecycle, gate, source, or effect change rather than partially splitting
  the operation.

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
  inactive history. Direct Domain memberships remain unchanged under MOD-061.
- **MOD-032 [core] — Coverage follows structure.** Adding, moving, or removing
  relevant descendant scope reopens decomposition coverage for affected finite
  parents and may create a scope review; it never rewrites unrelated evidence.
- **MOD-033 [core] — Date constraints accumulate.**

  ```text
  effective_not_before = latest value on self and ancestors
  effective_best_before = earliest value on self and ancestors
  effective_deadline = earliest value on self and ancestors
  ```

- **MOD-034 [standard] — Inheritance must be explicit.** Domain membership is
  direct-only under MOD-061, and MOD-068 makes RawLinks, requester,
  responsible actor, and `about` direct-only as well. V1 has no generic
  inherited domain-model mode. Implementations must not infer any of these
  relations from ancestry or the old free-text `context` field.

## Nature behavioral boundaries

- **MOD-035 [standard] — Living checklist.** A `living_checklist` is one
  durable Brick that owns changing ListEntries. When it has open entries,
  `next` serves the parent as the focus unit and one checklist surface makes
  the complete open set available together. A bounded viewport may show only
  part of a large set when it also exposes exact counts and deterministic
  scrolling. Resolved entries remain in history. An empty list is dormant
  rather than done, and adding a new entry makes it eligible again.
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
  Nature-owned ListEntries only where the receiving Brick's validated
  structural capability permits them. A root may therefore create a child
  checklist whose own Nature owns entries; it cannot make any incapable
  receiving Brick own either structure family. Every created Brick still has
  exactly one validated Nature. Accepted expansion becomes ordinary canonical
  state;
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
  `break` or Structure `parts` first determines whether finishing the planned
  parts should finish one outcome (`project`) or whether members may remain
  open-ended (`collection`), then collects the proposed child Bricks and
  previews that Nature change with the batch. `finite_checklist` is never a
  parts result: it owns ListEntries reached only through `list items`. A mere
  prerequisite remains an orthogonal Dependency and does not
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
  no runtime authority. Preparation children remain ordinary user-maintainable
  Bricks, but they do not replace the scheduled commitment as its own focus
  unit or weaken hard interval precedence. Manually adding one creates no
  relative-time anchor by inference; anchor editing remains under the
  scheduled-commitment timing contract.
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
  distinguishable from the original; MOD-071 defines revision attribution and
  stale-normalization behavior.
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
- **MOD-054 [core] — Raw Inbox is derived.** The Inbox is the view of active
  Raw material for which no triage disposition has been accepted. It is not a
  RawShelf, Domain, parent, Nature, or storage owner. Accepting a standalone,
  shelf-membership, attachment, ListEntry, or Work disposition removes the
  Raw from that view without deleting, transforming, or archiving it. Leaving
  triage pending keeps it in the Inbox and available to later review.
- **MOD-065 [core] — Raw content has four representations and immutable
  revisions.** Each Raw content revision is exactly one of `text`, `uri`,
  `blob`, or `structured`. Text stores Unicode text; URI stores one absolute
  identifier and an optional source-supplied label; blob stores bytes by
  cryptographic digest plus media type, byte length, and optional filename;
  structured stores canonical JSON plus a versioned schema identifier. Every
  accepted edit appends a revision with its UUID, ordinal, recorded instant,
  provenance, representation, payload or blob reference, and digest. The
  original and all superseded revisions remain addressable; `current_revision`
  is a projection, never an overwrite. A representation change requires the
  same edit preview as a content change.
- **MOD-066 [core] — Revision versus derivation is an explicit human
  distinction.** A corrected or newer representation of the same material is
  a revision of the same Raw. An extraction, summary, transcription,
  compilation, or independently meaningful artifact is a new Raw linked with
  `derived_from`. A derivation may cite several source Raws, forms an acyclic
  graph, and never archives or revises its sources. English normalization is
  the deliberate exception in MOD-049: it remains attributed metadata on one
  source revision and never becomes another Raw.
- **MOD-067 [core] — RawLink has a closed small role catalog.** The v1 roles
  are `description`, `materialization_source`, `attachment`, `evidence`, and
  `derived_from`. Description targets one Brick and obeys MOD-057; its current
  Raw revision must be text. Materialization source targets a Brick or
  ListEntry. Attachment and evidence may target a Brick, ListEntry, or Raw.
  Derived-from connects a derived Raw to one or more source Raws. Except for
  description, roles are many-to-many ordered sets: link acceptance order is
  the default display order and explicit reordering changes only that order.
  Note and URL are content meanings, not extra roles; import provenance is a
  SourceBinding, not a RawLink. Detach always preserves both endpoints.
- **MOD-068 [core] — Content relationships are direct-only.** RawLinks,
  requester, responsible actor, and `about` relationships never inherit
  through composition. A surface may separately show ancestor context, but it
  cannot present it as a relationship of the child. Domain membership remains
  direct-only under MOD-061. V1 has no generic inherited domain-model `mode`:
  dumb/powered-up is a surface capability, while Place, Domain, time, and
  explicit relations express operational context.
- **MOD-069 [standard] — RawShelf is a flat, many-to-many semantic organizer.**
  A RawShelf has identity, name, lifecycle, and ordered direct Raw membership.
  One Raw may appear on several shelves. Shelves do not nest, own files,
  convey provenance, grant Domain membership, become Work, or define review
  state. Rename preserves identity; archive hides the shelf without archiving
  members; merge unions membership after a preview and retains lineage.
- **MOD-070 [core] — Raw lifecycle is reversible.** Raw lifecycle is
  `active | archived`. Archive removes it from ordinary active views and
  source checking but preserves revisions, links, shelf/Domain memberships,
  origins, and history; unarchive restores them. V1 exposes no per-Raw
  permanent delete. Whole-dataset destruction and physical retention policy
  are administrative boundaries, not domain events disguised as deletion.
- **MOD-071 [core] — English normalization is revision-scoped.** One Raw
  revision may have at most one current canonical-English normalization,
  carrying normalized text, source (`human | powered_up | skill | import`),
  producer identity/version when applicable, acceptance instant, and optional
  confidence. Replacing it appends history. A later content revision makes the
  prior normalization `stale`; it remains inspectable but is not silently
  copied forward. Non-text material gains normalization only from an explicit
  accepted textual extraction; a URI itself, filename, or opaque bytes are
  never presented as translated content.
- **MOD-072 [standard] — Raw Domain classification is optional and direct.** A
  Raw may belong directly to zero or more existing Domains for retrieval. Its
  membership neither creates Work nor affects focus eligibility, composition,
  shelves, SourceBindings, or the membership of linked records. Domain moves
  change the rendered path without rewriting the Raw relationship.
- **MOD-073 [core] — Domains form one identity-stable forest.** V1 has one
  Domain forest with any number of roots; each active Domain has at most one
  parent and a nonempty English canonical name unique among active siblings.
  Equal leaf names under different parents are valid and always render through
  their complete `›` path. Rename or move preserves identity. Multiple
  parallel taxonomy systems and negative/exclusion membership are not v1
  concepts.
- **MOD-074 [core] — Domain lifecycle never changes its members' lifecycle.**
  A Domain is `active | archived`. Archiving a subtree preserves every direct
  Brick/Raw membership and descendant identity but removes the path from
  ordinary active classification and scoped draws; no member is archived,
  moved, or completed. The preview must clear or retarget an active Domain or
  hard scope inside the subtree. Restoring revives the same paths and
  memberships.
- **MOD-075 [core] — Domain movement and merge preserve direct truth.** Moving
  a Domain moves its complete subtree after cycle and sibling-name validation,
  changes rendered paths, and leaves direct memberships untouched. Merge
  chooses one survivor, unions direct members and children, retargets active
  Domain/scope, preserves lineage, and first resolves any resulting sibling
  name conflict explicitly. Neither operation changes composition, importance,
  or RawShelf membership; both provide dry-run and typed undo as an atomic
  structure batch.
- **MOD-076 [standard] — Recursive Domain queries are unique projections.** A
  direct query returns only direct memberships. A recursive query includes the
  selected Domain and descendants, deduplicates a record with several matching
  memberships, and reports direct, descendant, and unique totals separately.
  Natural questions such as “how many Bricks are in R&D?” use recursive scope
  by default and show the resolved full path; an ambiguous leaf opens the
  ordinary typed selector.

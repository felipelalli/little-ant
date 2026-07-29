# 5. Raw material

## 5.1 Meaning

`Raw` replaces the current terminal `RawInput` extraction model.

- Raw is material, not work.
- Raw is never inserted into the priority tree.
- Raw is never directly focused.
- Raw is durable and reusable.
- Using Raw does not consume it.
- One Raw may be referenced by many Bricks and many RawShelves.
- One Brick or RawShelf may reference many Raws.
- Reviewing Raw may produce zero, one, or many Bricks.
- A Raw may also remain useful only as a source or attachment.

A Brick description remains canonical English content owned directly by the
Brick. It is not wrapped in a generic Artifact or automatically converted into
Raw. Verbatim input, supporting material, evidence, and external content may
be retained separately as Raw and linked with explicit provenance.

A structured list occurrence is not Raw merely because it is not independently
focusable. `Milk` in a grocery list is normally a ListEntry. A product URL,
receipt, coupon, image, or recipe may be Raw attached to that entry or its
owning Brick.

## 5.2 Two orthogonal state axes

Raw has two independent state axes:

```text
review  = pending | reviewed
storage = active  | archived
```

Confirmed behavior:

- A new Raw begins as `pending` and `active`.
- Review completion is explicit and may record zero or many dispositions.
- Creating the first Brick from a Raw does not automatically mark it reviewed.
- A reviewed Raw may be reopened.
- Archiving is reversible through unarchive.
- Archiving does not change the review state.
- Unarchiving restores visibility with the previous review state intact.
- Archived Raw is excluded from ordinary views and ordinary proposals.
- The product term is **archive**, not delete or close.
- Raw has no `done` operation. `review`, `reopen`, `archive`, and `unarchive`
  change only the two explicit Raw axes.
- Natural language such as “done with this material” is interpreted by the
  REPL or operator as a proposal to review, archive, or identify real Brick
  work; the core never materializes a Brick merely to make `done` accept Raw.

Permanent deletion and blob garbage collection remain open.

## 5.3 External origin and immutable snapshots

A Raw has zero or one external `RawOrigin`.

- Inline text or bytes have no external origin. `inline_text` and
  `inline_blob` describe feeding or storage forms, not origin kinds.
- An external origin records an adapter kind, live locator, optional stable
  external identity, last check time, and last observed external revision.
- Origin observation history keeps external work state separate from external
  presence or reachability. Completion, disappearance, and access failure are
  not interchangeable facts.
- Exact adapter kinds and field names remain open. Expected examples include
  a filepath, URI, URL, GitHub issue, or another adapter-supported upstream
  object.
- Moving or replacing an origin preserves its history.
- A retired migration profile makes the origin historical rather than
  deleting it. Its locator and stable identity remain provenance, while
  ordinary source-freshness pressure stops.
- A mirror, fork, local draft, or separately published copy is another Raw,
  normally connected through a `derived_from` RawLink. It is not a second
  origin hidden inside the same Raw.

A `RawSnapshot` preserves one snapshotted content version:

- Snapshots are immutable, content-addressed, and versioned.
- Identical content hashes are deduplicated.
- Content deduplication does not merge distinct Raw entities or feeding
  events.
  Distinct provenance remains distinct even when immutable bytes share storage.
- All distinct versions are retained.
- Large bytes do not belong inline in JSONL. JSONL stores hashes and metadata;
  a blob store lives adjacent to the Little Ant data directory.
- The bytes referenced by a RawSnapshot are logically part of the Little Ant
  dataset and participate in backup and synchronization by default.
- A metadata record whose referenced blob is absent or fails hash verification
  is an explicit incomplete or corrupted state, not a valid metadata-only
  snapshot.
- A locator or observed external revision without snapshotted bytes remains
  RawOrigin information; it does not pretend that a RawSnapshot exists.

The core owns logical blob identity, content-hash verification, reference
integrity, and explicit availability state. It does not require or assign
semantic authority to Git. Immutable snapshot history comes from domain events
and hashes; Git, Git LFS, Syncthing, an object store, or another mechanism may
transport and back up the same logical dataset.

A replica may be temporarily incomplete while bytes are transferring, but it
must expose that condition and must not silently serve the missing snapshot as
available. A future storage adapter may tier or fetch bytes on demand without
changing RawSnapshot identity or provenance.

Expected snapshot metadata:

```text
snapshotted_at
content_hash
size
media_type
origin_revision  # when supplied by an external origin
```

Expected RawOrigin metadata:

```text
adapter
locator
external_id       # optional stable upstream identity
last_checked_at
last_observed_revision
```

External work state, presence, observation authority, source-container state,
and migration-cleanup provenance also require typed history. Their exact event
and projection fields remain open rather than being compressed into one
mutable “source status.”

RawOrigin locators are typed adapter data, not a universal public mention
grammar embedded in prose. A surface may accept a pasted standard URI or an
adapter-supported external reference and propose explicit Raw feeding. The
adapter may then normalize it into `adapter`, `locator`, and `external_id`
without requiring the user to type a provider-specific scheme.

Identifiers such as `github:...`, `gmail:...`, or `gchat:...` may exist inside
an adapter contract, import key, or normalized locator. They do not become a
single core-wide language whose appearance in arbitrary text creates a
RawOrigin. Until feeding is confirmed, a URI or provider-shaped token remains
literal input.

## 5.4 Check, refresh, and reconciliation

A Raw may have an optional freshness policy such as `max_age`.

- `check` asks an adapter to observe the external revision or fingerprint.
- If the revision is unchanged, only `last_checked_at` advances.
- If it changed, `refresh` may explicitly fetch and append a new immutable
  snapshot; it never overwrites an older snapshot.
- A new snapshot is stored only when its content or attributable upstream
  revision changed.
- Fetching external content is never a silent network or filesystem side
  effect.
- A changed Raw does not by itself imply a semantic conflict. Reconciliation
  belongs to each RawLink whose role makes that version relevant to a Brick.
- A source relationship records the snapshot last reconciled with that Brick.
  Several Bricks may therefore reconcile the same refreshed Raw independently.
- `write_back` remains a separate externally approved effect.
- External deletion is never Raw archival or Brick completion. An authoritative
  provider tombstone changes only the observed external-presence history.
- Missing results from a filter, an inaccessible account or container, and a
  failed refresh do not prove deletion.
- A confirmed active ImportProfile may authorize recurring read-only checks,
  refreshes, and feeding runs. Deletion from the source still requires a separate
  destructive migration plan and approval.
- Current, changed, unavailable, and reconciliation-needed conditions are
  derived from check history, snapshots, and per-link baselines rather than a
  mutable `diverged` boolean.
- `last_checked_at` advances even when content is unchanged.
- Refresh failures, retry/backoff behavior, and missing-file behavior remain
  open.

## 5.5 RawLink

A `RawLink` records why a Brick, ListEntry, or another Raw refers to Raw.
Working role names include:

```text
attachment | source | evidence | derived_from
```

The exact minimal vocabulary remains open. Roles must have explicit semantics:

- an attachment is informational and does not automatically create
  reconciliation pressure;
- a source identifies material whose newer snapshot may require the linked
  Brick to be reassessed;
- evidence pins the attributable version used for a judgment;
- `derived_from` preserves provenance between distinct Raw material.

Behavioral relationships such as parent, dependency, wait, delegation,
requester, and `about` do not become RawLink roles.

## 5.6 RawShelf

`RawShelf` is the selected name for reusable Raw groupings.

- Shelves are flat; shelves cannot contain shelves.
- Shelf membership is unordered.
- Raw-to-shelf membership is many-to-many.
- A shelf is material, not work, and has no priority position.
- A shelf does not appear directly in `next`.
- If consuming, synthesizing, or reviewing a shelf is work, the user creates a
  Brick that points to that shelf.

The exact RawLink vocabulary and RawShelf membership event grammar remain
open.

## 5.7 Source views and imported material

Grouping by provider, account binding, or external container is derived from
RawOrigin. It is a source view used for inspection, refresh, reconciliation,
and triage, not a RawShelf. The system does not create a provider-named shelf
merely because material came from Microsoft To Do, Evernote, or another
adapter.

A confirmed ImportProfile may separately add imported material to a semantic
RawShelf. It may also route structured work to a Brick parent, collection, or
ListEntry owner. Provenance grouping is automatic; semantic grouping is
explicit policy.

Feeding an external structured task always preserves Raw provenance, but it
need not stop at pending Raw. A configured task source may atomically feed
the Raw and adopt it into a positioned Brick or ListEntry. Unknown, mixed, and
note-like sources remain pending Raw until reviewed. See
[External imports, source views, and extension packs](32-external-imports-source-views-and-extension-packs.md).

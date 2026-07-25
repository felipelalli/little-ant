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

Permanent deletion and blob garbage collection remain open.

## 5.3 Origins and snapshots

A Raw keeps its origin and may preserve immutable snapshots.

Proposed canonical origin kinds, accepted as the current direction:

```text
inline_text | inline_blob | url | uri | filepath
```

Rules:

- Inline content is already preserved by the event log or adjacent blob
  storage.
- A URL, URI, or filepath retains its live locator.
- Capturing a URL or filepath should ask whether a local copy should be
  preserved.
- Additional snapshots may be captured or refreshed later.
- Snapshots are immutable, content-addressed, and versioned.
- Identical content hashes are deduplicated.
- All distinct versions are retained.
- Large bytes do not belong inline in JSONL. JSONL stores hashes and metadata;
  a blob store lives adjacent to the Little Ant data directory.

Expected snapshot metadata:

```text
captured_at
content_hash
size
media_type
```

Expected source metadata:

```text
last_checked_at
source_updated_at  # only when supplied by the origin
```

## 5.4 Freshness

A Raw may have an optional freshness policy such as `max_age`.

- Stale Raw may produce a weighted `refresh_raw` proposal.
- Refreshing an external source is never a silent network side effect.
- Once the human accepts the refresh, the source is checked.
- A new snapshot is stored only when its content changed.
- `last_checked_at` advances even when content is unchanged.
- Refresh failures, retry/backoff behavior, and missing-file behavior remain
  open.

## 5.5 RawShelf

`RawShelf` is the selected name for reusable Raw groupings.

- Shelves are flat; shelves cannot contain shelves.
- Shelf membership is unordered.
- Raw-to-shelf membership is many-to-many.
- A shelf is material, not work, and has no priority position.
- A shelf does not appear directly in `next`.
- If consuming, synthesizing, or reviewing a shelf is work, the user creates a
  Brick that points to that shelf.

The exact relationship vocabulary between Raw, RawShelf, Brick, source, and
attachment remains open.

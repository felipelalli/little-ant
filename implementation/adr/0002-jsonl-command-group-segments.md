# ADR 0002 — Immutable JSONL command-group segments

Status: **accepted for implementation; frozen before later event kinds**

## Context

The canonical contract requires an append-only JSONL authority, atomic command
groups, deterministic replay from zero, explicit event upcasting, bounded
writer contention, and a canonical cursor suitable for optimistic response
validation. It intentionally does not prescribe a self-referential on-disk
hash layout.

## Decision

Each accepted command group is one immutable file in `events/` named:

```text
<20-digit-sequence>-<sha256-of-exact-file-bytes>.jsonl
```

Every line is one versioned event envelope. The envelope records schema,
event type and version, event and command UUIDv7 identities, segment and event
sequence, actor, recording time, previous accepted segment hash, command
precondition hash, replay facts, and typed payload. The file hash remains in
the filename rather than inside the bytes it hashes.

The canonical dataset cursor is `genesis` for no accepted segment or
`<20-digit-sequence>:<sha256>` for the current head. A segment is prepared in a
dot-prefixed temporary file, flushed and fsynced, atomically renamed to its
content-addressed name, then followed by a directory fsync. Replay ignores
temporary files and rejects gaps, hash-chain disagreement, filename/content
hash disagreement, malformed accepted bytes, and unknown event versions.

One bounded interruptible advisory writer lock covers head validation and
publication. Lock timeout is a typed retry-safe conflict and writes nothing.
Pure upcasters convert accepted old event versions before the fold; they never
rewrite accepted history.

## Consequences

- A command group is either wholly absent or wholly visible.
- Exact accepted bytes can be copied, verified, and replayed independently.
- The cursor is compact and does not require a mutable manifest.
- Multiple events from one command share one segment and command identity.
- Any future chunking or compaction remains a disposable projection concern;
  it cannot replace replay equivalence or mutate the accepted log.

## Alternatives rejected

Embedding a segment's own hash in the segment creates a needless fixed-point
problem. One file per event weakens command-group atomicity. A mutable head
manifest creates a second authority and a crash-recovery protocol. A single
ever-growing JSONL file makes atomic multi-event publication and content
addressing substantially harder.

## Evidence

The S01 walking-skeleton suite exercises accepted-file hashing, previous-hash
validation, current and upcasted corpora, torn temporary files, malformed and
unknown accepted events, lock contention, dry-run, restart, compensation, and
replay-derived cursor equality.

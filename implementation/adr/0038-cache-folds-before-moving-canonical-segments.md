# ADR 0038 — Cache folds before moving canonical segments

Status: accepted for implementation following the user's October 12 request.

The migrated snapshot/hot-log/cold-archive Work described a v0 monolithic log.
V1 already stores each accepted command group in an immutable JSONL file with
its sequence and SHA-256 in the filename. Repacking those groups into one
quarterly JSONL file would erase that physical validation boundary. Store
therefore retains each file unchanged inside `archive/YYYY-QN/`.

After 128 accepted groups since the last valid cache, the exclusive writer
validates the complete canonical fold. It writes and fsyncs the fold snapshot,
atomically replaces the cache, and fsyncs its directory before moving any
covered group. Each move writes and fsyncs a hidden temporary cold copy,
renames and fsyncs the cold directory, then unlinks and fsyncs the hot copy.
The quarter uses the first event's recorded UTC instant; a group never splits.
An interruption leaves either a hot file, a cold file, or identical copies.
Complete replay coalesces only identical copies and rejects divergent ones.
Readers resolve moved hot paths by their unchanged name in cold storage.
Cached readers also compare the snapshot generation before and after replay,
retrying if another writer published a cache while reading its hot suffix.

`fold-snapshot@1` wraps the cursor, complete accepted count, and typed State
payload in a SHA-256 checksum. The private `fold-state-binary@2` codec uses
Binary with explicit identity/time codecs and generic model records, avoiding
any change to accepted event or public JSON schemas.
Its exact model representation is disposable: decoding incompatibility or a
checksum failure ignores it and replays canonical history. Changes to fold
semantics or the cache model must bump the cache format rather than reusing an
old semantic cache. The loader also requires the named cursor segment to
exist. Cached boot reads hot bytes only; archive metadata locates the boundary.
Its progress counter counts suffix records actually decoded during that load,
while `loadedEventCount` retains the complete count.

Doctor, repair candidates, and history always validate hot and cold canonical
bytes. They do not trust a snapshot to certify old history. A healthy cache
can therefore accelerate startup while an explicit diagnostic still detects
later damage to an immutable cold file. A backup includes hot segments, cold
segments, and blobs; the cache can be omitted. Repair candidates flatten all
canonical segments into their new events directory and rebuild projections.

This is physical history rotation, independent of Brick status. It never
drops a live identity, handle, recurrence rule, closed cycle, or focus fact.
Archiving or restoring Work still requires its ordinary semantic events.
Automatic cache/rotation failure does not turn an already committed command
into an apparent failed command; explicit `compactDataset` returns its typed
failure, and full diagnostics remain available. Device event-set union and
online synchronization are outside this change.

The October 13 retired-prerequisite correction adds the removed Dependency
state and changes lifecycle folds. Format 2 rejects format 1 snapshots, so
existing canonical histories rebuild their inactive retirement edges before
accepting a new cache. No canonical event bytes or identities are rewritten.

# 30. Domain authority, blobs, and rebuildable projections

## 30.1 Authoritative operational dataset

The append-only domain event log is authoritative for Little Ant operational
state. Deterministic replay with versioned upcasting derives current entities,
relationships, orders, histories, and projections from accepted events.

“Plain text is the source of truth” is too broad when read literally. A
RawSnapshot may reference immutable bytes that are logically part of the
dataset:

```text
authoritative operational dataset =
  domain event log
  + every referenced canonical blob
```

The event log owns the fact that a snapshot exists, its content hash,
provenance, and relationships. The referenced bytes provide the content. A
missing or hash-invalid canonical blob makes the dataset explicitly incomplete
or corrupt; it is not reconstructed from a database projection.

## 30.2 Rebuildable projections

A database, search engine, index, materialized view, cache, or analytical store
may accelerate queries. It is permitted only as a derived projection when used
for operational domain state.

A rebuildable projection:

- is derivable from the authoritative events and applicable canonical blobs;
- records enough schema version and event-log cursor information to detect
  staleness or incompatibility;
- may be deleted and rebuilt without losing accepted domain information;
- never becomes the only copy of a canonical event, relationship, annotation,
  comparison, occurrence, or blob;
- accepts no domain mutation that bypasses the ordinary core operation and
  event-append path;
- fails explicitly when its source dataset is incomplete rather than treating
  cached data as new authority.

The choice of SQLite, another database, an embedded search index, or no
projection at all is an implementation decision. The observable requirements
are deterministic replay, integrity, explicit incompleteness, and equivalent
canonical results.

## 30.3 Other persistent artifacts

Not every persistent file is a domain projection:

- a REPL checkpoint is temporarily authoritative only for presentation
  recovery, such as the current dialog, cursor, and unsent draft; it cannot
  create accepted domain state;
- an immutable planning manifest records one confirmed external simulation
  outside operational domain state;
- a Little-Ant-owned encrypted credential vault and CredentialBindings have
  separate local deployment authority and must not be smuggled into events,
  domain projections, Packs, or ImportProfiles;
- backups and replicas preserve authoritative data but do not define new
  domain semantics.

Losing a disposable projection may reduce performance. Losing a REPL checkpoint
may lose recoverable presentation state. Neither loss changes accepted domain
history. Losing a referenced canonical blob is a material dataset failure.

The credential vault is excluded from ordinary dataset synchronization by
default. Backup or transfer requires an explicit encrypted export. Unlocking
places key material only in a transient local memory agent for a bounded idle
period; Pack code never receives a stored secret or access token. A locked
vault makes credential-dependent work explicitly unavailable without changing
domain history or pretending that the provider failed.

## 30.4 Documentation distribution

The final 1.0 documentation should distribute this rule by audience:

- `README.md` states the principle in one short sentence and links to this
  specification chapter;
- the Markdown record under `spec/little-ant-1.0/` explains event authority,
  blobs, replay, upcasting, projections, checkpoints, manifests, backup, and
  integrity boundaries;
- `spec/little-ant.allium` specifies only externally observable replay,
  integrity, and state behavior rather than prescribing SQLite or a physical
  file layout.

The README is an entry point, not the complete storage architecture.

## 30.5 Still open

- Event-envelope versioning and deterministic upcast contract.
- Canonical event-log segmentation, compaction without lost authority,
  integrity chaining, and corruption recovery.
- Projection cursor, schema-version, rebuild, and equivalence-test contracts.
- Backup and synchronization boundary across events, blobs, configuration,
  checkpoints, and planning manifests.
- Exact encrypted-vault format, cryptographic construction, recovery,
  rotation, revocation, idle timeout, and memory-agent IPC hardening.
- Whether any projection supports incremental repair or is always rebuilt
  wholesale.
- Exact user-visible behavior while a projection is stale, rebuilding, or
  unavailable.

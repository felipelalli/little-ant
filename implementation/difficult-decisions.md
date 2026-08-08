# Difficult implementation decisions

These choices close physical planning ambiguity without changing product
semantics. Canonical behavior remains in [`spec/`](../spec/little-ant-1.0.md).

## Allium is outside the 1.0 critical path

The prior Markdown → Allium → generated-tests path could validate an
intermediate interpretation after observable UX had already been lost. V1
therefore implements exact spec IDs directly through human-inspected golden,
property, state-machine, protocol, and scenario evidence. Allium is reconsidered
only for a concrete invariant not adequately expressed by those mechanisms.

## Command groups use immutable JSONL segments

The spec requires append-only JSONL, deterministic replay, and atomic semantic
batches but does not prescribe a physical transaction format. V1 uses one
atomically published immutable JSONL segment per accepted command group, with
one line per typed domain event. This keeps event granularity and a factual
loading counter while making a crash expose either the old segment set or the
complete new group—never a partially foldable command.

## Event history evolves additively

Later slices cannot reinterpret earlier event payloads when richer domain
types arrive. Accepted type/version meanings freeze; changes add versions and
pure upcasters. Every slice contributes byte-identical dataset fixtures to a
permanent full-replay corpus.

## Snapshots are projections, not events

Replay performance matters, but no snapshot event is reserved speculatively.
A projection checkpoint is disposable, cursor/hash-bound, verified against
full replay, and safe to delete. Canonical segments and blobs remain sufficient
to rebuild the product.

## Concurrency fails safely after bounded lock acquisition

REPL, CLI, and local web may race. A mutator takes an interruptible bounded
exclusive writer lock, then reloads and revalidates. It never steals a lock or
retries an already-decided event list. Timeout returns a typed retry-safe
conflict and no mutation.

## Dumb behavior is built first without hiding parity debt

Each flow has one implementation owner, but `implemented` does not mean
`verified`. Full verification waits for every evidence branch in the canonical
row. A trivial headless envelope client starts in S01 to test surface
independence early; powered-up, Skill, and local web still arrive only after
the dumb product is complete.

## Hash changes default to normative

Spec block hashes prevent silent drift, but legitimate errata remain possible.
An unclassified change invalidates evidence. Only a reviewed editorial change
may refresh hashes without reacceptance; normative changes demote affected
verified flows and require new failing-then-passing evidence.

## The release includes the complete standard ring

Imports, Packs, Calendar, TaskJuggler, local web, recurrence, delegation,
powered-up, Skill, credentials, and v0 migration remain v1 deliverables. The
slice order keeps them out of the minimal happy path but does not defer them to
a later product version.

## Library choices remain replaceable ADRs

The exact terminal backend, reviewed age implementation, and lower-level HsLua
libraries are implementation choices deliberately left out of product
discovery. S00/S08 record bounded ADRs after capability spikes. They may change
without changing envelopes, events, commands, or screens.

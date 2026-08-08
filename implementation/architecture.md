# Implementation architecture

This document fixes implementation topology, not product semantics. Canonical
rules remain in [`spec/`](../spec/little-ant-1.0.md).

## Functional core, imperative shell

All state-changing paths converge on one pure decision boundary:

```text
REPL key / CLI command / Skill action / web action
                       ↓
canonical parse and reference resolution
                       ↓
interaction/revision/precondition validation
                       ↓
pure decision kernel: State × Command × RuntimeFacts
                       ↓
Decision { domain events, typed result, next interaction }
                       ↓
atomic append and deterministic fold
                       ↓
canonical sparse JSON + human rendering
```

`RuntimeFacts` contains only explicit inputs required for a decision: clock,
allocated UUIDs, deterministic random blocks/cursors, actor/profile, terminal
or presentation capabilities when relevant, and externally observed facts.
Every fact that can affect replay is recorded in the accepted command group.

The REPL owns raw terminal input, local editing, navigation checkpoints,
rendering, and process lifecycle. It never owns eligibility, focus selection,
command availability, semantic actions, event writes, or integration logic.
This is the implementation boundary required by PRD-006 and UX-001..005.

## Canonical components

The initial Haskell package should grow along these boundaries. Exact module
splits may change within a slice when dependency direction remains intact.

```text
LittleAnt.Foundation      opaque IDs, revisions, time, fixed point, hashes
LittleAnt.Model           canonical records and closed enumerations
LittleAnt.Event           versioned event registry, codec, validation, fold
LittleAnt.Command         public registry, parsing, typed commands and errors
LittleAnt.Decision        pure command handlers and invariant validation
LittleAnt.Interaction     envelopes, actions, uncertainty routes, checkpoints
LittleAnt.Importance      evidence graph, ordering, confidence, judgments
LittleAnt.Forecast        admission, opportunities, weighted hierarchical draw
LittleAnt.Work            focus, symptoms, lifecycle, standing work, time
LittleAnt.Projection      sparse results, search, history, lists, status
LittleAnt.Store           dataset lock, immutable JSONL segments, blobs
LittleAnt.Effect          durable intent and receipt state machine
LittleAnt.Pack            manifests, HsLua host contracts, runner protocol
LittleAnt.Surface         pure screen model and human renderings
LittleAnt.REPL            terminal harness only
LittleAnt.Migration       isolated v0 preflight, candidate, and cutover
```

Only `lant` is public. `lant-pack-runner` and a profile-scoped vault agent are
private helper processes with closed protocols. The historical `la` executable
is removed under UX-204 rather than retained as a packaging alias.

## Dataset and atomic commands

The v1 dataset is a directory, not a database authority:

```text
dataset/
├── events/        immutable ordered *.jsonl command-group segments
├── blobs/         content-addressed canonical Raw material
├── checkpoints/   disposable UI checkpoints
└── projections/   disposable indexes and caches
```

One accepted command group is written as one new immutable JSONL segment. The
segment contains one line per typed domain event, preserves event identity and
order, and has a content hash tied to the prior accepted segment. The writer:

1. acquires the dataset's exclusive advisory writer lock;
2. reloads the current cursor and revalidates the command preconditions;
3. writes the complete next segment to a same-filesystem temporary file;
4. validates its lines, event sequence, hash chain, and fold result;
5. flushes the file, atomically renames it into `events/`, and flushes the
   directory;
6. releases the lock only after the new canonical cursor is observable.

A crash before the rename leaves no canonical command. A crash after the
durable rename leaves the entire command group. Incomplete temporary files are
not history and may be diagnosed or removed without rewriting canonical data.
Replay validates a complete segment before applying any event in it, so a
semantic batch is all-or-none. This design preserves a factual per-event JSONL
loading counter and avoids both a second database authority and an in-place
JSONL repair protocol.

Readers use immutable accepted segments. A process that intends to mutate
must still take the writer lock and revalidate its revision, dataset cursor,
interaction token, and precondition hash. A process never relies on an old
in-memory projection merely because its command began earlier.

Writer-lock acquisition is bounded and interruptible. A process never steals a
lock. After acquiring it, the process reloads and revalidates before deciding;
on timeout it returns a typed, retry-safe conflict without mutating state. A
retry starts from current state and never appends events decided against an old
projection.

## Event and result registries

S01 introduces versioned, closed registries rather than a generic payload:

- every event has a stable type, major version, UUIDv7, command group,
  attributable actor/origin, recorded instant, sequence/hash evidence, and a
  typed payload;
- every accepted command group records its preconditions and all replay inputs;
- every result declares `little-ant/<result-kind>@1`, dataset cursor, presence
  rules, and command identity when applicable;
- unknown event major versions stop writable replay;
- upcasters are pure and version-local;
- complete projections remain distinct from raw event or blob access.

Physical field names and event names are frozen by S01 fixtures before later
slices append to the registries. Later slices may add versioned cases but may
not reinterpret an accepted case.

Event evolution is additive and replay-first:

- an accepted event type, version, and decoder are immutable;
- a changed payload shape receives a new version and a pure upcaster;
- each slice freezes a byte-identical accepted-dataset fixture;
- every later build replays the complete fixture corpus from zero;
- a new projection may derive new knowledge, but may not make an old event
  claim a fact that it did not record;
- an unknown future version is a writable-startup failure, never a guess.

Performance snapshots are disposable projections keyed by an accepted segment
cursor and hash. They are never events and never required for correctness. A
suffix fold from a valid snapshot must equal a full fold from zero; deleting
all snapshots remains safe. This preserves DAT-003's single canonical history.

## Determinism seams

The core receives interfaces for:

- wall clock and timezone database;
- operational-day boundaries;
- UUIDv7 allocation;
- the closed purpose-to-random-cursor map;
- filesystem durability and locking;
- external source observations;
- terminal capabilities and presentation preferences;
- effect dispatch and provider receipts.

Tests replace each interface. Production adapters convert observations into
typed facts before the pure decision and never let IO run during replay.
Randomness follows the exact fixed-point and SHA-256 profile in
[`deterministic-calculation-profile.md`](../spec/little-ant-1.0/deterministic-calculation-profile.md).

## External effects

No decision handler calls a provider. It first commits an immutable effect
revision and dispatch intent. A host worker may then perform only that exact
approved revision and append a typed receipt. Retry, unknown outcome, and any
compensating operation return through the same state machine. Dry-run reaches
the complete preview but writes neither intent nor receipt.

Packs never participate in replay. Executable Pack code runs in a fresh
`lant-pack-runner` process; the trusted host owns credentials, HTTP,
filesystem destinations, limits, validation, and redaction.

## Surface architecture

The dispatcher returns an `InteractionEnvelope`; it does not return a TUI
widget tree. A pure renderer converts the envelope and terminal capability
profile into a screen model, then a terminal backend paints it. Golden tests
assert the plain canonical rendering and separate styled-role snapshots.

S00 performs a bounded terminal-backend spike and records the choice in an ADR.
The selected backend must support immediate key events, resize, Unicode width,
color capability detection, alternate-screen cleanup, raw input, selected
text, and deterministic headless rendering. The library choice is deliberately
not a product decision and cannot alter the screen grammar.

## Dependency direction

The following imports are forbidden:

- model/event/fold code importing REPL, web, Pack, provider, or LLM code;
- replay importing current configuration instead of recorded profile facts;
- renderers recomputing domain eligibility or actions;
- adapters writing events directly;
- tests reaching around the dispatcher to make an end-to-end scenario pass;
- powered-up, Skill, or web code parsing user configuration or JSONL directly.

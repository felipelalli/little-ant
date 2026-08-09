# ADR 0015 — Materialize source objects only after import consent

Status: accepted for S09

## Canonical constraints

DAT-011..017 and DAT-076..079 separate observation, Raw preservation,
adoption, reconciliation, and source mutation. A preflight is read-only and
sparse; acceptance reacquires the exact source and must preserve every selected
object with stable identity. Pack code has no filesystem or process authority,
does not participate in replay, and cannot become canonical storage.

The Notesnook release path makes the existing single-object shortcut
insufficient: one ZIP contains several independently identified note objects.
The same kernel is required by provider-backed task collections.

## Considered implementations

1. Persist full material in `SourcePreflight`. This makes checkpoints large,
   duplicates private source bytes in presentation state, and lets stale
   material survive beyond the custody read.
2. Preserve an archive as one Raw and triage its entries later. This loses the
   source-object identities and violates Raw-first object preservation.
3. Parse each supported source format in privileged Haskell. This duplicates
   adapter semantics in the core and makes Packs cosmetic.
4. Add a separate, bounded materialization invocation after consent. The same
   signed Lua component is rerun against newly reacquired host-custodied bytes;
   the full result remains transient and must reproduce the preview exactly.

## Decision

Use option 4. `source_preflight` returns only `SourceMaterialSummary` values.
`source_materialize` runs only after explicit acceptance and returns one
transient `SourceMaterial` for every previewed external identity plus the same
observation. The host rejects any change in Pack authority, input custody,
object set, metadata, digest, size, or preview before calling the pure import
decision. Only accepted Raw events become replay authority.

ZIP expansion is a trusted deterministic helper over the already authorized
input bytes, not a new filesystem capability. `lant.input_zip_entries()` is
available only inside the isolated process. It enforces path, entry-count,
expanded-size, encryption, symbolic-link, advertised-size, and CRC limits
before Lua interprets entries. The Pack still decides which safe entries are
source objects.

## Consequences and verification

- preflight checkpoints stay sparse and do not contain complete note bodies;
- stale or inconsistent materialization fails before any event;
- multiobject imports remain one replayable command with one mapping per
  external identity;
- exact retries are event-free and changed material under stable identity
  enters reconciliation rather than duplicating Raw truth;
- runner tests cover the preflight/materialization privacy split;
- import tests cover atomic multiobject preservation, handle collision, replay,
  and retry; and
- the signed standard Pack test exercises a compressed Notesnook-shaped ZIP
  through the real private runner.

This boundary can later carry provider response bytes supplied by the
host-brokered HTTP layer without changing replay or import semantics.

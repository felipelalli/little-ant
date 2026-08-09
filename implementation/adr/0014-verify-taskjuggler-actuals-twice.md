# ADR 0014 — Verify TaskJuggler actuals at both extension boundaries

## Status

Accepted for S09.

## Context

TaskJuggler files are intentionally editable after export. Their artifact
digest therefore cannot identify the Little Ant planning cut that produced
them. Actual effort also crosses an extension boundary: a signed Lua
SourceAdapter interprets the file, but replayable effort semantics must remain
owned by the Haskell core.

Missing actual fields are meaningful. A partial report may know completed
effort without knowing remaining effort, and an explicit `0h` is different
from no observation. A mutable file can also contain copied, reordered, or
ambiguous custody comments and task blocks.

## Decision

The offline standard Pack ships a separate `taskjuggler_actuals`
SourceAdapter. It supports snapshot only and receives the `.tjp` bytes through
the existing host-custodied `input_bytes` capability. The runner additionally
offers pure SHA-256 and canonical unpadded-base64url decoding functions; these
grant no filesystem, network, clock, randomness, or credential authority.

The adapter and an independent core parser both require:

- exactly one lowercase SHA-256 manifest line followed immediately by one
  contiguous, numbered base64url block;
- bytes whose digest matches that line, decode as canonical JCS, and declare
  `little-ant/planning-manifest@1`;
- canonical UUID-derived task IDs, unique flat top-level task declarations,
  and no actuals outside the manifest cut;
- only `actual:effortdone` and `actual:effortleft`, expressed as bounded,
  nonnegative hours with at most six decimal places;
- at least one actual record, exactly one UTC project timezone, and exactly one
  explicit canonical project `now` timestamp.

The SourceAdapter reports manifest digest, observation time, and record count
as explicit source identity. The host compares those values byte-for-byte
with its independent parse before exposing a preflight. The whole `.tjp`
remains the proposed Raw material, while its stable observation identity is
the manifest digest plus `as_of`; the mutable artifact digest is only content
custody.

Actuals may be partial. Absence means no evidence, while present `0h` remains
present. Actual evidence never mutates a historical EffortClaim. Acceptance
will persist the Raw before linked evidence and will reject an older or equal
non-identical observation for the same manifest.

## Consequences

- a compromised or defective Lua component cannot cause the core to accept a
  different manifest or actual set than the one previewed;
- old exports remain identifiable without a prior export event;
- copied manifests, unknown tasks, nested task ambiguity, duplicate fields,
  placeholder progress dates, and unit coercions fail before mutation;
- later planning may use explicit remaining effort conservatively without
  rewriting the estimate that produced the original planning cut.

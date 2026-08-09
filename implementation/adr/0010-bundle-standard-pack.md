# ADR 0010: Bundle the standard Pack as one exact built-in artifact

## Status

Accepted for S09.

## Context

The standard serializers must be inspectable Lua components and must traverse
the same Pack boundary as community code. Reimplementing them in Haskell would
create privileged duplicate behavior, while reconstructing an unsigned Pack
at startup would weaken the canonical archive and trust contracts.

## Decision

The source tree contains canonical `pack.json`, `signature.json`, component
payloads, and the resulting `standard.lantpack`. A maintenance tool refreshes
payload records, creates a one-off Ed25519 signature when the exact built-in
artifact changes, reconstructs the canonical ZIP32/store archive, and verifies
it byte for byte. The private signing seed is never written or retained;
continuity comes from the exact artifact identity compiled into the host, not
from treating this key as a release root.

At startup the host locates the installed data file (with a bounded
executable-ancestor fallback for an uninstalled Cabal build), validates the
complete archive, authenticates its signature, and requires its publisher,
name, version, manifest digest, and archive digest to equal the compiled
identity. Only then does ordinary built-in install/execution authorization
produce a profile-scoped registry.

Version 1.0's first standard-Pack milestone enables `tree`, `table`, `csv`,
`org`, and `html`. They all consume `little-ant/structure@1`; tree and Org
retain composition, table accounts for UTF-8 terminal width, CSV emits RFC
4180 record framing, and HTML is self-contained with no script or external
request. `taskjuggler` follows in a separate milestone because its projection
requires a core-owned planning cut and immutable planning manifest.

## Consequences

- standard and third-party exporters share the same isolation and closed
  result contract;
- source, manifest, signature, archive, compiled identity, and golden fixtures
  expose accidental drift immediately;
- ordinary startup performs deterministic local verification and no network
  activity;
- changing any payload byte deliberately changes both compiled identity
  digests;
- an uninstalled development build remains usable without trusting its current
  working directory: the candidate archive must still match the exact compiled
  identity.

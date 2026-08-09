# ADR 0013: Separate import scope from invocation custody

## Status

Accepted for S09.

## Context

DAT-012 gives an ImportProfile a durable provider/account source scope and an
idempotent external-identity mapping. DAT-023 independently requires every
accepted external invocation to retain its exact component, contract,
permissions, Pack identity, input revision, and attributable result. DAT-077
then requires the accepted source objects to preserve canonical Raw truth and
source relationships.

Putting exact input and Pack digests on ImportProfile makes a new profile for
every file or adapter revision. Reusing that profile and overwriting those
facts instead destroys the custody of earlier imports. SourceBinding alone is
also insufficient: it represents the stable external mapping and can outlive
many observations and adapter invocations.

## Decision

Use three replayable facts with separate lifetimes:

- `ImportProfile` owns the active adapter, source/account reference, mode,
  cleanup policy, and lifecycle;
- `SourceBinding` owns the stable mapping from one external object identity to
  one canonical Raw inside that profile; and
- immutable `ImportInvocation` owns one accepted preflight's component and
  contract major, exact canonical permissions, input label/media type/digest
  and byte count, mode, complete signed Pack identity, signer fingerprint, and
  external-identity-to-Raw result mappings.

Acceptance records a new profile only when its durable scope is new. It
records a new invocation whenever exact input or execution authority differs.
An exact retry finds the prior invocation and returns its existing mappings
without events. A new invocation with an already mapped external identity and
byte-identical material reuses the Raw. Different material under that same
identity fails into source reconciliation. A content-addressed file object
whose external identity changes may preserve a new Raw under the same profile.

One command group orders new facts as profile, Raw, SourceBinding, then
ImportInvocation. Replay therefore validates every invocation result against
the canonical Raw and unique stable binding already established by that same
atomic group. Created/reused dispositions are checked against the command that
originally created each Raw.

## Consequences

- provider/account scope remains stable across Pack upgrades and file
  snapshots;
- every accepted external execution remains inspectable without the Pack;
- exact retries are event-free and deterministic;
- a Pack upgrade cannot duplicate unchanged source material;
- provider identity conflicts cannot silently fork canonical truth; and
- later multi-object adapters can reuse the same invocation-to-object mapping
  without changing the public Raw-first flow.

The S09 import suite proves exact retry, Pack-upgrade reuse, changed file
snapshots, provider-identity conflict, stale preflight, replay, cleanup gating,
and dry-run behavior.

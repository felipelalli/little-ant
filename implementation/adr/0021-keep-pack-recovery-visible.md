# ADR 0021 — Keep Pack recovery visible when the registry fails closed

Status: accepted

## Context

The Pack contract requires one configured unsafe, unavailable, revoked, or
colliding Pack to fail the complete executable component registry. The same
contract requires `/packs` to explain the unavailable state and offer sober
recovery while canonical data and Pack-free replay remain available. Failing
application construction on the registry error satisfied the first rule but
made the second rule impossible: `lant packs list` and `lant packs show` could
not start.

## Decision

Production application construction retains a typed registry problem instead
of failing the complete process. Import and export ports become unavailable
and return that exact problem before adapter selection or invocation. Core
work commands continue against canonical state.

Pack inspection is a separate read-only host path. It authenticates the
built-in Pack and safely inspects each configured content-addressed archive,
but it never converts structural inspection into execution authority. Missing
or invalid archives remain visible from their exact profile pins with status
`unavailable` and the typed problem. The sparse `little-ant/packs@1`
projection carries both per-Pack and registry-wide problems.

## Consequences

- registry failure remains fail-closed for every Pack component;
- `/packs` can diagnose the configuration that caused the failure;
- `next`, history, search, and Pack-free replay do not become collateral
  damage;
- read-only inspection cannot be reused as installation or execution consent;
- later trust, install, update, remove, and recovery screens can build on one
  explicit unavailable state instead of special startup behavior.

## Evidence

`test/s09-pack-admin/Spec.hs` covers the built-in list/detail projections,
exact-name failure, sparse dry-run JSON, and a profile with a missing pinned
archive whose registry fails while Pack inspection and ordinary core work
remain available.

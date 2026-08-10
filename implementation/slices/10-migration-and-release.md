# S10 — v0.1 migration and cutover

Status: **alpha subset implemented; complete v1 route deferred to beta**

## Outcome

Implement the exact signed-v0.1 preflight, isolated candidate, full validation,
and atomic cutover without consulting or reviving the failed v1 rewrite.

The alpha subset is bounded by
[`implementation/releases/v1-alpha.md`](../releases/v1-alpha.md): it accepts
the 25 event types observed in the private real dataset, requires an empty v1
target, preserves the exact source, replays an isolated candidate, and supports
resumable atomic cutover. The broader signed-v0.1 vocabulary, immutable plan
UI, allocation reuse, and nonempty-target review remain beta work.

## Canonical flow row owned

- v0.1 preflight/candidate/cutover

Generate MIG-001..044, UX-MIG00..MIG02, SCN-MIG-001, the complete
[`v0→1.0 capability matrix`](../../spec/little-ant-1.0/v0-v1-capability-matrix.md),
and only the signed `v0.1.0` schema/upcast evidence explicitly named by
MIG-024. Deleted v1 Allium/tests and `experimental/failed/v1-rewrite` are
forbidden implementation inputs.

## Work

1. Freeze immutable v0.1 fixtures and verify tag/commit/schema/upcast hashes.
2. Implement strict source validation and content-addressed preflight plans.
3. Implement every required mapping, preservation record, historical-only
   evidence, provisional review, and blocking repair class.
4. Build candidates beside the live target with durable UUID allocation tables
   and deterministic handle proposals.
5. Replay candidates from zero; verify identity map, projection hash, source
   archive bytes, counts, graphs, order, lifecycle, and all v1 invariants.
6. Implement the three-screen dumb route and exact CLI preflight/inspect/build/
   cutover stages.
7. Implement stale-plan rejection, retained backup, atomic target replacement,
   existing-v1 merge boundary, and no external effects.

## Gate

- migration golden fixtures cover every v0 capability-matrix row;
- no v0 precedence evidence becomes human importance;
- no legacy name/kind fabricates Nature, phase, Domain, Wait, Delegation,
  completion, or current effect;
- every old identity has one inspectable mapped/preserved disposition;
- interrupted or failed preflight/build/cutover preserves source and live
  target exactly;
- a cutover candidate is accepted only after full replay matches its recorded
  hash and invariants.

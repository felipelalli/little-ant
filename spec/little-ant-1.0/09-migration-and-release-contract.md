# 9. Migration and release contract

## Migration principles

- **MIG-001 [core] — Explicit v0 boundary.** Migration reads a versioned,
  immutable v0 archive and writes v1 through canonical creation or migration
  operations. The archive remains verifiable after cutover.
- **MIG-002 [core] — No in-place guess.** Migration first projects and
  validates a candidate v1 state, reports ambiguity, and commits only after
  invariant and identity checks pass.
- **MIG-003 [core] — Identity map.** Every migrated v0 Raw, Brick, ListEntry,
  Party, source, and relevant historical event has an inspectable old-to-new
  identity or preservation record.
- **MIG-004 [core] — Historical evidence.** Rejected vocabulary may remain
  quoted inside immutable v0 payloads and migration reports. Current v1 state
  and APIs use only canonical vocabulary.
- **MIG-005 [core] — No fabricated judgment.** Migration preserves attributable
  comparisons and known orders but never invents human evidence, phase,
  completion, progress, or semantic scope.

## Required mappings

- **MIG-006 [core] — Legacy stages.**

  - v0 `seed`, `committed`, and `ready` become `active`/`idle`;
  - v0 `wip` becomes `active`/`wip`, with current focus preserved only when
    explicit evidence identifies it;
  - terminal `done`, `dropped`, and `superseded` retain their outcomes and
    lineage;
  - no legacy stage is converted into phase merely by name.

- **MIG-007 [core] — Importance.** Existing valid sibling order and comparison
  evidence are preserved where their scope is known. Bricks without a
  comparable position enter resumable insertion with explicit uncertainty;
  they never form an unordered pool.
- **MIG-008 [core] — Behavior and kind.** A validated mapping selects one
  factory or migrated custom BrickNature. Ambiguous legacy `kind`, `weight`,
  estimate, and context values remain migration evidence and produce bounded
  review rather than a lossy direct cast.
- **MIG-009 [core] — Party.** v0 person and AI-agent records map to
  ExternalEntity. `company` maps to `organization`. Legacy `area` requires an
  explicit decision between Domain, team, organization, or historical-only
  evidence; migration must not guess.
- **MIG-010 [core] — Raw and source.** Raw bytes, origin, snapshot, review,
  archive, links, and reconciliation evidence remain logically complete even
  when older data lacks a 1.0 field.
- **MIG-011 [core] — Removed fields.** Legacy `weight` is not silently renamed
  to effort or forecast probability. Legacy hour estimates remain attributed
  planning evidence pending EffortProfile classification.

## Verification and cutover

- **MIG-012 [core] — Preflight.** Before any cutover, report source counts,
  parse/upcast warnings, unmapped identities, ambiguous references,
  incompatible cycles, title-only collisions, and unresolved Nature mappings.
- **MIG-013 [core] — Projection invariants.** Candidate state must satisfy
  opaque identity, exactly one Nature per Brick, one sibling position per
  active Brick, acyclic composition/dependencies, valid terminal structure,
  and canonical link ownership.
- **MIG-014 [core] — Dry-run first.** The migration provides a complete dry-run
  report and writes neither v0 nor v1 state before explicit cutover.
- **MIG-015 [core] — Atomic v1 commit.** Cutover records source archive hash,
  migration version, identity map, counts, warnings accepted, projection hash,
  and committed target revision.
- **MIG-016 [core] — Failure preserves both sides.** Verification or write
  failure leaves the v0 archive and prior v1 target untouched and provides a
  concrete repair path.
- **MIG-017 [standard] — External-source cleanup.** Provider deletion after a
  migration is a later approved adapter effect under `DAT-016`, never part of
  the atomic local cutover.

## Documentation and implementation gate

- **MIG-018 [core] — UX acceptance first.** Canonical screen and scenario
  review must finish before Markdown is promoted into Allium obligations or
  generated tests.
- **MIG-019 [core] — Stable trace IDs.** Every promoted Allium rule, surface,
  and test cites the originating rule or scenario ID. Promotion reports
  uncovered, conflicting, or intentionally non-testable IDs.
- **MIG-020 [core] — Regression gate.** The v0 capability audit is resolved
  item by item as restored, deliberately replaced, deliberately retired, or
  out of scope. Passing syntax or generated unit tests alone is insufficient.
- **MIG-021 [core] — README after truth.** The README becomes a concise 1.0
  entry point only after the canonical product and UX contract are accepted.
  It links here rather than duplicating architectural detail.
- **MIG-022 [core] — Separate coding authorization.** Documentation, scenario,
  Allium, test generation, implementation, and data cutover remain explicit
  phases. Finishing one never silently authorizes the next.

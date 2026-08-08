# Little Ant 1.0 implementation plan

Status: **implementation in progress; S00-S01 verified, S02-S03 implemented, S04 in progress**

The canonical product contract remains
[`spec/little-ant-1.0.md`](../spec/little-ant-1.0.md). This directory describes
how to implement that contract without becoming another specification. When an
implementation document and the specification disagree, the specification
wins and the implementation document must be corrected.

## Objective

Deliver Little Ant 1.0 as a greenfield, deterministic Haskell application with:

- one canonical command dispatcher;
- an append-only, replayable event authority;
- `lant` as the sole public executable;
- the dumb REPL as the reference guided surface;
- exact structured envelopes shared by CLI, powered-up, Skill, and local web;
- replay-safe clocks, UUID allocation, randomness, effects, undo, and migration;
- every row of the canonical UX flow inventory verified by executable evidence.

Implementation follows product behavior, not chapter order. Each numbered
slice is a vertical path through interaction, command validation, events,
projection, rendering, and tests.

## Authority chain

```text
canonical rule and scenario IDs
          ↓ exact lookup; no paraphrased shadow spec
slice packet and failing acceptance tests
          ↓
pure decisions, events, projections, and adapters
          ↓
executable evidence and generated coverage report
```

Allium is not in the 1.0 critical path. It may be reconsidered only for a
named invariant that the implemented type system, property tests, and
state-machine tests demonstrably fail to express. It never becomes product
authority or the sole source of tests.

## Delivery order

| Slice | Outcome | Depends on | Canonical flows owned |
|---|---|---|---:|
| [S00](slices/00-bootstrap.md) | Honest build, contract tooling, and test harness | — | 0 |
| [S01](slices/01-walking-skeleton.md) | Start, Feed, persist, replay, inspect, and recover | S00 | 8 |
| [S02](slices/02-daily-loop.md) | Raw triage through one usable Work loop | S01 | 7 |
| [S03](slices/03-importance-and-judgment.md) | Complete importance and lazy judgment mechanics | S02 | 5 |
| [S04](slices/04-forecast-and-focus.md) | Hierarchical weighted forecast and truthful Focus | S03 | 8 |
| [S05](slices/05-adaptation-and-maintenance.md) | Skip learning, focus lifecycle, maintenance, and recovery | S04 | 8 |
| [S06](slices/06-structure-and-checklists.md) | Decomposition, lifecycle composition, and all Natures | S05 | 6 |
| [S07](slices/07-time-and-standing-work.md) | Dates, notices, recurrence, habits, and commitments | S06 | 5 |
| [S08](slices/08-waits-delegation-and-effects.md) | Waits, delegation, effects, profiles, and credentials | S07 | 3 |
| [S09](slices/09-sources-packs-and-adapters.md) | Sources, imports, Packs, Calendar, exports, and repair | S08 | 9 |
| [S10](slices/10-migration-and-release.md) | Verified v0.1 projection and atomic cutover | S09 | 1 |
| [S11](slices/11-assisted-surfaces.md) | Powered-up, Skill, local-web parity, and release closure | S10 | 5 |

The 65 exact flow assignments live in [`coverage.tsv`](coverage.tsv). A flow
is not `verified` merely because its owning dumb behavior exists. Its complete
evidence row—including failure, uncertainty, recovery, and paired surfaces
where required—must pass.

## Gates shared by every slice

A slice is complete only when:

1. its context packet was generated from exact rule/scenario IDs;
2. its dumb UX golden transcript was reviewed before implementation;
3. acceptance tests failed for the intended missing behavior;
4. every mutation passes through the canonical dispatcher;
5. replay from an empty projection reproduces the expected state and result;
6. fake clock, UUID, randomness, terminal capability, and external observations
   make the test deterministic;
7. ordinary, uncertainty, stale, failure, dry-run, and undo branches required by
   the owned flow are covered;
8. no rejected public vocabulary is introduced;
9. the generated coverage report contains no unknown IDs or silently stale
   rule hashes;
10. the full previously completed suite remains green.

See [`testing-and-traceability.md`](testing-and-traceability.md),
[`delivery-process.md`](delivery-process.md), and the physical choices recorded
in [`difficult-decisions.md`](difficult-decisions.md).

## Current checkpoint

Current slice: **S04 — Forecast, hierarchy, and Focus.**

S03 now implements the complete sibling-only human importance maintenance
engine, confidence decay, bounded uncertainty and tie-break, explicit
contradiction recovery, separate Impact evidence maturity, lazy Effort
exemplars, and optional phase claims. Its pure and vertical suites pass the
full CI gate.

To resume in a fresh context:

    Read implementation/README.md, then implementation/slices/04-forecast-and-focus.md,
    and follow only its required canonical references. Implement S04 and nothing
    from later slices.

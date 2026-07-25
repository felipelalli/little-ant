# Little Ant 1.0 — Conceptual Design Record

Status: **draft for review; no implementation has started**

Target release: **Little Ant 1.0**

Current implementation baseline: **v0**, package version `0.1.0.0`

Last consolidated: **2026-07-25**

This is the index for the Little Ant 1.0 discovery record. Each chapter is a
small standalone file so a future session can load only the relevant concepts
instead of the entire design history.

The chapters are preparatory design material. They do not yet replace
[`little-ant.allium`](little-ant.allium). The Allium specification becomes
authoritative for 1.0 only after the remaining questions are resolved and the
documentation phase is deliberately completed and reviewed.

## Minimum safe reading

For any focused design question, load:

1. [Purpose and authority](little-ant-1.0/01-purpose-and-authority.md);
2. [Corrections and superseded decisions](little-ant-1.0/17-corrections-and-superseded-decisions.md);
3. the relevant subject chapter;
4. the relevant portion of [Open questions](little-ant-1.0/19-open-questions.md);
5. the latest entries in the [Session log](little-ant-1.0/22-session-log.md).

Later corrections override earlier proposals. Open questions are
non-normative.

## Topic-oriented reading paths

| Topic | Load these chapters |
|---|---|
| Release, terminology, and compatibility | [02](little-ant-1.0/02-release-version-compatibility-and-language.md), [03](little-ant-1.0/03-design-center.md), [17](little-ant-1.0/17-corrections-and-superseded-decisions.md) |
| Raw material | [04](little-ant-1.0/04-conceptual-entities.md), [05](little-ant-1.0/05-raw-material-and-shelves.md), [19](little-ant-1.0/19-open-questions.md) |
| Brick lifecycle and hierarchy | [06](little-ant-1.0/06-brick-state-phase-and-metadata.md), [07](little-ant-1.0/07-composition-tree-and-inheritance.md), [18](little-ant-1.0/18-confirmed-invariants.md) |
| Priority and contradictions | [08](little-ant-1.0/08-human-priority-ordering-and-confidence.md), [17](little-ant-1.0/17-corrections-and-superseded-decisions.md), [18](little-ant-1.0/18-confirmed-invariants.md) |
| Impact and effort | [09](little-ant-1.0/09-impact-rating.md), [10](little-ant-1.0/10-effort-rating-and-calibration.md), [19](little-ant-1.0/19-open-questions.md) |
| Dates, WIP, and current focus | [11](little-ant-1.0/11-dates-and-urgency.md), [12](little-ant-1.0/12-wip-focus-and-delegation.md) |
| Forecast, next, and skip | [13](little-ant-1.0/13-priority-forecast-and-next.md), [14](little-ant-1.0/14-skip-semantics.md), [19](little-ant-1.0/19-open-questions.md) |
| TaskJuggler | [10](little-ant-1.0/10-effort-rating-and-calibration.md), [15](little-ant-1.0/15-taskjuggler-planning-boundary.md), [17](little-ant-1.0/17-corrections-and-superseded-decisions.md), [19](little-ant-1.0/19-open-questions.md) |
| REPL harness | [24](little-ant-1.0/24-repl-harness.md), [16](little-ant-1.0/16-core-operator-and-adapter-boundary.md), [19](little-ant-1.0/19-open-questions.md) |
| Core/operator boundary | [16](little-ant-1.0/16-core-operator-and-adapter-boundary.md), [18](little-ant-1.0/18-confirmed-invariants.md) |
| Existing Brick review | [20](little-ant-1.0/20-existing-brick-review.md), [21](little-ant-1.0/21-documentation-and-implementation-sequence.md) |
| Resume the discovery session | [19](little-ant-1.0/19-open-questions.md), [22](little-ant-1.0/22-session-log.md), [23](little-ant-1.0/23-review-checklist.md) |

## Chapters

1. [Purpose and authority](little-ant-1.0/01-purpose-and-authority.md) —
   authority, scope, and normative language.
2. [Release, version, compatibility, and language](little-ant-1.0/02-release-version-compatibility-and-language.md) —
   1.0 target, no core aliases, and English-only product artifacts.
3. [Design center](little-ant-1.0/03-design-center.md) — concise statement of
   the new model.
4. [Conceptual entities](little-ant-1.0/04-conceptual-entities.md) — entity
   map and persistence caveats.
5. [Raw material and shelves](little-ant-1.0/05-raw-material-and-shelves.md) —
   Raw, snapshots, freshness, review, archive, and RawShelf.
6. [Brick state, phase, and metadata](little-ant-1.0/06-brick-state-phase-and-metadata.md) —
   independent state axes and removed legacy fields.
7. [Composition tree and inheritance](little-ant-1.0/07-composition-tree-and-inheritance.md) —
   hierarchy, breaking, moving, closure, and effective metadata.
8. [Human priority, ordering, and confidence](little-ant-1.0/08-human-priority-ordering-and-confidence.md) —
   sibling order, binary insertion, skip, evidence, and recalibration.
9. [Impact and evidence maturity](little-ant-1.0/09-impact-rating.md) —
   root-scoped expected-impact classes, evidence maturity, and validation work.
10. [Effort rating and calibration](little-ant-1.0/10-effort-rating-and-calibration.md) —
    total effort classes, versioned profiles, derived remaining work, and scope
    revision.
11. [Dates and urgency](little-ant-1.0/11-dates-and-urgency.md) —
    `not_before`, `best_before`, and `deadline`.
12. [WIP, focus, and delegation](little-ant-1.0/12-wip-focus-and-delegation.md) —
    multiple WIPs, exclusive current focus, and parallel delegation.
13. [Priority, forecast, and next](little-ant-1.0/13-priority-forecast-and-next.md) —
    the stable priority tree versus the dynamic selection distribution.
14. [Skip semantics](little-ant-1.0/14-skip-semantics.md) — served-Brick,
    ordering, and rating skip.
15. [TaskJuggler planning boundary](little-ant-1.0/15-taskjuggler-planning-boundary.md) —
    effort macros, non-overlapping planning cuts, immutable manifests, and
    actuals.
16. [Core, operator, and adapter boundary](little-ant-1.0/16-core-operator-and-adapter-boundary.md) —
    deterministic mechanism versus external judgment.
17. [Corrections and superseded decisions](little-ant-1.0/17-corrections-and-superseded-decisions.md) —
    authoritative reversals, including the retracted leaf-only inference.
18. [Confirmed invariants](little-ant-1.0/18-confirmed-invariants.md) —
    compact list of settled cross-cutting rules.
19. [Open questions](little-ant-1.0/19-open-questions.md) — unresolved design
    decisions grouped by area.
20. [Existing Little Ant Brick review](little-ant-1.0/20-existing-brick-review.md) —
    review protocol, preliminary mapping, and captured inventory.
21. [Documentation and implementation sequence](little-ant-1.0/21-documentation-and-implementation-sequence.md) —
    discovery, specification, migration planning, and coding boundary.
22. [Session log](little-ant-1.0/22-session-log.md) — chronological decision
    history and corrections.
23. [Review checklist](little-ant-1.0/23-review-checklist.md) — checks before
    the record is accepted.
24. [Deterministic REPL harness](little-ant-1.0/24-repl-harness.md) —
    one-key guided operation, adaptive terminal UI, activity history, notices,
    and exact dialog recovery.

## Maintenance protocol

When discovery changes the design:

1. update the smallest relevant subject chapter;
2. add a correction to chapter 17 when it reverses prior wording;
3. resolve or add the corresponding item in chapter 19;
4. append a concise entry to chapter 22;
5. update this index only when chapter structure or reading paths change.

All files in this record must remain in English. Code and
`little-ant.allium` remain untouched until the documentation phase explicitly
reaches them.

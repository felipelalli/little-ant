# Decision and evidence traceability

This register preserves provenance without keeping a second live
specification. Git stores the chronological discovery record; the compact
chapters store current behavior; the capability matrix stores regression
dispositions; UX scenarios store observable acceptance.

Historical prose never overrides a canonical rule merely because it is older,
longer, or recoverable.

## Evidence anchors

| Commit | Evidence preserved | Authority now |
|---|---|---|
| `c6f3cb7` | Final implementation-first v0 baseline: core, tests, skill, Allium, README | Evidence of delivered v0 behavior; distinguish code/tests from aspirations |
| `98dbe1c` | First split 1.0 conceptual design record | Discovery evidence; unresolved text is not current behavior |
| `70cb5b0` | Divergent mega-rewrite into Markdown, Allium, generated tests, and implementation contract | Failure evidence; never current product authority |
| `e949c51` | Independent v0 capability-regression audit | Input to the maintained matrix |
| `ec12294` | First compact chapters plus unchanged `R100` moves of the old corpus into `history/` | Explains the shadow-spec defect; compact structure retained, shadow authority rejected |
| `9a748bf` | Last commit containing the complete 38-file shadow tree and session log through entry 111 | Immutable recovery anchor for every deleted historical file |
| `33e9dd3` | Restored Description-as-Raw and same-Raw English normalization | Current Raw baseline |
| `e4dd122` | Maintained v0→1.0 matrix and finite UX-first closure plan | Current regression and completion gates |
| `f178f04` | Removed the live shadow tree, reorganized open decisions, and added UX flow coverage | Gate 1 closure and current active-spec boundary |

The pre-rewrite bundle at
`~/tmp/little-ant-pre-rewrite-202607101708.bundle` is older than the final v0
baseline. It is useful forensic evidence but not the final vocabulary or
capability boundary.

## Recovering the removed discovery record

The historical corpus remains byte-for-byte recoverable without living beside
the canonical specification:

```sh
git ls-tree -r --name-only 9a748bf spec/little-ant-1.0/history
git show 9a748bf:spec/little-ant-1.0/history/22-session-log.md
git show 9a748bf:spec/little-ant-1.0/history/36-v0-capability-regression-audit.md
```

The complete divergent formal garden and generated tests remain recoverable
from `70cb5b0`; the failed implementation remains on
`experimental/failed/v1-rewrite`. Neither is an implementation starting point.

## Current subject provenance

| Current subject | Canonical destination | Primary evidence |
|---|---|---|
| Product promise, English, no aliases, scope rings | `PRD-*` | initial design, later vocabulary corrections, UX recovery |
| Raw, Description, same-Raw normalization, shelves, sources | `MOD-001`, `MOD-023`, `MOD-029`, `MOD-049`, `FED-010..018`, `DAT-002`, `DAT-011..017`, `DAT-042..043`, `OPEN-RAW-*` | `98dbe1c`, explicit post-`9a748bf` correction, `33e9dd3` |
| UUIDv7 identity, mnemonic handles, repeated titles, duplicate suspicion, merge | `MOD-008..012`, `FED-004`, `FED-015..018`, `UX-075..076`, `OPEN-MERGE-001`, `OPEN-REF-001` | v0 audit plus the 1.0 identity and human-reference redesign |
| Brick axes, Natures, Templates, ListEntries | `MOD-002..005`, `MOD-013..018`, `MOD-025..053`, `OPEN-LST-001` | conceptual sessions and Nature/Template screen reviews |
| Composition, sibling locality, Domains, dependencies | `MOD-019..024`, `MOD-031..034`, `FED-030..036`, `OPEN-TREE-001`, `OPEN-DOM-*` | hierarchy, Domain, and enabling-recovery sessions including fear validation and support |
| Importance and `org-sort-tasks` | `IMP-001..016`, `IMP-030..037` | v0 `Order.hs`/tests, canonical importance correction, regression audit |
| Impact, effort, planning calibration | `IMP-017..029`, `IMP-038`, `DAT-030..037`, calibration profile | estimation/TaskJuggler and tired-recovery sessions |
| Forecast, hierarchy, Domain and interaction-family continuity, blockers, and opportunity variants | `FOC-001..046` | recovery ledger decisions and fixed-stream UX scenarios |
| Focus, WIP, skip, time, standing work, delegation | `WRK-001..083` | v0 behavior audit plus skip, recurrence, habit, delegation, honest-sprint, and fear-recovery sessions |
| Canonical interaction and dumb REPL | `UX-001..118`, screen catalog | REPL recovery and screen-by-screen review |
| Event authority, sparse output, imports, Packs, Calendar | `DAT-001..045` | context-pollution, source safety, Pack, Calendar, cold-load, and sparse-timer sessions |
| Migration and promotion gates | `MIG-001..023` | v0 archive review and failed-rewrite analysis |

## Regression trace

The maintained
[v0→1.0 capability matrix](v0-v1-capability-matrix.md) replaces the stale
historical audit. Each meaningful capability has:

```text
v0 evidence strength
current disposition
canonical destination or OPEN ID
acceptance route
```

An unresolved row is a visible specification gap. It may not be converted into
an implementation default or disappear because an old command was removed.

## UX trace

The [screen catalog](ux/screen-catalog.md) is the visual authority. The
[simulation protocol](ux/00-simulation-protocol.md) defines how a screen is
accepted. The [flow coverage inventory](ux/flow-coverage.md) makes missing
transitions visible. The [synthetic week](ux/01-synthetic-week.md) and
[real shadow day](ux/02-real-shadow-day.md) are acceptance programs, not
sources of new semantics.

Every resolved UX finding records:

```text
scenario step
screen revision before
observed critique
accepted change
canonical rule IDs
screen revision after
commit
```

## Downstream promotion trace

Allium and tests do not yet exist for the recovered 1.0 contract. When the
specification reaches Gate 12 of the
[completion plan](spec-completion-plan.md), promotion adds these fields for
every canonical rule and flow:

```text
Allium obligation
generated obligation inspection
property/state-machine test
end-to-end scenario
non-testable rationale, when reviewed
```

Passing Allium syntax, analysis, or a large obligation count is insufficient.
The 2026 failed rewrite demonstrated that comments, guarantees, and generated
declarations can all pass while the product loses observable behavior.

## Maintenance

- Current behavior is stated once, in a canonical chapter.
- Corrections edit that rule and its affected screen/scenario; they do not add
  a corrections chapter.
- Chronology lives in signed commits, not an append-only Markdown session log.
- Open semantics live only in `open-release-decisions.md`.
- V0 dispositions live only in the capability matrix.
- A compact record may cite historical terms only to explain a deliberate
  replacement or migration.
- The v0 operator skill is evidence, not 1.0 authority, until the Skill mirror
  phase. It must not supply a missing dumb-core route.

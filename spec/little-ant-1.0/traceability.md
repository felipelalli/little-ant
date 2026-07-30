# Historical traceability

This register proves that consolidation did not make the discovery record
disappear. `adopted` means the compact rules are current; `superseded` means a
later rule intentionally replaces the old wording; `open` points to an
explicit release decision; `historical` preserves process evidence without
current product authority.

## Subject chapters

| Historical source | Current destination | Disposition |
|---|---|---|
| [00 index](history/00-conceptual-design-record-index.md) | [canonical index](../little-ant-1.0.md), `PRD-019`, `MIG-018..022` | superseded authority; preserved navigation evidence |
| [01 purpose](history/01-purpose-and-authority.md) | `PRD-001..019` | adopted |
| [02 release/language](history/02-release-version-compatibility-and-language.md) | `PRD-010..013`, `PRD-018` | adopted |
| [03 design center](history/03-design-center.md) | `PRD-001..017`, `MOD-001..028`, `FOC-001..028` | adopted and decomposed |
| [04 conceptual entities](history/04-conceptual-entities.md) | `MOD-001..024`, `WRK-029..034`, `DAT-018..027` | adopted; Party replaced by ExternalEntity |
| [05 Raw](history/05-raw-material-and-shelves.md) | `MOD-001`, `MOD-023`, `FED-010..018`, `DAT-002`, `DAT-010..017`, `OPEN-RAW-001` | adopted/open |
| [06 Brick state](history/06-brick-state-phase-and-metadata.md) | `MOD-013..018`, `IMP-022..029`, `CAL provisional phase placement`, `OPEN-MOD-002` | adopted/open |
| [07 composition](history/07-composition-tree-and-inheritance.md) | `MOD-019..024`, `MOD-031..034`, `IMP-002..005`, `MIG-013`, `OPEN-MOD-003`, `OPEN-TREE-001` | adopted/open |
| [08 human ordering](history/08-human-priority-ordering-and-confidence.md) | `IMP-001..016` | adopted; `priority` vocabulary superseded |
| [09 impact](history/09-impact-rating.md) | `IMP-017..021`, `OPEN-JUD-001` | adopted/open |
| [10 effort](history/10-effort-rating-and-calibration.md) | `IMP-022..029`, EffortProfile, `OPEN-JUD-001` | adopted/open |
| [11 dates](history/11-dates-and-urgency.md) | `WRK-014..018`, `OPEN-TIME-001` | adopted/open |
| [12 focus/delegation](history/12-wip-focus-and-delegation.md) | `WRK-001..006`, `WRK-029..034` | adopted; Party replaced |
| [13 two lists](history/13-priority-forecast-and-next.md) | `PRD-003`, `FOC-001..028`, `UX-007..009`, `OPEN-FOC-001..002` | adopted/open; `priority` vocabulary superseded |
| [14 skip](history/14-skip-semantics.md) | `IMP-006..010`, `WRK-007..013`, `UX-014..018` | adopted |
| [15 TaskJuggler](history/15-taskjuggler-planning-boundary.md) | `IMP-022..029`, `DAT-028..031`, `DAT-034..037` | adopted |
| [16 boundaries](history/16-core-operator-and-adapter-boundary.md) | `PRD-006..009`, `FED-005..009`, `DAT-001..033` | adopted |
| [17 corrections](history/17-corrections-and-superseded-decisions.md) | vocabulary table plus all canonical rules | adopted as dispositions, no longer a competing authority |
| [18 invariants](history/18-confirmed-invariants.md) | all canonical rule IDs | adopted and deduplicated |
| [19 open questions](history/19-open-questions.md) | [open decisions](open-release-decisions.md), [calibration](configuration-and-calibration.md), or later implementation plan | triaged |
| [20 Brick review](history/20-existing-brick-review.md) | `FOC-009`, `MIG-020`, historical backlog evidence | adopted/historical |
| [21 sequence](history/21-documentation-and-implementation-sequence.md) | `PRD-019`, `MIG-018..022` | adopted |
| [22 session log](history/22-session-log.md) | session-entry map below | historical with adopted decisions |
| [23 checklist](history/23-review-checklist.md) | acceptance gates in canonical index, traceability, simulations, and `MIG-018..022` | superseded checklist |
| [24 REPL](history/24-repl-harness.md) | `UX-001..049`, UX records, `OPEN-UX-001..002` | adopted/open |
| [25 Natures/templates](history/25-brick-natures-and-template-library.md) | `MOD-004..005`, `MOD-025..028`, `FED-005..009`, `WRK-031..032` | adopted |
| [26 entries/identity](history/26-structured-entries-identity-and-duplicate-suspicion.md) | `MOD-003`, `MOD-008..012`, `FED-015..018` | adopted |
| [27 standing work](history/27-standing-work-recurrence-obligations-and-practices.md) | `WRK-019..028`, `OPEN-WRK-001..002` | adopted/open |
| [28 places](history/28-place-conditions-and-location-observations.md) | `WRK-035..037` | adopted |
| [29 annotations](history/29-text-mentions-and-typed-annotations.md) | `MOD-007`, `MOD-024`, `OPEN-MOD-001` | adopted/open |
| [30 data authority](history/30-domain-authority-blobs-and-rebuildable-projections.md) | `DAT-001..005`, `MIG-001..017` | adopted |
| [31 resumable interactions](history/31-resumable-interactions-and-honest-progress.md) | `FOC-025..028`, `UX-019..032`, `OPEN-UX-002` | adopted/open |
| [32 imports/Packs](history/32-external-imports-source-views-and-extension-packs.md) | `DAT-011..023`, `DAT-033`, `OPEN-EXT-002`, `OPEN-PACK-001` | adopted/open |
| [33 sparse responses](history/33-structured-command-responses-and-sparse-projections.md) | `DAT-006..010`, `UX-029`, `UX-040..042`, `OPEN-DAT-001` | adopted/open |
| [34 Lua runtime](history/34-lua-pack-runtime-credentials-exporters-and-ui-adapters.md) | `DAT-018..033`, `OPEN-EXT-001..002`, `OPEN-PACK-001` | adopted/open |
| [35 recovery ledger](history/35-v1-recovery-ledger.md) | recovery-entry map below | adopted |
| [36 v0 regression audit](history/36-v0-capability-regression-audit.md) | `IMP-005`, `UX-012..024`, `UX-040..042`, `DAT-028..031`, `MIG-018..022` | adopted as release gate |

## Recovery ledger entries

| Entries | Current rule IDs |
|---|---|
| 35.2 remove `priority` | `PRD-003`, `PRD-013`, `IMP-001`, `FOC-001` |
| 35.3 probabilistic deterministic `next` | `FOC-001..005` |
| 35.4 contextual `?`, Nature decomposition | `FOC-011..012`, `UX-016..017` |
| 35.5 N blocker steps | `FOC-020..024` |
| 35.6–35.7 phase correction and model boundary | `MOD-017..018`, `PRD-006..008` |
| 35.8 closed opportunity family | `FOC-006..009`, `OPEN-FOC-001` |
| 35.9 response language | `UX-001..018` |
| 35.10 one lottery | `FOC-006..009`, `FOC-025..026` |
| 35.11 hierarchy | `FOC-010..013` |
| 35.12 signal bonus | `FOC-008`, calibration profile |
| 35.13 Domain multi-membership | `MOD-006`, `MOD-022`, `FOC-014..019` |
| 35.14 feeding vocabulary | `PRD-013`, `FED-001..004` |
| 35.15 Nature at birth | `MOD-025`, `FED-005..006` |
| 35.16–35.18 Domain continuity and narrowing | `FOC-014..019` |
| 35.19–35.21 skip symptoms, labels, waiting/blocking | `WRK-007..013` |
| 35.22 navigation versus undo | `UX-019..021` |
| 35.23 discreet review and status separation | `UX-005..006`, `UX-025..027`, `UX-045` |
| 35.24 default marker | `UX-015` |
| 35.25 comparison versus confirmation | `UX-006..010` |
| 35.26 safeguards and empty states | `FOC-027..029`, `UX-040..042`, `UX-E00..E01` |
| 35.27 taxonomy watch | `WRK-012` |
| 35.28 structural exporters | `DAT-028..030` |
| 35.29 English product | `PRD-010..012` |
| 35.30 later and grammar | `UX-018`, `UX-022..023` |
| 35.31 deterministic time | `WRK-017` |
| 35.32 merge | `MOD-011..012` |
| 35.33 delegation follow-up | `WRK-030`, `WRK-033` |
| 35.34 Nature-aware delegation scope | `WRK-031..034` |

## Session-log coverage

The log is rationale, not another specification. Entries are grouped only when
they were successive refinements of the same current rule family.

| Entries | Current destination |
|---|---|
| 1–9 | `MOD-013..018`, `IMP-001..016`, `PRD-013` |
| 10–18 | `MOD-001`, `FED-010..014`, `PRD-010..013`, historical preservation |
| 19–24 | `UX-001..049`, `IMP-022..029`, reproducible scenarios |
| 25–30 | `IMP-017..029`, `UX-001..018`, `WRK-007..013` |
| 31–36 | `MOD-003..005`, `MOD-025..028`, `FED-005..009`, `WRK-019..028` |
| 37–41 | historical Brick review, `MOD-001`, `DAT-002`, `WRK-021..022` |
| 42–47 | `UX-025..032`, `FOC-009`, `MOD-014..015`, `OPEN-TREE-001` |
| 48–52 | `WRK-019..028`, `WRK-035..037`, `MOD-024`, `DAT-001..005` |
| 53–57 | spec authority, `MOD-021`, `MIG-018..022`, `UX-029..031` |
| 58–60 | `MOD-007`, `MOD-024`, `WRK-014..018`, `OPEN-MOD-001` |
| 61–64 | `DAT-006..033`, `MIG-001..017` |
| 65–66 | `PRD-003`, `FOC-001..005` |
| 67–73 | `FOC-009..013`, `FOC-020..024`, `MOD-018`, `OPEN-FOC-001` |
| 74–76 | `UX-001..018`, `FOC-006..013` |
| 77–81 | `FOC-008`, `MOD-006`, `MOD-022`, `MOD-025`, `FOC-014..019` |
| 82–87 | `WRK-007..013`, `UX-019..026`, regression audit |
| 88–90 | `UX-006..010`, `OPEN-UX-001`, `MIG-020` |
| 91 | `UX-018`, `UX-022..023`, `WRK-017`, `MOD-012` |
| 92–93 | `WRK-030..034` |
| Post-consolidation REPL corrections | `UX-011`, `UX-022`, `UX-025`, `UX-045..049`, `FOC-029`, `SCN-009`, `SCN-012..013`, `SCN-FED-001..002`, `UX-R00`, `UX-E00` |

## Downstream coverage

Current `.allium` files and generated tests remain intentionally unmapped at
the rule level because they contain rejected constructs such as `Capture*`,
`Party`, `Priority*`, and generic abandoned interactions. After UX acceptance,
promotion must add two columns to this register for every canonical ID:

```text
Allium obligation | acceptance test(s)
```

An empty cell is a release failure unless the rule is explicitly marked
non-testable with a reviewed rationale.

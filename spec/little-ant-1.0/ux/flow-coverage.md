# UX flow coverage

This is the compact inventory of observable 1.0 routes. It prevents a screen
example from being mistaken for a complete state machine.

Statuses:

```text
screened  — one or more reference compositions exist
partial   — some transitions are settled, but the route is not end to end
missing   — no canonical reference transition exists yet
accepted  — exact dumb route, resulting state, and next envelope were reviewed
mirrored  — accepted dumb route also passed powered-up, Skill, and web/mobile
```

No current route is `accepted`; the synthetic week explicitly has not yet been
run as an interactive transcript.

| Gate | Flow | Current references | Status | Missing boundary |
|---:|---|---|---|---|
| 2 | Shared frame and footer | `UX-R00..R01`, `UX-025`, `UX-045..049`, `UX-062..065`, `UX-070..073`, `SCN-015` | partial | exact monochrome selection marker, narrow/accessibility form, unbound-key rendering, and personality catalogs |
| 2 | JSONL loading splash | `DAT-044`, `UX-094`, `UX-R02` | screened | exact factory ASCII-art polish and interactive cold-load replay |
| 2 | Contextual personality | `UX-F04..F05`, `UX-064..065`, `SCN-014` | partial | review all four 16-phrase English catalogs |
| 2 | Honest-answer assistance | `UX-016..017`, `UX-130`, `SCN-016`, `OPEN-UX-004` | partial | declared bounded tree, leaf confirmation, reverse path, and `/help` recovery for every remaining finite screen |
| 2 | Palette/command escape | `UX-M01`, `UX-022..024`, `UX-047..048`, `UX-072..073` | partial | remaining screen placement, monochrome cursor marker, and unavailable/search recovery |
| 2 | Revision/stale response | `UX-029..031` | missing | `OPEN-UX-002` |
| 2 | Reference selection | `MOD-010`, `MOD-024`, `UX-075..076`, `UX-RF01` | screened | exact single-word/non-Latin handle normalization and recovery under `OPEN-REF-001` |
| 3 | Restore/startup to `next` | `UX-R00`, `UX-F04..F05`, `UX-F09`, `UX-046`, `UX-063`, `UX-080` | partial | pending-envelope result transition |
| 3 | Pristine first start | `UX-E00`, `FOC-029` | screened | Feed/back/end-to-end transition |
| 3 | Useful non-pristine empty | `UX-E01`, `FOC-028` | screened | state-derived choice transitions |
| 3 | Feed text input | `FED-049`, `UX-M01`, `UX-I02`, `UX-047..049`, `UX-144`, `UX-184` | partial | deterministic post-commit revalidation, pristine transition, empty-input failure, and crash replay |
| 3 | Preserve/normalize Raw | `MOD-001`, `MOD-029`, `MOD-049`, `MOD-056..057`, `MOD-065..072`, `FED-052..056`, `WRK-105`, `UX-158..162`, `UX-186..190`, `DAT-046..050`, `UX-S42..S45`, `UX-RA00..RA04` | partial | deterministic paired internal/external-editor and dumb/assisted transcript replay |
| 3 | Nature discovery | `UX-K01..K03`, `FED-024..027` | partial | exact full traversal transcript |
| 3 | Template selection/proposal | `UX-K04..K06`, `FED-028..029` | partial | resulting route and complete preview |
| 3 | Raw triage and disposition | `MOD-001`, `MOD-054`, `MOD-065..072`, `FED-001..009`, `FED-042..056`, `FOC-051..052`, `UX-144..150`, `UX-184..190`, `UX-T01..T09`, `UX-RA00..RA04` | partial | deterministic triage, shelf/link/source, archive, revision, and source-recovery replay |
| 3 | Duplicate suspicion | `MOD-008..012`, `MOD-063`, `FED-015..018`, `FED-046`, `FED-051`, `UX-149`, `UX-T05`, `UX-T08` | partial | Raw-to-Raw and durable Brick-to-Brick merge outcomes plus deterministic replay |
| 3 | Parent/owner/Domain choice | `FED-005`, `FED-007`, `FED-022..023`, `FED-042..043`, `FED-051`, `UX-T02..T04`, `UX-T07` | partial | RawShelf creation and deterministic multi-Domain replay |
| 3 | Initial importance insertion | `UX-C01`, `UX-T07`, `UX-T09`, `IMP-004..010`, `IMP-040..046`, `UX-134..138` | partial | deterministic accepted, skip, no-alternative, either-order, and cancelled-draft replay |
| 3 | Complete Raw-to-Work materialization | `FED-019..021`, `FED-045`, `FED-051`, `UX-185`, `UX-K01..K06`, `UX-T07..T09` | partial | deterministic end-to-end replay and required builders for every factory Nature/Template |
| 3 | Focus proposal and active completion | `UX-F01..F05`, `UX-F07`, `UX-F12..F14`, `UX-M01`, `FOC-048..050`, `WRK-002`, `WRK-005`, `WRK-049`, `UX-069`, `UX-139..143`, `SCN-FOC-006` | partial | nested UX-F13 uncertainty tree, exact `/show` projection, and replay through ordinary and zero-eligible post-completion `next` results |
| 4 | Ordering uncertainty, skip, and provisional placement | `IMP-008..010`, `IMP-040..046`, `UX-096`, `UX-134..138`, `UX-O05`, `UX-O11..O15`, `SCN-IMP-002`, `SCN-IMP-004` | partial | deterministic end-to-end replay including `/tie-break` and no-nearby-alternative placement |
| 4 | Contradiction/recalibration | `IMP-013..015`, `IMP-033..037`, `FOC-042..043`, `UX-097..102`, `UX-O06..O10`, `SCN-IMP-003` | partial | deterministic end-to-end replay still pending |
| 4 | Adaptive bulk ordering | `IMP-005`, `IMP-031..044`, `FOC-041..043`, `UX-091..102`, `UX-134..138`, `UX-O01..O15` | partial | deterministic end-to-end replay |
| 4 | Served-work symptom | `UX-S01..S47`, `WRK-007..013`, `WRK-047`, `WRK-067..107`, `UX-084`, `UX-103..133`, `UX-152..164`, `FED-030..041`, `IMP-039`, `FOC-047`, `DAT-045` | partial | exact bounded custom-sprint/general-date selection, remaining update-branch screens, Nature matrix, and empty/multi-Domain recovery under `OPEN-SKIP-001`; downstream Feed or handoff results remain with their owning flows |
| 4 | Atomic break/reclassification and part addition | `UX-S06`, `UX-S55..S59`, `UX-B00..B02`, `MOD-045..047`, `MOD-052`, `MOD-062`, `IMP-030`, `IMP-045`, `FOC-039..040`, `WRK-112`, `WRK-115..116`, `UX-057`, `UX-085..089`, `UX-174..179` | partial | remaining all-pairs reconciliations, deterministic interactive replay, duplicate-suspicion handoff, and exact undo compensation |
| 4 | Focus/WIP interruption | `FOC-025`, `FOC-032..033`, `FOC-038`, `UX-F06`, `UX-F09..F10`, `UX-066..067`, `UX-080..081`, `WRK-001..006`, `WRK-048`, `WRK-065` | partial | WIP action result screens, public command names, and remaining `OPEN-WRK-001` boundary |
| 4 | Merge/supersede/subtree outcome | `MOD-011..012`, `MOD-031..032`, `UX-RF02` | partial | relationship-transfer and subtree outcomes under `OPEN-MERGE-001`, `OPEN-TREE-001` |
| 4 | Archive and relevance review | `MOD-055..057`, `FOC-053`, `WRK-098..105`, `UX-152..161`, `UX-S35..S45`, `SCN-ARC-001` | partial | remaining typed branch screens, supersession transfer, honest-answer tree, subtree outcomes, and paired surface replay |
| 4 | Meaning, title, and attached description | `MOD-056..057`, `MOD-065..071`, `FED-037`, `FED-052..055`, `WRK-103..105`, `UX-156..162`, `UX-186..188`, `DAT-046`, `UX-S39..S45`, `UX-RA00..RA03`, `SCN-ARC-001` | partial | remaining uncertainty trees and paired surface replay |
| 4 | Behavior and Nature reclassification | `MOD-058..063`, `WRK-106..118`, `UX-163..181`, `UX-S46..S59`, `UX-L00..L01`, `SCN-ARC-001` | partial | remaining all-pairs capability-delta consequences and generated transition validation under `OPEN-NAT-001`, direct behavior uncertainty tree, undo conflicts, and paired surface replay |
| 4 | Direct semantic update | `MOD-060..064`, `WRK-101..121`, `UX-154..183`, `UX-S37..S59`, `UX-L00..L01`, `UX-D02..D04`, `SCN-ARC-001`, `SCN-DEL-001` | partial | placement reuses `IMP-004`, `IMP-045`, and `MOD-031`; compensation remains under `OPEN-UNDO-001`; parent-search tie ranking remains under `OPEN-REF-001`; timing, context, and source-material branch screens, remaining uncertainty trees, exact return envelopes, and paired direct/stale/archived replay |
| 4 | Escape/undo/redo/recovery | `UX-019..021`, `UX-U01..U02`, `SCN-UNDO-001`, `OPEN-UNDO-001` | partial | exhaustive typed compensation matrix and conflict replay |
| 4 | Global search and return | `UX-151`, `UX-RF03`, `SCN-SRCH-001` | partial | deterministic cross-kind ranking, pagination, and paired surface replay |
| 5 | Cross-Domain focus | `UX-F02`, `UX-F12..F14`, `FOC-014..019`, `FOC-048..050` | partial | hard scope and equal-specificity target |
| 5 | N-step/branching blockers | `UX-F03`, `UX-F12..F14`, `FOC-020..024`, `FOC-048..050` | partial | non-Brick endpoint and branch inspection |
| 5 | Wait activation and review | `MOD-050`, `FOC-034`, `WRK-050..054`, `UX-S02C`, `UX-W01`, `SCN-WAIT-001` | partial | first-review and repeated-review policy under `OPEN-WAIT-001` |
| 5 | Project/collection descent | `MOD-015`, `MOD-045..046`, `FOC-010..013`, `FOC-039`, `WRK-066`, `UX-083`, `UX-F01`, `UX-F11`, `UX-B01`, `SCN-FOC-004` | partial | final-child transition result plus archived/superseded child and subtree outcomes under `OPEN-TREE-001` |
| 5 | Lazy claim review lottery | `MOD-052..053`, `IMP-030..031`, `FOC-040..041`, `UX-090..091`, `UX-095`, `UX-B02`, `UX-N01`, `UX-O01`, `UX-O04`, `SCN-FOC-004` | partial | exact Nature-review result envelope and deterministic paired replay |
| 5 | Importance/forecast projections | `IMP-003`, `FOC-002`, `FOC-013` | missing | list choice, inspect, recursive queries |
| 6 | Living-checklist run | `UX-L00..L01`, `MOD-003`, `MOD-035..037`, `MOD-063`, `WRK-019..020`, `WRK-117..118`, `UX-180..181`, `SCN-LST-001` | partial | deterministic transcript replay and exact undo compensation |
| 6 | Finite-checklist run | `UX-083`, `UX-L00..L01`, `MOD-003`, `MOD-036..037`, `MOD-063`, `FOC-039`, `WRK-066`, `WRK-117..118`, `UX-180..181`, `SCN-LST-001` | partial | deterministic transcript replay and exact undo compensation |
| 6 | Nature capability matrix | factory Nature table | missing | Gate 6 matrix |
| 7 | Date notice/later | `WRK-014..018`, `UX-A01` | partial | `OPEN-TIME-001` |
| 7 | Repeatable return/jitter | `WRK-021..022`, `WRK-062`, `WRK-064`, `UX-078..079`, `UX-F08`, `SCN-REP-001` | partial | completion/reschedule/retire screens |
| 7 | Recurring obligation | `WRK-023`, `WRK-062`, `WRK-064`, `SCN-TIME-001` | missing | occurrence release, overdue, close, and exact skip result screen |
| 7 | Habit schedule/outcome | `WRK-024..027`, `WRK-062..064`, `UX-079`, `UX-P01`, `SCN-PRC-001` | partial | `OPEN-WRK-002`, exact fixed-slot/quota skip results, and schedule screens |
| 7 | Scheduled commitment | `FOC-030..031`, `WRK-041..046` | missing | `OPEN-SCH-001..002` |
| 8 | Raw review/source reconcile | `MOD-065..072`, `FED-010..014`, `FED-052..056`, `UX-186..190`, `DAT-011..017`, `DAT-047..050`, UX-RA00..RA04 | screened | deterministic end-to-end and corrupt-blob fixture replay |
| 8 | `/translate` | `MOD-049`, `MOD-071`, `FED-054..055`, `UX-188`, UX-RA03 | screened | deterministic dumb/assisted queue replay |
| 8 | Delegation lifecycle | `MOD-051`, `MOD-064`, `FOC-035..036`, `WRK-029..034`, `WRK-056..061`, `WRK-119..121`, `UX-182..183`, `UX-A01..A02`, `UX-D01..D04`, `SCN-DEL-001` | partial | deterministic transcript replay, ContactPoint bindings under `OPEN-MOD-001`, effect adapter protocol under `OPEN-EFF-001`, scheduled-commitment scope under `OPEN-SCH-001`, and exact compensation under `OPEN-UNDO-001` |
| 8 | Import/migrate/erase source | `DAT-011..017`, `DAT-042..043` | missing | effect/failure screens |
| 8 | Calendar observe/write | `DAT-038..041` | missing | `OPEN-CAL-001` |
| 8 | Typed reference/error/dry-run | `MOD-008..010`, `UX-040..042`, `UX-075..076`, `UX-RF01..RF02`, `SCN-REF-001` | partial | technical-reference, not-found, precondition, edge-normalization, and generic dry-run screens |
| 8 | Corrupt history/repair | `MIG-001..017` | missing | `OPEN-DAT-002` |
| 9 | Powered-up paired replay | `UX-033..039`, `UX-043`, `UX-059..060`, `UX-086..087`, `UX-B00A..B00B` | partial | replay accepted dumb flows |
| 10 | Skill and web/mobile mirror | screen-catalog surface mapping | missing | accepted envelopes required first |

Each route becomes `accepted` only when its transcript records:

```text
entry revision and deterministic inputs
exact screen
action ID and key/input
domain event(s), or explicit no-mutation result
new revision and observable postcondition
next envelope
Escape, uncertainty, and failure branches
```

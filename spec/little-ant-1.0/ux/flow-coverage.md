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
| 2 | Contextual personality | `UX-F04..F05`, `UX-064..065`, `SCN-014` | partial | review all four 16-phrase English catalogs |
| 2 | Contextual uncertainty/help | `UX-H01`, `UX-016..017` | partial | assistance subpages and return transitions |
| 2 | Palette/command escape | `UX-M01`, `UX-022..024`, `UX-047..048`, `UX-072..073` | partial | remaining screen placement, monochrome cursor marker, and unavailable/search recovery |
| 2 | Revision/stale response | `UX-029..031` | missing | `OPEN-UX-002` |
| 2 | Reference selection | `MOD-010`, `MOD-024`, `UX-075..076`, `UX-RF01` | screened | exact single-word/non-Latin handle normalization and recovery under `OPEN-REF-001` |
| 3 | Restore/startup to `next` | `UX-R00`, `UX-F04..F05`, `UX-F09`, `UX-046`, `UX-063`, `UX-080` | partial | pending-envelope result transition |
| 3 | Pristine first start | `UX-E00`, `FOC-029` | screened | Feed/back/end-to-end transition |
| 3 | Useful non-pristine empty | `UX-E01`, `FOC-028` | screened | state-derived choice transitions |
| 3 | Feed text input | `UX-M01`, `UX-I02`, `UX-047..049` | partial | submit route and proposal revalidation |
| 3 | Preserve/normalize Raw | `MOD-001`, `MOD-029`, `MOD-049` | missing | `OPEN-RAW-001..002` |
| 3 | Nature discovery | `UX-K01..K03`, `FED-024..027` | partial | exact full traversal transcript |
| 3 | Template selection/proposal | `UX-K04..K06`, `FED-028..029` | partial | resulting route and complete preview |
| 3 | Raw/Brick/ListEntry/enrich route | `FED-001..009` | missing | route-choice grammar |
| 3 | Duplicate suspicion | `MOD-008..012`, `FED-015..018` | missing | candidate/outcome screens |
| 3 | Parent/owner/Domain choice | `FED-005`, `FED-022..023` | missing | target and optional-membership screens |
| 3 | Initial importance insertion | `UX-C01`, `IMP-004..010` | partial | accepted answer through final placement |
| 3 | Complete Feed confirmation/result | `FED-019..021` | missing | full preview, mutation, prior-proposal revalidation |
| 3 | Focus proposal and active completion | `UX-F01..F05`, `UX-F07`, `UX-M01`, `WRK-002`, `WRK-005`, `WRK-049`, `UX-069` | partial | exact replay through ordinary and zero-eligible post-completion `next` results |
| 4 | Ordering skip and provisional placement | `IMP-008..010` | missing | `OPEN-IMP-001` |
| 4 | Contradiction/recalibration | `IMP-013..015` | missing | provocative check and local replacement screens |
| 4 | Adaptive bulk ordering | `IMP-005`, `IMP-031`, `FOC-041`, `UX-091`, `UX-O01` | partial | exact one-pair result, completed-run result, and `/order` scope entry |
| 4 | Served-work symptom | `UX-S01..S06`, `WRK-007..013`, `WRK-047`, `WRK-067`, `UX-084`, `FED-030..031` | partial | reaction screens other than settled `blocked or waiting` and `big` under `OPEN-SKIP-001` |
| 4 | Atomic break/reclassification | `UX-S06`, `UX-B00..B02`, `MOD-045..047`, `MOD-052`, `IMP-030`, `FOC-040`, `UX-057`, `UX-085..089` | partial | deterministic interactive replay and exact undo compensation |
| 4 | Focus/WIP interruption | `FOC-025`, `FOC-032..033`, `FOC-038`, `UX-F06`, `UX-F09..F10`, `UX-066..067`, `UX-080..081`, `WRK-001..006`, `WRK-048`, `WRK-065` | partial | WIP action result screens, public command names, and remaining `OPEN-WRK-001` boundary |
| 4 | Merge/supersede/subtree outcome | `MOD-011..012`, `MOD-031..032`, `UX-RF02` | partial | relationship-transfer and subtree outcomes under `OPEN-MERGE-001`, `OPEN-TREE-001` |
| 4 | Escape/undo/redo/recovery | `UX-019..021`, `UX-U01..U02`, `SCN-UNDO-001` | partial | redo conflict and no-candidate educational result |
| 5 | Cross-Domain focus | `UX-F02`, `FOC-014..019` | partial | hard scope and equal-specificity target |
| 5 | N-step/branching blockers | `UX-F03`, `FOC-020..024` | partial | non-Brick endpoint and branch inspection |
| 5 | Wait activation and review | `MOD-050`, `FOC-034`, `WRK-050..054`, `UX-S02C`, `UX-W01`, `SCN-WAIT-001` | partial | first-review and repeated-review policy under `OPEN-WAIT-001` |
| 5 | Project/collection descent | `MOD-015`, `MOD-045..046`, `FOC-010..013`, `FOC-039`, `WRK-066`, `UX-083`, `UX-F01`, `UX-F11`, `UX-B01`, `SCN-FOC-004` | partial | final-child transition result plus dropped/superseded child and subtree outcomes under `OPEN-TREE-001` |
| 5 | Lazy claim review lottery | `MOD-052..053`, `IMP-030..031`, `FOC-040..041`, `UX-090..091`, `UX-B02`, `UX-N01`, `UX-O01`, `SCN-FOC-004` | partial | exact Nature- and importance-review result envelopes |
| 5 | Importance/forecast projections | `IMP-003`, `FOC-002`, `FOC-013` | missing | list choice, inspect, recursive queries |
| 6 | Living-checklist run | `UX-L01`, `MOD-035..037`, `WRK-019..020` | partial | `OPEN-LST-001` |
| 6 | Finite-checklist run | `MOD-036..037` | missing | `OPEN-LST-001` |
| 6 | Nature capability matrix | factory Nature table | missing | Gate 6 matrix |
| 7 | Date notice/later | `WRK-014..018`, `UX-A01` | partial | `OPEN-TIME-001` |
| 7 | Repeatable return/jitter | `WRK-021..022`, `WRK-062`, `WRK-064`, `UX-078..079`, `UX-F08`, `SCN-REP-001` | partial | completion/reschedule/retire screens |
| 7 | Recurring obligation | `WRK-023`, `WRK-062`, `WRK-064`, `SCN-TIME-001` | missing | occurrence release, overdue, close, and exact skip result screen |
| 7 | Habit schedule/outcome | `WRK-024..027`, `WRK-062..064`, `UX-079`, `UX-P01`, `SCN-PRC-001` | partial | `OPEN-WRK-002`, exact fixed-slot/quota skip results, and schedule screens |
| 7 | Scheduled commitment | `FOC-030..031`, `WRK-041..046` | missing | `OPEN-SCH-001..002` |
| 8 | Raw review/source reconcile | `FED-010..014`, `DAT-011..017` | missing | `OPEN-RAW-003` |
| 8 | `/translate` | `MOD-049` | missing | `OPEN-RAW-002` |
| 8 | Delegation lifecycle | `WRK-029..034`, `UX-A01` | partial | `OPEN-DEL-001` |
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

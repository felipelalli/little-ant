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
| 2 | Shared frame and status | `UX-R00..R01`, `UX-025`, `UX-045..049`, `UX-062..065` | partial | narrow/accessibility form, unbound-key rendering, and exact personality catalogs |
| 2 | Contextual personality | `UX-F04..F05`, `UX-064..065`, `SCN-014` | partial | review all four 16-phrase English catalogs |
| 2 | Contextual uncertainty/help | `UX-H01`, `UX-016..017` | partial | assistance subpages and return transitions |
| 2 | Palette/command escape | `UX-M01`, `UX-022..024`, `UX-047..048` | partial | remaining screen placement and unavailable/search recovery under `OPEN-UX-003` |
| 2 | Revision/stale response | `UX-029..031` | missing | `OPEN-UX-002` |
| 2 | Reference selection | `MOD-010`, `MOD-024` | missing | `OPEN-REF-001` |
| 3 | Restore/startup to `next` | `UX-R00`, `UX-F04..F05`, `UX-046`, `UX-063` | partial | pending-envelope result transition |
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
| 3 | Focus and secondary done | `UX-F01..F05`, `UX-M01`, `WRK-002`, `WRK-005` | partial | `/done` result and next envelope |
| 4 | Ordering skip and provisional placement | `IMP-008..010` | missing | `OPEN-IMP-001` |
| 4 | Contradiction/recalibration | `IMP-013..015` | missing | provocative check and local replacement screens |
| 4 | Adaptive bulk ordering | `IMP-005` | missing | one-pair step, interruption, settled result |
| 4 | Served-work symptom | `UX-S01`, `WRK-007..013`, `WRK-047` | partial | every reaction screen under `OPEN-SKIP-001` |
| 4 | Atomic break/reclassification | `UX-B01`, `MOD-045..047` | screened | accepted/rejected result transitions |
| 4 | Focus/WIP interruption | `FOC-033`, `UX-066`, `WRK-001..006` | partial | pause/idle command grammar, result screens, and `OPEN-WRK-001` |
| 4 | Merge/supersede/subtree outcome | `MOD-011..012`, `MOD-031..032` | missing | `OPEN-MERGE-001`, `OPEN-TREE-001` |
| 4 | Escape/undo/redo/recovery | `UX-019..021`, `SCN-UNDO-001` | missing | exact screens and conflict result |
| 5 | Cross-Domain focus | `UX-F02`, `FOC-014..019` | partial | hard scope and equal-specificity target |
| 5 | N-step/branching blockers | `UX-F03`, `FOC-020..024` | partial | non-Brick endpoint and branch inspection |
| 5 | Project/collection descent | `FOC-010..013` | missing | container draw/decomposition screens |
| 5 | Importance/forecast projections | `IMP-003`, `FOC-002`, `FOC-013` | missing | list choice, inspect, recursive queries |
| 6 | Living-checklist run | `UX-L01`, `MOD-035..037`, `WRK-019..020` | partial | `OPEN-LST-001` |
| 6 | Finite-checklist run | `MOD-036..037` | missing | `OPEN-LST-001` |
| 6 | Nature capability matrix | factory Nature table | missing | Gate 6 matrix |
| 7 | Date notice/later | `WRK-014..018`, `UX-A01` | partial | `OPEN-TIME-001` |
| 7 | Repeatable return/jitter | `WRK-021..022`, `SCN-REP-001` | missing | completion/reschedule/retire screens |
| 7 | Recurring obligation | `WRK-023` | missing | occurrence release, overdue, close |
| 7 | Habit schedule/outcome | `WRK-024..027`, `UX-P01` | partial | `OPEN-WRK-002` and schedule screens |
| 7 | Scheduled commitment | `FOC-030..031`, `WRK-041..046` | missing | `OPEN-SCH-001..002` |
| 8 | Raw review/source reconcile | `FED-010..014`, `DAT-011..017` | missing | `OPEN-RAW-003` |
| 8 | `/translate` | `MOD-049` | missing | `OPEN-RAW-002` |
| 8 | Delegation lifecycle | `WRK-029..034`, `UX-A01` | partial | `OPEN-DEL-001` |
| 8 | Import/migrate/erase source | `DAT-011..017`, `DAT-042..043` | missing | effect/failure screens |
| 8 | Calendar observe/write | `DAT-038..041` | missing | `OPEN-CAL-001` |
| 8 | Typed error/dry-run | `UX-040..042` | missing | complete reference screens |
| 8 | Corrupt history/repair | `MIG-001..017` | missing | `OPEN-DAT-002` |
| 9 | Powered-up paired replay | `UX-033..039`, `UX-043`, `UX-059..060` | partial | replay accepted dumb flows |
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

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
| 2 | Shared frame and footer | `UX-R00..R02`, `UX-025`, `UX-045..049`, `UX-062..065`, `UX-070..073`, `UX-252..259`, UX-A11Y00, `SCN-014..015`, `SCN-UI-001` | specified | styled/plain/emoji/narrow parity, permanent cursor, unbound keys, and exact catalogs |
| 2 | JSONL loading splash | `DAT-044`, `UX-094`, UX-R02, `SCN-UI-001` | specified | factual cold replay, cancellation, corruption, and noninteractive omission |
| 2 | Contextual personality | `UX-F04..F05`, `UX-064..065`, `UX-259`, [`personality-catalog.md`](../personality-catalog.md), `SCN-014`, `SCN-UI-001` | specified | exact four-by-sixteen English catalog and dumb/assisted replay |
| 2 | Honest-answer assistance | `UX-016..017`, `UX-130..143`, `UX-196`, `SCN-016` | specified | generated family-route coverage for every finite screen and paired assisted annotations |
| 2 | Palette/command escape | UX-M01, `UX-022..024`, `UX-047..048`, `UX-072..073`, `UX-254..258`, UX-A11Y00, `SCN-UI-001` | specified | contextual placement, permanent cursor, filtering, unavailable-key recovery, and exact return |
| 2 | Revision/stale response | `UX-029..031`, `UX-191..193`, UX-ER02 | screened | concurrency, crash, and integrity-token fixture replay |
| 2 | Reference selection | `MOD-010`, `MOD-024`, `UX-075..076`, `UX-201..203`, UX-RF01, UX-RF04 | screened | edge-normalization and deterministic cross-surface replay |
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
| 4 | Contradiction/recalibration | `IMP-013..015`, `IMP-033..037`, `IMP-055`, `FOC-042..043`, `UX-097..102`, `UX-230`, `UX-O06..O10`, UX-J07, `SCN-IMP-003`, `SCN-JUD-001` | specified | deterministic per-axis decay, cycle, provocation, skip, and assisted replay |
| 4 | Adaptive bulk ordering | `IMP-005`, `IMP-031..044`, `FOC-041..043`, `UX-091..102`, `UX-134..138`, `UX-O01..O15` | partial | deterministic end-to-end replay |
| 4 | Impact, maturity, and effort judgment | `IMP-017..029`, `IMP-038`, `IMP-047..056`, `FOC-054`, `FOC-061`, `UX-224..234`, UX-J00..J08, `SCN-JUD-001` | specified | direct, comparative, evidence-ladder, stale-evidence, contradiction, structured-output, and paired assisted replay |
| 4 | Optional phase review | `MOD-017..018`, `FOC-061`, `UX-252..253`, UX-PH00, `SCN-UI-001` | specified | all four phases, no-phase path, text/emoji parity, lazy review, direct update, undo, and assisted suggestion |
| 4 | Served-work symptom | `UX-S01..S47`, UX-S08E, UX-S15A, UX-S35A, UX-S37A, UX-DT00..DT02, UX-UP00..UP02, `WRK-007..013`, `WRK-047`, `WRK-067..128`, `UX-084`, `UX-103..133`, `UX-152..164`, `UX-211..217`, `FED-030..041`, `IMP-039`, `FOC-047`, `DAT-045` | specified | deterministic replay of every symptom, Nature-owned completion/deferral, shared date input, and paired assisted surface; downstream Feed or handoff results remain with their owning flows |
| 4 | Atomic break/reclassification and part addition | `UX-S06`, `UX-S55..S59`, `UX-B00..B02`, UX-NAT01, `MOD-045..047`, `MOD-052`, `MOD-062`, `MOD-077..081`, `IMP-030`, `IMP-045`, `FOC-039..040`, `WRK-112`, `WRK-115..116`, `WRK-122`, `UX-057`, `UX-085..089`, `UX-174..179` | specified | deterministic interactive replay, duplicate-suspicion handoff, and exact undo compensation |
| 4 | Focus/WIP interruption | `FOC-025`, `FOC-032..033`, `FOC-038`, UX-F06/F09/F10/F15, `UX-066..069`, `UX-080..081`, `UX-238`, `WRK-001..006`, `WRK-048..049`, `WRK-065`, `WRK-139..140`, `SCN-WRK-001` | specified | focus, pause, idle, Nature-owned done/finish, archive, invalid-alias, dry-run, undo, and paired operator replay |
| 4 | Merge/supersede/subtree outcome | `MOD-011..012`, `MOD-031..032`, `MOD-083..088`, `WRK-129..133`, `UX-218..223`, UX-LC00..LC05, `UX-RF02`, `SCN-LC-001` | specified | exhaustive transfer-matrix fixtures, cross-boundary gates, atomic compensation, and paired assisted replay |
| 4 | Archive and relevance review | `MOD-055..057`, `MOD-083..088`, `FOC-053`, `WRK-098..105`, `WRK-129..133`, `UX-152..161`, `UX-215`, `UX-218..223`, `UX-S35..S45`, UX-S35A, UX-LC00..LC05, `SCN-ARC-001`, `SCN-LC-001` | specified | deterministic archive, restoration, relevance, supersession, subtree, undo, and paired assisted replay |
| 4 | Meaning, title, and attached description | `MOD-056..057`, `MOD-065..071`, `FED-037`, `FED-052..055`, `WRK-103..105`, `UX-156..162`, `UX-186..188`, `DAT-046`, `UX-S39..S45`, `UX-RA00..RA03`, `SCN-ARC-001` | partial | remaining uncertainty trees and paired surface replay |
| 4 | Behavior and Nature reclassification | `MOD-058..064`, `MOD-077..082`, `WRK-106..118`, `WRK-122`, `UX-163..181`, `UX-S46..S59`, `UX-NAT01`, `UX-L00..L01`, `SCN-ARC-001` | specified | generated 81-transition capability-delta validation, direct behavior uncertainty tree, compensation conflicts, and paired surface replay |
| 4 | Direct semantic update | `MOD-060..064`, `WRK-101..128`, `UX-154..183`, `UX-196..203`, `UX-216..217`, `UX-S37..S59`, UX-S37A, UX-UP00..UP02, UX-DT00..DT02, `UX-L00..L01`, `UX-D02..D04`, `SCN-ARC-001`, `SCN-DEL-001` | specified | paired direct, stale, archived, typed-branch, uncertainty, and undo replay |
| 4 | Escape/undo/redo/recovery | `UX-019..021`, `UX-191..200`, `UX-U01..U02`, UX-ER01..ER03, `SCN-UNDO-001` | specified | exhaustive mutation-family fixtures and concurrent-conflict replay |
| 4 | Global search and return | `UX-151`, `UX-RF03`, `SCN-SRCH-001` | partial | deterministic cross-kind ranking, pagination, and paired surface replay |
| 5 | Cross-Domain focus | `MOD-073..076`, `FED-057..058`, `UX-F02`, `UX-F12..F14`, `UX-DM00..DM03`, `FOC-014..019`, `FOC-055..060`, `UX-205..210`, `SCN-DOM-001` | specified | deterministic forest, hard-scope, tie-path, and edge-case replay |
| 5 | N-step/branching blockers | `UX-F03`, `UX-F12..F14`, `FOC-020..024`, `FOC-048..050`, `FOC-055..058` | specified | parent/child gate order and every non-Brick endpoint replay |
| 5 | Wait activation and review | `MOD-050`, `FOC-034`, `WRK-050..055`, `WRK-127`, `WRK-134..138`, `UX-235..237`, `UX-S02C`, UX-W00..W03, UX-DT00..DT02, `SCN-WAIT-001` | specified | activation, gating, pressure, history-backed timing, follow-up strategy, source confirmation, typed skip, and paired assisted replay |
| 5 | Project/collection descent | `MOD-015`, `MOD-045..046`, `MOD-083..084`, `FOC-010..013`, `FOC-039`, `WRK-066`, `WRK-129..130`, `UX-083`, `UX-218..219`, `UX-F01`, `UX-F11`, `UX-B01`, UX-LC00/LC04, `SCN-FOC-004`, `SCN-LC-001` | specified | deterministic mixed-child closure and explicit parent/subtree lifecycle replay |
| 5 | Lazy claim review lottery | `MOD-052..053`, `IMP-030..031`, `FOC-040..041`, `UX-090..091`, `UX-095`, `UX-B02`, `UX-N01`, `UX-O01`, `UX-O04`, `SCN-FOC-004` | partial | exact Nature-review result envelope and deterministic paired replay |
| 5 | Importance/forecast projections | `IMP-003`, `FOC-002`, `FOC-013`, `FOC-054..061`, `UX-210`, `MOD-076` | screened | fixed-stream probabilities, opportunity-catalog fixtures, and recursive query replay |
| 6 | Living-checklist run | `UX-L00..L01`, `MOD-003`, `MOD-035..037`, `MOD-063`, `WRK-019..020`, `WRK-117..118`, `UX-180..181`, `SCN-LST-001` | partial | deterministic transcript replay and exact undo compensation |
| 6 | Finite-checklist run | `UX-083`, `UX-L00..L01`, `MOD-003`, `MOD-036..037`, `MOD-063`, `FOC-039`, `WRK-066`, `WRK-117..118`, `UX-180..181`, `SCN-LST-001` | partial | deterministic transcript replay and exact undo compensation |
| 6 | Nature capability matrix | factory Nature table | missing | Gate 6 matrix |
| 7 | Date notice/later | `WRK-014..018`, `WRK-146..147`, `UX-244`, UX-NOT00, `SCN-TIME-001` | specified | safe-boundary surfacing, bounded rotation, acknowledge, snooze, inspection, and deterministic replay |
| 7 | Repeatable return/jitter | `WRK-021..022`, `WRK-062`, `WRK-064`, `WRK-139..142`, `UX-078..079`, `UX-239..240`, UX-F08, UX-REP00..REP01, `SCN-REP-001` | specified | first/existing return, exact/jittered policy, manual-only, archive, crash, dry-run, undo, and paired assisted replay |
| 7 | Recurring obligation | `IMP-057`, `FOC-062`, `WRK-023`, `WRK-062`, `WRK-064`, `WRK-148..150`, `UX-245..246`, UX-RO00..RO01, `SCN-TIME-001` | specified | zoned release, stable occurrence identity, catch-up, one series attention slot, local positive-tail selection, and ordinary Work outcomes |
| 7 | Habit schedule/outcome | `WRK-024..027`, `WRK-038..040`, `WRK-062..064`, `WRK-143..145`, `FOC-054`, `UX-079`, `UX-241..243`, UX-P01, UX-H00..H01, `SCN-PRC-001..002` | specified | fixed-slot and quota editors, truthful outcomes, streaks, rollover, and bounded introspection replay |
| 7 | Scheduled commitment | `MOD-043`, `MOD-047`, `MOD-089`, `FOC-030..031`, `WRK-041..046`, `WRK-151..156`, `UX-247..251`, UX-SC00..SC05, `SCN-SCH-001..002` | specified | exact intervals, hard precedence, truthful outcomes, focus/overlap handling, preparation, delegation boundary, and atomic rescheduling |
| 8 | Raw review/source reconcile | `MOD-065..072`, `FED-010..014`, `FED-052..056`, `UX-186..190`, `DAT-011..017`, `DAT-047..050`, UX-RA00..RA04 | screened | deterministic end-to-end and corrupt-blob fixture replay |
| 8 | `/translate` | `MOD-049`, `MOD-071`, `FED-054..055`, `UX-188`, UX-RA03 | screened | deterministic dumb/assisted queue replay |
| 8 | Delegation lifecycle | `MOD-051`, `MOD-064`, `MOD-090..092`, `FOC-035..036`, `WRK-029..034`, `WRK-056..061`, `WRK-119..121`, `DAT-057..073`, `UX-182..183`, `UX-197..199`, `UX-260..266`, UX-A01..A02, UX-D01..D04, UX-CNT00..CNT01, UX-VLT00, UX-EFX00, `SCN-DEL-001`, `SCN-EFF-001`, `SCN-SEC-001` | specified | exact delivery purposes, immutable consent, dispatch-before-I/O, failure/retry/unknown outcomes, contacts, bindings, and vault |
| 8 | Profiles, preferences, and credential vault | `PRD-011`, `MOD-090..092`, `DAT-024..027`, `DAT-057..067`, `UX-260..264`, UX-CNT00..CNT01, UX-VLT00, UX-CFG00, `SCN-SEC-001` | specified | separate typed XDG stores, multi-profile resolution, age-v1 vault, recovery/rotation, memory agent, locked-state return, and redaction threat replay |
| 8 | Import/migrate/erase source | `DAT-011..017`, `DAT-042..043`, `DAT-068..079`, UX-IMP00..IMP02, UX-A01, UX-EFX00, `UX-265..267`, `SCN-EXT-001`, [`standard-integration-catalog.md`](../standard-integration-catalog.md) | specified | Raw-first preflight, exact shipping modes, verification, supported cleanup, partial effects, and file-source limits |
| 8 | Calendar observe/write | `DAT-038..041`, `DAT-068..073`, `DAT-080..085`, `WRK-148..156`, UX-CAL00..CAL01, UX-A01, UX-EFX00, `UX-265..268`, `SCN-CAL-001` | specified | observe-first allowlist, adoption scope, exact/all-day/series routing, reconciliation, reviewed write-back, and privacy |
| 8 | Local web UIAdapter | `DAT-032`, `DAT-074..075`, `UX-269`, `SCN-UIA-001`, [`standard-integration-catalog.md`](../standard-integration-catalog.md) | specified | loopback-only mirror, session/revision safety, no browser credentials, and no second grammar |
| 8 | Pack trust/install/update/remove | `DAT-018..023`, `DAT-033`, `DAT-086..091`, `UX-270..272`, UX-PACK00..PACK02, `SCN-PACK-001`, [`pack-format-and-trust.md`](../pack-format-and-trust.md) | specified | reproducible archive, signatures, official/community trust, revocation, zero cross-Pack dependencies, explicit updates, and safe removal |
| 8 | Typed reference/error/dry-run | `MOD-008..010`, `UX-040..042`, `UX-075..076`, `UX-RF01..RF02`, `SCN-REF-001` | partial | technical-reference, not-found, precondition, edge-normalization, and generic dry-run screens |
| 8 | Corrupt history/repair | `DAT-049`, `DAT-055..056`, `MIG-001..044`, UX-ER01 | specified | corrupt-log, unknown-version, backup, and repair fixtures |
| 9 | v0.1 preflight/candidate/cutover | `MIG-001..044`, `UX-273..275`, UX-MIG00..MIG02, `SCN-MIG-001` | specified | exact-schema projection, blocker repair, stable identity allocation, stale plans, full replay, atomic cutover, backup, and no external effects |
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

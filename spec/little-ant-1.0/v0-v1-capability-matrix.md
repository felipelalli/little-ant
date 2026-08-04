# V0 to 1.0 capability matrix

Status: **authoritative regression register; unresolved rows block the 1.0
specification freeze**

This register protects product capability, not old command count or old names.
Every meaningful v0 behavior receives an explicit 1.0 disposition. A removed
command is not a regression when its capability remains reachable through the
canonical 1.0 interaction; a passing parser or generated test suite is not
evidence that the capability survived.

## Evidence boundary

The final implementation-first v0 baseline is commit `c6f3cb7`, immediately
before the 1.0 conceptual-design work. Evidence strength is:

```text
I+T  implemented and covered by a behavioral test
I    implemented, with no dedicated behavioral test found
O    explicit operator/interaction contract
D    design statement or aspiration, not delivered v0 behavior
```

Primary evidence is recoverable from:

```text
c6f3cb7:app/Main.hs
c6f3cb7:src/LittleAnt/
c6f3cb7:test/Spec.hs
c6f3cb7:skills/little-ant/SKILL.md
c6f3cb7:spec/little-ant.allium
```

The July 10 pre-rewrite bundle ends at an older checkpoint and is not the
final-v0 vocabulary baseline. In particular, final v0 had already changed
`capture`, `energy`, `session`, and `!` to `feed`, `weight`, `flow`, and `*`.

Dispositions mean:

```text
retained              same product capability and compatible semantics
strengthened          capability retained with stricter 1.0 guarantees
replaced              deliberate new model serving the same need
explicitly simplified useful intent retained through a smaller model
retired               deliberately absent from 1.0
unresolved            no trustworthy 1.0 disposition yet
```

## Product, protocol, and control

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| Deterministic offline core with judgment outside it | `I+T`, state/command tests; `O`, skill | **strengthened** | `PRD-006..009`, `DAT-001..005` | synthetic-week replay |
| `feed` is the only ingress word; natural-language synonyms stay outside the core | `I+T`, `59e1d8f`, `Command.hs`; `O` | **retained** | `PRD-013`, `FED-001..009` | `SCN-FED-001..004` |
| Core-owned grammar, stable answer letters, `*`, `?`, and contextual `[l]ater` | `I+T`, `Grammar.hs`; `O` | **strengthened** | `UX-012..018`, `UX-022..024` | interaction-vocabulary gate |
| Finite choices execute with one key and no Enter | `O`; partly terminal-tested | **retained** | `UX-011..014` | exact dumb-REPL transcript |
| A full command word can interrupt a pending one-key question | `O`; partial parser behavior | **replaced** | explicit `[/] more...` palette suspends the pending interaction under `UX-022`, `UX-047`, and `UX-M01`; bare hidden aliases are rejected by `UX-062` | palette navigation, mutation, Escape, and stale-revalidation simulation |
| JSON success/error envelope includes canonical human rendering | `I+T`, `Main.hs::emit` | **replaced** | `DAT-006..010` sparse typed response plus explicit depth | sparse-versus-complete scenario |
| Typed educational errors distinguish precondition, not found, ambiguous reference, and collision | `I+T`, `CmdError` and exit-code tests | **retained** | `UX-040..042`; exact protocol in `OPEN-DAT-001` | failure-recovery scenario |
| Global `--dry-run` validates without writing | `I+T`, ordinary and migration tests | **strengthened** | `UX-041`, `MIG-014` | mutator/effect/migration dry-runs |
| Every command advances due temporal rules; explicit `tick` runs the same phase | `I+T`, `Tick.hs` | **strengthened** | `WRK-017` | deterministic-clock scenario |
| A guided session ends usefully rather than falling silent | `O`, Allium/skill; v0 CLI violated it on empty state | **strengthened** | `PRD-004`, `FOC-027..029`, `UX-E00..E01` | first-start, empty, filtered-empty, safe-end transcripts |
| Data and product vocabulary are English | `O`; uneven historic data | **retained** | `PRD-010..012`, `UX-049`, `MOD-049` | multilingual Feed and `/translate` route |
| `la` and `lant` are both installed executable names | `I`, packaging | **unresolved** | `OPEN-CLI-001` | command-vocabulary review |

## Identity, material, and feeding

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| Feed asks for no metadata form before entry | `O`, README/skill/Allium | **explicitly simplified** | one Nature is required; all other axes remain lazy under `PRD-014`, `FED-004..009` | three golden Feed routes |
| Raw can yield zero or more work items | `I+T`, extraction tests | **strengthened** | durable, reusable Raw under `MOD-001`, `MOD-023`, `MOD-029`, `MOD-049`, `FED-010..014` | Raw review and description routes |
| Description is a scalar Brick field | `I`, `set --desc` | **replaced** | description is linked Raw under `MOD-029` | create/edit/reuse description Raw |
| Title-derived IDs and exact-title collision | `I+T`, `Ids.hs` | **replaced** | UUIDv7 identities, repeated titles, and duplicate suspicion under `MOD-008..012`, `FED-015..018` | duplicate-title scenarios |
| Unique-prefix reference resolution | `I+T`, `Ids.resolvePrefix` | **deliberately replaced and strengthened** | immutable UUIDv7 identities plus dataset-local mnemonic `#`/`@` handles, typed autocomplete, collision suffixes, rename stability, and previewed merge remapping under `MOD-008..012` and `UX-075..076`; remaining edge grammar in `OPEN-REF-001` | handle allocation, autocomplete, rename, retired-handle, merge-conflict, technical-reference, and action-token scenarios |
| Source fingerprints reveal drift and require reconciliation | `I+T`, source tests | **strengthened** | Raw origin, snapshots, observations, and reconciliation under `FED-014`, `DAT-011..017`, `OPEN-RAW-003` | URL relocation/access-loss scenario |
| Source/content use is non-consuming | `O`; limited v0 structure | **strengthened** | many-link Raw under `MOD-023` | shared description/source scenario |
| Exact source grouping and semantic organization are the same thing | not a delivered guarantee | **retired** | source views and RawShelves remain distinct under `FED-012..013` | import-to-shelf route |

## Lifecycle, hierarchy, and relationships

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| `seed → committed → ready → wip` models commitment and readiness | `I+T` | **explicitly simplified** | active status, optional phase, WIP/focus, and importance position under `MOD-013..018` | migration plus focus route |
| Explicit start, stop, and direct done preserve work history | `I+T` | **strengthened** | `WRK-001..006`; public grammar in `OPEN-WRK-001` | focus/WIP interruption route |
| Break creates independently tracked children | `I+T` | **strengthened** | Nature-aware reclassification and atomic preview under `MOD-019..021`, `MOD-045..047`, `UX-B01` | atomic-break route |
| Closing a parent silently re-roots active children | `I+T` | **retired** | explicit subtree outcome under `MOD-015`, `OPEN-TREE-001` | project closure route |
| Dependencies are acyclic relationships | `I+T` | **retained** | `MOD-021`, `FOC-020..024` | N-step blocker route |
| `unify` retargets comparisons and marks one Brick superseded | `I+T` | **replaced** | explicit previewable `merge` under `MOD-011..012`; transfer matrix in `OPEN-MERGE-001` | merge-conflict route |
| `supersede` preserves lineage and selected relationships | `I+T` | **unresolved** | lineage retained; complete transfer matrix in `OPEN-MERGE-001` | finite and standing replacement routes |
| One free `context` string owns a Brick's organizational placement | `I` | **replaced** | hierarchical, non-exclusive Domain plus composition under `MOD-006`, `MOD-019..022` | Domain membership/query route |
| Person/agent/company/area registry supports requester and delegation | `I+T`, but only name/type were delivered | **strengthened** | ExternalEntity under `MOD-007`, `MOD-030`, `WRK-029`; contacts remain `OPEN-MOD-001` | requester/delegation route |

## Importance order

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| Pairwise binary insertion | `I+T`, `49abaa5`, placement tests | **retained** | sibling-only importance under `IMP-001..004` | `SCN-IMP-001` |
| Adaptive `org-sort-tasks` maintenance: short-run insertion, adaptive merge, ordered-halves shortcut, and known transitive answers | `I+T`, `b35df00`, `Order.mergeSortStep` | **retained** | `IMP-005` | resumable bulk-order transcript |
| One unresolved pair per core maintenance step; persisted answers make interruption safe | `I+T`, ordering tests | **retained** | `IMP-005` | stop/resume bulk-order transcript |
| Human evidence outranks AI pre-ordering | `I+T` | **strengthened** | `IMP-011..015` | assisted insertion and reversal |
| Adjacent question rounds, stale comparisons, and burst/time sanity triggers | `I+T`, `Order.hs`, `Tick.hs` | **replaced** | derived review opportunities, not meta-Bricks, under `IMP-014..016`, `FOC-009` | ordering-maintenance route |
| Dependencies supply hard edges to the same human order | `I+T` | **retired** | dependency and importance are orthogonal under `IMP-001`, `MOD-021` | blocked-but-important scenario |
| Cycles are silently broken by creation order | `I+T` | **retired** | contradiction lowers confidence and provokes local recalibration under `IMP-013..015` | `SCN-IMP-003` |
| Human order exists only on actionable frontier leaves | `I+T` | **replaced** | strict local sibling order for every active Brick under `IMP-002..003` | hierarchy projection scenario |

## Forecast, scope, and continuity

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| Foreground/background queues and periodic background turn | `I+T`, `Scheduler.hs` | **replaced** | hierarchical replay-deterministic weighted draw with positive tail under `FOC-001..013` | fixed-stream forecast sweep |
| Active flow context supports `ignore | prefer | require` | `I+T` | **unresolved** | soft continuity is `FOC-014..019`; hard temporary scope remains `OPEN-DOM-001` | explicit-scope/empty-scope route |
| Blocked and waiting work disappear from the executable frontier | `I+T` | **replaced** | N-step blocker resolution and typed non-Brick endpoint under `FOC-020..024` | `SCN-FOC-003` |
| Anti-starvation is a bounded periodic cadence | `I+T` for background cadence; not for waiting work | **replaced** | positive probability plus aging under `FOC-003..005`; bounded-service guarantee remains `OPEN-FOC-003` | long-run parameter sweep |
| Project/container selection descends to concrete work | partial `I`; leaf frontier | **strengthened** | structure-owned hierarchical descent and explicit parent closure review under `FOC-010..013`, `FOC-039` | `SCN-FOC-004` |
| Inspecting a forecast does not consume the next draw | not explicit v0 guarantee | **strengthened** | `FOC-002`, `FOC-005` | inspect-then-draw replay |

## Skip, adaptation, and work

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| Every served skip records a typed reason and optional verbatim text | `I+T` | **strengthened** | symptom then reaction under `WRK-007..013`, `WRK-047`, `UX-S01` | one route per symptom family |
| `other` requires explanation and repeated evidence triggers taxonomy review | `I+T`, taxonomy tests | **strengthened** | `WRK-012`; never automatic vocabulary mutation | `SCN-WRK-004` |
| `vague` regresses lifecycle and may create a clarification meta-Brick | `I+T` | **retired** | phase/content/enabling work without stage regression; exact reactions `OPEN-SKIP-001` | vague reaction route |
| `not_priority`, `meh`, `kill`, and `alternatives` are symptoms | `I+T` | **replaced** | `less_important`, `fear`, and separate terminal/method actions under `WRK-008` | symptom screen review |
| Several WIPs can exist while one item has attention | partly `I+T`; v0 dangling-WIP notices | **strengthened** | `WRK-001..004` | WIP review and focus switch |
| Waiting on an external condition differs from a Brick dependency | `I+T` | **strengthened** | `WRK-009`, `MOD-050`, `FOC-024`, `FOC-034`, `WRK-050..054` | common obstacle classification plus request-to-Wait handoff and due-review simulation |

## Delegation, effects, time, and recurrence

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| Delegation draft, preview boundary, cancel-before-send, due nudge, approve/decline, and completed/refused/abandoned outcomes | `I+T`, delegation tests | **strengthened but incomplete** | follow-up policy, Nature scope, and observed handoff under `WRK-029..034`, `WRK-058`; final lifecycle in `OPEN-DEL-001` | `SCN-DEL-001` plus delivery/manual handoff and full effect routes |
| Delegated work does not consume human focus/WIP or remain human-executable | `I+T` | **strengthened** | `WRK-029`, `WRK-057`, `FOC-035` | delegation/focus/importance interleave with exact scope |
| Completion effects `write_back`, `notify`, and arbitrary `spawn` stop for approval | `I+T` | **replaced** | external preview retained by `PRD-009`; general effect families in `OPEN-EFF-001`; arbitrary spawn retired in favor of closed release rules | external-effect route |
| Every later answer resolves to an explicit absolute date | `O`; implemented nudge dates | **strengthened** | `UX-018`, `WRK-016` | later/date route |
| Recurrence and habits | not delivered v0 behavior | **new 1.0 capability, not a regression row** | `WRK-019..028`, `WRK-038..040` | `SCN-REP-001`, `SCN-PRC-001..002` |
| Scheduled commitments and operational day boundaries | not delivered v0 behavior | **new 1.0 capability, not a regression row** | `FOC-030..031`, `WRK-041..046` | flight/meeting/habit-day routes |

## Views, planning, history, and migration

| V0 capability | Evidence | 1.0 disposition | Canonical destination | Acceptance route |
|---|---|---|---|---|
| Tree, aligned table, CSV, Org, and self-contained HTML projections | `I+T`, `5eb485e`, `797466f` | **retained through boundary change** | standard Lua ReadOnlyExporters under `DAT-028..033` | exporter fixtures, including offline HTML |
| Compact one-line Brick rendering | `I+T`, `d688947` | **retained** | complete Brick citation under `MOD-010`; exact summary projection `OPEN-DAT-001` | list/show rendering |
| TaskJuggler export includes dependencies, order, estimates, and visible gaps | `I+T`, `49abaa5` | **strengthened** | planning cut, EffortProfile, immutable manifest, Lua exporter, separate actuals under `DAT-030..037` | planning-manifest replay |
| `show`, `ls`, `status`, grammar, and event audit support inspection | `I`; some view tests | **strengthened but incomplete** | sparse depth and filtered semantic history under `DAT-006..010`, `UX-023`, `UX-025..028`; exact grammar `OPEN-DAT-001` | inspection/history route |
| Event versions, upcasting, dry-run migration, and backup | `I+T`, `7a4dfab` | **strengthened but incomplete** | `MIG-001..017`; corrupt/unknown policy `OPEN-DAT-002` | migration failure/rollback route |
| Append-only JSONL can be synchronized by event-set union, archived by rotation, and queried through snapshots | `D`, README roadmap; not delivered | **not a v0 regression** | any 1.0 adoption requires a separate explicit decision | outside core-UX closure |

## Outstanding regression decisions

The rows marked unresolved, strengthened-but-incomplete, or
replaced-with-open-details define concrete specification work:

1. pending-question command escape and global palette behavior;
2. canonical executable name;
3. typed-handle edge normalization and technical-reference grammar;
4. complete merge and supersede transfer matrices;
5. hard temporary Domain scope and no-result recovery;
6. whether positive probability needs any bounded service guarantee;
7. complete skip symptom-to-reaction catalog;
8. focus/WIP public commands and standing-run closure;
9. Delegation lifecycle names and complete effect sequence;
10. general external write-back/notification boundary;
11. complete inspection/history projections and event corruption policy.

No item may disappear by deleting an old command or chapter. It must become a
canonical rule, a linked open decision with a closure scenario, or an explicit
retirement in this register.

## Promotion gate

Before Allium or code:

- every unresolved row has a settled disposition;
- every retained, strengthened, or replaced capability cites one canonical
  rule and one exact UX flow;
- deterministic cross-rule capabilities have a property or state-machine test
  obligation;
- an end-to-end regression scenario covers adaptive ordering, delegation,
  skip reaction, Raw/source reconciliation, sparse-versus-complete output,
  migration, first-start/empty state, and standard-Pack projections;
- generated-test inspection proves the intended behavior produced an
  executable obligation rather than only an informational declaration.

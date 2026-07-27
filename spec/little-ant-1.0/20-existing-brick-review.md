# 20. Existing Little Ant Brick review

The initial discovery session did not mutate Little Ant data. The deliberate
Brick-by-Brick review began on 2026-07-26: the `Little Ant 1.0` root was
created, and reviewed Bricks are now closed only after their useful ideas are
materialized in this record.

The agreed future process is:

1. review the current conceptual consolidation;
2. create a root/project Brick named `Little Ant 1.0`;
3. review every existing Little Ant-related Brick with the user;
4. ask which useful idea should be absorbed into the 1.0 design;
5. resolve blocking conceptual questions exposed by that review;
6. attach or recreate the accepted work under the 1.0 root;
7. only then mark the old Brick done, dropped, or superseded as appropriate;
8. produce the implementation and v0-to-1.0 migration plan.

## 20.1 Preliminary mapping, not final disposition

The following mapping preserves the initial repository/backlog inspection. It
is a hypothesis for the later question session, not authorization to mutate
the data.

Likely already absorbed by the 1.0 design:

| Brick | Preliminary interpretation |
|---|---|
| `4de709d` dates | Reviewed. `not_before`, `best_before`, and `deadline` affect eligibility and forecast without reordering priority. Threshold notices are deduplicated rather than repeated on every command. |
| `d9c18f8` impact | Impact is absorbed; old generic weight is removed. |
| `f2a62b8` placement | Absorbed by from-birth hierarchical placement. |
| `a232a74` break positions | Absorbed by local child ordering after break. |
| `5d41ad7` parent review | Reviewed. Finite parents receive `review_parent` rather than automatic completion; proposal strength follows coverage and child outcomes, collections become dormant, and ancestor review ascends explicitly one level at a time. |
| `82e789d` interrupted rounds | Reviewed. Confirmed answers persist as ordinary events; prompts are derived from current state; unconfirmed text stays in a surface checkpoint; no round or continuation Brick exists; and adaptive progress never invents an exact denominator. |
| `86e68cf` mention grammar | Reviewed. `@` and `#` are explicit Party and Brick autocomplete affordances, not global parsers. External tracking uses RawOrigin and RawLink rather than a public provider-scheme grammar. |
| `eabdce0` compare reason | Likely absorbed by evidence provenance and optional reason. |
| `be7f87c` forecast | Absorbed and expanded into the forecast projection. |
| `c16963b` done direct | Reviewed. `already done` is removed as distinct vocabulary: ordinary `done` works by reference and as a served action without synthetic start or false duration, and completion provenance retains its authority. |
| `dc01980` done any stage/raw | Reviewed. Any active Brick completes directly without fabricated intermediate transitions, subject to structural and behavior invariants. Raw has explicit review/archive operations and never auto-materializes into a Brick for `done`. |
| `c524be5` mutator JSON | Reviewed. The old full-Brick echo is replaced by a compact typed postcondition. Operational JSON is command-specific and sparse by schema, while complete entity and audit projections remain available explicitly. |
| `bf4265f` REPL | The REPL is now required for 1.0 as a deterministic guided harness; exact interaction details remain open. |
| `24ba73f` title normalization | Reviewed. Title-derived identity and destructive title normalization are removed. Verbatim input, a conservatively cleaned canonical English title, renderer-owned markers, and derived matching fingerprints have distinct roles. |
| `ede9f19` recurrence/habits | Reviewed. One durable identity applies only where executions form one honest history; obligations may need separate occurrence Bricks, event triggers release opportunities without rebirth, and supersession keeps histories separate with explicit reconciliation. |
| `e62a98a` consumable | Reviewed. No `consumable` axis is needed: a generic repeatable behavior retains one Brick and records executions; optional completion-triggered repetition assigns a deterministic jittered `not_before`. |
| `829fbae` artifacts | Reviewed and completed. The generic Artifact bag was rejected; description, RawOrigin, RawSnapshot, RawLink roles, and behavioral relationships now have explicit boundaries. |
| `1437d01` import TODOs | Reviewed. External capture and adoption are separate; configured task sources may atomically create or reconcile Raw and positioned work, while unknown, mixed, and notebook sources remain pending Raw. Source views, ImportProfiles, idempotency, note triage, and versioned extension packs define the provider-neutral 1.0 boundary. |
| `5205704` sync round | Reviewed. Replace one monolithic skill-owned sync round with provider-neutral core observations and reconciliation, Adapter-owned provider mechanics, explicit migration cutover, retired ImportProfiles, historical RawOrigins, and optional verified item-scoped source cleanup. External deletion never means completion. |

Likely obsolete or substantially superseded:

| Brick | Preliminary interpretation |
|---|---|
| `d1ad5f8` promote to commit rename | Both lifecycle operations disappear. |
| `2467144` stage unification/supersede seed | Old stages disappear; any useful supersede semantics need extraction. |
| `d58e0e3` readable Party slug | Reviewed. Party uses opaque immutable identity; mutable labels and optional overlapping alternate names support rendering and retrieval without becoming IDs or aliases. |
| `6db8938` grooming meta-Brick | Reviewed. Grooming becomes a manually invocable or forecast-derived `brick_review` interaction, never another Brick or mandatory checklist. |
| `dbf72a7` subset sort | Must be reconsidered under sibling-scoped hierarchical order. |
| `ed8176f` README rewrite | Reviewed and superseded by `39959b4`. Obsolete v0 feedback was separated from a clean English 1.0 documentation deliverable. |
| `6b212ab` skill checklist | Reviewed and superseded by `f278949`. The mixed v0 checklist was replaced by one thin English operator deliverable over the canonical interaction contract; channel rendering belongs to adapters. |

Still visibly open:

| Brick | Preliminary interpretation |
|---|---|
| `f7048ad` snooze | Needs separation from cooldown, wait, and `not_before`. |
| `2ca8d39` flow stop/pause/lighter/change subject | Flow and focus grammar remains open; old weight-based “lighter” is obsolete. |
| `355a9b7` status line | Reviewed. The core owns one typed StatusSummary and the compact default human rendering of `la status`; a separate `--line` flag is rejected. Operational and complete structured projections expose the same facts. Exact status fields and presence defaults remain open. |

## 20.2 Remaining inventory captured for later review

The following IDs and shorthand titles were observed and must be reviewed
individually. Shorthand titles are only navigation aids; the CLI remains the
authority for their full current data.

Committed at inspection time:

```text
09a47ce blobs
355a9b7 status line
6db8938 grooming
dc01980 done any stage
e62a98a consumable
```

Seeds at inspection time:

```text
829fbae artifacts: description/source/attachment
6b5261e Party null bug
75456d6 ready/wait bug
a232a74 break positions
b8b92b6 dropped blocker bug
d9c18f8 impact
4de709d dates
c16963b already done
c524be5 mutators echo updated Brick
2467144 unify/supersede seed
d1acce4 Party references/about
0741514 concurrent log
ff6fd63 mobile WASM
7b678e2 dependency remove
86e68cf mention grammar
d58e0e3 Party slug
1437d01 import TODOs
f2a62b8 placement
f4b333e Metro web
d1ad5f8 rename promote/commit
2ca8d39 flow
eabdce0 comparison reason
24ba73f title normalization
5d41ad7 parent done
ede9f19 recurrence/habits
ed8176f README rewrite
6b212ab skill review
5205704 sync round
82e789d interrupted rounds
18b7326 search/theme
f8e836d seven triggers
35bf548 archive
6a62628 metadata
dbf72a7 subset sort
be7f87c forecast
bf4265f REPL
f7048ad snooze
```

At the time of inspection there was no existing root named `Little Ant 1.0`.

## 20.3 Reviewed dispositions

| Date | Brick | Disposition | Materialized result |
|---|---|---|---|
| 2026-07-26 | `829fbae` artifacts | `done` | No generic Artifact. Raw has at most one external origin and immutable snapshots; RawLinks carry material roles and per-Brick reconciliation baselines; check, refresh, reconcile, and write-back remain distinct. |
| 2026-07-26 | `e62a98a` consumable | `done` | No `consumable` property. `repeatable` is a generic behavior with one durable Brick identity and priority position, execution history, optional completion-triggered repetition, and deterministic jittered `not_before`; independently outstanding obligations still materialize occurrence Bricks. |
| 2026-07-26 | `09a47ce` binary blobs | `done` | RawSnapshot bytes are content-addressed logical dataset members referenced from JSONL, synchronized by default, and integrity-checked. Missing bytes are explicit incomplete or corrupt state; Git and other concrete transports remain outside core semantics. |
| 2026-07-26 | `355a9b7` canonical status line | `done` | `la status` has one compact canonical default human rendering and one typed StatusSummary shared by CLI, REPL, powered-up mode, and skill. Sparse operational and explicit complete projections expose the same facts; no `--line` alias or operator-recomposed status exists. |
| 2026-07-26 | `6db8938` grooming meta-Brick | `done` | `brick_review` is a guided interaction over an existing Brick, invoked manually or proposed by forecast. It asks only materially applicable questions, records ordinary events, and creates real follow-up work only through explicit proposals. |
| 2026-07-26 | `dc01980` done from any stage and Raw | `done` | `done` directly terminates any active Brick without synthetic lifecycle history while preserving structural and behavior safeguards. Raw is not work, has no `done`, and is never converted automatically into a Brick. |
| 2026-07-27 | `c16963b` already done | `done` | No separate command, event, kind, or skip reason. Ordinary `done` is available by reference and when served, records no synthetic start or duration, applies normal behavior effects, and distinguishes human reports from externally proposed evidence. |
| 2026-07-27 | `24ba73f` title normalization | `done` | Identity is opaque and independent from title. Original input remains verbatim; canonical English receives only conservative Unicode and whitespace cleanup; system emoji stay in renderer metadata; intentional user emoji may remain; and stronger lexical normalization exists only in derived duplicate-matching fingerprints. |
| 2026-07-27 | `5d41ad7` parent completion review | `done` | Closing the last active child proposes `review_parent` only for a finite parent. Complete coverage plus successful outcomes favors `done`; open or mixed scope gets a neutral review. Empty collections become dormant, and confirmed completion exposes at most the next ancestor for separate review. |
| 2026-07-27 | `ede9f19` recurrence and habits | `done` | Standing identity, recurring obligations, repeatable work, practices, opportunity outcomes, derived streaks, blockers, introspection, deterministic schedules, and restricted event triggers are separated. Continuing intent updates one Brick; misleading historical continuity requires a separate successor and explicit reconciliation. |
| 2026-07-27 | `ed8176f` old README rewrite | `superseded` by `39959b4` | Location observations, typed text annotations, domain-data authority, progressive disclosure, core/operator/adapter ownership, and the corrected priority-versus-dependency example were absorbed into the 1.0 record. The English successor remains open after Allium revision and before coding. |
| 2026-07-27 | `6b212ab` old skill checklist | `superseded` by `f278949` | Valid ideas were reframed around a thin operator, the core interaction envelope, contextual skip operations, typed annotations, opaque identity, terse progressive disclosure, and adapter-owned channel rendering. The successor retains the interrupted-round and annotation reviews as blockers. |
| 2026-07-27 | `82e789d` interrupted rounds | `done` | Confirmed actions persist immediately; the core derives the next valid prompt from current state and retains replay data where needed; unconfirmed text remains presentation state; no continuation Brick exists; and progress is exact only when its denominator is genuinely known. |
| 2026-07-27 | `d58e0e3` readable Party slug | `done` | Curated Parties follow the same opaque identity rule as other persisted entities. Mutable labels and optional overlapping alternate names aid human rendering, search, and duplicate suspicion but never become identity, global aliases, or implicit references. |
| 2026-07-27 | `86e68cf` mention grammar | `done` | Party and Brick sigils are narrow editor affordances whose explicit selection creates typed annotations. Unselected sigil text and URIs remain literal; externally tracked material is modeled explicitly through RawOrigin and RawLink, with provider normalization confined to adapters. |
| 2026-07-27 | `4de709d` dates and deadline pressure | `done` | Three distinct dates remain: `not_before`, `best_before`, and `deadline`. Date pressure is derived and explained without reordering priority; threshold crossings create idempotent notices, while acknowledgment and snooze affect presentation only. |
| 2026-07-27 | `1437d01` external TODO import | `done` | Little Ant 1.0 includes a provider-neutral import framework. Stable Raw provenance is always retained; configured structured tasks may be adopted atomically into positioned work with provisional priority confidence, notes require triage, source groups remain derived views, and broader adapters, templates, behaviors, and enrichers may ship as permission-declared Little Ant Packs. |
| 2026-07-27 | `c524be5` mutator JSON response | `done` | Mutators return compact typed postconditions rather than booleans or complete Bricks. Sparse operational projections use schema-defined presence rules, preserve meaningful false/zero/empty/tri-state values, and leave complete entity and event output to explicit queries. |
| 2026-07-27 | `5205704` external reconciliation and migration | `done` | Active ImportProfiles may authorize visible read-only checks. Work state and presence remain independent; deletion never means completion. Migration uses explicit verification and cutover, retains historical provenance, and may request separately approved, item-scoped, resumable source cleanup before retiring the profile. |

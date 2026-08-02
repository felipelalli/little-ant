# Open release decisions

Only unresolved semantic, protocol, migration, or security boundaries live
here. Tuning values belong in
[`configuration-and-calibration.md`](configuration-and-calibration.md);
ordinary implementation choices wait for the implementation plan.

An `OPEN-*` item is not permission to guess. It names the exact boundary and
the UX or threat-model evidence required to close it.

## Core and dumb-REPL closure

These decisions close Gates 2 through 7 of the
[specification completion plan](spec-completion-plan.md).

| ID | Blocking decision | Closure evidence |
|---|---|---|
| `OPEN-MOD-002` | Exact accessible markers for `idea`, `exec`, and `validation`; `spec = 📐` is settled. | Canonical screen-catalog review. |
| `OPEN-MOD-003` | Final mode vocabulary/inheritance, direct versus inherited Domain membership, and inheritance of requester, `about`, or RawLinks. FED-030 settles the visible same-effective-Domain baseline for an enabling sibling but deliberately does not guess its persistent direct/inherited encoding. | Composition, multi-Domain, and physical-errand scenarios. |
| `OPEN-RAW-001` | Final Raw content kinds, RawLink roles and cardinalities, description replacement/revision behavior, Raw-to-Raw derivation, RawShelf membership, optional Domain classification, and whether permanent deletion ever exists. The settled baseline is that Brick descriptions are Raw. | Description edit, reusable note, attached file, shelf, and multi-Domain content scenarios. |
| `OPEN-RAW-002` | Exact same-Raw English-normalization schema and `/translate` flow: attribution, versioning, staleness after original edits, preview/approval, active versus archived scope, non-text material, and search preference. Translation itself must not create another Raw. | Dumb and powered-up normalization of Brick descriptions, titles, URLs, imported notes, and binary attachments. |
| `OPEN-TREE-001` | Exact batch close, move, drop, and supersede behavior when subtrees contain dependencies, waits, delegations, or cross-boundary relationships. | Project closure and migration simulations. |
| `OPEN-MERGE-001` | Complete relationship-transfer matrices for `merge` and `supersede`: parent/children, sibling position and evidence, Domains, RawLinks, waits, dates, recurrence, delegation, effects, annotations, occurrence history, and external provenance. | Finite, standing, delegated, externally linked, and conflicting merge/supersede simulations. |
| `OPEN-LST-001` | Complete ListEntry model: open/resolved/cancelled outcomes, quantity, carry-over across runs, unlisted discoveries, duplicate suspicion within and across runs, and what `done` means on each checklist Nature. | Grocery, trip, one-time checklist, partial run, and unlisted-item simulations. |
| `OPEN-IMP-001` | Final ordering-skip assistance screen and the visible route to `tie-break for me`. | Binary-insertion simulation with repeated uncertainty. |
| `OPEN-JUD-001` | Exact impact-assistance grammar, no-basis default, maturity promotion/demotion evidence, and effort-confidence presentation. | Judgment scenarios using product research and historical exemplars. |
| `OPEN-FOC-001` | Semantic granularity is settled by `FOC-009`: distinct action/transition families require discriminated variants; an identical family may use typed `purpose`; signals, warnings, and context are not opportunities; and screen grammar is orthogonal. Every ordinary-lottery variant visibly supports typed skip under `FOC-026`; continuations, recovery, and hard precedence are excluded. Remaining work: the exhaustive versioned 1.0 variant names, required payloads, purposes, remaining actions, and transitions. | Coverage matrix across the synthetic week and v0 regression audit, including rejection of hybrid payloads, accidental signal-as-opportunity tickets, missing lottery skip, and misleading skip on hard precedence. |
| `OPEN-FOC-002` | Tie handling when accepted work has several equally specific descendant Domain memberships, and the exact ordering of container descent versus dependency resolution. | Multi-Domain and N-step blocker simulations. |
| `OPEN-FOC-003` | Whether positive probability plus aging is sufficient anti-starvation, or whether any admitted opportunity also needs a bounded service guarantee compatible with weighted replay. | Long fixed-stream sweeps containing very-low-chance work and changing eligibility. |
| `OPEN-DOM-001` | Exact UX and state for a temporary hard Domain scope, explicitly ignoring continuity, and recovering when the selected scope has no actionable endpoint. | Same-Domain, cross-Domain, descendant-scope, and empty-scope simulations. |
| `OPEN-DOM-002` | Domain lifecycle and taxonomy boundaries: create, rename, move, merge, archive, multiple taxonomies, direct versus inherited membership, explicit exclusion, recursive queries, and ambiguous references. | Personal/organizational overlap, subtree move, rename, merge, exclusion, and recursive-count simulations. |
| `OPEN-SKIP-001` | Complete symptom-to-reaction catalog, including Nature-sensitive applicability, bounded `vague` clarification, recovery versus deferral, Domain scope, and exact reaction grammar. | One dumb-REPL simulation for every served-work symptom, then powered-up and Skill parity review. |
| `OPEN-WAIT-001` | `review_not_before`, weighted eligibility after opening, no due/overdue semantics, the human-response dumb choices and three-day factory suggestion, bounded history/assistance, early source proposal, request handoff, outcome families, and typed review skip are settled by `FOC-034` and `WRK-050..055`. Remaining work: exact custom date/time selector, pressure curve and evidence threshold, non-response escalation cap, source-resolution confirmation, and follow-up cadence. | Short/long human response, custom instant, source-observed response, repeated no-response, skip-versus-wait-longer, follow-up, reclassification, and resolution simulations. |
| `OPEN-WRK-001` | Final public commands for resuming focus, WIP-to-idle, standing-run finish, and retiring standing work. Transactional `/next` browsing, non-state `/pause`, and immediate reversible focused completion are settled by `FOC-033`, `WRK-048..049`, and `UX-066..069`. | Focus, interruption, checklist, and repeatable-work screens. |
| `OPEN-WRK-002` | Canonical English name for an explicitly or deterministically unfulfilled habit opportunity. | Habit and streak simulation; do not reuse generic `abandon`. |
| `OPEN-TIME-001` | Exact notice action grammar, acknowledgment/snooze behavior, and safe-boundary surfacing. | Deadline, best-before, and recurring-obligation simulation. |
| `OPEN-SCH-001` | Final `scheduled_commitment` required interval data, action grammar and attended/missed/cancelled outcomes, conflicts with current focus or overlap, active hard-prerequisite presentation, and delegation scope. Active commitment precedence is settled. | Flight, appointment, meeting, service-window, overlap, and time-zone-crossing simulations. |
| `OPEN-SCH-002` | Relative-preparation behavior when the commitment anchor moves: pending versus completed children, explicit overrides, newly overdue work, and preview requirement. | Reschedule a flight and meeting before and after preparation begins. |
| `OPEN-UX-001` | Remaining shortcut collisions after settling ordinary `[n]ext`, natural `[n]o` only for unavoidable binary propositions, importance `[m]ore/[l]ess`, `[b]locked or waiting`, `bo[r]ed`, served-work `[l]ess important`, and `[d]one`; choice/input layouts, contextual-assistance labels, the exact monochrome selection marker and no-emoji rendering, and the exact English copy for all four settled 16-entry personality catalogs. `Work:`, `Current focus:`, and `Done:` are settled work-flow headings; `Next:` is not a visible opportunity heading; comparisons begin directly with their natural proposition and have no type heading; every ordinary-lottery screen exposes typed `[s]kip`, while hard precedence does not. ANSI capability detection, theme-owned colors, reverse-video selection, and display-cell alignment are settled by `UX-070..073`. | Almost-literal REPL/web/Skill screen and factory-copy review. |
| `OPEN-UX-002` | Final InteractionEnvelope identity, revision, stale-response/rebase fields, progress fields, and checkpoint conflict grammar. | Crash, concurrent update, undo/redo, and cross-surface scenarios. |
| `OPEN-UX-003` | Which remaining non-input grammars expose `[/] more...`, plus exact recovery for empty searches, unavailable commands, ambiguous selection, and guided arguments. Focus and served-work symptom/result screens already expose it; Focus suspends its pending interaction and revalidates it after mutation under `UX-022`, `UX-047`, and `UX-M01`. Compound command identifiers are already settled as one kebab-case token by `UX-074`. | Comparison, confirmation, choice, nested assistance, empty-search, unavailable-command, and guided-argument simulations. |
| `OPEN-CLI-001` | One canonical executable name for 1.0 (`la` or `lant`) and whether the other is retired or justified strictly as a packaging shim without becoming a core alias. | README/installation and shell-collision review. |
| `OPEN-REF-001` | UUIDv7 internal identity, UUID-backed relationships, mnemonic Brick `#` handles, ExternalEntity `@` handles, collision suffixes from `2`, non-reuse, rename stability, no aliases, typed autocomplete, and deterministic cross-dataset remapping are settled by `MOD-008..012` and `UX-075..076`. Remaining work: exact handle normalization for single-word, non-Latin, empty, and punctuation-only names; explicit human references for Raw and other technical records; pasted-reference/action-token precedence; and exact recovery screens. | Single-word/non-Latin names, repeated-title and handle collisions, title and explicit-handle renames, retired handles, Raw/technical references, merge identity conflicts, and cross-surface autocomplete simulations. |
| `OPEN-DAT-001` | Final projection names, schema-version negotiation, complete-projection request, history filters, and meaningful-zero declarations. | Operator-context and sparse-response fixtures. |
| `OPEN-DAT-002` | Authoritative-log behavior for malformed records, unknown event versions, missing-entity references, and partial corruption: fail, quarantine, or explicit degraded mode, with no silent evidence loss. | Corrupt-log, unknown-version, repair, backup, and migration rollback fixtures. |

## External and standard 1.0 closure

These decisions close Gate 8. A standard item may be explicitly deferred out
of 1.0 at Gate 12, but it may not remain half-specified while the README claims
it.

| ID | Blocking decision | Closure evidence |
|---|---|---|
| `OPEN-MOD-001` | Final `ContactPoint` model and boundary between synchronized ExternalEntity details and local credential/delivery bindings. | Delegation and waiting scenario plus credential threat review. |
| `OPEN-RAW-003` | Final external-origin/check policy fields, immutable snapshot repair, source relocation, reconciliation baseline, and missing or corrupt source behavior. | Raw URL, imported note, relocation, access-loss, and offline-source scenarios. |
| `OPEN-DEL-001` | Confirmation semantics are settled by `WRK-056`: `yes` approves the exact effect, `no` rejects only that effect instance, `later` changes its review instant, and lottery `skip` preserves effect and instant while deferring the opportunity. UX-077 and UX-A01/A02 settle explicit edit, selected prefill, simple `Suggested message:`/`Message:` labels, hidden technical identifiers, and inspectable attribution. FOC-035 and WRK-057 settle that an active Delegation suppresses human execution only for its resolved scope while preserving Importance and typed follow-up opportunities. Remaining work: the exact transition that makes a Delegation active; final factory message catalog; draft ownership and persistence across surfaces; final lifecycle names; and the complete sequence for initial notice, cancellation-before-send, due follow-up, reported completion, refusal, and terminal give-up. | One `once`, `every`, and explicitly-`none` Delegation, including pre-activation eligibility, exact-scope suppression, dumb-factory, model-proposed, selected-prefill editing, rejected, failed-delivery, recovery, and Nature-aware-scope paths. |
| `OPEN-EFF-001` | Closed 1.0 external-effect families and authority model, especially general write-back and notification after arbitrary completion-time `spawn` is retired. | Completion, reconciliation, Calendar write-back, delegation delivery, failure, retry, and compensation scenarios. |
| `OPEN-PREF-001` | Canonical boundary and location for user preferences, wrapper presentation language, integrations/bindings, calibration profiles, and local secret bindings; these must not collapse into one untyped manifest. | Dumb REPL, Skill, powered-up, Pack, and multi-profile configuration review. |
| `OPEN-EXT-001` | Vault format, KDF/cipher, recovery, rotation, memory-agent IPC, and locked-state security. | Dedicated security design before credentialed adapters ship. |
| `OPEN-EXT-002` | Which listed importers, including required official Google Calendar support, and UIAdapters ship in the offline standard Pack versus a pinned official companion catalog. | API feasibility and release-packaging review; all listed sources remain supported 1.0 targets until explicitly deferred. |
| `OPEN-CAL-001` | Google Calendar write-back authority and approval grammar; series versus occurrence adoption; all-day routing; cancellation reconciliation; and calendar/attendee privacy projections. Observation and reconciliation are already required. | Flight, meeting, recurring swimming, all-day, reschedule, cancellation, and access-loss simulations against a fake provider. |
| `OPEN-PACK-001` | Pack signing, trust roots, revocation, dependency policy, update review, and reproducible archive format. | Supply-chain threat review and TaskJuggler reference Pack. |

## Migration and freeze

| ID | Blocking decision | Closure evidence |
|---|---|---|
| `OPEN-MIG-001` | User-confirmed mapping for every legacy `area`, ambiguous `kind`, legacy Party detail, and unsupported v0 relation. | Real v0 migration dry-run report. |

## Deliberately not release blockers

These do not justify inventing more core behavior before simulation:

- exact forecast curve coefficients and cooldown lengths;
- exact screen region sizes, colors, terminal library, or web framework;
- whether a particular personal Template is popular;
- automatic semantic causality for skip patterns;
- arbitrary generic plugins or custom event hooks;
- cross-device draft synchronization;
- a global world-object catalog;
- alternative storage or selection engines;
- points, leaderboards, or punitive habit scoring.

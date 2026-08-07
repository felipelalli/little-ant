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
| `OPEN-TREE-001` | Exact batch close, move, archive, and supersede behavior when subtrees contain dependencies, waits, delegations, or cross-boundary relationships; and whether archived or superseded children satisfy the all-children-finished boundary that releases parent scope review. Done children are already settled to release review without cascading parent completion. | Project closure and migration simulations. |
| `OPEN-MERGE-001` | Complete relationship-transfer matrices for `merge` and `supersede`: parent/children, sibling position and evidence, Domains, RawLinks, waits, dates, recurrence, delegation, effects, annotations, occurrence history, and external provenance. | Finite, standing, delegated, externally linked, and conflicting merge/supersede simulations. |
| `OPEN-JUD-001` | Exact impact-assistance grammar, no-basis default, maturity promotion/demotion evidence, and general effort-confidence presentation. IMP-038 settles one narrow source: an accepted tired-recovery shortlist choice supplies weak relative effort evidence without assigning hours or a class. | Judgment scenarios using product research and historical exemplars. |
| `OPEN-WAIT-001` | `review_not_before`, weighted eligibility after opening, no due/overdue semantics, the human-response dumb choices and three-day factory suggestion, bounded history/assistance, early source proposal, request handoff, outcome families, typed review skip, and the shared custom date/time selector are settled by `FOC-034`, `WRK-050..055`, `WRK-127`, and UX-DT00..DT02. MOD-051 and WRK-059 settle that Delegation activation never creates an implicit Wait; a later independent gate must be explicit and keeps separate history. Remaining work: pressure curve and evidence threshold, non-response escalation cap, source-resolution confirmation, and follow-up cadence. | Short/long human response, custom instant, source-observed response, repeated no-response, skip-versus-wait-longer, explicit Delegation-plus-Wait, follow-up, reclassification, and resolution simulations. |
| `OPEN-WRK-001` | Final public commands for resuming focus, WIP-to-idle, standing-run finish, and retiring standing work. Transactional `/next` browsing, non-state `/pause`, and immediate reversible focused completion are settled by `FOC-033`, `WRK-048..049`, and `UX-066..069`. | Focus, interruption, checklist, and repeatable-work screens. |
| `OPEN-WRK-002` | Canonical English name for an explicitly or deterministically unfulfilled habit opportunity. | Habit and streak simulation; do not reuse generic `abandon`. |
| `OPEN-TIME-001` | Exact notice action grammar, acknowledgment/snooze behavior, and safe-boundary surfacing. | Deadline, best-before, and recurring-obligation simulation. |
| `OPEN-SCH-001` | Final `scheduled_commitment` required interval data, action grammar and attended/missed/cancelled outcomes, conflicts with current focus or overlap, active hard-prerequisite presentation, and delegation scope. Active commitment precedence is settled. | Flight, appointment, meeting, service-window, overlap, and time-zone-crossing simulations. |
| `OPEN-SCH-002` | Relative-preparation behavior when the commitment anchor moves: pending versus completed children, explicit overrides, newly overdue work, and preview requirement. MOD-047 and MOD-062 settle that preparation children are ordinary maintainable Bricks, never replace the commitment focus unit, and receive no relative-time anchor merely because they were added manually. | Reschedule a flight and meeting before and after preparation begins; add one unanchored preparation Brick manually. |
| `OPEN-UX-001` | Remaining shortcut collisions after settling ordinary `[n]ext`, natural `[n]o` only for unavoidable binary propositions, importance `[m]ore/[l]ess`, `[b]locked or waiting`, `bo[r]ed`, served-work `[l]ess important`, and `[d]one`; choice/input layouts, contextual-assistance labels, the exact monochrome selection marker and no-emoji rendering, and the exact English copy for all four settled 16-entry personality catalogs. `Work:`, `Current focus:`, and `Done:` are settled work-flow headings; `Next:` is not a visible opportunity heading; comparisons begin directly with their natural proposition and have no type heading; every ordinary-lottery screen exposes typed `[s]kip`, while hard precedence does not. ANSI capability detection, theme-owned colors, reverse-video selection, and display-cell alignment are settled by `UX-070..073`. | Almost-literal REPL/web/Skill screen and factory-copy review. |

## External and standard 1.0 closure

These decisions close Gate 8. A standard item may be explicitly deferred out
of 1.0 at Gate 12, but it may not remain half-specified while the README claims
it.

| ID | Blocking decision | Closure evidence |
|---|---|---|
| `OPEN-MOD-001` | Final `ContactPoint` model and boundary between synchronized ExternalEntity details and local credential/delivery bindings. | Delegation and waiting scenario plus credential threat review. |
| `OPEN-EFF-001` | Closed 1.0 external-effect families and authority model, especially general write-back and notification after arbitrary completion-time `spawn` is retired. Delegation now requires the named `delegation_delivery` and optional `delegation_take_back_notice` purposes under WRK-120, but their adapter protocol, failure/retry envelope, and place in the complete closed catalog remain here. | Completion, reconciliation, Calendar write-back, delegation delivery, failure, retry, and compensation scenarios. |
| `OPEN-PREF-001` | Canonical boundary and location for user preferences, wrapper presentation language, integrations/bindings, calibration profiles, and local secret bindings; these must not collapse into one untyped manifest. UX-162 settles external-editor argv meaning and environment fallback as a presentation preference, but not the eventual preference-file location. | Dumb REPL, Skill, powered-up, Pack, and multi-profile configuration review. |
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

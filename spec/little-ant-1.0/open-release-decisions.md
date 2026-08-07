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

No core or dumb-REPL interaction boundary remains open. New uncertainty found
during the final contradiction audit must receive a new ID rather than being
hidden in prose.

## External and standard 1.0 closure

These decisions close Gate 8. A standard item may be explicitly deferred out
of 1.0 at Gate 12, but it may not remain half-specified while the README claims
it.

| ID | Blocking decision | Closure evidence |
|---|---|---|
| `OPEN-EFF-001` | Closed 1.0 external-effect families and authority model, especially general write-back and notification after arbitrary completion-time `spawn` is retired. Delegation now requires the named `delegation_delivery` and optional `delegation_take_back_notice` purposes under WRK-120, but their adapter protocol, failure/retry envelope, and place in the complete closed catalog remain here. | Completion, reconciliation, Calendar write-back, delegation delivery, failure, retry, and compensation scenarios. |
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

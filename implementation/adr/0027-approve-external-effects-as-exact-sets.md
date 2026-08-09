# ADR 0027: Approve external effects as exact finite sets

## Status

Accepted.

## Context

The first executable ExternalEffect aggregate was shaped around Delegation:
its fields assumed one ExternalEntity target, an optional ContactPoint, and a
message. That shape could not represent source cleanup or Calendar effects
without adding unrelated optional fields, and its single-effect approval did
not preserve the exact bounded-set consent required by DAT-069..073.

The old `revision` also advanced for ordinary state transitions. That made a
payload revision indistinguishable from the record version even though consent
must remain attached to one immutable payload revision.

## Decision

ExternalEffect has one closed typed request sum. Delegation delivery and
take-back notices remain explicit variants; source item and container cleanup
use signed adapter custody plus exact typed targets. The purpose is derived
from that request rather than stored as a second independently mutable fact.
Calendar purposes remain in the closed purpose catalog and will gain their
typed requests with the Calendar milestone.

Payload `revision` and aggregate `record_version` are separate. Editing the
request creates a new payload revision and clears consent. Approval, dispatch,
receipt, defer, reject, and withdrawal only advance the record version.

Approval is one durable `ExternalEffectApprovalGrant` event containing a
sorted, nonempty, duplicate-free list of `(effect UUID, payload revision,
consent digest)`. Replay validates every member against a currently proposed
effect before atomically marking the whole finite set approved. Every effect
retains its grant UUID and exact digest; approval cannot move between effects
or revisions.

The lifecycle vocabulary is the specification's closed catalog:
`proposed`, `approved`, `dispatching`, `succeeded`, `failed_retryable`,
`failed_terminal`, `outcome_unknown`, `rejected`, and `withdrawn`. Retryable
effects may reuse consent only when an unchanged idempotency key is recorded.
An unknown outcome still requires explicit duplicate-risk consent and a new
payload revision.

## Consequences

- Source cleanup and Calendar can share one effect protocol without a second
  effect subsystem or optional-field soup.
- One-item approvals are ordinary one-member grants; batches do not require a
  separate mutable batch lifecycle.
- Durable dispatch intent can be recorded against the same exact consent
  digest before any provider I/O.
- The event schema intentionally changes in V1; no V0 compatibility alias or
  dual parser is retained.
- S08 tests exercise exact-set approval, payload/record version separation,
  dispatch-before-receipt, and unknown-outcome recovery.

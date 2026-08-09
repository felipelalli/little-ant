# ADR 0028: Reconcile source cleanup before retry

## Status

Accepted.

## Context

An accepted migration preserves provider objects locally before cleanup can
be proposed. Cleanup is still destructive external IO: a process can stop
after recording its intent, a provider can accept DELETE while its response is
lost, and authority can drift between preview and dispatch. Treating any of
those states as an ordinary retry can delete the wrong object or repeat an
effect whose outcome is already true.

DAT-043 and DAT-068..079 require exact finite approval, durable itemwise
progress, conservative unknown-outcome handling, and retention of the local
Raw regardless of provider cleanup. They also require the ImportProfile to
remain active until every selected object has a terminal cleanup disposition.

## Decision

Source item cleanup uses the shared ExternalEffect lifecycle and never calls a
provider from forecast or replay. The accepted ImportInvocation is converted
to one immutable effect per selected source object. One approval grant names
the exact sorted set of effect UUIDs, payload revisions, and consent digests.

Before every DELETE, the host re-resolves and compares the exact signed Pack
component, provider account, credential binding, ImportInvocation custody, and
source target. It records `dispatching` durably before provider IO and records
one closed receipt afterward.

Recovery is state-specific:

- approved items remain pending and can resume without touching succeeded
  siblings;
- an interrupted `dispatching` item first becomes `outcome_unknown`;
- an unknown item is reconciled by a read-only provider request;
- confirmed absence becomes `succeeded`, confirmed presence becomes
  `failed_retryable`, and an inconclusive check remains `outcome_unknown`;
- an unchanged idempotent retryable item may reuse its existing approval;
- retrying an unknowable outcome requires explicit duplicate-risk consent,
  creates a new proposed payload revision, and then passes through ordinary
  exact-set approval again;
- stopping recovery withdraws the unknown item rather than inventing provider
  truth.

The ImportProfile is retired only after every selected item effect is
`succeeded`, `failed_terminal`, `rejected`, or `withdrawn`. Source-container
deletion is not inferred from item completion and will use a separate preview
and approval. No cleanup transition deletes or rewrites the imported local
Raw.

## Consequences

- Restart and partial-failure recovery are replayable and do not blindly
  repeat provider mutations.
- One failed item cannot cause already successful siblings to be dispatched
  again.
- Authority drift fails closed before provider IO.
- Provider truth and local custody remain distinct: cleanup can fail or stop
  while the imported material remains usable.
- The official Microsoft To Do Pack exposes a read-only item-verification
  operation in addition to its cleanup operation; both remain constrained by
  the same signed brokered HTTP authority.
- Cleanup of source containers and other providers remains a later milestone,
  not an implicit generalization of this item protocol.

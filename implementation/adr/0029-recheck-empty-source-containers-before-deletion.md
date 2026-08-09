# ADR 0029: Recheck empty source containers before deletion

## Status

Accepted.

## Context

After a migration has preserved every selected object locally and item cleanup
has reached terminal success, the source container may itself be empty. Deleting
that container is a different destructive decision from deleting its imported
items. An earlier empty observation is insufficient because another client can
add an item before the deletion request, and Microsoft Graph does not provide a
conditional list-deletion contract that can atomically assert continued
emptiness.

DAT-043 and DAT-068..079 require cleanup to retain exact source custody,
separate consent, durable dispatch intent, conservative recovery, and all local
Raw material. The product must not turn successful item cleanup into implicit
container deletion.

## Decision

Source-container cleanup is a distinct ExternalEffect phase with no default
action. A container becomes eligible only when:

- it belongs to the exact accepted migration invocation and signed adapter
  custody;
- every selected item-cleanup effect in that container succeeded;
- the ImportProfile is already retired; and
- no live cleanup effect for that container exists.

Before proposing deletion, the host invokes a read-only Pack inspection and
records its canonical digest and observation time. Absent, nonempty, protected,
shared, or non-owned containers do not produce an effect. An empty owned custom
container receives its own immutable proposal and exact human approval.

The approved Pack operation repeats the complete paginated emptiness and
ownership inspection immediately before DELETE. Any newly observed item or
authority drift fails terminally without deletion. The host records durable
dispatch intent before invoking the Pack. If the DELETE response is lost, the
effect becomes `outcome_unknown`; recovery checks container existence read-only
and never blindly repeats DELETE. Local Raw material is never removed.

This protocol narrows but cannot eliminate the provider's final time-of-check /
time-of-use race. That limitation remains explicit because the provider offers
no atomic conditional delete for this resource.

## Consequences

- Item cleanup and container cleanup have separate previews, approvals,
  dispatch records, receipts, and recovery paths.
- A container that gains an item between preview and dispatch is preserved.
- Built-in, shared, and non-owned Microsoft To Do lists are never deletion
  candidates.
- A lost successful deletion is reconciled without a second destructive call.
- The official connector Pack owns provider-specific inspection semantics;
  core owns eligibility, custody, consent, durable effects, and replay.

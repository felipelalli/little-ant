# ADR 0037: Separate Pack removal from global archive collection

Status: accepted for S09

## Context

A Pack release can stop being preferred for new configuration while its exact
signed archive still gives meaning or authority to existing state. A live
ProviderAccount may deliberately remain pinned to that release, accepted import
manifests retain it for reproducibility, and a nonterminal external effect must
keep the authority reviewed at approval time. Deleting the archive as part of
"remove" would therefore make a simple profile preference change destructive
and ambiguous.

Archive collection has a different scope. The content-addressed store is shared
by every local profile, so looking only at the selected profile can delete bytes
still needed elsewhere. Collection also needs exact byte custody and a stable
snapshot rather than a best-effort directory sweep.

## Decision

`lant packs remove <pack>` and `lant packs gc` are two separate, no-default
binary consents.

Removal changes only the selected profile's preferred pin. Its preview lists
all references to the exact artifact and classifies each one as either retained
or requiring resolution. An exact ProviderAccount remains usable and retains
the old archive. Accepted ImportInvocation manifests remain reproducible and
also retain it. An active source without matching exact provider authority, a
component-only delivery binding, or a nonterminal effect blocks removal until
its owning flow pauses, detaches, rebinds, rejects, withdraws, or finishes it.
Version 1 has no force-removal route and performs no implicit recovery action.

Garbage collection scans the authenticated content-addressed store and every
local profile. Its retained set is the union of preferred pins, exact
ProviderAccount pins, all accepted ImportInvocation archive digests, and
nonterminal external-effect custody. The preview identifies each candidate by
exact artifact, signer fingerprint, path, and byte count, and records every
profile revision and dataset cursor.

Acceptance acquires one store-wide lock, reloads every profile and dataset,
reauthenticates every candidate archive, and rebuilds the complete plan. Any
profile, dataset, archive-identity, or byte-count drift returns a fresh
unapproved preview or fails closed. Only the exact unchanged candidates are
unlinked. Collection never edits profile configuration, canonical events,
Raw material, history, trust, or provider credentials, and it never runs
automatically. A partially interrupted unlink pass is safe to rerun because
the retained set and remaining authenticated candidates are recomputed.

Install and update publish the candidate and change the preferred pin while
holding the same store-wide lock, so garbage collection cannot race the
publication-to-pin boundary. Dry-run performs the complete validation without
persisting consent or deleting bytes.

## Consequences

- "Remove" remains a reversible preference change instead of a storage
  deletion.
- Exact old integrations and accepted provenance continue to work after the
  preferred release changes or disappears.
- Disk reclamation is explicit, global, inspectable, and safe across profiles.
- Ambiguous bindings must first gain exact custody or be resolved in their own
  lifecycle; the Pack manager does not invent those decisions.
- Unreferenced archives left by a lost installation/update race are harmless
  and become candidates for a later reviewed collection.

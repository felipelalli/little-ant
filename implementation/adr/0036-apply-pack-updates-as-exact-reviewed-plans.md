# ADR 0036: Apply Pack updates as exact reviewed plans

Status: accepted for S09

## Context

A Pack update changes the preferred release used for new configuration, but
live integrations may still depend on the exact installed artifact. Version,
component ID, credential-slot name, and configuration-schema filename are not
enough to prove that a live binding can move safely. OAuth consent is bound to
the old artifact, pending effects carry old signed custody, and a schema file
can change while retaining its path.

The update screen must remain one understandable binary consent. It cannot hide
an automatic migration behind installation, nor make the human approve a plan
that is recomputed differently at application time.

## Decision

`lant packs update <pack>` resolves the newest release in the already accepted
official catalog and downloads its exact digest. `lant packs update
<archive.lantpack>` admits a locally supplied candidate from an already trusted
community publisher. Both paths authenticate the archive before creating the
same persisted `binary_consent` Opportunity.

The update draft contains exact source custody, installed and candidate
artifacts, signer/trust, enabled components, profile revision, a semantic
manifest difference, and one disposition for every affected live binding:

- `rebind` moves the binding to the candidate pin;
- `keep_installed` retains the old exact pin and archive;
- `unavailable` identifies a binding kind that cannot yet represent either
  outcome safely and makes the displayed plan inapplicable.

The semantic difference compares component presence, kind, contract major,
configuration-schema path and content digest, component payload digest,
credential slots, OAuth authority, exact HTTP routes, effect permissions,
projections, and host capabilities. The summary stays bounded; the inspect
action exposes the complete stored change records.

A ProviderAccount may be proposed for automatic rebinding only when its
component still has the same contract major and configuration-schema content,
all credential bindings are non-OAuth and retain the same slot and scheme, and
no nonterminal external effect carries that account's old Pack custody. OAuth,
schema/contract drift, removed credentials, removed components, and pending
effects keep the account on the installed release with a visible reason.

Before acceptance, the host reopens and authenticates the exact candidate,
reinspects the preferred old archive, rereads the profile, and regenerates the
complete difference and binding plan. Any byte, profile, authority, or plan
drift produces a new unapproved preview or fails closed. A successful update
publishes the immutable candidate first, then compare-and-swaps the preferred
pin and only the displayed `rebind` accounts in one profile write. A lost race
leaves at most an unreferenced content-addressed archive. No canonical Work
event is emitted.

`keep current` changes no pin or binding. Dry-run persists neither the preview
nor the candidate and applies no profile change. Existing accepted results,
Nature snapshots, import provenance, and old archives remain untouched.

## Consequences

- Update approval is tied to one inspectable plan rather than to a version
  label.
- Compatible static integrations can move without forcing unrelated OAuth
  reconnection.
- OAuth accounts remain usable on their old artifact until an explicit
  reconnect establishes candidate-bound authorization.
- Pending effects keep the exact authority they were approved against.
- Delivery and UI bindings must gain exact-pin state before an affected update
  can be applied; they cannot float silently with the preferred component.

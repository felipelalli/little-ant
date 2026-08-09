# ADR 0008: Replay accepted official-catalog history

## Status

Accepted for S09.

## Context

An official catalog is useful only if a refresh cannot roll its sequence back,
forget an earlier revocation, or substitute a locally asserted signing root.
Persisting only the latest derived trust policy would discard the signed
evidence needed to reconstruct those decisions. Root rotation also has to
survive an application upgrade whose compiled root is the replacement rather
than the original key.

## Decision

Each profile stores one atomically replaced, private, closed state document
whose ordered history retains the exact JCS catalog or root-transition bytes
and their detached proofs. Loading starts from a compiled root that must occur
in the contiguous dual-signed root chain, then replays every entry in order.
Catalog signatures must name the root active at that point and catalog
sequences must strictly increase.

Root-transition documents carry both public keys and fingerprints and advance
one generation. Their detached proof contains signatures by both keys over the
same transition bytes. This allows either side of a legitimate transition to
serve as a compiled trust anchor while preserving the event order that prevents
a retired root from signing a later catalog.

The current catalog supplies installable releases and expiry. Effective key
and archive revocations are the monotonic union of every verified accepted
catalog. Refresh and root rotation serialize through one profile lock; a
candidate is fully verified before the state file is durably replaced.

## Consequences

- catalog expiry blocks refresh/install authority without invalidating an
  already accepted non-revoked pin;
- a later catalog cannot erase an earlier known revocation by omission;
- exact signatures, monotonic sequence, root generation, and file privacy are
  rechecked after every cold load;
- catalog history grows with explicit refreshes, which are expected to be rare
  and remain bounded by the state reader;
- filesystem rollback by the profile owner remains outside the threat model,
  but normal concurrent commands cannot publish a stale state over a newer one.

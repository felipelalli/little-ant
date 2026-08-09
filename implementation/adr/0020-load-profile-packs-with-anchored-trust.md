# ADR 0020 — Load profile Packs with anchored trust

Status: accepted for S09

## Context

The content-addressed Pack store, typed profile pins, signed catalog history,
and execution registry already existed as separate boundaries. Production,
however, loaded only the exact built-in standard Pack and ignored every
configured pin. Joining those pieces exposes one important distinction:
offline official execution has accepted-but-expired catalog evidence, while a
build with no compiled official root has no official authority at all.

Treating an absent catalog as an empty catalog would let
`PinVerifiedOfficial` become its own trust root. Re-authenticating the archive
would prove only that its named key signed those bytes, not that the key or
release was ever delegated by Little Ant. It would also turn absence of the
revocation channel into an implicit statement that nothing is revoked.

## Decision

The production registry loader combines one execution authorization for the
exact built-in standard Pack with every PackPin in the selected profile's
`integrations.yaml`. Configured pins are loaded in Pack-name order from the
global content-addressed store. Each archive independently rechecks its private
regular-file custody, digest-named path, canonical structure, Ed25519
signature, exact pin identity, enabled components, selected profile, current
trust, and known revocations. The final registry is built once; any missing,
unsafe, invalid, untrusted, revoked, or colliding configured Pack fails the
whole startup instead of silently removing behavior.

Official catalog authority is an explicit host input with two states:

- `compiled root`: replay the selected profile's exact accepted catalog
  history and derive official grants, historical pin authorizations, and the
  monotonic known-revocation union;
- `unavailable`: accept built-in and explicitly trusted-community pins only.
  An official pin or even an existing official-catalog state file fails
  explicitly because this build cannot authenticate it.

Every accepted catalog contributes immutable historical pin authorizations
containing its sequence, exact artifact identity, and delegated signer
fingerprint. `PinVerifiedOfficial(sequence)` may execute only when that exact
authorization occurs in replayed signed history. Current catalog expiry or
release-list omission does not invalidate the historical proof; a known key or
archive revocation still dominates it.

No production official catalog root is published in this milestone.
Production therefore declares official authority unavailable rather than
embedding a fixture key, trusting profile YAML, or promoting the separately
shipped connector Pack to built-in status. Publishing and embedding the real
root is a prerequisite of the public official install/refresh path.

## Consequences and verification

- production now discovers exact trusted-community Packs already installed in
  the selected profile and exposes their enabled components through the same
  registry as the standard Pack;
- an official pin is evidence of a prior selection, not self-authenticating
  proof that its signer was official;
- offline official execution remains supported once a real compiled root and
  accepted history exist;
- downgrade to a build without the required root fails visibly rather than
  ignoring catalog state or configured behavior;
- the Microsoft To Do Pack follows the generic loader and receives no
  provider-specific core branch; and
- integration tests cover combined registries, missing archives, unavailable
  authority, exact historical authorization, and remembered revocation.

# ADR 0035: Bind live integrations to exact Pack pins

Status: accepted for S09

## Context

The V1 contract keeps one preferred installed Pack pin per exact Pack name, but
an accepted update may rebind only some integrations. Replacing that preferred
pin cannot silently move every existing provider account to the new code, and
a component-ID-only binding cannot distinguish two releases that expose the
same component ID.

Keeping a second independently managed installation registry would duplicate
authority and make removal and garbage collection ambiguous. Resolving an old
binding through whichever release is currently preferred would violate the
signed provenance and explicit-rebinding requirements.

## Decision

`installed_components` remains the profile's one preferred pin per Pack name.
It supplies the default component selected for new configuration and unbound
component discovery.

Every `ProviderAccount` carries an exact `pack_pin` as well as its component
ID. The pin contains the artifact identity, signer, trust origin, and enabled
component set already used by installation authority. A newly connected
account copies the current preferred pin only after the signed component has
been selected and reviewed.

The runtime registry has two deterministic views:

1. the default view contains only the built-in Pack and preferred profile pins
   and continues to reject component-ID collisions;
2. the exact view is keyed by `(PackArtifactIdentity, component ID)` and also
   contains releases retained by live bindings.

Provider observation, OAuth refresh, and broker construction resolve through
the account's exact view. Updating the preferred pin therefore affects no
existing account until a reviewed update plan rewrites that account's exact
pin. OAuth authorization fingerprints remain artifact-bound and may require a
new provider connection before a binding can move.

Profile startup authenticates and authorizes every exact pin referenced by a
live account. Equal artifact pins are coalesced only when signer and trust
origin agree; their enabled component sets are unioned. A missing, revoked, or
unverifiable retained archive fails closed. Merely storing an unreferenced
archive creates no execution authority.

DeliveryBindings and UIAdapter bindings must adopt the same exact-pin rule
before their update paths are enabled. Historical canonical provenance remains
self-contained and does not become runtime authority.

## Consequences

- Preferred and retained releases can coexist without a dependency solver or
  a second installation database.
- Existing provider accounts keep their reviewed code until explicitly
  rebound.
- Removal can distinguish deactivating a preferred pin from breaking a live
  binding, and garbage collection can derive exact archive references.
- `integrations.yaml` is intentionally more explicit and repeats a small signed
  pin inside each provider account.
- V1 is greenfield, so the closed `little-ant/integrations@1` schema requires
  `pack_pin`; there is no ambiguous compatibility fallback.

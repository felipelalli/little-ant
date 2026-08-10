# ADR 0034 — Connect explicitly signed static credentials after consent

Status: accepted for S09

## Context

The official GitHub Issues adapter declares one `bearer_token` credential slot.
The existing guided provider connection supported only signed OAuth flows, so
showing GitHub as `connect...` would incorrectly ask for a public OAuth client
ID and then fail. Asking for the token during command parsing would instead put
secret material too early in the flow and risk carrying it through a persisted
interaction checkpoint.

This does not reverse ADR 0018's rejection of pretending that a Microsoft OAuth
slot accepts an ad-hoc bearer token. Static connection is available only when
the installed signed component itself declares the static scheme.

## Decision

A provider is statically connectable only when its executable component has no
OAuth authorization and has exactly one otherwise-unclaimed `bearer_token` or
`api_key` slot. Zero or multiple eligible slots fail closed. The signed Pack,
not the provider name or UI hint, remains authoritative for the slot and scheme.

The dumb flow collects the local account key and optional English label, then
shows the ordinary no-default connection preview. That draft contains the exact
Pack artifact, component, slot, scheme, account, and profile revision; it never
contains the credential. Empty static fields such as OAuth client ID and scopes
are omitted from serialized interaction JSON rather than represented as null or
empty noise.

Acceptance reloads the profile and Pack and regenerates the draft. It checks
that the Vault is unlocked before requesting secret input. The CLI disables
terminal echo; the Vty REPL uses a dedicated masked editor whose bytes stay only
in the running process. Escape cancels without profile or Vault mutation. The
trusted host writes the credential to the exact opaque Vault UUID and wipes its
mutable byte buffer before it compare-and-swaps the non-secret typed account and
binding into `integrations.yaml`. A lost profile race may leave an unreferenced
Vault entry, but never configuration that references a missing secret.

OAuth connection remains unchanged and still requires its public client ID.
The provider catalog carries a presentation hint only to skip that editor for a
known static connector; draft construction always checks the installed signed
component and rejects a mismatched hint.

## Consequences and verification

- GitHub Issues can honestly appear in `/import` as `connect...` and returns to
  its ordinary snapshot/synchronize selector after connection;
- bearer and API-key bytes never enter arguments, YAML, events, Pack input,
  persisted checkpoints, JSON results, transcripts, or rendered diagnostics;
- a locked Vault stops before the credential callback, and dry-run requests no
  secret;
- static credential replacement reuses the binding's exact Vault UUID and
  cannot change its declared scheme;
- OAuth and static paths share the same signed-artifact refresh, no-default
  preview, profile compare-and-swap, and production ImportPort; and
- focused tests prove sparse preview serialization, post-consent acquisition,
  redacted inventory, typed binding persistence, restart discovery, and the
  unchanged OAuth path.

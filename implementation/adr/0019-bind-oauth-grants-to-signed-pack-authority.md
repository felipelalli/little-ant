# ADR 0019 — Bind OAuth grants to signed Pack authority

Status: accepted for S09

## Context

ADR 0018 established typed provider accounts, credential bindings, vault
custody, and credential injection after HTTP-route authorization. A usable
OAuth device flow still needs to decide which authority may select endpoints,
scopes, and client identity; how a stored grant survives Pack or account
changes; and how refresh-token rotation reaches the encrypted vault without a
partially updated credential.

Treating OAuth endpoints or scopes as mutable host configuration would let an
unsigned profile change the authority requested from the provider. Treating a
token set as valid merely because its slot name still matches would also let a
grant silently outlive a Pack, endpoint, scope, or client-ID change.

## Decision

An executable component using `oauth2_device_authorization` declares one
signed `oauth_device_authorization` descriptor for that credential slot. The
descriptor owns the exact HTTPS device-authorization endpoint, HTTPS token
endpoint, provider-account configuration key containing the public client ID,
and requested scope set. Device authorization requires `offline_access` so the
trusted host can refresh without inventing a second credential shape.

The public client ID remains non-secret account configuration. Before consent,
the trusted host computes a SHA-256 authorization fingerprint over the exact
Pack artifact identity, component ID, credential slot, signed endpoints,
resolved client ID, and signed scopes. Both the `CredentialBinding` and the
closed `little-ant/oauth-token-set@1` vault payload carry that fingerprint.
Any mismatch requires a fresh reviewed connection; it is never accepted as a
transparent update.

The trusted host owns the complete OAuth Device Authorization state machine:

1. start authorization with the signed client ID and scopes;
2. expose only the bounded verification URI, user code, expiry, and polling
   interval to the interaction surface;
3. poll with the opaque device code, honoring `authorization_pending`,
   `slow_down`, decline, bad code, and expiry;
4. accept only Bearer access tokens whose returned scopes are a nonempty
   subset of the signed access scopes; and
5. refresh with the stored refresh token, adopting provider rotation while
   retaining the prior refresh token only when a successful response omits a
   replacement.

OAuth form requests use a separate trusted TLS transport with system CA
validation, no redirects, proxy, cookies, or automatic decompression, fixed
timeouts, bounded JSON responses, and sanitized failures. Lua and the Pack
receive neither device codes nor tokens.

Successful acquisition or refresh is encoded as the closed token-set payload
and sent to the profile-scoped vault agent. Updating an existing UUID must keep
the credential scheme unchanged. The agent validates and replaces the entire
vault revision atomically; a failed mutation preserves the prior token set.

## Consequences and verification

- Pack signatures, not mutable YAML, authorize OAuth endpoints and scopes;
- changing a Pack artifact, component, slot, endpoint, scope, or client ID
  invalidates the local binding and requires reviewed consent;
- host-only client configuration is removed before the Lua adapter receives
  its ordinary configuration;
- refresh-token rotation cannot create a mixed or partially written token set;
- malformed responses, scope escalation, expiry, decline, and authorization
  drift fail without provider-source mutation; and
- focused tests cover the full pending-to-success lifecycle, slowdown,
  decline, local expiry, scope confinement, refresh rotation, and a real vault
  agent insert/refresh round trip.

Production discovery of the pinned official Pack and public connection/import
orchestration remain separate milestones. This ADR adds no provider-specific
branch to the deterministic core.

## Protocol references

- [Microsoft identity platform OAuth 2.0 device authorization grant](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code)
- [Microsoft identity platform scopes and `offline_access`](https://learn.microsoft.com/en-us/entra/identity-platform/scopes-oidc)
- [Microsoft identity platform refresh tokens](https://learn.microsoft.com/en-us/entra/identity-platform/refresh-tokens)

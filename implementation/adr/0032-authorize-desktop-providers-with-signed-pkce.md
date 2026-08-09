# ADR 0032 — Authorize desktop providers with signed PKCE

## Context

Google Tasks and similar native-app providers require OAuth authorization code
with PKCE rather than Device Authorization. Little Ant already had typed OAuth
token custody and a trusted Device Authorization host, but the Pack format did
not yet carry the exact authority needed to start a PKCE flow. Leaving those
endpoints or scopes in mutable profile configuration would let configuration
silently widen a signed component's authority.

## Decision

An executable component that uses `oauth2_authorization_code_pkce` declares
exactly one signed `oauth_authorization_code_pkce` descriptor for that slot.
It owns the exact HTTPS authorization and token endpoints, public client-ID
configuration key, requested scopes, and bounded additional authorization
parameters. Additional parameters cannot replace any host-owned OAuth or PKCE
field. These values and the exact Pack/component identity form the same
drift-sensitive authorization fingerprint used by token custody.

The trusted host generates 64 bytes for an unpadded base64url verifier and 32
bytes for state, derives an `S256` challenge, presents the external-browser URL,
and listens once on an ephemeral IPv4 `127.0.0.1` port at
`/oauth/callback`. It accepts only the exact loopback peer, Host header, path,
bounded request, unique query fields, and state. It then exchanges the code
without a client secret. The callback times out after five minutes and fails
closed after its one request.

The initial exchange must produce a refresh token. A refresh may omit a
replacement refresh token or the unchanged scope field; the host retains the
previously verified value. Any returned scope must remain a nonempty subset of
the signed request. Token-set persistence remains an atomic same-scheme vault
mutation.

## Consequences

- Packs, configuration, Lua, events, and InteractionEnvelopes never receive
  state, verifier, authorization code, access token, or refresh token.
- Profile connection can dispatch from one generic reviewed draft to either
  Device Authorization or PKCE without domain-specific core branches.
- A signed authority or public client-ID change requires fresh consent rather
  than silently reusing a token.
- Version 1 deliberately uses deterministic IPv4 loopback rather than racing
  IPv4 and IPv6 listeners. A failed or intercepted one-shot callback requires
  the human to retry the unchanged connection preview.
- Automatic access-token refresh during a later provider request remains a
  separate broker milestone; this decision supplies and persists the refresh
  operation without hiding provider work inside replay.

## Evidence

The OAuth suite covers exact authorization URL ownership, PKCE challenge and
verifier lengths, transient state, public-client exchange, missing refresh
custody, scope confinement, refresh responses that omit unchanged fields, and
the production IPv4 loopback receiver. Pack-format tests cover canonical
round-trip and rejection of missing, insecure, or host-field-overriding
authority.

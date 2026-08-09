# ADR 0018 — Bind provider HTTP after typed account authorization

Status: accepted for S09

## Context

The official Microsoft To Do Pack can already describe its reads through the
transcript broker, but production configuration still represented provider
accounts and credential bindings as arbitrary strings. The file ImportPort
also assumed every source was a local path. Connecting those placeholders
directly to an HTTP client would make account identity ambiguous and risk
injecting credentials before the Pack request had crossed its signed authority
boundary.

OAuth Device Authorization is a separate state machine: authorization
initiation, human verification, bounded polling, expiry, refresh, revocation,
and atomic replacement of vault material. This milestone must not simulate
that state machine or advertise a live provider happy path before it exists.

## Decision

Replace the placeholder integration maps with closed typed records.

A `ProviderAccount` names one enabled component, provider namespace, stable
provider account identity, human label, and JSON object containing only
non-secret component configuration. A `CredentialBinding` names one exact
component slot and account, its declared scheme, one opaque vault-entry UUID,
and a nonempty purpose set. The profile validator rejects missing enabled
components, dangling accounts, mismatched components, duplicate
component/slot/account ownership, malformed names, and recursively
secret-shaped configuration keys.

Configured providers become explicit `ProviderImportSource` values. One
account uses the adapter ID as its source reference; multiple accounts use
`adapter@account`, avoiding an implicit default. Host-owned `provider`,
`account_id`, and `account_label` fields are injected into the adapter
configuration and cannot be overridden. The provider-aware ImportPort invokes
the same sparse preflight and consent-gated materialization contracts as file
sources.

The credential-bound broker receives an execution-authorized component. On
every request it independently rechecks the signed route and exact credential
slot before asking an `AccessTokenResolver` for secret material. It then passes
an internal, deliberately non-serializable credentialed request to a trusted
transport. The Pack-visible request and replay transcript never contain the
Authorization header.

The production transport uses `http-client` with the TLS manager and system CA
validation. It disables redirects, proxies, cookies, and automatic
decompression; applies a fixed timeout and response-body bound; accepts only
JSON; retains only the broker's closed response-header set; and converts
transport exceptions to generic errors without rendering the request.

OAuth vault entries use the closed canonical
`little-ant/oauth-token-set@1` payload: Bearer token type, access token,
optional refresh token, expiry, and scopes. The vault agent resolves the opaque
entry only for `source_read`. Expired material produces
`PermissionRequired` with `RetryAfterRefresh`; it is not counted as provider
failure and is not silently used.

## Rejected shortcut

A peer review suggested allowing a manually entered bearer token so the public
Microsoft To Do path could succeed before Device Authorization exists. That
would either mislabel bearer material as `oauth2_device_authorization` or widen
the signed component to a second credential scheme solely as a temporary
shortcut. Both make the core less truthful. V1 instead keeps the public route
unadvertised until the declared OAuth flow can create and refresh the typed
vault entry honestly.

## Consequences and verification

- account and binding configuration is inspectable, closed, and contains no
  secret values;
- moving configuration without its vault keeps an opaque unbound/locked state;
- credentials are resolved only after signed route authorization and never
  enter source custody, Pack input, replay, or rendered exceptions;
- hostile or mismatched routes, slots, schemes, and components fail before
  credential resolution or transport;
- multiple accounts have deterministic explicit references and distinct
  provider identity inputs;
- fake-provider tests execute complete remote preflight and materialization
  through the actual Pack runner and prove token absence from transcripts; and
- OAuth Device Authorization/refresh, installed official-Pack loading, and the
  public import selector remain the next coherent milestone rather than hidden
  incompleteness in this one.

# ADR 0033 — Refresh provider grants before broker use

Status: accepted for S09

## Context

Device Authorization and authorization code with PKCE both persist a closed,
expiring OAuth token set. The provider broker already refuses to use an expired
access token, but returning `RetryAfterRefresh` to every caller would duplicate
refresh orchestration and could let a caller select endpoints or scopes that
differ from the installed signed Pack.

## Decision

The production `AccessTokenResolver` may refresh one locally expired OAuth
grant before a credentialed provider request. It resolves the exact enabled
SourceAdapter, account, credential slot, binding scheme, client ID, signed
OAuth descriptor, and authorization fingerprint from the installed Pack and
profile. Device and PKCE bindings dispatch only to their matching closed
refresh protocol.

The resolver sends the existing refresh token only to the signed token
endpoint through the trusted OAuth form transport. Returned scopes remain
confined to signed authority. A successful response may retain an omitted
replacement refresh token or unchanged scope set, but the complete resulting
token set must be atomically persisted through the same profile vault agent
before its access token is returned to the broker. Failure to refresh or
persist performs no provider request. A rejected or unusable refresh grant
returns `PermissionRequired` with a concrete reconnect action.

No provider response, Pack transcript, event, interaction, diagnostic, or
configuration receives either token set. Replay never refreshes: the operation
exists only inside the live trusted provider-transport boundary.

## Consequences

- callers use one provider broker regardless of OAuth grant type;
- mutable profile configuration cannot widen refresh authority;
- a new access token is never used unless its complete custody update succeeds;
- ordinary provider failure and local credential expiry remain distinct; and
- V1 refreshes from local expiry rather than blindly retrying a failed provider
  request, avoiding duplicate non-idempotent provider work.

## Evidence

The OAuth suite starts a real profile vault agent with an expired Google Tasks
PKCE grant, resolves the signed official component, refreshes exactly once,
persists a response that omits unchanged fields, and reuses the replacement on
the next access without another OAuth request. Provider-host tests continue to
prove route and binding checks occur before credential resolution.

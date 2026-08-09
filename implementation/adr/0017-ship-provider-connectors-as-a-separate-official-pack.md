# ADR 0017 — Ship provider connectors as a separate official Pack

Status: accepted for S09

## Context

Little Ant needs provider-specific behavior without moving provider policy,
credentials, or network authority into either the deterministic core or
untrusted Lua. Microsoft To Do is the first online migration target and needs
adaptive Microsoft Graph pagination, stable source identity, optional completed
items, and an honest answer when Graph metadata says an attachment exists but
the list response does not contain its bytes.

The standard Pack is an exact built-in offline artifact. Provider connectors
have a different release and permission surface: they need catalog trust,
credential slots, tightly scoped HTTP routes, and independently reviewable
cleanup purposes.

## Decision

Ship provider components in the separately signed and reproducible
`org.littleant.official-connectors` Pack. It is verified through the ordinary
Pack format, authentication, official-catalog trust, pin, and component
registry boundaries. It is not privileged Haskell code and is not folded into
the standard offline Pack.

The first component is the `microsoft_todo` SourceAdapter. Its signed authority
contains exactly:

- GET requests to `https://graph.microsoft.com/v1.0/me/todo...`;
- one `microsoft` OAuth 2 device-authorization credential slot; and
- separate `source_cleanup_item` and `source_cleanup_container` effect
  purposes.

Lua receives neither the OAuth token nor transport authority. The trusted host
injects credentials only while brokering an authorized request. Read access
does not imply delete access: migration cleanup will be a separately previewed,
approved, and dispatched effect.

The adapter reads every selected list and its paginated tasks. Provider
identity is account + list + task, independent of mutable titles. Completed
tasks are excluded unless explicitly requested. Each accepted task becomes one
structured Raw document containing the complete task JSON returned by Graph,
plus its account and list context. Persisted preflight retains only sparse
identity, counts, digests, warnings, and bounded previews.

The Pack runner exposes pure canonical JSON encoding and RFC 3986 UTF-8 path
segment encoding. These operations add no IO authority and prevent provider
identifiers from being mistaken for URL syntax.

## Attachment boundary

A task list response can report `hasAttachments` without carrying attachment
bodies. Metadata is not treated as imported bytes. Snapshot and synchronization
remain available with an explicit warning. Migration fails while any included
task has unmaterialized attachment bodies unless the user explicitly accepts
an incomplete attachment transfer.

This guard is deliberately conservative. A later milestone may add bounded
attachment enumeration and binary custody as a distinct reviewed capability;
this milestone does not invent blob handles or silently discard provider data.

## Consequences and verification

- connector releases can evolve independently while using the same trust and
  isolation path as community Packs;
- the core remains provider-neutral and replay remains offline;
- exact source identity survives title changes and Pack upgrades;
- fake Microsoft Graph tests cover list/task pagination, completed-item opt-in,
  path encoding, complete structured-Raw materialization, and preflight
  privacy;
- a provider-controlled `@odata.nextLink` outside the signed Graph route is
  rejected before the broker performs the next call;
- canonical source files reconstruct the committed signed archive byte for
  byte; and
- production account discovery, credential resolution, public import
  orchestration, and cleanup dispatch remain explicit follow-up milestones.

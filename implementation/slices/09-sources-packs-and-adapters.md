# S09 — Sources, Packs, adapters, exports, and repair

Status: **in progress**

## Outcome

Complete external observation and extension boundaries: Raw source
reconciliation, translation review, standard imports and optional cleanup,
Google Calendar, reproducible Packs, safe exporters, local-web hosting
infrastructure, complete command registry, and corrupt-history recovery.

## Canonical flow rows owned

- Preserve/normalize Raw
- Raw review/source reconcile
- `/translate`
- Import/migrate/erase source
- Calendar observe/write
- Pack trust/install/update/remove
- Canonical commands and safe export
- Typed reference/error/dry-run
- Corrupt history/repair

Generate all owning-row references plus the complete data/integration chapter,
[`standard-integration-catalog.md`](../../spec/little-ant-1.0/standard-integration-catalog.md),
[`pack-format-and-trust.md`](../../spec/little-ant-1.0/pack-format-and-trust.md),
the command catalog, DAT-011..023, DAT-028..043, DAT-046..050,
DAT-068..093, and UX-RA00..RA04, UX-IMP00..IMP02,
UX-CAL00..CAL01, UX-PACK00..PACK02, UX-EXP00.

## Work

1. Complete Raw revision/original/English-normalization, source binding,
   immutable observation, divergence, schedule, detach, and damaged-blob
   recovery.
2. Implement `/translate` as an attributed review queue; dumb mode never
   fabricates translation.
3. Implement Pack manifest/archive/signature/trust/revocation/update/remove
   protocols and the isolated HsLua runner with host-brokered IO.
4. Ship the standard offline Pack and official connector Pack exactly from the
   catalog, including Microsoft To Do and Notesnook paths needed for real
   migration use; unsupported provider capabilities remain explicit.
5. Implement Raw-first snapshot/synchronize/migrate preflight, idempotent
   adoption, partial effects, verified cleanup queue, and source absence
   safety.
6. Implement observe-first Google Calendar adoption, occurrence identity,
   reconciliation, allowlisted write-back, and minimal privacy projections.
7. Implement standard structural exporters, TaskJuggler exporter/actuals
   importer, safe stdout/new-file host writes, and local-web UIAdapter host
   protocol. S11 verifies complete visual parity.
8. Close the command/help/schema registry, contextual palette, generic
   dry-run, typed reference/error families, doctor, and candidate-based repair.

Current checkpoint: structural exporters, the core-owned TaskJuggler planning
cut/exporter, the isolated SourceAdapter preflight/materialization contract,
and the separate TaskJuggler actuals custody and Raw-first acceptance paths are
implemented through the exact signed standard Pack. Explicit consent now
reacquires source bytes and invokes a distinct materialization operation; the
host rejects any drift from the sparse preview before one atomic multiobject
command. Generic acceptance preserves stable object identity, collision-free
handles, exact-retry idempotency, and changed-material reconciliation.

The `plain_text` component has the complete explicit CLI preflight and verified
Raw-first acceptance path, including stale regeneration, stable ImportProfile
scope, immutable ImportInvocation custody, SourceBinding identity, dry-run,
and unsupported cleanup failure. The bundled offline Notesnook ZIP adapter
imports Markdown, HTML, and plain-text notes through a deterministic bounded
archive helper while retaining relative-path identities, source-container
suggestions, and unsupported-entry diagnostics. TaskJuggler actuals have
independent core/Lua manifest verification, explicit observation time, partial
actual semantics, real `tj3` coverage, a public snapshot preview, atomic
immutable evidence acceptance, monotonic observation custody, and conservative
explicit-remaining projection without estimate mutation. The separately signed
official connector Pack now contains a `microsoft_todo` SourceAdapter. It
performs bounded paginated list/task reads, preserves stable account/list/task
identities, keeps completed tasks opt-in, and materializes complete returned
task JSON as structured Raw. Sparse preflight contains no private provider
body. Reported attachments whose bytes are absent from Graph remain explicit
limitations, and migrate requires an explicit incomplete-attachment
acknowledgment. The public configuration connection and provider-aware CLI
import paths are implemented; the dumb REPL source selector, separately
consented cleanup effects, remaining standard importers, Calendar, and
local-web UIAdapter remain in this slice.

The trusted provider host now has typed ProviderAccount and CredentialBinding
configuration, unambiguous single/multi-account source references, a
provider-aware ImportPort, closed expiring OAuth token-set custody, vault-agent
resolution, and real bounded HTTPS transport. Credentials are resolved only
after signed route and slot authorization and never enter Pack transcripts or
persisted preflight. Signed OAuth Device Authorization and refresh are now
implemented: endpoint and scope authority plus the public client ID produce a
drift-sensitive fingerprint, returned scopes remain confined, and token
rotation persists atomically through the vault agent. Production now combines
the exact standard Pack with all trusted profile pins from the
content-addressed store and fails the whole registry on unsafe or unavailable
configured behavior. Official pins additionally require exact replayed catalog
history. The production generation-zero root and sequence-1 catalog are now
published, and explicit refresh plus official-name installation expose the
ordinary no-default consent path. `config connect` now binds one reviewed
account through transient Device Authorization and the encrypted vault; a
restarted production CLI exposes that account through the same
snapshot/synchronize/migrate ImportPort as offline sources. Contextual REPL
discovery and connection remain open.

The public read-only Pack manager now exposes `lant packs list` and exact-name
`lant packs show` through one sparse `little-ant/packs@1` projection. It shows
the built-in and profile-pinned identities, trust class, status, exact signer
and archive digests, enabled components, and signed permission summaries.
Registry failure no longer prevents Pack recovery or Pack-free canonical work:
adapter ports fail closed with the retained typed error, while the manager can
still inspect a missing or invalid pin as unavailable. Local community trust
and archive installation now implement UX-PACK00 as two independent
no-default consents with exact file/profile custody, dry-run, content-addressed
publication, and atomic profile pinning. The contextual dumb `/packs` REPL
manager now keeps list/detail/input collection non-consequential, hands trust
and installation to those same canonical envelopes, exposes explicit signed
catalog refresh, and refreshes its runtime registry after accepted authority
changes. Updates and removal/GC remain open.

Provider-backed SourceAdapters now have a bounded host-brokered HTTP kernel.
Lua receives a synchronous-looking JSON request function but no network or
credential authority. Each exchange is authorized against one unambiguous
signed component route, executed by the trusted host, sanitized, and replayed
through a fresh private process and VM. Remote preflight persists only custody
digest/count plus the sparse observation; materialization refetches and must
match. The Microsoft To Do component is built on this kernel as an exact
official artifact. Typed credential binding, transport, acquisition, refresh,
installed-Pack loading, public account connection, and production provider
import routing are built. Contextual REPL orchestration and cleanup-effect
dispatch remain to be built.

## Gate

- replay works with every Pack removed and performs no provider IO;
- archive/signature and trust fixtures are reproducible byte-for-byte;
- every adapter capability is constrained by the shipping catalog;
- missing source objects never imply local completion or deletion;
- erase-after-import cannot dispatch before canonical verification and exact
  consent;
- export cannot overwrite, follow symlinks, or escape its one new file;
- full command enumeration has no alias and uses only `lant`;
- corrupt-log fixtures stop safely and repair only into a fully replayed
  replacement dataset.

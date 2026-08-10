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
suggestions, and unsupported-entry diagnostics. The same signed Pack now
preserves individual Markdown, HTML, JSON, CSV, and Org files without
conversion and imports complete Evernote ENEX note elements with stable GUID or
digest identity and embedded-resource custody. The Apple Reminders offline kit
ships a closed JSON Schema, reviewed example, and inspectable Shortcut recipe;
its strict adapter requires Apple identifiers, preserves task-shaped structured
Raw, and reports fields the portable workflow cannot export. TaskJuggler actuals have
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
acknowledgment. The public configuration connection, provider-aware CLI import
paths, generic canonical acceptance, and dumb REPL source selector are
implemented. Microsoft To Do item cleanup is now separately proposed only
after local Raw verification, approved as one exact finite set, and dispatched
item by item with durable intent and receipts. Empty source containers now have
a separate fresh inspection, approval, pre-delete recheck, and unknown-outcome
reconciliation path. The signed connector Pack now also carries an observe-only
GitHub Issues adapter with stable node identities, page-number pagination,
explicit closed-issue inclusion, pull-request omission, and complete structured
Raw custody. Its exact least-authority route is
`GET https://api.github.com/issues`; cleanup and issue mutation remain
unsupported. Generic guided static credentials now bind an explicitly signed
bearer/API-key slot to no-echo post-consent Vault input before typed profile
configuration, so GitHub can appear honestly in the dumb source selector.
Calendar write-back, the remaining connector breadth, and the local-web
UIAdapter remain in this slice.

The trusted provider host now has typed ProviderAccount and CredentialBinding
configuration, unambiguous single/multi-account source references, a
provider-aware ImportPort, closed expiring OAuth token-set custody, vault-agent
resolution, and real bounded HTTPS transport. Credentials are resolved only
after signed route and slot authorization and never enter Pack transcripts or
persisted preflight. Signed OAuth Device Authorization and authorization code
with PKCE are now implemented: endpoint and scope authority plus the public
client ID produce a drift-sensitive fingerprint, returned scopes remain
confined, and token rotation persists atomically through the vault agent. PKCE
uses `S256`, a one-shot IPv4 loopback receiver, exact state validation, and no
persisted authorization session. Production now combines
the exact standard Pack with all trusted profile pins from the
content-addressed store and fails the whole registry on unsafe or unavailable
configured behavior. Official pins additionally require exact replayed catalog
history. The production generation-zero root and current monotonic catalog are
now published, and explicit refresh plus official-name installation expose the
ordinary no-default consent path. `config connect` now binds one reviewed
account through transient Device Authorization and the encrypted vault; a
restarted production CLI exposes that account through the same
snapshot/synchronize/migrate ImportPort as offline sources. Contextual REPL
discovery, exact multi-account choices, and connection return to a
still-unapproved import mode are implemented.

The same official Pack now also contains `google_tasks`. Its signed PKCE
authority, bounded Google Tasks routes, opaque page-token encoding, complete
structured-Raw materialization, completed/hidden opt-in, exact item cleanup,
and nondefault empty-list cleanup all use the generic provider host. Expired
OAuth grants are refreshed from the exact signed component and persisted
through the vault agent before the broker may use the replacement access
token. The Pack also ships an observe-only `google_calendar` adapter with
read-only PKCE authority, discovery that reads no events, exact nonempty
calendar allowlists, bounded opaque pagination, and complete structured event
custody. Exact allowlists are durable in revisioned import profiles, immutable
in import invocations, and retained in pending consent. Repeated CLI
`--container ID` flags select scope explicitly; omission reuses one
unambiguous active scope, while a changed set revises that profile without
rewriting history. The dumb REPL discovers containers and exposes a bounded,
arrow-key, Space-toggle, no-default selector. Reviewed Calendar write-back
remains a later separate authority.

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
changes. `lant packs updates` now inspects only the already accepted signed
catalog, performs no network request, mutates no profile or dataset state, and
selects the newest release with complete SemVer precedence. Update acceptance
is now one persisted no-default plan over an official catalog candidate or a
local trusted-publisher archive. It records the complete signed difference and
per-binding disposition, revalidates both archives and the whole plan at
acceptance, preserves OAuth and pending-effect bindings on the old release,
and atomically changes the preferred pin plus only compatible displayed static
bindings. Removal/GC remain open. Live ProviderAccounts retain one exact Pack pin.
The runtime separately indexes preferred components and exact retained
components, so changing the preferred release cannot silently upgrade an
existing provider binding.

Provider-backed SourceAdapters now have a bounded host-brokered HTTP kernel.
Lua receives a synchronous-looking JSON request function but no network or
credential authority. Each exchange is authorized against one unambiguous
signed component route, executed by the trusted host, sanitized, and replayed
through a fresh private process and VM. Remote preflight persists only custody
digest/count plus the sparse observation; materialization refetches and must
match. The Microsoft To Do component is built on this kernel as an exact
official artifact. Typed credential binding, transport, acquisition, refresh,
installed-Pack loading, public account connection, production provider import
routing, contextual REPL orchestration, and canonical provider-material
acceptance are built. Item cleanup now revalidates the exact signed Pack,
account, credential binding, import invocation, and target before every
provider request. A durable `dispatching` state precedes DELETE; interrupted
or lost responses become `outcome_unknown` and are checked with a read-only
provider request before any retry. Retryable unchanged idempotent items can
reuse the original exact approval, while an unknowable result requires a new
revision, explicit duplicate-risk consent, and ordinary approval again.
Successful, terminal, rejected, and withdrawn item dispositions retire the
ImportProfile only when every selected item is terminal. Local imported Raw is
never removed.

The shared ExternalEffect aggregate is no longer Delegation-shaped. Closed
typed requests, exact signed-adapter custody, separate payload and record
versions, the full lifecycle vocabulary, and durable finite-set approval
grants now provide the common consent boundary for source cleanup and later
Calendar effects. Source cleanup proposal, exact-set approval, itemwise
dispatch, restart recovery, read-only reconciliation, safe retry, explicit
duplicate-risk revision, rejection, withdrawal, and terminal profile closure
are implemented for Microsoft To Do items. Source-container cleanup is also
implemented as a separate later approval boundary: only an empty custom owned
list whose item effects all succeeded can be proposed; the Pack repeats the
complete paginated emptiness check immediately before DELETE, and a lost result
is reconciled read-only rather than retried blindly.

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

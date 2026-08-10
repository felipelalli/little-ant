# Implementation handoff

Current release gate: **1.0.0-alpha.2 — dumb daily use, safe v0 migration, and direct REPL exit.**
The supported boundary lives in `implementation/releases/v1-alpha.md`; the
remaining S08-S11 obligations live in `implementation/releases/v1-beta.md`.
Coverage labels stay conservative until executable evidence is reconciled.


Baseline at the start of the current milestone: **b484d5b**
(`feat(packs): discover signed updates`). The current milestone binds every
live ProviderAccount to its exact Pack artifact while retaining one preferred
release per Pack name for new work. This file stays editable between milestone
commits.

## Implementation now available

- append-only replayable JSONL command groups, typed sparse results, persisted
  integrity-protected InteractionEnvelopes, factual loading progress, and the
  dumb Vty REPL foundation;
- Feed-first Raw triage, Natures/Templates, RawShelves, ListEntries, typed Raw
  links, duplicate suspicion, child Work, Domains, sibling-only importance
  insertion, and exact identity/handle separation;
- decaying human judgment, continuous adaptive ordering, nearby skip,
  provisional placement, provocative validation, contradiction recovery,
  independent Impact/Effort evidence, and optional phase;
- hierarchical replay-safe weighted forecast, Domain continuity/scope,
  N-step Dependency forwarding, Focus/WIP, skip diagnosis, Pomodoro, break,
  archive/restore, and checklist runs;
- exact dates/notices, repeatable jitter, recurrence, habit outcomes,
  scheduled commitments, operational-day boundaries, and truthful standing
  outcomes;
- ExternalEntity and ContactPoint state, Wait gates/reviews, Nature-aware
  Delegation coverage, typed immutable external-effect requests, exact finite
  approval grants, profiles/configuration, age-v1 encrypted vaults, and a
  profile-scoped AF_UNIX vault agent;
- dumb mini-simulations for external-condition Wait activation and manual
  Delegation from skip diagnosis through observed handoff;
- effect edit, defer, reject, approval, durable dispatch intent, and receipt
  transitions, with deferred effects excluded from the forecast.
- Microsoft To Do item cleanup after verified migration, with one effect per
  exact selected object, finite-set approval, durable intent before DELETE,
  partial-progress preservation, restart recovery, read-only reconciliation,
  safe unchanged retries, explicit duplicate-risk revisions, and terminal
  profile closure. Every dispatch rechecks signed Pack, account, credential,
  invocation, and target custody; local imported Raw is always retained.
- Microsoft To Do source-container cleanup after item success, with a separate
  no-default approval. The signed adapter verifies that a custom owned list is
  empty before proposal and repeats the paginated check immediately before
  deletion. New items, built-in/shared/non-owned lists, and authority drift
  fail closed; lost DELETE responses are reconciled read-only without a blind
  retry, and local Raw remains untouched.
- `lant doctor` runs before ordinary replay and auto-tick, reports the last
  valid cursor and event count, and identifies the first malformed event by
  canonical segment, physical JSONL line, and byte offset without mutating the
  dataset.
- a content-addressed repair plan can correct a provable segment-filename hash
  mismatch in a separate sibling dataset, replay the complete candidate, write
  a durable verification receipt, and reuse that candidate idempotently;
  unsupported corruption and stale plans fail before creating a candidate, and
  the live authority remains byte-for-byte unchanged.
- `lant repair` exposes separate preview, candidate-build, and cutover
  checkpoints with no default consent; cutover durably records its exact plan,
  uses an atomic same-filesystem directory exchange, resumes forward from
  pre- or post-exchange interruption, and retains the former authority as a
  read-only backup. Dry-run writes no repair artifact.
- `lant export` resolves a named, versioned exporter through an injected
  read-only port and supplies only a deterministic sparse structural
  projection. Export code receives no destination path or filesystem
  authority. The host either emits the artifact bytes to stdout or exclusively
  publishes one private new regular file through a same-directory temporary
  file and atomic no-clobber link; unsafe targets fail before exporter
  invocation, and dry-run writes nothing. The production registry is populated
  from the exact built-in standard Pack; the serializers remain Lua components
  rather than privileged Haskell implementations.
- `little-ant/pack@1` has one closed concrete manifest shape with permissions
  owned by individual executable components. The canonical `.lantpack` writer
  emits one reproducible ZIP32/store encoding, and the structural verifier
  reconstructs the complete archive byte-for-byte before decoding strict JCS
  control documents or validating payload ownership, limits, lengths, and
  SHA-256 digests. It extracts nothing and produces a structural type that the
  executable registry cannot consume. Signature authentication and trust
  classification remain a separate authority boundary.
- exact Ed25519 authentication now validates canonical unpadded key/signature
  encodings, decoded lengths, the public-key fingerprint, and the signature
  over the exact manifest bytes. Trust assessment renders only the five
  canonical classes with revocation dominant and catalog freshness separate.
  Installation and pinned execution produce distinct opaque, profile- and
  artifact-bound capabilities: catalog expiry blocks a new official install
  while an accepted non-revoked official pin remains executable offline, and
  untrusting a community publisher disables its pins.
- authorized archives publish idempotently as private regular files under the
  global XDG content-addressed store and are never overwritten. Every load
  rechecks file type/mode, filename digest, canonical structure, Ed25519
  authentication, exact profile pin, current trust, and revocation before
  yielding execution authority. `integrations.yaml` now round-trips closed
  typed Pack pins and community publisher keys atomically. The component
  registry accepts only execution-authorized Packs, restricts payload bytes to
  each enabled component root, rejects cross-profile authority, and fails on
  component-ID collisions.
- official catalog refresh now verifies exact canonical bytes against the
  active compiled-root chain, accepts only an unexpired strictly newer
  sequence, and persists the signed history atomically per profile. Dual-signed
  contiguous root transitions remain verifiable from either compiled root,
  while effective key/archive revocations accumulate across all accepted
  catalogs and cannot disappear by omission.
- every Pack exporter runs in a fresh private non-threaded HsLua process over a
  bounded canonical stdin/stdout protocol. The VM has only pure library
  operations, payload-confined modules/assets, no dynamic loader or random
  source, and parent/child resource ceilings. Nix exposes only `lant` publicly
  and relocates the helper under `libexec/little-ant`.
- the signed, reproducible `org.littleant.standard` archive is verified against
  its compiled exact identity at startup and grants built-in execution
  authority only to the `tree`, `table`, `csv`, `org`, `html`, and
  `taskjuggler` exporters plus the `apple_reminders_export`, `document_file`,
  `evernote_enex`, `notesnook_export`, `plain_text`, and `taskjuggler_actuals`
  SourceAdapters.
  The structural exporters' reviewed fixtures cover hierarchy, quoting, UTF-8
  alignment, RFC 4180 framing, and a script-free/offline HTML document. The CLI
  production environment uses this registry, so `lant export csv` works
  without installing a provider Pack.
- `little-ant/taskjuggler@1` is built by the core from the explicit scope,
  current human-reviewed effort claims, dependencies, and temporal facts. Its
  deterministic cut never overlaps an effort-bearing ancestor and descendant,
  never substitutes a default for missing effort, fails closed on an unknown
  EffortProfile revision, and retains WIP total-effort, standing-owner,
  best-before, fixed-interval, dependency, and factory-resource assumptions as
  visible warnings. The canonical immutable manifest records its source
  cursor/hash, roots, cut, complete eight-macro profile, resources/calendar,
  projection, and exact exporter identity; the `.tjp` embeds the complete
  manifest plus its own digest, distinct from the artifact digest.
- the signed Lua TaskJuggler component only serializes that projection. It
  emits optimistic/realistic/pessimistic scenarios, stable UUID-derived task
  IDs, dependencies, order as a TaskJuggler scheduler tie-breaker, exact
  intervals, release milestones, deadlines, explicit effort gaps, and one
  inspectable factory UTC resource. Reviewed fragments and the real `tj3`
  parser cover the generated file, and the installed CLI exports a valid
  `.tjp` from an empty isolated profile.
- the same private runner now has an operation-typed SourceAdapter preflight.
  The trusted host supplies only bytes, a display label, media type, digest,
  count, and explicit mode; Lua receives no path or general IO authority.
  Export invocations cannot carry source bytes, and a SourceAdapter must hold
  the component-local `input_bytes` capability. The closed observation records
  supported modes, cleanup strength, containers, typed objects/material,
  source completion observations, attachment counts, duplicate-suspicion
  keys, unsupported fields, and warnings before the host adds immutable Pack,
  signer, and input-custody facts. Preflight material crosses back only as a
  bounded kind/digest/count/preview summary.
- explicit acceptance now invokes a distinct `source_materialize` runner
  operation after reacquiring the same source bytes. It returns transient full
  material only after consent; the host requires the Pack authority, input
  custody, observation, complete object identity set, and every material
  summary to reproduce the preview exactly before any event can be decided.
  No complete body is retained in the interaction checkpoint.
- the exact signed standard Pack now also authorizes `plain_text`. It describes
  one complete UTF-8 file as one note-shaped source object through a bounded
  custody summary, supports snapshot and migration, and truthfully declares
  no synchronization or cleanup. Both
  the generic runner fixture and the exact bundled component execute through
  the real private process.
- the standard Pack now also authorizes `document_file` for Markdown, HTML,
  JSON, CSV, and Org. One signed component preserves each complete UTF-8 file
  as one Raw without conversion, while the host chooses media type through a
  longest-specific-suffix rule. `evernote_enex` preserves every complete note
  element independently, retains embedded resources in the Raw XML, counts
  attachments, and uses GUID or element-digest identity. Both support only
  snapshot/migrate and declare no cleanup or live-presence inference.
- the standard Pack's Apple Reminders kit contains a closed JSON Schema,
  reviewed example, and human-auditable Shortcut recipe rather than a fake
  unsigned Apple workflow. Its `.apple-reminders.json` adapter wins over the
  generic JSON suffix, requires opaque Apple list/reminder identifiers,
  preserves each reminder as canonical structured Raw, keeps source completion
  observational, and declares recurrence, subtasks, attachments, and location
  alarms unsupported. Pure bounded JSON decoding lives in the isolated runner;
  null cannot disappear into Lua `nil`.
- `lant import <source> (--snapshot|--synchronize|--migrate)` now has a
  persisted read-only preflight with no default consent. Acceptance reacquires
  the file through `O_NOFOLLOW`, reruns the signed adapter, refreshes stale
  previews without events, and atomically records durable `ImportProfile`
  scope, immutable `ImportInvocation` authority/custody/result, canonical Raw
  bytes, and a stable `SourceBinding`. Exact retries are event-free; a Pack
  upgrade reuses unchanged mappings; changed material under one provider
  identity requires reconciliation; dry-run describes hypothetical results.
- generic import acceptance now preserves every materialized source object in
  one atomic command, with one stable `SourceBinding` per object and
  collision-free human handles. Exact multiobject retries remain event-free;
  changed material under a stable provider identity still enters explicit
  reconciliation rather than silently overwriting or duplicating truth.
- the exact signed standard Pack now also ships an offline Notesnook ZIP
  SourceAdapter. Its Lua component imports Markdown, HTML, and plain-text notes,
  retains relative paths as stable external identities, proposes source
  containers, and reports unsupported entries without provider IO or cleanup.
  A trusted runner helper expands only already-authorized input bytes with
  deterministic ordering and entry-count, path, encryption, symlink, size,
  expanded-total, and CRC checks.
- the standard Pack now contains a snapshot-only `taskjuggler_actuals`
  SourceAdapter. Its isolated Lua code and an independent Haskell parser both
  reconstruct the contiguous embedded manifest, verify its canonical bytes
  and SHA-256 identity, enforce flat canonical task membership, retain partial
  `effortdone`/`effortleft` with explicit zero, and require one explicit UTC
  progress cutoff. The host compares the adapter's manifest/as-of/count facts
  with its own parse before rendering the public import preview. Real `tj3`,
  malformed-custody fixtures, and CLI E2E cover the boundary without events.
- accepting that preview now atomically persists the whole `.tjp` Raw and its
  source custody before one immutable evidence event per actual-bearing task.
  Replay validates the Raw, invocation, canonical task identity, manifest,
  observation cutoff, and single-record membership. Exact retries add no
  events; older and equal non-identical observations fail before mutation;
  absent actual fields remain absent and explicit zero survives.
- planning leaves the historical EffortClaim and its three-point macro intact.
  Only the latest explicit `effortleft` becomes a separate, provenance-bearing
  remaining-effort projection. The signed exporter emits that exact point in
  all three TaskJuggler scenarios with a visible no-spread warning; a latest
  missing value or `effortdone` alone never revives or derives remaining work.
- provider-backed SourceAdapters can now call synchronous-looking
  `lant.http.request` without receiving network or credential authority. Every
  broker step runs a new private process and Lua VM against an exact sanitized
  transcript; an exhausted transcript yields one typed pending request for the
  trusted parent to authorize, execute, append, and replay from the beginning.
  Signed component permissions constrain the closed method set, exact
  lowercase HTTPS host, decoded path prefix, and allowed headers. Ambiguous
  rules, nearby hosts, ports, escaped traversal, unused exchanges, repeated
  request cycles, and oversized bodies or transcripts fail before unsafe IO.
- remote preflight and materialization entry points retain provider response
  transcripts only as transient host custody. Persisted previews contain the
  digest, count, label, and sparse SourceObservation rather than private
  provider bodies. A fake adaptive provider proves sequential list/child
  requests, fresh-VM replay, exact materialization, and denial before broker
  invocation.
- `org.littleant.official-connectors` is a separate canonical, reproducible,
  Ed25519-signed Pack rather than privileged provider code in the core. Its
  first SourceAdapter, `microsoft_todo`, declares only the Microsoft Graph To
  Do GET/DELETE route, one OAuth device-authorization credential slot, and
  separate item/container cleanup effect purposes. Lua never receives the
  OAuth token; DELETE remains host-brokered and requires a durable exact effect
  approval before invocation.
- the Microsoft To Do adapter supports snapshot, synchronization, and
  migration observations over paginated list and task collections. It keeps
  stable account/list/task provider identities, treats completed tasks as an
  explicit opt-in, encodes provider identifiers as canonical URL path
  segments, and preserves each complete task response as one structured Raw
  document after consent. Provider bodies remain absent from the sparse
  preflight.
- attachment custody stays truthful at the current JSON boundary. When Graph
  reports attachments without returning their bodies, snapshot and
  synchronization expose the limitation as a warning; migration fails unless
  the user explicitly acknowledges an incomplete attachment transfer. The
  adapter does not misreport metadata as imported bytes. Pure canonical JSON
  encoding and UTF-8 path-segment encoding are available to isolated Packs
  without adding IO authority.
- `integrations.yaml` now stores closed `ProviderAccount` and
  `CredentialBinding` records instead of stringly placeholders. An account
  names its enabled component, provider namespace, stable external identity,
  human label, and non-secret component configuration. A binding names the
  exact component slot, account, typed credential scheme, opaque vault-entry
  UUID, and purposes. Validation rejects dangling components/accounts,
  duplicate component-slot-account ownership, and recursively secret-shaped
  configuration keys.
- configured remote sources join those typed records to an execution-authorized
  Pack component. One account keeps the human source reference; multiple
  accounts receive explicit `adapter@account` references. Host-owned provider,
  account identity, and label fields cannot be replaced by Pack configuration.
  The provider-aware ImportPort reuses the existing sparse preflight and exact
  materialization contracts without treating remote input as a file.
- the credential-bound broker rechecks the signed HTTP route and slot before
  resolving one access token. The credential is added only to an internal
  non-serializable transport request after authorization; Pack requests,
  transcripts, source custody, preflights, diagnostics, and exceptions remain
  credential-free. The real transport uses CA-validated HTTPS with no redirect,
  proxy, cookie jar, or automatic decompression, a fixed timeout, bounded JSON
  responses, closed response headers, and sanitized errors.
- OAuth vault material has one closed `little-ant/oauth-token-set@1` shape with
  bearer type, access token, optional refresh token, expiry, scopes, and the
  authorization fingerprint that binds it to the exact signed Pack authority.
  The profile-scoped vault agent resolves it only for `source_read`; expired
  credentials return `RetryAfterRefresh` without becoming provider failure.
- OAuth Device Authorization is now a complete trusted-host protocol. The
  signed component owns exact HTTPS device/token endpoints and requested
  scopes, while the account supplies only the public client ID. The host
  exposes the bounded verification prompt, honors pending, slowdown, decline,
  and expiry, confines returned scopes, rotates refresh tokens, and atomically
  persists same-scheme token sets through the vault agent. Any Pack, endpoint,
  scope, slot, or client-ID drift requires fresh reviewed consent. Lua receives
  neither OAuth material nor host-only client configuration.
- OAuth authorization code with PKCE is now a second complete signed
  trusted-host protocol. Each participating component owns exact authorization
  and token endpoints, scopes, public-client configuration key, and bounded
  extra authorization parameters. The host generates an `S256` verifier and
  unpredictable state, exposes only the browser URL, receives one exact
  callback on an ephemeral `127.0.0.1` listener, exchanges the code without a
  client secret, and atomically stores the resulting token set through the
  same vault-agent boundary. State, verifier, authorization code, and tokens
  never enter Pack, profile, event, or interaction state. Initial exchange
  requires refresh custody; refresh preserves an omitted replacement token or
  unchanged scope set.
- expired provider grants are now refreshed by the trusted host before broker
  transport. Refresh authority is resolved from the exact installed signed
  component and credential binding, the new closed token set must be persisted
  through the same vault agent before use, and an invalid or unavailable grant
  stops with explicit reconnect recovery. Pack Lua and provider transcripts
  never receive either old or new credential material.
- The exact official connector Pack now declares both Microsoft To Do's
  device-flow authority and Google Tasks' authorization-code-with-PKCE
  authority. Google Tasks performs bounded task-list/task pagination, keeps
  completed and hidden tasks opt-in, preserves complete provider JSON as
  structured Raw after consent, and uses stable account/list/task identities.
  Item cleanup rechecks the exact target; container cleanup proves a nondefault
  list empty immediately before deletion and never deletes Google's default
  task list. The archive and official catalog identities were rebuilt and
  signed reproducibly.
- The exact official connector Pack now also contains an observe-only
  `github_issues` SourceAdapter. It declares one bearer credential slot for a
  repository-confined fine-grained token and only
  `GET https://api.github.com/issues`, supports
  snapshot and synchronization, includes open issues by default, keeps closed
  issues an explicit opt-in, and omits pull requests returned by GitHub's
  shared endpoint. Stable GitHub node identities anchor issue and repository
  custody; every accepted issue becomes complete structured Raw while sparse
  preflight retains no issue body. Cleanup, closing, editing, and deletion are
  unsupported.
- production now builds one registry from the exact standard Pack plus every
  selected-profile pin loaded in deterministic Pack-name order from the
  content-addressed store. Missing, unsafe, untrusted, revoked, mismatched, or
  colliding configured Packs fail the complete registry rather than silently
  disappearing. Export and file-import ports therefore see installed
  trusted-community components without a provider-specific branch.
- official pins now require exact historical authorization by catalog
  sequence, artifact identity, and delegated signer. Expired catalog metadata
  preserves that offline proof, while remembered revocations dominate. A
  build without a compiled official root treats official authority as
  unavailable and refuses both official pins and pre-existing catalog state;
  it never treats absence as an empty revocation set.
- production now compiles the published generation-zero Ed25519 catalog root,
  and the repository ships canonical sequence-2 metadata plus its detached
  signature and digest-named official connector archive. The private root is
  held outside Git; the maintainer tool rejects unsafe custody, stale sequence,
  expired publication, root mismatch, and revocation loss.
- `lant packs refresh` fetches only fixed bounded HTTPS catalog/signature
  locations, verifies them against the active compiled-root chain, treats the
  exact accepted sequence idempotently, rejects rollback/equivocation/tamper,
  and writes no history in dry-run. Refresh never installs or updates code.
- `lant packs install <name[@version]>` resolves an exact current official
  grant, downloads only its digest-named archive, caches immutable preview
  custody privately, and enters the existing no-default installation
  Interaction. Acceptance reopens and reauthorizes those bytes, then records
  `PinVerifiedOfficial(sequence)` without adding community publisher trust.
- `lant packs updates` compares preferred pins with the accepted signed
  catalog using complete SemVer precedence. It is a sparse read-only discovery
  surface: it neither performs network access nor changes profile or Pack
  state.
- every live ProviderAccount carries the exact Pack pin that established its
  provider contract. The runtime registry exposes a collision-checked
  preferred component view for new work and a second exact-artifact view for
  existing bindings. Referenced older archives are reauthenticated and
  reauthorized on every load, so changing the preferred release cannot
  silently upgrade an account and missing, revoked, or untrusted retained
  authority fails closed.
- `lant packs update` now turns either the newest accepted official release or
  one local trusted-publisher archive into a persisted no-default UX-PACK01
  plan. The preview records exact archive custody, semantic component and
  authority changes, and every affected binding disposition. Acceptance
  reopens both releases and recomputes the plan; profile or byte drift returns
  to fresh review. Compatible static accounts may rebind, while OAuth,
  schema/contract drift, removed credentials, and nonterminal effects retain
  the old exact pin. Candidate publication and one compare-and-swap profile
  update leave old archives and historical provenance intact.
- `lant packs list` and exact-name `lant packs show` now expose one sparse,
  typed `little-ant/packs@1` projection. It includes display and signed
  identities, trust/status, full signer and archive digests, enabled component
  state, and declared HTTP/credential/effect/host authority without Pack
  payload bytes.
- a configured Pack failure no longer prevents the recovery command that must
  explain it. Production retains the exact registry problem, denies every
  import/export adapter before invocation, and keeps Pack-free canonical work
  available. The read-only manager structurally inspects each pin and renders
  missing, corrupt, revoked, untrusted, or colliding registry state as
  unavailable rather than granting partial execution.
- `lant packs remove <pack>` now previews one exact reference plan and removes
  only the selected profile's preferred pin. Exact ProviderAccounts and
  accepted import manifests remain valid; component-only live authority blocks
  removal rather than being silently rebound or paused. `lant packs gc` is the
  separate global byte-reclamation consent: it scans every profile, retains
  exact live/effect/provenance custody, reauthenticates candidates under the
  shared store lock, and deletes only an unchanged reviewed set. Dry-run,
  stale-profile refresh, dumb `/packs` navigation, and cross-profile retention
  are covered by the S09 administration suite.
- `lant packs trust <key-file>` and `lant packs install <archive>` now use the
  shared persisted Interaction contract. Community trust shows the complete
  validated fingerprint and returns to a still-unapproved installation
  preview; installation shows every component kind and declared host,
  credential, effect, and local-UI authority with no Enter default.
- pending consent retains no archive or key bytes. Acceptance safely reopens
  and authenticates the exact file, rejects byte drift, refreshes without
  carrying yes across profile drift, and compare-and-swaps the profile under
  an exclusive lock. Archive publication precedes the exact pin, so a lost
  race leaves only collectable content-addressed bytes. Dry-run persists none
  of the checkpoint, trust, archive, or pin.
- `/packs` is now reachable from ordinary idle, Focus, Raw-review, checklist,
  and result palettes. Its dumb REPL manager lists and inspects the sparse core
  projection, accepts an official name or local archive/key path, and then
  hands off unchanged to the canonical trust/install envelopes. Enter only
  inspects; explicit `[r]efresh catalog`, trust, and install retain distinct
  shortcuts. Accepted catalog/profile changes rebuild the long-running REPL
  environment before another adapter can run.
- `lant config connect microsoft_todo --account <name> --client-id <public-id>`
  now opens a sealed, no-default preview of the exact installed Pack, public
  client identity, account, credential slot, and signed scopes. Connection is
  typed configuration rather than a second import grammar and adopts no source
  data.
- acceptance reopens and revalidates the profile and signed Pack before any
  provider request. A locked vault fails before OAuth starts and leaves the
  same preview usable; Device Authorization state and codes remain transient,
  while successful tokens enter the encrypted vault before the account and
  binding are compare-and-swapped into `integrations.yaml`.
- production source discovery now treats optional connectors as optional for a
  clean profile, but fails a configured provider route closed when its account,
  binding, Pack, or credential authority is invalid. Import failures remain
  separate from Pack-manager health. After restart, a connected Microsoft To
  Do account is exposed through the ordinary snapshot/synchronize/migrate
  ImportPort.
- `/import` is now available from ordinary interaction palettes and opens one
  searchable dumb source selector. File sources collect a local path before
  presenting only their declared modes; configured provider accounts appear as
  exact labeled choices, with `adapter@account` references retained when more
  than one account exists.
- an installed online source without an account appears as `connect...` rather
  than importable. The REPL collects the lowercase account key, optional human
  label, and public client ID when the signed authorization requires one, then
  delegates to the canonical no-default provider connection envelope. Success
  rebuilds the production environment and returns to that exact account's
  no-default mode screen. It transfers no consent and runs neither preflight
  nor import automatically.
- a signed provider component with exactly one otherwise-unclaimed
  `bearer_token` or `api_key` slot can use the same connection envelope without
  inventing OAuth. The preview contains exact Pack/slot/scheme authority but no
  secret and omits inapplicable client-ID/scope fields. Only after acceptance
  and an unlocked Vault does the CLI open echo-disabled input or the Vty REPL
  open its masked editor. The host wipes the transient bytes, persists the
  credential before typed profile configuration, and never exposes it to Pack,
  checkpoint, event, JSON, YAML, transcript, or diagnostics.
- canonical import acceptance now consumes the common signed SourceAdapter
  materialization contract rather than an adapter-name whitelist. The real
  Microsoft To Do Pack and broker can therefore preserve its complete
  structured task response as Raw truth through the ordinary application
  consent, with stable SourceBinding and ImportInvocation custody. Exact retry
  remains event-free.
- provider preflight normalizes even a convenient single-account selector to
  the durable `adapter@account` reference. An account added later cannot
  reinterpret an existing ImportProfile; TaskJuggler actuals retain their
  independent semantic validation on top of the generic material contract.

## Last green gate

The most recent full commands were:

    make format-check
    cabal check
    cabal test all --test-show-details=never
    ./test/e2e/s01-cli.sh
    python3 -m unittest discover -s test/conformance -t .
    python3 tools/lant_conformance.py audit
    python3 tools/lant_conformance.py vocabulary
    cabal exec runghc -- -XGHC2021 -XDerivingStrategies -XLambdaCase -XOverloadedStrings -isrc tools/rebuild-standard-pack.hs verify
    cabal exec runghc -- -XGHC2021 -XDerivingStrategies -XLambdaCase -XOverloadedStrings -isrc tools/rebuild-official-connectors-pack.hs verify
    nix build path:.#little-ant

Every Haskell test suite, all 16 conformance tests, the canonical-ID audit, the
public-vocabulary guard, and explicit formatting checks pass at this
checkpoint. The targeted S09 source suite has 22 passing
source/translation/diagnostic/repair tests, including both cutover crash phases
and the public no-default consent flow. The new S09 export suite has 7 passing
tests for deterministic projections, stdout, dry-run, exclusive publication,
pre-invocation target rejection, exporter failure, and registry compatibility.
The structural, authority, store, registry, and catalog Pack suite has 23 passing tests
for reproducible archives, JCS, closed schemas, component permission
isolation, path ownership, payload integrity, canonical ZIP mutation
rejection, Unicode path safety,
exact Ed25519 authentication, trust precedence, official-catalog expiry,
community untrust, pin confinement, release equivocation, private/idempotent
publication, tamper and symlink rejection, registry confinement, typed profile
round-trips, catalog sequence/expiry, monotonic revocation, dual-signed root
rotation, and private replayable catalog state. The full
build, every Haskell suite, the isolated CLI end-to-end test, and formatting
pass. Targeted HLint review found only the documented repository baseline after
the newly introduced hint was corrected. The CLI test now isolates all four
XDG roots, so a developer's real profile cannot contaminate it. The aggregate
`make ci` gate remains red only at the repository-wide HLint baseline; those
pre-existing hints are outside this milestone and S09 remains in progress.
The isolated-runner suite now has 11 process-boundary cases, including closed
host-custodied source preflight, consent-gated materialization,
unsupported-mode rejection, adaptive fake-provider paging, route denial before
broker invocation, and repeated-request cycle prevention. The standard-Pack
suite now has 10 archive/authority/golden-format/TaskJuggler/source cases, the pure
planning suite has 4 cut/custody/profile/remaining-evidence cases, and the dedicated actuals suite
has 7 strict custody/acceptance/replay cases. The CLI test exercises
CSV, TaskJuggler export, and TaskJuggler actuals preflight through the
production environment. A clean
`nix build path:.#little-ant` passes all Cabal suites, installs the private
runner under `libexec/little-ant`, carries the signed archive in the Cabal data
output, and supplies `tj3` to its isolated contract test. The installed
`lant export taskjuggler` output from an empty XDG profile also passes
`tj3 --check-syntax --no-reports`.
The final source distribution metadata also passes `cabal check` without
warnings.
The dedicated S09 import suite has 12 deterministic application cases covering
read-only preview, canonical custody, exact retry, Pack-upgrade reuse, changed
file snapshots, stable-identity conflict, stale-preview regeneration,
unsupported authority, dry-run, atomic multiobject preservation, and
materialization drift before mutation. It also proves exact remote-container
selection, event-free scope reuse, explicit profile revision, and immutable
per-invocation scope. The CLI E2E also rejects omitted modes
and the removed `--mode` form while proving explicit snapshot previews record
no events, recognizes repeated `--container` flags while refusing them for a
file source, and covers a compressed Notesnook-shaped ZIP. It also selects
Markdown and Evernote ENEX by file suffix, exposes the exact media type, and
keeps both preflights read-only.
The dedicated official-connectors suite has 13 cases covering exact archive
reconstruction and official trust, least-authority manifest permissions,
adaptive Microsoft Graph list/task pagination, canonical provider identity and
URL encoding, sparse-preview privacy, complete structured-Raw materialization,
completed-task opt-in, guarded partial attachment migration, and denial of a
provider-controlled `nextLink` before a second broker call. It additionally
covers Google Tasks pagination with encoded opaque tokens, explicit
completed/hidden inclusion, complete structured Raw, exact item cleanup,
default-list protection, and verified empty custom-list cleanup.
It also proves that Google Calendar discovery observes no events, a scoped
read preserves exact selected event truth, and an absent selected calendar is
rejected. GitHub coverage proves bounded page-number pagination, pull-request
omission, sparse-body privacy, complete structured Raw materialization, stable
repository/issue identity, and explicit closed-issue inclusion.
The dedicated provider-host suite has 19 cases covering typed integration-state
round trips, secret-key rejection, closed OAuth token custody and expiry,
credential injection after authorization only, transcript privacy, locked-vault
short-circuiting, multi-account references, signed slot/scheme matching, and
defense-in-depth route checks before credential resolution. Cleanup simulations
cover partial item failure and safe retry, lost responses reconciled as absent,
restart from durable dispatch intent, authority drift before DELETE, exact-set
rejection, and an unknowable result requiring a new duplicate-risk revision and
approval. The suite also verifies
Container simulations additionally cover separate empty-list approval,
nonempty refusal, a list gaining an item before dispatch, and a lost list
DELETE reconciled without repeating deletion. The suite also verifies that
multiple configured accounts remain separate, human-labeled catalog rows
with exact source references. Its full application path accepts one verified
Microsoft To Do task as structured Raw truth and proves an exact retry is
event-free.
The S08 responsibility suite now also proves that payload revision and record
version are distinct, one approval grant covers only its exact finite effect
set, dispatch requires that durable grant, and provider receipts cannot appear
before durable dispatch intent.
The dedicated Pack-administration suite has 29 focused cases for exact
built-in list/detail projection, sparse read-only recovery, the complete
community trust/install journey, separate standalone publisher trust,
no-default previews, dry-run custody, closed canonical key transport,
archive-byte invalidation, profile-drift regeneration, and locked profile
compare-and-swap. It also covers the public provider-connection preview,
locked-vault recovery before network access, transient Device Authorization,
typed account/binding persistence, production import-source discovery, the
installed-but-unconfigured source selector, exact connected-account return,
and the no-default mode projection. Read-only update discovery selects the
newest exact signed release with SemVer rather than lexical ordering, emits a
sparse machine projection, performs no network request, and changes neither
profile nor canonical state.
The reviewed update paths cover keep-current, applied side-by-side replacement,
selective static/OAuth rebinding, dry-run isolation, profile-plan regeneration,
and candidate-byte invalidation.
The suite proves the dumb `/packs` manager's bounded rendering,
ordinary-palette reachability, official-name/local-path input, explicit catalog
refresh, published-root tamper rejection, dry-run isolation, exact official
pinning, the bounded no-default remote-container selector, and the
`t → t → i` community keyboard consent sequence. Full
milestone gates are recorded immediately before each signed milestone commit.

The provider host now also carries a generic exact-container selection contract.
File and ordinary provider sources reject unexpected scope; scoped providers
reject an empty set with typed `select-containers` recovery before credential or
network access. The Pack runner projects selected container identifiers in
deterministic order, and the host rejects observations that omit a selected
container or return an object outside the allowlist. Google Calendar is the
first shipped scoped provider: its observe-only adapter discovers calendars
without reading events and preserves complete selected event truth. The exact
allowlist is now durable in revisioned `ImportProfile` state, immutable in each
`ImportInvocation`, and carried by the pending preflight envelope. Repeating an
import without `--container` reuses one unambiguous active scope; an explicit
different scope revises that profile without rewriting prior invocations. The
CLI accepts repeated `--container ID`, while the dumb REPL discovers available
containers and presents an arrow-key, Space-toggle, no-default multi-select
screen whose state survives contextual-palette navigation.

## Remaining S08 closure (carried forward from prior checkpoint)

Before marking the slice verified, close these deliberately visible gaps:

- request-not-yet-made must create explicit enabling Work plus its declared
  successor response Wait rather than display educational text only;
- prerequisite, absolute-time, and Place branches from blocked/waiting need
  complete previews instead of falling through to generic recovery copy;
- Wait follow-up, blocker replacement, custom date/time, repeated-follow-up
  strategy, and source-observed resolution need their complete state paths;
- Delegation no-response must honor `once | every | none`, produce a separate
  approval-bearing follow-up when allowed, and use strategy review at the soft
  cap; completion/refusal need full Nature-aware reconciliation;
- proposed-message editing after creation, adapter delivery, effect recovery,
  duplicate-risk retry, and compensation need executable paths;
- add CLI-level tests for profile/config/vault and the missing `vault update`
  surface; tighten secret-memory zeroization limitations where the Haskell
  `Text` representation permits;
- run `make ci`, not only `make test`, before declaring the slice closed.

## Next work

Stop integration breadth. Close the supported dumb daily loop, implement the
bounded real-v0 migration, and pass the alpha promotion gate. Calendar
write-back, local web, assisted surfaces, and remaining closure work are beta
items and do not precede alpha use.

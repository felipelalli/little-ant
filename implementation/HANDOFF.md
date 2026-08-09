# Implementation handoff

Current slice and gate: **S09 — Sources, Packs, imports, and repair; implementation in progress.**
S00-S08 are executable and mostly stable; S08 closure items remain open below.
Coverage labels stay conservative until every required recovery, uncertainty, and paired-surface row is fully evidenced.


Baseline at the start of the current milestone: **a7de5ba**
(`feat(packs): require separate trust and install consent`). The current
milestone exposes that canonical consent path through the dumb REPL's
non-consequential `/packs` manager and refreshes its runtime Pack registry after
accepted profile changes. This file stays editable between milestone commits.

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
  Delegation coverage, immutable external effects, profiles/configuration,
  age-v1 encrypted vaults, and a profile-scoped AF_UNIX vault agent;
- dumb mini-simulations for external-condition Wait activation and manual
  Delegation from skip diagnosis through observed handoff;
- effect edit, defer, reject, approval, durable dispatch intent, and receipt
  transitions, with deferred effects excluded from the forecast.
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
  `taskjuggler` exporters plus the `plain_text` SourceAdapter. The structural
  exporters' reviewed
  fixtures cover hierarchy, quoting, UTF-8 alignment, RFC 4180 framing, and a
  script-free/offline HTML document. The CLI production environment uses this
  registry, so `lant export csv` works without installing a provider Pack.
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
  Do GET route, one OAuth device-authorization credential slot, and separate
  item/container cleanup effect purposes. Lua never receives the OAuth token
  or DELETE authority.
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
- The exact official connector Pack declares Microsoft To Do's device-flow
  authority and `Tasks.Read offline_access`; its archive and signed fixture
  identities were rebuilt reproducibly. Public discovery, connection, and
  import are still gated on publication of the production catalog root,
  official install/refresh, and explicit CLI/REPL orchestration.
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
- no production catalog root is published yet. The official Microsoft To Do
  Pack remains a separately shipped, fully verifiable artifact rather than a
  built-in; public official installation/refresh must publish the real root
  before connection/import orchestration can expose it honestly.
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
  projection, collects local archive/key paths, and then hands off unchanged to
  the canonical trust/install envelopes. Enter only inspects; trust and install
  retain separate no-default shortcuts. Accepted profile changes rebuild the
  long-running REPL environment before another adapter can run.

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
suite now has 8 archive/authority/golden-format/TaskJuggler/source cases, the pure
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
The dedicated S09 import suite has 11 deterministic application cases covering
read-only preview, canonical custody, exact retry, Pack-upgrade reuse, changed
file snapshots, stable-identity conflict, stale-preview regeneration,
unsupported authority, dry-run, atomic multiobject preservation, and
materialization drift before mutation. The CLI E2E also rejects omitted modes
and the removed `--mode` form while proving explicit snapshot previews record
no events, including for a compressed Notesnook-shaped ZIP.
The dedicated official-connectors suite has 5 cases covering exact archive
reconstruction and official trust, least-authority manifest permissions,
adaptive Microsoft Graph list/task pagination, canonical provider identity and
URL encoding, sparse-preview privacy, complete structured-Raw materialization,
completed-task opt-in, guarded partial attachment migration, and denial of a
provider-controlled `nextLink` before a second broker call.
The dedicated provider-host suite has 7 cases covering typed integration-state
round trips, secret-key rejection, closed OAuth token custody and expiry,
credential injection after authorization only, transcript privacy, locked-vault
short-circuiting, multi-account references, signed slot/scheme matching, and
defense-in-depth route checks before credential resolution.
The dedicated Pack-administration suite has 13 focused cases for exact
built-in list/detail projection, sparse read-only recovery, the complete
community trust/install journey, separate standalone publisher trust,
no-default previews, dry-run custody, closed canonical key transport,
archive-byte invalidation, profile-drift regeneration, and locked profile
compare-and-swap. It also proves the dumb `/packs` manager's bounded rendering,
ordinary-palette reachability, local path editors, and the exact `t → t → i`
keyboard consent sequence. Full milestone gates are recorded immediately
before each signed milestone commit.

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

Finish S09 from [`slices/09-sources-packs-and-adapters.md`](slices/09-sources-packs-and-adapters.md) before continuing to S10.
Next, publish the real official root/catalog and implement explicit
refresh/update/remove/GC, and expose Microsoft account connection plus
snapshot/synchronize/migrate orchestration. Cleanup remains a separately
previewed effect. Google Calendar, remaining standard importers, and the local
web UIAdapter remain. The complete S09 gate still precedes `verified`.

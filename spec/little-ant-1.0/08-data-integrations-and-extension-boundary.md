# 8. Data, integrations, and extension boundary

## Authority and replay

- **DAT-001 [core] — Append-only authority.** Versioned domain events are the
  authoritative operational history. Current state is a deterministic fold
  after every event passes through its version boundary.
- **DAT-002 [core] — Canonical material completeness.** Raw snapshot bytes and
  required blob metadata are part of the logical dataset even when physically
  stored outside the event stream.
- **DAT-003 [core] — Rebuildable projections.** Databases, search indexes,
  caches, rendered views, forecasts, and status summaries are disposable and
  reproducible from canonical data.
- **DAT-004 [core] — UI checkpoints are separate.** Surface checkpoints recover
  presentation only. They never become the source of a comparison, Brick
  field, completion, or other domain answer.
- **DAT-005 [core] — Pack-free replay.** Replaying accepted events never runs a
  Pack, model, provider, exporter, or external effect.
- **DAT-044 [core] — Observable replay progress is factual.** The canonical
  loader may report the number of JSONL event records successfully decoded and
  folded during the current load. Progress is monotonic, derived from the same
  read that builds state, and cannot require a preliminary counting pass or
  mutate the dataset. If an efficiently known total is unavailable, the
  interface reports only the processed count. Blank or malformed physical
  lines are not reported as accepted events; corruption follows the typed
  recovery policy rather than being skipped to inflate progress.
- **DAT-045 [core] — Sprint clocks have sparse canonical evidence.** An
  accepted sprint records one canonical start fact with its Brick, duration,
  target instant, origin, and effective configuration. It records exactly one
  terminal outcome such as elapsed, completed early, paused, skipped, or
  displaced by a focus switch. Rendering a changing countdown creates no
  per-second events and does not mutate canonical state. Replay derives the
  same target and outcome from the recorded clock facts; a duration or elapsed
  target alone is never evidence of observed work or progress.

## Structured responses and context control

- **DAT-006 [core] — Typed sparse default.** Ordinary commands return a
  command-specific typed result and canonical human rendering, not a complete
  entity and raw event list by default.
- **DAT-007 [core] — Observable postcondition.** A mutator returns enough
  compact identity, revision, changed aspects, spawned work, notices, pending
  effects, and next interaction to establish its outcome without a mandatory
  follow-up query. In a technical JSON projection, `id` is the canonical
  UUIDv7 string and a human `handle`, when the record kind has one, is a
  separate field. UUID-bearing relation fields never substitute or persist a
  display handle.
- **DAT-008 [core] — Schema-owned omission.** Optional inapplicable values and
  unrelated empty collections may be omitted. Meaningful `false`, zero,
  requested empty collections, tri-state values, and explicit clearing remain
  visible according to the projection schema.
- **DAT-009 [core] — Explicit depth.** Summary, operational detail,
  relationship, history, and complete projections expose progressively more
  context without changing semantic state.
- **DAT-010 [core] — Actionable facts cannot hide.** Sparse output never hides
  a newly actionable blocker, notice, external effect, error recovery, or
  interaction solely inside omitted event payloads.

## External sources and imports

- **DAT-011 [standard] — Feeding versus adoption.** Reading an external object,
  preserving it as Raw, adopting it as a Brick/ListEntry, reconciling it, and
  changing the source are distinct decisions.
- **DAT-012 [standard] — Stable source identity.** An ImportProfile owns
  provider/account scope and maps each external identity idempotently to at
  most one canonical adoption.
- **DAT-013 [standard] — External presence is not work state.** A missing
  provider object does not imply `done`, `archived`, or erased local work.
  Source observation and canonical work status remain independent.
- **DAT-014 [standard] — Synchronize versus migrate.** Synchronization keeps
  observing the source. Migration imports, verifies, cuts over, and may then
  propose source cleanup. The mode is explicit and inspectable.
- **DAT-015 [standard] — Notes require triage.** Mixed note systems such as
  Notesnook and Evernote preserve candidates as Raw unless a powered-up model,
  operator skill, or explicit human route adopts them. Dumb mode never guesses
  note-shaped work.
- **DAT-016 [standard] — Source cleanup is an effect.** An
  `erase-after-import` workflow previews exact objects, requires approval only
  after canonical verification, applies idempotently through the adapter, and
  records receipts and failures. Deleting an empty source container is a
  separate approval.
- **DAT-017 [standard] — Partial failure is recoverable.** Successfully
  imported canonical objects remain valid if provider deletion fails; cleanup
  becomes retryable and never rolls back or marks the Brick complete.
The 1.0 adapter catalog covers these common sources through the standard Pack
or official connector Pack:

```text
Microsoft To Do
Apple Reminders
Google Tasks
Google Calendar
GitHub Issues
Notesnook
Evernote
```

Exact modes, cleanup capability, and shipping placement are closed in the
[standard integration catalog](standard-integration-catalog.md). A source
name never implies live sync or destructive cleanup when its platform cannot
support them honestly.

## Little Ant Packs

- **DAT-018 [standard] — Typed distribution.** `Little Ant Pack` is the only
  installable extension concept. Each component implements exactly one closed
  versioned host contract.
- **DAT-019 [standard] — Component kinds.**

  ```text
  BrickNature | BrickTemplate | ImportProfilePreset
  SourceAdapter | ReadOnlyExporter | UIAdapter
  ```

  The first three are declarative. The last three execute as bounded Lua
  components.

  Version 1.0 has no generic executable `Enricher`: revising or deriving Raw,
  reconciling a source, and accepting an assisted proposal remain their
  existing typed flows rather than an extension hook.

- **DAT-020 [standard] — No generic plugins.** Packs cannot add lifecycle
  hooks, entities, events, selection algorithms, storage engines, commands,
  aliases, background threads, or replay logic.
- **DAT-021 [standard] — Lua boundary.** Lua 5.4 is the only first-class
  executable Pack language. Every standard or community invocation runs in a
  separate `lant-pack-runner` process with a fresh HsLua VM, resource limits,
  schema validation, and no unrestricted `io`, `os`, sockets, debug, dynamic C
  modules, or subprocesses.
- **DAT-022 [standard] — Host-brokered HTTP.** Lua uses only
  `lant.http.request`. The host owns TLS, exact allowed hosts, redirects,
  timeouts, rate limits, body limits, JSON, retries, cancellation, credential
  injection, and redaction.
- **DAT-023 [standard] — Invocation provenance.** Accepted external input
  records component, Pack and contract versions, content hash, input revision,
  permissions, and attributable result without making Pack code replay
  authority.

## Credentials

- **DAT-024 [standard] — Local encrypted vault.** Credentials live in a
  Little-Ant-owned encrypted local vault and memory agent, outside Packs,
  domain events, ordinary dataset synchronization, and rebuildable
  projections.
- **DAT-025 [standard] — Local binding.** A CredentialBinding maps a manifest
  slot and account to local secret material. Lua receives a binding name and
  redacted response, never stored or refreshed tokens.
- **DAT-026 [standard] — Typed schemes.** Initial schemes are OAuth 2.0
  authorization code with PKCE, device authorization, bearer/API key, and no
  authentication.
- **DAT-027 [standard] — Locked is not failed.** A due credential-dependent
  check remains due while the vault is locked and does not advance provider
  failure backoff.
- **DAT-057 [standard] — Configuration uses separate typed XDG files.** On
  Unix-like systems, one named profile resolves these paths:

  ```text
  $XDG_CONFIG_HOME/lant/selection.yaml
  $XDG_CONFIG_HOME/lant/profiles/<name>/profile.yaml
  $XDG_CONFIG_HOME/lant/profiles/<name>/preferences.yaml
  $XDG_CONFIG_HOME/lant/profiles/<name>/calibration.yaml
  $XDG_CONFIG_HOME/lant/profiles/<name>/integrations.yaml
  $XDG_DATA_HOME/lant/vaults/<name>.age
  $XDG_STATE_HOME/lant/profiles/<name>/
  $XDG_RUNTIME_DIR/lant/<name>/vault.sock
  ```

  The ordinary XDG fallbacks apply when an environment variable is absent.
  Configuration, data, persistent UI state, and runtime IPC therefore do not
  share one directory. Parent directories are private to the user. Other
  platforms use their native per-user configuration, data, state, and runtime
  equivalents and expose the resolved paths through `/config paths`.
- **DAT-058 [standard] — Each file owns one schema.** `profile.yaml` uses
  `little-ant/profile@1` and contains only dataset location plus explicit
  references to the other three YAML files and one vault name.
  `preferences.yaml` uses `little-ant/preferences@1` and contains presentation
  language, color/emoji modes, editor argv, powered-up argv, and other
  presentation conveniences. `calibration.yaml` uses
  `little-ant/calibration@1` and contains only CAL-001 parameters.
  `integrations.yaml` uses `little-ant/integrations@1` and contains installed
  component pins, provider accounts, CredentialBinding names,
  DeliveryBindings, and explicitly trusted community publisher public keys.
  Verified official-catalog metadata and last accepted sequence live under the
  profile state directory; the compiled official root is not YAML.
  Operational ImportProfiles and SourceBindings remain canonical dataset
  records rather than configuration. `selection.yaml` uses
  `little-ant/profile-selection@1` and contains only one selected profile name.
  Unknown keys are errors. No YAML file accepts secret values or arbitrary
  adapter configuration outside its component schema.
- **DAT-059 [standard] — Profile selection is explicit and non-merging.** The
  selected profile is, in order, the CLI `--profile <name>`, `LANT_PROFILE`,
  DAT-058's selection file, or literal `default`. `/profile use <name>` writes
  only that selection file for future starts; the resolved name remains visible
  in `/config paths` and technical output. Files from two profiles are never
  deep-merged. Skill, powered-up, REPL, and first-party clients query the
  resolved typed configuration through the CLI/protocol rather than parsing
  YAML independently. Canonical English remains unchanged when a presentation
  preference requests translated wrapper text.
- **DAT-060 [standard] — Bindings are references, not secrets.** A
  CredentialBinding maps a component-declared credential slot and provider
  account to one opaque vault-entry UUID. A DeliveryBinding follows MOD-092.
  Config inspection and diagnostics render only binding name, scheme,
  component/account, purposes, readiness, and redacted last four characters
  when the scheme defines them. Moving or copying an integration manifest
  without its vault yields `unbound`, not an authentication failure or a
  copied secret.
- **DAT-061 [standard] — Vault 1 uses the age v1 passphrase format.** The file
  at DAT-057's vault path is one binary `age-encryption.org/v1` file with its
  sole native `scrypt` recipient stanza. New and rotated v1 vaults use a fresh
  16-byte salt, work factor `2^18`, `r = 8`, `p = 1`, and the age v1
  ChaCha20-Poly1305 wrapping and payload construction. The authenticated
  plaintext is canonical UTF-8 JSON with schema `little-ant/vault@1`, vault
  UUID, monotonically increasing revision, and UUID-keyed typed secret
  entries. Passphrases are consumed as entered UTF-8 bytes without trimming or
  normalization. The implementation uses a reviewed age-format library, not
  a shell command or a Little-Ant-specific cipher construction.
- **DAT-062 [standard] — Vault writes are whole-file and atomic.** Creating,
  changing, or deleting an entry decrypts in trusted memory, validates the
  complete next plaintext, and writes a freshly encrypted age file to a new
  same-directory inode with mode `0600`; file and directory are synchronized
  before atomic replacement. Failure preserves the prior file. Rotation uses
  a fresh file key, salt, and payload nonce and verifies the replacement before
  cutover. The vault never joins dataset JSONL, sync, history, Pack input,
  crash dumps, debug output, or general backups.
- **DAT-063 [standard] — Recovery is honest, not escrow.** Vault creation asks
  for and confirms one nonempty passphrase through no-echo input, then requires
  the user to create or explicitly decline an encrypted backup. `/vault backup`
  verifies the current ciphertext before copying that ciphertext—never
  plaintext—to an explicit destination. The same passphrase unlocks it. There
  is no server escrow, reset link, hidden recovery key, or bypass: losing the
  passphrase and every unlocked session loses the credentials, while canonical
  Little Ant data remains intact and integrations can be reconnected. A
  passphrase change is DAT-062 rotation; provider-secret rotation is a separate
  adapter-specific reviewed effect.
- **DAT-064 [standard] — One memory agent owns each unlocked profile.** The
  first trusted host that needs a credential starts or connects to one
  profile-scoped agent. On Unix it uses DAT-057's AF_UNIX socket inside a
  `0700` runtime directory; the socket is `0600`, peer UID is checked, and the
  protocol is length-delimited, schema-versioned, size-bounded, and rejects
  unknown operations. The agent exposes only lock/unlock, redacted inventory,
  typed entry mutation, and resolution of a named CredentialBinding to the
  trusted host. It offers no arbitrary file decrypt/encrypt primitive and no
  Pack/UIAdapter connection. Explicit `/vault lock`, agent shutdown, logout,
  or the configured idle timeout clears decrypted entries and keys with
  best-effort locked memory and zeroization.
- **DAT-065 [standard] — Secret use has a narrow trusted path.** The canonical
  host resolves a binding only while executing the exact host-brokered HTTP or
  external-effect request that declared the credential slot. It injects the
  secret after Pack output validation, never returns it to Lua, and redacts
  request headers, URLs, bodies, errors, receipts, and traces according to the
  component manifest. OAuth authorization and refresh happen in the trusted
  host/agent boundary; refresh-token replacement is an atomic vault mutation.
  Secrets are never accepted in command arguments, environment variables,
  YAML, ordinary stdin, or InteractionEnvelopes. Dedicated no-echo unlock and
  authorization-code inputs are the only interactive secret inputs.
- **DAT-066 [standard] — Locked state preserves the interrupted intention.** A
  credentialed route encountering a locked vault renders UX-VLT00. Unlock uses
  no-echo input and, on success, returns to the exact still-unapproved preview;
  it never retries, sends, syncs, or approves automatically. Choosing another
  method or later follows the owning flow. Failure reveals no distinction
  between wrong passphrase and corrupt authentication until explicit
  `/vault diagnose`; provider backoff and source cursors do not advance.
- **DAT-067 [standard] — The security boundary is stated plainly.** The vault
  protects secrets at rest, from accidental dataset/configuration sharing,
  from Packs, and from unprivileged OS users. It does not claim to resist a
  compromised process running as the same OS user, a debugger attached to the
  trusted host or agent, kernel compromise, terminal capture during unlock,
  or rollback to an older whole vault file. Diagnostics warn about unsafe
  permissions, symlinks, unsupported age headers, excessive KDF work factors,
  and revision rollback observed against local state; they never weaken or
  silently repair authentication.

DAT-057 follows the
[XDG Base Directory Specification 0.8](https://specifications.freedesktop.org/basedir/).
DAT-061 is a constrained use of the reviewed
[age v1 file format](https://age-encryption.org/v1), including its native
scrypt stanza and authenticated streaming payload; Little Ant does not fork
that cryptographic format.

## Exporters and UI adapters

- **DAT-028 [standard] — Read-only exporter.** An exporter receives a named
  versioned projection and returns bytes, media type, filename, warnings, and
  metadata. Writing, publishing, or invoking another program is a separate
  surface or effect.
- **DAT-092 [standard] — Export destinations remain host-owned.** Pack code
  receives projection data and returns bytes; it never receives an output path
  or filesystem capability. The trusted `lant export` host writes to stdout by
  default or exclusively creates one new regular file requested by
  `--output`. Existing paths, symlinks, missing parents, and nonregular targets
  fail before exporter invocation. Version 1.0 has no overwrite, publish,
  automatic-open, or arbitrary-output effect.
- **DAT-093 [standard] — Profile creation cannot escape its roots.** A profile
  name is lowercase ASCII matching `[a-z0-9][a-z0-9-]{0,31}`; `default` is an
  ordinary valid name. Creation resolves every DAT-057 path first, rejects an
  existing name, symlink, non-directory parent, or path outside the resolved
  XDG roots, then atomically creates private directories and the four minimal
  typed YAML files. It points at a newly created empty dataset unless the
  reviewed command explicitly selects an existing verified dataset. It never
  copies another profile, imports data, creates credentials, or selects the
  new profile implicitly. Version 1.0 has no profile-removal operation.
- **DAT-029 [standard] — Standard structural formats.** The standard Pack
  ships tree text, aligned table, RFC 4180 CSV, Org, and self-contained HTML
  exporters.
- **DAT-030 [standard] — TaskJuggler reference.** The standard Pack ships a Lua
  TaskJuggler exporter with source, fixtures, contract tests, failure examples,
  and an authoring guide. The core owns effort semantics, planning cut,
  projection validation, stable IDs, and immutable manifest; Lua owns `.tjp`
  serialization.
- **DAT-031 [standard] — Actuals import.** Importing TaskJuggler actuals uses a
  separate SourceAdapter with explicit manifest identity, preview, and
  confirmation. Actuals never rewrite estimates.
- **DAT-032 [standard] — UIAdapter.** A UIAdapter renders the canonical
  envelope and maps a channel response to exactly one action ID and displayed
  revision. It cannot invent semantics, weaken approval, claim authority, or
  retain credentials. Like the REPL, Skill, local-web host, and any future
  conforming mobile host,
  it invokes the canonical CLI/protocol dispatcher rather than another
  presentation surface.
- **DAT-046 [standard] — External text editors are host-mediated.** A
  first-party surface host, or a host explicitly serving a UIAdapter, may
  transport one pending text draft through UX-162. Executable Pack code never
  receives subprocess, filesystem-path, environment, or temporary-file
  authority: it can render or select the declared action only. Imported bytes
  return as an ordinary pending interaction action bound to the displayed
  revision and pass through the canonical preview. Editor launch, failure,
  cleanup, and local draft recovery are presentation operations and emit no
  domain event.
- **DAT-033 [standard] — Standard and community catalogs.** A standard offline
  Pack ships with 1.0. A separate `little-ant-packs` repository may distribute
  a broader inspectable community catalog without becoming domain authority.
- **DAT-074 [standard] — The shipping catalog is closed.** The
  [standard integration catalog](standard-integration-catalog.md) is the exact
  1.0 distribution and capability matrix. The offline standard Pack contains
  file importers, standard exporters, declarative factory content, the Apple
  Reminders export kit, and `local_web`. The official connector Pack contains
  Microsoft To Do, Google Tasks, Google Calendar, and GitHub Issues adapters.
  Provider credentials are requested only when a connector is configured.
- **DAT-075 [standard] — Local web mirrors; it does not reinterpret.** The
  shipped `local_web` UIAdapter is served by a first-party host on loopback
  only. It carries the same action IDs, revisions, wording, ordering, approval
  boundaries, and recovery paths as the accepted dumb envelope. An
  unguessable per-session token and origin checks protect the local endpoint;
  provider credentials never enter browser or Lua state. Remote binding and
  remote-channel UIAdapters are not 1.0 release promises.

- **DAT-086 [standard] — One reproducible archive format.** The exact ZIP32,
  JCS manifest, Ed25519 signature, path, size, digest, and limit rules live in
  [Pack format and trust](pack-format-and-trust.md). The host verifies the
  complete archive before extraction or Lua startup. Pack identity is
  publisher, reverse-DNS name, SemVer, manifest digest, and archive digest;
  a reused version with different bytes is rejected as equivocation.
- **DAT-087 [standard] — Trust is explicit and local.** The only trust classes
  are `built in`, `verified official`, `trusted publisher`, `untrusted`, and
  `revoked`. Official trust descends from the root embedded in the binary and
  its signed catalog. A community publisher key requires a separate local
  fingerprint approval. Unsigned and revoked archives never execute. Trusting
  a signer does not approve a Pack's permissions or future updates.
- **DAT-088 [standard] — Revocation stops code, not data.** Explicit catalog
  refresh from `/packs` or `lant packs refresh` may accept only newer,
  unexpired, root-signed catalog
  metadata. A known revoked signer or digest immediately disables affected
  executable components and effects without deleting canonical data,
  SourceBindings, provenance, or archives. Pack-free replay and inspection
  remain available. Expired metadata blocks new official installs/updates but
  does not break an already pinned non-revoked Pack offline.
- **DAT-089 [standard] — No dependency solver exists.** Packs cannot depend on
  other Packs, run installation hooks, or fetch executable code. Lua libraries
  are vendored under one declared component root and signed like every other
  payload. Compatibility names exact core/component contract majors; SemVer
  ranges never substitute for a content digest or permission review.
- **DAT-090 [standard] — Installation and update never happen in the
  background.** The `/packs` manager and `lant packs install|update` verify to the
  content-addressed store, then preview trust, exact versions/digests,
  components, permissions, configuration changes, and affected bindings before
  changing a profile pin. Updates remain side by side. Existing bindings use
  their pinned version until the same preview explicitly rebinds them.
  The updates view is read-only and there is no automatic update timer.
- **DAT-091 [standard] — Removal preserves meaning.** Removing a Pack through
  `/packs` or `lant packs remove`
  deactivates a profile pin only after every affected binding, pending effect,
  and UIAdapter is re-bound, paused, rejected, or explicitly left unavailable.
  Existing Brick Nature snapshots and historical provenance remain valid.
  Explicit `lant packs gc` removes only unreferenced archives after an exact byte
  preview; no ordinary startup, update, or uninstall runs garbage collection.

## Planning reproducibility

- **DAT-034 [standard] — One macro per cut item.** Each effort-bearing item in
  one plan selects exactly one EffortProfile macro, which supplies optimistic,
  realistic, and pessimistic values. Exporters cannot pick unrelated values
  per scenario.
- **DAT-035 [standard] — Non-overlapping planning cut.** The core proposes and
  validates a human-confirmed cut in which no effort-bearing node has an
  effort-bearing ancestor or descendant. A Brick with children may still be a
  leaf of one particular external plan.
- **DAT-036 [standard] — Immutable manifest.** Every confirmed planning run
  records source cursor/hash, roots, cut, EffortProfile, macros and warnings,
  resources/calendars, projection version, and exporter identity/hash required
  for reproduction.
- **DAT-037 [standard] — WIP warning.** Planning uses derived remaining effort
  only when conservative evidence supports it; otherwise it exports total
  effort with an explicit warning rather than inferring progress from time.

## Calendar synchronization

- **DAT-038 [standard] — Official Google Calendar path.** Little Ant 1.0 ships
  an officially maintained Google Calendar `SourceAdapter` in the separately
  installed official connector Pack named by DAT-074. It observes and
  reconciles calendar events into canonical work without requiring a community
  extension; it is not present in the offline standard Pack because it needs a
  provider account and credentials.
- **DAT-039 [standard] — Occurrence identity and exact time.** The adapter uses
  provider, account, calendar, event, series, and recurrence-instance identity
  as applicable, so repeated synchronization updates one canonical adoption
  rather than duplicating it. Exact event intervals retain their IANA time
  zone. All-day events remain distinguishable from exact intervals and are not
  silently classified as `scheduled_commitment`. A cancelled, deleted, or
  inaccessible source event is a source observation, never implicit local
  completion.
- **DAT-040 [standard] — Assisted calendar classification.** Event title and
  structured evidence such as recurrence, interval, organizer, attendees,
  location, and source may support an attributed Skill or powered-up proposal
  for Nature and Template, but private fields participate only when the human
  explicitly exposes them under `DAT-085`; the default projection does not
  inspect attendees, descriptions, conferencing URLs, or attachments.
  Template-owned guidance under `MOD-048` participates in catalog-wide
  discovery; the following cases are illustrative, not a closed recognition
  list. `Flight AD123` may propose
  `scheduled_commitment` with `flight`, and `Quarterly planning meeting` may
  propose `scheduled_commitment` with `meeting`. A recurring `Swimming` event
  may support `habit` with `physical_activity`, while an isolated session may
  remain a `scheduled_commitment`; ambiguous evidence lowers confidence
  instead of hiding the distinction.
- **DAT-041 [core] — No lexical domain rules.** Calendar words and provider
  metadata do not create hard-coded title branches in the deterministic core.
  After source Raw is preserved, assisted triage follows `FED-005` through
  `FED-009` and `FED-029`: the proposed disposition is attributed and
  previewed, `[y]es` accepts it, `[n]o` enters ordinary dumb Raw triage, and
  uncertainty remains explicit.

## External effects

- **DAT-068 [standard] — Effect purposes form a closed catalog.** Little Ant
  1.0 may request only `delegation_delivery`,
  `delegation_take_back_notice`, `source_cleanup_item`,
  `source_cleanup_container`, `calendar_create`, `calendar_update`, and
  `calendar_cancel`. Initial and follow-up Delegation messages share
  `delegation_delivery` with distinct typed reasons. There is no generic
  `write_back`, `notify`, `spawn`, webhook, or arbitrary HTTP effect.
- **DAT-069 [standard] — One immutable revision is the unit of consent.** An
  effect revision records its UUID, purpose, adapter and component version,
  provider account and binding, exact target, redacted human preview, complete
  machine payload digest, originating command and dataset cursor, idempotency
  key when supported, and state. Editing payload, recipient, target, account,
  adapter version, or purpose creates a new revision and requires new human
  approval. Approval never transfers across revisions or effects.
- **DAT-070 [standard] — Dispatch intent is durable before I/O.** The closed
  lifecycle is `proposed | approved | dispatching | succeeded |
  failed_retryable | failed_terminal | outcome_unknown | rejected |
  withdrawn`. The host durably records `dispatching` with the approved digest
  before external I/O and records one redacted receipt afterward. A crash or
  lost response after dispatch begins becomes `outcome_unknown`; it is never
  reported as success or silently retried. Pack code proposes a typed request;
  only the trusted host resolves credentials, verifies approval, performs the
  request, and records the receipt.
- **DAT-071 [standard] — Retry follows provider truth.** A
  `failed_retryable` revision may retry without another approval only when the
  adapter contract guarantees idempotency for the recorded key and the
  approved payload, target, and component version are unchanged. An unknown
  outcome first uses a read-only provider reconciliation when available. If
  truth remains unknowable, dumb mode offers verify externally, retry with an
  explicit duplicate-risk approval, or stop; it never guesses. A terminal
  failure or corrected request requires a new effect revision and approval.
- **DAT-072 [standard] — Batches are bounded sets of item effects.** A cleanup
  or Calendar batch preview names the exact selected count, scope, adapter,
  and irreversible consequences and provides an inspectable item list. One
  approval covers only that finite set and payload revision. Dispatch remains
  itemwise with one state and receipt per item; stopping leaves undispatched
  items approved but pending and never rolls back verified local imports.
- **DAT-073 [core] — Simulation and compensation stay honest.** `--dry-run`,
  replay, exporters, and UI rendering never unlock credentials or dispatch an
  effect. Before `dispatching`, undo may withdraw an effect. After dispatch
  begins, local undo cannot retract the outside world. Delivery and cleanup
  have no 1.0 compensation; a Calendar change may propose a new current-state
  Calendar effect only after fresh observation and ordinary approval, never
  replay a historical inverse blindly.

## Import execution

- **DAT-076 [standard] — Import preflight has one complete preview.** `/import`
  selects a source, account/input, and explicit `snapshot`, `synchronize`, or
  `migrate` mode supported by that adapter. Preflight shows source containers,
  object and attachment counts, skipped/unsupported fields, destination
  profile, duplicate suspicions, RawShelf suggestions, credential needs, and
  whether cleanup is supported. It reads but does not adopt, clean up, or
  change canonical state. A stale preview must be regenerated.
- **DAT-077 [standard] — Local import commits Raw truth first.** Acceptance
  preserves each selected source object as canonical Raw material with stable
  source identity, bytes or normalized structured snapshot, provenance, and
  its source-container relationship. It verifies counts, digests, and identity
  uniqueness before reporting success. Task-shaped items may then enter a
  separate ordinary bulk-adoption preview; note-shaped material remains lazy
  Raw triage. No import silently creates a Domain, importance judgment, local
  done outcome, or source mutation.
- **DAT-078 [standard] — `erase-after-import` means queue a review, not erase
  immediately.** The flag is valid only for a `migrate` adapter whose catalog
  row declares cleanup. It performs local import and verification first, then
  opens the exact item cleanup preview under DAT-068..073. Rejection or exit
  keeps both local data and the source. An unsupported source fails preflight
  before importing and suggests ordinary migration. Container deletion is
  never implied by item cleanup and always has its own later preview.
- **DAT-079 [standard] — Source-specific strength is explicit.** Microsoft To
  Do and Google Tasks support observation plus verified item/container cleanup;
  Google Calendar uses its separate reviewed write-back path; GitHub Issues
  never substitutes close for delete; Apple Reminders uses the standard
  Pack's inspectable Shortcut JSON export; Notesnook uses exported
  Markdown/HTML/plain-text ZIP; and Evernote uses ENEX or HTML. File imports
  retain the input digest and original relative path but have no live presence
  inference.

## Calendar authority and reconciliation

- **DAT-080 [standard] — Calendar authority is allowlisted and observe-first.**
  A Google Calendar ImportProfile selects exact calendars and begins
  `observe_only` with read-only OAuth scope. The human may enable
  `reviewed_writeback` separately per calendar after a scope-change preview;
  there is no automatic write-back mode. Read loss pauses observation without
  changing local Work. Write loss leaves observation usable and effects
  unavailable rather than requesting broader authority silently.
- **DAT-081 [standard] — Adoption follows time meaning, not provider shape.**
  Every event is preserved as source Raw before adoption. One exact timed
  occurrence may become `scheduled_commitment`. An all-day event remains Raw
  or may become ordinary Work with civil-day `not_before`, `best_before`, or
  `deadline`; it cannot become `scheduled_commitment` until the human supplies
  exact endpoints. “This occurrence” and “whole series” are distinct visible
  choices and neither is preselected in dumb mode.
- **DAT-082 [standard] — Recurring Calendar adoption reuses existing Natures.**
  A supported provider series may become a `habit` only when the human accepts
  practice/streak meaning, a `recurring_obligation` with atomic occurrences
  for repeated obligations, or a `recurring_obligation` with exact
  `scheduled_commitment` occurrences for repeated attendance. Whole-series
  adoption is available only when the provider rule maps exactly to WRK-148;
  exceptions retain source identity and explicit reviewed overrides.
  Unsupported RRULEs remain Raw or use separately reviewed finite occurrences.
- **DAT-083 [standard] — Source changes are proposals, never outcomes.** A
  changed event offers accept source locally, keep local, or detach. Keeping a
  local value may then propose a separate Calendar update effect when
  `reviewed_writeback` is available. A cancelled, deleted, or inaccessible
  event offers cancel the local commitment, keep it and detach, or recreate it
  through a separate effect; none means `done`, `attended`, or `missed`.
  Recurring-instance cancellation affects only that occurrence unless a
  separate whole-series preview is explicitly chosen.
- **DAT-084 [standard] — Local edits do not smuggle remote edits.** Creating,
  rescheduling, or cancelling a local source-bound commitment commits the
  validated local change first and may then open one `calendar_create`,
  `calendar_update`, or `calendar_cancel` preview. Rejecting, deferring, or
  failing the effect leaves local truth intact and marks the SourceBinding
  visibly divergent. A successful create attaches the returned provider
  identity; update and cancel receipts advance the accepted baseline.
- **DAT-085 [standard] — Calendar projections minimize private context.**
  Provider account and calendar allowlist are visible. Default Pack,
  powered-up, Skill, history-summary, and UIAdapter projections include only
  title, interval/all-day dates, recurrence shape, calendar label, event
  identity, and redacted location presence needed for the route. Description,
  conferencing URLs, attachments, attendee identities, and attendee responses
  require explicit inspection or per-profile opt-in. Attendees never become
  ExternalEntities or ContactPoints without human adoption.

## Source safety refinements

- **DAT-042 [standard] — Ambiguous absence proves nothing.** A filtered
  response, expired credential, lost permission, provider outage, ambiguous
  `404`, or incomplete page is not authoritative deletion evidence. An
  unexpected mass disappearance pauses automatic reconciliation and returns a
  typed review instead of applying a bulk local outcome.
- **DAT-043 [standard] — Itemwise cleanup truth.** Migration cleanup has one
  verified disposition and durable receipt per selected external object even
  when a provider offers a batch API. Partial progress remains resumable. The
  ImportProfile is retired only after every selected object has a terminal
  cleanup disposition; deleting an external container always requires a
  separate destructive approval.
- **DAT-047 [core] — SourceBinding is the stable external-origin record.** A
  SourceBinding joins one Raw to a source kind, optional ImportProfile UUID,
  stable external identity when supplied, current locator, explicit mode
  (`snapshot | synchronize | migrate`), check policy (`manual | interval`),
  optional positive interval, lifecycle (`active | paused | detached`), and
  accepted reconciliation baseline. A Raw may have several bindings; none is
  silently primary. Changing a locator preserves binding identity only after
  provider identity verifies it or the human explicitly accepts the move.
- **DAT-048 [core] — SourceObservation is immutable and typed.** Every check
  appends observed instant, binding, locator, outcome (`unchanged | changed |
  missing | unreachable | unauthorized | malformed`), provider version or
  fingerprint when available, and optional immutable snapshot digest. A
  changed observation does not become current Raw content or reconciliation
  baseline until FED-056 accepts it. Snapshot bytes are canonical material
  under DAT-002; an adapter cache is not a substitute.
- **DAT-049 [core] — Corrupt canonical material fails locally and loudly.** A
  missing or digest-invalid Raw revision or SourceObservation snapshot places
  that Raw in explicit degraded read-only state and reports the exact record
  and recovery choices. Restoration may use a byte-identical verified backup
  or re-fetch with the same provider fingerprint; different bytes form a new
  observation and require reconciliation. The loader never silently drops,
  rewrites, or substitutes canonical bytes. Unaffected records remain usable
  when their fold does not depend on the damaged material.
- **DAT-050 [standard] — Source schedules are replayable facts.** Interval
  checking derives `next_check_at` from the last terminal observation and the
  accepted positive duration. Pausing, resuming, changing policy, relocating,
  and detaching are explicit events. Detach stops future checking but preserves
  all observations and Raw content. Archive pauses checks; unarchive restores
  the prior policy without inventing a missed observation.
- **DAT-051 [core] — Structured result schemas are named and negotiated.** A
  JSON result declares `schema = little-ant/<result-kind>@1`, `command_id` when
  applicable, and dataset cursor. Clients request one supported major schema;
  omission selects the current v1 major, while an unsupported major fails
  before mutation with the supported set. Result kind, not an all-purpose
  entity object, owns required fields and meaningful defaults.
- **DAT-052 [core] — Projection depth has one public vocabulary.** Technical
  commands accept `--view summary | operational | relationships | history |
  complete`; command-specific sparse output remains the default. `complete`
  means every field declared by that result schema, including requested empty
  collections and meaningful false/zero/null, not every event or linked blob.
  History and blob content still require their explicit projections.
- **DAT-053 [core] — Presence rules are machine-readable.** Each schema marks
  fields as required, optional-omitted, tri-state, meaningful-zero, or
  requested-empty. DAT-008 follows that declaration exactly. Producers may not
  omit `false`, zero, or empty merely to save tokens when the schema says the
  value distinguishes states; consumers may not infer an omitted optional as
  a universal false.
- **DAT-054 [standard] — History filtering is closed and composable.** History
  accepts inclusive `since`, exclusive `until`, subject UUID/reference,
  structural scope, actor, semantic family, relevance, cursor, and positive
  limit. Filters combine with AND; repeated values within one filter combine
  with OR. Results are newest-first for human views, retain canonical log
  positions, and page by opaque cursor without loading unrelated event payloads
  into an operator context.
- **DAT-055 [core] — Corrupt logs stop before evidence loss.** Malformed JSON,
  invalid event schema, unknown event major version, broken hash/sequence, or a
  missing referenced identity stops ordinary writable startup at the first
  offending record. The valid prefix may be opened only in explicit degraded
  read-only mode with a persistent warning and exact boundary; it cannot draw,
  mutate, sync, or export an authoritative replacement.
- **DAT-056 [core] — Repair creates a verified replacement dataset.**
  `lant doctor` performs read-only full validation and reports exact offsets,
  identities, versions, and safe recovery sources. `lant repair` never edits
  the authoritative log in place: after explicit preview it writes a separate
  candidate dataset, records every migration or restoration decision, replays
  it completely, compares canonical counts/hashes, and only then may propose
  an atomic cutover with retained backup. Unknown semantics cannot be
  quarantined or skipped merely to make replay finish.

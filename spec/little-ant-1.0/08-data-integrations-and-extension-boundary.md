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
The 1.0 adapter catalog must cover these common sources through the standard
Pack or its pinned companion catalog:

```text
Microsoft To Do
Apple Reminders
Google Tasks
Google Calendar
GitHub Issues
Notesnook
Evernote
```

Exact shipping placement and API feasibility are tracked under
`OPEN-EXT-002`; the import protocol itself is a 1.0 requirement.

## Little Ant Packs

- **DAT-018 [standard] — Typed distribution.** `Little Ant Pack` is the only
  installable extension concept. Each component implements exactly one closed
  versioned host contract.
- **DAT-019 [standard] — Component kinds.**

  ```text
  BrickNature | BrickTemplate | ImportProfilePreset
  SourceAdapter | Enricher | ReadOnlyExporter | UIAdapter
  ```

  The first three are declarative. The last four execute as bounded Lua
  components.

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

The concrete vault, recovery, rotation, and memory-agent security design is
`OPEN-EXT-001`.

## Exporters and UI adapters

- **DAT-028 [standard] — Read-only exporter.** An exporter receives a named
  versioned projection and returns bytes, media type, filename, warnings, and
  metadata. Writing, publishing, or invoking another program is a separate
  surface or effect.
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
  retain credentials. Like the REPL, Skill, and first-party web/mobile hosts,
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

Pack signing, trust roots, revocation, dependency/update policy, and
reproducible archives remain `OPEN-PACK-001`.

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
  or pins an officially maintained Google Calendar `SourceAdapter`. It must
  observe and reconcile calendar events into canonical work without requiring
  a community extension. Whether it resides in the offline standard Pack or an
  official credentialed companion Pack is packaging, not a capability gap.
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
  for Nature and Template. Template-owned guidance under `MOD-048` participates
  in catalog-wide discovery; the following cases are illustrative, not a
  closed recognition list. `Flight AD123` may propose
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

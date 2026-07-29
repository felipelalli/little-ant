# 16. Core, operator, and adapter boundary

## 16.1 Core responsibilities

The core must remain deterministic, offline-capable, and replayable. It owns:

- the append-only event log and upcasting;
- canonical English commands and values;
- entity state and lifecycle invariants;
- tree structure and total sibling orders;
- opaque entity identity independent from titles;
- versioned BrickNatures, validated Nature capabilities, ListEntries, and
  deterministic template-expansion inputs;
- versioned standard and personal template catalogs, deterministic discovery
  metadata, contextual candidate retrieval, route validation, and
  capability-guided custom construction;
- comparison history and authority rules;
- discrete impact and effort classifications, versioned EffortProfiles, and
  deterministic confidence or internal reliability calculations;
- decomposition coverage, scope-change suspicions, and explicitly confirmed
  scope revisions;
- pseudo-random selection with recorded seeds or cursors;
- cooldown, aging, and proposal mechanics;
- mechanical detection and state-scoped assembly of applicable Brick-review
  questions without semantic guessing or meta-Brick creation;
- recurrence rules, restricted event-triggered opportunity release,
  occurrence windows and outcomes, standing-work eligibility, and streak
  projections;
- Delegation state, exactly one explicit follow-up policy per Delegation,
  replay-safe follow-up scheduling, and approval-bearing due opportunities;
- one idempotent deterministic time-advancement phase used before every
  command and by the explicit `la tick` administration surface;
- named Places, explicit Brick-to-Place conditions, attributed time-bounded
  location observations, and their deterministic eligibility or forecast
  effects;
- Raw identity and lifecycle, immutable snapshot history, typed RawLinks,
  content-addressed blob identity and integrity, explicit blob availability,
  per-link reconciliation baselines, and derived freshness or divergence
  conditions;
- normalized import batches, stable external-identity matching, inspectable
  ImportProfiles, validated feeding and adoption routes, source views, and
  provisional-placement confidence;
- independent external work-state and presence observations, migration scope
  and verification, explicit cutover, per-object cleanup effects, immutable
  migration receipts, and ImportProfile retirement;
- Little Ant Pack manifests, typed PackComponent contracts, compatibility
  checks, version pinning, content hashes, declared permissions, isolated
  runner invocation, and validation of every component result or proposed
  canonical operation;
- deterministic lexical normalization, candidate retrieval, and explainable
  duplicate-suspicion evidence;
- typed, previewable, atomic Brick merge plans with explicit survivor lineage
  and relationship-conflict validation;
- validation and replay of explicit field- and revision-bound typed text
  annotations without inferring targets from `@` strings;
- projections, including priority and forecast;
- one typed canonical status summary, its compact default human renderer, and
  command-appropriate sparse and complete projections used by every surface;
- a state-scoped interaction envelope containing the pending prompt, valid
  actions, shortcuts, exact canonical command representations, and relevant
  help, shared with first-party surfaces and UIAdapters;
- one versioned global interaction-grammar registry exposed read-only through
  `la grammar`, from which surfaces inspect rather than invent stable meanings
  and shortcuts;
- command-specific typed results, compact mutator postconditions,
  schema-declared field-presence rules, complete projections on demand, and
  explicit audit access without attaching full entities or event payloads to
  every operation;
- global side-effect-free dry-run execution for state-changing commands and
  stable typed failures with core-validated recovery actions;
- useful state-derived empty-session proposals without fabricating eligible
  work;
- non-overlapping planning-cut proposals and canonical versioned read-only
  projections for target-format exporters;
- explicit evidence ingestion with author, source, reason, and confidence.

The core may implement sophisticated statistics. “Deterministic” does not mean
“mathematically simplistic.”

## 16.2 Core prohibitions

The core must not:

- call an AI model;
- call the network to obtain judgment;
- place API keys, access tokens, CredentialBindings, or vault state in the
  operational domain model or event log;
- infer semantic analogies through a vendor service;
- hard-code provider-specific task or notebook branches into the domain
  model;
- translate, infer semantic duplicate identity, or invent causal explanations
  from free text;
- let an installed SourceAdapter or Enricher bypass canonical validation, gain
  undeclared capabilities, or perform write-back implicitly;
- expose a generic plugin hook, allow Pack code to invent entity or event
  kinds, or execute Pack code during replay;
- infer completion, dropping, archival, or migration cutover from external
  deletion, absence, or an empty import result;
- keep public compatibility aliases for removed commands or concepts;
- silently perform external side effects.

## 16.3 Operator responsibilities

The operator skill owns:

- understanding free-form and legacy human vocabulary;
- mapping it to one canonical core operation;
- resolving context-dependent language such as “done with this Raw” into an
  explicit Raw review/archive proposal or identified Brick completion without
  inventing a Raw-to-Brick conversion;
- preserving original text while translating non-English interaction into
  canonical English data;
- proposing titles, descriptions, phases, parents, BrickNatures, templates,
  ListEntry targets, and comparison reasons;
- resolving interface mention syntax into attributed typed-annotation
  proposals over core-provided candidates;
- ranking core-provided feeding routes and template candidates, filling a
  bounded proposal, and explaining why it fits;
- finding semantic analogs;
- finding semantic duplicate candidates and mapping them to explicit
  core-validated reuse, merge, enrichment, or separate-creation proposals;
- deciding whether a mechanical edit represents a semantic scope revision;
- proposing an appropriate validation method when impact uncertainty deserves
  real work;
- invoking AI or external planning tools;
- obtaining human confirmation where inference changes structure or authority;
- injecting explicit, attributed evidence into the core;
- explaining low confidence and asking useful questions;
- interpreting a guided Brick review and proposing real enabling or
  investigation work when a mechanical gap has semantic consequences;
- interpreting repeated practice outcomes and skip reasons, then proposing
  schedule changes, blockers, dependencies, pauses, or enabling Bricks;
- mapping free text about location to an explicit named Place and attributed
  manual observation;
- drafting external actions for approval.

An operator or adapter may submit attributed evidence that external work
appears complete and propose the ordinary `done` operation. The core preserves
its provenance and authority; external or AI evidence never fabricates a human
completion report.

Typed SourceAdapters own provider translation such as authentication flow
selection, pagination and incremental cursors, external-origin checks and
refreshes, normalized import candidates, confirmed actual imports,
provider-specific deletion signals, and execution of already-approved
item-scoped source cleanup. They return explicit attributed candidates,
observations, or effect receipts. A SourceAdapter never turns an external
change into a silent domain update or write-back. Source deletion requires a
separately declared capability and core-approved effect; the SourceAdapter
executes the provider call but neither chooses migration scope nor decides that
local verification is sufficient.

Location sensing and mapping to configured Places, device permission, geofence
geometry, raw coordinates, and transport or tiering of the logical blob
dataset remain adapter or deployment concerns outside domain semantics. Git,
Git LFS, Syncthing, object storage, and similar replication mechanisms do not
become Pack APIs merely because they exist outside the core.

ReadOnlyExporters translate a core-prepared versioned projection into a target
format. They cannot read the network or filesystem, run a subprocess, or
mutate canonical state. Enrichers return bounded attributed proposals.

UIAdapters own alternate-channel rendering, transport, and surface-local
session details such as voice duplication, Telegram keyboards, Markdown
dialects, and mobile layout. They consume the same state-scoped interaction
envelope as the REPL and operator and return one canonical action ID with its
interaction revision. A UIAdapter may arrange or decorate canonical content
for its channel, but it must not invent domain actions, redefine shortcut
semantics, or become another command catalog.

Credential authorization, refresh, and request injection belong to the
Little-Ant-owned credential broker and encrypted local vault. Pack code names
an explicitly configured CredentialBinding but never reads the underlying
secret or token. The vault has local deployment authority and is neither Pack
content nor operational domain state.

## 16.4 REPL surface

The REPL is a deterministic first-party surface over the same canonical
command runner as the ordinary CLI. It owns guided dialog, terminal rendering,
and a separate atomic UI checkpoint. It does not gain operator authority,
change domain semantics, or place unconfirmed presentation state in the event
log.

See [Deterministic REPL harness](24-repl-harness.md).

## 16.5 Thin operator protocol

The operator skill must not carry the complete command catalog and every
deterministic workflow as permanent prompt context. The core interaction
envelope is the source of truth for what may happen next.

The skill needs only a small bootstrap contract:

- obtain the current state-scoped interaction;
- understand or translate the human response;
- select or propose one returned canonical action;
- request deeper help, filtered history, or command details on demand;
- preserve approval and authority boundaries.

Long command references and specialized workflows should use progressive
disclosure. Rich core behavior is acceptable only when the currently exposed
surface remains small, explicit, and contextual.

The skill may recognize broad natural-language focus requests and legacy human
vocabulary, but it maps them to the current canonical action rather than
restoring aliases in the core. Product commands, values, shortcuts, and
canonical data remain English. The skill may localize only its conversational
wrapper when explicitly requested or selected by an operator preference.
Channel-specific presentation rules belong to the applicable first-party
surface or UIAdapter, not to the permanent skill bootstrap.

## 16.6 Extension package boundary

A Little Ant Pack is a distribution unit, not another authority layer.
Data-only Natures and templates select only core-supported capabilities.
The declarative component set is BrickNature, BrickTemplate, and
ImportProfilePreset. The executable component set is SourceAdapter, Enricher,
ReadOnlyExporter, and UIAdapter. Each component declares a separate typed
contract and explicit permissions; there is no generic `Plugin` type or
arbitrary lifecycle hook.

Executable Pack components use Lua 5.4 through a separate HsLua-based
`lant-pack-runner` process, with a fresh VM and resource limits for every
invocation. Official components receive no in-process exception. The host
exposes only bounded capability modules, such as `lant.http.request`; Lua does
not receive unrestricted operating-system libraries, raw sockets, dynamic C
modules, or credentials. Pack code is never executed during domain replay.

The open `little-ant-packs` repository may distribute an official standard
pack and broader community contributions, but the package format is
independent from GitHub and accepts other immutable sources. Credentials,
personal account bindings, local ImportProfiles, and runtime state never
belong in a shared pack.

See
[External imports, source views, and extension packs](32-external-imports-source-views-and-extension-packs.md)
and
[Lua Pack runtime, credentials, exporters, and UI adapters](34-lua-pack-runtime-credentials-exporters-and-ui-adapters.md).

## 16.7 Structured response boundary

The core selects a typed result and projection for each command. Operational
JSON is sparse by default, while a complete projection remains explicitly
available. Mutators return a compact postcondition sufficient to avoid a
follow-up `show`; they do not echo an entire Brick automatically.

Surfaces may request different scopes of the same canonical projection, but
they may not infer missing sparse fields as arbitrary null, false, or zero
values. Full audit events remain available explicitly, while actionable
outcomes appear directly in the current result or interaction.

See
[Structured command responses and sparse projections](33-structured-command-responses-and-sparse-projections.md).

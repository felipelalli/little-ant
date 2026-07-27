# 34. Lua Pack runtime, credentials, exporters, and UI adapters

## 34.1 A typed extension boundary, not generic plugins

`Little Ant Pack` is the only canonical name for a versioned installable
distribution unit. A Pack contains one or more typed `PackComponent`
definitions. Public introductory prose may describe Packs informally as
installable extensions, but 1.0 introduces no generic `Plugin` entity, command,
alias, lifecycle hook, or unrestricted extension API.

The distinction is deliberate:

- a Pack is packaging, provenance, compatibility, and installation;
- a PackComponent implements exactly one versioned host contract;
- permissions belong to an executable component and are visible before use;
- every component result is validated by the host contract that requested it;
- no component becomes another source of domain authority.

The 1.0 component kinds are:

| Component | Execution | Result |
|---|---|---|
| `BrickBehavior` | declarative | A versioned selection of core-supported capabilities. |
| `BrickTemplate` | declarative | An inspectable, one-time creation recipe. |
| `ImportProfilePreset` | declarative | A reusable credential-free starting policy for an external source. |
| `SourceAdapter` | Lua | Normalized candidates, source observations, or receipts for effects already approved through the canonical effect boundary. |
| `Enricher` | Lua | Bounded, attributed proposals derived from an explicit input projection. |
| `ReadOnlyExporter` | Lua | Bytes plus media type, suggested filename, warnings, and export metadata derived from a versioned read-only projection. |
| `UIAdapter` | Lua | Channel rendering and a mapping from channel interactions back to one canonical action ID and interaction revision. |

The terms do not overlap. An importer is a `SourceAdapter`; a TaskJuggler
serializer is a `ReadOnlyExporter`; Telegram or another alternate interaction
surface uses a `UIAdapter`. A Pack may contain several components, but each
component is invoked through its own contract and permissions.

The following extension powers are explicitly absent from 1.0:

- alternative priority, forecast, or next-selection algorithms;
- new canonical entity or event kinds;
- direct event-log, domain-storage, or projection mutation;
- arbitrary lifecycle hooks such as `on_done`;
- self-owned background threads or schedulers;
- global commands, aliases, or shortcut definitions;
- replacement storage engines;
- arbitrary canonical operations chosen outside the current interaction or
  effect contract;
- executable logic during event replay.

Adding a new semantic capability therefore remains a core design change. A
Pack may compose or present an existing capability, translate an external
system, or propose bounded evidence; it cannot quietly redefine Little Ant.

## 34.2 Determinism and replay

Executable Packs are useful at the system boundary, where the external world
is necessarily non-deterministic. Their outputs become explicit inputs to the
deterministic core:

```text
Pack code + external world
  -> candidate / observation / proposal / effect receipt
  -> core schema and authority validation
  -> canonical operation
  -> persisted event

replay(persisted events)
  -> the same operational state
  -> no Pack execution
```

The invocation records or references the component ID, Pack version and content
hash, contract version, relevant input revision, declared capability set, and
the accepted result provenance. Provider receipts and external timestamps
remain observations rather than replayed effects.

The core decides when a component may run. Scheduled source checks, for
example, are core-derived due work executed by an available surface or host;
a SourceAdapter does not create its own timer. Retrying an invocation never
changes idempotency or approval rules.

## 34.3 One Lua runtime for executable Packs

Lua 5.4 is the only first-class executable Pack language in Little Ant 1.0.
The Haskell host embeds it through HsLua, but the public Pack API is a
Little-Ant-owned, independently versioned contract rather than a promise about
HsLua internals.

Every executable component, including components shipped by the project, runs
in a separate `lant-pack-runner` process. There is no trusted in-process
exception for the standard Pack. Each invocation receives a fresh Lua VM and
bounded structured input, and returns one bounded structured result.

The runner enforces at least:

- a wall-clock deadline;
- an instruction budget;
- memory, result-size, and nesting-depth limits;
- a manifest-declared capability set;
- deterministic schema validation at both process boundaries;
- cancellation and explicit error classification;
- redaction of credentials and sensitive request metadata.

It does not expose unrestricted Lua libraries. In particular, Pack code has no
direct `io`, `os`, `debug`, raw socket, `package.loadlib`, dynamic C module, or
unconstrained subprocess access. A Pack cannot dynamically install LuaRocks.
Permitted pure-Lua dependencies are vendored in the Pack, versioned, included
in its content hash, and subject to the same runtime limits.

The exact process protocol, default resource budgets, cancellation grace
period, and operating-system sandbox profile remain open. These parameters may
be tuned without broadening the component contracts.

## 34.4 Host capabilities and HTTP

Lua code reaches external facilities only through narrow host modules. The
initial network surface is one synchronous request function:

```lua
local response = lant.http.request {
  method = "GET",
  url = "https://graph.microsoft.com/v1.0/me/todo/lists",
  credential = "microsoft-todo",
  query = { ["$top"] = 100 },
  accept = "json"
}
```

`lant.http.request` is the only canonical HTTP entry point in 1.0; convenience
aliases such as `get`, `post`, or `delete` are not separate contracts.

The host, rather than an arbitrary Lua library, owns:

- TLS and certificate validation;
- query encoding and bounded request bodies;
- JSON encoding and decoding;
- redirect policy;
- timeouts and cancellation;
- safe retry policy and rate limiting;
- response-size limits;
- structured transport errors;
- credential injection and log redaction.

The manifest declares every exact network host a component may contact. A
redirect to an undeclared host fails explicitly. Network permission alone does
not grant credentials, provider write-back, source deletion, or access to
another component's account binding.

Filesystem reads, subprocesses, and future capabilities follow the same
principle: a typed host function exists only when 1.0 specifies its bounded
input, output, authority, and audit behavior. The presence of a permission name
does not expose a general operating-system API.

## 34.5 Credentials and the local vault

Little Ant 1.0 owns an encrypted credential vault rather than delegating its
primary credential model to a desktop keyring or an arbitrary credential
command. The vault is local deployment authority:

- it is not operational domain state;
- it is not stored in the append-only event log;
- it is not a rebuildable domain projection;
- it is not part of ordinary dataset synchronization;
- it never belongs in a Pack or ImportProfile;
- backup or transfer requires an explicit encrypted export.

A Pack manifest declares a named credential slot, typed authentication scheme,
required scopes, exact allowed hosts, and any non-secret authorization or token
endpoints. A local `CredentialBinding` maps that slot to one vault entry and
account. Shared Packs therefore contain neither tokens nor personal account
identifiers.

The 1.0 `CredentialBroker` supports these typed schemes:

- OAuth 2.0 authorization code with PKCE;
- OAuth 2.0 device authorization;
- bearer token or API key;
- no authentication.

The broker performs interactive authorization, refreshes credentials when
allowed, and injects authentication into `lant.http.request`. Lua receives
neither the stored secret nor a refreshed access token. It sees only the
declared binding name and a redacted request result.

An explicit unlock operation, with `la vault unlock` as the working CLI
spelling, unlocks a local memory agent. Decrypted key material remains only in
memory and expires after an idle timeout. When the vault is locked, a
credential-dependent scheduled check remains due and reports
`credential_locked`; it is not counted as a provider failure and does not
advance provider backoff. The REPL, operator, or another UI surface may offer
the explicit unlock interaction.

The vault file format, key derivation and cipher choices, master-key and
recovery procedure, rotation and revocation semantics, idle timeout, and local
agent IPC hardening remain open security-design work. No unconfirmed recovery
mechanism is implied by this chapter.

## 34.6 Read-only exporters

A `ReadOnlyExporter` receives a named, versioned projection prepared by the
core. It returns:

```text
bytes
media_type
suggested_filename
warnings
export_metadata
```

The component has no direct network or filesystem access and cannot mutate
canonical state. Writing the returned bytes to stdout or a selected path is
the invoking surface's responsibility. Publishing them or invoking another
program is a separately approved effect outside the pure exporter.

The projection schema is exporter-independent wherever possible. It carries
stable IDs, explicit relationships, source revisions, and typed values; the
exporter owns only target-format serialization. Export validation distinguishes
an unsupported input from malformed component output.

### TaskJuggler as the reference exporter

The standard Pack shipped with Little Ant 1.0 includes a TaskJuggler
`ReadOnlyExporter` implemented in Lua. It is both a supported product
integration and the canonical executable-Pack example for community authors.

The core still owns:

- total-effort semantics and EffortProfile resolution;
- the proposed and human-confirmed non-overlapping planning cut;
- construction and validation of the canonical planning projection;
- stable Brick IDs and dependency references;
- the immutable planning manifest and its source revisions.

The Lua component owns TaskJuggler-specific `.tjp` serialization and returns
the generated bytes, media type, suggested `.tjp` filename, and warnings. No
TaskJuggler formatter is hard-coded in the Haskell core.

Running `tj3`, choosing calendars or resources, writing output, and publishing
results are planning or surface effects, not part of the pure exporter.
Importing TaskJuggler actuals uses a separate standard-Pack `SourceAdapter`
with explicit identity mapping, preview, and confirmation.

The TaskJuggler component ships with an inspectable manifest, source,
fixtures, contract tests, failure examples, and a minimal authoring guide. It
must exercise the same runner, permissions, schemas, and version negotiation
as a community component; it must not depend on private host APIs.

The final generic export command grammar and the exact planning projection
schema remain open. The current v0 `la export tj` spelling is evidence, not an
automatic 1.0 compatibility alias.

## 34.7 UI adapters

`UIAdapter` is a first-class executable PackComponent in 1.0. It permits
alternate interaction surfaces without creating another command language.

The core supplies a canonical `InteractionEnvelope` containing:

- interaction identity and revision;
- the current prompt and canonical human content;
- state-scoped valid actions;
- stable action IDs;
- canonical command representations;
- core-assigned shortcuts and contextual help;
- bounded typed projection data needed for rendering.

A UIAdapter maps that envelope to channel-specific output and maps a received
channel interaction back to exactly one action ID and the interaction revision
against which it was rendered. The core rejects stale, unknown, ambiguous, or
out-of-scope actions.

A UIAdapter may own:

- transport and delivery to its configured surface;
- channel session and cursor checkpoints;
- Markdown dialect, buttons, keyboards, pagination, voice duplication, and
  layout;
- channel-specific correlation identifiers and retry receipts.

It may not:

- invent actions, commands, aliases, or shortcuts;
- reinterpret an action's meaning or approval requirement;
- submit a response without its interaction revision;
- mutate canonical state directly;
- claim human authority for an AI or transport-generated answer;
- turn arbitrary third-party notifications into ordinary UI delivery;
- retain secrets outside the credential broker.

A configured personal UI surface may deliver ordinary Little Ant interaction
as part of its explicit channel configuration. Sending a message to an
unconfigured recipient, publishing content, or producing another third-party
effect still requires the ordinary explicit-effect boundary.

The first-party offline REPL remains a core surface and need not be packaged as
a UIAdapter. It nevertheless consumes the same envelope and obeys the same
stale-response and authority rules. Candidate Pack-based surfaces include
Telegram, Slack, Discord, Matrix, voice, web, mobile, and alternate TUIs; which
concrete adapters ship in the initial standard Pack remains open.

## 34.8 Standard Pack and community development

A standard Pack is distributed offline with Little Ant 1.0 and pinned through
the same installation and compatibility machinery as any other Pack. At
minimum it contains the Lua TaskJuggler exporter and its reference
implementation materials. Its remaining initial templates, behaviors,
SourceAdapters, Enrichers, ImportProfilePresets, and UIAdapters are selected
during implementation planning.

The separate open `little-ant-packs` repository is the recommended broader
catalog for official and community contributions. Pack installation must also
work from a local path or immutable archive; GitHub is a distribution
convention, not authority.

Author tooling should provide:

- Pack and component manifest validation;
- a local runner with deterministic fixture input;
- typed request and result schemas;
- capability inspection;
- conformance suites for each component kind;
- reproducible packaging and content hashing;
- redacted diagnostics;
- examples based on the standard TaskJuggler exporter.

Signing, registry indexes, dependency resolution, update review, revocation,
and community acceptance policy remain open. Whatever mechanism is selected
must preserve pinned versions, explicit permission changes, inspectability,
and replay without executing Pack code.

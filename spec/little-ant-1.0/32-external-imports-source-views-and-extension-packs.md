# 32. External imports, source views, and extension packs

## 32.1 The 1.0 commitment

Little Ant 1.0 includes a general external-import mechanism. This commitment
does not hard-code Microsoft To Do, Apple Reminders, Google Tasks, GitHub, or
another provider into the domain model, and it does not require every known
connector to block the first 1.0 release.

The core defines and validates:

- normalized import candidates and batches;
- external identity, provenance, snapshots, and idempotency;
- import preview and the canonical operations an accepted candidate may use;
- inspectable import profiles;
- priority placement and uncertainty;
- reconciliation, migration cutover, and explicit external-effect boundaries;
- package manifests, compatibility, and declared permissions.

Adapters own provider authentication, pagination, incremental cursors,
provider field interpretation, and translation into that normalized contract.
Import is read-only by default. Any write-back remains a separately proposed
external effect and never follows merely from installing or running an
importer. Deleting imported objects from their source is a destructive
migration operation, not an ordinary consequence of import or synchronization.

## 32.2 Capture and adoption are separate decisions

Import has two conceptual steps:

```text
capture or refresh external material
adopt or route accepted meaning into Little Ant work
```

`capture` creates or refreshes one Raw with a RawOrigin and immutable
RawSnapshots. It preserves the upstream object even when no Little Ant work is
created.

`adopt` applies an explicit route, such as:

- create a positioned Brick linked to the Raw as its source;
- add a ListEntry to an existing compatible Brick;
- link the Raw to an existing Brick or ListEntry;
- add the Raw to a semantic RawShelf;
- record a reviewed disposition that creates no work.

This corrects the earlier absolute rule that every imported item must stop as
Raw and later pass through one mandatory extraction funnel. Raw capture remains
mandatory for attributable external content, but a configured structured-task
source may capture the Raw and adopt it into work atomically.

An accepted structured task from a configured source may therefore create, in
one validated operation:

1. the Raw, RawOrigin, and available snapshot;
2. a canonical-English Brick or ListEntry;
3. the applicable source RawLink;
4. a valid semantic destination;
5. a valid strict priority position when a Brick is created;
6. a reviewed Raw disposition.

There are no unpositioned Bricks. Automatic adoption may use a confirmed
profile placement policy or an attributed operator or powered-up proposal to
choose a provisional strict position. That placement carries low priority
confidence and creates future comparison pressure. It does not claim that the
upstream list order is human importance.

Unknown sources, mixed sources, ambiguous items, and note-like material remain
pending Raw until routed. Reviewing a note may produce zero, one, or many
Bricks. The operator skill or powered-up REPL may propose translation,
classification, duplicate candidates, shelves, links, and work extraction.
The dumb REPL must still support manual review and deterministic routing; the
core never performs semantic extraction itself.

## 32.3 Source grouping is not a RawShelf

Provider provenance is a derived source view, not a semantic shelf. The core
can group or filter imported material by typed RawOrigin fields such as:

```text
adapter
account binding
external container
external identity
```

This supports inspection, resynchronization, reconciliation, bulk review, and
diagnostics such as:

```text
Microsoft To Do / Personal / Household
GitHub Issues / juxt/allium
Notesnook / Research
```

No `Microsoft To Do` or `Evernote` RawShelf is created merely because those
providers supplied material. Doing so would duplicate provenance and confuse
origin with subject matter.

A confirmed ImportProfile may additionally map an external container to:

- a semantic RawShelf;
- a Brick parent or collection;
- a compatible ListEntry-owning Brick;
- a template or behavior configuration.

For example, `Microsoft To Do / Personal / Household` may map task adoption to
the `Keep the house in order` collection and optionally map supporting
material to a `household` RawShelf. The mapping is semantic policy, not an
inference from provider identity.

One semantic destination may aggregate several external sources, and one
mixed external container may need several routing rules. Changing a profile
affects later imports; it never silently moves or reclassifies already adopted
work.

## 32.4 ImportProfile

`ImportProfile` is the working name for an inspectable, versioned routing
policy. Its exact schema remains open, but it must be able to express:

- a source matcher, including adapter, account binding, container, and
  optional provider query or filter;
- the declared source shape: structured task, material, or mixed;
- whether adoption is manual, proposed, or authorized automatically;
- the target parent, collection, ListEntry owner, or optional RawShelf;
- an applicable template or resolved behavior;
- provisional-placement policy and priority-confidence treatment;
- explicit mappings for dates, completion evidence, recurrence, descriptions,
  labels, and supported provider fields;
- canonical-English normalization and preservation of original input;
- refresh, incremental-import, and reconciliation policy.

Credentials, tokens, and provider secrets are deployment configuration, never
shareable profile content or operational domain events. A reusable pack may
provide a profile preset, but personal account bindings and semantic
destinations are configured locally.

The first unresolved container mapping is confirmed once and may then be
reused deterministically. Rejection or a reviewed no-work disposition is tied
to stable external identity so later imports do not repeatedly present the
same unchanged item.

An active ImportProfile may authorize scheduled read-only checks, refreshes,
and incremental capture without requiring a new confirmation for every run.
The activity and any failures still appear in recap and history. Provider
write-back, source cleanup, and other destructive effects are never implied by
that standing read authorization.

## 32.5 Identity, duplicates, and reconciliation

When available, the importer resolves one upstream object through the tuple:

```text
adapter + account binding + stable external identity
```

That tuple identifies external provenance, not semantic equality. Reimporting
the same upstream object refreshes the same Raw and reconciles its existing
adoption; it does not create another Brick. Two different upstream identities
with similar content remain distinct captures and may raise ordinary duplicate
suspicion. They are never silently merged.

A changed upstream object appends a RawSnapshot when warranted. Each source
RawLink tracks its own reconciliation baseline. An upstream completion is
attributed evidence that may propose ordinary Little Ant completion; it never
silently records the human's answer. Provider ordering, labels, due fields,
and completion vocabulary are preserved in provenance and mapped only through
an inspectable adapter and ImportProfile.

External work state and external presence are independent observations.
Working vocabulary is:

```text
external work state: open | completed | unknown
external presence:   present | removed | unavailable | unknown
```

The first axis applies only when the provider object has meaningful completion
semantics. The second describes whether the adapter can still observe the
object. A provider tombstone or another authoritative deletion signal may
establish `removed`; it never establishes `completed`, `done`, `dropped`, or
Raw archival. Omission from a filtered page, expired credentials, a failed
request, an inaccessible container, and a provider-specific ambiguous `404`
must not be translated into deletion without adapter evidence that makes that
interpretation authoritative.

Deleting an external container likewise does not complete all of its former
children. The container observation and each known child origin remain
inspectable. Unexpected mass removal pauses automatic reconciliation and
raises one source-level anomaly for review instead of producing a burst of
Brick lifecycle changes.

Incremental cursor storage, retry and backoff mechanics, exact observation
schemas, anomaly thresholds, and reconciliation interactions remain open.

## 32.6 Migration cutover and optional source cleanup

A migration is a bounded import workflow, not an indefinitely active
synchronization relationship. Its conceptual sequence is:

```text
capture and adopt
review and verify
prepare cutover
optionally clean the source
finalize cutover
retire the ImportProfile
```

Cutover is explicit. It is never inferred from an empty source, a run with no
new candidates, or upstream deletion. Finalization records an immutable
migration receipt that identifies the selected source scope, imported
external identities and revisions, corresponding Raw and adoption
dispositions, verification results, and any cleanup outcomes. The exact
receipt schema remains open.

A retired ImportProfile keeps its configuration and history inspectable but
authorizes no later scheduled checks. Its RawOrigins become historical
provenance: stable external IDs, locators, snapshots, and reconciliation
history remain available, while ordinary freshness pressure is suppressed.
Retirement does not delete or detach Raw, RawLinks, Bricks, or ListEntries.

An illustrative destructive migration request is:

```text
lant import microsoft-todo --erase-after-import
```

The exact final command grammar and adapter identifier remain open. The
semantic decision is fixed: `erase-after-import` means “after the selected
migration scope is durably captured, adopted or explicitly disposed, and
verified, request deletion of those imported objects from the source.” It
never means “treat disappearance as completion.”

The safe execution contract is:

1. ordinary import keeps the source unchanged;
2. the Adapter must separately declare source-deletion capability, and the
   configured credentials must possess it;
3. the core freezes and previews the exact source scope, counts, unsupported
   or lossy fields, and intended destructive effects;
4. every object must have a verified local receipt, available required
   snapshots, and a reviewed adoption or no-work disposition before it becomes
   cleanup-eligible;
5. a changed upstream revision, incomplete capture, unsupported required
   material, or unresolved route blocks deletion of the affected object;
6. the user explicitly approves the displayed cleanup plan after verification
   and before the first deletion; specifying the flag expresses intent but
   does not bypass that checkpoint;
7. deletion is logically item-scoped. An Adapter may batch transport calls,
   but the core records a separate requested and observed outcome for every
   stable external identity;
8. each successful deletion records external presence as removed with
   migration-cleanup provenance. It does not mutate local work state;
9. partial failure is resumable and idempotent. Successful local imports and
   completed deletions are not rolled back, failed deletions remain explicit,
   and the profile is not retired until every selected object is erased,
   explicitly kept, or otherwise resolved;
10. deleting the now-empty external list or container is a separate,
    separately previewed effect. It is never implied by deleting its imported
    entries.

Cleanup normally begins only after the selected scope passes the verification
checkpoint; an item is not deleted merely because its individual fetch
returned success. A retry may accept “already absent” as success only when a
prior recorded cleanup request or provider receipt proves that Little Ant
caused the deletion. Otherwise absence remains an external observation to
reconcile.

This design lets a Microsoft To Do migration remove entries progressively
after one global review while retaining per-item fault isolation. Provider
batching and an API that can delete a whole list are transport optimizations,
not broader domain authority.

## 32.7 Notes and mixed sources

Notesnook, Evernote, OneNote, Joplin, Obsidian directories, and similar
notebooks are material-first sources. Their notes normally become pending Raw
with notebook, folder, and tag provenance retained. Semantic triage is
judgment:

- zero useful actions is valid;
- one note may support many Bricks;
- several notes may support one Brick;
- a note may remain only reference material;
- translation and summaries are attributed derivatives and never replace the
  original snapshot.

Notion, Joplin TODO notes, Trello cards with substantial reference material,
and other mixed systems require per-item routing. A provider name alone never
decides whether an item is Raw, a Brick, or a ListEntry.

Candidate task sources include Microsoft To Do, Apple Reminders, Google Tasks,
GitHub Issues, Todoist, TickTick, Microsoft Planner, Trello, Asana, Jira,
Linear, and GitLab Issues. Candidate material or mixed sources include
Notesnook, Evernote, OneNote, Notion, Joplin, Obsidian or generic Markdown
directories, Apple Notes, and Google Keep. This is a connector catalog, not a
statement that every adapter blocks 1.0.

Apple's product is Apple Reminders. Its adapter is expected to be a local
platform integration rather than a provider-independent server API.
Notesnook may begin with its standard export formats. Evernote may begin with
an export adapter before a live API adapter. Generic Markdown, HTML, text,
JSON, CSV, ZIP, and ENEX import reduces provider coupling and gives note
triage a common path.

The exact initial adapter set distributed with 1.0 remains an implementation
planning decision. The framework, at least one representative path for each
supported acquisition class, and the stable package boundary are 1.0
requirements.

## 32.8 Little Ant packs

`Little Ant Pack` is the selected name for a versioned distributable bundle of
extensions. A pack may contain:

- declarative BrickBehaviors composed only from core-supported capabilities;
- BrickTemplates;
- reusable ImportProfilePresets without credentials or personal bindings;
- SourceAdapters that return normalized candidates or observations and
  execute only already-approved source effects;
- Enrichers that return bounded attributed proposals;
- ReadOnlyExporters that serialize versioned core projections without
  filesystem, network, or mutation authority;
- UIAdapters that render canonical InteractionEnvelopes and map channel input
  back to canonical action identity and interaction revision.

These are typed `PackComponent` contracts, not one generic plugin API. A Pack
may bundle several component kinds, but each remains independently declared,
versioned, permissioned, invoked, and validated.

The recommended open community repository is `little-ant-packs`. It may
contain a broader catalog that users can inspect, fork, and contribute to.
The repository is a distribution convention, not domain authority: the pack
format must also be installable from a local path or immutable archive and
must not require GitHub.

`little-ant-packs` is preferred over `lant-collection`, because `collection`
already names a BrickBehavior, over `lant-plus`, which suggests a commercial
edition, and over `enrichment`, which does not cover all extension kinds.

The core repository retains the event model, schemas, capability
implementations, package protocol, validation, permission enforcement, CLI,
and REPL. A small generic factory library and the standard pack are available
offline with the product. Broader domain templates, providers, and community
extensions can evolve without a core release when they use an already
supported contract.

The standard Pack shipped with 1.0 includes a TaskJuggler ReadOnlyExporter
implemented in Lua. It is a supported integration and the canonical reference
component for community authors; it receives no private in-process privilege.

## 32.9 Package authority, compatibility, and trust

A pack cannot introduce unchecked domain semantics. Declarative behaviors and
templates may select only capabilities implemented and validated by the core.
An unsupported capability requires a core change and fails explicitly rather
than degrading or executing hidden logic.

SourceAdapters, Enrichers, ReadOnlyExporters, and UIAdapters are executable and
have a different trust class from data-only behaviors, templates, and import
presets. Lua 5.4 is the only first-class executable Pack language in 1.0.
Every executable component, including the standard Pack, runs with a fresh VM
inside the separate HsLua-based `lant-pack-runner`; no Pack code runs during
domain replay.

Installation and inspection must expose bounded declarations such as:

```text
component kind and contract version
exact HTTP hosts
credential slots and typed authentication schemes
typed source-read or filesystem-read capabilities
source_delete
UI transport capability
```

Exact permission names remain open. `source_delete` is working vocabulary for
a capability distinct from ordinary source reads; it is not granted merely
because a SourceAdapter can authenticate. The host exposes bounded capability
modules instead of unrestricted `io`, `os`, raw sockets, dynamic C modules, or
subprocess access. No executable component gains write-back, arbitrary domain
mutation, or secret access implicitly.

Credentials live in a Little-Ant-owned encrypted local vault. A Pack declares
a credential slot, authentication scheme, scopes, endpoints, and allowed
hosts; a local CredentialBinding selects the account. The credential broker
performs authorization and refresh and injects authentication into
`lant.http.request`. Lua never receives the stored secret or token.

At minimum a pack manifest identifies:

```text
pack_id
version
compatible core API range
components
permissions
dependencies
license
source
content hash
```

Installed versions are pinned. Template expansion records provenance, and the
resulting Brick state carries replay-safe resolved behavior configuration.
Updating a pack never silently changes existing Bricks, reroutes prior
imports, or grants new permissions. Credentials, CredentialBindings, local
ImportProfiles, and runtime state are excluded from community packages.

Signing, registry indexes, dependency resolution, update review, revocation,
component conformance tests, and exact executable resource budgets remain
open. The runtime, credential, exporter, and UI contracts are detailed in
[Lua Pack runtime, credentials, exporters, and UI adapters](34-lua-pack-runtime-credentials-exporters-and-ui-adapters.md).

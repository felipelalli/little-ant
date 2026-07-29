# 22. Session log

Exact message timestamps were not reconstructed. The sequence below preserves
the decision order and the later corrections that matter.

## Entry 1 — Simplify the lifecycle

The session began from the concern that `raw / seed / committed / ready` was
too complex. Raw remained meaningful as unorderable material. The initial idea
was to unify the other pre-completion states into a default Brick that is
ordered from birth.

## Entry 2 — Make ordering the center

The human priority list became the central model. Higher position represents
stronger commitment; lower position resembles backlog. Binary insertion
remained the placement mechanism. The canonical comparison was simplified to
“Does X come before Y?”

## Entry 3 — Put “I do not know” in the core

The user required ordering skip to be deterministic core behavior, not an
operator improvisation. A skipped comparison tries another nearby Brick. A
second skip accepts a provisional location with uncertainty and future
reordering pressure.

## Entry 4 — Separate phase from priority

The former stage concept was split. Phase became `idea`, `spec`, `exec`, or
optional `validation`, while completion became a separate status. A confusing
phrase about ordering by “phase/derived readiness” was rejected: phase may
suggest an initial area and affect selection, but human priority remains its
own order.

## Entry 5 — Reject compatibility aliases

Because the system is still personal and pre-production, the user rejected
core aliases. The operator may interpret natural language, but the core must
have exactly one unambiguous vocabulary.

## Entry 6 — Distinguish priority from next

The user clarified that there are two visible lists:

- the stable human priority hierarchy;
- the dynamic Little Ant choice list.

The second became a derived forecast/probability distribution rather than a
second stored order.

## Entry 7 — Refine hierarchy and uncertainty

Priority became sibling-scoped and hierarchical, with lexicographic global
display. A boolean uncertainty idea evolved into derived confidence. Direct
human and AI comparison histories were retained with authority and recency.

## Entry 8 — Add provocative validation

The user asked how contradictory indirect comparisons should work across
priority, impact, and effort. The system gained discovery, validation, and
recalibration probes. It may directly challenge a transitive implication.
Contradictions lower local confidence and trigger recalibration rather than
being rejected.

## Entry 9 — Prefer current judgment plus history

The user selected a model that preserves history while giving greater weight
to more recent judgment. Human evidence remains authoritative over AI
evidence.

## Entry 10 — Expand Raw into durable material

Raw was refined from a one-shot inbox item into durable, reusable material with
separate review and archive axes, immutable snapshots, optional freshness, and
many-to-many RawShelf groupings.

## Entry 11 — Separate WIP from current attention

An earlier consolidation incorrectly proposed one human WIP. This was
corrected: multiple WIPs are valid, with a soft limit of three, while only
current human focus is exclusive.

## Entry 12 — Replace hours with relative effort

The user challenged hour estimation because humans and AI are poor at it
without a stronger planning model. Generic `weight` was also considered
ambiguous. The design selected relative remaining `effort`, learned through
comparisons and calibrated evidence, with hours only at an external planning
boundary. This was an intermediate model, later replaced by entries 21 and 23.

## Entry 13 — Inspect personal TaskJuggler practice

The personal `planning` repository and TaskJuggler guidance were inspected.
They showed scenario-expanding effort macros, resource efficiency as a
separate concern, and actual-effort corrections. The user corrected an
important misunderstanding about scenarios: an estimated export item selects
one macro, and that macro expands into optimistic, realistic, and pessimistic
values.

## Entry 14 — Retract the leaf-only inference

The first materialized draft incorrectly stated that only active leaves receive
TaskJuggler effort and that parent roll-ups had been rejected. The user
immediately identified that this had never been decided. The statement was
retracted. Export granularity and parent/descendant effort semantics remain
open at this point in the session; entry 22 records their later resolution.

## Entry 15 — Fix the core/operator boundary

The deterministic core may compute ratings and confidence but never calls AI
or owns network judgment. The operator finds analogies, consults external
tools, and injects attributed evidence. Adapters translate that evidence into
planning formats.

## Entry 16 — Require English throughout

The user explicitly required all product commands, answers, shortcuts, data,
documentation, and specifications to be English. This superseded any earlier
idea of a pt-BR product surface.

## Entry 17 — Preserve the work before continuing

The user asked to stop the question battery long enough to materialize the
decisions, then continue discovery, review every existing Little Ant Brick,
and only afterward create the implementation and migration plan. This
document is that materialization. No code or Little Ant data was changed.

## Entry 18 — Split the record for selective loading

At the user's request, the monolithic design record was moved under `spec/`
and split into one descriptive file per chapter. A compact index now provides
topic-oriented reading paths so future sessions can load only the authority,
corrections, open questions, log tail, and subject chapters they need. The
split changed navigation, not product behavior.

## Entry 19 — Promote the REPL into 1.0

The user clarified that the REPL is required in 1.0, superseding an existing
backlog idea that placed it in 1.5. It must behave like a deterministic
Claude/Codex-style harness over the canonical CLI pipeline, advance through
mechanical steps, and stop at human decisions. Finite choices use one keypress
without Enter.

## Entry 20 — Define the REPL interaction and recovery model

`/` became the navigation-mode command palette, replacing an earlier `:`
suggestion. The REPL gained adaptive persistent regions, summarized recent
activity, searchable `/history`, timed notices that never interrupt an active
answer, and an atomic presentation checkpoint capable of restoring the exact
dialog, draft, cursor, and transcript. The checkpoint remains separate from
the domain event log and is validated against its cursor and hash.

## Entry 21 — Make effort total rather than remaining

The user argued that effort should remain the original amount of work rather
than a moving target. This was refined into total effort for the current scope:
progress never lowers it, while a better estimate or confirmed scope revision
may replace the current judgment without erasing history. Remaining effort
became a conservative derived planning projection.

## Entry 22 — Resolve parent effort and planning granularity

A parent's effort was defined as its complete scope including descendants.
Decomposition gained explicit `open | complete` coverage. TaskJuggler export
was resolved through a human-confirmed non-overlapping planning cut: a Little
Ant parent may be a TaskJuggler leaf for a particular plan, and parent and
descendant effort are never counted together.

## Entry 23 — Replace continuous effort with a profile

The intermediate `effort_score: 0..1` and global effort-list ideas were
discarded. Effort now uses eight canonical discrete classes in a versioned
EffortProfile. A user may classify directly or press `?` for up to three
adaptive comparisons against trusted exemplars; `s` cancels without evidence.
The profile's realistic hours may be displayed as context but hours do not
belong to a Brick.

## Entry 24 — Make planning simulations reproducible artifacts

Each effort class maps to one structural macro that expands into all three
TaskJuggler scenarios. Every confirmed simulation produces an immutable
planning manifest outside operational domain state. Actual import uses
embedded Brick IDs, a grouped human-confirmed preview, and preserves the
estimate separately from observed work.

## Entry 25 — Replace impact floats with class and maturity

The intermediate public `impact_score` and `impact_confidence` were discarded.
Impact became expected impact with six discrete classes. Evidence quality
became four public maturity levels: `SPECULATIVE`, `SUPPORTED`, `VALIDATED`,
and `OBSERVED`. Maturity is not probability of success, and the core may use a
separate internal reliability signal only for selection.

## Entry 26 — Treat meaningful impact validation as work

A quick question remains an `impact_probe`, but a questionnaire, experiment,
POC, MVP, or homologation may be a real `validation`-phase Brick. Completion
only produces evidence; it never silently changes impact or maturity. Little
Ant should suggest such work only when its expected value of information is
high and must not invent the method or create the Brick automatically.

## Entry 27 — Consolidate before pausing

The user requested a durable checkpoint for the next day. The subject
chapters, corrections, invariants, open-question queue, Brick inventory, and
review checklist were updated without changing code, README, the executable
Allium specification, or Little Ant data.

## Entry 28 — Define priority as strict importance

The human ordering question changed from “Does X come before Y?” to “Is X more
important than Y?” Urgency, dependency, maturity, and selection remain
separate. An `equally important` answer was rejected because lack of knowledge
or willingness is not equality. `?` became a visible non-answer for
information and help. Ordering skip may record `tie-break for me`, which
delegates a provisional strict direction without asserting equality.

Two unresolved comparison skips retain provisional placement and low
confidence. When the uncertainty could alter a relevant choice, the core may
offer an ordinary investigation Brick. It never invents the method, creates
the Brick, or chooses the eventual comparison answer.

## Entry 29 — Make phase and effort lazy

The user did not want to remove phase or effort before experiencing them in
practice. Both became optional, Nature-applicable metadata. Missing values
are neutral, feeding remains formless, and the system asks only when the field
could materially change an action or planning result. Phase no longer acts as
the replacement for every former `kind` distinction.

## Entry 30 — Keep one dialog protocol

Concern about an ever-growing operator skill led to a thin-skill design. The
core returns the pending prompt, currently valid actions, exact canonical
commands, shortcuts, and on-demand help. The dumb REPL, powered-up REPL, and
Codex/Claude skill consume this same interaction protocol instead of carrying
separate workflow catalogs. Paginated, filtered history and concise briefs
prevent a large event log from becoming permanent LLM context.

Powered-up mode uses an explicitly configured executable, validates it before
startup, sends prompts through stdin, validates bounded structured responses,
shows its adapter in the status line, and attributes all suggestions to AI.
It may improve normalization, duplicate candidates, parenting, provisional
ordering, and causal proposals without gaining human authority.

## Entry 31 — Separate Nature from templates and domain-specific recipes

Hard-coded natures such as grocery list, wishlist, reading list, and feature
backlog were rejected as core branches. `BrickNature` became a persistent,
versioned selection of generic core capabilities. `BrickTemplate` became an
inspectable one-time creation recipe. A small factory Nature library and an
opinionated standard template library may ship as data and be cloned into
personal namespaces. The earlier public `BrickShape` idea was dropped as an
unnecessary configurable axis.

## Entry 32 — Add ListEntry and replace title identity

A grocery item was found to be neither durable Raw nor independently
focusable Brick work. `ListEntry` became a lightweight occurrence resolved
inside its owning batch. Raw remains appropriate for a receipt, product URL,
coupon, photo, or other source.

The current v0 title-hash identity and global title collision rule were
superseded for 1.0. Persisted entities receive opaque creation-derived IDs;
titles may repeat; dates are not forced into names. Content hashes deduplicate
immutable bytes, while entity identity and duplicate suspicion remain
separate.

## Entry 33 — Make duplicate suspicion a feeding mechanism

Repeated feed was identified as normal rather than exceptional. Duplicate
suspicion became an explainable, scope-sensitive pipeline over canonical
English, type, parent, Nature, Domain, state, recurrence period, history,
and optional attributed semantic evidence. It may propose reuse, quantity
adjustment, merge, enrichment, or separate creation, but it never silently
discards input. Original non-English text remains provenance while canonical
searchable data stays English. No global world-object catalog was added.

## Entry 34 — Separate standing lists from their executions

The grocery example led to standing work. `Buy groceries` may remain one
active priority-positioned Brick whose open entries make it eligible. Each
shopping trip is an execution occurrence: finishing it does not terminally
complete the Brick, unresolved entries remain open, bought entries remain in
history, and an empty list becomes derivatively dormant. Final standing versus
finite grocery configuration and exact run persistence remain open.

## Entry 35 — Bring recurrence and practices into 1.0

Recurrence and desired practices moved from an unreviewed backlog idea into
the 1.0 design. Recurring obligations materialize independent Bricks that
remain open and may become overdue. Practices use expiring opportunities:
unfulfilled intent is recorded but does not accumulate as infinite overdue
work.

The user requested a small motivational game with recent outcomes and streak
consequences. Streaks are derived, and a consequence warning applies when an
action would actually finalize an unfulfilled opportunity. Repeated skips or
failures may produce an introspection review. The core detects patterns; the
powered-up REPL or skill may propose a cause, schedule change, dependency, or
enabling Brick. A blocked practice, such as swimming before finding a pool,
does not accrue false failures or lose its streak.

## Entry 36 — Consolidate the second discovery round

The importance grammar, optional axes, thin operator protocol, Natures,
templates, structured entries, identity, duplicate suspicion, standing work,
recurrence, obligations, and practices were transferred into focused English
chapters. Corrections, invariants, open questions, review paths, and the old
Brick mapping were updated. Code, README, the executable Allium specification,
the operator skill, and Little Ant data remained unchanged.

## Entry 37 — Begin the existing-Brick review

The `Little Ant 1.0` root Brick was created through the v0 CLI. Existing work
will be reviewed one Brick at a time; useful concepts are materialized in this
record before the old Brick receives an explicit terminal disposition.

## Entry 38 — Replace generic Artifact with Raw provenance

The artifacts Brick was reviewed and completed. A generic open-ended Artifact
bag was rejected. Brick description remains direct canonical content. Raw owns
durable material, zero or one external RawOrigin, and immutable RawSnapshots.
A typed RawLink records why a Brick, ListEntry, or another Raw refers to Raw
and, for source semantics, which snapshot that Brick last reconciled.

External check, snapshot refresh, per-Brick reconciliation, and write-back are
distinct. Divergence is derived rather than stored as a boolean. Mirrors,
forks, local drafts, and published copies are separate Raw entities connected
through provenance.

## Entry 39 — Replace consumable with completion-triggered repetition

The consumable Brick was reviewed through the example of reading an article
and revisiting it approximately six months later. Consumption did not justify
another Brick property. The accepted generic Nature is `repeatable`: one
Brick keeps its identity, human priority position, source links, and complete
execution-occurrence history.

Finishing an execution may end the Brick terminally or schedule one later
execution. A repeat assigns the same active Brick a `not_before` calculated
from the completion time, a base delay, and deterministic pseudo-random jitter.
The draw is replay-safe and explainable. Before that date the Brick is
derivatively dormant; afterward it returns to ordinary forecast eligibility
without another binary insertion. There is no implied `best_before`, deadline,
expiry, missed outcome, streak, or backlog. Recurring obligations remain
different because independently unresolved periods require separate Bricks.

`BrickNature` owns these mechanics, while an inspectable template such as
`article_reading` may supply a source role, completion-note convention,
repeat prompt, and default six-month delay with three-month jitter. The
`EffortProfile` is unrelated, and no `BrickShape` axis was restored.

## Entry 40 — Replace queue with collection and make templates discoverable

The generic open-ended child container was renamed from `queue` to
`collection`. Queue was rejected because it implies FIFO or chronological
consumption. A collection contains independently focusable child Bricks in
human importance order, is not progressed toward one parent outcome, and
becomes derivatively dormant when empty. A project remains distinct because it
represents one finite outcome whose descendant scope contributes to closure.

The product may distribute a broad, versioned standard template catalog as
inspectable data while keeping the factory Nature vocabulary small.
`packing_checklist` now names the finite travel or event-packing example, and
`exercise_practice` covers walking, swimming, running, gym work, and similar
physical practices more naturally than `walking_practice` or
`sporting_practice`.

Feeding routes use one shared interaction envelope. Dumb mode browses a
deterministic shortlist; powered-up mode or the operator may rank the same
bounded candidates and propose a concrete route, target, template version, and
inputs. Rejecting a proposal returns to the deterministic flow. The user may
open more templates or enter a custom capability-guided builder. The builder
reuses an existing Nature whenever possible and may save a personal template;
it cannot invent unsupported mechanics.

## Entry 41 — Make RawSnapshot bytes part of the logical dataset

The binary-blob Brick was reviewed after content-addressed RawSnapshots had
already absorbed most of its proposal. The remaining decision separated
logical durability from transport. Every RawSnapshot includes referenced bytes
as part of the Little Ant dataset, and those bytes participate in backup and
synchronization by default. JSONL stores hashes and metadata rather than large
payloads.

A missing or hash-invalid blob is explicit incomplete or corrupted state, not a
valid metadata-only snapshot. An external locator that has not been fetched
remains RawOrigin information. The core owns identity, integrity, references,
and availability, but does not know or depend on Git. Git, Git LFS, Syncthing,
object storage, future on-demand tiering, and similar mechanisms are transport
or adapter concerns. Immutable version history comes from domain events and
content hashes rather than Git history.

## Entry 42 — Make la status canonical without a line flag

The status-line Brick was reviewed against the current implementation, which
already exposes rich structured status and a compact human result but leaves
the skill responsible for some presentation. The intended core ownership was
accepted while the proposed `--line` flag was rejected.

The core owns one typed canonical status summary. Plain `la status` emits its
compact canonical human rendering; `la status --json` returns the complete
typed fields and that same `human` value. The REPL uses the typed fields in its
header or fallback layout, while the operator skill surfaces the canonical
human result instead of recomposing counts. Exact fields, ordering, wording,
timestamp policy, and zero-omission rules remain to be designed.

## Entry 43 — Replace grooming meta-Bricks with guided review

The grooming meta-Brick proposed preparing another Brick through a fixed list
of estimate, dependency, decomposition, and placement steps. That representation
was rejected. Placement now exists from birth, optional fields remain lazy, and
maintenance does not need its own priority, phase, effort, or lifecycle.

The useful remainder became a guided `brick_review` interaction. It may be
invoked manually or proposed by forecast when a mechanical gap could
materially change what happens next. It asks only applicable questions, routes
accepted answers through their ordinary canonical operations, and resumes
through the shared interaction and checkpoint machinery. If it exposes real
clarification, investigation, or enabling work, that work may be proposed as an
ordinary Brick but is never created automatically.

## Entry 44 — Make done direct without fabricating lifecycle history

The old done-from-any-stage Brick assumed `seed`, `committed`, and `ready` and
proposed synthesizing those intermediate transitions. Those stages no longer
exist. The accepted intent is a direct terminal transition from any active
Brick, independent from phase, work state, and optional metadata. Honest
history preserves that no start or preparation event occurred.

Direct completion does not bypass active-descendant reconciliation,
standing-work run semantics, repeatable completion choices, or external-effect
approval. Raw remains outside Brick lifecycle entirely: it has review and
archive axes, not `done`. Natural language may be interpreted into an explicit
Raw operation or real Brick proposal, but the core never materializes and
completes a Brick merely to accept `done` on material.

## Entry 45 — Remove already done as distinct vocabulary

The older already-done Brick added useful interaction and provenance details to
the direct-completion rule. `already done` does not survive as a command,
status, event, completion kind, or skip reason. It is ordinary `done` invoked
without prior start evidence, either by Brick reference or as a context-valid
action when that Brick is served.

The core does not synthesize a zero-duration start; observed duration remains
unknown. All applicable successful-completion, recurrence, practice, streak,
and effect semantics still apply. A human report and externally observed
evidence can lead to the same canonical operation, but their provenance and
authority remain distinct, and external evidence may only propose completion
under the ordinary confirmation rules.

## Entry 46 — Separate canonical titles from matching fingerprints

The old title-normalization Brick assumed that a title had to be trimmed,
lowercased, and stripped of emoji before producing a hash identity. Opaque,
creation-derived identity removes that premise. Titles may repeat and renaming
never changes identity.

The remaining useful concern was split into explicit representations.
Verbatim `original_text` preserves feeding provenance. The human-facing
canonical English title receives only conservative Unicode composition and
whitespace cleanup; case, punctuation, and intentional user emoji are not
silently destroyed. Product-owned status, phase, and warning emoji belong to
rendering metadata and never become title content. Translation or semantic
rewriting retains its author.

Search and duplicate suspicion derive multiple rebuildable matching
fingerprints instead of destructively changing the stored title. Case-folded,
punctuation-insensitive, emoji-insensitive, tokenized, and conservatively
singularized variants may retrieve and rank candidates with different
strengths. They never become identity, global aliases, or authority for a
silent merge.

## Entry 47 — Review finite parents without cascading completion

The parent-completion Brick's original choice was retained and refined.
Closing the last active child never completes the parent automatically. A
finite parent instead receives `review_parent`, whose payload summarizes child
outcomes and decomposition coverage.

When coverage is complete and every relevant child completed successfully,
`done` is the preferred proposal but still requires confirmation. Open
coverage or dropped or superseded children produce a neutral review: the
outcome may already be achieved, missing work may need to be added, or the
parent may remain open. An empty standing collection is different; it becomes
derivatively dormant and does not receive a terminal-completion proposal
merely because it is empty.

If the human confirms the finite parent's completion, its own parent may
become eligible for another `review_parent`. The process advances one explicit
level at a time and never auto-completes an ancestor cascade.

## Entry 48 — Add restricted event-triggered opportunities

Little Ant 1.0 now includes a minimal event-triggered opportunity capability
for standing work. A supported canonical event, such as finishing an execution
of `Have lunch`, may release one opportunity on an existing `Brush teeth`
practice. This does not rebirth, create, start, complete, or reprioritize the
target Brick.

The trigger is inspectable canonical data after any template expansion. It
selects only core-supported source events and release mechanics, contains no
arbitrary script or hidden runtime template code, and is idempotent for the
trigger-rule and source-event pair. Natural-language reports first become
attributed canonical source events; the trigger then follows the same
deterministic path. A manual release, when supported, remains an honest
separate operation rather than fabricated source history.

## Entry 49 — Define standing identity by historical continuity

The recurrence-and-habits Brick was completed after replacing its broad
“rebirth” model with explicit standing-work patterns and a semantic continuity
test. A standing Brick keeps its identity when executions before and after a
change still belong to one honest history and streak. Title, context, method,
location, schedule, cadence, and trigger changes do not alone require a new
identity, and their history does not rewrite earlier occurrences.

When combining histories would misrepresent what was practiced or owed, a
distinct successor is required. Supersession preserves lineage but keeps
occurrence and streak histories separate, disables the old Brick's future
releases, and never silently transfers recurrence rules, triggers,
dependencies, or priority placement. Applicable mechanics require explicit
reconciliation. The core cannot make this semantic judgment.

Similar input for retired standing work enters duplicate suspicion. It may
offer explicit reactivation or separate creation but never resurrects the old
Brick automatically. Exact recurrence syntax, opportunity events, streak
grammar, retirement, reactivation, and supersession mechanics remain in the
open-question register rather than in the completed conceptual Brick.

## Entry 50 — Add attributed location observations

Little Ant 1.0 now includes a minimal location-aware selection model. Bricks
may have hard or soft conditions referring to a named Place. A current
location observation may make compatible physical work eligible, increase its
forecast relevance, or produce a derived grouping proposal without changing
human priority.

The core stores the canonical Place, attributed observation, time, and
validity evidence. GPS, Wi-Fi, Bluetooth, geofence geometry, device permission,
and raw coordinates belong to an optional adapter, which maps sensor evidence
to a configured Place. Manual statements use the same canonical ingestion
path with distinct provenance. Stale observations expire deterministically.

Location evidence never starts, completes, skips, delegates, or resolves work,
and it never sends a silent notification. It is evidence for eligibility and
selection, not authority to act. The design is isolated in chapter 28 so place
semantics do not become ambiguous extensions of dates or generic context.

## Entry 51 — Make @ mentions explicit typed annotations

The old README note proposed treating `@slug` as a reference in every
free-text field. That implicit global parser was rejected. In 1.0, `@...` is
convenient interface syntax whose autocomplete result must be explicitly
selected. Confirmation creates a typed annotation from one owner field and
text revision to an opaque target ID. Ambiguous or unresolved text remains
literal.

Annotations support navigation, backlinks, and search but have no behavioral
authority. Requester, delegation, dependency, parent, `about`, notification,
and other relationships remain explicit core operations. Renaming a target
does not break its annotation, and editing annotated text cannot silently move
the reference to another substring.

Only declared annotation-capable fields participate. Raw remains verbatim and
is never automatically parsed or rewritten; a later explicit annotation over
a particular immutable snapshot may be designed separately. Chapter 29
isolates the concept and leaves exact fields, target types, span encoding,
editing, rendering, and autocomplete mechanics open.

## Entry 52 — Refine plain-text authority and database projections

The README's former “plain text is the source of truth” principle was corrected
after RawSnapshot blobs, REPL checkpoints, and planning manifests acquired
explicit boundaries. The append-only event log is authoritative for
operational domain state, while every referenced canonical blob is also a
required logical dataset member. The log owns snapshot identity and
provenance; it cannot replace missing bytes.

Databases, search indexes, caches, and materialized views are permitted as
disposable, rebuildable projections. They never contain unique canonical
state, never bypass canonical event-producing operations, and fail explicitly
when their authoritative source dataset is incomplete. REPL checkpoints retain
only presentation-recovery authority, and immutable planning manifests remain
outside operational state.

The final README will state this briefly and link to the relevant Markdown
chapter under `spec/little-ant-1.0/`. Allium will specify observable replay,
integrity, and state behavior without prescribing SQLite or file layout.

## Entry 53 — Keep deep design in spec, not docs

The user corrected a transient carry-over from the old README Brick:
`docs/design.md` is no longer the destination for deep persistence design.
The current Markdown design record already lives under
`spec/little-ant-1.0/`, with chapter 30 holding this subject. The final README
links into that specification structure. Only externally observable normative
behavior is later promoted into `spec/little-ant.allium`; no parallel design
document is introduced under `docs/`.

## Entry 54 — Keep dependency outside human priority

The user reaffirmed the existing 1.0 model instead of retaining the README
Brick's old frontier-only ordering explanation. Every active Brick has a human
importance position from birth, including blocked work. Dependency neither
forces blocker-before-blocked priority nor suppresses importance comparisons
between siblings.

Forecast and `next` exclude blocked execution while allowing the blocker to
gain pressure for unlocking important work. When the dependency resolves, the
Brick becomes eligible at its existing position without binary insertion. The
future README must explain this distinction with a concrete priority-versus-
eligibility example.

## Entry 55 — Supersede the old README brief with an English 1.0 deliverable

The README-rewrite Brick was reviewed rather than falsely completed. Its
useful feedback was absorbed into the 1.0 specification: progressive
disclosure, named Place observations, typed `@` annotations, event-and-blob
authority, rebuildable projections, core/operator/adapter ownership, and the
correct separation of human priority from dependency eligibility. Legacy
stage, hour-estimate, title-hash, collision, frontier-only, and arbitrary
`on_done` assumptions were rejected.

Because the actual README rewrite remains future work, the old Portuguese
Brick `ed8176f` was promoted as required by the v0 lifecycle and superseded
with committed English Brick `39959b4`, `Rewrite the Little Ant 1.0 README
with progressive disclosure`. Its description records the reviewed contract.
The successor is scheduled conceptually after the final review and Allium
revision, but before coding; no README content was changed during this review.

## Entry 56 — Replace the mixed skill checklist with a thin operator deliverable

The ten-item skill Brick could not be applied as one coherent 1.0 checklist.
Its valid concerns were retained in corrected form: free-form and focus-trigger
interpretation, canonical English product data, concise progressive
disclosure, resumable interactions, and ranked reference proposals. Structural
or authoritative inferences still require confirmation.

Several v0 assumptions were rejected. The skill will not own a duplicate
command or shortcut catalog, ordering and served-work skips remain distinct,
text mentions resolve through explicit typed annotations to opaque IDs, and
entity identity no longer depends on title hashes. Product-owned emoji belong
to rendering metadata, while intentional user content is preserved.

Channel mechanics such as voice duplication, Telegram keyboards, Markdown
dialects, and mobile layout belong to presentation adapters or manifests.
They consume the same core interaction envelope and cannot redefine its
actions or semantics. The skill remains a thin English bootstrap that obtains
state-scoped actions, canonical commands, shortcuts, status, and deeper help
from the core on demand.

Because the actual skill rewrite remains future work and must not describe a
command surface that does not yet exist, old Brick `6b212ab` was promoted as
required by the v0 lifecycle and superseded by committed English Brick
`f278949`, `Rewrite the Little Ant 1.0 operator skill from the canonical
interaction contract`. It inherited `82e789d` and `86e68cf` as blockers so
interrupted-round and annotation details can be reviewed separately. No
operator-skill implementation was changed during this review.

## Entry 57 — Resume interactions without inventing work or progress

The interrupted-round Brick was accepted only after correcting three
overstatements. A frozen ordinal cursor is not canonical domain state, but
replay information for an observable pseudo-random prompt may still need to be
recorded. A round is not represented by a meta-Brick, yet an atomic multi-step
operation may persist the minimum provisional domain state required by its
invariants. Progress is derived, but an exact `12/20` display is valid only
when the finite denominator is actually known.

Every confirmed answer is appended immediately through its ordinary domain
operation. Resuming asks the core for a new state-scoped interaction envelope,
which may legitimately choose a different useful prompt after concurrent
changes while retaining all prior evidence. A response bound to a stale prompt
cannot be applied to another question, and no “continue round” Brick is
created.

Unsubmitted text, the editing cursor, current screen, and local transcript
belong to the surface checkpoint. They do not silently update a Brick
description or another canonical field. Explicit confirmation creates the
domain revision; a future synchronized draft feature would require a separate
explicit operation. Chapter 31 now holds the cross-surface contract, with REPL
recovery and proposal chapters linking to it.

## Entry 58 — Keep Party identity opaque and human rendering readable

The readable-Party-slug Brick was rejected as an identity design while
preserving its usability concern. Curating a Party does not justify making a
human word authoritative. Names change, different Parties may share a name,
translations vary, and an alias chain would turn mutable vocabulary into
permanent core identity.

Every Party therefore receives an opaque immutable ID. It has a mutable
canonical display label and may later support alternate names or nicknames for
candidate retrieval. Those labels may overlap and never become global IDs,
unambiguous command aliases, or automatic text bindings. Mutating operations
resolve ambiguity through opaque identity, context, or explicit selection.

Canonical events retain IDs. Human renderers and inspection projections show
the current label with enough disambiguating context, so event-log readability
does not require readable identity. The `@...` surface remains autocomplete
syntax: explicit selection creates a typed annotation to the Party ID, and
renaming the Party does not break that reference or require an old-slug alias.

## Entry 59 — Make mention sigils explicit and external tracking typed

The mention-grammar Brick retained `@` and `#` only as narrow editor
affordances. On an annotation-capable surface, `@` opens Party candidates and
`#` opens Brick candidates. Selecting a candidate explicitly creates a typed
annotation to its opaque ID. A visible title or label is historical rendering
data rather than identity or a checksum.

No global parser scans prose. Text such as `issue #918`, `github:@alice`, an
email address, or an unresolved autocomplete token remains literal. This
removes the apparent collision between Brick IDs, GitHub issue numbers, social
handles, and ordinary punctuation without inventing format-based heuristics.
An explicit CLI short reference remains a separate command-surface concern.

External references also split by intent. A URI may remain ordinary clickable
text. If its content must be fed, refreshed, synchronized, or reconciled,
the user confirms creation of Raw with RawOrigin and the applicable RawLink.
Provider-specific normalized locators may exist inside adapter contracts or
import keys, but `github:`, `gmail:`, and `gchat:` do not become a universal
public grammar whose appearance in prose changes domain state.

## Entry 60 — Keep date pressure visible without warning spam

The date Brick confirmed three independent meanings: `not_before` is a hard
eligibility boundary, `best_before` is a soft preferred-completion target, and
`deadline` is a hard limit. Their pressure contributes to forecast, next,
status, and planning but never changes the human priority tree.

The proposal to print the same inline warning on every auto-ticked command was
rejected. Crossing a meaningful date threshold creates one idempotent notice
occurrence keyed by the Brick, date field, date revision, and threshold.
Repeated ticks while that condition remains true do not append duplicate
events or permanently prepend a banner to unrelated command results.

The ongoing condition remains visible in status and forecast. Acknowledging or
snoozing its notice affects presentation only and cannot change the date,
eligibility, priority, or pressure. A changed date is a new revision; a later
threshold may create a distinct occurrence. Date notices never authorize an
external notification without ordinary approval.

## Entry 61 — Separate external feeding, adoption, source views, and packs

The external-TODO Brick exposed an obsolete absolute rule: imported material
does not need to stop in one mandatory Raw-only extraction funnel. External
content is still fed as Raw with stable RawOrigin identity and immutable
snapshots, but a configured structured-task source may atomically adopt that
feeding into a positioned Brick or ListEntry. Unknown, mixed, ambiguous, and
note-like sources remain pending Raw; reviewing one note may produce zero, one,
or many Bricks.

Every automatically adopted Brick has a strict position from birth. A
confirmed ImportProfile or attributed judgment may assign a provisional
position with low priority confidence, which creates future comparison
pressure. External list order never becomes human importance. Reimporting a
stable upstream identity refreshes and reconciles the same Raw and adoption,
while semantically similar but differently identified material uses ordinary
duplicate suspicion.

Provider, account, and external-container grouping is a derived source view
for filtering, synchronization, reconciliation, and triage. It is not an
automatic RawShelf. A confirmed ImportProfile may separately map a source to a
semantic RawShelf, Brick parent or collection, ListEntry owner, template, and
field policies. Profile changes never silently move existing work.

Little Ant 1.0 now explicitly includes the provider-neutral import framework.
Concrete authentication, pagination, and field translation belong to
adapters. Microsoft To Do, Apple Reminders, Google Tasks, GitHub Issues,
Notesnook, Evernote, Todoist, and other providers form an extensible connector
catalog rather than core branches or an assertion that every connector blocks
the first release.

The selected extension unit is `Little Ant Pack`, with the recommended open
community repository `little-ant-packs`. Packs may contain declarative
Natures and templates, executable importers, attributed enrichers, and
credential-free ImportProfile presets. The core retains schemas, capabilities,
validation, permission enforcement, replay, and all domain authority.
Data-only and executable components have distinct trust classes; installing an
adapter never grants implicit write-back or unrestricted access.

## Entry 62 — Return sparse typed postconditions instead of full entities

The mutator-output Brick began from a real round-trip problem: several v0
commands returned only events or a boolean, forcing another `show` to learn the
resulting Brick state. Its proposed remedy, echoing the complete Brick from
every mutator, became counterproductive once the complete JSON was inspected.
The current Brick view includes every optional null, neutral boolean, zero
counter, empty relationship list, and full event payload, all of which can
unnecessarily consume operator context.

Little Ant 1.0 instead returns a command-specific compact postcondition. It
identifies affected entities, relevant resulting state, semantic changes, and
a revision suitable for stale-response protection. Non-empty spawned work,
pending effects, notices, and warnings remain visible. A caller does not need a
follow-up query merely to establish what the mutation did, but descriptions,
complete relationships, and audit history are retrieved only when requested.

Operational JSON is sparse by schema rather than by one recursive
“remove falsy values” pass. An optional inapplicable value may be omitted, and
an unrelated empty collection need not appear. Meaningful false or zero
answers, explicitly requested empty collections, selected tri-state values,
and explicit clearing outcomes remain present. A missing sparse field means it
was not emitted by that projection unless its schema declares a specific
default; absence has no universal null, false, zero, or empty meaning.

State, projection, and serialization remain separate. The event log and
replayed domain state retain authority; named sparse and complete projections
derive from them. Full events are explicit audit output, while every actionable
command or lazy-tick outcome must still be surfaced through the typed result,
notice, status, or interaction envelope. The REPL may request a complete
StatusSummary while the ordinary operator receives only decision-relevant
status fields, without creating two semantic status models.

## Entry 63 — Separate synchronization, migration cutover, and source cleanup

The sync-round Brick was reviewed against the import model. One monolithic
skill-owned “sync round” would mix deterministic provider observations,
semantic judgment, Brick lifecycle, and external effects. Little Ant 1.0
instead keeps provider-neutral identity, observation history, reconciliation,
migration verification, and effect approval in the core. Adapters translate
provider pagination, deltas, tombstones, and writes. The operator or powered-up
REPL contributes semantic judgment only where a deterministic route is
insufficient.

External completion and external presence are independent observations.
Provider completion evidence may propose ordinary `done` with provenance.
An authoritative deletion signal records that the source object was removed;
it cannot complete, drop, archive, or delete local state. Filter omissions,
inaccessible credentials or containers, failed checks, and ambiguous provider
responses do not prove deletion. Unexpected mass removal pauses
reconciliation and raises one source anomaly instead of cascading lifecycle
changes.

An active ImportProfile may authorize visible recurring read-only checks and
feeding. Migration has an explicit cutover: feed and adopt, review and
verify, prepare cutover, optionally clean the source, finalize cutover, and
retire the profile. Retirement disables scheduled checks and suppresses
ordinary freshness pressure without discarding RawOrigins, snapshots, links,
stable external identities, local work, or the immutable migration receipt.

The proposed `erase-after-import` option was accepted as a destructive
migration policy, not as ordinary sync. The selected scope is durably fed,
fully dispositioned, verified, previewed, and approved before deletion begins.
The Adapter requires a separate source-deletion capability and executes
provider calls, but the core owns scope and eligibility. Cleanup remains
logically item-scoped and records each outcome even if transport is batched.
Partial failure is resumable; cutover cannot retire the profile while selected
items remain unresolved. Removing an emptied external list is a separate
effect. At no point does a cleanup deletion imply that the corresponding Brick
was completed.

## Entry 64 — Define typed Lua Packs, credential brokering, UI adapters, and a reference TaskJuggler exporter

The extension discussion rejected a generic Plugin abstraction before it
could become another ambiguous core concept. `Little Ant Pack` remains the
single versioned distribution unit, while every contained `PackComponent` has
one closed host contract. Declarative components are BrickNature,
BrickTemplate, and ImportProfilePreset. Executable components are
SourceAdapter, Enricher, ReadOnlyExporter, and UIAdapter. Packs cannot replace
ranking, forecast, storage, entities, events, commands, or replay, install
arbitrary lifecycle hooks, or own background schedulers.

Lua 5.4 through HsLua was selected as the only first-class executable Pack
runtime for 1.0. The Pack remains a bundle of declarative assets and typed Lua
entry points, not arbitrary trusted code. Every invocation, including an
official standard-Pack component, uses a fresh Lua VM in a separate
`lant-pack-runner` process with bounded time, instructions, memory, output, and
capabilities. There is no in-process exception. Unrestricted `io`, `os`,
`debug`, raw sockets, dynamic C modules, LuaRocks installation, and hidden
subprocess access are excluded; pure-Lua dependencies are vendored and hashed.
Replay consumes the previously accepted events and never reruns Pack code.

HTTP is a host capability rather than a Lua ecosystem dependency. Pack code
uses one synchronous `lant.http.request` table contract. The host owns TLS,
encoding, JSON, redirects, cancellation, safe retries, rate limiting, response
limits, structured transport errors, and redaction. A component declares exact
allowed hosts, and redirects cannot escape that set.

Credentials use a Little-Ant-owned encrypted local vault. A shared Pack
declares typed credential slots, scopes, endpoints, and hosts; a local
CredentialBinding selects the vault entry and account. The CredentialBroker
supports OAuth authorization code with PKCE, OAuth device authorization,
bearer or API-key credentials, and no authentication. It performs login and
refresh and injects credentials into host HTTP, so Lua never receives the
secret or token. A working `la vault unlock` surface activates a local memory
agent for an idle period. A locked vault leaves a scheduled source check due
with `credential_locked` instead of fabricating provider failure or backoff. The
exact cryptographic format, master-key and recovery design, rotation,
revocation, timeout, and IPC hardening remain open; ordinary dataset sync does
not include the vault, and transfer requires explicit encrypted export.

`ReadOnlyExporter` was added as a pure serialization boundary. It receives a
versioned core projection and returns bytes, media type, suggested filename,
warnings, and metadata without filesystem, network, subprocess, or mutation
access. A surface owns writing or publishing. The standard Pack shipped with
1.0 must include a TaskJuggler exporter written in Lua. The core still owns
effort semantics, the confirmed non-overlapping planning cut, stable IDs,
planning projection, validation, and immutable manifest; Lua owns only `.tjp`
serialization. Its source, manifest, fixtures, conformance tests, and failures
serve as the canonical reference for community component authors. Importing
TaskJuggler actuals remains a separate SourceAdapter.

The proposed UI extension was also accepted for 1.0 as `UIAdapter`. It renders
the same canonical InteractionEnvelope used by the first-party REPL and maps a
channel response back to exactly one action ID plus the interaction revision.
It may own transport, presentation, buttons, pagination, and surface-local
checkpoints, but cannot invent commands or shortcuts, weaken approvals, mutate
state, keep tokens, or apply stale answers. Configuring a personal UI channel
allows ordinary product interaction on that channel; arbitrary recipient
messages and publishing remain explicit external effects. The first-party
REPL stays a core surface, while the exact initial Pack-based UI adapters
remain an implementation-planning choice.

## Entry 65 — Begin commit-backed recovery and remove ambiguous priority

After the first attempted 1.0 implementation regressed important v0 behavior,
the recovery process was changed to record and commit each confirmed decision
immediately. This prevents context compaction or a later consolidation from
silently inventing answers. The current v0 operator skill, v0 implementation,
rewritten Allium, generated tests, and failed implementation are evidence to
audit; none overrides an explicit 1.0 recovery decision.

The word `priority` was removed from the canonical 1.0 vocabulary because it
could mean persistent importance, urgency, execution order, or dynamic
selection. The working separation is now importance order, focus forecast,
and next suggestion. The old word may appear only in explicitly historical
v0 material or literal external-source vocabulary. A natural-language
operator must disambiguate rather than introduce a core alias.

The dynamic focus forecast was confirmed as a derived probability
distribution. `next` performs a weighted pseudo-random draw whose result is
reproducible from authoritative state, the candidate set, recorded random
evidence, and the applicable configuration revision. A useful long tail gives
unusual eligible work a chance to surface. The LLM comparison is an intuition
for weighted sampling, not a requirement for a normal distribution or a
particular formula.

Calibratable selection parameters should have validated factory defaults, be
revisable over time, and be identifiable by configuration revision so tests
can compare parameter sets without changing semantic invariants. A
human-editable YAML profile and exact tail controls remain proposals pending
further review.

## Entry 66 — Give every eligible Brick a positive draw chance

The long-tail direction was made exact. A hard eligibility rule excludes a
Brick from the ordinary work lottery and gives it probability zero. Every
Brick that remains eligible and enters the lottery must have probability
strictly greater than zero, however small. Soft scoring, normalization, and
tail calibration cannot silently turn an eligible Brick into an excluded one.

This requirement does not yet promise that every Brick will be served within a
bounded number of draws. The exact hard eligibility conditions, tail
allocation, and any future bounded-service guarantee remain open.

## Entry 67 — Put project context behind `?` and scope decomposition by Nature

The minimal `next` prompt no longer needs a separate `open project` action.
The existing universal `?` interaction is the single progressive-disclosure
entry point: it may reveal the pending suggestion's explanation, ancestry,
project or collection context, children, blockers, evidence, and navigation.
All relevant context remains reachable without dumping an unbounded projection
or history, and leaving the view restores the same suggestion without a draw,
answer, skip, or mutation.

Hierarchical selection follows the Brick's resolved Nature. Project-like
finite outcomes normally lead to an eligible descendant; when none exists,
reviewing or decomposing the outcome may itself be proposed. Decomposition is
not inferred from a high-level title and is not applicable to every Brick. The
operator skill or powered-up REPL may propose a Nature or template, while
the dumb REPL uses the same bounded core candidates. The selected concrete
Nature remains explicit and core-validated.

Blocked-work selection was discussed but not settled. The working proposal
keeps a blocked Brick out of executable results while preserving it as blocked
demand: that demand may add bounded, explainable pressure to an actionable
blocker and may occasionally create a distinct review or reminder proposal.
Exact behavior for chains, multiple blockers, external waits, cycles,
attenuation, and caps remains open.

## Entry 68 — Require truthful blocker provenance and complete Brick labels

The desired blocked-work interface was made concrete without prematurely
choosing the internal probability model. When blocked work causes an
actionable blocker to become the next suggestion, the rendering identifies the
actionable Brick, its containing Brick when relevant, and a causal explanation
that names both the blocked Brick and blocker.

Two internal models remain open. Little Ant may first sample an attention
Brick and redirect a blocked result through its dependency, or it may derive
and aggregate blocker pressure before sampling an actionable result. The first
can truthfully say “I was going to suggest the blocked Brick”; the second must
say that the blocker was suggested because it unlocks the blocked Brick.
Structured provenance must support the truthful explanation in either case.

The canonical compact Brick label was reaffirmed as
`#shortid "Canonical English title"`. Product renderers, specification
examples, and operator commentary use the full label for every particular
Brick, including a parent shown under `Within`; bare titles and bare short IDs
are insufficient. The opaque immutable ID remains authoritative.

Emoji design was deliberately left open. The former seed glyph `🌱` is a
candidate for the optional `idea` phase without restoring the removed `seed`
lifecycle. A later review must define a non-ambiguous marker grammar for
independent phase, status, focus, WIP, blocking, and confidence.

## Entry 69 — Resolve drawn work through N blockers and correct phase recall

The user selected the draw-then-resolve model and corrected its depth. It is
not a two-step special case: a drawn Brick may be blocked by another Brick
that is itself blocked, producing an N-step dependency path. Dependency
blocking alone does not remove an otherwise admitted active Brick from the
initial attention draw. If `B0` is drawn, Little Ant records and follows
`B0 -> B1 -> ... -> BN`, where every Brick is blocked by the next and `BN` is
the actionable result. Effective blocker pressure emerges from redirected
attention mass instead of a separately stored mutable field.

The interface therefore preserves the initial draw and ordered blocker path,
not only the endpoint. `Next` renders `BN`, `Within` renders a relevant
containing Brick when applicable, and `Why` names `B0` and every displayed
dependency step. `?` exposes the complete path without consuming another draw.
Multiple immediate blockers, branches, external or temporal endpoints,
composition with project descent, and compact folding remain open.

The user also corrected the preceding emoji note: the former seed glyph `🌱`
had already been abandoned and is not a 1.0 phase-marker candidate. Inspection
of the durable record found the phase set
`idea | spec | exec | validation`; `spec` already meant planning or
specification and had an unresolved design/planning icon. The user then
explicitly reaffirmed `spec` as the canonical value. `design` is not a second
phase or alias; a clipboard, drafting, ruler, or similar design-tool glyph
remains only a visual candidate for `spec`.

## Entry 70 — Fix the `spec` marker as `📐`

The user selected `📐` as the exact canonical renderer marker for the `spec`
phase. The broader marker grammar and the markers for `idea`, `exec`,
`validation`, terminal status, focus, WIP, blocking, and confidence remain
open. `design` remains only a description of the visual metaphor; it is not a
phase value or alias.

## Entry 71 — Use weighted subdraws at dependency branches

The user confirmed that an N-step dependency path does not collapse a
branching dependency graph into a fixed first edge. When the current path node
has several unresolved immediate Brick blockers, Little Ant performs a
replay-deterministic weighted subdraw among the admitted branches. Every
admitted blocker has strictly positive probability, and the selected edge and
random evidence become part of the recorded resolution path.

Unchosen blockers remain unresolved. The compact `Why` rendering shows the
selected path, while `?` exposes the other immediate blockers considered at
each branching step without redrawing or changing the pending suggestion. The
exact subdraw weights, normalization, random-stream derivation, configuration,
and probability treatment of reconverging branches remain open.

## Entry 72 — Reuse the focus-forecast weighting function locally

The user confirmed that dependency-branch subdraws must not introduce another
ranking or scoring formula. They reuse the same weighting function as the
focus forecast, evaluate it for the admitted immediate blockers, and normalize
the resulting weights within that local branch set. Replay evidence derivation
and the generic forecast function's eventual calibration remain open.

The user also corrected the discovery granularity: subsequent questions should
prioritize decisions that materially shape the core model, public UI, or the
authority boundary between them. Mechanical consequences and low-risk
calibration details should normally be derived from confirmed principles and
recorded as implementation questions rather than consuming interview rounds.

## Entry 73 — Close the `next` result type, not its current inventory

The user confirmed that `next` selects one member of a versioned closed set of
core-defined focus-opportunity variants. A public catch-all command named
`interaction` is rejected, and Natures, templates, Packs, powered-up mode,
and the operator cannot invent new fundamental variants or canonical actions.

The examples in the preceding discussion were not exhaustive. The exact 1.0
catalog still needs a macro-level decision informed by the proposal inventory
already present in the specification.

The user also replaced the proposed importance-comparison presentation. The
primary UI asks the concrete proposition:

```text
Next: Is

      #a12345 "Launch the landing page"
      (>>) more important than
      #b45678 "Interview prospective customers"
?

  [y]es · [n]o · [s]kip · [?]
```

A large `Why` section is unnecessary for this self-explanatory prompt.
Provenance remains structured and available through `?`; a capable surface may
show a subtle summary in an optional status region.

The user emphasized that concrete mini-simulations make macro decisions easier
to evaluate. The REPL's UX and UI are therefore the 1.0 reference interaction
design. Later web and mobile surfaces, UIAdapters, and the operator skill
preserve the same domain prompts, action semantics, information hierarchy, and
progressive disclosure while adapting physical controls and layout.

## Entry 74 — Stabilize response grammar and pre-order provisionally

The user refined the focus rendering:

```text
Next:

    #c12345 "Write the migration specification"
    Within: #a12345 "Recover Little Ant v1"

    Focus?

    [y]es · [d]one · [s]kip · [?]
```

The explicit proposition keeps `y` as ordinary confirmation rather than
giving it a screen-specific label such as `focus`. The user requested the same
grammar and the same letters for the same meanings across screens wherever
possible. `y` confirms, `n` rejects, `d` completes, `s` skips, and `?` requests
context or help. An unavailable action is omitted rather than assigning its
letter another meaning. Approval prompts therefore prefer `yes` and `no`
instead of labeling the same letters `approve` and `decline`.

The user accepted the concrete review shape and asked whether importance
questions would already benefit from skill or powered-up pre-ordering. The
existing authority model answers yes: the active operator skill or powered-up
REPL adapter may submit attributed AI comparison evidence before a human
placement prompt. The core still owns and validates binary insertion, records
the resulting position as provisional, and preserves the evidence in recap,
history, and inspection. Human judgment remains stronger and may later
recalibrate the local order. Dumb mode, adapter failure, or model abstention
falls back to the ordinary human insertion question.

The skill and powered-up adapter are alternative surface-specific judgment
providers. The deterministic core never invokes the skill itself.

## Entry 75 — Put every new opportunity kind in one lottery

The user confirmed that approvals, delegation follow-ups, reviews, questions,
and executable work do not occupy fixed precedence lanes. Every newly
selectable opportunity participates in the same replay-deterministic weighted
draw. Type alone grants no priority; urgency, aging, accumulated pressure, and
other forecast evidence may change weights. Status still exposes pending
counts when a different opportunity wins.

Only genuine continuity and validity happen first. An already pending
interaction resumes with its identity and revision, and an active current
focus resumes while it remains in progress. Neither is a new candidate. A
consistency failure that prevents a valid forecast or mutation stops the draw
with an explicit diagnostic and is not represented as a focus opportunity.

This supersedes the earlier working precedence list that placed effects,
messages, or overdue follow-ups ahead of the ordinary lottery.

## Entry 76 — Restore hierarchical forecast semantics

The user recalled that the intended 1.0 forecast was hierarchical, consistent
with both the composition tree and the recently proposed subject-first
selection model. Repository history confirmed that the pre-propagation
Markdown made importance and composition hierarchical but left the exact
forecast formula open. The recovery ledger had already restored
Nature-aware descent from a selected project-like container. The propagated
Allium nevertheless represents `ForecastItem` values in one flat list and
draws directly from that list.

The user confirmed the missing semantic boundary: the focus forecast is not a
flat lottery in which one subject gains another top-level ticket for every
applicable question, review, or executable action. Each admitted attention
subject participates once in its applicable scope. Selection then performs a
replay-deterministic weighted local subdraw among that subject's admitted
opportunity variants. Project-like containers add recursive, Nature-aware
child-scope draws rather than flattening all descendants.

The previously confirmed “one lottery for every opportunity kind” rule remains
in force. It means that type creates no fixed precedence lane; it does not
collapse the hierarchy. Exact weight aggregation, container allocation,
normalization, and ordering relative to dependency resolution remain open
calibration and protocol questions. The Allium and generated tests are
therefore divergent on this point and must be corrected only after the
recovery discussion is complete.

## Entry 77 — Aggregate subject signals and reopen organizational context

The user selected the strongest-signal-plus-bonus model for a subject's
top-level forecast weight. The strongest applicable opportunity signal anchors
the weight; additional independent reasons may add a bounded bonus with
diminishing returns. A flat sum, duplicated proposal, or artificial
fragmentation cannot manufacture extra tickets. Exact curves and caps remain
calibration rather than conceptual decisions.

Reviewing examples such as `Orbit / R&D / Antifraud` exposed another gap. The
v0 implementation gives slash-separated context strings prefix semantics, but
the propagated v1 Allium retains only one optional string plus nearest-ancestor
inheritance. It defines no classification entity, hierarchy, recursive list or
count query, or multiple membership.

The user confirmed that one Brick may belong to several branches of the future
hierarchical organizational-classification model and expressed doubt about
the name `Area`. The canonical name therefore remains open. This model is
orthogonal to the Brick composition tree and to execution conditions such as
Place and mode.

The working classification flow keeps feeding lazy. The core retrieves and
validates bounded candidates; a skill or powered-up adapter may rank several
existing candidates with attributed judgment, while dumb mode uses only
deterministic evidence such as an explicit current branch, parent membership,
or ImportProfile mapping. Unknown classification never blocks preservation of
input. Whether a high-confidence assisted suggestion may be attached
provisionally without a glance remains for user confirmation.

## Entry 78 — Separate required Nature from optional Domain membership

The user rejected the remaining product vocabulary based on “capture” and
required `feed` or `feeding` throughout commands, responses, specification,
tests, and implementation. The v1 propagation must rename `Capture*`
declarations and use more precise terms for snapshotting, observation, or
import where those operations are not product feeding. The core provides no
compatibility alias.

The previous classification discussion concerned Domain membership, not the
Brick's behavioral type. The user clarified that behavioral classification is
core and mandatory from birth, prefers the name `Nature`, and requires a
fallback when the user skips. A Nature may be supplied explicitly, implied by
a selected template, or proposed by the skill or powered-up adapter; otherwise
the Brick uses the generic `standard` Nature.

`Domain` was accepted as the current working name for hierarchical,
non-exclusive organizational membership. Domain assignment remains distinct
from required Nature selection.

The user also confirmed cognitive continuity as a forecast input. After
accepted work in one Domain, subjects sharing that Domain receive a bounded
soft bonus until an explicit switch or another defined transition. A displayed
or skipped suggestion does not switch Domains, several shared memberships do
not manufacture tickets, and unrelated eligible work retains positive
probability.

A grocery item illustrates a separate concern. It should normally be a
ListEntry under standing grocery work and therefore never surface
independently. The owning Brick may gain time-window, recurrence, deadline, or
Place pressure through generic mechanics. Exact recurring preferred-time
windows remain open.

## Entry 79 — Confirm BrickNature as the sole behavioral classification

The user confirmed the integral rename. `BrickNature` is the one required,
versioned core concept, and `nature` is the Brick field. A parallel behavioral
entity or field would duplicate semantics and is forbidden. The chapter and
conceptual Markdown now use the confirmed name; the current Allium, generated
tests, skill, and implementation remain explicitly divergent until the
controlled propagation phase.

## Entry 80 — Make Domain continuity explicit without another prompt

The proposed preliminary `Switch Domain?` dialog exposed an ambiguity between
rejecting a context transition and skipping the served Brick. The user
confirmed the simpler model: a cross-Domain result remains the ordinary
`Focus?` interaction and visibly includes the prospective Domain transition.
`y` atomically starts focus and changes the persisted active Domain; `d`
completes directly without changing it; `s` records the ordinary served-work
skip and cooldown, preserves the active Domain, and returns to a global draw;
`?` explains the result. `n` is omitted because it would duplicate skip.

Continuity is hierarchical rather than exact-label matching. The default
structural affinity between active and candidate Domains is the depth of their
lowest common ancestor divided by the larger path depth. An exact branch is
strongest, related subdomains retain progressively smaller bonuses, and an
unrelated top-level branch has no continuity bonus but remains eligible. A
multiply classified Brick uses its strongest affinity; memberships never
manufacture extra tickets. The affinity scales one bounded signal in the
strongest-signal-plus-bonus model, while intensity, cap, and temporal decay
remain calibratable.

## Entry 81 — Narrow accepted focus into a specific subdomain

The user confirmed that accepted focus should refine a broad active Domain when
the Brick belongs to a more specific descendant. With `Orbit / R&D` active,
focusing a Brick classified under `Orbit / R&D / Rock Splitter` changes the
active Domain to that descendant even when the Brick also belongs to an
unrelated branch such as `Research / Fraud Detection`. This records the
specific cognitive context actually entered. Equal-specificity descendants
and transitions with no ancestor-descendant relationship remain open rather
than gaining an unreviewed tie-break rule.

## Entry 82 — Separate skip symptoms from their remedies

The user corrected the proposed skip flow. A skip is a symptom report, not an
action such as changing subject. The first bounded screen must show several
applicable symptoms together; only after one is selected may another screen
propose a reaction. Symptom evidence and accepted remediation remain separate.
The user also restored the earlier intended replacement of vague `meh` with
`fear`, which the existing conceptual record had incorrectly left as an open
possibility.

Finite-choice labels expose shortcuts inside their actual English words:
`[s]kip`, `[c]hange subject`, or `e[x]change` after a collision. Unrelated
prefix letters are not allowed, and `[?] dunno` is only an exceptional fallback
to avoid. The user accepted a short Domain-subtree cooldown followed by a
bounded decaying negative forecast signal when a later confirmed reaction
applies the symptom to that scope. Choosing the symptom alone performs no
Domain transition or remediation.

## Entry 83 — Refine skip grouping and make `?` mean uncertainty

The user separated work that feels large from work that feels difficult but
rejected the duration claim in `too long`; the symptom became `big`, rendered
as `bi[g]`. Timeless `not_priority` wording became `[n]ot important now`,
allowing its importance to change later. Shortcut reuse across screens is
intentional because only the currently visible screen owns its one-key
namespace. Similar symptoms share visual rows without becoming one action.

The user also corrected the universal `?` mental model. It is visibly labeled
as “I don't know” or an equivalent human-uncertainty phrase and opens
contextual assistance for the pending decision. It is not merely unlabeled
system help. A second `?` from inside that assistance screen opens Little Ant
help, producing an effective `??` help gesture. The distinction between
external waiting and actionable blocking, and whether `done` is repeated on
the symptom screen, remain for the focused screen discussion.

## Entry 84 — Split external waiting from actionable blocking

The user confirmed that the symptom screen distinguishes `[w]aiting` from
`bloc[k]ed`. Waiting means an unresolved external person, event, or condition
for which no directly actionable work is currently known. Blocking means a
representable missing prerequisite such as another Brick, information, access,
or material. The latter may lead to a subsequent proposal for a Dependency or
enabling Brick, but symptom selection itself performs no remediation.

The focus screen keeps its direct completion action, and the symptom screen
repeats `[d]one` in a visually separate “Already finished?” region. This is a
recovery affordance for work that was already completed, not a skip reason:
it records completion without skip evidence, cooldown, or avoidance pressure.

## Entry 85 — Separate screen navigation from append-only undo

The user accepted a split between presentation navigation and semantic
reversal. `Escape` closes an uncommitted screen, while `Backspace` remains text
editing. `C-_` and `/undo` reverse the latest reversible action in the current
interaction by appending a typed compensation; `C-M-_` and `/redo` reapply the
intent only if it remains valid. Explicit event selection is required across
sessions or surfaces, recorded randomness is reused instead of redrawn, and
external effects are never silently claimed to be reversed.

The user also accepted a less dense interaction hierarchy. The main region now
contains only the cited subject, concrete question, and valid answers.
Composition, Domain, warnings, provenance, and compact statistics move below a
visual separator into a sparse context region. Paths read broadest to most
specific, empty rows disappear, one warning slot shows an additional count,
and at most one statistics line uses the Little Ant mascot `🐜`. Exact warning
rotation remains open for the next discussion.

## Entry 86 — Keep review as discreet orchestration

The user confirmed that review should not become a visually prominent fifth
screen type. A guided review sequences ordinary concrete interaction layouts,
while its identity and honest progress remain a discreet line in the
secondary context region. The line may show known facts such as answers
accepted in the session, but must not claim a fixed total for an adaptive
question flow.

## Entry 87 — Restore defaults and start a capability regression audit

The user rejected the working generic “Proposition” layout and noticed that
the preceding screen review had lost `*`, a useful v0 grammar marker. Repository
evidence confirmed its exact former contract: it marks a suggested action, a
bare `*` accepts that action, and no default appears when there is no basis to
guess. The marker is now restored as a cross-surface 1.0 invariant while its
authority and risk policy remain open.

The same check exposed a broader specification-pipeline failure. The current
formal garden structurally validates, but contains no suggested-default or
adaptive `org-sort-tasks` mechanics. Its `OneKeyFiniteChoices` promise is only
a guarantee and produces no generated obligation. The failed v1 CLI reduced
64 v0 parser entries to 15 without a capability-by-capability disposition.
Chapter 36 now records an independent audit that separates valuable behavior
to restore, stronger 1.0 replacements, deliberate removals, formal drift, and
still-unreviewed capabilities. This does not revive compatibility aliases or
obsolete concepts.

## Entry 88 — Split comparison from confirmation

The user accepted the assertion-style importance comparison and rejected
“Proposition” as one generic layout for unrelated decisions. The primary
grammar set is now focus, comparison, confirmation, choice, and input.
Comparison states the relation between two cited peers and asks `Is that
right?`; confirmation presents one proposed action or effect and its required
preview. Guided review continues to orchestrate ordinary screens discreetly
instead of becoming a sixth type.

The reference comparison shows `#A "..." is more important than #B "..."`,
then `*[y]es`, `[n]o`, `[s]kip`, and `[?] I don't know`. `No` records the
reverse strict direction, while the shown default remains conditional rather
than a permanent bias toward yes.

## Entry 89 — Expose two residual v0 policy questions

Completing the capability audit found two smaller v0 behaviors not represented
in the 1.0 record. The answer namespace included `[l]ater` and required the
resulting absolute date to be shown. The operator policy also kept canonical UI
and data in English while composing outbound messages in the recipient's
language. Neither behavior is restored implicitly: generic `later` may
conflict with context-specific skip, snooze, defer, and `not_before`, while
recipient-language choice belongs to an attributed operator or adapter rather
than deterministic core semantics.

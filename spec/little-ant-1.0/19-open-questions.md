# 19. Open questions

These questions must be resolved through continued discovery before changing
the Allium specification. An item listed here is not an implicit 1.0
commitment.

## 19.1 Recommended resumption order

After reviewing this consolidation, the next session should:

1. review every existing Little Ant Brick using chapter 20;
2. absorb useful ideas into this record through explicit questions;
3. resolve the remaining questions that block the Allium model and migration;
4. then follow the documentation and implementation sequence in chapter 21.

Impact evidence, effort confidence, exact REPL grammar, Nature schemas,
duplicate suspicion, and recurrence details remain important, but their
unsettled mechanics no longer postpone the existing-Brick review.

## 19.2 Raw and source semantics

- What are the exact link relation names: `source`, `attachment`,
  `derived_from`, `target`, `about`, or a smaller set?
- Can a Brick inherit RawLinks from ancestors?
- What are the final RawOrigin adapter, locator, external-identity, revision,
  relocation-history, and check-policy fields?
- What is the exact per-RawLink reconciliation-baseline schema and which roles
  carry it?
- How are snapshot failures, inaccessible files, HTTP errors, retries, and
  backoff represented?
- When may unreferenced blobs be garbage-collected, if ever?
- Exact atomic blob-write, transfer, verification, incomplete-replica, repair,
  quota, and out-of-space behavior.
- Whether on-demand remote tiering belongs to 1.0 or remains a later storage
  adapter, without changing the logical-dataset invariant.
- Is permanent Raw deletion supported, or only archive?

## 19.3 Brick metadata and phase

- Exact markers for `idea`, `exec`, `validation`, and terminal statuses;
  `spec` is settled as `📐`.
- The compact marker grammar and precedence for independent phase, terminal
  status, focus, WIP, blocking, and confidence indications.
- Exact direct-completion event grammar, optional completion note or evidence,
  reported-versus-observed provenance, and projection of a Brick completed
  without prior start evidence.
- Exact served-interaction wording and shortcut for direct `done`, subject to
  the final canonical grammar.
- Which external completion evidence is sufficient to offer or emphasize a
  `done` proposal while still requiring the applicable authority boundary.
- Exact guided choices when a standing, repeatable, or structurally non-leaf
  Brick receives completion intent.
- Exact phase-confidence evidence and UI threshold.
- Whether a Nature declares phase merely applicable or also restricts the
  allowed phase vocabulary.
- The neutral provisional placement prior when phase is absent.
- Whether `atomicity` remains unchanged or needs a better model.
- Exact `mode` values: only `digital | physical`, or also `hybrid`, `any`, or
  `unknown`.
- How mode uncertainty interacts with nearest-ancestor inheritance.
- Whether `about`, requester, and RawLinks inherit.

## 19.4 Tree operations, decomposition, and scope

- Exact commands and event semantics for batch done, drop, move, and
  supersede.
- How active delegations, waits, dependencies, and proposed effects behave
  when a subtree is closed.
- How supersede transfers selected children without ambiguity.
- Whether dependencies crossing a moved or closed subtree require explicit
  reconciliation.
- The final field and command names for decomposition coverage
  (`open | complete` is working vocabulary).
- Exact `review_parent` prompt, action grammar, proposal lifetime, child-outcome
  summary, and treatment of superseded work whose replacement moved elsewhere.
  Its finite-parent boundary and non-cascading confirmation semantics are
  already fixed.
- Which mechanical changes create `scope_review`, and how several suspicions
  are coalesced.
- The exact confirmation grammar and event shape for `scope_revised`.
- How the core determines the smallest set of affected relationships without
  erasing unrelated judgments.
- Which generic provenance or `about` relationships connect investigation
  evidence to a judgment without introducing a special validation-work type.

## 19.5 Priority comparison and confidence

- Exact interaction path for the ordering-skip subreason
  `tie-break for me`.
- What information `?` displays for a priority comparison and how the same
  pending prompt is restored.
- Exact formula for priority confidence, recency, and decay.
- Baseline provocative-validation probability and its adaptive multipliers.
- How a recalibration round persists and resumes.
- The minimum coherent evidence required before an affected segment is
  atomically replaced.
- How reasons and semantic changes affect priority-evidence staleness.
- Whether priority-confidence thresholds are global or configurable.
- The expected-value threshold for offering an ordinary investigation Brick
  after unresolved importance comparisons.

## 19.6 Impact classification and maturity

- The evidence required to promote each transition between `SPECULATIVE`,
  `SUPPORTED`, `VALIDATED`, and `OBSERVED`.
- The explicit process for lowering maturity when evidence becomes stale,
  contested, or inapplicable.
- Whether a human may directly select an impact class, request assistance, or
  both.
- The canonical impact question wording, answers, skip behavior, and maximum
  number of assisted comparisons.
- The default impact class when there is no reasonable basis for a judgment.
- How comparison history maps to the six public classes without exposing a
  public float.
- The internal reliability calculation from maturity, recency, provenance,
  and consistency.
- The threshold for proposing real validation work based on expected value of
  information, and the proposal's canonical name.

## 19.7 Effort classification and calibration

- The public representation of effort confidence: discrete labels, reasons
  only, another model, or some combination.
- Exact exemplar-selection and adaptive-comparison rules for the three-question
  assisted flow.
- How the five comparison answers map to a provisional class.
- How users edit an EffortProfile and how profile revisions are versioned.
- How old estimates behave when a newer profile becomes active.
- How open-ended outliers affect confidence and break-work pressure.
- Exact conservative derivation of remaining effort from descendants, explicit
  progress, and imported actuals.
- Thresholds that provoke profile or scope review after an actual-estimate
  mismatch.

## 19.8 Selection and proposals

- The exhaustive 1.0 `NextSuggestion` variant catalog, how it is grouped
  without becoming either a flat proliferation of bespoke proposal kinds or
  an ambiguous generic `interaction`, and the response contract of each
  variant.
- Exact forecast formula and normalization.
- Exact cooldown and aging curves for served-Brick, ordering, and
  classification skips.
- Exact `best_before` and `deadline` pressure curves and notice thresholds.
- Final date-notice event names, deduplication key, acknowledgment, snooze,
  resolution, and command-surfacing grammar.
- Whether the confirmed positive probability for every eligible Brick also
  needs a bounded service guarantee.
- The exact boundary between a genuine continuation that resumes before a new
  draw and a newly selectable review opportunity that belongs in the lottery.
- The exact diminishing-return bonus curve, cap, correlation or deduplication
  rule, and configuration schema for additional subject signals. The strongest
  applicable signal is already confirmed as the anchor.
- The canonical attention-subject catalog and how system-, source-, Raw-, and
  Brick-scoped opportunities enter an applicable hierarchy.
- Which proposals are fully derived and which require persisted resumable
  state.
- Final interaction-envelope identity, domain revision token, stale-answer
  rejection, and rebase grammar.
- Final name and command surface for `brick_review`, its manual invocation,
  relevance threshold, ordering of applicable questions, exit behavior, and
  relationship to broader question rounds.
- Minimum persisted domain state for atomic multi-step interactions versus
  state that can be safely derived.
- Exact progress fields and when an adaptive remaining-work estimate is
  sufficiently defensible to display.
- Whether 1.0 needs an explicit cross-surface draft operation beyond local
  presentation checkpoints.
- Whether proposal weights are configuration, learned policy, or both.
- Final command names for priority and forecast views.
- How internal impact reliability and effort confidence affect selection
  without becoming hidden public scores.
- How nested dependency-branch subdraws derive and record replay evidence from
  the random stream. Their weighting policy is no longer open: it reuses the
  focus-forecast function and normalizes it over the local admitted branch
  set.
- How a branching dependency DAG contributes effective probability without
  double-counting, and whether practical calibration needs attenuation or
  caps.
- What `next` returns when dependency resolution reaches an external wait,
  temporal gate, unavailable permission, or another condition without an
  actionable Brick endpoint.
- How inspection and `next` report imported or corrupted state that violates
  the acyclic dependency invariant.
- How dependency resolution composes with Nature-driven descent through
  projects and collections.
- The ordering and replay-evidence contract among container descent,
  dependency-chain resolution, and the final subject-local opportunity
  subdraw.
- Exact compact `Why` formatting, long-path folding, and cross-parent `Within`
  behavior. `?` must retain access to the complete recorded path.
- The exact probability allocation and local normalization for project-like
  containers and their actionable descendants. Hierarchical selection itself
  is confirmed.

## 19.9 WIP, focus, and delegation grammar

- Canonical commands for focus, unfocus, WIP start, and return to idle.
- Exact stale-focus threshold and what counts as activity.
- Exact soft-limit review pressure above three WIPs.
- Whether current focus may point to a temporarily ineligible Brick.
- Whether 1.0 permits more than one active Delegation for the same Brick, or
  requires decomposition before assigning the outcome to several Parties.
- Whether delegating a non-leaf Brick covers its executable descendants for
  human-focus eligibility or requires explicit child-level assignments.
- Final compact Delegation lifecycle and which acceptance or progress facts
  remain observations rather than statuses.
- Follow-up policy vocabulary: none, one absolute follow-up, and/or an interval
  anchored to the most recent confirmed contact; exact defaults and limits.
- Whether an inbound reply resets an interval only after an attributed manual
  or SourceAdapter observation.
- Exact follow-up screen semantics for approving a draft, rejecting its
  content, rescheduling it with `later`, skipping without a decision, and
  cancelling the entire Delegation.
- How a completed Delegation produces validation or acceptance work without
  silently marking its Brick done.
- Party identity, delivery-route selection, delivery receipts, retry behavior,
  and operation when no message integration is configured.

## 19.10 Served-Brick skip taxonomy

- Which existing skip reasons survive unchanged in 1.0.
- Whether `fear` should remain the broad canonical symptom or whether another
  precise English label better covers fear and anxiety. `meh` is removed and
  fear is no longer merely a possible addition.
- The complete symptom set, ordering, applicability rules, concise labels, and
  optional free-text path for the single first skip screen.
- Exact boundary examples for `waiting` versus `blocked`, including when an
  external dependency becomes actionable enough to create or link an enabling
  Brick.
- Exact English shortcut letters after all command namespaces are known.
- Which symptom-specific reactions are proposed on the subsequent screen,
  their ordering, and which always require another confirmation.
- Which symptoms may propose alternative approaches. `alternatives` is a
  reaction, not a symptom, and may plausibly follow `hard`, `bored`, `fear`,
  or an actionable blocker.
- How a selected symptom is scoped to the served Brick, active Domain, another
  Domain ancestor, Place, effort, dependency, or another explicit cause.
- Whether a Domain-scoped symptom also contributes ordinary Brick-specific
  skip pressure or records only suggestion-level and Domain evidence.
- Exact default cooldown, negative-signal decay, cap, inspection, clearing,
  and calibration fixtures for an accepted Domain reaction.
- Exact taxonomy-watch threshold, evidence window, decay, review layout, and
  versioned taxonomy-revision event.
- Whether snooze is distinct from cooldown, wait, and `not_before`.

## 19.11 TaskJuggler and planning

- The exact planning-manifest schema, location, naming, retention, and
  exporter-component provenance fields.
- How dependencies outside selected export scopes are represented.
- How resources, efficiency, calendars, and scenario inputs are selected.
- How a newer EffortProfile affects a plan containing older estimates.
- The versioned canonical planning-projection schema and generic export command
  grammar.
- The exact ReadOnlyExporter result schema, warning taxonomy, filename rules,
  and byte-size limits.
- Whether and how a planning surface offers separately approved `tj3`
  execution after pure export.
- Exact TaskJuggler SourceAdapter mapping, preview, and confirmation grammar
  for actual import.
- Thresholds and presentation for estimate-versus-actual warnings.

The following are settled and must not be treated as open: a parent effort
includes descendant scope; the planning cut is non-overlapping; each selected
cut node uses one macro; and each confirmed run produces an immutable manifest
outside operational domain state. The standard Pack ships a TaskJuggler
ReadOnlyExporter written in Lua, and that component is the public reference
implementation for community exporter authors.

## 19.12 REPL harness

- Exact typed compensation schema, reversible-action catalog, conflict
  response, retention, and event-selection grammar for semantic undo and redo.
- Whether any safe external effect kind can expose a standard compensating
  proposal, without ever treating domain undo as proof of external reversal.
- Exact warning selection and rotation policy for the single context-region
  warning slot, including what stays stable across navigation and what changes
  at a new semantic decision boundary.
- Final context-region row order, width folding, breadcrumb truncation, warning
  severity treatment, and compact mascot-statistics fields.
- Exact discreet review-context wording and which honest progress facts appear
  there without inventing a fixed denominator.
- Exact one-key grammar, including global, screen-local, and answer shortcuts.
- Final machine-readable `la grammar --json` schema, registry versioning,
  unknown-screen behavior, and whether filters beyond the confirmed
  `--screen` belong in 1.0.
- Exact relative-date presets, explicit date-input grammar, timezone
  rendering, and closed list of temporal proposal kinds that admit
  contextual `[l]ater`.
- Which authorities may nominate the action marked by `*`, whether destructive
  or externally visible actions can ever be defaults, and how default
  provenance, confidence, and accessible rendering are exposed.
- Deterministic shortcut allocation when several visible labels compete for
  the same letters. A shortcut must be displayed inside its label; unrelated
  prefix letters are forbidden, and exceptional `[?]` fallback should be
  avoided.
- Exact visible uncertainty label (`I don't know` versus a shorter equivalent)
  and the contents of its contextual-assistance screen. Single `?` is
  decision uncertainty and nested `?` is system help.
- Exact command-palette selection behavior and whether it accepts raw canonical
  command syntax.
- Terminal layout, resize behavior, colors, accessibility, and UI library.
- Exact non-TTY behavior.
- Idle tick cadence and safe-boundary scheduling.
- Notice rotation, dismissal, snooze, and recurrence details.
- Recent-activity length and the metadata used to group several events into
  one semantic action.
- `/history` search and navigation grammar, canonical CLI filter composition,
  relevance labels, pagination, and concise brief format.
- Checkpoint file naming, transcript size and retention, cleanup, and
  multi-device conflict behavior.
- Exact rebase and recovery choices when the event log advanced.
- How outbound integrations are displayed without weakening approval rules.
- Exact state-scoped interaction-envelope schema and action identifiers.
- Exact powered-up flag, executable-path handling, timeout, stdin handshake,
  response schema, and bounded extraction rule.
- Which low-authority AI proposals may be applied automatically and which
  always require an explicit glance.
- How non-English input is preserved when the dumb REPL cannot safely produce
  canonical English.
- How much context one `?` view reveals before pagination, and how nested
  project or collection navigation restores the exact pending interaction.
- Exact canonical status fields, ordering, wording, icon, timestamp policy,
  status-specific presence defaults, and conditions whose zero value is itself
  important.
- How the alternate-screen header and compact fallback render the typed status
  summary without becoming separate semantic projections.

## 19.13 Core surfaces and migration

- Final canonical command names, flags, output fields, and English grammar.
- Projection formats for priority confidence, effort confidence, evidence
  maturity, and internal warning reasons.
- Exact event schema and upcast path from v0 to 1.0.
- Whether migration rewrites historical events or only upcasts them on read
  before an explicit normalization command.
- How existing title-derived IDs, collisions, stage, weight, kind, estimate,
  Raw, and WIP data map into opaque identity, Natures, optional axes, and
  discrete profiles.
- Exact version bump point and migration rollback or backup procedure.

## 19.14 Existing feature review

- Source reconciliation policy.
- Start-time effects.
- Mobile and multi-device event union.
- Concurrent event-log behavior.
- Search, rendering, and web UI projections.
- Remaining bugs and ergonomic requests in the current backlog.

These are not implicitly accepted into 1.0. They will be reviewed Brick by
Brick with the user.

## 19.15 BrickNature and BrickTemplate

- Final canonical Nature identifiers. The working factory set remains
  `standard`, `project`, `collection`, `repeatable`, `standing_checklist`,
  `finite_checklist`, `recurring_obligation`, and `practice`.
- Exact feeding-time Nature interaction for explicit human input, template
  implication, attributed skill or powered-up judgment, dumb browsing, skip,
  and the required `standard` fallback.
- Authority and correction rules for an assisted Nature chosen at birth, and
  which later Nature changes require reconciliation because they alter focus,
  decomposition, recurrence, entries, or completion semantics.
- Final capability schema and definition syntax for the factory Nature IDs
  and initial standard template catalog recorded in chapter 25.
- How factory definitions are stored, inspected, cloned, versioned, and
  migrated.
- Whether a Brick stores a Nature version reference, a resolved snapshot, or
  both.
- Which Nature changes are semantic scope revisions.
- Exact Nature applicability rules for phase, effort, entries, focus unit,
  standing eligibility, completion, and recurrence.
- Exact canonical operations for template instantiation and context-sensitive
  `feed` routing.
- Exact template discovery metadata, lexical candidate retrieval, categories,
  search, pagination, ranking evidence, and performance budget.
- Exact bounded schema through which powered-up mode or the operator proposes a
  route, template version, target, populated inputs, confidence, and reason.
- Exact deterministic fallback dialog after a proposal is rejected, including
  the core-assigned shortcuts for `other templates` and `custom`.
- Exact custom-builder question sequence, Nature-reuse test, personal
  namespace rules, and final offer to save a reusable personal template.

## 19.16 ListEntry, identity, and duplicate suspicion

- Final ListEntry fields, lifecycle vocabulary, resolution outcomes, and
  attachment relations.
- Exact boundary between ListEntry and independently focusable child Brick.
- Replay-safe opaque ID generation and short-reference format.
- Exact matching-fingerprint variants, signal weights, candidate retrieval,
  scoring, explanation, thresholds, and performance budget. Their
  non-identifying and non-destructive role is already fixed.
- Scope rules across parent, Domain, Nature, recurrence period, active
  state, and terminal history.
- Exact human dialog for quantity adjustment, reuse, merge, enrichment, and
  separate creation.
- How confirmed merge and separation decisions influence later suspicion
  without becoming ambiguous global aliases.
- Exact merge-plan and receipt schemas, per-relationship transfer defaults,
  compact preview, and interactive conflict-resolution grammar.
- How source and survivor parentage and sibling importance positions are
  handled when they belong to different composition scopes.
- Exact persisted provenance for original input, canonical English, and
  normalization author.
- Whether a future world-object catalog is ever justified; it is excluded from
  the current 1.0 scope.

## 19.17 Standing work and recurrence

- Final recurrence expression syntax, timezones, daylight-saving behavior,
  release offsets, calendar exceptions, and catch-up behavior.
- Whether execution occurrences are explicit entities or projections over
  start/finish events.
- Exact event grammar for finishing a repeatable execution, choosing terminal
  completion versus another repeat, and changing or cancelling a scheduled
  repeat.
- Exact duration and jitter representation, calendar arithmetic, persisted
  draw fields, and behavior when jitter would produce an invalid or past
  `not_before`.
- Whether the repeat prompt and default delay belong only to template-expanded
  instance configuration or also have reusable named configuration records.
- Exact standing-work dormant, run-finish, retirement, and interrupted-run
  grammar.
- Whether `Buy groceries` is permanently standing by default or may be
  configured as finite per trip; standing is the current design direction.
- How unplanned resolved entries and unresolved carry-over are recorded.
- How several active bill periods, changed deadlines, source imports, and
  manual feed reconcile.
- Whether recurrence rules live on a standing Brick, template-derived series,
  or a separate persisted series entity.
- Exact opportunity-trigger schema, supported source events, target
  eligibility checks, opportunity identity, coalescing policy, removal
  semantics, and treatment of corrected source events. Its restricted,
  inspectable, idempotent, non-lifecycle-changing boundary is already fixed.
- Exact standing-work supersession reconciliation for open opportunities,
  future recurrence releases, inbound and outbound triggers, dependencies,
  priority placement, and external source relationships.
- Exact reactivation dialog and event grammar when duplicate suspicion finds
  retired standing work, including how to distinguish continuation from a new
  responsibility without automatic resurrection.

## 19.18 Practices, streaks, and introspection

- Final canonical name for an unfulfilled practice opportunity:
  `not_done`, `missed`, or another exact English value.
- Fixed-slot versus quota-window semantics, including twice-per-week targets.
- Exact practice opportunity, explicit abandonment, expiry, pause, and resume
  events.
- Streak definition, visual symbols, warning grammar, configurability, and
  whether a successful quota window or each execution extends the streak.
- Initial and adaptive thresholds for `practice_review` and repeatedly carried
  ListEntry review.
- Which context and skip evidence the dumb core may aggregate without making a
  semantic causal claim.
- Exact guided review that can propose schedule changes, dependencies,
  enabling Bricks, pause, retirement, or more observation.
- How a blocked practice freezes opportunities and streaks across recurrence
  boundaries, and how it resumes after the blocker is completed.

## 19.19 Places and location observations

- Final Place identity, label, aliases, nesting, duplicate suspicion, and
  adapter mapping.
- Exact hard and soft place-condition fields, multi-place semantics,
  inheritance, and interaction with context, mode, waits, and dates.
- Location-observation event grammar, supported observation kinds, source
  authority, idempotency key, correction, replacement, exit, and TTL.
- Privacy controls and retention, redaction, export, synchronization, and
  deletion policy for location history.
- Exact `place_batch` proposal, ranking, grouping, interaction, and forecast
  explanation.
- Whether a configured adapter may wake a surface without notifying the user,
  and how any location-driven push remains inside the external-action approval
  boundary.

## 19.20 Text mentions and typed annotations

- Final annotation entity, event, field, and command names.
- Exact Party display-label and alternate-name fields, candidate-search
  Nature, and disambiguating Domain. Their non-identifying role is fixed.
- Initial annotation-capable fields and any target types beyond the confirmed
  Party and Brick editor paths.
- Span and Unicode indexing, text revision identity, edit re-anchoring,
  concurrent change, and reconciliation semantics.
- Autocomplete candidate search, ranking, disambiguation, pagination, and
  canonical interaction grammar.
- Exact visible-token copy, paste, export, short-ID, and title rendering.
- Rendering after target rename, merge, terminal status, unavailability, or a
  future deletion policy.
- Backlink projections, search and export behavior, and whether annotations
  contribute evidence to duplicate suspicion.
- Exact explicit interaction for promoting a literal URI into Raw with a
  normalized RawOrigin and applicable RawLink.
- Explicit RawSnapshot annotation without mutating or semantically reclassifying
  immutable source material.

## 19.21 Domain authority and rebuildable projections

- Event-envelope versioning, deterministic upcasting, integrity chaining,
  segmentation, compaction, corruption recovery, and audit tooling.
- Projection schema versions, source cursors, stale detection, incremental
  repair, wholesale rebuild, and canonical-equivalence tests.
- User-visible behavior while an optional projection is missing, stale,
  incompatible, corrupt, or rebuilding.
- Exact backup and synchronization scope for events, canonical blobs,
  configuration, REPL checkpoints, and immutable planning manifests.
- How event-log compaction can remain inspectable and authoritative without
  erasing historical evidence.

## 19.22 External imports, Packs, and executable components

- Final normalized ImportCandidate and ImportBatch schemas, including partial
  failures and atomicity boundaries.
- Exact ImportProfile schema, event or configuration authority, matching
  precedence, versioning, and migration behavior.
- Exact automatic-adoption authorization and provisional-placement policy.
- How priority uncertainty from bulk imports is represented and scheduled for
  comparison without exposing a stored boolean as the public model.
- Incremental cursor authority, retries, backoff, rate limits, and
  interrupted-batch recovery.
- Final external work-state, presence, container-state, observation-authority,
  and removal-provenance event and projection schemas.
- Exact adapter rules for distinguishing authoritative tombstones from
  filtered omission, inaccessible sources, ambiguous `404` responses, and
  other unavailable states.
- Exact source-anomaly detection, mass-removal threshold, pause, inspection,
  and recovery interaction.
- Final migration-run, verification, cutover, ImportProfile-retirement, and
  immutable receipt schemas and command grammar.
- Final spelling and interaction for the working `erase-after-import` option,
  including source-scope preview, destructive approval, unsupported or lossy
  field handling, concurrent upstream edits, retries, and explicit keep
  dispositions.
- Whether and when an emptied external container should be offered for a
  separately approved deletion.
- Exact mapping and confirmation rules for provider dates, completion,
  recurrence, descriptions, labels, and external ordering.
- Exact source-view filters, aggregation, pagination, and bulk-triage
  interaction.
- Which representative adapters and generic formats ship in the initial 1.0
  standard pack.
- Final pack manifest, namespace, compatibility, dependency, installation,
  update, pinning, rollback, revocation, and inspection grammar.
- Exact PackComponent schemas and version-negotiation rules for SourceAdapter,
  Enricher, ReadOnlyExporter, and UIAdapter.
- Exact `lant-pack-runner` process protocol, isolation profile, cancellation,
  wall-clock, instruction, memory, output-size, and nesting-depth defaults.
- Exact bounded host-capability vocabulary, filesystem bridge, HTTP request
  and response schemas, retry safety, rate-limit behavior, and redaction
  requirements. Raw Lua operating-system and socket access is already
  excluded.
- Final credential-slot, CredentialBinding, and typed authentication schemas.
- Final vault, login, account-binding, unlock, lock, and encrypted-export
  command grammar.
- Exact encrypted-vault file format, cryptographic construction, master-key
  and recovery procedure, explicit encrypted export, rotation, revocation,
  idle timeout, and local memory-agent IPC hardening.
- Which concrete UIAdapters, if any beyond the component contract and
  first-party REPL, ship in the initial standard Pack.
- Exact UI transport/session checkpoint, delivery retry, offline, duplicate
  input, interaction-expiry, configured-recipient, and conformance rules.
- Exact component conformance suites, reference fixtures, diagnostic format,
  content signing, security-review requirements, and acceptance policy for the
  open `little-ant-packs` repository.
- Whether one community repository should retain both executable and
  data-only components permanently or later split their distribution while
  preserving the same pack contract.
- Whether pure-Lua dependency policy needs an allowlist in addition to
  vendoring, hashing, and runtime limits.
- Whether the five standard structural formats are five exporter components or
  format variants of fewer components, and their exact options and fixtures.

The following are settled and must not be treated as open: `Little Ant Pack`
is the distribution unit; there is no generic Plugin entity or arbitrary hook;
the closed component kinds are those listed in chapter 34; Lua 5.4 through a
separate HsLua-based runner is the sole first-class executable runtime in 1.0;
official and community components use the same isolation boundary; Pack code
never runs during replay; HTTP and credentials are host-brokered; the local
encrypted vault is excluded from ordinary dataset synchronization; and
UIAdapter is included in the 1.0 component protocol.
Tree text, table text, CSV, Org, and self-contained HTML also ship as standard
Lua ReadOnlyExporters and must not be reconsidered as hard-coded core target
renderers.

## 19.23 Structured responses and sparse projections

- Final success and failure envelope schemas, protocol version, and schema
  discovery mechanism.
- Exact command-result kinds and compact entity-reference fields.
- Whether stale-response protection uses a dataset revision, entity revision,
  interaction revision, or a typed combination.
- Final named projections and command grammar for summary, operational detail,
  relationship, history, and complete views.
- Exact per-field required, optional, omission-default, meaningful-zero,
  tri-state, and clearing semantics.
- Which event references or semantic change summaries, if any, accompany an
  ordinary mutation without returning full event payloads.
- How lazy-tick outcomes remain visible without attaching unrelated audit
  events to every response.
- Whether validated field selection belongs in 1.0 in addition to named
  projections, and its relationship to filtered history.
- Exact response-size budgets, pagination, truncation signaling, and
  progressive-detail links.
- Compatibility, schema negotiation, and behavior when a client requests an
  unsupported projection or field.
- Exact dry-run time snapshot, state revision, and replay-token contract;
  stable error-code taxonomy, process exit codes, field names, and bounded
  recovery-action catalog.

## 19.24 Hierarchical organizational classification

- Whether `Domain`, now accepted as the working product term, needs any final
  correction before Allium propagation. `Folder` is misleading because
  membership is not exclusive storage ownership, while generic `context`
  conflicts with execution and interaction meanings.
- The entity, opaque identity, parent relation, label, alternate-label, path,
  rename, move, merge, archive, duplicate-suspicion, and cycle-prevention
  schema.
- Whether classification forms one hierarchy or several named taxonomies.
- Direct versus inherited membership, additive inheritance, explicit
  exclusion, and what happens when a Brick or classification branch moves.
- Exact recursive query semantics for list, count, search, forecast, and
  `next`, including active-versus-terminal defaults and ambiguous labels.
- Whether a natural request such as “related to Orbit” defaults only to
  recursive classification membership or composes classification, requester,
  `about`, source, annotation, and text-search predicates.
- Candidate retrieval from an explicit current scope, parent membership,
  import profile, recent activity, source provenance, title, description, and
  attributed semantic judgment.
- Whether the skill or powered-up adapter may attach an existing
  classification provisionally without a blocking confirmation, and the
  confidence, provenance, recap, correction, and later-review requirements if
  it may.
- Which changes always require confirmation. Creating a new classification
  branch, removing a human membership, or merging branches must not be
  silently inferred.
- The dumb REPL's bounded candidate and browse interaction when deterministic
  evidence is useful, and when feeding should remain unclassified rather than
  becoming a mandatory form.
- How proposed memberships participate in duplicate suspicion before atomic
  creation without allowing classification uncertainty to discard input.
- Exact active-Domain event and projection schema, session lifetime, temporal
  decay or clearing, and explicit switch command. The state is confirmed as
  persisted and `Focus?` acceptance changes it atomically.
- How the displayed target Domain is chosen when several equally specific
  descendant memberships qualify, or when no candidate membership has an
  ancestor-descendant relationship with the active Domain. A unique most
  specific descendant is already confirmed as the automatic narrowing target;
  weighting uses the strongest affinity and never adds membership tickets.
- Domain-continuity signal intensity, cap, configuration range, and calibration
  fixtures. The hierarchical lowest-common-ancestor affinity factor and its
  place inside the strongest-signal-plus-bonus model are fixed.
- Exact compact and expanded rendering for a prospective Domain transition;
  the normal `Focus?` grammar and its `y/d/s/?` semantics are fixed.
- Which explicit Domain request means a soft preference and which, if any,
  means a hard filter.
- Generic recurring preferred-time windows and Place evidence for standing
  work such as grocery shopping, without hard-coded grocery mechanics or
  turning each ListEntry into independently focusable work.

# 9. Migration and release contract

## Migration principles

- **MIG-001 [core] — Explicit v0 boundary.** Migration reads a versioned,
  immutable v0 archive and writes v1 through canonical creation or migration
  operations. The archive remains verifiable after cutover.
- **MIG-002 [core] — No in-place guess.** Migration first projects and
  validates a candidate v1 state, reports ambiguity, and commits only after
  invariant and identity checks pass.
- **MIG-003 [core] — Identity map.** Every migrated v0 Raw, Brick, ListEntry,
  legacy Party, source, and relevant historical event has an inspectable
  old-to-new identity or preservation record. Each newly materialized v1
  object receives one stored UUIDv7; replay of the migration reuses the
  recorded mapping rather than minting another identity.
- **MIG-004 [core] — Historical evidence.** Rejected vocabulary may remain
  quoted inside immutable v0 payloads and migration reports. Current v1 state
  and APIs use only canonical vocabulary.
- **MIG-005 [core] — No fabricated judgment.** Migration preserves attributable
  comparisons and known orders but never invents human evidence, phase,
  completion, progress, or semantic scope.

## Required mappings

- **MIG-006 [core] — Legacy stages.**

  - v0 `seed`, `committed`, and `ready` become `active`/`idle`;
  - v0 `wip` becomes `active`/`wip`, with current focus preserved only when
    explicit evidence identifies it;
  - terminal v0 `done` and `superseded` retain their outcomes and lineage;
    any explicit v0 `dropped` outcome maps to canonical v1 `archived` with
    its source vocabulary and reason preserved as migration evidence;
  - no legacy stage is converted into phase merely by name.

- **MIG-007 [core] — Legacy precedence is not importance.** V0 comparisons
  answered “before/after,” while v1 comparisons answer “more/less important.”
  No v0 comparison becomes human importance evidence. Within each v1 sibling
  group, the v0 deterministic order—restricted to that group and with creation
  sequence as its tie-break—seeds one complete provisional position list.
  Dependency edges remain Dependencies and do not constrain importance. Every
  imported active Brick is therefore positioned, but affected sibling runs
  carry one lazy importance-review marker. Original comparison direction,
  author, time, stale flag, and cross-parent scope remain migration evidence.
- **MIG-008 [core] — Behavior comes from mechanics, not `kind`.** A Brick that
  owns legacy broken-out children or has `atomicity = divisible` becomes
  `project`. Every other Brick becomes `atomic_task`; explicit legacy
  `atomicity = atomic` is attributable supporting evidence, while unknown
  atomicity creates a `migration_default` Nature claim with lazy human review.
  Legacy `spec`, `exec`, `delegation`, `decision`, and `meta` kind values remain
  role evidence. `spec` and `exec` may create provisional phase suggestions for
  later review but never set phase directly; no legacy kind creates a v1
  Nature, Delegation, or effect by name.
- **MIG-009 [core] — Legacy Party.** V0 person and AI-agent records map to
  ExternalEntity `person` and `ai_agent`; `company` maps to `organization`.
  A legacy `area` used as requester, delegate, or Wait target maps to
  ExternalEntity `team`. An area name equal to a complete legacy context or
  one slash-delimited context segment also maps to that Domain; if both rules
  apply, the identity record explicitly splits to the team and Domain. An
  otherwise unreferenced area becomes a provisional `team` with lazy kind
  review. V0 stored only name and type, so no contact, credential, or delivery
  method is fabricated.
- **MIG-010 [core] — Raw and source remain complete.** Each legacy Feed Raw
  becomes one text Raw with original received time and content. A successful
  `seeds_extracted` event links that same Raw as `materialization_source` to
  each produced Brick; an empty extraction records accepted standalone triage.
  Pending Raw stays in the Inbox. Every historical description stream becomes
  one separate text Raw per Brick, its `brick_described` events become ordered
  revisions, and one description RawLink is attached. A legacy SourceLink
  becomes one URI Raw linked as evidence plus a paused manual snapshot
  SourceBinding carrying type, locator, fingerprint, and divergence evidence;
  it never gains a provider adapter or live-sync claim by inference.
- **MIG-011 [core] — Removed fields.** Legacy `weight` is not silently renamed
  to effort, impact, importance, or forecast probability. Legacy hour
  estimates and their human/AI author remain planning evidence pending
  EffortProfile classification. `digital`/`physical`, free-text effect detail,
  Flow strictness/context, and any unsupported legacy role remain
  historical-only evidence rather than a new Place, Domain, command, or hook.

## Exact v0.1 projection

- **MIG-024 [core] — The accepted source is the signed v0.1 schema.** The
  migrator accepts the event vocabulary at signed tag `v0.1.0` (commit
  `c6f3cb7`) plus exactly its shipped upcasts for `raw_captured`,
  `brick_enriched` energy, legacy session names, and legacy `focus_served`
  field. It verifies every JSON line, declared version, intrinsic event hash,
  timestamp, reference, and final fold. Unknown types/versions, duplicate
  incompatible event IDs, and malformed or reordered evidence stop preflight;
  the migrator never inherits v0's tolerant unknown-event skip.
- **MIG-025 [core] — One canonical MigrationRecord preserves provenance.** A
  successful candidate owns the exact v0 archive bytes as immutable canonical
  blob, archive SHA-256, source schema/tag, ordered event ID/line-digest table,
  old-record-to-new-UUID or preservation disposition map, mapping-policy
  version, accepted warnings, candidate projection hash, and cutover facts.
  V1 history renders semantic v1 facts by default and exposes original payloads
  only through explicit migration evidence; it does not replay old commands as
  new user actions.
- **MIG-026 [core] — Legacy context becomes direct Domain evidence.** Every
  nonempty current Brick context is split on v0's semantic `/` namespace,
  trimming nonempty segments, and creates or reuses that exact Domain path.
  The Brick receives direct membership in the leaf Domain. Literal `>` and `›`
  were not v0 separators and remain part of a segment. A Flow context hint is
  session history only. Conflicting normalized sibling names or empty path
  segments are blocking mapping issues rather than silent repair.
- **MIG-027 [core] — Lifecycle and focus use final state plus event evidence.**
  `seed`, `committed`, and `ready` map to active idle; `done` to done; and
  `dropped` to archived with legacy reason. `bricks_unified` makes the loser
  `merged` into its survivor, whereas `brick_superseded` preserves
  supersession and replacement lineage. Every final v0 WIP Brick remains WIP;
  the most recently started still-WIP Brick becomes current focus, and other
  WIP Bricks receive a review-due marker. A WIP flag remains review evidence.
  Active descendants under a terminal parent, multiple incompatible current
  starts, or irreconcilable lineage block candidate construction rather than
  being detached or reopened automatically.
- **MIG-028 [core] — Structural relationships preserve only their exact
  meaning.** Legacy parent/part composition, acyclic Dependencies, requester,
  and Brick-to-Brick `about` annotations map directly after UUID resolution.
  Orphan references that were no-ops in the validated v0 fold remain
  historical no-op evidence. A cycle, self-edge, or relationship incompatible
  with the mapped Nature is a blocking issue with explicit repair choices; no
  title resemblance creates a relation.
- **MIG-029 [core] — Skip observations map conservatively.** `hard`, `vague`,
  `tired`, and `other` retain their corresponding evidence; `not_priority`
  becomes legacy `less_important` evidence without an importance judgment;
  `waiting` remains `blocked_or_waiting` unless an actual Wait record supplies
  precision. `meh`, `alternatives`, and their reaction tags remain historical
  other-evidence because neither proves v1 `bored`, `fear`, or a subject
  change. `kill` maps through the Brick's archived lifecycle. Raw skip text,
  time, serve/skip counts, and taxonomy history remain attributable; old
  reactions are not rerun.
- **MIG-030 [core] — Waits and Dependencies do not borrow each other's
  meaning.** Each current or resolved legacy Wait becomes a v1 Wait with its
  exact Brick, optional mapped ExternalEntity, condition text, and resolution
  history. An active Wait receives `review_not_before = migration instant`, so
  it remains gating and honestly reviewable without an invented cadence.
  Legacy Dependencies map separately. A legacy waiting skip creates neither.
- **MIG-031 [standard] — Legacy Delegation never fabricates delivery.**
  `to_notify`, `notified`, and `nudged` become proposed Delegations whose target
  and nudge history are preserved, but execution remains human-eligible until
  the ordinary v1 route confirms handoff, scope, follow-up policy, delay, and
  method. Old approval was not an adapter receipt. Completed and refused
  records become attributed terminal reports without completing the Brick.
  Cancelled/abandoned records become closed `legacy_terminated` evidence, not a
  resurrected generic abandon state. Existing nudge times never authorize a
  new message.
- **MIG-032 [standard] — Generic legacy effects are inert evidence.** Armed,
  proposed, applied, and declined `write_back`, `notify`, and `spawn` records
  retain detail, state, source Brick, and any already-created spawned Brick in
  the MigrationRecord. None becomes a DAT-068 effect, pending approval,
  delivery receipt, or provider truth. The migration report groups unresolved
  armed/proposed effects for manual recreation through a supported current
  flow; cutover never dispatches them.
- **MIG-033 [core] — System meta-Bricks collapse only by event provenance.** A
  Brick created by `order_sanity_proposed` becomes derived importance-review
  pressure, not Work. A Brick created by `source_diverged` becomes source
  reconciliation pressure, not Work. Their titles and histories remain
  migration evidence. A `clarification_deferred` Brick and a Brick actually
  spawned by an applied legacy effect remain ordinary mapped Work because they
  represented a concrete user-visible intention. `kind = meta` or a title
  alone is never enough to suppress a Brick.
- **MIG-034 [core] — Review burden has four explicit classes.** Preflight groups
  every disposition as `automatic`, `provisional review`, `historical only`,
  or `blocking`. Automatic and provisional mappings create a valid candidate;
  provisional Nature, phase, entity-kind, and importance markers enter their
  existing bounded lazy reviews. Historical-only evidence stays inspectable
  without becoming lottery work. Only structural/integrity contradictions are
  blocking, and every blocker has a finite repair preview. Accepting warnings
  records their exact IDs and never converts them into human judgments.

## Verification and cutover

- **MIG-012 [core] — Preflight.** Before any cutover, report source counts,
  parse/upcast warnings, unmapped identities, ambiguous references,
  incompatible cycles, title-only collisions, proposed mnemonic handles,
  handle remappings, and unresolved Nature mappings. A dataset merge never
  changes UUIDs merely to resolve a public-handle collision.
- **MIG-013 [core] — Projection invariants.** Candidate state must satisfy
  opaque identity, exactly one Nature per Brick, one sibling position per
  active Brick, acyclic composition/dependencies, valid terminal structure,
  and canonical link ownership.
- **MIG-014 [core] — Dry-run first.** The migration provides a complete dry-run
  report and writes neither v0 nor v1 state before explicit cutover.
- **MIG-015 [core] — Atomic v1 commit.** Cutover records source archive hash,
  migration version, identity map, counts, warnings accepted, projection hash,
  and committed target revision.
- **MIG-016 [core] — Failure preserves both sides.** Verification or write
  failure leaves the v0 archive and prior v1 target untouched and provides a
  concrete repair path.
- **MIG-017 [standard] — External-source cleanup.** Provider deletion after a
  migration is a later approved adapter effect under `DAT-016`, never part of
  the atomic local cutover.
- **MIG-035 [core] — Preflight is the harmless default.**
  `lant migrate --from <v0-jsonl> --into <v1-dataset>` performs only validated
  preflight and emits a sparse mapping report plus one content-addressed
  `<plan>` reference. `lant migrate --inspect <plan>` expands it, and
  `/migrate` opens the equivalent dumb guided route. Neither command writes a
  candidate, reserves identities, changes the current target, or modifies the
  source unless the human later chooses the separately named build and cutover
  steps. `--dry-run` is accepted globally and makes this guarantee explicit;
  it is never required merely to make the default safe.
- **MIG-036 [core] — One immutable plan controls later steps.** Preflight
  produces a content-addressed plan from the source archive hash, mapping
  policy version, relevant target revision/hash, accepted repair choices, and
  exact warning IDs. Build and cutover name that plan. Any changed source,
  target, policy, or repair choice makes the plan stale and requires a new
  preflight; the migrator never silently recalculates under an old approval.
- **MIG-037 [core] — Candidate construction is isolated and retry-safe.**
  `lant migrate --build <plan>` writes a new candidate dataset beside, never
  inside, the source or live target, and returns one `<candidate>` reference.
  It atomically persists an allocation table before exposing the candidate:
  each new object receives one UUIDv7 exactly once, and an interrupted retry
  reuses it. Mnemonic handles are proposed in legacy creation order using the
  ordinary v1 derivation and numeric collision suffixes. Dry-run may show
  deterministic handle proposals without pretending to know UUIDs it did not
  allocate.
- **MIG-038 [core] — Candidate validation is a full replay.** A built candidate
  must replay from zero and reproduce its projection hash, MigrationRecord,
  identity table, object counts, references, lifecycle, orders, and all
  `MIG-013` invariants. Its embedded source archive must match the preflight
  hash byte for byte. A failed candidate remains inspectable or discardable
  and cannot be cut over.
- **MIG-039 [core] — Cutover is a separate exact consent.** Cutover previews
  the validated candidate hash, current target hash or absence, retained
  backup location, source location, and accepted warning count. It has no
  default action. Acceptance performs one atomic target replacement; the
  previous target is retained as a read-only backup and the source remains
  untouched. If the target changed after preflight, cutover fails before any
  rename. An existing v1 target follows `MIG-023` rather than being
  overwritten as an empty destination. The noninteractive entry is
  `lant migrate --cutover <candidate>`; it still emits the same consent and
  requires an explicit answer on an interactive terminal. In a noninteractive
  environment it stops after rendering the preview rather than accepting a
  force flag.
- **MIG-040 [core] — Migration never performs outside-world work.** Preflight,
  build, validation, and local cutover dispatch no adapter effect, delegation,
  notification, Calendar write, provider cleanup, or legacy effect. Later
  cleanup, if explicitly requested and supported, begins a new ordinary
  `DAT-068` approval against the already verified local result.
- **MIG-041 [core] — Reports are durable and human-sized.** Every run stores a
  full machine-readable report and renders counts by the four `MIG-034`
  classes, followed by only blocking issues and consequential warnings.
  Inspection can expand any identity, legacy event, provisional claim, or
  historical-only disposition. Powered-up mode and the Skill may summarize
  the report or suggest one explicit repair, but cannot accept a warning,
  allocate an identity, build, cut over, clean a source, or suppress an issue.

## Canonical migration interaction

- **MIG-042 [core] — Three screens, no wizard sprawl.** Dumb mode has exactly
  three principal checkpoints: preflight report, validated candidate, and
  cutover consent. Blocking preflight adds only an inspect/repair path and
  withholds build. Escape leaves source and target untouched. Successful local
  cutover ends with the ordinary result grammar and offers `[n]ext` and
  `[/] more...`; migration does not invent a parallel shell.
- **MIG-043 [core] — Repair choices are typed and local.** Each blocker names
  the exact failed invariant and offers only repairs that preserve v0 evidence,
  such as selecting a mapped identity, removing a proven invalid edge from the
  candidate, or preserving the record as historical-only when that cannot
  alter current meaning. The preview shows the consequence before the repair
  joins the plan. There is no broad “fix everything” action, title-based
  relation inference, or assisted auto-accept.
- **MIG-044 [core] — Migration success is reversible operationally, not by
  rewriting history.** `/undo` does not reverse a dataset cutover or external
  cleanup. The result explains how to switch back to the retained target
  backup after closing the current process, with an exact preview that verifies
  both revisions. Candidate discard is recoverable until explicit garbage
  collection; source and MigrationRecord remain retained under the configured
  archival policy.

## Documentation and implementation gate

- **MIG-018 [core] — UX acceptance first.** Canonical screen and scenario
  review must finish before Markdown is promoted into Allium obligations or
  generated tests.
- **MIG-019 [core] — Stable trace IDs.** Every promoted Allium rule, surface,
  and test cites the originating rule or scenario ID. Promotion reports
  uncovered, conflicting, or intentionally non-testable IDs.
- **MIG-020 [core] — Regression gate.** The v0 capability audit is resolved
  item by item as restored, deliberately replaced, deliberately retired, or
  out of scope. Passing syntax or generated unit tests alone is insufficient.
- **MIG-021 [core] — README after truth.** The README becomes a concise 1.0
  entry point only after the canonical product and UX contract are accepted.
  It links here rather than duplicating architectural detail.
- **MIG-022 [core] — Separate coding authorization.** Documentation, scenario,
  Allium, test generation, implementation, and data cutover remain explicit
  phases. Finishing one never silently authorizes the next.
- **MIG-023 [core] — Dataset-merge identity safety.** Importing or merging an
  existing v1 dataset first reconciles equal UUIDs by lineage, rejects
  incompatible equal-UUID histories as explicit identity conflicts, and then
  previews deterministic handle remapping for different objects that share a
  handle. Approval records the mapping report; it never creates compatibility
  aliases.

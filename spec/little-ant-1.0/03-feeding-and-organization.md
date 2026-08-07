# 3. Feeding and organization

## One ingress

- **FED-001 [core] — Feed is the door.** `feed` is the sole canonical ingress
  vocabulary. Every accepted submission immediately creates Raw material in
  the derived Inbox without asking for Nature, Template, parent, Domain,
  shelf, importance, or final route.
- **FED-002 [core] — Routing is lazy triage.** A later Raw-triage opportunity
  may keep the Raw standalone, place it on one or more RawShelves, attach it
  to an existing entity, use it as the source of a ListEntry, or materialize
  one or more positioned Bricks. These are dispositions of preserved Raw,
  never alternate meanings of the `feed` command.
- **FED-003 [core] — Preserve before interpretation.** Original input is
  retained before normalization, translation, extraction, or routing, so a
  rejected proposal cannot lose user material.
- **FED-004 [core] — Fast path commits only Raw.** Submitting nonempty Feed
  input atomically stores its original representation and provenance as one
  Raw with a generated UUIDv7, then returns to the ordinary useful envelope.
  No model call or classification blocks that commit. Escape before submission
  creates nothing. Later materialization performs duplicate review before
  allocating a Brick, ListEntry, or other target identity, so reuse and
  attachment never create and then hide a duplicate.

## Classification and confirmation

- **FED-005 [core] — Triage begins with one behavioral distinction.** Dumb
  triage first asks whether the Raw, as it stands, is something the user could
  work on by itself. `yes` enters Work materialization; `no` ranks compatible
  existing destinations that may supply missing meaning or ownership. This
  question occurs during a later review, never as a toll on `feed`.
- **FED-006 [core] — No hidden fallback.** Materializing Work still requires
  one validated Nature. Nature uncertainty opens the bounded capability tree
  answered with `yes`, `no`, or `[?] I don't know`; unresolved uncertainty
  leaves the Raw in the Inbox and creates no Brick. No path silently assigns a
  generic Nature, parent, shelf, ListEntry owner, or attachment role.
- **FED-007 [standard] — Contextual candidate ranking.** Dumb mode ranks a
  bounded set of compatible existing destinations using only recorded and
  inspectable evidence: target mechanics, current focus and Domain, recent
  modification and use, earlier accepted Feed destinations, lexical or
  duplicate evidence, and temporal proximity among recently fed Raws. A
  visible default requires a defensible leading candidate. Every compatible
  candidate remains discoverable through deterministic pagination and search.
- **FED-008 [standard] — Assisted triage.** Skill or powered-up mode may add
  attributed semantic evidence from the Raw, canonical context, and a bounded
  recent-Feed window; translate; rank duplicate or destination candidates;
  suggest a batch disposition; and provisionally pre-order Work. It never
  delays or rewrites the completed Feed commit, silently accepts its own
  proposal, or fabricates human comparison history. Rejection enters the
  unchanged dumb triage with every Raw preserved.
- **FED-009 [standard] — Dumb completeness.** Every assisted disposition has a
  deterministic dumb route using behavioral questions, core-ranked targets,
  factory Nature choice, capability questions, and compatible-Template
  browsing. A Pack may supply validated definitions, but no executable Pack
  or model is required.

## Raw, shelves, and sources

- **FED-010 [core] — Content is not work.** A description, bare URL, pasted
  conversation, document, note, imported object, or malformed fragment may
  enter as Raw. Raw remains durable after it is linked or routed. The system
  may separately propose ordinary Brick work such as reading or reviewing it.
- **FED-011 [standard] — Raw review.** Raw has independent review and storage
  axes. Reviewing, reopening, archiving, and unarchiving are explicit; no
  synthetic Brick is created to mark Raw done.
- **FED-012 [standard] — RawShelf semantics.** A RawShelf groups material by
  user meaning, such as books or technical articles. It does not represent
  source provenance, Domain hierarchy, or file ownership.
- **FED-013 [standard] — Source view.** Items imported from one source may be
  shown together through a derived source view without forcing them onto one
  semantic shelf.
- **FED-014 [standard] — Immutable evidence.** An external origin may have
  immutable local snapshots, observations, relocation history, and an explicit
  reconciliation baseline. External removal never silently means completion.

## Duplicate suspicion

- **FED-015 [core] — Normalize for matching.** A Raw's canonical-English
  normalization and original representation, plus title fingerprints, source
  identity, parent, Nature, Domain, and historical continuity, may generate a
  bounded duplicate candidate set.
- **FED-016 [core] — Scope-sensitive review.** The review distinguishes:

  ```text
  reuse | enrich | merge | keep separate
  ```

  The available outcomes depend on whether the candidate is Raw, Brick, or
  ListEntry.

- **FED-017 [core] — No global object catalog.** Repeated real-world labels
  such as `milk` do not create one universal object. A grocery entry belongs
  to its living checklist and may recur historically without title-derived
  identity.
- **FED-018 [standard] — Recurrence-aware matching.** Series and period
  identity participate in matching, so a manually fed bill can enrich the
  existing occurrence instead of duplicating it.

## Placement after feeding

- **FED-019 [core] — Immediate position.** Every Brick materialized from Raw
  receives a sibling position in the same accepted operation. Comparison
  answers may remain in the pending triage draft until that atomic commit; the
  Brick is never left in an unordered staging pool.
- **FED-020 [core] — Human settlement.** AI or Nature priors may suggest an
  initial direction, but the importance mechanism in `IMP-004` through
  `IMP-009` settles the recorded order and uncertainty.
- **FED-021 [standard] — Phase prior only.** If phase is already known and
  applicable, it may influence a provisional insertion center. It never forms
  a permanent band or sort key.

## Domain classification and queries

- **FED-022 [core] — Domain is optional classification.** A Brick may be fed
  without a Domain. Skill or powered-up mode may propose memberships; dumb
  mode may show a bounded optional choice when useful; skipping never blocks
  creation.
- **FED-023 [core] — Domain query.** Canonical queries can select one Domain
  node with or without descendants, count matching Bricks, and draw within
  that scope. Multi-membership never duplicates results.

## Nature discovery decision tree

- **FED-024 [core] — Mechanical discovery.** Dumb Nature discovery during
  Work materialization asks one
  behavioral question per screen and follows this factory tree:

  ```text
  Q0. Must this happen during an externally fixed time or time window?
  ├─ yes → scheduled_commitment
  └─ no
     Q1. Will completing this once finish the whole intention?
     ├─ yes
     │  Q2. Does completion require tracking multiple parts?
     │  ├─ no  → atomic_task
     │  └─ yes
     │     Q3. Do any parts need independent focus, importance, blockers,
     │         dates, Domain membership, or history?
     │     ├─ yes → project
     │     └─ no  → finite_checklist
     └─ no
        Q4. Does it maintain a changing set of members or entries?
        ├─ yes
        │  Q5. Should next ever serve one member independently?
        │  ├─ yes → collection
        │  └─ no  → living_checklist
        └─ no
           Q6. Does each required occurrence remain open until completed or
               explicitly closed?
           ├─ yes → recurring_obligation
           └─ no
              Q7. Are missed time windows recorded and are streaks meaningful?
              ├─ yes → habit
              └─ no  → repeatable
  ```

- **FED-025 [core] — Uncertainty probes.** `[?] I don't know` never chooses a
  branch. It explains the current distinction with one example from each
  branch and asks an alternate consequence-oriented probe:

  | Split | Alternate probe | `yes` | `no` |
  |---|---|---|---|
  | fixed-time commitment or flexible work | Would doing it earlier still satisfy the intention? | flexible work | scheduled commitment |
  | finite or continuing | Should this Brick remain active after a successful run? | continuing | finite |
  | atomic or multipart | Would one `done` action lose progress that should be tracked separately? | multipart | atomic |
  | project or finite checklist | Could any part need its own `next`, importance, blocker, date, Domain, or history? | project | finite checklist |
  | members or executions | Will items be added or removed while the parent remains? | members | executions |
  | collection or living checklist | At focus time, must the whole open set appear together? | living checklist | collection |
  | obligation or non-accumulating work | If missed, should the old occurrence remain open or overdue? | recurring obligation | non-accumulating work |
  | habit or repeatable | Should a missed window record an unfulfilled outcome or affect a streak? | habit | repeatable |

  A second uncertainty at the same split leaves Raw triage pending instead of
  guessing.
- **FED-026 [core] — Confirm the discovered Nature.** Reaching a leaf shows the
  resulting Nature and the decisive behavioral reason, then asks whether the
  classification is right. `yes` accepts the Nature and continues Work
  materialization. `no` discards only the local discovery path and returns to
  the factory Nature choice, where the user may select directly or use
  `[?] I don't know` to run discovery again. `[?] I don't know` at the result
  restarts discovery from Q0. None of these paths creates a Brick before the
  complete materialization route is confirmed.
- **FED-027 [core] — Discovery checkpoints.** Every discovery question and its
  result is an uncommitted navigation checkpoint. Escape returns to the
  immediately preceding question and discards only the answer and descendants
  after that checkpoint. Escape from Q0 returns to the factory Nature choice.
  The source Raw, the prior proposal, and the random cursor are preserved; no
  domain event, semantic undo, or new draw occurs.
- **FED-028 [core] — Explicit optional Template.** After dumb Work
  materialization resolves a Nature, it presents the compatible Template
  choice whenever the installed
  catalog contains at least one candidate. The user may select one Template or
  explicitly continue with no Template. Absence of a Template never prevents
  creation because the resolved Nature is already sufficient.
- **FED-029 [standard] — Catalog-wide assisted discovery.** Skill and
  powered-up classification consider the full installed compatible Template
  catalog rather than a hard-coded shortlist. Template guidance under
  `MOD-048` may improve recall and explain candidate evidence, but judgment may
  also use the preserved source Raw and canonical context. The attributed
  proposal identifies the winning Template and catalog version; low
  confidence or no suitable candidate enters the unchanged dumb route.
- **FED-030 [core] — Contextual enabling baseline.** Feeding an enabling Brick
  from a blocked-work reaction has one deterministic dumb structural
  suggestion: make the new Brick a sibling of the blocked Brick under the same
  immediate parent, propose the same effective Domain path shown for the
  blocked Brick, and add a Dependency from the blocked Brick to the new
  prerequisite. A root Brick therefore proposes another root Brick. The
  suggestion is visible and reversible; it never silently reparents,
  reclassifies, or equates dependency with importance. Accepting the shown
  Domain path stores explicit direct memberships on the new Brick under
  MOD-061; composition itself grants none.
- **FED-031 [standard] — Assisted enabling exception.** Skill or powered-up
  mode may replace the dumb structural suggestion with one attributed
  canonical proposal when title, hierarchy, Domain, or relationship evidence
  supports another parent or Domain. It cannot remove or reverse the enabling
  Dependency. The complete proposed parent, proposed direct Domain memberships
  with their effective paths, and Dependency are shown before confirmation.
  With weak or conflicting evidence, it must
  reuse the dumb baseline. Rejecting an assisted proposal records no evidence
  and enters the unchanged dumb structure route with the input preserved.
- **FED-032 [core] — Dumb better-way scaffolds an enabling Brick.** The dumb
  `find a better way` route classifies the intended improvement as
  `automate repetitive parts`, `simplify the process`, `learn another method`,
  or `get help from someone`. It derives one editable title using the matching
  safe prefix `Automate parts of:`, `Simplify:`, `Learn a better method for:`,
  or `Get help with:` followed verbatim by the served Brick title. The complete
  preview uses FED-030's sibling, effective-Domain, and Dependency baseline;
  proposes `atomic_task` with a lazy human Nature review; and shows local
  importance insertion as post-commit reviewable evidence rather than asking
  comparisons before creation. No handle or durable identity exists before
  acceptance.
- **FED-033 [standard] — Assisted better-way proposal stays attributable.**
  Powered-up or Skill may propose one concrete title, Raw content attached as
  description, Nature, or structure from the served Brick's actual context.
  The complete proposal
  names its source and still passes through the same human preview. Rejecting
  it opens the unchanged FED-032 classification; editing never lets assistance
  allocate an identity, accept its own evidence, or bypass the canonical CLI.
- **FED-034 [core] — Dumb fear recovery asks for the missing content.** The
  dumb `validate the risk first` and `make a safer first move` routes do not
  invent advice from a title. They ask one short free-text question:
  `What should be learned or tested first?` or `What would be a safer first
  move?`. The input uses the ordinary English reminder and then opens the same
  complete enabling-Brick preview. Validation proposes `atomic_task`, phase
  `validation`, and lazy human Nature review. A safer move proposes
  `atomic_task` with lazy human Nature review and no inferred phase.
- **FED-035 [core] — Dumb support recovery is entity-first.** `Get support`
  first selects an existing ExternalEntity through typed `@` autocomplete or
  its visible `New person or company...` route. It then offers `ask for
  advice`, `work together`, and `delegate this Brick`. Advice derives the
  editable title `Ask <display name> for advice about: <served title>` and
  enters the canonical request-handoff route, including its successor Wait.
  Work together derives `Arrange work with <display name> on: <served title>`
  and uses FED-030's enabling Dependency preview; it never invents a meeting,
  schedule, or delegation. Delegate enters the canonical Delegation preview
  for the served Brick and selected ExternalEntity.
- **FED-036 [standard] — Assisted fear recovery preserves the dumb contract.**
  Powered-up or Skill may prefill one attributed validation or safer-step
  suggestion, or propose an ExternalEntity and support route from canonical
  context. The complete editable preview remains mandatory. Rejection returns
  to the corresponding unchanged dumb input or entity-first route; assistance
  cannot create a risk score, accept its own proposal, or bypass CLI
  authority.
- **FED-037 [core] — Goal clarification changes descriptive content, not
  ontology.** The dumb `vague` goal route asks `What result should this Brick
  produce?`, preserves the entered text as Raw content, and previews its
  application through the Brick's `RawLink(role = description)`. It creates
  no `Definition`,
  `Outcome`, acceptance-criterion field, or clarification Brick. The preview
  exposes the complete resulting descriptive change before acceptance. It
  follows MOD-056..057 and WRK-105: the visible description is an ordinary Raw
  attachment, an existing description is revised on the same Raw identity,
  and a missing one creates one ordinary text Raw plus its
  `RawLink(role = description)` atomically. MOD-065 owns the generic revision
  encoding; the route may not expose it as a Description object.
- **FED-038 [core] — Missing information and first steps reuse enabling work.**
  A `vague` information route reuses WRK-067's contextual `collect more
  context` Feed with the current symptom carried provisionally. A first-step
  route offers existing decomposition, `learn about the subject`, and typed
  human support rather than inventing a planning object. Any new work uses the
  ordinary FED-030 enabling baseline, full preview, lazy claims, and local
  importance evidence. The route never turns descriptive text itself into a
  Brick.
- **FED-039 [standard] — Assisted vague clarification remains attributable.**
  Powered-up or Skill may propose one goal clarification, contextual enabling
  Brick, decomposition draft, learning Brick, or support target from canonical
  evidence. The proposal identifies its source and enters the same dumb
  Description or enabling-work preview. Rejection returns to the unchanged
  dumb route, and assistance cannot allocate identity or apply descriptive
  content on its own.
- **FED-040 [core] — Dumb hard recovery reuses ordinary enabling Feed.** The
  `learn or practice first` route asks `What should be learned or practiced
  first?` through contextual Feed. The entered title then passes through
  ordinary Nature confirmation, FED-030 sibling/Domain/Dependency preview,
  and local importance insertion; the core does not infer that practice is a
  habit or that learning is atomic. `Break into smaller parts`, `find an easier
  approach`, and `get help` reuse the existing decomposition, FED-032
  better-way, and FED-035 support builders respectively.
- **FED-041 [standard] — Assisted hard recovery changes only the proposal.**
  Powered-up or Skill may propose one attributed learning/practice Brick,
  decomposition, easier method, or support target from canonical context. It
  still enters the corresponding complete dumb preview. Rejection returns to
  the unchanged dumb route, and assistance cannot classify effort, accept a
  structure, or create enabling work on its own.
- **FED-042 [core] — Target mechanics choose the continuation.** Selecting a
  checklist owner proposes a ListEntry; selecting a RawShelf proposes shelf
  membership; selecting an ordinary Brick asks whether the Raw should become
  independently suggestible child Work. `yes` enters Nature, structure, and
  local importance settlement; `no` proposes a typed Raw attachment. A target
  is never treated as a generic folder, and its Nature is never inferred from
  the fed text.
- **FED-043 [core] — Browse, search, and create are distinct.** `[m]ore
  matches...` deterministically pages additional existing candidates from the
  same ranked set. `[s]earch...` opens typed autocomplete across every
  compatible existing destination. `[c]reate a new group...` stops searching
  and enters explicit new-destination discovery. None of these actions claims
  that the user has inspected or rejected unseen candidates. The unchanged
  slash palette is labelled `[/] menu...` on this screen so `more` cannot be
  mistaken for system commands.
- **FED-044 [standard] — Recent material may support one batch proposal.** A
  Skill or powered-up host may observe a bounded recent-Feed window and propose
  one explicit disposition for several named Raws, such as routing `milk`,
  `coffee`, and `bread` to one grocery checklist. The proposal identifies its
  source, enumerates every affected Raw and resulting ListEntry or link, and
  requires ordinary consent. Rejecting it neither weakens nor resolves any Raw
  and enters dumb triage. Dumb mode may expose deterministic recent-neighbor
  evidence but performs no semantic clustering.
- **FED-045 [core] — Routing preserves origin.** Materializing a Brick or
  ListEntry, adding a shelf membership, or attaching content records an
  explicit link to the source Raw and a triage disposition. The Raw keeps its
  original representation, normalization, provenance, and identity. Semantic
  undo reverses the disposition and derived mutation without inventing or
  losing the original Feed material.
- **FED-046 [core] — Owner-scoped ListEntry reuse and quantity.** Duplicate
  review for a ListEntry is scoped to its checklist owner; a label such as
  `Milk` is not a global object. Refeeding an open match offers keeping it as
  is, adding the newly fed quantity, changing quantity, or creating a
  deliberately separate distinguishable entry. Reusing a resolved or
  cancelled match reopens the same owner-scoped identity while preserving its
  earlier result in history. Quantity follows MOD-063. The add action appears
  only when both amounts have the same normalized unit; otherwise the screen
  offers keep, change, or distinguishable separation without implying a
  conversion.
- **FED-047 [core] — Explicit contextual builders may continue.** When the
  user has already chosen an unambiguous result such as creating a
  prerequisite, investigation, or child Work item, submitting its contextual
  text still commits source Raw first and may immediately continue the
  corresponding preview instead of asking UX-T01 again. Rejecting or escaping
  that later preview creates no Brick and leaves the Raw in the Inbox. This is
  not semantic inference and does not change ordinary `/feed`, whose only
  immediate result remains Raw.
- **FED-048 [core] — Group is interface language only.** `Group` is not a
  durable core kind. New-group discovery asks how members should behave. A
  list shown as one working unit creates a Brick whose subsequent lifecycle
  question resolves `living_checklist` or `finite_checklist`; a shelf creates
  a RawShelf; independently suggestible child Work enters ordinary Brick
  Nature and structure discovery. Every branch shows its resulting canonical
  object before creation and keeps the source Raw in the Inbox if abandoned.
- **FED-049 [core] — Feed returns to useful work without a receipt toll.** A
  successful ordinary Feed commits one Raw, then redraws the revalidated
  suspended proposal or current-focus continuation with one transient
  `Fed: +handle "preview"` fact. The fact appears once, is not an event of its
  own, and never steals the primary question. If there was no prior useful
  envelope, the canonical `next` pipeline runs; a pristine store containing
  only the new Raw therefore reaches its `raw_triage` opportunity. Empty input
  stays in the editor with an educational error, and Escape before submission
  returns unchanged. Contextual builders already covered by FED-047 resume
  their declared continuation after the Raw commit rather than entering
  ordinary triage.
- **FED-050 [core] — Raw triage can finish without creating another object.**
  Question mark on the independent-Work question asks whether seeing this Raw
  alone under `Work:` would communicate one useful action such as doing,
  considering, or reading it. Yes returns to Work materialization; no returns
  to destination selection. A second uncertainty may inspect the complete Raw
  once and repeat the question; another uncertainty leaves triage pending.
  Destination selection always includes `keep as standalone raw material` in
  addition to ranked compatible targets, search, and new-group discovery.
  Accepting standalone records that triage disposition, removes the Raw from
  the derived Inbox, and creates no shelf, link, entry, Brick, importance
  evidence, archive state, or hidden classification.
- **FED-051 [core] — Raw-to-Work materialization has one final mutation
  boundary.** After triage chooses independent Work, the dumb route resolves,
  in order: Nature; optional compatible Template and every required validated
  Template/Nature input; an editable canonical title; optional parent proposal;
  optional direct Domain membership proposal; duplicate suspicion; and local
  sibling importance insertion. The title starts selected when a bounded text
  line, source label, or filename supplies a deterministic draft; otherwise
  the human enters it. The English hint remains advisory. With no recorded
  parent evidence, root is the visible final fact and no selector toll appears.
  With no recorded Domain evidence, the membership set is empty and no
  selector toll appears. An explicit edit from the final preview can still
  open either selector. A parent never supplies Domain membership silently.

  A suspected existing Brick asks whether completing that existing Work would
  also handle the proposed intention. Reuse links the preserved Raw to that
  Brick as its materialization source and creates no new Brick or importance
  slot; keep-separate retains the draft and may keep the same title because
  equal titles are valid identities. Read-only differences may be inspected
  and return to the same decision. `merge` is absent because no second Brick
  exists yet.

  Importance comparisons cite the draft as proposed Work without a `#` handle
  and remain inside its recoverable checkpoint. When the exact sibling slot is
  resolved, one final preview names source Raw, title, Nature, Template or
  none, required configuration, parent or root, direct Domains or none,
  adjacent importance neighbors, confidence/provenance, and any lazy claim.
  Its yes atomically creates the Brick and handle, source relationship,
  triage disposition, position, accepted draft comparisons, and configured
  facts. No rejects only this materialization and leaves the Raw in the Inbox;
  reverse navigation edits the nearest draft fact. No partial Brick or human
  comparison evidence survives cancellation.
- **FED-052 [core] — Raw organization asks one consequence at a time.** The
  dumb Raw detail surface offers `revise`, `link`, `shelve`, `classify`,
  `source`, `translate`, and `archive`; it never opens a metadata form. Link
  first chooses one MOD-067 role, then a compatible autocomplete target, then
  previews the relationship. Shelve and classify use bounded searchable
  multi-selectors. Empty selection is valid. Every accepted action is one
  reversible event family and returns to the same Raw detail.
- **FED-053 [core] — Description editing remains ordinary Raw editing.** If a
  Raw is a description, revision preview names the Brick and any other direct
  consumers before commit. Changing its current representation away from text
  is unavailable until the description link is detached or moved. Creating a
  description from Brick context first creates one text Raw and its unique
  link atomically; detaching never archives it. A cardinality conflict shows
  the two existing endpoints and offers only inspect, detach one explicitly,
  or cancel—never copy or merge by implication.
- **FED-054 [standard] — `/translate` is an interruptible review queue.** With
  a target it opens that Brick title or Raw; without one it previews counts for
  active non-English Brick titles and stale or missing Raw normalizations.
  Archived material is excluded unless explicitly included. Brick titles are
  replaced in place after an individual preview; event history preserves the
  prior title. Raw text is stored as MOD-071 normalization on the same Raw and
  original revision. Unsupported non-text candidates are reported, not
  guessed. Dumb mode uses a selected editable English field; powered-up or
  Skill may prefill and attribute that same field. Each acceptance is atomic,
  interruption resumes at the next unresolved candidate, and rejection opens
  the dumb editor rather than skipping consent.
- **FED-055 [standard] — Search uses both human memory and English
  normalization.** Exact handle and exact original-content matches rank before
  normalized matches. Current accepted English normalization supports
  language-independent matching and duplicate suspicion. Stale normalization
  remains searchable with a visible stale marker and lower rank; no result is
  hidden merely because translation is missing. Proper ExternalEntity names
  retain declared spelling and are outside bulk translation.
- **FED-056 [standard] — Source checking proposes truth; it never rewrites it.**
  A changed external observation presents a bounded difference and asks
  whether it is a newer revision of the same Raw, separate derived material,
  or unrelated. An unchanged check records only the observation. Missing,
  inaccessible, unauthorized, malformed, or relocated sources enter typed
  source review and cannot archive, complete, revise, or detach local data.
  Dumb mode can inspect and decide every branch; assisted modes may summarize
  differences or rank a branch but use the same preview and confirmation.
- **FED-057 [core] — Domain membership management is direct and symmetric.**
  Brick or Raw detail exposes `classify` with a searchable multi-selector over
  active Domain paths. The final preview lists additions and removals; yes
  applies one relationship batch, and an empty set means explicitly no Domain.
  Creating a Domain is a separate named action and returns to the same draft.
  Parentage, RawLinks, source, requester, title, and recent proximity may rank
  a proposed path but never create membership without this preview.
- **FED-058 [standard] — Domain maintenance uses a small command family.**
  `lant domain` inspects the forest and offers create, rename, move, merge,
  archive, restore, members, and focus behavior. Guided arguments use complete
  paths and ordinary autocomplete. Each mutator shows identities, path changes,
  affected direct membership counts, active-focus/scope consequence, and
  conflicts before one atomic acceptance; no command overloads Brick
  composition or RawShelf organization.

## Reference flows

Feeding `comprar leite` first produces exactly one Inbox Raw preserving the
original Portuguese input. Later dumb or assisted triage may produce:

1. attributed canonical English `milk` on that same Raw;
2. duplicate and compatible-target candidates;
3. a proposal to add one ListEntry under `#… "Buy groceries"`;
4. an explicit keep, quantity, reopen, or separate-item result;
5. a deterministic choice rather than silent routing.

Feeding `https://example.com/article` first produces one URL Raw. Later triage
may produce:

1. external-origin and snapshot policy on that same Raw;
2. a proposal for `#… "Read …"` using `article_reading`;
3. ordinary sibling importance insertion;
4. after completion, an optional deterministic future `not_before`.

Neither flow adds domain-specific branches to the core.

# 3. Feeding and organization

## One ingress

- **FED-001 [core] — Feed is the door.** `feed` is the sole canonical ingress
  vocabulary. It accepts material or intent without assuming in advance which
  durable entity should result.
- **FED-002 [core] — Canonical routes.** A resolved feed may preserve Raw,
  create a positioned Brick, add a ListEntry to a compatible owner, instantiate
  a template, or enrich an existing entity after duplicate review.
- **FED-003 [core] — Preserve before interpretation.** Original input is
  retained before normalization, translation, extraction, or routing, so a
  rejected proposal cannot lose user material.
- **FED-004 [core] — Fast path.** Creating a Brick requires a title and one
  Nature. Phase, effort, impact, Domain, descriptive Raw, dates, and other
  optional axes are enriched later when useful.

## Classification and confirmation

- **FED-005 [core] — One validated Nature.** The operator skill or powered-up
  REPL may rank Nature, template, parent, Domain, or entry-target candidates.
  The dumb REPL obtains the same bounded candidate set from the core. The
  resulting concrete route is shown whenever it changes structure or lifecycle
  semantics. Dumb interaction resolves Nature before offering compatible
  Templates; it never mixes both concepts in one flat choice.
- **FED-006 [core] — No hidden fallback.** Nature uncertainty opens a bounded
  tree of capability questions answered with `yes`, `no`, or
  `[?] I don't know`. The tree resolves a validated Nature before creation.
  Repeated uncertainty keeps the Feed interaction pending; it never assigns a
  generic Nature or silently routes to a parent or ListEntry owner.
- **FED-007 [standard] — Contextual convenience.** A currently open collection
  or exactly one compatible target may provide a suggested default. It remains
  visible and reversible. Template selection is optional after Nature
  resolution unless a confirmed Template has already resolved that Nature.
- **FED-008 [standard] — Powered-up assistance.** A model may translate,
  classify, rank duplicate candidates, and provisionally pre-order, but its
  structured proposal is attributed AI evidence and cannot fabricate human
  comparison history. A proposed Template shows its resulting Nature and
  source before `[y]es · [n]o · [?]`; `no` enters the unchanged dumb
  classification flow.
- **FED-009 [standard] — Dumb completeness.** Every powered-up proposal has a
  deterministic dumb route using the factory Nature choice, capability
  questions, and later compatible-Template browsing. A Pack may supply
  validated definitions, but no executable Pack or model is required.

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

- **FED-019 [core] — Immediate position.** Every new active Brick receives a
  sibling position during the feed interaction. It is never left in an
  unordered staging pool.
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

- **FED-024 [core] — Mechanical discovery.** Dumb Nature discovery asks one
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

  A second uncertainty at the same split leaves Feed pending instead of
  guessing.
- **FED-026 [core] — Confirm the discovered Nature.** Reaching a leaf shows the
  resulting Nature and the decisive behavioral reason, then asks whether the
  classification is right. `yes` accepts the Nature and continues the Feed
  route. `no` discards only the local discovery path and returns to the
  factory Nature choice, where the user may select directly or use
  `[?] I don't know` to run discovery again. `[?] I don't know` at the result
  restarts discovery from Q1. None of these paths creates a Brick before the
  complete Feed route is confirmed.
- **FED-027 [core] — Discovery checkpoints.** Every discovery question and its
  result is an uncommitted navigation checkpoint. Escape returns to the
  immediately preceding question and discards only the answer and descendants
  after that checkpoint. Escape from Q1 returns to the factory Nature choice.
  Original Feed input, the prior proposal, and the random cursor are
  preserved; no domain event, semantic undo, or new draw occurs.
- **FED-028 [core] — Explicit optional Template.** After dumb Feed resolves a
  Nature, it presents the compatible Template choice whenever the installed
  catalog contains at least one candidate. The user may select one Template or
  explicitly continue with no Template. Absence of a Template never prevents
  creation because the resolved Nature is already sufficient.
- **FED-029 [standard] — Catalog-wide assisted discovery.** Skill and
  powered-up classification consider the full installed compatible Template
  catalog rather than a hard-coded shortlist. Template guidance under
  `MOD-048` may improve recall and explain candidate evidence, but judgment may
  also use the preserved Feed input and canonical context. The attributed
  proposal identifies the winning Template and catalog version; low
  confidence or no suitable candidate enters the unchanged dumb route.

## Reference flows

Feeding `comprar leite` may produce:

1. a Raw preserving the original Portuguese input;
2. attributed canonical English `milk` on that same Raw;
3. duplicate and compatible-target candidates;
4. a proposal to add one ListEntry under `#… "Buy groceries"`;
5. a deterministic choice rather than silent routing.

Feeding `https://example.com/article` may produce:

1. URL Raw with external origin and snapshot policy;
2. a proposal for `#… "Read …"` using `article_reading`;
3. ordinary sibling importance insertion;
4. after completion, an optional deterministic future `not_before`.

Neither flow adds domain-specific branches to the core.

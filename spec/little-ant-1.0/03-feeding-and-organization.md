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
  Nature. Phase, effort, impact, Domain, description, dates, and other optional
  axes are enriched later when useful.

## Classification and confirmation

- **FED-005 [core] — One validated Nature.** The operator skill or powered-up
  REPL may rank Nature, template, parent, Domain, or entry-target candidates.
  The dumb REPL obtains the same bounded candidate set from the core. The
  resulting concrete route is shown whenever it changes structure or
  lifecycle semantics.
- **FED-006 [core] — Safe fallback.** If the user skips Nature classification,
  an ordinary Brick uses `standard`; ambiguous input is never silently routed
  to a parent or ListEntry owner.
- **FED-007 [standard] — Contextual convenience.** A currently open collection
  or exactly one compatible target may provide a suggested default. It remains
  visible and reversible.
- **FED-008 [standard] — Powered-up assistance.** A model may translate,
  classify, rank duplicate candidates, and provisionally pre-order, but its
  structured proposal is attributed AI evidence and cannot fabricate human
  comparison history.
- **FED-009 [standard] — Dumb completeness.** Every powered-up proposal has a
  deterministic dumb route using shortlist, catalog browsing, custom
  capability questions, or the safe fallback.

## Raw, shelves, and sources

- **FED-010 [core] — Material is not work.** A bare URL, pasted conversation,
  document, note, or malformed fragment may enter as Raw. The system may then
  propose ordinary Brick work such as reading or reviewing it.
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

- **FED-015 [core] — Normalize for matching.** Canonical English, original
  input, title fingerprints, source identity, parent, Nature, Domain, and
  historical continuity may generate a bounded duplicate candidate set.
- **FED-016 [core] — Scope-sensitive review.** The review distinguishes:

  ```text
  reuse | enrich | merge | keep separate
  ```

  The available outcomes depend on whether the candidate is Raw, Brick, or
  ListEntry.

- **FED-017 [core] — No global object catalog.** Repeated real-world labels
  such as `milk` do not create one universal object. A grocery entry belongs
  to its standing checklist and may recur historically without title-derived
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

## Reference flows

Feeding `comprar leite` may produce:

1. preserved original Portuguese input;
2. proposed canonical English `milk`;
3. duplicate and compatible-target candidates;
4. a proposal to add one ListEntry under `#… "Buy groceries"`;
5. a deterministic choice rather than silent routing.

Feeding `https://example.com/article` may produce:

1. URL Raw with external origin and snapshot policy;
2. a proposal for `#… "Read …"` using `article_reading`;
3. ordinary sibling importance insertion;
4. after completion, an optional deterministic future `not_before`.

Neither flow adds domain-specific branches to the core.

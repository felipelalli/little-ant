# 26. Structured entries, identity, and duplicate suspicion

## 26.1 ListEntry

`ListEntry` is a lightweight occurrence attached to a Brick whose behavior
owns a structured list. It represents something that must be visible and
resolvable inside the batch but is not independently useful as Little Ant
work.

A ListEntry:

- has an immutable occurrence identity;
- belongs to exactly one owning Brick;
- has an English canonical label and may have quantity, note, and
  behavior-specific details;
- retains creation, resolution, removal, and provenance history;
- may reference Raw attachments;
- is never inserted into the Brick priority tree;
- is never selected independently by `next`;
- has no independent phase or effort.

The working generic lifecycle is `open | resolved | removed`; behavior-specific
surfaces may render `resolved` as checked, bought, packed, or another exact
outcome. Exact fields and enum names remain open.

`Milk` in `Buy groceries` is normally a ListEntry. A product URL, receipt,
coupon, photo, or recipe is Raw that may be attached to the entry or owning
Brick. Raw is durable source material; a current need to buy something is not
Raw.

If an item has its own deadline, blocker, independent focus, or completion
evidence, it should normally be a Brick instead. A bill occurrence is therefore
a Brick, not a ListEntry.

## 26.2 Entity identity

Title-derived entity identity is removed in 1.0.

- A persisted entity receives an opaque immutable ID derived from its creation
  event or equivalent replay-safe identity source.
- Renaming never changes identity.
- Two entities may have the same title or label.
- A title is display and search data, not a global uniqueness key.
- Ambiguous references must be resolved by ID, parent, context, state, or an
  explicit choice.
- Creation time is recorded automatically but is not appended to a title or
  used as a forced semantic date.

Dates such as `not_before`, `best_before`, and `deadline` keep their behavioral
meanings and must not be used merely to avoid a name collision.

The same identity rule applies to curated entities such as Party. A Party has
an opaque immutable ID and one current canonical display label. Renaming the
label does not change identity, create a replacement Party, or require an
identity alias. Two Parties may have the same display label.

Optional alternate names or nicknames are retrieval metadata:

- they may help candidate search and duplicate suspicion;
- they may overlap across Parties;
- they never become global IDs or unambiguous command aliases;
- a mutating operation still resolves ambiguity through opaque identity,
  context, or explicit selection.

Canonical events refer to opaque IDs. Human renderers and inspection
projections resolve the current label and enough context for readability.
Event-log legibility is therefore a projection concern rather than a reason to
embed a mutable human word in identity.

Content addressing remains appropriate for immutable bytes. Two snapshots with
the same content hash may share blob storage while remaining distinct captures
with distinct provenance. Entity identity, content identity, and duplicate
suspicion are separate concepts.

## 26.3 Canonical English and original input

Canonical searchable product data is English. When input arrives in another
language, the system should preserve both meaning and provenance:

```text
original_text
canonical_english
normalization_author
```

These are working field names. They represent three different concerns:

- `original_text` preserves the verbatim input as capture provenance, either
  on the applicable event or as Raw;
- `canonical_english` is the human-facing canonical title or label;
- `normalization_author` attributes translation or semantic rewriting to the
  human, operator, or powered-up adapter that performed it.

The canonical title receives only conservative deterministic cleanup: Unicode
canonical composition, removal of leading and trailing whitespace, and
collapse of internal whitespace or line breaks. This cleanup must not
lowercase or case-fold the stored title, strip punctuation or emoji,
singularize words, or otherwise rewrite meaning.

Phase, status, warning, and other product-owned emoji are renderer metadata and
never title content. An emoji intentionally supplied as user content may remain
in the canonical title; the verbatim original preserves it regardless.
Translation, capitalization repair, and semantic rephrasing are attributed
normalization decisions rather than hidden deterministic rewrites.

The verbatim original is not an alternative canonical title. The operator or
powered-up REPL may translate before canonical creation. Exact dumb-REPL
behavior when it cannot safely normalize language remains open.

## 26.4 Derived matching fingerprints

Duplicate suspicion must not use one destructive normalized title. The core
may derive several replay-safe, rebuildable matching fingerprints from
canonical data, including:

- conservatively Unicode-normalized and whitespace-normalized text;
- a case-folded variant;
- punctuation-insensitive and emoji-insensitive variants;
- tokenized variants with conservative English singularization.

Matching fingerprints are read-model evidence. They are neither persisted
entity identity, canonical title data, global aliases, nor proof that two
occurrences are the same. Exact, case-insensitive, punctuation-insensitive,
and semantic signals may carry different strengths. A match may retrieve or
rank a duplicate candidate but never causes a silent merge, deletion, or
identity collision.

## 26.5 Duplicate-suspicion pipeline

Repeated `feed` input is expected. Duplicate detection is therefore a
first-class capture mechanism, but suspicion is not identity and never
silently deletes or merges information.

The pipeline is:

1. preserve the original input;
2. produce or request canonical English;
3. determine the proposed entity type and relevant scope;
4. derive deterministic matching fingerprints and lexical features;
5. retrieve and rank possible existing matches;
6. explain the evidence for each meaningful suspicion;
7. propose reuse, quantity adjustment, merge, enrichment, or separate
   creation;
8. record the human or attributed operator decision.

Deterministic evidence may include:

- Unicode, case, whitespace, and punctuation normalization;
- English singularization or other conservative lexical normalization;
- relevant-token overlap and ordering;
- the same parent, behavior, template provenance, context, or recurrence
  period;
- active versus resolved or terminal state;
- prior confirmed merge and separation decisions;
- temporal proximity.

Powered-up or skill operation may contribute semantic candidates, translation,
and explanations as attributed AI evidence. The deterministic core validates
the proposed operation and retains authority; it does not call the model or
pretend semantic similarity is identity.

## 26.6 Scope-sensitive outcomes

Examples:

- `Milk` already open in the same grocery list is a strong suspicion. The
  system may propose increasing quantity, reusing the entry, or keeping a
  separate occurrence.
- `Milk` resolved during an earlier shopping run is history, not a collision;
  a new need creates a new occurrence.
- `Milk` in an office list and `Milk` in a home list are normally distinct.
- `Milk` and `Oat milk` are related but must not be silently merged.
- `Research milk intolerance` is not a duplicate grocery entry despite token
  overlap.
- A manually fed recurring bill that matches an already generated period
  should normally enrich the existing occurrence rather than create another.

Even when capture is merged into an existing entity, the event history must
preserve that a new input arrived, its original text, and the chosen target.

## 26.7 No global world-object catalog in 1.0

The label `Milk` does not automatically create or resolve to one global
real-world object. Product, brand, unit, aisle, price, and stock identity would
require a separate catalog model and are not justified for the 1.0 core.

History may still provide autocomplete and prior-entry suggestions. A future
`Thing` or `CatalogItem` requires an explicit use case and design review.

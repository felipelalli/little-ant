# 29. Text mentions and typed annotations

## 29.1 Purpose

Little Ant 1.0 may let a user type an interface token such as `@Alice` or
`#Plan the release` while editing an annotation-capable text field. The token
is convenient input and display syntax; it is not a canonical entity
identifier and has no semantic authority by itself.

When the user confirms an autocomplete result, the surface submits both:

```text
text: "Discuss the budget with @Alice"
annotation:
  target_type: party
  target_id: <opaque Party ID>
  displayed_token: "@Alice"
```

Exact field names are open.

A Brick selection follows the same structure with `target_type: brick` and
the selected Brick's opaque ID. The visible `#...` token is not a short ID,
checksum, or stored relationship by itself.

## 29.2 Typed annotation

A typed text annotation records at least:

- the owning entity, field, and applicable text revision;
- a target type and opaque target ID;
- the span, anchor, or equivalent location in that text revision;
- the token or label visible when the annotation was created;
- author and provenance.

Renaming the target never breaks the semantic reference because the opaque ID
is authoritative. The original text and recorded token remain historical.
Exact rendering of a renamed target, and whether the visible token is updated
or supplemented with the current label, remain open.

The core validates that the owner field supports annotations, the target type
is allowed, the target exists, and the annotation is anchored to the submitted
text revision. It does not infer a target from string similarity.

## 29.3 Interface resolution and sigils

The initial editor sigils have narrow presentation meanings:

- `@` opens Party candidate search;
- `#` opens Brick candidate search.

Both are interface syntax supported by autocomplete and explicit selection:

- a surface may search supported target types and show disambiguating context;
- one unambiguous-looking textual match is still only a proposal;
- ambiguous candidates require an explicit choice;
- an unresolved or unconfirmed token remains literal text with no annotation;
- an operator or powered-up REPL may rank candidates, but its proposal remains
  attributed and subject to the same confirmation and validation path;
- dumb mode reaches the same result through deterministic search and choice.

There is no global mutable `@slug` identity and no compatibility alias in the
core. A renderer may show friendly labels while commands and stored references
use opaque identity.

Party display labels and optional alternate names may retrieve autocomplete
candidates, but the visible token remains only interface text. Even one
apparently exact label match is not an identity proof. Confirmation stores the
selected opaque target ID, and a later Party rename requires neither text
parsing nor an alias chain to preserve the reference.

The same rule prevents collisions with external vocabulary. Typing or pasting
`issue #918`, `github:@alice`, an email address, or any other sigil-shaped
string creates no annotation unless the user explicitly selects an
autocomplete candidate. The surrounding characters do not need a fragile
global parser to guess which namespace was intended.

An explicit CLI short reference and an editor token are separate surfaces. A
renderer may include a short ID and current title for disambiguation, but the
annotation's opaque target ID is authoritative. The recorded visible token is
historical display data, not a checksum that validates the target title.

## 29.4 No implicit behavioral effect

A text annotation supports navigation, inspection, backlinks, and search. It
does not imply:

- requester or assignee;
- delegation or notification;
- dependency, wait, parent, or `about`;
- authorization or approval;
- an external message or effect.

Those remain explicit typed domain relationships or operations. Mentioning a
Party does not notify that Party. Mentioning a Brick does not connect its
lifecycle to the text owner.

## 29.5 External references

A standard URI in text remains literal content. A capable renderer may make it
clickable without creating a domain relationship, synchronization policy,
backlink, or reconciliation obligation.

When external material must be fed, refreshed, synchronized, or
reconciled, the surface proposes an explicit Raw with RawOrigin. The applicable
owner then receives a typed RawLink such as `attachment`, `source`, or
`evidence`. If a future annotation-capable field supports Raw targets, a typed
annotation may additionally anchor the visible URI to that Raw; it does not
replace RawLink semantics.

There is no universal public registry in which strings beginning with
`github:`, `gmail:`, `gchat:`, or another provider name become references in
arbitrary prose. An adapter may normalize such identifiers internally as
RawOrigin locators or import keys. The core validates the explicit Raw
operation rather than scanning text for provider schemes.

## 29.6 Annotation-capable fields and Raw

Only fields explicitly declared annotation-capable may carry typed
annotations. The core must not scan every free-text field for `@` tokens.
Email addresses, social handles, quoted content, code, and ordinary prose must
remain literal unless a surface submits a confirmed annotation.

Raw content is always preserved verbatim and is never automatically parsed,
rewritten, or bound to entities. A later extraction or explicit annotation
operation may propose references over a particular RawSnapshot without
changing its immutable bytes. Exact supported fields and Raw annotation
persistence remain open.

## 29.7 Editing and history

Annotations are tied to the text revision against which they were confirmed.
Editing text must not silently move a reference to a different substring or
target. A surface may propose deterministic re-anchoring when safe, otherwise
it asks for review or removes only the annotation while preserving text and
history.

If a target later becomes terminal, renamed, merged, unavailable, or deleted
under a future retention policy, historical annotation provenance remains.
Exact dangling-target rendering and reconciliation are open.

## 29.8 Still open

- Final entity and field names for typed annotations.
- Initial annotation-capable fields and any target types beyond the confirmed
  Party and Brick editor paths.
- Span representation, Unicode indexing, text revision identity, edit
  re-anchoring, and conflict behavior.
- Autocomplete search, ranking, pagination, disambiguation, and shortcut
  grammar.
- Exact visible-token grammar, copy/paste and export representation, and
  display after a short ID becomes ambiguous.
- Rendering after target rename, merge, terminal status, or unavailability.
- Backlink projections, filtering, export, and whether annotations influence
  duplicate-suspicion candidate retrieval.
- Exact explicit interaction that turns a literal URI into Raw with a
  normalized RawOrigin and the applicable RawLink.
- Explicit annotation over immutable RawSnapshots without treating extracted
  semantics as part of the original material.

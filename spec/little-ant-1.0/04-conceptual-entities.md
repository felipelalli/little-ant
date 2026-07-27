# 4. Conceptual entities

The following names reflect the current design. Names marked as open may still
change before the Allium specification is edited.

| Concept | Meaning |
|---|---|
| `Raw` | Durable, reusable, unorderable source material. |
| `RawOrigin` | The optional single live external origin owned by one Raw. |
| `RawSnapshot` | One immutable, content-addressed version captured from a Raw or its origin. |
| `RawLink` | A typed material relationship from a Brick, ListEntry, or Raw to Raw, with per-Brick reconciliation state when applicable. |
| `RawShelf` | A flat, unordered, many-to-many grouping of Raw material. |
| `Brick` | A positioned unit or container of work. |
| `BrickBehavior` | A persistent, versioned selection of core-supported interaction capabilities. |
| `BrickTemplate` | A one-time, inspectable creation recipe with no hidden runtime authority after expansion. |
| `ImportProfile` | An inspectable, versioned policy mapping an external source to capture, adoption, destination, and reconciliation behavior without containing credentials. |
| `ImportProfilePreset` | A credential-free declarative PackComponent that proposes reusable initial ImportProfile policy without becoming local policy authority. |
| `Little Ant Pack` | A versioned distributable bundle of declarative or executable extensions; it is not operational domain state. |
| `PackComponent` | One typed, versioned component inside a Little Ant Pack. Its kind fixes its input, output, capabilities, and authority boundary. |
| `SourceAdapter` | An executable Lua PackComponent that translates an external source into normalized candidates or observations and may execute only already-approved source effects. |
| `Enricher` | An executable Lua PackComponent that returns bounded, attributed proposals without canonical mutation authority. |
| `ReadOnlyExporter` | An executable Lua PackComponent that serializes a versioned core projection into bounded bytes and metadata without network, filesystem, or mutation authority. |
| `UIAdapter` | An executable Lua PackComponent that renders a canonical InteractionEnvelope on another surface and maps responses back to canonical action identity and interaction revision. |
| `CredentialBinding` | Local deployment configuration mapping a Pack credential slot to one encrypted-vault entry and account; it is neither Pack content nor domain state. |
| `ListEntry` | A lightweight, non-focusable occurrence inside a structured batch owned by a Brick. |
| recurrence rule | A deterministic rule that releases obligations or defines applicable practice opportunities. |
| opportunity trigger | An inspectable canonical rule that releases one target opportunity from one supported source event. |
| occurrence | One recurrence period, practice opportunity, or execution of standing work; exact persisted forms remain open. |
| `Place` | A stable canonical reference to a user-defined physical or logical place, without requiring coordinates or a global place catalog. |
| location observation | An attributed, time-bounded report that the user entered, left, or is present at a named Place. |
| text annotation | A field- and revision-bound typed reference from confirmed text to an opaque entity ID, without implicit behavioral effect. |
| `Party` | A person, AI agent, company, or area related to work, identified opaquely and presented through mutable labels. |
| `Dependency` | A blocker relationship between Bricks; it affects eligibility, not human priority. |
| `Wait` | An unresolved external condition or party wait. |
| `Delegation` | Work assigned to another Party and followed up independently from human focus. |
| comparison evidence | A timestamped priority, impact, or effort judgment with author, provenance, and applicable scope. |
| `EffortProfile` | A versioned ordered set of effort classes and their planning calibration. |
| impact evidence | Evidence supporting an expected-impact class and its public maturity. |
| scope revision | A human- or operator-confirmed semantic change to what a Brick includes. |
| proposal | A derived opportunity for focus, review, calibration, follow-up, or maintenance. |
| duplicate suspicion | A derived, explainable set of possible existing matches for new canonical input; it is not identity. |
| planning manifest | An immutable, reproducible record of one confirmed external planning simulation; it is outside operational domain state. |
| REPL checkpoint | Atomically persisted presentation state for exact dialog recovery; it is not a domain event. |

Not every projection or proposal needs to become a persisted entity. Persistence
is an open design choice wherever resumability cannot be derived safely from
the event history. The planning manifest and REPL checkpoint are deliberately
persistent artifacts without becoming Bricks or mutable domain entities.
Import candidates and provider source groups are projections or adapter
payloads rather than new work or material entities. A Little Ant Pack is
installed product content, while local ImportProfiles, CredentialBindings, and
the encrypted credential vault have bounded configuration or deployment
authority; none is a substitute for canonical Raw or Brick state. There is no
generic `Plugin` entity or arbitrary extension hook in 1.0.

No global `Thing` or `CatalogItem` is introduced in 1.0. Repeated labels such
as `Milk` are occurrences unless an explicit future catalog model is justified.

There is also no generic `Artifact` bag with arbitrary runtime types and opaque
status values. A Brick keeps canonical descriptive content directly; durable
material is Raw; external provenance belongs to RawOrigin and RawSnapshot;
and parent, dependency, `about`, delegation, and other behavioral
relationships remain explicit domain concepts.

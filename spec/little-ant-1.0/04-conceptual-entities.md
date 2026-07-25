# 4. Conceptual entities

The following names reflect the current design. Names marked as open may still
change before the Allium specification is edited.

| Concept | Meaning |
|---|---|
| `Raw` | Durable, reusable, unorderable source material. |
| `RawShelf` | A flat, unordered, many-to-many grouping of Raw material. |
| `Brick` | A positioned unit or container of work. |
| `Party` | A person, AI agent, company, or area related to work. |
| `Dependency` | A blocker relationship between Bricks; it affects eligibility, not human priority. |
| `Wait` | An unresolved external condition or party wait. |
| `Delegation` | Work assigned to another Party and followed up independently from human focus. |
| comparison evidence | A timestamped priority, impact, or effort judgment with author, provenance, and applicable scope. |
| `EffortProfile` | A versioned ordered set of effort classes and their planning calibration. |
| impact evidence | Evidence supporting an expected-impact class and its public maturity. |
| scope revision | A human- or operator-confirmed semantic change to what a Brick includes. |
| proposal | A derived opportunity for focus, review, calibration, follow-up, or maintenance. |
| planning manifest | An immutable, reproducible record of one confirmed external planning simulation; it is outside operational domain state. |
| REPL checkpoint | Atomically persisted presentation state for exact dialog recovery; it is not a domain event. |

Not every projection or proposal needs to become a persisted entity. Persistence
is an open design choice wherever resumability cannot be derived safely from
the event history. The planning manifest and REPL checkpoint are deliberately
persistent artifacts without becoming Bricks or mutable domain entities.

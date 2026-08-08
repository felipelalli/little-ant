# Testing and traceability

Tests are executable evidence for the canonical contract. They are not
generated assertions against a second interpretation of it.

## Evidence layers

| Layer | Purpose | Typical evidence |
|---|---|---|
| Pure unit | formulas, codecs, local invariants | fixed vectors and boundary tables |
| Property | algebraic and graph invariants | replay equivalence, acyclicity, stable order, positive chance |
| State machine | command/event lifecycle | generated valid/invalid command sequences |
| Protocol contract | sparse schemas and errors | canonical JSON golden files |
| Dumb UX golden | exact human interaction | key/input → exact screen → next envelope |
| Scenario replay | realistic vertical behavior | synthetic-week and failure fixtures |
| Adapter contract | effects without provider authority | recorded request/receipt fixtures |
| Migration | v0.1 preservation and cutover | immutable archive/candidate fixtures |
| Surface parity | no second grammar | dumb/powered-up/Skill/web paired replay |

The dumb UX golden is the primary observable acceptance layer. Lower tests
explain failures; higher adapters may not make a divergent dumb flow pass.

## Deterministic test world

Every scenario declares:

- dataset seed and all starting random cursors;
- clock, timezone, workday and habit-day boundaries;
- UUID allocation sequence;
- actor/profile and presentation capabilities;
- source observations and effect receipts;
- starting event segments and blobs;
- expected entry and exit dataset cursors.

Tests never depend on the machine clock, OS entropy, unordered map traversal,
locale, terminal theme, live network, provider account, or filesystem listing
order.

## Contract test descriptor

Every contract test is registered as data alongside its executable body:

```text
evidence_id       SCN-FED-001 or a stable implementation fixture ID
rules             exact PRD/MOD/FED/IMP/FOC/WRK/UX/DAT/MIG IDs
screens           exact UX screen IDs when visible
flow              exact flow-coverage row name
kind              unit | property | state-machine | protocol | golden | e2e
spec_hashes        generated hashes of the referenced canonical blocks
```

The test runner emits a machine-readable coverage report. CI fails when:

- a referenced ID is missing or duplicated;
- a canonical block hash changed without its tests being reviewed;
- a flow has no executable evidence;
- a test claims an unknown flow or rule;
- a verified flow loses a required evidence kind;
- a result or screen is updated without its golden diff being reviewed.

The generated owner union must equal the complete canonical rule, screen,
scenario, and flow catalogs. Unknown, unowned, multiply owned, or ambiguously
ranged IDs fail the audit. Every rule has one operational owner, or a reviewed
non-testable rationale when it truly cannot have executable evidence. Every
flow has exactly one slice owner.

Prohibitive, gate, and conditional rules require a negative or boundary test,
not merely a successful happy path. The deterministic calculation profile has
engine-independent golden vectors so a locally consistent implementation
cannot silently reinterpret its arithmetic or random streams.

[`coverage.tsv`](coverage.tsv) assigns implementation ownership only. It does
not claim semantic coverage and is not the generated test report.

## Required cross-cutting properties

The following properties start as soon as their types exist and remain in the
full suite:

- folding accepted event segments twice yields the same projection;
- incremental fold equals replay from zero;
- a rejected, dry-run, stale, or unconfirmed action changes no canonical
  cursor or random cursor;
- every accepted mutation advances the dataset cursor and returns its compact
  observable postcondition;
- every durable identity is UUIDv7 and every human handle resolves without
  becoming stored identity;
- active composition and Dependency graphs remain acyclic;
- every active Brick has exactly one Nature and one sibling position;
- every admitted weighted candidate has a positive integer weight;
- changing one random-purpose cursor cannot perturb another purpose;
- rendering, paging, inspection, help, and navigation consume no semantic
  randomness;
- replay performs no external IO;
- an interrupted command segment is either absent or wholly accepted;
- undo is atomic for its declared command group and redo revalidates current
  preconditions;
- sparse JSON never omits a schema-declared meaningful false, zero, null, or
  requested empty collection.

Each slice freezes at least one byte-identical accepted dataset. Every later
slice replays the whole corpus with effects, Packs, and assisted models
disabled. Replay from zero must preserve the expected cursor and canonical
projection; it may not reinterpret an old event through current heuristics.

## Golden transcript discipline

A golden fixture contains the semantic envelope and plain rendering. Styled
tests assert roles rather than embedding terminal-specific ANSI bytes in every
fixture. Separate capability fixtures cover color, no-color, emoji, no-emoji,
narrow width, redirected output, `TERM=dumb`, and motion-disabled startup.

Golden updates are never accepted in bulk merely because implementation
changed. Each diff names the owning UX/rule IDs and confirms that action order,
shortcuts, wording, punctuation, defaults, footer facts, and transition stayed
canonical.

A normative canonical hash change invalidates affected evidence and demotes a
verified flow to implemented until reviewed replacement evidence passes. Only
a recorded editorial classification may refresh hashes without that demotion.

## Regression vocabulary guard

S00 derives a current-public vocabulary check from PRD-013, PRD-018, UX-204,
and the rejected section of the command catalog. It scans v1 module names,
public identifiers, current help, screens, schemas, tests, README examples, and
Pack contracts. Explicit migration parsers, immutable v0 fixtures, quoted
educational errors, and the capability matrix are narrow allowlisted evidence.

This check detects reintroduced aliases such as public `capture`, `priority`,
`weight`, `seed` stage, `unify`, `abandon`, or executable `la`; it must not ban
ordinary English inside historical or explanatory contexts blindly.

## Allium disposition

No Allium artifact is required by any slice or release gate. If a later
concrete invariant motivates an experiment, its obligation must cite exact
rule hashes and be tested against existing golden/state-machine evidence. A
passing Allium analysis never upgrades a flow to `verified` by itself.

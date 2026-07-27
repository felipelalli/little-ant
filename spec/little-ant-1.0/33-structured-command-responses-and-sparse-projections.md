# 33. Structured command responses and sparse projections

## 33.1 Design objective

Little Ant is operated by humans, the deterministic REPL, scripts, and LLM
operators. Its default structured response must be sufficient for the current
operation without repeatedly injecting complete entities, empty collections,
and neutral fields into an LLM context.

The 1.0 default is therefore a command-specific operational projection, not a
full state dump. A complete projection remains explicitly available for
debugging, generic inspection, export, and clients that genuinely need every
field.

This corrects the older proposal that every Brick mutator should echo the
entire resulting Brick. The underlying concern was valid: a caller should not
need another `show` merely to discover the mutation's postcondition. The
solution is a compact typed postcondition, not an unconditional full entity.

## 33.2 State, projection, and serialization are different

Three layers remain distinct:

1. canonical events and replayed domain state retain all authoritative facts;
2. a command selects a typed projection appropriate to its purpose;
3. the JSON serializer applies the presence rules of that projection.

Omitting a field from a sparse response never erases domain state. Likewise,
adding a complete projection does not create another source of truth. Every
projection is derived from the same current state and command outcome.

The projection identity and schema must be inspectable or versioned so a
machine client knows which presence rules apply. The exact schema-version and
projection-selection grammar remain open.

## 33.3 Sparse success and failure envelopes

A successful operational envelope carries the stable essentials:

```json
{
  "ok": true,
  "human": "✓ completed",
  "result": {
    "kind": "brick_changed",
    "brick": {
      "id": "c524be5",
      "title": "Reduce structured response noise",
      "status": "done",
      "revision": 731
    },
    "changed": ["status"]
  }
}
```

The example is illustrative rather than final field grammar. Confirmed
semantics are:

- `ok`, the canonical `human` rendering, and a typed command result are
  available on success;
- `dry_run` is emitted when the response represents a dry run rather than
  repeating the neutral false value on every ordinary operation;
- warnings, spawned entities, pending effects, notices, and other collections
  appear when non-empty or when they are the requested answer;
- a failure contains its code and message, with a hint only when one exists;
- full event payloads are not copied into every ordinary response merely
  because the operation was implemented through events.

An actionable condition created by a command or lazy tick cannot be hidden
only inside an omitted event payload. It must appear in the applicable typed
result, notice, status, or interaction envelope. Complete audit events remain
available through an explicit event or full-debug projection.

## 33.4 Mutator postconditions

Every successful mutation returns enough structured information to establish
its observable postcondition without a follow-up query. For an affected Brick,
the compact reference normally includes:

- opaque ID;
- canonical title when useful for human or operator continuity;
- the relevant resulting status or other state discriminator;
- a state or entity revision token suitable for stale-response protection;
- the fields or semantic aspects changed by the command.

If the operation creates, updates, or exposes several entities, its result
contains compact references to the affected set and includes only non-empty
spawned, pending-effect, or next-interaction collections.

The postcondition is not necessarily a generic field patch. Some commands have
domain outcomes such as completion, recurrence release, reconciliation, or a
new pending approval. Their result uses a command-specific typed shape rather
than forcing every outcome into one arbitrary key-value delta.

Mutators do not return the entire Brick merely for uniformity. A caller that
needs descriptions, all effective metadata, every relationship, or history
requests the corresponding query projection explicitly.

## 33.5 Presence and omission rules

There is no global recursive rule that removes every `null`, empty value,
`false`, or zero. Presence is declared per field and projection.

The operational defaults are:

| Value or condition | Sparse projection behavior |
|---|---|
| optional value that is not applicable | omit it |
| empty collection unrelated to the requested answer | omit it |
| collection explicitly requested by the command | include it, even when empty |
| neutral `false` or zero with a schema-declared default | it may be omitted |
| `false` or zero that materially answers the command | include it |
| selected tri-state boolean | include `true`, `false`, or `null` explicitly |
| field cleared by a mutation | represent the clearing explicitly in the typed postcondition |

Consequently:

- absence in a sparse projection means “not emitted by this projection” unless
  that field's schema declares an omission default;
- absence must not be interpreted generically as canonical `null`, `false`,
  zero, or an empty collection;
- `null` is reserved for a selected field whose explicit unknown or unset
  state matters;
- meaningful zero values remain visible when the question or projection makes
  them relevant;
- the complete projection emits every field selected by its schema, including
  nulls, false values, zeros, and empty collections.

These rules apply to responses, not to mutation syntax. Omitting a request
field means “leave unchanged”; clearing a value requires an explicit canonical
operation or patch meaning.

## 33.6 Query projections

Query commands also use purpose-bounded projections:

- a summary projection supports lists, candidates, references, and comparison
  prompts;
- an operational detail projection supports ordinary `show`, status, and
  interaction;
- relationship, history, or other subject projections provide focused depth;
- a complete projection supports debugging and generic clients.

Exact projection names and flags remain open. The important rule is that
encoding and scope are independent: requesting JSON does not necessarily ask
for every field, and requesting a complete projection does not create a
different semantic model.

Field selection and filtered history may provide additional context control,
but they must use schema-known fields and deterministic validation rather than
an unchecked expression language. Progressive disclosure lets an operator ask
for detail only when it becomes useful.

## 33.7 Status and interaction envelopes

The core continues to own one canonical typed StatusSummary and one canonical
compact human rendering. Different consumers may request sparse or complete
projections of that same summary:

- an ordinary operator receives the fields relevant to current decisions;
- the REPL may request the complete status fields needed for its persistent
  regions;
- a diagnostic client may explicitly request every field;
- all consumers receive the same canonical `human` line where applicable.

No surface parses the human line to reconstruct facts, and no surface invents
a second status model.

The state-scoped interaction envelope follows the same rule. It contains the
current prompt, valid actions, canonical command representations, and relevant
help, but it does not attach the full command catalog, complete Brick, and raw
event history unless the current interaction actually requires them.

## 33.8 LLM context and auditability

Sparse responses are an interface and performance property, not an excuse to
hide decisions. A compact result remains typed, attributable, and sufficient
to explain what changed. The full current projection, event history, schema,
and filtered semantic history remain available on demand.

This gives the skill and powered-up REPL a bounded context while preserving
diagnostic depth:

```text
ordinary operation -> sparse typed result
need more context   -> focused subject projection
debug or generic    -> explicit complete projection
audit               -> explicit event/history query
```

The exact token or byte budgets, schema negotiation, compatibility policy,
event-summary format, and CLI flags remain open for the Allium and
implementation-planning phases.

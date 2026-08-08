# ADR 0003 — Persisted guided checkpoints and atomic materialization

Status: **accepted for implementation**

## Context

The dumb REPL, headless CLI, powered-up mode, Skill, and later local web surface
must continue the same guided interaction after restart. Raw triage also gathers
several provisional answers—Nature, Template, title, parent, Domains, and local
importance evidence—before the user approves one durable materialization.
Writing each answer into canonical history would confuse navigation with domain
activity and leave partially created Work after cancellation or a crash.

## Decision

The application persists one integrity-protected presentation checkpoint beside,
but never inside, canonical JSONL history. The checkpoint contains the current
typed `InteractionEnvelope` plus bounded back and forward envelope stacks. Every
envelope carries the dataset cursor, semantic precondition hash, interaction ID,
revision, grammar, typed opportunity, actions, and footer facts needed to render
or answer it without hidden REPL state.

Local Escape, Backspace/Left, and Right navigation updates only this checkpoint.
It emits no domain event and consumes no semantic randomness. A restarted client
receives the same envelope. An answer is accepted only after its envelope
integrity, revision, cursor relevance, action identity, and semantic
preconditions are revalidated; otherwise the dispatcher returns a fresh useful
envelope without mutating history.

Raw-to-Work, Raw-to-ListEntry, RawShelf creation/membership, Raw attachment, and
existing-Work reuse are final-preview commands. Each accepted command publishes
one immutable command-group segment containing every event required to preserve
the source Raw, its disposition, links, created identities, Nature/Template
provenance, parent/Domains, sibling position, and lazy-review claims. Draft
answers never allocate durable identities.

`MaterializationEffect` records enough inverse evidence for later generic
semantic compensation: created Bricks, ListEntries and RawShelves; new shelf
memberships and links; source disposition; importance evidence; and prior
quantities. S05 owns the shared undo/redo interaction and compensation event
machinery. S02 owns proving that its command groups record complete evidence and
replay atomically.

## Consequences

- All guided surfaces share one protocol and one dispatcher.
- Restart-safe drafts do not pollute the event log.
- Browser-style local navigation remains distinct from semantic undo/redo.
- A crash exposes either no materialization or the entire command group.
- Raw receipts survive every classification and remain independently inspectable.
- Description is a cardinality-constrained RawLink role, not a Brick scalar.
- Domain inheritance is never hidden: parent Domains may be proposed, but the
  user explicitly accepts or changes the proposal when evidence exists.
- Later compensation can be implemented without reconstructing overwritten
  quantities or guessing which structures a command created.

## Alternatives rejected

Persisting each wizard answer as a domain event would turn Back into semantic
history, consume identities before consent, and require compensating incomplete
drafts. Keeping drafts only in REPL memory would break restart and make headless
clients semantically weaker. Encoding draft fields in ad-hoc command arguments
would create a second protocol and permit stale clients to bypass current

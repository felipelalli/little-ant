# 31. Resumable interactions and honest progress

## 31.1 Three distinct layers

A guided interaction spans three layers that must not be collapsed.

### Confirmed domain state

Every accepted semantic answer uses its ordinary canonical core operation and
is appended to the event log immediately. Examples include a priority
comparison, an impact judgment, a skip, an approved description revision, or
a confirmed dependency.

This state is authoritative, replayable, and available to every surface.
There is no separate batch commit at the end of a question round.

If a multi-step operation requires durable provisional domain state, such as
the smallest incoherent priority segment awaiting atomic recalibration, the
core records only that required state explicitly. It does not represent the
interaction as a Brick.

### Core interaction envelope

The core assembles a state-scoped interaction envelope containing the current
prompt, valid actions, canonical commands, shortcuts, relevant help, and an
honest progress summary. The envelope is bound to the domain revision against
which it was produced.

The next useful prompt is normally derived from current domain state. It is not
a frozen ordinal cursor such as “continue at question 12.” A new Brick, a
confirmed comparison, a resolved blocker, or another concurrent event may
legitimately change which question is most informative next.

### Surface checkpoint

A REPL or another capable surface may checkpoint presentation state such as:

- the current screen and selected item;
- an unsubmitted text buffer and editing cursor;
- navigation position;
- the local transcript;
- the domain revision and interaction identity it was displaying.

This checkpoint has presentation-recovery authority only. It is never the
source of a domain answer, description, comparison, or lifecycle change.

## 31.2 Resume protocol

After a confirmed answer:

1. the surface submits one action bound to the prompt and domain revision it
   displayed;
2. the core rejects the action if it can no longer be safely applied to that
   prompt;
3. a valid action appends its ordinary domain event or events;
4. the core computes the next state-scoped interaction from the resulting
   state;
5. the surface replaces or rebases its checkpoint.

After interruption, the core does not replay a remembered conversational
cursor. It inspects the current domain state and computes the next useful
boundary. Previously confirmed answers remain present because they are domain
events. The surface may restore an unconfirmed local buffer only after
validating its checkpoint against current state.

A stale keypress or answer must never be applied to a different prompt. A
surface conflict preserves recoverable text and asks what to do; it does not
guess.

## 31.3 No continuation or round Brick

Priority insertion, recalibration, impact or effort assistance, Brick review,
and similar question sequences are interactions over existing domain state.
They have no independent:

- Brick identity;
- priority position;
- phase or effort;
- dependency;
- completion event;
- “continue round” successor.

Stopping an interaction merely stops asking questions. Forecast may later
propose another relevant probe or review from current evidence, but it does
not keep an artificial obligation alive to finish a form.

## 31.4 Unconfirmed and confirmed text

Text still being edited is not canonical content. It stays in the surface
checkpoint and does not silently overwrite or append to a Brick description.
Closing or crashing the same capable surface may restore that buffer exactly.

Pressing the applicable confirmation action submits an explicit canonical
operation. Only then does the text become attributed domain content.
Previously confirmed portions therefore survive interruption, while an
unconfirmed portion remains presentation state.

A future cross-surface `save draft` capability, if needed, must be an explicit
operation with defined provenance and conflict behavior. It must not be
implemented by silently inserting a draft marker into a canonical
description. Cross-device draft synchronization is not implied by 1.0 dialog
recovery.

The operator must not rely on model conversation memory as the only copy of an
accepted answer. It submits accepted semantics to the core at each decision
boundary.

## 31.5 Determinism and pseudo-random choices

Deriving the next prompt does not mean erasing all cursors or seeds.

- Purely mechanical candidate selection may be recomputed from the current
  state.
- When a pseudo-random choice affects an observable prompt or later answer
  binding, the core records or carries the seed, cursor, or selected candidate
  required for replay and validation.
- Merely rendering a read-only progress view must not consume randomness.

The exact representation may differ by interaction, but replay must explain
why that prompt was shown.

## 31.6 Honest progress

Progress is derived from current domain facts rather than maintained as a
mutable “questions completed” counter.

An exact numerator and denominator may be shown only when the remaining set is
finite, stable for the stated scope, and actually known. Adaptive interactions
often do not satisfy that condition:

- a comparison answer changes which comparison is informative next;
- a new Brick changes an ordering region;
- a contradiction opens local recalibration;
- an optional answer may make later questions irrelevant.

For such interactions, the envelope should expose useful facts instead of
false precision, for example:

```text
3 comparisons recorded in this session
5 Bricks remain in the uncertain segment
estimated 2–4 useful comparisons remain
```

An estimated range must be labeled as estimated. If no defensible estimate
exists, omit it. A changing estimate after new domain evidence is not a lost
answer or backward progress.

## 31.7 Examples

### Priority round

The user confirms three comparisons and exits. Those comparison events remain
authoritative. On return, the core may ask a different next pair because a new
Brick arrived, while still using all three earlier judgments.

### Brick review

The user confirms a dependency and then leaves while editing done criteria.
The dependency survives as domain state. The unsubmitted criteria remain only
in the capable surface's checkpoint. Resuming recomputes which review question
is still useful.

### Local recalibration

A direct answer contradicts an implied priority relation. The smallest
affected segment remains explicitly provisional. Confirmed comparison evidence
is retained, the next discriminating prompt is derived, and the coherent
replacement order is applied atomically. No recalibration Brick is created.

## 31.8 Still open

- Final interaction-envelope identity, revision token, and stale-answer error
  grammar.
- The minimum persisted domain state needed by each atomic multi-step
  operation versus what can be derived.
- Exact progress fields, estimate methods, wording, and compact rendering.
- Checkpoint naming, retention, cleanup, encryption, and multi-device
  conflict behavior.
- Whether 1.0 needs an explicit cross-surface draft operation.

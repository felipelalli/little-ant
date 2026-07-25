# 22. Session log

Exact message timestamps were not reconstructed. The sequence below preserves
the decision order and the later corrections that matter.

## Entry 1 — Simplify the lifecycle

The session began from the concern that `raw / seed / committed / ready` was
too complex. Raw remained meaningful as unorderable material. The initial idea
was to unify the other pre-completion states into a default Brick that is
ordered from birth.

## Entry 2 — Make ordering the center

The human priority list became the central model. Higher position represents
stronger commitment; lower position resembles backlog. Binary insertion
remained the placement mechanism. The canonical comparison was simplified to
“Does X come before Y?”

## Entry 3 — Put “I do not know” in the core

The user required ordering skip to be deterministic core behavior, not an
operator improvisation. A skipped comparison tries another nearby Brick. A
second skip accepts a provisional location with uncertainty and future
reordering pressure.

## Entry 4 — Separate phase from priority

The former stage concept was split. Phase became `idea`, `spec`, `exec`, or
optional `validation`, while completion became a separate status. A confusing
phrase about ordering by “phase/derived readiness” was rejected: phase may
suggest an initial area and affect selection, but human priority remains its
own order.

## Entry 5 — Reject compatibility aliases

Because the system is still personal and pre-production, the user rejected
core aliases. The operator may interpret natural language, but the core must
have exactly one unambiguous vocabulary.

## Entry 6 — Distinguish priority from next

The user clarified that there are two visible lists:

- the stable human priority hierarchy;
- the dynamic Little Ant choice list.

The second became a derived forecast/probability distribution rather than a
second stored order.

## Entry 7 — Refine hierarchy and uncertainty

Priority became sibling-scoped and hierarchical, with lexicographic global
display. A boolean uncertainty idea evolved into derived confidence. Direct
human and AI comparison histories were retained with authority and recency.

## Entry 8 — Add provocative validation

The user asked how contradictory indirect comparisons should work across
priority, impact, and effort. The system gained discovery, validation, and
recalibration probes. It may directly challenge a transitive implication.
Contradictions lower local confidence and trigger recalibration rather than
being rejected.

## Entry 9 — Prefer current judgment plus history

The user selected a model that preserves history while giving greater weight
to more recent judgment. Human evidence remains authoritative over AI
evidence.

## Entry 10 — Expand Raw into durable material

Raw was refined from a one-shot inbox item into durable, reusable material with
separate review and archive axes, immutable snapshots, optional freshness, and
many-to-many RawShelf groupings.

## Entry 11 — Separate WIP from current attention

An earlier consolidation incorrectly proposed one human WIP. This was
corrected: multiple WIPs are valid, with a soft limit of three, while only
current human focus is exclusive.

## Entry 12 — Replace hours with relative effort

The user challenged hour estimation because humans and AI are poor at it
without a stronger planning model. Generic `weight` was also considered
ambiguous. The design selected relative remaining `effort`, learned through
comparisons and calibrated evidence, with hours only at an external planning
boundary. This was an intermediate model, later replaced by entries 21 and 23.

## Entry 13 — Inspect personal TaskJuggler practice

The personal `planning` repository and TaskJuggler guidance were inspected.
They showed scenario-expanding effort macros, resource efficiency as a
separate concern, and actual-effort corrections. The user corrected an
important misunderstanding about scenarios: an estimated export item selects
one macro, and that macro expands into optimistic, realistic, and pessimistic
values.

## Entry 14 — Retract the leaf-only inference

The first materialized draft incorrectly stated that only active leaves receive
TaskJuggler effort and that parent roll-ups had been rejected. The user
immediately identified that this had never been decided. The statement was
retracted. Export granularity and parent/descendant effort semantics remain
open at this point in the session; entry 22 records their later resolution.

## Entry 15 — Fix the core/operator boundary

The deterministic core may compute ratings and confidence but never calls AI
or owns network judgment. The operator finds analogies, consults external
tools, and injects attributed evidence. Adapters translate that evidence into
planning formats.

## Entry 16 — Require English throughout

The user explicitly required all product commands, answers, shortcuts, data,
documentation, and specifications to be English. This superseded any earlier
idea of a pt-BR product surface.

## Entry 17 — Preserve the work before continuing

The user asked to stop the question battery long enough to materialize the
decisions, then continue discovery, review every existing Little Ant Brick,
and only afterward create the implementation and migration plan. This
document is that materialization. No code or Little Ant data was changed.

## Entry 18 — Split the record for selective loading

At the user's request, the monolithic design record was moved under `spec/`
and split into one descriptive file per chapter. A compact index now provides
topic-oriented reading paths so future sessions can load only the authority,
corrections, open questions, log tail, and subject chapters they need. The
split changed navigation, not product behavior.

## Entry 19 — Promote the REPL into 1.0

The user clarified that the REPL is required in 1.0, superseding an existing
backlog idea that placed it in 1.5. It must behave like a deterministic
Claude/Codex-style harness over the canonical CLI pipeline, advance through
mechanical steps, and stop at human decisions. Finite choices use one keypress
without Enter.

## Entry 20 — Define the REPL interaction and recovery model

`/` became the navigation-mode command palette, replacing an earlier `:`
suggestion. The REPL gained adaptive persistent regions, summarized recent
activity, searchable `/history`, timed notices that never interrupt an active
answer, and an atomic presentation checkpoint capable of restoring the exact
dialog, draft, cursor, and transcript. The checkpoint remains separate from
the domain event log and is validated against its cursor and hash.

## Entry 21 — Make effort total rather than remaining

The user argued that effort should remain the original amount of work rather
than a moving target. This was refined into total effort for the current scope:
progress never lowers it, while a better estimate or confirmed scope revision
may replace the current judgment without erasing history. Remaining effort
became a conservative derived planning projection.

## Entry 22 — Resolve parent effort and planning granularity

A parent's effort was defined as its complete scope including descendants.
Decomposition gained explicit `open | complete` coverage. TaskJuggler export
was resolved through a human-confirmed non-overlapping planning cut: a Little
Ant parent may be a TaskJuggler leaf for a particular plan, and parent and
descendant effort are never counted together.

## Entry 23 — Replace continuous effort with a profile

The intermediate `effort_score: 0..1` and global effort-list ideas were
discarded. Effort now uses eight canonical discrete classes in a versioned
EffortProfile. A user may classify directly or press `?` for up to three
adaptive comparisons against trusted exemplars; `s` cancels without evidence.
The profile's realistic hours may be displayed as context but hours do not
belong to a Brick.

## Entry 24 — Make planning simulations reproducible artifacts

Each effort class maps to one structural macro that expands into all three
TaskJuggler scenarios. Every confirmed simulation produces an immutable
planning manifest outside operational domain state. Actual import uses
embedded Brick IDs, a grouped human-confirmed preview, and preserves the
estimate separately from observed work.

## Entry 25 — Replace impact floats with class and maturity

The intermediate public `impact_score` and `impact_confidence` were discarded.
Impact became expected impact with six discrete classes. Evidence quality
became four public maturity levels: `SPECULATIVE`, `SUPPORTED`, `VALIDATED`,
and `OBSERVED`. Maturity is not probability of success, and the core may use a
separate internal reliability signal only for selection.

## Entry 26 — Treat meaningful impact validation as work

A quick question remains an `impact_probe`, but a questionnaire, experiment,
POC, MVP, or homologation may be a real `validation`-phase Brick. Completion
only produces evidence; it never silently changes impact or maturity. Little
Ant should suggest such work only when its expected value of information is
high and must not invent the method or create the Brick automatically.

## Entry 27 — Consolidate before pausing

The user requested a durable checkpoint for the next day. The subject
chapters, corrections, invariants, open-question queue, Brick inventory, and
review checklist were updated without changing code, README, the executable
Allium specification, or Little Ant data.

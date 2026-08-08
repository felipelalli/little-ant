# Delivery and context process

The implementation must survive fresh sessions and context compaction without
summarizing the whole specification from memory.

## One slice per working context

A normal implementation session reads:

1. [`README.md`](README.md);
2. one file under [`slices/`](slices/README.md);
3. the exact canonical rule blocks and screens named by that slice;
4. only the source and tests touched by that slice;
5. the previous handoff record.

It does not load the whole spec, historical skill, removed Allium garden, v0
source, or later slices unless the current packet explicitly requires one of
them.

## Exact context packets

S00 supplies a read-only `spec-packet` tool. Given rule, screen, scenario, and
flow identifiers, it:

- locates each identifier in the canonical files;
- extracts its exact block without paraphrase;
- records source path and content hash;
- fails on an unknown, duplicate, or noncanonical definition;
- emits a bounded Markdown packet under `tmp/` or stdout;
- never writes into `spec/` or treats implementation prose as authority.

A slice file owns identifier lists and implementation sequencing only. It does
not copy the normative rule text. Hand-authored summaries are orientation, not
acceptance evidence.

## Slice loop

For each slice:

1. generate and inspect the exact packet;
2. render or extract the canonical dumb screens;
3. write the highest-level failing golden/E2E test first;
4. add the smallest pure domain/property tests needed to localize failure;
5. implement one vertical path through dispatcher, events, fold, projection,
   envelope, and REPL;
6. add dry-run, stale, uncertainty, failure, crash/replay, and undo evidence
   required by the owned flows;
7. run the slice suite and every earlier slice suite;
8. generate coverage and rejected-vocabulary reports;
9. review the user-visible diff before internal refactoring;
10. update only operational status and the handoff; never rewrite settled
    semantics to match code;
11. prepare one coherent signed commit, but execute it only with explicit user
    approval under the repository instructions.

When implementation exposes a concrete counterexample, stop only that path,
record the exact conflicting fixture, and reopen the smallest affected
canonical rule/screen. Unrelated work and completed slices remain closed.

## Spec errata and content hashes

A changed canonical block hash is stale by default. It is classified before
any affected evidence is refreshed:

- **Editorial** means no semantic condition, canonical UI byte, action,
  example outcome, or acceptance requirement changed. Hashes may be refreshed
  only after the classification is recorded and reviewed.
- **Normative** means observable behavior or wording changed. Every affected
  test becomes stale and every affected `verified` flow is demoted to
  `implemented` until new failing-then-passing evidence is reviewed.
- **Unclassified** is treated as normative.

Bulk hash acceptance is forbidden. The classification and affected IDs belong
in the implementation handoff or reviewed change, not in a parallel product
specification.

## Handoff record

`implementation/HANDOFF.md` is created when S00 begins and stays short. It has
exactly:

```text
current slice and gate
last verified commit
working-tree facts
tests run and exact results
remaining failing acceptance test
next exact command or file
known deviation or blocker, if any
```

It is not a diary or decision log. Chronology belongs in Git; product decisions
belong in the canonical spec; implementation decisions belong in small ADRs.

## Review sizes

- One slice may contain several internal commits only when each leaves all
  prior behavior green and has an independently reviewable observable result.
- A change that cannot be explained with one dumb transcript is too broad and
  must be split internally without changing the published slice order.
- Mechanical refactoring is separated from behavior changes when it would
  obscure the transcript or event-schema diff.
- A model or subagent receives one bounded task and the same exact packet; it
  never receives authority to fill missing semantics.

## Implementation decision records

ADRs are reserved for physical decisions that affect future code, such as the
terminal backend, event-segment durability, an audited age implementation, or
the HsLua process boundary. An ADR must state:

- the canonical constraints it serves;
- considered physical alternatives;
- the selected implementation and tradeoff;
- how the choice is tested and can be replaced without changing behavior.

An ADR cannot add a command, state, action, event meaning, or UX branch.

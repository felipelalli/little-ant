# Real v0 shadow day

Status: **protocol prepared; no personal data has been read**

## Authorization boundary

- **SCN-REAL-001 — Explicit source choice.** Before reading personal state,
  the user identifies and authorizes one v0 data directory or sanitized
  archive. Little Ant normally resolves `--data`, then `ANT_DATA_DIR`, then the
  XDG location, but this protocol never assumes which one is intended.
- **SCN-REAL-002 — No CLI against the source.** The current CLI auto-ticks and
  may append events even for apparently read-oriented commands. Never run it
  against the authorized original during a shadow study.
- **SCN-REAL-003 — Isolated copy.** Hash the source files, copy only the
  authorized event log/configuration into an isolated temporary directory,
  and run any projection or v0 inspection only against that copy.
- **SCN-REAL-004 — Verify no mutation.** Re-hash the original after the study
  and require byte-identical results.
- **SCN-REAL-005 — No personal commit.** Raw logs, titles, descriptions,
  ExternalEntity details, URLs, source identifiers, and unredacted transcripts
  never enter the repository. Only anonymized findings and synthetic
  reproductions may be committed.

## Projection

1. Parse or replay the isolated v0 copy with warnings retained.
2. Build an ephemeral inventory of active/terminal work, composition,
   comparisons/order, dependencies, waits, Raw, sources, WIP/focus,
   delegations, and recurring evidence.
3. Map only the subset required for one representative day to the canonical v1
   concepts.
4. Mark every ambiguous stage, kind, weight, legacy Party/area, or title
   collision; do not silently repair it.
5. Replace sensitive labels with stable synthetic labels before any durable
   transcript is created.

The projection is not a migration and writes no v1 event.

## Shadow session

Using the same factory profile and a fixed random stream:

1. show the opening status and current-focus recovery, if applicable;
2. request `next` repeatedly across realistic morning, afternoon, and evening
   contexts;
3. exercise actual Domain continuity and context switching;
4. follow one real blocker/dependency path;
5. respond naturally to at least one served-work skip;
6. feed one representative item through duplicate suspicion;
7. inspect a real project/container through `?`;
8. review one date, recurring item, delegation, or Raw decision when present;
9. finish with history and a useful session ending.

The simulation remains one screen per user turn. Current v0 UI, command names,
and failed v1 Allium are evidence only; every proposed screen comes from the
canonical catalog.

## Findings

Classify each difference between the synthetic week and real use as:

```text
missing scenario
unrealistic fixture
wrong default
missing semantic rule
unclear screen
surface-parity defect
migration ambiguity
personal preference
```

Personal preferences become user configuration only when they do not change
canonical action meaning. Repeated cross-user candidates may justify a later
factory-default change, never an invisible learned policy.

## Completion criteria

- original source hashes are unchanged;
- no personal data is staged or committed;
- every observed v0 capability is mapped to a canonical rule, explicit
  replacement, open decision, or deliberate retirement;
- every accepted UX change has a synthetic reproduction;
- configuration recommendations identify the fixed fixture, random stream,
  and compared values;
- the resulting canonical session still renders almost literally across REPL,
  powered-up, Skill, and local web.

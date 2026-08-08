# S07 — Time and standing work

Status: **planned**

## Outcome

Implement the three ordinary date meanings and every standing or anchored
execution lifecycle: notices, repeatable returns, recurring obligations,
habits, and scheduled commitments with preparation.

## Canonical flow rows owned

- Date notice/later
- Repeatable return/jitter
- Recurring obligation
- Habit schedule/outcome
- Scheduled commitment

Generate all owning-row references plus WRK-014..027, WRK-038..046,
WRK-062..064, WRK-139..156, FOC-030..031, FOC-062,
MOD-043, MOD-047, MOD-077..081, MOD-089, UX-NOT00,
UX-REP00..REP01, UX-RO00..RO01, UX-P01, UX-H00..H01,
UX-SC00..SC05, and the standard Template catalog.

## Work

1. Implement `not_before`, `best_before`, and deadline independently; dates
   affect eligibility/pressure but never importance.
2. Implement deterministic tick on every command and explicit `lant tick`.
3. Implement bounded, deduplicated notice rotation and acknowledge/snooze
   state without creating separate warning tickets.
4. Implement repeatable run history and exact/jittered/manual return policies.
5. Implement recurring series release, stable occurrence identity, bounded
   catch-up, and local occurrence draw under one series subject.
6. Implement fixed-slot/quota habits, configurable habit-day boundary,
   truthful outcomes, streak display, missed-count history, blockage, and
   bounded introspection.
7. Implement scheduled commitment intervals, workday/timezone safety, hard
   active precedence, attended/missed/cancelled outcomes, preparation children,
   overlap, and atomic rescheduling consequences.

## Gate

- DST gaps/folds, timezone changes, exact-instant commitments, month-end clamp,
  and 4am/6am factory boundaries have fixtures;
- offline catch-up is bounded and idempotent;
- jitter consumes only its purpose stream and replays identically;
- a skipped obligation returns according to its debt policy while a skipped
  habit closes only the appropriate opportunity/window truthfully;
- active commitments suspend ordinary lottery without silently changing
  existing focus;
- no standing completion accidentally archives its durable owner.

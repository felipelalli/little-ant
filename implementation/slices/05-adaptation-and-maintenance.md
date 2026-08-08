# S05 — Adaptation, maintenance, and recovery

Status: **planned**

## Outcome

Complete the ordinary human work loop after a proposal: current focus and WIP,
typed skip symptoms and reactions, pause/sprints, archive/relevance, semantic
updates, search/history, and general undo/redo recovery.

## Canonical flow rows owned

- Served-work symptom
- Focus/WIP interruption
- Archive and relevance review
- Meaning, title, and attached description
- Direct semantic update
- Escape/undo/redo/recovery
- Global search and return
- Global history and recent recap

Generate all owning-row references plus WRK-001..013, WRK-047..049,
WRK-065, WRK-067..105, WRK-123..128, WRK-139..140,
FOC-025..026, FOC-032..033, FOC-038, FOC-044..050,
DAT-045, DAT-052..054, UX-S01..S47, UX-DT00..DT02,
UX-UP00..UP02, UX-U01..U02, UX-ER01..ER03.

## Work

1. Implement one current focus plus multiple WIPs, transactional `/next`
   browsing, pause, return-to-idle, stale focus, non-current WIP review, and
   Nature-owned direct completion dispatch.
2. Implement the uniform symptom screen, mechanical uncertainty tree, and all
   typed reactions for vague, hard, big, waiting/blocked handoff, tired, bored,
   fear, less important, other, and already done.
3. Implement cooldown, scoped fatigue, family affinity, taxonomy watch,
   pressure, and reaction-specific state without treating skip as an outcome.
4. Implement bounded sprints with sparse start/terminal events and derived
   screen timer.
5. Implement archive, one later relevance review, restore, meaning/title/
   description updates, Raw-backed multiline drafts, and external-editor draft
   transport.
6. Implement the semantic update hub and result receipts without a generic
   field editor or `/plan` command.
7. Implement global search/history suspension and exact return to pending
   interactions.
8. Complete all compensation classes, arrow-to-preview behavior, redo
   preconditions, and educational error envelopes for mutation families now
   present.

## Gate

- each symptom records evidence only when its final reaction commits;
- Nature-specific completion does not change the shared symptom taxonomy;
- rendering sprint countdowns emits no per-second event;
- archive is reversible and never claims completion;
- title changes preserve UUID and handle; description remains ordinary Raw;
- search/history/render/navigation do not mutate or consume forecast draws;
- the state-machine suite explores every undo class and conflict boundary
  introduced through S05.

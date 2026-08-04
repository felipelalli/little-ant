# Little Ant 1.0

Status: **canonical product-specification draft**

Target release: **Little Ant 1.0**

Implementation baseline: **none; 1.0 is a greenfield implementation**

Last consolidated: **2026-07-30**

This is the canonical index for Little Ant 1.0. The compact chapters linked
below define what the product must do. A normative answer must be discoverable
from this index and one subject chapter. Chronological discovery evidence is
recoverable through the commits listed in `traceability.md`; it is never
required to operate or implement the product.

The previous implementation, Allium garden, and generated tests were removed
from the working tree after their divergence was diagnosed. Git history and a
versioned v0 archive remain migration evidence only. The current README and v0
operator skill are not authoritative for 1.0.

## Authority

When sources disagree, use this order:

1. the compact canonical chapters below;
2. [open release decisions](little-ant-1.0/open-release-decisions.md), only to
   identify an intentionally unresolved boundary;
3. the [v0→1.0 capability matrix](little-ant-1.0/v0-v1-capability-matrix.md),
   to require an explicit regression disposition rather than define new
   behavior;
4. [traceability](little-ant-1.0/traceability.md), to locate provenance rather
   than define behavior;
5. Git evidence anchors and the retained v0 skill, as non-authoritative
   historical evidence.

Deleted code, Allium, and generated artifacts must not be consulted as current
product evidence merely because Git can recover them.

`skills/little-ant/SKILL.md` is explicitly a **v0 operator skill** during this
specification phase. It may provide historical evidence, but it must not name,
infer, or fill a 1.0 route. It is replaced only after the dumb and powered-up
contracts reach the Skill-mirror gate.

Normative rules have stable IDs. Later Allium obligations and tests must carry
the same IDs so a rule cannot silently disappear between layers.

## Current closure state

Gate 1 of the [completion plan](little-ant-1.0/spec-completion-plan.md) is
complete:

- Raw, Brick description, and same-Raw English normalization use the corrected
  baseline;
- the maintained capability matrix protects v0 behavior;
- unique safety guarantees and unresolved boundaries have canonical homes;
- the linked shadow specification has been removed while remaining fully
  recoverable from Git.

Gate 2 is in progress. `FOC-037` has closed the five ordinary execution
variants. UX-first review is now paused inside `repeatable_run`: `UX-078` and
`UX-F08` settle its ordinary `Work:` rendering and visible `Last completed`
context; `WRK-062..064` settle the different post-skip behavior of repeatable
runs, fixed-slot and quota-window habits, recurring obligations, and active
scheduled commitments. `FOC-025`, `FOC-032`, `UX-080`, and `UX-F09` settle
stale current focus as a check-in continuation outside the lottery.
`FOC-038`, `WRK-065`, `UX-081`, and `UX-F10` settle non-current WIP review as
a distinct ordinary-lottery opportunity. `MOD-015`, `FOC-011`, and `UX-082`
restore the universal-Brick execution rule: an undecomposed project uses
ordinary Work, a decomposed parent yields execution to its children, and the
parent returns only for scope review after every child is done. `UX-025`,
`UX-045`, and `UX-071` settle the global six-line, dot-led, emoji-free footer,
its active-Brick/Raw-review/review counts, and its theme-neutral intensity
hierarchy. `FOC-039`, `WRK-066`, `UX-083`, and `UX-F11` settle scope closure
as a typed review with explicit completion, more-work, and deferral outcomes.
Resume with the remaining non-execution opportunity catalog.

## Scope rings

Every capability belongs to one ring:

- **core** — the daily experience: feed, organize, order by importance, draw
  a focus opportunity, act, and learn from use;
- **standard** — supported 1.0 capabilities that do not dominate the happy
  path, including recurrence, delegation, imports, Packs, and planning;
- **calibration** — replay-safe parameters or hypotheses whose exact values
  should be refined through use rather than invented as universal constants.

`calibration` is not a euphemism for unspecified behavior. The semantic rule
and factory default must be explicit before implementation; only the tunable
value may remain adjustable.

## Canonical chapters

1. [Product, language, and scope](little-ant-1.0/01-product-language-and-scope.md)
2. [Concepts, identity, and hierarchy](little-ant-1.0/02-concepts-identity-and-hierarchy.md)
3. [Feeding and organization](little-ant-1.0/03-feeding-and-organization.md)
4. [Importance and judgment](little-ant-1.0/04-importance-and-judgment.md)
5. [Focus forecast and selection](little-ant-1.0/05-focus-forecast-and-selection.md)
6. [Work, time, and adaptation](little-ant-1.0/06-work-time-and-adaptation.md)
7. [Interaction and surface contract](little-ant-1.0/07-interaction-and-surface-contract.md)
8. [Data, integrations, and extension boundary](little-ant-1.0/08-data-integrations-and-extension-boundary.md)
9. [Migration and release contract](little-ant-1.0/09-migration-and-release-contract.md)

## Supporting records

- [Configuration and calibration](little-ant-1.0/configuration-and-calibration.md)
- [Standard Template catalog](little-ant-1.0/standard-template-catalog.md)
- [Open release decisions](little-ant-1.0/open-release-decisions.md)
- [V0→1.0 capability matrix](little-ant-1.0/v0-v1-capability-matrix.md)
- [Specification completion plan](little-ant-1.0/spec-completion-plan.md)
- [Decision and evidence traceability](little-ant-1.0/traceability.md)
- [UX simulation protocol](little-ant-1.0/ux/00-simulation-protocol.md)
- [Canonical screen catalog](little-ant-1.0/ux/screen-catalog.md)
- [UX flow coverage](little-ant-1.0/ux/flow-coverage.md)
- [Synthetic week](little-ant-1.0/ux/01-synthetic-week.md)
- [Real shadow day](little-ant-1.0/ux/02-real-shadow-day.md)

## Reading paths

- Daily product behavior: chapters 1, 3, 4, 5, 6, and 7.
- Domain model: chapters 1 and 2.
- REPL, web/mobile, and skill parity: chapter 7 and the UX records.
- Imports, Packs, exporters, and TaskJuggler: chapter 8.
- Implementation or migration planning: chapters 2, 8, and 9.
- Finishing product discovery: follow the specification completion plan in
  gate order.
- Why a rule exists: follow its ID through `traceability.md`.

## Maintenance rules

- Define each normative rule in exactly one canonical chapter.
- Cross-reference rule IDs instead of copying normative paragraphs.
- Keep product data, commands, responses, specifications, and default UI in
  English.
- Record a genuinely unresolved semantic boundary in
  `open-release-decisions.md`; do not hide it in prose or invent an answer.
- Keep chronology in small signed commits, not a second specification,
  corrections chapter, or append-only session log.
- Do not promote this record into Allium or tests until the UX simulations
  have validated the observable contract.

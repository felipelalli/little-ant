# Little Ant 1.0

Status: **canonical 1.0 implementation contract; product discovery complete**

Target release: **Little Ant 1.0**

Implementation baseline: **none; 1.0 is a greenfield implementation**

Last consolidated: **2026-08-08**

This is the canonical index for Little Ant 1.0. The compact chapters linked
below define what the product must do. A normative answer must be discoverable
from this index and one subject chapter. Chronological discovery evidence is
recoverable through the commits listed in `traceability.md`; it is never
required to operate or implement the product.

The previous implementation, Allium garden, and generated tests were removed
from the working tree after their divergence was diagnosed. Git history and a
versioned v0 archive remain migration evidence only. The README summarizes
this contract, while the v0 operator skill remains historical evidence; neither
overrides a canonical rule.

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

All 12 gates of the
[completion plan](little-ant-1.0/spec-completion-plan.md) are complete. The
contract has no open release-blocking semantic boundary or unresolved v0
regression. Every route in the
[UX flow inventory](little-ant-1.0/ux/flow-coverage.md) is `specified`; none is
claimed `verified` before a conforming implementation passes its cited replay.

**Next phase:** a separately authorized implementation plan that promotes the
stable rule and scenario IDs into inspected obligations, high-level tests, and
then product code. Allium and generated tests remain absent and
non-authoritative until that phase. A later concrete counterexample reopens
only the smallest affected rule and flow, never product discovery as a whole.

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
- [Deterministic calculation profile](little-ant-1.0/deterministic-calculation-profile.md)
- [Standard Template catalog](little-ant-1.0/standard-template-catalog.md)
- [Standard integration catalog](little-ant-1.0/standard-integration-catalog.md)
- [Pack format and trust](little-ant-1.0/pack-format-and-trust.md)
- [Canonical command catalog](little-ant-1.0/command-catalog.md)
- [Factory personality catalog](little-ant-1.0/personality-catalog.md)
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
- REPL, powered-up, Skill, and local-web parity: chapter 7, the
  [command catalog](little-ant-1.0/command-catalog.md), and the UX records;
  future mobile must conform there but is not a 1.0 deliverable.
- Imports, Packs, exporters, and TaskJuggler: chapter 8.
- Implementation or migration planning: chapters 2, 8, and 9.
- Implementation planning: begin with the frozen completion record, flow
  inventory, command catalog, and migration contract.
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
- Keep `Current closure state` at 25 lines or fewer. During discovery it owns
  one `Next review:` marker; after specification freeze it owns one `Next
  phase:` marker instead. `Resume` is ordinary prose, not a checkpoint.
- Promote this record into Allium or tests only in a separately authorized
  implementation phase. Generated artifacts must preserve originating IDs and
  be inspected against the dumb UX contract before product code relies on
  them.

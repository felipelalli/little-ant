# Little Ant 1.0

Status: **canonical product-specification draft**

Target release: **Little Ant 1.0**

Implementation baseline: **none; 1.0 is a greenfield implementation**

Last consolidated: **2026-07-29**

This is the canonical index for Little Ant 1.0. The compact chapters linked
below define what the product must do. A normative answer must be discoverable
from this index and one subject chapter; the historical discovery record is
never required to operate or implement the product.

The previous implementation, Allium garden, and generated tests were removed
from the working tree after their divergence was diagnosed. Git history and a
versioned v0 archive remain migration evidence only. The current README and v0
operator skill are not authoritative for 1.0.

## Authority

When sources disagree, use this order:

1. the compact canonical chapters below;
2. [open release decisions](little-ant-1.0/open-release-decisions.md), only to
   identify an intentionally unresolved boundary;
3. [traceability](little-ant-1.0/traceability.md), to locate provenance rather
   than define behavior;
4. the [historical record](little-ant-1.0/history/README.md), as evidence only;
5. the retained README and v0 skill, as non-authoritative historical evidence.

Deleted code, Allium, and generated artifacts must not be consulted as current
product evidence merely because Git can recover them.

Normative rules have stable IDs. Later Allium obligations and tests must carry
the same IDs so a rule cannot silently disappear between layers.

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
- [Open release decisions](little-ant-1.0/open-release-decisions.md)
- [Historical traceability](little-ant-1.0/traceability.md)
- [UX simulation protocol](little-ant-1.0/ux/00-simulation-protocol.md)
- [Canonical screen catalog](little-ant-1.0/ux/screen-catalog.md)
- [Synthetic week](little-ant-1.0/ux/01-synthetic-week.md)
- [Real shadow day](little-ant-1.0/ux/02-real-shadow-day.md)

## Reading paths

- Daily product behavior: chapters 1, 3, 4, 5, 6, and 7.
- Domain model: chapters 1 and 2.
- REPL, web/mobile, and skill parity: chapter 7 and the UX records.
- Imports, Packs, exporters, and TaskJuggler: chapter 8.
- Implementation or migration planning: chapters 2, 8, and 9.
- Why a rule exists: follow its ID through `traceability.md`.

## Maintenance rules

- Define each normative rule in exactly one canonical chapter.
- Cross-reference rule IDs instead of copying normative paragraphs.
- Keep product data, commands, responses, specifications, and default UI in
  English.
- Record a genuinely unresolved semantic boundary in
  `open-release-decisions.md`; do not hide it in prose or invent an answer.
- Keep historical files unchanged. Corrections belong in the compact
  specification and traceability dispositions.
- Do not promote this record into Allium or tests until the UX simulations
  have validated the observable contract.

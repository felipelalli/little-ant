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
`WRK-067`, `UX-084`, and UX-S06 settle `big` as a provisional choice among
decomposition, one enabling context-gathering or learning Brick, and ordinary
deferral. Explicit `/break` remains independently reachable, while Nature,
title, and unaccepted assistance never trigger decomposition. `UX-085..087`
and UX-B00 settle the editor between `break` and UX-B01, its
title-specific English hint, the attributed full-draft gateway, and one-part
inline assistance without moving validation or mutation outside the CLI.
`MOD-052` and `IMP-030` settle the accepted baseline: child Natures default
visibly to lazily reviewable `atomic_task`, input sequence seeds a complete
low-confidence sibling run, assisted claims retain AI provenance, and no
human comparison delays the atomic creation. `UX-088` settles the complete
human-facing UX-B01 confirmation and its accepted, rejected, edited, uncertain,
and reverse-navigation transitions, including draft-handle suppression and
assisted-exception labeling. `FOC-040`, `UX-089`, and UX-B02 settle the exact
post-commit result and its next envelope: all four lazy claim reviews
immediately join the weighted lottery with low positive
weight, remain counted while unresolved, and no draw occurs before explicit
`next`. `MOD-053`, `UX-090`, and UX-N01 settle the dumb `nature_review` screen,
including human
confirmation, reclassification entry, typed skip, source attribution, and
isolated claim resolution. Resume with the dumb `importance_run_review`
screen for the provisional sibling sequence. `IMP-031`, `FOC-041`, `UX-091`,
and UX-O01 settle its comparison grammar and cadence: lottery selection asks
one pair then boosts later importance-maintenance draws, while explicit
`/order` advances directly through the same resumable `org-sort-tasks` state.
`IMP-032`, `UX-092`, and UX-O02 settle sibling-safe scope selection and its
Brick/Domain autocomplete; `all groups` is the first factory default and both
`*` and Enter invoke any visible finite-choice default under UX-015. `UX-093`
and UX-O03 settle boundary-only continuous-flow results, exit, resume,
completion, and their distinction from undo. `DAT-044`, `UX-094`, and
UX-R02 record the honest JSONL cold-load splash; its final ASCII-art polish
remains a Gate 2 visual review. `UX-095` and UX-O04 settle results per cycle,
not per answer: a lottery review has one pair and one minimal receipt, while
multi-step insertion, classification, and `/order` remain uninterrupted until
a real boundary. `UX-096` and UX-O05 settle the ordinary two-skip path: nearby
redraw first, then provisional placement; direct `/order` continues while a
lottery review returns a compact result. `IMP-033..034`, `UX-097..099`, and
UX-O06..O08 settle temporal confidence and explicit fresh-cycle resolution.
`IMP-015` and `FOC-042` keep replay-deterministic provocative validation outside
`org-sort-tasks` and explicit `/order`. `IMP-035`, `FOC-043`, `UX-100`, and
UX-O09 settle a second uncertainty response without forced judgment: retain
the prior coherent order, lower local confidence, and revisit the segment
later. `IMP-036` and `UX-101` resolve longer fresh cycles through repeated
bounded UX-O07 triads using the importance-only counterfactual `If only one of
these could ever be done...`; urgency never enters the question. Resume with
`IMP-037`, `UX-102`, and UX-O10 settle provocative-validation skip without
provisional placement or confidence mutation. Importance ordering,
contradiction, and validation now have complete reviewed semantics.
`IMP-040..044`, `UX-134..138`, and UX-O11..O15 settle the ordinary
comparison's honest-answer tree, including node-local question-mark behavior,
pair-local `either_order`, relationship-only investigation work, a bounded
nearby aid, and explicit provisional placement. Only the remaining ordinary
ordering edges in `OPEN-IMP-001` remain. `WRK-068`, `UX-103`, and UX-S07 begin
the next Gate 4 flow by settling the visible `tired` recovery
choices. `IMP-038`, `FOC-044`, `WRK-069`, `UX-104`, and UX-S08 settle `easier
work` as a deterministic three-candidate shortlist: same-Domain and known-low
effort are preferences, unknown effort retains a positive chance, selection
records contextual plus weak relative evidence, and the chosen Brick still
passes through ordinary focus consent. `FOC-045`, `WRK-070`, `UX-105`, and
UX-S09 settle `change subject` as a positive full-path target choice with
nonrepeating pages, one target-scoped draw, inferred source-branch fatigue,
decaying target affinity, and a screen-local `[/] menu...` label that avoids
collision with `[m]ore options...`. `WRK-071`, `UX-106`, and UX-S10 settle
`pause for now` as evidence-bearing rest with a truthful state variant,
optional `safe_end` warmth, no automatic draw or process exit, and no
persistent paused state. `FED-032..033`, `FOC-046`, `WRK-072..080`,
`UX-107..114`, `DAT-045`, and UX-S11..S17 settle the main `bored` routes:
positive subject change, one organization-family draw, visible decomposition,
deterministic or attributed better-method enablers, and an honest focus
timebox. The sprint uses visible 5/15/25-minute choices with a 25-minute
Pomodoro default, a target-derived live countdown where supported, sparse
start/terminal evidence, and an expiry choice that never claims progress or
completion. The main `tired` and `bored` flows are complete except their
declared empty and multi-Domain edges and the bounded custom-duration picker.
`FED-034..036`, `WRK-081..083`, `UX-115..118`, and UX-S18..S23 then settle
`fear` without adding a risk axis: dumb mode asks for validation or a safer
first move, or selects a typed ExternalEntity for advice, collaboration, or
delegation; all accepted paths reuse explicit prerequisite and handoff
mechanisms. `FED-037..039`, `WRK-084..086`, `UX-119..121`, and UX-S24..S27
then settle `vague` by separating a direct Description Raw clarification from
real context-gathering, decomposition, learning, or support work; the Raw
revision encoding remains explicitly in `OPEN-RAW-001`. `FED-040..041`,
`WRK-087..088`, `UX-122..123`, and UX-S28..S29 settle `hard` with explicit
learning/practice, decomposition, easier-method, and support recoveries. A
shared decomposition preserves `hard` plus its chosen reaction instead of
silently rewriting the symptom as `big`, and it never classifies Effort.
`IMP-039`, `FOC-047`, `WRK-089..092`, `UX-124..126`, and UX-S30 then settle
`less important` by separating a comparison-backed human-order change, an
explicit `not_before` date, a one-draw Domain change, and defer-only skip. No
route treats momentary timing or subject preference as importance evidence.
`WRK-093..094`, `UX-127..129`, and UX-S31..S32 then settle `other` as a
confirmed verbatim skip reason whose repeated evidence may create a separate
taxonomy-review opportunity but never mutates vocabulary automatically.
`WRK-095..097`, `UX-130..133`, and UX-S33..S34 settle the first complete
application of the global honest-answer protocol: symptom uncertainty follows
a deterministic binary tree to one confirmed existing symptom or `other`, and
records nothing before a final reaction.
`FOC-048..050`, `UX-139..143`, and UX-F12..F14 settle the primary Focus
honest-answer tree: understand the Brick through `/show`, inspect the immutable
weighted-draw explanation, explicitly consent to Focus, or enter existing
symptom discovery while preserving any prior current focus. The nested
question-mark tree inside the forecast explanation remains named in
`OPEN-UX-004` rather than being invented here. `MOD-054`, `FED-001..009`,
`FED-042..048`, `FOC-051..052`, `UX-144..150`, and UX-T01..T06 then simplify
ordinary Feed to one immediate Raw commit: the derived Inbox holds unresolved
material, and later weighted triage may keep it standalone, shelve or attach
it, create or reuse an owner-scoped ListEntry, or materialize positioned Work.
The dumb route ranks inspectable existing destinations; `[m]ore matches...`
paginates, `[s]earch...` autocompletes across the compatible set, and
`[c]reate a new group...` begins explicit list, RawShelf, or Work-container
discovery without claiming unseen candidates do not fit. `Group` remains
interface language rather than a core object. Assisted modes may propose an
attributed bounded recent-Raw batch but never delay Feed or accept routing.
That review subsequently reached the stale-Work and semantic-maintenance
flows. `MOD-060..061`, `WRK-098..113`, `UX-152..170`, and UX-S35..S51 now distinguish
reversible archive, restoration, stale correction, and ordinary direct
`/update #brick`. All three update origins share one neutral semantic hub, but
only the stale and archived origins carry their respective atomic evidence or
restoration consequence. `plan` is a human dispatch route to composition,
gates, and responsibility rather than an entity, phase, or axis; `/edit` and
`/plan` are not aliases. The Plan hub now has exactly structure, blockers, and
responsibility; its blocker route reuses the existing human classifier while
omitting skip-only grammar and evidence. Structure always exposes placement,
child parts, and list items; an incompatible choice proposes explicit Nature
reconciliation instead of disappearing or converting silently. Composition
never grants Domain membership; dumb reparenting compares only explicit path
sets, preserves them by default, and exposes divergence without semantic
guessing. Resume the UX-first review at the parent selector and new-sibling
importance placement, then exercise parts, list items, and responsibility
before proceeding to timing, context, and source material.

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

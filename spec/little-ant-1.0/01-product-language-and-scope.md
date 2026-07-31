# 1. Product, language, and scope

## Product promise

- **PRD-001 [core] — One useful next move.** Little Ant helps one person turn
  material and intentions into a trustworthy answer to “where should I focus
  now?” without pretending that a static list can answer that question alone.
- **PRD-002 [core] — UX precedes mechanism.** User flow and cognitive clarity
  take precedence; shared UI composition is second; storage,
  algorithms, and implementation follow the observable contract.
- **PRD-003 [core] — Two different judgments.** Human importance is a stable
  hierarchical order. The focus forecast is a dynamic probability
  distribution. Neither is called `priority`.
- **PRD-004 [core] — Useful session ending.** Every guided session ends with a
  useful proposal, explanation, or concrete recovery path, including when no
  work is currently eligible.
- **PRD-005 [core] — Honest history.** The system records what was confirmed
  or observed. It never fabricates preparation, start, progress, completion,
  or external action merely to make a workflow look complete.

## Core and judgment boundary

- **PRD-006 [core] — Deterministic core.** The core owns canonical state,
  invariants, event history, clocks, pseudo-random evidence, comparison
  mechanics, scheduling, and validated actions. Its canonical command
  dispatcher is exposed through the structured CLI/protocol and is the only
  state-changing gateway used by first-party surfaces. Whether a host invokes
  that dispatcher as a process, library, or service is an implementation
  choice and cannot change its observable semantics.
- **PRD-007 [core] — Attributed judgment.** A human, operator skill,
  powered-up model, or adapter may interpret language and propose subjective
  judgments. The source and confidence remain explicit, and only canonical
  core actions may change state.
- **PRD-008 [core] — No hidden authority.** Templates, Packs, adapters, and
  models cannot invent commands, actions, event kinds, ranking algorithms, or
  lifecycle semantics.
- **PRD-009 [standard] — External-effect approval.** Nothing is sent, erased,
  written back, or otherwise applied outside Little Ant without a complete
  preview and the required explicit approval.

## Canonical language

- **PRD-010 [core] — English canonical product.** Commands, action labels,
  identifiers, canonical titles, Raw English normalizations, responses,
  documentation, and default UI are English.
- **PRD-011 [standard] — Presentation preference.** A skill or UI adapter may
  translate presentation only when the user explicitly requests it or a
  user-owned preference selects it. Canonical data and action identity remain
  English. The preference, integration-binding, calibration, and secret
  boundaries are closed under `OPEN-PREF-001`.
- **PRD-012 [standard] — Original input.** When Raw content is normalized or
  translated, the original representation and its language remain on that
  same Raw as attributable evidence instead of being discarded.
- **PRD-013 [core] — No compatibility aliases.** The 1.0 core exposes one
  unambiguous term and command per concept. Natural-language mapping belongs
  to the operator or powered-up layer.

| Rejected or legacy term | Canonical 1.0 term |
|---|---|
| `capture` | `feed` |
| human `priority` | `importance order` |
| dynamic `priority` | `focus forecast` or `next` |
| `BrickBehavior`, generic task type | `BrickNature` |
| `Party`, organizational `area` | `ExternalEntity`, `Domain` |
| `unify` | `merge` |
| `seed`, `committed`, `ready` | one active Brick plus independent phase, work state, and importance position |
| Brick `weight` | `effort` for workload; probability or chance for forecast selection |

`interaction` remains ordinary descriptive language and the name of a typed
envelope; it is not a catch-all public command or extension point.

## Scope policy

- **PRD-014 [core] — Minimal happy path.** Feeding requires only enough
  information to choose a canonical route and, for a Brick, one Nature.
  Optional axes are gathered lazily.
- **PRD-015 [standard] — Standard without intrusion.** Recurrence,
  delegation, imports, planning, and extensions ship as supported 1.0
  capabilities but appear only when the current Nature or situation makes
  them relevant.
- **PRD-016 [calibration] — Tunable mechanics.** Cooldowns, aging, curve
  strengths, thresholds, jitter ranges, and similar values live in a
  versioned configuration profile with factory defaults.
- **PRD-017 [core] — No false simplification.** Moving a capability out of the
  happy path does not erase its invariant, history, or migration requirement.

## Version boundary

- **PRD-018 [core] — Clean v1 vocabulary.** Migration may recognize v0 data,
  but v1 state, commands, responses, code identifiers, current documentation,
  Allium, and tests must not preserve rejected aliases.
- **PRD-019 [core] — Specification promotion gate.** This compact product
  specification and its approved UX scenarios must be reviewed before Allium,
  generated tests, the operator skill, README claims, or implementation are
  treated as 1.0.

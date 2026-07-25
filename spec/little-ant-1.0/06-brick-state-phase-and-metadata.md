# 6. Brick state

## 6.1 Independent axes

The current lifecycle is replaced by independent status, phase, work state,
and focus:

```text
status     = active | done | dropped | superseded
phase      = idea | spec | exec | validation
work_state = idle | wip
focus      = zero or one current Brick globally
```

The exact field name for global focus is still open; `current_brick` is a
working term.

Terminal status applies to `done`, `dropped`, and `superseded`. Only active
Bricks participate in open-work selection.

## 6.2 Removed lifecycle stages

The following current stages are abolished:

```text
seed | committed | ready
```

Their intended meaning is derived instead:

- lower priority positions resemble an idea backlog;
- higher positions express stronger commitment;
- readiness for a particular action is inferred from phase, structure,
  dependencies, waits, context, and confidence;
- no separate commitment-stage mutation is required.

This does **not** mean phase sorts the priority tree. Phase can inform initial
placement and dynamic selection, but it never overrides the human's explicit
priority order.

## 6.3 Phase

Every active Brick has exactly one phase:

| Marker | Phase | Meaning |
|---|---|---|
| lightbulb emoji, exact glyph open | `idea` | Immature or exploratory work. |
| design/planning emoji, exact glyph open | `spec` | Planning or specification; still nebulous or under-defined. |
| current execution marker, exact glyph open | `exec` | Execution is the relevant action. |
| laboratory emoji, exact glyph open | `validation` | Testing, homologation, proof of concept, or validation. Optional in a Brick's history. |

Phase is descriptive, not a rigid workflow:

- An active Brick may move explicitly from any phase to any other phase.
- Validation is optional.
- There is no required `idea -> spec -> exec -> validation` path.
- A normal capture defaults to `spec` when no better judgment exists.
- The operator may infer another phase, but an inferred phase remains
  uncertain until human-confirmed.
- Repeated `vague` skips should propose a phase review; they must not silently
  change the phase.

Phase confidence should be represented continuously, or derived from evidence,
rather than as a user-entered boolean. Its precise model remains open.

## 6.4 Phase-informed initial placement

A newly created Brick is positioned immediately. When no direct priority
evidence exists, phase supplies only a provisional insertion prior:

| Phase | Provisional center |
|---|---|
| `validation` | center of the top quarter, approximately 12.5% |
| `exec` | center of the second quarter, approximately 37.5% |
| `spec` | approximately the midpoint, 50% |
| `idea` | center of the lower half, approximately 75% |

Binary insertion and later judgments determine the actual position. These
percentages are starting priors, not permanent phase bands and not a sort key.

## 6.5 Removed and retained metadata

Confirmed removals:

- `kind` is removed. Phase carries the useful work-shape distinction.
- `role` is not introduced. Maintenance work is represented by proposals, not
  special meta-Bricks.
- `weight` is removed because the word and field are ambiguous.
- `estimate_hours` and `estimate_author` are removed from canonical Brick
  state.

Canonical workload and value metadata use the new explicit axes:

- an optional, lazily collected effort class plus its EffortProfile version;
- a direct impact class and evidence maturity on root Bricks only;
- decomposition coverage for Bricks with children;
- confirmed scope-revision history.

No decision has yet removed `atomicity`, `context`, `mode`, `about`,
`requester`, waits, dependencies, delegation, descriptions, sources, or
effects. Some require redesign and are listed under open questions.

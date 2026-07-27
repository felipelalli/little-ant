# 6. Brick state

## 6.1 Independent axes

The current lifecycle is replaced by independent status, phase, work state,
and focus:

```text
status     = active | done | dropped | superseded
phase?     = idea | spec | exec | validation
work_state = idle | wip
focus      = zero or one current Brick globally
```

The exact field name for global focus is still open; `current_brick` is a
working term.

Terminal status applies to `done`, `dropped`, and `superseded`. Only active
Bricks participate in open-work selection.

`done` is a direct transition from any active Brick. It does not require a
particular phase, `work_state`, effort assessment, description, or other
optional preparation, and it does not fabricate `start`, promotion,
preparation, or phase-transition history. The event history honestly records
that completion was reported directly.

Direct does not mean unconditional. Structural and behavior invariants still
apply:

- active descendants require the explicit subtree-closure path;
- finishing one standing execution is distinct from retiring the standing
  Brick;
- a repeatable Brick may offer terminal completion or another execution;
- pending external effects remain subject to their approval boundaries.

Successful terminal completion clears current focus or WIP as applicable and
fires only the ordinary confirmed completion mechanics. Exact completion
evidence fields and event grammar remain open.

`already done` is not a separate product command, status, event, or completion
kind. It is ordinary `done` invoked without prior start evidence:

- the user may invoke `done` directly by Brick reference;
- when a Brick is served, `done` is a context-valid action alongside start and
  skip, never a skip reason;
- no zero-duration start is synthesized;
- observed duration remains unknown rather than becoming a false zero;
- the applicable BrickBehavior still records the normal successful execution,
  recurrence, practice, streak, or completion effects;
- completion provenance distinguishes a direct human report from a proposal
  based on external evidence.

External evidence may propose the same canonical `done` operation, but it does
not silently become human completion evidence or bypass the normal authority
and confirmation rules.

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

## 6.3 Optional phase

Phase is optional and lazy. A BrickBehavior may declare phase applicable,
irrelevant, or disabled. Missing phase is neutral: it does not block capture,
create a form, or generate pressure merely because it is absent.

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
- A normal capture does not require or silently default phase.
- The operator may infer another phase, but an inferred phase remains
  uncertain until human-confirmed.
- Repeated `vague` skips should propose a phase review; they must not silently
  change the phase.
- A phase review is useful only when phase could change the next useful action.

Phase confidence should be represented continuously, or derived from evidence,
rather than as a user-entered boolean. Its precise model remains open.

## 6.4 Phase-informed initial placement

A newly created Brick is positioned immediately. When applicable phase is
already known and no direct priority evidence exists, it may supply only a
provisional insertion prior:

| Phase | Provisional center |
|---|---|
| `validation` | center of the top quarter, approximately 12.5% |
| `exec` | center of the second quarter, approximately 37.5% |
| `spec` | approximately the midpoint, 50% |
| `idea` | center of the lower half, approximately 75% |

Binary insertion and later judgments determine the actual position. These
percentages are starting priors, not permanent phase bands and not a sort key.
When phase is absent or disabled, the core uses a neutral behavior/default
prior and does not ask for phase as a capture toll.

## 6.5 Removed and retained metadata

Confirmed removals:

- `kind` is removed. Generic interaction differences belong to an explicit
  BrickBehavior; domain language belongs to templates or operator
  interpretation.
- `role` is not introduced. Maintenance work is represented by proposals, not
  special meta-Bricks.
- `weight` is removed because the word and field are ambiguous.
- `estimate_hours` and `estimate_author` are removed from canonical Brick
  state.

Canonical workload and value metadata use the new explicit axes:

- an optional, behavior-applicable, lazily collected effort class plus its
  EffortProfile version;
- a direct impact class and evidence maturity on root Bricks only;
- decomposition coverage for Bricks with children;
- confirmed scope-revision history.

No decision has yet removed `atomicity`, `context`, `mode`, `about`,
`requester`, waits, dependencies, delegation, descriptions, sources, or
effects. Some require redesign and are listed under open questions.

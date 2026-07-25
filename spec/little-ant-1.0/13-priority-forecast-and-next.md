# 13. The two lists

The user experiences two lists, but only one is a persistent human order.

## 13.1 Priority

`la priority` is the working name for the stable hierarchical commitment tree.
It exposes:

- composition;
- sibling order and global lexicographic order;
- position confidence and reasons;
- blocking without rewriting position.

The final command and projection name remains to be confirmed.

## 13.2 Forecast and next

The selection list is a derived probability distribution, not another stored
order.

`la forecast` is the working name for a read-only projection that exposes:

- eligible candidates and maintenance proposals;
- current weight or probability;
- relevant dates;
- reasons contributing pressure;
- confidence;
- blockers and contextual effects where useful.

Forecast must not consume randomness or mutate the result of a future draw.

`la next`:

- performs one reproducible pseudo-random draw;
- records the draw seed or cursor and selected outcome;
- proposes one next action;
- does not rewrite the priority tree.

Every eligible candidate has a positive chance. Aging increases the chance of
neglected candidates. There is no confirmed bounded guarantee that every item
must appear within N draws.

## 13.3 Inputs to selection

Selection may take into account:

- priority path and confidence;
- phase and phase confidence;
- expected-impact class, evidence maturity, and internal reliability;
- total effort class, derived remaining effort, and applicable confidence;
- dates and overdue state;
- context and mode;
- dependencies and waits;
- current focus and WIP review pressure;
- skip cooldown and accumulated skip pressure;
- stale or contradictory judgments;
- Raw review and refresh;
- delegation, approval, and follow-up state;
- aging;
- other derived proposals.

There is no fixed global phase multiplier. Phase changes what action is useful
and may affect contextual selection, but it does not act as a universal
priority substitute.

## 13.4 Deterministic precedence

Some conditions are resolved before the ordinary lottery:

1. current focus, when it remains valid;
2. stale-focus resolution;
3. external effects or messages already proposed and awaiting approval;
4. overdue follow-ups.

The exact ordering and completeness of this precedence list still needs a
formal review against current delegation and effect semantics.

## 13.5 Proposal vocabulary

The current proposal set includes:

```text
priority_probe
impact_probe
effort_probe
review_parent
review_wip
phase_review
review_raw
refresh_raw
stale_focus
stale_comparison
scope_review
source_reconciliation
delegation_followup
effect_approval
```

These are maintenance or decision opportunities, not meta-Bricks. Their
relative weights, persistence, interruption, and resumability remain partly
open.

The forecast may also surface a proposal to plan real impact-validation work
when the expected value of information is high. Its exact canonical proposal
name remains open. The proposal is not itself a Brick and must not
automatically create a questionnaire, experiment, POC, or MVP.

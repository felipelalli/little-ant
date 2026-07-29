# 27. Standing work, recurrence, obligations, and practices

## 27.1 Minimum 1.0 scope

Recurrence and desired practices are part of the Little Ant 1.0 design. The
minimum model must distinguish:

| Pattern | What persists | What happens when one opportunity is not completed |
|---|---|---|
| standing collection | one Brick plus changing entries | unresolved entries remain available |
| completion-triggered repeat | one Brick plus execution history and at most one scheduled next execution | after `not_before`, the same Brick remains eligible; no missed occurrence is fabricated |
| recurring obligation | a recurrence rule plus independently completable Brick occurrences | the occurrence remains open and may become overdue |
| practice | one standing Brick plus expiring opportunities and execution history | the opportunity records an unfulfilled outcome and does not become backlog |

The core owns deterministic schedules, restricted event triggers, windows,
occurrence identity, outcomes, history, eligibility, and derived pressure.
Natural-language recurrence interpretation remains operator work.

## 27.2 Standing work and execution occurrences

A standing Brick remains active across many executions and retains one human
importance position. Its Nature may make it derivatively dormant when there
is nothing currently useful to do. Dormancy is eligibility, not another
persisted lifecycle status.

`Buy groceries` is the reference example:

- the Brick uses a standing-checklist Nature;
- open ListEntries are always rendered together;
- adding an entry makes an empty list eligible again;
- starting the Brick begins an execution occurrence, or run;
- finishing the shopping run ends current execution without terminally
  completing the standing Brick;
- bought entries leave the ordinary open view but remain in history;
- unbought entries remain open;
- an item bought outside the prior list may be recorded directly as resolved
  without implying that the list was exhaustive;
- resolving the last planned entry may propose finishing the run but never
  completes it automatically.

The exact persistence form and public name for an execution occurrence remain
open. Terminally completing, dropping, or superseding a standing Brick means
retiring that standing responsibility, not finishing one run.

## 27.3 Recurring obligations

A recurring obligation materializes independently resolvable Brick
occurrences. Each occurrence may have its own:

- recurrence period and identity;
- release time;
- `not_before`, `best_before`, or `deadline`;
- source and Raw attachments;
- wait, dependency, completion evidence, and status.

`Pay bills` may be a standing grouping Brick whose open children are bill
occurrences:

```text
Pay bills
  Electricity bill · July 2026
  Rent · August 2026
  Credit card bill · July 2026
```

Predictable obligations may be released from a recurrence rule. Variable
invoices may begin as predicted occurrences and later receive the actual
amount, document, or deadline from explicit input or an adapter.

An unpaid obligation remains open and may become overdue. A later recurrence
does not erase it; several periods may coexist. Series and period identity
must participate in duplicate suspicion so a manual feed can enrich an
existing occurrence instead of duplicating it.

## 27.4 Completion-triggered repetition

A repeatable activity is one persistent, independently focusable Brick with an
execution-occurrence history. Reading an article, watching a film, or reviewing
reference material may use this pattern. “Consumable” is not a property: the
same source may be used repeatedly, and whether another execution is useful is
a Nature decision.

When an execution finishes:

1. the execution occurrence is recorded with its completion evidence;
2. the user may finish the Brick terminally or request another execution;
3. if another execution is requested, the Brick remains active and receives
   one future `not_before`;
4. its prior priority position remains unchanged.

An approximate request such as “revisit in six months, plus or minus three
months” chooses one date rather than creating an eligibility window:

```text
next_not_before =
  completion_time + deterministic_jitter(base_delay, jitter_range, seed)
```

The base delay, allowed jitter, seed or equivalent replay evidence, selected
delay, and resulting date must be recorded or deterministically reconstructible
and explainable. The jitter prevents several Bricks completed together from
necessarily returning together.

Before `not_before`, the Brick is derivatively dormant and excluded from
ordinary `next` eligibility. At and after `not_before`, the same Brick returns
to forecast and accumulates ordinary aging or skip pressure until acted on. It
is not binary-inserted again, and there is at most one pending future execution.
Finishing that execution offers the choice again.

By default this pattern has no `best_before`, deadline, expiry, `not_done`
outcome, streak, quota, or accumulating occurrence backlog. Those concepts
belong only to Natures that explicitly need them. If several periods must be
independently resolvable or may coexist unfinished, the recurring-obligation
model creates separate occurrence Bricks instead.

## 27.5 Event-triggered opportunities

A supported canonical source event may release one opportunity on an existing
standing target. This is useful when meaningful timing follows another
activity rather than a clock:

```text
finish an execution of Have lunch
  -> release one opportunity for Brush teeth
```

This is not generic automation and not Brick rebirth:

- the source is an explicit canonical event, such as finishing one identified
  execution occurrence;
- the target is an existing standing Brick whose Nature supports
  opportunities;
- the result releases one target opportunity but does not create, resurrect,
  start, complete, reprioritize, or otherwise change the target's lifecycle;
- the rule selects only core-supported event and release capabilities and
  contains no arbitrary script, network call, or hidden template code;
- the pair of trigger-rule identity and source-event identity releases at most
  one opportunity.

A template may initially configure the relationship, but after expansion the
trigger is ordinary inspectable canonical data. It can be reviewed, edited, or
removed without changing the template definition.

If the user says “I finished lunch,” the operator or powered-up REPL first
proposes the attributable source completion. Only after that canonical event
is accepted does the core evaluate the same deterministic trigger. It must not
fabricate lunch history merely to make the target eligible. An explicit manual
target release may use its own canonical operation when supported; it is not
silently represented as a source event that never happened.

Exact supported event types, opportunity coalescing, correction behavior, and
public rule grammar remain open.

## 27.6 Identity-preserving change and supersession

A standing Brick keeps its identity when its continuing executions still
belong to one semantically honest history. The practical question is:

```text
Should executions before and after this change belong to the same history and
streak?
```

If yes, update the existing Brick. Renaming it or changing its context,
location, method, cadence, schedule, or trigger configuration does not by
itself require a successor. Each configuration change remains historical and
must not retroactively rewrite the configuration attributed to past
occurrences.

For example, changing `Swim twice per week at Club A` to the same practice at
Club B normally preserves one Brick. Moving a weekly walk to a warmer winter
hour also preserves one Brick. Whether changing outdoor walking to treadmill
walking is continuous depends on the intended practice: it may preserve a
walking history, but it does not preserve an outdoor-light practice merely
because the activity looks similar.

If combining old and new executions would make the history or streak
misleading, use a distinct successor. For example, `Pay rent monthly` and
`Pay mortgage monthly` are different obligations; `Swim twice per week` and
`Strength training three times per week` are normally different practices.
Supersession then:

- preserves the old Brick, occurrences, and configuration history;
- records explicit lineage to a distinct successor;
- does not merge or transfer streak history;
- disables future releases owned by the superseded Brick;
- never silently copies or retargets recurrence rules, opportunity triggers,
  dependencies, or priority placement.

An explicit reconciliation may configure or retarget applicable mechanics for
the successor. If streak continuity is semantically required, that is evidence
that the existing Brick should normally be updated instead of superseded.

The deterministic core cannot infer semantic continuity from title similarity
or configuration changes. A human or attributed operator chooses update versus
supersede. Likewise, feeding something similar to retired standing work may
produce a duplicate-suspicion proposal to reactivate it or create a new Brick,
but never automatic resurrection.

## 27.7 Practices and unfulfilled intentions

The canonical domain should use a neutral term such as `practice`, not assert
that a habit is morally good.

A practice is a standing Brick with a cadence, schedule, or quota window, such
as:

```text
Go for a walk · once per week
Swim · twice per week
```

Each applicable opportunity records an outcome. The working outcome vocabulary
includes:

```text
done | not_done
```

The exact canonical name for an unfulfilled intention remains open, but the
Nature is settled:

- an applicable opportunity that expires without completion is recorded;
- it does not create an indefinitely overdue task;
- the next opportunity follows the recurrence rule;
- ordinary skip and terminal occurrence outcome remain distinct;
- skip may defer the current suggestion without immediately fabricating
  `not_done`;
- an explicit action that abandons the current opportunity, or deterministic
  expiry of its valid window, may finalize the unfulfilled outcome.

Quota schedules such as twice per week must not create one overdue Brick for
each missing performance.

## 27.8 Blocked and paused practices

A practice may depend on enabling work. A known blocker changes eligibility
and must prevent false failure evidence.

Example:

```text
Swim twice per week
  blocked by -> Find a swimming pool
```

While the applicable practice is blocked or explicitly paused:

- it is not served as an executable practice;
- elapsed windows do not create `not_done`;
- its streak does not break merely because the prerequisite is unresolved;
- selection pressure may move to the blocker;
- resumption is explicit and keeps the history.

## 27.9 Motivational projection

Practices may expose a compact, game-like history projection:

```text
[x][x][x][-][x][x]
```

The projection and streak are derived from occurrence history; they are not
mutable scores. Before an action would finalize `not_done`, the UI may warn
about the concrete streak consequence:

```text
This will end a 2-occurrence streak. Continue?
```

An ordinary defer-only skip must not claim that a streak has already been
lost. Exact symbols, streak definitions for fixed slots versus quota windows,
and whether the feature is configurable remain open. The minimum design does
not require points, leaderboards, or punitive scoring.

## 27.10 Introspection and enabling work

Repeated skips or unfulfilled opportunities create evidence for a derived
practice review. The trigger must be configurable or adjustable from real
usage; 1.0 does not hard-code one universal number of attempts.

The deterministic core may:

- count consecutive and recent outcomes;
- aggregate explicit skip reasons and their timestamps;
- expose schedule, season, context, blocker, and streak facts;
- propose a review when the pattern becomes meaningful;
- persist any explicitly confirmed schedule, dependency, pause, or new Brick.

The dumb REPL may guide a fixed review dialog over those facts. The powered-up
REPL or operator skill may interpret the pattern and propose a semantic
hypothesis. For example, repeated “too cold” reasons may suggest moving a walk
to a warmer winter hour.

The review may propose, but never silently perform:

- changing cadence or time window;
- changing context or method;
- adding a dependency;
- creating one or more enabling Bricks;
- pausing or retiring the practice;
- preserving the current configuration and collecting more evidence.

An enabling activity is ordinary work. `Find a swimming pool` is a normal
Brick, and the practice becomes blocked through the ordinary dependency model.
The core detects patterns and enforces mechanics; human or attributed operator
judgment supplies causal interpretation.

## 27.11 Adaptive thresholds

The same evidence-first principle applies to repeatedly carried ListEntries,
practice reviews, and similar standing work. The core must retain enough
history to tune review pressure, expose why a review was proposed, and avoid
silently removing work. Exact thresholds and adaptation policy should be
calibrated through day-to-day use rather than fixed prematurely.

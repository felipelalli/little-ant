# Synthetic UX week

Status: **fixture defined; interactive transcript not yet run**

## Fixed environment

```text
fixture: lant-v1-ux-week-001
timezone: America/Montevideo
starts_at: 2026-08-03T09:00:00-03:00
configuration: factory-v1-draft-001
random_stream: ux-week-001
initial_active_domain: Orbit › R&D › Rock Splitter
initial_focus: none
```

Read-only forecast views reuse the same state and never advance
`random_stream`.

## Fixture

### Domains

```text
Orbit
  R&D
    Rock Splitter
Personal
  Little Ant
  Housekeeping
  Health
  Finance
Learning
```

### ExternalEntities

```text
#e00001 "Bento Camargo" · person
#e00002 "GitHub" · service
#e00003 "Fast model" · ai_agent
```

### Bricks and material

```text
#r90000 "Release Little Ant v1" · project · Personal › Little Ant
  #a12345 "Recover Little Ant v1" · project
    #c12345 "Write the migration specification" · atomic_task · phase spec
    #i20000 "Restore importance ordering" · project
      #b30000 "Define the importance-maintenance contract" · atomic_task · phase spec

#p12345 "Rock Splitter" · project · Orbit › R&D › Rock Splitter
  #r12345 "Review Rock Splitter rules" · atomic_task

#h12345 "Buy groceries" · living_checklist · Personal › Housekeeping
  entries: Coffee, Dish soap

#s12345 "Swim twice per week" · habit · Personal › Health
  blocked by #g12345 "Find a swimming pool" · atomic_task

#e12345 "Pay electricity bill · August 2026"
  recurring_obligation occurrence · Personal › Finance

#l12345 "Read the focus-engine article" · repeatable · Learning
  source Raw #w12345 "https://example.com/focus-engine"

#d12345 "Obtain supplier review" · atomic_task
  delegated to #e00001 "Bento Camargo" · follow-up overdue

Raw #n12345 "Unsorted meeting notes"
Raw #w12345 "https://example.com/focus-engine"
```

Dependencies:

```text
#r90000 blocked by #i20000
#i20000 blocked by #b30000
#s12345 blocked by #g12345
```

## Day 1 — Feeding and identity

### SCN-FED-001 — Dumb REPL baseline

Start the REPL with `mode: dumb`. It automatically serves the fixture's
current `next` opportunity. Press `/`, select `/feed`, enter `comprar leite`
in the Feed input screen, and submit it.

Validate:

- the status bar is visibly separate from the automatically served `next`
  proposal;
- the first screen contains only the Focus decision and `[/] more...`, not a
  direct Feed action, default Feed, or shell prompt;
- no decorative personality message competes with the opening Focus decision;
- the palette initially suggests valid contextual commands, makes implicit
  targets visible, and opens Feed through `/feed`;
- Escape from Feed input restores the exact served proposal without consuming
  another draw;
- dumb Feed input recommends English without rejecting or rewriting the
  Portuguese input;
- no translation, task-shape, target, duplicate, or Nature judgment is
  attributed to a model;
- original Portuguese is preserved;
- no hidden Nature fallback exists: direct factory Nature choices and the
  guided `[?] I don't know` path precede any compatible Template catalog;
- every decision needed to obtain an English canonical title and route is
  reachable through deterministic one-key/input screens;
- duplicate suspicion uses core mechanics without a global `milk` identity;
- the exact route, parent, and Nature are visible before confirmation.

Do not predetermine how many screens are required. The baseline exists to
discover whether language normalization, target selection, or Nature choice
creates unacceptable form-like friction.

### SCN-FED-002 — Powered-up delta

Reset to the identical fixture revision and random cursor. Start the REPL with:

```text
mode: powered up · by: /bin/claude-fast.sh
```

It must automatically serve the same opening `next` opportunity. Press
`/`, select `/feed`, enter `comprar leite`, and submit it. Validate that the
model may propose canonical English, ListEntry route,
`#h12345 "Buy groceries"`, and duplicate interpretation in fewer screens
while using the same canonical envelope/action IDs. Any proposed Template
must expose its resulting Nature and source, require `[y]es`, `[n]o`, or
`[?] I don't know`, and enter the unchanged dumb flow after `no`. Record
every skipped dumb screen and the provenance of every added default.

### SCN-FED-003 — Article URL

Run the URL flow in dumb REPL first, then replay it powered up. Preserve Raw,
propose an `article_reading` Brick when confirmed, attach source material, and
enter sibling importance insertion without treating the URL as completed work.

### SCN-FED-004 — Skill and web/mobile mirror

Only after SCN-FED-001 through SCN-FED-003 are accepted, render their existing
envelopes in the operator skill and web/mobile reference. Validate
almost-literal parity; do not let the skill supply a missing dumb-core path.

### SCN-FED-005 — Nature discovery coverage

Starting from identical pending Feed input, replay the dumb discovery tree once
for each factory Nature leaf. At every split, replay `[?] I don't know`, verify
the alternate probe and its branch equivalence, then use uncertainty again and
verify that Feed remains pending without creating a Brick. At a leaf, verify
the Nature, decisive reason, final confirmation, `no` return to direct choice,
`?` restart from Q0, and Escape return to the previous question. None may lose
Feed input, create a Brick, record a domain event, or consume a draw.

## Day 2 — Importance and uncertainty

### SCN-IMP-001 — Binary insertion

Place `#c12345 "Write the migration specification"` among siblings using
UX-C01. Validate `yes`, `no`, `*`, and full Brick labels.

### SCN-IMP-002 — Two skips

Skip one comparison, receive a replay-deterministic sibling one to three
positions away, then skip again. Validate provisional nearby placement,
visible low confidence, and no false equality.

### SCN-IMP-003 — Contradiction

Answer a provocative direct comparison against a transitive implication.
Validate preserved history, lower confidence, and local recalibration rather
than opaque rewriting.

## Day 3 — Forecast, Domain, and blockers

### SCN-FOC-001 — Same-subject continuity

With Rock Splitter active, draw related work and validate the Domain-affinity
explanation without a hard filter.

### SCN-FOC-002 — Positive-tail cross-Domain draw

Use a recorded draw in which `#h12345 "Buy groceries"` wins. Validate UX-F02:
no preliminary switch prompt; `yes` changes Domain; `skip` and non-focus
palette actions do not.

### SCN-FOC-003 — N-step blocker path

Draw `#r90000 "Release Little Ant v1"` and resolve through `#i20000` to
`#b30000`. Validate UX-F03, local weighted branch evidence, complete `?`
context, and no importance rewrite.

### SCN-FOC-004 — Project descent

Draw a project-like subject and validate Nature-driven child descent versus
review/decomposition. An atomic Brick must not receive the same prompt merely
because its title sounds large.

## Day 4 — Focus and skip adaptation

### SCN-WRK-001 — Focus lifecycle

Accept focus and validate UX-F04 before any further action: focus starts
immediately, the ordinary eligible count drops from 18 to 17, no second draw
occurs, and the selected `focus_started` phrase remains stable when the screen
is redrawn. Verify the ordered `[d]one · [s]kip · [/] more...` action strip.
Open `skip`, cancel the symptom screen, and confirm that no skip evidence or
state change occurred. Replay powered up and allow only the bounded UX-065
paraphrase. Close and reopen five minutes later; validate sober UX-F05 with no
event, draw, repeated phrase, or premature stale-focus question. Then switch
to another Brick through `/next`: cancel the first proposal and confirm that
the old focus survives, then accept a second proposal and confirm that the
switch is atomic while the old Brick remains WIP. Inspect several WIPs and
return one to idle through `/pause`. Validate UX-F06, one current focus,
honest WIP and focus-interval history, unchanged Domain and importance, and no
implicit draw, skip, cooldown, or `paused` Brick state. In a separate replay,
select direct `done` from current focus and validate UX-F07: no intermediate
confirmation, one atomic completion that closes the focus interval and clears
focus, one stable `work_completed` result, and a contextual `/undo` that can
restore the prior state when its preconditions still hold. Verify that the
result performs no automatic draw, renders `ne[x]t`, rejects `n` as unavailable
rather than interpreting it as next, and enters the ordinary `next` pipeline
only after `x`.

### SCN-WRK-002 — Symptom then reaction

Open UX-S01, Escape without mutation, reopen it, select `tired`, then choose a
separately proposed Domain-scoped remedy. Validate active Domain, cooldown,
and that `change subject` was never presented as a symptom. Reopen the screen
and verify `[b]locked`, `bo[r]ed`, `not [i]mportant now`, and the unchanged
`[d]one` binding. Confirm that `n` is not accepted as the symptom shortcut.

### SCN-WRK-003 — Waiting versus blocked

Exercise both paths. Waiting records an ExternalEntity/event/condition;
blocked proposes a Dependency or enabling Brick only on the later reaction
screen.

### SCN-WRK-004 — Other and taxonomy watch

Record repeated attributed `other` explanations and validate a later weighted
taxonomy-review opportunity without automatic vocabulary mutation.

## Day 5 — Lists, dates, and repetition

### SCN-LST-001 — Grocery run

Render all open entries together, add Milk, start a run, resolve listed and
unlisted purchases, leave one item open, and finish the run without retiring
the standing Brick.

### SCN-TIME-001 — Bill and warning

Exercise `not_before`, `best_before`, and `deadline` separately. Validate one
discreet warning, overflow count, acknowledgment/snooze, and no importance
change.

### SCN-REP-001 — Read again

Complete `#l12345`, request another reading in six months plus or minus three,
record one deterministic date, keep its importance position, and ensure a
batch of articles receives distinct replay-safe dates.

## Day 6 — Habits and delegation

### SCN-PRC-001 — Blocked habit

Advance a swimming window while `#s12345` remains blocked by `#g12345`.
Validate no `not_done` outcome and no streak loss.

### SCN-PRC-002 — Explicit unfulfilled intention

After unblocking, attempt to end a window and validate UX-P01. Distinguish
ordinary skip, explicit outcome, and deterministic expiry.

### SCN-DEL-001 — Delegation contract

Delegate a project-like Brick. Validate Nature-driven scope choice,
`once | every | explicitly none`, complete English message preview, approval,
follow-up, refusal/completion reporting, and no cascading parent completion.

## Day 7 — Context, recovery, and boundaries

### SCN-HIS-001 — Recent and filtered history

Validate concise recent actions, `/history`, time/Brick/actor/family filters,
return to the exact envelope, and bounded operator context.

### SCN-REC-001 — Crash and stale answer

Restore an input draft after a simulated crash, advance domain state elsewhere,
and ensure a stale keypress cannot answer the replacement prompt.

### SCN-UNDO-001 — Navigation, undo, and redo

Distinguish Escape from `C-_`; redo a valid compensation; then create a
conflict and require an explicit diagnostic.

### SCN-EXT-001 — Import and source deletion

Migrate a small Microsoft To Do source, verify it, preview
`erase-after-import`, fail one deletion, and validate retained canonical work,
retryable effect, and no false completion.

### SCN-EMPTY-001 — No eligible work

Reach UX-E01 and validate a state-derived useful proposal instead of silence or
fabricated work.

## Parameter sweeps

After the interaction transcript is accepted, replay the fixed week while
varying only:

- importance long-tail strength;
- Domain affinity;
- skip cooldown and fatigue decay;
- additional-signal cap;
- warning lead/rotation;
- provocative comparison chance.

Compare starvation, Domain thrashing, repeated suggestions, warning noise, and
time-to-useful-focus. Parameter sweeps do not change the canonical transcript
or semantic rules.

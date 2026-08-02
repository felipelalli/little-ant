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
@bc "Bento Camargo" · person
@github "GitHub" · service
@fm "Fast model" · ai_agent
```

### Bricks and material

```text
#rlav "Release Little Ant v1" · project · Personal › Little Ant
  #rlav2 "Recover Little Ant v1" · project
    #wtms "Write the migration specification" · atomic_task · phase spec
    #rio "Restore importance ordering" · project
      #dtimc "Define the importance-maintenance contract" · atomic_task · phase spec

#rs "Rock Splitter" · project · Orbit › R&D › Rock Splitter
  #rrsr "Review Rock Splitter rules" · atomic_task

#bg "Buy groceries" · living_checklist · Personal › Housekeeping
  entries: Coffee, Dish soap

#stpw "Swim twice per week" · habit · Personal › Health
  blocked by #fsp "Find a swimming pool" · atomic_task

#peb "Pay electricity bill · August 2026"
  recurring_obligation occurrence · Personal › Finance

#rtfea "Read the focus-engine article" · repeatable · Learning
  source Raw "https://example.com/focus-engine"

#osr "Obtain supplier review" · atomic_task
  delegated to @bc "Bento Camargo" · follow-up overdue

Raw "Unsorted meeting notes"
Raw "https://example.com/focus-engine"
```

Dependencies:

```text
#rlav blocked by #rio
#rio blocked by #dtimc
#stpw blocked by #fsp
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
`#bg "Buy groceries"`, and duplicate interpretation in fewer screens
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

Place `#wtms "Write the migration specification"` among siblings using
UX-C01. Validate `more important`, `less important`, `*`, and full Brick
labels.

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

Use a recorded draw in which `#bg "Buy groceries"` wins. Validate UX-F02:
no preliminary switch prompt; `yes` changes Domain; `skip` and non-focus
palette actions do not.

### SCN-FOC-003 — N-step blocker path

Draw `#rlav "Release Little Ant v1"` and resolve through `#rio` to
`#dtimc`. Validate UX-F03, local weighted branch evidence, complete `?`
context, and no importance rewrite.

### SCN-FOC-004 — Project descent

Draw a project-like subject and validate Nature-driven child descent versus
review/decomposition. An atomic Brick must not receive the same prompt merely
because its title sounds large.

### SCN-FOC-005 — Semantic opportunity granularity

Generate importance-comparison offers for insertion, revalidation, and a
provocative consistency check. If their valid actions and transition family
remain identical, verify that they use one canonical variant with distinct
typed purposes and provenance. Generate two reviews whose valid actions or
domain consequences differ and verify that the final catalog represents them
with distinct discriminated variants even if both reuse the same visual
grammar. Reject a hybrid payload containing mutually exclusive branches or an
action outside its variant. Finally add deadline pressure, one discreet
warning, and explanatory context to a subject and verify that none creates an
additional opportunity or top-level ticket by itself.

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
result performs no automatic draw, renders `[n]ext`, and enters the ordinary
`next` pipeline only after `n`. Verify that this result contains no binary
question or `no` action.

### SCN-WRK-002 — Symptom then reaction

Open UX-S01, Escape without mutation, reopen it, select `tired`, then choose a
separately proposed Domain-scoped remedy. Validate active Domain, cooldown,
and that `change subject` was never presented as a symptom. Reopen the screen
and verify `[b]locked or waiting`, `bo[r]ed`, `[l]ess important`, and the
unchanged `[d]one` binding. Confirm that `n` is not accepted as the symptom
shortcut, that every symptom family retains its icon, and that no personality
message appears before a final reaction commits the skip. From a reaction
screen, verify that `Escape`, `Backspace`, and `Left Arrow` each restore the
exact symptom checkpoint without mutation; from the symptom screen, verify
that they restore the prior Focus checkpoint. Repeat while editing text and
while selecting in a palette to prove that Backspace and arrow keys retain
their local editing or selection meanings.

### SCN-WRK-003 — Waiting versus blocked

Enter the common `[b]locked or waiting` route and classify each branch in
UX-S02. Verify that another task opens UX-S02A; select and cancel an
existing-Brick search, create and cancel an enabling-Brick Feed route, and
prove that neither leaves partial state. Then complete each route and verify
one atomic prerequisite, Dependency, `blocked` evidence, reaction, and
cooldown. Open the response route and validate UX-S02B with both an existing
person and an existing team: typing filters one combined autocomplete,
Up/Down plus Enter selects a revisioned result, and the same list offers
creation without a preliminary `find or create` question. Cancel creation and
prove that it leaves no ExternalEntity; complete it through explicit kind
selection and preserve the proper name without an English-writing hint.
Verify that response and event/condition create typed Waits, while date/time
and location create `not_before` and Place conditions without masquerading as
Waits. Separately choose `skip anyway` before classification and verify
explicit `blocked_or_waiting` evidence and cooldown without an invented
blocker, Wait, time, or Place. In the create route, validate UX-S03 and
UX-S04: the dumb proposal uses the blocked Brick's immediate parent and
effective Domain, keeps the new Brick a sibling, and expresses prerequisite
order only through Dependency.
Reject it and choose another valid structure without losing the draft. Accept
it, verify that insertion starts from the ordinary unresolved midpoint rather
than the blocked Brick, and settle sibling importance independently. Cancel
once after answering a comparison and prove that no draft comparison became
evidence; replay to completion and verify the final atomic result. Validate
UX-S05: no automatic draw or focus, ordinary weighted `[n]ext`, and one
contextual `/focus-blocker` command that opens `Focus?` without silently
starting work. Reject `/focus blocker` and `/focus_blocker` as unknown command
identifiers with canonical recovery. In paired powered-up and Skill replays,
accept one well-supported alternative parent or Domain proposal, reject
another into the unchanged dumb baseline, and require the baseline itself
whenever assisted evidence is weak.

### SCN-WRK-004 — Other and taxonomy watch

Record repeated attributed `other` explanations and validate a later weighted
taxonomy-review opportunity without automatic vocabulary mutation.

### SCN-WAIT-001 — Request handoff and Wait review

From UX-S02C, first answer that a request was already made, validate UX-W00's
canonical wording `When may we start checking again?`, and activate a Wait
only after choosing its `review_not_before`. Accept the factory three-day
suggestion and verify the absolute date and timezone-aware instant. Replay from
the same initial state,
answer `no`, create an enabling Brick, and verify a previewed successor Wait.
Complete the enabling Brick and prove that Dependency resolution plus Wait
activation is atomic: the affected Brick never appears as ordinary focusable
work between them. Before `review_not_before`, verify that the Wait creates
neither a top-level ticket nor a work-focus opportunity. After the threshold,
prove that it is not called due or overdue, then draw UX-W01 through the
affected Brick's subject ticket. Exercise response received, wait longer,
follow-up, change-blocker, uncertainty, skip, and reverse navigation. Verify
that skip leaves `review_not_before` and the Wait outcome unchanged, applies
only typed review cooldown and pressure, and cannot be mistaken for `wait
longer` or served-work symptom evidence. Confirm that a follow-up is an
ordinary Brick and not a claim that any message was sent; that
resolving the Wait releases but does not complete the affected Brick; and that
all transitions remain visible in history. Repeat `wait longer` and verify a
bounded future pressure increase after the new threshold. Finally introduce an
early source observation and verify an attributed candidate resolution without
silent Wait resolution.

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

Complete `#rtfea`, request another reading in six months plus or minus three,
record one deterministic date, keep its importance position, and ensure a
batch of articles receives distinct replay-safe dates.

## Day 6 — Habits and delegation

### SCN-PRC-001 — Blocked habit

Advance a swimming window while `#stpw` remains blocked by `#fsp`.
Validate no `not_done` outcome and no streak loss.

### SCN-PRC-002 — Explicit unfulfilled intention

After unblocking, attempt to end a window and validate UX-P01. Distinguish
ordinary skip, explicit outcome, and deterministic expiry.

### SCN-DEL-001 — Delegation contract

Delegate a project-like Brick. Validate Nature-driven scope choice,
`once | every | explicitly none`, complete English message preview, approval,
follow-up, refusal/completion reporting, and no cascading parent completion.
Before activation, prove that the proposed Delegation has not suppressed
human work. Once active, verify that its exact resolved scope remains visible
in Importance views but contributes no ordinary human Work opportunity. Its
subject may still enter the lottery through a Delegation review, follow-up,
effect approval, or outcome reconciliation. Keep an independent blocker
outside the delegated scope eligible, and represent concurrent human
collaboration with a separate non-covered Brick rather than double-owning the
same work.

Exercise both activation routes. For adapter delivery, prove that draft,
preview, approval, and an attempted send do not suppress human work; a recorded
delivery success activates once, while a delivery failure remains inactive and
retryable. Separately choose `I already handed it off` for an out-of-band
conversation and require explicit human confirmation before activation. In
both routes, handoff must not claim reading, acceptance, refusal, or completion.
Record a later refusal and require typed reconciliation before returning the
scope to human Work eligibility.

Prove that activation creates no automatic Wait for the delegate: Delegation
policy alone schedules its reviews and follow-ups. Then record that the
delegate is waiting for Legal approval and explicitly create a distinct Wait
on the affected Brick. Preserve both histories and outcomes independently
while FOC-006..008 expose only one top-level subject ticket and locally choose
the applicable review opportunity.

When an effect approval wins the lottery, skip it and verify that the pending
effect remains unchanged while only typed approval cooldown and pressure are
recorded. Exercise the other outcomes against separate effect instances:
`later` changes only the review instant, while `no` permanently rejects that
exact effect without cancelling the Delegation, resolving its need, or
silently drafting a replacement.
In dumb mode, open a deterministic suggested follow-up, verify that no
technical template identifier appears in the primary screen, and choose
`edit`. Confirm that the entire prefilled message starts selected: printable
input and paste replace it, Backspace/Delete clear it, and each arrow collapses
the selection without changing the text. Enter must return to the complete
preview under `Message:` without sending; Escape must retain the prior
suggestion. History, assistance, and the structured projection must retain the
factory origin and human edit attribution. Repeat with a powered-up proposal
and require the same interaction grammar and explicit attribution.

## Day 7 — Context, recovery, and boundaries

### SCN-HIS-001 — Recent and filtered history

Validate concise recent actions, `/history`, time/Brick/actor/family filters,
return to the exact envelope, and bounded operator context.

### SCN-REC-001 — Crash and stale answer

Restore an input draft after a simulated crash, advance domain state elsewhere,
and ensure a stale keypress cannot answer the replacement prompt.

### SCN-REF-001 — UUID identity and typed mnemonic handles

Using the existing `#rs "Rock Splitter"`, create `#rs2 "Reason Season"` and
`@rs "Rita Santos"`, plus records whose internal UUIDv7 values share arbitrary
prefixes. Verify that `#` autocomplete searches only Bricks by handle and
title, `@` autocomplete searches only people or companies by handle and name,
and ordinary rendering never exposes or asks the user to memorize those
UUIDs. Rename both Bricks and verify that their UUIDs and handles remain
stable. Explicitly rename one handle, verify the old spelling does not resolve
as an alias, retire it, and verify the allocator does not reuse it.

Then dry-run a merge between independent datasets containing different UUIDs
that both use `#rs`. The preview must retain one handle and deterministically
propose `#rs2` for the other, name every changed public reference, and leave
both UUIDs unchanged. Equal UUIDs with compatible lineage reconcile as the
same object; equal UUIDs with incompatible history stop as an explicit
identity conflict. Validate the same behavior in REPL, CLI JSON, powered-up,
and Skill projections.

### SCN-UNDO-001 — Navigation, undo, and redo

Distinguish uncommitted `Escape`/`Backspace`/arrow navigation from typed
semantic reversal. Walk backward and forward through provisional checkpoints,
choose another branch, and verify that its discarded forward chain cannot be
restored. Complete a focused Brick, exhaust local backward navigation, and
press `Left Arrow`: preview `Undo the last recorded action?` without mutation;
confirm it and verify the same compensation as `/undo`. Press `Right Arrow`
with no local forward checkpoint, preview redo, and confirm a valid
reapplication. Verify that `Escape` and empty-buffer `Backspace` never cross a
commit boundary. Finally create a redo conflict and require an explicit
diagnostic.

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
